extends GutTest


var _actor: L5RCharacterData
var _target: L5RCharacterData
var _characters: Dictionary
var _provinces: Dictionary
var _action_log: Array


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
	var settlements: Array = [settlement]
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
	var results: Array = [
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
	var all_applied: Array = EffectApplicator.apply_day_results(
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


# -- Gossip 3rd-party disposition (s15.4) --------------------------------------

func test_gossip_effect_mutates_listener_toward_subject() -> void:
	var subject := L5RCharacterData.new()
	subject.character_id = 99
	subject.character_name = "Subject"
	_target.disposition_values = {99: 20}
	_characters[99] = subject

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "GOSSIP",
		"ic_day": 5,
		"effects": {
			"gossip_subject_id": 99,
			"gossip_subject_disposition": -5,
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(_target.disposition_values[99], 15)
	assert_eq(applied["disposition_changes"].size(), 1)
	assert_eq(applied["disposition_changes"][0]["actor_id"], 2)
	assert_eq(applied["disposition_changes"][0]["target_id"], 99)
	assert_eq(applied["disposition_changes"][0]["delta"], -5)


func test_gossip_effect_no_op_without_subject_id() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "GOSSIP",
		"ic_day": 5,
		"effects": {"gossip_subject_id": -1, "gossip_subject_disposition": -5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_target.disposition_values.get(99, 0), 0)


func test_gossip_effect_clamps_to_minus_100() -> void:
	var subject := L5RCharacterData.new()
	subject.character_id = 99
	_target.disposition_values = {99: -95}
	_characters[99] = subject

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "GOSSIP",
		"ic_day": 5,
		"effects": {"gossip_subject_id": 99, "gossip_subject_disposition": -15},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_target.disposition_values[99], -100)


# -- Per-witness disposition toward target (PUBLIC_INSULT s15.4) ---------------

func test_target_witness_disposition_mutates_witnesses() -> void:
	var witness_a := L5RCharacterData.new()
	witness_a.character_id = 50
	witness_a.character_name = "Witness A"
	witness_a.disposition_values = {2: 10}

	var witness_b := L5RCharacterData.new()
	witness_b.character_id = 51
	witness_b.character_name = "Witness B"
	witness_b.disposition_values = {2: 30}

	_characters[50] = witness_a
	_characters[51] = witness_b

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PUBLIC_INSULT",
		"ic_day": 5,
		"effects": {
			"target_witness_disposition": -4,
			"witnesses": [50, 51],
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(witness_a.disposition_values[2], 6)
	assert_eq(witness_b.disposition_values[2], 26)
	assert_eq(applied["disposition_changes"].size(), 2)


func test_target_witness_skips_target_itself() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 50
	witness.character_name = "Witness"
	witness.disposition_values = {2: 10}
	_characters[50] = witness

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PUBLIC_INSULT",
		"ic_day": 5,
		"effects": {
			"target_witness_disposition": -3,
			"witnesses": [2, 50],
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(witness.disposition_values[2], 7)
	assert_eq(applied["disposition_changes"].size(), 1)


func test_target_witness_no_op_without_witnesses() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PUBLIC_INSULT",
		"ic_day": 5,
		"effects": {"target_witness_disposition": -3, "witnesses": []},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["disposition_changes"].size(), 0)


# -- Witness disposition gain (broadcast actions s12.2 Category 2) -------------

func test_witness_gain_mutates_witnesses_toward_actor() -> void:
	var witness_a := L5RCharacterData.new()
	witness_a.character_id = 50
	witness_a.character_name = "Witness A"
	witness_a.disposition_values = {1: 5}

	var witness_b := L5RCharacterData.new()
	witness_b.character_id = 51
	witness_b.character_name = "Witness B"
	witness_b.disposition_values = {1: -3}

	_characters[50] = witness_a
	_characters[51] = witness_b

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "PUBLIC_DEBATE",
		"ic_day": 5,
		"effects": {
			"witness_disposition_gain": 3,
			"witnesses": [50, 51],
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(witness_a.disposition_values[1], 8)
	assert_eq(witness_b.disposition_values[1], 0)
	assert_eq(applied["disposition_changes"].size(), 2)


func test_witness_gain_skips_actor() -> void:
	var witness := L5RCharacterData.new()
	witness.character_id = 50
	witness.character_name = "Witness"
	witness.disposition_values = {1: 0}
	_characters[50] = witness

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "PUBLIC_DEBATE",
		"ic_day": 5,
		"effects": {
			"witness_disposition_gain": 2,
			"witnesses": [1, 50],
		},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(applied["disposition_changes"].size(), 1)
	assert_eq(witness.disposition_values[1], 2)


# -- Family/Clan Disposition Ripple (s12.2) ------------------------------------

func test_family_ripple_on_disposition_change() -> void:
	var family_member := L5RCharacterData.new()
	family_member.character_id = 60
	family_member.character_name = "Family Member"
	family_member.clan = "Crane"
	family_member.family = "Doji"

	_target.clan = "Crane"
	_target.family = "Doji"
	_actor.clan = "Lion"
	_actor.family = "Akodo"
	_characters[60] = family_member

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 8},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values.get(60, 0), 2)


func test_clan_ripple_different_family() -> void:
	var clan_member := L5RCharacterData.new()
	clan_member.character_id = 61
	clan_member.character_name = "Clan Member"
	clan_member.clan = "Crane"
	clan_member.family = "Kakita"

	_target.clan = "Crane"
	_target.family = "Doji"
	_actor.clan = "Lion"
	_actor.family = "Akodo"
	_characters[61] = clan_member

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 8},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values.get(61, 0), 1)


