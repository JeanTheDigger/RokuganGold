extends GutTest
## Tests for MagistrateCorruptionSystem per GDD s11.3.11.


func _make_character(
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.GI,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.school_type = Enums.SchoolType.BUSHI
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	c.character_name = "TestChar"
	return c


# -- Bribery Resistance (s11.3.11f Step 6) ----

func test_resistance_bonus_high_honor():
	assert_eq(MagistrateCorruptionSystem.get_bribery_resistance_bonus(7), 35)


func test_resistance_bonus_low_honor():
	assert_eq(MagistrateCorruptionSystem.get_bribery_resistance_bonus(3), 15)


func test_resistance_bonus_zero():
	assert_eq(MagistrateCorruptionSystem.get_bribery_resistance_bonus(0), 0)


# -- Personality Gates (s11.3.11g) ----

func test_gi_blocked():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.GI),
		MagistrateCorruptionSystem.BriberyPermission.BLOCKED
	)


func test_makoto_blocked():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.MAKOTO),
		MagistrateCorruptionSystem.BriberyPermission.BLOCKED
	)


func test_meiyo_blocked():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.MEIYO),
		MagistrateCorruptionSystem.BriberyPermission.BLOCKED
	)


func test_jin_conditional():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.JIN),
		MagistrateCorruptionSystem.BriberyPermission.CONDITIONAL
	)


func test_yu_conditional():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.YU),
		MagistrateCorruptionSystem.BriberyPermission.CONDITIONAL
	)


func test_rei_conditional():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.REI),
		MagistrateCorruptionSystem.BriberyPermission.CONDITIONAL
	)


func test_chugi_conditional():
	assert_eq(
		MagistrateCorruptionSystem.get_bushido_bribery_permission(Enums.BushidoVirtue.CHUGI),
		MagistrateCorruptionSystem.BriberyPermission.CONDITIONAL
	)


func test_seigyo_unrestricted():
	assert_eq(
		MagistrateCorruptionSystem.get_shourido_bribery_permission(Enums.ShouridoVirtue.SEIGYO),
		MagistrateCorruptionSystem.BriberyPermission.UNRESTRICTED
	)


func test_ketsui_unrestricted():
	assert_eq(
		MagistrateCorruptionSystem.get_shourido_bribery_permission(Enums.ShouridoVirtue.KETSUI),
		MagistrateCorruptionSystem.BriberyPermission.UNRESTRICTED
	)


func test_dosatsu_unrestricted():
	assert_eq(
		MagistrateCorruptionSystem.get_shourido_bribery_permission(Enums.ShouridoVirtue.DOSATSU),
		MagistrateCorruptionSystem.BriberyPermission.UNRESTRICTED
	)


func test_ishi_unrestricted():
	assert_eq(
		MagistrateCorruptionSystem.get_shourido_bribery_permission(Enums.ShouridoVirtue.ISHI),
		MagistrateCorruptionSystem.BriberyPermission.UNRESTRICTED
	)


# -- Conditional Reasons ----

func test_jin_reason_protecting_innocents():
	assert_eq(
		MagistrateCorruptionSystem.get_conditional_reason(Enums.BushidoVirtue.JIN),
		MagistrateCorruptionSystem.ConditionalReason.PROTECTING_INNOCENTS
	)


func test_yu_reason_protecting_others():
	assert_eq(
		MagistrateCorruptionSystem.get_conditional_reason(Enums.BushidoVirtue.YU),
		MagistrateCorruptionSystem.ConditionalReason.PROTECTING_OTHERS
	)


func test_rei_reason_intermediary_only():
	assert_eq(
		MagistrateCorruptionSystem.get_conditional_reason(Enums.BushidoVirtue.REI),
		MagistrateCorruptionSystem.ConditionalReason.INTERMEDIARY_ONLY
	)


func test_chugi_reason_lord_assigned():
	assert_eq(
		MagistrateCorruptionSystem.get_conditional_reason(Enums.BushidoVirtue.CHUGI),
		MagistrateCorruptionSystem.ConditionalReason.LORD_ASSIGNED
	)


# -- Combined Permission Evaluation ----

func test_evaluate_shourido_overrides_bushido():
	var c := _make_character(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO)
	var result: Dictionary = MagistrateCorruptionSystem.evaluate_bribery_permission(c)
	assert_eq(result["permission"], MagistrateCorruptionSystem.BriberyPermission.UNRESTRICTED)


func test_evaluate_blocked_bushido():
	var c := _make_character(Enums.BushidoVirtue.GI)
	var result: Dictionary = MagistrateCorruptionSystem.evaluate_bribery_permission(c)
	assert_eq(result["permission"], MagistrateCorruptionSystem.BriberyPermission.BLOCKED)


func test_evaluate_conditional_has_reason():
	var c := _make_character(Enums.BushidoVirtue.JIN)
	var result: Dictionary = MagistrateCorruptionSystem.evaluate_bribery_permission(c)
	assert_eq(result["permission"], MagistrateCorruptionSystem.BriberyPermission.CONDITIONAL)
	assert_eq(
		result["conditional_reason"],
		MagistrateCorruptionSystem.ConditionalReason.PROTECTING_INNOCENTS
	)


