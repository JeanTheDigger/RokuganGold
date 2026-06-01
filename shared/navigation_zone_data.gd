class_name NavigationZoneData
extends Resource
## Data model for a Navigation Zone — the middle tier of the zone hierarchy (s4.4.1 v564).
##
## Navigation Zones group Lesser Zones (and nested Navigation Zones) within a settlement
## or wilderness area. They may have an ASCII map (outdoor walkable spaces: streets, plazas,
## harbour fronts, castle courtyards) or be pure MUD navigation containers.
##
## zone_event_log is only populated when has_ascii_map = true — actions on a street
## log here; actions inside a child building log to that building's LesserZoneData.

const EVENT_LOG_RETENTION_DAYS: int = 90

# -- Identity ----------------------------------------------------------------

@export var zone_id: String = ""
@export var zone_name: String = ""
# NavigationZoneType — determines structural role and ASCII map style if applicable.
@export var zone_type: int = Enums.NavigationZoneType.STREET
# Parent is a GreaterZoneData.zone_id (or another NavigationZoneData.zone_id for nesting).
@export var parent_zone_id: String = ""

# -- Children ----------------------------------------------------------------

# IDs of child LesserZoneData or nested NavigationZoneData objects.
@export var child_zone_ids: Array[String] = []

# -- Navigation --------------------------------------------------------------

# Exits to sibling Navigation Zones under the same parent.
# Each entry: {direction: String, target_zone_id: String}
@export var exits: Array = []

# -- ASCII map (optional) ----------------------------------------------------

# True for walkable outdoor spaces (streets, plazas). False for pure MUD containers.
@export var has_ascii_map: bool = false

# Only meaningful when has_ascii_map = true.
# ZoneSubtype used if this Navigation Zone generates an ASCII map of its own.
@export var zone_subtype: int = Enums.ZoneSubtype.MARKET_STREET

# Persistent tile overrides for this Navigation Zone's ASCII map.
@export var map_deltas: Dictionary = {}

# Event log — only populated when has_ascii_map = true.
# Each entry: {character_id: int, action_id: String, ic_day: int, x: int, y: int}
@export var zone_event_log: Array = []

# -- Child zone helpers ------------------------------------------------------

func add_child_zone(child_id: String) -> void:
	if not child_id in child_zone_ids:
		child_zone_ids.append(child_id)


func remove_child_zone(child_id: String) -> void:
	child_zone_ids.erase(child_id)


func has_child_zone(child_id: String) -> bool:
	return child_id in child_zone_ids

# -- Exit helpers ------------------------------------------------------------

func add_exit(direction: String, target_zone_id: String) -> void:
	for e: Dictionary in exits:
		if e.get("direction", "") == direction:
			e["target_zone_id"] = target_zone_id
			return
	exits.append({"direction": direction, "target_zone_id": target_zone_id})


func get_exit(direction: String) -> String:
	for e: Dictionary in exits:
		if e.get("direction", "") == direction:
			return e.get("target_zone_id", "")
	return ""


func remove_exit(direction: String) -> void:
	for i: int in range(exits.size() - 1, -1, -1):
		if exits[i].get("direction", "") == direction:
			exits.remove_at(i)
			return

# -- Delta helpers (only valid when has_ascii_map = true) --------------------

func apply_delta(x: int, y: int, tile: int) -> void:
	if not has_ascii_map:
		return
	map_deltas["%d,%d" % [x, y]] = tile


func remove_delta(x: int, y: int) -> void:
	map_deltas.erase("%d,%d" % [x, y])


func has_delta(x: int, y: int) -> bool:
	return map_deltas.has("%d,%d" % [x, y])

# -- Event log helpers (only valid when has_ascii_map = true) ----------------

func log_event(
	character_id: int,
	action_id: String,
	ic_day: int,
	x: int = -1,
	y: int = -1,
) -> void:
	if not has_ascii_map:
		return
	zone_event_log.append({
		"character_id": character_id,
		"action_id": action_id,
		"ic_day": ic_day,
		"x": x,
		"y": y,
	})


func purge_old_events(current_ic_day: int) -> void:
	var cutoff: int = current_ic_day - EVENT_LOG_RETENTION_DAYS
	var kept: Array = []
	for e: Dictionary in zone_event_log:
		if e.get("ic_day", 0) >= cutoff:
			kept.append(e)
	zone_event_log = kept


func get_events_for_character(character_id: int) -> Array:
	var result: Array = []
	for e: Dictionary in zone_event_log:
		if e.get("character_id", -1) == character_id:
			result.append(e)
	return result
