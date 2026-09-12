"""Procedural NPC samurai generation: a faithful, GENERIC port of GDD s22.4
(Generation Templates: LOCKED).

s22.4 builds a character from Clan + Family + School + Insight Rank. The
school-specific pieces (which skills, which Trait bonuses, the outfit) live in
Sections 27/29, which are NOT ported here. What IS ported is everything s22.4
specifies independently of a particular school:

  - Ring value ranges and Ring-sum band per Insight Rank (Ranks 1-5)
  - Trait baseline 2 with upward variance (Rings kept within the LOCKED sum band)
  - Starting Glory  = 1.0 + 0.5 x (Rank - 1)
  - Starting Honor  = school value (defaulted; caller may override) ± 0.5 variance
  - Age             = the Rank's range (Rank 1-5)
  - Koku            = 1d10 x Rank  (the "additional savings" term; the role
                      stipend term needs role data and is left to the DM)
  - Skills          = caller-supplied school-skill names distributed per Rank
                      (s22.4 skill distribution); no skill NAMES are invented

Ranks 6+ have no ring/age ranges in s22.4, so generation is capped at Rank 5
(no extrapolation). Nothing here invents a value: every number traces to s22.4,
and the specific skill/clan/family/school text is supplied by the DM.
"""

from __future__ import annotations

from .character import Character
from .dice import DiceEngine
from .enums import RING_TRAITS

# (ring_min, ring_max, sum_min, sum_max) per Insight Rank: s22.4 "Ring value ranges".
RANK_RINGS = {
    1: (2, 3, 11, 13),
    2: (2, 3, 13, 15),
    3: (2, 4, 15, 17),
    4: (3, 4, 17, 19),
    5: (3, 5, 19, 22),
}

# s22.4 "Age Calculation" ranges (Rank 1-5).
RANK_AGE = {
    1: (15, 20),
    2: (18, 28),
    3: (23, 35),
    4: (30, 45),
    5: (38, 55),
}

# s22.4 "Skill Distribution": the average school-skill rank, and the one
# specialty skill's rank, per Insight Rank.
SKILL_BASE = {1: 1, 2: 2, 3: 3, 4: 3, 5: 4}
SKILL_SPECIALTY = {1: 2, 2: 3, 3: 4, 4: 5, 5: 5}

MIN_RANK = 1
MAX_RANK = 5


def _adjust_sum(rings: dict, sum_min: int, sum_max: int, ring_min: int, ring_max: int, dice: DiceEngine) -> None:
    """Nudge ring values (within per-ring bounds) until their sum lands in the band."""
    keys = list(rings.keys())
    guard = 0
    while sum(rings.values()) < sum_min and guard < 200:
        candidates = [k for k in keys if rings[k] < ring_max]
        if not candidates:
            break
        rings[candidates[dice.rand_int_range(0, len(candidates) - 1)]] += 1
        guard += 1
    while sum(rings.values()) > sum_max and guard < 400:
        candidates = [k for k in keys if rings[k] > ring_min]
        if not candidates:
            break
        rings[candidates[dice.rand_int_range(0, len(candidates) - 1)]] -= 1
        guard += 1


def generate(
    name: str,
    rank: int,
    dice: DiceEngine,
    clan: str = "",
    family: str = "",
    school: str = "",
    school_type: str = "Bushi",
    school_skills: list[str] | None = None,
    base_honor: float = 3.5,
) -> Character:
    rank = max(MIN_RANK, min(MAX_RANK, rank))
    ring_min, ring_max, sum_min, sum_max = RANK_RINGS[rank]

    # 1. Ring values within per-ring bounds, then nudged into the sum band.
    rings = {r: dice.rand_int_range(ring_min, ring_max) for r in ("air", "earth", "fire", "water", "void")}
    _adjust_sum(rings, sum_min, sum_max, ring_min, ring_max, dice)

    c = Character(
        name=name, clan=clan, family=family, school=school,
        school_type=school_type, is_npc=True,
    )
    c.school_rank = rank  # techniques are known up to School Rank = Insight Rank (s22.4)

    # 2. Traits: a Ring = min of its two Traits (character_stats.gd). Set the lower
    #    trait to the ring value; give the other +0/+1 variance (upward only, so the
    #    Ring/sum stays within the LOCKED band). Void is standalone.
    c.void_ring = rings["void"]
    for ring, (trait_a, trait_b) in RING_TRAITS.items():
        base = rings[ring]
        higher = min(ring_max, base + dice.rand_int_range(0, 1))
        pair = [base, higher]
        if dice.rand_int_range(0, 1) == 0:
            pair.reverse()
        setattr(c, trait_a, pair[0])
        setattr(c, trait_b, pair[1])
    c.current_void_points = c.max_void_points = c.void_ring

    # 3. Honor (school value, defaulted) ± 0.5 variance; Glory by Rank.
    honor = base_honor + dice.rand_int_range(-1, 1) * 0.5
    c.honor = max(0.0, min(10.0, honor))
    c.glory = 1.0 + 0.5 * (rank - 1)

    # 4. Age from the Rank's range; koku = 1d10 x Rank (savings term only).
    age_lo, age_hi = RANK_AGE[rank]
    c.age = dice.rand_int_range(age_lo, age_hi)
    c.koku = float(dice.roll_d10() * rank)

    # 5. Skills: caller-supplied school-skill names distributed per Rank. One
    #    becomes the specialty. No skill names are invented here.
    skills = [s.strip().title() for s in (school_skills or []) if s.strip()]
    if skills:
        base_rank = SKILL_BASE[rank]
        for s in skills:
            c.skills[s] = base_rank
        specialty = skills[dice.rand_int_range(0, len(skills) - 1)]
        c.skills[specialty] = SKILL_SPECIALTY[rank]

    return c
