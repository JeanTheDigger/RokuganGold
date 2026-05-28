extends GutTest
## Tests for CourtActionSystem (s15.4 Court Action Menu).


# -- Helpers -------------------------------------------------------------------

var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)


func _make_char(id: int, skills: Dictionary = {}, traits: Dictionary = {}) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Crane"
	c.family = "Doji"
	c.school = "Doji Courtier"
	c.honor = 5.0
	c.glory = 3.0
	c.status = 4.0
	c.physical_location = "court_a"
	c.strength = 2
	c.willpower = 3
	c.stamina = 2
	c.reflexes = 3
	c.awareness = 3
	c.intelligence = 3
	c.agility = 2
	c.perception = 3
	var _trait_map: Dictionary = {
		"Strength": Enums.Trait.STRENGTH, "Willpower": Enums.Trait.WILLPOWER,
		"Stamina": Enums.Trait.STAMINA, "Reflexes": Enums.Trait.REFLEXES,
		"Awareness": Enums.Trait.AWARENESS, "Intelligence": Enums.Trait.INTELLIGENCE,
		"Agility": Enums.Trait.AGILITY, "Perception": Enums.Trait.PERCEPTION,
	}
	for k: String in traits:
		if _trait_map.has(k):
			c.set_trait_value(_trait_map[k], traits[k])
	c.skills = {
		"Courtier": 3, "Etiquette": 3, "Sincerity": 3, "Investigation": 3,
		"Intimidation": 2, "Lore": 2,
	}
	for k: String in skills:
		c.skills[k] = skills[k]
	return c


# -- Negotiate ----------------------------------------------------------------

func test_negotiate_success_base() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(20, 15, 0, false, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.NEGOTIATE_BASE_DISP)


func test_negotiate_success_with_raises() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(30, 15, 3, false, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.NEGOTIATE_BASE_DISP + 3 * CourtActionSystem.NEGOTIATE_RAISE_BONUS)


func test_negotiate_success_topic_position_shift() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(25, 15, 2, true, 0)
	assert_true(r["success"])
	assert_true(r.has("target_position_shift"))
	assert_eq(r["target_position_shift"], CourtActionSystem.NEGOTIATE_POSITION_SHIFT + 2 * CourtActionSystem.NEGOTIATE_RAISE_POSITION_BONUS)


func test_negotiate_session_tn_reduction() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(20, 15, 0, false, 0)
	assert_eq(r["session_tn_reduction"], CourtActionSystem.NEGOTIATE_SESSION_TN_REDUCTION)


func test_negotiate_failure_no_topic() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(10, 15, 0, false, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], 0)


func test_negotiate_failure_topic_hardens() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(10, 15, 0, true, 0)
	assert_false(r["success"])
	assert_true(r.get("position_hardened", false))
	assert_eq(r["target_position_shift"], -1.0)


func test_negotiate_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(5, 20, 0, true, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], -6)
	assert_eq(r["target_position_shift"], -3.0)


# -- Persuade -----------------------------------------------------------------

func test_persuade_success_base() -> void:
	var r: Dictionary = CourtActionSystem.resolve_persuade(20, 15, 0, false)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.PERSUADE_BASE_DISP)


func test_persuade_success_topic_durable() -> void:
	var r: Dictionary = CourtActionSystem.resolve_persuade(25, 15, 2, true)
	assert_true(r["success"])
	assert_true(r.get("position_durable", false))
	assert_eq(r["target_position_shift"], CourtActionSystem.PERSUADE_POSITION_SHIFT + 2 * CourtActionSystem.PERSUADE_RAISE_POSITION_BONUS)


func test_persuade_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_persuade(10, 15, 0, false)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], 0)


func test_persuade_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_persuade(5, 20, 0, true)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], -7)
	assert_true(r.get("position_hardened", false))


# -- Charm --------------------------------------------------------------------

func test_charm_success_base() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 0, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.CHARM_FULL_GAIN)


func test_charm_ceiling_caps_at_40() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 38, 0)
	assert_true(r["success"])
	var expected: int = mini(CourtActionSystem.CHARM_FULL_GAIN, CourtActionSystem.CHARM_CEILING - 38)
	assert_eq(r["disposition_change"], maxi(expected, 0))


func test_charm_ceiling_already_at_cap() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 40, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], 0)
	assert_true(r.get("charm_ceiling_active", false))


func test_charm_diminishing_half() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 0, 2)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.CHARM_FULL_GAIN / 2)


func test_charm_diminishing_minimal() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 0, 3)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], maxi(CourtActionSystem.CHARM_FULL_GAIN / 4, 0))


func test_charm_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(10, 15, 0, 0, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], 0)


func test_charm_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(5, 20, 0, 0, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], -5)


# -- Impress ------------------------------------------------------------------

func test_impress_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_impress(20, 15, 1)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.IMPRESS_BASE_DISP + 1 * CourtActionSystem.IMPRESS_RAISE_BONUS)
	assert_eq(r["session_tn_reduction"], CourtActionSystem.IMPRESS_SESSION_TN_REDUCTION)
	assert_false(r.has("target_position_shift"))


func test_impress_success_with_topic() -> void:
	var r: Dictionary = CourtActionSystem.resolve_impress(20, 15, 1, true)
	assert_true(r["success"])
	assert_eq(r["target_position_shift"], CourtActionSystem.IMPRESS_POSITION_SHIFT)


func test_impress_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_impress(5, 20, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], -6)


# -- Listen and Reflect -------------------------------------------------------

func test_listen_reflect_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_listen_reflect(20, 15, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], CourtActionSystem.LISTEN_REFLECT_BASE_DISP)
	assert_eq(r["persuade_negotiate_tn_reduction"], CourtActionSystem.LISTEN_REFLECT_SESSION_TN_REDUCTION)
	assert_false(r.has("target_position_shift"))


func test_listen_reflect_success_with_topic() -> void:
	var r: Dictionary = CourtActionSystem.resolve_listen_reflect(20, 15, 2, true)
	assert_true(r["success"])
	assert_eq(r["target_position_shift"], CourtActionSystem.LISTEN_REFLECT_POSITION_SHIFT + 2 * CourtActionSystem.LISTEN_REFLECT_RAISE_POSITION_BONUS)


