extends GutTest
## Tests for governance action wiring: APPOINT_TO_POSITION,
## ASSIGN_VASSAL_OBJECTIVE, CALL_COURT, SEND_INVITATION,
## and REASSIGN_VASSAL_OBJECTIVE strategic directive consumption.


var _dice: DiceEngine
var _time: TimeSystem


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)
	_time = TimeSystem.new()


func _make_char(id: int, clan: String = "Crane", status: float = 4.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC_" + str(id)
	c.clan = clan
	c.family = "Doji"
	c.school_type = Enums.SchoolType.COURTIER
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.honor = 5.0
	c.glory = 3.0
	c.status = status
	c.skills = {"Courtier": 3, "Etiquette": 3, "Calligraphy": 2, "Awareness": 3}
	c.emphases = {}
	c.reflexes = 3
	c.awareness = 3
	c.stamina = 3
	c.willpower = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	c.void_ring = 2
	c.wounds_taken = 0
	c.knowledge_pool = []
	c.known_contacts_by_clan = {}
	c.met_characters = []
	c.physical_location = "100"
	c.lord_id = -1
	ActionPointSystem.reset_daily_ap(c)
	return c


func _make_ctx(char: L5RCharacterData, flag: Enums.ContextFlag = Enums.ContextFlag.AT_OWN_HOLDINGS) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = char.character_id
	ctx.character_name = char.character_name
	ctx.clan = char.clan
	ctx.family = char.family
	ctx.school = "Doji Courtier"
	ctx.school_type = char.school_type
	ctx.is_lord = true
	ctx.location_id = char.physical_location
	ctx.context_flag = flag
	ctx.season = 1
	ctx.ic_day = 10
	ctx.honor = char.honor
	ctx.glory = char.glory
	ctx.status = char.status
	ctx.skill_ranks = char.skills
	return ctx


func _make_action(action_id: String, metadata: Dictionary = {}) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.metadata = metadata
	return a


# -- Context Action List Tests -------------------------------------------------

func test_call_court_in_at_own_holdings_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("CALL_COURT"), "CALL_COURT should be in AT_OWN_HOLDINGS")


func test_send_invitation_in_at_own_holdings_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("SEND_INVITATION"), "SEND_INVITATION should be in AT_OWN_HOLDINGS")


func test_assign_vassal_objective_in_at_own_holdings_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("ASSIGN_VASSAL_OBJECTIVE"), "ASSIGN_VASSAL_OBJECTIVE should be in AT_OWN_HOLDINGS")


func test_call_court_in_at_court_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("CALL_COURT"), "CALL_COURT should be in AT_COURT")


func test_send_invitation_in_at_court_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("SEND_INVITATION"), "SEND_INVITATION should be in AT_COURT")


func test_assign_vassal_objective_in_at_court_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("ASSIGN_VASSAL_OBJECTIVE"), "ASSIGN_VASSAL_OBJECTIVE should be in AT_COURT")


# -- Lord-Only Gating Tests ----------------------------------------------------

func test_lord_only_actions_blocked_for_non_lords() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = false
	for action_id: String in NPCDecisionEngine.LORD_ONLY_ACTIONS:
		assert_true(
			NPCDecisionEngine._is_lord_only_blocked(action_id, ctx),
			action_id + " should be blocked for non-lords"
		)


func test_lord_only_actions_allowed_for_lords() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = true
	for action_id: String in NPCDecisionEngine.LORD_ONLY_ACTIONS:
		assert_false(
			NPCDecisionEngine._is_lord_only_blocked(action_id, ctx),
			action_id + " should be allowed for lords"
		)


func test_non_lord_actions_not_blocked() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = false
	assert_false(NPCDecisionEngine._is_lord_only_blocked("CHARM", ctx))
	assert_false(NPCDecisionEngine._is_lord_only_blocked("TRAIN", ctx))
	assert_false(NPCDecisionEngine._is_lord_only_blocked("REST", ctx))


func test_governance_actions_not_in_traveling() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.TRAVELING
	)
	assert_false(actions.has("CALL_COURT"))
	assert_false(actions.has("SEND_INVITATION"))
	assert_false(actions.has("ASSIGN_VASSAL_OBJECTIVE"))


# -- Action Executor Tests -----------------------------------------------------

func test_appoint_to_position_returns_requires_flag() -> void:
	var char := _make_char(1)
	var ctx := _make_ctx(char)
	var action := _make_action("APPOINT_TO_POSITION", {
		"target_npc_id": 5,
		"position": "Clan Magistrate",
	})
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, _dice, {}
	)
	assert_true(result["success"])
	assert_eq(result["action_id"], "APPOINT_TO_POSITION")
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("requires_appointment", false))
	assert_eq(effects["appointee_id"], 5)
	assert_eq(effects["position"], "Clan Magistrate")
	assert_eq(effects["appointing_lord_id"], 1)


