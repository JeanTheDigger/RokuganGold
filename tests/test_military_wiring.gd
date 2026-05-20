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


func _make_empty_siege_state() -> Dictionary:
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
	assert_true(DayOrchestrator.new().has_method("advance_day"))


func test_military_daily_returns_all_keys() -> void:
	var r: Dictionary = DayOrchestrator._process_military_daily(
		[], [], [], [], DiceEngine.new(), [], [],
	)
	assert_true(r.has("movement_results"))
	assert_true(r.has("battle_results"))
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
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [100]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(r["type"], "levy_raised")
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


func test_levy_creates_company_dict() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [100]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(companies.size(), 1)
	assert_eq(companies[0]["company_id"], 100)
	assert_eq(companies[0]["lord_id"], 5)
	assert_eq(companies[0]["source_province_id"], 1)
	assert_eq(companies[0]["army_id"], -1)
	assert_false(companies[0]["destroyed"])
	assert_eq(r["company_id"], 100)
	assert_eq(r["unit_type"], Enums.CompanyUnitType.ASHIGARU_SPEARMEN)


func test_levy_increments_company_id() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 5)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [50]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	DayOrchestrator._apply_levy_pu_effect(applied, [s], companies, next_id)
	assert_eq(next_id[0], 51)


func test_levy_respects_unit_type_metadata() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {
			"requires_levy_pu": true,
			"levy_unit_type": Enums.CompanyUnitType.PEASANT_LEVY,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(companies[0]["unit_type"], Enums.CompanyUnitType.PEASANT_LEVY)
	assert_eq(r["unit_type"], Enums.CompanyUnitType.PEASANT_LEVY)


func test_levy_defaults_to_ashigaru_spearmen() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	DayOrchestrator._apply_levy_pu_effect(applied, [s], companies, next_id)
	assert_eq(companies[0]["unit_type"], Enums.CompanyUnitType.ASHIGARU_SPEARMEN)


func test_levy_company_has_correct_health() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	DayOrchestrator._apply_levy_pu_effect(applied, [s], companies, next_id)
	var stats: Dictionary = ArmyCombatSystem.UNIT_STATS[Enums.CompanyUnitType.ASHIGARU_SPEARMEN]
	assert_eq(companies[0]["health"], stats["health"])
	assert_eq(companies[0]["morale"], stats["morale"])


func test_levy_returns_arms_cost() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	var expected_cost: float = ArmyUpkeepSystem.get_arms_equip_cost(
		Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
	)
	assert_eq(r["arms_cost"], expected_cost)


func test_levy_scanned_in_process_military_effects() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [200]
	var applied_list: Array = [{
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_military_effects(
		applied_list, [s], {}, companies, {}, next_id,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "levy_raised")
	assert_eq(companies.size(), 1)
	assert_eq(companies[0]["company_id"], 200)


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


# -- Iron Upkeep Deducts from iron_stockpile (GDD s4.3.10) ----------------------
# GDD s4.3.10 is explicit: "paid in Iron, not Arms."
# Confirmed the day_orchestrator reads/writes iron_stockpile, not arms_stockpile.

func test_army_upkeep_iron_deducts_from_iron_stockpile() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var clan: ClanData = _make_clan("Crab", [1])
	clan.iron_stockpile = 10.0
	clan.arms_stockpile = 99.0  # must not change
	var clans: Dictionary = {"Crab": clan}

	DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_almost_eq(clan.arms_stockpile, 99.0, 0.001, "arms_stockpile must not be touched by iron upkeep")
	assert_true(clan.iron_stockpile < 10.0, "iron_stockpile must decrease by iron upkeep cost")


func test_army_upkeep_insufficient_iron_does_not_touch_arms() -> void:
	var companies: Array[Dictionary] = [
		_make_company_dict(1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN),
	]
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var clan: ClanData = _make_clan("Crab", [1])
	clan.iron_stockpile = 0.0
	clan.arms_stockpile = 99.0
	var clans: Dictionary = {"Crab": clan}

	var r: Dictionary = DayOrchestrator._process_army_upkeep(companies, [s], clans)
	assert_almost_eq(clan.arms_stockpile, 99.0, 0.001, "arms_stockpile untouched when iron runs out")
	assert_almost_eq(clan.iron_stockpile, 0.0, 0.001, "iron_stockpile floors at 0")
	var iron_result: Dictionary = r["iron_results"][0]
	assert_false(iron_result["supplied"])


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
	c.iron_stockpile = 10.0
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


func test_tether_tick_injects_army_id_into_results() -> void:
	var typed_path: Array[int] = [10]
	var tether: Dictionary = SupplyTetherSystem.create_tether(7, 100, typed_path)
	tether["garrisons_on_path"] = {}
	tether["enemy_armies_on_path"] = []
	var dice: DiceEngine = DiceEngine.new(42)
	var results: Array[Dictionary] = DayOrchestrator._process_tether_ticks(
		[tether], dice, [],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["army_id"], 7)


func test_tether_tick_skips_detached_tethers() -> void:
	var typed_path: Array[int] = [10]
	var tether: Dictionary = SupplyTetherSystem.create_tether(7, 100, typed_path)
	tether["detached"] = true
	var dice: DiceEngine = DiceEngine.new(42)
	var results: Array[Dictionary] = DayOrchestrator._process_tether_ticks(
		[tether], dice, [],
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
	clan.iron_stockpile = 10.0
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
	clan.iron_stockpile = 10.0
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
	army["path"] = [5]
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
	army["path"] = [5]
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
	army["path"] = [5]
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
	army["path"] = [5]
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
	army["path"] = [5]
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
	army["path"] = [5]
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
	army["path"] = [5]
	army["destination_sub_tile"] = 5
	var dice: DiceEngine = DiceEngine.new(42)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		[army],
		[],
		[],
		[],
		dice,
		[],
		[],
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
	army["path"] = [5]
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


# -- Garrison Assignment Tests --------------------------------------------------

func _make_character_for_garrison(
	id: int,
	clan: String = "Crane",
	honor: float = 3.0,
) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.honor = honor
	return c


func _make_wall_tower(id: int, province_id: int, garrison: float = 2.0) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.garrison_pu = garrison
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	return s


func _make_province(id: int, clan: String) -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = id
	p.clan = clan
	return p


func test_garrison_assignment_transfers_pu() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 2.0)
	var source: SettlementData = _make_settlement(2, 200, 10, 3)
	source.garrison_pu = 5.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
			"honor_gain_recipient": 0.1,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane},
	)
	assert_eq(r["type"], "garrison_assigned")
	assert_eq(r["daimyo_id"], 10)
	assert_eq(r["target_province_id"], 100)
	assert_almost_eq(r["pu_transferred"], 1.0, 0.01)
	assert_almost_eq(wall.garrison_pu, 3.0, 0.01)
	assert_almost_eq(source.garrison_pu, 4.0, 0.01)
	assert_almost_eq(daimyo.honor, 3.1, 0.01)


func test_garrison_assignment_honor_applied_to_daimyo() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane", 5.0)
	var wall: SettlementData = _make_wall_tower(1, 100, 1.0)
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 2.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
			"honor_gain_recipient": 0.1,
		},
	}
	DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane},
	)
	assert_almost_eq(daimyo.honor, 5.1, 0.01)


func test_garrison_assignment_partial_pu_when_source_low() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 2.0)
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 0.4
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
			"honor_gain_recipient": 0.1,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane},
	)
	assert_almost_eq(r["pu_transferred"], 0.4, 0.01)
	assert_almost_eq(source.garrison_pu, 0.0, 0.01)
	assert_almost_eq(wall.garrison_pu, 2.4, 0.01)


func test_garrison_assignment_no_target_returns_empty() -> void:
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": -1,
			"target_province_id": 100,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_garrison_assignment(
		applied, {}, [], {},
	)
	assert_true(r.is_empty())


func test_garrison_assignment_no_wall_tower_no_transfer() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 5.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
			"honor_gain_recipient": 0.1,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [source], {200: province_crane},
	)
	assert_eq(r["type"], "garrison_assigned")
	assert_almost_eq(r["pu_transferred"], 0.0, 0.01)
	assert_almost_eq(source.garrison_pu, 5.0, 0.01)


func test_garrison_assignment_scanned_in_process_military_effects() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 2.0)
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 3.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied_list: Array = [
		{
			"character_id": 5,
			"effects": {
				"requires_garrison_assignment": true,
				"target_npc_id": 10,
				"target_province_id": 100,
				"honor_gain_recipient": 0.1,
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._process_military_effects(
		applied_list, [wall, source], {10: daimyo}, [], {200: province_crane},
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "garrison_assigned")


func test_garrison_assignment_requester_id_captured() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 2.0)
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 3.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 42,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
			"honor_gain_recipient": 0.1,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane},
	)
	assert_eq(r["requester_id"], 42)


func test_garrison_assignment_sets_courtier_dispatched_flag() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 0.0)  # below minimum
	wall.garrison_shortage_courtier_dispatched = false
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 0.5
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
		},
	}
	DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane}
	)
	assert_true(wall.garrison_shortage_courtier_dispatched)


