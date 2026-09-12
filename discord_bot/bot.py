"""Rokugan L5R 4e Discord bot — entry point.

Phases so far:
  1. Dice — Roll & Keep as a slash command.
  2. Character sheets — create/store sheets, link one to your Discord account,
     view/edit them, and a DM role that can edit anyone's sheet.

Discord plumbing only. All game math lives in `l5r_rules/`; all persistence in
`storage.py`. Run locally: see README.md.
"""

from __future__ import annotations

import logging
import os

import discord
from discord import app_commands

import encounter
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
        log.info("Logged in as %s (id=%s). Ready.", self.user, getattr(self.user, "id", "?"))


client = RokuganBot()


# ===========================================================================
# Shared helpers
# ===========================================================================
def _is_dm(interaction: discord.Interaction) -> bool:
    """A DM is a server admin, someone with Manage Server, or an explicit grant."""
    perms = getattr(interaction.user, "guild_permissions", None)
    if perms is not None and (perms.administrator or perms.manage_guild):
        return True
    return store.is_dm(str(interaction.guild_id), str(interaction.user.id))


def _guild_ok(interaction: discord.Interaction) -> bool:
    return interaction.guild_id is not None


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
        f"🌪️ Air — {pair('reflexes', 'awareness')}\n"
        f"⛰️ Earth — {pair('stamina', 'willpower')}\n"
        f"🔥 Fire — {pair('agility', 'intelligence')}\n"
        f"💧 Water — {pair('strength', 'perception')}\n"
        f"🌀 Void — {c.void_ring}"
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
    header = " · ".join(subtitle_bits) if subtitle_bits else "—"
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
    track = _wound_track(c)
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

    gear = f"Armor: {c.armor_name or '—'}  (TN +{c.armor_tn_bonus}, Reduction {c.armor_reduction})"
    if c.equipped_weapon:
        wield = c.equipped_weapon
        if c.off_hand_weapon:
            wield += f" + {c.off_hand_weapon} (off)"
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
        extras.append("**Techniques:** " + ", ".join(c.techniques))
    if c.katas:
        act = (c.active_kata or "").lower()
        extras.append("**Kata:** " + ", ".join(
            (f"⚑{k}" if k.lower() == act else k) for k in c.katas))
    if c.kiho:
        active_kiho = [a.lower() for a in getattr(c, "active_kiho", [])]
        extras.append("**Kiho:** " + ", ".join(
            (f"⚑{k}" if k.lower() in active_kiho else k) for k in c.kiho))
    if c.emphases:
        extras.append("**Emphases:** " + ", ".join(
            f"{sk} ({', '.join(em)})" for sk, em in sorted(c.emphases.items()) if em))
    if c.spells_known:
        extras.append("**Spells:** " + ", ".join(c.spells_known))
    if c.advantages:
        extras.append("**Advantages:** " + ", ".join(c.advantages))
    if c.disadvantages:
        extras.append("**Disadvantages:** " + ", ".join(c.disadvantages))
    if c.taint > 0:
        extras.append(f"**Taint:** {c.taint:g}")
    if c.koku:
        extras.append(f"**Koku:** {c.koku:g}")
    if c.notes:
        extras.append(f"*{c.notes}*")
    if extras:
        embed.add_field(name="Details", value="\n".join(extras)[:1024], inline=False)

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
    embed.description = f"Creature — *{cr.template_id}*{tags}"
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
    thr = ", ".join(str(t) for t in cr.wound_thresholds) if cr.wound_thresholds else "—"
    embed.add_field(
        name="Wounds",
        value=f"**{lvl}** — {cr.wounds_taken} / {cr.wounds_dead} (dead)\nthresholds: {thr}"
        + ("  💀 **SLAIN**" if dead else ""),
        inline=False,
    )
    embed.set_footer(text=f"creature #{record.id}")
    return embed


async def _resolve_active_for_edit(
    interaction: discord.Interaction, member: discord.Member | None
) -> tuple[storage.CharacterRecord | None, str | None]:
    """Return (record, error). Editing another member's sheet requires DM."""
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            return None, "Only a DM can edit another player's character."
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


