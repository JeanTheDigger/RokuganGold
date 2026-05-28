extends GutTest


func _make_log_entry(overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"character_id": 1,
		"action_id": "CHARM",
		"target_npc_id": 2,
		"target_province_id": -1,
		"ic_day": 10,
		"season": 1,
		"success": true,
		"skill_used": "Courtier",
		"is_order": false,
		"roll_result": 25,
		"tn": 15,
		"observable_effect": false,
	}
	entry.merge(overrides, true)
	return entry


func _make_action_log(
	count: int,
	action_id: String = "CHARM",
	roll_result: int = 25,
	tn: int = 15,
	observable: bool = false,
) -> Array:
	var log: Array = []
	for i: int in range(count):
		log.append(_make_log_entry({
			"action_id": action_id,
			"roll_result": roll_result,
			"tn": tn,
			"observable_effect": observable,
		}))
	return log


# =============================================================================
# Measurement Thresholds
# =============================================================================

func test_social_threshold_is_two():
	assert_eq(ApproachEvaluation.get_measurement_threshold("CHARM"), 2)

func test_covert_threshold_is_three():
	assert_eq(ApproachEvaluation.get_measurement_threshold("BRIBE_FOR_INFO"), 3)

func test_military_returns_negative():
	assert_eq(ApproachEvaluation.get_measurement_threshold("ORDER_PATROL"), -1)

func test_unknown_returns_negative():
	assert_eq(ApproachEvaluation.get_measurement_threshold("REST"), -1)


# =============================================================================
# Measurement Pressure
# =============================================================================

func test_measurement_not_needed_with_zero_actions():
	var log: Array = []
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_not_needed_with_one_high_roll():
	var log: Array = _make_action_log(1)
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_needed_with_two_high_rolls_no_effect():
	var log: Array = _make_action_log(2)
	assert_true(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_not_needed_when_observable():
	var log: Array = _make_action_log(2, "CHARM", 25, 15, true)
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_not_needed_for_low_rolls():
	var log: Array = _make_action_log(3, "CHARM", 16, 15, false)
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_covert_needs_three_high_rolls():
	var log: Array = _make_action_log(2, "BRIBE_FOR_INFO", 30, 20, false)
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "BRIBE_FOR_INFO", 1))

func test_covert_triggers_at_three():
	var log: Array = _make_action_log(3, "BRIBE_FOR_INFO", 30, 20, false)
	assert_true(ApproachEvaluation.check_measurement_needed(log, 1, 2, "BRIBE_FOR_INFO", 1))

func test_measurement_scoped_to_target():
	var log: Array = _make_action_log(2)
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 99, "CHARM", 1))

func test_measurement_scoped_to_character():
	var log: Array = _make_action_log(2)
	assert_false(ApproachEvaluation.check_measurement_needed(log, 99, 2, "CHARM", 1))

func test_measurement_mixed_observable_and_not():
	var log: Array = []
	log.append(_make_log_entry({"roll_result": 25, "observable_effect": false}))
	log.append(_make_log_entry({"roll_result": 25, "observable_effect": true}))
	log.append(_make_log_entry({"roll_result": 25, "observable_effect": false}))
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_any_observable_blocks_with_enough_high_rolls():
	var log: Array = []
	log.append(_make_log_entry({"roll_result": 25, "observable_effect": true}))
	log.append(_make_log_entry({"roll_result": 25, "observable_effect": false}))
	log.append(_make_log_entry({"roll_result": 25, "observable_effect": false}))
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_scoped_to_current_season():
	var log: Array = []
	log.append(_make_log_entry({"roll_result": 25, "season": 0}))
	log.append(_make_log_entry({"roll_result": 25, "season": 0}))
	assert_false(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 1))

func test_measurement_triggers_in_correct_season():
	var log: Array = []
	log.append(_make_log_entry({"roll_result": 25, "season": 2}))
	log.append(_make_log_entry({"roll_result": 25, "season": 2}))
	assert_true(ApproachEvaluation.check_measurement_needed(log, 1, 2, "CHARM", 2))


# =============================================================================
# Approach Assessment
# =============================================================================

func test_effective_when_progress_made():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"CHARM", 2, 20, 10
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_EFFECTIVE)

