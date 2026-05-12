extends GutTest
## Tests for governance action wiring: APPOINT_TO_POSITION (daily AP action),
## REASSIGN_VASSAL_OBJECTIVE (strategic review directive consumption),
## and lord-only action gating.
## CALL_COURT and ASSIGN_VASSAL_OBJECTIVE run through Strategic Review.
## SEND_INVITATION runs through the free daily letter system.


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


# -- Context Action List: APPOINT_TO_POSITION ---------------------------------

func test_appoint_in_at_own_holdings_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("APPOINT_TO_POSITION"))


func test_appoint_in_at_court_actions() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("APPOINT_TO_POSITION"))


func test_appoint_not_in_traveling() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.TRAVELING
	)
	assert_false(actions.has("APPOINT_TO_POSITION"))


# -- Strategic Review Actions NOT in Daily AP Loop -----------------------------

func test_call_court_not_in_daily_action_lists() -> void:
	var holdings: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	var court: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_false(holdings.has("CALL_COURT"), "CALL_COURT uses Strategic Review, not daily AP")
	assert_false(court.has("CALL_COURT"))


func test_assign_vassal_not_in_daily_action_lists() -> void:
	var holdings: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	var court: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_false(holdings.has("ASSIGN_VASSAL_OBJECTIVE"), "ASSIGN_VASSAL uses Strategic Review")
	assert_false(court.has("ASSIGN_VASSAL_OBJECTIVE"))


func test_send_invitation_not_in_daily_action_lists() -> void:
	var holdings: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	var court: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_false(holdings.has("SEND_INVITATION"), "SEND_INVITATION uses letter system")
	assert_false(court.has("SEND_INVITATION"))


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


func test_appoint_blocked_for_non_lord() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = false
	assert_true(NPCDecisionEngine._is_lord_only_blocked("APPOINT_TO_POSITION", ctx))


func test_declare_war_blocked_for_non_lord() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = false
	assert_true(NPCDecisionEngine._is_lord_only_blocked("DECLARE_WAR", ctx))


# -- Action Executor: APPOINT_TO_POSITION --------------------------------------

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


func test_appoint_fails_without_target() -> void:
	var char := _make_char(1)
	var ctx := _make_ctx(char)
	var action := _make_action("APPOINT_TO_POSITION", {})
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


# -- Strategic Review: Vassal Reassignment Directive Consumption ---------------

func test_reassign_directive_assigns_new_objective() -> void:
	var objectives_map: Dictionary = {5: {}}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": 5,
		"decision": "ASSIGN",
		"new_objective": {"need_type": "DEFEND_PROVINCE", "target_province_id": 10},
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
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


# -- Integration: governance_results in advance_day ----------------------------

