class_name BloodspeakerNetworkSystem
## Empire-wide Bloodspeaker cult cell network per GDD s56.14.
## Manages cell distribution, state transitions, propagation, activation
## triggers, and the Hydra Rule. Active cells feed into InsurgencySystem
## (s11.11 Maho Cult type) for detection and suppression.


# =============================================================================
# Constants — World Generation (s56.14.2)
# =============================================================================

const CELL_COUNT_MIN: int = 25
const CELL_COUNT_MAX: int = 35
const DORMANT_FRACTION_MIN: float = 0.75
const DORMANT_FRACTION_MAX: float = 0.80
const ACTIVE_STRENGTH_MIN: int = 2
const ACTIVE_STRENGTH_MAX: int = 4
const MAHO_CULT_BASE_CONCEALMENT: int = 8


# =============================================================================
# Constants — Activation Triggers (s56.14.5)
# =============================================================================

const ACTIVATION_CHANCE_PTL: float = 0.20
const ACTIVATION_CHANCE_INSTABILITY: float = 0.15
const ACTIVATION_CHANCE_BASE: float = 0.02
const PTL_ACTIVATION_THRESHOLD: float = 3.0

# Dormant PTL contribution (s56.14.6)
const DORMANT_PTL_PER_SEASON: float = 0.25


# =============================================================================
# Constants — Propagation (s56.14.3)
# =============================================================================

const PROPAGATION_STRENGTH_THRESHOLD: int = 4
const PROPAGATION_CHANCE: float = 0.10
const PROPAGATION_MIN_DISTANCE: int = 3


# =============================================================================
# Constants — Hydra Rule (s56.14.4)
# =============================================================================

const HYDRA_EARLY_SEASONS: int = 4
const HYDRA_LATE_SEASONS: int = 8
const HYDRA_EARLY_CHANCE: float = 0.60
const HYDRA_LATE_CHANCE: float = 0.90


# =============================================================================
# Constants — Sleeper Aftermath (s56.14.4)
# =============================================================================

const SLEEPER_AFTERMATH_EARLY_BONUS: float = 0.15
const SLEEPER_AFTERMATH_LATE_BONUS: float = 0.30


# =============================================================================
# World Generation — Initial Distribution (s56.14.2)
# =============================================================================

static func generate_initial_cells(
	provinces: Dictionary,
	dice: DiceEngine,
	next_cell_id: Array,
	current_season: int,
	next_insurgency_id: Array = [1],
) -> Dictionary:
	var cell_count: int = dice.rand_int_range(CELL_COUNT_MIN, CELL_COUNT_MAX)
	var dormant_fraction: float = DORMANT_FRACTION_MIN + dice.randf() * (DORMANT_FRACTION_MAX - DORMANT_FRACTION_MIN)
	var dormant_count: int = int(cell_count * dormant_fraction)

	var province_ids: Array = provinces.keys()
	if province_ids.is_empty():
		return {"cells": [], "insurgencies": []}

	var selected_provinces: Array = _random_select_provinces(province_ids, cell_count, dice)

	var cells: Array = []
	var insurgencies: Array = []
	for i: int in range(selected_provinces.size()):
		var pid: int = selected_provinces[i]
		var cell := BloodspeakerCellData.new()
		cell.cell_id = next_cell_id[0]
		next_cell_id[0] += 1
		cell.province_id = pid
		cell.season_created = current_season
		cell.concealment = MAHO_CULT_BASE_CONCEALMENT
		cell.leader_id = -1

		if i < dormant_count:
			cell.state = Enums.BloodspeakerCellState.DORMANT
			cell.strength = 1
		else:
			cell.state = Enums.BloodspeakerCellState.ACTIVE
			cell.strength = dice.rand_int_range(ACTIVE_STRENGTH_MIN, ACTIVE_STRENGTH_MAX)
			var ins: InsurgencyData = _create_insurgency_from_cell(
				cell, next_insurgency_id[0], current_season,
			)
			next_insurgency_id[0] += 1
			cell.insurgency_id = ins.insurgency_id
			insurgencies.append(ins)

		cells.append(cell)

	return {"cells": cells, "insurgencies": insurgencies}


