@tool
extends Control

@export var bracket_size: float = 10.0
@export var bracket_color: Color = Color("#8b2020")
@export var bracket_width: float = 1.0
@export var bracket_inset: float = 4.0
@export var line_ratio: float = 0.25

func _draw():
	var w = size.x
	var h = size.y
	var s = bracket_size
	var i = bracket_inset

	# Calculate line start/end based on ratio of total edge length
	var h_line_start = w * (0.5 - line_ratio / 2.0)
	var h_line_end = w * (0.5 + line_ratio / 2.0)
	var v_line_start = h * (0.5 - line_ratio / 2.0)
	var v_line_end = h * (0.5 + line_ratio / 2.0)

	# Top-left corner
	draw_line(Vector2(i, i + s), Vector2(i, i), bracket_color, bracket_width)
	draw_line(Vector2(i, i), Vector2(i + s, i), bracket_color, bracket_width)

	# Top-right corner
	draw_line(Vector2(w - i - s, i), Vector2(w - i, i), bracket_color, bracket_width)
	draw_line(Vector2(w - i, i), Vector2(w - i, i + s), bracket_color, bracket_width)

	# Bottom-left corner
	draw_line(Vector2(i, h - i - s), Vector2(i, h - i), bracket_color, bracket_width)
	draw_line(Vector2(i, h - i), Vector2(i + s, h - i), bracket_color, bracket_width)

	# Bottom-right corner
	draw_line(Vector2(w - i - s, h - i), Vector2(w - i, h - i), bracket_color, bracket_width)
	draw_line(Vector2(w - i, h - i), Vector2(w - i, h - i - s), bracket_color, bracket_width)

	# Top line (centered, only covers line_ratio of total width)
	draw_line(Vector2(h_line_start, i), Vector2(h_line_end, i), bracket_color, bracket_width)

	# Bottom line
	draw_line(Vector2(h_line_start, h - i), Vector2(h_line_end, h - i), bracket_color, bracket_width)

	# Left line (centered, only covers line_ratio of total height)
	draw_line(Vector2(i, v_line_start), Vector2(i, v_line_end), bracket_color, bracket_width)

	# Right line
	draw_line(Vector2(w - i, v_line_start), Vector2(w - i, v_line_end), bracket_color, bracket_width)