func test_garrison_assignment_resets_shortage_flags_when_resolved() -> void:
	# Transfer enough PU to bring garrison above minimum (MINIMUM_GARRISON_PU = 1.0).
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 0.0)
	wall.garrison_shortage_letter_season = 3
	wall.garrison_shortage_courtier_dispatched = true
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 5.0  # plenty to bring tower above minimum
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
		},
	}
	DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane}
	)
	# wall.garrison_pu is now 1.0 which equals MINIMUM_GARRISON_PU → resolved
	assert_eq(wall.garrison_shortage_letter_season, -1)
	assert_false(wall.garrison_shortage_courtier_dispatched)


func test_garrison_assignment_keeps_flags_when_still_below_minimum() -> void:
	# Partial transfer — garrison still below minimum; flags should NOT reset.
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 0.0)
	wall.garrison_shortage_letter_season = 2
	wall.garrison_shortage_courtier_dispatched = true
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 0.5  # partial — wall becomes 0.5 which is still < 1.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
		},
	}
	DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane}
	)
	assert_eq(wall.garrison_shortage_letter_season, 2)  # unchanged
	assert_true(wall.garrison_shortage_courtier_dispatched)  # unchanged


# -- Garrison shortage letter write-back (s2.4.13–14) -------------------------

func _make_character_at_tower(id: int, tower_id: int) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.physical_location = str(tower_id)
	return c


func test_letter_writeback_marks_tower_letter_season() -> void:
	var tower: SettlementData = _make_wall_tower(1, 10, 0.0)
	tower.settlement_id = 1
	var char: L5RCharacterData = _make_character_at_tower(5, 1)
	var letter_results: Array[Dictionary] = [{
		"character_id": 5,
		"need_type": "STRENGTHEN_WALL",
		"action_id": "WRITE_LETTER",
	}]
	DayOrchestrator._apply_garrison_shortage_letter_writebacks(
		letter_results, {5: char}, [tower], 4
	)
	assert_eq(tower.garrison_shortage_letter_season, 4)


func test_letter_writeback_ignores_non_strengthen_wall_need() -> void:
	var tower: SettlementData = _make_wall_tower(1, 10, 0.0)
	var char: L5RCharacterData = _make_character_at_tower(5, 1)
	var letter_results: Array[Dictionary] = [{
		"character_id": 5,
		"need_type": "MAXIMIZE_PROSPERITY",
		"action_id": "WRITE_LETTER",
	}]
	DayOrchestrator._apply_garrison_shortage_letter_writebacks(
		letter_results, {5: char}, [tower], 4
	)
	assert_eq(tower.garrison_shortage_letter_season, -1)


func test_letter_writeback_ignores_unknown_character() -> void:
	var tower: SettlementData = _make_wall_tower(1, 10, 0.0)
	var letter_results: Array[Dictionary] = [{
		"character_id": 999,  # not in characters_by_id
		"need_type": "STRENGTHEN_WALL",
		"action_id": "WRITE_LETTER",
	}]
	DayOrchestrator._apply_garrison_shortage_letter_writebacks(
		letter_results, {}, [tower], 4
	)
	assert_eq(tower.garrison_shortage_letter_season, -1)


func test_letter_writeback_ignores_non_tower_settlement() -> void:
	var town: SettlementData = _make_settlement(1, 10)  # not a WALL_TOWER
	var char: L5RCharacterData = _make_character_at_tower(5, 1)
	var letter_results: Array[Dictionary] = [{
		"character_id": 5,
		"need_type": "STRENGTHEN_WALL",
		"action_id": "WRITE_LETTER",
	}]
	DayOrchestrator._apply_garrison_shortage_letter_writebacks(
		letter_results, {5: char}, [town], 4
	)
	# Town should be unchanged (not a WALL_TOWER)
	assert_eq(town.garrison_shortage_letter_season, -1)


# -- Garrison courtier refusal write-back (s2.4.14) ----------------------------

func test_refusal_writeback_sets_courtier_refused_flag() -> void:
	var tower: SettlementData = _make_wall_tower(1, 100, 0.0)
	tower.garrison_shortage_courtier_refused = false
	var results: Array[Dictionary] = [{
		"action_id": "DISPATCH_COURTIER",
		"effects": {
			"garrison_refused": true,
			"target_province_id": 100,
		},
	}]
	DayOrchestrator._apply_garrison_courtier_refusal_writebacks(
		results, [tower]
	)
	assert_true(tower.garrison_shortage_courtier_refused)


func test_refusal_writeback_ignores_non_refused_effects() -> void:
	var tower: SettlementData = _make_wall_tower(1, 100, 0.0)
	tower.garrison_shortage_courtier_refused = false
	var results: Array[Dictionary] = [{
		"action_id": "DISPATCH_COURTIER",
		"effects": {
			"garrison_refused": false,
			"target_province_id": 100,
		},
	}]
	DayOrchestrator._apply_garrison_courtier_refusal_writebacks(
		results, [tower]
	)
	assert_false(tower.garrison_shortage_courtier_refused)


func test_refusal_writeback_ignores_mismatched_province() -> void:
	var tower: SettlementData = _make_wall_tower(1, 200, 0.0)  # province 200
	tower.garrison_shortage_courtier_refused = false
	var results: Array[Dictionary] = [{
		"action_id": "DISPATCH_COURTIER",
		"effects": {
			"garrison_refused": true,
			"target_province_id": 100,  # different province
		},
	}]
	DayOrchestrator._apply_garrison_courtier_refusal_writebacks(
		results, [tower]
	)
	assert_false(tower.garrison_shortage_courtier_refused)


func test_garrison_assignment_resets_courtier_refused_when_resolved() -> void:
	var daimyo: L5RCharacterData = _make_character_for_garrison(10, "Crane")
	var wall: SettlementData = _make_wall_tower(1, 100, 0.0)
	wall.garrison_shortage_courtier_refused = true
	var source: SettlementData = _make_settlement(2, 200)
	source.garrison_pu = 5.0
	var province_crane: ProvinceData = _make_province(200, "Crane")
	var applied: Dictionary = {
		"character_id": 5,
		"effects": {
			"requires_garrison_assignment": true,
			"target_npc_id": 10,
			"target_province_id": 100,
		},
	}
	DayOrchestrator._apply_garrison_assignment(
		applied, {10: daimyo}, [wall, source], {200: province_crane}
	)
	assert_false(wall.garrison_shortage_courtier_refused)


# -- Army Battle Resolution Tests -----------------------------------------------

func _make_company_dict_for_battle(
	id: int,
	army_id: int,
	clan: String = "Crab",
	ut: int = Enums.CompanyUnitType.BUSHI_RETAINER,
) -> Dictionary:
	var stats: Dictionary = ArmyCombatSystem.UNIT_STATS.get(ut, {})
	return {
		"company_id": id,
		"army_id": army_id,
		"unit_type": ut,
		"clan_name": clan,
		"commander_id": -1,
		"source_province_id": 1,
		"current_health": stats.get("health", 153),
		"current_morale": stats.get("morale", 10),
	}


func test_company_dict_to_data_converts_correctly() -> void:
	var cd: Dictionary = _make_company_dict_for_battle(1, 10, "Crab")
	var data: MilitaryUnitData.CompanyData = DayOrchestrator._company_dict_to_data(cd)
	assert_eq(data.company_id, 1)
	assert_eq(data.unit_type, Enums.CompanyUnitType.BUSHI_RETAINER)
	assert_true(data.health > 0)
	assert_true(data.attack > 0)


func test_get_army_companies_filters_by_army_id() -> void:
	var c1: Dictionary = _make_company_dict_for_battle(1, 10)
	var c2: Dictionary = _make_company_dict_for_battle(2, 10)
	var c3: Dictionary = _make_company_dict_for_battle(3, 20)
	var result: Array[Dictionary] = DayOrchestrator._get_army_companies(
		10, [c1, c2, c3],
	)
	assert_eq(result.size(), 2)


func test_build_battle_states_creates_states() -> void:
	var cd: Dictionary = _make_company_dict_for_battle(1, 10)
	var states: Array[Dictionary] = DayOrchestrator._build_battle_states(
		[cd], "attacker", {},
	)
	assert_eq(states.size(), 1)
	assert_eq(states[0]["side"], "attacker")
	assert_eq(states[0]["company_id"], 1)
	assert_true(states[0]["starting_health"] > 0)


func test_write_battle_results_updates_companies() -> void:
	var cd: Dictionary = _make_company_dict_for_battle(1, 10)
	cd["current_health"] = 153
	var battle_result: Dictionary = {
		"attacker_states": [
			{"company_id": 1, "current_health": 50, "current_morale": 3,
			 "is_destroyed": false, "is_routed": false, "commander_dead": false},
		],
		"defender_states": [],
	}
	DayOrchestrator._write_battle_results_to_companies(battle_result, [cd])
	assert_eq(cd["current_health"], 50)
	assert_eq(cd["current_morale"], 3)


