"""Skill, trait, and special check slash commands (/check group).

Extracted from bot.py - all 13 check commands plus their check-only
constants and helpers.  Shared helpers (guards, autocompletes, format_dice,
log_roll, resolve_duelist) are injected via init().
"""

from __future__ import annotations

import discord
from discord import app_commands

from l5r_rules import combat, enums, stats, taint
from l5r_rules import advantage_effects
from l5r_rules import tattoo_effects
import storage as _storage_mod


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store: _storage_mod.Store
    engine: object  # DiceEngine
    require_guild: object
    require_dm_role: object
    resolve_duelist: object
    format_dice: object
    log_roll: object
    refuse_if_dead: object
    refuse_if_cannot_act: object
    fear_penalty: object
    set_fear_penalty: object
    is_dm: object
    ROLE_FORTUNE: str
    NPC_OWNER: str


_d = _Deps()


def init(
    *,
    store: _storage_mod.Store,
    engine: object,
    require_guild,
    require_dm_role,
    resolve_duelist,
    format_dice,
    log_roll,
    npc_owner: str,
    skill_autocomplete,
    refuse_if_dead,
    refuse_if_cannot_act,
    fear_penalty,
    set_fear_penalty,
    is_dm,
    role_fortune,
) -> None:
    _d.store = store
    _d.engine = engine
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.resolve_duelist = resolve_duelist
    _d.format_dice = format_dice
    _d.log_roll = log_roll
    _d.refuse_if_dead = refuse_if_dead
    _d.refuse_if_cannot_act = refuse_if_cannot_act
    _d.fear_penalty = fear_penalty
    _d.set_fear_penalty = set_fear_penalty
    _d.is_dm = is_dm
    _d.ROLE_FORTUNE = role_fortune
    _d.NPC_OWNER = npc_owner

    # Wire autocompletes programmatically
    for cmd in (skill_check_cmd, check_cooperative, stealth_check, social_check, craft_check,
                lore_check, horsemanship_check, medicine_check):
        cmd.autocomplete("emphasis")(_emphasis_autocomplete)
    skill_check_cmd.autocomplete("skill")(skill_autocomplete)
    check_cooperative.autocomplete("skill")(skill_autocomplete)
    craft_check.autocomplete("skill")(skill_autocomplete)
    lore_check.autocomplete("specialty")(skill_autocomplete)


# ---------------------------------------------------------------------------
# Check-only constants
# ---------------------------------------------------------------------------

_CONTEST_TRAITS = [
    app_commands.Choice(name=("Void" if t == "void" else t.capitalize()), value=t)
    for t in enums.TRAITS
]

_INVESTIGATION_EMPHASIS = [
    app_commands.Choice(name="Notice (passive alertness)", value="Notice"),
    app_commands.Choice(name="Interrogation (questioning a subject)", value="Interrogation"),
    app_commands.Choice(name="Search (active search of an area)", value="Search"),
]

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


# ---------------------------------------------------------------------------
# Check-only helpers
# ---------------------------------------------------------------------------

def _try_spend_void(
    c, spend_void: bool, *,
    skill_name: str = "", sk: int = -1,
    void_unskilled: bool = False,
    void_param_label: str = "spend_void",
) -> tuple[int, int, bool, str, int]:
    """Handle Void Point spending for rolls.

    Returns (extra_rolled, extra_kept, spent, status_line, new_sk).
    *new_sk* only differs from *sk* when void_unskilled succeeds.
    """
    void_r = void_k = 0
    void_line = ""
    void_spent = False
    if spend_void:
        ok, reason = advantage_effects.can_spend_void_on_roll(c, skill_name=skill_name) if skill_name else advantage_effects.can_spend_void_on_roll(c)
        if not ok:
            void_line = f"\U0001f300 {reason}"
        elif c.current_void_points <= 0:
            void_line = f"\U0001f300 no Void Points to spend (0/{c.max_void_points})"
        else:
            c.current_void_points -= 1
            void_r = void_k = 1
            void_spent = True
            void_line = f"\U0001f300 Void +1k1 ({c.current_void_points} VP left)"
    if void_unskilled and not spend_void:
        if sk > 0:
            void_line = f"\U0001f300 Already has {skill_name} {sk} - use {void_param_label} for +1k1 instead"
        else:
            ok, reason = advantage_effects.can_spend_void_on_roll(c, skill_name=skill_name)
            if not ok:
                void_line = f"\U0001f300 {reason}"
            elif c.current_void_points <= 0:
                void_line = f"\U0001f300 no Void Points to spend (0/{c.max_void_points})"
            else:
                c.current_void_points -= 1
                sk = 1
                void_spent = True
                void_line = f"\U0001f300 Void: Skill 0→1 (unskilled penalty removed, {c.current_void_points} VP left)"
    return void_r, void_k, void_spent, void_line, sk


