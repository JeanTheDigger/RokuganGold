extends GutTest
## Maho Channel 3 ACTIVE examination (EXAMINE_FOR_TAINT, owner-authorized
## 2026-06-10). R2 corroboration: a witch-hunter who knows an active
## taint_suspected accusation deliberately examines the co-located accused
## suspect to confirm it firsthand. Roll = Lore: Shadowlands + Perception vs
## (8 − Taint Rank) × 5 (Kuni/Asako +2k0). Success refreshes the accusation,
## widens its reach to the examiner's lord, and records a dedup entry.
## NOT a Sense cast — Sense detects kami, not kansen.

func _examiner(id: int, family: String, lore: int, per: int = 6,
		loc: String = "village_a", lord: int = -1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.school_type = Enums.SchoolType.SHUGENJA
	c.family = family
	c.perception = per
	c.skills = {"Lore: Shadowlands": lore}
	c.physical_location = loc
	c.lord_id = lord
	c.topic_pool = [5000]
	return c


func _suspect(id: int, taint: float, clan: String = "Scorpion",
		loc: String = "village_a") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Suspect %d" % id
	c.taint = taint
	c.clan = clan
	c.physical_location = loc
	return c


func _accusation(topic_id: int, subject: int) -> TopicData:
	var t := TopicData.new()
	t.topic_id = topic_id
	t.title = "Suspect %d suspected of Taint corruption" % subject
	t.variant = "taint_suspected"
	t.topic_type = "accusation"
	t.tier = TopicData.Tier.TIER_3
	t.category = TopicData.Category.SUPERNATURAL
	t.subject_character_id = subject
	t.momentum = 1.0
	t.resolved = false
	return t


func _by_id(chars: Array) -> Dictionary:
	var d: Dictionary = {}
	for c: L5RCharacterData in chars:
		d[c.character_id] = c
	return d


# -- Pre-pass: target selection ------------------------------------------------

func test_prepass_finds_colocated_known_accusation() -> void:
	var e := _examiner(30, "Kuni", 6)
	var x := _suspect(40, 5.0)
	var out := DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)])
	assert_true(out.has(30), "co-located Kuni who knows the accusation gets a target")
	if out.has(30):
		assert_eq(out[30]["target_id"], 40)
		assert_eq(out[30]["topic_id"], 5000)


func test_prepass_crab_suspect_skipped() -> void:
	var e := _examiner(30, "Kuni", 6)
	var x := _suspect(40, 5.0, "Crab")
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)]).has(30),
		"Crab suspect has an innocent explanation")


func test_prepass_non_colocated_skipped() -> void:
	var e := _examiner(30, "Kuni", 6, 6, "village_b")
	var x := _suspect(40, 5.0)
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)]).has(30),
		"examiner must be co-located with the suspect")


func test_prepass_requires_known_accusation() -> void:
	var e := _examiner(30, "Kuni", 6)
	e.topic_pool = []  # does not know the accusation
	var x := _suspect(40, 5.0)
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)]).has(30),
		"examiner must already know the accusation (the named lead)")


func test_prepass_non_specialist_needs_lore3() -> void:
	var e := _examiner(30, "Isawa", 2)  # not Kuni/Asako, Lore < 3
	var x := _suspect(40, 5.0)
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)]).has(30),
		"non-specialist needs Lore: Shadowlands >= 3")


func test_prepass_low_taint_skipped() -> void:
	var e := _examiner(30, "Kuni", 6)
	var x := _suspect(40, 1.5)  # Rank 1
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)]).has(30),
		"a suspect below Rank 2 carries no corroborable Taint")


func test_prepass_already_corroborated_skipped() -> void:
	var e := _examiner(30, "Kuni", 6)
	var entry := KnowledgeEntry.new()
	entry.entry_type = "taint_corroborated"
	entry.data = {"topic_id": 5000, "target_id": 40}
	e.knowledge_pool.append(entry)
	var x := _suspect(40, 5.0)
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [_accusation(5000, 40)]).has(30),
		"the same examiner does not re-corroborate the same accusation")


func test_prepass_resolved_accusation_skipped() -> void:
	var e := _examiner(30, "Kuni", 6)
	var x := _suspect(40, 5.0)
	var t := _accusation(5000, 40)
	t.resolved = true
	assert_false(DayOrchestrator._build_taint_corroboration_targets(
		[e, x], _by_id([e, x]), [t]).has(30),
		"a resolved accusation is no longer a live lead")


