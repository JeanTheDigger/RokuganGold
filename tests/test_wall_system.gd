extends GutTest
## Tests for WallSystem per GDD s2.4.2, s2.4.3, s2.4.10, s2.4.11, s2.4.15.
## All functions are pure static — no scene tree or dice engine needed.


# -- SS Tier Queries -----------------------------------------------------------

func test_ss_tier_none_when_zero() -> void:
	assert_eq(WallSystem.get_ss_tier(0), "none")


func test_ss_tier_low_at_1() -> void:
	assert_eq(WallSystem.get_ss_tier(1), "low")


func test_ss_tier_low_at_4() -> void:
	assert_eq(WallSystem.get_ss_tier(4), "low")


func test_ss_tier_medium_at_5() -> void:
	assert_eq(WallSystem.get_ss_tier(5), "medium")


func test_ss_tier_medium_at_8() -> void:
	assert_eq(WallSystem.get_ss_tier(8), "medium")


func test_ss_tier_high_at_9() -> void:
	assert_eq(WallSystem.get_ss_tier(9), "high")


func test_ss_tier_high_at_20() -> void:
	assert_eq(WallSystem.get_ss_tier(20), "high")


# -- SI Defense Bonus ----------------------------------------------------------

func test_si_10_gives_12_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(10), 12)


func test_si_9_gives_10_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(9), 10)


func test_si_8_gives_10_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(8), 10)


func test_si_7_gives_7_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(7), 7)


func test_si_6_gives_7_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(6), 7)


func test_si_5_gives_4_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(5), 4)


func test_si_4_gives_4_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(4), 4)


func test_si_3_gives_1_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(3), 1)


func test_si_2_gives_1_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(2), 1)


func test_si_1_gives_0_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(1), 0)


func test_si_0_gives_0_defense() -> void:
	assert_eq(WallSystem.get_si_defense_bonus(0), 0)


# -- Seasonal SI Decay (base, no SS) ------------------------------------------

func test_spring_base_decay_is_1() -> void:
	assert_eq(WallSystem.get_seasonal_si_decay("spring"), 1)


func test_summer_base_decay_is_0() -> void:
	assert_eq(WallSystem.get_seasonal_si_decay("summer"), 0)


func test_autumn_base_decay_is_1() -> void:
	assert_eq(WallSystem.get_seasonal_si_decay("autumn"), 1)


func test_winter_base_decay_is_2() -> void:
	assert_eq(WallSystem.get_seasonal_si_decay("winter"), 2)


# -- Total SI Decay with SS Modifier ------------------------------------------

func test_spring_low_ss_no_extra_decay() -> void:
	var decay: float = WallSystem.get_total_si_decay("spring", 3)
	assert_eq(decay, 1.0)


func test_spring_medium_ss_adds_half_point() -> void:
	var decay: float = WallSystem.get_total_si_decay("spring", 5)
	assert_eq(decay, 1.5)


func test_winter_high_ss_adds_1_point() -> void:
	var decay: float = WallSystem.get_total_si_decay("winter", 10)
	assert_eq(decay, 3.0)


func test_summer_medium_ss_gives_half_point() -> void:
	var decay: float = WallSystem.get_total_si_decay("summer", 8)
	assert_eq(decay, 0.5)


# -- Koku Cost -----------------------------------------------------------------

func test_spring_low_ss_koku_2() -> void:
	assert_eq(WallSystem.get_total_koku_cost("spring", 3), 2)


func test_spring_medium_ss_koku_3() -> void:
	assert_eq(WallSystem.get_total_koku_cost("spring", 5), 3)


func test_spring_high_ss_koku_4() -> void:
	assert_eq(WallSystem.get_total_koku_cost("spring", 9), 4)


func test_summer_low_ss_koku_1() -> void:
	assert_eq(WallSystem.get_total_koku_cost("summer", 2), 1)


func test_winter_high_ss_koku_5() -> void:
	assert_eq(WallSystem.get_total_koku_cost("winter", 12), 5)


# -- Rice Modifier -------------------------------------------------------------

func test_spring_low_ss_rice_1x() -> void:
	assert_almost_eq(WallSystem.get_rice_modifier("spring", 2), 1.0, 0.001)


func test_autumn_medium_ss_rice_modifier() -> void:
	# base 1.2 × 1.1 = 1.32
	assert_almost_eq(WallSystem.get_rice_modifier("autumn", 6), 1.32, 0.001)


