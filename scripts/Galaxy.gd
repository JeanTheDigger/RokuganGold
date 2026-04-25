extends Node2D
class_name Galaxy

signal planet_selected(planet_name: String)
signal planet_double_clicked(planet_name: String)

# Small helper node to draw system circles.
class SystemDot:
	extends Node2D

	var radius: float = 8.0
	var color: Color = Color.WHITE
	var idle_fleet_count: int = 0
	var moving_fleet_count: int = 0
	var moving_min_arrival_day: int = -1

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		var total_fleets: int = idle_fleet_count + moving_fleet_count
		if total_fleets <= 0:
			return
		var display_count: int = mini(total_fleets, 5)
		var marker_radius: float = maxf(1.8, radius * 0.20)
		var orbit_radius: float = radius + marker_radius + 1.5
		for index in range(display_count):
			var angle: float = -PI * 0.5 + (float(index) / maxf(1.0, float(display_count))) * PI * 0.85
			var marker_position: Vector2 = Vector2(cos(angle), sin(angle)) * orbit_radius
			var marker_color: Color = Color(0.2, 0.95, 1.0, 1.0) if index < moving_fleet_count else Color(1.0, 0.9, 0.35, 1.0)
			var heading: Vector2 = marker_position.normalized()
			if heading.length_squared() <= 0.000001:
				heading = Vector2.UP
			var right: Vector2 = heading.orthogonal().normalized()
			var tip: Vector2 = marker_position + heading * (marker_radius * 1.35)
			var left: Vector2 = marker_position - heading * (marker_radius * 0.70) + right * (marker_radius * 0.95)
			var base_right: Vector2 = marker_position - heading * (marker_radius * 0.70) - right * (marker_radius * 0.95)
			draw_colored_polygon(PackedVector2Array([tip, left, base_right]), marker_color)
		if total_fleets > 5:
			draw_string(ThemeDB.fallback_font, Vector2(radius + 4.0, -radius - 2.0), "+%d" % [total_fleets - 5], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.92, 0.96, 0.95))

const CanonSystemData = preload("res://scripts/data/canon_systems.gd")
const CanonSpacelaneData = preload("res://scripts/data/canon_spacelanes.gd")
const GalacticNameGenerator = preload("res://scripts/data/galactic_name_generator.gd")

const MAIN_MIN_COUNT: int = 5
const MAIN_MAX_COUNT: int = 10
const MAIN_MIN_RADIUS: float = 10.0
const MAIN_MAX_RADIUS: float = 14.0
const BRANCH_MIN_RADIUS: float = 6.0
const BRANCH_MAX_RADIUS: float = 8.0
const MAIN_MIN_SPACING: float = 80.0
const BRANCH_PARENT_MIN_DISTANCE: float = 70.0
const BRANCH_PARENT_MAX_DISTANCE: float = 220.0
const MAX_BRANCH_DEPTH: int = 3
const NON_MAIN_BRANCH_CONTINUE_CHANCE: float = 0.88
const LANE_SYSTEM_SPAWN_CHANCE: float = 0.60
const LANE_SYSTEM_INSERT_CHANCE: float = 0.20
const LANE_SYSTEM_MIN_T: float = 0.25
const LANE_SYSTEM_MAX_T: float = 0.75
const LANE_BRANCH_OFFSET_MIN: float = 16.0
const LANE_BRANCH_OFFSET_MAX: float = 56.0
const BRANCH_POSITION_SAMPLES: int = 14
const EMPTY_SPACE_NEARBY_RADIUS: float = 180.0
const EMPTY_SPACE_TARGET_NEIGHBORS: int = 5
const EMPTY_SPACE_BRANCH_BONUS: float = 0.25
const EMPTY_SPACE_DISTANCE_WEIGHT: float = 0.80
const HYPERLANE_AVOID_WEIGHT: float = 0.55
const DIRECTIONAL_EMPTY_WEIGHT: float = 0.60
const OFFSHOOT_BRANCH_CHANCE: float = 0.24
const OFFSHOOT_DISTANCE_MIN_MULTIPLIER: float = 1.35
const OFFSHOOT_DISTANCE_MAX_MULTIPLIER: float = 1.85
const OFFLANE_EMPTY_BIAS: float = 0.20
const MAP_PADDING: float = 120.0
const CANON_PADDING: float = 300.0
const CANON_MAIN_RADIUS: float = 11.0

const CAMERA_ZOOM_MIN: float = 0.35
@export var search_focus_zoom: float = 0.70

const MAIN_COLOR := Color(0.93, 0.93, 0.98)
const BRANCH_COLOR := Color(0.75, 0.85, 1.0)
const HIGHWAY_COLOR := Color(0.0, 0.95, 1.0, 1.0)
const NORMAL_LANE_COLOR := Color(0.6, 0.6, 0.65, 1.0)

var rng := RandomNumberGenerator.new()
var _name_generator: GalacticNameGenerator = GalacticNameGenerator.new()

var systems_by_id: Dictionary = {}  # id -> {position: Vector2, radius: float, ...}
var adjacency: Dictionary = {}      # id -> Array[int]
var edges: Dictionary = {}          # "a|b" -> {"a": int, "b": int, "highway": bool}

var _next_system_id: int = 0
var _highway_nodes: Array[int] = []
var _map_min: Vector2 = Vector2.ZERO
var _map_max: Vector2 = Vector2.ZERO
var _camera_bounds_min: Vector2 = Vector2.ZERO
var _camera_bounds_max: Vector2 = Vector2.ZERO
var _selected_planet_id: int = -1

@onready var systems_node: Node2D = $Systems
@onready var lanes_node: Node2D = $Lanes
@onready var camera: Camera2D = get_viewport().get_camera_2d()


