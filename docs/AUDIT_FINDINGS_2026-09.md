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
alibi `evidence_change` mismatch, and `treason_system.gd`'s
BushidoVirtue/ShouridoVirtue int collision in `should_name_co_conspirators` +
the `apply_refused_seppuku` rank-scaling call-site bug + `static var`→`const`
hardening. See git log (`claude/project-overview-planning-bb3lmo`).

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

---

## D. `simulation/treason_system.gd`

### D1 — `apply_refused_seppuku`'s consequences are computed but never applied anywhere — MEDIUM
The function returns a fully-specified payload (`new_legal_status: "ronin"`,
`honor_change`, `infamy_gain: 3.0`, `status_set_to: 0.0`, `exile: true`) using
constants already defined in this same file (`REFUSED_SEPPUKU_HONOR_LOSS`,
`REFUSED_SEPPUKU_INFAMY_GAIN`) — no new number would need inventing. But its
only caller (`conviction_processor.resolve_seppuku`) stores the result under
`treason_exile` in a day-report dict (`seppuku_results`) that nothing
downstream reads. **A convicted traitor who refuses seppuku never actually
becomes ronin, is never exiled, and keeps their prior status/honor/infamy
forever** — the s11.3.8d Refused Seppuku Path is a pure wiring gap.
*Decision needed is HOW to apply it, not what values to use:* `RoninSystem`
has a `make_ronin(character, cause: RoninCause)` entry point, but its
`RoninCause` enum (`LORD_DEATH_NO_HEIR`, `DISMISSAL`, `DISMISSAL_DISGRACE`,
`CLAN_DESTROYED`, `VOLUNTARY_DEPARTURE`) has no case for this, and
`make_ronin`'s own consequences (relative `-1.0` status decrement + a
cause-keyed glory loss) don't match this path's already-defined absolute
`status_set_to: 0.0` and honor/infamy figures — so wiring this either means
adding a new `RoninCause` (a new enum value, which needs owner sign-off per
CLAUDE.md) or writing a bespoke apply-path that bypasses `make_ronin` entirely
and applies the exact fields this function already returns. Also note: the
code's own comment cites "s11.3.8d" for this path, but the current GDD's
actual §11.3.8d is titled "Authority Chain" — worth confirming the section
number hasn't drifted since this was written. *Not fixed.*

### D2 — `get_preferred_response` has the identical Bushido/Shourido int collision, left unfixed — LOW (currently unreachable in production)
Same root cause as the `should_name_co_conspirators` fix applied this round
(`BushidoVirtue`/`ShouridoVirtue` share their underlying int values), but here
it lives in two module-level lookup dicts checked in sequence
(`BUSHIDO_RESPONSE_PREFERENCE` before `SHOURIDO_RESPONSE_PREFERENCE`) rather
than a `match`. **This function has zero production callers today** (grep
confirms it's only ever invoked from `tests/test_treason_system.gd`), so the
bug has no live effect. It was left unfixed — unlike the sibling function —
because `tests/test_treason_system.gd:271-276`
(`test_seigyo_lord_prefers_patience`) explicitly asserts the *buggy* result
(`TEST_LOYALTY`) as the expected value, with a comment documenting the
collision as known. Correcting the function would require updating that
test's expected value to `WAIT_FOR_PROOF`, and GUT is non-functional headless
in this environment, so I cannot execute the suite to verify a test edit is
even syntactically sound. *Decision:* is editing an existing (non-functional-
to-run) test file in scope for a correctness fix, or should this wait until
GUT is usable again / the function gains a real caller? *Not fixed.*

---

## E. `simulation/fugitive_extradition_system.gd` — MOST SIGNIFICANT FINDING THIS AUDIT (governance, not a line-bug)

### E1 — An entire file duplicates `simulation/extradition_system.gd` (both s11.3.16c/d), and the two copies have already drifted apart — HIGH, needs an explicit owner decision
Both files were added in the same commit (`459451d`) and both implement the
GDD's extradition-decision logic (`evaluate_extradition`,
`get_cooperation_consequences` / `apply_cooperation`, a refusal path, etc.)
independently. This is a direct violation of CLAUDE.md's own evergreen rule:
*"Before writing any new `/simulation/` or `/shared/` file, search both dirs
to confirm the system doesn't already exist."* Verified by grep (not just the
reviewer's claim):
- Of `FugitiveExtraditionSystem`'s 14 functions, **only 4 are called from
  production** (`day_orchestrator.gd`): `generates_sighting_topic`,
  `can_request_imperial_warrant`, `evaluate_imperial_warrant_compliance`,
  `get_standing_warrant_consequences`. The other 10 — including the file's
  main decision logic, `evaluate_extradition` and `select_response` — have
  **zero production callers**, confirmed transitively (e.g.
  `_get_personality_score` is only ever called from the also-dead
  `evaluate_extradition`).
