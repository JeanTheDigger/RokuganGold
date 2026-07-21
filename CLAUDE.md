# CLAUDE.md — Rokugan Persistent World

## What This Project Is
An online persistent world set in Rokugan (Legend of the Five Rings, 4th Edition).
The simulation runs continuously server-side whether players are connected or not.
Players connect to a living world — they do not host or drive it.
All gameplay resolves through L5R 4th Edition rules (Roll and Keep dice system).

## Engine and Language
- Godot 4.6.2-stable
- GDScript (typed where possible — always annotate variables and return types)
- Networking is NOT in scope yet — do not scaffold multiplayer, RPC, or
  ENet/WebSocket systems until explicitly instructed

## The GDD Is the Authoritative Source
All game mechanics are in /gdd/ as markdown files.
The master index is at /gdd/00_INDEX.md — read it before asking what exists.

**All GDD sections are now open for implementation — there are no off-limits sections by policy.**
**Any game design decision (new mechanics, numeric values, behavioral rules not already specified in the GDD) requires explicit owner approval before implementation.** If the GDD doesn't specify a value or behavior, stop and ask — do not invent defaults.
Never extrapolate from one system to another (e.g. land combat rules to naval
combat, one school's technique to another's). If the GDD is silent, stop and ask.

**The GDD design files in /gdd/ are NOT read-only — they MAY be edited, but
every edit requires the owner's explicit, prior permission.** You may NEVER
edit, add, remove, or reword any design content in /gdd/ on your own initiative. Before touching a GDD design
file you MUST: (1) state exactly what you propose to change and why, (2) ask
for the owner's opinion, and (3) receive explicit, unambiguous approval. No
approval, no edit — silence is not approval, and a general "go ahead" on a
task does not extend to GDD design changes. The owner's opinion governs the
final wording. Updating the Code Implementation Status table in
/gdd/00_INDEX.md to reflect what code now exists does NOT require approval
(it records implementation status, not design); changing design intent,
mechanics, or numeric values anywhere in /gdd/ always does.

When implementing any system, read its LOCKED section directly from /gdd/.
Do not rely on summaries, cross-references, or inference. LOCKED sections win.

## Section Quick-Reference
The system → GDD-section lookup table is archived in
`docs/CLAUDE_CHANGELOG_ARCHIVE.md`. The authoritative master index is
`/gdd/00_INDEX.md` — read it before implementing or auditing a system, then read
the target's LOCKED section directly from `/gdd/` (LOCKED sections win over any
summary).

## Directory Structure
```
/gdd/                              — GDD markdown files (design source; edit ONLY with the
                                     owner's explicit prior approval — see "The GDD Is the
                                     Authoritative Source". 00_INDEX.md status table is the
                                     one exception: status updates need no approval)
/simulation/                       — Headless simulation logic: NPC engine, resource tick,
                                     world event resolution. NO Node inheritance here.
                                     Plain GDScript classes only (class_name, no extends Node).
/shared/                           — Data models: CharacterData, ProvinceData, etc.
                                     Use Resource subclasses for serialisable data.
/tests/                            — Pre-existing GUT tests. Do NOT add new test files
                                     here (see "Testing — DO NOT WRITE TEST CODE").
/scripts/managers/                 — Godot Autoloads / singletons (WorldState, SimScheduler).
                                     Registered in Project Settings. May extend Node.
/scripts/ui/                       — Player-facing Godot scenes (UI, ASCII map display, etc.).
                                     Nothing here should contain simulation logic.
/systems/npc_engine/data/tables/   — JSON scoring tables for the NPC decision engine
                                     (8 files: objective_alignment, personality_lean,
                                     personality_filter, action_skill_map, competence_table,
                                     disposition_tiers, urgency_rules, topic_position_alignment).
```

## GDScript Conventions
- Always use static typing: `var x: int`, `func foo(a: String) -> bool:`
- Use `class_name` on every file that defines a reusable type
- Simulation classes must NOT extend Node. They are plain objects.
  Correct:  `class_name ResourceTick` (no extends)
  Wrong:    `class_name ResourceTick extends Node`
- Use `const` for lookup tables and enum-equivalent dictionaries
- Prefer `enum` blocks for NeedType, ActionID, DispositionTier, WoundLevel, etc.
- Autoloads are the only global singletons — do not use static variables as
  a substitute for proper singleton registration
