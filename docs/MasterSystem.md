# MasterSystem

This document is the authoritative behavior reference for the **current test simulation layer**.

> Scope: `scripts/GalaxySimulationTest.gd`, `scripts/simulation/StrategicTestConfig.gd`, `scripts/simulation/StrategicTestLogic.gd`, and `scripts/data/canon_systems_test.gd`.

---

## 1) Current test-simulation scope

The test simulation currently runs a **strategic daily tick** focused on deterministic economy + shared-orbit space-control-lite behavior.

Active focus:
- faction global stockpiles (credits + upkeep/solvency),
- faction-global material stockpiles for all affordability (`faction.metal`, `faction.rare_metal`),
- planet strategic state (control/stability/garrison),
- deterministic planet income,
- deterministic control/stability updates,
- system-level SR-derived blockade maps,
- system-level orbital structures (Shipyard I + Defense Station I + Listening Post + Patrol HQ),
- system-level scouting freshness by faction,
- deterministic piracy pressure/state + pirate presence baseline,
- system-level asteroid belt income,
- deterministic daily logging.

---

## 2) Time model

- `1 day = 1 strategic tick`.
- `GalaxyViewportTest` advances days by calling `GalaxySimulationTest.advance_day()`.
- `advance_day()` calls `run_strategic_day()` exactly once.

---

## 3) Data model currently in code

### 3.1 Galaxy

- The simulation contains `systems: Array[Dictionary]` (test data dictionaries).

### 3.2 Star system (current runtime dictionary shape)

A system currently carries:
- `id: int`
- `system_name: String`
- `planets: Array[Dictionary]`
- `planet_ids: Array[int]` (derived during setup)
- `fleets: Array[Dictionary]` (physical fleet units in the system)
- `fleets_present: Dictionary[int, Array[Dictionary]]` (derived per day)
- `orbital_structures: Array[Dictionary]` (shipyards + defense stations)
- `space_queue: Array[Dictionary]` (system-level strategic construction queue)
- `has_belt: bool`
- `belt_class: String` (`none|metal|rich_metal|rare|rich_rare`)
- `platform_tier: int` (`0..3`)
- `belt_disabled_days: int`
- `belt_owner_faction_id: int`
- `belt: Dictionary` (compatibility mirror)
- `sr_by_faction: Dictionary[int, int]` (derived per day)
- `enemy_sr_by_faction: Dictionary[int, int]` (derived per day)
- `blockade_by_faction: Dictionary[int, bool]` (derived per day)
- `piracy_pressure: int` (`0..100`)
- `pirate_state: int` (`0=NONE, 1=ACTIVITY, 2=HAVEN`)
- `pirate_presence: Dictionary` (always present baseline object)
- `last_scout_day_by_faction: Dictionary[int, int]`
- `security_by_faction: Dictionary[int, int]`

`pirate_presence` currently stores:
- `system_id: int`
- `state: int`
- `threat_sr: int` (`0/10/35` in current baseline)
- `base_level: int` (`0/1/2`)
- `tags: Dictionary` with defaults `has_hidden_base=false`, `leader_id=null`, `loot_table_id="pirate_basic"`
- `active_fleets: Array` (currently always empty)
- `structures: Array` (currently always empty)

### 3.3 Planet

Each planet currently carries:
- `planet_id: int`
- `system_id: int` (set during setup)
- `owner_faction_id: int`
- `control: int` (`0..100`)
- `stability: int` (`0..100`)
- `base_credits_per_day: int`
- `base_metal_per_day: int`
- `base_rare_per_day: int`
- `required_garrison_gp: int`
- `current_garrison_gp: int`
- `garrison_recruit_progress: int` (deterministic recruitment accumulator; can exceed `100` while paused for insufficient credits; capped at `GARRISON_RECRUIT_PROGRESS_CAP`)
- `garrison_recruit_rate: int` (daily recruitment progress; default `25`)
- `garrison_recruit_paused_reason: String` (empty when active; `"insufficient_credits"` when wallet-gated)
- `garrison_recruit_last_paid_day: int` (debug visibility; default `-1`)
- `stored_metal: int` (deprecated legacy field; always `0`, not used for affordability)
- `stored_rare_metal: int` (deprecated legacy field; always `0`, not used for affordability)
- `bootstrap_seed_applied: bool` (deprecated legacy guard; retained for compatibility only)

Blockade is **derived** by helper call (`is_planet_blockaded`) using `(planet.system_id, planet.owner_faction_id)`.

### 3.4 Faction

Each faction tracks:
- `id: int`
- `name: String`
- `credits: int`
- `metal: int`
- `rare_metal: int`
- `owned_planet_ids: Array[int]`

### 3.5 Orbital structures

Orbital structures are system-level dictionaries with common fields:
- `type`
- `owner_faction_id`
- `system_id`
- `sr`
- `upkeep_credits_per_day`
- `enabled`
- `disabled_days`

Shipyard I stores queue/progress fields (`queue`, `current_progress_sp`, `ship_points_per_day`, etc.) and has `sr = 0`.
Defense Station I has `sr = 15`.
Listening Post has `sr = 5` and contributes automatic scouting freshness for owner faction.
Patrol HQ has `sr = 10` and contributes to piracy-security reduction rules.

### 3.6 Belt node

Runtime belt state is normalized at system scope and mirrored into `system.belt` for compatibility.

Primary runtime fields:
- `has_belt`
- `belt_class`
- `platform_tier` (`0..3`)
- `belt_disabled_days`
- `belt_owner_faction_id`

Compatibility mirror (`system.belt`) contains:
- `has_belt`
- `belt_class`
- `platform_tier`
- `belt_disabled_days`
- `disabled_days` (legacy mirror of `belt_disabled_days`)
- `owner_faction_id`

`belt_owner_faction_id` is synced to the owner of the primary planet (`planet_ids[0]`).

---

## 4) Blockade model (current behavior)

Blockade is computed per `(system, owner faction)` each day:

1. Compute `sr_by_faction` as fleet SR + orbital SR in that system. Only orbital structures that are not disabled and currently enabled contribute SR.
2. For each faction owning at least one planet in the system:
   - `friendly_sr = sr_by_faction[owner]`
   - `enemy_sr = max(sr_by_faction[other factions]) + pirate_presence.threat_sr`
   - `blockade_by_faction[owner] = enemy_sr > friendly_sr`

Planets do not own mutable blockade state in the runtime model.

---

## 5) Planet income rules (current)

For each planet each day:

- `control_mult = control / 100.0`
- `stability_mult = 0.5 + (stability / 200.0)`
- `blockade_mult = 0.40 if is_planet_blockaded(planet) else 1.00`

