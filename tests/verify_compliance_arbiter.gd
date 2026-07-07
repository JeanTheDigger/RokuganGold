extends SceneTree
## Runtime driver for routing the intimidation compliance-maintenance decision through the
## canonical IntimidationSystem.check_compliance_status arbiter instead of the inline OR-copy
## in _process_intimidation_compliance (the "arbiter bypassed by inline copy" anti-pattern,
## introduced when the compliance tracker was first wired -- check_compliance_status had ZERO
## callers). Behavior-preserving: verifies the arbiter's 3-condition truth table AND that the
## refactored maintenance loop drops/keeps entries identically (fresh survives, dead drops,
## friendship drops, leverage-exposed drops, and a neutral pair with intact leverage survives
## a weak-target/strong-intimidator tick).
## Run: godot --headless -s tests/verify_compliance_arbiter.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _IS := preload("res://simulation/intimidation_system.gd")

var _pass: int = 0
var _fail: int = 0
var _dice := DiceEngine.new()


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, wp: int, intim: int, disp_toward: Dictionary = {}) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "C%d" % cid
	c.willpower = wp
	c.skills = {"Intimidation": intim}
	c.disposition_values = disp_toward
	return c


func _entry(iid: int, tid: int, secret_id: int, established: int) -> Dictionary:
	return {
		"intimidator_id": iid, "target_id": tid,
		"leverage_secret_id": secret_id, "established_ic_day": established,
	}


func _exposed_secret(sid: int) -> SecretData:
	var s := SecretData.new()
	s.secret_id = sid
	s.exposed = true
	return s


func _run(entries: Array, by_id: Dictionary, secrets: Array, ic_day: int) -> Array:
	_DO._process_intimidation_compliance(entries, [], by_id, secrets, ic_day, _dice)
	return entries


func _init() -> void:
	print("--- Intimidation Compliance via check_compliance_status arbiter (s12.9) ---")
	_test_arbiter_truth_table()
	_test_maintenance_branches()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter_truth_table() -> void:
	print("[1] check_compliance_status: continues only when all three end-conditions are false")
	# disp below Friend (0), no leverage removed, no pushback -> continues (true).
	_ok(_IS.check_compliance_status(0, false, false) == true, "neutral, intact, no pushback -> continue")
	# leverage removed -> ends.
	_ok(_IS.check_compliance_status(0, true, false) == false, "leverage removed -> end")
	# pushback succeeded -> ends.
	_ok(_IS.check_compliance_status(0, false, true) == false, "pushback -> end")
	# disposition reaches Friend (>=31) -> ends (can_compliance_end).
	_ok(_IS.check_compliance_status(31, false, false) == false, "friendship -> end")
	_ok(_IS.check_compliance_status(30, false, false) == true, "disp 30 (below Friend) -> continue")


func _test_maintenance_branches() -> void:
	print("[2] maintenance loop drops/keeps identically to the old inline logic")
	# Fresh (established this tick) survives regardless.
	var e_fresh := [_entry(1, 2, -1, 5)]
	_run(e_fresh, {1: _char(1, 3, 4, {2: 0}), 2: _char(2, 3, 0)}, [], 5)
	_ok(e_fresh.size() == 1, "freshly established this tick survives")

	# Dead intimidator -> dropped.
	var dead_intim := _char(1, 3, 4, {2: 0})
	dead_intim.wounds_taken = 999  # ensure dead via CharacterStats
	var e_dead := [_entry(1, 2, -1, 4)]
	_run(e_dead, {1: dead_intim, 2: _char(2, 3, 0)}, [], 5)
	_ok(e_dead.is_empty(), "dead intimidator -> compliance dropped")

	# Friendship: intimidator disp toward target >= 31 -> dropped (no pushback rolled).
	var e_friend := [_entry(1, 2, -1, 4)]
	_run(e_friend, {1: _char(1, 3, 4, {2: 40}), 2: _char(2, 10, 0)}, [], 5)
	_ok(e_friend.is_empty(), "disposition reaches Friend -> dropped")

	# Leverage exposed -> dropped.
	var e_lev := [_entry(1, 2, 77, 4)]
	_run(e_lev, {1: _char(1, 3, 4, {2: 0}), 2: _char(2, 10, 0)}, [_exposed_secret(77)], 5)
	_ok(e_lev.is_empty(), "blackmail secret exposed -> dropped")

	# Neutral, intact leverage (unexposed secret), weak target (WP 1) vs strong intimidator
	# (Intimidation 10 -> pushback TN 25): pushback almost never succeeds -> survives.
	var survived: int = 0
	for i: int in range(40):
		var e := [_entry(1, 2, 88, 4)]
		var unexposed := SecretData.new()
		unexposed.secret_id = 88
		_run(e, {1: _char(1, 3, 10, {2: 0}), 2: _char(2, 1, 0)}, [unexposed], 5)
		if e.size() == 1:
			survived += 1
	_ok(survived >= 38, "weak target vs strong intimidator -> compliance persists (%d/40)" % survived)
