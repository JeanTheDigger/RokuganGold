"""Derived character values: pure functions over a Character.

Faithful port of the relevant parts of `simulation/character_stats.gd` and
`simulation/wound_system.gd`:

  - Ring = min of its two Traits (Void standalone)
  - Wound track (L5R 4e RAW, owner decision 2026-09-15): Healthy holds
    Earth x 5 wounds; each of the seven following levels (Nicked .. Out)
    holds Earth x 2. Dead is anything beyond Out.
    (The Godot simulation and GDD s22.3 use Earth x 2 for every level; the
    bot deliberately follows the tabletop rule instead.)
  - 9 wound levels (Healthy .. Dead)
  - Total capacity = Earth x 5 + Earth x 2 x 7 (Dead beyond Out)
  - Insight = (sum of the five Rings) x 10 + total skill ranks
  - Insight Rank ladder: R1@0, R2@150, then +25 per rank

Known simplifications vs the GDScript (documented, not silent):
  - PERMANENT_WOUND advantage floor (min NICKED) IS now applied in
    wound_level_index(): characters with the disadvantage are always at
    least at the Nicked wound level.
  - Insight includes Courtier/Etiquette R3 (+3) and R7 (+10) mastery Insight
    bonuses. The core formula is exact.
  - Spirit-creature stat-block wound tracks are not modelled (PC formula only).
"""

from __future__ import annotations

import re

from . import enums
from .character import Character


def ring_value(c: Character, ring: str) -> int:
    ring = ring.lower()
    if ring == "void":
        return c.void_ring
    a, b = enums.RING_TRAITS[ring]
    return min(getattr(c, a), getattr(c, b))


def earth_ring(c: Character) -> int:
    return ring_value(c, "earth")


def healthy_wound_threshold(c: Character) -> int:
    """Wounds the Healthy level holds (RAW: Earth x 5)."""
    return earth_ring(c) * 5


def wound_threshold_per_level(c: Character) -> int:
    """Wounds each level after Healthy holds (RAW: Earth x 2)."""
    return earth_ring(c) * 2


def wound_level_index(c: Character) -> int:
    healthy = healthy_wound_threshold(c)
    step = wound_threshold_per_level(c)
    if step <= 0:
        return 8  # Earth 0 -> Dead
    effective = c.wounds_taken
    if any(d.lower() == "permanent wound" for d in c.disadvantages):
        effective = max(effective, healthy + 1)
    if effective <= healthy:
        return 0  # Healthy (a full level is still that level)
    idx = 1 + (effective - healthy - 1) // step
    return min(idx, 8)


def wound_level_name(c: Character) -> str:
    return enums.WOUND_LEVELS[wound_level_index(c)]


def wound_penalty(c: Character) -> int:
    return enums.WOUND_PENALTIES[wound_level_index(c)]


def total_wound_capacity(c: Character) -> int:
    """Wounds at which Out is full; one more is Dead."""
    return healthy_wound_threshold(c) + wound_threshold_per_level(c) * 7


def is_dead(c: Character) -> bool:
    return wound_level_index(c) == 8


def _skill_rank(c: Character, name: str) -> int:
    lower = name.lower()
    for k, v in c.skills.items():
        if k.lower() == lower:
            return v
    return 0


def insight(c: Character) -> int:
    rings_sum = sum(ring_value(c, r) for r in ("air", "earth", "fire", "water", "void"))
    total_skill_ranks = sum(c.skills.values())
    base = rings_sum * 10 + total_skill_ranks
    # Courtier/Etiquette mastery: +3 Insight at R3, +10 more at R7 (cumulative)
    for sk in ("Courtier", "Etiquette"):
        rank = _skill_rank(c, sk)
        if rank >= 3:
            base += 3
        if rank >= 7:
            base += 10
    return base


def insight_rank(c: Character) -> int:
    v = insight(c)
    # L5R4e Core: Rank 1 at 0, Rank 2 at 150, then +25 per rank.
    for threshold, rank in (
        (350, 10), (325, 9), (300, 8), (275, 7), (250, 6),
        (225, 5), (200, 4), (175, 3), (150, 2),
    ):
        if v >= threshold:
            return rank
    return 1


def all_rings(c: Character) -> dict[str, int]:
    return {r: ring_value(c, r) for r in ("air", "earth", "fire", "water", "void")}


