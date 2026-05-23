extends GutTest


func _make_lord(id: int, honor: float = 5.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.honor = honor
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_commitment(
	lord_id: int = 1,
	type: String = "send_supplies",
	source: CourtCommitmentData.CommitmentSource = CourtCommitmentData.CommitmentSource.VOLUNTARY,
	declared: int = 100,
	deadline: int = 200,
	amount: int = -1,
) -> CourtCommitmentData:
	return CourtCommitmentSystem.create_commitment(
		lord_id, 10, type, source, declared, deadline, amount
	)


# -- Factory -------------------------------------------------------------------

func test_create_commitment_fields():
	var c: CourtCommitmentData = CourtCommitmentSystem.create_commitment(
		1, 10, "send_military_aid",
		CourtCommitmentData.CommitmentSource.VOLUNTARY,
		100, 200, 5
	)
	assert_eq(c.lord_id, 1)
	assert_eq(c.topic_id, 10)
	assert_eq(c.commitment_type, "send_military_aid")
	assert_eq(c.source, CourtCommitmentData.CommitmentSource.VOLUNTARY)
	assert_eq(c.declared_at_ic_day, 100)
	assert_eq(c.deadline_ic_day, 200)
	assert_eq(c.resource_amount, 5)
	assert_false(c.fulfilled)
	assert_true(c.good_faith)
	assert_eq(c.ap_spent_toward, 0)

func test_create_edict_commitment():
	var c: CourtCommitmentData = CourtCommitmentSystem.create_edict_commitment(
		1, 10, "send_supplies", 100, 200, 3
	)
	assert_eq(c.source, CourtCommitmentData.CommitmentSource.EDICT)
	assert_eq(c.resource_amount, 3)


# -- Priority ------------------------------------------------------------------

func test_priority_chugi():
	var p: int = CourtCommitmentSystem.get_priority(Enums.BushidoVirtue.CHUGI)
	assert_eq(p, 100)

func test_priority_default():
	var p: int = CourtCommitmentSystem.get_priority(Enums.BushidoVirtue.JIN)
	assert_eq(p, 95)

func test_priority_none():
	var p: int = CourtCommitmentSystem.get_priority(Enums.BushidoVirtue.NONE)
	assert_eq(p, 95)


# -- Decomposition -------------------------------------------------------------

func test_decompose_military_aid():
	var c := _make_commitment(1, "send_military_aid")
	var result: Dictionary = CourtCommitmentSystem.decompose_commitment(c)
	assert_eq(result["need_type"], "HONOR_COMMITMENT")
	assert_eq(result["action_id"], "ORDER_DEPLOY")

func test_decompose_supplies():
	var c := _make_commitment(1, "send_supplies")
	var result: Dictionary = CourtCommitmentSystem.decompose_commitment(c)
	assert_eq(result["action_id"], "SHARE_SUPPLIES")

func test_decompose_shugenja():
	var c := _make_commitment(1, "send_shugenja")
	var result: Dictionary = CourtCommitmentSystem.decompose_commitment(c)
	assert_eq(result["action_id"], "ASSIGN_VASSAL_OBJECTIVE")

func test_decompose_magistrates():
	var c := _make_commitment(1, "send_magistrates")
	var result: Dictionary = CourtCommitmentSystem.decompose_commitment(c)
	assert_eq(result["action_id"], "ASSIGN_VASSAL_OBJECTIVE")

func test_decompose_unknown_type():
	var c := _make_commitment(1, "unknown_type")
	var result: Dictionary = CourtCommitmentSystem.decompose_commitment(c)
	assert_eq(result["action_id"], "DO_NOTHING")


# -- Deprioritize / Renege Willingness -----------------------------------------

func test_seigyo_deprioritizes():
	assert_true(CourtCommitmentSystem.should_deprioritize(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO
	))

func test_chugi_does_not_deprioritize():
	assert_false(CourtCommitmentSystem.should_deprioritize(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	))

func test_renege_willingness_seigyo():
	var w: float = CourtCommitmentSystem.get_renege_willingness(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO
	)
	assert_almost_eq(w, 0.8, 0.01)

func test_renege_willingness_chugi():
	var w: float = CourtCommitmentSystem.get_renege_willingness(
		Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(w, 0.05, 0.01)

func test_renege_willingness_makoto():
	var w: float = CourtCommitmentSystem.get_renege_willingness(
		Enums.BushidoVirtue.MAKOTO, Enums.ShouridoVirtue.NONE
	)
	assert_almost_eq(w, 0.1, 0.01)


# -- Fulfillment Detection ----------------------------------------------------

func test_already_fulfilled():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	c.fulfilled = true
	var log: Array = []
	assert_true(CourtCommitmentSystem.check_fulfillment(c, log))

func test_resource_fulfillment_met():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 10)
	var log: Array = [
		{"character_id": 1, "action_id": "SHARE_SUPPLIES", "amount": 6},
		{"character_id": 1, "action_id": "SHARE_SUPPLIES", "amount": 5},
	]
	assert_true(CourtCommitmentSystem.check_fulfillment(c, log))

func test_resource_fulfillment_not_met():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 10)
	var log: Array = [
		{"character_id": 1, "action_id": "SHARE_SUPPLIES", "amount": 3},
	]
	assert_false(CourtCommitmentSystem.check_fulfillment(c, log))

