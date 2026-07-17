extends SceneTree
## Runtime driver for s57.21 military unification Stage 2b: promotion-from-within.
## Before Stage 2b the _gather_promotion_candidates filter `if commanded_unit_id >= 0: continue`
## EXCLUDED every serving officer, so a serving Chui could never be a Taisa candidate and a serving
## Taisa could never be a Shireikan candidate -- contra LOCKED s11.7 line 311 ("Candidates: Chui
## currently serving in the Go-hatamoto"). Stage 2b relaxes the filter on the refill path (Legion/
## Section) via admit_serving, and vacates a promoted officer's OLD unit so the cascade refills it.
##
## Exercises the REAL DayOrchestrator statics:
##   [1] admit_serving gating: a serving officer is excluded with admit_serving=false (the CHUI
##       company path, zero regression), admitted with admit_serving=true (the refill path).
##   [2] _vacate_unit_command clears the right tier's commander_id and leaves others untouched.
##   [3] end-to-end _process_military_command_refill + _apply_command_refill_results: a serving Chui
##       fills a vacant Legion (Taisa seat) and their old company is vacated; a serving Taisa fills a
##       vacant Section (Shireikan seat) and their old legion is vacated -- shared `claimed` dedup holds.
##   [4] the promoted officer inherits the dead predecessor's slot (op_superior + role) and the raw
##       units are rewritten so the next tick's liveness bake keeps the new commander.
##   [5] an ineligible serving officer (no battle_record) leaves the seat vacant + their command intact.
## Run: godot --headless -s tests/verify_military_unification_stage2b.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, rank: int, battle: int, br: Dictionary, cmd_unit: int, dead: bool = false) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = rank
	c.commanded_unit_id = cmd_unit
	c.skills = {"Battle": battle}
	c.battle_record = br
	c.wounds_taken = 999 if dead else 0
	c.operational_superior_id = -1
	c.role_position = ""
	return c


func _init() -> void:
	print("--- s57.21 Stage 2b: promotion-from-within ---")
	_test_admit_serving_gate()
	_test_vacate_helper()
	_test_refill_from_within()
	_test_ineligible_leaves_vacant()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_admit_serving_gate() -> void:
	print("[1] admit_serving gate: serving officer excluded (false) / admitted (true)")
	var chui: L5RCharacterData = _mk(
		101, Enums.MilitaryRank.CHUI, 4, {"battles_fought": 1, "battles_as_chui": 1}, 201)
	var cbi: Dictionary = {101: chui}
	var vac: Dictionary = {"unit_id": 5, "rank_needed": Enums.MilitaryRank.TAISA}
	var no_serve: Array = _DO._gather_promotion_candidates(vac, cbi)  # default admit_serving=false
	var with_serve: Array = _DO._gather_promotion_candidates(vac, cbi, true)
	_ok(no_serve.is_empty(), "serving Chui EXCLUDED with admit_serving=false (CHUI company path)")
	_ok(with_serve.size() == 1 and int(with_serve[0]["character_id"]) == 101,
		"serving Chui ADMITTED with admit_serving=true (refill path)")
	# The candidate carries the battle counters select_best_candidate's eligibility reads.
	if with_serve.size() == 1:
		_ok(int(with_serve[0].get("battles_as_chui", -1)) == 1, "candidate carries battles_as_chui")
	# A same-rank officer is still excluded (military_rank >= rank_needed) even with admit_serving.
	var taisa: L5RCharacterData = _mk(
		100, Enums.MilitaryRank.TAISA, 5, {"battles_fought": 2, "battles_as_taisa": 2}, 5)
	var also: Array = _DO._gather_promotion_candidates(vac, {100: taisa}, true)
	_ok(also.is_empty(), "same-rank Taisa excluded from a Taisa vacancy (rank filter still applies)")


func _test_vacate_helper() -> void:
	print("[2] _vacate_unit_command clears the right tier only")
	var companies: Array = [{"company_id": 201, "commander_id": 101}, {"company_id": 202, "commander_id": 102}]
	var legions: Array = [{"legion_id": 5, "commander_id": 100}, {"legion_id": 6, "commander_id": 99}]
	var sections: Array = [{"section_id": 3, "commander_id": 103}]
	_DO._vacate_unit_command(201, companies, legions, sections)
	_ok(int(companies[0]["commander_id"]) == -1, "company 201 vacated")
	_ok(int(companies[1]["commander_id"]) == 102, "company 202 untouched")
	_ok(int(legions[0]["commander_id"]) == 100 and int(legions[1]["commander_id"]) == 99, "legions untouched")
	_DO._vacate_unit_command(6, companies, legions, sections)
	_ok(int(legions[1]["commander_id"]) == -1, "legion 6 vacated")
	_ok(int(legions[0]["commander_id"]) == 100, "legion 5 untouched")
	_DO._vacate_unit_command(3, companies, legions, sections)
	_ok(int(sections[0]["commander_id"]) == -1, "section 3 vacated")
	# unknown id is a graceful no-op.
	_DO._vacate_unit_command(9999, companies, legions, sections)
	_ok(true, "unknown id vacate is a no-op (no crash)")


