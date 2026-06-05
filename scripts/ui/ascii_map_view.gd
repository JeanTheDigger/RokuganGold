class_name AsciiMapView
extends Control
## Renders a 31×31 viewport window into a variable-size ASCII zone map (s4.4).
##
## When a CombatController is attached via set_combat_controller(), all player
## input is routed through it (bump-to-attack, stealth mode, NPC turns).
## Without a CombatController the view works as a pure explorer (original mode).
##
## Input (when focused):
##   Movement  — numpad 1-9 / WASD + Q/E/Z/C diagonals
##   Wait      — numpad 5, period
##   S         — toggle stealth mode (only active in combat)
##   Look mode — L key: arrow/numpad pan camera; Esc exits look mode
##
## Signals:
##   moved(x, y)                    player stepped to (x, y)
##   zone_exit_reached(x, y)        player stepped onto ZONE_EXIT
##   door_toggled(x, y, is_open)    a door was opened/closed
##   waited()                       player waited
##   combat_event(event)            CombatController NPC event dict
##   player_died()                  player's wounds reached lethal
##   mission_complete()             all enemies defeated
##   stealth_mode_changed(enabled)  stealth mode toggled

signal moved(new_x: int, new_y: int)
signal zone_exit_reached(exit_x: int, exit_y: int)
signal door_toggled(x: int, y: int, is_open: bool)
signal waited()
signal combat_event(event: Dictionary)
signal player_died()
signal mission_complete()
signal stealth_mode_changed(enabled: bool)

const VIEWPORT_SIZE: int = 31
const CELL_SIZE: int = 20

const BG_DEFAULT: Color = Color(0.06, 0.06, 0.08, 1.0)
const HIDDEN_BG: Color  = Color(0.06, 0.06, 0.08, 1.0)
const DIM_FACTOR: float = 0.30
const BLINK_INTERVAL: float = 0.5

# Corpse glyph.
const CORPSE_GLYPH: String = "%"
const CORPSE_COLOR: Color   = Color(0.5, 0.1, 0.1, 1.0)

# Alert state color tints applied on top of the unit's base color.
# Key = AsciiMapEnvironment.AlertState value.
const ALERT_TINTS: Dictionary = {
	0: Color(1.0, 1.0, 1.0, 1.0),  # UNAWARE    — no tint
	1: Color(1.0, 1.0, 0.3, 1.0),  # SUSPICIOUS — yellow
	2: Color(1.0, 0.3, 0.3, 1.0),  # ALERT      — red
	3: Color(0.8, 0.3, 0.8, 1.0),  # FLEEING    — magenta
}