func test_listen_reflect_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_listen_reflect(5, 20, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], -7)


# -- Offer Favor --------------------------------------------------------------

func test_offer_favor_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_offer_favor(20, 15)
	assert_true(r["success"])
	assert_true(r.get("requires_favor_creation", false))


func test_offer_favor_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_offer_favor(10, 15)
	assert_false(r["success"])


# -- Play a Game --------------------------------------------------------------

func test_play_game_a_wins() -> void:
	var r: Dictionary = CourtActionSystem.resolve_play_game(20, 15, 1, 2)
	assert_true(r["success"])
	assert_eq(r["a_disposition_toward_b"], 3)
	assert_eq(r["b_disposition_toward_a"], 4)
	assert_eq(r["winner_id"], 1)


func test_play_game_b_wins() -> void:
	var r: Dictionary = CourtActionSystem.resolve_play_game(10, 20, 1, 2)
	assert_eq(r["a_disposition_toward_b"], 4)
	assert_eq(r["b_disposition_toward_a"], 3)
	assert_eq(r["winner_id"], 2)


func test_play_game_tie() -> void:
	var r: Dictionary = CourtActionSystem.resolve_play_game(15, 15, 1, 2)
	assert_eq(r["a_disposition_toward_b"], 3)
	assert_eq(r["b_disposition_toward_a"], 3)
	assert_eq(r["winner_id"], -1)


# -- Gossip (Split Raises) ---------------------------------------------------

func test_gossip_success_base() -> void:
	var r: Dictionary = CourtActionSystem.resolve_gossip(20, 15, 0, 0)
	assert_true(r["success"])
	assert_eq(r["gossip_subject_disposition"], -5)
	assert_false(r["source_concealed"])


func test_gossip_damage_raises() -> void:
	var r: Dictionary = CourtActionSystem.resolve_gossip(30, 15, 2, 0)
	assert_true(r["success"])
	assert_eq(r["gossip_subject_disposition"], -5 + 2 * -2)


func test_gossip_concealment_raises() -> void:
	var r: Dictionary = CourtActionSystem.resolve_gossip(30, 15, 0, 2)
	assert_true(r["success"])
	assert_true(r["source_concealed"])
	assert_eq(r["concealment_depth"], 2)
	assert_eq(r["gossip_subject_disposition"], -5)


func test_gossip_split_raises() -> void:
	var r: Dictionary = CourtActionSystem.resolve_gossip(30, 15, 1, 2)
	assert_true(r["success"])
	assert_eq(r["gossip_subject_disposition"], -7)
	assert_true(r["source_concealed"])


func test_gossip_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_gossip(10, 15, 0, 0)
	assert_false(r["success"])
	assert_false(r.has("gossip_subject_disposition"))


func test_gossip_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_gossip(5, 20, 0, 0)
	assert_false(r["success"])
	assert_eq(r.get("disposition_change", 0), -5)


func test_gossip_tn_computation() -> void:
	assert_eq(CourtActionSystem.compute_gossip_tn(10.0, 3.0), 45)
	assert_eq(CourtActionSystem.compute_gossip_tn(0.0, 5.0), 5)
	assert_eq(CourtActionSystem.compute_gossip_tn(0.0, 0.0), 10)


# -- Disclose -----------------------------------------------------------------

func test_disclose_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_disclose(20, 15, -30)
	assert_true(r["success"])
	assert_true(r["info_gained"])
	assert_eq(r["disclosed_opinion"], -30)


func test_disclose_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_disclose(5, 20, 0)
	assert_false(r["success"])
	assert_eq(r.get("disposition_change", 0), -5)


# -- Provoke Emotion ----------------------------------------------------------

func test_provoke_emotion_success() -> void:
	var witnesses: Array = [10, 11, 12]
	var r: Dictionary = CourtActionSystem.resolve_provoke_emotion(20, 15, witnesses)
	assert_true(r["success"])
	assert_eq(r["target_honor_change"], -0.2)
	assert_eq(r["target_glory_change"], -0.1)
	assert_eq(r["target_witness_disposition"], -3)
	assert_eq(r["witnesses"].size(), 3)


func test_provoke_emotion_failure() -> void:
	var witnesses: Array = [10, 11]
	var r: Dictionary = CourtActionSystem.resolve_provoke_emotion(10, 15, witnesses)
	assert_false(r["success"])
	assert_false(r.has("target_honor_change"))


func test_provoke_emotion_critical_failure() -> void:
	var witnesses: Array = [10, 11]
	var r: Dictionary = CourtActionSystem.resolve_provoke_emotion(5, 20, witnesses)
	assert_false(r["success"])
	assert_eq(r["witness_disposition_loss"], -5)
	assert_eq(r["witnesses"].size(), 2)


# -- Public Debate (Per-Witness) ---------------------------------------------

func test_debate_a_wins_all_neutral() -> void:
	var disp_a: Dictionary = {10: 0, 11: 0}
	var disp_b: Dictionary = {10: 0, 11: 0}
	var r: Dictionary = CourtActionSystem.resolve_public_debate(20, 15, disp_a, disp_b, 1)
	assert_true(r["success"])
	var pw: Array = r["per_witness_results"]
	assert_eq(pw.size(), 2)
	for w: Dictionary in pw:
		assert_true(w["a_won_for_witness"])
		assert_gt(w["a_disposition_change"], 0)
		assert_lt(w["b_disposition_change"], 0)


func test_debate_position_shift_by_raises() -> void:
	var disp_a: Dictionary = {10: 0}
	var disp_b: Dictionary = {10: 0}
	var r0: Dictionary = CourtActionSystem.resolve_public_debate(20, 15, disp_a, disp_b, 0)
	var r1: Dictionary = CourtActionSystem.resolve_public_debate(20, 15, disp_a, disp_b, 1)
	var r2: Dictionary = CourtActionSystem.resolve_public_debate(20, 15, disp_a, disp_b, 2)
	var r3: Dictionary = CourtActionSystem.resolve_public_debate(20, 15, disp_a, disp_b, 3)
	assert_eq(r0["per_witness_results"][0]["position_shift_toward_a"], 2.0)
	assert_eq(r1["per_witness_results"][0]["position_shift_toward_a"], 4.0)
	assert_eq(r2["per_witness_results"][0]["position_shift_toward_a"], 6.0)
	assert_eq(r3["per_witness_results"][0]["position_shift_toward_a"], 8.0)