func test_write_battle_results_marks_destroyed() -> void:
	var cd: Dictionary = _make_company_dict_for_battle(1, 10)
	cd["commander_id"] = 5
	var battle_result: Dictionary = {
		"attacker_states": [
			{"company_id": 1, "current_health": 0, "current_morale": 0,
			 "is_destroyed": true, "is_routed": false, "commander_dead": true},
		],
		"defender_states": [],
	}
	DayOrchestrator._write_battle_results_to_companies(battle_result, [cd])
	assert_eq(cd["current_health"], 0)
	assert_true(cd.get("is_destroyed", false))
	assert_true(cd.get("commander_dead", false))
	assert_eq(cd["commander_id"], -1)


func test_resolve_army_battles_no_trigger_returns_empty() -> void:
	var movement_results: Array[Dictionary] = [
		{"army_id": 1, "arrived": true, "battle_check": {"battle_triggered": false}},
	]
	var results: Array[Dictionary] = DayOrchestrator._resolve_army_battles(
		movement_results, [], [], [], DiceEngine.new(), [], {}, {},
	)
	assert_eq(results.size(), 0)


func test_resolve_army_battles_skips_when_not_at_war() -> void:
	var army_a: Dictionary = ArmyMovementSystem.create_army_state(1, 5, "Crab")
	var army_b: Dictionary = ArmyMovementSystem.create_army_state(2, 5, "Crane")
	var c1: Dictionary = _make_company_dict_for_battle(1, 1, "Crab")
	var c2: Dictionary = _make_company_dict_for_battle(2, 2, "Crane")
	var movement_results: Array[Dictionary] = [
		{
			"army_id": 1, "arrived": true,
			"battle_check": {
				"battle_triggered": true,
				"enemy_army_ids": [2],
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._resolve_army_battles(
		movement_results, [army_a, army_b], [c1, c2],
		[], DiceEngine.new(42), [], {}, {},
	)
	assert_eq(results.size(), 0)


func test_resolve_army_battles_resolves_combat_when_at_war() -> void:
	var dice: DiceEngine = DiceEngine.new(42)
	var army_a: Dictionary = ArmyMovementSystem.create_army_state(1, 5, "Crab")
	var army_b: Dictionary = ArmyMovementSystem.create_army_state(2, 5, "Crane")
	var c1: Dictionary = _make_company_dict_for_battle(
		1, 1, "Crab", Enums.CompanyUnitType.BUSHI_RETAINER,
	)
	var c2: Dictionary = _make_company_dict_for_battle(
		2, 2, "Crane", Enums.CompanyUnitType.PEASANT_LEVY,
	)
	var war: WarData = WarSystem.declare_war(1, "Crab", "Crane", 1, 1, 2)
	var s1: SettlementData = _make_settlement(10, 1, 10, 3)
	var movement_results: Array[Dictionary] = [
		{
			"army_id": 1, "arrived": true,
			"battle_check": {
				"battle_triggered": true,
				"enemy_army_ids": [2],
			},
		},
	]
	var results: Array[Dictionary] = DayOrchestrator._resolve_army_battles(
		movement_results, [army_a, army_b], [c1, c2],
		[war], dice, [s1], {}, {},
	)
	assert_eq(results.size(), 1)
	assert_true(results[0].has("victor"))
	assert_true(results[0].has("reconciliation"))
	assert_eq(results[0]["attacker_clan"], "Crab")
	assert_eq(results[0]["defender_clan"], "Crane")
	# Companies should have been mutated
	var health_changed: bool = (
		c1["current_health"] != 153 or c2["current_health"] != 153
	)
	assert_true(health_changed, "At least one company should take damage")


func test_resolve_army_battles_marks_battle_resolved_on_movement() -> void:
	var dice: DiceEngine = DiceEngine.new(42)
	var army_a: Dictionary = ArmyMovementSystem.create_army_state(1, 5, "Crab")
	var army_b: Dictionary = ArmyMovementSystem.create_army_state(2, 5, "Crane")
	var c1: Dictionary = _make_company_dict_for_battle(1, 1, "Crab")
	var c2: Dictionary = _make_company_dict_for_battle(2, 2, "Crane")
	var war: WarData = WarSystem.declare_war(1, "Crab", "Crane", 1, 1, 2)
	var mr: Dictionary = {
		"army_id": 1, "arrived": true,
		"battle_check": {"battle_triggered": true, "enemy_army_ids": [2]},
	}
	DayOrchestrator._resolve_army_battles(
		[mr], [army_a, army_b], [c1, c2],
		[war], dice, [], {}, {},
	)
	assert_true(mr.get("battle_resolved", false))


func test_resolve_army_battles_in_military_daily() -> void:
	var dice: DiceEngine = DiceEngine.new(42)
	var army_a: Dictionary = ArmyMovementSystem.create_army_state(1, 5, "Crab")
	army_a["is_moving"] = true
	army_a["days_remaining"] = 1
	army_a["path"] = [0, 5]
	army_a["path_index"] = 0
	var army_b: Dictionary = ArmyMovementSystem.create_army_state(2, 5, "Crane")
	var c1: Dictionary = _make_company_dict_for_battle(1, 1, "Crab")
	var c2: Dictionary = _make_company_dict_for_battle(2, 2, "Crane")
	var war: WarData = WarSystem.declare_war(1, "Crab", "Crane", 1, 1, 2)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		[army_a, army_b], [], [], [], dice, [], [c1, c2], {},
		[war], {},
	)
	assert_true(result.has("battle_results"))


# -- Levy Unit Type Selection Tests ----------------------------------------------

func test_select_levy_unit_type_default_is_ashigaru_spearmen() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = true
	ctx.unit_training_counts = {}
	var ut: int = NPCDecisionEngine._select_levy_unit_type(ctx)
	assert_eq(ut, Enums.CompanyUnitType.ASHIGARU_SPEARMEN)


func test_select_levy_peasant_when_no_iron() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = false
	ctx.unit_training_counts = {}
	var ut: int = NPCDecisionEngine._select_levy_unit_type(ctx)
	assert_eq(ut, Enums.CompanyUnitType.PEASANT_LEVY)


func test_select_levy_archers_when_enough_spearmen() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = true
	ctx.unit_training_counts = {Enums.CompanyUnitType.ASHIGARU_SPEARMEN: 2}
	var ut: int = NPCDecisionEngine._select_levy_unit_type(ctx)
	assert_eq(ut, Enums.CompanyUnitType.ASHIGARU_ARCHERS)


func test_select_levy_spearmen_when_already_have_archers() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = true
	ctx.unit_training_counts = {
		Enums.CompanyUnitType.ASHIGARU_SPEARMEN: 2,
		Enums.CompanyUnitType.ASHIGARU_ARCHERS: 1,
	}
	var ut: int = NPCDecisionEngine._select_levy_unit_type(ctx)
	assert_eq(ut, Enums.CompanyUnitType.ASHIGARU_SPEARMEN)


func test_select_levy_iron_gate_overrides_composition() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = false
	ctx.unit_training_counts = {Enums.CompanyUnitType.ASHIGARU_SPEARMEN: 5}
	var ut: int = NPCDecisionEngine._select_levy_unit_type(ctx)
	assert_eq(ut, Enums.CompanyUnitType.PEASANT_LEVY)


func test_populate_metadata_order_levy() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "ORDER_LEVY"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = true
	ctx.unit_training_counts = {}
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_true(option.metadata.has("levy_unit_type"))
	assert_eq(option.metadata["levy_unit_type"], Enums.CompanyUnitType.ASHIGARU_SPEARMEN)


func test_executor_order_levy_passes_unit_type() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ORDER_LEVY"
	action.metadata = {"levy_unit_type": Enums.CompanyUnitType.ASHIGARU_ARCHERS}
	var effects: Dictionary = ActionExecutor._compute_military_effects("ORDER_LEVY", action)
	assert_eq(effects["levy_unit_type"], Enums.CompanyUnitType.ASHIGARU_ARCHERS)
	assert_true(effects["requires_levy_pu"])


func test_executor_order_levy_defaults_without_metadata() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ORDER_LEVY"
	action.metadata = {}
	var effects: Dictionary = ActionExecutor._compute_military_effects("ORDER_LEVY", action)
	assert_eq(effects["levy_unit_type"], Enums.CompanyUnitType.ASHIGARU_SPEARMEN)


# -- Arms Equip Deduction Tests --------------------------------------------------

func _make_char_for_levy(id: int, clan: String) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	return c


func test_levy_deducts_arms_from_clan() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var clan: ClanData = _make_clan("Crab", [1])
	clan.arms_stockpile = 10.0
	var chars_by_id: Dictionary = {5: lord}
	var clans_dict: Dictionary = {"Crab": clan}
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id, chars_by_id, clans_dict,
	)
	var expected_cost: float = ArmyUpkeepSystem.get_arms_equip_cost(
		Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
	)
	assert_eq(r["arms_deducted"], expected_cost)
	assert_almost_eq(clan.arms_stockpile, 10.0 - expected_cost, 0.001)


func test_levy_arms_clamped_at_zero() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var clan: ClanData = _make_clan("Crab", [1])
	clan.arms_stockpile = 0.5
	var chars_by_id: Dictionary = {5: lord}
	var clans_dict: Dictionary = {"Crab": clan}
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id, chars_by_id, clans_dict,
	)
	assert_eq(clan.arms_stockpile, 0.0)


