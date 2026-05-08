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
	assert_eq(result["status"], FeasibilityLedger.ResourceStatus.RED)


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