func test_debate_disposition_tiers_affect_outcome() -> void:
	var disp_a: Dictionary = {10: 3}
	var disp_b: Dictionary = {10: -2}
	var r: Dictionary = CourtActionSystem.resolve_public_debate(18, 18, disp_a, disp_b, 0)
	var pw: Dictionary = r["per_witness_results"][0]
	assert_gt(pw["combined_score"], 0)
	assert_true(pw["a_won_for_witness"])


func test_debate_b_wins_with_disposition_advantage() -> void:
	var disp_a: Dictionary = {10: -3}
	var disp_b: Dictionary = {10: 3}
	var r: Dictionary = CourtActionSystem.resolve_public_debate(18, 18, disp_a, disp_b, 0)
	var pw: Dictionary = r["per_witness_results"][0]
	assert_lt(pw["combined_score"], 0)
	assert_false(pw["a_won_for_witness"])


func test_debate_neutral_score_no_change() -> void:
	var disp_a: Dictionary = {10: 0}
	var disp_b: Dictionary = {10: 0}
	var r: Dictionary = CourtActionSystem.resolve_public_debate(15, 15, disp_a, disp_b, 0)
	var pw: Dictionary = r["per_witness_results"][0]
	assert_eq(pw["combined_score"], 0)
	assert_eq(pw["a_disposition_change"], 0)
	assert_eq(pw["b_disposition_change"], 0)
	assert_eq(pw["position_shift_toward_a"], 0.0)


# -- Read Character -----------------------------------------------------------

func test_read_character_success_one_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_read_character(17, 15, _dice)
	assert_true(r["success"])
	assert_eq(r["info_count"], 1)
	assert_eq(r["info_types"].size(), 1)


func test_read_character_success_two_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_read_character(25, 15, _dice)
	assert_true(r["success"])
	# margin=10, raises=int(10/5)=2, raises>=2 gives count=3
	assert_eq(r["info_count"], 3)


func test_read_character_success_three_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_read_character(30, 15, _dice)
	assert_true(r["success"])
	assert_eq(r["info_count"], 3)


func test_read_character_partial_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_read_character(16, 15, _dice)
	assert_true(r["success"])
	assert_true(r.get("partial", false))
	assert_eq(r["info_count"], 1)


func test_read_character_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_read_character(10, 15, _dice)
	assert_false(r["success"])
	assert_false(r.has("info_types"))


func test_read_character_critical_failure_false_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_read_character(5, 20, _dice)
	assert_false(r["success"])
	assert_true(r.get("critical_failure", false))
	assert_eq(r["false_info"].size(), 1)
	assert_true(r["false_info"][0] in CourtActionSystem.READ_CHARACTER_INFO_TYPES)


# -- Probe --------------------------------------------------------------------

func test_probe_success_one_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_probe(17, 15, _dice)
	assert_true(r["success"])
	assert_eq(r["info_count"], 1)
	assert_true(r["detected"])


func test_probe_success_both_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_probe(25, 15, _dice)
	assert_true(r["success"])
	assert_eq(r["info_count"], 2)


func test_probe_failure_still_detected() -> void:
	var r: Dictionary = CourtActionSystem.resolve_probe(10, 15, _dice)
	assert_false(r["success"])
	assert_true(r["detected"])


func test_probe_critical_failure_false_info() -> void:
	var r: Dictionary = CourtActionSystem.resolve_probe(5, 20, _dice)
	assert_false(r["success"])
	assert_true(r.get("critical_failure", false))
	assert_eq(r["false_info"].size(), 1)


# -- Discern Need -------------------------------------------------------------

func test_discern_need_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_discern_need(20, 15)
	assert_true(r["success"])
	assert_true(r["info_gained"])
	assert_eq(r["info_type"], "priority_objective")


func test_discern_need_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_discern_need(5, 20)
	assert_false(r["success"])
	assert_true(r.get("critical_failure", false))
	assert_eq(r["disposition_change"], -3)
	assert_true(r["detected"])


func test_discern_need_failure_no_detection() -> void:
	var r: Dictionary = CourtActionSystem.resolve_discern_need(10, 15)
	assert_false(r["success"])
	assert_false(r.has("detected"))


# -- Debate Disposition Tier Lookup -------------------------------------------

func test_debate_tier_blood_enemy() -> void:
	assert_eq(CourtActionSystem.get_debate_disposition_tier(-70), -3)


func test_debate_tier_devoted() -> void:
	assert_eq(CourtActionSystem.get_debate_disposition_tier(95), 3)


func test_debate_tier_stranger() -> void:
	assert_eq(CourtActionSystem.get_debate_disposition_tier(0), 0)


func test_debate_tier_friend() -> void:
	assert_eq(CourtActionSystem.get_debate_disposition_tier(35), 1)


# -- Executor Integration Tests -----------------------------------------------

func _make_action(action_id: String, target_id: int = 2, meta: Dictionary = {}) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = target_id
	a.target_province_id = -1
	a.metadata = meta
	return a


func _make_ctx(char_id: int = 1, disp: Dictionary = {}) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = char_id
	ctx.ic_day = 45
	ctx.season = 0  # SPRING
	ctx.context_flag = Enums.ContextFlag.AT_COURT
	ctx.dispositions = disp
	return ctx


func _build_skill_map() -> Dictionary:
	var loader := ScoringTableLoader.new()
	loader.load_all()
	return loader.get_table("action_skill_map")


