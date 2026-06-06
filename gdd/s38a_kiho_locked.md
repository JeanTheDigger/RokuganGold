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

- **A0 — MONK-ONLY (owner override, 2026-06-06).** Only MONK characters may learn
  kiho. This **overrides s38's provision that shugenja may learn kiho at 2× cost** —
  shugenja are excluded entirely. Combined with A10 (PCs may not be monks), PCs
  never learn kiho. s38's catalog and effect text remain the reference; this clause
  governs who may channel kiho.
- **A1 — Eligibility.** A monk meets a kiho's Mastery Level if
  `school_rank + relevant_ring ≥ mastery`. (Shugenja path removed per A0.)
- **A2 — Cost multiplier.** Brotherhood monk ×1.0; non-Brotherhood monk ×1.5.
  (Shugenja ×2 removed per A0.)
- **A3 — Base XP cost (LOCKED here).** `learn_cost = ceil(mastery × cost_multiplier)`.
  The base (mastery level) mirrors the KataSystem convention (`xp_cost = mastery`).
- **A4 — Knowledge cap (from s38).** Non-Brotherhood monks may know at most
  `school_rank` kiho. Brotherhood monks are uncapped.
- **A5 — Brotherhood identity.** `school_type == MONK` with `brotherhood_sect != ""`
  is a Brotherhood monk; `MONK` with `""` (e.g. Togashi Tattooed Order) is a
  non-Brotherhood monk.
- **A6 — Kuni reduction.** Inert under A0: the s38 Kuni −1 on Sever the Dark Lord's
  Touch applied to Kuni Shugenja / Witch-Hunters, who are shugenja and can no longer
  learn kiho. No monk is Kuni, so the reduction never fires.
- **A7 — Rebuke of the Heavens.** Monk-learnable (trivially satisfied under A0).
- **A8 — Activation (from s38).** Void Point = Free Action (no roll); Meditation/Void
  roll TN 15 = Complex, TN 30 = Simple; atemi delivery is Free. Active-slot
  constraint: one Internal + one Kharmic + one Mystical active at a time; Martial
  kiho are unlimited.
- **A9 — NPC auto-learning.** In the seasonal advancement pass, **monks** claim
  kiho XP before progress bars (same precedence as bushi claiming kata).
- **A10 — PCs may not be monks (s60.2).** Player characters cannot take a monk
  school. Enforced by `PcSystem.is_school_type_allowed_for_pc()` /
  `PcSystem.is_valid_pc()`. Because kiho is monk-only (A0), PCs never learn kiho.

## Deferred

Per-kiho combat effects (damage, conditions, Reduction, Initiative, atemi
delivery resolution) are stubbed via `get_effect_stub()` (`blocked_on:
"s40_effects"`). Wiring them into the s40 individual-combat / ASCII-map layer is
future work and will require per-effect review.
