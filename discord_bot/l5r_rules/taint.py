"""L5R 4e Shadowlands Taint progression system (GDD s42, sheet field s22.3).

Taint is a score of the form Rank.Points: 10 Points = 1 Rank, so 2.3 is
Rank 2 with 3 Points. Taint Rank is the whole-number part. Rank effects,
mutation thresholds and Social penalties follow s42.
"""

from __future__ import annotations

import random

from . import stats
from .character import Character

TAINT_RANK_EFFECTS: dict[int, str] = {
    0: "Seeds of Darkness: not treated as Tainted; spells targeting the Tainted do not register. At worst, occasional nightmares.",
    1: "Passive Infection: recognised as Tainted by specific spells and abilities, otherwise functions normally. Occasional nightmares; may feel sick or tired.",
    2: "Active Infection: nightmares, nausea and vomiting, muscle tremors, mild hallucinations. Develops one Shadowlands Power (usually Minor).",
    3: "Consuming: paranoid and transformed. -1k0 to all Social Skill rolls. One additional Shadowlands Power and one physical mutation.",
    4: "Deadly: barely functions in society; obsessed with blood, death and flesh. -2k0 to all Social Skill rolls; Willpower TN 15 under stress or resort to violence; max Void Points -1. Two Shadowlands Powers (one Major) and one more mutation.",
    5: "The Lost: claimed by the Shadowlands unless exceptional (a Ring at 6+ holds on until Rank 7). Becomes a creature under GM control.",
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
    "Paranoia: trust no one",
    "Bloodlust: urge to violence",
    "Nightmares: Fatigue after rest (no VP refresh without Meditation TN 20)",
    "Whispers: hears kansen speaking",
    "Obsession: fixates on a single goal",
    "Cruelty: enjoys others' suffering",
    "Megalomania: believes self above mortals",
    "Apathy: loses emotional connection",
]


def taint_rank(character: Character) -> int:
    """Whole-number part of the Taint score (s42: 10 Points = 1 Rank)."""
    return stats.taint_rank(character)


def taint_description(rank: int) -> str:
    return TAINT_RANK_EFFECTS.get(rank, TAINT_RANK_EFFECTS[5])


def is_lost(character: Character) -> bool:
    return taint_rank(character) >= 5


def social_penalty(character: Character) -> int:
    """Rolled dice lost on Social Skill rolls (s42): -1k0 at Rank 3, -2k0 at Rank 4+."""
    rank = taint_rank(character)
    if rank >= 4:
        return 2
    if rank >= 3:
        return 1
    return 0


def mutation_roll(rng: random.Random | None = None) -> str:
    """Roll a random mutation (d10 on the mutations table)."""
    return (rng or random).choice(MUTATIONS)


def madness_roll(rng: random.Random | None = None) -> str:
    """Roll a random madness effect."""
    return (rng or random).choice(MADNESS)


def check_threshold_crossing(old_taint: float, new_taint: float, character: Character) -> dict | None:
    """Check if adding taint crosses a Taint Rank boundary.
    Returns info about the new rank if crossed, None otherwise."""
    old_rank = min(int(max(0.0, old_taint)), 10)
    new_rank = min(int(max(0.0, new_taint)), 10)
    if new_rank > old_rank:
        result = {
            "old_rank": old_rank,
            "new_rank": new_rank,
            "description": taint_description(new_rank),
            "is_lost": new_rank >= 5,
        }
        if new_rank >= 3:
            result["mutation"] = mutation_roll()
        if new_rank >= 4:
            result["madness"] = madness_roll()
        return result
    return None
