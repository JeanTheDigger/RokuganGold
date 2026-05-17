extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_war(
	war_id: int = 1,
	clan_a: String = "Crab",
	clan_b: String = "Crane",
	authority: WarData.AuthorityLevel = WarData.AuthorityLevel.PROVINCIAL_RAID,
) -> WarData:
	return WarSystem.declare_war(war_id, clan_a, clan_b, authority, 10, 20, 100)


# -- Declaration Tests -----------------------------------------------------------

func test_declare_war_sets_fields() -> void:
	var w: WarData = _make_war()
	assert_eq(w.war_id, 1)
	assert_eq(w.clan_a, "Crab")
	assert_eq(w.clan_b, "Crane")
	assert_eq(w.war_score_a, 50)
	assert_eq(w.war_score_b, 50)
	assert_true(w.is_active)
	assert_eq(w.initiator_clan, "Crab")
	assert_eq(w.declaring_lord_id, 10)
	assert_eq(w.target_lord_id, 20)
	assert_eq(w.ic_day_started, 100)


func test_declare_war_default_authority() -> void:
	var w: WarData = _make_war()
	assert_eq(w.authority_level, WarData.AuthorityLevel.PROVINCIAL_RAID)


# -- War Score Tier Tests --------------------------------------------------------

func test_war_score_tier_dominant() -> void:
	assert_eq(WarSystem.get_war_score_tier(80), WarData.WarScoreTier.DOMINANT)
	assert_eq(WarSystem.get_war_score_tier(100), WarData.WarScoreTier.DOMINANT)


func test_war_score_tier_winning() -> void:
	assert_eq(WarSystem.get_war_score_tier(65), WarData.WarScoreTier.WINNING)
	assert_eq(WarSystem.get_war_score_tier(79), WarData.WarScoreTier.WINNING)


func test_war_score_tier_ahead() -> void:
	assert_eq(WarSystem.get_war_score_tier(50), WarData.WarScoreTier.AHEAD)
	assert_eq(WarSystem.get_war_score_tier(64), WarData.WarScoreTier.AHEAD)


func test_war_score_tier_behind() -> void:
	assert_eq(WarSystem.get_war_score_tier(40), WarData.WarScoreTier.BEHIND)
	assert_eq(WarSystem.get_war_score_tier(49), WarData.WarScoreTier.BEHIND)


func test_war_score_tier_losing() -> void:
	assert_eq(WarSystem.get_war_score_tier(25), WarData.WarScoreTier.LOSING)
	assert_eq(WarSystem.get_war_score_tier(39), WarData.WarScoreTier.LOSING)


func test_war_score_tier_desperate() -> void:
	assert_eq(WarSystem.get_war_score_tier(0), WarData.WarScoreTier.DESPERATE)
	assert_eq(WarSystem.get_war_score_tier(24), WarData.WarScoreTier.DESPERATE)


# -- Score Shift Tests -----------------------------------------------------------

func test_apply_minor_battle_victory() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.apply_score_shift(w, "minor_battle", "Crab")
	assert_eq(r["shift"], 3)
	assert_eq(w.war_score_a, 53)
	assert_eq(w.war_score_b, 47)


func test_apply_major_battle_victory() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "major_battle", "Crane")
	assert_eq(w.war_score_b, 58)
	assert_eq(w.war_score_a, 42)


func test_apply_decisive_battle() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "decisive_battle", "Crab")
	assert_eq(w.war_score_a, 65)
	assert_eq(w.war_score_b, 35)


func test_score_shift_clamps_at_0() -> void:
	var w: WarData = _make_war()
	w.war_score_b = 5
	WarSystem.apply_score_shift(w, "decisive_battle", "Crab")
	assert_eq(w.war_score_b, 0)


func test_score_shift_clamps_at_100() -> void:
	var w: WarData = _make_war()
	w.war_score_a = 95
	WarSystem.apply_score_shift(w, "decisive_battle", "Crab")
	assert_eq(w.war_score_a, 100)


