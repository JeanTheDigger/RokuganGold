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
var _visible: Dictionary = {}  # Vector2i (map coords) -> bool


func _ready() -> void:
	custom_minimum_size = Vector2(VIEWPORT_SIZE * CELL_SIZE, VIEWPORT_SIZE * CELL_SIZE)


# Load a new map and set the player position. Camera centers on the player.
# perception: character's Perception trait (base vision radius).
# env_modifier: environmental reduction (0–4 per s4.4.2).
func set_map(
	map: AsciiMapData,
	player_x: int,
	player_y: int,
	perception: int,
	env_modifier: int = 0,
) -> void:
	_map = map
	_player_x = player_x
	_player_y = player_y
	_vision_radius = FovSystem.effective_radius(perception, env_modifier)
	_env_modifier = env_modifier
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
	_center_camera_on(_player_x, _player_y)
	queue_redraw()


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
