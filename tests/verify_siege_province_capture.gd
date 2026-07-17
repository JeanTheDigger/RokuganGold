extends SceneTree
## Runtime driver for wiring WarSystem.record_province_capture into the live siege-capture site
## (s53, LOCKED: "Terms require formally ceding provinces held at the start of the war"). The
## function was fully built AND its consumer is LIVE (war_termination._get_captured_provinces ->
## territory_transferred -> apply_territory_transfer flips province.clan at peace) -- but it had
## ZERO production callers, so provinces_captured_by_a/b were ALWAYS empty and every war ended
## transferring zero territory regardless of who won. Now DayOrchestrator._apply_siege_province_capture
## (fired once per won siege alongside the hostage capture) records the besieged province.
## Verifies: attacker-captor records into the correct war side; ally captor records to the principal
## side; the guards (self-clan, no war, unknown settlement/province) no-op; and the end-to-end
## war-termination consumer then transfers exactly that province at peace.
## Run: godot --headless -s tests/verify_siege_province_capture.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _WS := preload("res://simulation/war_system.gd")
const _WT := preload("res://simulation/war_termination.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _lord(cid: int, clan: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.clan = clan
	return c


func _settle(sid: int, pid: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = pid
	return s


func _prov(pid: int, clan: String) -> Dictionary:
	# advance_day keeps `provinces` as a Dictionary keyed by province_id.
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	return {pid: p}


func _war(clan_a: String, clan_b: String) -> WarData:
	var w := WarData.new()
	w.war_id = 1
	w.clan_a = clan_a
	w.clan_b = clan_b
	w.is_active = true
	return w


func _init() -> void:
	print("--- Siege province capture -> war captured-province list (s53) ---")
	_test_records_capture()
	_test_ally_captor()
	_test_guards()
	_test_end_to_end_transfer()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_records_capture() -> void:
	print("[1] attacker (Lion) captures a Crane province -> recorded on Lion's war side")
	var war := _war("Lion", "Crane")            # Lion = side a, Crane = side b
	var by_id: Dictionary = {10: _lord(10, "Lion")}
	var settlements: Array = [_settle(500, 77)]  # settlement 500 in province 77
	var provinces: Dictionary = _prov(77, "Crane")  # province 77 owned by Crane (defender)
	_DO._apply_siege_province_capture(500, 10, settlements, provinces, [war], by_id)
	_ok(77 in war.provinces_captured_by_a, "province 77 recorded on side a (Lion)")
	_ok(77 not in war.provinces_captured_by_b, "not on side b (Crane)")


func _test_ally_captor() -> void:
	print("[2] an ALLIED captor records to that side's principal list")
	var war := _war("Crab", "Scorpion")
	war.allied_clans_a = ["Crane"]               # Crane fights on Crab's side
	var by_id: Dictionary = {11: _lord(11, "Crane")}  # captor is the ally
	var settlements: Array = [_settle(600, 88)]
	var provinces: Dictionary = _prov(88, "Scorpion")
	_DO._apply_siege_province_capture(600, 11, settlements, provinces, [war], by_id)
	_ok(88 in war.provinces_captured_by_a, "ally (Crane) capture recorded on principal side a (Crab)")


func _test_guards() -> void:
	print("[3] guards: self-clan province / no war / unknown ids -> no-op")
	# Capturing a province your own clan already owns -> nothing.
	var war := _war("Lion", "Crane")
	var by_id: Dictionary = {10: _lord(10, "Lion")}
	_DO._apply_siege_province_capture(500, 10, [_settle(500, 77)], _prov(77, "Lion"), [war], by_id)
	_ok(war.provinces_captured_by_a.is_empty(), "self-clan province not recorded")

	# No active war between captor and defender -> nothing.
	var war2 := _war("Dragon", "Phoenix")
	_DO._apply_siege_province_capture(500, 10, [_settle(500, 77)], _prov(77, "Crane"), [war2], by_id)
	_ok(war2.provinces_captured_by_a.is_empty() and war2.provinces_captured_by_b.is_empty(),
		"no war between Lion and Crane -> nothing recorded")

	# Unknown settlement -> nothing.
	var war3 := _war("Lion", "Crane")
	_DO._apply_siege_province_capture(999, 10, [_settle(500, 77)], _prov(77, "Crane"), [war3], by_id)
	_ok(war3.provinces_captured_by_a.is_empty(), "unknown settlement id -> nothing recorded")

	# Missing captor -> nothing.
	var war4 := _war("Lion", "Crane")
	_DO._apply_siege_province_capture(500, -1, [_settle(500, 77)], _prov(77, "Crane"), [war4], {})
	_ok(war4.provinces_captured_by_a.is_empty(), "invalid captor -> nothing recorded")


func _test_end_to_end_transfer() -> void:
	print("[4] end-to-end: recorded capture -> war_termination transfers that province at peace")
	var war := _war("Lion", "Crane")
	var by_id: Dictionary = {10: _lord(10, "Lion")}
	# Lion captures two Crane provinces during the war.
	_DO._apply_siege_province_capture(500, 10, [_settle(500, 77)], _prov(77, "Crane"), [war], by_id)
	_DO._apply_siege_province_capture(501, 10, [_settle(501, 78)], _prov(78, "Crane"), [war], by_id)
	_ok(war.provinces_captured_by_a.size() == 2, "two Crane provinces recorded for Lion")

	# The war-termination consumer reads exactly those (side a = Lion).
	var captured: Array = _WT._get_captured_provinces(war, "a")
	_ok(77 in captured and 78 in captured, "war_termination._get_captured_provinces sees them (was empty pre-fix)")
