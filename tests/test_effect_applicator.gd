extends GutTest


var _actor: L5RCharacterData
var _target: L5RCharacterData
var _characters: Dictionary
var _provinces: Dictionary
var _action_log: Array[Dictionary]


func before_each() -> void:
	_actor = L5RCharacterData.new()
	_actor.character_id = 1
	_actor.character_name = "Actor"
	_actor.honor = 5.0
	_actor.glory = 3.0
	_actor.disposition_values = {2: 20}

	_target = L5RCharacterData.new()
	_target.character_id = 2
	_target.character_name = "Target"

	_characters = {1: _actor, 2: _target}

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.last_report_ic_day = -1
	_provinces = {10: province}

	_action_log = []


# -- Disposition Changes -------------------------------------------------------

func test_positive_disposition_change() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 5},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(_actor.disposition_values[2], 25)
	assert_eq(applied["disposition_changes"].size(), 1)
	assert_eq(applied["disposition_changes"][0]["delta"], 5)


func test_negative_disposition_change() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "INTIMIDATE",
		"ic_day": 5,
		"effects": {"disposition_change": -8},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values[2], 12)


func test_disposition_clamped_at_100() -> void:
	_actor.disposition_values[2] = 95
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 10},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values[2], 100)


func test_disposition_clamped_at_negative_100() -> void:
	_actor.disposition_values[2] = -95
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "INTIMIDATE",
		"ic_day": 5,
		"effects": {"disposition_change": -10},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values[2], -100)


func test_no_disposition_change_without_target() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 5},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["disposition_changes"].size(), 0)


func test_disposition_created_for_new_target() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 99,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 3},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values.get(99, 0), 3)


# -- Honor Changes -------------------------------------------------------------

func test_honor_increase() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "PUBLIC_ATONEMENT",
		"ic_day": 5,
		"effects": {"honor_change": 0.5},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_almost_eq(_actor.honor, 5.5, 0.01)
	assert_eq(applied["honor_changes"].size(), 1)


func test_honor_clamped_at_10() -> void:
	_actor.honor = 9.8
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "PERFORM_RITUAL",
		"ic_day": 5,
		"effects": {"honor_change": 0.5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.honor, 10.0, 0.01)


# -- Glory Changes -------------------------------------------------------------

func test_glory_increase() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "PUBLIC_DEBATE",
		"ic_day": 5,
		"effects": {"glory_change": 0.1},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_almost_eq(_actor.glory, 3.1, 0.01)
	assert_eq(applied["glory_changes"].size(), 1)


func test_glory_decrease_on_failure() -> void:
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "PUBLIC_DEBATE",
		"ic_day": 5,
		"effects": {"failed": true, "glory_change": -0.05},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.glory, 2.95, 0.01)


# -- Province Effects ----------------------------------------------------------

func test_patrol_increases_stability() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"target_province_id": 10,
		"action_id": "ORDER_PATROL",
		"ic_day": 5,
		"effects": {"effect": "patrol_dispatched"},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_almost_eq(_provinces[10].stability, 72.0, 0.01)
	assert_eq(applied["province_updates"].size(), 1)


func test_patrol_stability_capped_at_100() -> void:
	_provinces[10].stability = 99.5
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"target_province_id": 10,
		"action_id": "ORDER_PATROL",
		"ic_day": 5,
		"effects": {"effect": "patrol_dispatched"},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_provinces[10].stability, 100.0, 0.01)


func test_garrison_assigned_increases_pu() -> void:
	var settlement := SettlementData.new()
	settlement.settlement_id = 100
	settlement.province_id = 10
	settlement.garrison_pu = 3
	var settlements: Array[SettlementData] = [settlement]
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"target_province_id": 10,
		"action_id": "ASSIGN_GARRISON",
		"ic_day": 5,
		"effects": {"effect": "garrison_assigned"},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log, settlements)
	assert_eq(settlement.garrison_pu, 4)


func test_intelligence_gathered_refreshes_report() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"target_province_id": 10,
		"action_id": "ASSESS_PROVINCE_STATUS",
		"ic_day": 15,
		"effects": {"effect": "intelligence_gathered", "info_gained": true},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_provinces[10].last_report_ic_day, 15)


func test_province_effect_skipped_for_unknown_province() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"target_province_id": 999,
		"action_id": "ORDER_PATROL",
		"ic_day": 5,
		"effects": {"effect": "patrol_dispatched"},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["province_updates"].size(), 0)


# -- Information Events --------------------------------------------------------

func test_info_gained_produces_event() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PROBE",
		"ic_day": 5,
		"effects": {"info_gained": true, "quality": 3},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["info_events"].size(), 1)
	assert_eq(applied["info_events"][0]["quality"], 3)


func test_no_info_event_without_flag() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 3},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["info_events"].size(), 0)


# -- Action Log ----------------------------------------------------------------

func test_action_logged() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"skill_used": "Etiquette",
		"effects": {"disposition_change": 3},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_action_log.size(), 1)
	assert_eq(_action_log[0]["action_id"], "CHARM")
	assert_eq(_action_log[0]["character_id"], 1)
	assert_true(_action_log[0]["success"])


func test_action_log_includes_roll_fields() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"skill_used": "Etiquette",
		"roll_total": 22,
		"tn": 15,
		"effects": {"disposition_change": 3},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_action_log[0]["roll_result"], 22)
	assert_eq(_action_log[0]["tn"], 15)
	assert_true(_action_log[0].has("observable_effect"))


func test_observable_effect_on_tier_crossing() -> void:
	_actor.disposition_values[2] = 28
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"roll_total": 20,
		"tn": 15,
		"effects": {"disposition_change": 5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_true(_action_log[0]["observable_effect"])


func test_no_observable_effect_within_tier() -> void:
	_actor.disposition_values[2] = 15
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"roll_total": 20,
		"tn": 15,
		"effects": {"disposition_change": 3},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_false(_action_log[0]["observable_effect"])


func test_failed_action_logged() -> void:
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_action_log.size(), 1)
	assert_false(_action_log[0]["success"])


# -- Batch Apply ---------------------------------------------------------------

func test_batch_apply_multiple_results() -> void:
	var results: Array[Dictionary] = [
		{
			"success": true,
			"character_id": 1,
			"target_npc_id": 2,
			"action_id": "CHARM",
			"ic_day": 5,
			"effects": {"disposition_change": 3},
		},
		{
			"success": true,
			"character_id": 1,
			"target_npc_id": -1,
			"action_id": "PERFORM_RITUAL",
			"ic_day": 5,
			"effects": {"honor_change": 0.1},
		},
	]
	var all_applied: Array[Dictionary] = EffectApplicator.apply_day_results(
		results, _characters, _provinces, _action_log
	)
	assert_eq(all_applied.size(), 2)
	assert_eq(_actor.disposition_values[2], 23)
	assert_almost_eq(_actor.honor, 5.1, 0.01)
	assert_eq(_action_log.size(), 2)


# -- Combined Effects ----------------------------------------------------------

func test_action_with_multiple_effect_types() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PUBLIC_PERFORMANCE",
		"ic_day": 5,
		"effects": {
			"disposition_change": 1,
			"glory_change": 0.1,
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values[2], 21)
	assert_almost_eq(_actor.glory, 3.1, 0.01)


func test_honor_and_province_effect_together() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"target_province_id": 10,
		"action_id": "SHARE_SUPPLIES",
		"ic_day": 5,
		"effects": {"effect": "supplies_shared", "honor_change": 0.3},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.honor, 5.3, 0.01)
