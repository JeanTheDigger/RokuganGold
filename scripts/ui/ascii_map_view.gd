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

var _map: AsciiMapData = null
var _player_x: int = 15
var _player_y: int = 15
# Top-left corner of the viewport in map coordinates.
var _camera_x: int = 0
var _camera_y: int = 0
var _vision_radius: int = 4
var _env_modifier: int = 0
var _water_ring: int = 3
var _visible: Dictionary = {}  # Vector2i (map coords) -> bool
var _look_mode: bool = false   # true: arrow keys pan camera, not player


func _ready() -> void:
	custom_minimum_size = Vector2(VIEWPORT_SIZE * CELL_SIZE, VIEWPORT_SIZE * CELL_SIZE)
	set_process_unhandled_input(true)


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
	_vision_radius = FovSystem.effective_radius(perception, env_modifier)
	_env_modifier = env_modifier
	_water_ring = water_ring
	_look_mode = false
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
	_vision_radius = FovSystem.effective_radius(perception, env_modifier)
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
	_visible = FovSystem.compute_visible(_player_x, _player_y, _vision_radius, _map)


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
				draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), HIDDEN_BG)
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

	# Draw player marker if visible through the current viewport window.
	var pvx: int = _player_x - _camera_x
	var pvy: int = _player_y - _camera_y
	if pvx >= 0 and pvx < VIEWPORT_SIZE and pvy >= 0 and pvy < VIEWPORT_SIZE:
		if _visible.get(Vector2i(_player_x, _player_y), false):
			var player_cell: Vector2 = Vector2(pvx * CELL_SIZE, pvy * CELL_SIZE)
			var text_y: float = player_cell.y + font.get_ascent(font_size)
			draw_string(font, Vector2(player_cell.x + 2, text_y), "@",
				HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, Color(1.0, 1.0, 0.0))
