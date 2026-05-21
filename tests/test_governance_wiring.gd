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
	var actions: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("APPOINT_TO_POSITION"))


func test_appoint_in_at_court_actions() -> void:
	var actions: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("APPOINT_TO_POSITION"))


func test_appoint_not_in_traveling() -> void:
	var actions: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.TRAVELING
	)
	assert_false(actions.has("APPOINT_TO_POSITION"))


# -- Strategic Review Actions NOT in Daily AP Loop -----------------------------

func test_call_court_not_in_daily_action_lists() -> void:
	var holdings: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	var court: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_false(holdings.has("CALL_COURT"), "CALL_COURT uses Strategic Review, not daily AP")
	assert_false(court.has("CALL_COURT"))


func test_assign_vassal_not_in_daily_action_lists() -> void:
	var holdings: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	var court: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_false(holdings.has("ASSIGN_VASSAL_OBJECTIVE"), "ASSIGN_VASSAL uses Strategic Review")
	assert_false(court.has("ASSIGN_VASSAL_OBJECTIVE"))


func test_send_invitation_not_in_daily_action_lists() -> void:
	var holdings: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	var court: Array = NPCDecisionEngine._get_actions_for_context(
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
	var strategic_results: Array = [{
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
	var strategic_results: Array = [{
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
	var strategic_results: Array = [{
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
	var strategic_results: Array = [{
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
	var strategic_results: Array = [{
		"directive": StrategicReview.Directive.CALL_COURT,
		"lord_id": 1,
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, {}
	)

	assert_eq(objectives_map.size(), 0)


func test_reassign_directive_skips_invalid_vassal_id() -> void:
	var objectives_map: Dictionary = {}
	var strategic_results: Array = [{
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

	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}
	var _loader := ScoringTableLoader.new()
	_loader.load_all()
	var scoring_tables: Dictionary = _loader.get_scoring_tables()
	var filter_data: Dictionary = _loader.get_filter_data()
	var action_skill_map: Dictionary = _loader.get_table("action_skill_map")

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
	var characters: Array = [lord, vassal]
	var chars_by_id: Dictionary = {1: lord, 2: vassal}

	var prov := _make_province(10, "Crane")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array = [fort]

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
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Phoenix")
	var provinces: Dictionary = {10: prov}
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array = [temple]

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
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Dragon")
	var provinces: Dictionary = {10: prov}
	var monastery := _make_settlement(100, 10, Enums.SettlementType.MONASTERY)
	var settlements: Array = [monastery]

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
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort1 := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var fort2 := _make_settlement(101, 10, Enums.SettlementType.KEEP)
	var settlements: Array = [fort1, fort2]

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
	var characters: Array = [lord, commander]
	var chars_by_id: Dictionary = {1: lord, 2: commander}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array = [fort]

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
	var characters: Array = [lord, head]
	var chars_by_id: Dictionary = {1: lord, 2: head}

	var prov := _make_province(10, "Phoenix")
	var provinces: Dictionary = {10: prov}
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array = [temple]

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
	var characters: Array = [lord, weak, strong]
	var chars_by_id: Dictionary = {1: lord, 2: weak, 3: strong}

	var prov := _make_province(10, "Crane")
	var provinces: Dictionary = {10: prov}
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array = [temple]

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
	var characters: Array = [lord]
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
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Lion")
	var provinces: Dictionary = {10: prov}
	var village := _make_settlement(100, 10, Enums.SettlementType.VILLAGE)
	var settlements: Array = [village]

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
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Scorpion")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.CASTLE)
	var settlements: Array = [fort]

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
	var characters: Array = [lord]
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
	var characters: Array = [lord, master]
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
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var families_found: Array = []
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
	var characters: Array = [low_status]
	var chars_by_id: Dictionary = {1: low_status}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {})

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	var school_master_count: int = 0
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "School Master":
			school_master_count += 1
	assert_eq(school_master_count, 0, "No school master vacancies when no lord with status >= 5")


# -- Position-Specific Candidate Scoring Tests ----------------------------------


func test_candidate_scoring_magistrate_prefers_investigation_skill() -> void:
	var lord := _make_char(1, "Lion", 5.0)
	lord.lord_id = -1
	lord.clan = "Lion"
	var bushi := _make_char(2, "Lion", 2.0)
	bushi.lord_id = 1
	bushi.honor = 3.0
	bushi.glory = 2.0
	bushi.skills = {"Battle": 4, "Kenjutsu": 3}
	var investigator := _make_char(3, "Lion", 2.0)
	investigator.lord_id = 1
	investigator.honor = 3.0
	investigator.glory = 2.0
	investigator.skills = {"Investigation": 4, "Lore: Law": 3}
	var characters: Array = [lord, bushi, investigator]
	var chars_by_id: Dictionary = {1: lord, 2: bushi, 3: investigator}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Clan Magistrate", characters, chars_by_id,
	)
	assert_eq(result, 3, "Investigator should score higher for magistrate position")


func test_candidate_scoring_garrison_prefers_battle_skill() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var courtier := _make_char(2, "Crab", 2.0)
	courtier.lord_id = 1
	courtier.honor = 3.0
	courtier.glory = 2.0
	courtier.skills = {"Courtier": 4, "Etiquette": 3}
	var warrior := _make_char(3, "Crab", 2.0)
	warrior.lord_id = 1
	warrior.honor = 3.0
	warrior.glory = 2.0
	warrior.skills = {"Battle": 4, "Defense": 3, "Kenjutsu": 2}
	var characters: Array = [lord, courtier, warrior]
	var chars_by_id: Dictionary = {1: lord, 2: courtier, 3: warrior}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Garrison Commander", characters, chars_by_id,
	)
	assert_eq(result, 3, "Warrior should score higher for garrison commander")


func test_candidate_scoring_virtue_bonus_for_magistrate() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	lord.lord_id = -1
	var base := _make_char(2, "Crane", 2.0)
	base.lord_id = 1
	base.honor = 3.0
	base.glory = 2.0
	base.bushido_virtue = Enums.BushidoVirtue.YU
	var virtuous := _make_char(3, "Crane", 2.0)
	virtuous.lord_id = 1
	virtuous.honor = 3.0
	virtuous.glory = 2.0
	virtuous.bushido_virtue = Enums.BushidoVirtue.GI
	var characters: Array = [lord, base, virtuous]
	var chars_by_id: Dictionary = {1: lord, 2: base, 3: virtuous}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Clan Magistrate", characters, chars_by_id,
	)
	assert_eq(result, 3, "Gi-virtue character should get bonus for magistrate")


func test_candidate_scoring_school_type_bonus_for_temple() -> void:
	var lord := _make_char(1, "Phoenix", 5.0)
	lord.lord_id = -1
	lord.clan = "Phoenix"
	var bushi := _make_char(2, "Phoenix", 2.0)
	bushi.lord_id = 1
	bushi.honor = 3.0
	bushi.glory = 2.0
	bushi.school_type = Enums.SchoolType.BUSHI
	var shugenja := _make_char(3, "Phoenix", 2.0)
	shugenja.lord_id = 1
	shugenja.honor = 3.0
	shugenja.glory = 2.0
	shugenja.school_type = Enums.SchoolType.SHUGENJA
	var characters: Array = [lord, bushi, shugenja]
	var chars_by_id: Dictionary = {1: lord, 2: bushi, 3: shugenja}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Temple Head", characters, chars_by_id,
	)
	assert_eq(result, 3, "Shugenja should get school type bonus for temple head")


func test_candidate_scoring_monastery_prefers_monk() -> void:
	var lord := _make_char(1, "Dragon", 5.0)
	lord.lord_id = -1
	lord.clan = "Dragon"
	var bushi := _make_char(2, "Dragon", 2.0)
	bushi.lord_id = 1
	bushi.honor = 3.0
	bushi.glory = 2.0
	bushi.school_type = Enums.SchoolType.BUSHI
	var monk := _make_char(3, "Dragon", 2.0)
	monk.lord_id = 1
	monk.honor = 3.0
	monk.glory = 2.0
	monk.school_type = Enums.SchoolType.MONK
	var characters: Array = [lord, bushi, monk]
	var chars_by_id: Dictionary = {1: lord, 2: bushi, 3: monk}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Monastery Abbot", characters, chars_by_id,
	)
	assert_eq(result, 3, "Monk should get school type bonus for monastery abbot")


func test_candidate_scoring_still_uses_loyalty() -> void:
	var lord := _make_char(1, "Lion", 5.0)
	lord.lord_id = -1
	lord.clan = "Lion"
	# Equal stats except disposition
	var disliked := _make_char(2, "Lion", 2.0)
	disliked.lord_id = 1
	disliked.honor = 3.0
	disliked.glory = 2.0
	disliked.disposition_values = {1: -20}
	var loyal := _make_char(3, "Lion", 2.0)
	loyal.lord_id = 1
	loyal.honor = 3.0
	loyal.glory = 2.0
	loyal.disposition_values = {1: 40}
	var characters: Array = [lord, disliked, loyal]
	var chars_by_id: Dictionary = {1: lord, 2: disliked, 3: loyal}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Garrison Commander", characters, chars_by_id,
	)
	assert_eq(result, 3, "Loyal vassal should score higher via disposition bonus")


func test_candidate_scoring_skips_already_assigned() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var assigned := _make_char(2, "Crab", 3.0)
	assigned.lord_id = 1
	assigned.honor = 8.0
	assigned.glory = 5.0
	assigned.role_position = "Clan Magistrate"
	assigned.skills = {"Battle": 5, "Defense": 4}
	var free := _make_char(3, "Crab", 2.0)
	free.lord_id = 1
	free.honor = 2.0
	free.glory = 1.0
	var characters: Array = [lord, assigned, free]
	var chars_by_id: Dictionary = {1: lord, 2: assigned, 3: free}

	var result: int = DayOrchestrator._find_vacancy_candidate(
		1, "Garrison Commander", characters, chars_by_id,
	)
	assert_eq(result, 3, "Already-assigned character should be skipped")


# -- Vacancy Persistence & Season Tracking Tests --------------------------------


func test_vacancy_registry_created_in_season_meta() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	lord.lord_id = -1
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}
	var season_meta: Dictionary = {}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], [], {}, season_meta)

	assert_true(season_meta.has("vacancy_registry"), "Registry should be created in season_meta")


func test_vacancy_seasons_vacant_starts_at_zero() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}
	var season_meta: Dictionary = {}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array = [fort]

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces, season_meta)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			assert_eq(v["seasons_vacant"], 0, "New vacancy starts at 0 seasons")