func test_dispatch_fulfillment():
	var c := _make_commitment(1, "send_military_aid")
	var log: Array = [
		{"character_id": 1, "action_id": "ORDER_DEPLOY", "fulfilled": true},
	]
	assert_true(CourtCommitmentSystem.check_fulfillment(c, log))

func test_dispatch_not_fulfilled():
	var c := _make_commitment(1, "send_military_aid")
	var log: Array = [
		{"character_id": 1, "action_id": "ORDER_DEPLOY", "fulfilled": false},
	]
	assert_false(CourtCommitmentSystem.check_fulfillment(c, log))

func test_wrong_lord_log_ignored():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	var log: Array = [
		{"character_id": 2, "action_id": "SHARE_SUPPLIES", "amount": 10},
	]
	assert_false(CourtCommitmentSystem.check_fulfillment(c, log))

func test_ap_spent_tracked():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 100)
	var log: Array = [
		{"character_id": 1, "action_id": "SHARE_SUPPLIES", "amount": 1},
		{"character_id": 1, "action_id": "SHARE_SUPPLIES", "amount": 1},
		{"character_id": 1, "action_id": "ORDER_DEPLOY"},
	]
	CourtCommitmentSystem.check_fulfillment(c, log)
	assert_eq(c.ap_spent_toward, 3)


# -- Renege Detection ---------------------------------------------------------

func test_renege_not_past_deadline():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	assert_false(CourtCommitmentSystem.check_renege(c, 150))

func test_renege_past_deadline_no_ap():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	c.ap_spent_toward = 0
	assert_true(CourtCommitmentSystem.check_renege(c, 200))

func test_renege_past_deadline_with_ap():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	c.ap_spent_toward = 3
	assert_false(CourtCommitmentSystem.check_renege(c, 200))

func test_renege_fulfilled_never():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	c.fulfilled = true
	assert_false(CourtCommitmentSystem.check_renege(c, 300))


# -- Renege Consequences -------------------------------------------------------

func test_voluntary_renege_honor_scaled():
	var c := _make_commitment()
	var lord := _make_lord(1, 5.0)
	var result: Dictionary = CourtCommitmentSystem.compute_renege_consequences(c, lord)
	assert_almost_eq(result["honor_change"], -2.5, 0.01)
	assert_eq(result["disposition_penalty"], -15)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_3)

func test_edict_renege_extra_honor():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.EDICT)
	var lord := _make_lord(1, 3.0)
	var result: Dictionary = CourtCommitmentSystem.compute_renege_consequences(c, lord)
	# Base -1.5 (rank 3) + -3.0 edict = -4.5
	assert_almost_eq(result["honor_change"], -4.5, 0.01)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_2)

func test_low_honor_renege():
	var c := _make_commitment()
	var lord := _make_lord(1, 0.5)
	var result: Dictionary = CourtCommitmentSystem.compute_renege_consequences(c, lord)
	assert_almost_eq(result["honor_change"], -0.5, 0.01)

func test_high_honor_renege():
	var c := _make_commitment()
	var lord := _make_lord(1, 9.5)
	var result: Dictionary = CourtCommitmentSystem.compute_renege_consequences(c, lord)
	assert_almost_eq(result["honor_change"], -4.5, 0.01)


# -- Good Faith ----------------------------------------------------------------

