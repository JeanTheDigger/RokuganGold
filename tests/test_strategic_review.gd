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
	var vassals: Array = []
	var objectives_map: Dictionary = {}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	assert_eq(results.size(), 1)
	assert_eq(str(results[0]["directive"]), StrategicReview.Directive.NO_CHANGE)


func test_returns_multiple_directives() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.JIN)
	var v1 := _make_vassal(10, 1)
	var v2 := _make_vassal(11, 1)
	var vassals: Array = [v1, v2]
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

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	assert_gt(results.size(), 1)


# -- Orphaned Vassal Resolution ------------------------------------------------

func test_resolves_orphaned_vassals_confirm_for_chugi() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.CHUGI)
	var v := _make_vassal(10, 1)
	var vassals: Array = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "BREAK_ALLIANCE", "status": "ORPHANED", "assigning_lord_id": 1}},
	}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "BREAK_ALLIANCE", "status": "ORPHANED", "assigning_lord_id": 1}},
	}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = [v]
	var objectives_map: Dictionary = {
		10: {"primary": {"objective_type": "ISOLATE_CHARACTER", "status": "ORPHANED", "assigning_lord_id": 1}},
	}
	var world_state: Dictionary = {"last_court_season": 0, "current_season": 0}

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.CALL_COURT)


func test_court_triggered_by_crises() -> void:
	var lord := _make_lord()
	var v := _make_vassal(10, 1)
	var vassals: Array = [v]
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.ADJUST_TAX)


# -- War Readiness -------------------------------------------------------------

func test_war_readiness_with_active_wars() -> void:
	var lord := _make_lord()
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.WAR_READINESS)


# -- Seek Peace ----------------------------------------------------------------

func test_seek_peace_jin_lord_with_wars() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.JIN)
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("directive", -1), StrategicReview.Directive.SEEK_PEACE)


func test_seek_peace_long_war_any_lord() -> void:
	var lord := _make_lord(1, Enums.BushidoVirtue.MEIYO)
	var vassals: Array = []
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = [v]
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = [v]
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

	var results: Array = StrategicReview.run_seasonal_review(
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
	var vassals: Array = [v]
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

	var results: Array = StrategicReview.run_seasonal_review(
		lord, vassals, objectives_map, world_state
	)

	for r: Dictionary in results:
		assert_ne(r.get("decision", ""), "ASSIGN")


# -- Emperor Review ------------------------------------------------------------

func test_emperor_review_includes_lord_directives() -> void:
	var emperor := _make_lord(1, Enums.BushidoVirtue.CHUGI)
	var champion := _make_vassal(10, 1)
	champion.clan = "Lion"
	var champions: Array = [champion]
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	assert_gt(results.size(), 0)


func test_emperor_winter_court_selection_autumn_only() -> void:
	var emperor := _make_lord(1, Enums.BushidoVirtue.JIN)
	var c1 := _make_vassal(10, 1)
	c1.clan = "Crane"
	var c2 := _make_vassal(11, 1)
	c2.clan = "Lion"
	var champions: Array = [c1, c2]
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "WINTER_COURT_HOST")


func test_emperor_winter_court_host_selected_in_autumn() -> void:
	var emperor := _make_lord(1, Enums.BushidoVirtue.JIN)
	emperor.disposition_values = {10: 20.0, 11: 5.0}
	var c1 := _make_vassal(10, 1)
	c1.clan = "Crane"
	var c2 := _make_vassal(11, 1)
	c2.clan = "Lion"
	var champions: Array = [c1, c2]
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, world_state, objectives_map
	)

	var host_found: Dictionary = {}
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "WINTER_COURT_HOST":
			host_found = r
			break
	assert_false(host_found.is_empty())
	assert_has(["Crane", "Lion"], host_found["host_clan"])