func test_vacancy_seasons_increment_on_season_boundary() -> void:
	var season_meta: Dictionary = {
		"vacancy_registry": {
			"1_Garrison Commander_s100": 0,
			"1_Clan Magistrate": 1,
		}
	}

	DayOrchestrator._increment_vacancy_seasons(season_meta)

	var registry: Dictionary = season_meta["vacancy_registry"]
	assert_eq(registry["1_Garrison Commander_s100"], 1)
	assert_eq(registry["1_Clan Magistrate"], 2)


func test_vacancy_inherits_seasons_from_registry() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var characters: Array = [lord]
	var chars_by_id: Dictionary = {1: lord}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array = [fort]

	# Pre-populate registry with existing vacancy at 3 seasons
	var season_meta: Dictionary = {
		"vacancy_registry": {
			"1_Garrison Commander_s100": 3,
		}
	}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces, season_meta)

	var vacancies: Array = ws.get("vacancy_data", {}).get(1, [])
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			assert_eq(v["seasons_vacant"], 3, "Should inherit seasons_vacant from registry")


func test_vacancy_registry_clears_filled_positions() -> void:
	var lord := _make_char(1, "Crab", 5.0)
	lord.lord_id = -1
	lord.clan = "Crab"
	var commander := _make_char(2, "Crab", 3.0)
	commander.lord_id = 1
	commander.role_position = "Garrison Commander"
	var characters: Array = [lord, commander]
	var chars_by_id: Dictionary = {1: lord, 2: commander}

	var prov := _make_province(10, "Crab")
	var provinces: Dictionary = {10: prov}
	var fort := _make_settlement(100, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array = [fort]

	# Registry has the old vacancy
	var season_meta: Dictionary = {
		"vacancy_registry": {
			"1_Garrison Commander_s100": 5,
		}
	}

	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(ws, characters, chars_by_id, [], settlements, provinces, season_meta)

	# Since the position is now filled, the vacancy should not appear
	var registry: Dictionary = season_meta["vacancy_registry"]
	assert_false(registry.has("1_Garrison Commander_s100"), "Filled vacancy should be removed from registry")


func test_vacancy_key_includes_family_for_school_master() -> void:
	var v: Dictionary = {"position_type": "School Master", "family": "Hida"}
	var key: String = DayOrchestrator._vacancy_key(1, v)
	assert_eq(key, "1_School Master_Hida")


func test_vacancy_key_includes_settlement_for_garrison() -> void:
	var v: Dictionary = {"position_type": "Garrison Commander", "settlement_id": 100}
	var key: String = DayOrchestrator._vacancy_key(1, v)
	assert_eq(key, "1_Garrison Commander_s100")


func test_vacancy_key_includes_unit_for_military() -> void:
	var v: Dictionary = {"position_type": "military_commander", "unit_id": 42}
	var key: String = DayOrchestrator._vacancy_key(1, v)
	assert_eq(key, "1_military_commander_u42")


func test_vacancy_key_fallback_for_magistrate() -> void:
	var v: Dictionary = {"position_type": "Clan Magistrate"}
	var key: String = DayOrchestrator._vacancy_key(1, v)
	assert_eq(key, "1_Clan Magistrate")


# -- Infrastructure Intelligence Tests ------------------------------------------


func test_infra_border_includes_all_military_types() -> void:
	var prov_a := _make_province(10, "Crane")
	var prov_b := _make_province(20, "Lion")
	prov_a.adjacent_province_ids = [20]
	prov_b.adjacent_province_ids = [10]
	var provinces: Dictionary = {10: prov_a, 20: prov_b}

	# Province A has a castle — should not be flagged
	var castle := _make_settlement(100, 10, Enums.SettlementType.CASTLE)
	# Province B has no military — should be flagged
	var village := _make_settlement(200, 20, Enums.SettlementType.VILLAGE)
	var settlements: Array = [castle, village]

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, provinces, settlements, [], {})

	var border_dict: Dictionary = ws.get("border_province_ids_without_fort", {})
	assert_false(border_dict.has(10), "Province with castle should not be flagged")
	assert_true(border_dict.has(20), "Province without military should be flagged")


