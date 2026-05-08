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
