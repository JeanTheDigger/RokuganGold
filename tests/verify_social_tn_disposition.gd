extends SceneTree
## Runtime driver for consolidating the disposition->social-TN modifier onto the canonical
## DispositionSystem.get_raise_modifier arbiter (s12.2). ActionExecutor._get_social_tn re-derived
## the identical per-tier table inline (each TN delta = raise modifier x 5). No divergence today,
## but it was a drift hazard and DispositionSystem.get_raise_modifier had ZERO callers (orphaned
## canonical). Verifies the routed TN matches raise_modifier x 5 across the whole -100..+100 range,
## and spot-checks every tier boundary.
## Run: godot --headless -s tests/verify_social_tn_disposition.gd

const _AE := preload("res://simulation/action_executor.gd")
const _DS := preload("res://simulation/disposition_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# The inline formula that USED to live in _get_social_tn (the reference we must preserve).
func _legacy_delta(d: int) -> int:
	if d <= -61:
		return 10
	elif d <= -31:
		return 5
	elif d >= 91:
		return -15
	elif d >= 61:
		return -10
	elif d >= 31:
		return -5
	return 0


func _social_tn(target_disp: int) -> int:
	var act := NPCDataStructures.ScoredAction.new()
	act.action_id = "CHARM"
	act.target_npc_id = 42
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.dispositions = {42: target_disp}
	return _AE._get_social_tn(act, ctx, null)


func _init() -> void:
	print("--- Social TN disposition modifier == canonical get_raise_modifier x 5 (s12.2) ---")
	_test_full_range()
	_test_boundaries()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_full_range() -> void:
	print("[1] every disposition -100..+100: routed TN == base + raise_modifier x 5 == legacy")
	var base: int = _AE.SOCIAL_BASE_TN
	var mismatches: int = 0
	for d: int in range(-100, 101):
		var got: int = _social_tn(d)
		var via_canonical: int = maxi(base + _DS.get_raise_modifier(d) * 5, 5)
		var via_legacy: int = maxi(base + _legacy_delta(d), 5)
		if got != via_canonical or got != via_legacy:
			mismatches += 1
	_ok(mismatches == 0, "0 mismatches across 201 disposition values (got %d)" % mismatches)


func _test_boundaries() -> void:
	print("[2] tier boundary spot-checks (raise_modifier x 5)")
	# (disposition, expected raise modifier)
	var cases: Array = [
		[-100, 2], [-61, 2],           # BLOOD_ENEMY +2
		[-60, 1], [-31, 1],            # ENEMY +1
		[-30, 0], [-11, 0], [0, 0], [10, 0], [11, 0], [30, 0],  # RIVAL/STRANGER/ACQUAINTANCE 0
		[31, -1], [60, -1],            # FRIEND -1
		[61, -2], [90, -2],            # TRUSTED_ALLY -2
		[91, -3], [100, -3],           # DEVOTED -3
	]
	for c: Array in cases:
		var d: int = c[0]
		var want_mod: int = c[1]
		_ok(_DS.get_raise_modifier(d) == want_mod, "disp %d -> raise modifier %d" % [d, want_mod])