def _fear(interaction: discord.Interaction, c, adv_r: int, adv_notes: list[str]) -> tuple[int, list[str]]:
    """Apply a tracked failed-Fear penalty (GDD s46: -Xk0 to all rolls) to a check's rolled dice."""
    fr = _d.fear_penalty(interaction.channel_id, c.name)
    if fr:
        return adv_r - fr, adv_notes + [f"Fear: -{fr}k0 (failed Fear check)"]
    return adv_r, adv_notes


_FIXED_SKILL_BY_COMMAND: dict[str, str] = {"stealth": "Stealth", "horsemanship": "Horsemanship", "medicine": "Medicine"}


async def _emphasis_autocomplete(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    """Offer the Emphases the check's character has in the Skill being rolled."""
    ns = interaction.namespace
    cmd_name = interaction.command.name if interaction.command else ""
    skill = _FIXED_SKILL_BY_COMMAND.get(cmd_name) or getattr(ns, "skill", None) or getattr(ns, "specialty", None)
    if isinstance(skill, app_commands.Choice):
        skill = skill.value
    if not skill or interaction.guild_id is None:
        return []
    guild = str(interaction.guild_id)
    rec = None
    try:
        name = getattr(ns, "name", None) or ""
        if name or getattr(ns, "member", None) is not None:
            rec = _d.resolve_duelist(guild, interaction.channel_id, name, bool(getattr(ns, "is_npc", False)),
                                     getattr(ns, "member", None))
    except Exception:
        rec = None
    if rec is None:
        rec = _d.store.get_active(guild, str(interaction.user.id))
    if rec is None:
        return []
    cur = (current or "").lower()
    emphs = rec.character.emphases.get(str(skill), [])
    return [app_commands.Choice(name=e, value=e) for e in emphs if cur in e.lower()][:25]


async def _resolve_roller(interaction: discord.Interaction, name: str | None, is_npc: bool,
                          member: discord.Member | None):
    """The character to roll for. With no name, member or NPC flag it is the
    caller's active character. Anyone may roll for their own character; another
    player's character or an NPC needs the Fortune role. Sends the error itself."""
    guild = str(interaction.guild_id)
    uid = str(interaction.user.id)
    if not name and member is None and not is_npc:
        rec = _d.store.get_active(guild, uid)
        if rec is None:
            await interaction.response.send_message(
                "You have no active character. Create one with `/sheet create`, or give a `name:`.", ephemeral=True,
            )
            return None
        return rec
    rec = _d.resolve_duelist(guild, interaction.channel_id, name or "", is_npc, member)
    if rec is None:
        who = name or (member.display_name if member is not None else "that character")
        await interaction.response.send_message(f"No character found for **{who}**.", ephemeral=True)
        return None
    if rec.owner_id != uid and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can roll for your own character. Rolling for **{rec.character.name}** needs the "
            f"**{_d.ROLE_FORTUNE}** role.", ephemeral=True,
        )
        return None
    return rec


