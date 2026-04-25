extends Node2D
class_name SystemMap

signal zoom_out_requested(system_name: String)
signal planet_selected(system_name: String, planet_data: Dictionary)
signal planet_double_clicked(system_name: String, planet_data: Dictionary)

class PlanetDot:
	extends Node2D

	var radius: float = 8.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)

const CanonSystemData = preload("res://scripts/data/canon_systems.gd")
const GalacticNameGenerator = preload("res://scripts/data/galactic_name_generator.gd")

const CANON_COLOR := Color(0.95, 0.95, 1.0, 1.0)
const GENERATED_COLOR := Color(0.65, 0.85, 1.0, 1.0)
const ORBIT_COLOR := Color(0.25, 0.45, 0.75, 0.50)
const LABEL_COLOR := Color(0.92, 0.95, 1.0, 1.0)

const CENTRAL_STAR_RADIUS: float = 22.0
const CANON_PLANET_RADIUS: float = 8.0
const GENERATED_PLANET_RADIUS: float = 6.0
const MIN_GENERATED_PLANETS: int = 4
const MAX_GENERATED_PLANETS: int = 9
const PLANET_NAME_MAX_LENGTH: int = 10
const MIN_ORBIT_RADIUS: float = 80.0
const ORBIT_STEP: float = 38.0
const CAMERA_ZOOM_MIN: float = 0.45
const CAMERA_ZOOM_MAX: float = 1.0
const MAP_PADDING: float = 140.0
const STAR_BINARY_CHANCE: float = 0.12
const STAR_SEPARATION: float = 34.0
const SECONDARY_STAR_RADIUS: float = 17.0
const SECONDARY_STAR_COLOR := Color(1.0, 0.72, 0.38, 1.0)
const MOON_COLOR := Color(0.82, 0.86, 0.95, 1.0)
const MOON_RADIUS: float = 3.0
const MOON_ORBIT_STEP: float = 10.0
const MOON_ORBIT_BASE_RADIUS: float = 14.0
const DOUBLE_CLICK_WINDOW_MS: int = 360

var _rng := RandomNumberGenerator.new()
var _name_generator: GalacticNameGenerator = GalacticNameGenerator.new()
var _current_system_name: String = ""
var _current_system_data: Dictionary = {}
var _generated_planets_by_system: Dictionary = {}
var _system_layouts_by_name: Dictionary = {}
var _star_layout_by_system: Dictionary = {}
var _planet_click_data: Array[Dictionary] = []
var _last_click_time_ms: int = -1
var _last_click_planet_key: String = ""

@onready var orbit_node: Node2D = $Orbits
@onready var planet_node: Node2D = $Planets
@onready var label_node: Node2D = $Labels
@onready var camera: Camera2D = get_viewport().get_camera_2d()


func _ready() -> void:
	_rng.seed = Time.get_unix_time_from_system() + Time.get_ticks_msec()
	_prebuild_generated_planets()
	visible = false
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Use viewport-aware mouse position so clicks in SubViewport map to Node2D space correctly.
	var local_position: Vector2 = get_local_mouse_position()
	var selected_planet: Dictionary = _find_planet_by_position(local_position)
	if selected_planet.is_empty():
		return

	emit_signal("planet_selected", _current_system_name, selected_planet.duplicate(true))
	if mouse_event.double_click or _is_manual_double_click(selected_planet):
		emit_signal("planet_double_clicked", _current_system_name, selected_planet.duplicate(true))

	_last_click_time_ms = Time.get_ticks_msec()
	_last_click_planet_key = _planet_identity_key(selected_planet)


func show_system(system_name: String) -> bool:
	var target_system_name: String = system_name.strip_edges()
	if target_system_name.is_empty():
		return false

	var system_data: Dictionary = _find_system_by_name(target_system_name)
	if system_data.is_empty():
		system_data = {
			"system_name": target_system_name,
			"planets": [],
		}

	_current_system_name = String(system_data.get("system_name", target_system_name)).strip_edges()
	_current_system_data = system_data
	visible = true
	_build_system_visuals()
	return true


