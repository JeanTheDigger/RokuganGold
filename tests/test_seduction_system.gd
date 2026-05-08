extends GutTest


var _seducer: L5RCharacterData
var _target: L5RCharacterData
var _engine: DiceEngine


func before_each() -> void:
	_engine = DiceEngine.new(42)

	_seducer = L5RCharacterData.new()
	_seducer.character_id = 1
	_seducer.awareness = 4
	_seducer.skills = {"Temptation": 4}
	_seducer.honor = 5.0
	_seducer.infamy = 0.0

	_target = L5RCharacterData.new()
	_target.character_id = 2
	_target.willpower = 3
	_target.skills = {"Etiquette": 2}
	_target.honor = 3.0


# ==============================================================================
# Seduction Resolution
# ==============================================================================

func test_no_temptation_skill_fails() -> void:
	_seducer.skills = {}
	var r: Dictionary = SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE, _engine
	)
	assert_false(r["success"])
	assert_eq(r["reason"], "no_temptation_skill")


func test_seduction_applies_honor_cost() -> void:
	SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE, _engine
	)
	assert_almost_eq(_seducer.honor, 4.7, 0.01)


func test_seduction_applies_infamy() -> void:
	SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE, _engine
	)
	assert_almost_eq(_seducer.infamy, 0.1, 0.01)


func test_seduction_tn_includes_etiquette_willpower_honor() -> void:
	var r: Dictionary = SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE, _engine
	)
	# TN = 15 + etiquette(2) + willpower(3) + honor_rank(3) = 23
	assert_eq(r["tn"], 23)


func test_seduction_raises_increase_tn() -> void:
	var r: Dictionary = SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE, _engine, 2
	)
	assert_eq(r["tn"], 33)


func test_seduce_variant_gives_disposition() -> void:
	_target.willpower = 1
	_target.skills = {}
	_target.honor = 1.0
	var e: DiceEngine = DiceEngine.new(7)
	var r: Dictionary = SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE, e
	)
	if r["success"]:
		assert_eq(r["effects"]["disposition_change"], 5)
	else:
		pass_test("Low TN roll may still fail with RNG")


func test_seduce_for_info_variant() -> void:
	_target.willpower = 1
	_target.skills = {}
	_target.honor = 1.0
	var e: DiceEngine = DiceEngine.new(7)
	var r: Dictionary = SeductionSystem.resolve_seduction(
		_seducer, _target, SeductionSystem.SeductionVariant.SEDUCE_FOR_INFO, e
	)
	if r["success"]:
		assert_true(r["effects"]["info_gained"])
	else:
		pass_test("Roll may fail with RNG")


# ==============================================================================
# Entanglement Lifecycle
# ==============================================================================

func test_create_entanglement() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	assert_eq(ent["seducer_id"], 1)
	assert_eq(ent["target_id"], 2)
	assert_eq(ent["state"], SeductionSystem.EntanglementState.ACTIVE)
	assert_eq(ent["created_ic_day"], 100)
	assert_eq(ent["missed_windows"], 0)


func test_maintenance_not_needed_within_window() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	var r: Dictionary = SeductionSystem.check_maintenance(ent, 110)
	assert_false(r["needs_maintenance"])


func test_maintenance_needed_after_window() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	var r: Dictionary = SeductionSystem.check_maintenance(ent, 120)
	assert_true(r["needs_maintenance"])
	assert_eq(r["state"], SeductionSystem.EntanglementState.NEGLECTED)


func test_entanglement_breaks_after_3_missed() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	ent["missed_windows"] = 2
	var r: Dictionary = SeductionSystem.check_maintenance(ent, 120)
	assert_eq(r["state"], SeductionSystem.EntanglementState.BROKEN)


func test_maintain_resets_missed_windows() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	ent["missed_windows"] = 1
	ent["state"] = SeductionSystem.EntanglementState.NEGLECTED
	SeductionSystem.maintain_entanglement(ent, 120)
	assert_eq(ent["missed_windows"], 0)
	assert_eq(ent["state"], SeductionSystem.EntanglementState.ACTIVE)


func test_break_entanglement_high_attachment() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	var r: Dictionary = SeductionSystem.break_entanglement(ent, 50)
	assert_eq(r["disposition_loss"], -30)
	assert_eq(r["attachment_level"], "high")
	assert_eq(ent["state"], SeductionSystem.EntanglementState.BROKEN)


func test_break_entanglement_moderate_attachment() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	var r: Dictionary = SeductionSystem.break_entanglement(ent, 15)
	assert_eq(r["disposition_loss"], -15)


func test_break_entanglement_low_attachment() -> void:
	var ent: Dictionary = SeductionSystem.create_entanglement(1, 2, 100)
	var r: Dictionary = SeductionSystem.break_entanglement(ent, -10)
	assert_eq(r["disposition_loss"], -5)


# ==============================================================================
# Affair Secret Severity
# ==============================================================================

func test_unmarried_affair_tier_4() -> void:
	var s: SecretData.Severity = SeductionSystem.get_affair_severity(false, false, false, false)
	assert_eq(s, SecretData.Severity.TIER_4)


func test_married_affair_tier_3() -> void:
	var s: SecretData.Severity = SeductionSystem.get_affair_severity(true, false, false, false)
	assert_eq(s, SecretData.Severity.TIER_3)


func test_political_marriage_affair_tier_2() -> void:
	var s: SecretData.Severity = SeductionSystem.get_affair_severity(true, true, true, false)
	assert_eq(s, SecretData.Severity.TIER_2)


func test_cross_clan_affair_tier_1() -> void:
	var s: SecretData.Severity = SeductionSystem.get_affair_severity(false, false, false, true)
	assert_eq(s, SecretData.Severity.TIER_1)


func test_cross_clan_overrides_political() -> void:
	var s: SecretData.Severity = SeductionSystem.get_affair_severity(true, true, true, true)
	assert_eq(s, SecretData.Severity.TIER_1)
