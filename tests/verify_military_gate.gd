extends SceneTree
## Runtime driver for s57.21 T2: the vacant-superior military-order gate. Before this, the Taisa/Shireikan
## gates in ActionExecutor._validate_military_order were dead two ways: (1) military_data.legions/sections
## were never populated (world-gen had no unit Resources), so the gate short-circuited on empty dicts; and
## (2) MilitaryHierarchy.can_legion_coordinate/can_section_initiate_campaign were semantic no-ops
## (commander_id >= 0 -- the acting commander IS the commander, always true). This driver exercises the
## redesigned rule (owner-approved): a Taisa's ORDER_BATTLE/CONDUCT_RAID is blocked when their Legion's
## parent Section has NO living Shireikan; a Shireikan's is blocked when a constituent Legion has no living
## Taisa. Liveness is baked into commander_id (-1 = vacant) by _populate_military_data. Both halves trace to
## LOCKED s57.21.3; both are non-tautological (a Taisa can be alive while their Shireikan is dead).
## Run: godot --headless -s tests/verify_military_gate.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _MH := preload("res://simulation/military_hierarchy.gd")
const _AE := preload("res://simulation/action_executor.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _NDS := preload("res://simulation/npc_data_structures.gd")
const _MUD := preload("res://shared/military_unit_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, rank: int, dead: bool = false) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = rank
	c.wounds_taken = 9999 if dead else 0
	return c


func _ctx(id: int, rank: int, unit_id: int) -> NPCDataStructures.ContextSnapshot:
	var ctx: NPCDataStructures.ContextSnapshot = _NDS.ContextSnapshot.new()
	ctx.character_id = id
	ctx.military_rank = rank
	ctx.commanded_unit_id = unit_id
	ctx.is_lord = false
	return ctx


# Build a small world: 1 Army -> 1 Section (Shireikan 100) -> 2 Legions (Taisa 200, 201).
# Section id 10, Legion ids 20, 21.
func _raw() -> Dictionary:
	var sections_raw: Array = [{
		"section_id": 10, "parent_army_id": 1, "commander_id": 100,
		"constituent_legions": [20, 21],
	}]
	var legions_raw: Array = [
		{"legion_id": 20, "parent_section_id": 10, "commander_id": 200, "constituent_companies": []},
		{"legion_id": 21, "parent_section_id": 10, "commander_id": 201, "constituent_companies": []},
	]
	return {"sections": sections_raw, "legions": legions_raw}


func _md(chars_by_id: Dictionary) -> Dictionary:
	var raw: Dictionary = _raw()
	var military_data: Dictionary = {}
	_DO._populate_military_data(military_data, [], raw["legions"], raw["sections"], chars_by_id)
	return military_data


func _init() -> void:
	print("--- s57.21 T2 vacant-superior military-order gate ---")
	_test_populate_liveness()
	_test_arbiters()
	_test_taisa_gate()
	_test_shireikan_gate()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_populate_liveness() -> void:
	print("[1] _populate_military_data bakes liveness into commander_id (-1 = vacant)")
	var shi: L5RCharacterData = _mk(100, Enums.MilitaryRank.SHIREIKAN)
	var t20: L5RCharacterData = _mk(200, Enums.MilitaryRank.TAISA)
	var t21_dead: L5RCharacterData = _mk(201, Enums.MilitaryRank.TAISA, true)
	var chars: Dictionary = {100: shi, 200: t20, 201: t21_dead}
	var md: Dictionary = _md(chars)
	var legions: Dictionary = md["legions"]
	var sections: Dictionary = md["sections"]
	_ok(sections[10].commander_id == 100, "living Shireikan -> section commander_id kept")
	_ok(legions[20].commander_id == 200, "living Taisa -> legion commander_id kept")
	_ok(legions[21].commander_id == -1, "DEAD Taisa -> legion commander_id vacated to -1")
	# Missing commander (not in chars) also vacates.
	var md2: Dictionary = _md({100: shi, 200: t20})  # 201 missing
	_ok((md2["legions"] as Dictionary)[21].commander_id == -1, "missing commander -> vacated to -1")
	# Empty characters_by_id leaves ids intact (graceful, no liveness).
	var md3: Dictionary = _md({})
	_ok((md3["legions"] as Dictionary)[21].commander_id == 201, "empty chars map -> ids intact (graceful)")


func _test_arbiters() -> void:
	print("[2] arbiters: parent-Section-Shireikan / constituent-Legion-Taisa liveness")
	# All alive.
	var chars: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA),
	}
	var md: Dictionary = _md(chars)
	var legions: Dictionary = md["legions"]
	var sections: Dictionary = md["sections"]
	_ok(_MH.can_legion_coordinate(legions[20], sections), "legion coordinates: living Shireikan above")
	_ok(_MH.can_section_initiate_campaign(sections[10], legions), "section campaigns: all Taisa living")
	# Shireikan dead -> legion cannot coordinate.
	var chars_shi_dead: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN, true),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA),
	}
	var md_sd: Dictionary = _md(chars_shi_dead)
	_ok(not _MH.can_legion_coordinate((md_sd["legions"] as Dictionary)[20], md_sd["sections"]),
		"Shireikan dead -> legion CANNOT coordinate (vacant superior)")
	# One subordinate Taisa dead -> section cannot initiate campaign.
	var chars_t_dead: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA, true),
	}
	var md_td: Dictionary = _md(chars_t_dead)
	_ok(not _MH.can_section_initiate_campaign((md_td["sections"] as Dictionary)[10], md_td["legions"]),
		"a subordinate Taisa dead -> section CANNOT initiate campaign")
	# Graceful: unresolvable parent section -> not blocked.
	var orphan_legion: MilitaryUnitData.LegionData = _MUD.LegionData.new()
	orphan_legion.parent_section_id = 999
	_ok(_MH.can_legion_coordinate(orphan_legion, sections), "unresolvable parent section -> not blocked")


