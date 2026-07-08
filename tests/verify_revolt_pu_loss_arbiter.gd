extends SceneTree
## Runtime driver for the Peasant-Revolt suppression PU-loss arbiter consolidation (s11.11 line 147).
## InsurgencySystem.get_pu_loss_on_suppression(ins) (the canonical PU-loss magnitude, ins.strength*0.1
## for PEASANT_REVOLT else 0.0) had ZERO production callers -- the live coordinated-suppression
## writeback (DayOrchestrator, ~14586) computed the loss as a raw inline `float(ins.strength) * 0.1`
## literal, a divergent copy of the arbiter's own s11.11:147 magnitude. Fix: route the inline site
## through the arbiter so the 0.1 lives in ONE place. Value-identical (drift-safe dedup, no invention).
## Run: godot --headless -s tests/verify_revolt_pu_loss_arbiter.gd

const _IS := preload("res://simulation/insurgency_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _ins(t: Enums.InsurgencyType, strength: int) -> InsurgencyData:
	var i := InsurgencyData.new()
	i.insurgency_type = t
	i.strength = strength
	return i


func _init() -> void:
	print("--- Peasant-Revolt suppression PU-loss routed through the canonical arbiter (s11.11:147) ---")
	_test_arbiter_values()
	_test_type_gate()
	_test_matches_inline_formula()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter_values() -> void:
	print("[1] the arbiter returns strength * 0.1 for a Peasant Revolt")
	_ok(is_equal_approx(_IS.get_pu_loss_on_suppression(_ins(Enums.InsurgencyType.PEASANT_REVOLT, 1)), 0.1),
		"strength 1 -> 0.1")
	_ok(is_equal_approx(_IS.get_pu_loss_on_suppression(_ins(Enums.InsurgencyType.PEASANT_REVOLT, 5)), 0.5),
		"strength 5 -> 0.5")
	_ok(is_equal_approx(_IS.get_pu_loss_on_suppression(_ins(Enums.InsurgencyType.PEASANT_REVOLT, 10)), 1.0),
		"strength 10 -> 1.0")


func _test_type_gate() -> void:
	print("[2] a non-Peasant-Revolt insurgency yields no PU loss")
	_ok(is_equal_approx(_IS.get_pu_loss_on_suppression(_ins(Enums.InsurgencyType.RONIN_BANDIT, 8)), 0.0),
		"Ronin Bandit -> 0.0")
	_ok(is_equal_approx(_IS.get_pu_loss_on_suppression(_ins(Enums.InsurgencyType.NEZUMI_INFESTATION, 8)), 0.0),
		"Nezumi -> 0.0")
	_ok(is_equal_approx(_IS.get_pu_loss_on_suppression(_ins(Enums.InsurgencyType.MAHO_CULT, 8)), 0.0),
		"Maho Cult -> 0.0")


func _test_matches_inline_formula() -> void:
	print("[3] arbiter * effective_actions == the retired inline `strength * 0.1 * effective_actions`")
	# The DayOrchestrator writeback computed the loss as strength*0.1*effective_actions. The consolidated
	# call is get_pu_loss_on_suppression(ins) * effective_actions -- prove they are byte-identical for a
	# Peasant Revolt across every plausible strength and action-count combination.
	var mismatches: int = 0
	for strength in range(1, 13):
		var ins: InsurgencyData = _ins(Enums.InsurgencyType.PEASANT_REVOLT, strength)
		for eff in range(0, 4):
			var inline_val: float = float(strength) * 0.1 * float(eff)
			var arbiter_val: float = _IS.get_pu_loss_on_suppression(ins) * float(eff)
			if not is_equal_approx(inline_val, arbiter_val):
				mismatches += 1
	_ok(mismatches == 0, "0 mismatches across strength 1..12 x effective_actions 0..3 (%d found)" % mismatches)
