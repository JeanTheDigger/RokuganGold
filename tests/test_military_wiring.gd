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
	var active_wars: Array[WarData] = []
	var applied: Array = [
		{
			"effects": {
				"effect": "readiness_assessed",
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_war_declarations(
		applied, active_wars, 100,
	)
	assert_eq(results.size(), 0)