const ENTITY_GLYPHS: Dictionary = {
	"RONIN":              {"glyph": "r", "color": Color(0.6, 0.8, 1.0)},
	"RONIN_ENFORCER":     {"glyph": "r", "color": Color(0.5, 0.7, 0.9)},
	"SIMPLE_BANDIT":      {"glyph": "t", "color": Color(0.8, 0.5, 0.1)},
	"EXPERIENCED_BANDIT": {"glyph": "t", "color": Color(0.9, 0.5, 0.1)},
	"BANDIT_LORD":        {"glyph": "T", "color": Color(1.0, 0.4, 0.0)},
	"BANDIT_THUG":        {"glyph": "t", "color": Color(0.9, 0.6, 0.2)},
	"BANDIT_RABBLE":      {"glyph": "p", "color": Color(0.7, 0.5, 0.3)},
	"REBEL_PEASANT":      {"glyph": "p", "color": Color(0.7, 0.5, 0.3)},
	"REBEL_ASHIGARU":     {"glyph": "a", "color": Color(0.7, 0.6, 0.3)},
	"REBEL_LEADER":       {"glyph": "P", "color": Color(0.9, 0.6, 0.2)},
	"NEZUMI_CHIEFTAIN":   {"glyph": "N", "color": Color(0.8, 0.6, 0.2)},
	"NEZUMI_WARRIOR":     {"glyph": "n", "color": Color(0.7, 0.5, 0.2)},
	"NEZUMI_ARCHER":      {"glyph": "n", "color": Color(0.6, 0.5, 0.2)},
	"NEZUMI_SCOUT":       {"glyph": "n", "color": Color(0.6, 0.4, 0.2)},
	"NEZUMI_BROODMOTHER": {"glyph": "N", "color": Color(0.9, 0.4, 0.1)},
	"CULT_INITIATE":      {"glyph": "c", "color": Color(0.7, 0.3, 0.8)},
	"MAHO_CULTIST":       {"glyph": "C", "color": Color(0.8, 0.2, 0.9)},
	"BLOODSPEAKER_ADEPT": {"glyph": "A", "color": Color(1.0, 0.1, 1.0)},
	"MAHO_TSUKAI":        {"glyph": "M", "color": Color(1.0, 0.2, 0.3)},
	"ZOMBIE":             {"glyph": "z", "color": Color(0.4, 0.6, 0.3)},
	"TAINTED_ANIMAL":     {"glyph": "a", "color": Color(0.5, 0.7, 0.1)},
	"TAINTED_HUMAN":      {"glyph": "T", "color": Color(0.6, 0.8, 0.1)},
	"BAKEMONO":           {"glyph": "b", "color": Color(0.5, 0.7, 0.2)},
	"BAKEMONO_WARRIOR":   {"glyph": "B", "color": Color(0.5, 0.8, 0.2)},
	"BAKEMONO_ARCHER":    {"glyph": "b", "color": Color(0.4, 0.6, 0.2)},
	"BAKEMONO_SHAMAN":    {"glyph": "S", "color": Color(0.8, 0.9, 0.2)},
	"BAKEMONO_SNEAK":     {"glyph": "b", "color": Color(0.3, 0.5, 0.1)},
	"BAKEMONO_WARMONGER": {"glyph": "B", "color": Color(0.7, 0.9, 0.1)},
	"TROLL":              {"glyph": "T", "color": Color(0.3, 0.7, 0.3)},
	"FREE_OGRE":          {"glyph": "o", "color": Color(0.8, 0.4, 0.1)},
	"FREE_OGRE_LEADER":   {"glyph": "O", "color": Color(0.9, 0.4, 0.1)},
	"FREE_OGRE_OVERLORD": {"glyph": "O", "color": Color(1.0, 0.3, 0.0)},
	"SKELETON_WARRIOR":   {"glyph": "s", "color": Color(0.8, 0.8, 0.7)},
	"OGRE_WARRIOR":       {"glyph": "O", "color": Color(0.9, 0.3, 0.1)},
	"OGRE_RAVENOUS":      {"glyph": "O", "color": Color(1.0, 0.2, 0.0)},
	"OGRE_WARLORD":       {"glyph": "O", "color": Color(1.0, 0.4, 0.0)},
	"ONI_SPAWN":          {"glyph": "o", "color": Color(1.0, 0.1, 0.1)},
	"HIDA_BUSHI":         {"glyph": "H", "color": Color(0.3, 0.5, 1.0)},
	"HIRUMA_SCOUT":       {"glyph": "h", "color": Color(0.2, 0.8, 0.7)},
	"KUNI_WITCH_HUNTER":  {"glyph": "K", "color": Color(0.9, 0.9, 1.0)},
}

var _map: AsciiMapData = null
var _player_x: int = 15
var _player_y: int = 15
var _camera_x: int = 0
var _camera_y: int = 0
var _perception: int = 4
var _vision_radius: int = 4
var _env_modifier: int = 0
var _water_ring: int = 3
var _visible: Dictionary = {}
var _seen: Dictionary = {}
var _look_mode: bool = false
var _entities: Array = []
var _blink_timer: float = 0.0
var _blink_visible: bool = true

# ── Combat integration ────────────────────────────────────────────────────────
## Active CombatController; null when not in a combat mission.
var _combat_controller: CombatController = null
## True when the player has toggled stealth movement mode.
var _stealth_mode: bool = false


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


# ── Map loading ───────────────────────────────────────────────────────────────

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


func look_at(map_x: int, map_y: int) -> void:
	_center_camera_on(map_x, map_y)
	queue_redraw()


func reset_camera() -> void:
	_look_mode = false
	_center_camera_on(_player_x, _player_y)
	queue_redraw()


# ── Combat controller integration ─────────────────────────────────────────────

## Attach a CombatController. All player input is routed through it.
## Call after set_map() (the CC shares the same map object).
func set_combat_controller(cc: CombatController) -> void:
	_combat_controller = cc
	_stealth_mode = false
	_sync_entities_from_cc()
	# Sync player position from CC.
	var ppos: Vector2i = cc.get_player_pos()
	if ppos.x >= 0:
		_player_x = ppos.x
		_player_y = ppos.y
	_center_camera_on(_player_x, _player_y)
	_recompute_fov()
	queue_redraw()


## Detach the CombatController (return to explore mode).
func clear_combat_controller() -> void:
	_combat_controller = null
	_stealth_mode = false


## Returns true when a CombatController is active.
func is_in_combat() -> bool:
	return _combat_controller != null


## Returns true when stealth mode is active.
func is_in_stealth_mode() -> bool:
	return _stealth_mode


## Returns the current round number from the active CombatController (0 if none).
func get_current_round() -> int:
	if _combat_controller == null:
		return 0
	return _combat_controller.get_round()


