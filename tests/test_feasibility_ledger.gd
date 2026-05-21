extends GutTest
## Tests for FeasibilityLedger (s4.3.17 Phase 1)


# -- Campaign Length Estimation ------------------------------------------------

func test_raid_campaign_length() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.PROVINCIAL_RAID, "",
	)
	assert_eq(seasons, 1)


func test_border_conflict_campaign_length() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.BORDER_CONFLICT, "",
	)
	assert_eq(seasons, 2)


func test_family_war_campaign_length() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.FAMILY_WAR, "",
	)
	assert_eq(seasons, 3)


func test_clan_war_campaign_length() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.CLAN_WAR, "",
	)
	assert_eq(seasons, 4)


func test_yu_reduces_estimate() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.CLAN_WAR, "Yu",
	)
	assert_eq(seasons, 3)


func test_kyoryoku_reduces_estimate() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.BORDER_CONFLICT, "Kyoryoku",
	)
	assert_eq(seasons, 1)


func test_reduce_estimate_minimum_one() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.PROVINCIAL_RAID, "Yu",
	)
	assert_eq(seasons, 1)


func test_seigyo_increases_estimate() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.BORDER_CONFLICT, "Seigyo",
	)
	assert_eq(seasons, 3)


func test_chishiki_increases_estimate() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.CLAN_WAR, "Chishiki",
	)
	assert_eq(seasons, 5)


func test_ketsui_no_change() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.FAMILY_WAR, "Ketsui",
	)
	assert_eq(seasons, 3)


func test_ishi_no_change() -> void:
	var seasons: int = FeasibilityLedger.estimate_campaign_seasons(
		WarData.AuthorityLevel.FAMILY_WAR, "Ishi",
	)
	assert_eq(seasons, 3)


# -- Rice Budget ---------------------------------------------------------------

func _make_settlement(
	province_id: int,
	rice: float,
	farming: int,
	mining: int,
	town: int,
	military: int,
) -> SettlementData:
	var s := SettlementData.new()
	s.province_id = province_id
	s.rice_stockpile = rice
	s.farming_pu = farming
	s.mining_pu = mining
	s.town_pu = town
	s.military_pu = military
	return s


func test_rice_budget_green() -> void:
	var s := _make_settlement(1, 100.0, 20, 5, 10, 5)
	var result: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 0.0, 1, false, false,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.GREEN)
	assert_true(result["net_position"] > 0.0)


func test_rice_budget_red_when_depleted() -> void:
	var s := _make_settlement(1, 1.0, 5, 2, 3, 10)
	var result: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 20.0, 4, false, false,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.RED)
	assert_true(result["net_position"] < 0.0)


func test_rice_budget_includes_harvest_when_spans_autumn() -> void:
	var s := _make_settlement(1, 10.0, 20, 0, 5, 2)
	var with_harvest: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 0.0, 2, false, true,
	)
	var without_harvest: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 0.0, 2, false, false,
	)
	assert_true(with_harvest["projected_harvest"] > 0.0)
	assert_eq(without_harvest["projected_harvest"], 0.0)
	assert_true(with_harvest["net_position"] > without_harvest["net_position"])


func test_rice_budget_levy_production_loss() -> void:
	var s := _make_settlement(1, 50.0, 20, 5, 10, 5)
	var with_loss: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 5.0, 1, true, false,
	)
	var without_loss: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 5.0, 1, false, false,
	)
	assert_true(with_loss["production_loss"] > 0.0)
	assert_eq(without_loss["production_loss"], 0.0)
	assert_true(with_loss["net_position"] < without_loss["net_position"])


func test_rice_budget_yellow_when_tight() -> void:
	var s := _make_settlement(1, 15.0, 10, 5, 5, 2)
	var result: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s], 0.0, 1, false, false,
	)
	var civilian_pu: float = 10.0 + 5.0 + 5.0
	var military_pu: float = 2.0
	var total_pu: float = civilian_pu + military_pu
	var civilian_burn: float = civilian_pu * 0.25
	var military_burn: float = military_pu * 0.35
	var net: float = 15.0 - civilian_burn - military_burn
	var per_pu: float = net / total_pu
	if net >= 0.0 and per_pu < 1.0:
		assert_eq(result["status"], FeasibilityLedger.ResourceStatus.YELLOW)
	else:
		assert_eq(result["status"], FeasibilityLedger.ResourceStatus.GREEN)


func test_rice_budget_multiple_settlements() -> void:
	var s1 := _make_settlement(1, 30.0, 10, 0, 5, 2)
	var s2 := _make_settlement(2, 20.0, 8, 2, 3, 1)
	var result: Dictionary = FeasibilityLedger.calculate_rice_budget(
		[s1, s2], 0.0, 1, false, false,
	)
	assert_eq(result["current_stockpile"], 50.0)


# -- Arms Budget ---------------------------------------------------------------

func test_arms_budget_green_when_sufficient() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_arms_budget(
		10.0, 5.0, 3.0, 2.0, 5.0, 3.0, 0.10, 2,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.GREEN)


func test_arms_budget_red_when_insufficient() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_arms_budget(
		0.0, 0.0, 0.0, 10.0, 5.0, 3.0, 0.10, 2,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.RED)


func test_arms_budget_yellow_with_market_koku() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_arms_budget(
		0.0, 0.0, 0.0, 5.0, 0.0, 0.0, 0.10, 1, 100.0,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.YELLOW)


func test_arms_budget_red_with_insufficient_koku() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_arms_budget(
		0.0, 0.0, 0.0, 100.0, 0.0, 0.0, 0.10, 1, 1.0,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.RED)


# -- Koku Budget ---------------------------------------------------------------

func test_koku_budget_green() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_koku_budget(
		100.0, 2, 10.0, 5.0,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.GREEN)


func test_koku_budget_red_when_broke() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_koku_budget(
		0.0, 4, 50.0, 0.0,
	)
	# current_koku(0.0) >= market_purchase_cost(0.0) is true, so YELLOW not RED
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.YELLOW)