# -- Bribery Evaluation Trigger (s11.3.11g) ----

func test_should_evaluate_at_threshold():
	assert_true(MagistrateCorruptionSystem.should_evaluate_bribery(25))


func test_should_evaluate_above_threshold():
	assert_true(MagistrateCorruptionSystem.should_evaluate_bribery(30))


func test_should_not_evaluate_below_threshold():
	assert_false(MagistrateCorruptionSystem.should_evaluate_bribery(24))


# -- Bribe Acceptance (s11.3.11f Step 7b) ----

func test_acceptance_destroys_physical():
	var items: Array[Dictionary] = [
		{"type": MagistrateCorruptionSystem.EvidenceType.PHYSICAL, "weight": 50},
		{"type": MagistrateCorruptionSystem.EvidenceType.TESTIMONY, "weight": 20},
	]
	var result: Dictionary = MagistrateCorruptionSystem.get_bribe_acceptance_result(items)
	assert_eq(result["destroyed_weight"], 50)
	assert_eq(result["suppressed_weight"], 20)
	assert_eq(result["honor_loss"], -0.5)
	assert_eq(result["secret_tier"], 1)
	assert_eq(result["case_status"], "buried")


func test_acceptance_testimony_survives():
	var items: Array[Dictionary] = [
		{"type": MagistrateCorruptionSystem.EvidenceType.TESTIMONY, "weight": 30},
	]
	var result: Dictionary = MagistrateCorruptionSystem.get_bribe_acceptance_result(items)
	assert_eq(result["destroyed_weight"], 0)
	assert_eq(result["suppressed_weight"], 30)
	assert_eq(result["remaining_testimony"].size(), 1)


func test_evidence_total_after_corruption():
	var items: Array[Dictionary] = [
		{"type": MagistrateCorruptionSystem.EvidenceType.PHYSICAL, "weight": 40},
		{"type": MagistrateCorruptionSystem.EvidenceType.TESTIMONY, "weight": 20},
	]
	var new_total: int = MagistrateCorruptionSystem.get_evidence_total_after_corruption(
		80, items
	)
	assert_eq(new_total, 40)


func test_evidence_total_floor_zero():
	var items: Array[Dictionary] = [
		{"type": MagistrateCorruptionSystem.EvidenceType.PHYSICAL, "weight": 100},
	]
	var new_total: int = MagistrateCorruptionSystem.get_evidence_total_after_corruption(
		50, items
	)
	assert_eq(new_total, 0)


# -- Bribe Refusal (s11.3.11f Step 7a) ----

func test_refusal_direct_approach():
	var result: Dictionary = MagistrateCorruptionSystem.get_bribe_refusal_result(true)
	assert_eq(result["evidence_bonus"], 15)
	assert_true(result["separate_offense"])
	assert_true(result["briber_identity_known"])


func test_refusal_intermediary_approach():
	var result: Dictionary = MagistrateCorruptionSystem.get_bribe_refusal_result(false)
	assert_eq(result["evidence_bonus"], 15)
	assert_true(result["separate_offense"])
	assert_false(result["briber_identity_known"])


# -- Refusal Report Behavior (s11.3.11k) ----

func test_gi_reports_public():
	var c := _make_character(Enums.BushidoVirtue.GI)
	assert_eq(
		MagistrateCorruptionSystem.get_refusal_report_behavior(c),
		MagistrateCorruptionSystem.RefusalReportBehavior.REPORT_PUBLIC
	)


func test_yu_reports_public():
	var c := _make_character(Enums.BushidoVirtue.YU)
	assert_eq(
		MagistrateCorruptionSystem.get_refusal_report_behavior(c),
		MagistrateCorruptionSystem.RefusalReportBehavior.REPORT_PUBLIC
	)


func test_chugi_reports_lord_private():
	var c := _make_character(Enums.BushidoVirtue.CHUGI)
	assert_eq(
		MagistrateCorruptionSystem.get_refusal_report_behavior(c),
		MagistrateCorruptionSystem.RefusalReportBehavior.REPORT_LORD_PRIVATE
	)


func test_meiyo_reports_formal():
	var c := _make_character(Enums.BushidoVirtue.MEIYO)
	assert_eq(
		MagistrateCorruptionSystem.get_refusal_report_behavior(c),
		MagistrateCorruptionSystem.RefusalReportBehavior.REPORT_FORMAL
	)


func test_seigyo_holds_as_leverage():
	var c := _make_character(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO)
	assert_eq(
		MagistrateCorruptionSystem.get_refusal_report_behavior(c),
		MagistrateCorruptionSystem.RefusalReportBehavior.HOLD_AS_LEVERAGE
	)


func test_dosatsu_observes_silently():
	var c := _make_character(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.DOSATSU)
	assert_eq(
		MagistrateCorruptionSystem.get_refusal_report_behavior(c),
		MagistrateCorruptionSystem.RefusalReportBehavior.OBSERVE_SILENTLY
	)


