"""Creatures / monsters — fixed stat blocks transcribed VERBATIM from the
Rokugan bestiaries (natural_creature_bestiary.gd, shadowlands_beast_bestiary.gd,
undead_bestiary.gd, oni_bestiary.gd), using the SpiritCreatureData model.

Unlike samurai (who roll trait+skill), a creature attacks and damages with a
FIXED Roll & Keep from its stat block, has an explicit Armor TN and Reduction,
and dies at its `wounds_dead` total with wound levels read off `wound_thresholds`
(the spirit-creature wound track from character_stats.gd `_spirit_wound_level`).

Every number here is copied from the bestiary — nothing is invented. This is a
starter roster (a few natural animals, low Shadowlands threats, a zombie, and
two lesser oni); more can be transcribed the same way.
"""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field, asdict, fields

from .dice import DiceEngine

# Living wound levels (index 0-7); DEAD is separate (character_stats.gd).
_WOUND_LEVELS = ["Healthy", "Nicked", "Grazed", "Hurt", "Injured", "Crippled", "Down", "Out"]


@dataclass
class Creature:
    template_id: str
    name: str
    air: int
    earth: int
    fire: int
    water: int
    initiative_rolled: int
    initiative_kept: int
    attack_name: str
    attack_rolled: int
    attack_kept: int
    damage_rolled: int
    damage_kept: int
    armor_tn: int
    reduction: int
    wounds_dead: int
    fear: int
    wound_thresholds: list[int] = field(default_factory=list)
    traits: dict[str, int] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)
    wounds_taken: int = 0  # mutable, per spawned instance

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Creature":
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in data.items() if k in known})


def _c(
    template_id, name, air, earth, fire, water, init_r, init_k,
    atk_name, atk_r, atk_k, dmg_r, dmg_k, atn, reduction, thresholds, dead, fear,
    traits=None, tags=None,
) -> Creature:
    return Creature(
        template_id=template_id, name=name, air=air, earth=earth, fire=fire, water=water,
        initiative_rolled=init_r, initiative_kept=init_k,
        attack_name=atk_name, attack_rolled=atk_r, attack_kept=atk_k,
        damage_rolled=dmg_r, damage_kept=dmg_k, armor_tn=atn, reduction=reduction,
        wound_thresholds=list(thresholds), wounds_dead=dead, fear=fear,
        traits=traits or {}, tags=tags or [],
    )


