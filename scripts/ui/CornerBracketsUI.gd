@tool
extends Control

@export var bracket_size: float = 10.0
@export var bracket_color: Color = Color("#8b2020")
@export var bracket_width: float = 1.0
@export var bracket_inset: float = 4.0
@export var line_ratio: float = 0.25
@export var gleam_enabled: bool = true
@export var gleam_color: Color = Color("#c8a96e")
@export var gleam_speed: float = 0.08
@export var gleam_width: float = 0.06
@export var gleam_intensity: float = 0.5
@export var gleam_offset: float = 0.0

var _time: float = 0.0

func _process(delta: float) -> void:
	if gleam_enabled:
		_time += delta
		queue_redraw()

func _get_gleam_brightness(point: Vector2) -> float:
	if not gleam_enabled:
		return 0.0
	var t: float = fmod(_time * gleam_speed + gleam_offset, 1.0)
	var pos: float = (point.x / size.x + point.y / size.y) / 2.0
	var dist: float = abs(pos - t)
	dist = min(dist, 1.0 - dist)
	var glow: float = smoothstep(gleam_width, 0.0, dist) * gleam_intensity
	return glow

func _draw_gleam_line(from: Vector2, to: Vector2) -> void:
	var steps: int = 20
	for step in range(steps):
		var t: float = float(step) / float(steps)
		var t_next: float = float(step + 1) / float(steps)
		var p1: Vector2 = from.lerp(to, t)
		var p2: Vector2 = from.lerp(to, t_next)
		var mid: Vector2 = from.lerp(to, (t + t_next) / 2.0)
		var glow: float = _get_gleam_brightness(mid)
		var col: Color = bracket_color.lerp(gleam_color, glow)
		draw_line(p1, p2, col, bracket_width)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var s: float = bracket_size
	var i: float = bracket_inset

	var h_line_start: float = w * (0.5 - line_ratio / 2.0)
	var h_line_end: float = w * (0.5 + line_ratio / 2.0)
	var v_line_start: float = h * (0.5 - line_ratio / 2.0)
	var v_line_end: float = h * (0.5 + line_ratio / 2.0)

	# Top-left corner
	_draw_gleam_line(Vector2(i, i + s), Vector2(i, i))
	_draw_gleam_line(Vector2(i, i), Vector2(i + s, i))

	# Top-right corner
	_draw_gleam_line(Vector2(w - i - s, i), Vector2(w - i, i))
	_draw_gleam_line(Vector2(w - i, i), Vector2(w - i, i + s))

	# Bottom-left corner
	_draw_gleam_line(Vector2(i, h - i - s), Vector2(i, h - i))
	_draw_gleam_line(Vector2(i, h - i), Vector2(i + s, h - i))

	# Bottom-right corner
	_draw_gleam_line(Vector2(w - i - s, h - i), Vector2(w - i, h - i))
	_draw_gleam_line(Vector2(w - i, h - i), Vector2(w - i, h - i - s))

	# Top line
	_draw_gleam_line(Vector2(h_line_start, i), Vector2(h_line_end, i))

	# Bottom line
	_draw_gleam_line(Vector2(h_line_start, h - i), Vector2(h_line_end, h - i))

	# Left line
	_draw_gleam_line(Vector2(i, v_line_start), Vector2(i, v_line_end))

	# Right line
	_draw_gleam_line(Vector2(w - i, v_line_start), Vector2(w - i, v_line_end))
