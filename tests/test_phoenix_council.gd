extends GutTest
## Tests for PhoenixCouncil per GDD s55.10.3.


var _state: Dictionary
var _dice: DiceEngine


func before_each() -> void:
	_state = PhoenixCouncil.make_initial_state()
	_dice = DiceEngine.new(42)


# -- Decision categorisation -------------------------------------------------

func test_declare_war_is_major() -> void:
	assert_true(PhoenixCouncil.is_major_decision(PhoenixCouncil.DecisionType.DECLARE_WAR))


func test_grand_ritual_is_major() -> void:
	assert_true(PhoenixCouncil.is_major_decision(PhoenixCouncil.DecisionType.GRAND_RITUAL))


func test_internal_governance_is_not_major() -> void:
	assert_false(PhoenixCouncil.is_major_decision(PhoenixCouncil.DecisionType.INTERNAL_GOVERNANCE))


func test_tax_adjustment_is_not_major() -> void:
	assert_false(PhoenixCouncil.is_major_decision(PhoenixCouncil.DecisionType.TAX_ADJUSTMENT))


# -- Per-master vote evaluation (element-driven) ----------------------------

func test_fire_master_votes_yes_on_declare_war() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.FIRE, prop, 0, _dice,
		Enums.BushidoVirtue.YU
	)
	assert_eq(ev["vote"], "yes")


func test_fire_master_votes_no_on_sign_treaty() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.FIRE, prop, 0, _dice,
		Enums.BushidoVirtue.YU
	)
	assert_eq(ev["vote"], "no")


func test_water_master_votes_yes_on_sign_treaty() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.WATER, prop, 0, _dice,
		Enums.BushidoVirtue.JIN
	)
	assert_eq(ev["vote"], "yes")


func test_air_master_votes_yes_on_sign_treaty() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.AIR, prop, 0, _dice,
		Enums.BushidoVirtue.REI
	)
	assert_eq(ev["vote"], "yes")


func test_air_master_votes_no_on_declare_war() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.AIR, prop, 0, _dice,
		Enums.BushidoVirtue.REI
	)
	assert_eq(ev["vote"], "no")


func test_earth_master_votes_no_on_declare_war() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.EARTH, prop, 0, _dice,
		Enums.BushidoVirtue.JIN
	)
	assert_eq(ev["vote"], "no")


func test_no_element_lean_votes_no_by_default() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.GRAND_RITUAL}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.EARTH, prop, 0, _dice
	)
	assert_eq(ev["vote"], "no")


# -- Disposition modifier ----------------------------------------------------

func test_friend_disposition_tilts_vote_to_yes() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.COMMIT_SHUGENJA}
	var no_disp: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.WATER, prop, 0, _dice
	)
	assert_eq(no_disp["vote"], "no")
	var friend: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.WATER, prop, 50, _dice
	)
	assert_eq(friend["vote"], "yes")


func test_rival_disposition_tilts_vote_to_no() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.EARTH, prop, -30, _dice,
		Enums.BushidoVirtue.GI
	)
	# Earth has no SIGN_TREATY lean (0), rival disposition -5 → net -5 → NO.
	assert_eq(ev["vote"], "no")


# -- Crisis and element-threatened bonuses ----------------------------------

func test_tier_1_crisis_overrides_temperament() -> void:
	var prop: Dictionary = {
		"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR,
		"crisis_response": true,
	}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.EARTH, prop, 0, _dice,
		Enums.BushidoVirtue.REI
	)
	# Earth -10 + crisis +15 = +5 → YES.
	assert_eq(ev["vote"], "yes")


func test_element_threatened_locks_in_yes_for_that_master() -> void:
	var prop: Dictionary = {
		"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR,
		"threatens_element": PhoenixCouncil.Master.AIR,
	}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.AIR, prop, 0, _dice,
		Enums.BushidoVirtue.REI
	)
	# Air -10 + element threatened +20 = +10 → YES.
	assert_eq(ev["vote"], "yes")


