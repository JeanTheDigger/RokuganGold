"""L5R 4e individual combat — the core resolution, ported from
`simulation/individual_combat.gd` (s40) and `simulation/wound_system.gd`.

This is the CORE only. The GDScript layers on kata, kiho, mutations, advantages,
spirit-creature stat blocks, void-point spends, dual-wielding, mounted combat,
skill masteries (R3/R5/R7 damage bonuses and 9-explosions), and per-round
participant state — all persistent-world combat features the bot does not model.
What is reproduced here is exactly what the GDScript does with those layers
inert:

  Armor TN      = Reflexes x 5 + 5 + armor_tn_bonus  (+ stance)
  Attack roll   = (trait + weapon skill) keep trait, vs Armor TN, raises x5 to TN,
                  minus the attacker's wound penalty; explodes only if skilled.
                  trait = Agility for melee, Reflexes for bows/iaijutsu weapons.
  Damage roll   = weapon dice + Strength (melee, if strength_adds) + increased-
                  damage raises, exploding on 10, kept unchanged.
  Wound apply   = max(0, raw_damage - target armor_reduction) added to wounds_taken.

Stances modelled: Attack (0), Full Attack (attacker +2k1 to hit / -10 own Armor
TN), Defense (defender +Air ring + Defense skill to Armor TN), Center (0). Full
Defense needs a roll and is left to the DM via a manual TN adjustment.

No game values are invented — every number traces to the GDScript / GDD.
"""

from __future__ import annotations

from . import stats
from .character import Character
from .dice import DiceEngine