func test_negative_ripple_on_negative_disposition() -> void:
	var family_member := L5RCharacterData.new()
	family_member.character_id = 60
	family_member.character_name = "Family Member"
	family_member.clan = "Crane"
	family_member.family = "Doji"

	_target.clan = "Crane"
	_target.family = "Doji"
	_actor.clan = "Lion"
	_actor.family = "Akodo"
	_characters[60] = family_member

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": -5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values.get(60, 0), -2)


func test_ripple_capped_at_family_cap() -> void:
	var family_member := L5RCharacterData.new()
	family_member.character_id = 60
	family_member.character_name = "Family Member"
	family_member.clan = "Crane"
	family_member.family = "Doji"

	_target.clan = "Crane"
	_target.family = "Doji"
	_actor.clan = "Lion"
	_actor.family = "Akodo"
	_actor.disposition_values[60] = 29
	_characters[60] = family_member

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 8},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.disposition_values.get(60, 0), 30)


func test_ripple_no_op_when_at_cap() -> void:
	var family_member := L5RCharacterData.new()
	family_member.character_id = 60
	family_member.character_name = "Family Member"
	family_member.clan = "Crane"
	family_member.family = "Doji"

	_target.clan = "Crane"
	_target.family = "Doji"
	_actor.clan = "Lion"
	_actor.family = "Akodo"
	_actor.disposition_values[60] = 30
	_characters[60] = family_member

	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 8},
	}
	var applied: Dictionary = EffectApplicator.apply(
		result, _characters, _provinces, _action_log
	)
	assert_eq(_actor.disposition_values.get(60, 0), 30)
	var ripple_found: bool = false
	for change: Dictionary in applied["disposition_changes"]:
		if change.get("target_id", -1) == 60:
			ripple_found = true
	assert_false(ripple_found)


# =============================================================================
# Koku Cost Deduction (s55.32)
# =============================================================================

func test_koku_cost_deducted_on_success() -> void:
	_actor.koku = 20.0
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "BRIBE_FOR_INFO",
		"ic_day": 5,
		"effects": {"koku_cost": 5.0},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.koku, 15.0, 0.01)


func test_koku_cost_deducted_on_failed_with_marker() -> void:
	_actor.koku = 10.0
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "BRIBE_FOR_INFO",
		"ic_day": 5,
		"effects": {"failed": true, "koku_cost": 5.0},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.koku, 5.0, 0.01)


