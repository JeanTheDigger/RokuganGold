extends SceneTree
## Runtime driver for s11.7 field rice-deprivation morale/health drain — a produced-but-not-consumed
## bug. DayOrchestrator._process_field_deprivation computed each starving field company's LOCKED
## RICE_DEPRIVATION morale/health deltas (tick2 -3/0, tick3 -3/-5, tick4 -5/-10) into
## military_daily["deprivation_results"], but that array had ZERO readers — so a rice-starved field
## army lost NO morale/health (the symmetric twin of the fixed "army recovery never applied" bug).
## FIX: the pass now applies the rice delta to cd["current_morale"]/["current_health"] (clamped >=0),
## the same fields the recovery pass writes. (The arms attack/defense half stays report-only.)
## Run: godot --headless -s tests/verify_field_deprivation.gd

const _EN := preload("res://shared/enums.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _company(cid: int, morale: int, health: int) -> Dictionary:
	return {
		"company_id": cid,
		"army_id": 1,
		"unit_type": _EN.CompanyUnitType.PEASANT_LEVY,
		"current_morale": morale,
		"current_health": health,
	}


func _run(rice_tick: int, comp: Dictionary, detached: bool = false) -> Array:
	var tethers: Array = [{"army_id": 1, "company_ids": [comp["company_id"]], "detached": detached}]
	var tether_results: Array = [{"rice_deprivation_tick": rice_tick, "arms_deprivation_tick": 0}]
	return DayOrchestrator._process_field_deprivation(tethers, tether_results, [comp])


func _init() -> void:
	print("--- s11.7 field rice-deprivation morale/health drain ---")
	_test_tier_drains()
	_test_clamp_and_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_tier_drains() -> void:
	print("[1] each deprivation tick applies its LOCKED RICE_DEPRIVATION delta per day")
	# tick 2 -> -3 morale, 0 health
	var c2 := _company(10, 20, 50)
	_run(2, c2)
	_ok(c2["current_morale"] == 17 and c2["current_health"] == 50, "tick 2 -> -3 morale, health unchanged")
	# tick 3 -> -3 morale, -5 health
	var c3 := _company(11, 20, 50)
	_run(3, c3)
	_ok(c3["current_morale"] == 17 and c3["current_health"] == 45, "tick 3 -> -3 morale, -5 health")
	# tick 4 -> -5 morale, -10 health
	var c4 := _company(12, 20, 50)
	_run(4, c4)
	_ok(c4["current_morale"] == 15 and c4["current_health"] == 40, "tick 4 -> -5 morale, -10 health")
	# tick 1 -> no change (0/0)
	var c1 := _company(13, 20, 50)
	_run(1, c1)
	_ok(c1["current_morale"] == 20 and c1["current_health"] == 50, "tick 1 -> no drain")


func _test_clamp_and_guards() -> void:
	print("[2] clamp at 0; detached / no-company / report shape")
	# clamp: a near-broken company can't go below 0
	var low := _company(20, 2, 6)
	_run(4, low)  # -5 morale, -10 health
	_ok(low["current_morale"] == 0 and low["current_health"] == 0, "morale/health floored at 0")
	# detached tether -> skipped, no drain
	var det := _company(21, 20, 50)
	_run(3, det, true)
	_ok(det["current_morale"] == 20 and det["current_health"] == 50, "detached tether -> no drain")
	# report is still produced and records the applied amounts
	var c := _company(22, 20, 50)
	var res: Array = _run(4, c)
	var applied_ok := false
	for r_v in res:
		for ce_v in (r_v as Dictionary).get("company_effects", []):
			var ce: Dictionary = ce_v
			if int(ce.get("company_id", -1)) == 22:
				applied_ok = int(ce.get("morale_applied", 0)) == -5 and int(ce.get("health_applied", 0)) == -10
	_ok(applied_ok, "report records morale_applied -5 / health_applied -10")
	# no companies passed (report-only fallback) -> no crash, no drain crash
	var tethers: Array = [{"army_id": 1, "company_ids": [99], "detached": false}]
	var tr: Array = [{"rice_deprivation_tick": 4, "arms_deprivation_tick": 0}]
	var res2: Array = DayOrchestrator._process_field_deprivation(tethers, tr, [])
	_ok(res2.size() == 1, "empty companies -> report still produced, no crash")
