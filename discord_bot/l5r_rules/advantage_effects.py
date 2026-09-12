"""Deterministic combat modifiers from Advantages & Disadvantages (GDD s45).

Auto-applied (12 effects across 10 entries):
  Large: +1k0 damage (large melee weapon)
  Hands of Stone: +0k1 unarmed damage
  Small: -1k0 melee damage
  Bad Eyesight: -1k1 ranged attack rolls
  Blind: -3k3 ranged attacks, -1k1 melee attacks, defender Armor TN override
  Strength of the Earth: wound penalties reduced by 3
  Low Pain Threshold: wound penalties increased by 5
  Permanent Wound: always at least Nicked wound level
  Touch of the Spirit Realms: Jigoku: +Taint Rank flat to attack rolls
  Touch of the Spirit Realms: Gaki-do: heal 5 Wounds on kill
  Seven Fortunes' Curse: Bishamon: -1k0 damage (Strength -1)
  Bishamon's Blessing: +1 extra raise for Increased Damage when 3+ declared

Reminder-only (not auto-applied):
  Quick (Initiative re-add needs Reactions Stage), Prodigy (school-skill
  detection not modelled), Sacred Weapons (weapon identity not tracked beyond
  name), Crab Hands (unskilled fallback: edge case), Blind movement penalty,
  Small movement penalty, Lame, Missing Limb, Weakness (trait-specific needs
  parameterised storage), Momoku/Consumed/Failure of Bushido (Void-spend
  restrictions need per-spend gating), Doubt (skill-specific needs parameterised
  storage), Magic Resistance (spell combat not modelled here).
"""

from __future__ import annotations

import math

from .character import Character


def _has_adv(c: Character, name: str) -> bool:
    name_lower = name.lower()
    return any(a.lower() == name_lower for a in c.advantages)


def _has_disadv(c: Character, name: str) -> bool:
    name_lower = name.lower()
    return any(d.lower() == name_lower for d in c.disadvantages)


def _has_adv_containing(c: Character, fragment: str) -> bool:
    frag = fragment.lower()
    return any(frag in a.lower() for a in c.advantages)


def _has_disadv_containing(c: Character, fragment: str) -> bool:
    frag = fragment.lower()
    return any(frag in d.lower() for d in c.disadvantages)


def attacker_damage(
    attacker: Character, weapon_profile: dict, weapon_name: str,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll."""
    rolled = kept = flat = 0
    notes: list[str] = []
    is_melee = weapon_profile.get("melee", True)
    wname = weapon_name.lower().strip()
    size = str(weapon_profile.get("size", "")).lower()

    if _has_adv(attacker, "Large") and is_melee and size == "large":
        rolled += 1
        notes.append("Large +1k0 damage (large melee weapon)")
    if _has_adv(attacker, "Hands of Stone") and wname == "unarmed":
        kept += 1
        notes.append("Hands of Stone +0k1 damage (unarmed)")
    if _has_disadv(attacker, "Small") and is_melee:
        rolled -= 1
        notes.append("Small -1k0 damage (melee)")
    if _has_disadv_containing(attacker, "bishamon") and _has_disadv_containing(attacker, "seven fortunes"):
        rolled -= 1
        notes.append("Bishamon's Curse -1k0 damage (Strength -1)")
    return rolled, kept, flat, notes


def attacker_attack_dice(
    attacker: Character, weapon_profile: dict,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the attack roll."""
    rolled = kept = flat = 0
    notes: list[str] = []
    is_melee = weapon_profile.get("melee", True)

    if _has_disadv(attacker, "Bad Eyesight") and not is_melee:
        rolled -= 1; kept -= 1
        notes.append("Bad Eyesight -1k1 (ranged attack)")
    if _has_disadv(attacker, "Blind"):
        if is_melee:
            rolled -= 1; kept -= 1
            notes.append("Blind -1k1 (melee attack)")
        else:
            rolled -= 3; kept -= 3
            notes.append("Blind -3k3 (ranged attack)")
    if _has_adv_containing(attacker, "jigoku") and _has_adv_containing(attacker, "touch of the spirit"):
        taint_rank = int(attacker.taint)
        if taint_rank > 0:
            flat += taint_rank
            notes.append(f"Touch of Jigoku +{taint_rank} attack (Taint Rank)")
    return rolled, kept, flat, notes


def attacker_wound_penalty_mod(attacker: Character) -> tuple[int, list[str]]:
    """(flat_bonus_modifier, notes) added to the attack roll's flat bonus to
    adjust the wound penalty's effect. Positive = less penalty (Strength of the
    Earth counteracts the negative wound penalty), negative = worse penalty
    (Low Pain Threshold deepens it)."""
    mod = 0
    notes: list[str] = []
    if _has_adv(attacker, "Strength of the Earth"):
        mod += 3
        notes.append("Strength of the Earth: wound penalties reduced by 3")
    if _has_disadv(attacker, "Low Pain Threshold"):
        mod -= 5
        notes.append("Low Pain Threshold: wound penalties increased by 5")
    return mod, notes


def defender_armor_tn_mod(defender: Character) -> tuple[int, list[str]]:
    """(modifier, notes) added to the defender's Armor TN base.
    Blind: base Armor TN = Reflexes + 5 instead of Reflexes x 5 + 5,
    so the modifier is -(Reflexes x 4)."""
    mod = 0
    notes: list[str] = []
    if _has_disadv(defender, "Blind"):
        mod -= defender.reflexes * 4
        notes.append(f"Blind: Armor TN base = Reflexes + 5 (−{defender.reflexes * 4})")
    return mod, notes


def increased_damage_bonus(
    attacker: Character, increased_damage_raises: int,
) -> tuple[int, list[str]]:
    """(extra_rolled_damage_dice, notes) from Bishamon's Blessing: when 3+
    raises are declared for Increased Damage, gain one additional raise worth
    of damage (+1k0)."""
    if (
        increased_damage_raises >= 3
        and _has_adv_containing(attacker, "bishamon")
        and _has_adv_containing(attacker, "seven fortunes")
    ):
        return 1, ["Bishamon's Blessing +1k0 damage (3+ Increased Damage raises)"]
    return 0, []


def post_kill_heal(attacker: Character) -> tuple[int, list[str]]:
    """(wounds_healed, notes) to apply to the attacker after killing a target.
    Touch of Gaki-do: heal 5 Wounds on kill."""
    if _has_adv_containing(attacker, "gaki-do") and _has_adv_containing(attacker, "touch of the spirit"):
        return 5, ["Touch of Gaki-do: heal 5 Wounds on kill"]
    return 0, []


def permanent_wound_floor(character: Character) -> tuple[bool, str]:
    """(True, note) if the character has Permanent Wound: their first wound
    rank is always considered full, meaning they are always at least Nicked."""
    if _has_disadv(character, "Permanent Wound"):
        return True, "Permanent Wound: always at least Nicked"
    return False, ""