func test_good_faith_fulfilled():
	var c := _make_commitment()
	c.fulfilled = true
	assert_true(CourtCommitmentSystem.evaluate_good_faith(c, 300))

func test_good_faith_before_deadline_no_ap():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200)
	assert_false(CourtCommitmentSystem.evaluate_good_faith(c, 150))

func test_good_faith_before_deadline_with_ap():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200)
	c.ap_spent_toward = 2
	assert_true(CourtCommitmentSystem.evaluate_good_faith(c, 150))


# -- Seasonal Processing ------------------------------------------------------

func test_seasonal_detects_fulfillment():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 5)
	var commitments: Array = [c]
	var log: Array = [
		{"character_id": 1, "action_id": "SHARE_SUPPLIES", "amount": 5},
	]
	var lord := _make_lord(1)
	var chars: Dictionary = {1: lord}
	var result: Dictionary = CourtCommitmentSystem.process_seasonal_commitments(
		commitments, log, 150, chars
	)
	assert_eq(result["fulfilled_count"], 1)
	assert_true(c.fulfilled)

func test_seasonal_detects_renege():
	var c := _make_commitment(1, "send_supplies", CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200, 100)
	var commitments: Array = [c]
	var log: Array = []
	var lord := _make_lord(1)
	var chars: Dictionary = {1: lord}
	var result: Dictionary = CourtCommitmentSystem.process_seasonal_commitments(
		commitments, log, 250, chars
	)
	assert_eq(result["fulfilled_count"], 0)
	assert_eq(result["reneged"].size(), 1)
	assert_eq(result["reneged"][0]["lord_id"], 1)

func test_seasonal_skips_already_fulfilled():
	var c := _make_commitment()
	c.fulfilled = true
	var commitments: Array = [c]
	var log: Array = []
	var lord := _make_lord(1)
	var chars: Dictionary = {1: lord}
	var result: Dictionary = CourtCommitmentSystem.process_seasonal_commitments(
		commitments, log, 250, chars
	)
	assert_eq(result["fulfilled_count"], 0)
	assert_eq(result["reneged"].size(), 0)


# -- Queries -------------------------------------------------------------------

func test_get_active_commitments():
	var c1 := _make_commitment(1, "send_supplies")
	var c2 := _make_commitment(2, "send_supplies")
	var c3 := _make_commitment(1, "send_military_aid")
	c3.fulfilled = true
	var commitments: Array = [c1, c2, c3]
	var active: Array = CourtCommitmentSystem.get_active_commitments(commitments, 1)
	assert_eq(active.size(), 1)
	assert_eq(active[0].commitment_type, "send_supplies")

func test_has_unfulfilled_true():
	var c := _make_commitment(1, "send_supplies")
	var commitments: Array = [c]
	assert_true(CourtCommitmentSystem.has_unfulfilled_commitments(commitments, 1))

func test_has_unfulfilled_false():
	var c := _make_commitment(1, "send_supplies")
	c.fulfilled = true
	var commitments: Array = [c]
	assert_false(CourtCommitmentSystem.has_unfulfilled_commitments(commitments, 1))

func test_has_unfulfilled_wrong_lord():
	var c := _make_commitment(2, "send_supplies")
	var commitments: Array = [c]
	assert_false(CourtCommitmentSystem.has_unfulfilled_commitments(commitments, 1))


# -- Topic Commitment Check ---------------------------------------------------

func test_has_commitment_on_topic_true():
	var c := _make_commitment(1, "send_supplies")
	var commitments: Array = [c]
	assert_true(CourtCommitmentSystem.has_commitment_on_topic(commitments, 1, 10))

func test_has_commitment_on_topic_wrong_lord():
	var c := _make_commitment(2, "send_supplies")
	var commitments: Array = [c]
	assert_false(CourtCommitmentSystem.has_commitment_on_topic(commitments, 1, 10))

func test_has_commitment_on_topic_wrong_topic():
	var c := _make_commitment(1, "send_supplies")
	var commitments: Array = [c]
	assert_false(CourtCommitmentSystem.has_commitment_on_topic(commitments, 1, 99))


# -- Declarable Topics --------------------------------------------------------

func _make_famine_topic(id: int, momentum: float = 50.0) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.momentum = momentum
	t.topic_type = "famine"
	t.category = TopicData.Category.POLITICAL
	return t

