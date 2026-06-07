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


# === Tranche 9: dual-stance topic positions (s54.7f) ===

func _pos_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 20}      # mild public support
	ctx.kolat_positions = {1: -100}    # true Kolat stance: maximum opposition
	return ctx


func _pos_tables() -> Dictionary:
	return {"topic_position_alignment": {"T": {"strong_support": 15, "strong_opposition": -15}}}


func test_dual_stance_substitutes_kolat_position() -> void:
	var ctx := _pos_ctx()
	var mod := NPCDecisionEngine._compute_topic_position_modifier("X", _need("T"), ctx, _pos_tables())
	assert_eq(mod, -15.0, "kolat_positions stance (-100) drives the modifier, not the mild public +20")


func test_dual_stance_falls_back_to_known_positions() -> void:
	var ctx := _pos_ctx()
	ctx.kolat_positions = {}  # no Kolat entry for this topic
	var mod := NPCDecisionEngine._compute_topic_position_modifier("X", _need("T"), ctx, _pos_tables())
	assert_true(mod > 0.0 and mod < 15.0, "with no kolat stance, the mild public +20 is used")


func test_build_context_populates_kolat_positions_for_agents_only() -> void:
	var agent := _coin_master(40)
	agent.is_kolat_master = false
	agent.kolat_sect = Enums.KolatSect.SILK
	agent.kolat_positions = {7: -100}
	var ctx_agent := NPCDecisionEngine.build_context(agent, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS})
	assert_eq(ctx_agent.kolat_positions.get(7), -100, "conscious agent's kolat_positions reach context")

	var plain := _coin_master(41)
	plain.is_kolat_master = false
	plain.kolat_sect = Enums.KolatSect.NONE
	plain.kolat_positions = {7: -100}  # should be ignored — not a conscious agent
	var ctx_plain := NPCDecisionEngine.build_context(plain, {"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS})
	assert_true(ctx_plain.kolat_positions.is_empty(), "non-Kolat characters carry no dual stance")


# === Tranche 12: Sect standing-objective mandate (s54.7b) ===

func test_standing_needtype_explicit_sects() -> void:
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.SILK), "MAINTAIN_KOLAT_NETWORK")
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.COIN), "MANAGE_KOLAT_FUNDS")
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.DREAM), "MAINTAIN_SLEEPER")


func test_standing_needtype_structural_sects() -> void:
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.TIGER), "MONITOR_KOLAT_SECURITY")
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.JADE), "ASSESS_SUPERNATURAL_THREAT")
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.STEEL), "MONITOR_TEMPLE_PERIMETER")


func test_standing_needtype_empty_for_roc() -> void:
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.ROC), "",
		"Roc is inactive at launch (s54.7b)")


func test_standing_needtype_lotus_owner_decision() -> void:
	assert_eq(KolatSystem.standing_needtype_for_sect(Enums.KolatSect.LOTUS),
		"MAINTAIN_DEAD_DROP_SCHEDULE", "Lotus standing per owner decision 2026-06-06")


func test_assign_kolat_standing_sets_mandate_for_master() -> void:
	var coin := _coin_master(50)
	var omap: Dictionary = {}
	DayOrchestrator._assign_kolat_standing_objectives([coin], omap)
	assert_eq(omap[50]["standing"]["need_type"], "MANAGE_KOLAT_FUNDS")
	assert_true(omap[50]["standing"]["auto_assigned"])


func test_assign_kolat_standing_skips_non_master_and_roc() -> void:
	var agent := _coin_master(51)
	agent.is_kolat_master = false  # conscious agent, not a Master
	var roc := _coin_master(52)
	roc.kolat_sect = Enums.KolatSect.ROC
	var omap: Dictionary = {}
	DayOrchestrator._assign_kolat_standing_objectives([agent, roc], omap)
	assert_false(omap.has(51), "non-Masters get no Sect standing mandate")
	assert_false(omap.has(52) and omap[52].get("standing", {}).has("need_type"),
		"Roc Master gets no standing mandate")


func test_assign_kolat_standing_does_not_overwrite_existing() -> void:
	var coin := _coin_master(53)
	var omap: Dictionary = {53: {"standing": {"need_type": "UPHOLD_LAW", "priority": 4}}}
	DayOrchestrator._assign_kolat_standing_objectives([coin], omap)
	assert_eq(omap[53]["standing"]["need_type"], "UPHOLD_LAW",
		"an existing standing objective is never overwritten")


# === Phase-2 Kolat objective cascade (s54.7d) ===

func test_kolat_objective_priority3_fires_before_primary() -> void:
	var c := _coin_master(60)
	var ctx := _ctx_for(c)
	var objectives := {
		"primary": {"need_type": "ACQUIRE_RESOURCE", "priority": 2},
		"kolat": {"need_type": "MANAGE_KOLAT_FUNDS", "priority": 3, "kolat_objective": true},
	}
	var need := NPCDecisionEngine.resolve_goal(c, ctx, objectives)
	assert_eq(need.need_type, "MANAGE_KOLAT_FUNDS",
		"priority-3 Kolat objective fires before the primary")


func test_kolat_objective_priority1_yields_to_primary() -> void:
	var c := _coin_master(61)
	var ctx := _ctx_for(c)
	var objectives := {
		"primary": {"need_type": "ACQUIRE_RESOURCE", "priority": 2},
		"kolat": {"need_type": "MANAGE_KOLAT_FUNDS", "priority": 1, "kolat_objective": true},
	}
	var need := NPCDecisionEngine.resolve_goal(c, ctx, objectives)
	assert_eq(need.need_type, "ACQUIRE_RESOURCE",
		"priority-1 Kolat objective yields to the primary")


func test_kolat_objective_precedes_standing_when_no_primary() -> void:
	var c := _coin_master(62)
	var ctx := _ctx_for(c)
	var objectives := {
		"standing": {"need_type": "UPHOLD_LAW", "priority": 4},
		"kolat": {"need_type": "MANAGE_KOLAT_FUNDS", "priority": 1, "kolat_objective": true},
	}
	var need := NPCDecisionEngine.resolve_goal(c, ctx, objectives)
	assert_eq(need.need_type, "MANAGE_KOLAT_FUNDS",
		"priority-1 Kolat objective precedes the standing objective")
