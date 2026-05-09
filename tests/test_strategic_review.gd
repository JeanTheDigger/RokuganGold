extends GutTest


func _make_lord(id: int = 1, virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.CHUGI) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Crane"
	c.lord_id = -1
	c.status = 6.0
	c.bushido_virtue = virtue
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_vassal(id: int, lord_id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Crane"
	c.lord_id = lord_id
	c.status = 3.0
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	return c


# -- Basic Review Flow ---------------------------------------------------------

func test_no_change_when_nothing_to_do() -> void:
	var lord := _make_lord()
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["directive"], StrategicReview.Directive.NO_CHANGE)


func test_returns_multiple_directives() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.JIN)
	var v1 := _make_vassal(10, 1)
	var v2 := _make_vassal(11, 1)
	var vassals: Array[L5RCharacterData] = [v1, v2]
	var objectives_map: Dictionary = {
		10: {"primary": {"status": "COMPLETED"}},
		11: {"primary": {"status": "COMPLETED"}},
	}
	var world_state: Dictionary = {
		"last_court_season": -1,
		"current_season": TimeSystem.Season.WINTER,
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	assert_gt(results.size(), 1)


# -- Orphaned Vassal Resolution ------------------------------------------------

func test_resolves_orphaned_vassals_confirm_for_chugi() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.CHUGI)
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "BREAK_ALLIANCE", "status": "ORPHANED", "assigning_lord_id": 1}},
	}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var orphan_result: Dictionary = {}
	for r: Dictionary in results:
		if r.get("decision", "") == "CONFIRM":
			orphan_result = r
			break

	assert_false(orphan_result.is_empty())
	assert_eq(orphan_result["vassal_id"], 10)
	assert_eq(orphan_result["decision"], "CONFIRM")


func test_resolves_orphaned_vassals_cancel_for_jin() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.JIN)
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "BREAK_ALLIANCE", "status": "ORPHANED", "assigning_lord_id": 1}},
	}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var orphan_result: Dictionary = {}
	for r: Dictionary in results:
		if r.get("decision", "") == "CANCEL":
			orphan_result = r
			break

	assert_false(orphan_result.is_empty())
	assert_eq(orphan_result["vassal_id"], 10)


func test_resolves_orphaned_vassals_modify_for_gi() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.GI)
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "ISOLATE_CHARACTER", "status": "ORPHANED", "assigning_lord_id": 1}},
	}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var orphan_result: Dictionary = {}
	for r: Dictionary in results:
		if r.get("decision", "") == "MODIFY":
			orphan_result = r
			break

	assert_false(orphan_result.is_empty())


# -- Call Court ----------------------------------------------------------------

func test_call_court_in_winter_with_vassals() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.REI)
	var vassals: Array[L5RCharacterData] = []
	for i: int in range(5):
		vassals.append(_make_vassal(10 + i, 1))
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": -1,
		"current_season": TimeSystem.Season.WINTER,
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var court_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.CALL_COURT:
			court_found = true
			break
	assert_true(court_found)


func test_no_court_if_already_held_this_season() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.REI)
	var vassals: Array[L5RCharacterData] = []
	for i: int in range(10):
		vassals.append(_make_vassal(10 + i, 1))
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": TimeSystem.Season.WINTER,
		"current_season": TimeSystem.Season.WINTER,
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.CALL_COURT)


func test_court_triggered_by_crises() -> void:
	var lord := _make_lord()
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": -1,
		"current_season": TimeSystem.Season.SUMMER,
		"active_crises": [{"id": 1}, {"id": 2}, {"id": 3}],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var court_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.CALL_COURT:
			court_found = true
			break
	assert_true(court_found)


# -- Tax Adjustment ------------------------------------------------------------

func test_tax_lower_when_low_stability_high_treasury() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.JIN)
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"avg_province_stability": 25.0,
		"treasury_ratio": 2.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var tax_found: Dictionary = {}
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.ADJUST_TAX:
			tax_found = r
			break
	assert_false(tax_found.is_empty())
	assert_eq(tax_found["direction"], "LOWER")


func test_tax_raise_when_low_treasury_high_stability() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.MEIYO)
	lord.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"avg_province_stability": 70.0,
		"treasury_ratio": 0.8,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var tax_found: Dictionary = {}
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.ADJUST_TAX:
			tax_found = r
			break
	assert_false(tax_found.is_empty())
	assert_eq(tax_found["direction"], "RAISE")


func test_no_tax_change_when_balanced() -> void:
	var lord := _make_lord()
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.ADJUST_TAX)


# -- War Readiness -------------------------------------------------------------

