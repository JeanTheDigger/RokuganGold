extends GutTest


var _engine: DiceEngine
var _subject: L5RCharacterData
var _revealer: L5RCharacterData
var _recipient: L5RCharacterData
var _fabricator: L5RCharacterData


func before_each() -> void:
	_engine = DiceEngine.new(42)

	_subject = L5RCharacterData.new()
	_subject.character_id = 1
	_subject.honor = 5.0
	_subject.glory = 5.0
	_subject.infamy = 0.0

	_revealer = L5RCharacterData.new()
	_revealer.character_id = 2

	_recipient = L5RCharacterData.new()
	_recipient.character_id = 3
	_recipient.disposition_values = {}

	_fabricator = L5RCharacterData.new()
	_fabricator.character_id = 4
	_fabricator.agility = 4
	_fabricator.skills = {"Forgery": 3}
	_fabricator.honor = 5.0
	_fabricator.infamy = 0.0


# ==============================================================================
# Secret Creation
# ==============================================================================

func test_create_secret_sets_fields() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 10, SecretData.Severity.TIER_2, "scandal", "A scandal")
	assert_eq(s.secret_id, 1)
	assert_eq(s.subject_id, 10)
	assert_eq(s.severity, SecretData.Severity.TIER_2)
	assert_eq(s.slug, "scandal")
	assert_eq(s.description, "A scandal")
	assert_false(s.fabricated)
	assert_false(s.exposed)


func test_create_secret_defaults() -> void:
	var s: SecretData = SecretSystem.create_secret(2, 20, SecretData.Severity.TIER_4)
	assert_eq(s.slug, "")
	assert_eq(s.description, "")


# ==============================================================================
# Severity Enum Values
# ==============================================================================

func test_tier_1_is_most_severe() -> void:
	assert_eq(SecretData.Severity.TIER_1, 1)


func test_tier_4_is_least_severe() -> void:
	assert_eq(SecretData.Severity.TIER_4, 4)


# ==============================================================================
# Context Modifier — Severity Upgrade
# ==============================================================================

func test_no_upgrade_when_no_conditions_met() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_3)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 5.0, 3.0, 10)
	assert_eq(eff, SecretData.Severity.TIER_3)


func test_upgrade_when_involved_status_higher() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_3)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 3.0, 5.0, 10)
	assert_eq(eff, SecretData.Severity.TIER_2)


func test_upgrade_when_recent_act() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_3)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 5.0, 3.0, 2)
	assert_eq(eff, SecretData.Severity.TIER_2)


func test_no_upgrade_past_tier_4() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_4)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 3.0, 5.0, 1)
	assert_eq(eff, SecretData.Severity.TIER_4)


func test_upgrade_caps_at_tier_4_value() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_4)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 1.0, 9.0, 0)
	assert_eq(eff, SecretData.Severity.TIER_4)


func test_recency_boundary_at_4_seasons() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_3)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 5.0, 3.0, 4)
	assert_eq(eff, SecretData.Severity.TIER_3)


func test_recency_at_3_seasons_upgrades() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 1, SecretData.Severity.TIER_3)
	var eff: SecretData.Severity = SecretSystem.get_effective_severity(s, 5.0, 3.0, 3)
	assert_eq(eff, SecretData.Severity.TIER_2)


# ==============================================================================
# Private Exposure
# ==============================================================================

func test_reveal_privately_tier_4_disposition() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_4)
	var r: Dictionary = SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_eq(r["disposition_change"], -8)


func test_reveal_privately_tier_1_disposition() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	var r: Dictionary = SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_eq(r["disposition_change"], -50)


func test_reveal_privately_marks_exposed() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_true(s.exposed)
	assert_false(s.exposed_publicly)


func test_reveal_privately_applies_honor_loss() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_2)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_almost_eq(_subject.honor, 4.0, 0.01)


func test_reveal_privately_applies_glory_loss() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_almost_eq(_subject.glory, 4.0, 0.01)


func test_reveal_privately_applies_infamy_gain() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_almost_eq(_subject.infamy, 0.5, 0.01)


func test_reveal_privately_no_honor_loss_tier_4() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_4)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_almost_eq(_subject.honor, 5.0, 0.01)


func test_reveal_privately_mutates_recipient_disposition() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_eq(_recipient.disposition_values[_subject.character_id], -15)


func test_reveal_privately_generates_betrayal_topic_tier_1() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	var r: Dictionary = SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_true(r["generates_betrayal_topic"])


func test_reveal_privately_no_betrayal_topic_tier_2() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_2)
	var r: Dictionary = SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_false(r["generates_betrayal_topic"])


