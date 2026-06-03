extends GutTest


func _make_char(honor: float = 5.0, glory: float = 3.0, status: float = 2.0, infamy: float = 0.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.honor = honor
	c.glory = glory
	c.status = status
	c.infamy = infamy
	c.atoned_offenses = []
	return c


# -- apply_honor_change --------------------------------------------------------

func test_honor_change_positive() -> void:
	var c := _make_char(5.0)
	var actual: float = HonorGlorySystem.apply_honor_change(c, 1.5)
	assert_almost_eq(c.honor, 6.5, 0.01)
	assert_almost_eq(actual, 1.5, 0.01)


func test_honor_change_negative() -> void:
	var c := _make_char(5.0)
	var actual: float = HonorGlorySystem.apply_honor_change(c, -2.0)
	assert_almost_eq(c.honor, 3.0, 0.01)
	assert_almost_eq(actual, -2.0, 0.01)


func test_honor_clamped_at_10() -> void:
	var c := _make_char(9.0)
	var actual: float = HonorGlorySystem.apply_honor_change(c, 5.0)
	assert_almost_eq(c.honor, 10.0, 0.01)
	assert_almost_eq(actual, 1.0, 0.01)


func test_honor_clamped_at_0() -> void:
	var c := _make_char(1.0)
	var actual: float = HonorGlorySystem.apply_honor_change(c, -5.0)
	assert_almost_eq(c.honor, 0.0, 0.01)
	assert_almost_eq(actual, -1.0, 0.01)


# -- apply_glory_change --------------------------------------------------------

func test_glory_change_positive() -> void:
	var c := _make_char(5.0, 3.0)
	var actual: float = HonorGlorySystem.apply_glory_change(c, 0.5)
	assert_almost_eq(c.glory, 3.5, 0.01)
	assert_almost_eq(actual, 0.5, 0.01)


func test_glory_clamped_at_10() -> void:
	var c := _make_char(5.0, 9.5)
	var actual: float = HonorGlorySystem.apply_glory_change(c, 2.0)
	assert_almost_eq(c.glory, 10.0, 0.01)
	assert_almost_eq(actual, 0.5, 0.01)


func test_glory_clamped_at_0() -> void:
	var c := _make_char(5.0, 0.5)
	var actual: float = HonorGlorySystem.apply_glory_change(c, -3.0)
	assert_almost_eq(c.glory, 0.0, 0.01)
	assert_almost_eq(actual, -0.5, 0.01)


# -- apply_status_change -------------------------------------------------------

func test_status_change_positive() -> void:
	var c := _make_char(5.0, 3.0, 2.0)
	var actual: float = HonorGlorySystem.apply_status_change(c, 1.0)
	assert_almost_eq(c.status, 3.0, 0.01)
	assert_almost_eq(actual, 1.0, 0.01)


func test_status_clamped_at_10() -> void:
	var c := _make_char(5.0, 3.0, 9.8)
	var actual: float = HonorGlorySystem.apply_status_change(c, 1.0)
	assert_almost_eq(c.status, 10.0, 0.01)
	assert_almost_eq(actual, 0.2, 0.01)


# -- apply_infamy_change -------------------------------------------------------

func test_infamy_change_positive() -> void:
	var c := _make_char(5.0, 3.0, 2.0, 1.0)
	var actual: float = HonorGlorySystem.apply_infamy_change(c, 0.5)
	assert_almost_eq(c.infamy, 1.5, 0.01)
	assert_almost_eq(actual, 0.5, 0.01)


func test_infamy_clamped_at_10() -> void:
	var c := _make_char(5.0, 3.0, 2.0, 9.5)
	var actual: float = HonorGlorySystem.apply_infamy_change(c, 2.0)
	assert_almost_eq(c.infamy, 10.0, 0.01)
	assert_almost_eq(actual, 0.5, 0.01)


func test_infamy_clamped_at_0() -> void:
	var c := _make_char(5.0, 3.0, 2.0, 0.5)
	var actual: float = HonorGlorySystem.apply_infamy_change(c, -3.0)
	assert_almost_eq(c.infamy, 0.0, 0.01)
	assert_almost_eq(actual, -0.5, 0.01)


# -- Rank queries --------------------------------------------------------------

func test_honor_rank_truncates() -> void:
	var c := _make_char(5.9)
	assert_eq(HonorGlorySystem.get_honor_rank(c), 5)


func test_glory_rank_truncates() -> void:
	var c := _make_char(5.0, 7.3)
	assert_eq(HonorGlorySystem.get_glory_rank(c), 7)


func test_status_rank_truncates() -> void:
	var c := _make_char(5.0, 3.0, 4.8)
	assert_eq(HonorGlorySystem.get_status_rank(c), 4)


func test_infamy_rank_truncates() -> void:
	var c := _make_char(5.0, 3.0, 2.0, 2.1)
	assert_eq(HonorGlorySystem.get_infamy_rank(c), 2)


func test_rank_at_zero() -> void:
	var c := _make_char(0.0, 0.0, 0.0, 0.0)
	assert_eq(HonorGlorySystem.get_honor_rank(c), 0)
	assert_eq(HonorGlorySystem.get_glory_rank(c), 0)


# -- get_court_honor_modifier --------------------------------------------------

func test_court_modifier_honor_rank_7_plus() -> void:
	var c := _make_char(7.5)
	assert_eq(HonorGlorySystem.get_court_honor_modifier(c), 2)


func test_court_modifier_honor_rank_5_6() -> void:
	var c := _make_char(5.0)
	assert_eq(HonorGlorySystem.get_court_honor_modifier(c), 1)


func test_court_modifier_honor_rank_3_4() -> void:
	var c := _make_char(3.5)
	assert_eq(HonorGlorySystem.get_court_honor_modifier(c), 0)


func test_court_modifier_honor_rank_2() -> void:
	var c := _make_char(2.5)
	assert_eq(HonorGlorySystem.get_court_honor_modifier(c), -1)


func test_court_modifier_honor_rank_below_2() -> void:
	var c := _make_char(1.5)
	assert_eq(HonorGlorySystem.get_court_honor_modifier(c), -2)


func test_court_modifier_honor_rank_0() -> void:
	var c := _make_char(0.0)
	assert_eq(HonorGlorySystem.get_court_honor_modifier(c), -2)


# -- get_recognition_rank ------------------------------------------------------

func test_recognition_combines_glory_and_infamy() -> void:
	var c := _make_char(5.0, 3.0, 2.0, 2.0)
	assert_eq(HonorGlorySystem.get_recognition_rank(c), 5)


func test_recognition_zero_infamy() -> void:
	var c := _make_char(5.0, 4.0, 2.0, 0.0)
	assert_eq(HonorGlorySystem.get_recognition_rank(c), 4)


# -- Atonement ----------------------------------------------------------------

func test_can_atone_fresh_offense() -> void:
	var c := _make_char()
	assert_true(HonorGlorySystem.can_atone(c, "scandal_y3m7"))


func test_cannot_atone_already_atoned() -> void:
	var c := _make_char()
	c.atoned_offenses = ["scandal_y3m7"]
	assert_false(HonorGlorySystem.can_atone(c, "scandal_y3m7"))


func test_record_atonement_adds_offense() -> void:
	var c := _make_char()
	HonorGlorySystem.record_atonement(c, "scandal_y3m7")
	assert_true("scandal_y3m7" in c.atoned_offenses)


func test_record_atonement_no_duplicate() -> void:
	var c := _make_char()
	HonorGlorySystem.record_atonement(c, "scandal_y3m7")
	HonorGlorySystem.record_atonement(c, "scandal_y3m7")
	assert_eq(c.atoned_offenses.size(), 1)


# -- Constants -----------------------------------------------------------------

func test_atonement_honor_by_tier_has_four_tiers() -> void:
	assert_eq(HonorGlorySystem.ATONEMENT_HONOR_BY_TIER.size(), 4)
	assert_almost_eq(HonorGlorySystem.ATONEMENT_HONOR_BY_TIER[1], 1.0, 0.01)
	assert_almost_eq(HonorGlorySystem.ATONEMENT_HONOR_BY_TIER[4], 0.3, 0.01)


func test_atonement_tn_by_tier_has_four_tiers() -> void:
	assert_eq(HonorGlorySystem.ATONEMENT_TN_BY_TIER.size(), 4)
	assert_eq(HonorGlorySystem.ATONEMENT_TN_BY_TIER[1], 30)
	assert_eq(HonorGlorySystem.ATONEMENT_TN_BY_TIER[4], 15)


# -- ASCETIC glory scaling (s45 wiring) ----------------------------------------

func _add_ascetic(c: L5RCharacterData) -> void:
	var dis := DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.ASCETIC
	dis.rank = 1
	dis.metadata = {}
	c.disadvantages.append(dis)


func test_ascetic_samurai_halves_glory_gain() -> void:
	var c := _make_char(5.0, 3.0)
	_add_ascetic(c)
	HonorGlorySystem.apply_glory_change(c, 2.0)
	assert_almost_eq(c.glory, 4.0, 0.01, "samurai ASCETIC should receive only 1.0 glory (half of 2.0)")


func test_ascetic_samurai_halves_glory_loss() -> void:
	var c := _make_char(5.0, 5.0)
	_add_ascetic(c)
	HonorGlorySystem.apply_glory_change(c, -2.0)
	assert_almost_eq(c.glory, 4.0, 0.01, "samurai ASCETIC glory loss also halved")


func test_ascetic_monk_quarters_glory_gain() -> void:
	var c := _make_char(5.0, 3.0)
	c.school_type = Enums.SchoolType.MONK
	_add_ascetic(c)
	HonorGlorySystem.apply_glory_change(c, 2.0)
	assert_almost_eq(c.glory, 3.5, 0.01, "monk ASCETIC receives only 0.5 glory (quarter of 2.0)")


func test_no_ascetic_full_glory() -> void:
	var c := _make_char(5.0, 3.0)
	HonorGlorySystem.apply_glory_change(c, 2.0)
	assert_almost_eq(c.glory, 5.0, 0.01, "non-ASCETIC receives full glory")


# -- CAST_OUT get_observed_glory_rank (s45) ------------------------------------

func _make_cast_out_char(target_glory: float, sect_match: bool) -> L5RCharacterData:
	var target := _make_char(5.0, target_glory)
	var dis := DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.CAST_OUT
	dis.rank = 3
	dis.metadata = {"sect": "Shintao"}
	target.disadvantages.append(dis)
	return target


func test_cast_out_observer_matching_sect_sees_zero_glory() -> void:
	var target := _make_cast_out_char(6.0, true)
	var observer := _make_char()
	observer.brotherhood_sect = "Shintao"
	assert_eq(HonorGlorySystem.get_observed_glory_rank(target, observer), 0,
		"Shintao observer sees CAST_OUT target's glory as 0")


func test_cast_out_observer_different_sect_sees_normal_glory() -> void:
	var target := _make_cast_out_char(6.0, false)
	var observer := _make_char()
	observer.brotherhood_sect = "Fortunist"
	assert_eq(HonorGlorySystem.get_observed_glory_rank(target, observer), 6,
		"Fortunist observer not in target's cast-out sect sees real glory")


func test_cast_out_non_monk_observer_sees_normal_glory() -> void:
	var target := _make_cast_out_char(4.0, true)
	var observer := _make_char()
	observer.brotherhood_sect = ""
	assert_eq(HonorGlorySystem.get_observed_glory_rank(target, observer), 4,
		"Non-Brotherhood observer sees full glory regardless of CAST_OUT")


func test_no_cast_out_disadvantage_normal_glory() -> void:
	var target := _make_char(5.0, 3.0)
	var observer := _make_char()
	observer.brotherhood_sect = "Shintao"
	assert_eq(HonorGlorySystem.get_observed_glory_rank(target, observer), 3,
		"Character without CAST_OUT disadvantage always shows real glory")


func test_observed_glory_null_observer_safe() -> void:
	var target := _make_cast_out_char(5.0, true)
	assert_eq(HonorGlorySystem.get_observed_glory_rank(target, null), 5,
		"Null observer falls back to real glory rank safely")


# -- CAST_OUT wiring: consumer call sites (s45) --------------------------------
# These tests verify the six call sites that now use get_observed_glory_rank()
# instead of raw .glory field access.


func _make_cast_out_adv_dis() -> DisadvantageData:
	var dis := DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.CAST_OUT
	dis.rank = 3
	dis.metadata = {"sect": "Shintao"}
	return dis


func _make_succession_char(id: int, glory: float) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.honor = 5.0
	c.glory = glory
	c.status = 3.0
	c.infamy = 0.0
	c.atoned_offenses = []
	c.disposition_values = {}
	c.school_type = Enums.SchoolType.BUSHI
	c.skills = {}
	return c


func test_succession_glory_factor_uses_observed_glory() -> void:
	# Lord is a Brotherhood monk; candidate is cast out from the same sect.
	# _score_glory(observed 0.0) = 1 (lowest bracket); without wiring _score_glory(6.0) = 8.
	var lord := _make_succession_char(1, 0.0)
	lord.brotherhood_sect = "Shintao"
	var candidate := _make_succession_char(2, 6.0)
	candidate.disadvantages.append(_make_cast_out_adv_dis())
	var weights: Dictionary = SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result: Dictionary = SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"].get("glory", -1), 1,
		"Lord in same Brotherhood sect sees glory 0 → _score_glory(0.0) = 1 (lowest bracket)")


