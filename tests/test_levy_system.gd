extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_candidate(id: int, role: String = "uncommitted") -> Dictionary:
	return {"character_id": id, "role": role}


# -- Can Raise Levy Tests -------------------------------------------------------

func test_can_raise_with_available_pu() -> void:
	var r: Dictionary = LevySystem.can_raise_levy(
		2.0, 0.5, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	assert_true(r["can_raise"])


func test_cannot_raise_insufficient_pu() -> void:
	var r: Dictionary = LevySystem.can_raise_levy(
		0.5, 0.5, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	assert_false(r["can_raise"])
	assert_eq(r["reason"], "insufficient_pu")


func test_cannot_raise_invalid_unit_type() -> void:
	var r: Dictionary = LevySystem.can_raise_levy(
		5.0, 0.5, Enums.CompanyUnitType.BUSHI_RETAINER,
	)
	assert_false(r["can_raise"])
	assert_eq(r["reason"], "invalid_unit_type")


func test_can_raise_ashigaru_spearmen() -> void:
	var r: Dictionary = LevySystem.can_raise_levy(
		2.0, 0.0, Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
	)
	assert_true(r["can_raise"])


func test_can_raise_ashigaru_archers() -> void:
	var r: Dictionary = LevySystem.can_raise_levy(
		2.0, 0.0, Enums.CompanyUnitType.ASHIGARU_ARCHERS,
	)
	assert_true(r["can_raise"])


# -- Raise Levy Tests -----------------------------------------------------------

func test_raise_levy_creates_company() -> void:
	var r: Dictionary = LevySystem.raise_levy(
		1, Enums.CompanyUnitType.PEASANT_LEVY, 100, 10, 20,
	)
	assert_true(r["success"])
	var c: MilitaryUnitData.CompanyData = r["company"]
	assert_eq(c.company_id, 1)
	assert_eq(c.unit_type, Enums.CompanyUnitType.PEASANT_LEVY)
	assert_eq(c.parent_legion_id, -1)
	assert_eq(c.source_province_id, 10)


func test_raise_levy_returns_arms_cost() -> void:
	var r: Dictionary = LevySystem.raise_levy(
		1, Enums.CompanyUnitType.ASHIGARU_SPEARMEN, 100, 10, 20,
	)
	assert_almost_eq(r["arms_cost"], 1.0, 0.01)


func test_raise_levy_invalid_type() -> void:
	var r: Dictionary = LevySystem.raise_levy(
		1, Enums.CompanyUnitType.BUSHI_RETAINER, 100, 10, 20,
	)
	assert_false(r["success"])


func test_raise_levy_pu_consumed() -> void:
	var r: Dictionary = LevySystem.raise_levy(
		1, Enums.CompanyUnitType.PEASANT_LEVY, 100, 10, 20,
	)
	assert_almost_eq(r["pu_consumed"], 1.0, 0.01)


# -- Assign Commander Tests ------------------------------------------------------

func test_assign_commander() -> void:
	var company: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	LevySystem.assign_commander(company, 42)
	assert_eq(company.commander_id, 42)


# -- Disband Tests ---------------------------------------------------------------

func test_disband_full_health() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	c.health = 153  # full starting health per GDD s11.7
	var r: Dictionary = LevySystem.disband_levy(c)
	assert_almost_eq(r["pu_returned"], 1.0, 0.01)
	assert_true(r["arms_retained"])


func test_disband_half_health() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	c.health = 76  # ~half of 153; 76/153 ≈ 0.497
	var r: Dictionary = LevySystem.disband_levy(c)
	assert_almost_eq(r["pu_returned"], 0.5, 0.01)


func test_disband_zero_health() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	c.health = 0
	var r: Dictionary = LevySystem.disband_levy(c)
	assert_almost_eq(r["pu_returned"], 0.0, 0.01)


# -- Suspicion Tests -------------------------------------------------------------

func test_no_suspicion_wartime() -> void:
	var r: Dictionary = LevySystem.check_suspicion(5, true)
	assert_false(r["suspicion"])


func test_no_suspicion_under_threshold() -> void:
	var r: Dictionary = LevySystem.check_suspicion(0, false)
	assert_false(r["suspicion"])


func test_suspicion_at_threshold() -> void:
	var r: Dictionary = LevySystem.check_suspicion(1, false)
	assert_true(r["suspicion"])
	assert_eq(r["topic_tier"], 4)
	assert_false(r["escalated"])


func test_suspicion_two_seasons() -> void:
	var r: Dictionary = LevySystem.check_suspicion(2, false)
	assert_true(r["suspicion"])
	assert_eq(r["topic_tier"], 4)
	assert_eq(r["disposition_loss_lord"], -10)


func test_suspicion_escalates_at_three() -> void:
	var r: Dictionary = LevySystem.check_suspicion(3, false)
	assert_true(r["suspicion"])
	assert_eq(r["topic_tier"], 3)
	assert_true(r["escalated"])
	assert_eq(r["disposition_loss_lord"], -15)


func test_suspicion_neighbor_loss() -> void:
	var r: Dictionary = LevySystem.check_suspicion(2, false)
	assert_eq(r["disposition_loss_neighbor"], -3)


# -- Commitment Protection Tests -------------------------------------------------

func test_commitment_uncommitted() -> void:
	assert_eq(LevySystem.get_commitment_score("uncommitted"), 0)


func test_commitment_yojimbo_high() -> void:
	assert_eq(LevySystem.get_commitment_score("yojimbo_high_status"), -30)


func test_commitment_magistrate_insurgency() -> void:
	assert_eq(LevySystem.get_commitment_score("magistrate_insurgency"), -25)


func test_commitment_yoriki_idle() -> void:
	assert_eq(LevySystem.get_commitment_score("yoriki_idle"), -5)


# -- Personality Modified Commitment Tests ---------------------------------------

func test_jin_doubles_yojimbo_penalty() -> void:
	var score: int = LevySystem.evaluate_candidate("yojimbo_high_status", "Jin")
	assert_eq(score, -60)


func test_yu_halves_penalties() -> void:
	var score: int = LevySystem.evaluate_candidate("magistrate_insurgency", "Yu")
	assert_eq(score, -12)


func test_chugi_reduces_penalties() -> void:
	var score: int = LevySystem.evaluate_candidate("magistrate_stable", "Chugi")
	# -15 - (-10) = -5
	assert_eq(score, -5)


func test_uncommitted_no_personality_effect() -> void:
	var score: int = LevySystem.evaluate_candidate("uncommitted", "Jin")
	assert_eq(score, 0)


# -- Rank Candidates Tests -------------------------------------------------------

func test_rank_candidates_uncommitted_first() -> void:
	var candidates: Array[Dictionary] = [
		_make_candidate(1, "magistrate_stable"),
		_make_candidate(2, "uncommitted"),
		_make_candidate(3, "yoriki_idle"),
	]
	var ranked: Array[Dictionary] = LevySystem.rank_candidates(candidates, "")
	assert_eq(ranked[0]["character_id"], 2)


func test_rank_candidates_yu_reorders() -> void:
	var candidates: Array[Dictionary] = [
		_make_candidate(1, "magistrate_insurgency"),
		_make_candidate(2, "uncommitted"),
	]
	var ranked: Array[Dictionary] = LevySystem.rank_candidates(candidates, "Yu")
	# Yu halves penalties: magistrate = -12, uncommitted = 0
	assert_eq(ranked[0]["character_id"], 2)
	assert_eq(ranked[1]["commitment_score"], -12)


# -- Dual Authority Tests --------------------------------------------------------

func test_dual_authority_daimyo_taisa() -> void:
	assert_true(LevySystem.has_dual_authority(true, Enums.MilitaryRank.TAISA))


func test_no_dual_authority_not_daimyo() -> void:
	assert_false(LevySystem.has_dual_authority(false, Enums.MilitaryRank.TAISA))


func test_no_dual_authority_low_rank() -> void:
	assert_false(LevySystem.has_dual_authority(true, Enums.MilitaryRank.CHUI))


func test_dual_authority_daimyo_shireikan() -> void:
	assert_true(LevySystem.has_dual_authority(true, Enums.MilitaryRank.SHIREIKAN))


# -- Max Levy Companies Tests ----------------------------------------------------

func test_max_levy_companies() -> void:
	assert_eq(LevySystem.get_max_levy_companies(3.0, 0.5), 2)


func test_max_levy_companies_zero() -> void:
	assert_eq(LevySystem.get_max_levy_companies(0.5, 0.5), 0)


func test_max_levy_companies_large() -> void:
	assert_eq(LevySystem.get_max_levy_companies(5.0, 1.0), 4)


# -- Disposition Loss Application Tests (s11.7a) --------------------------------

func _make_lord_char(
	id: int, clan: String, lord_id: int, status: float,
) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.lord_id = lord_id
	c.status = status
	return c


func _make_levy_company(lord_id: int, raised_season: int) -> Dictionary:
	return {
		"company_id": 1,
		"lord_id": lord_id,
		"army_id": -1,
		"destroyed": false,
		"levy_raised_season": raised_season,
	}


func test_suspicion_applies_disposition_to_family_daimyo() -> void:
	var lord: L5RCharacterData = _make_lord_char(10, "Crab", 20, 5.0)
	var family_daimyo: L5RCharacterData = _make_lord_char(20, "Crab", -1, 6.0)
	var characters_by_id: Dictionary = {10: lord, 20: family_daimyo}
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1]
	DayOrchestrator._process_levy_suspicion(
		[_make_levy_company(10, 0)], [], characters_by_id,
		topics, next_topic_id, 90, 1,
	)
	assert_lt(family_daimyo.disposition_values.get(10, 0), 0)


func test_suspicion_applies_disposition_to_clan_champion() -> void:
	var lord: L5RCharacterData = _make_lord_char(10, "Crab", 20, 5.0)
	var family_daimyo: L5RCharacterData = _make_lord_char(20, "Crab", -1, 6.0)
	var champion: L5RCharacterData = _make_lord_char(30, "Crab", -1, 7.0)
	var characters_by_id: Dictionary = {10: lord, 20: family_daimyo, 30: champion}
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1]
	DayOrchestrator._process_levy_suspicion(
		[_make_levy_company(10, 0)], [], characters_by_id,
		topics, next_topic_id, 90, 1,
	)
	assert_lt(champion.disposition_values.get(10, 0), 0)


