"""L5R 4e individual combat: the core resolution, ported from
`simulation/individual_combat.gd` (s40) and `simulation/wound_system.gd`.

This is the CORE only. The GDScript layers on kata, kiho, mutations, advantages,
spirit-creature stat blocks, void-point spends, dual-wielding, mounted combat,
skill masteries (R3/R5/R7 damage bonuses and 9-explosions), and per-round
participant state: all persistent-world combat features the bot does not model.
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

No game values are invented: every number traces to the GDScript / GDD.
"""

from __future__ import annotations

import math

from . import stats
from .character import Character
from .dice import DiceEngine

# Weapon catalog subset (values verbatim from individual_combat.gd WEAPON_CATALOG).
# Keys used by the bot: rolled, kept, strength_adds, skill, trait, melee, size,
# no_explode (shinai), double_reduction (bokken), armor_tn_mult (arrows/blowgun/
# firearms), half_range, penalty_mounted, penalty_on_foot (bows/lance),
# ignore_all_reduction (bo-hiya), ignore_armor_reduction (firearms: zeroes armor
# Reduction only), ignore_creature_reduction (hand-cannon: zeroes natural toughness),
# break_threshold (kumade/lance/parangu/ninja-to), void_damage (katana: VP for +1k1),
# grapple_capable (sasumata/sodegarami: can initiate grapple while armed).
# Extraordinary weapon qualities (s39 crafting): balanced (+1k0 attack), radiant
# (jade for invuln), swift (+5 init), true (−Strength Reduction), unbreakable
# (can't break). Stored on Character.weapon_qualities; checked via has_weapon_quality().
WEAPON_CATALOG: dict[str, dict] = {
    # Swords (Kenjutsu)
    "katana": {"rolled": 3, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium", "void_damage": True},
    "wakizashi": {"rolled": 2, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Small"},
    "no_dachi": {"rolled": 3, "kept": 3, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Large"},
    "bokken": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium", "double_reduction": True},
    "ninja_to": {"rolled": 3, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium", "break_threshold": 40},
    "parangu": {"rolled": 2, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "agility", "melee": True, "size": "Medium", "break_threshold": 30},
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
    "lance": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large", "break_threshold": 30, "penalty_on_foot": 10, "penalty_mounted": 5},
    "nage_yari": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    # Staves
    "bo": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Large"},
    "jo": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    "nunchaku": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Small"},
    "tonfa": {"rolled": 0, "kept": 3, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    # War fan
    "war_fan": {"rolled": 0, "kept": 1, "strength_adds": True, "skill": "War Fan", "trait": "agility", "melee": True, "size": "Small"},
    # Bows (Kyujutsu; Reflexes; no Strength to damage).
    # penalty_mounted / penalty_on_foot: +N TN on attack rolls in that condition (s39).
    "yumi": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Large", "penalty_mounted": 10},
    "dai_kyu": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small", "penalty_on_foot": 10},
    "han_kyu": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small", "penalty_mounted": 10},
    # Arrows (s39 ammunition - select as weapon to use a specific arrow type;
    # Kyujutsu / Reflexes same as bows; DR from the arrow, not the bow).
    # armor_tn_mult: multiplier on the target's armor TN bonus from armor.
    "willow_leaf_arrow": {"rolled": 2, "kept": 2, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small"},
    "armor_piercing_arrow": {"rolled": 1, "kept": 1, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small", "armor_tn_mult": 0},
    "flesh_cutter_arrow": {"rolled": 2, "kept": 3, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small", "armor_tn_mult": 2, "half_range": True},
    "humming_bulb_arrow": {"rolled": 0, "kept": 1, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small"},
    "rope_cutter_arrow": {"rolled": 1, "kept": 1, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small", "half_range": True},
    "bo_hiya": {"rolled": 3, "kept": 3, "strength_adds": False, "skill": "Kyujutsu", "trait": "reflexes", "melee": False, "size": "Small", "ignore_all_reduction": True},
    # Polearms (grappling)
    "sasumata": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large", "grapple_capable": True},
    "sodegarami": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Polearms", "trait": "agility", "melee": True, "size": "Large", "grapple_capable": True},
    # More spears
    "kumade": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large", "break_threshold": 25},
    "mai_chong": {"rolled": 0, "kept": 3, "strength_adds": True, "skill": "Spears", "trait": "agility", "melee": True, "size": "Large"},
    # More staves
    "machi_kanshisha": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    "sang_kauw": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Staves", "trait": "agility", "melee": True, "size": "Medium"},
    # Chain weapons
    "kusarigama": {"rolled": 0, "kept": 2, "strength_adds": True, "skill": "Chain Weapons", "trait": "agility", "melee": True, "size": "Large"},
    "kyoketsu_shogi": {"rolled": 0, "kept": 1, "strength_adds": True, "skill": "Chain Weapons", "trait": "agility", "melee": True, "size": "Large", "armor_tn_mult": 2},
    "manrikikusari": {"rolled": 1, "kept": 1, "strength_adds": True, "skill": "Chain Weapons", "trait": "agility", "melee": True, "size": "Large"},
    # Thrown / ninja (Ninjutsu; no Strength to damage; damage does NOT explode
    # by default: s24: "Rank 5: Damage dice explode normally (they do not
    # normally)"; Ninjutsu R5 mastery overrides this).
    "shuriken": {"rolled": 1, "kept": 1, "strength_adds": False, "skill": "Ninjutsu", "trait": "agility", "melee": False, "size": "Small", "no_explode": True},
    "tsubute": {"rolled": 1, "kept": 1, "strength_adds": False, "skill": "Ninjutsu", "trait": "agility", "melee": False, "size": "Small", "no_explode": True},
    "blowgun": {"rolled": 0, "kept": 1, "strength_adds": False, "skill": "Ninjutsu", "trait": "agility", "melee": False, "size": "Medium", "no_explode": True, "armor_tn_mult": 3},
    # Thrown variants - same weapon used as a ranged attack (Reflexes, not Agility).
    # Select the _thrown entry when the weapon is hurled instead of wielded in melee.
    "wakizashi_thrown": {"rolled": 2, "kept": 2, "strength_adds": True, "skill": "Kenjutsu", "trait": "reflexes", "melee": False, "size": "Small"},
    "yari_thrown": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "reflexes", "melee": False, "size": "Large"},
    "nage_yari_thrown": {"rolled": 1, "kept": 2, "strength_adds": True, "skill": "Spears", "trait": "reflexes", "melee": False, "size": "Large"},
    "mai_chong_thrown": {"rolled": 0, "kept": 3, "strength_adds": True, "skill": "Spears", "trait": "reflexes", "melee": False, "size": "Large"},
    # Unarmed
    "unarmed": {"rolled": 0, "kept": 1, "strength_adds": True, "skill": "Jiujutsu", "trait": "agility", "melee": True, "size": "Small"},
    # Firearms (Teppoudo / Intelligence). General rule: ignore armor TN + armor Reduction.
    # Kakiyari can be used as a yari in melee (DR 1k1) - select "yari" for that mode.
    "kakiyari": {"rolled": 3, "kept": 2, "strength_adds": False, "skill": "Teppoudo", "trait": "intelligence", "melee": False, "size": "Large", "armor_tn_mult": 0, "ignore_armor_reduction": True},
    # Hand-Cannon: also ignores natural toughness Reduction. Can be used as tetsubo in melee.
    "hand_cannon": {"rolled": 4, "kept": 3, "strength_adds": False, "skill": "Teppoudo", "trait": "intelligence", "melee": False, "size": "Large", "armor_tn_mult": 0, "ignore_armor_reduction": True, "ignore_creature_reduction": True},
    "bajozutsu": {"rolled": 3, "kept": 2, "strength_adds": False, "skill": "Teppoudo", "trait": "intelligence", "melee": False, "size": "Small", "armor_tn_mult": 0, "ignore_armor_reduction": True},
    "teppo": {"rolled": 3, "kept": 3, "strength_adds": False, "skill": "Teppoudo", "trait": "intelligence", "melee": False, "size": "Large", "armor_tn_mult": 0, "ignore_armor_reduction": True},
}

# Armor catalog (verbatim from GDD s39 and simulation/armor_system.gd).
ARMOR_CATALOG: dict[str, dict] = {
    "bogu": {"tn_bonus": 0, "reduction": 1, "is_heavy": False, "penalty_kind": "none", "cost": 1, "special": ""},
    "ashigaru": {"tn_bonus": 3, "reduction": 1, "is_heavy": False, "penalty_kind": "none", "cost": 5, "special": ""},
    "tatami": {"tn_bonus": 4, "reduction": 1, "is_heavy": False, "penalty_kind": "none", "cost": 10, "special": ""},
    "light": {"tn_bonus": 5, "reduction": 3, "is_heavy": False, "penalty_kind": "athletics_stealth", "cost": 25, "special": "Increases TN of Athletics and Stealth rolls by +5."},
    "heavy": {"tn_bonus": 10, "reduction": 5, "is_heavy": True, "penalty_kind": "agi_ref", "cost": 40, "special": "Increases TN of all Agility and Reflexes skill rolls by +5."},
    "tetsu_do": {"tn_bonus": 13, "reduction": 8, "is_heavy": True, "penalty_kind": "agi_ref_iron", "cost": 100, "special": "Counts as Heavy Armor. Increases TN of all Agility/Reflexes skill rolls by +10 (+5 if Strength 5+)."},
    "riding": {"tn_bonus": 4, "reduction": 4, "is_heavy": False, "penalty_kind": "agi_ref_not_mounted", "cost": 55, "tn_bonus_mounted": 12, "special": "Armor TN +12 on horseback, +4 otherwise. Increases TN of Agility/Reflexes skill rolls by +5 except when mounted."},
}


def get_armor(armor_name: str) -> dict | None:
    return ARMOR_CATALOG.get(armor_name.lower().strip())


def armor_attack_penalty(attacker: Character) -> tuple[int, str]:
    """Flat penalty on the attack roll from the attacker's armor (s39).
    Heavy: +5 TN on Agility/Reflexes skills (−5 flat). Tetsu-Do: +10 (or +5
    if Strength ≥ 5). Hida Bushi R1 (Way of the Crab) ignores heavy armor
    penalties. Returns (penalty, note) where penalty is ≤ 0."""
    if not attacker.armor_name:
        return 0, ""
    prof = get_armor(attacker.armor_name)
    if prof is None:
        return 0, ""
    kind = prof.get("penalty_kind", "none")
    if kind not in ("agi_ref", "agi_ref_iron"):
        return 0, ""
    known = {t.lower() for t in attacker.techniques}
    if "the way of the crab" in known:
        return 0, ""
    if kind == "agi_ref":
        return -5, "Heavy Armor: −5 attack (Agi/Ref skill TN +5)"
    pen = -5 if attacker.strength >= 5 else -10
    return pen, f"Tetsu-Do: {pen} attack (Agi/Ref skill TN +{-pen}, Str {attacker.strength})"


def roll_full_defense(
    reflexes: int,
    defense_skill: int,
    dice_engine: DiceEngine,
    wound_penalty: int = 0,
    extra_rolled: int = 0,
    extra_flat: int = 0,
) -> dict:
    """Full Defense Stance (s40): Defense/Reflexes roll, add half (rounded up)
    to Armor TN until the character's next Turn. Complex Action."""
    rolled = reflexes + defense_skill + extra_rolled
    kept = reflexes
    explodes = defense_skill > 0
    result = dice_engine.roll_and_keep(max(1, rolled), max(1, kept), explodes)
    total = result.total + wound_penalty + extra_flat
    bonus = max(0, math.ceil(total / 2))
    return {
        "total": total,
        "bonus": bonus,
        "rolled": rolled,
        "kept": kept,
        "dice": result,
        "wound_penalty": wound_penalty,
    }


# individual_combat.gd DEFAULT_WEAPON: used for any unknown weapon name.
DEFAULT_WEAPON: dict = {
    "rolled": 2, "kept": 1, "strength_adds": True, "skill": "Kenjutsu",
    "trait": "agility", "melee": True, "size": "Medium",
}

# individual_combat.gd stance constants.
STANCE_ARMOR_TN_BONUS = {"attack": 0, "full_attack": -10, "defense": 0, "center": 0}
STANCE_ATTACK_ROLLED_BONUS = {"attack": 0, "full_attack": 2, "defense": 0, "center": 0}
STANCE_ATTACK_KEPT_BONUS = {"attack": 0, "full_attack": 1, "defense": 0, "center": 0}


def grapple_initiate_tn(target: Character, defender_stance: str = "attack", extra: int = 0) -> int:
    """Grapple initiation TN (s40): Armor TN minus armor's TN bonus."""
    base = target.reflexes * 5 + 5
    base += STANCE_ARMOR_TN_BONUS.get(defender_stance, 0)
    if defender_stance == "defense":
        base += stats.ring_value(target, "air") + target.skills.get("Defense", 0)
    return base + extra


def resolve_grapple_initiate(
    attacker: Character,
    target_tn: int,
    dice_engine: DiceEngine,
    extra_flat: int = 0,
    extra_rolled: int = 0,
) -> dict:
    """Grapple initiation attack: Jiujutsu/Agility vs modified Armor TN."""
    agility = attacker.agility
    jiujutsu = attacker.skills.get("Jiujutsu", 0)
    rolled = agility + jiujutsu + extra_rolled
    kept = agility
    explodes = jiujutsu > 0
    wound_pen = stats.wound_penalty(attacker)
    result = dice_engine.roll_and_keep(max(1, rolled), max(1, kept), explodes)
    total = result.total + extra_flat + wound_pen
    return {
        "hit": total >= target_tn,
        "roll": total,
        "target_tn": target_tn,
        "margin": total - target_tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
        "wound_penalty": wound_pen,
    }


def resolve_grapple_control(
    strength_a: int,
    jiujutsu_a: int,
    strength_b: int,
    jiujutsu_b: int,
    dice_engine: DiceEngine,
    wound_penalty_a: int = 0,
    wound_penalty_b: int = 0,
    extra_rolled_a: int = 0,
    extra_flat_a: int = 0,
    extra_rolled_b: int = 0,
    extra_flat_b: int = 0,
) -> dict:
    """Contested Jiujutsu/Strength roll for grapple control."""
    rolled_a = strength_a + jiujutsu_a + extra_rolled_a
    kept_a = strength_a
    rolled_b = strength_b + jiujutsu_b + extra_rolled_b
    kept_b = strength_b
    explodes_a = jiujutsu_a > 0
    explodes_b = jiujutsu_b > 0
    result_a = dice_engine.roll_and_keep(max(1, rolled_a), max(1, kept_a), explodes_a)
    result_b = dice_engine.roll_and_keep(max(1, rolled_b), max(1, kept_b), explodes_b)
    total_a = result_a.total + wound_penalty_a + extra_flat_a
    total_b = result_b.total + wound_penalty_b + extra_flat_b
    winner = "a"
    if total_b > total_a:
        winner = "b"
    elif total_a == total_b:
        winner = "tie"
    return {
        "winner": winner,
        "total_a": total_a,
        "total_b": total_b,
        "dice_a": result_a,
        "dice_b": result_b,
    }


def spell_casting_tn(mastery_level: int) -> int:
    """Spell casting TN (s31): 5 + (5 × Mastery Level)."""
    return 5 + 5 * mastery_level


def resolve_spell_casting(
    ring_value: int,
    school_rank: int,
    mastery_level: int,
    dice_engine: DiceEngine,
    affinity: bool = False,
    deficiency: bool = False,
    extra_rolled: int = 0,
    extra_kept: int = 0,
    raises: int = 0,
    extra_flat: int = 0,
) -> dict:
    """Spell Casting Roll (s31): (Ring + effective School Rank) keep Ring.

    Affinity: +1 effective School Rank. Deficiency: -1 (0 = cannot cast)."""
    effective_rank = school_rank
    if affinity:
        effective_rank += 1
    if deficiency:
        effective_rank -= 1
    if effective_rank <= 0:
        return {
            "success": False,
            "cannot_cast": True,
            "reason": "Deficiency reduces effective School Rank to 0",
        }
    rolled = ring_value + effective_rank + extra_rolled
    kept = ring_value + extra_kept
    tn = spell_casting_tn(mastery_level)
    effective_tn = tn + raises * 5
    result = dice_engine.roll_and_keep(max(1, rolled), max(1, kept))
    total = result.total + extra_flat
    return {
        "success": total >= effective_tn,
        "cannot_cast": False,
        "total": total,
        "tn": effective_tn,
        "base_tn": tn,
        "margin": total - effective_tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
        "effective_rank": effective_rank,
        "affinity": affinity,
        "deficiency": deficiency,
    }


def normalise_weapon_key(weapon_name: str) -> str:
    """Catalog key form: Lower case, spaces as underscores ("willow leaf arrow" -> "willow_leaf_arrow")."""
    return weapon_name.lower().strip().replace(" ", "_")


def weapon_display(weapon_name: str) -> str:
    return normalise_weapon_key(weapon_name).replace("_", " ")


def get_weapon_profile(weapon_name: str) -> dict:
    return WEAPON_CATALOG.get(normalise_weapon_key(weapon_name), DEFAULT_WEAPON)


# --- Arrows as ammunition (s39) ---------------------------------------------
# An arrow type is "wielded" as the weapon (its DR is the damage) with a bow in
# the other hand. The quiver is the character's inventory: One entry per arrow
# type, keyed by its display name, counting arrows. Each ranged attack with an
# arrow spends one. An arrow type with no inventory entry is untracked (legacy
# sheets that list the arrow among their weapons) and is never depleted.

def is_arrow(weapon_name: str) -> bool:
    key = normalise_weapon_key(weapon_name)
    return key.endswith("_arrow") and key in WEAPON_CATALOG


def is_bow(weapon_name: str) -> bool:
    key = normalise_weapon_key(weapon_name)
    spec = WEAPON_CATALOG.get(key)
    return spec is not None and spec.get("skill") == "Kyujutsu" and not key.endswith("_arrow")


def arrow_inventory_key(character: Character, weapon_name: str) -> str | None:
    """The inventory entry holding this arrow type, or None when untracked."""
    key = normalise_weapon_key(weapon_name)
    for name in character.inventory:
        if normalise_weapon_key(name) == key:
            return name
    return None


def arrow_count(character: Character, weapon_name: str) -> int | None:
    """Arrows of this type in the quiver. None only for a legacy sheet that lists
    the arrow type among its weapons without a quiver entry (untracked); an arrow
    type with no quiver entry and no legacy listing counts as 0."""
    name = arrow_inventory_key(character, weapon_name)
    if name is not None:
        return character.inventory.get(name, 0)
    key = normalise_weapon_key(weapon_name)
    if key in [normalise_weapon_key(w) for w in character.weapons]:
        return None
    return 0


def is_dual_wielding(character: Character) -> bool:
    """Two weapons in hand (s40 dual-wield rules apply). A bow held in the off hand
    while arrows are wielded is how a bow is shot, not dual wielding."""
    main = normalise_weapon_key(character.equipped_weapon or "")
    off = normalise_weapon_key(character.off_hand_weapon or "")
    if not main or not off:
        return False
    if is_arrow(main) and is_bow(off):
        return False
    return True


def consume_arrow(character: Character, weapon_name: str) -> int | None:
    """Spend one arrow. Returns arrows left, or None when the type is untracked."""
    name = arrow_inventory_key(character, weapon_name)
    if name is None:
        return None
    left = max(0, character.inventory.get(name, 0) - 1)
    if left == 0:
        del character.inventory[name]
    else:
        character.inventory[name] = left
    return left


def quiver(character: Character) -> list[tuple[str, int]]:
    """(catalog key, count) for every tracked arrow type with arrows left."""
    out: list[tuple[str, int]] = []
    for name, qty in character.inventory.items():
        if qty > 0 and is_arrow(name):
            out.append((normalise_weapon_key(name), qty))
    return out


def max_raises(character: Character) -> int:
    """GDD s41: maximum called Raises per roll = Void Ring (Free Raises do not count)."""
    return character.void_ring


def emphasis_match(character: Character, skill_name: str, requested: str | None) -> str | None:
    """The sheet's Emphasis in `skill_name` matching `requested` (case-insensitive), or None."""
    if not requested:
        return None
    want = requested.strip().lower()
    for emph in character.emphases.get(skill_name, []):
        if emph.lower() == want:
            return emph
    return None


def weapon_emphasis(character: Character, weapon_name: str) -> str | None:
    """The Emphasis on the weapon's Skill that names this weapon (e.g. Kenjutsu:
    Katana), or None. An Emphasis rerolls 1s once (GDD s04.5 / s24.0)."""
    skill_name = get_weapon_profile(weapon_name).get("skill", "Kenjutsu")
    want = weapon_name.lower().strip().replace("_", " ")
    for emph in character.emphases.get(skill_name, []):
        if emph.lower().replace("_", " ") == want:
            return emph
    return None


def armor_tn(target: Character, defender_stance: str = "attack", extra: int = 0) -> int:
    """Target's Armor TN. Base = Reflexes x 5 + 5 + armor bonus (CharacterStats.get_armor_tn),
    plus the defender's stance. `extra` is a DM-supplied situational modifier."""
    base = target.reflexes * 5 + 5 + target.armor_tn_bonus
    base += STANCE_ARMOR_TN_BONUS.get(defender_stance, 0)
    if defender_stance == "defense":
        base += stats.ring_value(target, "air") + target.skills.get("Defense", 0)
    return base + extra


def arrow_armor_tn_mod(weapon_name: str, target_armor_tn_bonus: int) -> tuple[int, str]:
    """Armor TN adjustment from arrow/blowgun/firearm specials (GDD s39).
    armor_tn_mult 0 = ignores bonus, 2 = doubles, 3 = triples.
    Returns (tn_modifier, note). Modifier is added to the target's Armor TN."""
    wp = get_weapon_profile(weapon_name)
    mult = wp.get("armor_tn_mult")
    if mult is None:
        return 0, ""
    label = weapon_name.replace("_", " ").title()
    adj = target_armor_tn_bonus * (mult - 1)
    if mult == 0:
        return adj, f"{label}: ignores armor TN bonus ({adj:+d})"
    if mult == 2:
        return adj, f"{label}: doubles armor TN bonus ({adj:+d})"
    if mult == 3:
        return adj, f"{label}: triples armor TN bonus ({adj:+d})"
    return adj, f"{label}: armor TN ×{mult} ({adj:+d})"


def staff_armor_tn_mod(attacker: Character, weapon_name: str, target_armor_tn_bonus: int) -> tuple[int, str]:
    """Staff special (L5R 4e Equipment): armor bonuses to Armor TN are doubled
    against attacks made with a staff. Staves R3 mastery negates this penalty.
    Returns (tn_modifier, note). Modifier is added to the target's Armor TN."""
    wp = get_weapon_profile(weapon_name)
    if wp.get("skill") != "Staves":
        return 0, ""
    if target_armor_tn_bonus <= 0:
        return 0, ""
    if attacker.skills.get("Staves", 0) >= 3:
        return 0, "Staves R3: armor TN doubling negated"
    return target_armor_tn_bonus, f"Staff vs armor: Armor TN bonus doubled (+{target_armor_tn_bonus})"


def blowgun_damage_bonus(attacker: Character, weapon_name: str) -> tuple[int, int, str]:
    """Extra damage dice from blowgun Ninjutsu rank scaling (GDD s39).
    Base 0k1; at Ninjutsu 3: 1k1 (+1k0); at Ninjutsu 7: 2k1 (+2k0).
    Returns (extra_rolled, extra_kept, note)."""
    if weapon_name.lower().strip() != "blowgun":
        return 0, 0, ""
    ninjutsu = attacker.skills.get("Ninjutsu", 0)
    if ninjutsu >= 7:
        return 2, 0, "Blowgun DR 2k1 (Ninjutsu 7+)"
    if ninjutsu >= 3:
        return 1, 0, "Blowgun DR 1k1 (Ninjutsu 3+)"
    return 0, 0, ""


FIREARM_WEAPONS: frozenset[str] = frozenset({
    "kakiyari", "hand_cannon", "bajozutsu", "teppo",
})

WEAPON_QUALITIES: frozenset[str] = frozenset({
    "balanced", "radiant", "signature", "swift", "true", "unbreakable",
})


def has_weapon_quality(character: Character, weapon_used: str, quality: str) -> bool:
    """True if the weapon being used is the character's equipped weapon and has the given quality."""
    if not character.weapon_qualities or quality not in character.weapon_qualities:
        return False
    return weapon_used.lower().strip() == character.equipped_weapon.lower().strip()


def weapon_stance_penalty(weapon_name: str, is_mounted: bool) -> tuple[int, str]:
    """Flat penalty from weapon-specific stance restrictions (GDD s39).
    Bows: Dai-kyu +10 on foot, Yumi/Han-kyu +10 mounted.
    Lance: +10 on foot, +5 mounted (no charge modeled yet; full DR 3k4 requires charge).
    Returns (flat_penalty, note). Penalty is negative (added to the attack roll)."""
    wp = get_weapon_profile(weapon_name)
    if wp.get("penalty_on_foot") and not is_mounted:
        pen = wp["penalty_on_foot"]
        return -pen, f"{weapon_name.replace('_', ' ').title()}: +{pen} TN (on foot, not mounted)"
    if wp.get("penalty_mounted") and is_mounted:
        pen = wp["penalty_mounted"]
        return -pen, f"{weapon_name.replace('_', ' ').title()}: +{pen} TN (mounted)"
    return 0, ""


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
    trait_override: int | None = None,
    trait_override_name: str = "",
    emphasis: bool = False,
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

    trait_name = weapon.get("trait", "agility")
    trait_value = getattr(attacker, trait_name, attacker.agility)
    if trait_override is not None:
        # An active kata replaces the normal Trait with a Ring (e.g. Iron Forest
        # Style: Air Ring instead of Agility for spear/polearm attack rolls, s30).
        trait_value = trait_override
        trait_name = trait_override_name or trait_name

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

    result = dice_engine.roll_check(max(1, rolled), max(1, kept), target_armor_tn, total_raises, flat_bonus, explodes, emphasis)
    return {
        "hit": result["success"],
        "emphasis": emphasis,
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
    extra_kept: int = 0,
    extra_flat: int = 0,
    explode_9: bool = False,
    force_explode: bool = False,
) -> dict:
    """Roll raw damage (before the target's armor reduction). `extra_rolled`/
    `extra_kept` are bonus damage dice from an active kata or School Technique
    (e.g. Waves upon the Breakers' +1k0, The Hand of Thunder's +0k1): added like
    Increased Damage but with no TN cost. `extra_flat` is a flat bonus added to
    the damage total (e.g. Matsu's Lion's Roar +Honor Rank). `explode_9` makes
    damage dice explode on 9+ (Kenjutsu R7, Heavy Weapons R7). `force_explode`
    overrides a weapon's default no-explode (Ninjutsu R5)."""
    weapon = get_weapon_profile(weapon_name)
    rolled = weapon.get("rolled", 2)
    kept = weapon.get("kept", 1)
    if weapon.get("strength_adds", True):
        rolled += attacker.strength
    rolled += increased_damage  # Increased Damage maneuver: +1k0 per raise
    rolled += extra_rolled       # bonus damage dice (no TN cost)
    kept += extra_kept
    can_explode = force_explode or not weapon.get("no_explode", False)
    res = dice_engine.roll_damage(max(1, rolled), max(1, kept), 0, 0, False, explode_9, can_explode)
    return {
        "rolled": rolled,
        "kept": kept,
        "raw_damage": res["raw"] + extra_flat,
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
MANEUVER_RAISES = {"feint": 2, "disarm": 3, "knockdown": 2, "knockdown_quad": 4, "extra_attack": 5}

CALLED_SHOT_PARTS = {
    1: "specific limb",
    2: "hand or foot",
    3: "head",
    4: "eye, ear, or finger",
}


def roll_initiative(character: Character, dice_engine: DiceEngine,
                    bonus_rolled: int = 0, bonus_kept: int = 0):
    """Initiative Roll & Keep: (Reflexes + Insight Rank) keep Reflexes
    plus optional bonus dice from school techniques."""
    ir = stats.insight_rank(character)
    rolled = character.reflexes + ir + bonus_rolled
    kept = character.reflexes + bonus_kept
    return dice_engine.roll_and_keep(max(1, rolled), max(1, kept))


def resolve_disarm(
    attacker: Character, defender: Character, dice_engine: DiceEngine,
    atk_rolled_mod: int = 0, atk_flat_mod: int = 0,
    def_rolled_mod: int = 0, def_flat_mod: int = 0,
) -> dict:
    """Disarm (s40): 2k1 damage regardless of weapon, plus a contested Strength
    roll (Strength k Strength, + wound penalties + conditions).
    Attacker wins ties-broken by >."""
    dmg = dice_engine.roll_damage(2, 1)
    a = dice_engine.roll_and_keep(max(attacker.strength + atk_rolled_mod, 1), max(attacker.strength, 1))
    d = dice_engine.roll_and_keep(max(defender.strength + def_rolled_mod, 1), max(defender.strength, 1))
    a_total = a.total + stats.wound_penalty(attacker) + atk_flat_mod
    d_total = d.total + stats.wound_penalty(defender) + def_flat_mod
    return {
        "damage": dmg["raw"],
        "damage_dice": dmg["dice"],
        "attacker_roll": a_total,
        "defender_roll": d_total,
        "disarmed": a_total > d_total,
    }


def resolve_knockdown(
    attacker: Character, defender: Character, dice_engine: DiceEngine,
    is_quadruped: bool = False,
    atk_rolled_mod: int = 0, atk_flat_mod: int = 0,
    def_rolled_mod: int = 0, def_flat_mod: int = 0,
) -> dict:
    """Knockdown (s40): contested Strength roll (+ wound penalties
    + conditions); a quadruped defender adds +4."""
    a = dice_engine.roll_and_keep(max(attacker.strength + atk_rolled_mod, 1), max(attacker.strength, 1))
    d = dice_engine.roll_and_keep(max(defender.strength + def_rolled_mod, 1), max(defender.strength, 1))
    a_total = a.total + stats.wound_penalty(attacker) + atk_flat_mod
    d_total = d.total + stats.wound_penalty(defender) + def_flat_mod + (4 if is_quadruped else 0)
    return {
        "attacker_roll": a_total,
        "defender_roll": d_total,
        "knocked_down": a_total > d_total,
    }


def compute_feint_bonus(attack_margin: int, attacker_insight_rank: int) -> int:
    """Feint (s40): half the attack margin, capped at 5 x Insight Rank, added to damage."""
    return min(attack_margin // 2, 5 * attacker_insight_rank)


# ---------------------------------------------------------------------------
# Iaijutsu dueling (s40)
# ---------------------------------------------------------------------------

ASSESSMENT_REVEALS = [
    "Void Ring",
    "Reflexes",
    "Iaijutsu Skill rank",
    "Iaijutsu Emphases",
    "Current Void Points",
    "Current Wound Level",
]


def iaijutsu_assessment_tn(opponent_insight_rank: int) -> int:
    return 10 + opponent_insight_rank * 5


def resolve_iaijutsu_assessment(
    awareness: int,
    iaijutsu_skill: int,
    opponent_insight_rank: int,
    dice_engine: DiceEngine,
    raises: int = 0,
    extra_flat: int = 0,
    bonus_rolled: int = 0,
    bonus_kept: int = 0,
    explode_9: bool = False,
) -> dict:
    """Iaijutsu (Assessment)/Awareness roll vs TN 10 + opponent IR×5."""
    rolled = awareness + iaijutsu_skill + bonus_rolled
    kept = awareness + bonus_kept
    explodes = iaijutsu_skill > 0
    result = dice_engine.roll_and_keep(
        max(1, rolled), max(1, kept), explodes, explode_9=explode_9,
    )
    total = result.total + extra_flat
    tn = iaijutsu_assessment_tn(opponent_insight_rank) + raises * 5
    success = total >= tn
    reveals = 0
    if success:
        reveals = 1 + raises
    return {
        "success": success,
        "total": total,
        "tn": tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
        "reveals": min(reveals, len(ASSESSMENT_REVEALS)),
    }


def resolve_iaijutsu_focus(
    void_a: int,
    iaijutsu_a: int,
    void_b: int,
    iaijutsu_b: int,
    dice_engine: DiceEngine,
    bonus_rolled_a: int = 0,
    bonus_kept_a: int = 0,
    bonus_rolled_b: int = 0,
    bonus_kept_b: int = 0,
    extra_flat_a: int = 0,
    extra_flat_b: int = 0,
    explode_9_a: bool = False,
    explode_9_b: bool = False,
    win_threshold_a: int = 5,
    win_threshold_b: int = 5,
    raise_divisor_a: int = 5,
    raise_divisor_b: int = 5,
) -> dict:
    """Contested Iaijutsu (Focus)/Void roll.

    Returns who strikes first and how many Free Raises.
    win_threshold controls the margin needed to strike first (default 5;
    Kakita R3 First and Last Strike uses 3). raise_divisor controls the
    Free-Raise-per-margin step (default 5; First and Last Strike uses 3).
    Thresholds are per-duelist - asymmetric when only one has the technique."""
    r_a = void_a + iaijutsu_a + bonus_rolled_a
    k_a = void_a + bonus_kept_a
    r_b = void_b + iaijutsu_b + bonus_rolled_b
    k_b = void_b + bonus_kept_b
    explodes_a = iaijutsu_a > 0
    explodes_b = iaijutsu_b > 0
    roll_a = dice_engine.roll_and_keep(
        max(1, r_a), max(1, k_a), explodes_a, explode_9=explode_9_a,
    )
    roll_b = dice_engine.roll_and_keep(
        max(1, r_b), max(1, k_b), explodes_b, explode_9=explode_9_b,
    )
    total_a = roll_a.total + extra_flat_a
    total_b = roll_b.total + extra_flat_b
    diff = total_a - total_b
    free_raises = 0
    if diff > 0 and diff >= win_threshold_a:
        first_striker = "a"
        free_raises = (diff - win_threshold_a) // raise_divisor_a
    elif diff < 0 and abs(diff) >= win_threshold_b:
        first_striker = "b"
        free_raises = (abs(diff) - win_threshold_b) // raise_divisor_b
    else:
        first_striker = "kharmic"
    return {
        "a_total": total_a,
        "b_total": total_b,
        "a_dice": roll_a,
        "b_dice": roll_b,
        "a_rolled": r_a,
        "a_kept": k_a,
        "b_rolled": r_b,
        "b_kept": k_b,
        "diff": diff,
        "first_striker": first_striker,
        "free_raises": free_raises,
    }


def resolve_iaijutsu_strike(
    reflexes: int,
    iaijutsu_skill: int,
    target_armor_tn: int,
    dice_engine: DiceEngine,
    free_raises: int = 0,
    extra_flat: int = 0,
    bonus_rolled: int = 0,
    bonus_kept: int = 0,
) -> dict:
    """Iaijutsu/Reflexes attack roll vs target's normal Armor TN."""
    rolled = reflexes + iaijutsu_skill + bonus_rolled
    kept = reflexes + bonus_kept
    explodes = iaijutsu_skill > 0
    result = dice_engine.roll_and_keep(max(1, rolled), max(1, kept), explodes)
    total = result.total + extra_flat
    return {
        "total": total,
        "tn": target_armor_tn,
        "hit": total >= target_armor_tn,
        "margin": total - target_armor_tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
        "free_raises": free_raises,
    }


# ---------------------------------------------------------------------------
# Contested skill checks (s40 general)
# ---------------------------------------------------------------------------

def resolve_contested_check(
    trait_a: int,
    skill_a: int,
    trait_b: int,
    skill_b: int,
    dice_engine: DiceEngine,
    bonus_a: int = 0,
    bonus_b: int = 0,
    extra_rolled_a: int = 0,
    extra_kept_a: int = 0,
    extra_rolled_b: int = 0,
    extra_kept_b: int = 0,
) -> dict:
    """Contested Skill/Trait roll. Each side rolls (trait + skill) keep trait;
    explodes only if skill > 0. bonus_a/bonus_b are flat modifiers (wound
    penalties, Void Point bonuses, situational). extra_rolled/extra_kept add
    dice from advantages without inflating both rolled and kept."""
    rolled_a = trait_a + skill_a + extra_rolled_a
    kept_a = trait_a + extra_kept_a
    rolled_b = trait_b + skill_b + extra_rolled_b
    kept_b = trait_b + extra_kept_b
    explodes_a = skill_a > 0
    explodes_b = skill_b > 0
    result_a = dice_engine.roll_and_keep(max(1, rolled_a), max(1, kept_a), explodes_a)
    result_b = dice_engine.roll_and_keep(max(1, rolled_b), max(1, kept_b), explodes_b)
    total_a = result_a.total + bonus_a
    total_b = result_b.total + bonus_b
    winner = "a"
    if total_b > total_a:
        winner = "b"
    elif total_a == total_b:
        winner = "tie"
    return {
        "winner": winner,
        "total_a": total_a,
        "total_b": total_b,
        "dice_a": result_a,
        "dice_b": result_b,
        "rolled_a": rolled_a,
        "kept_a": kept_a,
        "rolled_b": rolled_b,
        "kept_b": kept_b,
        "margin": abs(total_a - total_b),
    }


# ---------------------------------------------------------------------------
# Fear check (s40 / creature Fear ratings)
# ---------------------------------------------------------------------------

def resolve_fear_check(
    willpower: int,
    fear_rank: int,
    dice_engine: DiceEngine,
    bonus: int = 0,
    extra_rolled: int = 0,
    extra_kept: int = 0,
) -> dict:
    """Fear check: Willpower roll vs TN 5 + (Fear Rank × 5).
    Willpower is both rolled and kept. A Trait Roll explodes as normal
    (L5R 4e: only Unskilled Skill rolls forgo exploding dice)."""
    tn = 5 + fear_rank * 5
    rolled = max(1, willpower + extra_rolled)
    kept = max(1, willpower + extra_kept)
    result = dice_engine.roll_and_keep(rolled, kept)
    total = result.total + bonus
    return {
        "success": total >= tn,
        "total": total,
        "tn": tn,
        "margin": total - tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
    }


# ---------------------------------------------------------------------------
# Honor Roll (L5R 4e core p.214)
# ---------------------------------------------------------------------------

def resolve_honor_roll(
    honor_rank: int,
    tn: int,
    dice_engine: DiceEngine,
    bonus: int = 0,
) -> dict:
    """The Honor Roll (GDD s46, optional rule): re-roll a failed Skill, Trait,
    Ring or Spell Casting roll at the same TN using Honor Rank as both rolled
    and kept dice (Rank 6 rolls 6k6). Dice explode as on any Trait Roll."""
    rolled = max(1, honor_rank)
    result = dice_engine.roll_and_keep(rolled, rolled)
    total = result.total + bonus
    return {
        "success": total >= tn,
        "total": total,
        "tn": tn,
        "margin": total - tn,
        "dice": result,
        "rolled": rolled,
        "kept": rolled,
    }


# ---------------------------------------------------------------------------
# Poison resistance (L5R 4e core p.200)
# ---------------------------------------------------------------------------

def resolve_poison_resist(
    stamina: int,
    poison_strength: int,
    dice_engine: DiceEngine,
    bonus: int = 0,
    extra_rolled: int = 0,
    extra_kept: int = 0,
) -> dict:
    """Poison resistance: Stamina roll vs TN (Poison Strength × 5).
    Stamina is trait-only (rolled = kept = Stamina); a Trait Roll explodes
    as normal (L5R 4e: only Unskilled Skill rolls forgo exploding dice)."""
    tn = poison_strength * 5
    rolled = max(1, stamina + extra_rolled)
    kept = max(1, stamina + extra_kept)
    result = dice_engine.roll_and_keep(rolled, kept)
    total = result.total + bonus
    return {
        "success": total >= tn,
        "total": total,
        "tn": tn,
        "margin": total - tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
    }


# ---------------------------------------------------------------------------
# Generic skill check (Skill/Trait vs TN)
# ---------------------------------------------------------------------------

def resolve_skill_check(
    trait: int,
    skill: int,
    tn: int,
    dice_engine: DiceEngine,
    bonus: int = 0,
    extra_rolled: int = 0,
    extra_kept: int = 0,
    emphasis: bool = False,
) -> dict:
    """Generic Skill/Trait check vs a TN. Roll (trait + skill) keep trait.
    Explodes only if skilled (skill > 0). extra_rolled/extra_kept add dice
    from advantages without inflating both rolled and kept. `emphasis`
    rerolls 1s once (s04.5 / s24.0)."""
    rolled = max(1, trait + skill + extra_rolled)
    kept = max(1, trait + extra_kept)
    explodes = skill > 0
    result = dice_engine.roll_and_keep(rolled, kept, explodes, emphasis)
    total = result.total + bonus
    return {
        "success": total >= tn,
        "total": total,
        "tn": tn,
        "margin": total - tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
    }


# ---------------------------------------------------------------------------
# Medicine check (L5R 4e core p.154)
# ---------------------------------------------------------------------------

def resolve_medicine_check(
    intelligence: int,
    medicine_skill: int,
    tn: int,
    dice_engine: DiceEngine,
    bonus: int = 0,
    extra_rolled: int = 0,
    extra_kept: int = 0,
    emphasis: bool = False,
) -> dict:
    """Medicine/Intelligence check vs a TN. Used for treating poison, disease,
    wounds, etc. Explodes only if skilled."""
    rolled = max(1, intelligence + medicine_skill + extra_rolled)
    kept = max(1, intelligence + extra_kept)
    explodes = medicine_skill > 0
    result = dice_engine.roll_and_keep(rolled, kept, explodes, emphasis)
    total = result.total + bonus
    return {
        "success": total >= tn,
        "total": total,
        "tn": tn,
        "margin": total - tn,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
    }


STANCE_EFFECTS: dict[str, str] = {
    "attack": "",
    "full_attack": "+2k1 attack rolls, −10 own Armor TN. May only attack; no ranged attacks. Cannot use while mounted.",
    "defense": "+Air Ring + Defense skill to Armor TN. May not attack.",
    "full_defense": "Defense/Reflexes roll → half (rounded up) added to ATN. Complex Action; only Free Actions allowed.",
    "center": "Forfeit all Actions. Next Round: +1k1 + Void Ring on one roll, +10 Initiative.",
}


def stance_effects(stance: str) -> str:
    """Return the rules description for a combat stance."""
    return STANCE_EFFECTS.get(stance, "")
