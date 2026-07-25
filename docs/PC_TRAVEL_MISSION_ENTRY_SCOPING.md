# PC Travel → Mission Entry — Scoping (lifting the PC-travel HOLD)

Status: scoping draft, 2026-07-21. Not a design change — this catalogues what
exists, what remains, and the design decisions still owed to the owner before the
remaining pieces can be built. No mechanic/value is invented here.

**PROGRESS 2026-07-25 (HOLD lifted by owner):** the headless half of the pipeline
is now complete end-to-end.
- Phase-1 storage step finished: `_process_pc_mission_arrivals` now PERSISTS each
  PC's surfaced missions on `L5RCharacterData.pending_arrival_mission` (not just the
  advance_day return dict); `PcSystem.logout` clears it + resets the arrival marker.
- Headless launch DECISION added: `MissionEntryController.resolve_arrival_launch(pc)`
  (which AUTO seed launches + engageable list) + `consume_pending_arrival(pc)` —
  moves that logic out of the Node/UI `MissionFlow` into tested simulation.
- Headless outcome WRITEBACK added: `MissionEntryController.apply_mission_outcome(...)`
  gives `InsurgencyRelocationSystem` (s56.13, LOCKED, previously zero callers) a
  caller — a completed mission now writes strength/relocation back to the world.
- Remaining is genuinely the Godot combat UI + the sim<->UI wiring (runtime, not
  headless-validatable) and networking (out of scope). New owed decision below (#5).

## Goal

Make an ASCII-map mission actually reachable by a live player character: a PC
travels the world, arrives somewhere, and an AUTO seed launches (or the PC fires
`ENGAGE_MISSION` on a PLAYER_INITIATED seed). This is the end-to-end path the
s40 / s56 stack has been built-but-unreachable behind (the PC-travel HOLD).

## What already exists (the substrate)

| Piece | File | State |
|---|---|---|
| Settlement→settlement travel + travel-time model (s55.29) | `simulation/travel_system.gd` | Built, headless. `begin_travel`, `process_travel_tick` → **arrivals array**, terrain costs, distance lookup. |
| Travel tick wired into the daily loop | `simulation/day_orchestrator.gd:14039` | `process_travel_tick(characters)` runs each day; `travel_arrivals` flows through `advance_day`. |
| PC login/logout presence (s60.3/60.4) | `simulation/pc_system.gd` | `login()` sets `physical_location = home`; `logout()` clears it. |
| **PC arrival-detection core (s56.19)** | `simulation/pc_arrival_resolver.gd` | **Built 2026-07-21.** Province-change detection → classified AUTO/PLAYER_INITIATED seeds. Headless, PC-only. |
| Mission entry policy + controller (s56.19) | `mission_entry_policy.gd`, `mission_entry_controller.gd` | Built. AUTO/PLAYER_INITIATED classification; `ENGAGE_MISSION` (1 banked AP). |
| Session builder + UI glue | `mission_launcher.gd`, `scripts/ui/mission_flow.gd`, `scripts/ui/combat_screen.gd` | Built (MissionFlow flagged unverified-under-Godot). Turns a seed into a live skirmish. |
| Zone hierarchy + registry (s4.4) | `shared/{greater,navigation,lesser}_zone_data.gd`, `simulation/zone_registry.gd`, `settlement_zone_builder.gd` | Built. Greater→Navigation→Lesser, flag matrix. |
| Networked zone navigation (existing, out-of-policy) | `scripts/managers/NetworkManager.gd` | RPC `request_zone_move_to`, zone name/description/character-list. Pre-existing; networking was previously out of scope. |

## Remaining work, phased

### Phase 1 — Headless: connect the resolver to the existing arrival pipeline — **DONE 2026-07-21**
Wired: `DayOrchestrator._process_pc_mission_arrivals` runs `PCArrivalResolver` over every
PC each day (after travel settles `physical_location`) and emits `pc_mission_arrivals`
(`{pc_id, province_id, auto_seeds, engageable_seeds}` per PC with content) in the
`advance_day` return dict. Province-change detection unifies the three arrival triggers.
Producer only — no launch. The pass now produces the **complete** seed set:
- Insurgency / PTL-oni / taint / spiritual seeds (via `select_province_seeds`).
- Road Encounters (s4.3.11 / s56.1.5): a PC travel-arrival into an under-garrisoned
  province rolls `check_road_encounter` (15% → Ronin Bandit AUTO), login excluded;
  destination-province-only until intermediate-route data exists.
- Wall Sortie (s2.4.11 / s56.1.2, PLAYER_INITIATED): `wall_statuses` is built from each
  province's `shadowlands_strength`; `WallSystem.get_ai_sortie_size` sizes it and returns
  "none" below the medium SS tier, so only a genuinely-threatened Wall province surfaces one.

Caveat: the arrival pass fires on province change, so a **stationary** PC whose current
province gains a new PLAYER_INITIATED option (a Wall Sortie as SS rises, or a newly-detected
insurgency) won't see it via this pass — that on-demand engageable listing is the Phase-2
session layer's job (re-query `select_province_seeds` / `get_engageable_seeds` at the PC's
location when the player looks). No seed is lost; it is simply surfaced through a different
channel. No remaining Phase-1 data-gap.

