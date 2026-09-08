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

---

## N. `simulation/army_upkeep_system.gd` (s4.3/s11.7)

**Fixed (3 bugs, all decision-free):** Ronin Koku upkeep hardcoded a 3-month
multiplier regardless of actual season length (over/undercharging every
Autumn/Winter); Garrison Iron upkeep (0.10) was an invented cost the LOCKED
spec's own enumerated Garrison cost list explicitly excludes (Arms/Rice/Koku
only), now 0.00; a malformed company dict's Iron cost and stats-penalty
computations silently assumed two different unit types. See git log
(`da6be8a`).

### N1 — Deprivation recovery resets instantly instead of gradually — MEDIUM, real bug but currently dead code
GDD s11.7 (LOCKED): "the deprivation cascade does not reset instantly...
recovers one deprivation stage per tick... maluses recover at 1 deprivation
tier per tick while stationary and Arms-supplied." `process_deprivation_tick`
instead sets `arms_tick` straight to `1` the moment supply is restored, then
immediately calls `apply_arms_deprivation(c, 1)`, giving a company at Tick 4
(Attack/Defense −6/−6) **full recovery in one tick** instead of the LOCKED
gradual step-down. This also makes the file's own `apply_recovery_tick()` —
which correctly implements the gradual 1-tier-per-tick decrement — dead code
when composed with `process_deprivation_tick`, since the latter already
zeroes the malus instantly. *Why not fixed:* `process_deprivation_tick` (and
`apply_recovery_tick`) have **zero production callers** — confirmed by grep,
only exercised by `tests/test_army_upkeep_system.gd` — so this is currently
inert. Fixing the recovery logic would change what
`process_deprivation_tick` returns/mutates in ways the existing tests
(`tests/test_army_upkeep_system.gd:440,455`) assert against, and unlike the
Garrison-Iron test correction above (a single trivial numeric-literal fix),
this would require reworking the function's actual recovery algorithm and
therefore its test's assertions in a less mechanical, less obviously-safe
way. *Not fixed — flagged for whoever wires this dead code up, or an
explicit go-ahead to rework it now.*

---

## O. `simulation/companion_system.gd` (s57.46) — HOLD-scoped, none touched

The pure logic in `companion_system.gd` itself faithfully matches its LOCKED
GDD values (slots, command gating, morale formula, noise table, teamwork
bonus, avoidance gates, death-consequence shape) — no bugs found in the file
in isolation. All three findings are cross-file, inside
`simulation/ascii_map_combat_orchestrator.gd` — the ASCII-map / tile-combat
stack CLAUDE.md's own status explicitly marks **on the owner's PC-travel
HOLD (2026-06-06)**: "built and headless-verified, but NOT live-reachable...
validated by headless drivers, not a live session, until the HOLD lifts."
This is a *system-scope* pause the owner set deliberately, distinct from the
per-value ambiguity in every other deferred finding above — so unlike those,
I did not fix even the most mechanically-obvious one of these three, to
avoid unilaterally deciding which parts of a HOLD-status system are "safe"
to resume. All three are genuine bugs, none touched:

- **`CompanionSystem.death_consequences()` is never called from any
  production path** (only tests) — a companion's death on the ASCII map
  produces no world-state consequences (settlement `doshin_losses` never
  increments; no `FILL_VACANCY`/Tier-4 death topic for a named ally),
  contradicting s57.46.14 (LOCKED) and the s57.46a lock's own claim that this
  is implemented.
- **The only live call to `will_engage_samurai()` hardcodes
  `arrest_authorized=false, headman_present=false`** — the s57.46.11
  arrest-warrant exception (doshin fight a warranted samurai, reluctant −5)
  can never fire regardless of real `CrimeRecord.arrest_authorized` state; no
  plumbing exists to pass it in.
- **GUARD_EXIT's contested grapple-on-flee check is unimplemented** — a
  companion on GUARD_EXIT only moves to the tile and holds; nothing checks
  whether a fleeing enemy passes through a guarded exit tile at all. The
  orchestrator's own code groups this with its explicitly-deferred non-combat
  resolutions (IDENTIFY/SEARCH_AREA/INVESTIGATE).

*Not fixed — flagged together as within the existing HOLD, for whenever
that HOLD lifts or the owner asks for this specific slice ahead of it.*

---

## P. `simulation/insurgency_system.gd` (s11.11)

**Fixed:** Pirate Fleet's Strength cap enforced at the LOCKED 8 (was
unclamped, sharing the universal 10 with every other type; the resulting
Strength-10 "blockade" consequence was itself an invented value, now removed
as unreachable); PTL natural decay no longer silently cancels a Wall-breach
or lost-character PTL gain that has no other gain source. See git log
(`aa7a567`).