func test_infra_border_keep_counts_as_fortified() -> void:
	var prov := _make_province(10, "Crab")
	var enemy := _make_province(20, "Crane")
	prov.adjacent_province_ids = [20]
	enemy.adjacent_province_ids = [10]
	var provinces: Dictionary = {10: prov, 20: enemy}

	var keep := _make_settlement(100, 10, Enums.SettlementType.KEEP)
	var settlements: Array = [keep]

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, provinces, settlements, [], {})

	var border_dict: Dictionary = ws.get("border_province_ids_without_fort", {})
	assert_false(border_dict.has(10), "Province with keep should count as fortified")


func test_infra_data_includes_clan() -> void:
	var prov := _make_province(10, "Crane")
	var enemy := _make_province(20, "Lion")
	prov.adjacent_province_ids = [20]
	enemy.adjacent_province_ids = [10]
	var provinces: Dictionary = {10: prov, 20: enemy}

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, provinces, [], [], {})

	var border_dict: Dictionary = ws.get("border_province_ids_without_fort", {})
	if border_dict.has(10):
		assert_eq(border_dict[10], "Crane", "Border dict should include clan")


func test_infra_naval_threat_requires_ships() -> void:
	var war := WarData.new()
	war.clan_a = "Crane"
	war.clan_b = "Crab"

	# No ships at all — naval threat should be false
	var ws: Dictionary = {"active_wars": [war]}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {}, [], [], {})
	assert_false(ws.get("has_naval_threat", true), "No ships means no naval threat")


