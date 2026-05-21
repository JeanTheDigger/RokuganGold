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
	var actions: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true(actions.has("ARRANGE_MARRIAGE"))


func test_arrange_marriage_in_at_court() -> void:
	var actions: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true(actions.has("ARRANGE_MARRIAGE"))


func test_arrange_marriage_not_in_traveling() -> void:
	var actions: Array = NPCDecisionEngine._get_actions_for_context(
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
	var marriages: Array = []

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
	var marriages: Array = []

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
	var marriages: Array = []

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
	var marriages: Array = []

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
	var marriages: Array = []

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
	assert_true(gov.has("marriages"))


# -- Follow-up: Baseline Boosts -----------------------------------------------

func test_cross_clan_marriage_applies_baseline_boosts() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Lion", "Akodo")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	var clan_bl: Dictionary = baselines["clan"]
	var family_bl: Dictionary = baselines["family"]

	var key_clan: String = CollectiveDisposition.make_pair_key("Crane", "Lion")
	var before_clan: int = int(clan_bl.get(key_clan, 0))

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
	}
	DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
		clan_bl, family_bl,
	)

	var after_clan: int = int(clan_bl.get(key_clan, 0))
	assert_true(after_clan > before_clan, "Clan baseline should increase after cross-clan marriage")


func test_within_family_marriage_no_baseline_change() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Crane", "Doji")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	var clan_bl: Dictionary = baselines["clan"]
	var family_bl: Dictionary = baselines["family"]

	var clan_snapshot: Dictionary = clan_bl.duplicate()

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.WITHIN_FAMILY,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
	}
	DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
		clan_bl, family_bl,
	)

	assert_eq(clan_bl, clan_snapshot, "Within-family marriage should not change clan baselines")


# -- Follow-up: Favor Creation ------------------------------------------------

func test_cross_clan_marriage_creates_favor() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Lion", "Akodo")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []
	var favors: Array = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
		{}, {}, favors,
	)

	assert_true(result["favor_created"])
	assert_eq(favors.size(), 1)
	var favor: FavorData = favors[0]
	assert_eq(favor.creditor_id, 2)
	assert_eq(favor.debtor_id, 1)
	assert_eq(favor.tier, FavorData.FavorTier.MODERATE)
	assert_eq(favor.source_action, "ARRANGE_MARRIAGE")


func test_between_families_marriage_no_favor() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Crane", "Kakita")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []
	var favors: Array = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.BETWEEN_FAMILIES,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
		{}, {}, favors,
	)

	assert_false(result["favor_created"])
	assert_eq(favors.size(), 0)


# -- Follow-up: Topic Generation -----------------------------------------------

func test_marriage_generates_topic() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Lion", "Akodo")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []
	var topics: Array = []
	var next_tid: Array = [500]

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
		"proposing_lord_id": 1,
		"target_lord_id": 2,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
		{}, {}, [], topics, next_tid,
	)

	assert_eq(result["topic_id"], 500)
	assert_eq(next_tid[0], 501)
	assert_eq(topics.size(), 1)
	var topic: TopicData = topics[0]
	assert_eq(topic.topic_type, "marriage")
	assert_eq(topic.variant, "cross_clan")
	assert_eq(topic.category, TopicData.Category.POLITICAL)
	assert_eq(topic.tier, TopicData.Tier.TIER_4)
	# _reassign_moving_character changes char_b's family to char_a's family
	# before the topic slug is generated, so the slug uses the reassigned family.
	assert_true(topic.slug.begins_with("marriage_Doji_Doji"))


func test_between_families_topic_variant() -> void:
	var char_a := _make_char(10, "Crane", "Doji")
	var char_b := _make_char(11, "Crane", "Kakita")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []
	var topics: Array = []
	var next_tid: Array = [600]

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.BETWEEN_FAMILIES,
	}
	var result: Dictionary = DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
		{}, {}, [], topics, next_tid,
	)

	assert_eq(topics[0].variant, "between_families")
	assert_eq(topics[0].clan_involved, "Crane")


# -- Moving Character Reassignment Tests ----------------------------------------

