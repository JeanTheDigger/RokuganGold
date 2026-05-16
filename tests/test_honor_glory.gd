extends GutTest


var _char: L5RCharacterData


func before_each() -> void:
	_char = L5RCharacterData.new()


# -- Honor changes -------------------------------------------------------------

func test_honor_change_applies() -> void:
	_char.honor = 5.0
	HonorGlorySystem.apply_honor_change(_char, 0.3)
	assert_almost_eq(_char.honor, 5.3, 0.001)


func test_honor_clamps_at_ten() -> void:
	_char.honor = 9.8
	HonorGlorySystem.apply_honor_change(_char, 0.5)
	assert_almost_eq(_char.honor, 10.0, 0.001)


func test_honor_clamps_at_zero() -> void:
	_char.honor = 0.3
	HonorGlorySystem.apply_honor_change(_char, -1.0)
	assert_almost_eq(_char.honor, 0.0, 0.001)


func test_honor_change_returns_actual_delta() -> void:
	_char.honor = 9.8
	var actual: float = HonorGlorySystem.apply_honor_change(_char, 0.5)
	assert_almost_eq(actual, 0.2, 0.001)


# -- Glory changes -------------------------------------------------------------

func test_glory_change_applies() -> void:
	_char.glory = 2.0
	HonorGlorySystem.apply_glory_change(_char, 0.5)
	assert_almost_eq(_char.glory, 2.5, 0.001)


func test_glory_clamps_at_ten() -> void:
	_char.glory = 10.0
	HonorGlorySystem.apply_glory_change(_char, 1.0)
	assert_almost_eq(_char.glory, 10.0, 0.001)


# -- Status changes ------------------------------------------------------------

func test_status_change_applies() -> void:
	_char.status = 3.0
	HonorGlorySystem.apply_status_change(_char, -0.5)
	assert_almost_eq(_char.status, 2.5, 0.001)


# -- Infamy changes ------------------------------------------------------------

func test_infamy_change_applies() -> void:
	_char.infamy = 0.0
	HonorGlorySystem.apply_infamy_change(_char, 1.5)
	assert_almost_eq(_char.infamy, 1.5, 0.001)


# -- Rank calculations ---------------------------------------------------------

func test_honor_rank() -> void:
	_char.honor = 6.7
	assert_eq(HonorGlorySystem.get_honor_rank(_char), 6)


func test_honor_rank_floor() -> void:
	_char.honor = 2.9
	assert_eq(HonorGlorySystem.get_honor_rank(_char), 2)


func test_glory_rank() -> void:
	_char.glory = 4.1
	assert_eq(HonorGlorySystem.get_glory_rank(_char), 4)


# -- Court honor modifier (Free Raises / additional Raises) --------------------

func test_court_modifier_honor_rank_7_plus() -> void:
	_char.honor = 7.5
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), 2)


func test_court_modifier_honor_rank_5_6() -> void:
	_char.honor = 5.0
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), 1)

	_char.honor = 6.9
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), 1)


func test_court_modifier_honor_rank_3_4() -> void:
	_char.honor = 3.0
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), 0)

	_char.honor = 4.9
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), 0)


func test_court_modifier_honor_rank_2() -> void:
	_char.honor = 2.5
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), -1)


func test_court_modifier_honor_rank_1_or_below() -> void:
	_char.honor = 1.5
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), -2)

	_char.honor = 0.5
	assert_eq(HonorGlorySystem.get_court_honor_modifier(_char), -2)


# -- Recognition ---------------------------------------------------------------

func test_recognition_combines_glory_and_infamy() -> void:
	_char.glory = 3.5
	_char.infamy = 2.2
	assert_eq(HonorGlorySystem.get_recognition_rank(_char), 5)


# -- Event table constants exist -----------------------------------------------

func test_event_table_constants_defined() -> void:
	assert_eq(HonorGlorySystem.GLORY_PUBLIC_PERFORMANCE_SUCCESS, 0.3)
	assert_eq(HonorGlorySystem.HONOR_RENEGE_DECLARATION, -1.0)
	assert_eq(HonorGlorySystem.ATONEMENT_HONOR_BY_TIER[1], 1.0)
	assert_eq(HonorGlorySystem.ATONEMENT_TN_BY_TIER[4], 15)


# -- Court Honor Modifier Wiring (s4.6 into action_executor) -------------------

func _make_action(action_id: String, target_id: int = 0) -> NPCDataStructures.ScoredAction:
	var a: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = target_id
	a.metadata = {}
	return a


func _make_ctx(target_disp: int = 0) -> NPCDataStructures.ContextSnapshot:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.dispositions = {0: target_disp}
	return ctx


func test_social_tn_public_declaration_honor_7_lowers_tn() -> void:
	_char.honor = 7.5
	var action: NPCDataStructures.ScoredAction = _make_action("PUBLIC_DECLARATION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(0)
	var tn: int = ActionExecutor._get_social_tn(action, ctx, _char)
	var base_tn: int = ActionExecutor._get_social_tn(action, ctx, null)
	assert_eq(base_tn - tn, 10)


func test_social_tn_public_declaration_honor_1_raises_tn() -> void:
	_char.honor = 1.0
	var action: NPCDataStructures.ScoredAction = _make_action("PUBLIC_DECLARATION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(0)
	var tn: int = ActionExecutor._get_social_tn(action, ctx, _char)
	var base_tn: int = ActionExecutor._get_social_tn(action, ctx, null)
	assert_eq(tn - base_tn, 10)


func test_social_tn_charm_unaffected_by_honor() -> void:
	_char.honor = 7.5
	var action: NPCDataStructures.ScoredAction = _make_action("CHARM")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(0)
	var tn_with: int = ActionExecutor._get_social_tn(action, ctx, _char)
	var tn_without: int = ActionExecutor._get_social_tn(action, ctx, null)
	assert_eq(tn_with, tn_without)


func test_social_tn_honor_3_no_modifier() -> void:
	_char.honor = 3.5
	var action: NPCDataStructures.ScoredAction = _make_action("PUBLIC_DECLARATION")
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx(0)
	var tn: int = ActionExecutor._get_social_tn(action, ctx, _char)
	var base_tn: int = ActionExecutor._get_social_tn(action, ctx, null)
	assert_eq(tn, base_tn)
