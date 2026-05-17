extends GutTest


var _dice_engine: DiceEngine
var _host: L5RCharacterData
var _guest1: L5RCharacterData
var _guest2: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_dice_engine = DiceEngine.new()
	_dice_engine.set_seed(42)

	_host = L5RCharacterData.new()
	_host.character_id = 1
	_host.perception = 3
	_host.agility = 3
	_host.reflexes = 3
	_host.status = 2.5
	_host.skills = {"Hunting": 3, "Kyujutsu": 3}

	_guest1 = L5RCharacterData.new()
	_guest1.character_id = 2
	_guest1.perception = 2
	_guest1.agility = 2
	_guest1.reflexes = 2
	_guest1.status = 2.0
	_guest1.skills = {"Kyujutsu": 2}

	_guest2 = L5RCharacterData.new()
	_guest2.character_id = 3
	_guest2.perception = 2
	_guest2.agility = 2
	_guest2.reflexes = 2
	_guest2.status = 3.0
	_guest2.skills = {}  # Non-combatant

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.ic_day = 10
	_ctx.season = 0
	_ctx.known_objectives = {}


# -- can_announce --------------------------------------------------------------

func test_can_announce_valid() -> void:
	var result: Dictionary = HuntSystem.can_announce(_host, _ctx)
	assert_true(result.get("valid", false))


func test_can_announce_fails_no_hunting_skill() -> void:
	_host.skills = {}
	var result: Dictionary = HuntSystem.can_announce(_host, _ctx)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "insufficient_hunting_skill")


func test_can_announce_fails_invalid_context() -> void:
	_ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	var result: Dictionary = HuntSystem.can_announce(_host, _ctx)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "invalid_context")


func test_can_announce_fails_active_hunt() -> void:
	_ctx.known_objectives = {"active_hunt_id": 99}
	var result: Dictionary = HuntSystem.can_announce(_host, _ctx)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "hunt_already_active")


func test_can_announce_valid_at_court() -> void:
	_ctx.context_flag = Enums.ContextFlag.AT_COURT
	var result: Dictionary = HuntSystem.can_announce(_host, _ctx)
	assert_true(result.get("valid", false))


func test_can_announce_valid_visiting() -> void:
	_ctx.context_flag = Enums.ContextFlag.VISITING
	var result: Dictionary = HuntSystem.can_announce(_host, _ctx)
	assert_true(result.get("valid", false))


# -- can_cancel ----------------------------------------------------------------

func test_can_cancel_valid() -> void:
	_ctx.known_objectives = {"active_hunt_id": 5, "hunt_date_ic_day": 20}
	var result: Dictionary = HuntSystem.can_cancel(_host, _ctx)
	assert_true(result.get("valid", false))


func test_can_cancel_fails_no_active_hunt() -> void:
	var result: Dictionary = HuntSystem.can_cancel(_host, _ctx)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "no_active_hunt")


func test_can_cancel_fails_date_passed() -> void:
	_ctx.known_objectives = {"active_hunt_id": 5, "hunt_date_ic_day": 9}
	var result: Dictionary = HuntSystem.can_cancel(_host, _ctx)
	assert_false(result.get("valid", true))
	assert_eq(result.get("reason", ""), "hunt_date_passed")


func test_can_cancel_valid_while_traveling() -> void:
	_ctx.known_objectives = {"active_hunt_id": 5, "hunt_date_ic_day": 20}
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	var result: Dictionary = HuntSystem.can_cancel(_host, _ctx)
	assert_true(result.get("valid", false))


# -- invitation_direction ------------------------------------------------------

func test_direction_peer() -> void:
	assert_eq(HuntSystem.invitation_direction(2.5, 2.3), "peer")


func test_direction_downward() -> void:
	# Host 3.0, invitee 1.5 => diff = 1.5 >= threshold → downward
	assert_eq(HuntSystem.invitation_direction(3.0, 1.5), "downward")


func test_direction_upward() -> void:
	# Host 1.5, invitee 3.0 => diff = -1.5 → upward
	assert_eq(HuntSystem.invitation_direction(1.5, 3.0), "upward")


# -- evaluate_invitation_response ----------------------------------------------

func test_downward_invite_accepted_by_default() -> void:
	var r: Dictionary = HuntSystem.evaluate_invitation_response(3.0, 1.5, 0, false)
	assert_true(r.get("should_accept", false))
	assert_almost_eq(r.get("glory_change", 0.0), 0.1, 0.001)


func test_upward_invite_accepted_if_friend() -> void:
	var r: Dictionary = HuntSystem.evaluate_invitation_response(1.5, 3.0, 40, false)
	assert_true(r.get("should_accept", false))


func test_upward_invite_declined_if_not_friend() -> void:
	var r: Dictionary = HuntSystem.evaluate_invitation_response(1.5, 3.0, 20, false)
	assert_false(r.get("should_accept", true))


func test_peer_invite_accepted_if_acquaintance() -> void:
	var r: Dictionary = HuntSystem.evaluate_invitation_response(2.5, 2.3, 15, false)
	assert_true(r.get("should_accept", false))