func test_koku_cost_clamps_to_zero() -> void:
	_actor.koku = 2.0
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PURCHASE_MARKET",
		"ic_day": 5,
		"effects": {"koku_cost": 3.0},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.koku, 0.0, 0.01)


func test_no_koku_cost_when_absent() -> void:
	_actor.koku = 10.0
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.koku, 10.0, 0.01)


func test_koku_cost_skipped_when_blocked() -> void:
	_actor.koku = 10.0
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "BRIBE_FOR_INFO",
		"ic_day": 5,
		"effects": {},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(_actor.koku, 10.0, 0.01)


# -- Gossip Source Concealment -------------------------------------------------

func test_gossip_unconcealed_creates_knowledge_with_gossiper_id() -> void:
	_target.knowledge_pool = []
	var subject := L5RCharacterData.new()
	subject.character_id = 3
	_characters[3] = subject
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "GOSSIP",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"gossip_subject_id": 3,
			"gossip_subject_disposition": -5,
			"source_concealed": false,
			"concealment_depth": 0,
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_target.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = _target.knowledge_pool[0]
	assert_eq(entry.entry_type, "gossip_received")
	assert_eq(entry.data["gossiper_id"], 1, "Unconcealed gossip should attribute the gossiper")
	assert_eq(entry.data["subject_id"], 3)


func test_gossip_concealed_hides_gossiper_id() -> void:
	_target.knowledge_pool = []
	var subject := L5RCharacterData.new()
	subject.character_id = 3
	_characters[3] = subject
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "GOSSIP",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"gossip_subject_id": 3,
			"gossip_subject_disposition": -5,
			"source_concealed": true,
			"concealment_depth": 2,
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_target.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = _target.knowledge_pool[0]
	assert_eq(entry.entry_type, "gossip_received")
	assert_eq(entry.data["gossiper_id"], -1, "Concealed gossip should hide the gossiper")
	assert_eq(entry.data["subject_id"], 3)


func test_gossip_action_log_includes_source_concealed() -> void:
	var subject := L5RCharacterData.new()
	subject.character_id = 3
	_characters[3] = subject
	_target.knowledge_pool = []
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "GOSSIP",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"gossip_subject_id": 3,
			"gossip_subject_disposition": -5,
			"source_concealed": true,
			"concealment_depth": 2,
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_action_log.size(), 1)
	assert_true(_action_log[0].has("source_concealed"), "Action log should include source_concealed")
	assert_true(_action_log[0]["source_concealed"])
	assert_eq(_action_log[0]["concealment_depth"], 2)


func test_non_gossip_action_log_omits_source_concealed() -> void:
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"ic_day": 5,
		"effects": {"disposition_change": 5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_action_log.size(), 1)
	assert_false(_action_log[0].has("source_concealed"), "Non-gossip actions should not have source_concealed")


# -- False Info on Critical Failure --------------------------------------------

func test_false_info_personality_creates_wrong_virtue() -> void:
	_actor.knowledge_pool = []
	_target.bushido_virtue = Enums.BushidoVirtue.GI
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "READ_CHARACTER",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"failed": true,
			"false_info": ["personality_insight"],
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = _actor.knowledge_pool[0]
	assert_eq(entry.entry_type, "personality_insight")
	assert_eq(entry.source, Enums.KnowledgeSource.INTELLIGENCE)
	assert_eq(entry.confidence, Enums.KnowledgeConfidence.FRESH)
	assert_ne(entry.data["bushido_virtue"], Enums.BushidoVirtue.GI, "False virtue should differ from actual")
	assert_true(entry.data["is_false"])


func test_false_info_disposition_inverts_sign() -> void:
	_actor.knowledge_pool = []
	_target.disposition_values = {1: 30}
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "READ_CHARACTER",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"failed": true,
			"false_info": ["disposition_toward"],
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = _actor.knowledge_pool[0]
	assert_eq(entry.data["disposition"], -30, "False disposition should invert actual")
	assert_true(entry.data["is_false"])