def honor_rank(c: Character) -> int:
    """Honor Rank = the integer part of the Honor score (L5R convention:
    Honor is a 0.0-10.0 value whose whole number is the Rank; e.g. 3.5 = Rank 3)."""
    return int(c.honor)


def taint_rank(c: Character) -> int:
    """Taint Rank = whole-number part of the Taint score (GDD s22.3 / s42:
    10 Points = 1 Rank, so 2.3 = Rank 2 with 3 Points). Ranks run 0-10."""
    if c.taint <= 0:
        return 0
    return min(int(c.taint), 10)


def water_ring(c: Character) -> int:
    return ring_value(c, "water")


def natural_healing_rate(c: Character) -> int:
    """L5R 4e: a character heals Stamina x 2 wounds per day of rest."""
    return c.stamina * 2


def spell_slot_max(c: Character, element: str) -> int:
    """L5R 4e: per-element daily spell slots = Ring value."""
    return ring_value(c, element)


def void_bonus_max(c: Character) -> int:
    """L5R 4e: bonus spell slots = Void Ring, usable for any element."""
    return c.void_ring


SPELL_CAST_ELEMENTS = ("air", "earth", "fire", "water")


def deficiency_elements(c: Character) -> set[str]:
    """Every element the character is Deficient in. The sheet field holds one name, or several
    separated by "/" or "," (Self-Taught Shugenja has two)."""
    return {e.strip().lower() for e in re.split(r"[/,]", c.deficiency_element or "") if e.strip()}


def is_deficient(c: Character, element: str) -> bool:
    return element.lower() in deficiency_elements(c)


# Schools whose Affinity and Deficiency follow a spell's keyword, not its element (GDD s29.6, Yogo
# Wardmaster). `named` are spells the school's Technique text also treats as Wards.
KEYWORD_SCHOOLS: dict[str, dict] = {
    "yogo wardmaster": {
        "affinity": {"ward", "wards"},
        "deficiency": {"travel", "craft"},
        "named": {
            "to seek the truth", "by the light of the moon", "benten's touch", "summon fog",
            "armor of earth", "courage of the seven thunders", "force of will", "wholeness of the world",
            "extinguish", "fires of purity", "disrupt the aura", "haze of battle",
            "globe of the everlasting sun", "reversal of fortunes", "rejuvenating vapors",
            "wisdom & clarity", "near to ice",
        },
    },
}


def keyword_rule(c: Character) -> dict | None:
    return KEYWORD_SCHOOLS.get((c.school or "").strip().lower())


def spell_keywords(spell: dict) -> set[str]:
    return {k.strip().lower() for k in (spell.get("keyword") or "").split(",") if k.strip()}


def spell_affinity_state(c: Character, spell: dict, element: str | None = None) -> tuple[bool, bool]:
    """(Affinity applies, Deficiency applies) for casting this spell (s31). A keyword school judges
    the spell by its keywords; everyone else by the element it is cast with."""
    rule = keyword_rule(c)
    if rule is not None:
        kws = spell_keywords(spell)
        is_ward = bool(kws & rule["affinity"]) or spell["name"].lower().replace("\u2019", "'") in rule["named"]
        return (is_ward and spell["element"].lower() != "void"), bool(kws & rule["deficiency"])
    el = (element or spell["element"]).lower()
    return bool(c.affinity_element and c.affinity_element.lower() == el), is_deficient(c, el)


def effective_school_rank(c: Character, element: str, school_rank: int | None = None) -> int:
    """School Rank as it applies to spells of one element (s31): +1 in the Affinity
    element, -1 in the Deficiency element (0 = cannot cast that element)."""
    rank = c.school_rank if school_rank is None else school_rank
    el = element.lower()
    if c.affinity_element and c.affinity_element.lower() == el:
        rank += 1
    if is_deficient(c, el):
        rank -= 1
    return rank


def spell_mastery_ceiling(c: Character, spell_element: str, school_rank: int | None = None,
                          spell: dict | None = None) -> int:
    """Highest Mastery Level the character may learn or cast in a spell's element
    (s48: the Rank sets the ceiling; s31: Affinity/Deficiency shift it by one).
    Universal spells use the best of the four castable elements. Pass `spell` for a
    keyword school (Yogo Wardmaster), whose shift depends on the spell, not its element."""
    if spell is not None and keyword_rule(c) is not None:
        rank = c.school_rank if school_rank is None else school_rank
        aff, deff = spell_affinity_state(c, spell)
        return rank + (1 if aff else 0) - (1 if deff else 0)
    el = spell_element.lower()
    if el in SPELL_CAST_ELEMENTS or el == "void":
        return effective_school_rank(c, el, school_rank)
    return max(effective_school_rank(c, e, school_rank) for e in SPELL_CAST_ELEMENTS)