func test_suspicion_no_duplicate_if_champion_is_family_daimyo() -> void:
	# Lord's lord_id points directly to the Clan Champion (no separate Family Daimyo).
	var lord: L5RCharacterData = _make_lord_char(10, "Crab", 30, 5.0)
	var champion: L5RCharacterData = _make_lord_char(30, "Crab", -1, 7.0)
	var characters_by_id: Dictionary = {10: lord, 30: champion}
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1]
	DayOrchestrator._process_levy_suspicion(
		[_make_levy_company(10, 0)], [], characters_by_id,
		topics, next_topic_id, 90, 1,
	)
	# Champion is both Family Daimyo and Clan Champion — penalty applied only once (-5).
	assert_eq(champion.disposition_values.get(10, 0), -5)


func test_suspicion_wartime_skips_disposition() -> void:
	var lord: L5RCharacterData = _make_lord_char(10, "Crab", 20, 5.0)
	var family_daimyo: L5RCharacterData = _make_lord_char(20, "Crab", -1, 6.0)
	var characters_by_id: Dictionary = {10: lord, 20: family_daimyo}
	var war: WarData = WarData.new()
	war.clan_a = "Crab"
	war.clan_b = "Lion"
	var topics: Array[TopicData] = []
	var next_topic_id: Array[int] = [1]
	DayOrchestrator._process_levy_suspicion(
		[_make_levy_company(10, 0)], [war], characters_by_id,
		topics, next_topic_id, 90, 1,
	)
	# Wartime exception: no suspicion, no disposition change.
	assert_eq(family_daimyo.disposition_values.get(10, 0), 0)
