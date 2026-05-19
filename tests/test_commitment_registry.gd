extends GutTest


func _make_char(id: int, virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.honor = 5.0
	c.bushido_virtue = virtue
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.disposition_values = {}
	return c


func _make_char_shourido(id: int, virtue: Enums.ShouridoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.honor = 5.0
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = virtue
	c.disposition_values = {}
	return c


func _make_commitment(overrides: Dictionary = {}) -> CommitmentData:
	var c := CommitmentData.new()
	c.commitment_id = overrides.get("id", 1)
	c.commitment_type = overrides.get("type", Enums.CommitmentType.COURT_ATTENDANCE)
	c.creditor_npc_id = overrides.get("creditor", 2)
	c.debtor_npc_id = overrides.get("debtor", 1)
	c.deadline_ic_day = overrides.get("deadline", 10)
	c.tier = overrides.get("tier", 3)
	c.created_ic_day = overrides.get("created", 1)
	c.witnesses = overrides.get("witnesses", [])
	c.status = overrides.get("status", Enums.CommitmentStatus.PENDING)
	return c


# =============================================================================
# Creation
# =============================================================================

func test_create_commitment_fields():
	var c: CommitmentData = CommitmentRegistry.create_commitment(
		42, Enums.CommitmentType.VISIT_PROMISE,
		2, 1, 30, 2, 5, "SEND_LETTER", 100, [2, 1]
	)
	assert_eq(c.commitment_id, 42)
	assert_eq(c.commitment_type, Enums.CommitmentType.VISIT_PROMISE)
	assert_eq(c.creditor_npc_id, 2)
	assert_eq(c.debtor_npc_id, 1)
	assert_eq(c.deadline_ic_day, 30)
	assert_eq(c.tier, 2)
	assert_eq(c.fulfillment_target, 100)
	assert_eq(c.witnesses.size(), 2)

func test_create_clamps_tier():
	var c: CommitmentData = CommitmentRegistry.create_commitment(
		1, Enums.CommitmentType.COURT_ATTENDANCE, 2, 1, 10, 5, 1
	)
	assert_eq(c.tier, 3)


# =============================================================================
# Registry Queries
# =============================================================================

func test_get_pending_filters_by_debtor():
	var all: Array[CommitmentData] = [
		_make_commitment({"debtor": 1}),
		_make_commitment({"debtor": 2}),
	]
	var pending: Array[CommitmentData] = CommitmentRegistry.get_pending(all, 1)
	assert_eq(pending.size(), 1)

func test_get_pending_excludes_fulfilled():
	var all: Array[CommitmentData] = [
		_make_commitment({"debtor": 1, "status": Enums.CommitmentStatus.FULFILLED}),
		_make_commitment({"debtor": 1, "id": 2}),
	]
	var pending: Array[CommitmentData] = CommitmentRegistry.get_pending(all, 1)
	assert_eq(pending.size(), 1)

func test_get_by_crisis():
	var c1 := _make_commitment({"id": 1})
	c1.crisis_id = 99
	var c2 := _make_commitment({"id": 2})
	var all: Array[CommitmentData] = [c1, c2]
	assert_eq(CommitmentRegistry.get_by_crisis(all, 99).size(), 1)


# =============================================================================
# Proactive Management
# =============================================================================

func test_advance_notice_before_deadline():
	var c := _make_commitment({"deadline": 10})
	assert_true(CommitmentRegistry.send_advance_notice(c, 8))
	assert_true(c.advance_notice_sent)
	assert_eq(c.notice_ic_day, 8)

func test_advance_notice_at_deadline_fails():
	var c := _make_commitment({"deadline": 10})
	assert_false(CommitmentRegistry.send_advance_notice(c, 10))
	assert_false(c.advance_notice_sent)

func test_advance_notice_already_fulfilled_fails():
	var c := _make_commitment({"status": Enums.CommitmentStatus.FULFILLED})
	assert_false(CommitmentRegistry.send_advance_notice(c, 5))

func test_register_proxy_succeeds():
	var c := _make_commitment()
	assert_true(CommitmentRegistry.register_proxy(c))
	assert_true(c.proxy_sent)

func test_register_proxy_support_pledge_fails():
	var c := _make_commitment({"type": Enums.CommitmentType.SUPPORT_PLEDGE})
	assert_false(CommitmentRegistry.register_proxy(c))
	assert_false(c.proxy_sent)


# =============================================================================
# Deadline Check
# =============================================================================

func test_fulfilled_status():
	var c := _make_commitment()
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, true)
	assert_eq(status, Enums.CommitmentStatus.FULFILLED)

func test_broken_no_notice():
	var c := _make_commitment()
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, false)
	assert_eq(status, Enums.CommitmentStatus.BROKEN_NO_NOTICE)

