extends GutTest
## Tests for DayOrchestrator._set_wall_tower_context_flags per the Wall Tower
## context auto-detection feature (analogous to _set_court_context_flags).


# -- Helpers -------------------------------------------------------------------

func _make_character(id: int, location: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Test Character %d" % id
	c.physical_location = location
	c.travel_days_remaining = 0
	c.travel_destination = ""
	return c


func _make_wall_tower(settlement_id: int, province_id: int, si: int = 7) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = si
	s.garrison_pu = 2
	s.jade_stockpile = 20.0
	s.koku_stockpile = 5.0
	return s


func _make_non_tower(settlement_id: int, province_id: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.TOWN
	s.wall_si = 0
	return s


func _make_province(province_id: int, ss: int = 3) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = province_id
	p.shadowlands_strength = ss
	return p


func _make_ws(char_id: int, flag: int = Enums.ContextFlag.AT_OWN_HOLDINGS) -> Dictionary:
	return {
		char_id: {
			"context_flag": flag,
			"zone_subtype": Enums.ZoneSubtype.ROAD,
			"wall_statuses": [],
		},
	}


# =============================================================================
# AT_WALL_TOWER context flag set
# =============================================================================

func test_character_at_wall_tower_gets_at_wall_tower_flag() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10, 3)}
	var world_states := _make_ws(1)
	var settlements: Array = [tower]
	var characters: Array = [char]

	DayOrchestrator._set_wall_tower_context_flags(characters, settlements, provinces, world_states)

	assert_eq(world_states[1]["context_flag"], Enums.ContextFlag.AT_WALL_TOWER)


func test_character_at_wall_tower_gets_wall_tower_zone_subtype() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	assert_eq(world_states[1]["zone_subtype"], Enums.ZoneSubtype.WALL_TOWER)


func test_wall_statuses_populated_with_si() -> void:
	var tower := _make_wall_tower(100, 10, 7)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10, 5)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	assert_eq(statuses.size(), 1)
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_eq(ws.si, 7)


func test_wall_statuses_populated_with_ss_from_province() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10, 6)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_eq(ws.ss, 6)


func test_wall_statuses_province_id_matches() -> void:
	var tower := _make_wall_tower(100, 42)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {42: _make_province(42)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_eq(ws.province_id, 42)


func test_garrison_above_minimum_true_when_garrison_nonzero() -> void:
	var tower := _make_wall_tower(100, 10)
	tower.garrison_pu = 2
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_true(ws.garrison_above_minimum)


func test_garrison_above_minimum_false_when_garrison_zero() -> void:
	var tower := _make_wall_tower(100, 10)
	tower.garrison_pu = 0
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_false(ws.garrison_above_minimum)


func test_jade_stockpile_critical_false_when_above_minimum() -> void:
	# garrison=10, SORTIE_SMALL_MAX_PCT=0.20 → int(10*0.20)=2 warriors → min_jade=2
	# jade=50 > 2 → not critical
	var tower := _make_wall_tower(100, 10)
	tower.garrison_pu = 10
	tower.jade_stockpile = 50.0
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_false(ws.jade_stockpile_critical)


func test_jade_stockpile_critical_true_when_at_or_below_minimum() -> void:
	# garrison=10, SORTIE_SMALL_MAX_PCT=0.20 → int(10*0.20)=2 warriors → min_jade=2
	# jade=1 <= 2 → critical
	var tower := _make_wall_tower(100, 10)
	tower.garrison_pu = 10
	tower.jade_stockpile = 1.0
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_true(ws.jade_stockpile_critical)


# =============================================================================
# Priority: AT_COURT takes precedence
# =============================================================================

func test_at_court_character_not_overridden() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states: Dictionary = _make_ws(1, Enums.ContextFlag.AT_COURT)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	assert_eq(world_states[1]["context_flag"], Enums.ContextFlag.AT_COURT)


func test_at_court_character_wall_statuses_unchanged() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states: Dictionary = _make_ws(1, Enums.ContextFlag.AT_COURT)
	world_states[1]["wall_statuses"] = []

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	assert_eq(world_states[1]["wall_statuses"].size(), 0)


# =============================================================================
# Traveling characters not affected
# =============================================================================

func test_traveling_character_not_set_to_at_wall_tower() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	char.travel_days_remaining = 3
	char.travel_destination = "200"
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	assert_ne(world_states[1]["context_flag"], Enums.ContextFlag.AT_WALL_TOWER)


# =============================================================================
# Non-tower settlement: character unaffected
# =============================================================================

func test_character_at_non_tower_settlement_unaffected() -> void:
	var town := _make_non_tower(200, 20)
	var char := _make_character(1, "200")
	var provinces: Dictionary = {20: _make_province(20)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[town],
		provinces, world_states
	)

	assert_ne(world_states[1]["context_flag"], Enums.ContextFlag.AT_WALL_TOWER)


func test_no_wall_towers_in_settlements_does_nothing() -> void:
	var town := _make_non_tower(200, 20)
	var char := _make_character(1, "200")
	var provinces: Dictionary = {20: _make_province(20)}
	var world_states := _make_ws(1)
	var original_flag: int = world_states[1]["context_flag"]

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[town],
		provinces, world_states
	)

	assert_eq(world_states[1]["context_flag"], original_flag)


