# Dungeon Content Layer — Design Proposal (TRAPS · LOCKS · MULTILEVEL DESCENT)

**Status: PROPOSAL — awaiting owner approval. NOT a locked GDD section. NO code written yet.**
Every numeric value below is **PROVISIONAL** and marked `‹P›`. Nothing here is locked until the
owner approves it; on approval the agreed mechanics migrate into a locked /gdd section (with
permission) and only then is code written. Per project rules, no mechanic/number here may be
implemented until explicitly authorized.

Scope set by owner (2026-06-16): loot is **out** (not a Rokugan thing). Traps, locks/keys, and
multilevel descent are **in**. Entry confirmed working (PC spawns at the map entrance via
`MissionBuilder.get_player_entry` → `MissionSession.entry_pos`) — not part of this proposal.

Design constraints honored throughout: traces to L5R 4e skills/TNs and to existing systems
(`AsciiMapData` tile grid, `MovementSystem` open/closed doors, `FovSystem`, `NoiseSystem`,
`CombatController` AlertState, `WoundSystem`, the s56 templates + `MissionPopulator`). Deterministic
placement from the existing mission seed string. NPC-placed only when a defender has the relevant
skill (no free GM magic). PC-facing (NPCs never use the ASCII map, s40.x).

---

## 1. TRAPS