# -- Evidence Destruction (s11.3.11h) ----

func test_destroy_physical_only():
	var items: Array[Dictionary] = [
		{"type": MagistrateCorruptionSystem.EvidenceType.PHYSICAL, "weight": 50},
		{"type": MagistrateCorruptionSystem.EvidenceType.TESTIMONY, "weight": 20},
		{"type": MagistrateCorruptionSystem.EvidenceType.PHYSICAL, "weight": 30},
	]
	var result: Dictionary = MagistrateCorruptionSystem.destroy_evidence(items)
	assert_eq(result["destroyed"].size(), 2)
	assert_eq(result["surviving"].size(), 1)
	assert_eq(result["weight_removed"], 80)


func test_recover_suppressed_testimony():
	var items: Array[Dictionary] = [
		{"type": MagistrateCorruptionSystem.EvidenceType.TESTIMONY, "weight": 20},
		{"type": MagistrateCorruptionSystem.EvidenceType.TESTIMONY, "weight": 15},
	]
	var result: Dictionary = MagistrateCorruptionSystem.recover_suppressed_testimony(items)
	assert_eq(result["recovered_weight"], 35)
	assert_eq(result["recovered_items"].size(), 2)


# -- Magistrate Extortion (s11.3.11j) ----

func test_extortion_success_full_demand():
	var result: Dictionary = MagistrateCorruptionSystem.get_extortion_bargain_result(true, 20)
	assert_true(result["accepted"])
	assert_eq(result["final_koku"], 20)
	assert_false(result["bargained_down"])


func test_extortion_failed_roll_bargained():
	var result: Dictionary = MagistrateCorruptionSystem.get_extortion_bargain_result(false, 20)
	assert_true(result["accepted"])
	assert_eq(result["final_koku"], 10)
	assert_true(result["bargained_down"])


func test_extortion_bargain_floor():
	var result: Dictionary = MagistrateCorruptionSystem.get_extortion_bargain_result(false, 1)
	assert_eq(result["final_koku"], 1)


func test_seigyo_can_extort():
	var c := _make_character(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO)
	assert_true(MagistrateCorruptionSystem.can_magistrate_extort(c))


func test_kyoryoku_can_extort():
	var c := _make_character(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.KYORYOKU)
	assert_true(MagistrateCorruptionSystem.can_magistrate_extort(c))


func test_dosatsu_can_extort():
	var c := _make_character(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.DOSATSU)
	assert_true(MagistrateCorruptionSystem.can_magistrate_extort(c))


func test_gi_cannot_extort():
	var c := _make_character(Enums.BushidoVirtue.GI)
	assert_false(MagistrateCorruptionSystem.can_magistrate_extort(c))


func test_makoto_cannot_extort():
	var c := _make_character(Enums.BushidoVirtue.MAKOTO)
	assert_false(MagistrateCorruptionSystem.can_magistrate_extort(c))


# -- Jurisdiction (s11.3.11c) ----

func test_emerald_magistrate_always_can():
	assert_true(
		MagistrateCorruptionSystem.can_investigate_corrupt_magistrate(1, 5, true)
	)


func test_equal_rank_can():
	assert_true(
		MagistrateCorruptionSystem.can_investigate_corrupt_magistrate(3, 3, false)
	)


func test_higher_rank_can():
	assert_true(
		MagistrateCorruptionSystem.can_investigate_corrupt_magistrate(5, 3, false)
	)


func test_lower_rank_cannot():
	assert_false(
		MagistrateCorruptionSystem.can_investigate_corrupt_magistrate(2, 4, false)
	)


# -- Corruption Spiral (s11.3.11f Step 7b) ----

func test_spiral_no_bribes():
	assert_eq(MagistrateCorruptionSystem.get_corruption_spiral_resistance(7, 0), 35)


func test_spiral_one_bribe():
	assert_eq(MagistrateCorruptionSystem.get_corruption_spiral_resistance(7, 1), 30)


func test_spiral_multiple_bribes():
	assert_eq(MagistrateCorruptionSystem.get_corruption_spiral_resistance(7, 4), 25)


func test_spiral_floor_zero():
	assert_eq(MagistrateCorruptionSystem.get_corruption_spiral_resistance(3, 10), 0)


# -- Exposure Scope (s11.3.11d) ----

func test_exposure_scope():
	var scope: Dictionary = MagistrateCorruptionSystem.get_exposure_scope()
	assert_true(scope["active_cases_affected"])
	assert_false(scope["past_closed_cases_reopened"])
	assert_true(scope["requires_independent_investigation"])


# -- Punishment (s11.3.11e) ----

func test_punishment_is_treason():
	var p: Dictionary = MagistrateCorruptionSystem.get_corruption_punishment()
	assert_eq(p["severity"], "treason_equivalent")
	assert_true(p["seppuku_offered"])
	assert_eq(p["topic_tier"], 2)
	assert_true(p["appointing_lord_disposition_hit"])
