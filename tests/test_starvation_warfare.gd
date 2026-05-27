extends GutTest


# -- Helpers -------------------------------------------------------------------

func _make_character(id: int, clan: String = "Crab", status: float = 3.0) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = status
	c.historical_modifiers = {}
	return c


func _make_trade_route(route_id: int, a: int = 1, b: int = 2) -> TradeRouteData:
	var r: TradeRouteData = TradeRouteData.new()
	r.route_id = route_id
	r.province_a_id = a
	r.province_b_id = b
	r.is_disrupted = false
	r.disruption_reason = ""
	r.koku_bonus_per_season = 1.0
	return r


func _make_province(id: int, clan: String = "Crab") -> ProvinceData:
	var p: ProvinceData = ProvinceData.new()
	p.province_id = id
	p.clan = clan
	return p


func _make_settlement(id: int, province_id: int, farming_pu: int = 5) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.farming_pu = farming_pu
	s.population_pu = 10
	return s


# ==============================================================================
# Harvest Destruction Tests
# ==============================================================================

func test_can_destroy_harvest_requires_autumn() -> void:
	var r: Dictionary = StarvationWarfare.can_destroy_harvest("Yu", "spring", true)
	assert_false(r["allowed"])
	assert_eq(r["reason"], "wrong_season")


func test_can_destroy_harvest_requires_army() -> void:
	var r: Dictionary = StarvationWarfare.can_destroy_harvest("Yu", "autumn", false)
	assert_false(r["allowed"])
	assert_eq(r["reason"], "no_army_present")


func test_can_destroy_harvest_allowed_in_autumn_with_army() -> void:
	var r: Dictionary = StarvationWarfare.can_destroy_harvest("Yu", "autumn", true, true)
	assert_true(r["allowed"])


func test_jin_never_destroys_harvest() -> void:
	var r: Dictionary = StarvationWarfare.can_destroy_harvest("Jin", "autumn", true, true)
	assert_false(r["allowed"])
	assert_eq(r["reason"], "personality_block")


func test_gi_never_destroys_harvest() -> void:
	var r: Dictionary = StarvationWarfare.can_destroy_harvest("Gi", "autumn", true, true)
	assert_false(r["allowed"])
	assert_eq(r["reason"], "personality_block")


func test_rei_blocked_without_prior_demand() -> void:
	var without: Dictionary = StarvationWarfare.can_destroy_harvest("Rei", "autumn", true, false)
	assert_false(without["allowed"])
	assert_eq(without["reason"], "condition_not_met")
	assert_eq(without["condition"], "prior_formal_demand")
	var with_demand: Dictionary = StarvationWarfare.can_destroy_harvest("Rei", "autumn", true, true)
	assert_true(with_demand["allowed"])


func test_yu_only_if_no_other_path() -> void:
	var without: Dictionary = StarvationWarfare.can_destroy_harvest("Yu", "autumn", true, false)
	assert_false(without["allowed"])
	assert_eq(without["reason"], "condition_not_met")
	var with_cond: Dictionary = StarvationWarfare.can_destroy_harvest("Yu", "autumn", true, true)
	assert_true(with_cond["allowed"])


func test_meiyo_only_vs_hated_enemy() -> void:
	var without: Dictionary = StarvationWarfare.can_destroy_harvest("Meiyo", "autumn", true, false)
	assert_false(without["allowed"])
	var with_cond: Dictionary = StarvationWarfare.can_destroy_harvest("Meiyo", "autumn", true, true)
	assert_true(with_cond["allowed"])


func test_chugi_only_if_lord_commands() -> void:
	var without: Dictionary = StarvationWarfare.can_destroy_harvest("Chugi", "autumn", true, false)
	assert_false(without["allowed"])
	var with_cond: Dictionary = StarvationWarfare.can_destroy_harvest("Chugi", "autumn", true, true)
	assert_true(with_cond["allowed"])


func test_makoto_only_if_publicly_declared() -> void:
	var without: Dictionary = StarvationWarfare.can_destroy_harvest("Makoto", "autumn", true, false)
	assert_false(without["allowed"])
	var with_cond: Dictionary = StarvationWarfare.can_destroy_harvest("Makoto", "autumn", true, true)
	assert_true(with_cond["allowed"])


func test_shourido_always_considers() -> void:
	for virtue: String in ["Seigyo", "Ketsui", "Dosatsu", "Chishiki", "Kanpeki", "Ishi", "Kyoryoku"]:
		var r: Dictionary = StarvationWarfare.can_destroy_harvest(virtue, "autumn", true, false)
		assert_true(r["allowed"], "Shourido virtue %s should be allowed" % virtue)