func test_infra_naval_threat_with_enemy_ships() -> void:
	var war := WarData.new()
	war.clan_a = "Crane"
	war.clan_b = "Mantis"

	var ship := ShipData.new()
	ship.owning_clan = "Mantis"
	ship.is_destroyed = false

	var ws: Dictionary = {"active_wars": [war]}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {}, [], [ship], {})
	assert_true(ws.get("has_naval_threat", false), "Enemy clan with ships = naval threat")


func test_infra_naval_threat_no_threat_without_war() -> void:
	var ship := ShipData.new()
	ship.owning_clan = "Mantis"
	ship.is_destroyed = false

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {}, [], [ship], {})
	assert_false(ws.get("has_naval_threat", true), "Ships without war = no naval threat")


func test_filter_province_ids_by_clan() -> void:
	var data: Dictionary = {10: "Crane", 20: "Lion", 30: "Crane"}
	var result: Array = NPCDecisionEngine._filter_province_ids_by_clan(data, "Crane")
	assert_eq(result.size(), 2, "Should return only Crane provinces")
	assert_true(10 in result)
	assert_true(30 in result)
	assert_false(20 in result)


func test_filter_province_ids_backward_compat() -> void:
	# Old-style plain array (no clan data)
	var data: Array = [10, 20, 30]
	var result: Array = NPCDecisionEngine._filter_province_ids_by_clan(data, "Crane")
	assert_eq(result.size(), 3, "Backward compat: all ids returned from plain array")