func test_reveal_privately_with_proof_grants_free_raises() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	var r: Dictionary = SecretSystem.reveal_privately(s, _revealer, _recipient, _subject, true)
	assert_eq(r["free_raises"], 1)


func test_reveal_privately_without_proof_no_free_raises() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	var r: Dictionary = SecretSystem.reveal_privately(s, _revealer, _recipient, _subject, false)
	assert_eq(r["free_raises"], 0)


func test_reveal_privately_clamps_honor_at_zero() -> void:
	_subject.honor = 0.5
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	SecretSystem.reveal_privately(s, _revealer, _recipient, _subject)
	assert_almost_eq(_subject.honor, 0.0, 0.01)


# ==============================================================================
# Public Exposure
# ==============================================================================

func test_expose_publicly_disposition_per_witness() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	var w1: L5RCharacterData = L5RCharacterData.new()
	w1.character_id = 10
	var w2: L5RCharacterData = L5RCharacterData.new()
	w2.character_id = 11
	var chars: Dictionary = {10: w1, 11: w2}
	var r: Dictionary = SecretSystem.expose_publicly(s, _revealer, _subject, [10, 11] as Array[int], chars)
	assert_eq(r["disposition_per_witness"], -10)
	assert_eq(r["witness_count"], 2)
	assert_eq(r["witness_effects"].size(), 2)


func test_expose_publicly_marks_both_flags() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_2)
	SecretSystem.expose_publicly(s, _revealer, _subject, [] as Array[int], {})
	assert_true(s.exposed)
	assert_true(s.exposed_publicly)


func test_expose_publicly_applies_subject_consequences() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_2)
	SecretSystem.expose_publicly(s, _revealer, _subject, [] as Array[int], {})
	assert_almost_eq(_subject.honor, 4.0, 0.01)
	assert_almost_eq(_subject.glory, 4.5, 0.01)
	assert_almost_eq(_subject.infamy, 0.3, 0.01)


func test_expose_publicly_witness_disposition_mutated() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	var w: L5RCharacterData = L5RCharacterData.new()
	w.character_id = 10
	var r: Dictionary = SecretSystem.expose_publicly(s, _revealer, _subject, [10] as Array[int], {10: w})
	assert_eq(w.disposition_values[_subject.character_id], -35)


func test_expose_publicly_tier_1_generates_betrayal_topic() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_1)
	var r: Dictionary = SecretSystem.expose_publicly(s, _revealer, _subject, [] as Array[int], {})
	assert_true(r["generates_betrayal_topic"])


func test_expose_publicly_has_proof_grants_raises() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	var r: Dictionary = SecretSystem.expose_publicly(s, _revealer, _subject, [] as Array[int], {}, true)
	assert_eq(r["free_raises"], 1)


func test_expose_publicly_skips_missing_witness() -> void:
	var s: SecretData = SecretSystem.create_secret(1, _subject.character_id, SecretData.Severity.TIER_3)
	var r: Dictionary = SecretSystem.expose_publicly(s, _revealer, _subject, [99] as Array[int], {})
	assert_eq(r["witness_effects"].size(), 0)


# ==============================================================================
# Fabrication TN
# ==============================================================================

func test_fabrication_tn_tier_1() -> void:
	assert_eq(SecretSystem.get_fabrication_tn(SecretData.Severity.TIER_1), 15)


func test_fabrication_tn_tier_2() -> void:
	assert_eq(SecretSystem.get_fabrication_tn(SecretData.Severity.TIER_2), 20)


func test_fabrication_tn_tier_3() -> void:
	assert_eq(SecretSystem.get_fabrication_tn(SecretData.Severity.TIER_3), 25)


func test_fabrication_tn_tier_4() -> void:
	assert_eq(SecretSystem.get_fabrication_tn(SecretData.Severity.TIER_4), 30)


# ==============================================================================
# Fabrication
# ==============================================================================

func test_fabricate_fails_without_forgery_skill() -> void:
	_fabricator.skills = {}
	var r: Dictionary = SecretSystem.fabricate_secret(_fabricator, 10, SecretData.Severity.TIER_3, 1, _engine)
	assert_false(r["success"])
	assert_eq(r["reason"], "no_forgery_skill")


func test_fabricate_applies_honor_cost() -> void:
	var starting_honor: float = _fabricator.honor
	SecretSystem.fabricate_secret(_fabricator, 10, SecretData.Severity.TIER_1, 1, _engine)
	assert_true(_fabricator.honor < starting_honor)


func test_fabricate_applies_infamy() -> void:
	SecretSystem.fabricate_secret(_fabricator, 10, SecretData.Severity.TIER_1, 1, _engine)
	assert_almost_eq(_fabricator.infamy, 0.2, 0.01)


