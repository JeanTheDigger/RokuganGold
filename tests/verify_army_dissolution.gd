extends SceneTree
## Runtime driver for wiring the GDD s11.7 rout-dissolution outcome (line 365) into
## the army lifecycle. ArmyCombatSystem.resolve_rout already computes the post-pursuit
## <=20%-of-starting-Health dissolution and reconciles Health -> PU, but the field-
## battle path never applied that dissolved decision to the losing army entity, so a
## dissolved army lingered as a phantom (kept moving / re-triggering battles / healing).
## Verifies: (1) _apply_battle_army_dissolution flips the correct losing side inactive
## on rout.dissolved (attacker-victor -> defenders; defender-victor -> attacker; no-op
## on survivable rout or draw) and halts it; and (2) the movement + recovery passes now
## skip is_active == false armies (the guards that make the flip effective, and that
## also fix the latent disband-still-moves case).
## Run: godot --headless -s tests/verify_army_dissolution.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _army(aid: int, clan: String = "Lion") -> Dictionary:
	return {
		"army_id": aid,
		"clan_name": clan,
		"owning_clan": clan,
		"is_active": true,
		"is_moving": false,
		"province_id": 1,
	}


func _br(victor: String, dissolved: bool) -> Dictionary:
	return {"victor": victor, "rout": {"dissolved": dissolved}}


func _init() -> void:
	print("--- Army Rout-Dissolution Lifecycle Wiring (s11.7 line 365) ---")
	_test_dissolution_applier()
	_test_movement_guard()
	_test_recovery_guard()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_dissolution_applier() -> void:
	print("[1] _apply_battle_army_dissolution flips the losing side inactive")

	# Attacker wins, defenders dissolve -> both defender armies inactive, attacker active.
	var atk := _army(1)
	var def_a := _army(2)
	var def_b := _army(3)
	var armies: Array = [atk, def_a, def_b]
	_DO._apply_battle_army_dissolution(_br("attacker", true), "attacker", 1, [2, 3], armies)
	_ok(atk["is_active"] == true, "attacker (victor) stays active")
	_ok(def_a["is_active"] == false and def_b["is_active"] == false, "both defenders dissolved")
	_ok(def_a["is_moving"] == false and int(def_a["days_remaining"]) == 0 and (def_a["path"] as Array).is_empty(),
		"dissolved army halted (is_moving false, days 0, path cleared)")
	_ok(not def_a.has("retreat_ordered") and not def_a.has("disband_ordered"),
		"dissolved army retreat/disband flags cleared")

	# Defender wins, attacker dissolves -> attacker inactive, defender active.
	var atk2 := _army(10)
	var def2 := _army(11)
	_DO._apply_battle_army_dissolution(_br("defender", true), "defender", 10, [11], [atk2, def2])
	_ok(atk2["is_active"] == false, "attacker (loser) dissolved when defender wins")
	_ok(def2["is_active"] == true, "defender (victor) stays active")

	# Survivable rout (>20%, dissolved == false) -> NO dissolution (retreat deferred).
	var atk3 := _army(20)
	var def3 := _army(21)
	_DO._apply_battle_army_dissolution(_br("attacker", false), "attacker", 20, [21], [atk3, def3])
	_ok(def3["is_active"] == true, "survivable rout does not dissolve the loser")

	# Draw -> no-op even if dissolved somehow set.
	var atk4 := _army(30)
	var def4 := _army(31)
	_DO._apply_battle_army_dissolution(_br("draw", true), "draw", 30, [31], [atk4, def4])
	_ok(atk4["is_active"] == true and def4["is_active"] == true, "draw -> no dissolution")


func _test_movement_guard() -> void:
	print("[2] _process_army_movements skips is_active == false armies")
	# Active mover (days_remaining 1) advances/arrives; inactive mover is skipped.
	var mover := _army(40)
	mover["is_moving"] = true
	mover["days_remaining"] = 1
	mover["destination_sub_tile"] = 7
	mover["current_sub_tile"] = 3
	var phantom := _army(41)
	phantom["is_active"] = false
	phantom["is_moving"] = true
	phantom["days_remaining"] = 1
	phantom["destination_sub_tile"] = 9
	phantom["current_sub_tile"] = 5
	var results: Array = _DO._process_army_movements([mover, phantom])
	# The active mover produced a movement result; the phantom did not.
	var mover_moved: bool = false
	var phantom_moved: bool = false
	for r: Dictionary in results:
		if int(r.get("army_id", -1)) == 40:
			mover_moved = true
		if int(r.get("army_id", -1)) == 41:
			phantom_moved = true
	_ok(mover_moved, "active mover processed by the movement pass")
	_ok(not phantom_moved, "inactive (phantom) army skipped by the movement pass")
	# The phantom's days_remaining is untouched (never decremented); the mover's arrived.
	_ok(int(phantom["days_remaining"]) == 1 and phantom["is_moving"] == true,
		"phantom army state frozen (not advanced)")
	_ok(int(mover["current_sub_tile"]) == 7 and mover["is_moving"] == false,
		"active mover advanced to its destination")


func _test_recovery_guard() -> void:
	print("[3] _process_army_recovery skips is_active == false armies")
	var healthy := _army(50)  # active, stationary -> eligible for recovery
	var phantom := _army(51)
	phantom["is_active"] = false  # dissolved -> must not recover
	# Low current_health so a rice-supplied (SOLID tether default) active army recovers.
	var companies: Array = [
		{"army_id": 50, "company_id": 500, "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "current_health": 10, "starting_health": 153, "max_health": 153, "source_province_id": 1},
		{"army_id": 51, "company_id": 510, "unit_type": Enums.CompanyUnitType.PEASANT_LEVY, "current_health": 10, "starting_health": 153, "max_health": 153, "source_province_id": 1},
	]
	var results: Array = _DO._process_army_recovery([healthy, phantom], {}, companies, {})
	var healthy_recovered: bool = false
	var phantom_recovered: bool = false
	for r: Dictionary in results:
		if int(r.get("army_id", -1)) == 50:
			healthy_recovered = true
		if int(r.get("army_id", -1)) == 51:
			phantom_recovered = true
	_ok(healthy_recovered, "active army produces a recovery result")
	_ok(not phantom_recovered, "dissolved army produces NO recovery result")
