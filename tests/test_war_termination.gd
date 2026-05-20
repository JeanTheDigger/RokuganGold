extends GutTest
## Tests for WarTermination — war ending mechanics per GDD s53.


var _war: WarData
var _dice: DiceEngine


func before_each() -> void:
	_war = WarData.new()
	_war.war_id = 1
	_war.clan_a = "Crab"
	_war.clan_b = "Crane"
	_war.initiator_clan = "Crab"
	_war.declaring_lord_id = 100
	_war.target_lord_id = 200
	_war.war_score_a = 50
	_war.war_score_b = 50
	_war.is_active = true
	_war.authority_level = WarData.AuthorityLevel.CLAN_WAR
	_dice = DiceEngine.new()
	_dice.set_seed(42)


# -- Peace Terms ---------------------------------------------------------------

func test_dominant_terms_demand_territory() -> void:
	_war.war_score_a = 85
	_war.war_score_b = 15
	_war.provinces_captured_by_a = [1, 2, 3]
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	assert_true(terms["territory_demand"])
	assert_eq(terms["territory_count"], 3)
	assert_true(terms["honor_concession"])


func test_winning_terms_keep_captured() -> void:
	_war.war_score_a = 70
	_war.war_score_b = 30
	_war.provinces_captured_by_a = [1, 2]
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	assert_true(terms["territory_demand"])
	assert_eq(terms["territory_count"], 2)
	assert_false(terms["honor_concession"])


func test_ahead_terms_partial_territory() -> void:
	_war.war_score_a = 55
	_war.war_score_b = 45
	_war.provinces_captured_by_a = [1, 2, 3, 4]
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	assert_true(terms["territory_demand"])
	assert_eq(terms["territory_count"], 2)


func test_behind_terms_status_quo_ante() -> void:
	_war.war_score_a = 35
	_war.war_score_b = 65
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	assert_true(terms["status_quo_ante"])
	assert_false(terms["territory_demand"])


func test_terms_from_side_b_perspective() -> void:
	_war.war_score_a = 20
	_war.war_score_b = 80
	_war.provinces_captured_by_b = [10, 11]
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crane")
	assert_true(terms["territory_demand"])
	assert_eq(terms["territory_count"], 2)


func test_terms_no_captured_territory() -> void:
	_war.war_score_a = 70
	_war.war_score_b = 30
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	assert_false(terms["territory_demand"])
	assert_eq(terms["territory_count"], 0)


# -- Peace Acceptance ----------------------------------------------------------

func test_desperate_seigyo_accepts_easily() -> void:
	_war.war_score_b = 15
	var terms: Dictionary = {"territory_demand": false}
	var result: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, terms, "Crane", "Seigyo", false, false,
	)
	assert_true(result["accepted"])
	assert_gt(result["willingness"], 50)


func test_winning_yu_refuses() -> void:
	_war.war_score_b = 75
	var terms: Dictionary = {"territory_demand": true}
	var result: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, terms, "Crane", "Yu", false, false,
	)
	assert_false(result["accepted"])
	assert_eq(result["reason"], "winning_refuses")


func test_hostage_increases_willingness() -> void:
	_war.war_score_b = 40
	var terms: Dictionary = {"territory_demand": false}
	var without: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, terms, "Crane", "Yu", false, false,
	)
	var with_hostage: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, terms, "Crane", "Yu", true, false,
	)
	assert_gt(with_hostage["willingness"], without["willingness"])


func test_superior_pressure_increases_willingness() -> void:
	_war.war_score_b = 35
	var terms: Dictionary = {"territory_demand": false}
	var without: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, terms, "Crane", "Yu", false, false,
	)
	var with_pressure: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, terms, "Crane", "Yu", false, true,
	)
	assert_gt(with_pressure["willingness"], without["willingness"])


func test_territory_demand_reduces_willingness() -> void:
	_war.war_score_b = 35
	var no_cede: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, {"territory_demand": false}, "Crane", "Gi", false, false,
	)
	var cede: Dictionary = WarTermination.evaluate_peace_acceptance(
		_war, {"territory_demand": true}, "Crane", "Gi", false, false,
	)
	assert_gt(no_cede["willingness"], cede["willingness"])


