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
