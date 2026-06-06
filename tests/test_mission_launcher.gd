extends GutTest
## GUT tests for MissionLauncher (simulation/mission_launcher.gd). GDD s56.19.
## Verifies the headless launch-request → MissionSession bridge.


func _province() -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.MOUNTAINS
	p.province_taint_level = 0.0
	p.stability = 50.0
	return p


func _player() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 601
	c.is_pc = true
	c.strength = 3
	c.perception = 4
	return c


func _seed(seed_type: int, roster_ready: bool = true) -> Dictionary:
	return {
		"seed_type": seed_type,
		"strength": 2,
		"options": {},
		"roster_ready": roster_ready,
		"source_insurgency_id": -1,
	}


func test_build_session_returns_valid_session() -> void:
	var session := MissionLauncher.build_session(
		_seed(RosterCompositionSystem.SEED_MAHO_CULT), _province(), [], "launch_test", _player())
	assert_not_null(session, "A buildable seed yields a session")
	assert_true(session.is_valid(), "Session has a map and a reachable entry tile")


func test_build_session_uses_pc_water_ring() -> void:
	# Water Ring = min(Strength, Perception) = min(3, 4) = 3.
	var session := MissionLauncher.build_session(
		_seed(RosterCompositionSystem.SEED_RONIN_BANDIT), _province(), [], "wr_test", _player())
	assert_not_null(session)
	assert_eq(session.water_ring, 3, "Session water_ring is the PC's Water Ring")
	assert_eq(session.perception, 4, "Session perception is the PC's Perception")


func test_build_session_null_on_roster_not_ready() -> void:
	# roster_ready=false (e.g. Oni Manifestation blocked) → no mission.
	var session := MissionLauncher.build_session(
		_seed(QuestSeedSelector.SEED_ONI_MANIFESTATION, false), _province(), [], "blocked", _player())
	assert_null(session, "No session when the roster is not ready")


func test_build_session_null_on_missing_inputs() -> void:
	assert_null(MissionLauncher.build_session({}, _province(), [], "x", _player()),
		"Empty seed → null")
	assert_null(MissionLauncher.build_session(
		_seed(RosterCompositionSystem.SEED_MAHO_CULT), null, [], "x", _player()),
		"Null province → null")
	assert_null(MissionLauncher.build_session(
		_seed(RosterCompositionSystem.SEED_MAHO_CULT), _province(), [], "x", null),
		"Null player → null")
