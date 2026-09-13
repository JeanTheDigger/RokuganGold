"""L5R 4e constants shared by the rules layer.

Values transcribed from `shared/enums.gd` (Ring / Trait / WoundLevel enums,
RING_TRAITS, WOUND_PENALTIES). Nothing here is invented: it mirrors the
GDScript so the bot and the game agree on the numbers.
"""

from __future__ import annotations

# The eight Traits plus the standalone Void, by their sheet attribute names.
TRAITS: list[str] = [
    "stamina", "willpower",       # Earth
    "strength", "perception",     # Water
    "agility", "intelligence",    # Fire
    "reflexes", "awareness",      # Air
    "void",                       # Void (standalone)
]

RINGS: list[str] = ["air", "earth", "fire", "water", "void"]

# Ring = min(trait1, trait2); Void is standalone (shared/enums.gd RING_TRAITS).
RING_TRAITS: dict[str, tuple[str, str]] = {
    "air": ("reflexes", "awareness"),
    "earth": ("stamina", "willpower"),
    "fire": ("agility", "intelligence"),
    "water": ("strength", "perception"),
}

# WoundLevel order and per-level penalties (shared/enums.gd WOUND_PENALTIES).
WOUND_LEVELS: list[str] = [
    "Healthy", "Nicked", "Grazed", "Hurt", "Injured", "Crippled", "Down", "Out", "Dead",
]
WOUND_PENALTIES: list[int] = [0, -3, -5, -10, -15, -20, -40, 0, 0]

# School types (shared/enums.gd SchoolType).
SCHOOL_TYPES: list[str] = ["Bushi", "Courtier", "Shugenja", "Monk", "Ninja", "Artisan"]