### P1 — Crisis-topic generation is entirely unwired from the seasonal insurgency pass — HIGH, real feature gap
`process_season()` computes a rich `events` array every season — auto-
detection, detection hints, spawns, spread, and all four types' Strength-10
consequences (Oni Manifestation, province seizure, army-scale threat,
permanent Nezumi colony) — but its **only production caller**
(`day_orchestrator._process_insurgencies`) reads only `new_insurgencies` and
`next_id` from the returned dict; nothing anywhere reads `result["events"]`
(grep-confirmed: no match for `"strength_10"`, `auto_detected`/
`detection_hint` events, or an `insurgency_results` consumer). Per GDD
s11.11 line 91, "Detection generates a crisis topic at the tier appropriate
to the insurgency type... public knowledge within the topic system" — but no
`TopicData` is ever created from an insurgency detection or Strength-10
event. This is a substantial, GDD-mandated player-visibility gap: insurgency
crises simply never surface as topics through this pass. *Why not attempted
as a quick fix:* wiring this correctly means mapping each event type to the
right topic tier/category/audience (using `get_crisis_tier()`, which is
itself currently uncalled — see P2) and threading `next_topic_id`/
`active_topics` into `_process_insurgencies`' call chain — a real feature
build, not a bug patch, and the tier-mapping specifics deserve their own
verification pass rather than a rushed addition at the end of an already
large file's audit. *Not fixed.*

### P2 — The proactive, player-initiated detection path is unreachable — MEDIUM, real feature gap
GDD s11.11 line 82: "A lord who suspects a problem may commit a magistrate
or shugenja... to investigate the province... an Investigation roll against
the insurgency's current Concealment value." `attempt_detection()` (this
deliberate detection action) and `get_crisis_tier()` both have **zero
production callers** (grep-confirmed: only `tests/test_insurgency_system.gd`
references either). Detection today only ever happens passively — hidden
growth's concealment reaching 0, or `PATROL_PROVINCE` attrition
(`day_orchestrator.gd:16432-16436`, the only other place `.detected = true`
is set) — a lord can never proactively commit an investigator to detect an
insurgency early. Fixing this needs an ActionID/executor wire-up (a
magistrate or shugenja investigation action targeting a province's
insurgency), which is new plumbing, not a correctness fix to existing
wiring. *Not fixed.*

### P3 — `resolve_suppression` duplicates the live `resolve_coordinated_suppression` path, unreachable — LOW, dead-code hygiene
`resolve_suppression` (single-actor suppression) has zero production callers
— `day_orchestrator._process_insurgency_suppression` always routes through
`resolve_coordinated_suppression` even for one participant. The maho-cult/
taint-manifestation "max −1 reduction without shugenja" rule and the
critical/success/partial branching are implemented twice; only the
coordinated copy is live. A future rule change updating only one copy would
silently diverge. *Not fixed* — this is a legitimate simplification/dedup
candidate, not a correctness bug, and (per the pattern established
throughout this audit) deleting or consolidating a function that has its own
existing tests risks a GUT-unverifiable test-file edit; flagged rather than
acted on.

---

## Q. `simulation/war_system.gd` (s53) — plus `simulation/maho_system.gd` clean

`maho_system.gd` was audited this round with **zero findings** — its core
mechanics (skill checks, wound-penalty signs, mutation modifiers, the sole
production call site) all check out against GDD and each other. Worth
recording given CLAUDE.md's hard constraints specifically single out maho.

`war_system.gd`: **Fixed** a genuine regression — an earlier "remove
invented content" audit pass (commit `d1b5311`) deleted the
`condemn_clan`/`authorize_war` `SCORE_SHIFTS` entries without checking that
`imperial_edict_system.gd` still had live callers keying off them, silently
zeroing the mechanical effect of two Imperial edict types since that commit.
Restored using 00_INDEX.md's own documented record as the (non-invented)
source value. See git log (`04aa717`).

### Q1 — Three GDD s53 mechanics have zero production callers — MEDIUM-HIGH, real feature-build gaps
All three need new detection/state-tracking this audit did not have grounds
to build (unlike the SCORE_SHIFTS regression, none has an existing call site
missing just one function call):
- **`add_ally()`** (the allied-clan-joins-war pathway) is called only from
  tests. `allied_clans_a`/`allied_clans_b` are *read* in
  `otomo_seiyaku_system.gd` and `day_orchestrator.gd`, and an
  `"allied_clan_joins"` `SCORE_SHIFTS` entry exists purely to reward a join
  event nothing ever triggers — an allied clan can never mechanically join a
  war in the running simulation.
