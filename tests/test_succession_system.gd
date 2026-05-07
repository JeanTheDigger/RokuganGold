extends GutTest

# ==============================================================================
# Helpers
# ==============================================================================

func _make_char(id: int, clan: String = "Crane", family: String = "Doji") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.family = family
	c.honor = 5.0
	c.glory = 3.0
	c.status = 4.0
	c.age = 30
	c.school_type = Enums.SchoolType.BUSHI
	c.stamina = 3
	c.willpower = 3
	c.strength = 3
	c.perception = 3
	c.agility = 3
	c.intelligence = 3
	c.reflexes = 3
	c.awareness = 3
	c.void_ring = 3
	c.skills = {"Kenjutsu": 3, "Battle": 3, "Defense": 2, "Etiquette": 2}
	return c


func _make_lord(id: int, clan: String = "Crane") -> L5RCharacterData:
	var c := _make_char(id, clan, "Doji")
	c.status = 6.0
	c.bushido_virtue = Enums.BushidoVirtue.REI
	return c


func _make_dead_char(id: int, clan: String = "Crane") -> L5RCharacterData:
	var c := _make_char(id, clan)
	c.wounds_taken = 999
	return c


# ==============================================================================
# Succession Trigger
# ==============================================================================

func test_trigger_succession_creates_data() -> void:
	var deceased := _make_char(1)
	deceased.designated_heir_id = 5
	deceased.physical_location = "doji_castle"

	var data := SuccessionSystem.trigger_succession(
		deceased, SuccessionData.VacancyCause.DEATH,
		Enums.LordRank.PROVINCIAL_DAIMYO, 100)

	assert_eq(data.deceased_id, 1)
	assert_eq(data.position_tier, Enums.LordRank.PROVINCIAL_DAIMYO)
	assert_eq(data.clan, "Crane")
	assert_eq(data.family, "Doji")
	assert_eq(data.cause, SuccessionData.VacancyCause.DEATH)
	assert_eq(data.start_tick, 100)
	assert_eq(data.designated_heir_id, 5)
	assert_false(data.suspicious_death)
	assert_eq(data.settlement_id, "doji_castle")


func test_trigger_suspicious_death() -> void:
	var deceased := _make_char(1)
	var data := SuccessionSystem.trigger_succession(
		deceased, SuccessionData.VacancyCause.DEATH,
		Enums.LordRank.FAMILY_DAIMYO, 50, true)
	assert_true(data.suspicious_death)


func test_trigger_retirement() -> void:
	var deceased := _make_char(1)
	var data := SuccessionSystem.trigger_succession(
		deceased, SuccessionData.VacancyCause.RETIREMENT,
		Enums.LordRank.PROVINCIAL_DAIMYO, 200)
	assert_eq(data.cause, SuccessionData.VacancyCause.RETIREMENT)


# ==============================================================================
# Candidate Gathering
# ==============================================================================

func test_designated_heir_is_priority_1() -> void:
	var deceased := _make_char(1)
	var heir := _make_char(10)
	deceased.designated_heir_id = 10
	var chars := {10: heir}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0]["priority"], SuccessionSystem.CandidatePriority.DESIGNATED_HEIR)
	assert_eq(candidates[0]["id"], 10)


func test_eldest_child_is_priority_2() -> void:
	var deceased := _make_char(1)
	var child1 := _make_char(10)
	child1.age = 25
	var child2 := _make_char(11)
	child2.age = 20
	deceased.children_ids = [10, 11]
	var chars := {10: child1, 11: child2}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 2)
	assert_eq(candidates[0]["id"], 10)
	assert_eq(candidates[0]["priority"], SuccessionSystem.CandidatePriority.ELDEST_CHILD)
	assert_eq(candidates[1]["id"], 11)
	assert_eq(candidates[1]["priority"], SuccessionSystem.CandidatePriority.OTHER_CHILD)