- Never put simulation logic inside a scene's _ready() or _process().
  Scenes call into /simulation/ — simulation does not call into scenes.

## Testing — DO NOT WRITE TEST CODE
**Do not write GUT tests or any test files. Write only the real production code
that will actually run.** When a task is done, deliver the implementation and
wiring — not a `test_*.gd` file. Validate by re-reading the actual code against
its GDD section and by parse-checking (`godot --headless --check-only -s <file>`),
not by authoring tests. Existing tests under `/tests/` may remain, but new work
does not add to them. (Design intent — keep pure simulation functions callable
without a scene tree and pass dependencies explicitly — still holds, because it
keeps the real code clean; it is no longer a directive to write tests.)

## Hard Constraints — Never Violate Without Asking
- PC death is permanent. No resurrection mechanic of any kind.
- Jade counters Jigoku only. No effect on other spirit realms.
- Any maho use raises PTL whether detected or not.
- The simulation does not pause for absent players.
- NPCs never use the ASCII map unless a PC is personally present.
  NPC-only resolution goes through the dice engine, not map generation.
  (NPC-vs-NPC fights resolve via summary roll, not tile-by-tile — GDD s40.x.)
- ASCII map movement is real-time when no combat is active in a zone; the
  zone switches to turn-based (Initiative/Round/Turn) only when combat is
  initiated, and returns to real-time when combat resolves. See GDD s40.x.
- CrimeRecord exists at world level. The system always knows who committed
  the crime. Investigation is players discovering what the system knows.
- met_characters, hostile tag, provocation flag, zone_event_log,
  operational_superior_id, spell_intent tag, and weapon material tag are
  cross-cutting constraints. Read their authoritative sections before writing
  any code that reads or writes these fields.
- One topic per piece of information. One topic per death. One topic per event.
- Dead characters always carry NEUTRAL subject_role valence.
- Spirit realms are not evil except Jigoku. Do not implement jade as a
  general-purpose spirit ward.
- **Check existing channels before wiring any ActionID.** Before adding an
  ActionID to a context action list, creating an executor intercept, or
  assigning an AP cost, verify that the action does not already have a
  dedicated system (Strategic Review directives, daily letter pass, reactive
  events, etc.). If a channel already handles it, the wiring belongs in that
  system — not the daily AP loop. Do not create duplicate execution paths.
- **Do not invent mechanics.** Every game mechanic, numeric value, enum value,
  edict type, action type, honor cost, disposition modifier, deadline, threshold,
  or behavioral rule must trace back to a specific LOCKED GDD section or to an
  explicit entry in this CLAUDE.md file. If the GDD does not specify a value or
  behavior, stop and ask — do not fill in plausible defaults, extrapolate from
  adjacent systems, or invent new enum values. Structural wiring (routing,
  function signatures, orchestrator plumbing) is allowed; game design is not.

## What's Been Built So Far

The detailed dated changelog ("Systems Added" + "Known Code Issues" entries) has been
**archived to `docs/CLAUDE_CHANGELOG_ARCHIVE.md`** to reduce per-turn token cost. It is
NOT auto-loaded. When you need history on a specific past system, `grep` the archive for
its name/section before assuming it doesn't exist.

Evergreen rules that lived in that section:
- **Before writing any new `/simulation/` or `/shared/` file, search both dirs** to confirm
  the system doesn't already exist. Per-section status (DONE / PARTIAL / NOT STARTED /
  REFERENCE) lives in the **Code Implementation Status** table at the bottom of
  `/gdd/00_INDEX.md`.
- **The entire ASCII-map / tile-combat / individual-combat (s40) / PC-facing spawn stack is
  built and headless-verified, but NOT live-reachable** — it is on the owner's PC-travel
  HOLD (2026-06-06). The world-map → mission entry point is deferred. Anything in that stack
  is validated by headless drivers, not a live session, until the HOLD lifts.
- **GUT is non-functional headless in this environment** and writing test code is against
  policy — validate new work by re-reading it against its GDD section, parse-checking
  (`godot --headless --check-only`), and hand-tracing reachability, or with a temporary
  headless SceneTree driver (deleted after).
