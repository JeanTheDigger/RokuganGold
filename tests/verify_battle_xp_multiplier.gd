extends SceneTree
## Runtime driver for the s52 Part 3 BATTLE activity multiplier season-wide wire.
##
## NPCAdvancement.get_activity_multiplier grants 2.5x (participating) / 3.0x (commanding) XP for
## the OOC season to every combatant in world_state["in_battle_ids"] -- but DayOrchestrator's
## builder _build_advancement_world_state HARDCODED "in_battle_ids": [], so that arm was DEAD:
## no NPC ever received the battle multiplier. The producer battle_record was live (per-rank
## promotion counters) but carried no SEASON stamp, so the seasonal pass could not tell WHO
## fought THIS season.
##
## FIX (this driver): _record_side_participation now stamps battle_record["last_battle_season"]
## = get_absolute_season(ic_day) when a commander records a battle, and _build_advancement_world_state
## reconstructs in_battle_ids from every character whose stamp == the JUST-ENDED absolute season
## (advancement fires at the START of the new season, before this season's battles, so the credited
## season is get_absolute_season(ic_day) - 1). The stamp is per-character and self-cleaning (only
## "current" for one season). Values are the arbiter's own LOCKED s52 constants (2.5x/3.0x) --
## no invention.
## Run: godot --headless -s tests/verify_battle_xp_multiplier.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _MPS := preload("res://simulation/military_promotion_system.gd")
const _NA := preload("res://simulation/npc_advancement.gd")
const _TS := preload("res://simulation/time_system.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A Chui+ company commander (commands a unit -> 3.0x when in battle).
func _mk_commander(id: int, rank: int = Enums.MilitaryRank.TAISA, unit: int = 5) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.military_rank = rank
	c.commanded_unit_id = unit
	c.wounds_taken = 0
	return c


func _init() -> void:
	print("--- s52 battle activity multiplier (season-wide wire) ---")
	_test_producer_stamp()
	_test_builder_membership()
	_test_end_to_end_multiplier()
	_test_backward_compat()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_producer_stamp() -> void:
	print("[1] producer: _record_battle_participation stamps last_battle_season = get_absolute_season(ic_day)")
	# ic_day 90 -> absolute season 1 (summer, year 0).
	var ic_day: int = 90
	var abs_season: int = _TS.get_absolute_season(ic_day)
	_ok(abs_season == 1, "get_absolute_season(90) == 1 (summer y0)")

	var atk_cmd: L5RCharacterData = _mk_commander(1)
	var def_cmd: L5RCharacterData = _mk_commander(2, Enums.MilitaryRank.CHUI, 6)
	var chars: Dictionary = {1: atk_cmd, 2: def_cmd}
	var atk_dicts: Array = [{"commander_id": 1}]
	var def_dicts: Array = [{"commander_id": 2}]
	var battle_result: Dictionary = {"victor": "attacker"}

	_DO._record_battle_participation(battle_result, atk_dicts, def_dicts, chars, ic_day)

	_ok((atk_cmd.battle_record as Dictionary).get("last_battle_season", -999) == abs_season,
		"attacker commander stamped last_battle_season == %d" % abs_season)
	_ok((def_cmd.battle_record as Dictionary).get("last_battle_season", -999) == abs_season,
		"defender commander stamped last_battle_season == %d" % abs_season)
	_ok(int((atk_cmd.battle_record as Dictionary).get("battles_fought", 0)) == 1,
		"battle_record still accrues battles_fought (producer unchanged otherwise)")

	# Dead / -1 commanders record nothing.
	var dead: L5RCharacterData = _mk_commander(3)
	dead.wounds_taken = 9999  # lethal
	var chars2: Dictionary = {3: dead}
	_DO._record_battle_participation({"victor": "attacker"}, [{"commander_id": 3}], [{"commander_id": -1}], chars2, ic_day)
	_ok(not (dead.battle_record as Dictionary).has("last_battle_season"),
		"a dead commander is not stamped")


func _test_builder_membership() -> void:
	print("[2] builder: in_battle_ids = commanders whose stamp == the JUST-ENDED season")
	# Advancement fires at the start of the new season. Say ic_day 90 (summer y0 start,
	# absolute season 1) -> the just-ended season is spring y0 (absolute 0).
	var ic_day: int = 90
	var just_ended: int = _TS.get_absolute_season(ic_day) - 1  # == 0
	_ok(just_ended == 0, "credited (just-ended) absolute season == 0")

	var fought_last: L5RCharacterData = _mk_commander(10)
	fought_last.battle_record = _MPS.create_battle_record()
	(fought_last.battle_record as Dictionary)["last_battle_season"] = just_ended  # fought in spring

	var no_battle: L5RCharacterData = _mk_commander(11)
	no_battle.battle_record = _MPS.create_battle_record()  # never fought (no stamp)

	var fought_two_ago: L5RCharacterData = _mk_commander(12)
	fought_two_ago.battle_record = _MPS.create_battle_record()
	(fought_two_ago.battle_record as Dictionary)["last_battle_season"] = just_ended - 1  # stale

	var fought_this_season: L5RCharacterData = _mk_commander(13)
	fought_this_season.battle_record = _MPS.create_battle_record()
	(fought_this_season.battle_record as Dictionary)["last_battle_season"] = just_ended + 1  # current, not yet ended

	var ws: Dictionary = _DO._build_advancement_world_state(
		[fought_last, no_battle, fought_two_ago, fought_this_season], [], [], [], [], ic_day
	)
	var ids: Array = ws.get("in_battle_ids", [])
	_ok(ids.has(10), "commander who fought the just-ended season IS credited")
	_ok(not ids.has(11), "commander who never fought is NOT credited")
	_ok(not ids.has(12), "commander who fought TWO seasons ago is NOT credited (self-cleaning)")
	_ok(not ids.has(13), "commander who fought the current (not-yet-ended) season is NOT credited")

	# No ic_day -> empty (safe default, no crash).
	var ws_default: Dictionary = _DO._build_advancement_world_state([fought_last], [], [], [], [], -1)
	_ok((ws_default.get("in_battle_ids", []) as Array).is_empty(),
		"ic_day < 0 yields empty in_battle_ids (graceful default)")

	# EDGE CASE: the very first season boundary (ic_day 0/1, year-0 spring). prev_abs_season == -1,
	# which equals the empty-record .get default -- an unstamped character must NOT be falsely
	# credited. Guarded by prev_abs_season >= 0.
	var never_fought: L5RCharacterData = _mk_commander(14)
	never_fought.battle_record = _MPS.create_battle_record()  # no last_battle_season key -> .get == -1
	var empty_record: L5RCharacterData = _mk_commander(15)  # default {} battle_record
	for boundary_day: int in [0, 1]:
		var ws_first: Dictionary = _DO._build_advancement_world_state(
			[never_fought, empty_record], [], [], [], [], boundary_day
		)
		_ok((ws_first.get("in_battle_ids", []) as Array).is_empty(),
			"first season boundary (ic_day %d): no false credit for unstamped records" % boundary_day)


func _test_end_to_end_multiplier() -> void:
	print("[3] end-to-end: producer -> builder -> get_activity_multiplier (2.5x / 3.0x)")
	# Stamp two commanders during spring (ic_day 10 -> absolute season 0), then run the builder
	# at the summer boundary (ic_day 90 -> season 1, just-ended 0).
	var stamp_day: int = 10
	var commanding: L5RCharacterData = _mk_commander(20, Enums.MilitaryRank.TAISA, 7)  # commands -> 3.0x
	var participating: L5RCharacterData = _mk_commander(21, Enums.MilitaryRank.HOHEI, -1)  # no command -> 2.5x
	var bystander: L5RCharacterData = _mk_commander(22, Enums.MilitaryRank.TAISA, 8)  # never fought -> 1.0x
	var chars: Dictionary = {20: commanding, 21: participating}
	_DO._record_battle_participation(
		{"victor": "attacker"}, [{"commander_id": 20}, {"commander_id": 21}], [], chars, stamp_day
	)

	var adv_day: int = 90
	var ws: Dictionary = _DO._build_advancement_world_state(
		[commanding, participating, bystander], [], [], [], [], adv_day
	)
	_ok(_NA.get_activity_multiplier(commanding, ws) == _NA.MULTIPLIER_COMMANDING_BATTLE,
		"commanding officer -> 3.0x battle multiplier")
	_ok(_NA.get_activity_multiplier(participating, ws) == _NA.MULTIPLIER_BATTLE,
		"participating soldier (no command) -> 2.5x battle multiplier")
	_ok(_NA.get_activity_multiplier(bystander, ws) == _NA.MULTIPLIER_PEACETIME,
		"bystander who never fought -> 1.0x peacetime")


func _test_backward_compat() -> void:
	print("[4] backward-compat: 4-arg _record_battle_participation (no ic_day) leaves no stamp")
	var cmd: L5RCharacterData = _mk_commander(30)
	var chars: Dictionary = {30: cmd}
	# The pre-fix call shape (verify_battle_record.gd uses this) must still work.
	_DO._record_battle_participation({"victor": "attacker"}, [{"commander_id": 30}], [], chars)
	_ok(int((cmd.battle_record as Dictionary).get("battles_fought", 0)) == 1,
		"4-arg call still records the battle")
	_ok(not (cmd.battle_record as Dictionary).has("last_battle_season"),
		"4-arg call leaves no season stamp (ic_day defaults to -1)")
