class_name AsciiMapView
extends Control
## Renders a 31×31 viewport window into a variable-size ASCII zone map (s4.4).
##
## The viewport is always VIEWPORT_SIZE×VIEWPORT_SIZE tiles regardless of how
## large the underlying zone is. Call set_map() to load a map and position the
## camera. Use look_at() to pan the camera (Dwarf Fortress Adventure Mode style)
## when exploring zones larger than the viewport. move_player() repositions the
## player without moving the camera.
##
## Layout: each tile cell is CELL_SIZE × CELL_SIZE pixels. The control always
## occupies (VIEWPORT_SIZE * CELL_SIZE) × (VIEWPORT_SIZE * CELL_SIZE) pixels.
##
## Input (when has_focus or mouse_filter = PASS):
##   Movement  — numpad 1-9 (8-directional) or WASD + Q/E/Z/C diagonals
##   Wait      — numpad 5, period
##   Look mode — L key: arrow/numpad pan camera without moving player
##               Esc: exit look mode, re-center on player
##   Close door — C when adjacent closed door... (via context interaction)
##
## Signals emitted:
##   moved(new_x, new_y)              player took a step
##   zone_exit_reached(exit_x, exit_y) player stepped onto a ZONE_EXIT tile
##   door_toggled(x, y, is_open)      a door tile was opened or closed
##   waited()                         player waited (no movement)

## Emitted after every successful player step.
signal moved(new_x: int, new_y: int)
## Emitted when the player steps onto a ZONE_EXIT tile.
signal zone_exit_reached(exit_x: int, exit_y: int)
## Emitted when a door tile is toggled.  is_open==true means it was just opened.
signal door_toggled(x: int, y: int, is_open: bool)
## Emitted when the player waits in place.
signal waited()

const VIEWPORT_SIZE: int = 31  # tiles visible in each dimension
const CELL_SIZE: int = 20      # pixels per tile cell

const BG_DEFAULT: Color = Color(0.06, 0.06, 0.08, 1.0)
const HIDDEN_BG: Color = Color(0.06, 0.06, 0.08, 1.0)
# Explored tiles (seen before, not currently visible) render at this fraction
# of their full foreground/background brightness.
const DIM_FACTOR: float = 0.30
# Animated glyphs (player, entities) blink at 1 Hz (toggle every 0.5 s).
const BLINK_INTERVAL: float = 0.5