func _ready() -> void:
	rng.seed = Time.get_ticks_msec()
	var viewport := get_viewport()
	if not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_update_map_bounds_from_viewport()
	_generate_galaxy()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			_select_planet_from_screen(mouse_button_event.position, mouse_button_event.double_click)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	_update_map_bounds_from_viewport()
	_clamp_camera_to_map()

func _generate_galaxy() -> void:
	_clear_visuals()
	_reset_graph()
	var main_ids: Array[int] = _create_canon_main_systems()
	_build_canon_highways(main_ids)
	_generate_hyperspace_lane_systems()
	_connect_non_highway_mains(main_ids)

	for main_id in main_ids:
		if rng.randf() <= 0.70:
			_generate_branches(main_id, 1)

	_ensure_all_nodes_connected(main_ids)
	_ensure_graph_connected()
	_build_visuals()
	_setup_camera_to_fit_map()

func _clear_visuals() -> void:
	for child in systems_node.get_children():
		child.queue_free()
	for child in lanes_node.get_children():
		child.queue_free()

func _reset_graph() -> void:
	systems_by_id.clear()
	adjacency.clear()
	edges.clear()
	_next_system_id = 0
	_highway_nodes.clear()
	_selected_planet_id = -1

func _update_map_bounds_from_viewport() -> void:
	if not CanonSystemData.SYSTEMS.is_empty():
		var min_pos: Vector2 = Vector2(INF, INF)
		var max_pos: Vector2 = Vector2(-INF, -INF)
		for row_v in CanonSystemData.SYSTEMS:
			var row: Dictionary = row_v as Dictionary
			var point: Vector2 = _to_map_position(row.get("position") as Vector2)
			min_pos.x = minf(min_pos.x, point.x)
			min_pos.y = minf(min_pos.y, point.y)
			max_pos.x = maxf(max_pos.x, point.x)
			max_pos.y = maxf(max_pos.y, point.y)
		_map_min = min_pos - Vector2.ONE * CANON_PADDING
		_map_max = max_pos + Vector2.ONE * CANON_PADDING
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var half_w: float = maxf(320.0, viewport_size.x * 0.5 - MAP_PADDING)
	var half_h: float = maxf(220.0, viewport_size.y * 0.5 - MAP_PADDING)
	_map_min = Vector2(-half_w, -half_h)
	_map_max = Vector2(half_w, half_h)

func _create_canon_main_systems() -> Array[int]:
	var main_ids: Array[int] = []
	for row_v in CanonSystemData.SYSTEMS:
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
			str(row.get("system_name")),
			str(primary_planet.get("planetary_type", "Unknown")),
			row.get("lanes") as Array,
			str(row.get("region", "Unknown Regions"))
		)
		main_ids.append(id)
	return main_ids


func _to_map_position(source_position: Vector2) -> Vector2:
	return Vector2(source_position.x, -source_position.y)

func _build_canon_highways(main_ids: Array[int]) -> void:
	var systems_by_name: Dictionary = {}
	for id in main_ids:
		var system_data: Dictionary = systems_by_id[id] as Dictionary
		var system_name: String = str(system_data.get("name", ""))
		systems_by_name[_system_lookup_key(system_name)] = id

	var lane_to_nodes: Dictionary = {}
	for id in main_ids:
		var data: Dictionary = systems_by_id[id] as Dictionary
		for lane_v in data.get("lanes", []):
			var lane: String = str(lane_v).strip_edges()
			if lane.is_empty():
				continue
			if not lane_to_nodes.has(lane):
				lane_to_nodes[lane] = [] as Array[int]
			(lane_to_nodes[lane] as Array[int]).append(id)

	for lane_v in lane_to_nodes.keys():
		var lane: String = str(lane_v)
		var node_ids: Array[int] = lane_to_nodes[lane] as Array[int]
		if node_ids.size() < 2:
			continue

		var route: Dictionary = CanonSpacelaneData.get_lane_route(lane)
		var starts_at: int = int(systems_by_name.get(_system_lookup_key(str(route.get("begins", ""))), -1))
		var ends_at: int = int(systems_by_name.get(_system_lookup_key(str(route.get("closes", ""))), -1))
		var path: Array[int] = _build_lane_path(node_ids, starts_at, ends_at)

		for i in range(path.size() - 1):
			if _can_add_edge(path[i], path[i + 1]):
				_add_edge(path[i], path[i + 1], true)
			else:
				_add_forced_edge(path[i], path[i + 1], true)

func _build_lane_path(node_ids: Array[int], starts_at: int, ends_at: int) -> Array[int]:
	if node_ids.is_empty():
		return []

	var nodes: Array[int] = node_ids.duplicate()
	nodes.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = systems_by_id[a].get("position") as Vector2
		var pb: Vector2 = systems_by_id[b].get("position") as Vector2
		if is_equal_approx(pa.x, pb.x):
			return pa.y < pb.y
		return pa.x < pb.x
	)

	var start_id: int = starts_at if nodes.has(starts_at) else nodes[0]
	var end_id: int = ends_at if nodes.has(ends_at) else nodes[nodes.size() - 1]
	if start_id == end_id:
		return [start_id]

	var path: Array[int] = [start_id]
	var visited: Dictionary = {start_id: true}
	var current_id: int = start_id
	var start_pos: Vector2 = systems_by_id[start_id].get("position") as Vector2
	var end_pos: Vector2 = systems_by_id[end_id].get("position") as Vector2
	var direction: Vector2 = (end_pos - start_pos).normalized()
	if direction.length_squared() <= 0.000001:
		direction = Vector2.RIGHT
	var current_progress: float = direction.dot((systems_by_id[current_id].get("position") as Vector2) - start_pos)

	while path.size() < nodes.size() - 1:
		var current_pos: Vector2 = systems_by_id[current_id].get("position") as Vector2
		var next_id: int = -1
		var best_progress: float = INF
		var best_step: float = INF

		for candidate_id in nodes:
			if visited.has(candidate_id):
				continue
			if candidate_id == end_id:
				continue
			var candidate_pos: Vector2 = systems_by_id[candidate_id].get("position") as Vector2
			var candidate_progress: float = direction.dot(candidate_pos - start_pos)
			if candidate_progress < current_progress - 0.001:
				continue

			var step_distance: float = current_pos.distance_to(candidate_pos)
			if candidate_progress < best_progress - 0.001 or (is_equal_approx(candidate_progress, best_progress) and step_distance < best_step):
				best_progress = candidate_progress
				best_step = step_distance
				next_id = candidate_id

		if next_id == -1:
			break

		path.append(next_id)
		visited[next_id] = true
		current_id = next_id
		current_progress = direction.dot((systems_by_id[current_id].get("position") as Vector2) - start_pos)

	if not visited.has(end_id):
		path.append(end_id)

	return path