func test_find_declarable_topics_above_threshold():
	var lord := _make_lord(1)
	lord.topic_positions[100] = 60.0
	var topic := _make_famine_topic(100)
	var agenda: Array = [100]
	var topics: Array = [topic]
	var commitments: Array = []
	var result: Array = CourtCommitmentSystem.find_declarable_topics(
		lord, agenda, topics, commitments,
	)
	assert_eq(result.size(), 1)
	assert_eq(result[0].topic_id, 100)

func test_find_declarable_topics_below_threshold():
	var lord := _make_lord(1)
	lord.topic_positions[100] = 40.0
	var topic := _make_famine_topic(100)
	var agenda: Array = [100]
	var topics: Array = [topic]
	var commitments: Array = []
	var result: Array = CourtCommitmentSystem.find_declarable_topics(
		lord, agenda, topics, commitments,
	)
	assert_eq(result.size(), 0)

func test_find_declarable_topics_skips_existing_commitment():
	var lord := _make_lord(1)
	lord.topic_positions[100] = 60.0
	var topic := _make_famine_topic(100)
	var agenda: Array = [100]
	var topics: Array = [topic]
	var cc := _make_commitment(1, "send_supplies")
	cc.topic_id = 100
	var commitments: Array = [cc]
	var result: Array = CourtCommitmentSystem.find_declarable_topics(
		lord, agenda, topics, commitments,
	)
	assert_eq(result.size(), 0)

func test_find_declarable_topics_skips_non_action_topic():
	var lord := _make_lord(1)
	lord.topic_positions[100] = 60.0
	var topic := TopicData.new()
	topic.topic_id = 100
	topic.topic_type = "unknown_type_no_commitment"
	var agenda: Array = [100]
	var topics: Array = [topic]
	var commitments: Array = []
	var result: Array = CourtCommitmentSystem.find_declarable_topics(
		lord, agenda, topics, commitments,
	)
	assert_eq(result.size(), 0)

func test_find_declarable_topics_skips_off_agenda():
	var lord := _make_lord(1)
	lord.topic_positions[100] = 60.0
	var topic := _make_famine_topic(100)
	var agenda: Array = [200]  # different topic on agenda
	var topics: Array = [topic]
	var commitments: Array = []
	var result: Array = CourtCommitmentSystem.find_declarable_topics(
		lord, agenda, topics, commitments,
	)
	assert_eq(result.size(), 0)

func test_find_declarable_topics_skips_resolved():
	var lord := _make_lord(1)
	lord.topic_positions[100] = 60.0
	var topic := _make_famine_topic(100)
	topic.resolved = true
	var agenda: Array = [100]
	var topics: Array = [topic]
	var commitments: Array = []
	var result: Array = CourtCommitmentSystem.find_declarable_topics(
		lord, agenda, topics, commitments,
	)
	assert_eq(result.size(), 0)


# -- Witness IDs and Historical Modifier (s15.2) --------------------------------

func test_witness_ids_field_default_empty() -> void:
	var c: CourtCommitmentData = _make_commitment()
	assert_eq(c.witness_ids.size(), 0)


func test_process_seasonal_includes_witness_ids_in_renege() -> void:
	var lord: L5RCharacterData = _make_lord(1)
	lord.honor = 5.0
	var c: CourtCommitmentData = _make_commitment(1, "send_supplies",
		CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200)
	c.witness_ids = [2, 3]
	var chars: Dictionary = {1: lord}
	var result: Dictionary = CourtCommitmentSystem.process_seasonal_commitments(
		[c], [], 201, chars,
	)
	var reneged: Array = result.get("reneged", [])
	assert_eq(reneged.size(), 1)
	var entry: Dictionary = reneged[0]
	assert_true(entry.has("witness_ids"))
	assert_eq(entry["witness_ids"], [2, 3])


func test_process_seasonal_witness_ids_empty_when_none_set() -> void:
	var lord: L5RCharacterData = _make_lord(1)
	var c: CourtCommitmentData = _make_commitment(1, "send_supplies",
		CourtCommitmentData.CommitmentSource.VOLUNTARY, 100, 200)
	var chars: Dictionary = {1: lord}
	var result: Dictionary = CourtCommitmentSystem.process_seasonal_commitments(
		[c], [], 201, chars,
	)
	var reneged: Array = result.get("reneged", [])
	assert_eq(reneged.size(), 1)
	assert_eq(reneged[0].get("witness_ids", []), [])