func test_fabricate_success_creates_secret() -> void:
	var high_skill: L5RCharacterData = L5RCharacterData.new()
	high_skill.character_id = 99
	high_skill.agility = 8
	high_skill.skills = {"Forgery": 8}
	high_skill.honor = 5.0
	high_skill.infamy = 0.0
	var e: DiceEngine = DiceEngine.new(7)
	var r: Dictionary = SecretSystem.fabricate_secret(high_skill, 10, SecretData.Severity.TIER_1, 50, e)
	if r["success"]:
		var secret: SecretData = r["secret"]
		assert_true(secret.fabricated)
		assert_eq(secret.fabricator_id, 99)
		assert_eq(secret.subject_id, 10)
		assert_eq(secret.secret_id, 50)
	else:
		pass_test("Roll failed — acceptable with dice RNG")


func test_fabricate_with_raises_increases_tn() -> void:
	var r: Dictionary = SecretSystem.fabricate_secret(_fabricator, 10, SecretData.Severity.TIER_1, 1, _engine, 2)
	assert_eq(r["tn"], 25)


func test_fabricate_honor_cost_tier_4() -> void:
	_fabricator.honor = 5.0
	SecretSystem.fabricate_secret(_fabricator, 10, SecretData.Severity.TIER_4, 1, _engine)
	assert_almost_eq(_fabricator.honor, 3.5, 0.01)


func test_fabricate_honor_cost_tier_1() -> void:
	_fabricator.honor = 5.0
	SecretSystem.fabricate_secret(_fabricator, 10, SecretData.Severity.TIER_1, 1, _engine)
	assert_almost_eq(_fabricator.honor, 4.7, 0.01)


# ==============================================================================
# Detect Fabrication
# ==============================================================================

func test_detect_non_fabricated_returns_not_checked() -> void:
	var s: SecretData = SecretSystem.create_secret(1, 10, SecretData.Severity.TIER_3)
	var investigator: L5RCharacterData = L5RCharacterData.new()
	investigator.perception = 4
	investigator.skills = {"Investigation": 3}
	var r: Dictionary = SecretSystem.detect_fabrication(investigator, s, _engine)
	assert_false(r["checked"])
	assert_eq(r["reason"], "not_fabricated")


func test_detect_fabricated_secret_checked() -> void:
	var s: SecretData = SecretData.new()
	s.fabricated = true
	s.detection_tn = 15
	var investigator: L5RCharacterData = L5RCharacterData.new()
	investigator.perception = 4
	investigator.skills = {"Investigation": 3}
	var r: Dictionary = SecretSystem.detect_fabrication(investigator, s, _engine)
	assert_true(r["checked"])
	assert_has(r, "detected")
	assert_eq(r["detection_tn"], 15)


# ==============================================================================
# Covert Acquisition Costs
# ==============================================================================

func test_bribe_costs() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.honor = 5.0
	actor.infamy = 0.0
	SecretSystem.apply_bribe_costs(actor)
	assert_almost_eq(actor.honor, 4.8, 0.01)
	assert_almost_eq(actor.infamy, 0.1, 0.01)


func test_eavesdrop_costs() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.honor = 5.0
	actor.infamy = 0.0
	SecretSystem.apply_eavesdrop_costs(actor)
	assert_almost_eq(actor.honor, 4.9, 0.01)
	assert_almost_eq(actor.infamy, 0.05, 0.01)


func test_intercept_costs() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.honor = 5.0
	actor.infamy = 0.0
	SecretSystem.apply_intercept_costs(actor)
	assert_almost_eq(actor.honor, 4.7, 0.01)
	assert_almost_eq(actor.infamy, 0.1, 0.01)


func test_search_costs() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.honor = 5.0
	actor.infamy = 0.0
	SecretSystem.apply_search_costs(actor)
	assert_almost_eq(actor.honor, 4.7, 0.01)
	assert_almost_eq(actor.infamy, 0.1, 0.01)


func test_covert_costs_clamp_honor_at_zero() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.honor = 0.1
	actor.infamy = 0.0
	SecretSystem.apply_intercept_costs(actor)
	assert_almost_eq(actor.honor, 0.0, 0.01)


func test_covert_costs_clamp_infamy_at_ten() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.honor = 5.0
	actor.infamy = 9.95
	SecretSystem.apply_bribe_costs(actor)
	assert_almost_eq(actor.infamy, 10.0, 0.01)


# ==============================================================================
# Bribe TN
# ==============================================================================

func test_bribe_tn_positive_disposition() -> void:
	assert_eq(SecretSystem.get_bribe_tn(50), 20)


func test_bribe_tn_negative_disposition() -> void:
	assert_eq(SecretSystem.get_bribe_tn(-50), 0)