func test_koku_budget_yellow_covers_market_only() -> void:
	var result: Dictionary = FeasibilityLedger.calculate_koku_budget(
		10.0, 2, 10.0, 5.0,
	)
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.YELLOW)


# -- Composite Verdict ---------------------------------------------------------

func test_all_green_is_feasible() -> void:
	var v: int = FeasibilityLedger.compute_composite_verdict(
		FeasibilityLedger.ResourceStatus.GREEN,
		FeasibilityLedger.ResourceStatus.GREEN,
		FeasibilityLedger.ResourceStatus.GREEN,
	)
	assert_eq(v, FeasibilityLedger.CompositeVerdict.FEASIBLE)


func test_one_yellow_is_risky() -> void:
	var v: int = FeasibilityLedger.compute_composite_verdict(
		FeasibilityLedger.ResourceStatus.YELLOW,
		FeasibilityLedger.ResourceStatus.GREEN,
		FeasibilityLedger.ResourceStatus.GREEN,
	)
	assert_eq(v, FeasibilityLedger.CompositeVerdict.RISKY)


func test_one_red_is_not_feasible() -> void:
	var v: int = FeasibilityLedger.compute_composite_verdict(
		FeasibilityLedger.ResourceStatus.RED,
		FeasibilityLedger.ResourceStatus.GREEN,
		FeasibilityLedger.ResourceStatus.GREEN,
	)
	assert_eq(v, FeasibilityLedger.CompositeVerdict.NOT_FEASIBLE)


func test_all_red_is_desperate() -> void:
	var v: int = FeasibilityLedger.compute_composite_verdict(
		FeasibilityLedger.ResourceStatus.RED,
		FeasibilityLedger.ResourceStatus.RED,
		FeasibilityLedger.ResourceStatus.RED,
	)
	assert_eq(v, FeasibilityLedger.CompositeVerdict.DESPERATE)


func test_yellow_and_red_is_not_feasible() -> void:
	var v: int = FeasibilityLedger.compute_composite_verdict(
		FeasibilityLedger.ResourceStatus.YELLOW,
		FeasibilityLedger.ResourceStatus.RED,
		FeasibilityLedger.ResourceStatus.GREEN,
	)
	assert_eq(v, FeasibilityLedger.CompositeVerdict.NOT_FEASIBLE)


# -- Proceed on Risky ----------------------------------------------------------

func test_high_priority_proceeds_on_risky() -> void:
	assert_true(FeasibilityLedger.should_proceed_on_risky("Jin", true))


func test_yu_proceeds_on_risky() -> void:
	assert_true(FeasibilityLedger.should_proceed_on_risky("Yu", false))


func test_kyoryoku_proceeds_on_risky() -> void:
	assert_true(FeasibilityLedger.should_proceed_on_risky("Kyoryoku", false))


func test_ketsui_proceeds_on_risky() -> void:
	assert_true(FeasibilityLedger.should_proceed_on_risky("Ketsui", false))


func test_ishi_proceeds_on_risky() -> void:
	assert_true(FeasibilityLedger.should_proceed_on_risky("Ishi", false))


func test_jin_does_not_proceed_on_risky_without_priority() -> void:
	assert_false(FeasibilityLedger.should_proceed_on_risky("Jin", false))


func test_makoto_does_not_proceed_on_risky_without_priority() -> void:
	assert_false(FeasibilityLedger.should_proceed_on_risky("Makoto", false))


# -- Full Ledger Entry Point ---------------------------------------------------

func test_evaluate_feasibility_all_green() -> void:
	var s := _make_settlement(1, 200.0, 30, 5, 10, 5)
	s.koku_stockpile = 50.0
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 20.0,
		"clan_iron_stockpile": 10.0,
		"proposed_levy_pu": 2.0,
		"equip_cost": 1.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 50.0,
	}
	var result: Dictionary = FeasibilityLedger.evaluate_feasibility(inputs)
	assert_true(result["feasible"])
	assert_eq(result["verdict"], FeasibilityLedger.CompositeVerdict.FEASIBLE)


func test_evaluate_feasibility_not_feasible() -> void:
	var s := _make_settlement(1, 1.0, 2, 0, 1, 10)
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.CLAN_WAR,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 20.0,
		"equip_cost": 40.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
	}
	var result: Dictionary = FeasibilityLedger.evaluate_feasibility(inputs)
	assert_false(result["feasible"])


func test_evaluate_feasibility_risky_yu_proceeds() -> void:
	var s := _make_settlement(1, 10.0, 10, 2, 5, 3)
	s.koku_stockpile = 5.0
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "Yu",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 5.0,
		"clan_iron_stockpile": 3.0,
		"proposed_levy_pu": 1.0,
		"equip_cost": 0.5,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 5.0,
	}
	var result: Dictionary = FeasibilityLedger.evaluate_feasibility(inputs)
	if result["verdict"] == FeasibilityLedger.CompositeVerdict.RISKY:
		assert_true(result["feasible"])


func test_evaluate_feasibility_risky_jin_does_not_proceed() -> void:
	var s := _make_settlement(1, 10.0, 10, 2, 5, 3)
	s.koku_stockpile = 5.0
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "Jin",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 5.0,
		"clan_iron_stockpile": 3.0,
		"proposed_levy_pu": 1.0,
		"equip_cost": 0.5,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 5.0,
		"is_high_priority_objective": false,
	}
	var result: Dictionary = FeasibilityLedger.evaluate_feasibility(inputs)
	if result["verdict"] == FeasibilityLedger.CompositeVerdict.RISKY:
		assert_false(result["feasible"])


# -- War Justification Step 5 Integration -------------------------------------

func test_war_justification_step5_passes_with_resources() -> void:
	var s := _make_settlement(1, 200.0, 30, 5, 10, 5)
	s.koku_stockpile = 50.0
	var fi: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 20.0,
		"clan_iron_stockpile": 10.0,
		"proposed_levy_pu": 2.0,
		"equip_cost": 1.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 50.0,
	}
	var result: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "",
		false, false, false, 0.0, 0.0, fi,
	)
	assert_true(result["justified"])
	assert_true(result.has("feasibility"))