func test_apply_unknown_event_no_shift() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.apply_score_shift(w, "unknown_event", "Crab")
	assert_eq(r["shift"], 0)
	assert_eq(w.war_score_a, 50)


func test_apply_raw_shift() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_raw_shift(w, "Crab", 20)
	assert_eq(w.war_score_a, 70)
	WarSystem.apply_raw_shift(w, "Crane", -10)
	assert_eq(w.war_score_b, 40)


func test_scores_are_independent_not_zero_sum() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "allied_clan_joins", "Crab")
	assert_eq(w.war_score_a, 58, "Winner should gain 8")
	assert_eq(w.war_score_b, 50, "Loser unchanged for one-sided event")


func test_siege_asymmetric_attacker_wins() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "siege_won_attacker", "Crab")
	assert_eq(w.war_score_a, 62, "Attacker gains 12")
	assert_eq(w.war_score_b, 42, "Defender loses 8")


func test_siege_asymmetric_defender_wins() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "siege_won_defender", "Crane")
	assert_eq(w.war_score_b, 58, "Defender gains 8")
	assert_eq(w.war_score_a, 45, "Attacker loses 5")


func test_one_sided_authority_event() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "family_daimyo_commits", "Crane")
	assert_eq(w.war_score_b, 55, "Receiving side gains 5")
	assert_eq(w.war_score_a, 50, "Other side unchanged")


func test_both_scores_can_be_above_50() -> void:
	var w: WarData = _make_war()
	WarSystem.apply_score_shift(w, "allied_clan_joins", "Crab")
	WarSystem.apply_score_shift(w, "allied_clan_joins", "Crane")
	assert_eq(w.war_score_a, 58)
	assert_eq(w.war_score_b, 58)


func test_all_score_shift_events_exist() -> void:
	var expected: Array[String] = [
		"minor_battle", "major_battle", "decisive_battle",
		"province_captured", "castle_captured",
		"siege_won_attacker", "siege_won_defender",
		"gunso_chui_killed", "taisa_shireikan_killed", "rikugunshokan_killed",
		"hostage_rank3", "hostage_rank5_champion",
		"lord_assassinated", "supply_line_cut", "seasonal_attrition",
		"family_daimyo_commits", "clan_champion_commits", "allied_clan_joins",
		"condemn_clan", "authorize_war",
	]
	for e: String in expected:
		assert_true(
			WarSystem.SCORE_SHIFTS.has(e),
			"Missing score shift: %s" % e,
		)


func test_score_shift_values_match_gdd() -> void:
	assert_eq(WarSystem.SCORE_SHIFTS["minor_battle"], [3, 3])
	assert_eq(WarSystem.SCORE_SHIFTS["major_battle"], [8, 8])
	assert_eq(WarSystem.SCORE_SHIFTS["decisive_battle"], [15, 15])
	assert_eq(WarSystem.SCORE_SHIFTS["province_captured"], [5, 5])
	assert_eq(WarSystem.SCORE_SHIFTS["castle_captured"], [10, 10])
	assert_eq(WarSystem.SCORE_SHIFTS["siege_won_attacker"], [12, 8])
	assert_eq(WarSystem.SCORE_SHIFTS["siege_won_defender"], [8, 5])
	assert_eq(WarSystem.SCORE_SHIFTS["rikugunshokan_killed"], [10, 10])
	assert_eq(WarSystem.SCORE_SHIFTS["lord_assassinated"], [12, 12])
	assert_eq(WarSystem.SCORE_SHIFTS["allied_clan_joins"], [8, 0])
	assert_eq(WarSystem.SCORE_SHIFTS["family_daimyo_commits"], [5, 0])
	assert_eq(WarSystem.SCORE_SHIFTS["condemn_clan"], [10, 0])
	assert_eq(WarSystem.SCORE_SHIFTS["authorize_war"], [10, 0])


# -- Escalation Tests ------------------------------------------------------------

func test_can_escalate_raid() -> void:
	var w: WarData = _make_war(1, "Crab", "Crane", WarData.AuthorityLevel.PROVINCIAL_RAID)
	assert_true(WarSystem.can_escalate(w))


