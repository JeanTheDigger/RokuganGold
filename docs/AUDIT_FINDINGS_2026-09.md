# Silent-Gap Audit — Findings Requiring Owner Decision (2026-09-07)

Produced by the DONE-systems audit that applied the defect classes code-review
caught in the Kolat Conclave (over-broad triggers, scheduling-state-on-a-mortal,
missing `is_pc` guards, null-lookup bypasses, stale paired-state, and — new —
Dictionary-style access on typed `Resource` objects).

**Fixed already (structural correctness, no design decision):** champion-eval
`is_pc` guard, `_is_lord_tier` ronin misclassification, `strategic_review`
EdictData crash + dead logic + Ishi lock + mid-season id, the trial-by-combat
`LegalCaseEntry` desync, the bribe/extortion suppression race (same class,
`legal_status_system.gd`/`day_orchestrator.gd`), the `transition()` ic_day
sentinel hardening, and `investigation_system.gd`'s duplicate-lead generation +
alibi `evidence_change` mismatch. See git log
(`claude/project-overview-planning-bb3lmo`).

The items below are **real defects I did NOT auto-fix** because the correct
behavior depends on a game-design value or rule the GDD does not pin down, or
touches honor/disposition balance / the EffectApplicator dual-pattern where a
naive change risks double-application. Each needs an owner call before coding.

---

## A. `simulation/conviction_processor.gd`

### A1 — Acquittal drops the false-accusation disposition penalty (line 86 / 228–243) — MEDIUM
`_process_single_case` reports `lord_disposition_hit` (for treason,
`FALSE_ACCUSATION_DISPOSITION_HIT`), but `_apply_acquittal` only applies the
honor change — it never applies any disposition hit, and no orchestrator
consumer reads `lord_disposition_hit` (grep finds none). **The vassal
disposition penalty for a false accusation is silently dropped.**
*Decision:* should acquittal apply the reported disposition hit (and to whom —
lord→accused? clan-wide?)? If yes, I wire it; the target/scope is the design part.

### A2 — Acquittal honor loss applied for EVERY crime type, not just treason (line 241) — MEDIUM
`_apply_acquittal` unconditionally applies
`scale_honor_by_rank(TreasonSystem.FALSE_ACCUSATION_HONOR_LOSS, lord)`. For a
non-treason acquittal the hearing reports `lord_honor_change = 0.0`, yet the lord
is still docked the treason false-accusation honor loss. For treason the hearing
reports the **raw** constant while `_apply_acquittal` applies the **rank-scaled**
value. Either way the honor actually mutated diverges from the advertised result.
*Decision:* is the false-accusation honor loss meant to apply to all acquittals
or only treason? And is the authoritative magnitude the raw or the rank-scaled
constant? (Both are `TreasonSystem` values — a design call.)

### A3 — Trial-by-combat acquittal drops `victim_clan_disposition_hit` (line 321) — MEDIUM
On an `ACCUSED_WINS` trial, `DefenseHearingSystem.get_trial_by_combat_result`
returns `victim_clan_disposition_hit` (−30/−20/−10/−5 by victim status), nested
under `trial_result`. `_resolve_pending_trials` applies effects only on the LOSS
branch; no consumer reads `victim_clan_disposition_hit`. **The divine-judgment
disposition penalty against the victim's clan is silently dropped.**
*Decision:* confirm this penalty should apply and to which relationships, then I wire it.

### A4 — Authority-blocked case never escalates and re-processes every tick (line 89) — MEDIUM
When `TreasonSystem.can_convict` returns `must_escalate` (lord's status too low
vs. the accused), `_run_defense_hearing` returns `{blocked:true}` and
`_process_single_case` returns `outcome:"blocked"` **without changing
`record.legal_status`**. No orchestrator code consumes `blocked`, and nothing
escalates to a higher authority, so the still-ACCUSED record is re-selected and
re-runs the full hearing every day, emitting a no-op `blocked` forever.
*Decision:* the fix is escalation to a higher authority (s11.3.8 authority
chain) — which authority, and how selected? That routing rule is the design part.
(Behaviorally idempotent today — wasted work + a spammy result, not state
corruption — so it is not urgent, but it never converges.)