func _generate_main_systems() -> Array[int]:
	var target_count: int = rng.randi_range(MAIN_MIN_COUNT, MAIN_MAX_COUNT)
	var main_ids: Array[int] = []
	var attempts: int = 0

	while main_ids.size() < target_count and attempts < 3000:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(_map_min.x, _map_max.x),
			rng.randf_range(_map_min.y, _map_max.y)
		)
		if _is_position_clear_for_main(pos, main_ids):
			var radius: float = rng.randf_range(MAIN_MIN_RADIUS, MAIN_MAX_RADIUS)
			var id: int = _create_system(pos, true, radius, -1)
			main_ids.append(id)

	while main_ids.size() < MAIN_MIN_COUNT:
		var fallback_pos := Vector2(
			rng.randf_range(_map_min.x, _map_max.x),
			rng.randf_range(_map_min.y, _map_max.y)
		)
		var fallback_id: int = _create_system(fallback_pos, true, rng.randf_range(MAIN_MIN_RADIUS, MAIN_MAX_RADIUS), -1)
		main_ids.append(fallback_id)

	return main_ids

func _is_position_clear_for_main(pos: Vector2, main_ids: Array[int]) -> bool:
	for id in main_ids:
		var other_pos: Vector2 = systems_by_id[id].get("position") as Vector2
		if pos.distance_to(other_pos) < MAIN_MIN_SPACING:
			return false
	return true

func _build_highway(main_ids: Array[int]) -> Array[int]:
	var required_nodes: int = maxi(int(ceil(main_ids.size() / 2.0)), 2)
	var selection: Array[int] = main_ids.duplicate()
	selection.shuffle()
	selection = selection.slice(0, required_nodes)

	var path: Array[int] = _find_non_intersecting_path(selection)
	for i in range(path.size() - 1):
		_add_edge(path[i], path[i + 1], true)

	return path

func _find_non_intersecting_path(node_ids: Array[int]) -> Array[int]:
	if node_ids.size() <= 2:
		return node_ids

	var tries: int = 200
	for _i in range(tries):
		var candidate: Array[int] = node_ids.duplicate()
		candidate.shuffle()
		if not _path_has_self_intersection(candidate):
			return candidate

	var fallback: Array[int] = node_ids.duplicate()
	fallback.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = systems_by_id[a].get("position") as Vector2
		var pb: Vector2 = systems_by_id[b].get("position") as Vector2
		if is_equal_approx(pa.x, pb.x):
			return pa.y < pb.y
		return pa.x < pb.x
	)
	return fallback

func _path_has_self_intersection(path: Array[int]) -> bool:
	for i in range(path.size() - 1):
		var a1: Vector2 = systems_by_id[path[i]].get("position") as Vector2
		var a2: Vector2 = systems_by_id[path[i + 1]].get("position") as Vector2
		for j in range(i + 2, path.size() - 1):
			var b1: Vector2 = systems_by_id[path[j]].get("position") as Vector2
			var b2: Vector2 = systems_by_id[path[j + 1]].get("position") as Vector2
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return true
	return false

func _connect_non_highway_mains(main_ids: Array[int]) -> void:
	for id in main_ids:
		if (adjacency[id] as Array).is_empty():
			var nearest: int = _find_nearest_main_with_clear_edge(id, main_ids)
			if nearest != -1:
				_add_edge(id, nearest, false)

func _generate_branches(parent_id: int, depth: int) -> void:
	if depth > MAX_BRANCH_DEPTH:
		return

	var branch_count: int = 0
	var empty_bonus: bool = _is_area_sparse(parent_id)
	if bool(systems_by_id[parent_id].get("is_main")):
		branch_count = rng.randi_range(1, 3)
	else:
		var continue_chance: float = NON_MAIN_BRANCH_CONTINUE_CHANCE
		if empty_bonus:
			continue_chance = minf(0.98, continue_chance + EMPTY_SPACE_BRANCH_BONUS)
		if rng.randf() <= continue_chance:
			branch_count = rng.randi_range(1, 4)

	if empty_bonus and rng.randf() <= 0.55:
		branch_count += 1

	for _i in range(branch_count):
		var branch_pos: Vector2 = _find_branch_position(parent_id)
		var branch_radius: float = rng.randf_range(BRANCH_MIN_RADIUS, BRANCH_MAX_RADIUS)
		var branch_id: int = _create_generated_child_system(branch_pos, false, branch_radius, parent_id)
		if _can_add_edge(parent_id, branch_id):
			_add_edge(parent_id, branch_id, false)
			_generate_branches(branch_id, depth + 1)
		else:
			systems_by_id.erase(branch_id)
			adjacency.erase(branch_id)

