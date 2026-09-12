"""Deterministic combat modifiers from a character's ACTIVE kiho (GDD s38).

Only kiho whose effect the bot can compute faithfully from the sheet are
auto-applied here: passive modifiers gated on the active kiho list, the
equipped weapon, and character stats.

Auto-applied (6 effects across 6 kiho):
  Soul of the Four Winds: Armor TN += Insight Rank + Air Ring (defender)
  Musubi: Armor TN += Water Ring + Staves Skill Rank (defender, staff equipped)
  Embrace the Stone: Reduction += Earth Ring x 2 (defender)
  Partaking the Waters: Reduction += Water Ring (defender)
  Grasp the Earth Dragon: wound penalties reduced by Earth Ring (attacker)
  Air Fist: unarmed damage flat -Air Ring (attacker; cost of Initiative boost)

Everything else stays DM-adjudicated: atemi-delivered effects, reactive
abilities, duration-tracked debuffs, cumulative tracking (Rising Mountain),
action-economy changes (Dance of the Flames), and non-combat effects.
"""

from __future__ import annotations

from . import combat
from . import stats
from .character import Character


AUTO_KIHO: frozenset[str] = frozenset({
    "soul of the four winds",
    "musubi",
    "embrace the stone",
    "partaking the waters",
    "grasp the earth dragon",
    "air fist",
})


def is_auto(name: str) -> bool:
    return (name or "").lower().strip() in AUTO_KIHO


def _active_kiho(c: Character) -> list[str]:
    return [k.lower().strip() for k in (getattr(c, "active_kiho", None) or [])]


def defender_armor_tn_bonus(defender: Character) -> tuple[int, list[str]]:
    """(bonus, notes) added to the defender's Armor TN from active kiho."""
    active = _active_kiho(defender)
    bonus = 0
    notes: list[str] = []
    if "soul of the four winds" in active:
        ir = stats.insight_rank(defender)
        air = stats.ring_value(defender, "air")
        v = ir + air
        bonus += v
        notes.append(f"Soul of the Four Winds +{v} Armor TN (Insight Rank {ir} + Air {air})")
    if "musubi" in active:
        eq = (defender.equipped_weapon or "").strip()
        if eq:
            wp = combat.get_weapon_profile(eq)
            if str(wp.get("skill", "")).lower() == "staves":
                water = stats.ring_value(defender, "water")
                staves_rank = defender.skills.get("Staves", defender.skills.get("staves", 0))
                v = water + staves_rank
                bonus += v
                notes.append(f"Musubi +{v} Armor TN (Water {water} + Staves {staves_rank})")
    return bonus, notes


def defender_reduction_bonus(defender: Character) -> tuple[int, list[str]]:
    """(extra Reduction, notes) from the defender's active kiho."""
    active = _active_kiho(defender)
    bonus = 0
    notes: list[str] = []
    if "embrace the stone" in active:
        v = stats.ring_value(defender, "earth") * 2
        bonus += v
        notes.append(f"Embrace the Stone +{v} Reduction (Earth {stats.ring_value(defender, 'earth')} x2)")
    if "partaking the waters" in active:
        v = stats.ring_value(defender, "water")
        bonus += v
        notes.append(f"Partaking the Waters +{v} Reduction (Water Ring)")
    return bonus, notes


def attacker_wound_penalty_mod(attacker: Character) -> tuple[int, list[str]]:
    """(flat_bonus_modifier, notes) to counteract wound penalties.
    Grasp the Earth Dragon: wound penalties reduced by Earth Ring."""
    active = _active_kiho(attacker)
    if "grasp the earth dragon" in active:
        v = stats.ring_value(attacker, "earth")
        return v, [f"Grasp the Earth Dragon: wound penalties reduced by {v} (Earth Ring)"]
    return 0, []


def attacker_damage(
    attacker: Character, weapon_name: str,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll.
    Air Fist: unarmed damage reduced by Air Ring flat (cost of the +5
    Initiative boost; only while making unarmed attacks)."""
    active = _active_kiho(attacker)
    if "air fist" in active and weapon_name.lower().strip() == "unarmed":
        v = stats.ring_value(attacker, "air")
        return 0, 0, -v, [f"Air Fist −{v} damage (unarmed; tradeoff for +5 Initiative)"]
    return 0, 0, 0, []