func test_element_threatened_does_not_help_other_masters() -> void:
	var prop: Dictionary = {
		"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR,
		"threatens_element": PhoenixCouncil.Master.AIR,
	}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.EARTH, prop, 0, _dice,
		Enums.BushidoVirtue.JIN
	)
	assert_eq(ev["vote"], "no")


# -- Void master -------------------------------------------------------------

func test_void_master_returns_a_vote() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.VOID, prop, 0, _dice
	)
	assert_true(ev["vote"] in ["yes", "no", "abstain"])


func test_void_master_no_dice_returns_no() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.VOID, prop, 0, null
	)
	assert_eq(ev["vote"], "no")


func test_void_master_abstains_some_of_the_time_across_seeds() -> void:
	# Across many seeds, Void should sometimes abstain (PROVISIONAL ~10%).
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var saw_abstain: bool = false
	for seed in range(1, 60):
		var dice: DiceEngine = DiceEngine.new(seed)
		var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
			PhoenixCouncil.Master.VOID, prop, 0, dice
		)
		if ev["vote"] == "abstain":
			saw_abstain = true
			break
	assert_true(saw_abstain, "Void should abstain at least once across 60 seeds")


# -- Tally -------------------------------------------------------------------

func test_tally_passes_with_3_yes() -> void:
	# Sign-treaty: Water +10 YES, Air +10 YES, Earth 0 + friend disp +5 = YES, Fire -10 NO.
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var living: Array = [
		PhoenixCouncil.Master.FIRE,
		PhoenixCouncil.Master.WATER,
		PhoenixCouncil.Master.AIR,
		PhoenixCouncil.Master.EARTH,
	]
	var dispositions: Dictionary = {
		PhoenixCouncil.Master.EARTH: 50,
	}
	var result: Dictionary = PhoenixCouncil.tally_vote(living, prop, dispositions, _dice)
	assert_eq(result["yes"], 3)
	assert_eq(result["no"], 1)
	assert_true(result["passed"])


func test_tally_fails_with_only_one_yes_on_war() -> void:
	# Declare-war: Fire +10 YES, Water -10 NO, Air -10 NO, Earth -10 NO.
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var living: Array = [
		PhoenixCouncil.Master.FIRE,
		PhoenixCouncil.Master.WATER,
		PhoenixCouncil.Master.AIR,
		PhoenixCouncil.Master.EARTH,
	]
	var result: Dictionary = PhoenixCouncil.tally_vote(living, prop, {}, _dice)
	assert_false(result["passed"])
	assert_eq(result["yes"], 1)


# -- Deadlock ----------------------------------------------------------------

func test_table_proposal_increments_count() -> void:
	PhoenixCouncil.table_proposal(_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 0)
	assert_eq(PhoenixCouncil.get_tabled_vote_count(_state, PhoenixCouncil.DecisionType.SIGN_TREATY), 1)
	PhoenixCouncil.table_proposal(_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 1)
	assert_eq(PhoenixCouncil.get_tabled_vote_count(_state, PhoenixCouncil.DecisionType.SIGN_TREATY), 2)


func test_champion_may_break_tie_after_two_tablings() -> void:
	assert_false(PhoenixCouncil.champion_may_break_tie(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY,
	))
	PhoenixCouncil.table_proposal(_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 0)
	assert_false(PhoenixCouncil.champion_may_break_tie(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY,
	))
	PhoenixCouncil.table_proposal(_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 1)
	assert_true(PhoenixCouncil.champion_may_break_tie(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY,
	))


# -- Defiance Path -----------------------------------------------------------

func test_defiance_increments_counter_and_stage() -> void:
	PhoenixCouncil.handle_unilateral_action(_state)
	assert_eq(_state["defiance_count"], 1)
	assert_eq(_state["defiance_stage"], 1)
	PhoenixCouncil.handle_unilateral_action(_state)
	assert_eq(_state["defiance_count"], 2)
	assert_eq(_state["defiance_stage"], 2)