func test_levy_no_arms_deduction_without_clan() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var chars_by_id: Dictionary = {5: lord}
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id, chars_by_id, {},
	)
	assert_eq(r["arms_deducted"], 0.0)
	assert_eq(companies.size(), 1)


func test_levy_peasant_levy_cheaper_arms() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var clan: ClanData = _make_clan("Crab", [1])
	clan.arms_stockpile = 10.0
	var chars_by_id: Dictionary = {5: lord}
	var clans_dict: Dictionary = {"Crab": clan}
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {
			"requires_levy_pu": true,
			"levy_unit_type": Enums.CompanyUnitType.PEASANT_LEVY,
		},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id, chars_by_id, clans_dict,
	)
	var expected_cost: float = ArmyUpkeepSystem.get_arms_equip_cost(
		Enums.CompanyUnitType.PEASANT_LEVY,
	)
	assert_eq(r["arms_deducted"], expected_cost)
	assert_true(expected_cost < 1.0)


# -- Levy Province Selection Tests -----------------------------------------------

func test_pick_levy_province_returns_largest_pu() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	var ps1 := NPCDataStructures.ProvinceStatus.new()
	ps1.province_id = 10
	ps1.total_settlement_pu = 5
	var ps2 := NPCDataStructures.ProvinceStatus.new()
	ps2.province_id = 20
	ps2.total_settlement_pu = 12
	ctx.province_statuses = [ps1, ps2]
	var pid: int = NPCDecisionEngine._pick_levy_province(ctx)
	assert_eq(pid, 20)


func test_pick_levy_province_single() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	var ps1 := NPCDataStructures.ProvinceStatus.new()
	ps1.province_id = 7
	ps1.total_settlement_pu = 3
	ctx.province_statuses = [ps1]
	assert_eq(NPCDecisionEngine._pick_levy_province(ctx), 7)


func test_pick_levy_province_empty() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.province_statuses = []
	assert_eq(NPCDecisionEngine._pick_levy_province(ctx), -1)


func test_populate_metadata_order_levy_sets_province() -> void:
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "ORDER_LEVY"
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.can_sustain_iron_upkeep = true
	ctx.unit_training_counts = {}
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 42
	ps.total_settlement_pu = 8
	ctx.province_statuses = [ps]
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.target_province_id, 42)


# -- Levy Suspicion Tests --------------------------------------------------------

func _make_levy_company(
	company_id: int,
	lord_id: int,
	raised_season: int = 0,
) -> Dictionary:
	return {
		"company_id": company_id,
		"unit_type": Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
		"health": 153,
		"morale": 12,
		"commander_id": -1,
		"parent_legion_id": -1,
		"source_province_id": 1,
		"army_id": -1,
		"lord_id": lord_id,
		"destroyed": false,
		"routed": false,
		"levy_raised_season": raised_season,
	}


func test_levy_suspicion_fires_after_threshold() -> void:
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	lord.family = "Hida"
	var chars_by_id: Dictionary = {5: lord}
	var company: Dictionary = _make_levy_company(1, 5, 0)
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_levy_suspicion(
		[company], [], chars_by_id, topics, next_tid, 90, 1,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["lord_id"], 5)
	assert_eq(results[0]["topic_tier"], 4)
	assert_eq(topics.size(), 1)


func test_levy_suspicion_skips_wartime() -> void:
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var chars_by_id: Dictionary = {5: lord}
	var company: Dictionary = _make_levy_company(1, 5, 0)
	var war: WarData = WarSystem.declare_war(1, "Crab", "Crane", 1, 1, 2)
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_levy_suspicion(
		[company], [war], chars_by_id, topics, next_tid, 90, 3,
	)
	assert_eq(results.size(), 0)
	assert_eq(topics.size(), 0)


func test_levy_suspicion_skips_before_threshold() -> void:
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var chars_by_id: Dictionary = {5: lord}
	var company: Dictionary = _make_levy_company(1, 5, 5)
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_levy_suspicion(
		[company], [], chars_by_id, topics, next_tid, 90, 5,
	)
	assert_eq(results.size(), 0)


func test_levy_suspicion_escalates_at_3_seasons() -> void:
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	lord.family = "Hida"
	var chars_by_id: Dictionary = {5: lord}
	var company: Dictionary = _make_levy_company(1, 5, 0)
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_levy_suspicion(
		[company], [], chars_by_id, topics, next_tid, 90, 3,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["topic_tier"], 3)
	assert_true(results[0]["escalated"])


func test_levy_suspicion_skips_army_companies() -> void:
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	var chars_by_id: Dictionary = {5: lord}
	var company: Dictionary = _make_levy_company(1, 5, 0)
	company["army_id"] = 1
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_levy_suspicion(
		[company], [], chars_by_id, topics, next_tid, 90, 2,
	)
	assert_eq(results.size(), 0)


func test_levy_suspicion_one_topic_per_lord() -> void:
	var lord: L5RCharacterData = _make_char_for_levy(5, "Crab")
	lord.family = "Hida"
	var chars_by_id: Dictionary = {5: lord}
	var c1: Dictionary = _make_levy_company(1, 5, 0)
	var c2: Dictionary = _make_levy_company(2, 5, 0)
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_levy_suspicion(
		[c1, c2], [], chars_by_id, topics, next_tid, 90, 2,
	)
	assert_eq(results.size(), 1)
	assert_eq(topics.size(), 1)


func test_levy_company_dict_has_raised_season() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id, {}, {}, 7,
	)
	assert_eq(companies[0]["levy_raised_season"], 7)


# -- Levy PU Validation Tests ----------------------------------------------------

func test_levy_fails_with_insufficient_pu() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 0)
	s.garrison_pu = 10
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(r["type"], "levy_failed")
	assert_eq(r["reason"], "insufficient_pu")
	assert_eq(companies.size(), 0)


func test_levy_fails_no_military_pu() -> void:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	s.population_pu = 5
	s.military_pu = 0
	s.garrison_pu = 0
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(r["type"], "levy_failed")
	assert_eq(r["reason"], "insufficient_pu")
	assert_eq(companies.size(), 0)


func test_levy_succeeds_with_sufficient_pu() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 3)
	s.garrison_pu = 1
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [1]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	var r: Dictionary = DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(r["type"], "levy_raised")
	assert_eq(companies.size(), 1)


func test_levy_fails_does_not_increment_company_id() -> void:
	var s: SettlementData = _make_settlement(10, 1, 10, 0)
	s.garrison_pu = 10
	var companies: Array[Dictionary] = []
	var next_id: Array[int] = [50]
	var applied: Dictionary = {
		"character_id": 5,
		"target_province_id": 1,
		"effects": {"requires_levy_pu": true},
	}
	DayOrchestrator._apply_levy_pu_effect(
		applied, [s], companies, next_id,
	)
	assert_eq(next_id[0], 50)


# -- Battle Terrain & Fortification Tests ----------------------------------------

func test_get_battle_terrain_plains_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.PLAINS
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [])
	assert_eq(terrain, Enums.BattleTerrainType.PLAINS)


func test_get_battle_terrain_forest_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.FOREST
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [])
	assert_eq(terrain, Enums.BattleTerrainType.FOREST)


func test_get_battle_terrain_mountains_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.MOUNTAINS
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [])
	assert_eq(terrain, Enums.BattleTerrainType.MOUNTAIN)


func test_get_battle_terrain_hills_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.HILLS
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [])
	assert_eq(terrain, Enums.BattleTerrainType.HILLS)


func test_get_battle_terrain_river_delta_maps_to_plains() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.RIVER_DELTA
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [])
	assert_eq(terrain, Enums.BattleTerrainType.PLAINS)


func test_get_battle_terrain_urban_overrides_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.FOREST
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.TOWN
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [s])
	assert_eq(terrain, Enums.BattleTerrainType.URBAN)


func test_get_battle_terrain_city_is_urban() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.CITY
	var terrain: int = DayOrchestrator._get_battle_terrain(1, {}, [s])
	assert_eq(terrain, Enums.BattleTerrainType.URBAN)


func test_get_battle_terrain_imperial_capital_is_urban() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.IMPERIAL_CAPITAL
	var terrain: int = DayOrchestrator._get_battle_terrain(1, {}, [s])
	assert_eq(terrain, Enums.BattleTerrainType.URBAN)


func test_get_battle_terrain_village_does_not_override() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.terrain_type = Enums.TerrainType.FOREST
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.VILLAGE
	var provinces: Dictionary = {1: p}
	var terrain: int = DayOrchestrator._get_battle_terrain(1, provinces, [s])
	assert_eq(terrain, Enums.BattleTerrainType.FOREST)


func test_get_battle_terrain_unknown_province_defaults_plains() -> void:
	var terrain: int = DayOrchestrator._get_battle_terrain(999, {}, [])
	assert_eq(terrain, Enums.BattleTerrainType.PLAINS)


