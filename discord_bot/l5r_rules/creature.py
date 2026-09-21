"""Creatures / monsters: fixed stat blocks transcribed VERBATIM from the
Rokugan bestiaries (natural_creature_bestiary.gd, shadowlands_beast_bestiary.gd,
undead_bestiary.gd, oni_bestiary.gd), using the SpiritCreatureData model.

Unlike samurai (who roll trait+skill), a creature attacks and damages with a
FIXED Roll & Keep from its stat block, has an explicit Armor TN and Reduction,
and dies at its `wounds_dead` total with wound levels read off `wound_thresholds`
(the spirit-creature wound track from character_stats.gd `_spirit_wound_level`).

Every number here is copied from the bestiary: nothing is invented. This is a
starter roster (a few natural animals, low Shadowlands threats, a zombie, and
two lesser oni); more can be transcribed the same way.
"""

from __future__ import annotations

import random
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
        # ("human_wounds" tag), derived like a PC (stats.py, RAW): Healthy
        # holds Earth x 5, each later level Earth x 2. Thresholds are the
        # inclusive upper bound of Healthy..Down; Out ends at Earth x 19 and
        # one more wound is Dead.
        if int(d.get("wounds_dead", 0)) <= 0:
            earth = max(1, int(d.get("earth", 2)))
            healthy, step = earth * 5, earth * 2
            d["wound_thresholds"] = [healthy + step * i for i in range(7)]
            d["wounds_dead"] = healthy + step * 7 + 1
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


def randomize_stats(cr: Creature) -> list[str]:
    """Apply slight random variation to a spawned creature's stats.

    Rings/traits +/-1, dice pools +/-1 per component, Armor TN +/-5,
    Reduction +/-1, wound thresholds scaled 0.85-1.15. Fear, tags, and
    flat bonuses are unchanged. Returns human-readable change lines.
    """
    changes: list[str] = []

    for ring in ("air", "earth", "fire", "water"):
        base = getattr(cr, ring)
        if base <= 0:
            continue
        delta = random.choice([-1, 0, 1])
        if delta == 0:
            continue
        new_val = max(1, base + delta)
        if new_val != base:
            setattr(cr, ring, new_val)
            changes.append(f"{ring.capitalize()}: {base} → {new_val}")

    for tname, tval in list(cr.traits.items()):
        if tval <= 0:
            continue
        delta = random.choice([-1, 0, 1])
        if delta == 0:
            continue
        new_val = max(1, tval + delta)
        if new_val != tval:
            cr.traits[tname] = new_val
            changes.append(f"{tname}: {tval} → {new_val}")

    for label, r_attr, k_attr in [
        ("Initiative", "initiative_rolled", "initiative_kept"),
        ("Attack", "attack_rolled", "attack_kept"),
        ("Damage", "damage_rolled", "damage_kept"),
    ]:
        rolled = getattr(cr, r_attr)
        kept = getattr(cr, k_attr)
        dr = random.choice([-1, 0, 1])
        dk = random.choice([-1, 0, 1])
        new_r = max(1, rolled + dr)
        new_k = max(1, kept + dk)
        if new_k > new_r:
            new_k = new_r
        if new_r != rolled or new_k != kept:
            setattr(cr, r_attr, new_r)
            setattr(cr, k_attr, new_k)
            changes.append(f"{label}: {rolled}k{kept} → {new_r}k{new_k}")

    base_atn = cr.armor_tn
    atn_delta = random.choice([-5, 0, 5])
    if atn_delta != 0:
        cr.armor_tn = max(5, base_atn + atn_delta)
        if cr.armor_tn != base_atn:
            changes.append(f"Armor TN: {base_atn} → {cr.armor_tn}")

    base_red = cr.reduction
    red_delta = random.choice([-1, 0, 1])
    if red_delta != 0:
        new_red = max(0, base_red + red_delta)
        if new_red != base_red:
            cr.reduction = new_red
            changes.append(f"Reduction: {base_red} → {cr.reduction}")

    if cr.wound_thresholds:
        factor = random.uniform(0.85, 1.15)
        if abs(factor - 1.0) > 0.01:
            old_dead = cr.wounds_dead
            cr.wound_thresholds = [max(1, round(t * factor)) for t in cr.wound_thresholds]
            cr.wounds_dead = max(cr.wound_thresholds[-1] + 1, round(old_dead * factor))
            changes.append(f"Wounds Dead: {old_dead} → {cr.wounds_dead}")

    return changes