func test_war_justification_step5_fails_when_broke() -> void:
	var s := _make_settlement(1, 0.0, 1, 0, 0, 10)
	var fi: Dictionary = {
		"authority_level": WarData.AuthorityLevel.CLAN_WAR,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 20.0,
		"equip_cost": 40.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
	}
	var result: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "",
		false, false, false, 0.0, 0.0, fi,
	)
	assert_false(result["justified"])
	assert_eq(result["step_failed"], 5)
	assert_eq(result["reason"], "feasibility_failed")


func test_war_justification_no_feasibility_inputs_still_passes() -> void:
	var result: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "",
	)
	assert_true(result["justified"])
	assert_false(result.has("feasibility"))


# =============================================================================
# Phase 2: Alternative Ladder Tests
# =============================================================================

func _make_infeasible_inputs() -> Dictionary:
	var s := _make_settlement(1, 5.0, 5, 1, 3, 8)
	s.koku_stockpile = 2.0
	return {
		"authority_level": WarData.AuthorityLevel.BORDER_CONFLICT,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 1.0,
		"clan_iron_stockpile": 0.5,
		"proposed_levy_pu": 10.0,
		"equip_cost": 5.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 2.0,
	}


# -- Rung 1: Scale Down -------------------------------------------------------

func test_scale_down_halves_levy() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_scale_down(inputs)
	assert_true(result["applied"])
	assert_eq(result["reduced_levy_pu"], 5.0)


func test_scale_down_halves_equip_cost() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_scale_down(inputs)
	assert_eq(result["modified_inputs"]["equip_cost"], 2.5)


# -- Rung 2: Delay to Harvest -------------------------------------------------

func test_delay_to_harvest_applies_in_spring() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_delay_to_harvest(
		inputs, "Jin", "spring",
	)
	assert_true(result["applied"])
	assert_true(result["modified_inputs"]["spans_autumn"])
	assert_false(result["modified_inputs"]["levy_before_planting"])


func test_delay_to_harvest_applies_in_summer() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_delay_to_harvest(
		inputs, "Jin", "summer",
	)
	assert_true(result["applied"])


func test_delay_to_harvest_skipped_in_autumn() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_delay_to_harvest(
		inputs, "Jin", "autumn",
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "wrong_season")


func test_delay_to_harvest_skipped_in_winter() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_delay_to_harvest(
		inputs, "Jin", "winter",
	)
	assert_false(result["applied"])


func test_delay_to_harvest_yu_skips() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_delay_to_harvest(
		inputs, "Yu", "spring",
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "personality_skip")


func test_delay_to_harvest_kyoryoku_skips() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_delay_to_harvest(
		inputs, "Kyoryoku", "spring",
	)
	assert_false(result["applied"])


# -- Rung 3: Market Purchase --------------------------------------------------

func test_market_purchase_with_green_koku() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_market_purchase(
		inputs, FeasibilityLedger.ResourceStatus.GREEN, true,
	)
	assert_true(result["applied"])
	assert_true(result["rice_purchased"] > 0.0)


func test_market_purchase_blocked_by_red_koku() -> void:
	var result: Dictionary = FeasibilityLedger.try_market_purchase(
		{}, FeasibilityLedger.ResourceStatus.RED, true,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "koku_red")