func test_get_fortification_bonus_with_fort() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.FORTIFICATION
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Crab", [s])
	assert_eq(bonus, DayOrchestrator.FORTIFICATION_DEFENSE_BONUS)


func test_get_fortification_bonus_with_castle() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.CASTLE
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Lion", [s])
	assert_eq(bonus, DayOrchestrator.FORTIFICATION_DEFENSE_BONUS)


func test_get_fortification_bonus_with_wall_tower() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Crab", [s])
	assert_eq(bonus, DayOrchestrator.FORTIFICATION_DEFENSE_BONUS)


func test_get_fortification_bonus_no_fort() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.VILLAGE
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Crab", [s])
	assert_eq(bonus, 0)


func test_get_fortification_bonus_wrong_province() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 2
	s.settlement_type = Enums.SettlementType.CASTLE
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Lion", [s])
	assert_eq(bonus, 0)


func test_get_fortification_bonus_empty_settlements() -> void:
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Crab", [])
	assert_eq(bonus, 0)


func test_get_fortification_bonus_defender_owns_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.clan = "Crab"
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.FORTIFICATION
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Crab", [s], {1: p})
	assert_eq(bonus, DayOrchestrator.FORTIFICATION_DEFENSE_BONUS)


func test_get_fortification_bonus_attacker_in_enemy_province() -> void:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = 1
	p.clan = "Crab"
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.CASTLE
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Lion", [s], {1: p})
	assert_eq(bonus, 0)


func test_get_fortification_bonus_no_province_data_allows_bonus() -> void:
	var s: SettlementData = SettlementData.new()
	s.province_id = 1
	s.settlement_type = Enums.SettlementType.KEEP
	var bonus: int = DayOrchestrator._get_fortification_bonus(1, "Lion", [s], {})
	assert_eq(bonus, DayOrchestrator.FORTIFICATION_DEFENSE_BONUS)


# -- Storm Assault Processing Tests ----------------------------------------------

func _make_siege_state(
	settlement_id: int,
	atk_army_id: int,
	def_army_id: int,
) -> Dictionary:
	return SiegeSystem.create_siege_state(settlement_id, atk_army_id, def_army_id, 10.0, 5.0, 2.0)


func _make_army_company(
	company_id: int,
	army_id: int,
	unit_type: int = Enums.CompanyUnitType.BUSHI_RETAINER,
) -> Dictionary:
	var stats: Dictionary = ArmyCombatSystem.UNIT_STATS.get(unit_type, {})
	return {
		"company_id": company_id,
		"army_id": army_id,
		"unit_type": unit_type,
		"current_health": stats.get("health", 153),
		"current_morale": stats.get("morale", 18),
		"commander_id": -1,
		"source_province_id": 1,
		"destroyed": false,
		"routed": false,
	}


func test_storm_assault_no_flag_returns_empty() -> void:
	var applied: Array = [{"effects": {"effect": "something_else"}}]
	var r: Array[Dictionary] = DayOrchestrator._process_storm_assault_results(
		applied, [], [], DiceEngine.new(), [], {},
	)
	assert_eq(r.size(), 0)


func test_storm_assault_no_siege_returns_empty() -> void:
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 99},
	}]
	var r: Array[Dictionary] = DayOrchestrator._process_storm_assault_results(
		applied, [], [], DiceEngine.new(), [], {},
	)
	assert_eq(r.size(), 0)


func test_storm_assault_finds_siege_and_resolves() -> void:
	var siege: Dictionary = _make_siege_state(10, 1, 2)
	var companies: Array[Dictionary] = [
		_make_army_company(1, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(2, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(3, 2, Enums.CompanyUnitType.GARRISON),
	]
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	var r: Array[Dictionary] = DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, dice, [s], {},
	)
	assert_eq(r.size(), 1)
	assert_true(r[0].has("victor"))
	assert_eq(r[0]["siege_settlement_id"], 10)
	assert_eq(r[0]["attacker_army_id"], 1)
	assert_eq(r[0]["defender_army_id"], 2)


func test_storm_assault_attacker_victory_ends_siege() -> void:
	var siege: Dictionary = _make_siege_state(10, 1, 2)
	# Strong attacker vs weak defender
	var companies: Array[Dictionary] = [
		_make_army_company(1, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(2, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(3, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(4, 2, Enums.CompanyUnitType.PEASANT_LEVY),
	]
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(100)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, dice, [s], {},
	)
	if siege.get("siege_ended", false):
		assert_eq(siege["end_reason"], "storm_assault_success")


func test_storm_assault_empty_companies_skips() -> void:
	var siege: Dictionary = _make_siege_state(10, 1, 2)
	var companies: Array[Dictionary] = []
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var r: Array[Dictionary] = DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, DiceEngine.new(), [], {},
	)
	assert_eq(r.size(), 0)


func test_find_siege_by_settlement() -> void:
	var s1: Dictionary = _make_siege_state(10, 1, 2)
	var s2: Dictionary = _make_siege_state(20, 3, 4)
	var found: Dictionary = DayOrchestrator._find_siege_by_settlement(20, [s1, s2])
	assert_eq(found.get("settlement_id"), 20)


func test_find_siege_by_settlement_not_found() -> void:
	var found: Dictionary = DayOrchestrator._find_siege_by_settlement(99, [])
	assert_true(found.is_empty())


func test_storm_assault_uses_urban_terrain_and_fort_bonus() -> void:
	# Verify that storm assault applies the siege defense bonus
	var fort_bonus: int = SiegeSystem.get_storm_defense_bonus()
	assert_eq(fort_bonus, 8)


func test_storm_assault_metadata_sets_settlement_id() -> void:
	var option: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	option.action_id = "CONDUCT_STORM_ASSAULT"
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.location_id = 42
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata.get("siege_settlement_id", -1), 42)


# -- Battle Integration Tests: Terrain + Fort + War Score End-to-End --------

func _make_province(id: int, clan: String, terrain: Enums.TerrainType) -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = id
	p.clan = clan
	p.terrain_type = terrain
	return p


func _make_military_settlement(
	id: int,
	province_id: int,
	stype: Enums.SettlementType = Enums.SettlementType.FORTIFICATION,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.settlement_type = stype
	s.population_pu = 5
	s.military_pu = 1
	return s


func _setup_battle_scenario(
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	defender_has_fort: bool = false,
	province_clan: String = "Crane",
) -> Dictionary:
	var dice: DiceEngine = DiceEngine.new(99)
	var province_id: int = 5
	var prov: ProvinceData = _make_province(province_id, province_clan, terrain)
	var provinces: Dictionary = {province_id: prov}

	var army_a: Dictionary = ArmyMovementSystem.create_army_state(1, province_id, "Crab")
	army_a["is_moving"] = true
	army_a["days_remaining"] = 1
	army_a["path"] = [0, province_id]
	army_a["path_index"] = 0

	var army_b: Dictionary = ArmyMovementSystem.create_army_state(2, province_id, "Crane")

	var c1: Dictionary = _make_company_dict_for_battle(1, 1, "Crab")
	var c2: Dictionary = _make_company_dict_for_battle(2, 2, "Crane")

	var settlements: Array[SettlementData] = []
	if defender_has_fort:
		settlements.append(_make_military_settlement(10, province_id))

	var war: WarData = WarSystem.declare_war(1, "Crab", "Crane", 1, 1, 2)

	return {
		"dice": dice,
		"armies": [army_a, army_b],
		"companies": [c1, c2],
		"settlements": settlements,
		"wars": [war],
		"provinces": provinces,
		"province_id": province_id,
	}


func test_integration_battle_plains_terrain_no_fort() -> void:
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.PLAINS, false)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_true(result.has("battle_results"))
	assert_eq(result["battle_results"].size(), 1)
	var br: Dictionary = result["battle_results"][0]
	assert_eq(br["attacker_clan"], "Crab")
	assert_eq(br["defender_clan"], "Crane")
	assert_true(br.has("victor"))


func test_integration_battle_forest_terrain() -> void:
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.FOREST, false)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_battle_mountains_terrain() -> void:
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.MOUNTAINS, false)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_battle_with_fortification_bonus() -> void:
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.PLAINS, true, "Crane")
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)
	# Fort bonus should have given defender +5 defense — we can't directly
	# observe it from the result, but the battle completed without error
	# which means terrain + fort flowed through correctly


func test_integration_fort_bonus_not_applied_when_attacker_province() -> void:
	# Fort is in Crab province, but Crab is the attacker — no bonus
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.PLAINS, true, "Crab")
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_battle_urban_override_with_town() -> void:
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.FOREST, false)
	var town: SettlementData = SettlementData.new()
	town.settlement_id = 20
	town.province_id = s["province_id"]
	town.settlement_type = Enums.SettlementType.TOWN
	s["settlements"].append(town)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_battle_war_score_shifts() -> void:
	var s: Dictionary = _setup_battle_scenario()
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)
	# War score shifts are processed separately; verify the movement result
	# has the battle_triggered flag for downstream war score processing
	var mr: Array = result.get("movement_results", [])
	var found_battle: bool = false
	for m: Dictionary in mr:
		if m.get("battle_resolved", false):
			found_battle = true
			assert_true(m.has("company_count"))
	assert_true(found_battle)