## Sync the entity display list from CombatController state.
func _sync_entities_from_cc() -> void:
	if _combat_controller == null:
		return
	_entities = _combat_controller.get_entity_display_data()
	# Update player position from CC.
	var ppos: Vector2i = _combat_controller.get_player_pos()
	if ppos.x >= 0:
		_player_x = ppos.x
		_player_y = ppos.y


## Advance all NPC turns and sync display. Called after every player action.
func _run_npc_turns_and_sync() -> void:
	if _combat_controller == null:
		return
	var events: Array = _combat_controller.advance_npc_turns()
	_sync_entities_from_cc()
	_recompute_fov()
	queue_redraw()
	for ev: Dictionary in events:
		combat_event.emit(ev)
		# Flatten morale events nested inside npc_attacked results.
		for mev: Dictionary in ev.get("attack_result", {}).get("morale_events", []):
			combat_event.emit(mev)
	# Check terminal states — signals only; combat_event already emitted in the loop above.
	if _combat_controller.is_player_dead():
		player_died.emit()
	elif _combat_controller.is_mission_complete():
		mission_complete.emit()


## Process the Dictionary returned by CombatController's player action methods.
## Applies position updates, door changes, signals, and triggers NPC turns.
func _apply_player_result(result: Dictionary) -> void:
	if result.is_empty():
		return

	if result.get("blocked"):
		return  # Nothing happened.

	if result.get("opened_door"):
		_recompute_fov()
		queue_redraw()
		door_toggled.emit(result["door_x"], result["door_y"], true)
		_run_npc_turns_and_sync()
		return

	if result.get("exited"):
		zone_exit_reached.emit(result.get("exit_x", _player_x), result.get("exit_y", _player_y))
		return

	if result.get("moved"):
		_player_x = result.get("x", _player_x)
		_player_y = result.get("y", _player_y)
		_center_camera_on(_player_x, _player_y)
		_recompute_fov()
		queue_redraw()
		moved.emit(_player_x, _player_y)
		_run_npc_turns_and_sync()
		return

	if result.get("attacked") or result.has("success"):
		# bump-to-attack or stealth kill attempt (success or failure).
		if result.get("success", false):
			combat_event.emit(result)
		elif result.get("approach_failed") or result.get("attack_failed"):
			# Stealth approach/attack failed → target alerted; show stealth_failed.
			combat_event.emit({"type": "stealth_failed"})
		else:
			combat_event.emit(result)
		# Emit any morale events triggered by the kill.
		for mev: Dictionary in result.get("attack_result", {}).get("morale_events", []):
			combat_event.emit(mev)
		# Mission complete if last enemy fell.
		if _combat_controller != null and _combat_controller.is_mission_complete():
			_sync_entities_from_cc()
			_recompute_fov()
			queue_redraw()
			combat_event.emit({"type": "mission_complete"})
			mission_complete.emit()
			return
		_sync_entities_from_cc()
		_recompute_fov()
		queue_redraw()
		if _combat_controller != null and _combat_controller.is_player_dead():
			combat_event.emit({"type": "player_died"})
			player_died.emit()
			return
		_run_npc_turns_and_sync()
		return

	if result.get("waited"):
		waited.emit()
		_run_npc_turns_and_sync()
		return


# ── Entity layer (non-combat) ─────────────────────────────────────────────────

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


func kill_entity_at(x: int, y: int) -> void:
	for e: Dictionary in _entities:
		if e["is_alive"] and e["x"] == x and e["y"] == y:
			e["is_alive"] = false
			break
	queue_redraw()


func move_entity(fx: int, fy: int, tx: int, ty: int) -> void:
	for e: Dictionary in _entities:
		if e["is_alive"] and e["x"] == fx and e["y"] == fy:
			e["x"] = tx
			e["y"] = ty
			break
	queue_redraw()


func get_entities_at(x: int, y: int) -> Array:
	var result: Array = []
	for e: Dictionary in _entities:
		if e["is_alive"] and e["x"] == x and e["y"] == y:
			result.append(e)
	return result


func _make_entity(p: Dictionary, faction: String) -> Dictionary:
	return {
		"x":          p.get("x", 0),
		"y":          p.get("y", 0),
		"unit_type":  p.get("unit_type", ""),
		"faction":    faction,
		"is_alive":   true,
		"alert_state": 0,
		"morale_broken": false,
	}


# ── Keyboard input ────────────────────────────────────────────────────────────

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

	# Look mode: pan camera.
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

	# S key toggles stealth mode (combat only).
	if key.keycode == KEY_S and not key.echo and _combat_controller != null:
		_stealth_mode = not _stealth_mode
		stealth_mode_changed.emit(_stealth_mode)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	# Movement direction mapping.
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
		_: return

	get_viewport().set_input_as_handled()

	if is_wait:
		if _combat_controller != null:
			var wait_result: Dictionary = _combat_controller.wait_player()
			_apply_player_result(wait_result)
		else:
			waited.emit()
		return

	_try_move(dx, dy)