Then (with piracy multiplier applied before floor):
- `credits_gain = floor(base_credits_per_day * control_mult * stability_mult * blockade_mult * piracy_mult)`
- `metal_gain = floor(base_metal_per_day * control_mult * blockade_mult * piracy_mult)`
- `rare_gain = floor(base_rare_per_day * control_mult * blockade_mult * piracy_mult)`

Planet piracy multipliers by `system.pirate_state`:
- `NONE: 1.00`
- `ACTIVITY: 0.90`
- `HAVEN: 0.70`

Gains are added to faction global stockpiles.

Governor construction affordability currently uses faction-global stockpiles only:
- faction credits,
- faction metal,
- faction rare_metal.

All resources are faction-global; blockade/piracy modify income/production outcomes only and never gate storage accessibility by location.

---

## 6) Governance update order (current exact sequence)

Per planet, per day:

1. **Garrison -> Control**
   - define `effective_garrison_gp = current_garrison_gp + troop_gp` (troops are additive via `troop_gp`; `current_garrison_gp` is retained)
   - if `effective_garrison_gp >= required_garrison_gp`: `control += 1`
   - else: `control -= (required_garrison_gp - effective_garrison_gp)`
2. **Control -> Stability**
   - if `control >= 80`: `stability += 1`
   - if `control <= 30`: `stability -= 1`
3. **Stability -> Control**
   - if `stability >= 70`: `control += 1`
   - if `stability <= 40`: `control -= 1`
4. **Blockade -> Both**
   - if derived blockaded: `control -= 2` and `stability -= 2`
5. **Passive drift to 60**
   - if `stability > 60`: `stability -= 1`
   - if `stability < 60`: `stability += 1`
6. **Clamp** to `0..100`
22. **Revolt condition**
   - if `control == 0`:
     - owner becomes Rebels (`owner_faction_id = -1`)
     - `control = 50`
     - `stability = 40`

---

## 6.1) Faction bootstrap seed (current)

During setup (`_index_and_prepare_planets`), each faction receives a deterministic one-time bootstrap seed via `_ensure_faction_bootstrap_seed`:
- `faction.metal += 150`
- `faction.rare_metal += 20`
- `bootstrap_global_seed_applied = true`

Idempotence rule:
- If `bootstrap_global_seed_applied` is already true, seeding is skipped.

Compatibility behavior:
- Planet legacy fields `stored_metal` / `stored_rare_metal` are initialized to `0` and never used as spend wallets.

Logging:
- One setup log line per faction: `BOOTSTRAP seed applied: faction=<id> metal+150 rare_metal+20 wallet=faction_stockpile`.

This seed is faction-global and deterministic.

## 7) Orbital upkeep + production rules (current)

### 7.1 Shipyard I

Constants:
- Build cost: `3000 C / 250 M / 30 R`
- Upkeep: `30 C/day`
- `ship_points_per_day = 5`
- `build_slots = 1`
- `sr = 0`

Daily behavior:
1. Pay upkeep; if unpaid, no SP generation.
2. If owner is blockaded in that system and shipyard blocks on blockade, SP/day = 0.
3. Queue progresses if allowed.
4. On completion, costs are deducted exactly once and a fleet unit is spawned into persistent `system.fleets`.
   `fleets_present` is derived on the next SR/visibility derive pass and is not directly mutated by shipyard completion.

### 7.2 Defense Station I

Constants:
- Cost: `2000 C / 150 M / 20 R`
- Upkeep: `20 C/day`
- `sr = 15`

Station upkeep is paid by **station owner faction**.

### 7.3 Listening Post

Constants:
- Cost: `1600 C / 100 M / 20 R`
- Build time: `4 days`
- Upkeep: `20 C/day`
- `sr = 5`

Behavior:
- If active and owned by faction `F`, system is considered scouted that day for `F`.

### 7.4 Patrol HQ

Constants:
- Cost: `2200 C / 160 M / 30 R`
- Build time: `5 days`
- Upkeep: `25 C/day`
- `sr = 10`

Behavior:
- Contributes `+15` to controller security score for piracy-pressure reduction.

### 7.5 Controller security and piracy pressure (deterministic)

Controller (current implementation) is the owner of the primary planet (`planet_ids[0]`).

Controller security score (capped at 60):
- `+10` if any controller-owned planet has `effective_garrison_gp >= 1` (where `effective_garrison_gp = current_garrison_gp + troop_gp`)
- `+10` if any active controller Defense Station has `sr >= 15`
- `+15` if controller owns active Patrol HQ
- `+20` if controller owns active Listening Post
- Patrol security is computed from deterministic local patrol selection in-system only (controller-owned):
  - **Full patrol** (`sr >= 30`): `+10` each
  - **Light patrol** (`sr 15..29`): `+5` each
  - Selection order is deterministic: full fleets first (higher SR first, stable tie-break by `fleet_id`), then light fleets.
  - Selection is bounded by deterministic caps: `PATROL_MAX_FLEETS_ASSIGNED` (currently `2`), and optional `PATROL_ASSIGN_ONE_PER_SYSTEM` (currently `true`).
  - Patrol never issues movement orders; `PATROL_SELECT` is a local accounting log only.

Scouting age is tracked per faction:
- `scout_age = current_day - last_scout_day_by_faction.get(faction, -999999)`

Piracy pressure delta per day:
- `fog_bonus`: `0` (<=3), `2` (4..7), `4` (8..14), `6` (>=15)
- `value_bonus`: `+2` if `platform_tier >= 1`; `+1` if any planet `base_credits_per_day >= 220`; `+1` if `degree >= 4`
- `security_reduction = floor(security / 10)`
- `delta = max(0, fog_bonus + value_bonus - security_reduction)`
- `piracy_pressure = clamp(piracy_pressure + delta, 0, 100)`

State thresholds:
- `>= 80`: `HAVEN`
- `>= 40`: `ACTIVITY`
- else: `NONE`

`set_pirate_state(system, state)` syncs the baseline presence values:
- `NONE -> threat_sr=0, base_level=0, has_hidden_base=false`
- `ACTIVITY -> threat_sr=10, base_level=1, has_hidden_base=false`
- `HAVEN -> threat_sr=35, base_level=2, has_hidden_base=true`

Deterministic HAVEN clear (end of day):
- If faction with fleets present has `(fleet SR + active owned orbital SR) >= (pirate_threat_sr + 10)`, then:
  - `piracy_pressure = 30`
  - pirate state becomes `NONE` immediately.

---

## 8) Belt income + platform rules (current)

A system belt produces only when all conditions are true:
- `has_belt == true`
- `platform_tier > 0`
- `belt_disabled_days == 0`
- owner has holding presence:
  - at least one owner fleet in-system, **or**
  - an owner ACTIVE orbital structure (`enabled == true` and `disabled_days == 0`) with `sr >= 15`