func test_execute_harvest_destruction_returns_correct_effects() -> void:
	var result: Dictionary = StarvationWarfare.execute_harvest_destruction(5, "Lion", "Crane")
	assert_eq(result["province_id"], 5)
	assert_eq(result["ordering_clan"], "Lion")
	assert_eq(result["target_clan"], "Crane")
	assert_true(result["harvest_destroyed"])
	assert_almost_eq(result["honor_change"], -2.0, 0.01)
	assert_almost_eq(result["glory_change"], -0.5, 0.01)
	assert_eq(result["targeted_clan_disposition"], -20)
	assert_eq(result["other_clans_disposition"], -10)
	assert_true(result["generates_topic"])
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_2)


func test_apply_harvest_destruction_sets_flag() -> void:
	var meta: Dictionary = {}
	StarvationWarfare.apply_harvest_destruction(5, meta)
	assert_true(StarvationWarfare.is_harvest_destroyed(5, meta))


func test_harvest_flag_cleared_after_tick() -> void:
	var prov: ProvinceData = _make_province(1)
	var settlement: SettlementData = _make_settlement(10, 1, 5)
	var meta: Dictionary = {1: {"harvest_destroyed": true}}
	var result: Dictionary = ResourceTick._process_harvest([prov], [settlement], meta)
	assert_almost_eq(result[1]["yield"], 0.0, 0.01, "Destroyed harvest yields 0")
	assert_true(result[1]["destroyed"])
	assert_false(meta[1].get("harvest_destroyed", false), "Flag cleared after processing")


func test_harvest_recovers_next_year() -> void:
	var prov: ProvinceData = _make_province(1)
	var settlement: SettlementData = _make_settlement(10, 1, 5)
	var meta: Dictionary = {1: {"harvest_destroyed": true}}
	ResourceTick._process_harvest([prov], [settlement], meta)
	var second: Dictionary = ResourceTick._process_harvest([prov], [settlement], meta)
	assert_true(second[1]["yield"] > 0.0, "Harvest recovers after destruction year")
	assert_false(second[1]["destroyed"])


func test_generate_harvest_topic() -> void:
	var next_id: Array = [50]
	var topic: TopicData = StarvationWarfare.generate_harvest_topic("Lion", 5, next_id, 100)
	assert_eq(topic.topic_id, 50)
	assert_eq(next_id[0], 51)
	assert_eq(topic.tier, TopicData.Tier.TIER_2)
	assert_eq(topic.topic_type, "military")
	assert_eq(topic.variant, "harvest_destroyed")
	assert_eq(topic.clan_involved, "Lion")


func test_ai_harvest_decision_shourido() -> void:
	var r: Dictionary = StarvationWarfare.evaluate_ai_harvest_decision(
		"Ishi", "autumn", true,
	)
	assert_true(r["allowed"])


func test_ai_harvest_decision_jin_blocked() -> void:
	var r: Dictionary = StarvationWarfare.evaluate_ai_harvest_decision(
		"Jin", "autumn", true, true, true, true, true,
	)
	assert_false(r["allowed"])


# ==============================================================================
# Blockade Tests
# ==============================================================================

func test_blockade_requires_minimum_pu() -> void:
	var r: Dictionary = StarvationWarfare.can_blockade(0.5, true)
	assert_false(r["allowed"])
	assert_eq(r["reason"], "insufficient_pu")


func test_blockade_requires_route_node() -> void:
	var r: Dictionary = StarvationWarfare.can_blockade(2.0, false)
	assert_false(r["allowed"])
	assert_eq(r["reason"], "not_at_route_node")


func test_blockade_allowed_with_pu_and_node() -> void:
	var r: Dictionary = StarvationWarfare.can_blockade(1.0, true)
	assert_true(r["allowed"])


func test_execute_blockade_returns_effects() -> void:
	var result: Dictionary = StarvationWarfare.execute_blockade(10, "Crab", "Crane")
	assert_eq(result["route_id"], 10)
	assert_true(result["route_blocked"])
	assert_true(result["triggers_war_status"])
	assert_eq(result["disruption_reason"], "blockade_Crab")


func test_apply_blockade_disrupts_route() -> void:
	var route: TradeRouteData = _make_trade_route(1)
	StarvationWarfare.apply_blockade(route, "blockade_Crab")
	assert_true(route.is_disrupted)
	assert_eq(route.disruption_reason, "blockade_Crab")