func test_capped_at_charm_ceiling():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"CHARM", 2, 40, 35
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_CAPPED)

func test_capped_above_ceiling():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"CHARM", 2, 45, 35
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_CAPPED)

func test_small_progress_is_effective():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"CHARM", 2, 9, 8
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_EFFECTIVE)

func test_ineffective_regression():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"CHARM", 2, 5, 10
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE)

func test_intimidate_not_capped():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"INTIMIDATE", 2, 40, 35
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_EFFECTIVE)

func test_deliver_gift_not_capped():
	var tag: ApproachEvaluation.AssessmentTag = ApproachEvaluation.evaluate_approach(
		"DELIVER_GIFT", 2, 42, 38
	)
	assert_eq(tag, ApproachEvaluation.AssessmentTag.APPROACH_EFFECTIVE)


# =============================================================================
# Penalty Registry
# =============================================================================

func test_record_penalty_creates_entry():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(penalties.size(), 1)
	assert_eq(penalties[0]["action_id"], "CHARM")

func test_record_penalty_updates_existing():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_CAPPED, 4
	)
	assert_eq(penalties.size(), 1)
	assert_eq(penalties[0]["tag"], ApproachEvaluation.AssessmentTag.APPROACH_CAPPED)
	assert_eq(penalties[0]["season_recorded"], 4)

func test_record_penalty_separate_targets():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	ApproachEvaluation.record_penalty(
		penalties, 1, 3, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(penalties.size(), 2)


# =============================================================================
# Penalty Retrieval and Decay
# =============================================================================

func test_get_penalty_same_season():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 2, "CHARM", 3), -15)

func test_get_penalty_next_season_halved():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 2, "CHARM", 4), -7)

func test_get_penalty_two_seasons_later_cleared():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 2, "CHARM", 5), 0)

func test_get_penalty_effective_returns_zero():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_EFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 2, "CHARM", 3), 0)

func test_get_penalty_no_entry_returns_zero():
	var penalties: Array = []
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 2, "CHARM", 3), 0)

func test_get_penalty_wrong_target_returns_zero():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 99, "CHARM", 3), 0)

func test_capped_also_penalizes():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_CAPPED, 3
	)
	assert_eq(ApproachEvaluation.get_penalty(penalties, 1, 2, "CHARM", 3), -15)


# =============================================================================
# Alternative Bonus
# =============================================================================

func test_alternative_bonus_when_penalized():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_alternative_bonus(penalties, 1, 2, 3), 10)

func test_alternative_bonus_next_season():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_alternative_bonus(penalties, 1, 2, 4), 10)

func test_alternative_bonus_expired():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_alternative_bonus(penalties, 1, 2, 5), 0)

func test_alternative_bonus_wrong_target():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_alternative_bonus(penalties, 1, 99, 3), 0)

func test_effective_no_alternative_bonus():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_EFFECTIVE, 3
	)
	assert_eq(ApproachEvaluation.get_alternative_bonus(penalties, 1, 2, 3), 0)


# =============================================================================
# Penalty Decay
# =============================================================================

func test_decay_removes_old_penalties():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 1
	)
	var removed: int = ApproachEvaluation.decay_penalties(penalties, 3)
	assert_eq(removed, 1)
	assert_eq(penalties.size(), 0)

func test_decay_keeps_recent_penalties():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	var removed: int = ApproachEvaluation.decay_penalties(penalties, 4)
	assert_eq(removed, 0)
	assert_eq(penalties.size(), 1)

func test_decay_mixed_ages():
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 1
	)
	ApproachEvaluation.record_penalty(
		penalties, 1, 3, "PERSUADE",
		ApproachEvaluation.AssessmentTag.APPROACH_CAPPED, 3
	)
	var removed: int = ApproachEvaluation.decay_penalties(penalties, 3)
	assert_eq(removed, 1)
	assert_eq(penalties.size(), 1)
	assert_eq(penalties[0]["action_id"], "PERSUADE")


# =============================================================================
# Scoring Modifier Integration
# =============================================================================

func test_scoring_measurement_bonus_for_read_character():
	var log: Array = _make_action_log(2)
	var penalties: Array = []
	var mod: int = ApproachEvaluation.get_scoring_modifier(
		"READ_CHARACTER", 1, 2, log, penalties, 1
	)
	assert_eq(mod, 15)

