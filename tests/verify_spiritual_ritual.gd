extends SceneTree
## Headless runtime driver for the s56.16.5b–5f Restoration Ritual (SpiritualRitualSystem).
## Upgrades the system from static-only to runtime-verified. Exercises the
## GDD-locked math: durations, counter rings, per-round resolution (damage/wrong-
## ring/realm), summary stacking + interruption, the outcome spectrum, and
## apply_resolution's event mutation. Run: godot --headless -s tests/verify_spiritual_ritual.gd

const _SR := preload("res://simulation/spiritual_ritual_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _ev(sev: int, etype: int, realm: int = Enums.SpiritRealm.GAKI_DO, elem: int = Enums.Ring.NONE) -> SpiritualInsurgencyData:
	var e := SpiritualInsurgencyData.new()
	e.severity = sev
	e.event_type = etype
	e.realm = realm
	e.element = elem
	return e


func _shugenja() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Isawa"
	# Strong across the board so realm/element ritual rolls beat TN 15 reliably.
	c.awareness = 5
	c.willpower = 5
	c.perception = 5
	c.intelligence = 5
	c.agility = 5
	c.reflexes = 5
	c.stamina = 5
	c.strength = 5
	c.void_ring = 4
	c.skills = {"Lore: Theology": 5}
	return c


func _init() -> void:
	print("--- Spiritual Ritual Verification (s56.16.5b–5f) ---")
	_test_durations()
	_test_counter_ring()
	_test_round_resolution()
	_test_summary()
	_test_outcome_spectrum()
	_test_apply_resolution()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_durations() -> void:
	print("[1] durations (s56.16.5b: 10/20/30/50)")
	_ok(_SR.duration_for(_ev(Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.REALM_OVERLAP)) == 10, "MILD 10")
	_ok(_SR.duration_for(_ev(Enums.SpiritualSeverity.MODERATE, Enums.SpiritualEventType.REALM_OVERLAP)) == 20, "MODERATE 20")
	_ok(_SR.duration_for(_ev(Enums.SpiritualSeverity.SEVERE, Enums.SpiritualEventType.REALM_OVERLAP)) == 30, "SEVERE 30")
	_ok(_SR.duration_for(_ev(Enums.SpiritualSeverity.CATASTROPHIC, Enums.SpiritualEventType.REALM_OVERLAP)) == 50, "CATASTROPHIC 50")
	var e := _ev(Enums.SpiritualSeverity.MODERATE, Enums.SpiritualEventType.REALM_OVERLAP)
	e.ritual_rounds_completed = 8
	_ok(_SR.rounds_remaining(e) == 12, "remaining = duration - banked")
	e.ritual_rounds_completed = 25
	_ok(_SR.rounds_remaining(e) == 0, "remaining floors at 0")


func _test_counter_ring() -> void:
	print("[2] counter rings (s56.16.5d)")
	_ok(_SR.counter_ring(Enums.Ring.FIRE) == Enums.Ring.WATER, "Fire→Water")
	_ok(_SR.counter_ring(Enums.Ring.WATER) == Enums.Ring.EARTH, "Water→Earth")
	_ok(_SR.counter_ring(Enums.Ring.EARTH) == Enums.Ring.FIRE, "Earth→Fire")
	_ok(_SR.counter_ring(Enums.Ring.AIR) == Enums.Ring.EARTH, "Air→Earth")
	_ok(_SR.counter_ring(Enums.Ring.VOID, Enums.Ring.WATER) == Enums.Ring.WATER, "Void→chosen")
	_ok(_SR.counter_ring(Enums.Ring.VOID) == Enums.Ring.NONE, "Void undeclared→NONE")


func _test_round_resolution() -> void:
	print("[3] per-round resolution")
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var sh := _shugenja()
	# took_damage → interruption, no progress (s56.16.5b)
	var realm_ev := _ev(Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.GAKI_DO)
	var hit := _SR.resolve_ritual_round(sh, realm_ev, dice, true)
	_ok(not hit["success"] and int(hit["progress"]) == 0, "took_damage → no progress")
	# Elemental imbalance with undeclared Void counter → no progress (s56.16.5d)
	var void_ev := _ev(Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.ELEMENTAL_IMBALANCE, Enums.SpiritRealm.GAKI_DO, Enums.Ring.VOID)
	var noring := _SR.resolve_ritual_round(sh, void_ev, dice, false, Enums.Ring.NONE)
	_ok(not noring["success"] and int(noring["progress"]) == 0, "wrong/undeclared counter → no progress")
	# Strong shugenja, realm path, undamaged: mostly succeeds → progress over many rounds.
	var wins := 0
	for i in range(200):
		var rr := _SR.resolve_ritual_round(sh, realm_ev, dice, false)
		wins += int(rr["progress"])
	_ok(wins > 150, "strong shugenja makes progress most rounds (%d/200)" % wins)


func _test_summary() -> void:
	print("[4] summary ritual (stacking + interruption)")
	var dice := DiceEngine.new()
	dice.set_seed(7)
	var ev := _ev(Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.GAKI_DO)
	# One strong shugenja, plenty of rounds → reaches the needed 10 and stops.
	var prog := _SR.run_summary_ritual([_shugenja()], ev, dice, 40)
	_ok(prog >= 10, "single shugenja reaches full duration (%d)" % prog)
	_ok(prog <= 10, "stops once needed met (no over-count: %d)" % prog)
	# Two shugenja stack toward the same total → reach it in fewer rounds.
	var ev2 := _ev(Enums.SpiritualSeverity.MODERATE, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.GAKI_DO)
	var solo := _SR.run_summary_ritual([_shugenja()], ev2, dice, 12)
	var duo := _SR.run_summary_ritual([_shugenja(), _shugenja()], ev2, dice, 12)
	_ok(duo >= solo, "two shugenja stack (duo %d >= solo %d in 12 rounds)" % [duo, solo])
	# A dead shugenja contributes nothing.
	var deadsh := _shugenja()
	deadsh.wounds_taken = 9999
	var ev3 := _ev(Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.REALM_OVERLAP, Enums.SpiritRealm.GAKI_DO)
	_ok(_SR.run_summary_ritual([deadsh], ev3, dice, 20) == 0, "dead shugenja contributes 0")


func _test_outcome_spectrum() -> void:
	print("[5] outcome spectrum (s56.16.5f)")
	_ok(_SR.classify_outcome(5, 10, false) == _SR.Outcome.FAILURE, "no shugenja → FAILURE")
	_ok(_SR.classify_outcome(10, 10, true) == _SR.Outcome.FULL_SUCCESS, "full → FULL_SUCCESS")
	_ok(_SR.classify_outcome(6, 10, true) == _SR.Outcome.PARTIAL, "more than half → PARTIAL")
	_ok(_SR.classify_outcome(5, 10, true) == _SR.Outcome.RETREAT, "exactly half → RETREAT (not partial)")
	_ok(_SR.classify_outcome(0, 10, true) == _SR.Outcome.RETREAT, "no progress → RETREAT")


func _test_apply_resolution() -> void:
	print("[6] apply_resolution mutation")
	# FULL: banks total, resolved, type.
	var ef := _ev(Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.REALM_OVERLAP)
	var rf := _SR.apply_resolution(ef, 10, true, null, 3)
	_ok(rf["outcome"] == _SR.Outcome.FULL_SUCCESS and ef.resolved and ef.ritual_rounds_completed == 10 and ef.resolution_type == "full_success", "FULL banks + resolves")
	# PARTIAL: banks cumulative, not resolved.
	var ep := _ev(Enums.SpiritualSeverity.MODERATE, Enums.SpiritualEventType.REALM_OVERLAP)
	ep.ritual_rounds_completed = 4
	var rp := _SR.apply_resolution(ep, 9, true, null, 3)  # cumulative 13 of 20 = partial
	_ok(rp["outcome"] == _SR.Outcome.PARTIAL and not ep.resolved and ep.ritual_rounds_completed == 13, "PARTIAL banks cumulative")
	# RETREAT: banks nothing, one-season spike.
	var er := _ev(Enums.SpiritualSeverity.MODERATE, Enums.SpiritualEventType.REALM_OVERLAP)
	var rr := _SR.apply_resolution(er, 2, true, null, 5)  # 2 of 20 = retreat
	_ok(rr["outcome"] == _SR.Outcome.RETREAT and er.ritual_rounds_completed == 0 and er.intensity_spike_until_season == 6, "RETREAT no bank + spike")
	# FAILURE: shugenja lost, spike.
	var ex := _ev(Enums.SpiritualSeverity.SEVERE, Enums.SpiritualEventType.REALM_OVERLAP)
	var rx := _SR.apply_resolution(ex, 20, false, null, 5)
	_ok(rx["outcome"] == _SR.Outcome.FAILURE and ex.resolution_type == "failure" and ex.intensity_spike_until_season == 6, "FAILURE spike")
	# Affliction check: only Catastrophic.
	var dice := DiceEngine.new(); dice.set_seed(1)
	_ok(not _SR.post_resolution_affliction_check(_shugenja(), _ev(Enums.SpiritualSeverity.SEVERE, Enums.SpiritualEventType.REALM_OVERLAP), dice), "non-catastrophic → no affliction check")
