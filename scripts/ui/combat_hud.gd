class_name CombatHUD
extends Control
## Combat HUD overlay for the ASCII map view (s40, s56).
##
## Displays: round number, player wound level + penalty, movement budget,
## stealth/normal mode indicator, and a scrolling log of combat events.
##
## Usage:
##   1. Add as a CanvasLayer child above AsciiMapView.
##   2. Call update_from_cc(cc) each time the player acts.
##   3. Call push_event(event_dict) for each combat_event signal received.
##   4. Call set_mode(in_stealth) when AsciiMapView.stealth_mode_changed fires.
##   5. Call hide() when no combat session is active.


# Maximum lines kept in the event log.
const MAX_LOG_LINES: int = 8
# Background colour for the HUD panels.
const HUD_BG: Color = Color(0.06, 0.06, 0.10, 0.88)
# Colors for wound level status text.
const WOUND_COLORS: Dictionary = {
	Enums.WoundLevel.HEALTHY:   Color(0.3, 1.0, 0.3),
	Enums.WoundLevel.NICKED:    Color(0.7, 1.0, 0.3),
	Enums.WoundLevel.GRAZED:    Color(1.0, 1.0, 0.3),
	Enums.WoundLevel.HURT:      Color(1.0, 0.8, 0.1),
	Enums.WoundLevel.INJURED:   Color(1.0, 0.5, 0.1),
	Enums.WoundLevel.CRIPPLED:  Color(1.0, 0.3, 0.1),
	Enums.WoundLevel.DOWN:      Color(1.0, 0.1, 0.1),
	Enums.WoundLevel.OUT:       Color(0.8, 0.1, 0.1),
	Enums.WoundLevel.DEAD:      Color(0.5, 0.0, 0.0),
}
const WOUND_LABELS: Dictionary = {
	Enums.WoundLevel.HEALTHY:   "HEALTHY",
	Enums.WoundLevel.NICKED:    "NICKED",
	Enums.WoundLevel.GRAZED:    "GRAZED",
	Enums.WoundLevel.HURT:      "HURT",
	Enums.WoundLevel.INJURED:   "INJURED",
	Enums.WoundLevel.CRIPPLED:  "CRIPPLED",
	Enums.WoundLevel.DOWN:      "DOWN",
	Enums.WoundLevel.OUT:       "OUT",
	Enums.WoundLevel.DEAD:      "DEAD",
}

# ── State ─────────────────────────────────────────────────────────────────────

var _round: int = 0
var _wound_level: Enums.WoundLevel = Enums.WoundLevel.HEALTHY
var _wound_penalty: int = 0
var _wounds_taken: int = 0
var _water_ring: int = 3
var _in_stealth: bool = false
var _enemy_count: int = 0
var _log_lines: Array[String] = []


# ── Public API ────────────────────────────────────────────────────────────────

## Sync all HUD values from the active CombatController.
func update_from_cc(cc: CombatController, water_ring: int = 3) -> void:
	_round = cc.get_round()
	_water_ring = water_ring

	var player: CombatController.EntityState = cc.get_player()
	if player != null:
		var char_data: L5RCharacterData = player.character
		_wound_level = CharacterStats.get_wound_level(char_data)
		_wound_penalty = CharacterStats.get_wound_penalty(char_data)
		_wounds_taken = char_data.wounds_taken

	# Count living enemies.
	_enemy_count = 0
	for e: Dictionary in cc.get_entity_display_data():
		if e.get("faction") == "enemy" and e.get("is_alive", false):
			_enemy_count += 1

	queue_redraw()


## Notify the HUD that the stealth mode changed.
func set_mode(in_stealth: bool) -> void:
	_in_stealth = in_stealth
	queue_redraw()


## Push a combat event dictionary to the log (call when combat_event fires).
func push_event(event: Dictionary) -> void:
	var line: String = _format_event(event)
	if not line.is_empty():
		_log_lines.append(line)
		if _log_lines.size() > MAX_LOG_LINES:
			_log_lines.pop_front()
		queue_redraw()


## Clear the event log.
func clear_log() -> void:
	_log_lines.clear()
	queue_redraw()


## Reset all state (call when entering a new combat session).
func reset(water_ring: int = 3) -> void:
	_round = 0
	_wound_level = Enums.WoundLevel.HEALTHY
	_wound_penalty = 0
	_wounds_taken = 0
	_water_ring = water_ring
	_in_stealth = false
	_enemy_count = 0
	_log_lines.clear()
	queue_redraw()


# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var font: Font    = ThemeDB.fallback_font
	var fs: int       = 14
	var padding: int  = 6
	var line_h: int   = fs + 4

	# ── Status panel (top-left) ────────────────────────────────────────────────
	var status_w: int = 200
	var status_h: int = line_h * 5 + padding * 2
	draw_rect(Rect2(Vector2.ZERO, Vector2(status_w, status_h)), HUD_BG)

	var x0: float = padding
	var y: float  = padding + font.get_ascent(fs)

	# Round
	_draw_text(font, fs, x0, y,
		"Round: %d" % _round, Color(0.9, 0.9, 0.9))
	y += line_h

	# Wound status
	var wc: Color  = WOUND_COLORS.get(_wound_level, Color.WHITE)
	var wl: String = WOUND_LABELS.get(_wound_level, "???")
	var penalty_str: String = ""
	if _wound_penalty < 0:
		penalty_str = " (%d)" % _wound_penalty
	_draw_text(font, fs, x0, y,
		"Wounds: %s%s" % [wl, penalty_str], wc)
	y += line_h

	# Wounds taken (numeric)
	_draw_text(font, fs, x0, y,
		"HP lost: %d" % _wounds_taken, Color(0.7, 0.7, 0.7))
	y += line_h

	# Enemies remaining
	var enemy_color: Color = Color(1.0, 0.4, 0.4) if _enemy_count > 0 else Color(0.4, 1.0, 0.4)
	_draw_text(font, fs, x0, y,
		"Enemies: %d" % _enemy_count, enemy_color)
	y += line_h

	# Mode indicator
	var mode_str: String = "[STEALTH]" if _in_stealth else "[NORMAL]"
	var mode_color: Color = Color(0.5, 0.8, 1.0) if _in_stealth else Color(0.9, 0.9, 0.3)
	_draw_text(font, fs, x0, y, mode_str, mode_color)

	# ── Controls hint (bottom of status panel) ─────────────────────────────────
	var hint_y: float = float(status_h) - line_h * 0.5
	_draw_text(font, fs - 2, x0, hint_y,
		"S=stealth  .=wait  L=look", Color(0.5, 0.5, 0.5))

	# ── Event log panel (bottom-left) ─────────────────────────────────────────
	if _log_lines.is_empty():
		return

	var log_h: int   = line_h * _log_lines.size() + padding * 2
	var size: Vector2 = get_parent_area_size() if has_method("get_parent_area_size") \
		else Vector2(620, 620)
	var log_y: float = size.y - log_h
	draw_rect(Rect2(Vector2(0.0, log_y), Vector2(status_w + 40, log_h)), HUD_BG)

	var ty: float = log_y + padding + font.get_ascent(fs)
	for line: String in _log_lines:
		var lc: Color = _line_color(line)
		_draw_text(font, fs, x0, ty, line, lc)
		ty += line_h


func _draw_text(font: Font, fs: int, x: float, y: float, text: String, color: Color) -> void:
	draw_string(font, Vector2(x, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


# ── Event formatting ──────────────────────────────────────────────────────────

func _format_event(ev: Dictionary) -> String:
	var t: String = ev.get("type", "")
	match t:
		"attacked":
			var dmg: int = ev.get("damage", 0)
			var target: String = ev.get("unit_type", "enemy")
			if ev.get("killed", false):
				return "You slew the %s (%d dmg)." % [target, dmg]
			else:
				return "You struck %s for %d." % [target, dmg]

		"stealth_kill":
			var target: String = ev.get("unit_type", "enemy")
			return "Silently eliminated %s." % target

		"npc_attacked":
			var attacker: String = ev.get("unit_type", "enemy")
			var dmg: int = ev.get("damage", 0)
			if ev.get("player_killed", false):
				return "SLAIN by %s!" % attacker
			else:
				return "%s strikes you for %d!" % [attacker, dmg]

		"noise_detected":
			return "An enemy heard something…"

		"body_spotted":
			var ut: String = ev.get("unit_type", "enemy")
			return "%s found a body — alerted!" % ut

		"alarm_raised":
			return "★ ALARM RAISED — all enemies alert!"

		"morale_broken":
			var ut: String = ev.get("unit_type", "enemy")
			return "%s turns and flees!" % ut

		"npc_fled":
			var ut: String = ev.get("unit_type", "enemy")
			return "%s has fled the area." % ut

		"stealth_failed":
			return "Your cover is blown!"

		"mission_complete":
			return "Mission complete — all enemies defeated."

		"player_died":
			return "You have fallen."

		_:
			return ""


func _line_color(line: String) -> Color:
	if line.begins_with("★"):
		return Color(1.0, 0.3, 0.3)
	if line.begins_with("SLAIN") or line.begins_with("You have"):
		return Color(1.0, 0.2, 0.2)
	if line.begins_with("Silently") or line.begins_with("You slew"):
		return Color(0.4, 1.0, 0.4)
	if line.begins_with("Mission"):
		return Color(0.4, 1.0, 0.9)
	if line.contains("strikes you") or line.contains("heard"):
		return Color(1.0, 0.7, 0.2)
	if line.contains("found a body"):
		return Color(1.0, 0.5, 0.1)
	return Color(0.85, 0.85, 0.85)