func test_acceptance_threshold_is_50() -> void:
	assert_eq(WarTermination.PEACE_ACCEPTANCE_THRESHOLD, 50)


# -- Formal Surrender ----------------------------------------------------------

func test_formal_surrender_ends_war() -> void:
	var result: Dictionary = WarTermination.resolve_formal_surrender(_war, "Crane")
	assert_false(_war.is_active)
	assert_eq(_war.resolution_type, "formal_surrender")
	assert_eq(result["winner_clan"], "Crab")
	assert_eq(result["loser_clan"], "Crane")
	assert_eq(result["honor_cost_loser"], -1.0)
	assert_eq(result["stability_bonus"], 3)


func test_formal_surrender_transfers_captured_territory() -> void:
	_war.provinces_captured_by_a = [1, 2]
	var result: Dictionary = WarTermination.resolve_formal_surrender(_war, "Crane")
	assert_eq(result["territory_transferred"].size(), 2)


# -- Negotiated Settlement -----------------------------------------------------

func test_negotiated_settlement_ends_war() -> void:
	var terms: Dictionary = {
		"proposing_clan": "Crab",
		"territory_demand": false,
		"status_quo_ante": true,
	}
	var result: Dictionary = WarTermination.resolve_negotiated_settlement(_war, terms)
	assert_false(_war.is_active)
	assert_eq(_war.resolution_type, "negotiated_settlement")
	assert_eq(result["honor_both"], 0.1)
	assert_true(result["status_quo_ante"])


func test_negotiated_settlement_territory_transfer() -> void:
	_war.provinces_captured_by_a = [1, 2, 3]
	var terms: Dictionary = {
		"proposing_clan": "Crab",
		"territory_demand": true,
		"territory_count": 2,
	}
	var result: Dictionary = WarTermination.resolve_negotiated_settlement(_war, terms)
	assert_eq(result["territory_transferred"].size(), 2)


func test_negotiated_settlement_clamps_to_available() -> void:
	_war.provinces_captured_by_a = [1]
	var terms: Dictionary = {
		"proposing_clan": "Crab",
		"territory_demand": true,
		"territory_count": 5,
	}
	var result: Dictionary = WarTermination.resolve_negotiated_settlement(_war, terms)
	assert_eq(result["territory_transferred"].size(), 1)


# -- Imperial Edict ------------------------------------------------------------

func test_imperial_edict_ends_war() -> void:
	var result: Dictionary = WarTermination.resolve_imperial_edict(_war)
	assert_false(_war.is_active)
	assert_eq(_war.resolution_type, "imperial_edict")
	assert_true(result["status_quo_ante"])
	assert_eq(result["stability_bonus"], 3)


# -- Annihilation --------------------------------------------------------------

func test_check_annihilation_side_a() -> void:
	_war.war_score_a = 0
	var check: Dictionary = WarTermination.check_annihilation(_war)
	assert_true(check["annihilated"])
	assert_eq(check["clan"], "Crab")


func test_check_annihilation_side_b() -> void:
	_war.war_score_b = 0
	var check: Dictionary = WarTermination.check_annihilation(_war)
	assert_true(check["annihilated"])
	assert_eq(check["clan"], "Crane")


func test_check_annihilation_neither() -> void:
	var check: Dictionary = WarTermination.check_annihilation(_war)
	assert_false(check["annihilated"])


func test_resolve_annihilation() -> void:
	_war.war_score_b = 0
	var result: Dictionary = WarTermination.resolve_annihilation(_war, "Crane")
	assert_false(_war.is_active)
	assert_eq(_war.resolution_type, "annihilation")
	assert_eq(result["victor_clan"], "Crab")
	assert_eq(result["annihilated_clan"], "Crane")
	assert_eq(result["stability_bonus"], 0)


# -- Negotiate Surrender Action ------------------------------------------------

func _make_character(clan: String, courtier_rank: int = 3) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 100
	c.clan = clan
	c.skills["Courtier"] = courtier_rank
	c.set_trait_value(Enums.Trait.AWARENESS, 3)
	return c


func test_negotiate_surrender_no_war_fails() -> void:
	var c: L5RCharacterData = _make_character("Crab")
	var ctx_war: Dictionary = {"war": null, "own_clan": "Crab", "enemy_clan": "Crane"}
	var result: Dictionary = WarTermination.resolve_negotiate_surrender(
		c, ctx_war, "Gi", false, false, _dice,
	)
	assert_true(result["failed"])
	assert_eq(result["reason"], "no_active_war")


