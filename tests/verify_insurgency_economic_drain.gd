extends SceneTree
## Runtime driver for the insurgency per-season economic drain fix (s11.11).
## InsurgencySystem.get_koku_drain / get_rice_drain were zero-caller effect arbiters: process_season
## never drained province Rice/Koku, so the whole s11.11 economic-pressure layer was inert (Nezumi
## never stole rice, Ronin/Pirate never drained koku). Fix: DayOrchestrator._process_insurgencies now
## drains each SURVIVING insurgency's GDD-locked absolute amount from its province's settlement
## stockpiles -- Nezumi -> Rice (Strength*0.1), Ronin/Pirate -> Koku (Strength*0.05). The
## URBAN_CRIMINAL_NETWORK koku branch is DEFERRED (percentage-of-generation, not an absolute stockpile
## drain) and must NOT touch the stockpile.
## Run: godot --headless -s tests/verify_insurgency_economic_drain.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _IS := preload("res://simulation/insurgency_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _ins(t: int, pid: int, strength: int) -> InsurgencyData:
	var i := InsurgencyData.new()
	i.insurgency_id = 100 + strength
	i.insurgency_type = t
	i.province_id = pid
	i.strength = strength
	i.detected = true
	i.concealment = 5
	return i


func _sett(pid: int, rice: float, koku: float) -> SettlementData:
	var s := SettlementData.new()
	s.province_id = pid
	s.rice_stockpile = rice
	s.koku_stockpile = koku
	return s


func _prov(pid: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.clan = "Crab"
	p.province_taint_level = 0.0
	return p


func _init() -> void:
	print("--- Insurgency economic drain wired into _process_insurgencies (s11.11) ---")
	_test_arbiters()
	_test_helper()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiters() -> void:
	print("[1] the drain arbiters return the GDD-locked absolute amounts")
	_ok(abs(_IS.get_rice_drain(_ins(Enums.InsurgencyType.NEZUMI_INFESTATION, 1, 4)) - 0.4) < 0.0001,
		"Nezumi rice = Strength*0.1 (4 -> 0.4)")
	_ok(abs(_IS.get_rice_drain(_ins(Enums.InsurgencyType.NEZUMI_INFESTATION, 1, 12)) - 1.0) < 0.0001,
		"Nezumi rice caps at 1.0 (Strength>=10)")
	_ok(_IS.get_rice_drain(_ins(Enums.InsurgencyType.RONIN_BANDIT, 1, 4)) == 0.0,
		"non-Nezumi -> 0 rice drain")
	_ok(abs(_IS.get_koku_drain(_ins(Enums.InsurgencyType.RONIN_BANDIT, 1, 4)) - 0.2) < 0.0001,
		"Ronin koku = Strength*0.05 (4 -> 0.2)")
	_ok(abs(_IS.get_koku_drain(_ins(Enums.InsurgencyType.PIRATE_FLEET, 1, 8)) - 0.4) < 0.0001,
		"Pirate koku = Strength*0.05 (8 -> 0.4 = the cap)")


func _test_helper() -> void:
	print("[2] _drain_province_stockpile drains the aggregate and floors at 0")
	var a := _sett(1, 0.3, 0.0)
	var b := _sett(1, 0.5, 0.0)
	_DO._drain_province_stockpile([a, b], 0.6, "rice_stockpile")
	# 0.6 drained from [0.3, 0.5]: first empties a (0.3), then 0.3 from b (-> 0.2).
	_ok(abs(a.rice_stockpile - 0.0) < 0.0001, "first settlement emptied (0.3 -> 0.0)")
	_ok(abs(b.rice_stockpile - 0.2) < 0.0001, "remainder taken from second (0.5 -> 0.2)")

	var c := _sett(1, 0.1, 0.0)
	_DO._drain_province_stockpile([c], 5.0, "rice_stockpile")
	_ok(c.rice_stockpile == 0.0, "over-drain floors at 0 (never negative)")


func _test_end_to_end() -> void:
	print("[3] _process_insurgencies applies the drain end-to-end")
	var dice := DiceEngine.new(777)

	# --- Nezumi drains rice, leaves koku untouched ---
	var prov: Dictionary = {5: _prov(5)}
	var sett := _sett(5, 10.0, 10.0)
	var nez := _ins(Enums.InsurgencyType.NEZUMI_INFESTATION, 5, 4)
	var ins_list: Array = [nez]
	_DO._process_insurgencies(
		ins_list, prov, dice, 0, [200], {}, {}, {}, [1], [], {}, [sett],
	)
	if not ins_list.is_empty():  # survived the season
		var expected: float = nez.strength * 0.1
		_ok(abs((10.0 - sett.rice_stockpile) - expected) < 0.0001,
			"Nezumi drained rice by Strength*0.1 (post-season Strength %d -> %.2f)" % [nez.strength, expected])
		_ok(abs(sett.koku_stockpile - 10.0) < 0.0001, "Nezumi left koku untouched")
	else:
		_ok(false, "Nezumi insurgency unexpectedly removed before drain")

	# --- Ronin drains koku, leaves rice untouched ---
	var prov2: Dictionary = {6: _prov(6)}
	var sett2 := _sett(6, 10.0, 10.0)
	var ron := _ins(Enums.InsurgencyType.RONIN_BANDIT, 6, 4)
	var ins_list2: Array = [ron]
	_DO._process_insurgencies(
		ins_list2, prov2, dice, 0, [300], {}, {}, {}, [1], [], {}, [sett2],
	)
	if not ins_list2.is_empty():
		var expected2: float = ron.strength * 0.05
		_ok(abs((10.0 - sett2.koku_stockpile) - expected2) < 0.0001,
			"Ronin drained koku by Strength*0.05 (post-season Strength %d -> %.2f)" % [ron.strength, expected2])
		_ok(abs(sett2.rice_stockpile - 10.0) < 0.0001, "Ronin left rice untouched")
	else:
		_ok(false, "Ronin insurgency unexpectedly removed before drain")

	# --- Urban Criminal Network does NOT drain the stockpile (deferred percent-of-generation) ---
	var prov3: Dictionary = {7: _prov(7)}
	var sett3 := _sett(7, 10.0, 10.0)
	var crim := _ins(Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK, 7, 4)
	var ins_list3: Array = [crim]
	_DO._process_insurgencies(
		ins_list3, prov3, dice, 0, [400], {}, {}, {}, [1], [], {}, [sett3],
	)
	_ok(abs(sett3.koku_stockpile - 10.0) < 0.0001,
		"Urban Criminal koku drain DEFERRED -> stockpile untouched (no invented absolute drain)")
	_ok(abs(sett3.rice_stockpile - 10.0) < 0.0001, "Urban Criminal leaves rice untouched")
