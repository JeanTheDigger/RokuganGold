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

High Skill mastery auto-applied (contested-only):
  Courtier R5: +1k0 on Contested Rolls
  Etiquette R5: +1k0 on Contested Rolls
  Investigation R5: +5 on Contested Rolls
  Sincerity R5: +5 on Contested Rolls
  Meditation R5: +5 flat on Fasting emphasis rolls (TN reduced by 5)

High Skill mastery reminder-only:
  Acting R3/R5/R7 (disguise TN reduction), Calligraphy R5 (cipher +10),
  Divination R5 (second attempt), Investigation R3/R7 (Search retries),
  Medicine R5 (healing +1k0), Meditation R3/R7 (VP recovery),
  Spellcraft R5 (casting +1k0), Tea Ceremony R5 (2 VP recovery)

Bugei Skill mastery reminder-only:
  Athletics R3/R5/R7 (terrain/movement), Battle R5 (Initiative),
  Defense R3/R5/R7 (stances), Horsemanship R3/R5/R7 (horseback),
  Hunting R5 (+1k0 Stealth in wilderness, cross-skill note on Stealth),
  Iaijutsu R3/R5/R7 (ready/duel).
  Weapon Bugei masteries are in skill_mastery.py (not here).

Merchant Skill mastery reminder-only:
  Animal Handling R3/R5/R7 (training/command), Commerce R5 (price ±20%),
  Engineering R5 (+5 Cooperative), Sailing R5 (+5 Cooperative).
  Craft: no mastery abilities.

Low Skill mastery auto-applied (contested-only):
  Intimidation R5: +5 on Contested Rolls
  Temptation R5: +5 on Contested Rolls