func test_emperor_vacancy_fill_iron_immediate() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [{"position_type": "Clan Magistrate", "priority": 3, "seasons_vacant": 0}],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	var vacancy_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "FILL_VACANCY":
			vacancy_found = true
			assert_eq(r["skill_weight"], 25)
			assert_eq(r["disposition_weight"], 10)
			break
	assert_true(vacancy_found)


func test_cunning_emperor_delays_vacancy_season_zero() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [{"position_type": "Clan Magistrate", "priority": 3, "seasons_vacant": 0}],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.CUNNING, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "FILL_VACANCY")


func test_cunning_emperor_fills_after_one_season() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [{"position_type": "Clan Magistrate", "priority": 3, "seasons_vacant": 1}],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.CUNNING, champions, world_state, objectives_map
	)

	var vacancy_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "FILL_VACANCY":
			vacancy_found = true
			assert_true(r.has("clan_balance_weight"), "Cunning should include clan_balance_weight")
			assert_eq(r["clan_balance_weight"], 25)
			break
	assert_true(vacancy_found)


# -- Warlike Dual Vacancy Delays ------------------------------------------------

func test_warlike_fills_military_vacancy_immediately() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [{"position_type": "military_commander", "priority": 3, "seasons_vacant": 0}],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, world_state, objectives_map
	)

	var vacancy_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "FILL_VACANCY":
			vacancy_found = true
			break
	assert_true(vacancy_found, "Warlike should fill military vacancy immediately")


func test_warlike_delays_political_vacancy() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [{"position_type": "Clan Magistrate", "priority": 3, "seasons_vacant": 0}],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "FILL_VACANCY", "Warlike should delay political vacancy")


func test_warlike_fills_political_after_season() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [{"position_type": "Clan Magistrate", "priority": 3, "seasons_vacant": 1}],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, world_state, objectives_map
	)

	var vacancy_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "FILL_VACANCY":
			vacancy_found = true
			break
	assert_true(vacancy_found, "Warlike should fill political vacancy after 1 season")


func test_warlike_prefers_military_over_political() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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
		"vacancies": [
			{"position_type": "Clan Magistrate", "priority": 2, "seasons_vacant": 1},
			{"position_type": "military_commander", "priority": 3, "seasons_vacant": 0},
		],
		"shogun_exists": false,
	}

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		if str(r.get("directive", "")) == "FILL_VACANCY":
			assert_eq(r["vacancy"]["position_type"], "military_commander",
				"Warlike should pick military vacancy (higher priority)")
			break


# -- Warlike Bushi Disposition Baselines ----------------------------------------

func test_warlike_seeds_bushi_champion_acquaintance() -> void:
	var emperor := _make_emperor()
	var champion := _make_champion(10, "Crab")
	champion.school_type = Enums.SchoolType.BUSHI

	var champions: Array = [champion]
	var ws: Dictionary = _base_emperor_world_state()
	StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, ws, {}
	)

	assert_eq(emperor.disposition_values.get(10, -999), 15,
		"Warlike Emperor should seed bushi champion at Acquaintance (+15)")


func test_warlike_seeds_courtier_champion_stranger() -> void:
	var emperor := _make_emperor()
	var champion := _make_champion(11, "Crane")
	champion.school_type = Enums.SchoolType.COURTIER

	var champions: Array = [champion]
	var ws: Dictionary = _base_emperor_world_state()
	StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, ws, {}
	)

	assert_false(emperor.disposition_values.has(11),
		"Warlike Emperor should not seed courtier (baseline 0 = no entry)")


func test_warlike_does_not_overwrite_existing_disposition() -> void:
	var emperor := _make_emperor()
	var champion := _make_champion(10, "Crab")
	champion.school_type = Enums.SchoolType.BUSHI
	emperor.disposition_values[10] = -20  # Already has disposition

	var champions: Array = [champion]
	var ws: Dictionary = _base_emperor_world_state()
	StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, ws, {}
	)

	assert_eq(emperor.disposition_values.get(10, 0), -20,
		"Should not overwrite existing disposition")


