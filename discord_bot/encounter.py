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


VALID_CONDITIONS: frozenset[str] = frozenset({
    "blinded", "dazed", "entangled", "fatigued",
    "grappled", "mounted", "prone", "stunned",
})


@dataclass
class Combatant:
    name: str
    initiative: int
    initiative_detail: str = ""       # e.g. "kept [7, 4] = 11"
    owner_id: str | None = None       # Discord user id for a player character; None for NPCs
    is_npc: bool = False
    # Keys of "once per Turn" / "once per Round" abilities already spent (L5R s30).
    # used_this_turn clears when this combatant's turn begins; used_this_round
    # clears at the top of each new Round. Used to enforce rate-limited kata.
    used_this_turn: set[str] = field(default_factory=set)
    used_this_round: set[str] = field(default_factory=set)
    # Combat conditions (GDD s40): transient per-encounter, DM-managed.
    conditions: set[str] = field(default_factory=set)
    # Guard maneuver (s40): name of the combatant being guarded, or empty.
    # Ward gets +10 Armor TN, guarder gets -5 Armor TN. Clears on guarder's turn.
    guarding: str = ""

    def consume_once(self, key: str, scope: str) -> bool:
        """Try to spend a once-per-`scope` ability ('turn' or 'round'). Returns
        True if it was available (and marks it spent), False if already used."""
        bucket = self.used_this_turn if scope == "turn" else self.used_this_round
        if key in bucket:
            return False
        bucket.add(key)
        return True


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

    def find(self, name: str) -> Combatant | None:
        """The combatant with this name (case-insensitive), or None."""
        lowered = name.lower()
        for c in self.combatants:
            if c.name.lower() == lowered:
                return c
        return None

    def advance(self) -> Combatant | None:
        """Advance to the next combatant; wraps and increments the round.

        Resets the incoming actor's once-per-Turn abilities, and every
        combatant's once-per-Round abilities at the top of a new Round."""
        if not self.combatants:
            return None
        self.started = True
        self.turn_index += 1
        if self.turn_index >= len(self.combatants):
            self.turn_index = 0
            self.round += 1
            for c in self.combatants:
                c.used_this_round.clear()
        cur = self.current()
        if cur is not None:
            cur.used_this_turn.clear()
            cur.guarding = ""
        return cur
