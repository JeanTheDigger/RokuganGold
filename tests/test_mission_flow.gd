extends GutTest
## GUT tests for MissionFlow (scripts/ui/mission_flow.gd) — UI/session glue (s56.19).
## NOTE: like the rest of the ASCII UI layer, these are written but not executed
## here (no Godot runtime). Run under GUT before relying on them.


func _province() -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.MOUNTAINS
	p.province_taint_level = 0.0
	p.stability = 50.0
	return p


func _player(banked: int = 4) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 701
	c.is_pc = true
	c.banked_ap = banked
	c.strength = 3
	c.perception = 4
	return c


func _seed(seed_type: int) -> Dictionary:
	return {
		"seed_type": seed_type,
		"strength": 2,
		"options": {},
		"roster_ready": true,
		"source_insurgency_id": -1,
	}


func _make_flow() -> MissionFlow:
	var flow := MissionFlow.new()
	add_child_autofree(flow)
	var screen := CombatScreen.new()
	add_child_autofree(screen)
	flow.setup(screen, DiceEngine.new(7))
	return flow


func test_auto_seed_launches_on_arrival() -> void:
	var flow := _make_flow()
	watch_signals(flow)
	var engageable: Array = flow.on_pc_arrived(
		_player(), _province(), [], [_seed(RosterCompositionSystem.SEED_RONIN_BANDIT)], "auto1")
	assert_true(flow.is_busy(), "AUTO seed launches a mission on arrival")
	assert_signal_emitted(flow, "mission_launched")
	assert_eq(engageable.size(), 0, "No player-initiated seeds to offer")


func test_player_seed_not_auto_launched() -> void:
	var flow := _make_flow()
	var engageable: Array = flow.on_pc_arrived(
		_player(), _province(), [], [_seed(RosterCompositionSystem.SEED_MAHO_CULT)], "p1")
	assert_false(flow.is_busy(), "PLAYER_INITIATED seed does not auto-launch")
	assert_eq(engageable.size(), 1, "It is offered as engageable instead")


func test_engage_launches_and_spends_ap() -> void:
	var flow := _make_flow()
	var pc := _player(2)
	watch_signals(flow)
	var ok: bool = flow.engage(
		pc, _seed(RosterCompositionSystem.SEED_MAHO_CULT), _province(), [], "eng1")
	assert_true(ok, "Engage launches the mission")
	assert_eq(pc.banked_ap, 1, "ENGAGE_MISSION spent 1 banked AP")
	assert_true(flow.is_busy(), "Mission is now active")
	assert_signal_emitted(flow, "mission_launched")


func test_engage_blocked_without_ap() -> void:
	var flow := _make_flow()
	watch_signals(flow)
	var ok: bool = flow.engage(
		_player(0), _seed(RosterCompositionSystem.SEED_MAHO_CULT), _province(), [], "eng2")
	assert_false(ok, "Engage fails without AP")
	assert_false(flow.is_busy(), "No mission launched")
	assert_signal_emitted(flow, "mission_blocked")


func test_no_double_launch_while_busy() -> void:
	var flow := _make_flow()
	flow.on_pc_arrived(
		_player(), _province(), [], [_seed(RosterCompositionSystem.SEED_RONIN_BANDIT)], "busy1")
	assert_true(flow.is_busy(), "First mission active")
	watch_signals(flow)
	# A second AUTO arrival while busy must not start a new mission.
	flow.on_pc_arrived(
		_player(), _province(), [], [_seed(RosterCompositionSystem.SEED_RONIN_BANDIT)], "busy2")
	assert_signal_emitted(flow, "mission_blocked")


func test_end_mission_resets_busy_and_allows_relaunch() -> void:
	var flow := _make_flow()
	flow.on_pc_arrived(
		_player(), _province(), [], [_seed(RosterCompositionSystem.SEED_RONIN_BANDIT)], "r1")
	assert_true(flow.is_busy(), "First mission active")
	flow.end_mission()
	assert_false(flow.is_busy(), "end_mission frees the screen")
	# A new AUTO arrival can now launch.
	flow.on_pc_arrived(
		_player(), _province(), [], [_seed(RosterCompositionSystem.SEED_RONIN_BANDIT)], "r2")
	assert_true(flow.is_busy(), "A second mission launches after teardown")