- **GDD s53 "The Honor Stakes of Refusing"** (a fully-specified mechanic:
  −2.0/−3.0 Honor for a Family Daimyo/Clan Champion refusing a vassal's
  formal aid request, −15/−20/−5/−10 disposition to
  vassals/family/neighbors/court) has no trigger point *at all* — there is
  no existing "vassal formally requests aid from their superior" flow
  anywhere in the codebase to hook these already-correct consequence
  functions (`get_refusal_honor_cost`, `get_aid_request_honor_cost`,
  `get_refusal_disposition_effects`, `get_territory_fall_honor_cost`) into.
  This is distinct from the existing `REQUEST_ALLIED_AID` ActionID pipeline,
  which handles cross-clan ally requests, not vertical superior/vassal
  requests within the same hierarchy.
- **`check_auto_escalation()`/`escalate()`** are never called each season, so
  a war's `authority_level` never advances past whatever `declare_war()` set
  it to, even when the LOCKED auto-escalation triggers (requesting lord's
  score < 25, castle fallen, seasons_active > 3, enemy spread to another
  family, enemy allied with another clan) are met. Wiring this needs new
  per-war state this session doesn't have grounds to build (castle-fallen
  tracking against the war's territory, family-spread tracking, and #Q1's
  own alliance system for the "enemy allied" trigger).

*Not fixed — all three are real, GDD-mandated gaps, but each is a feature
build (new detection/state), not a bounded correctness fix.*

---

## R. `simulation/operational_hierarchy_system.gd` (s11.3.18)

**Fixed:** `will_escalate_refusal()`'s `shourido_virtue != NONE` gating bug
(a copy/paste inversion of the correct sibling pattern) that made the LOCKED
"Gi always escalates" rule permanently unreachable for any real character.
See git log (`b04fc61`).

### R1 — The entire operational-hierarchy pipeline is unwired from production — HIGH, large feature-build gap
`assign_operational_superior()` (and with it `get_starting_baseline()`'s
LOCKED s11.3.18i +5/+5/+10 first-meeting disposition floor,
`execute_feudal_override()`, `can_higher_superior_override()`,
`can_feudal_lord_override()`, `get_objective_priority()`,
`is_on_operational_assignment()`) is called only from
`tests/test_operational_hierarchy_system.gd` — `day_orchestrator.gd` calls
only `clear_subordinates_on_death()` from this file. Grep confirms
`operational_superior_id` is instead set by **direct field assignment at
~10 scattered sites** (`day_orchestrator.gd` ~19564/26645/29104,
`world_population_generator.gd`, `ronin_system.gd`), every one of them
bypassing `assign_operational_superior()` and therefore never applying the
starting-baseline floor, and never gaining access to the
objective-priority/escalation pipeline this file implements and tests. *Why
not fixed:* this isn't a single missing call site (like `death_consequences`
in companion_system.gd) — it's ~10 independent assignment sites, each
needing individual judgement on whether it represents a genuine "first
meeting" the LOCKED baseline should apply to, or an internal bookkeeping
re-assignment that shouldn't re-trigger it. That's a real audit-and-wire
project in its own right, not a bounded fix. *Not fixed.*

### R2 — Vindication disposition gain is pinned to the range floor, never scales — LOW-MEDIUM, invented-formula gap
`get_escalation_consequences()`'s `DAIMYO_BELIEVES_SUBORDINATE` outcome
always returns `VINDICATION_DISPOSITION_GAIN_MIN` (5);
`VINDICATION_DISPOSITION_GAIN_MAX` (10) is declared but never referenced
anywhere. GDD 11.3.18h: "the daimyo's disposition toward the subordinate
increases (+5 to +10 for loyalty in reporting wrongdoing)" — a range with no
stated scaling factor (severity, honor rank, or otherwise) anywhere in the
passage. *Decision:* what should determine where in the 5–10 range a given
vindication lands? *Not fixed.*

---

## S. `simulation/commitment_registry.gd` (s55.31)

**Fixed:** `register_proxy()`'s blanket SUPPORT_PLEDGE rejection (plus the
matching early-return in `day_orchestrator.gd`'s `_attempt_proxy_dispatch()`)
that made the LOCKED "proxy sent for SUPPORT_PLEDGE → BROKEN_WITH_NOTICE"
downgrade unreachable; `apply_forgiveness()`'s `int()` truncation and
recovery-vs-reported mismatch (now `roundi()`, matching the codebase's
existing float-rate-to-int-delta convention, with the reported total equal
to what was actually applied); `get_at_risk_penalty()`'s
`creditor_in_loyalty_chain` Callable, never supplied at its sole call site
(`npc_decision_engine.gd` `score_all()`), now wired from the existing
`chars_by_id` parameter and `character.lord_id` per s55.31.7's literal
"their lord or a character in their lord's direct service" definition. See
git log (`7fc6206`). Two other code-review findings on this file were
investigated and rejected as false positives (see that commit message):
the Bushido-modifier Seigyo/Kyoryoku skip in `get_at_risk_penalty()` exactly
reproduces both of s55.31.7's own worked examples; `link_crisis()`'s
blanket per-debtor linking matches s55.31.11.4's Yasuki Taka worked example
exactly (all four of his unrelated commitments, including a
travel-independent RESOURCE_PROMISE, are linked to one crisis as the
correct outcome).