func test_siblings_are_priority_5() -> void:
	var deceased := _make_char(1)
	var sibling := _make_char(20)
	deceased.sibling_ids = [20]
	var chars := {20: sibling}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0]["priority"], SuccessionSystem.CandidatePriority.SIBLING)


func test_dead_candidates_excluded() -> void:
	var deceased := _make_char(1)
	var dead_child := _make_dead_char(10)
	deceased.children_ids = [10]
	var chars := {10: dead_child}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 0)


func test_wrong_clan_child_excluded() -> void:
	var deceased := _make_char(1, "Crane")
	var child := _make_char(10, "Scorpion")
	deceased.children_ids = [10]
	var chars := {10: child}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 0)


func test_designated_heir_not_duplicated_as_child() -> void:
	var deceased := _make_char(1)
	var heir := _make_char(10)
	heir.age = 25
	deceased.designated_heir_id = 10
	deceased.children_ids = [10]
	var chars := {10: heir}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0]["priority"], SuccessionSystem.CandidatePriority.DESIGNATED_HEIR)


func test_full_priority_ordering() -> void:
	var deceased := _make_char(1)
	var heir := _make_char(10)
	var child := _make_char(11)
	child.age = 20
	var sibling := _make_char(12)
	deceased.designated_heir_id = 10
	deceased.children_ids = [11]
	deceased.sibling_ids = [12]
	var chars := {10: heir, 11: child, 12: sibling}
	var candidates := SuccessionSystem.get_candidates(deceased, chars)
	assert_eq(candidates.size(), 3)
	assert_eq(candidates[0]["priority"], SuccessionSystem.CandidatePriority.DESIGNATED_HEIR)
	assert_eq(candidates[1]["priority"], SuccessionSystem.CandidatePriority.ELDEST_CHILD)
	assert_eq(candidates[2]["priority"], SuccessionSystem.CandidatePriority.SIBLING)


# ==============================================================================
# Confirmation Authority
# ==============================================================================

func test_local_daimyo_confirmed_by_provincial() -> void:
	var tier := SuccessionSystem.get_confirming_authority_tier(Enums.LordRank.VILLAGE_HEADMAN)
	assert_eq(tier, Enums.LordRank.PROVINCIAL_DAIMYO)


func test_provincial_confirmed_by_family() -> void:
	var tier := SuccessionSystem.get_confirming_authority_tier(Enums.LordRank.PROVINCIAL_DAIMYO)
	assert_eq(tier, Enums.LordRank.FAMILY_DAIMYO)


func test_family_confirmed_by_champion() -> void:
	var tier := SuccessionSystem.get_confirming_authority_tier(Enums.LordRank.FAMILY_DAIMYO)
	assert_eq(tier, Enums.LordRank.CLAN_CHAMPION)


func test_champion_confirmed_by_emperor() -> void:
	var tier := SuccessionSystem.get_confirming_authority_tier(Enums.LordRank.CLAN_CHAMPION)
	assert_eq(tier, Enums.LordRank.IMPERIAL)


func test_find_confirming_authority_returns_best_status() -> void:
	var low := _make_char(10, "Crane")
	low.status = 5.0
	var high := _make_char(11, "Crane")
	high.status = 6.5
	var chars := {10: low, 11: high}
	var auth_id := SuccessionSystem.find_confirming_authority(
		Enums.LordRank.FAMILY_DAIMYO, "Crane", chars)
	assert_eq(auth_id, 11)


func test_find_confirming_authority_wrong_clan_skipped() -> void:
	var lion := _make_char(10, "Lion")
	lion.status = 7.0
	var chars := {10: lion}
	var auth_id := SuccessionSystem.find_confirming_authority(
		Enums.LordRank.FAMILY_DAIMYO, "Crane", chars)
	assert_eq(auth_id, -1)


# ==============================================================================
# Clean vs. Disputed
# ==============================================================================

