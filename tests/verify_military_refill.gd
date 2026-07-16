extends SceneTree
## Runtime driver for s57.21 T3: command-vacancy refill for generated Legion/Section commanders.
## When a generated Taisa (Legion) or Shireikan (Section) dies, the persistent military_legions /
## military_sections raw arrays still name the corpse. T2 made the read-time liveness bake fire the
## vacant-superior GATE; T3 refills the slot so it is not leaderless forever. The refill reuses the
## LOCKED promotion machinery -- its TAISA/SHIREIKAN eligibility reads battles_as_chui / battles_as_taisa
## from the now-live s11.7a battle_record (Commit A). This driver exercises _process_military_command_refill
## + _apply_command_refill_results: a dead Taisa's Legion is refilled by the best eligible uncommanded
## officer (battle_skill >= 4 AND battles_as_chui >= 1); the new commander inherits the dead predecessor's
## slot (commanded_unit_id / operational_superior_id / role_position); the raw unit's commander_id is
## rewritten; a live commander is untouched; no eligible/no-battle-record candidate leaves the slot vacant
## (graceful); no candidate is double-claimed in one pass; and a Shireikan seat requires battles_as_taisa >= 2.
## Run: godot --headless -s tests/verify_military_refill.gd

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


# A commander with a filled slot (rank + unit + superior + role).
func _mk_cmd(id: int, rank: int, unit_id: int, superior: int, role: String, dead: bool = false) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = rank
	c.commanded_unit_id = unit_id
	c.operational_superior_id = superior
	c.role_position = role
	c.wounds_taken = 9999 if dead else 0
	return c


# An uncommanded officer candidate: military_rank below the vacancy, no command, Battle skill +
# a REAL battle_record (battles_as_chui for a Taisa seat, battles_as_taisa for a Shireikan seat).
# battle_record is now a declared field (Commit A), so the test can seed it directly.
func _mk_cand(id: int, battle_skill: int, battles_as_chui: int = 0, battles_as_taisa: int = 0) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = Enums.MilitaryRank.CHUI
	c.commanded_unit_id = -1
	c.skills = {"Battle": battle_skill}
	c.battle_record = {
		"battles_fought": battles_as_chui + battles_as_taisa,
		"battles_won": 0,
		"battles_lost": 0,
		"companies_destroyed_under_command": 0,
		"battles_as_chui": battles_as_chui,
		"battles_as_taisa": battles_as_taisa,
	}
	c.wounds_taken = 0
	return c


func _init() -> void:
	print("--- s57.21 T3 command-vacancy refill ---")
	_test_dead_taisa_refilled()
	_test_live_taisa_untouched()
	_test_no_battle_record_stays_vacant()
	_test_no_double_claim()
	_test_shireikan_needs_battle_tested_taisa()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_dead_taisa_refilled() -> void:
	print("[1] dead Taisa -> Legion refilled by best eligible officer, slot inherited")
	# Legion 20 under Section 10 (Shireikan 100). Taisa 200 (dead), role "Taisa".
	var dead_taisa: L5RCharacterData = _mk_cmd(200, Enums.MilitaryRank.TAISA, 20, 100, "Taisa", true)
	# Two eligible candidates (both Battle >= 4, battles_as_chui >= 1); 301 has higher Battle -> selected.
	var cand_a: L5RCharacterData = _mk_cand(300, 4, 1)
	var cand_b: L5RCharacterData = _mk_cand(301, 6, 2)
	var chars: Dictionary = {200: dead_taisa, 300: cand_a, 301: cand_b}
	var legions_raw: Array = [{
		"legion_id": 20, "parent_section_id": 10, "commander_id": 200,
		"constituent_companies": [],
	}]
	var sections_raw: Array = []
	var results: Array = _DO._process_military_command_refill(legions_raw, sections_raw, chars)
	_ok(results.size() == 1, "one refill result for the dead-Taisa legion")
	if results.size() == 1:
		var r: Dictionary = results[0]
		_ok(r.get("new_commander_id", -1) == 301, "best-Battle candidate (301) selected")
		_ok(r.get("operational_superior_id", -1) == 100, "inherits dead predecessor's superior (Shireikan 100)")
		_ok(r.get("role_position", "") == "Taisa", "inherits dead predecessor's role (Taisa)")
	_DO._apply_command_refill_results(results, legions_raw, sections_raw, chars)
	_ok((legions_raw[0] as Dictionary).get("commander_id", -1) == 301, "raw legion commander_id rewritten to 301")
	var promoted: L5RCharacterData = chars[301]
	_ok(promoted.military_rank == Enums.MilitaryRank.TAISA, "new commander is now a Taisa")
	_ok(promoted.commanded_unit_id == 20, "new commander commands legion 20")
	_ok(promoted.operational_superior_id == 100, "new commander op_superior = Shireikan 100")
	_ok(promoted.role_position == "Taisa", "new commander role_position = Taisa")
	_ok((chars[300] as L5RCharacterData).commanded_unit_id == -1, "non-selected candidate stays uncommanded")


