extends SceneTree
## Headless runtime driver for the s2.4 Wall garrison Taint watch (D7).
## Verifies the Kuni Rank-4 removal: a Tainted Rank-4 stationed character is
## removed from the Wall (relocated off-Wall, hierarchy detached) ONLY when a
## Kuni assessor is present; below-Rank-4 and no-Kuni cases leave them in place.
## Run: godot --headless -s tests/verify_wall_taint_removal.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _tower(id: int, num: int, prov: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_tower_number = num
	s.province_id = prov
	return s


func _settle(id: int, prov: int, t: Enums.SettlementType) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = t
	s.province_id = prov
	return s


func _prov(id: int, clan: String) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.clan = clan
	return p


func _kuni(id: int, loc: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = str(loc)
	c.school = "Kuni Shugenja"
	c.family = "Kuni"
	return c


func _garrison(id: int, loc: int, taint: float, superior: int = 500) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = str(loc)
	c.taint = taint
	c.operational_superior_id = superior
	c.tea_managed_until_ic_day = 90
	c.school = "Hida Bushi"
	return c


func _init() -> void:
	print("--- Wall Garrison Taint Watch Verification (s2.4 D7) ---")
	_test_removal_with_kuni()
	_test_no_kuni()
	_test_below_threshold()
	_test_dest_preference()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_removal_with_kuni() -> void:
	print("[1] Rank-4 removed when a Kuni is stationed")
	var tower := _tower(100, 1, 200)
	var monastery := _settle(101, 200, Enums.SettlementType.MONASTERY)
	var provs: Dictionary = {200: _prov(200, "Crab")}
	var kuni := _kuni(500, 100)
	var rank4 := _garrison(10, 100, 4.0)   # Rank 4 exactly
	var rank5 := _garrison(11, 100, 5.2)   # Lost — also >= 4
	var res: Array = _DO._process_wall_taint_removal([kuni, rank4, rank5], [tower, monastery], provs)
	_ok(res.size() == 2, "two removals reported")
	_ok(rank4.physical_location == "101" and rank4.operational_superior_id == -1, "Rank-4 relocated to monastery + detached")
	_ok(rank4.tea_managed_until_ic_day == -1, "removed char's Tea flag cleared")
	_ok(rank5.physical_location == "101", "Rank-5 (Lost) also removed")
	_ok(kuni.physical_location == "100", "the Kuni stays at the Tower")


func _test_no_kuni() -> void:
	print("[2] no Kuni → no removal (operationally blind)")
	var tower := _tower(300, 1, 400)
	var monastery := _settle(301, 400, Enums.SettlementType.MONASTERY)
	var provs: Dictionary = {400: _prov(400, "Crab")}
	var rank4 := _garrison(20, 300, 4.5)
	var res: Array = _DO._process_wall_taint_removal([rank4], [tower, monastery], provs)
	_ok(res.is_empty(), "no removal without a Kuni")
	_ok(rank4.physical_location == "300" and rank4.operational_superior_id == 500, "Rank-4 stays in the garrison")


func _test_below_threshold() -> void:
	print("[3] below Rank 4 stays")
	var tower := _tower(600, 1, 700)
	var monastery := _settle(601, 700, Enums.SettlementType.MONASTERY)
	var provs: Dictionary = {700: _prov(700, "Crab")}
	var kuni := _kuni(800, 600)
	var rank3 := _garrison(30, 600, 3.9)   # Rank 3 (3.0-3.9)
	var res: Array = _DO._process_wall_taint_removal([kuni, rank3], [tower, monastery], provs)
	_ok(res.is_empty(), "Rank 3 not removed")
	_ok(rank3.physical_location == "600", "Rank-3 stays at the Tower")


func _test_dest_preference() -> void:
	print("[4] destination prefers religious house, falls back to inland")
	var tower := _tower(900, 1, 1000)
	# Only a CITY in-clan (no religious house) → fallback to the city.
	var city := _settle(901, 1000, Enums.SettlementType.CITY)
	var provs: Dictionary = {1000: _prov(1000, "Crab")}
	var kuni := _kuni(1100, 900)
	var rank4 := _garrison(40, 900, 4.0)
	_DO._process_wall_taint_removal([kuni, rank4], [tower, city], provs)
	_ok(rank4.physical_location == "901", "falls back to inland city when no monastery")
	# Wrong-clan settlements are never chosen.
	var tower2 := _tower(1200, 2, 1300)
	var wrong := _settle(1201, 1300, Enums.SettlementType.MONASTERY)
	wrong.province_id = 1301  # a different province
	var provs2: Dictionary = {1300: _prov(1300, "Crab"), 1301: _prov(1301, "Crane")}
	var kuni2 := _kuni(1400, 1200)
	var rank4b := _garrison(41, 1200, 4.0)
	_DO._process_wall_taint_removal([kuni2, rank4b], [tower2, wrong], provs2)
	_ok(rank4b.physical_location == "1200", "no in-clan destination → stays put (posting still cleared)")
	_ok(rank4b.operational_superior_id == -1, "detached even when no destination found")
