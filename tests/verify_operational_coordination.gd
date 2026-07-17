extends SceneTree
## Runtime driver for s57.54.10d operational-superior subordinate coordination.
## An operational superior (a Taisa/Shireikan holding operational_superior_id authority) receives a
## Civilian Order budget (2/day for 1-3 subordinates, 3/day for 4+, LOCKED) and spends 1 CO per IDLE
## subordinate they direct; the subordinate inherits a copy of the superior's OWN active primary
## objective (owner-approved 2026-07-17: propagate the operational directive down the chain). This
## driver exercises: (1) StrategicReview.co_budget_for_subordinate_count (0/1-3/4+ tiers); (2)
## DayOrchestrator._reset_all_ap's s57.54.10d max-rule (a non-lord op-superior gets the op budget, a
## lord gets max(lord, op), a non-superior gets 0); and (3) _process_operational_coordination (idle
## subs inherit the superior's need_type + targets, CO decremented per sub; active subs untouched;
## idle superior / no-primary / exhausted budget / dead+PC guards; targets propagated).
## Run: godot --headless -s tests/verify_operational_coordination.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _SR := preload("res://simulation/strategic_review.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, status: float = 3.5, superior_id: int = -1, dead: bool = false, pc: bool = false) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.status = status
	c.operational_superior_id = superior_id
	c.wounds_taken = 9999 if dead else 0
	c.is_pc = pc
	c.lord_id = 500  # has a feudal lord (so not lord-by-lord_id==-1)
	return c


func _init() -> void:
	print("--- s57.54.10d operational-superior subordinate coordination ---")
	_test_co_budget_helper()
	_test_reset_ap_max_rule()
	_test_coordination_directs_idle_subs()
	_test_active_sub_untouched()
	_test_idle_superior_no_coordination()
	_test_budget_exhaustion()
	_test_guards()
	_test_targets_propagated()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_co_budget_helper() -> void:
	print("[1] co_budget_for_subordinate_count tiers (LOCKED)")
	_ok(_SR.co_budget_for_subordinate_count(0) == 0, "0 subs -> 0")
	_ok(_SR.co_budget_for_subordinate_count(1) == 2, "1 sub -> 2")
	_ok(_SR.co_budget_for_subordinate_count(3) == 2, "3 subs -> 2")
	_ok(_SR.co_budget_for_subordinate_count(4) == 3, "4 subs -> 3")
	_ok(_SR.co_budget_for_subordinate_count(12) == 3, "12 subs -> 3")


func _test_reset_ap_max_rule() -> void:
	print("[2] _reset_all_ap s57.54.10d max-rule")
	# Non-lord Taisa (status 3.5, rank budget 0) with 2 subordinates -> op budget 2.
	var taisa: L5RCharacterData = _mk(200, 3.5)
	var sub_a: L5RCharacterData = _mk(300, 2.0, 200)
	var sub_b: L5RCharacterData = _mk(301, 2.0, 200)
	# Lord (status 6.0 -> FAMILY_DAIMYO rank budget 10) with 5 subordinates -> max(10, 3) = 10.
	var lord: L5RCharacterData = _mk(400, 6.0)
	var lsubs: Array = []
	for i in range(5):
		lsubs.append(_mk(410 + i, 2.0, 400))
	# Plain non-superior non-lord -> 0.
	var plain: L5RCharacterData = _mk(600, 3.0)
	var chars: Array = [taisa, sub_a, sub_b, lord, plain] + lsubs
	_DO._reset_all_ap(chars)
	_ok(taisa.civilian_order_budget_max == 2, "non-lord Taisa (2 subs) budget_max == 2 (got %d)" % taisa.civilian_order_budget_max)
	_ok(taisa.civilian_orders_remaining == 2, "Taisa civilian_orders_remaining == 2")
	_ok(lord.civilian_order_budget_max == 10, "lord (5 subs) budget_max == max(10,3) == 10 (got %d)" % lord.civilian_order_budget_max)
	_ok(plain.civilian_order_budget_max == 0, "non-superior non-lord budget_max == 0 (got %d)" % plain.civilian_order_budget_max)
	_ok(sub_a.civilian_order_budget_max == 0, "subordinate (no subs, non-lord) budget_max == 0")


