extends GutTest
## Tests for RitsuyoSystem per GDD s11.3.10.


func _make_character(honor: float = 5.0, infamy: float = 0.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.honor = honor
	c.infamy = infamy
	return c


# -- Testimony Weight (s11.3.10) ----

func test_honor_7_no_infamy():
	var c := _make_character(7.0, 0.0)
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 35)


func test_honor_5_no_infamy():
	var c := _make_character(5.0, 0.0)
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 25)


func test_honor_3_no_infamy():
	var c := _make_character(3.0, 0.0)
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 15)


func test_honor_1_no_infamy():
	var c := _make_character(1.5, 0.0)
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 5)


func test_honor_5_infamy_3():
	var c := _make_character(5.0, 3.0)
	# 25 - 9 = 16
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 16)


func test_honor_2_infamy_5():
	var c := _make_character(2.0, 5.0)
	# 10 - 15 = -5 → floored at 0
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 0)


func test_testimony_cannot_go_negative():
	var c := _make_character(1.0, 10.0)
	assert_eq(RitsuyoSystem.get_testimony_weight(c), 0)


# -- Low Honor / Worthless Testimony ----

func test_is_low_honor_accused_honor_3():
	var c := _make_character(3.0)
	assert_true(RitsuyoSystem.is_low_honor_accused(c))


func test_is_low_honor_accused_honor_4():
	var c := _make_character(4.0)
	assert_false(RitsuyoSystem.is_low_honor_accused(c))


func test_is_testimony_worthless_zero_weight():
	var c := _make_character(2.0, 5.0)
	assert_true(RitsuyoSystem.is_testimony_worthless(c))


func test_is_testimony_worthless_nonzero():
	var c := _make_character(5.0, 0.0)
	assert_false(RitsuyoSystem.is_testimony_worthless(c))


# -- Testimonial Advantage ----

func test_high_honor_accuser_vs_low_honor_accused():
	var accuser := _make_character(7.0, 0.0)
	var accused := _make_character(3.0, 0.0)
	# 35 - 15 = 20 advantage for accuser
	assert_eq(RitsuyoSystem.get_testimonial_advantage(accuser, accused), 20)


func test_low_honor_accuser_vs_high_honor_accused():
	var accuser := _make_character(3.0, 2.0)
	var accused := _make_character(7.0, 0.0)
	# accuser: 15-6=9, accused: 35. 9-35 = -26 (negative = accused advantaged)
	assert_eq(RitsuyoSystem.get_testimonial_advantage(accuser, accused), -26)


func test_equal_honor_no_advantage():
	var accuser := _make_character(5.0, 0.0)
	var accused := _make_character(5.0, 0.0)
	assert_eq(RitsuyoSystem.get_testimonial_advantage(accuser, accused), 0)


# -- Defense Strength ----

func test_defense_high_honor_denies_effectively():
	var accused := _make_character(7.0, 0.0)
	var result := RitsuyoSystem.get_defense_strength(accused, 30)
	assert_eq(result["testimony_weight"], 35)
	assert_true(result["can_deny_effectively"])
	assert_eq(result["net_evidence"], -5)


func test_defense_low_honor_cannot_deny():
	var accused := _make_character(3.0, 0.0)
	var result := RitsuyoSystem.get_defense_strength(accused, 30)
	assert_eq(result["testimony_weight"], 15)
	assert_false(result["can_deny_effectively"])
	assert_eq(result["net_evidence"], 15)


func test_defense_infamy_weakens_denial():
	var accused := _make_character(5.0, 3.0)
	# testimony = 25-9 = 16
	var result := RitsuyoSystem.get_defense_strength(accused, 30)
	assert_eq(result["testimony_weight"], 16)
	assert_false(result["can_deny_effectively"])


# -- Prosecution Strength ----

func test_prosecution_credible_when_accuser_outranks():
	var accuser := _make_character(7.0, 0.0)
	var accused := _make_character(3.0, 0.0)
	var result := RitsuyoSystem.get_prosecution_strength(accuser, 30, accused)
	assert_true(result["structurally_credible"])
	# effective = 30 + 35 - 15 = 50
	assert_eq(result["effective_evidence"], 50)


func test_prosecution_not_credible_when_accused_outranks():
	var accuser := _make_character(3.0, 2.0)
	var accused := _make_character(7.0, 0.0)
	var result := RitsuyoSystem.get_prosecution_strength(accuser, 20, accused)
	assert_false(result["structurally_credible"])
	# effective = 20 + 9 - 35 = -6 → floored at 0
	assert_eq(result["effective_evidence"], 0)


func test_prosecution_with_overwhelming_physical_evidence():
	var accuser := _make_character(3.0, 2.0)
	var accused := _make_character(7.0, 0.0)
	# Even with low-honor accuser, massive evidence overcomes
	var result := RitsuyoSystem.get_prosecution_strength(accuser, 60, accused)
	# effective = 60 + 9 - 35 = 34
	assert_eq(result["effective_evidence"], 34)
	assert_false(result["structurally_credible"])


# -- Scorpion Clan Scenario (from GDD narrative) ----

func test_scorpion_vs_crane_scenario():
	# Scorpion Honor 3.0 accusing Crane Honor 7.0
	var scorpion := _make_character(3.0, 0.0)
	var crane := _make_character(7.0, 0.0)
	var result := RitsuyoSystem.get_prosecution_strength(scorpion, 25, crane)
	# effective = 25 + 15 - 35 = 5 (barely enough)
	assert_eq(result["effective_evidence"], 5)
	assert_false(result["structurally_credible"])