- `day_orchestrator.gd` wires `ExtraditionSystem` (the sibling file) for the
  actual extradition decision flow, not this file's parallel copy.
- The two implementations have **already behaviorally diverged**:
  `FugitiveExtraditionSystem.select_response()` has no REI-virtue branch and
  uses a hard `fugitive_status < 3.0` cutoff for `DENY_KNOWLEDGE`, while
  `ExtraditionSystem._determine_response()` adds a REI/`score >= -10`
  `NEGOTIATE` branch and gates `DENY_KNOWLEDGE` on `score > -30` as well as
  status. Neither is obviously "the" correct one without the owner's original
  intent.
- Within the dead code, `evaluate_extradition()` looks up disposition via
  `harboring_lord.disposition_values.get(clan_name.hash(), 0)` — but
  `disposition_values` is keyed by `character_id: int` everywhere else in the
  codebase (day_orchestrator.gd, commitment_registry.gd, advantage_system.gd,
  ...), so this lookup can never hit and silently treats every relationship as
  neutral. Currently inert since the function is unreachable, but a landmine
  if anyone ever revives this file.

*Why I did not touch this file:* the correct fix isn't a line-level bug patch
— it's an architectural decision (delete the duplicate and repoint
`day_orchestrator.gd`'s 4 live calls to `ExtraditionSystem` if it has
equivalents; keep this file but strip the 10 dead functions; or reconcile the
two diverged decision-logic implementations into one). Any of these touches
`tests/test_fugitive_extradition_system.gd`, which currently exercises **all
14 functions** including the 10 dead ones — and GUT is non-functional
headless in this environment, so I cannot verify a structural edit to that
test doesn't break it. This needs the owner to say which file (or which
logic) is canonical before any code moves. *Not fixed — flagged only.*

### E2 — `get_concealment_tn()` unconditionally returns 0, ignoring both its arguments — INFO/BENIGN (likely intentional forward-wiring)
GDD s11.3.16a: "The higher the fugitive's Status and Glory, the harder
concealment becomes," but the function discards `fugitive_status`/
`fugitive_glory` and always returns 0; `STATUS_CONCEALMENT_BONUS_PER_RANK` is
also hardcoded to 0. Zero production callers (only the dead test references
it) — this reads as intentional forward-wiring (the CLAUDE.md Section F
pattern), not a live bug, so no numeric TN formula is invented here. Mentioned
only because it sits in the same file as E1 and could be mistaken for working
logic by a future reader. *Not fixed — no action needed unless this file is
revived per E1's decision.*

---

## F. `simulation/sentencing_system.gd`

**Fixed:** `PUNISHMENT_RANGES` was missing `CrimeType.VIOLATION_EMPERORS_PEACE`
entirely, silently falling back to `OTHER`'s lenient range instead of the
GDD-mandated fixed capital sentence — a high-leniency lord could sentence a
CAPITAL crime to a `VERBAL_REPRIMAND`. Fixed using the exact same
all-`EXECUTION_WITHOUT_SEPPUKU` fixed-sentence pattern the table already uses
for `MAHO`. See git log.

### F1 — Two GDD-specified leniency inputs are permanently defeated at the call site — MEDIUM
`SentencingSystem.select_punishment()`'s only production caller
(`conviction_processor.gd:113`) hardcodes `victim_clan_pushing=false` and never
passes `seigyo_usefulness` (defaults to `0`). Per GDD s11.3.15c, "victim's clan
actively pushing for harsh punishment: −15 additional" pressure can never fire
regardless of real diplomatic circumstances. Per s11.3.15a, a Seigyo-virtue
daimyo's `personality_base` is supposed to swing ±20 based on the convicted's
political usefulness — with the parameter always `0`, every Seigyo daimyo's
base is silently pinned to the DOSATSU/CHISHIKI "neutral" value for every
conviction. *Not fixed:* neither "is the victim's clan pushing for harsh
punishment" nor "the convicted's political usefulness" has any existing
detection/scoring logic anywhere else in the codebase to wire up — computing
either correctly means designing a new mechanic (what makes a clan "push"; how
usefulness is scored), which needs an owner call, not an invented formula.

