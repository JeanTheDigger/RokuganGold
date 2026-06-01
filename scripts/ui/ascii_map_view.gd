class_name AsciiMapView
extends Control
## Renders a 31×31 ASCII tile map for a Lesser Zone (s4.4).
##
## Call set_map() to load a map and position the player. The view redraws
## automatically. AsciiMapGenerator.get_glyph() and get_fg_color() supply the
## display data; FovSystem.compute_visible() determines which tiles are shown.
##
## Layout: each tile cell is CELL_SIZE × CELL_SIZE pixels. The full grid is
## MAP_SIZE * CELL_SIZE wide and tall. Size this control to at least
## (31 * CELL_SIZE) × (31 * CELL_SIZE) in the scene.


const MAP_SIZE: int = AsciiMapData.MAP_SIZE  # 31
const CELL_SIZE: int = 20  # pixels per tile cell

# Colour of the visible-but-dark background behind each glyph.
const BG_DEFAULT: Color = Color(0.06, 0.06, 0.08, 1.0)
# Tiles outside FOV are not rendered (blank = BG_DEFAULT only).
const HIDDEN_BG: Color = Color(0.06, 0.06, 0.08, 1.0)

var _map: AsciiMapData = null
var _player_x: int = AsciiMapData.MAP_SIZE / 2
var _player_y: int = AsciiMapData.MAP_SIZE / 2
var _vision_radius: int = 4
var _env_modifier: int = 0
var _visible: Dictionary = {}  # Vector2i -> bool

# Font used for glyph rendering.  Assign a monospace font in the scene editor
# or via set_font_override("font", monospace_font) for best results.
# Falls back to the theme default if none is assigned.


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE * CELL_SIZE, MAP_SIZE * CELL_SIZE)


# Load a new map and update the player's position and vision.
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
	_recompute_fov()
	queue_redraw()


# Update only the player position and vision without changing the map.
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
	_recompute_fov()
	queue_redraw()


func _recompute_fov() -> void:
	if _map == null:
		_visible = {}
		return
	_visible = FovSystem.compute_visible(_player_x, _player_y, _vision_radius, _map)


func _draw() -> void:
	# Dark background for the entire map area.
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), BG_DEFAULT)

	if _map == null:
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = CELL_SIZE - 2  # Slightly smaller than cell for padding.

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var cell_pos: Vector2 = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var grid_pos: Vector2i = Vector2i(x, y)

			if not _visible.get(grid_pos, false):
				draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), HIDDEN_BG)
				continue

			var tile: int = _map.get_tile(x, y)

			# Background colour (only non-transparent tiles need a rect).
			var bg: Color = AsciiMapGenerator.get_bg_color(tile)
			if bg.a > 0.01:
				draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), bg)

			# Glyph.
			var glyph: String = AsciiMapGenerator.get_glyph(tile, x, y, _map)
			if glyph.is_empty() or glyph == " ":
				continue
			var fg: Color = AsciiMapGenerator.get_fg_color(tile)
			var text_y: float = cell_pos.y + font.get_ascent(font_size)
			draw_string(font, Vector2(cell_pos.x + 2, text_y), glyph,
				HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, fg)

	# Draw player marker (@) on top of the player's tile.
	var player_cell: Vector2 = Vector2(_player_x * CELL_SIZE, _player_y * CELL_SIZE)
	var text_y: float = player_cell.y + font.get_ascent(font_size)
	draw_string(font, Vector2(player_cell.x + 2, text_y), "@",
		HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, Color(1.0, 1.0, 0.0))