### A5 — Acquittal evidence-halving can desync record vs. case_entry (line 239) — LOW
When a `LegalCaseEntry` exists, the hearing computes `evidence_halved_to` from
`case_entry.evidence_total`, but `_apply_acquittal` halves
`record.evidence_total` and leaves `case_entry.evidence_total` untouched. If the
two differ, the reported halved value and the stored evidence disagree, and the
case_entry keeps full evidence. *Decision:* which is the source of truth for
evidence — the record or the case_entry — so the halving targets it consistently.

### A6 — Accused with no operational superior is silently skipped (line 39) — LOW/INFO
`lord_map.get(perpetrator_id, -1)` → `characters_by_id.get(-1)` is null →
`continue`, so a top-tier or masterless accused (Clan Champion, ronin) is never
processed by this pipeline and stalls at ACCUSED. *Decision:* are such characters
meant to be convictable here, and if so, who acts as the convicting authority?
(May be intentional — this pipeline may be vassal-only by design.)

---

## B. `simulation/strategic_review.gd`

### B1 — Falling-momentum penalty is unreachable (line ~1375) — MEDIUM
The per-topic momentum value is `+10 / 0 / −10`, but the aggregation
`if mom_val > momentum_bonus: momentum_bonus = mom_val` starts at 0, so a falling
topic (−10) never lowers the score below 0. A conclusion whose source topics are
all falling scores 0 for momentum instead of the documented −10, overweighting
declining crises. *Decision:* is the intended aggregation "max momentum across
source topics, floored at 0" (current behavior) or "a lone falling topic yields
−10" (the code comment)? This is a scoring-value/selection change, hence owner-gated.

### B2 — Call-court dedup compares season-of-year, not a monotonic index (line 203) — MEDIUM
`last_court_season` stores the season enum (0–3); the guard
`last_court_season == current_season` therefore over-suppresses across years — a
lord whose most recent court was WINTER y1 is blocked from a WINTER y2 court
(both equal `Season.WINTER`) unless they held some court in an intervening
season. A monotonic season index (`current_season_index`, already computed) would
fix it, but it is a coordinated 2–3 site change (writer at day_orchestrator
~22895 + this reader) in an area that already carries a prior careful patch, so
it warrants owner sign-off before altering court cadence.

### B3 — `strategic_evaluation_log` overwritten, not appended (line ~979) — INFO/BENIGN
`champion.strategic_evaluation_log = [log_entry]` replaces the log each season
rather than appending, capping debug history at one season. Benign if single-
season is intended; flagged only so the intent is on record.

---

## C. `simulation/investigation_system.gd`

### C1 — Repeat witness interviews may allow unbounded evidence stacking (line 426) — MEDIUM
`process_witness_interview` tracks `interviewed_witnesses`/`interviewed_suspects`
in the objective dict, but never checks that tracking before adding evidence —
every call adds `PROBE_WITNESS_EVIDENCE_MIN..MAX` (10–20) regardless of whether
the target was already interviewed. An NPC-driven investigation is naturally
protected because the decomposer's own target selection
(`investigation_decomposer.gd:_get_uninterviewed`) skips already-interviewed
targets, but a **PC-issued PROBE bypasses that filter** and can re-probe the
same witness repeatedly for repeat evidence, potentially forcing an
`ACCUSATION_THRESHOLD` crossing on stale information.
*Decision:* is this intentional (the GDD's "10-20 per successful interview,"
s11.3, could be read either way) or should evidence be capped per witness per
case? The governing section is explicitly flagged **"PARTIALLY DESIGNED"** in
its own filename, so this needs an owner ruling rather than an invented cap.
*Not fixed.*
