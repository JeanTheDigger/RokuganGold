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


# -- Witness Disposition Loss --------------------------------------------------

func test_witness_disposition_loss_applied() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 3
	witness.character_name = "Witness"
	witness.disposition_values = {1: 10}
	_characters[3] = witness

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "INTIMIDATE",
		"ic_day": 5,
		"effects": {
			"disposition_change": -3,
			"witness_disposition_loss": -2,
			"witnesses": [3],
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(witness.disposition_values[1], 8)
	var witness_changes: Array = applied["disposition_changes"].filter(
		func(c: Dictionary) -> bool: return c["actor_id"] == 3
	)
	assert_eq(witness_changes.size(), 1)
	assert_eq(witness_changes[0]["delta"], -2)


func test_witness_loss_skips_actor() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "INTIMIDATE",
		"ic_day": 5,
		"effects": {
			"witness_disposition_loss": -2,
			"witnesses": [1, 2],
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	var witness_changes: Array = applied["disposition_changes"].filter(
		func(c: Dictionary) -> bool: return c.get("delta", 0) == -2
	)
	assert_eq(witness_changes.size(), 1)
	assert_eq(witness_changes[0]["actor_id"], 2)


func test_no_witness_effect_without_loss() -> void:
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
	var witness_related: Array = applied["disposition_changes"].filter(
		func(c: Dictionary) -> bool: return c["actor_id"] != 1
	)
	assert_eq(witness_related.size(), 0)


func test_multiple_witnesses_all_affected() -> void:
	var w1 := L5RCharacterData.new()
	w1.character_id = 3
	w1.character_name = "Witness1"
	w1.disposition_values = {}
	var w2 := L5RCharacterData.new()
	w2.character_id = 4
	w2.character_name = "Witness2"
	w2.disposition_values = {}
	_characters[3] = w1
	_characters[4] = w2

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "INTIMIDATE",
		"ic_day": 5,
		"effects": {
			"witness_disposition_loss": -5,
			"witnesses": [3, 4],
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(w1.disposition_values.get(1, 0), -5)
	assert_eq(w2.disposition_values.get(1, 0), -5)


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


# -- Infamy Changes ------------------------------------------------------------

func test_infamy_gain_applied() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "EAVESDROP",
		"ic_day": 5,
		"effects": {"infamy_gain": 0.1},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_almost_eq(_actor.infamy, 0.1, 0.01)
	assert_eq(applied["infamy_changes"].size(), 1)
	assert_almost_eq(applied["infamy_changes"][0]["delta"], 0.1, 0.01)


func test_infamy_clamped_at_10() -> void:
	_actor.infamy = 9.8
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "EAVESDROP",
		"ic_day": 5,
		"effects": {"infamy_gain": 0.5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.infamy, 10.0, 0.01)


func test_no_infamy_change_when_zero() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 3},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["infamy_changes"].size(), 0)
	assert_almost_eq(_actor.infamy, 0.0, 0.01)


func test_infamy_change_key_also_works() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "FABRICATE_SECRET",
		"ic_day": 5,
		"effects": {"infamy_change": 0.2},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_almost_eq(_actor.infamy, 0.2, 0.01)
	assert_eq(applied["infamy_changes"].size(), 1)


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


# -- Recipient-side effects (gifts) ------------------------------------------

func test_gift_recipient_disposition_lands_on_recipient_side() -> void:
	# The disposition change goes onto the recipient's record, toward the actor.
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "DELIVER_GIFT",
		"ic_day": 5,
		"effects": {
			"recipient_disposition_change": 8,
			"recipient_modifiers": [],
			"consume_item_id": -1,
			"gift_outcome": "success",
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	# Actor's disposition toward target unchanged.
	assert_eq(_actor.disposition_values.get(2, 20), 20)
	# Recipient's disposition toward actor gained +8.
	assert_eq(_target.disposition_values[1], 8)


func test_gift_consumes_item_from_actor_inventory() -> void:
	_actor.items = [
		InventorySystem.create_gift_item(7, "Tea Bowl", 2, 3),
		InventorySystem.create_gift_item(8, "Inkstone", 1, 2),
	]
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "DELIVER_GIFT",
		"ic_day": 5,
		"effects": {
			"recipient_disposition_change": 5,
			"recipient_modifiers": [],
			"consume_item_id": 7,
			"gift_outcome": "success",
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.items.size(), 1)
	assert_eq(_actor.items[0]["item_id"], 8)


func test_gift_appends_temporary_modifiers_on_recipient() -> void:
	var modifiers: Array = [
		{"event_type": "gift_fine", "value": 5, "created_ic_day": 5, "duration": 45},
		{"event_type": "gift_obligation", "value": -2, "created_ic_day": 5, "duration": -1},
	]
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "DELIVER_GIFT",
		"ic_day": 5,
		"effects": {
			"recipient_disposition_change": 5,
			"recipient_modifiers": modifiers,
			"consume_item_id": -1,
			"gift_outcome": "success",
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	var bucket: Array = _target.temporary_modifiers.get(1, [])
	assert_eq(bucket.size(), 2)
	assert_eq(bucket[0]["event_type"], "gift_fine")
	assert_eq(bucket[1]["event_type"], "gift_obligation")


func test_gift_failed_outcome_still_applies_disposition() -> void:
	# The "failed" key opts the result into the full pipeline so the
	# critical-failure disposition loss lands on the recipient.
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "DELIVER_GIFT",
		"ic_day": 5,
		"effects": {
			"recipient_disposition_change": -5,
			"recipient_modifiers": [],
			"consume_item_id": -1,
			"gift_outcome": "critical_failure",
			"failed": true,
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_target.disposition_values[1], -5)


func test_gift_consume_item_id_minus_one_is_no_op() -> void:
	_actor.items = [InventorySystem.create_gift_item(7, "Tea Bowl", 2, 3)]
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "DELIVER_GIFT",
		"ic_day": 5,
		"effects": {
			"recipient_disposition_change": 3,
			"recipient_modifiers": [],
			"consume_item_id": -1,
			"gift_outcome": "success",
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.items.size(), 1)