func test_winter_high_ss_rice_modifier() -> void:
	# base 1.5 × 1.2 = 1.8
	assert_almost_eq(WallSystem.get_rice_modifier("winter", 10), 1.8, 0.001)


func test_summer_no_ss_rice_1x() -> void:
	assert_almost_eq(WallSystem.get_rice_modifier("summer", 0), 1.0, 0.001)


# -- Adjacent Tower Bleed -----------------------------------------------------

func test_bleed_inactive_when_si_above_4() -> void:
	var result: Dictionary = WallSystem.compute_adjacent_bleed(5)
	assert_false(result["bleed_active"])
	assert_almost_eq(result["bleed_amount"], 0.0, 0.001)


func test_bleed_active_at_si_4() -> void:
	var result: Dictionary = WallSystem.compute_adjacent_bleed(4)
	assert_true(result["bleed_active"])
	assert_almost_eq(result["bleed_amount"], 0.5, 0.001)


func test_bleed_active_at_si_0() -> void:
	var result: Dictionary = WallSystem.compute_adjacent_bleed(0)
	assert_true(result["bleed_active"])


# -- PTL Contribution ----------------------------------------------------------

func test_ptl_zero_for_non_wall_province() -> void:
	assert_almost_eq(WallSystem.compute_ptl_contribution(10, false), 0.0, 0.001)


func test_ptl_baseline_for_healthy_wall_province() -> void:
	# SI 10, wall-adjacent → baseline 0.1
	assert_almost_eq(WallSystem.compute_ptl_contribution(10, true), 0.1, 0.001)


func test_ptl_extra_for_degraded_tower() -> void:
	# SI 5 or below → 0.1 baseline + 0.5 extra = 0.6
	assert_almost_eq(WallSystem.compute_ptl_contribution(5, true), 0.6, 0.001)


func test_ptl_extra_at_si_0() -> void:
	assert_almost_eq(WallSystem.compute_ptl_contribution(0, true), 0.6, 0.001)


func test_ptl_no_extra_at_si_6() -> void:
	# SI 6 is above degraded threshold (5) → baseline only
	assert_almost_eq(WallSystem.compute_ptl_contribution(6, true), 0.1, 0.001)


# -- apply_seasonal_si_decay --------------------------------------------------

func test_apply_si_decay_spring_low_ss() -> void:
	var tower := SettlementData.new()
	tower.wall_si = 9
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "spring", 2)
	assert_eq(result["new_si"], 8)
	assert_eq(result["decay_applied"], 1)


func test_apply_si_decay_winter_high_ss() -> void:
	var tower := SettlementData.new()
	tower.wall_si = 10
	# Winter base 2 + high SS 1 = 3 total decay
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "winter", 10)
	assert_eq(result["new_si"], 7)
	assert_eq(result["decay_applied"], 3)


func test_apply_si_decay_floor_at_zero() -> void:
	var tower := SettlementData.new()
	tower.wall_si = 1
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "winter", 12)
	assert_eq(result["new_si"], 0)


func test_apply_si_decay_summer_no_decay() -> void:
	var tower := SettlementData.new()
	tower.wall_si = 7
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "summer", 3)
	assert_eq(result["new_si"], 7)
	assert_eq(result["decay_applied"], 0)


func test_apply_si_decay_kaiu_reduction_reduces_decay() -> void:
	var tower := SettlementData.new()
	tower.wall_si = 10
	# Winter base 2; kaiu_reduction 0.75 → effective decay = 1.25 → int = 1
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "winter", 0, 0.75)
	assert_eq(result["decay_applied"], 1)
	assert_eq(result["new_si"], 9)


func test_apply_si_decay_kaiu_reduction_cannot_restore() -> void:
	# kaiu_reduction larger than base decay → clamped to 0, no gain
	var tower := SettlementData.new()
	tower.wall_si = 8
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "spring", 0, 2.0)
	assert_eq(result["decay_applied"], 0)
	assert_eq(result["new_si"], 8)


func test_apply_si_decay_kaiu_full_cancel_of_medium_ss_spring() -> void:
	# Spring base 1 + Medium SS 0.5 = 1.5; kaiu 0.5 → 1.0 → int = 1
	var tower := SettlementData.new()
	tower.wall_si = 10
	var result: Dictionary = WallSystem.apply_seasonal_si_decay(tower, "spring", 5, 0.5)
	assert_eq(result["decay_applied"], 1)
	assert_eq(result["new_si"], 9)