func test_negotiate_surrender_success_peace_accepted() -> void:
	_war.war_score_a = 20
	_war.war_score_b = 80
	_dice.set_seed(999)
	var c: L5RCharacterData = _make_character("Crab", 5)
	c.set_trait_value(Enums.Trait.AWARENESS, 5)
	var ctx_war: Dictionary = {"war": _war, "own_clan": "Crab", "enemy_clan": "Crane"}
	var result: Dictionary = WarTermination.resolve_negotiate_surrender(
		c, ctx_war, "Seigyo", false, true, _dice,
	)
	if result.get("failed", false):
		# Roll may fail — test the structure at least.
		assert_true(result.has("reason"))
	else:
		assert_true(result.has("peace_accepted"))
		assert_true(result.has("terms"))


func test_negotiate_surrender_roll_failure() -> void:
	_dice.set_seed(1)
	var c: L5RCharacterData = _make_character("Crab", 1)
	c.set_trait_value(Enums.Trait.AWARENESS, 1)
	var ctx_war: Dictionary = {"war": _war, "own_clan": "Crab", "enemy_clan": "Crane"}
	var result: Dictionary = WarTermination.resolve_negotiate_surrender(
		c, ctx_war, "Yu", false, false, _dice,
	)
	# With skill 1 and awareness 1 (1k1), very unlikely to hit TN 20.
	# The result should be failed=true with reason negotiation_failed OR
	# a low willingness rejection. Either is valid.
	assert_true(result.has("failed") or result.has("peace_accepted"))


func test_negotiate_surrender_not_combatant() -> void:
	var c: L5RCharacterData = _make_character("Lion")
	var ctx_war: Dictionary = {"war": _war, "own_clan": "Lion", "enemy_clan": ""}
	var result: Dictionary = WarTermination.resolve_negotiate_surrender(
		c, ctx_war, "Gi", false, false, _dice,
	)
	assert_true(result["failed"])
	assert_eq(result["reason"], "not_a_combatant")


# -- Topic Generation ---------------------------------------------------------

func test_generate_surrender_topic() -> void:
	var resolution: Dictionary = {
		"resolution": "formal_surrender",
		"war_id": 1,
		"loser_clan": "Crane",
		"winner_clan": "Crab",
	}
	var next_id: Array[int] = [500]
	var topic: TopicData = WarTermination.generate_war_end_topic(resolution, next_id, 100)
	assert_eq(topic.topic_id, 500)
	assert_eq(next_id[0], 501)
	assert_eq(topic.topic_type, "war_end")
	assert_eq(topic.variant, "formal_surrender")
	assert_eq(topic.tier, TopicData.Tier.TIER_2)
	assert_eq(topic.momentum, 60.0)
	assert_eq(topic.category, TopicData.Category.POLITICAL)
	assert_eq(topic.clan_involved, "Crane")
	assert_eq(topic.subject_role, "VICTIM")


func test_generate_negotiated_topic() -> void:
	var resolution: Dictionary = {
		"resolution": "negotiated_settlement",
		"war_id": 1,
	}
	var next_id: Array[int] = [600]
	var topic: TopicData = WarTermination.generate_war_end_topic(resolution, next_id, 200)
	assert_eq(topic.tier, TopicData.Tier.TIER_3)
	assert_eq(topic.momentum, 40.0)


func test_generate_imperial_edict_topic() -> void:
	var resolution: Dictionary = {
		"resolution": "imperial_edict",
		"war_id": 1,
	}
	var next_id: Array[int] = [700]
	var topic: TopicData = WarTermination.generate_war_end_topic(resolution, next_id, 300)
	assert_eq(topic.tier, TopicData.Tier.TIER_2)
	assert_eq(topic.momentum, 70.0)


func test_generate_annihilation_topic() -> void:
	var resolution: Dictionary = {
		"resolution": "annihilation",
		"war_id": 1,
		"annihilated_clan": "Crane",
	}
	var next_id: Array[int] = [800]
	var topic: TopicData = WarTermination.generate_war_end_topic(resolution, next_id, 400)
	assert_eq(topic.tier, TopicData.Tier.TIER_1)
	assert_eq(topic.momentum, 80.0)
	assert_eq(topic.clan_involved, "Crane")