static func _random_select_provinces(
	province_ids: Array,
	count: int,
	dice: DiceEngine,
) -> Array:
	var selected: Array = []
	if province_ids.is_empty():
		return selected
	for _i: int in range(count):
		var idx: int = dice.rand_int_range(0, province_ids.size() - 1)
		selected.append(province_ids[idx])
	return selected


# =============================================================================
# Seasonal Processing (s56.14.3–s56.14.6)
# =============================================================================

static func process_season(
	cells: Array,
	provinces: Dictionary,
	insurgencies: Array,
	next_insurgency_id: Array,
	dice: DiceEngine,
	current_season: int,
	next_cell_id: Array,
	maho_provinces: Array = [],
) -> Dictionary:
	var new_cells: Array = []
	var new_insurgencies: Array = []
	var events: Array = []
	var ptl_contributions: Dictionary = {}

	for cell: BloodspeakerCellData in cells:
		if cell.state == Enums.BloodspeakerCellState.DESTROYED:
			continue

		if cell.state == Enums.BloodspeakerCellState.DORMANT:
			cell.seasons_dormant += 1

			var ptl_delta: float = ptl_contributions.get(cell.province_id, 0.0)
			ptl_contributions[cell.province_id] = ptl_delta + DORMANT_PTL_PER_SEASON

			var activation_result: Dictionary = _check_activation(cell, provinces, maho_provinces, dice)
			if activation_result["activated"]:
				cell.state = Enums.BloodspeakerCellState.ACTIVE
				cell.seasons_active = 0
				cell.strength = maxi(cell.strength, 1)
				cell.concealment = MAHO_CULT_BASE_CONCEALMENT
				events.append({
					"event": "cell_activated",
					"cell_id": cell.cell_id,
					"province_id": cell.province_id,
					"trigger": activation_result["trigger"],
				})
				var ins: InsurgencyData = _create_insurgency_from_cell(
					cell, next_insurgency_id[0], current_season,
				)
				cell.insurgency_id = ins.insurgency_id
				next_insurgency_id[0] += 1
				new_insurgencies.append(ins)

		elif cell.state == Enums.BloodspeakerCellState.ACTIVE:
			cell.seasons_active += 1

			if cell.strength >= PROPAGATION_STRENGTH_THRESHOLD:
				var prop_roll: float = dice.randf()
				if prop_roll < PROPAGATION_CHANCE:
					var dormant_target: BloodspeakerCellData = _find_activatable_dormant(cells, cell.cell_id)
					if dormant_target != null:
						dormant_target.state = Enums.BloodspeakerCellState.ACTIVE
						dormant_target.seasons_active = 0
						dormant_target.strength = maxi(dormant_target.strength, 1)
						dormant_target.concealment = MAHO_CULT_BASE_CONCEALMENT
						cell.propagation_count += 1
						var d_ins: InsurgencyData = _create_insurgency_from_cell(
							dormant_target, next_insurgency_id[0], current_season,
						)
						dormant_target.insurgency_id = d_ins.insurgency_id
						next_insurgency_id[0] += 1
						new_insurgencies.append(d_ins)
						events.append({
							"event": "cell_activated_by_instruction",
							"source_cell_id": cell.cell_id,
							"target_cell_id": dormant_target.cell_id,
							"province_id": dormant_target.province_id,
						})
					else:
						var target_pid: int = _select_propagation_target(
							cell, provinces, cells, new_cells, dice,
						)
						if target_pid >= 0:
							cell.state = Enums.BloodspeakerCellState.PROPAGATING
							cell.propagation_count += 1
							cell.strength = maxi(cell.strength - 1, 1)

							var new_cell := BloodspeakerCellData.new()
							new_cell.cell_id = next_cell_id[0]
							next_cell_id[0] += 1
							new_cell.province_id = target_pid
							new_cell.state = Enums.BloodspeakerCellState.DORMANT
							new_cell.strength = 1
							new_cell.concealment = MAHO_CULT_BASE_CONCEALMENT
							new_cell.parent_cell_id = cell.cell_id
							new_cell.season_created = current_season
							new_cell.establishment_path = Enums.CellEstablishmentPath.AGENT_INFILTRATION

							new_cells.append(new_cell)
							events.append({
								"event": "cell_propagated",
								"parent_cell_id": cell.cell_id,
								"new_cell_id": new_cell.cell_id,
								"target_province_id": target_pid,
							})

							cell.state = Enums.BloodspeakerCellState.ACTIVE

		elif cell.state == Enums.BloodspeakerCellState.PROPAGATING:
			cell.state = Enums.BloodspeakerCellState.ACTIVE
			cell.seasons_active += 1

	return {
		"new_cells": new_cells,
		"new_insurgencies": new_insurgencies,
		"events": events,
		"ptl_contributions": ptl_contributions,
	}


