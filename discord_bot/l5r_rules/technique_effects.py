"""Deterministic combat modifiers from a character's KNOWN School Techniques
(GDD s29).

Unlike kata (one active at a time), a character carries every Technique their
School grants up to their School Rank: recorded on the sheet via `/school learn`
:  and they are passive and always in force. So these effects STACK and are keyed
by technique name against `character.techniques`.

This module is the COMPLETE auto-apply set: it wires every s29 Technique whose
effect the single-shot `/attack` (with the initiative tracker and `/sheet wield`)
can evaluate deterministically: a modifier gated only on stance, the weapon,
armour worn, an Initiative comparison, an Honor comparison, or a trait scalar.
The remaining ~600 Techniques turn on things the bot has no way to know (target
type: "vs Shadowlands / unaware", mounted, duels, grapples, terrain, multiple
opponents, allies), are reactive/Void-gated/"once per X", need player choice, or
need systems the bot does not model (spells, tattoos, mass battle, conditions,
kiho). Those stay DM-adjudicated: their full text is on the sheet via
`/school view`. Per CLAUDE 'do not invent mechanics': every value here is read
verbatim from the s29 LOCKED text; nothing is auto-applied on a condition the
engine cannot actually check.

Initiative- and Honor-comparison techniques apply only when the needed data is
available (both combatants in the `/combat` encounter; the attacker passed in);
otherwise they fall through to DM adjudication.
"""

from __future__ import annotations

import math

from . import stats
from .character import Character

_SPEAR_POLEARM = frozenset({"spears", "polearms"})
_IGNORE_ALL = 999  # sentinel: reduce the target's Reduction to zero


def _known(character: Character) -> set[str]:
    return {t.lower().strip() for t in getattr(character, "techniques", [])}


def _skill(weapon_profile: dict) -> str:
    return str(weapon_profile.get("skill", "")).lower()


def _is_two_handed_melee(weapon_profile: dict) -> bool:
    return bool(weapon_profile.get("melee")) and str(weapon_profile.get("size", "")).lower() == "large"


def _is_bow(weapon_profile: dict) -> bool:
    return _skill(weapon_profile) == "kyujutsu"


def _is_small(weapon_profile: dict) -> bool:
    return str(weapon_profile.get("size", "")).lower() == "small"


def _no_armor(character: Character) -> bool:
    return not (getattr(character, "armor_name", "") or "").strip()


