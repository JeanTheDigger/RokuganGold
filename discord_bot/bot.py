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
import traceback
from collections import defaultdict, deque
from time import monotonic

import discord
from discord import app_commands

import encounter
import cog_checks
import cog_combat
import ref_commands
import storage
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

# In-memory roll history: channel_id → deque of (timestamp, user_display, description, total).
_roll_history: dict[int, deque] = defaultdict(lambda: deque(maxlen=50))

# Cached Discord webhooks for NPC speech, keyed by parent channel id.
_npc_webhooks: dict[int, discord.Webhook] = {}
WEBHOOK_NAME = "Rokugan NPC"

def _log_roll(channel_id: int, user: str, description: str, total: int | str) -> None:
    _roll_history[channel_id].append((monotonic(), user, description, total))

class RokuganBot(discord.Client):
    def __init__(self) -> None:
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self) -> None:
        if GUILD_ID:
            guild = discord.Object(id=int(GUILD_ID))
            self.tree.copy_global_to(guild=guild)
            synced = await self.tree.sync(guild=guild)
            log.info("Synced %d commands to dev guild %s", len(synced), GUILD_ID)
        else:
            synced = await self.tree.sync()
            log.info("Synced %d global commands (may take up to ~1h to appear)", len(synced))

    async def on_ready(self) -> None:
        self.tree.on_error = _on_app_command_error
        log.info("Logged in as %s (id=%s). Ready.", self.user, getattr(self.user, "id", "?"))
        for ch_id_str, data_json in store.load_all_encounters():
            try:
                enc = encounter.Encounter.from_dict(json.loads(data_json))
                encounters[int(ch_id_str)] = enc
            except Exception:
                log.warning("Failed to restore encounter for channel %s", ch_id_str)
        if encounters:
            log.info("Restored %d encounter(s) from database.", len(encounters))

client = RokuganBot()

# ===========================================================================
# Global error handler
# ===========================================================================
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