# -- KAIU_REINFORCE_TABLE / get_kaiu_reinforce ---------------------------------

func test_kaiu_reinforce_rank1() -> void:
	var r: Dictionary = WallSystem.get_kaiu_reinforce(1)
	assert_almost_eq(r["decay_reduction"], 0.25, 0.001)
	assert_eq(r["duration"], 2)


func test_kaiu_reinforce_rank3() -> void:
	var r: Dictionary = WallSystem.get_kaiu_reinforce(3)
	assert_almost_eq(r["decay_reduction"], 0.50, 0.001)
	assert_eq(r["duration"], 3)


func test_kaiu_reinforce_rank5() -> void:
	var r: Dictionary = WallSystem.get_kaiu_reinforce(5)
	assert_almost_eq(r["decay_reduction"], 0.75, 0.001)
	assert_eq(r["duration"], 5)


func test_kaiu_reinforce_rank_clamped_low() -> void:
	# Rank 0 clamps to 1
	var r: Dictionary = WallSystem.get_kaiu_reinforce(0)
	assert_almost_eq(r["decay_reduction"], 0.25, 0.001)


func test_kaiu_reinforce_rank_clamped_high() -> void:
	# Rank 6 clamps to 5
	var r: Dictionary = WallSystem.get_kaiu_reinforce(6)
	assert_almost_eq(r["decay_reduction"], 0.75, 0.001)


# -- get_fortify_tn ------------------------------------------------------------

func test_fortify_tn_si_10_is_20() -> void:
	assert_eq(WallSystem.get_fortify_tn(10), 20)


func test_fortify_tn_si_9_is_22() -> void:
	assert_eq(WallSystem.get_fortify_tn(9), 22)


func test_fortify_tn_si_5_is_30() -> void:
	assert_eq(WallSystem.get_fortify_tn(5), 30)


func test_fortify_tn_si_2_is_36() -> void:
	# GDD example: crumbling tower SI 2 → TN 36
	assert_eq(WallSystem.get_fortify_tn(2), 36)


func test_fortify_tn_si_1_is_38() -> void:
	assert_eq(WallSystem.get_fortify_tn(1), 38)


func test_fortify_tn_si_0_clamped_to_si1() -> void:
	# SI 0 would require SEAL_WALL_BREACH; clamp to 1 if called anyway
	assert_eq(WallSystem.get_fortify_tn(0), 38)


# -- compute_fortify_si_gain ---------------------------------------------------

func test_fortify_gain_zero_raises() -> void:
	assert_almost_eq(WallSystem.compute_fortify_si_gain(0), 1.0, 0.001)


func test_fortify_gain_two_raises() -> void:
	assert_almost_eq(WallSystem.compute_fortify_si_gain(2), 2.0, 0.001)


func test_fortify_gain_four_raises() -> void:
	assert_almost_eq(WallSystem.compute_fortify_si_gain(4), 3.0, 0.001)


func test_fortify_gain_one_raise_is_1_5() -> void:
	assert_almost_eq(WallSystem.compute_fortify_si_gain(1), 1.5, 0.001)


# -- AI Sortie Size Selection --------------------------------------------------

func test_ai_sortie_none_when_ss_zero() -> void:
	assert_eq(WallSystem.get_ai_sortie_size(0), "none")


func test_ai_sortie_none_when_ss_low() -> void:
	assert_eq(WallSystem.get_ai_sortie_size(3), "none")


func test_ai_sortie_small_when_ss_medium() -> void:
	assert_eq(WallSystem.get_ai_sortie_size(5), "small")


func test_ai_sortie_small_at_ss_8() -> void:
	assert_eq(WallSystem.get_ai_sortie_size(8), "small")


func test_ai_sortie_medium_when_ss_high() -> void:
	assert_eq(WallSystem.get_ai_sortie_size(9), "medium")


func test_ai_sortie_medium_at_ss_15() -> void:
	assert_eq(WallSystem.get_ai_sortie_size(15), "medium")


# -- SS Reduction per force size -----------------------------------------------

func test_ss_reduction_small_is_1() -> void:
	assert_eq(WallSystem.get_ss_reduction("small"), 1)