def _emphasis_for(c, skill_name: str, requested: str | None) -> tuple[str | None, str | None]:
    """(matched Emphasis, error). An Emphasis must be on the sheet for that Skill;
    it rerolls 1s once (GDD s04.5 / s24.0)."""
    if not requested:
        return None, None
    emph = combat.emphasis_match(c, skill_name, requested)
    if emph:
        return emph, None
    have = ", ".join(c.emphases.get(skill_name, [])) or "none"
    return None, f"**{c.name}** has no *{requested.strip()}* Emphasis in {skill_name} (sheet: {have})."


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
    adv_notes: list[str] | None = None,
    void_line: str = "",
) -> discord.Embed:
    success = result["success"]
    embed = discord.Embed(
        title=f"{title}: {c_name}",
        color=discord.Color.green() if success else discord.Color.greyple(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    roll_text = (
        f"{skill_label}/{trait_name} ({result['rolled']}k{result['kept']}"
        f"{wp_str}{bonus_str}) vs TN **{result['tn']}**"
    )
    if void_line:
        roll_text += f"\n{void_line}"
    embed.add_field(name="Roll", value=roll_text, inline=False)
    embed.add_field(name="Dice", value=_d.format_dice(result["dice"]), inline=False)
    verdict = success_text if success else fail_text
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {result['tn']}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    if adv_notes:
        embed.add_field(name="Advantages/Disadvantages", value="\n".join(adv_notes), inline=False)
    return embed


# ---------------------------------------------------------------------------
# Group definition
# ---------------------------------------------------------------------------

check = app_commands.Group(name="check", description="Skill, trait, contested and situational checks for a character.")


# ---------------------------------------------------------------------------
# /check contest
# ---------------------------------------------------------------------------

@check.command(
    name="contest",
    description="Contested Skill/Trait roll between two characters. [Fortune]",
)
@app_commands.describe(
    name_a="First participant (combatant or NPC name).",
    trait_a="Trait for A (the kept dice).",
    skill_a="Skill for A (e.g. Intimidation).",
    name_b="Second participant name.",
    trait_b="Trait for B.",
    skill_b="Skill name for B.",
    a_member="First participant as a player.",
    b_member="Second participant as a player.",
    a_is_npc="First name is an NPC.",
    b_is_npc="Second name is an NPC.",
    bonus_a="Flat bonus for A.",
    bonus_b="Flat bonus for B.",
    void_a="A spends a Void Point for +1k1.",
    void_b="B spends a Void Point for +1k1.",
    void_unskilled_a="A: Void Point to treat Skill 0 as Rank 1.",
    void_unskilled_b="B: Void Point to treat Skill 0 as Rank 1.",
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
    void_a: bool = False,
    void_b: bool = False,
    void_unskilled_a: bool = False,
    void_unskilled_b: bool = False,
    reason: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    if void_a and void_unskilled_a:
        await interaction.response.send_message("A: cannot use both void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    if void_b and void_unskilled_b:
        await interaction.response.send_message("B: cannot use both void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _d.resolve_duelist(guild, ch, name_a, a_is_npc, a_member)
    rec_b = _d.resolve_duelist(guild, ch, name_b, b_is_npc, b_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{name_a}**.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"No character found for **{name_b}**.", ephemeral=True)
        return
    ca, cb = rec_a.character, rec_b.character
    if await _d.refuse_if_cannot_act(interaction, ca) or await _d.refuse_if_cannot_act(interaction, cb):
        return
    tv_a = stats.trait_value(ca, trait_a.value)
    tv_b = stats.trait_value(cb, trait_b.value)
    sk_a = ca.skills.get(skill_a, 0)
    sk_b = cb.skills.get(skill_b, 0)
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb)
    adv_ra, adv_ka, adv_fa, adv_notes_a = advantage_effects.skill_check_modifiers(
        ca, skill_a, trait_a.value, is_contested=True, opponent_skill=skill_b,
    )
    adv_rb, adv_kb, adv_fb, adv_notes_b = advantage_effects.skill_check_modifiers(
        cb, skill_b, trait_b.value, is_contested=True, opponent_skill=skill_a,
    )
    # GDD s46: the side resisting Intimidation or Temptation adds Honor Rank.
    soh_ra, soh_fa, soh_na = advantage_effects.strength_of_honor(ca, skill_b)
    soh_rb, soh_fb, soh_nb = advantage_effects.strength_of_honor(cb, skill_a)
    adv_ra += soh_ra; adv_fa += soh_fa; adv_notes_a = adv_notes_a + soh_na
    adv_rb += soh_rb; adv_fb += soh_fb; adv_notes_b = adv_notes_b + soh_nb
    # s42: Taint Rank 3/4 lose rolled dice on Social Skill rolls.
    tp_ra, tp_na = taint.social_roll_penalty(ca, skill_a)
    tp_rb, tp_nb = taint.social_roll_penalty(cb, skill_b)
    adv_ra += tp_ra; adv_notes_a = adv_notes_a + tp_na
    adv_rb += tp_rb; adv_notes_b = adv_notes_b + tp_nb
    adv_ra, adv_notes_a = _fear(interaction, ca, adv_ra, adv_notes_a)
    adv_rb, adv_notes_b = _fear(interaction, cb, adv_rb, adv_notes_b)
    void_ra, void_ka, void_spent_a, void_line_a, sk_a = _try_spend_void(
        ca, void_a, skill_name=skill_a, sk=sk_a,
        void_unskilled=void_unskilled_a, void_param_label="void_a",
    )
    void_rb, void_kb, void_spent_b, void_line_b, sk_b = _try_spend_void(
        cb, void_b, skill_name=skill_b, sk=sk_b,
        void_unskilled=void_unskilled_b, void_param_label="void_b",
    )
    result = combat.resolve_contested_check(
        tv_a, sk_a, tv_b, sk_b, _d.engine,
        bonus_a=bonus_a + wp_a + adv_fa,
        bonus_b=bonus_b + wp_b + adv_fb,
        extra_rolled_a=adv_ra + void_ra, extra_kept_a=adv_ka + void_ka,
        extra_rolled_b=adv_rb + void_rb, extra_kept_b=adv_kb + void_kb,
    )
    if void_spent_a:
        _d.store.save(rec_a)
    if void_spent_b:
        _d.store.save(rec_b)
    title = "🎯 Contested Check"
    if reason:
        title += f": {reason}"
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
    a_text = (
        f"{a_label} ({result['rolled_a']}k{result['kept_a']}"
        f"{a_wp_str}{a_bonus_str}) → **{result['total_a']}**\n"
        f"{_d.format_dice(result['dice_a'])}"
    )
    if void_line_a:
        a_text += f"\n{void_line_a}"
    embed.add_field(name=ca.name, value=a_text, inline=False)
    if adv_notes_a:
        embed.add_field(name=f"{ca.name} Adv/Disadv", value="\n".join(adv_notes_a), inline=False)
    b_text = (
        f"{b_label} ({result['rolled_b']}k{result['kept_b']}"
        f"{b_wp_str}{b_bonus_str}) → **{result['total_b']}**\n"
        f"{_d.format_dice(result['dice_b'])}"
    )
    if void_line_b:
        b_text += f"\n{void_line_b}"
    embed.add_field(name=cb.name, value=b_text, inline=False)
    if adv_notes_b:
        embed.add_field(name=f"{cb.name} Adv/Disadv", value="\n".join(adv_notes_b), inline=False)
    embed.add_field(name="Result", value=verdict, inline=False)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check fear
# ---------------------------------------------------------------------------

@check.command(
    name="fear",
    description="Fear check: Willpower vs TN 5 + (Fear Rank x 5).",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    fear_rank="Fear Rank 1-10 (TN = 5 + rank x 5).",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    clear="Clear the Fear penalty instead of rolling.",
)
async def fear_check(
    interaction: discord.Interaction,
    fear_rank: app_commands.Range[int, 1, 10],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    clear: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    if tattoo_effects.is_fear_immune(c):
        await interaction.response.send_message(
            f"**{c.name}** is immune to Fear (Mantis Tattoo). No roll needed.",
            ephemeral=True,
        )
        return
    if clear:
        cleared = _d.set_fear_penalty(guild, interaction.channel_id, c.name, 0)
        await interaction.response.send_message(
            f"😌 Fear penalty cleared for **{c.name}**." if cleared
            else f"**{c.name}** is not in this channel's encounter; nothing to clear.",
        )
        return
    wp = stats.wound_penalty(c)
    void_r, void_k, void_spent, void_line, _ = _try_spend_void(c, spend_void)
    soh_r, soh_f, soh_notes = advantage_effects.strength_of_honor(c, "fear")
    prev_fear = _d.fear_penalty(interaction.channel_id, c.name)
    if prev_fear:
        soh_notes = soh_notes + [f"Fear: -{prev_fear}k0 (earlier failed Fear check)"]
    result = combat.resolve_fear_check(
        c.willpower, fear_rank, _d.engine, bonus=bonus + wp + soh_f,
        extra_rolled=void_r + soh_r - prev_fear, extra_kept=void_k,
    )
    if void_spent:
        _d.store.save(rec)
    success = result["success"]
    tn = result["tn"]
    # GDD s46: failure = -Xk0 (X = Fear Rank) to all rolls until the encounter
    # ends; failing by 15+ is catastrophic (flee or cower, GM's call).
    tracked = False
    if not success:
        tracked = _d.set_fear_penalty(guild, interaction.channel_id, c.name, fear_rank)
    embed = discord.Embed(
        title=f"😨 Fear Check: {c.name}",
        color=discord.Color.green() if success else discord.Color.dark_red(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    soh_str = f" +{soh_f}" if soh_f else ""
    roll_text = (
        f"Willpower ({result['rolled']}k{result['kept']}{wp_str}{bonus_str}{soh_str})"
        f" vs TN **{tn}** (Fear {fear_rank})"
    )
    if soh_notes:
        roll_text += "\n" + " · ".join(soh_notes)
    if void_line:
        roll_text += f"\n{void_line}"
    embed.add_field(name="Roll", value=roll_text, inline=False)
    embed.add_field(name="Dice", value=_d.format_dice(result["dice"]), inline=False)
    if success:
        verdict = "✅ **Resists the Fear!**"
    else:
        verdict = f"❌ **Fails!** -{fear_rank}k0 to all rolls until the encounter ends"
        verdict += " (tracked on the initiative list)." if tracked else " (not in an encounter here: DM tracks it)."
        if result["margin"] <= -15:
            verdict += "\n💥 **Catastrophic failure (15+):** overwhelmed - flees or cowers helplessly (GM's determination)."
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check honor
# ---------------------------------------------------------------------------

@check.command(
    name="honor",
    description="Honor Roll: roll Honor Rank dice, keep 1, vs a TN.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    tn="Target Number to resist.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
)
async def honor_roll(
    interaction: discord.Interaction,
    tn: app_commands.Range[int, 1, 100],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    hr = stats.honor_rank(c)
    result = combat.resolve_honor_roll(hr, tn, _d.engine, bonus=bonus)
    success = result["success"]
    embed = discord.Embed(
        title=f"⚖️ Honor Roll: {c.name}",
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
    embed.add_field(name="Dice", value=_d.format_dice(result["dice"]), inline=False)
    verdict = "✅ **Honor holds!**" if success else "❌ **Honor wavers.**"
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check poison
# ---------------------------------------------------------------------------

@check.command(
    name="poison",
    description="Poison resistance: Stamina vs TN (Strength x 5).",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    strength="Poison Strength 1-10 (TN = Strength x 5).",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    poison_name="Name of the poison (for display).",
)
async def poison_resist(
    interaction: discord.Interaction,
    strength: app_commands.Range[int, 1, 10],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    poison_name: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, "poison_resist", "stamina")
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    void_r, void_k, void_spent, void_line, _ = _try_spend_void(c, spend_void, skill_name="poison_resist")
    result = combat.resolve_poison_resist(c.stamina, strength, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k)
    if void_spent:
        _d.store.save(rec)
    success = result["success"]
    tn = result["tn"]
    title = f"☠️ Poison Resistance: {c.name}"
    if poison_name:
        title += f" vs {poison_name}"
    embed = discord.Embed(
        title=title,
        color=discord.Color.green() if success else discord.Color.dark_purple(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    roll_text = (
        f"Stamina ({result['rolled']}k{result['kept']}{wp_str}{bonus_str})"
        f" vs TN **{tn}** (Strength {strength})"
    )
    if void_line:
        roll_text += f"\n{void_line}"
    embed.add_field(name="Roll", value=roll_text, inline=False)
    embed.add_field(name="Dice", value=_d.format_dice(result["dice"]), inline=False)
    verdict = "✅ **Resists the poison!**" if success else "❌ **Succumbs!** Apply poison effects."
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    if adv_notes:
        embed.add_field(name="Advantages/Disadvantages", value="\n".join(adv_notes), inline=False)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check medicine
# ---------------------------------------------------------------------------

@check.command(
    name="medicine",
    description="Medicine/Intelligence check vs a TN (treat wounds, poison, disease).",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    tn="Target Number for the treatment.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Medicine 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="What is being treated (for display).",
)
async def medicine_check(
    interaction: discord.Interaction,
    tn: app_commands.Range[int, 1, 100],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    medicine_skill = c.skills.get("Medicine", 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, "Medicine", "intelligence")
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, "Medicine", emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, medicine_skill = _try_spend_void(
        c, spend_void, skill_name="Medicine", sk=medicine_skill, void_unskilled=void_unskilled,
    )
    result = combat.resolve_medicine_check(c.intelligence, medicine_skill, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    success = result["success"]
    title = "💊 Medicine Check"
    if reason:
        title += f": {reason}"
    embed = discord.Embed(
        title=f"{title}: {c.name}",
        color=discord.Color.green() if success else discord.Color.greyple(),
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    skill_label = f"Medicine {medicine_skill}" if medicine_skill > 0 else "Medicine (unskilled)"
    roll_text = (
        f"{skill_label}/Intelligence ({result['rolled']}k{result['kept']}"
        f"{wp_str}{bonus_str}) vs TN **{tn}**"
    )
    if void_line:
        roll_text += f"\n{void_line}"
    embed.add_field(name="Roll", value=roll_text, inline=False)
    embed.add_field(name="Dice", value=_d.format_dice(result["dice"]), inline=False)
    verdict = "✅ **Treatment successful!**" if success else "❌ **Treatment fails.**"
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    if adv_notes:
        embed.add_field(name="Advantages/Disadvantages", value="\n".join(adv_notes), inline=False)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check skill
# ---------------------------------------------------------------------------

@check.command(
    name="skill",
    description="Generic Skill/Trait check vs a TN. DM picks the trait and skill.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    trait="Trait for the roll (the kept dice).",
    skill="Skill name as on the sheet (e.g. Athletics).",
    tn="Target Number.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Skill 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label shown with the roll.",
    secret="Only you see the result.",
)
@app_commands.choices(trait=_CONTEST_TRAITS)
async def skill_check_cmd(
    interaction: discord.Interaction,
    trait: app_commands.Choice[str],
    skill: str,
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
    secret: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    tv = stats.trait_value(c, trait.value)
    sk = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, skill, trait.value)
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    tp_r, tp_notes = taint.social_roll_penalty(c, skill)
    adv_r += tp_r; adv_notes = adv_notes + tp_notes
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    emph, emph_err = _emphasis_for(c, skill, emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name=skill, sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(tv, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    skill_label = f"{skill} {sk}" if sk > 0 else f"{skill} (unskilled)"
    title = "\U0001f3af Skill Check" + (" \U0001f92b" if secret else "")
    if reason:
        title += f": {reason}"
    embed = _build_check_embed(title, c.name, skill_label, trait.name, result, wp, bonus, adv_notes=adv_notes, void_line=void_line)
    if not secret:
        _d.log_roll(interaction.channel_id, c.name, f"{skill}/{trait.name} vs TN {tn}", result["total"])
    await interaction.response.send_message(embed=embed, ephemeral=secret)


# ---------------------------------------------------------------------------
# /check cooperative
# ---------------------------------------------------------------------------

@check.command(
    name="cooperative",
    description="Cooperative check: helpers roll at TN+5, each success gives primary +1k0 (cap Void).",
)
@app_commands.describe(
    name="Primary character making the check.",
    trait="Trait for the roll (kept dice).",
    skill="Skill name (e.g. 'Athletics').",
    tn="Target Number for the primary check.",
    helpers="Helper names, comma-separated.",
    member="Another player's character [Fortune]",
    is_npc="Primary character is an NPC.",
    bonus="Flat bonus to the primary roll.",
    spend_void="Spend a Void Point for +1k1 on the primary roll.",
    void_unskilled="Void Point: treat Skill 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label shown with the roll.",
)
@app_commands.choices(trait=_CONTEST_TRAITS)
async def check_cooperative(
    interaction: discord.Interaction,
    name: str,
    trait: app_commands.Choice[str],
    skill: str,
    tn: app_commands.Range[int, 1, 200],
    helpers: str,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"No character found for **{name}**.", ephemeral=True)
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    tv = stats.trait_value(c, trait.value)
    sk = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    max_helpers = c.void_ring
    helper_names = [h.strip() for h in helpers.split(",") if h.strip()]
    if not helper_names:
        await interaction.response.send_message("Provide at least one helper name.", ephemeral=True)
        return
    helper_tn = tn + 5
    helper_lines: list[str] = []
    successes = 0
    for hname in helper_names:
        hrec = _d.resolve_duelist(guild, interaction.channel_id, hname, False, None)
        if hrec is None:
            hrec = _d.store.get_by_name(guild, _d.NPC_OWNER, hname)
        if hrec is None:
            helper_lines.append(f"❌ **{hname}**: not found")
            continue
        hc = hrec.character
        htv = stats.trait_value(hc, trait.value)
        hsk = hc.skills.get(skill, 0)
        hwp = stats.wound_penalty(hc)
        hresult = combat.resolve_skill_check(htv, hsk, helper_tn, _d.engine, bonus=hwp)
        mark = "✅" if hresult["success"] else "❌"
        helper_lines.append(
            f"{mark} **{hc.name}** rolled **{hresult['total']}** vs TN {helper_tn} "
            f"({hresult['rolled']}k{hresult['kept']})"
        )
        if hresult["success"]:
            successes += 1
    applied = min(successes, max_helpers)
    helper_rolled = applied
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, skill, trait.value)
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, skill, emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name=skill, sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(tv, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=helper_rolled + adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    result["rolled"] = tv + sk + helper_rolled + adv_r + void_r
    result["kept"] = tv + adv_k + void_k
    skill_label = f"{skill} {sk}" if sk > 0 else f"{skill} (unskilled)"
    title = "\U0001F91D Cooperative Check"
    if reason:
        title += f": {reason}"
    embed = discord.Embed(
        title=f"{title}: {c.name}",
        color=discord.Color.green() if result["success"] else discord.Color.greyple(),
    )
    embed.add_field(
        name="Helpers",
        value="\n".join(helper_lines) + f"\n**{applied}** of {len(helper_names)} succeeded "
              f"(cap {max_helpers} = Void Ring)",
        inline=False,
    )
    wp_str = f" {wp}" if wp else ""
    bonus_str = f" {bonus:+d}" if bonus else ""
    coop_str = f" +{helper_rolled}k0 assist" if helper_rolled else ""
    roll_text = (
        f"{skill_label}/{trait.name} ({result['rolled']}k{result['kept']}"
        f"{wp_str}{bonus_str}{coop_str}) vs TN **{tn}**"
    )
    if void_line:
        roll_text += f"\n{void_line}"
    embed.add_field(name="Primary Roll", value=roll_text, inline=False)
    embed.add_field(name="Dice", value=_d.format_dice(result["dice"]), inline=False)
    verdict = "✅ **Success!**" if result["success"] else "❌ **Failure.**"
    embed.add_field(
        name="Result",
        value=f"**{result['total']}** vs TN {tn}: {verdict} (margin {result['margin']:+d})",
        inline=False,
    )
    if adv_notes:
        embed.add_field(name="Advantages/Disadvantages", value="\n".join(adv_notes), inline=False)
    if void_spent:
        _d.store.save(rec)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check stealth
# ---------------------------------------------------------------------------

@check.command(
    name="stealth",
    description="Stealth/Agility check vs a TN.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    tn="Target Number.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Stealth 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label (e.g. 'sneaking past the guards').",
    secret="Only you see the result.",
)
async def stealth_check(
    interaction: discord.Interaction,
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
    secret: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    sk = c.skills.get("Stealth", 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, "Stealth", "agility")
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, "Stealth", emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name="Stealth", sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(c.agility, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    skill_label = f"Stealth {sk}" if sk > 0 else "Stealth (unskilled)"
    title = "🥷 Stealth Check" + (" 🤫" if secret else "")
    if reason:
        title += f": {reason}"
    embed = _build_check_embed(
        title, c.name, skill_label, "Agility", result, wp, bonus,
        success_text="✅ **Undetected!**",
        fail_text="❌ **Spotted!**",
        adv_notes=adv_notes,
        void_line=void_line,
    )
    await interaction.response.send_message(embed=embed, ephemeral=secret)


# ---------------------------------------------------------------------------
# /check investigate
# ---------------------------------------------------------------------------

@check.command(
    name="investigate",
    description="Investigation/Perception check vs a TN.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    tn="Target Number.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Investigation 0 as Rank 1.",
    reason="Label (e.g. 'searching the crime scene').",
    secret="Only you see the result.",
)
@app_commands.choices(emphasis=_INVESTIGATION_EMPHASIS)
async def investigate_check(
    interaction: discord.Interaction,
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    emphasis: app_commands.Choice[str] | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    reason: str | None = None,
    secret: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    sk = c.skills.get("Investigation", 0)
    wp = stats.wound_penalty(c)
    emp_name = emphasis.value if emphasis else None
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(
        c, "Investigation", "perception", emphasis=emp_name,
    )
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    inv_emph = combat.emphasis_match(c, "Investigation", emp_name)
    if inv_emph:
        adv_notes = adv_notes + [f"Emphasis ({inv_emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name="Investigation", sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(c.perception, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(inv_emph))
    if void_spent:
        _d.store.save(rec)
    has_emphasis = emp_name and emp_name in c.emphases.get("Investigation", [])
    skill_label = f"Investigation {sk}" if sk > 0 else "Investigation (unskilled)"
    if emp_name:
        skill_label += f" [{emp_name}]"
    title = "🔍 Investigation" + (" 🤫" if secret else "")
    if emp_name:
        title += f" ({emp_name})"
    if reason:
        title += f": {reason}"
    embed = _build_check_embed(title, c.name, skill_label, "Perception", result, wp, bonus, adv_notes=adv_notes, void_line=void_line)
    if has_emphasis:
        embed.set_footer(text=f"Has {emp_name} emphasis: reroll 1s once (DM adjudicates).")
    elif emp_name:
        embed.set_footer(text=f"No {emp_name} emphasis on sheet.")
    await interaction.response.send_message(embed=embed, ephemeral=secret)


# ---------------------------------------------------------------------------
# /check social
# ---------------------------------------------------------------------------

@check.command(
    name="social",
    description="Social skill check vs a TN. Auto-selects the correct trait.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    skill="Social skill (auto-selects the correct trait).",
    tn="Target Number.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Skill 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label (e.g. 'convincing the magistrate').",
)
@app_commands.choices(skill=_SOCIAL_SKILLS)
async def social_check(
    interaction: discord.Interaction,
    skill: app_commands.Choice[str],
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    trait_attr = _SOCIAL_TRAIT_MAP[skill.value]
    tv = stats.trait_value(c, trait_attr)
    sk = c.skills.get(skill.value, 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, skill.value, trait_attr)
    tp_r, tp_notes = taint.social_roll_penalty(c, skill.value)
    adv_r += tp_r; adv_notes = adv_notes + tp_notes
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, skill.value, emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name=skill.value, sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(tv, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    skill_label = f"{skill.value} {sk}" if sk > 0 else f"{skill.value} (unskilled)"
    trait_display = trait_attr.capitalize()
    title = "🗣️ Social Check"
    if reason:
        title += f": {reason}"
    embed = _build_check_embed(title, c.name, skill_label, trait_display, result, wp, bonus, adv_notes=adv_notes, void_line=void_line)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check craft
# ---------------------------------------------------------------------------

@check.command(
    name="craft",
    description="Artisan or Craft skill / Intelligence check vs a TN.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    skill="Skill as on the sheet (e.g. Craft: Weaponsmithing).",
    tn="Target Number.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Skill 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label (e.g. 'forging a katana').",
)
async def craft_check(
    interaction: discord.Interaction,
    skill: str,
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    sk = c.skills.get(skill, 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, skill, "intelligence")
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, skill, emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name=skill, sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(c.intelligence, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    skill_label = f"{skill} {sk}" if sk > 0 else f"{skill} (unskilled)"
    title = "🔨 Craft Check"
    if reason:
        title += f": {reason}"
    embed = _build_check_embed(title, c.name, skill_label, "Intelligence", result, wp, bonus, adv_notes=adv_notes, void_line=void_line)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check lore
# ---------------------------------------------------------------------------

@check.command(
    name="lore",
    description="Lore/Intelligence check vs a TN.",
)
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    specialty="Lore skill as on the sheet (e.g. Lore: Shadowlands).",
    tn="Target Number.",
    member="Another player's character [Fortune]",
    is_npc="The name is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Skill 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label (e.g. 'identifying the creature').",
)
async def lore_check(
    interaction: discord.Interaction,
    specialty: str,
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: app_commands.Range[int, -50, 50] = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    sk = c.skills.get(specialty, 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, specialty, "intelligence")
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, specialty, emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, sk = _try_spend_void(
        c, spend_void, skill_name=specialty, sk=sk, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(c.intelligence, sk, tn, _d.engine, bonus=bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    skill_label = f"{specialty} {sk}" if sk > 0 else f"{specialty} (unskilled)"
    title = "📚 Lore Check"
    if reason:
        title += f": {reason}"
    embed = _build_check_embed(title, c.name, skill_label, "Intelligence", result, wp, bonus, adv_notes=adv_notes, void_line=void_line)
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /check horsemanship
# ---------------------------------------------------------------------------

@check.command(name="horsemanship", description="Horsemanship/Agility check (mounted combat maneuver).")
@app_commands.describe(
    name="Character (default: yours; others or NPCs need Fortune).",
    tn="Target Number.",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus.",
    spend_void="Spend a Void Point for +1k1.",
    void_unskilled="Void Point: treat Horsemanship 0 as Rank 1.",
    emphasis="Emphasis on the sheet: rerolls 1s once.",
    reason="Label (e.g. 'charge').",
)
async def horsemanship_check(
    interaction: discord.Interaction,
    tn: app_commands.Range[int, 1, 200],
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: int = 0,
    spend_void: bool = False,
    void_unskilled: bool = False,
    emphasis: str | None = None,
    reason: str = "",
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    rec = await _resolve_roller(interaction, name, is_npc, member)
    if rec is None:
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    if spend_void and void_unskilled:
        await interaction.response.send_message("Cannot use both spend_void (+1k1) and void_unskilled (Skill 0→1) on the same roll.", ephemeral=True)
        return
    skill_rank = c.skills.get("Horsemanship", 0)
    wp = stats.wound_penalty(c)
    adv_r, adv_k, adv_f, adv_notes = advantage_effects.skill_check_modifiers(c, "Horsemanship", "agility")
    adv_r, adv_notes = _fear(interaction, c, adv_r, adv_notes)
    emph, emph_err = _emphasis_for(c, "Horsemanship", emphasis)
    if emph_err:
        await interaction.response.send_message(emph_err, ephemeral=True)
        return
    if emph:
        adv_notes = adv_notes + [f"Emphasis ({emph}): 1s rerolled once"]
    void_r, void_k, void_spent, void_line, skill_rank = _try_spend_void(
        c, spend_void, skill_name="Horsemanship", sk=skill_rank, void_unskilled=void_unskilled,
    )
    result = combat.resolve_skill_check(c.agility, skill_rank, tn, _d.engine, bonus + wp + adv_f, extra_rolled=adv_r + void_r, extra_kept=adv_k + void_k, emphasis=bool(emph))
    if void_spent:
        _d.store.save(rec)
    embed = _build_check_embed(
        reason or "Horsemanship Check", c.name, "Horsemanship", "Agility", result, wp, bonus,
        success_text="Maneuver succeeds!", fail_text="The rider falters!",
        adv_notes=adv_notes, void_line=void_line,
    )
    await interaction.response.send_message(embed=embed)
