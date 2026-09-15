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


# --- Rank effects and periodic resistance (s42) ------------------------------

# Days between periodic Taint resistance rolls, by Rank (s42: once per month at
# Rank 0-1, twice per month at Rank 2, weekly at Rank 3, daily at Rank 4).
# The Lost (Rank 5+) no longer roll. A Rokugani month is 28 days.
PERIODIC_ROLL_DAYS: dict[int, int] = {0: 28, 1: 28, 2: 14, 3: 7, 4: 1}

_SOCIAL_SKILLS = {"courtier", "etiquette", "intimidation", "temptation", "sincerity", "perform"}


def periodic_roll_interval(rank: int) -> int | None:
    return PERIODIC_ROLL_DAYS.get(rank)


def periodic_roll_tn(rank: int) -> int:
    """s42: TN 5 at Rank 0, +5 per Rank thereafter."""
    return 5 + 5 * rank


def void_point_cap(character: Character) -> int:
    """Maximum Void Points after Taint: Rank 4+ reduces the maximum by 1 (s42)."""
    cap = character.max_void_points
    if taint_rank(character) >= 4:
        cap -= 1
    return max(0, cap)


def social_roll_penalty(character: Character, skill_name: str) -> tuple[int, list[str]]:
    """(rolled-dice delta, notes) for a Social Skill roll: -1k0 at Rank 3, -2k0 at Rank 4+ (s42)."""
    base = (skill_name or "").split(":")[0].strip().lower()
    if base not in _SOCIAL_SKILLS:
        return 0, []
    pen = social_penalty(character)
    if not pen:
        return 0, []
    return -pen, [f"Taint Rank {taint_rank(character)}: -{pen}k0 (Social Skill)"]


def has_jade_petal_tea(character: Character) -> bool:
    return any("jade petal tea" in name.lower() and qty > 0 for name, qty in character.inventory.items())


def resolve_periodic_roll(character: Character, dice_engine) -> dict:
    """The periodic Taint resistance roll (s42): Earth Ring roll vs TN 5 + 5 x Rank;
    Jade Petal Tea adds +2k2. Failure adds 1 Point (0.1) of Taint. Mutates the
    character's taint on failure and returns the details."""
    rank = taint_rank(character)
    earth = stats.earth_ring(character)
    tea = has_jade_petal_tea(character)
    rolled = earth + (2 if tea else 0)
    kept = earth + (2 if tea else 0)
    tn = periodic_roll_tn(rank)
    result = dice_engine.roll_and_keep(max(1, rolled), max(1, kept))
    success = result.total >= tn
    crossing = None
    old = character.taint
    if not success:
        character.taint = round(character.taint + 0.1, 1)
        crossing = check_threshold_crossing(old, character.taint, character)
    return {
        "rank": rank, "rolled": rolled, "kept": kept, "tn": tn,
        "total": result.total, "dice": result, "success": success,
        "tea": tea, "old_taint": old, "new_taint": character.taint,
        "crossing": crossing,
    }