func test_defiance_stage_caps_at_4() -> void:
	for i in 6:
		PhoenixCouncil.handle_unilateral_action(_state)
	assert_eq(_state["defiance_stage"], 4)


func test_compliant_season_unwinds_stage() -> void:
	for i in 3:
		PhoenixCouncil.handle_unilateral_action(_state)
	assert_eq(_state["defiance_stage"], 3)
	PhoenixCouncil.handle_compliant_season(_state)
	assert_eq(_state["defiance_stage"], 2)


func test_compliant_season_does_not_reset_lifetime_count() -> void:
	# Per s55.10.3.5 escalation scope — single act of compliance does not
	# undo trust damage.
	PhoenixCouncil.handle_unilateral_action(_state)
	PhoenixCouncil.handle_unilateral_action(_state)
	PhoenixCouncil.handle_compliant_season(_state)
	assert_eq(_state["defiance_count"], 2)
	assert_eq(_state["defiance_stage"], 1)


func test_defiance_stage_2_suspends_diplomatic_authority() -> void:
	_state["defiance_stage"] = 2
	assert_true(PhoenixCouncil.is_diplomatic_suspended(_state))


func test_defiance_stage_3_withdraws_shugenja() -> void:
	_state["defiance_stage"] = 2
	assert_false(PhoenixCouncil.is_shugenja_withdrawn(_state))
	_state["defiance_stage"] = 3
	assert_true(PhoenixCouncil.is_shugenja_withdrawn(_state))


func test_defiance_stage_4_unfit_declaration() -> void:
	_state["defiance_stage"] = 3
	assert_false(PhoenixCouncil.is_unfit_declaration_active(_state))
	_state["defiance_stage"] = 4
	assert_true(PhoenixCouncil.is_unfit_declaration_active(_state))


# -- Overreach Path ----------------------------------------------------------

func test_overreach_trigger_increments() -> void:
	PhoenixCouncil.handle_overreach_trigger(_state)
	assert_eq(_state["overreach_count"], 1)
	assert_eq(_state["overreach_stage"], 1)


func test_overreach_stage_caps_at_4() -> void:
	for i in 6:
		PhoenixCouncil.handle_overreach_trigger(_state)
	assert_eq(_state["overreach_stage"], 4)


func test_emperor_appeal_available_at_stage_2() -> void:
	_state["overreach_stage"] = 1
	assert_false(PhoenixCouncil.is_emperor_appeal_available(_state))
	_state["overreach_stage"] = 2
	assert_true(PhoenixCouncil.is_emperor_appeal_available(_state))


func test_compact_violated_at_stage_3() -> void:
	_state["overreach_stage"] = 2
	assert_false(PhoenixCouncil.is_compact_declared_violated(_state))
	_state["overreach_stage"] = 3
	assert_true(PhoenixCouncil.is_compact_declared_violated(_state))


# -- Crisis veto streak ------------------------------------------------------

func test_three_crisis_vetoes_trigger_overreach() -> void:
	assert_false(PhoenixCouncil.track_consecutive_crisis_veto(_state))
	assert_false(PhoenixCouncil.track_consecutive_crisis_veto(_state))
	assert_true(PhoenixCouncil.track_consecutive_crisis_veto(_state))
	assert_eq(_state["overreach_count"], 1)


func test_crisis_veto_streak_reset() -> void:
	PhoenixCouncil.track_consecutive_crisis_veto(_state)
	PhoenixCouncil.track_consecutive_crisis_veto(_state)
	PhoenixCouncil.reset_crisis_veto_streak(_state)
	assert_eq(_state["consecutive_crisis_vetoes"], 0)


func test_three_obstruction_seasons_trigger_overreach() -> void:
	PhoenixCouncil.track_consecutive_obstruction(_state)
	PhoenixCouncil.track_consecutive_obstruction(_state)
	var triggered: bool = PhoenixCouncil.track_consecutive_obstruction(_state)
	assert_true(triggered)
	assert_eq(_state["overreach_count"], 1)


