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

# -- Otosan Uchi district governance (s2.3.23) -------------------------------
# These fields are only meaningful for the Imperial Capital's district zones
# (CITY_DISTRICT / EKOHIKEI_DISTRICT / FORBIDDEN_CITY). They stay inert
# (default sentinels) for every other Navigation Zone in the world.

# Population units allocated to this district; generates Koku independently
# (s2.3.23 District Economics). 0 = not an Otosan Uchi district.
@export var district_pu: int = 0
# Permanent internal district identifier (Sentaku name). Governors may rename a
# Toshisoto district for flavour, but this name never changes (s2.3.23).
@export var sentaku_name: String = ""
# Enums.AccessLayer (TOSHISOTO / EKOHIKEI / FORBIDDEN_CITY). -1 = not gated.
@export var access_layer: int = -1
# Governor clan-preference convention for appointments (s2.3.23). Not a hard gate.
@export var clan_preference: Array[String] = []
# Current Governor's character_id; -1 = vacant (district under Sentaku authority).
@export var zone_lord_id: int = -1
# True for the 15 governed Otosan Uchi districts (Toshisoto + Ekohikei); false for
# the Forbidden City (no Governor) and every non-capital zone. Distinguishes a
# vacant governed seat from a district that simply never has a Governor (s2.3.23).
@export var has_governor: bool = false
# Per-district Stability (Governor scope) — distinct from province-wide stability.
@export var district_stability: float = 100.0
# Crime incidents recorded in this district during the current IC season. Drives
# the Sentaku Governor performance review's crime-rate weight (s2.3.23). Reset at
# each seasonal review; incremented when crime attribution to districts is wired
# (district economics). 0 = no incidents this season.
@export var district_crime_count: int = 0

# Consecutive IC seasons this district's Stability has stayed below the revolt
# crisis floor (s2.3.23 district unrest → s11.11 PEASANT_REVOLT). Reset to 0 the
# moment Stability recovers above the floor, or when a revolt spawns. Owner-locked
# 2026-06-15: 3 consecutive seasons below 25 breeds a revolt.
@export var district_unrest_seasons: int = 0
# insurgency_id of this district's currently-active PEASANT_REVOLT, or -1. Used to
# dedup (one active district revolt at a time); cleared once that revolt is
# suppressed (no longer present/strong in active_insurgencies).
@export var district_revolt_insurgency_id: int = -1

# Fraction of this district's seasonal Koku the Governor retains (the remainder
# flows to the Emperor's stockpile), set via SET_TAX_RATE per GDD s2.3.23. Defaults
# to 0.30 (the s4.3.7 provincial 30%); clamped to [0.10, 0.50] when a Governor sets
# it. Persists on the district across Governors.
@export var district_tax_retention: float = 0.30


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
