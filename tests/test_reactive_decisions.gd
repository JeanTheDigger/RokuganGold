extends GutTest


func _make_character(
	id: int = 1,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.CHUGI,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Crane"
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	c.skills = {"Iaijutsu": 3, "Courtier": 4}
	return c


func _make_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.characters_present = []
	ctx.known_objectives = {}
	return ctx


# =============================================================================
# Duel Response
# =============================================================================

func test_yu_always_accepts_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.YU)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": true}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_DUEL")


func test_kyoryoku_always_accepts_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": true}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_DUEL")


func test_rival_disposition_accepts_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.disposition_values = {5: -20.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": true}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_DUEL")


func test_rival_boundary_disposition_accepts_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE)
	c.disposition_values = {5: -11.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": false}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_DUEL")


func test_meiyo_accepts_public_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.MEIYO)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": true}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_DUEL")


func test_bushido_virtue_accepts_public_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": true}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_DUEL")


func test_no_virtue_declines_duel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE)
	c.disposition_values = {5: 10.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": false}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_DUEL")


func test_decline_duel_includes_glory_loss() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE)
	c.disposition_values = {5: 10.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 5, "is_public": false}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["glory_loss"], -0.3)


# =============================================================================
# Proactive Duel Trigger
# =============================================================================

func test_duel_trigger_yu_always_issues() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.YU)
	c.skills = {"Iaijutsu": 1}
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_eq(result.get("action", ""), "ISSUE_DUEL_CHALLENGE")


func test_duel_trigger_jin_never_issues() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.JIN)
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_true(result.is_empty())


func test_duel_trigger_rei_never_issues() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.REI)
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_true(result.is_empty())


func test_duel_trigger_meiyo_only_public_insult() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.MEIYO)
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_eq(result.get("action", ""), "ISSUE_DUEL_CHALLENGE")


func test_duel_trigger_meiyo_ignores_non_public() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.MEIYO)
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "family_dishonored"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_true(result.is_empty())


func test_duel_trigger_low_iaijutsu_no_champion_fails() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.skills = {"Iaijutsu": 1}
	var ctx := _make_ctx()
	ctx.characters_present = []
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_true(result.is_empty())


func test_duel_trigger_champion_present_passes_capability() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.skills = {"Iaijutsu": 1}
	c.disposition_values = {10: 31.0}
	var ctx := _make_ctx()
	ctx.characters_present = [10]
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_eq(result.get("action", ""), "ISSUE_DUEL_CHALLENGE")


func test_duel_trigger_champion_acquaintance_not_enough() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.skills = {"Iaijutsu": 1}
	c.disposition_values = {10: 30.0}
	var ctx := _make_ctx()
	ctx.characters_present = [10]
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_true(result.is_empty())


func test_duel_trigger_dosatsu_needs_intel() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.DOSATSU)
	c.skills = {"Iaijutsu": 5}
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_true(result.is_empty())


func test_duel_trigger_dosatsu_with_intel_passes() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.DOSATSU)
	c.skills = {"Iaijutsu": 5}
	var entry := KnowledgeEntry.new()
	entry.entry_type = "skill_assessment"
	entry.data = {"target_id": 5}
	c.knowledge_pool.append(entry)
	var ctx := _make_ctx()
	var trigger: Dictionary = {"target_npc_id": 5, "trigger_type": "public_insult"}
	var result: Dictionary = ReactiveDecisions.evaluate_duel_trigger(c, trigger, ctx)
	assert_eq(result.get("action", ""), "ISSUE_DUEL_CHALLENGE")


# =============================================================================
# Favor Response
# =============================================================================

func test_chugi_always_honors_favor() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.CHUGI)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "FAVOR_REQUESTED", "requester_id": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "HONOR_FAVOR")


func test_makoto_always_honors_favor() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.MAKOTO)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "FAVOR_REQUESTED", "requester_id": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "HONOR_FAVOR")