func test_bribe_tn_zero_disposition() -> void:
	assert_eq(SecretSystem.get_bribe_tn(0), 10)


# ==============================================================================
# Assassination Order Honor Cost
# ==============================================================================

func test_assassination_low_status() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(2.0), -2.0, 0.01)


func test_assassination_mid_status() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(4.0), -3.0, 0.01)


func test_assassination_high_status() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(7.0), -4.0, 0.01)


func test_assassination_imperial_status() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(9.0), -5.0, 0.01)


func test_assassination_boundary_3() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(3.0), -3.0, 0.01)


func test_assassination_boundary_6() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(6.0), -4.0, 0.01)


func test_assassination_boundary_8() -> void:
	assert_almost_eq(SecretSystem.get_assassination_order_honor_cost(8.0), -5.0, 0.01)


# ==============================================================================
# Reputation Threshold
# ==============================================================================

func test_below_threshold_no_topic() -> void:
	assert_false(SecretSystem.should_generate_reputation_topic(0.4))


func test_at_threshold_generates_topic() -> void:
	assert_true(SecretSystem.should_generate_reputation_topic(0.5))


func test_above_threshold_generates_topic() -> void:
	assert_true(SecretSystem.should_generate_reputation_topic(1.0))


# ==============================================================================
# NPC Covert Filters
# ==============================================================================

func _make_npc(clan: String, virtue_b: Enums.BushidoVirtue, honor: float) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 100
	c.clan = clan
	c.bushido_virtue = virtue_b
	c.honor = honor
	return c


func test_gi_virtue_blocks_covert() -> void:
	var c: L5RCharacterData = _make_npc("Scorpion", Enums.BushidoVirtue.GI, 1.0)
	assert_false(SecretSystem.passes_covert_filters(c, -50, true))


func test_makoto_virtue_blocks_covert() -> void:
	var c: L5RCharacterData = _make_npc("Scorpion", Enums.BushidoVirtue.MAKOTO, 1.0)
	assert_false(SecretSystem.passes_covert_filters(c, -50, true))


func test_scorpion_high_honor_passes() -> void:
	var c: L5RCharacterData = _make_npc("Scorpion", Enums.BushidoVirtue.NONE, 4.0)
	assert_true(SecretSystem.passes_covert_filters(c, -50, true))


func test_lion_high_honor_blocked() -> void:
	var c: L5RCharacterData = _make_npc("Lion", Enums.BushidoVirtue.NONE, 4.0)
	assert_false(SecretSystem.passes_covert_filters(c, -50, true))


func test_crane_high_honor_blocked() -> void:
	var c: L5RCharacterData = _make_npc("Crane", Enums.BushidoVirtue.NONE, 4.0)
	assert_false(SecretSystem.passes_covert_filters(c, -50, true))


func test_positive_disposition_no_lord_blocked() -> void:
	var c: L5RCharacterData = _make_npc("Scorpion", Enums.BushidoVirtue.NONE, 1.0)
	assert_false(SecretSystem.passes_covert_filters(c, 0, false))


func test_negative_disposition_no_lord_passes() -> void:
	var c: L5RCharacterData = _make_npc("Scorpion", Enums.BushidoVirtue.NONE, 1.0)
	assert_true(SecretSystem.passes_covert_filters(c, -50, false))


func test_lord_assignment_overrides_disposition() -> void:
	var c: L5RCharacterData = _make_npc("Scorpion", Enums.BushidoVirtue.NONE, 1.0)
	assert_true(SecretSystem.passes_covert_filters(c, 50, true))


func test_crab_low_reluctance_high_honor_blocked() -> void:
	var c: L5RCharacterData = _make_npc("Crab", Enums.BushidoVirtue.NONE, 4.0)
	assert_false(SecretSystem.passes_covert_filters(c, -50, true))


# ==============================================================================
# Fabrication Gate
# ==============================================================================

func test_can_fabricate_normal() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	assert_true(SecretSystem.can_fabricate(c))


func test_gi_cannot_fabricate() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.GI
	assert_false(SecretSystem.can_fabricate(c))


func test_makoto_cannot_fabricate() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.MAKOTO
	assert_false(SecretSystem.can_fabricate(c))


func test_ishi_can_fabricate() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.ISHI
	assert_true(SecretSystem.can_fabricate(c))


# ==============================================================================
# Fabrication Exposure Disposition
# ==============================================================================

func test_fabrication_exposed_disp_constant() -> void:
	assert_eq(SecretSystem.FABRICATION_EXPOSED_DISP, -25)


# ==============================================================================
# Clan Reluctance Table
# ==============================================================================

func test_scorpion_zero_reluctance() -> void:
	assert_eq(SecretSystem.CLAN_RELUCTANCE["Scorpion"], 0)


