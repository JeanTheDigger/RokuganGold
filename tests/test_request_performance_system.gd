extends GutTest


var _lord: L5RCharacterData
var _performer: L5RCharacterData
var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_lord = L5RCharacterData.new()
	_lord.character_id = 1
	_lord.status = 6.0
	_lord.civilian_orders_remaining = 3
	_lord.skills = {}
	_lord.disposition_values = {}

	_performer = L5RCharacterData.new()
	_performer.character_id = 2
	_performer.skills = {"Perform: Biwa": 3}
	_performer.disposition_values = {1: 30}

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.character_id = 1
	_ctx.is_lord = true
	_ctx.civilian_orders_remaining = 3
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.ic_day = 10


func test_create_request_sets_expiry() -> void:
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 10
	)
	assert_eq(req["expires_ic_day"], 10 + RequestPerformanceSystem.EXPIRY_IC_DAYS)


func test_create_request_open_when_no_target() -> void:
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "song", -1, "public", 5
	)
	assert_eq(req["target_performer_id"], -1)


func test_can_request_requires_lord() -> void:
	_ctx.is_lord = false
	var result: Dictionary = RequestPerformanceSystem.can_request(
		_lord, _ctx, "biwa", []
	)
	assert_false(result["valid"])
	assert_eq(result["reason"], "not_a_lord")


func test_can_request_requires_orders() -> void:
	_lord.civilian_orders_remaining = 0
	_ctx.civilian_orders_remaining = 0
	var result: Dictionary = RequestPerformanceSystem.can_request(
		_lord, _ctx, "biwa", []
	)
	assert_false(result["valid"])
	assert_eq(result["reason"], "no_civilian_orders")


func test_can_request_requires_correct_context() -> void:
	_ctx.context_flag = Enums.ContextFlag.TRAVELING
	var result: Dictionary = RequestPerformanceSystem.can_request(
		_lord, _ctx, "biwa", []
	)
	assert_false(result["valid"])
	assert_eq(result["reason"], "wrong_context")


func test_can_request_rejects_duplicate_type() -> void:
	var existing: Array = [
		RequestPerformanceSystem.create_request(0, 1, "biwa", -1, "public", 5)
	]
	var result: Dictionary = RequestPerformanceSystem.can_request(
		_lord, _ctx, "biwa", existing
	)
	assert_false(result["valid"])
	assert_eq(result["reason"], "duplicate_performance_type")


func test_can_request_valid_case() -> void:
	var result: Dictionary = RequestPerformanceSystem.can_request(
		_lord, _ctx, "biwa", []
	)
	assert_true(result["valid"])


func test_score_acceptance_zero_for_wrong_performer() -> void:
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", 99, "public", 5
	)
	var score: int = RequestPerformanceSystem.score_acceptance(
		_performer, req, _lord, 0
	)
	assert_eq(score, 0)


func test_score_acceptance_friend_at_court() -> void:
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 5
	)
	var score: int = RequestPerformanceSystem.score_acceptance(
		_performer, req, _lord, 0
	)
	assert_gt(score, 0)


func test_score_acceptance_rival_penalty() -> void:
	_performer.disposition_values[1] = -20
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 5
	)
	var score_rival: int = RequestPerformanceSystem.score_acceptance(
		_performer, req, _lord, 0
	)
	_performer.disposition_values[1] = 30
	var score_friend: int = RequestPerformanceSystem.score_acceptance(
		_performer, req, _lord, 0
	)
	assert_lt(score_rival, score_friend)


func test_score_acceptance_distance_penalty() -> void:
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 5
	)
	var score_near: int = RequestPerformanceSystem.score_acceptance(
		_performer, req, _lord, 0
	)
	var score_far: int = RequestPerformanceSystem.score_acceptance(
		_performer, req, _lord, 3
	)
	assert_eq(score_near - score_far, 3 * RequestPerformanceSystem.TRAVEL_PENALTY_PER_PROVINCE)


func test_can_fulfill_true_when_has_skill() -> void:
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 5
	)
	assert_true(RequestPerformanceSystem.can_fulfill(_performer, req))


