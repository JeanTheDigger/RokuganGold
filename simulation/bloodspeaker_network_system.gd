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

# Placement weights (s56.14.2)
const WEIGHT_BASE: float = 1.0
const WEIGHT_HIGH_POPULATION: float = 3.0
const WEIGHT_ETA_COMMUNITY: float = 2.0
const WEIGHT_SHADOWLANDS_ADJACENT: float = 2.0
const WEIGHT_URBAN_CENTER: float = 2.0
const WEIGHT_LOW_GARRISON: float = 1.5

const HIGH_POPULATION_THRESHOLD: int = 50

# Urban settlement types (provincial capitals and castle towns)
const URBAN_SETTLEMENT_TYPES: Array[int] = [
	Enums.SettlementType.TOWN,
	Enums.SettlementType.CITY,
	Enums.SettlementType.IMPERIAL_CAPITAL,
	Enums.SettlementType.CASTLE,
	Enums.SettlementType.FAMILY_CASTLE,
]


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
# Constants — Leader Selection (s56.14.2)
# =============================================================================

const LEADER_SUSCEPTIBILITY_THRESHOLD: int = 3
const LEADER_TIER1_WEIGHT: int = 5
const LEADER_TIER2_WEIGHT: int = 2
const LEADER_TIER3_WEIGHT: int = 1


# =============================================================================
# World Generation — Initial Distribution (s56.14.2)
# =============================================================================

static func generate_initial_cells(
	provinces: Dictionary,
	settlements: Array,
	characters: Array,
	characters_by_id: Dictionary,
	dice: DiceEngine,
	next_cell_id: Array,
	current_season: int,
	shadowlands_province_ids: Array = [],
) -> Array:
	var cell_count: int = dice.rand_int_range(CELL_COUNT_MIN, CELL_COUNT_MAX)
	var dormant_fraction: float = DORMANT_FRACTION_MIN + dice.randf() * (DORMANT_FRACTION_MAX - DORMANT_FRACTION_MIN)
	var dormant_count: int = int(cell_count * dormant_fraction)
	var active_count: int = cell_count - dormant_count

	var province_weights: Dictionary = _compute_province_weights(provinces, settlements, shadowlands_province_ids)

	var selected_provinces: Array = _weighted_select_provinces(province_weights, cell_count, dice)

	var cells: Array = []
	for i: int in range(selected_provinces.size()):
		var pid: int = selected_provinces[i]
		var cell := BloodspeakerCellData.new()
		cell.cell_id = next_cell_id[0]
		next_cell_id[0] += 1
		cell.province_id = pid
		cell.season_created = current_season
		cell.concealment = MAHO_CULT_BASE_CONCEALMENT

		if i < dormant_count:
			cell.state = Enums.BloodspeakerCellState.DORMANT
			cell.strength = 1
		else:
			cell.state = Enums.BloodspeakerCellState.ACTIVE
			cell.strength = dice.rand_int_range(ACTIVE_STRENGTH_MIN, ACTIVE_STRENGTH_MAX)

		cell.leader_id = _select_cell_leader(pid, characters, characters_by_id, cells, dice)
		if cell.leader_id >= 0:
			var leader: L5RCharacterData = characters_by_id.get(cell.leader_id)
			if leader != null:
				leader.cult_affiliation = true

		cells.append(cell)

	return cells


static func _compute_province_weights(
	provinces: Dictionary,
	settlements: Array,
	shadowlands_province_ids: Array,
) -> Dictionary:
	var settlement_by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if not settlement_by_province.has(s.province_id):
			settlement_by_province[s.province_id] = []
		settlement_by_province[s.province_id].append(s)

	var weights: Dictionary = {}
	for pid: int in provinces:
		var province: ProvinceData = provinces[pid]
		var w: float = WEIGHT_BASE

		var province_settlements: Array = settlement_by_province.get(pid, [])
		var total_pop: int = 0
		var total_garrison: int = 0
		var has_urban: bool = false
		for s: SettlementData in province_settlements:
			total_pop += s.population_pu
			total_garrison += s.garrison_pu
			if s.settlement_type in URBAN_SETTLEMENT_TYPES:
				has_urban = true

		if total_pop >= HIGH_POPULATION_THRESHOLD:
			w += WEIGHT_HIGH_POPULATION

		if has_urban:
			w += WEIGHT_URBAN_CENTER

		if pid in shadowlands_province_ids:
			w += WEIGHT_SHADOWLANDS_ADJACENT

		if total_pop > 0 and total_garrison < total_pop * 0.05:
			w += WEIGHT_LOW_GARRISON

		weights[pid] = w

	return weights


static func _weighted_select_provinces(
	weights: Dictionary,
	count: int,
	dice: DiceEngine,
) -> Array:
	if weights.is_empty():
		return []

	var province_ids: Array = weights.keys()
	var selected: Array = []

	for _i: int in range(count):
		var total_weight: float = 0.0
		for pid: int in province_ids:
			total_weight += weights.get(pid, 0.0)
		if total_weight <= 0.0:
			break

		var roll: float = dice.randf() * total_weight
		var cumulative: float = 0.0
		var chosen_pid: int = province_ids[0]
		for pid: int in province_ids:
			cumulative += weights.get(pid, 0.0)
			if roll <= cumulative:
				chosen_pid = pid
				break
		selected.append(chosen_pid)

	return selected


