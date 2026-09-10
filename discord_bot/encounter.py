"""In-memory initiative tracker for combat encounters.

One Encounter per Discord channel. Combatants are ordered by initiative total
(highest first); ties keep insertion order. This is ephemeral scratch state for
running a fight's turn order — it is not persisted, so a bot restart clears any
in-progress encounters (acceptable for a turn tracker; sheets and wounds are in
the database and survive).

Pure Python — no Discord, no rules imports. The bot rolls initiative via
l5r_rules.combat.roll_initiative and hands the totals here.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Combatant:
    name: str
    initiative: int
    initiative_detail: str = ""       # e.g. "kept [7, 4] = 11"
    owner_id: str | None = None       # Discord user id for a player character; None for NPCs
    is_npc: bool = False


@dataclass
class Encounter:
    channel_id: int
    combatants: list[Combatant] = field(default_factory=list)
    round: int = 1
    turn_index: int = 0
    started: bool = False

    def _sort(self) -> None:
        # Stable sort by initiative descending keeps insertion order on ties.
        self.combatants.sort(key=lambda c: c.initiative, reverse=True)

    def add(self, combatant: Combatant) -> None:
        self.combatants.append(combatant)
        self._sort()

    def remove(self, name: str) -> bool:
        before = len(self.combatants)
        lowered = name.lower()
        # Preserve the current actor across a removal.
        current = self.current()
        self.combatants = [c for c in self.combatants if c.name.lower() != lowered]
        if len(self.combatants) == before:
            return False
        if current is not None and current.name.lower() != lowered:
            # Re-point turn_index at the same actor after the list shrank.
            self.turn_index = self.combatants.index(current)
        elif self.combatants:
            self.turn_index %= len(self.combatants)
        else:
            self.turn_index = 0
        return True

    def current(self) -> Combatant | None:
        if not self.combatants:
            return None
        return self.combatants[self.turn_index % len(self.combatants)]

    def advance(self) -> Combatant | None:
        """Advance to the next combatant; wraps and increments the round."""
        if not self.combatants:
            return None
        self.started = True
        self.turn_index += 1
        if self.turn_index >= len(self.combatants):
            self.turn_index = 0
            self.round += 1
        return self.current()