func test_can_fulfill_false_when_no_skill() -> void:
	_performer.skills = {}
	var req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 5
	)
	assert_false(RequestPerformanceSystem.can_fulfill(_performer, req))


func test_expire_requests_removes_old() -> void:
	var old_req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 1
	)
	var requests: Array = [old_req]
	var result: Array = RequestPerformanceSystem.expire_requests(requests, 200)
	assert_eq(result.size(), 0)


func test_expire_requests_keeps_valid() -> void:
	var fresh_req: Dictionary = RequestPerformanceSystem.create_request(
		0, 1, "biwa", -1, "public", 150
	)
	var requests: Array = [fresh_req]
	var result: Array = RequestPerformanceSystem.expire_requests(requests, 200)
	assert_eq(result.size(), 1)


func test_compute_patron_glory_public_success() -> void:
	var glory: float = RequestPerformanceSystem.compute_patron_glory(
		PerformativeArtsSystem.PerformanceOutcome.SUCCESS, "public", 1.0
	)
	assert_almost_eq(glory, 0.2, 0.0001)


func test_compute_patron_glory_private_success() -> void:
	var glory: float = RequestPerformanceSystem.compute_patron_glory(
		PerformativeArtsSystem.PerformanceOutcome.SUCCESS, "private", 1.0
	)
	assert_almost_eq(glory, 0.1, 0.0001)


func test_compute_patron_glory_critical_fail() -> void:
	var glory: float = RequestPerformanceSystem.compute_patron_glory(
		PerformativeArtsSystem.PerformanceOutcome.CRITICAL_FAILURE, "public", 1.0
	)
	assert_almost_eq(glory, -0.1, 0.0001)


func test_compute_patron_glory_fatigue_halved() -> void:
	var glory_full: float = RequestPerformanceSystem.compute_patron_glory(
		PerformativeArtsSystem.PerformanceOutcome.SUCCESS, "public", 1.0
	)
	var glory_half: float = RequestPerformanceSystem.compute_patron_glory(
		PerformativeArtsSystem.PerformanceOutcome.SUCCESS, "public", 0.5
	)
	assert_almost_eq(glory_half, glory_full * 0.5, 0.0001)


# -- Disposition threshold tests (s12.2 tier boundaries) ----------------------

func test_score_acceptance_strong_ally_threshold_at_51() -> void:
	_performer.disposition_values[1] = 51
	var req: Dictionary = RequestPerformanceSystem.create_request(0, 1, "song", -1, "public", 5)
	var score_at: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	_performer.disposition_values[1] = 50
	var score_below: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	assert_eq(score_at - score_below, RequestPerformanceSystem.DISP_STRONG_ALLY - RequestPerformanceSystem.DISP_FRIEND)


func test_score_acceptance_friend_threshold_at_31() -> void:
	_performer.disposition_values[1] = 31
	var req: Dictionary = RequestPerformanceSystem.create_request(0, 1, "song", -1, "public", 5)
	var score_at: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	_performer.disposition_values[1] = 30
	var score_below: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	assert_eq(score_at - score_below, RequestPerformanceSystem.DISP_FRIEND - RequestPerformanceSystem.DISP_ACQUAINTANCE)


func test_score_acceptance_acquaintance_threshold_at_11() -> void:
	_performer.disposition_values[1] = 11
	var req: Dictionary = RequestPerformanceSystem.create_request(0, 1, "song", -1, "public", 5)
	var score_at: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	_performer.disposition_values[1] = 10
	var score_below: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	assert_eq(score_at - score_below, RequestPerformanceSystem.DISP_ACQUAINTANCE - RequestPerformanceSystem.DISP_NEUTRAL)


func test_score_acceptance_rival_threshold_at_minus10() -> void:
	_performer.disposition_values[1] = -10
	var req: Dictionary = RequestPerformanceSystem.create_request(0, 1, "song", -1, "public", 5)
	var score_neutral: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	_performer.disposition_values[1] = -11
	var score_rival: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	assert_eq(score_neutral - score_rival, RequestPerformanceSystem.DISP_NEUTRAL - RequestPerformanceSystem.DISP_RIVAL)


