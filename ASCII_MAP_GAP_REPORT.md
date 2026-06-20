# ASCII Map System — Gap Report
Generated 2026-06-20. File-by-file: what's built, how it was verified, and whether it's reachable in a live game.

## Legend
**Verification**
- ✅ RUNTIME — executed under a Godot headless driver (behavior observed)
- 🟡 STATIC — written + parse-checked + reviewed, **never executed**
- 🧪 TEST-ONLY — GUT tests exist but GUT is **non-functional headless** in this project, so effectively unverified-at-runtime
- 🔢 GENERATOR-VERIFIED — run under Godot as a map generator (connectivity/output sweeps), but not in live combat

**Reachability**
- 🔌 LIVE — actually runs inside the world simulation today
- 🎮 DEMO — reachable only via `combat_demo.gd` (a manual test scene)
- 🚫 NONE — no production caller; cannot be entered in a real game session

> **Top-line:** there is **no path from the running world sim to an ASCII mission.** PC world-map travel is owner-HOLD, so the entire layer below is 🎮/🚫 in practice. Everything is "engine present, not plugged into play."

---

## 1. Map generation & terrain layers — solid, generator-verified
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `ascii_map_generator` | 2155 | 🔢 | 🚫 | All 35 ZoneSubtypes generate; full flood-fill connectivity sweep passed (2026-06-15/16). |
| `ascii_map_data` (shared) | 386 | 🔢 | 🚫 | Tile grid, doors, destruction, fire/overlay/depth fields. |
| `fov_system` | 168 | ✅ | 🚫 | Shadowcasting + env modifiers; runtime-tested. |
| `movement_system` | 84 | ✅ | partial | Terrain cost/passability; used by `ascii_map_view` input (live for the demo). |
| `noise_system` | 202 | 🧪 | 🚫 | Dijkstra propagation; GUT tests only. |
| `ascii_map_environment` | 317 | 🧪 | 🚫 | Weather/biome/alert/kansen tables. |
| `fire_system` | 157 | 🟡 | 🚫 | Spread/weather; wired into `advance_round` but never run live. |
| `kansen_system` | 157 | 🧪 | 🚫 | Per-tile taint grid; `generate_density_grid` has **no caller** (needs missions). |
| `trap_system` | 347 | 🟡 | 🚫 | 5 traps; all values PROVISIONAL; UI hooks in `ascii_map_view` unrun. |

## 2. Mission pipeline — built, headless-verified, no live trigger
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `quest_seed_selector` | 270 | 🧪 | 🚫 | Seed routing. |
| `roster_composition_system` | 764 | 🧪 | 🚫 | Unit rosters per seed. |
| `template_selector` | 171 | 🧪 | 🚫 | Terrain→template pools. |
| `mission_template_resolver` | 61 | 🧪 | 🚫 | |
| `mission_populator` | 361 | 🧪 | 🚫 | Spatial placement. |
| `mission_builder` | 298 | 🧪 | 🚫 | Assembles seed→map→roster→env. |
| `mission_session` | 65 | 🟡 | 🚫 | |
| `mission_entry_policy` / `mission_entry_controller` | 46/65 | 🧪 | 🚫 | s56.19 AUTO vs PLAYER_INITIATED; `ENGAGE_MISSION` AP spend. |
| `mission_launcher` | 37 | 🧪 | 🚫 | Builds a session from a launch request. |
| **8 template generators** (cave, occupied_village, makeshift_stockade, hilltop, ravine_camp, ruined_structure, urban_hideout, castle_siege, ship_boarding, forest_approach_camp) | ~5k | 🔢 | 🚫 | Generate + connectivity-verified; CAVE entrance fix confirmed. |

## 3. Turn-based combat core — the most-verified part
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `individual_combat` | 2629 | ✅ | partial | Rolls, stances, **all s40 maneuvers** (Knockdown/Disarm/Feint/Guard/Grapple incl. Break/Pass), sumai, iaijutsu, kata/kiho hooks. Heavily runtime-verified this month. |
| `ascii_map_combat_orchestrator` | 6500 | ✅/🟡 mix | 🎮 | **Core combat (maneuvers, grapple, NPC AI, companion turns) runtime-verified.** Spirit/oni live-combat + escalation + positional abilities = **mostly 🟡 static** (tranches 7–16), with a subset later runtime-verified (oni damage path, regen, swallow, spawn-on-death, disease, charges). |
| `combat_controller` | 1811 | 🧪 | 🎮 | Real-time/stealth (alert, noise, stealth kills, morale, end-combat consent). 154 GUT tests that **don't run headless** → effectively unverified at runtime. |
| `companion_system` | 257 | ✅ | 🎮 | Commands/morale; orchestrator integration runtime-verified (PROTECT→Guard etc.). |