func clear_system() -> void:
	_current_system_name = ""
	_current_system_data = {}
	visible = false
	_clear_visuals()


func get_current_system_name() -> String:
	return _current_system_name


func request_zoom_out() -> void:
	if _current_system_name.is_empty():
		return
	emit_signal("zoom_out_requested", _current_system_name)


func _clear_visuals() -> void:
	_planet_click_data.clear()
	for child in orbit_node.get_children():
		child.queue_free()
	for child in planet_node.get_children():
		child.queue_free()
	for child in label_node.get_children():
		child.queue_free()


func _build_system_visuals() -> void:
	_clear_visuals()

	var system_label := Label.new()
	system_label.text = _current_system_name
	system_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	system_label.position = Vector2(-180.0, -220.0)
	system_label.size = Vector2(360.0, 32.0)
	system_label.modulate = LABEL_COLOR
	label_node.add_child(system_label)

	_draw_stars(_current_system_name, _current_system_data)

	var planets_to_draw: Array[Dictionary] = _get_or_create_layout_for_system(_current_system_name, _current_system_data)

	for i in range(planets_to_draw.size()):
		var planet: Dictionary = planets_to_draw[i] as Dictionary
		var orbit_radius: float = MIN_ORBIT_RADIUS + ORBIT_STEP * i
		var angle: float = float(planet.get("orbit_angle", 0.0))
		var position_on_orbit: Vector2 = Vector2.RIGHT.rotated(angle) * orbit_radius

		var orbit := Line2D.new()
		orbit.width = 1.5
		orbit.default_color = ORBIT_COLOR
		orbit.closed = true
		orbit.antialiased = true
		orbit.points = _create_orbit_points(orbit_radius, 48)
		orbit_node.add_child(orbit)

		var dot := PlanetDot.new()
		dot.radius = CANON_PLANET_RADIUS if bool(planet.get("is_canon")) else GENERATED_PLANET_RADIUS
		dot.color = CANON_COLOR if bool(planet.get("is_canon")) else GENERATED_COLOR
		dot.position = position_on_orbit
		planet_node.add_child(dot)

		var planet_payload: Dictionary = planet.duplicate(true)
		planet_payload["radius"] = dot.radius
		planet_payload["position"] = position_on_orbit
		_planet_click_data.append(planet_payload)

		var moon_layout: Array = planet.get("moons", []) as Array
		if not moon_layout.is_empty():
			_draw_moons(position_on_orbit, moon_layout)

		var label := Label.new()
		label.text = "%s (%s)" % [String(planet.get("name")), String(planet.get("planetary_type"))]
		label.modulate = LABEL_COLOR
		label.position = position_on_orbit + Vector2(12.0, -8.0)
		label_node.add_child(label)

	_configure_camera_for_system(planets_to_draw.size())


func _find_planet_by_position(local_position: Vector2) -> Dictionary:
	for planet_v in _planet_click_data:
		var planet_data: Dictionary = planet_v as Dictionary
		var center: Vector2 = planet_data.get("position", Vector2.ZERO) as Vector2
		var radius: float = float(planet_data.get("radius", GENERATED_PLANET_RADIUS))
		if local_position.distance_to(center) <= radius + 8.0:
			return planet_data
	return {}


func _is_manual_double_click(selected_planet: Dictionary) -> bool:
	var now_ms: int = Time.get_ticks_msec()
	var clicked_key: String = _planet_identity_key(selected_planet)
	if clicked_key.is_empty() or _last_click_planet_key != clicked_key:
		return false
	if _last_click_time_ms < 0:
		return false
	return now_ms - _last_click_time_ms <= DOUBLE_CLICK_WINDOW_MS