### S1 — `get_forgiveness_rate()`'s Bushido-vs-Shourido axis priority is unspecified and currently backwards — MEDIUM, design-decision gap
s55.31.11.3 (LOCKED) states the retroactive-forgiveness rate "varies by the
receiving NPC's personality primary" and lists nine virtues as flat
alternatives — six from the Bushido axis (Jin 100%, Gi 75%, Chugi 75%/25%,
Rei 50%, Meiyo 50%, Yu 50%) and three from the Shourido axis (Dosatsu 50%,
Seigyo 25%, Kyoryoku 25%) — as if each character has exactly one
"personality primary" drawn from the combined set. But every real character
has **both** a non-`NONE` `bushido_virtue` and a non-`NONE` `shourido_virtue`
(confirmed via `world_generator.gd`'s mandatory assignment and this file's
own `operational_hierarchy_system.gd` precedent from finding R). The current
code checks `shourido_virtue != NONE` first and returns from
`FORGIVENESS_RATES_SHOURIDO` unconditionally whenever it's set — which for a
real character is always — making the six-entry
`FORGIVENESS_RATES_BUSHIDO` table (Jin/Gi/Chugi/Rei/Meiyo/Yu) permanently
dead code. This directly contradicts s55.31.11.4's own worked example: Isawa
Kaede is described as "Jin primary... Forgiveness rate: 100% (Jin full
compassion)" — but no `ShouridoVirtue` value maps to 1.0 in
`FORGIVENESS_RATES_SHOURIDO`, so the current Shourido-first order can never
actually produce 100% for her, regardless of what her (unstated) Shourido
virtue happens to be.

Simply reversing the check order (Bushido-first) does not fix this — it
just makes the *Shourido* table (Dosatsu/Seigyo/Kyoryoku) permanently dead
instead, since `bushido_virtue` is equally always non-`NONE`. Either order
leaves one of the two LOCKED-specified tables unreachable for any real
character. There is no existing field or documented rule establishing which
of a character's two virtue axes is their "personality primary" for this
specific purpose — that concept exists only in a different, unimplemented
GDD section's pseudocode (`s55.28`'s `personality_primary`/
`personality_secondary`, part of the still-PARTIALLY-DESIGNED political
decomposition tree), not as a field on `L5RCharacterData`.

*Decision needed:* which axis should `get_forgiveness_rate()` check first
(or does forgiveness rate need its own tie-break rule, e.g. Bushido always
wins, or a new "dominant virtue axis" concept)? Not fixed — inventing a
priority order here would be inventing an unspecified mechanic.

---

## T. `simulation/orphaned_objectives.gd` (s55.33)

**Fixed:** the MODIFY branch's empty-stub bug (real `new_objective` now
generated via `_select_objective_for_vassal()`, and `_resolve_orphaned_vassals`
converted to a pure planning pass matching its sibling
`_evaluate_vassal_objectives`); CONFIRM's missing `assigning_lord_id` update to
the new lord; `_find_next_authority()`'s missing "there is always someone"
escalation ladder (Family Daimyo → Clan Champion → highest-Status clan
survivor). See git log (`51bc70e`). `is_target_dependent()` being unreferenced
outside tests was investigated and is not a bug — `check_objective_validity()`
already defaults correctly to ACTIVE for anything not lord-dependent.

### T1 — Orphan status changes fire instantly at lord death, with no Knowledge Delay gate — MEDIUM-HIGH, feature-build gap
s55.33.1 (LOCKED, "Knowledge Delay — Section 20 Compliance") is explicit:
"Until the death topic enters the vassal's knowledge pool, their objective
remains ACTIVE... A vassal on campaign two provinces away may not learn for
1-2 seasons." The worked example (s55.33.8) has Akodo Kenji conquer an
entire province *during* the delay, precisely because his objective was
still ACTIVE while the death topic hadn't reached him yet. But
`process_lord_death()` (called from `day_orchestrator.gd`'s
`_process_lord_deaths`, same tick as the death event) runs
`check_objective_validity()` for every vassal of the dead lord immediately —
there is no check anywhere in the call chain for whether the death topic has
actually entered the vassal's `known_topics`/`topic_pool`. Every vassal,
regardless of distance or information channel, orphans instantly.

