extends SceneTree
## Runtime driver for s57.21 Stage 3: T3-tier (Legion/Section) demotion.
## Before Stage 3, _process_military_demotions iterated `companies` only, so a generated Taisa
## (commands a LEGION) or Shireikan (commands a SECTION) who loathes their appointing lord could
## never be removed -- the top-tier counterpart to the company-tier disposition removal was missing.
## Stage 3 adds _process_military_command_demotions / _apply_command_demotion_results over the raw
## military_legions / military_sections arrays, reusing the canonical apply_demotion arbiter
## (threshold -10, -0.5 Glory), and seeds the just-demoted officers into the refill's `claimed` set
## so a removed commander is not re-appointed into a vacated seat the same season.
##
## Exercises the REAL DayOrchestrator statics:
##   [1] detection: a disloyal Taisa/Shireikan (disp < -10 toward lord) is marked; a loyal one, a
##       lordless one, a dead one, and a vacant unit are all skipped.
##   [2] application: rank/command cleared, -0.5 Glory, raw unit vacated; the Rikugunshokan-who-is-
##       also-a-Family-Daimyo feudal-position carve-out (role_position / lord_id kept).
##   [3] refill pre_claimed exclusion: a demoted officer seeded into pre_claimed is NOT re-selected
##       even when they would otherwise be the best candidate.
##   [4] end-to-end: a disloyal Taisa is demoted -> legion vacated -> the refill (with the demoted
##       officer excluded) appoints a DIFFERENT eligible serving Chui instead.
## Run: godot --headless -s tests/verify_military_command_demotion.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _MPS := preload("res://simulation/military_promotion_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, rank: int, lord_id: int, disp_to_lord: int, cmd_unit: int, dead: bool = false) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = rank
	c.commanded_unit_id = cmd_unit
	c.lord_id = lord_id
	c.disposition_values = {lord_id: disp_to_lord} if lord_id >= 0 else {}
	c.glory = 4.0
	c.skills = {"Battle": 5}
	c.battle_record = {"battles_fought": 3, "battles_as_taisa": 3, "battles_as_chui": 3}
	c.wounds_taken = 999 if dead else 0
	c.operational_superior_id = -1
	c.role_position = ""
	return c


func _init() -> void:
	print("--- s57.21 Stage 3: T3-tier (Legion/Section) demotion ---")
	_test_detection()
	_test_application()
	_test_refill_exclusion()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_detection() -> void:
	print("[1] detection: disloyal Taisa/Shireikan marked; loyal/lordless/dead/vacant skipped")
	var lord: int = 500
	# Disloyal Taisa (disp -11 < -10) commanding legion 5.
	var disloyal_taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA, lord, -11, 5)
	# Loyal Taisa (disp +20) commanding legion 6 -- kept.
	var loyal_taisa: L5RCharacterData = _mk(101, Enums.MilitaryRank.TAISA, lord, 20, 6)
	# Boundary: disp exactly -10 is NOT below threshold -> kept (legion 7).
	var boundary_taisa: L5RCharacterData = _mk(102, Enums.MilitaryRank.TAISA, lord, -10, 7)
	# Lordless Taisa (lord_id -1) -> skipped (no appointing lord), legion 8.
	var lordless_taisa: L5RCharacterData = _mk(103, Enums.MilitaryRank.TAISA, -1, 0, 8)
	# Dead Taisa -> skipped (liveness), legion 9.
	var dead_taisa: L5RCharacterData = _mk(104, Enums.MilitaryRank.TAISA, lord, -50, 9, true)
	# Disloyal Shireikan commanding section 3.
	var disloyal_shi: L5RCharacterData = _mk(105, Enums.MilitaryRank.SHIREIKAN, lord, -30, 3)
	var cbi: Dictionary = {
		100: disloyal_taisa, 101: loyal_taisa, 102: boundary_taisa,
		103: lordless_taisa, 104: dead_taisa, 105: disloyal_shi,
	}
	var legions: Array = [
		{"legion_id": 5, "commander_id": 100}, {"legion_id": 6, "commander_id": 101},
		{"legion_id": 7, "commander_id": 102}, {"legion_id": 8, "commander_id": 103},
		{"legion_id": 9, "commander_id": 104}, {"legion_id": 10, "commander_id": -1},  # already vacant
	]
	var sections: Array = [{"section_id": 3, "commander_id": 105}]
	var results: Array = _DO._process_military_command_demotions(legions, sections, cbi)
	var demoted_ids: Array = []
	for r: Dictionary in results:
		demoted_ids.append(int(r["commander_id"]))
	_ok(100 in demoted_ids, "disloyal Taisa (disp -11) marked")
	_ok(105 in demoted_ids, "disloyal Shireikan (disp -30) marked")
	_ok(not (101 in demoted_ids), "loyal Taisa (disp +20) NOT marked")
	_ok(not (102 in demoted_ids), "boundary Taisa (disp -10, not below) NOT marked")
	_ok(not (103 in demoted_ids), "lordless Taisa NOT marked")
	_ok(not (104 in demoted_ids), "dead Taisa NOT marked")
	_ok(results.size() == 2, "exactly 2 demotions (Taisa 100 + Shireikan 105)")
	# id_key correctly tags tier (legion vs section) for the vacate step.
	for r: Dictionary in results:
		if int(r["commander_id"]) == 100:
			_ok(r.get("id_key", "") == "legion_id" and int(r["unit_id"]) == 5, "Taisa 100 tagged legion 5")
		if int(r["commander_id"]) == 105:
			_ok(r.get("id_key", "") == "section_id" and int(r["unit_id"]) == 3, "Shireikan 105 tagged section 3")


