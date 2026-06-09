# Build Health — Compile & Test Status

_Last updated: 2026-06-09_

## TL;DR

**The full test suite is green.** Latest full run:
**13140 passing / 0 failing / 13226 tests (224 scripts); 86 Risky/Pending.**
Every test file loads (zero parse errors), the project boots clean (all autoloads
instantiate), and the suite completes without hanging. The remaining
Risky/Pending entries are conditional-assert tests and intentional `pending()`
markers (e.g. INNATE_ABILITY s45 gap, minor-clan roster count awaiting an owner
decision), not failures.

The runtime-failure cleanup that closed out the last 47 failures surfaced
several real implementation bugs (not just test drift), e.g.: geisha okiya clan
lookup using an int key against a string-keyed map (clan tiers never applied in
production); ring advancement never raising a ring when both underlying traits
were equal; Phoenix Stage-4 champion removal unreachable below Council quorum;
MissionPopulator tiering via get_class() (native base) instead of the GDScript
class_name; multiple induction/letter sites reading a nonexistent `lord_rank`
property on L5RCharacterData; HIRE_RONIN/induction passing ic_day as the
resolve_skill_check `raises` arg; PERMANENT_WOUND never reaching NICKED; combat
stance/dead-check ordering; and a same-tick succession removal that hid
auto-confirmed successions from callers.

This was not the case before: the GUT runner itself was broken on Godot 4.6, so
there was **no compile/test feedback at all**, and parse errors + API drift had
accumulated undetected across many "static-review-only" commits. The whole
codebase — including `day_orchestrator.gd`, the central integration file — did
not compile.

The remaining **131 failures are runtime assertion failures** (logic/wiring
issues now surfaced by actually executing the code, e.g. wound-penalty not
reducing roll totals), not compile/parse errors. Those are ordinary test-fixing
work.

## Runtime-failure cleanup (in progress)

Working the 131 down with a fast per-file loop
(`-gselect=test_X.gd`). Cleared so far (verified 0 failing each):
festival, world_state_saver, strategic_evaluation, individual_combat,
bound_escape, assassination, wind_down, animal_handling, opportunity_scanner,
and the ASCII-map templates (ravine, makeshift, occupied_village, ruined,
cave, hilltop, forest — mostly a GUT `assert_is` fix + size-category guards).

**Failure categories found (most are test bugs, some real impl bugs):**
- **GUT `assert_is(x, Class)`** rejects `class_name` scripts on Godot 4.6 →
  `assert_true(x is Class)`.
- **Probabilistic generation** — template tests assumed low strength → smallest
  variant; guarded by actual `size_category`.
- **Wound math** — tests used wound counts one level too low, or gave chars
  Earth 0 (→ DEAD, penalty 0). Impl is GDD-correct.
- **`var x: Array[String] = dict.get(...)`** silently fails on Godot 4.6
  (untyped→typed) — a *real impl bug* in strategic_review.
- **int assigned to a String field** (`target_clan_id`) threw → null — *real
  impl bug* in `_check_combined_pool`.
- **GDD-value mismatches** — e.g. painting completion tiers, JIN/CHUGI defend
  preference; fixed tests to match the LOCKED GDD.

**Remaining (~80, long tail):** painting (3), origami (2), theater (2),
npc_advancement (2), spell (3), marriage_dissolution (6 — Phoenix-governance
acceptance), geisha (probabilistic), shide, day_orchestrator, and others —
mostly 1–6 per file, each needing per-system investigation.

## How to run the suite

```bash
godot --headless --import            # build the import / class cache first
godot --headless -s addons/gut/gut_cmdln.gd -gexit   # run all tests
# single file:
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_x.gd -gexit
# parse-check one script (note: cold-boot single-script checks can show
# spurious cascade errors until the whole graph compiles — trust the GUT run):
godot --headless --check-only --script simulation/x.gd
```

## Root causes

1. **GUT runner broken on Godot 4.6.** GUT 9.3.0's `addons/gut/utils.gd`
   declared `static var Logger`, which shadows the native `Logger` class added
   in Godot 4.4+ — a hard parse error in 4.6 that took down the whole runner
   (cascading `get_logger`/`set_gut` Nil errors). **Fixed** by renaming the
   static var to `GutLogger`. (Consider updating GUT to ≥9.3.1 instead of
   carrying this patch.)

2. **No feedback → accumulated parse errors.** With GUT down, nothing ever
   compiled the project, so GDScript-4.6 errors and API/enum drift piled up.
   The first one in load order (`WeaponData`) broke the `world_state` and
   `simulation_scheduler` autoloads — i.e. the simulation could not even boot.

## Recurring GDScript-4.6 bug classes (for fixing the rest)

- **`trait` is now a reserved word** — `var trait` fails. Rename the field.
- **Multi-line `match` patterns are invalid** — all patterns of an arm must be
  on one line. `a,\n b:` → `a, b:`. (Verified empirically.)
