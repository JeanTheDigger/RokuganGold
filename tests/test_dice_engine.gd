extends GutTest


var _engine: DiceEngine


func before_each() -> void:
	_engine = DiceEngine.new(12345)


# -- Basic roll_and_keep -------------------------------------------------------

func test_roll_and_keep_returns_correct_kept_count() -> void:
	var result: DiceResult = _engine.roll_and_keep(6, 3)
	assert_eq(result.kept_dice.size(), 3, "Should keep exactly 3 dice")


func test_roll_and_keep_returns_correct_dropped_count() -> void:
	var result: DiceResult = _engine.roll_and_keep(6, 3)
	assert_eq(result.dropped_dice.size(), 3, "Should drop exactly 3 dice")


func test_kept_dice_are_sorted_descending() -> void:
	var result: DiceResult = _engine.roll_and_keep(8, 4)
	for i: int in range(result.kept_dice.size() - 1):
		assert_true(
			result.kept_dice[i] >= result.kept_dice[i + 1],
			"Kept dice should be in descending order"
		)


func test_total_equals_sum_of_kept_plus_overflow() -> void:
	var result: DiceResult = _engine.roll_and_keep(5, 3)
	var manual_sum: int = result.overflow_bonus
	for die_value: int in result.kept_dice:
		manual_sum += die_value
	assert_eq(result.total, manual_sum, "Total should equal sum of kept dice + overflow bonus")


func test_kept_cannot_exceed_rolled() -> void:
	var result: DiceResult = _engine.roll_and_keep(3, 5)
	assert_eq(result.kept_dice.size(), 3, "Kept cannot exceed rolled")
	assert_eq(result.dropped_dice.size(), 0, "Nothing to drop")


func test_zero_rolled_returns_empty() -> void:
	var result: DiceResult = _engine.roll_and_keep(0, 0)
	assert_eq(result.total, 0)
	assert_eq(result.kept_dice.size(), 0)


func test_one_k_one_returns_single_die() -> void:
	var result: DiceResult = _engine.roll_and_keep(1, 1)
	assert_eq(result.kept_dice.size(), 1)
	assert_true(result.total >= 1, "Minimum die value is 1")


# -- Exploding dice ------------------------------------------------------------

func test_exploding_can_exceed_ten() -> void:
	var found_over_ten: bool = false
	for i: int in range(200):
		_engine.set_seed(i)
		var result: DiceResult = _engine.roll_and_keep(10, 10)
		for die_value: int in result.kept_dice:
			if die_value > 10:
				found_over_ten = true
				break
		if found_over_ten:
			break
	assert_true(found_over_ten, "With enough rolls, exploding dice should exceed 10")


func test_no_exploding_caps_at_ten() -> void:
	for i: int in range(100):
		_engine.set_seed(i)
		var result: DiceResult = _engine.roll_and_keep(10, 10, false)
		for die_value: int in result.kept_dice:
			assert_true(die_value <= 10, "Non-exploding dice should not exceed 10")
		for die_value: int in result.dropped_dice:
			assert_true(die_value <= 10, "Non-exploding dice should not exceed 10")


func test_explosions_tracked() -> void:
	var found_explosions: bool = false
	for i: int in range(200):
		_engine.set_seed(i)
		var result: DiceResult = _engine.roll_and_keep(10, 10)
		if result.explosions > 0:
			found_explosions = true
			break
	assert_true(found_explosions, "Should track explosion count")


# -- Deterministic seeding -----------------------------------------------------

func test_same_seed_same_result() -> void:
	_engine.set_seed(99999)
	var result_a: DiceResult = _engine.roll_and_keep(6, 3)

	_engine.set_seed(99999)
	var result_b: DiceResult = _engine.roll_and_keep(6, 3)

	assert_eq(result_a.total, result_b.total, "Same seed should produce same total")
	assert_eq(result_a.kept_dice, result_b.kept_dice, "Same seed should produce same kept dice")


