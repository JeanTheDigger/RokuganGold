extends GutTest


func _make_ctx(status: float = 3.0) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.status = status
	return ctx


func _make_char(
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	return c


func _make_objective(overrides: Dictionary = {}) -> Dictionary:
	var obj: Dictionary = {
		"need_type": "RAISE_DISPOSITION",
		"travel_redirects": 0,
		"last_measured_progress": 0.0,
		"seasons_without_progress": 0,
		"lord_assigned": false,
	}
	obj.merge(overrides, true)
	return obj


# =============================================================================
# 55.29.1 — Travel Frustration Counter
# =============================================================================

func test_redirect_penalty_zero():
	assert_eq(TravelCommitment.get_redirect_penalty(0), 0)

func test_redirect_penalty_one():
	assert_eq(TravelCommitment.get_redirect_penalty(1), -5)

func test_redirect_penalty_two():
	assert_eq(TravelCommitment.get_redirect_penalty(2), -15)

func test_redirect_penalty_three():
	assert_eq(TravelCommitment.get_redirect_penalty(3), -30)

func test_redirect_penalty_clamps_at_three():
	assert_eq(TravelCommitment.get_redirect_penalty(5), -30)

func test_increment_redirects():
	var obj := _make_objective()
	TravelCommitment.increment_redirects(obj)
	assert_eq(obj["travel_redirects"], 1)
	TravelCommitment.increment_redirects(obj)
	assert_eq(obj["travel_redirects"], 2)

func test_reset_redirects():
	var obj := _make_objective({"travel_redirects": 3})
	TravelCommitment.reset_redirects(obj)
	assert_eq(obj["travel_redirects"], 0)

func test_should_reset_at_court():
	assert_true(TravelCommitment.should_reset_redirects(Enums.ContextFlag.AT_COURT))

func test_should_reset_at_own_holdings():
	assert_true(TravelCommitment.should_reset_redirects(Enums.ContextFlag.AT_OWN_HOLDINGS))

func test_should_reset_visiting():
	assert_true(TravelCommitment.should_reset_redirects(Enums.ContextFlag.VISITING))

func test_should_reset_on_campaign():
	assert_true(TravelCommitment.should_reset_redirects(Enums.ContextFlag.ON_CAMPAIGN))

func test_should_not_reset_while_traveling():
	assert_false(TravelCommitment.should_reset_redirects(Enums.ContextFlag.TRAVELING))

func test_should_not_reset_under_siege():
	assert_false(TravelCommitment.should_reset_redirects(Enums.ContextFlag.UNDER_SIEGE))


# =============================================================================
# 55.29.2 — Sublocation Access
# =============================================================================

func test_public_always_accessible():
	var ctx := _make_ctx(0.0)
	assert_true(TravelCommitment.can_access_sublocation(ctx, Enums.Sublocation.PUBLIC))

func test_court_accessible_with_invitation():
	var ctx := _make_ctx(0.0)
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.COURT, 5.0, false, true
	))

func test_court_accessible_with_status():
	var ctx := _make_ctx(5.0)
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.COURT, 3.0
	))

func test_court_accessible_during_open_session():
	var ctx := _make_ctx(0.0)
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.COURT, 5.0, true
	))

func test_court_denied_without_status_or_invitation():
	var ctx := _make_ctx(2.0)
	assert_false(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.COURT, 5.0
	))

func test_private_accessible_household():
	var ctx := _make_ctx()
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.PRIVATE, 3.0, false, false, true
	))

func test_private_accessible_guest():
	var ctx := _make_ctx()
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.PRIVATE, 3.0, false, false, false, true
	))

func test_private_denied_no_status():
	var ctx := _make_ctx(10.0)
	assert_false(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.PRIVATE
	))

func test_restricted_accessible_with_role():
	var ctx := _make_ctx()
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.RESTRICTED, 3.0, false, false, false, false, true
	))

func test_restricted_accessible_with_flags():
	var ctx := _make_ctx()
	assert_true(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.RESTRICTED, 3.0, false, false, false, false, false, true
	))

func test_restricted_denied_no_role():
	var ctx := _make_ctx(10.0)
	assert_false(TravelCommitment.can_access_sublocation(
		ctx, Enums.Sublocation.RESTRICTED
	))


# -- Denial Reasons ------------------------------------------------------------

func test_denial_reason_court_insufficient_status():
	var ctx := _make_ctx(1.0)
	var reason: Enums.AccessDenialReason = TravelCommitment.get_denial_reason(
		Enums.Sublocation.COURT, ctx, 5.0
	)
	assert_eq(reason, Enums.AccessDenialReason.INSUFFICIENT_STATUS)

func test_denial_reason_private_not_household():
	var ctx := _make_ctx()
	var reason: Enums.AccessDenialReason = TravelCommitment.get_denial_reason(
		Enums.Sublocation.PRIVATE, ctx
	)
	assert_eq(reason, Enums.AccessDenialReason.NO_INVITATION)

func test_denial_reason_restricted():
	var ctx := _make_ctx()
	var reason: Enums.AccessDenialReason = TravelCommitment.get_denial_reason(
		Enums.Sublocation.RESTRICTED, ctx
	)
	assert_eq(reason, Enums.AccessDenialReason.RESTRICTED_ROLE)


# -- Fallback Actions ----------------------------------------------------------

