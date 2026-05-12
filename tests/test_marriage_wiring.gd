extends GutTest
## Tests for ARRANGE_MARRIAGE wiring: executor intercept, proposal evaluation,
## orchestrator marriage/rejection processing, and metadata population.


var _dice: DiceEngine
var _time: TimeSystem


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)
	_time = TimeSystem.new()


func _make_char(id: int, clan: String = "Crane", family: String = "Doji", status: float = 4.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC_" + str(id)
	c.clan = clan
	c.family = family
	c.school_type = Enums.SchoolType.COURTIER
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.honor = 5.0
	c.glory = 3.0
	c.status = status
	c.skills = {"Courtier": 3, "Etiquette": 3, "Awareness": 3}
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
	c.spouse_id = -1
	c.disposition_values = {}
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


# -- Context Action List: ARRANGE_MARRIAGE ------------------------------------

func test_arrange_marriage_in_at_own_holdings() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("ARRANGE_MARRIAGE"))


func test_arrange_marriage_in_at_court() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("ARRANGE_MARRIAGE"))


func test_arrange_marriage_not_in_traveling() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.TRAVELING
	)
	assert_false(actions.has("ARRANGE_MARRIAGE"))


# -- Lord-Only Gating ---------------------------------------------------------

func test_arrange_marriage_blocked_for_non_lord() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = false
	assert_true(NPCDecisionEngine._is_lord_only_blocked("ARRANGE_MARRIAGE", ctx))


func test_arrange_marriage_allowed_for_lord() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.is_lord = true
	assert_false(NPCDecisionEngine._is_lord_only_blocked("ARRANGE_MARRIAGE", ctx))


# -- Action Executor: ARRANGE_MARRIAGE ----------------------------------------

func test_arrange_marriage_accepted() -> void:
	var lord_a := _make_char(1, "Crane", "Doji")
	var lord_b := _make_char(2, "Lion", "Akodo")
	lord_b.disposition_values[1] = 20
	var candidate_a := _make_char(10, "Crane", "Doji", 3.0)
	var candidate_b := _make_char(11, "Lion", "Akodo", 3.0)

	var chars_by_id: Dictionary = {1: lord_a, 2: lord_b, 10: candidate_a, 11: candidate_b}

	var ctx := _make_ctx(lord_a)
	var action := _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 10,
		"target_lord_id": 2,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	assert_true(result["success"])
	assert_eq(result["action_id"], "ARRANGE_MARRIAGE")
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("requires_marriage", false))
	assert_eq(effects["candidate_a_id"], 10)
	assert_eq(effects["candidate_b_id"], 11)
	assert_eq(effects["proposing_lord_id"], 1)
	assert_eq(effects["target_lord_id"], 2)


func test_arrange_marriage_rejected_negative_disposition() -> void:
	var lord_a := _make_char(1, "Crane", "Doji")
	var lord_b := _make_char(2, "Lion", "Akodo")
	lord_b.disposition_values[1] = -30
	var candidate_a := _make_char(10, "Crane", "Doji", 1.0)
	candidate_a.glory = 0.0
	var candidate_b := _make_char(11, "Lion", "Akodo", 1.0)

	var chars_by_id: Dictionary = {1: lord_a, 2: lord_b, 10: candidate_a, 11: candidate_b}

	var ctx := _make_ctx(lord_a)
	var action := _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 10,
		"target_lord_id": 2,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	assert_false(result["success"])
	var effects: Dictionary = result["effects"]
	assert_true(effects.get("marriage_rejected", false))
	assert_eq(effects["disposition_change"], -3)


func test_arrange_marriage_fails_without_metadata() -> void:
	var lord := _make_char(1)
	var ctx := _make_ctx(lord)
	var action := _make_action("ARRANGE_MARRIAGE", {})

	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, _dice, {})
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "missing_metadata")


func test_arrange_marriage_fails_target_lord_not_found() -> void:
	var lord := _make_char(1)
	var ctx := _make_ctx(lord)
	var action := _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 10,
		"target_lord_id": 999,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord, ctx, _dice, {})
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "target_lord_not_found")


func test_arrange_marriage_cross_clan_type() -> void:
	var lord_a := _make_char(1, "Crane", "Doji")
	var lord_b := _make_char(2, "Lion", "Akodo")
	lord_b.disposition_values[1] = 30
	var candidate_a := _make_char(10, "Crane", "Doji", 3.0)
	var candidate_b := _make_char(11, "Lion", "Akodo", 3.0)
	var chars_by_id: Dictionary = {1: lord_a, 2: lord_b, 10: candidate_a, 11: candidate_b}

	var ctx := _make_ctx(lord_a)
	var action := _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 10,
		"target_lord_id": 2,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	assert_true(result["success"])
	assert_eq(result["effects"]["marriage_type"], MarriageSystem.MarriageType.CROSS_CLAN)