func test_succession_glory_high_without_cast_out_disadvantage() -> void:
	# Same lord but candidate has no CAST_OUT → observed = real glory 6.0 → score 8.
	var lord := _make_succession_char(1, 0.0)
	lord.brotherhood_sect = "Shintao"
	var candidate := _make_succession_char(2, 6.0)
	var weights: Dictionary = SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result: Dictionary = SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"].get("glory", -1), 8,
		"Candidate without CAST_OUT disadvantage shows full glory score")


func test_succession_glory_factor_normal_for_non_sect_observer() -> void:
	var lord := _make_succession_char(1, 0.0)
	lord.brotherhood_sect = "Fortunist"
	var candidate := _make_succession_char(2, 4.0)
	candidate.disadvantages.append(_make_cast_out_adv_dis())
	var weights: Dictionary = SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result: Dictionary = SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	# glory 4.0 → _score_glory(4.0) = 6
	assert_eq(result["scores"].get("glory", -1), 6,
		"Lord in different sect sees candidate's real glory rank → _score_glory(4.0) = 6")


func _make_winter_court_candidate(glory: float, cast_out_sect: String = "") -> L5RCharacterData:
	var c := _make_char(5.0, glory, 3.0)
	c.character_id = randi() % 1000 + 100
	c.skills = {"Etiquette": 3, "Sincerity": 3, "Courtier": 3, "Perform": 3}
	if cast_out_sect != "":
		var dis := DisadvantageData.new()
		dis.disadvantage_type = Enums.Disadvantage.CAST_OUT
		dis.rank = 3
		dis.metadata = {"sect": cast_out_sect}
		c.disadvantages.append(dis)
	return c