func test_broken_with_notice():
	var c := _make_commitment()
	c.advance_notice_sent = true
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, false)
	assert_eq(status, Enums.CommitmentStatus.BROKEN_WITH_NOTICE)

func test_broken_with_proxy():
	var c := _make_commitment()
	c.proxy_sent = true
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, false)
	assert_eq(status, Enums.CommitmentStatus.BROKEN_WITH_PROXY)

func test_support_pledge_proxy_treated_as_notice():
	var c := _make_commitment({"type": Enums.CommitmentType.SUPPORT_PLEDGE})
	c.proxy_sent = true
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, false)
	assert_eq(status, Enums.CommitmentStatus.BROKEN_WITH_NOTICE)

func test_force_majeure_overrides_notice():
	var c := _make_commitment()
	c.advance_notice_sent = true
	c.crisis_id = 42
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, false)
	assert_eq(status, Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE)

func test_already_resolved_not_rechecked():
	var c := _make_commitment({"status": Enums.CommitmentStatus.FULFILLED})
	var status: Enums.CommitmentStatus = CommitmentRegistry.check_deadline(c, false)
	assert_eq(status, Enums.CommitmentStatus.FULFILLED)


# =============================================================================
# Consequences — No Notice
# =============================================================================

func test_no_notice_tier3_honor():
	var c := _make_commitment({"tier": 3})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], -0.1, 0.001)

func test_no_notice_tier2_creditor_disp():
	var c := _make_commitment({"tier": 2})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_eq(conseq["creditor_disp"], -6)

func test_no_notice_tier2_witness_disp():
	var c := _make_commitment({"tier": 2})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_eq(conseq["witness_disp"], -2)

func test_no_notice_tier1_all():
	var c := _make_commitment({"tier": 1})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], -0.5, 0.001)
	assert_eq(conseq["creditor_disp"], -10)
	assert_eq(conseq["witness_disp"], -5)
	assert_eq(conseq["topic_tier"], 2)


# =============================================================================
# Consequences — With Notice
# =============================================================================

func test_with_notice_tier3_no_honor_loss():
	var c := _make_commitment({"tier": 3})
	c.status = Enums.CommitmentStatus.BROKEN_WITH_NOTICE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], 0.0, 0.001)

func test_with_notice_tier3_small_disp():
	var c := _make_commitment({"tier": 3})
	c.status = Enums.CommitmentStatus.BROKEN_WITH_NOTICE
	assert_eq(CommitmentRegistry.get_consequences(c)["creditor_disp"], -1)

func test_with_notice_tier2_honor():
	var c := _make_commitment({"tier": 2})
	c.status = Enums.CommitmentStatus.BROKEN_WITH_NOTICE
	assert_almost_eq(CommitmentRegistry.get_consequences(c)["honor"], -0.1, 0.001)


# =============================================================================
# Consequences — With Proxy
# =============================================================================

func test_proxy_tier3_no_penalty():
	var c := _make_commitment({"tier": 3})
	c.status = Enums.CommitmentStatus.BROKEN_WITH_PROXY
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], 0.0, 0.001)
	assert_eq(conseq["creditor_disp"], 0)