func test_scoring_measurement_bonus_for_probe():
	var log: Array = _make_action_log(2)
	var penalties: Array = []
	var mod: int = ApproachEvaluation.get_scoring_modifier(
		"PROBE", 1, 2, log, penalties, 1
	)
	assert_eq(mod, 15)

func test_scoring_no_measurement_bonus_without_pressure():
	var log: Array = []
	var penalties: Array = []
	var mod: int = ApproachEvaluation.get_scoring_modifier(
		"READ_CHARACTER", 1, 2, log, penalties, 1
	)
	assert_eq(mod, 0)

func test_scoring_penalty_for_penalized_action():
	var log: Array = []
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	var mod: int = ApproachEvaluation.get_scoring_modifier(
		"CHARM", 1, 2, log, penalties, 3
	)
	assert_eq(mod, -15)

func test_scoring_alt_bonus_for_unpenalized_action():
	var log: Array = []
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	var mod: int = ApproachEvaluation.get_scoring_modifier(
		"PERSUADE", 1, 2, log, penalties, 3
	)
	assert_eq(mod, 10)

func test_scoring_no_bonus_for_unrelated_target():
	var log: Array = []
	var penalties: Array = []
	ApproachEvaluation.record_penalty(
		penalties, 1, 2, "CHARM",
		ApproachEvaluation.AssessmentTag.APPROACH_INEFFECTIVE, 3
	)
	var mod: int = ApproachEvaluation.get_scoring_modifier(
		"PERSUADE", 1, 99, log, penalties, 3
	)
	assert_eq(mod, 0)


# =============================================================================
# Observable Effect Detection (EffectApplicator)
# =============================================================================

func test_disposition_tier_boundaries():
	assert_eq(EffectApplicator._get_disposition_tier(-70), 0)
	assert_eq(EffectApplicator._get_disposition_tier(-50), 1)
	assert_eq(EffectApplicator._get_disposition_tier(-20), 2)
	assert_eq(EffectApplicator._get_disposition_tier(0), 3)
	assert_eq(EffectApplicator._get_disposition_tier(20), 4)
	assert_eq(EffectApplicator._get_disposition_tier(40), 5)
	assert_eq(EffectApplicator._get_disposition_tier(70), 6)
	assert_eq(EffectApplicator._get_disposition_tier(95), 7)

func test_same_tier_not_observable():
	var result: Dictionary = {"action_id": "CHARM", "success": true}
	var effects: Dictionary = {"disposition_change": 3}
	var applied: Dictionary = {
		"disposition_changes": [{"old": 15, "new": 18}],
		"province_updates": [],
	}
	assert_false(EffectApplicator._detect_observable_effect(result, effects, applied))

func test_tier_crossing_is_observable():
	var result: Dictionary = {"action_id": "CHARM", "success": true}
	var effects: Dictionary = {"disposition_change": 5}
	var applied: Dictionary = {
		"disposition_changes": [{"old": 28, "new": 33}],
		"province_updates": [],
	}
	assert_true(EffectApplicator._detect_observable_effect(result, effects, applied))

func test_info_gained_is_observable():
	var result: Dictionary = {"action_id": "PROBE", "success": true}
	var effects: Dictionary = {"info_gained": true}
	var applied: Dictionary = {
		"disposition_changes": [],
		"province_updates": [],
	}
	assert_true(EffectApplicator._detect_observable_effect(result, effects, applied))

func test_province_update_is_observable():
	var result: Dictionary = {"action_id": "ORDER_PATROL", "success": true}
	var effects: Dictionary = {}
	var applied: Dictionary = {
		"disposition_changes": [],
		"province_updates": [{"effect": "stability_increase"}],
	}
	assert_true(EffectApplicator._detect_observable_effect(result, effects, applied))

func test_no_changes_not_observable():
	var result: Dictionary = {"action_id": "CHARM", "success": true}
	var effects: Dictionary = {}
	var applied: Dictionary = {
		"disposition_changes": [],
		"province_updates": [],
	}
	assert_false(EffectApplicator._detect_observable_effect(result, effects, applied))