func test_lion_highest_reluctance() -> void:
	assert_eq(SecretSystem.CLAN_RELUCTANCE["Lion"], 5)


func test_dragon_mid_reluctance() -> void:
	assert_eq(SecretSystem.CLAN_RELUCTANCE["Dragon"], 3)


# ==============================================================================
# Eavesdrop Resolution
# ==============================================================================

func _make_eavesdropper() -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 50
	c.agility = 4
	c.skills = {"Stealth": 4}
	c.honor = 5.0
	c.infamy = 0.0
	return c


func _make_eavesdrop_target() -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 51
	c.perception = 3
	c.skills = {"Investigation": 2}
	return c


func test_eavesdrop_applies_costs() -> void:
	var eav: L5RCharacterData = _make_eavesdropper()
	var tgt: L5RCharacterData = _make_eavesdrop_target()
	SecretSystem.resolve_eavesdrop(eav, tgt, _engine)
	assert_almost_eq(eav.honor, 4.9, 0.01)
	assert_almost_eq(eav.infamy, 0.05, 0.01)


func test_eavesdrop_returns_contested_result() -> void:
	var eav: L5RCharacterData = _make_eavesdropper()
	var tgt: L5RCharacterData = _make_eavesdrop_target()
	var r: Dictionary = SecretSystem.resolve_eavesdrop(eav, tgt, _engine)
	assert_has(r, "success")
	assert_has(r, "eavesdropper_total")
	assert_has(r, "target_total")
	assert_has(r, "detection_risk")


func test_eavesdrop_detected_on_failure() -> void:
	var eav: L5RCharacterData = _make_eavesdropper()
	var tgt: L5RCharacterData = _make_eavesdrop_target()
	var r: Dictionary = SecretSystem.resolve_eavesdrop(eav, tgt, _engine)
	assert_eq(r["detected"], not r["success"])


# ==============================================================================
# Intercept Letter Resolution
# ==============================================================================

func test_intercept_applies_costs() -> void:
	_fabricator.skills["Stealth"] = 3
	_fabricator.skills["Forgery"] = 3
	var starting: float = _fabricator.honor
	SecretSystem.resolve_intercept_letter(_fabricator, _engine)
	assert_true(_fabricator.honor < starting)


func test_intercept_same_location_easier() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 60
	c.agility = 4
	c.intelligence = 4
	c.skills = {"Stealth": 3, "Forgery": 3}
	c.honor = 5.0
	c.infamy = 0.0
	var r1: Dictionary = SecretSystem.resolve_intercept_letter(c, DiceEngine.new(42), false)
	c.honor = 5.0
	c.infamy = 0.0
	var r2: Dictionary = SecretSystem.resolve_intercept_letter(c, DiceEngine.new(42), true)
	assert_eq(r2.get("stealth_tn", 0), r1.get("stealth_tn", 0) - 5)


func test_intercept_stealth_fail_detected() -> void:
	var weak: L5RCharacterData = L5RCharacterData.new()
	weak.character_id = 61
	weak.agility = 1
	weak.intelligence = 1
	weak.skills = {"Stealth": 0, "Forgery": 0}
	weak.honor = 5.0
	weak.infamy = 0.0
	var e: DiceEngine = DiceEngine.new(1)
	var r: Dictionary = SecretSystem.resolve_intercept_letter(weak, e)
	if not r["success"]:
		assert_eq(r["phase_failed"], "stealth")
		assert_true(r["detection_risk"])


# ==============================================================================
# Search Quarters Resolution
# ==============================================================================

func test_search_quarters_tn_includes_target_investigation() -> void:
	var searcher: L5RCharacterData = L5RCharacterData.new()
	searcher.character_id = 70
	searcher.agility = 4
	searcher.skills = {"Sleight of Hand": 3}
	searcher.honor = 5.0
	searcher.infamy = 0.0
	var tgt: L5RCharacterData = L5RCharacterData.new()
	tgt.skills = {"Investigation": 4}
	var r: Dictionary = SecretSystem.resolve_search_quarters(searcher, tgt, _engine)
	assert_eq(r["tn"], 19)


func test_search_quarters_applies_costs() -> void:
	var searcher: L5RCharacterData = L5RCharacterData.new()
	searcher.character_id = 71
	searcher.agility = 3
	searcher.skills = {"Sleight of Hand": 2}
	searcher.honor = 5.0
	searcher.infamy = 0.0
	var tgt: L5RCharacterData = L5RCharacterData.new()
	tgt.skills = {}
	SecretSystem.resolve_search_quarters(searcher, tgt, _engine)
	assert_almost_eq(searcher.honor, 4.7, 0.01)


