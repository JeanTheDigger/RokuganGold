extends GutTest


func _make_character(
	id: int = 1,
	clan: String = "Crane",
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.REI,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.bushido_virtue = bushido
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.honor = 5.0
	c.glory = 4.0
	c.status = 5.0
	return c


# =============================================================================
# Self-Selection Timing
# =============================================================================

func test_chugi_never_self_selects() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.CHUGI)
	assert_false(OpportunityScanner.can_self_select(c, 10))


func test_seigyo_self_selects_after_1_season() -> void:
	var c := _make_character()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	assert_false(OpportunityScanner.can_self_select(c, 0))
	assert_true(OpportunityScanner.can_self_select(c, 1))


func test_ishi_self_selects_after_1_season() -> void:
	var c := _make_character()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.ISHI
	assert_true(OpportunityScanner.can_self_select(c, 1))


func test_makoto_self_selects_after_2_seasons() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.MAKOTO)
	assert_false(OpportunityScanner.can_self_select(c, 1))
	assert_true(OpportunityScanner.can_self_select(c, 2))


func test_default_self_selects_after_3_seasons() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.GI)
	assert_false(OpportunityScanner.can_self_select(c, 2))
	assert_true(OpportunityScanner.can_self_select(c, 3))


# =============================================================================
# Opportunity Scoring
# =============================================================================

func test_opportunity_score_weighted() -> void:
	var opp := OpportunityScanner.Opportunity.new()
	opp.standing_alignment = 100.0
	opp.feasibility = 100.0
	opp.urgency = 100.0
	opp.personality_fit = 100.0
	assert_almost_eq(opp.get_score(), 100.0, 0.01)


func test_opportunity_score_partial() -> void:
	var opp := OpportunityScanner.Opportunity.new()
	opp.standing_alignment = 80.0
	opp.feasibility = 60.0
	opp.urgency = 40.0
	opp.personality_fit = 20.0
	# 80*0.4 + 60*0.3 + 40*0.2 + 20*0.1 = 32 + 18 + 8 + 2 = 60
	assert_almost_eq(opp.get_score(), 60.0, 0.01)


# =============================================================================
# Political Scanning
# =============================================================================

func test_scan_political_weak_neighbors() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [{"clan": "Lion", "stability": 20.0}],
		"rising_clans": [],
		"upcoming_courts": [],
		"secrets_held": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_POLITICAL, "MAINTAIN_PEACE", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].objective_type, "SECURE_ALLIANCE")
	assert_eq(opps[0].standing_alignment, 70.0)


func test_scan_political_rising_clan() -> void:
	var c := _make_character(1, "Crane")
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [],
		"rising_clans": [{"clan": "Lion", "urgency": 55.0}],
		"upcoming_courts": [],
		"secrets_held": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_POLITICAL, "ADVANCE_FAMILY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].objective_type, "ISOLATE_CHARACTER")
	assert_eq(opps[0].standing_alignment, 80.0)


func test_scan_political_skips_own_clan() -> void:
	var c := _make_character(1, "Lion")
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [],
		"rising_clans": [{"clan": "Lion", "urgency": 55.0}],
		"upcoming_courts": [],
		"secrets_held": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_POLITICAL, "ADVANCE_FAMILY", world_state
	)
	assert_eq(opps.size(), 0)


func test_scan_political_secrets() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [],
		"rising_clans": [],
		"upcoming_courts": [],
		"secrets_held": [{"target_id": 5}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_POLITICAL, "ACCUMULATE_LEVERAGE", world_state
	)
	var expose_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "EXPOSE_SECRET":
			expose_found = true
			assert_eq(opp.standing_alignment, 90.0)
	assert_true(expose_found)


# =============================================================================
# Military Scanning
# =============================================================================