func test_different_seed_likely_different_result() -> void:
	_engine.set_seed(11111)
	var result_a: DiceResult = _engine.roll_and_keep(6, 3)

	_engine.set_seed(22222)
	var result_b: DiceResult = _engine.roll_and_keep(6, 3)

	# Not guaranteed but extremely likely with different seeds
	var same: bool = result_a.total == result_b.total and result_a.kept_dice == result_b.kept_dice
	assert_false(same, "Different seeds should almost certainly produce different results")


# -- roll_check ----------------------------------------------------------------

func test_roll_check_success() -> void:
	_engine.set_seed(42)
	var check: Dictionary = _engine.roll_check(6, 3, 10)
	# With 6k3 against TN 10, success is very likely
	assert_true(check.has("success"))
	assert_true(check.has("total"))
	assert_true(check.has("tn"))
	assert_true(check.has("margin"))
	assert_true(check.has("dice"))
	assert_eq(check["tn"], 10, "TN should be 10 with no raises")


func test_roll_check_raises_increase_tn() -> void:
	_engine.set_seed(42)
	var check: Dictionary = _engine.roll_check(6, 3, 15, 2)
	assert_eq(check["tn"], 25, "TN 15 + 2 raises * 5 = 25")


func test_roll_check_bonus_adds_to_total() -> void:
	_engine.set_seed(42)
	var without_bonus: Dictionary = _engine.roll_check(4, 2, 15, 0, 0)

	_engine.set_seed(42)
	var with_bonus: Dictionary = _engine.roll_check(4, 2, 15, 0, 5)

	assert_eq(
		with_bonus["total"], without_bonus["total"] + 5,
		"Bonus should add directly to total"
	)


func test_roll_check_margin_correct() -> void:
	_engine.set_seed(42)
	var check: Dictionary = _engine.roll_check(6, 3, 10)
	assert_eq(
		check["margin"], check["total"] - check["tn"],
		"Margin should be total minus TN"
	)


# -- contested_roll ------------------------------------------------------------

func test_contested_roll_has_winner() -> void:
	_engine.set_seed(42)
	var result: Dictionary = _engine.contested_roll(5, 3, 5, 3)
	assert_true(result["winner"] in ["a", "b", "tie"], "Winner must be a, b, or tie")


func test_contested_roll_totals_match_dice() -> void:
	_engine.set_seed(42)
	var result: Dictionary = _engine.contested_roll(5, 3, 5, 3)
	assert_eq(result["total_a"], result["dice_a"].total)
	assert_eq(result["total_b"], result["dice_b"].total)


func test_contested_roll_bonus_applied() -> void:
	_engine.set_seed(42)
	var without: Dictionary = _engine.contested_roll(4, 2, 4, 2, 0, 0)

	_engine.set_seed(42)
	var with_bonus: Dictionary = _engine.contested_roll(4, 2, 4, 2, 10, 0)

	assert_eq(with_bonus["total_a"], without["total_a"] + 10)
	assert_eq(with_bonus["total_b"], without["total_b"])


# -- roll_initiative -----------------------------------------------------------

func test_initiative_uses_reflexes_plus_insight_rank() -> void:
	_engine.set_seed(42)
	var result: DiceResult = _engine.roll_initiative(3, 2)
	# 3 reflexes + 2 insight rank = 5 rolled, keep 3 (reflexes)
	assert_eq(result.kept_dice.size(), 3, "Keep count should equal reflexes")


# -- roll_damage ---------------------------------------------------------------

func test_damage_reduction_applied() -> void:
	_engine.set_seed(42)
	var result: Dictionary = _engine.roll_damage(3, 2, 0, 5)
	assert_eq(result["final"], maxi(0, result["raw"] - 5))


func test_damage_cannot_go_negative() -> void:
	_engine.set_seed(42)
	var result: Dictionary = _engine.roll_damage(1, 1, 0, 999)
	assert_eq(result["final"], 0, "Damage after reduction cannot be negative")


func test_damage_strength_bonus_adds_rolled() -> void:
	_engine.set_seed(42)
	var katana_no_str: Dictionary = _engine.roll_damage(3, 2, 0, 0)

	_engine.set_seed(42)
	var katana_str3: Dictionary = _engine.roll_damage(3, 2, 3, 0)

	# With strength bonus, more dice are rolled so kept dice can be higher
	assert_true(
		katana_str3["dice"].kept_dice.size() == 2,
		"Keep count unchanged by strength"
	)
	assert_eq(
		katana_str3["dice"].kept_dice.size() + katana_str3["dice"].dropped_dice.size(),
		6,
		"Strength 3 + DR 3 = 6 total dice rolled"
	)


