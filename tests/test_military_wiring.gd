extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_army_state(is_marching: bool = true, days_remaining: int = 2) -> Dictionary:
	return {
		"army_id": 1,
		"is_marching": is_marching,
		"days_remaining": days_remaining,
		"current_sub_tile": 0,
		"path": [0, 1, 2],
		"path_index": 0,
		"total_travel_days": 3,
	}


func _make_siege_state() -> Dictionary:
	return {
		"siege_id": 1,
		"ticks_elapsed": 5,
		"rice_stockpile": 2.0,
		"civilian_pu": 10,
		"garrison_pu": 0.5,
		"events_fired": [],
		"personality_tag": "default",
		"honor_ticks_without_sortie": 0,
		"sheltered_army_pu": 0.0,
		"starvation_stage": 0,
	}


func _make_order_state() -> Dictionary:
	return OrderSystem.create_order_state(
		1, Enums.MilitaryRank.TAISA,
	)


func _make_company_dict(
	id: int,
	unit_type: int = Enums.CompanyUnitType.PEASANT_LEVY,
) -> Dictionary:
	return {
		"company_id": id,
		"unit_type": unit_type,
		"commander_id": -1,
		"clan_name": "Crab",
	}


func _make_company_data(
	id: int,
	source_province_id: int = 1,
) -> MilitaryUnitData.CompanyData:
	return ArmyCombatSystem.create_company(
		id, Enums.CompanyUnitType.PEASANT_LEVY, -1, source_province_id,
	)


# -- Daily Military Processing Tests --------------------------------------------

func test_process_military_daily_empty() -> void:
	var r: Dictionary = DayOrchestrator._process_military_daily(
		[], [], [], [], DiceEngine.new(), [],
	)
	assert_eq(r["movement_results"].size(), 0)
	assert_eq(r["siege_results"].size(), 0)
	assert_eq(r["tether_results"].size(), 0)
	assert_eq(r["order_results"]["total_delivered"], 0)
	assert_eq(r["deprivation_results"].size(), 0)
	assert_eq(r["recovery_results"].size(), 0)


func test_army_movement_ticks() -> void:
	var army: Dictionary = _make_army_state(true, 3)
	var results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	assert_eq(results.size(), 1)


func test_army_movement_skips_stationary() -> void:
	var army: Dictionary = _make_army_state(false, 0)
	var results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	assert_eq(results.size(), 0)


func test_order_tick_resets_and_delivers() -> void:
	var os: Dictionary = _make_order_state()
	os["orders_used"] = 5
	var order: Dictionary = OrderSystem.create_scout_order(10, 5)
	OrderSystem.issue_order(os, order, false, 1)

	var r: Dictionary = DayOrchestrator._process_order_ticks([os])
	# Daily reset should have cleared orders_used
	assert_eq(os["orders_used"], 0)
	# The scout order had 1 day delivery, should be delivered
	assert_eq(r["total_delivered"], 1)


func test_order_tick_multiple_commanders() -> void:
	var os1: Dictionary = _make_order_state()
	var os2: Dictionary = OrderSystem.create_order_state(2, Enums.MilitaryRank.CHUI)

	var order1: Dictionary = OrderSystem.create_march_order(10, 20)
	OrderSystem.issue_order(os1, order1, false, 1)

	var order2: Dictionary = OrderSystem.create_scout_order(11, 5)
	OrderSystem.issue_order(os2, order2, true)

	var r: Dictionary = DayOrchestrator._process_order_ticks([os1, os2])
	# os1: march with 1 day delay → delivered after tick
	# os2: instant scout → already delivered, shows up in pending processing
	assert_true(r["total_delivered"] >= 1)


# -- Seasonal Military Processing Tests -----------------------------------------

func test_army_upkeep_calculates_costs() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.PEASANT_LEVY),
		_make_company_dict(2, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [], {})
	assert_true(r["total_rice_cost"] > 0.0)
	assert_eq(r["company_count"], 2)


func test_army_upkeep_empty_companies() -> void:
	var r: Dictionary = DayOrchestrator._process_army_upkeep([], [], {})
	assert_almost_eq(r["total_rice_cost"], 0.0, 0.001)
	assert_eq(r["company_count"], 0)


func test_army_upkeep_ronin_koku_cost() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.RONIN),
	]
	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [], {})
	assert_true(r["total_koku_cost"] > 0.0)


func test_army_upkeep_garrison_koku_cost() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.GARRISON),
	]
	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [], {})
	assert_true(r["total_koku_cost"] > 0.0)


# -- Military Promotion Wiring Tests --------------------------------------------

func test_promotion_finds_no_vacancies_when_all_filled() -> void:
	var companies: Array[Dictionary] = [
		{"company_id": 1, "commander_id": 10, "unit_type": Enums.CompanyUnitType.BUSHI_RETAINER},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_military_promotions(
		companies, {},
	)
	assert_eq(results.size(), 0)


func test_promotion_detects_vacancy() -> void:
	var companies: Array[Dictionary] = [
		{"company_id": 1, "commander_id": -1, "unit_type": Enums.CompanyUnitType.BUSHI_RETAINER},
	]
	# No eligible candidates available
	var results: Array[Dictionary] = DayOrchestrator._process_military_promotions(
		companies, {},
	)
	assert_eq(results.size(), 0)


# -- Integration: advance_day parameter count -----------------------------------

func test_advance_day_accepts_military_params() -> void:
	assert_true(DayOrchestrator.has_method("advance_day"))


func test_military_daily_returns_all_keys() -> void:
	var r: Dictionary = DayOrchestrator._process_military_daily(
		[], [], [], [], DiceEngine.new(), [], [],
	)
	assert_true(r.has("movement_results"))
	assert_true(r.has("siege_results"))
	assert_true(r.has("tether_results"))
	assert_true(r.has("order_results"))
	assert_true(r.has("deprivation_results"))
	assert_true(r.has("recovery_results"))


# -- Military Effect Post-Processing Tests --------------------------------------

func _make_settlement(
	id: int,
	province_id: int,
	pop: int = 10,
	military: int = 2,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.population_pu = pop
	s.military_pu = military
	return s


func test_levy_pu_effect_consumes_pu() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(applied, [s])
	assert_eq(r["type"], "levy_pu_consumed")
	assert_eq(r["pu_consumed"], 1)
	assert_eq(s.military_pu, 2)
	assert_eq(s.population_pu, 9)


func test_levy_pu_effect_no_province() -> void:
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": -1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(applied, [])
	assert_true(r.is_empty())


func test_battle_pu_reconciliation_effect() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var settlements: Dictionary = {1: [s]}
	var applied: Dictionary = {
		"effects": {
			"requires_battle_resolution": true,
			"victor_companies": [
				{"company_id": 1, "starting_health": 153, "current_health": 100, "source_province_id": 1},
			],
			"loser_companies": [
				{"company_id": 2, "starting_health": 153, "current_health": 50, "source_province_id": 1},
			],
		},
	}
	var r: Dictionary = DayOrchestrator._apply_battle_pu_reconciliation(
		applied, settlements,
	)
	assert_eq(r["type"], "battle_pu_reconciliation")
	assert_true(r.has("casualties"))
	assert_true(r.has("recovery"))


func test_battle_pu_reconciliation_no_companies() -> void:
	var applied: Dictionary = {
		"effects": {"requires_battle_resolution": true},
	}
	var r: Dictionary = DayOrchestrator._apply_battle_pu_reconciliation(applied, {})
	assert_true(r.is_empty())


func test_process_military_effects_scans_results() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var applied_list: Array = [
		{
			"character_id": 5,
			"target_province_id": 1,
			"effects": {"requires_levy_pu": true},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_military_effects(
		applied_list, [s], {}, [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "levy_pu_consumed")


func test_build_settlements_by_province() -> void:
	var s1: SettlementData = _make_settlement(1, 10)
	var s2: SettlementData = _make_settlement(2, 10)
	var s3: SettlementData = _make_settlement(3, 20)
	var result: Dictionary = DayOrchestrator._build_settlements_by_province(
		[s1, s2, s3],
	)
	assert_eq(result[10].size(), 2)
	assert_eq(result[20].size(), 1)


# -- Iron Upkeep Dict Tests -----------------------------------------------------

func test_iron_upkeep_dict_supplied() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var iron_state: Dictionary = {}
	var r: Dictionary = ArmyUpkeepSystem.process_iron_upkeep_dict(
		companies, iron_state, 10.0,
	)
	assert_true(r["supplied"])
	assert_eq(r["degraded_companies"].size(), 0)


func test_iron_upkeep_dict_not_supplied() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var iron_state: Dictionary = {}
	var r: Dictionary = ArmyUpkeepSystem.process_iron_upkeep_dict(
		companies, iron_state, 0.0,
	)
	assert_false(r["supplied"])
	assert_eq(r["degraded_companies"].size(), 1)
	assert_eq(iron_state[1], 1)


func test_iron_upkeep_dict_increments_state() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var iron_state: Dictionary = {1: 1}
	ArmyUpkeepSystem.process_iron_upkeep_dict(companies, iron_state, 0.0)
	assert_eq(iron_state[1], 2)


func test_iron_upkeep_dict_resets_on_supply() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var iron_state: Dictionary = {1: 3}
	ArmyUpkeepSystem.process_iron_upkeep_dict(companies, iron_state, 10.0)
	assert_eq(iron_state[1], 0)


# -- Battle Flow Integration Tests ----------------------------------------------

func _make_battle_company_state(
	id: int,
	unit_type: int = Enums.CompanyUnitType.BUSHI_RETAINER,
	source_province_id: int = 1,
) -> Dictionary:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		id, unit_type, -1, source_province_id,
	)
	return ArmyCombatSystem.make_battle_company(c, 1, 0, "attacker")


func test_extract_pu_data_attacker_wins() -> void:
	var result: Dictionary = {
		"victor": "attacker",
		"attacker_states": [_make_battle_company_state(1)],
		"defender_states": [_make_battle_company_state(2, Enums.CompanyUnitType.PEASANT_LEVY, 2)],
	}
	# Simulate some damage
	result["attacker_states"][0]["current_health"] = 100
	result["defender_states"][0]["current_health"] = 30
	var pu_data: Dictionary = ArmyCombatSystem.extract_pu_reconciliation_data(result)
	assert_eq(pu_data["victor_companies"].size(), 1)
	assert_eq(pu_data["loser_companies"].size(), 1)
	assert_eq(pu_data["victor_companies"][0]["source_province_id"], 1)
	assert_eq(pu_data["loser_companies"][0]["source_province_id"], 2)


func test_extract_pu_data_draw() -> void:
	var result: Dictionary = {
		"victor": "draw",
		"attacker_states": [_make_battle_company_state(1)],
		"defender_states": [_make_battle_company_state(2)],
	}
	var pu_data: Dictionary = ArmyCombatSystem.extract_pu_reconciliation_data(result)
	assert_eq(pu_data["victor_companies"].size(), 0)
	assert_eq(pu_data["loser_companies"].size(), 2)


func test_extract_pu_data_preserves_health() -> void:
	var result: Dictionary = {
		"victor": "attacker",
		"attacker_states": [_make_battle_company_state(1)],
		"defender_states": [],
	}
	result["attacker_states"][0]["current_health"] = 80
	var pu_data: Dictionary = ArmyCombatSystem.extract_pu_reconciliation_data(result)
	assert_eq(pu_data["victor_companies"][0]["current_health"], 80)
	assert_eq(pu_data["victor_companies"][0]["starting_health"], 153)


func test_resolve_and_reconcile_battle() -> void:
	var dice: DiceEngine = DiceEngine.new(42)
	var attacker: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.BUSHI_RETAINER, -1, 1,
	)
	var defender: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		2, Enums.CompanyUnitType.PEASANT_LEVY, -1, 2,
	)
	var atk_states: Array[Dictionary] = [
		ArmyCombatSystem.make_battle_company(attacker, 1, 0, "attacker"),
	]
	var def_states: Array[Dictionary] = [
		ArmyCombatSystem.make_battle_company(defender, 1, 0, "defender"),
	]
	var s1: SettlementData = _make_settlement(10, 1, 10, 3)
	var s2: SettlementData = _make_settlement(20, 2, 10, 3)

	var r: Dictionary = DayOrchestrator.resolve_and_reconcile_battle(
		atk_states, def_states, Enums.BattleTerrainType.PLAINS,
		dice, [s1, s2],
	)
	assert_true(r.has("victor"))
	assert_true(r.has("reconciliation"))
	assert_true(r.has("rout"))
	assert_true(r["reconciliation"].has("casualties"))


func test_is_cavalry_public() -> void:
	assert_true(ArmyCombatSystem.is_cavalry(Enums.CompanyUnitType.LIGHT_CAVALRY))
	assert_false(ArmyCombatSystem.is_cavalry(Enums.CompanyUnitType.BUSHI_RETAINER))


# -- Rout Dissolution Wiring Tests -----------------------------------------------

func test_build_dissolution_companies_distributes_pursuit() -> void:
	var loser_states: Array[Dictionary] = [
		{"current_health": 100, "is_destroyed": false, "company": _make_company_data(1, 1)},
		{"current_health": 50, "is_destroyed": false, "company": _make_company_data(2, 2)},
	]
	var result: Array[Dictionary] = DayOrchestrator._build_dissolution_companies(
		loser_states, 30,
	)
	assert_eq(result.size(), 2)
	assert_eq(result[0]["current_health"], 70)
	assert_eq(result[1]["current_health"], 50)


func test_build_dissolution_companies_skips_destroyed() -> void:
	var loser_states: Array[Dictionary] = [
		{"current_health": 0, "is_destroyed": true, "company": _make_company_data(1, 1)},
		{"current_health": 80, "is_destroyed": false, "company": _make_company_data(2, 2)},
	]
	var result: Array[Dictionary] = DayOrchestrator._build_dissolution_companies(
		loser_states, 20,
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["current_health"], 60)


func test_build_dissolution_companies_preserves_source_province() -> void:
	var loser_states: Array[Dictionary] = [
		{"current_health": 50, "is_destroyed": false, "company": _make_company_data(1, 5)},
	]
	var result: Array[Dictionary] = DayOrchestrator._build_dissolution_companies(
		loser_states, 0,
	)
	assert_eq(result[0]["source_province_id"], 5)


func test_resolve_battle_includes_dissolution_when_dissolved() -> void:
	var dice: DiceEngine = DiceEngine.new(99)
	var strong: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.BUSHI_RETAINER, -1, 1,
	)
	var weak: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		2, Enums.CompanyUnitType.PEASANT_LEVY, -1, 2,
	)
	weak.health = 10
	weak.morale = 1
	var atk_states: Array[Dictionary] = [
		ArmyCombatSystem.make_battle_company(strong, 1, 0, "attacker"),
	]
	var def_states: Array[Dictionary] = [
		ArmyCombatSystem.make_battle_company(weak, 1, 0, "defender"),
	]
	var s1: SettlementData = _make_settlement(10, 1, 10, 3)
	var s2: SettlementData = _make_settlement(20, 2, 10, 3)

	var r: Dictionary = DayOrchestrator.resolve_and_reconcile_battle(
		atk_states, def_states, Enums.BattleTerrainType.PLAINS,
		dice, [s1, s2],
	)
	if r["rout"].get("dissolved", false):
		assert_true(r.has("dissolution"))
		assert_true(r["dissolution"].has("total_returned_pu"))