func test_reassign_moving_character_cross_clan_sets_birth_fields() -> void:
	var char_a: L5RCharacterData = _make_char(10, "Crane", "Doji")
	var char_b: L5RCharacterData = _make_char(11, "Lion", "Akodo")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
		"proposing_lord_id": 10,
		"target_lord_id": 11,
	}
	DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
	)

	assert_eq(char_b.birth_clan, "Lion", "Moving char should preserve original clan")
	assert_eq(char_b.birth_family, "Akodo", "Moving char should preserve original family")
	assert_eq(char_b.clan, "Crane", "Moving char should adopt spouse clan")
	assert_eq(char_b.family, "Doji", "Moving char should adopt spouse family")


func test_reassign_moving_character_updates_lord_id() -> void:
	var char_a: L5RCharacterData = _make_char(10, "Crane", "Doji")
	char_a.lord_id = -1
	var char_b: L5RCharacterData = _make_char(11, "Lion", "Akodo")
	char_b.lord_id = 50
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.CROSS_CLAN,
		"proposing_lord_id": 30,
		"target_lord_id": 40,
	}
	DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
	)

	assert_eq(char_b.lord_id, 40, "Moving char (b) gets target_lord_id")


func test_reassign_within_family_no_reassignment() -> void:
	var char_a: L5RCharacterData = _make_char(10, "Crane", "Doji")
	var char_b: L5RCharacterData = _make_char(11, "Crane", "Doji")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.WITHIN_FAMILY,
	}
	DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
	)

	assert_eq(char_b.birth_clan, "", "No birth_clan set for within-family")
	assert_eq(char_b.birth_family, "", "No birth_family set for within-family")
	assert_eq(char_b.clan, "Crane", "Clan unchanged")
	assert_eq(char_b.family, "Doji", "Family unchanged")


func test_reassign_between_families_sets_birth_family() -> void:
	var char_a: L5RCharacterData = _make_char(10, "Crane", "Doji")
	var char_b: L5RCharacterData = _make_char(11, "Crane", "Kakita")
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}
	var marriages: Array = []

	var effects: Dictionary = {
		"requires_marriage": true,
		"candidate_a_id": 10,
		"candidate_b_id": 11,
		"marriage_type": MarriageSystem.MarriageType.BETWEEN_FAMILIES,
		"proposing_lord_id": 30,
		"target_lord_id": 40,
	}
	DayOrchestrator._apply_marriage(
		effects, chars_by_id, marriages, 100,
	)

	assert_eq(char_b.birth_clan, "Crane", "Same clan preserved as birth_clan")
	assert_eq(char_b.birth_family, "Kakita", "Original family preserved")
	assert_eq(char_b.family, "Doji", "Moved to spouse family")


# -- Pregnancy Processing Tests --------------------------------------------------

func test_pregnancy_check_creates_child_on_success() -> void:
	var father: L5RCharacterData = _make_char(10, "Crane", "Doji")
	father.gender = "male"
	var mother: L5RCharacterData = _make_char(11, "Crane", "Doji")
	mother.gender = "female"
	father.disposition_values[11] = 70
	mother.disposition_values[10] = 70
	var chars_by_id: Dictionary = {10: father, 11: mother}

	var marriage: Dictionary = MarriageSystem.create_marriage(
		10, 11, MarriageSystem.MarriageType.WITHIN_FAMILY, -1, 50,
	)
	var marriages: Array = [marriage]
	var children: Array = []

	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)

	var found_child: bool = false
	for _i: int in range(20):
		var results: Array = DayOrchestrator._process_pregnancy_checks(
			marriages, chars_by_id, children, dice, 100 + _i,
		)
		if results.size() > 0:
			found_child = true
			assert_eq(results[0]["father_id"], 10)
			assert_eq(results[0]["mother_id"], 11)
			assert_eq(results[0]["clan"], "Crane")
			assert_true(children.size() > 0, "Child added to children array")
			assert_true(father.children_ids.has(results[0]["child_id"]))
			assert_true(mother.children_ids.has(results[0]["child_id"]))
			break

	assert_true(found_child, "Should have produced a child within 20 attempts at high disposition")


func test_pregnancy_skips_inactive_marriage() -> void:
	var father: L5RCharacterData = _make_char(10, "Crane", "Doji")
	father.gender = "male"
	var mother: L5RCharacterData = _make_char(11, "Crane", "Doji")
	mother.gender = "female"
	father.disposition_values[11] = 70
	mother.disposition_values[10] = 70
	var chars_by_id: Dictionary = {10: father, 11: mother}

	var marriage: Dictionary = MarriageSystem.create_marriage(
		10, 11, MarriageSystem.MarriageType.WITHIN_FAMILY, -1, 50,
	)
	marriage["active"] = false
	var marriages: Array = [marriage]
	var children: Array = []

	var results: Array = DayOrchestrator._process_pregnancy_checks(
		marriages, chars_by_id, children, _dice, 100,
	)
	assert_eq(results.size(), 0, "No pregnancy from inactive marriage")