func _test_application() -> void:
	print("[2] application: rank/command cleared, -0.5 Glory, unit vacated, feudal position kept")
	var lord: int = 500
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA, lord, -20, 5)
	taisa.glory = 4.0
	taisa.role_position = "Legion Commander"  # a feudal/role field that must survive
	var shi: L5RCharacterData = _mk(105, Enums.MilitaryRank.SHIREIKAN, lord, -20, 3)
	shi.glory = 6.0
	shi.role_position = "Family Daimyo"  # the Rikugunshokan-is-Family-Daimyo carve-out proxy
	var cbi: Dictionary = {100: taisa, 105: shi}
	var legions: Array = [{"legion_id": 5, "commander_id": 100}]
	var sections: Array = [{"section_id": 3, "commander_id": 105}]
	var demo_results: Array = _DO._process_military_command_demotions(legions, sections, cbi)
	_DO._apply_command_demotion_results(demo_results, cbi, legions, sections)
	_ok(taisa.military_rank == Enums.MilitaryRank.NONE, "Taisa rank cleared to NONE")
	_ok(taisa.commanded_unit_id == -1, "Taisa commanded_unit_id cleared to -1")
	_ok(abs(taisa.glory - 3.5) < 0.001, "Taisa Glory 4.0 -> 3.5 (-0.5)")
	_ok(taisa.role_position == "Legion Commander", "Taisa role_position kept (only military fields cleared)")
	_ok(int(legions[0]["commander_id"]) == -1, "legion 5 vacated (commander_id -> -1)")
	_ok(shi.military_rank == Enums.MilitaryRank.NONE, "Shireikan rank cleared")
	_ok(shi.commanded_unit_id == -1, "Shireikan command cleared")
	_ok(abs(shi.glory - 5.5) < 0.001, "Shireikan Glory 6.0 -> 5.5")
	_ok(shi.role_position == "Family Daimyo", "Shireikan-Daimyo keeps feudal position (carve-out)")
	_ok(int(sections[0]["commander_id"]) == -1, "section 3 vacated")