- **`var _ = x`** — `_` is not a valid variable name in a `var` declaration.
  Use a real name (prefix `_` to suppress unused warnings) or remove the line.
- **Implicit (adjacent) string concatenation** — `"a"\n"b"` is invalid; use `+`.
- **API/enum drift** — calls/ened members that no longer exist or are in the
  wrong enum (e.g. `DispositionSystem.apply_disposition_change` doesn't exist;
  `TopicSystem` is `TopicMomentumSystem`; `TopicData.Category.SOCIAL` is not a
  category; `roll_and_keep()` arg 4 is a `bool`, not a `String`). These need
  per-site analysis — the file was written against an older API and never built.

## Status update (later pass)

The major compile cascades are now **cleared** — `combat_controller.gd`,
`individual_combat.gd`, `day_orchestrator.gd`, `strategic_review.gd`,
`sculpture_system.gd`, `movement_system.gd`, `garden_system.gd`,
`skill_resolver.gd`, `void_system.gd`, `advantage_system.gd` all compile.
The ~380 "could not resolve class" / "cannot infer type" cascade errors are gone.

Remaining is now **scattered**: ~49 "cannot find member" + assorted single-site
API/enum drift across individual systems and their test files, plus *runtime*
bugs surfacing now that code executes (e.g. nonexistent dice methods — fixed
`roll_d10`/`roll_1d10`). Two non-parse issues of note:
- **`test_world_bootstrap.gd` is extremely slow** — 62 tests, most calling
  `bootstrap_world()` which regenerates the *entire* world (142 provinces + full
  population + military + bloodspeaker + geisha + shide). 62 full-world builds
  make this file take minutes and stall the headless run before totals print.
  This is a test-design/perf issue (use `before_all` caching or a smaller
  fixture), not a parse bug.
- Last clean measured run before the combat/day_orchestrator fixes:
  **~7775 passing / ~207 failing**; those fixes cleared the largest cascades,
  so the passing count is higher now (a full clean total is blocked by the
  bootstrap-test slowness above).

## Fixed so far (committed)

- `addons/gut/utils.gd` — GUT `Logger` → `GutLogger` (runner works again).
- `shared/weapon_data.gd` + `individual_combat.gd` — `trait` → `attack_trait`.
- `strategic_review.gd`, `movement_system.gd` — multi-line match patterns.
- `day_orchestrator.gd`, `castle_siege_generator.gd`, `garden_system.gd` —
  `_ =` / `var _ =` discards.
- `ikebana_system.gd` — implicit string concatenation.
- `advantage_system.gd` — dead `SHADOWED_HEART` match arm removed;
  `TOUCH_OF_THE_VOID` dead functions pointed at the real `Disadvantage` enum.

## Remaining (prioritised by cascade size)

Drive this from the GUT run, not from grep (a structural grep can't tell a
multi-line match pattern from a valid multi-line function signature). Fix a
root file, re-run `--import` + GUT, watch the pass count climb.

1. **`combat_controller.gd`** — largest cascade (~212 "could not resolve class"
   + ~170 type-inference failures in dependent tests). Multi-line match
   patterns + `STANCE_ATTACK`-style member references.
2. **`day_orchestrator.gd`** — ~15 distinct API/enum-drift errors
   (`TopicSystem`→`TopicMomentumSystem`, `DispositionSystem` methods that don't
   exist, `TopicData.Category.SOCIAL`, `roll_and_keep` arg types, `.get()` on a
   bool, `KnowledgeSource` string assignments, function arg-count mismatches,
   `Enums.Disadvantage.FORBIDDEN_KNOWLEDGE` wrong enum, "Material" external
   member). The central orchestrator — fixing it unblocks the most behaviour.
3. **`individual_combat.gd` / `ascii_map_combat_orchestrator.gd`** — combat-layer
   member/API drift (`STANCE_ATTACK`, `alert_state` on null, duplicate function
   definitions — "same name as previously declared function").
4. **Enum issues** — `Enums.LordRank.NONE`, `Enums.ContextFlag` string
   assignments, `KnowledgeSource`. Decide enum membership before "fixing"
   references (some are design-adjacent — see below).

## Items needing an owner decision (do NOT guess)

- **`TOUCH_OF_THE_VOID`** — GDD has both a Phoenix Rank-5 *technique* (s29.5,
  beneficial) and a *Disadvantage* of the same name (s45/s29.12). The dead
  `advantage_system` functions conflate them. Decide intended modelling.
- **`FORBIDDEN_KNOWLEDGE`** — referenced as `Enums.Disadvantage` but defined in
  the `Advantage` enum. Confirm correct classification.
- **`TopicData.Category.SOCIAL`** — not a real category; pick the intended one
  (`POLITICAL` / `PERSONAL` / …) per the topic's meaning.

## Process lesson

The "DONE & tested" status recorded in `CLAUDE.md` for recent work reflects
**static review only** — most of it was never executed. Keep the GUT loop green
from now on: run `--import` + GUT before marking anything done.