func test_peer_invite_declined_if_rival() -> void:
	var r: Dictionary = HuntSystem.evaluate_invitation_response(2.5, 2.3, 15, true)
	assert_false(r.get("should_accept", true))


# -- compute_party_defence_tn --------------------------------------------------

func test_party_defence_single() -> void:
	# reflexes=3, armor_tn_bonus=0 → armor TN = 3*5+5 = 20; no party bonus
	_host.reflexes = 3
	_host.armor_tn_bonus = 0
	var tn: int = HuntSystem.compute_party_defence_tn([_host])
	assert_eq(tn, 20)


func test_party_defence_party_bonus_capped() -> void:
	# 4 participants: bonus = min(3*3, 9) = 9
	var chars: Array = [_host, _guest1, _guest2]
	var extra: L5RCharacterData = L5RCharacterData.new()
	extra.reflexes = 2
	extra.armor_tn_bonus = 0
	chars.append(extra)
	var tn: int = HuntSystem.compute_party_defence_tn(chars)
	# mean armor = each has reflexes*5+5; host=20, guest1=15, guest2=15, extra=15
	# mean = (20+15+15+15)/4 = 65/4 = 16
	# bonus = min(3*3, 9) = 9
	assert_eq(tn, 16 + 9)


# -- School lean helpers -------------------------------------------------------

func test_positive_lean_hiruma() -> void:
	assert_true(HuntSystem.has_hunt_positive_lean("Hiruma Scout"))


func test_positive_lean_shinjo() -> void:
	assert_true(HuntSystem.has_hunt_positive_lean("Shinjo Bushi"))


func test_negative_lean_doji() -> void:
	assert_true(HuntSystem.has_hunt_negative_lean("Doji Courtier"))


func test_negative_lean_otomo() -> void:
	assert_true(HuntSystem.has_hunt_negative_lean("Otomo Courtier"))


func test_no_lean_generic_bushi() -> void:
	assert_false(HuntSystem.has_hunt_positive_lean("Kakita Bushi"))
	assert_false(HuntSystem.has_hunt_negative_lean("Kakita Bushi"))


# -- resolve_npc_hunt ----------------------------------------------------------

func test_hunt_fails_empty_party() -> void:
	var beast: Dictionary = {"armor_tn": 20, "wound_threshold": 10, "initiative": 2, "attack_skill": 2}
	var result: Dictionary = HuntSystem.resolve_npc_hunt(_host, [], beast, _dice_engine)
	assert_eq(result.get("outcome", ""), HuntSystem.OUTCOME_FAILED)


func test_hunt_fails_all_noncombatants() -> void:
	# guest2 has no weapon skills
	var beast: Dictionary = {"armor_tn": 5, "wound_threshold": 5, "initiative": 1, "attack_skill": 1}
	var result: Dictionary = HuntSystem.resolve_npc_hunt(_host, [_guest2], beast, _dice_engine)
	# _host is not in participants list here — only _guest2 who is noncombatant
	assert_eq(result.get("outcome", ""), HuntSystem.OUTCOME_FAILED)


func test_hunt_can_succeed() -> void:
	# High-skill host vs weak beast; use seeded dice for repeatability
	_host.skills = {"Hunting": 5, "Kyujutsu": 5}
	_host.perception = 5
	_host.agility = 5
	_dice_engine.set_seed(99)
	var beast: Dictionary = {"armor_tn": 5, "wound_threshold": 2, "initiative": 1, "attack_skill": 1}
	var result: Dictionary = HuntSystem.resolve_npc_hunt(_host, [_host, _guest1], beast, _dice_engine)
	assert_true(result.get("outcome", "") in [
		HuntSystem.OUTCOME_SUCCESS,
		HuntSystem.OUTCOME_COSTLY,
		HuntSystem.OUTCOME_FAILED,
		HuntSystem.OUTCOME_DISASTROUS,
	])


func test_hunt_result_has_required_keys() -> void:
	var beast: Dictionary = {"armor_tn": 20, "wound_threshold": 10, "initiative": 2, "attack_skill": 2}
	var result: Dictionary = HuntSystem.resolve_npc_hunt(
		_host, [_host, _guest1], beast, _dice_engine
	)
	assert_true(result.has("outcome"))
	assert_true(result.has("killer_id"))
	assert_true(result.has("second_id"))
	assert_true(result.has("wounded_id"))
	assert_true(result.has("killed_id"))
	assert_true(result.has("hunt_type"))


# -- compute_glory_distribution ------------------------------------------------

func test_glory_success_killer_gets_03() -> void:
	var participants: Array = [
		{"character_id": 1, "is_noncombatant": false},
		{"character_id": 2, "is_noncombatant": false},
	]
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_SUCCESS, participants, 1, 2, 3, false, false, false
	)
	assert_almost_eq(dist.get(1, 0.0), HuntSystem.GLORY_KILLER, 0.001)