# =============================================================================
# Activation Trigger Checks (s56.14.5)
# =============================================================================

static func _check_activation(
	cell: BloodspeakerCellData,
	provinces: Dictionary,
	maho_provinces: Array,
	dice: DiceEngine,
) -> Dictionary:
	var province: ProvinceData = provinces.get(cell.province_id)
	if province == null:
		return {"activated": false, "trigger": ""}

	if cell.province_id in maho_provinces:
		return {"activated": true, "trigger": "named_npc_maho"}

	if province.province_taint_level >= PTL_ACTIVATION_THRESHOLD:
		var roll: float = dice.randf()
		if roll < ACTIVATION_CHANCE_PTL:
			return {"activated": true, "trigger": "ptl_threshold"}

	var tier: Enums.StabilityTier = InsurgencySystem.get_stability_tier(province.stability)
	if tier == Enums.StabilityTier.VOLATILE or tier == Enums.StabilityTier.BROKEN:
		var roll: float = dice.randf()
		if roll < ACTIVATION_CHANCE_INSTABILITY:
			return {"activated": true, "trigger": "instability"}

	var base_roll: float = dice.randf()
	if base_roll < ACTIVATION_CHANCE_BASE:
		return {"activated": true, "trigger": "passage_of_time"}

	return {"activated": false, "trigger": ""}


static func activate_cell_by_instruction(
	cell: BloodspeakerCellData,
	insurgencies: Array,
	next_insurgency_id: Array,
	current_season: int,
) -> Dictionary:
	if cell.state != Enums.BloodspeakerCellState.DORMANT:
		return {"activated": false}
	cell.state = Enums.BloodspeakerCellState.ACTIVE
	cell.seasons_active = 0
	cell.strength = maxi(cell.strength, 1)
	cell.concealment = MAHO_CULT_BASE_CONCEALMENT
	var ins: InsurgencyData = _create_insurgency_from_cell(cell, next_insurgency_id[0], current_season)
	cell.insurgency_id = ins.insurgency_id
	next_insurgency_id[0] += 1
	insurgencies.append(ins)
	return {"activated": true, "insurgency_id": ins.insurgency_id}


# =============================================================================
# Propagation Target Selection (s56.14.3)
# =============================================================================