- owner is not blockaded in that system

Base yields by belt class:
- `metal`: `M=12, R=0`
- `rich_metal`: `M=20, R=0`
- `rare`: `M=12, R=4`
- `rich_rare`: `M=16, R=8`

Platform multiplier:
- tier0 `0.0`
- tier1 `1.0`
- tier2 `1.5`
- tier3 `2.0`

Income is floored and applied to faction stockpiles (`metal`, `rare_metal`) only; belts do not grant credits.

Belt piracy multipliers by `system.pirate_state`:
- `NONE: 1.00`
- `ACTIVITY: 0.70`
- `HAVEN: 0.00`

Mining platform tier parameters:
- Platform I: `800 C / 60 M / 0 R`, `2 days`, upkeep `15 C/day`
- Platform II: `1200 C / 120 M / 10 R`, `3 days`, upkeep `25 C/day`
- Platform III: `2000 C / 200 M / 30 R`, `4 days`, upkeep `40 C/day`

Queue rules:
- queue entry type: `build_mining_platform`
- sequential upgrades enforced (`0->1->2->3`)
- queueing deducts resources immediately
- completion sets `platform_tier = target_tier`
- action is rejected when `has_belt == false`

---

## 9) Daily execution order (authoritative)

`run_strategic_day()` currently executes:

1. apply fleet arrivals for `current_day` (discrete relocation completes),
2. derive system SR,
3. create new **space engagements** (`ENGAGE_SPACE_START`) for hostile co-location (no damage),
4. create new **ground engagements** (`ENGAGE_GROUND_START`) for hostile co-location (no damage),
5. resolve engagements scheduled for today (`ENGAGE_SPACE_RESOLVE` / `ENGAGE_GROUND_RESOLVE`),
6. immediately re-derive system SR (post-resolution readiness/ship-loss updates),
7. proceed with scouting freshness (after deterministic patrol position sync/assignment),
8. update controller security + piracy pressure/state,
9. derive blockades (including pirate threat SR),
10. resolve planet income (with piracy multipliers),
11. resolve belt income (with piracy multipliers),
12. pay belt platform upkeep + orbital upkeep + fleet upkeep + troop upkeep (deterministic ordering),
13. apply deterministic garrison recruitment (Patch 7A/7B) (post-income, post-upkeep, pre-governance),
14. apply governance updates,
15. progress shipyard queues/spawns + completion retries (Phase 8),
16. progress system `space_queue` (mining platforms + orbital build orders, includes same-day orbital completions),
17. run AI invasion planner (sees same-day shipyard completions in `shipyard_active_in`),
18. run dispatcher priorities (including HAVEN SR massing),
19. run background governor (`run_galaxy_background_governor`) to score owned systems and enqueue legal orbit builds,
20. apply deterministic HAVEN clear check,
21. decrement disable counters,
22. emit logs for governor + systems + planets + factions.

### Patch 7A — Deterministic Garrison Recruitment (no costs)

Patch 7A introduces a deterministic garrison recovery loop with no credit/metal/rare costs and no patrol or blockade rule rewrites.

- Added runtime planet fields:
  - `garrison_recruit_progress` (deterministic accumulator; may exceed `100` while paused for insufficient credits; capped at `GARRISON_RECRUIT_PROGRESS_CAP`), default `0`
  - `garrison_recruit_rate` (daily progress), default `25`
- Timing: recruitment runs in `run_strategic_day()` after income resolution and upkeep, and before governance.
- Recruitment rate is halved when blockaded using deterministic integer math (`effective_rate = max(1, rate / 2)`).
- Recruitment accumulates progress and converts each full `100` progress into `+1` `current_garrison_gp`.
- `current_garrison_gp` is capped at `required_garrison_gp` (no over-garrison).
- Purpose: provide a deterministic recovery path so under-garrisoned planets can eventually re-enter the existing `+1 control/day` governance branch when blockade pressure is not permanent.

### Patch 7B — Garrison Credit Costs + Solvency-Safe Pausing

Patch 7B extends Patch 7A by adding deterministic faction-credit spending for each recruited GP while preserving existing patrol thresholds and governance/blockade rules.

- Each successful `+1` garrison GP now charges faction credits once: `GARRISON_GP_RECRUIT_COST_CREDITS` (currently `100`).
- Under blockade, recruit cost is multiplied by `1.5x` with integer floor via deterministic ratio constants (`3/2`).
- Recruitment progress still accumulates deterministically and is consumed only when a purchase succeeds (subtract `100` per successful GP).
- If faction credits are insufficient for the next purchase (`credits - cost < min_buffer`), recruitment pauses for that day with reason `insufficient_credits`.
- On pause, no credits are spent, no GP is added, and progress is retained and may exceed `100`, up to `GARRISON_RECRUIT_PROGRESS_CAP` (no loss of accumulated progress).
- Credits never go negative; Patch 7B does not introduce any solvency override for recruitment.

### Patch 7C — Operational Stabilization (Light Patrol + Early Security Counter-Loop)

Patch 7C adds deterministic light-patrol eligibility and patrol-derived security contribution while preserving blockade math, piracy thresholds, and recruitment loops.

- Patrol eligibility tiers:
  - full: `sr >= 30`
  - light: `sr 15..29`
- Deterministic patrol ordering and caps are applied before contribution.
- Controller security gains patrol contribution from assigned patrol fleets in-system:
  - `full_count * 10 + light_count * 5`
- Controller security remains capped at `60`.
- This directly affects piracy pressure via:
  - `security_reduction = floor(security / 10)`


---

## 10) Logging (current)

Per day logs currently include:
- per-faction governor net credits/day and system counts,
- top governor priorities by system with TS/PS/EV breakdown,
- successful governor enqueues with cost/upkeep/projected net,
- first failure reason when a high-priority governor action cannot enqueue,
- per-system SR/blockade tables,
- per-system piracy/scouting/security fields (`piracy_pressure`, `pirate_state`, `pirate_threat_sr`, controller, scout age, security),
- per-planet owner/control/stability/derived-blockade and yield gains,
- per-faction stockpiles + upkeep + shipyard status.

This is the current implementation baseline for the test simulation layer.


---

## 11) Acceptance checks helper (current)

`GalaxySimulationTest` includes `validate_model_a_acceptance_tests()` with explicit checks for:
- single-planet deterministic compatibility,
- multi-planet shared-orbit blockade asymmetry,
- shipyard blockade gating,
- belt presence/blockade gating,
- explicit RARE + Platform II belt output (`18 M`, `6 R`) checks,
- same-day blockade shutoff to `0` belt income,
- no-fleet/no-station shutoff to `0` belt income,
- mining platform queue sequential/gating behavior,
- Phase 4 deterministic checks:
  - unscouted/low-security value system rises to ACTIVITY then HAVEN,
  - Listening Post keeps scouting fresh and prevents fog-driven growth,
  - HAVEN belt multiplier shuts belt output to zero,
  - sufficient friendly SR clears HAVEN to `piracy_pressure=30`.
