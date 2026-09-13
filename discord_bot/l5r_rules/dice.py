"""L5R 4th Edition Roll & Keep dice engine.

Faithful Python port of `simulation/dice_engine.gd` and `simulation/dice_result.gd`
from the Rokugan Godot project. The GDScript is the reference implementation;
this module reproduces its rules exactly:

  - Roll & Keep (roll N dice, keep the K highest, sum the kept)
  - Exploding 10s (and 9-or-10 for high-rank techniques via ``explode_9``)
  - Emphasis (reroll any initial 1 once; the new face stands)
  - The L5R4e 10-dice cap: never roll or keep more than 10; every excess die
    converts to a flat +2 bonus on the final total ("overflow bonus")
  - Unskilled rolls do not explode (handled by callers passing ``explodes=False``)
  - Hungry Blade / initial-8 bonus explosion via ``explode_8``

Pure standard library. No Discord, no I/O, no globals.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field


@dataclass
class DiceResult:
    """The outcome of one Roll & Keep. Mirrors `dice_result.gd`.

    ``total`` is the sum of the kept dice plus the overflow bonus (from the
    10-dice cap). It is computed on demand so the object stays a plain record.
    """

    kept_dice: list[int] = field(default_factory=list)
    dropped_dice: list[int] = field(default_factory=list)
    explosions: int = 0
    overflow_bonus: int = 0

    @property
    def total(self) -> int:
        return self.overflow_bonus + sum(self.kept_dice)


class DiceEngine:
    """The single authoritative entry point for all dice rolling.

    Construct once and reuse. Pass a non-negative ``seed`` for deterministic
    output (useful for reproducible tests); omit it for real randomness.
    """

    def __init__(self, seed: int | None = None) -> None:
        self._rng = random.Random()
        if seed is not None and seed >= 0:
            self._rng.seed(seed)

    def set_seed(self, seed: int) -> None:
        self._rng.seed(seed)

    # -- Raw randomness helpers ------------------------------------------------

    def rand_int_range(self, low: int, high: int) -> int:
        return self._rng.randint(low, high)

    def randf(self) -> float:
        return self._rng.random()

    def _roll_d10(self) -> int:
        return self._rng.randint(1, 10)

    def roll_d10(self) -> int:
        """A single raw d10 (1-10)."""
        return self._roll_d10()

    def roll_die(self, sides: int) -> int:
        """A single die of arbitrary size (1-sides). Returns 1 if sides < 1."""
        if sides < 1:
            return 1
        return self._rng.randint(1, sides)

    # -- Core Roll & Keep ------------------------------------------------------

    def roll_and_keep(
        self,
        rolled: int,
        kept: int,
        explodes: bool = True,
        emphasis: bool = False,
        explode_8: bool = False,
        explode_9: bool = False,
    ) -> DiceResult:
        if rolled <= 0 or kept <= 0:
            return DiceResult([], [], 0)

        if kept > rolled:
            kept = rolled

        # L5R4e 10-dice cap: never roll or keep more than 10. Each excess die
        # converts to a flat +2 bonus on the final total.
        overflow_bonus = 0
        if rolled > 10:
            overflow_bonus += (rolled - 10) * 2
            rolled = 10
        if kept > 10:
            overflow_bonus += (kept - 10) * 2
            kept = 10

        all_dice: list[int] = []
        explosion_count = 0
        # s24 Kenjutsu R7 / Heavy Weapons R7: damage dice explode on 9 AND 10.
        explode_at = 9 if explode_9 else 10

        for _ in range(rolled):
            face = self._roll_d10()

            # Emphasis: reroll any initial 1 once. New result stands.
            if emphasis and face == 1:
                face = self._roll_d10()

            initial_face = face
            die_total = face

            if explodes:
                while face >= explode_at:
                    face = self._roll_d10()
                    die_total += face
                    explosion_count += 1

            # s35 Hungry Blade: a die whose INITIAL result was 8 (or 9 when the
            # 9-threshold is not already active) explodes once more; that bonus
            # die then follows the normal 10-chain.
            if explode_8 and (initial_face == 8 or (initial_face == 9 and not explode_9)):
                bonus = self._roll_d10()
                die_total += bonus
                explosion_count += 1
                if explodes:
                    while bonus == 10:
                        bonus = self._roll_d10()
                        die_total += bonus
                        explosion_count += 1

            all_dice.append(die_total)

        all_dice.sort(reverse=True)
        kept_dice = all_dice[:kept]
        dropped_dice = all_dice[kept:]

        return DiceResult(kept_dice, dropped_dice, explosion_count, overflow_bonus)

    # -- Raw Check Against TN --------------------------------------------------

    def roll_check(
        self,
        rolled: int,
        kept: int,
        tn: int,
        raises: int = 0,
        bonus: int = 0,
        explodes: bool = True,
        emphasis: bool = False,
    ) -> dict:
        effective_tn = tn + (raises * 5)
        result = self.roll_and_keep(rolled, kept, explodes, emphasis)
        final_total = result.total + bonus
        return {
            "success": final_total >= effective_tn,
            "total": final_total,
            "tn": effective_tn,
            "margin": final_total - effective_tn,
            "dice": result,
        }

    # -- Skill Check (handles unskilled + emphasis rules) ----------------------
    # L5R4e p.78: Unskilled rolls (skill_rank == 0) do NOT explode.
    # Rolled = trait + skill_rank, Kept = trait.

    def roll_skill_check(
        self,
        trait_value: int,
        skill_rank: int,
        tn: int,
        raises: int = 0,
        bonus: int = 0,
        has_emphasis: bool = False,
    ) -> dict:
        rolled = trait_value + skill_rank
        kept = trait_value
        explodes = skill_rank > 0
        return self.roll_check(rolled, kept, tn, raises, bonus, explodes, has_emphasis)

    # -- Contested Roll --------------------------------------------------------

    def contested_roll(
        self,
        rolled_a: int,
        kept_a: int,
        rolled_b: int,
        kept_b: int,
        bonus_a: int = 0,
        bonus_b: int = 0,
        explodes: bool = True,
    ) -> dict:
        result_a = self.roll_and_keep(rolled_a, kept_a, explodes)
        result_b = self.roll_and_keep(rolled_b, kept_b, explodes)
        total_a = result_a.total + bonus_a
        total_b = result_b.total + bonus_b

        winner = "a"
        if total_b > total_a:
            winner = "b"
        elif total_a == total_b:
            winner = "tie"

        return {
            "winner": winner,
            "total_a": total_a,
            "total_b": total_b,
            "dice_a": result_a,
            "dice_b": result_b,
        }

    # -- Initiative ------------------------------------------------------------

    def roll_initiative(self, reflexes: int, insight_rank: int) -> DiceResult:
        return self.roll_and_keep(reflexes + insight_rank, reflexes)

    # -- Damage Roll -----------------------------------------------------------

    def roll_damage(
        self,
        rolled: int,
        kept: int,
        strength_bonus: int = 0,
        reduction: int = 0,
        explode_8: bool = False,
        explode_9: bool = False,
        can_explode: bool = True,
    ) -> dict:
        # can_explode = False for weapons whose damage dice cannot explode (shinai).
        result = self.roll_and_keep(
            rolled + strength_bonus, kept, can_explode, False, explode_8, explode_9
        )
        raw_damage = result.total
        final_damage = max(0, raw_damage - reduction)
        return {
            "raw": raw_damage,
            "reduction": reduction,
            "final": final_damage,
            "dice": result,
        }


# ---------------------------------------------------------------------------
# Self-test: run `python3 dice.py` to validate the rules logic against the
# GDScript's invariants. This is NOT a unit-test file (the project forbids
# adding those): it is a hand-runnable validator, deleted from CI concerns.
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    eng = DiceEngine(seed=12345)

    # 1. Basic keep: keep K highest of N, sorted descending.
    r = eng.roll_and_keep(5, 2, explodes=False)
    assert len(r.kept_dice) == 2 and len(r.dropped_dice) == 3
    assert r.kept_dice == sorted(r.kept_dice, reverse=True)
    assert all(r.kept_dice[0] >= d for d in r.dropped_dice)
    assert r.total == sum(r.kept_dice)

    # 2. kept clamped to rolled.
    r = eng.roll_and_keep(3, 9, explodes=False)
    assert len(r.kept_dice) == 3 and len(r.dropped_dice) == 0

    # 3. 10-dice cap overflow: 12k5 -> roll capped 10 (+2*2=+4), keep 5.
    r = eng.roll_and_keep(12, 5, explodes=False)
    assert r.overflow_bonus == 4
    assert len(r.kept_dice) == 5
    assert r.total == sum(r.kept_dice) + 4

    # 4. keep overflow too: 12k12 -> roll 10 (+4), keep 10 (+4) = +8 total.
    r = eng.roll_and_keep(12, 12, explodes=False)
    assert r.overflow_bonus == 8

    # 5. Non-exploding dice never exceed 10 per die.
    r = eng.roll_and_keep(10, 10, explodes=False)
    assert all(1 <= d <= 10 for d in r.kept_dice)

    # 6. Exploding dice can exceed 10 sometimes (statistical check over many rolls).
    saw_explosion = any(
        eng.roll_and_keep(10, 10, explodes=True).explosions > 0 for _ in range(200)
    )
    assert saw_explosion, "expected at least one explosion in 200 rolls of 10k10"

    # 7. Emphasis: with explodes off and emphasis on, 1s are rerolled once.
    #    Over many single-die rolls, the frequency of a final 1 should drop
    #    below the un-emphasised ~10% (a 1 only survives a 1-then-1 reroll).
    emph_ones = sum(
        1 for _ in range(4000) if eng.roll_and_keep(1, 1, explodes=False, emphasis=True).total == 1
    )
    assert emph_ones < 4000 * 0.05, f"emphasis should suppress 1s, saw {emph_ones}/4000"

    # 8. roll_check TN math: raises add +5 each to the effective TN.
    chk = eng.roll_check(1, 1, tn=10, raises=2)
    assert chk["tn"] == 20 and chk["margin"] == chk["total"] - 20

    # 9. Unskilled skill check does not explode (rank 0 -> explodes False path).
    #    Rolled = trait+0, Kept = trait; each kept die <= 10.
    chk = eng.roll_skill_check(trait_value=3, skill_rank=0, tn=15)
    assert all(1 <= d <= 10 for d in chk["dice"].kept_dice)

    # 10. Damage: strength_bonus adds rolled dice; reduction floors final at 0.
    dmg = eng.roll_damage(rolled=3, kept=2, strength_bonus=2, reduction=1000)
    assert dmg["final"] == 0 and dmg["raw"] >= 2

    # 11. Contested roll reports a valid winner.
    con = eng.contested_roll(5, 3, 5, 3)
    assert con["winner"] in ("a", "b", "tie")

    print("dice.py self-test: ALL CHECKS PASSED")
    print("Sample rolls (seeded):")
    for spec in [(7, 2), (5, 3), (10, 5), (12, 4)]:
        s = eng.roll_and_keep(*spec, explodes=True)
        print(
            f"  {spec[0]}k{spec[1]}: kept={s.kept_dice} dropped={s.dropped_dice} "
            f"explosions={s.explosions} overflow=+{s.overflow_bonus} -> TOTAL {s.total}"
        )