@client.tree.command(name="whoami", description="Quick glance at your active character's status.")
async def whoami(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
    wound_str = f"**{lvl}**" + (f" ({pen} penalty)" if pen else "") + f" — {c.wounds_taken}/{cap}"
    if pen:
        wound_str = f"⚠️ {wound_str}"
    vp_str = f"{c.current_void_points}/{c.max_void_points} VP"
    header = " · ".join(b for b in (c.clan, c.school) if b) or "—"
    water = stats.water_ring(c)
    move_str = f"Move: {water * 5} ft (Free) / {water * 10} ft (Simple)"
    track = _wound_track(c)
    lines = [
        f"**{c.name}** — {header} (Rank {stats.insight_rank(c)})",
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
        if slot_parts:
            lines.append(f"Spell Slots: {' · '.join(slot_parts)}")
    if c.equipped_weapon:
        wield = c.equipped_weapon
        if c.off_hand_weapon:
            wield += f" + {c.off_hand_weapon}"
        lines.append(f"Wielding: {wield}")
    if c.active_kata:
        lines.append(f"Active Kata: {c.active_kata}")
    enc = encounters.get(interaction.channel_id)
    if enc:
        uid = str(interaction.user.id)
        for cb in enc.combatants:
            if cb.owner_id == uid and cb.name.lower() == c.name.lower():
                conds = ", ".join(sorted(cb.conditions)) if cb.conditions else "none"
                lines.append(f"In combat — conditions: {conds}")
                break
    await interaction.response.send_message("\n".join(lines), ephemeral=True)


@client.tree.command(name="party", description="DM overview — all active PCs on this server.")
async def party_overview(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can view the party roster.", ephemeral=True)
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
        wound_str = f"{lvl}" + (f" ({pen})" if pen else "") + f" — {c.wounds_taken}/{cap}"
        vp_str = f"VP {c.current_void_points}/{c.max_void_points}"
        header = " · ".join(b for b in (c.clan, c.school) if b) or "—"
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
            val_parts.append(f"Wielding: {wield}")
        embed.add_field(
            name=f"{c.name}  (<@{owner_id}>)",
            value="\n".join(val_parts),
            inline=False,
        )
    embed.set_footer(text=f"{len(active)} active PC{'s' if len(active) != 1 else ''}")
    await interaction.response.send_message(embed=embed, ephemeral=True)


def _format_dice(result: DiceResult) -> str:
    kept = ", ".join(str(d) for d in result.kept_dice) or "—"
    line = f"**Kept:** {kept}"
    if result.dropped_dice:
        line += f"   ·   *dropped: {', '.join(str(d) for d in result.dropped_dice)}*"
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


@client.tree.command(
    name="roll",
    description="Roll & Keep (L5R 4e). Example: rolled=7 kept=3, optionally against a TN.",
)
@app_commands.describe(
    rolled="Number of dice to ROLL (the X in XkY).",
    kept="Number of dice to KEEP (the Y in XkY).",
    tn="Optional Target Number to test against.",
    raises="Called Raises — each adds +5 to the TN (default 0).",
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
    title = "🎲 Roll & Keep" + (f" — {reason}" if reason else "")

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
            value=f"**{outcome['total']}** vs TN {outcome['tn']} — {verdict} (margin {outcome['margin']:+d})",
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

    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /attack — combat with DM-authorized damage
# ===========================================================================
_ATTACKER_STANCES = [
    app_commands.Choice(name="Attack", value="attack"),
    app_commands.Choice(name="Full Attack (+2k1 to hit, -10 own Armor TN)", value="full_attack"),
    app_commands.Choice(name="Center", value="center"),
]
_DEFENDER_STANCES = [
    app_commands.Choice(name="Attack", value="attack"),
    app_commands.Choice(name="Full Attack (-10 Armor TN)", value="full_attack"),
    app_commands.Choice(name="Defense (+Air + Defense skill to Armor TN)", value="defense"),
]


async def _weapon_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    names = [w for w in combat.WEAPON_CATALOG if cur in w]
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
    """Starting Schools only — for character creation / NPC generation.
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


_MANEUVER_APPLY_LABEL = {
    "none": "Roll & Apply Damage",
    "feint": "Roll & Apply Damage (Feint)",
    "increased_damage": "Roll & Apply Damage",
    "disarm": "Resolve Disarm (2k1 + Strength)",
    "knockdown": "Resolve Knockdown (Strength)",
    "called_shot": "Roll & Apply Damage (Called Shot)",
    "extra_attack": "Roll & Apply Damage (1st Attack)",
}


class DamageView(discord.ui.View):
    """DM-only buttons attached to a landed attack: resolve the hit, or waive it.

    Handles the plain hit and the Feint / Disarm / Knockdown maneuvers."""

    def __init__(
        self,
        attacker_id: int,
        target_id: int | None,
        weapon: str,
        increased_damage: int,
        attacker_name: str,
        target_name: str,
        maneuver: str = "none",
        attack_margin: int = 0,
        target_creature_id: int | None = None,
        defender_stance: str = "attack",
        called_shot_raises: int = 0,
        channel_id: int = 0,
    ) -> None:
        super().__init__(timeout=1800)  # 30 min
        self.attacker_id = attacker_id
        self.target_id = target_id
        self.target_creature_id = target_creature_id
        self.weapon = weapon
        self.increased_damage = increased_damage
        self.attacker_name = attacker_name
        self.target_name = target_name
        self.maneuver = maneuver
        self.attack_margin = attack_margin
        self.defender_stance = defender_stance
        self.called_shot_raises = called_shot_raises
        self.channel_id = channel_id
        # Relabel the primary button to match the maneuver, and hide the Void
        # button when it would be nonsensical (knockdown has no damage roll;
        # creature targets have no VP pool).
        hide_void = maneuver == "knockdown" or target_creature_id is not None
        to_remove = []
        for child in self.children:
            if isinstance(child, discord.ui.Button) and child.style == discord.ButtonStyle.danger:
                child.label = _MANEUVER_APPLY_LABEL.get(maneuver, "Roll & Apply Damage")
            if isinstance(child, discord.ui.Button) and child.style == discord.ButtonStyle.primary and hide_void:
                to_remove.append(child)
        for child in to_remove:
            self.remove_item(child)

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    def _wound_status(self, target_rec: storage.CharacterRecord, applied: dict) -> str:
        c = target_rec.character
        if applied["level_changed"]:
            status = (
                f"{self.target_name}: {applied['old_wound_level']} → "
                f"**{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
            )
        else:
            status = f"{self.target_name}: **{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
        if applied["is_dead"]:
            status += "  💀 **DEAD**"
        return status

    def _rate_limited_damage(self, interaction: discord.Interaction, attacker: Character):
        """Enforce once-per-Turn/Round damage-side kata against the live tracker.
        Returns (scorpion_bonus, scorpion_note, tsunami_ignore, tsunami_note); an
        effect fires only while an encounter is tracking the attacker."""
        enc = encounters.get(interaction.channel_id)
        combatant = enc.find(attacker.name) if enc else None
        scorp_bonus, scorp_note = 0, ""
        val, note = kata_effects.scorpion_feint_damage(attacker, self.maneuver)
        if val and _rate_status(combatant, "scorpion", "turn") == "apply":
            scorp_bonus, scorp_note = val, note
        tsu_ignore, tsu_note = 0, ""
        val, note = kata_effects.tsunami_ignore_reduction(attacker)
        if val and _rate_status(combatant, "tsunami", "round") == "apply":
            tsu_ignore, tsu_note = val, note
        return scorp_bonus, scorp_note, tsu_ignore, tsu_note

    @discord.ui.button(label="Roll & Apply Damage", style=discord.ButtonStyle.danger, emoji="⚔️")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return
        await self._resolve_damage(interaction, void_reduce=False)

    @discord.ui.button(label="Void Reduce (−10 wounds)", style=discord.ButtonStyle.primary, emoji="🔮")
    async def void_reduce_apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return
        await self._resolve_damage(interaction, void_reduce=True)

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can resolve this.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} denied the effect — "
            f"no damage applied to **{self.target_name}**."
        )

    async def _resolve_damage(self, interaction: discord.Interaction, void_reduce: bool = False) -> None:
        """Shared damage resolution for both normal and Void-reduced paths."""

        # Creature target: apply the attacker's weapon damage to the creature's
        # own wound track (plain hit or Feint only; disarm/knockdown are blocked
        # against creatures at /attack).
        if self.target_creature_id is not None:
            attacker_rec = store.get_by_id(self.attacker_id)
            cre_rec = store.get_creature_by_id(self.target_creature_id)
            if cre_rec is None:
                await interaction.response.send_message("The creature no longer exists.", ephemeral=True)
                return
            if attacker_rec is None:
                await interaction.response.send_message("The attacker no longer exists.", ephemeral=True)
                return
            attacker = attacker_rec.character
            wp = combat.get_weapon_profile(self.weapon)
            extra_rolled, waves_note = kata_effects.attacker_damage_rolled_bonus(attacker, wp)
            t_roll, t_kept, t_flat, t_dmg_notes = technique_effects.attacker_damage(attacker, wp, self.weapon)
            extra_rolled += t_roll
            m_roll, m_kept, m_flat, m_dmg_notes = skill_mastery.attacker_damage(attacker, wp, self.weapon)
            extra_rolled += m_roll
            t_kept += m_kept
            t_flat += m_flat
            t_dmg_notes = t_dmg_notes + m_dmg_notes
            a_roll, a_kept, a_flat, a_dmg_notes = advantage_effects.attacker_damage(attacker, wp, self.weapon)
            extra_rolled += a_roll
            t_kept += a_kept
            t_flat += a_flat
            t_dmg_notes = t_dmg_notes + a_dmg_notes
            k_roll, k_kept, k_flat, k_dmg_notes = kiho_effects.attacker_damage(attacker, self.weapon)
            extra_rolled += k_roll
            t_kept += k_kept
            t_flat += k_flat
            t_dmg_notes = t_dmg_notes + k_dmg_notes
            bish_roll, bish_notes = advantage_effects.increased_damage_bonus(attacker, self.increased_damage)
            extra_rolled += bish_roll
            t_dmg_notes = t_dmg_notes + bish_notes
            ignore, sos_note = kata_effects.attacker_reduction_ignored(attacker, wp)
            t_ignore, t_ign_notes = technique_effects.attacker_reduction_ignored(attacker, wp, self.weapon)
            ignore += t_ignore
            enc = encounters.get(interaction.channel_id)
            enc_round = enc.round if enc else None
            m_ignore, m_ign_notes = skill_mastery.attacker_reduction_ignored(attacker, wp, enc_round)
            ignore += m_ignore
            t_dmg_notes = t_dmg_notes + t_ign_notes + m_ign_notes
            explode_9, e9_note = skill_mastery.attacker_explode_9(attacker, wp)
            force_explode, fe_note = skill_mastery.attacker_ninjutsu_can_explode(attacker, wp)
            if e9_note:
                t_dmg_notes.append(e9_note)
            if fe_note:
                t_dmg_notes.append(fe_note)
            dmg = combat.resolve_damage(
                attacker, self.weapon, engine, self.increased_damage,
                extra_rolled, t_kept, t_flat, explode_9=explode_9, force_explode=force_explode,
            )
            raw = dmg["raw_damage"]
            feint_line = ""
            if self.maneuver == "feint":
                fb = combat.compute_feint_bonus(self.attack_margin, stats.insight_rank(attacker))
                raw += fb
                feint_line = f"\nFeint bonus **+{fb}**"
            scorp_bonus, scorp_note, tsu_ignore, tsu_note = self._rate_limited_damage(interaction, attacker)
            raw += scorp_bonus
            kata_line = "".join(f"\n⚑ {n}" for n in (waves_note, sos_note, scorp_note, tsu_note, *t_dmg_notes) if n)
            reduction = max(0, cre_rec.creature.reduction - ignore - tsu_ignore)
            applied = creature.apply_damage_to_creature(cre_rec.creature, raw, reduction)
            heal_line = ""
            if applied["is_dead"]:
                heal_amt, heal_notes = advantage_effects.post_kill_heal(attacker)
                if heal_amt:
                    attacker.wounds_taken = max(0, attacker.wounds_taken - heal_amt)
                    store.save(attacker_rec)
                    heal_line = f"\n⚑ {heal_notes[0]} ({attacker.wounds_taken} wounds remaining)"
            store.save_creature(cre_rec)
            cr = cre_rec.creature
            cre_cs_line = ""
            if self.maneuver == "called_shot" and self.called_shot_raises > 0:
                part = combat.CALLED_SHOT_PARTS.get(
                    min(self.called_shot_raises, 4), "specific part"
                )
                cre_cs_line = f"\n🎯 Called Shot: **{part}** ({self.called_shot_raises} raise{'s' if self.called_shot_raises != 1 else ''})"
            embed = discord.Embed(
                title="⚔️ Damage applied",
                color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
            )
            embed.add_field(
                name="Damage",
                value=(
                    f"{self.attacker_name} → **{self.target_name}** with {self.weapon}\n"
                    f"{_format_dice(dmg['dice'])}{feint_line}{kata_line}{cre_cs_line}\n"
                    f"Raw **{raw}** − reduction {applied['reduction']} = "
                    f"**{applied['final_damage']}** wounds"
                ),
                inline=False,
            )
            if applied["level_changed"]:
                status = (
                    f"{self.target_name}: {applied['old_wound_level']} → "
                    f"**{applied['new_wound_level']}** ({cr.wounds_taken}/{cr.wounds_dead})"
                )
            else:
                status = f"{self.target_name}: **{applied['new_wound_level']}** ({cr.wounds_taken}/{cr.wounds_dead})"
            if applied["is_dead"]:
                status += "  💀 **SLAIN**"
            status += heal_line
            embed.add_field(name="Result", value=status, inline=False)
            embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
            self._disable()
            await interaction.response.edit_message(view=self)
            await interaction.followup.send(embed=embed)
            dead_tag = " SLAIN" if applied["is_dead"] else ""
            await _combat_log(
                str(interaction.guild_id),
                f"Damage: {self.attacker_name} → {self.target_name} ({self.weapon}) "
                f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
            )
            if self.maneuver == "extra_attack" and not applied["is_dead"]:
                await self._second_attack_creature(interaction, attacker_rec, cre_rec)
            return

        attacker_rec = store.get_by_id(self.attacker_id)
        target_rec = store.get_by_id(self.target_id)
        if target_rec is None:
            await interaction.response.send_message("The target no longer exists.", ephemeral=True)
            return
        if attacker_rec is None:
            await interaction.response.send_message("The attacker no longer exists.", ephemeral=True)
            return
        attacker = attacker_rec.character
        target = target_rec.character

        if self.maneuver == "knockdown":
            kd = combat.resolve_knockdown(attacker, target, engine)
            if kd["knocked_down"]:
                enc = encounters.get(interaction.channel_id)
                if enc:
                    def_c = enc.find(target.name)
                    if def_c:
                        def_c.conditions.add("prone")
            embed = discord.Embed(
                title="🥋 Knockdown",
                color=discord.Color.green() if kd["knocked_down"] else discord.Color.greyple(),
            )
            embed.add_field(
                name="Contested Strength",
                value=f"{self.attacker_name} **{kd['attacker_roll']}** vs "
                f"{self.target_name} **{kd['defender_roll']}**",
                inline=False,
            )
            verdict = (
                f"**{self.target_name} is knocked prone!**" if kd["knocked_down"]
                else f"{self.target_name} keeps their feet."
            )
            embed.add_field(name="Result", value=verdict, inline=False)
            embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
            self._disable()
            await interaction.response.edit_message(view=self)
            await interaction.followup.send(embed=embed)
            result_tag = "knocked prone" if kd["knocked_down"] else "resisted"
            await _combat_log(
                str(interaction.guild_id),
                f"Knockdown: {self.attacker_name} → {self.target_name} ({result_tag})",
            )
            return

        if self.maneuver == "disarm":
            dis = combat.resolve_disarm(attacker, target, engine)
            applied = combat.apply_damage(target, dis["damage"], target.armor_reduction)
            void_line = ""
            if void_reduce and target.current_void_points > 0:
                void_saved = min(10, applied["final_damage"])
                target.wounds_taken = max(0, target.wounds_taken - void_saved)
                target.current_void_points -= 1
                applied["final_damage"] -= void_saved
                applied["new_wound_level"] = stats.wound_level_name(target)
                applied["is_dead"] = stats.is_dead(target)
                applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
                void_line = f"\n🔮 Void Point spent: **−{void_saved}** wounds ({target.current_void_points} VP remaining)"
            elif void_reduce:
                void_line = "\n🔮 No Void Points available — full damage applied"
            store.save(target_rec)
            embed = discord.Embed(
                title="🗡️ Disarm",
                color=discord.Color.green() if dis["disarmed"] else discord.Color.orange(),
            )
            embed.add_field(
                name="Damage (2k1)",
                value=f"{_format_dice(dis['damage_dice'])}\nRaw **{dis['damage']}** − reduction "
                f"{applied['reduction']} = **{applied['final_damage']}** wounds{void_line}",
                inline=False,
            )
            embed.add_field(
                name="Contested Strength",
                value=f"{self.attacker_name} **{dis['attacker_roll']}** vs "
                f"{self.target_name} **{dis['defender_roll']}**",
                inline=False,
            )
            verdict = (
                f"**{self.target_name} is disarmed!**" if dis["disarmed"]
                else f"{self.target_name} holds their weapon."
            )
            embed.add_field(name="Result", value=f"{verdict}\n{self._wound_status(target_rec, applied)}", inline=False)
            embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
            self._disable()
            await interaction.response.edit_message(view=self)
            await interaction.followup.send(embed=embed)
            disarm_tag = "disarmed" if dis["disarmed"] else "held"
            await _combat_log(
                str(interaction.guild_id),
                f"Disarm: {self.attacker_name} → {self.target_name} ({disarm_tag}, "
                f"{applied['final_damage']} wounds [{applied['new_wound_level']}])",
            )
            return

        # Plain hit or Feint: weapon damage (+ feint bonus, + active-kata, Technique & Mastery mods).
        wp = combat.get_weapon_profile(self.weapon)
        extra_rolled, waves_note = kata_effects.attacker_damage_rolled_bonus(attacker, wp)
        t_roll, t_kept, t_flat, t_dmg_notes = technique_effects.attacker_damage(attacker, wp, self.weapon)
        extra_rolled += t_roll
        m_roll, m_kept, m_flat, m_dmg_notes = skill_mastery.attacker_damage(attacker, wp, self.weapon)
        extra_rolled += m_roll
        t_kept += m_kept
        t_flat += m_flat
        t_dmg_notes = t_dmg_notes + m_dmg_notes
        a_roll, a_kept, a_flat, a_dmg_notes = advantage_effects.attacker_damage(attacker, wp, self.weapon)
        extra_rolled += a_roll
        t_kept += a_kept
        t_flat += a_flat
        t_dmg_notes = t_dmg_notes + a_dmg_notes
        k_roll, k_kept, k_flat, k_dmg_notes = kiho_effects.attacker_damage(attacker, self.weapon)
        extra_rolled += k_roll
        t_kept += k_kept
        t_flat += k_flat
        t_dmg_notes = t_dmg_notes + k_dmg_notes
        bish_roll, bish_notes = advantage_effects.increased_damage_bonus(attacker, self.increased_damage)
        extra_rolled += bish_roll
        t_dmg_notes = t_dmg_notes + bish_notes
        ignore, sos_note = kata_effects.attacker_reduction_ignored(attacker, wp)
        t_ignore, t_ign_notes = technique_effects.attacker_reduction_ignored(attacker, wp, self.weapon)
        ignore += t_ignore
        enc = encounters.get(interaction.channel_id)
        enc_round = enc.round if enc else None
        m_ignore, m_ign_notes = skill_mastery.attacker_reduction_ignored(attacker, wp, enc_round)
        ignore += m_ignore
        t_dmg_notes = t_dmg_notes + t_ign_notes + m_ign_notes
        explode_9, e9_note = skill_mastery.attacker_explode_9(attacker, wp)
        force_explode, fe_note = skill_mastery.attacker_ninjutsu_can_explode(attacker, wp)
        if e9_note:
            t_dmg_notes.append(e9_note)
        if fe_note:
            t_dmg_notes.append(fe_note)
        dmg = combat.resolve_damage(
            attacker, self.weapon, engine, self.increased_damage,
            extra_rolled, t_kept, t_flat, explode_9=explode_9, force_explode=force_explode,
        )
        raw = dmg["raw_damage"]
        feint_line = ""
        if self.maneuver == "feint":
            fb = combat.compute_feint_bonus(self.attack_margin, stats.insight_rank(attacker))
            raw += fb
            feint_line = f"\nFeint bonus **+{fb}** (½ margin {self.attack_margin}, cap 5×Insight Rank)"
        crab_bonus, crab_note = kata_effects.defender_reduction_bonus(target, self.defender_stance)
        tech_red, tech_red_notes = technique_effects.defender_reduction_bonus(target)
        kiho_red, kiho_red_notes = kiho_effects.defender_reduction_bonus(target)
        scorp_bonus, scorp_note, tsu_ignore, tsu_note = self._rate_limited_damage(interaction, attacker)
        raw += scorp_bonus
        kata_line = "".join(
            f"\n⚑ {n}" for n in (waves_note, sos_note, crab_note, scorp_note, tsu_note, *t_dmg_notes, *tech_red_notes, *kiho_red_notes) if n
        )
        reduction = max(0, target.armor_reduction - ignore - tsu_ignore + crab_bonus + tech_red + kiho_red)
        applied = combat.apply_damage(target, raw, reduction)
        void_line = ""
        if void_reduce and target.current_void_points > 0:
            void_saved = min(10, applied["final_damage"])
            target.wounds_taken = max(0, target.wounds_taken - void_saved)
            target.current_void_points -= 1
            applied["final_damage"] -= void_saved
            applied["new_wound_level"] = stats.wound_level_name(target)
            applied["is_dead"] = stats.is_dead(target)
            applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
            void_line = f"\n🔮 Void Point spent: **−{void_saved}** wounds ({target.current_void_points} VP remaining)"
        elif void_reduce:
            void_line = "\n🔮 No Void Points available — full damage applied"
        heal_line = ""
        if applied["is_dead"]:
            heal_amt, heal_notes = advantage_effects.post_kill_heal(attacker)
            if heal_amt:
                attacker.wounds_taken = max(0, attacker.wounds_taken - heal_amt)
                store.save(attacker_rec)
                heal_line = f"\n⚑ {heal_notes[0]} ({attacker.wounds_taken} wounds remaining)"
        store.save(target_rec)

        called_shot_line = ""
        if self.maneuver == "called_shot" and self.called_shot_raises > 0:
            part = combat.CALLED_SHOT_PARTS.get(
                min(self.called_shot_raises, 4), "specific part"
            )
            called_shot_line = f"\n🎯 Called Shot: **{part}** ({self.called_shot_raises} raise{'s' if self.called_shot_raises != 1 else ''})"

        embed = discord.Embed(
            title="⚔️ Damage applied",
            color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
        )
        embed.add_field(
            name="Damage",
            value=(
                f"{self.attacker_name} → **{self.target_name}** with {self.weapon}\n"
                f"{_format_dice(dmg['dice'])}{feint_line}{kata_line}{called_shot_line}\n"
                f"Raw **{raw}** − reduction {applied['reduction']} = "
                f"**{applied['final_damage']}** wounds{void_line}"
            ),
            inline=False,
        )
        embed.add_field(name="Result", value=self._wound_status(target_rec, applied) + heal_line, inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(embed=embed)
        dead_tag = " DEAD" if applied["is_dead"] else ""
        man_tag = f" ({self.maneuver})" if self.maneuver not in ("none", "called_shot") else ""
        cs_tag = ""
        if self.maneuver == "called_shot" and self.called_shot_raises > 0:
            part = combat.CALLED_SHOT_PARTS.get(min(self.called_shot_raises, 4), "specific part")
            cs_tag = f" (Called Shot: {part})"
        await _combat_log(
            str(interaction.guild_id),
            f"Damage: {self.attacker_name} → {self.target_name} ({self.weapon}){man_tag}{cs_tag} "
            f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
        )

        if self.maneuver == "extra_attack" and not applied["is_dead"]:
            await self._second_attack(interaction, attacker_rec, target_rec)

    async def _second_attack(
        self,
        interaction: discord.Interaction,
        attacker_rec: storage.CharacterRecord,
        target_rec: storage.CharacterRecord,
    ) -> None:
        """Roll the free second attack granted by Extra Attack (s40)."""
        attacker = attacker_rec.character
        target = target_rec.character
        wp = combat.get_weapon_profile(self.weapon)
        is_melee = wp.get("melee", True)
        enc = encounters.get(self.channel_id)
        def_conds = set()
        dc = None
        if enc:
            dc = enc.find(target.name)
            if dc:
                def_conds = dc.conditions
        cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
            def_conds, target.reflexes, target.armor_tn_bonus, is_melee,
        )
        cond_def_mod, _ = condition_effects.defender_armor_tn_mod(def_conds, is_melee)
        guard_mod2 = 0
        fd_bonus2 = dc.full_defense_bonus if dc else 0
        if enc:
            for gc in enc.combatants:
                if gc.guarding.lower() == target.name.lower():
                    guard_mod2 += 10
                    break
            if dc and dc.guarding:
                guard_mod2 -= 5
        if cond_tn_ovr is not None:
            tn = cond_tn_ovr + cond_def_mod + guard_mod2 + fd_bonus2
        else:
            tn = combat.armor_tn(target, self.defender_stance) + cond_def_mod + guard_mod2 + fd_bonus2
        outcome = combat.resolve_attack(attacker, self.weapon, tn, 0, engine)
        hit = outcome["hit"]
        embed2 = discord.Embed(
            title="⚔️ Extra Attack — 2nd strike",
            color=discord.Color.green() if hit else discord.Color.light_grey(),
        )
        embed2.add_field(
            name="Attack Roll",
            value=f"{self.attacker_name} → **{self.target_name}** with {self.weapon}\n"
                  f"Roll **{outcome['roll']}** vs TN **{outcome['target_tn']}**"
                  f" — {'**HIT**' if hit else 'miss'}",
            inline=False,
        )
        if hit:
            view2 = DamageView(
                attacker_rec.id, target_rec.id, self.weapon, 0,
                self.attacker_name, self.target_name,
                maneuver="none", attack_margin=outcome["margin"],
                defender_stance=self.defender_stance,
                channel_id=self.channel_id,
            )
            await interaction.followup.send(
                content="A DM can authorize the 2nd attack's damage below.",
                embed=embed2, view=view2,
            )
            await _combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) HIT")
        else:
            await interaction.followup.send(embed=embed2)
            await _combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) MISS")

    async def _second_attack_creature(
        self,
        interaction: discord.Interaction,
        attacker_rec: storage.CharacterRecord,
        cre_rec: storage.CreatureRecord,
    ) -> None:
        """Roll the free second attack against a creature (Extra Attack, s40)."""
        attacker = attacker_rec.character
        tn = cre_rec.creature.armor_tn
        outcome = combat.resolve_attack(attacker, self.weapon, tn, 0, engine)
        hit = outcome["hit"]
        embed2 = discord.Embed(
            title="⚔️ Extra Attack — 2nd strike",
            color=discord.Color.green() if hit else discord.Color.light_grey(),
        )
        embed2.add_field(
            name="Attack Roll",
            value=f"{self.attacker_name} → **{self.target_name}** with {self.weapon}\n"
                  f"Roll **{outcome['roll']}** vs TN **{outcome['target_tn']}**"
                  f" — {'**HIT**' if hit else 'miss'}",
            inline=False,
        )
        if hit:
            view2 = DamageView(
                attacker_rec.id, None, self.weapon, 0,
                self.attacker_name, self.target_name,
                maneuver="none", attack_margin=outcome["margin"],
                target_creature_id=cre_rec.id,
                channel_id=self.channel_id,
            )
            await interaction.followup.send(
                content="A DM can authorize the 2nd attack's damage below.",
                embed=embed2, view=view2,
            )
            await _combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) HIT")
        else:
            await interaction.followup.send(embed=embed2)
            await _combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) MISS")

    @discord.ui.button(label="No Effect", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def waive(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message(
                "Only a DM can resolve this attack.", ephemeral=True
            )
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} ruled **no effect** on "
            f"{self.attacker_name}'s hit against {self.target_name}."
        )


def _rate_status(combatant, key: str, scope: str) -> str:
    """Gate a once-per-Turn/Round kata against the live encounter tracker.

    Returns 'apply' (available — and marks it spent), 'used' (already spent this
    Turn/Round), or 'untracked' (no encounter is tracking this attacker, so the
    limit can't be enforced and the effect stays a DM-adjudicated reminder)."""
    if combatant is None:
        return "untracked"
    return "apply" if combatant.consume_once(key, scope) else "used"


def _active_ability_reminders(c: Character, role: str, drop_rate_limited: bool = False) -> list[str]:
    """DM reminder lines for a combatant's active kata/kiho that the bot does NOT
    auto-apply (rate-limited, positional, tradeoff, or every kiho). The
    deterministic kata are folded into the roll instead and shown separately.
    `drop_rate_limited` skips the kata line when a rate-limited kata was already
    enforced against the live tracker (the roll shows the enforced note instead)."""
    lines: list[str] = []
    kata_text = kata_effects.active_kata_reminder(c)
    if kata_text and not (drop_rate_limited and kata_effects.is_rate_limited(c.active_kata)):
        active = c.active_kata
        lines.append(f"**{role.capitalize()} kata — {active}:** {kata_text}")
    for name in getattr(c, "active_kiho", []) or []:
        if kiho_effects.is_auto(name):
            continue
        rec = kiho.get(name)
        effect = rec["effect"] if rec else ""
        lines.append(f"**{role.capitalize()} kiho — {name}:** {effect}")
    return lines


_MANEUVER_CHOICES = [
    app_commands.Choice(name="None", value="none"),
    app_commands.Choice(name="Feint (2 raises → bonus damage)", value="feint"),
    app_commands.Choice(name="Disarm (3 raises → 2k1 + contested Strength)", value="disarm"),
    app_commands.Choice(name="Knockdown (2 raises → contested Strength)", value="knockdown"),
    app_commands.Choice(name="Called Shot (1-4 raises → target body part)", value="called_shot"),
    app_commands.Choice(name="Extra Attack (5 raises → second attack)", value="extra_attack"),
]


@client.tree.command(
    name="attack",
    description="Attack another character. Rolls to hit; on a hit a DM authorizes the outcome.",
)
@app_commands.describe(
    target="The player to attack (their active character). Or use target_npc / target_creature.",
    target_npc="Attack a stored NPC by name (instead of a player).",
    target_creature="Attack a spawned creature by name (instead of a player).",
    attacker_npc="Attack WITH a stored NPC instead of your own character (DM only).",
    weapon="Weapon for this attack. Defaults to your wielded weapon (`/sheet wield`), else katana.",
    raises="Called Raises — each adds +5 to the target's Armor TN.",
    increased_damage="Increased Damage raises — each adds +5 TN AND +1 damage die on a hit.",
    maneuver="A combat maneuver (its raise cost is added to the TN automatically).",
    spend_void="Spend a Void Point for +1k1 on the attack roll (RAW: not valid on damage).",
    attacker_stance="Your stance (Full Attack = +2k1 to hit).",
    defender_stance="Target's stance (affects their Armor TN).",
    bonus_tn="Situational +/- to the target's Armor TN (DM discretion).",
)
@app_commands.autocomplete(
    weapon=_weapon_autocomplete, target_npc=_npc_autocomplete, attacker_npc=_npc_autocomplete,
    target_creature=_creature_instance_autocomplete,
)
@app_commands.choices(
    attacker_stance=_ATTACKER_STANCES, defender_stance=_DEFENDER_STANCES, maneuver=_MANEUVER_CHOICES
)
async def attack(
    interaction: discord.Interaction,
    target: discord.Member | None = None,
    target_npc: str | None = None,
    target_creature: str | None = None,
    attacker_npc: str | None = None,
    weapon: str | None = None,
    raises: app_commands.Range[int, 0, 10] = 0,
    increased_damage: app_commands.Range[int, 0, 10] = 0,
    maneuver: app_commands.Choice[str] | None = None,
    spend_void: bool = False,
    attacker_stance: app_commands.Choice[str] | None = None,
    defender_stance: app_commands.Choice[str] | None = None,
    bonus_tn: app_commands.Range[int, -50, 50] = 0,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)

    # Resolve the attacker: a stored NPC (DM only) or the caller's active character.
    if attacker_npc:
        if not _is_dm(interaction):
            await interaction.response.send_message(
                "Only a DM can attack with an NPC.", ephemeral=True
            )
            return
        attacker_rec = store.get_by_name(guild, NPC_OWNER, attacker_npc)
        if attacker_rec is None:
            await interaction.response.send_message(
                f"No NPC named **{attacker_npc}**.", ephemeral=True
            )
            return
    else:
        attacker_rec = store.get_active(guild, str(interaction.user.id))
        if attacker_rec is None:
            await interaction.response.send_message(
                "You have no active character. Use `/sheet create` first.", ephemeral=True
            )
            return

    # Weapon: explicit choice, else the attacker's wielded weapon, else katana.
    weapon = (weapon or "").strip() or attacker_rec.character.equipped_weapon or "katana"

    # Resolve the target: a spawned creature, a stored NPC, or a player's character.
    target_rec = None
    target_creature_rec = None
    if target_creature:
        target_creature_rec = store.get_creature_by_name(guild, target_creature)
        if target_creature_rec is None:
            await interaction.response.send_message(
                f"No creature named **{target_creature}**.", ephemeral=True
            )
            return
    elif target_npc:
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
            "Pick a target: `target:` (player), `target_npc:`, or `target_creature:`.", ephemeral=True
        )
        return

    a_stance_explicit = attacker_stance.value if attacker_stance else None
    d_stance_explicit = defender_stance.value if defender_stance else None
    man = maneuver.value if maneuver else "none"

    if target_creature_rec is not None and man in ("disarm", "knockdown"):
        await interaction.response.send_message(
            "Disarm/Knockdown aren't supported against creatures yet — use a plain attack or Feint.",
            ephemeral=True,
        )
        return
    if man == "called_shot" and raises < 1:
        await interaction.response.send_message(
            "Called Shot requires at least 1 raise (1=limb, 2=hand/foot, 3=head, 4=eye/ear/finger).",
            ephemeral=True,
        )
        return
    if man == "extra_attack":
        enc = encounters.get(interaction.channel_id)
        if enc:
            atk_c = enc.find(attacker_rec.character.name)
            if atk_c and "extra_attack" in atk_c.used_this_turn:
                await interaction.response.send_message(
                    "Extra Attack can only be used once per Turn.", ephemeral=True
                )
                return
            if atk_c:
                atk_c.used_this_turn.add("extra_attack")
    maneuver_raises = combat.MANEUVER_RAISES.get(man, 0)

    # Void Point spend: +1k1 on the attack roll (decrement the pool now).
    void_line = ""
    bonus_rolled = bonus_kept = 0
    if spend_void:
        c = attacker_rec.character
        if c.current_void_points > 0:
            c.current_void_points -= 1
            bonus_rolled = bonus_kept = 1
            store.save(attacker_rec)
            void_line = f" · 🌀 Void +1k1 ({c.current_void_points} VP left)"
        else:
            void_line = " · 🌀 no Void Points to spend"

    # Active-kata combat modifiers (GDD s30; deterministic subset only).
    kata_notes: list[str] = []          # effects auto-applied to this roll
    rl_used_notes: list[str] = []       # rate-limited effects already spent this Turn/Round
    attacker = attacker_rec.character
    enc = encounters.get(interaction.channel_id)
    atk_combatant = enc.find(attacker.name) if enc else None
    atk_init = atk_combatant.initiative if atk_combatant else None
    def_combatant = enc.find(target_rec.character.name) if (enc and target_rec is not None) else None
    def_init = def_combatant.initiative if def_combatant else None

    # Stance resolution: explicit parameter wins; otherwise read from encounter.
    a_stance = a_stance_explicit or (atk_combatant.stance if atk_combatant else "attack")
    d_stance = d_stance_explicit or (def_combatant.stance if def_combatant else "attack")

    # A rate-limited kata is enforced by the tracker (on this roll or its damage
    # step) only while an encounter is tracking the attacker; then suppress its
    # generic reminder. Untracked -> stays a DM-adjudicated reminder.
    rate_limited_handled = atk_combatant is not None and kata_effects.is_rate_limited(attacker.active_kata)

    # Defender's active kata + known Techniques: stance-conditional Armor TN
    # bonus (players only — creatures use fixed stat blocks and carry neither).
    def_kata_bonus = 0
    if target_creature_rec is None:
        def_kata_bonus, def_note = kata_effects.defender_armor_tn_bonus(
            target_rec.character, d_stance
        )
        if def_note:
            kata_notes.append(def_note)
        def_tech_bonus, def_tech_notes = technique_effects.defender_armor_tn_bonus(
            target_rec.character, d_stance, atk_init, def_init, attacker=attacker
        )
        def_kata_bonus += def_tech_bonus
        kata_notes.extend(def_tech_notes)
        def_mastery_bonus, def_mastery_notes = skill_mastery.defender_armor_tn_bonus(target_rec.character)
        def_kata_bonus += def_mastery_bonus
        kata_notes.extend(def_mastery_notes)
        def_adv_mod, def_adv_notes = advantage_effects.defender_armor_tn_mod(target_rec.character)
        def_kata_bonus += def_adv_mod
        kata_notes.extend(def_adv_notes)
        def_kiho_tn, def_kiho_tn_notes = kiho_effects.defender_armor_tn_bonus(target_rec.character)
        def_kata_bonus += def_kiho_tn
        kata_notes.extend(def_kiho_tn_notes)
    # Attacker's active kata: flat bonus added to the attack-roll total.
    atk_flat, atk_note = kata_effects.attacker_roll_flat_bonus(attacker, man, increased_damage)
    if atk_note:
        kata_notes.append(atk_note)
    # Rate-limited: Striking as Fire adds Fire Ring to one attack roll per Round.
    sf_val, sf_note = kata_effects.striking_as_fire_bonus(attacker, a_stance)
    if sf_val:
        status = _rate_status(atk_combatant, "striking_as_fire", "round")
        if status == "apply":
            atk_flat += sf_val
            kata_notes.append(sf_note)
        elif status == "used":
            rl_used_notes.append("Striking as Fire already used this Round.")
    # Attacker's active kata: a Trait replaced by a Ring on the attack roll.
    atk_weapon_profile = combat.get_weapon_profile(weapon)
    trait_ovr, trait_ovr_note = kata_effects.attacker_trait_override(attacker, atk_weapon_profile)
    trait_ovr_name = "Air" if trait_ovr is not None else ""
    if trait_ovr_note:
        kata_notes.append(trait_ovr_note)
    # Rate-limited: Strength in Arms uses Strength (not Agility) once per Turn (Heavy Weapon).
    if trait_ovr is None:
        sia_val, sia_note = kata_effects.strength_in_arms_override(attacker, atk_weapon_profile)
        if sia_val is not None:
            status = _rate_status(atk_combatant, "strength_in_arms", "turn")
            if status == "apply":
                trait_ovr, trait_ovr_name = sia_val, "Strength"
                kata_notes.append(sia_note)
            elif status == "used":
                rl_used_notes.append("Strength in Arms already used this Turn.")
    # Technique trait override (Falcon's Strike: Perception for bow attacks) —
    # only if no kata already replaced the attack Trait.
    if trait_ovr is None:
        to_val, to_name, to_note = technique_effects.attacker_trait_override(attacker, atk_weapon_profile)
        if to_val is not None:
            trait_ovr, trait_ovr_name = to_val, to_name
            kata_notes.append(to_note)

    # Attacker's known Techniques: extra attack dice / flat bonus to the roll.
    t_rolled, t_kept, t_flat, t_notes = technique_effects.attacker_attack_dice(
        attacker, atk_weapon_profile, weapon, a_stance, atk_init, def_init
    )
    bonus_rolled += t_rolled
    bonus_kept += t_kept
    atk_flat += t_flat
    kata_notes.extend(t_notes)

    # Advantage/disadvantage attack-roll modifiers (Bad Eyesight, Blind, Touch of Jigoku).
    adv_rolled, adv_kept, adv_flat, adv_notes = advantage_effects.attacker_attack_dice(
        attacker, atk_weapon_profile
    )
    bonus_rolled += adv_rolled
    bonus_kept += adv_kept
    atk_flat += adv_flat
    kata_notes.extend(adv_notes)

    # Advantage wound-penalty modifiers (Strength of the Earth, Low Pain Threshold).
    wp_mod, wp_notes = advantage_effects.attacker_wound_penalty_mod(attacker)
    if wp_mod:
        atk_flat += wp_mod
        kata_notes.extend(wp_notes)

    # Kiho wound-penalty modifier (Grasp the Earth Dragon).
    kiho_wp_mod, kiho_wp_notes = kiho_effects.attacker_wound_penalty_mod(attacker)
    if kiho_wp_mod:
        atk_flat += kiho_wp_mod
        kata_notes.extend(kiho_wp_notes)

    # Condition-based attack modifiers (GDD s40: Blinded, Dazed, Fatigued, Mounted, Prone).
    atk_conds = atk_combatant.conditions if atk_combatant else set()
    cond_rolled, cond_kept, cond_flat, cond_atk_notes = condition_effects.attacker_attack_dice(
        atk_conds, atk_weapon_profile
    )
    bonus_rolled += cond_rolled
    bonus_kept += cond_kept
    atk_flat += cond_flat
    kata_notes.extend(cond_atk_notes)

    # Armor attack penalty (s39: Heavy −5, Tetsu-Do −10/−5; Hida R1 exempt).
    armor_pen, armor_note = combat.armor_attack_penalty(attacker)
    if armor_pen:
        atk_flat += armor_pen
        kata_notes.append(armor_note)

    # Defender condition modifiers (Prone -10 Armor TN vs melee).
    # Kept separate from def_kata_bonus so it applies even when an override fires.
    def_conds = def_combatant.conditions if def_combatant else set()
    is_melee_attack = atk_weapon_profile.get("melee", True)
    cond_def_mod, cond_def_notes = condition_effects.defender_armor_tn_mod(def_conds, is_melee_attack)
    kata_notes.extend(cond_def_notes)

    # Skill mastery: free raises that reduce a maneuver's raise cost (s24).
    mastery_free, mastery_free_notes = skill_mastery.maneuver_free_raises(
        attacker, atk_weapon_profile, weapon, man
    )
    if mastery_free:
        maneuver_raises = max(0, maneuver_raises - mastery_free)
        kata_notes.extend(mastery_free_notes)

    # Guard maneuver TN modifiers (s40): guarded target gets +10, guarder gets -5.
    guard_mod = 0
    if enc and target_rec is not None:
        def_name_lower = target_rec.character.name.lower()
        for gc in enc.combatants:
            if gc.guarding.lower() == def_name_lower:
                guard_mod += 10
                kata_notes.append(f"Guarded by {gc.name}: +10 Armor TN")
                break
        if def_combatant and def_combatant.guarding:
            guard_mod -= 5
            kata_notes.append(f"Guarding {def_combatant.guarding}: −5 Armor TN")

    # Full Defense bonus (s40): half of Defense/Reflexes roll, set by /combat full_defense.
    fd_bonus = 0
    if def_combatant and def_combatant.full_defense_bonus:
        fd_bonus = def_combatant.full_defense_bonus
        kata_notes.append(f"Full Defense: +{fd_bonus} Armor TN")

    # Target name + Armor TN depend on the target kind.
    if target_creature_rec is not None:
        t_name = target_creature_rec.creature.name
        tn = target_creature_rec.creature.armor_tn + bonus_tn
    else:
        t_name = target_rec.character.name
        # Condition Armor TN override (Stunned/Grappled/Blinded replace the formula).
        # Overrides ignore stance and kata/technique bonuses (GDD: "5 + armor bonuses").
        # Condition modifiers (Prone -10) still stack on top.
        cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
            def_conds, target_rec.character.reflexes, target_rec.character.armor_tn_bonus,
            is_melee_attack,
        )
        if cond_tn_ovr is not None:
            tn = cond_tn_ovr + cond_def_mod + guard_mod + fd_bonus + bonus_tn
            kata_notes.extend(cond_tn_notes)
        else:
            tn = combat.armor_tn(target_rec.character, d_stance, bonus_tn + def_kata_bonus + cond_def_mod + guard_mod + fd_bonus)

    outcome = combat.resolve_attack(
        attacker, weapon, tn, raises + maneuver_raises, engine,
        attacker_stance=a_stance, increased_damage=increased_damage,
        bonus_rolled=bonus_rolled, bonus_kept=bonus_kept, extra_flat=atk_flat,
        trait_override=trait_ovr, trait_override_name=trait_ovr_name,
    )

    a_name = attacker_rec.character.name
    hit = outcome["hit"]
    embed = discord.Embed(
        title=f"⚔️ {a_name} attacks {t_name}",
        color=discord.Color.green() if hit else discord.Color.greyple(),
    )
    atk_desc = (
        f"{outcome['skill_name']} {outcome['skill_rank']} / "
        f"{outcome['trait_name'].capitalize()} with **{weapon}**"
    )
    if a_stance != "attack":
        auto_tag = " *(enc)*" if (not a_stance_explicit and atk_combatant) else ""
        atk_desc += f"  ·  {a_stance.replace('_', ' ').title()}{auto_tag}"
    if man != "none":
        atk_desc += f"  ·  Maneuver: {man.title()}"
    atk_desc += void_line
    embed.add_field(name="Attacker", value=atk_desc, inline=False)
    embed.add_field(name="Attack roll", value=_format_dice(outcome["dice"]), inline=False)

    tn_note = f"Armor TN **{outcome['target_tn']}**"
    if outcome["raises"]:
        tn_note += f" ({outcome['raises']} raises)"
    if target_creature_rec is None and d_stance != "attack":
        auto_tag = " *(enc)*" if (not d_stance_explicit and def_combatant) else ""
        tn_note += f"  ·  {d_stance.replace('_', ' ').title()}{auto_tag}"
    verdict = "✅ **HIT**" if hit else "❌ **MISS**"
    embed.add_field(
        name="Result",
        value=f"Total **{outcome['roll']}** vs {tn_note} — {verdict} (margin {outcome['margin']:+d})",
        inline=False,
    )
    if outcome["unskilled"]:
        embed.set_footer(text=f"Unskilled in {outcome['skill_name']} — dice did not explode.")

    if kata_notes:
        embed.add_field(name="⚑ Combat effects (auto-applied)", value=" · ".join(kata_notes)[:1024], inline=False)
    if rl_used_notes:
        embed.add_field(name="Rate-limited (already spent)", value="\n".join(rl_used_notes)[:1024], inline=False)
    reminders = _active_ability_reminders(attacker, "attacker", drop_rate_limited=rate_limited_handled)
    if target_creature_rec is None:
        reminders += _active_ability_reminders(target_rec.character, "defender")
    # Condition reminders for non-auto-applied effects (movement, stance limits, recovery).
    cond_reminders = condition_effects.condition_reminders(atk_conds)
    if def_conds:
        cond_reminders += condition_effects.condition_reminders(def_conds)
    reminders += cond_reminders
    if reminders:
        embed.add_field(
            name="Active abilities — DM adjudicates",
            value="\n".join(reminders)[:1024],
            inline=False,
        )

    cs_raises = raises if man == "called_shot" else 0
    if hit:
        if target_creature_rec is not None:
            view = DamageView(
                attacker_rec.id, None, weapon, increased_damage, a_name, t_name,
                maneuver=man, attack_margin=outcome["margin"],
                target_creature_id=target_creature_rec.id, defender_stance=d_stance,
                called_shot_raises=cs_raises, channel_id=interaction.channel_id,
            )
        else:
            view = DamageView(
                attacker_rec.id, target_rec.id, weapon, increased_damage, a_name, t_name,
                maneuver=man, attack_margin=outcome["margin"], defender_stance=d_stance,
                called_shot_raises=cs_raises, channel_id=interaction.channel_id,
            )
        prompt = {
            "disarm": "A DM can resolve the disarm below.",
            "knockdown": "A DM can resolve the knockdown below.",
        }.get(man, "A DM can authorize the damage below.")
        await interaction.response.send_message(content=prompt, embed=embed, view=view)
        await _combat_log(guild, f"Attack: {a_name} → {t_name} ({weapon}) HIT (roll {outcome['roll']} vs TN {outcome['target_tn']})")
    else:
        await interaction.response.send_message(embed=embed)
        await _combat_log(guild, f"Attack: {a_name} → {t_name} ({weapon}) MISS (roll {outcome['roll']} vs TN {outcome['target_tn']})")


def _apply_numeric_field(c: Character, field: str, value: float) -> None:
    """Set one numeric sheet field with clamping. Shared by /sheet set and /npc set."""
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


# ===========================================================================
# /sheet group
# ===========================================================================
sheet = app_commands.Group(name="sheet", description="Create and manage L5R 4e character sheets.")

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
    school="School (start typing for the catalog — a match auto-fills Benefit, Skills, Honor).",
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
            f"Created **{name}** ({applied['clan']} {applied['name']}) and set it active — "
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


@sheet.command(name="view", description="View a character sheet (yours, or another player's if you are a DM).")
@app_commands.describe(member="Whose active character to view (DM only). Omit for your own.")
async def sheet_view(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            await interaction.response.send_message(
                "Only a DM can view another player's sheet.", ephemeral=True
            )
            return
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
@app_commands.describe(member="Whose characters to list (DM only). Omit for your own.")
async def sheet_list(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    target = member or interaction.user
    if member is not None and member.id != interaction.user.id and not _is_dm(interaction):
        await interaction.response.send_message(
            "Only a DM can list another player's characters.", ephemeral=True
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
        f"— {r.character.clan or '—'} {r.character.school_type}"
        for r in records
    ]
    await interaction.response.send_message(
        f"Characters for {target.display_name}:\n" + "\n".join(lines), ephemeral=True
    )


@sheet.command(name="activate", description="Set which of your characters is active.")
@app_commands.describe(name="The character name to activate.")
async def sheet_activate(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
@app_commands.describe(name="Character name.", member="Owner of the character (DM only).")
async def sheet_delete(
    interaction: discord.Interaction, name: str, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    owner_target = interaction.user
    if member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            await interaction.response.send_message(
                "Only a DM can delete another player's character.", ephemeral=True
            )
            return
        owner_target = member
    rec = store.get_by_name(guild, str(owner_target.id), name)
    if rec is None:
        await interaction.response.send_message(f"No character named **{name}** found.", ephemeral=True)
        return
    store.delete(rec.id)
    await interaction.response.send_message(f"Deleted **{rec.character.name}**.", ephemeral=True)


@sheet.command(name="trait", description="Set a Trait (or Void) on the active character.")
@app_commands.describe(
    trait="Which Trait to set.", value="New value (0-10).",
    member="Target player (DM only). Omit for your own active character.",
)
@app_commands.choices(trait=_TRAIT_CHOICES)
async def sheet_trait(
    interaction: discord.Interaction,
    trait: app_commands.Choice[str],
    value: app_commands.Range[int, 0, 10],
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.set_trait(trait.value, value)
    store.save(rec)
    label = "Void" if trait.value == "void" else trait.value.capitalize()
    await interaction.response.send_message(
        f"Set **{label}** to **{value}** on **{rec.character.name}**.", embed=build_sheet_embed(rec)
    )


@sheet.command(name="skill", description="Set a skill rank on the active character (rank 0 removes it).")
@app_commands.describe(
    skill="Skill name (free text, e.g. Kenjutsu, Courtier).",
    rank="Rank 0-10 (0 removes the skill).",
    member="Target player (DM only). Omit for your own active character.",
)
async def sheet_skill(
    interaction: discord.Interaction,
    skill: app_commands.Range[str, 1, 40],
    rank: app_commands.Range[int, 0, 10],
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
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


@sheet.command(name="set", description="Set a numeric field (honor, glory, void points, armor, etc.).")
@app_commands.describe(
    field="Which field to set.", value="New value.",
    member="Target player (DM only). Omit for your own active character.",
)
@app_commands.choices(field=_SET_CHOICES)
async def sheet_set(
    interaction: discord.Interaction,
    field: app_commands.Choice[str],
    value: float,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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


@sheet.command(name="equip", description="Add (or remove) a weapon on your character's gear.")
@app_commands.describe(weapon="Weapon name.", remove="Remove it instead of adding.", member="Target player (DM only).")
@app_commands.autocomplete(weapon=_weapon_autocomplete)
async def sheet_equip(
    interaction: discord.Interaction,
    weapon: str,
    remove: bool = False,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
                f"Unknown weapon **{weapon}** — see `/weapon list`.", ephemeral=True
            )
            return
        if w not in [x.lower() for x in c.weapons]:
            c.weapons.append(w)
        prof = combat.WEAPON_CATALOG[w]
        msg = f"**{c.name}** equips **{w}** (DR {prof['rolled']}k{prof['kept']}, {prof['skill']})."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))


@sheet.command(name="wield", description="Set the weapon(s) you're wielding — /attack's default weapon and defender Kata gates (s30).")
@app_commands.describe(
    weapon="Main-hand weapon (start typing for suggestions).",
    off_hand="Off-hand weapon, e.g. wakizashi for a daisho. Blank clears the off hand.",
    unwield="Lower both weapons (go unarmed).",
    member="Target player (DM only).",
)
@app_commands.autocomplete(weapon=_weapon_autocomplete, off_hand=_weapon_autocomplete)
async def sheet_wield(
    interaction: discord.Interaction,
    weapon: str | None = None,
    off_hand: str | None = None,
    unwield: bool = False,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
    c.off_hand_weapon = off_hand.lower().strip() if off_hand and off_hand.strip() else ""
    store.save(rec)
    if not c.equipped_weapon:
        await interaction.response.send_message(
            "Give a `weapon:` to wield, or `unwield:true` to go unarmed.", ephemeral=True
        )
        return
    off = f" + **{c.off_hand_weapon}** (off hand)" if c.off_hand_weapon else ""
    await interaction.response.send_message(
        f"🗡️ **{c.name}** wields **{c.equipped_weapon}**{off}.", embed=build_sheet_embed(rec)
    )


@sheet.command(name="armor", description="Equip armor (sets Armor TN bonus & Reduction), or 'none' to remove.")
@app_commands.describe(armor="Armor type (bogu/ashigaru/tatami/light/heavy/tetsu_do/riding, or 'none').", member="Target player (DM only).")
@app_commands.autocomplete(armor=_armor_autocomplete)
async def sheet_armor(
    interaction: discord.Interaction,
    armor: str,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
        msg = f"**{c.name}** equips **{a}**{heavy}: Armor TN +{spec['tn_bonus']}, Reduction {spec['reduction']}."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))


@sheet.command(name="advantage", description="Record (or remove) an Advantage on your sheet (free — no XP).")
@app_commands.describe(name="Advantage name.", remove="Remove it instead.", member="Target player (DM only).")
@app_commands.autocomplete(name=_advantage_autocomplete)
async def sheet_advantage(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    adv = advantages.get(name, "advantage")
    canonical = adv["name"] if adv else name.strip()
    c = rec.character
    if remove:
        c.advantages = [x for x in c.advantages if x.lower() != canonical.lower()]
        msg = f"Removed advantage **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.advantages]:
            c.advantages.append(canonical)
        msg = f"**{c.name}** gains the advantage **{canonical}**."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))


@sheet.command(name="disadvantage", description="Record (or remove) a Disadvantage on your sheet (grants XP — DM /xp grant).")
@app_commands.describe(name="Disadvantage name.", remove="Remove it instead.", member="Target player (DM only).")
@app_commands.autocomplete(name=_disadvantage_autocomplete)
async def sheet_disadvantage(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    dis = advantages.get(name, "disadvantage")
    canonical = dis["name"] if dis else name.strip()
    c = rec.character
    if remove:
        c.disadvantages = [x for x in c.disadvantages if x.lower() != canonical.lower()]
        msg = f"Removed disadvantage **{canonical}** from **{c.name}**."
    else:
        if canonical.lower() not in [x.lower() for x in c.disadvantages]:
            c.disadvantages.append(canonical)
        grant = f" (grants {dis['points']} XP — a DM applies it with `/xp grant`)" if dis and dis["points"] else ""
        msg = f"**{c.name}** takes the disadvantage **{canonical}**{grant}."
    store.save(rec)
    await interaction.response.send_message(msg, embed=build_sheet_embed(rec))


@sheet.command(name="kata", description="Record (or remove) a Kata on your sheet (free — no XP; use /xp kata to buy).")
@app_commands.describe(name="Kata name.", remove="Remove it instead.", member="Target player (DM only).")
@app_commands.autocomplete(name=_kata_autocomplete)
async def sheet_kata(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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


@sheet.command(name="kiho", description="Record (or remove) a Kiho on your sheet (free — no XP; use /xp kiho to buy).")
@app_commands.describe(name="Kiho name.", remove="Remove it instead.", member="Target player (DM only).")
@app_commands.autocomplete(name=_kiho_autocomplete)
async def sheet_kiho(
    interaction: discord.Interaction, name: str, remove: bool = False, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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


@sheet.command(name="kata_activate", description="Set your active Kata (Simple Action; only one active — s30). Blank name drops it.")
@app_commands.describe(
    name="A Kata your character knows. Leave blank to drop the active Kata.",
    member="Target player (DM only).",
)
@app_commands.autocomplete(name=_kata_autocomplete)
async def sheet_kata_activate(
    interaction: discord.Interaction, name: str | None = None, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
            f"**{c.name}** hasn't learned the Kata **{canonical}** — add it with `/sheet kata` "
            f"or buy it with `/xp kata`.", ephemeral=True,
        )
        return
    c.active_kata = canonical
    store.save(rec)
    note = (
        "" if kata_effects.is_auto(canonical)
        else " *(its effect is DM-adjudicated — shown as a reminder on attacks.)*"
    )
    await interaction.response.send_message(
        f"🥋 **{c.name}** assumes the Kata **{canonical}**.{note}", embed=build_sheet_embed(rec)
    )


@sheet.command(name="kiho_activate", description="Activate/deactivate a Kiho (one Internal/Kharmic/Mystical; Martial stacks — s38).")
@app_commands.describe(
    name="A Kiho your character knows.",
    off="Deactivate it instead.",
    member="Target player (DM only).",
)
@app_commands.autocomplete(name=_kiho_autocomplete)
async def sheet_kiho_activate(
    interaction: discord.Interaction, name: str, off: bool = False, member: discord.Member | None = None
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
            f"**{c.name}** hasn't learned the Kiho **{canonical}** — add it with `/sheet kiho` "
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
        f"*(Activation cost — a Void Point or Meditation/Void roll — and duration are "
        f"DM-adjudicated; its combat effect is shown as a reminder on attacks.)*",
        embed=build_sheet_embed(rec),
    )


@sheet.command(name="wound", description="Apply wounds to the active character (raw, no armor reduction here).")
@app_commands.describe(
    amount="Wounds to apply.",
    member="Target player (DM only). Omit for your own active character.",
)
async def sheet_wound(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
    member="Target player (DM only). Omit for your own active character.",
)
async def sheet_heal(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
dm = app_commands.Group(name="dm", description="Manage Dungeon Master (game master) status on this server.")


def _require_admin(interaction: discord.Interaction) -> bool:
    perms = getattr(interaction.user, "guild_permissions", None)
    return perms is not None and (perms.administrator or perms.manage_guild)


@dm.command(name="grant", description="Grant DM status to a member (server admins only).")
@app_commands.describe(member="The member to make a DM.")
async def dm_grant(interaction: discord.Interaction, member: discord.Member) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _require_admin(interaction):
        await interaction.response.send_message(
            "Only server admins (Manage Server) can grant DM status.", ephemeral=True
        )
        return
    store.grant_dm(str(interaction.guild_id), str(member.id))
    await interaction.response.send_message(f"✅ {member.mention} is now a DM on this server.")


@dm.command(name="revoke", description="Revoke DM status from a member (server admins only).")
@app_commands.describe(member="The member to remove DM status from.")
async def dm_revoke(interaction: discord.Interaction, member: discord.Member) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _require_admin(interaction):
        await interaction.response.send_message(
            "Only server admins (Manage Server) can revoke DM status.", ephemeral=True
        )
        return
    store.revoke_dm(str(interaction.guild_id), str(member.id))
    await interaction.response.send_message(f"Removed DM status from {member.mention}.")


@dm.command(name="list", description="List the DMs on this server.")
async def dm_list(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    ids = store.list_dms(str(interaction.guild_id))
    if not ids:
        await interaction.response.send_message(
            "No explicit DMs granted. Server admins (Manage Server) are DMs automatically.",
            ephemeral=True,
        )
        return
    mentions = ", ".join(f"<@{uid}>" for uid in ids)
    await interaction.response.send_message(
        f"DMs on this server: {mentions}\n*(Server admins are also DMs automatically.)*",
        ephemeral=True,
    )


SPELL_ELEMENTS = ("air", "earth", "fire", "water", "void")


@dm.command(name="new_day", description="Advance to a new day: refresh spell slots and apply natural healing for all active PCs.")
async def dm_new_day(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can advance the day.", ephemeral=True)
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
        store.save(rec)
        slots_str = ", ".join(
            f"{e.title()} {c.spell_slots[e]}" for e in SPELL_ELEMENTS
        )
        parts.append(f"slots: {slots_str}")
        lines.append(f"**{c.name}** — {' · '.join(parts)}")
    embed = discord.Embed(
        title="New Day",
        description="\n".join(lines),
        color=discord.Color.green(),
    )
    embed.set_footer(text="Rest: full VP · Stamina x 2 healing · Spell slots: Ring + School Rank per element")
    await interaction.response.send_message(embed=embed)


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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can use this.", ephemeral=True)
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
        title=f"💥 Pending damage — {c.name}",
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
    view = DmDamageView(
        target_id=rec.id, target_name=c.name,
        amount=amount, reason=reason,
    )
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can use this.", ephemeral=True)
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
    if c.wounds_taken <= 0:
        await interaction.response.send_message(f"**{c.name}** has no wounds to heal.", ephemeral=True)
        return
    wl = stats.wound_level_name(c)
    embed = discord.Embed(
        title=f"💚 Pending healing — {c.name}",
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
    view = DmHealView(
        target_id=rec.id, target_name=c.name,
        amount=amount, reason=reason,
    )
    await interaction.response.send_message(
        content="A DM can authorize the healing below.",
        embed=embed, view=view,
    )


# ===========================================================================
# /combat group — initiative tracker
# ===========================================================================
combat_group = app_commands.Group(name="combat", description="Track combat initiative and turn order.")


def _wound_track(c) -> str:
    """Visual wound track: shows each level with the current position marked."""
    names = ["Healthy", "Nicked", "Grazed", "Hurt", "Injured", "Crippled", "Down", "Out", "Dead"]
    short = ["H", "Ni", "Gr", "Hu", "In", "Cr", "Dn", "Ou", "De"]
    idx = stats.wound_level_index(c)
    parts = []
    for i, s in enumerate(short):
        if i == idx:
            parts.append(f"[**{s}**]")
        else:
            parts.append(s)
    return " → ".join(parts)


def _stance_effects(stance: str) -> str:
    effects = {
        "attack": "",
        "full_attack": "+2k1 attack rolls, −10 Armor TN. Cannot use Defense/Full Defense.",
        "defense": "+Air Ring + Defense skill to Armor TN.",
        "full_defense": "Defense/Reflexes roll → half (rounded up) added to ATN. Complex Action. Cannot attack.",
        "center": "+Void Ring to Armor TN. Regain Void Point if not struck before next turn.",
    }
    return effects.get(stance, "")


def _render_encounter(enc: encounter.Encounter) -> str:
    if not enc.combatants:
        return "No combatants yet. Add them with `/combat join` or `/combat add`."
    cur = enc.current()
    lines = []
    for i, c in enumerate(enc.combatants):
        marker = "▶️ " if (enc.started and c is cur) else f"{i + 1}. "
        tag = " *(NPC)*" if c.is_npc else ""
        detail = f"  ·  {c.initiative_detail}" if c.initiative_detail else ""
        stance_str = f"  ⚔️{c.stance.replace('_', ' ').title()}" if c.stance != "attack" else ""
        acts = f"  [{c.actions_used}/2 acts]" if enc.started and c.actions_used > 0 else ""
        cond = f"  [{', '.join(sorted(c.conditions))}]" if c.conditions else ""
        guard = f"  🛡️→{c.guarding}" if c.guarding else ""
        fd = f"  🛡️FD+{c.full_defense_bonus}" if c.full_defense_bonus else ""
        held = "  ⏸️HELD" if c.held else ""
        delayed = "  ⏳DELAYED" if c.delayed else ""
        lines.append(f"{marker}**{c.name}**{tag} — init **{c.initiative}**{detail}{stance_str}{acts}{cond}{guard}{fd}{held}{delayed}")
    header = f"⚔️ **Round {enc.round}**"
    if enc.surprise_round:
        header += " *(Surprise)*"
    if not enc.started:
        header = "⚔️ **Not started** — use `/combat next` to begin."
        if enc.surprise_round:
            header += " *(Surprise Round)*"
    return header + "\n" + "\n".join(lines)


@combat_group.command(name="start", description="Start a fresh initiative tracker in this channel.")
async def combat_start(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    encounters[interaction.channel_id] = encounter.Encounter(channel_id=interaction.channel_id)
    await interaction.response.send_message(
        "⚔️ New encounter started. Add combatants with `/combat join` (your character) "
        "or `/combat add` (an NPC), then `/combat next` to begin."
    )
    await _combat_log(str(interaction.guild_id), "--- Encounter started ---")


def _get_or_create(channel_id: int) -> encounter.Encounter:
    enc = encounters.get(channel_id)
    if enc is None:
        enc = encounter.Encounter(channel_id=channel_id)
        encounters[channel_id] = enc
    return enc


@combat_group.command(name="join", description="Add a character to initiative (rolls initiative).")
@app_commands.describe(member="Add another player's active character (DM only). Omit for your own.")
async def combat_join(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            await interaction.response.send_message(
                "Only a DM can add another player's character.", ephemeral=True
            )
            return
        owner = member
    else:
        owner = interaction.user
    rec = store.get_active(guild, str(owner.id))
    if rec is None:
        who = "You have" if owner.id == interaction.user.id else f"{owner.display_name} has"
        await interaction.response.send_message(f"{who} no active character.", ephemeral=True)
        return

    result = combat.roll_initiative(rec.character, engine)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(rec.character.name)  # re-join re-rolls
    enc.add(encounter.Combatant(
        name=rec.character.name,
        initiative=result.total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}",
        owner_id=str(owner.id),
        is_npc=False,
        reflexes=rec.character.reflexes,
    ))
    await interaction.response.send_message(_render_encounter(enc))
    await _combat_log(guild, f"Joined: {rec.character.name} (Init {result.total})")


@combat_group.command(name="add", description="Add an NPC/monster to initiative by its Reflexes and Insight Rank.")
@app_commands.describe(
    name="NPC name.", reflexes="NPC Reflexes.", insight_rank="NPC Insight Rank (1 if unknown).",
)
async def combat_add(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 40],
    reflexes: app_commands.Range[int, 1, 10],
    insight_rank: app_commands.Range[int, 1, 10] = 1,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message(
            "Only a DM can add NPCs to initiative.", ephemeral=True
        )
        return
    result = engine.roll_and_keep(reflexes + insight_rank, reflexes)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(name)
    enc.add(encounter.Combatant(
        name=name,
        initiative=result.total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}",
        owner_id=None,
        is_npc=True,
        reflexes=reflexes,
    ))
    await interaction.response.send_message(_render_encounter(enc))
    await _combat_log(str(interaction.guild_id), f"Added NPC: {name} (Init {result.total})")


@combat_group.command(name="next", description="Advance to the next combatant's turn.")
async def combat_next(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None or not enc.combatants:
        await interaction.response.send_message(
            "No encounter here. Start one with `/combat start`.", ephemeral=True
        )
        return
    prev_round = enc.round
    current = enc.advance()
    parts = [f"➡️ It is now **{current.name}**'s turn."]
    reminders = condition_effects.condition_reminders(current.conditions)
    if reminders:
        parts.append("\n".join(reminders))
    parts.append(_render_encounter(enc))
    await interaction.response.send_message("\n\n".join(parts))
    guild = str(interaction.guild_id)
    if enc.round != prev_round:
        await _combat_log(guild, f"--- Round {enc.round} ---")
    cond_str = f" [{', '.join(sorted(current.conditions))}]" if current.conditions else ""
    await _combat_log(guild, f"Turn: {current.name}{cond_str}")


@combat_group.command(name="status", description="Show the current initiative order.")
async def combat_status(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message(
            "No encounter here. Start one with `/combat start`.", ephemeral=True
        )
        return
    await interaction.response.send_message(_render_encounter(enc))


@combat_group.command(name="remove", description="Remove a combatant from initiative.")
@app_commands.describe(name="The combatant name to remove.")
async def combat_remove(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None or not enc.remove(name):
        await interaction.response.send_message(f"No combatant named **{name}** here.", ephemeral=True)
        return
    await interaction.response.send_message(f"Removed **{name}**.\n\n{_render_encounter(enc)}")


@combat_group.command(name="end", description="End the encounter in this channel.")
async def combat_end(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if encounters.pop(interaction.channel_id, None) is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    await interaction.response.send_message("⚔️ Encounter ended.")
    await _combat_log(str(interaction.guild_id), "--- Encounter ended ---")


@combat_group.command(name="summary", description="Compact overview of all combatants' key stats. DM only.")
async def combat_summary(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can view the combat summary.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None or not enc.combatants:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    title = f"⚔️ Combat Summary — Round {enc.round}"
    if enc.surprise_round:
        title += " (Surprise)"
    embed = discord.Embed(title=title, color=discord.Color.dark_red())
    for cb in enc.combatants:
        rec = _resolve_combatant_record(guild, cb)
        if rec is not None:
            c = rec.character
            lvl = stats.wound_level_name(c)
            pen = stats.wound_penalty(c)
            cap = stats.total_wound_capacity(c)
            tn = combat.armor_tn(c, cb.stance)
            pen_str = f" ⚠️ **{pen} penalty**" if pen else ""
            vp = f"{c.current_void_points}/{c.max_void_points} VP"
            conds = ", ".join(sorted(cb.conditions)) if cb.conditions else "—"
            fd = f", FD+{cb.full_defense_bonus}" if cb.full_defense_bonus else ""
            guard = f", guarding {cb.guarding}" if cb.guarding else ""
            held = ", HELD" if cb.held else ""
            delayed = ", DELAYED" if cb.delayed else ""
            stance_label = cb.stance.replace("_", " ").title()
            acts_left = 2 - cb.actions_used
            value = (
                f"Wounds: {c.wounds_taken}/{cap} **{lvl}**{pen_str}\n"
                f"ATN: **{tn}** · {vp} · Stance: **{stance_label}** · Acts: {acts_left}\n"
                f"Conditions: {conds}{fd}{guard}{held}{delayed}"
            )
        else:
            conds = ", ".join(sorted(cb.conditions)) if cb.conditions else "—"
            value = f"*(no sheet)* · Conditions: {conds}"
        marker = "▶️ " if (enc.started and cb is enc.current()) else ""
        embed.add_field(
            name=f"{marker}{cb.name} (init {cb.initiative})",
            value=value,
            inline=True,
        )
    await interaction.response.send_message(embed=embed, ephemeral=True)


@combat_group.command(name="npc", description="Add a stored NPC to initiative (rolls its initiative). DM only.")
@app_commands.describe(name="The NPC to add.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def combat_npc(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can add NPCs to initiative.", ephemeral=True)
        return
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    result = combat.roll_initiative(rec.character, engine)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(rec.character.name)
    enc.add(encounter.Combatant(
        name=rec.character.name,
        initiative=result.total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}",
        owner_id=None,
        is_npc=True,
        reflexes=rec.character.reflexes,
    ))
    await interaction.response.send_message(_render_encounter(enc))


_CONDITION_CHOICES = [
    app_commands.Choice(name=c.title(), value=c)
    for c in sorted(encounter.VALID_CONDITIONS)
]


@combat_group.command(name="condition_set", description="Apply a condition to a combatant (DM only).")
@app_commands.describe(
    name="The combatant to affect.",
    condition="The condition to apply.",
)
@app_commands.choices(condition=_CONDITION_CHOICES)
async def combat_condition_set(
    interaction: discord.Interaction,
    name: str,
    condition: app_commands.Choice[str],
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can set conditions.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    c = enc.find(name)
    if c is None:
        await interaction.response.send_message(f"No combatant named **{name}**.", ephemeral=True)
        return
    c.conditions.add(condition.value)
    await interaction.response.send_message(
        f"**{c.name}** is now **{condition.name}**.\n\n{_render_encounter(enc)}"
    )
    await _combat_log(str(interaction.guild_id), f"Condition: {c.name} +{condition.name}")


@combat_group.command(name="condition_clear", description="Remove a condition from a combatant (DM only).")
@app_commands.describe(
    name="The combatant to affect.",
    condition="The condition to remove.",
)
@app_commands.choices(condition=_CONDITION_CHOICES)
async def combat_condition_clear(
    interaction: discord.Interaction,
    name: str,
    condition: app_commands.Choice[str],
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can clear conditions.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    c = enc.find(name)
    if c is None:
        await interaction.response.send_message(f"No combatant named **{name}**.", ephemeral=True)
        return
    c.conditions.discard(condition.value)
    await interaction.response.send_message(
        f"**{c.name}** is no longer **{condition.name}**.\n\n{_render_encounter(enc)}"
    )
    await _combat_log(str(interaction.guild_id), f"Condition: {c.name} -{condition.name}")


@combat_group.command(name="conditions", description="Show a combatant's active conditions.")
@app_commands.describe(name="The combatant to check.")
async def combat_conditions(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    c = enc.find(name)
    if c is None:
        await interaction.response.send_message(f"No combatant named **{name}**.", ephemeral=True)
        return
    if not c.conditions:
        await interaction.response.send_message(f"**{c.name}** has no active conditions.")
        return
    cond_list = ", ".join(sorted(c.conditions))
    reminders = condition_effects.condition_reminders(c.conditions)
    lines = f"**{c.name}** conditions: {cond_list}"
    if reminders:
        lines += "\n" + "\n".join(reminders)
    await interaction.response.send_message(lines)


@combat_group.command(name="guard", description="Guard another combatant (+10 Armor TN to ward, −5 to you). Lasts until your next turn.")
@app_commands.describe(
    guarder="The combatant doing the guarding.",
    ward="The combatant being protected.",
)
async def combat_guard(interaction: discord.Interaction, guarder: str, ward: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can assign Guard.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    g = enc.find(guarder)
    if g is None:
        await interaction.response.send_message(f"No combatant named **{guarder}**.", ephemeral=True)
        return
    w = enc.find(ward)
    if w is None:
        await interaction.response.send_message(f"No combatant named **{ward}**.", ephemeral=True)
        return
    if g.name == w.name:
        await interaction.response.send_message("A combatant cannot guard themselves.", ephemeral=True)
        return
    g.guarding = w.name
    await interaction.response.send_message(
        f"🛡️ **{g.name}** is guarding **{w.name}**.\n"
        f"  Ward: +10 Armor TN · Guarder: −5 Armor TN\n"
        f"  Expires at the start of {g.name}'s next turn."
    )
    await _combat_log(str(interaction.guild_id), f"Guard: {g.name} guards {w.name}")


@combat_group.command(name="full_defense", description="Full Defense: Defense/Reflexes roll, half (rounded up) added to Armor TN until next turn.")
@app_commands.describe(
    combatant="The combatant entering Full Defense.",
    reflexes="Override Reflexes (for ad-hoc NPCs without a sheet).",
    defense_skill="Override Defense skill rank (for ad-hoc NPCs without a sheet).",
)
async def combat_full_defense(
    interaction: discord.Interaction,
    combatant: str,
    reflexes: app_commands.Range[int, 1, 10] | None = None,
    defense_skill: app_commands.Range[int, 0, 10] | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can declare Full Defense.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    cb = enc.find(combatant)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{combatant}**.", ephemeral=True)
        return
    ref = reflexes
    def_sk = defense_skill
    if ref is None or def_sk is None:
        guild = str(interaction.guild_id)
        rec = None
        if cb.is_npc:
            rec = store.get_by_name(guild, NPC_OWNER, cb.name)
        elif cb.owner_id:
            rec = store.get_active(guild, cb.owner_id)
        if rec is not None:
            if ref is None:
                ref = rec.character.reflexes
            if def_sk is None:
                def_sk = rec.character.skills.get("Defense", 0)
    if ref is None or def_sk is None:
        await interaction.response.send_message(
            f"Cannot resolve stats for **{cb.name}**. Provide `reflexes:` and `defense_skill:` explicitly.",
            ephemeral=True,
        )
        return
    result = combat.roll_full_defense(ref, def_sk, engine)
    cb.full_defense_bonus = result["bonus"]
    await interaction.response.send_message(
        f"🛡️ **{cb.name}** enters **Full Defense**.\n"
        f"  Roll: {result['rolled']}k{result['kept']} → **{result['total']}** · "
        f"half (rounded up) = **+{result['bonus']} Armor TN**\n"
        f"  Complex Action — only Free Actions until next turn.\n"
        f"  Expires at the start of {cb.name}'s next turn."
    )
    await _combat_log(str(interaction.guild_id), f"Full Defense: {cb.name} (+{result['bonus']} Armor TN)")


# ===========================================================================
# /grapple group — grappling subsystem (s40)
# ===========================================================================
grapple_group = app_commands.Group(name="grapple", description="Grappling subsystem: initiate, control, hit, throw, break (s40).")


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


@grapple_group.command(name="initiate", description="Initiate a Grapple: Jiujutsu/Agility vs Armor TN (ignoring armor bonus). DM only.")
@app_commands.describe(
    attacker="The combatant initiating the grapple.",
    target="The target being grappled.",
    bonus_tn="DM situational TN modifier.",
    defender_stance="Target's stance.",
)
@app_commands.choices(defender_stance=_DEFENDER_STANCES)
async def grapple_initiate(
    interaction: discord.Interaction,
    attacker: str,
    target: str,
    bonus_tn: int = 0,
    defender_stance: app_commands.Choice[str] | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can initiate a grapple.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    atk_cb = enc.find(attacker)
    if atk_cb is None:
        await interaction.response.send_message(f"No combatant named **{attacker}**.", ephemeral=True)
        return
    def_cb = enc.find(target)
    if def_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    atk_rec = _resolve_combatant_record(guild, atk_cb)
    def_rec = _resolve_combatant_record(guild, def_cb)
    if atk_rec is None or def_rec is None:
        await interaction.response.send_message(
            "Both combatants need stored character sheets for grapple initiation.", ephemeral=True
        )
        return
    d_stance = defender_stance.value if defender_stance else "attack"
    tn = combat.grapple_initiate_tn(def_rec.character, d_stance, bonus_tn)
    # Full Defense bonus and condition/guard modifiers still apply to the TN.
    extra_tn = 0
    if def_cb.full_defense_bonus:
        extra_tn += def_cb.full_defense_bonus
    # Condition TN override (Stunned/Grappled replace formula).
    def_conds = def_cb.conditions
    cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
        def_conds, def_rec.character.reflexes, def_rec.character.armor_tn_bonus, True,
    )
    cond_def_mod, _ = condition_effects.defender_armor_tn_mod(def_conds, True)
    if cond_tn_ovr is not None:
        tn = cond_tn_ovr + cond_def_mod + extra_tn + bonus_tn
    else:
        tn += cond_def_mod + extra_tn
    outcome = combat.resolve_grapple_initiate(atk_rec.character, tn, engine)
    hit = outcome["hit"]
    embed = discord.Embed(
        title=f"🤼 {atk_cb.name} attempts to grapple {def_cb.name}",
        color=discord.Color.green() if hit else discord.Color.greyple(),
    )
    embed.add_field(
        name="Grapple Attack (Jiujutsu/Agility)",
        value=f"Roll **{outcome['roll']}** vs TN **{outcome['target_tn']}**"
              f" — {'**GRAPPLED**' if hit else 'miss'}"
              f"\n({outcome['rolled']}k{outcome['kept']}, wound penalty {outcome['wound_penalty']})",
        inline=False,
    )
    if hit:
        atk_cb.conditions.add("grappled")
        def_cb.conditions.add("grappled")
        embed.add_field(
            name="Result",
            value=f"Both **{atk_cb.name}** and **{def_cb.name}** are now **Grappled**.\n"
                  f"{atk_cb.name} has initial control.",
            inline=False,
        )
    await interaction.response.send_message(embed=embed)
    tag = "GRAPPLED" if hit else "MISS"
    await _combat_log(guild, f"Grapple: {atk_cb.name} → {def_cb.name} {tag}")


@grapple_group.command(name="control", description="Contested Jiujutsu/Strength roll for grapple control. DM only.")
@app_commands.describe(
    combatant_a="First grapple participant.",
    combatant_b="Second grapple participant.",
)
async def grapple_control(
    interaction: discord.Interaction,
    combatant_a: str,
    combatant_b: str,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can roll grapple control.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    cb_a = enc.find(combatant_a)
    cb_b = enc.find(combatant_b)
    if cb_a is None:
        await interaction.response.send_message(f"No combatant named **{combatant_a}**.", ephemeral=True)
        return
    if cb_b is None:
        await interaction.response.send_message(f"No combatant named **{combatant_b}**.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec_a = _resolve_combatant_record(guild, cb_a)
    rec_b = _resolve_combatant_record(guild, cb_b)
    if rec_a is None or rec_b is None:
        await interaction.response.send_message(
            "Both combatants need stored character sheets for grapple control.", ephemeral=True
        )
        return
    str_a = rec_a.character.strength
    jiu_a = rec_a.character.skills.get("Jiujutsu", 0)
    str_b = rec_b.character.strength
    jiu_b = rec_b.character.skills.get("Jiujutsu", 0)
    wp_a = stats.wound_penalty(rec_a.character)
    wp_b = stats.wound_penalty(rec_b.character)
    result = combat.resolve_grapple_control(str_a, jiu_a, str_b, jiu_b, engine, wp_a, wp_b)
    if result["winner"] == "a":
        winner, loser = cb_a.name, cb_b.name
    elif result["winner"] == "b":
        winner, loser = cb_b.name, cb_a.name
    else:
        winner = "Tie (previous controller retains)"
        loser = ""
    embed = discord.Embed(
        title="🤼 Grapple Control — Contested Jiujutsu/Strength",
        color=discord.Color.blue(),
    )
    embed.add_field(
        name=cb_a.name,
        value=f"({str_a + jiu_a}k{str_a}) → **{result['total_a']}**",
        inline=True,
    )
    embed.add_field(
        name=cb_b.name,
        value=f"({str_b + jiu_b}k{str_b}) → **{result['total_b']}**",
        inline=True,
    )
    if loser:
        embed.add_field(name="Control", value=f"**{winner}** has control.", inline=False)
    else:
        embed.add_field(name="Control", value=f"**{winner}**", inline=False)
    await interaction.response.send_message(embed=embed)
    await _combat_log(guild, f"Grapple Control: {winner} wins")


@grapple_group.command(name="hit", description="Grapple Hit: unarmed damage on a grappled opponent (no attack roll). DM only.")
@app_commands.describe(
    attacker="The combatant in control (dealing damage).",
    target="The grapple participant receiving damage.",
)
async def grapple_hit(
    interaction: discord.Interaction,
    attacker: str,
    target: str,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can resolve a grapple hit.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    atk_cb = enc.find(attacker)
    def_cb = enc.find(target)
    if atk_cb is None:
        await interaction.response.send_message(f"No combatant named **{attacker}**.", ephemeral=True)
        return
    if def_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    atk_rec = _resolve_combatant_record(guild, atk_cb)
    def_rec = _resolve_combatant_record(guild, def_cb)
    if atk_rec is None:
        await interaction.response.send_message(f"No character sheet for **{attacker}**.", ephemeral=True)
        return
    if def_rec is None:
        await interaction.response.send_message(f"No character sheet for **{target}**.", ephemeral=True)
        return
    embed = discord.Embed(
        title=f"🤼 Grapple Hit — {atk_cb.name} strikes {def_cb.name}",
        description="Unarmed damage, no attack roll (controller's action).",
        color=discord.Color.orange(),
    )
    view = DamageView(
        atk_rec.id, def_rec.id, "unarmed", 0,
        atk_cb.name, def_cb.name,
        maneuver="none", attack_margin=0,
        defender_stance="attack",
        channel_id=interaction.channel_id,
    )
    await interaction.response.send_message(embed=embed, view=view)


@grapple_group.command(name="throw", description="Grapple Throw: target becomes Prone and leaves the grapple. DM only.")
@app_commands.describe(
    thrower="The combatant in control (throwing).",
    target="The combatant being thrown.",
)
async def grapple_throw(
    interaction: discord.Interaction,
    thrower: str,
    target: str,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can resolve a grapple throw.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    thrower_cb = enc.find(thrower)
    target_cb = enc.find(target)
    if thrower_cb is None:
        await interaction.response.send_message(f"No combatant named **{thrower}**.", ephemeral=True)
        return
    if target_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    target_cb.conditions.discard("grappled")
    target_cb.conditions.add("prone")
    await interaction.response.send_message(
        f"🤼 **{thrower_cb.name}** throws **{target_cb.name}**!\n"
        f"  {target_cb.name} is now **Prone** and removed from the grapple.\n"
        f"  (Standing up is a Simple Action.)"
    )
    await _combat_log(str(interaction.guild_id), f"Grapple Throw: {thrower_cb.name} throws {target_cb.name} (prone)")


@grapple_group.command(name="break_free", description="Break free from a grapple (Simple Action for controller). DM only.")
@app_commands.describe(combatant="The combatant leaving the grapple.")
async def grapple_break(
    interaction: discord.Interaction,
    combatant: str,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can break a grapple.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here.", ephemeral=True)
        return
    cb = enc.find(combatant)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{combatant}**.", ephemeral=True)
        return
    cb.conditions.discard("grappled")
    await interaction.response.send_message(
        f"🤼 **{cb.name}** breaks free from the grapple.\n"
        f"  (Grappled condition removed.)"
    )
    await _combat_log(str(interaction.guild_id), f"Grapple Break: {cb.name} breaks free")


# ===========================================================================
# /duel group — Iaijutsu dueling (s40)
# ===========================================================================
duel_group = app_commands.Group(name="duel", description="Iaijutsu dueling: assessment, focus, strike (s40).")


@duel_group.command(name="assess", description="Assessment stage: both duelists roll Iaijutsu(Assessment)/Awareness. DM only.")
@app_commands.describe(
    duelist_a="First duelist (combatant name or character).",
    duelist_b="Second duelist (combatant name or character).",
    a_is_npc="First duelist is a stored NPC.",
    b_is_npc="Second duelist is a stored NPC.",
    a_member="First duelist is another player's character.",
    b_member="Second duelist is another player's character.",
)
async def duel_assess(
    interaction: discord.Interaction,
    duelist_a: str,
    duelist_b: str,
    a_is_npc: bool = False,
    b_is_npc: bool = False,
    a_member: discord.Member | None = None,
    b_member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can run a duel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _resolve_duelist(guild, ch, duelist_a, a_is_npc, a_member)
    rec_b = _resolve_duelist(guild, ch, duelist_b, b_is_npc, b_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{duelist_a}**.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"No character found for **{duelist_b}**.", ephemeral=True)
        return

    ca, cb_char = rec_a.character, rec_b.character
    ir_a = stats.insight_rank(ca)
    ir_b = stats.insight_rank(cb_char)
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb_char)

    res_a = combat.resolve_iaijutsu_assessment(
        ca.awareness, ca.skills.get("Iaijutsu", 0), ir_b, engine, extra_flat=wp_a,
    )
    res_b = combat.resolve_iaijutsu_assessment(
        cb_char.awareness, cb_char.skills.get("Iaijutsu", 0), ir_a, engine, extra_flat=wp_b,
    )

    diff_ab = res_a["total"] - res_b["total"]
    focus_bonus = ""
    if diff_ab >= 10:
        focus_bonus = f"⚡ **{ca.name}** exceeded by {diff_ab} → **+1k1** on Focus roll."
    elif diff_ab <= -10:
        focus_bonus = f"⚡ **{cb_char.name}** exceeded by {-diff_ab} → **+1k1** on Focus roll."

    embed = discord.Embed(title=f"⚔️ Iaijutsu Duel — Assessment", color=discord.Color.gold())

    def _reveal_text(res, opponent):
        if not res["success"]:
            return "Failed — no information learned."
        reveals = res["reveals"]
        opponent_ir = stats.insight_rank(opponent)
        opponent_iaijutsu = opponent.skills.get("Iaijutsu", 0)
        available = [
            f"Void Ring: **{opponent.void_ring}**",
            f"Reflexes: **{opponent.reflexes}**",
            f"Iaijutsu Skill: **{opponent_iaijutsu}**",
            f"Iaijutsu Emphases: **{'Assessment, Focus' if opponent_iaijutsu >= 1 else 'none listed'}**",
            f"Void Points: **{opponent.current_void_points}**",
            f"Wound Level: **{stats.wound_level_name(opponent)}**",
        ]
        chosen = available[:reveals]
        return "Learned " + str(reveals) + ":\n" + "\n".join(chosen)

    embed.add_field(
        name=f"{ca.name} — Assessment",
        value=(
            f"{res_a['rolled']}k{res_a['kept']} → **{res_a['total']}** vs TN **{res_a['tn']}**"
            f" — {'**SUCCESS**' if res_a['success'] else '**FAILED**'}"
            + (f" (wound penalty {wp_a})" if wp_a else "")
            + "\n" + _reveal_text(res_a, cb_char)
        ),
        inline=False,
    )
    embed.add_field(
        name=f"{cb_char.name} — Assessment",
        value=(
            f"{res_b['rolled']}k{res_b['kept']} → **{res_b['total']}** vs TN **{res_b['tn']}**"
            f" — {'**SUCCESS**' if res_b['success'] else '**FAILED**'}"
            + (f" (wound penalty {wp_b})" if wp_b else "")
            + "\n" + _reveal_text(res_b, ca)
        ),
        inline=False,
    )
    if focus_bonus:
        embed.add_field(name="Focus Bonus", value=focus_bonus.strip(), inline=False)
    embed.set_footer(text="Either duelist may concede after Assessment. Otherwise: /duel focus")
    await interaction.response.send_message(embed=embed)
    await _combat_log(str(interaction.guild_id), f"Duel Assess: {ca.name} vs {cb_char.name}")


@duel_group.command(name="focus", description="Focus stage: contested Iaijutsu(Focus)/Void roll. DM only.")
@app_commands.describe(
    duelist_a="First duelist.",
    duelist_b="Second duelist.",
    a_focus_bonus="Duelist A got +1k1 from Assessment (exceeded by 10+).",
    b_focus_bonus="Duelist B got +1k1 from Assessment (exceeded by 10+).",
    a_is_npc="First duelist is a stored NPC.",
    b_is_npc="Second duelist is a stored NPC.",
    a_member="First duelist is another player's character.",
    b_member="Second duelist is another player's character.",
)
async def duel_focus(
    interaction: discord.Interaction,
    duelist_a: str,
    duelist_b: str,
    a_focus_bonus: bool = False,
    b_focus_bonus: bool = False,
    a_is_npc: bool = False,
    b_is_npc: bool = False,
    a_member: discord.Member | None = None,
    b_member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can run a duel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _resolve_duelist(guild, ch, duelist_a, a_is_npc, a_member)
    rec_b = _resolve_duelist(guild, ch, duelist_b, b_is_npc, b_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{duelist_a}**.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"No character found for **{duelist_b}**.", ephemeral=True)
        return

    ca, cb_char = rec_a.character, rec_b.character
    bonus_r_a = 1 if a_focus_bonus else 0
    bonus_k_a = 1 if a_focus_bonus else 0
    bonus_r_b = 1 if b_focus_bonus else 0
    bonus_k_b = 1 if b_focus_bonus else 0
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb_char)

    result = combat.resolve_iaijutsu_focus(
        ca.void_ring, ca.skills.get("Iaijutsu", 0),
        cb_char.void_ring, cb_char.skills.get("Iaijutsu", 0),
        engine,
        bonus_rolled_a=bonus_r_a, bonus_kept_a=bonus_k_a,
        bonus_rolled_b=bonus_r_b, bonus_kept_b=bonus_k_b,
        extra_flat_a=wp_a, extra_flat_b=wp_b,
    )

    embed = discord.Embed(title="⚔️ Iaijutsu Duel — Focus", color=discord.Color.dark_gold())
    a_mods = []
    b_mods = []
    if a_focus_bonus:
        a_mods.append("+1k1 Assessment")
    if wp_a:
        a_mods.append(f"wound {wp_a}")
    if b_focus_bonus:
        b_mods.append("+1k1 Assessment")
    if wp_b:
        b_mods.append(f"wound {wp_b}")
    a_notes = f" ({', '.join(a_mods)})" if a_mods else ""
    b_notes = f" ({', '.join(b_mods)})" if b_mods else ""
    embed.add_field(
        name=f"{ca.name} — Focus (Iaijutsu/Void)",
        value=f"{result['a_rolled']}k{result['a_kept']}{a_notes} → **{result['a_total']}**",
        inline=True,
    )
    embed.add_field(
        name=f"{cb_char.name} — Focus (Iaijutsu/Void)",
        value=f"{result['b_rolled']}k{result['b_kept']}{b_notes} → **{result['b_total']}**",
        inline=True,
    )

    diff = abs(result["diff"])
    fs = result["first_striker"]
    if fs == "kharmic":
        outcome = (
            f"Neither exceeds by 5 — **Kharmic Strike** (simultaneous).\n"
            f"Both attack at the same time; the cause is considered dropped."
        )
    else:
        winner = ca.name if fs == "a" else cb_char.name
        loser = cb_char.name if fs == "a" else ca.name
        fr = result["free_raises"]
        fr_text = f" with **{fr} Free Raise{'s' if fr != 1 else ''}**" if fr else ""
        outcome = (
            f"**{winner}** wins Focus by {diff} → strikes first{fr_text}.\n"
            f"**{loser}** may strike after if still alive."
        )
    embed.add_field(name="Result", value=outcome, inline=False)
    embed.set_footer(text="Proceed to: /duel strike")
    await interaction.response.send_message(embed=embed)
    if fs == "kharmic":
        await _combat_log(str(interaction.guild_id), f"Duel Focus: {ca.name} vs {cb_char.name} — Kharmic Strike")
    else:
        winner = ca.name if fs == "a" else cb_char.name
        await _combat_log(str(interaction.guild_id), f"Duel Focus: {winner} strikes first (margin {diff})")


@duel_group.command(name="strike", description="Strike stage: Iaijutsu/Reflexes attack roll + damage. DM only.")
@app_commands.describe(
    attacker="The duelist striking.",
    target="The opponent being struck.",
    weapon="Weapon used (default: katana).",
    free_raises="Free Raises from Focus (auto-applied to damage total).",
    bonus_tn="DM situational modifier to the target's Armor TN.",
    attacker_npc="Attacker is a stored NPC.",
    target_npc="Target is a stored NPC.",
    attacker_member="Attacker is another player's character.",
    target_member="Target is another player's character.",
)
async def duel_strike(
    interaction: discord.Interaction,
    attacker: str,
    target: str,
    weapon: str = "katana",
    free_raises: int = 0,
    bonus_tn: int = 0,
    attacker_npc: bool = False,
    target_npc: bool = False,
    attacker_member: discord.Member | None = None,
    target_member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can run a duel strike.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _resolve_duelist(guild, ch, attacker, attacker_npc, attacker_member)
    rec_t = _resolve_duelist(guild, ch, target, target_npc, target_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{attacker}**.", ephemeral=True)
        return
    if rec_t is None:
        await interaction.response.send_message(f"No character found for **{target}**.", ephemeral=True)
        return

    atk = rec_a.character
    tgt = rec_t.character
    wp = combat.get_weapon(weapon)
    if wp is None:
        await interaction.response.send_message(f"No weapon named **{weapon}**.", ephemeral=True)
        return
    target_tn = combat.armor_tn(tgt, "center", bonus_tn)
    wound_pen = stats.wound_penalty(atk)
    result = combat.resolve_iaijutsu_strike(
        atk.reflexes, atk.skills.get("Iaijutsu", 0), target_tn, engine,
        free_raises=free_raises, extra_flat=wound_pen,
    )
    hit = result["hit"]
    embed = discord.Embed(
        title=f"⚔️ {atk.name} strikes at {tgt.name}",
        color=discord.Color.red() if hit else discord.Color.greyple(),
    )
    roll_text = (
        f"Iaijutsu/Reflexes: {result['rolled']}k{result['kept']} → **{result['total']}**"
        f" vs TN **{result['tn']}** — {'**HIT**' if hit else '**MISS**'}"
    )
    notes = []
    if wound_pen:
        notes.append(f"wound penalty {wound_pen}")
    if free_raises:
        notes.append(f"{free_raises} Free Raise{'s' if free_raises != 1 else ''} from Focus")
    if notes:
        roll_text += f"\n({', '.join(notes)})"
    embed.add_field(name="Strike Roll", value=roll_text, inline=False)

    view = None
    if hit:
        view = DamageView(
            attacker_id=rec_a.id,
            target_id=rec_t.id,
            weapon=weapon,
            increased_damage=free_raises,
            attacker_name=atk.name,
            target_name=tgt.name,
            maneuver="none",
            attack_margin=result["margin"],
            channel_id=interaction.channel_id,
        )
    else:
        embed.set_footer(text="The strike misses.")

    await interaction.response.send_message(embed=embed, view=view)
    tag = "HIT" if hit else "MISS"
    await _combat_log(guild, f"Duel Strike: {atk.name} → {tgt.name} ({weapon}) {tag} (roll {result['total']} vs TN {result['tn']})")


# ===========================================================================
# /contest — contested skill checks
# ===========================================================================
_CONTEST_TRAITS = [
    app_commands.Choice(name=("Void" if t == "void" else t.capitalize()), value=t)
    for t in enums.TRAITS
]


def _trait_value(c: Character, name: str) -> int:
    if name == "void":
        return c.void_ring
    return getattr(c, name, 0)


@client.tree.command(
    name="contest",
    description="Contested Skill/Trait roll between two characters. DM only.",
)
@app_commands.describe(
    name_a="First participant name (encounter combatant or NPC).",
    trait_a="Trait for A (the kept dice).",
    skill_a="Skill name for A (case-sensitive, e.g. 'Intimidation').",
    name_b="Second participant name.",
    trait_b="Trait for B.",
    skill_b="Skill name for B.",
    a_member="First participant (player — uses their active character).",
    b_member="Second participant (player).",
    a_is_npc="First participant is an NPC (look up by name, not encounter).",
    b_is_npc="Second participant is an NPC.",
    bonus_a="Flat bonus for A (Void Point, situational).",
    bonus_b="Flat bonus for B.",
    reason="Label shown with the roll.",
)
@app_commands.choices(trait_a=_CONTEST_TRAITS, trait_b=_CONTEST_TRAITS)
async def contest(
    interaction: discord.Interaction,
    name_a: str,
    trait_a: app_commands.Choice[str],
    skill_a: str,
    name_b: str,
    trait_b: app_commands.Choice[str],
    skill_b: str,
    a_member: discord.Member | None = None,
    b_member: discord.Member | None = None,
    a_is_npc: bool = False,
    b_is_npc: bool = False,
    bonus_a: app_commands.Range[int, -50, 50] = 0,
    bonus_b: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can run a contested check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _resolve_duelist(guild, ch, name_a, a_is_npc, a_member)
    rec_b = _resolve_duelist(guild, ch, name_b, b_is_npc, b_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{name_a}**.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"No character found for **{name_b}**.", ephemeral=True)
        return
    ca, cb = rec_a.character, rec_b.character
    tv_a = _trait_value(ca, trait_a.value)
    tv_b = _trait_value(cb, trait_b.value)
    sk_a = ca.skills.get(skill_a, 0)
    sk_b = cb.skills.get(skill_b, 0)
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb)
    result = combat.resolve_contested_check(
        tv_a, sk_a, tv_b, sk_b, engine,
        bonus_a=bonus_a + wp_a,
        bonus_b=bonus_b + wp_b,
    )
    title = "🎯 Contested Check"
    if reason:
        title += f" — {reason}"
    if result["winner"] == "a":
        color = discord.Color.green()
        verdict = f"**{ca.name}** wins by {result['margin']}!"
    elif result["winner"] == "b":
        color = discord.Color.green()
        verdict = f"**{cb.name}** wins by {result['margin']}!"
    else:
        color = discord.Color.gold()
        verdict = "**Tie!** (Higher trait breaks ties; if still tied, higher skill.)"
    embed = discord.Embed(title=title, color=color)
    a_label = f"{skill_a}/{trait_a.name}" if sk_a > 0 else f"Unskilled {skill_a}/{trait_a.name}"
    b_label = f"{skill_b}/{trait_b.name}" if sk_b > 0 else f"Unskilled {skill_b}/{trait_b.name}"
    a_wp_str = f" {wp_a}" if wp_a else ""
    b_wp_str = f" {wp_b}" if wp_b else ""
    a_bonus_str = f" {bonus_a:+d}" if bonus_a else ""
    b_bonus_str = f" {bonus_b:+d}" if bonus_b else ""
    embed.add_field(
        name=ca.name,
        value=(
            f"{a_label} ({result['rolled_a']}k{result['kept_a']}"
            f"{a_wp_str}{a_bonus_str}) → **{result['total_a']}**\n"
            f"{_format_dice(result['dice_a'])}"
        ),
        inline=False,
    )
    embed.add_field(
        name=cb.name,
        value=(
            f"{b_label} ({result['rolled_b']}k{result['kept_b']}"
            f"{b_wp_str}{b_bonus_str}) → **{result['total_b']}**\n"
            f"{_format_dice(result['dice_b'])}"
        ),
        inline=False,
    )
    embed.add_field(name="Result", value=verdict, inline=False)
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /fear — Fear check (s40 / creature Fear ratings)
# ===========================================================================
@client.tree.command(
    name="fear",
    description="Fear check: Willpower vs TN 5 + (Fear Rank x 5). DM only.",
)
@app_commands.describe(
    name="Character making the check (encounter combatant or NPC name).",
    fear_rank="Fear Rank of the source (1-10, sets TN to 5 + rank x 5).",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (Void Point, advantages, etc.).",
)
async def fear_check(
    interaction: discord.Interaction,
    name: str,
    fear_rank: app_commands.Range[int, 1, 10],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a Fear check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    wp = stats.wound_penalty(c)
    result = combat.resolve_fear_check(c.willpower, fear_rank, engine, bonus=bonus + wp)
    success = result["success"]
    tn = result["tn"]
    embed = discord.Embed(
        title=f"😨 Fear Check — {c.name}",
        color=discord.Color.green() if success else discord.Color.dark_red(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    embed.add_field(
        name="Roll",
        value=(
            f"Willpower ({result['rolled']}k{result['kept']}{wp_str}{bonus_str})"
            f" vs TN **{tn}** (Fear {fear_rank})"
        ),
        inline=False,
    )
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    verdict = "✅ **Resists the Fear!**" if success else "❌ **Fails!** Must flee or cower."
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn} — {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /honor_roll — Honor Roll (L5R 4e core p.214)
# ===========================================================================
@client.tree.command(
    name="honor_roll",
    description="Honor Roll: roll Honor Rank dice, keep 1, vs a TN. DM only.",
)
@app_commands.describe(
    name="Character making the check (encounter combatant or NPC name).",
    tn="Target Number to resist (DM sets this based on temptation).",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (advantages, situational).",
)
async def honor_roll(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 1, 100],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for an Honor Roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    hr = stats.honor_rank(c)
    result = combat.resolve_honor_roll(hr, tn, engine, bonus=bonus)
    success = result["success"]
    embed = discord.Embed(
        title=f"⚖️ Honor Roll — {c.name}",
        color=discord.Color.gold() if success else discord.Color.dark_grey(),
    )
    bonus_str = f" {bonus:+d}" if bonus else ""
    embed.add_field(
        name="Roll",
        value=(
            f"Honor Rank **{hr}** (Honor {c.honor:.1f}) → "
            f"{result['rolled']}k{result['kept']}{bonus_str} vs TN **{tn}**"
        ),
        inline=False,
    )
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    verdict = "✅ **Honor holds!**" if success else "❌ **Honor wavers.**"
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn} — {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /void group — Void Point management
# ===========================================================================
void_group = app_commands.Group(name="void", description="Void Point management: spend, refresh, status.")


@void_group.command(name="spend", description="Spend a Void Point (general purpose: +1k1, negate Conditional, etc.).")
@app_commands.describe(
    reason="What the VP is for (e.g. '+1k1 on Investigation check').",
    member="Player spending VP (uses their active character). Omit = yourself.",
    npc_name="NPC name (DM only).",
)
async def void_spend(
    interaction: discord.Interaction,
    reason: str,
    member: discord.Member | None = None,
    npc_name: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if npc_name:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can spend VP for an NPC.", ephemeral=True)
            return
        rec = store.get_by_name(guild, NPC_OWNER, npc_name)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{npc_name}**.", ephemeral=True)
            return
    elif member is not None:
        if not _is_dm(interaction) and member.id != interaction.user.id:
            await interaction.response.send_message("Only a DM can spend VP for another player.", ephemeral=True)
            return
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet activate`.", ephemeral=True)
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


@void_group.command(name="refresh", description="Refresh Void Points (rest = full, or Meditation/Void check for 1).")
@app_commands.describe(
    mode="How VP are being refreshed.",
    member="Player refreshing (uses their active character). Omit = yourself.",
    npc_name="NPC name (DM only).",
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if npc_name:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can refresh VP for an NPC.", ephemeral=True)
            return
        rec = store.get_by_name(guild, NPC_OWNER, npc_name)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{npc_name}**.", ephemeral=True)
            return
    elif member is not None:
        if not _is_dm(interaction) and member.id != interaction.user.id:
            await interaction.response.send_message("Only a DM can refresh VP for another player.", ephemeral=True)
            return
        rec = store.get_active(guild, str(member.id))
        if rec is None:
            await interaction.response.send_message(f"{member.display_name} has no active character.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet activate`.", ephemeral=True)
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
            title=f"🧘 Meditation — {c.name}",
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
                    f"**{total}** vs TN {meditation_tn} — ✅ **Success!** Recovers 1 VP.\n"
                    f"VP: **{c.current_void_points}/{c.max_void_points}**"
                ),
                inline=False,
            )
        else:
            embed.add_field(
                name="Result",
                value=(
                    f"**{total}** vs TN {meditation_tn} — ❌ **Fails.** No VP recovered.\n"
                    f"VP: **{c.current_void_points}/{c.max_void_points}**"
                ),
                inline=False,
            )
        await interaction.response.send_message(embed=embed)


@void_group.command(name="status", description="Show current Void Points for a character.")
@app_commands.describe(
    member="Player to check (uses their active character). Omit = yourself.",
    npc_name="NPC name (DM only).",
)
async def void_status(
    interaction: discord.Interaction,
    member: discord.Member | None = None,
    npc_name: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if npc_name:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can check NPC VP.", ephemeral=True)
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
            await interaction.response.send_message("You have no active character. Use `/sheet activate`.", ephemeral=True)
            return
    c = rec.character
    bar_full = "🟣" * c.current_void_points
    bar_empty = "⚫" * (c.max_void_points - c.current_void_points)
    await interaction.response.send_message(
        f"🌀 **{c.name}** — Void Points: **{c.current_void_points}/{c.max_void_points}**\n"
        f"  {bar_full}{bar_empty}\n"
        f"  Void Ring: **{c.void_ring}**",
        ephemeral=True,
    )


# ===========================================================================
# /poison — poison resistance checks
# ===========================================================================
@client.tree.command(
    name="poison",
    description="Poison resistance: Stamina vs TN (Strength x 5). DM only.",
)
@app_commands.describe(
    name="Character resisting the poison (encounter combatant or NPC name).",
    strength="Poison Strength rating (1-10; TN = Strength x 5).",
    member="Player resisting (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (advantages, antidotes, etc.).",
    poison_name="Name of the poison (for display).",
)
async def poison_resist(
    interaction: discord.Interaction,
    name: str,
    strength: app_commands.Range[int, 1, 10],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    poison_name: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a poison resistance check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    wp = stats.wound_penalty(c)
    result = combat.resolve_poison_resist(c.stamina, strength, engine, bonus=bonus + wp)
    success = result["success"]
    tn = result["tn"]
    title = f"☠️ Poison Resistance — {c.name}"
    if poison_name:
        title += f" vs {poison_name}"
    embed = discord.Embed(
        title=title,
        color=discord.Color.green() if success else discord.Color.dark_purple(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    embed.add_field(
        name="Roll",
        value=(
            f"Stamina ({result['rolled']}k{result['kept']}{wp_str}{bonus_str})"
            f" vs TN **{tn}** (Strength {strength})"
        ),
        inline=False,
    )
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    verdict = "✅ **Resists the poison!**" if success else "❌ **Succumbs!** Apply poison effects."
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn} — {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /medicine — Medicine/Intelligence checks
# ===========================================================================
@client.tree.command(
    name="medicine",
    description="Medicine/Intelligence check vs a TN (treat wounds, poison, disease). DM only.",
)
@app_commands.describe(
    name="Character making the check (encounter combatant or NPC name).",
    tn="Target Number for the treatment.",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (advantages, tools, etc.).",
    reason="What is being treated (for display).",
)
async def medicine_check(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 1, 100],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a Medicine check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    medicine_skill = c.skills.get("Medicine", 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_medicine_check(c.intelligence, medicine_skill, tn, engine, bonus=bonus + wp)
    success = result["success"]
    title = "💊 Medicine Check"
    if reason:
        title += f" — {reason}"
    embed = discord.Embed(
        title=f"{title} — {c.name}",
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
        value=f"**{result['total']}** vs TN {tn} — {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# Shared skill-check embed builder (Phases 37-40)
# ===========================================================================
def _build_check_embed(
    title: str,
    c_name: str,
    skill_label: str,
    trait_name: str,
    result: dict,
    wp: int,
    bonus: int,
    success_text: str = "✅ **Success!**",
    fail_text: str = "❌ **Failure.**",
) -> discord.Embed:
    success = result["success"]
    embed = discord.Embed(
        title=f"{title} — {c_name}",
        color=discord.Color.green() if success else discord.Color.greyple(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    embed.add_field(
        name="Roll",
        value=(
            f"{skill_label}/{trait_name} ({result['rolled']}k{result['kept']}"
            f"{wp_str}{bonus_str}) vs TN **{result['tn']}**"
        ),
        inline=False,
    )
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    verdict = success_text if success else fail_text
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {result['tn']} — {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    return embed


# ===========================================================================
# /skillcheck — generic Skill/Trait check (Phase 37)
# ===========================================================================
@client.tree.command(
    name="skillcheck",
    description="Generic Skill/Trait check vs a TN. DM picks the trait and skill. DM only.",
)
@app_commands.describe(
    name="Character making the check (encounter combatant or NPC name).",
    trait="Trait for the roll (the kept dice).",
    skill="Skill name (case-sensitive, e.g. 'Athletics'). Rank is read from the character sheet.",
    tn="Target Number.",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (Void Point, advantages, etc.).",
    reason="Label shown with the roll.",
)
@app_commands.choices(trait=_CONTEST_TRAITS)
@app_commands.autocomplete(skill=_skill_autocomplete)
async def skill_check(
    interaction: discord.Interaction,
    name: str,
    trait: app_commands.Choice[str],
    skill: str,
    tn: app_commands.Range[int, 1, 200],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a skill check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    tv = _trait_value(c, trait.value)
    sk = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(tv, sk, tn, engine, bonus=bonus + wp)
    skill_label = f"{skill} {sk}" if sk > 0 else f"{skill} (unskilled)"
    title = "🎯 Skill Check"
    if reason:
        title += f" — {reason}"
    embed = _build_check_embed(title, c.name, skill_label, trait.name, result, wp, bonus)
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /stealth — Stealth/Agility check (Phase 37)
# ===========================================================================
@client.tree.command(
    name="stealth",
    description="Stealth/Agility check vs a TN. DM only.",
)
@app_commands.describe(
    name="Character attempting stealth.",
    tn="Target Number (DM sets based on conditions, observer alertness, etc.).",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (cover, darkness, distractions, etc.).",
    reason="Label (e.g. 'sneaking past the guards').",
)
async def stealth_check(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 1, 200],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a Stealth check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    sk = c.skills.get("Stealth", 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(c.agility, sk, tn, engine, bonus=bonus + wp)
    skill_label = f"Stealth {sk}" if sk > 0 else "Stealth (unskilled)"
    title = "🥷 Stealth Check"
    if reason:
        title += f" — {reason}"
    embed = _build_check_embed(
        title, c.name, skill_label, "Agility", result, wp, bonus,
        success_text="✅ **Undetected!**",
        fail_text="❌ **Spotted!**",
    )
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /investigate — Investigation/Perception check (Phase 37)
# ===========================================================================
_INVESTIGATION_EMPHASIS = [
    app_commands.Choice(name="Notice (passive alertness)", value="Notice"),
    app_commands.Choice(name="Interrogation (questioning a subject)", value="Interrogation"),
    app_commands.Choice(name="Search (active search of an area)", value="Search"),
]


@client.tree.command(
    name="investigate",
    description="Investigation/Perception check vs a TN. DM only.",
)
@app_commands.describe(
    name="Character investigating.",
    tn="Target Number.",
    emphasis="Investigation emphasis (display/reminder — DM adjudicates emphasis reroll).",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (advantages, tools, etc.).",
    reason="Label (e.g. 'searching the crime scene').",
)
@app_commands.choices(emphasis=_INVESTIGATION_EMPHASIS)
async def investigate_check(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 1, 200],
    emphasis: app_commands.Choice[str] | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for an Investigation check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    sk = c.skills.get("Investigation", 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(c.perception, sk, tn, engine, bonus=bonus + wp)
    emp_name = emphasis.value if emphasis else None
    has_emphasis = emp_name and emp_name in c.emphases.get("Investigation", [])
    skill_label = f"Investigation {sk}" if sk > 0 else "Investigation (unskilled)"
    if emp_name:
        skill_label += f" [{emp_name}]"
    title = "🔍 Investigation"
    if emp_name:
        title += f" ({emp_name})"
    if reason:
        title += f" — {reason}"
    embed = _build_check_embed(title, c.name, skill_label, "Perception", result, wp, bonus)
    if has_emphasis:
        embed.set_footer(text=f"Has {emp_name} emphasis — reroll 1s once (DM adjudicates).")
    elif emp_name:
        embed.set_footer(text=f"No {emp_name} emphasis on sheet.")
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /social — Social skill checks (Phase 38)
# ===========================================================================
_SOCIAL_SKILLS = [
    app_commands.Choice(name="Courtier (Awareness)", value="Courtier"),
    app_commands.Choice(name="Etiquette (Awareness)", value="Etiquette"),
    app_commands.Choice(name="Intimidation (Willpower)", value="Intimidation"),
    app_commands.Choice(name="Temptation (Awareness)", value="Temptation"),
    app_commands.Choice(name="Sincerity (Awareness)", value="Sincerity"),
    app_commands.Choice(name="Perform (Awareness)", value="Perform"),
]

_SOCIAL_TRAIT_MAP: dict[str, str] = {
    "Courtier": "awareness",
    "Etiquette": "awareness",
    "Intimidation": "willpower",
    "Temptation": "awareness",
    "Sincerity": "awareness",
    "Perform": "awareness",
}


@client.tree.command(
    name="social",
    description="Social skill check vs a TN. Auto-selects the correct trait. DM only.",
)
@app_commands.describe(
    name="Character making the social check.",
    skill="Social skill (auto-selects the correct trait).",
    tn="Target Number.",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (Status, Honor, Void Point, etc.).",
    reason="Label (e.g. 'convincing the magistrate').",
)
@app_commands.choices(skill=_SOCIAL_SKILLS)
async def social_check(
    interaction: discord.Interaction,
    name: str,
    skill: app_commands.Choice[str],
    tn: app_commands.Range[int, 1, 200],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a social check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    trait_attr = _SOCIAL_TRAIT_MAP[skill.value]
    tv = _trait_value(c, trait_attr)
    sk = c.skills.get(skill.value, 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(tv, sk, tn, engine, bonus=bonus + wp)
    skill_label = f"{skill.value} {sk}" if sk > 0 else f"{skill.value} (unskilled)"
    trait_display = trait_attr.capitalize()
    title = "🗣️ Social Check"
    if reason:
        title += f" — {reason}"
    embed = _build_check_embed(title, c.name, skill_label, trait_display, result, wp, bonus)
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /craft — Artisan & Craft skill checks (Phase 39)
# ===========================================================================
@client.tree.command(
    name="craft",
    description="Artisan or Craft skill / Intelligence check vs a TN. DM only.",
)
@app_commands.describe(
    name="Character making the craft check.",
    skill="Skill name as it appears on the sheet (e.g. 'Artisan: Painting', 'Craft: Weaponsmithing').",
    tn="Target Number.",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (tools, workshop, etc.).",
    reason="Label (e.g. 'forging a katana').",
)
@app_commands.autocomplete(skill=_skill_autocomplete)
async def craft_check(
    interaction: discord.Interaction,
    name: str,
    skill: str,
    tn: app_commands.Range[int, 1, 200],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a Craft check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    sk = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(c.intelligence, sk, tn, engine, bonus=bonus + wp)
    skill_label = f"{skill} {sk}" if sk > 0 else f"{skill} (unskilled)"
    title = "🔨 Craft Check"
    if reason:
        title += f" — {reason}"
    embed = _build_check_embed(title, c.name, skill_label, "Intelligence", result, wp, bonus)
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /lore — Lore & Knowledge skill checks (Phase 40)
# ===========================================================================
@client.tree.command(
    name="lore",
    description="Lore/Intelligence check vs a TN. DM only.",
)
@app_commands.describe(
    name="Character making the knowledge check.",
    specialty="Lore specialty as on the sheet (e.g. 'Lore: Heraldry', 'Lore: Shadowlands').",
    tn="Target Number.",
    member="Player making the check (uses their active character).",
    is_npc="Character is an NPC (look up by name).",
    bonus="Flat bonus (library, scrolls, advantages, etc.).",
    reason="Label (e.g. 'identifying the creature').",
)
@app_commands.autocomplete(specialty=_skill_autocomplete)
async def lore_check(
    interaction: discord.Interaction,
    name: str,
    specialty: str,
    tn: app_commands.Range[int, 1, 200],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    reason: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for a Lore check.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    sk = c.skills.get(specialty, 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(c.intelligence, sk, tn, engine, bonus=bonus + wp)
    skill_label = f"{specialty} {sk}" if sk > 0 else f"{specialty} (unskilled)"
    title = "📚 Lore Check"
    if reason:
        title += f" — {reason}"
    embed = _build_check_embed(title, c.name, skill_label, "Intelligence", result, wp, bonus)
    await interaction.response.send_message(embed=embed)


# ===========================================================================
# /lookup — unified cross-catalog search
# ===========================================================================
@client.tree.command(
    name="lookup",
    description="Search across all catalogs at once: spells, schools, kata, kiho, advantages, weapons, creatures.",
)
@app_commands.describe(
    query="Search term (matches names, elements, categories).",
)
async def lookup(
    interaction: discord.Interaction,
    query: str,
) -> None:
    q = query.lower().strip()
    if len(q) < 2:
        await interaction.response.send_message("Search term must be at least 2 characters.", ephemeral=True)
        return

    results: list[tuple[str, str, str]] = []

    for s in spells.search(q)[:5]:
        results.append(("Spell", s["name"], f"{s['element']} {s['mastery']}"))

    for s in schools.search(q)[:5]:
        cat = s.get("category", "")
        results.append(("School", s["name"], f"{s['clan']} {cat}"))

    for k in kata.search(q)[:5]:
        results.append(("Kata", k["name"], f"{k['element']} ML{k['mastery']}"))

    for k in kiho.search(q)[:5]:
        results.append(("Kiho", k["name"], f"{k['element']} ML{k['mastery']}"))

    for a in advantages.search(q)[:5]:
        kind = a.get("kind", "")
        pts = a.get("points", "")
        results.append(("Advt/Dis", a["name"], f"{kind} ({pts} pts)"))

    for tid, t in sorted(creature.CREATURE_CATALOG.items(), key=lambda kv: kv[1].name):
        if q in tid or q in t.name.lower() or any(q in tag for tag in t.tags):
            results.append(("Creature", t.name, f"TN {t.armor_tn}, dead {t.wounds_dead}"))
            if len([r for r in results if r[0] == "Creature"]) >= 5:
                break

    for wname, w in combat.WEAPON_CATALOG.items():
        if q in wname:
            size = w.get("size", "")
            skill = w.get("skill", "")
            results.append(("Weapon", wname.replace("_", " ").title(), f"{skill}, {size}"))

    if not results:
        await interaction.response.send_message(f"No results for **{query}**.", ephemeral=True)
        return

    lines = [f"`{cat:10s}` **{name}** — {detail}" for cat, name, detail in results[:25]]
    extra = f"\n*…{len(results) - 25} more — narrow your search.*" if len(results) > 25 else ""
    await interaction.response.send_message(
        f"🔎 **{len(results)} result(s) for `{query}`:**\n" + "\n".join(lines) + extra,
        ephemeral=True,
    )


# ===========================================================================
# /help — categorized command reference
# ===========================================================================
_HELP_CATEGORIES: list[tuple[str, list[tuple[str, str]]]] = [
    ("Dice & Basics", [
        ("/ping", "Check the bot is alive (shows gateway latency)."),
        ("/whoami", "Quick glance at your active character's status."),
        ("/roll", "Roll & Keep: XkY, optional TN, raises, emphasis, unskilled."),
        ("/lookup", "Search all catalogs at once (spells, schools, kata, etc.)."),
    ]),
    ("Character Sheets", [
        ("/sheet create", "Create a character (optionally with a school)."),
        ("/sheet view", "View a sheet (yours or another player's if DM)."),
        ("/sheet list", "List your characters."),
        ("/sheet activate", "Switch your active character."),
        ("/sheet delete", "Delete a character."),
        ("/sheet trait", "Set a Trait or Void."),
        ("/sheet skill", "Set a skill rank (0 removes)."),
        ("/sheet set", "Set a numeric field (honor, glory, koku, etc.)."),
        ("/sheet wound / heal", "Apply or heal wounds."),
        ("/sheet equip", "Add/remove a weapon from gear."),
        ("/sheet wield", "Set wielded weapon(s) for /attack."),
        ("/sheet armor", "Equip armor (auto-sets TN bonus & Reduction)."),
        ("/sheet advantage / disadvantage", "Record advantages or disadvantages."),
        ("/sheet kata / kiho", "Record Kata or Kiho (free, no XP)."),
        ("/sheet kata_activate / kiho_activate", "Activate Kata (one) or Kiho (by type)."),
        ("/sheet export", "Export character sheet as JSON for backup."),
        ("/sheet import_sheet", "Import a character from JSON."),
    ]),
    ("DM Management", [
        ("/dm grant / revoke", "Grant or revoke DM status (admin only)."),
        ("/dm list", "List this server's DMs."),
        ("/dm new_day", "Advance to a new day: refresh spell slots & heal all PCs."),
        ("/dm damage", "Apply damage to a character (DM-approval gate)."),
        ("/dm heal", "Heal wounds on a character (DM-approval gate)."),
        ("/dm treat", "Medicine treatment: healer rolls, DM approves healing."),
        ("/dm log_channel", "Set a channel for automatic combat event logging."),
        ("/dm clear_log", "Stop logging combat events."),
        ("/party", "Overview of all active PCs (DM only)."),
    ]),
    ("Combat", [
        ("/attack", "Attack a character, NPC, or creature."),
        ("/combat start / end", "Start or end an encounter in this channel."),
        ("/combat join / add", "Add a PC or NPC to initiative."),
        ("/combat next", "Advance to the next combatant's turn."),
        ("/combat status", "Show initiative order."),
        ("/combat summary", "Compact stat overview of all combatants (DM)."),
        ("/combat remove", "Remove a combatant."),
        ("/combat condition_set / clear", "Apply or remove a condition (DM)."),
        ("/combat conditions", "Show a combatant's active conditions."),
        ("/combat guard", "Guard another combatant (+10 TN ward)."),
        ("/combat full_defense", "Full Defense roll (Complex Action)."),
        ("/combat creature", "Add a spawned creature to initiative."),
        ("/combat npc", "Add a stored NPC to initiative."),
    ]),
    ("Grappling & Dueling", [
        ("/grapple initiate", "Start a grapple (Jiujutsu/Agility). DM only."),
        ("/grapple control", "Contested control roll. DM only."),
        ("/grapple hit / throw / break_free", "Grapple actions. DM only."),
        ("/duel assess", "Assessment stage. DM only."),
        ("/duel focus", "Focus stage (contested). DM only."),
        ("/duel strike", "Strike stage. DM only."),
    ]),
    ("Checks & Rolls", [
        ("/contest", "Contested Skill/Trait roll between two characters. DM only."),
        ("/fear", "Fear check: Willpower vs TN. DM only."),
        ("/honor_roll", "Honor Roll: Honor Rank dice, keep 1. DM only."),
        ("/skillcheck", "Generic Skill/Trait check (DM picks trait). DM only."),
        ("/stealth", "Stealth/Agility vs TN. DM only."),
        ("/investigate", "Investigation/Perception vs TN (with emphasis). DM only."),
        ("/social", "Social skill (auto-selects trait). DM only."),
        ("/craft", "Artisan or Craft / Intelligence. DM only."),
        ("/lore", "Lore specialty / Intelligence. DM only."),
        ("/poison", "Poison resistance: Stamina vs TN. DM only."),
        ("/medicine", "Medicine/Intelligence check. DM only."),
    ]),
    ("Void Points", [
        ("/void spend", "Spend a VP with a reason label."),
        ("/void refresh", "Rest (full) or Meditation check (1 VP)."),
        ("/void status", "Show current VP bar."),
    ]),
    ("NPCs", [
        ("/npc generate", "Generate an NPC samurai (s22.4). DM only."),
        ("/npc view / list / delete", "View, roster, or remove NPCs."),
        ("/npc trait / skill / set / wound / heal / rename", "Edit NPC fields. DM only."),
    ]),
    ("Creatures", [
        ("/creature catalog", "Search the bestiary (208 creatures)."),
        ("/creature spawn", "Spawn a creature instance. DM only."),
        ("/creature list / view / delete", "Roster, view, or remove creatures."),
        ("/creature wound / heal", "Adjust creature wounds. DM only."),
        ("/creature attack", "Creature attacks a PC/NPC (fixed stat block). DM only."),
    ]),
    ("XP & Advancement", [
        ("/xp grant", "Give XP to a player. DM only."),
        ("/xp balance", "Show available/spent XP and Insight Rank."),
        ("/xp trait / skill / emphasis", "Spend XP on Traits, Skills, or Emphases."),
        ("/xp kata / kiho / spell", "Learn Kata, Kiho, or memorise a Spell."),
        ("/xp advantage", "Buy an Advantage with XP."),
        ("/xp remove_disadvantage", "Buy off a Disadvantage (2x point cost)."),
        ("/xp costs", "Show the RAW cost reference."),
    ]),
    ("Schools & Spells", [
        ("/school list / search / view", "Browse 347 schools and their techniques."),
        ("/school learn", "Record techniques up to your School Rank."),
        ("/spell list / search / view", "Browse 287 spells."),
        ("/spell cast", "Cast a spell: (Ring + School Rank) keep Ring."),
        ("/spell resist", "Spell resistance: Willpower roll vs TN (DM only)."),
    ]),
    ("Equipment & Catalogs", [
        ("/weapon list / view", "Browse the 44 weapons."),
        ("/armor list", "Browse the 7 armor types."),
        ("/advantage list / search / view", "Browse 149 advantages & disadvantages."),
        ("/kata list / search / view", "Browse 43 Kata."),
        ("/kiho list / search / view", "Browse 73 Kiho."),
    ]),
    ("Combat — Stances & Actions", [
        ("/combat stance", "Declare stance (Attack, Full Attack, Defense, Full Defense, Center)."),
        ("/combat action", "Track Simple/Complex action economy per turn."),
        ("/combat init", "Adjust a combatant's initiative (DM only). Ties break by Reflexes."),
        ("/combat hold / delay", "Hold or delay a combatant's action (DM only)."),
        ("/combat surprise", "Toggle surprise round (DM only)."),
        ("/combat mount", "Mount or dismount (adds/removes Mounted condition)."),
        ("/combat full_defense", "Full Defense roll (Complex Action)."),
        ("/dual_wield", "Dual-wielding rules and off-hand penalties."),
    ]),
    ("Mass Battle", [
        ("/battle roll", "Mass Battle engagement roll (Battle/Perception vs TN)."),
        ("/battle damage", "Incidental damage by engagement level."),
    ]),
    ("Character Creation", [
        ("/family list / search", "Browse 47 families and their Trait bonuses."),
        ("/heritage roll / table", "Roll on clan Heritage tables."),
        ("/ancestors", "Ancestor advantage mechanical effects."),
    ]),
    ("Taint & Corruption", [
        ("/taint", "View or modify Shadowlands Taint (rank, mutations, madness)."),
    ]),
    ("Utility", [
        ("/spell_damage", "Roll spell damage dice (DM-approval gate to apply)."),
        ("/craft_extended", "Multi-step extended crafting rolls with quality tiers."),
        ("/encumbrance", "Strength-based carrying capacity check."),
        ("/atn", "Armor TN breakdown (base, armor, stance, guard, conditions)."),
        ("/modifiers", "Terrain, range, and situational combat modifier reference."),
        ("/calledshot", "Called Shot raise costs and body part effects reference."),
        ("/horsemanship", "Horsemanship/Agility check."),
        ("/influence", "Track court influence points (DM)."),
        ("/travel", "Calculate travel time by mode and terrain."),
    ]),
    ("Rooms", [
        ("/room create", "Open a private play room (thread)."),
        ("/room invite / kick", "Add or remove a member."),
        ("/room members / list", "Who's here / all rooms."),
        ("/room close", "Archive the room."),
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
                    title=f"Rokugan Bot — {cat_name}",
                    color=discord.Color.gold(),
                )
                lines = [f"`{cmd}` — {desc}" for cmd, desc in cmds]
                embed.description = "\n".join(lines)
                await interaction.response.send_message(embed=embed, ephemeral=True)
                return
        await interaction.response.send_message("Category not found.", ephemeral=True)
        return

    embed = discord.Embed(
        title="Rokugan Bot — Command Reference",
        description="Use `/help category:` to expand a section. All game math is L5R 4th Edition RAW.",
        color=discord.Color.gold(),
    )
    for cat_name, cmds in _HELP_CATEGORIES:
        summary = ", ".join(f"`{cmd}`" for cmd, _ in cmds[:4])
        if len(cmds) > 4:
            summary += f" *… +{len(cmds) - 4} more*"
        embed.add_field(name=f"{cat_name} ({len(cmds)})", value=summary, inline=False)
    embed.set_footer(text="Tip: /help category:Combat — to see all combat commands.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ===========================================================================
# /npc group — generate and manage NPC characters (s22.4 templates)
# ===========================================================================
npc = app_commands.Group(name="npc", description="Generate and manage NPC characters (GDD s22.4 templates).")


@npc.command(name="generate", description="Generate an NPC samurai from a Clan/Family/School/Rank template. DM only.")
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can generate NPCs.", ephemeral=True)
        return

    school_skills = [s for s in skills.split(",")] if skills else None
    resolved_type = school_type.value if school_type else "Bushi"
    # A catalog school fills in the concrete skills, honor, clan, and type. The
    # Benefit is NOT re-applied here — the s22.4 ring bands already reflect it.
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
    note = f"🎭 Generated **{name}** — a Rank {insight_rank} {char.school_type} NPC (stats have random variance)."
    if not school_skills:
        note += " No skills set — regenerate with `skills:` to give it school skills."
    await interaction.response.send_message(content=note, embed=build_sheet_embed(rec))


@npc.command(name="view", description="View a stored NPC.")
@app_commands.describe(name="The NPC to view.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_view(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    await interaction.response.send_message(embed=build_sheet_embed(rec))


@npc.command(name="list", description="List the NPCs on this server.")
async def npc_list(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    recs = store.list_by_owner(str(interaction.guild_id), NPC_OWNER)
    if not recs:
        await interaction.response.send_message(
            "No NPCs yet. Create one with `/npc generate` (DM).", ephemeral=True
        )
        return
    lines = [
        f"• **{r.character.name}** — {r.character.clan or '—'} {r.character.school_type} "
        f"(Rank {r.character.school_rank})"
        for r in recs
    ]
    await interaction.response.send_message("🎭 **NPCs on this server:**\n" + "\n".join(lines[:50]))


@npc.command(name="delete", description="Delete a stored NPC. DM only.")
@app_commands.describe(name="The NPC to delete.")
@app_commands.autocomplete(name=_npc_autocomplete)
async def npc_delete(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can delete NPCs.", ephemeral=True)
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
        return None, "Only a DM can edit NPCs."
    rec = store.get_by_name(str(interaction.guild_id), NPC_OWNER, name)
    if rec is None:
        return None, f"No NPC named **{name}**."
    return rec, None


@npc.command(name="trait", description="Set a Trait (or Void) on an NPC. DM only.")
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


@npc.command(name="skill", description="Set a skill rank on an NPC (0 removes it). DM only.")
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


@npc.command(name="set", description="Set a numeric field on an NPC (honor, armor, void points, etc.). DM only.")
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


@npc.command(name="wound", description="Apply wounds to an NPC. DM only.")
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


@npc.command(name="heal", description="Heal wounds on an NPC. DM only.")
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


@npc.command(name="rename", description="Rename an NPC. DM only.")
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


# ===========================================================================
# /room group — private-thread play rooms with invites
# ===========================================================================
room = app_commands.Group(name="room", description="Create private play rooms and invite people.")


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


@room.command(name="create", description="Create a private play room (a thread) and become its host.")
@app_commands.describe(name="Room name.")
async def room_create(interaction: discord.Interaction, name: app_commands.Range[str, 1, 90]) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
        str(interaction.guild_id), str(interaction.channel_id), str(thread.id), name, str(interaction.user.id)
    )
    await interaction.response.send_message(
        f"🏮 Room **{name}** created: {thread.mention} (host {interaction.user.mention}). "
        f"Invite people with `/room invite` inside the room."
    )
    await thread.send(
        f"🏮 Welcome to **{name}**. {interaction.user.mention} is the host. "
        f"Play happens here — `/sheet`, `/roll`, `/attack`, and `/combat` all work inside this room."
    )


@room.command(name="invite", description="Invite a member into this room (run inside the room's thread).")
@app_commands.describe(member="Who to invite.")
async def room_invite(interaction: discord.Interaction, member: discord.Member) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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


@room.command(name="kick", description="Remove a member from this room (run inside the room's thread).")
@app_commands.describe(member="Who to remove.")
async def room_kick(interaction: discord.Interaction, member: discord.Member) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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


@room.command(name="members", description="List who's in this room (run inside the room's thread).")
async def room_members(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_current_room(interaction)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    ids = store.list_room_members(rec.id)
    mentions = ", ".join(f"<@{uid}>" for uid in ids) if ids else "—"
    await interaction.response.send_message(
        f"🏮 **{rec.name}** — host <@{rec.host_id}>\nMembers: {mentions}", ephemeral=True
    )


@room.command(name="list", description="List the open rooms on this server.")
async def room_list(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rooms = store.list_rooms(str(interaction.guild_id))
    if not rooms:
        await interaction.response.send_message(
            "No open rooms. Create one with `/room create`.", ephemeral=True
        )
        return
    lines = [
        f"• <#{r.thread_id}> — **{r.name}** (host <@{r.host_id}>, "
        f"{len(store.list_room_members(r.id))} members)"
        for r in rooms
    ]
    await interaction.response.send_message("🏮 **Open rooms:**\n" + "\n".join(lines[:40]), ephemeral=True)


@room.command(name="close", description="Close this room (archives the thread). Host or DM only.")
async def room_close(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
    store.close_room(rec.id)
    await interaction.response.send_message(f"🏮 Room **{rec.name}** closed. Archiving the thread.")
    try:
        await interaction.channel.edit(archived=True, locked=True)
    except discord.Forbidden:
        pass


@combat_group.command(name="creature", description="Add a spawned creature to initiative (rolls its initiative). DM only.")
@app_commands.describe(name="The creature to add.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def combat_creature(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can add creatures to initiative.", ephemeral=True)
        return
    rec = store.get_creature_by_name(str(interaction.guild_id), name)
    if rec is None:
        await interaction.response.send_message(f"No creature named **{name}**.", ephemeral=True)
        return
    result = creature.roll_creature_initiative(rec.creature, engine)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(rec.creature.name)
    enc.add(encounter.Combatant(
        name=rec.creature.name,
        initiative=result.total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}",
        owner_id=None,
        is_npc=True,
        reflexes=rec.creature.air,
    ))
    await interaction.response.send_message(_render_encounter(enc))


# ===========================================================================
# /creature group — bestiary monsters and creature combat
# ===========================================================================
creature_group = app_commands.Group(name="creature", description="Spawn and run bestiary creatures.")


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
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
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
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can resolve this.", ephemeral=True)
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

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Damage", style=discord.ButtonStyle.danger, emoji="📜")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return
        await self._resolve(interaction, void_reduce=False)

    @discord.ui.button(label="Void Reduce (−10)", style=discord.ButtonStyle.primary, emoji="🔮")
    async def void_reduce(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return
        await self._resolve(interaction, void_reduce=True)

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can resolve this.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} denied — "
            f"no spell damage applied to **{self.target_name}**."
        )

    async def _resolve(self, interaction: discord.Interaction, void_reduce: bool) -> None:
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        applied = combat.apply_damage(rec.character, self.raw_damage, rec.character.armor_reduction)
        void_line = ""
        if void_reduce and rec.character.current_void_points > 0:
            void_saved = min(10, applied["final_damage"])
            rec.character.wounds_taken = max(0, rec.character.wounds_taken - void_saved)
            rec.character.current_void_points -= 1
            applied["final_damage"] -= void_saved
            applied["new_wound_level"] = stats.wound_level_name(rec.character)
            applied["is_dead"] = stats.is_dead(rec.character)
            applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
            void_line = f"\n🔮 Void Point: **−{void_saved}** wounds ({rec.character.current_void_points} VP left)"
        elif void_reduce:
            void_line = "\n🔮 No Void Points available — full damage applied"
        store.save(rec)
        c = rec.character
        embed = discord.Embed(
            title=f"📜 {self.reason or 'Spell Damage'} — applied",
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

    def __init__(self, target_id: int, target_name: str, amount: int, reason: str) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.amount = amount
        self.reason = reason
        self.void_reduced = False

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Damage", style=discord.ButtonStyle.danger, emoji="💥")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
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
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return
        if self.void_reduced:
            await interaction.response.send_message("Already Void-reduced once.", ephemeral=True)
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        c = rec.character
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
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can resolve this.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} denied — "
            f"no damage applied to **{self.target_name}**."
        )


class DmHealView(discord.ui.View):
    """DM-approval gate for /dm heal: shows pending healing and lets a DM
    confirm or deny before modifying the target's wound track."""

    def __init__(self, target_id: int, target_name: str, amount: int, reason: str) -> None:
        super().__init__(timeout=1800)
        self.target_id = target_id
        self.target_name = target_name
        self.amount = amount
        self.reason = reason

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Healing", style=discord.ButtonStyle.success, emoji="💚")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return
        rec = store.get_by_id(self.target_id)
        if rec is None:
            await interaction.response.send_message("Target no longer exists.", ephemeral=True)
            return
        c = rec.character
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
        await interaction.followup.send(embed=embed)
        reason_tag = f" ({self.reason})" if self.reason else ""
        await _combat_log(
            str(interaction.guild_id),
            f"Heal: {self.target_name}{reason_tag} {healed} wounds healed [{new_level}]",
        )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="❌")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can resolve this.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"❌ {interaction.user.display_name} denied — "
            f"no healing applied to **{self.target_name}**."
        )


def _resolve_creature(
    interaction: discord.Interaction, name: str, require_dm: bool = True
) -> tuple[storage.CreatureRecord | None, str | None]:
    if not _guild_ok(interaction):
        return None, "Please use this in a server channel."
    if require_dm and not _is_dm(interaction):
        return None, "Only a DM can do that with creatures."
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
        f"• `{tid}` — **{t.name}** (atk {t.attack_rolled}k{t.attack_kept}, dmg "
        f"{t.damage_rolled}k{t.damage_kept}, TN {t.armor_tn}, red {t.reduction}, dead {t.wounds_dead})"
        for tid, t in matches[:40]
    ]
    extra = f"\n…and {len(matches) - 40} more — narrow your search." if len(matches) > 40 else ""
    await interaction.response.send_message(
        f"👹 **{len(matches)} match(es) for `{search}`:**\n" + "\n".join(lines) + extra, ephemeral=True
    )


@creature_group.command(name="spawn", description="Spawn a creature instance from a template. DM only.")
@app_commands.describe(template="Which creature template.", name="Instance name (default: the template's name).")
@app_commands.autocomplete(template=_creature_template_autocomplete)
async def creature_spawn(interaction: discord.Interaction, template: str, name: str | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can spawn creatures.", ephemeral=True)
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    recs = store.list_creatures(str(interaction.guild_id))
    if not recs:
        await interaction.response.send_message(
            "No creatures spawned. Use `/creature spawn` (DM).", ephemeral=True
        )
        return
    lines = [
        f"• **{r.creature.name}** — {creature.creature_wound_level(r.creature)} "
        f"({r.creature.wounds_taken}/{r.creature.wounds_dead})"
        for r in recs
    ]
    await interaction.response.send_message("👹 **Creatures:**\n" + "\n".join(lines[:50]))


@creature_group.command(name="view", description="View a spawned creature.")
@app_commands.describe(name="The creature to view.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_view(interaction: discord.Interaction, name: str) -> None:
    rec, err = _resolve_creature(interaction, name, require_dm=False)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    await interaction.response.send_message(embed=build_creature_embed(rec))


@creature_group.command(name="delete", description="Remove a spawned creature. DM only.")
@app_commands.describe(name="The creature to remove.")
@app_commands.autocomplete(name=_creature_instance_autocomplete)
async def creature_delete(interaction: discord.Interaction, name: str) -> None:
    rec, err = _resolve_creature(interaction, name)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    store.delete_creature(rec.id)
    await interaction.response.send_message(f"Removed creature **{rec.creature.name}**.", ephemeral=True)


@creature_group.command(name="wound", description="Apply wounds to a creature directly (no reduction). DM only.")
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


@creature_group.command(name="heal", description="Heal a creature's wounds. DM only.")
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


@creature_group.command(name="attack", description="A creature attacks a player/NPC (fixed stat block). DM only.")
@app_commands.describe(
    creature_name="The attacking creature.",
    target="The player to attack (their active character).",
    target_npc="Attack a stored NPC instead of a player.",
    raises="Called Raises — each adds +5 to the target's Armor TN.",
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can attack with a creature.", ephemeral=True)
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
    tn = combat.armor_tn(target_rec.character, "attack", bonus_tn)
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
        value=f"Total **{outcome['total']}** vs Armor TN **{outcome['tn']}** — {verdict} "
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
# /xp group — Experience: DMs grant, players spend to advance (L5R 4e RAW)
# ===========================================================================
xp = app_commands.Group(name="xp", description="Grant and spend Experience to advance characters (L5R 4e RAW).")


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


@xp.command(name="grant", description="Grant (or correct) a player's Experience. DM only.")
@app_commands.describe(member="The player to grant XP to.", amount="XP amount (negative to correct).", reason="Optional note.")
async def xp_grant(interaction: discord.Interaction, member: discord.Member, amount: app_commands.Range[float, -100000.0, 100000.0], reason: str | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can grant XP.", ephemeral=True)
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


@xp.command(name="balance", description="Show a character's available Experience.")
@app_commands.describe(member="Whose XP to show (DM only). Omit for your own.")
async def xp_balance(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can view another player's XP.", ephemeral=True)
            return
        rec = store.get_active(guild, str(member.id))
    else:
        rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("No active character. Use `/sheet create` first.", ephemeral=True)
        return
    c = rec.character
    await interaction.response.send_message(
        f"**{c.name}** - XP available **{c.xp:g}**, spent {c.xp_spent:g}. "
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}).", ephemeral=True)


@xp.command(name="trait", description="Spend XP to raise a Trait or Void (RAW: Trait N x4, Void N x6).")
@app_commands.describe(trait="Which Trait (or Void) to raise.", member="Advance another player's character (DM only).")
@app_commands.choices(trait=_TRAIT_CHOICES)
async def xp_trait(interaction: discord.Interaction, trait: app_commands.Choice[str], member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
    store.save(rec)
    await interaction.response.send_message(
        f"\U0001F300 **{c.name}** raises **{label}** to rank **{new_rank}** for **{cost}** XP.\n"
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) - XP left {c.xp:g}", embed=build_sheet_embed(rec))


@xp.command(name="skill", description="Spend XP to raise or learn a Skill (RAW: new rank x1).")
@app_commands.describe(skill="Skill name.", member="Advance another player's character (DM only).")
async def xp_skill(interaction: discord.Interaction, skill: app_commands.Range[str, 1, 40], member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
    store.save(rec)
    await interaction.response.send_message(
        f"\U0001F4D8 **{c.name}** raises **{skill_name}** to rank **{new_rank}** for **{cost}** XP.\n"
        f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) - XP left {c.xp:g}", embed=build_sheet_embed(rec))


@xp.command(name="emphasis", description="Spend 2 XP to add a Skill Emphasis (max ceil(rank/2) per skill).")
@app_commands.describe(skill="The skill to add an Emphasis to.", emphasis="The Emphasis (e.g. Katana).", member="Advance another player's character (DM only).")
async def xp_emphasis(interaction: discord.Interaction, skill: app_commands.Range[str, 1, 40], emphasis: app_commands.Range[str, 1, 40], member: discord.Member | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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


@xp.command(name="kata", description="Learn a Kata (cost = 1 x Mastery Level).")
@app_commands.describe(
    name="Kata name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the kata is in the catalog).",
    member="Advance another player's character (DM only).",
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
            f"**{name}** isn't in the catalog — give its `mastery_level:` too.", ephemeral=True
        )
        return
    canonical = rec["name"] if rec else name.strip()
    await _buy_named(interaction, member, canonical, ml, "katas", "kata", "\U0001F94B")


@xp.command(name="kiho", description="Learn a Kiho (cost = 1 x Mastery Level; non-Brotherhood pay 1.5x, ceil).")
@app_commands.describe(
    name="Kiho name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the kiho is in the catalog).",
    non_brotherhood="Set True if the buyer is not a Brotherhood monk (1.5x cost, per s38a).",
    member="Advance another player's character (DM only).",
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
            f"**{name}** isn't in the catalog — give its `mastery_level:` too.", ephemeral=True
        )
        return
    canonical = rec["name"] if rec else name.strip()
    cost = advancement.kiho_cost(ml, non_brotherhood)
    note = " *(non-Brotherhood monk: 1.5x cost, per s38a.)*" if non_brotherhood else ""
    await _buy_named(interaction, member, canonical, ml, "kiho", "kiho", "✋", note=note, cost=cost)


@xp.command(name="spell", description="Memorise a spell so no scroll is needed (cost = 1 x Mastery Level).")
@app_commands.describe(
    name="Spell name (catalog match auto-fills the Mastery Level).",
    mastery_level="Its Mastery Level (optional if the spell is in the catalog).",
    member="Advance another player's character (DM only).",
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
            f"**{name}** isn't in the catalog — give its `mastery_level:` too.", ephemeral=True
        )
        return
    canonical = spell["name"] if spell else name.strip()
    await _buy_named(interaction, member, canonical, ml, "spells_known", "spell", "\U0001F4DC")


@xp.command(name="advantage", description="Buy an Advantage with XP (cost = its point value).")
@app_commands.describe(
    name="Advantage name.",
    points="Point cost — required only for 'Variable'-cost advantages.",
    member="Advance another player's character (DM only).",
)
@app_commands.autocomplete(name=_advantage_autocomplete)
async def xp_advantage(
    interaction: discord.Interaction,
    name: str,
    points: app_commands.Range[int, 1, 20] | None = None,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    adv = advantages.get(name, "advantage")
    if adv is None:
        await interaction.response.send_message(
            f"No advantage named **{name}** — see `/advantage search`.", ephemeral=True
        )
        return
    cost = points if points is not None else adv["points"]
    if cost is None:
        await interaction.response.send_message(
            f"**{adv['name']}** has a Variable cost ({adv['cost_text']}) — pass `points:` to set it.",
            ephemeral=True,
        )
        return
    c = rec.character
    if adv["name"].lower() in [x.lower() for x in c.advantages]:
        await interaction.response.send_message(f"**{c.name}** already has **{adv['name']}**.", ephemeral=True)
        return
    if c.xp < cost:
        await interaction.response.send_message(
            f"Not enough XP: **{adv['name']}** costs **{cost}**, but **{c.name}** has {c.xp:g}.", ephemeral=True
        )
        return
    c.advantages.append(adv["name"])
    c.xp -= cost
    c.xp_spent += cost
    store.save(rec)
    await interaction.response.send_message(
        f"🌸 **{c.name}** gains the advantage **{adv['name']}** for **{cost}** XP. XP left {c.xp:g}",
        embed=build_sheet_embed(rec),
    )


@xp.command(name="remove_disadvantage", description="Buy off a Disadvantage with XP (cost = 2x its point value).")
@app_commands.describe(
    name="Disadvantage name (must be on the character's sheet).",
    points="Point value of the disadvantage (required if not in catalog or Variable cost).",
    member="Target another player's character (DM only).",
)
@app_commands.autocomplete(name=_disadvantage_autocomplete)
async def xp_remove_disadvantage(
    interaction: discord.Interaction,
    name: str,
    points: app_commands.Range[int, 1, 20] | None = None,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    matched = [d for d in c.disadvantages if d.lower() == name.lower().strip()]
    if not matched:
        adv = advantages.get(name, "disadvantage")
        canonical = adv["name"] if adv else name.strip()
        matched = [d for d in c.disadvantages if d.lower() == canonical.lower()]
    if not matched:
        await interaction.response.send_message(
            f"**{c.name}** doesn't have the disadvantage **{name}**.", ephemeral=True
        )
        return
    canonical = matched[0]
    adv = advantages.get(canonical, "disadvantage")
    base_cost = points if points is not None else (adv["points"] if adv else None)
    if base_cost is None:
        await interaction.response.send_message(
            f"**{canonical}** has a Variable cost — pass `points:` to set its base value.", ephemeral=True
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


@xp.command(name="costs", description="Show the Experience cost reference (L5R 4e RAW).")
async def xp_costs(interaction: discord.Interaction) -> None:
    await interaction.response.send_message(
        "**Experience costs (L5R 4e RAW)**\n" + advancement.cost_table()
        + "\n\nA DM grants XP with `/xp grant`; spend it with `/xp trait`, `/xp skill`, `/xp emphasis`, "
        "`/xp kata`, `/xp kiho`, `/xp spell`. Insight Rank follows automatically. Prerequisites and "
        "learning-a-Technique roleplay are DM-adjudicated.", ephemeral=True)

# ===========================================================================
# /school group — schools & techniques (GDD s29)
# ===========================================================================
school = app_commands.Group(name="school", description="Browse schools and their techniques (GDD s29).")


_SCHOOL_CATEGORY_LABEL = {
    "basic": "school", "advanced": "Advanced School", "alternate": "Alternate Path",
}


def build_school_embed(s: dict) -> discord.Embed:
    kw = f" [{', '.join(s['keywords'])}]" if s["keywords"] else ""
    embed = discord.Embed(title=f"🏯 {s['name']}{kw}", color=discord.Color.dark_teal())
    cat = _SCHOOL_CATEGORY_LABEL.get(s.get("category", "basic"), "school")
    embed.description = f"{s['clan']} {cat}"
    meta = []
    if s["benefit"]:
        meta.append(f"**Benefit:** {s['benefit']}")
    if s["honor"]:
        meta.append(f"**Honor:** {s['honor']}")
    if meta:
        embed.add_field(name="​", value="  ·  ".join(meta), inline=False)
    if s["skills"]:
        embed.add_field(name="Skills", value=s["skills"][:1024], inline=False)
    if s["outfit"]:
        embed.add_field(name="Outfit", value=s["outfit"][:1024], inline=False)
    if s["affinity"]:
        embed.add_field(name="Affinity/Deficiency", value=s["affinity"][:1024], inline=False)
    if s["prereq"]:
        embed.add_field(name="Prerequisites", value=s["prereq"][:1024], inline=False)
    # Techniques (each its own field; effect truncated to stay within limits).
    for t in s["techniques"][:12]:
        rank_label = f"Rank {t['rank']}" if t["rank"] else "Technique"
        title = f"{rank_label} — {t['name']}" if t["name"] else rank_label
        embed.add_field(name=title[:256], value=t["effect"][:1024], inline=False)
    return embed


@school.command(name="list", description="List schools (optionally by clan).")
@app_commands.describe(clan="Filter by clan (Crab, Crane, …). Omit for a summary.")
async def school_list(interaction: discord.Interaction, clan: str | None = None) -> None:
    if clan:
        matches = schools.by_clan(clan)
        if not matches:
            await interaction.response.send_message(
                f"No schools for clan **{clan}**. Clans: {', '.join(schools.clans())}", ephemeral=True
            )
            return
        lines = []
        for cat, label in (("basic", "Basic"), ("advanced", "Advanced"), ("alternate", "Alternate Paths")):
            names = [s["name"] for s in matches if s.get("category", "basic") == cat]
            if names:
                lines.append(f"**{label} ({len(names)}):** " + ", ".join(names))
        text = f"🏯 **{clan} — {len(matches)} schools/paths**\n" + "\n".join(lines)
        await interaction.response.send_message(text[:1990], ephemeral=True)
        return
    from collections import Counter
    counts = Counter(s["clan"] for s in schools.ALL)
    cats = Counter(s.get("category", "basic") for s in schools.ALL)
    summary = " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    await interaction.response.send_message(
        f"🏯 **{len(schools.ALL)} schools & paths** "
        f"({cats['basic']} basic · {cats['advanced']} advanced · {cats['alternate']} alternate). "
        f"Browse with `/school list clan:<clan>`, `/school search`, or `/school view`.\n{summary}",
        ephemeral=True,
    )


@school.command(name="search", description="Search schools by name or clan.")
@app_commands.describe(query="Name or clan fragment.")
async def school_search(interaction: discord.Interaction, query: str) -> None:
    matches = schools.search(query)
    if not matches:
        await interaction.response.send_message(f"No schools match `{query}`.", ephemeral=True)
        return
    _abbr = {"basic": "basic", "advanced": "adv", "alternate": "path"}
    lines = [
        f"• **{s['name']}** ({s['clan']}, {_abbr.get(s.get('category', 'basic'), 'basic')})"
        for s in matches[:40]
    ]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("🏯 " + "\n".join(lines) + extra, ephemeral=True)


@school.command(name="view", description="Show a school's benefit, skills, outfit, and techniques.")
@app_commands.describe(name="The school to view.")
@app_commands.autocomplete(name=_school_autocomplete)
async def school_view(interaction: discord.Interaction, name: str) -> None:
    s = schools.get(name)
    if s is None:
        await interaction.response.send_message(
            f"No school named **{name}**. Try `/school search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_school_embed(s))


@school.command(name="learn", description="Record the techniques your school grants up to your School Rank.")
@app_commands.describe(
    school_name="School to learn from (defaults to your sheet's school).",
    member="Do this for another player (DM only).",
)
@app_commands.autocomplete(school_name=_school_autocomplete)
async def school_learn(
    interaction: discord.Interaction,
    school_name: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
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
            f"(or `/sheet set` isn't for this — pick from `/school search`).",
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
        label = f"{s['name']} — {t['name']}"
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
# /spell group — spells & elements (GDD s32–s37)
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
        line.append(f"**Range:** {s['range']}")
    if s["area"]:
        line.append(f"**Area:** {s['area']}")
    if s["duration"]:
        line.append(f"**Duration:** {s['duration']}")
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
    lines = [f"**ML {ml}:** " + ", ".join(sorted(by_ml[ml])) for ml in sorted(by_ml)]
    text = f"🔮 **{element} spells ({len(matches)}):**\n" + "\n".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@spell_group.command(name="search", description="Search spells by name, element, or keyword.")
@app_commands.describe(query="Name, element, or keyword fragment.")
async def spell_search(interaction: discord.Interaction, query: str) -> None:
    matches = spells.search(query)
    if not matches:
        await interaction.response.send_message(f"No spells match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{s['name']}** ({s['element']} {s['mastery']})" for s in matches[:40]]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("🔮 " + "\n".join(lines) + extra, ephemeral=True)


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
    attacker_npc="Cast as a stored NPC (DM only).",
    member="Cast as another player's character (DM only).",
)
@app_commands.autocomplete(name=_spell_autocomplete)
async def spell_cast(
    interaction: discord.Interaction,
    name: str,
    raises: int = 0,
    spend_void: bool = False,
    attacker_npc: str | None = None,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    s = spells.get(name)
    if s is None:
        await interaction.response.send_message(f"No spell named **{name}**. Try `/spell search`.", ephemeral=True)
        return
    # Resolve caster.
    if attacker_npc:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can cast as an NPC.", ephemeral=True)
            return
        rec = store.get_by_name(guild, NPC_OWNER, attacker_npc)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{attacker_npc}**.", ephemeral=True)
            return
    elif member is not None and member.id != interaction.user.id:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can cast for another player.", ephemeral=True)
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
    # Spell slot check: if slots are tracked, enforce the limit.
    slot_remaining = caster.spell_slots.get(element)
    if slot_remaining is not None and slot_remaining <= 0:
        slot_max = stats.spell_slot_max(caster, element)
        await interaction.response.send_message(
            f"**{caster.name}** has no **{element.title()}** spell slots remaining "
            f"(0/{slot_max}). A DM must call `/dm new_day` to refresh slots.",
            ephemeral=True,
        )
        return
    extra_rolled = 1 if spend_void else 0
    extra_kept = 1 if spend_void else 0
    wound_pen = stats.wound_penalty(caster)
    if spend_void:
        if caster.current_void_points <= 0:
            await interaction.response.send_message("No Void Points remaining.", ephemeral=True)
            return
        caster.current_void_points -= 1
        store.save(rec)
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
    if element in caster.spell_slots:
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
    if element in caster.spell_slots:
        slot_max = stats.spell_slot_max(caster, element)
        notes.append(f"{element.title()} slots: {caster.spell_slots[element]}/{slot_max}")
    roll_desc = (
        f"**{s['element']}** Ring {ring_val} + School Rank {result['effective_rank']}"
        f" → {result['rolled']}k{result['kept']}\n"
        f"Roll **{result['total']}** vs TN **{result['tn']}**"
        f" — {'**SUCCESS**' if success else '**FAILED** (slot consumed)'}"
    )
    embed.add_field(name="Spell Casting Roll", value=roll_desc, inline=False)
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


@spell_group.command(name="resist", description="Target resists a spell: Willpower roll vs TN. DM only.")
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Please use this in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for spell resistance.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _find_any_character(guild, target)
    if rec is None:
        await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
        return
    c = rec.character
    willpower = c.willpower
    extra_rolled = 1 if spend_void else 0
    extra_kept = 1 if spend_void else 0
    if spend_void:
        if c.current_void_points <= 0:
            await interaction.response.send_message(
                f"**{c.name}** has no Void Points remaining.", ephemeral=True
            )
            return
        c.current_void_points -= 1
        store.save(rec)
    rolled = willpower + extra_rolled
    kept = willpower + extra_kept
    result = engine.roll_and_keep(max(1, rolled), max(1, kept), False)
    wound_pen = stats.wound_penalty(c)
    total = result.total + wound_pen
    success = total >= tn
    embed = discord.Embed(
        title=f"🛡️ {c.name} — Spell Resistance",
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
        f" — {'**RESISTED** (spell has no effect)' if success else '**FAILED** (spell takes effect)'}"
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


# ===========================================================================
# /weapon and /armor groups — equipment reference (individual_combat.gd / armor_system.gd)
# ===========================================================================
weapon_group = app_commands.Group(name="weapon", description="Browse the weapon catalog (damage, skill, size).")


@weapon_group.command(name="list", description="List all weapons, grouped by skill.")
async def weapon_list(interaction: discord.Interaction) -> None:
    by_skill: dict[str, list[str]] = {}
    for wid, w in combat.WEAPON_CATALOG.items():
        by_skill.setdefault(w["skill"], []).append(f"{wid} {w['rolled']}k{w['kept']}")
    lines = [f"**{sk}:** " + ", ".join(sorted(v)) for sk, v in sorted(by_skill.items())]
    await interaction.response.send_message(
        f"⚔️ **{len(combat.WEAPON_CATALOG)} weapons** (name DR):\n" + "\n".join(lines), ephemeral=True
    )


@weapon_group.command(name="view", description="Show a weapon's details.")
@app_commands.describe(name="Weapon name.")
@app_commands.autocomplete(name=_weapon_autocomplete)
async def weapon_view(interaction: discord.Interaction, name: str) -> None:
    w = combat.WEAPON_CATALOG.get(name.lower().strip())
    if w is None:
        await interaction.response.send_message(f"No weapon named **{name}**. See `/weapon list`.", ephemeral=True)
        return
    dr = f"{w['rolled']}k{w['kept']}" + (" + Strength" if w.get("strength_adds") and w.get("melee") else "")
    embed = discord.Embed(title=f"⚔️ {name.lower().strip()}", color=discord.Color.dark_grey())
    embed.add_field(name="Damage (DR)", value=dr, inline=True)
    embed.add_field(name="Skill", value=w["skill"], inline=True)
    embed.add_field(name="Trait", value=w["trait"].capitalize(), inline=True)
    embed.add_field(name="Size", value=w["size"], inline=True)
    embed.add_field(name="Type", value="Melee" if w.get("melee") else "Ranged", inline=True)
    if w.get("no_explode"):
        embed.set_footer(text="Damage dice do not explode.")
    await interaction.response.send_message(embed=embed)


armor_group = app_commands.Group(name="armor", description="Browse the armor catalog (TN bonus, Reduction).")


@armor_group.command(name="list", description="List all armor types.")
async def armor_list(interaction: discord.Interaction) -> None:
    lines = [
        f"• **{a}** — Armor TN +{s['tn_bonus']}, Reduction {s['reduction']}"
        + (" · heavy" if s["is_heavy"] else "")
        for a, s in combat.ARMOR_CATALOG.items()
    ]
    await interaction.response.send_message(
        "🛡️ **Armor** (equip with `/sheet armor`):\n" + "\n".join(lines), ephemeral=True
    )


# ===========================================================================
# /advantage group — Advantages & Disadvantages (GDD s45)
# ===========================================================================
advantage_group = app_commands.Group(name="advantage", description="Browse Advantages & Disadvantages (GDD s45).")


def build_advantage_embed(r: dict) -> discord.Embed:
    is_adv = r["kind"] == "advantage"
    embed = discord.Embed(
        title=f"{'🌸' if is_adv else '💢'} {r['name']}",
        color=discord.Color.green() if is_adv else discord.Color.dark_red(),
    )
    meta = [r["kind"].capitalize()]
    if r["category"]:
        meta.append(r["category"])
    meta.append(f"{r['cost_text']}" + (" pts" if r["points"] is not None else ""))
    if r["tags"]:
        meta.append(", ".join(r["tags"]))
    embed.description = " · ".join(meta)
    if r["effect"]:
        embed.add_field(name="Effect", value=r["effect"][:1024], inline=False)
    return embed


@advantage_group.command(name="list", description="List Advantages or Disadvantages.")
@app_commands.describe(kind="advantages or disadvantages (default a summary).")
@app_commands.choices(kind=[
    app_commands.Choice(name="advantages", value="advantage"),
    app_commands.Choice(name="disadvantages", value="disadvantage"),
])
async def advantage_list(interaction: discord.Interaction, kind: app_commands.Choice[str] | None = None) -> None:
    if kind is None:
        n_adv = len(advantages.by_kind("advantage"))
        n_dis = len(advantages.by_kind("disadvantage"))
        await interaction.response.send_message(
            f"🌸 **{n_adv} Advantages**, 💢 **{n_dis} Disadvantages**. "
            f"Use `/advantage list kind:` or `/advantage search`, `/advantage view`.",
            ephemeral=True,
        )
        return
    pool = sorted(advantages.by_kind(kind.value), key=lambda r: r["name"])
    lines = [f"**{r['name']}** ({r['cost_text']})" for r in pool]
    text = f"{'🌸' if kind.value == 'advantage' else '💢'} **{kind.name} ({len(pool)}):** " + " · ".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@advantage_group.command(name="search", description="Search Advantages & Disadvantages by name or category.")
@app_commands.describe(query="Name or category fragment.")
async def advantage_search(interaction: discord.Interaction, query: str) -> None:
    matches = advantages.search(query)
    if not matches:
        await interaction.response.send_message(f"No entries match `{query}`.", ephemeral=True)
        return
    lines = [
        f"{'🌸' if r['kind'] == 'advantage' else '💢'} **{r['name']}** ({r['cost_text']})"
        for r in matches[:40]
    ]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("\n".join(lines) + extra, ephemeral=True)


@advantage_group.command(name="view", description="Show an Advantage or Disadvantage in full.")
@app_commands.describe(name="The entry to view.")
@app_commands.autocomplete(name=_anyadv_autocomplete)
async def advantage_view(interaction: discord.Interaction, name: str) -> None:
    r = advantages.get(name)
    if r is None:
        await interaction.response.send_message(f"No entry named **{name}**. Try `/advantage search`.", ephemeral=True)
        return
    await interaction.response.send_message(embed=build_advantage_embed(r))


# ===========================================================================
# /kata and /kiho groups — Kata (GDD s30) and Kiho (GDD s38) reference
# ===========================================================================
kata_group = app_commands.Group(name="kata", description="Browse Kata by element and mastery (GDD s30).")


def build_kata_embed(k: dict) -> discord.Embed:
    color = _ELEMENT_COLORS.get(k["element"].lower(), discord.Color.teal())
    embed = discord.Embed(title=f"\U0001F94B {k['name']}", color=color)
    embed.description = f"**{k['element']} {k['mastery']}**"
    if k.get("schools"):
        embed.add_field(name="Schools", value=k["schools"][:1024], inline=False)
    if k.get("effect"):
        embed.add_field(name="Effect", value=k["effect"][:1024], inline=False)
    return embed


@kata_group.command(name="list", description="List Kata by element (or a summary).")
@app_commands.describe(element="Air, Earth, Fire, Water, Void. Omit for a summary.")
async def kata_list(interaction: discord.Interaction, element: str | None = None) -> None:
    if not element:
        from collections import Counter
        counts = Counter(k["element"] for k in kata.ALL)
        summary = " · ".join(f"{el} {n}" for el, n in sorted(counts.items()))
        await interaction.response.send_message(
            f"\U0001F94B **{len(kata.ALL)} Kata.** Browse with `/kata list element:<element>`, "
            f"`/kata search`, `/kata view`.\n{summary}", ephemeral=True
        )
        return
    matches = kata.by_element(element)
    if not matches:
        await interaction.response.send_message(
            f"No Kata for **{element}**. Elements: {', '.join(kata.elements())}", ephemeral=True
        )
        return
    by_ml: dict[int, list[str]] = {}
    for k in matches:
        by_ml.setdefault(k["mastery"], []).append(k["name"])
    lines = [f"**ML {ml}:** " + ", ".join(sorted(by_ml[ml])) for ml in sorted(by_ml)]
    text = f"\U0001F94B **{element} Kata ({len(matches)}):**\n" + "\n".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@kata_group.command(name="search", description="Search Kata by name or element.")
@app_commands.describe(query="Name or element fragment.")
async def kata_search(interaction: discord.Interaction, query: str) -> None:
    matches = kata.search(query)
    if not matches:
        await interaction.response.send_message(f"No Kata match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{k['name']}** ({k['element']} {k['mastery']})" for k in matches[:40]]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("\U0001F94B " + "\n".join(lines) + extra, ephemeral=True)


@kata_group.command(name="view", description="Show a Kata's element, mastery, schools, and effect.")
@app_commands.describe(name="The Kata to view.")
@app_commands.autocomplete(name=_kata_autocomplete)
async def kata_view(interaction: discord.Interaction, name: str) -> None:
    k = kata.get(name)
    if k is None:
        await interaction.response.send_message(
            f"No Kata named **{name}**. Try `/kata search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_kata_embed(k))


kiho_group = app_commands.Group(name="kiho", description="Browse Kiho by element and mastery (GDD s38).")


def build_kiho_embed(k: dict) -> discord.Embed:
    color = _ELEMENT_COLORS.get(k["element"].lower(), discord.Color.teal())
    atemi = " · Atemi" if k.get("atemi") else ""
    embed = discord.Embed(title=f"✋ {k['name']}{atemi}", color=color)
    meta = f"**{k['element']} {k['mastery']}**"
    if k.get("type"):
        meta += f" · {k['type']}"
    embed.description = meta
    if k.get("effect"):
        embed.add_field(name="Effect", value=k["effect"][:1024], inline=False)
    return embed


@kiho_group.command(name="list", description="List Kiho by element (or a summary).")
@app_commands.describe(element="Air, Earth, Fire, Water, Void. Omit for a summary.")
async def kiho_list(interaction: discord.Interaction, element: str | None = None) -> None:
    if not element:
        from collections import Counter
        counts = Counter(k["element"] for k in kiho.ALL)
        summary = " · ".join(f"{el} {n}" for el, n in sorted(counts.items()))
        await interaction.response.send_message(
            f"✋ **{len(kiho.ALL)} Kiho.** Browse with `/kiho list element:<element>`, "
            f"`/kiho search`, `/kiho view`.\n{summary}", ephemeral=True
        )
        return
    matches = kiho.by_element(element)
    if not matches:
        await interaction.response.send_message(
            f"No Kiho for **{element}**. Elements: {', '.join(kiho.elements())}", ephemeral=True
        )
        return
    by_ml: dict[int, list[str]] = {}
    for k in matches:
        by_ml.setdefault(k["mastery"], []).append(k["name"])
    lines = [f"**ML {ml}:** " + ", ".join(sorted(by_ml[ml])) for ml in sorted(by_ml)]
    text = f"✋ **{element} Kiho ({len(matches)}):**\n" + "\n".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@kiho_group.command(name="search", description="Search Kiho by name, element, or type.")
@app_commands.describe(query="Name, element, or type fragment.")
async def kiho_search(interaction: discord.Interaction, query: str) -> None:
    matches = kiho.search(query)
    if not matches:
        await interaction.response.send_message(f"No Kiho match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{k['name']}** ({k['element']} {k['mastery']})" for k in matches[:40]]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("✋ " + "\n".join(lines) + extra, ephemeral=True)


@kiho_group.command(name="view", description="Show a Kiho's element, mastery, type, and effect.")
@app_commands.describe(name="The Kiho to view.")
@app_commands.autocomplete(name=_kiho_autocomplete)
async def kiho_view(interaction: discord.Interaction, name: str) -> None:
    k = kiho.get(name)
    if k is None:
        await interaction.response.send_message(
            f"No Kiho named **{name}**. Try `/kiho search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_kiho_embed(k))


# ---------------------------------------------------------------------------
# Phase 42 — Stance Tracking (#1)
# ---------------------------------------------------------------------------

_STANCE_CHOICES = [
    app_commands.Choice(name="Attack", value="attack"),
    app_commands.Choice(name="Full Attack (+2k1 hit, −10 ATN)", value="full_attack"),
    app_commands.Choice(name="Defense (+Air+Defense to ATN)", value="defense"),
    app_commands.Choice(name="Full Defense (Complex Action)", value="full_defense"),
    app_commands.Choice(name="Center (+Void ATN, +1k1 next turn)", value="center"),
]


@combat_group.command(name="stance", description="Declare your stance for this turn (persists until your next turn).")
@app_commands.describe(
    name="Combatant name.",
    stance="Stance to adopt.",
)
@app_commands.choices(stance=_STANCE_CHOICES)
async def combat_stance(
    interaction: discord.Interaction,
    name: str,
    stance: app_commands.Choice[str],
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if stance.value not in encounter.VALID_STANCES:
        await interaction.response.send_message("Invalid stance.", ephemeral=True)
        return
    cb.stance = stance.value
    label = stance.name
    effects = _stance_effects(stance.value)
    msg = f"**{cb.name}** adopts **{label}** stance."
    if effects:
        msg += f"\n{effects}"
    await interaction.response.send_message(msg)
    await _combat_log(str(interaction.guild_id), f"Stance: {cb.name} → {label}")


@combat_group.command(name="init", description="Adjust a combatant's initiative value (DM only).")
@app_commands.describe(
    name="Combatant name.",
    value="New initiative total.",
)
async def combat_init(
    interaction: discord.Interaction,
    name: str,
    value: app_commands.Range[int, -100, 200],
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can adjust initiative.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    old = cb.initiative
    cb.initiative = value
    enc._sort()
    if enc.started:
        cur = enc.current()
        if cur is not None:
            enc.turn_index = enc.combatants.index(cur)
    await interaction.response.send_message(
        f"**{cb.name}** initiative {old} → **{value}**\n{_render_encounter(enc)}"
    )


@combat_group.command(name="hold", description="Mark a combatant as holding their action (DM only).")
@app_commands.describe(name="Combatant name.")
async def combat_hold(interaction: discord.Interaction, name: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can manage held actions.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    cb.held = not cb.held
    status = "holding" if cb.held else "no longer holding"
    await interaction.response.send_message(f"**{cb.name}** is {status} their action.")


@combat_group.command(name="delay", description="Mark a combatant as delaying (DM only).")
@app_commands.describe(name="Combatant name.", new_initiative="Optional new initiative value.")
async def combat_delay(
    interaction: discord.Interaction,
    name: str,
    new_initiative: app_commands.Range[int, -100, 200] | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can manage delayed actions.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    cb.delayed = not cb.delayed
    if new_initiative is not None and cb.delayed:
        cb.initiative = new_initiative
        enc._sort()
        if enc.started:
            cur = enc.current()
            if cur is not None:
                enc.turn_index = enc.combatants.index(cur)
    status = "delaying" if cb.delayed else "no longer delaying"
    init_note = f" (init → {cb.initiative})" if new_initiative is not None and cb.delayed else ""
    await interaction.response.send_message(f"**{cb.name}** is {status}{init_note}.")


@combat_group.command(name="surprise", description="Toggle the surprise round flag on the current encounter (DM only).")
async def combat_surprise(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can toggle the surprise round.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    enc.surprise_round = not enc.surprise_round
    state = "ON" if enc.surprise_round else "OFF"
    await interaction.response.send_message(f"Surprise round: **{state}**\n{_render_encounter(enc)}")


# ---------------------------------------------------------------------------
# Phase 42 — Heritage Tables (#4)
# ---------------------------------------------------------------------------

heritage_group = app_commands.Group(name="heritage", description="Heritage table rolls (L5R 4e character creation).")


@heritage_group.command(name="roll", description="Roll on a clan's Heritage Table (1d10). DM only.")
@app_commands.describe(clan="Clan name (Crab, Crane, Dragon, Lion, Mantis, Phoenix, Scorpion, Unicorn).")
async def heritage_roll(interaction: discord.Interaction, clan: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can roll heritage.", ephemeral=True)
        return
    result = heritage.roll_heritage(clan)
    embed = discord.Embed(
        title=f"Heritage Roll — {clan}",
        color=discord.Color.dark_teal(),
    )
    embed.add_field(name=f"Roll: {result['roll']} — {result['name']}", value=result["effect"], inline=False)
    await interaction.response.send_message(embed=embed)


@heritage_group.command(name="table", description="Show a clan's full Heritage Table.")
@app_commands.describe(clan="Clan name.")
async def heritage_table(interaction: discord.Interaction, clan: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    table = heritage.get_table(clan)
    lines = [f"**{r['roll']}.** {r['name']} — {r['effect']}" for r in table]
    embed = discord.Embed(title=f"Heritage Table — {clan}", description="\n".join(lines), color=discord.Color.dark_teal())
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 42 — Taint Progression (#14)
# ---------------------------------------------------------------------------

@client.tree.command(name="taint", description="View or modify a character's Shadowlands Taint. DM only.")
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if add is not None and not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can modify Taint.", ephemeral=True)
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
        c.taint = max(0.0, c.taint + add)
        store.save(rec)
        crossing = taint.check_threshold_crossing(old_taint, c.taint, c)
        embed = discord.Embed(title=f"Taint — {c.name}", color=discord.Color.dark_purple())
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
        embed = discord.Embed(title=f"Taint — {c.name}", color=discord.Color.dark_purple())
        embed.add_field(name="Taint", value=f"**{c.taint:g}**", inline=True)
        embed.add_field(name="Taint Rank", value=f"**{rank}**", inline=True)
        embed.add_field(name="Earth Ring", value=str(stats.earth_ring(c)), inline=True)
        embed.add_field(name="Status", value=taint.taint_description(rank), inline=False)
        if taint.social_penalty(c):
            embed.add_field(name="Social Penalty", value=f"TN +{taint.social_penalty(c)}", inline=True)
        await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 42 — Mass Battle (#3)
# ---------------------------------------------------------------------------

battle_group = app_commands.Group(name="battle", description="Mass Battle system (L5R 4e).")


@battle_group.command(name="roll", description="Battle/Perception roll to determine engagement level. DM only.")
@app_commands.describe(
    name="Character name.",
    tn="Battle TN set by DM (10-15 winning, 15-20 even, 20-30 losing, 30+ desperate).",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus (advantages, terrain, etc.).",
)
async def battle_roll(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 5, 100],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: int = 0,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can run mass battle rolls.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    c, _ = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if c is None:
        await interaction.response.send_message(f"Character **{name}** not found.", ephemeral=True)
        return
    battle_skill = c.skills.get("Battle", 0)
    wp = stats.wound_penalty(c)
    result = mass_battle.resolve_battle_roll(c.perception, battle_skill, tn, engine, bonus + wp)
    info = result["engagement_info"]
    embed = discord.Embed(
        title=f"Mass Battle — {c.name}",
        color=discord.Color.red() if result["engagement"] in ("heavily_engaged", "heroic") else discord.Color.orange(),
    )
    embed.add_field(name="Roll", value=f"({result['rolled']}k{result['kept']}) = **{result['total']}** vs TN {tn}", inline=False)
    embed.add_field(name="Engagement", value=f"**{info['name']}**", inline=True)
    embed.add_field(name="Margin", value=f"{result['margin']:+d}", inline=True)
    embed.add_field(name="Description", value=info["description"], inline=False)
    dice_str = _format_dice(result["dice"])
    embed.add_field(name="Dice", value=dice_str, inline=False)
    await interaction.response.send_message(embed=embed)


@battle_group.command(name="damage", description="Roll incidental damage from a mass battle round. DM only.")
@app_commands.describe(engagement="Engagement level from the battle roll.")
@app_commands.choices(engagement=[
    app_commands.Choice(name="Reserves (0 damage)", value="reserves"),
    app_commands.Choice(name="Disengaged (1k1)", value="disengaged"),
    app_commands.Choice(name="Engaged (2k1)", value="engaged"),
    app_commands.Choice(name="Heavily Engaged (3k2)", value="heavily_engaged"),
    app_commands.Choice(name="Heroic (4k3)", value="heroic"),
])
async def battle_damage(
    interaction: discord.Interaction,
    engagement: app_commands.Choice[str],
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can roll battle damage.", ephemeral=True)
        return
    result = mass_battle.resolve_battle_turn_damage(engagement.value, engine)
    if result["damage"] == 0:
        await interaction.response.send_message(f"**{engagement.name}** — no incidental damage this round.")
        return
    embed = discord.Embed(title=f"Mass Battle Damage — {engagement.name}", color=discord.Color.dark_red())
    embed.add_field(name="Damage", value=f"**{result['damage']}** ({result['rolled']}k{result['kept']})", inline=True)
    if result["dice"]:
        embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    embed.set_footer(text="Apply with /sheet wound or /npc wound, subtracting armor Reduction.")
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Phase 42 — Mounted Combat (#10)
# ---------------------------------------------------------------------------

@combat_group.command(name="mount", description="Mount or dismount (sets/clears Mounted condition). DM only.")
@app_commands.describe(
    name="Combatant name.",
    dismount="Dismount instead of mounting.",
)
async def combat_mount(
    interaction: discord.Interaction,
    name: str,
    dismount: bool = False,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can mount/dismount combatants.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if dismount:
        cb.conditions.discard("mounted")
        await interaction.response.send_message(f"**{cb.name}** dismounts.")
    else:
        cb.conditions.add("mounted")
        await interaction.response.send_message(
            f"**{cb.name}** mounts up. Mounted combat: +1k0 damage on melee "
            f"vs unmounted, +1 rolled die on Horsemanship checks. Mounted archery "
            f"at −1k0 unless Mounted Archery emphasis."
        )


@client.tree.command(name="horsemanship", description="Horsemanship/Agility check (mounted combat maneuver). DM only.")
@app_commands.describe(
    name="Character name.",
    tn="Target Number.",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus.",
    reason="Label (e.g. 'charge', 'leap obstacle', 'stay mounted').",
)
async def horsemanship_check(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 1, 200],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: int = 0,
    reason: str = "",
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can call Horsemanship checks.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    c, _ = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if c is None:
        await interaction.response.send_message(f"Character **{name}** not found.", ephemeral=True)
        return
    skill_rank = c.skills.get("Horsemanship", 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(c.agility, skill_rank, tn, engine, bonus + wp)
    embed = _build_check_embed(
        reason or "Horsemanship Check", c.name, "Horsemanship", "Agility", result, wp, bonus,
        success_text="Maneuver succeeds!", fail_text="The rider falters!",
    )
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Phase 42 — Crafting Extended (#6)
# ---------------------------------------------------------------------------

@client.tree.command(name="craft_extended", description="Extended crafting roll — multi-step project with cumulative total. DM only.")
@app_commands.describe(
    name="Character name.",
    skill="Craft/Artisan skill name.",
    tn="Cumulative TN to complete the project.",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus (tools, workshop, etc.).",
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
    reason: str = "",
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can run extended crafting.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    c, _ = _resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if c is None:
        await interaction.response.send_message(f"Character **{name}** not found.", ephemeral=True)
        return
    skill_rank = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    result = combat.resolve_skill_check(c.intelligence, skill_rank, 10, engine, bonus + wp)
    embed = discord.Embed(
        title=reason or f"Extended Crafting — {skill}",
        color=discord.Color.teal(),
    )
    embed.add_field(name="Craftsman", value=c.name, inline=True)
    embed.add_field(name="Roll", value=f"({result['rolled']}k{result['kept']}) = **{result['total']}**", inline=True)
    embed.add_field(name="Progress", value=f"+{result['total']} toward TN **{tn}**", inline=False)
    embed.add_field(name="Dice", value=_format_dice(result["dice"]), inline=False)
    quality_thresholds = [
        (tn * 2, "Exceptional Quality (+1k0 relevant rolls)"),
        (int(tn * 1.5), "Fine Quality (+0k1 relevant rolls)"),
        (tn, "Standard Quality"),
    ]
    quality_lines = [f"TN {t}: {desc}" for t, desc in quality_thresholds]
    embed.add_field(name="Quality Tiers (cumulative total)", value="\n".join(quality_lines), inline=False)
    embed.set_footer(text="DM: track cumulative total across rolls. Each roll = one crafting period.")
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Phase 42 — Encumbrance (#11)
# ---------------------------------------------------------------------------

@client.tree.command(name="encumbrance", description="Check a character's carrying capacity (Strength-based).")
@app_commands.describe(
    member="Player whose character to check.",
    is_npc="Target is an NPC.",
    name="NPC name (if is_npc).",
)
async def encumbrance_check(
    interaction: discord.Interaction,
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if is_npc and name:
        rec = store.get_by_name(guild, NPC_OWNER, name)
    elif member is not None:
        rec = store.get_active(guild, str(member.id))
    else:
        rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("Character not found.", ephemeral=True)
        return
    c = rec.character
    cap = stats.encumbrance_capacity(c)
    water = stats.water_ring(c)
    embed = discord.Embed(title=f"Encumbrance — {c.name}", color=discord.Color.greyple())
    embed.add_field(name="Strength", value=str(c.strength), inline=True)
    embed.add_field(name="Carry Capacity", value=f"**{cap}** items", inline=True)
    embed.add_field(name="Water Ring", value=str(water), inline=True)
    embed.add_field(
        name="Overloaded Penalty",
        value=f"Beyond {cap} items: −{1}k0 to all physical rolls per {c.strength} items over capacity.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


@client.tree.command(name="atn", description="Show Armor TN breakdown for your active character.")
@app_commands.describe(
    target="Character name (DM only — omit to see your own).",
)
async def atn_breakdown(interaction: discord.Interaction, target: str | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if target:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can view another character's ATN.", ephemeral=True)
            return
        rec = _find_any_character(guild, target)
        if rec is None:
            await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
            return
    else:
        rec = store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("No active character.", ephemeral=True)
            return
    c = rec.character
    base = c.reflexes * 5 + 5
    armor_bonus = c.armor_tn_bonus
    armor_name = c.armor_name or "None"
    reduction = c.armor_reduction
    lines = [
        f"Base (Reflexes {c.reflexes} × 5 + 5) = **{base}**",
        f"Armor: {armor_name} (+{armor_bonus} TN, Reduction {reduction})",
    ]
    total = base + armor_bonus
    enc = encounters.get(interaction.channel_id)
    cb = None
    if enc:
        for comb in enc.combatants:
            if comb.name.lower() == c.name.lower():
                cb = comb
                break
    if cb is not None:
        stance_mod = combat.STANCE_ARMOR_TN_BONUS.get(cb.stance, 0)
        if cb.stance == "defense":
            def_bonus = stats.ring_value(c, "air") + c.skills.get("Defense", 0)
            lines.append(f"Defense Stance: +{def_bonus} (Air {stats.ring_value(c, 'air')} + Defense {c.skills.get('Defense', 0)})")
            total += def_bonus
        elif cb.stance == "center":
            void_bonus = c.void_ring
            lines.append(f"Center Stance: +{void_bonus} (Void Ring)")
            total += void_bonus
        elif stance_mod != 0:
            stance_label = cb.stance.replace("_", " ").title()
            lines.append(f"{stance_label} Stance: {stance_mod:+d}")
            total += stance_mod
        if cb.full_defense_bonus:
            lines.append(f"Full Defense bonus: +{cb.full_defense_bonus}")
            total += cb.full_defense_bonus
        if cb.guarding:
            lines.append(f"Guarding {cb.guarding}: −5")
            total -= 5
        for other in enc.combatants:
            if other.guarding.lower() == c.name.lower():
                lines.append(f"Guarded by {other.name}: +10")
                total += 10
                break
        override, override_notes = condition_effects.defender_armor_tn_override(
            cb.conditions, c.reflexes, armor_bonus, True,
        )
        cond_mod, cond_notes = condition_effects.defender_armor_tn_mod(cb.conditions, True)
        if override is not None:
            lines.append(f"Condition override: {override_notes[0]}")
            lines.append(f"**Effective ATN = {override + cond_mod}** (overridden)")
        else:
            if cond_mod:
                lines.append(f"Condition modifier: {cond_mod:+d} ({', '.join(cond_notes)})")
                total += cond_mod
            lines.append(f"**Total ATN = {total}**")
    else:
        lines.append(f"**Total ATN = {total}** (out of combat)")
    embed = discord.Embed(title=f"🛡️ ATN Breakdown — {c.name}", color=discord.Color.blue())
    embed.description = "\n".join(lines)
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 42 — Family catalog (#12)
# ---------------------------------------------------------------------------

family_group = app_commands.Group(name="family", description="Family catalog (L5R 4e character creation bonuses).")


@family_group.command(name="list", description="List families by clan.")
@app_commands.describe(clan="Filter by clan (optional).")
async def family_list(interaction: discord.Interaction, clan: str | None = None) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if clan:
        fams = families.by_clan(clan)
        if not fams:
            await interaction.response.send_message(f"No families found for clan **{clan}**.", ephemeral=True)
            return
        lines = [f"**{f['name']}** — +1 {f['bonus_trait'].capitalize()}" for f in fams]
        embed = discord.Embed(title=f"Families — {clan}", description="\n".join(lines), color=discord.Color.blue())
    else:
        clans: dict[str, list[str]] = {}
        for f in families.ALL:
            clans.setdefault(f["clan"], []).append(f"{f['name']} (+1 {f['bonus_trait'].capitalize()})")
        embed = discord.Embed(title="All Families", color=discord.Color.blue())
        for clan_name in sorted(clans):
            embed.add_field(name=clan_name, value=", ".join(clans[clan_name]), inline=False)
    await interaction.response.send_message(embed=embed, ephemeral=True)


@family_group.command(name="search", description="Search families by name or clan.")
@app_commands.describe(query="Name or clan to search for.")
async def family_search(interaction: discord.Interaction, query: str) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    results = families.search(query)
    if not results:
        await interaction.response.send_message(f"No families matching **{query}**.", ephemeral=True)
        return
    lines = [f"**{f['name']}** ({f['clan']}) — +1 {f['bonus_trait'].capitalize()}" for f in results[:25]]
    embed = discord.Embed(title=f"Family Search — \"{query}\"", description="\n".join(lines), color=discord.Color.blue())
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 42 — Spell Damage (#8 partial)
# ---------------------------------------------------------------------------

@client.tree.command(name="spell_damage", description="Roll spell damage dice (for offensive spells). DM only.")
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can roll spell damage.", ephemeral=True)
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
            view = SpellDamageView(
                target_id=rec.id, target_name=rec.character.name,
                raw_damage=total, dice_text=_format_dice(result),
                reason=reason, rolled=rolled, kept=kept, bonus=bonus,
            )
            await interaction.response.send_message(
                content="A DM can authorize the spell damage below.",
                embed=embed, view=view,
            )
        else:
            embed.set_footer(text=f"Target '{target}' not found — use exact character name.")
            await interaction.response.send_message(embed=embed)
    else:
        embed.set_footer(text="Add target: to route damage through the DM-approval gate.")
        await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Phase 42 — Multiple Attacks / Action Economy (#9)
# ---------------------------------------------------------------------------

@combat_group.command(name="action", description="Track action usage this turn (Simple or Complex). DM only.")
@app_commands.describe(
    name="Combatant name.",
    action_type="Type of action being taken.",
)
@app_commands.choices(action_type=[
    app_commands.Choice(name="Simple Action (1 of 2)", value="simple"),
    app_commands.Choice(name="Complex Action (uses both)", value="complex"),
    app_commands.Choice(name="Free Action (no cost)", value="free"),
    app_commands.Choice(name="Reset (undo)", value="reset"),
])
async def combat_action(
    interaction: discord.Interaction,
    name: str,
    action_type: app_commands.Choice[str],
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can track actions.", ephemeral=True)
        return
    enc = encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter in this channel.", ephemeral=True)
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if action_type.value == "reset":
        cb.actions_used = 0
        await interaction.response.send_message(f"**{cb.name}** — actions reset.")
        return
    if action_type.value == "free":
        await interaction.response.send_message(f"**{cb.name}** takes a Free Action.")
        return
    if action_type.value == "complex":
        if cb.actions_used > 0:
            await interaction.response.send_message(f"**{cb.name}** has already used an action this turn.", ephemeral=True)
            return
        cb.actions_used = 2
        await interaction.response.send_message(f"**{cb.name}** takes a **Complex Action** (turn used).")
    else:
        if cb.actions_used >= 2:
            await interaction.response.send_message(f"**{cb.name}** has no actions remaining this turn.", ephemeral=True)
            return
        cb.actions_used += 1
        remaining = 2 - cb.actions_used
        await interaction.response.send_message(
            f"**{cb.name}** takes a **Simple Action** ({remaining} action{'s' if remaining != 1 else ''} remaining)."
        )


# ---------------------------------------------------------------------------
# Phase 42 — Ancestor Advantages effects reminder (#13)
# ---------------------------------------------------------------------------

ANCESTOR_EFFECTS: dict[str, str] = {
    "ancestor: hida": "+1k0 vs Shadowlands creatures.",
    "ancestor: hiruma": "+1k0 on Hunting and Stealth checks.",
    "ancestor: kaiu": "+1k0 on Engineering and Craft checks.",
    "ancestor: kuni": "+1k0 on Lore: Shadowlands checks.",
    "ancestor: doji": "+1k0 on Etiquette and Courtier checks.",
    "ancestor: kakita": "+1k0 on Iaijutsu checks.",
    "ancestor: daidoji": "+1k0 on Battle checks.",
    "ancestor: mirumoto": "+1k0 on Kenjutsu checks when wielding two weapons.",
    "ancestor: kitsuki": "+1k0 on Investigation checks.",
    "ancestor: togashi": "+1k0 on Meditation checks.",
    "ancestor: akodo": "+1k0 on Battle checks.",
    "ancestor: matsu": "+1k0 on attack rolls when at Hurt or worse.",
    "ancestor: ikoma": "+1k0 on Lore: History checks.",
    "ancestor: bayushi": "+1k0 on Stealth and Sincerity checks.",
    "ancestor: shosuro": "+1k0 on Acting and Disguise checks.",
    "ancestor: soshi": "+1k0 on spell casting rolls for Air spells.",
    "ancestor: shinjo": "+1k0 on Horsemanship checks.",
    "ancestor: moto": "+1k0 on attack rolls while Mounted.",
    "ancestor: ide": "+1k0 on Commerce and Etiquette checks.",
    "ancestor: isawa": "+1k0 on spell casting rolls.",
    "ancestor: shiba": "+1k0 on Defense rolls.",
}


@client.tree.command(name="ancestors", description="Show mechanical effects of Ancestor advantages on a character.")
@app_commands.describe(
    member="Player whose character to check.",
    is_npc="Target is an NPC.",
    name="NPC name (if is_npc).",
)
async def ancestors_check(
    interaction: discord.Interaction,
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if is_npc and name:
        rec = store.get_by_name(guild, NPC_OWNER, name)
    elif member is not None:
        rec = store.get_active(guild, str(member.id))
    else:
        rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("Character not found.", ephemeral=True)
        return
    c = rec.character
    found = []
    for adv in c.advantages:
        key = adv.lower().strip()
        if key in ANCESTOR_EFFECTS:
            found.append(f"**{adv}** — {ANCESTOR_EFFECTS[key]}")
    if not found:
        await interaction.response.send_message(
            f"**{c.name}** has no Ancestor advantages recorded. Use `/sheet advantage` to add one.",
            ephemeral=True,
        )
        return
    embed = discord.Embed(
        title=f"Ancestor Effects — {c.name}",
        description="\n".join(found),
        color=discord.Color.gold(),
    )
    embed.set_footer(text="DM: apply these bonuses manually to relevant rolls.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 42 — Dual Wield reminder (#9 supplement)
# ---------------------------------------------------------------------------

@client.tree.command(name="dual_wield", description="Show dual-wielding rules and penalties for a character.")
@app_commands.describe(
    member="Player whose character to check.",
    name="NPC name.",
    is_npc="Target is an NPC.",
)
async def dual_wield_info(
    interaction: discord.Interaction,
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    if is_npc and name:
        rec = store.get_by_name(guild, NPC_OWNER, name)
    elif member is not None:
        rec = store.get_active(guild, str(member.id))
    else:
        rec = store.get_active(guild, str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("Character not found.", ephemeral=True)
        return
    c = rec.character
    embed = discord.Embed(title=f"Dual Wielding — {c.name}", color=discord.Color.dark_blue())
    if c.equipped_weapon and c.off_hand_weapon:
        main_w = combat.get_weapon_profile(c.equipped_weapon)
        off_w = combat.get_weapon_profile(c.off_hand_weapon)
        embed.add_field(name="Main Hand", value=f"{c.equipped_weapon} ({main_w.get('rolled',2)}k{main_w.get('kept',1)})", inline=True)
        embed.add_field(name="Off Hand", value=f"{c.off_hand_weapon} ({off_w.get('rolled',2)}k{off_w.get('kept',1)})", inline=True)
        off_size = off_w.get("size", "Medium")
        if off_size == "Small":
            penalty = "−5 TN (Small off-hand weapon)"
        elif off_size == "Medium":
            penalty = "−10 TN (Medium off-hand weapon)"
        else:
            penalty = "−15 TN (Large off-hand weapon — not normally allowed)"
        embed.add_field(name="Off-hand Attack Penalty", value=penalty, inline=False)
        embed.add_field(
            name="Rules",
            value=(
                "• Main-hand attack: normal (Simple Action)\n"
                "• Off-hand attack: Simple Action with penalty above\n"
                "• Both attacks in one turn use both Simple Actions\n"
                "• Mirumoto Two-Heavens / Niten Mastery may reduce penalties"
            ),
            inline=False,
        )
    elif c.equipped_weapon:
        embed.description = f"Only wielding **{c.equipped_weapon}** (no off-hand). Use `/sheet wield` to set both weapons."
    else:
        embed.description = "No weapons wielded. Use `/sheet wield` to equip weapons."
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 42 — Courtier/Social Influence (#5)
# ---------------------------------------------------------------------------

@client.tree.command(name="influence", description="Track Influence Points during a court scene. DM only.")
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only DMs can track influence.", ephemeral=True)
        return
    embed = discord.Embed(title="Court Influence", color=discord.Color.purple())
    sign = "+" if change >= 0 else ""
    embed.add_field(name=name, value=f"{sign}{change} Influence" + (f" — {reason}" if reason else ""), inline=False)
    embed.set_footer(text="DM: track cumulative influence totals for the court scene. Use /social for Courtier/Etiquette checks.")
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Phase 42 — Travel (#7)
# ---------------------------------------------------------------------------

TRAVEL_SPEEDS: dict[str, dict] = {
    "foot": {"name": "On Foot", "miles_per_day": 20, "description": "Standard travel pace. Can force-march for 30 (Stamina TN 15 or gain Fatigued)."},
    "horse": {"name": "Mounted", "miles_per_day": 40, "description": "Standard mounted pace. Can push for 60 (Horsemanship TN 15)."},
    "forced_march": {"name": "Forced March", "miles_per_day": 30, "description": "Stamina check TN 15 each day or gain Fatigued condition."},
    "cart": {"name": "Cart/Wagon", "miles_per_day": 15, "description": "Slow but can carry heavy loads."},
    "ship": {"name": "Ship (coastal)", "miles_per_day": 50, "description": "Coastal sailing. Open-sea routes may be faster or slower depending on winds."},
    "river": {"name": "River Barge", "miles_per_day": 25, "description": "Downstream travel. Upstream is half speed."},
}


@client.tree.command(name="travel", description="Calculate travel time between locations.")
@app_commands.describe(
    distance="Distance in miles.",
    mode="Travel mode.",
    terrain="Terrain modifier (halves or quarters speed).",
)
@app_commands.choices(
    mode=[app_commands.Choice(name=v["name"], value=k) for k, v in TRAVEL_SPEEDS.items()],
    terrain=[
        app_commands.Choice(name="Road/Clear (normal)", value="normal"),
        app_commands.Choice(name="Rough/Hills (half)", value="half"),
        app_commands.Choice(name="Mountain/Swamp (quarter)", value="quarter"),
    ],
)
async def travel_calc(
    interaction: discord.Interaction,
    distance: app_commands.Range[int, 1, 10000],
    mode: app_commands.Choice[str],
    terrain: app_commands.Choice[str] | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    info = TRAVEL_SPEEDS[mode.value]
    speed = info["miles_per_day"]
    terrain_name = "Road/Clear"
    if terrain and terrain.value == "half":
        speed = speed // 2
        terrain_name = "Rough/Hills"
    elif terrain and terrain.value == "quarter":
        speed = speed // 4
        terrain_name = "Mountain/Swamp"
    days = (distance + speed - 1) // speed if speed > 0 else 999
    embed = discord.Embed(title="Travel Calculator", color=discord.Color.green())
    embed.add_field(name="Distance", value=f"{distance} miles", inline=True)
    embed.add_field(name="Mode", value=info["name"], inline=True)
    embed.add_field(name="Terrain", value=terrain_name, inline=True)
    embed.add_field(name="Speed", value=f"{speed} miles/day", inline=True)
    embed.add_field(name="Travel Time", value=f"**{days} day{'s' if days != 1 else ''}**", inline=True)
    embed.add_field(name="Notes", value=info["description"], inline=False)
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 47 — Terrain/Range Modifiers Reference
# ---------------------------------------------------------------------------

TERRAIN_MODIFIERS: list[tuple[str, str]] = [
    ("Light Cover (foliage, fence)", "+10 Armor TN"),
    ("Heavy Cover (wall, fortification)", "+20 Armor TN"),
    ("Concealment (fog, darkness, smoke)", "+10 Armor TN (partial) / +20 (total)"),
    ("Higher Ground (attacker above)", "+1k0 on attack rolls"),
    ("Darkness (total)", "Blinded: all rolls −3k0, TN +10"),
    ("Narrow Footing (bridge, ledge)", "Agility TN 20 or fall; no Full Attack"),
    ("Mounted vs. Foot", "+1k0 to mounted attacker; unmounted −1k0 to attack"),
    ("Prone Target (melee)", "−10 Armor TN"),
    ("Prone Target (ranged)", "+10 Armor TN"),
]

RANGE_INCREMENTS: list[tuple[str, str]] = [
    ("Within first increment", "Normal TN"),
    ("2nd increment", "+10 TN"),
    ("3rd increment", "+20 TN"),
    ("4th increment", "+30 TN"),
    ("5th increment", "+40 TN (maximum range)"),
]


@client.tree.command(name="modifiers", description="Quick reference for terrain, range, and situational combat modifiers (L5R 4e).")
async def modifiers_ref(interaction: discord.Interaction) -> None:
    embed = discord.Embed(title="⚔️ Combat Modifiers Reference", color=discord.Color.dark_gold())
    terrain_lines = [f"**{name}** — {effect}" for name, effect in TERRAIN_MODIFIERS]
    embed.add_field(name="Terrain & Situational", value="\n".join(terrain_lines), inline=False)
    range_lines = [f"**{name}** — {effect}" for name, effect in RANGE_INCREMENTS]
    embed.add_field(name="Range Increments (Ranged Weapons)", value="\n".join(range_lines), inline=False)
    embed.add_field(
        name="How to Apply",
        value=(
            "Use the `bonus_tn:` parameter on `/attack` for situational modifiers.\n"
            "Positive = harder to hit (cover, range). Negative = easier (prone target in melee)."
        ),
        inline=False,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 47 — Called Shot Reference
# ---------------------------------------------------------------------------

@client.tree.command(name="calledshot", description="Called Shot reference: raise costs and body part effects (L5R 4e).")
async def calledshot_ref(interaction: discord.Interaction) -> None:
    embed = discord.Embed(title="🎯 Called Shot Reference", color=discord.Color.dark_gold())
    parts_lines = []
    for raises, part in sorted(combat.CALLED_SHOT_PARTS.items()):
        parts_lines.append(f"**{raises} raise{'s' if raises != 1 else ''}** — {part.title()}")
    embed.add_field(name="Raises → Target", value="\n".join(parts_lines), inline=False)
    embed.add_field(
        name="Effects",
        value=(
            "Called Shots use the standard Raise mechanic (+5 TN per raise). "
            "On a successful hit, the DM adjudicates the effect based on the body part:\n"
            "• **Limb** — may disarm, hamper movement, or force a Stamina check\n"
            "• **Hand/Foot** — may drop weapon, reduce movement\n"
            "• **Head** — +1k1 bonus damage on this strike\n"
            "• **Eye/Ear/Finger** — devastating: +1k1 damage, potential permanent injury"
        ),
        inline=False,
    )
    embed.add_field(
        name="Usage",
        value="Use `/attack maneuver: Called Shot raises: N` — the raise cost is added to TN automatically.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Phase 47 — Medicine Treatment (wound healing with DM gate)
# ---------------------------------------------------------------------------

class MedicineTreatView(discord.ui.View):
    """DM-approval gate for medicine treatment healing."""

    def __init__(
        self, healer_name: str, target_id: int, target_name: str,
        wounds_healed: int, treatment_type: str, roll_result: dict,
    ) -> None:
        super().__init__(timeout=1800)
        self.healer_name = healer_name
        self.target_id = target_id
        self.target_name = target_name
        self.wounds_healed = wounds_healed
        self.treatment_type = treatment_type
        self.roll_result = roll_result

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()

    @discord.ui.button(label="Apply Healing", style=discord.ButtonStyle.success, emoji="💚")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
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
        await interaction.followup.send(embed=embed)
        await _combat_log(
            str(interaction.guild_id),
            f"Medicine: {self.healer_name} treats {self.target_name} ({self.treatment_type}) "
            f"{self.wounds_healed} wounds healed [{new_level}]",
        )

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can resolve this.", ephemeral=True)
            return
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(
            f"🛡️ {interaction.user.display_name} denied — no healing applied to **{self.target_name}**."
        )


MEDICINE_TN = {
    "wound_treatment": 15,
    "disease_diagnosis": 15,
    "poison_treatment": 20,
    "antidote_preparation": 20,
}


@dm.command(name="log_channel", description="Set the channel where combat events are logged (persistent record).")
@app_commands.describe(channel="The text channel to post combat log entries to.")
async def dm_log_channel(
    interaction: discord.Interaction,
    channel: discord.TextChannel,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can set the combat log channel.", ephemeral=True)
        return
    store.set_log_channel(str(interaction.guild_id), str(channel.id))
    await interaction.response.send_message(
        f"Combat log channel set to {channel.mention}. "
        f"Attack outcomes, damage, healing, turn advances, and other combat events "
        f"will be logged there automatically."
    )


@dm.command(name="clear_log", description="Stop logging combat events (removes the log channel setting).")
async def dm_clear_log(interaction: discord.Interaction) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can clear the combat log channel.", ephemeral=True)
        return
    store.clear_log_channel(str(interaction.guild_id))
    await interaction.response.send_message("Combat log channel cleared. Events will no longer be logged.")


@dm.command(name="treat", description="Medicine treatment: healer rolls, DM approves healing. L5R 4e Medicine rules.")
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
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    if not _is_dm(interaction):
        await interaction.response.send_message("Only a DM can call for treatment.", ephemeral=True)
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
        title=f"💊 {treat_label} — {hc.name} treats {pc.name}",
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
        value=f"**{result['total']}** vs TN {tn} — {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    if success and heal_amount > 0 and pc.wounds_taken > 0:
        effective_heal = min(heal_amount, pc.wounds_taken)
        embed.add_field(
            name="Healing",
            value=f"**{effective_heal}** wounds to heal (Intelligence {hc.intelligence} × 2 = {hc.intelligence * 2})",
            inline=False,
        )
        view = MedicineTreatView(
            healer_name=hc.name, target_id=patient_rec.id, target_name=pc.name,
            wounds_healed=effective_heal, treatment_type=treat_label, roll_result=result,
        )
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
# Phase 47 — Character Import/Export
# ---------------------------------------------------------------------------

@sheet.command(name="export", description="Export your active character sheet as JSON (for backup or sharing).")
@app_commands.describe(
    member="Export another player's character (DM only).",
)
async def sheet_export(
    interaction: discord.Interaction,
    member: discord.Member | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
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
            f"**{c.name}** — character sheet JSON:\n```json\n{payload}\n```",
            ephemeral=True,
        )
    else:
        import io
        buf = io.BytesIO(payload.encode("utf-8"))
        fname = c.name.lower().replace(" ", "_").replace("'", "") + ".json"
        file = discord.File(buf, filename=fname)
        await interaction.response.send_message(
            content=f"**{c.name}** — character sheet exported.",
            file=file,
            ephemeral=True,
        )


@sheet.command(name="import_sheet", description="Import a character from JSON (paste the JSON or attach a .json file).")
@app_commands.describe(
    json_data="Paste the character JSON here (or attach a .json file instead).",
)
async def sheet_import(
    interaction: discord.Interaction,
    json_data: str | None = None,
) -> None:
    if not _guild_ok(interaction):
        await interaction.response.send_message("Use in a server channel.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    owner = str(interaction.user.id)
    import json as _json

    raw: str | None = json_data
    if raw is None or raw.strip() == "":
        await interaction.response.send_message(
            "Paste your character JSON in the `json_data` parameter. "
            "Get it from `/sheet export`.",
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


client.tree.add_command(sheet)
client.tree.add_command(dm)
client.tree.add_command(combat_group)
client.tree.add_command(grapple_group)
client.tree.add_command(duel_group)
client.tree.add_command(void_group)
client.tree.add_command(npc)
client.tree.add_command(room)
client.tree.add_command(creature_group)
client.tree.add_command(xp)
client.tree.add_command(school)
client.tree.add_command(spell_group)
client.tree.add_command(weapon_group)
client.tree.add_command(armor_group)
client.tree.add_command(advantage_group)
client.tree.add_command(kata_group)
client.tree.add_command(kiho_group)
client.tree.add_command(heritage_group)
client.tree.add_command(battle_group)
client.tree.add_command(family_group)


def main() -> None:
    if not TOKEN:
        raise SystemExit(
            "DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and paste your "
            "bot token, or export DISCORD_BOT_TOKEN in the environment. See README.md."
        )
    client.run(TOKEN)


if __name__ == "__main__":
    main()