func test_pregnancy_skips_dead_spouse() -> void:
	var father: L5RCharacterData = _make_char(10, "Crane", "Doji")
	father.gender = "male"
	father.wounds_taken = 999
	var mother: L5RCharacterData = _make_char(11, "Crane", "Doji")
	mother.gender = "female"
	father.disposition_values[11] = 70
	mother.disposition_values[10] = 70
	var chars_by_id: Dictionary = {10: father, 11: mother}

	var marriage: Dictionary = MarriageSystem.create_marriage(
		10, 11, MarriageSystem.MarriageType.WITHIN_FAMILY, -1, 50,
	)
	var marriages: Array = [marriage]
	var children: Array = []

	var results: Array = DayOrchestrator._process_pregnancy_checks(
		marriages, chars_by_id, children, _dice, 100,
	)
	assert_eq(results.size(), 0, "No pregnancy when spouse is dead")


func test_pregnancy_skips_same_gender_non_bisexual() -> void:
	var char_a: L5RCharacterData = _make_char(10, "Crane", "Doji")
	char_a.gender = "male"
	var char_b: L5RCharacterData = _make_char(11, "Crane", "Doji")
	char_b.gender = "male"
	char_a.disposition_values[11] = 70
	char_b.disposition_values[10] = 70
	var chars_by_id: Dictionary = {10: char_a, 11: char_b}

	var marriage: Dictionary = MarriageSystem.create_marriage(
		10, 11, MarriageSystem.MarriageType.WITHIN_FAMILY, -1, 50,
	)
	var marriages: Array = [marriage]
	var children: Array = []

	var results: Array = DayOrchestrator._process_pregnancy_checks(
		marriages, chars_by_id, children, _dice, 100,
	)
	assert_eq(results.size(), 0, "Same-gender couples cannot have biological children")


func test_pregnancy_zero_chance_at_hostile_disposition() -> void:
	var father: L5RCharacterData = _make_char(10, "Crane", "Doji")
	father.gender = "male"
	var mother: L5RCharacterData = _make_char(11, "Crane", "Doji")
	mother.gender = "female"
	father.disposition_values[11] = -50
	mother.disposition_values[10] = -50
	var chars_by_id: Dictionary = {10: father, 11: mother}

	var marriage: Dictionary = MarriageSystem.create_marriage(
		10, 11, MarriageSystem.MarriageType.WITHIN_FAMILY, -1, 50,
	)
	var marriages: Array = [marriage]
	var children: Array = []

	for _i: int in range(50):
		var results: Array = DayOrchestrator._process_pregnancy_checks(
			marriages, chars_by_id, children, _dice, 100 + _i,
		)
		assert_eq(results.size(), 0, "Hostile disposition = 0% pregnancy chance")


func test_pregnancy_adds_child_to_marriage_record() -> void:
	var father: L5RCharacterData = _make_char(10, "Crane", "Doji")
	father.gender = "male"
	var mother: L5RCharacterData = _make_char(11, "Crane", "Doji")
	mother.gender = "female"
	father.disposition_values[11] = 80
	mother.disposition_values[10] = 80
	var chars_by_id: Dictionary = {10: father, 11: mother}

	var marriage: Dictionary = MarriageSystem.create_marriage(
		10, 11, MarriageSystem.MarriageType.WITHIN_FAMILY, -1, 50,
	)
	var marriages: Array = [marriage]
	var children: Array = []

	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(1)

	var found: bool = false
	for _i: int in range(20):
		var results: Array = DayOrchestrator._process_pregnancy_checks(
			marriages, chars_by_id, children, dice, 100 + _i,
		)
		if results.size() > 0:
			found = true
			var m_children: Array = marriage.get("children_ids", [])
			assert_true(m_children.has(results[0]["child_id"]), "Marriage record tracks child")
			break

	assert_true(found, "Should have produced a child")


# -- Marriageable Vassal Detection Tests ----------------------------------------

