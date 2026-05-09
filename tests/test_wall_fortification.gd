extends GutTest
## Tests for FORTIFY_WALL_SECTION and SEAL_WALL_BREACH execution paths per GDD s2.4.16.
## Covers ActionExecutor intercepts and DayOrchestrator._process_wall_engineering_effects.


# -- Helpers -------------------------------------------------------------------

func _make_kaiu(rank: int, engineering_rank: int = 5) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Kaiu Tanaka"
	c.school = "Kaiu Engineer"
	c.school_type = Enums.SchoolType.BUSHI
	c.insight_rank = rank
	c.skills = {"Engineering": engineering_rank}
	c.intelligence = 3
	c.willpower = 2
	c.reflexes = 3
	c.awareness = 3
	c.agility = 3
	c.strength = 3
	c.stamina = 3
	c.perception = 3
	c.void_ring = 2
	c.wounds_taken = 0
	return c


func _make_ctx_at_wall(si: int, province_id: int = 10) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.context_flag = Enums.ContextFlag.AT_WALL_TOWER
	ctx.ic_day = 5
	ctx.season = 1
	ctx.insight_rank = 2
	ctx.school = "Kaiu Engineer"
	var ws := NPCDataStructures.WallStatus.new()
	ws.province_id = province_id
	ws.si = si
	ws.ss = 0
	ws.garrison_above_minimum = true
	ws.jade_stockpile_critical = false
	ctx.wall_statuses = [ws]
	return ctx


func _make_fortify_action(target_province: int = 10) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "FORTIFY_WALL_SECTION"
	a.target_province_id = target_province
	a.ap_cost = 1
	a.metadata = {}
	return a


func _make_seal_action(target_province: int = 10) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "SEAL_WALL_BREACH"
	a.target_province_id = target_province
	a.ap_cost = 2
	a.metadata = {}
	return a


func _make_wall_settlement(province_id: int, si: int, koku: float = 10.0) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = province_id * 10
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = si
	s.koku_stockpile = koku
	return s


# =============================================================================
# FORTIFY_WALL_SECTION — ActionExecutor
# =============================================================================

func test_fortify_blocked_when_si_zero() -> void:
	var ctx := _make_ctx_at_wall(0)
	var action := _make_fortify_action()
	var dice := DiceEngine.new()
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(2), ctx, dice, {}, {}, {})
	assert_false(result["success"])
	assert_eq(result["effects"]["blocked_reason"], "si_is_zero_use_seal")


func test_fortify_success_sets_requires_fortify_wall() -> void:
	var ctx := _make_ctx_at_wall(5)
	var action := _make_fortify_action()
	var kaiu := _make_kaiu(2, 8)  # high Engineering for easy success
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, kaiu, ctx, dice, {}, {}, {})
	if result["success"]:
		assert_true(result["effects"]["requires_fortify_wall"])
		assert_true(result["effects"].has("si_gain"))
		assert_true(result["effects"].has("kaiu_decay_reduction"))
		assert_true(result["effects"].has("kaiu_reinforce_duration"))
	else:
		# Even on failure, no requires_fortify_wall
		assert_false(result["effects"].get("requires_fortify_wall", false))


func test_fortify_tn_matches_si() -> void:
	# SI 5 → TN 20 + (10-5)*2 = 30
	var ctx := _make_ctx_at_wall(5)
	var action := _make_fortify_action()
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(2), ctx, dice, {}, {}, {})
	assert_eq(result["tn"], 30)


func test_fortify_tn_si_10_is_20() -> void:
	var ctx := _make_ctx_at_wall(10)
	var action := _make_fortify_action()
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(2), ctx, dice, {}, {}, {})
	assert_eq(result["tn"], 20)


func test_fortify_kaiu_reduction_from_rank() -> void:
	# Rank 2 → decay_reduction 0.25, duration 3
	var ctx := _make_ctx_at_wall(8)
	ctx.insight_rank = 2
	var action := _make_fortify_action()
	var kaiu := _make_kaiu(2, 10)
	var dice := DiceEngine.new()
	dice.set_seed(999)
	var result: Dictionary = ActionExecutor.execute(action, kaiu, ctx, dice, {}, {}, {})
	if result["success"]:
		assert_almost_eq(float(result["effects"]["kaiu_decay_reduction"]), 0.25, 0.001)
		assert_eq(result["effects"]["kaiu_reinforce_duration"], 3)