# ==============================================================================
# Shadow Target Resolution
# ==============================================================================

func test_shadow_target_returns_contested() -> void:
	var shadow: L5RCharacterData = L5RCharacterData.new()
	shadow.character_id = 80
	shadow.agility = 4
	shadow.skills = {"Stealth": 4}
	var tgt: L5RCharacterData = L5RCharacterData.new()
	tgt.character_id = 81
	tgt.perception = 3
	tgt.skills = {"Investigation": 2}
	var r: Dictionary = SecretSystem.resolve_shadow_target(shadow, tgt, _engine)
	assert_has(r, "success")
	assert_has(r, "shadow_total")
	assert_has(r, "target_total")
	assert_eq(r["detected"], not r["success"])
	assert_has(r, "detection_risk")
	assert_eq(r["detection_risk"], r["detected"])


# ==============================================================================
# Conceal Item
# ==============================================================================

func test_conceal_tn_small() -> void:
	assert_eq(SecretSystem.get_conceal_tn("SMALL"), 10)


func test_conceal_tn_medium() -> void:
	assert_eq(SecretSystem.get_conceal_tn("MEDIUM"), 15)


func test_conceal_tn_large() -> void:
	assert_eq(SecretSystem.get_conceal_tn("LARGE"), 20)


func test_conceal_weapon_requires_rank_5() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.agility = 3
	actor.skills = {"Sleight of Hand": 3}
	var r: Dictionary = SecretSystem.resolve_conceal_item(actor, "SMALL", true, _engine)
	assert_false(r["success"])
	assert_eq(r["reason"], "weapon_skill_gate")


func test_conceal_weapon_rank_5_allowed() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.agility = 4
	actor.skills = {"Sleight of Hand": 5}
	var r: Dictionary = SecretSystem.resolve_conceal_item(actor, "SMALL", true, _engine)
	assert_has(r, "roll_total")


func test_conceal_non_weapon_no_gate() -> void:
	var actor: L5RCharacterData = L5RCharacterData.new()
	actor.agility = 3
	actor.skills = {"Sleight of Hand": 2}
	var r: Dictionary = SecretSystem.resolve_conceal_item(actor, "MEDIUM", false, _engine)
	assert_has(r, "roll_total")


# ==============================================================================
# Search Person
# ==============================================================================

func test_search_person_glory_cost_without_authority() -> void:
	var searcher: L5RCharacterData = L5RCharacterData.new()
	searcher.character_id = 90
	searcher.perception = 2
	searcher.skills = {"Investigation": 1}
	searcher.glory = 5.0
	var tgt: L5RCharacterData = L5RCharacterData.new()
	var e: DiceEngine = DiceEngine.new(1)
	var r: Dictionary = SecretSystem.resolve_search_person(searcher, tgt, 99, e, false)
	if not r["success"]:
		assert_almost_eq(searcher.glory, 4.7, 0.01)


func test_search_person_no_glory_cost_with_authority() -> void:
	var searcher: L5RCharacterData = L5RCharacterData.new()
	searcher.character_id = 91
	searcher.perception = 2
	searcher.skills = {"Investigation": 1}
	searcher.glory = 5.0
	var tgt: L5RCharacterData = L5RCharacterData.new()
	var e: DiceEngine = DiceEngine.new(1)
	SecretSystem.resolve_search_person(searcher, tgt, 99, e, true)
	assert_almost_eq(searcher.glory, 5.0, 0.01)


# ==============================================================================
# Forge Impersonation Letter
# ==============================================================================

func test_forge_letter_no_forgery_fails() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.skills = {}
	var r: Dictionary = SecretSystem.resolve_forge_impersonation_letter(c, "minor", _engine)
	assert_false(r["success"])
	assert_eq(r["reason"], "no_forgery_skill")


func test_forge_letter_tn_by_authority() -> void:
	assert_eq(SecretSystem.FORGE_LETTER_TN["minor"], 15)
	assert_eq(SecretSystem.FORGE_LETTER_TN["moderate"], 20)
	assert_eq(SecretSystem.FORGE_LETTER_TN["major"], 25)


func test_forge_letter_applies_honor_and_infamy() -> void:
	_fabricator.honor = 5.0
	_fabricator.infamy = 0.0
	SecretSystem.resolve_forge_impersonation_letter(_fabricator, "minor", _engine)
	assert_almost_eq(_fabricator.honor, 4.7, 0.01)
	assert_almost_eq(_fabricator.infamy, 0.1, 0.01)


# ==============================================================================
# Forge Order
# ==============================================================================

func test_forge_order_no_forgery_fails() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.skills = {}
	var r: Dictionary = SecretSystem.resolve_forge_order(c, "minor", _engine)
	assert_false(r["success"])