func test_fallback_actions_status():
	var actions: Array = TravelCommitment.get_fallback_actions(
		Enums.AccessDenialReason.INSUFFICIENT_STATUS
	)
	assert_true("SEND_LETTER" in actions)
	assert_true("ACQUIRE_LEVERAGE" in actions)

func test_fallback_actions_no_invitation():
	var actions: Array = TravelCommitment.get_fallback_actions(
		Enums.AccessDenialReason.NO_INVITATION
	)
	assert_true("RAISE_DISPOSITION" in actions)

func test_fallback_actions_restricted():
	var actions: Array = TravelCommitment.get_fallback_actions(
		Enums.AccessDenialReason.RESTRICTED_ROLE
	)
	assert_true("REASSESS_OBJECTIVE" in actions)


# =============================================================================
# 55.29.3 — Stall Detection
# =============================================================================

# -- Personality Thresholds ----------------------------------------------------

func test_stall_threshold_yu_five():
	var c := _make_char(Enums.BushidoVirtue.YU)
	assert_eq(TravelCommitment.get_stall_threshold(c), 5)

func test_stall_threshold_jin_two():
	var c := _make_char(Enums.BushidoVirtue.JIN)
	assert_eq(TravelCommitment.get_stall_threshold(c), 2)

func test_stall_threshold_gi_two():
	var c := _make_char(Enums.BushidoVirtue.GI)
	assert_eq(TravelCommitment.get_stall_threshold(c), 2)

func test_stall_threshold_ketsui_five():
	var c := _make_char(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI)
	assert_eq(TravelCommitment.get_stall_threshold(c), 5)

func test_stall_threshold_dosatsu_three():
	var c := _make_char(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.DOSATSU)
	assert_eq(TravelCommitment.get_stall_threshold(c), 3)

func test_stall_threshold_default_three():
	var c := _make_char()
	assert_eq(TravelCommitment.get_stall_threshold(c), 3)

func test_shourido_takes_precedence():
	var c := _make_char(Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.DOSATSU)
	assert_eq(TravelCommitment.get_stall_threshold(c), 3)


# -- Progress Tracking ---------------------------------------------------------

func test_update_progress_resets_stall_on_gain():
	var obj := _make_objective({"last_measured_progress": 0.2, "seasons_without_progress": 2})
	TravelCommitment.update_progress(obj, 0.4)
	assert_eq(obj["seasons_without_progress"], 0)
	assert_almost_eq(obj["last_measured_progress"], 0.4, 0.001)

func test_update_progress_increments_stall_on_plateau():
	var obj := _make_objective({"last_measured_progress": 0.5, "seasons_without_progress": 1})
	TravelCommitment.update_progress(obj, 0.5)
	assert_eq(obj["seasons_without_progress"], 2)

func test_update_progress_increments_on_regression():
	var obj := _make_objective({"last_measured_progress": 0.5, "seasons_without_progress": 0})
	TravelCommitment.update_progress(obj, 0.3)
	assert_eq(obj["seasons_without_progress"], 1)

func test_update_progress_ignores_tiny_gain():
	var obj := _make_objective({"last_measured_progress": 0.5, "seasons_without_progress": 1})
	TravelCommitment.update_progress(obj, 0.5005)
	assert_eq(obj["seasons_without_progress"], 2)


# -- Stall Check ---------------------------------------------------------------

func test_is_stalled_below_threshold():
	var c := _make_char()  # threshold = 3
	var obj := _make_objective({"seasons_without_progress": 2})
	assert_false(TravelCommitment.is_stalled(obj, c))

func test_is_stalled_at_threshold():
	var c := _make_char()  # threshold = 3
	var obj := _make_objective({"seasons_without_progress": 3})
	assert_true(TravelCommitment.is_stalled(obj, c))

func test_is_stalled_above_threshold():
	var c := _make_char()  # threshold = 3
	var obj := _make_objective({"seasons_without_progress": 5})
	assert_true(TravelCommitment.is_stalled(obj, c))

func test_yu_not_stalled_at_three():
	var c := _make_char(Enums.BushidoVirtue.YU)  # threshold = 5
	var obj := _make_objective({"seasons_without_progress": 3})
	assert_false(TravelCommitment.is_stalled(obj, c))

func test_jin_stalled_at_two():
	var c := _make_char(Enums.BushidoVirtue.JIN)  # threshold = 2
	var obj := _make_objective({"seasons_without_progress": 2})
	assert_true(TravelCommitment.is_stalled(obj, c))

func test_chugi_lord_assigned_never_stalls():
	var c := _make_char(Enums.BushidoVirtue.CHUGI)
	var obj := _make_objective({"seasons_without_progress": 10, "lord_assigned": true})
	assert_false(TravelCommitment.is_stalled(obj, c))

func test_chugi_self_selected_can_stall():
	var c := _make_char(Enums.BushidoVirtue.CHUGI)  # threshold = 3
	var obj := _make_objective({"seasons_without_progress": 3, "lord_assigned": false})
	assert_true(TravelCommitment.is_stalled(obj, c))


# -- REASSESS_OBJECTIVE Need ---------------------------------------------------

func test_make_reassess_need():
	var obj := _make_objective({"need_type": "RAISE_DISPOSITION"})
	var need: NPCDataStructures.ImmediateNeed = TravelCommitment.make_reassess_need(obj)
	assert_eq(need.need_type, "REASSESS_OBJECTIVE")
	assert_eq(need.source, "stall_detection")
	assert_eq(need.target_intent, "RAISE_DISPOSITION")