func test_find_marriageable_vassals_returns_unmarried() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var vassal: L5RCharacterData = _make_char(2, "Crane", "Doji")
	vassal.lord_id = 1
	vassal.spouse_id = -1
	var married: L5RCharacterData = _make_char(3, "Crane", "Doji")
	married.lord_id = 1
	married.spouse_id = 5
	var chars_by_id: Dictionary = {1: lord, 2: vassal, 3: married}

	var result: Array = NPCDecisionEngine._find_marriageable_vassals(lord, chars_by_id)
	assert_true(result.has(2), "Unmarried vassal included")
	assert_false(result.has(3), "Married vassal excluded")
	assert_false(result.has(1), "Lord excluded from own list")


func test_find_marriageable_vassals_includes_children() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	lord.children_ids = [4]
	var child: L5RCharacterData = _make_char(4, "Crane", "Doji")
	child.lord_id = 99
	child.spouse_id = -1
	var chars_by_id: Dictionary = {1: lord, 4: child}

	var result: Array = NPCDecisionEngine._find_marriageable_vassals(lord, chars_by_id)
	assert_true(result.has(4), "Lord's child included even with different lord_id")


func test_find_marriageable_vassals_excludes_dead() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var vassal: L5RCharacterData = _make_char(2, "Crane", "Doji")
	vassal.lord_id = 1
	vassal.spouse_id = -1
	vassal.wounds_taken = 999
	var chars_by_id: Dictionary = {1: lord, 2: vassal}

	var result: Array = NPCDecisionEngine._find_marriageable_vassals(lord, chars_by_id)
	assert_eq(result.size(), 0, "Dead vassal excluded")


# -- Decomposition Tree Tests ---------------------------------------------------

func test_advance_family_produces_arrange_marriage() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.target_npc_id, 2, "Candidate is the unmarried vassal")
	assert_eq(need.target_npc_id_secondary, 10, "Target lord from known contacts")


func test_advance_family_skips_marriage_without_candidates() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = []
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE", "Falls through when no candidates")


func test_accumulate_leverage_produces_arrange_marriage() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Scorpion": [20]}
	ctx.dispositions = {20: 0}

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ACCUMULATE_LEVERAGE", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")


func test_maintain_peace_produces_arrange_marriage_no_war() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}
	ctx.active_wars = []
	ctx.escalating_conflicts = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "MAINTAIN_PEACE", "category": "military"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")


func test_maintain_peace_prioritizes_war_over_marriage() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}
	ctx.active_wars = [{"clan_a": "Crane", "clan_b": "Lion", "enemy_clan_id": "Lion"}]
	ctx.escalating_conflicts = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "MAINTAIN_PEACE", "category": "military"}, ctx,
	)
	assert_eq(need.need_type, "SEEK_PEACE", "Active war takes priority over marriage")


func test_marriage_skipped_at_court() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord, Enums.ContextFlag.AT_COURT)
	ctx.is_lord = true
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE", "Marriage only arranged from own holdings")


func test_marriage_same_clan_used_as_between_families_fallback() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Crane": [10]}
	ctx.dispositions = {10: 5}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE", "Same-clan contacts used for between-families marriage")


func test_executor_auto_selects_target_candidate() -> void:
	var lord_a: L5RCharacterData = _make_char(1, "Crane", "Doji", 6.0)
	var candidate: L5RCharacterData = _make_char(2, "Crane", "Doji")
	candidate.lord_id = 1
	var lord_b: L5RCharacterData = _make_char(10, "Lion", "Akodo", 6.0)
	lord_b.disposition_values[1] = 20
	var target_candidate: L5RCharacterData = _make_char(11, "Lion", "Akodo")
	target_candidate.lord_id = 10
	target_candidate.status = 3.0
	target_candidate.glory = 2.0
	var chars_by_id: Dictionary = {1: lord_a, 2: candidate, 10: lord_b, 11: target_candidate}

	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord_a)
	var action: NPCDataStructures.ScoredAction = _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 2,
		"target_lord_id": 10,
		"target_candidate_id": -1,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	var effects: Dictionary = result.get("effects", {})

	if effects.get("requires_marriage", false):
		assert_eq(effects.get("candidate_b_id", -1), 11, "Auto-selected target candidate")
	else:
		assert_true(result.get("success", false), "Marriage should succeed with auto-selection")


# -- Birth Family Disposition Floor Tests ----------------------------------------

