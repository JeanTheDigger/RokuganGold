"""Rokugan L5R 4e Discord bot: entry point.

Permission model: two Discord roles gate access.
  - **Fortune**: DM commands (combat, NPCs, encounters, skill checks, etc.)
  - **Kami**: everything Fortune can do + server admin (log channel, etc.)
Players without either role can only manage their own character sheets and
use reference commands (spells, weapons, schools).

Discord plumbing only. All game math lives in `l5r_rules/`; all persistence in
`storage.py`. Run locally: see README.md.
"""

from __future__ import annotations

import copy
import json
import logging
import math
import os
import re
import time
from collections import defaultdict, deque
from time import monotonic

import discord
from discord import app_commands
from discord.ext import tasks

import encounter
import cog_checks
import cog_combat
import cog_hub
import cog_inventory
import cog_npc_builder
import ref_commands
import storage
import views_base
from l5r_rules import (
    advancement, advantage_effects, advantages, combat, condition_effects, creature, enums,
    families, heritage, kata, kata_effects, kiho, kiho_effects, mass_battle, npc_gen,
    schools, skill_mastery, spells, stats, taint, technique_effects,
)
from l5r_rules.character import Character
from l5r_rules.dice import DiceEngine, DiceResult

# NPCs are stored as characters owned by this reserved per-guild pseudo-user, so
# they never collide with a real player's own sheets. Names are unique per guild.
NPC_OWNER = "npc"

# Discord role names for permission gating.  Kami (server admin) > Fortune (DM).
ROLE_KAMI = "Kami"
ROLE_FORTUNE = "Fortune"
ROLE_APPROVED = "Approved"
CAT_PLAYER_SUPPORT = "Player Support"

# Rokugani calendar: 12 months (zodiac animals), 28 days each, 4 seasons.
ROKUGANI_MONTHS: tuple[tuple[str, str], ...] = (
    ("Hare", "Spring"),
    ("Dragon", "Spring"),
    ("Serpent", "Spring"),
    ("Horse", "Summer"),
    ("Goat", "Summer"),
    ("Monkey", "Summer"),
    ("Rooster", "Autumn"),
    ("Dog", "Autumn"),
    ("Boar", "Autumn"),
    ("Rat", "Winter"),
    ("Ox", "Winter"),
    ("Tiger", "Winter"),
)
DAYS_PER_MONTH = 28
SPELL_ELEMENTS = ("air", "earth", "fire", "water", "void")

try:
    from dotenv import load_dotenv

    load_dotenv()
except ModuleNotFoundError:
    pass

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("rokugan-bot")

TOKEN = os.environ.get("DISCORD_BOT_TOKEN")
GUILD_ID = os.environ.get("DISCORD_GUILD_ID")
DB_PATH = os.environ.get("DB_PATH", "rokugan.db")

intents = discord.Intents.default()

engine = DiceEngine()
store = storage.Store(DB_PATH)

# In-memory initiative encounters, keyed by Discord channel id (see encounter.py).
encounters: dict[int, encounter.Encounter] = {}
# Undo snapshots (/dm undo) older than this are purged at startup.
UNDO_MAX_AGE_SECONDS: float = 30 * 24 * 3600
# Stale-turn nudge: re-ping the current actor once after this many minutes.
STALE_TURN_MINUTES: int = 10
# Mentions allowed on approval / nudge messages (role pings need the Fortune role
# to be mentionable, or the bot to hold Mention Everyone).
_PING_MENTIONS = discord.AllowedMentions(roles=True, users=True, everyone=False)

def _dm_ping(guild: discord.Guild | None) -> str:
    """The Fortune role mention (plus a space) for approval prompts, or ''."""
    role = discord.utils.get(guild.roles, name=ROLE_FORTUNE) if guild else None
    return f"{role.mention} " if role else ""

# In-memory roll history: channel_id → deque of (timestamp, user_display, description, total).
_roll_history: dict[int, deque] = defaultdict(lambda: deque(maxlen=50))

# Cached Discord webhooks for NPC speech, keyed by parent channel id.
_npc_webhooks: dict[int, discord.Webhook] = {}
WEBHOOK_NAME = "Rokugan NPC"

def _log_roll(channel_id: int, user: str, description: str, total: int | str) -> None:
    _roll_history[channel_id].append((monotonic(), user, description, total))

@tasks.loop(minutes=1)
async def _stale_turn_check() -> None:
    """Once per turn, nudge the current actor after STALE_TURN_MINUTES of silence."""
    now = time.time()
    for channel_id, enc in list(encounters.items()):
        try:
            if not enc.started or enc.nudged or not enc.combatants or not enc.turn_started_at:
                continue
            if now - enc.turn_started_at < STALE_TURN_MINUTES * 60:
                continue
            cur = enc.current()
            if cur is None:
                continue
            enc.nudged = True
            guild_id = store.encounter_guild(str(channel_id))
            if guild_id:
                _save_encounter(guild_id, enc)
            channel = client.get_channel(channel_id)
            if channel is None:
                continue
            mention = f"<@{cur.owner_id}> " if cur.owner_id and not cur.is_npc else ""
            await channel.send(
                f"⏰ {mention}**{cur.name}**'s turn has been waiting {STALE_TURN_MINUTES} min (Round {enc.round}). "
                f"Act, then `/combat turn done`. Staff can `/combat turn done name:{cur.name}` or `/combat next`.",
                allowed_mentions=_PING_MENTIONS,
            )
        except Exception:
            # One bad encounter or channel must not stop the loop for everyone.
            log.warning("Stale-turn nudge failed for channel %s", channel_id, exc_info=True)


# Discord rejects a whole sync if any one top-level command's combined name,
# description and choice-value text exceeds this many characters.
COMMAND_TEXT_LIMIT: int = 8000

def _command_text_chars(payload: object) -> int:
    """Characters Discord counts toward COMMAND_TEXT_LIMIT in a command's registration payload."""
    if isinstance(payload, dict):
        return sum(
            len(v) if k in ("name", "description", "value") and isinstance(v, str) else _command_text_chars(v)
            for k, v in payload.items()
        )
    if isinstance(payload, list):
        return sum(_command_text_chars(item) for item in payload)
    return 0

def _oversized_commands(tree: app_commands.CommandTree) -> list[tuple[str, int]]:
    """(name, chars) for every top-level command whose payload Discord would refuse."""
    out: list[tuple[str, int]] = []
    for cmd in tree.get_commands():
        chars = _command_text_chars(cmd.to_dict(tree))
        if chars > COMMAND_TEXT_LIMIT:
            out.append((cmd.name, chars))
    return out

async def _sync_tree(tree: app_commands.CommandTree, guild: discord.abc.Snowflake) -> tuple[int, str]:
    """Register the tree with one guild and clear global copies. Returns (count, error).
    A failed sync leaves Discord serving the previous definitions, so the error is
    always logged and returned instead of raised."""
    for name, chars in _oversized_commands(tree):
        log.error("/%s registration is %d chars (limit %d): Discord will reject the sync", name, chars, COMMAND_TEXT_LIMIT)
    try:
        tree.copy_global_to(guild=guild)
        synced = await tree.sync(guild=guild)
        tree.clear_commands(guild=None)
        await tree.sync()
    except discord.HTTPException as e:
        detail = getattr(e, "text", "") or str(e)
        log.error("Command sync to guild %s FAILED: %s", getattr(guild, "id", "?"), detail)
        return 0, detail
    log.info("Synced %d commands to guild %s", len(synced), getattr(guild, "id", "?"))
    return len(synced), ""

class RokuganBot(discord.Client):
    def __init__(self) -> None:
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self) -> None:
        if GUILD_ID:
            await _sync_tree(self.tree, discord.Object(id=int(GUILD_ID)))

    async def on_ready(self) -> None:
        self.tree.on_error = _on_app_command_error
        self.add_view(_ChargenButtonView())
        if not GUILD_ID:
            for g in self.guilds:
                await _sync_tree(self.tree, g)
        log.info("Logged in as %s (id=%s). Ready.", self.user, getattr(self.user, "id", "?"))
        for ch_id_str, data_json in store.load_all_encounters():
            try:
                enc = encounter.Encounter.from_dict(json.loads(data_json))
                encounters[int(ch_id_str)] = enc
            except Exception:
                log.warning("Failed to restore encounter for channel %s", ch_id_str)
        if encounters:
            log.info("Restored %d encounter(s) from database.", len(encounters))
        if not _stale_turn_check.is_running():
            _stale_turn_check.start()
        if not getattr(self, "_views_restored", False):
            self._views_restored = True
            store.purge_undo(time.time() - UNDO_MAX_AGE_SECONDS)
            restored = views_base.restore_all(self)
            if restored:
                log.info("Re-attached %d pending approval view(s).", restored)

client = RokuganBot()


# Approval views: shared _disable(), and (for subclasses that set KIND)
# persistence across restarts. See views_base.py.
_DisableableView = views_base.PersistentView
views_base.init(store)


# ===========================================================================
# Global error handlers (slash commands, buttons/menus, modals)
# ===========================================================================
_COMPONENT_ERROR_TEXT = (
    "Something went wrong with that control. The error has been logged; "
    "try again, or tell a DM what you pressed."
)

async def _send_component_error(interaction: discord.Interaction) -> None:
    try:
        if interaction.response.is_done():
            await interaction.followup.send(_COMPONENT_ERROR_TEXT, ephemeral=True)
        else:
            await interaction.response.send_message(_COMPONENT_ERROR_TEXT, ephemeral=True)
    except discord.HTTPException:
        pass

async def _view_on_error(self: discord.ui.View, interaction: discord.Interaction, error: Exception,
                         item: discord.ui.Item) -> None:
    label = getattr(item, "label", None) or getattr(item, "placeholder", None) or type(item).__name__
    log.error("Unhandled error in view %s [%s]: %s", type(self).__name__, label, error, exc_info=error)
    await _send_component_error(interaction)

async def _modal_on_error(self: discord.ui.Modal, interaction: discord.Interaction, error: Exception) -> None:
    log.error("Unhandled error in modal %s: %s", type(self).__name__, error, exc_info=error)
    await _send_component_error(interaction)

# Every view and modal in the bot (library defaults only print to stderr and
# leave the user with Discord's bare "This interaction failed").
discord.ui.View.on_error = _view_on_error
discord.ui.Modal.on_error = _modal_on_error

async def _on_app_command_error(
    interaction: discord.Interaction, error: app_commands.AppCommandError
) -> None:
    if isinstance(error, app_commands.CommandOnCooldown):
        await interaction.response.send_message(
            f"This command is on cooldown. Try again in **{error.retry_after:.0f}s**.",
            ephemeral=True,
        )
        return
    if isinstance(error, app_commands.CheckFailure):
        await interaction.response.send_message(
            "You don't have permission to use this command.", ephemeral=True
        )
        return
    log.error("Unhandled error in /%s: %s", getattr(interaction.command, "qualified_name", "?"), error, exc_info=error)
    embed = discord.Embed(
        title="Something went wrong",
        description=(
            "An unexpected error occurred while running this command. "
            "The error has been logged. Please try again or contact a DM."
        ),
        color=discord.Color.red(),
    )
    try:
        if interaction.response.is_done():
            await interaction.followup.send(embed=embed, ephemeral=True)
        else:
            await interaction.response.send_message(embed=embed, ephemeral=True)
    except discord.HTTPException:
        pass

# ===========================================================================
# Shared helpers
# ===========================================================================
def _has_role(interaction: discord.Interaction, name: str) -> bool:
    """True if the interacting member has a role with the given name."""
    member = interaction.user
    if not isinstance(member, discord.Member):
        return False
    return any(r.name == name for r in member.roles)

def _is_dm(interaction: discord.Interaction) -> bool:
    """True if the member has the Fortune or Kami role."""
    return _has_role(interaction, ROLE_FORTUNE) or _has_role(interaction, ROLE_KAMI)

def _is_kami(interaction: discord.Interaction) -> bool:
    """True if the member has the Kami role."""
    return _has_role(interaction, ROLE_KAMI)

async def _require_guild(interaction: discord.Interaction) -> bool:
    """Send an error if not in a server channel. Returns True if OK."""
    if interaction.guild_id is not None:
        return True
    await interaction.response.send_message(
        "Please use this in a server channel.", ephemeral=True
    )
    return False

async def _require_dm_role(interaction: discord.Interaction) -> bool:
    """Send an error if the user lacks the Fortune/Kami role. Returns True if OK."""
    if _is_dm(interaction):
        return True
    await interaction.response.send_message(
        f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to use this command.",
        ephemeral=True,
    )
    return False

async def _require_encounter(interaction: discord.Interaction) -> encounter.Encounter | None:
    """Return the channel's encounter, or send an error and return None."""
    enc = encounters.get(interaction.channel_id)
    if enc is not None:
        return enc
    await interaction.response.send_message(
        "No encounter here. Start one with `/combat start`.", ephemeral=True
    )
    return None

async def _refuse_if_dead(interaction: discord.Interaction, c: Character) -> bool:
    """Ephemeral refusal for actions by or on a dead character. True = refused."""
    if not stats.is_dead(c):
        return False
    await interaction.response.send_message(
        f"💀 **{c.name}** is dead. PC death is permanent; a DM may use `/dm revive` only to undo a bug.",
        ephemeral=True,
    )
    return True

async def _refuse_if_cannot_act(interaction: discord.Interaction, c: Character) -> bool:
    """Actor-side gate: dead, or Out (unconscious, s22.3). True = refused."""
    if await _refuse_if_dead(interaction, c):
        return True
    if stats.wound_level_name(c) == "Out":
        await interaction.response.send_message(
            f"😵 **{c.name}** is **Out** — unconscious — and cannot act until healed above that level.",
            ephemeral=True,
        )
        return True
    return False

def _fear_penalty(channel_id: int, name: str) -> int:
    """Rolled dice lost to a failed Fear check, from the channel's encounter (0 if untracked)."""
    enc = encounters.get(channel_id)
    cb = enc.find(name) if enc else None
    return cb.fear_penalty if cb else 0

def _set_fear_penalty(guild_id: str, channel_id: int, name: str, rank: int) -> bool:
    """Record (rank > 0, keeping the worse of old/new) or clear (rank == 0) a
    combatant's Fear penalty. False if the character is not in this channel's encounter."""
    enc = encounters.get(channel_id)
    cb = enc.find(name) if enc else None
    if cb is None:
        return False
    cb.fear_penalty = max(cb.fear_penalty, rank) if rank > 0 else 0
    _save_encounter(guild_id, enc)
    return True

def _sheet_diff(old: dict, new: dict) -> list[str]:
    """Readable field-by-field differences between two saved sheets."""
    out: list[str] = []
    for key in sorted(set(old) | set(new)):
        a, b = old.get(key), new.get(key)
        if a == b:
            continue
        if isinstance(a, dict) or isinstance(b, dict):
            a, b = a or {}, b or {}
            for k in sorted(set(a) | set(b)):
                if a.get(k) != b.get(k):
                    out.append(f"{key}.{k} {a.get(k, '—')} → {b.get(k, '—')}")
        elif isinstance(a, list) or isinstance(b, list):
            a, b = a or [], b or []
            added = [x for x in b if x not in a]; removed = [x for x in a if x not in b]
            if added:
                out.append(f"{key} +{', '.join(map(str, added))}")
            if removed:
                out.append(f"{key} −{', '.join(map(str, removed))}")
        else:
            out.append(f"{key} {a} → {b}")
    return out

async def _audit_stat(interaction: discord.Interaction, rec: storage.CharacterRecord, what: str,
                      changed: bool = True) -> None:
    """One combat-log line per sheet edit: who edited whose sheet and what changed.
    `changed` is Store.save()'s return value: the undo snapshot it just took is the before-state."""
    guild = str(interaction.guild_id)
    changes: list[str] = []
    if changed:
        snaps = store.list_undo(guild, rec.character.name, limit=1)
        if snaps and snaps[0].entity_id == rec.id:
            changes = _sheet_diff(snaps[0].data, rec.character.to_dict())
    who = interaction.user.display_name + ("" if rec.owner_id == str(interaction.user.id) else " (staff)")
    detail = "; ".join(changes)[:600] if changes else "no change"
    await _combat_log(guild, f"EDIT: {who} · {rec.character.name} · {what} · {detail}")

def _tally(channel_id: int | None, name: str, key: str, amount: int = 1) -> None:
    """Add to the fight tally of this channel's encounter (no-op if none / unknown name)."""
    if channel_id is None or not amount:
        return
    enc = encounters.get(channel_id)
    if enc is None or not enc.record(name, key, amount):
        return
    guild_id = store.encounter_guild(str(channel_id))
    if guild_id:
        _save_encounter(guild_id, enc)

async def _on_death(guild_id: str, name: str, owner_id: str | None, record_id: int | None) -> list[str]:
    """Bookkeeping when a character or creature dies: drop it from every
    initiative tracker in this guild and, for a PC, stop it being the
    player's active character. Returns note lines for the announcement."""
    notes: list[str] = []
    for enc in list(encounters.values()):
        if store.encounter_guild(str(enc.channel_id)) != guild_id:
            continue
        cb = enc.find(name)
        if cb is None:
            continue
        if owner_id and owner_id != NPC_OWNER and cb.owner_id not in (None, owner_id):
            continue
        enc.note_death(name)
        enc.remove(name)
        _save_encounter(guild_id, enc)
        if "removed from initiative" not in notes:
            notes.append("removed from initiative")
    if owner_id and owner_id != NPC_OWNER and record_id is not None:
        active = store.get_active(guild_id, owner_id)
        if active is not None and active.id == record_id:
            store.clear_active(guild_id, owner_id, record_id)
            notes.append("no longer the player's active character")
    await _combat_log(guild_id, f"DEATH: {name}" + (f" ({'; '.join(notes)})" if notes else ""))
    return notes

async def _resolve_active(
    interaction: discord.Interaction, member: discord.Member | None
) -> storage.CharacterRecord | None:
    """Return the active character record, or send an error and return None.
    Unlike _resolve_active_for_edit, this does NOT require DM to view others."""
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(
                f"{member.display_name} has no active character.", ephemeral=True
            )
            return None
        return rec
    rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message(
            "You have no active character. Use `/sheet create` first.", ephemeral=True
        )
        return None
    return rec

def _wound_color(record: storage.CharacterRecord) -> discord.Color:
    idx = stats.wound_level_index(record.character)
    if idx == 0:
        return discord.Color.green()
    if idx >= 6:  # Down / Out / Dead
        return discord.Color.dark_red()
    if idx >= 3:  # Hurt / Injured / Crippled
        return discord.Color.orange()
    return discord.Color.gold()

def _format_traits(c: Character) -> str:
    def pair(a: str, b: str) -> str:
        return f"{a.capitalize()} {c.get_trait(a)} / {b.capitalize()} {c.get_trait(b)}"

    return (
        f"🌪️ Air: {pair('reflexes', 'awareness')}\n"
        f"⛰️ Earth: {pair('stamina', 'willpower')}\n"
        f"🔥 Fire: {pair('agility', 'intelligence')}\n"
        f"💧 Water: {pair('strength', 'perception')}\n"
        f"🌀 Void: {c.void_ring}"
    )

def build_sheet_embed(record: storage.CharacterRecord) -> discord.Embed:
    c = record.character
    rings = stats.all_rings(c)
    embed = discord.Embed(
        title=c.name or "(unnamed)",
        color=_wound_color(record),
    )

    subtitle_bits = [b for b in (c.clan, c.family, c.school) if b]
    school_line = f"{c.school_type} School" + (f" (Rank {c.school_rank})" if c.school_rank else "")
    header = " · ".join(subtitle_bits) if subtitle_bits else " "
    npc_tag = "🎭 **NPC**\n" if c.is_npc else ""
    embed.description = f"{npc_tag}{header}\n{school_line}"

    embed.add_field(
        name="Rings",
        value=(
            f"Air **{rings['air']}** · Earth **{rings['earth']}** · Fire **{rings['fire']}** · "
            f"Water **{rings['water']}** · Void **{rings['void']}**"
        ),
        inline=False,
    )
    embed.add_field(name="Traits", value=_format_traits(c), inline=True)

    lvl = stats.wound_level_name(c)
    pen = stats.wound_penalty(c)
    cap = stats.total_wound_capacity(c)
    healthy = stats.healthy_wound_threshold(c)
    per = stats.wound_threshold_per_level(c)
    track = stats.wound_track(c)
    wound_line = (
        f"**{lvl}**" + (f" ({pen} penalty)" if pen else "")
        + f"\n{c.wounds_taken} / {cap} wounds  ·  Healthy {healthy}, then {per} per level"
        + f"\n{track}"
    )
    embed.add_field(name="Wounds", value=wound_line, inline=True)

    embed.add_field(
        name="Standing",
        value=(
            f"Honor {c.honor:g} · Glory {c.glory:g} · Status {c.status:g} · Infamy {c.infamy:g}\n"
            f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) · "
            f"Void Points {c.current_void_points}/{taint.void_point_cap(c)}"
            + (" (Taint: max -1)" if taint.void_point_cap(c) < c.max_void_points else "") + "\n"
            f"XP available: **{c.xp:g}** (spent {c.xp_spent:g})"
        ),
        inline=False,
    )

    base_atn = c.reflexes * 5 + 5 + c.armor_tn_bonus
    init_rolled = c.reflexes + stats.insight_rank(c)
    init_kept = c.reflexes
    embed.add_field(
        name="Derived",
        value=(
            f"Armor TN **{base_atn}** (Ref {c.reflexes}×5+5"
            + (f"+{c.armor_tn_bonus} armor" if c.armor_tn_bonus else "")
            + f") · Reduction **{c.armor_reduction}**"
            f"\nInitiative **{init_rolled}k{init_kept}** · "
            f"Healing Rate {c.stamina * 2}/day"
        ),
        inline=False,
    )

    if c.armor_name:
        gear = f"Armor: {c.armor_name}  (TN +{c.armor_tn_bonus}, Reduction {c.armor_reduction})"
    elif c.owned_armor:
        gear = f"Armor: {c.owned_armor}  (not worn)"
    else:
        gear = "Armor: —"
    if c.equipped_weapon:
        wield = c.equipped_weapon
        if c.off_hand_weapon:
            wield += f" + {c.off_hand_weapon} (off)"
        if c.weapon_qualities:
            wield += f" [{', '.join(c.weapon_qualities)}]"
        gear += f"\nWielding: {wield}"
    if c.weapons:
        gear += "\nWeapons: " + ", ".join(c.weapons)
    embed.add_field(name="Equipment", value=gear, inline=False)

    if c.spell_slots:
        slot_parts = []
        for elem in SPELL_ELEMENTS:
            if elem in c.spell_slots:
                mx = stats.spell_slot_max(c, elem)
                cur = c.spell_slots[elem]
                slot_parts.append(f"{elem.capitalize()} **{cur}**/{mx}")
        bonus_mx = stats.void_bonus_max(c)
        slot_parts.append(f"Bonus **{c.void_spell_bonus}**/{bonus_mx}")
        if slot_parts:
            embed.add_field(name="Spell Slots", value=" · ".join(slot_parts), inline=False)

    water = stats.water_ring(c)
    embed.add_field(
        name="Movement",
        value=f"Free Move: {water * 5} ft · Simple Move: {water * 10} ft  (Water Ring {water})",
        inline=False,
    )

    if c.skills:
        skill_line = ", ".join(f"{name} {rank}" for name, rank in sorted(c.skills.items()))
        embed.add_field(name="Skills", value=skill_line[:1024], inline=False)

    extras = []
    if c.techniques:
        extras.append("**Techniques: ** " + ", ".join(c.techniques))
    if c.katas:
        act = (c.active_kata or "").lower()
        extras.append("**Kata: ** " + ", ".join(
            (f"⚑{k}" if k.lower() == act else k) for k in c.katas))
    if c.kiho:
        active_kiho = [a.lower() for a in getattr(c, "active_kiho", [])]
        extras.append("**Kiho: ** " + ", ".join(
            (f"⚑{k}" if k.lower() in active_kiho else k) for k in c.kiho))
    if c.tattoos:
        act_t = (c.active_tattoo or "").lower()
        extras.append("**Tattoos: ** " + ", ".join(
            (f"⚑{t}" if t.lower() == act_t else t) for t in c.tattoos))
    if c.emphases:
        extras.append("**Emphases: ** " + ", ".join(
            f"{sk} ({', '.join(em)})" for sk, em in sorted(c.emphases.items()) if em))
    if c.spells_known:
        extras.append("**Spells: ** " + ", ".join(c.spells_known))
    if c.advantages:
        extras.append("**Advantages: ** " + ", ".join(c.advantages))
    if c.disadvantages:
        extras.append("**Disadvantages: ** " + ", ".join(c.disadvantages))
    if c.taint > 0:
        extras.append(f"**Taint: ** {c.taint:g}")
    if c.koku:
        extras.append(f"**Koku: ** {c.koku:g}")
    if c.inventory:
        inv_parts = []
        for iname, qty in sorted(c.inventory.items()):
            inv_parts.append(f"{iname} ×{qty}" if qty > 1 else iname)
        extras.append("**Inventory: ** " + ", ".join(inv_parts))
    if c.notes:
        extras.append(f"*{c.notes}*")
    if extras:
        embed.add_field(name="Details", value="\n".join(extras)[:1024], inline=False)

    if record.owner_id == NPC_OWNER:
        cats = store.list_entity_categories(record.guild_id, "npc", c.name)
        if cats:
            embed.add_field(name="Categories", value=", ".join(cat.name for cat in cats), inline=False)

    embed.set_footer(text=f"Owner: player {record.owner_id} · sheet #{record.id}")
    return embed

def build_creature_embed(record: storage.CreatureRecord) -> discord.Embed:
    cr = record.creature
    lvl = creature.creature_wound_level(cr)
    dead = creature.creature_is_dead(cr)
    color = discord.Color.dark_red() if dead else (
        discord.Color.green() if cr.wounds_taken == 0 else discord.Color.orange()
    )
    embed = discord.Embed(title=f"👹 {cr.name}", color=color)
    tags = f" · {', '.join(cr.tags)}" if cr.tags else ""
    embed.description = f"Creature: *{cr.template_id}*{tags}"
    embed.add_field(
        name="Rings",
        value=f"Air **{cr.air}** · Earth **{cr.earth}** · Fire **{cr.fire}** · Water **{cr.water}**",
        inline=False,
    )
    embed.add_field(
        name="Combat",
        value=(
            f"Initiative {cr.initiative_rolled}k{cr.initiative_kept}\n"
            f"{cr.attack_name}: attack **{cr.attack_rolled}k{cr.attack_kept}**, "
            f"damage **{cr.damage_rolled}k{cr.damage_kept}**\n"
            f"Armor TN **{cr.armor_tn}** · Reduction **{cr.reduction}**"
            + (f" · Fear **{cr.fear}**" if cr.fear else "")
        ),
        inline=False,
    )
    thr = ", ".join(str(t) for t in cr.wound_thresholds) if cr.wound_thresholds else " "
    embed.add_field(
        name="Wounds",
        value=f"**{lvl}**: {cr.wounds_taken} / {cr.wounds_dead} (dead)\nthresholds: {thr}"
        + ("  💀 **SLAIN**" if dead else ""),
        inline=False,
    )
    specials = creature.creature_special_notes(cr)
    if specials:
        embed.add_field(name="Special Abilities", value="\n".join(specials), inline=False)
    cats = store.list_entity_categories(record.guild_id, "creature", cr.name)
    if cats:
        embed.add_field(name="Categories", value=", ".join(c.name for c in cats), inline=False)
    embed.set_footer(text=f"creature #{record.id}")
    return embed

_RING_TRAITS: dict[str, tuple[str, str]] = {
    "air": ("reflexes", "awareness"),
    "earth": ("stamina", "willpower"),
    "fire": ("agility", "intelligence"),
    "water": ("strength", "perception"),
}

_CR_WOUND_LEVELS = ["Healthy", "Nicked", "Grazed", "Hurt", "Injured", "Crippled", "Down", "Out"]

def _build_creature_template_embed(cr: creature.Creature) -> discord.Embed:
    embed = discord.Embed(title=f"\U0001f479 {cr.name}", color=discord.Color.dark_purple())
    embed.description = f"Template: `{cr.template_id}`"

    ring_parts: list[str] = []
    for ring_name, (trait_a, trait_b) in _RING_TRAITS.items():
        ring_val = getattr(cr, ring_name)
        overrides: list[str] = []
        if trait_a in cr.traits:
            overrides.append(f"{trait_a.capitalize()} {cr.traits[trait_a]}")
        if trait_b in cr.traits:
            overrides.append(f"{trait_b.capitalize()} {cr.traits[trait_b]}")
        label = ring_name.capitalize()
        if overrides:
            ring_parts.append(f"{label} **{ring_val}** ({', '.join(overrides)})")
        else:
            ring_parts.append(f"{label} **{ring_val}**")
    embed.add_field(name="Rings", value=" · ".join(ring_parts), inline=False)

    atk = f"**{cr.attack_rolled}k{cr.attack_kept}**"
    if cr.attack_flat:
        atk += f"+{cr.attack_flat}"
    dmg = f"**{cr.damage_rolled}k{cr.damage_kept}**"
    if cr.damage_flat:
        dmg += f"+{cr.damage_flat}"
    combat_lines = [
        f"Initiative: {cr.initiative_rolled}k{cr.initiative_kept}",
        f"{cr.attack_name or 'Attack'}: attack {atk}, damage {dmg}",
        f"Armor TN **{cr.armor_tn}** · Reduction **{cr.reduction}**",
    ]
    if cr.fear > 0:
        combat_lines.append(f"Fear **{cr.fear}**")
    embed.add_field(name="Combat", value="\n".join(combat_lines), inline=False)

    if cr.wound_thresholds:
        parts: list[str] = []
        prev_upper = 0
        for i, threshold in enumerate(cr.wound_thresholds):
            level_name = _CR_WOUND_LEVELS[i] if i < len(_CR_WOUND_LEVELS) else f"Level {i}"
            low = prev_upper + 1 if prev_upper > 0 else 0
            parts.append(f"{level_name} {low}–{threshold}")
            prev_upper = threshold
        remaining_idx = len(cr.wound_thresholds)
        if remaining_idx < len(_CR_WOUND_LEVELS) and prev_upper + 1 < cr.wounds_dead:
            parts.append(f"{_CR_WOUND_LEVELS[remaining_idx]} {prev_upper + 1}–{cr.wounds_dead - 1}")
        parts.append(f"Dead {cr.wounds_dead}")
        wound_text = " · ".join(parts)
    else:
        wound_text = f"Dead at **{cr.wounds_dead}** wounds"
    embed.add_field(name="Wound Track", value=wound_text, inline=False)

    specials = creature.creature_special_notes(cr)
    if specials:
        embed.add_field(name="Special Abilities", value="\n".join(specials), inline=False)

    if cr.tags:
        embed.add_field(name="Tags", value=", ".join(f"`{t}`" for t in cr.tags), inline=False)

    return embed

_TRAIT_ABBREV = {
    "reflexes": "Ref", "awareness": "Awa", "stamina": "Sta", "willpower": "Wil",
    "agility": "Agi", "intelligence": "Int", "strength": "Str", "perception": "Per",
}

def _creature_compact_summary(cr: creature.Creature) -> str:
    ring_parts: list[str] = []
    for ring_name, (trait_a, trait_b) in _RING_TRAITS.items():
        ring_val = getattr(cr, ring_name)
        overrides: list[str] = []
        if trait_a in cr.traits:
            overrides.append(f"{_TRAIT_ABBREV[trait_a]} {cr.traits[trait_a]}")
        if trait_b in cr.traits:
            overrides.append(f"{_TRAIT_ABBREV[trait_b]} {cr.traits[trait_b]}")
        label = ring_name.capitalize()[:1]
        if overrides:
            ring_parts.append(f"{label} {ring_val} ({', '.join(overrides)})")
        else:
            ring_parts.append(f"{label} {ring_val}")
    rings = " · ".join(ring_parts)
    atk = f"{cr.attack_rolled}k{cr.attack_kept}"
    if cr.attack_flat:
        atk += f"+{cr.attack_flat}"
    dmg = f"{cr.damage_rolled}k{cr.damage_kept}"
    if cr.damage_flat:
        dmg += f"+{cr.damage_flat}"
    combat = (
        f"Init {cr.initiative_rolled}k{cr.initiative_kept} | "
        f"{cr.attack_name or 'Atk'}: {atk} / Dmg: {dmg}\n"
        f"TN **{cr.armor_tn}** · Red **{cr.reduction}**"
    )
    if cr.fear > 0:
        combat += f" · Fear **{cr.fear}**"
    if cr.wound_thresholds:
        thr = ", ".join(str(t) for t in cr.wound_thresholds)
        wounds = f"Thresholds: {thr} → Dead {cr.wounds_dead}"
    else:
        wounds = f"Dead at {cr.wounds_dead}"
    specials = creature.creature_special_notes(cr)
    lines = [rings, combat, wounds]
    if specials:
        lines.extend(specials)
    if cr.tags:
        lines.append(", ".join(f"`{t}`" for t in cr.tags))
    return "\n".join(lines)

async def _resolve_active_for_edit(
    interaction: discord.Interaction, member: discord.Member | None
) -> tuple[storage.CharacterRecord | None, str | None]:
    """Return (record, error). Editing another member's sheet requires DM."""
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            return None, f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to edit another player's character."
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            return None, f"{member.display_name} has no active character."
        return rec, None
    rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        return None, "You have no active character. Use `/sheet create` first."
    return rec, None

# ===========================================================================
# Top-level commands
# ===========================================================================
@client.tree.command(name="ping", description="Check that the bot is alive.")
async def ping(interaction: discord.Interaction) -> None:
    latency = client.latency
    ms = f"{round(latency * 1000)} ms" if latency == latency else "not measured yet"
    await interaction.response.send_message(f"🎋 Alive. Gateway latency {ms}.", ephemeral=True)

@client.tree.command(name="sync", description="Re-sync all slash commands with Discord [Kami]")
async def sync_commands(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(
            f"Only the **{ROLE_KAMI}** role can sync commands.", ephemeral=True
        )
        return
    await interaction.response.defer(ephemeral=True)
    oversized = _oversized_commands(client.tree)
    count, error = await _sync_tree(client.tree, discord.Object(id=interaction.guild_id))
    if error:
        too_big = "; ".join(f"/{n} is {c} chars (limit {COMMAND_TEXT_LIMIT})" for n, c in oversized)
        await interaction.followup.send(
            "Sync **failed**: Discord kept the previous command definitions.\n"
            f"```\n{error[:1500]}\n```" + (f"\nOversized: {too_big}" if too_big else "")
        )
        return
    await interaction.followup.send(f"Synced **{count}** commands to this server (global duplicates cleared).")

def _whoami_lines(interaction: discord.Interaction, rec: storage.CharacterRecord) -> list[str]:
    """The quick status card lines for a character (used by /whoami and the character hub)."""
    c = rec.character
    rings = stats.all_rings(c)
    lvl = stats.wound_level_name(c)
    pen = stats.wound_penalty(c)
    cap = stats.total_wound_capacity(c)
    ring_str = " · ".join(f"{r.capitalize()} **{v}**" for r, v in rings.items())
    wound_str = f"**{lvl}**" + (f" ({pen} penalty)" if pen else "") + f": {c.wounds_taken}/{cap}"
    if pen:
        wound_str = f"⚠️ {wound_str}"
    vp_str = f"{c.current_void_points}/{c.max_void_points} VP"
    header = " · ".join(b for b in (c.clan, c.school) if b) or " "
    water = stats.water_ring(c)
    move_str = f"Move: {water * 5} ft (Free) / {water * 10} ft (Simple)"
    track = stats.wound_track(c)
    lines = [
        f"**{c.name}**: {header} (Rank {stats.insight_rank(c)})",
        f"Rings: {ring_str}",
        f"Wounds: {wound_str}  ·  {vp_str}",
        track,
        f"Honor {c.honor:g} · Glory {c.glory:g} · Status {c.status:g}",
        move_str,
    ]
    if c.spell_slots:
        slot_parts = []
        for elem in SPELL_ELEMENTS:
            if elem in c.spell_slots:
                mx = stats.spell_slot_max(c, elem)
                cur = c.spell_slots[elem]
                slot_parts.append(f"{elem.capitalize()} {cur}/{mx}")
        bonus_mx = stats.void_bonus_max(c)
        slot_parts.append(f"Bonus {c.void_spell_bonus}/{bonus_mx}")
        if slot_parts:
            lines.append(f"Spell Slots: {' · '.join(slot_parts)}")
    if c.equipped_weapon:
        wield = c.equipped_weapon
        if c.off_hand_weapon:
            wield += f" + {c.off_hand_weapon}"
        if c.weapon_qualities:
            wield += f" [{', '.join(c.weapon_qualities)}]"
        lines.append(f"Wielding: {wield}")
    if c.active_kata:
        lines.append(f"Active Kata: {c.active_kata}")
    enc = encounters.get(interaction.channel_id)
    if enc:
        uid = str(interaction.user.id)
        for cb in enc.combatants:
            if cb.owner_id == uid and cb.name.lower() == c.name.lower():
                conds = ", ".join(sorted(cb.conditions)) if cb.conditions else "none"
                lines.append(f"In combat: conditions: {conds}")
                break
    return lines

@client.tree.command(name="date", description="Show the current in-game Rokugani calendar date.")
async def date_cmd(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    cal = store.get_calendar(str(interaction.guild_id))
    if cal is None:
        await interaction.response.send_message(
            "No in-game date has been set yet. A DM can set it with `/dm setdate`.", ephemeral=True
        )
        return
    year, month, day = cal
    date_str = _format_rokugani_date(year, month, day)
    embed = discord.Embed(title="Rokugani Calendar", description=date_str, color=0xC4A747)
    await interaction.response.send_message(embed=embed)

def _format_dice(result: DiceResult) -> str:
    kept = " + ".join(f"**{d}**" for d in result.kept_dice) or " "
    total_kept = sum(result.kept_dice)
    line = f"[{kept}] = **{total_kept}**"
    if result.dropped_dice:
        dropped = ", ".join(f"~~{d}~~" for d in result.dropped_dice)
        line += f"   ·   dropped: {dropped}"
    extras = []
    if result.explosions:
        extras.append(f"💥 {result.explosions} explosion{'s' if result.explosions != 1 else ''}")
    if result.overflow_bonus:
        extras.append(f"+{result.overflow_bonus} overflow (10-dice cap)")
    if extras:
        line += "\n" + "   ·   ".join(extras)
    return line

async def _combat_log(guild_id: str, message: str) -> None:
    """Post a compact line to the server's combat log channel, if configured."""
    ch_id = store.get_log_channel(guild_id)
    if ch_id is None:
        return
    channel = client.get_channel(int(ch_id))
    if channel is None:
        return
    try:
        await channel.send(message[:2000])
    except Exception:
        pass

async def _xp_log(guild_id: str, message: str) -> bool:
    """Post a line to the Kami-only XP log channel. False if none is configured."""
    ch_id = store.get_xp_log_channel(guild_id)
    if ch_id is None:
        return False
    channel = client.get_channel(int(ch_id))
    if channel is None:
        return False
    try:
        await channel.send(message[:2000], allowed_mentions=discord.AllowedMentions.none())
    except Exception:
        return False
    return True

async def _xp_spend_log(interaction: discord.Interaction, rec: storage.CharacterRecord, changed: bool) -> None:
    """XP spends go to the XP log too, with the fields they bought."""
    if not changed:
        return
    guild = str(interaction.guild_id)
    snaps = store.list_undo(guild, rec.character.name, limit=1)
    diff = "; ".join(_sheet_diff(snaps[0].data, rec.character.to_dict())) if snaps and snaps[0].entity_id == rec.id else ""
    who = interaction.user.display_name + ("" if rec.owner_id == str(interaction.user.id) else " (staff)")
    await _xp_log(guild, f"XP SPEND: {who} · {rec.character.name} · {diff[:600]}")

def _save_encounter(guild_id: str, enc: encounter.Encounter) -> None:
    store.save_encounter(str(enc.channel_id), guild_id, json.dumps(enc.to_dict()))

def _delete_encounter(channel_id: int) -> None:
    store.delete_encounter(str(channel_id))

@client.tree.command(
    name="roll",
    description="Roll & Keep (L5R 4e). Example: rolled=7 kept=3, optionally against a TN.",
)
@app_commands.describe(
    rolled="Number of dice to ROLL (the X in XkY).",
    kept="Number of dice to KEEP (the Y in XkY).",
    tn="Optional Target Number to test against.",
    raises="Called Raises: each adds +5 to the TN (default 0).",
    bonus="Flat modifier added to the total (default 0).",
    emphasis="Emphasis: reroll any initial 1 once (default off).",
    unskilled="Unskilled roll: dice do NOT explode (default off).",
    reason="Optional label shown with the roll (e.g. 'Kenjutsu attack').",
)
async def roll(
    interaction: discord.Interaction,
    rolled: app_commands.Range[int, 1, 100],
    kept: app_commands.Range[int, 1, 100],
    tn: app_commands.Range[int, 1, 200] | None = None,
    raises: app_commands.Range[int, 0, 10] = 0,
    bonus: app_commands.Range[int, -100, 100] = 0,
    emphasis: bool = False,
    unskilled: bool = False,
    reason: str | None = None,
) -> None:
    explodes = not unskilled
    title = "🎲 Roll & Keep" + (f": {reason}" if reason else "")

    if tn is not None:
        outcome = engine.roll_check(rolled, kept, tn, raises, bonus, explodes, emphasis)
        result = outcome["dice"]
        success = outcome["success"]
        embed = discord.Embed(
            title=title, color=discord.Color.green() if success else discord.Color.red()
        )
        embed.add_field(name="Request", value=f"`{rolled}k{kept}`" + (f" + {bonus}" if bonus else ""), inline=True)
        embed.add_field(
            name="Target",
            value=f"TN {tn}" + (f" + {raises}×5 = **{outcome['tn']}**" if raises else ""),
            inline=True,
        )
        embed.add_field(name="Result", value=_format_dice(result), inline=False)
        verdict = "✅ **Success**" if success else "❌ **Failure**"
        embed.add_field(
            name="Total",
            value=f"**{outcome['total']}** vs TN {outcome['tn']}: {verdict} (margin {outcome['margin']:+d})",
            inline=False,
        )
    else:
        result = engine.roll_and_keep(rolled, kept, explodes, emphasis)
        total = result.total + bonus
        embed = discord.Embed(title=title, color=discord.Color.blurple())
        embed.add_field(name="Request", value=f"`{rolled}k{kept}`" + (f" + {bonus}" if bonus else ""), inline=True)
        embed.add_field(name="Result", value=_format_dice(result), inline=False)
        total_str = f"**{total}**"
        if bonus:
            total_str += f"  (dice {result.total} {'+' if bonus >= 0 else '−'} {abs(bonus)})"
        embed.add_field(name="Total", value=total_str, inline=False)

    flags = []
    if emphasis:
        flags.append("Emphasis")
    if unskilled:
        flags.append("Unskilled (no explode)")
    if flags:
        embed.set_footer(text=" · ".join(flags))

    log_total = outcome["total"] if tn is not None else total
    _log_roll(interaction.channel_id, interaction.user.display_name, title, log_total)
    await interaction.response.send_message(embed=embed)

_DICE_RE = re.compile(
    r"^(\d{1,3})\s*k\s*(\d{1,3})"
    r"(?:\s*([+-])\s*(\d{1,4}))?"
    r"$",
    re.IGNORECASE,
)

@client.tree.command(
    name="dice",
    description="Quick dice: type '5k3', '7k2+5', '4k2-3'. Shorthand for /roll.",
)
@app_commands.describe(
    expression="Dice expression like 5k3, 7k2+5, 4k2-3.",
    tn="Optional Target Number to test against.",
    reason="Optional label shown with the roll.",
)
async def dice_quick(
    interaction: discord.Interaction,
    expression: str,
    tn: app_commands.Range[int, 1, 200] | None = None,
    reason: str | None = None,
) -> None:
    m = _DICE_RE.match(expression.strip())
    if not m:
        await interaction.response.send_message(
            "Invalid format. Use `XkY` or `XkY+N` or `XkY-N`  (e.g. `5k3`, `7k2+5`).",
            ephemeral=True,
        )
        return
    rolled = int(m.group(1))
    kept = int(m.group(2))
    bonus = 0
    if m.group(3):
        val = int(m.group(4))
        bonus = val if m.group(3) == "+" else -val
    if rolled < 1 or rolled > 100 or kept < 1 or kept > 100:
        await interaction.response.send_message("Rolled and kept must be 1-100.", ephemeral=True)
        return
    title = f"🎲 {rolled}k{kept}" + (f"{bonus:+d}" if bonus else "") + (f": {reason}" if reason else "")
    if tn is not None:
        outcome = engine.roll_check(rolled, kept, tn, 0, bonus, True, False)
        result = outcome["dice"]
        success = outcome["success"]
        embed = discord.Embed(
            title=title, color=discord.Color.green() if success else discord.Color.red()
        )
        embed.add_field(name="Result", value=_format_dice(result), inline=False)
        verdict = "✅ **Success**" if success else "❌ **Failure**"
        embed.add_field(
            name="Total",
            value=f"**{outcome['total']}** vs TN {outcome['tn']}: {verdict} (margin {outcome['margin']:+d})",
            inline=False,
        )
    else:
        result = engine.roll_and_keep(rolled, kept, True, False)
        total = result.total + bonus
        embed = discord.Embed(title=title, color=discord.Color.blurple())
        embed.add_field(name="Result", value=_format_dice(result), inline=False)
        total_str = f"**{total}**"
        if bonus:
            total_str += f"  (dice {result.total} {'+' if bonus >= 0 else '−'} {abs(bonus)})"
        embed.add_field(name="Total", value=total_str, inline=False)
    _log_roll(interaction.channel_id, interaction.user.display_name, title, outcome["total"] if tn else total)
    await interaction.response.send_message(embed=embed)

async def _weapon_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    names = [w for w in combat.WEAPON_CATALOG if cur in w.lower()]
    return [app_commands.Choice(name=w, value=w) for w in sorted(names)[:25]]

async def _armor_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    names = [a for a in combat.ARMOR_CATALOG if cur in a] + (["none"] if cur in "none" else [])
    return [app_commands.Choice(name=a, value=a) for a in names][:25]

def _adv_choices(current: str, kind: str | None) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    pool = advantages.by_kind(kind) if kind else advantages.ALL
    out = []
    for r in pool:
        if cur in r["name"].lower():
            label = f"{r['name']} ({r['cost_text']})"
            out.append(app_commands.Choice(name=label[:100], value=r["name"]))
    return out[:25]

async def _advantage_autocomplete(interaction: discord.Interaction, current: str):
    return _adv_choices(current, "advantage")

async def _disadvantage_autocomplete(interaction: discord.Interaction, current: str):
    return _adv_choices(current, "disadvantage")

async def _anyadv_autocomplete(interaction: discord.Interaction, current: str):
    return _adv_choices(current, None)

async def _own_character_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    cur = current.lower().strip()
    recs = store.list_by_owner(str(interaction.guild_id), str(interaction.user.id))
    names = [r.character.name for r in recs if cur in r.character.name.lower()]
    return [app_commands.Choice(name=n, value=n) for n in sorted(names)[:25]]

async def _npc_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    cur = current.lower().strip()
    recs = store.list_by_owner(str(interaction.guild_id), NPC_OWNER)
    names = [r.character.name for r in recs if cur in r.character.name.lower()]
    return [app_commands.Choice(name=n, value=n) for n in sorted(names)[:25]]

async def _any_character_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    """Autocomplete across all PCs and NPCs in the guild."""
    if interaction.guild_id is None:
        return []
    guild = str(interaction.guild_id)
    cur = current.lower().strip()
    names: list[str] = []
    for _, rec in store.list_active_pcs(guild):
        if cur in rec.character.name.lower():
            names.append(rec.character.name)
    for rec in store.list_by_owner(guild, NPC_OWNER):
        if cur in rec.character.name.lower():
            names.append(rec.character.name)
    return [app_commands.Choice(name=n, value=n) for n in sorted(names)[:25]]

def _find_any_character(guild: str, name: str) -> storage.CharacterRecord | None:
    rec = store.get_by_name(guild, NPC_OWNER, name)
    if rec is not None:
        return rec
    for _, pc_rec in store.list_active_pcs(guild):
        if pc_rec.character.name.lower() == name.lower():
            return pc_rec
    return None

async def _creature_template_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = []
    for tid, tmpl in creature.CREATURE_CATALOG.items():
        if cur in tid or cur in tmpl.name.lower():
            out.append(app_commands.Choice(name=tmpl.name, value=tid))
    return out[:25]

async def _creature_instance_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    cur = current.lower().strip()
    recs = store.list_creatures(str(interaction.guild_id))
    names = [r.creature.name for r in recs if cur in r.creature.name.lower()]
    return [app_commands.Choice(name=n, value=n) for n in sorted(names)[:25]]

async def _school_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = [app_commands.Choice(name=s["name"], value=s["name"]) for s in schools.ALL if cur in s["name"].lower()]
    return out[:25]

async def _basic_school_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    """Starting Schools only: for character creation / NPC generation.
    Advanced Schools and Alternate Paths are transitions, not starting Schools."""
    cur = current.lower().strip()
    out = [app_commands.Choice(name=s["name"], value=s["name"]) for s in schools.basic() if cur in s["name"].lower()]
    return out[:25]

async def _family_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = [
        app_commands.Choice(name=f"{f['name']} ({f['clan']}, +1 {f['bonus_trait'].capitalize()})", value=f["name"])
        for f in families.ALL if cur in f["name"].lower() or cur in f["clan"].lower()
    ]
    return out[:25]

async def _spell_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = [
        app_commands.Choice(name=f"{s['name']} ({s['element']} {s['mastery']})", value=s["name"])
        for s in spells.ALL if cur in s["name"].lower()
    ]
    return out[:25]

async def _kata_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = [
        app_commands.Choice(name=f"{k['name']} ({k['element']} {k['mastery']})", value=k["name"])
        for k in kata.ALL if cur in k["name"].lower()
    ]
    return out[:25]

async def _kiho_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = [
        app_commands.Choice(name=f"{k['name']} ({k['element']} {k['mastery']})", value=k["name"])
        for k in kiho.ALL if cur in k["name"].lower()
    ]
    return out[:25]


async def _tattoo_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    from l5r_rules import tattoo_catalog
    return [
        app_commands.Choice(name=t["name"], value=key)
        for key, t in tattoo_catalog.TATTOO_CATALOG.items() if cur in key
    ][:25]

async def _skill_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    """Autocomplete skill names from the caller's active character (or the
    member/NPC target if those params are already filled in)."""
    if interaction.guild_id is None:
        return []
    guild = str(interaction.guild_id)
    cur = current.lower().strip()
    ns = interaction.namespace
    char = None
    is_npc = getattr(ns, "is_npc", False)
    name_val = getattr(ns, "name", None)
    member_val = getattr(ns, "member", None)
    if is_npc and name_val:
        rec = store.get_by_name(guild, NPC_OWNER, name_val)
        if rec:
            char = rec.character
    elif member_val is not None:
        mid = str(member_val.id) if hasattr(member_val, "id") else str(member_val)
        rec = store.get_active(guild, mid)
        if rec:
            char = rec.character
    if char is None:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec:
            char = rec.character
    if char is None or not char.skills:
        return []
    skills = sorted(char.skills.keys())
    out = [
        app_commands.Choice(name=f"{s} ({char.skills[s]})", value=s)
        for s in skills if cur in s.lower()
    ]
    return out[:25]

def _apply_numeric_field(c: Character, field: str, value: float) -> None:
    """Set one numeric sheet field with clamping. Shared by /stat set and /npc-edit set."""
    if field in ("honor", "glory", "status", "infamy"):
        setattr(c, field, max(0.0, min(10.0, float(value))))
    elif field == "taint":
        c.taint = max(0.0, float(value))
    elif field == "koku":
        c.koku = float(value)
    elif field == "age":
        c.age = max(0, int(value))
    elif field == "school_rank":
        c.school_rank = max(1, min(10, int(value)))
    elif field == "void_points_max":
        c.max_void_points = max(0, int(value))
        c.current_void_points = min(c.current_void_points, c.max_void_points)
    elif field == "void_points_current":
        c.current_void_points = max(0, min(int(value), c.max_void_points))
    elif field == "armor_tn_bonus":
        c.armor_tn_bonus = max(0, int(value))
    elif field == "armor_reduction":
        c.armor_reduction = max(0, int(value))

def _check_insight_rank_advance(c: Character) -> str:
    result = stats.check_insight_rank_advance(c)
    if result is None:
        return ""
    old, new_rank = result
    return (
        f"\n\U0001F393 **School Rank {old} → {new_rank}!** "
        f"(Insight {stats.insight(c)}). "
        f"Use `/sheet learn` to learn your Rank {new_rank} technique."
    )

# ===========================================================================
# /sheet group
# ===========================================================================
sheet = app_commands.Group(name="sheet", description="Create and manage L5R 4e character sheets.")
sheet_void = app_commands.Group(name="void", description="Void Point management: spend, refresh, status.", parent=sheet)
sheet_kata_grp = app_commands.Group(name="kata", description="Record and activate Kata.", parent=sheet)
sheet_kiho_grp = app_commands.Group(name="kiho", description="Record and activate Kiho.", parent=sheet)
sheet_tattoo_grp = app_commands.Group(name="tattoo", description="Manage Togashi tattoos.", parent=sheet)
sheet_data = app_commands.Group(name="data", description="Export / import character sheets.", parent=sheet)
stat_group = app_commands.Group(name="stat", description="Staff edits to a character sheet: traits, skills, armor, qualities, advantages.")
xp_group = app_commands.Group(name="xp", description="Grant and spend Experience to advance characters.")

_SCHOOL_CHOICES = [app_commands.Choice(name=s, value=s) for s in enums.SCHOOL_TYPES]
_TRAIT_CHOICES = [
    app_commands.Choice(name=("Void" if t == "void" else t.capitalize()), value=t)
    for t in enums.TRAITS
]
_SET_FIELDS = [
    "honor", "glory", "status", "infamy", "taint", "koku", "age", "school_rank",
    "void_points_current", "void_points_max", "armor_tn_bonus", "armor_reduction",
]
_SET_CHOICES = [app_commands.Choice(name=f, value=f) for f in _SET_FIELDS]

@sheet.command(name="create", description="Create a new character — opens a private wizard channel.")
async def sheet_create(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    await _start_chargen_wizard(interaction)

# ---------------------------------------------------------------------------
# /sheet wizard: guided step-by-step character creation
# ---------------------------------------------------------------------------
_GREAT_CLANS = ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn", "Ronin", "Imperial"]
# Owner ruling 2026-09-16: Mantis, Fox, Centipede and Wasp are minor clans in this setting.
_MINOR_CLANS = ["Badger", "Bat", "Boar", "Centipede", "Dragonfly", "Fox", "Hare", "Mantis", "Monkey", "Oriole", "Ox",
                "Sparrow", "Tiger", "Tortoise", "Wasp"]
_ALL_SCHOOL_CLANS = sorted({s["clan"] for s in schools.ALL if s.get("category", "basic") == "basic"})

def _wizard_embed(state: dict) -> discord.Embed:
    """Build a progress embed from the wizard state dict."""
    embed = discord.Embed(title=f"Character Wizard: {state['name']}", color=discord.Color.gold())
    lines: list[str] = []
    if state.get("clan"):
        lines.append(f"**Clan: ** {state['clan']}")
    if state.get("family_name"):
        fam = families.get(state["family_name"])
        bonus = f" (+1 {fam['bonus_trait'].capitalize()})" if fam else ""
        lines.append(f"**Family: ** {state['family_name']}{bonus}")
    if state.get("heritage_result"):
        lines.append(f"**Heritage: ** {state['heritage_result']}")
    if state.get("different_school"):
        lines.append("**Different School** advantage (5 pts)")
    if state.get("school_name"):
        sch = schools.get(state["school_name"])
        if sch:
            ben = schools.parse_benefit(sch.get("benefit", ""))
            ben_str = f" (+{ben[1]} {ben[0].capitalize()})" if ben else ""
            lines.append(f"**School: ** {sch['name']}{ben_str}")
    embed.description = "\n".join(lines) if lines else "Starting..."
    return embed

class _ClanSelect(discord.ui.Select):
    """One of two menus on the clan step: the Great Clans, or the minor clans and others."""

    def __init__(self, state: dict, great: bool = True):
        self.state = state
        clans = schools.great_clans() if great else schools.minor_clans()
        options = [discord.SelectOption(label=c) for c in clans[:25]]
        super().__init__(placeholder="Great Clan..." if great else "Minor clan, Brotherhood, Imperial or Ronin...",
                         options=options, row=0 if great else 1)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        self.state["clan"] = self.values[0]
        clan_families = families.by_clan(self.state["clan"])
        if clan_families:
            view = _WizardView(self.state)
            view.add_item(_FamilySelect(self.state, clan_families))
            total = "10" if self.state.get("full_wizard") else "5"
            await interaction.response.edit_message(
                content=f"**Step 2/{total}**: Choose your Family.",
                embed=_active_embed(self.state), view=view,
            )
        else:
            self.state["family_name"] = ""
            await _go_to_heritage_or_school(interaction, self.state)

class _FamilySelect(discord.ui.Select):
    def __init__(self, state: dict, clan_families: list[dict]):
        self.state = state
        options = [
            discord.SelectOption(label=f["name"], description=f"+1 {f['bonus_trait'].capitalize()}")
            for f in clan_families
        ][:25]
        super().__init__(placeholder="Choose your Family...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        self.state["family_name"] = self.values[0]
        await _go_to_heritage_or_school(interaction, self.state)

async def _go_to_heritage_or_school(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "heritage"
    clan = state["clan"]
    if clan in heritage.HERITAGE_TABLES:
        view = _WizardView(state)
        roll_btn = discord.ui.Button(label="Roll Heritage", style=discord.ButtonStyle.primary, emoji="\U0001f3b2")
        skip_btn = discord.ui.Button(label="Skip", style=discord.ButtonStyle.secondary)

        async def on_roll(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            result = heritage.roll_heritage(clan)
            state["heritage_result"] = f"{result['name']}: {result['effect']}"
            state["heritage_grants"] = result.get("grants", {})
            await _go_to_school_choice(btn_inter, state)

        async def on_skip(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            await _go_to_school_choice(btn_inter, state)

        roll_btn.callback = on_roll
        skip_btn.callback = on_skip
        view.add_item(roll_btn)
        view.add_item(skip_btn)
        total = "10" if state.get("full_wizard") else "5"
        await interaction.response.edit_message(
            content=f"**Step 3/{total}**: Heritage Roll (optional).",
            embed=_active_embed(state), view=view,
        )
    else:
        await _go_to_school_choice(interaction, state)

async def _go_to_school_choice(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "school"
    view = _WizardView(state)
    same_btn = discord.ui.Button(label=f"{state['clan']} Schools", style=discord.ButtonStyle.primary)
    diff_btn = discord.ui.Button(label="Different School (5 pts)", style=discord.ButtonStyle.secondary)

    async def on_same(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        state["different_school"] = False
        await _show_school_select(btn_inter, state, state["clan"])

    async def on_diff(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        state["different_school"] = True
        view2 = _WizardView(state)
        view2.add_item(_SchoolClanSelect(state))
        total = "10" if state.get("full_wizard") else "5"
        await btn_inter.response.edit_message(
            content=f"**Step 4/{total}**: Pick the clan whose school you want to attend.",
            embed=_active_embed(state), view=view2,
        )

    same_btn.callback = on_same
    diff_btn.callback = on_diff
    view.add_item(same_btn)
    view.add_item(diff_btn)
    total = "10" if state.get("full_wizard") else "5"
    heritage_step = "4" if state["clan"] in heritage.HERITAGE_TABLES else "3"
    step = f"{heritage_step}/{total}"
    await interaction.response.edit_message(
        content=f"**Step {step}**: Same-clan school or Different School?",
        embed=_active_embed(state), view=view,
    )

class _SchoolClanSelect(discord.ui.Select):
    def __init__(self, state: dict):
        self.state = state
        options = [discord.SelectOption(label=c) for c in _ALL_SCHOOL_CLANS]
        super().__init__(placeholder="Pick school clan...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _show_school_select(interaction, self.state, self.values[0])

async def _show_school_select(interaction: discord.Interaction, state: dict, school_clan: str) -> None:
    basic_schools = schools.basic_for_clan(school_clan)
    if not basic_schools:
        await interaction.response.edit_message(
            content=f"No basic schools found for **{school_clan}**. Pick **Different School** and choose another clan's school.",
            embed=_active_embed(state), view=interaction.message.view,
        )
        return
    view = _WizardView(state)
    view.add_item(_SchoolSelect(state, basic_schools))
    total = "10" if state.get("full_wizard") else "5"
    await interaction.response.edit_message(
        content=f"**Step 4/{total}**: Choose your School ({school_clan}).",
        embed=_active_embed(state), view=view,
    )

class _SchoolSelect(discord.ui.Select):
    def __init__(self, state: dict, school_list: list[dict]):
        self.state = state
        options = []
        for s in school_list[:25]:
            kw = ", ".join(s.get("keywords", []))
            ben = s.get("benefit", "")[:50]
            desc = f"{kw}: {ben}" if kw else ben
            options.append(discord.SelectOption(label=s["name"][:100], description=desc[:100]))
        super().__init__(placeholder="Choose your School...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        self.state["school_name"] = self.values[0]
        if self.state.get("full_wizard"):
            sch = schools.get(self.values[0])
            if sch:
                wc_slots = _expand_wildcard_slots(sch)
                if wc_slots:
                    self.state["wildcard_slots"] = wc_slots
                    self.state["wildcard_picks"] = []
                    await _chargen_wildcards(interaction, self.state)
                    return
            await _chargen_traits(interaction, self.state)
        else:
            await _show_confirmation(interaction, self.state)

async def _show_confirmation(interaction: discord.Interaction, state: dict) -> None:
    view = _WizardView(state)
    create_btn = discord.ui.Button(label="Create Character", style=discord.ButtonStyle.success, emoji="✅")
    cancel_btn = discord.ui.Button(label="Cancel", style=discord.ButtonStyle.danger)

    async def on_create(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        char = Character(name=state["name"], clan=state.get("clan", ""), family=state.get("family_name", ""),
                         school="", school_type="Bushi")
        family_entry = families.get(state["family_name"]) if state.get("family_name") else None
        if family_entry:
            families.apply_to_character(char, family_entry)
            if not char.clan:
                char.clan = family_entry["clan"]
        applied = schools.get(state["school_name"])
        report = schools.apply_to_character(char, applied) if applied else None
        try:
            record = store.create_character(state["guild_id"], state["user_id"], char)
        except storage.DuplicateNameError:
            await btn_inter.response.edit_message(
                content=f"You already have a character named **{state['name']}**. Use a different name.",
                embed=None, view=None,
            )
            return
        store.set_active(state["guild_id"], state["user_id"], record.id)
        bits = []
        if applied:
            bits.append(f"School **{applied['name']}**")
        if report and report.get("benefit"):
            bits.append(f"Benefit {report['benefit']}")
        if report and report.get("skills"):
            bits.append(f"{len(report['skills'])} school skills")
        if report and report.get("wildcards"):
            bits.append("choose: " + "; ".join(report["wildcards"]))
        if report and report.get("outfit"):
            bits.append(f"Outfit: {len(report['outfit'])} items")
        if state.get("different_school"):
            bits.append("**Different School** advantage recorded")
        if state.get("heritage_result"):
            bits.append(f"Heritage: {state['heritage_result'][:80]}")
        summary = ", ".join(bits) + "." if bits else ""
        await btn_inter.response.edit_message(
            content=f"Created **{state['name']}** and set as active. {summary}\n"
                    f"Use `/sheet learn` to record your Rank-1 technique.",
            embed=build_sheet_embed(record), view=None,
        )

    async def on_cancel(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await btn_inter.response.edit_message(content="Character creation cancelled.", embed=None, view=None)

    create_btn.callback = on_create
    cancel_btn.callback = on_cancel
    view.add_item(create_btn)
    view.add_item(cancel_btn)

    preview_char = Character(name=state["name"], clan=state.get("clan", ""), family=state.get("family_name", ""),
                             school="", school_type="Bushi")
    family_entry = families.get(state["family_name"]) if state.get("family_name") else None
    if family_entry:
        families.apply_to_character(preview_char, family_entry)
    applied = schools.get(state["school_name"])
    if applied:
        schools.apply_to_character(preview_char, applied)
    preview_embed = _wizard_embed(state)
    preview_embed.title = f"Confirm: {state['name']}"
    preview_embed.color = discord.Color.green()
    if state.get("heritage_result"):
        preview_embed.add_field(name="Heritage", value=state["heritage_result"][:1024], inline=False)

    await interaction.response.edit_message(
        content="Review your character and confirm.",
        embed=preview_embed, view=view,
    )

# Character-creation wizard views: one live view per (guild, user); an hour of
# idle time; on expiry the message gets a persistent Resume button; state is
# saved on every render so a wizard survives idling and bot restarts.
CHARGEN_IDLE_SECONDS: int = 3600
_active_wizard_views: dict[tuple[str, str], "discord.ui.View"] = {}

_CHARGEN_STEP_LABELS: dict[str, str] = {
    "clan": "1/10 Clan", "heritage": "3/10 Heritage", "school": "4/10 School", "wildcards": "4/10 School skills",
    "traits": "5/10 Traits", "advantages": "6/10 Advantages", "disadvantages": "7/10 Disadvantages",
    "skills": "8/10 Skills", "spells": "9/10 Spells", "review": "10/10 Review",
}


def _cg_save(state: dict) -> None:
    """Persist the wizard state (called on every render)."""
    if not state.get("full_wizard"):
        return
    try:
        store.save_creation_state(str(state["guild_id"]), str(state["user_id"]), json.dumps(state, default=str))
    except (TypeError, ValueError, KeyError):
        log.warning("Could not save chargen state for %s", state.get("user_id"), exc_info=True)


class _WizardView(discord.ui.View):
    def __init__(self, state: dict):
        super().__init__(timeout=CHARGEN_IDLE_SECONDS)
        self.state = state
        key = (str(state.get("guild_id", "")), str(state.get("user_id", "")))
        prev = _active_wizard_views.get(key)
        if prev is not None and prev is not self:
            prev.stop()  # an older step's view must not time out onto the current message
        _active_wizard_views[key] = self

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.message is not None:
            self.state["message_id"] = interaction.message.id
            self.state["channel_id"] = interaction.channel_id
        return True

    async def on_timeout(self) -> None:
        if not self.state.get("full_wizard") or self.state.get("submitted"):
            return
        key = (str(self.state.get("guild_id", "")), str(self.state.get("user_id", "")))
        if _active_wizard_views.get(key) is not self:
            return
        mid, cid = self.state.get("message_id"), self.state.get("channel_id")
        if not mid or not cid:
            return
        channel = client.get_channel(int(cid))
        if channel is None:
            return
        try:
            msg = await channel.fetch_message(int(mid))
        except discord.HTTPException:
            return
        view = _ChargenResumeView(str(self.state["guild_id"]), str(self.state["user_id"]))
        try:
            await msg.edit(
                content=(msg.content or "") + "\n\n⌛ This wizard has been idle for an hour. Press **Resume** to carry on where you left off.",
                view=view,
            )
            await view.persist(msg)
        except discord.HTTPException:
            pass


_ChargenView = _WizardView


class _ChargenResumeView(views_base.PersistentView):
    """A single Resume button that reloads a saved wizard and shows its last step."""

    KIND = "chargen_resume"

    def __init__(self, guild_id: str, user_id: str) -> None:
        super().__init__()
        self.guild_id = guild_id
        self.user_id = user_id

    @discord.ui.button(label="Resume wizard", style=discord.ButtonStyle.primary, emoji="▶️")
    async def resume(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if str(interaction.user.id) != self.user_id and not _is_dm(interaction):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        if not self.claim():
            await interaction.response.send_message("Already resumed.", ephemeral=True)
            return
        raw = store.get_creation_state(self.guild_id, self.user_id)
        if not raw:
            self._disable()
            await interaction.response.edit_message(
                content="No character creation in progress. Start one with `/sheet create`.", view=self,
            )
            return
        state = json.loads(raw)
        self._disable()
        if state.get("submitted"):
            await interaction.response.edit_message(
                content=_SUBMITTED_TEXT.format(name=state.get("name", "your character")), view=self,
            )
            return
        await _cg_resume(interaction, state)

# ---------------------------------------------------------------------------
# Full character-creation wizard (runs in a private channel via /submit)
# ---------------------------------------------------------------------------
_CHARGEN_XP = 40
_MAX_DISADVANTAGE_XP = 10
_EMPHASIS_XP_COST = 2
_CHARGEN_TRAIT_CAP = 4   # L5R 4e: no starting character may begin with any ability above 4
_CHARGEN_SKILL_CAP = 4

_SKILL_CATEGORIES: dict[str, list[str]] = {
    "Bugei": [
        "Athletics", "Battle", "Defense", "Horsemanship", "Hunting",
        "Iaijutsu", "Jiujutsu", "Kenjutsu", "Knives", "Kyujutsu",
        "Naginatajutsu", "Polearms", "Spears", "Staves", "War Fan",
        "Chain Weapons",
    ],
    "High": [
        "Artisan", "Calligraphy", "Courtier", "Divination", "Etiquette",
        "Games", "Investigation", "Lore", "Medicine", "Meditation",
        "Perform", "Sincerity", "Spellcraft", "Tea Ceremony", "Theology",
    ],
    "Low": [
        "Acting", "Commerce", "Engineering", "Forgery", "Intimidation",
        "Locksmith", "Sleight of Hand", "Stealth", "Temptation",
    ],
    "Merchant": [
        "Animal Handling", "Craft", "Sailing",
    ],
}

_WEAPON_SKILLS: list[str] = [
    "Chain Weapons", "Iaijutsu", "Kenjutsu", "Knives", "Kyujutsu",
    "Naginatajutsu", "Polearms", "Spears", "Staves", "War Fan",
]
_LORE_SKILLS: list[str] = [
    "Lore: Architecture", "Lore: Bushido", "Lore: Elements",
    "Lore: Ghosts", "Lore: Heraldry", "Lore: History", "Lore: Law",
    "Lore: Maho", "Lore: Nature", "Lore: Nonhumans",
    "Lore: Shadowlands", "Lore: Spirit Realms", "Lore: Theology",
    "Lore: Underworld", "Lore: War",
]
_CRAFT_SKILLS: list[str] = [
    "Craft: Armorsmithing", "Craft: Blacksmithing", "Craft: Bowyer",
    "Craft: Brewing", "Craft: Carpentry", "Craft: Cartography",
    "Craft: Cooking", "Craft: Farming", "Craft: Fishing",
    "Craft: Mining", "Craft: Pottery", "Craft: Shipbuilding",
    "Craft: Weaponsmithing",
]
_ARTISAN_SKILLS: list[str] = [
    "Artisan: Gardening", "Artisan: Ikebana", "Artisan: Origami",
    "Artisan: Painting", "Artisan: Poetry", "Artisan: Sculpture",
]
_PERFORM_SKILLS: list[str] = [
    "Perform: Biwa", "Perform: Dance", "Perform: Flute",
    "Perform: Oratory", "Perform: Song", "Perform: Storytelling",
]

_ALL_CHARGEN_SKILLS: list[str] = sorted(
    set(s for cat in _SKILL_CATEGORIES.values() for s in cat)
)

_SUBCAT_MAP: dict[str, list[str]] = {
    "weapon": _WEAPON_SKILLS,
    "lore": _LORE_SKILLS,
    "craft": _CRAFT_SKILLS,
    "artisan": _ARTISAN_SKILLS,
    "perform": _PERFORM_SKILLS,
}

_CHARGEN_SKILL_CATS: dict[str, list[str]] = {
    "Bugei": [
        "Athletics", "Battle", "Defense", "Horsemanship", "Hunting",
        "Iaijutsu", "Jiujutsu", "Kenjutsu", "Knives", "Kyujutsu",
        "Naginatajutsu", "Polearms", "Spears", "Staves", "War Fan",
        "Chain Weapons",
    ],
    "High": [
        "Calligraphy", "Courtier", "Divination", "Etiquette", "Games",
        "Investigation", "Medicine", "Meditation", "Sincerity",
        "Spellcraft", "Tea Ceremony", "Theology",
    ],
    "Low": [
        "Acting", "Commerce", "Engineering", "Forgery", "Intimidation",
        "Locksmith", "Sleight of Hand", "Stealth", "Temptation",
    ],
    "Merchant": [
        "Animal Handling", "Sailing",
    ],
    "Lore": _LORE_SKILLS,
    "Craft": _CRAFT_SKILLS,
    "Artisan": _ARTISAN_SKILLS,
    "Perform": _PERFORM_SKILLS,
}


def _wildcard_count(text: str) -> int:
    low = text.lower().strip()
    _wn = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5}
    if re.match(r"\w+\s+ranks?\s+in\b", low):
        m = re.search(r"any\s+(\w+)\b", low)
        if m:
            return _wn.get(m.group(1), int(m.group(1)) if m.group(1).isdigit() else 1)
        return 1
    m = re.search(r"\bany\s+(\d+)\b", low)
    if m:
        return int(m.group(1))
    m = re.search(r"\b(?:pick|choose)\s+(\d+)\b", low)
    if m:
        return int(m.group(1))
    for word, n in _wn.items():
        if re.search(r"\b" + word + r"\b", low):
            return n
    return 1


def _wildcard_rank(text: str) -> int:
    m = re.match(r"(\w+)\s+ranks?\s+in\b", text.lower().strip())
    if m:
        return {"one": 1, "two": 2, "three": 3}.get(m.group(1),
               int(m.group(1)) if m.group(1).isdigit() else 1)
    return 1


def _wildcard_eligible(text: str) -> list[str]:
    low = text.lower().strip()
    if "|" in low:
        low = low.split("|")[0].strip()
    if "ninja weapon" in low:
        return []
    if "from:" in low:
        return list(_ALL_CHARGEN_SKILLS)
    negate: set[str] = set()
    if "non-high" in low or "not be a high" in low:
        negate.add("High")
    if "non-low" in low or "not be a low" in low:
        negate.add("Low")
    if "non-bugei" in low or "not be a bugei" in low:
        negate.add("Bugei")
    if "non-merchant" in low or "not be a merchant" in low:
        negate.add("Merchant")
    if negate:
        return sorted(s for cat, skills in _SKILL_CATEGORIES.items()
                      if cat not in negate for s in skills)
    main_cats: list[str] = []
    for key, label in [("bugei", "Bugei"), ("high", "High"),
                       ("low", "Low"), ("merchant", "Merchant")]:
        if re.search(r"\b" + key + r"\b", low):
            main_cats.append(label)
    sub_lists: list[list[str]] = []
    for sub_name, sub_skills in _SUBCAT_MAP.items():
        if re.search(r"\b" + sub_name + r"\b", low):
            sub_lists.append(sub_skills)
    result: list[str] = []
    for cn in main_cats:
        result.extend(_SKILL_CATEGORIES.get(cn, []))
    for sl in sub_lists:
        result.extend(sl)
    if result:
        return sorted(set(result))
    return list(_ALL_CHARGEN_SKILLS)


def _expand_wildcard_slots(school: dict) -> list[dict]:
    eff_skills, _, _ = schools.effective_fields(school)
    _, wildcards = schools.parse_skills(eff_skills)
    slots: list[dict] = []
    for wc in wildcards:
        eligible = _wildcard_eligible(wc)
        if not eligible:
            continue
        count = _wildcard_count(wc)
        rank = _wildcard_rank(wc)
        label = wc.split("|")[0].strip() if "|" in wc else wc
        for _ in range(count):
            slots.append({"label": label, "eligible": eligible, "rank": rank})
    return slots


def _wildcard_cat_groups(eligible: list[str]) -> dict[str, list[str]]:
    cat_lookup: dict[str, str] = {}
    for cat, skills in _SKILL_CATEGORIES.items():
        for s in skills:
            cat_lookup[s] = cat
    groups: dict[str, list[str]] = {}
    for s in eligible:
        if ":" in s:
            prefix = s.split(":")[0]
            groups.setdefault(prefix, []).append(s)
        elif s in cat_lookup:
            groups.setdefault(cat_lookup[s], []).append(s)
        else:
            groups.setdefault("Other", []).append(s)
    return groups


def _parse_spell_allotment(school: dict) -> dict[str, int] | None:
    """Parse starting spell allotment from a shugenja school.

    Returns {element: count} or None if not a shugenja school.
    Sense/Commune/Summon are auto-granted and not counted here.
    """
    aff = school.get("affinity", "")
    if not aff:
        return None
    if "|" in aff:
        _, spell_part = aff.split("|", 1)
        spell_part = spell_part.strip()
        if spell_part.lower().startswith("starting spells:"):
            spell_part = spell_part[len("Starting Spells:"):].strip()
        allot: dict[str, int] = {}
        for chunk in spell_part.split(","):
            chunk = chunk.strip()
            if chunk.lower() in ("sense", "commune", "summon"):
                continue
            parts = chunk.split(None, 1)
            if len(parts) == 2 and parts[0].isdigit():
                allot[parts[1]] = int(parts[0])
        return allot if allot else None
    elements = ["Air", "Earth", "Fire", "Water"]
    aff_lower = aff.lower()
    found: list[tuple[int, str]] = []
    for el in elements:
        pos = aff_lower.find(el.lower())
        if pos >= 0:
            found.append((pos, el))
    if not found:
        return None
    found.sort()
    affinity_el = found[0][1]
    allot = {affinity_el: 3}
    for el in elements:
        if el != affinity_el:
            allot[el] = 1
    return allot


def _build_base_char(state: dict) -> Character:
    """Build a Character with family+school applied (no XP purchases)."""
    char = Character(name=state["name"], clan=state.get("clan", ""),
                     family=state.get("family_name", ""), school="", school_type="Bushi")
    family_entry = families.get(state["family_name"]) if state.get("family_name") else None
    if family_entry:
        families.apply_to_character(char, family_entry)
        if not char.clan:
            char.clan = family_entry["clan"]
    applied = schools.get(state["school_name"]) if state.get("school_name") else None
    if applied:
        schools.apply_to_character(char, applied)
        if state.get("clan"):
            char.clan = state["clan"]  # a Fox studying at a school filed under Mantis is still a Fox
    for pick in state.get("wildcard_picks", []):
        sk = pick["skill"]
        rk = pick["rank"]
        char.skills[sk] = max(char.skills.get(sk, 0), rk)
    return char


def _calc_chargen_xp(state: dict) -> tuple[int, int]:
    """Return (xp_spent, xp_remaining) from chargen purchases."""
    spent = 0
    if state.get("different_school"):
        spent += 5
    base_char = _build_base_char(state)
    for trait, ranks in state.get("trait_purchases", {}).items():
        base_val = base_char.void_ring if trait == "void" else base_char.get_trait(trait)
        mult = advancement.VOID_XP_MULT if trait == "void" else advancement.TRAIT_XP_MULT
        for i in range(ranks):
            spent += (base_val + i + 1) * mult
    for adv in state.get("advantages_chosen", []):
        spent += adv["points"]
    for skill, ranks in state.get("skill_purchases", {}).items():
        base_val = base_char.skills.get(skill, 0)
        for i in range(ranks):
            spent += (base_val + i + 1) * advancement.SKILL_XP_MULT
    spent += len(state.get("emphasis_purchases", [])) * _EMPHASIS_XP_COST
    disadv_xp = sum(d["points"] for d in state.get("disadvantages_chosen", []))
    disadv_xp = min(disadv_xp, _MAX_DISADVANTAGE_XP)
    return spent, _CHARGEN_XP + disadv_xp - spent


def _chargen_embed(state: dict) -> discord.Embed:
    """Full-wizard progress embed showing all chargen state."""
    _cg_save(state)
    spent, remaining = _calc_chargen_xp(state)
    embed = discord.Embed(
        title=f"Character Creation: {state['name']}",
        color=discord.Color.gold(),
    )
    lines: list[str] = []
    if state.get("clan"):
        lines.append(f"**Clan:** {state['clan']}")
    if state.get("family_name"):
        fam = families.get(state["family_name"])
        bonus = f" (+1 {fam['bonus_trait'].capitalize()})" if fam else ""
        lines.append(f"**Family:** {state['family_name']}{bonus}")
    if state.get("heritage_result"):
        lines.append(f"**Heritage:** {state['heritage_result'][:80]}")
    if state.get("different_school"):
        lines.append("**Different School** (5 XP)")
    if state.get("school_name"):
        sch = schools.get(state["school_name"])
        if sch:
            ben = schools.parse_benefit(sch.get("benefit", ""))
            ben_str = f" (+{ben[1]} {ben[0].capitalize()})" if ben else ""
            lines.append(f"**School:** {sch['name']}{ben_str}")

    if state.get("wildcard_picks"):
        wl = ", ".join(f"{p['skill']} {p['rank']}" for p in state["wildcard_picks"])
        lines.append(f"**Starting Skill Picks:** {wl}")

    if state.get("trait_purchases"):
        tp = ", ".join(f"{t.capitalize()} +{r}" for t, r in state["trait_purchases"].items())
        lines.append(f"**Trait Raises:** {tp}")
    if state.get("advantages_chosen"):
        al = ", ".join(f"{a['name']} ({a['points']})" for a in state["advantages_chosen"])
        lines.append(f"**Advantages:** {al}")
    if state.get("disadvantages_chosen"):
        dl = ", ".join(f"{d['name']} ({d['points']})" for d in state["disadvantages_chosen"])
        lines.append(f"**Disadvantages:** {dl}")
    if state.get("skill_purchases"):
        sl = ", ".join(f"{s} +{r}" for s, r in state["skill_purchases"].items())
        lines.append(f"**Skill Purchases:** {sl}")
    if state.get("emphasis_purchases"):
        el = ", ".join(f"{e['skill']}: {e['emphasis']}" for e in state["emphasis_purchases"])
        lines.append(f"**Emphases:** {el}")
    if state.get("chosen_spells"):
        lines.append(f"**Spells:** {', '.join(state['chosen_spells'])}")

    lines.append(f"\n**XP:** {remaining} remaining ({spent} spent of {_CHARGEN_XP}"
                 + (f" + {min(sum(d['points'] for d in state.get('disadvantages_chosen', [])), _MAX_DISADVANTAGE_XP)} from disadv." if state.get("disadvantages_chosen") else "")
                 + ")")
    embed.description = "\n".join(lines) if lines else "Starting..."
    return embed


def _active_embed(state: dict) -> discord.Embed:
    """Choose the right embed based on wizard mode."""
    if state.get("full_wizard"):
        return _chargen_embed(state)
    return _wizard_embed(state)


def _materialize_character(state: dict) -> Character:
    """Build the final Character with all XP purchases applied."""
    char = _build_base_char(state)

    for trait, ranks in state.get("trait_purchases", {}).items():
        for _ in range(ranks):
            advancement.apply_trait_raise(char, trait)

    for skill, ranks in state.get("skill_purchases", {}).items():
        for _ in range(ranks):
            advancement.apply_skill_raise(char, skill)

    for adv in state.get("advantages_chosen", []):
        if adv["name"] not in char.advantages:
            char.advantages.append(adv["name"])

    for dis in state.get("disadvantages_chosen", []):
        if dis["name"] not in char.disadvantages:
            char.disadvantages.append(dis["name"])

    for emp in state.get("emphasis_purchases", []):
        lst = char.emphases.setdefault(emp["skill"], [])
        if emp["emphasis"] not in lst:
            lst.append(emp["emphasis"])

    for spell_name in state.get("chosen_spells", []):
        if spell_name not in char.spells_known:
            char.spells_known.append(spell_name)

    sch = schools.get(state.get("school_name", "")) if state.get("school_name") else None
    if sch and sch.get("affinity"):
        allot = _parse_spell_allotment(sch)
        if allot:
            for base_spell in ("Sense", "Commune", "Summon"):
                if base_spell not in char.spells_known:
                    char.spells_known.insert(0, base_spell)

    heritage_grants = state.get("heritage_grants", {})
    if heritage_grants:
        heritage.apply_heritage(char, {"grants": heritage_grants})

    spent, remaining = _calc_chargen_xp(state)
    char.xp_spent = float(spent)
    char.xp = float(max(0, remaining))

    if state.get("concept"):
        char.notes = state["concept"]

    return char


# --- Step 4b: Wildcard school skill picks ---
class _WildcardSkillSelect(discord.ui.Select):
    def __init__(self, state: dict, eligible: list[str], slot_idx: int, rank: int):
        self.state = state
        self.slot_idx = slot_idx
        self.rank = rank
        options = [discord.SelectOption(label=s) for s in eligible[:25]]
        super().__init__(placeholder="Choose a skill...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        picks = self.state.setdefault("wildcard_picks", [])
        if len(picks) == self.slot_idx:  # a stale (double-clicked) menu must not fill the slot twice
            picks.append({"skill": self.values[0], "rank": self.rank})
        await _chargen_wildcards(interaction, self.state)


class _WildcardCategorySelect(discord.ui.Select):
    def __init__(self, state: dict, eligible: list[str], slot_idx: int):
        self.state = state
        self.eligible = eligible
        self.slot_idx = slot_idx
        groups = _wildcard_cat_groups(eligible)
        options = [discord.SelectOption(label=cat, description=f"{len(skills)} skills")
                   for cat, skills in sorted(groups.items())]
        super().__init__(placeholder="Choose a category first...", options=options[:25])

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_wildcard_category(interaction, self.state, self.slot_idx, self.values[0])


async def _chargen_wildcards(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "wildcards"
    slots = state.get("wildcard_slots", [])
    picks = state.get("wildcard_picks", [])
    slot_idx = len(picks)

    if slot_idx >= len(slots):
        await _chargen_traits(interaction, state)
        return

    slot = slots[slot_idx]
    already = {p["skill"] for p in picks}
    eligible = [s for s in slot["eligible"] if s not in already]

    if not eligible:
        picks.append({"skill": "(auto-skipped)", "rank": slot["rank"]})
        await _chargen_wildcards(interaction, state)
        return

    view = _WizardView(state)
    rank_note = f" at Rank {slot['rank']}" if slot["rank"] > 1 else ""

    if len(eligible) <= 25:
        view.add_item(_WildcardSkillSelect(state, eligible, slot_idx, slot["rank"]))
    else:
        view.add_item(_WildcardCategorySelect(state, eligible, slot_idx))

    if picks:
        undo_btn = discord.ui.Button(label="Undo Last", style=discord.ButtonStyle.secondary, row=2)

        async def on_undo(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            state["wildcard_picks"].pop()
            await _chargen_wildcards(btn_inter, state)

        undo_btn.callback = on_undo
        view.add_item(undo_btn)

    skip_btn = discord.ui.Button(label="Skip Remaining", style=discord.ButtonStyle.secondary, row=2)

    async def on_skip(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        state["wildcard_slots"] = slots[:len(state.get("wildcard_picks", []))]
        await _chargen_traits(btn_inter, state)

    skip_btn.callback = on_skip
    view.add_item(skip_btn)

    total = len(slots)
    await interaction.response.edit_message(
        content=f"**Starting Skills — Pick {slot_idx + 1} of {total}**{rank_note}\n{slot['label']}",
        embed=_active_embed(state), view=view,
    )


async def _chargen_wildcard_category(interaction: discord.Interaction, state: dict,
                                     slot_idx: int, category: str) -> None:
    slots = state.get("wildcard_slots", [])
    picks = state.get("wildcard_picks", [])
    if slot_idx != len(picks) or slot_idx >= len(slots):
        # A stale menu (double click, or Skip already took this slot): show the current pick instead.
        await _chargen_wildcards(interaction, state)
        return
    slot = slots[slot_idx]
    already = {p["skill"] for p in picks}

    groups = _wildcard_cat_groups([s for s in slot["eligible"] if s not in already])
    skills_in_cat = groups.get(category, [])

    if not skills_in_cat:
        await interaction.response.send_message("No skills available in that category.", ephemeral=True)
        return

    view = _WizardView(state)
    view.add_item(_WildcardSkillSelect(state, skills_in_cat[:25], slot_idx, slot["rank"]))

    back_btn = discord.ui.Button(label="Back: Categories", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_wildcards(btn_inter, state)

    back_btn.callback = on_back
    view.add_item(back_btn)

    rank_note = f" at Rank {slot['rank']}" if slot["rank"] > 1 else ""
    total = len(slots)
    await interaction.response.edit_message(
        content=f"**Starting Skills — Pick {slot_idx + 1} of {total}** ({category}){rank_note}\n{slot['label']}",
        embed=_active_embed(state), view=view,
    )


# --- Step 5: Trait raises ---
class _TraitRaiseSelect(discord.ui.Select):
    def __init__(self, state: dict):
        self.state = state
        base = _build_base_char(state)
        options = []
        for t in advancement.TRAIT_NAMES:
            cur = base.void_ring if t == "void" else base.get_trait(t)
            bought = state.get("trait_purchases", {}).get(t, 0)
            effective = cur + bought
            if effective >= _CHARGEN_TRAIT_CAP:
                continue
            mult = advancement.VOID_XP_MULT if t == "void" else advancement.TRAIT_XP_MULT
            cost = (effective + 1) * mult
            options.append(discord.SelectOption(
                label=f"{t.capitalize()} ({effective} → {effective + 1})",
                value=t,
                description=f"Cost: {cost} XP",
            ))
        if not options:
            options = [discord.SelectOption(label="All traits maxed", value="__none__")]
        super().__init__(placeholder="Raise a trait...", options=options[:25])

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        chosen = self.values[0]
        if chosen == "__none__":
            await interaction.response.defer()
            return
        purchases = self.state.setdefault("trait_purchases", {})
        purchases[chosen] = purchases.get(chosen, 0) + 1
        _, remaining = _calc_chargen_xp(self.state)
        if remaining < 0:
            purchases[chosen] -= 1
            if purchases[chosen] <= 0:
                del purchases[chosen]
            await interaction.response.send_message("Not enough XP for that raise.", ephemeral=True)
            return
        await _chargen_traits(interaction, self.state)


async def _chargen_traits(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "traits"
    view = _ChargenView(state)
    view.add_item(_TraitRaiseSelect(state))

    undo_btn = discord.ui.Button(label="Undo Last", style=discord.ButtonStyle.secondary, row=2)
    next_btn = discord.ui.Button(label="Next: Advantages", style=discord.ButtonStyle.primary, row=2)

    async def on_undo(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        purchases = state.get("trait_purchases", {})
        if purchases:
            last_key = list(purchases.keys())[-1]
            purchases[last_key] -= 1
            if purchases[last_key] <= 0:
                del purchases[last_key]
        await _chargen_traits(btn_inter, state)

    async def on_next(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_advantages(btn_inter, state)

    undo_btn.callback = on_undo
    next_btn.callback = on_next

    if state.get("wildcard_slots"):
        back_wc_btn = discord.ui.Button(label="Back: Starting Skills", style=discord.ButtonStyle.secondary, row=2)

        async def on_back_wc(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            state["wildcard_picks"] = state.get("wildcard_picks", [])[:-1] if state.get("wildcard_picks") else []
            await _chargen_wildcards(btn_inter, state)

        back_wc_btn.callback = on_back_wc
        view.add_item(back_wc_btn)

    view.add_item(undo_btn)
    view.add_item(next_btn)

    await interaction.response.edit_message(
        content="**Step 5/10 — Trait Raises** · Select a trait to raise (costs XP). Press **Next** when done.",
        embed=_chargen_embed(state), view=view,
    )


# --- Advantage / disadvantage choice prompts ---
# Entries with a fixed XP cost that need the player to specify a detail.
# (label: max 45 chars for Discord TextInput, placeholder: max 100 chars)
_CHARGEN_CHOICES: dict[str, tuple[str, str]] = {
    # Advantages
    "Chosen by the Oracles": ("Which Oracle?", "Air, Earth, Fire, Water, or Void"),
    "Dark Paragon": ("Which Shourido tenet?", "Control, Determination, Insight, Knowledge, Perfection, Strength, or Will"),
    "Different School": ("Which school?", "Full school name (e.g. Kakita Bushi)"),
    "Elemental Blessing": ("Which element?", "Air, Earth, Fire, or Water"),
    "Forbidden Knowledge": ("What forbidden topic?", "e.g. Maho, Kolat, Lying Darkness, Gozoku"),
    "Friend of the Elements": ("Which element?", "Air, Earth, Fire, or Water"),
    "Great Potential": ("Which Skill?", "One Skill you possess (e.g. Kenjutsu)"),
    "Heart of Vengeance": ("Against whom?", "A clan, family, or group (e.g. Scorpion Clan)"),
    "Higher Purpose": ("What is the purpose?", "A specific goal or cause"),
    "Inheritance": ("What item?", "Describe the inherited item (weapon, armor, etc.)"),
    "Inner Gift": ("Which Inner Gift?", "Empathy, Foresight, Lesser Prophecy, Tongues, or other"),
    "Languages": ("Which language(s)?", "e.g. Gaijin (Merenae), Nezumi, Senpet, Yobanjin"),
    "Multiple Schools": ("Which second school?", "Full school name (e.g. Doji Courtier)"),
    "Paragon": ("Which Bushido tenet?", "Compassion, Courage, Courtesy, Duty, Honesty, Honor, or Sincerity"),
    "Seven Fortunes' Blessing": ("Which Fortune?", "Benten, Bishamon, Daikoku, Ebisu, Fukurokujin, Hotei, or Jurojin"),
    "Social Position": ("What position?", "e.g. Magistrate, Imperial Herald, Governor's Advisor"),
    "Soul of Artistry": ("Which Artisan Skill?", "e.g. Painting, Poetry, Ikebana, Origami, Sculpture"),
    "Spy Network": ("Where?", "Province, city, or region your network covers"),
    "Touch of the Spirit Realms": ("Which spirit realm?", "Chikushudo, Gaki-do, Meido, Sakkaku, Tengoku, Toshigoku, Yomi, Yume-do"),
    "Way of the Land": ("Which province?", "Province name (e.g. Beiden, Ryoko Owari)"),
    # Disadvantages
    "Bad Fortune": ("Which type?", "Secret Love, Disfigurement, Evil Eye, Allergy, Lingering Misfortune, Unknown Enemy"),
    "Compulsion": ("What compulsion?", "e.g. Gambling, Drinking, Lying, Cleaning, Bragging"),
    "Cursed by the Realm": ("Which spirit realm?", "Chikushudo, Gaki-do, Jigoku, Maigo no Musha, Meido, Sakkaku, Tengoku, etc."),
    "Dark Secret": ("What is the secret?", "Describe briefly (only DM and you see this)"),
    "Doubt": ("Which School Skill?", "One of your School Skills (e.g. Kenjutsu)"),
    "Driven": ("What goal?", "The goal you would sacrifice anything for"),
    "Elemental Imbalance": ("Which element?", "Air, Earth, Fire, or Water (not your Deficiency)"),
    "Fascination": ("What subject?", "e.g. Gaijin culture, the Shadowlands, ancient history"),
    "Haunted": ("By what or whom?", "e.g. An ancestor, a spirit, a vengeful ghost"),
    "Jealousy": ("Jealous of whom?", "A specific PC or major NPC name"),
    "Lost Love": ("Who was lost?", "Name, clan/family, circumstances"),
    "Obligation": ("Obligated to whom?", "Person, group, or organization (e.g. your daimyo, a monk order)"),
    "Phobia": ("What do you fear?", "e.g. Fire, Heights, Water, Spiders, Crowds, the Shadowlands"),
    "Seven Fortunes' Curse": ("Which Fortune's curse?", "Benten, Bishamon, Daikoku, Ebisu, Fukurokujin, Hotei (6 pts), Jurojin"),
    "True Love": ("Who is your true love?", "Name and brief description"),
    "Weakness": ("Which Trait?", "Agility, Awareness, Intelligence, Perception, Reflexes, Stamina, Strength, Willpower"),
    "Wrath of the Kami": ("Which element?", "Air, Earth, Fire, or Water"),
}


class _AdvChoiceModal(discord.ui.Modal):
    choice = discord.ui.TextInput(label="Specify", max_length=100, required=True)

    def __init__(self, state: dict, entry: dict, kind: str, label: str, placeholder: str,
                 category: str = ""):
        super().__init__(title=entry["name"][:45])
        self.state = state
        self.entry = entry
        self.kind = kind
        self._category = category
        self.choice.label = label[:45]
        self.choice.placeholder = placeholder[:100]

    async def on_submit(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        detail = self.choice.value.strip()
        if not detail:
            await interaction.response.send_message("Please specify a choice.", ephemeral=True)
            return
        name = f"{self.entry['name']} ({detail})"
        entry_data = {"name": name, "points": self.entry["points"]}
        if self.kind == "advantage":
            self.state.setdefault("advantages_chosen", []).append(entry_data)
            _, remaining = _calc_chargen_xp(self.state)
            if remaining < 0:
                self.state["advantages_chosen"].pop()
                await interaction.response.send_message("Not enough XP for that advantage.", ephemeral=True)
                return
            if self._category:
                await _chargen_adv_category(interaction, self.state, self._category)
            else:
                await _chargen_advantages(interaction, self.state)
        else:
            current_disadv_xp = sum(d["points"] for d in self.state.get("disadvantages_chosen", []))
            if current_disadv_xp >= _MAX_DISADVANTAGE_XP:
                await interaction.response.send_message(
                    f"Maximum {_MAX_DISADVANTAGE_XP} XP from disadvantages already reached.", ephemeral=True,
                )
                return
            self.state.setdefault("disadvantages_chosen", []).append(entry_data)
            if self._category:
                await _chargen_disadv_category(interaction, self.state, self._category)
            else:
                await _chargen_disadvantages(interaction, self.state)


# --- Step 6: Advantages ---
class _AdvantageSelect(discord.ui.Select):
    def __init__(self, state: dict, category: str):
        self.state = state
        self.category = category
        chosen_names = set()
        for a in state.get("advantages_chosen", []):
            chosen_names.add(a["name"])
            base = a["name"].split(" (")[0]
            if base in _CHARGEN_CHOICES:
                chosen_names.add(base)
        advs = [a for a in advantages.by_kind("advantage")
                if a.get("points") is not None and a["name"] not in chosen_names
                and (a.get("category") or "") == category]
        advs.sort(key=lambda a: a["name"])
        options = []
        for a in advs[:25]:
            options.append(discord.SelectOption(
                label=a["name"][:100],
                description=f"{a['cost_text']} — {a.get('category', '')}",
            ))
        if not options:
            options = [discord.SelectOption(label="(none available)", value="__none__")]
        super().__init__(placeholder=f"{category} advantages...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        chosen = self.values[0]
        if chosen == "__none__":
            await interaction.response.defer()
            return
        adv = advantages.get(chosen, "advantage")
        if not adv or adv.get("points") is None:
            await interaction.response.send_message("That advantage has a variable cost; ask a DM.", ephemeral=True)
            return
        choice_spec = _CHARGEN_CHOICES.get(adv["name"])
        if choice_spec:
            modal = _AdvChoiceModal(self.state, adv, "advantage", choice_spec[0], choice_spec[1],
                                    category=self.category)
            await interaction.response.send_modal(modal)
            return
        self.state.setdefault("advantages_chosen", []).append({"name": adv["name"], "points": adv["points"]})
        _, remaining = _calc_chargen_xp(self.state)
        if remaining < 0:
            self.state["advantages_chosen"].pop()
            await interaction.response.send_message("Not enough XP for that advantage.", ephemeral=True)
            return
        await _chargen_adv_category(interaction, self.state, self.category)


async def _chargen_adv_category(interaction: discord.Interaction, state: dict, cat: str) -> None:
    view = _ChargenView(state)
    view.add_item(_AdvantageSelect(state, cat))
    back_btn = discord.ui.Button(label="Back to Categories", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_advantages(btn_inter, state)

    back_btn.callback = on_back
    view.add_item(back_btn)
    await interaction.response.edit_message(
        content=f"**Step 6/10 — Advantages ({cat})** · Select an advantage to buy.",
        embed=_chargen_embed(state), view=view,
    )


class _AdvCategorySelect(discord.ui.Select):
    def __init__(self, state: dict):
        self.state = state
        cats = ["Mental", "Physical", "Social", "Spiritual", "Material"]
        options = [discord.SelectOption(label=c) for c in cats]
        super().__init__(placeholder="Pick a category to browse...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_adv_category(interaction, self.state, self.values[0])


async def _chargen_advantages(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "advantages"
    view = _ChargenView(state)
    view.add_item(_AdvCategorySelect(state))

    undo_btn = discord.ui.Button(label="Undo Last", style=discord.ButtonStyle.secondary, row=2)
    next_btn = discord.ui.Button(label="Next: Disadvantages", style=discord.ButtonStyle.primary, row=2)

    async def on_undo(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        if state.get("advantages_chosen"):
            state["advantages_chosen"].pop()
        await _chargen_advantages(btn_inter, state)

    async def on_next(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_disadvantages(btn_inter, state)

    back_btn = discord.ui.Button(label="Back: Traits", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_traits(btn_inter, state)

    undo_btn.callback = on_undo
    next_btn.callback = on_next
    back_btn.callback = on_back
    view.add_item(back_btn)
    view.add_item(undo_btn)
    view.add_item(next_btn)

    await interaction.response.edit_message(
        content="**Step 6/10 — Advantages** · Pick a category then select advantages. Press **Next** when done.",
        embed=_chargen_embed(state), view=view,
    )


# --- Step 7: Disadvantages ---
class _DisadvantageSelect(discord.ui.Select):
    def __init__(self, state: dict, category: str):
        self.state = state
        self.category = category
        chosen_names = set()
        for d in state.get("disadvantages_chosen", []):
            chosen_names.add(d["name"])
            base = d["name"].split(" (")[0]
            if base in _CHARGEN_CHOICES:
                chosen_names.add(base)
        disadvs = [d for d in advantages.by_kind("disadvantage")
                   if d.get("points") is not None and d["name"] not in chosen_names
                   and (d.get("category") or "") == category]
        disadvs.sort(key=lambda d: d["name"])
        options = []
        for d in disadvs[:25]:
            options.append(discord.SelectOption(
                label=d["name"][:100],
                description=f"{d['cost_text']} — gives XP back",
            ))
        if not options:
            options = [discord.SelectOption(label="(none available)", value="__none__")]
        super().__init__(placeholder=f"{category} disadvantages...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        chosen = self.values[0]
        if chosen == "__none__":
            await interaction.response.defer()
            return
        dis = advantages.get(chosen, "disadvantage")
        if not dis or dis.get("points") is None:
            await interaction.response.send_message("That disadvantage has a variable cost; ask a DM.", ephemeral=True)
            return
        current_disadv_xp = sum(d["points"] for d in self.state.get("disadvantages_chosen", []))
        if current_disadv_xp >= _MAX_DISADVANTAGE_XP:
            await interaction.response.send_message(
                f"You've already reached the maximum {_MAX_DISADVANTAGE_XP} XP from disadvantages.",
                ephemeral=True,
            )
            return
        choice_spec = _CHARGEN_CHOICES.get(dis["name"])
        if choice_spec:
            modal = _AdvChoiceModal(self.state, dis, "disadvantage", choice_spec[0], choice_spec[1],
                                    category=self.category)
            await interaction.response.send_modal(modal)
            return
        self.state.setdefault("disadvantages_chosen", []).append({"name": dis["name"], "points": dis["points"]})
        await _chargen_disadv_category(interaction, self.state, self.category)


async def _chargen_disadv_category(interaction: discord.Interaction, state: dict, cat: str) -> None:
    view = _ChargenView(state)
    view.add_item(_DisadvantageSelect(state, cat))
    back_btn = discord.ui.Button(label="Back to Categories", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_disadvantages(btn_inter, state)

    back_btn.callback = on_back
    view.add_item(back_btn)
    disadv_xp = sum(d["points"] for d in state.get("disadvantages_chosen", []))
    await interaction.response.edit_message(
        content=f"**Step 7/10 — Disadvantages ({cat})** · "
                f"Select a disadvantage ({disadv_xp}/{_MAX_DISADVANTAGE_XP} XP gained).",
        embed=_chargen_embed(state), view=view,
    )


class _DisadvCategorySelect(discord.ui.Select):
    def __init__(self, state: dict):
        self.state = state
        cats = ["Mental", "Physical", "Social", "Spiritual"]
        options = [discord.SelectOption(label=c) for c in cats]
        super().__init__(placeholder="Pick a category to browse...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_disadv_category(interaction, self.state, self.values[0])


async def _chargen_disadvantages(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "disadvantages"
    view = _ChargenView(state)
    view.add_item(_DisadvCategorySelect(state))

    undo_btn = discord.ui.Button(label="Undo Last", style=discord.ButtonStyle.secondary, row=2)
    next_btn = discord.ui.Button(label="Next: Skills", style=discord.ButtonStyle.primary, row=2)

    async def on_undo(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        if state.get("disadvantages_chosen"):
            state["disadvantages_chosen"].pop()
        await _chargen_disadvantages(btn_inter, state)

    async def on_next(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills(btn_inter, state)

    back_btn = discord.ui.Button(label="Back: Advantages", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_advantages(btn_inter, state)

    undo_btn.callback = on_undo
    next_btn.callback = on_next
    back_btn.callback = on_back
    view.add_item(back_btn)
    view.add_item(undo_btn)
    view.add_item(next_btn)

    disadv_xp = sum(d["points"] for d in state.get("disadvantages_chosen", []))
    await interaction.response.edit_message(
        content=f"**Step 7/10 — Disadvantages** · Pick a category to browse. "
                f"({disadv_xp}/{_MAX_DISADVANTAGE_XP} XP gained). Press **Next** when done.",
        embed=_chargen_embed(state), view=view,
    )


# --- Step 8: Skills ---
class _SkillSelect(discord.ui.Select):
    def __init__(self, state: dict, category: str):
        self.state = state
        self._category = category
        skill_list = _CHARGEN_SKILL_CATS.get(category, [])
        base = _build_base_char(state)
        options = []
        for sk in skill_list:
            base_rank = base.skills.get(sk, 0)
            bought = state.get("skill_purchases", {}).get(sk, 0)
            effective = base_rank + bought
            if effective >= _CHARGEN_SKILL_CAP:
                continue
            cost = (effective + 1) * advancement.SKILL_XP_MULT
            label = f"{sk} ({effective} → {effective + 1})" if effective > 0 else f"{sk} (0 → 1)"
            options.append(discord.SelectOption(
                label=label[:100], value=sk,
                description=f"Cost: {cost} XP",
            ))
        if not options:
            options = [discord.SelectOption(label="(none available)", value="__none__")]
        super().__init__(placeholder=f"{category} skills...", options=options[:25])

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        chosen = self.values[0]
        if chosen == "__none__":
            await interaction.response.defer()
            return
        purchases = self.state.setdefault("skill_purchases", {})
        purchases[chosen] = purchases.get(chosen, 0) + 1
        _, remaining = _calc_chargen_xp(self.state)
        if remaining < 0:
            purchases[chosen] -= 1
            if purchases[chosen] <= 0:
                del purchases[chosen]
            await interaction.response.send_message("Not enough XP for that skill rank.", ephemeral=True)
            return
        await _chargen_skills_category(interaction, self.state, self._category)


class _SkillCategorySelect(discord.ui.Select):
    def __init__(self, state: dict):
        self.state = state
        options = [discord.SelectOption(label=c) for c in _CHARGEN_SKILL_CATS]
        super().__init__(placeholder="Pick a skill category...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills_category(interaction, self.state, self.values[0])


async def _chargen_skills_category(interaction: discord.Interaction, state: dict, category: str) -> None:
    view = _ChargenView(state)
    view.add_item(_SkillSelect(state, category))
    back_btn = discord.ui.Button(label="Back to Categories", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills(btn_inter, state)

    back_btn.callback = on_back
    view.add_item(back_btn)
    await interaction.response.edit_message(
        content=f"**Step 8/10 — Skills ({category})** · Select a skill to buy/raise.",
        embed=_chargen_embed(state), view=view,
    )


async def _chargen_skills(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "skills"
    view = _ChargenView(state)
    view.add_item(_SkillCategorySelect(state))

    undo_btn = discord.ui.Button(label="Undo Last", style=discord.ButtonStyle.secondary, row=2)
    next_btn = discord.ui.Button(label="Next: Spells", style=discord.ButtonStyle.primary, row=2)

    async def on_undo(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        purchases = state.get("skill_purchases", {})
        if purchases:
            last_key = list(purchases.keys())[-1]
            purchases[last_key] -= 1
            if purchases[last_key] <= 0:
                del purchases[last_key]
        await _chargen_skills(btn_inter, state)

    async def on_next(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        sch = schools.get(state.get("school_name", "")) if state.get("school_name") else None
        if sch and sch.get("affinity"):
            await _chargen_spells(btn_inter, state)
        else:
            await _chargen_review(btn_inter, state)

    back_btn = discord.ui.Button(label="Back: Disadvantages", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_disadvantages(btn_inter, state)

    emph_btn = discord.ui.Button(label="Buy Emphasis (2 XP)", style=discord.ButtonStyle.secondary, row=3)

    async def on_emph(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_emphasis_pick(btn_inter, state)

    emph_btn.callback = on_emph

    undo_emph_btn = discord.ui.Button(label="Undo Emphasis", style=discord.ButtonStyle.secondary, row=3)

    async def on_undo_emph(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        emphs = state.get("emphasis_purchases", [])
        if emphs:
            emphs.pop()
        await _chargen_skills(btn_inter, state)

    undo_emph_btn.callback = on_undo_emph

    undo_btn.callback = on_undo
    next_btn.callback = on_next
    back_btn.callback = on_back
    view.add_item(back_btn)
    view.add_item(undo_btn)
    view.add_item(next_btn)
    view.add_item(emph_btn)
    view.add_item(undo_emph_btn)

    await interaction.response.edit_message(
        content="**Step 8/10 — Skills** · Pick a category then select skills to buy. "
                "Use **Buy Emphasis** to add skill emphases. Press **Next** when done.",
        embed=_chargen_embed(state), view=view,
    )


class _EmphasisSkillSelect(discord.ui.Select):
    def __init__(self, state: dict):
        self.state = state
        base = _build_base_char(state)
        all_skills: dict[str, int] = dict(base.skills)
        for sk, ranks in state.get("skill_purchases", {}).items():
            all_skills[sk] = all_skills.get(sk, 0) + ranks
        options = [discord.SelectOption(label=f"{sk} (Rank {rk})", value=sk)
                   for sk, rk in sorted(all_skills.items()) if rk >= 1]
        if not options:
            options = [discord.SelectOption(label="(no skills yet)", value="__none__")]
        super().__init__(placeholder="Which skill gets the emphasis?", options=options[:25])

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        chosen = self.values[0]
        if chosen == "__none__":
            await interaction.response.defer()
            return
        await interaction.response.send_modal(_EmphasisModal(self.state, chosen))


class _EmphasisModal(discord.ui.Modal):
    def __init__(self, state: dict, skill: str):
        super().__init__(title=f"Emphasis for {skill}"[:45])
        self.state = state
        self.skill = skill
        self.emphasis_input = discord.ui.TextInput(
            label="Emphasis name",
            placeholder="e.g. Swords, Deception, Rokugani...",
            max_length=60,
        )
        self.add_item(self.emphasis_input)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        emph_name = self.emphasis_input.value.strip()
        if not emph_name:
            await interaction.response.send_message("Emphasis cannot be empty.", ephemeral=True)
            return
        emphs = self.state.setdefault("emphasis_purchases", [])
        for e in emphs:
            if e["skill"] == self.skill and e["emphasis"].lower() == emph_name.lower():
                await interaction.response.send_message(
                    f"You already bought {self.skill}: {emph_name}.", ephemeral=True)
                return
        base = _build_base_char(self.state)
        for existing in base.emphases.get(self.skill, []):
            if existing.lower() == emph_name.lower():
                await interaction.response.send_message(
                    f"Your school already grants {self.skill}: {existing}.", ephemeral=True)
                return
        emphs.append({"skill": self.skill, "emphasis": emph_name})
        _, remaining = _calc_chargen_xp(self.state)
        if remaining < 0:
            emphs.pop()
            await interaction.response.send_message("Not enough XP for this emphasis.", ephemeral=True)
            return
        await _chargen_skills(interaction, self.state)


async def _chargen_emphasis_pick(interaction: discord.Interaction, state: dict) -> None:
    view = _ChargenView(state)
    view.add_item(_EmphasisSkillSelect(state))
    back_btn = discord.ui.Button(label="Back to Skills", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills(btn_inter, state)

    back_btn.callback = on_back
    view.add_item(back_btn)
    _, remaining = _calc_chargen_xp(state)
    await interaction.response.edit_message(
        content=f"**Step 8/10 — Emphasis** · Pick a skill to add an emphasis to ({_EMPHASIS_XP_COST} XP each). "
                f"{remaining} XP remaining.",
        embed=_chargen_embed(state), view=view,
    )


# --- Step 9: Spells (shugenja only) ---
class _SpellSelect(discord.ui.Select):
    def __init__(self, state: dict, element: str, remaining: int):
        self.state = state
        self.element = element
        chosen_names = set(state.get("chosen_spells", []))
        available = [s for s in spells.by_element(element)
                     if s["mastery"] == 1 and s["name"] not in chosen_names]
        available.sort(key=lambda s: s["name"])
        options = []
        for s in available[:25]:
            kw = s.get("keyword", "")
            desc = kw[:100] if kw else s.get("range", "")[:100]
            options.append(discord.SelectOption(
                label=s["name"][:100], description=desc,
            ))
        if not options:
            options = [discord.SelectOption(label="(none available)", value="__none__")]
        super().__init__(
            placeholder=f"{element} spells ({remaining} left to pick)...",
            options=options,
        )

    async def callback(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        chosen = self.values[0]
        if chosen == "__none__":
            await interaction.response.defer()
            return
        self.state.setdefault("chosen_spells", []).append(chosen)
        allot_tracking = self.state.setdefault("_spell_allot_remaining", {})
        allot_tracking[self.element] = allot_tracking.get(self.element, 0) - 1
        await _chargen_spells(interaction, self.state)


async def _chargen_spells(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "spells"
    sch = schools.get(state.get("school_name", "")) if state.get("school_name") else None
    allot = _parse_spell_allotment(sch) if sch else None
    if allot is None:
        await _chargen_review(interaction, state)
        return

    if "_spell_allot_remaining" not in state:
        state["_spell_allot_remaining"] = dict(allot)

    remaining = state["_spell_allot_remaining"]
    total_remaining = sum(max(0, v) for v in remaining.values())

    if total_remaining <= 0:
        await _chargen_review(interaction, state)
        return

    view = _ChargenView(state)

    elements_with_slots = [(el, cnt) for el, cnt in remaining.items() if cnt > 0]
    if len(elements_with_slots) == 1:
        el, cnt = elements_with_slots[0]
        view.add_item(_SpellSelect(state, el, cnt))
    else:
        el_select = discord.ui.Select(
            placeholder="Pick an element...",
            options=[discord.SelectOption(label=f"{el} ({cnt} remaining)", value=el)
                     for el, cnt in elements_with_slots],
        )

        async def on_element(sel_inter: discord.Interaction) -> None:
            if sel_inter.user.id != int(state["user_id"]):
                await sel_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            el = sel_inter.values[0]
            cnt = remaining.get(el, 0)
            v2 = _ChargenView(state)
            v2.add_item(_SpellSelect(state, el, cnt))
            back_btn = discord.ui.Button(label="Back to Elements", style=discord.ButtonStyle.secondary, row=2)

            async def on_back(btn_inter: discord.Interaction) -> None:
                if btn_inter.user.id != int(state["user_id"]):
                    await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                    return
                await _chargen_spells(btn_inter, state)

            back_btn.callback = on_back
            v2.add_item(back_btn)
            await sel_inter.response.edit_message(
                content=f"**Step 9/10 — Spells ({el})** · Pick a Mastery 1 spell.",
                embed=_chargen_embed(state), view=v2,
            )

        el_select.callback = on_element
        view.add_item(el_select)

    back_btn = discord.ui.Button(label="Back: Skills", style=discord.ButtonStyle.secondary, row=2)
    skip_btn = discord.ui.Button(label="Skip Remaining Spells", style=discord.ButtonStyle.secondary, row=2)

    async def on_back(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills(btn_inter, state)

    async def on_skip(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_review(btn_inter, state)

    back_btn.callback = on_back
    skip_btn.callback = on_skip
    view.add_item(back_btn)
    view.add_item(skip_btn)

    slots_desc = ", ".join(f"{el}: {cnt}" for el, cnt in remaining.items() if cnt > 0)
    await interaction.response.edit_message(
        content=f"**Step 9/10 — Starting Spells** · Remaining slots: {slots_desc}. "
                f"(Sense, Commune, Summon are auto-granted.)",
        embed=_chargen_embed(state), view=view,
    )


# --- Step 10: Review & Submit ---
async def _chargen_review(interaction: discord.Interaction, state: dict) -> None:
    state["step"] = "review"
    char = _materialize_character(state)
    spent, remaining = _calc_chargen_xp(state)

    embed = discord.Embed(
        title=f"Review: {state['name']}",
        color=discord.Color.green(),
    )

    lines: list[str] = []
    lines.append(f"**Clan:** {char.clan}")
    if char.family:
        lines.append(f"**Family:** {char.family}")
    lines.append(f"**School:** {char.school} ({char.school_type})")
    if state.get("heritage_result"):
        lines.append(f"**Heritage:** {state['heritage_result'][:80]}")
    if state.get("concept"):
        lines.append(f"**Concept:** {state['concept'][:200]}")
    embed.description = "\n".join(lines)

    rings = stats.all_rings(char)
    trait_lines = (
        f"Air: Ref {char.reflexes} / Awa {char.awareness} (Ring {rings['air']})\n"
        f"Earth: Sta {char.stamina} / Wil {char.willpower} (Ring {rings['earth']})\n"
        f"Fire: Agi {char.agility} / Int {char.intelligence} (Ring {rings['fire']})\n"
        f"Water: Str {char.strength} / Per {char.perception} (Ring {rings['water']})\n"
        f"Void: {char.void_ring}"
    )
    embed.add_field(name="Traits & Rings", value=trait_lines, inline=False)

    if char.skills:
        skill_str = ", ".join(f"{s} {r}" for s, r in sorted(char.skills.items()))
        embed.add_field(name="Skills", value=skill_str[:1024], inline=False)

    if char.emphases:
        emph_str = ", ".join(f"{sk} ({', '.join(em)})" for sk, em in sorted(char.emphases.items()) if em)
        if emph_str:
            embed.add_field(name="Emphases", value=emph_str[:1024], inline=False)

    if char.advantages:
        embed.add_field(name="Advantages", value=", ".join(char.advantages)[:1024], inline=False)
    if char.disadvantages:
        embed.add_field(name="Disadvantages", value=", ".join(char.disadvantages)[:1024], inline=False)

    if char.spells_known:
        embed.add_field(name="Spells", value=", ".join(char.spells_known)[:1024], inline=False)

    embed.add_field(name="Honor", value=f"{char.honor:.1f}", inline=True)
    embed.add_field(name="Insight", value=str(stats.insight(char)), inline=True)
    embed.add_field(name="XP", value=f"{spent} spent, {remaining} unspent", inline=True)

    if remaining > 0:
        embed.set_footer(text=f"{remaining} XP unspent: it carries over to your sheet as spendable XP.")

    wc_picks = state.get("wildcard_picks", [])
    resolved_picks = [p for p in wc_picks if p.get("skill") != "(auto-skipped)"]
    if resolved_picks:
        wc_lines = [f"- {p['skill']} (Rank {p['rank']})" for p in resolved_picks]
        embed.add_field(name="Wildcard Skills (player chosen)",
                        value="\n".join(wc_lines)[:1024], inline=False)

    view = _ChargenView(state)
    submit_btn = discord.ui.Button(label="Submit for Approval", style=discord.ButtonStyle.success, emoji="📋", row=0)
    back_traits_btn = discord.ui.Button(label="Back: Traits", style=discord.ButtonStyle.secondary, row=1)
    back_adv_btn = discord.ui.Button(label="Back: Advantages", style=discord.ButtonStyle.secondary, row=1)
    back_disadv_btn = discord.ui.Button(label="Back: Disadvantages", style=discord.ButtonStyle.secondary, row=1)
    back_skills_btn = discord.ui.Button(label="Back: Skills", style=discord.ButtonStyle.secondary, row=1)

    async def on_submit(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _submit_for_approval(btn_inter, state)

    async def on_back_traits(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_traits(btn_inter, state)

    async def on_back_adv(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_advantages(btn_inter, state)

    async def on_back_disadv(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_disadvantages(btn_inter, state)

    async def on_back_skills(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills(btn_inter, state)

    submit_btn.callback = on_submit
    back_traits_btn.callback = on_back_traits
    back_adv_btn.callback = on_back_adv
    back_disadv_btn.callback = on_back_disadv
    back_skills_btn.callback = on_back_skills
    view.add_item(submit_btn)
    view.add_item(back_traits_btn)
    view.add_item(back_adv_btn)
    view.add_item(back_disadv_btn)
    view.add_item(back_skills_btn)

    sch = schools.get(state.get("school_name", "")) if state.get("school_name") else None
    is_shugenja = sch and sch.get("affinity")
    if is_shugenja:
        back_spells_btn = discord.ui.Button(label="Back: Spells", style=discord.ButtonStyle.secondary, row=2)

        async def on_back_spells(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            await _chargen_spells(btn_inter, state)

        back_spells_btn.callback = on_back_spells
        view.add_item(back_spells_btn)

    await interaction.response.edit_message(
        content="**Step 10/10 — Review** · Check your character below, then submit for DM approval.",
        embed=embed, view=view,
    )


_SUBMITTED_TEXT = (
    "📋 Thank you! **{name}** has been submitted and staff are looking into it. "
    "You'll be notified here when a decision is made. Nothing else is needed from you for now."
)


def _cg_lock_after_submit(state: dict) -> None:
    """Mark a wizard as submitted, save it, and stop its live view so nothing can re-open it."""
    state["submitted"] = True
    state["submitted_at"] = time.time()
    _cg_save(state)
    key = (str(state.get("guild_id", "")), str(state.get("user_id", "")))
    live = _active_wizard_views.pop(key, None)
    if live is not None:
        live.stop()


async def _submit_for_approval(interaction: discord.Interaction, state: dict) -> None:
    """Send the completed character to the approval channel for DM review."""
    guild_id = state["guild_id"]
    if state.get("submitted"):
        await interaction.response.send_message(
            _SUBMITTED_TEXT.format(name=state.get("name", "your character")), ephemeral=True,
        )
        return
    approval_ch_id = store.get_approval_channel(guild_id)
    if not approval_ch_id:
        await interaction.response.send_message(
            "No approval channel configured. Ask an admin to run `/setup server`.",
            ephemeral=True,
        )
        return
    approval_ch = client.get_channel(int(approval_ch_id))
    if approval_ch is None:
        await interaction.response.send_message(
            "The approval channel is no longer accessible.", ephemeral=True,
        )
        return

    char = _materialize_character(state)
    spent, remaining = _calc_chargen_xp(state)

    embed = discord.Embed(
        title="📋 Character Submission (Full Sheet)",
        color=0xC4A747,
    )
    embed.add_field(name="Player", value=f"<@{state['user_id']}>", inline=True)
    embed.add_field(name="Character Name", value=state["name"], inline=True)
    embed.add_field(name="Clan / Family / School",
                    value=f"{char.clan} / {char.family} / {char.school} ({char.school_type})",
                    inline=False)

    if state.get("concept"):
        embed.add_field(name="Concept", value=state["concept"][:1024], inline=False)

    rings = stats.all_rings(char)
    trait_lines = (
        f"Air: Ref {char.reflexes} / Awa {char.awareness} (Ring {rings['air']})\n"
        f"Earth: Sta {char.stamina} / Wil {char.willpower} (Ring {rings['earth']})\n"
        f"Fire: Agi {char.agility} / Int {char.intelligence} (Ring {rings['fire']})\n"
        f"Water: Str {char.strength} / Per {char.perception} (Ring {rings['water']})\n"
        f"Void: {char.void_ring}"
    )
    embed.add_field(name="Traits & Rings", value=trait_lines, inline=False)

    if char.skills:
        skill_str = ", ".join(f"{s} {r}" for s, r in sorted(char.skills.items()))
        embed.add_field(name="Skills", value=skill_str[:1024], inline=False)

    if char.emphases:
        emph_str = ", ".join(f"{sk} ({', '.join(em)})" for sk, em in sorted(char.emphases.items()) if em)
        if emph_str:
            embed.add_field(name="Emphases", value=emph_str[:1024], inline=False)

    if char.advantages:
        embed.add_field(name="Advantages", value=", ".join(char.advantages)[:1024], inline=False)
    if char.disadvantages:
        embed.add_field(name="Disadvantages", value=", ".join(char.disadvantages)[:1024], inline=False)
    if char.spells_known:
        embed.add_field(name="Spells", value=", ".join(char.spells_known)[:1024], inline=False)

    embed.add_field(name="Honor", value=f"{char.honor:.1f}", inline=True)
    embed.add_field(name="Insight", value=str(stats.insight(char)), inline=True)
    embed.add_field(name="XP", value=f"{spent} spent, {remaining} unspent", inline=True)

    if state.get("heritage_result"):
        embed.add_field(name="Heritage", value=state["heritage_result"][:1024], inline=False)

    view = _FullCharacterApprovalView(
        applicant_id=int(state["user_id"]),
        character_state=state,
        lobby_channel_id=int(state.get("channel_id", interaction.channel_id)),
    )
    _cg_lock_after_submit(state)   # before posting: a second click cannot race the first
    await view.persist(await approval_ch.send(
        content=f"{_dm_ping(approval_ch.guild)}New character submission awaiting review.",
        embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
    ))

    await interaction.response.edit_message(
        content=_SUBMITTED_TEXT.format(name=state["name"]),
        embed=None, view=None,
    )


async def _create_player_support_channel(
    guild: discord.Guild, member: discord.Member, character_name: str,
) -> str | None:
    """Create a private channel in Player Support for a newly approved character.

    Returns a note string on success/failure, or None if the category doesn't exist.
    """
    support_cat = discord.utils.get(guild.categories, name=CAT_PLAYER_SUPPORT)
    if support_cat is None:
        return None
    channel_name = character_name.lower().replace(" ", "-")
    everyone = guild.default_role
    bot_member = guild.me
    fortune_role = discord.utils.get(guild.roles, name=ROLE_FORTUNE)
    kami_role = discord.utils.get(guild.roles, name=ROLE_KAMI)
    overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True,
        ),
        member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        ),
    }
    for r in (fortune_role, kami_role):
        if r:
            overwrites[r] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
                manage_messages=True,
            )
    try:
        ch = await support_cat.create_text_channel(
            channel_name, overwrites=overwrites,
            topic=f"Private channel for {character_name} — speak with Staff here.",
            reason=f"Player support channel for approved character '{character_name}'",
        )
        await ch.send(
            f"Welcome, {member.mention}! This is your private channel to communicate "
            f"with the Staff about **{character_name}**. Only you and Staff can see this."
        )
        return f"Support channel #{ch.name} created."
    except discord.Forbidden:
        return "Could not create support channel — bot lacks permission."


class _FullCharacterApprovalView(_DisableableView):
    """DM approval view for fully-built character sheets from the wizard."""

    KIND = "char_approval"

    def __init__(self, applicant_id: int, character_state: dict,
                 lobby_channel_id: int) -> None:
        super().__init__(timeout=None)
        self.applicant_id = applicant_id
        self.character_state = character_state
        self.lobby_channel_id = lobby_channel_id

    @discord.ui.button(label="Approve", style=discord.ButtonStyle.success, emoji="✅")
    async def approve(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        guild = interaction.guild
        if guild is None:
            return
        member = guild.get_member(self.applicant_id)
        if member is None:
            try:
                member = await guild.fetch_member(self.applicant_id)
            except discord.NotFound:
                await interaction.response.send_message("That member is no longer in the server.", ephemeral=True)
                return
        approved_role = discord.utils.get(guild.roles, name=ROLE_APPROVED)
        if approved_role is None:
            await interaction.response.send_message(
                f"The **{ROLE_APPROVED}** role doesn't exist. Run `/setup server` first.",
                ephemeral=True,
            )
            return

        guild_id = str(guild.id)
        owner_id = str(self.applicant_id)
        state = self.character_state
        char = _materialize_character(state)

        try:
            record = store.create_character(guild_id, owner_id, char)
        except storage.DuplicateNameError:
            await interaction.response.send_message(
                f"A character named **{state['name']}** already exists for that player.",
                ephemeral=True,
            )
            return
        store.set_active(guild_id, owner_id, record.id)

        roles_to_add = [approved_role]
        if char.clan:
            clan_role = discord.utils.get(guild.roles, name=char.clan)
            if clan_role:
                roles_to_add.append(clan_role)
        if char.family:
            family_role = discord.utils.get(guild.roles, name=char.family)
            if family_role:
                roles_to_add.append(family_role)
        await member.add_roles(*roles_to_add,
                               reason=f"Character '{state['name']}' approved by {interaction.user.display_name}")
        nick_note = ""
        try:
            await member.edit(nick=state["name"], reason=f"Character approved: {state['name']}")
        except discord.Forbidden:
            nick_note = ("\n(Could not change nickname — the bot's role may be too low "
                         "or the member is the server owner.)")

        creation_ch_id = store.get_creation_channel(guild_id, owner_id)
        if creation_ch_id:
            ch = client.get_channel(int(creation_ch_id))
            if ch:
                try:
                    await ch.delete(reason=f"Character '{state['name']}' approved — wizard channel cleanup")
                except discord.Forbidden:
                    pass
            store.delete_creation_channel(guild_id, owner_id)

        support_note = await _create_player_support_channel(guild, member, state["name"])

        self._disable()
        await interaction.response.edit_message(view=self)

        support_info = f"\n{support_note}" if support_note else ""
        embed = discord.Embed(
            title="✅ Character Approved (Full Sheet)",
            color=discord.Color.green(),
            description=(
                f"**{member.mention}**'s character **{state['name']}** has been approved.\n"
                f"Full character sheet created with all traits, skills, advantages, "
                f"and spells applied.{nick_note}{support_info}"
            ),
        )
        embed.set_footer(text=f"Approved by {interaction.user.display_name}")
        await interaction.followup.send(embed=embed)

        lobby = client.get_channel(self.lobby_channel_id)
        if lobby:
            await lobby.send(
                f"✅ {member.mention}, your character **{state['name']}** has been approved! "
                f"Your full character sheet is ready. Welcome to Rokugan!"
            )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.danger, emoji="❌")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        guild = interaction.guild
        member = guild.get_member(self.applicant_id) if guild else None
        if member is None and guild is not None:
            try:
                member = await guild.fetch_member(self.applicant_id)
            except discord.NotFound:
                member = None
        member_str = member.mention if member else f"User {self.applicant_id}"
        embed = discord.Embed(
            title="❌ Character Denied",
            color=discord.Color.red(),
            description=f"**{member_str}**'s character **{self.character_state['name']}** was denied.",
        )
        embed.set_footer(text=f"Denied by {interaction.user.display_name}")
        await interaction.followup.send(embed=embed)
        # Re-open the applicant's wizard so they can fix the sheet and submit again.
        applicant = str(self.applicant_id)
        guild_id = str(interaction.guild_id)
        raw = store.get_creation_state(guild_id, applicant)
        resume_view = None
        if raw:
            try:
                saved = json.loads(raw)
                saved["submitted"] = False
                saved.pop("submitted_at", None)
                store.save_creation_state(guild_id, applicant, json.dumps(saved, default=str))
                resume_view = _ChargenResumeView(guild_id, applicant)
            except ValueError:
                resume_view = None
        lobby = client.get_channel(self.lobby_channel_id)
        if lobby and member:
            msg = await lobby.send(
                f"❌ {member.mention}, your character **{self.character_state['name']}** was not approved. "
                f"Please speak with a DM for details"
                + (", then press **Resume** to adjust the sheet and submit again." if resume_view else " and feel free to submit again."),
                view=resume_view,
            )
            if resume_view is not None:
                await resume_view.persist(msg)


async def sheet_wizard(  # legacy in-channel wizard, no longer registered as a command
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 64],
) -> None:
    if not await _require_guild(interaction):
        return
    state = {
        "guild_id": str(interaction.guild_id),
        "user_id": str(interaction.user.id),
        "name": name,
        "clan": "",
        "family_name": "",
        "heritage_result": None,
        "different_school": False,
        "school_name": "",
    }
    view = _WizardView(state)
    view.add_item(_ClanSelect(state, great=True))
    view.add_item(_ClanSelect(state, great=False))
    await interaction.response.send_message(
        content="**Step 1/5**: Choose your Clan.",
        embed=_wizard_embed(state), view=view,
    )

@sheet.command(name="view", description="View a character sheet (yours or another player's).")
@app_commands.describe(member="Whose active character to view. Omit for your own.")
async def sheet_view(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(
                f"{member.display_name} has no active character.", ephemeral=True
            )
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message(
                "You have no active character. Use `/sheet create` first.", ephemeral=True
            )
            return
    await interaction.response.send_message(embed=build_sheet_embed(rec), ephemeral=True)

async def _activate_autocomplete(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    """Staff only: their own characters plus every stored NPC."""
    if interaction.guild_id is None or not _is_dm(interaction):
        return []
    guild = str(interaction.guild_id)
    cur = (current or "").lower().strip()
    mine = [r.character.name for r in store.list_by_owner(guild, str(interaction.user.id))]
    npcs = [r.character.name for r in store.list_by_owner(guild, NPC_OWNER)]
    out = [app_commands.Choice(name=n, value=n) for n in mine if cur in n.lower()]
    out += [app_commands.Choice(name=f"NPC: {n}", value=n) for n in sorted(npcs) if cur in n.lower()]
    return out[:25]

@sheet.command(name="activate", description="Staff: act as one of your characters or as a stored NPC (commands without a name use it).")
@app_commands.describe(name="Your character, or an NPC's name.")
@app_commands.autocomplete(name=_activate_autocomplete)
async def sheet_activate(interaction: discord.Interaction, name: app_commands.Range[str, 1, 64]) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    uid = str(interaction.user.id)
    if not _is_dm(interaction):
        await interaction.response.send_message(
            "Each player has one character, so there is nothing to switch to. If yours needs replacing, ask staff.",
            ephemeral=True,
        )
        return
    rec = store.get_by_name(guild, uid, name)
    as_npc = False
    if rec is None:
        rec = store.get_by_name(guild, NPC_OWNER, name)
        as_npc = rec is not None
    if rec is None:
        mine = ", ".join(r.character.name for r in store.list_by_owner(guild, uid)) or "none"
        await interaction.response.send_message(
            f"No character or NPC called **{name}**. Yours: {mine}. NPCs: see `/npc list`.", ephemeral=True,
        )
        return
    if stats.is_dead(rec.character):
        await interaction.response.send_message(f"💀 **{rec.character.name}** is dead and cannot be made active.", ephemeral=True)
        return
    store.set_active(guild, uid, rec.id)
    if as_npc:
        await interaction.response.send_message(
            f"🎭 You are now acting as **{rec.character.name}** (NPC): attacks, checks, spells and `/fight status` "
            f"without a name use it. `/sheet activate` your own character to switch back.", ephemeral=True,
        )
    else:
        await interaction.response.send_message(f"✅ **{rec.character.name}** is now your active character.", ephemeral=True)

@sheet.command(name="list", description="List your characters (or a player's, if you are a DM).")
@app_commands.describe(member="Whose characters to list [Fortune]. Omit for your own.")
async def sheet_list(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    target = member or interaction.user
    if member is not None and member.id != interaction.user.id and not _is_dm(interaction):
        await interaction.response.send_message(
            f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to list another player's characters.", ephemeral=True
        )
        return

    records = store.list_by_owner(guild, str(target.id))
    active = store.get_active(guild, str(target.id))
    active_id = active.id if active else None
    if not records:
        await interaction.response.send_message(
            f"{'You have' if target.id == interaction.user.id else target.display_name + ' has'} "
            f"no characters yet.",
            ephemeral=True,
        )
        return
    lines = [
        f"{'▶️ ' if r.id == active_id else '• '}{'💀 ' if stats.is_dead(r.character) else ''}**{r.character.name}** "
        f": {r.character.clan or ' '} {r.character.school_type}"
        for r in records
    ]
    await interaction.response.send_message(
        f"Characters for {target.display_name}:\n" + "\n".join(lines), ephemeral=True
    )


@sheet.command(name="delete", description="Delete a character sheet (players: ask staff). [Fortune]")
@app_commands.describe(name="Character name.", member="Owner of the character [Fortune]")
@app_commands.autocomplete(name=_own_character_autocomplete)
async def sheet_delete(
    interaction: discord.Interaction, name: str, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    owner_target = interaction.user
    if member is not None and member.id != interaction.user.id:
        if not await _require_dm_role(interaction):
            return
        owner_target = member
    rec = store.get_by_name(guild, str(owner_target.id), name)
    if rec is None and member is None and _is_dm(interaction):
        rec = store.get_by_name_guild(guild, name)
    if rec is None:
        await interaction.response.send_message(f"No character named **{name}** found.", ephemeral=True)
        return
    if stats.is_dead(rec.character) and not _is_dm(interaction):
        await interaction.response.send_message(
            f"💀 **{rec.character.name}** is dead. Only Staff can remove a dead character's sheet.",
            ephemeral=True,
        )
        return
    view = _DeleteConfirmView(rec, interaction.user.id)
    await interaction.response.send_message(
        f"⚠️ Are you sure you want to **permanently delete** **{rec.character.name}**?\n"
        f"This cannot be undone.",
        view=view,
        ephemeral=True,
    )

class _DeleteConfirmView(discord.ui.View):
    def __init__(self, record: storage.CharacterRecord, user_id: int) -> None:
        super().__init__(timeout=30)
        self._record = record
        self._user_id = user_id

    @discord.ui.button(label="Delete", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if interaction.user.id != self._user_id:
            await interaction.response.send_message("Not your confirmation.", ephemeral=True)
            return
        guild = interaction.guild
        owner_id = self._record.owner_id
        char = self._record.character
        store.delete(self._record.id)
        self.stop()

        role_notes: list[str] = []
        if guild is not None:
            member = guild.get_member(int(owner_id))
            if member is None:
                try:
                    member = await guild.fetch_member(int(owner_id))
                except discord.NotFound:
                    member = None

            if member is not None:
                roles_to_remove: list[discord.Role] = []
                approved_role = discord.utils.get(guild.roles, name=ROLE_APPROVED)
                if approved_role and approved_role in member.roles:
                    roles_to_remove.append(approved_role)
                if char.clan:
                    clan_role = discord.utils.get(guild.roles, name=char.clan)
                    if clan_role and clan_role in member.roles:
                        roles_to_remove.append(clan_role)
                if char.family:
                    family_role = discord.utils.get(guild.roles, name=char.family)
                    if family_role and family_role in member.roles:
                        roles_to_remove.append(family_role)
                if roles_to_remove:
                    try:
                        await member.remove_roles(*roles_to_remove, reason=f"Character '{char.name}' deleted")
                        role_notes.append("Roles removed: " + ", ".join(r.name for r in roles_to_remove))
                    except discord.Forbidden:
                        role_notes.append("Could not remove roles — bot lacks permission.")
                try:
                    await member.edit(nick=None, reason=f"Character '{char.name}' deleted")
                    role_notes.append("Nickname reset.")
                except discord.Forbidden:
                    role_notes.append("Could not reset nickname — bot lacks permission.")

            support_cat = discord.utils.get(guild.categories, name=CAT_PLAYER_SUPPORT)
            if support_cat:
                channel_slug = char.name.lower().replace(" ", "-")
                support_ch = discord.utils.get(support_cat.text_channels, name=channel_slug)
                if support_ch:
                    try:
                        await support_ch.delete(reason=f"Character '{char.name}' deleted")
                        role_notes.append(f"Support channel #{channel_slug} deleted.")
                    except discord.Forbidden:
                        role_notes.append("Could not delete support channel — bot lacks permission.")

        extra = ("\n" + "\n".join(role_notes)) if role_notes else ""
        await interaction.response.edit_message(
            content=f"🗑️ Deleted **{char.name}** permanently.{extra}", view=None
        )

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if interaction.user.id != self._user_id:
            await interaction.response.send_message("Not your confirmation.", ephemeral=True)
            return
        self.stop()
        await interaction.response.edit_message(content="Deletion cancelled.", view=None)

    async def on_timeout(self) -> None:
        pass


@sheet.command(name="owner", description="Show who owns a character (PC owner or NPC).")
@app_commands.describe(name="Character name.")
@app_commands.autocomplete(name=_any_character_autocomplete)
async def sheet_owner(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = store.get_by_name_guild(guild, name)
    if rec is None:
        await interaction.response.send_message(f"No character named **{name}** found.", ephemeral=True)
        return
    if rec.owner_id == NPC_OWNER:
        await interaction.response.send_message(f"**{rec.character.name}** is an NPC.", ephemeral=True)
    else:
        await interaction.response.send_message(
            f"**{rec.character.name}** belongs to <@{rec.owner_id}>.", ephemeral=True,
        )


class _PaginatorView(discord.ui.View):
    """Reusable paginator for long text lists."""

    def __init__(self, pages: list[str], user_id: int, *, timeout: float = 120) -> None:
        super().__init__(timeout=timeout)
        self._pages = pages
        self._user_id = user_id
        self._index = 0
        self._update_buttons()

    def _update_buttons(self) -> None:
        self.prev_btn.disabled = self._index == 0
        self.next_btn.disabled = self._index >= len(self._pages) - 1
        self.prev_btn.label = f"◀ {self._index}" if self._index > 0 else "◀"
        self.next_btn.label = f"▶ {self._index + 2}" if self._index < len(self._pages) - 1 else "▶"

    @discord.ui.button(label="◀", style=discord.ButtonStyle.secondary)
    async def prev_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if interaction.user.id != self._user_id:
            await interaction.response.send_message("Not your paginator.", ephemeral=True)
            return
        self._index = max(0, self._index - 1)
        self._update_buttons()
        await interaction.response.edit_message(content=self._pages[self._index], view=self)

    @discord.ui.button(label="▶", style=discord.ButtonStyle.secondary)
    async def next_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if interaction.user.id != self._user_id:
            await interaction.response.send_message("Not your paginator.", ephemeral=True)
            return
        self._index = min(len(self._pages) - 1, self._index + 1)
        self._update_buttons()
        await interaction.response.edit_message(content=self._pages[self._index], view=self)

    async def on_timeout(self) -> None:
        pass

def _paginate(lines: list[str], header: str, *, per_page: int = 15) -> list[str]:
    """Split lines into pages with a header and page indicator.

    Also enforces the Discord 2000-char message limit: if a page exceeds
    1900 chars (leaving room for the footer), it splits at the last line
    that fits."""
    total_pages = max(1, math.ceil(len(lines) / per_page))
    raw_pages: list[list[str]] = []
    for i in range(total_pages):
        raw_pages.append(lines[i * per_page : (i + 1) * per_page])
    pages: list[list[str]] = []
    for chunk in raw_pages:
        current: list[str] = []
        current_len = len(header)
        for line in chunk:
            line_len = len(line) + 1
            if current and current_len + line_len > 1900:
                pages.append(current)
                current = [line]
                current_len = len(header) + line_len
            else:
                current.append(line)
                current_len += line_len
        if current:
            pages.append(current)
    result = []
    for i, chunk in enumerate(pages):
        footer = f"\n*Page {i + 1}/{len(pages)}*" if len(pages) > 1 else ""
        result.append(header + "\n".join(chunk) + footer)
    return result

@stat_group.command(name="trait", description="Set a Trait (or Void) on the active character. [Fortune]")
@app_commands.describe(
    trait="Which Trait to set.", value="New value (0-10).",
    member="Target player [Fortune]. Omit for your own active character.",
)
@app_commands.choices(trait=_TRAIT_CHOICES)
async def sheet_trait(
    interaction: discord.Interaction,
    trait: app_commands.Choice[str],
    value: app_commands.Range[int, 0, 10],
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.set_trait(trait.value, value)
    rank_msg = _check_insight_rank_advance(rec.character)
    changed = store.save(rec, note="stat trait")
    await _audit_stat(interaction, rec, "stat trait", changed)
    label = "Void" if trait.value == "void" else trait.value.capitalize()
    await interaction.response.send_message(
        f"Set **{label}** to **{value}** on **{rec.character.name}**.{rank_msg}", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="skill", description="Set skill ranks. Single: skill='Kenjutsu' rank=3. Bulk: skill='Kenjutsu 3, Courtier 2'. [Fortune]")
@app_commands.describe(
    skill="Skill name, or bulk list: 'Kenjutsu 3, Courtier 2, Etiquette 1'.",
    rank="Rank 0-10 (0 removes). Omit when using bulk format.",
    member="Target player [Fortune]. Omit for your own active character.",
)
async def sheet_skill(
    interaction: discord.Interaction,
    skill: app_commands.Range[str, 1, 200],
    rank: app_commands.Range[int, 0, 10] | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if rank is not None:
        skill_name = skill.strip().title()
        if rank == 0:
            rec.character.skills.pop(skill_name, None)
            msg = f"Removed **{skill_name}** from **{rec.character.name}**."
        else:
            rec.character.skills[skill_name] = rank
            msg = f"Set **{skill_name}** to rank **{rank}** on **{rec.character.name}**."
    else:
        parts = [p.strip() for p in skill.split(",") if p.strip()]
        changes = []
        for p in parts:
            m = re.match(r"^(.+?)\s+(\d{1,2})$", p.strip())
            if not m:
                await interaction.response.send_message(
                    f"Could not parse **{p}**. Use format: `Kenjutsu 3, Courtier 2`.", ephemeral=True
                )
                return
            sname = m.group(1).strip().title()
            srank = int(m.group(2))
            if srank > 10:
                await interaction.response.send_message(f"Rank for **{sname}** exceeds 10.", ephemeral=True)
                return
            if srank == 0:
                rec.character.skills.pop(sname, None)
                changes.append(f"removed **{sname}**")
            else:
                rec.character.skills[sname] = srank
                changes.append(f"**{sname}** {srank}")
        msg = f"Set on **{rec.character.name}**: {', '.join(changes)}."
    msg += _check_insight_rank_advance(rec.character)
    changed = store.save(rec, note="stat skill")
    await _audit_stat(interaction, rec, "stat skill", changed)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="set", description="Set a numeric field (honor, glory, void points, armor, etc.). [Fortune]")
@app_commands.describe(
    field="Which field to set.", value="New value.",
    member="Target player [Fortune]. Omit for your own active character.",
)
@app_commands.choices(field=_SET_CHOICES)
async def sheet_set(
    interaction: discord.Interaction,
    field: app_commands.Choice[str],
    value: float,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    _apply_numeric_field(rec.character, field.value, value)
    changed = store.save(rec, note="stat set")
    await _audit_stat(interaction, rec, "stat set", changed)
    await interaction.response.send_message(
        f"Updated **{field.value}** on **{rec.character.name}**.", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="identity", description="Set clan, family and/or school on a sheet; a catalog family adds its +1 Trait. [Fortune]")
@app_commands.describe(
    clan="Clan name (free text).",
    family="Family name; a catalog match also applies its +1 Trait unless apply_bonus is false.",
    school="School name (catalog match preferred; free text allowed).",
    apply_bonus="Apply the catalog family's +1 Trait (default true). Ignored when the family is unchanged.",
    member="Target player [Fortune]. Omit for your own active character.",
)
async def sheet_identity(
    interaction: discord.Interaction,
    clan: str | None = None,
    family: str | None = None,
    school: str | None = None,
    apply_bonus: bool = True,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    changes: list[str] = []
    if clan is not None:
        c.clan = clan.strip()
        changes.append(f"Clan **{c.clan or '(none)'}**")
    if family is not None:
        fam = families.get(family.strip())
        new_name = fam["name"] if fam else family.strip()
        if new_name.lower() != (c.family or "").lower():
            if fam and apply_bonus:
                changes.append(f"Family **{fam['name']}** ({families.apply_to_character(c, fam)})")
                if not c.clan:
                    c.clan = fam["clan"]
            else:
                c.family = new_name
                changes.append(f"Family **{new_name or '(none)'}**" + (" (no bonus applied)" if fam else " (not in the catalog: no bonus)"))
        else:
            changes.append(f"Family already **{c.family}** (unchanged, no bonus re-applied)")
    if school is not None:
        sch = schools.get(school.strip())
        c.school = sch["name"] if sch else school.strip()
        changes.append(f"School **{c.school or '(none)'}**" + ("" if sch or not c.school else " (not in the catalog)"))
    if not changes:
        await interaction.response.send_message("Give at least one of `clan:`, `family:` or `school:`.", ephemeral=True)
        return
    changed = store.save(rec, note="stat identity")
    await _audit_stat(interaction, rec, "stat identity", changed)
    await interaction.response.send_message(
        f"Updated **{c.name}**: " + "; ".join(changes) + ".", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="armor", description="Equip armor (sets Armor TN bonus & Reduction), or 'none' to remove. [Fortune]")
@app_commands.describe(armor="Armor type (bogu/ashigaru/tatami/light/heavy/tetsu_do/riding, or 'none').", member="Target player [Fortune]")
@app_commands.autocomplete(armor=_armor_autocomplete)
async def sheet_armor(
    interaction: discord.Interaction,
    armor: str,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    a = armor.lower().strip()
    if a in ("none", "", "remove"):
        c.armor_name = ""
        c.owned_armor = ""
        c.armor_tn_bonus = 0
        c.armor_reduction = 0
        msg = f"Removed armor from **{c.name}**."
    else:
        spec = combat.get_armor(a)
        if spec is None:
            await interaction.response.send_message(
                f"Unknown armor **{armor}**. Options: {', '.join(combat.ARMOR_CATALOG)}.", ephemeral=True
            )
            return
        c.armor_name = a
        c.owned_armor = a
        c.armor_tn_bonus = spec["tn_bonus"]
        c.armor_reduction = spec["reduction"]
        heavy = " (heavy)" if spec["is_heavy"] else ""
        cost_note = f" · {spec['cost']} koku" if spec.get("cost") else ""
        msg = f"**{c.name}** equips **{a}**{heavy}: Armor TN +{spec['tn_bonus']}, Reduction {spec['reduction']}{cost_note}."
        if spec.get("special"):
            msg += f"\n⚠️ {spec['special']}"
    changed = store.save(rec, note="stat armor")
    await _audit_stat(interaction, rec, "stat armor", changed)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

_QUALITY_CHOICES = [
    app_commands.Choice(name=q.title(), value=q) for q in sorted(combat.WEAPON_QUALITIES)
]

async def _quality_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    low = current.lower()
    return [c for c in _QUALITY_CHOICES if low in c.value][:25]

@stat_group.command(name="quality", description="Set extraordinary weapon qualities on the equipped weapon. [Fortune]")
@app_commands.describe(
    qualities="Comma-separated qualities: balanced, radiant, signature, swift, true, unbreakable.",
    clear="Remove all weapon qualities.",
    member="Target player [Fortune]",
)
@app_commands.autocomplete(qualities=_quality_autocomplete)
async def sheet_quality(
    interaction: discord.Interaction,
    qualities: str | None = None,
    clear: bool = False,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if clear:
        c.weapon_qualities = []
        changed = store.save(rec, note="stat quality")
        await _audit_stat(interaction, rec, "stat quality", changed)
        await interaction.response.send_message(
            f"Cleared all weapon qualities from **{c.name}**.", embed=build_sheet_embed(rec)
        )
        return
    if not qualities:
        current = ", ".join(c.weapon_qualities) if c.weapon_qualities else "none"
        await interaction.response.send_message(
            f"**{c.name}** weapon qualities: {current}\n"
            f"Valid: {', '.join(sorted(combat.WEAPON_QUALITIES))}",
            ephemeral=True,
        )
        return
    parsed = [q.strip().lower() for q in qualities.split(",") if q.strip()]
    invalid = [q for q in parsed if q not in combat.WEAPON_QUALITIES]
    if invalid:
        await interaction.response.send_message(
            f"Unknown qualities: {', '.join(invalid)}. Valid: {', '.join(sorted(combat.WEAPON_QUALITIES))}.",
            ephemeral=True,
        )
        return
    c.weapon_qualities = sorted(set(parsed))
    changed = store.save(rec, note="stat quality")
    await _audit_stat(interaction, rec, "stat quality", changed)
    q_list = ", ".join(c.weapon_qualities)
    wpn = c.equipped_weapon or "(no weapon equipped)"
    await interaction.response.send_message(
        f"**{c.name}** weapon qualities set: **{q_list}** (on {wpn}).", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="advantage", description="Record (or remove) an Advantage on your sheet (free: no XP). [Fortune]")
@app_commands.describe(
    name="Advantage name. For parameterised advantages, include the parameter: 'Weakness: Willpower', 'Seven Fortunes' Blessing: Daikoku'.",
    remove="Remove it instead.",
    member="Target player [Fortune]",
)
@app_commands.autocomplete(name=_advantage_autocomplete)
async def sheet_advantage(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    adv, canonical = _parse_advdis_name(name, "advantage")
    c = rec.character
    if remove:
        c.advantages = [x for x in c.advantages if x.lower() != canonical.lower()]
        msg = f"Removed advantage **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.advantages]:
            c.advantages.append(canonical)
        msg = f"**{c.name}** gains the advantage **{canonical}**."
        base = adv["name"] if adv else name.strip().split(":")[0].strip()
        param_hint = advantage_effects.PARAMETERISED_ADVANTAGES.get(base)
        if param_hint and ":" not in name:
            msg += f"\n*Hint: this advantage can be parameterised. Use `{canonical}: <{param_hint}>` to record the chosen option.*"
    changed = store.save(rec, note="stat advantage")
    await _audit_stat(interaction, rec, "stat advantage", changed)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="disadvantage", description="Record (or remove) a Disadvantage on your sheet (grants XP: DM /xp grant). [Fortune]")
@app_commands.describe(
    name="Disadvantage name. For parameterised disadvantages, include the parameter: 'Weakness: Willpower', 'Doubt: Kenjutsu'.",
    remove="Remove it instead.",
    member="Target player [Fortune]",
)
@app_commands.autocomplete(name=_disadvantage_autocomplete)
async def sheet_disadvantage(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    dis, canonical = _parse_advdis_name(name, "disadvantage")
    c = rec.character
    if remove:
        c.disadvantages = [x for x in c.disadvantages if x.lower() != canonical.lower()]
        msg = f"Removed disadvantage **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.disadvantages]:
            c.disadvantages.append(canonical)
        grant = f" (grants {dis['points']} XP: a DM applies it with `/xp grant`)" if dis and dis["points"] else ""
        msg = f"**{c.name}** takes the disadvantage **{canonical}**{grant}."
        base = dis["name"] if dis else name.strip().split(":")[0].strip()
        param_hint = advantage_effects.PARAMETERISED_DISADVANTAGES.get(base)
        if param_hint and ":" not in name:
            msg += f"\n*Hint: this disadvantage can be parameterised. Use `{canonical}: <{param_hint}>` to record the chosen option.*"
    changed = store.save(rec, note="stat disadvantage")
    await _audit_stat(interaction, rec, "stat disadvantage", changed)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@sheet_kata_grp.command(name="learn", description="Record (or remove) a Kata on your sheet (free: no XP; use /xp kata to buy). [Fortune]")
@app_commands.describe(name="Kata name.", remove="Remove it instead.", member="Target player [Fortune]")
@app_commands.autocomplete(name=_kata_autocomplete)
async def sheet_kata(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    k = kata.get(name)
    canonical = k["name"] if k else name.strip()
    c = rec.character
    if remove:
        c.katas = [x for x in c.katas if x.lower() != canonical.lower()]
        msg = f"Removed Kata **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.katas]:
            c.katas.append(canonical)
        msg = f"\U0001F94B **{c.name}** learns the Kata **{canonical}**."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@sheet_kiho_grp.command(name="learn", description="Record (or remove) a Kiho on your sheet (free: no XP; use /xp kiho to buy). [Fortune]")
@app_commands.describe(name="Kiho name.", remove="Remove it instead.", member="Target player [Fortune]")
@app_commands.autocomplete(name=_kiho_autocomplete)
async def sheet_kiho(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    k = kiho.get(name)
    canonical = k["name"] if k else name.strip()
    c = rec.character
    if remove:
        c.kiho = [x for x in c.kiho if x.lower() != canonical.lower()]
        msg = f"Removed Kiho **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.kiho]:
            c.kiho.append(canonical)
        msg = f"✋ **{c.name}** learns the Kiho **{canonical}**."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

def _activate_kata(c: Character, name: str | None) -> tuple[bool, str]:
    """Set (or drop) the active Kata. Returns (changed, message)."""
    if not name or not name.strip():
        prev = c.active_kata
        c.active_kata = ""
        tail = f" (**{prev}**)" if prev else ""
        return True, f"**{c.name}** drops their active Kata{tail}."
    k = kata.get(name)
    canonical = k["name"] if k else name.strip()
    if canonical.lower() not in [x.lower() for x in c.katas]:
        return False, (f"**{c.name}** hasn't learned the Kata **{canonical}**: add it with `/sheet kata learn` "
                       f"or buy it with `/xp kata`.")
    c.active_kata = canonical
    note = "" if kata_effects.is_auto(canonical) else " *(its effect is DM-adjudicated: shown as a reminder on attacks.)*"
    return True, f"🥋 **{c.name}** assumes the Kata **{canonical}**.{note}"

def _activate_kiho(c: Character, name: str, off: bool = False) -> tuple[bool, str]:
    """Activate or end a known Kiho (s38: one Internal/Kharmic/Mystical; Martial stacks). Returns (changed, message)."""
    h = kiho.get(name)
    canonical = h["name"] if h else name.strip()
    if off:
        c.active_kiho = [x for x in c.active_kiho if x.lower() != canonical.lower()]
        return True, f"**{c.name}** ends the Kiho **{canonical}**."
    if canonical.lower() not in [x.lower() for x in c.kiho]:
        return False, (f"**{c.name}** hasn't learned the Kiho **{canonical}**: add it with `/sheet kiho learn` "
                       f"or buy it with `/xp kiho`.")
    ktype = (h["type"] if h else "").strip().lower()
    replaced = ""
    if ktype in ("internal", "kharmic", "mystical"):
        dropped = []
        kept = []
        for x in c.active_kiho:
            xr = kiho.get(x)
            xt = (xr["type"] if xr else "").strip().lower()
            (dropped if xt == ktype else kept).append(x)
        c.active_kiho = kept
        if dropped:
            replaced = f" (replaces {', '.join(dropped)})"
    if canonical.lower() not in [x.lower() for x in c.active_kiho]:
        c.active_kiho.append(canonical)
    tlabel = h["type"] if h and h.get("type") else "Kiho"
    return True, (f"✋ **{c.name}** activates the {tlabel} Kiho **{canonical}**{replaced}. "
                  f"*(Activation cost: a Void Point or Meditation/Void roll: and duration are "
                  f"DM-adjudicated; its combat effect is shown as a reminder on attacks.)*")

@sheet_kata_grp.command(name="activate", description="Set your active Kata (Simple Action; only one active). Blank name drops it.")
@app_commands.describe(
    name="A Kata your character knows. Leave blank to drop the active Kata.",
    member="Target player [Fortune]",
)
@app_commands.autocomplete(name=_kata_autocomplete)
async def sheet_kata_activate(
    interaction: discord.Interaction, name: str | None = None, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    ok, msg = _activate_kata(rec.character, name)
    if not ok:
        await interaction.response.send_message(msg, ephemeral=True)
        return
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@sheet_kiho_grp.command(name="activate", description="Activate/deactivate a Kiho (one Internal/Kharmic/Mystical; Martial stacks).")
@app_commands.describe(
    name="A Kiho your character knows.",
    off="Deactivate it instead.",
    member="Target player [Fortune]",
)
@app_commands.autocomplete(name=_kiho_autocomplete)
async def sheet_kiho_activate(
    interaction: discord.Interaction, name: str, off: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    ok, msg = _activate_kiho(rec.character, name, off)
    if not ok:
        await interaction.response.send_message(msg, ephemeral=True)
        return
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))


# ---------------------------------------------------------------------------
# /sheet tattoo — Togashi tattoo management (s57.25)
# ---------------------------------------------------------------------------

@sheet_tattoo_grp.command(name="add", description="Grant a Togashi tattoo ability to a character. [Fortune]")
@app_commands.describe(name="Tattoo name (e.g. bamboo, crab, mountain).", member="Target player [Fortune]")
@app_commands.autocomplete(name=_tattoo_autocomplete)
async def sheet_tattoo_add(
    interaction: discord.Interaction, name: str, member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    from l5r_rules import tattoo_catalog
    t = tattoo_catalog.get_tattoo(name)
    key = name.lower().strip()
    label = t["name"] if t else key.title()
    c = rec.character
    if key in [x.lower() for x in c.tattoos]:
        await interaction.response.send_message(
            f"**{c.name}** already has the **{label}** tattoo.", ephemeral=True
        )
        return
    c.tattoos.append(label if t else key)
    store.save(rec)
    effect = f"\n> {t['effect']}" if t else ""
    await interaction.response.send_message(
        f"🐉 **{c.name}** receives the **{label}** tattoo.{effect}",
        embed=build_sheet_embed(rec),
    )


@sheet_tattoo_grp.command(name="remove", description="Remove a tattoo from a character. [Fortune]")
@app_commands.describe(name="Tattoo to remove.", member="Target player [Fortune]")
@app_commands.autocomplete(name=_tattoo_autocomplete)
async def sheet_tattoo_remove(
    interaction: discord.Interaction, name: str, member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    key = name.lower().strip()
    before = len(c.tattoos)
    c.tattoos = [x for x in c.tattoos if x.lower() != key]
    if len(c.tattoos) == before:
        await interaction.response.send_message(
            f"**{c.name}** doesn't have a **{name}** tattoo.", ephemeral=True
        )
        return
    if c.active_tattoo.lower() == key:
        c.active_tattoo = ""
    store.save(rec)
    await interaction.response.send_message(
        f"Removed **{name}** tattoo from **{c.name}**.", embed=build_sheet_embed(rec)
    )


@sheet_tattoo_grp.command(name="activate", description="Set the active tattoo (only one at a time, except Mantis/Ocean passive).")
@app_commands.describe(
    name="Tattoo to activate.",
    off="Deactivate the current tattoo.",
    choice="Bear only: 'stamina' (+School Rank Stamina) or 'strength' (+half School Rank Strength, rounded up).",
    skill="Lion only: Bugei skill to boost by +SR ranks (e.g. Kenjutsu, Heavy Weapons).",
    member="Target player [Fortune]",
)
@app_commands.choices(choice=[
    app_commands.Choice(name="Stamina (+School Rank)", value="stamina"),
    app_commands.Choice(name="Strength (+ceil(SR/2))", value="strength"),
])
@app_commands.autocomplete(name=_tattoo_autocomplete)
async def sheet_tattoo_activate(
    interaction: discord.Interaction, name: str | None = None, off: bool = False,
    choice: app_commands.Choice[str] | None = None,
    skill: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if off:
        old = c.active_tattoo or "(none)"
        c.active_tattoo = ""
        c.bear_tattoo_choice = ""
        c.lion_tattoo_skill = ""
        store.save(rec)
        await interaction.response.send_message(
            f"**{c.name}** deactivates the **{old}** tattoo.", embed=build_sheet_embed(rec)
        )
        return
    if not name:
        await interaction.response.send_message(
            "Provide a `name:` to activate, or `off:true` to deactivate.", ephemeral=True
        )
        return
    key = name.lower().strip()
    if key not in [x.lower() for x in c.tattoos]:
        await interaction.response.send_message(
            f"**{c.name}** doesn't have a **{name}** tattoo. Grant it with `/sheet tattoo add`.",
            ephemeral=True,
        )
        return
    if key == "bear" and not choice:
        await interaction.response.send_message(
            "Bear Tattoo requires `choice:` — pick **Stamina** (+SR) or **Strength** (+ceil(SR/2)).",
            ephemeral=True,
        )
        return
    _BUGEI_SKILLS = {
        "athletics", "battle", "defense", "horsemanship", "hunting", "iaijutsu",
        "jiujutsu", "kenjutsu", "kyujutsu", "spears", "polearms", "heavy weapons",
        "knives", "war fan", "chain weapons", "staves",
    }
    if key == "lion":
        if not skill:
            await interaction.response.send_message(
                "Lion Tattoo requires `skill:` — name one Bugei skill to boost by +SR ranks "
                "(e.g. Kenjutsu, Heavy Weapons, Jiujutsu).", ephemeral=True,
            )
            return
        if skill.lower().strip() not in _BUGEI_SKILLS:
            await interaction.response.send_message(
                f"**{skill}** is not a Bugei skill. Valid: {', '.join(sorted(_BUGEI_SKILLS))}.",
                ephemeral=True,
            )
            return
    from l5r_rules import tattoo_catalog
    t = tattoo_catalog.get_tattoo(key)
    label = t["name"] if t else key.title()
    c.active_tattoo = label
    c.bear_tattoo_choice = choice.value if choice and key == "bear" else ""
    c.lion_tattoo_skill = skill.strip() if skill and key == "lion" else ""
    store.save(rec)
    effect = f"\n> {t['effect']}" if t else ""
    extra = ""
    if key == "bear" and choice:
        if choice.value == "stamina":
            extra = f"\n> Choice: **Stamina +{c.school_rank}** (locked for duration)"
        else:
            import math as _m
            extra = f"\n> Choice: **Strength +{_m.ceil(c.school_rank / 2)}** (locked for duration)"
    elif key == "lion" and skill:
        extra = f"\n> Skill: **{skill.strip().title()} +{c.school_rank}** ranks (locked for duration)"
    await interaction.response.send_message(
        f"🐉 **{c.name}** activates the **{label}** tattoo.{effect}{extra}",
        embed=build_sheet_embed(rec),
    )


@sheet.command(name="wound", description="Apply wounds to the active character (raw, no armor reduction here). [Fortune]")
@app_commands.describe(
    amount="Wounds to apply.",
    member="Target player [Fortune]. Omit for your own active character.",
)
async def sheet_wound(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if await _refuse_if_dead(interaction, c):
        return
    old = stats.wound_level_name(c)
    c.wounds_taken += amount
    store.save(rec, note="wound")
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    dead = ""
    if stats.is_dead(c):
        death_notes = await _on_death(str(interaction.guild_id), c.name, rec.owner_id, rec.id)
        dead = "  💀 **DEAD**" + "".join(f"\n💀 {n}" for n in death_notes)
    await interaction.response.send_message(
        f"**{c.name}** takes **{amount}** wounds → {c.wounds_taken} total{crossed}{dead}",
        embed=build_sheet_embed(rec),
    )

@sheet.command(name="heal", description="Heal wounds on the active character. [Fortune]")
@app_commands.describe(
    amount="Wounds to heal.",
    member="Target player [Fortune]. Omit for your own active character.",
)
async def sheet_heal(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if stats.is_dead(c):
        await interaction.response.send_message(f"**{c.name}** is dead. PC death is permanent.", ephemeral=True)
        return
    old = stats.wound_level_name(c)
    c.wounds_taken = max(0, c.wounds_taken - amount)
    store.save(rec, note="heal")
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    await interaction.response.send_message(
        f"**{c.name}** heals **{amount}** wounds → {c.wounds_taken} total{crossed}",
        embed=build_sheet_embed(rec),
    )

# ===========================================================================
# /dm group
# ===========================================================================
dm = app_commands.Group(name="dm", description="DM tools: requires the Fortune role (or Kami for admin commands).")
npc_group = app_commands.Group(name="npc", description="Generate, view, and manage NPC characters.")
npc_edit_group = app_commands.Group(name="npc-edit", description="Edit NPC stats: traits, skills, items, spells, and gear.")
creature_group = app_commands.Group(name="creature", description="Spawn and run bestiary creatures.")
room_group = app_commands.Group(name="room", description="Create private play rooms and invite people.")
category_group = app_commands.Group(name="category", description="Organise NPCs and creatures into named groups.")
location_group = app_commands.Group(name="location", description="Create and manage in-character areas and locations.")
location_area_group = app_commands.Group(name="area", description="Manage location areas (Discord categories). [Fortune]", parent=location_group)

# ---------------------------------------------------------------------------
# /dm wizard: interactive DM command menu
# ---------------------------------------------------------------------------
_DM_WIZARD_CATS: list[tuple[str, str, str, list[tuple[str, str]]]] = [
    ("\U0001f3ad", "Session & World", "Manage your game session and world state.", [
        ("/dm party", "Overview of all active PCs"),
        ("/dm new_day", "New day: refresh spells, natural healing"),
        ("/dm setdate", "Set the Rokugani calendar date (year/month/day)"),
        ("/dm roles", "Show Fortune and Kami role holders"),
        ("/dm influence", "Track Influence Points (court scene)"),
        ("/dm mount", "Toggle mounted state on a character (outside combat)"),
        ("/room create", "Create a private play room (thread, optional description)"),
        ("/room describe", "Set or update the pinned room description"),
        ("/room invite / kick", "Add or remove room members"),
        ("/room list / members / close", "List, inspect, or close rooms"),
        ("/dm announce", "Post a session announcement with RSVP reactions"),
    ]),
    ("\U0001f9d1‍⚖️", "NPCs", "Create and manage NPC samurai.", [
        ("/npc generate", "Generate NPC from Clan/Family/School/Rank"),
        ("/npc view / list", "View one NPC or list all on this server"),
        ("/npc-edit trait / skill / set", "Edit Traits, Skills, or numeric fields"),
        ("/npc-edit wound / heal", "Apply or heal wounds"),
        ("/npc-edit item", "Add/remove inventory items"),
        ("/npc-edit spell", "Add/remove known spells"),
        ("/npc-edit equip", "Set weapon, off-hand, armor name"),
        ("/npc-edit feature", "Add/remove advantage, technique, kata, etc."),
        ("/npc-edit affinity", "Set shugenja affinity/deficiency"),
        ("/npc notes", "Set or clear NPC notes"),
        ("/npc clone", "Clone an NPC with a new name"),
        ("/npc rename / delete", "Rename or remove an NPC"),
        ("/npc place / dismiss", "Place or remove an NPC in a room"),
        ("/npc say", "Speak as an NPC (webhook — appears as their name)"),
    ]),
    ("\U0001f409", "Creatures", "Bestiary creature management.", [
        ("/creature catalog", "Search bestiary templates (compact)"),
        ("/creature search", "Search with detailed output"),
        ("/creature info", "Full stat block of a template"),
        ("/creature compare", "Compare two templates side-by-side"),
        ("/creature spawn", "Spawn a creature from a template"),
        ("/creature view / list", "View or list spawned creatures"),
        ("/creature attack", "Creature attacks a PC/NPC"),
        ("/creature wound / heal", "Apply or heal creature wounds"),
        ("/creature delete", "Remove a spawned creature"),
    ]),
    ("\U0001f4c2", "Categories", "Organise NPCs and creatures into named groups.", [
        ("/category create", "Create a named category"),
        ("/category delete", "Delete a category (members untouched)"),
        ("/category rename", "Rename a category"),
        ("/category add / remove", "Add or remove an NPC/creature"),
        ("/category bulk_add / bulk_remove", "Add or remove multiple (comma-separated)"),
        ("/category list / view", "List categories or view one"),
        ("/category spawn", "Spawn all creature templates in a category"),
    ]),
    ("⚔️", "Combat", "Start encounters and manage combatants.", [
        ("/combat start / end", "Start or end an encounter"),
        ("/combat join / add", "Add PCs or custom combatants to initiative"),
        ("/combat npc / creature", "Add a stored NPC or creature to initiative"),
        ("/combat category", "Add all NPCs/creatures in a category to initiative"),
        ("/combat room", "Add all room members at once"),
        ("/combat next / status / remove", "Advance turn, view tracker, remove"),
        ("/combat summary", "Compact stat overview of all combatants"),
        ("/fight attack", "Attack a character, NPC, or creature"),
        ("/fight stance / guard / full_defense", "Set stance or declare defense"),
        ("/fight mount", "Mount or dismount"),
        ("/fight action", "Track Simple/Complex action usage"),
        ("/fight env cover", "Set cover/terrain Armor TN bonus on a combatant"),
        ("/fight env notes", "Set environment description for the encounter"),
        ("/fight env damage", "Apply environmental damage to multiple combatants"),
    ]),
    ("\U0001f504", "Conditions & Initiative", "Adjust conditions and turn order.", [
        ("/combat condition set / clear", "Apply or remove a condition"),
        ("/combat condition list", "List conditions on a combatant"),
        ("/combat turn init", "Adjust a combatant's initiative value"),
        ("/combat turn hold / delay / act", "Hold, delay, or resolve held action"),
        ("/combat turn surprise", "Toggle the surprise round flag"),
    ]),
    ("\U0001f91c", "Grapple, Duel & Battle", "Subsystem combat mechanics.", [
        ("/engage grapple initiate", "Start a grapple (Jiujutsu/Agility)"),
        ("/engage grapple control", "Contested control (Jiujutsu/Strength)"),
        ("/engage grapple hit / throw / pin / break_free", "Grapple actions"),
        ("/engage duel assess", "Assessment (Iaijutsu/Awareness)"),
        ("/engage duel focus", "Focus (contested Iaijutsu/Void)"),
        ("/engage duel strike", "Strike (Iaijutsu/Reflexes + damage)"),
        ("/engage battle roll / damage", "Mass battle engagement and damage"),
    ]),
    ("\U0001f3af", "Skill Checks", "Roll skill and trait checks for characters.", [
        ("/check skill", "Generic Skill/Trait vs TN"),
        ("/check contest", "Contested roll between two characters"),
        ("/check cooperative", "Cooperative check: helpers assist primary"),
        ("/check fear / honor", "Fear or Honor Roll"),
        ("/check stealth / investigate", "Stealth or Investigation"),
        ("/check social", "Social skill check (auto-selects trait)"),
        ("/check craft / lore", "Craft or Lore check"),
        ("/check poison / medicine", "Poison resistance or Medicine"),
        ("/check horsemanship", "Mounted maneuver check"),
    ]),
    ("\U0001fa78", "Damage, Healing & Taint", "Manage character health.", [
        ("/dm damage", "Apply damage to a character"),
        ("/dm heal", "Heal wounds on a character"),
        ("/dm treat", "Medicine treatment roll"),
        ("/dm taint", "View or modify Shadowlands Taint"),
    ]),
    ("✨", "Spells & Crafting", "Spell support and extended crafting.", [
        ("/spell cast", "Cast a spell (Ring + School Rank)"),
        ("/spell importune", "Importune the kami (Spellcraft check + cast)"),
        ("/spell resist", "Target resists a spell (Willpower vs TN)"),
        ("/spell interrupt", "Interrupt a spell (contested Reflexes)"),
        ("/spell damage", "Roll spell damage dice"),
        ("/dm craft_extended", "Extended crafting (multi-step project)"),
    ]),
    ("\U0001f4b0", "XP & Advancement", "Grant and manage Experience Points.", [
        ("/xp grant", "Grant XP to a player"),
        ("/xp balance", "Show a character's available XP"),
        ("/xp costs", "XP cost reference table"),
    ]),
    ("\U0001f5fa️", "Locations", "Manage RP areas and channels.", [
        ("/location area create", "Create an RP area (Discord category)"),
        ("/location area delete / list", "Delete or list RP areas"),
        ("/location area fix-permissions", "Repair visibility on all areas (Kami)"),
        ("/location create", "Create a location channel in an area"),
        ("/location describe", "Set or update a location's description"),
        ("/location list / close", "List or close locations"),
    ]),
    ("\U0001f6e0️", "Admin (Kami Only)", "Server administration commands.", [
        ("/dm log_channel / clear_log", "Set or clear combat event log channel"),
        ("/dm approval_channel / clear_approval", "Set character submission approval channel"),
        ("/dm damage_channel / clear_damage_channel", "Set damage/healing approval channel"),
        ("/dm date_channel / clear_date_channel", "Set or clear the pinned date display"),
        ("/setup server", "Create full server structure (categories, channels, roles)"),
        ("/sync", "Re-sync slash commands with Discord"),
    ]),
]

class _DmWizardCatSelect(discord.ui.Select):
    def __init__(self) -> None:
        options = [
            discord.SelectOption(label=name, emoji=emoji, description=desc[:100])
            for emoji, name, desc, _ in _DM_WIZARD_CATS
        ]
        super().__init__(placeholder="What do you need to do?", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        chosen = self.values[0]
        cat = next((c for c in _DM_WIZARD_CATS if c[1] == chosen), None)
        if cat is None:
            await interaction.response.send_message("Category not found.", ephemeral=True)
            return
        emoji, name, desc, commands = cat
        embed = discord.Embed(
            title=f"{emoji} {name}",
            description=desc,
            color=discord.Color.dark_gold(),
        )
        lines: list[str] = []
        for cmd, hint in commands:
            lines.append(f"`{cmd}`\n {hint}")
        embed.add_field(name="Commands", value="\n".join(lines), inline=False)
        embed.set_footer(text="Type any command in the chat bar: Discord will autocomplete the parameters.")
        view = discord.ui.View(timeout=300)
        back_btn = discord.ui.Button(label="Back to categories", style=discord.ButtonStyle.secondary)

        async def on_back(btn_inter: discord.Interaction) -> None:
            view2 = discord.ui.View(timeout=300)
            view2.add_item(_DmWizardCatSelect())
            await btn_inter.response.edit_message(
                content=None,
                embed=discord.Embed(
                    title="\U0001f3b2 DM Command Menu",
                    description="Pick a category to see available commands.",
                    color=discord.Color.dark_gold(),
                ),
                view=view2,
            )

        back_btn.callback = on_back
        view.add_item(back_btn)
        await interaction.response.edit_message(content=None, embed=embed, view=view)

@dm.command(name="wizard", description="Interactive command menu: browse all Fortune and Kami actions by category.")
async def dm_wizard_cmd(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    view = discord.ui.View(timeout=300)
    view.add_item(_DmWizardCatSelect())
    await interaction.response.send_message(
        embed=discord.Embed(
            title="\U0001f3b2 DM Command Menu",
            description="Pick a category to see available commands.",
            color=discord.Color.dark_gold(),
        ),
        view=view,
        ephemeral=True,
    )

@dm.command(name="party", description="DM overview: all active PCs on this server.")
async def party_overview(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    active = store.list_active_pcs(guild)
    if not active:
        await interaction.response.send_message("No active PCs on this server.", ephemeral=True)
        return
    embed = discord.Embed(title="Party Roster", color=discord.Color.gold())
    for owner_id, rec in active:
        c = rec.character
        rings = stats.all_rings(c)
        ring_str = " / ".join(f"{r[0].upper()}{v}" for r, v in rings.items())
        lvl = stats.wound_level_name(c)
        pen = stats.wound_penalty(c)
        cap = stats.total_wound_capacity(c)
        wound_str = f"{lvl}" + (f" ({pen})" if pen else "") + f": {c.wounds_taken}/{cap}"
        vp_str = f"VP {c.current_void_points}/{c.max_void_points}"
        header = " · ".join(b for b in (c.clan, c.school) if b) or " "
        val_parts = [
            f"{header} (Rank {stats.insight_rank(c)})",
            f"Rings: {ring_str}",
            f"Wounds: {wound_str}  ·  {vp_str}",
            f"Honor {c.honor:g} · Glory {c.glory:g} · Status {c.status:g}",
        ]
        if c.equipped_weapon:
            wield = c.equipped_weapon
            if c.off_hand_weapon:
                wield += f" + {c.off_hand_weapon}"
            if c.weapon_qualities:
                wield += f" [{', '.join(c.weapon_qualities)}]"
            val_parts.append(f"Wielding: {wield}")
        embed.add_field(
            name=f"{c.name}  (<@{owner_id}>)",
            value="\n".join(val_parts),
            inline=False,
        )
    embed.set_footer(text=f"{len(active)} active PC{'s' if len(active) != 1 else ''}")
    await interaction.response.send_message(embed=embed, ephemeral=True)

@dm.command(name="roles", description="Show who has the Fortune and Kami roles on this server.")
async def dm_roles(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    guild = interaction.guild
    if guild is None:
        await interaction.response.send_message("Not in a server.", ephemeral=True)
        return
    kami_role = discord.utils.get(guild.roles, name=ROLE_KAMI)
    fortune_role = discord.utils.get(guild.roles, name=ROLE_FORTUNE)
    lines: list[str] = []
    if kami_role:
        members = [m.mention for m in kami_role.members]
        lines.append(f"**{ROLE_KAMI}** (admin): {', '.join(members) if members else 'nobody'}")
    else:
        lines.append(f"**{ROLE_KAMI}** role not found: create it in Server Settings > Roles.")
    if fortune_role:
        members = [m.mention for m in fortune_role.members]
        lines.append(f"**{ROLE_FORTUNE}** (DM): {', '.join(members) if members else 'nobody'}")
    else:
        lines.append(f"**{ROLE_FORTUNE}** role not found: create it in Server Settings > Roles.")
    await interaction.response.send_message("\n".join(lines), ephemeral=True)

@dm.command(name="new_day", description="Advance one day: heal, refresh VP and spell slots for all PCs.")
async def dm_new_day(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    active = store.list_active_pcs(guild)
    if not active:
        await interaction.response.send_message("No active PCs on this server.", ephemeral=True)
        return
    lines = []
    for owner_id, rec in active:
        c = rec.character
        parts = []
        if stats.is_dead(c):
            lines.append(f"**{c.name}**: 💀 dead — no recovery")
            continue
        healed = 0
        rate = stats.natural_healing_rate(c)
        if c.wounds_taken > 0:
            old_wounds = c.wounds_taken
            c.wounds_taken = max(0, c.wounds_taken - rate)
            healed = old_wounds - c.wounds_taken
        if healed > 0:
            parts.append(f"healed {healed} wounds ({c.wounds_taken} left)")
        vp_old = c.current_void_points
        vp_cap = taint.void_point_cap(c)
        c.current_void_points = vp_cap
        if vp_old < vp_cap:
            parts.append(f"VP {vp_old} → {vp_cap}/{vp_cap}")
        if vp_cap < c.max_void_points:
            parts.append(f"Taint Rank {taint.taint_rank(c)}: max VP -1")
        for element in SPELL_ELEMENTS:
            c.spell_slots[element] = stats.spell_slot_max(c, element)
        c.void_spell_bonus = stats.void_bonus_max(c)
        # s42 periodic Taint resistance: cadence by Rank, Earth roll vs TN 5 + 5 x Rank.
        if c.taint > 0:
            interval = taint.periodic_roll_interval(taint.taint_rank(c))
            if interval is not None:
                c.taint_days_since_roll += 1
                if c.taint_days_since_roll >= interval:
                    c.taint_days_since_roll = 0
                    tr = taint.resolve_periodic_roll(c, engine)
                    tea = " +2k2 Jade Petal Tea" if tr["tea"] else ""
                    if tr["success"]:
                        parts.append(f"Taint resisted ({tr['rolled']}k{tr['kept']}{tea} = {tr['total']} vs TN {tr['tn']})")
                    else:
                        line = (f"☠️ Taint roll failed ({tr['rolled']}k{tr['kept']}{tea} = {tr['total']} vs TN {tr['tn']}): "
                                f"Taint {tr['old_taint']:g} → **{tr['new_taint']:g}**")
                        if tr["crossing"]:
                            line += f" — **Rank {tr['crossing']['new_rank']}**: {tr['crossing']['description']}"
                            if "mutation" in tr["crossing"]:
                                line += f" Mutation: {tr['crossing']['mutation']}."
                            if "madness" in tr["crossing"]:
                                line += f" Madness: {tr['crossing']['madness']}."
                        parts.append(line)
                else:
                    parts.append(f"Taint roll in {interval - c.taint_days_since_roll} day(s)")
        store.save(rec, note="new day")
        slots_str = ", ".join(
            f"{e.title()} {c.spell_slots[e]}" for e in SPELL_ELEMENTS
        )
        slots_str += f", Bonus {c.void_spell_bonus}"
        parts.append(f"slots: {slots_str}")
        lines.append(f"**{c.name}**: {' · '.join(parts)}")
    date_str = _advance_calendar(guild)
    embed = discord.Embed(
        title="New Day",
        description="\n".join(lines),
        color=discord.Color.green(),
    )
    footer = "Rest: full VP · Stamina x 2 healing · Spell slots: Ring per element + Void Ring bonus"
    if date_str:
        embed.add_field(name="Calendar", value=date_str, inline=False)
    else:
        footer += " · Set the date with /dm setdate"
    embed.set_footer(text=footer)
    await interaction.response.send_message(embed=embed)
    if date_str:
        await _update_date_display(guild, date_str, reason="A new day dawns in Rokugan.")


@dm.command(name="mount", description="Toggle mounted state on a character (outside combat). [Fortune]")
@app_commands.describe(
    member="Target player.",
    dismount="Dismount instead of mounting.",
)
async def dm_mount(
    interaction: discord.Interaction,
    member: discord.Member,
    dismount: bool = False,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = store.get_active(guild, str(member.id))
    if rec is None:
        await interaction.response.send_message(
            f"{member.display_name} has no active character.", ephemeral=True,
        )
        return
    c = rec.character
    mounting = not dismount
    if c.is_mounted == mounting:
        state = "already mounted" if mounting else "already dismounted"
        await interaction.response.send_message(
            f"**{c.name}** is {state}.", ephemeral=True,
        )
        return
    c.is_mounted = mounting
    prof = combat.get_armor(c.armor_name) if c.armor_name else None
    armor_note = ""
    if prof and prof.get("tn_bonus_mounted"):
        if mounting:
            c.armor_tn_bonus = prof["tn_bonus_mounted"]
        else:
            c.armor_tn_bonus = prof["tn_bonus"]
        armor_note = f" Armor TN bonus → +{c.armor_tn_bonus}."
    store.save(rec, note="mount" if mounting else "dismount")
    if mounting:
        await interaction.response.send_message(
            f"**{c.name}** mounts up.{armor_note} Riding armor skill penalty removed while mounted.",
        )
    else:
        await interaction.response.send_message(
            f"**{c.name}** dismounts.{armor_note}",
        )


def _format_rokugani_date(year: int, month: int, day: int) -> str:
    """Format a Rokugani date as a human-readable string."""
    month_name, season = ROKUGANI_MONTHS[month - 1]
    return f"Day {day} of the Month of the {month_name}, {season} — Year {year} (Isawa Calendar)"

def _date_embed(date_str: str) -> discord.Embed:
    return discord.Embed(
        title="Current Date",
        description=date_str,
        color=0xC4A747,
    )

async def _update_date_display(guild_id: str, date_str: str, reason: str = "Time has advanced.") -> None:
    """Edit the pinned date message and ping @everyone in the date channel."""
    info = store.get_date_channel(guild_id)
    if info is None:
        return
    channel_id, message_id = info
    channel = client.get_channel(int(channel_id))
    if channel is None:
        return
    if message_id:
        try:
            msg = await channel.fetch_message(int(message_id))
            await msg.edit(embed=_date_embed(date_str))
        except discord.NotFound:
            new_msg = await channel.send(embed=_date_embed(date_str))
            await new_msg.pin()
            store.set_date_channel(guild_id, channel_id, str(new_msg.id))
    await channel.send(f"@everyone {reason}\n**{date_str}**")

def _advance_calendar(guild_id: str) -> str | None:
    """Advance the guild's calendar by 1 day. Returns the new date string, or None if no date set."""
    cal = store.get_calendar(guild_id)
    if cal is None:
        return None
    year, month, day = cal
    day += 1
    if day > DAYS_PER_MONTH:
        day = 1
        month += 1
        if month > 12:
            month = 1
            year += 1
    store.set_calendar(guild_id, year, month, day)
    return _format_rokugani_date(year, month, day)

@dm.command(name="setdate", description="Set the Rokugani calendar date [Fortune]")
@app_commands.describe(
    year="Year number (Isawa Calendar).",
    month="Month (1-12): Hare, Dragon, Serpent, Horse, Goat, Monkey, Rooster, Dog, Boar, Rat, Ox, Tiger.",
    day="Day of the month (1-28).",
)
@app_commands.choices(month=[
    app_commands.Choice(name=f"{i}. {ROKUGANI_MONTHS[i - 1][0]} ({ROKUGANI_MONTHS[i - 1][1]})", value=i)
    for i in range(1, 13)
])
async def dm_setdate(
    interaction: discord.Interaction,
    year: app_commands.Range[int, 1, 9999],
    month: app_commands.Range[int, 1, 12],
    day: app_commands.Range[int, 1, 28],
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    store.set_calendar(guild, year, month, day)
    date_str = _format_rokugani_date(year, month, day)
    embed = discord.Embed(
        title="Calendar Set",
        description=date_str,
        color=0xC4A747,
    )
    await interaction.response.send_message(embed=embed)
    await _update_date_display(guild, date_str, reason="The calendar has been set.")

def _parse_advdis_name(raw: str, kind: str) -> tuple[dict | None, str]:
    """Parse an advantage/disadvantage name with optional parameter.

    Returns (lookup_entry, canonical_name).
    """
    input_name = raw.strip()
    base_name = input_name.split(":")[0].strip() if ":" in input_name else input_name
    entry = advantages.get(base_name, kind)
    canonical = entry["name"] if entry else base_name
    if ":" in input_name:
        param = input_name[input_name.index(":") + 1:].strip()
        canonical = f"{canonical}: {param}"
    return entry, canonical


def _auto_wield(c: Character) -> str:
    """If nothing is in hand but the character owns a catalog weapon, wield the first one.
    Returns the weapon wielded, or ''. Nothing wielded means every attack is unarmed."""
    if c.equipped_weapon:
        return c.equipped_weapon
    for w in c.weapons:
        if w.lower() in combat.WEAPON_CATALOG:
            c.equipped_weapon = w.lower()
            return c.equipped_weapon
    return ""

def _modify_inventory(
    inventory: dict[str, int], char_name: str,
    item_name: str, quantity: int, remove: bool,
) -> tuple[bool, str]:
    """Add or remove items from an inventory dict.

    Returns (ok, message).  When ok is False the caller should send the
    message as an ephemeral error and skip saving.
    """
    match_key = next((k for k in inventory if k.lower() == item_name.lower()), None)
    if remove:
        if match_key is None:
            return False, f"**{char_name}** doesn't have **{item_name}**."
        remaining = inventory[match_key] - quantity
        if remaining <= 0:
            del inventory[match_key]
            return True, f"Removed all **{match_key}** from **{char_name}**'s inventory."
        inventory[match_key] = remaining
        return True, f"Removed {quantity}× **{match_key}** from **{char_name}** ({remaining} left)."
    key = match_key or item_name
    inventory[key] = inventory.get(key, 0) + quantity
    total = inventory[key]
    return True, f"Added {quantity}× **{key}** to **{char_name}** (now {total})."


@dm.command(name="damage", description="Apply damage to a character (shows DM-approval buttons).")
@app_commands.describe(
    target="Character name (PC or NPC).",
    amount="Raw damage to apply (before Reduction).",
    reason="Source of the damage (spell, trap, environmental, etc.).",
)
@app_commands.autocomplete(target=_any_character_autocomplete)
async def dm_damage(
    interaction: discord.Interaction,
    target: str,
    amount: app_commands.Range[int, 1, 9999],
    reason: str = "",
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _find_any_character(guild, target)
    if rec is None:
        await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
        return
    c = rec.character
    wl = stats.wound_level_name(c)
    embed = discord.Embed(
        title=f"💥 Pending damage: {c.name}",
        color=discord.Color.orange(),
    )
    embed.add_field(
        name="Proposed",
        value=(
            f"**{amount}** raw damage"
            f"{f' ({reason})' if reason else ''}\n"
            f"Reduction: {c.armor_reduction} · Current: **{wl}** ({c.wounds_taken} wounds)"
        ),
        inline=False,
    )
    approval_ch_id = store.get_damage_approval_channel(guild) or store.get_approval_channel(guild)
    approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
    src_ch_id = interaction.channel_id if approval_ch else 0
    view = DmDamageView(
        target_id=rec.id, target_name=c.name,
        amount=amount, reason=reason,
        source_channel_id=src_ch_id,
    )
    owner_ping = f" <@{rec.owner_id}>" if rec.owner_id != NPC_OWNER else ""
    if approval_ch:
        embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
        embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
        await view.persist(await approval_ch.send(content=f"{_dm_ping(interaction.guild)}A DM can authorize the damage below.", embed=embed, view=view, allowed_mentions=_PING_MENTIONS))
        await interaction.response.send_message(
            f"💥 Pending damage on **{c.name}** — approval routed to the DM channel.{owner_ping}"
        )
    else:
        await interaction.response.send_message(
            content=f"{_dm_ping(interaction.guild)}A DM can authorize the damage below.{owner_ping}",
            embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
        )
        await view.persist(await interaction.original_response())

@dm.command(name="heal", description="Heal wounds on a character (shows DM-approval buttons).")
@app_commands.describe(
    target="Character name (PC or NPC).",
    amount="Wounds to heal.",
    reason="Source of healing (spell, medicine, rest, etc.).",
)
@app_commands.autocomplete(target=_any_character_autocomplete)
async def dm_heal(
    interaction: discord.Interaction,
    target: str,
    amount: app_commands.Range[int, 1, 9999],
    reason: str = "",
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _find_any_character(guild, target)
    if rec is None:
        await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
        return
    c = rec.character
    if stats.is_dead(c):
        await interaction.response.send_message(f"**{c.name}** is dead. PC death is permanent.", ephemeral=True)
        return
    if c.wounds_taken <= 0:
        await interaction.response.send_message(f"**{c.name}** has no wounds to heal.", ephemeral=True)
        return
    wl = stats.wound_level_name(c)
    embed = discord.Embed(
        title=f"💚 Pending healing: {c.name}",
        color=discord.Color.teal(),
    )
    embed.add_field(
        name="Proposed",
        value=(
            f"**{amount}** wounds healed"
            f"{f' ({reason})' if reason else ''}\n"
            f"Current: **{wl}** ({c.wounds_taken} wounds)"
        ),
        inline=False,
    )
    approval_ch_id = store.get_damage_approval_channel(guild) or store.get_approval_channel(guild)
    approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
    src_ch_id = interaction.channel_id if approval_ch else 0
    view = DmHealView(
        target_id=rec.id, target_name=c.name,
        amount=amount, reason=reason,
        source_channel_id=src_ch_id,
    )
    owner_ping = f" <@{rec.owner_id}>" if rec.owner_id != NPC_OWNER else ""
    if approval_ch:
        embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
        embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
        await view.persist(await approval_ch.send(content=f"{_dm_ping(interaction.guild)}A DM can authorize the healing below.", embed=embed, view=view, allowed_mentions=_PING_MENTIONS))
        await interaction.response.send_message(
            f"💚 Pending healing on **{c.name}** — approval routed to the DM channel.{owner_ping}"
        )
    else:
        await interaction.response.send_message(
            content=f"{_dm_ping(interaction.guild)}A DM can authorize the healing below.{owner_ping}",
            embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
        )
        await view.persist(await interaction.original_response())

# ===========================================================================
# /grapple group: grappling subsystem (s40)
# ===========================================================================

@dm.command(name="revive", description="Reverse a death caused by a bug (logged). [Fortune]")
@app_commands.describe(
    target="Character name (PC or NPC).",
    reason="Why this death is being reversed (required; written to the combat log).",
    wounds="Wounds to set the character to (default: the top of the Out level, alive but Out).",
)
@app_commands.autocomplete(target=_any_character_autocomplete)
async def dm_revive(
    interaction: discord.Interaction,
    target: str,
    reason: app_commands.Range[str, 5, 200],
    wounds: app_commands.Range[int, 0, 9999] | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _find_any_character(guild, target)
    if rec is None:
        await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
        return
    c = rec.character
    if not stats.is_dead(c):
        await interaction.response.send_message(f"**{c.name}** is not dead ({stats.wound_level_name(c)}).", ephemeral=True)
        return
    old = c.wounds_taken
    c.wounds_taken = wounds if wounds is not None else stats.total_wound_capacity(c)
    if stats.is_dead(c):
        c.wounds_taken = stats.total_wound_capacity(c)
    store.save(rec, note="revive")
    notes = [f"wounds {old} → {c.wounds_taken} ({stats.wound_level_name(c)})"]
    if rec.owner_id != NPC_OWNER and store.get_active(guild, rec.owner_id) is None:
        store.set_active(guild, rec.owner_id, rec.id)
        notes.append("set as the player's active character again")
    await _combat_log(guild, f"REVIVE: {c.name} by {interaction.user.display_name} — {reason} ({'; '.join(notes)})")
    embed = discord.Embed(
        title=f"🕊️ Revived: {c.name}",
        description=f"**Reason:** {reason}\n" + "\n".join(f"• {n}" for n in notes),
        color=discord.Color.teal(),
    )
    embed.set_footer(text=f"Staff override by {interaction.user.display_name} — logged")
    await interaction.response.send_message(embed=embed)

def _undo_diff(entity_type: str, old: dict, new: dict) -> list[str]:
    """Human-readable differences between two saved states, key fields first."""
    lines: list[str] = []
    if entity_type == "character":
        oc, nc = Character.from_dict(old), Character.from_dict(new)
        if oc.wounds_taken != nc.wounds_taken:
            lines.append(f"wounds {oc.wounds_taken} ({stats.wound_level_name(oc)}) → {nc.wounds_taken} ({stats.wound_level_name(nc)})")
        watched = [
            ("taint", "Taint"), ("current_void_points", "Void Points"), ("xp", "XP"),
            ("honor", "Honor"), ("glory", "Glory"), ("status", "Status"), ("infamy", "Infamy"),
            ("koku", "koku"), ("name", "name"),
        ]
        skip = {"wounds_taken"}
    else:
        oc, nc = None, None
        watched = [("wounds_taken", "wounds"), ("name", "name")]
        skip = set()
    for key, label in watched:
        if old.get(key) != new.get(key):
            lines.append(f"{label} {old.get(key)} → {new.get(key)}")
        skip.add(key)
    others = sorted(k for k in set(old) | set(new) if k not in skip and old.get(k) != new.get(k))
    if others:
        lines.append("also: " + ", ".join(others))
    return lines or ["no visible difference"]

@dm.command(name="undo", description="Roll back the last change to a character or creature (wounds, heal, Taint…). [Fortune]")
@app_commands.describe(
    target="Character or creature name. Leave empty for the most recent change on this server.",
    preview="Show the last few recorded changes instead of undoing anything.",
)
@app_commands.autocomplete(target=_any_character_autocomplete)
async def dm_undo(
    interaction: discord.Interaction,
    target: str | None = None,
    preview: bool = False,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    snaps = store.list_undo(guild, target, limit=5 if preview else 1)
    if not snaps:
        who = f" for **{target}**" if target else ""
        await interaction.response.send_message(f"Nothing recorded to undo{who}.", ephemeral=True)
        return
    now = time.time()
    if preview:
        lines = []
        for sn in snaps:
            cur = store.get_by_id(sn.entity_id) if sn.entity_type == "character" else store.get_creature_by_id(sn.entity_id)
            if cur is None:
                effect = "entity deleted since"
            else:
                cur_d = cur.character.to_dict() if sn.entity_type == "character" else cur.creature.to_dict()
                effect = "; ".join(_undo_diff(sn.entity_type, cur_d, sn.data))
            age = int((now - sn.created_at) // 60)
            lines.append(f"• **{sn.entity_name}** — {sn.note} ({age} min ago)\n  ↩ would restore: {effect}")
        embed = discord.Embed(
            title="↩ Undo preview (newest first)",
            description="\n".join(lines)[:4000],
            color=discord.Color.greyple(),
        )
        embed.set_footer(text="Run /dm undo with the name to roll back the newest entry for that character.")
        await interaction.response.send_message(embed=embed, ephemeral=True)
        return
    sn = snaps[0]
    cur = store.get_by_id(sn.entity_id) if sn.entity_type == "character" else store.get_creature_by_id(sn.entity_id)
    if cur is None:
        store.apply_undo(sn.id)  # drops the orphaned snapshot
        await interaction.response.send_message(
            f"**{sn.entity_name}** was deleted after that change; nothing to restore.", ephemeral=True,
        )
        return
    before_d = cur.character.to_dict() if sn.entity_type == "character" else cur.creature.to_dict()
    _, restored = store.apply_undo(sn.id)
    if not restored:
        await interaction.response.send_message(
            f"That change could not be restored: **{sn.entity_name}** would take back a name another sheet "
            "now uses. Rename the other sheet and run `/dm undo` again.", ephemeral=True,
        )
        return
    notes = _undo_diff(sn.entity_type, before_d, sn.data)
    if sn.entity_type == "character":
        after = store.get_by_id(sn.entity_id)
        was_dead = stats.is_dead(Character.from_dict(before_d))
        now_dead = stats.is_dead(after.character)
        if now_dead and not was_dead:
            notes += await _on_death(guild, after.character.name, after.owner_id, after.id)
        elif was_dead and not now_dead:
            if after.owner_id != NPC_OWNER and store.get_active(guild, after.owner_id) is None:
                store.set_active(guild, after.owner_id, after.id)
                notes.append("set as the player's active character again")
            notes.append("not re-added to any initiative list: use `/combat add` if needed")
    else:
        after_cr = store.get_creature_by_id(sn.entity_id).creature
        if after_cr.wounds_taken >= after_cr.wounds_dead and before_d.get("wounds_taken", 0) < after_cr.wounds_dead:
            notes += await _on_death(guild, after_cr.name, None, None)
    await _combat_log(guild, f"UNDO: {sn.entity_name} ({sn.note}) by {interaction.user.display_name} — {'; '.join(notes)}")
    embed = discord.Embed(
        title=f"↩ Undone: {sn.note} on {sn.entity_name}",
        description="\n".join(f"• {n}" for n in notes),
        color=discord.Color.dark_teal(),
    )
    remaining = len(store.list_undo(guild, sn.entity_name, limit=storage.UNDO_KEEP_PER_ENTITY))
    embed.set_footer(text=f"Staff action by {interaction.user.display_name} — logged. {remaining} earlier change(s) still undoable for {sn.entity_name}.")
    await interaction.response.send_message(embed=embed)

_PENDING_KIND_LABELS: dict[str, str] = {
    "attack_damage": "⚔️ Attack damage", "spell_damage": "📜 Spell damage", "dm_damage": "💥 DM damage",
    "dm_heal": "💚 DM healing", "creature_attack": "🐾 Creature damage", "medicine_treat": "💊 Medicine treatment",
    "char_approval": "📝 Character approval", "condition_request": "🩹 Condition request",
}

def _pending_summary(kind: str, state: str) -> str:
    try:
        args = json.loads(state).get("args", {})
    except (ValueError, AttributeError):
        args = {}
    if kind == "char_approval":
        cs = args.get("character_state") or {}
        return str(cs.get("name") or cs.get("character_name") or "new character")
    names = [args.get(k) for k in ("attacker_name", "healer_name", "attacker", "caster_name")]
    tgt = args.get("target_name") or args.get("name") or args.get("target")
    if kind == "condition_request" and tgt:
        return f"{str(args.get('condition', '')).title()} on {tgt}"
    src = next((n for n in names if n), None)
    if src and tgt:
        return f"{src} → {tgt}"
    return str(tgt or src or "")

@dm.command(name="pending", description="List approvals still waiting for a DM, with jump links [Fortune]")
async def dm_pending(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rows = [r for r in store.list_pending_views(guild) if r[2] in _PENDING_KIND_LABELS]
    if not rows:
        await interaction.response.send_message("✅ Nothing is waiting for a DM.", ephemeral=True)
        return
    now = time.time()
    lines = []
    for message_id, channel_id, kind, state, created_at in rows[:15]:
        age = int((now - created_at) // 60)
        age_s = f"{age} min" if age < 120 else f"{age // 60} h"
        link = f"[open](https://discord.com/channels/{guild}/{channel_id}/{message_id})" if channel_id else "*(no link: posted before this update)*"
        summary = _pending_summary(kind, state)
        lines.append(f"• {_PENDING_KIND_LABELS[kind]}{': **' + summary + '**' if summary else ''} — {age_s} ago — {link}")
    more = f"\n… and {len(rows) - 15} more." if len(rows) > 15 else ""
    embed = discord.Embed(
        title=f"⏳ Pending approvals ({len(rows)})",
        description=("\n".join(lines) + more)[:4000],
        color=discord.Color.orange(),
    )
    embed.set_footer(text="Resolved approvals leave this list. Entries older than 7 days are dropped at restart.")
    await interaction.response.send_message(embed=embed, ephemeral=True)

def _resolve_combatant_record(guild: str, cb: encounter.Combatant) -> storage.CharacterRecord | None:
    """Look up a stored character record from a Combatant (PC or NPC)."""
    if cb.is_npc:
        return store.get_by_name(guild, NPC_OWNER, cb.name)
    if cb.owner_id:
        return store.get_active(guild, cb.owner_id)
    return None

def _resolve_duelist(
    guild: str, channel_id: int, name: str, is_npc: bool, member: discord.Member | None,
) -> storage.CharacterRecord | None:
    """Resolve a duelist by NPC flag, member, encounter combatant, or NPC name."""
    if is_npc:
        return store.get_by_name(guild, NPC_OWNER, name)
    if member is not None:
        return store.get_active(guild, str(member.id))
    enc = encounters.get(channel_id)
    if enc:
        cb = enc.find(name)
        if cb:
            return _resolve_combatant_record(guild, cb)
    return store.get_by_name(guild, NPC_OWNER, name)

# ===========================================================================
# /void group: Void Point management
# ===========================================================================

@sheet_void.command(name="spend", description="Spend a Void Point (general purpose: +1k1, negate Conditional, etc.).")
@app_commands.describe(
    reason="What the VP is for (e.g. '+1k1 on Investigation check').",
    member="Player spending VP (uses their active character). Omit = yourself.",
    npc_name="NPC name [Fortune]",
)
async def void_spend(
    interaction: discord.Interaction,
    reason: str,
    member: discord.Member | None = None,
    npc_name: str | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if npc_name:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_name(guild, NPC_OWNER, npc_name)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{npc_name}**.", ephemeral=True)
            return
    elif member is not None:
        if not _is_dm(interaction) and member.id != interaction.user.id:
            await interaction.response.send_message(f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to spend VP for another player.", ephemeral=True)
            return
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
            return
    c = rec.character
    if c.current_void_points <= 0:
        await interaction.response.send_message(
            f"**{c.name}** has no Void Points remaining (0/{c.max_void_points}).", ephemeral=True
        )
        return
    c.current_void_points -= 1
    _tally(interaction.channel_id, c.name, "void")
    store.save(rec)
    await interaction.response.send_message(
        f"🌀 **{c.name}** spends a Void Point: {reason}\n"
        f"  VP remaining: **{c.current_void_points}/{c.max_void_points}**"
    )

@sheet_void.command(name="refresh", description="Refresh Void Points (rest = full, or Meditation/Void check for 1).")
@app_commands.describe(
    mode="How VP are being refreshed.",
    member="Player refreshing (uses their active character). Omit = yourself.",
    npc_name="NPC name [Fortune]",
    tn="Meditation TN (only for meditation mode; default 20).",
)
@app_commands.choices(mode=[
    app_commands.Choice(name="Rest (full refresh)", value="rest"),
    app_commands.Choice(name="Meditation (roll Meditation/Void, recover 1 on success)", value="meditation"),
])
async def void_refresh(
    interaction: discord.Interaction,
    mode: app_commands.Choice[str],
    member: discord.Member | None = None,
    npc_name: str | None = None,
    tn: app_commands.Range[int, 1, 100] | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if npc_name:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_name(guild, NPC_OWNER, npc_name)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{npc_name}**.", ephemeral=True)
            return
    elif member is not None:
        if not _is_dm(interaction) and member.id != interaction.user.id:
            await interaction.response.send_message(f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to refresh VP for another player.", ephemeral=True)
            return
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
            return
    c = rec.character
    vp_cap = taint.void_point_cap(c)
    cap_note = f" (Taint Rank {taint.taint_rank(c)}: max VP -1)" if vp_cap < c.max_void_points else ""
    if mode.value == "rest":
        if not npc_name and (member is None or member.id == interaction.user.id):
            if not await _require_dm_role(interaction):
                return
        old = c.current_void_points
        c.current_void_points = vp_cap
        store.save(rec)
        await interaction.response.send_message(
            f"🌀 **{c.name}** rests and recovers all Void Points.\n"
            f"  VP: {old} → **{c.current_void_points}/{vp_cap}**{cap_note}"
        )
    else:
        if c.current_void_points >= vp_cap:
            await interaction.response.send_message(
                f"**{c.name}** is already at full VP ({c.current_void_points}/{vp_cap}){cap_note}.",
                ephemeral=True,
            )
            return
        meditation_tn = tn if tn is not None else 20
        meditation_skill = c.skills.get("Meditation", 0)
        rolled = c.void_ring + meditation_skill
        kept = c.void_ring
        explodes = meditation_skill > 0
        wp = stats.wound_penalty(c)
        result = engine.roll_and_keep(max(1, rolled), max(1, kept), explodes)
        total = result.total + wp
        success = total >= meditation_tn
        if success:
            c.current_void_points = min(c.current_void_points + 1, vp_cap)
        store.save(rec)
        embed = discord.Embed(
            title=f"🧘 Meditation: {c.name}",
            color=discord.Color.teal() if success else discord.Color.greyple(),
        )
        wp_str = f" {wp}" if wp else ""
        embed.add_field(
            name="Roll",
            value=f"Meditation/Void ({rolled}k{kept}{wp_str}) vs TN **{meditation_tn}**",
            inline=False,
        )
        embed.add_field(name="Dice", value=_format_dice(result), inline=False)
        if success:
            embed.add_field(
                name="Result",
                value=(
                    f"**{total}** vs TN {meditation_tn}: ✅ **Success!** Recovers 1 VP.\n"
                    f"VP: **{c.current_void_points}/{c.max_void_points}**"
                ),
                inline=False,
            )
        else:
            embed.add_field(
                name="Result",
                value=(
                    f"**{total}** vs TN {meditation_tn}: ❌ **Fails.** No VP recovered.\n"
                    f"VP: **{c.current_void_points}/{c.max_void_points}**"
                ),
                inline=False,
            )
        await interaction.response.send_message(embed=embed)

@sheet_void.command(name="status", description="Show current Void Points for a character.")
@app_commands.describe(
    member="Player to check (uses their active character). Omit = yourself.",
    npc_name="NPC name [Fortune]",
)
async def void_status(
    interaction: discord.Interaction,
    member: discord.Member | None = None,
    npc_name: str | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if npc_name:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_name(guild, NPC_OWNER, npc_name)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{npc_name}**.", ephemeral=True)
            return
    elif member is not None:
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
            return
    c = rec.character
    vp_cap = taint.void_point_cap(c)
    bar_full = "🟣" * c.current_void_points
    bar_empty = "⚫" * max(0, vp_cap - c.current_void_points)
    cap_note = f"\n  Taint Rank {taint.taint_rank(c)}: maximum reduced by 1" if vp_cap < c.max_void_points else ""
    await interaction.response.send_message(
        f"🌀 **{c.name}**: Void Points: **{c.current_void_points}/{vp_cap}**\n"
        f"  {bar_full}{bar_empty}\n"
        f"  Void Ring: **{c.void_ring}**{cap_note}",
        ephemeral=True,
    )

# ===========================================================================
# /help: categorized command reference
# ===========================================================================

_HELP_BLURBS: dict[str, str] = {
    "sheet": "Your character sheet: create, view, Void, Kata, Kiho, export. One character per player; staff use activate to act as NPCs.",
    "stat": "Staff sheet edits: traits, skills, numeric fields, armor, qualities, advantages. Players use /inventory for gear and /xp to advance.",
    "inventory": "Your gear and purse in one panel: wield, weapons, items, koku.",
    "xp": "Spend Experience on traits, skills, emphases, kata, kiho, spells and advantages.",
    "roll": "Roll & Keep dice, with optional TN, Raises and Emphasis.",
    "dice": "Quick dice shorthand: 5k3, 7k2+5.",
    "macro": "Save and roll your usual dice pools.",
    "history": "Recent rolls in this channel.",
    "check": "Skill, trait and situational checks for your character. Rolling for others or NPCs needs Fortune.",
    "combat": "Initiative and turn order. Your own actions are under /fight; grapples, duels and battles under /engage.",
    "fight": "Your actions in a fight: attack, stance, guard, full defense, your status card.",
    "engage": "Grapple, Iaijutsu duel and mass battle subsystems (run by Fortune).",
    "spell": "Browse spells, cast, resist, importune, spell damage.",
    "players": "Directory of approved player characters.",
    "compare": "Compare two characters side by side.",
    "whoami": "Your character hub: status card with buttons for Void, Kata, Kiho, tattoos, inventory, full sheet, export.",
    "room": "Private play rooms (threads) with invites.",
    "location": "In-character areas and location channels.",
    "date": "The current Rokugani calendar date.",
    "npc": "Stored NPCs: build with exact stats, templates, generate, view, place in rooms, speak as them [Fortune].",
    "npc-edit": "Edit NPC stats and gear [Fortune].",
    "creature": "Bestiary creatures: spawn, wound, attack [Fortune].",
    "category": "Group NPCs and creatures for bulk actions [Fortune].",
    "dm": "Fortune and Kami tools: approvals, new day, damage, undo, revive, channels.",
    "ref": "Weapons, armor, schools, families, kata, kiho, advantages, tattoos, heritage, travel, modifiers.",
    "setup": "Server setup [Kami].",
    "sync": "Re-sync slash commands [Kami].",
    "ping": "Is the bot alive?",
    "help": "This overview.",
}
_HELP_SECTIONS: list[tuple[str, list[str]]] = [
    ("Getting started", ["help", "whoami", "players", "compare", "date"]),
    ("Your character", ["sheet", "inventory", "xp", "stat"]),
    ("Dice and checks", ["roll", "dice", "check", "macro", "history"]),
    ("Fights and magic", ["combat", "fight", "engage", "spell"]),
    ("Places", ["room", "location"]),
    ("Rules reference", ["ref"]),
    ("Staff [Fortune]", ["npc", "npc-edit", "creature", "category", "dm"]),
    ("Admin [Kami]", ["setup", "sync", "ping"]),
]
_HELP_ORDER: list[str] = [name for _, names in _HELP_SECTIONS for name in names]
_HELP_START = (
    "**New here?** `/sheet create` makes a character, `/whoami` is your character dashboard (spend Void, set Kata, "
    "open inventory), `/players` shows who is around, `/roll` rolls dice, "
    "`/check skill` rolls a skill for your character. In a fight: `/combat` runs initiative, `/fight` is what "
    "you do on your turn, `/engage` covers grapples, duels and battles. **[Fortune]** = DM role, **[Kami]** = admin."
)
_HELP_TAG_RE = re.compile(r"\s*\[(Fortune|Kami)\]\.?\s*$")

def _help_desc(desc: str) -> str:
    """One sentence, ending in a period, with the role tag (if any) last."""
    text = str(desc or "").strip()
    m = _HELP_TAG_RE.search(text)
    tag = f" [{m.group(1)}]" if m else ""
    core = text[: m.start()] if m else text
    core = core.rstrip().rstrip(":;,")
    if core and core[-1] not in ".?!":
        core += "."
    return core + tag

def _help_leaves(cmd: app_commands.Command | app_commands.Group, path: str = "") -> list[tuple[str, str]]:
    p = f"{path} {cmd.name}".strip()
    if isinstance(cmd, app_commands.Group):
        out: list[tuple[str, str]] = []
        for sub in cmd.commands:
            out.extend(_help_leaves(sub, p))
        return out
    return [(f"/{p}", cmd.description)]

def _help_page_lines(cmd: app_commands.Command | app_commands.Group) -> list[str]:
    """A group's commands: plain commands first, then each sub-group under its own header."""
    if not isinstance(cmd, app_commands.Group):
        return [f"`/{cmd.name}`: {_help_desc(cmd.description)}"]
    plain = [c for c in cmd.commands if not isinstance(c, app_commands.Group)]
    subgroups = [c for c in cmd.commands if isinstance(c, app_commands.Group)]
    lines = [f"`/{cmd.name} {c.name}`: {_help_desc(c.description)}" for c in plain]
    for sg in subgroups:
        lines.append("")
        lines.append(f"**/{cmd.name} {sg.name}**: {_help_desc(sg.description)}")
        lines.extend(f"`/{cmd.name} {sg.name} {c.name}`: {_help_desc(c.description)}" for c in sg.commands)
    return lines

# Top-level commands as registered at import. After the startup sync the tree's
# global list is empty (commands are copied per guild and the global copies
# cleared), so /help must not read the live tree.
_HELP_COMMANDS: list[app_commands.Command | app_commands.Group] = []

def _help_top() -> list[app_commands.Command | app_commands.Group]:
    cmds = {c.name: c for c in (_HELP_COMMANDS or client.tree.get_commands())}
    ordered = [cmds.pop(n) for n in _HELP_ORDER if n in cmds]
    return ordered + [cmds[n] for n in sorted(cmds)]

async def _help_category_autocomplete(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    cur = (current or "").lower().lstrip("/")
    return [app_commands.Choice(name=f"/{c.name}", value=c.name) for c in _help_top() if cur in c.name][:25]

@client.tree.command(
    name="help",
    description="All bot commands by group, always current. Pick a group to see every command in it.",
)
@app_commands.describe(category="A command group, e.g. combat (omit for the overview).")
@app_commands.autocomplete(category=_help_category_autocomplete)
async def help_command(
    interaction: discord.Interaction,
    category: str | None = None,
) -> None:
    top = _help_top()
    if category:
        key = category.strip().lstrip("/").lower()
        cmd = next((c for c in top if c.name == key), None)
        if cmd is None:
            names = ", ".join(f"`/{c.name}`" for c in top)
            await interaction.response.send_message(
                f"No command group called **{category}**. Groups: {names}.", ephemeral=True
            )
            return
        leaves = _help_leaves(cmd)
        lines = _help_page_lines(cmd)
        blurb = _HELP_BLURBS.get(cmd.name, "")
        embeds: list[discord.Embed] = []
        chunk: list[str] = []
        size = len(blurb) + 2
        for line in lines:
            if size + len(line) + 1 > 3900 and chunk:
                embeds.append(discord.Embed(description="\n".join(chunk), color=discord.Color.gold()))
                chunk, size = [], 0
            chunk.append(line); size += len(line) + 1
        embeds.append(discord.Embed(description="\n".join(chunk).strip(), color=discord.Color.gold()))
        embeds[0].title = f"Rokugan Bot: /{cmd.name} ({len(leaves)} command{'s' if len(leaves) != 1 else ''})"
        if blurb:
            embeds[0].description = blurb + "\n\n" + (embeds[0].description or "")
        # One embed per message: Discord caps a single message at 6000 characters across embeds.
        await interaction.response.send_message(embed=embeds[0], ephemeral=True)
        for extra in embeds[1:]:
            await interaction.followup.send(embed=extra, ephemeral=True)
        return
    # Overview: sections of one line per group in the body (an embed holds at
    # most 25 fields, and there are more groups than that).
    by_name = {c.name: c for c in top}
    listed: set[str] = set()
    parts: list[str] = []
    for section, names in _HELP_SECTIONS + [("Other", [n for n in by_name if n not in _HELP_ORDER])]:
        entries = []
        for name in names:
            cmd = by_name.get(name)
            if cmd is None:
                continue
            listed.add(name)
            n = len(_help_leaves(cmd))
            label = f"**/{cmd.name}**" + (f" ({n})" if n > 1 else "")
            entries.append(f"{label}: {_help_desc(_HELP_BLURBS.get(cmd.name, cmd.description))}")
        if entries:
            parts.append(f"__**{section}**__\n" + "\n".join(entries))
    body = (
        _HELP_START
        + "\n\nUse `/help category:` to list every command in a group. All game math is L5R 4th Edition.\n\n"
        + "\n\n".join(parts)
    )
    embed = discord.Embed(title="Rokugan Bot: Command Reference", description=body[:4096], color=discord.Color.gold())
    embed.set_footer(text="Tip: /help category:combat")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ===========================================================================
# /npc group: generate and manage NPC characters (s22.4 templates)
# ===========================================================================

@npc_group.command(name="generate", description="Generate an NPC samurai from a Clan/Family/School/Rank template. [Fortune]")
@app_commands.describe(
    name="NPC name.",
    insight_rank="Insight Rank 1–5 (power level; higher = stronger).",
    clan="Clan (flavor).",
    family="Family (flavor).",
    school="School (catalog match auto-fills skills, honor, clan, type; s22.4 ring bands already include the Benefit).",
    school_type="School type (default Bushi; a catalog school sets this).",
    skills="Override the school skills (comma-separated). One becomes the specialty.",
    base_honor="Starting Honor before ±0.5 variance (a catalog school sets this).",
)
@app_commands.autocomplete(school=_basic_school_autocomplete)
@app_commands.choices(school_type=_SCHOOL_CHOICES)
async def npc_generate(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 64],
    insight_rank: app_commands.Range[int, 1, 5],
    clan: str | None = None,
    family: str | None = None,
    school: str | None = None,
    school_type: app_commands.Choice[str] | None = None,
    skills: str | None = None,
    base_honor: app_commands.Range[float, 0.0, 10.0] | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return

    school_skills = [s for s in skills.split(",")] if skills else None
    resolved_type = school_type.value if school_type else "Bushi"
    # A catalog school fills in the concrete skills, honor, clan, and type. The
    # Benefit is NOT re-applied here: the s22.4 ring bands already reflect it.
    catalog = schools.get(school) if school else None
    if catalog:
        eff_skills, eff_honor, eff_outfit = schools.effective_fields(catalog)
        if not school_skills:
            assigned, _ = schools.parse_skills(eff_skills)
            school_skills = [nm for nm, _r, _e in assigned]
        if base_honor is None:
            base_honor = schools.parse_honor(eff_honor)
        clan = clan or catalog.get("clan")
        if school_type is None and schools._infer_type(catalog):
            resolved_type = schools._infer_type(catalog)
        school = catalog["name"]

    char = npc_gen.generate(
        name, insight_rank, engine,
        clan=clan or "", family=family or "", school=school or "",
        school_type=resolved_type,
        school_skills=school_skills,
        base_honor=(base_honor if base_honor is not None else 3.5),
    )
    if catalog:
        schools.apply_outfit(char, eff_outfit)
        _auto_wield(char)
    try:
        rec = store.create_character(str(interaction.guild_id), NPC_OWNER, char)
    except storage.DuplicateNameError:
        await interaction.response.send_message(
            f"An NPC named **{name}** already exists. Pick another name or delete it first.",
            ephemeral=True,
        )
        return
    note = f"🎭 Generated **{name}**: a Rank {insight_rank} {char.school_type} NPC (stats have random variance)."
    if not school_skills:
        note += " No skills set: regenerate with `skills:` to give it school skills."
    await interaction.response.send_message(content=note, embed=build_sheet_embed(rec))

@npc_group.command(name="view", description="View a stored NPC.")
@app_commands.describe(name="The NPC to view.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_view(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    await interaction.response.send_message(embed=build_sheet_embed(rec))

@npc_group.command(name="list", description="List the NPCs on this server.")
async def npc_list(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    recs = store.list_by_owner(str(interaction.guild_id), NPC_OWNER)
    if not recs:
        await interaction.response.send_message(
            "No NPCs yet. Build one with `/npc create` or `/npc form`, or spawn from a template (Fortune).", ephemeral=True
        )
        return
    lines = [
        f"• {'💀 ' if stats.is_dead(r.character) else ''}**{r.character.name}**: {r.character.clan or ' '} {r.character.school_type} "
        f"(Rank {r.character.school_rank})"
        for r in recs
    ]
    pages = _paginate(lines, "🎭 **NPCs on this server: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0])
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view)

@npc_group.command(name="delete", description="Delete a stored NPC. [Fortune]")
@app_commands.describe(name="The NPC to delete.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_delete(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    store.delete(rec.id)
    await interaction.response.send_message(f"Deleted NPC **{rec.character.name}**.", ephemeral=True)

def _resolve_npc(
    interaction: discord.Interaction, name: str
) -> tuple[storage.CharacterRecord | None, str | None]:
    if interaction.guild_id is None:
        return None, "Please use this in a server channel."
    if not _is_dm(interaction):
        return None, f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to edit NPCs."
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        return None, f"No NPC named **{name}**."
    return rec, None

@npc_edit_group.command(name="trait", description="Set a Trait (or Void) on an NPC. [Fortune]")
@app_commands.describe(name="NPC name.", trait="Which Trait.", value="New value (0-10).")
@app_commands.choices(trait=_TRAIT_CHOICES)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_trait(
    interaction: discord.Interaction,
    name: str,
    trait: app_commands.Choice[str],
    value: app_commands.Range[int, 0, 10],
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.set_trait(trait.value, value)
    store.save(rec)
    label = "Void" if trait.value == "void" else trait.value.capitalize()
    await interaction.response.send_message(
        f"Set **{label}** to **{value}** on **{rec.character.name}**.", embed=build_sheet_embed(rec)
    )

@npc_edit_group.command(name="skill", description="Set a skill rank on an NPC (0 removes it). [Fortune]")
@app_commands.describe(name="NPC name.", skill="Skill name.", rank="Rank 0-10 (0 removes).")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_skill(
    interaction: discord.Interaction,
    name: str,
    skill: app_commands.Range[str, 1, 40],
    rank: app_commands.Range[int, 0, 10],
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    skill_name = skill.strip().title()
    if rank == 0:
        rec.character.skills.pop(skill_name, None)
        msg = f"Removed **{skill_name}** from **{rec.character.name}**."
    else:
        rec.character.skills[skill_name] = rank
        msg = f"Set **{skill_name}** to rank **{rank}** on **{rec.character.name}**."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@npc_edit_group.command(name="set", description="Set a numeric field on an NPC (honor, armor, void points, etc.). [Fortune]")
@app_commands.describe(name="NPC name.", field="Which field.", value="New value.")
@app_commands.choices(field=_SET_CHOICES)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_set(
    interaction: discord.Interaction,
    name: str,
    field: app_commands.Choice[str],
    value: float,
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    _apply_numeric_field(rec.character, field.value, value)
    store.save(rec)
    await interaction.response.send_message(
        f"Updated **{field.value}** on **{rec.character.name}**.", embed=build_sheet_embed(rec)
    )

@npc_edit_group.command(name="wound", description="Apply wounds to an NPC. [Fortune]")
@app_commands.describe(name="NPC name.", amount="Wounds to apply.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_wound(
    interaction: discord.Interaction, name: str, amount: app_commands.Range[int, 1, 1000]
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if await _refuse_if_dead(interaction, c):
        return
    old = stats.wound_level_name(c)
    c.wounds_taken += amount
    store.save(rec, note="wound")
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    dead = ""
    if stats.is_dead(c):
        death_notes = await _on_death(str(interaction.guild_id), c.name, rec.owner_id, rec.id)
        dead = "  💀 **DEAD**" + "".join(f"\n💀 {n}" for n in death_notes)
    await interaction.response.send_message(
        f"**{c.name}** takes **{amount}** wounds → {c.wounds_taken} total{crossed}{dead}",
        embed=build_sheet_embed(rec),
    )

@npc_edit_group.command(name="heal", description="Heal wounds on an NPC. [Fortune]")
@app_commands.describe(name="NPC name.", amount="Wounds to heal.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_heal(
    interaction: discord.Interaction, name: str, amount: app_commands.Range[int, 1, 1000]
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if await _refuse_if_dead(interaction, c):
        return
    old = stats.wound_level_name(c)
    c.wounds_taken = max(0, c.wounds_taken - amount)
    store.save(rec, note="heal")
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    await interaction.response.send_message(
        f"**{c.name}** heals **{amount}** wounds → {c.wounds_taken} total{crossed}",
        embed=build_sheet_embed(rec),
    )

@npc_group.command(name="rename", description="Rename an NPC. [Fortune]")
@app_commands.describe(name="Current NPC name.", new_name="New name.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_rename(
    interaction: discord.Interaction, name: str, new_name: app_commands.Range[str, 1, 64]
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if store.get_by_name(str(interaction.guild_id), NPC_OWNER, new_name) is not None:
        await interaction.response.send_message(
            f"An NPC named **{new_name}** already exists.", ephemeral=True
        )
        return
    old_name = rec.character.name
    rec.character.name = new_name
    store.save(rec)
    await interaction.response.send_message(
        f"Renamed **{old_name}** → **{new_name}**.", embed=build_sheet_embed(rec)
    )

# -- NPC room placement & speech -------------------------------------------

async def _get_npc_webhook(channel: discord.TextChannel) -> discord.Webhook:
    """Get or create a reusable webhook on *channel* for NPC speech."""
    cached = _npc_webhooks.get(channel.id)
    if cached is not None:
        return cached
    for wh in await channel.webhooks():
        if wh.name == WEBHOOK_NAME and wh.user == client.user:
            _npc_webhooks[channel.id] = wh
            return wh
    wh = await channel.create_webhook(name=WEBHOOK_NAME)
    _npc_webhooks[channel.id] = wh
    return wh

async def _room_npc_autocomplete(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    """Autocomplete listing NPCs placed in the current room."""
    rec = store.get_room_by_thread(str(interaction.channel_id))
    if rec is None:
        return []
    names = store.list_room_npcs(rec.id)
    cur = current.lower().strip()
    return [
        app_commands.Choice(name=n, value=n)
        for n in sorted(names) if cur in n.lower()
    ][:25]

@npc_group.command(name="place", description="Place an NPC in this room (run inside a room thread). [Fortune]")
@app_commands.describe(name="NPC to place in the room.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_place(interaction: discord.Interaction, name: str) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    room = store.get_room_by_thread(str(interaction.channel_id))
    if room is None:
        await interaction.response.send_message(
            "Run this inside a room's thread (open one with `/room create`).", ephemeral=True
        )
        return
    store.place_npc_in_room(room.id, rec.character.name)
    npcs = store.list_room_npcs(room.id)
    npc_list = ", ".join(f"**{n}**" for n in sorted(npcs))
    await interaction.response.send_message(
        f"🎭 **{rec.character.name}** enters **{room.name}**.\n"
        f"NPCs present: {npc_list}"
    )

@npc_group.command(name="dismiss", description="Remove an NPC from this room. [Fortune]")
@app_commands.describe(name="NPC to remove from the room.")
@app_commands.autocomplete(name=_room_npc_autocomplete)
async def npc_dismiss(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    room = store.get_room_by_thread(str(interaction.channel_id))
    if room is None:
        await interaction.response.send_message(
            "Run this inside a room's thread (open one with `/room create`).", ephemeral=True
        )
        return
    current = store.list_room_npcs(room.id)
    matched = next((n for n in current if n.lower() == name.lower()), None)
    if matched is None:
        await interaction.response.send_message(
            f"**{name}** is not in this room.", ephemeral=True
        )
        return
    store.remove_npc_from_room(room.id, matched)
    remaining = store.list_room_npcs(room.id)
    npc_list = ", ".join(f"**{n}**" for n in sorted(remaining)) if remaining else "none"
    await interaction.response.send_message(
        f"🎭 **{matched}** leaves **{room.name}**.\nNPCs present: {npc_list}"
    )

@npc_group.command(name="say", description="Speak as an NPC (posts as their name via webhook). [Fortune]")
@app_commands.describe(name="Which NPC speaks.", message="What they say.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_say(interaction: discord.Interaction, name: str, message: app_commands.Range[str, 1, 2000]) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    npc_rec = store.get_by_name(guild, NPC_OWNER, name)
    if npc_rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    channel = interaction.channel
    thread_target = None
    if isinstance(channel, discord.Thread):
        thread_target = channel
        channel = channel.parent
    if not isinstance(channel, discord.TextChannel):
        await interaction.response.send_message(
            "Webhook speech only works in text channels (or room threads).", ephemeral=True
        )
        return
    try:
        wh = await _get_npc_webhook(channel)
        kwargs: dict = {"content": message, "username": npc_rec.character.name, "wait": True}
        if thread_target is not None:
            kwargs["thread"] = thread_target
        await wh.send(**kwargs)
        await interaction.response.send_message("✓", ephemeral=True, delete_after=1)
    except discord.Forbidden:
        await interaction.response.send_message(
            "I need **Manage Webhooks** permission in this channel to speak as NPCs.", ephemeral=True
        )
    except discord.HTTPException as exc:
        await interaction.response.send_message(f"Webhook failed: {exc}", ephemeral=True)

# --- NPC inventory, spells, notes, clone -----------------------------------

@npc_edit_group.command(name="item", description="Add or remove items from an NPC's inventory. [Fortune]")
@app_commands.describe(
    name="NPC name.", item="Item name.",
    quantity="How many (default 1).", remove="Remove instead of adding.",
)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_item(
    interaction: discord.Interaction, name: str, item: str,
    quantity: app_commands.Range[int, 1, 9999] = 1, remove: bool = False,
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    ok, msg = _modify_inventory(c.inventory, c.name, item.strip(), quantity, remove)
    if not ok:
        await interaction.response.send_message(msg, ephemeral=True)
        return
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@npc_edit_group.command(name="spell", description="Add or remove a spell from an NPC's known spell list. [Fortune]")
@app_commands.describe(
    name="NPC name.", spell="Spell name to add or remove.", remove="Remove instead of adding.",
)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_spell(
    interaction: discord.Interaction, name: str, spell: str, remove: bool = False,
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    spell_name = spell.strip()
    if remove:
        match = next((s for s in c.spells_known if s.lower() == spell_name.lower()), None)
        if match is None:
            await interaction.response.send_message(
                f"**{c.name}** doesn't know **{spell_name}**.", ephemeral=True,
            )
            return
        c.spells_known.remove(match)
        msg = f"Removed spell **{match}** from **{c.name}**."
    else:
        if any(s.lower() == spell_name.lower() for s in c.spells_known):
            await interaction.response.send_message(
                f"**{c.name}** already knows **{spell_name}**.", ephemeral=True,
            )
            return
        c.spells_known.append(spell_name)
        msg = f"Added spell **{spell_name}** to **{c.name}**."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@npc_group.command(name="notes", description="Set or clear notes on an NPC. [Fortune]")
@app_commands.describe(
    name="NPC name.", text="Notes text (omit or leave empty to clear).",
)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_notes(
    interaction: discord.Interaction, name: str, text: str = "",
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.notes = text.strip()
    store.save(rec)
    if rec.character.notes:
        msg = f"Notes set on **{rec.character.name}**: *{rec.character.notes}*"
    else:
        msg = f"Notes cleared on **{rec.character.name}**."
    await interaction.response.send_message(msg, ephemeral=True)

@npc_group.command(name="clone", description="Clone an NPC with a new name. [Fortune]")
@app_commands.describe(name="NPC to clone.", new_name="Name for the clone.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_clone(
    interaction: discord.Interaction, name: str, new_name: app_commands.Range[str, 1, 64],
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    clone = copy.deepcopy(rec.character)
    clone.name = new_name.strip()
    clone.wounds_taken = 0
    try:
        new_rec = store.create_character(rec.guild_id, NPC_OWNER, clone)
    except storage.DuplicateNameError:
        await interaction.response.send_message(
            f"An NPC named **{clone.name}** already exists.", ephemeral=True,
        )
        return
    await interaction.response.send_message(
        f"🎭 Cloned **{rec.character.name}** → **{clone.name}**.",
        embed=build_sheet_embed(new_rec),
    )

@npc_edit_group.command(name="equip", description="Set an NPC's equipped weapon and/or armor name. [Fortune]")
@app_commands.describe(
    name="NPC name.",
    weapon="Equipped weapon name (empty to clear).",
    off_hand="Off-hand weapon (empty to clear).",
    armor="Armor name (empty to clear).",
)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_equip(
    interaction: discord.Interaction, name: str,
    weapon: str | None = None, off_hand: str | None = None, armor: str | None = None,
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    changes: list[str] = []
    if weapon is not None:
        c.equipped_weapon = weapon.strip()
        changes.append(f"Weapon: **{c.equipped_weapon or '(none)'}**")
    if off_hand is not None:
        c.off_hand_weapon = off_hand.strip()
        changes.append(f"Off-hand: **{c.off_hand_weapon or '(none)'}**")
    if armor is not None:
        a = armor.lower().strip()
        if a in ("none", "", "remove"):
            c.armor_name = ""
            c.owned_armor = ""
            c.armor_tn_bonus = 0
            c.armor_reduction = 0
            changes.append("Armor: **(none)**")
        else:
            spec = combat.get_armor(a)
            if spec is not None:
                c.armor_name = a
                c.owned_armor = a
                c.armor_tn_bonus = spec["tn_bonus"]
                c.armor_reduction = spec["reduction"]
                changes.append(f"Armor: **{a}** (ATN+{spec['tn_bonus']}, Red {spec['reduction']})")
            else:
                c.armor_name = a
                c.owned_armor = a
                changes.append(f"Armor: **{a}** (custom — set ATN/Reduction manually)")
    if not changes:
        await interaction.response.send_message(
            "Provide at least one of `weapon:`, `off_hand:`, or `armor:`.", ephemeral=True,
        )
        return
    store.save(rec)
    await interaction.response.send_message(
        f"🎭 **{c.name}** equipment updated:\n" + "\n".join(changes),
        embed=build_sheet_embed(rec),
    )

_FEATURE_FIELDS = [
    app_commands.Choice(name="Advantage", value="advantages"),
    app_commands.Choice(name="Disadvantage", value="disadvantages"),
    app_commands.Choice(name="Technique", value="techniques"),
    app_commands.Choice(name="Kata", value="katas"),
    app_commands.Choice(name="Kiho", value="kiho"),
    app_commands.Choice(name="Weapon (owned)", value="weapons"),
    app_commands.Choice(name="Weapon Quality", value="weapon_qualities"),
    app_commands.Choice(name="Emphasis", value="_emphasis"),
]

@npc_edit_group.command(name="feature", description="Add or remove an advantage, technique, kata, kiho, weapon, quality, or emphasis.")
@app_commands.describe(
    name="NPC name.", field="Which feature list to modify.",
    entry="Name to add or remove.", remove="Remove instead of adding.",
    skill="Skill name (required for Emphasis only).",
)
@app_commands.choices(field=_FEATURE_FIELDS)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_feature(
    interaction: discord.Interaction, name: str,
    field: app_commands.Choice[str], entry: str,
    remove: bool = False, skill: str | None = None,
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    entry_name = entry.strip()
    if field.value == "_emphasis":
        if not skill:
            await interaction.response.send_message(
                "Emphasis requires the `skill:` parameter (e.g. skill: Kenjutsu).", ephemeral=True,
            )
            return
        skill_name = skill.strip()
        if remove:
            emph_list = c.emphases.get(skill_name, [])
            match = next((e for e in emph_list if e.lower() == entry_name.lower()), None)
            if match is None:
                await interaction.response.send_message(
                    f"**{c.name}** has no emphasis **{entry_name}** under {skill_name}.", ephemeral=True,
                )
                return
            emph_list.remove(match)
            if not emph_list:
                del c.emphases[skill_name]
            msg = f"Removed emphasis **{match}** ({skill_name}) from **{c.name}**."
        else:
            emph_list = c.emphases.setdefault(skill_name, [])
            if any(e.lower() == entry_name.lower() for e in emph_list):
                await interaction.response.send_message(
                    f"**{c.name}** already has emphasis **{entry_name}** under {skill_name}.", ephemeral=True,
                )
                return
            emph_list.append(entry_name)
            msg = f"Added emphasis **{entry_name}** ({skill_name}) to **{c.name}**."
    else:
        lst: list = getattr(c, field.value)
        if remove:
            match = next((x for x in lst if x.lower() == entry_name.lower()), None)
            if match is None:
                await interaction.response.send_message(
                    f"**{c.name}** doesn't have {field.name} **{entry_name}**.", ephemeral=True,
                )
                return
            lst.remove(match)
            msg = f"Removed {field.name} **{match}** from **{c.name}**."
        else:
            if any(x.lower() == entry_name.lower() for x in lst):
                await interaction.response.send_message(
                    f"**{c.name}** already has {field.name} **{entry_name}**.", ephemeral=True,
                )
                return
            lst.append(entry_name)
            msg = f"Added {field.name} **{entry_name}** to **{c.name}**."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

_ELEMENT_CHOICES = [
    app_commands.Choice(name=e, value=e)
    for e in ("Air", "Earth", "Fire", "Water", "Void", "(clear)")
]

@npc_edit_group.command(name="affinity", description="Set an NPC's affinity and/or deficiency element. [Fortune]")
@app_commands.describe(
    name="NPC name.",
    affinity_element="Affinity element (choose '(clear)' to remove).",
    deficiency_element="Deficiency element (choose '(clear)' to remove).",
)
@app_commands.choices(affinity_element=_ELEMENT_CHOICES, deficiency_element=_ELEMENT_CHOICES)
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_affinity(
    interaction: discord.Interaction, name: str,
    affinity_element: app_commands.Choice[str] | None = None,
    deficiency_element: app_commands.Choice[str] | None = None,
) -> None:
    rec, err = _resolve_npc(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    changes: list[str] = []
    if affinity_element is not None:
        c.affinity_element = "" if affinity_element.value == "(clear)" else affinity_element.value.lower()
        changes.append(f"Affinity: **{c.affinity_element or '(none)'}**")
    if deficiency_element is not None:
        c.deficiency_element = "" if deficiency_element.value == "(clear)" else deficiency_element.value.lower()
        changes.append(f"Deficiency: **{c.deficiency_element or '(none)'}**")
    if not changes:
        await interaction.response.send_message(
            "Provide at least one of `affinity_element:` or `deficiency_element:`.", ephemeral=True,
        )
        return
    store.save(rec)
    await interaction.response.send_message(
        f"🎭 **{c.name}** element affinity updated:\n" + "\n".join(changes),
        ephemeral=True,
    )

# ===========================================================================
# /room group: private-thread play rooms with invites
# ===========================================================================

def _room_host_or_dm(interaction: discord.Interaction, rec: storage.RoomRecord) -> bool:
    return str(interaction.user.id) == rec.host_id or _is_dm(interaction)

async def _resolve_current_room(
    interaction: discord.Interaction,
) -> tuple[storage.RoomRecord | None, str | None]:
    """Rooms context commands run INSIDE the room's thread."""
    rec = store.get_room_by_thread(str(interaction.channel_id))
    if rec is None:
        return None, "Run this inside a room's thread (open one with `/room create`)."
    return rec, None

@room_group.command(name="create", description="Create a private play room (a thread) and become its host.")
@app_commands.describe(name="Room name.", description="Optional location description (pinned at top of the room).")
async def room_create(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 90],
    description: app_commands.Range[str, 1, 4000] | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not isinstance(interaction.channel, discord.TextChannel):
        await interaction.response.send_message(
            "Create a room from a normal text channel (not inside a thread or DM).", ephemeral=True
        )
        return
    try:
        thread = await interaction.channel.create_thread(
            name=name, type=discord.ChannelType.private_thread, invitable=False
        )
        await thread.add_user(interaction.user)
    except discord.Forbidden:
        await interaction.response.send_message(
            "I need **Create Private Threads**, **Send Messages in Threads**, and **Manage Threads** "
            "permissions here. Ask a server admin to grant them (see README).",
            ephemeral=True,
        )
        return
    rec = store.create_room(
        str(interaction.guild_id), str(interaction.channel_id), str(thread.id), name, str(interaction.user.id),
        description=description or "",
    )
    await interaction.response.send_message(
        f"🏮 Room **{name}** created: {thread.mention} (host {interaction.user.mention}). "
        f"Invite people with `/room invite` inside the room."
    )
    await thread.send(
        f"🏮 Welcome to **{name}**. {interaction.user.mention} is the host. "
        f"Play happens here:`/sheet`, `/roll`, `/fight attack`, and `/combat` all work inside this room."
    )
    if description:
        embed = discord.Embed(title=name, description=description, color=0xC4A747)
        pin_msg = await thread.send(embed=embed)
        await pin_msg.pin()

@room_group.command(name="describe", description="Set or update the room's pinned description (run inside the room).")
@app_commands.describe(description="The new location description to pin.")
async def room_describe(
    interaction: discord.Interaction,
    description: app_commands.Range[str, 1, 4000],
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_current_room(interaction)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if not _room_host_or_dm(interaction, rec):
        await interaction.response.send_message("Only the room host or a DM can set the description.", ephemeral=True)
        return
    await interaction.response.send_message(f"📜 Updating description for **{rec.name}**...", ephemeral=True)
    # Unpin any existing description embeds from the bot
    try:
        pinned = await interaction.channel.pins()
        for msg in pinned:
            if msg.author == interaction.client.user and msg.embeds and msg.embeds[0].color and msg.embeds[0].color.value == 0xC4A747:
                await msg.unpin()
                await msg.delete()
    except discord.Forbidden:
        pass
    store.update_room_description(rec.id, description)
    embed = discord.Embed(title=rec.name, description=description, color=0xC4A747)
    pin_msg = await interaction.channel.send(embed=embed)
    await pin_msg.pin()

@room_group.command(name="invite", description="Invite a member into this room (run inside the room's thread).")
@app_commands.describe(member="Who to invite.")
async def room_invite(interaction: discord.Interaction, member: discord.Member) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_current_room(interaction)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if not _room_host_or_dm(interaction, rec):
        await interaction.response.send_message(
            "Only the room host or a DM can invite.", ephemeral=True
        )
        return
    try:
        await interaction.channel.add_user(member)
    except discord.Forbidden:
        await interaction.response.send_message("I can't add members to this thread.", ephemeral=True)
        return
    store.add_room_member(rec.id, str(member.id))
    await interaction.response.send_message(f"➕ {member.mention} joined **{rec.name}**.")

@room_group.command(name="kick", description="Remove a member from this room (run inside the room's thread).")
@app_commands.describe(member="Who to remove.")
async def room_kick(interaction: discord.Interaction, member: discord.Member) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_current_room(interaction)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if not _room_host_or_dm(interaction, rec):
        await interaction.response.send_message(
            "Only the room host or a DM can remove members.", ephemeral=True
        )
        return
    try:
        await interaction.channel.remove_user(member)
    except discord.Forbidden:
        await interaction.response.send_message("I can't remove members from this thread.", ephemeral=True)
        return
    store.remove_room_member(rec.id, str(member.id))
    await interaction.response.send_message(f"➖ Removed {member.mention} from **{rec.name}**.")

@room_group.command(name="members", description="List who's in this room (run inside the room's thread).")
async def room_members(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_current_room(interaction)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    ids = store.list_room_members(rec.id)
    mentions = ", ".join(f"<@{uid}>" for uid in ids) if ids else "none"
    npcs = store.list_room_npcs(rec.id)
    npc_line = "\n🎭 NPCs: " + ", ".join(f"**{n}**" for n in sorted(npcs)) if npcs else ""
    await interaction.response.send_message(
        f"🏮 **{rec.name}**: host <@{rec.host_id}>\nMembers: {mentions}{npc_line}",
        ephemeral=True,
    )

@room_group.command(name="list", description="List the open rooms on this server.")
async def room_list(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    rooms = store.list_rooms(str(interaction.guild_id))
    if not rooms:
        await interaction.response.send_message(
            "No open rooms. Create one with `/room create`.", ephemeral=True
        )
        return
    lines = []
    for r in rooms:
        n_members = len(store.list_room_members(r.id))
        n_npcs = len(store.list_room_npcs(r.id))
        npc_tag = f", {n_npcs} NPC{'s' if n_npcs != 1 else ''}" if n_npcs else ""
        lines.append(
            f"• <#{r.thread_id}>: **{r.name}** (host <@{r.host_id}>, "
            f"{n_members} member{'s' if n_members != 1 else ''}{npc_tag})"
        )
    await interaction.response.send_message("🏮 **Open rooms: **\n" + "\n".join(lines[:40]), ephemeral=True)

@room_group.command(name="close", description="Close this room (archives the thread). Host or Fortune.")
async def room_close(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_current_room(interaction)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if not _room_host_or_dm(interaction, rec):
        await interaction.response.send_message(
            "Only the room host or a DM can close it.", ephemeral=True
        )
        return
    store.clear_room_npcs(rec.id)
    store.close_room(rec.id)
    await interaction.response.send_message(f"🏮 Room **{rec.name}** closed. Archiving the thread.")
    try:
        await interaction.channel.edit(archived=True, locked=True)
    except discord.Forbidden:
        pass

# ===========================================================================
# /creature group: bestiary monsters and creature combat
# ===========================================================================

class CreatureAttackView(_DisableableView):
    """DM-only button: apply a creature's fixed damage to a character it hit."""

    KIND = "creature_attack"

    def __init__(self, creature_id: int, target_char_id: int, creature_name: str, target_name: str) -> None:
        super().__init__(timeout=1800)
        self.creature_id = creature_id
        self.target_char_id = target_char_id
        self.creature_name = creature_name
        self.target_name = target_name

    @discord.ui.button(label="Apply Creature Damage", style=discord.ButtonStyle.danger, emoji="👹")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        cre_rec = store.get_creature_by_id(self.creature_id)
        target_rec = store.get_by_id(self.target_char_id)
        if cre_rec is None:
            await interaction.response.send_message("The creature no longer exists.", ephemeral=True)
            return
        if target_rec is None:
            await interaction.response.send_message("The target no longer exists.", ephemeral=True)
            return
        dmg = creature.creature_damage(cre_rec.creature, engine)
        applied = combat.apply_damage(target_rec.character, dmg["raw"], target_rec.character.armor_reduction)
        store.save(target_rec, note="creature attack damage")
        c = target_rec.character
        _tally(interaction.channel_id, self.creature_name, "attacks"); _tally(interaction.channel_id, self.creature_name, "hits")
        _tally(interaction.channel_id, self.creature_name, "dealt", applied["final_damage"])
        _tally(interaction.channel_id, c.name, "taken", applied["final_damage"])
        if applied["is_dead"]:
            _tally(interaction.channel_id, self.creature_name, "kills")
        death_line = ""
        if applied["is_dead"]:
            notes = await _on_death(str(interaction.guild_id), c.name, target_rec.owner_id, target_rec.id)
            death_line = "".join(f"\n💀 {n}" for n in notes)
        embed = discord.Embed(
            title="👹 Creature damage applied",
            color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
        )
        embed.add_field(
            name="Damage",
            value=(
                f"{self.creature_name} → **{self.target_name}**\n{_format_dice(dmg['dice'])}\n"
                f"Raw **{dmg['raw']}** − reduction {applied['reduction']} = "
                f"**{applied['final_damage']}** wounds"
            ),
            inline=False,
        )
        if applied["level_changed"]:
            status = (
                f"{self.target_name}: {applied['old_wound_level']} → "
                f"**{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
            )
        else:
            status = f"{self.target_name}: **{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
        if applied["is_dead"]:
            status += "  💀 **DEAD**" + death_line
        embed.add_field(name="Result", value=status, inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(embed=embed)
        dead_tag = " DEAD" if applied["is_dead"] else ""
        await _combat_log(
            str(interaction.guild_id),
            f"Creature Damage: {self.creature_name} → {self.target_name} "
            f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
        )

    @discord.ui.button(label="No Damage", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def waive(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} ruled no damage from {self.creature_name}."
        )

class SpellDamageView(_DisableableView):
    """DM-approval gate for spell damage: shows the rolled damage and lets
    the DM approve, void-reduce, or deny before touching the target's sheet."""

    KIND = "spell_damage"

    def __init__(
        self,
        target_id: int,
        target_name: str,
        raw_damage: int,
        dice_text: str,
        reason: str,
        rolled: int,
        kept: int,
        bonus: int,
        source_channel_id: int = 0,
        caster_name: str = "",
    ) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.caster_name = caster_name
        self.raw_damage = raw_damage
        self.dice_text = dice_text
        self.reason = reason
        self.rolled = rolled
        self.kept = kept
        self.bonus = bonus
        self.source_channel_id = source_channel_id

    @discord.ui.button(label="Apply Damage", style=discord.ButtonStyle.danger, emoji="📜")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        await self._resolve(interaction, void_reduce=False)

    @discord.ui.button(label="Void Reduce (−10)", style=discord.ButtonStyle.primary, emoji="🔮")
    async def void_reduce(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        await self._resolve(interaction, void_reduce=True)

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        msg = (
            f"🛡️ {interaction.user.display_name} denied: "
            f"no spell damage applied to **{self.target_name}**."
        )
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(msg)
            await interaction.followup.send(f"Denied — posted in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(msg)

    async def _resolve(self, interaction: discord.Interaction, void_reduce: bool) -> None:
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        applied = combat.apply_damage(rec.character, self.raw_damage, rec.character.armor_reduction)
        void_line = ""
        if void_reduce:
            if applied["final_damage"] <= 0:
                void_line = "\n🔮 No damage to reduce (fully absorbed by armor)"
            else:
                ok, reason_block = advantage_effects.can_spend_void_on_roll(rec.character, is_wound_reduction=True)
                if not ok:
                    void_line = f"\n🔮 {reason_block}"
                elif rec.character.current_void_points > 0:
                    void_saved = min(10, applied["final_damage"])
                    rec.character.wounds_taken = max(0, rec.character.wounds_taken - void_saved)
                    rec.character.current_void_points -= 1
                    _tally(self.source_channel_id or interaction.channel_id, rec.character.name, "void")
                    applied["final_damage"] -= void_saved
                    applied["new_wound_level"] = stats.wound_level_name(rec.character)
                    applied["is_dead"] = stats.is_dead(rec.character)
                    applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
                    void_line = f"\n🔮 Void Point: **−{void_saved}** wounds ({rec.character.current_void_points} VP left)"
                else:
                    void_line = "\n🔮 No Void Points available: full damage applied"
        store.save(rec, note="spell damage")
        ch_for_tally = self.source_channel_id or interaction.channel_id
        _tally(ch_for_tally, rec.character.name, "taken", applied["final_damage"])
        if self.caster_name:
            _tally(ch_for_tally, self.caster_name, "dealt", applied["final_damage"])
            if applied["is_dead"]:
                _tally(ch_for_tally, self.caster_name, "kills")
        c = rec.character
        death_line = ""
        if applied["is_dead"]:
            notes = await _on_death(str(interaction.guild_id), c.name, rec.owner_id, rec.id)
            death_line = "".join(f"\n💀 {n}" for n in notes)
        embed = discord.Embed(
            title=f"📜 {self.reason or 'Spell Damage'}: applied",
            color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.dark_magenta(),
        )
        embed.add_field(
            name="Damage",
            value=(
                f"→ **{self.target_name}**\n"
                f"Raw **{self.raw_damage}** − reduction {applied['reduction']} = "
                f"**{applied['final_damage']}** wounds{void_line}"
            ),
            inline=False,
        )
        if applied["level_changed"]:
            status = (
                f"{self.target_name}: {applied['old_wound_level']} → "
                f"**{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
            )
        else:
            status = f"{self.target_name}: **{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
        if applied["is_dead"]:
            status += "  💀 **DEAD**" + death_line
        embed.add_field(name="Result", value=status, inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(embed=embed)
            await interaction.followup.send(f"Resolved in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(embed=embed)
        dead_tag = " DEAD" if applied["is_dead"] else ""
        reason_tag = f" ({self.reason})" if self.reason else ""
        await _combat_log(
            str(interaction.guild_id),
            f"Spell Damage: {self.target_name}{reason_tag} "
            f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
        )

class DmDamageView(_DisableableView):
    """DM-approval gate for /dm damage: shows pending damage and lets a DM
    confirm or deny before applying to the target's sheet."""

    KIND = "dm_damage"

    def __init__(self, target_id: int, target_name: str, amount: int, reason: str,
                 source_channel_id: int = 0, void_reduced: bool = False) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.amount = amount
        self.reason = reason
        self.void_reduced = void_reduced
        self.source_channel_id = source_channel_id

    @discord.ui.button(label="Apply Damage", style=discord.ButtonStyle.danger, emoji="💥")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        applied = combat.apply_damage(rec.character, self.amount, rec.character.armor_reduction)
        store.save(rec, note="DM damage")
        _tally(self.source_channel_id or interaction.channel_id, rec.character.name, "taken", applied["final_damage"])
        c = rec.character
        death_line = ""
        if applied["is_dead"]:
            notes = await _on_death(str(interaction.guild_id), c.name, rec.owner_id, rec.id)
            death_line = "".join(f"\n💀 {n}" for n in notes)
        embed = discord.Embed(
            title="💥 Damage applied",
            color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
        )
        embed.add_field(
            name="Damage",
            value=(
                f"→ **{self.target_name}**"
                f"{f' ({self.reason})' if self.reason else ''}\n"
                f"Raw **{self.amount}** − reduction {applied['reduction']} = "
                f"**{applied['final_damage']}** wounds"
            ),
            inline=False,
        )
        if applied["level_changed"]:
            status = (
                f"{self.target_name}: {applied['old_wound_level']} → "
                f"**{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
            )
        else:
            status = f"{self.target_name}: **{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
        if applied["is_dead"]:
            status += "  💀 **DEAD**" + death_line
        embed.add_field(name="Result", value=status, inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(embed=embed)
            await interaction.followup.send(f"Resolved in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(embed=embed)
        dead_tag = " DEAD" if applied["is_dead"] else ""
        reason_tag = f" ({self.reason})" if self.reason else ""
        await _combat_log(
            str(interaction.guild_id),
            f"DM Damage: {self.target_name}{reason_tag} "
            f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
        )

    @discord.ui.button(label="Void Reduce (−10)", style=discord.ButtonStyle.primary, emoji="🔮")
    async def void_reduce(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if self.void_reduced:
            await interaction.response.send_message("Already Void-reduced once.", ephemeral=True)
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        c = rec.character
        ok, reason_block = advantage_effects.can_spend_void_on_roll(c, is_wound_reduction=True)
        if not ok:
            await interaction.response.send_message(f"🔮 {reason_block}", ephemeral=True)
            return
        if c.current_void_points <= 0:
            await interaction.response.send_message(
                f"**{c.name}** has no Void Points remaining.", ephemeral=True
            )
            return
        c.current_void_points -= 1
        _tally(self.source_channel_id or interaction.channel_id, c.name, "void")
        self.amount = max(0, self.amount - 10)
        self.void_reduced = True
        store.save(rec, note="Void Point spent (damage reduction)")
        # Re-persist so the reduction survives a restart before Apply/Deny.
        self._persist_args.update(amount=self.amount, void_reduced=True)
        await self.persist(interaction.message)
        await interaction.response.send_message(
            f"🔮 **{self.target_name}** spends 1 VP → damage reduced to **{self.amount}**. "
            f"({c.current_void_points}/{c.max_void_points} VP left). "
            f"DM: now click Apply Damage or Deny."
        )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        if self.void_reduced:
            rec = store.get_by_id(self.target_id)
            if rec is not None:
                rec.character.current_void_points += 1
                store.save(rec, note="Void Point refunded (damage denied)")
        msg = (
            f"🛡️ {interaction.user.display_name} denied: "
            f"no damage applied to **{self.target_name}**."
        )
        if self.void_reduced:
            msg += " 🔮 Void Point refunded."
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(msg)
            await interaction.followup.send(f"Denied — posted in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(msg)

class DmHealView(_DisableableView):
    """DM-approval gate for /dm heal: shows pending healing and lets a DM
    confirm or deny before modifying the target's wound track."""

    KIND = "dm_heal"

    def __init__(self, target_id: int, target_name: str, amount: int, reason: str,
                 source_channel_id: int = 0) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.amount = amount
        self.reason = reason
        self.source_channel_id = source_channel_id

    @discord.ui.button(label="Apply Healing", style=discord.ButtonStyle.success, emoji="💚")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        c = rec.character
        if stats.is_dead(c):
            self._disable()
            await interaction.response.edit_message(view=self)
            await interaction.followup.send(f"**{c.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        old_wounds = c.wounds_taken
        old_level = stats.wound_level_name(c)
        c.wounds_taken = max(0, c.wounds_taken - self.amount)
        healed = old_wounds - c.wounds_taken
        new_level = stats.wound_level_name(c)
        store.save(rec, note="DM heal")
        _tally(self.source_channel_id or interaction.channel_id, c.name, "healed", healed)
        embed = discord.Embed(
            title="💚 Healing applied",
            color=discord.Color.green(),
        )
        embed.add_field(
            name="Healing",
            value=(
                f"→ **{self.target_name}**"
                f"{f' ({self.reason})' if self.reason else ''}\n"
                f"**{healed}** wounds healed ({c.wounds_taken} remaining)"
            ),
            inline=False,
        )
        if old_level != new_level:
            status = f"{self.target_name}: {old_level} → **{new_level}**"
        else:
            status = f"{self.target_name}: **{new_level}** ({c.wounds_taken} wounds)"
        embed.add_field(name="Result", value=status, inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(embed=embed)
            await interaction.followup.send(f"Resolved in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(embed=embed)
        reason_tag = f" ({self.reason})" if self.reason else ""
        await _combat_log(
            str(interaction.guild_id),
            f"Heal: {self.target_name}{reason_tag} {healed} wounds healed [{new_level}]",
        )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="❌")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        msg = (
            f"❌ {interaction.user.display_name} denied: "
            f"no healing applied to **{self.target_name}**."
        )
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(msg)
            await interaction.followup.send(f"Denied — posted in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(msg)

def _resolve_creature(
    interaction: discord.Interaction, name: str, require_dm: bool = True
) -> tuple[storage.CreatureRecord | None, str | None]:
    if interaction.guild_id is None:
        return None, "Please use this in a server channel."
    if require_dm and not _is_dm(interaction):
        return None, f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to do that with creatures."
    rec = store.get_creature_by_name(str(interaction.guild_id), name)
    if rec is None:
        return None, f"No creature named **{name}**."
    return rec, None

@creature_group.command(name="catalog", description="Search the bestiary templates you can spawn.")
@app_commands.describe(search="Filter by name, id, or tag (e.g. 'oni', 'goblin', 'wolf'). Omit for a summary.")
async def creature_catalog(interaction: discord.Interaction, search: str | None = None) -> None:
    items = sorted(creature.CREATURE_CATALOG.items(), key=lambda kv: kv[1].name)
    total = len(items)
    if not search:
        # No filter: show a category summary (the full list is too long to dump).
        cats = {}
        for _, t in items:
            key = next((tag for tag in ("animal", "oni", "undead", "spirit", "shadowlands") if tag in t.tags), "other")
            cats[key] = cats.get(key, 0) + 1
        summary = " · ".join(f"{k} {v}" for k, v in sorted(cats.items()))
        await interaction.response.send_message(
            f"👹 **{total} creature templates.** Use `/creature catalog search:<term>` to filter "
            f"(by name, id, or tag).\nCategories: {summary}",
            ephemeral=True,
        )
        return
    cur = search.lower().strip()
    matches = [
        (tid, t) for tid, t in items
        if cur in tid or cur in t.name.lower() or any(cur in tag for tag in t.tags)
    ]
    if not matches:
        await interaction.response.send_message(f"No templates match `{search}`.", ephemeral=True)
        return
    lines = [
        f"• `{tid}`: **{t.name}** (atk {t.attack_rolled}k{t.attack_kept}, dmg "
        f"{t.damage_rolled}k{t.damage_kept}, TN {t.armor_tn}, red {t.reduction}, dead {t.wounds_dead})"
        for tid, t in matches
    ]
    pages = _paginate(lines, f"👹 **{len(matches)} match(es) for `{search}`: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)

@creature_group.command(name="search", description="Search bestiary templates with detailed output. [Fortune]")
@app_commands.describe(query="Search by name, id, or tag (e.g. 'oni', 'bear', 'spirit').")
async def creature_search(interaction: discord.Interaction, query: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    q = query.lower().strip()
    if len(q) < 2:
        await interaction.response.send_message("Search term must be at least 2 characters.", ephemeral=True)
        return
    items = sorted(creature.CREATURE_CATALOG.items(), key=lambda kv: kv[1].name)
    matches = [
        (tid, t) for tid, t in items
        if q in tid or q in t.name.lower() or any(q in tag for tag in t.tags)
    ]
    if not matches:
        await interaction.response.send_message(f"No templates match `{query}`.", ephemeral=True)
        return
    lines: list[str] = []
    for tid, t in matches:
        ring_parts: list[str] = []
        for rn, (ta, tb) in _RING_TRAITS.items():
            rv = getattr(t, rn)
            ov = []
            if ta in t.traits:
                ov.append(f"{_TRAIT_ABBREV[ta]} {t.traits[ta]}")
            if tb in t.traits:
                ov.append(f"{_TRAIT_ABBREV[tb]} {t.traits[tb]}")
            lbl = rn.capitalize()[:1]
            ring_parts.append(f"{lbl} {rv} ({', '.join(ov)})" if ov else f"{lbl} {rv}")
        atk = f"{t.attack_rolled}k{t.attack_kept}"
        if t.attack_flat:
            atk += f"+{t.attack_flat}"
        dmg = f"{t.damage_rolled}k{t.damage_kept}"
        if t.damage_flat:
            dmg += f"+{t.damage_flat}"
        fear_s = f" | Fear {t.fear}" if t.fear else ""
        tags_s = ", ".join(t.tags[:6])
        if len(t.tags) > 6:
            tags_s += f" +{len(t.tags) - 6}"
        lines.append(
            f"• **{t.name}** (`{tid}`)\n"
            f"  {' · '.join(ring_parts)}\n"
            f"  {t.attack_name or 'Atk'}: atk {atk}, dmg {dmg} | TN {t.armor_tn}, Red {t.reduction} | "
            f"Dead {t.wounds_dead}{fear_s}\n"
            f"  {tags_s}"
        )
    pages = _paginate(lines, f"\U0001f479 **{len(matches)} match(es) for `{query}`: **\n", per_page=5)
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)

@creature_group.command(name="info", description="View the full stat block of a bestiary template (without spawning). [Fortune]")
@app_commands.describe(template="Which creature template to look up.")
@app_commands.autocomplete(template=_creature_template_autocomplete)
async def creature_info(interaction: discord.Interaction, template: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    tmpl = creature.CREATURE_CATALOG.get(template)
    if tmpl is None:
        await interaction.response.send_message(
            f"Unknown template `{template}`. Use `/creature catalog` to search.", ephemeral=True,
        )
        return
    await interaction.response.send_message(embed=_build_creature_template_embed(tmpl), ephemeral=True)

@creature_group.command(name="compare", description="Compare two bestiary templates side-by-side. [Fortune]")
@app_commands.describe(template_a="First creature template.", template_b="Second creature template.")
@app_commands.autocomplete(template_a=_creature_template_autocomplete, template_b=_creature_template_autocomplete)
async def creature_compare(interaction: discord.Interaction, template_a: str, template_b: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    a = creature.CREATURE_CATALOG.get(template_a)
    b = creature.CREATURE_CATALOG.get(template_b)
    if a is None:
        await interaction.response.send_message(f"Unknown template `{template_a}`.", ephemeral=True)
        return
    if b is None:
        await interaction.response.send_message(f"Unknown template `{template_b}`.", ephemeral=True)
        return
    embed = discord.Embed(
        title=f"\U0001f479 {a.name}  vs  {b.name}",
        color=discord.Color.dark_purple(),
    )
    embed.add_field(name=f"⚔️ {a.name}", value=_creature_compact_summary(a), inline=False)
    embed.add_field(name=f"⚔️ {b.name}", value=_creature_compact_summary(b), inline=False)
    embed.set_footer(text=f"{template_a}  vs  {template_b}")
    await interaction.response.send_message(embed=embed, ephemeral=True)

@creature_group.command(name="spawn", description="Spawn a creature instance from a template. [Fortune]")
@app_commands.describe(template="Which creature template.", name="Instance name (default: the template's name).")
@app_commands.autocomplete(template=_creature_template_autocomplete)
async def creature_spawn(interaction: discord.Interaction, template: str, name: str | None = None) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    tmpl = creature.CREATURE_CATALOG.get(template)
    if tmpl is None:
        await interaction.response.send_message(
            f"Unknown template `{template}`. See `/creature catalog`.", ephemeral=True
        )
        return
    inst_name = name or tmpl.name
    cr = creature.spawn(template, inst_name)
    try:
        rec = store.create_creature(str(interaction.guild_id), cr)
    except storage.DuplicateNameError:
        await interaction.response.send_message(
            f"A creature named **{inst_name}** already exists. Give this one a distinct `name:`.",
            ephemeral=True,
        )
        return
    await interaction.response.send_message(
        content=f"👹 Spawned **{inst_name}**.", embed=build_creature_embed(rec)
    )

@creature_group.command(name="list", description="List spawned creatures on this server.")
async def creature_list(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    recs = store.list_creatures(str(interaction.guild_id))
    if not recs:
        await interaction.response.send_message(
            "No creatures spawned. Use `/creature spawn` (Fortune).", ephemeral=True
        )
        return
    lines = [
        f"• **{r.creature.name}**: {creature.creature_wound_level(r.creature)} "
        f"({r.creature.wounds_taken}/{r.creature.wounds_dead})"
        for r in recs
    ]
    pages = _paginate(lines, "👹 **Creatures: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0])
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view)

@creature_group.command(name="view", description="View a spawned creature.")
@app_commands.describe(name="The creature to view.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_view(interaction: discord.Interaction, name: str) -> None:
    rec, err = _resolve_creature(interaction, name, require_dm=False)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    await interaction.response.send_message(embed=build_creature_embed(rec))

@creature_group.command(name="delete", description="Remove a spawned creature. [Fortune]")
@app_commands.describe(name="The creature to remove.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_delete(interaction: discord.Interaction, name: str) -> None:
    rec, err = _resolve_creature(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    store.delete_creature(rec.id)
    await interaction.response.send_message(f"Removed creature **{rec.creature.name}**.", ephemeral=True)

@creature_group.command(name="wound", description="Apply wounds to a creature directly (no reduction). [Fortune]")
@app_commands.describe(name="The creature.", amount="Wounds to apply.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_wound(
    interaction: discord.Interaction, name: str, amount: app_commands.Range[int, 1, 1000]
) -> None:
    rec, err = _resolve_creature(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    applied = creature.apply_damage_to_creature(rec.creature, amount, reduction=0)
    store.save_creature(rec, note="wound")
    dead = ""
    if applied["is_dead"]:
        notes = await _on_death(str(interaction.guild_id), rec.creature.name, None, None)
        dead = "  💀 **SLAIN**" + "".join(f"\n💀 {n}" for n in notes)
    crossed = f"  ({applied['old_wound_level']} → **{applied['new_wound_level']}**)" if applied["level_changed"] else ""
    await interaction.response.send_message(
        f"**{rec.creature.name}** takes **{amount}** → {rec.creature.wounds_taken}/{rec.creature.wounds_dead}{crossed}{dead}",
        embed=build_creature_embed(rec),
    )

@creature_group.command(name="heal", description="Heal a creature's wounds. [Fortune]")
@app_commands.describe(name="The creature.", amount="Wounds to heal.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_heal(
    interaction: discord.Interaction, name: str, amount: app_commands.Range[int, 1, 1000]
) -> None:
    rec, err = _resolve_creature(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.creature.wounds_taken = max(0, rec.creature.wounds_taken - amount)
    store.save_creature(rec, note="heal")
    await interaction.response.send_message(
        f"**{rec.creature.name}** healed **{amount}** → {rec.creature.wounds_taken}/{rec.creature.wounds_dead}",
        embed=build_creature_embed(rec),
    )

@creature_group.command(name="attack", description="A creature attacks a player/NPC (fixed stat block). [Fortune]")
@app_commands.describe(
    creature_name="The attacking creature.",
    target="The player to attack (their active character).",
    target_npc="Attack a stored NPC instead of a player.",
    raises="Called Raises: each adds +5 to the target's Armor TN.",
    bonus_tn="Situational +/- to the target's Armor TN.",
)
@app_commands.autocomplete(creature_name=_creature_instance_autocomplete, target_npc=_npc_autocomplete)
async def creature_attack_cmd(
    interaction: discord.Interaction,
    creature_name: str,
    target: discord.Member | None = None,
    target_npc: str | None = None,
    raises: app_commands.Range[int, 0, 10] = 0,
    bonus_tn: app_commands.Range[int, -50, 50] = 0,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    cre_rec = store.get_creature_by_name(guild, creature_name)
    if cre_rec is None:
        await interaction.response.send_message(f"No creature named **{creature_name}**.", ephemeral=True)
        return
    if target_npc:
        target_rec = store.get_by_name(guild, NPC_OWNER, target_npc)
        if target_rec is None:
            await interaction.response.send_message(f"No NPC named **{target_npc}**.", ephemeral=True)
            return
    elif target is not None:
        target_rec = store.get_active(guild, str(target.id))
        if target_rec is None:
            await interaction.response.send_message(
                f"{target.display_name} has no active character.", ephemeral=True
            )
            return
    else:
        await interaction.response.send_message(
            "Pick a target: `target:` (player) or `target_npc:`.", ephemeral=True
        )
        return

    cr = cre_rec.creature
    if creature.creature_is_dead(cr):
        await interaction.response.send_message(f"💀 **{cr.name}** has been slain.", ephemeral=True)
        return
    if await _refuse_if_dead(interaction, target_rec.character):
        return
    enc = encounters.get(interaction.channel_id)
    tgt = target_rec.character
    def_cb = enc.find(tgt.name) if enc else None
    # Same defender Armor TN assembly as /fight attack: live stance, Full
    # Defense, Void armor, Guard, cover and conditions from the encounter.
    tn_notes: list[str] = []
    d_stance = def_cb.stance if def_cb else "attack"
    tn_mod = bonus_tn
    if def_cb:
        if def_cb.full_defense_bonus:
            tn_mod += def_cb.full_defense_bonus
            tn_notes.append(f"Full Defense +{def_cb.full_defense_bonus}")
        if def_cb.void_armor_tn_bonus:
            tn_mod += def_cb.void_armor_tn_bonus
            tn_notes.append(f"Void Armor +{def_cb.void_armor_tn_bonus}")
        if def_cb.cover_bonus:
            tn_mod += def_cb.cover_bonus
            tn_notes.append(f"Cover {def_cb.cover_bonus:+d}")
        for gc in enc.combatants:
            if gc.guarding.lower() == tgt.name.lower():
                tn_mod += 10
                tn_notes.append(f"Guarded by {gc.name} +10")
        if def_cb.guarding:
            tn_mod -= 5
            tn_notes.append(f"Guarding {def_cb.guarding} −5")
    def_conds = def_cb.conditions if def_cb else set()
    cond_def_mod, cond_def_notes = condition_effects.defender_armor_tn_mod(def_conds, True)
    tn_notes.extend(cond_def_notes)
    cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
        def_conds, tgt.reflexes, tgt.armor_tn_bonus, True,
    )
    if cond_tn_ovr is not None:
        tn = cond_tn_ovr + cond_def_mod + tn_mod
        tn_notes.extend(cond_tn_notes)
    else:
        tn = combat.armor_tn(tgt, d_stance, tn_mod + cond_def_mod)
        if d_stance != "attack":
            tn_notes.append(f"{d_stance.replace('_', ' ').title()} stance")
    outcome = creature.creature_attack(cr, tn, engine, raises)
    hit = outcome["success"]
    t_name = target_rec.character.name
    embed = discord.Embed(
        title=f"👹 {cr.name} attacks {t_name}",
        color=discord.Color.green() if hit else discord.Color.greyple(),
    )
    embed.add_field(
        name="Attack", value=f"{cr.attack_name} **{cr.attack_rolled}k{cr.attack_kept}**", inline=False
    )
    embed.add_field(name="Attack roll", value=_format_dice(outcome["dice"]), inline=False)
    verdict = "✅ **HIT**" if hit else "❌ **MISS**"
    embed.add_field(
        name="Result",
        value=f"Total **{outcome['total']}** vs Armor TN **{outcome['tn']}**: {verdict} "
        f"(margin {outcome['margin']:+d})",
        inline=False,
    )
    if tn_notes:
        embed.add_field(name="Defender Armor TN modifiers", value=" · ".join(tn_notes)[:1024], inline=False)
    if hit:
        view = CreatureAttackView(cre_rec.id, target_rec.id, cr.name, t_name)
        await interaction.response.send_message(
            content=f"{_dm_ping(interaction.guild)}A DM can apply the creature's damage below.",
            embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
        )
        await view.persist(await interaction.original_response())
        await _combat_log(guild, f"Creature Attack: {cr.name} → {t_name} HIT (roll {outcome['total']} vs TN {outcome['tn']})")
    else:
        await interaction.response.send_message(embed=embed)
        await _combat_log(guild, f"Creature Attack: {cr.name} → {t_name} MISS (roll {outcome['total']} vs TN {outcome['tn']})")

# ===========================================================================
# /category — organise NPCs & creatures into named groups
# ===========================================================================
_ENTITY_TYPE_CHOICES = [
    app_commands.Choice(name="NPC", value="npc"),
    app_commands.Choice(name="Creature", value="creature"),
]

async def _category_autocomplete(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    cats = store.list_categories(str(interaction.guild_id))
    cur = current.lower().strip()
    return [
        app_commands.Choice(name=c.name, value=c.name)
        for c in cats if cur in c.name.lower()
    ][:25]

@category_group.command(name="create", description="Create a new category. [Fortune]")
@app_commands.describe(name="Category name (e.g. 'Bandits', 'Town Guards', 'Wildlife').")
async def category_create(interaction: discord.Interaction, name: app_commands.Range[str, 1, 64]) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    try:
        cat = store.create_category(str(interaction.guild_id), name.strip())
    except storage.DuplicateNameError:
        await interaction.response.send_message(f"Category **{name}** already exists.", ephemeral=True)
        return
    await interaction.response.send_message(f"\U0001f4c1 Created category **{cat.name}**.")

@category_group.command(name="delete", description="Delete a category (members are NOT deleted). [Fortune]")
@app_commands.describe(name="Category to delete.")
@app_commands.autocomplete(name=_category_autocomplete)
async def category_delete(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    cat = store.get_category(str(interaction.guild_id), name)
    if cat is None:
        await interaction.response.send_message(f"No category named **{name}**.", ephemeral=True)
        return
    store.delete_category(cat.id)
    await interaction.response.send_message(f"\U0001f4c1 Deleted category **{cat.name}**.", ephemeral=True)

@category_group.command(name="rename", description="Rename a category. [Fortune]")
@app_commands.describe(name="Current category name.", new_name="New name.")
@app_commands.autocomplete(name=_category_autocomplete)
async def category_rename(
    interaction: discord.Interaction, name: str, new_name: app_commands.Range[str, 1, 64],
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    cat = store.get_category(str(interaction.guild_id), name)
    if cat is None:
        await interaction.response.send_message(f"No category named **{name}**.", ephemeral=True)
        return
    try:
        store.rename_category(cat.id, new_name.strip())
    except storage.DuplicateNameError:
        await interaction.response.send_message(f"Category **{new_name}** already exists.", ephemeral=True)
        return
    await interaction.response.send_message(f"\U0001f4c1 Renamed **{cat.name}** → **{new_name.strip()}**.")

@category_group.command(name="add", description="Add an NPC or creature to a category. [Fortune]")
@app_commands.describe(
    category="Which category.", kind="NPC or creature.", name="Name of the NPC or creature.",
)
@app_commands.choices(kind=_ENTITY_TYPE_CHOICES)
@app_commands.autocomplete(category=_category_autocomplete)
async def category_add(
    interaction: discord.Interaction,
    category: str,
    kind: app_commands.Choice[str],
    name: app_commands.Range[str, 1, 64],
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    cat = store.get_category(guild, category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    if kind.value == "npc":
        if store.get_by_name(guild, NPC_OWNER, name) is None:
            await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
            return
    else:
        if store.get_creature_by_name(guild, name) is None:
            await interaction.response.send_message(f"No creature named **{name}**.", ephemeral=True)
            return
    added = store.add_to_category(cat.id, kind.value, name.strip())
    if not added:
        await interaction.response.send_message(
            f"**{name}** is already in **{cat.name}**.", ephemeral=True,
        )
        return
    await interaction.response.send_message(
        f"\U0001f4c1 Added {kind.name} **{name}** to **{cat.name}**.",
    )

@category_group.command(name="remove", description="Remove an NPC or creature from a category. [Fortune]")
@app_commands.describe(
    category="Which category.", kind="NPC or creature.", name="Name to remove.",
)
@app_commands.choices(kind=_ENTITY_TYPE_CHOICES)
@app_commands.autocomplete(category=_category_autocomplete)
async def category_remove(
    interaction: discord.Interaction,
    category: str,
    kind: app_commands.Choice[str],
    name: app_commands.Range[str, 1, 64],
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    cat = store.get_category(str(interaction.guild_id), category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    removed = store.remove_from_category(cat.id, kind.value, name.strip())
    if not removed:
        await interaction.response.send_message(f"**{name}** is not in **{cat.name}**.", ephemeral=True)
        return
    await interaction.response.send_message(
        f"\U0001f4c1 Removed {kind.name} **{name}** from **{cat.name}**.", ephemeral=True,
    )

@category_group.command(name="list", description="List all categories on this server.")
async def category_list(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    cats = store.list_categories(str(interaction.guild_id))
    if not cats:
        await interaction.response.send_message(
            "No categories yet. Use `/category create` to make one.", ephemeral=True,
        )
        return
    lines = [f"• **{c.name}** ({store.category_count(c.id)} members)" for c in cats]
    pages = _paginate(lines, "\U0001f4c1 **Categories: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)

@category_group.command(name="view", description="View all members of a category.")
@app_commands.describe(category="Which category to view.")
@app_commands.autocomplete(category=_category_autocomplete)
async def category_view(interaction: discord.Interaction, category: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    cat = store.get_category(str(interaction.guild_id), category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    members = store.list_category_members(cat.id)
    if not members:
        await interaction.response.send_message(
            f"\U0001f4c1 **{cat.name}** is empty. Use `/category add` to populate it.",
            ephemeral=True,
        )
        return
    lines = [f"• `{etype:8s}` **{ename}**" for etype, ename in members]
    pages = _paginate(lines, f"\U0001f4c1 **{cat.name}** ({len(members)} members):\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)

@category_group.command(name="bulk_add", description="Add multiple NPCs or creatures to a category at once. [Fortune]")
@app_commands.describe(
    category="Which category.",
    kind="NPC or creature.",
    names="Comma-separated list of names to add.",
)
@app_commands.choices(kind=_ENTITY_TYPE_CHOICES)
@app_commands.autocomplete(category=_category_autocomplete)
async def category_bulk_add(
    interaction: discord.Interaction,
    category: str,
    kind: app_commands.Choice[str],
    names: str,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    cat = store.get_category(guild, category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    parsed = [n.strip() for n in names.split(",") if n.strip()]
    if not parsed:
        await interaction.response.send_message("Provide at least one name (comma-separated).", ephemeral=True)
        return
    added: list[str] = []
    skipped: list[str] = []
    not_found: list[str] = []
    for n in parsed:
        if kind.value == "npc":
            if store.get_by_name(guild, NPC_OWNER, n) is None:
                not_found.append(n)
                continue
        else:
            if store.get_creature_by_name(guild, n) is None:
                not_found.append(n)
                continue
        if store.add_to_category(cat.id, kind.value, n):
            added.append(n)
        else:
            skipped.append(n)
    parts: list[str] = []
    if added:
        parts.append(f"Added: **{', '.join(added)}**")
    if skipped:
        parts.append(f"Already in category: {', '.join(skipped)}")
    if not_found:
        parts.append(f"Not found: {', '.join(not_found)}")
    await interaction.response.send_message(
        f"\U0001f4c1 **{cat.name}** — {kind.name} bulk add\n" + "\n".join(parts),
        ephemeral=True,
    )

@category_group.command(name="bulk_remove", description="Remove multiple NPCs or creatures from a category at once. [Fortune]")
@app_commands.describe(
    category="Which category.",
    kind="NPC or creature.",
    names="Comma-separated list of names to remove.",
)
@app_commands.choices(kind=_ENTITY_TYPE_CHOICES)
@app_commands.autocomplete(category=_category_autocomplete)
async def category_bulk_remove(
    interaction: discord.Interaction,
    category: str,
    kind: app_commands.Choice[str],
    names: str,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    cat = store.get_category(str(interaction.guild_id), category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    parsed = [n.strip() for n in names.split(",") if n.strip()]
    if not parsed:
        await interaction.response.send_message("Provide at least one name (comma-separated).", ephemeral=True)
        return
    removed: list[str] = []
    not_in: list[str] = []
    for n in parsed:
        if store.remove_from_category(cat.id, kind.value, n):
            removed.append(n)
        else:
            not_in.append(n)
    parts: list[str] = []
    if removed:
        parts.append(f"Removed: **{', '.join(removed)}**")
    if not_in:
        parts.append(f"Not in category: {', '.join(not_in)}")
    await interaction.response.send_message(
        f"\U0001f4c1 **{cat.name}** — {kind.name} bulk remove\n" + "\n".join(parts),
        ephemeral=True,
    )

@category_group.command(name="spawn", description="Spawn all creature templates in a category as instances. [Fortune]")
@app_commands.describe(category="Which category to spawn creatures from.")
@app_commands.autocomplete(category=_category_autocomplete)
async def category_spawn(interaction: discord.Interaction, category: str) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    cat = store.get_category(guild, category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    members = store.list_category_members(cat.id)
    creatures_in_cat = [(etype, ename) for etype, ename in members if etype == "creature"]
    if not creatures_in_cat:
        await interaction.response.send_message(
            f"**{cat.name}** has no creature members to spawn.", ephemeral=True,
        )
        return
    spawned: list[str] = []
    already_exist: list[str] = []
    not_found: list[str] = []
    for _, ename in creatures_in_cat:
        tmpl = creature.CREATURE_CATALOG.get(ename)
        if tmpl is None:
            existing = store.get_creature_by_name(guild, ename)
            if existing is not None:
                tmpl = creature.CREATURE_CATALOG.get(existing.creature.template_id)
        if tmpl is None:
            not_found.append(ename)
            continue
        cr = creature.spawn(tmpl.template_id, ename)
        try:
            store.create_creature(guild, cr)
            spawned.append(ename)
        except storage.DuplicateNameError:
            already_exist.append(ename)
    parts: list[str] = []
    if spawned:
        parts.append(f"Spawned: **{', '.join(spawned)}**")
    if already_exist:
        parts.append(f"Already spawned: {', '.join(already_exist)}")
    if not_found:
        parts.append(f"Template not found: {', '.join(not_found)}")
    await interaction.response.send_message(
        f"👹 Category **{cat.name}** — spawn\n" + "\n".join(parts),
    )

# ===========================================================================
# /location group: IC areas (Discord categories) and locations (text channels)
# ===========================================================================

async def _location_area_autocomplete(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    areas = store.list_location_areas(str(interaction.guild_id))
    cur = current.lower()
    return [
        app_commands.Choice(name=a.name, value=a.name)
        for a in areas if cur in a.name.lower()
    ][:25]


@location_area_group.command(name="create", description="Create a new location area (Discord category). [Fortune]")
@app_commands.describe(
    name="Area name (becomes the Discord category name).",
    description="Description of the area (posted in a read-only #description channel).",
    role="Restrict visibility to this role (plus Staff). Omit for all Approved players.",
    member1="Grant access to this specific member.",
    member2="Grant access to a second member.",
    member3="Grant access to a third member.",
    member4="Grant access to a fourth member.",
    member5="Grant access to a fifth member.",
)
async def location_area_create(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 90],
    description: app_commands.Range[str, 1, 4000] | None = None,
    role: discord.Role | None = None,
    member1: discord.Member | None = None,
    member2: discord.Member | None = None,
    member3: discord.Member | None = None,
    member4: discord.Member | None = None,
    member5: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = interaction.guild
    guild_id = str(guild.id)
    clean_name = name.strip()
    if store.get_location_area(guild_id, clean_name):
        await interaction.response.send_message(f"Area **{clean_name}** already exists.", ephemeral=True)
        return
    everyone = guild.default_role
    bot_member = guild.me
    approved_role = discord.utils.get(guild.roles, name=ROLE_APPROVED)
    fortune_role = discord.utils.get(guild.roles, name=ROLE_FORTUNE)
    kami_role = discord.utils.get(guild.roles, name=ROLE_KAMI)
    overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True, manage_threads=True,
        ),
    }
    if role:
        overwrites[role] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        )
    elif approved_role:
        overwrites[approved_role] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        )
    for r in (fortune_role, kami_role):
        if r:
            overwrites[r] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
                manage_messages=True,
            )
    extra_members = [m for m in (member1, member2, member3, member4, member5) if m]
    for m in extra_members:
        overwrites[m] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        )
    try:
        category = await guild.create_category(clean_name, overwrites=overwrites, reason=f"Location area by {interaction.user}")
    except discord.Forbidden:
        await interaction.response.send_message(
            "I need **Manage Channels** permission to create categories.", ephemeral=True,
        )
        return

    if description:
        desc_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(view_channel=False, send_messages=False),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_messages=True,
            ),
        }
        if role:
            desc_overwrites[role] = discord.PermissionOverwrite(
                view_channel=True, send_messages=False, read_message_history=True,
            )
        elif approved_role:
            desc_overwrites[approved_role] = discord.PermissionOverwrite(
                view_channel=True, send_messages=False, read_message_history=True,
            )
        for r in (fortune_role, kami_role):
            if r:
                desc_overwrites[r] = discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, read_message_history=True,
                    manage_messages=True,
                )
        desc_ch = await category.create_text_channel("description", overwrites=desc_overwrites)
        embed = discord.Embed(
            title=clean_name, color=0xC4A747, description=description,
        )
        msg = await desc_ch.send(embed=embed)
        await msg.pin()

    # Position above Staff Members so it stays at the bottom
    staff_cat = discord.utils.get(guild.categories, name="Staff Members")
    if staff_cat and category.position >= staff_cat.position:
        try:
            await category.edit(position=staff_cat.position, reason="Place above Staff Members")
        except (discord.Forbidden, discord.HTTPException):
            pass

    try:
        store.create_location_area(guild_id, str(category.id), clean_name, str(interaction.user.id))
    except storage.DuplicateNameError:
        await category.delete(reason="Duplicate area cleanup")
        await interaction.response.send_message(f"Area **{clean_name}** already exists.", ephemeral=True)
        return

    parts = [f"Created location area **{clean_name}**."]
    if role:
        parts.append(f"Restricted to {role.mention}.")
    if extra_members:
        parts.append(f"Access granted to: {', '.join(m.mention for m in extra_members)}.")
    if description:
        parts.append("Description channel created.")
    await interaction.response.send_message(" ".join(parts))


@location_area_group.command(name="delete", description="Delete a location area and all its locations. [Fortune]")
@app_commands.describe(name="Area to delete.")
@app_commands.autocomplete(name=_location_area_autocomplete)
async def location_area_delete(
    interaction: discord.Interaction, name: str,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = interaction.guild
    guild_id = str(guild.id)
    area = store.get_location_area(guild_id, name)
    if area is None:
        await interaction.response.send_message(f"No area named **{name}**.", ephemeral=True)
        return
    await interaction.response.defer(ephemeral=True)
    locs = store.list_locations(area.id)
    for loc in locs:
        ch = guild.get_channel(int(loc.channel_id))
        if ch:
            try:
                await ch.delete(reason=f"Area {area.name} deleted")
            except discord.Forbidden:
                pass
        store.delete_location(loc.id)
    cat_ch = guild.get_channel(int(area.category_id))
    if cat_ch:
        try:
            await cat_ch.delete(reason=f"Location area deleted by {interaction.user}")
        except discord.Forbidden:
            pass
    store.delete_location_area(area.id)
    await interaction.followup.send(f"Deleted area **{area.name}** and {len(locs)} location(s).")


@location_area_group.command(name="list", description="List all location areas on this server.")
async def location_area_list(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    guild_id = str(interaction.guild_id)
    areas = store.list_location_areas(guild_id)
    if not areas:
        await interaction.response.send_message(
            "No location areas. A Fortune can create one with `/location area create`.", ephemeral=True,
        )
        return
    lines = []
    for a in areas:
        n_locs = len(store.list_locations(a.id))
        lines.append(f"• **{a.name}** ({n_locs} location{'s' if n_locs != 1 else ''})")
    pages = _paginate(lines, "**Location Areas:**\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)


@location_area_group.command(name="fix-permissions", description="Repair permissions on all location areas (hides them from non-Approved). [Kami]")
async def location_area_fix_permissions(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = interaction.guild
    guild_id = str(guild.id)
    areas = store.list_location_areas(guild_id)
    if not areas:
        await interaction.response.send_message("No location areas to fix.", ephemeral=True)
        return
    await interaction.response.defer(ephemeral=True)
    everyone = guild.default_role
    bot_member = guild.me
    approved_role = discord.utils.get(guild.roles, name=ROLE_APPROVED)
    fortune_role = discord.utils.get(guild.roles, name=ROLE_FORTUNE)
    kami_role = discord.utils.get(guild.roles, name=ROLE_KAMI)
    fixed = 0
    skipped = 0
    for area in areas:
        cat = guild.get_channel(int(area.category_id))
        if cat is None or not isinstance(cat, discord.CategoryChannel):
            skipped += 1
            continue
        try:
            await cat.set_permissions(everyone, view_channel=False, reason="Fix permissions")
            await cat.set_permissions(bot_member, view_channel=True, send_messages=True,
                                     manage_channels=True, manage_messages=True,
                                     manage_threads=True, reason="Fix permissions")
            if approved_role:
                await cat.set_permissions(approved_role, view_channel=True, send_messages=True,
                                         read_message_history=True, reason="Fix permissions")
            for r in (fortune_role, kami_role):
                if r:
                    await cat.set_permissions(r, view_channel=True, send_messages=True,
                                             read_message_history=True, manage_messages=True,
                                             reason="Fix permissions")
            for ch in cat.text_channels:
                if ch.name == "description":
                    await ch.set_permissions(everyone, view_channel=False, send_messages=False,
                                            reason="Fix permissions")
                    if approved_role:
                        await ch.set_permissions(approved_role, view_channel=True, send_messages=False,
                                                read_message_history=True, reason="Fix permissions")
                    for r in (fortune_role, kami_role):
                        if r:
                            await ch.set_permissions(r, view_channel=True, send_messages=True,
                                                    read_message_history=True, manage_messages=True,
                                                    reason="Fix permissions")
            fixed += 1
        except discord.Forbidden:
            skipped += 1
    await interaction.followup.send(
        f"Fixed permissions on **{fixed}** area(s). "
        + (f"Skipped **{skipped}** (missing or no permission)." if skipped else "All areas updated."),
        ephemeral=True,
    )


@location_group.command(name="create", description="Create a location (text channel) in an area. [Fortune]")
@app_commands.describe(
    area="Which area to create the location in.",
    name="Location name (becomes the channel name).",
    description="Optional location description (pinned at the top).",
    private="If True, only listed members can see the channel. Default: public (inherits area visibility).",
    member1="Grant access to this member (required for private locations).",
    member2="Grant access to a second member.",
    member3="Grant access to a third member.",
    member4="Grant access to a fourth member.",
    member5="Grant access to a fifth member.",
)
@app_commands.autocomplete(area=_location_area_autocomplete)
async def location_create(
    interaction: discord.Interaction,
    area: str,
    name: app_commands.Range[str, 1, 90],
    description: app_commands.Range[str, 1, 4000] | None = None,
    private: bool = False,
    member1: discord.Member | None = None,
    member2: discord.Member | None = None,
    member3: discord.Member | None = None,
    member4: discord.Member | None = None,
    member5: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = interaction.guild
    guild_id = str(guild.id)
    area_rec = store.get_location_area(guild_id, area)
    if area_rec is None:
        await interaction.response.send_message(f"No area named **{area}**.", ephemeral=True)
        return
    clean_name = name.strip()
    cat_ch = guild.get_channel(int(area_rec.category_id))
    if cat_ch is None or not isinstance(cat_ch, discord.CategoryChannel):
        await interaction.response.send_message(
            f"The Discord category for area **{area_rec.name}** no longer exists. "
            "A Fortune should delete and recreate the area.",
            ephemeral=True,
        )
        return
    extra_members = [m for m in (member1, member2, member3, member4, member5) if m]
    ch_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] | None = None
    if private:
        everyone = guild.default_role
        bot_member = guild.me
        fortune_role = discord.utils.get(guild.roles, name=ROLE_FORTUNE)
        kami_role = discord.utils.get(guild.roles, name=ROLE_KAMI)
        ch_overwrites = {
            everyone: discord.PermissionOverwrite(view_channel=False),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_channels=True,
                manage_messages=True,
            ),
        }
        for r in (fortune_role, kami_role):
            if r:
                ch_overwrites[r] = discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, read_message_history=True,
                    manage_messages=True,
                )
        for m in extra_members:
            ch_overwrites[m] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
            )
    try:
        channel = await cat_ch.create_text_channel(
            clean_name, overwrites=ch_overwrites or {}, reason=f"Location by {interaction.user}",
        )
    except discord.Forbidden:
        await interaction.response.send_message(
            "I need **Manage Channels** permission in this category.", ephemeral=True,
        )
        return
    if not private and extra_members:
        for m in extra_members:
            await channel.set_permissions(m, view_channel=True, send_messages=True,
                                          read_message_history=True, reason="Extra member access")
    try:
        loc = store.create_location(
            guild_id, area_rec.id, str(channel.id), clean_name,
            str(interaction.user.id), description=description or "",
        )
    except storage.DuplicateNameError:
        await channel.delete(reason="Duplicate location cleanup")
        await interaction.response.send_message(
            f"A location named **{clean_name}** already exists in **{area_rec.name}**.", ephemeral=True,
        )
        return
    parts = [f"Created location {channel.mention} in **{area_rec.name}**."]
    if private:
        parts.append("(Private)")
    if extra_members:
        parts.append(f"Access: {', '.join(m.mention for m in extra_members)}.")
    await interaction.response.send_message(" ".join(parts))
    if description:
        embed = discord.Embed(title=clean_name, description=description, color=0xC4A747)
        pin_msg = await channel.send(embed=embed)
        await pin_msg.pin()


@location_group.command(name="describe", description="Set or update a location's pinned description (run inside the location channel).")
@app_commands.describe(description="The new location description to pin.")
async def location_describe(
    interaction: discord.Interaction,
    description: app_commands.Range[str, 1, 4000],
) -> None:
    if not await _require_guild(interaction):
        return
    loc = store.get_location_by_channel(str(interaction.channel_id))
    if loc is None:
        await interaction.response.send_message(
            "Run this inside a location channel.", ephemeral=True,
        )
        return
    if str(interaction.user.id) != loc.creator_id and not _is_dm(interaction):
        await interaction.response.send_message(
            "Only the location creator or a Fortune can change the description.", ephemeral=True,
        )
        return
    await interaction.response.send_message(f"Updating description for **{loc.name}**...", ephemeral=True)
    try:
        pinned = await interaction.channel.pins()
        for msg in pinned:
            if msg.author == interaction.client.user and msg.embeds and msg.embeds[0].color and msg.embeds[0].color.value == 0xC4A747:
                await msg.unpin()
                await msg.delete()
    except discord.Forbidden:
        pass
    store.update_location_description(loc.id, description)
    embed = discord.Embed(title=loc.name, description=description, color=0xC4A747)
    pin_msg = await interaction.channel.send(embed=embed)
    await pin_msg.pin()


@location_group.command(name="list", description="List locations in an area (or all areas if none specified).")
@app_commands.describe(area="Filter to a specific area.")
@app_commands.autocomplete(area=_location_area_autocomplete)
async def location_list(
    interaction: discord.Interaction,
    area: str | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild_id = str(interaction.guild_id)
    if area:
        area_rec = store.get_location_area(guild_id, area)
        if area_rec is None:
            await interaction.response.send_message(f"No area named **{area}**.", ephemeral=True)
            return
        areas_to_show = [area_rec]
    else:
        areas_to_show = store.list_location_areas(guild_id)
    if not areas_to_show:
        await interaction.response.send_message(
            "No location areas. A Fortune can create one with `/location area create`.",
            ephemeral=True,
        )
        return
    lines = []
    for a in areas_to_show:
        locs = store.list_locations(a.id)
        lines.append(f"**{a.name}**")
        if locs:
            for loc in locs:
                lines.append(f"  • <#{loc.channel_id}> — {loc.name}" + (f" (by <@{loc.creator_id}>)" if loc.creator_id else ""))
        else:
            lines.append("  *(no locations yet)*")
    pages = _paginate(lines, "**Locations:**\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)


@location_group.command(name="close", description="Delete a location channel. Creator or Fortune required (run inside the channel).")
async def location_close(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    loc = store.get_location_by_channel(str(interaction.channel_id))
    if loc is None:
        await interaction.response.send_message(
            "Run this inside a location channel.", ephemeral=True,
        )
        return
    if str(interaction.user.id) != loc.creator_id and not _is_dm(interaction):
        await interaction.response.send_message(
            "Only the location creator or a Fortune can close it.", ephemeral=True,
        )
        return
    store.delete_location(loc.id)
    await interaction.response.send_message(f"Closing location **{loc.name}**...")
    try:
        await interaction.channel.delete(reason=f"Location closed by {interaction.user}")
    except discord.Forbidden:
        pass


# ===========================================================================
# /xp group: Experience: DMs grant, players spend to advance (L5R 4e RAW)
# ===========================================================================

async def _buy_named(interaction, member, name, mastery_level, attr, label, emoji, note="", cost=None):
    """Shared handler for Kata / Kiho / memorised Spell (cost = 1 x Mastery Level unless overridden)."""
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    lst = getattr(c, attr)
    if any(x.lower() == name.lower() for x in lst):
        await interaction.response.send_message(f"**{c.name}** already knows the {label} **{name}**.", ephemeral=True)
        return
    if cost is None:
        cost = advancement.misc_cost(mastery_level)
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: **{name}** (Mastery Level {mastery_level}) costs **{cost}**, "
            f"but **{c.name}** has {c.xp:g}.", ephemeral=True)
        return
    lst.append(name)
    c.xp -= cost
    c.xp_spent += cost
    changed = store.save(rec, note="xp spend")
    await _xp_spend_log(interaction, rec, changed)
    await interaction.response.send_message(
        f"{emoji} **{c.name}** learns the {label} **{name}** (ML {mastery_level}) for **{cost}** XP.{note}\n"
        f"XP left {c.xp:g}", embed=build_sheet_embed(rec))

@xp_group.command(name="grant", description="Grant (or correct) a player's Experience. [Fortune]")
@app_commands.describe(member="The player to grant XP to.", amount="XP amount (negative to correct).", reason="Optional note.")
async def xp_grant(interaction: discord.Interaction, member: discord.Member, amount: app_commands.Range[float, -100000.0, 100000.0], reason: str | None = None) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    rec = store.get_active(str(interaction.guild_id), str(member.id))
    if rec is None:
        await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
        return
    before = rec.character.xp
    rec.character.xp = max(0.0, rec.character.xp + float(amount))
    store.save(rec, note="xp grant")
    note = f" - *{reason}*" if reason else ""
    await interaction.response.send_message(
        f"✨ {member.mention}'s **{rec.character.name}** {'gains' if amount >= 0 else 'loses'} "
        f"**{abs(amount):g}** XP -> **{rec.character.xp:g}** available{note}")
    logged = await _xp_log(
        str(interaction.guild_id),
        f"XP GRANT: {interaction.user.display_name} → {rec.character.name} ({member.display_name}) "
        f"{'+' if amount >= 0 else ''}{amount:g} · {before:g} → {rec.character.xp:g}" + (f" · {reason}" if reason else ""),
    )
    if not logged:
        await interaction.followup.send(
            "⚠️ This grant was not logged: no XP log channel is set. A Kami can set one with `/dm xp_log_channel`.",
            ephemeral=True,
        )

@xp_group.command(name="balance", description="Show a character's available Experience.")
@app_commands.describe(member="Whose XP to show [Fortune]. Omit for your own.")
async def xp_balance(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_active(guild, str(member.id))
    else:
        rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
        return
    c = rec.character
    await interaction.response.send_message(
        f"**{c.name}** - XP available **{c.xp:g}**, spent {c.xp_spent:g}. "
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}).", ephemeral=True)

@xp_group.command(name="trait", description="Spend XP to raise a Trait or Void (RAW: Trait N x4, Void N x6).")
@app_commands.describe(trait="Which Trait (or Void) to raise.", member="Advance another player's character [Fortune]")
@app_commands.choices(trait=_TRAIT_CHOICES)
async def xp_trait(interaction: discord.Interaction, trait: app_commands.Choice[str], member: discord.Member | None = None) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    quote = advancement.trait_raise_quote(c, trait.value)
    label = "Void" if trait.value == "void" else trait.value.capitalize()
    if quote is None:
        cap = advancement.MAX_VOID_RANK if trait.value == "void" else advancement.MAX_TRAIT_RANK
        await interaction.response.send_message(f"{label} is already at rank {cap}.", ephemeral=True)
        return
    new_rank, cost = quote
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: raising {label} to **{new_rank}** costs **{cost}**, but **{c.name}** has {c.xp:g}.",
            ephemeral=True)
        return
    advancement.apply_trait_raise(c, trait.value)
    c.xp -= cost
    c.xp_spent += cost
    rank_msg = _check_insight_rank_advance(c)
    changed = store.save(rec, note="xp spend")
    await _xp_spend_log(interaction, rec, changed)
    await interaction.response.send_message(
        f"\U0001F300 **{c.name}** raises **{label}** to rank **{new_rank}** for **{cost}** XP.\n"
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) - XP left {c.xp:g}{rank_msg}", embed=build_sheet_embed(rec))

@xp_group.command(name="skill", description="Spend XP to raise or learn a Skill (RAW: new rank x1).")
@app_commands.describe(skill="Skill name.", member="Advance another player's character [Fortune]")
async def xp_skill(interaction: discord.Interaction, skill: app_commands.Range[str, 1, 40], member: discord.Member | None = None) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    skill_name = skill.strip().title()
    quote = advancement.skill_raise_quote(c, skill_name)
    if quote is None:
        await interaction.response.send_message(f"**{skill_name}** is already at rank {advancement.MAX_SKILL_RANK}.", ephemeral=True)
        return
    new_rank, cost = quote
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: raising **{skill_name}** to **{new_rank}** costs **{cost}**, but **{c.name}** has {c.xp:g}.",
            ephemeral=True)
        return
    advancement.apply_skill_raise(c, skill_name)
    c.xp -= cost
    c.xp_spent += cost
    rank_msg = _check_insight_rank_advance(c)
    changed = store.save(rec, note="xp spend")
    await _xp_spend_log(interaction, rec, changed)
    await interaction.response.send_message(
        f"\U0001F4D8 **{c.name}** raises **{skill_name}** to rank **{new_rank}** for **{cost}** XP.\n"
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) - XP left {c.xp:g}{rank_msg}", embed=build_sheet_embed(rec))

@xp_group.command(name="emphasis", description="Spend 2 XP to add a Skill Emphasis (at most half the Skill rank, rounded up).")
@app_commands.describe(skill="The skill to add an Emphasis to.", emphasis="The Emphasis (e.g. Katana).", member="Advance another player's character [Fortune]")
async def xp_emphasis(interaction: discord.Interaction, skill: app_commands.Range[str, 1, 40], emphasis: app_commands.Range[str, 1, 40], member: discord.Member | None = None) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    skill_name = skill.strip().title()
    emph = emphasis.strip().title()
    cost, problem = advancement.emphasis_quote(c, skill_name, emph)
    if problem:
        await interaction.response.send_message(problem, ephemeral=True)
        return
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: an Emphasis costs **{cost}**, but **{c.name}** has {c.xp:g}.", ephemeral=True)
        return
    advancement.apply_emphasis(c, skill_name, emph)
    c.xp -= cost
    c.xp_spent += cost
    changed = store.save(rec, note="xp spend")
    await _xp_spend_log(interaction, rec, changed)
    await interaction.response.send_message(
        f"\U0001F3AF **{c.name}** gains **{skill_name} (Emphasis: {emph})** for **{cost}** XP. XP left {c.xp:g}",
        embed=build_sheet_embed(rec))

def _kata_school_ok(c: Character, schools_str: str) -> tuple[bool, str]:
    """Check if character qualifies for a kata's school requirement."""
    if not schools_str:
        return True, ""
    base = schools_str.split("|")[0].strip()
    if base.lower() == "any":
        return True, ""
    if base.lower().startswith("any "):
        parts = base.split()
        if len(parts) == 3 and parts[2].lower() in ("bushi", "school"):
            if parts[1].lower() == "bushi":
                if "bushi" not in c.school_type.lower():
                    return False, f"requires a Bushi school (you are {c.school_type})"
                return True, ""
            clan_req = parts[1]
            if c.clan.lower() != clan_req.lower():
                return False, f"requires {clan_req} clan (you are {c.clan})"
            if "bushi" not in c.school_type.lower():
                return False, f"requires a {clan_req} Bushi school (you are {c.school_type})"
            return True, ""
        if len(parts) == 2 and parts[1].lower() == "bushi":
            if "bushi" not in c.school_type.lower():
                return False, f"requires a Bushi school (you are {c.school_type})"
            return True, ""
    allowed = [s.strip().lower() for s in base.split(",")]
    if c.school.strip().lower() in allowed:
        return True, ""
    return False, f"requires school: {base}"

@xp_group.command(name="kata", description="Learn a Kata (cost = 1 x Mastery Level).")
@app_commands.describe(
    name="Kata name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the kata is in the catalog).",
    member="Advance another player's character [Fortune]",
)
@app_commands.autocomplete(name=_kata_autocomplete)
async def xp_kata(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 60],
    mastery_level: app_commands.Range[int, 1, 10] | None = None,
    member: discord.Member | None = None,
) -> None:
    kata_entry = kata.get(name)
    ml = mastery_level if mastery_level is not None else (kata_entry["mastery"] if kata_entry else None)
    if ml is None:
        await interaction.response.send_message(
            f"**{name}** isn't in the catalog: give its `mastery_level:` too.", ephemeral=True
        )
        return
    if not _is_dm(interaction) and kata_entry:
        rec, err = await _resolve_active_for_edit(interaction, member)
        if err:
            await interaction.response.send_message(err, ephemeral=True)
            return
        ok, reason = _kata_school_ok(rec.character, kata_entry.get("schools", ""))
        if not ok:
            await interaction.response.send_message(
                f"**{rec.character.name}** cannot learn **{kata_entry['name']}**: {reason}.",
                ephemeral=True)
            return
    canonical = kata_entry["name"] if kata_entry else name.strip()
    await _buy_named(interaction, member, canonical, ml, "katas", "kata", "\U0001F94B")

@xp_group.command(name="kiho", description="Learn a Kiho (Brotherhood 1x ML; non-Brotherhood monks 1.5x; shugenja 2x).")
@app_commands.describe(
    name="Kiho name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the kiho is in the catalog).",
    non_brotherhood="Non-Brotherhood monk (1.5x cost).",
    shugenja="Shugenja buyer (2x cost).",
    member="Advance another player's character [Fortune]",
)
@app_commands.autocomplete(name=_kiho_autocomplete)
async def xp_kiho(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 60],
    mastery_level: app_commands.Range[int, 1, 10] | None = None,
    non_brotherhood: bool = False,
    shugenja: bool = False,
    member: discord.Member | None = None,
) -> None:
    if non_brotherhood and shugenja:
        await interaction.response.send_message("Pick one: `non_brotherhood` or `shugenja`, not both.", ephemeral=True)
        return
    kiho_entry = kiho.get(name)
    ml = mastery_level if mastery_level is not None else (kiho_entry["mastery"] if kiho_entry else None)
    if ml is None:
        await interaction.response.send_message(
            f"**{name}** isn't in the catalog: give its `mastery_level:` too.", ephemeral=True
        )
        return
    if not _is_dm(interaction):
        rec, err = await _resolve_active_for_edit(interaction, member)
        if err:
            await interaction.response.send_message(err, ephemeral=True)
            return
        c = rec.character
        stype = c.school_type.lower()
        if "monk" not in stype and "shugenja" not in stype:
            await interaction.response.send_message(
                f"**{c.name}** is a {c.school_type}. Only Monks and Shugenja can learn Kiho.",
                ephemeral=True)
            return
        if "shugenja" in stype and not shugenja:
            shugenja = True
        if kiho_entry and kiho_entry.get("element"):
            elem = kiho_entry["element"].lower()
            if elem != "void":
                ring_val = stats.ring_value(c, elem)
                if ring_val < ml:
                    await interaction.response.send_message(
                        f"**{c.name}**'s {elem.title()} Ring is {ring_val}, but **{kiho_entry['name']}** "
                        f"requires {elem.title()} {ml}.", ephemeral=True)
                    return
    canonical = kiho_entry["name"] if kiho_entry else name.strip()
    cost = advancement.kiho_cost(ml, non_brotherhood=non_brotherhood, shugenja=shugenja)
    note = " *(shugenja: 2x cost)*" if shugenja else (" *(non-Brotherhood monk: 1.5x cost)*" if non_brotherhood else "")
    await _buy_named(interaction, member, canonical, ml, "kiho", "kiho", "✋", note=note, cost=cost)

@xp_group.command(name="spell", description="Memorise a spell so no scroll is needed (cost = 1 x Mastery Level).")
@app_commands.describe(
    name="Spell name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the spell is in the catalog).",
    member="Advance another player's character [Fortune]",
)
@app_commands.autocomplete(name=_spell_autocomplete)
async def xp_spell(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 60],
    mastery_level: app_commands.Range[int, 1, 10] | None = None,
    member: discord.Member | None = None,
) -> None:
    spell = spells.get(name)
    ml = mastery_level if mastery_level is not None else (spell["mastery"] if spell else None)
    if ml is None:
        await interaction.response.send_message(
            f"**{name}** isn't in the catalog: give its `mastery_level:` too.", ephemeral=True
        )
        return
    if not _is_dm(interaction):
        rec, err = await _resolve_active_for_edit(interaction, member)
        if err:
            await interaction.response.send_message(err, ephemeral=True)
            return
        if "shugenja" not in rec.character.school_type.lower():
            await interaction.response.send_message(
                f"**{rec.character.name}** is a {rec.character.school_type}, not a Shugenja. "
                f"Only Shugenja can memorise spells.", ephemeral=True)
            return
    canonical = spell["name"] if spell else name.strip()
    await _buy_named(interaction, member, canonical, ml, "spells_known", "spell", "\U0001F4DC")

@xp_group.command(name="advantage", description="Buy an Advantage with XP (cost = its point value).")
@app_commands.describe(
    name="Advantage name.",
    points="Point cost: required only for 'Variable'-cost advantages.",
    member="Advance another player's character [Fortune]",
)
@app_commands.autocomplete(name=_advantage_autocomplete)
async def xp_advantage(
    interaction: discord.Interaction,
    name: str,
    points: app_commands.Range[int, 1, 20] | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    input_name = name.strip()
    base_name = input_name.split(":")[0].strip() if ":" in input_name else input_name
    adv = advantages.get(base_name, "advantage")
    if adv is None:
        await interaction.response.send_message(
            f"No advantage named **{base_name}**: see `/ref advantage search`.", ephemeral=True
        )
        return
    canonical = adv["name"]
    if ":" in input_name:
        param = input_name[input_name.index(":") + 1:].strip()
        canonical = f"{canonical}: {param}"
    cost = points if points is not None else adv["points"]
    if cost is None:
        await interaction.response.send_message(
            f"**{adv['name']}** has a Variable cost ({adv['cost_text']}): pass `points:` to set it.",
            ephemeral=True,
        )
        return
    c = rec.character
    if canonical.lower() in [x.lower() for x in c.advantages]:
        await interaction.response.send_message(f"**{c.name}** already has **{canonical}**.", ephemeral=True)
        return
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: **{canonical}** costs **{cost}**, but **{c.name}** has {c.xp:g}.", ephemeral=True
        )
        return
    c.advantages.append(canonical)
    c.xp -= cost
    c.xp_spent += cost
    changed = store.save(rec, note="xp spend")
    await _xp_spend_log(interaction, rec, changed)
    msg = f"🌸 **{c.name}** gains the advantage **{canonical}** for **{cost}** XP. XP left {c.xp:g}"
    param_hint = advantage_effects.PARAMETERISED_ADVANTAGES.get(adv["name"])
    if param_hint and ":" not in input_name:
        msg += f"\n*Hint: use `{adv['name']}: <{param_hint}>` to record the chosen option.*"
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@xp_group.command(name="remove_disadvantage", description="Buy off a Disadvantage with XP (cost = 2x its point value).")
@app_commands.describe(
    name="Disadvantage name (must be on the character's sheet).",
    points="Point value of the disadvantage (required if not in catalog or Variable cost).",
    member="Target another player's character [Fortune]",
)
@app_commands.autocomplete(name=_disadvantage_autocomplete)
async def xp_remove_disadvantage(
    interaction: discord.Interaction,
    name: str,
    points: app_commands.Range[int, 1, 20] | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    name_stripped = name.strip()
    name_low = name_stripped.lower()
    matched = [d for d in c.disadvantages if d.lower() == name_low]
    if not matched:
        base_name = name_stripped.split(":")[0].strip()
        adv = advantages.get(name_stripped, "disadvantage") or advantages.get(base_name, "disadvantage")
        canonical = adv["name"] if adv else base_name
        matched = [d for d in c.disadvantages if d.lower() == canonical.lower()]
    if not matched:
        matched = [d for d in c.disadvantages if d.lower().startswith(name_low.split(":")[0].strip())]
    if not matched:
        await interaction.response.send_message(
            f"**{c.name}** doesn't have the disadvantage **{name}**.", ephemeral=True
        )
        return
    canonical = matched[0]
    base_for_lookup = canonical.split(":")[0].strip()
    adv = advantages.get(canonical, "disadvantage") or advantages.get(base_for_lookup, "disadvantage")
    base_cost = points if points is not None else (adv["points"] if adv else None)
    if base_cost is None:
        await interaction.response.send_message(
            f"**{canonical}** has a Variable cost: pass `points:` to set its base value.", ephemeral=True
        )
        return
    cost = base_cost * 2
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: removing **{canonical}** costs **{cost}** (2x{base_cost}), "
            f"but **{c.name}** has {c.xp:g}.", ephemeral=True
        )
        return
    c.disadvantages = [d for d in c.disadvantages if d.lower() != canonical.lower()]
    c.xp -= cost
    c.xp_spent += cost
    changed = store.save(rec, note="xp spend")
    await _xp_spend_log(interaction, rec, changed)
    await interaction.response.send_message(
        f"**{c.name}** overcomes the disadvantage **{canonical}** for **{cost}** XP "
        f"(2x base {base_cost}). XP left {c.xp:g}",
        embed=build_sheet_embed(rec),
    )

@xp_group.command(name="costs", description="Show the Experience cost reference (L5R 4e RAW).")
async def xp_costs(interaction: discord.Interaction) -> None:
    await interaction.response.send_message(
        "**Experience costs (L5R 4e RAW)**\n" + advancement.cost_table()
        + "\n\nA DM grants XP with `/xp grant`; spend it with `/xp trait`, `/xp skill`, `/xp emphasis`, "
        "`/xp kata`, `/xp kiho`, `/xp spell`. Insight Rank follows automatically. Prerequisites and "
        "learning-a-Technique roleplay are DM-adjudicated.", ephemeral=True)

# ===========================================================================
# /school group: schools & techniques (GDD s29)
# ===========================================================================

@sheet.command(name="learn", description="Record the techniques your school grants up to your School Rank.")
@app_commands.describe(
    school_name="School to learn from (defaults to your sheet's school). Different school requires Fortune.",
    member="Do this for another player [Fortune]",
)
@app_commands.autocomplete(school_name=_school_autocomplete)
async def school_learn(
    interaction: discord.Interaction,
    school_name: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if school_name and c.school and school_name.strip().lower() != c.school.strip().lower():
        if not await _require_dm_role(interaction):
            return
    lookup = school_name or c.school
    s = schools.get(lookup) if lookup else None
    if s is None:
        await interaction.response.send_message(
            f"No school named **{lookup or '(unset)'}**. Set one with `school_name:` "
            f"(or `/stat set` isn't for this: pick from `/ref school search`).",
            ephemeral=True,
        )
        return
    entitled = schools.techniques_up_to(s["name"], c.school_rank)
    if not entitled:
        await interaction.response.send_message(
            f"**{s['name']}** grants no ranked techniques at School Rank {c.school_rank}.", ephemeral=True
        )
        return
    added = []
    for t in entitled:
        label = f"{s['name']}: {t['name']}"
        if not any(label.lower() == x.lower() or t["name"].lower() == x.lower() for x in c.techniques):
            c.techniques.append(label)
            added.append(f"R{t['rank']} {t['name']}")
    store.save(rec)
    if added:
        msg = f"📜 **{c.name}** learns from **{s['name']}** (up to Rank {c.school_rank}): " + ", ".join(added)
    else:
        msg = f"**{c.name}** already knows all **{s['name']}** techniques up to Rank {c.school_rank}."
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

# ===========================================================================
# /spell group: spells & elements (GDD s32–s37)
# ===========================================================================
spell_group = app_commands.Group(name="spell", description="Browse spells by element and mastery.")

_ELEMENT_COLORS = {
    "air": discord.Color.light_grey(), "earth": discord.Color.dark_gold(),
    "fire": discord.Color.red(), "water": discord.Color.blue(),
    "void": discord.Color.purple(), "all": discord.Color.teal(),
}

def build_spell_embed(s: dict) -> discord.Embed:
    color = _ELEMENT_COLORS.get(s["element"].lower(), discord.Color.teal())
    kw = f" · {s['keyword']}" if s["keyword"] else ""
    tags = f" [{', '.join(s['tags'])}]" if s["tags"] else ""
    embed = discord.Embed(title=f"🔮 {s['name']}{tags}", color=color)
    embed.description = f"**{s['element']} {s['mastery']}**{kw}"
    line = []
    if s["range"]:
        line.append(f"**Range: ** {s['range']}")
    if s["area"]:
        line.append(f"**Area: ** {s['area']}")
    if s["duration"]:
        line.append(f"**Duration: ** {s['duration']}")
    if line:
        embed.add_field(name="​", value="  ·  ".join(line), inline=False)
    if s["raises"]:
        embed.add_field(name="Raises", value=s["raises"][:1024], inline=False)
    if s["effect"]:
        embed.add_field(name="Effect", value=s["effect"][:1024], inline=False)
    return embed

@spell_group.command(name="list", description="List spells by element (or a summary).")
@app_commands.describe(element="Air, Earth, Fire, Water, Void, All. Omit for a summary.")
async def spell_list(interaction: discord.Interaction, element: str | None = None) -> None:
    if not element:
        from collections import Counter
        counts = Counter(s["element"] for s in spells.ALL)
        summary = " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))
        await interaction.response.send_message(
            f"🔮 **{len(spells.ALL)} spells.** Browse with `/spell list element:<element>`, "
            f"`/spell search`, `/spell view`.\n{summary}", ephemeral=True
        )
        return
    matches = spells.by_element(element)
    if not matches:
        await interaction.response.send_message(
            f"No spells for **{element}**. Elements: {', '.join(spells.elements())}", ephemeral=True
        )
        return
    by_ml: dict[int, list[str]] = {}
    for s in matches:
        by_ml.setdefault(s["mastery"], []).append(s["name"])
    lines = [f"**ML {ml}: ** " + ", ".join(sorted(by_ml[ml])) for ml in sorted(by_ml)]
    pages = _paginate(lines, f"🔮 **{element} spells ({len(matches)}): **\n", per_page=10)
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)

@spell_group.command(name="search", description="Search spells by name, element, or keyword.")
@app_commands.describe(query="Name, element, or keyword fragment.")
async def spell_search(interaction: discord.Interaction, query: str) -> None:
    matches = spells.search(query)
    if not matches:
        await interaction.response.send_message(f"No spells match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{s['name']}** ({s['element']} {s['mastery']})" for s in matches]
    pages = _paginate(lines, f"🔮 **{len(matches)} spell(s) matching `{query}`: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)

@spell_group.command(name="view", description="Show a spell's element, mastery, range, and effect.")
@app_commands.describe(name="The spell to view.")
@app_commands.autocomplete(name=_spell_autocomplete)
async def spell_view(interaction: discord.Interaction, name: str) -> None:
    s = spells.get(name)
    if s is None:
        await interaction.response.send_message(
            f"No spell named **{name}**. Try `/spell search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_spell_embed(s))

@spell_group.command(name="cast", description="Roll a Spell Casting Roll: (Ring + School Rank) keep Ring vs TN.")
@app_commands.describe(
    name="Spell name (auto-complete from the catalog).",
    raises="Called raises on the casting roll.",
    spend_void="Spend a Void Point for +1k1.",
    conceal="Conceal the casting with Stealth/Agility (result = observers' detection TN).",
    attacker_npc="Cast as a stored NPC [Fortune]",
    member="Cast as another player's character [Fortune]",
    target="Combatant the spell is aimed at: enables Request-condition buttons for Dazed, Prone, etc.",
)
@app_commands.autocomplete(name=_spell_autocomplete, target=cog_combat._combatant_autocomplete)
async def spell_cast(
    interaction: discord.Interaction,
    name: str,
    raises: int = 0,
    spend_void: bool = False,
    target: str | None = None,
    conceal: bool = False,
    attacker_npc: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    s = spells.get(name)
    if s is None:
        await interaction.response.send_message(f"No spell named **{name}**. Try `/spell search`.", ephemeral=True)
        return
    # Resolve caster.
    if attacker_npc:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_name(guild, NPC_OWNER, attacker_npc)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{attacker_npc}**.", ephemeral=True)
            return
    elif member is not None and member.id != interaction.user.id:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message(
                "You have no active character. Use `/sheet create` first.", ephemeral=True
            )
            return
    caster = rec.character
    if await _refuse_if_cannot_act(interaction, caster):
        return
    if raises < 0 or raises > combat.max_raises(caster):
        await interaction.response.send_message(
            f"Too many Raises: {raises} called but the maximum per roll is the Void Ring, "
            f"**{combat.max_raises(caster)}**.", ephemeral=True,
        )
        return
    element = s["element"].lower()
    ring_val = stats.ring_value(caster, element)
    affinity = caster.affinity_element.lower() == element if caster.affinity_element else False
    deficiency = caster.deficiency_element.lower() == element if caster.deficiency_element else False
    # Spell slot check with Void bonus fallback.
    used_bonus_slot = False
    slot_remaining = caster.spell_slots.get(element)
    if slot_remaining is not None and slot_remaining <= 0:
        if caster.void_spell_bonus > 0:
            used_bonus_slot = True
        else:
            slot_max = stats.spell_slot_max(caster, element)
            bonus_max = stats.void_bonus_max(caster)
            await interaction.response.send_message(
                f"**{caster.name}** has no **{element.title()}** spell slots remaining "
                f"(0/{slot_max}) and no Void bonus slots (0/{bonus_max}). "
                f"A DM must call `/dm new_day` to refresh slots.",
                ephemeral=True,
            )
            return
    extra_rolled = 0
    extra_kept = 0
    wound_pen = stats.wound_penalty(caster)
    if spend_void:
        ok, reason_block = advantage_effects.can_spend_void_on_roll(caster)
        if not ok:
            await interaction.response.send_message(f"🌀 {reason_block}", ephemeral=True)
            return
        if caster.current_void_points <= 0:
            await interaction.response.send_message("No Void Points remaining.", ephemeral=True)
            return
        caster.current_void_points -= 1
        _tally(interaction.channel_id, caster.name, "void")
        extra_rolled = extra_kept = 1
    fear_r = _fear_penalty(interaction.channel_id, caster.name)
    extra_rolled -= fear_r
    result = combat.resolve_spell_casting(
        ring_val, caster.school_rank, s["mastery"], engine,
        affinity=affinity, deficiency=deficiency,
        extra_rolled=extra_rolled, extra_kept=extra_kept,
        raises=raises, extra_flat=wound_pen,
    )
    if result.get("cannot_cast"):
        await interaction.response.send_message(
            f"**{caster.name}** cannot cast **{s['name']}**: {result['reason']}.", ephemeral=True
        )
        return
    # Consume a spell slot (L5R 4e: consumed whether the roll succeeds or fails).
    if used_bonus_slot:
        caster.void_spell_bonus = max(0, caster.void_spell_bonus - 1)
    elif element in caster.spell_slots:
        caster.spell_slots[element] = max(0, caster.spell_slots[element] - 1)
    store.save(rec)
    success = result["success"]
    embed = discord.Embed(
        title=f"📜 {caster.name} casts {s['name']}",
        color=discord.Color.gold() if success else discord.Color.greyple(),
    )
    notes = []
    if affinity:
        notes.append(f"Affinity ({element.title()}): effective rank {result['effective_rank']}")
    if deficiency:
        notes.append(f"Deficiency ({element.title()}): effective rank {result['effective_rank']}")
    if spend_void:
        notes.append(f"Void Point: +1k1 ({caster.current_void_points} VP left)")
    if wound_pen:
        notes.append(f"Wound penalty: {wound_pen}")
    if fear_r:
        notes.append(f"Fear: -{fear_r}k0 (failed Fear check)")
    if used_bonus_slot:
        bonus_max = stats.void_bonus_max(caster)
        notes.append(f"Void bonus slot used ({caster.void_spell_bonus}/{bonus_max} left)")
    elif element in caster.spell_slots:
        slot_max = stats.spell_slot_max(caster, element)
        notes.append(f"{element.title()} slots: {caster.spell_slots[element]}/{slot_max}")
    roll_desc = (
        f"**{s['element']}** Ring {ring_val} + School Rank {result['effective_rank']}"
        f" → {result['rolled']}k{result['kept']}\n"
        f"Roll **{result['total']}** vs TN **{result['tn']}**"
        f": {'**SUCCESS**' if success else '**FAILED** (slot consumed)'}"
    )
    embed.add_field(name="Spell Casting Roll", value=roll_desc, inline=False)
    if conceal:
        stealth_rank = caster.skills.get("Stealth", 0)
        conceal_rolled = caster.agility + stealth_rank
        conceal_kept = caster.agility
        conceal_result = engine.roll_and_keep(max(1, conceal_rolled), max(1, conceal_kept))
        conceal_total = conceal_result.total + wound_pen
        embed.add_field(
            name="Concealed Casting",
            value=(
                f"Stealth {stealth_rank} / Agility {caster.agility} → "
                f"{conceal_rolled}k{conceal_kept} = **{conceal_total}**\n"
                f"Observers must roll Perception (Investigation) ≥ {conceal_total} to notice."
            ),
            inline=False,
        )
    if notes:
        embed.add_field(name="Modifiers", value=" · ".join(notes), inline=False)
    if success:
        casting_time = max(1, s["mastery"] - raises) if raises else s["mastery"]
        spell_info = f"**Mastery {s['mastery']}** · Range: {s['range']} · Duration: {s['duration']}"
        if casting_time > 1:
            spell_info += f"\n⏱️ **{casting_time} Complex Actions** to complete"
        embed.add_field(name="Spell", value=spell_info, inline=False)
        if s.get("effect"):
            effect_text = s["effect"][:1024]
            embed.add_field(name="Effect", value=effect_text, inline=False)
    prompt_view = None
    conds = cog_combat.spell_conditions(s.get("effect", "")) if success else []
    if conds:
        enc_here = encounters.get(interaction.channel_id)
        tgt_cb = enc_here.find(target) if (enc_here and target) else None
        cond_names = ", ".join(c.title() for c, _ in conds)
        if tgt_cb is not None:
            prompt_view = cog_combat.SpellConditionPromptView(
                guild, interaction.channel_id, tgt_cb.name, interaction.user.id, s["name"], conds,
            )
            embed.set_footer(text=f"This spell can impose: {cond_names}. Press a button to ask a DM to apply it to {tgt_cb.name}.")
        else:
            embed.set_footer(text=f"This spell can impose: {cond_names}. Cast with target: (a combatant here) for one-click requests, or use /fight condition.")
    # discord.py's interaction response rejects view=None (only a real view or omitted).
    if prompt_view is not None:
        await interaction.response.send_message(embed=embed, view=prompt_view)
    else:
        await interaction.response.send_message(embed=embed)

@spell_group.command(name="resist", description="Target resists a spell: Willpower roll vs TN. [Fortune]")
@app_commands.describe(
    target="Character resisting the spell.",
    tn="Target Number for the resistance roll.",
    spend_void="Target spends a Void Point for +1k1.",
)
@app_commands.autocomplete(target=_any_character_autocomplete)
async def spell_resist(
    interaction: discord.Interaction,
    target: str,
    tn: int,
    spend_void: bool = False,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _find_any_character(guild, target)
    if rec is None:
        await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
        return
    c = rec.character
    willpower = c.willpower
    extra_rolled = 0
    extra_kept = 0
    if spend_void:
        ok, reason_block = advantage_effects.can_spend_void_on_roll(c)
        if not ok:
            await interaction.response.send_message(f"🌀 {reason_block}", ephemeral=True)
            return
        if c.current_void_points <= 0:
            await interaction.response.send_message(
                f"**{c.name}** has no Void Points remaining.", ephemeral=True
            )
            return
        c.current_void_points -= 1
        extra_rolled = extra_kept = 1
        store.save(rec)
    rolled = willpower + extra_rolled
    kept = willpower + extra_kept
    result = engine.roll_and_keep(max(1, rolled), max(1, kept))
    wound_pen = stats.wound_penalty(c)
    total = result.total + wound_pen
    success = total >= tn
    embed = discord.Embed(
        title=f"🛡️ {c.name}: Spell Resistance",
        color=discord.Color.green() if success else discord.Color.red(),
    )
    notes = []
    if spend_void:
        notes.append(f"Void Point: +1k1 ({c.current_void_points} VP left)")
    if wound_pen:
        notes.append(f"Wound penalty: {wound_pen}")
    roll_desc = (
        f"Willpower {willpower} → {rolled}k{kept}\n"
        f"Roll **{total}** vs TN **{tn}**"
        f": {'**RESISTED** (spell has no effect)' if success else '**FAILED** (spell takes effect)'}"
    )
    embed.add_field(name="Resistance Roll", value=roll_desc, inline=False)
    if notes:
        embed.add_field(name="Modifiers", value=" · ".join(notes), inline=False)
    embed.add_field(
        name="Rule",
        value="L5R 4e: target rolls raw Willpower (a Trait Roll: no skill, dice explode) vs the spell's TN.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)

@spell_group.command(name="interrupt", description="Willpower check when a caster is hit mid-cast. Disrupted = slot refunded. [Fortune]")
@app_commands.describe(
    caster="Character being interrupted.",
    element="Element of the spell being cast (for slot refund if disrupted).",
    damage="Damage taken (0 = mere distraction, TN 10; >0 = TN 5 + damage).",
    void_bonus="Refund goes to the Void bonus pool instead of the element pool.",
)
@app_commands.autocomplete(caster=_any_character_autocomplete)
async def spell_interrupt(
    interaction: discord.Interaction,
    caster: str,
    element: str,
    damage: int = 0,
    void_bonus: bool = False,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _find_any_character(guild, caster)
    if rec is None:
        await interaction.response.send_message(f"No character named **{caster}**.", ephemeral=True)
        return
    c = rec.character
    tn = (5 + damage) if damage > 0 else 10
    willpower = c.willpower
    wound_pen = stats.wound_penalty(c)
    result = engine.roll_and_keep(max(1, willpower), max(1, willpower))
    total = result.total + wound_pen
    success = total >= tn
    embed = discord.Embed(
        title=f"⚡ {c.name}: Casting Interrupted",
        color=discord.Color.green() if success else discord.Color.orange(),
    )
    tn_reason = f"TN {tn} (5 + {damage} damage)" if damage > 0 else "TN 10 (distraction)"
    roll_desc = (
        f"Willpower {willpower}k{willpower} = **{total}** vs {tn_reason}\n"
    )
    if success:
        roll_desc += "**MAINTAINED**: spell continues normally."
    else:
        roll_desc += "**DISRUPTED**: spell fails, but spell slot is refunded."
        elem = element.lower().strip()
        if void_bonus:
            c.void_spell_bonus = min(c.void_spell_bonus + 1, stats.void_bonus_max(c))
            roll_desc += f"\nVoid bonus slot refunded ({c.void_spell_bonus}/{stats.void_bonus_max(c)})."
        elif elem in c.spell_slots:
            c.spell_slots[elem] = min(c.spell_slots[elem] + 1, stats.spell_slot_max(c, elem))
            roll_desc += f"\n{elem.title()} slot refunded ({c.spell_slots[elem]}/{stats.spell_slot_max(c, elem)})."
        store.save(rec)
    embed.add_field(name="Willpower Check", value=roll_desc, inline=False)
    notes = []
    if wound_pen:
        notes.append(f"Wound penalty: {wound_pen}")
    if notes:
        embed.add_field(name="Modifiers", value=" · ".join(notes), inline=False)
    embed.add_field(
        name="Rule",
        value="L5R 4e: interrupted caster rolls Willpower vs TN 10 (distraction) or TN 5 + damage. "
              "Failure = spell disrupted but slot not consumed.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)

@spell_group.command(name="importune", description="Entreat the kami for a spell you don't have: Spellcraft/Ring, then cast at higher TN.")
@app_commands.describe(
    name="Spell name (auto-complete from the catalog).",
    raises="Called raises on the casting roll (not the Spellcraft check).",
    spend_void="Spend a Void Point for +1k1 on the casting roll.",
    attacker_npc="Importune as a stored NPC [Fortune]",
    member="Importune as another player's character [Fortune]",
)
@app_commands.autocomplete(name=_spell_autocomplete)
async def spell_importune(
    interaction: discord.Interaction,
    name: str,
    raises: int = 0,
    spend_void: bool = False,
    attacker_npc: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    s = spells.get(name)
    if s is None:
        await interaction.response.send_message(f"No spell named **{name}**. Try `/spell search`.", ephemeral=True)
        return
    # Resolve caster (same logic as /spell cast).
    if attacker_npc:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_name(guild, NPC_OWNER, attacker_npc)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{attacker_npc}**.", ephemeral=True)
            return
    elif member is not None and member.id != interaction.user.id:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
            return
    caster = rec.character
    if await _refuse_if_cannot_act(interaction, caster):
        return
    if raises < 0 or raises > combat.max_raises(caster):
        await interaction.response.send_message(
            f"Too many Raises: {raises} called but the maximum per roll is the Void Ring, "
            f"**{combat.max_raises(caster)}**.", ephemeral=True,
        )
        return
    element = s["element"].lower()
    ring_val = stats.ring_value(caster, element)
    ml = s["mastery"]
    affinity = caster.affinity_element.lower() == element if caster.affinity_element else False
    deficiency = caster.deficiency_element.lower() == element if caster.deficiency_element else False
    effective_rank = caster.school_rank + (1 if affinity else 0) + (-1 if deficiency else 0)
    if effective_rank <= 0:
        await interaction.response.send_message(
            f"**{caster.name}** cannot cast {element.title()} spells (Deficiency reduces effective rank to 0).",
            ephemeral=True,
        )
        return
    if ml > effective_rank:
        await interaction.response.send_message(
            f"**{caster.name}** cannot importune a Mastery {ml} spell: "
            f"effective School Rank is only {effective_rank}.",
            ephemeral=True,
        )
        return
    wound_pen = stats.wound_penalty(caster)
    # Step 1: Spellcraft (Importune) / Ring check.
    spellcraft_rank = caster.skills.get("Spellcraft", 0)
    has_importune = "Importune" in caster.emphases.get("Spellcraft", [])
    importune_bonus = 1 if has_importune else 0
    imp_rolled = ring_val + spellcraft_rank + importune_bonus
    imp_kept = ring_val
    imp_tn = 15 + 5 * ml
    imp_result = engine.roll_and_keep(max(1, imp_rolled), max(1, imp_kept))
    imp_total = imp_result.total + wound_pen
    imp_success = imp_total >= imp_tn
    embed = discord.Embed(
        title=f"🙏 {caster.name} importunes for {s['name']}",
        color=discord.Color.purple(),
    )
    imp_notes = f"Spellcraft {spellcraft_rank}"
    if has_importune:
        imp_notes += " (Importune emphasis: +1k0)"
    imp_notes += f" / {s['element']} Ring {ring_val}"
    imp_desc = (
        f"{imp_notes} → {imp_rolled}k{imp_kept}\n"
        f"Roll **{imp_total}** vs TN **{imp_tn}**"
        f": {'**KAMI AGREE**' if imp_success else '**KAMI REFUSE**'}"
    )
    if wound_pen:
        imp_desc += f" (wound penalty: {wound_pen})"
    embed.add_field(name="Step 1: Spellcraft (Importune)", value=imp_desc, inline=False)
    embed.add_field(
        name="Prerequisite",
        value=f"Requires successful Commune cast + {ml * 5} minutes of communion.",
        inline=False,
    )
    if not imp_success:
        embed.set_footer(text="The kami will not grant this prayer.")
        await interaction.response.send_message(embed=embed)
        return
    # Step 2: Casting roll at importune TN (15 + 5×ML, not the normal 5 + 5×ML).
    # Spell slot check with Void bonus fallback.
    used_bonus_slot = False
    slot_remaining = caster.spell_slots.get(element)
    if slot_remaining is not None and slot_remaining <= 0:
        if caster.void_spell_bonus > 0:
            used_bonus_slot = True
        else:
            slot_max = stats.spell_slot_max(caster, element)
            bonus_max = stats.void_bonus_max(caster)
            embed.add_field(
                name="Step 2: Casting",
                value=f"No {element.title()} slots (0/{slot_max}) or bonus slots (0/{bonus_max}): cannot attempt the cast.",
                inline=False,
            )
            await interaction.response.send_message(embed=embed)
            return
    extra_rolled = 0
    extra_kept = 0
    if spend_void:
        ok, reason_block = advantage_effects.can_spend_void_on_roll(caster)
        if not ok:
            embed.add_field(name="Step 2: Casting", value=f"🌀 {reason_block}", inline=False)
            await interaction.response.send_message(embed=embed)
            return
        if caster.current_void_points <= 0:
            embed.add_field(name="Step 2: Casting", value="No Void Points remaining: cannot spend VP.", inline=False)
            await interaction.response.send_message(embed=embed)
            return
        caster.current_void_points -= 1
        _tally(interaction.channel_id, caster.name, "void")
        extra_rolled = extra_kept = 1
    cast_rolled = ring_val + effective_rank + extra_rolled
    cast_kept = ring_val + extra_kept
    cast_base_tn = 15 + 5 * ml
    cast_tn = cast_base_tn + raises * 5
    cast_result = engine.roll_and_keep(max(1, cast_rolled), max(1, cast_kept))
    cast_total = cast_result.total + wound_pen
    cast_success = cast_total >= cast_tn
    # Consume slot (pass or fail).
    if used_bonus_slot:
        caster.void_spell_bonus = max(0, caster.void_spell_bonus - 1)
    elif element in caster.spell_slots:
        caster.spell_slots[element] = max(0, caster.spell_slots[element] - 1)
    store.save(rec)
    cast_notes = []
    if spend_void:
        cast_notes.append(f"VP: +1k1 ({caster.current_void_points} left)")
    if used_bonus_slot:
        cast_notes.append(f"Void bonus slot used ({caster.void_spell_bonus}/{stats.void_bonus_max(caster)})")
    elif element in caster.spell_slots:
        cast_notes.append(f"{element.title()} slots: {caster.spell_slots[element]}/{stats.spell_slot_max(caster, element)}")
    cast_desc = (
        f"Ring {ring_val} + School Rank {effective_rank} → {cast_rolled}k{cast_kept}\n"
        f"Roll **{cast_total}** vs TN **{cast_tn}** (importune TN: 15 + {ml}×5"
        + (f" + {raises}×5 raises" if raises else "") + ")\n"
        f"{'**SUCCESS**:the kami grant the spell!' if cast_success else '**FAILED** (slot consumed)'}"
    )
    if cast_notes:
        cast_desc += "\n" + " · ".join(cast_notes)
    embed.add_field(name="Step 2: Casting Roll", value=cast_desc, inline=False)
    if cast_success:
        casting_time = max(1, ml - raises) if raises else ml
        spell_info = f"**Mastery {ml}** · Range: {s['range']} · Duration: {s['duration']}"
        if casting_time > 1:
            spell_info += f"\n⏱️ **{casting_time} Complex Actions** to complete"
        embed.add_field(name="Spell", value=spell_info, inline=False)
        if s.get("effect"):
            embed.add_field(name="Effect", value=s["effect"][:1024], inline=False)
    embed.color = discord.Color.gold() if cast_success else discord.Color.greyple()
    await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 42: Taint Progression (#14)
# ---------------------------------------------------------------------------

@dm.command(name="taint", description="View or modify a character's Shadowlands Taint [Fortune]")
@app_commands.describe(
    name="Character name.",
    add="Taint points to add (can be negative to remove).",
    member="Player whose character to check (omit for caller's).",
    is_npc="Target is an NPC.",
)
async def taint_command(
    interaction: discord.Interaction,
    name: str | None = None,
    add: float | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if add is not None and not _is_dm(interaction):
        await interaction.response.send_message(f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to modify Taint.", ephemeral=True)
        return
    if is_npc and name:
        rec = store.get_by_name(guild, NPC_OWNER, name)
    elif member is not None:
        rec = store.get_active(guild, str(member.id))
    elif name:
        rec = store.get_by_name(guild, NPC_OWNER, name)
        if rec is None:
            rec = store.get_active(guild, str(interaction.user.id))
    else:
        rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("Character not found.", ephemeral=True)
        return
    c = rec.character
    if add is not None:
        old_taint = c.taint
        c.taint = max(0.0, c.taint + add * 0.1)
        store.save(rec, note="Taint change")
        crossing = taint.check_threshold_crossing(old_taint, c.taint, c)
        embed = discord.Embed(title=f"Taint: {c.name}", color=discord.Color.dark_purple())
        embed.add_field(name="Taint", value=f"{old_taint:g} → **{c.taint:g}**", inline=True)
        embed.add_field(name="Taint Rank", value=f"**{taint.taint_rank(c)}**", inline=True)
        embed.add_field(name="Earth Ring", value=str(stats.earth_ring(c)), inline=True)
        if crossing:
            embed.add_field(name="Rank Crossed!", value=crossing["description"], inline=False)
            if "mutation" in crossing:
                embed.add_field(name="Mutation", value=crossing["mutation"], inline=False)
            if "madness" in crossing:
                embed.add_field(name="Madness", value=crossing["madness"], inline=False)
            if crossing["is_lost"]:
                embed.add_field(name="LOST TO THE TAINT", value="Character becomes an NPC.", inline=False)
        await interaction.response.send_message(embed=embed)
    else:
        rank = taint.taint_rank(c)
        embed = discord.Embed(title=f"Taint: {c.name}", color=discord.Color.dark_purple())
        embed.add_field(name="Taint", value=f"**{c.taint:g}**", inline=True)
        embed.add_field(name="Taint Rank", value=f"**{rank}**", inline=True)
        embed.add_field(name="Earth Ring", value=str(stats.earth_ring(c)), inline=True)
        embed.add_field(name="Status", value=taint.taint_description(rank), inline=False)
        if taint.social_penalty(c):
            embed.add_field(name="Social Penalty", value=f"-{taint.social_penalty(c)}k0 to Social Skill rolls", inline=True)
        if rank >= 4:
            embed.add_field(name="Void Points", value=f"maximum -1 → {taint.void_point_cap(c)}", inline=True)
        interval = taint.periodic_roll_interval(rank)
        if c.taint > 0 and interval is not None:
            due = max(0, interval - c.taint_days_since_roll)
            tea = " · Jade Petal Tea +2k2" if taint.has_jade_petal_tea(c) else ""
            embed.add_field(
                name="Resistance Roll",
                value=f"Earth {stats.earth_ring(c)}k{stats.earth_ring(c)} vs TN {taint.periodic_roll_tn(rank)} "
                      f"every {interval} day(s) — next in {due} day(s) (via /dm new_day){tea}",
                inline=False,
            )
        await interaction.response.send_message(embed=embed, ephemeral=True)

# ---------------------------------------------------------------------------
# Phase 42: Crafting Extended (#6)
# ---------------------------------------------------------------------------

@dm.command(name="craft_extended", description="Extended crafting roll: cumulative multi-step project [Fortune]")
@app_commands.describe(
    name="Character name.",
    skill="Craft/Artisan skill name.",
    tn="Cumulative TN to complete the project.",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus (tools, workshop, etc.).",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Spend a Void Point to treat Skill 0 as 1 (removes unskilled penalty).",
    reason="Label (e.g. 'forging a katana').",
)
@app_commands.autocomplete(skill=_skill_autocomplete)
async def craft_extended(
    interaction: discord.Interaction,
    name: str,
    skill: str,
    tn: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: int = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    reason: str = "",
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"Character **{name}** not found.", ephemeral=True)
        return
    c = rec.character
    if await _refuse_if_cannot_act(interaction, c):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    skill_rank = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, skill, "intelligence")
    void_r = void_k = 0
    void_line = ""
    void_spent = False
    if spend_void:
        ok, reason_block = advantage_effects.can_spend_void_on_roll(c, skill_name=skill)
        if not ok:
            void_line = f"🌀 {reason_block}"
        elif c.current_void_points <= 0:
            void_line = f"🌀 no Void Points to spend (0/{c.max_void_points})"
        else:
            c.current_void_points -= 1
            void_r = void_k = 1
            void_spent = True
            void_line = f"🌀 Void +1k1 ({c.current_void_points} VP left)"
    if void_unskilled and not spend_void:
        if skill_rank > 0:
            void_line = f"🌀 Already has {skill} {skill_rank} — use spend_void for +1k1 instead"
        else:
            ok, reason_block = advantage_effects.can_spend_void_on_roll(c, skill_name=skill)
            if not ok:
                void_line = f"🌀 {reason_block}"
            elif c.current_void_points <= 0:
                void_line = f"🌀 no Void Points to spend (0/{c.max_void_points})"
            else:
                c.current_void_points -= 1
                skill_rank = 1
                void_spent = True
                void_line = f"🌀 Void: Skill 0→1 (unskilled penalty removed, {c.current_void_points} VP left)"
    result = combat.resolve_skill_check(c.intelligence, skill_rank, 10, engine, bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k)
    if void_spent:
        store.save(rec)
    embed = discord.Embed(
        title=reason or f"Extended Crafting: {skill}",
        color=discord.Color.teal(),
    )
    embed.add_field(name="Craftsman", value=c.name, inline=True)
    roll_text = f"({result['rolled']}k{result['kept']}) = **{result['total']}**"
    if void_line:
        roll_text += f"\n{void_line}"
    embed.add_field(name="Roll", value=roll_text, inline=True)
    embed.add_field(name="Progress", value=f"+{result['total']} toward TN **{tn}**", inline=False)
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    quality_thresholds = [
        (tn * 2, "Exceptional Quality (+1k0 relevant rolls)"),
        (int(tn * 1.5), "Fine Quality (+0k1 relevant rolls)"),
        (tn, "Standard Quality"),
    ]
    quality_lines = [f"TN {t}: {desc}" for t, desc in quality_thresholds]
    embed.add_field(name="Quality Tiers (cumulative total)", value="\n".join(quality_lines), inline=False)
    if adv_notes:
        embed.add_field(name="Advantages/Disadvantages", value="\n".join(adv_notes), inline=False)
    embed.set_footer(text="DM: track cumulative total across rolls. Each roll = one crafting period.")
    await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 42: Spell Damage (#8 partial)
# ---------------------------------------------------------------------------

@spell_group.command(name="damage", description="Roll spell damage dice (for offensive spells). [Fortune]")
@app_commands.describe(
    rolled="Number of dice to roll (from spell description, e.g. Fire Ring for Fires of Purity).",
    kept="Number of dice to keep.",
    bonus="Flat damage bonus.",
    target="Target character name (shows DM-approval buttons to apply).",
    reason="Spell name or label.",
    caster="The caster (a combatant here): credits the damage and any kill in the fight summary.",
)
@app_commands.autocomplete(caster=cog_combat._combatant_autocomplete)
async def spell_damage(
    interaction: discord.Interaction,
    rolled: app_commands.Range[int, 1, 30],
    kept: app_commands.Range[int, 1, 15],
    bonus: int = 0,
    target: str | None = None,
    reason: str = "",
    caster: str | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    result = engine.roll_and_keep(rolled, kept)
    total = result.total + bonus
    embed = discord.Embed(
        title=reason or "Spell Damage",
        color=discord.Color.dark_magenta(),
    )
    embed.add_field(name="Damage Roll", value=f"({rolled}k{kept}{f'+{bonus}' if bonus else ''}) = **{total}**", inline=False)
    embed.add_field(name="Dice", value=_format_dice(result), inline=False)
    if target:
        guild = str(interaction.guild_id)
        rec = _find_any_character(guild, target)
        if rec:
            red = rec.character.armor_reduction
            wl = stats.wound_level_name(rec.character)
            embed.add_field(
                name=f"Target: {rec.character.name}",
                value=f"Reduction {red} · Current: **{wl}** ({rec.character.wounds_taken} wounds)",
                inline=False,
            )
            approval_ch_id = store.get_damage_approval_channel(guild) or store.get_approval_channel(guild)
            approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
            src_ch_id = interaction.channel_id if approval_ch else 0
            view = SpellDamageView(
                target_id=rec.id, target_name=rec.character.name,
                raw_damage=total, dice_text=_format_dice(result),
                reason=reason, rolled=rolled, kept=kept, bonus=bonus,
                source_channel_id=src_ch_id, caster_name=(caster or "").strip(),
            )
            owner_ping = f" <@{rec.owner_id}>" if rec.owner_id != NPC_OWNER else ""
            if approval_ch:
                embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
                embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
                await view.persist(await approval_ch.send(content=f"{_dm_ping(interaction.guild)}A DM can authorize the spell damage below.", embed=embed, view=view, allowed_mentions=_PING_MENTIONS))
                await interaction.response.send_message(
                    f"📜 Spell damage on **{rec.character.name}** — approval routed to the DM channel.{owner_ping}"
                )
            else:
                await interaction.response.send_message(
                    content=f"{_dm_ping(interaction.guild)}A DM can authorize the spell damage below.{owner_ping}",
                    embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
                )
                await view.persist(await interaction.original_response())
        else:
            embed.set_footer(text=f"Target '{target}' not found: use exact character name.")
            await interaction.response.send_message(embed=embed)
    else:
        embed.set_footer(text="Add target: to route damage through the DM-approval gate.")
        await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 42: Courtier/Social Influence (#5)
# ---------------------------------------------------------------------------

@dm.command(name="influence", description="Track Influence Points during a court scene. [Fortune]")
@app_commands.describe(
    name="Character name.",
    change="Influence points to add (negative to subtract).",
    reason="Why the influence changed.",
)
async def influence_track(
    interaction: discord.Interaction,
    name: str,
    change: int,
    reason: str = "",
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    embed = discord.Embed(title="Court Influence", color=discord.Color.purple())
    sign = "+" if change >= 0 else ""
    embed.add_field(name=name, value=f"{sign}{change} Influence" + (f": {reason}" if reason else ""), inline=False)
    embed.set_footer(text="DM: track cumulative influence totals for the court scene. Use /social for Courtier/Etiquette checks.")
    await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 47: Medicine Treatment (wound healing with DM gate)
# ---------------------------------------------------------------------------

class MedicineTreatView(_DisableableView):
    """DM-approval gate for medicine treatment healing."""

    KIND = "medicine_treat"

    def __init__(
        self, healer_name: str, target_id: int, target_name: str,
        wounds_healed: int, treatment_type: str, roll_result: dict,
        source_channel_id: int = 0,
    ) -> None:
        super().__init__(timeout=1800)
        self.healer_name = healer_name
        self.target_id = target_id
        self.target_name = target_name
        self.wounds_healed = wounds_healed
        self.treatment_type = treatment_type
        self.roll_result = roll_result
        self.source_channel_id = source_channel_id

    @discord.ui.button(label="Apply Healing", style=discord.ButtonStyle.success, emoji="💚")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        c = rec.character
        if stats.is_dead(c):
            self._disable()
            await interaction.response.edit_message(view=self)
            await interaction.followup.send(f"**{c.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        old_level = stats.wound_level_name(c)
        old_wounds = c.wounds_taken
        c.wounds_taken = max(0, c.wounds_taken - self.wounds_healed)
        store.save(rec, note="Medicine treatment")
        _tally(self.source_channel_id or interaction.channel_id, c.name, "healed", old_wounds - c.wounds_taken)
        new_level = stats.wound_level_name(c)
        embed = discord.Embed(title="💚 Treatment Applied", color=discord.Color.green())
        crossed = f" ({old_level} → **{new_level}**)" if old_level != new_level else ""
        embed.add_field(
            name="Result",
            value=(
                f"**{self.healer_name}** treats **{self.target_name}** ({self.treatment_type})\n"
                f"Healed **{self.wounds_healed}** wounds → {c.wounds_taken} remaining{crossed}"
            ),
            inline=False,
        )
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(embed=embed)
            await interaction.followup.send(f"Resolved in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(embed=embed)
        await _combat_log(
            str(interaction.guild_id),
            f"Medicine: {self.healer_name} treats {self.target_name} ({self.treatment_type}) "
            f"{self.wounds_healed} wounds healed [{new_level}]",
        )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        msg = (
            f"🛡️ {interaction.user.display_name} denied: "
            f"no healing applied to **{self.target_name}**."
        )
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = client.get_channel(self.source_channel_id)
            if src:
                await src.send(msg)
            await interaction.followup.send(f"Denied — posted in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(msg)

MEDICINE_TN = {
    "wound_treatment": 15,
    "disease_diagnosis": 15,
    "poison_treatment": 20,
    "antidote_preparation": 20,
}

@dm.command(name="xp_log_channel", description="Set (or clear) the Kami-only channel logging XP grants and spends [Kami]")
@app_commands.describe(channel="The Kami-only text channel. Omit to stop logging XP.")
async def dm_xp_log_channel(interaction: discord.Interaction, channel: discord.TextChannel | None = None) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can set the XP log channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if channel is None:
        store.clear_xp_log_channel(guild)
        await interaction.response.send_message("XP logging stopped.", ephemeral=True)
        return
    store.set_xp_log_channel(guild, str(channel.id))
    await interaction.response.send_message(
        f"XP log channel set to {channel.mention}: every `/xp grant` and every XP spend is recorded there. "
        f"Make sure only **{ROLE_KAMI}** can see that channel.", ephemeral=True,
    )

@dm.command(name="log_channel", description="Set the channel where combat events are logged [Kami]")
@app_commands.describe(channel="The text channel to post combat log entries to.")
async def dm_log_channel(
    interaction: discord.Interaction,
    channel: discord.TextChannel,
) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can set the combat log channel.", ephemeral=True)
        return
    store.set_log_channel(str(interaction.guild_id), str(channel.id))
    await interaction.response.send_message(
        f"Combat log channel set to {channel.mention}. "
        f"Attack outcomes, damage, healing, turn advances, and other combat events "
        f"will be logged there automatically."
    )

@dm.command(name="clear_log", description="Stop logging combat events [Kami]")
async def dm_clear_log(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the combat log channel.", ephemeral=True)
        return
    store.clear_log_channel(str(interaction.guild_id))
    await interaction.response.send_message("Combat log channel cleared. Events will no longer be logged.", ephemeral=True)

@dm.command(name="date_channel", description="Set the channel for the pinned date display [Kami]")
@app_commands.describe(channel="The text channel where the date will be pinned and updated.")
async def dm_date_channel(
    interaction: discord.Interaction,
    channel: discord.TextChannel,
) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can set the date channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    cal = store.get_calendar(guild)
    if cal is None:
        await interaction.response.send_message(
            "Set the date first with `/dm setdate` before choosing a date channel.", ephemeral=True
        )
        return
    await interaction.response.defer(ephemeral=True)
    date_str = _format_rokugani_date(*cal)
    msg = await channel.send(embed=_date_embed(date_str))
    await msg.pin()
    store.set_date_channel(guild, str(channel.id), str(msg.id))
    await interaction.followup.send(
        f"Date channel set to {channel.mention}. The current date is pinned there and "
        f"will update automatically when time advances."
    )

@dm.command(name="clear_date_channel", description="Stop updating the date display channel [Kami]")
async def dm_clear_date_channel(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the date channel.", ephemeral=True)
        return
    store.clear_date_channel(str(interaction.guild_id))
    await interaction.response.send_message("Date channel cleared. The pinned message will no longer update.", ephemeral=True)

@dm.command(name="approval_channel", description="Set the channel for character submission approvals [Kami]")
@app_commands.describe(channel="The DM-only text channel for character submissions.")
async def dm_approval_channel(
    interaction: discord.Interaction,
    channel: discord.TextChannel,
) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can set the approval channel.", ephemeral=True)
        return
    store.set_approval_channel(str(interaction.guild_id), str(channel.id))
    await interaction.response.send_message(
        f"Character approval channel set to {channel.mention}. "
        f"Character submissions will be routed there for DM review."
    )

@dm.command(name="clear_approval", description="Stop routing character approvals to a DM channel [Kami]")
async def dm_clear_approval(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the approval channel.", ephemeral=True)
        return
    store.clear_approval_channel(str(interaction.guild_id))
    await interaction.response.send_message("Character approval channel cleared.", ephemeral=True)

@dm.command(name="damage_channel", description="Set the channel for damage/healing approvals [Kami]")
@app_commands.describe(channel="The DM-only text channel for damage approval requests.")
async def dm_damage_channel(
    interaction: discord.Interaction,
    channel: discord.TextChannel,
) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can set the damage approval channel.", ephemeral=True)
        return
    store.set_damage_approval_channel(str(interaction.guild_id), str(channel.id))
    await interaction.response.send_message(
        f"Damage approval channel set to {channel.mention}. "
        f"Damage, healing, and spell approvals will be routed there for DM review. "
        f"Results will be posted back in the combat room."
    )

@dm.command(name="clear_damage_channel", description="Stop routing damage approvals to a separate channel [Kami]")
async def dm_clear_damage_channel(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the damage approval channel.", ephemeral=True)
        return
    store.clear_damage_approval_channel(str(interaction.guild_id))
    await interaction.response.send_message("Damage approval channel cleared. Damage approvals will fall back to the character approval channel.", ephemeral=True)

@dm.command(name="treat", description="Medicine treatment: healer rolls, DM approves (L5R 4e).")
@app_commands.describe(
    healer="Character performing the treatment.",
    patient="Character being treated.",
    treatment="Type of medical treatment.",
    wounds_healed="Wounds healed on success (default: healer's Intelligence x 2).",
    tn_override="Custom TN (overrides default for the treatment type).",
    bonus="Flat bonus (tools, emphasis, etc.).",
)
@app_commands.autocomplete(healer=_any_character_autocomplete, patient=_any_character_autocomplete)
@app_commands.choices(treatment=[
    app_commands.Choice(name="Wound Treatment (TN 15)", value="wound_treatment"),
    app_commands.Choice(name="Disease Diagnosis (TN 15)", value="disease_diagnosis"),
    app_commands.Choice(name="Poison Treatment (TN 20)", value="poison_treatment"),
    app_commands.Choice(name="Antidote Preparation (TN 20)", value="antidote_preparation"),
])
async def dm_treat(
    interaction: discord.Interaction,
    healer: str,
    patient: str,
    treatment: app_commands.Choice[str],
    wounds_healed: app_commands.Range[int, 0, 999] | None = None,
    tn_override: app_commands.Range[int, 1, 100] | None = None,
    bonus: app_commands.Range[int, -50, 50] = 0,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    healer_rec = _find_any_character(guild, healer)
    if healer_rec is None:
        await interaction.response.send_message(f"No character named **{healer}**.", ephemeral=True)
        return
    patient_rec = _find_any_character(guild, patient)
    if patient_rec is None:
        await interaction.response.send_message(f"No character named **{patient}**.", ephemeral=True)
        return
    hc = healer_rec.character
    pc = patient_rec.character
    if await _refuse_if_cannot_act(interaction, hc):
        return
    if stats.is_dead(pc):
        await interaction.response.send_message(f"**{pc.name}** is dead. PC death is permanent.", ephemeral=True)
        return
    tn = tn_override if tn_override is not None else MEDICINE_TN.get(treatment.value, 15)
    medicine_skill = hc.skills.get("Medicine", 0)
    wp = stats.wound_penalty(hc)
    result = combat.resolve_medicine_check(hc.intelligence, medicine_skill, tn, engine, bonus=bonus + wp)
    success = result["success"]
    heal_amount = wounds_healed if wounds_healed is not None else hc.intelligence * 2
    treat_label = treatment.name.split(" (")[0]
    embed = discord.Embed(
        title=f"💊 {treat_label}: {hc.name} treats {pc.name}",
        color=discord.Color.green() if success else discord.Color.greyple(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    skill_label = f"Medicine {medicine_skill}" if medicine_skill > 0 else "Medicine (unskilled)"
    embed.add_field(
        name="Roll",
        value=(
            f"{skill_label}/Intelligence ({result['rolled']}k{result['kept']}"
            f"{wp_str}{bonus_str}) vs TN **{tn}**"
        ),
        inline=False,
    )
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    verdict = "✅ **Treatment successful!**" if success else "❌ **Treatment fails.**"
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    if success and heal_amount > 0 and pc.wounds_taken > 0:
        effective_heal = min(heal_amount, pc.wounds_taken)
        embed.add_field(
            name="Healing",
            value=f"**{effective_heal}** wounds to heal (Intelligence {hc.intelligence} × 2 = {hc.intelligence * 2})",
            inline=False,
        )
        approval_ch_id = store.get_damage_approval_channel(guild) or store.get_approval_channel(guild)
        approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
        src_ch_id = interaction.channel_id if approval_ch else 0
        view = MedicineTreatView(
            healer_name=hc.name, target_id=patient_rec.id, target_name=pc.name,
            wounds_healed=effective_heal, treatment_type=treat_label, roll_result=result,
            source_channel_id=src_ch_id,
        )
        owner_ping = f" <@{patient_rec.owner_id}>" if patient_rec.owner_id != NPC_OWNER else ""
        if approval_ch:
            embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
            embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
            await view.persist(await approval_ch.send(
                content=f"{_dm_ping(interaction.guild)}Treatment succeeded. A DM can authorize the healing below.",
                embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
            ))
            await interaction.response.send_message(
                f"💊 Treatment on **{pc.name}** succeeded — healing approval routed to the DM channel.{owner_ping}"
            )
        else:
            await interaction.response.send_message(
                content=f"{_dm_ping(interaction.guild)}Treatment succeeded. A DM can authorize the healing below.{owner_ping}",
                embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
            )
            await view.persist(await interaction.original_response())
    elif success:
        if pc.wounds_taken <= 0:
            embed.add_field(name="Note", value=f"**{pc.name}** has no wounds to heal.", inline=False)
        await interaction.response.send_message(embed=embed)
    else:
        embed.set_footer(text="L5R 4e: a failed Medicine check cannot be re-attempted on the same patient until the next day.")
        await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 47: Character Import/Export
# ---------------------------------------------------------------------------

@sheet_data.command(name="export", description="Export your active character sheet as JSON (for backup or sharing).")
@app_commands.describe(
    member="Export another player's character [Fortune]",
)
async def sheet_export(
    interaction: discord.Interaction,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    data = c.to_dict()
    import json as _json
    payload = _json.dumps(data, indent=2, ensure_ascii=False)
    if len(payload) <= 1900:
        await interaction.response.send_message(
            f"**{c.name}**: character sheet JSON:\n```json\n{payload}\n```",
            ephemeral=True,
        )
    else:
        import io
        buf = io.BytesIO(payload.encode("utf-8"))
        fname = c.name.lower().replace(" ", "_").replace("'", "") + ".json"
        file = discord.File(buf, filename=fname)
        await interaction.response.send_message(
            content=f"**{c.name}**: character sheet exported.",
            file=file,
            ephemeral=True,
        )

@sheet_data.command(name="import", description="Import a character from JSON (paste the JSON or attach a .json file). [Fortune]")
@app_commands.describe(
    json_data="Paste the character JSON here (or attach a .json file instead).",
)
async def sheet_import(
    interaction: discord.Interaction,
    json_data: str | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    owner = str(interaction.user.id)
    import json as _json

    raw: str | None = json_data
    if raw is None or raw.strip() == "":
        await interaction.response.send_message(
            "Paste your character JSON in the `json_data` parameter. "
            "Get it from `/sheet data export`.",
            ephemeral=True,
        )
        return
    try:
        data = _json.loads(raw)
    except _json.JSONDecodeError as exc:
        await interaction.response.send_message(f"Invalid JSON: {exc}", ephemeral=True)
        return
    if not isinstance(data, dict):
        await interaction.response.send_message("JSON must be an object (dictionary).", ephemeral=True)
        return
    if "name" not in data or not data["name"]:
        await interaction.response.send_message("JSON must include a `name` field.", ephemeral=True)
        return
    try:
        char = Character.from_dict(data)
    except Exception as exc:
        await interaction.response.send_message(f"Could not parse character: {exc}", ephemeral=True)
        return
    try:
        rec = store.create_character(guild, owner, char)
    except storage.DuplicateNameError:
        await interaction.response.send_message(
            f"You already have a character named **{char.name}**. "
            "Rename or delete the existing one first.",
            ephemeral=True,
        )
        return
    store.set_active(guild, owner, rec.id)
    embed = build_sheet_embed(rec)
    await interaction.response.send_message(
        f"✅ Imported **{char.name}** and set as your active character.",
        embed=embed,
    )

# ===========================================================================
# /macro: saved rolls
# ===========================================================================

macro_group = app_commands.Group(name="macro", description="Save and use frequently-rolled dice pools.")

async def _macro_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    macros = store.list_macros(str(interaction.guild_id), str(interaction.user.id))
    cur = current.lower().strip()
    return [
        app_commands.Choice(name=m.name, value=m.name)
        for m in macros if cur in m.name.lower()
    ][:25]

@macro_group.command(name="save", description="Save a roll macro (e.g. /macro save name:attack rolled:7 kept:3 modifier:5).")
@app_commands.describe(
    name="Short name for this macro (e.g. 'attack', 'stealth').",
    rolled="Number of dice rolled.",
    kept="Number of dice kept.",
    modifier="Flat modifier to add (default 0).",
    label="Optional description (e.g. 'Kenjutsu / Agility').",
)
async def macro_save(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 30],
    rolled: app_commands.Range[int, 1, 20],
    kept: app_commands.Range[int, 1, 20],
    modifier: int = 0,
    label: str = "",
) -> None:
    if not await _require_guild(interaction):
        return
    rec = store.save_macro(
        str(interaction.guild_id), str(interaction.user.id),
        name, rolled, kept, modifier, label,
    )
    mod_str = f"+{modifier}" if modifier > 0 else (str(modifier) if modifier < 0 else "")
    await interaction.response.send_message(
        f"💾 Saved macro **{rec.name}** → `{rolled}k{kept}{mod_str}`"
        + (f" ({label})" if label else ""),
        ephemeral=True,
    )

@macro_group.command(name="list", description="List your saved macros.")
async def macro_list(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    macros = store.list_macros(str(interaction.guild_id), str(interaction.user.id))
    if not macros:
        await interaction.response.send_message(
            "No saved macros. Use `/macro save` to create one.", ephemeral=True
        )
        return
    lines = []
    for m in macros:
        mod_str = f"+{m.modifier}" if m.modifier > 0 else (str(m.modifier) if m.modifier < 0 else "")
        desc = f": {m.label}" if m.label else ""
        lines.append(f"• **{m.name}** → `{m.rolled}k{m.kept}{mod_str}`{desc}")
    await interaction.response.send_message(
        f"💾 **Your macros ({len(macros)}): **\n" + "\n".join(lines), ephemeral=True
    )

@macro_group.command(name="roll", description="Roll a saved macro.")
@app_commands.describe(name="Which macro to roll.")
@app_commands.autocomplete(name=_macro_autocomplete)
async def macro_roll(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    m = store.get_macro(str(interaction.guild_id), str(interaction.user.id), name)
    if m is None:
        await interaction.response.send_message(
            f"No macro named **{name}**. See `/macro list`.", ephemeral=True
        )
        return
    result = engine.roll_and_keep(m.rolled, m.kept)
    total = result.total + m.modifier
    mod_str = f"+{m.modifier}" if m.modifier > 0 else (str(m.modifier) if m.modifier < 0 else "")
    title = f"🎲 {m.name}" + (f": {m.label}" if m.label else "")
    embed = discord.Embed(title=title, color=discord.Color.teal())
    embed.add_field(
        name=f"{m.rolled}k{m.kept}{mod_str}",
        value=_format_dice(result) + (f"\n+{m.modifier} modifier = **{total}**" if m.modifier else ""),
        inline=False,
    )
    embed.set_footer(text=f"Total: {total}")
    _log_roll(interaction.channel_id, interaction.user.display_name, title, total)
    await interaction.response.send_message(embed=embed)

@macro_group.command(name="delete", description="Delete a saved macro.")
@app_commands.describe(name="Which macro to delete.")
@app_commands.autocomplete(name=_macro_autocomplete)
async def macro_delete(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    deleted = store.delete_macro(str(interaction.guild_id), str(interaction.user.id), name)
    if not deleted:
        await interaction.response.send_message(
            f"No macro named **{name}**. See `/macro list`.", ephemeral=True
        )
        return
    await interaction.response.send_message(f"🗑️ Deleted macro **{name}**.", ephemeral=True)

client.tree.add_command(macro_group)

# ===========================================================================
# /compare: side-by-side character comparison
# ===========================================================================

@client.tree.command(name="compare", description="Compare two characters side-by-side (yours, another player's, or an NPC).")
@app_commands.describe(
    name_a="First character name.",
    name_b="Second character name.",
    member_a="Owner of first character (omit for your own).",
    member_b="Owner of second character (omit for your own).",
)
async def compare_characters(
    interaction: discord.Interaction,
    name_a: str,
    name_b: str,
    member_a: discord.Member | None = None,
    member_b: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    owner_a = str(member_a.id) if member_a else str(interaction.user.id)
    owner_b = str(member_b.id) if member_b else str(interaction.user.id)

    rec_a = store.get_by_name(guild, owner_a, name_a)
    if rec_a is None:
        rec_a = store.get_by_name(guild, NPC_OWNER, name_a)
    rec_b = store.get_by_name(guild, owner_b, name_b)
    if rec_b is None:
        rec_b = store.get_by_name(guild, NPC_OWNER, name_b)

    if rec_a is None:
        await interaction.response.send_message(f"Character **{name_a}** not found.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"Character **{name_b}** not found.", ephemeral=True)
        return

    a, b = rec_a.character, rec_b.character
    rings_a, rings_b = stats.all_rings(a), stats.all_rings(b)

    def _delta(va: int, vb: int) -> str:
        d = va - vb
        if d > 0:
            return f" (+{d})"
        if d < 0:
            return f" ({d})"
        return ""

    trait_lines = []
    for t in ("stamina", "willpower", "strength", "perception", "agility", "intelligence", "reflexes", "awareness"):
        va, vb = a.get_trait(t), b.get_trait(t)
        trait_lines.append(f"{t.capitalize():12s}  **{va}**{_delta(va, vb):6s}  vs  **{vb}**")
    trait_lines.append(f"{'Void':12s}  **{a.void_ring}**{_delta(a.void_ring, b.void_ring):6s}  vs  **{b.void_ring}**")

    ring_lines = []
    for r in SPELL_ELEMENTS:
        va, vb = rings_a[r], rings_b[r]
        ring_lines.append(f"{r.capitalize():6s}  **{va}**{_delta(va, vb):6s}  vs  **{vb}**")

    ins_a, ins_b = stats.insight(a), stats.insight(b)
    ir_a, ir_b = stats.insight_rank(a), stats.insight_rank(b)
    atn_a = a.reflexes * 5 + 5 + a.armor_tn_bonus
    atn_b = b.reflexes * 5 + 5 + b.armor_tn_bonus

    embed = discord.Embed(
        title=f"⚖️ {a.name} vs {b.name}",
        color=discord.Color.blue(),
    )
    embed.add_field(
        name="Rings",
        value="\n".join(ring_lines),
        inline=False,
    )
    embed.add_field(
        name="Traits",
        value="\n".join(trait_lines),
        inline=False,
    )
    embed.add_field(
        name="Derived",
        value=(
            f"Insight: **{ins_a}** (R{ir_a}) vs **{ins_b}** (R{ir_b})\n"
            f"Armor TN: **{atn_a}** vs **{atn_b}**\n"
            f"Wounds: {a.wounds_taken}/{stats.total_wound_capacity(a)} "
            f"({stats.wound_level_name(a)}) vs "
            f"{b.wounds_taken}/{stats.total_wound_capacity(b)} "
            f"({stats.wound_level_name(b)})\n"
            f"Honor: {a.honor} vs {b.honor}"
        ),
        inline=False,
    )
    await interaction.response.send_message(embed=embed)

# ===========================================================================
# /history: recent roll log for this channel
# ===========================================================================

@client.tree.command(name="history", description="Show recent dice rolls in this channel.")
@app_commands.describe(count="How many entries to show (default 10, max 50).")
async def roll_history(
    interaction: discord.Interaction,
    count: app_commands.Range[int, 1, 50] = 10,
) -> None:
    entries = list(_roll_history.get(interaction.channel_id, []))
    if not entries:
        await interaction.response.send_message("No rolls recorded in this channel yet.", ephemeral=True)
        return
    recent = entries[-count:]
    recent.reverse()
    now = monotonic()
    lines = []
    for ts, user, desc, total in recent:
        ago = now - ts
        if ago < 60:
            time_str = f"{int(ago)}s ago"
        elif ago < 3600:
            time_str = f"{int(ago / 60)}m ago"
        else:
            time_str = f"{int(ago / 3600)}h ago"
        lines.append(f"• **{user}**: {desc} → **{total}** ({time_str})")
    await interaction.response.send_message(
        f"📜 **Recent rolls** (last {len(recent)}):\n" + "\n".join(lines),
        ephemeral=True,
    )

# ---------------------------------------------------------------------------
#  Server setup (Kami-only) & character submission
# ---------------------------------------------------------------------------

async def _cg_resume(interaction: discord.Interaction, state: dict) -> None:
    """Show the wizard's last step again on the message this interaction came from."""
    if interaction.message is not None:
        state["message_id"] = interaction.message.id
        state["channel_id"] = interaction.channel_id
    step = state.get("step", "clan")
    if step in ("clan", "family"):
        view = _WizardView(state)
        view.add_item(_ClanSelect(state, great=True))
        view.add_item(_ClanSelect(state, great=False))
        await interaction.response.edit_message(
            content=f"Resuming **{state.get('name', 'your character')}**.\n**Step 1/10**: Choose your Clan.",
            embed=_chargen_embed(state), view=view,
        )
        return
    handlers = {
        "heritage": _go_to_heritage_or_school, "school": _go_to_school_choice, "wildcards": _chargen_wildcards,
        "traits": _chargen_traits, "advantages": _chargen_advantages, "disadvantages": _chargen_disadvantages,
        "skills": _chargen_skills, "spells": _chargen_spells, "review": _chargen_review,
    }
    await handlers.get(step, _chargen_traits)(interaction, state)


async def _start_chargen_wizard(interaction: discord.Interaction) -> None:
    """Shared entry point: open a private channel and pop the name modal."""
    guild = interaction.guild
    guild_id = str(guild.id)
    user_id = str(interaction.user.id)

    approval_ch_id = store.get_approval_channel(guild_id)
    if not approval_ch_id:
        await interaction.response.send_message(
            "No approval channel has been configured. A server admin needs to run `/setup server` first.",
            ephemeral=True,
        )
        return

    existing_chars = store.list_by_owner(guild_id, user_id)
    if existing_chars:
        await interaction.response.send_message(
            f"You already have a character: **{existing_chars[0].character.name}**. "
            f"You can only have one character at a time. Delete the existing one first with `/sheet delete`.",
            ephemeral=True,
        )
        return

    existing_ch_id = store.get_creation_channel(guild_id, user_id)
    if existing_ch_id:
        existing_ch = client.get_channel(int(existing_ch_id))
        if existing_ch:
            raw = store.get_creation_state(guild_id, user_id)
            if raw:
                try:
                    saved = json.loads(raw)
                except ValueError:
                    saved = {}
                if saved.get("submitted"):
                    await interaction.response.send_message(
                        _SUBMITTED_TEXT.format(name=saved.get("name", "your character")), ephemeral=True,
                    )
                    return
                label = _CHARGEN_STEP_LABELS.get(saved.get("step", ""), "where you left off")
                view = _ChargenResumeView(guild_id, user_id)
                msg = await existing_ch.send(
                    f"{interaction.user.mention} Your wizard for **{saved.get('name', 'your character')}** is waiting "
                    f"at step {label}. Press **Resume** to continue.",
                    view=view,
                )
                await view.persist(msg)
                await interaction.response.send_message(
                    f"You already have a character in progress. Continue in {existing_ch.mention} (a Resume button is waiting there).",
                    ephemeral=True,
                )
                return
            # A wizard channel with no saved state predates resumable wizards (or
            # its state was lost): its controls are dead, so clear it and start over.
            try:
                await existing_ch.delete(reason="Stale character creation wizard replaced")
            except discord.HTTPException:
                pass
        store.delete_creation_channel(guild_id, user_id)

    await interaction.response.send_modal(_ChargenNameModal(interaction))


class _ChargenNameModal(discord.ui.Modal, title="Character Creation"):
    char_name = discord.ui.TextInput(
        label="Character Name",
        placeholder="e.g. Bayushi Kachiko",
        min_length=1, max_length=100,
    )
    concept = discord.ui.TextInput(
        label="Concept (optional)",
        placeholder="A short description of your character",
        required=False, max_length=2000,
        style=discord.TextStyle.paragraph,
    )

    def __init__(self, source_interaction: discord.Interaction) -> None:
        super().__init__()
        self._source_category = source_interaction.channel.category if source_interaction.channel else None

    async def on_submit(self, interaction: discord.Interaction) -> None:
        guild = interaction.guild
        guild_id = str(guild.id)
        user_id = str(interaction.user.id)
        character_name = self.char_name.value.strip()
        concept_text = (self.concept.value or "").strip()

        await interaction.response.defer(ephemeral=True)

        bot_member = guild.me
        dm_roles = [r for r in guild.roles if r.name in (ROLE_KAMI, ROLE_FORTUNE)]
        everyone = guild.default_role

        overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(view_channel=False),
            interaction.user: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
            ),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_channels=True,
                manage_messages=True,
            ),
        }
        for r in dm_roles:
            overwrites[r] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
            )

        channel_name = f"chargen-{interaction.user.display_name[:20].lower().replace(' ', '-')}"
        priv_channel = await guild.create_text_channel(
            channel_name,
            category=self._source_category,
            overwrites=overwrites,
            reason=f"Character creation wizard for {interaction.user.display_name}",
        )

        store.set_creation_channel(guild_id, user_id, str(priv_channel.id))

        state = {
            "guild_id": guild_id,
            "user_id": user_id,
            "name": character_name,
            "channel_id": priv_channel.id,
            "full_wizard": True,
            "clan": "",
            "family_name": "",
            "heritage_result": None,
            "different_school": False,
            "school_name": "",
            "trait_purchases": {},
            "advantages_chosen": [],
            "disadvantages_chosen": [],
            "skill_purchases": {},
            "emphasis_purchases": [],
            "chosen_spells": [],
            "concept": concept_text,
        }
        state["step"] = "clan"
        view = _WizardView(state)
        view.add_item(_ClanSelect(state, great=True))
        view.add_item(_ClanSelect(state, great=False))
        first_msg = await priv_channel.send(
            content=f"Welcome, {interaction.user.mention}! Let's build **{character_name}**.\n"
                    f"**Step 1/10**: Choose your Clan.",
            embed=_chargen_embed(state), view=view,
        )
        state["message_id"] = first_msg.id
        _cg_save(state)

        await interaction.followup.send(
            f"Your private character creation channel has been created: {priv_channel.mention}\n"
            f"Head there to build **{character_name}**!",
            ephemeral=True,
        )


async def submit_character(interaction: discord.Interaction) -> None:
    # Kept for the persistent lobby button; the slash command is /sheet create.
    if not await _require_guild(interaction):
        return
    await _start_chargen_wizard(interaction)


class _ChargenButtonView(discord.ui.View):
    """Persistent button posted in #character-submission. Survives bot restarts."""

    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(
        label="Begin Character Creation",
        style=discord.ButtonStyle.success,
        custom_id="chargen_start_button",
        emoji="⚔️",
    )
    async def start_chargen(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        await _start_chargen_wizard(interaction)


setup_group = app_commands.Group(name="setup", description="Server setup commands [Kami]")

@setup_group.command(name="server", description="Create the server channel structure (Lobby, OOC, IC, DM categories). [Kami]")
async def setup_server(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    member = interaction.user
    is_admin = isinstance(member, discord.Member) and member.guild_permissions.administrator
    if not _is_kami(interaction) and not is_admin:
        await interaction.response.send_message(
            f"Only the **{ROLE_KAMI}** role (or server administrators) can run server setup.",
            ephemeral=True,
        )
        return
    guild = interaction.guild
    if guild is None:
        return
    await interaction.response.defer(ephemeral=True)
    bot_member = guild.me
    everyone = guild.default_role

    # --- Pre-flight: check the bot actually has the permissions it needs ---
    bot_perms = bot_member.guild_permissions
    missing: list[str] = []
    if not bot_perms.manage_roles:
        missing.append("Manage Roles")
    if not bot_perms.manage_channels:
        missing.append("Manage Channels")
    if not bot_perms.send_messages:
        missing.append("Send Messages")
    if not bot_perms.manage_messages:
        missing.append("Manage Messages")
    if missing:
        await interaction.followup.send(
            "The bot is missing required permissions to set up the server:\n"
            + "\n".join(f"• **{p}**" for p in missing)
            + "\n\nGo to **Server Settings → Roles**, find the bot's role, "
            "and enable those permissions — or re-invite the bot with "
            "**Administrator** ticked.",
            ephemeral=True,
        )
        return

    try:
        await _setup_server_inner(guild, bot_member, everyone, interaction)
    except discord.Forbidden as exc:
        await interaction.followup.send(
            f"The bot was denied a permission by Discord: `{exc}`\n\n"
            "Make sure the bot's role is **above** the roles it's trying to "
            "create (Kami, Fortune, Approved) in **Server Settings → Roles**, "
            "and that **Manage Roles** + **Manage Channels** are enabled.",
            ephemeral=True,
        )
    except Exception as exc:
        await interaction.followup.send(
            f"Server setup failed with an unexpected error:\n```\n{exc}\n```\n"
            "Please report this to the bot developer.",
            ephemeral=True,
        )


async def _setup_server_inner(
    guild: discord.Guild,
    bot_member: discord.Member,
    everyone: discord.Role,
    interaction: discord.Interaction,
) -> None:
    """Core setup logic, extracted so the caller can wrap it in error handling."""
    # --- Roles (create if missing, update color/permissions if they exist) ---
    kami_perms = discord.Permissions(
        administrator=True,
    )
    kami_role = discord.utils.get(guild.roles, name=ROLE_KAMI)
    if kami_role is None:
        kami_role = await guild.create_role(
            name=ROLE_KAMI, color=discord.Color.from_str("#E8B923"),
            permissions=kami_perms, hoist=True,
            reason="Server setup: admin role",
        )
    else:
        await kami_role.edit(color=discord.Color.from_str("#E8B923"),
                            permissions=kami_perms, hoist=True,
                            reason="Server setup: update admin role")

    fortune_perms = discord.Permissions(
        manage_messages=True, manage_nicknames=True, manage_threads=True,
        mute_members=True, deafen_members=True, move_members=True,
        moderate_members=True, view_channel=True, send_messages=True,
        read_message_history=True, attach_files=True, embed_links=True,
        use_application_commands=True, connect=True, speak=True,
    )
    fortune_role = discord.utils.get(guild.roles, name=ROLE_FORTUNE)
    if fortune_role is None:
        fortune_role = await guild.create_role(
            name=ROLE_FORTUNE, color=discord.Color.from_str("#9B59B6"),
            permissions=fortune_perms, hoist=True,
            reason="Server setup: DM role",
        )
    else:
        await fortune_role.edit(color=discord.Color.from_str("#9B59B6"),
                                permissions=fortune_perms, hoist=True,
                                reason="Server setup: update DM role")

    approved_perms = discord.Permissions(
        view_channel=True, send_messages=True, read_message_history=True,
        attach_files=True, embed_links=True, add_reactions=True,
        use_application_commands=True, connect=True, speak=True,
        use_voice_activation=True,
    )
    approved_role = discord.utils.get(guild.roles, name=ROLE_APPROVED)
    if approved_role is None:
        approved_role = await guild.create_role(
            name=ROLE_APPROVED, color=discord.Color.from_str("#2ECC71"),
            permissions=approved_perms, hoist=False,
            reason="Server setup: player access role",
        )
    else:
        await approved_role.edit(color=discord.Color.from_str("#2ECC71"),
                                 permissions=approved_perms, hoist=False,
                                 reason="Server setup: update player role")

    dm_roles: list[discord.Role] = [fortune_role, kami_role]

    # --- Clan roles (cosmetic, hoisted to group members in sidebar) ---
    _CLAN_COLORS: dict[str, str] = {
        "Crab": "#4A6FA5",
        "Crane": "#5DADE2",
        "Dragon": "#27AE60",
        "Lion": "#F1C40F",
        "Mantis": "#1ABC9C",
        "Phoenix": "#E67E22",
        "Scorpion": "#E74C3C",
        "Unicorn": "#9B59B6",
        "Ronin": "#95A5A6",
        "Imperial": "#DAA520",
        "Badger": "#8B4513",
        "Bat": "#4B0082",
        "Dragonfly": "#6B8E23",
        "Hare": "#CD853F",
        "Monkey": "#D2691E",
        "Oriole": "#FFD700",
        "Ox": "#A0522D",
        "Sparrow": "#DEB887",
        "Tortoise": "#2E8B57",
    }
    clan_roles_created: list[discord.Role] = []
    for clan_name in _GREAT_CLANS + _MINOR_CLANS:
        color_hex = _CLAN_COLORS.get(clan_name, "#95A5A6")
        role = discord.utils.get(guild.roles, name=clan_name)
        if role is None:
            role = await guild.create_role(
                name=clan_name,
                color=discord.Color.from_str(color_hex),
                hoist=True,
                reason="Server setup: clan role",
            )
        else:
            await role.edit(
                color=discord.Color.from_str(color_hex),
                hoist=True,
                reason="Server setup: update clan role",
            )
        clan_roles_created.append(role)

    # --- Family roles (cosmetic, not hoisted, colored to match clan) ---
    from l5r_rules import families as _families_mod
    family_roles_created: list[discord.Role] = []
    for fam in _families_mod.ALL:
        fam_name = fam["name"]
        fam_clan = fam["clan"]
        color_hex = _CLAN_COLORS.get(fam_clan, "#95A5A6")
        role = discord.utils.get(guild.roles, name=fam_name)
        if role is None:
            role = await guild.create_role(
                name=fam_name,
                color=discord.Color.from_str(color_hex),
                hoist=False,
                reason=f"Server setup: {fam_clan} family role",
            )
        else:
            await role.edit(
                color=discord.Color.from_str(color_hex),
                hoist=False,
                reason=f"Server setup: update {fam_clan} family role",
            )
        family_roles_created.append(role)

    # --- Remove legacy "Minor Clan" role if present (replaced by individual minor clan roles) ---
    legacy_minor = discord.utils.get(guild.roles, name="Minor Clan")
    if legacy_minor:
        try:
            await legacy_minor.delete(reason="Server setup: replaced by individual minor clan roles")
        except discord.Forbidden:
            pass

    # --- Reorder: Approved below clan/family roles for color priority ---
    try:
        await approved_role.edit(position=1, reason="Server setup: move Approved below clan roles")
    except (discord.Forbidden, discord.HTTPException):
        pass

    # --- Cleanup helper: deduplicate categories, purge stray channels ---
    _EXPECTED_CATEGORIES: dict[str, set[str]] = {
        "Lobby": {"lore", "welcome", "character-submission"},
        "Out of Character": {"general", "off-topic", "announcements", "rules-reference"},
        "IC Information": {"calendar"},
        "Staff Members": {"dm-discussion", "approvals"},
    }
    deleted_dupes: list[str] = []
    deleted_channels: list[str] = []

    for cat_name, expected_channels in _EXPECTED_CATEGORIES.items():
        matches = [c for c in guild.categories if c.name == cat_name]
        if len(matches) <= 1:
            continue
        matches.sort(key=lambda c: c.created_at)
        keep = matches[0]
        for dupe in matches[1:]:
            for ch in dupe.channels:
                try:
                    await ch.delete(reason=f"Cleanup: duplicate {cat_name} category")
                    deleted_channels.append(f"#{ch.name}")
                except discord.Forbidden:
                    pass
            try:
                await dupe.delete(reason=f"Cleanup: duplicate {cat_name} category")
                deleted_dupes.append(cat_name)
            except discord.Forbidden:
                pass

    for cat_name, expected_channels in _EXPECTED_CATEGORIES.items():
        cat = discord.utils.get(guild.categories, name=cat_name)
        if cat is None:
            continue
        for ch in list(cat.text_channels):
            if ch.name not in expected_channels:
                try:
                    await ch.delete(reason=f"Cleanup: unexpected channel in {cat_name}")
                    deleted_channels.append(f"#{ch.name}")
                except discord.Forbidden:
                    pass

    # --- Ensure each category and its channels exist ---
    created_items: list[str] = []
    existing_items: list[str] = []

    # --- 1. Lobby (visible to everyone) ---
    lobby_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        ),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True,
        ),
    }
    lobby_cat = discord.utils.get(guild.categories, name="Lobby")
    if lobby_cat is None:
        lobby_cat = await guild.create_category("Lobby", overwrites=lobby_overwrites, reason="Server setup")
        created_items.append("Lobby category")
    else:
        await lobby_cat.edit(overwrites=lobby_overwrites, reason="Server setup: update permissions")
        existing_items.append("Lobby")
    existing_names = {ch.name for ch in lobby_cat.text_channels}
    if "lore" not in existing_names:
        lore_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(
                view_channel=True, send_messages=False, read_message_history=True,
            ),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_messages=True,
            ),
        }
        for r in dm_roles:
            lore_overwrites[r] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
            )
        await lobby_cat.create_text_channel("lore", overwrites=lore_overwrites)
        created_items.append("#lore")
    else:
        lore_ch = discord.utils.get(lobby_cat.text_channels, name="lore")
        if lore_ch is not None:
            lore_overwrites = {
                everyone: discord.PermissionOverwrite(
                    view_channel=True, send_messages=False, read_message_history=True,
                ),
                bot_member: discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, manage_messages=True,
                ),
            }
            for r in dm_roles:
                lore_overwrites[r] = discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, read_message_history=True,
                )
            await lore_ch.edit(overwrites=lore_overwrites, reason="Server setup: staff-only lore")
    if "welcome" not in existing_names:
        welcome_ch = await lobby_cat.create_text_channel("welcome")
        welcome_embed = discord.Embed(
            title="Welcome to Rokugan",
            color=0xC4A747,
            description=(
                "Welcome, traveler. This server hosts a persistent world set in "
                "Rokugan, using **Legend of the Five Rings 4th Edition** rules.\n\n"
                "Head over to **#character-submission** to create your character "
                "and join the world.\n\n"
                "We look forward to your story."
            ),
        )
        welcome_msg = await welcome_ch.send(embed=welcome_embed)
        await welcome_msg.pin()
        created_items.append("#welcome")
    if "character-submission" not in existing_names:
        sub_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(
                view_channel=True, send_messages=False, read_message_history=True,
            ),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_channels=True,
                manage_messages=True,
            ),
        }
        sub_ch = await lobby_cat.create_text_channel(
            "character-submission", overwrites=sub_overwrites,
        )
        sub_embed = discord.Embed(
            title="Character Submission",
            color=0xC4A747,
            description=(
                "Ready to enter Rokugan? Press the button below to begin "
                "creating your character.\n\n"
                "A private channel will open where you can build your character "
                "step by step. Once complete, a Staff Member will review and "
                "approve your submission.\n\n"
                "After approval, you'll gain access to the rest of the server."
            ),
        )
        await sub_ch.send(embed=sub_embed, view=_ChargenButtonView())
        created_items.append("#character-submission")
    else:
        sub_ch = discord.utils.get(lobby_cat.text_channels, name="character-submission")
        if sub_ch:
            sub_overwrites_upd: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
                everyone: discord.PermissionOverwrite(
                    view_channel=True, send_messages=False, read_message_history=True,
                ),
                bot_member: discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, manage_channels=True,
                    manage_messages=True,
                ),
            }
            await sub_ch.edit(overwrites=sub_overwrites_upd, reason="Server setup: lock character-submission")
            await sub_ch.purge(limit=200, reason="Server setup: reset character-submission")
            sub_embed = discord.Embed(
                title="Character Submission",
                color=0xC4A747,
                description=(
                    "Ready to enter Rokugan? Press the button below to begin "
                    "creating your character.\n\n"
                    "A private channel will open where you can build your character "
                    "step by step. Once complete, a Staff Member will review and "
                    "approve your submission.\n\n"
                    "After approval, you'll gain access to the rest of the server."
                ),
            )
            await sub_ch.send(embed=sub_embed, view=_ChargenButtonView())

    # Order lobby channels: lore, welcome, character-submission
    _LOBBY_ORDER = ["lore", "welcome", "character-submission"]
    lobby_channels = {ch.name: ch for ch in lobby_cat.text_channels}
    for pos, name in enumerate(_LOBBY_ORDER):
        ch = lobby_channels.get(name)
        if ch and ch.position != pos:
            try:
                await ch.edit(position=pos)
            except discord.Forbidden:
                pass

    # Set welcome as the system channel so new members land there
    welcome_ch_obj = discord.utils.get(lobby_cat.text_channels, name="welcome")
    if welcome_ch_obj and guild.system_channel != welcome_ch_obj:
        try:
            await guild.edit(system_channel=welcome_ch_obj, reason="Server setup: new members see #welcome first")
        except discord.Forbidden:
            pass

    # --- 2. Out of Character (Approved + DMs only) ---
    ooc_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        approved_role: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        ),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True,
        ),
    }
    for r in dm_roles:
        ooc_overwrites[r] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        )
    ooc_cat = discord.utils.get(guild.categories, name="Out of Character")
    if ooc_cat is None:
        ooc_cat = await guild.create_category("Out of Character", overwrites=ooc_overwrites, reason="Server setup")
        created_items.append("Out of Character category")
    else:
        await ooc_cat.edit(overwrites=ooc_overwrites, reason="Server setup: update permissions")
        existing_items.append("Out of Character")
    existing_names = {ch.name for ch in ooc_cat.text_channels}
    if "general" not in existing_names:
        await ooc_cat.create_text_channel("general")
        created_items.append("#general")
    if "off-topic" not in existing_names:
        await ooc_cat.create_text_channel("off-topic")
        created_items.append("#off-topic")
    if "announcements" not in existing_names:
        announce_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(view_channel=False),
            approved_role: discord.PermissionOverwrite(
                view_channel=True, send_messages=False, read_message_history=True,
                add_reactions=True,
            ),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_messages=True,
                embed_links=True,
            ),
        }
        for r in dm_roles:
            announce_overwrites[r] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
                manage_messages=True,
            )
        await ooc_cat.create_text_channel("announcements", overwrites=announce_overwrites)
        created_items.append("#announcements")
    else:
        ann_ch = discord.utils.get(ooc_cat.text_channels, name="announcements")
        if ann_ch is not None:
            announce_overwrites = {
                everyone: discord.PermissionOverwrite(view_channel=False),
                approved_role: discord.PermissionOverwrite(
                    view_channel=True, send_messages=False, read_message_history=True,
                    add_reactions=True,
                ),
                bot_member: discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, manage_messages=True,
                    embed_links=True,
                ),
            }
            for r in dm_roles:
                announce_overwrites[r] = discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, read_message_history=True,
                    manage_messages=True,
                )
            await ann_ch.edit(overwrites=announce_overwrites, reason="Server setup: staff-only announcements")
    if "rules-reference" not in existing_names:
        rules_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(view_channel=False),
            approved_role: discord.PermissionOverwrite(
                view_channel=True, send_messages=False, read_message_history=True,
            ),
            bot_member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, manage_messages=True,
            ),
        }
        for r in dm_roles:
            rules_overwrites[r] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True,
            )
        rules_ch = await ooc_cat.create_text_channel("rules-reference", overwrites=rules_overwrites)
        await _post_rules_reference(rules_ch)
        created_items.append("#rules-reference")
    else:
        rules_ch = discord.utils.get(ooc_cat.text_channels, name="rules-reference")
        if rules_ch is not None:
            rules_overwrites = {
                everyone: discord.PermissionOverwrite(view_channel=False),
                approved_role: discord.PermissionOverwrite(
                    view_channel=True, send_messages=False, read_message_history=True,
                ),
                bot_member: discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, manage_messages=True,
                ),
            }
            for r in dm_roles:
                rules_overwrites[r] = discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, read_message_history=True,
                )
            await rules_ch.edit(overwrites=rules_overwrites, reason="Server setup: staff-only rules-reference")

    # Order OOC channels: announcements, general, off-topic, rules-reference
    _OOC_ORDER = ["announcements", "general", "off-topic", "rules-reference"]
    ooc_channels = {ch.name: ch for ch in ooc_cat.text_channels}
    for pos, name in enumerate(_OOC_ORDER):
        ch = ooc_channels.get(name)
        if ch and ch.position != pos:
            try:
                await ch.edit(position=pos)
            except discord.Forbidden:
                pass

    # --- 3. IC Information (Approved + DMs, read-only) ---
    icinfo_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        approved_role: discord.PermissionOverwrite(
            view_channel=True, send_messages=False, read_message_history=True,
        ),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True,
        ),
    }
    for r in dm_roles:
        icinfo_overwrites[r] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
            manage_messages=True,
        )
    icinfo_cat = discord.utils.get(guild.categories, name="IC Information")
    if icinfo_cat is None:
        icinfo_cat = await guild.create_category("IC Information", overwrites=icinfo_overwrites, reason="Server setup")
        created_items.append("IC Information category")
    else:
        await icinfo_cat.edit(overwrites=icinfo_overwrites, reason="Server setup: update permissions")
        existing_items.append("IC Information")
    existing_names = {ch.name for ch in icinfo_cat.text_channels}
    cal_ch: discord.TextChannel | None = None
    if "calendar" not in existing_names:
        cal_ch = await icinfo_cat.create_text_channel("calendar")
        created_items.append("#calendar")
    else:
        cal_ch = discord.utils.get(icinfo_cat.text_channels, name="calendar")
        if cal_ch:
            await cal_ch.purge(limit=200, reason="Server setup: reset calendar")
    guild_id = str(guild.id)
    cal = store.get_calendar(guild_id)
    if cal is not None and cal_ch is not None:
        date_str = _format_rokugani_date(*cal)
        msg = await cal_ch.send(embed=_date_embed(date_str))
        await msg.pin()
        store.set_date_channel(guild_id, str(cal_ch.id), str(msg.id))

    # --- 4. Remove legacy "In Character" category if present ---
    ic_cat = discord.utils.get(guild.categories, name="In Character")
    if ic_cat is not None:
        for ch in list(ic_cat.channels):
            try:
                await ch.delete(reason="Server setup: removing unused In Character category")
            except discord.Forbidden:
                pass
        try:
            await ic_cat.delete(reason="Server setup: removing unused In Character category")
            deleted_channels.append("In Character (category)")
        except discord.Forbidden:
            pass

    # --- 5. Player Support (per-player private channels, created on approval) ---
    ps_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True,
        ),
    }
    for r in dm_roles:
        ps_overwrites[r] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
            manage_messages=True,
        )
    ps_cat = discord.utils.get(guild.categories, name=CAT_PLAYER_SUPPORT)
    if ps_cat is None:
        ps_cat = await guild.create_category(CAT_PLAYER_SUPPORT, overwrites=ps_overwrites, reason="Server setup")
        created_items.append("Player Support category")
    else:
        await ps_cat.edit(overwrites=ps_overwrites, reason="Server setup: update permissions")
        existing_items.append("Player Support")

    # --- 6. Staff Members (Fortune + Kami only) ---
    dm_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True,
        ),
    }
    for r in dm_roles:
        dm_overwrites[r] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
            manage_messages=True,
        )
    dm_cat = discord.utils.get(guild.categories, name="Staff Members")
    if dm_cat is None:
        dm_cat = discord.utils.get(guild.categories, name="Dungeon Masters")
    if dm_cat is None:
        dm_cat = await guild.create_category("Staff Members", overwrites=dm_overwrites, reason="Server setup")
        created_items.append("Staff Members category")
    else:
        await dm_cat.edit(name="Staff Members", overwrites=dm_overwrites, reason="Server setup: rename to Staff Members")
        existing_items.append("Staff Members")
    existing_names = {ch.name for ch in dm_cat.text_channels}
    if "dm-discussion" not in existing_names:
        await dm_cat.create_text_channel("dm-discussion")
        created_items.append("#dm-discussion")
    if "approvals" not in existing_names:
        await dm_cat.create_text_channel("approvals")
        created_items.append("#approvals (character submissions)")
    approvals_ch_disc = discord.utils.get(dm_cat.text_channels, name="approvals")
    if approvals_ch_disc:
        store.set_approval_channel(str(guild.id), str(approvals_ch_disc.id))
    if "damage-approvals" not in existing_names:
        await dm_cat.create_text_channel("damage-approvals")
        created_items.append("#damage-approvals (combat/spell/healing)")
    dmg_ch_disc = discord.utils.get(dm_cat.text_channels, name="damage-approvals")
    if dmg_ch_disc:
        store.set_damage_approval_channel(str(guild.id), str(dmg_ch_disc.id))
    if "xp-log" not in existing_names:
        xp_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            everyone: discord.PermissionOverwrite(view_channel=False),
            bot_member: discord.PermissionOverwrite(view_channel=True, send_messages=True, manage_channels=True),
            kami_role: discord.PermissionOverwrite(view_channel=True, send_messages=True, read_message_history=True),
        }
        for r in dm_roles:
            if r != kami_role:
                xp_overwrites[r] = discord.PermissionOverwrite(view_channel=False)
        await dm_cat.create_text_channel("xp-log", overwrites=xp_overwrites, reason="Server setup: Kami-only XP log")
        created_items.append("#xp-log (Kami only: XP grants and spends)")
    xp_ch_disc = discord.utils.get(dm_cat.text_channels, name="xp-log")
    if xp_ch_disc:
        store.set_xp_log_channel(str(guild.id), str(xp_ch_disc.id))

    # --- Position Player Support just above Staff Members, Staff Members always last ---
    max_pos = max((c.position for c in guild.categories), default=0)
    try:
        await dm_cat.edit(position=max_pos + 1, reason="Server setup: Staff Members always last")
    except (discord.Forbidden, discord.HTTPException):
        pass
    try:
        await ps_cat.edit(position=dm_cat.position - 1, reason="Server setup: Player Support above Staff Members")
    except (discord.Forbidden, discord.HTTPException):
        pass

    # --- 7. Fix permissions on existing location areas ---
    location_areas = store.list_location_areas(str(guild.id))
    areas_fixed = 0
    areas_skipped = 0
    for area in location_areas:
        cat = guild.get_channel(int(area.category_id))
        if cat is None or not isinstance(cat, discord.CategoryChannel):
            areas_skipped += 1
            continue
        try:
            await cat.set_permissions(everyone, view_channel=False, reason="Server setup: fix area permissions")
            await cat.set_permissions(bot_member, view_channel=True, send_messages=True,
                                     manage_channels=True, manage_messages=True,
                                     manage_threads=True, reason="Server setup: fix area permissions")
            await cat.set_permissions(approved_role, view_channel=True, send_messages=True,
                                     read_message_history=True, reason="Server setup: fix area permissions")
            for r in (fortune_role, kami_role):
                await cat.set_permissions(r, view_channel=True, send_messages=True,
                                         read_message_history=True, manage_messages=True,
                                         reason="Server setup: fix area permissions")
            for ch in cat.text_channels:
                if ch.name == "description":
                    await ch.set_permissions(everyone, view_channel=False, send_messages=False,
                                            reason="Server setup: fix area permissions")
                    await ch.set_permissions(approved_role, view_channel=True, send_messages=False,
                                            read_message_history=True, reason="Server setup: fix area permissions")
                    for r in (fortune_role, kami_role):
                        await ch.set_permissions(r, view_channel=True, send_messages=True,
                                                 read_message_history=True, manage_messages=True,
                                                 reason="Server setup: fix area permissions")
            areas_fixed += 1
        except discord.Forbidden:
            areas_skipped += 1

    # --- Summary ---
    summary_parts = ["**Server setup complete!**\n"]
    summary_parts.append(
        f"**Roles:** {kami_role.mention} (admin), {fortune_role.mention} (DM), "
        f"{approved_role.mention} (player), {len(clan_roles_created)} clan, "
        f"{len(family_roles_created)} family roles"
    )
    if deleted_dupes:
        summary_parts.append(f"**Deleted duplicate categories:** {', '.join(deleted_dupes)}")
    if deleted_channels:
        summary_parts.append(f"**Deleted stray/duplicate channels:** {', '.join(deleted_channels)}")
    if created_items:
        summary_parts.append(f"**Created:** {', '.join(created_items)}")
    if existing_items:
        summary_parts.append(f"**Already existed (permissions updated):** {', '.join(existing_items)}")
    if areas_fixed:
        summary_parts.append(f"**Location areas:** permissions repaired on {areas_fixed} area(s).")
    if not deleted_dupes and not deleted_channels and not created_items and not areas_fixed:
        summary_parts.append("Everything was already in order. Permissions refreshed.")
    summary_parts.append(
        f"\nPlayers use `/sheet create` to apply. "
        f"DMs approve or deny from the approvals channel."
    )
    await interaction.followup.send("\n".join(summary_parts), ephemeral=True)

# ---------------------------------------------------------------------------
#  Rules reference — pinned embeds posted by /setup server
# ---------------------------------------------------------------------------

async def _post_rules_reference(channel: discord.TextChannel) -> None:
    """Post and pin the L5R 4e quick-reference embeds."""
    # 1. Wound Levels
    wound_lines: list[str] = []
    for lvl, pen in zip(enums.WOUND_LEVELS, enums.WOUND_PENALTIES):
        pen_str = f" ({pen:+d} to all rolls)" if pen else ""
        wound_lines.append(f"**{lvl}**{pen_str}")
    wound_embed = discord.Embed(
        title="Wound Levels",
        color=0xC4A747,
        description=(
            "Each level holds (Earth Ring x 2) wounds.\n"
            + "\n".join(wound_lines)
            + "\n\n*Wound penalties apply to all rolls at that level.*"
        ),
    )
    msg = await channel.send(embed=wound_embed)
    await msg.pin()

    # 2. Stances
    stance_embed = discord.Embed(
        title="Combat Stances",
        color=0xC4A747,
    )
    stance_embed.add_field(
        name="Attack",
        value="Standard stance. No bonuses or penalties.",
        inline=False,
    )
    stance_embed.add_field(
        name="Full Attack",
        value="+2k1 to attack rolls, but **-10 to your Armor TN** (reckless).",
        inline=False,
    )
    stance_embed.add_field(
        name="Defense",
        value="+(Air Ring + Defense Skill) to your Armor TN. You may still attack normally.",
        inline=False,
    )
    stance_embed.add_field(
        name="Full Defense",
        value="Roll Defense/Reflexes. Add half (rounded up) to your Armor TN until your next turn. **Cannot attack.**",
        inline=False,
    )
    stance_embed.add_field(
        name="Center",
        value="No combat actions. On your *next* turn: +1k1+Void to your first roll.",
        inline=False,
    )
    msg = await channel.send(embed=stance_embed)
    await msg.pin()

    # 3. Common TNs
    tn_embed = discord.Embed(
        title="Target Numbers (TN)",
        color=0xC4A747,
        description=(
            "**5** — Mundane\n"
            "**10** — Simple\n"
            "**15** — Normal\n"
            "**20** — Hard\n"
            "**25** — Very Hard\n"
            "**30** — Heroic\n"
            "**40** — Legendary\n"
            "**50+** — Impossible\n\n"
            "**Raises:** voluntarily increase TN by +5 each for extra effects.\n"
            "**Free Raises:** from mastery abilities or advantages; don't increase TN."
        ),
    )
    msg = await channel.send(embed=tn_embed)
    await msg.pin()

    # 4. Maneuvers
    maneuver_embed = discord.Embed(
        title="Combat Maneuvers",
        color=0xC4A747,
    )
    maneuver_embed.add_field(
        name="Called Shot (0 Raises)",
        value="Declare a specific hit location for narrative effect.",
        inline=False,
    )
    maneuver_embed.add_field(
        name="Feint (2 Raises)",
        value="Ignore target's Armor TN bonus from armor on this attack. Margin of success matters.",
        inline=False,
    )
    maneuver_embed.add_field(
        name="Knockdown (2 Raises)",
        value="Contested Strength roll. Loser is knocked prone.",
        inline=False,
    )
    maneuver_embed.add_field(
        name="Disarm (3 Raises)",
        value="Contested attack vs. Reflexes roll. If you win, target drops their weapon.",
        inline=False,
    )
    maneuver_embed.add_field(
        name="Extra Attack (5 Raises)",
        value="Make one additional attack this round.",
        inline=False,
    )
    maneuver_embed.add_field(
        name="Increased Damage (+1 Raise each)",
        value="Each Raise adds +1k0 to your damage roll.",
        inline=False,
    )
    msg = await channel.send(embed=maneuver_embed)
    await msg.pin()

    # 5. Rings & Traits
    ring_embed = discord.Embed(
        title="Rings & Traits",
        color=0xC4A747,
        description=(
            "**Air** = min(Reflexes, Awareness)\n"
            "**Earth** = min(Stamina, Willpower)\n"
            "**Fire** = min(Agility, Intelligence)\n"
            "**Water** = min(Strength, Perception)\n"
            "**Void** = Void (standalone)\n\n"
            "*Armor TN = Reflexes x 5 + 5 (+ armor bonus)*\n"
            "*Initiative = Insight Rank + Reflexes, keep Reflexes*"
        ),
    )
    msg = await channel.send(embed=ring_embed)
    await msg.pin()

# ---------------------------------------------------------------------------
#  /dm announce — post an event to announcements with RSVP
# ---------------------------------------------------------------------------

@dm.command(name="announce", description="Post a session/event announcement with RSVP reactions [Fortune]")
@app_commands.describe(
    title="Event title (e.g. 'Court of the Crane — Session 5').",
    description="Event details (what, where, when, etc.).",
    date="When the event takes place (e.g. 'Saturday, Sept 14 at 7pm EST').",
    channel="Channel to post in (defaults to #announcements if it exists).",
)
async def dm_announce(
    interaction: discord.Interaction,
    title: app_commands.Range[str, 1, 256],
    description: app_commands.Range[str, 1, 4000],
    date: app_commands.Range[str, 1, 200] | None = None,
    channel: discord.TextChannel | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    if not await _require_dm_role(interaction):
        return
    target_ch = channel
    if target_ch is None:
        for ch in interaction.guild.text_channels:
            if ch.name == "announcements":
                target_ch = ch
                break
    if target_ch is None:
        await interaction.response.send_message(
            "No announcements channel found. Either specify a channel or run `/setup server`.",
            ephemeral=True,
        )
        return
    embed = discord.Embed(
        title=title,
        color=0xC4A747,
        description=description,
    )
    if date:
        embed.add_field(name="When", value=date, inline=False)
    embed.add_field(
        name="RSVP",
        value="React below:\n✅ Attending  ❔ Maybe  ❌ Can't make it",
        inline=False,
    )
    embed.set_footer(text=f"Posted by {interaction.user.display_name}")
    msg = await target_ch.send(embed=embed)
    await msg.add_reaction("✅")
    await msg.add_reaction("❔")
    await msg.add_reaction("❌")
    await interaction.response.send_message(
        f"Announcement posted in {target_ch.mention}.", ephemeral=True,
    )

# ---------------------------------------------------------------------------
#  /players — player character directory
# ---------------------------------------------------------------------------

@client.tree.command(name="players", description="Show all approved player characters on this server.")
async def players_cmd(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    guild_id = str(interaction.guild_id)
    pcs = store.list_active_pcs(guild_id)
    if not pcs:
        await interaction.response.send_message(
            "No active player characters found on this server.", ephemeral=True,
        )
        return
    embed = discord.Embed(
        title="Player Character Roster",
        color=0xC4A747,
        description=f"**{len(pcs)}** active characters on this server.",
    )
    for owner_id, rec in pcs[:25]:
        c = rec.character
        clan_str = c.clan if c.clan else "—"
        school_str = c.school if c.school else "—"
        wl = stats.wound_level_name(c)
        wound_icon = ""
        if wl == "Dead":
            wound_icon = " \U0001f480"
        elif wl in ("Down", "Out"):
            wound_icon = " \U0001f534"
        elif wl in ("Hurt", "Injured", "Crippled"):
            wound_icon = " \U0001f7e0"
        elif wl == "Healthy":
            wound_icon = " \U0001f7e2"
        member = interaction.guild.get_member(int(owner_id))
        player_str = member.mention if member else f"<@{owner_id}>"
        embed.add_field(
            name=f"{c.name}{wound_icon}",
            value=f"{clan_str} • {school_str}\n{wl} ({c.wounds_taken} wounds) • Player: {player_str}",
            inline=True,
        )
    if len(pcs) > 25:
        embed.set_footer(text=f"Showing first 25 of {len(pcs)} characters.")
    await interaction.response.send_message(embed=embed)

cog_checks.init(
    store=store,
    engine=engine,
    require_guild=_require_guild,
    require_dm_role=_require_dm_role,
    resolve_duelist=_resolve_duelist,
    format_dice=_format_dice,
    log_roll=_log_roll,
    npc_owner=NPC_OWNER,
    skill_autocomplete=_skill_autocomplete,
    refuse_if_dead=_refuse_if_dead,
    refuse_if_cannot_act=_refuse_if_cannot_act,
    fear_penalty=_fear_penalty,
    set_fear_penalty=_set_fear_penalty,
    is_dm=_is_dm,
    role_fortune=ROLE_FORTUNE,
)

cog_combat.init(
    store=store,
    engine=engine,
    encounters=encounters,
    npc_owner=NPC_OWNER,
    role_fortune=ROLE_FORTUNE,
    role_kami=ROLE_KAMI,
    bot_client=client,
    is_dm=_is_dm,
    refuse_if_dead=_refuse_if_dead,
    refuse_if_cannot_act=_refuse_if_cannot_act,
    on_death=_on_death,
    dm_ping=_dm_ping,
    tally=_tally,
    require_guild=_require_guild,
    require_dm_role=_require_dm_role,
    require_encounter=_require_encounter,
    resolve_combatant_record=_resolve_combatant_record,
    resolve_duelist=_resolve_duelist,
    format_dice=_format_dice,
    combat_log=_combat_log,
    save_encounter=_save_encounter,
    delete_encounter=_delete_encounter,
    npc_autocomplete=_npc_autocomplete,
    weapon_autocomplete=_weapon_autocomplete,
    creature_instance_autocomplete=_creature_instance_autocomplete,
    category_autocomplete=_category_autocomplete,
)

cog_inventory.init(
    tree=client.tree,
    store=store,
    npc_owner=NPC_OWNER,
    require_guild=_require_guild,
    is_dm=_is_dm,
    resolve_active_for_edit=_resolve_active_for_edit,
    audit_stat=_audit_stat,
    modify_inventory=_modify_inventory,
    npc_autocomplete=_npc_autocomplete,
    role_fortune=ROLE_FORTUNE,
    role_kami=ROLE_KAMI,
)

cog_hub.init(
    tree=client.tree,
    store=store,
    require_guild=_require_guild,
    build_sheet_embed=build_sheet_embed,
    whoami_lines=_whoami_lines,
    activate_kata=_activate_kata,
    activate_kiho=_activate_kiho,
    tally=_tally,
    export_callback=sheet_export.callback,
    fight_status_callback=cog_combat.fight_status.callback,
    inventory_callback=cog_inventory.inventory.callback,
    is_dm=_is_dm,
)

cog_npc_builder.init(
    store=store,
    npc_owner=NPC_OWNER,
    require_guild=_require_guild,
    require_dm_role=_require_dm_role,
    is_dm=_is_dm,
    build_sheet_embed=build_sheet_embed,
    npc_autocomplete=_npc_autocomplete,
    npc_group=npc_group,
)

ref_commands.init(
    store=store,
    encounters=encounters,
    require_guild=_require_guild,
    require_dm_role=_require_dm_role,
    find_any_character=_find_any_character,
    paginate=_paginate,
    PaginatorView=_PaginatorView,
    element_colors=_ELEMENT_COLORS,
    npc_owner=NPC_OWNER,
    weapon_autocomplete=_weapon_autocomplete,
    armor_autocomplete=_armor_autocomplete,
    school_autocomplete=_school_autocomplete,
    kata_autocomplete=_kata_autocomplete,
    kiho_autocomplete=_kiho_autocomplete,
    anyadv_autocomplete=_anyadv_autocomplete,
)

client.tree.add_command(sheet)
client.tree.add_command(stat_group)
client.tree.add_command(xp_group)
client.tree.add_command(dm)
client.tree.add_command(npc_group)
client.tree.add_command(npc_edit_group)
client.tree.add_command(creature_group)
client.tree.add_command(room_group)
client.tree.add_command(category_group)
client.tree.add_command(location_group)
client.tree.add_command(cog_combat.combat_group)
client.tree.add_command(cog_combat.fight_group)
client.tree.add_command(cog_combat.engage_group)
client.tree.add_command(spell_group)
client.tree.add_command(cog_checks.check)
client.tree.add_command(ref_commands.ref)
client.tree.add_command(setup_group)
_HELP_COMMANDS.extend(client.tree.get_commands())

def main() -> None:
    if not TOKEN:
        raise SystemExit(
            "DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and paste your "
            "bot token, or export DISCORD_BOT_TOKEN in the environment. See README.md."
        )
    client.run(TOKEN)

if __name__ == "__main__":
    main()
