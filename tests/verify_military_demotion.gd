extends SceneTree
## Runtime driver for wiring the military demotion-for-disposition arbiter (s11.7, LOCKED:
## "A commander whose disposition toward their appointing lord drops below -10 may be replaced
## for political reasons. Removal clears military_rank and commanded_unit_id... they lose 0.5
## Glory."). The sibling promotion arbiters run live every season, but
## MilitaryPromotionSystem.should_remove_for_disposition + apply_demotion had ZERO production
## callers -- so a commander who came to loathe their lord kept command forever.
## Verifies _process_military_demotions (decision, threshold -10 via the arbiter) and
## _apply_demotion_results (clears rank/command, -0.5 Glory, vacates the Company, KEEPS the
## feudal role_position/lord_id).
## Run: godot --headless -s tests/verify_military_demotion.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _commander(cid: int, lord_id: int, disp_toward_lord: int, glory: float = 4.0,
		role: String = "") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "Cmd%d" % cid
	c.lord_id = lord_id
	c.military_rank = Enums.MilitaryRank.CHUI
	c.commanded_unit_id = 100 + cid
	c.glory = glory
	c.role_position = role
	c.disposition_values = {lord_id: disp_toward_lord}
	return c


func _company(company_id: int, commander_id: int) -> Dictionary:
	return {"company_id": company_id, "commander_id": commander_id}


func _init() -> void:
	print("--- Military Demotion for Disposition (s11.7) ---")
	_test_decision_threshold()
	_test_application()
	_test_feudal_position_kept()
	_test_guards()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_decision_threshold() -> void:
	print("[1] decision: disposition < -10 -> demotion")
	# -11 (below threshold) -> flagged; -10 (at threshold, not below) -> kept.
	var loathes := _commander(1, 9, -11)
	var borderline := _commander(2, 9, -10)
	var loyal := _commander(3, 9, 40)
	var by_id: Dictionary = {1: loathes, 2: borderline, 3: loyal}
	var companies: Array = [_company(101, 1), _company(102, 2), _company(103, 3)]
	var results: Array = _DO._process_military_demotions(companies, by_id)
	var flagged: Dictionary = {}
	for r_v: Variant in results:
		flagged[(r_v as Dictionary).get("commander_id", -1)] = true
	_ok(flagged.has(1), "disp -11 -> demoted")
	_ok(not flagged.has(2), "disp -10 (at threshold, not below) -> kept")
	_ok(not flagged.has(3), "disp +40 (loyal) -> kept")
	_ok(results.size() == 1, "exactly one demotion flagged")


func _test_application() -> void:
	print("[2] application: clears rank/command, -0.5 Glory, vacates Company")
	var cmd := _commander(1, 9, -20, 4.0)
	var by_id: Dictionary = {1: cmd}
	var companies: Array = [_company(101, 1)]
	var demotions: Array = _DO._process_military_demotions(companies, by_id)
	_DO._apply_demotion_results(demotions, by_id, companies)
	_ok(cmd.military_rank == Enums.MilitaryRank.NONE, "military_rank cleared to NONE")
	_ok(cmd.commanded_unit_id == -1, "commanded_unit_id cleared to -1")
	_ok(abs(cmd.glory - 3.5) < 0.001, "Glory 4.0 -> 3.5 (-0.5 via apply_demotion)")
	_ok((companies[0] as Dictionary).get("commander_id", -99) == -1, "Company vacated (commander_id -1)")


func _test_feudal_position_kept() -> void:
	print("[3] a removed Rikugunshokan who is also a Family Daimyo keeps their feudal position")
	var daimyo_general := _commander(1, 9, -30, 5.0, RoleRegistry.FAMILY_DAIMYO)
	daimyo_general.military_rank = Enums.MilitaryRank.RIKUGUNSHOKAN
	var by_id: Dictionary = {1: daimyo_general}
	var companies: Array = [_company(101, 1)]
	var demotions: Array = _DO._process_military_demotions(companies, by_id)
	_DO._apply_demotion_results(demotions, by_id, companies)
	_ok(daimyo_general.military_rank == Enums.MilitaryRank.NONE, "military authority lost (rank NONE)")
	_ok(daimyo_general.role_position == RoleRegistry.FAMILY_DAIMYO, "feudal position RETAINED")
	_ok(daimyo_general.lord_id == 9, "lord_id (feudal bond) retained")


func _test_guards() -> void:
	print("[4] no-op guards")
	# No appointing lord (lord_id -1) -> never demoted even at extreme disposition.
	var lordless := _commander(1, -1, -50)
	lordless.disposition_values = {}
	# Vacant Company (commander_id -1) -> skipped.
	var by_id: Dictionary = {1: lordless}
	var companies: Array = [_company(101, 1), _company(102, -1)]
	var results: Array = _DO._process_military_demotions(companies, by_id)
	_ok(results.is_empty(), "lordless commander + vacant Company -> no demotions")

	# Missing / dead commander -> no crash, no demotion.
	var companies2: Array = [_company(103, 999)]
	var results2: Array = _DO._process_military_demotions(companies2, {})
	_ok(results2.is_empty(), "commander not in characters_by_id -> no demotion")