# -- Rice Upkeep Deduction Tests -------------------------------------------------

func _make_clan(name: String, province_ids: Array[int]) -> ClanData:
	var c: ClanData = ClanData.new()
	c.clan_name = name
	c.province_ids = province_ids
	c.arms_stockpile = 10.0
	return c


func test_rice_upkeep_deducts_from_settlements() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.PEASANT_LEVY),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.rice_stockpile = 5.0
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_true(r["rice_deducted"] > 0.0)
	assert_true(s.rice_stockpile < 5.0)


func test_rice_upkeep_caps_at_available_stockpile() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.PEASANT_LEVY),
		_make_company_dict(2, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_company_dict(3, Enums.CompanyUnitType.BUSHI_RETAINER),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.rice_stockpile = 0.1
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_almost_eq(s.rice_stockpile, 0.0, 0.001)
	assert_almost_eq(r["rice_deducted"], 0.1, 0.001)


func test_rice_upkeep_no_clan_no_deduction() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.PEASANT_LEVY),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.rice_stockpile = 5.0

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], {})
	assert_almost_eq(r["rice_deducted"], 0.0, 0.001)
	assert_almost_eq(s.rice_stockpile, 5.0, 0.001)


# -- Koku Upkeep Deduction Tests -------------------------------------------------

func test_koku_upkeep_deducts_for_garrison() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.GARRISON),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.koku_stockpile = 5.0
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_true(r["koku_deducted"] > 0.0)
	assert_true(s.koku_stockpile < 5.0)
	assert_almost_eq(r["koku_deducted"], ArmyUpkeepSystem.GARRISON_KOKU_PER_PU_PER_SEASON, 0.001)


func test_koku_upkeep_deducts_for_ronin() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.RONIN),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.koku_stockpile = 5.0
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	var expected_koku: float = ArmyUpkeepSystem.RONIN_UPKEEP_KOKU_PER_MONTH * 3.0
	assert_almost_eq(r["koku_deducted"], expected_koku, 0.001)
	assert_almost_eq(s.koku_stockpile, 5.0 - expected_koku, 0.001)


func test_koku_upkeep_zero_for_non_koku_units() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.PEASANT_LEVY),
		_make_company_dict(2, Enums.CompanyUnitType.BUSHI_RETAINER),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.koku_stockpile = 5.0
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_almost_eq(r["koku_deducted"], 0.0, 0.001)
	assert_almost_eq(s.koku_stockpile, 5.0, 0.001)


func test_koku_upkeep_caps_at_available() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.RONIN),
		_make_company_dict(2, Enums.CompanyUnitType.RONIN),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.koku_stockpile = 0.5
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_almost_eq(s.koku_stockpile, 0.0, 0.001)
	assert_almost_eq(r["koku_deducted"], 0.5, 0.001)


func test_koku_upkeep_no_clan_no_deduction() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.GARRISON),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.koku_stockpile = 5.0

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], {})
	assert_almost_eq(r["koku_deducted"], 0.0, 0.001)
	assert_almost_eq(s.koku_stockpile, 5.0, 0.001)


func test_koku_upkeep_multiple_settlements_spread() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.RONIN),
	]
	var s1: SettlementData = _make_settlement(10, 1, 10, 3)
	s1.koku_stockpile = 0.5
	var s2: SettlementData = _make_settlement(11, 1, 10, 3)
	s2.koku_stockpile = 3.0
	var clan: ClanData = _make_clan("Crab", [1])
	var clans: Dictionary = {"Crab": clan}

	var expected_koku: float = ArmyUpkeepSystem.RONIN_UPKEEP_KOKU_PER_MONTH * 3.0
	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s1, s2], clans)
	assert_almost_eq(r["koku_deducted"], expected_koku, 0.001)
	assert_almost_eq(s1.koku_stockpile, 0.0, 0.001)
	assert_almost_eq(s2.koku_stockpile, 3.0 - (expected_koku - 0.5), 0.001)


# -- Field Deprivation Wiring Tests -----------------------------------------------

func _make_tether(army_id: int, company_ids: Array) -> Dictionary:
	return {
		"army_id": army_id,
		"company_ids": company_ids,
		"rice_deprivation_tick": 0,
		"arms_deprivation_tick": 0,
	}


func test_field_deprivation_no_tethers() -> void:
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation([], [])
	assert_eq(results.size(), 0)


func test_field_deprivation_skips_zero_ticks() -> void:
	var tether: Dictionary = _make_tether(1, [1, 2])
	var tether_result: Dictionary = {
		"rice_deprivation_tick": 0,
		"arms_deprivation_tick": 0,
	}
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation(
		[tether], [tether_result],
	)
	assert_eq(results.size(), 0)


func test_field_deprivation_applies_rice_effects() -> void:
	var tether: Dictionary = _make_tether(1, [10, 20])
	var tether_result: Dictionary = {
		"rice_deprivation_tick": 3,
		"arms_deprivation_tick": 0,
	}
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation(
		[tether], [tether_result],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["army_id"], 1)
	assert_eq(results[0]["rice_deprivation_tick"], 3)
	assert_eq(results[0]["company_effects"].size(), 2)
	var eff: Dictionary = results[0]["company_effects"][0]
	assert_eq(eff["company_id"], 10)
	assert_true(eff["rice_effect"].has("morale"))
	assert_true(eff["rice_effect"]["morale"] < 0)


func test_field_deprivation_applies_arms_effects() -> void:
	var tether: Dictionary = _make_tether(1, [10])
	var tether_result: Dictionary = {
		"rice_deprivation_tick": 0,
		"arms_deprivation_tick": 2,
	}
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation(
		[tether], [tether_result],
	)
	assert_eq(results.size(), 1)
	var eff: Dictionary = results[0]["company_effects"][0]
	assert_true(eff["arms_effect"].has("attack"))
	assert_true(eff["arms_effect"]["attack"] < 0)


func test_field_deprivation_both_rice_and_arms() -> void:
	var tether: Dictionary = _make_tether(1, [10])
	var tether_result: Dictionary = {
		"rice_deprivation_tick": 2,
		"arms_deprivation_tick": 3,
	}
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation(
		[tether], [tether_result],
	)
	assert_eq(results.size(), 1)
	var eff: Dictionary = results[0]["company_effects"][0]
	assert_false(eff["rice_effect"].is_empty())
	assert_false(eff["arms_effect"].is_empty())


func test_field_deprivation_tick_1_warning_only() -> void:
	var tether: Dictionary = _make_tether(1, [10])
	var tether_result: Dictionary = {
		"rice_deprivation_tick": 1,
		"arms_deprivation_tick": 1,
	}
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation(
		[tether], [tether_result],
	)
	assert_eq(results.size(), 1)
	var eff: Dictionary = results[0]["company_effects"][0]
	assert_eq(eff["rice_effect"]["morale"], 0)
	assert_eq(eff["rice_effect"]["health"], 0)
	assert_eq(eff["arms_effect"]["attack"], 0)
	assert_eq(eff["arms_effect"]["defense"], 0)


func test_field_deprivation_multiple_tethers() -> void:
	var t1: Dictionary = _make_tether(1, [10])
	var t2: Dictionary = _make_tether(2, [20, 30])
	var tr1: Dictionary = {"rice_deprivation_tick": 2, "arms_deprivation_tick": 0}
	var tr2: Dictionary = {"rice_deprivation_tick": 0, "arms_deprivation_tick": 4}
	var results: Array[Dictionary] = DayOrchestrator._process_field_deprivation(
		[t1, t2], [tr1, tr2],
	)
	assert_eq(results.size(), 2)
	assert_eq(results[0]["army_id"], 1)
	assert_eq(results[1]["army_id"], 2)
	assert_eq(results[1]["company_effects"].size(), 2)


# -- Tether Companies Fix Tests ---------------------------------------------------