# -- Executor: the examination roll -------------------------------------------

func _ctx() -> NPCDataStructures.ContextSnapshot:
	var c := NPCDataStructures.ContextSnapshot.new()
	c.ic_day = 100
	c.season = 0
	return c


func _action(target: int, topic: int) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "EXAMINE_FOR_TAINT"
	a.metadata = {"taint_target_id": target, "taint_topic_id": topic}
	return a


func test_executor_success_emits_corroboration() -> void:
	var e := _examiner(30, "Kuni", 6, 8)
	var x := _suspect(40, 5.0)  # Rank 5 → TN 15
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var r := ActionExecutor._execute_examine_for_taint(
		_action(40, 5000), e, _ctx(), dice, _by_id([e, x]))
	assert_true(r["success"], "maxed Kuni clears TN 15 against a Rank-5 suspect")
	if r["success"]:
		assert_true(r["effects"]["requires_taint_corroboration"])
		assert_eq(r["effects"]["taint_topic_id"], 5000)
		assert_eq(r["effects"]["taint_target_id"], 40)


func test_executor_crab_target_blocked() -> void:
	var e := _examiner(30, "Kuni", 6, 8)
	var x := _suspect(40, 5.0, "Crab")
	var dice := DiceEngine.new()
	var r := ActionExecutor._execute_examine_for_taint(
		_action(40, 5000), e, _ctx(), dice, _by_id([e, x]))
	assert_false(r["success"])
	assert_eq(r.get("reason", ""), "crab_exempt")


func test_executor_dead_target_blocked() -> void:
	var e := _examiner(30, "Kuni", 6, 8)
	var x := _suspect(40, 5.0)
	x.wounds_taken = 9999
	var dice := DiceEngine.new()
	var r := ActionExecutor._execute_examine_for_taint(
		_action(40, 5000), e, _ctx(), dice, _by_id([e, x]))
	assert_false(r["success"], "a dead suspect is never examined/accused")
	assert_eq(r.get("reason", ""), "no_valid_suspect")


func test_executor_untainted_target_finds_nothing() -> void:
	var e := _examiner(30, "Kuni", 6, 8)
	var x := _suspect(40, 1.0)  # Rank 1 — false lead
	var dice := DiceEngine.new()
	var r := ActionExecutor._execute_examine_for_taint(
		_action(40, 5000), e, _ctx(), dice, _by_id([e, x]))
	assert_false(r["success"])
	assert_eq(r.get("reason", ""), "no_taint_found")


# -- Writeback: corroboration effects -----------------------------------------

func test_writeback_refreshes_widens_and_dedups() -> void:
	var e := _examiner(30, "Kuni", 6, 8, "village_a", 20)
	var lord := _examiner(20, "Kuni", 0, 6)
	lord.topic_pool = []
	var t := _accusation(5000, 40)
	t.momentum = 1.0
	var results: Array = [{
		"character_id": 30,
		"effects": {
			"requires_taint_corroboration": true,
			"taint_topic_id": 5000,
			"taint_target_id": 40,
		},
	}]
	DayOrchestrator._process_taint_examination_writebacks(
		results, _by_id([e, lord]), [t], 0)
	assert_gt(t.momentum, 1.0, "corroboration refreshes the accusation momentum")
	assert_eq(t.discussion_count_this_day, 1, "discussion bump holds the topic")
	assert_true(5000 in lord.topic_pool, "reach widened to the examiner's lord")
	assert_true(DayOrchestrator._has_corroborated_taint(e, 5000),
		"examiner records a dedup entry so they won't re-corroborate")


func test_writeback_dead_examiner_skipped() -> void:
	var e := _examiner(30, "Kuni", 6, 8, "village_a", 20)
	e.wounds_taken = 9999
	var t := _accusation(5000, 40)
	var before: float = t.momentum
	DayOrchestrator._process_taint_examination_writebacks(
		[{"character_id": 30, "effects": {
			"requires_taint_corroboration": true,
			"taint_topic_id": 5000, "taint_target_id": 40}}],
		_by_id([e]), [t], 0)
	assert_eq(t.momentum, before, "a dead examiner applies no corroboration")