func test_winter_court_delegation_uses_observed_glory() -> void:
	# Champion is Brotherhood Shintao; candidate is cast out from Shintao.
	var champion := _make_char(6.0, 5.0)
	champion.character_id = 1
	champion.brotherhood_sect = "Shintao"
	champion.disposition_values = {}
	var candidate := _make_winter_court_candidate(8.0, "Shintao")
	# Build a minimal topic_pool_map.
	var scored: float = WinterCourtSystem._score_delegate_candidate(champion, candidate, [], {})
	# Also score same candidate with no cast-out for comparison.
	var candidate_normal := _make_winter_court_candidate(8.0)
	var scored_normal: float = WinterCourtSystem._score_delegate_candidate(champion, candidate_normal, [], {})
	assert_lt(scored, scored_normal,
		"Cast-out candidate should score lower prestige with same-sect champion")


func test_winter_court_delegation_normal_for_non_sect_champion() -> void:
	var champion := _make_char(6.0, 5.0)
	champion.character_id = 1
	champion.brotherhood_sect = "Fortunist"
	champion.disposition_values = {}
	var candidate := _make_winter_court_candidate(8.0, "Shintao")
	var scored_cast_out: float = WinterCourtSystem._score_delegate_candidate(champion, candidate, [], {})
	var candidate_normal := _make_winter_court_candidate(8.0)
	var scored_normal: float = WinterCourtSystem._score_delegate_candidate(champion, candidate_normal, [], {})
	assert_almost_eq(scored_cast_out, scored_normal, 0.01,
		"Different sect champion sees cast-out candidate's real glory")
