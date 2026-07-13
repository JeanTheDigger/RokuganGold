extends SceneTree
## Runtime driver for the settlement -> governing-NPC linkage wire. SettlementData.lord_character_id
## and shrine_custodian_id were zero-writer dead @export fields: world-gen never set them and no
## production pass wrote them, so 10+ readers (supply-share recipient resolution, art-ownership /
## daimyo-glory maps, the s57.26b shide auto-grant) all misfired on the -1 default. Fix:
## DayOrchestrator._populate_settlement_governance runs daily, resolving each province's lord via the
## SAME clan/family wildcard heuristic as _find_province_lord (highest-status matching char) in one
## O(chars) pass, and each religious settlement's custodian as the highest-Insight shugenja stationed
## there. Self-correcting: a dead lord's settlements re-point next tick.
## Run: godot --headless -s tests/verify_settlement_governance.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _PROV := preload("res://shared/province_data.gd")
const _SETT := preload("res://shared/settlement_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mkc(id: int, clan: String, fam: String, status: float) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = clan
	c.family = fam
	c.status = status
	return c


func _mkp(id: int, clan: String, fam: String) -> ProvinceData:
	var p: ProvinceData = _PROV.new()
	p.province_id = id
	p.clan = clan
	p.family = fam
	return p


func _mks(id: int, pid: int, st: int) -> SettlementData:
	var s: SettlementData = _SETT.new()
	s.settlement_id = id
	s.province_id = pid
	s.settlement_type = st
	return s


func _init() -> void:
	print("--- settlement -> governing-NPC linkage ---")
	_test_lord_resolution()
	_test_custodian()
	_test_self_correction()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_lord_resolution() -> void:
	print("[1] lord resolved by clan/family wildcard, matching _find_province_lord")
	var doji_daimyo: L5RCharacterData = _mkc(1, "Crane", "Doji", 6.0)
	var doji_low: L5RCharacterData = _mkc(2, "Crane", "Doji", 3.0)
	var kakita: L5RCharacterData = _mkc(3, "Crane", "Kakita", 5.0)
	var akodo: L5RCharacterData = _mkc(4, "Lion", "Akodo", 7.0)  # highest status overall
	var by_id: Dictionary = {1: doji_daimyo, 2: doji_low, 3: kakita, 4: akodo}
	# clan+family exact -> highest-status Crane/Doji.
	var p_cf: ProvinceData = _mkp(10, "Crane", "Doji")
	# clan only -> highest-status Crane (Doji daimyo 6 > Kakita 5).
	var p_c: ProvinceData = _mkp(11, "Crane", "")
	# family only (any clan) -> highest-status Kakita.
	var p_f: ProvinceData = _mkp(12, "", "Kakita")
	# both empty -> global highest (Akodo 7).
	var p_any: ProvinceData = _mkp(13, "", "")
	var provs: Dictionary = {10: p_cf, 11: p_c, 12: p_f, 13: p_any}
	var s_cf: SettlementData = _mks(100, 10, Enums.SettlementType.CITY)
	var s_c: SettlementData = _mks(101, 11, Enums.SettlementType.VILLAGE)
	var s_f: SettlementData = _mks(102, 12, Enums.SettlementType.VILLAGE)
	var s_any: SettlementData = _mks(103, 13, Enums.SettlementType.VILLAGE)
	# A settlement in a province with NO matching lord (Phoenix clan, none exist) -> -1.
	var p_none: ProvinceData = _mkp(14, "Phoenix", "Isawa")
	provs[14] = p_none
	var s_none: SettlementData = _mks(104, 14, Enums.SettlementType.VILLAGE)
	var setts: Array = [s_cf, s_c, s_f, s_any, s_none]
	_DO._populate_settlement_governance(setts, provs, by_id)
	_ok(s_cf.lord_character_id == 1, "clan+family province -> highest-status Crane/Doji (id 1)")
	_ok(s_c.lord_character_id == 1, "clan-only province -> highest-status Crane (Doji daimyo 6 > Kakita 5)")
	_ok(s_f.lord_character_id == 3, "family-only province -> highest-status Kakita (id 3)")
	_ok(s_any.lord_character_id == 4, "empty clan+family -> global highest (Akodo 7)")
	_ok(s_none.lord_character_id == -1, "no matching lord (Phoenix/Isawa) -> -1")
	# Parity spot-check against the canonical _find_province_lord.
	_ok(_DO._find_province_lord(p_cf, by_id).character_id == s_cf.lord_character_id, "parity: clan+family matches _find_province_lord")
	_ok(_DO._find_province_lord(p_c, by_id).character_id == s_c.lord_character_id, "parity: clan-only matches _find_province_lord")


func _test_custodian() -> void:
	print("[2] shrine_custodian_id = highest-Insight shugenja at a religious settlement only")
	var lord: L5RCharacterData = _mkc(1, "Phoenix", "Isawa", 6.0)
	# Two shugenja stationed at the temple; higher Insight wins. Insight tracks rings+skills, so give
	# the senior one strong rings via the trait pairs Fire=min(agi,int) etc. Simpler: use skills count.
	var shug_low: L5RCharacterData = _mkc(2, "Phoenix", "Isawa", 3.0)
	shug_low.school_type = Enums.SchoolType.SHUGENJA
	shug_low.physical_location = "500"
	var shug_high: L5RCharacterData = _mkc(3, "Phoenix", "Isawa", 4.0)
	shug_high.school_type = Enums.SchoolType.SHUGENJA
	shug_high.physical_location = "500"
	# Boost shug_high's insight above shug_low via a higher insight_rank stat and more skills.
	shug_high.fire_ring = 4; shug_high.air_ring = 4; shug_high.water_ring = 4
	shug_high.earth_ring = 4; shug_high.void_ring = 4
	shug_low.fire_ring = 2; shug_low.air_ring = 2; shug_low.water_ring = 2
	shug_low.earth_ring = 2; shug_low.void_ring = 2
	# A bushi at the same temple must NOT be picked as custodian.
	var bushi: L5RCharacterData = _mkc(4, "Phoenix", "Shiba", 5.0)
	bushi.school_type = Enums.SchoolType.BUSHI
	bushi.physical_location = "500"
	var by_id: Dictionary = {1: lord, 2: shug_low, 3: shug_high, 4: bushi}
	var p: ProvinceData = _mkp(20, "Phoenix", "Isawa")
	var temple: SettlementData = _mks(500, 20, Enums.SettlementType.TEMPLE)
	var city: SettlementData = _mks(501, 20, Enums.SettlementType.CITY)  # non-religious
	_DO._populate_settlement_governance([temple, city], {20: p}, by_id)
	_ok(temple.shrine_custodian_id == 3, "temple custodian = highest-Insight shugenja (id 3)")
	_ok(city.shrine_custodian_id == -1, "non-religious settlement leaves custodian -1")
	# A religious settlement with no shugenja present -> -1.
	var p2: ProvinceData = _mkp(21, "Phoenix", "Isawa")
	var empty_temple: SettlementData = _mks(502, 21, Enums.SettlementType.MONASTERY)
	_DO._populate_settlement_governance([empty_temple], {21: p2}, {1: lord, 4: bushi})
	_ok(empty_temple.shrine_custodian_id == -1, "religious settlement with no shugenja -> -1")


func _test_self_correction() -> void:
	print("[3] self-correcting: a dead lord's settlement re-points to the new highest-status heir")
	var daimyo: L5RCharacterData = _mkc(1, "Crab", "Hida", 6.0)
	var heir: L5RCharacterData = _mkc(2, "Crab", "Hida", 4.0)
	var by_id: Dictionary = {1: daimyo, 2: heir}
	var p: ProvinceData = _mkp(30, "Crab", "Hida")
	var s: SettlementData = _mks(600, 30, Enums.SettlementType.CASTLE)
	_DO._populate_settlement_governance([s], {30: p}, by_id)
	_ok(s.lord_character_id == 1, "living daimyo governs")
	# The daimyo dies; next tick the settlement re-points to the heir.
	daimyo.wounds_taken = 999
	_DO._populate_settlement_governance([s], {30: p}, by_id)
	_ok(s.lord_character_id == 2, "dead daimyo -> re-points to next highest-status (heir)")
	# Both dead -> -1.
	heir.wounds_taken = 999
	_DO._populate_settlement_governance([s], {30: p}, by_id)
	_ok(s.lord_character_id == -1, "all governors dead -> -1")
