extends SceneTree
## Runtime driver for the s57.25.7 SEEK_TATTOO maximum-urgency precedence escalation.
## get_seek_tattoo_urgency (85/90/95 by seasons-at-rank-unfilled) was LIVE only for the GRANT
## pass's recipient selection; its OTHER LOCKED effect -- "after 3 IC seasons unfilled, SEEK_TATTOO
## overrides all objectives except a direct lord command + active military deployment" -- had no
## consumer (the engine ranks objectives by precedence TIERS, not a numeric objective score, so the
## 95 had no slot). Fix: the SEEK pass now stamps urgency_seasons onto the SEEK_TATTOO standing, and
## resolve_goal skips a self-selected primary (falling through to the SEEK_TATTOO standing) at
## maximum urgency via _seek_tattoo_max_urgency_override. This driver exercises the override predicate
## AND the end-to-end resolve_goal precedence flip, plus the SEEK-pass urgency stamp.
## Run: godot --headless -s tests/verify_seek_urgency_escalation.gd

const _NPC := preload("res://simulation/npc_decision_engine.gd")
const _TAT := preload("res://simulation/tattoo_system.gd")
const _DO := preload("res://simulation/day_orchestrator.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _NDS := preload("res://simulation/npc_data_structures.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk(id: int, school: String, rank: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.school = school
	c.school_rank = rank
	c.insight_rank = rank
	return c


func _ctx(id: int, flag: int = Enums.ContextFlag.AT_OWN_HOLDINGS) -> NPCDataStructures.ContextSnapshot:
	var ctx: NPCDataStructures.ContextSnapshot = _NDS.ContextSnapshot.new()
	ctx.character_id = id
	ctx.context_flag = flag
	return ctx


func _init() -> void:
	print("--- s57.25.7 SEEK_TATTOO maximum-urgency escalation ---")
	_test_override_predicate()
	_test_resolve_goal_flip()
	_test_seek_pass_urgency_stamp()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_override_predicate() -> void:
	print("[1] _seek_tattoo_max_urgency_override: gate on urgency / lord-command / on-campaign")
	var monk: L5RCharacterData = _mk(1, "Togashi Tattooed Order", 1)
	var ctx: NPCDataStructures.ContextSnapshot = _ctx(1)
	# Standing SEEK_TATTOO at max urgency (3 seasons) + self-selected primary -> override.
	var objs_max: Dictionary = {
		"primary": {"need_type": "PERFORM_RITUAL"},  # no assigned_by -> self-selected
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 3},
	}
	_ok(_NPC._seek_tattoo_max_urgency_override(monk, ctx, objs_max), "max urgency + self primary -> override")
	# Below max urgency (2 seasons -> OVERRIDE_SCORE 90, not MAXIMUM 95) -> no override.
	var objs_mid: Dictionary = {
		"primary": {"need_type": "PERFORM_RITUAL"},
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 2},
	}
	_ok(not _NPC._seek_tattoo_max_urgency_override(monk, ctx, objs_mid), "2 seasons (score 90) -> no override")
	# Standing is not SEEK_TATTOO -> no override.
	var objs_notseek: Dictionary = {
		"primary": {"need_type": "PERFORM_RITUAL"},
		"standing": {"need_type": "PERFORM_RITUAL", "urgency_seasons": 5},
	}
	_ok(not _NPC._seek_tattoo_max_urgency_override(monk, ctx, objs_notseek), "non-SEEK standing -> no override")
	# Lord-assigned primary (assigned_by = some other id) -> NEVER overridden.
	var objs_lord: Dictionary = {
		"primary": {"need_type": "TRAVEL_TO", "assigned_by": 99},
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 4},
	}
	_ok(not _NPC._seek_tattoo_max_urgency_override(monk, ctx, objs_lord), "lord command primary -> never overridden")
	# Self-assigned primary (assigned_by == self) counts as self-selected -> override.
	var objs_self: Dictionary = {
		"primary": {"need_type": "TRAVEL_TO", "assigned_by": 1},
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 3},
	}
	_ok(_NPC._seek_tattoo_max_urgency_override(monk, ctx, objs_self), "self-assigned primary -> override")
	# On active campaign -> NEVER overridden.
	var ctx_camp: NPCDataStructures.ContextSnapshot = _ctx(1, Enums.ContextFlag.ON_CAMPAIGN)
	_ok(not _NPC._seek_tattoo_max_urgency_override(monk, ctx_camp, objs_max), "on-campaign -> never overridden")


