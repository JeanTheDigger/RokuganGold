extends SystemMap
class_name SystemMapTest

signal fleet_selected(system_name: String, fleet_data: Dictionary)

const CanonSystemTestData = preload("res://scripts/data/canon_systems_test.gd")

const FLEET_RING_OFFSET: float = 52.0
const FLEET_SHIP_SPACING_X: float = 14.0
const FLEET_SHIP_SPACING_Y: float = 10.0
const FACTION_A_ID: int = 1
const FACTION_B_ID: int = 2
const FACTION_A_COLOR := Color(1.0, 0.55, 0.10, 1.0)
const FACTION_B_COLOR := Color(0.86, 0.12, 0.12, 1.0)
const DEFAULT_FACTION_FLEET_COLOR := Color(0.82, 0.88, 0.95, 1.0)
const STATION_RING_OFFSET: float = 28.0
const STATION_SQUARE_SIZE: float = 7.0

class StationSquare:
	extends Node2D
	var size: float = STATION_SQUARE_SIZE
	var color: Color = Color.WHITE
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-size, -size), Vector2(size * 2.0, size * 2.0)), color)

class FleetTriangle:
	extends Node2D
	var size: float = 6.0
	var color: Color = Color.WHITE
	func _draw() -> void:
		var tip: Vector2 = Vector2(size, 0.0)
		var left: Vector2 = Vector2(-size * 0.75, -size * 0.55)
		var right: Vector2 = Vector2(-size * 0.75, size * 0.55)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), color)

var _fleet_state_by_system_name: Dictionary = {}
var _fleet_click_data: Array[Dictionary] = []
@onready var fleet_node: Node2D = get_node_or_null("Fleets") as Node2D
@onready var station_node: Node2D = get_node_or_null("Stations") as Node2D


func _ready() -> void:
	super._ready()
	if fleet_node == null:
		fleet_node = Node2D.new()
		fleet_node.name = "Fleets"
		add_child(fleet_node)
	if station_node == null:
		station_node = Node2D.new()
		station_node.name = "Stations"
		add_child(station_node)


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var selected_fleet: Dictionary = _find_fleet_by_position(get_local_mouse_position())
			if not selected_fleet.is_empty():
				emit_signal("fleet_selected", _current_system_name, selected_fleet.duplicate(true))
				return
	super._input(event)


func set_system_fleet_state_by_name(fleet_state_by_system_name: Dictionary) -> void:
	_fleet_state_by_system_name = fleet_state_by_system_name.duplicate(true)
	if visible:
		_build_system_visuals()


func _build_system_visuals() -> void:
	super._build_system_visuals()
	_draw_system_stations()
	_draw_system_fleets()


func _clear_visuals() -> void:
	super._clear_visuals()
	_fleet_click_data.clear()
	if fleet_node != null:
		for child in fleet_node.get_children():
			child.queue_free()
	if station_node != null:
		for child in station_node.get_children():
			child.queue_free()


func _draw_system_stations() -> void:
	if station_node == null:
		return
	var structures: Array = _current_system_data.get("orbital_structures", []) as Array
	if structures.is_empty():
		return
	var ring_radius: float = MIN_ORBIT_RADIUS + STATION_RING_OFFSET
	var count: int = structures.size()
	for i in range(count):
		var structure: Dictionary = structures[i] as Dictionary
		var owner_faction_id: int = int(structure.get("owner_faction_id", 0))
		var square := StationSquare.new()
		square.size = STATION_SQUARE_SIZE
		square.color = _color_for_faction(owner_faction_id)
		var angle: float = -PI * 0.5 + TAU * (float(i) / maxf(1.0, float(count)))
		square.position = Vector2.RIGHT.rotated(angle) * ring_radius
		station_node.add_child(square)