# Weapon catalog subset (values verbatim from individual_combat.gd WEAPON_CATALOG).
# Keys used by the bot: rolled, kept, strength_adds, skill, trait, melee, size,
# and no_explode (shinai). Special keys (thrown/charge/armor_tn_mult/break/etc.)
# are intentionally omitted — those maneuvers are not modelled at this phase.
WEAPON_CATALOG: dict[str, dict] = {
    # Swords (Kenjutsu)
    "katana": {"rolled": 3, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium"},
    "wakizashi": {"rolled": 2, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Small"},
    "no_dachi": {"rolled": 3, "kept": 3, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Large"},
    "bokken": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium"},
    "ninja_to": {"rolled": 3, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium"},
    "parangu": {"rolled": 2, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium"},
    "scimitar": {"rolled": 2, "kept": 3, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium"},
    "shinai": {"rolled": 0, "kept": 1, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium", "no_explode": True},
    # Knives
    "tanto": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Knives", "trait": "agility", "melee": True, "size": "Small"},
    "aiguchi": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Knives", "trait": "agility", "melee": True, "size": "Small"},
    "sai": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Knives", "trait": "agility", "melee": True, "size": "Small"},
    "jitte": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Knives", "trait": "agility", "melee": True, "size": "Small"},
    "kama": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Knives", "trait": "agility", "melee": True, "size": "Small"},
    # Heavy Weapons
    "tetsubo": {"rolled": 3, "kept": 3, "strength_adds": True, "skill": "Heavy Weapons", "trait": "agility", "melee": True, "size": "Large"},
    "dai_tsuchi": {"rolled": 5, "kept": 2, "strength_adds": True, "skill": "Heavy Weapons", "trait": "agility", "melee": True, "size": "Large"},
    "masakiri": {"rolled": 2, "kept": 3, "strength_adds": True, "skill": "Heavy Weapons", "trait": "agility", "melee": True, "size": "Medium"},
    "ono": {"rolled": 0, "kept": 4, "strength_adds": True, "skill": "Heavy Weapons", "trait": "agility", "melee": True, "size": "Large"},
    # Polearms
    "naginata": {"rolled": 3, "kept": 2, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large"},
    "bisento": {"rolled": 3, "kept": 3, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large"},
    "nagamaki": {"rolled": 2, "kept": 3, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large"},
    # Spears
    "yari": {"rolled": 2, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    "lance": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    "nage_yari": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    # Staves
    "bo": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Large"},
    "jo": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    "nunchaku": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Small"},
    "tonfa": {"rolled": 0, "kept": 3, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    # War fan
    "war_fan": {"rolled": 0, "kept": 1, "strength_adds": True, "skill": "War Fan", "trait": "agility", "melee": True, "size": "Small"},
    # Bows (Kyujutsu; Reflexes; no Strength to damage)
    "yumi": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Large"},
    "dai_kyu": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small"},
    "han_kyu": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small"},
    # Polearms (grappling)
    "sasumata": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large"},
    "sadegarami": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large"},
    # More spears
    "kumade": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    "mai_chong": {"rolled": 0, "kept": 3, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    # More staves
    "machi_kanshisha": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    "sang_kauw": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    # Chain weapons
    "kusarigama": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Chain Weapons", "trait": "agility", "melee": True, "size": "Large"},
    "kyoketsu_shogi": {"rolled": 0, "kept": 1, "strength_adds": True, "skill": "Chain Weapons", "trait": "agility", "melee": True, "size": "Large"},
    "manrikikusari": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Chain Weapons", "trait": "agility", "melee": True, "size": "Large"},
    # Thrown / ninja (Ninjutsu; no Strength to damage)
    "shuriken": {"rolled": 1, "kept": 1, "strength_adds": False, "skill": "Ninjutsu", "trait": "agility", "melee": False, "size": "Small"},
    "tsubute": {"rolled": 1, "kept": 1, "strength_adds": False, "skill": "Ninjutsu", "trait": "agility", "melee": False, "size": "Small"},
    "blowgun": {"rolled": 0, "kept": 1, "strength_adds": False, "skill": "Ninjutsu", "trait": "agility", "melee": False, "size": "Medium"},
    # Unarmed
    "unarmed": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Jiujutsu", "trait": "agility", "melee": True, "size": "Small"},
}

# Armor catalog (verbatim from simulation/armor_system.gd ARMOR_CATALOG).
ARMOR_CATALOG: dict[str, dict] = {
    "bogu": {"tn_bonus": 0, "reduction": 1, "is_heavy": False, "penalty_kind": "none"},
    "ashigaru": {"tn_bonus": 3, "reduction": 1, "is_heavy": False, "penalty_kind": "none"},
    "tatami": {"tn_bonus": 4, "reduction": 1, "is_heavy": False, "penalty_kind": "none"},
    "light": {"tn_bonus": 5, "reduction": 3, "is_heavy": False, "penalty_kind": "athletics_stealth"},
    "heavy": {"tn_bonus": 10, "reduction": 5, "is_heavy": True, "penalty_kind": "agi_ref"},
    "tetsu_do": {"tn_bonus": 13, "reduction": 8, "is_heavy": True, "penalty_kind": "agi_ref_iron"},
    "riding": {"tn_bonus": 4, "reduction": 4, "is_heavy": False, "penalty_kind": "agi_ref_not_mounted"},
}


def get_armor(armor_name: str) -> dict | None:
    return ARMOR_CATALOG.get(armor_name.lower().strip())

# individual_combat.gd DEFAULT_WEAPON — used for any unknown weapon name.
DEFAULT_WEAPON: dict = {
    "rolled": 2, "kept": 1, "strength_adds": True, "skill": "Kenjutsu",
    "trait": "agility", "melee": True, "size": "Medium",
}

# individual_combat.gd stance constants.
STANCE_ARMOR_TN_BONUS = {"attack": 0, "full_attack": -10, "defense": 0, "center": 0}
STANCE_ATTACK_ROLLED_BONUS = {"attack": 0, "full_attack": 2, "defense": 0, "center": 0}
STANCE_ATTACK_KEPT_BONUS = {"attack": 0, "full_attack": 1, "defense": 0, "center": 0}


def get_weapon_profile(weapon_name: str) -> dict:
    return WEAPON_CATALOG.get(weapon_name.lower().strip(), DEFAULT_WEAPON)


def armor_tn(target: Character, defender_stance: str = "attack", extra: int = 0) -> int:
    """Target's Armor TN. Base = Reflexes x 5 + 5 + armor bonus (CharacterStats.get_armor_tn),
    plus the defender's stance. `extra` is a DM-supplied situational modifier."""
    base = target.reflexes * 5 + 5 + target.armor_tn_bonus
    base += STANCE_ARMOR_TN_BONUS.get(defender_stance, 0)
    if defender_stance == "defense":
        # Defense stance: + Air ring + Defense skill rank (rolled bonus not modelled;
        # this matches the GDScript's non-rolled Defense-stance contribution).
        base += stats.ring_value(target, "air") + target.skills.get("Defense", 0)
    return base + extra


def resolve_attack(
    attacker: Character,
    weapon_name: str,
    target_armor_tn: int,
    raises: int,
    dice_engine: DiceEngine,
    attacker_stance: str = "attack",
    increased_damage: int = 0,
    bonus_rolled: int = 0,
    bonus_kept: int = 0,
    extra_flat: int = 0,
) -> dict:
    """Resolve one attack roll vs a Target Number. `increased_damage` are raises
    spent on the Increased Damage maneuver: they raise the TN like any called
    raise AND add +1 rolled damage die each on the follow-up damage roll.
    `bonus_rolled`/`bonus_kept` are extra dice from a Void Point spend (+1k1).
    `extra_flat` is a flat bonus added to the attack-roll total (e.g. an active
    kata's North/South Wind Air-Ring bonus, per s30)."""
    weapon = get_weapon_profile(weapon_name)
    skill_name = weapon.get("skill", "Kenjutsu")
    skill_rank = attacker.skills.get(skill_name, 0)

    trait_name = "reflexes" if weapon.get("trait") == "reflexes" else "agility"
    trait_value = attacker.reflexes if trait_name == "reflexes" else attacker.agility

    rolled = trait_value + skill_rank
    kept = trait_value
    rolled += STANCE_ATTACK_ROLLED_BONUS.get(attacker_stance, 0)
    kept += STANCE_ATTACK_KEPT_BONUS.get(attacker_stance, 0)
    rolled += bonus_rolled  # Void Point spend (+1k1); RAW: valid on the attack roll, not damage
    kept += bonus_kept

    wound_penalty = stats.wound_penalty(attacker)  # <= 0
    flat_bonus = wound_penalty + extra_flat
    total_raises = raises + increased_damage
    explodes = skill_rank > 0

    result = dice_engine.roll_check(rolled, kept, target_armor_tn, total_raises, flat_bonus, explodes)
    return {
        "success": result["success"],
        "hit": result["success"],
        "roll": result["total"],
        "target_tn": result["tn"],
        "margin": result["margin"],
        "dice": result["dice"],
        "skill_name": skill_name,
        "skill_rank": skill_rank,
        "trait_name": trait_name,
        "weapon_name": weapon_name,
        "unskilled": skill_rank == 0,
        "wound_penalty": wound_penalty,
        "raises": total_raises,
    }


def resolve_damage(
    attacker: Character,
    weapon_name: str,
    dice_engine: DiceEngine,
    increased_damage: int = 0,
    extra_rolled: int = 0,
) -> dict:
    """Roll raw damage (before the target's armor reduction). `extra_rolled`
    are extra rolled damage dice from an active kata (e.g. Waves upon the
    Breakers' +1k0, per s30) — added like Increased Damage but with no TN cost."""
    weapon = get_weapon_profile(weapon_name)
    rolled = weapon.get("rolled", 2)
    kept = weapon.get("kept", 1)
    if weapon.get("strength_adds", True) and weapon.get("melee", True):
        rolled += attacker.strength
    rolled += increased_damage  # Increased Damage maneuver: +1k0 per raise
    rolled += extra_rolled       # active-kata bonus damage dice (no TN cost)
    can_explode = not weapon.get("no_explode", False)
    res = dice_engine.roll_damage(rolled, kept, 0, 0, False, False, can_explode)
    return {
        "rolled": rolled,
        "kept": kept,
        "raw_damage": res["raw"],
        "dice": res["dice"],
    }


def apply_damage(target: Character, raw_damage: int, reduction: int | None = None) -> dict:
    """Apply raw damage through the target's armor reduction (wound_system.gd).
    Mutates target.wounds_taken. Returns before/after wound-level info."""
    if reduction is None:
        reduction = target.armor_reduction
    final_damage = max(0, raw_damage - reduction)
    old_level = stats.wound_level_name(target)
    target.wounds_taken += final_damage
    new_level = stats.wound_level_name(target)
    return {
        "raw_damage": raw_damage,
        "reduction": reduction,
        "final_damage": final_damage,
        "old_wound_level": old_level,
        "new_wound_level": new_level,
        "is_dead": stats.is_dead(target),
        "level_changed": old_level != new_level,
    }


# ---------------------------------------------------------------------------
# Initiative and contested maneuvers (individual_combat.gd s40)
# ---------------------------------------------------------------------------

# Maneuver raise costs (individual_combat.gd MANEUVER_RAISES). Only the ones the
# bot resolves are listed; each is a called Raise on the attack (raises the TN).
MANEUVER_RAISES = {"feint": 2, "disarm": 3, "knockdown": 2}


def roll_initiative(character: Character, dice_engine: DiceEngine):
    """Initiative Roll & Keep: (Reflexes + Insight Rank) keep Reflexes
    (character_stats.gd get_initiative_rolled / _kept)."""
    ir = stats.insight_rank(character)
    return dice_engine.roll_and_keep(character.reflexes + ir, character.reflexes)


def resolve_disarm(attacker: Character, defender: Character, dice_engine: DiceEngine) -> dict:
    """Disarm (s40): 2k1 damage regardless of weapon, plus a contested Strength
    roll (Strength k Strength, non-exploding, + wound penalties). Attacker wins ties-broken by >."""
    dmg = dice_engine.roll_damage(2, 1)
    a = dice_engine.roll_and_keep(max(attacker.strength, 1), max(attacker.strength, 1), False)
    d = dice_engine.roll_and_keep(max(defender.strength, 1), max(defender.strength, 1), False)
    a_total = a.total + stats.wound_penalty(attacker)
    d_total = d.total + stats.wound_penalty(defender)
    return {
        "damage": dmg["raw"],
        "damage_dice": dmg["dice"],
        "attacker_roll": a_total,
        "defender_roll": d_total,
        "disarmed": a_total > d_total,
    }


def resolve_knockdown(
    attacker: Character, defender: Character, dice_engine: DiceEngine, is_quadruped: bool = False
) -> dict:
    """Knockdown (s40): contested Strength roll (non-exploding, + wound penalties);
    a quadruped defender adds +4. No inherent damage."""
    a = dice_engine.roll_and_keep(max(attacker.strength, 1), max(attacker.strength, 1), False)
    d = dice_engine.roll_and_keep(max(defender.strength, 1), max(defender.strength, 1), False)
    a_total = a.total + stats.wound_penalty(attacker)
    d_total = d.total + stats.wound_penalty(defender) + (4 if is_quadruped else 0)
    return {
        "attacker_roll": a_total,
        "defender_roll": d_total,
        "knocked_down": a_total > d_total,
    }


def compute_feint_bonus(attack_margin: int, attacker_insight_rank: int) -> int:
    """Feint (s40): half the attack margin, capped at 5 x Insight Rank, added to damage."""
    return min(attack_margin // 2, 5 * attacker_insight_rank)