- **Godot 4.6.2-stable is installed** (see SessionStart) — headless `--check-only` and
  `--import` parse-checks and `-s` driver runs work, but the full project's Node/autoload
  graph stalls a bare `-s` run; use a minimal autoload-free copy of `simulation/`+`shared/`
  for driver verification, matching the pattern used throughout the archive.

**Sections available for design (source material exists, owner authorization required before
coding — see "Decisions Needed", Section D):** s38 kiho, s40 individual combat (partial),
s54.7 Kolat, s57.42–s57.43 sailing, s57.46 allied NPC companion. DONE: s31–s37 spells,
s43 maho, s44 mutations, s45 advantages, and the s57 art/craft systems.

## Resolved Design Decisions

### 1. Topic Identity — RESOLVED: int IDs
**Decision:** Standardise on `int` as canonical topic identity everywhere.
- `topic_pool` migrates from `Array[String]` to `Array[int]`
- `TopicData.topic_id: int` remains unchanged (already correct)
- `ContextSnapshot.known_topics: Array[int]` remains unchanged
- A world-level auto-incrementing counter assigns each new topic its `topic_id`
- Slugs (e.g. `"crane_scandal_y3m7"`) become a `slug: String` metadata field
  on `TopicData` — used for logging and debugging, never matched on as identity
- Letter/conversation code migrates from string slug matching to int comparison
- **Rationale:** Consistent with NPC engine's existing int patterns, compact for
  network payload, matches Godot's idiomatic int-ID conventions, fast Dictionary
  lookups. No translation layer needed.

### 2. Timestamp Sentinel — RESOLVED: -1 for "never happened"
**Decision:** All "never happened" int timestamps use `-1` as sentinel.
- IC day 0 remains a valid game day (no epoch shift)
- Fields currently defaulting to `0` for "never" migrate to `-1`:
  `last_medicine_treatment_ic_day`, `void_refresh_blocked_until`, and any others
- Comparison convention: `if timestamp == -1: never happened`
- **Rationale:** `-1` is a universal sentinel convention and matches Godot's own
  patterns (e.g. `String.find()` returns `-1`). Avoids the hidden rule of "day 0
  isn't real" and requires no time system changes.

### 3. CommitmentData Redundant Fields — RESOLVED: keep source_action_id
**Decision:** Remove `created_by_action`. Keep `source_action_id` only.
- One fact ("which action created this commitment") = one field
- `source_action_id` follows the `_id` suffix convention used across the
  codebase (`commanded_unit_id`, `assigned_company_id`, `kolat_superior_id`)
- If a future distinction genuinely arises, it gets a new field with a clear
  name — not silent divergence of an originally-identical pair
- **Rationale:** Eliminates a redundancy that would otherwise become a debugging
  hazard if the two fields ever drifted apart unintentionally.

### 4. knowledge_pool Typing — RESOLVED: typed KnowledgeEntry Resource
**Decision:** Promote `knowledge_pool` from `Array[Dictionary]` to
`Array[KnowledgeEntry]` where `KnowledgeEntry` is a Resource subclass.
- Create `shared/knowledge_entry.gd` with `class_name KnowledgeEntry`
  extending Resource, typed fields for the ~6 known keys
- `L5RCharacterData.knowledge_pool` becomes `Array[KnowledgeEntry]`
- InformationSystem reads/writes update from `entry["key"]` to `entry.key`
- **Rationale:** Consistent with CommitmentData, TattooData, TopicData pattern.
  Catches key typos at parse time instead of silent nulls at runtime. Native
  Godot Resource serialization. Compact and predictable for network sync.
  Autocomplete and static analysis support in GDScript.

### 5. Maho Detection Pipeline — RESOLVED: three-channel topic generation
**Decision:** Maho use is never directly observable. Detection flows through three
independent channels; no single channel is reliable alone (per s57.47.7). All
three feed the same downstream machinery: a topic enters a magistrate's
`known_topics` → UPHOLD_LAW fires → INVESTIGATE_CRIME assigned.

**Channel 1 — PTL accumulation (province-level, passive, already LOCKED)**
Every maho cast raises PTL +1.0 (MahoSystem.PTL_PER_CAST). s11.11 (LOCKED)
already defines what happens next:
- PTL 3 → Province Taint Manifestation insurgency spawns; Tier 3 crisis topic
  generated automatically. Observable to any lord monitoring province reports.