func test_lift_blockade_restores_route() -> void:
	var route: TradeRouteData = _make_trade_route(1)
	StarvationWarfare.apply_blockade(route, "blockade_Crab")
	var lifted: bool = StarvationWarfare.lift_blockade(route, "Crab")
	assert_true(lifted)
	assert_false(route.is_disrupted)
	assert_eq(route.disruption_reason, "")


func test_lift_blockade_ignores_other_disruptions() -> void:
	var route: TradeRouteData = _make_trade_route(1)
	route.is_disrupted = true
	route.disruption_reason = "war_Crab_Crane"
	var lifted: bool = StarvationWarfare.lift_blockade(route, "Crab")
	assert_false(lifted)
	assert_true(route.is_disrupted)


func test_get_blockaded_routes() -> void:
	var r1: TradeRouteData = _make_trade_route(1)
	r1.is_disrupted = true
	r1.disruption_reason = "blockade_Crab"
	var r2: TradeRouteData = _make_trade_route(2)
	r2.is_disrupted = true
	r2.disruption_reason = "war_Lion_Crane"
	var r3: TradeRouteData = _make_trade_route(3)
	r3.is_disrupted = true
	r3.disruption_reason = "blockade_Crab"
	var result: Array = StarvationWarfare.get_blockaded_routes(
		[r1, r2, r3], "Crab",
	)
	assert_eq(result.size(), 2)


func test_seasonal_blockade_honor_cost() -> void:
	var route: TradeRouteData = _make_trade_route(1)
	route.is_disrupted = true
	route.disruption_reason = "blockade_Crab"
	var lord: L5RCharacterData = _make_character(1, "Crab", 6.0)
	var chars: Dictionary = {1: lord}
	var results: Array = StarvationWarfare.process_seasonal_blockade_honor(
		[route], chars,
	)
	assert_eq(results.size(), 1)
	assert_almost_eq(results[0]["honor_cost"], -0.5, 0.01)
	assert_eq(results[0]["routes_maintained"], 1)


func test_seasonal_blockade_honor_stacks_per_route() -> void:
	var r1: TradeRouteData = _make_trade_route(1)
	r1.is_disrupted = true
	r1.disruption_reason = "blockade_Crab"
	var r2: TradeRouteData = _make_trade_route(2)
	r2.is_disrupted = true
	r2.disruption_reason = "blockade_Crab"
	var lord: L5RCharacterData = _make_character(1, "Crab", 6.0)
	var chars: Dictionary = {1: lord}
	var results: Array = StarvationWarfare.process_seasonal_blockade_honor(
		[r1, r2], chars,
	)
	assert_eq(results.size(), 1)
	assert_almost_eq(results[0]["honor_cost"], -1.0, 0.01)
	assert_eq(results[0]["routes_maintained"], 2)


func test_seasonal_blockade_no_results_when_no_blockades() -> void:
	var route: TradeRouteData = _make_trade_route(1)
	var results: Array = StarvationWarfare.process_seasonal_blockade_honor(
		[route], {},
	)
	assert_eq(results.size(), 0)


# ==============================================================================
# Orchestrator Wiring Tests
# ==============================================================================

func test_orchestrator_harvest_destruction_creates_topic() -> void:
	var target_char: L5RCharacterData = _make_character(2, "Crane")
	var other_char: L5RCharacterData = _make_character(3, "Dragon")
	var attacker: L5RCharacterData = _make_character(1, "Lion")
	var chars_by_id: Dictionary = {1: attacker, 2: target_char, 3: other_char}
	var topics: Array = []
	var next_topic_id: Array = [100]
	var season_meta: Dictionary = {}

	var applied: Array = [{
		"character_id": 1,
		"action_id": "RAID_HARVEST",
		"effects": {
			"requires_harvest_destruction": true,
			"province_id": 5,
			"ordering_clan": "Lion",
			"target_clan": "Crane",
			"honor_change": -2.0,
			"glory_change": -0.5,
		},
	}]

	var results: Array = DayOrchestrator._process_starvation_warfare_effects(
		applied, chars_by_id, [], topics, next_topic_id, 100, season_meta, [], [1],
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "harvest_destruction")
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].tier, TopicData.Tier.TIER_2)
	assert_true(StarvationWarfare.is_harvest_destroyed(5, season_meta))