func test_scan_military_border_weakness() -> void:
	var c := _make_character(1, "Lion", Enums.BushidoVirtue.YU)
	var world_state: Dictionary = {
		"border_weaknesses": [{"province_id": 10, "feasibility": 70.0}],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "EXPAND_TERRITORY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].objective_type, "CONQUER_PROVINCE")
	assert_eq(opps[0].standing_alignment, 100.0)
	assert_eq(opps[0].feasibility, 70.0)


func test_scan_military_rival_stronger() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.YU)
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {"Crane": 20.0, "Lion": 30.0},
		"taint_topic_province_ids": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "MILITARY_DOMINANCE", world_state
	)
	var build_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "BUILD_STRONGEST_FORCE":
			build_found = true
			assert_eq(opp.standing_alignment, 90.0)
	assert_true(build_found)


func test_scan_military_no_imbalance() -> void:
	var c := _make_character(1, "Crane")
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {"Crane": 25.0, "Lion": 25.0},
		"taint_topic_province_ids": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "MILITARY_DOMINANCE", world_state
	)
	for opp: OpportunityScanner.Opportunity in opps:
		assert_ne(opp.objective_type, "BUILD_STRONGEST_FORCE")
	pass_test("No BUILD_STRONGEST_FORCE opportunity when clans are balanced")


func test_scan_military_taint_detected() -> void:
	var c := _make_character(1, "Crab")
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [7],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "STRENGTHEN_WALL", world_state
	)
	var shadow_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ELIMINATE_SHADOWLANDS":
			shadow_found = true
			assert_eq(opp.urgency, 90.0)
	assert_true(shadow_found)


# =============================================================================
# Economic Scanning
# =============================================================================

func test_scan_economic_resource_deficit() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"resource_deficits": [{"resource": "rice", "urgency": 70.0}],
		"famine_provinces": [],
		"low_koku_provinces": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_ECONOMIC, "MAXIMIZE_PROSPERITY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].objective_type, "PREVENT_SHORTAGE")
	assert_eq(opps[0].standing_alignment, 85.0)


func test_scan_economic_famine_high_urgency() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"resource_deficits": [],
		"famine_provinces": [{"province_id": 3}],
		"low_koku_provinces": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_ECONOMIC, "MAXIMIZE_PROSPERITY", world_state
	)
	var famine_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.urgency == 90.0:
			famine_found = true
	assert_true(famine_found)


# =============================================================================
# Personal Scanning
# =============================================================================

func test_scan_personal_low_honor() -> void:
	var c := _make_character()
	c.honor = 2.0
	var world_state: Dictionary = {
		"vengeance_targets": [],
		"trainable_vassals": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "SEEK_GLORY", world_state
	)
	var honor_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "RESTORE_HONOR":
			honor_found = true
			assert_eq(opp.standing_alignment, 80.0)
	assert_true(honor_found)


func test_scan_personal_glory_gap() -> void:
	var c := _make_character()
	c.glory = 2.0
	c.status = 5.0
	var world_state: Dictionary = {
		"vengeance_targets": [],
		"trainable_vassals": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "SEEK_GLORY", world_state
	)
	var glory_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "SEEK_GLORY":
			glory_found = true
			assert_eq(opp.standing_alignment, 90.0)
	assert_true(glory_found)


func test_scan_personal_vengeance() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"vengeance_targets": [{"target_id": 99, "feasibility": 60.0}],
		"trainable_vassals": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "SEEK_VENGEANCE", world_state
	)
	var avenge_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "AVENGE":
			avenge_found = true
			assert_eq(opp.standing_alignment, 100.0)
			assert_eq(opp.feasibility, 60.0)
	assert_true(avenge_found)


# =============================================================================
# Full Selection
# =============================================================================

func test_select_best_objective() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.REI)
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [{"clan": "Dragon", "stability": 30.0}],
		"rising_clans": [],
		"upcoming_courts": [{"id": 1}],
		"secrets_held": [],
	}
	var result: Dictionary = OpportunityScanner.select_primary_objective(
		c, "MAINTAIN_PEACE", world_state
	)
	assert_false(result.is_empty())
	assert_true(result.has("objective_type"))
	assert_eq(result["source"], "SELF_SELECTED")