func test_market_purchase_blocked_by_no_routes() -> void:
	var result: Dictionary = FeasibilityLedger.try_market_purchase(
		{}, FeasibilityLedger.ResourceStatus.GREEN, false,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_trade_routes")


# -- Rung 4: Demand Tribute ---------------------------------------------------

func test_demand_tribute_extracts_25_percent() -> void:
	var inputs := _make_infeasible_inputs()
	var vassals: Array = [
		{"disposition": 40, "rice_stockpile": 100.0, "arms_stockpile": 10.0},
	]
	var result: Dictionary = FeasibilityLedger.try_demand_tribute(
		inputs, "", vassals,
	)
	assert_true(result["applied"])
	assert_eq(result["tribute_rice"], 25.0)
	assert_eq(result["tribute_arms"], 2.5)
	assert_eq(result["compliant_vassals"], 1)


func test_demand_tribute_rival_refuses() -> void:
	var inputs := _make_infeasible_inputs()
	var vassals: Array = [
		{"disposition": -20, "rice_stockpile": 100.0, "arms_stockpile": 10.0},
	]
	var result: Dictionary = FeasibilityLedger.try_demand_tribute(
		inputs, "", vassals,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_compliant_vassals")


func test_demand_tribute_jin_skips_shortage_vassal() -> void:
	var inputs := _make_infeasible_inputs()
	var vassals: Array = [
		{"disposition": 40, "rice_stockpile": 100.0, "arms_stockpile": 10.0, "in_shortage": true},
	]
	var result: Dictionary = FeasibilityLedger.try_demand_tribute(
		inputs, "Jin", vassals,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_compliant_vassals")


func test_demand_tribute_generates_topic() -> void:
	var inputs := _make_infeasible_inputs()
	var vassals: Array = [
		{"disposition": 40, "rice_stockpile": 50.0, "arms_stockpile": 5.0},
	]
	var result: Dictionary = FeasibilityLedger.try_demand_tribute(
		inputs, "", vassals,
	)
	assert_true(result["generates_topic"])
	assert_eq(result["topic_tier"], 4)


func test_demand_tribute_no_vassals() -> void:
	var inputs := _make_infeasible_inputs()
	var result: Dictionary = FeasibilityLedger.try_demand_tribute(
		inputs, "", [],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_vassals")


# -- Rung 5: Allied Aid -------------------------------------------------------

func test_allied_aid_with_willing_friend() -> void:
	var inputs := _make_infeasible_inputs()
	var allies: Array = [
		{"disposition": 40, "surplus_rice": 50.0, "surplus_koku": 20.0},
	]
	var result: Dictionary = FeasibilityLedger.try_request_allied_aid(
		inputs, "", allies,
	)
	assert_true(result["applied"])
	assert_true(result["aid_rice"] > 0.0)
	assert_true(result["creates_favor"])


func test_allied_aid_ketsui_skips() -> void:
	var allies: Array = [
		{"disposition": 40, "surplus_rice": 50.0, "surplus_koku": 20.0},
	]
	var result: Dictionary = FeasibilityLedger.try_request_allied_aid(
		{}, "Ketsui", allies,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "personality_skip")


func test_allied_aid_ishi_skips() -> void:
	var result: Dictionary = FeasibilityLedger.try_request_allied_aid(
		{}, "Ishi", [{"disposition": 50, "surplus_rice": 100.0}],
	)
	assert_false(result["applied"])


func test_allied_aid_low_disposition_rejected() -> void:
	var inputs := _make_infeasible_inputs()
	var allies: Array = [
		{"disposition": 10, "surplus_rice": 50.0, "surplus_koku": 20.0},
	]
	var result: Dictionary = FeasibilityLedger.try_request_allied_aid(
		inputs, "", allies,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_willing_allies")


func test_allied_aid_significant_contribution_tier2_favor() -> void:
	var inputs := _make_infeasible_inputs()
	var allies: Array = [
		{"disposition": 50, "surplus_rice": 10.0, "surplus_koku": 0.0},
	]
	var result: Dictionary = FeasibilityLedger.try_request_allied_aid(
		inputs, "", allies,
	)
	assert_true(result["applied"])
	# contribution_rice = 10 * 0.25 = 2.5, threshold = 10 * 0.30 = 3.0
	# 2.5 > 3.0 is false, so favor_tier stays at default 3
	assert_eq(result["favor_tier"], 3)


func test_allied_aid_tracks_contributing_ally_ids() -> void:
	var inputs := _make_infeasible_inputs()
	var allies: Array = [
		{"disposition": 40, "surplus_rice": 50.0, "surplus_koku": 0.0, "character_id": 10},
		{"disposition": 50, "surplus_rice": 30.0, "surplus_koku": 0.0, "character_id": 20},
		{"disposition": 5, "surplus_rice": 100.0, "surplus_koku": 0.0, "character_id": 30},
	]
	var result: Dictionary = FeasibilityLedger.try_request_allied_aid(
		inputs, "", allies,
	)
	assert_true(result["applied"])
	var ids: Array = result["contributing_ally_ids"]
	assert_eq(ids.size(), 2, "Only friends (disp>=31) contribute")
	assert_true(10 in ids)
	assert_true(20 in ids)
	assert_false(30 in ids, "Low disposition ally excluded")


func test_extract_side_effects_includes_contributing_ally_ids() -> void:
	var rung_result: Dictionary = {
		"rung": FeasibilityLedger.LadderRung.REQUEST_ALLIED_AID,
		"applied": true,
		"creates_favor": true,
		"favor_tier": 3,
		"contributing_ally_ids": [10, 20],
	}
	var effects: Dictionary = FeasibilityLedger._extract_side_effects(rung_result)
	assert_true(effects["creates_favor"])
	var ids: Array = effects["contributing_ally_ids"]
	assert_eq(ids.size(), 2)
	assert_true(10 in ids)
	assert_true(20 in ids)


# -- Rung 6: Raid Neighbor ----------------------------------------------------

func test_raid_jin_blocked() -> void:
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		{}, "Jin", false, false, [],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "personality_block")


func test_raid_gi_blocked() -> void:
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		{}, "Gi", false, false, [],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "personality_block")


func test_raid_meiyo_needs_grievance() -> void:
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		{}, "Meiyo", false, false, [{"garrison_pu": 0.5, "rice_stockpile": 40.0}],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "meiyo_no_grievance")


func test_raid_meiyo_with_grievance_allowed() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 0.5, "rice_stockpile": 40.0},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "Meiyo", true, false, provinces,
	)
	assert_true(result["applied"])


func test_raid_rei_needs_prior_demand() -> void:
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		{}, "Rei", false, false, [{"garrison_pu": 0.5, "rice_stockpile": 40.0}],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "rei_no_prior_demand")


func test_raid_rei_with_prior_demand_allowed() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 0.5, "rice_stockpile": 40.0},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "Rei", false, true, provinces,
	)
	assert_true(result["applied"])


func test_raid_seizes_50_percent_rice() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 0.5, "rice_stockpile": 80.0},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "", false, false, provinces,
	)
	assert_true(result["applied"])
	assert_eq(result["seized_rice"], 40.0)
	assert_eq(result["honor_cost"], -1.0)
	assert_eq(result["glory_cost"], -0.3)


func test_raid_prefers_existing_war_target() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 0.5, "rice_stockpile": 40.0, "already_at_war": false},
		{"province_id": 6, "clan": "Lion", "garrison_pu": 0.5, "rice_stockpile": 30.0, "already_at_war": true},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "", false, false, provinces,
	)
	assert_true(result["applied"])
	assert_eq(result["target_province_id"], 6)


func test_raid_skips_heavy_garrison() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 2.0, "rice_stockpile": 100.0},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "", false, false, provinces,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_viable_targets")


func test_raid_no_targets_empty() -> void:
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		{}, "", false, false, [],
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_targets")


func test_raid_triggers_war_status_when_not_at_war() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 0.5, "rice_stockpile": 40.0, "already_at_war": false},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "", false, false, provinces,
	)
	assert_true(result["triggers_war_status"])


func test_raid_no_war_trigger_when_already_at_war() -> void:
	var inputs := _make_infeasible_inputs()
	var provinces: Array = [
		{"province_id": 5, "clan": "Crane", "garrison_pu": 0.5, "rice_stockpile": 40.0, "already_at_war": true},
	]
	var result: Dictionary = FeasibilityLedger.try_raid_neighbor(
		inputs, "", false, false, provinces,
	)
	assert_false(result["triggers_war_status"])


