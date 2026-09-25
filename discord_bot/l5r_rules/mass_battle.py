"""L5R 4e Mass Battle system.

Two subsystems:

1. Core Rulebook engagement roll (resolve_battle_roll): Roll & Keep
   Battle/Perception vs DM-set TN to determine engagement level. Simpler
   system for quick resolution.

2. GDD s47 Battle Table (resolve_battle_table): The full mass battle
   individual-experience system. Player DECLARES engagement level, then
   rolls 1d10 + Water Ring + Battle Skill. Cross-reference with Army Status
   (Winning/Stalemate/Losing) and Engagement to get column on the Battle
   Table. Result: Wounds (each die 1k1), Glory earned, Duel or Heroic
   Opportunity trigger.
"""

from __future__ import annotations

from .dice import DiceEngine

ENGAGEMENT_LEVELS = {
    "reserves": {"name": "Reserves", "description": "Safe behind the lines. No combat this round. No Glory gain."},
    "disengaged": {"name": "Disengaged", "description": "Light skirmishing at the edges. Minor combat (1 opponent). +1 Glory point."},
    "engaged": {"name": "Engaged", "description": "In the thick of battle. Full combat (2-3 opponents). +3 Glory points."},
    "heavily_engaged": {"name": "Heavily Engaged", "description": "Intense fighting against elite opponents. High risk (3-5 opponents). +5 Glory points."},
    "heroic": {"name": "Heroic Opportunity", "description": "Face-to-face with the enemy commander or a dramatic turning point. +10 Glory points if successful. Failure may mean death."},
}

# ---------------------------------------------------------------------------
# GDD s47 Battle Table - Individual Character Experience in Mass Battle
# ---------------------------------------------------------------------------
# Each entry: (wounds_dice, glory, event)
# wounds_dice = number of 1k1 dice of damage the character suffers
# glory = Glory points earned this Battle Turn
# event = None | "duel" | "heroic"
# Row index = clamped((total - 1) // 3, 0, 9) - bands of 3 from 1-30
# Column index = 0-5 (columns 1-6)
# VALUES PROVISIONAL per GDD.
BATTLE_TABLE: list[list[tuple[int, int, str | None]]] = [
    # Roll 1-3
    [(1, 0, None), (2, 0, None), (3, 1, None), (4, 1, None), (5, 1, "duel"), (6, 3, "heroic")],
    # Roll 4-6
    [(1, 0, None), (1, 0, None), (3, 1, None), (4, 1, None), (5, 1, "duel"), (5, 2, "heroic")],
    # Roll 7-9
    [(1, 0, None), (0, 0, None), (2, 1, None), (3, 1, None), (4, 1, "duel"), (5, 1, "duel")],
    # Roll 10-12
    [(0, 0, None), (0, 0, None), (2, 0, "duel"), (3, 0, "heroic"), (4, 1, "heroic"), (4, 1, "duel")],
    # Roll 13-15
    [(0, 1, None), (0, 1, None), (1, 1, "duel"), (2, 1, None), (3, 1, None), (4, 1, "heroic")],
    # Roll 16-18
    [(0, 1, None), (0, 1, "duel"), (1, 1, None), (2, 1, "duel"), (3, 2, None), (3, 2, "heroic")],
    # Roll 19-21
    [(0, 2, None), (0, 2, "heroic"), (1, 2, None), (2, 2, None), (3, 2, "heroic"), (3, 2, "duel")],
    # Roll 22-24
    [(0, 2, "heroic"), (0, 2, None), (1, 2, "heroic"), (2, 2, None), (2, 3, None), (3, 3, "duel")],
    # Roll 25-27
    [(0, 2, None), (0, 2, "duel"), (0, 3, None), (1, 3, None), (2, 4, "heroic"), (3, 4, "heroic")],
    # Roll 28-30
    [(0, 3, "heroic"), (0, 3, "duel"), (0, 4, None), (1, 4, "duel"), (2, 5, None), (3, 5, "heroic")],
]

# Column mapping: Winning reads leftward (safer), Losing reads rightward.
COLUMN_MAP: dict[str, dict[str, int]] = {
    "winning":   {"reserves": 1, "disengaged": 2, "engaged": 3, "heavily_engaged": 4, "heroic": 5},
    "stalemate": {"reserves": 2, "disengaged": 3, "engaged": 4, "heavily_engaged": 5, "heroic": 6},
    "losing":    {"reserves": 3, "disengaged": 4, "engaged": 5, "heavily_engaged": 6, "heroic": 6},
}

ARMY_STATUS_NAMES: dict[str, str] = {
    "winning": "Winning",
    "stalemate": "Stalemate",
    "losing": "Losing",
}

ENGAGEMENT_NAMES: dict[str, str] = {
    "reserves": "Reserves",
    "disengaged": "Disengaged",
    "engaged": "Engaged",
    "heavily_engaged": "Heavily Engaged",
    "heroic": "Heroic Opportunity",
}