# unit_type string → {glyph, color} for entity rendering.
const ENTITY_GLYPHS: Dictionary = {
	# ── Bandit / ronin ────────────────────────────────────────────────────────
	"RONIN":              {"glyph": "r", "color": Color(0.6, 0.8, 1.0)},
	"RONIN_ENFORCER":     {"glyph": "r", "color": Color(0.5, 0.7, 0.9)},
	"BANDIT_THUG":        {"glyph": "t", "color": Color(0.9, 0.6, 0.2)},
	"BANDIT_RABBLE":      {"glyph": "p", "color": Color(0.7, 0.5, 0.3)},
	# ── Peasant revolt ────────────────────────────────────────────────────────
	"REBEL_PEASANT":      {"glyph": "p", "color": Color(0.7, 0.5, 0.3)},
	# ── Nezumi ────────────────────────────────────────────────────────────────
	"NEZUMI_CHIEFTAIN":   {"glyph": "N", "color": Color(0.8, 0.6, 0.2)},
	"NEZUMI_WARRIOR":     {"glyph": "n", "color": Color(0.7, 0.5, 0.2)},
	"NEZUMI_ARCHER":      {"glyph": "n", "color": Color(0.6, 0.5, 0.2)},
	"NEZUMI_SCOUT":       {"glyph": "n", "color": Color(0.6, 0.4, 0.2)},
	"NEZUMI_BROODMOTHER": {"glyph": "N", "color": Color(0.9, 0.4, 0.1)},
	# ── Maho cult / bloodspeakers ─────────────────────────────────────────────
	"CULT_INITIATE":      {"glyph": "c", "color": Color(0.7, 0.3, 0.8)},
	"MAHO_CULTIST":       {"glyph": "C", "color": Color(0.8, 0.2, 0.9)},
	"BLOODSPEAKER_ADEPT": {"glyph": "A", "color": Color(1.0, 0.1, 1.0)},
	"MAHO_TSUKAI":        {"glyph": "M", "color": Color(1.0, 0.2, 0.3)},
	# ── Undead / tainted ──────────────────────────────────────────────────────
	"ZOMBIE":             {"glyph": "z", "color": Color(0.4, 0.6, 0.3)},
	"TAINTED_ANIMAL":     {"glyph": "a", "color": Color(0.5, 0.7, 0.1)},
	"TAINTED_HUMAN":      {"glyph": "T", "color": Color(0.6, 0.8, 0.1)},
	# ── Shadowlands creatures ─────────────────────────────────────────────────
	"BAKEMONO":           {"glyph": "b", "color": Color(0.5, 0.7, 0.2)},
	"BAKEMONO_WARRIOR":   {"glyph": "B", "color": Color(0.5, 0.8, 0.2)},
	"BAKEMONO_ARCHER":    {"glyph": "b", "color": Color(0.4, 0.6, 0.2)},
	"BAKEMONO_SHAMAN":    {"glyph": "S", "color": Color(0.8, 0.9, 0.2)},
	"SKELETON_WARRIOR":   {"glyph": "s", "color": Color(0.8, 0.8, 0.7)},
	"OGRE_WARRIOR":       {"glyph": "O", "color": Color(0.9, 0.3, 0.1)},
	"OGRE_RAVENOUS":      {"glyph": "O", "color": Color(1.0, 0.2, 0.0)},
	"OGRE_WARLORD":       {"glyph": "O", "color": Color(1.0, 0.4, 0.0)},
	"ONI_SPAWN":          {"glyph": "o", "color": Color(1.0, 0.1, 0.1)},
	# ── Crab Clan (friendly side in wall-sortie missions) ─────────────────────
	"HIDA_BUSHI":         {"glyph": "H", "color": Color(0.3, 0.5, 1.0)},
	"HIRUMA_SCOUT":       {"glyph": "h", "color": Color(0.2, 0.8, 0.7)},
	"KUNI_WITCH_HUNTER":  {"glyph": "K", "color": Color(0.9, 0.9, 1.0)},
}

var _map: AsciiMapData = null
var _player_x: int = 15
var _player_y: int = 15
# Top-left corner of the viewport in map coordinates.
var _camera_x: int = 0
var _camera_y: int = 0
var _perception: int = 4      # raw Perception trait; base for FovSystem calls
var _vision_radius: int = 4   # effective radius after env modifier + lookout
var _env_modifier: int = 0
var _water_ring: int = 3
var _visible: Dictionary = {}  # Vector2i (map coords) -> bool; current FOV
var _seen: Dictionary = {}     # Vector2i (map coords) -> bool; all tiles ever seen
var _look_mode: bool = false   # true: arrow keys pan camera, not player
# Transient entity list: Array of {x, y, unit_type, faction, is_alive}.
var _entities: Array = []
# Blink state for animated glyphs (player marker + entities).
var _blink_timer: float = 0.0
var _blink_visible: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(VIEWPORT_SIZE * CELL_SIZE, VIEWPORT_SIZE * CELL_SIZE)
	set_process_unhandled_input(true)
	set_process(true)


