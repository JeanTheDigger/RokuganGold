extends SceneTree
## Runtime driver for the s11.7a battle_record producer (owner-approved "Resolve battle_record").
## Before this, battle_record was a PHANTOM: the field did not exist on L5RCharacterData, the factory
## (MilitaryPromotionSystem.create_battle_record) omitted battles_as_chui/battles_as_taisa, and the
## mutator (record_battle) had ZERO production callers -- so every promotion criterion that reads the
## record (CHUI-scoring battles_commanded; TAISA/SHIREIKAN eligibility battles_as_chui/as_taisa) was
## permanently 0. This driver exercises the three-part fix: (1) the factory now seeds all six keys;
## (2) record_battle increments the per-rank counter off the commander's rank at battle time; (3) the
## new _record_battle_participation writes a record for every living participating commander after a
## resolved battle (deduped, won/lost by victor side, dead skipped, pre-existing records accumulate).
## Run: godot --headless -s tests/verify_battle_record.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _MPS := preload("res://simulation/military_promotion_system.gd")
const _CHAR := preload("res://shared/character_data.gd")

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


func _init() -> void:
	print("--- s11.7a battle_record producer ---")
	_test_factory()
	_test_record_by_rank()
	_test_participation()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_factory() -> void:
	print("[1] create_battle_record seeds all six keys (incl. per-rank counts)")
	var br: Dictionary = _MPS.create_battle_record()
	_ok(br.has("battles_fought") and br["battles_fought"] == 0, "battles_fought seeded 0")
	_ok(br.has("battles_won") and br["battles_won"] == 0, "battles_won seeded 0")
	_ok(br.has("battles_lost") and br["battles_lost"] == 0, "battles_lost seeded 0")
	_ok(br.has("companies_destroyed_under_command"), "companies_destroyed seeded")
	_ok(br.has("battles_as_chui") and br["battles_as_chui"] == 0, "battles_as_chui seeded 0 (was absent)")
	_ok(br.has("battles_as_taisa") and br["battles_as_taisa"] == 0, "battles_as_taisa seeded 0 (was absent)")


func _test_record_by_rank() -> void:
	print("[2] record_battle increments per-rank by the commander's rank at battle time")
	# NONE rank: only battles_fought/won/lost, no per-rank increment.
	var none_br: Dictionary = _MPS.create_battle_record()
	_MPS.record_battle(none_br, true, 0, Enums.MilitaryRank.NONE)
	_ok(none_br["battles_fought"] == 1 and none_br["battles_won"] == 1, "NONE: fought+won incremented")
	_ok(none_br["battles_as_chui"] == 0 and none_br["battles_as_taisa"] == 0, "NONE: no per-rank increment")
	# CHUI: battles_as_chui++.
	var chui_br: Dictionary = _MPS.create_battle_record()
	_MPS.record_battle(chui_br, false, 0, Enums.MilitaryRank.CHUI)
	_ok(chui_br["battles_fought"] == 1 and chui_br["battles_lost"] == 1, "CHUI loss: fought+lost")
	_ok(chui_br["battles_as_chui"] == 1 and chui_br["battles_as_taisa"] == 0, "CHUI: battles_as_chui++")
	# TAISA: battles_as_taisa++. Accumulates across calls.
	var taisa_br: Dictionary = _MPS.create_battle_record()
	_MPS.record_battle(taisa_br, true, 0, Enums.MilitaryRank.TAISA)
	_MPS.record_battle(taisa_br, true, 0, Enums.MilitaryRank.TAISA)
	_ok(taisa_br["battles_as_taisa"] == 2, "TAISA: battles_as_taisa accumulates to 2")
	_ok(taisa_br["battles_fought"] == 2, "TAISA: two battles fought")


func _test_participation() -> void:
	print("[3] _record_battle_participation: living commanders recorded, deduped, won/lost by victor")
	# Attacker side: legion commanded by Taisa 200 (two companies -> deduped to one battle).
	# Defender side: company commanded by Chui 300 + a DEAD commander 301 (skipped).
	var atk: L5RCharacterData = _mk(200, Enums.MilitaryRank.TAISA)
	var def_live: L5RCharacterData = _mk(300, Enums.MilitaryRank.CHUI)
	var def_dead: L5RCharacterData = _mk(301, Enums.MilitaryRank.CHUI, true)
	var chars: Dictionary = {200: atk, 300: def_live, 301: def_dead}
	var atk_dicts: Array = [
		{"company_id": 1, "commander_id": 200},
		{"company_id": 2, "commander_id": 200},  # same commander -> dedup
	]
	var def_dicts: Array = [
		{"company_id": 3, "commander_id": 300},
		{"company_id": 4, "commander_id": 301},  # dead -> skipped
		{"company_id": 5, "commander_id": -1},   # no commander -> skipped
	]
	var battle_result: Dictionary = {"victor": "attacker"}
	_DO._record_battle_participation(battle_result, atk_dicts, def_dicts, chars)
	# Attacker Taisa: one battle, WON, as a Taisa.
	_ok(atk.battle_record.get("battles_fought", 0) == 1, "attacker Taisa: exactly one battle (deduped across 2 companies)")
	_ok(atk.battle_record.get("battles_won", 0) == 1, "attacker Taisa: recorded as WON (attacker victor)")
	_ok(atk.battle_record.get("battles_as_taisa", 0) == 1, "attacker Taisa: battles_as_taisa++")
	# Defender Chui: one battle, LOST, as a Chui.
	_ok(def_live.battle_record.get("battles_fought", 0) == 1, "defender Chui: one battle")
	_ok(def_live.battle_record.get("battles_lost", 0) == 1, "defender Chui: recorded as LOST (attacker victor)")
	_ok(def_live.battle_record.get("battles_as_chui", 0) == 1, "defender Chui: battles_as_chui++")
	# Dead defender commander: no record.
	_ok((def_dead.battle_record as Dictionary).is_empty(), "dead commander: no battle_record written")
	# A second battle accumulates on the same commander (pre-existing record not reset).
	_DO._record_battle_participation({"victor": "defender"}, atk_dicts, def_dicts, chars)
	_ok(atk.battle_record.get("battles_fought", 0) == 2, "attacker Taisa: second battle accumulates (fought=2)")
	_ok(atk.battle_record.get("battles_lost", 0) == 1, "attacker Taisa: this one LOST (defender victor)")
	_ok(atk.battle_record.get("battles_as_taisa", 0) == 2, "attacker Taisa: battles_as_taisa=2 after two battles")
