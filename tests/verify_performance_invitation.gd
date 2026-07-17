extends SceneTree
## Runtime driver for the dead performance_invitation_received reactive need (s12.4 / s57.33).
## _decompose_reactive_event branches on ev.type == "performance_invitation_received" (priority 2,
## a TARGETED personal court commission), but NO injector ever created that event: the injector
## only emitted "open_performance_request" and `continue`d past every targeted request. So a named
## performer was never nudged to fulfill a personal commission -- it just expired 90 days later.
## Now build_context injects performance_invitation_received for the addressed performer (precedence
## over an open request), else open_performance_request.
## Run: godot --headless -s tests/verify_performance_invitation.gd

const _E := preload("res://simulation/npc_decision_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _performer(cid: int, skilled: bool = true) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "P%d" % cid
	if skilled:
		c.skills = {"Perform: Dance": 3}
	return c


func _req(request_id: int, target_performer_id: int) -> Dictionary:
	return {
		"request_id": request_id,
		"requesting_lord_id": 500,
		"performance_type": "dance",
		"target_performer_id": target_performer_id,
		"venue_mode": "public",
	}


func _ws(requests: Array, at_court: bool = true) -> Dictionary:
	var ws: Dictionary = {"pending_performance_requests": requests}
	if at_court:
		ws["active_court_at_location"] = {"court_id": 1}
	return ws


func _event_types(character: L5RCharacterData, ws: Dictionary) -> Array:
	var ctx := _E.build_context(character, ws, {})
	var types: Array = []
	for ev: Dictionary in ctx.pending_events:
		types.append(ev.get("type", ""))
	return types


func _init() -> void:
	print("--- performance_invitation_received injection (s12.4 targeted / s57.33.3 open) ---")
	_test_targeted()
	_test_open()
	_test_targeted_other_performer()
	_test_targeted_precedence()
	_test_no_court()
	_test_unskilled()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_targeted() -> void:
	print("[1] a targeted commission to this performer -> performance_invitation_received")
	var types := _event_types(_performer(1), _ws([_req(10, 1)]))
	_ok("performance_invitation_received" in types, "invited performer gets the reactive nudge")


func _test_open() -> void:
	print("[2] an open request (target -1) -> open_performance_request")
	var types := _event_types(_performer(2), _ws([_req(11, -1)]))
	_ok("open_performance_request" in types, "open request nudges a present performer")
	_ok(not ("performance_invitation_received" in types), "open request is NOT a targeted invitation")


func _test_targeted_other_performer() -> void:
	print("[3] a targeted commission to a DIFFERENT performer -> this one gets nothing")
	var types := _event_types(_performer(1), _ws([_req(12, 99)]))
	_ok(not ("performance_invitation_received" in types) and not ("open_performance_request" in types),
		"a targeted-to-someone-else request does not nudge this performer")


func _test_targeted_precedence() -> void:
	print("[4] both a targeted-for-me AND an open request -> targeted wins (priority 2)")
	var types := _event_types(_performer(1), _ws([_req(13, -1), _req(14, 1)]))
	_ok("performance_invitation_received" in types, "targeted invitation injected")
	_ok(not ("open_performance_request" in types), "the open request is not also injected (targeted precedence)")


func _test_no_court() -> void:
	print("[5] no active court -> no performance event even for a targeted invitation")
	var types := _event_types(_performer(1), _ws([_req(15, 1)], false))
	_ok(not ("performance_invitation_received" in types), "no court -> no invitation nudge")


func _test_unskilled() -> void:
	print("[6] targeted performer who lacks the skill (can_fulfill false) -> no nudge")
	var types := _event_types(_performer(1, false), _ws([_req(16, 1)]))
	_ok(not ("performance_invitation_received" in types), "unskilled invited performer is not nudged")
