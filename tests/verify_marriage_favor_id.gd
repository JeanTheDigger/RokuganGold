extends SceneTree
## Runtime driver for routing the marriage-obligation favor through the canonical
## FavorSystem.offer_favor factory (s12.10 / s22.7). The inline FavorData.new() in _apply_marriage
## set NO favor_id, so every cross-clan marriage-obligation favor defaulted to favor_id -1 -- they
## were indistinguishable and could never be reliably invoked/honored/broken (all favor lookups
## match by favor_id). Verifies each marriage favor now gets a UNIQUE id, with the field values
## (GENERAL / MODERATE / creditor=target lord / debtor=proposing lord / terms / source_action)
## preserved; and that BETWEEN_FAMILIES marriages owe no favor.
## Run: godot --headless -s tests/verify_marriage_favor_id.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _M := preload("res://simulation/marriage_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, clan: String, family: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "C%d" % cid
	c.clan = clan
	c.family = family
	c.spouse_id = -1
	return c


func _marry(effects: Dictionary, by_id: Dictionary, favors: Array) -> void:
	_DO._apply_marriage(effects, by_id, [], 40, {}, {}, favors, [], [5000], {}, {})


func _cross(a: int, b: int, proposing_lord: int, target_lord: int) -> Dictionary:
	return {
		"candidate_a_id": a, "candidate_b_id": b,
		"marriage_type": _M.MarriageType.CROSS_CLAN,
		"proposing_lord_id": proposing_lord, "target_lord_id": target_lord,
	}


func _init() -> void:
	print("--- Marriage-obligation favor gets a unique favor_id (s12.10 / s22.7) ---")
	_test_unique_ids()
	_test_fields_and_no_favor_case()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_unique_ids() -> void:
	print("[1] two cross-clan marriages -> two favors with UNIQUE ids (not both -1)")
	var by_id: Dictionary = {
		1: _char(1, "Crane", "Doji"), 2: _char(2, "Lion", "Akodo"),
		3: _char(3, "Crab", "Hida"), 4: _char(4, "Scorpion", "Bayushi"),
	}
	var favors: Array = []
	_marry(_cross(1, 2, 10, 20), by_id, favors)
	_marry(_cross(3, 4, 30, 40), by_id, favors)
	_ok(favors.size() == 2, "two marriage favors created (got %d)" % favors.size())
	if favors.size() == 2:
		var f0: FavorData = favors[0] as FavorData
		var f1: FavorData = favors[1] as FavorData
		_ok(f0.favor_id != -1 and f1.favor_id != -1, "neither favor_id is the -1 default (was the bug)")
		_ok(f0.favor_id != f1.favor_id, "the two favor ids are UNIQUE (%d vs %d)" % [f0.favor_id, f1.favor_id])
		_ok(f0.favor_id == 0 and f1.favor_id == 1, "ids assigned sequentially (0, 1)")


func _test_fields_and_no_favor_case() -> void:
	print("[2] field values preserved; BETWEEN_FAMILIES owes no favor")
	var by_id: Dictionary = {1: _char(1, "Crane", "Doji"), 2: _char(2, "Lion", "Akodo")}
	var favors: Array = []
	_marry(_cross(1, 2, 10, 20), by_id, favors)
	_ok(favors.size() == 1, "cross-clan marriage owes one favor")
	if favors.size() == 1:
		var f: FavorData = favors[0] as FavorData
		_ok(f.favor_type == FavorData.FavorType.GENERAL, "favor_type GENERAL preserved")
		_ok(f.tier == FavorData.FavorTier.MODERATE, "tier MODERATE preserved")
		_ok(f.creditor_id == 20 and f.debtor_id == 10, "creditor=target lord / debtor=proposing lord")
		_ok(f.terms == "marriage_obligation", "terms preserved")
		_ok(f.source_action == "ARRANGE_MARRIAGE", "source_action preserved")

	# BETWEEN_FAMILIES (same clan, different family) owes NO favor.
	var by_id2: Dictionary = {5: _char(5, "Crane", "Doji"), 6: _char(6, "Crane", "Kakita")}
	var favors2: Array = []
	_DO._apply_marriage({
		"candidate_a_id": 5, "candidate_b_id": 6,
		"marriage_type": _M.MarriageType.BETWEEN_FAMILIES,
		"proposing_lord_id": 10, "target_lord_id": 20,
	}, by_id2, [], 40, {}, {}, favors2, [], [5000], {}, {})
	_ok(favors2.is_empty(), "between-families marriage owes no favor")