func test_forge_order_tn_by_authority() -> void:
	assert_eq(SecretSystem.FORGE_ORDER_TN["minor"], 20)
	assert_eq(SecretSystem.FORGE_ORDER_TN["moderate"], 25)
	assert_eq(SecretSystem.FORGE_ORDER_TN["major"], 30)


func test_forge_order_applies_honor_and_infamy() -> void:
	_fabricator.honor = 5.0
	_fabricator.infamy = 0.0
	SecretSystem.resolve_forge_order(_fabricator, "minor", _engine)
	assert_almost_eq(_fabricator.honor, 4.7, 0.01)
	assert_almost_eq(_fabricator.infamy, 0.1, 0.01)


# -- Technique bonus integration (SkillResolver routing) -----------------------

func _make_kitsuki_investigator(rank: int) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 90
	c.school = "Kitsuki Investigator"
	c.perception = 4
	c.awareness = 3
	c.intelligence = 3
	c.willpower = 2
	c.stamina = 2
	c.strength = 2
	c.agility = 3
	c.reflexes = 3
	c.void_ring = 2
	c.skills = {"Investigation": 3, "Courtier": 2, "Etiquette": 2, "Kenjutsu": 1}
	if rank >= 2:
		c.skills["Investigation"] = 4
		c.skills["Lore: Law"] = 2
		c.perception = 5
	return c


func test_detect_fabrication_kitsuki_gets_free_raise() -> void:
	var kitsuki: L5RCharacterData = _make_kitsuki_investigator(1)
	var generic: L5RCharacterData = L5RCharacterData.new()
	generic.character_id = 91
	generic.school = "Bayushi Bushi"
	generic.perception = 4
	generic.skills = {"Investigation": 3}
	generic.awareness = 2
	generic.intelligence = 2
	generic.willpower = 2
	generic.stamina = 2
	generic.strength = 2
	generic.agility = 2
	generic.reflexes = 2
	generic.void_ring = 2

	var secret := SecretData.new()
	secret.fabricated = true
	secret.detection_tn = 20

	var kitsuki_total: int = 0
	var generic_total: int = 0
	var trials: int = 200
	for i: int in range(trials):
		var d1: DiceEngine = DiceEngine.new(i * 7)
		var r1: Dictionary = SecretSystem.detect_fabrication(kitsuki, secret, d1)
		kitsuki_total += r1.get("roll_total", 0)
		var d2: DiceEngine = DiceEngine.new(i * 7)
		var r2: Dictionary = SecretSystem.detect_fabrication(generic, secret, d2)
		generic_total += r2.get("roll_total", 0)

	assert_true(
		kitsuki_total > generic_total,
		"Kitsuki should average higher due to free raise (+5 flat bonus)"
	)


# ==============================================================================
# CONCEAL_ITEM School Lean (s12.8)
# ==============================================================================

func test_conceal_school_lean_shosuro() -> void:
	var shosuro: L5RCharacterData = L5RCharacterData.new()
	shosuro.school = "Shosuro Infiltrator"
	shosuro.agility = 3
	shosuro.skills = {"Sleight of Hand": 3}
	assert_true(SecretSystem._has_conceal_lean(shosuro))


func test_conceal_school_lean_kasuga() -> void:
	var kasuga: L5RCharacterData = L5RCharacterData.new()
	kasuga.school = "Kasuga Smuggler"
	kasuga.agility = 3
	kasuga.skills = {"Sleight of Hand": 3}
	assert_true(SecretSystem._has_conceal_lean(kasuga))


func test_conceal_school_lean_kolat() -> void:
	var kolat: L5RCharacterData = L5RCharacterData.new()
	kolat.school = "Bayushi Bushi"
	kolat.kolat_sect = Enums.KolatSect.SILK
	kolat.agility = 3
	kolat.skills = {"Sleight of Hand": 3}
	assert_true(SecretSystem._has_conceal_lean(kolat))


func test_conceal_no_lean_generic() -> void:
	var generic: L5RCharacterData = L5RCharacterData.new()
	generic.school = "Akodo Bushi"
	generic.agility = 3
	generic.skills = {"Sleight of Hand": 3}
	assert_false(SecretSystem._has_conceal_lean(generic))


