extends SceneTree
## Runtime driver for the s57.21 pop-A/pop-B military unification -- Stage 1
## (de-conflict + Company->Legion chain linkage) in WorldBootstrap._create_initial_military.
##
## Before Stage 1 the pass set commanded_unit_id = company_id UNCONDITIONALLY for every rank->=CHUI
## officer, clobbering the legion/section/army pointer the s57.21 generator stamped on every
## Taisa/Shireikan/Rikugunshokan and defeating the T2 vacant-superior gate; companies were never
## linked into a legion (parent_legion_id always -1, constituent_companies always empty); and the
## company id space started at 1, overlapping the unit id space (a company_id could equal a legion_id).
##
## This driver exercises the fixed pass directly:
##   [1] Taisa/Shireikan/Rikugunshokan keep their unit pointer (NOT clobbered), get NO company.
##   [2] Chui-companies are linked into their Taisa's legion (parent_legion_id/parent_section_id +
##       legion.constituent_companies), and company ids live ABOVE every legion id (no collision).
##   [3] A company-tier officer whose superior is NOT a Taisa (garrison/wall) gets an UNLINKED
##       company (parent_legion_id -1) -- graceful, no crash, no regression.
## Run: godot --headless -s tests/verify_military_unification_stage1.gd

const _WB := preload("res://simulation/world_bootstrap.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, rank: int, superior: int, commanded: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.clan = "Crab"
	c.school_type = Enums.SchoolType.BUSHI
	c.military_rank = rank
	c.operational_superior_id = superior
	c.commanded_unit_id = commanded
	return c


func _init() -> void:
	print("--- s57.21 military unification Stage 1 (de-conflict + linkage) ---")
	# Legion 5 under section 3 under army 1 (raw pop-B dicts). Max unit id = 5.
	var legion: Dictionary = {
		"legion_id": 5, "parent_section_id": 3,
		"commander_id": 100, "home_province_id": -1,
		"current_location_id": "", "constituent_companies": [],
	}
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA, -1, 5)       # commands legion 5
	var chui_a: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI, 100, -1)     # under taisa 100
	var chui_b: L5RCharacterData = _mk(102, Enums.MilitaryRank.CHUI, 100, -1)     # under taisa 100
	var shireikan: L5RCharacterData = _mk(103, Enums.MilitaryRank.SHIREIKAN, -1, 3)  # commands section 3
	var rik: L5RCharacterData = _mk(104, Enums.MilitaryRank.RIKUGUNSHOKAN, -1, 1)    # commands army 1
	var garrison: L5RCharacterData = _mk(105, Enums.MilitaryRank.GUNSO, 103, -1)     # under a SHIREIKAN

	var chars: Array = [taisa, chui_a, chui_b, shireikan, rik, garrison]
	var result: Dictionary = _WB._create_initial_military(
		chars, {"Crab": {}}, {}, null, [], [legion],
	)
	var companies: Array = result.get("companies", [])

	print("[1] Taisa/Shireikan/Rikugunshokan pointers NOT clobbered; command no company")
	_ok(taisa.commanded_unit_id == 5, "Taisa keeps legion 5 (was %d)" % taisa.commanded_unit_id)
	_ok(shireikan.commanded_unit_id == 3, "Shireikan keeps section 3 (was %d)" % shireikan.commanded_unit_id)
	_ok(rik.commanded_unit_id == 1, "Rikugunshokan keeps army 1 (was %d)" % rik.commanded_unit_id)
	# Exactly 3 companies: chui_a, chui_b, garrison. T/S/R excluded.
	_ok(companies.size() == 3, "3 companies (chui_a, chui_b, garrison), got %d" % companies.size())
	for co: Dictionary in companies:
		_ok(int(co["commander_id"]) not in [100, 103, 104],
			"no company commanded by Taisa/Shireikan/Rikugunshokan")

	print("[2] Chui-companies linked into the Taisa's legion; ids above every legion id")
	_ok(chui_a.commanded_unit_id > 5, "chui_a company id %d > max legion id 5" % chui_a.commanded_unit_id)
	_ok(chui_b.commanded_unit_id > 5, "chui_b company id %d > max legion id 5" % chui_b.commanded_unit_id)
	_ok(chui_a.commanded_unit_id != chui_b.commanded_unit_id, "distinct company ids")
	var co_a: Dictionary = _find_company(companies, 101)
	var co_b: Dictionary = _find_company(companies, 102)
	_ok(int(co_a.get("parent_legion_id", -99)) == 5, "chui_a company parent_legion_id == 5")
	_ok(int(co_a.get("parent_section_id", -99)) == 3, "chui_a company parent_section_id == 3")
	_ok(int(co_b.get("parent_legion_id", -99)) == 5, "chui_b company parent_legion_id == 5")
	var cc: Array = legion["constituent_companies"]
	_ok(cc.size() == 2, "legion has 2 constituent companies, got %d" % cc.size())
	_ok(chui_a.commanded_unit_id in cc and chui_b.commanded_unit_id in cc,
		"both chui company ids appended to legion.constituent_companies")

	print("[3] garrison company (superior not a Taisa) is UNLINKED, no crash")
	var co_g: Dictionary = _find_company(companies, 105)
	_ok(int(co_g.get("parent_legion_id", -99)) == -1, "garrison company parent_legion_id == -1 (unlinked)")
	_ok(garrison.commanded_unit_id > 5, "garrison still gets a company id above legions")

	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _find_company(companies: Array, commander_id: int) -> Dictionary:
	for co: Dictionary in companies:
		if int(co["commander_id"]) == commander_id:
			return co
	return {}