func test_executor_negotiate_contested() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 4})
	var target: L5RCharacterData = _make_char(2, {"Courtier": 1}, {"Awareness": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("NEGOTIATE")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(1, {2: 0})
	var skill_map: Dictionary = _build_skill_map()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, skill_map, {}, chars
	)
	assert_eq(result["action_id"], "NEGOTIATE")
	assert_true(result.has("effects"))
	assert_true(result["effects"].has("disposition_change"))


func test_executor_charm_ceiling_enforced() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Etiquette": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Awareness": 1})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"CHARM", 2, {"session_charm_count": 0}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(1, {2: 39})

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result["success"]:
		assert_true(
			result["effects"].get("disposition_change", 0) <= 1,
			"Disposition change should be <= 1 due to charm ceiling",
		)


func test_executor_provoke_emotion() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Willpower": 2})
	var witness: L5RCharacterData = _make_char(3)
	witness.physical_location = "court_a"
	var chars: Dictionary = {1: actor, 2: target, 3: witness}
	var action: NPCDataStructures.ScoredAction = _make_action("PROVOKE_EMOTION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "PROVOKE_EMOTION")
	if result["success"]:
		assert_true(result["effects"].has("target_honor_change"))
		assert_true(result["effects"].has("witnesses"))


func test_executor_play_game() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Games: Go": 3}, {"Intelligence": 4})
	var target: L5RCharacterData = _make_char(2, {"Games: Go": 2}, {"Intelligence": 3})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"PLAY_GAME", 2, {"game_skill": "Games: Go"}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "PLAY_GAME")
	assert_true(result["success"])
	assert_true(result["effects"].has("a_disposition_toward_b"))
	assert_true(result["effects"].has("b_disposition_toward_a"))
	assert_true(result["effects"]["a_disposition_toward_b"] >= 3,
		"a_disposition_toward_b should be >= 3")
	assert_true(result["effects"]["b_disposition_toward_a"] >= 3,
		"b_disposition_toward_a should be >= 3")


func test_executor_discern_need() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Investigation": 4}, {"Awareness": 4})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Awareness": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("DISCERN_NEED")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "DISCERN_NEED")


func test_executor_read_character_contested() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Investigation": 5}, {"Perception": 4})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Awareness": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("READ_CHARACTER")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "READ_CHARACTER")
	if result["success"]:
		assert_true(result["effects"].has("info_gained"))


func test_executor_probe_contested() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Perception": 4})
	var target: L5RCharacterData = _make_char(2, {"Sincerity": 1}, {"Awareness": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("PROBE")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "PROBE")
	assert_true(result["effects"].get("detected", false))


func test_executor_public_debate_per_witness() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Courtier": 1}, {"Awareness": 2})
	var witness: L5RCharacterData = _make_char(3)
	witness.physical_location = "court_a"
	witness.disposition_values = {1: 10, 2: -5}
	var chars: Dictionary = {1: actor, 2: target, 3: witness}
	var action: NPCDataStructures.ScoredAction = _make_action("PUBLIC_DEBATE")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "PUBLIC_DEBATE")
	assert_true(result["effects"].has("debate_per_witness"))


func test_executor_disclose_contested() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Sincerity": 4}, {"Perception": 4})
	var target: L5RCharacterData = _make_char(2, {"Sincerity": 1}, {"Perception": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"DISCLOSE", 2, {"disclosed_opinion": -20}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["action_id"], "DISCLOSE")


func test_executor_discern_need_yasuki_school() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Commerce": 4}, {"Perception": 4})
	actor.school = "Yasuki Courtier"
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Awareness": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("DISCERN_NEED")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()

	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	assert_eq(result["skill_used"], "Commerce")


# -- Orchestrator Wiring Tests ------------------------------------------------

func _make_day_result(action_id: String, char_id: int, target_id: int, effects: Dictionary) -> Dictionary:
	return {
		"action_id": action_id,
		"character_id": char_id,
		"target_npc_id": target_id,
		"effects": effects,
	}


func test_orchestrator_gossip_subject_disposition() -> void:
	var gossiper: L5RCharacterData = _make_char(1)
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {99: 10}
	var chars: Dictionary = {1: gossiper, 2: listener}
	# Gossip subject disposition is applied via EffectApplicator, not
	# _process_court_action_effects. Route through the correct pipeline.
	var result: Dictionary = {
		"success": true,
		"action_id": "GOSSIP",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"gossip_subject_id": 99,
			"gossip_subject_disposition": -7,
		},
	}
	EffectApplicator.apply(result, chars, {}, [])
	assert_eq(listener.disposition_values[99], 3)


func test_orchestrator_gossip_subject_creates_new_entry() -> void:
	var gossiper: L5RCharacterData = _make_char(1)
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {}
	var chars: Dictionary = {1: gossiper, 2: listener}
	var result: Dictionary = {
		"success": true,
		"action_id": "GOSSIP",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"gossip_subject_id": 50,
			"gossip_subject_disposition": -5,
		},
	}
	EffectApplicator.apply(result, chars, {}, [])
	assert_eq(listener.disposition_values[50], -5)


func test_orchestrator_gossip_clamps_at_negative_100() -> void:
	var gossiper: L5RCharacterData = _make_char(1)
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {99: -98}
	var chars: Dictionary = {1: gossiper, 2: listener}
	var result: Dictionary = {
		"success": true,
		"action_id": "GOSSIP",
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {
			"gossip_subject_id": 99,
			"gossip_subject_disposition": -10,
		},
	}
	EffectApplicator.apply(result, chars, {}, [])
	assert_eq(listener.disposition_values[99], -100)