func _find_branch_position(parent_id: int) -> Vector2:
	var parent_pos: Vector2 = systems_by_id[parent_id].get("position") as Vector2
	var is_main_parent: bool = bool(systems_by_id[parent_id].get("is_main", false))
	var min_distance: float = BRANCH_PARENT_MIN_DISTANCE
	var max_distance: float = BRANCH_PARENT_MAX_DISTANCE
	if not is_main_parent and rng.randf() <= OFFSHOOT_BRANCH_CHANCE:
		min_distance = BRANCH_PARENT_MAX_DISTANCE * OFFSHOOT_DISTANCE_MIN_MULTIPLIER
		max_distance = BRANCH_PARENT_MAX_DISTANCE * OFFSHOOT_DISTANCE_MAX_MULTIPLIER

	var best_pos: Vector2 = parent_pos
	var best_score: float = -INF
	for _i in range(BRANCH_POSITION_SAMPLES):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(min_distance, max_distance)
		var pos: Vector2 = parent_pos + Vector2.RIGHT.rotated(angle) * dist
		pos.x = clamp(pos.x, _map_min.x, _map_max.x)
		pos.y = clamp(pos.y, _map_min.y, _map_max.y)
		if not _is_position_clear_for_any_system(pos, 30.0):
			continue

		var score: float = _score_branch_candidate(parent_pos, pos, max_distance)
		if score > best_score:
			best_score = score
			best_pos = pos

	if best_score > -INF:
		return best_pos

	for _i in range(60):
		var angle_fallback: float = rng.randf_range(0.0, TAU)
		var dist_fallback: float = rng.randf_range(min_distance, max_distance)
		var pos_fallback: Vector2 = parent_pos + Vector2.RIGHT.rotated(angle_fallback) * dist_fallback
		pos_fallback.x = clamp(pos_fallback.x, _map_min.x, _map_max.x)
		pos_fallback.y = clamp(pos_fallback.y, _map_min.y, _map_max.y)
		if _is_position_clear_for_any_system(pos_fallback, 30.0):
			return pos_fallback
	return parent_pos


func _score_branch_candidate(parent_pos: Vector2, candidate: Vector2, neighborhood_radius: float = BRANCH_PARENT_MAX_DISTANCE) -> float:
	var nearest_system_distance: float = _distance_to_nearest_system(candidate)
	var nearest_lane_distance: float = _distance_to_nearest_highway_segment(candidate)
	var directional_empty_bonus: float = _directional_emptiness_score(parent_pos, candidate, neighborhood_radius)
	return (
		nearest_system_distance * EMPTY_SPACE_DISTANCE_WEIGHT
		+ nearest_lane_distance * HYPERLANE_AVOID_WEIGHT
		+ directional_empty_bonus * DIRECTIONAL_EMPTY_WEIGHT
	)


func _distance_to_nearest_system(pos: Vector2) -> float:
	var nearest: float = INF
	for data_v in systems_by_id.values():
		var data: Dictionary = data_v as Dictionary
		var other_pos: Vector2 = data.get("position") as Vector2
		nearest = minf(nearest, pos.distance_to(other_pos))
	if nearest == INF:
		return 0.0
	return nearest


func _distance_to_nearest_highway_segment(pos: Vector2) -> float:
	var nearest: float = INF
	for edge_data_v in edges.values():
		var edge_data: Dictionary = edge_data_v as Dictionary
		if not bool(edge_data.get("highway", false)):
			continue
		var a: int = int(edge_data.get("a", -1))
		var b: int = int(edge_data.get("b", -1))
		if a == -1 or b == -1 or not systems_by_id.has(a) or not systems_by_id.has(b):
			continue
		var a_pos: Vector2 = systems_by_id[a].get("position") as Vector2
		var b_pos: Vector2 = systems_by_id[b].get("position") as Vector2
		nearest = minf(nearest, _point_to_segment_distance(pos, a_pos, b_pos))

	if nearest == INF:
		return 0.0
	return nearest


func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment: Vector2 = b - a
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(segment) / length_sq, 0.0, 1.0)
	var projected: Vector2 = a + segment * t
	return point.distance_to(projected)


func _directional_emptiness_score(parent_pos: Vector2, candidate: Vector2, neighborhood_radius: float = BRANCH_PARENT_MAX_DISTANCE) -> float:
	var direction: Vector2 = candidate - parent_pos
	if direction.length_squared() <= 0.000001:
		return 0.0
	var direction_normalized: Vector2 = direction.normalized()
	var nearby: int = 0
	for data_v in systems_by_id.values():
		var data: Dictionary = data_v as Dictionary
		var offset: Vector2 = (data.get("position") as Vector2) - parent_pos
		if offset.length_squared() <= 1.0:
			continue
		if offset.length() > neighborhood_radius * 1.35:
			continue
		if direction_normalized.dot(offset.normalized()) >= 0.45:
			nearby += 1
	return maxf(0.0, 7.0 - float(nearby)) * 12.0


func _is_area_sparse(system_id: int) -> bool:
	if not systems_by_id.has(system_id):
		return false
	var center: Vector2 = systems_by_id[system_id].get("position") as Vector2
	var nearby_count: int = 0
	for other_id_v in systems_by_id.keys():
		var other_id: int = int(other_id_v)
		if other_id == system_id:
			continue
		var other_pos: Vector2 = systems_by_id[other_id].get("position") as Vector2
		if center.distance_to(other_pos) <= EMPTY_SPACE_NEARBY_RADIUS:
			nearby_count += 1
	return nearby_count <= EMPTY_SPACE_TARGET_NEIGHBORS

func _is_position_clear_for_any_system(pos: Vector2, min_dist: float) -> bool:
	for id in systems_by_id.keys():
		var other_pos: Vector2 = systems_by_id[id].get("position") as Vector2
		if pos.distance_to(other_pos) < min_dist:
			return false
	return true

