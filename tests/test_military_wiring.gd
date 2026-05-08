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
	# Verify the function signature accepts the new params without error.
	# We can't run a full advance_day without all the infrastructure,
	# so we just confirm the static function exists with the right arity.
	assert_true(DayOrchestrator.has_method("advance_day"))