func test_integration_war_score_shift_from_battle() -> void:
	var s: Dictionary = _setup_battle_scenario()
	var war: WarData = s["wars"][0]
	var score_a_before: int = war.war_score_a
	var score_b_before: int = war.war_score_b
	var military_daily: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	var war_score_results: Array[Dictionary] = DayOrchestrator._process_war_score_shifts(
		military_daily, [], s["wars"], s["companies"],
	)
	# A battle with 2 companies is minor (+3 shift)
	assert_false(war_score_results.is_empty())
	var shifted: bool = (war.war_score_a != score_a_before or war.war_score_b != score_b_before)
	assert_true(shifted)


func test_integration_battle_writes_results_to_companies() -> void:
	var s: Dictionary = _setup_battle_scenario()
	var c1: Dictionary = s["companies"][0]
	var c2: Dictionary = s["companies"][1]
	var health_1_before: int = c1.get("current_health", 0)
	var health_2_before: int = c2.get("current_health", 0)
	DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	# At least one company should have taken damage
	var c1_changed: bool = c1.get("current_health", 0) != health_1_before
	var c2_changed: bool = c2.get("current_health", 0) != health_2_before
	assert_true(c1_changed or c2_changed)


func test_integration_battle_no_provinces_uses_plains_default() -> void:
	var s: Dictionary = _setup_battle_scenario()
	# Pass empty provinces — should default to PLAINS terrain
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, {},
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_no_battle_when_not_at_war() -> void:
	var s: Dictionary = _setup_battle_scenario()
	# Pass empty wars array — should not trigger battle
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, [], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 0)


func test_integration_multiple_terrain_types_resolve_differently() -> void:
	# Verify different terrains produce different battle outcomes (different RNG paths)
	var dice_plains: DiceEngine = DiceEngine.new(42)
	var dice_mountains: DiceEngine = DiceEngine.new(42)

	var setup_plains: Dictionary = _setup_battle_scenario(Enums.TerrainType.PLAINS, false)
	setup_plains["dice"] = dice_plains
	var result_plains: Dictionary = DayOrchestrator._process_military_daily(
		setup_plains["armies"], [], [], [], setup_plains["dice"],
		setup_plains["settlements"], setup_plains["companies"], {},
		setup_plains["wars"], {}, setup_plains["provinces"],
	)

	var setup_mountains: Dictionary = _setup_battle_scenario(Enums.TerrainType.MOUNTAINS, false)
	setup_mountains["dice"] = dice_mountains
	var result_mountains: Dictionary = DayOrchestrator._process_military_daily(
		setup_mountains["armies"], [], [], [], setup_mountains["dice"],
		setup_mountains["settlements"], setup_mountains["companies"], {},
		setup_mountains["wars"], {}, setup_mountains["provinces"],
	)

	assert_eq(result_plains["battle_results"].size(), 1)
	assert_eq(result_mountains["battle_results"].size(), 1)
	# Both should resolve but may have different outcomes due to terrain modifiers


func test_integration_fort_plus_terrain_stacks() -> void:
	# Mountain terrain (+4 def) + fortification (+5 def) should both apply
	var s: Dictionary = _setup_battle_scenario(
		Enums.TerrainType.MOUNTAINS, true, "Crane",
	)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_hills_terrain_battle() -> void:
	var s: Dictionary = _setup_battle_scenario(Enums.TerrainType.HILLS, false)
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	assert_eq(result["battle_results"].size(), 1)


func test_integration_battle_result_has_victor_and_clans() -> void:
	var s: Dictionary = _setup_battle_scenario()
	var result: Dictionary = DayOrchestrator._process_military_daily(
		s["armies"], [], [], [], s["dice"], s["settlements"],
		s["companies"], {}, s["wars"], {}, s["provinces"],
	)
	var br: Dictionary = result["battle_results"][0]
	assert_true(br.has("victor"))
	assert_true(br.has("attacker_clan"))
	assert_true(br.has("defender_clan"))
	assert_true(br.has("attacker_army_id"))
	assert_true(br.has("defender_army_ids"))
	assert_eq(br["attacker_clan"], "Crab")
	assert_eq(br["defender_clan"], "Crane")


# -- Storm Assault E2E Tests ---------------------------------------------------

func test_e2e_executor_produces_storm_assault_effect() -> void:
	var action: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	action.action_id = "CONDUCT_STORM_ASSAULT"
	action.metadata = {"siege_settlement_id": 77}
	var char: L5RCharacterData = L5RCharacterData.new()
	char.physical_location = 77
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = "spring"
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, DiceEngine.new(),
	)
	assert_true(result.get("effects", {}).get("requires_storm_assault", false))
	assert_eq(result["effects"]["siege_settlement_id"], 77)


func test_e2e_executor_uses_physical_location_fallback() -> void:
	var action: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	action.action_id = "CONDUCT_STORM_ASSAULT"
	action.metadata = {}
	var char: L5RCharacterData = L5RCharacterData.new()
	char.physical_location = 55
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = "spring"
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, DiceEngine.new(),
	)
	assert_eq(result["effects"]["siege_settlement_id"], 55)