func test_build_companies_by_id() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(10, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_company_dict(20, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var result: Dictionary = DayOrchestrator._build_companies_by_id(companies)
	assert_eq(result.size(), 2)
	assert_true(result.has(10))
	assert_true(result.has(20))
	assert_eq(result[10]["unit_type"], Enums.CompanyUnitType.BUSHI_RETAINER)


func test_build_companies_by_id_skips_invalid() -> void:
	var companies: Array[Dictionary] = [
		{"unit_type": 0},
	]
	var result: Dictionary = DayOrchestrator._build_companies_by_id(companies)
	assert_eq(result.size(), 0)


func test_escort_defense_reads_dict() -> void:
	var companies_by_id: Dictionary = {
		5: {"defense": 7},
	}
	var tether: Dictionary = {
		"node_states": {
			0: {"escort_company_id": 5, "escort_returning": false},
		},
	}
	var defense: int = SupplyTetherSystem.get_escort_defense(tether, 0, companies_by_id)
	assert_eq(defense, 7)


func test_escort_defense_reads_company_data() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		5, Enums.CompanyUnitType.BUSHI_RETAINER, -1, 1,
	)
	var companies_by_id: Dictionary = {5: c}
	var tether: Dictionary = {
		"node_states": {
			0: {"escort_company_id": 5, "escort_returning": false},
		},
	}
	var defense: int = SupplyTetherSystem.get_escort_defense(tether, 0, companies_by_id)
	assert_eq(defense, c.defense)


func test_escort_defense_returns_zero_when_no_escort() -> void:
	var tether: Dictionary = {
		"node_states": {
			0: {"escort_company_id": -1, "escort_returning": false},
		},
	}
	var defense: int = SupplyTetherSystem.get_escort_defense(tether, 0, {})
	assert_eq(defense, 0)


# -- Army Recovery Wiring Tests ---------------------------------------------------

func _make_army(army_id: int, is_moving: bool = false) -> Dictionary:
	return {"army_id": army_id, "is_moving": is_moving}


func _make_army_company(
	company_id: int,
	army_id: int,
	unit_type: int = Enums.CompanyUnitType.BUSHI_RETAINER,
	current_health: int = 100,
	current_morale: int = 10,
) -> Dictionary:
	return {
		"company_id": company_id,
		"army_id": army_id,
		"unit_type": unit_type,
		"current_health": current_health,
		"current_morale": current_morale,
		"clan_name": "Crab",
	}


func test_recovery_stationary_damaged_army() -> void:
	var army: Dictionary = _make_army(1, false)
	var company: Dictionary = _make_army_company(10, 1, Enums.CompanyUnitType.BUSHI_RETAINER, 100, 10)
	var results: Array[Dictionary] = DayOrchestrator._process_army_recovery(
		[army], {}, [company],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["army_id"], 1)
	var cr: Dictionary = results[0]["company_recoveries"][0]
	assert_eq(cr["company_id"], 10)
	assert_eq(cr["health_recovery"], ArmyUpkeepSystem.RECOVERY_HEALTH_PER_TICK)
	assert_eq(cr["morale_recovery"], ArmyUpkeepSystem.RECOVERY_MORALE_PER_TICK)


func test_recovery_skips_moving_army() -> void:
	var army: Dictionary = _make_army(1, true)
	var company: Dictionary = _make_army_company(10, 1, Enums.CompanyUnitType.BUSHI_RETAINER, 100, 10)
	var results: Array[Dictionary] = DayOrchestrator._process_army_recovery(
		[army], {}, [company],
	)
	assert_eq(results.size(), 0)


func test_recovery_caps_at_max_health() -> void:
	var base: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.BUSHI_RETAINER]
	var max_health: int = base["health"]
	var army: Dictionary = _make_army(1, false)
	var company: Dictionary = _make_army_company(10, 1, Enums.CompanyUnitType.BUSHI_RETAINER, max_health, base["morale"])
	var results: Array[Dictionary] = DayOrchestrator._process_army_recovery(
		[army], {}, [company],
	)
	assert_eq(results.size(), 0)


func test_recovery_no_companies_no_result() -> void:
	var army: Dictionary = _make_army(1, false)
	var results: Array[Dictionary] = DayOrchestrator._process_army_recovery(
		[army], {}, [],
	)
	assert_eq(results.size(), 0)


func test_recovery_broken_tether_no_supply() -> void:
	var army: Dictionary = _make_army(1, false)
	var company: Dictionary = _make_army_company(10, 1, Enums.CompanyUnitType.BUSHI_RETAINER, 100, 10)
	var tether_by_army: Dictionary = {
		1: {
			"overall_state": SupplyTetherSystem.TetherState.BROKEN,
			"arms_deprivation_tick": 0,
		},
	}
	var results: Array[Dictionary] = DayOrchestrator._process_army_recovery(
		[army], tether_by_army, [company],
	)
	assert_eq(results.size(), 0)


func test_recovery_arms_tier_when_supplied_and_deprived() -> void:
	var army: Dictionary = _make_army(1, false)
	var company: Dictionary = _make_army_company(10, 1, Enums.CompanyUnitType.BUSHI_RETAINER, 100, 10)
	var tether_by_army: Dictionary = {
		1: {
			"overall_state": SupplyTetherSystem.TetherState.SOLID,
			"arms_deprivation_tick": 3,
		},
	}
	var results: Array[Dictionary] = DayOrchestrator._process_army_recovery(
		[army], tether_by_army, [company],
	)
	assert_eq(results.size(), 1)
	var cr: Dictionary = results[0]["company_recoveries"][0]
	assert_true(cr["arms_tier_recovered"])


# -- Helper Extraction Tests ------------------------------------------------------

func test_build_tether_result_by_army() -> void:
	var tethers: Array[Dictionary] = [
		{"army_id": 1}, {"army_id": 2},
	]
	var results: Array[Dictionary] = [
		{"overall_state": 0, "rice_deprivation_tick": 3},
		{"overall_state": 2, "rice_deprivation_tick": 0},
	]
	var mapping: Dictionary = DayOrchestrator._build_tether_result_by_army(
		tethers, results,
	)
	assert_eq(mapping.size(), 2)
	assert_eq(mapping[1]["rice_deprivation_tick"], 3)
	assert_eq(mapping[2]["overall_state"], 2)


func test_build_tether_result_by_army_skips_invalid() -> void:
	var tethers: Array[Dictionary] = [{"army_id": -1}]
	var results: Array[Dictionary] = [{"overall_state": 0}]
	var mapping: Dictionary = DayOrchestrator._build_tether_result_by_army(
		tethers, results,
	)
	assert_eq(mapping.size(), 0)


# -- Military Event Topic Tests --------------------------------------------------

func test_generate_battle_topic_from_movement() -> void:
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "arrived_province_id": 5},
		],
		"siege_results": [],
	}
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [100]

	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, [], active_topics, next_id, 10,
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "battle_outcome")
	assert_eq(topics[0].category, TopicData.Category.MILITARY)
	assert_true(topics[0].momentum > 0.0)
	assert_eq(next_id[0], 101)
	assert_eq(active_topics.size(), 1)


func test_generate_battle_topic_skips_no_trigger() -> void:
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": false, "arrived_province_id": 5},
		],
		"siege_results": [],
	}
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [100]

	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, [], active_topics, next_id, 10,
	)
	assert_eq(topics.size(), 0)


func test_generate_heavy_casualties_topic() -> void:
	var military_daily: Dictionary = {
		"movement_results": [],
		"siege_results": [],
	}
	var effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {
				"total_pu_lost": 2.5,
				"pu_lost_by_province": {1: 1.5, 2: 1.0},
			},
		},
	]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [200]

	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, effects, active_topics, next_id, 15,
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].variant, "heavy_casualties")
	assert_eq(topics[0].provinces_affected.size(), 2)
	assert_eq(next_id[0], 201)


func test_generate_casualties_topic_skipped_for_small_loss() -> void:
	var military_daily: Dictionary = {
		"movement_results": [],
		"siege_results": [],
	}
	var effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {"total_pu_lost": 0.2},
		},
	]
	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, effects, [], [300], 15,
	)
	assert_eq(topics.size(), 0)


func test_generate_siege_event_topic() -> void:
	var military_daily: Dictionary = {
		"movement_results": [],
		"siege_results": [
			{
				"siege_id": 1,
				"events": [
					{"event_type": "supply_raid"},
				],
			},
		],
	}
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [400]

	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, [], active_topics, next_id, 20,
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_type, "siege")
	assert_eq(topics[0].variant, "supply_raid")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_4)
	assert_eq(next_id[0], 401)


func test_generate_siege_event_skips_empty_type() -> void:
	var military_daily: Dictionary = {
		"movement_results": [],
		"siege_results": [
			{
				"siege_id": 1,
				"events": [{"event_type": ""}],
			},
		],
	}
	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, [], [], [500], 20,
	)
	assert_eq(topics.size(), 0)


func test_generate_multiple_topics_in_one_day() -> void:
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "arrived_province_id": 3},
		],
		"siege_results": [
			{
				"siege_id": 2,
				"events": [{"event_type": "treachery"}],
			},
		],
	}
	var effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {"total_pu_lost": 1.0, "pu_lost_by_province": {3: 1.0}},
		},
	]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [600]

	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, effects, active_topics, next_id, 25,
	)
	assert_eq(topics.size(), 3)
	assert_eq(next_id[0], 603)
	assert_eq(active_topics.size(), 3)


func test_battle_topic_has_province_affected() -> void:
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "arrived_province_id": 7},
		],
		"siege_results": [],
	}
	var topics: Array[TopicData] = DayOrchestrator._generate_military_event_topics(
		military_daily, [], [], [700], 30,
	)
	assert_eq(topics[0].provinces_affected.size(), 1)
	assert_eq(topics[0].provinces_affected[0], 7)


# -- War System Wiring Tests -----------------------------------------------------

func _make_war(
	war_id: int = 1,
	clan_a: String = "Crab",
	clan_b: String = "Crane",
) -> WarData:
	return WarSystem.declare_war(
		war_id, clan_a, clan_b,
		WarData.AuthorityLevel.FAMILY_WAR, 10, 20, 100,
	)


func _make_character(
	id: int,
	clan: String = "Crab",
) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	return c


func test_war_score_shift_on_battle_trigger() -> void:
	var war: WarData = _make_war()
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "arrived_province_id": 5},
		],
	}
	var wars: Array[WarData] = [war]
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], wars, companies,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "minor_battle")
	assert_eq(war.war_score_a, 53)
	assert_eq(war.war_score_b, 47)


func test_war_score_no_shift_without_battle() -> void:
	var war: WarData = _make_war()
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": false},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results.size(), 0)
	assert_eq(war.war_score_a, 50)


func test_war_score_no_shift_without_wars() -> void:
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true},
		],
	}
	var wars: Array[WarData] = []
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], wars, [],
	)
	assert_eq(results.size(), 0)


func test_war_seasonal_attrition() -> void:
	var war: WarData = _make_war()
	var chars: Array[L5RCharacterData] = []
	DayOrchestrator._process_war_seasonal([war], chars)
	assert_eq(war.seasons_active, 1)
	assert_eq(war.war_score_a, 51)


func test_war_seasonal_disposition_penalty() -> void:
	var war: WarData = _make_war()
	war.seasons_active = 2
	var crab_char: L5RCharacterData = _make_character(1, "Crab")
	var crane_char: L5RCharacterData = _make_character(2, "Crane")
	crab_char.disposition_values[2] = 0
	crane_char.disposition_values[1] = 0
	var chars: Array[L5RCharacterData] = [crab_char, crane_char]
	DayOrchestrator._process_war_seasonal([war], chars)
	var penalty: int = WarSystem.get_active_war_disposition_penalty(
		war.seasons_active,
	)
	assert_true(crab_char.disposition_values[2] < 0)
	assert_true(crane_char.disposition_values[1] < 0)


func test_war_seasonal_skips_same_side() -> void:
	var war: WarData = _make_war()
	war.seasons_active = 2
	var crab1: L5RCharacterData = _make_character(1, "Crab")
	var crab2: L5RCharacterData = _make_character(2, "Crab")
	crab1.disposition_values[2] = 10
	crab2.disposition_values[1] = 10
	var chars: Array[L5RCharacterData] = [crab1, crab2]
	DayOrchestrator._process_war_seasonal([war], chars)
	assert_eq(crab1.disposition_values[2], 10)
	assert_eq(crab2.disposition_values[1], 10)


func test_war_seasonal_skips_uninvolved_clans() -> void:
	var war: WarData = _make_war(1, "Crab", "Crane")
	war.seasons_active = 2
	var lion: L5RCharacterData = _make_character(1, "Lion")
	var crab: L5RCharacterData = _make_character(2, "Crab")
	lion.disposition_values[2] = 10
	crab.disposition_values[1] = 10
	var chars: Array[L5RCharacterData] = [lion, crab]
	DayOrchestrator._process_war_seasonal([war], chars)
	assert_eq(lion.disposition_values[2], 10)
	assert_eq(crab.disposition_values[1], 10)


func test_get_army_clan() -> void:
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
		{"army_id": 2, "clan_name": "Crane"},
	]
	assert_eq(DayOrchestrator._get_army_clan(1, companies), "Crab")
	assert_eq(DayOrchestrator._get_army_clan(2, companies), "Crane")
	assert_eq(DayOrchestrator._get_army_clan(99, companies), "")


# -- Deeper War Score Event Tests ------------------------------------------------

func test_classify_battle_size_minor() -> void:
	assert_eq(DayOrchestrator._classify_battle_size(1), "minor_battle")
	assert_eq(DayOrchestrator._classify_battle_size(3), "minor_battle")


func test_classify_battle_size_major() -> void:
	assert_eq(DayOrchestrator._classify_battle_size(4), "major_battle")
	assert_eq(DayOrchestrator._classify_battle_size(7), "major_battle")


func test_classify_battle_size_decisive() -> void:
	assert_eq(DayOrchestrator._classify_battle_size(8), "decisive_battle")
	assert_eq(DayOrchestrator._classify_battle_size(20), "decisive_battle")


func test_rank_to_death_event_rikugunshokan() -> void:
	assert_eq(
		DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.RIKUGUNSHOKAN),
		"rikugunshokan_killed",
	)


