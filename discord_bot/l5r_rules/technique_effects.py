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

Initiative-, Honor-, and Fire-Ring-comparison techniques apply only when the
needed data is available (both combatants in the `/combat` encounter; both
attacker and defender Characters passed in); otherwise they fall through to DM
adjudication. Tengoku's Fist "Monk property" gate covers only the explicitly
named weapons (unarmed, bisento, bo); other Monk-property weapons fall through.
"""

from __future__ import annotations

import math

from . import enums, stats
from .character import Character

_SPEAR_POLEARM = frozenset({"spears", "polearms"})
_IGNORE_ALL = 999  # sentinel: reduce the target's Reduction to zero
_PEASANT_WEAPONS = frozenset({
    "bo", "jo", "nunchaku", "tonfa", "machi_kanshisha", "sang_kauw",
    "kusarigama", "kyoketsu_shogi", "manrikikusari",
    "kama", "sai", "jitte", "ono",
})
_SAMURAI_WEAPONS = frozenset({
    "katana", "wakizashi", "bokken", "shinai", "naginata",
})
_NINJA_WEAPONS = frozenset({
    "ninja_to", "shuriken", "tsubute", "blowgun",
})
_KNIFE_WEAPONS = frozenset({
    "tanto", "aiguchi", "sai", "jitte", "kama",
})
_MONK_WEAPONS = frozenset({
    "unarmed", "bisento", "bo",
})
_KSHATRIYA_WEAPON_SKILLS = frozenset({
    "kenjutsu", "jiujutsu", "spears", "kyujutsu",
})


def _known(character: Character) -> set[str]:
    raw = getattr(character, "techniques", [])
    result: set[str] = set()
    for t in raw:
        lowered = t.lower().strip()
        result.add(lowered.rstrip(":").rstrip())
        colon_pos = lowered.find(": ")
        if colon_pos > 0:
            name_part = lowered[colon_pos + 2:].strip()
            if name_part:
                result.add(name_part)
    return result


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
    defender: Character | None = None,
    maneuver: str = "none",
    defender_stance: str = "",
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
    if "the way of the mantis" in known:
        rolled += 1; notes.append("The Way of the Mantis +1k0 attack")
    if "the eternal stone unleashed" in known and wname in ("unarmed", "improvised"):
        rolled += 1; notes.append("The Eternal Stone Unleashed +1k0 attack (unarmed/improvised)")
    if "honor of the lion" in known and attacker_stance == "full_attack":
        rolled += 1; notes.append("Honor of the Lion +1k0 attack (Full Attack Stance)")
    if "no regrets" in known and _is_bow(weapon_profile):
        v = stats.ring_value(attacker, "air") // 2
        if v:
            rolled += v; notes.append(f"No Regrets +{v}k0 attack (½ Air Ring, bow)")
    if "heart of the mountains" in known and not weapon_profile.get("melee"):
        v = math.ceil(attacker.skills.get("Athletics", attacker.skills.get("athletics", 0)) / 2)
        if v:
            rolled += v; notes.append(f"Heart of the Mountains +{v}k0 attack (½ Athletics, ranged)")
    if "the blessings of heaven" in known and wname in _SAMURAI_WEAPONS:
        rolled += 1; notes.append("The Blessings of Heaven +1k0 attack (Samurai weapon)")
    if "never beyond my reach" in known and wname in _NINJA_WEAPONS:
        rolled += 1; kept += 1; notes.append("Never Beyond My Reach +1k1 attack (Ninja weapon)")
    if "purity in purpose & deed" in known:
        def_honor = stats.honor_rank(defender) if defender is not None else 0
        diff = stats.honor_rank(attacker) - def_honor
        if diff > 0:
            flat += diff; notes.append(f"Purity in Purpose & Deed +{diff} attack (Honor Rank {stats.honor_rank(attacker)} vs {def_honor})")
    if "the hand of the heavens" in known and wname in _MONK_WEAPONS:
        if defender is not None:
            atk_fire = stats.ring_value(attacker, "fire")
            def_fire = stats.ring_value(defender, "fire")
            if atk_fire > def_fire:
                flat += 5; notes.append(f"The Hand of the Heavens +5 attack (Free Raise; Fire {atk_fire} > {def_fire}, {wname})")
    if "howl of the cliff's edge" in known and wname == "kusarigama" and maneuver in ("knockdown", "disarm"):
        rolled += 2; kept += 1; notes.append(f"Howl of the Cliff's Edge +2k1 attack (kusarigama {maneuver})")
    if "smoke and mirrors" in known and wname == "machi_kanshisha" and maneuver in ("knockdown", "disarm"):
        flat += 5; notes.append(f"Smoke and Mirrors +5 attack (Free Raise; iron pipe {maneuver})")
    if "no course but one" in known and defender is not None:
        if int(defender.status) > stats.honor_rank(defender):
            flat += 5; notes.append(f"No Course but One +5 attack (Free Raise; target Status {int(defender.status)} > Honor {stats.honor_rank(defender)})")
    if "rain of death" in known:
        if _is_bow(weapon_profile):
            rolled += 2; kept += 2; notes.append("Rain of Death +2k2 attack (bow)")
        else:
            rolled += 1; notes.append("Rain of Death +1k0 attack")
    if "shinsei's smile" in known and defender is not None:
        wp_pen = stats.wound_penalty(defender)
        if wp_pen < 0:
            v = (-wp_pen) // 2
            if v:
                flat += v; notes.append(f"Shinsei's Smile +{v} attack (½ opponent wound penalty {wp_pen})")
    if "the strength of one man" in known and defender is not None:
        if stats.insight_rank(defender) > stats.insight_rank(attacker):
            rolled += 1; kept += 1; notes.append("The Strength of One Man +1k1 attack (higher Insight Rank)")
    if "crushing blow" in known and wname == "unarmed" and defender is not None:
        arm_bonus = getattr(defender, "armor_tn_bonus", 0)
        if arm_bonus:
            flat += arm_bonus; notes.append(f"Crushing Blow +{arm_bonus} attack (ignore armor TN, unarmed)")
    if "seeking weakness" in known and _is_small(weapon_profile) and defender is not None:
        arm_bonus = getattr(defender, "armor_tn_bonus", 0)
        if arm_bonus:
            flat += arm_bonus; notes.append(f"Seeking Weakness +{arm_bonus} attack (ignore armor TN, Small weapon)")
    if "way of the iron crane" in known and attacker_stance == "attack" and \
            skill == "heavy weapons" and defender_stance in ("attack", "full_attack"):
        rolled += 1; kept += 1; notes.append("Way of the Iron Crane +1k1 attack (Heavy Weapon, Attack vs Attack/Full Attack)")
    if "cracks within the elements" in known and defender is not None:
        rings = [stats.ring_value(defender, r) for r in ("air", "earth", "fire", "water")]
        gap = 2 * (max(rings) - min(rings))
        if gap:
            flat += gap; notes.append(f"Cracks Within the Elements +{gap} attack (2×(highest {max(rings)} − lowest {min(rings)}))")
    if "the kaiu method" in known and skill == "war fans":
        rolled += 1; notes.append("The Kaiu Method +1k0 attack (War Fan, School Skill)")
    if "the strength of indra" in known and skill in _KSHATRIYA_WEAPON_SKILLS:
        rolled += 1; notes.append(f"The Strength of Indra +1k0 attack ({skill}, School Weapon Skill)")
    if defender is not None and weapon_profile.get("melee"):
        def_known = _known(defender)
        if "the way of air" in def_known:
            def_wname = (getattr(defender, "equipped_weapon", "") or "").lower().strip()
            if not def_wname or def_wname == "unarmed":
                air = stats.ring_value(attacker, "air")
                if air:
                    rolled -= air; notes.append(f"The Way of Air −{air}k0 attack (defender unarmed, attacker Air {air})")
    return rolled, kept, flat, notes


def attacker_trait_override(attacker: Character, weapon_profile: dict) -> tuple[int | None, str, str]:
    """(trait_value, trait_name, note) replacing the attack roll's Trait, or
    (None, '', '') if none applies. Falcon's Strike: use Perception instead of
    Reflexes for ranged (bow) attack rolls."""
    known = _known(attacker)
    if "spotting the prey" in known and _is_bow(weapon_profile):
        return attacker.perception, "Perception", "Spotting the Prey: Perception replaces Reflexes (bow)"
    return None, "", ""


def attacker_wound_penalty_mod(attacker: Character) -> tuple[int, list[str]]:
    """(flat_bonus, notes) counteracting wound penalties on attack rolls.
    Toku's Lesson: wound penalties reduced by Willpower + 2*SR."""
    known = _known(attacker)
    bonus = 0
    notes: list[str] = []
    if "toku's lesson" in known:
        v = attacker.willpower + 2 * max(1, attacker.school_rank)
        bonus += v; notes.append(f"Toku's Lesson: wound penalties reduced by {v} (Will {attacker.willpower} + 2×SR {attacker.school_rank})")
    if "moto's strength" in known:
        theology = attacker.skills.get("Lore: Theology", attacker.skills.get("lore: theology", 0))
        if theology:
            idx = stats.wound_level_index(attacker)
            ignore_levels = 2 * theology
            effective_idx = max(0, idx - ignore_levels)
            offset = enums.WOUND_PENALTIES[effective_idx] - enums.WOUND_PENALTIES[idx]
            if offset:
                bonus += offset
                notes.append(f"Moto's Strength: ignore {ignore_levels} wound levels (Theology {theology}×2)")
    return bonus, notes