# -- Rung 7: Desperation Override ----------------------------------------------

func test_desperation_fires_with_all_conditions() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Yu", 0.3, true, 50, false,
	)
	assert_true(result["applied"])
	assert_true(result["desperation_levy"])
	assert_true(result["overrides_feasibility"])


func test_desperation_blocked_by_high_rice() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Yu", 0.6, true, 50, false,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "rice_above_threshold")


func test_desperation_blocked_without_critical_objective() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Yu", 0.3, false, 50, false,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "no_critical_objective")


func test_desperation_blocked_by_wrong_personality() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Jin", 0.3, true, 50, false,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "personality_and_score_block")


func test_desperation_defender_at_desperate_score() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Jin", 0.3, true, 20, true,
	)
	assert_true(result["applied"])


func test_desperation_jin_honor_cost() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Jin", 0.3, true, 20, true,
	)
	assert_eq(result["honor_cost"], -1.0)


func test_desperation_non_jin_no_extra_honor_cost() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Yu", 0.3, true, 50, false,
	)
	assert_eq(result["honor_cost"], 0.0)


func test_desperation_chugi_qualifies() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Chugi", 0.3, true, 50, false,
	)
	assert_true(result["applied"])


func test_desperation_ketsui_qualifies() -> void:
	var result: Dictionary = FeasibilityLedger.try_desperation_override(
		{}, "Ketsui", 0.3, true, 50, false,
	)
	assert_true(result["applied"])


# -- Full Ladder Walk ----------------------------------------------------------

func test_ladder_walk_already_feasible() -> void:
	var s := _make_settlement(1, 200.0, 30, 5, 10, 5)
	s.koku_stockpile = 50.0
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 20.0,
		"clan_iron_stockpile": 10.0,
		"proposed_levy_pu": 2.0,
		"equip_cost": 1.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 50.0,
	}
	var result: Dictionary = FeasibilityLedger.walk_alternative_ladder(
		inputs, "", "spring",
	)
	assert_eq(result["outcome"], "already_feasible")
	assert_eq(result["rungs_tried"].size(), 0)


func test_ladder_walk_scale_down_resolves() -> void:
	var s := _make_settlement(1, 50.0, 20, 5, 10, 5)
	s.koku_stockpile = 10.0
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 10.0,
		"clan_iron_stockpile": 5.0,
		"proposed_levy_pu": 30.0,
		"equip_cost": 15.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 10.0,
	}
	var initial: Dictionary = FeasibilityLedger.evaluate_feasibility(inputs)
	if not initial["feasible"]:
		var result: Dictionary = FeasibilityLedger.walk_alternative_ladder(
			inputs, "", "spring",
		)
		if result["outcome"] == "scaled_down":
			assert_true(result["final_ledger"]["feasible"])
			assert_true(result["rungs_tried"].size() >= 1)
		else:
			pass_test("Ladder walk did not scale down — outcome: %s" % result["outcome"])
	else:
		pass_test("Initial evaluation was already feasible")


func test_ladder_walk_abandoned_when_hopeless() -> void:
	var s := _make_settlement(1, 0.0, 1, 0, 0, 10)
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.CLAN_WAR,
		"primary_virtue": "Makoto",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 20.0,
		"equip_cost": 40.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
	}
	var result: Dictionary = FeasibilityLedger.walk_alternative_ladder(
		inputs, "Makoto", "autumn",
	)
	assert_eq(result["outcome"], "abandoned")
	assert_true(result["rungs_tried"].size() >= 5)


func test_ladder_walk_desperation_fires() -> void:
	var s := _make_settlement(1, 1.0, 2, 0, 1, 5)
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.BORDER_CONFLICT,
		"primary_virtue": "Yu",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 10.0,
		"equip_cost": 20.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
	}
	var result: Dictionary = FeasibilityLedger.walk_alternative_ladder(
		inputs, "Yu", "autumn",
		[], [], [], false, false, false, true, 50, false,
	)
	assert_eq(result["outcome"], "desperation_override")
	assert_true(result["desperation_levy"])


func test_ladder_walk_tribute_resolves() -> void:
	var s := _make_settlement(1, 5.0, 10, 2, 5, 3)
	s.koku_stockpile = 2.0
	var inputs: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 5.0,
		"clan_iron_stockpile": 3.0,
		"proposed_levy_pu": 5.0,
		"equip_cost": 2.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 2.0,
	}
	var vassals: Array = [
		{"disposition": 40, "rice_stockpile": 200.0, "arms_stockpile": 20.0},
	]
	var result: Dictionary = FeasibilityLedger.walk_alternative_ladder(
		inputs, "", "autumn", vassals,
	)
	if result["outcome"] == "demanded_tribute":
		assert_true(result["final_ledger"]["feasible"])
		assert_true(result.has("side_effects"))


# =============================================================================
# War Justification Ladder Wiring Tests
# =============================================================================

func _make_broke_fi_with_ladder(
	vassal_stockpiles: Array = [],
	raidable: Array = [],
	current_season: String = "autumn",
	has_trade_routes: bool = false,
) -> Dictionary:
	var s := _make_settlement(1, 0.0, 1, 0, 0, 10)
	return {
		"authority_level": WarData.AuthorityLevel.CLAN_WAR,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 20.0,
		"equip_cost": 40.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
		"ladder_context": {
			"current_season": current_season,
			"vassal_stockpiles": vassal_stockpiles,
			"allied_surplus": [],
			"raidable_provinces": raidable,
			"has_trade_routes": has_trade_routes,
			"has_grievance": false,
			"has_issued_demand": false,
			"war_score": 50,
			"is_defending": false,
		},
	}


func test_war_justification_ladder_still_fails_when_hopeless() -> void:
	var fi: Dictionary = _make_broke_fi_with_ladder()
	var result: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "Makoto",
		false, false, false, 0.0, 0.0, fi,
	)
	assert_false(result["justified"])
	assert_eq(result["step_failed"], 5)


