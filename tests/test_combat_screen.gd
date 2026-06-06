extends GutTest
## GUT tests for CombatScreen (scripts/ui/combat_screen.gd).
## Verifies the connective layer: MissionSession → CombatController →
## AsciiMapView + CombatHUD, signal relays, and teardown.


func _make_open_map(w: int = 20, h: int = 20) -> AsciiMapData:
	var m := AsciiMapData.new()
	m.width  = w
	m.height = h
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	return m


func _make_player() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 777
	c.reflexes = 3; c.awareness = 3; c.stamina = 3; c.willpower = 3
	c.agility = 3; c.intelligence = 3; c.strength = 3; c.perception = 3
	c.void_ring = 3
	c.skills = {"Kenjutsu": 3}
	return c


func _make_session() -> MissionSession:
	var s := MissionSession.new()
	s.map        = _make_open_map()
	s.placements = [{"unit_type": "BANDIT_RABBLE", "x": 8, "y": 8, "seed": 0}]
	s.entry_pos  = Vector2i(5, 5)
	s.water_ring = 3
	s.perception = 3
	return s


func _make_screen() -> CombatScreen:
	var screen := CombatScreen.new()
	add_child_autofree(screen)
	return screen


func _first_enemy(cc: CombatController) -> CombatController.EntityState:
	for es: CombatController.EntityState in cc.get_all_entities():
		if es.faction == CombatController.FACTION_ENEMY:
			return es
	return null


func test_start_mission_attaches_controller() -> void:
	var screen := _make_screen()
	var ok: bool = screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	assert_true(ok, "start_mission succeeds on a valid session")
	assert_not_null(screen.get_controller(), "Controller created and held")
	assert_false(screen.is_turn_based(), "Fresh mission starts in real-time")


func test_start_mission_rejects_invalid_session() -> void:
	var screen := _make_screen()
	var bad := MissionSession.new()  # no map → invalid
	assert_false(screen.start_mission(bad, _make_player(), DiceEngine.new(1)),
		"Invalid session is rejected")
	assert_null(screen.get_controller(), "No controller created on failure")


func test_engage_reflected_through_screen() -> void:
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	_first_enemy(screen.get_controller()).alert_state = AsciiMapEnvironment.AlertState.ALERT
	assert_true(screen.is_turn_based(), "Screen reports turn-based once an enemy is ALERT")


func test_combat_mode_changed_relayed() -> void:
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	watch_signals(screen)
	# Simulate the view detecting the transition and forwarding it.
	screen._view.combat_mode_changed.emit(true)
	assert_signal_emitted(screen, "combat_mode_changed",
		"Screen re-emits the view's combat_mode_changed")


func test_combat_ended_relayed() -> void:
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	watch_signals(screen)
	screen._view.combat_ended.emit()
	assert_signal_emitted(screen, "combat_ended", "Screen re-emits combat_ended")


func test_mission_complete_relayed() -> void:
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	watch_signals(screen)
	screen._view.mission_complete.emit()
	assert_signal_emitted(screen, "mission_complete", "Screen re-emits mission_complete")


func test_end_mission_detaches() -> void:
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	assert_true(screen._view.is_in_combat(), "Mission loaded")
	screen.end_mission()
	assert_false(screen._view.is_in_combat(), "Controller detached on end_mission")
	assert_null(screen.get_controller(), "Controller cleared")


func test_end_mission_disconnects_signals() -> void:
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	screen.end_mission()
	watch_signals(screen)
	# After teardown, a stray view signal must not be relayed.
	screen._view.combat_ended.emit()
	assert_signal_not_emitted(screen, "combat_ended",
		"Relays are disconnected after end_mission")


func test_restart_mission_does_not_double_connect() -> void:
	# Re-starting without end_mission must not double-connect signals.
	var screen := _make_screen()
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(1))
	screen.start_mission(_make_session(), _make_player(), DiceEngine.new(2))
	watch_signals(screen)
	screen._view.combat_ended.emit()
	# Exactly one relay, not two.
	assert_signal_emit_count(screen, "combat_ended", 1,
		"combat_ended relayed exactly once after a re-start")
