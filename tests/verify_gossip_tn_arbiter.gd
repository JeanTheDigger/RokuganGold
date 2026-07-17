extends SceneTree
## Runtime driver for the GOSSIP base-TN arbiter consolidation (s15.4).
## CourtActionSystem.compute_gossip_tn(subject_glory, gossiper_glory) -> clampi(10 + subject*5 - gossiper*5, 5, 60)
## had ZERO production callers -- the live _execute_gossip (action_executor ~1032) inlined the IDENTICAL
## clampi formula, a divergent hand-copy of the arbiter's own s15.4 gossip-TN. Fix: the executor now calls
## the arbiter so the formula lives in ONE place. Value-identical (drift-safe dedup, no invention).
## Run: godot --headless -s tests/verify_gossip_tn_arbiter.gd

const _CAS := preload("res://simulation/court_action_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- GOSSIP base-TN routed through the canonical arbiter (s15.4) ---")
	_test_arbiter_values()
	_test_clamp()
	_test_matches_inline_formula()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter_values() -> void:
	print("[1] compute_gossip_tn = 10 + subject_glory*5 - gossiper_glory*5 (within band)")
	_ok(_CAS.compute_gossip_tn(2.0, 2.0) == 10, "equal glory 2/2 -> 10 (base)")
	_ok(_CAS.compute_gossip_tn(4.0, 2.0) == 20, "subject 4, gossiper 2 -> 10+10 = 20 (harder to gossip about the glorious)")
	_ok(_CAS.compute_gossip_tn(2.0, 4.0) == 5, "subject 2, gossiper 4 -> 10-10 = 0 -> clamps up to 5")
	_ok(_CAS.compute_gossip_tn(3.0, 1.0) == 20, "subject 3, gossiper 1 -> 10+10 = 20")


func _test_clamp() -> void:
	print("[2] the [5, 60] clamp band")
	_ok(_CAS.compute_gossip_tn(0.0, 10.0) == 5, "very low subject / very high gossiper -> floor 5")
	_ok(_CAS.compute_gossip_tn(10.0, 0.0) == 60, "very high subject / very low gossiper -> ceil 60")
	_ok(_CAS.compute_gossip_tn(20.0, 0.0) == 60, "extreme subject glory -> still ceil 60")


func _test_matches_inline_formula() -> void:
	print("[3] arbiter == the retired inline clampi(10 + subj*5 - goss*5, 5, 60) across the glory grid")
	var mismatches: int = 0
	for subj in range(0, 11):
		for goss in range(0, 11):
			var inline_val: int = clampi(10 + int(float(subj)) * 5 - int(float(goss)) * 5, 5, 60)
			var arbiter_val: int = _CAS.compute_gossip_tn(float(subj), float(goss))
			if inline_val != arbiter_val:
				mismatches += 1
	_ok(mismatches == 0, "0 mismatches across subject 0..10 x gossiper 0..10 (%d found)" % mismatches)