# -- Construction → Vacancy Pipeline Tests ------------------------------------

func _make_construction(
	id: int, ctype: ConstructionData.ConstructionType,
	province_id: int, seasons_remaining: int = 1,
) -> ConstructionData:
	var cd := ConstructionData.new()
	cd.construction_id = id
	cd.construction_type = ctype
	cd.province_id = province_id
	cd.seasons_remaining = seasons_remaining
	cd.pu_committed = 0.5
	return cd


func test_completed_temple_triggers_vacancy() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var existing := _make_settlement(100, 10, Enums.SettlementType.TOWN)
	var settlements: Array = [existing]
	var provinces: Dictionary = {10: prov}

	# Create a temple construction about to complete
	var cd := _make_construction(1, ConstructionData.ConstructionType.TEMPLE, 10, 1)
	var constructions: Array = [cd]
	var next_sid: Array = [200]
	var next_tid: Array = [1]
	var topics: Array = []

	# Tick construction queue — temple completes and is added to settlements
	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [], _dice,
		next_sid, topics, next_tid, 10,
	)

	# Verify temple was created
	assert_eq(settlements.size(), 2, "Temple settlement should be added")
	var temple: SettlementData = settlements[1]
	assert_eq(temple.settlement_type, Enums.SettlementType.TEMPLE)

	# Now run vacancy intelligence — should detect Temple Head vacancy
	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	var vacancies: Array = ws.get("vacant_positions_1", [])
	var found_temple_head: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Temple Head":
			found_temple_head = true
			break
	assert_true(found_temple_head, "Completed temple should trigger Temple Head vacancy")


func test_completed_monastery_triggers_vacancy() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var existing := _make_settlement(100, 10, Enums.SettlementType.TOWN)
	var settlements: Array = [existing]
	var provinces: Dictionary = {10: prov}

	var cd := _make_construction(1, ConstructionData.ConstructionType.MONASTERY, 10, 1)
	var constructions: Array = [cd]
	var next_sid: Array = [200]
	var next_tid: Array = [1]
	var topics: Array = []

	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [], _dice,
		next_sid, topics, next_tid, 10,
	)

	assert_eq(settlements.size(), 2, "Monastery settlement should be added")

	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	var vacancies: Array = ws.get("vacant_positions_1", [])
	var found_abbot: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Monastery Abbot":
			found_abbot = true
			break
	assert_true(found_abbot, "Completed monastery should trigger Monastery Abbot vacancy")


func test_organic_village_no_position_vacancy() -> void:
	# Organic villages don't require any specific position holder
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	prov.terrain_type = Enums.TerrainType.PLAINS
	var existing := _make_settlement(100, 10, Enums.SettlementType.TOWN)
	existing.population_pu = 10.0
	var settlements: Array = [existing]
	var provinces: Dictionary = {10: prov}

	# Add a village manually (simulates organic village creation)
	var village := _make_settlement(200, 10, Enums.SettlementType.VILLAGE)
	settlements.append(village)

	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	var vacancies: Array = ws.get("vacant_positions_1", [])
	# Villages should not trigger Garrison Commander (not military)
	# and should not trigger Temple Head or Monastery Abbot
	for v: Dictionary in vacancies:
		var pt: String = v.get("position_type", "")
		if pt == "Garrison Commander" or pt == "Temple Head" or pt == "Monastery Abbot":
			# Check if this vacancy is from the village (settlement_id 200)
			if v.get("settlement_id", -1) == 200:
				fail_test("Village should not trigger position vacancy: " + pt)
				return
	pass_test("Village correctly produces no position vacancies")