func test_cannot_escalate_clan_war() -> void:
	var w: WarData = _make_war(1, "Crab", "Crane", WarData.AuthorityLevel.CLAN_WAR)
	assert_false(WarSystem.can_escalate(w))


func test_escalate_increments_level() -> void:
	var w: WarData = _make_war(1, "Crab", "Crane", WarData.AuthorityLevel.PROVINCIAL_RAID)
	WarSystem.escalate(w)
	assert_eq(w.authority_level, WarData.AuthorityLevel.BORDER_CONFLICT)
	WarSystem.escalate(w)
	assert_eq(w.authority_level, WarData.AuthorityLevel.FAMILY_WAR)
	WarSystem.escalate(w)
	assert_eq(w.authority_level, WarData.AuthorityLevel.CLAN_WAR)
	WarSystem.escalate(w)
	assert_eq(w.authority_level, WarData.AuthorityLevel.CLAN_WAR)


func test_auto_escalation_castle_fallen() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.check_auto_escalation(w, 1, true, false, false, 50)
	assert_true(r["should_escalate"])
	assert_eq(r["reason"], "castle_fallen")


func test_auto_escalation_prolonged() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.check_auto_escalation(w, 4, false, false, false, 50)
	assert_true(r["should_escalate"])
	assert_eq(r["reason"], "prolonged_conflict")


func test_auto_escalation_desperate_score() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.check_auto_escalation(w, 1, false, false, false, 20)
	assert_true(r["should_escalate"])
	assert_eq(r["reason"], "lord_score_desperate")


func test_auto_escalation_enemy_spread() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.check_auto_escalation(w, 1, false, true, false, 50)
	assert_true(r["should_escalate"])
	assert_eq(r["reason"], "enemy_spread")


func test_auto_escalation_enemy_alliance() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.check_auto_escalation(w, 1, false, false, true, 50)
	assert_true(r["should_escalate"])
	assert_eq(r["reason"], "enemy_alliance")


func test_auto_escalation_no_trigger() -> void:
	var w: WarData = _make_war()
	var r: Dictionary = WarSystem.check_auto_escalation(w, 1, false, false, false, 50)
	assert_false(r["should_escalate"])


# -- Peace Willingness Tests -----------------------------------------------------

func test_peace_willingness_desperate() -> void:
	var w: int = WarSystem.compute_peace_willingness(10, false, false, false, "")
	assert_true(w >= 40)


func test_peace_willingness_winning_low() -> void:
	var w: int = WarSystem.compute_peace_willingness(70, false, false, false, "")
	assert_true(w <= 10)


func test_peace_willingness_cede_territory_reduces() -> void:
	var base: int = WarSystem.compute_peace_willingness(30, false, false, false, "")
	var cede: int = WarSystem.compute_peace_willingness(30, true, false, false, "")
	assert_true(cede < base)


func test_peace_willingness_hostage_increases() -> void:
	var base: int = WarSystem.compute_peace_willingness(30, false, false, false, "")
	var hostage: int = WarSystem.compute_peace_willingness(30, false, true, false, "")
	assert_true(hostage > base)


func test_peace_willingness_seigyo_positive() -> void:
	var base: int = WarSystem.compute_peace_willingness(35, false, false, false, "")
	var seigyo: int = WarSystem.compute_peace_willingness(35, false, false, false, "Seigyo")
	assert_true(seigyo > base)


func test_peace_willingness_yu_negative() -> void:
	var base: int = WarSystem.compute_peace_willingness(35, false, false, false, "")
	var yu: int = WarSystem.compute_peace_willingness(35, false, false, false, "Yu")
	assert_true(yu < base)


func test_peace_willingness_clamped() -> void:
	var w: int = WarSystem.compute_peace_willingness(70, false, false, false, "Yu")
	assert_true(w >= 0)


# -- Honor Cost Tests ------------------------------------------------------------