def make_custom(
    name: str,
    earth: int,
    attack_rolled: int,
    attack_kept: int,
    damage_rolled: int,
    damage_kept: int,
    armor_tn: int,
    air: int | None = None,
    fire: int | None = None,
    water: int | None = None,
    attack_name: str = "Attack",
    reduction: int = 0,
    wounds_dead: int = 0,
    fear: int = 0,
    tags_str: str = "",
    initiative_rolled: int | None = None,
    initiative_kept: int | None = None,
) -> Creature:
    """Build a custom creature from explicit parameters."""
    _air = air if air is not None else earth
    _fire = fire if fire is not None else earth
    _water = water if water is not None else earth

    if initiative_rolled is None:
        initiative_rolled = _water + 1
    if initiative_kept is None:
        initiative_kept = _water

    tags = [t.strip() for t in tags_str.split(",") if t.strip()] if tags_str else []

    if wounds_dead <= 0:
        healthy, step = earth * 5, earth * 2
        wound_thresholds = [healthy + step * i for i in range(7)]
        wounds_dead = healthy + step * 7 + 1
    else:
        step = max(1, wounds_dead // 8)
        wound_thresholds = [step * (i + 1) for i in range(7)]

    slug = name.lower().replace(" ", "_").replace("'", "")
    template_id = f"custom_{slug}"

    return Creature(
        template_id=template_id,
        name=name,
        air=_air,
        earth=earth,
        fire=_fire,
        water=_water,
        initiative_rolled=initiative_rolled,
        initiative_kept=initiative_kept,
        attack_name=attack_name,
        attack_rolled=attack_rolled,
        attack_kept=attack_kept,
        damage_rolled=damage_rolled,
        damage_kept=damage_kept,
        armor_tn=armor_tn,
        reduction=reduction,
        wounds_dead=wounds_dead,
        fear=fear,
        wound_thresholds=wound_thresholds,
        tags=tags,
        wounds_taken=0,
    )


# --- Creature special abilities (GDD s54.0) --------------------------------

def creature_special_notes(cr: Creature) -> list[str]:
    """DM reminder lines for creature special abilities relevant to combat."""
    notes: list[str] = []
    tags = set(cr.tags)
    if "undead" in tags:
        notes.append("**Undead:** no Wound penalties; immune to Fear; functional until Dead")
    if "superior_invuln" in tags:
        notes.append("**Superior Invulnerability:** 1 Wound from all attacks (immune to spells, jade, crystal, obsidian)")
    elif "partial_invuln" in tags:
        notes.append("**Invulnerability:** 1 Wound from normal attacks; full damage from jade/crystal/obsidian/spells/nemuranai")
    elif "partial_invuln_half_damage" in tags:
        notes.append("**Partial Invulnerability:** half damage from normal attacks; full from jade/crystal/obsidian/spells")
    if "spirit" in tags:
        notes.append("**Spirit:** half damage from non-jade/crystal/obsidian weapons and non-Jade/Crystal spells")
    if cr.fear > 0:
        notes.append(f"**Fear {cr.fear}:** opponents must resist or suffer −{cr.fear}k0 to all rolls")
    return notes


def is_undead(cr: Creature) -> bool:
    return "undead" in cr.tags


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


def apply_damage_to_creature(
    cr: Creature,
    raw_damage: int,
    reduction: int | None = None,
    bypasses_invuln: bool = False,
    is_spell: bool = False,
    is_jade_spell: bool = False,
) -> dict:
    """Apply damage with creature special abilities (GDD s54.0).

    bypasses_invuln: weapon is jade, crystal, obsidian, or nemuranai.
    is_spell: damage is from a spell (bypasses standard Invulnerability).
    is_jade_spell: spell has the Jade or Crystal quality (bypasses Spirit half-damage).
    """
    if reduction is None:
        reduction = cr.reduction
    final = max(0, raw_damage - reduction)
    notes: list[str] = []
    tags = set(cr.tags)
    can_bypass = bypasses_invuln or is_spell
    if "superior_invuln" in tags and not bypasses_invuln:
        final = min(final, 1)
        notes.append("Superior Invulnerability: 1 Wound max (immune to spells too)")
    elif "partial_invuln" in tags and not can_bypass:
        final = min(final, 1)
        notes.append("Invulnerability: 1 Wound (need jade/crystal/obsidian/spell)")
    elif "partial_invuln_half_damage" in tags and not can_bypass:
        final = final // 2
        notes.append("Partial Invulnerability: half damage (need jade/crystal/obsidian/spell)")
    if "spirit" in tags and not bypasses_invuln:
        if is_spell and not is_jade_spell:
            final = final // 2
            notes.append("Spirit: half damage from non-Jade/Crystal spell")
        elif not is_spell:
            final = final // 2
            notes.append("Spirit: half damage (need jade/crystal/obsidian weapon)")
    old = creature_wound_level(cr)
    cr.wounds_taken += final
    new = creature_wound_level(cr)
    return {
        "raw_damage": raw_damage, "reduction": reduction, "final_damage": final,
        "old_wound_level": old, "new_wound_level": new,
        "is_dead": creature_is_dead(cr), "level_changed": old != new,
        "special_notes": notes,
    }