func test_proxy_tier1_minimal():
	var c := _make_commitment({"tier": 1})
	c.status = Enums.CommitmentStatus.BROKEN_WITH_PROXY
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], -0.1, 0.001)
	assert_eq(conseq["creditor_disp"], -2)


# =============================================================================
# Consequences — Force Majeure
# =============================================================================

func test_force_majeure_matches_notice():
	var c := _make_commitment({"tier": 2})
	c.status = Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], -0.1, 0.001)
	assert_eq(conseq["creditor_disp"], -3)
	assert_eq(conseq["witness_disp"], 0)


# =============================================================================
# Favor Obligation Exemption
# =============================================================================

func test_favor_obligation_no_consequences():
	var c := _make_commitment({"type": Enums.CommitmentType.FAVOR_OBLIGATION, "tier": 1})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var conseq: Dictionary = CommitmentRegistry.get_consequences(c)
	assert_almost_eq(conseq["honor"], 0.0, 0.001)
	assert_eq(conseq["creditor_disp"], 0)


# =============================================================================
# Apply Consequences
# =============================================================================

func test_apply_consequences_honor_change():
	var debtor := _make_char(1)
	var creditor := _make_char(2)
	var chars: Dictionary = {1: debtor, 2: creditor}
	var c := _make_commitment({"tier": 2, "creditor": 2, "debtor": 1})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var result: Dictionary = CommitmentRegistry.apply_consequences(c, debtor, chars)
	assert_almost_eq(debtor.honor, 4.8, 0.001)
	assert_almost_eq(result["honor_change"], -0.2, 0.001)

func test_apply_consequences_creditor_disposition():
	var debtor := _make_char(1)
	var creditor := _make_char(2)
	creditor.disposition_values[1] = 20
	var chars: Dictionary = {1: debtor, 2: creditor}
	var c := _make_commitment({"tier": 3, "creditor": 2, "debtor": 1})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	CommitmentRegistry.apply_consequences(c, debtor, chars)
	assert_eq(creditor.disposition_values[1], 17)

func test_apply_consequences_witness_disposition():
	var debtor := _make_char(1)
	var creditor := _make_char(2)
	var witness := _make_char(3)
	witness.disposition_values[1] = 10
	var chars: Dictionary = {1: debtor, 2: creditor, 3: witness}
	var c := _make_commitment({
		"tier": 2, "creditor": 2, "debtor": 1,
		"witnesses": [2, 3],
	})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	CommitmentRegistry.apply_consequences(c, debtor, chars)
	assert_eq(witness.disposition_values[1], 8)

func test_apply_consequences_skips_debtor_witness():
	var debtor := _make_char(1)
	debtor.disposition_values[1] = 50
	var creditor := _make_char(2)
	var chars: Dictionary = {1: debtor, 2: creditor}
	var c := _make_commitment({
		"tier": 2, "creditor": 2, "debtor": 1,
		"witnesses": [1, 2],
	})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	var result: Dictionary = CommitmentRegistry.apply_consequences(c, debtor, chars)
	assert_eq(debtor.disposition_values[1], 50)
	assert_eq(result["disposition_changes"].size(), 1)


# =============================================================================
# Crisis Linking
# =============================================================================

func test_link_crisis_stamps_pending():
	var all: Array[CommitmentData] = [
		_make_commitment({"id": 1, "debtor": 1}),
		_make_commitment({"id": 2, "debtor": 1}),
		_make_commitment({"id": 3, "debtor": 2}),
	]
	var linked: int = CommitmentRegistry.link_crisis(all, 1, 99)
	assert_eq(linked, 2)
	assert_eq(all[0].crisis_id, 99)
	assert_eq(all[1].crisis_id, 99)
	assert_eq(all[2].crisis_id, -1)

