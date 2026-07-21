class_name PCArrivalResolver
## PC province-arrival resolver — the headless core of the s56.19 mission entry
## mechanism (owner-approved 2026-06-06; trigger policy owner-set 2026-07-21).
##
## Pure simulation class — no Node inheritance, no networking, no scene access. This
## is the deterministic core that a future PC MUD-travel / session layer calls; it
## does NOT launch a mission (that is CombatScreen / MissionFlow's job per s56.19)
## and NEVER touches the ASCII map.
##
## PC-ONLY (hard constraint: NPCs never use the ASCII map, and PCs never run the NPC
## engine). resolve_arrival refuses any character that is not a valid PC.
##
## Trigger policy (owner-set 2026-07-21): an arrival fires on travel completion,
## province-boundary crossing, AND login. All three unify to a single rule — "the PC
## is now in a province it was not in the last time this resolver ran" — so the
## resolver is province-change detection, then delegation to the already-built
## QuestSeedSelector (province seed list) and MissionEntryController (AUTO /
## PLAYER_INITIATED classification). No new mechanics or values are introduced here.
##
## physical_location is a settlement id encoded as a String ("" = logged out, s60.4).
## Logged-out state maps to province -1 and is recorded, so the next login into ANY
## province registers as a fresh arrival — honoring the "on login" trigger even when
## the PC's home settlement sits in the province they logged out from.


## Resolve the province a `physical_location` string sits in. Mirrors the
## day-orchestrator settlement->province logic: physical_location is a settlement id
## as a String; "" (logged out) or an unknown settlement resolves to -1.
## `settlement_province_map` is {settlement_id: province_id}.
static func province_for_location(
		physical_location: String, settlement_province_map: Dictionary) -> int:
	if physical_location.is_empty() or not physical_location.is_valid_int():
		return -1
	return int(settlement_province_map.get(physical_location.to_int(), -1))


## Detect whether `pc` has arrived in a new province and, if so, return that
## province's classified quest seeds. Updates pc.last_arrival_province_id as a side
## effect (records what was processed, so the same province does not re-fire).
##
## Returns a Dictionary:
##   { "arrived": bool, "province_id": int,
##     "active_seeds": Array, "auto_seeds": Array, "engageable_seeds": Array }
## When arrived is false (same province, logged out, or non-PC) the seed arrays are
## empty. The caller launches auto_seeds[0] and offers engageable_seeds per s56.19 —
## this resolver only decides and classifies; it does not launch.
##
## Dependencies are passed explicitly (no globals): the settlement->province map,
## a {province_id: ProvinceData} lookup, and the world collections
## QuestSeedSelector.select_province_seeds consumes.
static func resolve_arrival(
		pc: L5RCharacterData,
		settlement_province_map: Dictionary,
		provinces_by_id: Dictionary,
		insurgencies: Array,
		wall_statuses: Dictionary,
		bloodspeaker_cells: Array,
		seed: int,
		spiritual_events: Array = []) -> Dictionary:
	var empty: Dictionary = {
		"arrived": false, "province_id": -1,
		"active_seeds": [], "auto_seeds": [], "engageable_seeds": [],
	}
	# PC-only. NPCs never enter the ASCII map (hard constraint).
	if not PcSystem.is_valid_pc(pc):
		return empty

	var current: int = province_for_location(pc.physical_location, settlement_province_map)

	# No province change since the last run -> not an arrival. (Covers "still in the
	# same province" and "still logged out".)
	if current == pc.last_arrival_province_id:
		return {
			"arrived": false, "province_id": current,
			"active_seeds": [], "auto_seeds": [], "engageable_seeds": [],
		}

	# Logged out (or unknown settlement): record -1 so the next login into ANY
	# province re-fires as a fresh arrival. Not an arrival itself.
	if current < 0:
		pc.last_arrival_province_id = -1
		return empty

	# Province changed but its ProvinceData was not supplied — a caller/data gap.
	# Do NOT consume the transition: leave last_arrival_province_id unchanged so the
	# arrival re-fires on the next run once the province data is available.
	var province: ProvinceData = provinces_by_id.get(current)
	if province == null:
		return {
			"arrived": false, "province_id": current,
			"active_seeds": [], "auto_seeds": [], "engageable_seeds": [],
		}

	# Arrival in a new, valid province — record it (so it does not re-fire next run)
	# and classify that province's active seeds (s56.19).
	pc.last_arrival_province_id = current
	var active_seeds: Array = QuestSeedSelector.select_province_seeds(
		province, insurgencies, wall_statuses, bloodspeaker_cells, seed, spiritual_events)
	return {
		"arrived": true,
		"province_id": current,
		"active_seeds": active_seeds,
		"auto_seeds": MissionEntryController.get_auto_launch_seeds(active_seeds),
		"engageable_seeds": MissionEntryController.get_engageable_seeds(active_seeds),
	}
