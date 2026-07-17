extends SceneTree
## Runtime driver for the s55.22b Otomo Seiyaku alliance-suppression EFFECT wire.
## Before this, the directive lifecycle ran but NO disposition suppression was applied anywhere:
## estimate_seasonal_effect (the sole reader of effectiveness_halved) had zero production callers,
## so the whole "Otomo suppress two clans' alliance" mechanic was decorative. This driver exercises:
## (1) the extended arbiter (committed-flat -6/season base, escalated MAX -12, detection halves);
## (2) DayOrchestrator._apply_seiyaku_suppression end-to-end — each active directive lowers BOTH
## targeted Champions' disposition toward each other (the pair the system scans), escalated at max
## intensity, detected halved, clamped to the +31 formal-alliance floor, skipping missing champions.
## All values LOCKED (s55.22b §3.1/§3.2/§6.1/§6.2). Run: godot --headless -s tests/verify_seiyaku_suppression.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _OS := preload("res://simulation/otomo_seiyaku_system.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _champ(id: int, clan: String) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = clan
	c.status = 7.5  # Great Clan Champion tier
	c.lord_id = -1
	c.wounds_taken = 0
	c.disposition_values = {}
	return c


func _state_with_directive(clan_a: String, clan_b: String, escalated: bool, halved: bool, formal: bool) -> Dictionary:
	var state: Dictionary = _OS.make_initial_state()
	var pk: String = _OS.make_pair_key(clan_a, clan_b)
	var d: Dictionary = _OS.create_directive(pk, 999, clan_a, clan_b)
	d["escalated"] = escalated
	d["effectiveness_halved"] = halved
	state["active_directives"][pk] = d
	if formal:
		_OS.declare_formal_alliance(state, pk)
	return state


func _init() -> void:
	print("--- s55.22b Otomo Seiyaku alliance-suppression effect ---")
	_test_arbiter()
	_test_base_suppression()
	_test_escalated_and_detected()
	_test_formal_floor()
	_test_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter() -> void:
	print("[1] estimate_seasonal_effect (committed channel set, LOCKED constants)")
	var base_d: Dictionary = {"effectiveness_halved": false}
	# Committed-flat: court + 1 visit + letters -> MIN sum -3 + -2 + -1 = -6.
	_ok(_OS.estimate_seasonal_effect(base_d, true, 1, true, false) == -6, "base -6")
	# Escalated -> MAX sum -8 + -5 + -2 = -15 clamped to -12.
	_ok(_OS.estimate_seasonal_effect(base_d, true, 1, true, true) == -12, "escalated -12 (clamped)")
	var halved_d: Dictionary = {"effectiveness_halved": true}
	_ok(_OS.estimate_seasonal_effect(halved_d, true, 1, true, false) == -3, "detected halves base -> -3")
	# Escalated raw sum -15 halved (before the -12 clamp, truncating toward zero) -> -7.
	_ok(_OS.estimate_seasonal_effect(halved_d, true, 1, true, true) == -7, "detected halves escalated raw -15 -> -7")


func _test_base_suppression() -> void:
	print("[2] base directive lowers BOTH champions' disposition by 6")
	var a: L5RCharacterData = _champ(10, "Crab")
	var b: L5RCharacterData = _champ(20, "Crane")
	a.disposition_values = {20: 50}
	b.disposition_values = {10: 48}
	var state: Dictionary = _state_with_directive("Crab", "Crane", false, false, false)
	_DO._apply_seiyaku_suppression(state, [a, b])
	_ok(int(a.disposition_values.get(20, 0)) == 44, "Crab->Crane 50 -> 44 (was %d)" % int(a.disposition_values.get(20, 0)))
	_ok(int(b.disposition_values.get(10, 0)) == 42, "Crane->Crab 48 -> 42 (was %d)" % int(b.disposition_values.get(10, 0)))


func _test_escalated_and_detected() -> void:
	print("[3] escalated -> -12, detected -> halved")
	var a: L5RCharacterData = _champ(10, "Lion")
	var b: L5RCharacterData = _champ(20, "Phoenix")
	a.disposition_values = {20: 50}
	b.disposition_values = {10: 50}
	var esc: Dictionary = _state_with_directive("Lion", "Phoenix", true, false, false)
	_DO._apply_seiyaku_suppression(esc, [a, b])
	_ok(int(a.disposition_values.get(20, 0)) == 38, "escalated Lion->Phoenix 50 -> 38")
	# Fresh pair, detected (halved base -> -3).
	var c: L5RCharacterData = _champ(30, "Dragon")
	var d: L5RCharacterData = _champ(40, "Unicorn")
	c.disposition_values = {40: 50}
	d.disposition_values = {30: 50}
	var det: Dictionary = _state_with_directive("Dragon", "Unicorn", false, true, false)
	_DO._apply_seiyaku_suppression(det, [c, d])
	_ok(int(c.disposition_values.get(40, 0)) == 47, "detected Dragon->Unicorn 50 -> 47 (halved -3)")


func _test_formal_floor() -> void:
	print("[4] formal-alliance +31 floor holds against suppression")
	var a: L5RCharacterData = _champ(10, "Crab")
	var b: L5RCharacterData = _champ(20, "Crane")
	a.disposition_values = {20: 35}
	b.disposition_values = {10: 35}
	# Escalated (-12) would drop 35 -> 23, but the +31 formal floor clamps to 31.
	var state: Dictionary = _state_with_directive("Crab", "Crane", true, false, true)
	_DO._apply_seiyaku_suppression(state, [a, b])
	_ok(int(a.disposition_values.get(20, 0)) == 31, "Crab->Crane clamped to +31 floor (was %d)" % int(a.disposition_values.get(20, 0)))
	_ok(int(b.disposition_values.get(10, 0)) == 31, "Crane->Crab clamped to +31 floor")


func _test_guards() -> void:
	print("[5] guards: no directive -> no change; missing champion -> skip")
	var a: L5RCharacterData = _champ(10, "Crab")
	var b: L5RCharacterData = _champ(20, "Crane")
	a.disposition_values = {20: 50}
	b.disposition_values = {10: 50}
	var empty: Dictionary = _OS.make_initial_state()
	_DO._apply_seiyaku_suppression(empty, [a, b])
	_ok(int(a.disposition_values.get(20, 0)) == 50, "no directive -> unchanged")
	# Directive present but Crane champion absent from the roster -> skip (no crash, no change).
	var state: Dictionary = _state_with_directive("Crab", "Crane", false, false, false)
	_DO._apply_seiyaku_suppression(state, [a])
	_ok(int(a.disposition_values.get(20, 0)) == 50, "missing champion -> skipped, unchanged")
