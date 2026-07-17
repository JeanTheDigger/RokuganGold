extends SceneTree
## Runtime driver for the double-applied assassination-order honor bug (s12.8).
## The ordering honor cost (rank-scaled by target Status) was applied TWICE to the commissioner
## per new commission: once at commission time in ActionExecutor (Pattern B, via the SecretSystem
## copy) AND again in DayOrchestrator._process_assassination_commissions (via the AssassinationSystem
## domain arbiter). Two value-identical twin arbiters, both firing. The writeback re-application is
## removed (Pattern B keeps the single commission-time charge); the executor is consolidated onto the
## domain arbiter AssassinationSystem.get_ordering_honor_loss (identical value to the old copy).
## Run: godot --headless -s tests/verify_assassination_order_honor.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, honor: float) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.honor = honor
	c.status = 4.0
	return c


func _commission_result(commissioner_id: int, honor_cost: float) -> Dictionary:
	return {
		"action_id": "COMMISSION_ASSASSINATION",
		"success": true,
		"effects": {
			"assassin_id": 200,
			"target_id": 300,
			"method": 0,
			"commissioner_id": commissioner_id,
			"subject_honor_loss": honor_cost,  # Pattern B: already applied by the executor.
		},
	}


func _init() -> void:
	print("--- assassination-order honor: applied once (s12.8) ---")
	_test_consolidation_behavior_preserving()
	_test_writeback_does_not_recharge()
	_test_writeback_still_registers_op()
	_test_dedup_still_holds()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_consolidation_behavior_preserving() -> void:
	print("[1] domain arbiter == the old SecretSystem copy (rank-scaled) across all Status tiers")
	var c := _char(1, 5.0)  # honor rank 5 -> a fixed rank-scale multiplier for both arbiters
	for s: float in [1.0, 2.0, 2.9, 3.0, 5.9, 6.0, 7.9, 8.0, 10.0]:
		var a: float = AssassinationSystem.get_ordering_honor_loss(s, c)
		var b: float = CrimeSystem.scale_honor_by_rank(SecretSystem.get_assassination_order_honor_cost(s), c)
		_ok(is_equal_approx(a, b), "status %.1f: domain %.3f == old-copy %.3f" % [s, a, b])


func _test_writeback_does_not_recharge() -> void:
	print("[2] _process_assassination_commissions does NOT re-apply the ordering honor (bug fix)")
	var commissioner := _char(10, 5.0)
	var ops: Array = []
	# The executor already charged the ordering honor (Pattern B); the stash is metadata only.
	var results: Array = [_commission_result(10, -3.0)]
	_DO._process_assassination_commissions(results, ops, 10, {10: commissioner})
	_ok(is_equal_approx(commissioner.honor, 5.0),
		"commissioner honor UNCHANGED by the writeback (%.3f, expected 5.0 -- no second charge)" % commissioner.honor)


func _test_writeback_still_registers_op() -> void:
	print("[3] the writeback still registers the assassination op")
	var commissioner := _char(11, 6.0)
	var ops: Array = []
	_DO._process_assassination_commissions([_commission_result(11, -3.0)], ops, 12, {11: commissioner})
	_ok(ops.size() == 1, "one assassination op registered (got %d)" % ops.size())
	_ok(int(ops[0].get("commissioner_id", -99)) == 11, "op carries the commissioner_id")


func _test_dedup_still_holds() -> void:
	print("[4] a duplicate commission (same assassin+target) still doesn't register a second op")
	var commissioner := _char(12, 6.0)
	var existing: Array = [{"assassin_id": 200, "target_id": 300}]
	_DO._process_assassination_commissions([_commission_result(12, -3.0)], existing, 12, {12: commissioner})
	_ok(existing.size() == 1, "no duplicate op registered (got %d)" % existing.size())
	_ok(is_equal_approx(commissioner.honor, 6.0), "and still no honor re-charge on the dedup path")