# -- Champion authority flag -------------------------------------------------

func test_champion_authority_default_false() -> void:
	assert_false(PhoenixCouncil.has_champion_authority(_state))


func test_grant_and_restore_round_trip() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	assert_true(PhoenixCouncil.has_champion_authority(_state))
	PhoenixCouncil.restore_council_compact(_state)
	assert_false(PhoenixCouncil.has_champion_authority(_state))


func test_restore_resets_defiance_and_overreach() -> void:
	PhoenixCouncil.handle_unilateral_action(_state)
	PhoenixCouncil.handle_overreach_trigger(_state)
	PhoenixCouncil.grant_champion_authority(_state)
	PhoenixCouncil.restore_council_compact(_state)
	assert_eq(_state["defiance_count"], 0)
	assert_eq(_state["defiance_stage"], 0)
	assert_eq(_state["overreach_count"], 0)
	assert_eq(_state["overreach_stage"], 0)


# -- Reincarnated Champion compact restoration ------------------------------

func test_chugi_dominant_restores_compact() -> void:
	var c := L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	# Duty score 70 → above 60 threshold.
	assert_true(PhoenixCouncil.reincarnated_champion_evaluates_restore(c, 0, 70))


func test_chugi_low_duty_does_not_restore() -> void:
	var c := L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	assert_false(PhoenixCouncil.reincarnated_champion_evaluates_restore(c, 0, 50))


func test_ishi_dominant_keeps_authority() -> void:
	var c := L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.ISHI
	# Even with high disposition, Ishi keeps authority.
	assert_false(PhoenixCouncil.reincarnated_champion_evaluates_restore(c, 80, 30))


func test_seigyo_dominant_keeps_authority() -> void:
	var c := L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	assert_false(PhoenixCouncil.reincarnated_champion_evaluates_restore(c, 80, 30))


func test_neutral_champion_disposition_driven() -> void:
	var c := L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	# Friend+ disposition (31+) → restores.
	assert_true(PhoenixCouncil.reincarnated_champion_evaluates_restore(c, 35, 30))
	assert_false(PhoenixCouncil.reincarnated_champion_evaluates_restore(c, 20, 30))


# -- Master vacancy / extinction --------------------------------------------

func test_council_can_self_govern_with_3_or_more() -> void:
	assert_true(PhoenixCouncil.can_council_self_govern([
		PhoenixCouncil.Master.FIRE,
		PhoenixCouncil.Master.WATER,
		PhoenixCouncil.Master.AIR,
	]))


func test_council_below_quorum_below_3() -> void:
	assert_false(PhoenixCouncil.can_council_self_govern([
		PhoenixCouncil.Master.FIRE, PhoenixCouncil.Master.WATER,
	]))


func test_champion_appoints_below_quorum() -> void:
	assert_true(PhoenixCouncil.champion_appoints_replacements([
		PhoenixCouncil.Master.FIRE,
	]))


func test_champion_appoints_at_full_council_false() -> void:
	assert_false(PhoenixCouncil.champion_appoints_replacements([
		PhoenixCouncil.Master.FIRE, PhoenixCouncil.Master.WATER,
		PhoenixCouncil.Master.AIR, PhoenixCouncil.Master.EARTH,
		PhoenixCouncil.Master.VOID,
	]))


func test_council_extinct_at_zero_masters() -> void:
	assert_true(PhoenixCouncil.is_council_extinct([]))
	assert_false(PhoenixCouncil.is_council_extinct([PhoenixCouncil.Master.FIRE]))


# -- Initial state -----------------------------------------------------------

func test_initial_state_zero_counters() -> void:
	assert_eq(_state["defiance_count"], 0)
	assert_eq(_state["overreach_count"], 0)
	assert_eq(_state["consecutive_crisis_vetoes"], 0)
	assert_eq(_state["consecutive_obstruction_seasons"], 0)
	assert_eq(_state["failed_proposals"], {})


# -- Resubmission ban (s55.10.3.4) -------------------------------------------