static func _select_cell_leader(
	province_id: int,
	characters: Array,
	characters_by_id: Dictionary,
	existing_cells: Array,
	dice: DiceEngine,
) -> int:
	var already_leaders: Array = []
	for cell: BloodspeakerCellData in existing_cells:
		if cell.leader_id >= 0:
			already_leaders.append(cell.leader_id)

	var candidates: Array = []
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.cult_affiliation:
			continue
		if c.character_id in already_leaders:
			continue
		if c.physical_location.is_empty():
			continue

		var susceptibility: int = InsurgencySystem.compute_susceptibility_maho(c, _get_lord_disposition(c, characters_by_id))
		if susceptibility < LEADER_SUSCEPTIBILITY_THRESHOLD:
			continue
		if InsurgencySystem.is_immune_to_corruption(c):
			continue

		candidates.append({"character": c, "susceptibility": susceptibility})

	if candidates.is_empty():
		return -1

	var tier1: Array = []
	var tier2: Array = []
	var tier3: Array = []
	for entry: Dictionary in candidates:
		var s: int = entry["susceptibility"]
		if s >= 6:
			tier1.append(entry)
		elif s >= 4:
			tier2.append(entry)
		else:
			tier3.append(entry)

	var weighted_pool: Array = []
	for entry: Dictionary in tier1:
		for _w: int in range(LEADER_TIER1_WEIGHT):
			weighted_pool.append(entry["character"].character_id)
	for entry: Dictionary in tier2:
		for _w: int in range(LEADER_TIER2_WEIGHT):
			weighted_pool.append(entry["character"].character_id)
	for entry: Dictionary in tier3:
		for _w: int in range(LEADER_TIER3_WEIGHT):
			weighted_pool.append(entry["character"].character_id)

	if weighted_pool.is_empty():
		return -1

	var idx: int = dice.rand_int_range(0, weighted_pool.size() - 1)
	return weighted_pool[idx]


static func _get_lord_disposition(c: L5RCharacterData, characters_by_id: Dictionary) -> int:
	if c.lord_id < 0:
		return 0
	var lord: L5RCharacterData = characters_by_id.get(c.lord_id)
	if lord == null:
		return 0
	return c.disposition_values.get(str(c.lord_id), 0)


# =============================================================================
# Seasonal Processing (s56.14.3–s56.14.6)
# =============================================================================

static func process_season(
	cells: Array,
	provinces: Dictionary,
	settlements: Array,
	insurgencies: Array,
	next_insurgency_id: Array,
	dice: DiceEngine,
	current_season: int,
	next_cell_id: Array,
	characters: Array = [],
	characters_by_id: Dictionary = {},
	shadowlands_province_ids: Array = [],
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
							cell, provinces, cells, new_cells, settlements,
							shadowlands_province_ids, dice,
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
	settlements: Array,
	shadowlands_province_ids: Array,
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

		var weight: float = _compute_single_province_weight(pid, provinces, settlements, shadowlands_province_ids)
		candidates.append({"province_id": pid, "weight": weight})

	if candidates.is_empty():
		for pid: int in provinces:
			if pid == cell.province_id:
				continue
			if occupied_provinces.has(pid):
				continue
			var distance: int = _estimate_province_distance(cell.province_id, pid, provinces)
			if distance < PROPAGATION_MIN_DISTANCE:
				continue
			var weight: float = _compute_single_province_weight(pid, provinces, settlements, shadowlands_province_ids)
			candidates.append({"province_id": pid, "weight": weight})

	if candidates.is_empty():
		return -1

	var total_weight: float = 0.0
	for c: Dictionary in candidates:
		total_weight += c["weight"]
	if total_weight <= 0.0:
		return candidates[0]["province_id"]

	var roll: float = dice.randf() * total_weight
	var cumulative: float = 0.0
	for c: Dictionary in candidates:
		cumulative += c["weight"]
		if roll <= cumulative:
			return c["province_id"]

	return candidates[candidates.size() - 1]["province_id"]


static func _compute_single_province_weight(
	pid: int,
	provinces: Dictionary,
	settlements: Array,
	shadowlands_province_ids: Array,
) -> float:
	var w: float = WEIGHT_BASE
	var total_pop: int = 0
	var total_garrison: int = 0
	var has_urban: bool = false
	for s: SettlementData in settlements:
		if s.province_id != pid:
			continue
		total_pop += s.population_pu
		total_garrison += s.garrison_pu
		if s.settlement_type in URBAN_SETTLEMENT_TYPES:
			has_urban = true

	if total_pop >= HIGH_POPULATION_THRESHOLD:
		w += WEIGHT_HIGH_POPULATION
	if has_urban:
		w += WEIGHT_URBAN_CENTER
	if pid in shadowlands_province_ids:
		w += WEIGHT_SHADOWLANDS_ADJACENT
	if total_pop > 0 and total_garrison < total_pop * 0.05:
		w += WEIGHT_LOW_GARRISON
	return w


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
	settlements: Array,
	dice: DiceEngine,
	next_cell_id: Array,
	current_season: int,
	shadowlands_province_ids: Array = [],
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
		cell, provinces, existing_cells, [], settlements,
		shadowlands_province_ids, dice,
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
	settlements: Array,
	dice: DiceEngine,
	next_cell_id: Array,
	current_season: int,
	shadowlands_province_ids: Array = [],
) -> Dictionary:
	var hydra_result: Dictionary = check_hydra_rule(
		cell, provinces, existing_cells, settlements,
		dice, next_cell_id, current_season, shadowlands_province_ids,
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
# Sleeper Aftermath Integration (s56.14.4)
# =============================================================================

static func get_sleeper_spawn_bonus(
	province_id: int,
	characters: Array,
	settlement_province_map: Dictionary,
) -> float:
	var bonus: float = 0.0
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if not c.cult_affiliation:
			continue
		var char_province: int = _get_character_province(c, settlement_province_map)
		if char_province != province_id:
			continue
		bonus += 0.15
	return minf(bonus, 0.30)


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