func test_war_readiness_with_active_wars() -> void:
	var lord := _make_lord()
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"active_wars": [{"id": 1}],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var war_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.WAR_READINESS:
			war_found = true
			break
	assert_true(war_found)


func test_war_readiness_yu_virtue_with_escalation() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.YU)
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"active_wars": [],
		"escalating_conflicts": [{"id": 1}],
		"military_readiness": 0.9,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var war_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.WAR_READINESS:
			war_found = true
			break
	assert_true(war_found)


func test_no_war_readiness_without_threats() -> void:
	var lord := _make_lord()
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.WAR_READINESS)


# -- Seek Peace ----------------------------------------------------------------

func test_seek_peace_jin_lord_with_wars() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.JIN)
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"active_wars": [{"id": 1}],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"longest_war_duration_seasons": 1,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var peace_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.SEEK_PEACE:
			peace_found = true
			break
	assert_true(peace_found)


func test_no_peace_for_yu_lord() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.YU)
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"active_wars": [{"id": 1}],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"longest_war_duration_seasons": 5,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.SEEK_PEACE)


func test_seek_peace_long_war_any_lord() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.MEIYO)
	var vassals: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"active_wars": [{"id": 1}],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"longest_war_duration_seasons": 4,
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"province_threats": [],
		"low_stability_provinces": [],
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var peace_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", -1) == StrategicReview.Directive.SEEK_PEACE:
			peace_found = true
			break
	assert_true(peace_found)


# -- Vassal Objective Assignment -----------------------------------------------

func test_assigns_objectives_to_idle_vassals() -> void:
	var lord := _make_lord()
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"status": "COMPLETED"}},
	}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"province_threats": [],
		"low_stability_provinces": [5],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var assign_found: Dictionary = {}
	for r: Dictionary in results:
		if r.get("decision", "") == "ASSIGN":
			assign_found = r
			break
	assert_false(assign_found.is_empty())
	assert_eq(assign_found["vassal_id"], 10)
	assert_eq(assign_found["new_objective"]["objective_type"], "MAXIMIZE_PROSPERITY")


func test_assigns_threat_objective_when_threats_exist() -> void:
	var lord := _make_lord()
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {}},
	}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"province_threats": [{"type": "shadowlands", "target": "Crab_1"}],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	var assign_found: Dictionary = {}
	for r: Dictionary in results:
		if r.get("decision", "") == "ASSIGN":
			assign_found = r
			break
	assert_false(assign_found.is_empty())
	assert_eq(assign_found["new_objective"]["objective_type"], "ELIMINATE_SHADOWLANDS")


func test_no_assignment_for_active_vassals() -> void:
	var lord := _make_lord()
	var v := _make_vassal(10, 1)
	var vassals: Array[L5RCharacterData] = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "MAINTAIN_PEACE", "status": "ACTIVE"}},
	}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": 0,
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
	}

	var results: Array[Dictionary] = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("decision", ""), "ASSIGN")


# -- Emperor Review ------------------------------------------------------------

func test_emperor_review_includes_lord_directives() -> void:
	var emperor := _make_lord(1, Enums.BushidoVirtue.CHUGI)
	var champion := _make_vassal(10, 1)
	champion.clan = "Lion"
	var champions: Array[L5RCharacterData] = [champion]
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": -1,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	assert_gt(results.size(), 0)


func test_emperor_winter_court_selection_autumn_only() -> void:
	var emperor := _make_lord(1, Enums.BushidoVirtue.JIN)
	var c1 := _make_vassal(10, 1)
	c1.clan = "Crane"
	var c2 := _make_vassal(11, 1)
	c2.clan = "Lion"
	var champions: Array[L5RCharacterData] = [c1, c2]
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": -1,
		"current_season": TimeSystem.Season.SPRING,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 1,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "WINTER_COURT_HOST")


func test_emperor_winter_court_host_selected_in_autumn() -> void:
	var emperor := _make_lord(1, Enums.BushidoVirtue.JIN)
	emperor.disposition_values = {10: 20.0, 11: 5.0}
	var c1 := _make_vassal(10, 1)
	c1.clan = "Crane"
	var c2 := _make_vassal(11, 1)
	c2.clan = "Lion"
	var champions: Array[L5RCharacterData] = [c1, c2]
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": -1,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"last_host_seasons": {"Crane": 2, "Lion": -100},
		"crisis_momentum_by_clan": {"Lion": 30.0},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, world_state, objectives_map
	)

	var host_found: Dictionary = {}
	for r: Dictionary in results:
		if r.get("directive", "") == "WINTER_COURT_HOST":
			host_found = r
			break
	assert_false(host_found.is_empty())
	assert_has(["Crane", "Lion"], host_found["host_clan"])