func test_clean_succession_with_designated_heir() -> void:
	var data := SuccessionData.new()
	var candidates: Array[Dictionary] = [{"priority": SuccessionSystem.CandidatePriority.DESIGNATED_HEIR, "id": 10}]
	assert_true(SuccessionSystem.is_clean_succession(data, candidates, 31))


func test_suspicious_death_forces_dispute() -> void:
	var data := SuccessionData.new()
	data.suspicious_death = true
	var candidates: Array[Dictionary] = [{"priority": SuccessionSystem.CandidatePriority.DESIGNATED_HEIR, "id": 10}]
	assert_false(SuccessionSystem.is_clean_succession(data, candidates, 50))


func test_contester_forces_dispute() -> void:
	var data := SuccessionData.new()
	data.contesting_ids = [20]
	var candidates: Array[Dictionary] = [{"priority": SuccessionSystem.CandidatePriority.DESIGNATED_HEIR, "id": 10}]
	assert_false(SuccessionSystem.is_clean_succession(data, candidates, 50))


func test_multiple_same_priority_forces_dispute() -> void:
	var data := SuccessionData.new()
	var candidates: Array[Dictionary] = [
		{"priority": SuccessionSystem.CandidatePriority.ELDEST_CHILD, "id": 10},
		{"priority": SuccessionSystem.CandidatePriority.ELDEST_CHILD, "id": 11},
	]
	assert_false(SuccessionSystem.is_clean_succession(data, candidates, 50))


func test_rival_disposition_forces_dispute() -> void:
	var data := SuccessionData.new()
	var candidates: Array[Dictionary] = [{"priority": SuccessionSystem.CandidatePriority.DESIGNATED_HEIR, "id": 10}]
	assert_false(SuccessionSystem.is_clean_succession(data, candidates, -11))


func test_clean_transition_duration_friend() -> void:
	assert_eq(SuccessionSystem.get_transition_duration(true, 31), 7)


func test_clean_transition_duration_acquaintance() -> void:
	assert_eq(SuccessionSystem.get_transition_duration(true, 10), 14)


func test_disputed_transition_duration() -> void:
	assert_eq(SuccessionSystem.get_transition_duration(false, 50), 60)


# ==============================================================================
# Heir Evaluation — Factor Scoring
# ==============================================================================

func test_disposition_score_devoted() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	lord.disposition_values[10] = 65
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE)
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["disposition"], 15)


func test_disposition_score_rival() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	lord.disposition_values[10] = -15
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE)
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["disposition"], 1)


func test_birth_order_eldest() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["birth_order"], 12)


func test_birth_order_sibling() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.SIBLING, weights)
	assert_eq(result["scores"]["birth_order"], 3)


func test_honor_score_high() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	candidate.honor = 8.0
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["honor"], 10)


func test_glory_score_low() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	candidate.glory = 0.5
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["glory"], 1)


func test_school_type_match_military() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	candidate.school_type = Enums.SchoolType.BUSHI
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights, "military")
	assert_eq(result["scores"]["school_type"], 8)


func test_school_type_mismatch() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	candidate.school_type = Enums.SchoolType.SHUGENJA
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights, "military")
	assert_eq(result["scores"]["school_type"], 1)


func test_achievement_score_caps_at_10() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	var topics: Array[Dictionary] = []
	for i in range(10):
		topics.append({"topic_type": "battle_commander_victory"})
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights, "military", topics)
	assert_eq(result["scores"]["achievements"], 10)


func test_achievement_score_floors_at_0() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	var topics: Array[Dictionary] = [
		{"topic_type": "betrayal"},
		{"topic_type": "betrayal"},
	]
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights, "military", topics)
	assert_eq(result["scores"]["achievements"], 0)


func test_titles_score_high_status() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	candidate.status = 6.0
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["titles"], 5)


# ==============================================================================
# Personality Weight Modifiers
# ==============================================================================

