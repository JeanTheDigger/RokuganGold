class_name TravelSystem
## Travel System per GDD s55.29.
## Manages NPC movement between settlements. Characters spend IC days
## traveling based on terrain distance. During travel, context flag is
## TRAVELING and only limited actions are available.
##
## Distance lookup is a placeholder dictionary — when the map is built,
## it plugs in here via set_distance_provider or by populating DISTANCES.


# -- Terrain Travel Costs (days per sub-tile) ---------------------------------

const TERRAIN_COST: Dictionary = {
	"plains": 1,
	"flatlands": 1,
	"coastal": 1,
	"forest": 2,
	"light_hills": 2,
	"hills": 3,
	"mountains": 3,
}

const RIVER_CROSSING_COST: int = 1
const SPRING_RIVER_CROSSING_COST: int = 2

const DEFAULT_TERRAIN_COST: int = 2
const MINIMUM_TRAVEL_DAYS: int = 1


# -- Distance Lookup ----------------------------------------------------------
# Keyed by "origin_id->destination_id", value = travel days.
# Populated at world gen or by map system. Symmetric: A->B == B->A.

static var _distances: Dictionary = {}


static func set_distance(origin: String, destination: String, days: int) -> void:
	var key_ab: String = origin + "->" + destination
	var key_ba: String = destination + "->" + origin
	_distances[key_ab] = days
	_distances[key_ba] = days


static func get_travel_time(origin: String, destination: String) -> int:
	if origin == destination:
		return 0
	var key: String = origin + "->" + destination
	if _distances.has(key):
		return _distances[key]
	return _default_travel_time()


static func _default_travel_time() -> int:
	return 3


static func clear_distances() -> void:
	_distances.clear()


# -- Travel State Management --------------------------------------------------

static func is_traveling(character: L5RCharacterData) -> bool:
	return character.travel_destination != "" and character.travel_days_remaining > 0


static func begin_travel(
	character: L5RCharacterData,
	destination: String,
) -> Dictionary:
	if destination == character.physical_location:
		return {"started": false, "reason": "already_there"}
	if destination.is_empty():
		return {"started": false, "reason": "no_destination"}

	var days: int = get_travel_time(character.physical_location, destination)
	days = maxi(days, MINIMUM_TRAVEL_DAYS)

	character.travel_origin = character.physical_location
	character.travel_destination = destination
	character.travel_days_remaining = days

	return {
		"started": true,
		"origin": character.travel_origin,
		"destination": destination,
		"travel_days": days,
	}


static func change_destination(
	character: L5RCharacterData,
	new_destination: String,
) -> Dictionary:
	if new_destination.is_empty():
		return {"changed": false, "reason": "no_destination"}
	if new_destination == character.travel_destination:
		return {"changed": false, "reason": "same_destination"}

	var current_location: String = character.travel_origin
	if is_traveling(character):
		current_location = _estimate_current_position(character)

	var new_days: int = get_travel_time(current_location, new_destination)
	new_days = maxi(new_days, MINIMUM_TRAVEL_DAYS)

	character.travel_destination = new_destination
	character.travel_days_remaining = new_days

	return {
		"changed": true,
		"new_destination": new_destination,
		"new_travel_days": new_days,
	}


static func _estimate_current_position(character: L5RCharacterData) -> String:
	# While in transit, use origin for distance calculations.
	# When map exists, this can interpolate actual position.
	return character.travel_origin


# -- Daily Tick ---------------------------------------------------------------

static func process_travel_tick(
	characters: Array[L5RCharacterData],
) -> Array:
	var arrivals: Array[Dictionary] = []

	for c: L5RCharacterData in characters:
		if not is_traveling(c):
			continue

		c.travel_days_remaining -= 1

		if c.travel_days_remaining <= 0:
			var result: Dictionary = _arrive(c)
			arrivals.append(result)

	return arrivals


static func _arrive(character: L5RCharacterData) -> Dictionary:
	var origin: String = character.travel_origin
	var destination: String = character.travel_destination

	character.physical_location = destination
	character.travel_destination = ""
	character.travel_days_remaining = 0
	character.travel_origin = ""

	return {
		"character_id": character.character_id,
		"origin": origin,
		"destination": destination,
		"arrived": true,
	}


# -- Cancel Travel ------------------------------------------------------------

static func cancel_travel(character: L5RCharacterData) -> Dictionary:
	if not is_traveling(character):
		return {"cancelled": false, "reason": "not_traveling"}

	var destination: String = character.travel_destination
	character.physical_location = character.travel_origin
	character.travel_destination = ""
	character.travel_days_remaining = 0
	character.travel_origin = ""

	return {
		"cancelled": true,
		"returned_to": character.physical_location,
		"abandoned_destination": destination,
	}


# -- Context Flag Helper ------------------------------------------------------

static func get_context_flag(character: L5RCharacterData) -> Enums.ContextFlag:
	if is_traveling(character):
		return Enums.ContextFlag.TRAVELING
	return Enums.ContextFlag.AT_OWN_HOLDINGS


# -- Forced March (army movement) ---------------------------------------------

const FORCED_MARCH_MORALE_COST: int = 5

static func apply_forced_march(base_days: int) -> Dictionary:
	var reduced: int = maxi(base_days - 1, MINIMUM_TRAVEL_DAYS)
	var days_saved: int = base_days - reduced
	return {
		"travel_days": reduced,
		"morale_cost": days_saved * FORCED_MARCH_MORALE_COST,
	}