def _guild_ok(interaction: discord.Interaction) -> bool:
    return interaction.guild_id is not None

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
    per = stats.wound_threshold_per_level(c)
    track = stats.wound_track(c)
    wound_line = (
        f"**{lvl}**" + (f" ({pen} penalty)" if pen else "")
        + f"\n{c.wounds_taken} / {cap} wounds  ·  {per} per level"
        + f"\n{track}"
    )
    embed.add_field(name="Wounds", value=wound_line, inline=True)

    embed.add_field(
        name="Standing",
        value=(
            f"Honor {c.honor:g} · Glory {c.glory:g} · Status {c.status:g} · Infamy {c.infamy:g}\n"
            f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) · "
            f"Void Points {c.current_void_points}/{c.max_void_points}\n"
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

    gear = f"Armor: {c.armor_name or ' '}  (TN +{c.armor_tn_bonus}, Reduction {c.armor_reduction})"
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
        for elem in ("air", "earth", "fire", "water", "void"):
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
    await interaction.response.send_message(
        f"🎋 Alive. Gateway latency {round(client.latency * 1000)} ms.", ephemeral=True
    )

@client.tree.command(name="sync", description="Re-sync all slash commands with Discord (Kami only).")
async def sync_commands(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(
            f"Only the **{ROLE_KAMI}** role can sync commands.", ephemeral=True
        )
        return
    await interaction.response.defer(ephemeral=True)
    guild = discord.Object(id=interaction.guild_id)
    client.tree.copy_global_to(guild=guild)
    synced = await client.tree.sync(guild=guild)
    await interaction.followup.send(f"Synced **{len(synced)}** commands to this server.")

@client.tree.command(name="whoami", description="Quick glance at your active character's status.")
async def whoami(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message(
            "You have no active character. Use `/sheet create` first.", ephemeral=True
        )
        return
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
        for elem in ("air", "earth", "fire", "water", "void"):
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
    await interaction.response.send_message("\n".join(lines), ephemeral=True)

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
sheet_data = app_commands.Group(name="data", description="Export / import character sheets.", parent=sheet)
stat_group = app_commands.Group(name="stat", description="Set traits, skills, equipment, and inventory on your character.")
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

@sheet.command(name="create", description="Create a new character and make it your active one.")
@app_commands.describe(
    name="Character name.",
    school="School (start typing for the catalog: a match auto-fills Benefit, Skills, Honor).",
    clan="Great/Minor Clan (optional; a catalog school sets this for you).",
    family="Family (optional).",
    school_type="School type (default Bushi; a catalog school sets this for you).",
    age="Age (default 16).",
)
@app_commands.autocomplete(school=_basic_school_autocomplete, family=_family_autocomplete)
@app_commands.choices(school_type=_SCHOOL_CHOICES)
async def sheet_create(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 64],
    school: str | None = None,
    clan: str | None = None,
    family: str | None = None,
    school_type: app_commands.Choice[str] | None = None,
    age: app_commands.Range[int, 0, 200] | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    owner = str(interaction.user.id)

    char = Character(
        name=name,
        clan=clan or "",
        family=family or "",
        school=school or "",
        school_type=(school_type.value if school_type else "Bushi"),
    )
    if age is not None:
        char.age = age

    # If the family matches a catalog entry, auto-apply its +1 Trait bonus.
    family_entry = families.get(family) if family else None
    family_report = None
    if family_entry:
        family_report = families.apply_to_character(char, family_entry)
        if not clan:
            char.clan = family_entry["clan"]

    # If the school matches a catalog entry, auto-apply its Benefit/Skills/Honor.
    applied = schools.get(school) if school else None
    report = schools.apply_to_character(char, applied) if applied else None

    try:
        record = store.create_character(guild, owner, char)
    except storage.DuplicateNameError:
        await interaction.response.send_message(
            f"You already have a character named **{name}**. Pick another name or "
            f"`/sheet activate` the existing one.",
            ephemeral=True,
        )
        return

    store.set_active(guild, owner, record.id)
    if report is not None:
        bits = [f"applied **{applied['name']}**"]
        if family_report:
            bits.append(f"Family {family_entry['name']} ({family_report})")
        if report["benefit"]:
            bits.append(f"Benefit {report['benefit']}")
        if report["skills"]:
            bits.append(f"{len(report['skills'])} school skills")
        if report["wildcards"]:
            bits.append("choose: " + "; ".join(report["wildcards"]))
        content = (
            f"Created **{name}** ({applied['clan']} {applied['name']}) and set it active:"
            + ", ".join(bits)
            + ". `/school learn` to record your Rank-1 technique."
        )
    else:
        fam_note = ""
        if family_report:
            fam_note = f" Family **{family_entry['name']}** applied ({family_report})."
        content = (
            f"Created **{name}** and set it as your active character. All Traits start at 2 "
            f"(the L5R 4e baseline).{fam_note} Tip: pass a `school:` from the catalog to auto-fill it."
        )
    await interaction.response.send_message(content=content, embed=build_sheet_embed(record))

# ---------------------------------------------------------------------------
# /sheet wizard: guided step-by-step character creation
# ---------------------------------------------------------------------------
_GREAT_CLANS = ["Crab", "Crane", "Dragon", "Lion", "Mantis", "Phoenix", "Scorpion", "Unicorn"]
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
    def __init__(self, state: dict):
        self.state = state
        options = [discord.SelectOption(label=c) for c in _ALL_SCHOOL_CLANS]
        super().__init__(placeholder="Choose your Clan...", options=options)

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
    basic_schools = [s for s in schools.by_clan(school_clan) if s.get("category", "basic") == "basic"]
    if not basic_schools:
        await interaction.response.edit_message(
            content=f"No basic schools found for **{school_clan}**. Pick another.",
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

class _WizardView(discord.ui.View):
    def __init__(self, state: dict):
        super().__init__(timeout=300)
        self.state = state

    async def on_timeout(self) -> None:
        pass

# ---------------------------------------------------------------------------
# Full character-creation wizard (runs in a private channel via /submit)
# ---------------------------------------------------------------------------
_CHARGEN_XP = 40
_MAX_DISADVANTAGE_XP = 10

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

_ALL_SKILLS_SORTED: list[str] = sorted(
    s for cat in _SKILL_CATEGORIES.values() for s in cat
)


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
    disadv_xp = sum(d["points"] for d in state.get("disadvantages_chosen", []))
    disadv_xp = min(disadv_xp, _MAX_DISADVANTAGE_XP)
    return spent, _CHARGEN_XP + disadv_xp - spent


def _chargen_embed(state: dict) -> discord.Embed:
    """Full-wizard progress embed showing all chargen state."""
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

    spent, _ = _calc_chargen_xp(state)
    char.xp_spent = float(spent)
    char.xp = 0.0

    if state.get("concept"):
        char.notes = state["concept"]

    return char


class _ChargenView(discord.ui.View):
    def __init__(self, state: dict):
        super().__init__(timeout=1800)
        self.state = state

    async def on_timeout(self) -> None:
        pass


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
            cap = advancement.MAX_VOID_RANK if t == "void" else advancement.MAX_TRAIT_RANK
            if effective >= cap:
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
    view.add_item(undo_btn)
    view.add_item(next_btn)

    await interaction.response.edit_message(
        content="**Step 5/10 — Trait Raises** · Select a trait to raise (costs XP). Press **Next** when done.",
        embed=_chargen_embed(state), view=view,
    )


# --- Step 6: Advantages ---
class _AdvantageSelect(discord.ui.Select):
    def __init__(self, state: dict, category: str):
        self.state = state
        self.category = category
        chosen_names = {a["name"] for a in state.get("advantages_chosen", [])}
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
        self.state.setdefault("advantages_chosen", []).append({"name": adv["name"], "points": adv["points"]})
        _, remaining = _calc_chargen_xp(self.state)
        if remaining < 0:
            self.state["advantages_chosen"].pop()
            await interaction.response.send_message("Not enough XP for that advantage.", ephemeral=True)
            return
        await _chargen_advantages(interaction, self.state)


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
        cat = self.values[0]
        view = _ChargenView(self.state)
        view.add_item(_AdvantageSelect(self.state, cat))
        back_btn = discord.ui.Button(label="Back to Categories", style=discord.ButtonStyle.secondary, row=2)

        async def on_back(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(self.state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            await _chargen_advantages(btn_inter, self.state)

        back_btn.callback = on_back
        view.add_item(back_btn)
        await interaction.response.edit_message(
            content=f"**Step 6/10 — Advantages ({cat})** · Select an advantage to buy.",
            embed=_chargen_embed(self.state), view=view,
        )


async def _chargen_advantages(interaction: discord.Interaction, state: dict) -> None:
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

    undo_btn.callback = on_undo
    next_btn.callback = on_next
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
        chosen_names = {d["name"] for d in state.get("disadvantages_chosen", [])}
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
        current_disadv_xp = sum(d["points"] for d in state.get("disadvantages_chosen", []))
        if current_disadv_xp >= _MAX_DISADVANTAGE_XP:
            await interaction.response.send_message(
                f"You've already reached the maximum {_MAX_DISADVANTAGE_XP} XP from disadvantages.",
                ephemeral=True,
            )
            return
        self.state.setdefault("disadvantages_chosen", []).append({"name": dis["name"], "points": dis["points"]})
        await _chargen_disadvantages(interaction, self.state)


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
        cat = self.values[0]
        view = _ChargenView(self.state)
        view.add_item(_DisadvantageSelect(self.state, cat))
        back_btn = discord.ui.Button(label="Back to Categories", style=discord.ButtonStyle.secondary, row=2)

        async def on_back(btn_inter: discord.Interaction) -> None:
            if btn_inter.user.id != int(self.state["user_id"]):
                await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
                return
            await _chargen_disadvantages(btn_inter, self.state)

        back_btn.callback = on_back
        view.add_item(back_btn)
        disadv_xp = sum(d["points"] for d in state.get("disadvantages_chosen", []))
        await interaction.response.edit_message(
            content=f"**Step 7/10 — Disadvantages ({cat})** · "
                    f"Select a disadvantage ({disadv_xp}/{_MAX_DISADVANTAGE_XP} XP gained).",
            embed=_chargen_embed(self.state), view=view,
        )


async def _chargen_disadvantages(interaction: discord.Interaction, state: dict) -> None:
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

    undo_btn.callback = on_undo
    next_btn.callback = on_next
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
        skill_list = _SKILL_CATEGORIES.get(category, [])
        base = _build_base_char(state)
        options = []
        for sk in skill_list:
            base_rank = base.skills.get(sk, 0)
            bought = state.get("skill_purchases", {}).get(sk, 0)
            effective = base_rank + bought
            if effective >= advancement.MAX_SKILL_RANK:
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
        options = [discord.SelectOption(label=c) for c in _SKILL_CATEGORIES]
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

    undo_btn.callback = on_undo
    next_btn.callback = on_next
    view.add_item(undo_btn)
    view.add_item(next_btn)

    await interaction.response.edit_message(
        content="**Step 8/10 — Skills** · Pick a category then select skills to buy. Press **Next** when done.",
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

    skip_btn = discord.ui.Button(label="Skip Remaining Spells", style=discord.ButtonStyle.secondary, row=2)

    async def on_skip(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_review(btn_inter, state)

    skip_btn.callback = on_skip
    view.add_item(skip_btn)

    slots_desc = ", ".join(f"{el}: {cnt}" for el, cnt in remaining.items() if cnt > 0)
    await interaction.response.edit_message(
        content=f"**Step 9/10 — Starting Spells** · Remaining slots: {slots_desc}. "
                f"(Sense, Commune, Summon are auto-granted.)",
        embed=_chargen_embed(state), view=view,
    )


# --- Step 10: Review & Submit ---
async def _chargen_review(interaction: discord.Interaction, state: dict) -> None:
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
        embed.set_footer(text=f"Warning: {remaining} XP unspent! Consider spending it before submitting.")

    sch = schools.get(state.get("school_name", "")) if state.get("school_name") else None
    school_report = schools.apply_to_character(Character(), sch) if sch else None
    wildcards = school_report.get("wildcards", []) if school_report else []
    if wildcards:
        embed.add_field(name="Wildcard Skills (DM assigns)",
                        value="\n".join(f"- {w}" for w in wildcards)[:1024], inline=False)

    view = _ChargenView(state)
    submit_btn = discord.ui.Button(label="Submit for Approval", style=discord.ButtonStyle.success, emoji="📋", row=0)
    back_traits_btn = discord.ui.Button(label="Back: Traits", style=discord.ButtonStyle.secondary, row=1)
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

    async def on_back_skills(btn_inter: discord.Interaction) -> None:
        if btn_inter.user.id != int(state["user_id"]):
            await btn_inter.response.send_message("This isn't your wizard.", ephemeral=True)
            return
        await _chargen_skills(btn_inter, state)

    submit_btn.callback = on_submit
    back_traits_btn.callback = on_back_traits
    back_skills_btn.callback = on_back_skills
    view.add_item(submit_btn)
    view.add_item(back_traits_btn)
    view.add_item(back_skills_btn)

    await interaction.response.edit_message(
        content="**Step 10/10 — Review** · Check your character below, then submit for DM approval.",
        embed=embed, view=view,
    )


async def _submit_for_approval(interaction: discord.Interaction, state: dict) -> None:
    """Send the completed character to the approval channel for DM review."""
    guild_id = state["guild_id"]
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
    await approval_ch.send(embed=embed, view=view)

    for child in interaction.message.view.children:
        child.disabled = True
    await interaction.response.edit_message(
        content=f"📋 Your character **{state['name']}** has been submitted for DM review! "
                f"You'll be notified when a decision is made.",
        embed=None, view=None,
    )


class _FullCharacterApprovalView(discord.ui.View):
    """DM approval view for fully-built character sheets from the wizard."""

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

        await member.add_roles(approved_role,
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

        for child in self.children:
            child.disabled = True
        self.stop()
        await interaction.response.edit_message(view=self)

        embed = discord.Embed(
            title="✅ Character Approved (Full Sheet)",
            color=discord.Color.green(),
            description=(
                f"**{member.mention}**'s character **{state['name']}** has been approved.\n"
                f"Full character sheet created with all traits, skills, advantages, "
                f"and spells applied.{nick_note}"
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
        for child in self.children:
            child.disabled = True
        self.stop()
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
        lobby = client.get_channel(self.lobby_channel_id)
        if lobby and member:
            await lobby.send(
                f"❌ {member.mention}, your character **{self.character_state['name']}** was not approved. "
                f"Please speak with a DM for details and feel free to submit again."
            )


@sheet.command(name="wizard", description="Step-by-step guided character creation.")
@app_commands.describe(name="Your character's name.")
async def sheet_wizard(
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
    view.add_item(_ClanSelect(state))
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
    await interaction.response.send_message(embed=build_sheet_embed(rec))

@sheet.command(name="list", description="List your characters (or a player's, if you are a DM).")
@app_commands.describe(member="Whose characters to list (Fortune). Omit for your own.")
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
        f"{'▶️ ' if r.id == active_id else '• '}**{r.character.name}** "
        f": {r.character.clan or ' '} {r.character.school_type}"
        for r in records
    ]
    await interaction.response.send_message(
        f"Characters for {target.display_name}:\n" + "\n".join(lines), ephemeral=True
    )

@sheet.command(name="activate", description="Set which of your characters is active.")
@app_commands.describe(name="The character name to activate.")
@app_commands.autocomplete(name=_own_character_autocomplete)
async def sheet_activate(interaction: discord.Interaction, name: str) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    owner = str(interaction.user.id)
    rec = store.get_by_name(guild, owner, name)
    if rec is None:
        await interaction.response.send_message(
            f"You have no character named **{name}**.", ephemeral=True
        )
        return
    store.set_active(guild, owner, rec.id)
    await interaction.response.send_message(
        f"**{rec.character.name}** is now your active character.", ephemeral=True
    )

@sheet.command(name="delete", description="Delete a character (yours, or a player's if you are a DM).")
@app_commands.describe(name="Character name.", member="Owner of the character (Fortune).")
@app_commands.autocomplete(name=_own_character_autocomplete)
async def sheet_delete(
    interaction: discord.Interaction, name: str, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    owner_target = interaction.user
    if member is not None and member.id != interaction.user.id:
        if not await _require_dm_role(interaction):
            return
        owner_target = member
    rec = store.get_by_name(guild, str(owner_target.id), name)
    if rec is None:
        await interaction.response.send_message(f"No character named **{name}** found.", ephemeral=True)
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
        store.delete(self._record.id)
        self.stop()
        await interaction.response.edit_message(
            content=f"🗑️ Deleted **{self._record.character.name}** permanently.", view=None
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

@stat_group.command(name="trait", description="Set a Trait (or Void) on the active character.")
@app_commands.describe(
    trait="Which Trait to set.", value="New value (0-10).",
    member="Target player (Fortune). Omit for your own active character.",
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
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.set_trait(trait.value, value)
    rank_msg = _check_insight_rank_advance(rec.character)
    store.save(rec)
    label = "Void" if trait.value == "void" else trait.value.capitalize()
    await interaction.response.send_message(
        f"Set **{label}** to **{value}** on **{rec.character.name}**.{rank_msg}", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="skill", description="Set skill ranks. Single: skill='Kenjutsu' rank=3. Bulk: skill='Kenjutsu 3, Courtier 2'.")
@app_commands.describe(
    skill="Skill name, or bulk list: 'Kenjutsu 3, Courtier 2, Etiquette 1'.",
    rank="Rank 0-10 (0 removes). Omit when using bulk format.",
    member="Target player (Fortune). Omit for your own active character.",
)
async def sheet_skill(
    interaction: discord.Interaction,
    skill: app_commands.Range[str, 1, 200],
    rank: app_commands.Range[int, 0, 10] | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
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
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="set", description="Set a numeric field (honor, glory, void points, armor, etc.).")
@app_commands.describe(
    field="Which field to set.", value="New value.",
    member="Target player (Fortune). Omit for your own active character.",
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
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    _apply_numeric_field(rec.character, field.value, value)
    store.save(rec)
    await interaction.response.send_message(
        f"Updated **{field.value}** on **{rec.character.name}**.", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="equip", description="Add (or remove) a weapon on your character's gear.")
@app_commands.describe(weapon="Weapon name.", remove="Remove it instead of adding.", member="Target player (Fortune).")
@app_commands.autocomplete(weapon=_weapon_autocomplete)
async def sheet_equip(
    interaction: discord.Interaction,
    weapon: str,
    remove: bool = False,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    w = weapon.lower().strip()
    c = rec.character
    if remove:
        c.weapons = [x for x in c.weapons if x.lower() != w]
        msg = f"Removed **{w}** from **{c.name}**."
    else:
        if w not in combat.WEAPON_CATALOG:
            await interaction.response.send_message(
                f"Unknown weapon **{weapon}**: see `/weapon list`.", ephemeral=True
            )
            return
        if w not in [x.lower() for x in c.weapons]:
            c.weapons.append(w)
        prof = combat.WEAPON_CATALOG[w]
        msg = f"**{c.name}** equips **{w}** (DR {prof['rolled']}k{prof['kept']}, {prof['skill']})."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="wield", description="Set the weapon(s) you're wielding:/attack's default weapon and defender Kata gates (s30).")
@app_commands.describe(
    weapon="Main-hand weapon (start typing for suggestions).",
    off_hand="Off-hand weapon, e.g. wakizashi for a daisho. Blank clears the off hand.",
    unwield="Lower both weapons (go unarmed).",
    member="Target player (Fortune).",
)
@app_commands.autocomplete(weapon=_weapon_autocomplete, off_hand=_weapon_autocomplete)
async def sheet_wield(
    interaction: discord.Interaction,
    weapon: str | None = None,
    off_hand: str | None = None,
    unwield: bool = False,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if unwield:
        c.equipped_weapon = ""
        c.off_hand_weapon = ""
        store.save(rec)
        await interaction.response.send_message(
            f"**{c.name}** lowers their weapons (unarmed).", embed=build_sheet_embed(rec)
        )
        return
    if weapon is not None and weapon.strip():
        c.equipped_weapon = weapon.lower().strip()
    if not c.equipped_weapon:
        await interaction.response.send_message(
            "Give a `weapon:` to wield, or `unwield:true` to go unarmed.", ephemeral=True
        )
        return
    c.off_hand_weapon = off_hand.lower().strip() if off_hand and off_hand.strip() else ""
    store.save(rec)
    off = f" + **{c.off_hand_weapon}** (off hand)" if c.off_hand_weapon else ""
    await interaction.response.send_message(
        f"🗡️ **{c.name}** wields **{c.equipped_weapon}**{off}.", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="armor", description="Equip armor (sets Armor TN bonus & Reduction), or 'none' to remove.")
@app_commands.describe(armor="Armor type (bogu/ashigaru/tatami/light/heavy/tetsu_do/riding, or 'none').", member="Target player (Fortune).")
@app_commands.autocomplete(armor=_armor_autocomplete)
async def sheet_armor(
    interaction: discord.Interaction,
    armor: str,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    a = armor.lower().strip()
    if a in ("none", "", "remove"):
        c.armor_name = ""
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
        c.armor_tn_bonus = spec["tn_bonus"]
        c.armor_reduction = spec["reduction"]
        heavy = " (heavy)" if spec["is_heavy"] else ""
        cost_note = f" · {spec['cost']} koku" if spec.get("cost") else ""
        msg = f"**{c.name}** equips **{a}**{heavy}: Armor TN +{spec['tn_bonus']}, Reduction {spec['reduction']}{cost_note}."
        if spec.get("special"):
            msg += f"\n⚠️ {spec['special']}"
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

_QUALITY_CHOICES = [
    app_commands.Choice(name=q.title(), value=q) for q in sorted(combat.WEAPON_QUALITIES)
]

async def _quality_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    low = current.lower()
    return [c for c in _QUALITY_CHOICES if low in c.value][:25]

@stat_group.command(name="quality", description="Set extraordinary weapon qualities on the equipped weapon (s39 crafting).")
@app_commands.describe(
    qualities="Comma-separated qualities: balanced, radiant, signature, swift, true, unbreakable.",
    clear="Remove all weapon qualities.",
    member="Target player (Fortune).",
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
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if clear:
        c.weapon_qualities = []
        store.save(rec)
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
    store.save(rec)
    q_list = ", ".join(c.weapon_qualities)
    wpn = c.equipped_weapon or "(no weapon equipped)"
    await interaction.response.send_message(
        f"**{c.name}** weapon qualities set: **{q_list}** (on {wpn}).", embed=build_sheet_embed(rec)
    )

@stat_group.command(name="item", description="Add or remove items from your inventory (quantity supported).")
@app_commands.describe(
    name="Item name.", quantity="How many (default 1).",
    remove="Remove instead of adding.", member="Target player (Fortune).",
)
async def sheet_item(
    interaction: discord.Interaction, name: str,
    quantity: app_commands.Range[int, 1, 9999] = 1,
    remove: bool = False, member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    item_name = name.strip()
    match_key = next((k for k in c.inventory if k.lower() == item_name.lower()), None)
    if remove:
        if match_key is None:
            await interaction.response.send_message(f"**{c.name}** doesn't have **{item_name}**.", ephemeral=True)
            return
        current = c.inventory[match_key]
        remaining = current - quantity
        if remaining <= 0:
            del c.inventory[match_key]
            msg = f"Removed all **{match_key}** from **{c.name}**'s inventory."
        else:
            c.inventory[match_key] = remaining
            msg = f"Removed {quantity}× **{match_key}** from **{c.name}** ({remaining} left)."
    else:
        key = match_key or item_name
        c.inventory[key] = c.inventory.get(key, 0) + quantity
        total = c.inventory[key]
        msg = f"Added {quantity}× **{key}** to **{c.name}** (now {total})."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="koku", description="Add or spend koku (money). Negative amount spends.")
@app_commands.describe(
    amount="Koku to add (positive) or spend (negative).",
    reason="Why (e.g. 'bought katana', 'reward from lord').",
    member="Target player (Fortune).",
)
async def sheet_koku(
    interaction: discord.Interaction,
    amount: float,
    reason: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if amount < 0 and c.koku + amount < 0:
        await interaction.response.send_message(
            f"**{c.name}** only has **{c.koku:g}** koku (tried to spend {abs(amount):g}).", ephemeral=True
        )
        return
    c.koku += amount
    c.koku = round(c.koku, 2)
    if amount >= 0:
        label = f"Received **{amount:g}** koku"
    else:
        label = f"Spent **{abs(amount):g}** koku"
    why = f" ({reason})" if reason else ""
    msg = f"\U0001F4B0 **{c.name}**: {label}{why}. Balance: **{c.koku:g}** koku."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="advantage", description="Record (or remove) an Advantage on your sheet (free: no XP).")
@app_commands.describe(
    name="Advantage name. For parameterised advantages, include the parameter: 'Weakness: Willpower', 'Seven Fortunes' Blessing: Daikoku'.",
    remove="Remove it instead.",
    member="Target player (Fortune).",
)
@app_commands.autocomplete(name=_advantage_autocomplete)
async def sheet_advantage(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
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
    canonical = adv["name"] if adv else base_name
    if ":" in input_name:
        param = input_name[input_name.index(":") + 1:].strip()
        canonical = f"{canonical}: {param}"
    c = rec.character
    if remove:
        c.advantages = [x for x in c.advantages if x.lower() != canonical.lower()]
        msg = f"Removed advantage **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.advantages]:
            c.advantages.append(canonical)
        msg = f"**{c.name}** gains the advantage **{canonical}**."
        param_hint = advantage_effects.PARAMETERISED_ADVANTAGES.get(adv["name"] if adv else base_name)
        if param_hint and ":" not in input_name:
            msg += f"\n*Hint: this advantage can be parameterised. Use `{canonical}: <{param_hint}>` to record the chosen option.*"
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@stat_group.command(name="disadvantage", description="Record (or remove) a Disadvantage on your sheet (grants XP: DM /xp grant).")
@app_commands.describe(
    name="Disadvantage name. For parameterised disadvantages, include the parameter: 'Weakness: Willpower', 'Doubt: Kenjutsu'.",
    remove="Remove it instead.",
    member="Target player (Fortune).",
)
@app_commands.autocomplete(name=_disadvantage_autocomplete)
async def sheet_disadvantage(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    input_name = name.strip()
    base_name = input_name.split(":")[0].strip() if ":" in input_name else input_name
    dis = advantages.get(base_name, "disadvantage")
    canonical = dis["name"] if dis else base_name
    if ":" in input_name:
        param = input_name[input_name.index(":") + 1:].strip()
        canonical = f"{canonical}: {param}"
    c = rec.character
    if remove:
        c.disadvantages = [x for x in c.disadvantages if x.lower() != canonical.lower()]
        msg = f"Removed disadvantage **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.disadvantages]:
            c.disadvantages.append(canonical)
        grant = f" (grants {dis['points']} XP: a DM applies it with `/xp grant`)" if dis and dis["points"] else ""
        msg = f"**{c.name}** takes the disadvantage **{canonical}**{grant}."
        param_hint = advantage_effects.PARAMETERISED_DISADVANTAGES.get(dis["name"] if dis else base_name)
        if param_hint and ":" not in input_name:
            msg += f"\n*Hint: this disadvantage can be parameterised. Use `{canonical}: <{param_hint}>` to record the chosen option.*"
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@sheet_kata_grp.command(name="learn", description="Record (or remove) a Kata on your sheet (free: no XP; use /xp kata to buy).")
@app_commands.describe(name="Kata name.", remove="Remove it instead.", member="Target player (Fortune).")
@app_commands.autocomplete(name=_kata_autocomplete)
async def sheet_kata(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
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

@sheet_kiho_grp.command(name="learn", description="Record (or remove) a Kiho on your sheet (free: no XP; use /xp kiho to buy).")
@app_commands.describe(name="Kiho name.", remove="Remove it instead.", member="Target player (Fortune).")
@app_commands.autocomplete(name=_kiho_autocomplete)
async def sheet_kiho(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not await _require_guild(interaction):
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

@sheet_kata_grp.command(name="activate", description="Set your active Kata (Simple Action; only one active: s30). Blank name drops it.")
@app_commands.describe(
    name="A Kata your character knows. Leave blank to drop the active Kata.",
    member="Target player (Fortune).",
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
    c = rec.character
    if not name or not name.strip():
        prev = c.active_kata
        c.active_kata = ""
        store.save(rec)
        tail = f" (**{prev}**)" if prev else ""
        await interaction.response.send_message(
            f"**{c.name}** drops their active Kata{tail}.", embed=build_sheet_embed(rec)
        )
        return
    k = kata.get(name)
    canonical = k["name"] if k else name.strip()
    if canonical.lower() not in [x.lower() for x in c.katas]:
        await interaction.response.send_message(
            f"**{c.name}** hasn't learned the Kata **{canonical}**: add it with `/sheet kata` "
            f"or buy it with `/xp kata`.", ephemeral=True,
        )
        return
    c.active_kata = canonical
    store.save(rec)
    note = (
        "" if kata_effects.is_auto(canonical)
        else " *(its effect is DM-adjudicated: shown as a reminder on attacks.)*"
    )
    await interaction.response.send_message(
        f"🥋 **{c.name}** assumes the Kata **{canonical}**.{note}", embed=build_sheet_embed(rec)
    )

@sheet_kiho_grp.command(name="activate", description="Activate/deactivate a Kiho (one Internal/Kharmic/Mystical; Martial stacks: s38).")
@app_commands.describe(
    name="A Kiho your character knows.",
    off="Deactivate it instead.",
    member="Target player (Fortune).",
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
    c = rec.character
    h = kiho.get(name)
    canonical = h["name"] if h else name.strip()
    if off:
        c.active_kiho = [x for x in c.active_kiho if x.lower() != canonical.lower()]
        store.save(rec)
        await interaction.response.send_message(
            f"**{c.name}** ends the Kiho **{canonical}**.", embed=build_sheet_embed(rec)
        )
        return
    if canonical.lower() not in [x.lower() for x in c.kiho]:
        await interaction.response.send_message(
            f"**{c.name}** hasn't learned the Kiho **{canonical}**: add it with `/sheet kiho` "
            f"or buy it with `/xp kiho`.", ephemeral=True,
        )
        return
    # s38: only one Internal, one Kharmic, one Mystical may be active; Martial stacks.
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
    store.save(rec)
    tlabel = h["type"] if h and h.get("type") else "Kiho"
    await interaction.response.send_message(
        f"✋ **{c.name}** activates the {tlabel} Kiho **{canonical}**{replaced}. "
        f"*(Activation cost: a Void Point or Meditation/Void roll: and duration are "
        f"DM-adjudicated; its combat effect is shown as a reminder on attacks.)*",
        embed=build_sheet_embed(rec),
    )

@sheet.command(name="wound", description="Apply wounds to the active character (raw, no armor reduction here).")
@app_commands.describe(
    amount="Wounds to apply.",
    member="Target player (Fortune). Omit for your own active character.",
)
async def sheet_wound(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    old = stats.wound_level_name(c)
    c.wounds_taken += amount
    store.save(rec)
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    dead = "  💀 **DEAD**" if stats.is_dead(c) else ""
    await interaction.response.send_message(
        f"**{c.name}** takes **{amount}** wounds → {c.wounds_taken} total{crossed}{dead}",
        embed=build_sheet_embed(rec),
    )

@sheet.command(name="heal", description="Heal wounds on the active character.")
@app_commands.describe(
    amount="Wounds to heal.",
    member="Target player (Fortune). Omit for your own active character.",
)
async def sheet_heal(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    old = stats.wound_level_name(c)
    c.wounds_taken = max(0, c.wounds_taken - amount)
    store.save(rec)
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
        ("/room create", "Create a private play room (thread, optional description)"),
        ("/room describe", "Set or update the pinned room description"),
        ("/room invite / kick", "Add or remove room members"),
        ("/room list / members / close", "List, inspect, or close rooms"),
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
        ("/assess fear / honor", "Fear or Honor Roll"),
        ("/assess stealth / investigate", "Stealth or Investigation"),
        ("/assess social", "Social skill check (auto-selects trait)"),
        ("/examine craft / lore", "Craft or Lore check"),
        ("/examine poison / medicine", "Poison resistance or Medicine"),
        ("/examine horsemanship", "Mounted maneuver check"),
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
    ("\U0001f6e0️", "Admin (Kami Only)", "Server administration commands.", [
        ("/dm log_channel", "Set combat event log channel"),
        ("/dm clear_log", "Stop combat event logging"),
        ("/dm approval_channel", "Set DM-approval channel for damage/healing"),
        ("/dm clear_approval", "Stop routing approvals to a channel"),
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

SPELL_ELEMENTS = ("air", "earth", "fire", "water", "void")

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
        healed = 0
        rate = stats.natural_healing_rate(c)
        if c.wounds_taken > 0:
            old_wounds = c.wounds_taken
            c.wounds_taken = max(0, c.wounds_taken - rate)
            healed = old_wounds - c.wounds_taken
        if healed > 0:
            parts.append(f"healed {healed} wounds ({c.wounds_taken} left)")
        vp_old = c.current_void_points
        c.current_void_points = c.max_void_points
        if vp_old < c.max_void_points:
            parts.append(f"VP {vp_old} → {c.max_void_points}/{c.max_void_points}")
        for element in SPELL_ELEMENTS:
            c.spell_slots[element] = stats.spell_slot_max(c, element)
        c.void_spell_bonus = stats.void_bonus_max(c)
        store.save(rec)
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
    footer = "Rest: full VP · Stamina x 2 healing · Spell slots: Ring + School Rank per element"
    if date_str:
        embed.add_field(name="Calendar", value=date_str, inline=False)
    else:
        footer += " · Set the date with /dm setdate"
    embed.set_footer(text=footer)
    await interaction.response.send_message(embed=embed)
    if date_str:
        await _update_date_display(guild, date_str, reason="A new day dawns in Rokugan.")

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

@dm.command(name="setdate", description="Set the Rokugani calendar date (Fortune+).")
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
    rec = store.get_by_name(guild, NPC_OWNER, target)
    if rec is None:
        for _, pc_rec in store.list_active_pcs(guild):
            if pc_rec.character.name.lower() == target.lower():
                rec = pc_rec
                break
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
    approval_ch_id = store.get_approval_channel(guild)
    approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
    src_ch_id = interaction.channel_id if approval_ch else 0
    view = DmDamageView(
        target_id=rec.id, target_name=c.name,
        amount=amount, reason=reason,
        source_channel_id=src_ch_id,
    )
    if approval_ch:
        embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
        embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
        await approval_ch.send(content="A DM can authorize the damage below.", embed=embed, view=view)
        await interaction.response.send_message(
            f"💥 Pending damage on **{c.name}** — approval routed to the DM channel."
        )
    else:
        await interaction.response.send_message(
            content="A DM can authorize the damage below.",
            embed=embed, view=view,
        )

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
    rec = store.get_by_name(guild, NPC_OWNER, target)
    if rec is None:
        for _, pc_rec in store.list_active_pcs(guild):
            if pc_rec.character.name.lower() == target.lower():
                rec = pc_rec
                break
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
    approval_ch_id = store.get_approval_channel(guild)
    approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
    src_ch_id = interaction.channel_id if approval_ch else 0
    view = DmHealView(
        target_id=rec.id, target_name=c.name,
        amount=amount, reason=reason,
        source_channel_id=src_ch_id,
    )
    if approval_ch:
        embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
        embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
        await approval_ch.send(content="A DM can authorize the healing below.", embed=embed, view=view)
        await interaction.response.send_message(
            f"💚 Pending healing on **{c.name}** — approval routed to the DM channel."
        )
    else:
        await interaction.response.send_message(
            content="A DM can authorize the healing below.",
            embed=embed, view=view,
        )

# ===========================================================================
# /grapple group: grappling subsystem (s40)
# ===========================================================================

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
    npc_name="NPC name (Fortune).",
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
    store.save(rec)
    await interaction.response.send_message(
        f"🌀 **{c.name}** spends a Void Point: {reason}\n"
        f"  VP remaining: **{c.current_void_points}/{c.max_void_points}**"
    )

@sheet_void.command(name="refresh", description="Refresh Void Points (rest = full, or Meditation/Void check for 1).")
@app_commands.describe(
    mode="How VP are being refreshed.",
    member="Player refreshing (uses their active character). Omit = yourself.",
    npc_name="NPC name (Fortune).",
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
    if mode.value == "rest":
        old = c.current_void_points
        c.current_void_points = c.max_void_points
        store.save(rec)
        await interaction.response.send_message(
            f"🌀 **{c.name}** rests and recovers all Void Points.\n"
            f"  VP: {old} → **{c.current_void_points}/{c.max_void_points}**"
        )
    else:
        if c.current_void_points >= c.max_void_points:
            await interaction.response.send_message(
                f"**{c.name}** is already at full VP ({c.current_void_points}/{c.max_void_points}).",
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
            c.current_void_points = min(c.current_void_points + 1, c.max_void_points)
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
    npc_name="NPC name (Fortune).",
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
    bar_full = "🟣" * c.current_void_points
    bar_empty = "⚫" * (c.max_void_points - c.current_void_points)
    await interaction.response.send_message(
        f"🌀 **{c.name}**: Void Points: **{c.current_void_points}/{c.max_void_points}**\n"
        f"  {bar_full}{bar_empty}\n"
        f"  Void Ring: **{c.void_ring}**",
        ephemeral=True,
    )

# ===========================================================================
# /help: categorized command reference
# ===========================================================================

_HELP_CATEGORIES: list[tuple[str, list[tuple[str, str]]]] = [
    ("Dice & Basics", [
        ("/ping", "Check the bot is alive (shows gateway latency)."),
        ("/whoami", "Quick glance at your active character's status."),
        ("/date", "Show the current in-game Rokugani calendar date."),
        ("/roll", "Roll & Keep: XkY, optional TN, raises, emphasis, unskilled."),
        ("/dice", "Quick shorthand: '5k3', '7k2+5'. Same as /roll but faster."),
        ("/macro save / list / roll / delete", "Save and reuse frequent dice pools."),
        ("/compare", "Side-by-side character comparison."),
        ("/history", "Recent dice rolls in this channel."),
        ("/help", "Show all bot commands, organized by category."),
    ]),
    ("Character Sheets", [
        ("/sheet wizard", "Step-by-step guided character creation."),
        ("/sheet create", "Create a character (optionally with a school)."),
        ("/sheet view", "View a sheet (yours or another player's if Fortune)."),
        ("/sheet list / activate / delete", "Manage your characters."),
        ("/stat trait / skill / set", "Set Traits, skills, or numeric fields."),
        ("/sheet wound / heal", "Apply or heal wounds."),
        ("/stat equip / wield / armor / quality", "Manage gear, equipment, and weapon qualities."),
        ("/stat item", "Add or remove inventory items with quantities."),
        ("/stat koku", "Add or spend koku (money management)."),
        ("/stat advantage / disadvantage", "Record advantages or disadvantages."),
        ("/sheet kata learn / activate", "Record or activate Kata."),
        ("/sheet kiho learn / activate", "Record or activate Kiho."),
        ("/sheet learn", "Record techniques up to your School Rank."),
        ("/sheet data export / import_sheet", "Backup and restore characters."),
        ("/sheet void spend / refresh / status", "Manage Void Points."),
        ("/xp grant / balance / trait / skill / ...", "XP and advancement."),
    ]),
    ("DM Management (Fortune/Kami)", [
        ("/dm wizard", "Interactive command menu: browse all DM actions by category."),
        ("/dm roles", "Show who has the Fortune and Kami roles."),
        ("/dm party", "Overview of all active PCs."),
        ("/dm new_day", "Advance to a new day: refresh spell slots & heal all PCs."),
        ("/dm setdate", "Set the Rokugani calendar date."),
        ("/dm damage / heal / treat", "Apply damage, heal wounds, or run Medicine checks."),
        ("/dm taint", "View or modify a character's Shadowlands Taint."),
        ("/dm influence", "Track court Influence Points."),
        ("/dm craft_extended", "Multi-step extended crafting rolls with quality tiers."),
        ("/dm log_channel / clear_log", "Combat event logging (Kami only)."),
        ("/npc generate / view / list / ...", "Generate and manage NPC samurai."),
        ("/npc place / dismiss / say", "Place NPCs in rooms and speak as them."),
        ("/npc-edit trait / skill / equip / ...", "Edit NPC stats and gear."),
        ("/creature catalog / spawn / attack / ...", "Bestiary creature management."),
        ("/room create / invite / kick / ...", "Private play rooms."),
        ("/category create / add / list / ...", "Organise NPCs and creatures into groups."),
    ]),
    ("Checks (Fortune)", [
        ("/check skill", "Generic Skill/Trait check (DM picks trait)."),
        ("/check contest", "Contested Skill/Trait roll between two characters."),
        ("/check cooperative", "Cooperative check: helpers roll at TN+5, success gives +1k0."),
        ("/assess fear / honor", "Fear or Honor Roll."),
        ("/assess stealth / investigate / social", "Stealth, Investigation, or Social checks."),
        ("/examine craft / lore", "Craft/Intelligence or Lore/Intelligence."),
        ("/examine poison / medicine", "Poison resistance or Medicine check."),
        ("/examine horsemanship", "Horsemanship/Agility (mounted maneuver)."),
    ]),
    ("Combat", [
        ("/fight attack", "Attack a character, NPC, or creature."),
        ("/combat start / end", "Start or end an encounter."),
        ("/combat join / add / npc / creature", "Add combatants to initiative."),
        ("/combat next / status / remove / summary", "Manage turn order."),
        ("/fight stance / guard / full_defense", "Stances and defensive actions."),
        ("/combat condition set / clear / list", "Manage conditions on combatants."),
        ("/combat turn init / hold / delay / act / surprise", "Advanced initiative (Fortune)."),
        ("/fight action / mount", "Action tracking and mounting."),
        ("/fight env cover / notes / damage", "Environment effects on combatants."),
        ("/engage grapple initiate / control / hit / throw / pin / break_free", "Grappling (Fortune)."),
        ("/engage duel assess / focus / strike", "Iaijutsu dueling (Fortune)."),
        ("/engage battle roll / damage", "Mass Battle engagement and damage."),
    ]),

    ("Spells", [
        ("/spell list / search / view", "Browse 287 spells."),
        ("/spell cast", "Cast a spell: (Ring + School Rank) keep Ring. Conceal with Stealth."),
        ("/spell resist", "Spell resistance: Willpower roll vs TN (Fortune)."),
        ("/spell interrupt", "Willpower check when caster is hit mid-cast (Fortune)."),
        ("/spell importune", "Entreat kami for an unknown spell: Spellcraft + cast at higher TN."),
        ("/spell damage", "Roll spell damage dice (Fortune)."),
    ]),
    ("Reference (/ref)", [
        ("/ref search", "Search all catalogs at once (spells, schools, kata, etc.)."),
        ("/ref weapon list / view", "Browse the 44 weapons."),
        ("/ref armor list / view / search", "Browse the 7 armor types (TN, Reduction, cost, specials)."),
        ("/ref school list / search / view", "Browse 347 schools and techniques."),
        ("/ref advantage list / search / view", "Browse 149 advantages & disadvantages."),
        ("/ref kata list / search / view", "Browse 43 Kata."),
        ("/ref kiho list / search / view", "Browse 73 Kiho."),
        ("/ref family list / search", "Browse 47 families and Trait bonuses."),
        ("/ref heritage roll / table", "Heritage Table rolls (Great Clans)."),
        ("/ref modifiers / calledshot", "Combat modifier and Called Shot reference."),
        ("/ref atn / encumbrance", "Armor TN breakdown and carrying capacity."),
        ("/ref ancestors / dual_wield / travel", "Other reference info."),
    ]),

]

@client.tree.command(
    name="help",
    description="Show all bot commands, organized by category.",
)
@app_commands.describe(
    category="Show only this category (omit for the full overview).",
)
@app_commands.choices(category=[
    app_commands.Choice(name=cat, value=cat) for cat, _ in _HELP_CATEGORIES
])
async def help_command(
    interaction: discord.Interaction,
    category: app_commands.Choice[str] | None = None,
) -> None:
    if category:
        for cat_name, cmds in _HELP_CATEGORIES:
            if cat_name == category.value:
                embed = discord.Embed(
                    title=f"Rokugan Bot: {cat_name}",
                    color=discord.Color.gold(),
                )
                lines = [f"`{cmd}`: {desc}" for cmd, desc in cmds]
                embed.description = "\n".join(lines)
                await interaction.response.send_message(embed=embed, ephemeral=True)
                return
        await interaction.response.send_message("Category not found.", ephemeral=True)
        return

    embed = discord.Embed(
        title="Rokugan Bot: Command Reference",
        description="Use `/help category:` to expand a section. All game math is L5R 4th Edition RAW.",
        color=discord.Color.gold(),
    )
    for cat_name, cmds in _HELP_CATEGORIES:
        summary = ", ".join(f"`{cmd}`" for cmd, _ in cmds[:4])
        if len(cmds) > 4:
            summary += f" *… +{len(cmds) - 4} more*"
        embed.add_field(name=f"{cat_name} ({len(cmds)})", value=summary, inline=False)
    embed.set_footer(text="Tip: /help category:Combat to see all combat commands.")
    await interaction.response.send_message(embed=embed, ephemeral=True)

# ===========================================================================
# /npc group: generate and manage NPC characters (s22.4 templates)
# ===========================================================================

@npc_group.command(name="generate", description="Generate an NPC samurai from a Clan/Family/School/Rank template. Fortune role required.")
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
        if not school_skills:
            assigned, _ = schools.parse_skills(catalog.get("skills", ""))
            school_skills = [nm for nm, _r, _e in assigned]
        if base_honor is None:
            base_honor = schools.parse_honor(catalog.get("honor", ""))
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
            "No NPCs yet. Create one with `/npc generate` (Fortune).", ephemeral=True
        )
        return
    lines = [
        f"• **{r.character.name}**: {r.character.clan or ' '} {r.character.school_type} "
        f"(Rank {r.character.school_rank})"
        for r in recs
    ]
    pages = _paginate(lines, "🎭 **NPCs on this server: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0])
    else:
        view = _PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view)

@npc_group.command(name="delete", description="Delete a stored NPC. Fortune role required.")
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
    if not _guild_ok(interaction):
        return None, "Please use this in a server channel."
    if not _is_dm(interaction):
        return None, f"You need the **{ROLE_FORTUNE}** (or **{ROLE_KAMI}**) role to edit NPCs."
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        return None, f"No NPC named **{name}**."
    return rec, None

@npc_edit_group.command(name="trait", description="Set a Trait (or Void) on an NPC. Fortune role required.")
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

@npc_edit_group.command(name="skill", description="Set a skill rank on an NPC (0 removes it). Fortune role required.")
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

@npc_edit_group.command(name="set", description="Set a numeric field on an NPC (honor, armor, void points, etc.). Fortune role required.")
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

@npc_edit_group.command(name="wound", description="Apply wounds to an NPC. Fortune role required.")
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
    old = stats.wound_level_name(c)
    c.wounds_taken += amount
    store.save(rec)
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    dead = "  💀 **DEAD**" if stats.is_dead(c) else ""
    await interaction.response.send_message(
        f"**{c.name}** takes **{amount}** wounds → {c.wounds_taken} total{crossed}{dead}",
        embed=build_sheet_embed(rec),
    )

@npc_edit_group.command(name="heal", description="Heal wounds on an NPC. Fortune role required.")
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
    old = stats.wound_level_name(c)
    c.wounds_taken = max(0, c.wounds_taken - amount)
    store.save(rec)
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    await interaction.response.send_message(
        f"**{c.name}** heals **{amount}** wounds → {c.wounds_taken} total{crossed}",
        embed=build_sheet_embed(rec),
    )

@npc_group.command(name="rename", description="Rename an NPC. Fortune role required.")
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

@npc_group.command(name="place", description="Place an NPC in this room (run inside a room thread). Fortune role required.")
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

@npc_group.command(name="dismiss", description="Remove an NPC from this room. Fortune role required.")
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

@npc_group.command(name="say", description="Speak as an NPC (posts as their name via webhook). Fortune role required.")
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

@npc_edit_group.command(name="item", description="Add or remove items from an NPC's inventory. Fortune role required.")
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
    item_name = item.strip()
    match_key = next((k for k in c.inventory if k.lower() == item_name.lower()), None)
    if remove:
        if match_key is None:
            await interaction.response.send_message(f"**{c.name}** doesn't have **{item_name}**.", ephemeral=True)
            return
        current = c.inventory[match_key]
        remaining = current - quantity
        if remaining <= 0:
            del c.inventory[match_key]
            msg = f"Removed all **{match_key}** from **{c.name}**'s inventory."
        else:
            c.inventory[match_key] = remaining
            msg = f"Removed {quantity}× **{match_key}** from **{c.name}** ({remaining} left)."
    else:
        key = match_key or item_name
        c.inventory[key] = c.inventory.get(key, 0) + quantity
        total = c.inventory[key]
        msg = f"Added {quantity}× **{key}** to **{c.name}** (now {total})."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@npc_edit_group.command(name="spell", description="Add or remove a spell from an NPC's known spell list. Fortune role required.")
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

@npc_group.command(name="notes", description="Set or clear notes on an NPC. Fortune role required.")
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

@npc_group.command(name="clone", description="Clone an NPC with a new name. Fortune role required.")
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

@npc_edit_group.command(name="equip", description="Set an NPC's equipped weapon and/or armor name. Fortune role required.")
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
            c.armor_tn_bonus = 0
            c.armor_reduction = 0
            changes.append("Armor: **(none)**")
        else:
            spec = combat.get_armor(a)
            if spec is not None:
                c.armor_name = a
                c.armor_tn_bonus = spec["tn_bonus"]
                c.armor_reduction = spec["reduction"]
                changes.append(f"Armor: **{a}** (ATN+{spec['tn_bonus']}, Red {spec['reduction']})")
            else:
                c.armor_name = a
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

@npc_edit_group.command(name="affinity", description="Set an NPC's affinity and/or deficiency element. Fortune role required.")
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
        f"Play happens here:`/sheet`, `/roll`, `/attack`, and `/combat` all work inside this room."
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

@room_group.command(name="close", description="Close this room (archives the thread). Host or Fortune role required.")
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

class CreatureAttackView(discord.ui.View):
    """DM-only button: apply a creature's fixed damage to a character it hit."""

    def __init__(self, creature_id: int, target_char_id: int, creature_name: str, target_name: str) -> None:
        super().__init__(timeout=1800)
        self.creature_id = creature_id
        self.target_char_id = target_char_id
        self.creature_name = creature_name
        self.target_name = target_name

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Creature Damage", style=discord.ButtonStyle.danger, emoji="👹")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
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
        store.save(target_rec)
        c = target_rec.character
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
            status += "  💀 **DEAD**"
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
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} ruled no damage from {self.creature_name}."
        )

class SpellDamageView(discord.ui.View):
    """DM-approval gate for spell damage: shows the rolled damage and lets
    the DM approve, void-reduce, or deny before touching the target's sheet."""

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
    ) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.raw_damage = raw_damage
        self.dice_text = dice_text
        self.reason = reason
        self.rolled = rolled
        self.kept = kept
        self.bonus = bonus
        self.source_channel_id = source_channel_id

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Damage", style=discord.ButtonStyle.danger, emoji="📜")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        await self._resolve(interaction, void_reduce=False)

    @discord.ui.button(label="Void Reduce (−10)", style=discord.ButtonStyle.primary, emoji="🔮")
    async def void_reduce(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        await self._resolve(interaction, void_reduce=True)

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
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
                    applied["final_damage"] -= void_saved
                    applied["new_wound_level"] = stats.wound_level_name(rec.character)
                    applied["is_dead"] = stats.is_dead(rec.character)
                    applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
                    void_line = f"\n🔮 Void Point: **−{void_saved}** wounds ({rec.character.current_void_points} VP left)"
                else:
                    void_line = "\n🔮 No Void Points available: full damage applied"
        store.save(rec)
        c = rec.character
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
            status += "  💀 **DEAD**"
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

class DmDamageView(discord.ui.View):
    """DM-approval gate for /dm damage: shows pending damage and lets a DM
    confirm or deny before applying to the target's sheet."""

    def __init__(self, target_id: int, target_name: str, amount: int, reason: str,
                 source_channel_id: int = 0) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.amount = amount
        self.reason = reason
        self.void_reduced = False
        self.source_channel_id = source_channel_id

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Damage", style=discord.ButtonStyle.danger, emoji="💥")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        applied = combat.apply_damage(rec.character, self.amount, rec.character.armor_reduction)
        store.save(rec)
        c = rec.character
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
            status += "  💀 **DEAD**"
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
        self.amount = max(0, self.amount - 10)
        self.void_reduced = True
        store.save(rec)
        await interaction.response.send_message(
            f"🔮 **{self.target_name}** spends 1 VP → damage reduced to **{self.amount}**. "
            f"({c.current_void_points}/{c.max_void_points} VP left). "
            f"DM: now click Apply Damage or Deny."
        )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        if self.void_reduced:
            rec = store.get_by_id(self.target_id)
            if rec is not None:
                rec.character.current_void_points += 1
                store.save(rec)
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

class DmHealView(discord.ui.View):
    """DM-approval gate for /dm heal: shows pending healing and lets a DM
    confirm or deny before modifying the target's wound track."""

    def __init__(self, target_id: int, target_name: str, amount: int, reason: str,
                 source_channel_id: int = 0) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.amount = amount
        self.reason = reason
        self.source_channel_id = source_channel_id

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Healing", style=discord.ButtonStyle.success, emoji="💚")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
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
        store.save(rec)
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
    if not _guild_ok(interaction):
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

@creature_group.command(name="search", description="Search bestiary templates with detailed output. Fortune role required.")
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

@creature_group.command(name="info", description="View the full stat block of a bestiary template (without spawning). Fortune role required.")
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

@creature_group.command(name="compare", description="Compare two bestiary templates side-by-side. Fortune role required.")
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

@creature_group.command(name="spawn", description="Spawn a creature instance from a template. Fortune role required.")
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

@creature_group.command(name="delete", description="Remove a spawned creature. Fortune role required.")
@app_commands.describe(name="The creature to remove.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_delete(interaction: discord.Interaction, name: str) -> None:
    rec, err = _resolve_creature(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    store.delete_creature(rec.id)
    await interaction.response.send_message(f"Removed creature **{rec.creature.name}**.", ephemeral=True)

@creature_group.command(name="wound", description="Apply wounds to a creature directly (no reduction). Fortune role required.")
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
    store.save_creature(rec)
    crossed = f"  ({applied['old_wound_level']} → **{applied['new_wound_level']}**)" if applied["level_changed"] else ""
    dead = "  💀 **SLAIN**" if applied["is_dead"] else ""
    await interaction.response.send_message(
        f"**{rec.creature.name}** takes **{amount}** → {rec.creature.wounds_taken}/{rec.creature.wounds_dead}{crossed}{dead}",
        embed=build_creature_embed(rec),
    )

@creature_group.command(name="heal", description="Heal a creature's wounds. Fortune role required.")
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
    store.save_creature(rec)
    await interaction.response.send_message(
        f"**{rec.creature.name}** healed **{amount}** → {rec.creature.wounds_taken}/{rec.creature.wounds_dead}",
        embed=build_creature_embed(rec),
    )

@creature_group.command(name="attack", description="A creature attacks a player/NPC (fixed stat block). Fortune role required.")
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
    enc = encounters.get(interaction.channel_id)
    def_cb = enc.find(target_rec.character.name) if enc else None
    cre_cover = def_cb.cover_bonus if def_cb else 0
    tn = combat.armor_tn(target_rec.character, "attack", bonus_tn + cre_cover)
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
    if hit:
        view = CreatureAttackView(cre_rec.id, target_rec.id, cr.name, t_name)
        await interaction.response.send_message(
            content="A DM can apply the creature's damage below.", embed=embed, view=view
        )
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

@category_group.command(name="create", description="Create a new category. Fortune role required.")
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

@category_group.command(name="delete", description="Delete a category (members are NOT deleted). Fortune role required.")
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

@category_group.command(name="rename", description="Rename a category. Fortune role required.")
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

@category_group.command(name="add", description="Add an NPC or creature to a category. Fortune role required.")
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

@category_group.command(name="remove", description="Remove an NPC or creature from a category. Fortune role required.")
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

@category_group.command(name="bulk_add", description="Add multiple NPCs or creatures to a category at once. Fortune role required.")
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

@category_group.command(name="bulk_remove", description="Remove multiple NPCs or creatures from a category at once. Fortune role required.")
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

@category_group.command(name="spawn", description="Spawn all creature templates in a category as instances. Fortune role required.")
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
    store.save(rec)
    await interaction.response.send_message(
        f"{emoji} **{c.name}** learns the {label} **{name}** (ML {mastery_level}) for **{cost}** XP.{note}\n"
        f"XP left {c.xp:g}", embed=build_sheet_embed(rec))

@xp_group.command(name="grant", description="Grant (or correct) a player's Experience. Fortune role required.")
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
    rec.character.xp = max(0.0, rec.character.xp + float(amount))
    store.save(rec)
    note = f" - *{reason}*" if reason else ""
    await interaction.response.send_message(
        f"✨ {member.mention}'s **{rec.character.name}** {'gains' if amount >= 0 else 'loses'} "
        f"**{abs(amount):g}** XP -> **{rec.character.xp:g}** available{note}")

@xp_group.command(name="balance", description="Show a character's available Experience.")
@app_commands.describe(member="Whose XP to show (Fortune). Omit for your own.")
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
@app_commands.describe(trait="Which Trait (or Void) to raise.", member="Advance another player's character (Fortune).")
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
    store.save(rec)
    await interaction.response.send_message(
        f"\U0001F300 **{c.name}** raises **{label}** to rank **{new_rank}** for **{cost}** XP.\n"
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) - XP left {c.xp:g}{rank_msg}", embed=build_sheet_embed(rec))

@xp_group.command(name="skill", description="Spend XP to raise or learn a Skill (RAW: new rank x1).")
@app_commands.describe(skill="Skill name.", member="Advance another player's character (Fortune).")
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
    store.save(rec)
    await interaction.response.send_message(
        f"\U0001F4D8 **{c.name}** raises **{skill_name}** to rank **{new_rank}** for **{cost}** XP.\n"
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) - XP left {c.xp:g}{rank_msg}", embed=build_sheet_embed(rec))

@xp_group.command(name="emphasis", description="Spend 2 XP to add a Skill Emphasis (max ceil(rank/2) per skill).")
@app_commands.describe(skill="The skill to add an Emphasis to.", emphasis="The Emphasis (e.g. Katana).", member="Advance another player's character (Fortune).")
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
    store.save(rec)
    await interaction.response.send_message(
        f"\U0001F3AF **{c.name}** gains **{skill_name} (Emphasis: {emph})** for **{cost}** XP. XP left {c.xp:g}",
        embed=build_sheet_embed(rec))

@xp_group.command(name="kata", description="Learn a Kata (cost = 1 x Mastery Level).")
@app_commands.describe(
    name="Kata name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the kata is in the catalog).",
    member="Advance another player's character (Fortune).",
)
@app_commands.autocomplete(name=_kata_autocomplete)
async def xp_kata(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 60],
    mastery_level: app_commands.Range[int, 1, 10] | None = None,
    member: discord.Member | None = None,
) -> None:
    rec = kata.get(name)
    ml = mastery_level if mastery_level is not None else (rec["mastery"] if rec else None)
    if ml is None:
        await interaction.response.send_message(
            f"**{name}** isn't in the catalog: give its `mastery_level:` too.", ephemeral=True
        )
        return
    canonical = rec["name"] if rec else name.strip()
    await _buy_named(interaction, member, canonical, ml, "katas", "kata", "\U0001F94B")

@xp_group.command(name="kiho", description="Learn a Kiho (cost = 1 x Mastery Level; non-Brotherhood pay 1.5x, ceil).")
@app_commands.describe(
    name="Kiho name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the kiho is in the catalog).",
    non_brotherhood="Set True if the buyer is not a Brotherhood monk (1.5x cost, per s38a).",
    member="Advance another player's character (Fortune).",
)
@app_commands.autocomplete(name=_kiho_autocomplete)
async def xp_kiho(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 60],
    mastery_level: app_commands.Range[int, 1, 10] | None = None,
    non_brotherhood: bool = False,
    member: discord.Member | None = None,
) -> None:
    rec = kiho.get(name)
    ml = mastery_level if mastery_level is not None else (rec["mastery"] if rec else None)
    if ml is None:
        await interaction.response.send_message(
            f"**{name}** isn't in the catalog: give its `mastery_level:` too.", ephemeral=True
        )
        return
    canonical = rec["name"] if rec else name.strip()
    cost = advancement.kiho_cost(ml, non_brotherhood)
    note = " *(non-Brotherhood monk: 1.5x cost, per s38a.)*" if non_brotherhood else ""
    await _buy_named(interaction, member, canonical, ml, "kiho", "kiho", "✋", note=note, cost=cost)

@xp_group.command(name="spell", description="Memorise a spell so no scroll is needed (cost = 1 x Mastery Level).")
@app_commands.describe(
    name="Spell name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the spell is in the catalog).",
    member="Advance another player's character (Fortune).",
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
    canonical = spell["name"] if spell else name.strip()
    await _buy_named(interaction, member, canonical, ml, "spells_known", "spell", "\U0001F4DC")

@xp_group.command(name="advantage", description="Buy an Advantage with XP (cost = its point value).")
@app_commands.describe(
    name="Advantage name.",
    points="Point cost: required only for 'Variable'-cost advantages.",
    member="Advance another player's character (Fortune).",
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
            f"No advantage named **{base_name}**: see `/advantage search`.", ephemeral=True
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
    store.save(rec)
    msg = f"🌸 **{c.name}** gains the advantage **{canonical}** for **{cost}** XP. XP left {c.xp:g}"
    param_hint = advantage_effects.PARAMETERISED_ADVANTAGES.get(adv["name"])
    if param_hint and ":" not in input_name:
        msg += f"\n*Hint: use `{adv['name']}: <{param_hint}>` to record the chosen option.*"
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))

@xp_group.command(name="remove_disadvantage", description="Buy off a Disadvantage with XP (cost = 2x its point value).")
@app_commands.describe(
    name="Disadvantage name (must be on the character's sheet).",
    points="Point value of the disadvantage (required if not in catalog or Variable cost).",
    member="Target another player's character (Fortune).",
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
    store.save(rec)
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
    school_name="School to learn from (defaults to your sheet's school).",
    member="Do this for another player (Fortune).",
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
    lookup = school_name or c.school
    s = schools.get(lookup) if lookup else None
    if s is None:
        await interaction.response.send_message(
            f"No school named **{lookup or '(unset)'}**. Set one with `school_name:` "
            f"(or `/stat set` isn't for this: pick from `/school search`).",
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
spell_group = app_commands.Group(name="spell", description="Browse spells by element and mastery (GDD s32-s37).")

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
    attacker_npc="Cast as a stored NPC (Fortune).",
    member="Cast as another player's character (Fortune).",
)
@app_commands.autocomplete(name=_spell_autocomplete)
async def spell_cast(
    interaction: discord.Interaction,
    name: str,
    raises: int = 0,
    spend_void: bool = False,
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
        extra_rolled = extra_kept = 1
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
    await interaction.response.send_message(embed=embed)

@spell_group.command(name="resist", description="Target resists a spell: Willpower roll vs TN. Fortune role required.")
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
    result = engine.roll_and_keep(max(1, rolled), max(1, kept), False)
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
        value="L5R 4e: target rolls raw Willpower (no skill, no explosion) vs the spell's TN.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)

@spell_group.command(name="interrupt", description="Willpower check when a caster is hit mid-cast. Disrupted = slot refunded. Fortune role required.")
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
    result = engine.roll_and_keep(max(1, willpower), max(1, willpower), False)
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
    attacker_npc="Importune as a stored NPC (Fortune).",
    member="Importune as another player's character (Fortune).",
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

@dm.command(name="taint", description="View or modify a character's Shadowlands Taint (Fortune+).")
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
        store.save(rec)
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
            embed.add_field(name="Social Penalty", value=f"TN +{taint.social_penalty(c)}", inline=True)
        await interaction.response.send_message(embed=embed, ephemeral=True)

# ---------------------------------------------------------------------------
# Phase 42: Crafting Extended (#6)
# ---------------------------------------------------------------------------

@dm.command(name="craft_extended", description="Extended crafting roll: cumulative multi-step project (Fortune+).")
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

@spell_group.command(name="damage", description="Roll spell damage dice (for offensive spells). Fortune role required.")
@app_commands.describe(
    rolled="Number of dice to roll (from spell description, e.g. Fire Ring for Fires of Purity).",
    kept="Number of dice to keep.",
    bonus="Flat damage bonus.",
    target="Target character name (shows DM-approval buttons to apply).",
    reason="Spell name or label.",
)
async def spell_damage(
    interaction: discord.Interaction,
    rolled: app_commands.Range[int, 1, 30],
    kept: app_commands.Range[int, 1, 15],
    bonus: int = 0,
    target: str | None = None,
    reason: str = "",
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
        rec = store.get_by_name(guild, NPC_OWNER, target)
        if rec is None:
            for _, pc_rec in store.list_active_pcs(guild):
                if pc_rec.character.name.lower() == target.lower():
                    rec = pc_rec
                    break
        if rec:
            red = rec.character.armor_reduction
            wl = stats.wound_level_name(rec.character)
            embed.add_field(
                name=f"Target: {rec.character.name}",
                value=f"Reduction {red} · Current: **{wl}** ({rec.character.wounds_taken} wounds)",
                inline=False,
            )
            approval_ch_id = store.get_approval_channel(guild)
            approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
            src_ch_id = interaction.channel_id if approval_ch else 0
            view = SpellDamageView(
                target_id=rec.id, target_name=rec.character.name,
                raw_damage=total, dice_text=_format_dice(result),
                reason=reason, rolled=rolled, kept=kept, bonus=bonus,
                source_channel_id=src_ch_id,
            )
            if approval_ch:
                embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
                embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
                await approval_ch.send(content="A DM can authorize the spell damage below.", embed=embed, view=view)
                await interaction.response.send_message(
                    f"📜 Spell damage on **{rec.character.name}** — approval routed to the DM channel."
                )
            else:
                await interaction.response.send_message(
                    content="A DM can authorize the spell damage below.",
                    embed=embed, view=view,
                )
        else:
            embed.set_footer(text=f"Target '{target}' not found: use exact character name.")
            await interaction.response.send_message(embed=embed)
    else:
        embed.set_footer(text="Add target: to route damage through the DM-approval gate.")
        await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 42: Courtier/Social Influence (#5)
# ---------------------------------------------------------------------------

@dm.command(name="influence", description="Track Influence Points during a court scene. Fortune role required.")
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

class MedicineTreatView(discord.ui.View):
    """DM-approval gate for medicine treatment healing."""

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

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Healing", style=discord.ButtonStyle.success, emoji="💚")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        c = rec.character
        old_level = stats.wound_level_name(c)
        c.wounds_taken = max(0, c.wounds_taken - self.wounds_healed)
        store.save(rec)
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

@dm.command(name="log_channel", description="Set the channel where combat events are logged (Kami only).")
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

@dm.command(name="clear_log", description="Stop logging combat events (Kami only).")
async def dm_clear_log(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the combat log channel.", ephemeral=True)
        return
    store.clear_log_channel(str(interaction.guild_id))
    await interaction.response.send_message("Combat log channel cleared. Events will no longer be logged.", ephemeral=True)

@dm.command(name="date_channel", description="Set the channel for the pinned date display (Kami only).")
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

@dm.command(name="clear_date_channel", description="Stop updating the date display channel (Kami only).")
async def dm_clear_date_channel(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the date channel.", ephemeral=True)
        return
    store.clear_date_channel(str(interaction.guild_id))
    await interaction.response.send_message("Date channel cleared. The pinned message will no longer update.", ephemeral=True)

@dm.command(name="approval_channel", description="Set the DM channel for damage/healing approvals (Kami only).")
@app_commands.describe(channel="The DM-only text channel for approval requests.")
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
        f"DM approval channel set to {channel.mention}. "
        f"Damage and healing requests will be routed there for DM review. "
        f"Results will be posted back in the combat room."
    )

@dm.command(name="clear_approval", description="Stop routing approvals to a DM channel (Kami only).")
async def dm_clear_approval(interaction: discord.Interaction) -> None:
    if not await _require_guild(interaction):
        return
    if not _is_kami(interaction):
        await interaction.response.send_message(f"Only the **{ROLE_KAMI}** role can clear the approval channel.", ephemeral=True)
        return
    store.clear_approval_channel(str(interaction.guild_id))
    await interaction.response.send_message("Approval channel cleared. Damage approvals will appear inline.", ephemeral=True)

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
        approval_ch_id = store.get_approval_channel(guild)
        approval_ch = client.get_channel(int(approval_ch_id)) if approval_ch_id else None
        src_ch_id = interaction.channel_id if approval_ch else 0
        view = MedicineTreatView(
            healer_name=hc.name, target_id=patient_rec.id, target_name=pc.name,
            wounds_healed=effective_heal, treatment_type=treat_label, roll_result=result,
            source_channel_id=src_ch_id,
        )
        if approval_ch:
            embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
            embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
            await approval_ch.send(
                content="Treatment succeeded. A DM can authorize the healing below.",
                embed=embed, view=view,
            )
            await interaction.response.send_message(
                f"💊 Treatment on **{pc.name}** succeeded — healing approval routed to the DM channel."
            )
        else:
            await interaction.response.send_message(
                content="Treatment succeeded. A DM can authorize the healing below.",
                embed=embed, view=view,
            )
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
    member="Export another player's character (Fortune).",
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

@sheet_data.command(name="import_sheet", description="Import a character from JSON (paste the JSON or attach a .json file).")
@app_commands.describe(
    json_data="Paste the character JSON here (or attach a .json file instead).",
)
async def sheet_import(
    interaction: discord.Interaction,
    json_data: str | None = None,
) -> None:
    if not await _require_guild(interaction):
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
    for r in ("air", "earth", "fire", "water", "void"):
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

class CharacterApprovalView(discord.ui.View):
    """Lets a DM approve or deny a character submission from the lobby."""

    def __init__(self, applicant_id: int, character_name: str, concept: str,
                 lobby_channel_id: int, clan: str = "", family_name: str = "",
                 school_name: str = "") -> None:
        super().__init__(timeout=None)
        self.applicant_id = applicant_id
        self.character_name = character_name
        self.concept = concept
        self.lobby_channel_id = lobby_channel_id
        self.clan = clan
        self.family_name = family_name
        self.school_name = school_name

    @discord.ui.button(label="Approve", style=discord.ButtonStyle.success, emoji="✅")
    async def approve(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
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
        char = Character(
            name=self.character_name,
            clan=self.clan,
            family=self.family_name,
            school=self.school_name,
            school_type="Bushi",
        )
        family_entry = families.get(self.family_name) if self.family_name else None
        family_report = None
        if family_entry:
            family_report = families.apply_to_character(char, family_entry)
            if not self.clan:
                char.clan = family_entry["clan"]
        applied = schools.get(self.school_name) if self.school_name else None
        report = schools.apply_to_character(char, applied) if applied else None
        if applied:
            char.school_type = applied.get("type", "Bushi")
        try:
            record = store.create_character(guild_id, owner_id, char)
        except storage.DuplicateNameError:
            await interaction.response.send_message(
                f"A character named **{self.character_name}** already exists for that player. "
                f"Ask them to pick another name.",
                ephemeral=True,
            )
            return
        store.set_active(guild_id, owner_id, record.id)

        await member.add_roles(approved_role, reason=f"Character '{self.character_name}' approved by {interaction.user.display_name}")
        nick_note = ""
        try:
            await member.edit(nick=self.character_name, reason=f"Character approved: {self.character_name}")
        except discord.Forbidden:
            nick_note = "\n(Could not change nickname — the bot's role may be too low or the member is the server owner.)"
        for child in self.children:
            child.disabled = True
        self.stop()
        await interaction.response.edit_message(view=self)

        sheet_parts: list[str] = []
        if applied:
            sheet_parts.append(f"School: **{applied['name']}**")
            if report and report["benefit"]:
                sheet_parts.append(f"Benefit: {report['benefit']}")
            if report and report["skills"]:
                sheet_parts.append(f"{len(report['skills'])} school skills applied")
            if report and report["wildcards"]:
                sheet_parts.append("Wildcards to choose: " + "; ".join(report["wildcards"]))
        if family_report:
            sheet_parts.append(f"Family: **{family_entry['name']}** ({family_report})")
        sheet_info = "\n".join(sheet_parts) if sheet_parts else "No school/family catalog match — sheet starts with base stats."

        embed = discord.Embed(
            title="✅ Character Approved",
            color=discord.Color.green(),
            description=(
                f"**{member.mention}**'s character **{self.character_name}** has been approved.\n"
                f"They now have the **{ROLE_APPROVED}** role, their nickname has been set, "
                f"and their character sheet has been created.{nick_note}"
            ),
        )
        embed.add_field(name="Sheet Created", value=sheet_info, inline=False)
        embed.set_footer(text=f"Approved by {interaction.user.display_name}")
        await interaction.followup.send(embed=embed)
        lobby = client.get_channel(self.lobby_channel_id)
        if lobby:
            await lobby.send(
                f"✅ {member.mention}, your character **{self.character_name}** has been approved! "
                f"Your character sheet has been created and set as active. "
                f"You now have access to the rest of the server. Welcome to Rokugan!"
            )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.danger, emoji="❌")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _require_dm_role(interaction):
            return
        for child in self.children:
            child.disabled = True
        self.stop()
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
            description=f"**{member_str}**'s character **{self.character_name}** was denied.",
        )
        embed.set_footer(text=f"Denied by {interaction.user.display_name}")
        await interaction.followup.send(embed=embed)
        lobby = client.get_channel(self.lobby_channel_id)
        if lobby and member:
            await lobby.send(
                f"❌ {member.mention}, your character **{self.character_name}** was not approved. "
                f"Please speak with a DM for details and feel free to submit again."
            )

@client.tree.command(name="submit", description="Start character creation — opens a private channel with the full wizard.")
@app_commands.describe(
    character_name="Your character's full name (e.g. Bayushi Kachiko).",
    concept="A short description of your character concept and personality (optional).",
)
async def submit_character(
    interaction: discord.Interaction,
    character_name: app_commands.Range[str, 1, 100],
    concept: app_commands.Range[str, 1, 2000] | None = None,
) -> None:
    if not await _require_guild(interaction):
        return
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

    existing_ch_id = store.get_creation_channel(guild_id, user_id)
    if existing_ch_id:
        existing_ch = client.get_channel(int(existing_ch_id))
        if existing_ch:
            await interaction.response.send_message(
                f"You already have an active character creation channel: {existing_ch.mention}. "
                f"Finish or cancel that one first.",
                ephemeral=True,
            )
            return
        store.delete_creation_channel(guild_id, user_id)

    await interaction.response.defer(ephemeral=True)

    lobby_cat = interaction.channel.category if interaction.channel else None
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
        category=lobby_cat,
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
        "chosen_spells": [],
        "concept": concept or "",
    }
    view = _WizardView(state)
    view.add_item(_ClanSelect(state))
    await priv_channel.send(
        content=f"Welcome, {interaction.user.mention}! Let's build **{character_name}**.\n"
                f"**Step 1/10**: Choose your Clan.",
        embed=_chargen_embed(state), view=view,
    )

    await interaction.followup.send(
        f"Your private character creation channel has been created: {priv_channel.mention}\n"
        f"Head there to build **{character_name}**!",
        ephemeral=True,
    )

setup_group = app_commands.Group(name="setup", description="Server setup commands (Kami only).")

@setup_group.command(name="server", description="Create the server channel structure (Lobby, OOC, IC, DM categories). Kami only.")
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
            permissions=approved_perms, hoist=True,
            reason="Server setup: player access role",
        )
    else:
        await approved_role.edit(color=discord.Color.from_str("#2ECC71"),
                                 permissions=approved_perms, hoist=True,
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
        "Spider": "#7F8C8D",
    }
    clan_roles_created: list[discord.Role] = []
    for clan_name in _GREAT_CLANS:
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
    lobby_cat = await guild.create_category("Lobby", overwrites=lobby_overwrites, reason="Server setup")
    welcome_ch = await lobby_cat.create_text_channel("welcome")
    await lobby_cat.create_text_channel("character-submission")
    welcome_embed = discord.Embed(
        title="Welcome to Rokugan",
        color=0xC4A747,
        description=(
            "Welcome, traveler. This server hosts a persistent world set in "
            "Rokugan, using **Legend of the Five Rings 4th Edition** rules.\n\n"
            "**To gain access to the server:**\n"
            "1. Go to the **#character-submission** channel\n"
            "2. Use the `/submit` command with your character's name and concept\n"
            "3. A Dungeon Master will review and approve your character\n"
            "4. Once approved, you'll gain access to all channels\n\n"
            "We look forward to your story."
        ),
    )
    welcome_msg = await welcome_ch.send(embed=welcome_embed)
    await welcome_msg.pin()

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
    ooc_cat = await guild.create_category("Out of Character", overwrites=ooc_overwrites, reason="Server setup")
    await ooc_cat.create_text_channel("general")
    await ooc_cat.create_text_channel("off-topic")

    # Announcements channel (read-only for players, DMs can post)
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
    announcements_ch = await ooc_cat.create_text_channel("announcements", overwrites=announce_overwrites)

    # Rules reference channel (read-only for everyone, bot posts pinned embeds)
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

    # --- 3. In Character (Approved + DMs only) ---
    ic_overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        everyone: discord.PermissionOverwrite(view_channel=False),
        approved_role: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
        ),
        bot_member: discord.PermissionOverwrite(
            view_channel=True, send_messages=True, manage_channels=True,
            manage_messages=True, manage_threads=True,
        ),
    }
    for r in dm_roles:
        ic_overwrites[r] = discord.PermissionOverwrite(
            view_channel=True, send_messages=True, read_message_history=True,
            manage_messages=True,
        )
    ic_cat = await guild.create_category("In Character", overwrites=ic_overwrites, reason="Server setup")
    await ic_cat.create_text_channel("in-character")

    # --- 4. DM Room (Fortune + Kami only) ---
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
    dm_cat = await guild.create_category("Dungeon Masters", overwrites=dm_overwrites, reason="Server setup")
    dm_discussion = await dm_cat.create_text_channel("dm-discussion")
    approvals_ch = await dm_cat.create_text_channel("approvals")

    store.set_approval_channel(str(guild.id), str(approvals_ch.id))

    clan_list = ", ".join(r.mention for r in clan_roles_created)
    family_list = ", ".join(r.mention for r in family_roles_created)
    summary = (
        f"**Server setup complete!**\n\n"
        f"**Staff Roles:**\n"
        f"• {kami_role.mention} — Server admin (gold, full permissions)\n"
        f"• {fortune_role.mention} — Dungeon Master (purple, moderation tools)\n"
        f"• {approved_role.mention} — Approved player (green, basic access)\n\n"
        f"**Clan Roles ({len(clan_roles_created)}):** {clan_list}\n\n"
        f"**Family Roles ({len(family_roles_created)}):** {family_list}\n\n"
        f"**Categories & Channels:**\n"
        f"• **Lobby** — {welcome_ch.mention}, #character-submission\n"
        f"• **Out of Character** — #general, #off-topic, {announcements_ch.mention} (DM-post only), "
        f"{rules_ch.mention} (read-only reference)\n"
        f"• **In Character** — #in-character (visible to {ROLE_APPROVED}+)\n"
        f"• **Dungeon Masters** — {dm_discussion.mention}, {approvals_ch.mention} (DMs only)\n\n"
        f"**Approval channel** set to {approvals_ch.mention} — character submissions and "
        f"damage/healing approvals will be routed there.\n\n"
        f"Players use `/submit` in the lobby to apply. DMs approve or deny from {approvals_ch.mention}.\n"
        f"Approved players get their nickname changed to their character name.\n\n"
        f"Use `/dm announce` to post events to {announcements_ch.mention}. "
        f"Use `/roster` to see all approved characters."
    )
    await interaction.followup.send(summary, ephemeral=True)

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

@dm.command(name="announce", description="Post a session/event announcement with RSVP reactions (Fortune+).")
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
#  /roster — player character directory
# ---------------------------------------------------------------------------

@client.tree.command(name="roster", description="Show all approved player characters on this server.")
async def roster(interaction: discord.Interaction) -> None:
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
)

cog_combat.init(
    store=store,
    engine=engine,
    encounters=encounters,
    npc_owner=NPC_OWNER,
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
client.tree.add_command(cog_combat.combat_group)
client.tree.add_command(cog_combat.fight_group)
client.tree.add_command(cog_combat.engage_group)
client.tree.add_command(spell_group)
client.tree.add_command(cog_checks.check)
client.tree.add_command(cog_checks.assess)
client.tree.add_command(cog_checks.examine)
client.tree.add_command(ref_commands.ref)
client.tree.add_command(setup_group)

def main() -> None:
    if not TOKEN:
        raise SystemExit(
            "DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and paste your "
            "bot token, or export DISCORD_BOT_TOKEN in the environment. See README.md."
        )
    client.run(TOKEN)

if __name__ == "__main__":
    main()