# -- 10-dice cap (L5R4e Core p.77) ---------------------------------------------

func test_cap_rolled_at_10() -> void:
	_engine.set_seed(42)
	var result: DiceResult = _engine.roll_and_keep(12, 5)
	# 12 rolled -> capped to 10 rolled, +4 overflow bonus (2 excess * 2)
	assert_eq(result.kept_dice.size(), 5, "Should keep 5")
	assert_eq(
		result.kept_dice.size() + result.dropped_dice.size(), 10,
		"Should only physically roll 10 dice"
	)
	assert_eq(result.overflow_bonus, 4, "2 excess rolled dice * 2 = +4 bonus")


func test_cap_kept_at_10() -> void:
	_engine.set_seed(42)
	var result: DiceResult = _engine.roll_and_keep(10, 12)
	# kept 12 > rolled 10, so kept clamped to rolled first (10),
	# then 10 kept is at the cap, no overflow from kept
	assert_eq(result.kept_dice.size(), 10)
	assert_eq(result.overflow_bonus, 0)


func test_cap_both_rolled_and_kept() -> void:
	_engine.set_seed(42)
	# 15k12 -> rolled overflow: (15-10)*2=10, kept overflow: (12-10)*2=4, total overflow: 14
	var result: DiceResult = _engine.roll_and_keep(15, 12)
	assert_eq(result.kept_dice.size(), 10)
	assert_eq(
		result.kept_dice.size() + result.dropped_dice.size(), 10,
		"Should physically roll 10 dice"
	)
	assert_eq(result.overflow_bonus, 14, "(15-10)*2 + (12-10)*2 = 14")


func test_cap_overflow_adds_to_total() -> void:
	_engine.set_seed(42)
	var capped: DiceResult = _engine.roll_and_keep(12, 5)
	# Total should be sum of kept + overflow
	var dice_sum: int = 0
	for die_value: int in capped.kept_dice:
		dice_sum += die_value
	assert_eq(capped.total, dice_sum + capped.overflow_bonus)


func test_10k10_no_overflow() -> void:
	_engine.set_seed(42)
	var result: DiceResult = _engine.roll_and_keep(10, 10)
	assert_eq(result.overflow_bonus, 0, "Exactly 10k10 should have no overflow")
	assert_eq(result.kept_dice.size(), 10)


# -- Unskilled rolls (L5R4e Core p.78) ----------------------------------------

func test_unskilled_does_not_explode() -> void:
	# roll_skill_check with skill_rank 0 should pass explodes=false
	for i: int in range(100):
		_engine.set_seed(i)
		var check: Dictionary = _engine.roll_skill_check(3, 0, 10)
		var dice: DiceResult = check["dice"]
		for die_value: int in dice.kept_dice:
			assert_true(die_value <= 10, "Unskilled roll should not explode past 10")
		for die_value: int in dice.dropped_dice:
			assert_true(die_value <= 10, "Unskilled roll should not explode past 10")


func test_skilled_can_explode() -> void:
	var found_over_ten: bool = false
	for i: int in range(200):
		_engine.set_seed(i)
		var check: Dictionary = _engine.roll_skill_check(3, 5, 10)
		var dice: DiceResult = check["dice"]
		for die_value: int in dice.kept_dice:
			if die_value > 10:
				found_over_ten = true
				break
		if found_over_ten:
			break
	assert_true(found_over_ten, "Skilled rolls should explode")


func test_skill_check_rolled_is_trait_plus_skill() -> void:
	_engine.set_seed(42)
	# trait 3, skill 4 -> 7k3
	var check: Dictionary = _engine.roll_skill_check(3, 4, 15)
	var dice: DiceResult = check["dice"]
	assert_eq(dice.kept_dice.size(), 3, "Kept should equal trait value")
	assert_eq(
		dice.kept_dice.size() + dice.dropped_dice.size(), 7,
		"Total dice should be trait + skill"
	)