func test_select_returns_empty_when_no_opportunities() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [],
		"rising_clans": [],
		"upcoming_courts": [],
		"secrets_held": [],
	}
	var result: Dictionary = OpportunityScanner.select_primary_objective(
		c, "MAINTAIN_PEACE", world_state
	)
	assert_true(result.is_empty())


func test_personality_fit_yu_prefers_military() -> void:
	var c := _make_character(1, "Lion", Enums.BushidoVirtue.YU)
	var world_state: Dictionary = {
		"border_weaknesses": [{"province_id": 10, "feasibility": 70.0}],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "EXPAND_TERRITORY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].personality_fit, 80.0)


func test_personality_fit_jin_dislikes_military() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.JIN)
	var world_state: Dictionary = {
		"border_weaknesses": [{"province_id": 10, "feasibility": 70.0}],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "EXPAND_TERRITORY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].personality_fit, 20.0)


# =============================================================================
# New Opportunity Types
# =============================================================================

func test_scan_political_unmarried_family() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"weak_neighbor_provinces": [],
		"rising_clans": [],
		"upcoming_courts": [],
		"secrets_held": [],
		"unmarried_family_members": [{"character_id": 5, "urgency": 40.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_POLITICAL, "ADVANCE_FAMILY", world_state
	)
	var marriage_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARRANGE_MARRIAGE":
			marriage_found = true
			assert_eq(opp.standing_alignment, 80.0)
	assert_true(marriage_found)


func test_scan_military_threatened_province() -> void:
	var c := _make_character(1, "Crab", Enums.BushidoVirtue.CHUGI)
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
		"threatened_provinces": [{"province_id": 3, "feasibility": 55.0, "urgency": 80.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "EXPAND_TERRITORY", world_state
	)
	var defend_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "DEFEND_PROVINCE":
			defend_found = true
			assert_eq(opp.standing_alignment, 90.0)
			assert_eq(opp.urgency, 80.0)
	assert_true(defend_found)


func test_scan_military_sieged_ally() -> void:
	var c := _make_character(1, "Lion", Enums.BushidoVirtue.YU)
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
		"sieged_allies": [{"province_id": 8, "feasibility": 45.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "MAINTAIN_PEACE", world_state
	)
	var siege_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "RELIEVE_SIEGE":
			siege_found = true
			assert_eq(opp.standing_alignment, 85.0)
			assert_eq(opp.urgency, 80.0)
	assert_true(siege_found)


func test_scan_military_tainted_province() -> void:
	var c := _make_character(1, "Crab")
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
		"tainted_provinces": [{"province_id": 12, "urgency": 85.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "ELIMINATE_SHADOWLANDS", world_state
	)
	var taint_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "MANAGE_TAINT":
			taint_found = true
			assert_eq(opp.standing_alignment, 90.0)
	assert_true(taint_found)


func test_scan_military_insurgent_province() -> void:
	var c := _make_character(1, "Lion")
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
		"insurgent_provinces": [{"province_id": 6, "urgency": 65.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "UPHOLD_LAW", world_state
	)
	var patrol_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "PATROL_PROVINCE":
			patrol_found = true
			assert_eq(opp.standing_alignment, 80.0)
	assert_true(patrol_found)


func test_scan_military_levy_at_moderate_imbalance() -> void:
	var c := _make_character(1, "Crane")
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {"Crane": 20.0, "Lion": 24.0},
		"taint_topic_province_ids": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "BUILD_STRONGEST_FORCE", world_state
	)
	var levy_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "LEVY_TROOPS":
			levy_found = true
			assert_eq(opp.standing_alignment, 75.0)
	assert_true(levy_found)


func test_scan_economic_critical_resource_need() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"resource_deficits": [],
		"famine_provinces": [],
		"low_koku_provinces": [],
		"critical_resource_needs": [{"resource": "iron", "threshold": 100.0, "urgency": 75.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_ECONOMIC, "MAXIMIZE_PROSPERITY", world_state
	)
	var acquire_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ACQUIRE_RESOURCE":
			acquire_found = true
			assert_eq(opp.standing_alignment, 80.0)
	assert_true(acquire_found)


func test_scan_economic_threatened_trade_route() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"resource_deficits": [],
		"famine_provinces": [],
		"low_koku_provinces": [],
		"threatened_trade_routes": [{"province_id": 15, "urgency": 60.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_ECONOMIC, "CONTROL_TRADE", world_state
	)
	var route_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "SECURE_TRADE_ROUTE":
			route_found = true
			assert_eq(opp.standing_alignment, 90.0)
	assert_true(route_found)


func test_scan_personal_bitter_rival() -> void:
	var c := _make_character(1, "Scorpion", Enums.BushidoVirtue.YU)
	var world_state: Dictionary = {
		"vengeance_targets": [],
		"trainable_vassals": [],
		"bitter_rivals": [{"target_id": 42, "feasibility": 35.0, "urgency": 55.0}],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "SEEK_VENGEANCE", world_state
	)
	var elim_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ELIMINATE_CHARACTER":
			elim_found = true
			assert_eq(opp.standing_alignment, 70.0)
	assert_true(elim_found)


func test_standing_domain_maps_all_objectives() -> void:
	var all_standing: Array = []
	all_standing.append_array(ObjectiveDecomposer.POLITICAL_OBJECTIVES)
	all_standing.append_array(ObjectiveDecomposer.ECONOMIC_OBJECTIVES)
	all_standing.append_array(ObjectiveDecomposer.PERSONAL_OBJECTIVES)
	all_standing.append_array(ObjectiveDecomposer.MILITARY_OBJECTIVES)
	all_standing.append_array(ObjectiveDecomposer.INVESTIGATION_OBJECTIVES)
	all_standing.append_array(ObjectiveDecomposer.INFRASTRUCTURE_OBJECTIVES)
	all_standing.append_array(ObjectiveDecomposer.GOVERNANCE_OBJECTIVES)
	for obj: String in all_standing:
		assert_true(
			OpportunityScanner.STANDING_OBJECTIVE_DOMAIN.has(obj),
			obj + " should be in STANDING_OBJECTIVE_DOMAIN"
		)


func test_tiebreak_urgency_first() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"resource_deficits": [
			{"resource": "rice", "urgency": 50.0},
			{"resource": "iron", "urgency": 80.0},
		],
		"famine_provinces": [],
		"low_koku_provinces": [],
	}
	var result: Dictionary = OpportunityScanner.select_primary_objective(
		c, "MAXIMIZE_PROSPERITY", world_state
	)
	assert_false(result.is_empty())
	assert_eq(result["target_fields"]["target_resource"], "iron")


func test_scan_personal_trainable_vassal_creates_mentor_opportunity() -> void:
	var c := _make_character()
	var world_state: Dictionary = {
		"trainable_vassals": [{"vassal_id": 42}],
		"vengeance_targets": [],
	}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", world_state
	)
	var mentor_found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "MENTOR_CHARACTER":
			mentor_found = true
			assert_eq(opp.target_fields.get("target_npc_id", -1), 42)
			assert_eq(opp.standing_alignment, 60.0)
			assert_eq(opp.feasibility, 85.0)
	assert_true(mentor_found, "Should create MENTOR_CHARACTER opportunity from trainable vassal")


# =============================================================================
# §57.22.11 ARTISTIC_EXPRESSION Self-Selection
# =============================================================================

func _make_art_character(
	id: int = 1,
	poetry: int = 3,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.REI,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := _make_character(id, "Crane", bushido)
	c.shourido_virtue = shourido
	c.skills = {"Poetry": poetry}
	c.disposition_values = {42: 20.0}  # strong positive disposition by default
	c.objectives_map = {}
	return c


func _art_world_state(clan_at_war: String = "") -> Dictionary:
	var wars: Array = []
	if not clan_at_war.is_empty():
		wars.append({"clan_a": clan_at_war, "clan_b": "Lion"})
	return {"active_wars": wars}


func test_artistic_expression_blocked_no_poetry() -> void:
	# Condition 1: Poetry rank 0 → no ARTISTIC_EXPRESSION opportunity.
	var c := _make_art_character(1, 0)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		assert_ne(opp.objective_type, "ARTISTIC_EXPRESSION")


func test_artistic_expression_blocked_active_objective() -> void:
	# Condition 2: Already has ARTISTIC_EXPRESSION as primary objective → blocked.
	var c := _make_art_character()
	c.objectives_map = {"primary": {"need_type": "ARTISTIC_EXPRESSION"}}
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		assert_ne(opp.objective_type, "ARTISTIC_EXPRESSION")


func test_artistic_expression_blocked_active_war() -> void:
	# Condition 3: Character's clan is in an active war → blocked.
	var c := _make_art_character()
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state("Crane")
	)
	for opp: OpportunityScanner.Opportunity in opps:
		assert_ne(opp.objective_type, "ARTISTIC_EXPRESSION")


func test_artistic_expression_blocked_no_strong_disposition() -> void:
	# Condition 4: No disposition >= ±11 → blocked (no subject to write about).
	var c := _make_art_character()
	c.disposition_values = {42: 5.0, 43: -3.0}  # all weak
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		assert_ne(opp.objective_type, "ARTISTIC_EXPRESSION")


func test_artistic_expression_returns_opportunity_on_success() -> void:
	# All conditions met → ARTISTIC_EXPRESSION opportunity returned.
	var c := _make_art_character()
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	var found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			found = true
			assert_almost_eq(opp.urgency, 20.0, 0.01)
	assert_true(found, "Should return ARTISTIC_EXPRESSION opportunity when all conditions met")


func test_artistic_expression_feasibility_formula() -> void:
	# feasibility = min(50 + Poetry * 10, 90). Poetry=3 → 80.
	var c := _make_art_character(1, 3)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.feasibility, 80.0, 0.01)


func test_artistic_expression_feasibility_capped_at_90() -> void:
	# Poetry=5 → min(100, 90) = 90.
	var c := _make_art_character(1, 5)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.feasibility, 90.0, 0.01)


func test_artistic_expression_personality_jin() -> void:
	# JIN → personality_fit = 90.
	var c := _make_art_character(1, 3, Enums.BushidoVirtue.JIN)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.personality_fit, 90.0, 0.01)


func test_artistic_expression_personality_rei() -> void:
	# REI → personality_fit = 85.
	var c := _make_art_character(1, 3, Enums.BushidoVirtue.REI)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.personality_fit, 85.0, 0.01)


func test_artistic_expression_personality_gi_domain_match() -> void:
	# GI prefers DOMAIN_PERSONAL → personality_fit = 80 (domain match short-circuits).
	var c := _make_art_character(1, 3, Enums.BushidoVirtue.GI)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.personality_fit, 80.0, 0.01)


