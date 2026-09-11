"""Derived character values — pure functions over a Character.

Faithful port of the relevant parts of `simulation/character_stats.gd` and
`simulation/wound_system.gd`:

  - Ring = min of its two Traits (Void standalone)
  - Wound threshold per level = Earth ring x 2
  - 9 wound levels (Healthy .. Dead); level index = (wounds - 1) // threshold
  - Total capacity = threshold x 8 (Dead beyond Out)
  - Insight = (sum of the five Rings) x 10 + total skill ranks
  - Insight Rank ladder: R1@0, R2@150, then +25 per rank

Known simplifications vs the GDScript (documented, not silent):
  - PERMANENT_WOUND advantage floor (min NICKED) IS now applied in
    wound_level_index() — characters with the disadvantage are always at
    least at the Nicked wound level.
  - Insight omits the Skill Mastery / Courtier insight bonuses (no s24 mastery
    engine here). The core formula is exact.
  - Spirit-creature stat-block wound tracks are not modelled (PC formula only).
"""

from __future__ import annotations

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


def wound_threshold_per_level(c: Character) -> int:
    return earth_ring(c) * 2


def wound_level_index(c: Character) -> int:
    threshold = wound_threshold_per_level(c)
    if threshold <= 0:
        return 8  # Earth 0 -> Dead
    effective = c.wounds_taken
    if any(d.lower() == "permanent wound" for d in c.disadvantages):
        effective = max(effective, threshold + 1)
    if effective <= 0:
        return 0  # Healthy
    idx = (effective - 1) // threshold
    return min(idx, 8)


def wound_level_name(c: Character) -> str:
    return enums.WOUND_LEVELS[wound_level_index(c)]


def wound_penalty(c: Character) -> int:
    return enums.WOUND_PENALTIES[wound_level_index(c)]


def total_wound_capacity(c: Character) -> int:
    return wound_threshold_per_level(c) * 8


def is_dead(c: Character) -> bool:
    return wound_level_index(c) == 8


def insight(c: Character) -> int:
    rings_sum = sum(ring_value(c, r) for r in ("air", "earth", "fire", "water", "void"))
    total_skill_ranks = sum(c.skills.values())
    return rings_sum * 10 + total_skill_ranks


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