func test_orchestrator_harvest_applies_disposition() -> void:
	var target_char: L5RCharacterData = _make_character(2, "Crane")
	var other_char: L5RCharacterData = _make_character(3, "Dragon")
	var attacker: L5RCharacterData = _make_character(1, "Lion")
	var chars_by_id: Dictionary = {1: attacker, 2: target_char, 3: other_char}
	var topics: Array = []
	var next_topic_id: Array = [100]
	var season_meta: Dictionary = {}

	var applied: Array = [{
		"effects": {
			"requires_harvest_destruction": true,
			"province_id": 5,
			"ordering_clan": "Lion",
			"target_clan": "Crane",
		},
	}]

	DayOrchestrator._process_starvation_warfare_effects(
		applied, chars_by_id, [], topics, next_topic_id, 50, season_meta, [], [1],
	)

	# Harvest disposition modifiers removed — not in GDD s12.2 historical modifier table.
	# create_historical_modifier returns {} for unknown event types; no modifiers appended.
	assert_false(target_char.historical_modifiers.has("Lion"), "No modifier — event type not in GDD")
	assert_false(other_char.historical_modifiers.has("Lion"), "No modifier — event type not in GDD")
	assert_false(attacker.historical_modifiers.has("Lion"), "Attacker doesn't get self-modifier")


func test_orchestrator_blockade_disrupts_route_and_creates_war() -> void:
	var route: TradeRouteData = _make_trade_route(10, 1, 2)
	var topics: Array = []
	var next_topic_id: Array = [100]
	var wars: Array = []
	var next_war_id: Array = [1]

	var applied: Array = [{
		"effects": {
			"requires_blockade": true,
			"route_id": 10,
			"blocking_clan": "Crab",
			"target_clan": "Crane",
			"disruption_reason": "blockade_Crab",
			"triggers_war_status": true,
		},
	}]

	var results: Array = DayOrchestrator._process_starvation_warfare_effects(
		applied, {}, [route], topics, next_topic_id, 50, {}, wars, next_war_id,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "blockade")
	assert_true(route.is_disrupted)
	assert_eq(wars.size(), 1, "War should be created")
	assert_eq(wars[0].clan_a, "Crab")
	assert_eq(wars[0].clan_b, "Crane")
	assert_true(results[0]["war_created"])


func test_orchestrator_blockade_no_duplicate_war() -> void:
	var route: TradeRouteData = _make_trade_route(10, 1, 2)
	var existing_war: WarData = WarData.new()
	existing_war.war_id = 1
	existing_war.clan_a = "Crab"
	existing_war.clan_b = "Crane"
	existing_war.is_active = true
	var wars: Array = [existing_war]
	var next_war_id: Array = [2]

	var applied: Array = [{
		"effects": {
			"requires_blockade": true,
			"route_id": 10,
			"blocking_clan": "Crab",
			"target_clan": "Crane",
			"disruption_reason": "blockade_Crab",
			"triggers_war_status": true,
		},
	}]

	var results: Array = DayOrchestrator._process_starvation_warfare_effects(
		applied, {}, [route], [], [100], 50, {}, wars, next_war_id,
	)
	assert_eq(wars.size(), 1, "No duplicate war")
	assert_false(results[0]["war_created"])


func test_disposition_system_harvest_events_removed() -> void:
	# Harvest disposition modifiers removed — not in GDD s12.2 historical modifier table.
	var mod: Dictionary = DispositionSystem.create_historical_modifier("destroyed_harvest", 100)
	assert_true(mod.is_empty())
	var witness_mod: Dictionary = DispositionSystem.create_historical_modifier(
		"witnessed_harvest_destruction", 100,
	)
	assert_true(witness_mod.is_empty())


func test_imperial_edict_consequence() -> void:
	var result: Dictionary = StarvationWarfare.apply_imperial_edict_consequence(
		1, "Crane", {},
	)
	assert_almost_eq(result["lord_honor_cost"], -3.0, 0.01)
	assert_eq(result["sympathy_bonus"], 5)
	assert_eq(result["sympathy_clan"], "Crane")


# ==============================================================================
# NPC Engine: Harvest Condition Evaluation Tests
# ==============================================================================

