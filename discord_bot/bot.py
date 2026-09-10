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
from l5r_rules import advancement, advantages, combat, creature, enums, npc_gen, schools, spells, stats
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
            f"Void Points {c.current_void_points}/{c.max_void_points}\n"
            f"XP available: **{c.xp:g}** (spent {c.xp_spent:g})"
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
    if c.katas:
        extras.append("**Kata:** " + ", ".join(c.katas))
    if c.kiho:
        extras.append("**Kiho:** " + ", ".join(c.kiho))
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


async def _spell_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    cur = current.lower().strip()
    out = [
        app_commands.Choice(name=f"{s['name']} ({s['element']} {s['mastery']})", value=s["name"])
        for s in spells.ALL if cur in s["name"].lower()
    ]
    return out[:25]


_MANEUVER_APPLY_LABEL = {
    "none": "Roll & Apply Damage",
    "feint": "Roll & Apply Damage (Feint)",
    "increased_damage": "Roll & Apply Damage",
    "disarm": "Resolve Disarm (2k1 + Strength)",
    "knockdown": "Resolve Knockdown (Strength)",
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
        # Relabel the primary button to match the maneuver.
        for child in self.children:
            if isinstance(child, discord.ui.Button) and child.style == discord.ButtonStyle.danger:
                child.label = _MANEUVER_APPLY_LABEL.get(maneuver, "Roll & Apply Damage")

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

    @discord.ui.button(label="Roll & Apply Damage", style=discord.ButtonStyle.danger, emoji="⚔️")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _is_dm(interaction):
            await interaction.response.send_message("Only a DM can authorize this.", ephemeral=True)
            return

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
            dmg = combat.resolve_damage(attacker_rec.character, self.weapon, engine, self.increased_damage)
            raw = dmg["raw_damage"]
            feint_line = ""
            if self.maneuver == "feint":
                fb = combat.compute_feint_bonus(self.attack_margin, stats.insight_rank(attacker_rec.character))
                raw += fb
                feint_line = f"\nFeint bonus **+{fb}**"
            applied = creature.apply_damage_to_creature(cre_rec.creature, raw, cre_rec.creature.reduction)
            store.save_creature(cre_rec)
            cr = cre_rec.creature
            embed = discord.Embed(
                title="⚔️ Damage applied",
                color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
            )
            embed.add_field(
                name="Damage",
                value=(
                    f"{self.attacker_name} → **{self.target_name}** with {self.weapon}\n"
                    f"{_format_dice(dmg['dice'])}{feint_line}\n"
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
            embed.add_field(name="Result", value=status, inline=False)
            embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
            self._disable()
            await interaction.response.edit_message(view=self)
            await interaction.followup.send(embed=embed)
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
            return

        if self.maneuver == "disarm":
            dis = combat.resolve_disarm(attacker, target, engine)
            applied = combat.apply_damage(target, dis["damage"], target.armor_reduction)
            store.save(target_rec)
            embed = discord.Embed(
                title="🗡️ Disarm",
                color=discord.Color.green() if dis["disarmed"] else discord.Color.orange(),
            )
            embed.add_field(
                name="Damage (2k1)",
                value=f"{_format_dice(dis['damage_dice'])}\nRaw **{dis['damage']}** − reduction "
                f"{applied['reduction']} = **{applied['final_damage']}** wounds",
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
            return

        # Plain hit or Feint: weapon damage (+ feint bonus).
        dmg = combat.resolve_damage(attacker, self.weapon, engine, self.increased_damage)
        raw = dmg["raw_damage"]
        feint_line = ""
        if self.maneuver == "feint":
            fb = combat.compute_feint_bonus(self.attack_margin, stats.insight_rank(attacker))
            raw += fb
            feint_line = f"\nFeint bonus **+{fb}** (½ margin {self.attack_margin}, cap 5×Insight Rank)"
        applied = combat.apply_damage(target, raw, target.armor_reduction)
        store.save(target_rec)

        embed = discord.Embed(
            title="⚔️ Damage applied",
            color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
        )
        embed.add_field(
            name="Damage",
            value=(
                f"{self.attacker_name} → **{self.target_name}** with {self.weapon}\n"
                f"{_format_dice(dmg['dice'])}{feint_line}\n"
                f"Raw **{raw}** − reduction {applied['reduction']} = "
                f"**{applied['final_damage']}** wounds"
            ),
            inline=False,
        )
        embed.add_field(name="Result", value=self._wound_status(target_rec, applied), inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        await interaction.followup.send(embed=embed)

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


_MANEUVER_CHOICES = [
    app_commands.Choice(name="None", value="none"),
    app_commands.Choice(name="Feint (2 raises → bonus damage)", value="feint"),
    app_commands.Choice(name="Disarm (3 raises → 2k1 + contested Strength)", value="disarm"),
    app_commands.Choice(name="Knockdown (2 raises → contested Strength)", value="knockdown"),
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
    weapon="Weapon (default katana). Start typing for suggestions.",
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
    weapon: str = "katana",
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

    a_stance = attacker_stance.value if attacker_stance else "attack"
    d_stance = defender_stance.value if defender_stance else "attack"
    man = maneuver.value if maneuver else "none"

    if target_creature_rec is not None and man in ("disarm", "knockdown"):
        await interaction.response.send_message(
            "Disarm/Knockdown aren't supported against creatures yet — use a plain attack or Feint.",
            ephemeral=True,
        )
        return
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

    # Target name + Armor TN depend on the target kind.
    if target_creature_rec is not None:
        t_name = target_creature_rec.creature.name
        tn = target_creature_rec.creature.armor_tn + bonus_tn
    else:
        t_name = target_rec.character.name
        tn = combat.armor_tn(target_rec.character, d_stance, bonus_tn)

    outcome = combat.resolve_attack(
        attacker_rec.character, weapon, tn, raises + maneuver_raises, engine,
        attacker_stance=a_stance, increased_damage=increased_damage,
        bonus_rolled=bonus_rolled, bonus_kept=bonus_kept,
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
        atk_desc += f"  ·  {a_stance.replace('_', ' ').title()}"
    if man != "none":
        atk_desc += f"  ·  Maneuver: {man.title()}"
    atk_desc += void_line
    embed.add_field(name="Attacker", value=atk_desc, inline=False)
    embed.add_field(name="Attack roll", value=_format_dice(outcome["dice"]), inline=False)

    tn_note = f"Armor TN **{outcome['target_tn']}**"
    if outcome["raises"]:
        tn_note += f" ({outcome['raises']} raises)"
    if target_creature_rec is None and d_stance != "attack":
        tn_note += f"  ·  {d_stance.replace('_', ' ').title()}"
    verdict = "✅ **HIT**" if hit else "❌ **MISS**"
    embed.add_field(
        name="Result",
        value=f"Total **{outcome['roll']}** vs {tn_note} — {verdict} (margin {outcome['margin']:+d})",
        inline=False,
    )
    if outcome["unskilled"]:
        embed.set_footer(text=f"Unskilled in {outcome['skill_name']} — dice did not explode.")

    if hit:
        if target_creature_rec is not None:
            view = DamageView(
                attacker_rec.id, None, weapon, increased_damage, a_name, t_name,
                maneuver=man, attack_margin=outcome["margin"],
                target_creature_id=target_creature_rec.id,
            )
        else:
            view = DamageView(
                attacker_rec.id, target_rec.id, weapon, increased_damage, a_name, t_name,
                maneuver=man, attack_margin=outcome["margin"],
            )
        prompt = {
            "disarm": "A DM can resolve the disarm below.",
            "knockdown": "A DM can resolve the knockdown below.",
        }.get(man, "A DM can authorize the damage below.")
        await interaction.response.send_message(content=prompt, embed=embed, view=view)
    else:
        await interaction.response.send_message(embed=embed)


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
@app_commands.autocomplete(school=_school_autocomplete)
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
        content = (
            f"Created **{name}** and set it as your active character. All Traits start at 2 "
            f"(the L5R 4e baseline). Tip: pass a `school:` from the catalog to auto-fill it."
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


# ===========================================================================
# /combat group — initiative tracker
# ===========================================================================
combat_group = app_commands.Group(name="combat", description="Track combat initiative and turn order.")


def _render_encounter(enc: encounter.Encounter) -> str:
    if not enc.combatants:
        return "No combatants yet. Add them with `/combat join` or `/combat add`."
    cur = enc.current()
    lines = []
    for i, c in enumerate(enc.combatants):
        marker = "▶️ " if (enc.started and c is cur) else f"{i + 1}. "
        tag = " *(NPC)*" if c.is_npc else ""
        detail = f"  ·  {c.initiative_detail}" if c.initiative_detail else ""
        lines.append(f"{marker}**{c.name}**{tag} — init **{c.initiative}**{detail}")
    header = f"⚔️ **Round {enc.round}**" if enc.started else "⚔️ **Not started** — use `/combat next` to begin."
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
    ))
    await interaction.response.send_message(_render_encounter(enc))


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
    ))
    await interaction.response.send_message(_render_encounter(enc))


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
    current = enc.advance()
    await interaction.response.send_message(
        f"➡️ It is now **{current.name}**'s turn.\n\n{_render_encounter(enc)}"
    )


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
    ))
    await interaction.response.send_message(_render_encounter(enc))


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
@app_commands.autocomplete(school=_school_autocomplete)
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
    else:
        await interaction.response.send_message(embed=embed)


# ===========================================================================
# /xp group — Experience: DMs grant, players spend to advance (L5R 4e RAW)
# ===========================================================================
xp = app_commands.Group(name="xp", description="Grant and spend Experience to advance characters (L5R 4e RAW).")


async def _buy_named(interaction, member, name, mastery_level, attr, label, emoji, note=""):
    """Shared handler for Kata / Kiho / memorised Spell (cost = 1 x Mastery Level)."""
    rec, err = await _resolve_active_for_edit(interaction, member)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    lst = getattr(c, attr)
    if any(x.lower() == name.lower() for x in lst):
        await interaction.response.send_message(f"**{c.name}** already knows the {label} **{name}**.", ephemeral=True)
        return
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
@app_commands.describe(name="Kata name.", mastery_level="Its Mastery Level.", member="Advance another player's character (DM only).")
async def xp_kata(interaction: discord.Interaction, name: app_commands.Range[str, 1, 60], mastery_level: app_commands.Range[int, 1, 10], member: discord.Member | None = None) -> None:
    await _buy_named(interaction, member, name.strip(), mastery_level, "katas", "kata", "\U0001F94B")


@xp.command(name="kiho", description="Learn a Kiho (cost = 1 x Mastery Level; non-Brotherhood mods DM-adjudicated).")
@app_commands.describe(name="Kiho name.", mastery_level="Its Mastery Level.", member="Advance another player's character (DM only).")
async def xp_kiho(interaction: discord.Interaction, name: app_commands.Range[str, 1, 60], mastery_level: app_commands.Range[int, 1, 10], member: discord.Member | None = None) -> None:
    await _buy_named(interaction, member, name.strip(), mastery_level, "kiho", "kiho", "✋",
                     note=" *(Brotherhood cost; non-Brotherhood modifiers per Core p.266 are DM-adjudicated.)*")


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


def build_school_embed(s: dict) -> discord.Embed:
    kw = f" [{', '.join(s['keywords'])}]" if s["keywords"] else ""
    embed = discord.Embed(title=f"🏯 {s['name']}{kw}", color=discord.Color.dark_teal())
    embed.description = f"{s['clan']} school"
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
        embed.add_field(name=f"{rank_label} — {t['name']}"[:256], value=t["effect"][:1024], inline=False)
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
        names = ", ".join(s["name"] for s in matches)
        await interaction.response.send_message(
            f"🏯 **{clan} schools ({len(matches)}):** {names}", ephemeral=True
        )
        return
    from collections import Counter
    counts = Counter(s["clan"] for s in schools.ALL)
    summary = " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    await interaction.response.send_message(
        f"🏯 **{len(schools.ALL)} schools.** Browse with `/school list clan:<clan>`, "
        f"`/school search`, or `/school view`.\n{summary}",
        ephemeral=True,
    )


@school.command(name="search", description="Search schools by name or clan.")
@app_commands.describe(query="Name or clan fragment.")
async def school_search(interaction: discord.Interaction, query: str) -> None:
    matches = schools.search(query)
    if not matches:
        await interaction.response.send_message(f"No schools match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{s['name']}** ({s['clan']})" for s in matches[:40]]
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


client.tree.add_command(sheet)
client.tree.add_command(dm)
client.tree.add_command(combat_group)
client.tree.add_command(npc)
client.tree.add_command(room)
client.tree.add_command(creature_group)
client.tree.add_command(xp)
client.tree.add_command(school)
client.tree.add_command(spell_group)
client.tree.add_command(weapon_group)
client.tree.add_command(armor_group)
client.tree.add_command(advantage_group)


def main() -> None:
    if not TOKEN:
        raise SystemExit(
            "DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and paste your "
            "bot token, or export DISCORD_BOT_TOKEN in the environment. See README.md."
        )
    client.run(TOKEN)


if __name__ == "__main__":
    main()
