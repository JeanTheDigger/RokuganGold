extends GutTest
## Tests for RitsuryoTestimonySystem per GDD s11.3.10.


func _make_character(honor: float = 5.0, infamy: float = 0.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.honor = honor
	c.infamy = infamy
	c.character_name = "TestChar"
	return c


# -- Testimony Weight Formula ----

func test_weight_high_honor_no_infamy():
	assert_eq(RitsuryoTestimonySystem.get_testimony_weight(7, 0.0), 35)


func test_weight_low_honor_no_infamy():
	assert_eq(RitsuryoTestimonySystem.get_testimony_weight(3, 0.0), 15)


func test_weight_honor_with_infamy():
	assert_eq(RitsuryoTestimonySystem.get_testimony_weight(5, 3.0), 16)


func test_weight_floor_at_zero():
	assert_eq(RitsuryoTestimonySystem.get_testimony_weight(2, 5.0), 0)


func test_weight_exact_zero():
	assert_eq(RitsuryoTestimonySystem.get_testimony_weight(3, 5.0), 0)


func test_weight_honor_one():
	assert_eq(RitsuryoTestimonySystem.get_testimony_weight(1, 0.0), 5)


# -- Accused/Accuser from Character Data ----

func test_accused_denial_weight():
	var c := _make_character(7.3, 0.0)
	assert_eq(RitsuryoTestimonySystem.get_accused_denial_weight(c), 35)


func test_accuser_weight_with_infamy():
	var c := _make_character(3.0, 2.0)
	assert_eq(RitsuryoTestimonySystem.get_accuser_testimony_weight(c), 9)


# -- Contested Testimony ----

func test_claimant_wins():
	var r: Dictionary = RitsuryoTestimonySystem.resolve_contested_testimony(7, 0.0, 3, 0.0)
	assert_eq(r["outcome"], RitsuryoTestimonySystem.ContestedOutcome.CLAIMANT_WINS)
	assert_eq(r["claimant_weight"], 35)
	assert_eq(r["denier_weight"], 15)
	assert_eq(r["weight_difference"], 20)


func test_denier_wins():
	var r: Dictionary = RitsuryoTestimonySystem.resolve_contested_testimony(3, 0.0, 7, 0.0)
	assert_eq(r["outcome"], RitsuryoTestimonySystem.ContestedOutcome.DENIER_WINS)
	assert_eq(r["weight_difference"], -20)


func test_tied():
	var r: Dictionary = RitsuryoTestimonySystem.resolve_contested_testimony(5, 0.0, 5, 0.0)
	assert_eq(r["outcome"], RitsuryoTestimonySystem.ContestedOutcome.TIED)
	assert_eq(r["weight_difference"], 0)


func test_infamy_breaks_tie():
	var r: Dictionary = RitsuryoTestimonySystem.resolve_contested_testimony(5, 0.0, 5, 2.0)
	assert_eq(r["outcome"], RitsuryoTestimonySystem.ContestedOutcome.CLAIMANT_WINS)


# -- Prosecution vs Defense ----

func test_can_convict_evidence_exceeds_denial():
	assert_true(RitsuryoTestimonySystem.can_convict_on_testimony_alone(40, 15))


func test_cannot_convict_denial_exceeds_evidence():
	assert_false(RitsuryoTestimonySystem.can_convict_on_testimony_alone(30, 35))


func test_cannot_convict_equal():
	assert_false(RitsuryoTestimonySystem.can_convict_on_testimony_alone(25, 25))


func test_effective_evidence_after_denial():
	assert_eq(RitsuryoTestimonySystem.get_effective_evidence_after_denial(50, 15), 35)


func test_effective_evidence_floor_zero():
	assert_eq(RitsuryoTestimonySystem.get_effective_evidence_after_denial(10, 35), 0)


# -- Low Honor Thresholds ----

func test_low_honor_at_3():
	assert_true(RitsuryoTestimonySystem.is_low_honor(3))


func test_not_low_honor_at_4():
	assert_false(RitsuryoTestimonySystem.is_low_honor(4))


func test_testimony_worthless():
	assert_true(RitsuryoTestimonySystem.is_testimony_worthless(2, 5.0))


func test_testimony_not_worthless():
	assert_false(RitsuryoTestimonySystem.is_testimony_worthless(5, 0.0))


# -- Conviction Risk ----

func test_conviction_risk_safe():
	var r: Dictionary = RitsuryoTestimonySystem.get_conviction_risk(3, 0.0, 50)
	assert_true(r["can_convict"])
	assert_eq(r["margin"], 35)
	assert_false(r["high_honor_risk"])


func test_conviction_risk_high_honor():
	var r: Dictionary = RitsuryoTestimonySystem.get_conviction_risk(7, 0.0, 45)
	assert_true(r["can_convict"])
	assert_eq(r["margin"], 10)
	assert_true(r["high_honor_risk"])


func test_conviction_risk_cannot_convict():
	var r: Dictionary = RitsuryoTestimonySystem.get_conviction_risk(7, 0.0, 30)
	assert_false(r["can_convict"])
	assert_eq(r["margin"], -5)


# -- Trial by Combat ----

func test_trial_bypasses_testimony():
	assert_true(RitsuryoTestimonySystem.trial_by_combat_bypasses_testimony())