func test_assign_vassal_objective_returns_requires_flag() -> void:
	var char := _make_char(1)
	var ctx := _make_ctx(char)
	var action := _make_action("ASSIGN_VASSAL_OBJECTIVE", {
		"vassal_id": 10,
		"objective_type": "DEFEND_PROVINCE",
		"target_province_id": 42,
	})
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, _dice, {}
	)
	assert_true(result["success"])
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("requires_vassal_assignment", false))
	assert_eq(effects["vassal_id"], 10)
	assert_eq(effects["objective_type"], "DEFEND_PROVINCE")
	assert_eq(effects["target_province_id"], 42)


func test_call_court_returns_requires_flag() -> void:
	var char := _make_char(1)
	char.physical_location = "200"
	var ctx := _make_ctx(char)
	var action := _make_action("CALL_COURT", {
		"lord_id": 1,
		"settlement_id": "200",
	})
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, _dice, {}
	)
	assert_true(result["success"])
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("requires_court_creation", false))
	assert_eq(effects["host_lord_id"], 1)
	assert_eq(effects["host_settlement_id"], 200)
	assert_eq(effects["host_clan"], "Crane")


func test_call_court_fails_with_invalid_location() -> void:
	var char := _make_char(1)
	char.physical_location = "unknown"
	var ctx := _make_ctx(char)
	var action := _make_action("CALL_COURT")
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, _dice, {}
	)
	assert_false(result["success"])


func test_send_invitation_returns_requires_flag() -> void:
	var char := _make_char(1)
	var ctx := _make_ctx(char)
	var action := _make_action("SEND_INVITATION", {
		"invitee_id": 15,
		"lord_id": 1,
	})
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, _dice, {}
	)
	assert_true(result["success"])
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("requires_invitation", false))
	assert_eq(effects["invitee_id"], 15)
	assert_eq(effects["host_lord_id"], 1)


func test_send_invitation_fails_without_invitee() -> void:
	var char := _make_char(1)
	var ctx := _make_ctx(char)
	var action := _make_action("SEND_INVITATION", {
		"lord_id": 1,
	})
	var result: Dictionary = ActionExecutor.execute(
		action, char, ctx, _dice, {}
	)
	assert_false(result["success"])


# -- Day Orchestrator: Appointment Processing ----------------------------------

func test_appointment_mutates_character() -> void:
	var appointee := _make_char(5)
	appointee.role_position = ""
	var chars_by_id: Dictionary = {5: appointee}

	var effects: Dictionary = {
		"requires_appointment": true,
		"appointing_lord_id": 1,
		"appointee_id": 5,
		"position": "Provincial Magistrate",
	}
	var result: Dictionary = DayOrchestrator._apply_appointment(effects, chars_by_id)
	assert_true(result["applied"])
	assert_eq(appointee.role_position, "Provincial Magistrate")
	assert_eq(appointee.operational_superior_id, 1)


func test_appointment_fails_for_missing_character() -> void:
	var chars_by_id: Dictionary = {}
	var effects: Dictionary = {
		"requires_appointment": true,
		"appointee_id": 999,
		"position": "Magistrate",
	}
	var result: Dictionary = DayOrchestrator._apply_appointment(effects, chars_by_id)
	assert_false(result["applied"])


# -- Day Orchestrator: Vassal Objective Assignment -----------------------------

func test_vassal_assignment_creates_objective() -> void:
	var objectives_map: Dictionary = {}
	var effects: Dictionary = {
		"requires_vassal_assignment": true,
		"lord_id": 1,
		"vassal_id": 10,
		"objective_type": "DEFEND_PROVINCE",
		"target_province_id": 42,
	}
	var result: Dictionary = DayOrchestrator._apply_vassal_objective_assignment(
		effects, objectives_map
	)
	assert_true(result["applied"])
	assert_true(objectives_map.has(10))
	var standing: Dictionary = objectives_map[10].get("standing", {})
	assert_eq(standing["need_type"], "DEFEND_PROVINCE")
	assert_eq(standing["status"], "ACTIVE")
	assert_eq(standing["assigned_by"], 1)
	assert_eq(standing["target_province_id"], 42)


func test_vassal_assignment_overwrites_existing() -> void:
	var objectives_map: Dictionary = {
		10: {"standing": {"need_type": "REST", "status": "ACTIVE"}},
	}
	var effects: Dictionary = {
		"requires_vassal_assignment": true,
		"lord_id": 1,
		"vassal_id": 10,
		"objective_type": "PATROL_PROVINCE",
	}
	var result: Dictionary = DayOrchestrator._apply_vassal_objective_assignment(
		effects, objectives_map
	)
	assert_true(result["applied"])
	assert_eq(objectives_map[10]["standing"]["need_type"], "PATROL_PROVINCE")


