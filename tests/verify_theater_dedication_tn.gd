extends SceneTree
## Runtime driver for the theater DEDICATE_PIECE magnitude-TN + can_dedicate gate fix (s57.22.10).
## TheaterSystem.get_dedication_tn (TN 10 + magnitude*2) and can_dedicate (known_by / <2 topic slots /
## topic-not-linked / topic-known preconditions) had ZERO callers: ActionExecutor._execute_dedicate_piece
## used a flat `DEDICATION_BASE_TN + raises*5` (DROPPING the magnitude difficulty term + double-counting
## raises) and gated only on "topic known". Fix: _build_dedicate_piece_metadata now selects a (piece,
## topic) pair that passes the canonical can_dedicate gate and carries get_dedication_tn; the executor
## uses that TN and folds raises once.
## Run: godot --headless -s tests/verify_theater_dedication_tn.gd

const _AE := preload("res://simulation/action_executor.gd")
const _TS := preload("res://simulation/theater_system.gd")
const _NDE := preload("res://simulation/npc_decision_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, topics: Array) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.clan = "Crane"
	c.family = "Doji"
	c.awareness = 3
	c.skills = {"Courtier": 3}
	c.topic_pool.assign(topics)
	return c


func _piece(pid: int, magnitude: int, known_by: Array, topic_ids: Array) -> TheaterPieceData:
	var p := TheaterPieceData.new()
	p.piece_id = pid
	p.style = _TS.Style.NOH
	p.disposition_magnitude = magnitude
	p.known_by.assign(known_by)
	p.topic_ids.assign(topic_ids)
	p.roles = [{"subject_type": _TS.SubjectType.ABSTRACT}]
	return p


func _ctx(cid: int, pieces: Array, topics: Array) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = cid
	ctx.ic_day = 300
	ctx.season = 0
	ctx.location_id = "10"
	var by_id: Dictionary = {}
	var perform: Array = []
	for p: TheaterPieceData in pieces:
		by_id[p.piece_id] = p
		perform.append(p.piece_id)
	ctx.known_objectives = {
		"_theater_pieces_by_id": by_id,
		"theater_pieces_to_perform": perform,
	}
	ctx.known_topics.assign(topics)
	return ctx


func _action(meta: Dictionary) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "DEDICATE_PIECE"
	a.metadata = meta
	return a


func _init() -> void:
	print("--- Theater dedication magnitude-TN + can_dedicate gate wired (s57.22.10) ---")
	_test_arbiter()
	_test_gate()
	_test_builder()
	_test_executor_tn()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter() -> void:
	print("[1] get_dedication_tn = 10 + magnitude*2")
	_ok(_TS.get_dedication_tn(_piece(1, 1, [7], [])) == 12, "magnitude 1 -> TN 12")
	_ok(_TS.get_dedication_tn(_piece(1, 3, [7], [])) == 16, "magnitude 3 -> TN 16")
	_ok(_TS.get_dedication_tn(_piece(1, 5, [7], [])) == 20, "magnitude 5 -> TN 20")


func _test_gate() -> void:
	print("[2] can_dedicate enforces the s57.22.10 preconditions")
	var ch := _char(7, [100])
	# Valid: char in known_by, 0/2 topic slots, topic not linked, topic known.
	_ok(_TS.can_dedicate(7, _piece(1, 2, [7], []), 100, ch), "valid pair -> true")
	# Not in known_by.
	_ok(not _TS.can_dedicate(7, _piece(1, 2, [8], []), 100, ch), "char not in known_by -> false")
	# Already 2 topic slots filled.
	_ok(not _TS.can_dedicate(7, _piece(1, 2, [7], [101, 102]), 100, ch), "2 topic slots full -> false")
	# Topic already linked to this piece.
	_ok(not _TS.can_dedicate(7, _piece(1, 2, [7], [100]), 100, ch), "topic already linked -> false")
	# Topic not in the character's topic_pool.
	_ok(not _TS.can_dedicate(7, _piece(1, 2, [7], []), 999, ch), "topic not known -> false")


func _test_builder() -> void:
	print("[3] the metadata builder selects a dedicatable pair + carries get_dedication_tn")
	var ch := _char(7, [100])
	# One dedicatable piece (magnitude 4, known, empty slots) + one NOT dedicatable (char not known).
	var good := _piece(1, 4, [7], [])
	var bad := _piece(2, 2, [8], [])
	var ctx := _ctx(7, [bad, good], [100])
	var need := NPCDataStructures.ImmediateNeed.new()
	var meta: Dictionary = _NDE._build_dedicate_piece_metadata(ctx, need, ch)
	_ok(int(meta.get("piece_id", -1)) == 1, "picks the dedicatable piece (skips the un-known one)")
	_ok(int(meta.get("topic_id", -1)) == 100, "picks the known, unlinked topic")
	_ok(int(meta.get("dedication_tn", -1)) == 18, "carries get_dedication_tn (magnitude 4 -> 10+4*2 = 18)")

	# No dedicatable pair at all -> piece_id -1 (executor will block).
	var ctx2 := _ctx(7, [bad], [100])
	var meta2: Dictionary = _NDE._build_dedicate_piece_metadata(ctx2, need, ch)
	_ok(int(meta2.get("piece_id", -1)) == -1, "no dedicatable pair -> piece_id -1 (no-op)")


func _test_executor_tn() -> void:
	print("[4] the executor uses the magnitude-scaled TN (harder for a bigger piece)")
	var ch := _char(7, [100])
	# Low-magnitude (TN 12) vs high-magnitude (TN 20) dedication, same performer + seeds.
	var lo_wins: int = 0
	var hi_wins: int = 0
	for seed in range(1, 161):
		var lo := _AE._execute_dedicate_piece(
			_action({"piece_id": 1, "topic_id": 100, "raises": 0, "dedication_tn": 12}),
			_char(7, [100]), _ctx(7, [_piece(1, 1, [7], [])], [100]), DiceEngine.new(seed))
		var hi := _AE._execute_dedicate_piece(
			_action({"piece_id": 1, "topic_id": 100, "raises": 0, "dedication_tn": 20}),
			_char(7, [100]), _ctx(7, [_piece(1, 5, [7], [])], [100]), DiceEngine.new(seed))
		if bool(lo.get("success", false)):
			lo_wins += 1
		if bool(hi.get("success", false)):
			hi_wins += 1
	_ok(hi_wins < lo_wins, "high-magnitude TN succeeds less than low (%d < %d)" % [hi_wins, lo_wins])

	# Missing dedication_tn -> falls back to DEDICATION_BASE_TN (no crash).
	var fb := _AE._execute_dedicate_piece(
		_action({"piece_id": 1, "topic_id": 100, "raises": 0}),
		ch, _ctx(7, [_piece(1, 1, [7], [])], [100]), DiceEngine.new(5))
	_ok(fb.has("success"), "missing dedication_tn -> base TN fallback, no crash")

	# piece_id -1 -> blocked.
	var blk := _AE._execute_dedicate_piece(
		_action({"piece_id": -1, "topic_id": -1, "raises": 0}),
		ch, _ctx(7, [], [100]), DiceEngine.new(5))
	_ok(not bool(blk.get("success", true))
		and blk.get("effects", {}).get("blocked_reason", "") == "no_piece_to_dedicate",
		"piece_id -1 -> blocked (no_piece_to_dedicate)")