func test_link_crisis_skips_fulfilled():
	var c := _make_commitment({"debtor": 1, "status": Enums.CommitmentStatus.FULFILLED})
	var all: Array[CommitmentData] = [c]
	assert_eq(CommitmentRegistry.link_crisis(all, 1, 99), 0)


# =============================================================================
# Forgiveness Rates
# =============================================================================

func test_jin_full_forgiveness():
	var c := _make_char(1, Enums.BushidoVirtue.JIN)
	assert_almost_eq(CommitmentRegistry.get_forgiveness_rate(c), 1.0, 0.001)

func test_gi_forgiveness():
	var c := _make_char(1, Enums.BushidoVirtue.GI)
	assert_almost_eq(CommitmentRegistry.get_forgiveness_rate(c), 0.75, 0.001)

func test_chugi_same_chain():
	var c := _make_char(1, Enums.BushidoVirtue.CHUGI)
	assert_almost_eq(CommitmentRegistry.get_forgiveness_rate(c, true), 0.75, 0.001)

func test_chugi_external():
	var c := _make_char(1, Enums.BushidoVirtue.CHUGI)
	assert_almost_eq(CommitmentRegistry.get_forgiveness_rate(c, false), 0.25, 0.001)

func test_seigyo_low_forgiveness():
	var c := _make_char_shourido(1, Enums.ShouridoVirtue.SEIGYO)
	assert_almost_eq(CommitmentRegistry.get_forgiveness_rate(c), 0.25, 0.001)

func test_default_forgiveness():
	var c := _make_char(1)
	assert_almost_eq(CommitmentRegistry.get_forgiveness_rate(c), 0.5, 0.001)


# =============================================================================
# Apply Forgiveness
# =============================================================================

func test_forgiveness_recovers_disposition():
	var debtor := _make_char(1)
	var creditor := _make_char(2, Enums.BushidoVirtue.JIN)
	creditor.disposition_values[1] = -6
	var c := _make_commitment({"tier": 2, "creditor": 2, "debtor": 1})
	c.status = Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE
	c.penalty_records = [{"npc_id": 2, "disposition_change": -6, "forgiveness_applied": false}]
	var recovery: float = CommitmentRegistry.apply_forgiveness(c, creditor, 1)
	assert_almost_eq(recovery, 6.0, 0.001)
	assert_eq(creditor.disposition_values[1], 0)

func test_forgiveness_partial_for_rei():
	var creditor := _make_char(2, Enums.BushidoVirtue.REI)
	creditor.disposition_values[1] = -6
	var c := _make_commitment({"tier": 2, "creditor": 2, "debtor": 1})
	c.status = Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE
	c.penalty_records = [{"npc_id": 2, "disposition_change": -6, "forgiveness_applied": false}]
	var recovery: float = CommitmentRegistry.apply_forgiveness(c, creditor, 1)
	assert_almost_eq(recovery, 3.0, 0.001)
	assert_eq(creditor.disposition_values[1], -3)

func test_forgiveness_not_applied_twice():
	var creditor := _make_char(2, Enums.BushidoVirtue.JIN)
	creditor.disposition_values[1] = -6
	var c := _make_commitment({"tier": 2, "creditor": 2, "debtor": 1})
	c.status = Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE
	c.penalty_records = [{"npc_id": 2, "disposition_change": -6, "forgiveness_applied": false}]
	CommitmentRegistry.apply_forgiveness(c, creditor, 1)
	creditor.disposition_values[1] = -6
	var second: float = CommitmentRegistry.apply_forgiveness(c, creditor, 1)
	assert_almost_eq(second, 0.0, 0.001)

func test_forgiveness_only_on_force_majeure():
	var creditor := _make_char(2, Enums.BushidoVirtue.JIN)
	creditor.disposition_values[1] = -6
	var c := _make_commitment({"tier": 2, "creditor": 2, "debtor": 1})
	c.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE
	c.penalty_records = [{"npc_id": 2, "disposition_change": -6, "forgiveness_applied": false}]
	var recovery: float = CommitmentRegistry.apply_forgiveness(c, creditor, 1)
	assert_almost_eq(recovery, 0.0, 0.001)


