class_name SupplyTetherSystem
## Supply tether mechanics for armies operating in hostile territory per GDD s11.7.
## Pure static functions. Caller owns all state dictionaries.


# -- Tether State ----------------------------------------------------------------

enum TetherState { SOLID, THREATENED, BROKEN }


# -- Constants -------------------------------------------------------------------

const BASE_GARRISON_ATTACK: int = 3
const BASE_GARRISON_PU: float = 1.0
const PU_STEP: float = 0.5

const UNESCORTED_TN: int = 5
const FULL_CUT_MARGIN: int = 5

const FULL_SUPPLY_FRACTION: float = 1.0
const PARTIAL_SUPPLY_FRACTION: float = 0.5
const NO_SUPPLY_FRACTION: float = 0.0

const STEP_DOWN_FULL_RATE: int = 1
const STEP_DOWN_PARTIAL_RATE: int = 2


# -- Tether Data Factory ---------------------------------------------------------

static func create_tether(
	army_id: int,
	source_province_id: int,
	sub_tile_path: Array[int],
) -> Dictionary:
	var node_states: Dictionary = {}
	for tile_id: int in sub_tile_path:
		node_states[tile_id] = {
			"state": TetherState.SOLID,
			"escort_company_id": -1,
			"escort_returning": false,
			"escort_return_ticks": 0,
		}
	return {
		"army_id": army_id,
		"source_province_id": source_province_id,
		"sub_tile_path": sub_tile_path,
		"node_states": node_states,
		"overall_state": TetherState.SOLID,
		"rice_deprivation_tick": 0,
		"arms_deprivation_tick": 0,
		"partial_tick_accumulator_rice": 0,
		"partial_tick_accumulator_arms": 0,
	}


# -- Garrison Raid Mechanics -----------------------------------------------------

static func compute_garrison_attack(garrison_pu: float) -> int:
	var pu_diff: float = garrison_pu - BASE_GARRISON_PU
	var steps: int = roundi(pu_diff / PU_STEP)
	return maxi(BASE_GARRISON_ATTACK + steps, 0)


static func compute_raid_tn(escort_defense: int) -> int:
	return UNESCORTED_TN + escort_defense


static func resolve_garrison_raid(
	dice: DiceEngine,
	garrison_pu: float,
	escort_defense: int,
) -> Dictionary:
	var attack: int = compute_garrison_attack(garrison_pu)
	var tn: int = compute_raid_tn(escort_defense)
	var roll: int = dice.rand_int_range(1, 10)
	var total: int = roll + attack
	var margin: int = total - tn

	var result: TetherState
	if margin < 0:
		result = TetherState.SOLID
	elif margin < FULL_CUT_MARGIN:
		result = TetherState.THREATENED
	else:
		result = TetherState.BROKEN

	return {
		"roll": roll,
		"attack": attack,
		"total": total,
		"tn": tn,
		"margin": margin,
		"result": result,
	}


# -- Sub-Tile Threat Processing --------------------------------------------------

static func get_escort_defense(
	tether: Dictionary,
	tile_id: int,
	companies_by_id: Dictionary,
) -> int:
	var node: Dictionary = tether["node_states"][tile_id]
	var escort_id: int = node["escort_company_id"]
	if escort_id < 0 or node["escort_returning"]:
		return 0
	if not companies_by_id.has(escort_id):
		return 0
	var company: MilitaryUnitData.CompanyData = companies_by_id[escort_id]
	return company.defense