func test_proposal_not_banned_after_one_failure() -> void:
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 10
	)
	assert_false(PhoenixCouncil.is_proposal_banned(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 10
	))


func test_proposal_banned_after_two_failures() -> void:
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 10
	)
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 11
	)
	assert_true(PhoenixCouncil.is_proposal_banned(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 11
	))


func test_proposal_ban_expires_after_two_seasons() -> void:
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.DECLARE_WAR, 5
	)
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.DECLARE_WAR, 6
	)
	assert_true(PhoenixCouncil.is_proposal_banned(
		_state, PhoenixCouncil.DecisionType.DECLARE_WAR, 7
	))
	assert_false(PhoenixCouncil.is_proposal_banned(
		_state, PhoenixCouncil.DecisionType.DECLARE_WAR, 8
	))


func test_clear_failed_proposal_removes_ban() -> void:
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 10
	)
	PhoenixCouncil.record_failed_proposal(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 11
	)
	PhoenixCouncil.clear_failed_proposal(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY
	)
	assert_false(PhoenixCouncil.is_proposal_banned(
		_state, PhoenixCouncil.DecisionType.SIGN_TREATY, 11
	))


# -- Stage consequences -----------------------------------------------------

func test_defiance_returns_consequences() -> void:
	var result: Dictionary = PhoenixCouncil.handle_unilateral_action(_state)
	assert_eq(result["stage"], 1)
	assert_eq(result["honor_penalty"], -0.3)
	assert_false(result["diplomatic_suspended"])


func test_defiance_stage_2_consequences_include_diplomatic() -> void:
	PhoenixCouncil.handle_unilateral_action(_state)
	var result: Dictionary = PhoenixCouncil.handle_unilateral_action(_state)
	assert_eq(result["stage"], 2)
	assert_true(result["diplomatic_suspended"])
	assert_false(result["shugenja_withdrawn"])


func test_overreach_returns_consequences() -> void:
	var result: Dictionary = PhoenixCouncil.handle_overreach_trigger(_state)
	assert_eq(result["stage"], 1)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_4)
	assert_false(_state["phoenix_champion_authority"])


# -- evaluate_reincarnation_schism_outcome (s55.10.3.7) ----------------------