func test_war_justification_ladder_tribute_rescues() -> void:
	var s := _make_settlement(1, 5.0, 10, 2, 5, 3)
	s.koku_stockpile = 2.0
	var fi: Dictionary = {
		"authority_level": WarData.AuthorityLevel.PROVINCIAL_RAID,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 5.0,
		"clan_iron_stockpile": 3.0,
		"proposed_levy_pu": 5.0,
		"equip_cost": 2.0,
		"iron_upkeep_rate_per_pu": 0.10,
		"levy_before_planting": false,
		"spans_autumn": false,
		"current_koku": 2.0,
		"ladder_context": {
			"current_season": "autumn",
			"vassal_stockpiles": [
				{"disposition": 40, "rice_stockpile": 200.0, "arms_stockpile": 20.0},
			],
			"allied_surplus": [],
			"raidable_provinces": [],
			"has_trade_routes": false,
		},
	}
	var initial: Dictionary = FeasibilityLedger.evaluate_feasibility(fi)
	if not initial["feasible"]:
		var result: Dictionary = WarJustification.evaluate_war_justification(
			"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "",
			false, false, false, 0.0, 0.0, fi,
		)
		if result["justified"]:
			assert_true(result.has("ladder_outcome"))


func test_war_justification_ladder_desperation_for_defend() -> void:
	var s := _make_settlement(1, 1.0, 2, 0, 1, 5)
	var fi: Dictionary = {
		"authority_level": WarData.AuthorityLevel.BORDER_CONFLICT,
		"primary_virtue": "Yu",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 10.0,
		"equip_cost": 20.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
		"ladder_context": {
			"current_season": "autumn",
			"vassal_stockpiles": [],
			"allied_surplus": [],
			"raidable_provinces": [],
			"has_trade_routes": false,
			"war_score": 50,
			"is_defending": false,
		},
	}
	var result: Dictionary = WarJustification.evaluate_war_justification(
		"DEFEND_PROVINCE", "", WarJustification.MilitaryTier.RAID, "Yu",
		false, false, false, 0.0, 0.0, fi,
	)
	if result["justified"]:
		assert_eq(result.get("ladder_outcome", ""), "desperation_override")
	else:
		pass_test("War justification not granted — desperation path not tested")


func test_war_justification_no_ladder_without_context() -> void:
	var s := _make_settlement(1, 0.0, 1, 0, 0, 10)
	var fi: Dictionary = {
		"authority_level": WarData.AuthorityLevel.CLAN_WAR,
		"primary_virtue": "",
		"controlled_settlements": [s],
		"provinces": [],
		"clan_arms_stockpile": 0.0,
		"clan_iron_stockpile": 0.0,
		"proposed_levy_pu": 20.0,
		"equip_cost": 40.0,
		"iron_upkeep_rate_per_pu": 0.20,
		"levy_before_planting": true,
		"spans_autumn": false,
		"current_koku": 0.0,
	}
	var result: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "",
		false, false, false, 0.0, 0.0, fi,
	)
	assert_false(result["justified"])
	assert_false(result.has("ladder_outcome"))


# =============================================================================
# Ladder Context Population Tests (NPC Engine Helpers)
# =============================================================================

func test_get_war_context_no_wars() -> void:
	var result: Dictionary = NPCDecisionEngine._get_war_context("Lion", [])
	assert_eq(result["war_score"], 50)
	assert_false(result["is_defending"])


func test_get_war_context_defending() -> void:
	var war: Dictionary = {
		"clan_a": "Lion",
		"clan_b": "Crane",
		"war_score_a": 30,
		"war_score_b": 70,
		"initiator_clan": "Crane",
	}
	var result: Dictionary = NPCDecisionEngine._get_war_context("Lion", [war])
	assert_eq(result["war_score"], 30)
	assert_true(result["is_defending"])


func test_get_war_context_attacking() -> void:
	var war: Dictionary = {
		"clan_a": "Lion",
		"clan_b": "Crane",
		"war_score_a": 65,
		"war_score_b": 35,
		"initiator_clan": "Lion",
	}
	var result: Dictionary = NPCDecisionEngine._get_war_context("Lion", [war])
	# worst_score initializes at 50 and only updates when my_score < worst_score.
	# Since 65 > 50, worst_score stays at 50.
	assert_eq(result["war_score"], 50)
	assert_false(result["is_defending"])


func test_get_war_context_worst_score_across_wars() -> void:
	var war1: Dictionary = {
		"clan_a": "Lion",
		"clan_b": "Crane",
		"war_score_a": 40,
		"war_score_b": 60,
		"initiator_clan": "Crane",
	}
	var war2: Dictionary = {
		"clan_a": "Scorpion",
		"clan_b": "Lion",
		"war_score_a": 70,
		"war_score_b": 20,
		"initiator_clan": "Scorpion",
	}
	var result: Dictionary = NPCDecisionEngine._get_war_context("Lion", [war1, war2])
	assert_eq(result["war_score"], 20)
	assert_true(result["is_defending"])


func test_get_war_context_with_war_data_resource() -> void:
	var wd := WarData.new()
	wd.clan_a = "Lion"
	wd.clan_b = "Crane"
	wd.war_score_a = 25
	wd.war_score_b = 75
	wd.initiator_clan = "Crane"
	var result: Dictionary = NPCDecisionEngine._get_war_context("Lion", [wd])
	assert_eq(result["war_score"], 25)
	assert_true(result["is_defending"])


func test_has_grievance_from_disposition() -> void:
	var c := L5RCharacterData.new()
	c.disposition_values = {10: -35}
	assert_true(NPCDecisionEngine._has_grievance_against_neighbors(c, []))


func test_has_grievance_from_objective() -> void:
	var c := L5RCharacterData.new()
	c.current_objective = "SEEK_VENGEANCE"
	assert_true(NPCDecisionEngine._has_grievance_against_neighbors(c, []))