func test_orchestrator_gossip_ignores_invalid_subject() -> void:
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {}
	var chars: Dictionary = {2: listener}
	var results: Array = [_make_day_result("GOSSIP", 1, 2, {
		"gossip_subject_id": -1,
		"gossip_subject_disposition": -5,
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_eq(listener.disposition_values.size(), 0)


func test_orchestrator_disclose_opinion_transfer() -> void:
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {50: 0}
	var chars: Dictionary = {2: listener}
	var results: Array = [_make_day_result("DISCLOSE", 1, 2, {
		"disclosed_opinion": -20,
		"disclose_about_id": 50,
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_eq(listener.disposition_values[50], -10)


func test_orchestrator_disclose_positive_opinion() -> void:
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {50: 5}
	var chars: Dictionary = {2: listener}
	var results: Array = [_make_day_result("DISCLOSE", 1, 2, {
		"disclosed_opinion": 30,
		"disclose_about_id": 50,
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_eq(listener.disposition_values[50], 20)


func test_orchestrator_disclose_ignores_invalid_about_id() -> void:
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {}
	var chars: Dictionary = {2: listener}
	var results: Array = [_make_day_result("DISCLOSE", 1, 2, {
		"disclosed_opinion": -20,
		"disclose_about_id": -1,
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_eq(listener.disposition_values.size(), 0)


func test_orchestrator_disclose_zero_opinion_no_change() -> void:
	var listener: L5RCharacterData = _make_char(2)
	listener.disposition_values = {50: 10}
	var chars: Dictionary = {2: listener}
	var results: Array = [_make_day_result("DISCLOSE", 1, 2, {
		"disclosed_opinion": 0,
		"disclose_about_id": 50,
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_eq(listener.disposition_values[50], 10)


func test_orchestrator_offer_favor_creates_favor() -> void:
	var favors: Array = []
	var chars: Dictionary = {1: _make_char(1), 2: _make_char(2)}
	var results: Array = [_make_day_result("OFFER_FAVOR", 1, 2, {
		"requires_favor_creation": true,
		"favor_creditor_id": 1,
		"favor_debtor_id": 2,
	})]
	DayOrchestrator._process_court_action_effects(results, chars, favors, 45)
	assert_eq(favors.size(), 1)
	var f: FavorData = favors[0]
	assert_eq(f.creditor_id, 1)
	assert_eq(f.debtor_id, 2)
	assert_eq(f.created_ic_day, 45)
	assert_eq(f.favor_type, FavorData.FavorType.GENERAL)
	assert_eq(f.tier, FavorData.FavorTier.MINOR)


func test_orchestrator_offer_favor_increments_id() -> void:
	var existing := FavorData.new()
	existing.favor_id = 5
	var favors: Array = [existing]
	var chars: Dictionary = {1: _make_char(1), 2: _make_char(2)}
	var results: Array = [_make_day_result("OFFER_FAVOR", 1, 2, {
		"requires_favor_creation": true,
		"favor_creditor_id": 1,
		"favor_debtor_id": 2,
	})]
	DayOrchestrator._process_court_action_effects(results, chars, favors, 45)
	assert_eq(favors.size(), 2)
	assert_eq((favors[1] as FavorData).favor_id, 6)


func test_orchestrator_offer_favor_skips_invalid_ids() -> void:
	var favors: Array = []
	var chars: Dictionary = {1: _make_char(1)}
	var results: Array = [_make_day_result("OFFER_FAVOR", 1, -1, {
		"requires_favor_creation": true,
		"favor_creditor_id": -1,
		"favor_debtor_id": 2,
	})]
	DayOrchestrator._process_court_action_effects(results, chars, favors, 45)
	assert_eq(favors.size(), 0)


func test_orchestrator_debate_topic_position_shifts() -> void:
	var witness: L5RCharacterData = _make_char(3)
	witness.topic_positions = {100: 0.0}
	var chars: Dictionary = {
		1: _make_char(1), 2: _make_char(2), 3: witness,
	}
	var results: Array = [_make_day_result("PUBLIC_DEBATE", 1, 2, {
		"debate_per_witness": [
			{
				"witness_id": 3,
				"a_disposition_change": 2,
				"b_disposition_change": -2,
				"position_shift_toward_a": 4.0,
			},
		],
		"_action_metadata": {"topic_id": 100},
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_almost_eq(witness.topic_positions[100], 4.0, 0.01)


func test_orchestrator_debate_negative_position_shift() -> void:
	var witness: L5RCharacterData = _make_char(3)
	witness.topic_positions = {100: 10.0}
	var chars: Dictionary = {
		1: _make_char(1), 2: _make_char(2), 3: witness,
	}
	var results: Array = [_make_day_result("PUBLIC_DEBATE", 1, 2, {
		"debate_per_witness": [
			{
				"witness_id": 3,
				"a_disposition_change": -1,
				"b_disposition_change": 1,
				"position_shift_toward_a": -6.0,
			},
		],
		"_action_metadata": {"topic_id": 100},
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_almost_eq(witness.topic_positions[100], 4.0, 0.01)


func test_orchestrator_debate_no_topic_skips_position() -> void:
	var witness: L5RCharacterData = _make_char(3)
	witness.topic_positions = {}
	var chars: Dictionary = {
		1: _make_char(1), 2: _make_char(2), 3: witness,
	}
	var results: Array = [_make_day_result("PUBLIC_DEBATE", 1, 2, {
		"debate_per_witness": [
			{
				"witness_id": 3,
				"a_disposition_change": 2,
				"b_disposition_change": -2,
				"position_shift_toward_a": 4.0,
			},
		],
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_eq(witness.topic_positions.size(), 0)


func test_orchestrator_debate_position_clamps() -> void:
	var witness: L5RCharacterData = _make_char(3)
	witness.topic_positions = {100: 98.0}
	var chars: Dictionary = {
		1: _make_char(1), 2: _make_char(2), 3: witness,
	}
	var results: Array = [_make_day_result("PUBLIC_DEBATE", 1, 2, {
		"debate_per_witness": [
			{
				"witness_id": 3,
				"a_disposition_change": 0,
				"b_disposition_change": 0,
				"position_shift_toward_a": 8.0,
			},
		],
		"_action_metadata": {"topic_id": 100},
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_almost_eq(witness.topic_positions[100], 100.0, 0.01)


func test_orchestrator_negotiate_position_shift() -> void:
	var target: L5RCharacterData = _make_char(2)
	target.topic_positions = {100: 20.0}
	var chars: Dictionary = {2: target}
	var results: Array = [_make_day_result("NEGOTIATE", 1, 2, {
		"target_position_shift": 5.0,
		"_action_metadata": {"topic_id": 100},
	})]
	DayOrchestrator._process_court_action_effects(results, chars)
	assert_almost_eq(target.topic_positions[100], 25.0, 0.01)


func test_orchestrator_metadata_threads_through_contested() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Courtier": 1}, {"Awareness": 2})
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"NEGOTIATE", 2, {"topic_id": 42}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(1, {2: 0})
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	var meta: Dictionary = result["effects"].get("_action_metadata", {})
	assert_eq(meta.get("topic_id", -1), 42)


# -- Bayushi Courtier Auto-Concealment Tests ----------------------------------

func test_bayushi_gossip_auto_concealed() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	actor.school = "Bayushi Courtier"
	actor.clan = "Scorpion"
	actor.glory = 5.0
	var listener: L5RCharacterData = _make_char(2)
	var subject: L5RCharacterData = _make_char(3)
	subject.glory = 1.0
	var chars: Dictionary = {1: actor, 2: listener, 3: subject}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"GOSSIP", 2, {"gossip_subject_id": 3}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		assert_true(result["effects"].get("source_concealed", false),
			"Bayushi Courtier gossip should always be source_concealed")


func test_non_bayushi_gossip_not_auto_concealed() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	actor.school = "Doji Courtier"
	actor.glory = 5.0
	var listener: L5RCharacterData = _make_char(2)
	var subject: L5RCharacterData = _make_char(3)
	subject.glory = 1.0
	var chars: Dictionary = {1: actor, 2: listener, 3: subject}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"GOSSIP", 2, {"gossip_subject_id": 3, "damage_raises": 99, "concealment_raises": 0}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		assert_false(result["effects"].get("source_concealed", false),
			"Non-Bayushi gossip without concealment raises should not be concealed")


func test_gossip_uses_court_action_system_resolution() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	actor.glory = 5.0
	var listener: L5RCharacterData = _make_char(2)
	var subject: L5RCharacterData = _make_char(3)
	subject.glory = 0.0
	var chars: Dictionary = {1: actor, 2: listener, 3: subject}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"GOSSIP", 2, {"gossip_subject_id": 3}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		assert_true(result["effects"].has("gossip_subject_disposition"))
		assert_true(result["effects"].has("source_concealed"))
		assert_true(result["effects"].has("concealment_depth"))


func test_gossip_damage_raises_split() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	actor.glory = 5.0
	var listener: L5RCharacterData = _make_char(2)
	var subject: L5RCharacterData = _make_char(3)
	subject.glory = 0.0
	var chars: Dictionary = {1: actor, 2: listener, 3: subject}
	var action: NPCDataStructures.ScoredAction = _make_action(
		"GOSSIP", 2, {"gossip_subject_id": 3, "damage_raises": 1, "concealment_raises": 1}
	)
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		var disp: int = result["effects"].get("gossip_subject_disposition", 0)
		assert_eq(disp, CourtActionSystem.GOSSIP_BASE_DISP + 1 * CourtActionSystem.GOSSIP_RAISE_DAMAGE)
		assert_true(result["effects"].get("source_concealed", false))


# -- Ikoma Bard R2 Exemption Tests -------------------------------------------

func test_ikoma_bard_exempt_from_provoke_penalties() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Willpower": 2})
	target.school = "Ikoma Bard"
	target.clan = "Lion"
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("PROVOKE_EMOTION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		assert_true(result["effects"].get("ikoma_bard_exempt", false))
		assert_false(result["effects"].has("target_honor_change"))
		assert_false(result["effects"].has("target_glory_change"))


func test_non_ikoma_not_exempt() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Willpower": 2})
	target.school = "Doji Courtier"
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("PROVOKE_EMOTION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		assert_false(result["effects"].get("ikoma_bard_exempt", false))
		assert_true(result["effects"].has("target_honor_change"))


func test_ikoma_bard_non_lion_not_exempt() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 5}, {"Awareness": 5})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 1}, {"Willpower": 2})
	target.school = "Ikoma Bard"
	target.clan = "Crane"
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("PROVOKE_EMOTION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if result.get("success", false):
		assert_false(result["effects"].get("ikoma_bard_exempt", false),
			"Non-Lion Ikoma Bard should not get the exemption")


func test_ikoma_bard_provoke_failure_still_normal() -> void:
	var actor: L5RCharacterData = _make_char(1, {"Courtier": 1}, {"Awareness": 2})
	var target: L5RCharacterData = _make_char(2, {"Etiquette": 5}, {"Willpower": 5})
	target.school = "Ikoma Bard"
	target.clan = "Lion"
	var chars: Dictionary = {1: actor, 2: target}
	var action: NPCDataStructures.ScoredAction = _make_action("PROVOKE_EMOTION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx()
	var result: Dictionary = ActionExecutor.execute(
		action, actor, ctx, _dice, _build_skill_map(), {}, chars
	)
	if not result.get("success", false):
		assert_true(result["effects"].get("failed", false),
			"Failed provoke against Ikoma Bard should still report failure")


# -- Phase 3 Metadata Population Tests ---------------------------------------

func _make_meta_ctx(court_topics: Array = [], disp: Dictionary = {}) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.ic_day = 45
	ctx.season = 0  # SPRING
	ctx.context_flag = Enums.ContextFlag.AT_COURT
	ctx.dispositions = disp
	ctx.disposition_values = disp.duplicate()
	if not court_topics.is_empty():
		ctx.active_court_at_location = {"topics": court_topics}
	return ctx


func test_metadata_negotiate_gets_topic_id() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "NEGOTIATE"
	action.target_npc_id = 2
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([42, 55])
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 42)


func test_metadata_persuade_gets_topic_id() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PERSUADE"
	action.target_npc_id = 2
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([100])
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 100)


func test_metadata_debate_gets_topic_id() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PUBLIC_DEBATE"
	action.target_npc_id = 2
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([77])
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 77)


func test_metadata_no_court_topic_returns_negative() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "NEGOTIATE"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), -1)


func test_metadata_gossip_subject_from_need() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 99
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "GOSSIP"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("gossip_subject_id", -1), 99)


func test_metadata_gossip_subject_from_worst_disposition() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = -1
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "GOSSIP"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([], {5: -20, 6: -5, 7: 10})
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("gossip_subject_id", -1), 5)


func test_metadata_gossip_no_negative_returns_negative() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = -1
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "GOSSIP"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([], {5: 10, 6: 20})
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("gossip_subject_id", -1), -1)


func test_metadata_gossip_defaults_all_damage_raises() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 99
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "GOSSIP"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("damage_raises", 0), 99)
	assert_eq(action.metadata.get("concealment_raises", -1), 0)


func test_metadata_disclose_about_and_opinion() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 50
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "DISCLOSE"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([], {50: -30})
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("disclose_about_id", -1), 50)
	assert_eq(action.metadata.get("disclosed_opinion", 0), -30)


func test_metadata_disclose_zero_opinion_for_unknown() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 50
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "DISCLOSE"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("disclosed_opinion", -1), 0)


# --- Topic-aware metadata selection ---

func test_topic_picks_strongest_position() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([10, 20, 30])
	ctx.known_topics = [10, 20, 30]
	ctx.known_positions = {10: 5.0, 20: -40.0, 30: 15.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "NEGOTIATE"
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 20, "Should pick topic with highest absolute position")


func test_topic_skips_unknown_topics() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([10, 20, 30])
	ctx.known_topics = [10, 30]
	ctx.known_positions = {10: 5.0, 30: 3.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PERSUADE"
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 10, "Should pick known topic with strongest position")


func test_topic_fallback_to_first_when_none_known() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([42, 55])
	ctx.known_topics = []
	ctx.known_positions = {}
	var need := NPCDataStructures.ImmediateNeed.new()
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "NEGOTIATE"
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 42, "Falls back to first agenda topic")


func test_topic_picks_positive_over_weak_negative() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([10, 20])
	ctx.known_topics = [10, 20]
	ctx.known_positions = {10: 30.0, 20: -10.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "PUBLIC_DEBATE"
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 10, "Strongest absolute position wins regardless of sign")


func test_topic_zero_position_loses_to_any_nonzero() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx([10, 20])
	ctx.known_topics = [10, 20]
	ctx.known_positions = {10: 0.0, 20: -1.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "NEGOTIATE"
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("topic_id", -1), 20)


func test_build_context_populates_known_topics_from_character() -> void:
	var char := L5RCharacterData.new()
	char.character_id = 1
	char.topic_pool = [10, 20, 30]
	char.topic_positions = {10: 5.0, 20: -40.0}
	var ws: Dictionary = {"is_lord": false}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(char, ws)
	assert_eq(ctx.known_topics, [10, 20, 30])
	assert_eq(ctx.known_positions.get(10, 0.0), 5.0)
	assert_eq(ctx.known_positions.get(20, 0.0), -40.0)


# --- Gossip concealment AI ---

func test_gossip_bayushi_courtier_all_damage() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.school = "Bayushi Courtier"
	ctx.clan = "Scorpion"
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["damage"], 99)
	assert_eq(split["concealment"], 0)


func test_gossip_gi_virtue_all_damage() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.bushido_virtue = Enums.BushidoVirtue.GI
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["damage"], 99)
	assert_eq(split["concealment"], 0)


func test_gossip_makoto_virtue_all_damage() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.bushido_virtue = Enums.BushidoVirtue.MAKOTO
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["damage"], 99)
	assert_eq(split["concealment"], 0)


func test_gossip_meiyo_virtue_all_damage() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["damage"], 99)
	assert_eq(split["concealment"], 0)


func test_gossip_seigyo_conceals() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["concealment"], 1)
	assert_eq(split["damage"], 98)


func test_gossip_dosatsu_conceals() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.shourido_virtue = Enums.ShouridoVirtue.DOSATSU
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["concealment"], 1)


func test_gossip_scorpion_clan_conceals() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.clan = "Scorpion"
	ctx.school = "Shosuro Infiltrator"
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["concealment"], 1)
	assert_eq(split["damage"], 98)


func test_gossip_default_all_damage() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.clan = "Crane"
	ctx.bushido_virtue = Enums.BushidoVirtue.REI
	var split: Dictionary = NPCDecisionEngine._compute_gossip_raise_split(ctx)
	assert_eq(split["damage"], 99)
	assert_eq(split["concealment"], 0)


func test_gossip_metadata_uses_split() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 50
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "GOSSIP"
	var ctx: NPCDataStructures.ContextSnapshot = _make_meta_ctx()
	ctx.clan = "Scorpion"
	ctx.school = "Bayushi Bushi"
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	assert_eq(action.metadata.get("concealment_raises", -1), 1)
	assert_eq(action.metadata.get("damage_raises", -1), 98)


# -- ASK_FOR_INTRODUCTION (s55.7.3) -------------------------------------------

func test_ask_intro_success_normal_target() -> void:
	# Roll meets TN 15, non-kuge target → +3 disposition.
	var r: Dictionary = CourtActionSystem.resolve_ask_for_introduction(15, false, 0.0)
	assert_true(r["success"])
	assert_eq(r["disposition_gain"], CourtActionSystem.ASK_FOR_INTRODUCTION_BASE_DISP)
	assert_true(r["contact_added"])


func test_ask_intro_failure_roll_below_tn() -> void:
	var r: Dictionary = CourtActionSystem.resolve_ask_for_introduction(14, false, 0.0)
	assert_false(r["success"])


func test_ask_intro_success_kuge_target_disposition_reduced() -> void:
	# Kuge target (Status 7+) grants only +2 disposition on success.
	var r: Dictionary = CourtActionSystem.resolve_ask_for_introduction(20, true, 5.0)
	assert_true(r["success"])
	assert_eq(r["disposition_gain"], CourtActionSystem.ASK_FOR_INTRODUCTION_KUGE_DISP)
	assert_true(r.get("target_is_kuge", false))


func test_ask_intro_kuge_blocked_intermediary_too_low() -> void:
	# Intermediary Status < 4.0 → blocked for kuge targets.
	var r: Dictionary = CourtActionSystem.resolve_ask_for_introduction(99, true, 3.9)
	assert_false(r["success"])
	assert_eq(r["blocked_reason"], "intermediary_insufficient_status")


func test_ask_intro_kuge_gate_not_applied_for_normal_target() -> void:
	# Intermediary status gate only applies to kuge targets.
	var r: Dictionary = CourtActionSystem.resolve_ask_for_introduction(15, false, 0.0)
	assert_true(r["success"])


func test_ask_intro_kuge_exact_intermediary_threshold_passes() -> void:
	# Exactly Status 4.0 satisfies the kuge intermediary gate.
	var r: Dictionary = CourtActionSystem.resolve_ask_for_introduction(20, true, 4.0)
	assert_true(r["success"])


# -- OBSERVE_COURT_ATTENDEES (s55.7.3) -----------------------------------------

func test_observe_court_failure_roll_below_tn() -> void:
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(14, 5)
	assert_false(r["success"])
	assert_eq(r["learn_count"], 0)


func test_observe_court_success_base_one_attendee() -> void:
	# Exactly meets TN 15, no raises → 1 attendee.
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(15, 5)
	assert_true(r["success"])
	assert_eq(r["learn_count"], 1)


func test_observe_court_one_raise_two_attendees() -> void:
	# margin = 20 - 15 = 5 → 1 Raise → 2 attendees.
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(20, 5)
	assert_true(r["success"])
	assert_eq(r["learn_count"], 2)


func test_observe_court_two_raises_three_attendees() -> void:
	# margin = 25 - 15 = 10 → 2 Raises → 3 attendees.
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(25, 5)
	assert_true(r["success"])
	assert_eq(r["learn_count"], 3)


func test_observe_court_capped_at_three() -> void:
	# Very high roll → still capped at 3.
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(99, 10)
	assert_true(r["success"])
	assert_eq(r["learn_count"], 3)


func test_observe_court_capped_by_observable_pool() -> void:
	# Only 2 attendees available → cannot learn more than 2.
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(99, 2)
	assert_true(r["success"])
	assert_eq(r["learn_count"], 2)


func test_observe_court_empty_pool() -> void:
	# No unknown attendees → learn_count 0 even on success.
	var r: Dictionary = CourtActionSystem.resolve_observe_court_attendees(99, 0)
	assert_true(r["success"])
	assert_eq(r["learn_count"], 0)


# -- NPC metadata population: OBSERVE_COURT_ATTENDEES / ASK_FOR_INTRODUCTION ---

func _make_contact_ctx(char_id: int, court_attendees: Array, met: Array, disp: Dictionary = {}) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = char_id
	ctx.met_characters = met
	ctx.disposition_values = disp
	ctx.dispositions = disp.duplicate()
	ctx.active_court_at_location = {"attendee_ids": court_attendees}
	return ctx


func test_observe_metadata_filters_met_characters() -> void:
	# Attendees [2,3,4]; met=[3] → observable=[2,4]
	var ctx: NPCDataStructures.ContextSnapshot = _make_contact_ctx(1, [2,3,4], [3])
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "OBSERVE_COURT_ATTENDEES"
	var need := NPCDataStructures.ImmediateNeed.new()
	NPCDecisionEngine._populate_action_metadata(action, need, ctx)
	var obs: Array = action.metadata.get("observable_attendee_ids", [])
	assert_eq(obs.size(), 2)
	assert_true(3 not in obs)
	assert_true(2 in obs)
	assert_true(4 in obs)


func test_observe_metadata_excludes_self() -> void:
	# Self (char_id=1) is in attendee list but should be excluded.
	var ctx: NPCDataStructures.ContextSnapshot = _make_contact_ctx(1, [1,2,3], [])
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "OBSERVE_COURT_ATTENDEES"
	NPCDecisionEngine._populate_action_metadata(action, NPCDataStructures.ImmediateNeed.new(), ctx)
	var obs: Array = action.metadata.get("observable_attendee_ids", [])
	assert_true(1 not in obs)
	assert_eq(obs.size(), 2)


func test_observe_metadata_no_court_gives_empty_pool() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	# active_court_at_location is empty dict by default
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "OBSERVE_COURT_ATTENDEES"
	NPCDecisionEngine._populate_action_metadata(action, NPCDataStructures.ImmediateNeed.new(), ctx)
	assert_eq(action.metadata.get("observable_attendee_ids", []).size(), 0)


func test_ask_intro_metadata_picks_best_friend_intermediary() -> void:
	# Dispositions: 2=50 (Friend+), 3=20 (Acquaintance), 4=60 (best Friend+)
	# Target = 2 → intermediary must not be 2 → picks 4 (highest Friend+)
	var ctx: NPCDataStructures.ContextSnapshot = _make_contact_ctx(1, [], [], {2: 50, 3: 20, 4: 60})
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ASK_FOR_INTRODUCTION"
	action.target_npc_id = 2
	NPCDecisionEngine._populate_action_metadata(action, NPCDataStructures.ImmediateNeed.new(), ctx)
	assert_eq(action.metadata.get("intermediary_id", -1), 4)


func test_ask_intro_metadata_no_friend_gives_minus_one() -> void:
	# No one has Friend+ disposition → intermediary = -1
	var ctx: NPCDataStructures.ContextSnapshot = _make_contact_ctx(1, [], [], {2: 20, 3: 10})
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ASK_FOR_INTRODUCTION"
	action.target_npc_id = 5
	NPCDecisionEngine._populate_action_metadata(action, NPCDataStructures.ImmediateNeed.new(), ctx)
	assert_eq(action.metadata.get("intermediary_id", -1), -1)


func test_ask_intro_metadata_excludes_target_as_intermediary() -> void:
	# Only Friend+ is character 2, but 2 is also the target → no valid intermediary
	var ctx: NPCDataStructures.ContextSnapshot = _make_contact_ctx(1, [], [], {2: 70})
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ASK_FOR_INTRODUCTION"
	action.target_npc_id = 2
	NPCDecisionEngine._populate_action_metadata(action, NPCDataStructures.ImmediateNeed.new(), ctx)
	assert_eq(action.metadata.get("intermediary_id", -1), -1)