func _test_live_taisa_untouched() -> void:
	print("[2] living Taisa -> no refill (slot occupied)")
	var live_taisa: L5RCharacterData = _mk_cmd(200, Enums.MilitaryRank.TAISA, 20, 100, "Taisa", false)
	var cand: L5RCharacterData = _mk_cand(300, 6, 2)
	var chars: Dictionary = {200: live_taisa, 300: cand}
	var legions_raw: Array = [{
		"legion_id": 20, "parent_section_id": 10, "commander_id": 200,
		"constituent_companies": [],
	}]
	var results: Array = _DO._process_military_command_refill(legions_raw, [], chars)
	_ok(results.is_empty(), "living commander -> no vacancy, no refill")
	_ok((chars[300] as L5RCharacterData).commanded_unit_id == -1, "candidate not drafted for an occupied slot")


func _test_no_battle_record_stays_vacant() -> void:
	print("[3] dead Taisa, candidate has NO battle record -> slot stays vacant (graceful)")
	var dead_taisa: L5RCharacterData = _mk_cmd(200, Enums.MilitaryRank.TAISA, 20, 100, "Taisa", true)
	# Candidate has Battle 4 but ZERO battles_as_chui -> is_eligible_for_taisa fails (the phantom-era state).
	var green: L5RCharacterData = _mk_cand(300, 4, 0)
	var chars: Dictionary = {200: dead_taisa, 300: green}
	var legions_raw: Array = [{
		"legion_id": 20, "parent_section_id": 10, "commander_id": 200,
		"constituent_companies": [],
	}]
	var results: Array = _DO._process_military_command_refill(legions_raw, [], chars)
	_ok(results.is_empty(), "no battle-tested officer -> no refill result")
	_DO._apply_command_refill_results(results, legions_raw, [], chars)
	_ok((legions_raw[0] as Dictionary).get("commander_id", -1) == 200, "raw legion unchanged (still names corpse; liveness bake vacates at read time)")


func _test_no_double_claim() -> void:
	print("[4] two vacant legions, one candidate -> claimed once, not double-assigned")
	var dead_a: L5RCharacterData = _mk_cmd(200, Enums.MilitaryRank.TAISA, 20, 100, "Taisa", true)
	var dead_b: L5RCharacterData = _mk_cmd(201, Enums.MilitaryRank.TAISA, 21, 100, "Taisa", true)
	var only_cand: L5RCharacterData = _mk_cand(300, 6, 2)
	var chars: Dictionary = {200: dead_a, 201: dead_b, 300: only_cand}
	var legions_raw: Array = [
		{"legion_id": 20, "parent_section_id": 10, "commander_id": 200, "constituent_companies": []},
		{"legion_id": 21, "parent_section_id": 10, "commander_id": 201, "constituent_companies": []},
	]
	var results: Array = _DO._process_military_command_refill(legions_raw, [], chars)
	_ok(results.size() == 1, "single candidate fills exactly one of the two vacancies")
	var filled: int = int((results[0] as Dictionary).get("unit_id", -1))
	_ok(filled == 20 or filled == 21, "the filled legion is one of the two vacant ones")


func _test_shireikan_needs_battle_tested_taisa() -> void:
	print("[5] dead Shireikan -> Section refill requires battles_as_taisa >= 2 (LOCKED)")
	var dead_shi: L5RCharacterData = _mk_cmd(100, Enums.MilitaryRank.SHIREIKAN, 10, 5, "Shireikan", true)
	# Battle 5 but only 1 battle_as_taisa -> is_eligible_for_shireikan fails.
	var underqual: L5RCharacterData = _mk_cand(300, 5, 3, 1)
	# Battle 5 and 2 battles_as_taisa -> eligible.
	var qual: L5RCharacterData = _mk_cand(301, 5, 3, 2)
	var chars_under: Dictionary = {100: dead_shi, 300: underqual}
	var sections_raw_u: Array = [{
		"section_id": 10, "parent_army_id": 1, "commander_id": 100, "constituent_legions": [],
	}]
	var r_under: Array = _DO._process_military_command_refill([], sections_raw_u, chars_under)
	_ok(r_under.is_empty(), "under-qualified (battles_as_taisa 1) -> Section stays vacant")
	var dead_shi2: L5RCharacterData = _mk_cmd(100, Enums.MilitaryRank.SHIREIKAN, 10, 5, "Shireikan", true)
	var chars_qual: Dictionary = {100: dead_shi2, 301: qual}
	var sections_raw_q: Array = [{
		"section_id": 10, "parent_army_id": 1, "commander_id": 100, "constituent_legions": [],
	}]
	var r_qual: Array = _DO._process_military_command_refill([], sections_raw_q, chars_qual)
	_ok(r_qual.size() == 1, "qualified Taisa-experienced officer fills the Shireikan seat")
	if r_qual.size() == 1:
		_ok((r_qual[0] as Dictionary).get("new_commander_id", -1) == 301, "qualified candidate (301) selected")
		_ok((r_qual[0] as Dictionary).get("operational_superior_id", -1) == 5, "inherits dead Shireikan's superior (Rikugunshokan 5)")
	_DO._apply_command_refill_results(r_qual, [], sections_raw_q, chars_qual)
	_ok((sections_raw_q[0] as Dictionary).get("commander_id", -1) == 301, "raw section commander_id rewritten to 301")
	_ok((chars_qual[301] as L5RCharacterData).military_rank == Enums.MilitaryRank.SHIREIKAN, "new commander is now a Shireikan")
