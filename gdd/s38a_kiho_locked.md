# 38a. Kiho — Implementation Values (LOCKED)

Owner-approved 2026-06-06. Locks the implementation values and scope for the
Kiho system (s38 is the REFERENCE catalog and rules; this file locks the
decisions s38 leaves open). Code: `simulation/kiho_system.gd`.

## Scope

KihoSystem mirrors KataSystem: the full s38 catalog, eligibility, cost
multipliers, knowledge cap, activation rules, the active-slot constraint, NPC
selection, and a **stub effect registry**. Per-kiho COMBAT EFFECTS are deferred
(stubs only) — wiring ~73 distinct effects into the s40 layer is a separate pass,
exactly as KataSystem deferred kata effects.

## Locked values

- **A1 — Eligibility (from s38).** A monk meets a kiho's Mastery Level if
  `school_rank + relevant_ring ≥ mastery`. A shugenja uses `ring ≥ mastery`
  (ring only, no school rank).
- **A2 — Cost multiplier (from s38).** Brotherhood monk ×1.0; non-Brotherhood
  monk ×1.5; shugenja ×2.0.
- **A3 — Base XP cost (LOCKED here).** `learn_cost = ceil(mastery × cost_multiplier)`.
  The base (mastery level) mirrors the KataSystem convention (`xp_cost = mastery`);
  the multiplier is the s38 cost factor.
- **A4 — Knowledge cap (from s38).** Non-Brotherhood characters may know at most
  `school_rank` kiho. Brotherhood monks are uncapped.
- **A5 — Brotherhood identity.** `school_type == MONK` with `brotherhood_sect != ""`
  is a Brotherhood monk; `MONK` with `""` (e.g. Togashi Tattooed Order) is a
  non-Brotherhood monk; `SHUGENJA` is the shugenja path.
- **A6 — Kuni reduction.** Sever the Dark Lord's Touch mastery is 1 lower for Kuni
  Shugenja / Kuni Witch-Hunters (from s38), floor 1.
- **A7 — Monks-only.** Rebuke of the Heavens is learnable by monks only (from s38).
- **A8 — Activation (from s38).** Void Point = Free Action (no roll); Meditation/Void
  roll TN 15 = Complex, TN 30 = Simple; atemi delivery is Free. Active-slot
  constraint: one Internal + one Kharmic + one Mystical active at a time; Martial
  kiho are unlimited.
- **A9 — NPC auto-learning.** In the seasonal advancement pass, **monks** claim
  kiho XP before progress bars (same precedence as bushi claiming kata). Shugenja
  may learn kiho via KihoSystem but the NPC seasonal pass does not auto-divert
  their XP from spells.

## Deferred

Per-kiho combat effects (damage, conditions, Reduction, Initiative, atemi
delivery resolution) are stubbed via `get_effect_stub()` (`blocked_on:
"s40_effects"`). Wiring them into the s40 individual-combat / ASCII-map layer is
future work and will require per-effect review.
