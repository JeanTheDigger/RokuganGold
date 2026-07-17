extends SceneTree
## Headless runtime driver for the s2.4 Wall jade resupply (D5).
## Verifies the centralized jade thresholds and the Shireikan reserve→tower
## refill pipeline that unblocks the sortie loop (a Tower no longer permanently
## stalls at 0 jade). Run: godot --headless -s tests/verify_wall_jade_resupply.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _tower(id: int, num: int, prov: int, jade: float, garrison: int = 3) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_tower_number = num
	s.province_id = prov
	s.jade_stockpile = jade
	s.garrison_pu = garrison
	s.wall_si = 10
	return s


func _prov(id: int, ss: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.shadowlands_strength = ss
	return p


func _shireikan(id: int, seat_settlement_id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.military_rank = Enums.MilitaryRank.SHIREIKAN
	c.physical_location = str(seat_settlement_id)
	return c


func _init() -> void:
	print("--- Wall Jade Resupply Verification (s2.4 D5) ---")
	_test_thresholds()
	_test_refill()
	_test_priority()
	_test_reserve_cap()
	_test_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_thresholds() -> void:
	print("[1] jade thresholds (s2.4.11 D5)")
	# garrison 3: Small alloc = int(3*0.20)*1 = 0; Medium alloc = int(3*0.40)*2 = 2.
	_ok(WallSystem.jade_critical_threshold(3) == 0.0, "critical threshold (g3) = 0")
	_ok(WallSystem.jade_routine_target(3) == 2.0, "routine target (g3) = 2")
	_ok(WallSystem.is_jade_critical(0.0, 3), "0 jade is critical")
	_ok(not WallSystem.is_jade_critical(1.0, 3), "1 jade not critical at g3")
	# garrison 10: Small = int(10*0.20)*1 = 2; Medium = int(10*0.40)*2 = 8; routine 10.
	_ok(WallSystem.jade_critical_threshold(10) == 2.0, "critical threshold (g10) = 2")
	_ok(WallSystem.jade_routine_target(10) == 10.0, "routine target (g10) = 10")
	_ok(WallSystem.is_jade_critical(2.0, 10), "2 jade critical at g10")
	_ok(not WallSystem.is_jade_critical(3.0, 10), "3 jade not critical at g10")


func _test_refill() -> void:
	print("[2] depleted tower refilled to routine, reserve tracked")
	# Southern Shireikan seated at tower 3; six towers in the half, one depleted.
	var towers: Array = []
	for n: int in range(1, 7):
		towers.append(_tower(100 + n, n, 200 + n, 2.0))  # all at routine
	# Deplete tower 5 to 0 (critical).
	(towers[4] as SettlementData).jade_stockpile = 0.0
	var provs: Dictionary = {}
	for n: int in range(1, 7):
		provs[200 + n] = _prov(200 + n, 0)
	var sh := _shireikan(500, 103)  # seat = tower 3's settlement id
	var res: Array = _DO._process_wall_jade_resupply([sh], towers, provs)
	_ok((towers[4] as SettlementData).jade_stockpile == 2.0, "depleted tower refilled to routine (2)")
	_ok(res.size() == 1 and int(res[0]["tower"]) == 5 and bool(res[0]["was_critical"]), "one critical delivery to tower 5")
	# Reserve = 12 delivered - 2 spent = 10 retained.
	_ok(abs(float(sh.supply_ledger.get("wall_jade_reserve", -1.0)) - 10.0) < 0.001, "reserve retains 10 after refill")
	# Running again next season with all at routine → no deliveries, reserve tops to cap.
	var res2: Array = _DO._process_wall_jade_resupply([sh], towers, provs)
	_ok(res2.is_empty(), "no delivery when all towers at routine")


func _test_priority() -> void:
	print("[3] critical before active-front before routine top-up")
	# Three depleted towers: one critical (0), one active-front (below routine, SS high),
	# one routine top-up (below routine, SS low). Small reserve so ordering matters.
	var towers: Array = [
		_tower(301, 1, 401, 0.0),   # critical, SS low
		_tower(302, 2, 402, 1.0),   # below routine (2), SS high → active
		_tower(303, 3, 403, 1.0),   # below routine, SS low → routine top-up
	]
	var provs: Dictionary = {401: _prov(401, 0), 402: _prov(402, 12), 403: _prov(403, 0)}
	var sh := _shireikan(600, 303)  # seat tower 3 → Southern half (1-6)
	# Constrain the reserve so it can't satisfy all: set it low via a pre-seeded ledger.
	# Delivery adds 12 (cap 24); with 3 towers needing 2+1+1 = 4 total, all get filled.
	# Instead verify ordering by checking the result sequence.
	var res: Array = _DO._process_wall_jade_resupply([sh], towers, provs)
	_ok(res.size() == 3, "all three delivered when reserve suffices")
	if res.size() == 3:
		_ok(int(res[0]["tower"]) == 1 and bool(res[0]["was_critical"]), "critical tower served first")
		_ok(int(res[1]["tower"]) == 2, "active-front tower served second")
		_ok(int(res[2]["tower"]) == 3, "routine top-up served last")
	_ok((towers[0] as SettlementData).jade_stockpile == 2.0, "critical → routine")


func _test_reserve_cap() -> void:
	print("[4] reserve capped, exhaustion partial-fills by priority")
	var towers: Array = [_tower(701, 1, 801, 0.0, 20)]  # garrison 20 → routine big
	var provs: Dictionary = {801: _prov(801, 0)}
	var sh := _shireikan(900, 701)
	# g20: Small = int(20*0.20)*1 = 4; Medium = int(20*0.40)*2 = 16; routine 20.
	_ok(WallSystem.jade_routine_target(20) == 20.0, "routine target (g20) = 20")
	var res: Array = _DO._process_wall_jade_resupply([sh], towers, provs)
	# Reserve delivery = 12 (capped 24), tower needs 20 → gets 12, reserve 0.
	_ok((towers[0] as SettlementData).jade_stockpile == 12.0, "partial fill limited by reserve (12)")
	_ok(float(sh.supply_ledger.get("wall_jade_reserve", -1.0)) == 0.0, "reserve exhausted")
	_ok(res.size() == 1 and float(res[0]["jade_delivered"]) == 12.0, "delivery == 12")
	# Pre-seed a full reserve then run: capped at 24, minus 8 to finish the tower = 16.
	sh.supply_ledger["wall_jade_reserve"] = 24.0
	var res2: Array = _DO._process_wall_jade_resupply([sh], towers, provs)
	_ok((towers[0] as SettlementData).jade_stockpile == 20.0, "finished to routine from full reserve")
	_ok(float(sh.supply_ledger.get("wall_jade_reserve", -1.0)) == 16.0, "reserve capped at 24 then spent 8 = 16")


func _test_guards() -> void:
	print("[5] guards: dead Shireikan, no towers, non-Shireikan")
	var towers: Array = [_tower(1001, 1, 1101, 0.0)]
	var provs: Dictionary = {1101: _prov(1101, 0)}
	var dead := _shireikan(1200, 1001)
	dead.wounds_taken = 99999
	var res: Array = _DO._process_wall_jade_resupply([dead], towers, provs)
	_ok(res.is_empty() and (towers[0] as SettlementData).jade_stockpile == 0.0, "dead Shireikan does nothing")
	# No towers at all.
	_ok(_DO._process_wall_jade_resupply([_shireikan(1300, 1)], [], {}).is_empty(), "no towers → no-op")
	# A non-Shireikan character is ignored.
	var bushi := L5RCharacterData.new()
	bushi.character_id = 1400
	bushi.military_rank = Enums.MilitaryRank.CHUI
	bushi.physical_location = "1001"
	var res2: Array = _DO._process_wall_jade_resupply([bushi], towers, provs)
	_ok(res2.is_empty(), "non-Shireikan ignored")