func _ensure_all_nodes_connected(main_ids: Array[int]) -> void:
	var all_ids: Array[int] = []
	for system_id in systems_by_id.keys():
		all_ids.append(int(system_id))

	for id in all_ids:
		if (adjacency[id] as Array).is_empty():
			var attach_to: int = _find_nearest_node_with_clear_edge(id, all_ids)
			if attach_to == -1:
				attach_to = _find_nearest_main_with_clear_edge(id, main_ids)
			if attach_to != -1 and attach_to != id:
				_add_edge(id, attach_to, false)

func _ensure_graph_connected() -> void:
	var remaining: Array[int] = []
	for id in systems_by_id.keys():
		remaining.append(int(id))

	if remaining.is_empty():
		return

	var components: Array[Array] = []
	var visited: Dictionary = {}
	for start_id in remaining:
		if visited.has(start_id):
			continue
		var component: Array[int] = []
		var queue: Array[int] = [start_id]
		visited[start_id] = true
		while not queue.is_empty():
			var current: int = queue.pop_front()
			component.append(current)
			for n in adjacency[current] as Array[int]:
				if not visited.has(n):
					visited[n] = true
					queue.append(n)
		components.append(component)

	if components.size() <= 1:
		return

	var root: Array[int] = components[0]
	for i in range(1, components.size()):
		var candidate: Array[int] = components[i]
		var pair: Array[int] = _find_nearest_pair_between_components(root, candidate)
		if pair.size() != 2:
			continue
		var a: int = pair[0]
		var b: int = pair[1]
		if _can_add_edge(a, b):
			_add_edge(a, b, false)
		else:
			_add_forced_edge(a, b, false)
		root.append_array(candidate)

func _find_nearest_pair_between_components(component_a: Array[int], component_b: Array[int]) -> Array[int]:
	var best_distance: float = INF
	var best_pair: Array[int] = []
	for id_a in component_a:
		var pos_a: Vector2 = systems_by_id[id_a].get("position") as Vector2
		for id_b in component_b:
			var pos_b: Vector2 = systems_by_id[id_b].get("position") as Vector2
			var d: float = pos_a.distance_to(pos_b)
			if d < best_distance:
				best_distance = d
				best_pair = [id_a, id_b]
	return best_pair

func _is_system_name_taken(candidate_name: String) -> bool:
	var key: String = _system_lookup_key(candidate_name)
	if key.is_empty():
		return false
	for data_v in systems_by_id.values():
		var data: Dictionary = data_v as Dictionary
		if _system_lookup_key(str(data.get("name", ""))) == key:
			return true
	return false


func _make_unique_system_name(base_name: String, avoid_name: String = "") -> String:
	var cleaned: String = base_name.strip_edges()
	if cleaned.is_empty():
		cleaned = "Unnamed"
	var avoid_key: String = _system_lookup_key(avoid_name)
	var candidate: String = cleaned
	if _system_lookup_key(candidate) != avoid_key and not _is_system_name_taken(candidate):
		return candidate

	for i in range(2, 200):
		candidate = "%s %d" % [cleaned, i]
		if _system_lookup_key(candidate) == avoid_key:
			continue
		if not _is_system_name_taken(candidate):
			return candidate
	return "%s %d" % [cleaned, _next_system_id + 1]


func _create_system(system_position: Vector2, is_main: bool, radius: float, parent_id: int, system_name: String = "", planetary_type: String = "", lanes: Array = [], region: String = "Unknown Regions") -> int:
	var id: int = _next_system_id
	_next_system_id += 1
	var display_name: String = system_name.strip_edges()
	if display_name.is_empty():
		display_name = "Planet %d" % (id + 1)
	display_name = _make_unique_system_name(display_name)

	systems_by_id[id] = {
		"id": id,
		"name": display_name,
		"region": region,
		"planetary_type": planetary_type,
		"position": system_position,
		"is_main": is_main,
		"radius": radius,
		"parent_id": parent_id,
		"on_highway": false,
		"lanes": lanes.duplicate(),
		"fleet_idle_count": 0,
		"fleet_moving_count": 0,
		"fleet_moving_min_arrival_day": -1,
	}
	adjacency[id] = [] as Array[int]
	return id


func _create_generated_child_system(system_position: Vector2, is_main: bool, radius: float, parent_id: int) -> int:
	var parent_region: String = "Unknown Regions"
	var parent_name: String = ""
	if systems_by_id.has(parent_id):
		var parent_data: Dictionary = systems_by_id[parent_id] as Dictionary
		parent_region = str(parent_data.get("region", parent_region))
		parent_name = str(parent_data.get("name", ""))

	var unique_name: String = ""
	for attempt in range(12):
		var payload: Dictionary = _name_generator.generate_name(
			parent_region,
			"system",
			{
				"parent_system_name": parent_name,
				"parent_system_region": parent_region,
				"ordinal_index": attempt + 1,
			}
		)
		var raw_name: String = str(payload.get("name", "")).strip_edges()
		if raw_name.is_empty():
			continue
		if _system_lookup_key(raw_name) == _system_lookup_key(parent_name):
			continue
		if not _is_system_name_taken(raw_name):
			unique_name = raw_name
			break

	if unique_name.is_empty():
		var fallback_root: String = parent_name if not parent_name.is_empty() else "Frontier"
		unique_name = _make_unique_system_name("%s Reach" % fallback_root, parent_name)

	return _create_system(system_position, is_main, radius, parent_id, unique_name, "Unknown", [], parent_region)