func test_gi_doubles_honor_weight() -> void:
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.NONE)
	assert_eq(weights["honor"], 20)


func test_yu_boosts_achievements() -> void:
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.NONE)
	assert_eq(weights["achievements"], 18)
	assert_eq(weights["disposition"], 7)


func test_ishi_boosts_birth_order_reduces_others() -> void:
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI)
	assert_eq(weights["birth_order"], 24)
	assert_eq(weights["disposition"], 19)
	assert_eq(weights["honor"], 8)
	assert_eq(weights["glory"], 6)


func test_seigyo_boosts_disposition_reduces_insight() -> void:
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	assert_eq(weights["disposition"], 27)
	assert_eq(weights["insight_rank"], 8)


func test_dual_virtue_stacks() -> void:
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.KANPEKI)
	assert_gt(weights["honor"], SuccessionSystem.BASE_WEIGHTS["honor"])


func test_kyoryoku_nearly_ignores_birth_order() -> void:
	var weights := SuccessionSystem.compute_personality_weights(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU)
	assert_eq(weights["birth_order"], 6)


# ==============================================================================
# Evaluate All Candidates
# ==============================================================================

func test_evaluate_all_returns_sorted_by_total() -> void:
	var lord := _make_lord(1)
	var c1 := _make_char(10)
	c1.honor = 9.0
	c1.glory = 8.0
	c1.status = 6.0
	var c2 := _make_char(11)
	c2.honor = 2.0
	c2.glory = 1.0
	c2.status = 1.0
	lord.disposition_values[10] = 50
	lord.disposition_values[11] = -20

	var candidates: Array[Dictionary] = [
		{"id": 10, "priority": SuccessionSystem.CandidatePriority.ELDEST_CHILD, "character": c1},
		{"id": 11, "priority": SuccessionSystem.CandidatePriority.OTHER_CHILD, "character": c2},
	]
	var results := SuccessionSystem.evaluate_all_candidates(lord, candidates)
	assert_eq(results.size(), 2)
	assert_eq(results[0]["candidate_id"], 10)
	assert_gt(results[0]["total"], results[1]["total"])


# ==============================================================================
# Confirm Successor
# ==============================================================================

func test_confirm_successor_sets_state() -> void:
	var data := SuccessionData.new()
	data.succession_id = 1
	var result := SuccessionSystem.confirm_successor(data, 10)
	assert_eq(data.successor_id, 10)
	assert_eq(data.state, SuccessionData.SuccessionState.CONFIRMED)
	assert_eq(result["successor_id"], 10)


# ==============================================================================
# Transition Effects
# ==============================================================================

func test_transition_effects_suspend_economy() -> void:
	var data := SuccessionData.new()
	data.settlement_id = "test_castle"
	data.position_tier = Enums.LordRank.FAMILY_DAIMYO
	var effects := SuccessionSystem.get_transition_effects(data)
	assert_true(effects["tax_cascade_suspended"])
	assert_true(effects["koku_flow_suspended"])
	assert_true(effects["stockpile_frozen"])


# ==============================================================================
# Successor Inheritance
# ==============================================================================

func test_major_favors_inherited() -> void:
	var deceased := _make_char(1)
	var successor := _make_char(10)
	var major := FavorData.new()
	major.tier = FavorData.FavorTier.MAJOR
	var minor := FavorData.new()
	minor.tier = FavorData.FavorTier.MINOR
	deceased.favors = [major, minor]

	var result := SuccessionSystem.apply_successor_inheritance(successor, deceased)
	assert_eq(result["inherited_major_favors"], 1)
	assert_eq(successor.favors.size(), 1)
	assert_eq(deceased.favors.size(), 1)
	assert_eq(deceased.favors[0].tier, FavorData.FavorTier.MINOR)


# ==============================================================================
# Dispute
# ==============================================================================