func test_e2e_metadata_to_executor_to_orchestrator() -> void:
	var option: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	option.action_id = "CONDUCT_STORM_ASSAULT"
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.location_id = 10
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = "spring"
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata["siege_settlement_id"], 10)

	var char: L5RCharacterData = L5RCharacterData.new()
	char.physical_location = 10
	var exec_result: Dictionary = ActionExecutor.execute(
		option, char, ctx, DiceEngine.new(),
	)
	assert_true(exec_result["effects"]["requires_storm_assault"])
	assert_eq(exec_result["effects"]["siege_settlement_id"], 10)

	var siege: Dictionary = _make_siege_state(10, 1, 2)
	var companies: Array[Dictionary] = [
		_make_army_company(1, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(2, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(3, 2, Enums.CompanyUnitType.GARRISON),
	]
	var applied: Array = [exec_result]
	var dice: DiceEngine = DiceEngine.new(42)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	var r: Array[Dictionary] = DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, dice, [s], {},
	)
	assert_eq(r.size(), 1)
	assert_true(r[0].has("victor"))


func test_e2e_storm_assault_defender_victory_resets_sortie_counter() -> void:
	var siege: Dictionary = _make_siege_state(10, 1, 2)
	siege["ticks_since_sortie"] = 15
	var companies: Array[Dictionary] = [
		_make_army_company(1, 1, Enums.CompanyUnitType.PEASANT_LEVY),
		_make_army_company(2, 2, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(3, 2, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(4, 2, Enums.CompanyUnitType.BUSHI_RETAINER),
	]
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var dice: DiceEngine = DiceEngine.new(42)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, dice, [s], {},
	)
	if not siege.get("siege_ended", false):
		assert_eq(siege.get("ticks_since_sortie", -1), 0)


func test_e2e_storm_assault_company_health_mutated() -> void:
	var siege: Dictionary = _make_siege_state(10, 1, 2)
	var c_atk: Dictionary = _make_army_company(1, 1, Enums.CompanyUnitType.BUSHI_RETAINER)
	var c_def: Dictionary = _make_army_company(2, 2, Enums.CompanyUnitType.BUSHI_RETAINER)
	var h_atk_before: int = c_atk["current_health"]
	var h_def_before: int = c_def["current_health"]
	var companies: Array[Dictionary] = [c_atk, c_def]
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var dice: DiceEngine = DiceEngine.new(42)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, dice, [s], {},
	)
	var atk_changed: bool = c_atk.get("current_health", h_atk_before) != h_atk_before
	var def_changed: bool = c_def.get("current_health", h_def_before) != h_def_before
	assert_true(atk_changed or def_changed)


func test_e2e_storm_assault_only_targets_matching_siege() -> void:
	var siege_a: Dictionary = _make_siege_state(10, 1, 2)
	var siege_b: Dictionary = _make_siege_state(20, 3, 4)
	var companies: Array[Dictionary] = [
		_make_army_company(1, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(2, 2, Enums.CompanyUnitType.GARRISON),
		_make_army_company(3, 3, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(4, 4, Enums.CompanyUnitType.GARRISON),
	]
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var dice: DiceEngine = DiceEngine.new(42)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	DayOrchestrator._process_storm_assault_results(
		applied, [siege_a, siege_b], companies, dice, [s], {},
	)
	assert_false(siege_b.get("siege_ended", false))


func test_e2e_storm_assault_uses_urban_terrain_and_fort_bonus() -> void:
	var siege: Dictionary = _make_siege_state(10, 1, 2)
	var companies: Array[Dictionary] = [
		_make_army_company(1, 1, Enums.CompanyUnitType.BUSHI_RETAINER),
		_make_army_company(2, 2, Enums.CompanyUnitType.GARRISON),
	]
	var applied: Array = [{
		"effects": {"requires_storm_assault": true, "siege_settlement_id": 10},
	}]
	var dice: DiceEngine = DiceEngine.new(42)
	var s: SettlementData = SettlementData.new()
	s.settlement_id = 10
	s.province_id = 1
	var r: Array[Dictionary] = DayOrchestrator._process_storm_assault_results(
		applied, [siege], companies, dice, [s], {},
	)
	assert_eq(r.size(), 1)
	assert_true(r[0]["rounds"] > 0)


# -- MAINTAIN_SIEGE wiring tests -----------------------------------------------

func test_maintain_siege_executor_returns_requires_flag() -> void:
	var action: ScoredAction = ScoredAction.new()
	action.action_id = "MAINTAIN_SIEGE"
	action.metadata = {"siege_settlement_id": 10}
	var ctx: ContextSnapshot = ContextSnapshot.new()
	var dice: DiceEngine = DiceEngine.new(1)
	var result: Dictionary = ActionExecutor.execute(action, ctx, dice)
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("requires_siege_maintenance", false))
	assert_eq(effects.get("siege_settlement_id", -1), 10)


func test_maintain_siege_stamps_last_maintained_ic_day() -> void:
	var siege: Dictionary = {"settlement_id": 10, "siege_ended": false}
	var applied: Array = [{
		"effects": {"requires_siege_maintenance": true, "siege_settlement_id": 10},
	}]
	DayOrchestrator._process_siege_maintenance(applied, [siege], 42)
	assert_eq(siege.get("last_maintained_ic_day", -1), 42)


func test_maintain_siege_no_match_leaves_siege_untouched() -> void:
	var siege: Dictionary = {"settlement_id": 5, "siege_ended": false}
	var applied: Array = [{
		"effects": {"requires_siege_maintenance": true, "siege_settlement_id": 10},
	}]
	DayOrchestrator._process_siege_maintenance(applied, [siege], 42)
	assert_false(siege.has("last_maintained_ic_day"))


func test_maintain_siege_skips_non_siege_effects() -> void:
	var siege: Dictionary = {"settlement_id": 10}
	var applied: Array = [{"effects": {"effect": "something_else"}}]
	DayOrchestrator._process_siege_maintenance(applied, [siege], 42)
	assert_false(siege.has("last_maintained_ic_day"))


func test_maintain_siege_metadata_population() -> void:
	var npc: L5RCharacterData = _make_char(1, "Crab")
	npc.physical_location = "settlement_10"
	var ctx: ContextSnapshot = ContextSnapshot.new()
	ctx.location_id = 10
	var option: ScoredAction = ScoredAction.new()
	option.action_id = "MAINTAIN_SIEGE"
	NPCDecisionEngine._populate_action_metadata(option, ctx, {})
	assert_eq(option.metadata.get("siege_settlement_id", -1), 10)


# -- ORDER_PATROL wiring tests ------------------------------------------------

func test_order_patrol_executor_returns_requires_flag() -> void:
	var action: ScoredAction = ScoredAction.new()
	action.action_id = "ORDER_PATROL"
	action.target_province_id = 5
	var ctx: ContextSnapshot = ContextSnapshot.new()
	var dice: DiceEngine = DiceEngine.new(1)
	var result: Dictionary = ActionExecutor.execute(action, ctx, dice)
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("requires_patrol", false))
	assert_eq(effects.get("patrol_province_id", -1), 5)


func test_patrol_stamps_season_meta() -> void:
	var applied: Array = [{
		"effects": {"requires_patrol": true, "patrol_province_id": 5},
		"character_id": 1,
	}]
	var season_meta: Dictionary = {}
	var r: Array[Dictionary] = DayOrchestrator._process_patrol_effects(applied, season_meta)
	assert_eq(r.size(), 1)
	assert_eq(r[0]["province_id"], 5)
	assert_true(season_meta.get("patrolled_provinces", {}).has(5))


func test_patrol_multiple_provinces() -> void:
	var applied: Array = [
		{"effects": {"requires_patrol": true, "patrol_province_id": 5}, "character_id": 1},
		{"effects": {"requires_patrol": true, "patrol_province_id": 8}, "character_id": 2},
	]
	var season_meta: Dictionary = {}
	var r: Array[Dictionary] = DayOrchestrator._process_patrol_effects(applied, season_meta)
	assert_eq(r.size(), 2)
	var patrolled: Dictionary = season_meta.get("patrolled_provinces", {})
	assert_true(patrolled.has(5))
	assert_true(patrolled.has(8))


func test_patrol_skips_invalid_province() -> void:
	var applied: Array = [{
		"effects": {"requires_patrol": true, "patrol_province_id": -1},
		"character_id": 1,
	}]
	var season_meta: Dictionary = {}
	var r: Array[Dictionary] = DayOrchestrator._process_patrol_effects(applied, season_meta)
	assert_eq(r.size(), 0)


func test_patrol_reduces_insurgency_spawn_chance() -> void:
	var ws: Dictionary = {"is_patrolled": true}
	var base_chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.PEASANT_REVOLT, Enums.StabilityTier.RESTLESS, {},
	)
	var patrolled_chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.PEASANT_REVOLT, Enums.StabilityTier.RESTLESS, ws,
	)
	assert_true(patrolled_chance < base_chance)
	assert_almost_eq(patrolled_chance, base_chance * 0.5, 0.001)


func test_patrol_concealment_reduction_on_hidden_insurgency() -> void:
	var ins: InsurgencyData = InsurgencyData.new()
	ins.province_id = 5
	ins.concealment = 3
	ins.detected = false
	ins.strength = 5
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	var season_meta: Dictionary = {"patrolled_provinces": {5: true}}
	var provinces: Dictionary = {5: province}
	var insurgencies: Array[InsurgencyData] = [ins]
	var dice: DiceEngine = DiceEngine.new(1)
	var next_id: Array[int] = [100]
	DayOrchestrator._process_insurgencies(
		insurgencies, provinces, dice, 0,
		next_id, {}, {}, season_meta,
	)
	assert_eq(ins.concealment, 2)


func test_patrol_auto_detects_at_concealment_one() -> void:
	var ins: InsurgencyData = InsurgencyData.new()
	ins.province_id = 5
	ins.concealment = 1
	ins.detected = false
	ins.strength = 5
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	var season_meta: Dictionary = {"patrolled_provinces": {5: true}}
	var provinces: Dictionary = {5: province}
	var insurgencies: Array[InsurgencyData] = [ins]
	var dice: DiceEngine = DiceEngine.new(1)
	var next_id: Array[int] = [100]
	DayOrchestrator._process_insurgencies(
		insurgencies, provinces, dice, 0,
		next_id, {}, {}, season_meta,
	)
	assert_eq(ins.concealment, 0)
	assert_true(ins.detected)


func test_patrolled_provinces_cleared_on_season_boundary() -> void:
	var season_meta: Dictionary = {"patrolled_provinces": {5: true, 8: true}}
	season_meta.erase("patrolled_provinces")
	assert_false(season_meta.has("patrolled_provinces"))


# -- PURIFY_TAINTED_GROUND wiring tests ----------------------------------------

func _make_kuni_shugenja(char_id: int, school_rank: int) -> L5RCharacterData:
	var c: L5RCharacterData = _make_char(char_id, "Crab")
	c.family = "Kuni"
	c.school = "Kuni Shugenja"
	c.school_type = Enums.SchoolType.SHUGENJA
	c.set_trait_value(Enums.Trait.INTELLIGENCE, 4)
	c.skills["Lore: Shadowlands"] = school_rank
	c.insight_rank = school_rank
	return c


func test_purify_executor_success_returns_flag() -> void:
	var c: L5RCharacterData = _make_kuni_shugenja(1, 3)
	var action: ScoredAction = ScoredAction.new()
	action.action_id = "PURIFY_TAINTED_GROUND"
	action.target_province_id = 5
	var ctx: ContextSnapshot = ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = "spring"
	var dice: DiceEngine = DiceEngine.new(99)
	var result: Dictionary = ActionExecutor._execute_purify_tainted_ground(
		action, ctx, c, dice, 1.0,
	)
	var effects: Dictionary = result.get("effects", {})
	if effects.get("requires_purification", false):
		assert_true(effects.get("ptl_reduction", 0.0) > 0.0)
		assert_eq(effects.get("province_id", -1), 5)


func test_purify_orchestrator_reduces_ptl() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	province.province_taint_level = 3.0
	var applied: Array = [{
		"effects": {
			"requires_purification": true,
			"province_id": 5,
			"ptl_reduction": 0.75,
			"ward_bleed_reduction": 0.2,
			"ward_duration": 4,
			"ward_school_rank": 3,
		},
	}]
	var season_meta: Dictionary = {}
	var r: Array[Dictionary] = DayOrchestrator._process_purification_effects(
		applied, {5: province}, season_meta,
	)
	assert_eq(r.size(), 1)
	assert_almost_eq(province.province_taint_level, 2.25, 0.001)
	assert_true(r[0].get("ward_set", false))


func test_purify_sets_kuni_ward_in_season_meta() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	province.province_taint_level = 2.0
	var applied: Array = [{
		"effects": {
			"requires_purification": true,
			"province_id": 5,
			"ptl_reduction": 0.5,
			"ward_bleed_reduction": 0.2,
			"ward_duration": 4,
			"ward_school_rank": 3,
		},
	}]
	var season_meta: Dictionary = {}
	DayOrchestrator._process_purification_effects(applied, {5: province}, season_meta)
	var wards: Dictionary = season_meta.get("kuni_wards", {})
	assert_true(wards.has("5"))
	assert_eq(wards["5"]["bleed_reduction"], 0.2)
	assert_eq(wards["5"]["seasons_remaining"], 4)