### Concept
Hidden hazards placed on dungeon maps by defenders who know how to make them. The player detects
them (or doesn't), then disarms, bypasses, or springs them. Anchored to the existing Crane **Daidoji
Iron Warrior / Harrier** ability ("Hunting (Traps)", "improvised traps deal +1k1/+2k1", s29.2/s11.7)
— that is the canonical trap-laying skill, so traps are a Crane/scout/bandit signature, not universal.

### Data model
Traps live as a **data layer, not tiles** (hidden traps must not render). New on `AsciiMapData`:
```
@export var traps: Array = []   # each: {x, y, type, detect_tn, disarm_tn, damage_roll, state, placed_by_skill}
```
`state`: HIDDEN → DETECTED → (DISARMED | SPRUNG). A DETECTED/SPRUNG trap can overlay a glyph; HIDDEN renders as normal floor.

### Trap types (traced to L5R hazards)
| Type | Effect | Resolves via |
|---|---|---|
| PIT | Fall: `‹P›2k2` damage; Athletics TN `‹P›15` to catch the edge (half/no damage) | WoundSystem + Athletics roll |
| DART / ARROW | Ranged attack vs **flat-footed Armor TN** (5 + armor bonus, per s40 stealth model), `‹P›2k2` | IndividualCombat attack |
| SNARE / NET | **Entangled** condition, escape TN `‹P›20` (matches oni-web Entangled TN 20, s54.5) | existing Entangled condition |
| ALARM / TRIPWIRE | No damage — raises nearby enemy **AlertState** (Unaware→Alert) | CombatController noise/alert |
| DEADFALL | Area collapse: `‹P›3k2`, adds rubble to `destroyed_tiles`, blocks the tile | WoundSystem + destroyed_tiles |

### Detection / disarm / trigger
- **Detect** — passive each turn within `‹P›`2 tiles AND in FOV: Perception + **Hunting** (or Investigation) vs `detect_tn`. Crane Daidoji / high Hunting get the school bonus they already have. Optional active `SEARCH` action for a deliberate sweep at +Raises.
- **Disarm** — adjacent + DETECTED: **Hunting (Traps)** or Sleight of Hand vs `disarm_tn`; miss by `‹P›10+` springs it.
- **Trigger** — stepping onto a HIDDEN trap (via `MovementSystem.check_step`, which gains a trap lookup) springs it and resolves the effect. A DETECTED trap can be stepped around (it's a known tile to avoid).
- **TN tiers** `‹P›`: crude 15 / set 20 / concealed 25 / master 30. **Damage values PROVISIONAL.**

### Placement
Deterministic from seed. Template-appropriate: cave **dead-ends** + chokepoints, before the objective room, at entrances; Forest/Stockade/Hilltop perimeters (scout templates). Density scales with seed `strength`. A trap is only placed if the roster contains a unit with Hunting:Traps (Crane Harrier, trap-savvy bandit) — otherwise the map has none. ALARM traps especially suit the stealth model (they convert a quiet infiltration into a fight).

### Integration points
`MovementSystem.check_step` (trigger), `FovSystem` (detect gating), `CombatController` (ALARM→AlertState), `MissionPopulator`/generators (placement), `AsciiMapCombatOrchestrator` (SEARCH/DISARM as actions).

### OWNER DECISIONS NEEDED
- Trap-type list (the 5 above? add/cut?), all TNs, all damage rolls.
- Detection model: passive-per-turn vs require an explicit SEARCH action vs both.
- Disarm skill: Hunting (Traps) only, or also Sleight of Hand?
- Does a sprung non-alarm trap also make noise (→ AlertState)?

---

## 2. LOCKS & KEYS  — ❌ DROPPED (owner decision 2026-06-16)

**Cut.** Rokugan's interior doors are sliding paper/wood screens (shōji/fusuma) — opened or cut, never
locked/picked. Authentic locks exist only on kura/vaults/strongboxes/cells/gates, and with loot already
cut the feature was judged too marginal. Gated areas are reached via combat / destroy-tile instead.
No lock data model, no key item layer, no PICK/FORCE actions will be built. (Original proposal retained
in git history.)

---

## 3. MULTILEVEL DESCENT

The GDD frames "depth" but **never** as classic roguelike floor-to-floor. Two interpretations:

### Option A — Within-map depth gradient (GDD-aligned, LOW complexity) — RECOMMENDED baseline
The GDD's actual language: "the **deeper** the player walks, the less the world looks like the mortal
realm" (Spiritual Insurgency s56.16), "**deeper layers** hold older, stronger revenants" (Corrupted
Burial s56.10), ravine "back-loaded value" (s56.11). All describe **one map** that gets harder/stranger
with distance from the entrance.
- **Mechanic:** tag each tile/region with a `depth` = path-distance from `entry_pos`. `MissionPopulator`
  weights stronger roster units into higher-depth regions; the leader sits at max depth. Spiritual maps
  shift their tile palette deeper (already the s56.16 concept).
- **Cost:** small — reuses the single-map pipeline; just a depth field + populator weighting.
- **Covers:** the GDD's "deeper = harder/stranger" directly, for every template.

### Option B — True stacked generated floors (HIGH complexity, NOT in GDD)
Descend a `DOWN_STAIR` tile → generate level N+1 as a fresh `AsciiMapData`; carry the party; persist
cleared levels; allow ascend/return.
- **Needs:** `MissionSession` becomes multi-level (array of `AsciiMapData`); stair transitions; per-level
  roster scaling; cross-level state persistence; a "return to surface / world" exit on level 1.
- **No GDD spec** — entirely new design.
- **Justified only** for a few templates that genuinely warrant true floors: **Cave** sub-levels, the
  **Corrupted Burial** crypt ("deeper layers"), the **Otosan Uchi Labyrinth** (already a maze zone).

### Recommendation
**Ship Option A as the universal baseline** (GDD-supported, cheap, satisfies "deeper = harder/stranger"
everywhere). **Reserve Option B** as an opt-in flag on 2–3 specific templates if you want literal
multi-floor crawls there. This avoids rebuilding the whole mission pipeline for a feature the GDD only
implies, while still giving true descent where it matters.

### OWNER DECISIONS NEEDED
- A, B, or hybrid (A everywhere + B on flagged templates)?
- If B/hybrid: which templates get true floors, how many floors, and roster scaling per floor?
- Does descending ever **prevent return** (one-way deeper), or is ascend always allowed?

---

## Suggested sequencing (after approval + GDD lock)
1. **Locks & keys** — smallest, extends the existing door model, immediate gameplay value (gated objectives).
2. **Traps** — self-contained data layer + detection/disarm/trigger; strong synergy with the stealth model (ALARM).
3. **Multilevel (Option A)** — a depth field + populator weighting; cheap and broadly applicable.
4. **Multilevel (Option B)** — only if you want true floors; largest lift, do last.

## Open cross-cutting question
Detection/disarm/pick all imply **player actions in the turn-based combat layer**, which is built
headlessly (`AsciiMapCombatOrchestrator`) but whose **player-facing UI is not scene-tested**. These
features are fully implementable and verifiable headlessly (the same way combat is); the player-facing
buttons land whenever the combat UI does.
