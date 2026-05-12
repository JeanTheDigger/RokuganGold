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
	c.traits = {
		"Strength": 2, "Willpower": 3, "Stamina": 2, "Reflexes": 3,
		"Awareness": 3, "Intelligence": 3, "Agility": 2, "Perception": 3,
	}
	for k: String in traits:
		c.traits[k] = traits[k]
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
	assert_eq(r["disposition_change"], 9 + 3 * 3)


func test_negotiate_success_topic_position_shift() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(25, 15, 2, true, 0)
	assert_true(r["success"])
	assert_true(r.has("target_position_shift"))
	assert_eq(r["target_position_shift"], 5.0 + 2 * 2.0)


func test_negotiate_session_tn_reduction() -> void:
	var r: Dictionary = CourtActionSystem.resolve_negotiate(20, 15, 0, false, 0)
	assert_eq(r["session_tn_reduction"], 5)


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
	assert_eq(r["disposition_change"], 11)


func test_persuade_success_topic_durable() -> void:
	var r: Dictionary = CourtActionSystem.resolve_persuade(25, 15, 2, true)
	assert_true(r["success"])
	assert_true(r.get("position_durable", false))
	assert_eq(r["target_position_shift"], 8.0 + 2 * 4.0)


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
	assert_eq(r["disposition_change"], 8)


func test_charm_ceiling_caps_at_40() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 38, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], 2)


func test_charm_ceiling_already_at_cap() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 40, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], 0)
	assert_true(r.get("charm_ceiling_active", false))


func test_charm_diminishing_half() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 0, 2)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], 4)


func test_charm_diminishing_minimal() -> void:
	var r: Dictionary = CourtActionSystem.resolve_charm(20, 15, 0, 0, 3)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], 1)


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
	assert_eq(r["disposition_change"], 9 + 3)
	assert_eq(r["session_tn_reduction"], 5)


func test_impress_critical_failure() -> void:
	var r: Dictionary = CourtActionSystem.resolve_impress(5, 20, 0)
	assert_false(r["success"])
	assert_eq(r["disposition_change"], -6)


# -- Listen and Reflect -------------------------------------------------------

func test_listen_reflect_success() -> void:
	var r: Dictionary = CourtActionSystem.resolve_listen_reflect(20, 15, 0)
	assert_true(r["success"])
	assert_eq(r["disposition_change"], 11)
	assert_eq(r["persuade_negotiate_tn_reduction"], 5)


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
	var witnesses: Array[int] = [10, 11, 12]
	var r: Dictionary = CourtActionSystem.resolve_provoke_emotion(20, 15, witnesses)
	assert_true(r["success"])
	assert_eq(r["target_honor_change"], -0.2)
	assert_eq(r["target_glory_change"], -0.1)
	assert_eq(r["target_witness_disposition"], -3)
	assert_eq(r["witnesses"].size(), 3)


func test_provoke_emotion_failure() -> void:
	var witnesses: Array[int] = [10, 11]
	var r: Dictionary = CourtActionSystem.resolve_provoke_emotion(10, 15, witnesses)
	assert_false(r["success"])
	assert_false(r.has("target_honor_change"))


func test_provoke_emotion_critical_failure() -> void:
	var witnesses: Array[int] = [10, 11]
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
	assert_eq(r["info_count"], 2)


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
	ctx.season = "spring"
	ctx.context_flag = Enums.ContextFlag.AT_COURT
	ctx.dispositions = disp
	return ctx


func _build_skill_map() -> Dictionary:
	return ScoringTableLoader.load_action_skill_map()


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
		assert_le(
			result["effects"].get("disposition_change", 0),
			1,
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
	assert_ge(result["effects"]["a_disposition_toward_b"], 3)
	assert_ge(result["effects"]["b_disposition_toward_a"], 3)


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
