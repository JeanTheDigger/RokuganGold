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
    attack_flat: int = 0   # flat +N to the attack-roll total (SpiritCreatureData.attack_flat_bonus)
    damage_flat: int = 0   # flat +N to the damage-roll total (SpiritCreatureData.damage_flat_bonus)
    wounds_taken: int = 0  # mutable, per spawned instance

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Creature":
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in data.items() if k in known})


from .creature_catalog import CATALOG_DATA

# Tags that mark an entry as not a spawnable combatant (environmental hazards).
_EXCLUDE_TAGS = {"not_creature", "cannot_be_fought"}


def _build_catalog() -> dict[str, Creature]:
    out: dict[str, Creature] = {}
    for raw in CATALOG_DATA:
        if _EXCLUDE_TAGS & set(raw.get("tags", [])):
            continue
        d = dict(raw)
        # A creature stored with wounds_dead == 0 uses the human wound track
        # ("human_wounds" tag): Earth ring x 2 per level, 8 levels to death —
        # the same LOCKED formula as PCs (character_stats.gd). Derive it here.
        if int(d.get("wounds_dead", 0)) <= 0:
            per = max(1, int(d.get("earth", 2))) * 2
            d["wound_thresholds"] = [per * i for i in range(1, 8)]
            d["wounds_dead"] = per * 8
        out[d["template_id"]] = Creature(**d)
    return out


# The full bestiary, transcribed verbatim by tools/extract_bestiary.py.
CREATURE_CATALOG: dict[str, Creature] = _build_catalog()


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
    """The creature's fixed attack vs a target's Armor TN (plus any attack_flat)."""
    return dice.roll_check(cr.attack_rolled, cr.attack_kept, target_armor_tn, raises, bonus + cr.attack_flat, True)


def creature_damage(cr: Creature, dice: DiceEngine) -> dict:
    """The creature's fixed damage (exploding, plus any damage_flat)."""
    res = dice.roll_damage(cr.damage_rolled, cr.damage_kept, 0, 0, False, False, True)
    res["raw"] += cr.damage_flat
    res["final"] = max(0, res["raw"] - res["reduction"])
    return res


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
