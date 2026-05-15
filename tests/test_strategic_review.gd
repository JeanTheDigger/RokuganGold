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


# -- Standing objective need_type key -------------------------------------------

func test_vassal_objective_has_need_type_key() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.status = 7.0
	lord.lord_id = -1
	var obj: Dictionary = StrategicReview._select_objective_for_vassal(lord, 2, [], {})
	assert_true(obj.has("need_type"), "Objective must have need_type key")
	assert_eq(obj["need_type"], obj["objective_type"], "need_type should match objective_type")


func test_vassal_objective_threat_has_need_type() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	var threats: Array = [{"type": "shadowlands", "target": "Crab"}]
	var obj: Dictionary = StrategicReview._select_objective_for_vassal(lord, 2, threats, {})
	assert_true(obj.has("need_type"))
	assert_eq(obj["need_type"], "ELIMINATE_SHADOWLANDS")


func test_vassal_objective_low_stability_has_need_type() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	var ws: Dictionary = {"low_stability_provinces": [100]}
	var obj: Dictionary = StrategicReview._select_objective_for_vassal(lord, 2, [], ws)
	assert_true(obj.has("need_type"))
	assert_eq(obj["need_type"], "MAXIMIZE_PROSPERITY")


# -- Tyrant Emperor Effects (s55.10) -------------------------------------------

func _make_emperor(id: int = 100) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Imperial"
	c.lord_id = -1
	c.status = 10.0
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	c.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	return c


func _make_champion(id: int, clan: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.lord_id = -1
	c.status = 7.0
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	return c


func _base_emperor_world_state() -> Dictionary:
	return {
		"last_court_season": 0,
		"current_season": TimeSystem.Season.SPRING,
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


# -- Disgrace Fabrication -------------------------------------------------------

func test_tyrant_fabricates_disgrace_for_rival_champions() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var crane := _make_champion(11, "Crane")
	emperor.disposition_values[10] = -15  # Rival
	emperor.disposition_values[11] = 20   # Acquaintance

	var champions: Array[L5RCharacterData] = [crab, crane]
	var results: Array[Dictionary] = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["directive"], "FABRICATE_DISGRACE")
	assert_eq(results[0]["target_id"], 10)
	assert_eq(results[0]["target_clan"], "Crab")


func test_tyrant_fabricates_disgrace_for_enemy_champions() -> void:
	var emperor := _make_emperor()
	var lion := _make_champion(12, "Lion")
	emperor.disposition_values[12] = -50  # Enemy

	var champions: Array[L5RCharacterData] = [lion]
	var results: Array[Dictionary] = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["target_id"], 12)


func test_tyrant_no_disgrace_for_friendly_champions() -> void:
	var emperor := _make_emperor()
	var crane := _make_champion(11, "Crane")
	emperor.disposition_values[11] = 40  # Friend

	var champions: Array[L5RCharacterData] = [crane]
	var results: Array[Dictionary] = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 0)


func test_non_tyrant_no_disgrace_fabrication() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	emperor.disposition_values[10] = -50

	var champions: Array[L5RCharacterData] = [crab]
	var results: Array[Dictionary] = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.IRON, champions
	)

	assert_eq(results.size(), 0)


func test_tyrant_disgrace_stranger_not_targeted() -> void:
	var emperor := _make_emperor()
	var dragon := _make_champion(13, "Dragon")
	emperor.disposition_values[13] = 0  # Stranger

	var champions: Array[L5RCharacterData] = [dragon]
	var results: Array[Dictionary] = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 0)


# -- Breaking Point (Imperial Civil War) ----------------------------------------