func test_friend_disposition_honors_favor() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.disposition_values = {5: 31.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "FAVOR_REQUESTED", "requester_id": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "HONOR_FAVOR")


func test_acquaintance_disposition_declines_favor() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.disposition_values = {5: 30.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "FAVOR_REQUESTED", "requester_id": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_FAVOR")


func test_low_disposition_declines_favor() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.disposition_values = {5: -10.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "FAVOR_REQUESTED", "requester_id": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_FAVOR")


# =============================================================================
# Court Invitation
# =============================================================================

func test_high_prestige_court_accepted() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "COURT_INVITATION", "host_id": 5, "prestige": 4}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ATTEND_COURT")


func test_rei_always_attends_court() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.REI)
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "COURT_INVITATION", "host_id": 5, "prestige": 1}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ATTEND_COURT")


func test_ishi_declines_low_prestige() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI)
	c.disposition_values = {5: -5.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "COURT_INVITATION", "host_id": 5, "prestige": 2}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_INVITATION")


func test_good_disposition_accepts_low_prestige() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.GI)
	c.disposition_values = {5: 20.0}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "COURT_INVITATION", "host_id": 5, "prestige": 1}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ATTEND_COURT")


# =============================================================================
# Training Response
# =============================================================================

func test_accept_training_normal() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.CHUGI)
	c.skills = {"Kenjutsu": 2}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "ACCEPT_TRAINING", "sensei_id": 5, "skill": "Kenjutsu", "sensei_rank": 4}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_TRAINING")
	assert_eq(result["skill"], "Kenjutsu")


func test_decline_training_no_benefit() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.CHUGI)
	c.skills = {"Kenjutsu": 5}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "ACCEPT_TRAINING", "sensei_id": 5, "skill": "Kenjutsu", "sensei_rank": 4}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_TRAINING")
	assert_eq(result["reason"], "no_benefit")


func test_kanpeki_needs_2_rank_gap() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KANPEKI)
	c.skills = {"Kenjutsu": 3}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "ACCEPT_TRAINING", "sensei_id": 5, "skill": "Kenjutsu", "sensei_rank": 4}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_TRAINING")
	assert_eq(result["reason"], "perfectionist_gate")


func test_kanpeki_accepts_large_gap() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KANPEKI)
	c.skills = {"Kenjutsu": 3}
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "ACCEPT_TRAINING", "sensei_id": 5, "skill": "Kenjutsu", "sensei_rank": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_TRAINING")


func test_ketsui_declines_without_mentor_objective() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI)
	c.skills = {"Kenjutsu": 2}
	var ctx := _make_ctx()
	ctx.known_objectives = {}
	var event: Dictionary = {"reactive_type": "ACCEPT_TRAINING", "sensei_id": 5, "skill": "Kenjutsu", "sensei_rank": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "DECLINE_TRAINING")
	assert_eq(result["reason"], "self_reliance")


func test_ketsui_accepts_with_mentor_objective() -> void:
	var c := _make_character(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI)
	c.skills = {"Kenjutsu": 2}
	var ctx := _make_ctx()
	ctx.known_objectives = {"primary": {"objective_type": "MENTOR_CHARACTER", "target_npc_id": 5}}
	var event: Dictionary = {"reactive_type": "ACCEPT_TRAINING", "sensei_id": 5, "skill": "Kenjutsu", "sensei_rank": 5}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "ACCEPT_TRAINING")


# =============================================================================
# Unknown Event Type
# =============================================================================

func test_unknown_event_passes_through() -> void:
	var c := _make_character()
	var ctx := _make_ctx()
	var event: Dictionary = {"reactive_type": "UNKNOWN", "need_type": "REST"}
	var result: Dictionary = ReactiveDecisions.evaluate_reactive_event(event, c, ctx)
	assert_eq(result["action"], "PASS")
	assert_eq(result["need_type"], "REST")
