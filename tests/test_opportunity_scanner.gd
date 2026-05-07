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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "MILITARY_DOMINANCE", world_state
	)
	for opp: OpportunityScanner.Opportunity in opps:
		assert_ne(opp.objective_type, "BUILD_STRONGEST_FORCE")


func test_scan_military_taint_detected() -> void:
	var c := _make_character(1, "Crab")
	var world_state: Dictionary = {
		"border_weaknesses": [],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [7],
	}
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
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
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "EXPAND_TERRITORY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].personality_fit, 90.0)


func test_personality_fit_jin_dislikes_military() -> void:
	var c := _make_character(1, "Crane", Enums.BushidoVirtue.JIN)
	var world_state: Dictionary = {
		"border_weaknesses": [{"province_id": 10, "feasibility": 70.0}],
		"active_insurgencies": [],
		"known_clan_strengths": {},
		"taint_topic_province_ids": [],
	}
	var opps: Array[OpportunityScanner.Opportunity] = OpportunityScanner.scan_opportunities(
		c, OpportunityScanner.DOMAIN_MILITARY, "EXPAND_TERRITORY", world_state
	)
	assert_gt(opps.size(), 0)
	assert_eq(opps[0].personality_fit, 20.0)


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