func _planet_identity_key(planet_data: Dictionary) -> String:
	return String(planet_data.get("source_name", planet_data.get("name", ""))).strip_edges().to_lower()


func _configure_camera_for_system(planet_count: int) -> void:
	if camera == null:
		return

	camera.enabled = true
	camera.position = Vector2.ZERO

	var max_radius: float = MIN_ORBIT_RADIUS + ORBIT_STEP * maxi(0, planet_count - 1)
	var content_extent: float = max_radius + MAP_PADDING
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe_width: float = maxf(1.0, viewport_size.x)
	var safe_height: float = maxf(1.0, viewport_size.y)
	var zoom_x: float = (content_extent * 2.0) / safe_width
	var zoom_y: float = (content_extent * 2.0) / safe_height
	camera.zoom = Vector2.ONE * clampf(maxf(zoom_x, zoom_y), CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)


func _prebuild_generated_planets() -> void:
	_generated_planets_by_system.clear()
	_system_layouts_by_name.clear()
	_star_layout_by_system.clear()
	for row_v in CanonSystemData.SYSTEMS:
		var row: Dictionary = row_v as Dictionary
		var system_name: String = String(row.get("system_name", ""))
		if system_name.is_empty():
			continue
		var system_key: String = _system_lookup_key(system_name)
		_generated_planets_by_system[system_key] = _generate_planets_for_system(system_name, row)


func _get_or_create_layout_for_system(system_name: String, system_data: Dictionary) -> Array[Dictionary]:
	if _system_layouts_by_name.has(system_name):
		return (_system_layouts_by_name[system_name] as Array).duplicate(true)

	var planets_to_draw: Array[Dictionary] = []
	var canon_planets: Array = system_data.get("planets", []) as Array
	for canon_v in canon_planets:
		var canon: Dictionary = canon_v as Dictionary
		var canon_name: String = String(canon.get("name", "Canon Planet"))
		planets_to_draw.append({
			"name": _truncate_planet_name(canon_name),
			"source_name": canon_name,
			"planetary_type": String(canon.get("planetary_type", "Unknown")),
			"is_canon": true,
			"moons": _normalize_moon_layout(canon.get("moons", []) as Array),
			"elements": (canon.get("elements", []) as Array).duplicate(true),
			"infrastructures": (canon.get("infrastructures", []) as Array).duplicate(true),
		})

	var generated_planets: Array = _get_or_create_generated_planets(system_name)
	for generated_v in generated_planets:
		planets_to_draw.append((generated_v as Dictionary).duplicate(true))

	planets_to_draw.shuffle()
	for planet_v in planets_to_draw:
		var planet: Dictionary = planet_v as Dictionary
		planet["orbit_angle"] = _rng.randf_range(0.0, TAU)

	_system_layouts_by_name[system_name] = planets_to_draw.duplicate(true)
	return planets_to_draw


func _get_or_create_generated_planets(system_name: String) -> Array[Dictionary]:
	var system_key: String = _system_lookup_key(system_name)
	if _generated_planets_by_system.has(system_key):
		return (_generated_planets_by_system[system_key] as Array).duplicate(true)

	var generated_planets: Array[Dictionary] = _generate_planets_for_system(system_name, _find_system_by_name(system_name))
	_generated_planets_by_system[system_key] = generated_planets
	return generated_planets.duplicate(true)


func _generate_planets_for_system(system_name: String, system_data: Dictionary = {}) -> Array[Dictionary]:
	var generated_count: int = _rng.randi_range(MIN_GENERATED_PLANETS, MAX_GENERATED_PLANETS)
	var generated_planets: Array[Dictionary] = []
	var region: String = String(system_data.get("region", "Unknown Regions"))
	var used_name_keys: Dictionary = _collect_used_name_keys(system_data)
	for i in range(generated_count):
		var name_payload: Dictionary = _build_unique_planet_name_payload(system_name, region, i + 1, used_name_keys)
		var generated_name: String = String(name_payload.get("name", "%s-%d" % [system_name.substr(0, mini(3, system_name.length())).to_upper(), i + 1]))
		generated_name = _truncate_planet_name(generated_name)
		used_name_keys[_planet_name_key(generated_name)] = true
		generated_planets.append({
			"name": generated_name,
			"source_name": generated_name,
			"planetary_type": _random_generated_type(),
			"is_canon": false,
			"moons": _generate_moons_for_planet(),
		})
	return generated_planets


