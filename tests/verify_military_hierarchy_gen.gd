extends SceneTree
## Runtime driver for s57.21 T1: world-gen instantiation of the military unit hierarchy from the
## generated commanders. Before this, `_generate_military_commanders` created Taisa/Chui characters
## with lord_id only -- no Shireikan tier, no LegionData/SectionData/ArmyData, no operational_superior_id
## and no commanded_unit_id -- so the whole s57.21 unit chain was absent (the Taisa/Shireikan military
## gates could never resolve a unit). This asserts the LOCKED chain integrity of the new output: LOCKED
## army count per clan, exactly SECTIONS_PER_ARMY Shireikan/army and LEGIONS_PER_SECTION (=4, the LOCKED
## range floor) Taisa/section and COMPANIES_PER_LEGION (=7) Chui/legion, no orphan / no skipped level,
## and the person chain (operational_superior_id) MIRRORS the unit chain (parent IDs) per s57.21.3.
## Run: godot --headless -s tests/verify_military_hierarchy_gen.gd

const _WPG := preload("res://simulation/world_population_generator.gd")
const _DICE := preload("res://simulation/dice_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _by_id(chars: Array) -> Dictionary:
	var m: Dictionary = {}
	for c: L5RCharacterData in chars:
		m[c.character_id] = c
	return m


func _init() -> void:
	print("--- s57.21 T1 military unit hierarchy generation ---")
	_test_lion_hierarchy()
	_test_locked_army_counts()
	_test_global_unit_ids_unique()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_lion_hierarchy() -> void:
	print("[1] Lion (4 armies): full chain + person-chain mirrors unit-chain")
	var dice: DiceEngine = _DICE.new(777)
	var next_id: Array = [5000]
	var next_unit_id: Array = [1]
	var rik_id: int = 4999
	var res: Dictionary = _WPG._generate_military_commanders("Lion", rik_id, next_id, dice, next_unit_id)
	var chars: Array = res.get("chars", [])
	var armies: Array = res.get("armies", [])
	var sections: Array = res.get("sections", [])
	var legions: Array = res.get("legions", [])
	var expect_armies: int = _WPG.CLAN_ARMY_COUNT.get("Lion", 0)  # LOCKED = 4
	var expect_sections: int = expect_armies * _WPG.SECTIONS_PER_ARMY
	var expect_legions: int = expect_sections * _WPG.LEGIONS_PER_SECTION
	var expect_chui: int = expect_legions * _WPG.COMPANIES_PER_LEGION
	_ok(armies.size() == expect_armies, "army count == LOCKED Lion count (%d)" % expect_armies)
	_ok(sections.size() == expect_sections, "section count == armies * SECTIONS_PER_ARMY (%d)" % expect_sections)
	_ok(legions.size() == expect_legions, "legion count == sections * LEGIONS_PER_SECTION (%d)" % expect_legions)
	_ok(_WPG.LEGIONS_PER_SECTION == 4, "LEGIONS_PER_SECTION is the LOCKED range floor (4)")
	_ok(_WPG.COMPANIES_PER_LEGION == 7, "COMPANIES_PER_LEGION == 7 (6 regular + 1 reserve)")

	var by_id: Dictionary = _by_id(chars)
	# Count by military rank.
	var n_shi: int = 0
	var n_tai: int = 0
	var n_chu: int = 0
	for c: L5RCharacterData in chars:
		match c.military_rank:
			Enums.MilitaryRank.SHIREIKAN: n_shi += 1
			Enums.MilitaryRank.TAISA: n_tai += 1
			Enums.MilitaryRank.CHUI: n_chu += 1
	_ok(n_shi == expect_sections, "one Shireikan per section (%d)" % expect_sections)
	_ok(n_tai == expect_legions, "one Taisa per legion (%d)" % expect_legions)
	_ok(n_chu == expect_chui, "one Chui per company (%d)" % expect_chui)

	# Unit-chain integrity: every legion -> a real section -> a real army; no orphan, no skipped level.
	var section_by_id: Dictionary = {}
	for s: Dictionary in sections:
		section_by_id[s["section_id"]] = s
	var army_by_id: Dictionary = {}
	for a: Dictionary in armies:
		army_by_id[a["army_id"]] = a
	var all_legions_ok: bool = true
	var person_mirrors_unit: bool = true
	for lg: Dictionary in legions:
		var pid: int = lg["parent_section_id"]
		if not section_by_id.has(pid):
			all_legions_ok = false
			continue
		# Taisa commands this legion; Taisa.commanded_unit_id == legion_id; Taisa.op_superior == section's Shireikan.
		var taisa: L5RCharacterData = by_id.get(lg["commander_id"])
		if taisa == null or taisa.commanded_unit_id != lg["legion_id"]:
			all_legions_ok = false
			continue
		var sec: Dictionary = section_by_id[pid]
		if taisa.operational_superior_id != sec["commander_id"]:
			person_mirrors_unit = false
	_ok(all_legions_ok, "every legion -> real section, Taisa commands it, commanded_unit_id == legion_id")
	_ok(person_mirrors_unit, "Taisa.operational_superior_id == parent section's Shireikan (person mirrors unit)")

	# Section chain: parent_army real, Shireikan commands it + commanded_unit_id == section_id + op_superior == Rikugunshokan.
	var sections_ok: bool = true
	for s2: Dictionary in sections:
		if not army_by_id.has(s2["parent_army_id"]):
			sections_ok = false
			continue
		var shi: L5RCharacterData = by_id.get(s2["commander_id"])
		if shi == null or shi.commanded_unit_id != s2["section_id"]:
			sections_ok = false
			continue
		if shi.operational_superior_id != rik_id:
			sections_ok = false
		# constituent_legions non-empty (LEGIONS_PER_SECTION)
		if s2["constituent_legions"].size() != _WPG.LEGIONS_PER_SECTION:
			sections_ok = false
	_ok(sections_ok, "every section -> real army, Shireikan commands it (commanded_unit_id/op_superior/constituent_legions)")

	# Chui op-superior mirrors: each Chui.operational_superior_id is a real Taisa.
	var chui_ok: bool = true
	for c2: L5RCharacterData in chars:
		if c2.military_rank == Enums.MilitaryRank.CHUI:
			var sup: L5RCharacterData = by_id.get(c2.operational_superior_id)
			if sup == null or sup.military_rank != Enums.MilitaryRank.TAISA:
				chui_ok = false
	_ok(chui_ok, "every Chui.operational_superior_id is a real Taisa")

	# Army: commander is the Rikugunshokan; constituent_sections non-empty.
	var army_ok: bool = true
	for a2: Dictionary in armies:
		if a2["commander_id"] != rik_id or a2["clan_id"] != "Lion":
			army_ok = false
		if a2["constituent_sections"].size() != _WPG.SECTIONS_PER_ARMY:
			army_ok = false
	_ok(army_ok, "every army commanded by the Rikugunshokan + constituent_sections populated")


func _test_locked_army_counts() -> void:
	print("[2] LOCKED per-clan army counts honored")
	var dice: DiceEngine = _DICE.new(101)
	for clan: String in ["Crab", "Crane", "Dragon", "Phoenix", "Scorpion", "Unicorn", "Mantis"]:
		var next_id: Array = [6000]
		var next_unit_id: Array = [1]
		var res: Dictionary = _WPG._generate_military_commanders(clan, 5999, next_id, dice, next_unit_id)
		var expect: int = _WPG.CLAN_ARMY_COUNT.get(clan, 0)
		_ok(res.get("armies", []).size() == expect, "%s -> %d armies (LOCKED)" % [clan, expect])


func _test_global_unit_ids_unique() -> void:
	print("[3] unit ids globally unique across clans (shared counter)")
	var dice: DiceEngine = _DICE.new(55)
	var next_id: Array = [7000]
	var next_unit_id: Array = [1]
	var seen: Dictionary = {}
	var collision: bool = false
	var idkey_of: Dictionary = {"armies": "army_id", "sections": "section_id", "legions": "legion_id"}
	for clan: String in ["Crab", "Lion", "Crane"]:
		var res: Dictionary = _WPG._generate_military_commanders(clan, 6999, next_id, dice, next_unit_id)
		for arr_key: String in ["armies", "sections", "legions"]:
			var idk: String = idkey_of[arr_key]
			for u: Dictionary in res.get(arr_key, []):
				var uid: int = u[idk]
				if seen.has(uid):
					collision = true
				seen[uid] = true
	_ok(not collision, "no unit-id collision across Crab/Lion/Crane with the shared counter")
	_ok(seen.size() > 0, "unit ids were assigned")
