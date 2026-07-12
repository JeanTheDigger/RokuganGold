extends SceneTree
## Runtime driver for the s12.8 bodyguard-assignment producer fix. The whole execution-phase
## bodyguard-encounter combat path (AssassinationSystem.resolve_bodyguard_encounter / the
## day_orchestrator combat retry) reads L5RCharacterData.assigned_protection_target_id to find the
## target's yojimbo -- but NOTHING ever WROTE that field, so _find_bodyguard/_target_has_bodyguard
## always returned null and the entire "household assigns a bodyguard at suspicion >= 20" (s12.8
## line 42) defense was dead. Fix: AssassinationSystem.find_best_protector picks the best loyal
## co-located household warrior, and day_orchestrator's ACCESS phase stamps
## assigned_protection_target_id on them when should_assign_bodyguard(op) AND no guard exists yet.
## This driver exercises find_best_protector's selection/exclusion gates and proves that a stamped
## protector is then found by _find_bodyguard/_target_has_bodyguard (the previously-dead path).
## Run: godot --headless -s tests/verify_bodyguard_assignment.gd

const _AS := preload("res://simulation/assassination_system.gd")
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


func _mk(id: int, loc: String, lord: int, disp_to: int, target_id: int, ken: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.physical_location = loc
	c.lord_id = lord
	if target_id >= 0 and disp_to != 0:
		c.disposition_values[target_id] = disp_to
	c.skills["Kenjutsu"] = ken
	return c


func _init() -> void:
	print("--- s12.8 bodyguard-assignment producer fix ---")
	_test_selection()
	_test_exclusions()
	_test_stamped_guard_is_found()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_selection() -> void:
	print("[1] find_best_protector picks the highest-combat loyal co-located household member")
	var target: L5RCharacterData = _mk(1, "Kyuden", 100, 0, -1, 0)
	# Two loyal same-lord vassals co-located; the higher Kenjutsu wins.
	var weak: L5RCharacterData = _mk(2, "Kyuden", 100, 10, 1, 2)
	var strong: L5RCharacterData = _mk(3, "Kyuden", 100, 5, 1, 5)
	# A loyal DIRECT vassal (lord_id == target) via Iaijutsu also qualifies but is weaker.
	var iai: L5RCharacterData = _mk(4, "Kyuden", 1, 40, 1, 0)
	iai.skills["Iaijutsu"] = 3
	var chars: Dictionary = {1: target, 2: weak, 3: strong, 4: iai}
	var best: L5RCharacterData = _AS.find_best_protector(target, 99, chars)
	_ok(best == strong, "highest-combat (Kenjutsu 5) household member chosen")
	# Remove the strong one -> the Iaijutsu-3 direct vassal (combat 3) beats Kenjutsu-2.
	chars.erase(3)
	best = _AS.find_best_protector(target, 99, chars)
	_ok(best == iai, "with the strongest gone, best-of-max(Ken,Iai) wins (Iaijutsu 3 > Kenjutsu 2)")


func _test_exclusions() -> void:
	print("[2] find_best_protector excludes assassin / target / dead / disloyal / already-guarding / off-site")
	var target: L5RCharacterData = _mk(1, "Kyuden", 100, 0, -1, 0)
	var assassin: L5RCharacterData = _mk(9, "Kyuden", 100, 50, 1, 8)  # loyal-looking but IS the assassin
	var disloyal: L5RCharacterData = _mk(2, "Kyuden", 100, -5, 1, 5)  # disposition < 0
	var offsite: L5RCharacterData = _mk(3, "FarAway", 100, 40, 1, 5)  # not co-located
	var stranger: L5RCharacterData = _mk(4, "Kyuden", 777, 40, 1, 5)  # different lord, not household
	var busy: L5RCharacterData = _mk(5, "Kyuden", 100, 40, 1, 5)      # already guarding someone else
	busy.assigned_protection_target_id = 42
	var dead: L5RCharacterData = _mk(6, "Kyuden", 100, 40, 1, 5)
	dead.wounds_taken = 999  # >> any Earth*16 capacity -> DEAD
	var chars: Dictionary = {
		1: target, 9: assassin, 2: disloyal, 3: offsite, 4: stranger, 5: busy, 6: dead,
	}
	var best: L5RCharacterData = _AS.find_best_protector(target, 9, chars)
	_ok(best == null, "no eligible protector -> null (all candidates excluded by a gate)")
	# Add one genuinely eligible loyal warrior -> now selected over all the excluded ones.
	var good: L5RCharacterData = _mk(7, "Kyuden", 100, 20, 1, 4)
	chars[7] = good
	best = _AS.find_best_protector(target, 9, chars)
	_ok(best == good, "the lone eligible loyal co-located warrior is chosen past every exclusion")


func _test_stamped_guard_is_found() -> void:
	print("[3] a stamped protector is now found by _find_bodyguard / _target_has_bodyguard (dead path revived)")
	var target: L5RCharacterData = _mk(1, "Kyuden", 100, 0, -1, 0)
	var guard: L5RCharacterData = _mk(2, "Kyuden", 100, 30, 1, 6)
	var chars: Dictionary = {1: target, 2: guard}
	# Pre-fix: no producer, so _target_has_bodyguard is always false.
	_ok(not _DO._target_has_bodyguard(target, chars), "before assignment: target has no bodyguard")
	# The producer the fix added: stamp the field the way the ACCESS phase does.
	var protector: L5RCharacterData = _AS.find_best_protector(target, 99, chars)
	_ok(protector == guard, "protector selected")
	protector.assigned_protection_target_id = target.character_id
	# The previously-dead execution-phase readers now resolve the guard.
	_ok(_DO._target_has_bodyguard(target, chars), "after assignment: _target_has_bodyguard true")
	_ok(_DO._find_bodyguard(target, chars) == guard, "_find_bodyguard resolves the stamped guard")
	# A guard who then leaves the settlement is no longer a valid bodyguard (co-location gate).
	guard.physical_location = "Elsewhere"
	_ok(_DO._find_bodyguard(target, chars) == null, "off-site guard no longer resolves (co-location gate)")
