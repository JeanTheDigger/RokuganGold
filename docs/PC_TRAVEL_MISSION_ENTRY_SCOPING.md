# PC Travel → Mission Entry — Scoping (lifting the PC-travel HOLD)

Status: scoping draft, 2026-07-21. Not a design change — this catalogues what
exists, what remains, and the design decisions still owed to the owner before the
remaining pieces can be built. No mechanic/value is invented here.

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

### Phase 1 — Headless: connect the resolver to the existing arrival pipeline
**In scope now, no networking, no new design decisions** (uses the owner-set trigger
policy from s56.19). For each PC in `advance_day`:
- travel-completion: filter `travel_arrivals` for PCs → `PCArrivalResolver.resolve_arrival`.
- login: call the resolver right after `PcSystem.login` sets `physical_location`.
- store the returned `auto_seeds` / `engageable_seeds` on the PC as *pending arrival
  missions* (a new field), for the session layer to consume. **No launch here**
  (launching is Node/UI). This turns the resolver from a dormant hook into a live
  producer.

### Phase 2 — Session/UI glue: actually launch the mission
**Needs a Godot runtime + the session layer.** Drive `MissionFlow.on_pc_arrived`
(or its pending-arrival equivalent) from Phase-1 output → `CombatScreen.start_mission`.
Verify `MissionFlow` under Godot (it is currently unrun scaffolding). This is where an
AUTO mission visibly launches for a live PC and where `ENGAGE_MISSION` becomes playable.

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
3. **PLAYER_INITIATED discovery gate.** s56.19 says the PC assaults a "known, located
   threat." Is the engageable-seed list gated on the PC's knowledge
   (`met_characters` / topics, s22.3 / s29.15.24), or surfaced for any active
   in-province seed? This is an undesigned gate — needs an owner rule.
4. **Target networking architecture.** `NetworkManager` is the pre-existing RPC layer
   built while networking was out of scope. Before building navigation on it, confirm
   the intended stack (ENet? WebSocket? single-player-first?) — CLAUDE.md's networking
   constraint is only just lifted and the target architecture is unspecified.

## Recommendation

Build **Phase 1** next — it is fully in scope (headless, no networking), needs none of
the four open decisions, and makes the resolver live against the travel pipeline that
already exists. Phases 2–3 wait on decisions #3 and #4 (and a Godot runtime for #2).
