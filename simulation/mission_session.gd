class_name MissionSession
## Pure data container for an active ASCII map mission.
## Produced by MissionBuilder.assemble(); consumed by the UI layer to
## initialise AsciiMapView and begin player interaction.
##
## The UI layer is responsible for wiring this into AsciiMapView:
##   view.set_map(session.map, entry.x, entry.y,
##                session.perception, session.fov_modifier, session.water_ring)
##   view.set_entities(session.placements)

var map:             AsciiMapData
var placements:      Variant   # Array (standard) | {"friendly":Array,"enemy":Array} (sortie)
var objective_slots: Array
var seed_dict:       Dictionary
var roster:          Dictionary
var environment:     Dictionary
var entry_pos:       Vector2i

## Character stats needed to boot the view.
var water_ring:      int = 3
var perception:      int = 3

# Derived convenience accessors -----------------------------------------------

func fov_modifier() -> int:
	return environment.get("fov_modifier", 0)


func is_sortie() -> bool:
	return placements is Dictionary and placements.has("friendly")


## Constructs a MissionSession from a MissionBuilder.assemble() result dict.
## water_ring and perception are the PC's stat block values.
static func from_builder(
		result: Dictionary,
		water_ring: int = 3,
		perception: int = 3) -> MissionSession:
	var s := MissionSession.new()
	s.map             = result.get("map")
	s.placements      = result.get("placements", [])
	s.objective_slots = result.get("objective_slots", [])
	s.seed_dict       = result.get("seed_dict", {})
	s.roster          = result.get("roster", {})
	s.environment     = result.get("environment", {})
	s.entry_pos       = result.get("entry_pos", Vector2i(1, 1))
	s.water_ring      = water_ring
	s.perception      = perception
	return s


## Returns true when this session has a valid map and a reachable entry tile.
func is_valid() -> bool:
	if map == null:
		return false
	if not MovementSystem.is_passable(map.get_tile(entry_pos.x, entry_pos.y)):
		return false
	return true