func _test_resolve_goal_flip() -> void:
	print("[2] resolve_goal: max-urgency SEEK_TATTOO overrides a self-selected primary end-to-end")
	var monk: L5RCharacterData = _mk(1, "Togashi Tattooed Order", 1)
	# Self-selected primary PERFORM_RITUAL + max-urgency SEEK_TATTOO standing.
	var objs_max: Dictionary = {
		"primary": {"need_type": "PERFORM_RITUAL"},
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 3, "priority": 3},
	}
	var ctx: NPCDataStructures.ContextSnapshot = _ctx(1)
	var need_max: NPCDataStructures.ImmediateNeed = _NPC.resolve_goal(monk, ctx, objs_max)
	_ok(need_max != null and need_max.need_type == "SEEK_TATTOO",
		"max urgency: resolve_goal returns SEEK_TATTOO (skips self primary)")
	# Below max urgency: the primary wins (standard precedence: primary before standing).
	var objs_low: Dictionary = {
		"primary": {"need_type": "PERFORM_RITUAL"},
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 1, "priority": 3},
	}
	var need_low: NPCDataStructures.ImmediateNeed = _NPC.resolve_goal(monk, ctx, objs_low)
	_ok(need_low != null and need_low.need_type == "PERFORM_RITUAL",
		"low urgency: primary still wins (standard precedence)")
	# Lord-assigned primary is never overridden even at max urgency.
	var objs_lord: Dictionary = {
		"primary": {"need_type": "PERFORM_RITUAL", "assigned_by": 99},
		"standing": {"need_type": "SEEK_TATTOO", "urgency_seasons": 5, "priority": 3},
	}
	var need_lord: NPCDataStructures.ImmediateNeed = _NPC.resolve_goal(monk, ctx, objs_lord)
	_ok(need_lord != null and need_lord.need_type == "PERFORM_RITUAL",
		"lord command wins over max-urgency SEEK_TATTOO")
	# On campaign at max urgency: military deployment wins.
	var ctx_camp: NPCDataStructures.ContextSnapshot = _ctx(1, Enums.ContextFlag.ON_CAMPAIGN)
	var need_camp: NPCDataStructures.ImmediateNeed = _NPC.resolve_goal(monk, ctx_camp, objs_max)
	_ok(need_camp != null and need_camp.need_type == "PERFORM_RITUAL",
		"active deployment wins over max-urgency SEEK_TATTOO")


func _test_seek_pass_urgency_stamp() -> void:
	print("[3] SEEK pass stamps urgency_seasons from seasons-at-rank, refreshed each tick")
	var monk: L5RCharacterData = _mk(1, "Togashi Tattooed Order", 1)
	monk.tattoo_rank_reached_season = 0  # absolute season 0
	var objectives_map: Dictionary = {}
	# ic_day 360 -> absolute season 4; seasons_at_rank_unfilled = 4.
	_DO._assign_seek_tattoo_standing_objectives([monk], objectives_map, [], 360)
	var st: Dictionary = objectives_map.get(1, {}).get("standing", {})
	_ok(st.get("need_type", "") == "SEEK_TATTOO", "seeker assigned SEEK_TATTOO")
	_ok(int(st.get("urgency_seasons", -1)) == 4, "urgency_seasons stamped = 4 seasons")
	# Refresh: the clock resets (rank advanced this season) -> next pass restamps lower urgency.
	monk.tattoo_rank_reached_season = 4  # now at season 4
	_DO._assign_seek_tattoo_standing_objectives([monk], objectives_map, [], 360)
	var st2: Dictionary = objectives_map.get(1, {}).get("standing", {})
	_ok(int(st2.get("urgency_seasons", -1)) == 0, "urgency_seasons re-stamped to 0 after rank reset")
	# ic_day -1 (untracked) -> urgency 0 stamp, still assigns.
	var om3: Dictionary = {}
	_DO._assign_seek_tattoo_standing_objectives([monk], om3, [], -1)
	_ok(int(om3.get(1, {}).get("standing", {}).get("urgency_seasons", -1)) == 0, "ic_day -1 -> urgency 0")
