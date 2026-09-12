"""L5R 4e Shadowlands Taint progression system.

Taint accumulates as a float. Taint Rank = floor(Taint / Earth Ring).
At Taint Rank thresholds, characters suffer mutations and madness.

L5R 4e Core Rulebook p.274-276.
"""

from __future__ import annotations

from . import stats
from .character import Character

TAINT_RANK_EFFECTS: dict[int, str] = {
    0: "No noticeable Taint.",
    1: "Minor physical change (pallor, shadow under eyes). Others may notice with Lore: Shadowlands check.",
    2: "Definite physical mutation (discolored veins, dark spots). Social penalty TN +5. Minor mental urges.",
    3: "Severe mutation (claws, inhuman eyes, scaled patches). Social penalty TN +10. Compulsive violent urges.",
    4: "Monstrous transformation. Social penalty TN +15. Risk of losing control (Honor Roll TN 20 to resist acting on Taint urges).",
    5: "Lost to the Taint. Character becomes an NPC under DM control.",
}

MUTATIONS: list[str] = [
    "Discolored skin patches",
    "Blackened veins visible under skin",
    "Eyes change color (red, yellow, black)",
    "Fingernails harden into claws (+0k1 unarmed)",
    "Patches of chitinous scales (+1 Reduction)",
    "Extra joint in fingers",
    "Voice deepens unnaturally",
    "Hair falls out or turns white",
    "Faint sulfurous smell",
    "Shadow moves independently",
]

MADNESS: list[str] = [
    "Paranoia — trust no one",
    "Bloodlust — urge to violence",
    "Nightmares — Fatigue after rest (no VP refresh without Meditation TN 20)",
    "Whispers — hears kansen speaking",
    "Obsession — fixates on a single goal",
    "Cruelty — enjoys others' suffering",
    "Megalomania — believes self above mortals",
    "Apathy — loses emotional connection",
]


def taint_rank(character: Character) -> int:
    """Taint Rank = floor(Taint / Earth Ring). Capped at 5 (lost)."""
    earth = stats.earth_ring(character)
    if earth <= 0:
        return 5 if character.taint > 0 else 0
    rank = int(character.taint // earth)
    return min(rank, 5)


def taint_description(rank: int) -> str:
    return TAINT_RANK_EFFECTS.get(rank, TAINT_RANK_EFFECTS[5])


def is_lost(character: Character) -> bool:
    return taint_rank(character) >= 5


def social_penalty(character: Character) -> int:
    """TN penalty to Social rolls from visible Taint (Taint Rank 2+)."""
    rank = taint_rank(character)
    if rank >= 4:
        return 15
    if rank >= 3:
        return 10
    if rank >= 2:
        return 5
    return 0


def mutation_roll() -> str:
    """Roll a random mutation (d10 on the mutations table)."""
    import random
    return random.choice(MUTATIONS)


def madness_roll() -> str:
    """Roll a random madness effect."""
    import random
    return random.choice(MADNESS)


def check_threshold_crossing(old_taint: float, new_taint: float, character: Character) -> dict | None:
    """Check if adding taint crosses a Taint Rank boundary.
    Returns info about the new rank if crossed, None otherwise."""
    earth = stats.earth_ring(character)
    if earth <= 0:
        return None
    old_rank = min(int(old_taint // earth), 5)
    new_rank = min(int(new_taint // earth), 5)
    if new_rank > old_rank:
        result = {
            "old_rank": old_rank,
            "new_rank": new_rank,
            "description": taint_description(new_rank),
            "is_lost": new_rank >= 5,
        }
        if new_rank >= 2:
            result["mutation"] = mutation_roll()
        if new_rank >= 3:
            result["madness"] = madness_roll()
        return result
    return None
