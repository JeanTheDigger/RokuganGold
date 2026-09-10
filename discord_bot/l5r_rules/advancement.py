"""Character advancement — automatic XP accrual and player self-service spending,
at tabletop L5R 4e RAW costs (no DM in the loop).

RAW advancement costs (L5R 4e Core — the same ratios the GDD cites):
  - Skill to rank N: N × 2 XP
  - Trait to rank N: N × 4 XP
  - Void  to rank N: N × 6 XP

RAW raises individual Traits (a Ring is just min of its two Traits, derived in
stats.py), so players buy Traits and Void directly. Traits/Void cap at rank 5
(human maximum); Skills cap at rank 10 (the RAW mastery ceiling). Insight and
Insight Rank are derived and update automatically once a Trait/Skill rises.

XP is credited automatically on a weekly stipend (the DM grants nothing) — see
`accrue`. The stipend RATE is an operator setting, not a game value.
"""

from __future__ import annotations

from .character import Character

SKILL_XP_MULT = 2   # Skill to rank N = N × 2 XP (RAW)
TRAIT_XP_MULT = 4   # Trait to rank N = N × 4 XP (RAW)
VOID_XP_MULT = 6    # Void  to rank N = N × 6 XP (RAW)

MAX_TRAIT_RANK = 5   # human maximum
MAX_VOID_RANK = 5
MAX_SKILL_RANK = 10  # RAW mastery ceiling

WEEK_SECONDS = 7 * 24 * 3600

# The eight Traits plus Void, by the value used in commands.
TRAIT_NAMES = [
    "stamina", "willpower", "strength", "perception",
    "agility", "intelligence", "reflexes", "awareness", "void",
]


def _trait_current(character: Character, trait: str) -> int:
    return character.void_ring if trait == "void" else character.get_trait(trait)


def trait_raise_quote(character: Character, trait: str) -> tuple[int, int] | None:
    """(new_rank, xp_cost) to raise a Trait or Void, or None if at the cap."""
    trait = trait.lower()
    current = _trait_current(character, trait)
    if trait == "void":
        cap, mult = MAX_VOID_RANK, VOID_XP_MULT
    else:
        cap, mult = MAX_TRAIT_RANK, TRAIT_XP_MULT
    if current >= cap:
        return None
    new_rank = current + 1
    return new_rank, new_rank * mult


def skill_raise_quote(character: Character, skill: str) -> tuple[int, int] | None:
    """(new_rank, xp_cost) to raise/learn a Skill, or None if at the cap."""
    current = character.skills.get(skill, 0)
    if current >= MAX_SKILL_RANK:
        return None
    new_rank = current + 1
    return new_rank, new_rank * SKILL_XP_MULT


def apply_trait_raise(character: Character, trait: str) -> None:
    trait = trait.lower()
    if trait == "void":
        character.void_ring += 1
        character.max_void_points = character.void_ring
        return
    character.set_trait(trait, character.get_trait(trait) + 1)


def apply_skill_raise(character: Character, skill: str) -> None:
    character.skills[skill] = character.skills.get(skill, 0) + 1


def accrue(character: Character, now_ts: float, rate_per_week: float) -> float:
    """Credit the automatic weekly XP stipend, lazily. Mutates the character
    (xp + the accrual anchor) and returns how much XP was credited this call.

    Whole weeks only; the remainder is carried by leaving the anchor mid-week.
    First contact just anchors the clock (no retroactive credit). rate <= 0 keeps
    the clock fresh so re-enabling later does not dump a backlog.
    """
    if character.xp_last_accrual <= 0:
        character.xp_last_accrual = now_ts
        return 0.0
    if rate_per_week <= 0:
        character.xp_last_accrual = now_ts
        return 0.0
    elapsed = now_ts - character.xp_last_accrual
    if elapsed < WEEK_SECONDS:
        return 0.0
    weeks = int(elapsed // WEEK_SECONDS)
    credited = weeks * rate_per_week
    character.xp += credited
    character.xp_last_accrual += weeks * WEEK_SECONDS
    return credited


def cost_table() -> str:
    skills = " · ".join(f"→{n} {n * SKILL_XP_MULT}xp" for n in range(1, 6)) + " … →10 20xp"
    traits = " · ".join(f"→{n} {n * TRAIT_XP_MULT}xp" for n in range(3, 6))
    void = " · ".join(f"→{n} {n * VOID_XP_MULT}xp" for n in range(3, 6))
    return (
        f"**Skills** (new rank × 2): {skills}\n"
        f"**Traits** (new rank × 4): {traits}\n"
        f"**Void** (new rank × 6): {void}"
    )
