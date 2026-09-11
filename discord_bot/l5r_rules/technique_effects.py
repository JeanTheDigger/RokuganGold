"""Deterministic combat modifiers from a character's KNOWN School Techniques
(GDD s29).

Unlike kata (one active at a time), a character carries every Technique their
School grants up to their School Rank — recorded on the sheet via `/school learn`
— and they are passive and always in force. So these effects STACK and are keyed
by technique name against `character.techniques`.

Only the small, verbatim-verified subset whose condition the single-shot
`/attack` can actually evaluate is auto-applied — a modifier gated on stance, the
attacker's weapon, or nothing at all. The hundreds of Techniques that turn on
target type ("vs Shadowlands", "vs unaware"), Initiative comparisons, grapples,
duels, per-attack player choices, or reactive triggers stay DM-adjudicated (their
full text is on the sheet via `/school view`). Per CLAUDE 'do not invent
mechanics': every value here is read verbatim from the s29 LOCKED text.

This is tranche 1 — the list is deliberately extensible.
"""

from __future__ import annotations

from . import stats
from .character import Character


def _known(character: Character) -> set[str]:
    return {t.lower().strip() for t in getattr(character, "techniques", [])}


def _is_two_handed_melee(weapon_profile: dict) -> bool:
    return bool(weapon_profile.get("melee")) and str(weapon_profile.get("size", "")).lower() == "large"


def attacker_attack_dice(attacker: Character, weapon_profile: dict, attacker_stance: str) -> tuple[int, int, int, list[str]]:
    """(bonus_rolled, bonus_kept, flat_bonus, notes) added to the attack roll by
    the attacker's known Techniques."""
    known = _known(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    if "torch's flame flickers" in known and attacker_stance == "attack":
        rolled += 1
        notes.append("Torch's Flame Flickers +1k0 attack (Attack Stance)")
    if "the way of the crane" in known and attacker_stance == "center":
        # "+1k1 plus School Rank to attack … rolls in Center Stance"
        rolled += 1
        kept += 1
        flat += max(1, attacker.school_rank)
        notes.append(f"The Way of the Crane +1k1 +{max(1, attacker.school_rank)} attack (Center Stance)")
    return rolled, kept, flat, notes


def attacker_damage_rolled(attacker: Character, weapon_profile: dict, weapon_name: str = "") -> tuple[int, list[str]]:
    """(extra rolled damage dice, notes) from the attacker's known Techniques."""
    known = _known(attacker)
    rolled = 0
    notes: list[str] = []
    skill = str(weapon_profile.get("skill", "")).lower()
    if "the way of the crab" in known and skill == "heavy weapons":
        rolled += 1
        notes.append("The Way of the Crab +1k0 damage (Heavy Weapons)")
    if "the way of the unicorn" in known:
        # "+1k0 damage … using a scimitar, or using a two-handed melee weapon
        #  (bonuses do not stack)" — mounted is not modelled.
        if weapon_name.lower().strip() == "scimitar" or _is_two_handed_melee(weapon_profile):
            rolled += 1
            notes.append("The Way of the Unicorn +1k0 damage (scimitar / two-handed)")
    return rolled, notes


def defender_armor_tn_bonus(defender: Character, defender_stance: str) -> tuple[int, list[str]]:
    """(Armor TN bonus, notes) from the DEFENDER's known Techniques."""
    known = _known(defender)
    bonus = 0
    notes: list[str] = []
    if "drawing the void" in known and defender_stance == "center":
        bonus += 10
        notes.append("Drawing the Void +10 Armor TN (Center Stance)")
    return bonus, notes


def defender_reduction_bonus(defender: Character) -> tuple[int, list[str]]:
    """(extra Reduction, notes) from the DEFENDER's known Techniques."""
    known = _known(defender)
    bonus = 0
    notes: list[str] = []
    if "the mountain does not move" in known:
        v = stats.ring_value(defender, "earth")
        bonus += v
        notes.append(f"The Mountain Does Not Move +{v} Reduction (Earth Ring)")
    return bonus, notes
