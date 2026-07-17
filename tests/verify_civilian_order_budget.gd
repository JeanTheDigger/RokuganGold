extends SceneTree
## Runtime driver for the s57.34 Civilian Order budget assignment — a catastrophic dormant bug.
## CivilianOrderBudget.update_budget_for_character (the SOLE writer of civilian_order_budget_max,
## from the LOCKED s57.34.2 BUDGET_BY_RANK table) had ZERO production callers, and world-gen never
## set the field, so civilian_order_budget_max stayed at its default 0 for EVERY character. The daily
## reset copied 0 into civilian_orders_remaining, so the wave-resolver gate
## `is_lord and civilian_orders_remaining > 0` was never entered — the entire Civilian Order
## governance channel (SET_TAX_RATE, ASSIGN_VASSAL_OBJECTIVE, SEND_INVITATION, REQUEST_ART, lord
## WRITE_LETTER, …) was inert since inception. FIX: _reset_all_ap now calls
## update_budget_for_character(c) before the reset, tracking current lord rank each day.
## Run: godot --headless -s tests/verify_civilian_order_budget.gd

const _COB := preload("res://simulation/civilian_order_budget.gd")
const _CH := preload("res://shared/character_data.gd")
const _EN := preload("res://shared/enums.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _lord(cid: int, status: float) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.status = status
	return c


func _init() -> void:
	print("--- s57.34 Civilian Order budget assignment (was permanently 0) ---")
	_test_default_is_zero()
	_test_arbiter_by_rank()
	_test_reset_now_assigns_budget()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_default_is_zero() -> void:
	print("[1] the field defaults to 0 (the bug: never set from rank in production)")
	var fam: L5RCharacterData = _lord(1, 6.0)  # FAMILY_DAIMYO
	_ok(fam.civilian_order_budget_max == 0, "fresh lord defaults budget_max 0")
	# The OLD reset line (remaining = budget_max) would have copied 0 -> no civilian orders.
	fam.civilian_orders_remaining = fam.civilian_order_budget_max
	_ok(fam.civilian_orders_remaining == 0, "old reset -> remaining 0 (the dead-channel symptom)")


func _test_arbiter_by_rank() -> void:
	print("[2] update_budget_for_character assigns the LOCKED s57.34.2 budget per lord rank")
	var cases := {
		3.0: 0,   # VILLAGE_HEADMAN / non-lord
		4.0: 5,   # CITY_DAIMYO
		5.0: 8,   # PROVINCIAL_DAIMYO
		6.0: 10,  # FAMILY_DAIMYO
		7.0: 12,  # CLAN_CHAMPION
		9.0: 15,  # IMPERIAL
	}
	for status_v: float in cases:
		var c: L5RCharacterData = _lord(10, status_v)
		_COB.update_budget_for_character(c)
		_ok(c.civilian_order_budget_max == cases[status_v],
			"status %.1f -> budget %d" % [status_v, cases[status_v]])


func _test_reset_now_assigns_budget() -> void:
	print("[3] the fixed daily reset gives lords their civilian orders (was 0 for all)")
	var champion: L5RCharacterData = _lord(20, 7.0)   # CLAN_CHAMPION -> 12
	var daimyo: L5RCharacterData = _lord(21, 6.0)     # FAMILY_DAIMYO -> 10
	var samurai: L5RCharacterData = _lord(22, 3.0)    # non-lord -> 0
	DayOrchestrator._reset_all_ap([champion, daimyo, samurai])
	_ok(champion.civilian_orders_remaining == 12, "champion reset -> 12 civilian orders (was 0)")
	_ok(daimyo.civilian_orders_remaining == 10, "family daimyo reset -> 10 (was 0)")
	_ok(samurai.civilian_orders_remaining == 0, "non-lord reset -> 0 (unchanged, no regression)")
	# The wave-resolver gate `is_lord and civilian_orders_remaining > 0` is now enterable for lords.
	_ok(champion.civilian_order_budget_max > 0, "lord budget_max now > 0 (daily-letter exclusion works)")
	_ok(samurai.civilian_order_budget_max == 0, "non-lord budget_max stays 0 (free daily letter pass)")
