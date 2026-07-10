extends SceneTree
## Runtime driver for s22.5 succession transition-duration clean wire.
## SuccessionSystem.get_transition_duration (clean+confirming-disp>=31 -> 7 / clean -> 14 /
## disputed -> 60) had ZERO callers -- the tick loop at day_orchestrator._process_successions
## inlined a divergent copy that yielded only 14 (PENDING) or 60 (else), so the 7-tick fast path
## ("clean succession + confirming authority Friend+ disposition resolves fastest", s22.5) was
## permanently UNREACHABLE. FIX: SuccessionData gains transition_max_ticks (stamped at creation via
## the canonical arbiter, where is_clean + confirming_disp are in scope); the tick loop reads it
## (-1 -> falls back to the prior inline behavior for old saves).
## Run: godot --headless -s tests/verify_succession_duration.gd

const _SS := preload("res://simulation/succession_system.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")
const _SUD := preload("res://shared/succession_data.gd")
const _CH := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	return c


func _succ(sid: int, max_ticks: int, cand_ids: Array) -> SuccessionData:
	var s: SuccessionData = _SUD.new()
	s.succession_id = sid
	s.state = SuccessionData.SuccessionState.PENDING
	s.transition_max_ticks = max_ticks
	s.confirming_authority_id = -1   # -> expiry uses candidates[0]["id"]
	s.candidate_ids = cand_ids
	return s


func _init() -> void:
	print("--- s22.5 succession transition-duration wire ---")
	_test_arbiter()
	_test_tick_loop()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter() -> void:
	print("[1] get_transition_duration: clean+high-disp -> 7 / clean -> 14 / disputed -> 60")
	_ok(_SS.get_transition_duration(true, 31) == _SS.CLEAN_SUCCESSION_MIN_TICKS, "clean + disp 31 -> 7")
	_ok(_SS.get_transition_duration(true, 60) == _SS.CLEAN_SUCCESSION_MIN_TICKS, "clean + disp 60 -> 7")
	_ok(_SS.get_transition_duration(true, 30) == _SS.CLEAN_SUCCESSION_MAX_TICKS, "clean + disp 30 -> 14 (boundary)")
	_ok(_SS.get_transition_duration(true, 0) == _SS.CLEAN_SUCCESSION_MAX_TICKS, "clean + disp 0 -> 14")
	_ok(_SS.get_transition_duration(false, 60) == _SS.DISPUTED_MAX_TICKS, "disputed (disp irrelevant) -> 60")
	_ok(_SS.get_transition_duration(false, 0) == _SS.DISPUTED_MAX_TICKS, "disputed + disp 0 -> 60")
	# The three constants are distinct so the fast path is genuinely a different outcome.
	_ok(_SS.CLEAN_SUCCESSION_MIN_TICKS == 7 and _SS.CLEAN_SUCCESSION_MAX_TICKS == 14
		and _SS.DISPUTED_MAX_TICKS == 60, "constants 7 / 14 / 60 (LOCKED)")


func _test_tick_loop() -> void:
	print("[2] _process_successions honors transition_max_ticks (7-tick fast path reachable)")
	var heir := _char(10)
	var chars := {10: heir}

	# A: a stamped fast-path succession (7) expires+confirms at exactly tick 7.
	var fast := _succ(1, 7, [10])
	var expired_at := -1
	for tick in range(1, 15):
		var res: Array = _DO._process_successions([fast], chars)
		if fast.state == SuccessionData.SuccessionState.CONFIRMED:
			expired_at = tick
			break
	_ok(expired_at == 7, "fast-path (max_ticks=7) confirms at tick 7, got %d" % expired_at)
	_ok(fast.successor_id == 10, "fast-path successor is the sole living candidate")

	# B: control -- the pre-fix inline behavior (transition_max_ticks=-1 -> PENDING falls back to 14).
	var legacy := _succ(2, -1, [10])
	var legacy_expired_at := -1
	for tick in range(1, 20):
		_DO._process_successions([legacy], chars)
		if legacy.state == SuccessionData.SuccessionState.CONFIRMED:
			legacy_expired_at = tick
			break
	_ok(legacy_expired_at == 14, "legacy fallback (-1, PENDING) confirms at tick 14, got %d" % legacy_expired_at)

	# C: the fix makes a DIFFERENCE -- the fast path resolves strictly sooner than the fallback.
	_ok(expired_at < legacy_expired_at, "fast path (7) resolves before the fallback (14)")

	# D: a CONFIRMED succession is skipped (no further ticking).
	var done := _succ(3, 7, [10])
	done.state = SuccessionData.SuccessionState.CONFIRMED
	done.ticks_elapsed = 3
	_DO._process_successions([done], chars)
	_ok(done.ticks_elapsed == 3, "CONFIRMED succession is not ticked")
