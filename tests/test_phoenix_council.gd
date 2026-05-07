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


# -- Per-master vote evaluation (personality-driven) -------------------------

func test_yu_master_votes_yes_on_declare_war() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.FIRE, prop, 0, _dice,
		Enums.BushidoVirtue.YU
	)
	assert_eq(ev["vote"], "yes")


func test_yu_master_votes_no_on_sign_treaty() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.FIRE, prop, 0, _dice,
		Enums.BushidoVirtue.YU
	)
	assert_eq(ev["vote"], "no")


func test_jin_master_votes_yes_on_sign_treaty() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.WATER, prop, 0, _dice,
		Enums.BushidoVirtue.JIN
	)
	assert_eq(ev["vote"], "yes")


func test_rei_master_votes_yes_on_sign_treaty() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.AIR, prop, 0, _dice,
		Enums.BushidoVirtue.REI
	)
	assert_eq(ev["vote"], "yes")


func test_rei_master_votes_no_on_declare_war() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.AIR, prop, 0, _dice,
		Enums.BushidoVirtue.REI
	)
	assert_eq(ev["vote"], "no")


func test_jin_master_votes_no_on_declare_war() -> void:
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var ev: Dictionary = PhoenixCouncil.evaluate_master_vote(
		PhoenixCouncil.Master.EARTH, prop, 0, _dice,
		Enums.BushidoVirtue.JIN
	)
	assert_eq(ev["vote"], "no")


func test_no_virtue_master_votes_no_by_default() -> void:
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
	# Gi gives +5 on treaty, rival -5 → net 0 → NO.
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
	# Rei -10 + crisis +15 = +5 → YES.
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
	# Rei -10 + element threatened +20 = +10 → YES.
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
	# Sign-treaty proposal: 3 Jin/Rei Masters lean YES, 1 Yu leans NO.
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.SIGN_TREATY}
	var living: Array = [
		PhoenixCouncil.Master.FIRE,
		PhoenixCouncil.Master.WATER,
		PhoenixCouncil.Master.AIR,
		PhoenixCouncil.Master.EARTH,
	]
	var virtues: Dictionary = {
		PhoenixCouncil.Master.FIRE: {"bushido": Enums.BushidoVirtue.YU},
		PhoenixCouncil.Master.WATER: {"bushido": Enums.BushidoVirtue.JIN},
		PhoenixCouncil.Master.AIR: {"bushido": Enums.BushidoVirtue.REI},
		PhoenixCouncil.Master.EARTH: {"bushido": Enums.BushidoVirtue.CHUGI},
	}
	var result: Dictionary = PhoenixCouncil.tally_vote(living, prop, {}, _dice, virtues)
	assert_eq(result["yes"], 3)
	assert_eq(result["no"], 1)
	assert_true(result["passed"])


func test_tally_fails_with_only_one_yes_on_war() -> void:
	# Declare-war: 1 Yu YES, 3 peaceful Masters NO.
	var prop: Dictionary = {"decision_type": PhoenixCouncil.DecisionType.DECLARE_WAR}
	var living: Array = [
		PhoenixCouncil.Master.FIRE,
		PhoenixCouncil.Master.WATER,
		PhoenixCouncil.Master.AIR,
		PhoenixCouncil.Master.EARTH,
	]
	var virtues: Dictionary = {
		PhoenixCouncil.Master.FIRE: {"bushido": Enums.BushidoVirtue.YU},
		PhoenixCouncil.Master.WATER: {"bushido": Enums.BushidoVirtue.JIN},
		PhoenixCouncil.Master.AIR: {"bushido": Enums.BushidoVirtue.REI},
		PhoenixCouncil.Master.EARTH: {"bushido": Enums.BushidoVirtue.JIN},
	}
	var result: Dictionary = PhoenixCouncil.tally_vote(living, prop, {}, _dice, virtues)
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
	assert_false(_state["phoenix_champion_authority"])
	assert_eq(_state["tabled_proposals"], {})