func _test_coordination_directs_idle_subs() -> void:
	print("[3] Taisa directs 2 idle Chui; each inherits the superior's objective; CO spent per sub")
	var taisa: L5RCharacterData = _mk(200, 3.5)
	taisa.civilian_orders_remaining = 2
	var sub_a: L5RCharacterData = _mk(300, 2.0, 200)
	var sub_b: L5RCharacterData = _mk(301, 2.0, 200)
	var chars: Array = [taisa, sub_a, sub_b]
	var by_id: Dictionary = {200: taisa, 300: sub_a, 301: sub_b}
	# Superior holds an active primary (a military need with a province target).
	var objs: Dictionary = {
		200: {"primary": {"need_type": "DEFEND_PROVINCE", "status": "ACTIVE", "target_province_id": 42}},
	}
	_DO._process_operational_coordination(chars, objs, by_id, 0)
	var pa: Dictionary = objs.get(300, {}).get("primary", {})
	var pb: Dictionary = objs.get(301, {}).get("primary", {})
	_ok(pa.get("need_type", "") == "DEFEND_PROVINCE", "sub A inherits need_type DEFEND_PROVINCE")
	_ok(pa.get("assigned_by", -1) == 200, "sub A assigned_by == superior 200")
	_ok(pa.get("source", "") == "operational_coordination", "sub A source == operational_coordination")
	_ok(int(pa.get("target_province_id", -1)) == 42, "sub A inherits target_province_id 42")
	_ok(pb.get("need_type", "") == "DEFEND_PROVINCE", "sub B inherits need_type")
	_ok(taisa.civilian_orders_remaining == 0, "2 CO spent -> 0 remaining (got %d)" % taisa.civilian_orders_remaining)


func _test_active_sub_untouched() -> void:
	print("[4] a subordinate with an ACTIVE primary is NOT clobbered")
	var taisa: L5RCharacterData = _mk(200, 3.5)
	taisa.civilian_orders_remaining = 2
	var busy: L5RCharacterData = _mk(300, 2.0, 200)
	var chars: Array = [taisa, busy]
	var by_id: Dictionary = {200: taisa, 300: busy}
	var objs: Dictionary = {
		200: {"primary": {"need_type": "DEFEND_PROVINCE", "status": "ACTIVE"}},
		300: {"primary": {"need_type": "PATROL_PROVINCE", "status": "ACTIVE", "assigned_by": 500}},
	}
	_DO._process_operational_coordination(chars, objs, by_id, 0)
	var p: Dictionary = objs.get(300, {}).get("primary", {})
	_ok(p.get("need_type", "") == "PATROL_PROVINCE", "busy sub keeps its own PATROL_PROVINCE primary")
	_ok(p.get("assigned_by", -1) == 500, "busy sub keeps assigned_by 500 (own lord)")
	_ok(taisa.civilian_orders_remaining == 2, "no CO spent on a non-idle sub")


func _test_idle_superior_no_coordination() -> void:
	print("[5] an idle superior (no primary) coordinates nothing")
	var taisa: L5RCharacterData = _mk(200, 3.5)
	taisa.civilian_orders_remaining = 2
	var sub: L5RCharacterData = _mk(300, 2.0, 200)
	var chars: Array = [taisa, sub]
	var by_id: Dictionary = {200: taisa, 300: sub}
	var objs: Dictionary = {}  # superior has no primary
	_DO._process_operational_coordination(chars, objs, by_id, 0)
	_ok(objs.get(300, {}).get("primary", {}).is_empty(), "idle superior -> sub stays undirected")
	_ok(taisa.civilian_orders_remaining == 2, "idle superior spends no CO")
	# A COMPLETED superior primary is also 'idle' -> no coordination.
	var objs2: Dictionary = {200: {"primary": {"need_type": "DEFEND_PROVINCE", "status": "COMPLETED"}}}
	_DO._process_operational_coordination(chars, objs2, by_id, 0)
	_ok(objs2.get(300, {}).get("primary", {}).is_empty(), "completed superior primary -> no coordination")