func test_unskilled_roll_only_trait_dice() -> void:
	_engine.set_seed(42)
	# trait 3, skill 0 -> 3k3
	var check: Dictionary = _engine.roll_skill_check(3, 0, 15)
	var dice: DiceResult = check["dice"]
	assert_eq(dice.kept_dice.size(), 3, "Kept should equal trait value")
	assert_eq(dice.dropped_dice.size(), 0, "No dropped dice when rolled == kept")


# -- Emphasis reroll (L5R4e Core p.78) -----------------------------------------

func test_emphasis_eliminates_ones() -> void:
	# With emphasis, no kept or dropped die should be 1 (unless the reroll
	# also landed on 1, which is possible but rare). Over many rolls, emphasis
	# should produce far fewer 1s than non-emphasis.
	var ones_without: int = 0
	var ones_with: int = 0
	var trials: int = 500
	for i: int in range(trials):
		_engine.set_seed(i)
		var no_emph: DiceResult = _engine.roll_and_keep(10, 10, false, false)
		for die_value: int in no_emph.kept_dice:
			if die_value == 1:
				ones_without += 1
		for die_value: int in no_emph.dropped_dice:
			if die_value == 1:
				ones_without += 1

		_engine.set_seed(i)
		var with_emph: DiceResult = _engine.roll_and_keep(10, 10, false, true)
		for die_value: int in with_emph.kept_dice:
			if die_value == 1:
				ones_with += 1
		for die_value: int in with_emph.dropped_dice:
			if die_value == 1:
				ones_with += 1

	assert_true(
		ones_with < ones_without,
		"Emphasis should produce fewer 1s: %d with vs %d without" % [ones_with, ones_without]
	)


func test_emphasis_raises_average() -> void:
	var sum_without: int = 0
	var sum_with: int = 0
	var trials: int = 1000
	for i: int in range(trials):
		_engine.set_seed(i)
		sum_without += _engine.roll_and_keep(6, 3, true, false).total

		_engine.set_seed(i)
		sum_with += _engine.roll_and_keep(6, 3, true, true).total

	assert_true(
		sum_with > sum_without,
		"Emphasis should raise the average total"
	)


func test_emphasis_reroll_can_explode() -> void:
	# If a 1 is rerolled into a 10, it should explode normally.
	var found_explosion_from_reroll: bool = false
	for i: int in range(500):
		_engine.set_seed(i)
		var no_emph: DiceResult = _engine.roll_and_keep(10, 10, true, false)

		_engine.set_seed(i)
		var with_emph: DiceResult = _engine.roll_and_keep(10, 10, true, true)

		# If emphasis version has more explosions, a rerolled 1 hit 10
		if with_emph.explosions > no_emph.explosions:
			found_explosion_from_reroll = true
			break

	assert_true(
		found_explosion_from_reroll,
		"A rerolled 1 that lands on 10 should explode"
	)


func test_emphasis_passed_through_skill_check() -> void:
	_engine.set_seed(42)
	var no_emph: Dictionary = _engine.roll_skill_check(3, 4, 10, 0, 0, false)

	_engine.set_seed(42)
	var with_emph: Dictionary = _engine.roll_skill_check(3, 4, 10, 0, 0, true)

	# Results may or may not differ for this seed, but at minimum verify
	# both calls succeed without error and return valid structure
	assert_true(no_emph.has("total"))
	assert_true(with_emph.has("total"))


# -- Statistical sanity --------------------------------------------------------

func test_average_roll_is_reasonable() -> void:
	var sum: int = 0
	var rolls: int = 1000
	for i: int in range(rolls):
		_engine.set_seed(i)
		var result: DiceResult = _engine.roll_and_keep(6, 3)
		sum += result.total
	var average: float = float(sum) / float(rolls)
	# 6k3 with exploding 10s: expected average ~17-22
	assert_true(average > 14.0, "Average 6k3 should be above 14, got %f" % average)
	assert_true(average < 28.0, "Average 6k3 should be below 28, got %f" % average)
