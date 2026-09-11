"""Deterministic combat modifiers from a character's KNOWN School Techniques
(GDD s29).

Unlike kata (one active at a time), a character carries every Technique their
School grants up to their School Rank — recorded on the sheet via `/school learn`
— and they are passive and always in force. So these effects STACK and are keyed
by technique name against `character.techniques`.

Only the small, verbatim-verified subset whose condition the single-shot
`/attack` (with the initiative tracker) can actually evaluate is auto-applied — a
modifier gated on stance, the attacker's weapon, an Initiative comparison, or
nothing at all. The hundreds of Techniques that turn on target type
("vs Shadowlands", "vs unaware"), being mounted, grapples, duels, per-attack
player choices, multi-opponent counts, or reactive triggers stay DM-adjudicated
(full text on the sheet via `/school view`). Per CLAUDE 'do not invent mechanics':
every value here is read verbatim from the s29 LOCKED text.

Initiative-comparison techniques apply only when BOTH combatants are in the
channel's `/combat` encounter (so the tracker knows their Initiative); otherwise
they fall through to DM adjudication.
"""

from __future__ import annotations

import math

from . import stats
from .character import Character

_SPEAR_POLEARM = frozenset({"spears", "polearms"})


def _known(character: Character) -> set[str]:
    return {t.lower().strip() for t in getattr(character, "techniques", [])}


def _skill(weapon_profile: dict) -> str:
    return str(weapon_profile.get("skill", "")).lower()


def _is_two_handed_melee(weapon_profile: dict) -> bool:
    return bool(weapon_profile.get("melee")) and str(weapon_profile.get("size", "")).lower() == "large"


def _is_bow(weapon_profile: dict) -> bool:
    return str(weapon_profile.get("skill", "")).lower() == "kyujutsu"


def _is_small(weapon_profile: dict) -> bool:
    return str(weapon_profile.get("size", "")).lower() == "small"