func _try_move(dx: int, dy: int) -> void:
	# ── Combat mode ────────────────────────────────────────────────────────────
	if _combat_controller != null:
		var result: Dictionary
		if _stealth_mode:
			result = _combat_controller.try_stealth_move(dx, dy)
			# Stealth kill available → execute immediately (DF bump-to-kill).
			if result.get("stealth_kill_available"):
				var kill_result: Dictionary = _combat_controller.execute_stealth_kill(
					result["target_id"]
				)
				_apply_player_result(kill_result)
				return
		else:
			result = _combat_controller.try_move_player(dx, dy)

		_apply_player_result(result)
		return

	# ── Explore mode (no combat controller) ────────────────────────────────────
	var tx: int = _player_x + dx
	var ty: int = _player_y + dy
	var step: Dictionary = MovementSystem.check_step(_map, _player_x, _player_y, tx, ty)

	if step["is_door"]:
		_open_door_at(tx, ty)
		return

	if not step["ok"]:
		return

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
	_recompute_fov()
	queue_redraw()
	door_toggled.emit(x, y, true)


# ── Camera and FOV ────────────────────────────────────────────────────────────

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


# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), BG_DEFAULT)
	if _map == null:
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = CELL_SIZE - 2

	# ── Tile layer ─────────────────────────────────────────────────────────────
	for vy in range(VIEWPORT_SIZE):
		for vx in range(VIEWPORT_SIZE):
			var mx: int = _camera_x + vx
			var my: int = _camera_y + vy
			var cell_pos: Vector2 = Vector2(vx * CELL_SIZE, vy * CELL_SIZE)
			var grid_pos: Vector2i = Vector2i(mx, my)

			if not _visible.get(grid_pos, false):
				if not _seen.get(grid_pos, false):
					draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), HIDDEN_BG)
				else:
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

	# ── Corpse layer (combat mode) ─────────────────────────────────────────────
	if _combat_controller != null and _blink_visible:
		for corpse_pos: Vector2i in _combat_controller.get_corpse_positions():
			if not _visible.get(corpse_pos, false):
				continue
			var cvx: int = corpse_pos.x - _camera_x
			var cvy: int = corpse_pos.y - _camera_y
			if cvx < 0 or cvx >= VIEWPORT_SIZE or cvy < 0 or cvy >= VIEWPORT_SIZE:
				continue
			var ccell: Vector2 = Vector2(cvx * CELL_SIZE, cvy * CELL_SIZE)
			draw_string(font, Vector2(ccell.x + 2, ccell.y + font.get_ascent(font_size)),
				CORPSE_GLYPH, HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, CORPSE_COLOR)

	# ── Entity layer ───────────────────────────────────────────────────────────
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
			var gd: Dictionary = ENTITY_GLYPHS.get(unit_type,
				{"glyph": "?", "color": Color.WHITE})
			# Apply alert state tint when in combat mode.
			var draw_color: Color = gd["color"]
			if _combat_controller != null:
				var alert_st: int = e.get("alert_state", 0)
				var tint: Color = ALERT_TINTS.get(alert_st, Color.WHITE)
				draw_color = Color(
					draw_color.r * tint.r,
					draw_color.g * tint.g,
					draw_color.b * tint.b, 1.0)
				# Dim morale-broken entities.
				if e.get("morale_broken", false):
					draw_color = Color(
						draw_color.r * 0.5,
						draw_color.g * 0.5,
						draw_color.b * 0.5, 1.0)
			var ecell: Vector2 = Vector2(evx * CELL_SIZE, evy * CELL_SIZE)
			draw_string(font, Vector2(ecell.x + 2, ecell.y + font.get_ascent(font_size)),
				gd["glyph"], HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, draw_color)

	# ── Player marker ──────────────────────────────────────────────────────────
	var pvx: int = _player_x - _camera_x
	var pvy: int = _player_y - _camera_y
	if pvx >= 0 and pvx < VIEWPORT_SIZE and pvy >= 0 and pvy < VIEWPORT_SIZE:
		if _visible.get(Vector2i(_player_x, _player_y), false) and _blink_visible:
			var player_cell: Vector2 = Vector2(pvx * CELL_SIZE, pvy * CELL_SIZE)
			var text_y: float = player_cell.y + font.get_ascent(font_size)
			# Stealth mode: player renders in blue-grey instead of yellow.
			var player_color: Color = Color(0.5, 0.8, 1.0) if _stealth_mode \
				else Color(1.0, 1.0, 0.0)
			draw_string(font, Vector2(player_cell.x + 2, text_y), "@",
				HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE, font_size, player_color)