func test_governance_results_in_advance_day() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	lord.physical_location = "100"

	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}
	var scoring_tables: Dictionary = ScoringTableLoader.get_scoring_tables()
	var filter_data: Dictionary = ScoringTableLoader.get_filter_data()
	var action_skill_map: Dictionary = ScoringTableLoader.load_action_skill_map()

	var result: Dictionary = DayOrchestrator.advance_day(
		_time, characters, chars_by_id,
		{"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS, "is_lord": true},
		{}, scoring_tables, filter_data, _dice, action_skill_map,
		{}, [], {},
	)

	assert_true(result.has("governance_results"))
	var gov: Dictionary = result["governance_results"]
	assert_true(gov.has("appointments"))


# -- Vacancy Scanner Expansion Tests -------------------------------------------


func _make_settlement(id: int, province_id: int, stype: Enums.SettlementType) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.settlement_type = stype
	s.population_pu = 5.0
	s.garrison_pu = 1.0
	return s


func _make_province(id: int, clan: String) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.province_name = "Prov_" + str(id)
	p.clan = clan
	return p


func test_vacancy_detects_garrison_commander_for_fortification() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	lord.lord_id = -1
	var vassal := _make_char(2, "Crane", 2.0)
	vassal.lord_id = 1
	var characters: Array[L5RCharacterData] = [lord, vassal]
	var chars_by_id: Dictionary = {1: lord, 2: vassal}

	var prov := _make_province(10, "Crane")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array[SettlementData] = [fort]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var found_garrison: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			found_garrison = true
			assert_eq(v["priority"], 3)
			assert_eq(v["province_id"], 10)
			assert_eq(v["settlement_id"], 100)
	assert_true(found_garrison, "Should detect garrison commander vacancy for fortification")


func test_vacancy_detects_temple_head() -> void:
	var lord := _make_char(1, "Phoenix", 5.0)
	lord.lord_id = -1
	lord.clan = "Phoenix"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Phoenix")
	var provinces: Dictionary = {10: prov}
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array[SettlementData] = [temple]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var found_temple: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Temple Head":
			found_temple = true
			assert_eq(v["priority"], 2)
	assert_true(found_temple, "Should detect temple head vacancy")


func test_vacancy_detects_monastery_abbot() -> void:
	var lord := _make_char(1, "Dragon", 5.0)
	lord.lord_id = -1
	lord.clan = "Dragon"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Dragon")
	var provinces: Dictionary = {10: prov}
	var monastery := _make_settlement(100, 10, Enums.SettlementType.MONASTERY)
	var settlements: Array[SettlementData] = [monastery]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var found_abbot: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Monastery Abbot":
			found_abbot = true
			assert_eq(v["priority"], 2)
	assert_true(found_abbot, "Should detect monastery abbot vacancy")


func test_vacancy_no_duplicate_garrison_for_multiple_forts() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort1 := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var fort2 := _make_settlement(101, 10, Enums.SettlementType.KEEP)
	var settlements: Array[SettlementData] = [fort1, fort2]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var garrison_count: int = 0
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			garrison_count += 1
	assert_eq(garrison_count, 1, "Should only generate one garrison vacancy per lord")


func test_vacancy_skips_filled_garrison_commander() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var commander := _make_char(2, "Crab", 3.0)
	commander.lord_id = 1
	commander.role_position = "Garrison Commander"
	var characters: Array[L5RCharacterData] = [lord, commander]
	var chars_by_id: Dictionary = {1: lord, 2: commander}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array[SettlementData] = [fort]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var found_garrison: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			found_garrison = true
	assert_false(found_garrison, "Should not detect vacancy when garrison commander exists")


func test_vacancy_skips_filled_temple_head() -> void:
	var lord := _make_char(1, "Phoenix", 5.0)
	lord.lord_id = -1
	lord.clan = "Phoenix"
	var head := _make_char(2, "Phoenix", 3.0)
	head.lord_id = 1
	head.role_position = "Temple Head"
	var characters: Array[L5RCharacterData] = [lord, head]
	var chars_by_id: Dictionary = {1: lord, 2: head}

	var prov := _make_province(10, "Phoenix")
	var provinces: Dictionary = {10: prov}
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array[SettlementData] = [temple]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var found_temple: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Temple Head":
			found_temple = true
	assert_false(found_temple, "Should not detect vacancy when temple head exists")


func test_vacancy_candidate_selection_prefers_high_score() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	lord.lord_id = -1
	var weak := _make_char(2, "Crane", 1.0)
	weak.lord_id = 1
	weak.honor = 2.0
	weak.glory = 1.0
	var strong := _make_char(3, "Crane", 3.0)
	strong.lord_id = 1
	strong.honor = 6.0
	strong.glory = 4.0
	var characters: Array[L5RCharacterData] = [lord, weak, strong]
	var chars_by_id: Dictionary = {1: lord, 2: weak, 3: strong}

	var prov := _make_province(10, "Crane")
	var provinces: Dictionary = {10: prov}
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array[SettlementData] = [temple]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Temple Head":
			assert_eq(v["candidate_id"], 3, "Should pick highest-scoring vassal")


func test_vacancy_no_settlement_detection_without_settlements() -> void:
	var lord := _make_char(1, "Lion", 5.0)
	lord.lord_id = -1
	lord.clan = "Lion"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var settlement_vacancies: int = 0
	for v: Dictionary in vacancies:
		if v.get("position_type", "") in ["Garrison Commander", "Temple Head", "Monastery Abbot"]:
			settlement_vacancies += 1
	assert_eq(settlement_vacancies, 0, "No settlement vacancies when no settlements provided")


func test_vacancy_village_does_not_trigger_garrison() -> void:
	var lord := _make_char(1, "Lion", 5.0)
	lord.lord_id = -1
	lord.clan = "Lion"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Lion")
	var provinces: Dictionary = {10: prov}
	var village := _make_settlement(100, 10, Enums.SettlementType.VILLAGE)
	var settlements: Array[SettlementData] = [village]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var found_garrison: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			found_garrison = true
	assert_false(found_garrison, "Village should not trigger garrison commander vacancy")


func test_vacancy_per_lord_key_includes_settlement_vacancies() -> void:
	var lord := _make_char(1, "Scorpion", 5.0)
	lord.lord_id = -1
	lord.clan = "Scorpion"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Scorpion")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.CASTLE)
	var settlements: Array[SettlementData] = [fort]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces)

	var per_lord_key: String = "vacant_positions_1"
	assert_true(ws.has(per_lord_key), "Per-lord key should exist")
	var per_lord: Array = ws[per_lord_key]
	var found_garrison: bool = false
	for v: Dictionary in per_lord:
		if v.get("position_type", "") == "Garrison Commander":
			found_garrison = true
	assert_true(found_garrison, "Per-lord flat list should include settlement vacancies")