func _test_refill_from_within() -> void:
	print("[3] end-to-end: serving Chui->Taisa (vacates company) + serving Taisa->Shireikan (vacates legion)")
	# Vacant Legion 5 (dead Taisa 100, superior=Shireikan 103); vacant Section 3 (dead Shireikan 103,
	# superior=Rikugunshokan 110). Serving Chui X (id 101, commands company 201). Serving Taisa Y
	# (id 102, commands legion 6). Both battle-tested so they clear the LOCKED eligibility gates.
	var dead_taisa: L5RCharacterData = _mk(
		100, Enums.MilitaryRank.TAISA, 5, {"battles_fought": 3, "battles_as_taisa": 3}, 5, true)
	dead_taisa.operational_superior_id = 103
	dead_taisa.role_position = "Legion Commander"
	var dead_shi: L5RCharacterData = _mk(
		103, Enums.MilitaryRank.SHIREIKAN, 5, {"battles_fought": 4}, 3, true)
	dead_shi.operational_superior_id = 110
	dead_shi.role_position = "Section Commander"
	var chui_x: L5RCharacterData = _mk(
		101, Enums.MilitaryRank.CHUI, 4, {"battles_fought": 1, "battles_as_chui": 1}, 201)
	var taisa_y: L5RCharacterData = _mk(
		102, Enums.MilitaryRank.TAISA, 5, {"battles_fought": 2, "battles_as_taisa": 2}, 6)
	var cbi: Dictionary = {100: dead_taisa, 103: dead_shi, 101: chui_x, 102: taisa_y}

	var legions: Array = [{"legion_id": 5, "parent_section_id": 3, "commander_id": 100}, {"legion_id": 6, "commander_id": 102}]
	var sections: Array = [{"section_id": 3, "parent_army_id": 1, "commander_id": 103}]
	var companies: Array = [{"company_id": 201, "commander_id": 101}]

	var results: Array = _DO._process_military_command_refill(legions, sections, cbi)
	_DO._apply_command_refill_results(results, legions, sections, cbi, companies)

	# Chui X promoted into vacant Legion 5 (Taisa seat), inheriting the dead Taisa's slot.
	_ok(chui_x.military_rank == Enums.MilitaryRank.TAISA, "X promoted to Taisa")
	_ok(chui_x.commanded_unit_id == 5, "X now commands legion 5")
	_ok(chui_x.operational_superior_id == 103, "X inherits the dead Taisa's Shireikan superior")
	_ok(chui_x.role_position == "Legion Commander", "X inherits the Legion Commander role")
	_ok(int(companies[0]["commander_id"]) == -1, "X's OLD company 201 vacated (cascade)")
	_ok(int(legions[0]["commander_id"]) == 101, "legion 5 raw rewritten to X")

	# Taisa Y promoted into vacant Section 3 (Shireikan seat), inheriting the dead Shireikan's slot.
	_ok(taisa_y.military_rank == Enums.MilitaryRank.SHIREIKAN, "Y promoted to Shireikan")
	_ok(taisa_y.commanded_unit_id == 3, "Y now commands section 3")
	_ok(taisa_y.operational_superior_id == 110, "Y inherits the dead Shireikan's Rikugunshokan superior")
	_ok(taisa_y.role_position == "Section Commander", "Y inherits the Section Commander role")
	_ok(int(legions[1]["commander_id"]) == -1, "Y's OLD legion 6 vacated (cascade)")
	_ok(int(sections[0]["commander_id"]) == 102, "section 3 raw rewritten to Y")


func _test_ineligible_leaves_vacant() -> void:
	print("[4] ineligible serving officer (no battle_record) -> seat stays vacant, command intact")
	var dead_taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA, 5, {}, 5, true)
	# Chui with Battle 4 but NO battles_as_chui -> fails is_eligible_for_taisa (battles_as_chui < 1).
	var chui: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI, 4, {"battles_fought": 0}, 201)
	var cbi: Dictionary = {100: dead_taisa, 101: chui}
	var legions: Array = [{"legion_id": 5, "commander_id": 100}]
	var companies: Array = [{"company_id": 201, "commander_id": 101}]
	var results: Array = _DO._process_military_command_refill(legions, [], cbi)
	_DO._apply_command_refill_results(results, legions, [], cbi, companies)
	_ok(results.is_empty(), "no refill produced (Chui fails battles_as_chui gate)")
	_ok(chui.military_rank == Enums.MilitaryRank.CHUI, "ineligible Chui unchanged")
	_ok(chui.commanded_unit_id == 201, "ineligible Chui keeps their company")
	_ok(int(companies[0]["commander_id"]) == 101, "company 201 NOT vacated")
	# The raw legion still names the corpse (the read-time liveness bake vacates it at gate time).
	_ok(int(legions[0]["commander_id"]) == 100, "vacant legion still names the dead Taisa (bake vacates at read)")