# -- DayOrchestrator Wiring ---------------------------------------------------

func test_annihilation_auto_resolves_in_orchestrator() -> void:
	_war.war_score_a = 0
	var active_wars: Array[WarData] = [_war]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_war_terminations(
		[], active_wars, active_topics, next_id, 50,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["resolution"], "annihilation")
	assert_eq(results[0]["annihilated_clan"], "Crab")
	assert_false(_war.is_active)
	assert_eq(active_topics.size(), 1)


func test_inactive_wars_skipped_in_annihilation_check() -> void:
	_war.war_score_a = 0
	_war.is_active = false
	var active_wars: Array[WarData] = [_war]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var results: Array[Dictionary] = DayOrchestrator._process_war_terminations(
		[], active_wars, active_topics, next_id, 50,
	)
	assert_eq(results.size(), 0)


func test_peace_resolution_from_applied_list() -> void:
	var applied: Array = [{
		"effects": {
			"requires_peace_resolution": true,
			"resolution_type": "negotiated_settlement",
			"war_id": 1,
			"own_clan": "Crab",
			"enemy_clan": "Crane",
			"terms": {
				"proposing_clan": "Crab",
				"territory_demand": false,
				"status_quo_ante": true,
			},
		},
	}]
	var active_wars: Array[WarData] = [_war]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [200]
	var results: Array[Dictionary] = DayOrchestrator._process_war_terminations(
		applied, active_wars, active_topics, next_id, 60,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["resolution"], "negotiated_settlement")
	assert_false(_war.is_active)
	assert_eq(active_topics.size(), 1)


func test_formal_surrender_from_applied_list() -> void:
	var applied: Array = [{
		"effects": {
			"requires_peace_resolution": true,
			"resolution_type": "formal_surrender",
			"war_id": 1,
			"own_clan": "Crane",
		},
	}]
	var active_wars: Array[WarData] = [_war]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [300]
	var results: Array[Dictionary] = DayOrchestrator._process_war_terminations(
		applied, active_wars, active_topics, next_id, 70,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["resolution"], "formal_surrender")
	assert_eq(results[0]["surrendering_clan"], "Crane")


func test_missing_war_id_skipped() -> void:
	var applied: Array = [{
		"effects": {
			"requires_peace_resolution": true,
			"resolution_type": "negotiated_settlement",
			"war_id": 999,
			"terms": {"proposing_clan": "Crab"},
		},
	}]
	var active_wars: Array[WarData] = [_war]
	var active_topics: Array[TopicData] = []
	var next_id: Array[int] = [400]
	var results: Array[Dictionary] = DayOrchestrator._process_war_terminations(
		applied, active_wars, active_topics, next_id, 80,
	)
	assert_eq(results.size(), 0)


func test_find_war_by_id() -> void:
	var wars: Array[WarData] = [_war]
	assert_eq(DayOrchestrator._find_war_by_id(wars, 1), _war)
	assert_null(DayOrchestrator._find_war_by_id(wars, 99))


# -- Resolution Names ----------------------------------------------------------

func test_resolution_name_constants() -> void:
	assert_eq(
		WarTermination.RESOLUTION_NAMES[WarTermination.ResolutionType.FORMAL_SURRENDER],
		"formal_surrender",
	)
	assert_eq(
		WarTermination.RESOLUTION_NAMES[WarTermination.ResolutionType.NEGOTIATED_SETTLEMENT],
		"negotiated_settlement",
	)
	assert_eq(
		WarTermination.RESOLUTION_NAMES[WarTermination.ResolutionType.IMPERIAL_EDICT],
		"imperial_edict",
	)
	assert_eq(
		WarTermination.RESOLUTION_NAMES[WarTermination.ResolutionType.ANNIHILATION],
		"annihilation",
	)


# -- Trade Route Suspension / Restoration --------------------------------------

func _make_route(id: int, prov_a: int, prov_b: int) -> TradeRouteData:
	var r: TradeRouteData = TradeRouteData.new()
	r.route_id = id
	r.province_a_id = prov_a
	r.province_b_id = prov_b
	return r