func test_ss_reduction_medium_is_2() -> void:
	assert_eq(WallSystem.get_ss_reduction("medium"), 2)


func test_ss_reduction_large_is_3() -> void:
	assert_eq(WallSystem.get_ss_reduction("large"), 3)


func test_ss_reduction_unknown_is_0() -> void:
	assert_eq(WallSystem.get_ss_reduction("none"), 0)


# -- Jade allocation per warrior -----------------------------------------------

func test_jade_small_sortie_1_per_warrior() -> void:
	assert_eq(WallSystem.get_jade_per_warrior("small"), 1)


func test_jade_medium_sortie_2_per_warrior() -> void:
	assert_eq(WallSystem.get_jade_per_warrior("medium"), 2)


func test_jade_large_sortie_3_per_warrior() -> void:
	assert_eq(WallSystem.get_jade_per_warrior("large"), 3)


# -- validate_sortie -----------------------------------------------------------

func test_validate_sortie_blocked_by_jade_critical() -> void:
	var result: Dictionary = WallSystem.validate_sortie(8, 9, true, true, false)
	assert_false(result["can_sortie"])
	assert_eq(result["blocked_reason"], "jade_critical")


func test_validate_sortie_blocked_by_garrison_below_minimum() -> void:
	var result: Dictionary = WallSystem.validate_sortie(8, 9, false, false, false)
	assert_false(result["can_sortie"])
	assert_eq(result["blocked_reason"], "garrison_below_minimum")


func test_validate_sortie_jade_gate_takes_precedence() -> void:
	# Even if garrison is below minimum, jade gate fires first
	var result: Dictionary = WallSystem.validate_sortie(9, 9, false, true, false)
	assert_false(result["can_sortie"])
	assert_eq(result["blocked_reason"], "jade_critical")


func test_validate_sortie_blocked_si_critical_and_ss_high() -> void:
	# SI < 6 and SS High simultaneously — double crisis (s2.4.11)
	var result: Dictionary = WallSystem.validate_sortie(9, 5, true, false, false)
	assert_false(result["can_sortie"])
	assert_eq(result["blocked_reason"], "si_critical_and_ss_high")


func test_validate_sortie_si_critical_allowed_when_ss_medium() -> void:
	# SI < 6 but SS is only Medium — sortie still allowed (only High is the gate)
	var result: Dictionary = WallSystem.validate_sortie(6, 4, true, false, false)
	assert_true(result["can_sortie"])
	assert_eq(result["force_size"], "small")


func test_validate_sortie_blocked_ss_too_low() -> void:
	var result: Dictionary = WallSystem.validate_sortie(3, 9, true, false, false)
	assert_false(result["can_sortie"])
	assert_eq(result["blocked_reason"], "ss_too_low")


func test_validate_sortie_large_blocked_without_shireikan() -> void:
	var result: Dictionary = WallSystem.validate_sortie(9, 9, true, false, false, "large")
	assert_false(result["can_sortie"])
	assert_eq(result["blocked_reason"], "large_requires_shireikan")


func test_validate_sortie_large_allowed_with_shireikan() -> void:
	var result: Dictionary = WallSystem.validate_sortie(9, 9, true, false, true, "large")
	assert_true(result["can_sortie"])
	assert_eq(result["force_size"], "large")


func test_validate_sortie_medium_ss_selects_small() -> void:
	var result: Dictionary = WallSystem.validate_sortie(7, 9, true, false, false)
	assert_true(result["can_sortie"])
	assert_eq(result["force_size"], "small")


func test_validate_sortie_high_ss_selects_medium() -> void:
	var result: Dictionary = WallSystem.validate_sortie(10, 9, true, false, false)
	assert_true(result["can_sortie"])
	assert_eq(result["force_size"], "medium")


# -- resolve_sortie -----------------------------------------------------------

func test_resolve_sortie_blocked_returns_failure() -> void:
	var result: Dictionary = WallSystem.resolve_sortie(0, 10, true, false, false, -1)
	assert_false(result["success"])
	assert_eq(result["blocked_reason"], "ss_too_low")


func test_resolve_sortie_medium_ss_returns_small_sortie() -> void:
	var result: Dictionary = WallSystem.resolve_sortie(6, 9, true, false, false, 10)
	assert_true(result["success"])
	assert_eq(result["force_size"], "small")
	assert_eq(result["ss_reduction"], 1)
	assert_almost_eq(result["force_pct"], 0.20, 0.001)
	assert_eq(result["jade_per_warrior"], 1)
	assert_true(result["requires_sortie_combat"])
	assert_eq(result["target_province_id"], 10)