func test_fortify_kaiu_rank5_sets_highest_modifier() -> void:
	# Rank 5 → decay_reduction 0.75, duration 5
	var ctx := _make_ctx_at_wall(8)
	ctx.insight_rank = 5
	var action := _make_fortify_action()
	var kaiu := _make_kaiu(5, 10)
	var dice := DiceEngine.new()
	dice.set_seed(999)
	var result: Dictionary = ActionExecutor.execute(action, kaiu, ctx, dice, {}, {}, {})
	if result["success"]:
		assert_almost_eq(float(result["effects"]["kaiu_decay_reduction"]), 0.75, 0.001)
		assert_eq(result["effects"]["kaiu_reinforce_duration"], 5)


func test_fortify_province_id_in_effects() -> void:
	var ctx := _make_ctx_at_wall(7, 42)
	var action := _make_fortify_action(42)
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(2), ctx, dice, {}, {}, {})
	assert_eq(result["effects"]["target_province_id"], 42)


# =============================================================================
# SEAL_WALL_BREACH — ActionExecutor
# =============================================================================

func test_seal_blocked_when_si_not_zero() -> void:
	var ctx := _make_ctx_at_wall(1)
	var action := _make_seal_action()
	var dice := DiceEngine.new()
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(3), ctx, dice, {}, {}, {})
	assert_false(result["success"])
	assert_eq(result["effects"]["blocked_reason"], "si_not_zero")


func test_seal_tn_is_35() -> void:
	var ctx := _make_ctx_at_wall(0)
	var action := _make_seal_action()
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(3), ctx, dice, {}, {}, {})
	assert_eq(result["tn"], 35)


func test_seal_koku_cost_always_present() -> void:
	var ctx := _make_ctx_at_wall(0)
	var action := _make_seal_action()
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, _make_kaiu(3), ctx, dice, {}, {}, {})
	assert_almost_eq(float(result["effects"]["koku_cost"]), 5.0, 0.001)


func test_seal_success_sets_requires_breach_seal() -> void:
	var ctx := _make_ctx_at_wall(0)
	var action := _make_seal_action()
	var kaiu := _make_kaiu(3, 10)  # high Engineering
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, kaiu, ctx, dice, {}, {}, {})
	if result["success"]:
		assert_true(result["effects"]["requires_breach_seal"])


func test_seal_failure_no_breach_seal_flag() -> void:
	# Low Engineering rank so roll fails
	var ctx := _make_ctx_at_wall(0)
	var action := _make_seal_action()
	var kaiu := _make_kaiu(3, 1)  # rank 1 Engineering — almost certain fail vs TN 35
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(action, kaiu, ctx, dice, {}, {}, {})
	if not result["success"]:
		assert_false(result["effects"].get("requires_breach_seal", false))
		# Koku still spent
		assert_almost_eq(float(result["effects"]["koku_cost"]), 5.0, 0.001)


# =============================================================================
# _process_wall_engineering_effects — DayOrchestrator
# =============================================================================

func test_fortify_applies_si_gain() -> void:
	var s := _make_wall_settlement(10, 7)
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 2,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_eq(s.wall_si, 9)


func test_fortify_si_capped_at_10() -> void:
	var s := _make_wall_settlement(10, 9)
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 5,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 2,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_eq(s.wall_si, 10)


func test_fortify_sets_kaiu_reduction() -> void:
	var s := _make_wall_settlement(10, 7)
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 1,
			"kaiu_decay_reduction": 0.50,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_almost_eq(s.kaiu_decay_reduction, 0.50, 0.001)
	assert_eq(s.kaiu_reinforce_seasons_remaining, 3)


func test_fortify_overwrite_rule_higher_wins() -> void:
	var s := _make_wall_settlement(10, 7)
	s.kaiu_decay_reduction = 0.25
	s.kaiu_reinforce_seasons_remaining = 2
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 1,
			"kaiu_decay_reduction": 0.50,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_almost_eq(s.kaiu_decay_reduction, 0.50, 0.001)
	assert_eq(s.kaiu_reinforce_seasons_remaining, 3)