- Phase 5 deterministic checks:
  - non-rare belt growth queues Platform I then II (not III),
  - RARE belt protection enqueues Defense Station before platform upgrades,
  - HAVEN response enqueues Listening Post before Defense Station,
  - blockaded shipyard system enqueues Defense Station,
  - multiple systems can enqueue builds on same day until legal limits apply.

Additional helper available for UI/logging:
- `get_pirate_encounter(system_id)` returns state/threat/base-level snapshot and recommended clear SR.

Note: Patch 7A/7B/7C validation coverage exists in acceptance helpers and should be explicitly mapped/listed here as part of ongoing maintenance (TODO: keep the mapping up to date when helper names or assertions change).


## Governor logging throttling (current)

- Governor insufficient-resource skips are throttled to once per day per system with:
  `DAY <d> | GOVERNOR | system=<id> skip=insufficient metal/rare_metal (throttled daily)`.
- Other governor enqueue failures still log with full action + reason.


## 12) Launching the simulation harness

To launch the project locally and exercise this simulation layer from the Godot runtime:

- Open project root in Godot editor, or run from CLI:
  - `godot --path .`

For focused verification of strategic behavior, trigger the existing acceptance helper in `GalaxySimulationTest` (`validate_model_a_acceptance_tests()`) from your test/debug entrypoint.

## 13) Phase 8 — Unit Production

Phase 8 adds deterministic fleet unit production through Shipyard I with no movement/combat scope expansion.

### 13.1 Blueprint catalog

`SHIP_BLUEPRINTS` defines deterministic ship data snapshots used by queue entries:

- `corvette_mk1`
  - `sp_cost=10`, `credits_cost=600`, `metal_cost=40`, `rare_cost=5`
  - `sr=10`, `upkeep_credits_per_day=4`
- `frigate_mk1`
  - `sp_cost=20`, `credits_cost=1100`, `metal_cost=75`, `rare_cost=10`
  - `sr=20`, `upkeep_credits_per_day=7`

### 13.2 Shipyard queue schema (Shipyard I)

Shipyard entries use `type=build_ship` and snapshot costs/upkeep at enqueue time:

- `blueprint_id`
- `sp_cost`
- `owner_faction_id`
- `system_id`
- `costs={credits, metal, rare}`
- `upkeep_credits_per_day`
- `progress_sp`
- optional `status` and `started_day`

Capacity semantics:

- Shipyard I has one active build slot.
- Queue may hold additional jobs.
- Only the head entry progresses/completes.

### 13.3 Cost timing, completion, stall, retry

Mandatory cost policy:

- Deduct costs at completion only.
- Do not deduct at enqueue.

Completion flow:

- If stockpiles are sufficient at completion:
  - deduct exactly once,
  - spawn a fleet unit,
  - pop queue head,
  - reset shipyard progress.
- If stockpiles are insufficient:
  - keep job stalled at `progress_sp == sp_cost`,
  - do not deduct,
  - no spawn,
  - retry once per day.

Retry/logging behavior:

- Stalled completion is retried deterministically once/day before governor enqueue decisions.
- Stall reason is throttled to once/day per stalled job.

### 13.4 Spawned fleet unit shape and SR timing

On completion, spawned unit shape:

- `fleet_id` (monotonic deterministic counter)
- `owner_faction_id`
- `system_id`
- `blueprint_id`
- `sr`
- `upkeep_credits_per_day`
- `tags` (dictionary)

Persistence/derive behavior:

- Spawn appends to `system.fleets`.
- `fleets_present` is not directly mutated by completion.
- SR contribution appears on the next derive pass (`compute_system_sr`).

### 13.5 Governor ship trigger rules

Per owned system, deterministic threat model:

- `friendly_sr = sr_by_faction[owner]` (default `0`)
- `max_enemy_faction_sr = max(sr_by_faction[f != owner])` (or `0`)
- `threat_sr = pirate_presence.threat_sr + max_enemy_faction_sr`
- `sr_deficit = max(0, threat_sr - friendly_sr)`

Decision:

- `sr_deficit >= 25`: prefer `frigate_mk1`
- `sr_deficit >= 10`: `corvette_mk1`
- HAVEN override: if `friendly_sr < threat_sr + 10`, prioritize `frigate_mk1`

Enqueue gates:

- active shipyard exists for system owner,
- per faction/system/day cap: at most one enqueue,
- solvency guardrail:
  - `projected_net_credits_per_day_after_new_upkeep >= 0`
  - projected net is current projected net minus blueprint upkeep.

### 13.6 Deterministic day order insertion

Shipyard progression/completion retry occurs before governor in daily flow, so retry outcomes and slot availability are deterministic before build decisions.

### 13.7 Logging contract (Phase 8)

Phase 8 ship logs include deterministic tokens:

- enqueue: `SHIP_ENQUEUE`
- completion: `SHIP_COMPLETE`
- stall: `SHIP_STALL reason=insufficient_stockpile ... (throttled daily)`
- governor ship enqueue skip reason (throttled once/day/system): `SHIP_ENQUEUE_SKIP`

## 14) Fleet movement (discrete relocation) + galaxy map fleet visualization

### 14.1 Fleet movement state model (no in-between fleets)

Hard rule:

- Fleets are always located in a valid system (`system_id` is always a concrete system id).
- There is no gameplay/UI state where a fleet is represented on a lane edge or `in_transit` with no system location.

Required movement fields:

- `status`: `"idle" | "moving" | "on_task"`
- `target_system_id`: destination system id while moving, else `-1`
- `arrival_day`: deterministic arrival day for current move, else `-1`
- `task`: dictionary payload for assignment metadata
- `last_order_day`: day index of last accepted order

Movement timing:

- On day `d`, ordering a move from system `A` to `B` computes BFS hop distance.
- `travel_days = hop_distance * FLEET_MOVE_TRAVEL_DAYS_PER_HOP`
- `arrival_day = d + travel_days`
- Fleet remains physically in origin system `A` and contributes SR there until arrival processing.
- On `day == arrival_day`, relocation is atomic:
  - `fleet.system_id = target_system_id`
  - `status = "on_task"` if task exists, else `"idle"`
  - `target_system_id = -1`

Deterministic day order:

