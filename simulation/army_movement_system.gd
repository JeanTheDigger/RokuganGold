class_name ArmyMovementSystem
## Army movement on the world map per GDD s11.7a. Sub-tile movement,
## terrain costs, forced march, visibility, and battle trigger detection.
## Pure static functions. Caller owns all state dictionaries.


# -- Movement Terrain Types (for sub-tiles) ------------------------------------

enum MovementTerrain {
	PLAINS,
	RIVER_DELTA,
	FOREST,
	HEAVY_HILLS,
	MOUNTAINS,
}


# -- Seasons (for movement modifiers) -----------------------------------------

enum Season { SPRING, SUMMER, AUTUMN, WINTER }


# -- Constants -----------------------------------------------------------------

const BASE_TERRAIN_COST: Dictionary = {
	MovementTerrain.PLAINS: 1,
	MovementTerrain.RIVER_DELTA: 1,
	MovementTerrain.FOREST: 2,
	MovementTerrain.HEAVY_HILLS: 2,
	MovementTerrain.MOUNTAINS: 3,
}

const RIVER_CROSSING_COST: int = 1
const SPRING_RIVER_CROSSING_COST: int = 2
const WINTER_MULTIPLIER: int = 2
const FORCED_MARCH_REDUCTION: int = 1
const FORCED_MARCH_MORALE_COST: int = 5
const MIN_CROSSING_TIME: int = 1

const PASSIVE_VISIBILITY_RANGE: int = 1
const SCOUT_VISIBILITY_RANGE: int = 2


# -- Army State Factory ----------------------------------------------------------

static func create_army_state(
	army_id: int,
	current_sub_tile: int,
	owning_clan: String,
) -> Dictionary:
	return {
		"army_id": army_id,
		"current_sub_tile": current_sub_tile,
		"destination_sub_tile": -1,
		"path": [] as Array[int],
		"days_remaining": 0,
		"is_moving": false,
		"owning_clan": owning_clan,
		"has_scouts": false,
		"forced_march": false,
	}


# -- Terrain Cost Calculation ---------------------------------------------------

static func get_terrain_cost(
	terrain: MovementTerrain,
	season: Season,
	has_river_crossing: bool,
) -> int:
	var base: int = BASE_TERRAIN_COST.get(terrain, 1)

	if season == Season.WINTER:
		base *= WINTER_MULTIPLIER

	var river_cost: int = 0
	if has_river_crossing:
		if season == Season.SPRING:
			river_cost = SPRING_RIVER_CROSSING_COST
		else:
			river_cost = RIVER_CROSSING_COST

	return base + river_cost


static func get_forced_march_cost(
	terrain: MovementTerrain,
	season: Season,
	has_river_crossing: bool,
	days_to_save: int,
) -> Dictionary:
	var base_cost: int = get_terrain_cost(terrain, season, has_river_crossing)
	var max_saveable: int = maxi(base_cost - MIN_CROSSING_TIME, 0)
	var actual_save: int = mini(days_to_save, max_saveable)
	var morale_cost: int = actual_save * FORCED_MARCH_MORALE_COST
	var travel_days: int = base_cost - actual_save

	return {
		"travel_days": travel_days,
		"days_saved": actual_save,
		"morale_cost": morale_cost,
		"max_saveable": max_saveable,
	}


# -- Path Computation -----------------------------------------------------------

static func compute_path_cost(
	path: Array[int],
	sub_tile_data: Dictionary,
	season: Season,
) -> int:
	var total: int = 0
	for tile_id: int in path:
		var data: Dictionary = sub_tile_data.get(tile_id, {})
		var terrain: MovementTerrain = data.get("terrain", MovementTerrain.PLAINS) as MovementTerrain
		var river: bool = data.get("has_river_crossing", false)
		total += get_terrain_cost(terrain, season, river)
	return total


# -- Movement Commands -----------------------------------------------------------

static func begin_march(
	army_state: Dictionary,
	path: Array[int],
	sub_tile_data: Dictionary,
	season: Season,
	forced_march: bool = false,
) -> Dictionary:
	if path.is_empty():
		return {"success": false, "reason": "empty_path"}

	var total_days: int = 0
	var total_morale_cost: int = 0
	for tile_id: int in path:
		var data: Dictionary = sub_tile_data.get(tile_id, {})
		var terrain: MovementTerrain = data.get("terrain", MovementTerrain.PLAINS) as MovementTerrain
		var river: bool = data.get("has_river_crossing", false)
		var cost: int = get_terrain_cost(terrain, season, river)

		if forced_march:
			var saveable: int = maxi(cost - MIN_CROSSING_TIME, 0)
			total_morale_cost += saveable * FORCED_MARCH_MORALE_COST
			cost = maxi(cost - saveable, MIN_CROSSING_TIME)

		total_days += cost

	army_state["destination_sub_tile"] = path[path.size() - 1]
	army_state["path"] = path.duplicate()
	army_state["days_remaining"] = total_days
	army_state["is_moving"] = true
	army_state["forced_march"] = forced_march

	return {
		"success": true,
		"total_days": total_days,
		"morale_cost": total_morale_cost,
		"destination": path[path.size() - 1],
	}