func _draw_system_fleets() -> void:
	if fleet_node == null:
		return
	var payload: Dictionary = _fleet_state_by_system_name.get(_current_system_name, {})
	var factions: Array = payload.get("factions", []) as Array
	if factions.is_empty():
		return
	var planet_count: int = (_planet_click_data as Array).size()
	var ring_radius: float = MIN_ORBIT_RADIUS + ORBIT_STEP * maxi(0, planet_count - 1) + FLEET_RING_OFFSET
	var cluster_states: Array[Dictionary] = _compute_cluster_states(factions)
	for cluster_state_variant in cluster_states:
		var cluster_state: Dictionary = cluster_state_variant
		var center: Vector2 = Vector2.RIGHT.rotated(float(cluster_state.get("center_angle", 0.0))) * ring_radius
		var heading_angle: float = float(cluster_state.get("heading_angle", 0.0))
		var heading: Vector2 = Vector2.RIGHT.rotated(heading_angle)
		var right: Vector2 = heading.orthogonal().normalized()
		var faction_payload: Dictionary = cluster_state.get("faction_payload", {})
		var owner_faction_id: int = int(faction_payload.get("faction_id", 0))
		var ship_offsets: Array[Vector2] = _build_wedge_offsets(int(cluster_state.get("ship_count", 0)))
		var ship_fleet_ids: Array[int] = []
		for ship_fleet_variant in (faction_payload.get("fleet_ship_counts", []) as Array):
			var ship_fleet: Dictionary = ship_fleet_variant
			for _ship_idx in range(maxi(0, int(ship_fleet.get("ship_count", 0)))):
				ship_fleet_ids.append(int(ship_fleet.get("fleet_id", -1)))
		while ship_fleet_ids.size() < ship_offsets.size():
			ship_fleet_ids.append(-1)
		for ship_index in range(ship_offsets.size()):
			var offset: Vector2 = ship_offsets[ship_index]
			var triangle_position: Vector2 = center + heading * offset.x + right * offset.y
			var triangle := FleetTriangle.new()
			triangle.position = triangle_position
			triangle.rotation = heading_angle
			triangle.size = 5.5
			triangle.color = _color_for_faction(owner_faction_id)
			fleet_node.add_child(triangle)
			var local_poly: PackedVector2Array = PackedVector2Array([
				Vector2(triangle.size, 0.0),
				Vector2(-triangle.size * 0.75, -triangle.size * 0.55),
				Vector2(-triangle.size * 0.75, triangle.size * 0.55),
			])
			var global_poly: PackedVector2Array = PackedVector2Array()
			for local_point in local_poly:
				global_poly.append(triangle.to_global(local_point))
			_fleet_click_data.append({
				"global_polygon": global_poly,
				"fleet_payload": {
					"fleet_id": ship_fleet_ids[ship_index],
					"owner_faction_id": owner_faction_id,
					"system_name": _current_system_name,
					"ship_index": ship_index,
					"ship_count": ship_offsets.size(),
					"fleet_ids": faction_payload.get("fleet_ids", []).duplicate(true),
				},
			})


func _find_fleet_by_position(local_position: Vector2) -> Dictionary:
	for fleet_entry_variant in _fleet_click_data:
		var fleet_entry: Dictionary = fleet_entry_variant
		var points: PackedVector2Array = fleet_entry.get("global_polygon", PackedVector2Array())
		if points.size() >= 3 and Geometry2D.is_point_in_polygon(local_position, points):
			return fleet_entry.get("fleet_payload", {})
	return {}


func _build_wedge_offsets(ship_count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var row: int = 0
	while offsets.size() < maxi(0, ship_count):
		for column in range(row + 1):
			if offsets.size() >= ship_count:
				break
			var lateral_index: float = float(column) - float(row) * 0.5
			offsets.append(Vector2(float(row) * FLEET_SHIP_SPACING_X, lateral_index * FLEET_SHIP_SPACING_Y))
		row += 1
	return offsets


func _compute_cluster_states(factions: Array) -> Array[Dictionary]:
	var cluster_states: Array[Dictionary] = []
	for faction_variant in factions:
		var faction_payload: Dictionary = faction_variant
		cluster_states.append({
			"faction_payload": faction_payload,
			"ship_count": maxi(0, int(faction_payload.get("ship_count", 0))),
			"center_angle": 0.0,
			"heading_angle": 0.0,
		})
	if cluster_states.size() == 2:
		var first_payload: Dictionary = cluster_states[0].get("faction_payload", {})
		var second_id: int = int((cluster_states[1].get("faction_payload", {}) as Dictionary).get("faction_id", 0))
		for hostile_variant in first_payload.get("hostile_to", []):
			if int(hostile_variant) == second_id:
				cluster_states[0]["center_angle"] = 0.0
				cluster_states[1]["center_angle"] = PI
				cluster_states[0]["heading_angle"] = PI
				cluster_states[1]["heading_angle"] = 0.0
				return cluster_states
	for i in range(cluster_states.size()):
		var angle: float = -PI * 0.5 + TAU * (float(i) / maxf(1.0, float(cluster_states.size())))
		cluster_states[i]["center_angle"] = angle
		cluster_states[i]["heading_angle"] = angle + PI * 0.5
	return cluster_states


func _color_for_faction(faction_id: int) -> Color:
	if faction_id == FACTION_A_ID:
		return FACTION_A_COLOR
	if faction_id == FACTION_B_ID:
		return FACTION_B_COLOR
	return DEFAULT_FACTION_FLEET_COLOR

func _prebuild_generated_planets() -> void:
	_generated_planets_by_system.clear()
	_system_layouts_by_name.clear()
	_star_layout_by_system.clear()


func _get_or_create_generated_planets(_system_name: String) -> Array[Dictionary]:
	return []


func _generate_planets_for_system(_system_name: String, _system_data: Dictionary = {}) -> Array[Dictionary]:
	return []


func _find_system_by_name(system_name: String) -> Dictionary:
	var target: String = system_name.strip_edges()
	if target.is_empty():
		return {}
	for row_v in CanonSystemTestData.get_preset_systems(CanonSystemTestData.PRESET_TEST_GALAXY_PREPATCH7):
		var row: Dictionary = row_v as Dictionary
		if _names_match_system_query(String(row.get("system_name", "")), target):
			return row
	return super._find_system_by_name(system_name)
