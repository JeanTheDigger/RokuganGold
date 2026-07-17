extends SceneTree
## Runtime driver for s57.22.5 COMPOSE_THEATER_PIECE priority arbiter wiring.
## Before this, TheaterSystem.select_composition_piece_to_advance had ZERO production callers AND
## a broken priority-1 (it computed `is_political` from the active need but never used it in the
## sort_custom comparator -- so political pieces did NOT rank above artistic ones). The live compose
## metadata builder (_build_compose_theater_metadata) just grabbed wip_ids[0] (the first WIP piece in
## injection order), ignoring the LOCKED s57.22.5 ordering entirely. This driver exercises the fix:
## (1) the arbiter now ranks a politically-motivated piece (TheaterPieceData.political_need_type set)
##     above an ARTISTIC_EXPRESSION piece (empty), THEN by highest progress/threshold ratio, THEN by
##     most-recently-declared (highest piece_id);
## (2) _inject_theater_context now exposes each WIP piece object in _theater_pieces_by_id (was a gap:
##     WIP pieces continued past the pieces_by_id write);
## (3) _build_compose_theater_metadata now resolves the WIP piece objects and calls the arbiter,
##     falling back to wip_ids[0] only when the piece objects are unresolvable.
## Run: godot --headless -s tests/verify_theater_compose_priority.gd

const _TS := preload("res://simulation/theater_system.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")
const _NDE := preload("res://simulation/npc_decision_engine.gd")
const _PIECE := preload("res://shared/theater_piece_data.gd")
const _CHAR := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


# A WIP piece: craft_progress >= 0, target_magnitude/num_roles_declared drive its threshold.
func _mk_wip(pid: int, author: int, progress: int, magnitude: int, political: String = "") -> TheaterPieceData:
	var p: TheaterPieceData = _PIECE.new()
	p.piece_id = pid
	p.author_id = author
	p.craft_progress = progress
	p.target_magnitude = magnitude
	p.num_roles_declared = 1
	p.political_need_type = political
	return p


func _init() -> void:
	print("--- s57.22.5 compose priority arbiter ---")
	_test_political_first()
	_test_progress_ratio()
	_test_recency_tiebreak()
	_test_filters()
	_test_injection_exposes_wip()
	_test_metadata_uses_arbiter()
	_test_metadata_fallback()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_political_first() -> void:
	print("[1] priority-1: political piece outranks a MORE-progressed artistic piece")
	# Artistic piece far along (high ratio) vs political piece barely started -> political wins.
	var artistic: TheaterPieceData = _mk_wip(10, 500, 90, 3, "")  # near threshold, but artistic
	var political: TheaterPieceData = _mk_wip(11, 500, 2, 3, "DAMAGE_RELATIONSHIP")  # barely started
	var chosen: TheaterPieceData = _TS.select_composition_piece_to_advance(500, [artistic, political], "ARTISTIC_EXPRESSION")
	_ok(chosen != null and chosen.piece_id == 11, "political piece (11) selected over more-progressed artistic (10)")
	# MOVE_TOPIC_POSITION is also political.
	var political2: TheaterPieceData = _mk_wip(12, 500, 1, 3, "MOVE_TOPIC_POSITION")
	var chosen2: TheaterPieceData = _TS.select_composition_piece_to_advance(500, [artistic, political2], "")
	_ok(chosen2 != null and chosen2.piece_id == 12, "MOVE_TOPIC_POSITION piece also counts as political")


func _test_progress_ratio() -> void:
	print("[2] priority-2: among same-priority pieces, highest progress/threshold ratio wins")
	# Two artistic pieces, same magnitude/threshold; higher progress wins.
	var lo: TheaterPieceData = _mk_wip(20, 500, 10, 3, "")
	var hi: TheaterPieceData = _mk_wip(21, 500, 40, 3, "")
	var chosen: TheaterPieceData = _TS.select_composition_piece_to_advance(500, [lo, hi], "")
	_ok(chosen != null and chosen.piece_id == 21, "more-progressed artistic piece (21) selected")
	# Two political pieces: ratio decides between them (political-vs-political).
	var plo: TheaterPieceData = _mk_wip(22, 500, 5, 3, "DAMAGE_RELATIONSHIP")
	var phi: TheaterPieceData = _mk_wip(23, 500, 50, 3, "MOVE_TOPIC_POSITION")
	var chosen2: TheaterPieceData = _TS.select_composition_piece_to_advance(500, [plo, phi], "")
	_ok(chosen2 != null and chosen2.piece_id == 23, "more-progressed political piece (23) selected")