func test_emperor_vacancy_fill_respects_delay() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [{"position": "Emerald_Champion"}],
		"ticks_since_oldest_vacancy": 5,
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "FILL_VACANCY")


func test_emperor_vacancy_fill_after_delay() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [{"position": "Emerald_Champion"}],
		"ticks_since_oldest_vacancy": 30,
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	var vacancy_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", "") == "FILL_VACANCY":
			vacancy_found = true
			assert_eq(r["skill_weight"], 25)
			assert_eq(r["disposition_weight"], 10)
			break
	assert_true(vacancy_found)


func test_cunning_emperor_delays_vacancy_longer() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 1.0,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [{"position": "Emerald_Champion"}],
		"ticks_since_oldest_vacancy": 30,
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.CUNNING, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "FILL_VACANCY")


# -- Shogun Creation -----------------------------------------------------------

func test_shogun_never_for_cunning() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.1,
		"tier1_crisis_active": true,
		"tier1_military_crisis_seasons": 5,
		"peace_attempted": true,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.CUNNING, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "CREATE_SHOGUN")


func test_shogun_never_for_warlike() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.1,
		"tier1_crisis_active": true,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "CREATE_SHOGUN")


func test_shogun_benevolent_after_prolonged_crisis() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.3,
		"tier1_military_crisis_seasons": 4,
		"peace_attempted": true,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, world_state, objectives_map
	)

	var shogun_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", "") == "CREATE_SHOGUN":
			shogun_found = true
			assert_eq(r["reason"], "prolonged_crisis_after_diplomacy")
			break
	assert_true(shogun_found)


func test_shogun_iron_on_tier1_crisis() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.8,
		"tier1_crisis_active": true,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	var shogun_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", "") == "CREATE_SHOGUN":
			shogun_found = true
			assert_eq(r["reason"], "duty_military_demand")
			break
	assert_true(shogun_found)


func test_shogun_tyrant_needs_loyal_candidate() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.8,
		"has_maximally_loyal_candidate": false,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "CREATE_SHOGUN")


func test_shogun_tyrant_with_loyal_candidate() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.8,
		"has_maximally_loyal_candidate": true,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": false,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions, world_state, objectives_map
	)

	var shogun_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", "") == "CREATE_SHOGUN":
			shogun_found = true
			assert_eq(r["reason"], "personal_enforcer")
			break
	assert_true(shogun_found)


func test_no_shogun_if_already_exists() -> void:
	var emperor := _make_lord()
	var champions: Array[L5RCharacterData] = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.AUTUMN,
		"active_crises": [],
		"province_threats": [],
		"low_stability_provinces": [],
		"avg_province_stability": 50.0,
		"treasury_ratio": 1.0,
		"active_wars": [],
		"escalating_conflicts": [],
		"military_readiness": 0.1,
		"tier1_crisis_active": true,
		"last_host_seasons": {},
		"crisis_momentum_by_clan": {},
		"current_season_index": 4,
		"vacancies": [],
		"shogun_exists": true,
	}

	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", ""), "CREATE_SHOGUN")


# -- DayOrchestrator Integration -----------------------------------------------

func test_day_orchestrator_runs_strategic_review_on_season_change() -> void:
	var time := TimeSystem.new()
	# Set to just before a season boundary (day 89 → day 90 = summer)
	for i: int in range(89):
		time.advance_tick()

	var lord := _make_lord()
	lord.action_points_current = 2
	var characters: Array[L5RCharacterData] = [lord]
	var characters_by_id: Dictionary = {lord.character_id: lord}
	var objectives_map: Dictionary = {}

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {},
		objectives_map, {}, {}, DiceEngine.new(42),
		{}, {}, [], {}, [], [], [], [], [], [1], {}, {}, [1000]
	)

	assert_true(result.get("season_changed", false))
	var strategic: Array = result.get("strategic_results", [])
	assert_gt(strategic.size(), 0)


func test_day_orchestrator_no_strategic_review_same_season() -> void:
	var time := TimeSystem.new()
	time.advance_tick()

	var lord := _make_lord()
	lord.action_points_current = 2
	var characters: Array[L5RCharacterData] = [lord]
	var characters_by_id: Dictionary = {lord.character_id: lord}
	var objectives_map: Dictionary = {}

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {},
		objectives_map, {}, {}, DiceEngine.new(42),
		{}, {}, [], {}, [], [], [], [], [], [1], {}, {}, [1000]
	)

	assert_false(result.get("season_changed", false))
	var strategic: Array = result.get("strategic_results", [])
	assert_eq(strategic.size(), 0)
