"""Deterministic combat modifiers from a character's ACTIVE kata (GDD s30).

Only the kata whose effect the bot's single-shot `/attack` can compute
faithfully are auto-applied here:
  - stance-conditional Armor TN bonuses (defender side), and
  - unconditional / weapon-conditional attack- and damage-roll modifiers
    (attacker side)
that depend solely on the sheet, the chosen stance, the maneuver, and the
weapon profile — all of which `/attack` already knows.

Everything else in s30 is deliberately NOT auto-applied and stays DM-adjudicated:
  - rate-limited effects ("once per Turn/Round") — the stateless `/attack` has
    no round/turn tracking, so applying them every swing would change the rule;
  - player-choice tradeoffs ("reduce Armor TN by *up to* Earth Ring …");
  - Initiative, movement, mount, ally, guard and other off-`/attack` effects.
The caller surfaces those as a reminder (see `active_kata_reminder`).

Per CLAUDE 'do not invent mechanics': every value below is read verbatim from
the s30 LOCKED text — no thresholds or defaults are invented. Only a PC sheet
carries an `active_kata`; NPCs/creatures simply have none unless a DM sets one.
"""

from __future__ import annotations

from . import stats
from . import kata as kata_mod
from .character import Character

# Lowercased names of the kata whose effect is auto-applied in combat.
AUTO_KATA: frozenset[str] = frozenset({
    "striking as air",         # Defense Stance -> Armor TN += Air Ring
    "reckless abandon style",  # Full Attack Stance -> Armor TN += Fire Ring
    "striking as void",        # Center Stance -> Armor TN += Void Ring
    "lee of the stone",        # Defense (/Full Defense) -> Armor TN += Earth Ring
    "north wind style",        # Increased Damage Maneuver -> attack total += Air Ring
    "south wind style",        # Called Shot/Knockdown Maneuver -> attack total += Air Ring
    "waves upon the breakers",  # weapon w/ 3+ Skill Ranks -> damage +1k0
    "son of storms",           # Small melee weapon -> opponent Reduction -1
})


def is_auto(name: str) -> bool:
    """True if `name` is a kata whose combat effect this module auto-applies."""
    return (name or "").lower().strip() in AUTO_KATA


def _active(character: Character) -> str:
    return (getattr(character, "active_kata", "") or "").lower().strip()


def defender_armor_tn_bonus(defender: Character, defender_stance: str) -> tuple[int, str]:
    """Armor TN added by the DEFENDER's active kata for their current stance.

    Returns (bonus, note). Note is a short human-readable tag, "" when nothing
    applies. Stance keys match the bot: attack / full_attack / defense / center.
    (The bot has no separate Full Defense stance, so Lee of the Stone's
    Full-Defense branch is unreachable here — Defense is honoured.)
    """
    k = _active(defender)
    if not k:
        return 0, ""
    if k == "striking as air" and defender_stance == "defense":
        v = stats.ring_value(defender, "air")
        return v, f"Striking as Air +{v} Armor TN (Defense)"
    if k == "reckless abandon style" and defender_stance == "full_attack":
        v = stats.ring_value(defender, "fire")
        return v, f"Reckless Abandon +{v} Armor TN (Full Attack)"
    if k == "striking as void" and defender_stance == "center":
        v = stats.ring_value(defender, "void")
        return v, f"Striking as Void +{v} Armor TN (Center)"
    if k == "lee of the stone" and defender_stance == "defense":
        v = stats.ring_value(defender, "earth")
        return v, f"Lee of the Stone +{v} Armor TN (Defense)"
    return 0, ""


def attacker_roll_flat_bonus(attacker: Character, maneuver: str, increased_damage: int) -> tuple[int, str]:
    """Flat bonus added to the ATTACKER's attack-roll total by their active kata.

    North Wind (Increased Damage maneuver) and South Wind (Knockdown; Called
    Shot isn't modelled) each add Air Ring to the attack total (s30).
    """
    k = _active(attacker)
    if not k:
        return 0, ""
    if k == "north wind style" and increased_damage > 0:
        v = stats.ring_value(attacker, "air")
        return v, f"North Wind +{v} to attack (Increased Damage)"
    if k == "south wind style" and maneuver == "knockdown":
        v = stats.ring_value(attacker, "air")
        return v, f"South Wind +{v} to attack (Knockdown)"
    return 0, ""


def attacker_damage_rolled_bonus(attacker: Character, weapon_profile: dict) -> tuple[int, str]:
    """Extra ROLLED damage dice from the attacker's active kata.

    Waves upon the Breakers: while wielding a weapon in which you have at least
    three Skill Ranks, damage is increased by +1k0 (s30) -> +1 rolled die.
    """
    if _active(attacker) == "waves upon the breakers":
        skill = weapon_profile.get("skill", "Kenjutsu")
        if attacker.skills.get(skill, 0) >= 3:
            return 1, "Waves upon the Breakers +1k0 damage"
    return 0, ""


def attacker_reduction_ignored(attacker: Character, weapon_profile: dict) -> tuple[int, str]:
    """Amount of the target's Reduction ignored by the attacker's active kata.

    Son of Storms: when attacking with a Small melee weapon, any Reduction an
    opponent possesses is decreased by 1 (s30).
    """
    if _active(attacker) == "son of storms":
        if weapon_profile.get("melee") and str(weapon_profile.get("size", "")).lower() == "small":
            return 1, "Son of Storms −1 target Reduction"
    return 0, ""


def active_kata_reminder(character: Character) -> str:
    """Effect text of an active kata the bot does NOT auto-apply, for the DM.

    Returns "" when there is no active kata, or when the active kata is one this
    module handles automatically (an auto kata whose condition simply isn't met
    this attack correctly does nothing, so it needs no reminder).
    """
    name = (getattr(character, "active_kata", "") or "").strip()
    if not name or is_auto(name):
        return ""
    rec = kata_mod.get(name)
    return rec["effect"] if rec else ""