func test_vassal_assignment_fails_without_vassal_id() -> void:
	var objectives_map: Dictionary = {}
	var effects: Dictionary = {
		"requires_vassal_assignment": true,
		"vassal_id": -1,
	}
	var result: Dictionary = DayOrchestrator._apply_vassal_objective_assignment(
		effects, objectives_map
	)
	assert_false(result["applied"])


# -- Day Orchestrator: Court Creation ------------------------------------------

func test_court_creation_adds_court() -> void:
	var active_courts: Array[CourtSessionData] = []
	var active_topics: Array[TopicData] = []
	var next_court_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]
	var world_states: Dictionary = {"current_season": 1}

	var effects: Dictionary = {
		"requires_court_creation": true,
		"host_lord_id": 1,
		"host_settlement_id": 200,
		"host_clan": "Crane",
	}
	var result: Dictionary = DayOrchestrator._apply_court_creation(
		effects, active_courts, active_topics,
		next_court_id, next_topic_id, 10, world_states,
	)
	assert_true(result["applied"])
	assert_eq(active_courts.size(), 1)
	assert_eq(active_courts[0].host_lord_id, 1)
	assert_eq(active_courts[0].host_settlement_id, 200)
	assert_eq(next_court_id[0], 2)


func test_court_creation_blocks_duplicate() -> void:
	var existing := CourtSessionData.new()
	existing.host_lord_id = 1
	existing.phase = CourtSessionData.CourtPhase.ACTIVE
	var active_courts: Array[CourtSessionData] = [existing]
	var active_topics: Array[TopicData] = []
	var next_court_id: Array[int] = [5]
	var world_states: Dictionary = {}

	var effects: Dictionary = {
		"requires_court_creation": true,
		"host_lord_id": 1,
		"host_settlement_id": 200,
		"host_clan": "Crane",
	}
	var result: Dictionary = DayOrchestrator._apply_court_creation(
		effects, active_courts, active_topics,
		next_court_id, [100], 10, world_states,
	)
	assert_false(result["applied"])
	assert_eq(result["reason"], "already_hosting")
	assert_eq(active_courts.size(), 1)


func test_court_creation_fails_without_settlement() -> void:
	var effects: Dictionary = {
		"requires_court_creation": true,
		"host_lord_id": 1,
		"host_settlement_id": -1,
		"host_clan": "Crane",
	}
	var result: Dictionary = DayOrchestrator._apply_court_creation(
		effects, [] as Array[CourtSessionData], [] as Array[TopicData],
		[1], [100], 10, {},
	)
	assert_false(result["applied"])


# -- Day Orchestrator: Invitation Processing -----------------------------------

func test_invitation_adds_letter() -> void:
	var pending_letters: Array = []
	var effects: Dictionary = {
		"requires_invitation": true,
		"invitee_id": 15,
		"host_lord_id": 1,
		"host_clan": "Crane",
	}
	var result: Dictionary = DayOrchestrator._apply_invitation(
		effects, pending_letters, 10
	)
	assert_true(result["applied"])
	assert_eq(pending_letters.size(), 1)
	var letter: Dictionary = pending_letters[0]
	assert_eq(letter["sender_id"], 1)
	assert_eq(letter["recipient_id"], 15)
	assert_eq(letter["letter_type"], "court_invitation")
	assert_eq(letter["ic_day_sent"], 10)


func test_invitation_fails_without_invitee() -> void:
	var pending_letters: Array = []
	var effects: Dictionary = {
		"requires_invitation": true,
		"invitee_id": -1,
		"host_lord_id": 1,
	}
	var result: Dictionary = DayOrchestrator._apply_invitation(
		effects, pending_letters, 10
	)
	assert_false(result["applied"])
	assert_eq(pending_letters.size(), 0)


# -- Strategic Review: Vassal Reassignment Directive Consumption ---------------

func test_reassign_directive_assigns_new_objective() -> void:
	var objectives_map: Dictionary = {5: {}}
	var chars_by_id: Dictionary = {}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": 5,
		"decision": "ASSIGN",
		"new_objective": {"need_type": "DEFEND_PROVINCE", "target_province_id": 10},
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, chars_by_id
	)

	var standing: Dictionary = objectives_map[5].get("standing", {})
	assert_eq(standing["need_type"], "DEFEND_PROVINCE")
	assert_eq(standing["status"], "ACTIVE")
	assert_eq(standing["assigned_by"], 1)