func _generate_hyperspace_lane_systems() -> void:
	var highway_keys: Array = edges.keys().duplicate()
	for edge_key_v in highway_keys:
		var edge_key: String = str(edge_key_v)
		if not edges.has(edge_key):
			continue
		var edge_data: Dictionary = edges[edge_key] as Dictionary
		if not bool(edge_data.get("highway", false)):
			continue
		if rng.randf() > LANE_SYSTEM_SPAWN_CHANCE:
			continue

		var a: int = int(edge_data.get("a", -1))
		var b: int = int(edge_data.get("b", -1))
		if a == -1 or b == -1:
			continue

		var pos_a: Vector2 = systems_by_id[a].get("position") as Vector2
		var pos_b: Vector2 = systems_by_id[b].get("position") as Vector2
		var lane_t: float = rng.randf_range(LANE_SYSTEM_MIN_T, LANE_SYSTEM_MAX_T)
		var midpoint: Vector2 = pos_a.lerp(pos_b, lane_t)
		var branch_pos: Vector2 = midpoint
		var local_sparse: bool = _is_segment_sparse(pos_a, pos_b)
		var on_lane_chance: float = LANE_SYSTEM_INSERT_CHANCE
		if local_sparse:
			on_lane_chance = maxf(0.05, on_lane_chance - OFFLANE_EMPTY_BIAS)
		var on_lane: bool = rng.randf() <= on_lane_chance

		if not on_lane:
			branch_pos = _find_offlane_sparse_position(pos_a, pos_b, midpoint)

		if not _is_position_clear_for_any_system(branch_pos, 24.0):
			continue

		var branch_id: int = _create_generated_child_system(branch_pos, false, rng.randf_range(BRANCH_MIN_RADIUS, BRANCH_MAX_RADIUS), a)
		if on_lane:
			_remove_edge(a, b)
			_add_forced_edge(a, branch_id, true)
			_add_forced_edge(branch_id, b, true)
		else:
			if _can_add_edge(a, branch_id):
				_add_edge(a, branch_id, false)
			else:
				_add_forced_edge(a, branch_id, false)
			if rng.randf() <= 0.35 and _can_add_edge(b, branch_id):
				_add_edge(b, branch_id, false)


func _is_segment_sparse(a: Vector2, b: Vector2) -> bool:
	var midpoint: Vector2 = a.lerp(b, 0.5)
	var nearby_count: int = 0
	for data_v in systems_by_id.values():
		var data: Dictionary = data_v as Dictionary
		var other_pos: Vector2 = data.get("position") as Vector2
		if midpoint.distance_to(other_pos) <= EMPTY_SPACE_NEARBY_RADIUS:
			nearby_count += 1
	return nearby_count <= EMPTY_SPACE_TARGET_NEIGHBORS


func _find_offlane_sparse_position(pos_a: Vector2, pos_b: Vector2, midpoint: Vector2) -> Vector2:
	var tangent: Vector2 = (pos_b - pos_a).normalized()
	if tangent.length_squared() <= 0.000001:
		tangent = Vector2.RIGHT
	var normal: Vector2 = tangent.orthogonal().normalized()

	var best_pos: Vector2 = midpoint
	var best_score: float = -INF
	for _i in range(10):
		var offset_distance: float = rng.randf_range(LANE_BRANCH_OFFSET_MIN, LANE_BRANCH_OFFSET_MAX)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var candidate: Vector2 = midpoint + normal * offset_distance * side
		candidate.x = clamp(candidate.x, _map_min.x, _map_max.x)
		candidate.y = clamp(candidate.y, _map_min.y, _map_max.y)
		if not _is_position_clear_for_any_system(candidate, 24.0):
			continue
		var score: float = _distance_to_nearest_system(candidate) + _distance_to_nearest_highway_segment(candidate) * 0.75
		if score > best_score:
			best_score = score
			best_pos = candidate

	if best_score > -INF:
		return best_pos

	var fallback: Vector2 = midpoint + normal * rng.randf_range(LANE_BRANCH_OFFSET_MIN, LANE_BRANCH_OFFSET_MAX) * (-1.0 if rng.randf() < 0.5 else 1.0)
	fallback.x = clamp(fallback.x, _map_min.x, _map_max.x)
	fallback.y = clamp(fallback.y, _map_min.y, _map_max.y)
	return fallback


func _add_edge(a: int, b: int, is_highway: bool) -> void:
	if a == b:
		return
	var key: String = _edge_key(a, b)
	if edges.has(key):
		if is_highway:
			(edges[key] as Dictionary)["highway"] = true
		return
	if not _can_add_edge(a, b):
		return

	edges[key] = {"a": a, "b": b, "highway": is_highway}
	(adjacency[a] as Array[int]).append(b)
	(adjacency[b] as Array[int]).append(a)

func _add_forced_edge(a: int, b: int, is_highway: bool) -> void:
	if a == b:
		return
	var key: String = _edge_key(a, b)
	if edges.has(key):
		if is_highway:
			(edges[key] as Dictionary)["highway"] = true
		return
	edges[key] = {"a": a, "b": b, "highway": is_highway}
	(adjacency[a] as Array[int]).append(b)
	(adjacency[b] as Array[int]).append(a)

func _can_add_edge(a: int, b: int) -> bool:
	var a_pos: Vector2 = systems_by_id[a].get("position") as Vector2
	var b_pos: Vector2 = systems_by_id[b].get("position") as Vector2

	for edge_data_v in edges.values():
		var edge_data: Dictionary = edge_data_v as Dictionary
		var c: int = int(edge_data.get("a"))
		var d: int = int(edge_data.get("b"))
		if c == a or c == b or d == a or d == b:
			continue

		var c_pos: Vector2 = systems_by_id[c].get("position") as Vector2
		var d_pos: Vector2 = systems_by_id[d].get("position") as Vector2
		if Geometry2D.segment_intersects_segment(a_pos, b_pos, c_pos, d_pos) != null:
			return false

	return true

