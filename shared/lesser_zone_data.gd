class_name LesserZoneData
extends Resource
## Data model for a Lesser Zone — the leaf-node play space in the zone hierarchy (s4.4.1).
##
## Every Lesser Zone has a MUD text window and an ASCII map. The ASCII map is generated
## deterministically from the seed (never stored) — only map_deltas persist physical
## changes. The zone_event_log records named-character actions for one IC season.
##
## Parent is either a NavigationZoneData or a GreaterZoneData (simple settlements
## with 2-3 Lesser Zones may skip the Navigation Zone tier entirely).

# Minimum event-log retention in IC days (shortest season, s4.4.1 "one IC season").
const EVENT_LOG_RETENTION_DAYS: int = 90

# -- Identity ----------------------------------------------------------------

@export var zone_id: String = ""
@export var zone_name: String = ""
# ZoneSubtype determines which ASCII map generator algorithm runs.
@export var zone_subtype: int = Enums.ZoneSubtype.SHRINE_CLEARING
# Parent is a NavigationZoneData.zone_id or GreaterZoneData.zone_id.
@export var parent_zone_id: String = ""

# -- Navigation --------------------------------------------------------------

# Each entry: {direction: String, target_zone_id: String}
# Directions: "N", "S", "E", "W", "NE", "NW", "SE", "SW", "up" (to parent), "down" (rare)
@export var exits: Array = []

# -- Event log ---------------------------------------------------------------

# Each entry: {character_id: int, action_id: String, ic_day: int, x: int, y: int}
# x/y are the tile coordinates of the action; -1 if not position-specific.
# Consumed by: Kitsuki's Eye, magistrate investigations, Secret System detection,
# insurgency detection. Purge after one IC season via purge_old_events().
@export var zone_event_log: Array = []

# -- Persistent map changes --------------------------------------------------

# Key: "x,y" string  Value: Enums.TileType int
# Overrides the deterministically generated tile. Persists between sessions.
# Applied on top of the generated map via AsciiMapData.set_delta().
@export var map_deltas: Dictionary = {}

# -- Map generation ----------------------------------------------------------

# Build a fresh AsciiMapData for this zone using settlement_name as part of the
# seed, then apply all stored deltas. Returns a new AsciiMapData each call.
func build_map(settlement_name: String = "") -> AsciiMapData:
	var map: AsciiMapData = AsciiMapGenerator.generate(
		zone_id, zone_name, zone_subtype, settlement_name
	)
	for key: String in map_deltas:
		var parts: Array = key.split(",")
		if parts.size() == 2:
			map.set_delta(parts[0].to_int(), parts[1].to_int(), map_deltas[key])
	return map

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

# -- Delta helpers -----------------------------------------------------------

func apply_delta(x: int, y: int, tile: int) -> void:
	map_deltas["%d,%d" % [x, y]] = tile


func remove_delta(x: int, y: int) -> void:
	map_deltas.erase("%d,%d" % [x, y])


func has_delta(x: int, y: int) -> bool:
	return map_deltas.has("%d,%d" % [x, y])

