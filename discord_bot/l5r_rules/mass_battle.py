"""L5R 4e Mass Battle system.

Core Rulebook p.173-175: Mass Battle is resolved in rounds. Each round,
participants roll Battle/Perception to determine their engagement level.
The DM sets a Battle TN based on the army's situation.

Engagement results determine what the character faces that round:
  - Reserves (low roll): safe, but no glory
  - Disengaged (near miss): light skirmishing
  - Engaged (success): full combat, potential glory
  - Heavily Engaged (raises): intense fighting, high risk/reward
  - Heroic Opportunity (great success): chance for legendary deeds
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
    if margin < -10:
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
