extends SceneTree
## Runtime driver for the disposition-scaled supply-sharing fix (s12.2 line 403).
## DispositionSystem.get_supply_share_ratio (the GDD arbiter: Friend +31 ~ half the surplus rising
## to the full amount at Devoted +61) was DORMANT -- zero callers -- and DayOrchestrator
## ._process_supply_sharing shared a flat `surplus * 0.5` regardless of the giver's disposition
## toward the recipient. Fix: amount = surplus * maxf(0.5, get_supply_share_ratio(giver_disp)) --
## a closer ally shares MORE, nothing shares LESS (the 0.5 floor = the +31 Friend baseline, so a
## deliberately-chosen SHARE_SUPPLIES has zero regression), wiring the dormant arbiter.
## Run: godot --headless -s tests/verify_supply_share_ratio.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _DS := preload("res://simulation/disposition_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _giver(disp_toward_recipient: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Crab"
	c.family = "Hida"
	c.birth_clan = ""  # no birth-clan floor -> effective disposition == stored
	c.disposition_values = {2: disp_toward_recipient}
	c.honor = 5.0
	return c


func _recipient() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 2
	c.clan = "Crane"
	c.family = "Doji"
	return c


func _giver_settlement() -> SettlementData:
	var s := SettlementData.new()
	s.province_id = 10
	s.population_pu = 100  # seasonal need 25, 4-season need 100
	s.rice_stockpile = 200.0  # surplus = 200 - 100 = 100
	return s


func _receiver_settlement(lord_id: int) -> SettlementData:
	var s := SettlementData.new()
	s.province_id = 20
	s.population_pu = 100
	s.rice_stockpile = 0.0  # starving -> stage 3
	s.lord_character_id = lord_id
	return s


func _prov(pid: int, clan: String) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = clan
	return p


# Runs one supply share; returns the koku... err, rice amount actually shared (giver stockpile drop).
func _shared_amount(giver_disp: int, recipient_lord_id: int) -> float:
	var giver := _giver(giver_disp)
	var recip := _recipient()
	var gs := _giver_settlement()
	var rs := _receiver_settlement(recipient_lord_id)
	var chars: Dictionary = {1: giver, 2: recip}
	var provs: Dictionary = {10: _prov(10, "Crab"), 20: _prov(20, "Crane")}
	var applied: Array = [{
		"effects": {"requires_supply_sharing": true},
		"character_id": 1,
		"target_province_id": 20,
	}]
	var before: float = gs.rice_stockpile
	_DO._process_supply_sharing(applied, chars, [gs, rs], provs, {})
	return before - gs.rice_stockpile


func _init() -> void:
	print("--- Disposition-scaled supply sharing wires get_supply_share_ratio (s12.2:403) ---")
	_test_arbiter()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter() -> void:
	print("[1] get_supply_share_ratio / will_share_supplies match the GDD tiers")
	_ok(_DS.get_supply_share_ratio(30) == 0.0, "below +31 -> 0.0 (refuses in the request model)")
	_ok(abs(_DS.get_supply_share_ratio(31) - 0.5) < 0.0001, "+31 Friend floor -> ~half (0.5)")
	_ok(_DS.get_supply_share_ratio(60) > 0.98, "+60 -> nearly full")
	_ok(_DS.get_supply_share_ratio(61) == 1.0, "+61 Devoted -> full (1.0)")
	_ok(_DS.get_supply_share_ratio(90) == 1.0, "+90 -> full (1.0)")
	_ok(not _DS.will_share_supplies(30) and _DS.will_share_supplies(31), "will_share gate at +31")


func _test_end_to_end() -> void:
	print("[2] _process_supply_sharing scales the shared amount by disposition (surplus=100)")
	# Devoted (+70): ratio 1.0 -> shares the FULL surplus (100), not the flat 50.
	_ok(abs(_shared_amount(70, 2) - 100.0) < 0.001, "Devoted +70 shares 100% of surplus (was flat 50)")
	# Friend +31: ratio 0.5 -> half.
	_ok(abs(_shared_amount(31, 2) - 50.0) < 0.001, "Friend +31 shares 50% (the baseline)")
	# +45: ratio 0.5 + (14/29)*0.5 = 0.7414 -> ~74.14.
	_ok(abs(_shared_amount(45, 2) - 74.14) < 0.5, "Friend +45 shares the proportional ~74%")
	# Low disposition (+5, below Friend): FLOORED at 0.5 -> 50 (no regression from the old flat 0.5).
	_ok(abs(_shared_amount(5, 2) - 50.0) < 0.001, "below-Friend chosen share floors at 50% (no regression)")
	# Unresolvable recipient lord (-1): floor 0.5 -> 50.
	_ok(abs(_shared_amount(70, -1) - 50.0) < 0.001, "unresolvable recipient -> Friend-floor 50% (no crash)")