Original scope note (now satisfied): **In scope, no networking, no new design decisions**
(uses the owner-set trigger policy from s56.19). For each PC in `advance_day`:
- travel-completion: filter `travel_arrivals` for PCs → `PCArrivalResolver.resolve_arrival`.
- login: call the resolver right after `PcSystem.login` sets `physical_location`.
- store the returned `auto_seeds` / `engageable_seeds` on the PC as *pending arrival
  missions* (a new field), for the session layer to consume. **No launch here**
  (launching is Node/UI). This turns the resolver from a dormant hook into a live
  producer.

### Phase 2 — Session/UI glue: actually launch the mission
**Needs a Godot runtime + the session layer.** Entry point added 2026-07-21:
`MissionFlow.on_pc_mission_arrival(pc, province, province_history, arrival, seed_str)`
consumes a Phase-1 `pc_mission_arrivals` entry directly (pre-classified seeds), auto-launches
the first AUTO seed via `CombatScreen.start_mission`, and returns the engageable list.
⚠ Like the rest of `MissionFlow` this is unverified scaffolding — it parse-checks but has
never run under Godot; it must be exercised in a live Godot/session run before being relied
on. **Remaining for Phase 2:** the session/net layer that, for each logged-in PC, looks up
`province` / `province_history` / `seed_str` and calls this method — plus verifying the whole
`MissionFlow` → `CombatScreen` → `AsciiMapView` chain under a real runtime. That runtime
layer is networking/UI and cannot be validated in the headless environment.

### Phase 3 — Player-facing MUD navigation
**Networking/UI.** Destination selection (MUD command) → `TravelSystem.begin_travel`,
driven through the net layer (`NetworkManager` or its successor). The zone-nav read
side (`request_zone_move_to`, zone descriptions) partly exists.

## Design decisions still owed to the owner (STOP — do not invent)

1. **Does PC overland travel reuse `TravelSystem` (s55.29) as-is?** s4.4 says travel
   costs time "per existing World Map travel rules," and `TravelSystem` *is* those
   rules — but it is documented as "NPC movement." Confirm PCs use the same system
   (recommended) vs. PC travel having its own rules.
2. **Province-boundary-crossing trigger granularity.** `TravelSystem` is a
   settlement→settlement days-countdown with **no intermediate provinces** — so
   "boundary crossing" currently coincides with "travel completion." True mid-journey
   crossing (firing seeds in provinces merely passed through) needs a sub-tile route
   path, a Section-C map-data blocker. Decision: accept boundary-crossing ≈
   travel-completion for now, or hold that sub-trigger until sub-tile routes exist?
3. **PLAYER_INITIATED discovery gate — RESOLVED 2026-07-21 (interpretation).** s56.19 says
   the PC assaults a "known, located threat." This is satisfied by the existing world-level
   detection gate: `QuestSeedSelector.select_province_seeds` surfaces insurgency-sourced
   seeds only when `ins.detected` is true, so the engageable list is exactly the set of
   world-known threats located in the PC's province. No per-PC knowledge gate is added
   (a detected insurgency is public knowledge). Owner may veto if a finer per-PC gate
   (met_characters / topics) is wanted — the GDD language does not require it.
4. **Target networking architecture.** `NetworkManager` is the pre-existing RPC layer
   built while networking was out of scope. Before building navigation on it, confirm
   the intended stack (ENet? WebSocket? single-player-first?) — CLAUDE.md's networking
   constraint is only just lifted and the target architecture is unspecified.
5. **PC-side mission rewards (NEW, 2026-07-25; PARTIALLY RESOLVED).** Correction:
   s56.10 *does* specify per-seed-type rewards/consequences (all PROVISIONAL). Wired:
   **Wall Sortie** (`apply_wall_sortie_outcome`) — SS −1/−2/−3 by size + PC commander
   +0.2 Glory on success, SS −1 on partial, nothing on failure (s56.10:521). Still
   unspecified (no number): the insurgency-backed seeds (Ronin Bandit / Maho Cult /
   etc.) say only "the lord gains Glory" — `apply_mission_outcome` writes the world
   effect but awards no PC Glory pending an owner number. The spiritual encounters
   (haunting fulfilled/banished +Honor/+Glory, Gaki-do) are s56.16 with their own
   resolution semantics (fulfilled ≠ a MissionOutcome value) — a separate wiring.

## Recommendation

Build **Phase 1** next — it is fully in scope (headless, no networking), needs none of
the four open decisions, and makes the resolver live against the travel pipeline that
already exists. Phases 2–3 wait on decisions #3 and #4 (and a Godot runtime for #2).