Low Skill mastery reminder-only:
  Forgery R3/R7 (detection TN bonus), Forgery R5 (detect others' forgery),
  Sleight of Hand R5 (conceal weapons), Stealth R3/R5/R7 (movement)

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
from . import stats


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
        taint_rank = stats.taint_rank(attacker)
        if taint_rank > 0:
            flat += taint_rank
            notes.append(f"Touch of Jigoku +{taint_rank} attack (Taint Rank)")

    weak_param = _get_disadv_param(attacker, "Weakness")
    if weak_param:
        atk_trait = weapon_profile.get("trait", "agility" if is_melee else "reflexes")
        if weak_param.lower() == atk_trait.lower():
            rolled -= 1; kept -= 1
            notes.append(f"Weakness -1k1 ({weak_param}: Trait treated as 1 lower)")

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

_HONOR_RESISTS = {"fear", "intimidation", "temptation"}


def strength_of_honor(character: Character, resisting: str) -> tuple[int, int, list[str]]:
    """(extra_rolled, flat_bonus, notes) when resisting Fear, Intimidation or
    Temptation. GDD s46 "The Strength of Honor": add Honor Rank to the total.
    s45 Student of Shourido: +5 instead of Honor Rank. s45 Balance: an extra
    +1k0 when Honor Rank is added against Intimidation or Temptation."""
    what = (resisting or "").lower().strip()
    if what not in _HONOR_RESISTS:
        return 0, 0, []
    notes: list[str] = []
    rolled = flat = 0
    if _has_disadv_containing(character, "failure of bushido") and _has_disadv_containing(character, "honor"):
        notes.append("Failure of Bushido (Honor): Cannot add Honor Rank to resist rolls")
        return 0, 0, notes
    if _has_adv(character, "Student of Shourido"):
        flat = 5
        notes.append("Student of Shourido +5 (instead of Honor Rank)")
        return rolled, flat, notes
    hr = stats.honor_rank(character)
    if hr:
        flat = hr
        notes.append(f"Strength of Honor +{hr} (Honor Rank vs {what.title()})")
        if what in ("intimidation", "temptation") and _has_adv(character, "Balance"):
            rolled = 1
            notes.append("Balance +1k0 (resisting with Honor)")
    return rolled, flat, notes


def _armor_skill_penalty(
    c: Character, skill_name: str, trait_name: str,
) -> tuple[int, list[str]]:
    """Flat penalty from the character's armor on skill checks (L5R 4e Equipment).

    Light: +5 TN on Athletics and Stealth.
    Heavy: +5 TN on all Agility/Reflexes skill rolls.
    Tetsu-do: +10 TN on Agility/Reflexes (+5 if Strength >= 5).
    Riding: +5 TN on Agility/Reflexes except when mounted.
    Hida Bushi R1 (Way of the Crab) negates heavy armor penalties.
    Returns (flat_penalty, notes) where penalty is <= 0."""
    if not c.armor_name:
        return 0, []
    from . import combat
    prof = combat.get_armor(c.armor_name)
    if prof is None:
        return 0, []
    kind = prof.get("penalty_kind", "none")
    if kind == "none":
        return 0, []
    sk = skill_name.lower()
    tr = trait_name.lower()
    if kind == "athletics_stealth":
        if sk in ("athletics", "stealth"):
            label = c.armor_name.replace("_", " ").title()
            return -5, [f"Light Armor ({label}): +5 TN on {skill_name}"]
        return 0, []
    if tr not in ("agility", "reflexes"):
        return 0, []
    if any(t.lower() == "the way of the crab" for t in c.techniques):
        return 0, []
    label = c.armor_name.replace("_", " ").title()
    if kind == "agi_ref":
        return -5, [f"Heavy Armor ({label}): +5 TN on {trait_name.capitalize()} skills"]
    if kind == "agi_ref_iron":
        if c.strength >= 5:
            return -5, [f"Tetsu-Do: +5 TN on {trait_name.capitalize()} skills (Strength {c.strength})"]
        return -10, [f"Tetsu-Do: +10 TN on {trait_name.capitalize()} skills (Strength {c.strength})"]
    if kind == "agi_ref_not_mounted":
        if c.is_mounted:
            return 0, []
        return -5, [f"Riding Armor: +5 TN on {trait_name.capitalize()} skills (not mounted)"]
    return 0, []


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

    # Seven Fortunes' Blessing: Daikoku - +1k1 Commerce
    if sk == "commerce" and _has_adv_containing(character, "daikoku") and _has_adv_containing(character, "seven fortunes"):
        rolled += 1; kept += 1
        notes.append("Daikoku's Blessing +1k1 (Commerce)")

    # Seven Fortunes' Blessing: Fukurokujin - +1k1 to chosen Lore
    if sk.startswith("lore") and _has_adv_containing(character, "fukurokujin") and _has_adv_containing(character, "seven fortunes"):
        param = _get_adv_param(character, "Seven Fortunes' Blessing")
        if param and "fukurokujin" in param.lower():
            if "(" in param:
                inner = param[param.index("(") + 1:].rstrip(")").strip().lower()
                if inner == sk or inner in sk:
                    rolled += 1; kept += 1
                    notes.append(f"Fukurokujin's Blessing +1k1 ({skill_name})")
            else:
                notes.append("Fukurokujin's Blessing: No specific Lore parameterised (DM: Set via /edit advantage)")

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

    # Seven Fortunes' Curse: Benten - +10 TN to Etiquette (= -10 flat)
    if sk == "etiquette" and _has_disadv_containing(character, "benten") and _has_disadv_containing(character, "seven fortunes"):
        flat -= 10
        notes.append("Benten's Curse -10 (Etiquette TN +10)")

    # Seven Fortunes' Curse: Daikoku - -1k1 Commerce
    if sk == "commerce" and _has_disadv_containing(character, "daikoku") and _has_disadv_containing(character, "seven fortunes"):
        rolled -= 1; kept -= 1
        notes.append("Daikoku's Curse -1k1 (Commerce)")

    # Seven Fortunes' Curse: Fukurokujin - +5 TN to all Lore (= -5 flat)
    if sk.startswith("lore") and _has_disadv_containing(character, "fukurokujin") and _has_disadv_containing(character, "seven fortunes"):
        flat -= 5
        notes.append("Fukurokujin's Curse -5 (Lore TN +5)")

    # Seven Fortunes' Blessing: Jurojin - +2k0 resist poison/disease
    if sk == "poison_resist" and _has_adv_containing(character, "jurojin") and _has_adv_containing(character, "seven fortunes"):
        rolled += 2
        notes.append("Jurojin's Blessing +2k0 (resist poison/disease)")

    # Seven Fortunes' Curse: Jurojin - -2k0 resist poison/disease
    if sk == "poison_resist" and _has_disadv_containing(character, "jurojin") and _has_disadv_containing(character, "seven fortunes"):
        rolled -= 2
        notes.append("Jurojin's Curse -2k0 (resist poison/disease)")

    # Weakness: chosen Trait treated as 1 Rank lower → -1k1
    weak_param = _get_disadv_param(character, "Weakness")
    if weak_param and weak_param.lower() == tr:
        rolled -= 1
        kept -= 1
        notes.append(f"Weakness -1k1 ({weak_param}: Trait treated as 1 lower)")

    # Doubt: mandatory Raise that does nothing on rolls with the named skill (+5 TN)
    doubt_param = _get_disadv_param(character, "Doubt")
    if doubt_param and doubt_param.lower() == sk:
        flat -= 5
        notes.append(f"Doubt -5 ({doubt_param}: Must call 1 Raise that does nothing)")

    # --- Skill Mastery Abilities (L5R 4e RAW) ---
    _sr = character.skills.get(skill_name, 0)

    # Cross-skill: Hunting R5 grants +1k0 Stealth in wilderness
    if sk == "stealth" and character.skills.get("Hunting", 0) >= 5:
        notes.append("Hunting R5: +1k0 Stealth in wilderness (DM: apply if in wilderness)")

    if sk == "acting":
        if _sr >= 7:
            notes.append("Acting R7: Disguise TN reduced by 15 (total)")
        elif _sr >= 5:
            notes.append("Acting R5: Disguise TN reduced by 10 (total)")
        elif _sr >= 3:
            notes.append("Acting R3: Disguise TN reduced by 5")

    elif sk == "calligraphy":
        if _sr >= 5:
            notes.append("Calligraphy R5: +10 when breaking a code or cipher")

    elif sk == "courtier":
        if is_contested and _sr >= 5:
            rolled += 1
            notes.append("Courtier R5: +1k0 (Contested Roll)")

    elif sk == "divination":
        if _sr >= 5:
            notes.append("Divination R5: Second attempt without Void Point cost")

    elif sk == "etiquette":
        if is_contested and _sr >= 5:
            rolled += 1
            notes.append("Etiquette R5: +1k0 (Contested Roll)")

    elif sk == "investigation":
        if _sr >= 3:
            notes.append("Investigation R3: Second Search attempt without TN increase")
        if is_contested and _sr >= 5:
            flat += 5
            notes.append("Investigation R5: +5 (Contested Roll)")
        if _sr >= 7:
            notes.append("Investigation R7: Third Search attempt if second fails")

    elif sk == "medicine":
        if _sr >= 5:
            notes.append("Medicine R5: Wound healing +1k0")

    elif sk == "meditation":
        if _sr >= 7:
            notes.append("Meditation R7: Restores up to 3 Void Points")
        elif _sr >= 3:
            notes.append("Meditation R3: Restores up to 2 Void Points")
        if _sr >= 5 and emphasis and emphasis.lower() == "fasting":
            flat += 5
            notes.append("Meditation R5: +5 (Fasting TN reduced by 5)")

    elif sk == "sincerity":
        if is_contested and _sr >= 5:
            flat += 5
            notes.append("Sincerity R5: +5 (Contested Roll)")

    elif sk == "spellcraft":
        if _sr >= 5:
            notes.append("Spellcraft R5: +1k0 on Spell Casting Rolls")

    elif sk == "tea ceremony":
        if _sr >= 5:
            notes.append("Tea Ceremony R5: Participants regain 2 Void Points instead of 1")

    # --- Bugei (non-weapon) Mastery Abilities ---

    elif sk == "athletics":
        if _sr >= 5:
            notes.append("Athletics R5: No movement penalties regardless of terrain")
        elif _sr >= 3:
            notes.append("Athletics R3: Moderate Terrain unimpeded; Difficult Terrain Water -1 instead of -2")
        if _sr >= 7:
            notes.append("Athletics R7: +5 feet to one Move Action per Round")

    elif sk == "battle":
        if _sr >= 5:
            notes.append(f"Battle R5: +{_sr} Initiative in Skirmishes (add Battle Skill Rank)")

    elif sk == "defense":
        if _sr >= 3:
            notes.append("Defense R3: Retain previous roll in maintained Full Defense")
        if _sr >= 5:
            notes.append("Defense R5: Armor TN +3 in Defense and Full Defense Stances")
        if _sr >= 7:
            notes.append("Defense R7: One Simple Action in Full Defense (no attacks)")

    elif sk == "horsemanship":
        if _sr >= 3:
            notes.append("Horsemanship R3: Full Attack Stance allowed on horseback")
        if _sr >= 7:
            notes.append("Horsemanship R7: Mounting is a Free Action, dismounting is Free")
        elif _sr >= 5:
            notes.append("Horsemanship R5: Mounting is Simple Action, dismounting is Free")

    elif sk == "hunting":
        if _sr >= 5:
            notes.append("Hunting R5: +1k0 to Stealth in wilderness")

    elif sk == "iaijutsu":
        if _sr >= 3:
            notes.append("Iaijutsu R3: Readying katana is a Free Action")
        if _sr >= 5:
            notes.append("Iaijutsu R5: Free Raise on Focus roll during Iaijutsu Duel")
        if _sr >= 7:
            notes.append("Iaijutsu R7: +2k2 Focus if Assessment exceeds opponent by 10+ (instead of +1k1)")

    # --- Merchant Mastery Abilities ---

    elif sk == "animal handling":
        if _sr >= 3:
            notes.append("Animal Handling R3: Trained animals may be used by others")
        if _sr >= 5:
            notes.append("Animal Handling R5: Command trained animals to attack a target")
        if _sr >= 7:
            notes.append("Animal Handling R7: Animals may be commanded non-verbally")

    elif sk == "commerce":
        if _sr >= 5:
            notes.append("Commerce R5: May adjust buy/sell price by up to 20%")

    elif sk == "engineering":
        if _sr >= 5:
            notes.append("Engineering R5: +5 on Cooperative or Cumulative Skill Rolls")

    elif sk == "sailing":
        if _sr >= 5:
            notes.append("Sailing R5: +5 on Cooperative or Cumulative Skill Rolls")

    # --- Low Skill Mastery Abilities ---

    elif sk == "forgery":
        if _sr >= 7:
            notes.append("Forgery R7: +1k1 to forgery detection TN (total)")
        elif _sr >= 3:
            notes.append("Forgery R3: +1k0 to forgery detection TN")
        if _sr >= 5:
            notes.append("Forgery R5: +1k0 to detect others' forgeries")

    elif sk == "intimidation":
        if is_contested and _sr >= 5:
            flat += 5
            notes.append("Intimidation R5: +5 (Contested Roll)")

    elif sk == "sleight of hand":
        if _sr >= 5:
            notes.append("Sleight of Hand R5: Conceal Emphasis may hide small weapons")

    elif sk == "stealth":
        if _sr >= 7:
            notes.append("Stealth R7: Free Move Actions allowed while using Stealth")
        elif _sr >= 5:
            notes.append("Stealth R5: Stealth movement = Water x 10")
        elif _sr >= 3:
            notes.append("Stealth R3: Stealth movement = Water x 5")

    elif sk == "temptation":
        if is_contested and _sr >= 5:
            flat += 5
            notes.append("Temptation R5: +5 (Contested Roll)")

    elif sk == "teppoudo":
        if _sr >= 5:
            notes.append("Teppoudo R5: Loading requires one less Complex Action")

    # Rank 10 universal mastery: Free Raise on all rolls using that Skill
    if character.skills.get(skill_name, 0) >= 10:
        notes.append(f"**{skill_name} R10**: Free Raise (DM: reduce declared raises by 1)")

    # Armor skill check penalties (L5R 4e Equipment)
    armor_pen, armor_notes = _armor_skill_penalty(character, skill_name, trait_name)
    flat += armor_pen
    notes.extend(armor_notes)

    return rolled, kept, flat, notes


# ---------------------------------------------------------------------------
# Void Point spend restrictions (Momoku, Consumed: Determination, FoB)
# ---------------------------------------------------------------------------


def can_spend_void_on_roll(
    character: Character,
    *,
    skill_name: str = "",
    is_wound_reduction: bool = False,
) -> tuple[bool, str]:
    """Check if this character can spend a Void Point for the given purpose.

    Returns (True, "") if allowed, or (False, reason) if blocked.
    """
    if _has_disadv(character, "Momoku"):
        return False, "Momoku: may only spend VP on School Techniques"

    if not is_wound_reduction:
        if _has_disadv_containing(character, "consumed") and _has_disadv_containing(character, "determination"):
            return False, "Consumed (Determination): cannot spend VP to enhance die rolls"

    if is_wound_reduction:
        if _has_disadv_containing(character, "failure of bushido") and _has_disadv_containing(character, "duty"):
            return False, "Failure of Bushido (Duty): cannot spend VP to negate Wounds"

    if skill_name.lower() == "sincerity":
        if _has_disadv_containing(character, "failure of bushido") and _has_disadv_containing(character, "honesty"):
            return False, "Failure of Bushido (Honesty): cannot spend VP on Sincerity"

    return True, ""


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