func test_rank_to_death_event_taisa() -> void:
	assert_eq(
		DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.TAISA),
		"taisa_shireikan_killed",
	)


func test_rank_to_death_event_shireikan() -> void:
	assert_eq(
		DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.SHIREIKAN),
		"taisa_shireikan_killed",
	)


func test_rank_to_death_event_chui() -> void:
	assert_eq(
		DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.CHUI),
		"gunso_chui_killed",
	)


func test_rank_to_death_event_gunso() -> void:
	assert_eq(
		DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.GUNSO),
		"gunso_chui_killed",
	)


func test_rank_to_death_event_none_returns_empty() -> void:
	assert_eq(DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.NONE), "")
	assert_eq(DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.HOHEI), "")
	assert_eq(DayOrchestrator._rank_to_death_event(Enums.MilitaryRank.NIKUTAI), "")


func test_battle_size_affects_war_score() -> void:
	var war: WarData = _make_war()
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "company_count": 5},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], companies,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "major_battle")
	assert_eq(results[0]["shift"], 8)


func test_decisive_battle_from_company_count() -> void:
	var war: WarData = _make_war()
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "company_count": 10},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], companies,
	)
	assert_eq(results[0]["event"], "decisive_battle")
	assert_eq(results[0]["shift"], 15)


func test_commander_death_shifts_enemy_score() -> void:
	var war: WarData = _make_war()
	var dead_cmd: L5RCharacterData = _make_character(10, "Crab")
	dead_cmd.military_rank = Enums.MilitaryRank.TAISA
	var military_daily: Dictionary = {
		"battle_results": [
			{
				"attacker_states": [
					{
						"commander_dead": true,
						"commander": dead_cmd,
						"side": "attacker",
					},
				],
				"defender_states": [],
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "taisa_shireikan_killed")
	assert_eq(results[0]["dead_commander_id"], 10)
	assert_eq(results[0]["clan"], "Crane")


func test_commander_death_rikugunshokan() -> void:
	var war: WarData = _make_war()
	var score_b_before: int = war.war_score_b
	var dead_cmd: L5RCharacterData = _make_character(10, "Crab")
	dead_cmd.military_rank = Enums.MilitaryRank.RIKUGUNSHOKAN
	var military_daily: Dictionary = {
		"battle_results": [
			{
				"attacker_states": [
					{"commander_dead": true, "commander": dead_cmd, "side": "attacker"},
				],
				"defender_states": [],
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results[0]["event"], "rikugunshokan_killed")
	assert_eq(results[0]["shift"], 10)
	assert_eq(war.war_score_b, score_b_before + 10)


func test_commander_death_low_rank_ignored() -> void:
	var war: WarData = _make_war()
	var dead_cmd: L5RCharacterData = _make_character(10, "Crab")
	dead_cmd.military_rank = Enums.MilitaryRank.HOHEI
	var military_daily: Dictionary = {
		"battle_results": [
			{
				"attacker_states": [
					{"commander_dead": true, "commander": dead_cmd, "side": "attacker"},
				],
				"defender_states": [],
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results.size(), 0)


func test_siege_attacker_victory_war_score() -> void:
	var war: WarData = _make_war()
	var score_a_before: int = war.war_score_a
	var military_daily: Dictionary = {
		"siege_results": [
			{
				"resolved": "attacker_victory",
				"attacker_clan": "Crab",
				"defender_clan": "Crane",
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "siege_won_attacker")
	assert_eq(results[0]["shift"], 12)
	assert_eq(war.war_score_a, score_a_before + 12)


func test_siege_defender_victory_war_score() -> void:
	var war: WarData = _make_war()
	var score_b_before: int = war.war_score_b
	var military_daily: Dictionary = {
		"siege_results": [
			{
				"resolved": "defender_victory",
				"attacker_clan": "Crab",
				"defender_clan": "Crane",
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "siege_won_defender")
	assert_eq(results[0]["shift"], 8)
	assert_eq(war.war_score_b, score_b_before + 8)


func test_siege_unresolved_no_score() -> void:
	var war: WarData = _make_war()
	var military_daily: Dictionary = {
		"siege_results": [
			{
				"resolved": "",
				"attacker_clan": "Crab",
				"defender_clan": "Crane",
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], [],
	)
	assert_eq(results.size(), 0)


func test_tether_broken_cuts_supply_for_enemy() -> void:
	var war: WarData = _make_war()
	var score_b_before: int = war.war_score_b
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var military_daily: Dictionary = {
		"tether_results": [
			{"army_id": 1, "overall_state": 2},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], companies,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "supply_line_cut")
	assert_eq(results[0]["clan"], "Crane")
	assert_eq(results[0]["shift"], 3)
	assert_eq(war.war_score_b, score_b_before + 3)


func test_tether_threatened_no_score() -> void:
	var war: WarData = _make_war()
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var military_daily: Dictionary = {
		"tether_results": [
			{"army_id": 1, "overall_state": 1},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], companies,
	)
	assert_eq(results.size(), 0)


func test_heavy_casualties_upgrade_to_decisive() -> void:
	var war: WarData = _make_war()
	var score_a_before: int = war.war_score_a
	var military_effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {"total_pu_lost": 6.0},
			"victor_clan": "Crab",
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		{}, military_effects, [war], [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "decisive_battle_upgrade")
	assert_eq(results[0]["clan"], "Crab")
	assert_eq(results[0]["shift"], 15)
	assert_eq(war.war_score_a, score_a_before + 15)


func test_moderate_casualties_upgrade_to_major() -> void:
	var war: WarData = _make_war()
	var military_effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {"total_pu_lost": 3.5},
			"victor_clan": "Crane",
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		{}, military_effects, [war], [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "major_battle_upgrade")
	assert_eq(results[0]["clan"], "Crane")
	assert_eq(results[0]["shift"], 8)


func test_small_casualties_no_upgrade() -> void:
	var war: WarData = _make_war()
	var military_effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {"total_pu_lost": 2.0},
			"victor_clan": "Crab",
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		{}, military_effects, [war], [],
	)
	assert_eq(results.size(), 0)


func test_casualties_upgrade_skipped_without_victor_clan() -> void:
	var war: WarData = _make_war()
	var military_effects: Array[Dictionary] = [
		{
			"type": "battle_pu_reconciliation",
			"casualties": {"total_pu_lost": 6.0},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		{}, military_effects, [war], [],
	)
	assert_eq(results.size(), 0)


func test_multiple_events_combine() -> void:
	var war: WarData = _make_war()
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var dead_cmd: L5RCharacterData = _make_character(10, "Crane")
	dead_cmd.military_rank = Enums.MilitaryRank.CHUI
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "company_count": 2},
		],
		"battle_results": [
			{
				"attacker_states": [],
				"defender_states": [
					{"commander_dead": true, "commander": dead_cmd, "side": "defender"},
				],
			},
		],
		"siege_results": [
			{
				"resolved": "attacker_victory",
				"attacker_clan": "Crab",
				"defender_clan": "Crane",
			},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], companies,
	)
	assert_true(results.size() >= 3)


func test_inactive_war_skipped_for_battle_scores() -> void:
	var war: WarData = _make_war()
	war.is_active = false
	var companies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab"},
	]
	var military_daily: Dictionary = {
		"movement_results": [
			{"army_id": 1, "battle_triggered": true, "company_count": 5},
		],
	}
	var results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], [war], companies,
	)
	assert_eq(results.size(), 0)


# -- War Declaration Wiring Tests ------------------------------------------------

func test_war_declaration_creates_war() -> void:
	var active_wars: Array[WarData] = []
	var next_wid: Array[int] = [5]
	var applied: Array = [
		{
			"effects": {
				"requires_war_creation": true,
				"declaring_clan": "Crab",
				"target_clan": "Crane",
				"authority_level": WarData.AuthorityLevel.FAMILY_WAR,
				"declaring_lord_id": 10,
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_declarations(
		applied, active_wars, 100, next_wid,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "war_declared")
	assert_eq(results[0]["declaring_clan"], "Crab")
	assert_eq(results[0]["target_clan"], "Crane")
	assert_eq(active_wars.size(), 1)
	assert_eq(active_wars[0].clan_a, "Crab")
	assert_eq(active_wars[0].clan_b, "Crane")
	assert_eq(active_wars[0].ic_day_started, 100)
	assert_eq(active_wars[0].war_id, 5)
	assert_eq(next_wid[0], 6)


func test_war_declaration_skips_duplicate() -> void:
	var existing_war: WarData = _make_war(1, "Crab", "Crane")
	var active_wars: Array[WarData] = [existing_war]
	var applied: Array = [
		{
			"effects": {
				"requires_war_creation": true,
				"declaring_clan": "Crab",
				"target_clan": "Crane",
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_declarations(
		applied, active_wars, 100,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "war_already_active")
	assert_eq(active_wars.size(), 1)


func test_war_declaration_skips_self_war() -> void:
	var active_wars: Array[WarData] = []
	var applied: Array = [
		{
			"effects": {
				"requires_war_creation": true,
				"declaring_clan": "Crab",
				"target_clan": "Crab",
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_declarations(
		applied, active_wars, 100,
	)
	assert_eq(results.size(), 0)
	assert_eq(active_wars.size(), 0)


func test_war_declaration_skips_empty_clans() -> void:
	var active_wars: Array[WarData] = []
	var applied: Array = [
		{
			"effects": {
				"requires_war_creation": true,
				"declaring_clan": "Crab",
				"target_clan": "",
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_declarations(
		applied, active_wars, 100,
	)
	assert_eq(results.size(), 0)


func test_war_declaration_no_effect_flag() -> void:
	var wars: Array[WarData] = []
	var applied: Array = [
		{
			"effects": {
				"effect": "readiness_assessed",
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_declarations(
		applied, wars, 100,
	)
	assert_eq(results.size(), 0)


# -- War Trigger Pipeline (Metadata Population) --------------------------------

func test_declare_war_metadata_populated_in_phase_3() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Crab"
	ctx.is_lord = true
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_clan_id = "Crane"
	need.target_intent = "EXPAND_TERRITORY"

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)

	var declare_war_option: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			declare_war_option = opt
			break

	assert_not_null(declare_war_option, "DECLARE_WAR should be in AT_OWN_HOLDINGS options")
	if declare_war_option != null:
		assert_eq(declare_war_option.metadata.get("standing_objective", ""), "EXPAND_TERRITORY")
		assert_eq(declare_war_option.metadata.get("target_clan", ""), "Crane")
		assert_eq(declare_war_option.target_province_id, 10)


func test_negotiate_surrender_metadata_populated_in_phase_3() -> void:
	var war_ns: WarData = _make_war(1, "Crab", "Crane")
	var war_dict: Dictionary = WarSystem.to_context_dict(war_ns)

	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Crab"
	ctx.is_lord = true
	ctx.active_wars = [war_dict]

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_PEACE"
	need.target_clan_id = "Crane"

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)

	var surrender_option: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "NEGOTIATE_SURRENDER":
			surrender_option = opt
			break

	assert_not_null(surrender_option, "NEGOTIATE_SURRENDER should be in AT_OWN_HOLDINGS options")
	if surrender_option != null:
		assert_eq(surrender_option.metadata.get("target_clan", ""), "Crane")
		assert_not_null(surrender_option.metadata.get("war_ref"))


func test_metadata_carried_through_execute_action() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 100

	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "DECLARE_WAR"
	action.ap_cost = 2
	action.metadata = {"standing_objective": "EXPAND_TERRITORY", "target_clan": "Crane"}

	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 1
	c.action_points = 4

	var result: Dictionary = NPCDecisionEngine.execute_action(action, c, ctx)
	assert_true(result.has("metadata"))
	assert_eq(result["metadata"]["standing_objective"], "EXPAND_TERRITORY")
	assert_eq(result["metadata"]["target_clan"], "Crane")


func test_expand_territory_produces_war_check_with_intent() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Crab"
	ctx.province_statuses = [_make_ps_wt(10, "Crane", 1)]

	var objective: Dictionary = {"type": "EXPAND_TERRITORY", "target_clan_id": "Crane"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "EXPAND_TERRITORY")
	assert_eq(need.target_province_id, 10)


# -- Personality-Driven Tier in Metadata ------------------------------------------

func test_yu_lord_gets_total_war_tier_in_metadata() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	ctx.bushido_virtue = Enums.BushidoVirtue.YU

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_clan_id = "Crane"
	need.target_intent = "EXPAND_TERRITORY"

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var declare_war_option: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			declare_war_option = opt
			break

	assert_not_null(declare_war_option)
	if declare_war_option != null:
		assert_eq(
			declare_war_option.metadata.get("intended_tier"),
			WarJustification.MilitaryTier.TOTAL_WAR,
		)
		assert_eq(
			declare_war_option.metadata.get("authority_level"),
			WarData.AuthorityLevel.CLAN_WAR,
		)
		assert_eq(declare_war_option.metadata.get("primary_virtue"), "Yu")


func test_jin_lord_gets_raid_tier_in_metadata() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Crane"
	ctx.is_lord = true
	ctx.bushido_virtue = Enums.BushidoVirtue.JIN

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_clan_id = "Lion"
	need.target_intent = "EXPAND_TERRITORY"

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var declare_war_option: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			declare_war_option = opt
			break

	assert_not_null(declare_war_option)
	if declare_war_option != null:
		assert_eq(
			declare_war_option.metadata.get("intended_tier"),
			WarJustification.MilitaryTier.RAID,
		)
		assert_eq(declare_war_option.metadata.get("primary_virtue"), "Jin")


func test_ketsui_lord_gets_formal_war_for_dominance() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Unicorn"
	ctx.is_lord = true
	ctx.shourido_virtue = Enums.ShouridoVirtue.KETSUI

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_clan_id = "Crane"
	need.target_intent = "MILITARY_DOMINANCE"

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var declare_war_option: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			declare_war_option = opt
			break

	assert_not_null(declare_war_option)
	if declare_war_option != null:
		assert_eq(
			declare_war_option.metadata.get("intended_tier"),
			WarJustification.MilitaryTier.FORMAL_WAR,
		)


# -- Weakness Conditions (s53.1) -------------------------------------------------

func test_garrison_at_minimum_with_zero_pu() -> void:
	assert_true(WarJustification.is_garrison_at_minimum(0, 0))


func test_garrison_at_minimum_exactly_5_percent() -> void:
	assert_true(WarJustification.is_garrison_at_minimum(1, 20))


func test_garrison_above_minimum() -> void:
	assert_false(WarJustification.is_garrison_at_minimum(5, 20))


func test_garrison_below_minimum() -> void:
	assert_true(WarJustification.is_garrison_at_minimum(0, 20))


func test_evaluate_province_weakness_all_conditions_met() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.garrison_pu = 0
	ps.total_settlement_pu = 20
	ps.has_field_army_nearby = false
	ps.has_alliance_protection = false
	var result: Dictionary = WarJustification.evaluate_province_weakness(ps)
	assert_true(result["is_weak"])
	assert_true(result["garrison_at_minimum"])
	assert_true(result["no_field_army_nearby"])
	assert_true(result["no_alliance_protection"])


func test_evaluate_province_weakness_garrison_too_high() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.garrison_pu = 5
	ps.total_settlement_pu = 20
	var result: Dictionary = WarJustification.evaluate_province_weakness(ps)
	assert_false(result["is_weak"])
	assert_false(result["garrison_at_minimum"])


func test_evaluate_province_weakness_field_army_present() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.garrison_pu = 0
	ps.total_settlement_pu = 20
	ps.has_field_army_nearby = true
	var result: Dictionary = WarJustification.evaluate_province_weakness(ps)
	assert_false(result["is_weak"])
	assert_false(result["no_field_army_nearby"])


func test_evaluate_province_weakness_alliance_protection() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.garrison_pu = 0
	ps.total_settlement_pu = 20
	ps.has_alliance_protection = true
	var result: Dictionary = WarJustification.evaluate_province_weakness(ps)
	assert_false(result["is_weak"])
	assert_false(result["no_alliance_protection"])


func test_find_weak_skips_own_clan() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.clan = "Lion"
	var own_ps := _make_ps_wt(10, "Lion", 2)
	ctx.province_statuses = [own_ps]
	var result: int = ObjectiveDecomposer._find_weak_neighbor_province(ctx)
	assert_eq(result, -1)


func test_find_weak_finds_enemy_province() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.clan = "Lion"
	var enemy_ps := _make_ps_wt(10, "Crane", 2)
	ctx.province_statuses = [enemy_ps]
	var result: int = ObjectiveDecomposer._find_weak_neighbor_province(ctx)
	assert_eq(result, 10)


func test_find_weak_rejects_strong_enemy() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.clan = "Lion"
	ctx.province_statuses = [_make_strong_ps(10, "Crane")]
	var result: int = ObjectiveDecomposer._find_weak_neighbor_province(ctx)
	assert_eq(result, -1)


# -- Formal War Weakness in Metadata (s53.1) ------------------------------------

func test_declare_war_metadata_includes_weakness_conditions() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	var target_ps := NPCDataStructures.ProvinceStatus.new()
	target_ps.province_id = 10
	target_ps.clan = "Crane"
	target_ps.garrison_pu = 0
	target_ps.total_settlement_pu = 20
	target_ps.has_field_army_nearby = false
	target_ps.has_alliance_protection = false
	ctx.province_statuses = [target_ps]
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_intent = "EXPAND_TERRITORY"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var dw: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			dw = opt
			break
	assert_not_null(dw)
	if dw != null:
		assert_true(dw.metadata.get("target_garrison_at_minimum", false))
		assert_true(dw.metadata.get("no_field_army_nearby", false))
		assert_true(dw.metadata.get("no_alliance_protection", false))
		assert_eq(dw.metadata.get("defender_observable_pu", -1.0), 0.0)


func test_declare_war_metadata_strong_province_not_weak() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	var target_ps := _make_strong_ps(10, "Crane")
	ctx.province_statuses = [target_ps]
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_intent = "EXPAND_TERRITORY"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var dw: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			dw = opt
			break
	assert_not_null(dw)
	if dw != null:
		assert_false(dw.metadata.get("target_garrison_at_minimum", true))
		assert_eq(dw.metadata.get("defender_observable_pu", -1.0), 5.0)


func test_declare_war_metadata_attacker_pu_from_levy_and_garrison() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	ctx.available_levy_pu = 10.0
	var own_ps := _make_strong_ps(5, "Lion")
	own_ps.garrison_pu = 8
	var target_ps := NPCDataStructures.ProvinceStatus.new()
	target_ps.province_id = 10
	target_ps.clan = "Crane"
	target_ps.garrison_pu = 2
	target_ps.total_settlement_pu = 20
	ctx.province_statuses = [own_ps, target_ps]
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_intent = "EXPAND_TERRITORY"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var dw: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			dw = opt
			break
	assert_not_null(dw)
	if dw != null:
		assert_eq(dw.metadata.get("attacker_pu", 0.0), 18.0)
		assert_eq(dw.metadata.get("defender_observable_pu", 0.0), 2.0)


func test_declare_war_metadata_no_target_province_status_omits_weakness() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 99
	need.target_clan_id = "Crane"
	need.target_intent = "EXPAND_TERRITORY"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var dw: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			dw = opt
			break
	assert_not_null(dw)
	if dw != null:
		assert_false(dw.metadata.has("target_garrison_at_minimum"))
		assert_false(dw.metadata.has("defender_observable_pu"))


func test_declare_war_metadata_field_army_blocks_weakness() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	var target_ps := NPCDataStructures.ProvinceStatus.new()
	target_ps.province_id = 10
	target_ps.clan = "Crane"
	target_ps.garrison_pu = 0
	target_ps.total_settlement_pu = 20
	target_ps.has_field_army_nearby = true
	ctx.province_statuses = [target_ps]
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_intent = "EXPAND_TERRITORY"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var dw: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			dw = opt
			break
	assert_not_null(dw)
	if dw != null:
		assert_false(dw.metadata.get("no_field_army_nearby", true))


func test_declare_war_metadata_multiple_own_provinces_sum_garrison() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.clan = "Lion"
	ctx.is_lord = true
	ctx.available_levy_pu = 5.0
	var own_a := _make_strong_ps(1, "Lion")
	own_a.garrison_pu = 3
	var own_b := _make_strong_ps(2, "Lion")
	own_b.garrison_pu = 7
	var target_ps := NPCDataStructures.ProvinceStatus.new()
	target_ps.province_id = 10
	target_ps.clan = "Crane"
	target_ps.garrison_pu = 1
	target_ps.total_settlement_pu = 20
	ctx.province_statuses = [own_a, own_b, target_ps]
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INITIATE_WAR_CHECK"
	need.target_province_id = 10
	need.target_intent = "EXPAND_TERRITORY"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need,
	)
	var dw: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DECLARE_WAR":
			dw = opt
			break
	assert_not_null(dw)
	if dw != null:
		assert_eq(dw.metadata.get("attacker_pu", 0.0), 15.0)


# -- ProvinceStatus.clan Wiring --------------------------------------------------

func test_build_province_statuses_from_data() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crab"
	pd.stability = 60.0
	pd.active_crisis_id = -1
	pd.active_insurgency_id = -1

	var result: Array = NPCDecisionEngine.build_province_statuses_from_data([pd])
	assert_eq(result.size(), 1)
	var ps: NPCDataStructures.ProvinceStatus = result[0]
	assert_eq(ps.province_id, 10)
	assert_eq(ps.clan, "Crab")
	assert_eq(ps.stability, 60.0)
	assert_eq(ps.confidence, 2)


func test_build_province_statuses_sums_garrison() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Lion"

	var s1 := SettlementData.new()
	s1.province_id = 10
	s1.garrison_pu = 3
	var s2 := SettlementData.new()
	s2.province_id = 10
	s2.garrison_pu = 2

	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [s1, s2],
	)
	assert_eq(result[0].garrison_pu, 5)


func test_build_context_auto_builds_province_statuses() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.status = 6.0

	var pd := ProvinceData.new()
	pd.province_id = 20
	pd.clan = "Crane"
	pd.stability = 45.0

	var ws: Dictionary = {
		"is_lord": true,
		"province_data": [pd],
		"settlements": [],
	}

	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		c, ws,
	)
	assert_eq(ctx.province_statuses.size(), 1)
	var ps: NPCDataStructures.ProvinceStatus = ctx.province_statuses[0]
	assert_eq(ps.clan, "Crane")
	assert_eq(ps.province_id, 20)
	assert_eq(ps.stability, 45.0)


func test_build_context_preserves_existing_province_statuses() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.status = 6.0

	var existing_ps := NPCDataStructures.ProvinceStatus.new()
	existing_ps.province_id = 30
	existing_ps.clan = "Dragon"

	var ws: Dictionary = {
		"is_lord": true,
		"province_statuses": [existing_ps],
		"province_data": [],
	}

	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		c, ws,
	)
	assert_eq(ctx.province_statuses.size(), 1)
	assert_eq(ctx.province_statuses[0].province_id, 30)
	assert_eq(ctx.province_statuses[0].clan, "Dragon")


# -- Field Army Detection Wiring -------------------------------------------------

func test_build_province_statuses_detects_enemy_army() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 100, "Lion", 10)
	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [], [army],
	)
	assert_true(result[0].has_field_army_nearby)


func test_build_province_statuses_own_clan_army_not_enemy() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 100, "Crane", 10)
	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [], [army],
	)
	assert_false(result[0].has_field_army_nearby)


func test_build_province_statuses_no_army_no_field() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [], [],
	)
	assert_false(result[0].has_field_army_nearby)


func test_build_province_statuses_army_at_different_province() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 200, "Lion", 20)
	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [], [army],
	)
	assert_false(result[0].has_field_army_nearby)


func test_build_province_statuses_army_no_province_id_ignored() -> void:
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 100, "Lion")
	var result: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[pd], [], [army],
	)
	assert_false(result[0].has_field_army_nearby)


func test_build_context_threads_active_armies() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.status = 6.0
	var pd := ProvinceData.new()
	pd.province_id = 10
	pd.clan = "Crane"
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 100, "Lion", 10)
	var ws: Dictionary = {
		"is_lord": true,
		"province_data": [pd],
		"settlements": [],
		"active_armies": [army],
	}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(c, ws)
	assert_eq(ctx.province_statuses.size(), 1)
	assert_true(ctx.province_statuses[0].has_field_army_nearby)


func test_army_state_factory_includes_province_id() -> void:
	var state: Dictionary = ArmyMovementSystem.create_army_state(1, 50, "Crab", 7)
	assert_eq(state["province_id"], 7)


func test_army_state_factory_default_province_id() -> void:
	var state: Dictionary = ArmyMovementSystem.create_army_state(1, 50, "Crab")
	assert_eq(state["province_id"], -1)


# -- Standing Objective War Check Paths ------------------------------------------

func test_seek_vengeance_produces_war_check() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.province_statuses = [_make_ps_wt(20, "Crane", 2)]

	var objective: Dictionary = {
		"type": "SEEK_VENGEANCE",
		"target_npc_id": -1,
		"target_clan_id": "Crane",
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "SEEK_VENGEANCE")
	assert_eq(need.target_clan_id, "Crane")
	assert_eq(need.target_province_id, 20)


func test_seek_vengeance_no_war_check_without_weak_province() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.province_statuses = [_make_strong_ps(20, "Crane")]

	var objective: Dictionary = {
		"type": "SEEK_VENGEANCE",
		"target_npc_id": -1,
		"target_clan_id": "Crane",
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_ne(need.need_type, "INITIATE_WAR_CHECK")


func test_seek_vengeance_no_war_check_same_clan() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.province_statuses = [_make_ps_wt(20, "Lion", 2)]

	var objective: Dictionary = {
		"type": "SEEK_VENGEANCE",
		"target_npc_id": -1,
		"target_clan_id": "Lion",
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_ne(need.need_type, "INITIATE_WAR_CHECK")


func test_undermine_clan_produces_war_check() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Scorpion"
	ctx.province_statuses = [_make_ps_wt(30, "Crane", 2)]

	var objective: Dictionary = {
		"type": "UNDERMINE_CLAN",
		"target_clan_id": "Crane",
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "UNDERMINE_CLAN")
	assert_eq(need.target_clan_id, "Crane")


func test_undermine_clan_falls_through_when_no_weak_target() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Scorpion"
	ctx.province_statuses = [_make_strong_ps(30, "Crane")]

	var objective: Dictionary = {
		"type": "UNDERMINE_CLAN",
		"target_clan_id": "Crane",
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "ACQUIRE_LEVERAGE")


func test_prevent_shortage_produces_war_check_when_starving() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Crab"
	ctx.resource_stockpiles = {"rice": 0.5, "rice_consumption": 1.0}
	ctx.province_statuses = [_make_ps_wt(15, "Crane", 2)]

	var objective: Dictionary = {"type": "PREVENT_SHORTAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "PREVENT_SHORTAGE")


func test_prevent_shortage_acquires_resource_when_no_weak_neighbor() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Crab"
	ctx.resource_stockpiles = {"rice": 0.5, "rice_consumption": 1.0}
	ctx.province_statuses = []

	var objective: Dictionary = {"type": "PREVENT_SHORTAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE")


func test_build_strongest_force_produces_war_check_when_trained() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.unit_training_counts = {0: 0, 1: 0, 2: 0}
	ctx.can_sustain_iron_upkeep = true
	ctx.available_levy_pu = 0.0
	ctx.resource_stockpiles = {"rice": 10.0, "military_upkeep": 1.0}
	ctx.province_statuses = [_make_ps_wt(25, "Crane", 2)]

	var objective: Dictionary = {"type": "BUILD_STRONGEST_FORCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "BUILD_STRONGEST_FORCE")


func test_advance_glory_produces_war_check_for_bushi_lord() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.school_type = Enums.SchoolType.BUSHI
	ctx.province_statuses = [_make_ps_wt(25, "Crane", 2)]

	var objective: Dictionary = {"type": "ADVANCE_GLORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "ADVANCE_GLORY")


func test_advance_glory_no_war_check_for_courtier() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Crane"
	ctx.school_type = Enums.SchoolType.COURTIER
	ctx.province_statuses = [_make_ps_wt(25, "Lion", 2)]

	var objective: Dictionary = {"type": "ADVANCE_GLORY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_ne(need.need_type, "INITIATE_WAR_CHECK")


func test_advance_family_produces_war_check() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.province_statuses = [_make_ps_wt(25, "Crane", 2)]

	var objective: Dictionary = {"type": "ADVANCE_FAMILY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "ADVANCE_FAMILY")


func test_advance_family_defends_first_on_crisis() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	var crisis_ps := _make_ps_wt(5, "Lion", 2)
	crisis_ps.active_crisis_id = 1
	ctx.province_statuses = [crisis_ps, _make_ps_wt(25, "Crane", 2)]

	var objective: Dictionary = {"type": "ADVANCE_FAMILY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "DEFEND_PROVINCE")


func test_honor_ancestors_produces_war_check_with_active_wars() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.active_wars = [{"war_id": 1}]
	ctx.province_statuses = [_make_ps_wt(25, "Crane", 2)]

	var objective: Dictionary = {"type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "INITIATE_WAR_CHECK")
	assert_eq(need.target_intent, "HONOR_ANCESTORS")


func test_honor_ancestors_trains_without_active_wars() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.is_lord = true
	ctx.clan = "Lion"
	ctx.active_wars = []
	ctx.escalating_conflicts = []
	ctx.province_statuses = [_make_ps_wt(25, "Crane", 2)]

	var objective: Dictionary = {"type": "HONOR_ANCESTORS"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx,
	)
	assert_eq(need.need_type, "TRAIN_SKILL")


func _make_ps_wt(
	prov_id: int, clan_name: String, confidence_val: int,
	stab: float = 40.0,
) -> NPCDataStructures.ProvinceStatus:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = prov_id
	ps.clan = clan_name
	ps.confidence = confidence_val
	ps.stability = stab
	return ps


func _make_strong_ps(
	prov_id: int, clan_name: String,
) -> NPCDataStructures.ProvinceStatus:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = prov_id
	ps.clan = clan_name
	ps.confidence = 2
	ps.garrison_pu = 5
	ps.total_settlement_pu = 20
	return ps


# -- Supply Status Check Wiring (s4.3.17 Phase 3) -----------------------------

func _make_supply_lord(
	id: int,
	clan: String = "Crab",
	virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c: L5RCharacterData = _make_character(id, clan)
	c.status = 6.0
	c.lord_id = -1
	c.bushido_virtue = virtue
	c.shourido_virtue = shourido
	return c


func _make_supply_settlement(
	id: int,
	province_id: int,
	rice: float = 50.0,
	farming: int = 10,
	mining: int = 5,
	town: int = 5,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.rice_stockpile = rice
	s.farming_pu = farming
	s.mining_pu = mining
	s.town_pu = town
	s.population_pu = farming + mining + town
	return s


func _make_supply_province(id: int, clan: String) -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = id
	p.clan = clan
	return p


func test_supply_status_check_skips_when_no_wars() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1)
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [], [], {}, [], {}, [],
	)
	assert_eq(results.size(), 0)


func test_supply_status_check_skips_non_lord() -> void:
	var c: L5RCharacterData = _make_character(1, "Crab")
	c.status = 2.0
	c.lord_id = 5
	var war: WarData = _make_war(1, "Crab", "Crane")
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[c], [war], [], {}, companies, {}, [],
	)
	assert_eq(results.size(), 0)


func test_supply_status_check_skips_lord_without_companies() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1)
	var war: WarData = _make_war(1, "Crab", "Crane")
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [], {}, [], {}, [],
	)
	assert_eq(results.size(), 0)


func test_supply_status_check_continue_when_all_clear() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1)
	var war: WarData = _make_war(1, "Crab", "Crane")
	var prov: ProvinceData = _make_supply_province(1, "Crab")
	var s: SettlementData = _make_supply_settlement(1, 1, 50.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = _make_clan("Crab", [1])
	var provinces: Dictionary = {1: prov}
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crab": clan}, [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)
	assert_eq(results[0]["lord_id"], 1)
	assert_eq(results[0]["clan"], "Crab")
	assert_false(results[0].has("peace_need"))
	assert_false(results[0].has("retreat"))


func test_supply_status_check_shortage_seeks_peace() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1, "Crab", Enums.BushidoVirtue.JIN)
	var war: WarData = _make_war(1, "Crab", "Crane")
	war.war_score_a = 40
	var prov: ProvinceData = _make_supply_province(1, "Crab")
	var s: SettlementData = _make_supply_settlement(1, 1, 15.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = _make_clan("Crab", [1])
	var provinces: Dictionary = {1: prov}
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crab": clan}, [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.SEEK_PEACE)
	assert_true(results[0]["peace_need"])


func test_supply_status_check_famine_immediate_peace() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1, "Crab", Enums.BushidoVirtue.JIN)
	var war: WarData = _make_war(1, "Crab", "Crane")
	var prov: ProvinceData = _make_supply_province(1, "Crab")
	var s: SettlementData = _make_supply_settlement(1, 1, 0.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = _make_clan("Crab", [1])
	var provinces: Dictionary = {1: prov}
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crab": clan}, [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE)
	assert_true(results[0]["peace_need"])
	assert_eq(results[0]["peace_urgency"], FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE)


func test_supply_status_check_broken_tether_retreat() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1)
	var war: WarData = _make_war(1, "Crab", "Crane")
	var prov: ProvinceData = _make_supply_province(1, "Crab")
	var s: SettlementData = _make_supply_settlement(1, 1, 50.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = _make_clan("Crab", [1])
	var provinces: Dictionary = {1: prov}
	var tethers: Array[Dictionary] = [{
		"army_id": 1,
		"overall_state": SupplyTetherSystem.TetherState.BROKEN,
		"seasons_cut": 2,
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crab": clan}, tethers,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.RETREAT)
	assert_true(results[0].has("retreat"))


func test_supply_status_check_broken_tether_restore_first() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1)
	var war: WarData = _make_war(1, "Crab", "Crane")
	var prov: ProvinceData = _make_supply_province(1, "Crab")
	var s: SettlementData = _make_supply_settlement(1, 1, 50.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = _make_clan("Crab", [1])
	var provinces: Dictionary = {1: prov}
	var tethers: Array[Dictionary] = [{
		"army_id": 1,
		"overall_state": SupplyTetherSystem.TetherState.BROKEN,
		"seasons_cut": 0,
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crab": clan}, tethers,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.RESTORE_TETHER)


func test_supply_status_check_war_score_from_correct_side() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1, "Crane")
	var war: WarData = _make_war(1, "Crab", "Crane")
	war.war_score_a = 30
	war.war_score_b = 70
	var prov: ProvinceData = _make_supply_province(1, "Crane")
	var s: SettlementData = _make_supply_settlement(1, 1, 15.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crane", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = ClanData.new()
	clan.clan_name = "Crane"
	clan.province_ids = [1]
	clan.arms_stockpile = 10.0
	var provinces: Dictionary = {1: prov}
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crane": clan}, [],
	)
	assert_eq(results.size(), 1)
	# Crane has war_score_b = 70, which is >= 65 (WINNING_THRESHOLD)
	# So despite shortage, decision should be PUSH_TO_FINISH
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.PUSH_TO_FINISH)


func test_supply_status_check_personality_ignores_shortage() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1, "Crab")
	lord.bushido_virtue = Enums.BushidoVirtue.YU
	var war: WarData = _make_war(1, "Crab", "Crane")
	war.war_score_a = 40
	var prov: ProvinceData = _make_supply_province(1, "Crab")
	var s: SettlementData = _make_supply_settlement(1, 1, 15.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Crab", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = _make_clan("Crab", [1])
	var provinces: Dictionary = {1: prov}
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Crab": clan}, [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["decision"], FeasibilityLedger.CampaignDecision.CONTINUE)
	assert_eq(results[0]["reason"], "personality_ignores_shortage")


func test_supply_status_check_uninvolved_clan_skipped() -> void:
	var lord: L5RCharacterData = _make_supply_lord(1, "Lion")
	var war: WarData = _make_war(1, "Crab", "Crane")
	var prov: ProvinceData = _make_supply_province(1, "Lion")
	var s: SettlementData = _make_supply_settlement(1, 1, 50.0, 10, 5, 5)
	var companies: Array[Dictionary] = [{"company_id": 1, "clan_name": "Lion", "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "army_id": 1}]
	var clan: ClanData = ClanData.new()
	clan.clan_name = "Lion"
	clan.province_ids = [1]
	clan.arms_stockpile = 10.0
	var provinces: Dictionary = {1: prov}
	var results: Array[Dictionary] = DayOrchestrator._process_supply_status_checks(
		[lord], [war], [s], provinces, companies, {"Lion": clan}, [],
	)
	assert_eq(results.size(), 0)


func test_supply_status_helper_get_character_virtue() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.YU
	assert_eq(DayOrchestrator._get_character_virtue(c), "Yu")

	var c2: L5RCharacterData = L5RCharacterData.new()
	c2.shourido_virtue = Enums.ShouridoVirtue.ISHI
	assert_eq(DayOrchestrator._get_character_virtue(c2), "Ishi")

	var c3: L5RCharacterData = L5RCharacterData.new()
	assert_eq(DayOrchestrator._get_character_virtue(c3), "")


func test_supply_status_helper_source_has_rice() -> void:
	var s1: SettlementData = _make_supply_settlement(1, 1, 20.0, 10, 5, 5)
	assert_true(DayOrchestrator._source_has_rice([s1]))
	var s2: SettlementData = _make_supply_settlement(2, 1, 5.0, 10, 5, 5)
	assert_false(DayOrchestrator._source_has_rice([s2]))


func test_supply_status_helper_worst_tether_state() -> void:
	var companies: Array[Dictionary] = [
		{"company_id": 1, "clan_name": "Crab", "army_id": 1},
		{"company_id": 2, "clan_name": "Crab", "army_id": 2},
	]
	var tethers: Array[Dictionary] = [
		{"army_id": 1, "overall_state": SupplyTetherSystem.TetherState.SOLID},
		{"army_id": 2, "overall_state": SupplyTetherSystem.TetherState.THREATENED},
	]
	assert_eq(
		DayOrchestrator._get_worst_tether_state("Crab", tethers, companies),
		SupplyTetherSystem.TetherState.THREATENED,
	)


func test_supply_status_helper_clan_settlements() -> void:
	var p1: ProvinceData = _make_supply_province(1, "Crab")
	var p2: ProvinceData = _make_supply_province(2, "Crane")
	var s1: SettlementData = _make_supply_settlement(10, 1)
	var s2: SettlementData = _make_supply_settlement(20, 2)
	var provinces: Dictionary = {1: p1, 2: p2}
	var result: Array[SettlementData] = DayOrchestrator._get_clan_settlements(
		"Crab", [s1, s2], provinces,
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0].settlement_id, 10)


# -- Ladder Side Effects Wiring ------------------------------------------------

func _make_applied_with_ladder(
	declaring_lord_id: int,
	declaring_clan: String,
	target_clan: String,
	side_effects: Dictionary,
) -> Dictionary:
	return {
		"effects": {
			"requires_war_creation": true,
			"declaring_clan": declaring_clan,
			"target_clan": target_clan,
			"declaring_lord_id": declaring_lord_id,
			"ladder_outcome": "demanded_tribute",
			"ladder_side_effects": side_effects,
		},
	}


func test_ladder_side_effects_skips_when_no_ladder() -> void:
	var applied: Array = [{"effects": {"requires_war_creation": true, "declaring_clan": "Crab"}}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_ladder_side_effects(
		applied, {}, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(results.size(), 0)


func test_ladder_side_effects_applies_glory_cost() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	lord.glory = 3.0
	var chars_by_id: Dictionary = {1: lord}
	var side: Dictionary = {"glory_cost": -0.3, "rung": FeasibilityLedger.LadderRung.RAID_NEIGHBOR}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(results.size(), 1)
	assert_almost_eq(lord.glory, 2.7, 0.01)
	assert_almost_eq(results[0]["glory_applied"], -0.3, 0.01)


func test_ladder_side_effects_applies_vassal_disposition() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var vassal: L5RCharacterData = _make_character(2, "Crab")
	vassal.lord_id = 1
	vassal.disposition_values[1] = 20
	var chars_by_id: Dictionary = {1: lord, 2: vassal}
	var side: Dictionary = {
		"disposition_cost": -5,
		"rung": FeasibilityLedger.LadderRung.DEMAND_TRIBUTE,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(vassal.disposition_values[1], 15)


func test_ladder_side_effects_vassal_disposition_not_applied_to_non_vassals() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var other: L5RCharacterData = _make_character(2, "Crab")
	other.lord_id = 99
	other.disposition_values[1] = 20
	var chars_by_id: Dictionary = {1: lord, 2: other}
	var side: Dictionary = {
		"disposition_cost": -5,
		"rung": FeasibilityLedger.LadderRung.DEMAND_TRIBUTE,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(other.disposition_values[1], 20)


func test_ladder_side_effects_clan_disposition_cost() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var target_char: L5RCharacterData = _make_character(2, "Crane")
	target_char.disposition_values[1] = 10
	var chars_by_id: Dictionary = {1: lord, 2: target_char}
	var side: Dictionary = {
		"clan_disposition_cost": -15,
		"raid_target_clan": "Crane",
		"rung": FeasibilityLedger.LadderRung.RAID_NEIGHBOR,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(target_char.disposition_values[1], -5)


func test_ladder_side_effects_other_clans_disposition_cost() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var lion: L5RCharacterData = _make_character(2, "Lion")
	lion.disposition_values[1] = 10
	var crane: L5RCharacterData = _make_character(3, "Crane")
	crane.disposition_values[1] = 10
	var chars_by_id: Dictionary = {1: lord, 2: lion, 3: crane}
	var side: Dictionary = {
		"other_disposition_cost": -5,
		"raid_target_clan": "Crane",
		"rung": FeasibilityLedger.LadderRung.RAID_NEIGHBOR,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	# Lion (other clan) gets the -5
	assert_eq(lion.disposition_values[1], 5)
	# Crane (target clan) is exempt from "other" cost
	assert_eq(crane.disposition_values[1], 10)


func test_ladder_side_effects_generates_topic() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var chars_by_id: Dictionary = {1: lord}
	var side: Dictionary = {
		"generates_topic": true,
		"topic_tier": 4,
		"rung": FeasibilityLedger.LadderRung.DEMAND_TRIBUTE,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].topic_id, 100)
	assert_eq(topics[0].tier, TopicData.Tier.TIER_4)
	assert_eq(topics[0].topic_type, "war_preparation")
	assert_eq(topics[0].clan_involved, "Crab")
	assert_eq(next_topic_id[0], 101)
	assert_eq(results[0]["topic_id"], 100)


func test_ladder_side_effects_tier_3_topic() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var chars_by_id: Dictionary = {1: lord}
	var side: Dictionary = {
		"generates_topic": true,
		"topic_tier": 3,
		"rung": FeasibilityLedger.LadderRung.RAID_NEIGHBOR,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [200]
	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], [], [1],
	)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].tier, TopicData.Tier.TIER_3)
	assert_almost_eq(topics[0].momentum, 26.0, 0.01)


func test_ladder_side_effects_creates_favor() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var chars_by_id: Dictionary = {1: lord}
	var side: Dictionary = {
		"creates_favor": true,
		"favor_tier": 2,
		"rung": FeasibilityLedger.LadderRung.REQUEST_ALLIED_AID,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var favors: Array = []
	var results: Array[Dictionary] = DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, favors, [], [1],
	)
	assert_eq(favors.size(), 1)
	assert_eq((favors[0] as FavorData).tier, FavorData.FavorTier.MODERATE)
	assert_eq((favors[0] as FavorData).debtor_id, 1)
	assert_eq(results[0]["favor_tier"], 2)


func test_ladder_side_effects_triggers_raid_war() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var chars_by_id: Dictionary = {1: lord}
	var side: Dictionary = {
		"triggers_war_status": true,
		"raid_target_clan": "Lion",
		"raid_target_province_id": 5,
		"rung": FeasibilityLedger.LadderRung.RAID_NEIGHBOR,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var active_wars: Array[WarData] = []
	var next_war_id: Array[int] = [10]
	var results: Array[Dictionary] = DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], active_wars, next_war_id,
	)
	assert_eq(active_wars.size(), 1)
	assert_eq(active_wars[0].clan_a, "Crab")
	assert_eq(active_wars[0].clan_b, "Lion")
	assert_eq(active_wars[0].authority_level, WarData.AuthorityLevel.PROVINCIAL_RAID)
	assert_eq(results[0]["raid_war_id"], 10)
	assert_eq(next_war_id[0], 11)


func test_ladder_side_effects_no_duplicate_raid_war() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	var chars_by_id: Dictionary = {1: lord}
	var side: Dictionary = {
		"triggers_war_status": true,
		"raid_target_clan": "Lion",
		"rung": FeasibilityLedger.LadderRung.RAID_NEIGHBOR,
	}
	var applied: Array = [_make_applied_with_ladder(1, "Crab", "Crane", side)]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var existing_war: WarData = _make_war(5, "Crab", "Lion")
	var active_wars: Array[WarData] = [existing_war]
	var next_war_id: Array[int] = [10]
	var results: Array[Dictionary] = DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, [], active_wars, next_war_id,
	)
	assert_eq(active_wars.size(), 1)
	assert_false(results[0].has("raid_war_id"))


func test_ladder_rung_name() -> void:
	assert_eq(
		DayOrchestrator._ladder_rung_name(FeasibilityLedger.LadderRung.DEMAND_TRIBUTE),
		"demand_tribute",
	)
	assert_eq(
		DayOrchestrator._ladder_rung_name(FeasibilityLedger.LadderRung.RAID_NEIGHBOR),
		"raid_neighbor",
	)
	assert_eq(
		DayOrchestrator._ladder_rung_name(FeasibilityLedger.LadderRung.REQUEST_ALLIED_AID),
		"allied_aid",
	)
	assert_eq(
		DayOrchestrator._ladder_rung_name(FeasibilityLedger.LadderRung.DESPERATION_OVERRIDE),
		"desperation",
	)
	assert_eq(DayOrchestrator._ladder_rung_name(-1), "unknown")


# -- Consume Supply Status Results ---------------------------------------------

func test_consume_supply_injects_peace_need_seek() -> void:
	var world_states: Dictionary = {}
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.SEEK_PEACE,
		"peace_need": true,
		"peace_urgency": FeasibilityLedger.CampaignDecision.SEEK_PEACE,
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, world_states, [], topics, next_topic_id, 1,
	)
	assert_true(world_states.has(1))
	var events: Array = world_states[1]["pending_events"]
	assert_eq(events.size(), 1)
	assert_eq(events[0]["need_type"], "SEEK_PEACE")
	assert_eq(events[0]["priority"], 2)
	assert_eq(events[0]["source"], "supply_status_check")


func test_consume_supply_injects_urgent_peace_priority_1() -> void:
	var world_states: Dictionary = {}
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.URGENT_PEACE,
		"peace_need": true,
		"peace_urgency": FeasibilityLedger.CampaignDecision.URGENT_PEACE,
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, world_states, [], topics, next_topic_id, 1,
	)
	var events: Array = world_states[1]["pending_events"]
	assert_eq(events[0]["priority"], 1)


func test_consume_supply_injects_immediate_peace_priority_1() -> void:
	var world_states: Dictionary = {}
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE,
		"peace_need": true,
		"peace_urgency": FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE,
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, world_states, [], topics, next_topic_id, 1,
	)
	var events: Array = world_states[1]["pending_events"]
	assert_eq(events[0]["priority"], 1)


func test_consume_supply_retreat_sets_army_flags() -> void:
	var active_armies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab", "is_active": true},
		{"army_id": 2, "clan_name": "Crane", "is_active": true},
	]
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.RETREAT,
		"retreat": {"found": true, "province_id": 5, "should_disband": false},
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, {}, active_armies, topics, next_topic_id, 1,
	)
	assert_true(active_armies[0].get("retreat_ordered", false))
	assert_eq(active_armies[0].get("retreat_target_province", -1), 5)
	assert_false(active_armies[1].has("retreat_ordered"))


func test_consume_supply_retreat_disband_generates_topic() -> void:
	var active_armies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab", "is_active": true},
	]
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.RETREAT,
		"retreat": {"found": false, "should_disband": true},
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, {}, active_armies, topics, next_topic_id, 1,
	)
	assert_true(active_armies[0].get("disband_ordered", false))
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].variant, "army_disbanded")
	assert_eq(topics[0].clan_involved, "Crab")
	assert_eq(next_topic_id[0], 101)


func test_consume_supply_continue_does_nothing() -> void:
	var world_states: Dictionary = {}
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.CONTINUE,
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, world_states, [], topics, next_topic_id, 1,
	)
	assert_false(world_states.has(1))
	assert_eq(topics.size(), 0)


func test_consume_supply_appends_to_existing_pending_events() -> void:
	var world_states: Dictionary = {1: {"pending_events": [{"need_type": "REST"}]}}
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.SEEK_PEACE,
		"peace_need": true,
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, world_states, [], topics, next_topic_id, 1,
	)
	var events: Array = world_states[1]["pending_events"]
	assert_eq(events.size(), 2)
	assert_eq(events[1]["need_type"], "SEEK_PEACE")


func test_consume_supply_retreat_skips_inactive_armies() -> void:
	var active_armies: Array[Dictionary] = [
		{"army_id": 1, "clan_name": "Crab", "is_active": false},
	]
	var results: Array[Dictionary] = [{
		"lord_id": 1,
		"clan": "Crab",
		"decision": FeasibilityLedger.CampaignDecision.RETREAT,
		"retreat": {"found": true, "province_id": 5, "should_disband": false},
	}]
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	DayOrchestrator._consume_supply_status_results(
		results, {}, active_armies, topics, next_topic_id, 1,
	)
	assert_false(active_armies[0].has("retreat_ordered"))


# -- Ladder Data Gaps: has_issued_demand -----------------------------------------

func test_has_issued_demand_true_when_demand_tribute_topic_exists() -> void:
	var c: L5RCharacterData = _make_character(1, "Crab")
	var topic: TopicData = TopicData.new()
	topic.topic_type = "war_preparation"
	topic.variant = "demand_tribute"
	topic.clan_involved = "Crab"
	var ws: Dictionary = {"active_topics": [topic]}
	assert_true(NPCDecisionEngine._has_issued_demand(c, ws))


func test_has_issued_demand_false_when_no_topics() -> void:
	var c: L5RCharacterData = _make_character(1, "Crab")
	var ws: Dictionary = {"active_topics": []}
	assert_false(NPCDecisionEngine._has_issued_demand(c, ws))


func test_has_issued_demand_false_for_different_clan() -> void:
	var c: L5RCharacterData = _make_character(1, "Crab")
	var topic: TopicData = TopicData.new()
	topic.topic_type = "war_preparation"
	topic.variant = "demand_tribute"
	topic.clan_involved = "Lion"
	var ws: Dictionary = {"active_topics": [topic]}
	assert_false(NPCDecisionEngine._has_issued_demand(c, ws))


func test_has_issued_demand_false_for_different_variant() -> void:
	var c: L5RCharacterData = _make_character(1, "Crab")
	var topic: TopicData = TopicData.new()
	topic.topic_type = "war_preparation"
	topic.variant = "allied_aid"
	topic.clan_involved = "Crab"
	var ws: Dictionary = {"active_topics": [topic]}
	assert_false(NPCDecisionEngine._has_issued_demand(c, ws))


func test_has_issued_demand_false_when_no_active_topics_key() -> void:
	var c: L5RCharacterData = _make_character(1, "Crab")
	assert_false(NPCDecisionEngine._has_issued_demand(c, {}))


# -- Ladder Data Gaps: contributing_ally_ids favor creation ----------------------

func test_ladder_favor_uses_real_ally_creditor_ids() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	lord.status = 6.0
	var ally1: L5RCharacterData = _make_character(10, "Crane")
	var ally2: L5RCharacterData = _make_character(20, "Lion")
	var chars_by_id: Dictionary = {1: lord, 10: ally1, 20: ally2}
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var favors: Array = []
	var wars: Array[WarData] = []
	var next_war_id: Array[int] = [1]

	var applied: Array[Dictionary] = [{
		"character_id": 1,
		"action_id": "DECLARE_WAR",
		"effects": {
			"ladder_side_effects": [{
				"creates_favor": true,
				"favor_tier": 3,
				"contributing_ally_ids": [10, 20],
			}],
		},
	}]

	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, favors, wars, next_war_id,
	)

	assert_eq(favors.size(), 2, "One favor per ally")
	var f0: FavorData = favors[0] as FavorData
	var f1: FavorData = favors[1] as FavorData
	assert_eq(f0.creditor_id, 10)
	assert_eq(f0.debtor_id, 1)
	assert_eq(f1.creditor_id, 20)
	assert_eq(f1.debtor_id, 1)


func test_ladder_favor_fallback_when_no_ally_ids() -> void:
	var lord: L5RCharacterData = _make_character(1, "Crab")
	lord.status = 6.0
	var chars_by_id: Dictionary = {1: lord}
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [100]
	var favors: Array = []
	var wars: Array[WarData] = []
	var next_war_id: Array[int] = [1]

	var applied: Array[Dictionary] = [{
		"character_id": 1,
		"action_id": "DECLARE_WAR",
		"effects": {
			"ladder_side_effects": [{
				"creates_favor": true,
				"favor_tier": 2,
				"contributing_ally_ids": [],
			}],
		},
	}]

	DayOrchestrator._process_ladder_side_effects(
		applied, chars_by_id, topics, next_topic_id, 1, favors, wars, next_war_id,
	)

	assert_eq(favors.size(), 1)
	var f: FavorData = favors[0] as FavorData
	assert_eq(f.creditor_id, -1, "Fallback creditor when no ally IDs")
	assert_eq(f.debtor_id, 1)


# -- Retreat flag consumption: initiate retreat march ----------------------------

func test_retreat_initiates_march_for_flagged_army() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	DayOrchestrator._initiate_retreat_march(army)
	assert_true(army["is_moving"])
	assert_eq(army["destination_sub_tile"], 5)
	assert_eq(army["days_remaining"], DayOrchestrator._RETREAT_DEFAULT_DAYS)


func test_retreat_skips_army_without_flag() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	DayOrchestrator._initiate_retreat_march(army)
	assert_false(army["is_moving"])


func test_retreat_skips_already_moving_army() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 2
	DayOrchestrator._initiate_retreat_march(army)
	assert_eq(army["days_remaining"], 2, "Should not reset travel time")


func test_retreat_skips_disband_ordered_army() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["disband_ordered"] = true
	army["retreat_target_province"] = 5
	DayOrchestrator._initiate_retreat_march(army)
	assert_false(army["is_moving"])


func test_retreat_skips_no_target_province() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	DayOrchestrator._initiate_retreat_march(army)
	assert_false(army["is_moving"])


func test_retreat_arrived_flag_set_on_arrival() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	assert_eq(results.size(), 1)
	assert_true(results[0].get("retreat_arrived", false))


func test_movement_processes_retreat_then_ticks() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	var results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	assert_eq(results.size(), 1, "Retreat initiated and immediately ticked")
	assert_true(army["is_moving"])
	assert_eq(army["days_remaining"], DayOrchestrator._RETREAT_DEFAULT_DAYS - 1)


# -- Retreat arrival cleanup -----------------------------------------------------

func test_retreat_arrival_clears_retreat_flags() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var movement_results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	var tethers: Array[Dictionary] = []
	var results: Array[Dictionary] = DayOrchestrator._process_retreat_arrivals(
		movement_results, [army], tethers,
	)
	assert_eq(results.size(), 1)
	assert_false(army.has("retreat_ordered"))
	assert_false(army.has("retreat_target_province"))


func test_retreat_arrival_detaches_tether() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var typed_path: Array[int] = [10, 20]
	var tether: Dictionary = SupplyTetherSystem.create_tether(1, 100, typed_path)
	var movement_results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	var results: Array[Dictionary] = DayOrchestrator._process_retreat_arrivals(
		movement_results, [army], [tether],
	)
	assert_eq(results.size(), 1)
	assert_true(results[0]["tether_detached"])
	assert_true(tether.get("detached", false))


func test_retreat_arrival_frees_escorts_from_tether() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var typed_path: Array[int] = [10, 20]
	var tether: Dictionary = SupplyTetherSystem.create_tether(1, 100, typed_path)
	SupplyTetherSystem.assign_escort(tether, 10, 201)
	var movement_results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	var results: Array[Dictionary] = DayOrchestrator._process_retreat_arrivals(
		movement_results, [army], [tether],
	)
	assert_eq(results[0]["freed_escort_ids"].size(), 1)
	assert_eq(results[0]["freed_escort_ids"][0], 201)


func test_retreat_arrival_skips_non_retreat() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var movement_results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	var results: Array[Dictionary] = DayOrchestrator._process_retreat_arrivals(
		movement_results, [army], [],
	)
	assert_eq(results.size(), 0)


func test_retreat_arrival_no_tether_still_cleans_flags() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var movement_results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	var results: Array[Dictionary] = DayOrchestrator._process_retreat_arrivals(
		movement_results, [army], [],
	)
	assert_eq(results.size(), 1)
	assert_false(results[0]["tether_detached"])
	assert_false(army.has("retreat_ordered"))


func test_retreat_arrival_in_military_daily() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var dice: DiceEngine = DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		[army] as Array[Dictionary],
		[] as Array[Dictionary],
		[] as Array[Dictionary],
		[] as Array[Dictionary],
		dice,
		[] as Array[SettlementData],
		[] as Array[Dictionary],
	)
	assert_true(result.has("retreat_arrival_results"))
	assert_eq(result["retreat_arrival_results"].size(), 1)
	assert_false(army.has("retreat_ordered"))