def attacker_attack_dice(
    attacker: Character, weapon_profile: dict, weapon_name: str, attacker_stance: str,
    atk_init: int | None = None, def_init: int | None = None,
) -> tuple[int, int, int, list[str]]:
    """(bonus_rolled, bonus_kept, flat_bonus, notes) added to the attack roll."""
    known = _known(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    wname = weapon_name.lower().strip()
    skill = _skill(weapon_profile)
    target_lower = atk_init is not None and def_init is not None and def_init < atk_init

    if "torch's flame flickers" in known and attacker_stance == "attack":
        rolled += 1; notes.append("Torch's Flame Flickers +1k0 attack (Attack Stance)")
    if "the force of honor" in known and attacker_stance == "attack":
        rolled += 1; notes.append("The Force of Honor +1k0 attack (Attack Stance)")
    if "the way of the crane" in known and attacker_stance == "center":
        sr = max(1, attacker.school_rank)
        rolled += 1; kept += 1; flat += sr
        notes.append(f"The Way of the Crane +1k1 +{sr} attack (Center Stance)")
    if "always be ready" in known and _is_bow(weapon_profile):
        rolled += 1; notes.append("Always Be Ready +1k0 attack (bow)")
    if "the subtle sting" in known and _is_small(weapon_profile):
        rolled += 2; notes.append("The Subtle Sting +2k0 attack (Small weapon)")
    if "the togashi tattooed order" in known and wname == "unarmed":
        rolled += 1; kept += 1; notes.append("Togashi Tattooed Order +1k1 attack (unarmed)")
    if "temper steel with honor" in known and wname in ("jitte", "sasumata"):
        rolled += 1; notes.append("Temper Steel With Honor +1k0 attack (jitte/sasumata)")
    if "the way of magari-yarijutsu" in known and skill in _SPEAR_POLEARM:
        rolled += 1; notes.append("The Way of Magari-Yarijutsu +1k0 attack (spear/polearm)")
    if "to defend unto death" in known:
        v = stats.honor_rank(attacker) // 2
        if v:
            flat += v; notes.append(f"To Defend Unto Death +{v} attack (½ Honor Rank)")
    if "matsu's courage" in known:
        wp = stats.wound_penalty(attacker)  # <= 0
        cap = stats.honor_rank(attacker) * (2 if attacker_stance == "full_attack" else 1)
        recovered = min(cap, -wp)
        if recovered:
            flat += recovered; notes.append(f"Matsu's Courage +{recovered} attack (ignore Wound penalty)")
    if "speed of lightning" in known and target_lower:
        rolled += 2; notes.append("Speed of Lightning +2k0 attack (target lower Initiative)")
    if "fast and furious" in known and target_lower:
        rolled += 2; kept += 2; notes.append("Fast and Furious +2k2 attack (target lower Initiative)")
    return rolled, kept, flat, notes


def attacker_trait_override(attacker: Character, weapon_profile: dict) -> tuple[int | None, str, str]:
    """(trait_value, trait_name, note) replacing the attack roll's Trait, or
    (None, '', '') if none applies. Falcon's Strike: use Perception instead of
    Reflexes for ranged (bow) attack rolls."""
    known = _known(attacker)
    if "spotting the prey" in known and _is_bow(weapon_profile):
        return attacker.perception, "Perception", "Spotting the Prey: Perception replaces Reflexes (bow)"
    return None, "", ""


def attacker_damage(attacker: Character, weapon_profile: dict, weapon_name: str) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll."""
    known = _known(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    skill = _skill(weapon_profile)
    wname = weapon_name.lower().strip()
    melee = bool(weapon_profile.get("melee"))

    if "the way of the crab" in known and skill == "heavy weapons":
        rolled += 1; notes.append("The Way of the Crab +1k0 damage (Heavy Weapons)")
    if "the way of the unicorn" in known and (wname == "scimitar" or _is_two_handed_melee(weapon_profile)):
        rolled += 1; notes.append("The Way of the Unicorn +1k0 damage (scimitar / two-handed)")
    if "the arrow knows the way" in known and _is_bow(weapon_profile):
        rolled += 2; notes.append("The Arrow Knows the Way +2k0 damage (bow)")
    if "the togashi tattooed order" in known and wname == "unarmed":
        rolled += 1; kept += 1; notes.append("Togashi Tattooed Order +1k1 damage (unarmed)")
    if "the hand of thunder" in known and wname == "unarmed":
        kept += 1; notes.append("The Hand of Thunder +0k1 damage (unarmed)")
    if "the lion's roar" in known:
        hr = stats.honor_rank(attacker); flat += hr
        notes.append(f"The Lion's Roar +{hr} damage (Honor Rank)")
    if "the face of justice" in known and melee:
        rolled += 1; notes.append("The Face of Justice +1k0 damage (melee)")
    if "strength of the forest" in known and melee:
        flat += attacker.stamina
        notes.append(f"Strength of the Forest +{attacker.stamina} damage (Stamina, melee)")
    if "aligned with the elements" in known and skill == "kenjutsu" and _no_armor(attacker):
        rolled += 1; notes.append("Aligned With the Elements +1k0 damage (sword, no armour)")
    return rolled, kept, flat, notes


def attacker_reduction_ignored(attacker: Character, weapon_profile: dict, weapon_name: str = "") -> tuple[int, list[str]]:
    """Amount of the target's Reduction ignored by the attacker's Techniques."""
    known = _known(attacker)
    ignore = 0
    notes: list[str] = []
    wname = weapon_name.lower().strip()
    if "strike like the lion" in known and _skill(weapon_profile) in _SPEAR_POLEARM:
        v = math.ceil(stats.honor_rank(attacker) / 2)
        ignore += v; notes.append(f"Strike Like the Lion ignores {v} Reduction (spear/polearm, ½ Honor Rank)")
    if "harmony and precision" in known and wname in ("katana", "wakizashi"):
        ignore = _IGNORE_ALL; notes.append("Harmony and Precision ignores all Reduction (katana/wakizashi)")
    if "crushing blow" in known and wname == "unarmed":
        ignore += 1; notes.append("Crushing Blow ignores 1 Reduction (unarmed)")
    return ignore, notes


def defender_armor_tn_bonus(
    defender: Character, defender_stance: str,
    atk_init: int | None = None, def_init: int | None = None,
    attacker: Character | None = None,
) -> tuple[int, list[str]]:
    """(Armor TN bonus, notes) from the DEFENDER's known Techniques."""
    known = _known(defender)
    bonus = 0
    notes: list[str] = []
    attacker_lower_init = atk_init is not None and def_init is not None and atk_init < def_init

    if "drawing the void" in known and defender_stance == "center":
        bonus += 10; notes.append("Drawing the Void +10 Armor TN (Center Stance)")
    if "the fury of matsu" in known and defender_stance == "full_attack":
        bonus += 10; notes.append("The Fury of Matsu +10 Armor TN (Full Attack Stance)")
    if "tamedaore's secret" in known and defender_stance == "center":
        v = 2 * stats.ring_value(defender, "void")
        bonus += v; notes.append(f"Tamedaore's Secret +{v} Armor TN (Center, 2×Void)")
    if "kitsuki's method" in known:
        bonus += defender.perception; notes.append(f"Kitsuki's Method +{defender.perception} Armor TN (Perception)")
    if "harmony" in known:
        v = stats.ring_value(defender, "void")
        bonus += v; notes.append(f"Harmony +{v} Armor TN (Void Rank)")
    if "temper steel with honor" in known:
        v = stats.ring_value(defender, "air")
        bonus += v; notes.append(f"Temper Steel With Honor +{v} Armor TN (Air Ring)")
    if "way of the dragon" in known and \
            defender.equipped_weapon.lower().strip() == "katana" and \
            defender.off_hand_weapon.lower().strip() == "wakizashi":
        v = max(1, defender.school_rank)
        bonus += v; notes.append(f"Way of the Dragon +{v} Armor TN (daishō)")
    if "the way of the scorpion" in known and attacker_lower_init:
        bonus += 5; notes.append("The Way of the Scorpion +5 Armor TN (attacker lower Initiative)")
    if "wing of thunder" in known and attacker_lower_init:
        v = defender.reflexes + max(1, defender.school_rank)
        bonus += v; notes.append(f"Wing of Thunder +{v} Armor TN (attacker lower Initiative)")
    if "purity of chi" in known and attacker is not None and \
            stats.honor_rank(attacker) < stats.honor_rank(defender):
        bonus += 5; notes.append("Purity of Chi +5 Armor TN (attacker lower Honor)")
    return bonus, notes


def defender_reduction_bonus(defender: Character) -> tuple[int, list[str]]:
    """(extra Reduction, notes) from the DEFENDER's known Techniques."""
    known = _known(defender)
    bonus = 0
    notes: list[str] = []
    if "the mountain does not move" in known:
        v = stats.ring_value(defender, "earth")
        bonus += v; notes.append(f"The Mountain Does Not Move +{v} Reduction (Earth Ring)")
    if "hida's strength" in known:
        bonus += 8; notes.append("Hida's Strength +8 Reduction")
    if "honor is my shield" in known:
        v = math.ceil(stats.honor_rank(defender) / 2)
        bonus += v; notes.append(f"Honor Is My Shield +{v} Reduction (½ Honor Rank)")
    if "aligned with the elements" in known and \
            defender.equipped_weapon.lower().strip() in ("katana", "wakizashi", "no_dachi", "bokken", "ninja_to", "parangu", "scimitar", "shinai") and \
            _no_armor(defender):
        v = max(1, defender.school_rank) + 2
        bonus += v; notes.append(f"Aligned With the Elements +{v} Reduction (sword, no armour)")
    return bonus, notes