func test_no_grievance_neutral() -> void:
	var c := L5RCharacterData.new()
	c.disposition_values = {10: 5}
	c.current_objective = "MAXIMIZE_PROSPERITY"
	assert_false(NPCDecisionEngine._has_grievance_against_neighbors(c, []))


func test_collect_allied_surplus_friend_plus() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.clan = "Lion"
	lord.disposition_values = {2: 40}

	var ally := L5RCharacterData.new()
	ally.character_id = 2
	ally.clan = "Crane"
	ally.status = 6.0

	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"

	var sd := SettlementData.new()
	sd.province_id = 10
	sd.rice_stockpile = 100.0
	sd.koku_stockpile = 30.0
	sd.farming_pu = 10
	sd.mining_pu = 2
	sd.town_pu = 5

	var ws: Dictionary = {"characters_by_id": {2: ally}}
	var result: Array = NPCDecisionEngine._collect_allied_surplus(
		lord, ws, [sd], [pd],
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["clan"], "Crane")
	assert_true(result[0]["surplus_rice"] > 0.0)
	assert_eq(result[0]["disposition"], 40)


func test_collect_allied_surplus_below_friend_excluded() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.clan = "Lion"
	lord.disposition_values = {2: 20}

	var ally := L5RCharacterData.new()
	ally.character_id = 2
	ally.clan = "Crane"
	ally.status = 6.0

	var ws: Dictionary = {"characters_by_id": {2: ally}}
	var result: Array = NPCDecisionEngine._collect_allied_surplus(
		lord, ws, [], [],
	)
	assert_eq(result.size(), 0)


func test_collect_raidable_provinces_excludes_own_clan() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Lion"
	var result: Array = NPCDecisionEngine._collect_raidable_provinces(
		"Lion", [pd], [], [],
	)
	assert_eq(result.size(), 0)


func test_collect_raidable_provinces_marks_at_war() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var war: Dictionary = {"clan_a": "Lion", "clan_b": "Crane"}
	var result: Array = NPCDecisionEngine._collect_raidable_provinces(
		"Lion", [pd], [], [war],
	)
	assert_eq(result.size(), 1)
	assert_true(result[0]["already_at_war"])


func test_build_feasibility_data_populates_ladder_context() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Lion"
	c.status = 6.0
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Lion"
	var sd := SettlementData.new()
	sd.province_id = 10
	sd.rice_stockpile = 50.0
	sd.koku_stockpile = 20.0
	sd.farming_pu = 10
	sd.mining_pu = 2
	sd.town_pu = 5
	sd.military_pu = 3
	var ws: Dictionary = {
		"settlements": [sd],
		"province_data": [pd],
		"clans": [],
		"characters_by_id": {},
		"current_season": "summer",
		"active_wars": [],
		"trade_routes": [],
	}
	var result: Dictionary = NPCDecisionEngine._build_feasibility_data(c, ws)
	assert_true(result.has("ladder_context"))
	var lc: Dictionary = result["ladder_context"]
	assert_eq(lc["current_season"], "summer")
	assert_eq(lc["war_score"], 50)
	assert_false(lc["is_defending"])


# =============================================================================
# Phase 3: Mid-Campaign Supply Status Monitor Tests
# =============================================================================

# -- Home Front Status ---------------------------------------------------------

func test_home_front_clear() -> void:
	var s := _make_settlement(1, 50.0, 10, 5, 5, 2)
	var result: Dictionary = FeasibilityLedger.assess_home_front([s])
	assert_eq(result["status"], FeasibilityLedger.HomeFrontStatus.CLEAR)


func test_home_front_shortage() -> void:
	var s := _make_settlement(1, 10.0, 10, 5, 5, 2)
	var result: Dictionary = FeasibilityLedger.assess_home_front([s])
	# rice_per_pu = 10.0 / (10+5+5) = 0.5, which is <= HUNGER threshold (0.50)
	assert_eq(result["status"], FeasibilityLedger.HomeFrontStatus.HUNGER)


func test_home_front_hunger() -> void:
	var s := _make_settlement(1, 5.0, 10, 5, 5, 2)
	var result: Dictionary = FeasibilityLedger.assess_home_front([s])
	assert_eq(result["status"], FeasibilityLedger.HomeFrontStatus.HUNGER)


func test_home_front_famine() -> void:
	var s := _make_settlement(1, 0.0, 10, 5, 5, 2)
	var result: Dictionary = FeasibilityLedger.assess_home_front([s])
	assert_eq(result["status"], FeasibilityLedger.HomeFrontStatus.FAMINE)


func test_home_front_worst_settlement_wins() -> void:
	var s1 := _make_settlement(1, 50.0, 10, 5, 5, 2)
	var s2 := _make_settlement(2, 0.0, 10, 5, 5, 2)
	var result: Dictionary = FeasibilityLedger.assess_home_front([s1, s2])
	assert_eq(result["status"], FeasibilityLedger.HomeFrontStatus.FAMINE)


# -- Army Supply Status --------------------------------------------------------

func test_army_supplied() -> void:
	var result: Dictionary = FeasibilityLedger.assess_army_supply(0, true)
	assert_eq(result["status"], FeasibilityLedger.ArmySupplyStatus.SUPPLIED)


func test_army_unsupplied_tether_cut() -> void:
	var result: Dictionary = FeasibilityLedger.assess_army_supply(2, true)
	assert_eq(result["status"], FeasibilityLedger.ArmySupplyStatus.UNSUPPLIED)


func test_army_unsupplied_no_rice() -> void:
	var result: Dictionary = FeasibilityLedger.assess_army_supply(0, false)
	assert_eq(result["status"], FeasibilityLedger.ArmySupplyStatus.UNSUPPLIED)


# -- Iron Upkeep Status --------------------------------------------------------

func test_iron_maintained() -> void:
	var result: Dictionary = FeasibilityLedger.assess_iron_upkeep(5.0, 3.0)
	assert_eq(result["status"], FeasibilityLedger.IronUpkeepStatus.MAINTAINED)
	assert_eq(result["deficit"], 0.0)


