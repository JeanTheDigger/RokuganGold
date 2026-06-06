class_name CombatScreen
extends Control
## Connective layer that boots an ASCII map mission and binds it to the UI.
##
## Ties together the pieces that were previously only wired in tests:
##   MissionSession (data) → CombatController (sim) → AsciiMapView + CombatHUD (UI).
##
## A mission owner (the world-map → mission entry point, design-pending s56/s60)
## calls start_mission() with a prepared MissionSession and the player's character.
## CombatScreen creates the CombatController, attaches it to the map view, keeps
## the HUD in sync, and relays the view's signals up to the owner.
##
## Real-time vs. turn-based combat (GDD s40.x) is owned by the CombatController;
## this screen simply forwards combat_mode_changed and refreshes the HUD.

## Re-emitted from AsciiMapView so the mission owner can react.
signal mission_complete()
signal player_died()
signal zone_exit_reached(exit_x: int, exit_y: int)
## Forwarded from AsciiMapView (GDD s40.x): the zone flipped real-time ↔ turn-based.
signal combat_mode_changed(turn_based: bool)
## Forwarded from AsciiMapView (GDD s40.x): a successful End Combat returned the
## zone to real-time.
signal combat_ended()

var _view: AsciiMapView = null
var _hud: CombatHUD = null
var _cc: CombatController = null
var _water_ring: int = 3


func _ready() -> void:
	# Build child UI if it was not provided in the scene.
	if _view == null:
		_view = AsciiMapView.new()
		_view.name = "AsciiMapView"
		_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_view)
	if _hud == null:
		_hud = CombatHUD.new()
		_hud.name = "CombatHUD"
		_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hud)
		_hud.hide()


## Boot a mission: create the controller, bind it to the view, wire the HUD,
## and connect signal relays. Returns false if the session is invalid.
func start_mission(
		session: MissionSession,
		player: L5RCharacterData,
		dice: DiceEngine,
) -> bool:
	if session == null or not session.is_valid() or player == null:
		return false

	_water_ring = session.water_ring
	_cc = CombatController.create(session, player, dice)

	_view.set_map(
		session.map,
		session.entry_pos.x, session.entry_pos.y,
		session.perception, session.fov_modifier(), session.water_ring)
	_view.set_combat_controller(_cc)

	_connect_view_signals()

	_hud.reset(session.water_ring)
	_hud.update_from_cc(_cc, session.water_ring)
	_hud.show()
	return true


## Tear down the active mission and return the view to plain exploration.
func end_mission() -> void:
	_disconnect_view_signals()
	if _view != null:
		_view.clear_combat_controller()
	if _hud != null:
		_hud.hide()
	_cc = null


## The active CombatController (null when no mission is running).
func get_controller() -> CombatController:
	return _cc


## True when the active zone is in turn-based combat (GDD s40.x).
func is_turn_based() -> bool:
	return _cc != null and _cc.is_turn_based()


# -- Signal wiring ------------------------------------------------------------

func _connect_view_signals() -> void:
	# Idempotent: drop any stale connections first so a re-start_mission without
	# an intervening end_mission does not double-connect (Godot errors on that).
	_disconnect_view_signals()
	_view.combat_event.connect(_on_combat_event)
	_view.combat_mode_changed.connect(_on_combat_mode_changed)
	_view.stealth_mode_changed.connect(_on_stealth_mode_changed)
	_view.moved.connect(_on_moved)
	_view.waited.connect(_on_waited)
	_view.combat_ended.connect(_on_combat_ended)
	_view.mission_complete.connect(_on_mission_complete)
	_view.player_died.connect(_on_player_died)
	_view.zone_exit_reached.connect(_on_zone_exit_reached)


func _disconnect_view_signals() -> void:
	if _view == null:
		return
	for s: Array in [
		["combat_event", _on_combat_event],
		["combat_mode_changed", _on_combat_mode_changed],
		["stealth_mode_changed", _on_stealth_mode_changed],
		["moved", _on_moved],
		["waited", _on_waited],
		["combat_ended", _on_combat_ended],
		["mission_complete", _on_mission_complete],
		["player_died", _on_player_died],
		["zone_exit_reached", _on_zone_exit_reached],
	]:
		if _view.is_connected(s[0], s[1]):
			_view.disconnect(s[0], s[1])


# -- Relays -------------------------------------------------------------------

func _refresh_hud() -> void:
	if _hud != null and _cc != null:
		_hud.update_from_cc(_cc, _water_ring)


func _on_combat_event(event: Dictionary) -> void:
	if _hud != null:
		_hud.push_event(event)
	_refresh_hud()


func _on_combat_mode_changed(turn_based: bool) -> void:
	_refresh_hud()
	combat_mode_changed.emit(turn_based)


func _on_stealth_mode_changed(enabled: bool) -> void:
	if _hud != null:
		_hud.set_mode(enabled)


func _on_moved(_x: int, _y: int) -> void:
	_refresh_hud()


func _on_waited() -> void:
	_refresh_hud()


func _on_combat_ended() -> void:
	_refresh_hud()
	combat_ended.emit()


func _on_mission_complete() -> void:
	_refresh_hud()
	mission_complete.emit()


func _on_player_died() -> void:
	_refresh_hud()
	player_died.emit()


func _on_zone_exit_reached(exit_x: int, exit_y: int) -> void:
	zone_exit_reached.emit(exit_x, exit_y)
