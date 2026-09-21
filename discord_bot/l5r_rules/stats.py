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