def attacker_damage(
    attacker: Character, weapon_profile: dict, weapon_name: str,
    attacker_stance: str = "",
    atk_init: int | None = None, def_init: int | None = None,
    defender: Character | None = None,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for the damage roll."""
    known = _known(attacker)
    rolled = kept = flat = 0
    notes: list[str] = []
    skill = _skill(weapon_profile)
    wname = weapon_name.lower().strip()
    melee = bool(weapon_profile.get("melee"))
    target_lower = atk_init is not None and def_init is not None and def_init < atk_init
    main = (getattr(attacker, "equipped_weapon", "") or "").lower().strip()
    off = (getattr(attacker, "off_hand_weapon", "") or "").lower().strip()

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
    if "the eternal stone unleashed" in known and wname in ("unarmed", "improvised"):
        rolled += 1; notes.append("The Eternal Stone Unleashed +1k0 damage (unarmed/improvised)")
    if "way of drunken fists" in known and (wname == "unarmed" or _is_small(weapon_profile)):
        rolled += 1; notes.append("Way of Drunken Fists +1k0 damage (unarmed/Small)")
    if "waves rush to shore" in known and wname == "kama" and main == "kama" and off == "kama":
        rolled += 3; notes.append("Waves Rush to Shore +3k0 damage (kama in each hand)")
    if "one blade, both hands" in known and wname == "tanto" and not off:
        rolled += 3; kept += 1; notes.append("One Blade, Both Hands +3k1 damage (tanto, off-hand empty)")
    if "the charge of the boar" in known and skill == "spears":
        kept += 1; notes.append("The Charge of the Boar +0k1 damage (spear)")
    if "fast and furious" in known and target_lower:
        rolled += 2; kept += 2; notes.append("Fast and Furious +2k2 damage (target lower Initiative)")
    if "deny the horde" in known and attacker_stance == "full_attack":
        rolled += 3; notes.append("Deny the Horde +3k0 damage (Full Attack)")
    if "moto cannot yield" in known and attacker_stance == "full_attack" and \
            (wname in _SAMURAI_WEAPONS or _is_two_handed_melee(weapon_profile)):
        v = attacker.strength // 2
        if v:
            kept += v; notes.append(f"Moto Cannot Yield +0k{v} damage (½ Strength, Full Attack, Samurai/two-handed)")
    if "the hitomi kikage zumi order" in known and wname == "unarmed" and attacker.school_rank >= 4:
        rolled += 1; kept += 1; notes.append("Kikage Zumi R4 +1k1 damage (unarmed)")
    if "never beyond my reach" in known and wname in _NINJA_WEAPONS:
        rolled += 1; kept += 1; notes.append("Never Beyond My Reach +1k1 damage (Ninja weapon)")
    if "master of the quick blade" in known and wname in _KNIFE_WEAPONS:
        if main in _KNIFE_WEAPONS and off in _KNIFE_WEAPONS:
            rolled += 1; kept += 1; notes.append("Master of the Quick Blade +1k1 damage (knife in each hand)")
    if "the path of one" in known and wname in _PEASANT_WEAPONS:
        rolled += 1; notes.append(f"The Path of One +1k0 damage (Peasant weapon)")
    if "spotting the prey" in known and _is_bow(weapon_profile) and wname == "yumi":
        from . import combat as _combat
        base_rolled = _combat.get_weapon_profile("yumi").get("rolled", 2)
        delta = attacker.perception - base_rolled
        if delta != 0:
            rolled += delta
            notes.append(f"Spotting the Prey: Perception {attacker.perception} replaces bow Strength {base_rolled} for damage ({delta:+d}k0)")
    if "the strength of one man" in known and defender is not None:
        if stats.insight_rank(defender) > stats.insight_rank(attacker):
            rolled += 1; kept += 1; notes.append("The Strength of One Man +1k1 damage (higher Insight Rank)")
    if "weaken the resistance" in known and defender is not None:
        has_armor_red = getattr(defender, "armor_reduction", 0) > 0
        tech_red_val, _ = defender_reduction_bonus(defender)
        if not has_armor_red and tech_red_val <= 0:
            rolled += 1; notes.append("Weaken the Resistance +1k0 damage (opponent has no armor/technique Reduction)")
    if "hold the passes" in known and not weapon_profile.get("melee", True):
        thrown_skill = _skill(weapon_profile)
        if thrown_skill in ("athletics", "knives"):
            if wname in ("nage_yari", "nage-yari", "rock"):
                rolled += 1; kept += 1; notes.append(f"Hold the Passes +1k1 damage (thrown {wname})")
            else:
                rolled += 1; notes.append("Hold the Passes +1k0 damage (thrown weapon)")
    if "purity in purpose & deed" in known:
        def_honor = stats.honor_rank(defender) if defender is not None else 0
        diff = stats.honor_rank(attacker) - def_honor
        if diff > 0:
            flat += diff; notes.append(f"Purity in Purpose & Deed +{diff} damage (Honor Rank {stats.honor_rank(attacker)} vs {def_honor})")
    return rolled, kept, flat, notes


def attacker_reduction_ignored(
    attacker: Character, weapon_profile: dict, weapon_name: str = "",
    defender: Character | None = None,
) -> tuple[int, list[str]]:
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
    if "claws of the falcon" in known:
        ignore += 5; notes.append("Claws of the Falcon ignores 5 Reduction")
    if "one blade, both hands" in known and wname == "tanto" and \
            not (getattr(attacker, "off_hand_weapon", "") or "").strip():
        ignore = _IGNORE_ALL; notes.append("One Blade, Both Hands ignores armor Reduction (tanto, off-hand empty)")
    if "weaken the resistance" in known and defender is not None:
        armor_red = getattr(defender, "armor_reduction", 0)
        tech_red_val, _ = defender_reduction_bonus(defender)
        total = armor_red + tech_red_val
        if total > 0:
            ignore += total; notes.append(f"Weaken the Resistance ignores {total} Reduction (armor {armor_red} + technique {tech_red_val})")
    if "seeking weakness" in known and _is_small(weapon_profile) and defender is not None:
        armor_red = getattr(defender, "armor_reduction", 0)
        if armor_red > 0:
            ignore += armor_red; notes.append(f"Seeking Weakness ignores {armor_red} armor Reduction (Small weapon)")
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
    if "folds of the iron fan" in known:
        wfr = defender.skills.get("War Fan", defender.skills.get("war fan", 0))
        main_wf = defender.equipped_weapon.lower().strip() == "war_fan"
        off_wf = (getattr(defender, "off_hand_weapon", "") or "").lower().strip() == "war_fan"
        if (main_wf or off_wf) and wfr:
            bonus += wfr; notes.append(f"Folds of the Iron Fan +{wfr} Armor TN (War Fan rank)")
    if "the commander's fan" in known:
        wfr = defender.skills.get("War Fan", defender.skills.get("war fan", 0))
        def_main = defender.equipped_weapon.lower().strip()
        def_off = (getattr(defender, "off_hand_weapon", "") or "").lower().strip()
        has_wf = def_main == "war_fan" or def_off == "war_fan"
        wf_only = (def_main == "war_fan" and not def_off) or (def_off == "war_fan" and not def_main)
        if has_wf and wfr:
            if defender_stance in ("defense", "full_defense") or wf_only:
                bonus += wfr
                notes.append(f"The Commander's Fan +{wfr} Armor TN (War Fan rank, Defense/only)")
            else:
                v = math.ceil(wfr / 2)
                if v:
                    bonus += v; notes.append(f"The Commander's Fan +{v} Armor TN (½ War Fan rank)")
    if "waves rush to shore" in known:
        def_main = defender.equipped_weapon.lower().strip()
        def_off = (getattr(defender, "off_hand_weapon", "") or "").lower().strip()
        if def_main == "kama" and def_off == "kama":
            kr = defender.skills.get("Knives", defender.skills.get("knives", 0))
            if kr:
                bonus += kr; notes.append(f"Waves Rush to Shore +{kr} Armor TN (Knives rank, kama pair)")
    if "iron feather" in known:
        armor = (getattr(defender, "armor_name", "") or "").lower().strip()
        if not armor or armor in ("light armor", "light", "ashigaru", "ashigaru armor"):
            sr = defender.skills.get("Stealth", defender.skills.get("stealth", 0))
            if sr:
                bonus += sr; notes.append(f"Iron Feather +{sr} Armor TN (Stealth rank, light/no armour)")
    if "way of the iron crane" in known and defender_stance in ("defense", "full_defense"):
        def_wpn_skill = ""
        from . import combat as _combat
        def_wp = _combat.get_weapon_profile(defender.equipped_weapon)
        def_wpn_skill = str(def_wp.get("skill", "")).lower()
        if def_wpn_skill == "heavy weapons":
            hw = defender.skills.get("Heavy Weapons", defender.skills.get("heavy weapons", 0))
            if hw:
                bonus += hw; notes.append(f"Way of the Iron Crane +{hw} Armor TN (Heavy Weapons rank, Defense)")
    if "the hitomi kikage zumi order" in known:
        bonus += defender.reflexes
        notes.append(f"Kikage Zumi R1 +{defender.reflexes} Armor TN (Reflexes)")
    if "speed of the hare" in known and defender_stance not in ("full_attack", "center"):
        ath = defender.skills.get("Athletics", defender.skills.get("athletics", 0))
        if ath:
            bonus += ath; notes.append(f"Speed of the Hare +{ath} Armor TN (Athletics rank)")
    return bonus, notes


def defender_reduction_bonus(
    defender: Character, defender_stance: str = "attack",
) -> tuple[int, list[str]]:
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
    if "power within and without" in known and _no_armor(defender) and \
            not (getattr(defender, "active_kiho", None) or []) and \
            not (getattr(defender, "active_tattoo", "") or "").strip():
        v = 3 + stats.ring_value(defender, "void")
        bonus += v; notes.append(f"Power Within and Without +{v} Reduction (3 + Void Ring, no armour/kiho/tattoo)")
    if "the way of magari-yarijutsu" in known and defender_stance in ("center", "defense", "full_defense"):
        from . import combat as _combat
        eq = (defender.equipped_weapon or "").strip()
        if eq:
            wp = _combat.get_weapon_profile(eq)
            wpn_skill = str(wp.get("skill", "")).lower()
            if wpn_skill in _SPEAR_POLEARM:
                sr = defender.skills.get("Spears", defender.skills.get("spears",
                     defender.skills.get("Polearms", defender.skills.get("polearms", 0))))
                v = math.ceil(sr / 2)
                if v:
                    bonus += v; notes.append(f"Way of Magari-Yarijutsu +{v} Reduction (½ {wpn_skill.title()} rank, {defender_stance.title()})")
    return bonus, notes


def maneuver_free_raises(
    attacker: Character, weapon_name: str, maneuver: str,
    weapon_profile: dict | None = None,
) -> tuple[int, list[str]]:
    """(free_raises, notes) that reduce a maneuver's raise cost."""
    known = _known(attacker)
    wname = weapon_name.lower().strip()
    free = 0
    notes: list[str] = []
    if "the hitomi kikage zumi order" in known and attacker.school_rank >= 4 \
            and maneuver == "knockdown" and wname == "unarmed":
        free += 1; notes.append("Kikage Zumi R4: Knockdown costs 1 less Raise (unarmed)")
    if "pincers and tail" in known and maneuver == "feint":
        free += 1; notes.append("Pincers and Tail: Feint costs 1 less Raise")
    if "wearing down the mountain" in known and maneuver == "extra_attack" and \
            wname in ("unarmed", "improvised"):
        free += 2; notes.append("Wearing Down the Mountain: Extra Attack costs 2 fewer Raises (unarmed/improvised)")
    if "the arrow knows the way" in known and maneuver == "called_shot":
        if weapon_profile is not None and _is_bow(weapon_profile):
            free += 1; notes.append("The Arrow Knows the Way: Called Shot 1 free Raise (bow)")
    if "fist and blade" in known and maneuver == "knockdown":
        if weapon_profile is not None and _skill(weapon_profile) == "kenjutsu":
            free += 1; notes.append("Fist and Blade: Knockdown costs 1 less Raise (sword)")
    if "reichin's style" in known and maneuver == "feint":
        free += 1; notes.append("Reichin's Style: Feint costs 1 less Raise")
    if "strike with the soul" in known and maneuver == "extra_attack":
        if weapon_profile is not None and _skill(weapon_profile) in _SPEAR_POLEARM:
            free += 2; notes.append("Strike With the Soul: Extra Attack costs 2 fewer Raises (spear/polearm)")
    if "no regrets" in known and maneuver == "called_shot":
        if weapon_profile is not None and _is_bow(weapon_profile):
            free += 1; notes.append("No Regrets: Called Shot costs 1 less Raise (bow)")
    if "the way of the archer" in known and maneuver == "called_shot":
        if weapon_profile is not None and _is_bow(weapon_profile):
            free += 1; notes.append("The Way of the Archer: Called Shot costs half Raises (bow)")
    return free, notes


def feint_uncapped(attacker: Character) -> tuple[bool, str]:
    """(uncapped, note): Reichin's Style removes the Feint damage cap (5×IR)."""
    if "reichin's style" in _known(attacker):
        return True, "Reichin's Style: Feint damage uncapped"
    return False, ""


def off_hand_penalty_removed(
    attacker: Character, weapon_profile: dict, weapon_name: str,
) -> tuple[bool, bool, list[str]]:
    """(off_hand_removed, dominant_hand_removed, notes).
    School techniques that remove dual-wielding penalties (s29)."""
    known = _known(attacker)
    wname = weapon_name.lower().strip()
    main = (getattr(attacker, "equipped_weapon", "") or "").lower().strip()
    off = (getattr(attacker, "off_hand_weapon", "") or "").lower().strip()

    if "way of the dragon" in known and {main, off} == {"katana", "wakizashi"}:
        return True, True, ["Way of the Dragon: no dual-wielding penalties (daishō)"]

    if "the way of the mantis" in known and wname in _PEASANT_WEAPONS:
        size = str(weapon_profile.get("size", "")).lower()
        if size in ("small", "medium"):
            return True, False, [f"Way of the Mantis: no off-hand penalty ({wname}, Peasant)"]

    if "deny the horde" in known and wname in ("masakari", "masakiri"):
        return True, False, ["Deny the Horde: no off-hand penalty (masakari)"]

    if "folds of the iron fan" in known and wname == "war_fan":
        return True, False, ["Folds of the Iron Fan: no off-hand penalty (war fan)"]

    return False, False, []


# ---------------------------------------------------------------------------
# Iaijutsu duel modifiers (s29)
# ---------------------------------------------------------------------------


def iaijutsu_roll_bonus(
    character: Character,
    roll_type: str,
) -> tuple[int, int, int, list[str]]:
    """(bonus_rolled, bonus_kept, flat_bonus, notes) for iaijutsu duel rolls.

    roll_type: "assessment", "focus", or "strike".
    Center Stance is assumed for all iaijutsu duel rolls.
    """
    known = _known(character)
    rolled = kept = flat = 0
    notes: list[str] = []

    if "the calm in midst of thunder" in known:
        v = character.skills.get("Kenjutsu", character.skills.get("kenjutsu", 0))
        if v:
            flat += v
            notes.append(f"Calm in Midst of Thunder +{v} (Kenjutsu rank, Center Stance)")

    if "the gaze of sun tao" in known:
        v = stats.honor_rank(character)
        if v:
            flat += v
            notes.append(f"Gaze of Sun Tao +{v} (Honor Rank)")

    if roll_type == "assessment":
        if "the purity of justice" in known:
            v = character.skills.get("Investigation", character.skills.get("investigation", 0))
            if v:
                flat += v
                notes.append(f"Purity of Justice +{v} Assessment (Investigation rank)")

    if roll_type == "focus":
        if "the way of the crane" in known:
            sr = max(1, character.school_rank)
            rolled += 1; kept += 1; flat += sr
            notes.append(f"Way of the Crane +1k1+{sr} Focus (Center Stance)")
        if "mirumoto's strength" in known:
            rolled += 1; kept += 1
            notes.append("Mirumoto's Strength +1k1 Focus (always)")

    if roll_type == "strike":
        if "the way of the crane" in known:
            sr = max(1, character.school_rank)
            rolled += 1; kept += 1; flat += sr
            notes.append(f"Way of the Crane +1k1+{sr} Strike (Center Stance)")

    return rolled, kept, flat, notes


def iaijutsu_explode_9(
    character: Character,
    roll_type: str,
) -> tuple[bool, list[str]]:
    """Whether the character's iaijutsu dice explode on 9+ (instead of 10).

    roll_type: "assessment" or "focus". Kakita's Strength applies to both.
    """
    known = _known(character)
    if roll_type in ("assessment", "focus") and "kakita's strength" in known:
        return True, ["Kakita's Strength: dice explode on 9+ (" + roll_type + ")"]
    return False, []


def iaijutsu_focus_thresholds(character: Character) -> tuple[int, int, list[str]]:
    """(win_margin, raise_divisor, notes) for Focus resolution.

    Default (5, 5). First and Last Strike: (3, 3).
    """
    known = _known(character)
    if "first and last strike" in known:
        return 3, 3, ["First and Last Strike: win by 3+, Free Raise per 3"]
    return 5, 5, []


def iaijutsu_strike_reduction(character: Character) -> tuple[int, list[str]]:
    """Extra Reduction during the Strike step of an iaijutsu duel."""
    known = _known(character)
    bonus = 0
    notes: list[str] = []
    if "warrior of earth" in known:
        v = stats.ring_value(character, "earth") * 3
        bonus += v
        notes.append(f"Warrior of Earth +{v} Reduction (Earth×3, duel Strike)")
    return bonus, notes


# ---------------------------------------------------------------------------
# Initiative modifiers (s29)
# ---------------------------------------------------------------------------


def initiative_bonus(character: Character) -> tuple[int, list[str]]:
    """Flat bonus added to the initiative roll total."""
    known = _known(character)
    bonus = 0
    notes: list[str] = []
    if "dance the razor's edge" in known:
        v = character.skills.get("Stealth", character.skills.get("stealth", 0))
        if v:
            bonus += v
            notes.append(f"Dance the Razor's Edge +{v} Initiative (Stealth rank)")
    if "always be ready" in known:
        bonus += 3
        notes.append("Always Be Ready +3 Initiative Score")
    if "the way of the crane" in known:
        v = 2 * character.skills.get("Iaijutsu", character.skills.get("iaijutsu", 0))
        if v:
            bonus += v
            notes.append(f"The Way of the Crane +{v} Initiative (2× Iaijutsu)")
    return bonus, notes


def initiative_dice_bonus(character: Character) -> tuple[int, int, list[str]]:
    """(bonus_rolled, bonus_kept, notes) extra dice added to the Initiative roll."""
    known = _known(character)
    rolled = kept = 0
    notes: list[str] = []
    if "the way of the scorpion" in known:
        rolled += 1; kept += 1
        notes.append("The Way of the Scorpion +1k1 Initiative")
    if "speed of my sisters" in known:
        rolled += 1
        notes.append("Speed of My Sisters +1k0 Initiative")
    if "master of the quick blade" in known:
        main = (getattr(character, "equipped_weapon", "") or "").lower().strip()
        off = (getattr(character, "off_hand_weapon", "") or "").lower().strip()
        if main in _KNIFE_WEAPONS and off in _KNIFE_WEAPONS:
            rolled += 1
            notes.append("Master of the Quick Blade +1k0 Initiative (knife in each hand)")
    return rolled, kept, notes


# ---------------------------------------------------------------------------
# Defender maneuver TN increase (s29)
# ---------------------------------------------------------------------------


def defender_maneuver_tn_increase(
    defender: Character,
    maneuver: str,
) -> tuple[int, list[str]]:
    """Extra raises the attacker must pay when using a maneuver against this
    defender. Returns (extra_raises, notes)."""
    known = _known(defender)
    extra = 0
    notes: list[str] = []
    if "wisdom the wind brings" in known and maneuver in ("feint", "disarm"):
        sr = max(1, defender.school_rank)
        extra += sr
        notes.append(f"Wisdom the Wind Brings +{sr * 5} TN vs {maneuver} ({sr} raises, Kitsuki SR)")
    return extra, notes