func test_contest_succession_adds_contester() -> void:
	var data := SuccessionData.new()
	SuccessionSystem.contest_succession(data, 20)
	assert_eq(data.contesting_ids.size(), 1)
	assert_eq(data.state, SuccessionData.SuccessionState.DISPUTED)


func test_contest_no_duplicate() -> void:
	var data := SuccessionData.new()
	SuccessionSystem.contest_succession(data, 20)
	SuccessionSystem.contest_succession(data, 20)
	assert_eq(data.contesting_ids.size(), 1)


func test_process_tick_increments() -> void:
	var data := SuccessionData.new()
	var result := SuccessionSystem.process_tick(data, 60)
	assert_eq(result["ticks_elapsed"], 1)
	assert_false(result["expired"])


func test_process_tick_expires() -> void:
	var data := SuccessionData.new()
	data.ticks_elapsed = 59
	var result := SuccessionSystem.process_tick(data, 60)
	assert_true(result["expired"])


# ==============================================================================
# Heir Designation
# ==============================================================================

func test_designate_heir() -> void:
	var lord := _make_lord(1)
	SuccessionSystem.designate_heir(lord, 10)
	assert_eq(lord.designated_heir_id, 10)


func test_ishi_never_reevaluates_existing_heir() -> void:
	var lord := _make_lord(1)
	lord.shourido_virtue = Enums.ShouridoVirtue.ISHI
	lord.designated_heir_id = 10
	assert_false(SuccessionSystem.should_reevaluate_heir(lord, {}))


func test_ishi_reevaluates_if_heir_dead() -> void:
	var lord := _make_lord(1)
	lord.shourido_virtue = Enums.ShouridoVirtue.ISHI
	lord.designated_heir_id = 10
	assert_true(SuccessionSystem.should_reevaluate_heir(lord, {"heir_dead": true}))


func test_seigyo_always_reevaluates() -> void:
	var lord := _make_lord(1)
	lord.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	lord.designated_heir_id = 10
	assert_true(SuccessionSystem.should_reevaluate_heir(lord, {}))


func test_no_heir_triggers_evaluation() -> void:
	var lord := _make_lord(1)
	lord.designated_heir_id = -1
	assert_true(SuccessionSystem.should_reevaluate_heir(lord, {}))


func test_new_candidate_triggers_reevaluation() -> void:
	var lord := _make_lord(1)
	lord.designated_heir_id = 10
	assert_true(SuccessionSystem.should_reevaluate_heir(lord, {"new_candidate_gempuku": true}))


func test_designation_urgency_no_heir_young() -> void:
	var lord := _make_lord(1)
	lord.age = 25
	lord.designated_heir_id = -1
	assert_eq(SuccessionSystem.get_designation_urgency(lord), 1)


func test_designation_urgency_no_heir_old() -> void:
	var lord := _make_lord(1)
	lord.age = 45
	lord.designated_heir_id = -1
	assert_eq(SuccessionSystem.get_designation_urgency(lord), 2)


func test_designation_urgency_has_blood_enemy() -> void:
	var lord := _make_lord(1)
	lord.designated_heir_id = -1
	lord.disposition_values[99] = -65
	assert_eq(SuccessionSystem.get_designation_urgency(lord), 2)


func test_designation_urgency_has_heir() -> void:
	var lord := _make_lord(1)
	lord.designated_heir_id = 10
	assert_eq(SuccessionSystem.get_designation_urgency(lord), 0)


# ==============================================================================
# Emperor Succession
# ==============================================================================

func test_emperor_succession_designated_heir() -> void:
	var emperor := _make_char(1, "Imperial")
	emperor.designated_heir_id = 10
	var heir := _make_char(10, "Imperial")
	var chars := {10: heir}
	var result := SuccessionSystem.evaluate_emperor_succession(emperor, chars)
	assert_eq(result["successor_id"], 10)
	assert_false(result["crisis"])
	assert_eq(result["method"], "designated_heir")