func test_arrange_marriage_within_clan_between_families() -> void:
	var lord_a := _make_char(1, "Crane", "Doji")
	var lord_b := _make_char(2, "Crane", "Kakita")
	lord_b.disposition_values[1] = 30
	var candidate_a := _make_char(10, "Crane", "Doji", 3.0)
	var candidate_b := _make_char(11, "Crane", "Kakita", 3.0)
	var chars_by_id: Dictionary = {1: lord_a, 2: lord_b, 10: candidate_a, 11: candidate_b}

	var ctx := _make_ctx(lord_a)
	var action := _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 10,
		"target_lord_id": 2,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	assert_true(result["success"])
	assert_eq(result["effects"]["marriage_type"], MarriageSystem.MarriageType.BETWEEN_FAMILIES)


func test_arrange_marriage_within_family() -> void:
	var lord_a := _make_char(1, "Crane", "Doji")
	var lord_b := _make_char(2, "Crane", "Doji")
	lord_b.disposition_values[1] = 30
	var candidate_a := _make_char(10, "Crane", "Doji", 3.0)
	var candidate_b := _make_char(11, "Crane", "Doji", 3.0)
	var chars_by_id: Dictionary = {1: lord_a, 2: lord_b, 10: candidate_a, 11: candidate_b}

	var ctx := _make_ctx(lord_a)
	var action := _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 10,
		"target_lord_id": 2,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	assert_true(result["success"])
	assert_eq(result["effects"]["marriage_type"], MarriageSystem.MarriageType.WITHIN_FAMILY)


# -- Day Orchestrator: Marriage Processing ------------------------------------

func test_apply_marriage_mutates_spouse_ids() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Lion", "Akodo")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array[Dictionary] = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100
	)

	assert_true(result["applied"])
	assert_eq(char_a.spouse_id, 11)
	assert_eq(char_b.spouse_id, 10)
	assert_eq(marriages.size(), 1)
	assert_eq(marriages[0]["character_a_id"], 10)
	assert_eq(marriages[0]["character_b_id"], 11)


func test_apply_marriage_returns_boosts() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Lion", "Akodo")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array[Dictionary] = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100
	)

	assert_eq(result["clan_boost"], MarriageSystem.CLAN_BASELINE_BOOST)
	assert_eq(result["family_boost"], MarriageSystem.FAMILY_BASELINE_BOOST)
	assert_true(result["favor_owed"])


func test_apply_marriage_between_families_no_clan_boost() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Crane", "Kakita")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array[Dictionary] = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.BETWEEN_FAMILIES,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100
	)

	assert_eq(result["clan_boost"], 0)
	assert_eq(result["family_boost"], MarriageSystem.FAMILY_BASELINE_BOOST)
	assert_false(result["favor_owed"])


func test_apply_marriage_fails_for_missing_character() -> void:
	var chars_by_id: Dictionary = {}
	var marriages: Array[Dictionary] = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 999,
		"candidate_b_id": 998,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100
	)

	assert_false(result["applied"])
	assert_eq(marriages.size(), 0)


func test_apply_marriage_fails_if_already_married() -> void:
	var char_a := _make_char(10)
	char_a.spouse_id = 50
	var char_b := _make_char(11)
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array[Dictionary] = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100
	)

	assert_false(result["applied"])
	assert_eq(result["reason"], "already_married")


func test_apply_marriage_rejection_mutates_disposition() -> void:
	var lord_b := _make_char(2)
	lord_b.disposition_values[1] = 10
	var chars_by_id: Dictionary = {2: lord_b}

	var effects: Dictionary = {
		"marriage_rejected": true,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
		"disposition_change": -3,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage_rejection(
		effects, chars_by_id
	)

	assert_true(result["applied"])
	assert_true(result["rejected"])
	assert_eq(lord_b.disposition_values[1], 7)


func test_apply_marriage_rejection_clamps_disposition() -> void:
	var lord_b := _make_char(2)
	lord_b.disposition_values[1] = -99
	var chars_by_id: Dictionary = {2: lord_b}

	var effects: Dictionary = {
		"marriage_rejected": true,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
		"disposition_change": -3,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage_rejection(
		effects, chars_by_id
	)

	assert_eq(lord_b.disposition_values[1], -100)


# -- Metadata Population Tests ------------------------------------------------

func test_arrange_marriage_metadata_populated() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 10
	need.target_npc_id_secondary = 2
	need.target_settlement_id = 11
	var ctx := _make_ctx(_make_char(1))
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "ARRANGE_MARRIAGE"

	NPCDecisionEngine._populate_action_metadata(option, need, ctx)

	assert_eq(option.metadata.get("candidate_id"), 10)
	assert_eq(option.metadata.get("target_lord_id"), 2)
	assert_eq(option.metadata.get("target_candidate_id"), 11)


# -- Integration: governance_results includes marriages -----------------------

func test_governance_results_include_marriages() -> void:
	var lord := _make_char(1, "Crane", "Doji", 5.0)
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
	assert_true(gov.has("marriages"))