func test_false_info_topic_position_inverted() -> void:
	_actor.knowledge_pool = []
	_target.topic_positions = {100: 25.0}
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "PROBE",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"failed": true,
			"false_info": ["topic_position"],
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.knowledge_pool.size(), 1)
	var entry: KnowledgeEntry = _actor.knowledge_pool[0]
	assert_eq(entry.data["topic_id"], 100)
	assert_almost_eq(entry.data["position"], -25.0, 0.01, "False position should invert actual")
	assert_true(entry.data["is_false"])


func test_false_info_no_entry_without_target() -> void:
	_actor.knowledge_pool = []
	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": -1,
		"action_id": "READ_CHARACTER",
		"ic_day": 5,
		"season": 2,
		"effects": {
			"failed": true,
			"false_info": ["personality_insight"],
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.knowledge_pool.size(), 0, "No false info without valid target")


# -- Winner Glory Application (duel non-actor winner) -------------------------

func test_winner_glory_change_applied_to_non_actor_winner() -> void:
	var winner := L5RCharacterData.new()
	winner.character_id = 90
	winner.glory = 3.0
	_characters[90] = winner

	var result: Dictionary = {
		"success": true,
		"action_id": "ISSUE_DUEL_CHALLENGE",
		"character_id": _actor.character_id,
		"target_npc_id": 90,
		"ic_day": 1,
		"season": 0,
		"effects": {
			"winner_glory_change": 0.5,
			"winner_glory_recipient_id": 90,
		},
	}

	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(winner.glory, 3.5, 0.01,
		"Winner glory change should be applied to the winner character")


func test_winner_glory_not_applied_without_key() -> void:
	var target := L5RCharacterData.new()
	target.character_id = 91
	target.glory = 3.0
	_characters[91] = target

	var result: Dictionary = {
		"success": true,
		"action_id": "ISSUE_DUEL_CHALLENGE",
		"character_id": _actor.character_id,
		"target_npc_id": 91,
		"ic_day": 1,
		"season": 0,
		"effects": {
			"glory_change": 0.5,
		},
	}

	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_almost_eq(target.glory, 3.0, 0.01,
		"Without winner_glory_change key, target glory unchanged")


# -- False Info Dedup ----------------------------------------------------------

func test_false_info_replaces_existing_true_entry() -> void:
	_actor.knowledge_pool = []
	var true_entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 2, "bushido_virtue": _target.bushido_virtue},
		0,
	)
	InformationSystem.update_intelligence_knowledge(_actor, true_entry)
	assert_eq(_actor.knowledge_pool.size(), 1)

	var result: Dictionary = {
		"success": false,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "READ_CHARACTER",
		"ic_day": 5,
		"season": 1,
		"effects": {
			"failed": true,
			"false_info": ["personality_insight"],
		},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_eq(_actor.knowledge_pool.size(), 1,
		"False info should replace existing true entry, not append")
	assert_true(_actor.knowledge_pool[0].data.get("is_false", false),
		"Entry should be the false version")


# -- Audit: Dead character guards (2026-05-22) ---------------------------------

func test_disposition_ripple_skips_dead_clan_members() -> void:
	var dead_clan_member := L5RCharacterData.new()
	dead_clan_member.character_id = 5
	dead_clan_member.clan = "Lion"
	dead_clan_member.family = "Akodo"
	dead_clan_member.stamina = 2
	dead_clan_member.willpower = 2
	dead_clan_member.wounds_taken = 999
	_characters[5] = dead_clan_member
	_target.clan = "Lion"
	_target.family = "Akodo"
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"effects": {"disposition_change": 5},
	}
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	assert_false(dead_clan_member.disposition_values.has(1),
		"Dead clan member should not receive disposition ripple")


func test_recipient_disposition_skips_dead_recipient() -> void:
	_target.wounds_taken = 999
	var result: Dictionary = {
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "DELIVER_GIFT",
		"effects": {"recipient_disposition_change": 10, "consume_item_id": -1},
	}
	var old_disp: int = _target.disposition_values.get(1, 0)
	EffectApplicator.apply(result, _characters, _provinces, _action_log)
	var new_disp: int = _target.disposition_values.get(1, 0)
	assert_eq(new_disp, old_disp,
		"Dead recipient should not receive disposition change")