func test_breaking_point_fires_with_three_hostile_clans() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var crane := _make_champion(11, "Crane")
	var lion := _make_champion(12, "Lion")
	var dragon := _make_champion(13, "Dragon")
	# Three clans hate the Emperor (disposition toward Emperor <= -31)
	crab.disposition_values[emperor.character_id] = -40
	crane.disposition_values[emperor.character_id] = -50
	lion.disposition_values[emperor.character_id] = -35
	dragon.disposition_values[emperor.character_id] = 10  # Neutral

	var champions: Array[L5RCharacterData] = [crab, crane, lion, dragon]
	var result: Dictionary = StrategicReview._evaluate_breaking_point(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_false(result.is_empty())
	assert_eq(result["directive"], "IMPERIAL_CIVIL_WAR")
	assert_eq(result["hostile_clan_count"], 3)


func test_breaking_point_does_not_fire_with_two_hostile_clans() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var crane := _make_champion(11, "Crane")
	var lion := _make_champion(12, "Lion")
	crab.disposition_values[emperor.character_id] = -40
	crane.disposition_values[emperor.character_id] = -50
	lion.disposition_values[emperor.character_id] = -20  # Rival, not Enemy

	var champions: Array[L5RCharacterData] = [crab, crane, lion]
	var result: Dictionary = StrategicReview._evaluate_breaking_point(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_true(result.is_empty())


func test_breaking_point_ignores_minor_clans() -> void:
	var emperor := _make_emperor()
	var sparrow := _make_champion(20, "Sparrow")
	var fox := _make_champion(21, "Fox")
	var wasp := _make_champion(22, "Wasp")
	sparrow.disposition_values[emperor.character_id] = -80
	fox.disposition_values[emperor.character_id] = -60
	wasp.disposition_values[emperor.character_id] = -45

	var champions: Array[L5RCharacterData] = [sparrow, fox, wasp]
	var result: Dictionary = StrategicReview._evaluate_breaking_point(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_true(result.is_empty())


func test_breaking_point_non_tyrant_never_fires() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var crane := _make_champion(11, "Crane")
	var lion := _make_champion(12, "Lion")
	crab.disposition_values[emperor.character_id] = -80
	crane.disposition_values[emperor.character_id] = -80
	lion.disposition_values[emperor.character_id] = -80

	var champions: Array[L5RCharacterData] = [crab, crane, lion]
	var result: Dictionary = StrategicReview._evaluate_breaking_point(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions
	)

	assert_true(result.is_empty())


# -- Emperor Review Integration -------------------------------------------------

func test_emperor_review_includes_tyrant_directives() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var crane := _make_champion(11, "Crane")
	var lion := _make_champion(12, "Lion")
	emperor.disposition_values[10] = -20  # Rival — triggers disgrace
	crab.disposition_values[emperor.character_id] = -40
	crane.disposition_values[emperor.character_id] = -50
	lion.disposition_values[emperor.character_id] = -35

	var champions: Array[L5RCharacterData] = [crab, crane, lion]
	var ws: Dictionary = _base_emperor_world_state()
	var results: Array[Dictionary] = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions, ws, {}
	)

	var disgrace_found: bool = false
	var civil_war_found: bool = false
	for r: Dictionary in results:
		if r.get("directive", "") == "FABRICATE_DISGRACE":
			disgrace_found = true
		if r.get("directive", "") == "IMPERIAL_CIVIL_WAR":
			civil_war_found = true

	assert_true(disgrace_found, "Tyrant should fabricate disgrace for Rival champion")
	assert_true(civil_war_found, "Breaking point should fire with 3 hostile Great Clans")


# -- Tyrant Stability Penalty ---------------------------------------------------

func test_tyrant_stability_penalty_applied() -> void:
	var p1 := ProvinceData.new()
	p1.province_id = 1
	p1.stability = 50.0
	var p2 := ProvinceData.new()
	p2.province_id = 2
	p2.stability = 1.0
	var provinces: Dictionary = {1: p1, 2: p2}

	DayOrchestrator._apply_tyrant_stability_penalty(
		StrategicReview.EmperorArchetype.TYRANT, provinces
	)

	assert_almost_eq(p1.stability, 48.0, 0.01)
	assert_almost_eq(p2.stability, 0.0, 0.01)  # Clamped at 0


func test_non_tyrant_stability_penalty_not_applied() -> void:
	var p := ProvinceData.new()
	p.province_id = 1
	p.stability = 50.0
	var provinces: Dictionary = {1: p}

	DayOrchestrator._apply_tyrant_stability_penalty(
		StrategicReview.EmperorArchetype.IRON, provinces
	)

	assert_almost_eq(p.stability, 50.0, 0.01)


# -- Tyrant Court Honor Penalty -------------------------------------------------

func test_tyrant_court_honor_penalty_for_opposing_emperor() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 50
	actor.honor = 5.0
	var emperor := _make_emperor()
	var characters_by_id: Dictionary = {50: actor, 100: emperor}

	var day_results: Array = [{
		"character_id": 50,
		"target_npc_id": 100,
		"action_id": "NEGOTIATE",
		"effects": {
			"target_position_shift": 5.0,
			"_action_metadata": {"topic_id": 1},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 1, 100,
		StrategicReview.EmperorArchetype.TYRANT,
	)

	assert_almost_eq(actor.honor, 4.5, 0.01)


func test_non_tyrant_no_court_honor_penalty() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 50
	actor.honor = 5.0
	var emperor := _make_emperor()
	var characters_by_id: Dictionary = {50: actor, 100: emperor}

	var day_results: Array = [{
		"character_id": 50,
		"target_npc_id": 100,
		"action_id": "NEGOTIATE",
		"effects": {
			"target_position_shift": 5.0,
			"_action_metadata": {"topic_id": 1},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 1, 100,
		StrategicReview.EmperorArchetype.IRON,
	)

	assert_almost_eq(actor.honor, 5.0, 0.01)


func test_tyrant_court_penalty_not_applied_to_non_emperor_target() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 50
	actor.honor = 5.0
	var other := L5RCharacterData.new()
	other.character_id = 60
	var characters_by_id: Dictionary = {50: actor, 60: other}

	var day_results: Array = [{
		"character_id": 50,
		"target_npc_id": 60,
		"action_id": "NEGOTIATE",
		"effects": {
			"target_position_shift": 5.0,
			"_action_metadata": {"topic_id": 1},
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 1, 100,
		StrategicReview.EmperorArchetype.TYRANT,
	)

	assert_almost_eq(actor.honor, 5.0, 0.01)


# -- Tyrant Directive Consumers -------------------------------------------------

func test_disgrace_directive_creates_topic() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	crab.character_name = "Hida Kisada"
	var characters_by_id: Dictionary = {100: emperor, 10: crab}

	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [500]
	var strategic_results: Array[Dictionary] = [{
		"directive": "FABRICATE_DISGRACE",
		"lord_id": 100,
		"target_id": 10,
		"target_clan": "Crab",
		"disposition": -20,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 30, characters_by_id
	)

	assert_eq(active_topics.size(), 1)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.topic_id, 500)
	assert_eq(topic.tier, TopicData.Tier.TIER_3)
	assert_eq(topic.category, TopicData.Category.PERSONAL)
	assert_eq(topic.subject_character_id, 10)
	assert_eq(topic.clan_involved, "Crab")
	assert_eq(topic.topic_type, "disgrace")
	assert_eq(topic.variant, "fabricated")
	assert_string_contains(topic.title, "Hida Kisada")
	assert_eq(next_topic_id[0], 501)


func test_imperial_civil_war_directive_creates_tier1_topic() -> void:
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [600]
	var strategic_results: Array[Dictionary] = [{
		"directive": "IMPERIAL_CIVIL_WAR",
		"lord_id": 100,
		"hostile_clan_count": 4,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 45, {}
	)

	assert_eq(active_topics.size(), 1)
	var topic: TopicData = active_topics[0]
	assert_eq(topic.topic_id, 600)
	assert_eq(topic.tier, TopicData.Tier.TIER_1)
	assert_eq(topic.category, TopicData.Category.MILITARY)
	assert_eq(topic.topic_type, "crisis")
	assert_eq(topic.variant, "imperial_civil_war")
	assert_string_contains(topic.title, "4 Great Clans")
	assert_almost_eq(topic.momentum, 80.0, 0.1)
	assert_eq(next_topic_id[0], 601)


func test_multiple_disgrace_directives_create_multiple_topics() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var lion := _make_champion(12, "Lion")
	crab.character_name = "Hida Kisada"
	lion.character_name = "Akodo Toturi"
	var characters_by_id: Dictionary = {100: emperor, 10: crab, 12: lion}

	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [700]
	var strategic_results: Array[Dictionary] = [
		{
			"directive": "FABRICATE_DISGRACE",
			"lord_id": 100,
			"target_id": 10,
			"target_clan": "Crab",
			"disposition": -20,
		},
		{
			"directive": "FABRICATE_DISGRACE",
			"lord_id": 100,
			"target_id": 12,
			"target_clan": "Lion",
			"disposition": -40,
		},
	]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 50, characters_by_id
	)

	assert_eq(active_topics.size(), 2)
	assert_eq(active_topics[0].subject_character_id, 10)
	assert_eq(active_topics[1].subject_character_id, 12)
	assert_eq(next_topic_id[0], 702)


func test_non_tyrant_directives_ignored() -> void:
	var active_topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [800]
	var strategic_results: Array[Dictionary] = [
		{"directive": StrategicReview.Directive.CALL_COURT, "lord_id": 1},
		{"directive": "FILL_VACANCY", "lord_id": 100},
	]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 60, {}
	)

	assert_eq(active_topics.size(), 0)
	assert_eq(next_topic_id[0], 800)