func _build_unique_planet_name_payload(system_name: String, region: String, ordinal_index: int, used_name_keys: Dictionary) -> Dictionary:
	for attempt in range(8):
		var payload: Dictionary = _name_generator.generate_name(
			region,
			"planet",
			{
				"parent_system_name": system_name,
				"ordinal_index": ordinal_index + attempt,
			}
		)
		var key: String = _planet_name_key(_truncate_planet_name(String(payload.get("name", ""))))
		if not key.is_empty() and not used_name_keys.has(key):
			return payload

	return {
		"name": "%s-%d" % [system_name.substr(0, mini(3, system_name.length())).to_upper(), ordinal_index],
	}


func _collect_used_name_keys(system_data: Dictionary) -> Dictionary:
	var used: Dictionary = {}
	var canon_planets: Array = system_data.get("planets", []) as Array
	for planet_v in canon_planets:
		var planet: Dictionary = planet_v as Dictionary
		var key: String = _planet_name_key(String(planet.get("name", "")))
		if not key.is_empty():
			used[key] = true
	return used


func _draw_stars(system_name: String, system_data: Dictionary) -> void:
	var stars: Array[Dictionary] = _get_or_create_star_layout(system_name, system_data)
	for star_data in stars:
		var star := PlanetDot.new()
		star.radius = float(star_data.get("radius", CENTRAL_STAR_RADIUS))
		star.color = star_data.get("color", Color(1.0, 0.82, 0.45, 1.0)) as Color
		star.position = star_data.get("position", Vector2.ZERO) as Vector2
		planet_node.add_child(star)


func _get_or_create_star_layout(system_name: String, system_data: Dictionary) -> Array[Dictionary]:
	var key: String = _system_lookup_key(system_name)
	if _star_layout_by_system.has(key):
		return (_star_layout_by_system[key] as Array).duplicate(true)

	var stars: Array[Dictionary] = []
	var configured: Array = system_data.get("stars", []) as Array
	if configured.size() >= 2:
		stars = [
			{
				"radius": float((configured[0] as Dictionary).get("radius", CENTRAL_STAR_RADIUS)),
				"color": (configured[0] as Dictionary).get("color", Color(1.0, 0.82, 0.45, 1.0)),
				"position": Vector2(-STAR_SEPARATION * 0.5, 0.0),
			},
			{
				"radius": float((configured[1] as Dictionary).get("radius", SECONDARY_STAR_RADIUS)),
				"color": (configured[1] as Dictionary).get("color", SECONDARY_STAR_COLOR),
				"position": Vector2(STAR_SEPARATION * 0.5, 0.0),
			},
		]
	else:
		var has_binary: bool = _rng.randf() < STAR_BINARY_CHANCE
		stars.append({
			"radius": CENTRAL_STAR_RADIUS,
			"color": Color(1.0, 0.82, 0.45, 1.0),
			"position": Vector2(-STAR_SEPARATION * 0.5, 0.0) if has_binary else Vector2.ZERO,
		})
		if has_binary:
			stars.append({
				"radius": SECONDARY_STAR_RADIUS,
				"color": SECONDARY_STAR_COLOR,
				"position": Vector2(STAR_SEPARATION * 0.5, 0.0),
			})

	_star_layout_by_system[key] = stars.duplicate(true)
	return stars


