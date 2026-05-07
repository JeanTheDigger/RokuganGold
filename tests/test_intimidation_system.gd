extends GutTest
## Tests for IntimidationSystem per GDD s12.9.


# -- Blackmail tests ----------------------------------------------------------

func test_blackmail_success_extracts_favors():
	var result := IntimidationSystem.resolve_blackmail(35, 15, 3.0, 2, 0)
	# defender_total = 15 + 3 = 18, free_raises = 2, effective_roll = 35 + 10 = 45
	# margin = 45 - 18 = 27, favors = 27/5 = 5
	assert_true(result["success"])
	assert_eq(result["favors_extracted"], 5)
	assert_true(result["compliance_active"])


func test_blackmail_failure():
	var result := IntimidationSystem.resolve_blackmail(10, 25, 5.0, 4, 2)
	# defender_total = 25 + 5 = 30, tn = 30 + 10 = 40
	# free_raises = 0, effective_roll = 10
	assert_false(result["success"])
	assert_eq(result["favors_extracted"], 0)
	assert_false(result["compliance_active"])


func test_blackmail_always_costs_honor():
	var result := IntimidationSystem.resolve_blackmail(10, 25, 5.0, 4, 0)
	assert_eq(result["honor_loss"], -0.3)
	assert_eq(result["infamy_gain"], 0.1)


func test_blackmail_tier1_secret_gives_3_free_raises():
	var result := IntimidationSystem.resolve_blackmail(20, 10, 2.0, 1, 0)
	# defender_total = 10 + 2 = 12, free_raises = 3, effective_roll = 20 + 15 = 35
	# margin = 35 - 12 = 23, favors = 23/5 = 4
	assert_true(result["success"])
	assert_eq(result["favors_extracted"], 4)


func test_blackmail_tier4_secret_no_free_raises():
	var result := IntimidationSystem.resolve_blackmail(20, 10, 2.0, 4, 0)
	# defender_total = 12, effective_roll = 20
	# margin = 20 - 12 = 8, favors = 8/5 = 1
	assert_true(result["success"])
	assert_eq(result["favors_extracted"], 1)


func test_blackmail_friend_gives_defense_bonus():
	var result := IntimidationSystem.resolve_blackmail(20, 10, 2.0, 3, 0, "friend")
	# defender_total = 10 + 2 + 5 = 17, free_raises = 1, effective_roll = 20 + 5 = 25
	# margin = 25 - 17 = 8, favors = 1
	assert_true(result["success"])
	assert_eq(result["favors_extracted"], 1)


func test_blackmail_enemy_gives_defense_penalty():
	var result := IntimidationSystem.resolve_blackmail(15, 10, 2.0, 3, 0, "enemy")
	# defender_total = 10 + 2 - 5 = 7, free_raises = 1, effective_roll = 15 + 5 = 20
	# margin = 20 - 7 = 13, favors = 2
	assert_true(result["success"])
	assert_eq(result["favors_extracted"], 2)


# -- Private intimidation tests -----------------------------------------------

func test_private_in_person_success():
	var result := IntimidationSystem.resolve_private_intimidation(30, 15, 3.0, false, 1)
	# defender_total = 15 + 3 = 18, tn = 18 + 5 = 23
	assert_true(result["success"])
	assert_eq(result["tn_increase"], 15)  # 10 + 5*1


func test_private_in_person_with_raises():
	var result := IntimidationSystem.resolve_private_intimidation(40, 15, 3.0, false, 3)
	# tn = 18 + 15 = 33
	assert_true(result["success"])
	assert_eq(result["tn_increase"], 25)  # 10 + 5*3


func test_private_in_person_failure():
	var result := IntimidationSystem.resolve_private_intimidation(10, 20, 4.0, false, 0)
	# defender_total = 24, tn = 24
	assert_false(result["success"])
	assert_eq(result["tn_increase"], 0)


func test_private_by_letter():
	var result := IntimidationSystem.resolve_private_intimidation(20, 0, 3.0, true)
	# tn = 15 + 3 = 18
	assert_true(result["success"])
	assert_eq(result["tn_increase"], 5)


func test_private_by_letter_failure():
	var result := IntimidationSystem.resolve_private_intimidation(10, 0, 8.0, true)
	# tn = 15 + 8 = 23
	assert_false(result["success"])
	assert_eq(result["tn_increase"], 0)


func test_private_costs_honor():
	var result := IntimidationSystem.resolve_private_intimidation(30, 15, 3.0, false, 0)
	assert_eq(result["honor_loss"], -0.2)
	assert_eq(result["infamy_gain"], 0.05)


# -- Public intimidation tests ------------------------------------------------

func test_public_intimidation_success():
	var result := IntimidationSystem.resolve_public_intimidation(30, 15, 3.0, 1, [10, 11, 12])
	# defender_total = 18, tn = 18 + 5 = 23
	assert_true(result["success"])
	assert_eq(result["tn_increase"], 15)  # 10 + 5*1
	assert_eq(result["witnesses"], [10, 11, 12])
	assert_eq(result["witness_disposition_loss"], -2)


func test_public_intimidation_failure():
	var result := IntimidationSystem.resolve_public_intimidation(10, 20, 5.0, 0, [10])
	assert_false(result["success"])
	assert_eq(result["tn_increase"], 0)


func test_public_costs_honor_and_infamy():
	var result := IntimidationSystem.resolve_public_intimidation(30, 15, 3.0, 0, [])
	assert_eq(result["honor_loss"], -0.3)
	assert_eq(result["infamy_gain"], 0.1)


func test_public_compliance_active_on_success():
	var result := IntimidationSystem.resolve_public_intimidation(30, 15, 3.0)
	assert_true(result["compliance_active"])


# -- Compliance tests ---------------------------------------------------------

func test_pushback_tn():
	assert_eq(IntimidationSystem.get_pushback_tn(3), 18)
	assert_eq(IntimidationSystem.get_pushback_tn(5), 20)


func test_compliance_ends_at_friend_disposition():
	assert_true(IntimidationSystem.can_compliance_end(51))
	assert_false(IntimidationSystem.can_compliance_end(50))


# -- Disposition defense modifier tests ---------------------------------------

func test_neutral_no_bonus():
	var result := IntimidationSystem.resolve_blackmail(20, 15, 2.0, 3, 0, "neutral")
	# defender_total = 15 + 2 = 17
	assert_true(result["success"])


func test_ally_gives_defense_bonus():
	var result := IntimidationSystem.resolve_blackmail(20, 15, 2.0, 3, 0, "ally")
	# defender_total = 15 + 2 + 5 = 22, free_raises = 1, effective_roll = 20 + 5 = 25
	assert_true(result["success"])


func test_bitter_enemy_gives_penalty():
	var result := IntimidationSystem.resolve_blackmail(15, 15, 2.0, 3, 0, "bitter_enemy")
	# defender_total = 15 + 2 - 5 = 12, free_raises = 1, effective_roll = 15 + 5 = 20
	assert_true(result["success"])