# -- Zone flag matrix (s57.36 SUPREMACY CLAUSE) -----------------------------
# Returns the flag Dictionary for a given ZoneSubtype.
# Keys: performance_permitted, wall_art_slot, displayed_art_slot, fusuma_slot,
#       tokonoma, bonsai_display_slot, garden_eligible, shrine_eligible.
static func get_zone_flags(subtype: int) -> Dictionary:
	var F: Dictionary = {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	}
	match subtype:
		# --- Castle interior zones (s57.36.3) ---
		Enums.ZoneSubtype.OHIROMA:
			F["performance_permitted"] = true
			F["wall_art_slot"] = true
			F["displayed_art_slot"] = true
			F["fusuma_slot"] = true
		Enums.ZoneSubtype.ENKAI_HALL:
			F["performance_permitted"] = true
			F["wall_art_slot"] = true
			F["displayed_art_slot"] = true
			F["fusuma_slot"] = true
		Enums.ZoneSubtype.AUDIENCE_CHAMBER:
			F["wall_art_slot"] = true
			F["displayed_art_slot"] = true
			F["fusuma_slot"] = true
			F["tokonoma"] = true
		Enums.ZoneSubtype.CHASHITSU:
			F["performance_permitted"] = true
			F["wall_art_slot"] = true
			F["tokonoma"] = true
		Enums.ZoneSubtype.GUEST_WING:
			F["wall_art_slot"] = true
			F["fusuma_slot"] = true
			F["tokonoma"] = true
		Enums.ZoneSubtype.LORD_QUARTERS:
			F["wall_art_slot"] = true
			F["displayed_art_slot"] = true
			F["fusuma_slot"] = true
			F["tokonoma"] = true
		Enums.ZoneSubtype.WAR_COUNCIL_ROOM:
			pass  # all false
		Enums.ZoneSubtype.DOJO:
			pass  # all false
		Enums.ZoneSubtype.OUTER_COURTYARD:
			F["performance_permitted"] = true
			F["bonsai_display_slot"] = true
			F["garden_eligible"] = true
		Enums.ZoneSubtype.TSUBONIWA:
			F["tokonoma"] = true
			F["bonsai_display_slot"] = true
			F["garden_eligible"] = true
		Enums.ZoneSubtype.CASTLE_SHRINE:
			F["wall_art_slot"] = true
			F["shrine_eligible"] = true
		# --- Urban district zones (s57.36.4) ---
		Enums.ZoneSubtype.MARKET_STREET:
			F["performance_permitted"] = true
		Enums.ZoneSubtype.RESIDENTIAL_QUARTER:
			pass  # all false
		Enums.ZoneSubtype.TEMPLE_GROUNDS:
			F["performance_permitted"] = true
			F["wall_art_slot"] = true
			F["displayed_art_slot"] = true
			F["fusuma_slot"] = true
			F["bonsai_display_slot"] = true
			F["garden_eligible"] = true
			F["shrine_eligible"] = true
		Enums.ZoneSubtype.PLEASURE_QUARTER:
			F["performance_permitted"] = true
			F["wall_art_slot"] = true
			F["displayed_art_slot"] = true
			F["fusuma_slot"] = true
			F["tokonoma"] = true
		Enums.ZoneSubtype.DOCKS_WATERFRONT:
			pass  # all false
		Enums.ZoneSubtype.POOR_QUARTER:
			pass  # all false
		Enums.ZoneSubtype.GOVERNMENT_QUARTER:
			F["wall_art_slot"] = true
		# --- Wilderness zones (s57.36.5) ---
		Enums.ZoneSubtype.SHRINE_CLEARING:
			F["shrine_eligible"] = true
		# ROAD, FOREST_PATH, MOUNTAIN_PASS, RIVER_CROSSING, FARMLAND, WALL_TOWER: all false
	return F

# -- Event log helpers -------------------------------------------------------

func log_event(
	character_id: int,
	action_id: String,
	ic_day: int,
	x: int = -1,
	y: int = -1,
) -> void:
	zone_event_log.append({
		"character_id": character_id,
		"action_id": action_id,
		"ic_day": ic_day,
		"x": x,
		"y": y,
	})


# Removes entries older than one IC season. Call at season boundaries.
func purge_old_events(current_ic_day: int) -> void:
	var cutoff: int = current_ic_day - EVENT_LOG_RETENTION_DAYS
	var kept: Array = []
	for e: Dictionary in zone_event_log:
		if e.get("ic_day", 0) >= cutoff:
			kept.append(e)
	zone_event_log = kept


# Returns all events involving a specific character.
func get_events_for_character(character_id: int) -> Array:
	var result: Array = []
	for e: Dictionary in zone_event_log:
		if e.get("character_id", -1) == character_id:
			result.append(e)
	return result