---

## G. `simulation/extradition_system.gd`

**Fixed:** the `-1` champion-id sentinel could be written into
`disposition_values` unguarded (day_orchestrator.gd's COOPERATE/REFUSE
branches lacked the read-side's existing `>= 0` guard), and the backwards-named
`REFUSE_DISPOSITION_MIN/MAX` constants were renamed to `MILD/SEVERE` (pure
rename, no behavior change). See git log.

### G1 — Two pieces of pre-existing live logic have no GDD citation — HIGH policy flag, deliberately NOT removed
`_determine_response()` (line 157) contains two branches that CLAUDE.md's hard
constraint ("every mechanic... must trace back to a specific LOCKED GDD
section... do not invent mechanics") would forbid if introduced today, but
both are **pre-existing** — unmodified since the file's introducing commit
(`123dfae`), not written this session:
- A `BushidoVirtue.REI` → `NEGOTIATE` branch (gated on `score >= -10`). GDD
  s11.3.16d's only virtue-specific negotiate rule is "Seigyo lords strongly
  favor this option" — no REI clause exists anywhere in s11.3.16c/d.
- A `score > -30` gate on the `DENY_KNOWLEDGE` branch. The GDD conditions Deny
  Knowledge only on "the fugitive has low Status and is genuinely hard to
  find" — no severity-score cutoff is specified.
Both currently produce real, observable game behavior (routing some
below-threshold REI lords to Negotiate instead of Refuse; blocking some
low-status fugitives from Deny Knowledge based on crime severity) that traces
to no LOCKED section I can find. *Why I did not remove them:* CLAUDE.md's rule
constrains *me* from inventing new mechanics going forward — it is not
license for me to unilaterally strip existing, possibly owner-approved
behavior that simply lacks an in-code citation (removal is just as much an
uninstructed design decision as invention would be). *Decision needed:*
retroactively bless these as intended s11.3.16d behavior (and note it in the
GDD), or strip them to the letter of the LOCKED text. *Not fixed.*

---

## H. `simulation/bribery_system.gd`

**Fixed:** two fully-dead constants removed (`ACCEPTANCE_HONOR_LOSS`,
`CONDITIONAL_BUSHIDO` — zero references anywhere), and
`BRIBERY_EVAL_EVIDENCE_THRESHOLD` was made to read
`InvestigationSystem.BRIBERY_EVAL_TRIGGER` directly instead of carrying an
independent duplicate literal that could silently drift. See git log.

### H1 — The GDD's conditional bushido bribery exceptions are structurally unreachable — MEDIUM, needs a new call path
`can_attempt_bribe(character, is_protecting_other, lord_assigned,
has_intermediary)` correctly implements GDD s11.3.11g's four conditional
exceptions (JIN/YU permitted when "protecting someone else," REI when acting
"through an intermediary," CHUGI when "lord-assigned"). But
`attempt_bribe()` — the only function that calls it — has exactly one
production call site (`action_executor.gd`'s `_resolve_bribe_attempt`,
reached only from the `bribery_eval` self-preservation scenario, i.e. the
briber IS the accused bribing to bury their own case) and always passes
`(false, false, false)`. In that specific scenario `is_protecting_other` is
definitionally false — the briber isn't protecting someone else, they're
protecting themselves — so this isn't simply an unthreaded-parameter bug like
the sentencing_system.gd case; it's that **the GDD's exceptions describe
bribery contexts (a vassal bribing on a lord's orders, or to shield someone
else, or through a go-between) that the pipeline has no distinct call path
for yet.** A lord-assigned CHUGI vassal, or a JIN/YU character bribing to
protect a third party, can never access their GDD-specified exception no
matter the in-fiction circumstances.
*Decision:* is a second bribery-attempt call path worth building for these
scenarios (need to define how "lord-assigned"/"protecting someone else"/
"has an intermediary" would be detected — none of the three currently has
any signal anywhere in the codebase), or is bribery intentionally scoped to
self-preservation only for now? *Not fixed.*

---

## I. `simulation/investigation_decomposer.gd`

**Fixed:** `_get_npc_location`'s ctx-based lookup checked `is String` against a
value production always stores as `int` (day_orchestrator's sole writer), so
it was always dead — every witness/suspect/alibi target silently used
`crime_location` instead of their real settlement, and magistrates never
issued `TRAVEL_TO` to reach anyone. This was live, observable, and probably
the highest-impact fix of this audit round. Also removed a fully-dead
duplicate `BRIBERY_EVAL_THRESHOLD` constant. See git log (`5117834`).

### I1 — Two low-priority dead-code notes, not touched
- `_prioritize_witness` is only ever called from tests; the live path
  (`_select_best_next_action`) calls `_pick_present_first` instead. The dead
  function's own comment frames it as an incomplete stand-in for the real
  GDD s57.16.4 priority order (awareness → lowest honor → proximity), which
  could mislead a future maintainer into "completing" logic that has no
  runtime effect. Not touched — deleting a test-only function or overhauling
  witness prioritization is out of this audit's decision-free scope.
- Two unreachable `match`/`if` branches in `_action_from_candidate`
  ("reexamine_scene") and `_decompose_lead` ("location" lead type) — the
  former per an existing test comment ("Reexamination scoring removed
  (invented caps)"), the latter because the only production lead generator
  (`InvestigationSystem.generate_leads_from_probe`) never emits a `location`-
  type lead. Both compile and look wired but never fire. Flagged only, since
  removing them is a structural cleanup call, not a bug fix, and the
  "reexamine_scene" removal history suggests deliberate prior intent I
  shouldn't second-guess without confirmation.

**Also noted, not fixed:** `ACCUSATION_THRESHOLD = 40` is independently
duplicated (as a literal, not a shared reference) across FOUR files —
`investigation_decomposer.gd`, `investigation_system.gd`,
`legal_status_system.gd`, `treason_system.gd` — all currently in sync. Unlike
the smaller single-file duplications fixed this round, consolidating four
files' call sites onto one source of truth is a larger architectural change
than this audit should make unprompted. Currently harmless (all four agree),
but worth a deliberate consolidation pass if the value is ever retuned.

---

## J. `simulation/investigation_loop_system.gd`

**Fixed:** `FALSE_ALIBI_EVIDENCE_ON_FAIL` (dead, zero references anywhere,
duplicate of the real `InvestigationSystem.check_alibi()` path) removed. See
git log (`cba0570`).

### J1 — A failed KILL_WITNESS attempt uses an invented, GDD-unspecified evidence value — MEDIUM-HIGH, genuine "do not invent mechanics" gap
GDD s11.3.13c gives an explicit "+10 evidence" failure consequence for BRIBE
WITNESS, INTIMIDATE WITNESS, and a false alibi falling apart — all three are
correctly named constants in this file (`WITNESS_BRIBE_EVIDENCE_ON_FAIL`,
`WITNESS_INTIMIDATE_EVIDENCE_ON_FAIL`, both `10`). **But the GDD's own KILL
WITNESS entry has no "Failure:" line at all** — it only describes the success
consequence ("eliminates testimony permanently... creates a second murder
investigation"). `get_tampering_failure_result()` in this file correspondingly
has no `KILL_WITNESS` case (falls to the `_` default,
`{"witness_silenced": false}`, no evidence key). Yet
`day_orchestrator.gd:7177` still needs *some* value for a failed KILL_WITNESS
roll and falls back to a bare, un-cited `effects.get("evidence_on_fail", 10)`
— reusing the bribe/intimidate figure by coincidence, not GDD citation. A
failed murder attempt witnessed is intuitively a much stronger evidentiary
event than a failed bribe (the witness now has direct testimony of an
attempted killing, not just suspicion), so `10` is plausibly too low, but I
won't guess a replacement number. *Decision:* what evidence weight (or other
consequence — e.g. immediate escalation to a hostile-action/attempted-murder
crime record rather than a flat evidence bump) should a failed KILL_WITNESS
attempt carry? *Not fixed — the existing magic number stands untouched
pending a ruling, since removing it without a replacement would break the
call site.*

### J2 — `get_initial_legal_status(IMMEDIATE)` sets `UNDER_INVESTIGATION` before any magistrate is assigned — LOW-MEDIUM, ambiguous by design or gap
GDD s11.3.13h: immediate-discovery crimes get a magistrate assigned "within
1-3 IC days." This file declares `MAGISTRATE_ASSIGNMENT_MIN_DAYS`/`MAX_DAYS`
(1/3) but never applies them anywhere (grep confirms zero other references).
`get_initial_legal_status()` — which IS live (`day_orchestrator.gd:5730`) —
sets `legal_status = UNDER_INVESTIGATION` at crime-record creation, while
`investigating_magistrate_id` defaults to `-1` until a separate
allocation step (`magistrate_allocation_system.gd`, `investigation_system.gd`,
etc.) actually assigns one — which happens through the ordinary NPC decision
cadence, not a hard-coded delay gate. *Whether this is a bug is genuinely
ambiguous:* a case administratively reading "under investigation" before an
investigator has physically picked it up is a normal real-world pattern (and
may be exactly what "within 1-3 days" describes — the NATURAL assignment
cadence, not a hard requirement that `legal_status` itself stay gated). I
could not determine from the GDD text alone whether `legal_status` should be
withheld until `investigating_magistrate_id >= 0`, or whether the two
declared-but-unused constants are just descriptive documentation of an
expected (and already roughly-true) natural delay. *Decision:* should
`UNDER_INVESTIGATION` be gated on actual magistrate assignment, and if so,
should the unused MIN/MAX constants become an enforced window or stay
descriptive? *Not fixed.*

### J3 — `ZONE_LOG_PURGE_SEASONS` unused multiplier — INFO/BENIGN, zero live impact today
`is_zone_log_available()` has no production caller (grep: only its own test,
`tests/test_investigation_loop_system.gd`), and its declared
`ZONE_LOG_PURGE_SEASONS` constant is never multiplied into the retention-
window check (`days_since_crime <= DAYS_PER_SEASON` instead of `<=
DAYS_PER_SEASON * ZONE_LOG_PURGE_SEASONS`). Confirmed harmless today:
`ZONE_LOG_PURGE_SEASONS == 1`, so applying the missing multiplier would be a
numeric no-op even if fixed. Also notes a small duplicate of
`InvestigationSystem.DAYS_PER_SEASON` (both `90`, unlinked). Not touched —
zero production impact, and the only consumer is a test file I can't verify
via GUT if a fix changed its asserted values.

---

## K. `simulation/winter_court_system.gd` (s55.10)

**Fixed (4 bugs, all with unambiguous LOCKED-spec citations, no invented
values):** `compute_glory_rewards` awarded the host-family-daimyo Glory to the
Emperor instead of the real host; `run_invitation_pipeline` illegally skipped
Personal Imperial Invitations during every regent-hosted court, contradicting
the LOCKED "function normally" text; `order_agenda_for_host`'s clan→champion
map used last-write-wins instead of highest-status (mirrored the file's own
already-correct `_find_clan_champion` helper); `_select_host_with_weights` had
no tie-break at all despite the LOCKED "Family Prestige then Clan Recency"
rule, using scores already computed in scope. See git log (`691c54d`).

### K1 — School Type scoring always contributes 0.0 in two functions — MEDIUM, genuine invented-value gap
`_score_school_type_for_invitation` (Personal Invitations, Factor 4) and
`_score_delegate_candidate`'s `school_score` term (Champion Delegation,
"School Type weight 5") both always return/contribute `0.0` regardless of
`school_type` or archetype — every `match` arm is `return 0.0`. GDD s55.10
is explicit that this should matter: *"Courtier schools score highest,
shugenja moderate, bushi lowest. The Warlike archetype inverts this ranking —
bushi score highest, courtiers lowest."* (Factor 4) and *"School Type (weight
5): courtier schools score highest, shugenja moderate, bushi lowest"*
(delegate scoring). **But the LOCKED text gives only the ordinal ranking, never
the exact 0–10 magnitude per school** (unlike Prestige, explicitly "mapped to
0–10," or Crisis Relevance's explicit momentum formula) — and no equivalent
courtier>shugenja>bushi numeric scoring pattern exists anywhere else in the
codebase to copy (grep confirmed). Every other factor in both scoring systems
uses a self-evident 0–10 scale, so `courtier=10, shugenja=5, bushi=0` (and the
Warlike-inverted counterpart, plus wherever MONK falls — not mentioned in the
3-tier ranking at all) is the *obvious* reading, but it is still a numeric
choice the GDD does not make for me, so I did not invent it.
*Decision:* confirm (or set) the exact per-school scores for both functions —
courtier/shugenja/bushi/monk, standard and Warlike-inverted — and I'll wire
both in immediately; this is otherwise a one-line-per-branch change. *Not
fixed.*

---

## L. `simulation/geisha_system.gd` (s57.45a)

**Fixed (6 bugs, all decision-free):** Kolat eavesdrop roll silently dropped
Perception from its rolled dice entirely (used a literal `1`); eavesdrop
fired at best-case odds even with no okaasan to eavesdrop on, and
`okaasan_received` was reported true even then; a successful eavesdrop
recorded only a bare topic_id instead of the LOCKED-specified provenance
KnowledgeEntry; `handle_character_death` never cleared a dead
`kolat_agent_id`, permanently blocking okiya reassignment; Imperial Capital
world-gen appended 3 duplicate "okiya" infrastructure tags and ignored its
own `IMPERIAL_CAPITAL_OKIYA_COUNT` constant. See git log (`ac05098`).

### L1 — Imperial Capital's 3-tier okiya collapse into one settlement-level price — MEDIUM, needs a design decision, not a one-line fix
`_okiya_entries_for_settlement` correctly generates three distinct `OkiyaData`
entries for Imperial Capital (tiers 1/2/3, per GDD A33), but the koku-cost
lookup path (`wind_down_system.gd`'s `GEISHA_HOUSE` case, called from
`day_orchestrator.gd` with `settlement.okiya_tier`) reads a single
**settlement-level** `okiya_tier` field, which generation sets to the
highest tier (3, the priciest "Famous House"). **Every visit to an Imperial
Capital geisha house is billed at Tier 3, regardless of which of the three
actual okiya exists at cheaper tiers** — a budget-conscious samurai wanting
the cheap Tier-1 house per A33/A34 has no way to reach that price. This is
not a simple wiring bug: the wind-down pipeline (`apply_wind_down`) has **no
concept of choosing among multiple okiya at one settlement** at all — it
takes a single `okiya_tier: int`, not a specific `OkiyaData`. Fixing this
properly means either (a) redefining what the single settlement-level
`okiya_tier` should represent for billing (e.g. cheapest-available instead of
priciest — itself a policy choice, not obviously "more correct" than the
current one), or (b) threading actual okiya selection through the wind-down
call chain so a character can choose a specific tier — a real feature, not a
bug patch. *Decision:* which of the two directions (or another) is intended?
*Not fixed.*

---

## M. `simulation/sailing_system.gd` (s57.42/s57.42a)

Tightly matches its LOCKED numeric spec elsewhere (constants, formulas,
null-safety, cross-file call signatures all checked clean) — one finding.

### M1 — Jin/Compassion's passage lean is unconditional, unlike its two siblings — LOW-MEDIUM, invented threshold needed
GDD s57.42/s57.42a (LOCKED) specifies three captain-personality leans on
`evaluate_passage_request`: "Jin/Compassion +5 lean on accepting **struggling
travelers**; Seigyo/Control +3 lean when **proper koku is offered**;
Rei/Courtesy +2 lean on accepting **high-Status or polite** requests." The
code (`_personality_lean`) correctly gates Seigyo on `koku_offered > 0.0` and
Rei on `requester_status >= HIGH_STATUS_THRESHOLD or polite` — both reuse
already-available parameters — but **Jin's `LEAN_JIN` bonus applies
unconditionally**, with no check on the requester's means or need at all. A
high-Status requester offering full compensation to a Jin-virtue captain
still gets the "struggling traveler" bonus, which can flip a marginal
decision toward acceptance the LOCKED design didn't intend to be lenient
about. *Why not fixed:* the two existing parameters (`koku_offered`,
`requester_status`) could plausibly serve as a "struggling" proxy (e.g. low
or zero `koku_offered`), but the LOCKED text gives **no numeric threshold**
for what counts as "struggling" — unlike its siblings' exact criteria
("`koku_offered > 0.0`," "`>= HIGH_STATUS_THRESHOLD`"). Even the most minimal
reading (`koku_offered == 0.0`) is my interpretation, not a GDD-specified
number. *Decision:* what marks a requester as "struggling" — an offered-koku
threshold, a status threshold, or something else? *Not fixed.*