static func process_tether_tick(
	dice: DiceEngine,
	tether: Dictionary,
	garrisons_on_path: Dictionary,
	enemy_armies_on_path: Array[int],
	companies_by_id: Dictionary,
) -> Dictionary:
	var raid_results: Array[Dictionary] = []
	var worst_state: TetherState = TetherState.SOLID
	var partial_count: int = 0

	for tile_id: int in tether["sub_tile_path"]:
		var node: Dictionary = tether["node_states"][tile_id]

		if node["escort_returning"]:
			node["escort_return_ticks"] -= 1
			if node["escort_return_ticks"] <= 0:
				node["escort_returning"] = false
				node["escort_company_id"] = -1

		if tile_id in enemy_armies_on_path:
			node["state"] = TetherState.BROKEN
			worst_state = TetherState.BROKEN
			raid_results.append({
				"tile_id": tile_id,
				"cause": "enemy_army",
				"result": TetherState.BROKEN,
			})
			continue

		if garrisons_on_path.has(tile_id):
			var garrison_pu: float = garrisons_on_path[tile_id]
			var escort_def: int = get_escort_defense(tether, tile_id, companies_by_id)
			var raid: Dictionary = resolve_garrison_raid(dice, garrison_pu, escort_def)
			node["state"] = raid["result"]
			raid_results.append({
				"tile_id": tile_id,
				"cause": "garrison_raid",
				"garrison_pu": garrison_pu,
				"escort_defense": escort_def,
				"roll": raid["roll"],
				"total": raid["total"],
				"tn": raid["tn"],
				"margin": raid["margin"],
				"result": raid["result"],
			})

			if raid["result"] == TetherState.BROKEN:
				worst_state = TetherState.BROKEN
			elif raid["result"] == TetherState.THREATENED:
				partial_count += 1
		else:
			node["state"] = TetherState.SOLID

	if worst_state != TetherState.BROKEN and partial_count >= 2:
		worst_state = TetherState.BROKEN
	elif worst_state != TetherState.BROKEN and partial_count == 1:
		worst_state = TetherState.THREATENED

	tether["overall_state"] = worst_state

	return {
		"overall_state": worst_state,
		"raid_results": raid_results,
		"partial_count": partial_count,
	}


# -- Supply Flow -----------------------------------------------------------------

static func compute_supply_fraction(tether_state: TetherState) -> float:
	match tether_state:
		TetherState.SOLID:
			return FULL_SUPPLY_FRACTION
		TetherState.THREATENED:
			return PARTIAL_SUPPLY_FRACTION
		TetherState.BROKEN:
			return NO_SUPPLY_FRACTION
	return NO_SUPPLY_FRACTION


static func is_in_friendly_territory(
	army_location_id: int,
	friendly_province_ids: Array[int],
) -> bool:
	return army_location_id in friendly_province_ids


# -- Escort Management ----------------------------------------------------------

static func assign_escort(
	tether: Dictionary,
	tile_id: int,
	company_id: int,
) -> Dictionary:
	if not tether["node_states"].has(tile_id):
		return {"success": false, "reason": "tile_not_on_path"}

	var node: Dictionary = tether["node_states"][tile_id]
	if node["escort_company_id"] >= 0 and not node["escort_returning"]:
		return {"success": false, "reason": "already_escorted"}

	node["escort_company_id"] = company_id
	node["escort_returning"] = false
	node["escort_return_ticks"] = 0
	return {"success": true}


static func recall_escort(
	tether: Dictionary,
	tile_id: int,
) -> Dictionary:
	if not tether["node_states"].has(tile_id):
		return {"success": false, "reason": "tile_not_on_path"}

	var node: Dictionary = tether["node_states"][tile_id]
	if node["escort_company_id"] < 0:
		return {"success": false, "reason": "no_escort"}

	node["escort_returning"] = true
	node["escort_return_ticks"] = 1
	return {"success": true, "company_id": node["escort_company_id"]}


# -- Deprivation Tracking -------------------------------------------------------

static func advance_deprivation(
	tether: Dictionary,
	overall_state: TetherState,
) -> Dictionary:
	var rice_advanced: bool = false
	var arms_advanced: bool = false

	if overall_state == TetherState.BROKEN:
		tether["rice_deprivation_tick"] += 1
		tether["arms_deprivation_tick"] += 1
		tether["partial_tick_accumulator_rice"] = 0
		tether["partial_tick_accumulator_arms"] = 0
		rice_advanced = true
		arms_advanced = true
	elif overall_state == TetherState.THREATENED:
		tether["partial_tick_accumulator_rice"] += 1
		tether["partial_tick_accumulator_arms"] += 1
		if tether["partial_tick_accumulator_rice"] >= 2:
			tether["rice_deprivation_tick"] += 1
			tether["partial_tick_accumulator_rice"] = 0
			rice_advanced = true
		if tether["partial_tick_accumulator_arms"] >= 2:
			tether["arms_deprivation_tick"] += 1
			tether["partial_tick_accumulator_arms"] = 0
			arms_advanced = true
	elif overall_state == TetherState.SOLID:
		tether["partial_tick_accumulator_rice"] = 0
		tether["partial_tick_accumulator_arms"] = 0

	return {
		"rice_tick": tether["rice_deprivation_tick"],
		"arms_tick": tether["arms_deprivation_tick"],
		"rice_advanced": rice_advanced,
		"arms_advanced": arms_advanced,
	}


