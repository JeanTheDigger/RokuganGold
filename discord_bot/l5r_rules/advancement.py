"""Character advancement — spending Experience to raise Rings and Skills.

All costs are the LOCKED values from GDD Section 48 ("Insight Rank Advancement &
Progression"), via its XP cost reference (1 XP = 200 progress):

  - Skill to rank N: N × 5 XP   (0→1 = 5, 1→2 = 10, … 4→5 = 25)
  - Ring  to rank N: N × 20 XP  (2→3 = 60, 3→4 = 80, 4→5 = 100)

Raising a Ring uses the exact GDScript semantics from npc_advancement.gd
`_raise_ring`: a Ring is min(trait1, trait2), so raise every underlying Trait
currently at that minimum (one when uneven, both when equal) so the Ring rises by
one; Void just increments `void_ring` (and its max Void Points). Rings and Skills
cap at rank 5. Insight and Insight Rank are derived (see stats.py) and update
automatically once a Ring or Skill rises — nothing here sets them.

Nothing is invented: every number traces to Section 48.
"""

from __future__ import annotations

from . import enums, stats
from .character import Character

SKILL_XP_PER_RANK = 5    # Skill to rank N costs N × 5 XP (s48)
RING_XP_PER_RANK = 20    # Ring to rank N costs N × 20 XP (s48)
MAX_SKILL_RANK = 5       # s48 Skill Progress Costs table
MAX_RING_RANK = 5        # s48 Ring Progress Costs table


def ring_raise_quote(character: Character, ring: str) -> tuple[int, int] | None:
    """(new_rank, xp_cost) to raise a Ring, or None if already at the cap."""
    current = stats.ring_value(character, ring)
    if current >= MAX_RING_RANK:
        return None
    new_rank = current + 1
    return new_rank, new_rank * RING_XP_PER_RANK


def skill_raise_quote(character: Character, skill: str) -> tuple[int, int] | None:
    """(new_rank, xp_cost) to raise/learn a Skill, or None if already at the cap."""
    current = character.skills.get(skill, 0)
    if current >= MAX_SKILL_RANK:
        return None
    new_rank = current + 1
    return new_rank, new_rank * SKILL_XP_PER_RANK


def apply_ring_raise(character: Character, ring: str) -> None:
    """Raise a Ring by one rank (npc_advancement.gd `_raise_ring` semantics)."""
    ring = ring.lower()
    if ring == "void":
        character.void_ring += 1
        character.max_void_points = character.void_ring
        return
    trait_a, trait_b = enums.RING_TRAITS[ring]
    v_a = character.get_trait(trait_a)
    v_b = character.get_trait(trait_b)
    ring_min = min(v_a, v_b)
    if v_a == ring_min:
        character.set_trait(trait_a, v_a + 1)
    if v_b == ring_min:
        character.set_trait(trait_b, v_b + 1)


def apply_skill_raise(character: Character, skill: str) -> None:
    character.skills[skill] = character.skills.get(skill, 0) + 1


def cost_table() -> str:
    """Human-readable reference of the s48 costs."""
    skills = " · ".join(f"→{n} {n * SKILL_XP_PER_RANK}xp" for n in range(1, MAX_SKILL_RANK + 1))
    rings = " · ".join(f"→{n} {n * RING_XP_PER_RANK}xp" for n in range(3, MAX_RING_RANK + 1))
    return f"Skills (by new rank): {skills}\nRings (by new rank): {rings}"