func test_retreat_arrival_skips_already_detached_tether() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["retreat_ordered"] = true
	army["retreat_target_province"] = 5
	army["is_moving"] = true
	army["days_remaining"] = 1
	army["path"] = [5] as Array[int]
	army["destination_sub_tile"] = 5
	var typed_path: Array[int] = [10, 20]
	var tether: Dictionary = SupplyTetherSystem.create_tether(1, 100, typed_path)
	tether["detached"] = true
	var movement_results: Array[Dictionary] = DayOrchestrator._process_army_movements([army])
	var results: Array[Dictionary] = DayOrchestrator._process_retreat_arrivals(
		movement_results, [army], [tether],
	)
	assert_eq(results.size(), 1)
	assert_false(results[0]["tether_detached"])


# -- Disband processing ---------------------------------------------------------

func _make_settlement_for_disband(province_id: int) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = province_id * 10
	s.province_id = province_id
	s.military_pu = 0
	s.population_pu = 10
	return s


func test_disband_deactivates_army_and_returns_pu() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["disband_ordered"] = true
	army["clan_name"] = "Crab"
	var comp: Dictionary = {
		"army_id": 1,
		"source_province_id": 3,
		"current_health": 100,
	}
	var settlement: SettlementData = _make_settlement_for_disband(3)
	var results: Array[Dictionary] = DayOrchestrator._process_disbands(
		[army], [comp], [settlement],
	)
	assert_eq(results.size(), 1)
	assert_false(army.get("is_active", true), "Army should be deactivated")
	assert_true(settlement.military_pu > 0, "PU should be returned")


