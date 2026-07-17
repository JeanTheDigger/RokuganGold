extends SceneTree
## Runtime driver for consolidating two hand-copied disposition-tier ladders onto the canonical
## DispositionSystem.get_tier arbiter (s12.2, LOCKED). ActionExecutor._get_disposition_tier_name and
## CourtActionSystem.get_debate_disposition_tier each re-implemented the 8-rung tier ladder inline
## (a drift hazard vs the LOCKED boundaries). Both now route through DispositionSystem.get_tier.
## This driver proves behavior-preservation: the rerouted functions match the ORIGINAL inline ladders
## for every disposition value -100..100.
## Run: godot --headless -s tests/verify_disposition_tier_dedup.gd

const _AE := preload("res://simulation/action_executor.gd")
const _CAS := preload("res://simulation/court_action_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# The ORIGINAL inline ladder from ActionExecutor._get_disposition_tier_name (pre-reroute).
func _legacy_tier_name(disp: int) -> String:
	if disp >= 91: return "devoted"
	if disp >= 61: return "trusted_ally"
	if disp >= 31: return "friend"
	if disp >= 11: return "acquaintance"
	if disp >= -10: return "stranger"
	if disp >= -30: return "rival"
	if disp >= -60: return "enemy"
	return "blood_enemy"


# The ORIGINAL inline ladder from CourtActionSystem.get_debate_disposition_tier (pre-reroute).
func _legacy_debate_tier(disp: int) -> int:
	var t: Dictionary = _CAS.DEBATE_DISPOSITION_TIERS
	if disp >= 91: return t["devoted"]
	if disp >= 61: return t["sworn"]
	if disp >= 31: return t["friend"]
	if disp >= 11: return t["acquaintance"]
	if disp >= -10: return t["stranger"]
	if disp >= -30: return t["rival"]
	if disp >= -60: return t["enemy"]
	return t["blood_enemy"]


func _init() -> void:
	print("--- disposition-tier ladders consolidated onto DispositionSystem.get_tier (s12.2) ---")
	_test_tier_name_full_range()
	_test_debate_tier_full_range()
	_test_boundary_spotchecks()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_tier_name_full_range() -> void:
	print("[1] _get_disposition_tier_name matches the legacy ladder for every value -100..100")
	var mismatches: int = 0
	for d: int in range(-100, 101):
		if _AE._get_disposition_tier_name(d) != _legacy_tier_name(d):
			mismatches += 1
	_ok(mismatches == 0, "0 mismatches across 201 values (got %d)" % mismatches)


func _test_debate_tier_full_range() -> void:
	print("[2] get_debate_disposition_tier matches the legacy ladder for every value -100..100")
	var mismatches: int = 0
	for d: int in range(-100, 101):
		if _CAS.get_debate_disposition_tier(d) != _legacy_debate_tier(d):
			mismatches += 1
	_ok(mismatches == 0, "0 mismatches across 201 values (got %d)" % mismatches)


func _test_boundary_spotchecks() -> void:
	print("[3] tier-boundary spot checks route through the canonical get_tier")
	# Each pair is (value, expected tier name) at the exact band edges.
	_ok(_AE._get_disposition_tier_name(-61) == "blood_enemy", "-61 -> blood_enemy")
	_ok(_AE._get_disposition_tier_name(-60) == "enemy", "-60 -> enemy")
	_ok(_AE._get_disposition_tier_name(-31) == "enemy", "-31 -> enemy")
	_ok(_AE._get_disposition_tier_name(-30) == "rival", "-30 -> rival")
	_ok(_AE._get_disposition_tier_name(-11) == "rival", "-11 -> rival")
	_ok(_AE._get_disposition_tier_name(-10) == "stranger", "-10 -> stranger")
	_ok(_AE._get_disposition_tier_name(10) == "stranger", "10 -> stranger")
	_ok(_AE._get_disposition_tier_name(11) == "acquaintance", "11 -> acquaintance")
	_ok(_AE._get_disposition_tier_name(30) == "acquaintance", "30 -> acquaintance")
	_ok(_AE._get_disposition_tier_name(31) == "friend", "31 -> friend")
	_ok(_AE._get_disposition_tier_name(60) == "friend", "60 -> friend")
	_ok(_AE._get_disposition_tier_name(61) == "trusted_ally", "61 -> trusted_ally")
	_ok(_AE._get_disposition_tier_name(90) == "trusted_ally", "90 -> trusted_ally")
	_ok(_AE._get_disposition_tier_name(91) == "devoted", "91 -> devoted")
