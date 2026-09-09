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

import storage
from l5r_rules import enums, stats
from l5r_rules.character import Character
from l5r_rules.dice import DiceEngine, DiceResult

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
    embed.description = f"{header}\n{school_line}"

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
    wound_line = (
        f"**{lvl}**" + (f" ({pen} penalty)" if pen else "")
        + f"\n{c.wounds_taken} / {cap} wounds  ·  {per} per level"
    )
    embed.add_field(name="Wounds", value=wound_line, inline=True)

    embed.add_field(
        name="Standing",
        value=(
            f"Honor {c.honor:g} · Glory {c.glory:g} · Status {c.status:g} · Infamy {c.infamy:g}\n"
            f"Insight {stats.insight(c)} (Rank {stats.insight_rank(c)}) · "
            f"Void Points {c.current_void_points}/{c.max_void_points}"
        ),
        inline=False,
    )

    gear = f"Armor: {c.armor_name or '—'}  (TN +{c.armor_tn_bonus}, Reduction {c.armor_reduction})"
    if c.weapons:
        gear += "\nWeapons: " + ", ".join(c.weapons)
    embed.add_field(name="Equipment", value=gear, inline=False)

    if c.skills:
        skill_line = ", ".join(f"{name} {rank}" for name, rank in sorted(c.skills.items()))
        embed.add_field(name="Skills", value=skill_line[:1024], inline=False)

    extras = []
    if c.techniques:
        extras.append("**Techniques:** " + ", ".join(c.techniques))
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
    clan="Great/Minor Clan (optional).",
    family="Family (optional).",
    school="School name (optional).",
    school_type="School type (default Bushi).",
    age="Age (default 16).",
)
@app_commands.choices(school_type=_SCHOOL_CHOICES)
async def sheet_create(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 64],
    clan: str | None = None,
    family: str | None = None,
    school: str | None = None,
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
    await interaction.response.send_message(
        content=f"Created **{name}** and set it as your active character. "
        f"All Traits start at 2 (the L5R 4e baseline) — set them with `/sheet trait` "
        f"and `/sheet skill`.",
        embed=build_sheet_embed(record),
    )


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
    c = rec.character
    f = field.value
    if f in ("honor", "glory", "status", "infamy"):
        setattr(c, f, max(0.0, min(10.0, float(value))))
    elif f == "taint":
        c.taint = max(0.0, float(value))
    elif f == "koku":
        c.koku = float(value)
    elif f == "age":
        c.age = max(0, int(value))
    elif f == "school_rank":
        c.school_rank = max(1, min(10, int(value)))
    elif f == "void_points_max":
        c.max_void_points = max(0, int(value))
        c.current_void_points = min(c.current_void_points, c.max_void_points)
    elif f == "void_points_current":
        c.current_void_points = max(0, min(int(value), c.max_void_points))
    elif f == "armor_tn_bonus":
        c.armor_tn_bonus = max(0, int(value))
    elif f == "armor_reduction":
        c.armor_reduction = max(0, int(value))
    store.save(rec)
    await interaction.response.send_message(
        f"Updated **{f}** on **{c.name}**.", embed=build_sheet_embed(rec)
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


client.tree.add_command(sheet)
client.tree.add_command(dm)


def main() -> None:
    if not TOKEN:
        raise SystemExit(
            "DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and paste your "
            "bot token, or export DISCORD_BOT_TOKEN in the environment. See README.md."
        )
    client.run(TOKEN)


if __name__ == "__main__":
    main()