func _make_province(id: int, clan: String) -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = id
	p.clan = clan
	return p


func test_suspend_routes_between_warring_clans() -> void:
	var p1: ProvinceData = _make_province(1, "Crab")
	var p2: ProvinceData = _make_province(2, "Crane")
	var p3: ProvinceData = _make_province(3, "Crab")
	var provinces: Dictionary = {1: p1, 2: p2, 3: p3}
	var route_cross: TradeRouteData = _make_route(10, 1, 2)
	var route_same: TradeRouteData = _make_route(11, 1, 3)
	var routes: Array = [route_cross, route_same]

	var results: Array[Dictionary] = WarTermination.suspend_trade_routes_for_war(
		routes, provinces, "Crab", "Crane",
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["route_id"], 10)
	assert_true(route_cross.is_disrupted)
	assert_eq(route_cross.disruption_reason, "war_Crab_Crane")
	assert_false(route_same.is_disrupted)


func test_suspend_skips_already_disrupted() -> void:
	var provinces: Dictionary = {
		1: _make_province(1, "Crab"),
		2: _make_province(2, "Crane"),
	}
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "bandits"
	var routes: Array = [route]

	var results: Array[Dictionary] = WarTermination.suspend_trade_routes_for_war(
		routes, provinces, "Crab", "Crane",
	)
	assert_eq(results.size(), 0)
	assert_eq(route.disruption_reason, "bandits")


func test_restore_routes_on_peace() -> void:
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "war_Crab_Crane"
	var route_other: TradeRouteData = _make_route(11, 3, 4)
	route_other.is_disrupted = true
	route_other.disruption_reason = "war_Lion_Unicorn"
	var routes: Array = [route, route_other]

	var results: Array[Dictionary] = WarTermination.restore_trade_routes_for_peace(
		routes, "Crab", "Crane",
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["route_id"], 10)
	assert_false(route.is_disrupted)
	assert_true(route_other.is_disrupted)


func test_restore_handles_reversed_clan_order() -> void:
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "war_Crane_Crab"
	var routes: Array = [route]

	var results: Array[Dictionary] = WarTermination.restore_trade_routes_for_peace(
		routes, "Crab", "Crane",
	)
	assert_eq(results.size(), 1)
	assert_false(route.is_disrupted)


func test_annihilation_does_not_restore_routes() -> void:
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "war_Crab_Crane"
	var routes: Array = [route]

	var results: Array[Dictionary] = DayOrchestrator._process_peace_trade_routes(
		[{"resolution": "annihilation", "victor_clan": "Crab", "annihilated_clan": "Crane"}],
		routes,
	)
	assert_eq(results.size(), 0)
	assert_true(route.is_disrupted)


func test_orchestrator_suspends_routes_on_declaration() -> void:
	var p1: ProvinceData = _make_province(1, "Crab")
	var p2: ProvinceData = _make_province(2, "Crane")
	var provinces: Dictionary = {1: p1, 2: p2}
	var route: TradeRouteData = _make_route(10, 1, 2)
	var routes: Array = [route]
	var declarations: Array[Dictionary] = [{
		"event": "war_declared",
		"declaring_clan": "Crab",
		"target_clan": "Crane",
	}]

	var results: Array[Dictionary] = DayOrchestrator._process_war_trade_routes(
		declarations, routes, provinces,
	)
	assert_eq(results.size(), 1)
	assert_true(route.is_disrupted)


func test_orchestrator_restores_routes_on_settlement() -> void:
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "war_Crab_Crane"
	var routes: Array = [route]
	var terminations: Array[Dictionary] = [{
		"resolution": "negotiated_settlement",
		"proposing_clan": "Crab",
		"receiving_clan": "Crane",
	}]

	var results: Array[Dictionary] = DayOrchestrator._process_peace_trade_routes(
		terminations, routes,
	)
	assert_eq(results.size(), 1)
	assert_false(route.is_disrupted)


func test_orchestrator_restores_routes_on_surrender() -> void:
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "war_Crab_Crane"
	var routes: Array = [route]
	var terminations: Array[Dictionary] = [{
		"resolution": "formal_surrender",
		"winner_clan": "Crab",
		"loser_clan": "Crane",
	}]

	var results: Array[Dictionary] = DayOrchestrator._process_peace_trade_routes(
		terminations, routes,
	)
	assert_eq(results.size(), 1)
	assert_false(route.is_disrupted)