def resolve_battle_roll(
    perception: int,
    battle_skill: int,
    tn: int,
    dice_engine: DiceEngine,
    bonus: int = 0,
) -> dict:
    """Battle/Perception roll to determine engagement level.

    TN set by DM based on army situation:
      - Winning army: TN 10-15
      - Even battle: TN 15-20
      - Losing army: TN 20-30
      - Desperate last stand: TN 30+

    Result determines engagement:
      - Failed by 10+: Reserves
      - Failed by <10: Disengaged
      - Success: Engaged
      - Success by 10+: Heavily Engaged
      - Success by 20+: Heroic Opportunity
    """
    rolled = perception + battle_skill
    kept = perception
    explodes = battle_skill > 0
    result = dice_engine.roll_and_keep(max(1, rolled), max(1, kept), explodes)
    total = result.total + bonus
    margin = total - tn
    if margin <= -10:
        level = "reserves"
    elif margin < 0:
        level = "disengaged"
    elif margin < 10:
        level = "engaged"
    elif margin < 20:
        level = "heavily_engaged"
    else:
        level = "heroic"
    return {
        "total": total,
        "tn": tn,
        "margin": margin,
        "success": margin >= 0,
        "engagement": level,
        "engagement_info": ENGAGEMENT_LEVELS[level],
        "dice": result,
        "rolled": rolled,
        "kept": kept,
    }


def resolve_battle_turn_damage(
    engagement: str,
    dice_engine: DiceEngine,
) -> dict:
    """Roll damage sustained during a mass battle round based on engagement.

    Characters in more intense engagement take more incidental damage.
    Reserves: 0 damage. Disengaged: 1k1. Engaged: 2k1. Heavily Engaged: 3k2.
    Heroic: 4k3 (but potential for greater reward).
    """
    damage_dice = {
        "reserves": (0, 0),
        "disengaged": (1, 1),
        "engaged": (2, 1),
        "heavily_engaged": (3, 2),
        "heroic": (4, 3),
    }
    rolled, kept = damage_dice.get(engagement, (0, 0))
    if rolled == 0:
        return {"damage": 0, "dice": None, "rolled": 0, "kept": 0}
    result = dice_engine.roll_and_keep(rolled, kept)
    return {
        "damage": result.total,
        "dice": result,
        "rolled": rolled,
        "kept": kept,
    }


def resolve_battle_table(
    water_ring: int,
    battle_skill: int,
    army_status: str,
    engagement: str,
    dice_engine: DiceEngine,
    bonus: int = 0,
) -> dict:
    """GDD s47 Battle Table roll for individual mass battle experience.

    Roll = 1d10 (exploding) + Water Ring + Battle Skill + bonus.
    Cross-reference total with Army Status and declared Engagement Level
    to determine column. Look up result: Wounds dice, Glory, event.
    Each wound die is 1k1 (WkW total).
    """
    die_result = dice_engine.roll_and_keep(1, 1, True)
    total = die_result.total + water_ring + battle_skill + bonus

    col = COLUMN_MAP.get(army_status, COLUMN_MAP["stalemate"]).get(
        engagement, 3,
    )

    if total < 1:
        row = 0
    else:
        row = min(9, (total - 1) // 3)

    wounds_dice, glory, event = BATTLE_TABLE[row][col - 1]

    wound_damage = 0
    wound_roll = None
    if wounds_dice > 0:
        wound_roll = dice_engine.roll_and_keep(wounds_dice, wounds_dice, True)
        wound_damage = wound_roll.total

    return {
        "die_result": die_result,
        "total": total,
        "water_ring": water_ring,
        "battle_skill": battle_skill,
        "bonus": bonus,
        "army_status": army_status,
        "engagement": engagement,
        "column": col,
        "row_band": f"{row * 3 + 1}–{row * 3 + 3}",
        "wounds_dice": wounds_dice,
        "wound_damage": wound_damage,
        "wound_roll": wound_roll,
        "glory": glory,
        "event": event,
    }


def resolve_general_contest(
    perception_a: int,
    battle_a: int,
    perception_b: int,
    battle_b: int,
    dice_engine: DiceEngine,
    bonus_a: int = 0,
    bonus_b: int = 0,
) -> dict:
    """Contested Battle/Perception roll between opposing generals (RAW L5R 4e).

    Each general rolls Battle/Perception. Compare totals:
      - Difference >= 5: higher side is Winning, lower is Losing
      - Difference < 5: Stalemate
    GM applies bonuses for terrain, numbers, prior Heroic Opportunities.
    """
    rolled_a = perception_a + battle_a
    kept_a = perception_a
    explodes_a = battle_a > 0
    result_a = dice_engine.roll_and_keep(
        max(1, rolled_a), max(1, kept_a), explodes_a,
    )
    total_a = result_a.total + bonus_a

    rolled_b = perception_b + battle_b
    kept_b = perception_b
    explodes_b = battle_b > 0
    result_b = dice_engine.roll_and_keep(
        max(1, rolled_b), max(1, kept_b), explodes_b,
    )
    total_b = result_b.total + bonus_b

    diff = total_a - total_b
    if diff >= 5:
        status_a, status_b = "winning", "losing"
    elif diff <= -5:
        status_a, status_b = "losing", "winning"
    else:
        status_a, status_b = "stalemate", "stalemate"

    return {
        "total_a": total_a,
        "total_b": total_b,
        "diff": diff,
        "status_a": status_a,
        "status_b": status_b,
        "dice_a": result_a,
        "dice_b": result_b,
        "rolled_a": rolled_a,
        "kept_a": kept_a,
        "rolled_b": rolled_b,
        "kept_b": kept_b,
    }