func test_reassign_directive_creates_objectives_map_entry() -> void:
	var objectives_map: Dictionary = {}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 2,
		"vassal_id": 7,
		"decision": "ASSIGN",
		"new_objective": {"need_type": "PATROL_PROVINCE"},
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
	)

	assert_true(objectives_map.has(7))
	assert_eq(objectives_map[7]["standing"]["need_type"], "PATROL_PROVINCE")


func test_reassign_directive_confirm_resolves_orphan() -> void:
	var objectives_map: Dictionary = {
		5: {"standing": {"need_type": "DEFEND_PROVINCE", "status": "ORPHANED"}},
	}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": 5,
		"decision": "CONFIRM",
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
	)

	assert_eq(objectives_map[5]["standing"]["status"], "ACTIVE")


func test_reassign_directive_cancel_removes_objective() -> void:
	var objectives_map: Dictionary = {
		5: {"standing": {"need_type": "DEFEND_PROVINCE", "status": "ORPHANED"}},
	}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": 5,
		"decision": "CANCEL",
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
	)

	assert_false(objectives_map[5].has("standing"))


func test_reassign_directive_skips_non_vassal_directives() -> void:
	var objectives_map: Dictionary = {}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.CALL_COURT,
		"lord_id": 1,
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
	)

	assert_eq(objectives_map.size(), 0)


func test_reassign_directive_skips_invalid_vassal_id() -> void:
	var objectives_map: Dictionary = {}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": -1,
		"decision": "ASSIGN",
		"new_objective": {"need_type": "REST"},
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
	)

	assert_eq(objectives_map.size(), 0)


# -- Metadata Population Tests ------------------------------------------------

func test_appoint_metadata_populated() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 5
	need.target_intent = "Provincial Magistrate"
	var ctx := _make_ctx(_make_char(1))
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "APPOINT_TO_POSITION"

	NPCDecisionEngine._populate_action_metadata(option, need, ctx)

	assert_eq(option.metadata.get("target_npc_id"), 5)
	assert_eq(option.metadata.get("position"), "Provincial Magistrate")


func test_assign_vassal_metadata_populated() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 10
	need.target_intent = "DEFEND_PROVINCE"
	need.target_province_id = 42
	var ctx := _make_ctx(_make_char(1))
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "ASSIGN_VASSAL_OBJECTIVE"

	NPCDecisionEngine._populate_action_metadata(option, need, ctx)

	assert_eq(option.metadata.get("vassal_id"), 10)
	assert_eq(option.metadata.get("objective_type"), "DEFEND_PROVINCE")
	assert_eq(option.metadata.get("target_province_id"), 42)


func test_call_court_metadata_populated() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	var ctx := _make_ctx(_make_char(1))
	ctx.location_id = "200"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CALL_COURT"

	NPCDecisionEngine._populate_action_metadata(option, need, ctx)

	assert_eq(option.metadata.get("lord_id"), 1)
	assert_eq(option.metadata.get("settlement_id"), "200")


func test_send_invitation_metadata_populated() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 15
	var ctx := _make_ctx(_make_char(1))
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "SEND_INVITATION"

	NPCDecisionEngine._populate_action_metadata(option, need, ctx)

	assert_eq(option.metadata.get("invitee_id"), 15)
	assert_eq(option.metadata.get("lord_id"), 1)


# -- Integration: Full Day Orchestrator Flow -----------------------------------

func test_governance_effects_processed_in_advance_day() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	lord.physical_location = "100"
	var vassal := _make_char(5, "Crane", 3.0)
	vassal.lord_id = 1
	var appointee := _make_char(10, "Crane", 2.0)
	appointee.role_position = ""

	var characters: Array[L5RCharacterData] = [lord, vassal, appointee]
	var chars_by_id: Dictionary = {1: lord, 5: vassal, 10: appointee}
	var objectives_map: Dictionary = {}
	var scoring_tables: Dictionary = ScoringTableLoader.get_scoring_tables()
	var filter_data: Dictionary = ScoringTableLoader.get_filter_data()
	var action_skill_map: Dictionary = ScoringTableLoader.load_action_skill_map()

	var result: Dictionary = DayOrchestrator.advance_day(
		_time, characters, chars_by_id,
		{"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS, "is_lord": true},
		objectives_map, scoring_tables, filter_data, _dice, action_skill_map,
		{}, [], {},
	)

	assert_true(result.has("governance_results"))
	var gov: Dictionary = result["governance_results"]
	assert_true(gov.has("appointments"))
	assert_true(gov.has("vassal_assignments"))
	assert_true(gov.has("court_creations"))
	assert_true(gov.has("invitations"))