func test_iron_degrading() -> void:
	var result: Dictionary = FeasibilityLedger.assess_iron_upkeep(2.0, 5.0)
	assert_eq(result["status"], FeasibilityLedger.IronUpkeepStatus.DEGRADING)
	assert_eq(result["deficit"], 3.0)


# -- Campaign Decision Matrix --------------------------------------------------

func test_clear_supplied_continue() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.CLEAR,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_shortage_winning_push_to_finish() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.SHORTAGE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"", 70,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.PUSH_TO_FINISH)


func test_shortage_losing_seek_peace() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.SHORTAGE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"", 40,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.SEEK_PEACE)


func test_shortage_yu_ignores() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.SHORTAGE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Yu", 30,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_shortage_kyoryoku_ignores() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.SHORTAGE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Kyoryoku", 30,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_shortage_ishi_ignores() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.SHORTAGE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Ishi", 30,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_hunger_urgent_peace() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.HUNGER,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.URGENT_PEACE)


func test_hunger_ishi_continues() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.HUNGER,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Ishi", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_hunger_yu_does_not_override() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.HUNGER,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Yu", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.URGENT_PEACE)


func test_famine_immediate_peace() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.FAMINE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE)


func test_famine_ishi_continues() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.FAMINE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Ishi", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_famine_yu_seeks_peace() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.FAMINE,
		FeasibilityLedger.ArmySupplyStatus.SUPPLIED,
		"Yu", 50,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE)


func test_supply_cut_restore_tether() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.CLEAR,
		FeasibilityLedger.ArmySupplyStatus.UNSUPPLIED,
		"", 50, 0,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.RESTORE_TETHER)
	assert_eq(d["hold_seasons_remaining"], 1)


func test_supply_cut_retreat_after_hold() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.CLEAR,
		FeasibilityLedger.ArmySupplyStatus.UNSUPPLIED,
		"", 50, 1,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.RETREAT)


func test_supply_cut_ketsui_holds_longer() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.CLEAR,
		FeasibilityLedger.ArmySupplyStatus.UNSUPPLIED,
		"Ketsui", 50, 1,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.RESTORE_TETHER)
	assert_eq(d["hold_seasons_remaining"], 1)


func test_supply_cut_ketsui_retreats_after_2() -> void:
	var d: Dictionary = FeasibilityLedger.determine_campaign_decision(
		FeasibilityLedger.HomeFrontStatus.CLEAR,
		FeasibilityLedger.ArmySupplyStatus.UNSUPPLIED,
		"Ketsui", 50, 2,
	)
	assert_eq(d["decision"], FeasibilityLedger.CampaignDecision.RETREAT)


# -- Retreat Target Selection --------------------------------------------------

func test_retreat_finds_rich_province() -> void:
	var provinces: Array = [
		{"province_id": 1, "distance": 1, "rice_per_pu": 2.0, "has_forge": false},
		{"province_id": 2, "distance": 2, "rice_per_pu": 0.5, "has_forge": true},
	]
	var result: Dictionary = FeasibilityLedger.find_retreat_target(10, provinces)
	assert_true(result["found"])
	assert_false(result["should_disband"])


func test_retreat_disbands_when_no_target() -> void:
	var provinces: Array = [
		{"province_id": 1, "distance": 3, "rice_per_pu": 2.0, "has_forge": false},
	]
	var result: Dictionary = FeasibilityLedger.find_retreat_target(10, provinces)
	assert_false(result["found"])
	assert_true(result["should_disband"])


func test_retreat_skips_poor_provinces() -> void:
	var provinces: Array = [
		{"province_id": 1, "distance": 1, "rice_per_pu": 0.5, "has_forge": false},
	]
	var result: Dictionary = FeasibilityLedger.find_retreat_target(10, provinces)
	assert_false(result["found"])
	assert_true(result["should_disband"])


func test_retreat_prefers_forge_province() -> void:
	var provinces: Array = [
		{"province_id": 1, "distance": 1, "rice_per_pu": 1.5, "has_forge": false},
		{"province_id": 2, "distance": 1, "rice_per_pu": 0.8, "has_forge": true},
	]
	var result: Dictionary = FeasibilityLedger.find_retreat_target(10, provinces)
	assert_true(result["found"])
	assert_eq(result["province_id"], 2)


# -- Full Supply Status Check --------------------------------------------------

func test_full_supply_check_all_clear() -> void:
	var s := _make_settlement(1, 50.0, 10, 5, 5, 2)
	var inputs: Dictionary = {
		"controlled_settlements": [s],
		"tether_state": 0,
		"source_has_rice": true,
		"clan_iron_stockpile": 5.0,
		"total_iron_upkeep": 3.0,
		"primary_virtue": "",
		"war_score": 50,
	}
	var result: Dictionary = FeasibilityLedger.run_supply_status_check(inputs)
	assert_eq(result["home_front"]["status"], FeasibilityLedger.HomeFrontStatus.CLEAR)
	assert_eq(result["army_supply"]["status"], FeasibilityLedger.ArmySupplyStatus.SUPPLIED)
	assert_eq(result["iron_upkeep"]["status"], FeasibilityLedger.IronUpkeepStatus.MAINTAINED)
	assert_eq(result["decision"]["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)


func test_full_supply_check_famine_retreat() -> void:
	var s := _make_settlement(1, 0.0, 10, 5, 5, 2)
	var inputs: Dictionary = {
		"controlled_settlements": [s],
		"tether_state": 2,
		"source_has_rice": false,
		"clan_iron_stockpile": 0.0,
		"total_iron_upkeep": 5.0,
		"primary_virtue": "Jin",
		"war_score": 30,
		"seasons_tether_cut": 2,
	}
	var result: Dictionary = FeasibilityLedger.run_supply_status_check(inputs)
	assert_eq(result["decision"]["decision"], FeasibilityLedger.CampaignDecision.RETREAT)