1. Apply fleet arrivals for `current_day`.
2. Derive SR from current fleets/structures.
3. Create space engagements for hostile co-presence (`ENGAGE_SPACE_START`).
4. Create ground engagements for hostile co-presence (`ENGAGE_GROUND_START`).
5. Resolve engagements scheduled for today (`ENGAGE_*_RESOLVE`).
6. Re-derive SR immediately after encounter readiness/ship-loss updates.
7. Continue scouting/security/piracy, blockade derivation, and remaining day phases.

Logging contract additions:

- order: `DAY d | FLEET_ORDER | source=FACTION_PLANNER faction=FID fleet=K sr=SR kind=KIND from=SYS_A to=SYS_B hops=H travel_days=T arrival_day=AD reason=...`
- blocked order: `DAY d | ERROR | FLEET_ORDER_BLOCKED | source=SOURCE faction=FID fleet=K from=SYS_A to=SYS_B reason=...`
- arrival: `DAY d | FLEET_ARRIVE | faction=FID fleet=K to=SYS_B kind=KIND`
- HAVEN response dispatch: `DAY d | HAVEN_MASS | faction=FID target_system=SID threshold=T friendly=F need=N chosen=[fleet_ids...] reason=mass_for_clear`

### 14.2 Galaxy viewpoint fleet symbols (text glyph markers)

Fleet markers are rendered on system nodes (never on lanes):

- **▲ yellow triangle** = non-moving fleet present in the system (`idle` / `on_task`).
- **▲ cyan triangle** = moving fleet that is still physically present in this origin system until arrival day.
- **+N text** = additional fleets not shown when marker cap (`5`) is exceeded.

Selection panel text behavior:

- Shows total fleets for selected system.
- If moving fleets exist, shows `moving (ETA day X)` using the minimum arrival day in that system.


### 14.3 Test galaxy data

- `TEST_GALAXY_PREPATCH7` now includes at least three Sith-owned systems (faction `2`) connected into the preset neighbor graph.
- `TEST_GALAXY_PREPATCH7` starts Republic and Sith with parity starting fleets (count + SR parity), placed in their owned systems.
- `TEST_GALAXY_PREPATCH7` starts Republic with higher credits than Sith to avoid immediate upkeep strangulation.
- Current v0 hostility rule is deterministic: any different faction ids are hostile, and Rebels (`-1`) are hostile to all non-Rebel factions.
- Existing fleet map markers remain triangular (`▲`) for both idle/on-task and moving-origin fleet presence.


---

## Phase 10 — Fleet Formations + Readiness

### Fleet roster + readiness shape

Each fleet supports a roster-based structure:
- `ships: Array[Dictionary]` with ship entries:
  - `blueprint_id: String`
  - `sr: int`
  - `upkeep_credits_per_day: int`
- `readiness: int` (`0..100`, default `100`)
- `missed_upkeep_days: int` (default `0`)
- `last_refit_day: int` (default `-999999`)

Legacy flat fleets (`blueprint_id/sr/upkeep_credits_per_day` without `ships`) are lazily normalized once when fleet defaults are applied.

Derived fleet values:
- `base_sr = sum(ships[].sr)`
- `upkeep = sum(ships[].upkeep_credits_per_day)`
- `effective_sr = floor(base_sr * readiness / 100)`

`effective_sr` is used for SR-sensitive gameplay (system SR maps, blockade comparisons, haven clear checks, and patrol eligibility thresholds).

### Deterministic fleet upkeep ordering

In daily upkeep, fleets are paid per faction in ascending `fleet_id` order.
- If faction credits can fully pay a fleet upkeep, upkeep is paid.
- If not, that fleet is unpaid for the day (credits do not go negative).

This unpaid marker drives readiness decay directly.

### Daily readiness rules (decay then recovery)

Per fleet per day:
1. **Decay**
   - unpaid upkeep: `missed_upkeep_days += 1`, `readiness -= 10`
   - paid upkeep: `missed_upkeep_days = 0`
   - if system pirate state is `ACTIVITY`: `readiness -= 1`
   - if system pirate state is `HAVEN`: `readiness -= 2`
2. **Recovery**
   - if in a system with an active allied Shipyard I (`enabled == true && disabled_days == 0`): `readiness += 5`, `last_refit_day = current_day`
   - otherwise passive recovery: `readiness += 1`

Readiness is clamped to `0..100`.

Readiness logs are emitted only when changed:
- `DAY d | FLEET_READY | fleet=K owner=FID sys=SID base_sr=B eff_sr=E readiness=R delta=DR reasons=[...]`
- reasons tokens: `upkeep_missed`, `piracy_activity`, `piracy_haven`, `refit`, `passive`.

### Merge / Split fleet operations

Simulation exposes deterministic methods:
- `merge_fleets(system_id, owner_faction_id, fleet_ids:Array[int]) -> int` returns primary fleet id
- `split_fleet_one_ship(fleet_id:int) -> int` returns new fleet id

**Merge preconditions**
- same owner faction
- same system
- no selected fleet has `status == "moving"`

**Merge deterministic behavior**
- primary fleet is lowest `fleet_id`
- merge order:
  - source fleets sorted by `fleet_id` asc
  - within each fleet, ships sorted by `(blueprint_id asc, sr desc, upkeep_credits_per_day asc)`
- merged readiness:
  - `floor(sum(readiness_i * base_sr_i) / sum(base_sr_i))`
- all merged fleets except primary are removed

**Split (v0: one ship) preconditions**
- fleet has at least 2 ships
- fleet not moving

**Split deterministic behavior**
- ships sorted by `(sr desc, blueprint_id asc, upkeep_credits_per_day asc)`
- detach the **LAST** ship in that sorted list
- new fleet receives detached ship and new monotonic fleet id
- both fleets retain original readiness

---

## 15) Phase 12 — Ground Troops v0

Ground troops are now a planet-locked strategic unit with deterministic training/upkeep behavior.

### 12.1 Troop blueprint

`StrategicTestConfig.TROOP_BLUEPRINTS["troops_basic"]`:
- `train_days = 3`
- `credits_cost = 120`
- `metal_cost = 10`
- `rare_cost = 0`
- `gp = 1`
- `upkeep_credits_per_day = 2`

Additional constants:
- `TROOP_MAX_TRAIN_JOBS_PER_PLANET = 1`
- `TROOP_TRAINING_USES_PLANET_CACHE = false` (training consumes faction global stockpiles, not settlement-local metal caches)

### 12.2 Planet troop fields

Each planet now carries:
- `troops: Array[Dictionary]`
- `troop_gp: int` (derived cache)
- `troop_training_queue: Array[Dictionary]`
- `troop_training_progress: int`

Each troop dictionary carries:
- `troop_id: int`
- `owner_faction_id: int`
- `planet_id: int`
- `type_id: String` (`"troops_basic"`)
- `gp: int`
- `upkeep_credits_per_day: int`
- `status: String` (`"active"`)