func test_disband_skips_non_disband_army() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["clan_name"] = "Crab"
	var results: Array[Dictionary] = DayOrchestrator._process_disbands(
		[army], [], [],
	)
	assert_eq(results.size(), 0)


func test_disband_skips_already_inactive() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["disband_ordered"] = true
	army["is_active"] = false
	army["clan_name"] = "Crab"
	var results: Array[Dictionary] = DayOrchestrator._process_disbands(
		[army], [], [],
	)
	assert_eq(results.size(), 0)


func test_disband_skips_company_without_health() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["disband_ordered"] = true
	army["clan_name"] = "Crab"
	var comp: Dictionary = {
		"army_id": 1,
		"source_province_id": 3,
		"current_health": 0,
	}
	var settlement: SettlementData = _make_settlement_for_disband(3)
	var results: Array[Dictionary] = DayOrchestrator._process_disbands(
		[army], [comp], [settlement],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["pu_returned"].size(), 0, "Dead company returns no PU")


func test_disband_multiple_companies_returns_to_correct_settlements() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["disband_ordered"] = true
	army["clan_name"] = "Crab"
	var comp1: Dictionary = {"army_id": 1, "source_province_id": 3, "current_health": 100}
	var comp2: Dictionary = {"army_id": 1, "source_province_id": 7, "current_health": 80}
	var s1: SettlementData = _make_settlement_for_disband(3)
	var s2: SettlementData = _make_settlement_for_disband(7)
	var results: Array[Dictionary] = DayOrchestrator._process_disbands(
		[army], [comp1, comp2], [s1, s2],
	)
	assert_eq(results[0]["pu_returned"].size(), 2)
	assert_true(s1.military_pu > 0)
	assert_true(s2.military_pu > 0)


func test_disband_runs_before_movement_in_daily() -> void:
	var army: Dictionary = ArmyMovementSystem.create_army_state(1, 10, "Crab")
	army["disband_ordered"] = true
	army["clan_name"] = "Crab"
	army["is_active"] = true
	var comp: Dictionary = {"army_id": 1, "source_province_id": 3, "current_health": 100}
	var settlement: SettlementData = _make_settlement_for_disband(3)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		[army], [], [], [], DiceEngine.new(), [settlement], [comp],
	)
	assert_true(result.has("disband_results"))
	assert_eq(result["disband_results"].size(), 1)
	assert_false(army.get("is_active", true))
