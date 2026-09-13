"""Access helpers for the family catalog: lookup, search, and apply to character."""

from __future__ import annotations

from .families_catalog import FAMILIES_DATA

ALL = FAMILIES_DATA
_BY_NAME = {f["name"].lower(): f for f in FAMILIES_DATA}


def get(name: str) -> dict | None:
    return _BY_NAME.get(name.lower().strip())


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [f for f in FAMILIES_DATA if q in f["name"].lower() or q in f["clan"].lower()]


def by_clan(clan: str) -> list[dict]:
    return [f for f in FAMILIES_DATA if f["clan"].lower() == clan.lower()]


def names() -> list[str]:
    return sorted(f["name"] for f in FAMILIES_DATA)


def apply_to_character(character, family: dict) -> str:
    """Apply the family's +1 Trait bonus. Mutates the character. Returns a report string."""
    character.family = family["name"]
    trait = family["bonus_trait"]
    if trait == "void":
        character.void_ring += 1
        character.max_void_points = character.void_ring
        character.current_void_points = character.void_ring
    else:
        character.set_trait(trait, character.get_trait(trait) + 1)
    return f"+1 {trait.capitalize()}"
