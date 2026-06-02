class_name GreaterZoneData
extends Resource
## Data model for a Greater Zone — the top tier of the zone hierarchy (s4.4.1).
##
## Greater Zones are pure navigation containers — they never have an ASCII map.
## Three types: province sub-tiles (matching the army movement grid), settlement
## containers, and travel routes between sub-tiles or settlements.
##
## Children are NavigationZoneData IDs for large settlements, or directly
## LesserZoneData IDs for simple settlements (village, small town) that skip
## the middle tier.

# -- Identity ----------------------------------------------------------------

@export var zone_id: String = ""
@export var zone_name: String = ""
# GreaterZoneType — determines the structural role of this zone.
@export var zone_type: int = Enums.GreaterZoneType.SETTLEMENT

# -- Type-specific identity --------------------------------------------------

# SETTLEMENT: the settlement this Greater Zone represents.
@export var settlement_id: String = ""

# PROVINCE_SUBTILE: which province and which sub-tile index (0-based, up to 4).
@export var province_id: String = ""
@export var subtile_index: int = -1

# -- Children ----------------------------------------------------------------

# IDs of child NavigationZoneData or (for simple settlements) LesserZoneData.
@export var child_zone_ids: Array[String] = []

# -- Navigation --------------------------------------------------------------

# Exits to sibling Greater Zones. Each entry: {direction: String, target_zone_id: String}
# Direction for travel routes: compass directions. For sub-tile movement: army-grid
# directions ("N", "S", "E", "W"). For settlement exits: "travel_north" etc.
@export var exits: Array = []

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
