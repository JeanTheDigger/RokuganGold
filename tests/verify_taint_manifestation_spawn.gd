extends SceneTree
## Runtime driver for the TAINT_MANIFESTATION spawn-gate fix (s11.11). InsurgencySystem.get_spawn_chance
## gated the PTL-3 Province Taint Manifestation on `world_state.get("ptl", 0.0)` -- a key NO producer ever
## wrote -- so it always read 0.0, `if ptl < 3.0: return 0.0` always fired, and TAINT_MANIFESTATION could
## NEVER spawn from the seasonal pass (a core Shadowlands escalation was inert). Fix: read the REAL
## province.province_taint_level (the exact value get_eligible_types already gates eligibility on).
## Run: godot --headless -s tests/verify_taint_manifestation_spawn.gd

const _IS := preload("res://simulation/insurgency_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _prov(pid: int, ptl: float) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = "Crab"
	p.family = ""
	p.is_coastal = false
	p.stability = 80.0  # STABLE
	p.province_taint_level = ptl
	return p


func _init() -> void:
	print("--- TAINT_MANIFESTATION spawn gate reads real province PTL (s11.11) ---")
	_test_consumer()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_consumer() -> void:
	print("[1] get_spawn_chance gates on province.province_taint_level, not the dead ws key")
	var T := Enums.InsurgencyType.TAINT_MANIFESTATION
	var S := Enums.StabilityTier.STABLE
	# PTL 4.0, empty ws -> 1.0 (was 0.0 before the fix; this is the whole bug)
	_ok(is_equal_approx(_IS.get_spawn_chance(T, S, _prov(1, 4.0), {}), 1.0),
		"PTL 4.0 + empty ws -> 1.0 (automatic spawn)")
	# PTL 2.9 -> below threshold -> 0.0
	_ok(is_equal_approx(_IS.get_spawn_chance(T, S, _prov(2, 2.9), {}), 0.0),
		"PTL 2.9 -> 0.0 (below the 3.0 threshold)")
	# PTL exactly 3.0 -> 1.0
	_ok(is_equal_approx(_IS.get_spawn_chance(T, S, _prov(3, 3.0), {}), 1.0),
		"PTL 3.0 -> 1.0 (threshold inclusive)")
	# The dead ws["ptl"] key is now ignored: province PTL 0 but ws says 9.0 -> still 0.0
	_ok(is_equal_approx(_IS.get_spawn_chance(T, S, _prov(4, 0.0), {"ptl": 9.0}), 0.0),
		"stale ws['ptl']=9.0 ignored (reads the province, not the dead key)")


func _test_end_to_end() -> void:
	print("[2] process_season actually spawns a TAINT_MANIFESTATION at PTL >= 3 (chance 1.0, deterministic)")
	# High-PTL province -> TAINT eligible (ptl>=3) + chance 1.0 -> ALWAYS spawns, regardless of dice.
	var pid: int = 500
	var prov := _prov(pid, 4.0)
	var provinces: Dictionary = {pid: prov}
	var ptls: Dictionary = {pid: 4.0}
	var insurgencies: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var res: Dictionary = _IS.process_season(insurgencies, provinces, ptls, dice, 0, 1, {}, {})
	var spawned_taint: bool = false
	for ins: InsurgencyData in res.get("new_insurgencies", []):
		if ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION and ins.province_id == pid:
			spawned_taint = true
	_ok(spawned_taint, "TAINT_MANIFESTATION spawned at PTL 4.0")

	# Control: PTL 1.0 -> TAINT not eligible -> never spawns.
	var pid2: int = 501
	var prov2 := _prov(pid2, 1.0)
	var provinces2: Dictionary = {pid2: prov2}
	var ptls2: Dictionary = {pid2: 1.0}
	var insurgencies2: Array = []
	var no_taint: bool = true
	for seed: int in range(0, 30):
		insurgencies2.clear()
		var d2 := DiceEngine.new()
		d2.set_seed(seed)
		var r2: Dictionary = _IS.process_season(insurgencies2, provinces2, ptls2, d2, 0, 1, {}, {})
		for ins: InsurgencyData in r2.get("new_insurgencies", []):
			if ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION:
				no_taint = false
	_ok(no_taint, "PTL 1.0 -> TAINT never spawns (not eligible)")