func test_score_acceptance_no_rank3_bonus() -> void:
	_performer.skills = {"Perform: Song": 3}
	var req: Dictionary = RequestPerformanceSystem.create_request(0, 1, "song", -1, "public", 5)
	var score_rank3: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	_performer.skills = {"Perform: Song": 4}
	var score_rank4: int = RequestPerformanceSystem.score_acceptance(_performer, req, _lord, 0)
	# Rank 3 and 4 should be identical — no intermediate bonus between unranked and rank 5.
	assert_eq(score_rank3, score_rank4)


# -- Patron glory writeback (DayOrchestrator._process_patron_glory_writebacks) -

func test_patron_glory_writeback_applies_glory_on_success() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.glory = 3.0
	var chars_by_id: Dictionary = {10: lord}

	var court := CourtSessionData.new()
	court.court_id = 1
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	var req: Dictionary = RequestPerformanceSystem.create_request(5, 10, "song", -1, "public", 0)
	court.pending_performance_requests = [req]

	var results: Array = [{
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": 2,
		"effects": {
			"fulfills_request_id": 5,
			"requesting_lord_id": 10,
			"venue_mode": "public",
			"fatigue_multiplier": 1.0,
			"performance_outcome": PerformativeArtsSystem.PerformanceOutcome.SUCCESS,
		},
	}]

	DayOrchestrator._process_patron_glory_writebacks(results, [court], chars_by_id)
	assert_almost_eq(lord.glory, 3.0 + RequestPerformanceSystem.PATRON_GLORY_PUBLIC_SUCCESS, 0.001)


func test_patron_glory_writeback_removes_request_from_court() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.glory = 2.0
	var chars_by_id: Dictionary = {10: lord}

	var court := CourtSessionData.new()
	court.court_id = 1
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	var req: Dictionary = RequestPerformanceSystem.create_request(7, 10, "dance", -1, "public", 0)
	court.pending_performance_requests = [req]

	var results: Array = [{
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"effects": {
			"fulfills_request_id": 7,
			"requesting_lord_id": 10,
			"venue_mode": "public",
			"fatigue_multiplier": 1.0,
			"performance_outcome": PerformativeArtsSystem.PerformanceOutcome.SUCCESS,
		},
	}]

	DayOrchestrator._process_patron_glory_writebacks(results, [court], chars_by_id)
	assert_eq(court.pending_performance_requests.size(), 0)


func test_patron_glory_writeback_no_effect_without_matching_request() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.glory = 2.0
	var chars_by_id: Dictionary = {10: lord}
	var court := CourtSessionData.new()
	court.court_id = 1
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.pending_performance_requests = []

	var results: Array = [{
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"effects": {
			"fulfills_request_id": 99,
			"requesting_lord_id": 10,
			"venue_mode": "public",
			"fatigue_multiplier": 1.0,
			"performance_outcome": PerformativeArtsSystem.PerformanceOutcome.SUCCESS,
		},
	}]

	DayOrchestrator._process_patron_glory_writebacks(results, [court], chars_by_id)
	assert_almost_eq(lord.glory, 2.0, 0.001)


func test_patron_glory_writeback_skips_failed_performance() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.glory = 2.0
	var chars_by_id: Dictionary = {10: lord}
	var court := CourtSessionData.new()
	court.court_id = 1
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	var req: Dictionary = RequestPerformanceSystem.create_request(3, 10, "song", -1, "public", 0)
	court.pending_performance_requests = [req]

	var results: Array = [{
		"action_id": "PUBLIC_PERFORMANCE",
		"success": false,
		"effects": {
			"fulfills_request_id": 3,
			"requesting_lord_id": 10,
			"venue_mode": "public",
			"fatigue_multiplier": 1.0,
			"performance_outcome": PerformativeArtsSystem.PerformanceOutcome.FAILURE,
		},
	}]

	DayOrchestrator._process_patron_glory_writebacks(results, [court], chars_by_id)
	assert_almost_eq(lord.glory, 2.0, 0.001)