static func _select_propagation_target(
	cell: BloodspeakerCellData,
	provinces: Dictionary,
	existing_cells: Array,
	new_cells: Array,
	dice: DiceEngine,
) -> int:
	var source_province: ProvinceData = provinces.get(cell.province_id)
	if source_province == null:
		return -1

	var occupied_provinces: Dictionary = {}
	for c: BloodspeakerCellData in existing_cells:
		if c.state != Enums.BloodspeakerCellState.DESTROYED:
			occupied_provinces[c.province_id] = true
	for c: BloodspeakerCellData in new_cells:
		occupied_provinces[c.province_id] = true

	# First pass: prefer different clan territory (GDD s56.14.3)
	var candidates: Array = []
	for pid: int in provinces:
		if pid == cell.province_id:
			continue
		if occupied_provinces.has(pid):
			continue

		var distance: int = _estimate_province_distance(cell.province_id, pid, provinces)
		if distance < PROPAGATION_MIN_DISTANCE:
			continue

		var target: ProvinceData = provinces[pid]
		if target.clan == source_province.clan:
			continue

		candidates.append(pid)

	# Fallback: allow same clan if no cross-clan targets
	if candidates.is_empty():
		for pid: int in provinces:
			if pid == cell.province_id:
				continue
			if occupied_provinces.has(pid):
				continue
			var distance: int = _estimate_province_distance(cell.province_id, pid, provinces)
			if distance < PROPAGATION_MIN_DISTANCE:
				continue
			candidates.append(pid)

	if candidates.is_empty():
		return -1

	# Uniform random selection — equal probability for all valid candidates
	var idx: int = dice.rand_int_range(0, candidates.size() - 1)
	return candidates[idx]


static func _estimate_province_distance(
	from_id: int,
	to_id: int,
	provinces: Dictionary,
) -> int:
	if from_id == to_id:
		return 0
	var visited: Dictionary = {from_id: true}
	var frontier: Array = [from_id]
	var distance: int = 0
	while not frontier.is_empty() and distance < 20:
		distance += 1
		var next_frontier: Array = []
		for pid: int in frontier:
			var prov: ProvinceData = provinces.get(pid)
			if prov == null:
				continue
			for adj_id: int in prov.adjacent_province_ids:
				if adj_id == to_id:
					return distance
				if not visited.has(adj_id):
					visited[adj_id] = true
					next_frontier.append(adj_id)
		frontier = next_frontier
	return 20


# =============================================================================
# Hydra Rule (s56.14.4)
# =============================================================================

static func check_hydra_rule(
	cell: BloodspeakerCellData,
	provinces: Dictionary,
	existing_cells: Array,
	dice: DiceEngine,
	next_cell_id: Array,
	current_season: int,
) -> Dictionary:
	if cell.state != Enums.BloodspeakerCellState.ACTIVE and cell.state != Enums.BloodspeakerCellState.PROPAGATING:
		return {"spawned": false}

	var chance: float = 0.0
	if cell.seasons_active >= HYDRA_LATE_SEASONS:
		chance = HYDRA_LATE_CHANCE
	elif cell.seasons_active >= HYDRA_EARLY_SEASONS:
		chance = HYDRA_EARLY_CHANCE
	else:
		return {"spawned": false}

	var roll: float = dice.randf()
	if roll >= chance:
		return {"spawned": false}

	var target_pid: int = _select_propagation_target(
		cell, provinces, existing_cells, [], dice,
	)
	if target_pid < 0:
		return {"spawned": false}

	var new_cell := BloodspeakerCellData.new()
	new_cell.cell_id = next_cell_id[0]
	next_cell_id[0] += 1
	new_cell.province_id = target_pid
	new_cell.state = Enums.BloodspeakerCellState.DORMANT
	new_cell.strength = 1
	new_cell.concealment = MAHO_CULT_BASE_CONCEALMENT
	new_cell.parent_cell_id = cell.cell_id
	new_cell.season_created = current_season
	new_cell.establishment_path = Enums.CellEstablishmentPath.AGENT_INFILTRATION

	return {
		"spawned": true,
		"new_cell": new_cell,
		"target_province_id": target_pid,
	}


# =============================================================================
# Suppression Integration (s56.14.1 + s11.11)
# =============================================================================