func test_artistic_expression_personality_seigyo() -> void:
	# SEIGYO → personality_fit = 20.
	var c := _make_art_character(1, 3, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.personality_fit, 20.0, 0.01)


func test_artistic_expression_personality_ketsui() -> void:
	# KETSUI → personality_fit = 30.
	var c := _make_art_character(1, 3, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI)
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", _art_world_state()
	)
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			assert_almost_eq(opp.personality_fit, 30.0, 0.01)


func test_artistic_expression_no_crash_without_objectives_map() -> void:
	# character.objectives_map is not a declared field; must not crash when unset.
	# Uses character.get("objectives_map", {}) instead of character.objectives_map.
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Crane"
	c.bushido_virtue = Enums.BushidoVirtue.REI
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.honor = 5.0
	c.glory = 4.0
	c.status = 5.0
	c.skills = {"Poetry": 3}
	c.disposition_values = {42: 20.0}
	# Deliberately do NOT set c.objectives_map — verify no crash
	var opps: Array = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_PERSONAL, "PERSONAL_EXCELLENCE", {"active_wars": []}
	)
	var found: bool = false
	for opp: OpportunityScanner.Opportunity in opps:
		if opp.objective_type == "ARTISTIC_EXPRESSION":
			found = true
	assert_true(found, "Should find ARTISTIC_EXPRESSION without objectives_map set")
