extends SceneTree
## Runtime driver for the s55.11 PROACTIVE duel path (Trigger 1: public insult) — owner-approved
## 2026-07-08. evaluate_duel_trigger (the deliberate capability/target-assessment/personality gates)
## was fully built but had ZERO callers, and no grievance→challenge event producer existed. Now:
##  (1) a successful PUBLIC_INSULT injects a GRIEVANCE event into the (non-brash-forced) target;
##  (2) the reactive path routes "GRIEVANCE" -> evaluate_duel_trigger;
##  (3) _process_proactive_duel_writebacks issues the resulting ISSUE_DUEL_CHALLENGE by injecting
##      DUEL_CHALLENGE_RECEIVED into the insulter (the existing wired response path takes over).
## Run: godot --headless -s tests/verify_proactive_duel.gd

const _RD := preload("res://simulation/reactive_decisions.gd")
const _CH := preload("res://shared/character_data.gd")
const _NDS := preload("res://simulation/npc_data_structures.gd")
const _DE := preload("res://simulation/dice_engine.gd")
const _EN := preload("res://shared/enums.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, bushido: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.bushido_virtue = bushido
	return c


func _ctx(cid: int) -> NPCDataStructures.ContextSnapshot:
	var ctx: NPCDataStructures.ContextSnapshot = _NDS.ContextSnapshot.new()
	ctx.character_id = cid
	ctx.characters_present = []
	return ctx


func _grievance(insulter_id: int) -> Dictionary:
	return {
		"reactive_type": "GRIEVANCE",
		"trigger_type": "public_insult",
		"target_npc_id": insulter_id,
		"is_public": true,
	}


func _init() -> void:
	print("--- s55.11 proactive duel (Trigger 1: public insult) activated ---")
	_test_reactive_arm_yu()
	_test_reactive_arm_blocked()
	_test_producer_injects_grievance()
	_test_issuance_writeback()
	_test_gossip_and_expose_grievance()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_reactive_arm_yu() -> void:
	print("[1] a GRIEVANCE routes to evaluate_duel_trigger -> ISSUE_DUEL_CHALLENGE for a YU bushi")
	var yu := _char(10, _EN.BushidoVirtue.YU)  # YU passes all three gates
	var res: Dictionary = _RD.evaluate_reactive_event(_grievance(99), yu, _ctx(10))
	_ok(res.get("action", "") == "ISSUE_DUEL_CHALLENGE", "YU -> ISSUE_DUEL_CHALLENGE")
	_ok(int(res.get("target_npc_id", -1)) == 99, "challenge targets the insulter (99)")


func _test_reactive_arm_blocked() -> void:
	print("[2] the personality/capability gates block the challenge (returns PASS)")
	# JIN fails the personality gate.
	var jin := _char(11, _EN.BushidoVirtue.JIN)
	var r1: Dictionary = _RD.evaluate_reactive_event(_grievance(99), jin, _ctx(11))
	_ok(r1.get("action", "") == "PASS", "JIN (compassion) declines -> PASS")
	# NONE virtue, no Iaijutsu, no allies present -> capability check fails.
	var meek := _char(12, _EN.BushidoVirtue.NONE)
	meek.skills = {"Iaijutsu": 0}
	var r2: Dictionary = _RD.evaluate_reactive_event(_grievance(99), meek, _ctx(12))
	_ok(r2.get("action", "") == "PASS", "no capability (no YU, Iaijutsu 0, no allies) -> PASS")


func _test_producer_injects_grievance() -> void:
	print("[3] a successful PUBLIC_INSULT injects a GRIEVANCE into the (non-brash) target")
	var dice: DiceEngine = _DE.new(5)
	var insulter := _char(10, _EN.BushidoVirtue.NONE)
	var target := _char(20, _EN.BushidoVirtue.YU)  # no Brash disadvantage -> deliberate path
	var chars := {10: insulter, 20: target}
	var world_states := {}
	var results := [{
		"action_id": "PUBLIC_INSULT",
		"success": true,
		"character_id": 10,
		"target_npc_id": 20,
	}]
	DayOrchestrator._process_brash_reactions(results, chars, world_states, dice)
	var t_ws: Dictionary = world_states.get(20, {})
	var pending: Array = t_ws.get("pending_events", [])
	var found := false
	for ev_v in pending:
		if ev_v is Dictionary and ev_v.get("reactive_type", "") == "GRIEVANCE" \
				and int(ev_v.get("target_npc_id", -1)) == 10:
			found = true
	_ok(found, "target 20 received a GRIEVANCE naming insulter 10")
	# A failed insult produces nothing.
	var world_states2 := {}
	DayOrchestrator._process_brash_reactions([{
		"action_id": "PUBLIC_INSULT", "success": false, "character_id": 10, "target_npc_id": 20,
	}], chars, world_states2, dice)
	_ok(world_states2.get(20, {}).get("pending_events", []).is_empty(),
		"a FAILED insult injects no grievance")


func _test_issuance_writeback() -> void:
	print("[4] a GRIEVANCE ISSUE_DUEL_CHALLENGE reactive result issues DUEL_CHALLENGE_RECEIVED")
	var insulter := _char(10, _EN.BushidoVirtue.NONE)  # the defender who gets challenged
	var chars := {10: insulter, 20: _char(20, _EN.BushidoVirtue.YU)}
	var world_states := {}
	var reactive_results := [{
		"reactive_type": "GRIEVANCE",
		"action": "ISSUE_DUEL_CHALLENGE",
		"character_id": 20,      # the grieving challenger
		"target_npc_id": 10,     # the insulter (defender)
		"event_data": {"is_public": true},
	}]
	DayOrchestrator._process_proactive_duel_writebacks(reactive_results, chars, world_states)
	var d_ws: Dictionary = world_states.get(10, {})
	var pending: Array = d_ws.get("pending_events", [])
	_ok(pending.size() == 1, "the insulter (10) received exactly one challenge event")
	var ev: Dictionary = pending[0] if pending.size() > 0 else {}
	_ok(ev.get("reactive_type", "") == "DUEL_CHALLENGE_RECEIVED", "it is a DUEL_CHALLENGE_RECEIVED")
	_ok(int(ev.get("challenger_id", -1)) == 20, "challenger is the grieving NPC (20)")
	_ok(ev.get("to_death", true) == false and ev.get("is_sanctioned", false) == true,
		"first-blood, sanctioned (honorable insult duel)")
	# Dedup: a second identical reactive result does not stack a second challenge.
	DayOrchestrator._process_proactive_duel_writebacks(reactive_results, chars, world_states)
	_ok((world_states.get(10, {}).get("pending_events", []) as Array).size() == 1,
		"a repeat GRIEVANCE from the same challenger does not stack a second challenge")


func _test_gossip_and_expose_grievance() -> void:
	print("[5] GOSSIP + EXPOSE_SECRET_PUBLICLY inject a GRIEVANCE into the reputation-damaged subject")
	var gossiper := _char(30, _EN.BushidoVirtue.NONE)
	var subject := _char(40, _EN.BushidoVirtue.YU)  # non-PC, alive
	var exposer := _char(31, _EN.BushidoVirtue.NONE)
	var chars := {30: gossiper, 40: subject, 31: exposer}

	# Open (non-concealed) GOSSIP -> subject can identify the gossiper -> GRIEVANCE naming gossiper 30.
	var ws1 := {}
	DayOrchestrator._process_reputation_grievance_triggers([{
		"action_id": "GOSSIP", "success": true, "character_id": 30,
		"effects": {"gossip_subject_id": 40, "source_concealed": false},
	}], chars, ws1)
	var g_ok := false
	for ev_v in ws1.get(40, {}).get("pending_events", []):
		if ev_v is Dictionary and ev_v.get("reactive_type", "") == "GRIEVANCE" \
				and int(ev_v.get("target_npc_id", -1)) == 30:
			g_ok = true
	_ok(g_ok, "open gossip -> subject 40 gets a GRIEVANCE naming gossiper 30")

	# CONCEALED-source gossip -> subject can't identify the gossiper -> NOTHING.
	var ws2 := {}
	DayOrchestrator._process_reputation_grievance_triggers([{
		"action_id": "GOSSIP", "success": true, "character_id": 30,
		"effects": {"gossip_subject_id": 40, "source_concealed": true},
	}], chars, ws2)
	_ok(ws2.get(40, {}).get("pending_events", []).is_empty(),
		"concealed gossip -> no grievance (unknown gossiper)")

	# EXPOSE_SECRET_PUBLICLY -> subject gets a GRIEVANCE naming the exposer 31.
	var ws3 := {}
	DayOrchestrator._process_reputation_grievance_triggers([{
		"action_id": "EXPOSE_SECRET_PUBLICLY", "success": true, "character_id": 31,
		"effects": {"subject_id": 40},
	}], chars, ws3)
	var e_ok := false
	for ev_v in ws3.get(40, {}).get("pending_events", []):
		if ev_v is Dictionary and ev_v.get("reactive_type", "") == "GRIEVANCE" \
				and int(ev_v.get("target_npc_id", -1)) == 31:
			e_ok = true
	_ok(e_ok, "public secret exposure -> subject 40 gets a GRIEVANCE naming exposer 31")

	# A FAILED exposure produces nothing; self-subject (actor == subject) produces nothing.
	var ws4 := {}
	DayOrchestrator._process_reputation_grievance_triggers([{
		"action_id": "EXPOSE_SECRET_PUBLICLY", "success": false, "character_id": 31,
		"effects": {"subject_id": 40},
	}], chars, ws4)
	_ok(ws4.get(40, {}).get("pending_events", []).is_empty(), "a FAILED exposure injects nothing")
	var ws5 := {}
	DayOrchestrator._process_reputation_grievance_triggers([{
		"action_id": "GOSSIP", "success": true, "character_id": 40,
		"effects": {"gossip_subject_id": 40, "source_concealed": false},
	}], chars, ws5)
	_ok(ws5.get(40, {}).get("pending_events", []).is_empty(), "self-gossip (actor==subject) injects nothing")