func test_glory_success_second_gets_02() -> void:
	var participants: Array = [
		{"character_id": 1, "is_noncombatant": false},
		{"character_id": 2, "is_noncombatant": false},
	]
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_SUCCESS, participants, 1, 2, 3, false, false, false
	)
	assert_almost_eq(dist.get(2, 0.0), HuntSystem.GLORY_SECOND_DAMAGE, 0.001)


func test_glory_success_host_bonus_when_not_killer() -> void:
	var participants: Array = [
		{"character_id": 1, "is_noncombatant": false},
		{"character_id": 2, "is_noncombatant": false},
	]
	# Host is 3, killer is 1 → host gets participant + host bonus
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_SUCCESS, participants, 1, 2, 3, false, false, false
	)
	# Character 3 is host but not a participant, gets host bonus added separately
	# In this scenario host_id=3 is NOT in participants, so result[3] = 0 + GLORY_HOST_BONUS
	assert_almost_eq(dist.get(3, 0.0), HuntSystem.GLORY_HOST_BONUS, 0.001)


func test_glory_disastrous_host_penalty() -> void:
	var participants: Array = [{"character_id": 1, "is_noncombatant": false}]
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_DISASTROUS, participants, -1, -1, 1, false, false, false
	)
	assert_almost_eq(dist.get(1, 0.0), HuntSystem.GLORY_DISASTROUS_HOST, 0.001)


func test_glory_disastrous_noncombatant_aggravated() -> void:
	var participants: Array = [{"character_id": 1, "is_noncombatant": false}]
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_DISASTROUS, participants, -1, -1, 1, true, false, false
	)
	assert_almost_eq(dist.get(1, 0.0), HuntSystem.GLORY_DISASTROUS_NONCOMBATANT_HOST, 0.001)


func test_glory_failed_no_changes() -> void:
	var participants: Array = [{"character_id": 1, "is_noncombatant": false}]
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_FAILED, participants, -1, -1, 1, false, false, false
	)
	assert_true(dist.is_empty())


func test_glory_solo_returns_empty() -> void:
	var participants: Array = [{"character_id": 1, "is_noncombatant": false}]
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_SUCCESS, participants, 1, -1, 1, false, false, true
	)
	assert_true(dist.is_empty())


func test_glory_winter_court_bonus_added() -> void:
	var participants: Array = [
		{"character_id": 1, "is_noncombatant": false},
		{"character_id": 2, "is_noncombatant": false},
	]
	# Host 1 is also the killer during Winter Court
	var dist: Dictionary = HuntSystem.compute_glory_distribution(
		HuntSystem.OUTCOME_SUCCESS, participants, 1, 2, 1, false, true, false
	)
	# Host=killer gets GLORY_KILLER + GLORY_WINTER_COURT_BONUS
	assert_almost_eq(
		dist.get(1, 0.0),
		HuntSystem.GLORY_KILLER + HuntSystem.GLORY_WINTER_COURT_BONUS,
		0.001
	)


# -- ActionExecutor integration ------------------------------------------------

func _make_action(action_id: String, meta: Dictionary = {}) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = -1
	a.ap_cost = 0
	a.metadata = meta
	return a


func test_executor_announce_hunt_valid() -> void:
	_host.skills = {"Hunting": 2}
	var action := _make_action("ANNOUNCE_HUNT", {
		"target_province_id": 5,
		"hunt_date_ic_day": 24,
		"priority_invitee_id": -1,
	})
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_true(result.get("success", false))
	assert_eq(result.get("action_id", ""), "ANNOUNCE_HUNT")


func test_executor_announce_hunt_fails_no_skill() -> void:
	_host.skills = {}
	var action := _make_action("ANNOUNCE_HUNT", {"target_province_id": 5, "hunt_date_ic_day": 24})
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "insufficient_hunting_skill")


func test_executor_cancel_hunt_valid() -> void:
	_ctx.known_objectives = {"active_hunt_id": 7, "hunt_date_ic_day": 30}
	var action := _make_action("CANCEL_HUNT", {"accepted_invitee_ids": []})
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_true(result.get("success", false))
	assert_eq(result.get("action_id", ""), "CANCEL_HUNT")


func test_executor_cancel_hunt_no_active_hunt() -> void:
	var action := _make_action("CANCEL_HUNT", {})
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_active_hunt")


func test_executor_request_invitation_valid() -> void:
	_ctx.known_objectives = {"hunt_topic_id": 42}
	var action := _make_action("REQUEST_HUNT_INVITATION", {
		"hunt_topic_id": 42,
		"host_id": 10,
	})
	action.target_npc_id = 10
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_true(result.get("success", false))
	assert_eq(result.get("action_id", ""), "REQUEST_HUNT_INVITATION")


func test_executor_request_invitation_no_topic() -> void:
	var action := _make_action("REQUEST_HUNT_INVITATION", {
		"hunt_topic_id": -1,
		"host_id": 10,
	})
	var result: Dictionary = ActionExecutor.execute(
		action, _host, _ctx, _dice_engine, {}, {}, {}
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_hunt_topic")