func test_construction_vacancy_has_zero_seasons_vacant() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var settlements: Array = [_make_settlement(100, 10, Enums.SettlementType.TOWN)]
	var provinces: Dictionary = {10: prov}

	var cd := _make_construction(1, ConstructionData.ConstructionType.TEMPLE, 10, 1)
	var constructions: Array = [cd]
	var next_sid: Array = [200]
	var next_tid: Array = [1]
	var topics: Array = []

	DayOrchestrator._process_construction_completions(
		constructions, settlements, provinces, [], _dice,
		next_sid, topics, next_tid, 10,
	)

	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	var vacancies: Array = ws.get("vacant_positions_1", [])
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Temple Head":
			assert_eq(v.get("seasons_vacant", -1), 0,
				"Newly created settlement vacancy should start at 0 seasons")
			return
	fail_test("Temple Head vacancy not found")


func test_completed_fortification_triggers_garrison_vacancy() -> void:
	# Fortifications don't go through the construction queue (they're immediate),
	# but let's verify that a fort settlement triggers Garrison Commander vacancy
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var fort := _make_settlement(200, 10, Enums.SettlementType.FORTIFICATION)
	var settlements: Array = [fort]
	var provinces: Dictionary = {10: prov}

	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	var vacancies: Array = ws.get("vacant_positions_1", [])
	var found_garrison: bool = false
	for v: Dictionary in vacancies:
		if v.get("position_type", "") == "Garrison Commander":
			found_garrison = true
			break
	assert_true(found_garrison, "Fortification should trigger Garrison Commander vacancy")


func test_vacancy_registry_tracks_new_settlement() -> void:
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var temple := _make_settlement(200, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array = [temple]
	var provinces: Dictionary = {10: prov}

	var sm: Dictionary = {"vacancy_registry": {}}
	var ws: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	# Verify new settlement vacancy appears in registry
	var registry: Dictionary = sm.get("vacancy_registry", {})
	var found_key: bool = false
	for key: String in registry:
		if "Temple Head" in key:
			found_key = true
			assert_eq(registry[key], 0, "New vacancy should start at season 0")
			break
	assert_true(found_key, "Temple Head vacancy should be in registry")


func test_vacancy_refresh_overwrites_stale_data() -> void:
	# Simulates the daily construction refresh: vacancy intelligence runs once
	# with no fort, then a fort is created mid-day, then vacancy intelligence
	# runs again — garrison commander vacancy should appear
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var town := _make_settlement(100, 10, Enums.SettlementType.TOWN)
	var settlements: Array = [town]
	var provinces: Dictionary = {10: prov}

	# First run: no military settlements → no garrison vacancy
	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)
	var vacancies_before: Array = ws.get("vacant_positions_1", [])
	var had_garrison_before: bool = false
	for v: Dictionary in vacancies_before:
		if v.get("position_type", "") == "Garrison Commander":
			had_garrison_before = true
	assert_false(had_garrison_before, "No garrison vacancy before fort exists")

	# Mid-day: fort gets created (simulating construction effect)
	var fort := _make_settlement(200, 10, Enums.SettlementType.FORTIFICATION)
	settlements.append(fort)

	# Second run (refresh): should now detect garrison commander vacancy
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)
	var vacancies_after: Array = ws.get("vacant_positions_1", [])
	var has_garrison_after: bool = false
	for v: Dictionary in vacancies_after:
		if v.get("position_type", "") == "Garrison Commander":
			has_garrison_after = true
	assert_true(has_garrison_after, "Garrison vacancy should appear after refresh")