# =============================================================================
# Phase 5 — Commitment-at-Risk Penalty
# =============================================================================

func test_at_risk_tier3_base():
	var c := _make_char(1)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 3, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -5)

func test_at_risk_tier2_base():
	var c := _make_char(1)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 2, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -15)

func test_at_risk_tier1_base():
	var c := _make_char(1)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 1, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -25)

func test_at_risk_stacking():
	var c := _make_char(1)
	var all: Array[CommitmentData] = [
		_make_commitment({"id": 1, "tier": 2, "debtor": 1}),
		_make_commitment({"id": 2, "tier": 3, "debtor": 1}),
	]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -20)

func test_at_risk_capped_at_minus_40():
	var c := _make_char(1)
	var all: Array[CommitmentData] = [
		_make_commitment({"id": 1, "tier": 1, "debtor": 1}),
		_make_commitment({"id": 2, "tier": 1, "debtor": 1}),
	]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -40)

func test_at_risk_meiyo_additional():
	var c := _make_char(1, Enums.BushidoVirtue.MEIYO)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 3, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -10)

func test_at_risk_gi_additional():
	var c := _make_char(1, Enums.BushidoVirtue.GI)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 2, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -23)

func test_at_risk_seigyo_reduced():
	var c := _make_char_shourido(1, Enums.ShouridoVirtue.SEIGYO)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 2, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -10)

func test_at_risk_kyoryoku_reduced():
	var c := _make_char_shourido(1, Enums.ShouridoVirtue.KYORYOKU)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 1, "debtor": 1})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), -20)

func test_at_risk_chugi_in_chain():
	var c := _make_char(1, Enums.BushidoVirtue.CHUGI)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 2, "debtor": 1, "creditor": 5})]
	var in_chain: Callable = func(npc_id: int) -> bool: return npc_id == 5
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c, in_chain), -20)

func test_at_risk_chugi_external():
	var c := _make_char(1, Enums.BushidoVirtue.CHUGI)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 2, "debtor": 1, "creditor": 5})]
	var not_in_chain: Callable = func(npc_id: int) -> bool: return false
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c, not_in_chain), -17)

func test_at_risk_ignores_other_debtor():
	var c := _make_char(1)
	var all: Array[CommitmentData] = [_make_commitment({"tier": 1, "debtor": 99})]
	assert_eq(CommitmentRegistry.get_at_risk_penalty(all, 1, c), 0)


# =============================================================================
# Phase 5 — Per-Action Commitment Modifier (s55.31.7)
# =============================================================================

func test_action_modifier_penalty_on_travel_away() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 2, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"BEGIN_TRAVEL", 200, all, 1, c,
	)
	assert_eq(result, -15, "BEGIN_TRAVEL away from target should apply penalty")


func test_action_modifier_bonus_on_travel_toward() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 2, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"BEGIN_TRAVEL", 100, all, 1, c,
	)
	assert_eq(result, 15, "BEGIN_TRAVEL toward target should give bonus")


func test_action_modifier_penalty_change_destination_away() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 1, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"CHANGE_DESTINATION", 200, all, 1, c,
	)
	assert_eq(result, -25, "CHANGE_DESTINATION away should apply penalty")


func test_action_modifier_no_penalty_change_destination_toward() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 1, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"CHANGE_DESTINATION", 100, all, 1, c,
	)
	assert_eq(result, 0, "CHANGE_DESTINATION toward target should be neutral")


func test_action_modifier_bonus_attend_court_at_target() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 3, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"ATTEND_COURT", 100, all, 1, c,
	)
	assert_eq(result, 5, "ATTEND_COURT at committed settlement should give bonus")


func test_action_modifier_bonus_for_action_at_committed_settlement() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 2, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"CHARM", 100, all, 1, c,
	)
	assert_eq(result, 15, "Any action at committed settlement should get bonus")