# -- Step-Down Recovery ----------------------------------------------------------

static func process_step_down_recovery(
	tether: Dictionary,
	overall_state: TetherState,
) -> Dictionary:
	if overall_state == TetherState.BROKEN:
		return {"rice_recovered": false, "arms_recovered": false}

	var rice_recovered: bool = false
	var arms_recovered: bool = false

	if overall_state == TetherState.SOLID:
		if tether["rice_deprivation_tick"] > 0:
			tether["rice_deprivation_tick"] -= STEP_DOWN_FULL_RATE
			tether["rice_deprivation_tick"] = maxi(tether["rice_deprivation_tick"], 0)
			rice_recovered = true
		if tether["arms_deprivation_tick"] > 0:
			tether["arms_deprivation_tick"] -= STEP_DOWN_FULL_RATE
			tether["arms_deprivation_tick"] = maxi(tether["arms_deprivation_tick"], 0)
			arms_recovered = true
		tether["partial_tick_accumulator_rice"] = 0
		tether["partial_tick_accumulator_arms"] = 0
	elif overall_state == TetherState.THREATENED:
		tether["partial_tick_accumulator_rice"] += 1
		if tether["partial_tick_accumulator_rice"] >= STEP_DOWN_PARTIAL_RATE:
			if tether["rice_deprivation_tick"] > 0:
				tether["rice_deprivation_tick"] -= 1
				tether["rice_deprivation_tick"] = maxi(tether["rice_deprivation_tick"], 0)
				rice_recovered = true
			tether["partial_tick_accumulator_rice"] = 0
		tether["partial_tick_accumulator_arms"] += 1
		if tether["partial_tick_accumulator_arms"] >= STEP_DOWN_PARTIAL_RATE:
			if tether["arms_deprivation_tick"] > 0:
				tether["arms_deprivation_tick"] -= 1
				tether["arms_deprivation_tick"] = maxi(tether["arms_deprivation_tick"], 0)
				arms_recovered = true
			tether["partial_tick_accumulator_arms"] = 0

	return {"rice_recovered": rice_recovered, "arms_recovered": arms_recovered}


# -- Supply Source ---------------------------------------------------------------

static func get_supply_source_provinces(
	lord_province_ids: Array[int],
	compelled_province_ids: Array[int],
	shared_province_ids: Array[int],
) -> Array[int]:
	var sources: Array[int] = lord_province_ids.duplicate()
	for pid: int in compelled_province_ids:
		if pid not in sources:
			sources.append(pid)
	for pid: int in shared_province_ids:
		if pid not in sources:
			sources.append(pid)
	return sources


# -- Full Tick Orchestrator ------------------------------------------------------

static func process_supply_tick(
	dice: DiceEngine,
	tether: Dictionary,
	garrisons_on_path: Dictionary,
	enemy_armies_on_path: Array[int],
	companies_by_id: Dictionary,
) -> Dictionary:
	var tick_result: Dictionary = process_tether_tick(
		dice, tether, garrisons_on_path, enemy_armies_on_path, companies_by_id,
	)
	var overall: TetherState = tick_result["overall_state"] as TetherState

	var dep_result: Dictionary
	if overall == TetherState.SOLID and (
		tether["rice_deprivation_tick"] > 0 or tether["arms_deprivation_tick"] > 0
	):
		dep_result = process_step_down_recovery(tether, overall)
	elif overall != TetherState.SOLID:
		dep_result = advance_deprivation(tether, overall)
	else:
		dep_result = {
			"rice_tick": 0,
			"arms_tick": 0,
			"rice_advanced": false,
			"arms_advanced": false,
		}

	var supply_fraction: float = compute_supply_fraction(overall)

	return {
		"overall_state": overall,
		"supply_fraction": supply_fraction,
		"raid_results": tick_result["raid_results"],
		"partial_count": tick_result["partial_count"],
		"rice_deprivation_tick": tether["rice_deprivation_tick"],
		"arms_deprivation_tick": tether["arms_deprivation_tick"],
		"deprivation": dep_result,
	}