### 12.3 Effective garrison

Per planet, troop contribution is derived as:
- `troop_gp = sum(t.gp for active troops owned by the planet owner)`

Governance and security use:
- `effective_garrison_gp = current_garrison_gp + troop_gp`

Usage:
- Control update (`Garrison -> Control`) now compares `effective_garrison_gp` against `required_garrison_gp`.
- Controller security +10 “planet has garrison” rule now checks whether any controller-owned planet has `effective_garrison_gp >= 1`.

`current_garrison_gp` is retained; troops are additive.

### 12.4 Planet-local troop training queue

Deterministic rules:
- max 1 active troop training job per planet,
- governor can enqueue jobs without requiring immediate stockpile sufficiency,
- costs are deducted at completion only,
- if completion-day stockpile is insufficient, job enters stalled state and retries daily,
- stall logging is throttled once/day/job.

Training job dictionary shape:
- `type = "train_troop"`
- `troop_type_id`
- `owner_faction_id`
- `planet_id`
- `days_required`
- `days_progress`
- `cost_credits / cost_metal / cost_rare`
- `status`

### 12.5 Governor enqueue rule

Per owned planet each day:
- computes deficit as `max(0, required_garrison_gp - (current_garrison_gp + troop_gp))`,
- enqueues one `troops_basic` job if deficit exists, queue is empty, and projected solvency still holds after adding future troop upkeep,
- throttles skip logs once/day/planet for solvency/queue-full skip cases.

### 12.6 Upkeep and logging

Daily upkeep:
- active troop upkeep is paid from owning faction credits in deterministic order (`planet_id`, then `troop_id`),
- if credits are insufficient, troop is not deleted in v0; unpaid event is logged.

Required troop logs present:
- `TROOP_ENQUEUE`
- `TROOP_COMPLETE`
- `TROOP_STALL`

Planet daily snapshot logs (including harness snapshots) now include:
- `troop_count`
- `troop_gp`
- `effective_garrison_gp`

### 12.7 Planet-locked non-goal (explicit)

v0 troops still do not move independently across planets/systems; transport-led invasion uses the two-day ground engagement lifecycle (start on contact, resolve next day).

## 14) Phase 13 — Inspector & Governor Transparency

Phase 13 introduces **read-only observability infrastructure** for strategic debugging/balancing with **no simulation-rule changes**.

### 14.1 Strategic Inspector panel (UI observability)

A togglable `Strategic Inspector` panel is intended to provide deterministic visibility across:
- `System`
- `Planet`
- `Faction`
- `Fleets`
- `Troops`
- `AI` (intent + budget transparency)

Inspector content requirements:
- global view when nothing is selected,
- selection-aware detail view for system/planet/faction/fleet context,
- deterministic ordering for all collections (sorted by stable ids/keys),
- deterministic formatting helpers (never rely on raw `str(Dictionary)`).

Deterministic helper expectations:
- `fmt_sorted_int_map(dict[int,int]) -> String`
- `fmt_sorted_bool_map(dict[int,bool]) -> String`
- `fmt_sorted_int_array(arr[int]) -> String`

### 14.2 Governor intent transparency (read-only instrumentation)

The governor loop records what was considered per day/faction without changing decisions:
- top candidate actions (target, priority, breakdown fields),
- final gating outcome (`ok` enqueue vs first blocking reason token),
- deterministic ordering/grouping by day, faction, system, and priority.

Standardized first-blocking tokens include:
- `shipyard_missing`
- `shipyard_busy`
- `enqueue_cap_reached`
- `solvency_failed`
- `insufficient_planet_cache_mr`
- `belt_missing`
- `platform_rule_failed`
- `troop_queue_full`
- `other`

Recommended storage shape:
- `sim.governor_intents_by_day[day][faction_id] = Array[Dictionary]`
- optional rolling retention window (example: last `K=10` days).

### 14.3 Budget ledger transparency (read-only instrumentation)

At end-of-day, the simulation records per-faction budget outcomes for UI/debugging:
- income totals (credits and optional metals),
- paid upkeep totals + breakdowns,
- net credit delta,
- credits end-of-day,
- optional unpaid-count diagnostics.

Recommended storage shape:
- `sim.budget_ledger_by_day[day][faction_id] = Dictionary`

### 14.4 Logging guardrail

A config gate controls optional transparency logging:
- `DEBUG_GOVERNOR_TRANSPARENCY_LOGS := false`

When enabled, logs should remain deterministic and throttled:
- one ledger summary line per faction/day,
- up to three intent lines per faction/day.

### 14.5 Invariants

Phase 13 observability must preserve existing strategic behavior:
- no changes to economy rules, costs, thresholds, or day order,
- no governor decision changes,
- no new mechanics/resources/units,
- no new randomness.

### 14.6 In-game observability export

Any observability text shown in-game should also be mirrored to a plain text file for offline review.

Current harness paths (GalaxyViewportTest):
- `galaxy_viewport_test_action_log.txt` (day log stream)
- `galaxy_viewport_test_ui_snapshot.txt` (latest in-game panel snapshot)

## 15) Phase 15 — Transports & Planet Conquest

### 15.1 Transport blueprint

A new ship blueprint is available in `SHIP_BLUEPRINTS`:
- `transport_mk1`
  - `sp_cost=8`
  - `credits_cost=500`
  - `metal_cost=25`
  - `rare_cost=0`
  - `sr=2`
  - `upkeep_credits_per_day=3`
  - `transport_capacity_gp=10`
  - `tags.role="transport"`

Transport fleets are intentionally weak in direct space combat and are expected to be escorted.

### 15.2 Fleet transport state

Fleet runtime schema now includes:
- `cargo_troop_gp: int`
- `transport_capacity_gp: int`
- `landed_planet_id: int` (`-1` = orbit, otherwise a planet id)

Rules:
- cargo is valid only for fleets made entirely of transport ships,
- non-transport fleets are normalized to `cargo_troop_gp=0` and `landed_planet_id=-1`,
- landed transports cannot receive inter-system move orders until launched.

### 15.3 Land / launch / load / unload

Transport actions are deterministic and id-gated:
- `transport_land(fleet_id, planet_id)`
- `transport_launch(fleet_id)`
- `transport_load_troops(fleet_id, planet_id, requested_gp)`
- `transport_unload_troops(fleet_id, planet_id, requested_gp)`

Load requires:
- transport is landed on that planet,
- same system,
- planet owner matches transport owner.

Load removal from `planet.troops` is deterministic by ascending `troop_id`, and GP removal is exact (partial reduction of a troop entry is allowed when needed so removed GP equals requested-applied GP).