func _make_phoenix_champion(
	bv: Enums.BushidoVirtue, sv: Enums.ShouridoVirtue
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 200
	c.character_name = "Shiba Reborn"
	c.clan = "Phoenix"
	c.family = "Shiba"
	c.bushido_virtue = bv
	c.shourido_virtue = sv
	return c


func test_chugi_high_duty_capitulates() -> void:
	var c: L5RCharacterData = _make_phoenix_champion(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(c, 0, 70)
	assert_true(result["capitulates"])
	assert_eq(result["reason"], "chugi_duty")


func test_chugi_low_duty_falls_to_disposition() -> void:
	# Chugi but duty_score < 60 — doesn't auto-capitulate; check disposition.
	var c: L5RCharacterData = _make_phoenix_champion(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(c, 0, 50)
	# disposition 0 is not Friend+ (threshold 31), so does not capitulate.
	assert_false(result["capitulates"])
	assert_eq(result["reason"], "neutral_or_hostile")


func test_ishi_continues_defiance() -> void:
	var c: L5RCharacterData = _make_phoenix_champion(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI
	)
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(c, 0, 30)
	assert_false(result["capitulates"])
	assert_eq(result["reason"], "ishi_will")


func test_seigyo_continues_defiance() -> void:
	var c: L5RCharacterData = _make_phoenix_champion(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO
	)
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(c, 35, 30)
	# Even with friend-level disposition, Seigyo keeps power.
	assert_false(result["capitulates"])
	assert_eq(result["reason"], "seigyo_control")


func test_friendly_disposition_capitulates_without_strong_virtue() -> void:
	var c: L5RCharacterData = _make_phoenix_champion(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(c, 35, 30)
	# disposition_to_council_avg >= FRIEND_DISPOSITION_THRESHOLD (31)
	assert_true(result["capitulates"])
	assert_eq(result["reason"], "friendly_disposition")


func test_hostile_disposition_continues_defiance() -> void:
	var c: L5RCharacterData = _make_phoenix_champion(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(c, 10, 30)
	assert_false(result["capitulates"])
	assert_eq(result["reason"], "neutral_or_hostile")


func test_null_champion_capitulates() -> void:
	var result: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(null, 0, 0)
	assert_true(result["capitulates"])
	assert_eq(result["reason"], "no_champion")


# -- make_initial_state includes known_champion_id ----------------------------

func test_initial_state_has_known_champion_id() -> void:
	assert_has(_state, "known_champion_id")
	assert_eq(int(_state["known_champion_id"]), -1)


# -- Reincarnation-with-flag: first-season evaluation (s55.10.3.7) -----------
# Tests call DayOrchestrator._process_phoenix_council_gating() directly.


func _make_champion(id: int, bv: Enums.BushidoVirtue, sv: Enums.ShouridoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Champion %d" % id
	c.clan = "Phoenix"
	c.family = "Shiba"
	c.status = 6.0
	c.lord_id = -1
	c.wounds_taken = 0
	c.stamina = 3   # Earth ring = min(stamina, willpower)
	c.willpower = 3
	c.void_ring = 2
	c.bushido_virtue = bv
	c.shourido_virtue = sv
	return c


func test_known_champion_id_updated_on_first_season() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	var champion: L5RCharacterData = _make_champion(
		10, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		_state, [], [champion], {10: champion},
		DiceEngine.new(), [], [9000], 1, [], {}, 0,
	)
	assert_eq(int(_state["known_champion_id"]), 10)
	assert_true(result.get("skipped", false))


func test_champion_change_triggers_reincarnation_eval() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	_state["known_champion_id"] = 99   # previous champion

	# New champion with Chugi virtue → restores compact.
	var new_champ: L5RCharacterData = _make_champion(
		10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		_state, [], [new_champ], {10: new_champ},
		DiceEngine.new(), [], [9000], 1, [], {}, 0,
	)
	assert_true(result.get("reincarnation_eval", false))
	assert_true(result.get("compact_restored", false))
	assert_false(
		PhoenixCouncil.has_champion_authority(_state),
		"Compact should be restored — authority flag cleared"
	)
	assert_eq(int(_state["known_champion_id"]), 10)


func test_champion_change_ishi_retains_authority() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	_state["known_champion_id"] = 99   # previous champion

	# New champion with Ishi virtue → keeps authority.
	var new_champ: L5RCharacterData = _make_champion(
		10, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI
	)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		_state, [], [new_champ], {10: new_champ},
		DiceEngine.new(), [], [9000], 1, [], {}, 0,
	)
	assert_true(result.get("reincarnation_eval", false))
	assert_false(result.get("compact_restored", false))
	assert_true(
		PhoenixCouncil.has_champion_authority(_state),
		"Authority should be retained when Ishi champion declines restoration"
	)


func test_no_champion_change_skips_without_eval() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	_state["known_champion_id"] = 10   # same champion

	var same_champ: L5RCharacterData = _make_champion(
		10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		_state, [], [same_champ], {10: same_champ},
		DiceEngine.new(), [], [9000], 1, [], {}, 0,
	)
	# Same champion — no eval. Skips normally.
	assert_false(result.get("reincarnation_eval", false))
	assert_true(result.get("skipped", false))
	# Authority stays.
	assert_true(PhoenixCouncil.has_champion_authority(_state))


func test_first_ever_call_sets_known_champion_no_eval() -> void:
	# known_champion_id == -1 (initial state) AND champion present.
	# Should NOT trigger eval — this is the very first season, not a reincarnation.
	PhoenixCouncil.grant_champion_authority(_state)
	assert_eq(int(_state["known_champion_id"]), -1)

	var champion: L5RCharacterData = _make_champion(
		10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	var result: Dictionary = DayOrchestrator._process_phoenix_council_gating(
		_state, [], [champion], {10: champion},
		DiceEngine.new(), [], [9000], 1, [], {}, 0,
	)
	assert_false(result.get("reincarnation_eval", false))
	assert_eq(int(_state["known_champion_id"]), 10)
	# Authority still held.
	assert_true(PhoenixCouncil.has_champion_authority(_state))
	assert_eq(_state["tabled_proposals"], {})


# -- RESTORE_COUNCIL_COMPACT: ActionExecutor output --------------------------

func test_restore_compact_action_returns_required_effect() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "RESTORE_COUNCIL_COMPACT"
	action.target_npc_id = -1
	action.target_province_id = -1

	var champion: L5RCharacterData = _make_champion(10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE)
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 10
	ctx.ic_day = 100
	ctx.season = 5
	ctx.phoenix_champion_authority = true

	var result: Dictionary = ActionExecutor.execute(
		action, champion, ctx, DiceEngine.new(), {}
	)

	assert_true(result["success"])
	assert_eq(result["action_id"], "RESTORE_COUNCIL_COMPACT")
	assert_true(result["effects"].get("requires_compact_restoration", false))
	assert_eq(int(result["effects"]["restoring_champion_id"]), 10)


# -- RESTORE_COUNCIL_COMPACT: _process_compact_restorations wiring -----------

func test_process_compact_restorations_clears_authority_flag() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	assert_true(PhoenixCouncil.has_champion_authority(_state))

	var applied_list: Array = [
		{
			"action_id": "RESTORE_COUNCIL_COMPACT",
			"character_id": 10,
			"effects": {
				"requires_compact_restoration": true,
				"restoring_champion_id": 10,
			},
		}
	]

	var results: Array = DayOrchestrator._process_compact_restorations(
		applied_list, _state
	)

	assert_false(PhoenixCouncil.has_champion_authority(_state))
	assert_eq(results.size(), 1)
	assert_eq(results[0]["event"], "compact_restored")
	assert_eq(int(results[0]["restoring_champion_id"]), 10)


func test_process_compact_restorations_skips_empty_state() -> void:
	var results: Array = DayOrchestrator._process_compact_restorations(
		[{"effects": {"requires_compact_restoration": true}}],
		{}   # empty state
	)
	assert_eq(results.size(), 0)


func test_process_compact_restorations_ignores_non_compact_effects() -> void:
	PhoenixCouncil.grant_champion_authority(_state)
	var applied_list: Array = [
		{"effects": {"requires_war_creation": true}},
		{"effects": {}},
	]
	DayOrchestrator._process_compact_restorations(applied_list, _state)
	assert_true(PhoenixCouncil.has_champion_authority(_state))


# -- RESTORE_COUNCIL_COMPACT: generate_options gate --------------------------

func test_generate_options_excludes_compact_when_no_authority() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 10
	ctx.clan = "Phoenix"
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.phoenix_champion_authority = false
	ctx.is_lord = true
	ctx.civilian_orders_remaining = 3

	var need := NPCDataStructures.ImmediateNeed.new()
	var options: Array = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array = []
	for opt in options:
		action_ids.append(opt.action_id)
	assert_false("RESTORE_COUNCIL_COMPACT" in action_ids)


func test_generate_options_includes_compact_when_authority_held() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 10
	ctx.clan = "Phoenix"
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.phoenix_champion_authority = true
	ctx.is_lord = true
	ctx.civilian_orders_remaining = 3
	ctx.ap_remaining = 5

	var need := NPCDataStructures.ImmediateNeed.new()
	var options: Array = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array = []
	for opt in options:
		action_ids.append(opt.action_id)
	assert_true("RESTORE_COUNCIL_COMPACT" in action_ids)


# =============================================================================
# GRAND RITUAL DEVASTATING EFFECT (s55.10.3.7)
# =============================================================================

func _make_master(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Phoenix"
	c.family = "Isawa"
	c.status = 5.0
	c.honor = 5.0
	return c


func _make_province(id: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.stability = 80.0
	p.grand_ritual_devastated = false
	return p


func test_grand_ritual_sets_stability_to_zero():
	var province: ProvinceData = _make_province(1)
	var result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(
		province, [], [], -1
	)
	assert_true(result.get("applied", false))
	assert_eq(province.stability, 0.0)


func test_grand_ritual_sets_devastated_flag():
	var province: ProvinceData = _make_province(1)
	PhoenixCouncil.apply_grand_ritual_devastation(province, [], [], -1)
	assert_true(province.grand_ritual_devastated)


func test_grand_ritual_penalizes_surviving_masters():
	var province: ProvinceData = _make_province(1)
	var m1: L5RCharacterData = _make_master(10)
	var m2: L5RCharacterData = _make_master(11)
	var result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(
		province, [m1, m2], [], -1
	)
	assert_eq(result.get("honor_cost_per_master", 0.0), PhoenixCouncil.GRAND_RITUAL_HONOR_COST)
	assert_true(m1.honor < 5.0)
	assert_true(m2.honor < 5.0)
	assert_eq(result["masters_penalized"].size(), 2)


func test_grand_ritual_applies_empire_disposition_to_status5_reps():
	var province: ProvinceData = _make_province(1)
	var rep: L5RCharacterData = L5RCharacterData.new()
	rep.character_id = 50
	rep.clan = "Crane"
	rep.status = 6.0
	var low_rank: L5RCharacterData = L5RCharacterData.new()
	low_rank.character_id = 51
	low_rank.clan = "Crab"
	low_rank.status = 2.0
	var result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(
		province, [], [rep, low_rank], 99
	)
	assert_eq(rep.disposition_values.get(99, 0), PhoenixCouncil.GRAND_RITUAL_EMPIRE_DISPOSITION)
	assert_eq(low_rank.disposition_values.get(99, 0), PhoenixCouncil.GRAND_RITUAL_EMPIRE_DISPOSITION,
		"All non-Phoenix reps affected regardless of status")
	assert_eq(result["reps_affected"].size(), 2)


func test_grand_ritual_skips_phoenix_clan_reps():
	var province: ProvinceData = _make_province(1)
	var phoenix_rep: L5RCharacterData = L5RCharacterData.new()
	phoenix_rep.character_id = 55
	phoenix_rep.clan = "Phoenix"
	phoenix_rep.status = 7.0
	PhoenixCouncil.apply_grand_ritual_devastation(province, [], [phoenix_rep], 99)
	assert_eq(phoenix_rep.disposition_values.get(99, 0), 0, "Phoenix members should not be affected")


func test_grand_ritual_returns_crisis_topic_dict():
	var province: ProvinceData = _make_province(1)
	var result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(province, [], [], -1)
	var ct: Dictionary = result.get("crisis_topic", {})
	assert_false(ct.is_empty())
	assert_eq(ct.get("tier", -1), TopicData.Tier.TIER_1)
	assert_eq(ct.get("variant", ""), "grand_ritual_devastation")


func test_grand_ritual_null_province_returns_not_applied():
	var result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(null, [], [], -1)
	assert_false(result.get("applied", true))


# -- Audit: Dead character guards (2026-05-23) ---------------------------------

func test_grand_ritual_skips_dead_representatives() -> void:
	var province := _make_province(1)
	var dead_rep := L5RCharacterData.new()
	dead_rep.character_id = 50
	dead_rep.clan = "Crane"
	dead_rep.status = 7.0
	dead_rep.stamina = 2
	dead_rep.willpower = 2
	dead_rep.wounds_taken = 999
	dead_rep.disposition_values = {99: 10}
	var result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(
		province, [], [dead_rep], 99
	)
	assert_eq(dead_rep.disposition_values.get(99, 0), 10,
		"Dead representative disposition should not change")
	assert_eq(result.get("reps_affected", []).size(), 0,
		"Dead reps should not appear in affected list")