func test_resolve_sortie_high_ss_returns_medium_sortie() -> void:
	var result: Dictionary = WallSystem.resolve_sortie(10, 9, true, false, false, 5)
	assert_true(result["success"])
	assert_eq(result["force_size"], "medium")
	assert_eq(result["ss_reduction"], 2)
	assert_almost_eq(result["force_pct"], 0.40, 0.001)
	assert_eq(result["jade_per_warrior"], 2)


func test_resolve_sortie_large_override_with_shireikan() -> void:
	var result: Dictionary = WallSystem.resolve_sortie(10, 9, true, false, true, 7, "large")
	assert_true(result["success"])
	assert_eq(result["force_size"], "large")
	assert_eq(result["ss_reduction"], 3)
	assert_almost_eq(result["force_pct"], 0.60, 0.001)
	assert_eq(result["jade_per_warrior"], 3)


func test_resolve_sortie_jade_critical_blocks() -> void:
	var result: Dictionary = WallSystem.resolve_sortie(8, 9, true, true, false, 10)
	assert_false(result["success"])
	assert_eq(result["blocked_reason"], "jade_critical")


# -- CONDUCT_SORTIE in ActionExecutor -----------------------------------------

func _make_ctx_with_wall(ss: int, si: int, garrison_above: bool, jade_crit: bool) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.ic_day = 10
	ctx.season = 1
	var ws := NPCDataStructures.WallStatus.new()
	ws.province_id = 10
	ws.ss = ss
	ws.si = si
	ws.garrison_above_minimum = garrison_above
	ws.jade_stockpile_critical = jade_crit
	ctx.wall_statuses = [ws]
	return ctx


func _make_sortie_action(target_province: int = 10) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "CONDUCT_SORTIE"
	a.target_province_id = target_province
	a.ap_cost = 1
	a.metadata = {}
	return a


func _make_taisa() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Taisa"
	c.military_rank = Enums.MilitaryRank.TAISA
	c.skills = {"Battle": 3}
	c.reflexes = 3
	c.willpower = 3
	c.awareness = 3
	c.agility = 3
	c.strength = 3
	c.stamina = 3
	c.perception = 3
	c.intelligence = 3
	c.void_ring = 2
	c.wounds_taken = 0
	return c


func test_conduct_sortie_blocked_jade_critical() -> void:
	var ctx := _make_ctx_with_wall(8, 9, true, true)
	var action := _make_sortie_action()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _make_taisa(), ctx, dice, {}, {}, {}
	)
	assert_false(result["success"])
	assert_eq(result["effects"]["blocked_reason"], "jade_critical")


func test_conduct_sortie_blocked_low_ss() -> void:
	var ctx := _make_ctx_with_wall(2, 9, true, false)
	var action := _make_sortie_action()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _make_taisa(), ctx, dice, {}, {}, {}
	)
	assert_false(result["success"])
	assert_eq(result["effects"]["blocked_reason"], "ss_too_low")


func test_conduct_sortie_medium_ss_succeeds_for_taisa() -> void:
	var ctx := _make_ctx_with_wall(6, 9, true, false)
	var action := _make_sortie_action()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _make_taisa(), ctx, dice, {}, {}, {}
	)
	assert_true(result["success"])
	assert_eq(result["effects"]["force_size"], "small")
	assert_eq(result["effects"]["ss_reduction"], 1)
	assert_true(result["effects"]["requires_sortie_combat"])


func test_conduct_sortie_large_blocked_for_taisa() -> void:
	var ctx := _make_ctx_with_wall(10, 9, true, false)
	var action := _make_sortie_action()
	action.metadata["force_size"] = "large"
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _make_taisa(), ctx, dice, {}, {}, {}
	)
	assert_false(result["success"])
	assert_eq(result["effects"]["blocked_reason"], "large_requires_shireikan")


