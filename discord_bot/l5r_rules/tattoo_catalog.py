"""L5R 4e Togashi Tattoo Catalog - GDD s57.25.11 (LOCKED).

25 mystical tattoos granted to monks of the Togashi Tattooed Order,
Kikage Zumi, and Hoshi Tsurui Zumi schools. Each has a unique effect.
Two are permanent passives (Mantis, Ocean passive). Most are activated
as Free Actions with only one active at a time. Default duration on
the ASCII map is 2 x School Rank rounds.
"""

from __future__ import annotations

TATTOO_CATALOG: dict[str, dict] = {
    "balance": {
        "name": "Balance",
        "effect": "Spells targeting the monk have their TN modified by (2 x School Rank) + 5: harmful spells harder to land, beneficial spells easier.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "bamboo": {
        "name": "Bamboo",
        "effect": "Armor TN increased by (2 x School Rank) + 5. Mutually exclusive with physical armor (tattoo must be exposed).",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "bear": {
        "name": "Bear",
        "effect": "Choose at activation: Stamina +School Rank, OR Strength +ceil(School Rank / 2). Choice locked for duration.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "blaze": {
        "name": "Blaze",
        "effect": "Unarmed strikes deal additional fire damage equal to Fire Ring + School Rank.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "centipede": {
        "name": "Centipede",
        "effect": "World map only. Move to any land-connected destination (no ocean). Costs 2 AP + 1 AP exhaustion.",
        "activation": "free_action",
        "duration": "instant",
        "passive": False,
        "layer": "world_map",
    },
    "cloud": {
        "name": "Cloud",
        "effect": "Physical attacks that hit require the attacker to re-roll; if the re-roll misses, the hit is negated. Monk cannot attack while active.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "crab": {
        "name": "Crab",
        "effect": "Gain Reduction equal to Earth Ring.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "crane": {
        "name": "Crane",
        "effect": "Gain a pool of bonus dice = School Rank + Air Ring. Each adds +1k0 to a Social Skill Roll (max Void Ring per roll). Dice lost if another tattoo is activated.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "dragon": {
        "name": "Dragon",
        "effect": "Complex Action: breathe fire in a cone (2-3 tiles). Damage: Fire Ring k Fire Ring. Monk takes Fire Ring self-damage per use. ASCII map only.",
        "activation": "complex_action",
        "duration": "standard",
        "passive": False,
        "layer": "ascii_map",
    },
    "hawk": {
        "name": "Hawk",
        "effect": "Complex Action: leap Water Ring x 5 tiles. Airborne during leap (ignores terrain/enemies). ASCII map only.",
        "activation": "complex_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "ki-rin": {
        "name": "Ki-Rin",
        "effect": "Re-roll any one of your rolls per round, keeping the higher result. Resets each round.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "lion": {
        "name": "Lion",
        "effect": "Gain temporary ranks equal to School Rank in one Bugei skill of choice (capped at Rank 10). Choice locked for duration.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "mantis": {
        "name": "Mantis",
        "effect": "PERMANENT PASSIVE. Complete immunity to all Fear effects. Does not block other tattoos.",
        "activation": "passive",
        "duration": "permanent",
        "passive": True,
        "layer": "both",
    },
    "mountain": {
        "name": "Mountain",
        "effect": "All Wound Penalties reduced by (School Rank + 2), minimum 0.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "ocean": {
        "name": "Ocean",
        "effect": "PASSIVE: No longer requires food or drink. ACTIVE (instant, 1/OOC day): Fully rested + all Void Points restored.",
        "activation": "mixed",
        "duration": "passive+instant",
        "passive": True,
        "layer": "both",
    },
    "phoenix": {
        "name": "Phoenix",
        "effect": "REACTIVE: When reduced to Down or below, if 1+ VP remains, lose all VP and heal School Rank x 10 wounds. Cooldown: 1 IC week.",
        "activation": "reactive",
        "duration": "instant",
        "passive": False,
        "layer": "both",
    },
    "scorpion": {
        "name": "Scorpion",
        "effect": "Two effects: +School Rank k0 on Stealth rolls. Unarmed attacks auto-Daze on any exploding damage die.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "spider": {
        "name": "Spider",
        "effect": "Auto-succeed all Athletics (Climbing) checks. Climbing speed halved. Falling if deactivated mid-climb.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "storm": {
        "name": "Storm",
        "effect": "Unarmed Knockdown maneuver costs only 1 Raise instead of standard. Contested Strength Roll still applies.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "void": {
        "name": "Void",
        "effect": "Sense all living things within School Rank x 2 tiles. Penetrates walls, darkness, Stealth. Reports count and category per direction.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "volcano": {
        "name": "Volcano",
        "effect": "Skin becomes lava. Wood weapons: Reduction 5 + weapon destroyed. Metal weapons: Contested Fire Roll or disarm. Sacred weapons immune. Unarmed: no effect.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "wave": {
        "name": "Wave",
        "effect": "+Insight Rank k0 on Contested Strength for unarmed Knockdown. Same bonus defensively vs all Knockdown attempts.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "both",
    },
    "whisper": {
        "name": "Whisper",
        "effect": "World map only. Instant message delivery (like WRITE_LETTER but uninterceptible). Range: 2 provinces per School Rank. One-way.",
        "activation": "free_action",
        "duration": "instant",
        "passive": False,
        "layer": "world_map",
    },
    "wind": {
        "name": "Wind",
        "effect": "Gain an extra Simple Action per round (cannot be used for attacks). No movement cap. ASCII map only.",
        "activation": "free_action",
        "duration": "standard",
        "passive": False,
        "layer": "ascii_map",
    },
    "wolf": {
        "name": "Wolf",
        "effect": "Free Raises on Hunting (Tracking) equal to School Rank. Duration: School Rank hours (lasts full mission on ASCII map).",
        "activation": "free_action",
        "duration": "school_rank_hours",
        "passive": False,
        "layer": "both",
    },
}

TATTOO_SCHOOL_ALLOTMENTS: dict[str, dict[int, int]] = {
    "Togashi Tattooed Order": {1: 2, 3: 2, 5: 2},
    "Kikage Zumi": {1: 1, 3: 1, 5: 1},
    "Hoshi Tsurui Zumi": {1: 1, 4: 1},
}

TATTOO_SCHOOLS = list(TATTOO_SCHOOL_ALLOTMENTS.keys())


def get_tattoo(name: str) -> dict | None:
    return TATTOO_CATALOG.get(name.lower().strip().replace(" ", "-") if " " in name.strip() else name.lower().strip())


def tattoo_names() -> list[str]:
    return sorted(TATTOO_CATALOG.keys())