func test_vacancy_refresh_preserves_existing_vacancies() -> void:
	# Refresh should not lose pre-existing vacancies when adding new ones
	var lord := _make_char(1, "Crane", 5.0)
	var prov := _make_province(10, "Crane")
	var temple := _make_settlement(100, 10, Enums.SettlementType.TEMPLE)
	var settlements: Array = [temple]
	var provinces: Dictionary = {10: prov}

	# First run: temple head vacancy
	var ws: Dictionary = {}
	var sm: Dictionary = {}
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	# Add a fort mid-day
	var fort := _make_settlement(200, 10, Enums.SettlementType.FORTIFICATION)
	settlements.append(fort)

	# Refresh
	DayOrchestrator._populate_vacancy_intelligence(
		ws, [lord], {1: lord}, [], settlements, provinces, sm,
	)

	var vacancies: Array = ws.get("vacant_positions_1", [])
	var types: Array = []
	for v: Dictionary in vacancies:
		types.append(v.get("position_type", ""))
	assert_true("Temple Head" in types, "Temple Head should be preserved after refresh")
	assert_true("Garrison Commander" in types, "Garrison Commander should appear after refresh")


# -- Worship Failure Detection Tests ------------------------------------------

func _make_worship_state_with_province(
	pid: int, fortune_wp: Dictionary,
) -> Dictionary:
	return {"province_wp": {pid: fortune_wp}}


func test_worship_failure_detected_when_below_threshold() -> void:
	# Province with some WP below the 10.0 threshold → should be flagged
	var prov := _make_province(10, "Crane")
	var fortune_wp: Dictionary = {}
	for f: int in range(7):
		fortune_wp[f] = 5.0  # 50% of threshold → DISPLEASED
	var worship_state: Dictionary = _make_worship_state_with_province(10, fortune_wp)

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], worship_state)
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_true(failing.has(10), "Province below threshold should be flagged as failing")


func test_worship_not_failing_when_at_threshold() -> void:
	# Province with all fortunes at exactly 10.0 WP → NONE tier → not failing
	var prov := _make_province(10, "Crane")
	var fortune_wp: Dictionary = {}
	for f: int in range(7):
		fortune_wp[f] = 10.0
	var worship_state: Dictionary = _make_worship_state_with_province(10, fortune_wp)

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], worship_state)
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_false(failing.has(10), "Province at threshold should not be flagged")


func test_worship_failure_wrathful_when_zero_wp() -> void:
	# Province in wp_data but with zero WP → WRATHFUL for all fortunes
	var prov := _make_province(10, "Crane")
	var fortune_wp: Dictionary = WorshipSystem.make_initial_province_worship()
	var worship_state: Dictionary = _make_worship_state_with_province(10, fortune_wp)

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], worship_state)
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_true(failing.has(10), "Zero WP province should be flagged as failing")


func test_worship_failure_empty_worship_state_no_flag() -> void:
	# Empty worship state (system not initialized) → should NOT flag any provinces
	var prov := _make_province(10, "Crane")
	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], {})
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_false(failing.has(10), "Empty worship state should not flag provinces")


func test_worship_failure_one_fortune_below() -> void:
	# 6 fortunes at threshold, 1 below → should still flag
	var prov := _make_province(10, "Crane")
	var fortune_wp: Dictionary = {}
	for f: int in range(7):
		fortune_wp[f] = 10.0
	fortune_wp[3] = 2.0  # Fortune 3 (Ebisu) at 20% → WRATHFUL
	var worship_state: Dictionary = _make_worship_state_with_province(10, fortune_wp)

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], worship_state)
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_true(failing.has(10), "One fortune below threshold should flag province")


func test_worship_failure_restless_tier_flagged() -> void:
	# Province at 75-99% of threshold → RESTLESS (still failing)
	var prov := _make_province(10, "Crane")
	var fortune_wp: Dictionary = {}
	for f: int in range(7):
		fortune_wp[f] = 10.0
	fortune_wp[0] = 8.0  # 80% of 10.0 → RESTLESS
	var worship_state: Dictionary = _make_worship_state_with_province(10, fortune_wp)

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], worship_state)
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_true(failing.has(10), "RESTLESS tier should still count as failing")


func test_worship_failure_province_not_in_wp_data() -> void:
	# Province exists but has no entry in wp_data → flagged (genuinely no worship)
	var prov := _make_province(10, "Crane")
	var worship_state: Dictionary = {"province_wp": {20: {}}}  # Different province

	var ws: Dictionary = {}
	DayOrchestrator._populate_infrastructure_intelligence(ws, {10: prov}, [], [], worship_state)
	var failing: Dictionary = ws.get("worship_failing_province_ids", {})
	assert_true(failing.has(10), "Province absent from wp_data should be flagged")