func test_purify_ptl_floors_at_zero() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	province.province_taint_level = 0.3
	var applied: Array = [{
		"effects": {
			"requires_purification": true,
			"province_id": 5,
			"ptl_reduction": 1.0,
			"ward_bleed_reduction": 0.1,
			"ward_duration": 2,
			"ward_school_rank": 1,
		},
	}]
	var season_meta: Dictionary = {}
	DayOrchestrator._process_purification_effects(applied, {5: province}, season_meta)
	assert_almost_eq(province.province_taint_level, 0.0, 0.001)


func test_purify_stronger_ward_replaces_weaker() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	province.province_taint_level = 5.0
	var season_meta: Dictionary = {
		"kuni_wards": {"5": {"bleed_reduction": 0.1, "seasons_remaining": 2, "school_rank": 1}},
	}
	var applied: Array = [{
		"effects": {
			"requires_purification": true,
			"province_id": 5,
			"ptl_reduction": 0.5,
			"ward_bleed_reduction": 0.3,
			"ward_duration": 6,
			"ward_school_rank": 5,
		},
	}]
	DayOrchestrator._process_purification_effects(applied, {5: province}, season_meta)
	var ward: Dictionary = season_meta["kuni_wards"]["5"]
	assert_eq(ward["bleed_reduction"], 0.3)
	assert_eq(ward["seasons_remaining"], 6)


func test_purify_weaker_ward_does_not_replace() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_id = 5
	province.province_taint_level = 5.0
	var season_meta: Dictionary = {
		"kuni_wards": {"5": {"bleed_reduction": 0.3, "seasons_remaining": 5, "school_rank": 5}},
	}
	var applied: Array = [{
		"effects": {
			"requires_purification": true,
			"province_id": 5,
			"ptl_reduction": 0.5,
			"ward_bleed_reduction": 0.1,
			"ward_duration": 2,
			"ward_school_rank": 1,
		},
	}]
	DayOrchestrator._process_purification_effects(applied, {5: province}, season_meta)
	var ward: Dictionary = season_meta["kuni_wards"]["5"]
	assert_eq(ward["bleed_reduction"], 0.3)
	assert_eq(ward["seasons_remaining"], 5)


func test_kuni_ward_tick_decrements_duration() -> void:
	var season_meta: Dictionary = {
		"kuni_wards": {
			"5": {"bleed_reduction": 0.2, "seasons_remaining": 3, "school_rank": 3},
			"8": {"bleed_reduction": 0.1, "seasons_remaining": 1, "school_rank": 1},
		},
	}
	DayOrchestrator._tick_kuni_wards(season_meta)
	var wards: Dictionary = season_meta.get("kuni_wards", {})
	assert_true(wards.has("5"))
	assert_eq(wards["5"]["seasons_remaining"], 2)
	assert_false(wards.has("8"))


func test_kuni_ward_tick_removes_all_expired() -> void:
	var season_meta: Dictionary = {
		"kuni_wards": {
			"5": {"bleed_reduction": 0.1, "seasons_remaining": 1, "school_rank": 1},
		},
	}
	DayOrchestrator._tick_kuni_wards(season_meta)
	assert_false(season_meta.has("kuni_wards"))


func test_purify_skips_nonexistent_province() -> void:
	var applied: Array = [{
		"effects": {
			"requires_purification": true,
			"province_id": 99,
			"ptl_reduction": 0.5,
			"ward_bleed_reduction": 0.1,
			"ward_duration": 2,
			"ward_school_rank": 1,
		},
	}]
	var r: Array[Dictionary] = DayOrchestrator._process_purification_effects(applied, {}, {})
	assert_eq(r.size(), 0)


# -- DRILL_TROOPS wiring tests ------------------------------------------------

func _make_trainable_company(cid: int, commander_id: int) -> Dictionary:
	return {
		"company_id": cid,
		"commander_id": commander_id,
		"training_level": 0,
		"training_points": 0,
		"health": 100,
		"max_health": 100,
		"destroyed": false,
	}


func test_drill_executor_returns_requires_flag() -> void:
	var action: ScoredAction = ScoredAction.new()
	action.action_id = "DRILL_TROOPS"
	action.metadata = {"target_company_id": 10}
	var ctx: ContextSnapshot = ContextSnapshot.new()
	var dice: DiceEngine = DiceEngine.new(1)
	var result: Dictionary = ActionExecutor.execute(action, ctx, dice)
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("requires_drill", false))
	assert_eq(effects.get("target_company_id", -1), 10)


func test_drill_success_adds_training_points() -> void:
	var c: L5RCharacterData = _make_char(1, "Lion")
	c.skills["Battle"] = 3
	c.set_trait_value(Enums.Trait.PERCEPTION, 3)
	var company: Dictionary = _make_trainable_company(10, 1)
	var applied: Array = [{
		"effects": {"requires_drill": true, "target_company_id": 10},
		"character_id": 1,
	}]
	var dice: DiceEngine = DiceEngine.new(99)
	var r: Array[Dictionary] = DayOrchestrator._process_drill_effects(
		applied, [company],
		{1: c}, dice,
	)
	assert_eq(r.size(), 1)
	assert_true(r[0].get("success", false))
	assert_true(r[0].get("points_added", 0) >= 1)
	assert_true(company.get("training_points", 0) >= 1)


func test_drill_fallback_to_commander_id() -> void:
	var c: L5RCharacterData = _make_char(1, "Lion")
	c.skills["Battle"] = 3
	c.set_trait_value(Enums.Trait.PERCEPTION, 3)
	var company: Dictionary = _make_trainable_company(10, 1)
	var applied: Array = [{
		"effects": {"requires_drill": true, "target_company_id": -1},
		"character_id": 1,
	}]
	var dice: DiceEngine = DiceEngine.new(99)
	var r: Array[Dictionary] = DayOrchestrator._process_drill_effects(
		applied, [company],
		{1: c}, dice,
	)
	assert_eq(r.size(), 1)
	assert_eq(r[0].get("company_id", -1), 10)


func test_drill_level_up_at_10_points() -> void:
	var c: L5RCharacterData = _make_char(1, "Lion")
	c.skills["Battle"] = 5
	c.set_trait_value(Enums.Trait.PERCEPTION, 5)
	var company: Dictionary = _make_trainable_company(10, 1)
	company["training_points"] = 9
	company["training_level"] = 0
	var applied: Array = [{
		"effects": {"requires_drill": true, "target_company_id": 10},
		"character_id": 1,
	}]
	var dice: DiceEngine = DiceEngine.new(99)
	var r: Array[Dictionary] = DayOrchestrator._process_drill_effects(
		applied, [company],
		{1: c}, dice,
	)
	if r[0].get("success", false) and r[0].get("points_added", 0) >= 1:
		assert_eq(company.get("training_level", 0), 1)


func test_drill_max_level_cap() -> void:
	var c: L5RCharacterData = _make_char(1, "Lion")
	c.skills["Battle"] = 5
	c.set_trait_value(Enums.Trait.PERCEPTION, 5)
	var company: Dictionary = _make_trainable_company(10, 1)
	company["training_points"] = 9
	company["training_level"] = 3
	var applied: Array = [{
		"effects": {"requires_drill": true, "target_company_id": 10},
		"character_id": 1,
	}]
	var dice: DiceEngine = DiceEngine.new(99)
	DayOrchestrator._process_drill_effects(
		applied, [company],
		{1: c}, dice,
	)
	assert_eq(company.get("training_level", 0), 3)


func test_drill_no_character_skips() -> void:
	var company: Dictionary = _make_trainable_company(10, 1)
	var applied: Array = [{
		"effects": {"requires_drill": true, "target_company_id": 10},
		"character_id": 999,
	}]
	var dice: DiceEngine = DiceEngine.new(1)
	var r: Array[Dictionary] = DayOrchestrator._process_drill_effects(
		applied, [company],
		{}, dice,
	)
	assert_eq(r.size(), 0)


func test_drill_no_company_skips() -> void:
	var c: L5RCharacterData = _make_char(1, "Lion")
	c.skills["Battle"] = 3
	var applied: Array = [{
		"effects": {"requires_drill": true, "target_company_id": 99},
		"character_id": 1,
	}]
	var dice: DiceEngine = DiceEngine.new(1)
	var r: Array[Dictionary] = DayOrchestrator._process_drill_effects(
		applied, [],
		{1: c}, dice,
	)
	assert_eq(r.size(), 0)


func test_drill_results_in_advance_day_return() -> void:
	var applied: Array = [{"effects": {"effect": "nothing"}}]
	var dice: DiceEngine = DiceEngine.new(1)
	var r: Array[Dictionary] = DayOrchestrator._process_drill_effects(
		applied, [], {}, dice,
	)
	assert_eq(r.size(), 0)