func _process(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= BLINK_INTERVAL:
		_blink_timer -= BLINK_INTERVAL
		_blink_visible = not _blink_visible
		queue_redraw()


# Load a new map and set the player position. Camera centers on the player.
# perception: character's Perception trait (base vision radius).
# env_modifier: environmental reduction (0–4 per s4.4.2).
# water_ring: character's Water Ring (movement budget source, s4.5).
func set_map(
	map: AsciiMapData,
	player_x: int,
	player_y: int,
	perception: int,
	env_modifier: int = 0,
	water_ring: int = 3,
) -> void:
	_map = map
	_player_x = player_x
	_player_y = player_y
	_perception = perception
	_env_modifier = env_modifier
	_water_ring = water_ring
	_look_mode = false
	_entities.clear()
	_seen.clear()
	_center_camera_on(_player_x, _player_y)
	_recompute_fov()
	queue_redraw()


# Update only the player position and vision without changing the map.
# The camera stays where it is (does not re-center automatically).
func move_player(
	player_x: int,
	player_y: int,
	perception: int,
	env_modifier: int = 0,
) -> void:
	_player_x = player_x
	_player_y = player_y
	_perception = perception
	_env_modifier = env_modifier
	_center_camera_on(_player_x, _player_y)
	_recompute_fov()
	queue_redraw()


# Pan the camera to center on the given map coordinate (Look action).
# FOV is still computed from the player position, not the look target.
func look_at(map_x: int, map_y: int) -> void:
	_center_camera_on(map_x, map_y)
	queue_redraw()


# Re-center on the player without changing perception/env settings.
func reset_camera() -> void:
	_look_mode = false
	_center_camera_on(_player_x, _player_y)
	queue_redraw()


# ── Entity layer ─────────────────────────────────────────────────────────────

# Load entities from MissionBuilder/MissionPopulator output.
# placements may be:
#   • Array — all entities treated as "enemy" (standard missions)
#   • Dictionary {"friendly": [...], "enemy": [...]} — wall-sortie missions
# Clears any previously loaded entities. Also called automatically by set_map().
func set_entities(placements) -> void:
	_entities.clear()
	if placements is Array:
		for p: Dictionary in placements:
			_entities.append(_make_entity(p, "enemy"))
	elif placements is Dictionary:
		for p: Dictionary in placements.get("friendly", []):
			_entities.append(_make_entity(p, "friendly"))
		for p: Dictionary in placements.get("enemy", []):
			_entities.append(_make_entity(p, "enemy"))
	queue_redraw()


func clear_entities() -> void:
	_entities.clear()
	queue_redraw()


# Mark the first alive entity at (x, y) as dead (removed from display).
func kill_entity_at(x: int, y: int) -> void:
	for e: Dictionary in _entities:
		if e["is_alive"] and e["x"] == x and e["y"] == y:
			e["is_alive"] = false
			break
	queue_redraw()


# Move the first alive entity at (fx, fy) to (tx, ty).
func move_entity(fx: int, fy: int, tx: int, ty: int) -> void:
	for e: Dictionary in _entities:
		if e["is_alive"] and e["x"] == fx and e["y"] == fy:
			e["x"] = tx
			e["y"] = ty
			break
	queue_redraw()


# Returns all alive entities at (x, y), or an empty array.
func get_entities_at(x: int, y: int) -> Array:
	var result: Array = []
	for e: Dictionary in _entities:
		if e["is_alive"] and e["x"] == x and e["y"] == y:
			result.append(e)
	return result


func _make_entity(p: Dictionary, faction: String) -> Dictionary:
	return {
		"x":         p.get("x", 0),
		"y":         p.get("y", 0),
		"unit_type": p.get("unit_type", ""),
		"faction":   faction,
		"is_alive":  true,
	}


# ── Keyboard input ───────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _map == null or not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed:
		return

	# Look-mode toggle / cancel.
	if key.keycode == KEY_L and not key.echo:
		_look_mode = not _look_mode
		if not _look_mode:
			_center_camera_on(_player_x, _player_y)
			queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if key.keycode == KEY_ESCAPE and not key.echo and _look_mode:
		_look_mode = false
		_center_camera_on(_player_x, _player_y)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	# Look mode: pan camera with arrows / numpad, do NOT move the player.
	if _look_mode:
		var ldx: int = 0
		var ldy: int = 0
		match key.keycode:
			KEY_KP_8, KEY_UP:    ldy = -1
			KEY_KP_2, KEY_DOWN:  ldy =  1
			KEY_KP_4, KEY_LEFT:  ldx = -1
			KEY_KP_6, KEY_RIGHT: ldx =  1
			KEY_KP_7: ldx = -1; ldy = -1
			KEY_KP_9: ldx =  1; ldy = -1
			KEY_KP_1: ldx = -1; ldy =  1
			KEY_KP_3: ldx =  1; ldy =  1
		if ldx != 0 or ldy != 0:
			var half: int = VIEWPORT_SIZE / 2
			var cx: int = clampi(
				_camera_x + half + ldx, 0,
				maxi(0, _map.width - 1))
			var cy: int = clampi(
				_camera_y + half + ldy, 0,
				maxi(0, _map.height - 1))
			look_at(cx, cy)
			get_viewport().set_input_as_handled()
		return

	# Normal mode: map movement direction from key.
	var dx: int = 0
	var dy: int = 0
	var is_wait: bool = false
	match key.keycode:
		KEY_KP_8:               dy = -1
		KEY_KP_2:               dy =  1
		KEY_KP_4:               dx = -1
		KEY_KP_6:               dx =  1
		KEY_KP_7:               dx = -1; dy = -1
		KEY_KP_9:               dx =  1; dy = -1
		KEY_KP_1:               dx = -1; dy =  1
		KEY_KP_3:               dx =  1; dy =  1
		KEY_W:                  dy = -1
		KEY_S:                  dy =  1
		KEY_A:                  dx = -1
		KEY_D:                  dx =  1
		KEY_Q:                  dx = -1; dy = -1
		KEY_E:                  dx =  1; dy = -1
		KEY_Z:                  dx = -1; dy =  1
		KEY_C:                  dx =  1; dy =  1
		KEY_KP_5, KEY_PERIOD:   is_wait = true
		_: return  # not a movement key — don't consume

	get_viewport().set_input_as_handled()

	if is_wait:
		waited.emit()
		return

	_try_move(dx, dy)


func _try_move(dx: int, dy: int) -> void:
	var tx: int = _player_x + dx
	var ty: int = _player_y + dy
	var step: Dictionary = MovementSystem.check_step(_map, _player_x, _player_y, tx, ty)

	if step["is_door"]:
		_open_door_at(tx, ty)
		return

	if not step["ok"]:
		return  # blocked by wall, tree, etc. — silent bump

	_player_x = tx
	_player_y = ty
	_center_camera_on(_player_x, _player_y)
	_recompute_fov()
	queue_redraw()
	moved.emit(_player_x, _player_y)

	if step["is_exit"]:
		zone_exit_reached.emit(_player_x, _player_y)


func _open_door_at(x: int, y: int) -> void:
	var closed_tile: int = _map.get_tile(x, y)
	if not MovementSystem.is_closed_door(closed_tile):
		return
	var open_tile: int = MovementSystem.open_door(closed_tile)
	_map.set_tile(x, y, open_tile)
	_recompute_fov()  # open door changes LOS
	queue_redraw()
	door_toggled.emit(x, y, true)


# ── Camera and FOV ───────────────────────────────────────────────────────────

func _center_camera_on(cx: int, cy: int) -> void:
	if _map == null:
		return
	var half: int = VIEWPORT_SIZE / 2
	_camera_x = clampi(cx - half, 0, maxi(0, _map.width - VIEWPORT_SIZE))
	_camera_y = clampi(cy - half, 0, maxi(0, _map.height - VIEWPORT_SIZE))


func _recompute_fov() -> void:
	if _map == null:
		_visible = {}
		return
	_vision_radius = FovSystem.lookout_radius(_perception, _env_modifier) \
		if _is_lookout_position() \
		else FovSystem.effective_radius(_perception, _env_modifier)
	_visible = FovSystem.compute_visible(_player_x, _player_y, _vision_radius, _map)
	for pos: Vector2i in _visible:
		_seen[pos] = true


# Returns true when the player is standing on a wall-walk or elevated position
# that grants the FovSystem.LOOKOUT_BONUS radius increase.
# Duck-typed check: castle siege maps expose wall_walkways rects; other templates
# may be added here as their data formats are confirmed.
func _is_lookout_position() -> bool:
	if _map == null:
		return false
	var wws: Variant = _map.get("wall_walkways")
	if wws is Array:
		for ww: Dictionary in (wws as Array):
			if _player_x >= ww.get("lx", -1) and _player_x <= ww.get("rx", -1) \
					and _player_y >= ww.get("ly", -1) and _player_y <= ww.get("ry", -1):
				return true
	return false


# ── Rendering ────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), BG_DEFAULT)

	if _map == null:
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = CELL_SIZE - 2

	for vy in range(VIEWPORT_SIZE):
		for vx in range(VIEWPORT_SIZE):
			var mx: int = _camera_x + vx
			var my: int = _camera_y + vy
			var cell_pos: Vector2 = Vector2(vx * CELL_SIZE, vy * CELL_SIZE)
			var grid_pos: Vector2i = Vector2i(mx, my)

			if not _visible.get(grid_pos, false):
				if not _seen.get(grid_pos, false):
					# Never seen — pure dark.
					draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), HIDDEN_BG)
				else:
					# Explored but not currently visible — draw dimmed tile.
					var rem_tile: int = _map.get_tile(mx, my)
					var rem_bg: Color = AsciiMapGenerator.get_bg_color(rem_tile)
					if rem_bg.a > 0.01:
						draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)),
							Color(rem_bg.r * DIM_FACTOR, rem_bg.g * DIM_FACTOR,
								rem_bg.b * DIM_FACTOR, 1.0))
					var rem_glyph: String = AsciiMapGenerator.get_glyph(rem_tile, mx, my, _map)
					if not rem_glyph.is_empty() and rem_glyph != " ":
						var rem_fg: Color = AsciiMapGenerator.get_fg_color(rem_tile)
						var dfg: Color = Color(rem_fg.r * DIM_FACTOR, rem_fg.g * DIM_FACTOR,
							rem_fg.b * DIM_FACTOR, 1.0)
						draw_string(font, Vector2(cell_pos.x + 2,
							cell_pos.y + font.get_ascent(font_size)),
							rem_glyph, HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, dfg)
				continue

			var tile: int = _map.get_tile(mx, my)

			var bg: Color = AsciiMapGenerator.get_bg_color(tile)
			if bg.a > 0.01:
				draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), bg)

			var glyph: String = AsciiMapGenerator.get_glyph(tile, mx, my, _map)
			if glyph.is_empty() or glyph == " ":
				continue
			var fg: Color = AsciiMapGenerator.get_fg_color(tile)
			var text_y: float = cell_pos.y + font.get_ascent(font_size)
			draw_string(font, Vector2(cell_pos.x + 2, text_y), glyph,
				HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, fg)

	# Draw entities (above tiles, below player marker).
	# Blink off phase: skip animated glyphs so they visually pulse at 1 Hz.
	if _blink_visible:
		for e: Dictionary in _entities:
			if not e["is_alive"]:
				continue
			var ex: int = e["x"]
			var ey: int = e["y"]
			if not _visible.get(Vector2i(ex, ey), false):
				continue
			var evx: int = ex - _camera_x
			var evy: int = ey - _camera_y
			if evx < 0 or evx >= VIEWPORT_SIZE or evy < 0 or evy >= VIEWPORT_SIZE:
				continue
			var unit_type: String = e.get("unit_type", "")
			var gd: Dictionary = ENTITY_GLYPHS.get(unit_type, {"glyph": "?", "color": Color.WHITE})
			var ecell: Vector2 = Vector2(evx * CELL_SIZE, evy * CELL_SIZE)
			draw_string(font, Vector2(ecell.x + 2, ecell.y + font.get_ascent(font_size)),
				gd["glyph"], HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, gd["color"])

	# Draw player marker if visible through the current viewport window.
	var pvx: int = _player_x - _camera_x
	var pvy: int = _player_y - _camera_y
	if pvx >= 0 and pvx < VIEWPORT_SIZE and pvy >= 0 and pvy < VIEWPORT_SIZE:
		if _visible.get(Vector2i(_player_x, _player_y), false) and _blink_visible:
			var player_cell: Vector2 = Vector2(pvx * CELL_SIZE, pvy * CELL_SIZE)
			var text_y: float = player_cell.y + font.get_ascent(font_size)
			draw_string(font, Vector2(player_cell.x + 2, text_y), "@",
				HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, Color(1.0, 1.0, 0.0))