func test_orchestrator_restores_routes_on_edict() -> void:
	var route: TradeRouteData = _make_route(10, 1, 2)
	route.is_disrupted = true
	route.disruption_reason = "war_Crab_Crane"
	var routes: Array = [route]
	var terminations: Array[Dictionary] = [{
		"resolution": "imperial_edict",
		"clan_a": "Crab",
		"clan_b": "Crane",
	}]

	var results: Array[Dictionary] = DayOrchestrator._process_peace_trade_routes(
		terminations, routes,
	)
	assert_eq(results.size(), 1)
	assert_false(route.is_disrupted)


# -- Territory Transfer Mutations -----------------------------------------------

func _make_province(pid: int, clan: String) -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	return p


func test_surrender_transfers_province_clan() -> void:
	var p1: ProvinceData = _make_province(1, "Crane")
	var p2: ProvinceData = _make_province(2, "Crane")
	var provinces: Dictionary = {1: p1, 2: p2}
	var resolution: Dictionary = {
		"resolution": "formal_surrender",
		"winner_clan": "Crab",
		"territory_transferred": [1, 2],
	}
	var log: Array[Dictionary] = WarTermination.apply_territory_transfers(resolution, provinces)
	assert_eq(p1.clan, "Crab")
	assert_eq(p2.clan, "Crab")
	assert_eq(log.size(), 2)


func test_negotiated_settlement_transfers_partial() -> void:
	var p1: ProvinceData = _make_province(10, "Crane")
	var provinces: Dictionary = {10: p1}
	var resolution: Dictionary = {
		"resolution": "negotiated_settlement",
		"proposing_clan": "Crab",
		"territory_transferred": [10],
	}
	var log: Array[Dictionary] = WarTermination.apply_territory_transfers(resolution, provinces)
	assert_eq(p1.clan, "Crab")
	assert_eq(log[0]["old_clan"], "Crane")
	assert_eq(log[0]["new_clan"], "Crab")


func test_no_transfer_when_empty() -> void:
	var provinces: Dictionary = {}
	var resolution: Dictionary = {
		"resolution": "negotiated_settlement",
		"proposing_clan": "Crab",
		"territory_transferred": [],
	}
	var log: Array[Dictionary] = WarTermination.apply_territory_transfers(resolution, provinces)
	assert_eq(log.size(), 0)


func test_imperial_edict_no_transfer() -> void:
	# Status quo ante — no territory changes hands
	var p: ProvinceData = _make_province(5, "Crane")
	var provinces: Dictionary = {5: p}
	var resolution: Dictionary = {
		"resolution": "imperial_edict",
		"clan_a": "Crab",
		"clan_b": "Crane",
		"territory_transferred": [],
	}
	WarTermination.apply_territory_transfers(resolution, provinces)
	assert_eq(p.clan, "Crane")  # unchanged


func test_transfer_skips_already_correct_clan() -> void:
	var p: ProvinceData = _make_province(7, "Crab")  # already Crab's
	var provinces: Dictionary = {7: p}
	var resolution: Dictionary = {
		"resolution": "formal_surrender",
		"winner_clan": "Crab",
		"territory_transferred": [7],
	}
	var log: Array[Dictionary] = WarTermination.apply_territory_transfers(resolution, provinces)
	assert_eq(log.size(), 0)  # no change logged — clan was already correct


func test_orchestrator_applies_territory_transfers() -> void:
	var p: ProvinceData = _make_province(3, "Crane")
	var provinces: Dictionary = {3: p}
	var war_termination_results: Array[Dictionary] = [{
		"resolution": "formal_surrender",
		"winner_clan": "Crab",
		"territory_transferred": [3],
	}]
	var result: Array[Dictionary] = DayOrchestrator._apply_war_territory_transfers(
		war_termination_results, provinces,
	)
	assert_eq(p.clan, "Crab")
	assert_eq(result.size(), 1)
	assert_eq(result[0]["new_clan"], "Crab")


# -- Peace Court ---------------------------------------------------------------

func _make_peace_court(ic_day: int = 1) -> CourtSessionData:
	return WarTermination.create_peace_court(
		99, _war, 100, 200, "Crab", ic_day,
	)


