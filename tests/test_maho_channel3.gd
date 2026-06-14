extends GutTest
## Maho Channel 3 — Taint detection on a person (s43 / Design Decision 5,
## owner-authorized 2026-06-10). Detection fires when a shugenja's successful
## action targets a Rank-2+ suspect; the detector rolls Perception + Lore:
## Shadowlands vs (8 − Taint Rank) × 5 (Kuni/Asako +2k0).

func _detector(id: int, family: String, lore: int, per: int = 6) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.school_type = Enums.SchoolType.SHUGENJA
	c.family = family
	c.perception = per
	c.skills = {"Lore: Shadowlands": lore}
	return c


func _suspect(id: int, taint: float, clan: String = "Scorpion") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Suspect %d" % id
	c.taint = taint
	c.clan = clan
	return c


func _run(detector_id: int, target_id: int, chars: Array, seed: int = 42) -> Array:
	var by_id: Dictionary = {}
	for c: L5RCharacterData in chars:
		by_id[c.character_id] = c
	var topics: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(seed)
	var results: Array = [{
		"action_id": "PROBE", "success": true,
		"character_id": detector_id, "target_npc_id": target_id,
	}]
	DayOrchestrator._process_taint_proximity_detection(
		results, by_id, {}, dice, topics, [5000], 100)
	return topics


func test_witch_hunter_detects_tainted() -> void:
	# Rank-5 suspect (taint 5.0) → TN 15; a maxed Kuni clears it easily.
	var topics := _run(30, 40, [_detector(30, "Kuni", 6), _suspect(40, 5.0)])
	assert_true(topics.size() >= 1, "Kuni detects a Rank-5 maho user")
	if topics.size() >= 1:
		assert_eq(topics[0].subject_character_id, 40, "names the suspect")
		assert_eq(topics[0].subject_role, "PERPETRATOR")
		assert_eq(topics[0].tier, TopicData.Tier.TIER_3)
		assert_eq(topics[0].category, TopicData.Category.SUPERNATURAL)
		assert_eq(topics[0].slug, "taint_suspected_40")


func test_crab_suspect_exempt() -> void:
	assert_eq(_run(30, 40, [_detector(30, "Kuni", 6), _suspect(40, 5.0, "Crab")]).size(), 0,
		"Crab has an innocent explanation (Kaiu Wall service)")


func test_low_taint_skipped() -> void:
	assert_eq(_run(30, 40, [_detector(30, "Kuni", 6), _suspect(40, 1.5)]).size(), 0,
		"Rank 1 (taint 1.5) is below the accusation threshold")


func test_non_specialist_needs_lore3() -> void:
	assert_eq(_run(30, 40, [_detector(30, "Isawa", 2), _suspect(40, 5.0)]).size(), 0,
		"non-Kuni/Asako shugenja need Lore: Shadowlands >= 3")


func test_specialist_attempts_at_low_lore() -> void:
	# Kuni attempts even at Lore 1 (auto); maxed Perception vs TN 15 succeeds.
	assert_true(_run(30, 40, [_detector(30, "Kuni", 1, 7), _suspect(40, 5.0)]).size() >= 1,
		"Kuni/Asako attempt regardless of Lore rank")


func test_learned_shugenja_detects() -> void:
	assert_true(_run(30, 40, [_detector(30, "Isawa", 6), _suspect(40, 5.0)]).size() >= 1,
		"a Lore: Shadowlands 3+ non-specialist detects")


func test_no_target_no_detection() -> void:
	var by_id := {30: _detector(30, "Kuni", 6)}
	var topics: Array = []
	var dice := DiceEngine.new()
	DayOrchestrator._process_taint_proximity_detection(
		[{"action_id": "MEDITATE", "success": true, "character_id": 30, "target_npc_id": -1}],
		by_id, {}, dice, topics, [5000], 100)
	assert_eq(topics.size(), 0, "an action with no target produces no accusation")


func test_dead_suspect_not_accused() -> void:
	var k := _detector(30, "Kuni", 6)
	var t := _suspect(40, 5.0)
	t.wounds_taken = 9999  # died this day
	assert_eq(_run(30, 40, [k, t]).size(), 0,
		"a suspect who died gets no PERPETRATOR accusation (dead carries NEUTRAL valence)")