Fixing this properly requires more than a bounded edit: a "Lord X has died"
topic must exist and propagate through the normal topic system (the current
death-handling code builds a *succession* topic via `_build_succession_topic`,
not clearly the same "[Lord Name] has died" Tier 2 topic s55.33.1 describes),
and the engine needs new persistent state to track "vassal V's orphan check
for lord L's death is still pending topic delivery" across however many
future ticks it takes for that topic to reach them — `process_lord_death()`
is currently a one-shot call, not a per-tick recheck. That's a real
feature-build (new topic correlation + new pending-state tracking across
ticks), not a decision-free fix. *Not fixed.*

---

## U. `simulation/travel_system.gd` (s55.29)

**Fixed:** `change_destination()`'s missing not-traveling guard (matching
`cancel_travel()`'s existing pattern, closing a latent state-corruption path
not currently reachable through the AI decision pipeline but reachable by
any future direct caller); a stale header comment referencing a
`set_distance_provider()` function and `DISTANCES` symbol that don't exist.
See git log (`42d1a52`).

### U1 — `_distances` is a mutable `static var` global singleton — LOW-MEDIUM, architecture/refactor-scope gap
CLAUDE.md's GDScript Conventions are explicit: "Autoloads are the only
global singletons — do not use static variables as a substitute for proper
singleton registration." `_distances` (line 33) plus `set_distance()` /
`clear_distances()` is exactly that pattern — visible today in
`tests/test_travel_system.gd` and `tests/test_day_orchestrator.gd`, both of
which must call `clear_distances()` before/after nearly every test to avoid
cross-test leakage. The same leakage risk applies to any two simulation runs
sharing process memory. *Why not fixed:* migrating this to a proper Autoload
directly conflicts with this file's own directory-level constraint
(`simulation/` classes must NOT extend Node — `TravelSystem` is a plain
`class_name`), so the correct destination for this state (an existing
Autoload like `WorldState`, with `TravelSystem`'s functions taking the
distances dict as a parameter instead) plus the full caller-migration
footprint across the codebase is a real architectural decision, not a
bounded fix — and the file's own header already flags this whole subsystem
as a placeholder "when the map is built." *Not fixed.*

### U2 — `TERRAIN_COST`/`RIVER_CROSSING_COST`/`SPRING_RIVER_CROSSING_COST` are dead, duplicate their `army_movement_system.gd` counterparts — LOW, hygiene / future-wiring gap
These three constants (lines 13–24) are never read anywhere in
`travel_system.gd` — `get_travel_time()` only consults `_distances` or a
flat `_default_travel_time()` fallback. They exactly duplicate
`army_movement_system.gd`'s `BASE_TERRAIN_COST` / `RIVER_CROSSING_COST` /
`SPRING_RIVER_CROSSING_COST` (same values), which already has a fully-wired,
season/river-aware `get_terrain_cost()`. *Why not fixed:* wiring
`get_travel_time()` to actually use terrain costs would need real terrain/
river-adjacency data between settlements that isn't currently passed to this
file, and — like U1 — is gated on the same not-yet-built map system this
file's header already defers to. Deleting them risks discarding intentional
staging for that future work. Left as-is; whoever builds the map-system
terrain wiring should either consolidate onto `ArmyMovementSystem.get_terrain_cost()`
or delete the duplicate. Not a design decision, just flagged so it isn't
mistaken for load-bearing code. *Not fixed.*

---

## V. `simulation/war_termination.gd` (s53)

**Fixed:** `resolve_negotiate_surrender()`'s dead `"willingness"` key (a stale
name from before `evaluate_peace_acceptance()` was changed to return
`"factors"` instead — the field was always the literal default `0`,
consumed by nothing else in the codebase). See git log (`76ec020`).

### V1 — `conclude_peace_court()`'s willingness-modifier combination rule is unspecified — LOW, design-decision gap (currently unwired)
GDD s53 (LOCKED) is explicit: "Peace willingness is not determined by a
single threshold... there is no score at which peace is automatic." That's
exactly why a prior audit pass correctly removed this function's old
`boosted_willingness >= PEACE_ACCEPTANCE_THRESHOLD` comparison (an invented
magic number). What replaced it — `base_accepted or receiving_modifier > 0`
— has its own two problems: any positive `willingness_modifier`, however
small, unconditionally forces acceptance regardless of how badly the
qualitative `factors` evaluation opposed peace (itself still "a single
threshold," just moved to zero), and a negative modifier can never undo an
acceptance the base factors already favored. No LOCKED text specifies how
a peace court's accumulated `willingness_modifier` (from
`apply_willingness_modifier()`, itself not GDD-sourced beyond "a skilled
courtier... affect[s] what the losing side is willing to accept," s53 line
257) should combine with the qualitative accept/reject decision — reusing
s15.5's unrelated +50 topic-commitment threshold would be extrapolating
from a different system. *Currently no live-gameplay impact*:
`apply_willingness_modifier()` and `conclude_peace_court()` both have zero
production callers today (tests only). *Decision needed:* how should a
peace court's accumulated willingness_modifier weigh against the base
qualitative factors (a magnitude-sensitive comparison, a modifier-based
factor added to the increases/decreases count, something else)? Not
fixed.