func _test_budget_exhaustion() -> void:
	print("[6] CO budget caps directed subordinates (budget 1, 2 idle subs -> 1 directed)")
	var taisa: L5RCharacterData = _mk(200, 3.5)
	taisa.civilian_orders_remaining = 1
	var sub_a: L5RCharacterData = _mk(300, 2.0, 200)
	var sub_b: L5RCharacterData = _mk(301, 2.0, 200)
	var chars: Array = [taisa, sub_a, sub_b]
	var by_id: Dictionary = {200: taisa, 300: sub_a, 301: sub_b}
	var objs: Dictionary = {200: {"primary": {"need_type": "DEFEND_PROVINCE", "status": "ACTIVE"}}}
	_DO._process_operational_coordination(chars, objs, by_id, 0)
	var directed: int = 0
	if not objs.get(300, {}).get("primary", {}).is_empty(): directed += 1
	if not objs.get(301, {}).get("primary", {}).is_empty(): directed += 1
	_ok(directed == 1, "exactly 1 of 2 idle subs directed (budget 1) (got %d)" % directed)
	_ok(taisa.civilian_orders_remaining == 0, "budget exhausted -> 0")


func _test_guards() -> void:
	print("[7] dead/PC subordinates skipped; PC superior does not coordinate")
	# PC superior -> no coordination even with budget + idle subs.
	var pc_sup: L5RCharacterData = _mk(200, 3.5, -1, false, true)
	pc_sup.civilian_orders_remaining = 2
	var s1: L5RCharacterData = _mk(300, 2.0, 200)
	var chars1: Array = [pc_sup, s1]
	var by1: Dictionary = {200: pc_sup, 300: s1}
	var objs1: Dictionary = {200: {"primary": {"need_type": "DEFEND_PROVINCE", "status": "ACTIVE"}}}
	_DO._process_operational_coordination(chars1, objs1, by1, 0)
	_ok(objs1.get(300, {}).get("primary", {}).is_empty(), "PC superior directs nobody")
	_ok(pc_sup.civilian_orders_remaining == 2, "PC superior spends no CO")

	# Dead + PC subordinates are not directed (and don't consume CO); a live one is.
	var taisa: L5RCharacterData = _mk(210, 3.5)
	taisa.civilian_orders_remaining = 3
	var dead_sub: L5RCharacterData = _mk(310, 2.0, 210, true)
	var pc_sub: L5RCharacterData = _mk(311, 2.0, 210, false, true)
	var live_sub: L5RCharacterData = _mk(312, 2.0, 210)
	var chars2: Array = [taisa, dead_sub, pc_sub, live_sub]
	var by2: Dictionary = {210: taisa, 310: dead_sub, 311: pc_sub, 312: live_sub}
	var objs2: Dictionary = {210: {"primary": {"need_type": "DEFEND_PROVINCE", "status": "ACTIVE"}}}
	_DO._process_operational_coordination(chars2, objs2, by2, 0)
	_ok(objs2.get(310, {}).get("primary", {}).is_empty(), "dead sub not directed")
	_ok(objs2.get(311, {}).get("primary", {}).is_empty(), "PC sub not directed")
	_ok(not objs2.get(312, {}).get("primary", {}).is_empty(), "live sub directed")
	_ok(taisa.civilian_orders_remaining == 2, "only the 1 live sub cost CO (3 -> 2)")


func _test_targets_propagated() -> void:
	print("[8] target_clan + target_npc_id propagate from the superior's objective")
	var taisa: L5RCharacterData = _mk(200, 3.5)
	taisa.civilian_orders_remaining = 1
	var sub: L5RCharacterData = _mk(300, 2.0, 200)
	var chars: Array = [taisa, sub]
	var by_id: Dictionary = {200: taisa, 300: sub}
	var objs: Dictionary = {
		200: {"primary": {"need_type": "SEEK_VENGEANCE", "status": "ACTIVE", "target_clan": "Lion", "target_npc_id": 777}},
	}
	_DO._process_operational_coordination(chars, objs, by_id, 0)
	var p: Dictionary = objs.get(300, {}).get("primary", {})
	_ok(p.get("target_clan", "") == "Lion", "target_clan Lion propagated")
	_ok(int(p.get("target_npc_id", -1)) == 777, "target_npc_id 777 propagated")
	# No target_province_id key when the source has none.
	_ok(not p.has("target_province_id"), "no phantom target_province_id when source lacks it")