def knows_spell(c: Character, name: str) -> bool:
    key = name.strip().lower()
    return any(s.lower() == key for s in c.spells_known)


def is_memorised(c: Character, name: str) -> bool:
    key = name.strip().lower()
    return any(s.lower() == key for s in c.spells_memorised)


def spell_source_note(c: Character, name: str) -> str:
    """How the caster reads the prayer (s31): from memory or from the scroll."""
    return "Memorised" if is_memorised(c, name) else "Read from scroll"


def is_void_mystic(c: Character) -> bool:
    return (c.school or "").strip().lower() == "void mystic"


_VOID_MYSTIC_BASE = {"sense", "commune", "summon"}
_VOID_MYSTIC_MAX_MASTERY = 5   # "Cannot cast Void spells above Rank 5" (GDD s29.12)


def void_mystic_can_cast(c: Character, spell: dict) -> bool:
    """The Void's Caress: a Void Mystic may cast any Void spell up to their Mastery, learned or not."""
    return (is_void_mystic(c) and spell["element"].lower() == "void"
            and spell["mastery"] <= min(c.school_rank, _VOID_MYSTIC_MAX_MASTERY))


def void_mystic_cast_problem(c: Character, spell: dict) -> str | None:
    """Why a Void Mystic may not cast this spell, or None. They cast only Void spells (and Sense,
    Commune, Summon), each once per day."""
    if not is_void_mystic(c):
        return None
    if spell["element"].lower() != "void":
        if spell["name"].lower() not in _VOID_MYSTIC_BASE:
            return "A Void Mystic cannot cast non-Void elemental spells except Sense, Commune, and Summon."
        return None
    if spell["name"] in c.spells_cast_today:
        return f"A Void Mystic casts each spell once per day, and **{spell['name']}** is spent until the next new day."
    return None


def void_mystic_spells(c: Character) -> list[dict]:
    """Void spells a Void Mystic can still cast today."""
    from . import spells as _spells
    if not is_void_mystic(c):
        return []
    return [s for s in _spells.by_element("void")
            if void_mystic_can_cast(c, s) and s["name"] not in c.spells_cast_today]


# Schools that do not hand out three spells per School Rank: Self-Taught must seek spells out
# (GDD s29.12); a Void Mystic casts Void spells without learning them.
_NO_RANK_SPELLS = {"self-taught shugenja", "void mystic"}


def pending_rank_spells(c: Character) -> tuple[int, int]:
    """(rank being learned, picks still owed) for a shugenja whose School Rank is
    above the last rank whose three spells were taken (s48); (0, 0) if none."""
    if (c.school or "").strip().lower() in _NO_RANK_SPELLS:
        return 0, 0
    if c.school_rank <= c.spell_ranks_learned:
        return 0, 0
    return c.spell_ranks_learned + 1, max(0, 3 - c.rank_spell_picks)


def trait_value(c: Character, name: str) -> int:
    """Return a trait value by name, including Void."""
    if name.lower() == "void":
        return c.void_ring
    return c.get_trait(name)


def wound_track(c: Character) -> str:
    """Visual wound track: shows each level with the current position marked."""
    short = ["H", "Ni", "Gr", "Hu", "In", "Cr", "Dn", "Ou", "De"]
    idx = wound_level_index(c)
    parts = []
    for i, s in enumerate(short):
        if i == idx:
            parts.append(f"[**{s}**]")
        else:
            parts.append(s)
    return " → ".join(parts)


def check_insight_rank_advance(c: Character) -> tuple[int, int] | None:
    """If insight qualifies for a higher school rank, update it and return
    (old_rank, new_rank). Otherwise return None."""
    new_rank = insight_rank(c)
    if new_rank <= c.school_rank:
        return None
    old = c.school_rank
    c.school_rank = new_rank
    return old, new_rank


def encumbrance_capacity(c: Character) -> int:
    """L5R 4e: a character can carry Strength x 5 items without penalty.
    Beyond that, TN penalties apply. This returns the threshold."""
    return c.strength * 5
