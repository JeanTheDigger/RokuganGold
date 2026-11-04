"""Saves the catalogue asks of a Disadvantage's owner ("must roll Willpower (TN 20) or ..."), as data.

Each entry names the Disadvantage, the Trait rolled, the TN (fixed, or 5 x a Glory Rank the GM names, or
set by the Disadvantage's level), and what a pass or a fail means. `/check drawback` rolls them so the
GM does not have to remember the numbers. Every value is the catalogue's text (GDD s45).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .character import Character


@dataclass(frozen=True)
class Drawback:
    key: str
    label: str
    trait: str
    tn: int | None          # fixed TN, or None when it depends on a Glory Rank or the level
    per_glory_rank: bool    # TN = 5 x the highest Glory Rank involved
    plus_honor_rank: bool   # roll (Trait + Honor Rank) keep Trait
    passed: str
    failed: str


DRAWBACKS: dict[str, Drawback] = {d.key: d for d in (
    Drawback("brash", "Brash", "willpower", 25, False, True,
             "Keeps their temper.", "Attacks the source of the threat or insult at once."),
    Drawback("cant lie", "Can't Lie", "willpower", 20, False, False,
             "Lets the lie pass.", "Cannot let the lie stand and corrects the liar at once."),
    Drawback("epilepsy", "Epilepsy", "willpower", 15, False, False,
             "No seizure.", "Has a seizure. Roll Willpower (TN 10) each minute to end it."),
    Drawback("enlightened madness", "Enlightened Madness", "willpower", None, False, False,
             "Holds on to their sanity.", "Is consumed by madness for eight hours."),
    Drawback("overconfident", "Overconfident", "perception", 20, False, False,
             "Recognizes the danger and may withdraw.", "Does not see the danger and presses the fight."),
    Drawback("soft-hearted", "Soft-Hearted", "willpower", 20, False, False,
             "Can bring themselves to kill.", "Cannot kill. (If they kill anyway, all TNs are +10 for a day.)"),
    Drawback("zakyo toshi stigma", "Zakyo Toshi Stigma", "willpower", 20, False, False,
             "Ignores the gambling.", "Abandons everything else to join the game. May roll again every ten minutes."),
    Drawback("rumormonger", "Rumormonger", "willpower", None, True, False,
             "Holds the rumor back.", "Spreads the rumor."),
    Drawback("contrary", "Contrary", "willpower", None, True, False,
             "Keeps quiet.", "Declares their position publicly: costs a conversation action or court AP, "
             "and counts as a minor Breach of Etiquette."),
    Drawback("lord moon's curse", "Lord Moon's Curse", "willpower", None, False, False,
             "Keeps control of their character tonight.", "Loses control of their character for the evening."),
)}


def owned_name(c: Character, key: str) -> str | None:
    """The sheet entry for this Disadvantage (with its parameter), or None."""
    for d in c.disadvantages:
        if d.lower().split(" (")[0].split(":")[0].strip() == key:
            return d
    return None


def _level_from(name: str, points_to_level: dict[int, int]) -> int:
    for n in re.findall(r"\d+", name):
        n = int(n)
        if n in points_to_level:
            return points_to_level[n]
    return 1


def tn_for(d: Drawback, owned: str, glory_rank: int | None) -> tuple[int | None, str]:
    """(TN, how it was worked out). TN is None when the GM must still give a Glory Rank."""
    if d.tn is not None:
        return d.tn, f"TN {d.tn}"
    if d.per_glory_rank:
        if glory_rank is None:
            return None, "needs the highest Glory Rank involved"
        return 5 * glory_rank, f"5 x Glory Rank {glory_rank}"
    if d.key == "enlightened madness":
        six = bool(re.search(r"\b6\b", owned))
        return (30, "6-point version, TN 30") if six else (20, "4-point version, TN 20")
    if d.key == "lord moon's curse":
        level = _level_from(owned, {3: 1, 5: 2, 7: 3, 1: 1, 2: 2})
        return 15 + 5 * (level - 1), f"level {level}: TN 15 + 5 per level after the first"
    return None, ""
