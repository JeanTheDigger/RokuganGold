extends Galaxy
class_name GalaxyTest

const CanonSystemTestData = preload("res://scripts/data/canon_systems_test.gd")


func _get_test_systems() -> Array[Dictionary]:
	return CanonSystemTestData.get_preset_systems(CanonSystemTestData.PRESET_TEST_GALAXY_PREPATCH7)

func _generate_galaxy() -> void:
	_clear_visuals()
	_reset_graph()
	var main_ids: Array[int] = _create_canon_main_systems()
	_build_canon_highways(main_ids)
	_build_visuals()
	_setup_camera_to_fit_map()
	_ensure_all_nodes_connected(main_ids)
	_ensure_graph_connected()


func _update_map_bounds_from_viewport() -> void:
	var systems: Array[Dictionary] = _get_test_systems()
	if not systems.is_empty():
		var min_pos: Vector2 = Vector2(INF, INF)
		var max_pos: Vector2 = Vector2(-INF, -INF)
		for row_v in systems:
			var row: Dictionary = row_v as Dictionary
			var point: Vector2 = _to_map_position(row.get("position") as Vector2)
			min_pos.x = minf(min_pos.x, point.x)
			min_pos.y = minf(min_pos.y, point.y)
			max_pos.x = maxf(max_pos.x, point.x)
			max_pos.y = maxf(max_pos.y, point.y)
		_map_min = min_pos - Vector2.ONE * CANON_PADDING
		_map_max = max_pos + Vector2.ONE * CANON_PADDING
		return

	super._update_map_bounds_from_viewport()


func _create_canon_main_systems() -> Array[int]:
	var main_ids: Array[int] = []
	for row_v in _get_test_systems():
		var row: Dictionary = row_v as Dictionary
		var system_planets: Array = row.get("planets", []) as Array
		var primary_planet: Dictionary = {}
		if not system_planets.is_empty():
			primary_planet = system_planets[0] as Dictionary
		var id: int = _create_system(
			_to_map_position(row.get("position") as Vector2),
			true,
			CANON_MAIN_RADIUS,
			-1,
			String(row.get("system_name")),
			String(primary_planet.get("planetary_type", "Unknown")),
			row.get("lanes") as Array,
			String(row.get("region", "Unknown Regions"))
		)
		main_ids.append(id)
	return main_ids