func test_conduct_sortie_large_allowed_for_shireikan() -> void:
	var ctx := _make_ctx_with_wall(10, 9, true, false)
	var action := _make_sortie_action()
	action.metadata["force_size"] = "large"
	var shireikan := _make_taisa()
	shireikan.military_rank = Enums.MilitaryRank.SHIREIKAN
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, shireikan, ctx, dice, {}, {}, {}
	)
	assert_true(result["success"])
	assert_eq(result["effects"]["force_size"], "large")
	assert_eq(result["effects"]["ss_reduction"], 3)


func test_conduct_sortie_returns_target_province_id() -> void:
	var ctx := _make_ctx_with_wall(7, 9, true, false)
	var action := _make_sortie_action(42)
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(
		action, _make_taisa(), ctx, dice, {}, {}, {}
	)
	if result["success"]:
		assert_eq(result["effects"]["target_province_id"], 42)


func test_conduct_sortie_high_ss_gives_medium_force() -> void:
	var ctx := _make_ctx_with_wall(10, 9, true, false)
	var action := _make_sortie_action()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _make_taisa(), ctx, dice, {}, {}, {}
	)
	assert_true(result["success"])
	assert_eq(result["effects"]["force_size"], "medium")
	assert_eq(result["effects"]["ss_reduction"], 2)


# =============================================================================
# _process_sortie_results — DayOrchestrator (s2.4.10, s2.4.11, s2.4.15)
# =============================================================================

func _make_sortie_applied(
	province_id: int, ss_reduction: int, force_pct: float, jade_per_warrior: int
) -> Dictionary:
	return {
		"action_id": "CONDUCT_SORTIE",
		"effects": {
			"requires_sortie_combat": true,
			"ss_reduction": ss_reduction,
			"force_pct": force_pct,
			"jade_per_warrior": jade_per_warrior,
			"target_province_id": province_id,
		}
	}


func _make_wall_province_data(pid: int, ss: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.shadowlands_strength = ss
	p.province_taint_level = 0.0
	p.adjacent_province_ids = []
	return p


func _make_wall_tower_settlement(pid: int, garrison: int, jade: float) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = pid * 10
	s.province_id = pid
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.garrison_pu = garrison
	s.jade_stockpile = jade
	return s


func test_sortie_reduces_ss() -> void:
	var p := _make_wall_province_data(10, 8)
	var s := _make_wall_tower_settlement(10, 10, 50.0)
	var applied: Array = [_make_sortie_applied(10, 2, 0.40, 2)]
	var results: Array = DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_eq(p.shadowlands_strength, 6)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["ss_reduction_applied"], 2)
	assert_eq(results[0]["new_ss"], 6)


func test_sortie_ss_clamped_at_zero() -> void:
	var p := _make_wall_province_data(10, 1)
	var s := _make_wall_tower_settlement(10, 10, 20.0)
	var applied: Array = [_make_sortie_applied(10, 3, 0.20, 1)]
	DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_eq(p.shadowlands_strength, 0)


func test_sortie_consumes_jade_from_settlement() -> void:
	# garrison_pu=10, force_pct=0.20 → warriors=2; jade_per_warrior=1 → jade_consumed=2
	var p := _make_wall_province_data(10, 6)
	var s := _make_wall_tower_settlement(10, 10, 20.0)
	var applied: Array = [_make_sortie_applied(10, 1, 0.20, 1)]
	DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_almost_eq(s.jade_stockpile, 18.0, 0.001)


func test_sortie_medium_consumes_2_jade_per_warrior() -> void:
	# garrison_pu=10, force_pct=0.40 → warriors=4; jade_per_warrior=2 → jade_consumed=8
	var p := _make_wall_province_data(10, 8)
	var s := _make_wall_tower_settlement(10, 10, 30.0)
	var applied: Array = [_make_sortie_applied(10, 2, 0.40, 2)]
	DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_almost_eq(s.jade_stockpile, 22.0, 0.001)


func test_sortie_large_consumes_3_jade_per_warrior() -> void:
	# garrison_pu=10, force_pct=0.60 → warriors=6; jade_per_warrior=3 → jade_consumed=18
	var p := _make_wall_province_data(10, 9)
	var s := _make_wall_tower_settlement(10, 10, 30.0)
	var applied: Array = [_make_sortie_applied(10, 3, 0.60, 3)]
	DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_almost_eq(s.jade_stockpile, 12.0, 0.001)


