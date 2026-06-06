extends GutTest
## Integration tests for the Kolat NPC-engine pipeline wiring (s54.7c/d/e):
## Phase-3 ActionID unlock, sleeper override loop, and ActionExecutor dispatch.

var _scoring: Dictionary


func before_all() -> void:
	var f := FileAccess.open("res://systems/npc_engine/data/tables/objective_alignment.json", FileAccess.READ)
	_scoring = {"objective_alignment": JSON.parse_string(f.get_as_text())}


func _coin_master(id: int = 1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.reflexes = 4; c.awareness = 4; c.stamina = 4; c.willpower = 4
	c.agility = 4; c.intelligence = 4; c.strength = 4; c.perception = 4
	c.void_ring = 4
	c.is_kolat_master = true
	c.kolat_sect = Enums.KolatSect.COIN
	c.skills = {"Commerce (Appraisal)": 6, "Commerce (Mathematics)": 6}
	return c


func _need(nt: String) -> NPCDataStructures.ImmediateNeed:
	var n := NPCDataStructures.ImmediateNeed.new()
	n.need_type = nt
	n.priority = 2
	return n


func _ctx_for(c: L5RCharacterData) -> NPCDataStructures.ContextSnapshot:
	return NPCDecisionEngine.build_context(c, {
		"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
		"has_kolat_objective": true,
	})


# === Phase-3 ActionID unlock ===

func test_kolat_master_unlocks_koku_actions() -> void:
	var c := _coin_master()
	var ctx := _ctx_for(c)
	var opts := NPCDecisionEngine.generate_options(ctx, _need("MANAGE_KOLAT_FUNDS"), c, {})
	opts = NPCDecisionEngine.apply_allowlist_filter(opts, "MANAGE_KOLAT_FUNDS", _scoring)
	var ids: Array = opts.map(func(o: NPCDataStructures.ScoredAction) -> String: return o.action_id)
	assert_true("LAUNDER_KOKU" in ids, "Kolat master unlocks LAUNDER_KOKU under MANAGE_KOLAT_FUNDS")
	assert_true("UNDERREPORT_KOKU" in ids)
	assert_true("TRANSFER_KOLAT_FUNDS" in ids)


func test_non_kolat_does_not_unlock() -> void:
	var c := _coin_master()
	c.is_kolat_master = false
	c.kolat_sect = Enums.KolatSect.NONE
	var ctx := NPCDecisionEngine.build_context(c, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS})
	var opts := NPCDecisionEngine.generate_options(ctx, _need("MANAGE_KOLAT_FUNDS"), c, {})
	var ids: Array = opts.map(func(o: NPCDataStructures.ScoredAction) -> String: return o.action_id)
	assert_false("LAUNDER_KOKU" in ids, "non-Kolat characters never see Kolat actions")


func test_agent_needs_kolat_objective_flag() -> void:
	var c := _coin_master()
	c.is_kolat_master = false  # conscious agent, not a Master
	# No has_kolat_objective → no unlock.
	var ctx := NPCDecisionEngine.build_context(c, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS})
	var opts := NPCDecisionEngine.generate_options(ctx, _need("MANAGE_KOLAT_FUNDS"), c, {})
	var ids: Array = opts.map(func(o: NPCDataStructures.ScoredAction) -> String: return o.action_id)
	assert_false("LAUNDER_KOKU" in ids, "agent without an active Kolat objective stays locked")


# === Sleeper override loop ===

func test_sleeper_override_bypasses_normal_loop() -> void:
	var c := _coin_master(5)
	c.is_kolat_master = false
	c.kolat_sect = Enums.KolatSect.NONE
	c.active_sleeper_command = {"need_type": "ELIMINATE_CHARACTER", "target_npc_id": 99}
	var result := NPCDecisionEngine.run(c, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS},
		{}, _scoring, {"bushido": {}, "shourido": {}})
	assert_true(result.get("sleeper_override", false), "activated sleeper runs the override loop")
	assert_true(result.get("memory_suppressed", false), "override actions are memory-suppressed")
	assert_eq(result.get("need_type"), "ELIMINATE_CHARACTER")


# === ActionExecutor dispatch ===

func test_action_executor_routes_launder() -> void:
	var c := _coin_master(7)
	c.dirty_koku = 12
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "LAUNDER_KOKU"
	var ctx := _ctx_for(c)
	var res := ActionExecutor.execute(action, c, ctx, DiceEngine.new(1), {})
	assert_true(res["success"], "LAUNDER_KOKU routes to KolatExecutor and succeeds")
	assert_eq(c.kolat_koku, 5)
	assert_eq(c.dirty_koku, 7)


func test_action_executor_deferred_kolat_action() -> void:
	var c := _coin_master(8)
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ARCHIVE_TOPIC"
	var ctx := _ctx_for(c)
	var res := ActionExecutor.execute(action, c, ctx, DiceEngine.new(1), {})
	assert_false(res["success"], "topic/spell Kolat actions are deferred")
	assert_eq(res["reason"], "deferred_system")


# === Tranche 6: metadata + sleeper completion ===

func test_activate_sleeper_metadata_carries_trigger_phrase() -> void:
	var master := _coin_master(20)
	var sleeper := _coin_master(21)
	sleeper.is_kolat_master = false
	sleeper.kolat_sect = Enums.KolatSect.NONE
	sleeper.trigger_phrase = "the river runs north"
	var ctx := _ctx_for(master)
	var need := _need("CONDITION_SLEEPER")
	need.target_npc_id = 21
	var opts := NPCDecisionEngine.generate_options(ctx, need, master, {21: sleeper})
	var act: NPCDataStructures.ScoredAction = null
	for o: NPCDataStructures.ScoredAction in opts:
		if o.action_id == "ACTIVATE_SLEEPER":
			act = o
			break
	assert_not_null(act, "ACTIVATE_SLEEPER is in the unlocked pool")
	assert_eq(act.metadata.get("spoken_phrase"), "the river runs north")
	assert_eq(act.metadata.get("target"), sleeper)


func test_sleeper_command_clears_when_target_dead() -> void:
	var sleeper := _coin_master(30)
	sleeper.is_kolat_master = false
	sleeper.kolat_sect = Enums.KolatSect.NONE
	sleeper.active_sleeper_command = {"need_type": "ELIMINATE_CHARACTER", "target_npc_id": 99}
	var victim := L5RCharacterData.new()
	victim.character_id = 99
	victim.wounds_taken = 9999  # dead
	var result := NPCDecisionEngine.run(sleeper, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS},
		{}, _scoring, {"bushido": {}, "shourido": {}}, [], [], 0, {99: victim})
	assert_false(result.get("sleeper_override", false), "completed kill order returns to normal behavior")
	assert_true(sleeper.active_sleeper_command.is_empty(), "completed command is cleared")


func test_sleeper_command_persists_while_target_alive() -> void:
	var sleeper := _coin_master(31)
	sleeper.is_kolat_master = false
	sleeper.kolat_sect = Enums.KolatSect.NONE
	sleeper.active_sleeper_command = {"need_type": "ELIMINATE_CHARACTER", "target_npc_id": 98}
	var victim := L5RCharacterData.new()
	victim.character_id = 98  # alive
	var result := NPCDecisionEngine.run(sleeper, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS},
		{}, _scoring, {"bushido": {}, "shourido": {}}, [], [], 0, {98: victim})
	assert_true(result.get("sleeper_override", false), "live target keeps the override active")
	assert_false(sleeper.active_sleeper_command.is_empty(), "command persists while target alive")