## 4. Creatures & abilities — data verified, many abilities deferred
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `spirit_bestiary` | 354 | ✅ | 🎮 | 4 realm rosters (Gaki-do/Toshigoku/Sakkaku/Chikushudo). Meido/Yume-do have **no GDD roster** (can't build). |
| `oni_bestiary` | 350 | ✅ | 🎮 | 35 oni; loads + damage path runtime-verified. |
| `undead_bestiary` / `additional_creatures_bestiary` / `ancient_races_bestiary` | 204/375/129 | ✅ | 🎮 | 16+37+10 creatures; spawn-by-id verified. |
| `spirit_ability_system` | 324 | ✅/🟡 | 🎮 | ~13 abilities wired (invuln filters, fear, swift, engulf, fire, paralysis…). **DEFERRED**: full possession/puppeteering, Mujina illusion-spellcasting, some group auras, deceptive-weight pin nuances. |
| `spirit_combatant` | 138 | ✅ | 🎮 | Stat-block→combat puppet adapter. |

## 5. Spiritual encounter (s56.16) — built, largely static-only
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `spiritual_encounter` | 596 | 🟡 | 🚫 | Per-round ritual+escalation+exposure loop. **Static-only — needs Godot driver-verify.** |
| `spiritual_ritual_system` | 221 | 🟡 | 🚫 | Restoration ritual; RITUAL_TN owner-set. |
| `spiritual_exposure_system` | 275 | 🟡 | 🚫 | Per-realm Willpower erosion. |
| `spiritual_palette` | 195 | 🟡 | 🚫(render hook live, gated) | Depth-driven overlay tile transform. |

## 6. Spells & techniques in combat
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `spell_system` | 965 | ✅ casting; ⛔ coverage | 🎮 | Casting + a **subset** of s31–37 combat effects (direct damage all 5 rings, some buff/status/heal, NPC+companion cast). **Many spells still have NO combat effect.** |
| `kata_system` | 505 | ✅ | 🎮 | 43 katas; combat effects wired into s40. |
| `kiho_system` | 293 | ✅ | 🎮 | 73 kiho; ~all combat-relevant effects wired across 33 tranches (some 🟡 static); ~12 out-of-combat buffs mostly unwired (no consumer). |

## 7. Player-facing UI — partial, demo-only
| File | LOC | Verify | Reach | Notes |
|---|---|---|---|---|
| `ascii_map_view` | 833 | 🟡 | 🎮 | Renders map/FOV; input for **movement, doors, look, disarm, end-combat** only. **No** human turn-based command menus (stance/attack/maneuver/cast/kiho). |
| `combat_hud` | 313 | 🧪 | 🎮 | Round/wound/budget/log overlay. |
| `combat_screen` | 184 | 🟡 | 🎮 | Mission↔view↔HUD glue. |
| `mission_flow` | 130 | 🟡 | 🚫 | World→mission glue; **written, never executed, not wired to PC travel.** |
| `combat_demo` | 127 | 🎮 | 🎮 | The only thing that actually starts a mission — a manual demo. |

---

## The blocking gaps, ranked
1. **No live entry (everything above is gated on this).** PC world-map travel is owner-HOLD → `mission_flow`/`mission_entry_*` have no real trigger. Until lifted, the player cannot enter any ASCII encounter in a real session.
2. **Player turn-based command UI is missing.** A human can move/open doors/look/disarm, but cannot issue stance/attack/maneuver/cast/kiho/atemi commands — those are NPC-auto or headless-only.
3. **`combat_controller` + much of the mission pipeline is GUT-test-only** → not runtime-verified (GUT is non-functional headless here).
4. **Spiritual encounter loop is static-only** — never executed under Godot.
5. **Spell coverage is a subset** — many s31–37 spells have no combat effect; several creature special abilities are deferred/blocked.
6. **Wired-but-no-trigger:** insurgency relocation (s56.13), in-mission kansen density, falling damage — all wait on #1.

## What "done" would require
- **Lift the PC-travel HOLD** → wire `world arrival → MissionEntryController → MissionLauncher → CombatScreen` (the glue exists in `mission_flow`, unverified).
- **Build the player turn-based command loop** in `ascii_map_view`/`combat_screen`.
- **Runtime-verify** `combat_controller`, the spiritual encounter loop, and the static-only orchestrator tranches under a real Godot driver (or in-engine).
- **Finish spell/creature-ability coverage** (owner design calls for the unspecified spell effects).