func test_benevolent_seeds_all_champions_acquaintance() -> void:
	var emperor := _make_emperor()
	var bushi := _make_champion(10, "Lion")
	bushi.school_type = Enums.SchoolType.BUSHI
	var courtier := _make_champion(11, "Crane")
	courtier.school_type = Enums.SchoolType.COURTIER

	var champions: Array = [bushi, courtier]
	var ws: Dictionary = _base_emperor_world_state()
	StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, ws, {}
	)

	assert_eq(emperor.disposition_values.get(10, -999), 15,
		"Benevolent Emperor should seed all champions at Acquaintance (+15)")
	assert_eq(emperor.disposition_values.get(11, -999), 15,
		"Benevolent Emperor should seed courtier at Acquaintance (+15) too")


func test_iron_does_not_seed_champion_baselines() -> void:
	var emperor := _make_emperor()
	var champion := _make_champion(10, "Crab")
	champion.school_type = Enums.SchoolType.BUSHI

	var champions: Array = [champion]
	var ws: Dictionary = _base_emperor_world_state()
	StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, ws, {}
	)

	assert_false(emperor.disposition_values.has(10),
		"Iron Emperor starts at Stranger (0) — no entry seeded")


# -- Archetype Baseline Utility -------------------------------------------------

func test_get_archetype_baseline_warlike_bushi() -> void:
	assert_eq(
		StrategicReview.get_archetype_champion_baseline(
			StrategicReview.EmperorArchetype.WARLIKE, Enums.SchoolType.BUSHI
		), 15
	)


func test_get_archetype_baseline_warlike_courtier() -> void:
	assert_eq(
		StrategicReview.get_archetype_champion_baseline(
			StrategicReview.EmperorArchetype.WARLIKE, Enums.SchoolType.COURTIER
		), 0
	)


func test_get_archetype_baseline_benevolent() -> void:
	assert_eq(
		StrategicReview.get_archetype_champion_baseline(
			StrategicReview.EmperorArchetype.BENEVOLENT, Enums.SchoolType.SHUGENJA
		), 15
	)


# -- Shogun Creation -----------------------------------------------------------

func test_shogun_never_for_cunning() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.CUNNING, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "CREATE_SHOGUN")


func test_shogun_never_for_warlike() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.WARLIKE, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "CREATE_SHOGUN")


func test_shogun_benevolent_after_prolonged_crisis() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.BENEVOLENT, champions, world_state, objectives_map
	)

	var shogun_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "CREATE_SHOGUN":
			shogun_found = true
			assert_eq(r["reason"], "prolonged_crisis_after_diplomacy")
			break
	assert_true(shogun_found)


func test_shogun_iron_on_tier1_crisis() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	var shogun_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "CREATE_SHOGUN":
			shogun_found = true
			assert_eq(r["reason"], "duty_military_demand")
			break
	assert_true(shogun_found)


func test_shogun_tyrant_needs_loyal_candidate() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "CREATE_SHOGUN")


func test_shogun_tyrant_with_loyal_candidate() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions, world_state, objectives_map
	)

	var shogun_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "CREATE_SHOGUN":
			shogun_found = true
			assert_eq(r["reason"], "personal_enforcer")
			break
	assert_true(shogun_found)


func test_no_shogun_if_already_exists() -> void:
	var emperor := _make_lord()
	var champions: Array = []
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

	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.IRON, champions, world_state, objectives_map
	)

	for r: Dictionary in results:
		assert_ne(str(r.get("directive", "")), "CREATE_SHOGUN")


# -- DayOrchestrator Integration -----------------------------------------------

func test_day_orchestrator_runs_strategic_review_on_season_change() -> void:
	var time := TimeSystem.new()
	# Set to just before a season boundary (day 89 → day 90 = summer)
	for i: int in range(89):
		time.advance_tick()

	var lord := _make_lord()
	lord.action_points_current = 2
	var characters: Array = [lord]
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
	var characters: Array = [lord]
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

	var champions: Array = [crab, crane]
	var results: Array = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 1)
	assert_eq(str(results[0]["directive"]), "FABRICATE_DISGRACE")
	assert_eq(results[0]["target_id"], 10)
	assert_eq(results[0]["target_clan"], "Crab")


