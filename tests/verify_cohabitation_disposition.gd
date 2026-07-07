extends SceneTree
## Runtime driver for wiring the cohabitation disposition bonus (s12.2 line 397, LOCKED:
## +0.1 disposition per IC day spent in the same settlement). day_orchestrator's
## _apply_cohabitation already accumulates the per-pair IC-day counter every tick, but
## nothing read it -- get_effective_disposition used only stored disposition + family bond.
## Verifies the read-time bonus is now folded in: 120 IC days -> +12 (the GDD Winter Court
## example), negligible over a few days, stacks with stored disposition, is bounded by the
## -100..+100 clamp, and is NOT applied on the degraded (no chars_by_id) plain-lookup path.
## Run: godot --headless -s tests/verify_cohabitation_disposition.gd

const _D := preload("res://simulation/disposition_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, stored_toward: Dictionary = {}, cohab: Dictionary = {}) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "C%d" % cid
	# Empty birth_clan -> no birth-family floor interference; no family relation -> bond 0.
	c.birth_clan = ""
	c.disposition_values = stored_toward
	c.cohabitation_days = cohab
	return c


func _init() -> void:
	print("--- Cohabitation Disposition Bonus (s12.2 line 397) ---")
	_test_pure_rate()
	_test_effective_read()
	_test_degraded_path_and_clamp()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_pure_rate() -> void:
	print("[1] compute_cohabitation_bonus rate")
	_ok(abs(_D.compute_cohabitation_bonus(120) - 12.0) < 0.001, "120 IC days -> +12.0 (Winter Court)")
	_ok(abs(_D.compute_cohabitation_bonus(1) - 0.1) < 0.001, "1 IC day -> +0.1 (smallest increment)")
	_ok(_D.compute_cohabitation_bonus(0) == 0.0, "0 days -> 0")


func _test_effective_read() -> void:
	print("[2] get_effective_disposition folds in the cohabitation bonus")
	var actor := _char(1, {2: 0}, {2: 120})  # 0 stored, 120 co-days toward #2
	var target := _char(2)
	var by_id: Dictionary = {1: actor, 2: target}
	_ok(_D.get_effective_disposition(actor, 2, by_id) == 12, "120 co-days -> effective +12")

	# Stacks with stored disposition.
	var actor2 := _char(3, {4: 20}, {4: 100})
	var t2 := _char(4)
	_ok(_D.get_effective_disposition(actor2, 4, {3: actor2, 4: t2}) == 30,
		"stored 20 + 100 co-days (+10) -> 30")

	# Negligible over a few days (int truncation of a sub-1 bonus).
	var actor3 := _char(5, {6: 0}, {6: 3})
	var t3 := _char(6)
	_ok(_D.get_effective_disposition(actor3, 6, {5: actor3, 6: t3}) == 0,
		"3 co-days -> +0 (negligible over a few days)")

	# No cohabitation record -> no bonus.
	var actor4 := _char(7, {8: 15}, {})
	var t4 := _char(8)
	_ok(_D.get_effective_disposition(actor4, 8, {7: actor4, 8: t4}) == 15,
		"no cohabitation record -> stored unchanged")


func _test_degraded_path_and_clamp() -> void:
	print("[3] degraded (plain-lookup) path excludes cohabitation; clamp bounds it")
	# Degraded path (chars_by_id empty) is a plain stored lookup -- no cohabitation.
	var actor := _char(1, {2: 5}, {2: 120})
	_ok(_D.get_effective_disposition(actor, 2, {}) == 5,
		"degraded path (no chars_by_id) -> stored only, no cohabitation")

	# The -100..+100 clamp bounds a very long co-residence.
	var actor2 := _char(3, {4: 0}, {4: 2000})  # 2000 * 0.1 = +200 -> clamped
	var t2 := _char(4)
	_ok(_D.get_effective_disposition(actor2, 4, {3: actor2, 4: t2}) == 100,
		"2000 co-days (+200) clamped to +100")
