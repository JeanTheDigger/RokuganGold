extends SceneTree
## Runtime driver for routing blackmail favor extraction through the canonical arbiter
## (FavorSystem.extract_blackmail_favor) instead of the buggy inline copy in
## _process_blackmail_favor_writebacks. GDD s12.10 line 89 (LOCKED): the extracted favor
## tier IS the secret's severity tier -- Tier 1 -> Major, Tier 2 -> Moderate, Tier 3 ->
## Minor, Tier 4 -> vague goodwill (NO tracked favor). The old inline loop hardcoded
## MINOR for every tier and minted Tier-4 favors the spec forbids. Verifies the writeback
## now produces the correct tier per secret tier, the Tier-4 no-favor rule, count == raises,
## and the missing-secret_tier default (3 -> Minor).
## Run: godot --headless -s tests/verify_blackmail_favor_tier.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _intimidate(creditor: int, debtor: int, count: int, secret_tier: Variant) -> Dictionary:
	var effects: Dictionary = {"favors_extracted": count}
	if secret_tier != null:
		effects["secret_tier"] = int(secret_tier)
	return {
		"action_id": "INTIMIDATE",
		"success": true,
		"character_id": creditor,
		"target_npc_id": debtor,
		"effects": effects,
	}


## Runs the writeback for one INTIMIDATE result and returns the favors created.
func _extract(count: int, secret_tier: Variant) -> Array:
	var favors: Array = []
	_DO._process_blackmail_favor_writebacks([_intimidate(1, 2, count, secret_tier)], favors, 40)
	return favors


func _init() -> void:
	print("--- Blackmail Favor Tier via Canonical Arbiter (s12.10 line 89) ---")
	_test_tier_mapping()
	_test_tier4_no_favor()
	_test_count_and_fields()
	_test_default_and_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_tier_mapping() -> void:
	print("[1] favor tier == secret severity tier")
	var t1: Array = _extract(1, 1)
	_ok(t1.size() == 1 and (t1[0] as FavorData).tier == FavorData.FavorTier.MAJOR,
		"Tier 1 secret -> MAJOR favor (was wrongly MINOR)")
	var t2: Array = _extract(1, 2)
	_ok(t2.size() == 1 and (t2[0] as FavorData).tier == FavorData.FavorTier.MODERATE,
		"Tier 2 secret -> MODERATE favor")
	var t3: Array = _extract(1, 3)
	_ok(t3.size() == 1 and (t3[0] as FavorData).tier == FavorData.FavorTier.MINOR,
		"Tier 3 secret -> MINOR favor")


func _test_tier4_no_favor() -> void:
	print("[2] Tier 4 secret -> vague goodwill, NO tracked favor")
	var t4: Array = _extract(3, 4)
	_ok(t4.is_empty(), "Tier 4 secret mints no FavorData (got %d)" % t4.size())


func _test_count_and_fields() -> void:
	print("[3] count == raises; blackmail fields + unique ids")
	var favors: Array = _extract(3, 2)  # 3 raises, Tier 2
	_ok(favors.size() == 3, "3 raises -> 3 favors (got %d)" % favors.size())
	var all_moderate: bool = true
	var all_blackmail: bool = true
	var right_parties: bool = true
	var ids: Dictionary = {}
	for f_v: Variant in favors:
		var f: FavorData = f_v as FavorData
		if f.tier != FavorData.FavorTier.MODERATE:
			all_moderate = false
		if not f.is_blackmail_extracted:
			all_blackmail = false
		if f.creditor_id != 1 or f.debtor_id != 2:
			right_parties = false
		ids[f.favor_id] = true
	_ok(all_moderate, "all 3 favors are MODERATE (the secret tier)")
	_ok(all_blackmail, "all flagged is_blackmail_extracted")
	_ok(right_parties, "creditor/debtor set correctly")
	_ok(ids.size() == 3, "favor ids are unique")


func _test_default_and_guards() -> void:
	print("[4] default secret_tier + no-op guards")
	# Missing secret_tier -> defaults to 3 (Minor), not a crash.
	var deflt: Array = _extract(1, null)
	_ok(deflt.size() == 1 and (deflt[0] as FavorData).tier == FavorData.FavorTier.MINOR,
		"missing secret_tier defaults to Tier 3 -> MINOR")
	# count 0 -> nothing.
	var zero: Array = _extract(0, 1)
	_ok(zero.is_empty(), "count 0 -> no favors")
	# Non-INTIMIDATE / unsuccessful results are ignored.
	var favors: Array = []
	_DO._process_blackmail_favor_writebacks([
		{"action_id": "CHARM", "success": true, "character_id": 1, "target_npc_id": 2,
			"effects": {"favors_extracted": 2, "secret_tier": 1}},
		{"action_id": "INTIMIDATE", "success": false, "character_id": 1, "target_npc_id": 2,
			"effects": {"favors_extracted": 2, "secret_tier": 1}},
	], favors, 40)
	_ok(favors.is_empty(), "non-INTIMIDATE / failed results extract nothing")
