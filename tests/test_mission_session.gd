class_name TestMissionSession
extends GutTest
## Tests for MissionSession — pure data container bridging MissionBuilder and UI.

# -- Helpers -------------------------------------------------------------------

func _make_province(terrain: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = 1
	p.terrain_type = terrain
	p.province_taint_level = 0.0
	p.stability = 50.0
	return p


func _make_result() -> Dictionary:
	var p   := _make_province(Enums.TerrainType.PLAINS)
	var sd  := {
		"seed_type":    RosterCompositionSystem.SEED_RONIN_BANDIT,
		"strength":     1,
		"options":      {},
		"roster_ready": true,
	}
	return MissionBuilder.assemble(p, [], sd, "session_test")


# -- from_builder() ------------------------------------------------------------

func test_from_builder_map_not_null():
	var session := MissionSession.from_builder(_make_result())
	assert_not_null(session.map)


func test_from_builder_placements_populated():
	var session := MissionSession.from_builder(_make_result())
	assert_false(session.placements == null)


func test_from_builder_entry_pos_is_vector2i():
	var session := MissionSession.from_builder(_make_result())
	assert_true(session.entry_pos is Vector2i)


func test_from_builder_default_water_ring():
	var session := MissionSession.from_builder(_make_result())
	assert_eq(session.water_ring, 3)


func test_from_builder_custom_water_ring():
	var session := MissionSession.from_builder(_make_result(), 4)
	assert_eq(session.water_ring, 4)


func test_from_builder_default_perception():
	var session := MissionSession.from_builder(_make_result())
	assert_eq(session.perception, 3)


func test_from_builder_custom_perception():
	var session := MissionSession.from_builder(_make_result(), 3, 5)
	assert_eq(session.perception, 5)


func test_from_builder_objective_slots_is_array():
	var session := MissionSession.from_builder(_make_result())
	assert_true(session.objective_slots is Array)


func test_from_builder_environment_is_dict():
	var session := MissionSession.from_builder(_make_result())
	assert_true(session.environment is Dictionary)


# -- is_valid() ----------------------------------------------------------------

func test_is_valid_true_for_normal_result():
	var session := MissionSession.from_builder(_make_result())
	assert_true(session.is_valid())


func test_is_valid_false_when_map_null():
	var session := MissionSession.new()
	session.map = null
	assert_false(session.is_valid())


func test_is_valid_false_when_entry_on_wall():
	var session := MissionSession.from_builder(_make_result())
	# Force entry_pos onto a wall tile for validation check.
	var walled_x := 0
	var walled_y := 0
	# Find a wall tile (map edges are walls in most templates).
	for y in range(session.map.height):
		for x in range(session.map.width):
			if not MovementSystem.is_passable(session.map.get_tile(x, y)):
				walled_x = x
				walled_y = y
				break
		if walled_x > 0 or walled_y > 0:
			break
	session.entry_pos = Vector2i(walled_x, walled_y)
	assert_false(session.is_valid())


# -- fov_modifier() -----------------------------------------------------------

func test_fov_modifier_returns_zero_for_clear_weather():
	var session := MissionSession.from_builder(_make_result())
	assert_eq(session.fov_modifier(), 0)


func test_fov_modifier_returns_int():
	var session := MissionSession.from_builder(_make_result())
	assert_true(session.fov_modifier() is int)


# -- is_sortie() --------------------------------------------------------------

func test_is_sortie_false_for_standard_seed():
	var session := MissionSession.from_builder(_make_result())
	assert_false(session.is_sortie())


func test_is_sortie_true_for_wall_sortie():
	var p := _make_province(Enums.TerrainType.MOUNTAINS)
	var sd := {
		"seed_type":    RosterCompositionSystem.SEED_WALL_SORTIE,
		"strength":     1,
		"options":      {},
		"roster_ready": true,
	}
	var result := MissionBuilder.assemble(p, [], sd, "sortie_session")
	var session := MissionSession.from_builder(result)
	assert_true(session.is_sortie())