static func on_cell_suppressed(
	cell: BloodspeakerCellData,
	provinces: Dictionary,
	existing_cells: Array,
	dice: DiceEngine,
	next_cell_id: Array,
	current_season: int,
) -> Dictionary:
	var hydra_result: Dictionary = check_hydra_rule(
		cell, provinces, existing_cells,
		dice, next_cell_id, current_season,
	)

	cell.state = Enums.BloodspeakerCellState.DESTROYED

	return {
		"destroyed": true,
		"leader_id": cell.leader_id,
		"hydra_spawned": hydra_result.get("spawned", false),
		"hydra_cell": hydra_result.get("new_cell"),
		"hydra_province_id": hydra_result.get("target_province_id", -1),
	}


# =============================================================================
# Sleeper Aftermath (s56.14.4)
# GDD: "+15% Maho Cult spawn chance" after 4 seasons since suppression,
# "+30% Maho Cult spawn chance" after 8 seasons since suppression.
# =============================================================================

static func get_sleeper_aftermath_bonus(seasons_since_suppression: int) -> float:
	if seasons_since_suppression >= HYDRA_LATE_SEASONS:
		return SLEEPER_AFTERMATH_LATE_BONUS
	elif seasons_since_suppression >= HYDRA_EARLY_SEASONS:
		return SLEEPER_AFTERMATH_EARLY_BONUS
	return 0.0


static func _get_character_province(c: L5RCharacterData, settlement_province_map: Dictionary) -> int:
	if c.physical_location.is_empty():
		return -1
	var loc_id: int = int(c.physical_location)
	return settlement_province_map.get(loc_id, -1)


# =============================================================================
# Helper — Find Dormant Cell for Activation Instruction (s56.14.5)
# =============================================================================

static func _find_activatable_dormant(cells: Array, source_cell_id: int) -> BloodspeakerCellData:
	for cell: BloodspeakerCellData in cells:
		if cell.cell_id == source_cell_id:
			continue
		if cell.state == Enums.BloodspeakerCellState.DORMANT:
			return cell
	return null


# =============================================================================
# Helper — Create Insurgency from Active Cell
# =============================================================================

static func _create_insurgency_from_cell(
	cell: BloodspeakerCellData,
	insurgency_id: int,
	current_season: int,
) -> InsurgencyData:
	var ins := InsurgencyData.new()
	ins.insurgency_id = insurgency_id
	ins.insurgency_type = Enums.InsurgencyType.MAHO_CULT
	ins.province_id = cell.province_id
	ins.strength = cell.strength
	ins.concealment = cell.concealment
	ins.detected = false
	ins.seasons_active = 0
	ins.season_spawned = current_season
	return ins


# =============================================================================
# Query Helpers
# =============================================================================

static func get_active_cells(cells: Array) -> Array:
	var result: Array = []
	for cell: BloodspeakerCellData in cells:
		if cell.state == Enums.BloodspeakerCellState.ACTIVE or cell.state == Enums.BloodspeakerCellState.PROPAGATING:
			result.append(cell)
	return result


static func get_dormant_cells(cells: Array) -> Array:
	var result: Array = []
	for cell: BloodspeakerCellData in cells:
		if cell.state == Enums.BloodspeakerCellState.DORMANT:
			result.append(cell)
	return result


static func get_cells_in_province(cells: Array, province_id: int) -> Array:
	var result: Array = []
	for cell: BloodspeakerCellData in cells:
		if cell.province_id == province_id and cell.state != Enums.BloodspeakerCellState.DESTROYED:
			result.append(cell)
	return result


static func find_cell_by_insurgency(cells: Array, insurgency_id: int) -> BloodspeakerCellData:
	for cell: BloodspeakerCellData in cells:
		if cell.insurgency_id == insurgency_id:
			return cell
	return null


static func count_living_cells(cells: Array) -> int:
	var count: int = 0
	for cell: BloodspeakerCellData in cells:
		if cell.state != Enums.BloodspeakerCellState.DESTROYED:
			count += 1
	return count
