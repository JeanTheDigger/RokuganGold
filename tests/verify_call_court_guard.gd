extends SceneTree
## Runtime driver for the last_court_season anti-duplicate-court guard fix (s55.10).
## StrategicReview._evaluate_call_court reads `last_court_season` off the TOP-LEVEL world_state, but
## DayOrchestrator._track_court_called writes it ONLY on the lord's per-character sub-dict
## (world_states[lord_id]["last_court_season"]). So the top-level read was always -1, the
## `last_court_season == current_season` guard never fired, and a lord re-proposed CALL_COURT every
## season. Fix: _run_strategic_reviews injects the reviewed lord's own value at top level per-lord.
## This driver exercises the consumer guard + the injection expression.
## Run: godot --headless -s tests/verify_call_court_guard.gd

const _SR := preload("res://simulation/strategic_review.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _lord() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 7
	c.bushido_virtue = Enums.BushidoVirtue.GI  # not REI -> no +15 court bonus
	return c


# Replicates the exact per-lord injection expression added in _run_strategic_reviews.
func _inject(world_states: Dictionary, lord_id: int) -> int:
	return int((world_states.get(lord_id, {}) as Dictionary).get("last_court_season", -1))


func _init() -> void:
	print("--- last_court_season anti-duplicate-court guard revived (s55.10) ---")
	_test()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test() -> void:
	var lord := _lord()
	var vassals: Array = [1, 2, 3, 4, 5, 6]  # 6 vassals -> court_score 30 (>= the 30 threshold)
	var spring: int = TimeSystem.Season.SPRING

	print("[1] guard fires when the lord already held a court this season")
	# last_court_season == current_season -> {} (no redundant CALL_COURT proposed).
	var r_guard := _SR._evaluate_call_court(lord, vassals, {
		"last_court_season": spring, "current_season": spring,
	})
	_ok(r_guard.is_empty(), "last_court_season == current_season -> {} (guard fires)")

	print("[2] the OLD dead state (top-level -1) would have re-proposed CALL_COURT")
	# -1 (the permanent pre-fix top-level default) != current_season -> guard open -> scores + fires.
	var r_dead := _SR._evaluate_call_court(lord, vassals, {
		"last_court_season": -1, "current_season": spring,
	})
	_ok(not r_dead.is_empty()
		and int(r_dead.get("directive", -1)) == _SR.Directive.CALL_COURT,
		"last_court_season -1 -> CALL_COURT (the dormant-guard behaviour the fix suppresses)")

	print("[3] guard open on a DIFFERENT season still proposes (correct)")
	var r_diff := _SR._evaluate_call_court(lord, vassals, {
		"last_court_season": TimeSystem.Season.WINTER, "current_season": spring,
	})
	_ok(not r_diff.is_empty(), "held court last WINTER, now SPRING -> proposes (guard correctly open)")

	print("[4] the injection expression maps the lord's per-character value to top level")
	# The producer (_track_court_called) writes on the per-character sub-dict; the injection reads it.
	var ws: Dictionary = {7: {"last_court_season": spring}}
	_ok(_inject(ws, 7) == spring, "per-char last_court_season -> injected top-level value")
	_ok(_inject(ws, 99) == -1, "lord with no sub-dict -> -1 (never held a court)")
	_ok(_inject({}, 7) == -1, "empty world_states -> -1 (safe default)")

	print("[5] end-to-end: injected top-level value makes the guard fire")
	# Simulate the fixed flow: inject the lord's per-char value at top level, then evaluate.
	var ws2: Dictionary = {7: {"last_court_season": spring}, "current_season": spring}
	ws2["last_court_season"] = _inject(ws2, 7)
	_ok(_SR._evaluate_call_court(lord, vassals, ws2).is_empty(),
		"inject(per-char spring) -> guard fires -> no redundant CALL_COURT")