- PTL 6 → Tier 2 crisis topic generated on first crossing.
- PTL 9 → Tier 1 crisis topic generated immediately.
These crisis topics are the primary indirect signal. Nobody knows maho caused
the PTL rise — they know the province is spiritually sick. Investigation traces
it back. No new topic generation code needed for Channel 1: the insurgency
system already produces the signal. PTL detection roll for shugenja:
Perception + Lore: Shadowlands vs TN (PTL × 5); Kuni and Asako +2k0 (s11.11).

**Channel 2 — Physical evidence at casting site (zone-level, active)**
Blood at the casting site follows the poison residue pattern from s57.48.8
exactly:
- At cast time: caster makes a Stealth / Agility roll (same formula as
  CONCEAL_ITEM). The result becomes the blood evidence `concealment_tn`.
- Evidence persists in `zone_event_log` for 1 IC season (same purge cycle
  as s57.48.8).
- Any character who runs EXAMINE_CRIME_SCENE in that zone rolls
  Investigation (Notice) / Perception against the `concealment_tn`.
- On success: generates a **Tier 3 topic** ("Evidence of blood magic in
  [zone]"). Topic does NOT name a perpetrator — the crime record exists
  at world level, but the investigator must narrow suspects via
  `zone_event_log` entries for who was present during the evidence window.
- No new ActionID or topic type needed; this uses existing EXAMINE_CRIME_SCENE
  and the world-known CrimeRecord.

**Channel 3 — Taint symptoms on the caster (personal, proximity-based)**
Caster's accumulating Taint is the most direct signal but requires physical
proximity. Detection is a Lore: Shadowlands check (NOT the Sense spell —
canonically Sense detects elemental kami, explicitly NOT kansen; owner
correction 2026-06-10). Two paths, both gated on proximity:
- **Passive (incidental) Lore: Shadowlands check** during any action that puts the detector in
  social proximity (INVESTIGATE_PROVINCE, court attendance, COMMUNE_WITH_SPIRITS
  near the suspect): Kuni Witch-Hunters and Asako Inquisitors automatically
  attempt this check when their known_topics include a Taint-related event in
  the same province. Other shugenja only attempt it if they hold Lore:
  Shadowlands 3+.
- Threshold triggering a topic: target's Taint Rank ≥ 2 AND no Wall service
  record on file (per s57.47.7: "has no innocent explanation").
- On detection success: generates a **Tier 3 topic** naming the specific
  character as a suspected maho user. This is a direct accusation topic —
  unlike Channel 1 and 2, it names a perpetrator.
- TN for the Lore: Shadowlands check = **(8 − Taint Rank) × 5** (owner-set
  2026-06-10): 30/25/20/15 for Rank 2–5. Both the passive (incidental) path and
  the active, deliberate examination (EXAMINE_FOR_TAINT) at the same TN are WIRED.

**Channel 4 — Direct witnesses (already handled)**
If `witnesses` is non-empty on the CrimeRecord, those characters carry direct
knowledge. They can testify through the existing court/investigation system.
No new code. The witness list in CrimeRecord IS the fourth channel.

**What is not yet implementable:**
- Channel 3 passive Lore: Shadowlands detection roll — WIRED (TN = (8 − Taint
  Rank) × 5, owner-set 2026-06-10). An active, deliberate Lore: Shadowlands
  examination (EXAMINE_FOR_TAINT, same TN) is now also WIRED — see "Maho
  Channel 3 active examination". NOTE: the Sense spell is NOT the detection
  tool — canonically Sense detects elemental kami, explicitly NOT kansen
  (owner correction 2026-06-10).
- Kuni/Asako/Kuroiban as Named Characters with UPHOLD_LAW standing objectives
  (blocked on s11.3.5 becoming LOCKED — currently PARTIALLY DESIGNED)
- `CAST_MAHO` as an NPC ActionID (no LOCKED specification exists for maho as
  a deliberate NPC action; do not implement until Section 43 or 55 specifies it)

**Rationale:** Channels 1 and 2 are wirable now — they use entirely existing
systems (insurgency topic generation, zone_event_log, EXAMINE_CRIME_SCENE).
Channel 3's passive proximity check is WIRED at TN (8 − Taint Rank) × 5.
This mirrors the GDD's intent: "multiple channels, none reliable alone."
The caster who casts once in a remote province and leaves quickly may never be
caught. The one who casts repeatedly in a populated area accumulates risk across
all four channels simultaneously.

### 6. Effect Application Pattern — RESOLVED: dual pattern with naming guard
**Decision:** Two coexisting patterns for applying character mutations:
- **Pattern A (Deferred):** System returns effect keys → EffectApplicator
  reads them and mutates characters centrally. Standard keys consumed:
  `honor_change`, `glory_change`, `infamy_gain`, `infamy_change`,
  `disposition_change`, `recipient_disposition_change`, `recipient_modifiers`,
  `consume_item_id`, `witness_disposition_loss` + `witnesses`.
  Used by: social actions, military, admin, intimidation, gifts.
- **Pattern B (Pre-applied):** System directly mutates characters before
  returning. Return dict contains metadata keys prefixed `subject_*` or
  suffixed `*_cost` (never matching Pattern A keys). Used by: SecretSystem
  (covert costs always apply regardless of success; exposure mutates the
  secret's subject, not the actor) and SeductionSystem (honor/infamy cost
  for attempting).
- **Safety rule:** Never use `honor_change`, `glory_change`, or `infamy_gain`
  as return dict keys from a system that pre-applies mutations. Use
  `subject_honor_loss`, `subject_glory_loss`, `subject_infamy_gain`,
  `honor_cost`, `glory_cost` to prevent EffectApplicator double-application.
- `FavorSystem.break_favor()` returns `disposition_floor` (per-tier minimum)
  which `_apply_favor_breach()` in DayOrchestrator enforces as a lower clamp.
- **Rationale:** Pre-application is correct for always-pay costs (covert action
  moral costs apply even on failure). Deferred application is correct for
  outcome-dependent effects (disposition gains only on success). The naming
  guard prevents accidental double-application across the two patterns.

## Decisions Needed and To-Be-Implemented Items

The full catalogue — PROVISIONAL numeric-value table (A), design gaps needing a
GDD spec/decision (B), sub-tile-map-data blockers (C), the per-feature design
table (D), unimplemented-due-to-missing-data items (E), and forward-wired no-op
entries (F) — is archived in `docs/CLAUDE_CHANGELOG_ARCHIVE.md`. Consult it
before building any to-be-implemented feature, or before treating a dormant
field/flag as a bug (many are intentional forward-wiring, Section F).

**Authorization policy (still active):** To-be-implemented features are not
off-limits by default, but any MAY be built ONLY with the owner's explicit, prior
authorization for that specific feature. Authorization is per-feature and
per-occasion — a general "go ahead" or approval on one feature does NOT extend to
another. Before starting one you MUST (1) state exactly what you propose to build
and the design choices it requires, (2) ask the owner, and (3) receive explicit,
unambiguous authorization. No authorization, no code — silence is not
authorization. Even once authorized you may not invent mechanics/values/rules
beyond what the owner authorizes (the "Do not invent mechanics" hard constraint
still applies). Items blocked purely on a missing dependency (Section C sub-tile
map data) cannot proceed until that dependency exists, regardless of authorization.

## What To Do When Uncertain
Stop. Read the relevant LOCKED section in /gdd/. If it does not answer the
question, say so explicitly — do not guess, do not fill gaps with plausible
logic, do not extrapolate from adjacent systems.

## Workflow — After Each Task
Whenever a task is complete (system implemented, wired, committed, pushed),
do the following in order before ending the turn:
1. **Validate twice** — re-read the actual code (not memory) and check it
   against the GDD section it implements. First pass: logic and GDD
   fidelity. Second pass: wiring completeness and edge cases (parse-check
   with `godot --headless --check-only`, trace each reachability/usage point
   by hand — do NOT write tests). State findings explicitly — what's correct,
   what's a known limitation, what would be a tuning concern.
2. **Suggest a list of next options** — present 3–4 distinct directions
   for what to build next, sized for clarity (small / medium / foundational
   / wiring follow-up). Use AskUserQuestion to let the user pick.