func test_fortify_overwrite_rule_lower_does_not_replace() -> void:
	var s := _make_wall_settlement(10, 7)
	s.kaiu_decay_reduction = 0.75
	s.kaiu_reinforce_seasons_remaining = 4
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 1,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 2,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	# Existing 0.75 modifier persists unchanged
	assert_almost_eq(s.kaiu_decay_reduction, 0.75, 0.001)
	assert_eq(s.kaiu_reinforce_seasons_remaining, 4)


func test_fortify_overwrite_equal_value_refreshes_duration() -> void:
	var s := _make_wall_settlement(10, 7)
	s.kaiu_decay_reduction = 0.50
	s.kaiu_reinforce_seasons_remaining = 1  # almost expired
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 1,
			"kaiu_decay_reduction": 0.50,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	# Equal value — fresh duration applied
	assert_eq(s.kaiu_reinforce_seasons_remaining, 3)


func test_seal_success_restores_si_to_2() -> void:
	var s := _make_wall_settlement(10, 0, 10.0)
	var applied: Array = [{
		"effects": {
			"requires_breach_seal": true,
			"koku_cost": 5.0,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_eq(s.wall_si, 2)
	assert_almost_eq(s.koku_stockpile, 5.0, 0.001)


func test_seal_failure_does_not_restore_si() -> void:
	var s := _make_wall_settlement(10, 0, 10.0)
	var applied: Array = [{
		"effects": {
			"requires_breach_seal": false,
			"koku_cost": 5.0,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_eq(s.wall_si, 0, "SI unchanged on failure")
	assert_almost_eq(s.koku_stockpile, 5.0, 0.001, "Koku deducted even on failure")


func test_seal_koku_capped_at_zero() -> void:
	# Only 3 Koku available — deducted to 0, not negative
	var s := _make_wall_settlement(10, 0, 3.0)
	var applied: Array = [{
		"effects": {
			"requires_breach_seal": true,
			"koku_cost": 5.0,
			"target_province_id": 10,
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_almost_eq(s.koku_stockpile, 0.0, 0.001)


func test_effects_unknown_province_skipped() -> void:
	var s := _make_wall_settlement(10, 7)
	var applied: Array = [{
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 2,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 99,  # no settlement in province 99
		}
	}]
	DayOrchestrator._process_wall_engineering_effects(applied, [s])
	assert_eq(s.wall_si, 7, "Unmatched province causes no mutation")


# =============================================================================
# Kaiu Reinforcement — seasonal decay integration
# =============================================================================

func test_kaiu_reduction_applied_in_seasonal_pressure() -> void:
	var s := SettlementData.new()
	s.settlement_id = 1
	s.province_id = 10
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = 10
	s.kaiu_decay_reduction = 0.75
	s.kaiu_reinforce_seasons_remaining = 3
	var p := ProvinceData.new()
	p.province_id = 10
	p.shadowlands_strength = 0
	p.province_taint_level = 0.0
	p.adjacent_province_ids = []
	var meta: Dictionary = {}
	# Winter base 2; kaiu 0.75 → effective 1.25 → int = 1 decay
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.WINTER, meta
	)
	assert_eq(s.wall_si, 9, "Kaiu reduction cuts winter decay from 2 to 1")


func test_kaiu_seasons_decremented_each_season() -> void:
	var s := SettlementData.new()
	s.settlement_id = 1
	s.province_id = 10
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = 10
	s.kaiu_decay_reduction = 0.50
	s.kaiu_reinforce_seasons_remaining = 2
	var p := ProvinceData.new()
	p.province_id = 10
	p.shadowlands_strength = 0
	p.province_taint_level = 0.0
	p.adjacent_province_ids = []
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SUMMER, {}
	)
	assert_eq(s.kaiu_reinforce_seasons_remaining, 1)


func test_kaiu_modifier_cleared_when_duration_expires() -> void:
	var s := SettlementData.new()
	s.settlement_id = 1
	s.province_id = 10
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = 10
	s.kaiu_decay_reduction = 0.50
	s.kaiu_reinforce_seasons_remaining = 1  # expires this season
	var p := ProvinceData.new()
	p.province_id = 10
	p.shadowlands_strength = 0
	p.province_taint_level = 0.0
	p.adjacent_province_ids = []
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SUMMER, {}
	)
	assert_eq(s.kaiu_reinforce_seasons_remaining, 0)
	assert_almost_eq(s.kaiu_decay_reduction, 0.0, 0.001)