# --- Starter roster (verbatim from the bestiaries) -------------------------
# _c(id, name, air, earth, fire, water, init_r, init_k, atk_name, atk_r, atk_k,
#    dmg_r, dmg_k, armor_tn, reduction, thresholds, wounds_dead, fear, traits, tags)
CREATURE_CATALOG: dict[str, Creature] = {c.template_id: c for c in [
    # Natural animals (natural_creature_bestiary.gd)
    _c("dog", "Dog (Inu)", 1, 2, 1, 1, 4, 3, "Bite", 3, 3, 2, 1, 20, 0, [12], 24, 0,
       {"reflexes": 3, "agility": 3, "perception": 3}, ["animal", "natural"]),
    _c("wolf", "Wolf (Ookami)", 1, 3, 2, 3, 4, 3, "Bite", 4, 3, 5, 2, 20, 3, [18], 36, 0,
       {"reflexes": 3, "agility": 3, "perception": 4}, ["animal", "natural"]),
    _c("boar", "Boar (Inoshishi)", 1, 5, 1, 2, 4, 3, "Tusks", 5, 3, 5, 2, 20, 12, [30], 75, 0,
       {"reflexes": 3, "agility": 3, "strength": 4}, ["animal", "natural", "huge"]),
    _c("crocodile", "Crocodile (Wani)", 1, 3, 2, 2, 4, 3, "Bite", 5, 4, 4, 4, 20, 5, [24, 36], 64, 2,
       {"reflexes": 3, "stamina": 4, "agility": 4, "strength": 4}, ["animal", "natural", "aquatic"]),
    _c("eagle", "Eagle (Washi)", 1, 1, 1, 2, 5, 5, "Beak/Talons", 5, 4, 2, 2, 30, 0, [7], 15, 0,
       {"reflexes": 5, "agility": 4, "perception": 4}, ["animal", "natural", "flying"]),
    # Shadowlands (shadowlands_beast_bestiary.gd)
    _c("goblin_warmonger", "Goblin Warmonger", 2, 3, 2, 2, 6, 3, "Katana", 6, 3, 6, 2, 25, 7, [15, 30], 45, 0,
       {"reflexes": 3, "agility": 3, "strength": 3}, ["shadowlands", "goblin"]),
    _c("ogre_free", "Free Ogre", 2, 3, 3, 2, 4, 3, "Tetsubo", 8, 4, 9, 3, 30, 15, [20, 40, 60], 80, 2,
       {"reflexes": 3, "stamina": 6, "strength": 6}, ["shadowlands", "ogre", "huge"]),
    _c("troll_common", "Troll, Common", 1, 3, 3, 3, 5, 3, "Claws", 6, 3, 6, 3, 20, 5, [20, 40, 65], 90, 0,
       {"reflexes": 3, "stamina": 5, "strength": 5}, ["shadowlands", "troll"]),
    # Undead (undead_bestiary.gd)
    _c("plague_zombie", "Plague Zombie", 0, 3, 0, 1, 1, 1, "Fist", 4, 2, 3, 1, 10, 5, [], 72, 3,
       {"reflexes": 1, "stamina": 4, "agility": 2, "strength": 3}, ["undead"]),
    # Oni (oni_bestiary.gd) — lesser (MID tier)
    _c("morei_no_oni", "Morei no Oni, the Grain Demon", 2, 2, 1, 1, 3, 2, "Claws", 3, 2, 3, 1, 15, 10, [12, 24], 36, 0,
       {"strength": 2}, ["oni", "immobile"]),
    _c("quiet_death", "Quiet Death", 1, 2, 1, 4, 3, 3, "Touch", 4, 4, 4, 1, 20, 10, [30, 60], 120, 0,
       {"reflexes": 3, "stamina": 5, "agility": 4}, ["oni", "amorphous"]),
]}


def spawn(template_id: str, instance_name: str) -> Creature | None:
    template = CREATURE_CATALOG.get(template_id)
    if template is None:
        return None
    cr = deepcopy(template)
    cr.name = instance_name
    cr.wounds_taken = 0
    return cr


# --- Combat math (fixed stat block) ----------------------------------------
def creature_wound_level(cr: Creature) -> str:
    w = cr.wounds_taken
    if w >= cr.wounds_dead:
        return "Dead"
    if w <= 0:
        return "Healthy"
    if not cr.wound_thresholds:
        idx = int(w / cr.wounds_dead * len(_WOUND_LEVELS))
    else:
        idx = sum(1 for t in cr.wound_thresholds if w > t)
    idx = max(0, min(idx, len(_WOUND_LEVELS) - 1))
    return _WOUND_LEVELS[idx]


def creature_is_dead(cr: Creature) -> bool:
    return cr.wounds_taken >= cr.wounds_dead


def roll_creature_initiative(cr: Creature, dice: DiceEngine):
    return dice.roll_and_keep(cr.initiative_rolled, cr.initiative_kept)


def creature_attack(cr: Creature, target_armor_tn: int, dice: DiceEngine, raises: int = 0, bonus: int = 0) -> dict:
    """The creature's fixed attack vs a target's Armor TN."""
    return dice.roll_check(cr.attack_rolled, cr.attack_kept, target_armor_tn, raises, bonus, True)


def creature_damage(cr: Creature, dice: DiceEngine) -> dict:
    """The creature's fixed damage (exploding)."""
    return dice.roll_damage(cr.damage_rolled, cr.damage_kept, 0, 0, False, False, True)


def apply_damage_to_creature(cr: Creature, raw_damage: int, reduction: int | None = None) -> dict:
    if reduction is None:
        reduction = cr.reduction
    final = max(0, raw_damage - reduction)
    old = creature_wound_level(cr)
    cr.wounds_taken += final
    new = creature_wound_level(cr)
    return {
        "raw_damage": raw_damage, "reduction": reduction, "final_damage": final,
        "old_wound_level": old, "new_wound_level": new,
        "is_dead": creature_is_dead(cr), "level_changed": old != new,
    }