func test_action_modifier_zero_for_action_elsewhere() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 2, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"CHARM", 200, all, 1, c,
	)
	assert_eq(result, 0, "Action at non-committed settlement gets no modifier")


func test_action_modifier_personality_stacks() -> void:
	var c := _make_char(1, Enums.BushidoVirtue.GI)
	var commitment: CommitmentData = _make_commitment({"tier": 2, "debtor": 1})
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"BEGIN_TRAVEL", 200, all, 1, c,
	)
	assert_eq(result, -23, "Gi modifier should stack with base penalty")


func test_action_modifier_no_commitments() -> void:
	var c := _make_char(1)
	var all: Array[CommitmentData] = []
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"BEGIN_TRAVEL", 200, all, 1, c,
	)
	assert_eq(result, 0, "No commitments should give zero modifier")


func test_action_modifier_favor_obligation_ignored() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 1, "debtor": 1})
	commitment.commitment_type = Enums.CommitmentType.FAVOR_OBLIGATION
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"BEGIN_TRAVEL", 200, all, 1, c,
	)
	assert_eq(result, 0, "FAVOR_OBLIGATION should not contribute to modifier")


func test_action_modifier_persuade_at_committed_court() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 2, "debtor": 1})
	commitment.commitment_type = Enums.CommitmentType.SUPPORT_PLEDGE
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"PERSUADE", 100, all, 1, c,
	)
	assert_eq(result, 15, "PERSUADE at pledged court should get bonus")


func test_action_modifier_negotiate_at_committed_court() -> void:
	var c := _make_char(1)
	var commitment: CommitmentData = _make_commitment({"tier": 1, "debtor": 1})
	commitment.commitment_type = Enums.CommitmentType.SUPPORT_PLEDGE
	commitment.fulfillment_target = 100
	var all: Array[CommitmentData] = [commitment]
	var result: int = CommitmentRegistry.get_action_commitment_modifier(
		"NEGOTIATE", 100, all, 1, c,
	)
	assert_eq(result, 25, "NEGOTIATE at T1 pledged court should get T1 bonus")



# =============================================================================
# Batch Processing
# =============================================================================

func test_process_deadlines_fulfills():
	var debtor := _make_char(1)
	var creditor := _make_char(2)
	var chars: Dictionary = {1: debtor, 2: creditor}
	var all: Array[CommitmentData] = [
		_make_commitment({"deadline": 5, "debtor": 1, "creditor": 2}),
	]
	var checker: Callable = func(_c: CommitmentData) -> bool: return true
	var results: Array[Dictionary] = CommitmentRegistry.process_deadlines(
		all, 5, checker, chars, chars
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["status"], "FULFILLED")

func test_process_deadlines_breaks_unfulfilled():
	var debtor := _make_char(1)
	var creditor := _make_char(2)
	var chars: Dictionary = {1: debtor, 2: creditor}
	var all: Array[CommitmentData] = [
		_make_commitment({"deadline": 5, "debtor": 1, "creditor": 2, "tier": 3}),
	]
	var checker: Callable = func(_c: CommitmentData) -> bool: return false
	var results: Array[Dictionary] = CommitmentRegistry.process_deadlines(
		all, 5, checker, chars, chars
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["status"], "BROKEN_NO_NOTICE")
	assert_almost_eq(debtor.honor, 4.9, 0.001)

func test_process_deadlines_skips_future():
	var debtor := _make_char(1)
	var creditor := _make_char(2)
	var chars: Dictionary = {1: debtor, 2: creditor}
	var all: Array[CommitmentData] = [
		_make_commitment({"deadline": 20, "debtor": 1}),
	]
	var checker: Callable = func(_c: CommitmentData) -> bool: return false
	var results: Array[Dictionary] = CommitmentRegistry.process_deadlines(
		all, 5, checker, chars, chars
	)
	assert_eq(results.size(), 0)