func test_aid_request_honor_desperate() -> void:
	assert_almost_eq(WarSystem.get_aid_request_honor_cost(10), 0.0, 0.001)


func test_aid_request_honor_losing() -> void:
	assert_almost_eq(WarSystem.get_aid_request_honor_cost(30), -1.0, 0.001)


func test_aid_request_honor_slight() -> void:
	assert_almost_eq(WarSystem.get_aid_request_honor_cost(45), -0.5, 0.001)


func test_refusal_honor_family() -> void:
	assert_almost_eq(
		WarSystem.get_refusal_honor_cost(WarData.AuthorityLevel.FAMILY_WAR),
		-2.0, 0.001,
	)


func test_refusal_honor_clan() -> void:
	assert_almost_eq(
		WarSystem.get_refusal_honor_cost(WarData.AuthorityLevel.CLAN_WAR),
		-3.0, 0.001,
	)


func test_refusal_disposition_effects() -> void:
	var effects: Dictionary = WarSystem.get_refusal_disposition_effects()
	assert_eq(effects["direct_vassals"], -15)
	assert_eq(effects["abandoned_family"], -20)
	assert_eq(effects["neighboring_lords"], -5)
	assert_eq(effects["imperial_court"], -10)


# -- Alliance Tests --------------------------------------------------------------

func test_add_ally() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	assert_true("Lion" in w.allied_clans_a)
	assert_eq(w.allied_clans_a.size(), 1)


func test_add_ally_no_duplicate() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	WarSystem.add_ally(w, "Lion", "a")
	assert_eq(w.allied_clans_a.size(), 1)


func test_remove_ally() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "b")
	WarSystem.remove_ally(w, "Lion")
	assert_false("Lion" in w.allied_clans_b)


func test_get_all_combatants() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	WarSystem.add_ally(w, "Dragon", "b")
	var clans: Array[String] = WarSystem.get_all_combatant_clans(w)
	assert_true("Crab" in clans)
	assert_true("Crane" in clans)
	assert_true("Lion" in clans)
	assert_true("Dragon" in clans)


func test_is_clan_involved() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	assert_true(WarSystem.is_clan_involved(w, "Crab"))
	assert_true(WarSystem.is_clan_involved(w, "Crane"))
	assert_true(WarSystem.is_clan_involved(w, "Lion"))
	assert_false(WarSystem.is_clan_involved(w, "Dragon"))


func test_get_clan_side() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	assert_eq(WarSystem.get_clan_side(w, "Crab"), "a")
	assert_eq(WarSystem.get_clan_side(w, "Lion"), "a")
	assert_eq(WarSystem.get_clan_side(w, "Crane"), "b")
	assert_eq(WarSystem.get_clan_side(w, "Dragon"), "")


# -- Resolution Tests ------------------------------------------------------------

func test_end_war() -> void:
	var w: WarData = _make_war()
	WarSystem.end_war(w, "negotiated_settlement")
	assert_false(w.is_active)
	assert_eq(w.resolution_type, "negotiated_settlement")


func test_is_annihilated() -> void:
	var w: WarData = _make_war()
	assert_false(WarSystem.is_annihilated(w, "Crab"))
	w.war_score_a = 0
	assert_true(WarSystem.is_annihilated(w, "Crab"))
	assert_false(WarSystem.is_annihilated(w, "Crane"))


# -- Seasonal Effects Tests ------------------------------------------------------

func test_seasonal_attrition() -> void:
	var w: WarData = _make_war()
	WarSystem.process_seasonal_attrition(w)
	assert_eq(w.seasons_active, 1)
	assert_eq(w.war_score_a, 51)
	assert_eq(w.war_score_b, 49)


func test_disposition_penalty_scales() -> void:
	assert_eq(WarSystem.get_active_war_disposition_penalty(1), -2)
	assert_eq(WarSystem.get_active_war_disposition_penalty(3), -6)
	assert_eq(WarSystem.get_active_war_disposition_penalty(5), -10)


# -- Province Capture Tests ------------------------------------------------------