func _test_refill_exclusion() -> void:
	print("[3] refill pre_claimed excludes a just-demoted officer from re-appointment")
	# Vacant Legion 5 (dead Taisa corpse). A demoted-but-battle-tested Chui 101 (now rank NONE,
	# unit -1) is the ONLY candidate. Without exclusion the refill would re-appoint them; with the
	# pre_claimed seed it must NOT.
	var dead_taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA, 500, -50, 5, true)
	var demoted_chui: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI, 500, -30, -1)
	demoted_chui.battle_record = {"battles_fought": 1, "battles_as_chui": 1}
	var cbi: Dictionary = {100: dead_taisa, 101: demoted_chui}
	var legions: Array = [{"legion_id": 5, "commander_id": 100}]

	# Without exclusion: the demoted Chui IS selected (baseline).
	var r_no_excl: Array = _DO._process_military_command_refill(legions.duplicate(true), [], cbi)
	_ok(r_no_excl.size() == 1 and int(r_no_excl[0]["new_commander_id"]) == 101,
		"baseline (no exclusion): demoted Chui would be selected")

	# With exclusion (pre_claimed seeded): NOT selected -> seat stays vacant this season.
	var r_excl: Array = _DO._process_military_command_refill(legions.duplicate(true), [], cbi, {101: true})
	_ok(r_excl.is_empty(), "with pre_claimed {101}: demoted Chui excluded, seat stays vacant this season")


func _test_end_to_end() -> void:
	print("[4] end-to-end: disloyal Taisa demoted -> legion vacated -> refill appoints a DIFFERENT officer")
	var lord: int = 500
	# Disloyal Taisa 100 commands legion 5 (superior Shireikan 103, role "Legion Commander").
	var disloyal_taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA, lord, -25, 5)
	disloyal_taisa.operational_superior_id = 103
	disloyal_taisa.role_position = "Legion Commander"
	disloyal_taisa.battle_record = {"battles_fought": 5, "battles_as_chui": 5}
	# A loyal battle-tested serving Chui 201 commanding company 301 -- the intended replacement.
	var loyal_chui: L5RCharacterData = _mk(201, Enums.MilitaryRank.CHUI, lord, 30, 301)
	loyal_chui.battle_record = {"battles_fought": 2, "battles_as_chui": 2}
	var cbi: Dictionary = {100: disloyal_taisa, 201: loyal_chui}
	var legions: Array = [{"legion_id": 5, "commander_id": 100}]
	var companies: Array = [{"company_id": 301, "commander_id": 201}]

	# Demote.
	var demo_results: Array = _DO._process_military_command_demotions(legions, [], cbi)
	_DO._apply_command_demotion_results(demo_results, cbi, legions, [])
	_ok(disloyal_taisa.military_rank == Enums.MilitaryRank.NONE, "disloyal Taisa demoted to NONE")
	_ok(int(legions[0]["commander_id"]) == -1, "legion 5 vacated by demotion")

	# Seed the demoted officer + slot-predecessor map and run the refill (mirrors the seasonal wiring).
	var demoted_this_season: Dictionary = {}
	var slot_pred: Dictionary = {}
	for d: Dictionary in demo_results:
		demoted_this_season[int(d["commander_id"])] = true
		slot_pred[int(d["unit_id"])] = int(d["commander_id"])
	var refill: Array = _DO._process_military_command_refill(legions, [], cbi, demoted_this_season, slot_pred)
	_DO._apply_command_refill_results(refill, legions, [], cbi, companies)

	_ok(refill.size() == 1 and int(refill[0]["new_commander_id"]) == 201,
		"loyal serving Chui 201 fills the seat (not the demoted ex-Taisa)")
	_ok(loyal_chui.military_rank == Enums.MilitaryRank.TAISA, "Chui 201 promoted to Taisa")
	_ok(loyal_chui.commanded_unit_id == 5, "Chui 201 now commands legion 5")
	_ok(loyal_chui.operational_superior_id == 103, "inherits the dead-slot Shireikan superior")
	_ok(int(companies[0]["commander_id"]) == -1, "Chui 201's old company 301 vacated (cascade)")
	_ok(disloyal_taisa.commanded_unit_id == -1, "demoted ex-Taisa remains uncommanded this season")
	_ok(int(legions[0]["commander_id"]) == 201, "legion 5 raw rewritten to the loyal Chui")
