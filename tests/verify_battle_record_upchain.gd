extends SceneTree
## Runtime driver for s57.21 military unification Stage 2a: up-chain battle_record credit.
## Before Stage 2, _record_side_participation credited ONLY the direct company commander (Chui/Gunso),
## so a Taisa (who commands a legion, never a company) could never accrue battles_as_taisa -- leaving
## the s11.7 Shireikan-eligibility rung (battles_as_taisa >= 2) permanently unreachable. Stage 2a walks
## the linked chain (company.parent_legion_id -> legion.commander_id [Taisa] -> legion.parent_section_id
## -> section.commander_id [Shireikan]) and credits each with one battle per engagement at their own rank.
##
## Exercises the REAL DayOrchestrator._record_battle_participation:
##   [1] company Chui + up-chain Taisa (battles_as_taisa) + Shireikan (battles_fought) all credited;
##       the Taisa is credited ONCE despite two of their companies fighting (per-engagement dedup).
##   [2] accumulation across two engagements reaches battles_as_taisa == 2 (Shireikan-eligibility rung).
##   [3] loss recorded as battles_lost up the chain; win/loss keyed off the side outcome.
##   [4] backward-compat: empty legion/section arrays -> company-commander-only (Taisa/Shireikan untouched).
##   [5] dead up-chain Taisa skipped without blocking the Shireikan credit; no crash.
## Run: godot --headless -s tests/verify_battle_record_upchain.gd

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


func _mk(id: int, rank: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = rank
	c.wounds_taken = 0
	c.battle_record = {}
	return c


func _br(c: L5RCharacterData, key: String) -> int:
	return int((c.battle_record as Dictionary).get(key, -999))


func _legion() -> Dictionary:
	return {"legion_id": 5, "parent_section_id": 3, "commander_id": 100, "constituent_companies": [201, 202]}


func _section() -> Dictionary:
	return {"section_id": 3, "parent_army_id": 1, "commander_id": 103, "constituent_legions": [5]}


func _companies() -> Array:
	return [
		{"company_id": 201, "commander_id": 101, "parent_legion_id": 5, "parent_section_id": 3},
		{"company_id": 202, "commander_id": 102, "parent_legion_id": 5, "parent_section_id": 3},
	]


func _init() -> void:
	print("--- s57.21 Stage 2a: up-chain battle_record credit ---")
	_test_upchain_credit_and_dedup()
	_test_accumulation()
	_test_loss()
	_test_backward_compat()
	_test_dead_taisa()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_upchain_credit_and_dedup() -> void:
	print("[1] Chui + up-chain Taisa (battles_as_taisa) + Shireikan credited; Taisa deduped per engagement")
	var chui_a: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI)
	var chui_b: L5RCharacterData = _mk(102, Enums.MilitaryRank.CHUI)
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA)
	var shi: L5RCharacterData = _mk(103, Enums.MilitaryRank.SHIREIKAN)
	var cbi: Dictionary = {101: chui_a, 102: chui_b, 100: taisa, 103: shi}
	_DO._record_battle_participation(
		{"victor": "attacker"}, _companies(), [], cbi, 90, [_legion()], [_section()],
	)
	_ok(_br(chui_a, "battles_as_chui") == 1 and _br(chui_a, "battles_won") == 1, "chui_a: chui+won")
	_ok(_br(chui_b, "battles_as_chui") == 1, "chui_b: chui")
	# Taisa credited ONCE across both companies in their legion.
	_ok(_br(taisa, "battles_fought") == 1, "Taisa battles_fought == 1 (deduped, not 2)")
	_ok(_br(taisa, "battles_as_taisa") == 1, "Taisa battles_as_taisa == 1")
	_ok(_br(taisa, "battles_won") == 1, "Taisa won (attacker side)")
	# Shireikan credited once, battles_fought only (no per-rank counter for SHIREIKAN).
	_ok(_br(shi, "battles_fought") == 1, "Shireikan battles_fought == 1")
	_ok(_br(shi, "battles_as_taisa") == 0, "Shireikan has no battles_as_taisa (own rank is SHIREIKAN)")
	_ok(_br(shi, "battles_won") == 1, "Shireikan won")
	_ok(_br(taisa, "last_battle_season") == TimeSystem.get_absolute_season(90), "Taisa last_battle_season stamped")


func _test_accumulation() -> void:
	print("[2] two engagements -> Taisa battles_as_taisa == 2 (Shireikan-eligibility rung)")
	var chui: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI)
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA)
	var shi: L5RCharacterData = _mk(103, Enums.MilitaryRank.SHIREIKAN)
	var cbi: Dictionary = {101: chui, 100: taisa, 103: shi}
	var one_company: Array = [{"company_id": 201, "commander_id": 101, "parent_legion_id": 5}]
	_DO._record_battle_participation({"victor": "attacker"}, one_company, [], cbi, 90, [_legion()], [_section()])
	_DO._record_battle_participation({"victor": "attacker"}, one_company, [], cbi, 180, [_legion()], [_section()])
	_ok(_br(taisa, "battles_as_taisa") == 2, "Taisa battles_as_taisa == 2 after two engagements")
	_ok(MilitaryPromotionSystem.is_eligible_for_shireikan(5, _br(taisa, "battles_as_taisa")),
		"Battle-5 Taisa now clears the Shireikan eligibility gate")


func _test_loss() -> void:
	print("[3] loss recorded up the chain (win/loss keyed off side outcome)")
	var chui: L5RCharacterData = _mk(102, Enums.MilitaryRank.CHUI)
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA)
	var cbi: Dictionary = {102: chui, 100: taisa}
	# defenders lose when victor is attacker.
	var def_company: Array = [{"company_id": 202, "commander_id": 102, "parent_legion_id": 5}]
	_DO._record_battle_participation({"victor": "attacker"}, [], def_company, cbi, 90, [_legion()], [])
	_ok(_br(taisa, "battles_lost") == 1 and _br(taisa, "battles_won") == 0, "Taisa recorded a loss")
	_ok(_br(chui, "battles_lost") == 1, "Chui recorded a loss")


func _test_backward_compat() -> void:
	print("[4] empty legion/section arrays -> company-commander-only (no up-chain)")
	var chui: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI)
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA)
	var cbi: Dictionary = {101: chui, 100: taisa}
	_DO._record_battle_participation({"victor": "attacker"}, _companies(), [], cbi, 90)
	_ok(_br(chui, "battles_as_chui") == 1, "Chui still credited with no arrays")
	_ok((taisa.battle_record as Dictionary).is_empty(), "Taisa UNTOUCHED without legion arrays (backward-compat)")


func _test_dead_taisa() -> void:
	print("[5] dead up-chain Taisa skipped; Shireikan still credited; no crash")
	var chui: L5RCharacterData = _mk(101, Enums.MilitaryRank.CHUI)
	var taisa: L5RCharacterData = _mk(100, Enums.MilitaryRank.TAISA)
	taisa.wounds_taken = 999  # dead
	var shi: L5RCharacterData = _mk(103, Enums.MilitaryRank.SHIREIKAN)
	var cbi: Dictionary = {101: chui, 100: taisa, 103: shi}
	var one_company: Array = [{"company_id": 201, "commander_id": 101, "parent_legion_id": 5}]
	_DO._record_battle_participation({"victor": "attacker"}, one_company, [], cbi, 90, [_legion()], [_section()])
	_ok((taisa.battle_record as Dictionary).is_empty(), "dead Taisa gets no record")
	_ok(_br(shi, "battles_fought") == 1, "Shireikan still credited despite dead Taisa")
	_ok(_br(chui, "battles_as_chui") == 1, "Chui still credited")
