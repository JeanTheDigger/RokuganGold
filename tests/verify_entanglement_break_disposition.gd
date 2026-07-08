extends SceneTree
## Runtime driver for the neglect-break disposition loss fix (s12.8 line 273, LOCKED).
## When three consecutive maintenance windows pass, an entanglement breaks and "the target's
## disposition drops -10 (feeling used and abandoned)". DayOrchestrator._process_entanglements
## detected the BROKEN transition but only cleared the flag -- it NEVER applied the -10. Fix: the
## BROKEN branch now applies NEGLECT_BREAK_DISPOSITION_LOSS (-10) to the target's disposition toward
## the seducer via a new helper (characters_by_id threaded in). This is the NATURAL-decay break, a
## distinct locked value from the formal breakup arbiter's -5/-15 (which has no ActionID -> deferred).
## Run: godot --headless -s tests/verify_entanglement_break_disposition.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _SD := preload("res://simulation/seduction_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, disp_toward: Dictionary = {}) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.disposition_values = disp_toward.duplicate()
	return c


func _ent(seducer: int, target: int, last_maintained: int) -> Dictionary:
	var e: Dictionary = _SD.create_entanglement(seducer, target, 0)
	e["last_maintained_ic_day"] = last_maintained
	e["missed_windows"] = 0
	return e


func _init() -> void:
	print("--- Neglect-break disposition loss wired into _process_entanglements (s12.8:273) ---")
	_test_const()
	_test_break_applies_loss()
	_test_neglected_no_loss()
	_test_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_const() -> void:
	print("[1] the locked neglect-break value")
	_ok(_SD.NEGLECT_BREAK_DISPOSITION_LOSS == -10, "NEGLECT_BREAK_DISPOSITION_LOSS == -10 (GDD s12.8:273)")


func _test_break_applies_loss() -> void:
	print("[2] a 3-window neglect break drops the target's disposition toward the seducer -10")
	# seducer 1, target 2 (target starts +20 toward the seducer). 3 windows missed (ic_day 48).
	var seducer := _char(1)
	var target := _char(2, {1: 20})
	var chars: Dictionary = {1: seducer, 2: target}
	var ents: Array = [_ent(1, 2, 0)]
	var results: Array = _DO._process_entanglements(ents, 3 * _SD.MAINTENANCE_WINDOW_IC_DAYS, chars)
	_ok(ents.is_empty(), "broken entanglement removed from the array")
	_ok(target.disposition_values.get(1, 999) == 10, "target 2 -> seducer 1 dropped 20 -> 10 (-10 applied)")
	# The result reports the applied loss.
	var reported: bool = false
	for r: Dictionary in results:
		if r.get("event", "") == "broken" and int(r.get("disposition_loss", 0)) == -10:
			reported = true
	_ok(reported, "the 'broken' result carries disposition_loss -10")

	# An entanglement that is ALREADY broken is just removed -- no second -10 charge.
	var target2 := _char(2, {1: 10})
	var chars2: Dictionary = {1: _char(1), 2: target2}
	var pre_broken: Dictionary = _ent(1, 2, 0)
	pre_broken["state"] = _SD.EntanglementState.BROKEN
	var ents2: Array = [pre_broken]
	_DO._process_entanglements(ents2, 3 * _SD.MAINTENANCE_WINDOW_IC_DAYS, chars2)
	_ok(ents2.is_empty(), "already-broken entanglement removed")
	_ok(target2.disposition_values.get(1, 999) == 10, "already-broken: no second -10 charge (stays 10)")


func _test_neglected_no_loss() -> void:
	print("[3] a NEGLECTED (not-yet-broken) entanglement applies no break loss")
	# 1 window missed (ic_day 16) -> NEGLECTED, not BROKEN. The -2/window decay is deferred, so
	# disposition must be UNCHANGED here (proving the -10 break fires only on the actual break).
	var target := _char(2, {1: 20})
	var chars: Dictionary = {1: _char(1), 2: target}
	var ents: Array = [_ent(1, 2, 0)]
	var results: Array = _DO._process_entanglements(ents, _SD.MAINTENANCE_WINDOW_IC_DAYS, chars)
	_ok(not ents.is_empty(), "neglected entanglement NOT removed (still active)")
	_ok(target.disposition_values.get(1, 999) == 20, "neglected: disposition unchanged (no premature -10)")
	var is_neglected: bool = false
	for r: Dictionary in results:
		if r.get("event", "") == "neglected":
			is_neglected = true
	_ok(is_neglected, "a 'neglected' event is emitted")


func _test_guards() -> void:
	print("[4] guards: dead target / empty characters_by_id -> no crash, no application")
	# Dead target -> no application.
	var dead_target := _char(2, {1: 20})
	dead_target.wounds_taken = 9999  # dead
	var chars: Dictionary = {1: _char(1), 2: dead_target}
	var ents: Array = [_ent(1, 2, 0)]
	_DO._process_entanglements(ents, 3 * _SD.MAINTENANCE_WINDOW_IC_DAYS, chars)
	_ok(ents.is_empty() and dead_target.disposition_values.get(1, 999) == 20,
		"dead target -> break still removes the entanglement, no disposition change")

	# Empty characters_by_id -> no crash, break still removes the entanglement.
	var ents2: Array = [_ent(1, 2, 0)]
	var results: Array = _DO._process_entanglements(ents2, 3 * _SD.MAINTENANCE_WINDOW_IC_DAYS, {})
	_ok(ents2.is_empty(), "empty characters_by_id -> break still processed, no crash")
	var zero_loss: bool = false
	for r: Dictionary in results:
		if r.get("event", "") == "broken" and int(r.get("disposition_loss", -1)) == 0:
			zero_loss = true
	_ok(zero_loss, "empty characters_by_id -> disposition_loss reported as 0")
