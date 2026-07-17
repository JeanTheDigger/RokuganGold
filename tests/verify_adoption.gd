extends SceneTree
## Runtime driver for the s22.5:33 ADOPTION wire. adopted_children_ids fed succession's whole
## ADOPTED_HEIR candidate path but was NEVER written -- no character ever had an adopted heir, so a
## heirless lord's line broke (the P6 "confirming lord selects" outcome) with no adoption fallback.
## Fix: the seasonal _evaluate_heir_designations pass (the dedicated succession channel, NOT a
## duplicate daily-AP ActionID) now, when a Family Daimyo+ has no bloodline heir and none settled,
## adopts the best same-clan junior into the family + generates the Adoption topic. Owner-approved
## trigger/target heuristic (2026-07-09).
## Run: godot --headless -s tests/verify_adoption.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, clan: String, fam: String, status: float, age: int, spouse: int = -1) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = clan
	c.family = fam
	c.status = status
	c.age = age
	c.spouse_id = spouse
	return c


func _init() -> void:
	print("--- s22.5:33 adoption wire ---")
	_test_should_adopt()
	_test_pick_candidate()
	_test_topic()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_should_adopt() -> void:
	print("[1] _should_adopt_heir gates: Family Daimyo+, no bio same-clan child, no heir, not already adopted")
	var lord: L5RCharacterData = _mk(1, "Crane", "Doji", 6.0, 45)  # Family Daimyo (status >= 6)
	var by_id: Dictionary = {1: lord}
	_ok(_DO._should_adopt_heir(lord, by_id), "heirless Family Daimyo -> adopts")
	# Below Family Daimyo (Provincial, status 5.x) -> no.
	var prov: L5RCharacterData = _mk(2, "Crane", "Doji", 5.5, 45)
	_ok(not _DO._should_adopt_heir(prov, {2: prov}), "Provincial Daimyo (below Family Daimyo) does not adopt")
	# Has a settled heir -> no.
	var withheir: L5RCharacterData = _mk(3, "Crane", "Doji", 6.0, 45)
	withheir.designated_heir_id = 99
	_ok(not _DO._should_adopt_heir(withheir, {3: withheir}), "already has a designated heir -> no adopt")
	# Already adopted -> no.
	var adopted: L5RCharacterData = _mk(4, "Crane", "Doji", 6.0, 45)
	adopted.adopted_children_ids = [50]
	_ok(not _DO._should_adopt_heir(adopted, {4: adopted}), "already adopted once -> no re-adopt")
	# Living same-clan bio child -> no (bloodline heir exists).
	var parent: L5RCharacterData = _mk(5, "Crane", "Doji", 6.0, 45)
	var child: L5RCharacterData = _mk(6, "Crane", "Doji", 2.0, 20)
	parent.children_ids = [6]
	_ok(not _DO._should_adopt_heir(parent, {5: parent, 6: child}), "living same-clan bio child blocks adoption")
	# A DEAD bio child does not block (line is broken).
	var deadchild: L5RCharacterData = _mk(7, "Crane", "Doji", 2.0, 20)
	deadchild.wounds_taken = 999
	var p2: L5RCharacterData = _mk(8, "Crane", "Doji", 6.0, 45)
	p2.children_ids = [7]
	_ok(_DO._should_adopt_heir(p2, {8: p2, 7: deadchild}), "a dead bio child does not block adoption")