# =============================================================================
# SS defaults to 0 when province not found
# =============================================================================

func test_ss_defaults_to_zero_when_province_missing() -> void:
	var tower := _make_wall_tower(100, 99)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {}  # province 99 not present
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	assert_eq(statuses.size(), 1)
	var ws: NPCDataStructures.WallStatus = statuses[0]
	assert_eq(ws.ss, 0)


# =============================================================================
# World state missing for character: skip gracefully
# =============================================================================

func test_character_without_world_state_entry_skipped() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(99, "100")  # ID 99 not in world_states
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)  # only char 1 has an entry

	# Should not crash
	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	# No side effects on unrelated char 1
	assert_ne(world_states[1]["context_flag"], Enums.ContextFlag.AT_WALL_TOWER)


# =============================================================================
# Multiple characters at same tower
# =============================================================================

func test_two_characters_at_same_tower_both_flagged() -> void:
	var tower := _make_wall_tower(100, 10)
	var c1 := _make_character(1, "100")
	var c2 := _make_character(2, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states: Dictionary = {
		1: {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS, "zone_subtype": Enums.ZoneSubtype.ROAD, "wall_statuses": []},
		2: {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS, "zone_subtype": Enums.ZoneSubtype.ROAD, "wall_statuses": []},
	}

	DayOrchestrator._set_wall_tower_context_flags(
		[c1, c2],
		[tower],
		provinces, world_states
	)

	assert_eq(world_states[1]["context_flag"], Enums.ContextFlag.AT_WALL_TOWER)
	assert_eq(world_states[2]["context_flag"], Enums.ContextFlag.AT_WALL_TOWER)


# =============================================================================
# Duplicate wall_statuses not added on second call
# =============================================================================

func test_existing_wall_status_for_province_not_duplicated() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	# Call twice
	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)
	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	assert_eq(statuses.size(), 1)


# =============================================================================
# Two different towers → two wall_statuses entries
# =============================================================================

func test_character_at_tower_with_preloaded_other_status_keeps_both() -> void:
	# Character is AT tower 100 (province 10), but already has a WallStatus
	# for province 20 in their world state (populated by prior system).
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}

	var pre_ws := NPCDataStructures.WallStatus.new()
	pre_ws.province_id = 20
	pre_ws.si = 5
	pre_ws.ss = 2

	var world_states: Dictionary = {
		1: {
			"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
			"zone_subtype": Enums.ZoneSubtype.ROAD,
			"wall_statuses": [pre_ws],
		},
	}

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var statuses: Array = world_states[1]["wall_statuses"]
	assert_eq(statuses.size(), 2)


# =============================================================================
# Garrison shortage state propagated from SettlementData (s2.4.13–14)
# =============================================================================

func test_minimum_garrison_populated_from_wall_system_constant() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var ws: NPCDataStructures.WallStatus = world_states[1]["wall_statuses"][0]
	assert_eq(ws.minimum_garrison, int(WallSystem.MINIMUM_GARRISON_PU))


func test_garrison_shortage_letter_season_propagated() -> void:
	var tower := _make_wall_tower(100, 10)
	tower.garrison_shortage_letter_season = 7
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var ws: NPCDataStructures.WallStatus = world_states[1]["wall_statuses"][0]
	assert_eq(ws.garrison_shortage_letter_season, 7)


func test_garrison_shortage_letter_season_default_is_sentinel() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var ws: NPCDataStructures.WallStatus = world_states[1]["wall_statuses"][0]
	assert_eq(ws.garrison_shortage_letter_season, -1)


func test_garrison_shortage_courtier_dispatched_propagated() -> void:
	var tower := _make_wall_tower(100, 10)
	tower.garrison_shortage_courtier_dispatched = true
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var ws: NPCDataStructures.WallStatus = world_states[1]["wall_statuses"][0]
	assert_true(ws.garrison_shortage_courtier_dispatched)


func test_garrison_shortage_courtier_refused_propagated() -> void:
	var tower := _make_wall_tower(100, 10)
	tower.garrison_shortage_courtier_refused = true
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var ws: NPCDataStructures.WallStatus = world_states[1]["wall_statuses"][0]
	assert_true(ws.garrison_shortage_courtier_refused)


func test_garrison_shortage_courtier_refused_default_is_false() -> void:
	var tower := _make_wall_tower(100, 10)
	var char := _make_character(1, "100")
	var provinces: Dictionary = {10: _make_province(10)}
	var world_states := _make_ws(1)

	DayOrchestrator._set_wall_tower_context_flags(
		[char],
		[tower],
		provinces, world_states
	)

	var ws: NPCDataStructures.WallStatus = world_states[1]["wall_statuses"][0]
	assert_false(ws.garrison_shortage_courtier_refused)