func _edge_key(a: int, b: int) -> String:
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	return "%d|%d" % [low, high]

func _build_visuals() -> void:
	for edge_data_v in edges.values():
		var edge_data: Dictionary = edge_data_v as Dictionary
		var a: int = int(edge_data.get("a"))
		var b: int = int(edge_data.get("b"))
		var is_highway: bool = bool(edge_data.get("highway"))

		var line := Line2D.new()
		line.default_color = HIGHWAY_COLOR if is_highway else NORMAL_LANE_COLOR
		line.width = 5.0 if is_highway else 2.0
		line.points = PackedVector2Array([
			systems_by_id[a].get("position") as Vector2,
			systems_by_id[b].get("position") as Vector2,
		])
		line.antialiased = true
		lanes_node.add_child(line)

	for system_data_v in systems_by_id.values():
		var system_data: Dictionary = system_data_v as Dictionary
		var dot := SystemDot.new()
		dot.position = system_data.get("position") as Vector2
		dot.radius = float(system_data.get("radius"))
		dot.color = MAIN_COLOR if bool(system_data.get("is_main")) else BRANCH_COLOR
		dot.name = str(system_data.get("name"))
		dot.idle_fleet_count = int(system_data.get("fleet_idle_count", 0))
		dot.moving_fleet_count = int(system_data.get("fleet_moving_count", 0))
		dot.moving_min_arrival_day = int(system_data.get("fleet_moving_min_arrival_day", -1))
		dot.queue_redraw()
		systems_node.add_child(dot)
		system_data["dot_node"] = dot

func _setup_camera_to_fit_map() -> void:
	var bounds: Rect2 = _calculate_system_bounds()
	var expanded_bounds: Rect2 = bounds.grow(MAP_PADDING)
	_camera_bounds_min = expanded_bounds.position
	_camera_bounds_max = expanded_bounds.end
	var center: Vector2 = (bounds.position + bounds.end) * 0.5
	camera.position = center
	camera.enabled = true

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var zoom_x: float = bounds.size.x / maxf(1.0, viewport_size.x)
		var zoom_y: float = bounds.size.y / maxf(1.0, viewport_size.y)
		var fit_zoom: float = clampf(maxf(zoom_x, zoom_y) * 1.10, CAMERA_ZOOM_MIN, 1.0)
		camera.zoom = Vector2.ONE * fit_zoom
	else:
		camera.zoom = Vector2.ONE

	_clamp_camera_to_map()

func _calculate_system_bounds() -> Rect2:
	if systems_by_id.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)

	var min_pos: Vector2 = Vector2(INF, INF)
	var max_pos: Vector2 = Vector2(-INF, -INF)

	for data_v in systems_by_id.values():
		var data: Dictionary = data_v as Dictionary
		var p: Vector2 = data.get("position") as Vector2
		var r: float = float(data.get("radius"))

		min_pos.x = minf(min_pos.x, p.x - r - 20.0)
		min_pos.y = minf(min_pos.y, p.y - r - 20.0)
		max_pos.x = maxf(max_pos.x, p.x + r + 20.0)
		max_pos.y = maxf(max_pos.y, p.y + r + 20.0)

	return Rect2(min_pos, max_pos - min_pos)

func _clamp_camera_to_map() -> void:
	var half_view: Vector2 = get_viewport_rect().size * 0.5 * camera.zoom
	var map_center: Vector2 = (_camera_bounds_min + _camera_bounds_max) * 0.5

	var min_x: float = _camera_bounds_min.x + half_view.x
	var max_x: float = _camera_bounds_max.x - half_view.x
	if min_x > max_x:
		camera.position.x = map_center.x
	else:
		camera.position.x = clamp(camera.position.x, min_x, max_x)

	var min_y: float = _camera_bounds_min.y + half_view.y
	var max_y: float = _camera_bounds_max.y - half_view.y
	if min_y > max_y:
		camera.position.y = map_center.y
	else:
		camera.position.y = clamp(camera.position.y, min_y, max_y)

func _find_nearest_main_with_clear_edge(main_id: int, main_ids: Array[int]) -> int:
	var sorted_candidates: Array[int] = []
	for candidate in main_ids:
		if candidate != main_id:
			sorted_candidates.append(candidate)

	var pos: Vector2 = systems_by_id[main_id].get("position") as Vector2
	sorted_candidates.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = systems_by_id[a].get("position") as Vector2
		var pb: Vector2 = systems_by_id[b].get("position") as Vector2
		return pos.distance_to(pa) < pos.distance_to(pb)
	)

	for candidate in sorted_candidates:
		if _can_add_edge(main_id, candidate):
			return candidate

	return -1

func _find_nearest_node_with_clear_edge(system_id: int, candidate_ids: Array[int]) -> int:
	var sorted_candidates: Array[int] = []
	for candidate in candidate_ids:
		if candidate != system_id:
			sorted_candidates.append(candidate)

	var pos: Vector2 = systems_by_id[system_id].get("position") as Vector2
	sorted_candidates.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = systems_by_id[a].get("position") as Vector2
		var pb: Vector2 = systems_by_id[b].get("position") as Vector2
		return pos.distance_to(pa) < pos.distance_to(pb)
	)

	for candidate in sorted_candidates:
		if _can_add_edge(system_id, candidate):
			return candidate

	return -1