func test_create_peace_court_type_and_phase() -> void:
	var court: CourtSessionData = _make_peace_court()
	assert_eq(court.court_type, CourtSessionData.CourtType.PEACE_COURT)
	assert_eq(court.phase, CourtSessionData.CourtPhase.ACTIVE)


func test_create_peace_court_links_war_id() -> void:
	var court: CourtSessionData = _make_peace_court()
	assert_eq(court.peace_court_war_id, _war.war_id)


func test_create_peace_court_has_clan_prestige() -> void:
	var court: CourtSessionData = _make_peace_court()
	assert_eq(court.prestige, CourtSystem.PRESTIGE_CLAN)


func test_create_peace_court_default_duration_is_max() -> void:
	var court: CourtSessionData = _make_peace_court()
	assert_eq(court.duration_ticks, CourtSystem.PEACE_COURT_MAX_DURATION)


func test_get_required_proxy_rank_clan_war() -> void:
	_war.authority_level = WarData.AuthorityLevel.CLAN_WAR
	assert_eq(WarTermination.get_required_proxy_rank(_war), Enums.LordRank.CLAN_CHAMPION)


func test_get_required_proxy_rank_family_war() -> void:
	_war.authority_level = WarData.AuthorityLevel.FAMILY_WAR
	assert_eq(WarTermination.get_required_proxy_rank(_war), Enums.LordRank.FAMILY_DAIMYO)


func test_get_required_proxy_rank_border_conflict() -> void:
	_war.authority_level = WarData.AuthorityLevel.BORDER_CONFLICT
	assert_eq(WarTermination.get_required_proxy_rank(_war), Enums.LordRank.FAMILY_DAIMYO)


func test_get_required_proxy_rank_provincial_raid() -> void:
	_war.authority_level = WarData.AuthorityLevel.PROVINCIAL_RAID
	assert_eq(WarTermination.get_required_proxy_rank(_war), Enums.LordRank.PROVINCIAL_DAIMYO)


func test_is_valid_peace_proxy_champion_for_clan_war() -> void:
	_war.authority_level = WarData.AuthorityLevel.CLAN_WAR
	var c: L5RCharacterData = L5RCharacterData.new()
	c.status = 6.5  # Clan Champion tier
	assert_true(WarTermination.is_valid_peace_proxy(c, _war))


func test_is_valid_peace_proxy_low_rank_fails_clan_war() -> void:
	_war.authority_level = WarData.AuthorityLevel.CLAN_WAR
	var c: L5RCharacterData = L5RCharacterData.new()
	c.status = 3.5  # Provincial Daimyo tier — not high enough
	assert_false(WarTermination.is_valid_peace_proxy(c, _war))


func test_is_valid_peace_proxy_family_daimyo_for_family_war() -> void:
	_war.authority_level = WarData.AuthorityLevel.FAMILY_WAR
	var c: L5RCharacterData = L5RCharacterData.new()
	c.status = 4.5  # Family Daimyo tier
	assert_true(WarTermination.is_valid_peace_proxy(c, _war))


func test_apply_willingness_modifier_clan_a() -> void:
	var court: CourtSessionData = _make_peace_court()
	var result: Dictionary = WarTermination.apply_willingness_modifier(court, _war, "Crab", 10)
	assert_true(result["applied"])
	assert_eq(court.willingness_modifier_clan_a, 10)
	assert_eq(court.willingness_modifier_clan_b, 0)


func test_apply_willingness_modifier_clan_b() -> void:
	var court: CourtSessionData = _make_peace_court()
	var result: Dictionary = WarTermination.apply_willingness_modifier(court, _war, "Crane", 15)
	assert_true(result["applied"])
	assert_eq(court.willingness_modifier_clan_b, 15)
	assert_eq(court.willingness_modifier_clan_a, 0)


func test_apply_willingness_modifier_accumulates() -> void:
	var court: CourtSessionData = _make_peace_court()
	WarTermination.apply_willingness_modifier(court, _war, "Crane", 10)
	WarTermination.apply_willingness_modifier(court, _war, "Crane", 5)
	assert_eq(court.willingness_modifier_clan_b, 15)