func _test_recency_tiebreak() -> void:
	print("[3] priority-3: equal political-status + equal ratio -> most-recently-declared (highest piece_id)")
	var older: TheaterPieceData = _mk_wip(30, 500, 20, 3, "")
	var newer: TheaterPieceData = _mk_wip(31, 500, 20, 3, "")  # identical ratio, higher id
	var chosen: TheaterPieceData = _TS.select_composition_piece_to_advance(500, [older, newer], "")
	_ok(chosen != null and chosen.piece_id == 31, "highest piece_id (31) wins the ratio tie")


func _test_filters() -> void:
	print("[4] arbiter filters: completed / lost / abandoned / other-author excluded")
	var mine_wip: TheaterPieceData = _mk_wip(40, 500, 10, 3, "")
	var completed: TheaterPieceData = _mk_wip(41, 500, 10, 3, "")
	completed.craft_progress = -1  # complete -> excluded
	var lost: TheaterPieceData = _mk_wip(42, 500, 99, 3, "DAMAGE_RELATIONSHIP")
	lost.lost = true  # excluded despite political + high progress
	var abandoned: TheaterPieceData = _mk_wip(43, 500, 99, 3, "DAMAGE_RELATIONSHIP")
	abandoned.abandoned_incomplete = true  # excluded
	var other: TheaterPieceData = _mk_wip(44, 999, 99, 3, "DAMAGE_RELATIONSHIP")  # not my author -> excluded
	var chosen: TheaterPieceData = _TS.select_composition_piece_to_advance(
		500, [mine_wip, completed, lost, abandoned, other], ""
	)
	_ok(chosen != null and chosen.piece_id == 40, "only my live WIP piece (40) survives the filters")
	# Nothing eligible -> null.
	var none: TheaterPieceData = _TS.select_composition_piece_to_advance(500, [completed, lost, other], "")
	_ok(none == null, "no eligible piece -> null")


func _test_injection_exposes_wip() -> void:
	print("[5] _inject_theater_context exposes the WIP piece object in _theater_pieces_by_id")
	var author: L5RCharacterData = _CHAR.new()
	author.character_id = 500
	author.wounds_taken = 0
	var wip: TheaterPieceData = _mk_wip(50, 500, 15, 3, "DAMAGE_RELATIONSHIP")
	var world_states: Dictionary = {500: {"known_objectives": {}}}
	_DO._inject_theater_context([wip], [author], world_states)
	var ko: Dictionary = (world_states[500] as Dictionary).get("known_objectives", {})
	var wip_ids: Array = ko.get("wip_piece_ids", [])
	_ok(wip_ids.size() == 1 and int(wip_ids[0]) == 50, "author's WIP piece id injected")
	var by_id: Dictionary = ko.get("_theater_pieces_by_id", {})
	_ok(by_id.has(50), "WIP piece object exposed in _theater_pieces_by_id (was the gap)")
	_ok(by_id.get(50, null) == wip, "exposed object is the actual WIP piece")


func _test_metadata_uses_arbiter() -> void:
	print("[6] _build_compose_theater_metadata picks the arbiter's choice, not wip_ids[0]")
	# wip_ids order puts the artistic piece FIRST; the arbiter must still pick the political one.
	var artistic: TheaterPieceData = _mk_wip(60, 500, 80, 3, "")  # first in wip_ids, high progress
	var political: TheaterPieceData = _mk_wip(61, 500, 3, 3, "DAMAGE_RELATIONSHIP")  # second, barely started
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 500
	ctx.known_objectives = {
		"wip_piece_ids": [60, 61],
		"_theater_pieces_by_id": {60: artistic, 61: political},
	}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DAMAGE_RELATIONSHIP"
	var meta: Dictionary = _NDE._build_compose_theater_metadata(ctx, need)
	_ok(meta.get("is_new", true) == false, "advancing a WIP piece (not declaring new)")
	_ok(meta.get("piece_id", -1) == 61, "arbiter picked the political piece (61), not wip_ids[0] (60)")


func _test_metadata_fallback() -> void:
	print("[7] metadata falls back to wip_ids[0] when piece objects are unresolvable")
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 500
	# WIP ids present but _theater_pieces_by_id missing them -> graceful fallback.
	ctx.known_objectives = {"wip_piece_ids": [70, 71], "_theater_pieces_by_id": {}}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "ARTISTIC_EXPRESSION"
	var meta: Dictionary = _NDE._build_compose_theater_metadata(ctx, need)
	_ok(meta.get("piece_id", -1) == 70, "unresolvable pieces -> fall back to wip_ids[0] (70)")
	_ok(meta.get("is_new", true) == false, "still advancing a WIP piece")