func _test_taisa_gate() -> void:
	print("[3] _validate_military_order: Taisa ORDER_BATTLE blocked when Shireikan vacant")
	# Living Shireikan -> valid.
	var chars: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA),
	}
	var md: Dictionary = _md(chars)
	var ctx_taisa: NPCDataStructures.ContextSnapshot = _ctx(200, Enums.MilitaryRank.TAISA, 20)  # commands legion 20
	var r_ok: Dictionary = _AE._validate_military_order("ORDER_BATTLE", ctx_taisa, md)
	_ok(r_ok.get("valid", false), "living Shireikan -> Taisa ORDER_BATTLE valid")
	# Dead Shireikan -> blocked.
	var chars_sd: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN, true),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA),
	}
	var md_sd: Dictionary = _md(chars_sd)
	var r_block: Dictionary = _AE._validate_military_order("ORDER_BATTLE", ctx_taisa, md_sd)
	_ok(not r_block.get("valid", true), "dead Shireikan -> Taisa ORDER_BATTLE blocked")
	_ok(r_block.get("reason", "") == "legion_superior_vacant", "block reason == legion_superior_vacant")
	# A non-battle action is NOT blocked even with vacant superior.
	var r_admin: Dictionary = _AE._validate_military_order("ASSIGN_GARRISON", ctx_taisa, md_sd)
	_ok(r_admin.get("valid", false), "ASSIGN_GARRISON not blocked by vacant superior (only battle/raid)")
	# CONDUCT_RAID also blocked.
	var r_raid: Dictionary = _AE._validate_military_order("CONDUCT_RAID", ctx_taisa, md_sd)
	_ok(not r_raid.get("valid", true), "CONDUCT_RAID blocked with vacant Shireikan")


func _test_shireikan_gate() -> void:
	print("[4] _validate_military_order: Shireikan ORDER_BATTLE blocked when a subordinate Taisa vacant")
	var ctx_shi: NPCDataStructures.ContextSnapshot = _ctx(100, Enums.MilitaryRank.SHIREIKAN, 10)  # commands section 10
	# All Taisa alive -> valid.
	var chars: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA),
	}
	var md: Dictionary = _md(chars)
	_ok(_AE._validate_military_order("ORDER_BATTLE", ctx_shi, md).get("valid", false),
		"all subordinate Taisa alive -> Shireikan ORDER_BATTLE valid")
	# One subordinate Taisa dead -> blocked.
	var chars_td: Dictionary = {
		100: _mk(100, Enums.MilitaryRank.SHIREIKAN),
		200: _mk(200, Enums.MilitaryRank.TAISA),
		201: _mk(201, Enums.MilitaryRank.TAISA, true),
	}
	var md_td: Dictionary = _md(chars_td)
	var r_block: Dictionary = _AE._validate_military_order("ORDER_BATTLE", ctx_shi, md_td)
	_ok(not r_block.get("valid", true), "a subordinate Taisa dead -> Shireikan ORDER_BATTLE blocked")
	_ok(r_block.get("reason", "") == "section_legion_vacant", "block reason == section_legion_vacant")
	# Empty military_data (pre-T1 / no hierarchy) -> not blocked (graceful, no regression).
	_ok(_AE._validate_military_order("ORDER_BATTLE", ctx_shi, {}).get("valid", false),
		"empty military_data -> not blocked (graceful)")