func test_conceal_lean_improves_roll() -> void:
	var shosuro: L5RCharacterData = L5RCharacterData.new()
	shosuro.school = "Shosuro Infiltrator"
	shosuro.agility = 3
	shosuro.skills = {"Sleight of Hand": 3}
	var generic: L5RCharacterData = L5RCharacterData.new()
	generic.school = "Akodo Bushi"
	generic.agility = 3
	generic.skills = {"Sleight of Hand": 3}

	var shosuro_total: int = 0
	var generic_total: int = 0
	for i: int in range(100):
		var e1: DiceEngine = DiceEngine.new(i * 11)
		var r1: Dictionary = SecretSystem.resolve_conceal_item(shosuro, "SMALL", false, e1)
		shosuro_total += r1.get("roll_total", 0)
		var e2: DiceEngine = DiceEngine.new(i * 11)
		var r2: Dictionary = SecretSystem.resolve_conceal_item(generic, "SMALL", false, e2)
		generic_total += r2.get("roll_total", 0)

	assert_true(shosuro_total > generic_total,
		"Shosuro should average higher due to +1k0 school lean")


# ==============================================================================
# Auto-Conceal on Arrival (s12.8 NPC Behavior)
# ==============================================================================

func test_auto_conceal_fires_for_contraband() -> void:
	var npc: L5RCharacterData = L5RCharacterData.new()
	npc.character_id = 80
	npc.agility = 4
	npc.skills = {"Sleight of Hand": 4}
	npc.physical_location = "Kyuden Bayushi"
	var poison_item: Dictionary = InventorySystem.create_item(
		1, "Poison Vial", InventorySystem.ItemCategory.VALUABLE,
		InventorySystem.ItemSize.SMALL, 1, false, true,
	)
	npc.items.append(poison_item)

	var arrivals: Array[Dictionary] = [{"character_id": 80, "destination": "Kyuden Bayushi"}]
	var chars: Dictionary = {80: npc}
	var e: DiceEngine = DiceEngine.new(42)
	var results: Array[Dictionary] = DayOrchestrator._process_auto_conceal_on_arrival(arrivals, chars, e)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["character_id"], 80)
	assert_eq(results[0]["item_id"], 1)


func test_auto_conceal_skips_non_contraband() -> void:
	var npc: L5RCharacterData = L5RCharacterData.new()
	npc.character_id = 81
	npc.agility = 3
	npc.skills = {"Sleight of Hand": 2}
	npc.physical_location = "Kyuden Crane"
	var normal_item: Dictionary = InventorySystem.create_item(
		2, "Letter", InventorySystem.ItemCategory.DOCUMENT,
		InventorySystem.ItemSize.SMALL, 1, false, false,
	)
	npc.items.append(normal_item)

	var arrivals: Array[Dictionary] = [{"character_id": 81, "destination": "Kyuden Crane"}]
	var chars: Dictionary = {81: npc}
	var e: DiceEngine = DiceEngine.new(42)
	var results: Array[Dictionary] = DayOrchestrator._process_auto_conceal_on_arrival(arrivals, chars, e)

	assert_eq(results.size(), 0, "Non-contraband items should not trigger auto-conceal")


func test_auto_conceal_skips_already_concealed() -> void:
	var npc: L5RCharacterData = L5RCharacterData.new()
	npc.character_id = 82
	npc.agility = 4
	npc.skills = {"Sleight of Hand": 4}
	npc.physical_location = "Otosan Uchi"
	var item: Dictionary = InventorySystem.create_item(
		3, "Stolen Evidence", InventorySystem.ItemCategory.EVIDENCE,
		InventorySystem.ItemSize.SMALL, 1, false, true,
	)
	item["concealed"] = true
	item["concealment_tn"] = 20
	npc.items.append(item)

	var arrivals: Array[Dictionary] = [{"character_id": 82, "destination": "Otosan Uchi"}]
	var chars: Dictionary = {82: npc}
	var e: DiceEngine = DiceEngine.new(42)
	var results: Array[Dictionary] = DayOrchestrator._process_auto_conceal_on_arrival(arrivals, chars, e)

	assert_eq(results.size(), 0, "Already concealed items should be skipped")


func test_auto_conceal_weapon_blocked_without_rank_5() -> void:
	var npc: L5RCharacterData = L5RCharacterData.new()
	npc.character_id = 83
	npc.agility = 3
	npc.skills = {"Sleight of Hand": 3}
	npc.physical_location = "Kyuden Doji"
	var blade: Dictionary = InventorySystem.create_item(
		4, "Tanto", InventorySystem.ItemCategory.WEAPON,
		InventorySystem.ItemSize.SMALL, 1, false, true,
	)
	npc.items.append(blade)

	var arrivals: Array[Dictionary] = [{"character_id": 83, "destination": "Kyuden Doji"}]
	var chars: Dictionary = {83: npc}
	var e: DiceEngine = DiceEngine.new(42)
	var results: Array[Dictionary] = DayOrchestrator._process_auto_conceal_on_arrival(arrivals, chars, e)

	assert_eq(results.size(), 1)
	assert_false(results[0]["success"])
	assert_eq(results[0]["reason"], "weapon_skill_gate")
