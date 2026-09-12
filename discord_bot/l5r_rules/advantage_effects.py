"""Deterministic modifiers from Advantages & Disadvantages (GDD s45).

Combat auto-applied (12 effects across 10 entries):
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

Skill-check auto-applied:
  Silent: +1k0 Stealth
  Voice: +1k1 Perform
  Wary: +1k1 Investigation (Notice emphasis only)
  Irreproachable: +1k0 vs Temptation (contested only)
  Heartless: +1k0 vs Courtier/Sincerity/Temptation (contested only)
  Clear Thinker: +1k0 contested defense vs manipulation
  Antisocial: -1k0 Social (or -1k1 if "Major")
  Bad Eyesight: -1k1 Perception-based skill checks
  Seven Fortunes' Curse: Benten: -10 flat Etiquette
  Seven Fortunes' Curse: Daikoku: -1k1 Commerce
  Seven Fortunes' Curse: Fukurokujin: -5 flat all Lore
  Seven Fortunes' Blessing: Daikoku: +1k1 Commerce
  Seven Fortunes' Blessing: Fukurokujin: +1k1 chosen Lore (parameterised)
  Weakness: chosen Trait treated as 1 lower (parameterised)

Parameterised storage: advantages requiring a parameter (Chosen by the
Oracles, Weakness, Doubt, Fukurokujin, Heart of Vengeance, etc.) are stored
as "Name: Parameter" on the character sheet (e.g. "Weakness: Willpower").
The _get_adv_param / _get_disadv_param helpers extract the parameter.

Reminder-only (not auto-applied):
  Quick (Initiative re-add needs Reactions Stage), Prodigy (school-skill
  detection not modelled), Sacred Weapons (weapon identity not tracked beyond
  name), Crab Hands (unskilled fallback: edge case), Blind movement penalty,
  Small movement penalty, Lame, Missing Limb,
  Momoku/Consumed/Failure of Bushido (Void-spend restrictions need per-spend
  gating), Magic Resistance (spell combat not modelled here).
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


def _get_adv_param(c: Character, base_name: str) -> str | None:
    """Extract the parameter from "Base Name: Parameter" in advantages."""
    base = base_name.lower()
    for a in c.advantages:
        al = a.lower()
        if al == base or al.startswith(base + ":") or al.startswith(base + " ("):
            rest = a[len(base_name):].lstrip(":").lstrip(" (").rstrip(")").strip()
            return rest if rest else None
    return None


def _get_disadv_param(c: Character, base_name: str) -> str | None:
    """Extract the parameter from "Base Name: Parameter" in disadvantages."""
    base = base_name.lower()
    for d in c.disadvantages:
        dl = d.lower()
        if dl == base or dl.startswith(base + ":") or dl.startswith(base + " ("):
            rest = d[len(base_name):].lstrip(":").lstrip(" (").rstrip(")").strip()
            return rest if rest else None
    return None


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


# ---------------------------------------------------------------------------
# Skill-check modifiers
# ---------------------------------------------------------------------------

_SOCIAL_SKILLS = {"courtier", "etiquette", "intimidation", "temptation", "sincerity", "perform"}


def skill_check_modifiers(
    character: Character,
    skill_name: str,
    trait_name: str,
    *,
    emphasis: str | None = None,
    is_contested: bool = False,
    opponent_skill: str | None = None,
) -> tuple[int, int, int, list[str]]:
    """(extra_rolled, extra_kept, flat_bonus, notes) for a skill check.

    Parameters
    ----------
    skill_name : the skill being rolled (e.g. "Stealth", "Investigation").
    trait_name : the trait being rolled (e.g. "agility", "perception").
    emphasis   : Investigation emphasis if applicable (e.g. "Notice").
    is_contested : True if this is a contested roll.
    opponent_skill : the opponent's skill in a contested roll (e.g. "Temptation").
    """
    rolled = kept = flat = 0
    notes: list[str] = []
    sk = skill_name.lower()
    tr = trait_name.lower()
    opp = opponent_skill.lower() if opponent_skill else ""

    # --- Advantages ---

    if _has_adv(character, "Silent") and sk == "stealth":
        rolled += 1
        notes.append("Silent +1k0 (Stealth)")

    if _has_adv(character, "Voice") and sk == "perform":
        rolled += 1; kept += 1
        notes.append("Voice +1k1 (Perform)")

    if _has_adv(character, "Wary") and sk == "investigation" and emphasis == "Notice":
        rolled += 1; kept += 1
        notes.append("Wary +1k1 (Investigation Notice vs Ambush)")

    if is_contested and _has_adv(character, "Irreproachable") and opp == "temptation":
        rolled += 1
        notes.append("Irreproachable +1k0 (vs Temptation)")

    if is_contested and _has_adv(character, "Heartless") and opp in ("courtier", "sincerity", "temptation"):
        rolled += 1
        notes.append(f"Heartless +1k0 (resisting {opponent_skill})")

    if is_contested and _has_adv(character, "Clear Thinker") and opp in ("sincerity", "temptation", "courtier"):
        rolled += 1
        notes.append("Clear Thinker +1k0 (vs manipulation)")

    # Seven Fortunes' Blessing: Daikoku — +1k1 Commerce
    if sk == "commerce" and _has_adv_containing(character, "daikoku") and _has_adv_containing(character, "seven fortunes"):
        rolled += 1; kept += 1
        notes.append("Daikoku's Blessing +1k1 (Commerce)")

    # Seven Fortunes' Blessing: Fukurokujin — +1k1 to chosen Lore
    if sk.startswith("lore") and _has_adv_containing(character, "fukurokujin") and _has_adv_containing(character, "seven fortunes"):
        param = _get_adv_param(character, "Seven Fortunes' Blessing")
        if param and "fukurokujin" in param.lower():
            # Check if a specific Lore is parameterised: "Fukurokujin (Lore: Heraldry)"
            lore_param = param.lower()
            if "(" in param:
                inner = param[param.index("(") + 1:].rstrip(")").strip().lower()
                if inner == sk or inner in sk:
                    rolled += 1; kept += 1
                    notes.append(f"Fukurokujin's Blessing +1k1 ({skill_name})")
            else:
                rolled += 1; kept += 1
                notes.append(f"Fukurokujin's Blessing +1k1 ({skill_name})")

    # --- Disadvantages ---

    # Antisocial: -1k0 Social (2 pts) or -1k1 (4 pts / "Major")
    if sk in _SOCIAL_SKILLS:
        if _has_disadv(character, "Antisocial (Major)") or _has_disadv_containing(character, "antisocial (major)"):
            rolled -= 1; kept -= 1
            notes.append("Antisocial (Major) -1k1 (Social)")
        elif _has_disadv(character, "Antisocial") or _has_disadv_containing(character, "antisocial"):
            if not _has_disadv_containing(character, "antisocial (major)"):
                rolled -= 1
                notes.append("Antisocial -1k0 (Social)")

    # Bad Eyesight: -1k1 to Perception-based skill checks (non-combat)
    if _has_disadv(character, "Bad Eyesight") and tr == "perception":
        rolled -= 1; kept -= 1
        notes.append("Bad Eyesight -1k1 (Perception-based)")

    # Seven Fortunes' Curse: Benten — +10 TN to Etiquette (= -10 flat)
    if sk == "etiquette" and _has_disadv_containing(character, "benten") and _has_disadv_containing(character, "seven fortunes"):
        flat -= 10
        notes.append("Benten's Curse -10 (Etiquette TN +10)")

    # Seven Fortunes' Curse: Daikoku — -1k1 Commerce
    if sk == "commerce" and _has_disadv_containing(character, "daikoku") and _has_disadv_containing(character, "seven fortunes"):
        rolled -= 1; kept -= 1
        notes.append("Daikoku's Curse -1k1 (Commerce)")

    # Seven Fortunes' Curse: Fukurokujin — +5 TN to all Lore (= -5 flat)
    if sk.startswith("lore") and _has_disadv_containing(character, "fukurokujin") and _has_disadv_containing(character, "seven fortunes"):
        flat -= 5
        notes.append("Fukurokujin's Curse -5 (Lore TN +5)")

    # Seven Fortunes' Blessing: Jurojin — +2k0 resist poison/disease
    if sk in ("poison_resist", "medicine") and _has_adv_containing(character, "jurojin") and _has_adv_containing(character, "seven fortunes"):
        rolled += 2
        notes.append("Jurojin's Blessing +2k0 (resist poison/disease)")

    # Seven Fortunes' Curse: Jurojin — -2k0 resist poison/disease
    if sk in ("poison_resist", "medicine") and _has_disadv_containing(character, "jurojin") and _has_disadv_containing(character, "seven fortunes"):
        rolled -= 2
        notes.append("Jurojin's Curse -2k0 (resist poison/disease)")

    # Weakness: chosen Trait treated as 1 Rank lower
    weak_param = _get_disadv_param(character, "Weakness")
    if weak_param and weak_param.lower() == tr:
        flat -= 1
        notes.append(f"Weakness -1 ({weak_param}: trait rolls as 1 lower)")

    return rolled, kept, flat, notes


# Parameterised advantages that require a ": Parameter" suffix.
PARAMETERISED_ADVANTAGES: dict[str, str] = {
    "Chosen by the Oracles": "Ring (Air, Earth, Fire, Water, Void)",
    "Friend of the Elements": "Ring (Air, Earth, Fire, Water)",
    "Friendly Kami": "Element (Air, Earth, Fire, Water)",
    "Elemental Blessing": "Element (Air, Earth, Fire, Water)",
    "Heart of Vengeance": "Clan or faction",
    "Seven Fortunes' Blessing": "Fortune (Benten, Bishamon, Daikoku, Ebisu, Fukurokujin, Hotei, Jurojin)",
    "Touch of the Spirit Realms": "Realm (Chikushudo, Gaki-do, Jigoku, Meido, Sakkaku, Tengoku, Toshigoku, Yomi, Yume-do)",
    "Inner Gift": "Gift (Animal Ken, Empathy, Foresight, Lesser Prophecy, Spirit Touch)",
    "Dark Paragon": "Precept (Control, Determination, Insight, Knowledge, Perfection, Strength, Will)",
    "Great Potential": "Skill name",
    "Darling of the Court": "Court name",
}

PARAMETERISED_DISADVANTAGES: dict[str, str] = {
    "Weakness": "Trait (Stamina, Willpower, Strength, Perception, Agility, Intelligence, Reflexes, Awareness)",
    "Doubt": "School Skill name",
    "Seven Fortunes' Curse": "Fortune (Benten, Bishamon, Daikoku, Ebisu, Fukurokujin, Hotei, Jurojin)",
    "Wrath of the Kami": "Element (Air, Earth, Fire, Water)",
    "Phobia": "Subject of fear",
    "Consumed": "Vice (Compulsion, Insatiable Desire, Jealousy, Obsession, Perfection)",
    "Failure of Bushido": "Tenet of Bushido",
}