func test_birth_family_floor_enforced_for_birth_family_members() -> void:
	var actor: L5RCharacterData = _make_char(1, "Crane", "Doji")
	actor.birth_clan = "Lion"
	actor.birth_family = "Akodo"
	var target: L5RCharacterData = _make_char(2, "Lion", "Akodo")
	actor.disposition_values[2] = -50
	var chars_by_id: Dictionary = {1: actor, 2: target}

	var eff: int = DispositionSystem.get_effective_disposition(actor, 2, chars_by_id)
	assert_eq(eff, MarriageSystem.BIRTH_FAMILY_DISPOSITION_FLOOR, "Birth family floor (+15) enforced")


func test_birth_clan_floor_enforced_for_birth_clan_members() -> void:
	var actor: L5RCharacterData = _make_char(1, "Crane", "Doji")
	actor.birth_clan = "Lion"
	actor.birth_family = "Akodo"
	var target: L5RCharacterData = _make_char(2, "Lion", "Matsu")
	actor.disposition_values[2] = -50
	var chars_by_id: Dictionary = {1: actor, 2: target}

	var eff: int = DispositionSystem.get_effective_disposition(actor, 2, chars_by_id)
	assert_eq(eff, MarriageSystem.BIRTH_CLAN_DISPOSITION_FLOOR, "Birth clan floor (+8) enforced")


func test_birth_family_floor_not_applied_to_other_clans() -> void:
	var actor: L5RCharacterData = _make_char(1, "Crane", "Doji")
	actor.birth_clan = "Lion"
	actor.birth_family = "Akodo"
	var target: L5RCharacterData = _make_char(2, "Scorpion", "Bayushi")
	actor.disposition_values[2] = -50
	var chars_by_id: Dictionary = {1: actor, 2: target}

	var eff: int = DispositionSystem.get_effective_disposition(actor, 2, chars_by_id)
	assert_eq(eff, -50, "No floor for unrelated clan members")


func test_no_floor_without_birth_clan() -> void:
	var actor: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var target: L5RCharacterData = _make_char(2, "Crane", "Doji")
	actor.disposition_values[2] = -50
	var chars_by_id: Dictionary = {1: actor, 2: target}

	var eff: int = DispositionSystem.get_effective_disposition(actor, 2, chars_by_id)
	assert_eq(eff, -50, "No floor when birth_clan is empty (never married away)")


func test_birth_family_floor_does_not_raise_above_floor() -> void:
	var actor: L5RCharacterData = _make_char(1, "Crane", "Doji")
	actor.birth_clan = "Lion"
	actor.birth_family = "Akodo"
	var target: L5RCharacterData = _make_char(2, "Lion", "Akodo")
	actor.disposition_values[2] = 30
	var chars_by_id: Dictionary = {1: actor, 2: target}

	var eff: int = DispositionSystem.get_effective_disposition(actor, 2, chars_by_id)
	assert_eq(eff, 30, "Floor doesn't override already-higher disposition")


# -- Cooldown Tests -------------------------------------------------------------

func test_cooldown_blocks_recent_marriage_attempt() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}
	ctx.province_statuses = []
	ctx.ic_day = 100
	ctx.action_log = [{"action_id": "ARRANGE_MARRIAGE", "character_id": 1, "ic_day": 50}]

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE", "Blocked by 90-day cooldown (50 days ago)")


func test_cooldown_allows_expired_marriage_attempt() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}
	ctx.province_statuses = []
	ctx.ic_day = 200
	ctx.action_log = [{"action_id": "ARRANGE_MARRIAGE", "character_id": 1, "ic_day": 50}]

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE", "Allowed after 150 days (>90 cooldown)")


func test_cooldown_ignores_other_characters_attempts() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: 5}
	ctx.province_statuses = []
	ctx.ic_day = 100
	ctx.action_log = [{"action_id": "ARRANGE_MARRIAGE", "character_id": 999, "ic_day": 50}]

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE", "Other character's attempt does not trigger cooldown")


# -- Smarter Target Lord Selection Tests ----------------------------------------

func test_smarter_selection_picks_lowest_disposition() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10, 11]}
	ctx.dispositions = {10: 20, 11: 0}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.target_npc_id_secondary, 11, "Picks lowest-disposition contact for maximum benefit")