---

## W. `simulation/crime_suppression_system.gd` (s11.3.19)

**Fixed:** `get_suppression_priority()`'s and `get_mission_type()`'s wildcard
match arms leaking a severity bonus / mission type onto insurgency types
outside this bridge's LOCKED scope (added a `NONE` sentinel to
`SuppressionMissionType`); `day_orchestrator.gd`'s `_classify_settlement_size()`
never checking `settlement_type`, so Otosan Uchi fell into `MAJOR_CITY` and
got the wrong (13 vs. the LOCKED 18) doshin baseline. See git log (`3937284`).

### W1 — The entire daimyo-override doshin recruitment pathway is unwired — LOW-MEDIUM, feature-build gap
`get_max_recruitable(available_doshin, daimyo_override: bool = false)`'s
`daimyo_override` parameter is never passed `true` by any production
caller (`day_orchestrator.gd`'s one call site always uses the default
`false`) — only a test exercises it. s11.3.19e.viii (LOCKED) describes a
real mechanic here: "if the daimyo explicitly authorizes, the full
available force can be committed... Stability drops -2 per season the
settlement has no doshin on regular duty" — and `STABILITY_PENALTY_NO_DOSHIN`
(the constant for that penalty) is declared but never read anywhere,
because nothing ever tracks "this settlement has had zero doshin on regular
duty for N seasons" in the first place. *Why not fixed:* there is no
decision point anywhere in the codebase for a daimyo to actually authorize
an override — no ActionID, no Strategic Review directive, no trigger of any
kind — so wiring this needs a real feature build (the authorization
decision point, plus new persistent per-settlement state to track duty-free
seasons for the stability penalty), not a bounded fix. *Not fixed.*

---

## X. `simulation/magistrate_allocation_system.gd` (s11.3.17)

**Fixed:** removed `EMERALD_MAGISTRATE_TOTAL: int = 6`, an invented value
with no LOCKED source ("a handful serve the entire Empire" is the only GDD
text), zero production callers, and only a self-referential test. See git
log (`fe5ba3c`).

### X1 — Most of this file's functions have no production caller — MEDIUM, sprawling wiring gap
Only `is_magistrate_available()` and `resolve_magistrate_conviction()` are
called from `day_orchestrator.gd`. `get_vacancy_effects()`,
`assign_replacement_magistrate()`, `get_conviction_cascade()`,
`get_magistrate_count()`, `get_yoriki_range()`, `get_investigation_capacity()`,
`get_case_queue_status()`, `is_emerald_jurisdiction()`,
`can_override_clan_magistrate()`, and `get_emerald_assignment_topic_tier()`
all have zero production callers. Concretely: s11.3.17e's "Appointment gap"
consequences (frozen tax rates, blocked construction, administrative
paralysis while a magistrate/governor position sits vacant) never apply,
and s11.3.17e's explicit replacement-appointment step ("the daimyo must
appoint a replacement magistrate... the replacement receives all suspended
case files") has no code path that actually assigns a new magistrate to the
suspended cases `resolve_magistrate_conviction()` already identifies —
`00_INDEX.md` lists this system's "conviction cascade on office vacancy" as
DONE, but only the case-suspension half runs. *Why not fixed:* this spans
several independent, undecided sub-features (when/how vacancy effects get
applied and cleared, what triggers an actual replacement appointment —
Strategic Review? A new directive?, how `get_magistrate_count`/
`get_yoriki_range` feed into world-gen or a later assignment pass, how
Emerald jurisdiction triggers get detected), not a single bounded fix. *Not
fixed.*

### X2 — `get_yoriki_range(MAJOR)`'s floor reuses the City tier's minimum with no LOCKED basis — LOW, currently unwired
GDD s11.3.17b gives Rural (1-2) and City (4-5) as explicit ranges, and only
an upper bound for Major jurisdictions ("up to a dozen") — no stated floor.
The code fills that gap with `YORIKI_MIN_CITY` (4) as MAJOR's minimum too, a
plausible but unauthorized value fill-in. *Currently no live-gameplay
impact* — `get_yoriki_range()` has zero production callers (see X1). *Not
fixed* — any replacement floor would be an equally invented number; left as
the reviewer found it since it's part of the same larger unwired area.

---

## Y. `simulation/succession_system.gd` (s22.5)