func _make_ctx_for_harvest(virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> NPCDataStructures.ContextSnapshot:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = virtue
	ctx.shourido_virtue = shourido
	ctx.clan = "Lion"
	ctx.active_wars = []
	ctx.disposition_values = {}
	ctx.pending_events = []
	ctx.action_log = []
	return ctx


func test_harvest_conditions_no_other_path_when_desperate() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	ctx.active_wars = [{"war_score": 20}]
	var conditions: Dictionary = NPCDecisionEngine._evaluate_harvest_conditions(ctx)
	assert_true(conditions["no_other_path"])


func test_harvest_conditions_no_other_path_false_when_ahead() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	ctx.active_wars = [{"war_score": 60}]
	var conditions: Dictionary = NPCDecisionEngine._evaluate_harvest_conditions(ctx)
	assert_false(conditions["no_other_path"])


func test_harvest_conditions_hated_enemy_when_blood_enemy() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	ctx.disposition_values = {5: -60}
	var conditions: Dictionary = NPCDecisionEngine._evaluate_harvest_conditions(ctx)
	assert_true(conditions["hated_enemy"])


func test_harvest_conditions_hated_enemy_false_for_rival() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	ctx.disposition_values = {5: -30}
	var conditions: Dictionary = NPCDecisionEngine._evaluate_harvest_conditions(ctx)
	assert_false(conditions["hated_enemy"])


func test_harvest_conditions_lord_commands() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	ctx.pending_events = [{"need_type": "RAID_HARVEST"}]
	var conditions: Dictionary = NPCDecisionEngine._evaluate_harvest_conditions(ctx)
	assert_true(conditions["lord_commands"])


func test_harvest_conditions_publicly_declared() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	ctx.action_log = [{"action_id": "PUBLIC_DECLARATION"}]
	var conditions: Dictionary = NPCDecisionEngine._evaluate_harvest_conditions(ctx)
	assert_true(conditions["publicly_declared"])


func test_harvest_blocked_jin_always() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.JIN)
	assert_true(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_blocked_gi_always() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.GI)
	assert_true(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_blocked_rei_always() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.REI)
	assert_true(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_not_blocked_yu_when_desperate() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.YU)
	ctx.active_wars = [{"war_score": 15}]
	assert_false(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_blocked_yu_when_not_desperate() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.YU)
	ctx.active_wars = [{"war_score": 60}]
	assert_true(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_not_blocked_meiyo_vs_blood_enemy() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.MEIYO)
	ctx.disposition_values = {5: -60}
	assert_false(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_blocked_meiyo_without_enemy() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.MEIYO)
	ctx.disposition_values = {5: -10}
	assert_true(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_not_blocked_chugi_when_lord_commands() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.CHUGI)
	ctx.pending_events = [{"need_type": "RAID_HARVEST"}]
	assert_false(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_not_blocked_makoto_when_publicly_declared() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(Enums.BushidoVirtue.MAKOTO)
	ctx.action_log = [{"action_id": "PUBLIC_DECLARATION"}]
	assert_false(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


func test_harvest_not_blocked_shourido() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI,
	)
	assert_false(NPCDecisionEngine._is_harvest_blocked_by_virtue(ctx))


# -- Metadata Population Tests ---------------------------------------------------

func test_raid_harvest_metadata_populates_clans() -> void:
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.target_province_id = 5
	need.target_clan_id = "Crane"
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	var meta: Dictionary = NPCDecisionEngine._build_raid_harvest_metadata(need, ctx)
	assert_eq(meta["target_province_id"], 5)
	assert_eq(meta["target_clan"], "Crane")
	assert_eq(meta["ordering_clan"], "Lion")


func test_raid_harvest_metadata_looks_up_clan_from_province_status() -> void:
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.target_province_id = 5
	need.target_clan_id = ""
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	var ps: NPCDataStructures.ProvinceStatus = NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 5
	ps.clan = "Crane"
	ctx.province_statuses = [ps]
	var meta: Dictionary = NPCDecisionEngine._build_raid_harvest_metadata(need, ctx)
	assert_eq(meta["target_clan"], "Crane")


func test_blockade_metadata_populates() -> void:
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.target_clan_id = "Crane"
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_harvest()
	var meta: Dictionary = NPCDecisionEngine._build_blockade_metadata(need, ctx)
	assert_eq(meta["blocking_clan"], "Lion")
	assert_eq(meta["target_clan"], "Crane")


func test_find_clan_lord_skips_dead_characters() -> void:
	var alive := L5RCharacterData.new()
	alive.character_id = 10
	alive.clan = "Crane"
	alive.status = 6.0
	var dead := L5RCharacterData.new()
	dead.character_id = 11
	dead.clan = "Crane"
	dead.status = 8.0
	dead.wounds_taken = 999
	var chars: Dictionary = {10: alive, 11: dead}
	var result: int = StarvationWarfare._find_clan_lord("Crane", chars)
	assert_eq(result, 10, "Should pick living character, not dead one with higher status")