Unload creates `troops_basic` units (`gp=1`) with deterministic `_next_troop_id` assignment.

Hard constraint:
- troops change planet only through transport unload; there is no direct troop relocation path.

### 15.4 Invasion (troops-only planet conquest)

Planet ownership changes only through ground engagement resolution (`ENGAGE_GROUND_RESOLVE` with `result=WIN`).

`transport_invade_planet(...)` is an intent/gate command (hostility + blockade + SR gate + landed transport checks) that logs `INVASION_ORDER`; actual combat is resolved by the two-day ground engagement lifecycle.

Invasion preconditions:
- attacker transport is landed on target planet,
- transport cargo > 0,
- attacker is hostile to current owner,
- attacker is not blockaded in system,
- attacker friendly SR in system is `>=` attacker enemy SR.

Combat model at resolve-day:
- `A = attacker GP currently present on planet` (hostile landed transport cargo + hostile troops)
- `D = defender.current_garrison_gp + defender_troop_gp`
- attacker wins if `A > D`, else defender holds

Attrition:
- `attacker_losses = min(A, ceil(D / 2))`
- `defender_troop_losses = min(defender_troop_gp, ceil(A / 2))`
- defender admin garrison is not directly killed in v0

On win:
- `planet.owner_faction_id = attacker`
- `control = 50`
- `stability = 40`
- `current_garrison_gp = 0`
- remaining defender troops on planet are cleared immediately
- remaining attacker cargo auto-unloads as occupying troops
- `faction.owned_planet_ids` is updated and sorted for both factions.

### 15.5 Encounter guardrail: transport kill on losing side

During hostile space engagements, once an engagement reaches `resolve_day`:
- each losing hostile faction with at least one transport present loses exactly one transport,
- victim is deterministic: lowest `fleet_id` transport,
- removed transport cargo is lost.

This enforces transport vulnerability and escort requirements even when not massively outmatched.

### 15.6 UI payload additions

Fleet panel payload now includes transport visibility fields:
- `is_transport`
- `cargo_troop_gp`
- `transport_capacity_gp`
- `landed_planet_id`

Planet panel payload now includes:
- `troop_count`
- `troop_gp`
- `effective_garrison_gp`
- `hostile_transport_warning` when a hostile landed transport with cargo is present
- `landed_transport_fleet_ids` and `hostile_transport_fleet_ids` (both deterministic/sorted).

Fleet panel payload now also exposes deterministic action metadata for transport fleets:
- `available_actions.can_land|can_launch|can_load|can_unload|can_invade`
- `available_actions.friendly_planet_ids`
- `available_actions.hostile_planet_ids`

### 15.7 Explicit constraints

- only ground troops participate in planet invasion resolution,
- only invasion can flip ownership,
- space combat/encounters never directly flip planets.

## 16) Phase 16 — AI Invasion Planner v0

Phase 16 adds deterministic AI orchestration for transport-led planet invasions. Combat timing now follows a two-day engagement lifecycle for both space and ground.

### 16.8 Combat phasing (current authoritative timing)

Space combat:
- Day **N**: if hostile fleets co-exist in a system, `ENGAGE_SPACE_START` is created (`resolve_day = N+1`).
- Day **N+1**: `ENGAGE_SPACE_RESOLVE` applies combat outcomes once and clears engagement state.
- Fleets that arrive during the window are present for resolve because arrivals are processed before engagement resolve.

Ground combat (transport invasion):
- Day **N**: hostile troop/transport co-location creates `ENGAGE_GROUND_START` (`resolve_day = N+1`).
- Day **N+1**: `ENGAGE_GROUND_RESOLVE` applies ground outcomes once and ownership may flip.
- If one side leaves before resolve, engagement resolves as `DISENGAGED` with no damage.

### 16.1 Runtime planner state

`GalaxySimulationTest` now maintains per-faction runtime planner state:
- `invasion_plan_by_faction: Dictionary[int, Dictionary]`

Plan dictionary fields:
- `state: "idle" | "build_transport" (ensure_transport) | "assemble_troops" (ensure_troops) | "ensure_escort" | "load" | "move" | "land" | "invade" | "retreat_or_abort" | "cooldown"`
- `target_planet_id`
- `target_system_id`
- `staging_planet_id`
- `staging_system_id`
- `transport_fleet_id`
- `escort_fleet_ids` (sorted)
- `required_troop_gp`
- `committed_troop_gp`
- `last_step_day`
- `cooldown_until_day`

### 16.2 Tick timing in daily order

Planner step runs once/day/faction:
1. after troop training completion,
2. after shipyard progression/completions,
3. before dispatcher/space queue advancement.

This allows the planner to issue deterministic move/land/load/invade actions using newly completed units.

### 16.3 Deterministic target + staging selection

When state is `idle` and cooldown expired, the planner selects one hostile target planet not already claimed by another active plan.

Eligibility:
- hostile owner (`faction_id != owner_faction_id`),
- reachable from candidate staging with hop distance `0..1` (same or adjacent).

Scoring (higher is better):
- `value_score = base_credits_per_day`
- `weakness_score = 100 - control`
- `defense_score = effective_garrison_gp * 20`
- `distance_penalty = hop_distance(staging, target) * 10`
- `total = value + weakness - defense - distance_penalty`
- tie-break: lowest `target_planet_id`

Staging planet selection:
- owned planet,
- reachable to target,
- has troops now or can enqueue troop training,
- highest control wins, tie-break lowest planet id.

Required invasion payload baseline:
- `required_troop_gp = max(5, target_effective_garrison_gp + 1)`.

### 16.4 State machine behavior

- `build_transport`
  - if no available transport fleet, enqueue `transport_mk1` via ship build queue in nearest owned system with active shipyard,
  - respects solvency rule (`expected_income - projected_upkeep >= 0`),
  - when available, pick lowest transport `fleet_id`.

- `assemble_troops`
  - stage on selected planet,
  - if troops on staging planet are already enough, transition directly to `load`,
  - if troops are below required, attempt staging-planet troop training,
  - if staging queue is full, treat as WAIT (`reason=wait_queue_full`) and do not emit a failure,
  - when queue is full and troops are insufficient, deterministically search alternate owned staging (reachable, has troops or train capacity), choosing highest troop GP then lowest `planet_id`, and log `reason=switch_staging`,
  - transition when enough troops are present.

- `load`
  - move transport to staging system if needed,
  - land on a deterministic owned load planet in-system (highest troop GP, tie lowest `planet_id`),
  - perform one deterministic `TROOP_LOAD` using `min(required, capacity, available)`.
  - if loading is expected but does not occur, emit one `reason=load_skip=<TOKEN>` line per day per faction for diagnostics,
  - allowed tokens: `transport_missing`, `transport_not_in_staging_system`, `transport_moving`, `transport_not_landed`, `staging_has_no_troops`, `capacity_full`, `cannot_land`, `other:<short>`.