func _select_planet_from_screen(screen_position: Vector2, is_double_click: bool = false) -> void:
	var canvas_xform: Transform2D = get_global_transform_with_canvas()
	var world_position: Vector2 = canvas_xform.affine_inverse() * screen_position
	var clicked_id: int = -1
	var clicked_distance: float = INF

	for system_id in systems_by_id.keys():
		var system_data: Dictionary = systems_by_id[system_id] as Dictionary
		var system_position: Vector2 = system_data.get("position") as Vector2
		var radius: float = float(system_data.get("radius"))
		var distance: float = world_position.distance_to(system_position)
		if distance <= radius and distance < clicked_distance:
			clicked_id = int(system_id)
			clicked_distance = distance

	if clicked_id != -1:
		_select_planet(clicked_id)
		if is_double_click:
			emit_signal("planet_double_clicked", str((systems_by_id[clicked_id] as Dictionary).get("name")))

func select_planet_by_name(system_name: String) -> bool:
	var trimmed_name: String = system_name.strip_edges()
	if trimmed_name.is_empty():
		return false

	for system_id in systems_by_id.keys():
		var system_data: Dictionary = systems_by_id[system_id] as Dictionary
		if _names_match_system_query(str(system_data.get("name")), trimmed_name):
			var matched_id: int = int(system_id)
			_select_planet(matched_id)
			_focus_camera_on_system(matched_id, search_focus_zoom)
			return true

	return false


func _focus_camera_on_system(system_id: int, zoom_value: float) -> void:
	if not systems_by_id.has(system_id):
		return
	if camera == null:
		return

	var target_position: Vector2 = (systems_by_id[system_id] as Dictionary).get("position") as Vector2
	camera.position = target_position
	var clamped_zoom: float = clampf(zoom_value, CAMERA_ZOOM_MIN, 1.0)
	camera.zoom = Vector2.ONE * clamped_zoom
	_clamp_camera_to_map()


func focus_camera_on_system_by_name(system_name: String, zoom_value: float = search_focus_zoom) -> bool:
	var trimmed_name: String = system_name.strip_edges()
	if trimmed_name.is_empty():
		return false

	for system_id in systems_by_id.keys():
		var system_data: Dictionary = systems_by_id[system_id] as Dictionary
		if _names_match_system_query(str(system_data.get("name")), trimmed_name):
			var matched_id: int = int(system_id)
			_select_planet(matched_id)
			_focus_camera_on_system(matched_id, zoom_value)
			return true

	return false

func _remove_edge(a: int, b: int) -> void:
	var key: String = _edge_key(a, b)
	if not edges.has(key):
		return
	edges.erase(key)
	if adjacency.has(a):
		(adjacency[a] as Array).erase(b)
	if adjacency.has(b):
		(adjacency[b] as Array).erase(a)


func _system_lookup_key(system_name: String) -> String:
	return system_name.strip_edges().to_lower()


func _names_match_system_query(system_name: String, query: String) -> bool:
	var left: String = system_name.strip_edges()
	var right: String = query.strip_edges()
	if left.is_empty() or right.is_empty():
		return false
	return left.nocasecmp_to(right) == 0


func _select_planet(system_id: int) -> void:
	if not systems_by_id.has(system_id):
		return
	_selected_planet_id = system_id
	var planet_name: String = str((systems_by_id[system_id] as Dictionary).get("name"))
	emit_signal("planet_selected", planet_name)


func _find_system_id_by_name(system_name: String) -> int:
	var target_key: String = _system_lookup_key(system_name)
	for system_id_variant in systems_by_id.keys():
		var system_id: int = int(system_id_variant)
		var system_data: Dictionary = systems_by_id[system_id] as Dictionary
		if _system_lookup_key(str(system_data.get("name", ""))) == target_key:
			return system_id
	return -1


func set_system_fleet_state_by_name(fleet_state_by_system_name: Dictionary) -> void:
	for system_id_variant in systems_by_id.keys():
		var system_id: int = int(system_id_variant)
		var system_data: Dictionary = systems_by_id[system_id] as Dictionary
		system_data["fleet_idle_count"] = 0
		system_data["fleet_moving_count"] = 0
		system_data["fleet_moving_min_arrival_day"] = -1

	for system_name_variant in fleet_state_by_system_name.keys():
		var system_name: String = str(system_name_variant)
		var system_id: int = _find_system_id_by_name(system_name)
		if system_id < 0 or not systems_by_id.has(system_id):
			continue
		var payload: Dictionary = fleet_state_by_system_name[system_name] as Dictionary
		var system_data: Dictionary = systems_by_id[system_id] as Dictionary
		system_data["fleet_idle_count"] = maxi(0, int(payload.get("idle", 0)))
		system_data["fleet_moving_count"] = maxi(0, int(payload.get("moving", 0)))
		system_data["fleet_moving_min_arrival_day"] = int(payload.get("min_arrival_day", -1))

	for system_data_variant in systems_by_id.values():
		var system_data: Dictionary = system_data_variant as Dictionary
		var dot: SystemDot = system_data.get("dot_node") as SystemDot
		if dot == null:
			continue
		dot.idle_fleet_count = int(system_data.get("fleet_idle_count", 0))
		dot.moving_fleet_count = int(system_data.get("fleet_moving_count", 0))
		dot.moving_min_arrival_day = int(system_data.get("fleet_moving_min_arrival_day", -1))
		dot.queue_redraw()


func get_system_fleet_summary_by_name(system_name: String) -> Dictionary:
	var system_id: int = _find_system_id_by_name(system_name)
	if system_id < 0 or not systems_by_id.has(system_id):
		return {}
	var system_data: Dictionary = systems_by_id[system_id] as Dictionary
	var idle_count: int = int(system_data.get("fleet_idle_count", 0))
	var moving_count: int = int(system_data.get("fleet_moving_count", 0))
	return {
		"idle": idle_count,
		"moving": moving_count,
		"min_arrival_day": int(system_data.get("fleet_moving_min_arrival_day", -1)),
		"total": idle_count + moving_count,
	}
