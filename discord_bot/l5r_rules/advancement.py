"""Character advancement: players spend DM-granted Experience, at tabletop
L5R 4e RAW costs. No automatic faucet: a DM grants XP; players spend it.

RAW costs (owner-confirmed):
  - Skill  to rank N        : N × 1 XP   (3→4 = 4)
  - Trait  to rank N        : N × 4 XP   (3→4 = 16)
  - Void   to rank N        : N × 6 XP   (3→4 = 24)
  - Skill Emphasis          : flat 2 XP  (max ⌈skill rank ÷ 2⌉ per skill)
  - Kata / memorised Spell  : 1 XP × Mastery Level
  - Kiho                    : 1 XP × Mastery Level (Brotherhood monks); non-Brotherhood
                              monks pay 1.5 × ML, rounded up (per s38a);
                              shugenja pay 2 × ML

RAW raises individual Traits (a Ring is min of its two Traits, derived in
stats.py). Traits/Void cap at 5, Skills at 10. Insight and Insight Rank are
derived and follow automatically. Prerequisites (school/ring gating for kata,
kiho, spells) are left to the DM: the bot handles the XP economy and records
what was bought.
"""

from __future__ import annotations

import math
import re

from . import skill_groups
from .character import Character

SKILL_XP_MULT = 1   # Skill to rank N = N × 1 XP (RAW)
TRAIT_XP_MULT = 4   # Trait to rank N = N × 4 XP (RAW)
VOID_XP_MULT = 6    # Void  to rank N = N × 6 XP (RAW)
EMPHASIS_COST = 2   # flat 2 XP per Skill Emphasis (RAW)

MAX_TRAIT_RANK = 5   # human maximum
MAX_VOID_RANK = 5
MAX_SKILL_RANK = 10  # RAW mastery ceiling

TRAIT_NAMES = [
    "stamina", "willpower", "strength", "perception",
    "agility", "intelligence", "reflexes", "awareness", "void",
]


_ELEMENT_TRAITS = {
    "air": ("reflexes", "awareness"), "earth": ("stamina", "willpower"),
    "fire": ("agility", "intelligence"), "water": ("strength", "perception"),
}


def _owns(items: list[str], name: str) -> bool:
    return any(i.lower() == name.lower() or i.lower().startswith(name.lower() + " (") or i.lower().startswith(name.lower() + ":")
               for i in items)


def has_friend_of_brotherhood(character: Character) -> bool:
    return _owns(character.advantages, "Friend of the Brotherhood")


def trait_step_cost(character: Character, trait: str, new_rank: int) -> int:
    """XP to raise a Trait or Void to `new_rank`, with the character's Advantages applied:
    Enlightened takes 2 off each Void raise, Elemental Blessing 1 off each of its element's two Traits."""
    trait = trait.lower()
    cost = new_rank * (VOID_XP_MULT if trait == "void" else TRAIT_XP_MULT)
    if trait == "void" and _owns(character.advantages, "Enlightened"):
        cost -= 2
    for a in character.advantages:
        if a.lower().startswith("elemental blessing"):
            m = re.search(r"\b(air|earth|fire|water)\b", a.lower())
            if m and trait in _ELEMENT_TRAITS[m.group(1)]:
                cost -= 1
                break
    return max(1, cost)


def skill_step_cost(character: Character, skill: str, new_rank: int) -> int:
    """XP to raise a Skill to `new_rank`. Obtuse doubles it for any High Skill except Investigation and Medicine."""
    cost = new_rank * SKILL_XP_MULT
    if _owns(character.disadvantages, "Obtuse"):
        b = skill_groups.base(skill)
        if skill_groups.is_high(skill) and b not in ("investigation", "medicine"):
            cost *= 2
    return cost


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
    return new_rank, trait_step_cost(character, trait, new_rank)


def skill_raise_quote(character: Character, skill: str) -> tuple[int, int] | None:
    """(new_rank, xp_cost) to raise/learn a Skill, or None if at the cap."""
    current = character.skills.get(skill, 0)
    if current >= MAX_SKILL_RANK:
        return None
    new_rank = current + 1
    return new_rank, skill_step_cost(character, skill, new_rank)


def emphasis_limit(skill_rank: int) -> int:
    """RAW: at most ⌈skill rank ÷ 2⌉ Emphases per skill."""
    return math.ceil(skill_rank / 2)


def emphasis_quote(character: Character, skill: str, emphasis: str) -> tuple[int, str | None]:
    """(cost, error). error is a message string when the buy is not allowed."""
    rank = character.skills.get(skill, 0)
    if rank < 1:
        return EMPHASIS_COST, f"You need at least 1 rank in **{skill}** to add an Emphasis."
    existing = list(character.emphases.get(skill, []))
    if any(e.lower() == emphasis.lower() for e in existing):
        return EMPHASIS_COST, f"**{skill}** already has the **{emphasis}** Emphasis."
    limit = emphasis_limit(rank)
    if len(existing) >= limit:
        return EMPHASIS_COST, (
            f"**{skill}** (rank {rank}) already has its maximum of {limit} "
            f"Emphasis{'es' if limit != 1 else ''}."
        )
    return EMPHASIS_COST, None


def apply_trait_raise(character: Character, trait: str) -> None:
    trait = trait.lower()
    if trait == "void":
        character.void_ring += 1
        character.max_void_points = character.void_ring
        return
    character.set_trait(trait, character.get_trait(trait) + 1)


def apply_skill_raise(character: Character, skill: str) -> None:
    character.skills[skill] = character.skills.get(skill, 0) + 1


def apply_emphasis(character: Character, skill: str, emphasis: str) -> None:
    character.emphases.setdefault(skill, []).append(emphasis)


def kiho_cost(mastery_level: int, non_brotherhood: bool = False, shugenja: bool = False) -> int:
    """Kiho XP cost. Brotherhood monks: 1× ML. Non-Brotherhood monks: 1.5× ML (ceil).
    Shugenja: 2× ML."""
    if shugenja:
        return max(1, mastery_level * 2)
    return math.ceil(mastery_level * 1.5) if non_brotherhood else max(1, mastery_level)


def misc_cost(mastery_level: int) -> int:
    """Kata, memorised spell, and (Brotherhood) kiho all cost 1 XP × Mastery Level."""
    return max(1, mastery_level)


def cost_table() -> str:
    return (
        "**Traits**: new rank × 4 (3→4 = 16) · cap 5\n"
        "**Void**: new rank × 6 (3→4 = 24) · cap 5\n"
        "**Skills**: new rank × 1 (3→4 = 4) · cap 10\n"
        "**Skill Emphasis**: flat 2 (max ⌈rank ÷ 2⌉ per skill)\n"
        "**Kata / memorised Spell**: 1 × Mastery Level\n"
        "**Kiho**: 1 × Mastery Level (Brotherhood); 1.5 × ML, "
        "rounded up, for non-Brotherhood monks; 2 × ML for shugenja"
    )