func test_emperor_succession_eldest_child() -> void:
	var emperor := _make_char(1, "Imperial")
	var child1 := _make_char(10, "Imperial")
	child1.age = 25
	var child2 := _make_char(11, "Imperial")
	child2.age = 20
	emperor.children_ids = [10, 11]
	var chars := {10: child1, 11: child2}
	var result := SuccessionSystem.evaluate_emperor_succession(emperor, chars)
	assert_eq(result["successor_id"], 10)
	assert_eq(result["method"], "eldest_child")


func test_emperor_succession_crisis() -> void:
	var emperor := _make_char(1, "Imperial")
	var chars: Dictionary = {}
	var result := SuccessionSystem.evaluate_emperor_succession(emperor, chars)
	assert_eq(result["successor_id"], -1)
	assert_true(result["crisis"])


func test_is_emperor_succession() -> void:
	assert_true(SuccessionSystem.is_emperor_succession(Enums.LordRank.IMPERIAL))
	assert_false(SuccessionSystem.is_emperor_succession(Enums.LordRank.CLAN_CHAMPION))


# ==============================================================================
# Topic Generation
# ==============================================================================

func test_clean_succession_topic() -> void:
	var data := SuccessionData.new()
	data.succession_id = 5
	data.clan = "Lion"
	data.deceased_id = 1
	var topic := SuccessionSystem.generate_succession_topic(data, false)
	assert_eq(topic["tier"], 4)
	assert_eq(topic["momentum"], 10.0)
	assert_eq(topic["variant"], "clean")


func test_disputed_succession_topic() -> void:
	var data := SuccessionData.new()
	data.succession_id = 5
	data.clan = "Lion"
	data.deceased_id = 1
	var topic := SuccessionSystem.generate_succession_topic(data, true)
	assert_eq(topic["tier"], 2)
	assert_eq(topic["momentum"], 50.0)
	assert_eq(topic["variant"], "disputed")


# ==============================================================================
# Clan Exceptions
# ==============================================================================

func test_phoenix_champion_exception() -> void:
	assert_true(SuccessionSystem.is_phoenix_champion_succession("Phoenix", Enums.LordRank.CLAN_CHAMPION))
	assert_false(SuccessionSystem.is_phoenix_champion_succession("Phoenix", Enums.LordRank.FAMILY_DAIMYO))
	assert_false(SuccessionSystem.is_phoenix_champion_succession("Crane", Enums.LordRank.CLAN_CHAMPION))


func test_dragon_togashi_exception() -> void:
	assert_true(SuccessionSystem.is_dragon_togashi_removal("Dragon", Enums.LordRank.CLAN_CHAMPION))
	assert_false(SuccessionSystem.is_dragon_togashi_removal("Dragon", Enums.LordRank.FAMILY_DAIMYO))
	assert_false(SuccessionSystem.is_dragon_togashi_removal("Lion", Enums.LordRank.CLAN_CHAMPION))


# ==============================================================================
# Edge Cases
# ==============================================================================

func test_no_candidates_returns_empty() -> void:
	var deceased := _make_char(1)
	var candidates := SuccessionSystem.get_candidates(deceased, {})
	assert_eq(candidates.size(), 0)


func test_empty_candidates_not_clean() -> void:
	var data := SuccessionData.new()
	var candidates: Array[Dictionary] = []
	assert_false(SuccessionSystem.is_clean_succession(data, candidates, 50))


func test_evaluate_candidate_with_no_skills() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	candidate.skills = {}
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_eq(result["scores"]["skills"], 1)


func test_evaluate_candidate_total_positive() -> void:
	var lord := _make_lord(1)
	var candidate := _make_char(10)
	lord.disposition_values[10] = 50
	var weights := SuccessionSystem.BASE_WEIGHTS.duplicate()
	var result := SuccessionSystem.evaluate_candidate(
		lord, candidate, SuccessionSystem.CandidatePriority.ELDEST_CHILD, weights)
	assert_gt(result["total"], 0.0)