def attacker_attack_dice(
    attacker: Character, weapon_profile: dict, weapon_name: str, attacker_stance: str,
    atk_init: int | None = None, def_init: int | None = None,
) -> tuple[int, int, int, list[str]]:
    """(bonus_rolled, bonus_kept, flat_bonus, notes) added to the attack roll by
    the attacker's known Techniques."""
    known = _known(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    wname = weapon_name.lower().strip()
    if "torch's flame flickers" in known and attacker_stance == "attack":
        rolled += 1
        notes.append("Torch's Flame Flickers +1k0 attack (Attack Stance)")
    if "the force of honor" in known and attacker_stance == "attack":
        rolled += 1
        notes.append("The Force of Honor +1k0 attack (Attack Stance)")
    if "the way of the crane" in known and attacker_stance == "center":
        rolled += 1
        kept += 1
        flat += max(1, attacker.school_rank)
        notes.append(f"The Way of the Crane +1k1 +{max(1, attacker.school_rank)} attack (Center Stance)")
    if "always be ready" in known and _is_bow(weapon_profile):
        rolled += 1
        notes.append("Always Be Ready +1k0 attack (bow)")
    if "the subtle sting" in known and _is_small(weapon_profile):
        rolled += 2
        notes.append("The Subtle Sting +2k0 attack (Small weapon)")
    if "the togashi tattooed order" in known and wname == "unarmed":
        rolled += 1
        kept += 1
        notes.append("Togashi Tattooed Order +1k1 attack (unarmed)")
    if "speed of lightning" in known and atk_init is not None and def_init is not None and def_init < atk_init:
        rolled += 2
        notes.append("Speed of Lightning +2k0 attack (target lower Initiative)")
    if "temper steel with honor" in known and wname in ("jitte", "sasumata"):
        rolled += 1
        notes.append("Temper Steel With Honor +1k0 attack (jitte/sasumata)")
    if "the way of magari-yarijutsu" in known and _skill(weapon_profile) in _SPEAR_POLEARM:
        rolled += 1
        notes.append("The Way of Magari-Yarijutsu +1k0 attack (spear/polearm)")
    return rolled, kept, flat, notes


def attacker_damage(attacker: Character, weapon_profile: dict, weapon_name: str) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll from the
    attacker's known Techniques."""
    known = _known(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    skill = str(weapon_profile.get("skill", "")).lower()
    wname = weapon_name.lower().strip()
    if "the way of the crab" in known and skill == "heavy weapons":
        rolled += 1
        notes.append("The Way of the Crab +1k0 damage (Heavy Weapons)")
    if "the way of the unicorn" in known and (wname == "scimitar" or _is_two_handed_melee(weapon_profile)):
        rolled += 1
        notes.append("The Way of the Unicorn +1k0 damage (scimitar / two-handed)")
    if "the arrow knows the way" in known and _is_bow(weapon_profile):
        rolled += 2
        notes.append("The Arrow Knows the Way +2k0 damage (bow)")
    if "the togashi tattooed order" in known and wname == "unarmed":
        rolled += 1
        kept += 1
        notes.append("Togashi Tattooed Order +1k1 damage (unarmed)")
    if "the hand of thunder" in known and wname == "unarmed":
        kept += 1
        notes.append("The Hand of Thunder +0k1 damage (unarmed)")
    if "the lion's roar" in known:
        hr = stats.honor_rank(attacker)
        flat += hr
        notes.append(f"The Lion's Roar +{hr} damage (Honor Rank)")
    if "the face of justice" in known and weapon_profile.get("melee"):
        rolled += 1
        notes.append("The Face of Justice +1k0 damage (melee)")
    return rolled, kept, flat, notes


def attacker_reduction_ignored(attacker: Character, weapon_profile: dict) -> tuple[int, list[str]]:
    """Amount of the target's Reduction ignored by the attacker's known Techniques."""
    known = _known(attacker)
    ignore = 0
    notes: list[str] = []
    if "strike like the lion" in known and _skill(weapon_profile) in _SPEAR_POLEARM:
        v = math.ceil(stats.honor_rank(attacker) / 2)
        ignore += v
        notes.append(f"Strike Like the Lion ignores {v} Reduction (spear/polearm, ½ Honor Rank)")
    return ignore, notes


def defender_armor_tn_bonus(
    defender: Character, defender_stance: str,
    atk_init: int | None = None, def_init: int | None = None,
) -> tuple[int, list[str]]:
    """(Armor TN bonus, notes) from the DEFENDER's known Techniques. `atk_init` is
    the attacker's Initiative, `def_init` the defender's (both None if untracked)."""
    known = _known(defender)
    bonus = 0
    notes: list[str] = []
    if "drawing the void" in known and defender_stance == "center":
        bonus += 10
        notes.append("Drawing the Void +10 Armor TN (Center Stance)")
    if "kitsuki's method" in known:
        bonus += defender.perception
        notes.append(f"Kitsuki's Method +{defender.perception} Armor TN (Perception)")
    if "harmony" in known:
        v = stats.ring_value(defender, "void")
        bonus += v
        notes.append(f"Harmony +{v} Armor TN (Void Rank)")
    attacker_lower = atk_init is not None and def_init is not None and atk_init < def_init
    if "the way of the scorpion" in known and attacker_lower:
        bonus += 5
        notes.append("The Way of the Scorpion +5 Armor TN (attacker lower Initiative)")
    if "wing of thunder" in known and attacker_lower:
        v = defender.reflexes + max(1, defender.school_rank)
        bonus += v
        notes.append(f"Wing of Thunder +{v} Armor TN (attacker lower Initiative)")
    if "temper steel with honor" in known:
        v = stats.ring_value(defender, "air")
        bonus += v
        notes.append(f"Temper Steel With Honor +{v} Armor TN (Air Ring)")
    if "way of the dragon" in known and \
            defender.equipped_weapon.lower().strip() == "katana" and \
            defender.off_hand_weapon.lower().strip() == "wakizashi":
        v = max(1, defender.school_rank)
        bonus += v
        notes.append(f"Way of the Dragon +{v} Armor TN (daishō)")
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