func test_sortie_jade_clamped_at_zero_if_insufficient() -> void:
	# garrison_pu=10, force_pct=0.40 → warriors=4; jade_per=2 → needs 8; only 3 available
	var p := _make_wall_province_data(10, 8)
	var s := _make_wall_tower_settlement(10, 10, 3.0)
	var applied: Array = [_make_sortie_applied(10, 2, 0.40, 2)]
	DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_almost_eq(s.jade_stockpile, 0.0, 0.001)


func test_sortie_no_mutation_when_flag_false() -> void:
	var p := _make_wall_province_data(10, 8)
	var s := _make_wall_tower_settlement(10, 10, 20.0)
	var applied: Array = [{
		"action_id": "CONDUCT_SORTIE",
		"effects": {"requires_sortie_combat": false, "target_province_id": 10}
	}]
	DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_eq(p.shadowlands_strength, 8, "No SS change without flag")
	assert_almost_eq(s.jade_stockpile, 20.0, 0.001, "No jade change without flag")


func test_sortie_result_in_return_array() -> void:
	var p := _make_wall_province_data(10, 5)
	var s := _make_wall_tower_settlement(10, 8, 15.0)
	var applied: Array = [_make_sortie_applied(10, 1, 0.20, 1)]
	var results: Array = DayOrchestrator._process_sortie_results(applied, [s], {10: p}, DiceEngine.new())
	assert_eq(results.size(), 1)
	assert_eq(results[0]["province_id"], 10)


func test_sortie_two_independent_sorties() -> void:
	var p1 := _make_wall_province_data(10, 6)
	var p2 := _make_wall_province_data(20, 9)
	var s1 := _make_wall_tower_settlement(10, 10, 20.0)
	var s2 := _make_wall_tower_settlement(20, 8, 30.0)
	var applied: Array = [
		_make_sortie_applied(10, 1, 0.20, 1),   # small → ss 6-1=5, jade 10*0.2=2 warriors ×1=2
		_make_sortie_applied(20, 2, 0.40, 2),   # medium → ss 9-2=7, jade 8*0.4=3 warriors ×2=6
	]
	DayOrchestrator._process_sortie_results(applied, [s1, s2], {10: p1, 20: p2}, DiceEngine.new())
	assert_eq(p1.shadowlands_strength, 5)
	assert_eq(p2.shadowlands_strength, 7)
	assert_almost_eq(s1.jade_stockpile, 18.0, 0.001)
	assert_almost_eq(s2.jade_stockpile, 24.0, 0.001)


# -- Garrison Honor Gain (s2.4.12) --------------------------------------------

func test_garrison_honor_gain_single_unit() -> void:
	assert_almost_eq(WallSystem.compute_garrison_honor_gain("unit"), 0.3, 0.001)


func test_garrison_honor_gain_guntai() -> void:
	assert_almost_eq(WallSystem.compute_garrison_honor_gain("guntai"), 0.5, 0.001)


func test_garrison_honor_gain_one_kaisha() -> void:
	assert_almost_eq(WallSystem.compute_garrison_honor_gain("kaisha", 1), 1.0, 0.001)


func test_garrison_honor_gain_multiple_kaisha() -> void:
	assert_almost_eq(WallSystem.compute_garrison_honor_gain("kaisha", 3), 3.0, 0.001)


func test_garrison_honor_gain_unknown_type_returns_zero() -> void:
	assert_almost_eq(WallSystem.compute_garrison_honor_gain("unknown"), 0.0, 0.001)


# -- Garrison Shortage Personality Modifier (s2.4.12) -------------------------

func test_garrison_personality_modifier_chugi() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(mod, 15.0, 0.001)


func test_garrison_personality_modifier_yu() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(mod, 8.0, 0.001)


func test_garrison_personality_modifier_meiyo() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(mod, 8.0, 0.001)


func test_garrison_personality_modifier_jin() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(mod, 6.0, 0.001)


func test_garrison_personality_modifier_kyoryoku() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU
	)
	assert_almost_eq(mod, -5.0, 0.001)


func test_garrison_personality_modifier_seigyo() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO
	)
	assert_almost_eq(mod, -5.0, 0.001)


func test_garrison_personality_modifier_no_virtue() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(mod, 0.0, 0.001)


func test_garrison_personality_modifier_chugi_with_seigyo() -> void:
	var mod: float = WallSystem.compute_garrison_shortage_personality_modifier(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.SEIGYO
	)
	assert_almost_eq(mod, 10.0, 0.001)  # 15 - 5