static func cancel_march(army_state: Dictionary) -> Dictionary:
	var was_moving: bool = army_state["is_moving"]
	army_state["destination_sub_tile"] = -1
	army_state["path"] = [] as Array[int]
	army_state["days_remaining"] = 0
	army_state["is_moving"] = false
	army_state["forced_march"] = false
	return {"cancelled": was_moving}


# -- Daily Tick Processing -------------------------------------------------------

static func process_movement_tick(army_state: Dictionary) -> Dictionary:
	if not army_state["is_moving"]:
		return {"moved": false, "arrived": false}

	army_state["days_remaining"] -= 1

	if army_state["days_remaining"] <= 0:
		army_state["current_sub_tile"] = army_state["destination_sub_tile"]
		army_state["destination_sub_tile"] = -1
		army_state["path"] = [] as Array[int]
		army_state["is_moving"] = false
		army_state["forced_march"] = false
		return {
			"moved": true,
			"arrived": true,
			"arrived_at": army_state["current_sub_tile"],
		}

	return {"moved": true, "arrived": false, "days_remaining": army_state["days_remaining"]}


# -- Battle Trigger Detection ----------------------------------------------------

static func check_battle_trigger(
	arriving_army: Dictionary,
	enemy_armies: Array[Dictionary],
) -> Dictionary:
	if not arriving_army.get("arrived_at", -1) >= 0:
		# Use the current sub-tile if not a fresh arrival
		pass

	var tile: int = arriving_army.get(
		"arrived_at", arriving_army.get("current_sub_tile", -1),
	)
	if tile < 0:
		return {"battle_triggered": false}

	var enemies_at_tile: Array[int] = []
	for enemy: Dictionary in enemy_armies:
		if enemy.get("current_sub_tile", -1) == tile:
			enemies_at_tile.append(enemy["army_id"])

	if enemies_at_tile.is_empty():
		return {"battle_triggered": false}

	return {
		"battle_triggered": true,
		"sub_tile": tile,
		"enemy_army_ids": enemies_at_tile,
	}


# -- Visibility ------------------------------------------------------------------

static func get_visible_sub_tiles(
	current_sub_tile: int,
	adjacency: Dictionary,
	has_scouts: bool,
) -> Array[int]:
	var visible: Array[int] = [current_sub_tile]

	var adjacent: Array = adjacency.get(current_sub_tile, [])
	for tile: int in adjacent:
		if tile not in visible:
			visible.append(tile)

	if has_scouts:
		var ring_1: Array[int] = visible.duplicate()
		for tile: int in ring_1:
			if tile == current_sub_tile:
				continue
			var next_ring: Array = adjacency.get(tile, [])
			for far_tile: int in next_ring:
				if far_tile not in visible:
					visible.append(far_tile)

	return visible


static func detect_enemy_armies(
	visible_tiles: Array[int],
	all_armies: Array[Dictionary],
	own_clan: String,
) -> Array[Dictionary]:
	var detected: Array[Dictionary] = []
	for army: Dictionary in all_armies:
		if army.get("owning_clan", "") == own_clan:
			continue
		if army.get("current_sub_tile", -1) in visible_tiles:
			detected.append({
				"army_id": army["army_id"],
				"sub_tile": army["current_sub_tile"],
				"detected_by": "passive" if true else "scout",
			})
	return detected


# -- Retreat ---------------------------------------------------------------------

static func retreat_army(
	army_state: Dictionary,
	previous_sub_tile: int,
) -> void:
	army_state["current_sub_tile"] = previous_sub_tile
	army_state["destination_sub_tile"] = -1
	army_state["path"] = [] as Array[int]
	army_state["days_remaining"] = 0
	army_state["is_moving"] = false
	army_state["forced_march"] = false


# -- Army Dissolution Check ------------------------------------------------------

static func should_dissolve(
	current_health: int,
	starting_health: int,
) -> bool:
	if starting_health <= 0:
		return true
	var ratio: float = float(current_health) / float(starting_health)
	return ratio <= 0.20