func test_record_province_capture() -> void:
	var w: WarData = _make_war()
	WarSystem.record_province_capture(w, 5, "Crab")
	assert_true(5 in w.provinces_captured_by_a)
	assert_false(5 in w.provinces_captured_by_b)


func test_capture_switches_side() -> void:
	var w: WarData = _make_war()
	WarSystem.record_province_capture(w, 5, "Crab")
	WarSystem.record_province_capture(w, 5, "Crane")
	assert_false(5 in w.provinces_captured_by_a)
	assert_true(5 in w.provinces_captured_by_b)


func test_allied_capture() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	WarSystem.record_province_capture(w, 7, "Lion")
	assert_true(7 in w.provinces_captured_by_a)


# -- Query Tests -----------------------------------------------------------------

func test_are_clans_at_war() -> void:
	var w: WarData = _make_war()
	var wars: Array[WarData] = [w]
	assert_true(WarSystem.are_clans_at_war(wars, "Crab", "Crane"))
	assert_true(WarSystem.are_clans_at_war(wars, "Crane", "Crab"))
	assert_false(WarSystem.are_clans_at_war(wars, "Crab", "Lion"))


func test_are_clans_at_war_inactive_excluded() -> void:
	var w: WarData = _make_war()
	WarSystem.end_war(w, "peace")
	var wars: Array[WarData] = [w]
	assert_false(WarSystem.are_clans_at_war(wars, "Crab", "Crane"))


func test_get_war_between() -> void:
	var w: WarData = _make_war()
	var wars: Array[WarData] = [w]
	var found: WarData = WarSystem.get_war_between(wars, "Crab", "Crane")
	assert_not_null(found)
	assert_eq(found.war_id, 1)


func test_get_war_between_not_found() -> void:
	var w: WarData = _make_war()
	var wars: Array[WarData] = [w]
	var found: WarData = WarSystem.get_war_between(wars, "Crab", "Lion")
	assert_null(found)


func test_get_active_wars_for_clan() -> void:
	var w1: WarData = _make_war(1, "Crab", "Crane")
	var w2: WarData = _make_war(2, "Crab", "Lion")
	var w3: WarData = _make_war(3, "Lion", "Crane")
	WarSystem.end_war(w2, "peace")
	var wars: Array[WarData] = [w1, w2, w3]
	var crab_wars: Array[WarData] = WarSystem.get_active_wars_for_clan(wars, "Crab")
	assert_eq(crab_wars.size(), 1)
	assert_eq(crab_wars[0].war_id, 1)


func test_allied_clans_at_war() -> void:
	var w: WarData = _make_war()
	WarSystem.add_ally(w, "Lion", "a")
	var wars: Array[WarData] = [w]
	assert_true(WarSystem.are_clans_at_war(wars, "Lion", "Crane"))


# -- Context Conversion Tests ----------------------------------------------------

func test_to_context_dict() -> void:
	var w: WarData = _make_war()
	var d: Dictionary = WarSystem.to_context_dict(w)
	assert_eq(d["war_id"], 1)
	assert_eq(d["clan_a"], "Crab")
	assert_eq(d["clan_b"], "Crane")
	assert_false(d.has("enemy_clan_id"))
	assert_eq(d["war_score_a"], 50)
	assert_true(d["is_active"])


func test_get_enemy_clan_from_war() -> void:
	var war: Dictionary = {"clan_a": "Crab", "clan_b": "Crane"}
	assert_eq(WarSystem.get_enemy_clan_from_war(war, "Crab"), "Crane")
	assert_eq(WarSystem.get_enemy_clan_from_war(war, "Crane"), "Crab")
	assert_eq(WarSystem.get_enemy_clan_from_war(war, "Lion"), "")


func test_wars_to_context_array_skips_inactive() -> void:
	var w1: WarData = _make_war(1)
	var w2: WarData = _make_war(2)
	WarSystem.end_war(w2, "peace")
	var wars: Array[WarData] = [w1, w2]
	var arr: Array = WarSystem.wars_to_context_array(wars)
	assert_eq(arr.size(), 1)