- `move`
  - escort safety gate before committing move,
  - escorts selected from same system: non-transport, not moving, `effective_sr >= 10`, lowest fleet ids,
  - include pirate threat in target risk estimate,
  - require `escort_sr + transport_sr >= estimated_enemy_sr(target_owner_sr + pirate_threat)`, otherwise wait.

- `land`
  - on target arrival, issue `TRANSPORT_LAND` for target planet.

- `invade`
  - re-check Phase 15 gate immediately before `INVASION`:
    - attacker not blockaded,
    - attacker friendly SR >= enemy SR in system,
  - if gate fails and enemy dominates, retreat to staging,
  - if gate passes, commit cargo via `transport_invade_planet`.

- `cooldown`
  - enter for 10 days after invade attempt,
  - target/staging/transport/escort payload fields are cleared while cooling down,
  - state returns to `idle` when cooldown expires.

### 16.5 Logging + determinism contract

Planner emits deterministic logs:
- one summary line per faction/day while state is not idle,
- explicit action lines for transport enqueue, load, move issue, invade outcome,
- repeated identical failure reasons are throttled to once/day/faction.

Determinism requirements:
- sorted faction iteration,
- sorted fleet/escort selection,
- stable lowest-id tie-breaks for targets, staging planets, and transport fleet choice.


### AI Invasion Planner Hardening (v0)

> Note: runtime state identifiers keep legacy names (`build_transport`, `assemble_troops`) where applicable; they are functionally equivalent to `ensure_transport` and `ensure_troops` in this hardening contract.

Audit + implementation notes (A1–A8):
- **A1 Single-authority enforcement:** only planner authority can emit movement, transport, invasion, and invasion troop enqueue operations; non-planner attempts are blocked with ERROR logs.
- **A2 Forward progress guarantee:** planner states now emit explicit WAIT reasons (`wait_queue_full`, `wait_escort`, etc.) or transition deterministically to cooldown/abort paths.
- **A3 Use-existing-troops-first:** `ensure_troops` transitions directly to `load` (`reason=proceed_to_load`) when staging troop GP already satisfies requirement.
- **A4 Staging fallback:** on blocked staging, planner deterministically switches to alternate owned staging by highest troop GP, tie-break lowest planet id; if no alternate exists, planner waits with explicit reason.
- **A5 Transport lifecycle resilience:** missing transport forces reset to `ensure_transport`; planner avoids transport build spam once a viable transport exists.
- **A6 Conservative escort policy:** transport does not move to target until escort SR gate and predicted invade preconditions are satisfied; otherwise planner waits with `reason=wait_escort`.
- **A7 Gate failure abort/retreat:** if pre-invade gate fails, planner transitions to `retreat_or_abort`, retreats transport/escorts deterministically to staging (or nearest safe owned system), logs `reason=abort_gate_failed`, then enters cooldown.
- **A8 Load diagnostics:** load emits once/day/faction `reason=load_skip=<token>` diagnostics when expected loading is blocked.

Canonical reason tokens:
- `wait_queue_full`
- `wait_escort`
- `switch_staging`
- `proceed_to_load`
- `proceed_to_move`
- `arrived_target_system`
- `abort_gate_failed`
- `transport_missing`
- `load_skip=<token>`
- `cooldown`

Planner summary contract (non-idle, once/day/faction):
- `DAY d | AI_INVASION | source=FACTION_PLANNER faction=FID state=STATE targetP=PID stagingP=SPID transport=K cargo_gp=CG req_gp=RG escorts=[...] reason=REASON gate_sr_ok=0|1 gate_blockaded=0|1 shipyard_candidates=[...] shipyard_active_in=SID shipyard_pending_in=SID`

### 16.6 Phase 16B — AI Planner Trace Buffer

Phase 16B adds observability-only planner tracing for post-mortem diagnostics without changing invasion decisions.

- Per-faction deterministic ring buffer size: `AI_TRACE_BUFFER_SIZE = 60`.
- Optional debug print switch: `DEBUG_AI_TRACE_LOGS = false` (disabled by default).
- Runtime storage in `GalaxySimulationTest`:
  - `ai_trace_by_faction: Dictionary[int, Array[Dictionary]]`
  - `ai_trace_cursor_by_faction: Dictionary[int, int]`
- Accessor `get_ai_trace_entries(faction_id)` returns entries in chronological order (oldest → newest), independent of ring overwrite position.
- Entry schema is stable and normalized for deterministic display:
  - ids/state/step (`day`, `faction_id`, `planner_state`, `step`, target/staging/transport ids)
  - force payload (`required_troop_gp`, `committed_troop_gp`, sorted `escort_fleet_ids`)
  - compact computed snapshot (`hop_distance`, `est_enemy_eff_sr`, `friendly_eff_sr`, `gate_pass` as ints/bools only)
  - outcome (`decision`, standardized `reason`, short `note`)
- Inspector integration shows faction trace rows chronologically (newest at bottom), with expandable computed/escort details.
- Contract: trace buffer is observability only; no planner thresholds, transitions, or simulation outcomes are changed.

## Phase 17 — Global Decision Authority

Phase 17 removes subsystem-level order authority and enforces a single faction planner.

- New deterministic per-day per-faction order book shape:
  - `fleet_orders`, `ship_build_orders`, `orbit_build_orders`, `platform_orders`, `troop_train_orders`, `transport_ops`, `invasion_ops`, `notes`
- Every executable order must include:
  - `source=FACTION_PLANNER`
  - deterministic reason token
  - explicit target ids
- Patrol, HAVEN, invasion AI, and governor are treated as scorers/candidate generators consumed by the faction planner.
- The invasion state-machine step is executed only from `execute_faction_order_book(...)` so transport, landing, and invasion effects still flow through planner authority.
- Only the planner execution phase may issue movement, transport/invasion actions, or enqueue builds.

Deterministic authority rules:

- max movement orders per faction/day: `2`
- max ship enqueues per faction/day: `1`
- max troop training enqueues per planet/day: `1`
- ties break by lowest target id after stable score ordering.

Daily planner summary log:

- `DAY d | FACTION_PLAN | faction=FID actions=fleet:X ship:Y orbit:Z troop:T invade:I notes=N`

Safety contract:

- Only `FACTION_PLANNER` may issue fleet movement orders.
- Any attempted movement order with source not equal to `FACTION_PLANNER` is rejected, logged as `FLEET_ORDER_BLOCKED`, and does not modify fleet movement state.
- Patrol is local-only and never emits movement orders.