func test_tyrant_fabricates_disgrace_for_enemy_champions() -> void:
	var emperor := _make_emperor()
	var lion := _make_champion(12, "Lion")
	emperor.disposition_values[12] = -50  # Enemy

	var champions: Array = [lion]
	var results: Array = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["target_id"], 12)


func test_tyrant_no_disgrace_for_friendly_champions() -> void:
	var emperor := _make_emperor()
	var crane := _make_champion(11, "Crane")
	emperor.disposition_values[11] = 40  # Friend

	var champions: Array = [crane]
	var results: Array = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions
	)

	assert_eq(results.size(), 0)


func test_non_tyrant_no_disgrace_fabrication() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	emperor.disposition_values[10] = -50

	var champions: Array = [crab]
	var results: Array = StrategicReview._evaluate_disgrace_fabrication(
		emperor, StrategicReview.EmperorArchetype.IRON, champions
	)

	assert_eq(results.size(), 0)


func test_tyrant_disgrace_stranger_not_targeted() -> void:
	var emperor := _make_emperor()
	var dragon := _make_champion(13, "Dragon")
	emperor.disposition_values[13] = 0  # Stranger

	var champions: Array = [dragon]
	var results: Array = StrategicReview._evaluate_disgrace_fabrication(
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

	var champions: Array = [crab, crane, lion, dragon]
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

	var champions: Array = [crab, crane, lion]
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

	var champions: Array = [sparrow, fox, wasp]
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

	var champions: Array = [crab, crane, lion]
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

	var champions: Array = [crab, crane, lion]
	var ws: Dictionary = _base_emperor_world_state()
	var results: Array = StrategicReview.run_emperor_review(
		emperor, StrategicReview.EmperorArchetype.TYRANT, champions, ws, {}
	)

	var disgrace_found: bool = false
	var civil_war_found: bool = false
	for r: Dictionary in results:
		if str(r.get("directive", "")) == "FABRICATE_DISGRACE":
			disgrace_found = true
		if str(r.get("directive", "")) == "IMPERIAL_CIVIL_WAR":
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


func test_tyrant_court_honor_penalty_for_public_debate_vs_emperor() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 50
	actor.honor = 5.0
	var emperor := _make_emperor()
	var characters_by_id: Dictionary = {50: actor, 100: emperor}

	var day_results: Array = [{
		"character_id": 50,
		"target_npc_id": 100,
		"action_id": "PUBLIC_DEBATE",
		"effects": {
			"debate_per_witness": [],
			"witnesses": [],
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 1, 100,
		StrategicReview.EmperorArchetype.TYRANT,
	)

	assert_almost_eq(actor.honor, 4.5, 0.01)


func test_non_tyrant_no_penalty_for_public_debate_vs_emperor() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 50
	actor.honor = 5.0
	var emperor := _make_emperor()
	var characters_by_id: Dictionary = {50: actor, 100: emperor}

	var day_results: Array = [{
		"character_id": 50,
		"target_npc_id": 100,
		"action_id": "PUBLIC_DEBATE",
		"effects": {
			"debate_per_witness": [],
			"witnesses": [],
		},
	}]

	DayOrchestrator._process_court_action_effects(
		day_results, characters_by_id, [], 1, 100,
		StrategicReview.EmperorArchetype.IRON,
	)

	assert_almost_eq(actor.honor, 5.0, 0.01)


func test_tyrant_public_debate_penalty_not_applied_to_non_emperor() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 50
	actor.honor = 5.0
	var other := L5RCharacterData.new()
	other.character_id = 60
	var characters_by_id: Dictionary = {50: actor, 60: other}

	var day_results: Array = [{
		"character_id": 50,
		"target_npc_id": 60,
		"action_id": "PUBLIC_DEBATE",
		"effects": {
			"debate_per_witness": [],
			"witnesses": [],
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

	var active_topics: Array = []
	var next_topic_id: Array = [500]
	var strategic_results: Array = [{
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
	var active_topics: Array = []
	var next_topic_id: Array = [600]
	var strategic_results: Array = [{
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

	var active_topics: Array = []
	var next_topic_id: Array = [700]
	var strategic_results: Array = [
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
	var active_topics: Array = []
	var next_topic_id: Array = [800]
	var strategic_results: Array = [
		{"directive": StrategicReview.Directive.CALL_COURT, "lord_id": 1},
		{"directive": "FILL_VACANCY", "lord_id": 100},
	]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 60, {}
	)

	assert_eq(active_topics.size(), 0)
	assert_eq(next_topic_id[0], 800)


# -- Repeat-Fire Guards ---------------------------------------------------------

func test_disgrace_guard_prevents_duplicate_for_same_champion() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	crab.character_name = "Hida Kisada"
	var characters_by_id: Dictionary = {100: emperor, 10: crab}

	var existing_topic := TopicData.new()
	existing_topic.topic_id = 400
	existing_topic.topic_type = "disgrace"
	existing_topic.subject_character_id = 10
	existing_topic.resolved = false
	var active_topics: Array = [existing_topic]

	var next_topic_id: Array = [500]
	var strategic_results: Array = [{
		"directive": "FABRICATE_DISGRACE",
		"lord_id": 100,
		"target_id": 10,
		"target_clan": "Crab",
		"disposition": -20,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 30, characters_by_id
	)

	assert_eq(active_topics.size(), 1, "Should not create duplicate disgrace topic")
	assert_eq(next_topic_id[0], 500, "Should not consume topic ID")


func test_disgrace_guard_allows_after_resolution() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	crab.character_name = "Hida Kisada"
	var characters_by_id: Dictionary = {100: emperor, 10: crab}

	var resolved_topic := TopicData.new()
	resolved_topic.topic_id = 400
	resolved_topic.topic_type = "disgrace"
	resolved_topic.subject_character_id = 10
	resolved_topic.resolved = true
	var active_topics: Array = [resolved_topic]

	var next_topic_id: Array = [500]
	var strategic_results: Array = [{
		"directive": "FABRICATE_DISGRACE",
		"lord_id": 100,
		"target_id": 10,
		"target_clan": "Crab",
		"disposition": -20,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 90, characters_by_id
	)

	assert_eq(active_topics.size(), 2, "Should create new disgrace after prior one resolved")
	assert_eq(next_topic_id[0], 501)


func test_disgrace_guard_allows_different_champion() -> void:
	var emperor := _make_emperor()
	var crab := _make_champion(10, "Crab")
	var lion := _make_champion(12, "Lion")
	crab.character_name = "Hida Kisada"
	lion.character_name = "Akodo Toturi"
	var characters_by_id: Dictionary = {100: emperor, 10: crab, 12: lion}

	var existing_topic := TopicData.new()
	existing_topic.topic_id = 400
	existing_topic.topic_type = "disgrace"
	existing_topic.subject_character_id = 10
	existing_topic.resolved = false
	var active_topics: Array = [existing_topic]

	var next_topic_id: Array = [500]
	var strategic_results: Array = [{
		"directive": "FABRICATE_DISGRACE",
		"lord_id": 100,
		"target_id": 12,
		"target_clan": "Lion",
		"disposition": -30,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 30, characters_by_id
	)

	assert_eq(active_topics.size(), 2, "Should allow disgrace for different champion")
	assert_eq(active_topics[1].subject_character_id, 12)


func test_civil_war_guard_prevents_duplicate() -> void:
	var existing_topic := TopicData.new()
	existing_topic.topic_id = 400
	existing_topic.variant = "imperial_civil_war"
	existing_topic.resolved = false
	var active_topics: Array = [existing_topic]

	var next_topic_id: Array = [600]
	var strategic_results: Array = [{
		"directive": "IMPERIAL_CIVIL_WAR",
		"lord_id": 100,
		"hostile_clan_count": 4,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 45, {}
	)

	assert_eq(active_topics.size(), 1, "Should not create duplicate civil war topic")
	assert_eq(next_topic_id[0], 600, "Should not consume topic ID")


func test_civil_war_guard_allows_after_resolution() -> void:
	var resolved_topic := TopicData.new()
	resolved_topic.topic_id = 400
	resolved_topic.variant = "imperial_civil_war"
	resolved_topic.resolved = true
	var active_topics: Array = [resolved_topic]

	var next_topic_id: Array = [600]
	var strategic_results: Array = [{
		"directive": "IMPERIAL_CIVIL_WAR",
		"lord_id": 100,
		"hostile_clan_count": 3,
	}]

	DayOrchestrator._process_tyrant_directives(
		strategic_results, active_topics, next_topic_id, 90, {}
	)

	assert_eq(active_topics.size(), 2, "Should create new civil war after prior one resolved")
	assert_eq(next_topic_id[0], 601)


# -- Emperor Tax Config Builder (GDD s55.10) -----------------------------------

func test_build_emperor_tax_config_iron_archetype() -> void:
	var world_states: Dictionary = {
		"emperor_archetype": StrategicReview.EmperorArchetype.IRON,
		"emperor_id": 100,
	}
	var config: Dictionary = DayOrchestrator._build_emperor_tax_config(world_states, {})
	assert_eq(config["archetype"], StrategicReview.EmperorArchetype.IRON)
	assert_false(config.has("clan_dispositions"))


func test_build_emperor_tax_config_cunning_builds_dispositions() -> void:
	var emperor := _make_emperor()
	emperor.disposition_values = {200: 40, 300: -20}
	var crane_champ := _make_champion(200, "Crane")
	crane_champ.status = 7.5
	crane_champ.lord_id = -1
	var lion_champ := _make_champion(300, "Lion")
	lion_champ.clan = "Lion"
	lion_champ.status = 7.5
	lion_champ.lord_id = -1
	var by_id: Dictionary = {
		100: emperor,
		200: crane_champ,
		300: lion_champ,
	}
	var world_states: Dictionary = {
		"emperor_archetype": StrategicReview.EmperorArchetype.CUNNING,
		"emperor_id": 100,
	}
	var config: Dictionary = DayOrchestrator._build_emperor_tax_config(world_states, by_id)
	assert_eq(config["archetype"], StrategicReview.EmperorArchetype.CUNNING)
	assert_true(config.has("clan_dispositions"))
	var disps: Dictionary = config["clan_dispositions"]
	assert_eq(disps["Crane"], 40)
	assert_eq(disps["Lion"], -20)


func test_build_emperor_tax_config_cunning_skips_non_champions() -> void:
	var emperor := _make_emperor()
	emperor.disposition_values = {200: 50}
	var retainer := L5RCharacterData.new()
	retainer.character_id = 200
	retainer.clan = "Crane"
	retainer.status = 3.0
	retainer.lord_id = 100
	var by_id: Dictionary = {100: emperor, 200: retainer}
	var world_states: Dictionary = {
		"emperor_archetype": StrategicReview.EmperorArchetype.CUNNING,
		"emperor_id": 100,
	}
	var config: Dictionary = DayOrchestrator._build_emperor_tax_config(world_states, by_id)
	assert_true(config["clan_dispositions"].is_empty())


func test_build_emperor_tax_config_warlike_no_dispositions() -> void:
	var world_states: Dictionary = {
		"emperor_archetype": StrategicReview.EmperorArchetype.WARLIKE,
		"emperor_id": 100,
	}
	var config: Dictionary = DayOrchestrator._build_emperor_tax_config(world_states, {})
	assert_eq(config["archetype"], StrategicReview.EmperorArchetype.WARLIKE)
	assert_false(config.has("clan_dispositions"))
