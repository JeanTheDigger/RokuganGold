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
	c.health = 100
	var r: Dictionary = LevySystem.disband_levy(c)
	assert_almost_eq(r["pu_returned"], 1.0, 0.01)
	assert_true(r["arms_retained"])


func test_disband_half_health() -> void:
	var c: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		1, Enums.CompanyUnitType.PEASANT_LEVY,
	)
	c.health = 50
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