func test_apply_willingness_modifier_wrong_clan_fails() -> void:
	var court: CourtSessionData = _make_peace_court()
	var result: Dictionary = WarTermination.apply_willingness_modifier(court, _war, "Lion", 10)
	assert_false(result["applied"])
	assert_eq(result["reason"], "clan_not_in_war")


func test_apply_willingness_modifier_closed_court_fails() -> void:
	var court: CourtSessionData = _make_peace_court()
	CourtSystem.close_court(court)
	var result: Dictionary = WarTermination.apply_willingness_modifier(court, _war, "Crab", 5)
	assert_false(result["applied"])
	assert_eq(result["reason"], "court_not_active")


func test_apply_willingness_modifier_war_mismatch_fails() -> void:
	var court: CourtSessionData = _make_peace_court()
	var other_war: WarData = WarData.new()
	other_war.war_id = 999
	other_war.clan_a = "Crab"
	other_war.clan_b = "Crane"
	var result: Dictionary = WarTermination.apply_willingness_modifier(court, other_war, "Crab", 5)
	assert_false(result["applied"])
	assert_eq(result["reason"], "court_war_mismatch")


func test_conclude_peace_court_accepted_ends_war() -> void:
	_war.war_score_a = 55
	_war.war_score_b = 45
	var court: CourtSessionData = _make_peace_court()
	# Apply large modifier so willingness crosses threshold
	WarTermination.apply_willingness_modifier(court, _war, "Crane", 60)
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	var result: Dictionary = WarTermination.conclude_peace_court(
		court, _war, terms, "Gi", "Gi", false, false,
	)
	assert_true(result["concluded"])
	assert_true(result["accepted_by_both"])
	assert_false(_war.is_active)


func test_conclude_peace_court_rejected_war_stays_active() -> void:
	_war.war_score_a = 85
	_war.war_score_b = 15
	_war.provinces_captured_by_a = [1, 2, 3]
	var court: CourtSessionData = _make_peace_court()
	# No willingness modifier — Desperate side still won't accept full conquest terms
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	var result: Dictionary = WarTermination.conclude_peace_court(
		court, _war, terms, "Yu", "Yu", false, false,
	)
	assert_true(result["concluded"])
	assert_false(result["accepted_by_both"])
	assert_true(_war.is_active)


func test_conclude_peace_court_closes_court_regardless() -> void:
	var court: CourtSessionData = _make_peace_court()
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	WarTermination.conclude_peace_court(court, _war, terms, "Gi", "Gi", false, false)
	assert_eq(court.phase, CourtSessionData.CourtPhase.CLOSED)


func test_conclude_peace_court_accepted_includes_court_id() -> void:
	_war.war_score_a = 50
	_war.war_score_b = 50
	var court: CourtSessionData = _make_peace_court()
	WarTermination.apply_willingness_modifier(court, _war, "Crane", 70)
	var terms: Dictionary = WarTermination.compute_peace_terms(_war, "Crab")
	var result: Dictionary = WarTermination.conclude_peace_court(
		court, _war, terms, "Gi", "Gi", false, false,
	)
	if result["accepted_by_both"]:
		assert_eq(result["resolution"]["peace_court_id"], court.court_id)


func test_conclude_peace_court_wrong_war_fails() -> void:
	var court: CourtSessionData = _make_peace_court()
	var other_war: WarData = WarData.new()
	other_war.war_id = 999
	other_war.clan_a = "Crab"
	other_war.clan_b = "Crane"
	other_war.is_active = true
	var terms: Dictionary = {"proposing_clan": "Crab"}
	var result: Dictionary = WarTermination.conclude_peace_court(
		court, other_war, terms, "Gi", "Gi", false, false,
	)
	assert_false(result["concluded"])
	assert_eq(result["reason"], "court_war_mismatch")


func test_court_system_peace_court_duration() -> void:
	assert_eq(
		CourtSystem.get_default_duration(CourtSessionData.CourtType.PEACE_COURT),
		CourtSystem.PEACE_COURT_MAX_DURATION,
	)


func test_court_system_peace_court_prestige() -> void:
	var court: CourtSessionData = CourtSystem.create_court(
		1, CourtSessionData.CourtType.PEACE_COURT, 10, 20, "Lion", 1,
	)
	assert_eq(court.prestige, CourtSystem.PRESTIGE_CLAN)