func _test_pick_candidate() -> void:
	print("[2] _pick_adoption_candidate: highest-status unmarried same-clan/family adult junior, unclaimed")
	var lord: L5RCharacterData = _mk(1, "Crane", "Doji", 6.0, 45)
	var strong: L5RCharacterData = _mk(10, "Crane", "Doji", 3.0, 25)      # best eligible
	var weak: L5RCharacterData = _mk(11, "Crane", "Doji", 2.0, 30)        # lower status
	var married: L5RCharacterData = _mk(12, "Crane", "Doji", 4.0, 25, 77) # excluded: married
	var kid: L5RCharacterData = _mk(13, "Crane", "Doji", 3.5, 12)         # excluded: age < 18
	var other_fam: L5RCharacterData = _mk(14, "Crane", "Kakita", 4.0, 25) # excluded: family
	var other_clan: L5RCharacterData = _mk(15, "Lion", "Akodo", 4.0, 25)  # excluded: clan
	var senior: L5RCharacterData = _mk(16, "Crane", "Doji", 6.0, 25)      # excluded: status >= lord
	var claimed: L5RCharacterData = _mk(17, "Crane", "Doji", 5.0, 25)     # excluded: already claimed
	var chars: Array = [lord, strong, weak, married, kid, other_fam, other_clan, senior, claimed]
	var claimed_ids: Dictionary = {17: true}
	var pick: L5RCharacterData = _DO._pick_adoption_candidate(lord, chars, claimed_ids)
	_ok(pick == strong, "picks the highest-status eligible junior (status 3.0), excluding married/child/family/clan/senior/claimed")
	# Unclaim the status-5.0 one -> it now wins (higher status, still a junior).
	pick = _DO._pick_adoption_candidate(lord, chars, {})
	_ok(pick == claimed, "with nobody claimed, the highest-status junior (5.0) wins")
	# No eligible candidate -> null.
	_ok(_DO._pick_adoption_candidate(lord, [lord, married, kid, other_clan], {}) == null,
		"no eligible junior -> null")


func _test_topic() -> void:
	print("[3] _create_adoption_topic: correct fields + appended to active_topics + both topic_pools")
	var lord: L5RCharacterData = _mk(1, "Crane", "Doji", 6.0, 45)
	var heir: L5RCharacterData = _mk(10, "Crane", "Doji", 3.0, 25)
	var topics: Array = []
	var next_id: Array = [5000]
	_DO._create_adoption_topic(lord, heir, topics, next_id, 200, {1: lord, 10: heir})
	_ok(topics.size() == 1, "one topic created")
	var t: TopicData = topics[0]
	_ok(t.topic_type == "adoption" and t.variant == "clear_succession", "topic_type=adoption / variant=clear_succession")
	_ok(t.tier == TopicData.Tier.TIER_4 and t.category == TopicData.Category.POLITICAL, "TIER_4 POLITICAL")
	_ok(t.subject_character_id == 10 and t.subject_role == "NEUTRAL", "subject = adoptee, NEUTRAL role")
	_ok(t.clan_involved == "Crane" and t.family_involved == "Doji", "clan/family involved set")
	_ok(next_id[0] == 5001, "next_topic_id advanced")
	_ok(t.topic_id in lord.topic_pool and t.topic_id in heir.topic_pool, "both lord and adoptee know the topic")


func _test_end_to_end() -> void:
	print("[4] end-to-end _evaluate_heir_designations: heirless Family Daimyo adopts; a lord with a bio child does not")
	var lord: L5RCharacterData = _mk(1, "Crane", "Doji", 6.0, 45)
	lord.shourido_virtue = Enums.ShouridoVirtue.SEIGYO  # should_reevaluate_heir -> true
	var heir: L5RCharacterData = _mk(10, "Crane", "Doji", 3.0, 25)
	# Control: another Family Daimyo who HAS a living same-clan bio child -> must not adopt.
	var lord2: L5RCharacterData = _mk(2, "Crane", "Doji", 6.0, 45)
	lord2.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var bio: L5RCharacterData = _mk(20, "Crane", "Doji", 2.0, 22)
	lord2.children_ids = [20]
	var chars: Array = [lord, heir, lord2, bio]
	var by_id: Dictionary = {1: lord, 10: heir, 2: lord2, 20: bio}
	var topics: Array = []
	_DO._evaluate_heir_designations(chars, by_id, topics, [7000], 300)
	_ok(lord.adopted_children_ids == [10], "heirless lord adopted the junior (adopted_children_ids)")
	_ok(lord.designated_heir_id == 10, "adopted heir is designated as heir")
	var found_adopt := false
	for t: TopicData in topics:
		if t.topic_type == "adoption" and t.subject_character_id == 10:
			found_adopt = true
	_ok(found_adopt, "an adoption topic was generated for the adoptee")
	_ok(lord2.adopted_children_ids.is_empty(), "the lord WITH a bio child did not adopt")