**Fixed:** `get_designation_urgency()`'s Blood Enemy off-by-one (`-60` vs.
the canonical `-61`); `should_reevaluate_heir()`'s `heir_dead` trigger now
wired at its call site; `compute_personality_weights()`'s truncation-order
bug (both virtue-axis multipliers now apply to the original base weight
before a single truncation, matching "Both apply simultaneously — they
stack"). See git log (`1d4113d`).

### Y1 — `contest_succession()` / `contesting_ids` is never invoked in production — MEDIUM, feature-build gap
`is_clean_succession()` correctly checks `succession.contesting_ids.size() >
0` to reject a clean succession per s22.5's Succession Dispute condition "a
named character with a claim (Priorities 1–5) formally contests the
succession (contesting costs 1 AP and generates a Succession Dispute topic
immediately)." But `contest_succession()` — the only function that appends
to `contesting_ids` — has zero production callers; only
`tests/test_succession_system.gd` calls it. In a live game,
`contesting_ids` is always empty, so a succession that a rival candidate
would want to formally contest instead always resolves as if uncontested.
*Why not fixed:* this needs real NPC decision logic (which candidates, with
what priority/personality, decide to spend 1 AP contesting a given
succession, and when) plus a new ActionID for it — not a bounded wiring
fix, and exactly the kind of decision CLAUDE.md's "Check existing channels
before wiring any ActionID" / "do not invent mechanics" rules require
owner sign-off on. *Not fixed.*

---

## Z. `simulation/hostage_system.gd` (s22.9 / s22.9a)

**Fixed:** nothing — all three findings below are genuine ambiguities or a
feature-build gap, not decision-free fixes. The constants
(`HARMED_HOSTAGE_HONOR_LOSS`, `ESCAPE_FAMILY_HONOR_LOSS`,
`ESCAPE_CRITICAL_FAMILY_HONOR_LOSS`, `YU_CAPTURE_LIKELIHOOD`,
`ISHI_CAPTURE_LIKELIHOOD`, `ESCAPE_TN_BY_SETTLEMENT`, `LEVERAGE_RANK*`) all
trace cleanly to s22.9a's LOCKED calibration table and were not touched.

### Z1 — `can_attempt_escape()`'s `committed_to_endure` gate is permanently dead — MEDIUM, feature-build gap
GDD s22.9 (LOCKED): "Will (Shourido) characters who committed to enduring
captivity will not attempt escape at all" — connecting to siege end
condition per-virtue behavior (s19.3, e.g. Ishi: "once they declare their
intention... will not reverse course"). No field anywhere in
`shared/`/`simulation/` tracks a character's declared siege end-condition
commitment, and the sole call site (`day_orchestrator.gd:17780`) never
passes `committed_to_endure`, so it is always `false` — an Ishi character
who declared "endure captivity" during the siege can still attempt escape
once captured. *Why not fixed:* needs new persistent state (the declared
commitment) plus the siege-end-condition decision logic that would set it
in the first place — a real feature build, not a bounded wiring fix. *Not
fixed.*

### Z2 — `is_action_blocked_for_hostage()`'s hardcoded ActionID blocklist isn't verbatim-sourced — LOW-MEDIUM, live-wired but unverified
s22.9 only locks two restriction categories: "confined to that location"
(movement) and "cannot work against their captor" (the `targets_captor`
parameter already handles this generically). `TRAVEL_TO` in the hardcoded
list clearly matches "confined to settlement," but `ORDER_BATTLE`,
`CONDUCT_RAID`, `LEVY_TROOPS`, and `DECLARE_WAR` are a plausible but
unquoted inference from "all bonuses and authority associated with their
position are on hold" — which sits in tension with the GDD's own "they can
still issue orders and communicate through the Game of Letters system."
This function IS live-wired (`action_executor.gd:157`), so the ambiguity
has real gameplay effect today. *Decision needed:* should a hostage be able
to issue military-command orders by letter (per "can still issue orders"),
or does "authority... on hold" block them specifically (the current
behavior)? Not confident enough either way to change it. *Not fixed.*

### Z3 — `get_capture_likelihood_modifier()`'s Bushido-vs-Shourido priority is unspecified — LOW-MEDIUM, live-wired axis-priority ambiguity
The same axis-priority pattern as `commitment_registry.gd`'s
`get_forgiveness_rate()` (Section S): a character can have `bushido_virtue
== YU` and `shourido_virtue == ISHI` simultaneously, and s22.9a only ever
specifies ONE virtue's modifier per axis (Yu on Bushido: 0.5, Ishi on
Shourido: 0.3) with no combined-case rule. The code checks Bushido first,
so a Yu+Ishi character gets 0.5 instead of the more capture-resistant 0.3 —
discarding the harder-to-capture Ishi trait. This function IS live-wired
(`day_orchestrator.gd:17916` and `24740`). *Decision needed:* which axis
wins, or should the lower (more resistant) of the two apply when both are
set? Not fixed — no LOCKED tie-break rule to implement.

---

## AA. `simulation/secret_system.gd` (s12.8)

**Fixed:** `resolve_search_person()` applying Glory loss to the wrong
character (searcher instead of target-on-find) and never applying Honor
loss to the searcher on an unauthorized non-find; the four covert
acquisition methods (Bribe/Eavesdrop/Intercept/Search) using a generic
Honor-rank-bracket table instead of their LOCKED flat per-method costs,
which sat declared-but-unused right above the bug. See git log (`b92ee1b`).

### AA1 — SEARCH_PERSON's disposition drop and "provocation flag" are unimplemented — MEDIUM, cross-cutting gap
GDD s12.8 "Search a Person": without magistrate authority and nothing
found, "the target gains a provocation flag — grounds for
ISSUE_DUEL_CHALLENGE. Disposition from the target toward the searcher
drops −10." With magistrate authority and nothing found, "the target may
resent it (disposition hit −3 to −5 toward the searcher)." Neither is
implemented in `resolve_search_person()`. *Why not fixed:* "provocation
flag" is one of CLAUDE.md's explicitly named cross-cutting constraints
("read their authoritative sections before writing any code that reads or
writes these fields") — and tracing it (s12.2's "Duel Provocation — LOCKED"
section) shows duel eligibility is actually driven by a disposition
threshold (Enemy/Blood Enemy) plus a "pretext" concept, not a simple
boolean flag stored on the character. Wiring this correctly requires
understanding how "pretext" is represented elsewhere in the already-built
duel-decision pipeline (`reactive_decisions.gd`, `npc_decision_engine.gd`'s
several `ISSUE_DUEL_CHALLENGE` sites) before adding a new SEARCH_PERSON
trigger to it — not a bounded, isolated fix. The GDD's exact disposition
magnitude for the with-authority case ("−3 to −5") is also a range with no
stated scaling rule. *Not fixed.*

---

## AB. `simulation/tattoo_system.gd` (s57.25)

**Fixed:** `compute_visibility()`'s missing martial-context alternate for
leg-location visibility (new `in_martial_context` parameter, default-safe
for all existing callers); `DAIDOJI_WRIST_LOCATIONS` deduplicated to derive
from `WRIST_FOREARM_LOCATIONS` instead of a hand-maintained copy; a
PROVISIONAL comment added (no behavior change) to `get_provenance_tn()`'s
unmarked Masterwork assumption. See git log (`d7f0423`).

### AB1 — `get_cultural_reluctance()`'s fallback silently invents a tier for unlisted (minor) clans — MEDIUM, live-wired gap
s57.25.3 (LOCKED) classifies exactly: No Reluctance — Dragon, Crab, Mantis
(plus Daidoji-wrist). Reluctant — Lion, Unicorn, Phoenix, Scorpion, all
non-Daidoji Crane. Very Reluctant — Otomo/Seppun/Miya. It says nothing
about any other clan. `world_bootstrap.gd` seeds six real, playable minor
clans this text never mentions — Fox, Wasp, Sparrow, Tortoise, Centipede,
Badger — and `get_cultural_reluctance()`'s final fallback silently returns
`RELUCTANT` for all of them, identical to a clan the GDD actually places in
that tier. This is live-wired: `check_consent()` (called from
`npc_decision_engine.gd`'s Phase 4c filter) gates APPLY_TATTOO consent on
this value today. *Decision needed:* what reluctance tier (if any) applies
to Fox/Wasp/Sparrow/Tortoise/Centipede/Badger? Any answer is an invented
value without an owner ruling — not fixed, since the function must keep
returning *something* for these clans to avoid breaking live consent
checks, and no tier is more justified than another from the LOCKED text
alone.

### AB2 — `get_provenance_tn()` has no LOCKED Masterwork value — LOW, unwired
s57.25.9 (LOCKED) gives an Investigation (Search)/Perception TN by artist
distinctiveness for exactly four quality tiers (Legendary 15, Exceptional
20, Fine 25, Normal 30) and never mentions Masterwork. The code reuses
Exceptional's TN (20), now marked PROVISIONAL per this file's own
convention for unlocked assumptions (it previously carried no such
marker, unlike every other assumption in this file, including
`tests/test_tattoo_system.gd:437`'s `test_provenance_tn_masterwork`, which
bakes in the same unlocked value as if it were GDD-specified).
*Currently no live-gameplay impact* — `get_provenance_tn()` has zero
production callers. *Decision needed:* should Masterwork sit between
Exceptional (20) and Legendary (15) at its own TN, or intentionally share
Exceptional's bracket? Not fixed — either answer invents a rule the GDD
doesn't state.