func test_smarter_selection_skips_below_minus_ten() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10, 11]}
	ctx.dispositions = {10: -15, 11: -20}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE", "All contacts below -10 disposition, falls through")


func test_smarter_selection_boundary_minus_ten_allowed() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Lion": [10]}
	ctx.dispositions = {10: -10}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE", "Contact at exactly -10 disposition is allowed")


# -- Benten Festival Gate Tests -------------------------------------------------

func test_benten_festival_boosts_acceptance() -> void:
	var lord_a: L5RCharacterData = _make_char(1, "Crane", "Doji", 6.0)
	var candidate: L5RCharacterData = _make_char(2, "Crane", "Doji")
	candidate.lord_id = 1
	var lord_b: L5RCharacterData = _make_char(10, "Lion", "Akodo", 6.0)
	lord_b.disposition_values[1] = -15
	var target_candidate: L5RCharacterData = _make_char(11, "Lion", "Akodo")
	target_candidate.lord_id = 10
	target_candidate.status = 3.0
	target_candidate.glory = 2.0
	var chars_by_id: Dictionary = {1: lord_a, 2: candidate, 10: lord_b, 11: target_candidate}

	# BENTEN_FESTIVAL_MONTH=11, BENTEN_FESTIVAL_DAY=9.
	# is_benten_festival computes month = int(day_of_year/30)+1, day = (day_of_year%30)+1.
	# For month=11, day=9: day_of_year = (11-1)*30 + (9-1) = 308.
	var benten_ic_day: int = (11 - 1) * 30 + (9 - 1)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord_a)
	ctx.ic_day = benten_ic_day
	var action: NPCDataStructures.ScoredAction = _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 2,
		"target_lord_id": 10,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("requires_marriage", false), "Benten bonus (+20) should push marginal proposal to acceptance")


func test_no_benten_bonus_on_normal_day() -> void:
	var lord_a: L5RCharacterData = _make_char(1, "Crane", "Doji", 6.0)
	var candidate: L5RCharacterData = _make_char(2, "Crane", "Doji")
	candidate.lord_id = 1
	var lord_b: L5RCharacterData = _make_char(10, "Lion", "Akodo", 6.0)
	lord_b.disposition_values[1] = -15
	var target_candidate: L5RCharacterData = _make_char(11, "Lion", "Akodo")
	target_candidate.lord_id = 10
	target_candidate.status = 3.0
	target_candidate.glory = 2.0
	var chars_by_id: Dictionary = {1: lord_a, 2: candidate, 10: lord_b, 11: target_candidate}

	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord_a)
	ctx.ic_day = 10
	var action: NPCDataStructures.ScoredAction = _make_action("ARRANGE_MARRIAGE", {
		"candidate_id": 2,
		"target_lord_id": 10,
		"target_candidate_id": 11,
	})

	var result: Dictionary = ActionExecutor.execute(action, lord_a, ctx, _dice, {}, {}, chars_by_id)
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("marriage_rejected", false), "Without Benten bonus, marginal proposal rejected")


# -- Between-Families Fallback Tests --------------------------------------------

func test_between_families_fallback_when_no_cross_clan() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Crane": [10]}
	ctx.dispositions = {10: 5}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE", "Falls back to between-families when no cross-clan")
	assert_eq(need.target_npc_id_secondary, 10, "Between-families lord from same clan")


func test_between_families_skips_self() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Crane": [1]}
	ctx.dispositions = {1: 0}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_ne(need.need_type, "ARRANGE_MARRIAGE", "Skips self in between-families search")


func test_between_families_picks_lowest_disposition() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Crane": [10, 11]}
	ctx.dispositions = {10: 20, 11: 0}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.target_npc_id_secondary, 11, "Between-families picks lowest disposition contact")


func test_cross_clan_preferred_over_between_families() -> void:
	var lord: L5RCharacterData = _make_char(1, "Crane", "Doji")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(lord)
	ctx.is_lord = true
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.marriageable_vassal_ids = [2]
	ctx.known_contacts_by_clan = {"Crane": [10], "Lion": [20]}
	ctx.dispositions = {10: 5, 20: 5}
	ctx.province_statuses = []

	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		{"need_type": "ADVANCE_FAMILY", "category": "political"}, ctx,
	)
	assert_eq(need.need_type, "ARRANGE_MARRIAGE")
	assert_eq(need.target_npc_id_secondary, 20, "Cross-clan preferred when available")