# -- School Master Vacancy Detection Tests --------------------------------------


func test_vacancy_detects_school_master_for_family() -> void:
	var lord := _make_char(1, "Crab", 7.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var school_master_count: int = 0
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "School Master":
			school_master_count += 1
			assert_eq(v["priority"], 2)
	# Crab has 5 families (Hida, Hiruma, Kaiu, Kuni, Yasuki) — all have schools
	assert_true(school_master_count >= 1, "Should detect school master vacancies for clan families")


func test_vacancy_skips_filled_school_master() -> void:
	var lord := _make_char(1, "Crab", 7.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var master := _make_char(2, "Crab", 5.0)
	master.lord_id = 1
	master.family = "Hida"
	master.role_position = "School Master"
	var characters: Array[L5RCharacterData] = [lord, master]
	var chars_by_id: Dictionary = {1: lord, 2: master}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var hida_master_found: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "School Master" and v.get("family", "") == "Hida":
			hida_master_found = true
	assert_false(hida_master_found, "Should not detect vacancy for Hida when school master exists")


func test_vacancy_school_master_has_family_field() -> void:
	var lord := _make_char(1, "Dragon", 7.0)
	lord.lord_id = -1
	lord.clan = "Dragon"
	var characters: Array[L5RCharacterData] = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var families_found: Array[String] = []
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "School Master":
			assert_true(v.has("family"), "School Master vacancy should include family field")
			families_found.append(v.get("family", ""))
	# Dragon has 3 families: Mirumoto, Kitsuki, Tamori
	assert_eq(families_found.size(), 3, "Should detect vacancies for all 3 Dragon families")


func test_vacancy_school_master_only_for_clans_with_lords() -> void:
	# No lord character with status >= 5.0 for Lion → no school master vacancies
	var low_status := _make_char(1, "Lion", 3.0)
	low_status.lord_id = -1
	low_status.clan = "Lion"
	var characters: Array[L5RCharacterData] = [low_status]
	var chars_by_id: Dictionary = {1: low_status}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var school_master_count: int = 0
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "School Master":
			school_master_count += 1
	assert_eq(school_master_count, 0, "No school master vacancies when no lord with status >= 5")