func _draw_moons(planet_position: Vector2, moon_layout: Array) -> void:
	for moon_v in moon_layout:
		var moon: Dictionary = moon_v as Dictionary
		var orbit_radius: float = float(moon.get("orbit_radius", MOON_ORBIT_BASE_RADIUS))
		var angle: float = float(moon.get("orbit_angle", 0.0))
		var moon_position: Vector2 = planet_position + (Vector2.RIGHT.rotated(angle) * orbit_radius)

		var orbit := Line2D.new()
		orbit.width = 1.0
		orbit.default_color = ORBIT_COLOR * Color(1.0, 1.0, 1.0, 0.75)
		orbit.closed = true
		orbit.antialiased = true
		orbit.points = _create_orbit_points(orbit_radius, 28)
		orbit.position = planet_position
		orbit_node.add_child(orbit)

		var moon_dot := PlanetDot.new()
		moon_dot.radius = float(moon.get("radius", MOON_RADIUS))
		moon_dot.color = moon.get("color", MOON_COLOR) as Color
		moon_dot.position = moon_position
		planet_node.add_child(moon_dot)


func _generate_moons_for_planet() -> Array[Dictionary]:
	var roll: float = _rng.randf()
	var moon_count: int = 0
	if roll < 0.72:
		moon_count = 0
	elif roll < 0.92:
		moon_count = 1
	elif roll < 0.985:
		moon_count = 2
	else:
		moon_count = 3

	var moons: Array[Dictionary] = []
	for i in range(moon_count):
		moons.append({
			"radius": MOON_RADIUS,
			"color": MOON_COLOR,
			"orbit_radius": MOON_ORBIT_BASE_RADIUS + (i * MOON_ORBIT_STEP),
			"orbit_angle": _rng.randf_range(0.0, TAU),
		})
	return moons


func _normalize_moon_layout(raw_moons: Array) -> Array[Dictionary]:
	var moons: Array[Dictionary] = []
	for i in range(raw_moons.size()):
		var raw: Dictionary = raw_moons[i] as Dictionary
		moons.append({
			"radius": float(raw.get("radius", MOON_RADIUS)),
			"color": raw.get("color", MOON_COLOR),
			"orbit_radius": float(raw.get("orbit_radius", MOON_ORBIT_BASE_RADIUS + (i * MOON_ORBIT_STEP))),
			"orbit_angle": float(raw.get("orbit_angle", _rng.randf_range(0.0, TAU))),
		})
	return moons


func _truncate_planet_name(name: String) -> String:
	var cleaned: String = name.strip_edges()
	if cleaned.length() <= PLANET_NAME_MAX_LENGTH:
		return cleaned
	var shortened: String = cleaned.substr(0, PLANET_NAME_MAX_LENGTH).strip_edges()
	while shortened.ends_with("-") or shortened.ends_with("'"):
		shortened = shortened.substr(0, shortened.length() - 1).strip_edges()
	return shortened


func _planet_name_key(name: String) -> String:
	return _truncate_planet_name(name).to_lower()


func _create_orbit_points(radius: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var angle: float = t * TAU
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _find_system_by_name(system_name: String) -> Dictionary:
	var target: String = system_name.strip_edges()
	if target.is_empty():
		return {}
	for row_v in CanonSystemData.SYSTEMS:
		var row: Dictionary = row_v as Dictionary
		if _names_match_system_query(String(row.get("system_name", "")), target):
			return row
	return {}


func _system_lookup_key(system_name: String) -> String:
	return system_name.strip_edges().to_lower()


func _names_match_system_query(system_name: String, query: String) -> bool:
	var left: String = system_name.strip_edges()
	var right: String = query.strip_edges()
	if left.is_empty() or right.is_empty():
		return false
	return left.nocasecmp_to(right) == 0


func _random_generated_type() -> String:
	var types: Array[String] = [
		"Rocky World",
		"Ice World",
		"Gas Giant",
		"Desert World",
		"Oceanic World",
		"Volcanic World",
	]
	return types[_rng.randi_range(0, types.size() - 1)]
