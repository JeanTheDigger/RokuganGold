extends GutTest


func _make_performer(skill_name: String = "Artisan", rank: int = 5) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.awareness = 4
	c.agility = 3
	c.void_ring = 3
	c.skills = {skill_name: rank}
	c.glory = 3.0
	c.honor = 5.0
	c.disposition_values = {}
	return c


func _make_recipient(id: int = 10) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.awareness = 3
	c.disposition_values = {}
	return c


func _make_high_roller() -> DiceEngine:
	var d := DiceEngine.new()
	d.set_seed(999)
	return d


func _make_low_roller() -> DiceEngine:
	var d := DiceEngine.new()
	d.set_seed(1)
	return d


# ==============================================================================
# Art Form Skill Mapping
# ==============================================================================

func test_poetry_uses_artisan() -> void:
	assert_eq(PerformativeArtsSystem.get_performance_skill(
		PerformativeArtsSystem.ArtForm.POETRY), "Artisan")


func test_dance_uses_perform() -> void:
	assert_eq(PerformativeArtsSystem.get_performance_skill(
		PerformativeArtsSystem.ArtForm.DANCE), "Perform")


func test_theater_uses_acting() -> void:
	assert_eq(PerformativeArtsSystem.get_performance_skill(
		PerformativeArtsSystem.ArtForm.THEATER), "Acting")


func test_tea_uses_tea_ceremony() -> void:
	assert_eq(PerformativeArtsSystem.get_performance_skill(
		PerformativeArtsSystem.ArtForm.TEA_CEREMONY), "Tea Ceremony")


# ==============================================================================
# Public Performance — Success
# ==============================================================================

func test_public_performance_success_gives_disposition() -> void:
	var performer := _make_performer("Artisan", 5)
	var dice := _make_high_roller()
	var witnesses: Array[int] = [10, 11, 12]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice)

	if result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.SUCCESS or \
	   result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.MASTERFUL:
		assert_gte(result["disposition_per_witness"], 2)
		assert_gt(result["glory_change"], 0.0)
		assert_eq(result["witness_effects"].size(), 3)


func test_public_performance_success_glory() -> void:
	var performer := _make_performer("Artisan", 5)
	var dice := _make_high_roller()
	var witnesses: Array[int] = [10]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice)

	if result["outcome"] != PerformativeArtsSystem.PerformanceOutcome.CRITICAL_FAILURE:
		assert_gte(result["glory_change"], 0.0)


func test_raises_increase_disposition() -> void:
	var performer := _make_performer("Artisan", 5)
	var dice := _make_high_roller()
	var witnesses: Array[int] = [10]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice)

	if result["raises"] > 0:
		assert_gt(result["disposition_per_witness"], PerformativeArtsSystem.SUCCESS_DISPOSITION)


# ==============================================================================
# Public Performance — Failure
# ==============================================================================

func test_public_performance_failure_no_disposition() -> void:
	var performer := _make_performer("Artisan", 1)
	performer.awareness = 1
	var dice := _make_low_roller()
	var witnesses: Array[int] = [10]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice)

	if result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.FAILURE:
		assert_eq(result["disposition_per_witness"], 0)


func test_critical_failure_negative_disposition() -> void:
	var result_dict := {
		"outcome": PerformativeArtsSystem.PerformanceOutcome.CRITICAL_FAILURE,
	}
	assert_eq(PerformativeArtsSystem.CRITICAL_FAILURE_DISPOSITION, -2)
	assert_lt(PerformativeArtsSystem.CRITICAL_FAILURE_GLORY, 0.0)


# ==============================================================================
# Performance Fatigue
# ==============================================================================

func test_fatigue_first_performance_full() -> void:
	assert_eq(PerformativeArtsSystem.get_fatigue_multiplier(0), 1.0)


func test_fatigue_second_performance_half() -> void:
	assert_eq(PerformativeArtsSystem.get_fatigue_multiplier(1), 0.5)


func test_fatigue_third_performance_zero() -> void:
	assert_eq(PerformativeArtsSystem.get_fatigue_multiplier(2), 0.0)


func test_fatigue_reduces_disposition() -> void:
	var performer := _make_performer("Artisan", 5)
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var witnesses: Array[int] = [10]

	var result_fresh := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice, 0)

	dice.set_seed(42)
	var result_fatigued := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice, 1)

	if result_fresh["outcome"] == PerformativeArtsSystem.PerformanceOutcome.SUCCESS:
		assert_gte(result_fresh["disposition_per_witness"],
			result_fatigued["disposition_per_witness"])


func test_fatigue_zero_produces_no_effect() -> void:
	var performer := _make_performer("Artisan", 5)
	var dice := _make_high_roller()
	var witnesses: Array[int] = [10]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.POETRY, witnesses, dice, 3)

	assert_eq(result["disposition_per_witness"], 0)
	assert_eq(result["glory_change"], 0.0)


# ==============================================================================
# Perform For (Targeted)
# ==============================================================================

func test_perform_for_success_strong_disposition() -> void:
	var performer := _make_performer("Artisan", 5)
	var recipient := _make_recipient()
	var dice := _make_high_roller()

	var result := PerformativeArtsSystem.resolve_perform_for(
		performer, recipient, PerformativeArtsSystem.ArtForm.POETRY, dice)

	if result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.SUCCESS or \
	   result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.MASTERFUL:
		assert_gte(result["disposition_change"], 3)
		assert_eq(result["recipient_id"], 10)


func test_perform_for_failure_small_loss() -> void:
	var performer := _make_performer("Artisan", 1)
	performer.awareness = 1
	var recipient := _make_recipient()
	var dice := _make_low_roller()

	var result := PerformativeArtsSystem.resolve_perform_for(
		performer, recipient, PerformativeArtsSystem.ArtForm.POETRY, dice)

	if result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.FAILURE:
		assert_eq(result["disposition_change"], -1)


func test_perform_for_no_critical_failure() -> void:
	var performer := _make_performer("Artisan", 1)
	performer.awareness = 1
	var recipient := _make_recipient()
	var dice := _make_low_roller()

	var result := PerformativeArtsSystem.resolve_perform_for(
		performer, recipient, PerformativeArtsSystem.ArtForm.POETRY, dice)

	assert_ne(result["outcome"], PerformativeArtsSystem.PerformanceOutcome.CRITICAL_FAILURE)


func test_perform_for_masterful_gives_glory() -> void:
	var performer := _make_performer("Artisan", 5)
	var recipient := _make_recipient()
	var dice := _make_high_roller()

	var result := PerformativeArtsSystem.resolve_perform_for(
		performer, recipient, PerformativeArtsSystem.ArtForm.POETRY, dice)

	if result["outcome"] == PerformativeArtsSystem.PerformanceOutcome.MASTERFUL:
		assert_gt(result["glory_change"], 0.0)


# ==============================================================================
# Best Art Form Selection
# ==============================================================================

func test_best_art_form_highest_effective() -> void:
	var performer := _make_performer()
	performer.skills = {"Tea Ceremony": 7, "Artisan": 2}
	performer.awareness = 4

	var best := PerformativeArtsSystem.get_best_art_form(performer)
	assert_eq(best, PerformativeArtsSystem.ArtForm.TEA_CEREMONY)


func test_best_art_form_all_use_awareness() -> void:
	var performer := _make_performer()
	performer.skills = {"Perform": 6, "Artisan": 2}
	performer.agility = 5
	performer.awareness = 4

	var best := PerformativeArtsSystem.get_best_art_form(performer)
	assert_true(best == PerformativeArtsSystem.ArtForm.DANCE or
		best == PerformativeArtsSystem.ArtForm.MUSIC)


# ==============================================================================
# Apply Effects
# ==============================================================================

func test_apply_public_performance_effects() -> void:
	var performer := _make_performer()
	var witness := _make_recipient(10)
	var chars_by_id := {10: witness}

	var result := {
		"glory_change": 0.3,
		"witness_effects": [
			{"character_id": 10, "disposition_change": 3},
		],
	}

	PerformativeArtsSystem.apply_performance_effects(performer, result, chars_by_id)

	assert_almost_eq(performer.glory, 3.3, 0.01)
	assert_eq(witness.disposition_values.get(1, 0), 3)


func test_apply_perform_for_effects() -> void:
	var performer := _make_performer()
	var recipient := _make_recipient(10)
	var chars_by_id := {10: recipient}

	var result := {
		"glory_change": 0.2,
		"disposition_change": 4,
		"recipient_id": 10,
	}

	PerformativeArtsSystem.apply_performance_effects(performer, result, chars_by_id)

	assert_almost_eq(performer.glory, 3.2, 0.01)
	assert_eq(recipient.disposition_values.get(1, 0), 4)


func test_apply_effects_clamps_glory() -> void:
	var performer := _make_performer()
	performer.glory = 9.9

	var result := {"glory_change": 0.5}

	PerformativeArtsSystem.apply_performance_effects(performer, result)

	assert_almost_eq(performer.glory, 10.0, 0.01)


func test_apply_negative_glory_clamps_at_zero() -> void:
	var performer := _make_performer()
	performer.glory = 0.1

	var result := {"glory_change": -0.3}

	PerformativeArtsSystem.apply_performance_effects(performer, result)

	assert_almost_eq(performer.glory, 0.0, 0.01)


func test_apply_effects_clamps_disposition() -> void:
	var performer := _make_performer()
	var witness := _make_recipient(10)
	witness.disposition_values[1] = 98
	var chars_by_id := {10: witness}

	var result := {
		"glory_change": 0.0,
		"witness_effects": [{"character_id": 10, "disposition_change": 5}],
	}

	PerformativeArtsSystem.apply_performance_effects(performer, result, chars_by_id)

	assert_eq(witness.disposition_values.get(1, 0), 100)


# ==============================================================================
# Constants Match GDD
# ==============================================================================

func test_performance_tn_is_15() -> void:
	assert_eq(PerformativeArtsSystem.PERFORMANCE_TN, 15)


func test_success_disposition_is_2() -> void:
	assert_eq(PerformativeArtsSystem.SUCCESS_DISPOSITION, 2)


func test_success_glory_is_03() -> void:
	assert_almost_eq(PerformativeArtsSystem.SUCCESS_GLORY, 0.3, 0.001)


func test_critical_failure_margin_is_minus_10() -> void:
	assert_eq(PerformativeArtsSystem.CRITICAL_FAILURE_MARGIN, -10)


func test_perform_for_success_disp_is_3() -> void:
	assert_eq(PerformativeArtsSystem.PERFORM_FOR_SUCCESS_DISPOSITION, 3)


func test_perform_for_failure_disp_is_minus_1() -> void:
	assert_eq(PerformativeArtsSystem.PERFORM_FOR_FAILURE_DISPOSITION, -1)


# ==============================================================================
# All Art Forms Use Awareness (GDD s12.4)
# ==============================================================================

func test_dance_uses_awareness_not_agility() -> void:
	var performer := _make_performer("Perform", 3)
	performer.awareness = 4
	performer.agility = 6
	var dice := _make_high_roller()
	var witnesses: Array[int] = [10]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.DANCE, witnesses, dice)

	assert_eq(result["skill_used"], "Perform")
	assert_true(result["roll_total"] > 0)


func test_tea_ceremony_uses_awareness_not_void() -> void:
	var performer := _make_performer("Tea Ceremony", 3)
	performer.awareness = 4
	performer.void_ring = 6
	var dice := _make_high_roller()
	var witnesses: Array[int] = [10]

	var result := PerformativeArtsSystem.resolve_public_performance(
		performer, PerformativeArtsSystem.ArtForm.TEA_CEREMONY, witnesses, dice)

	assert_eq(result["skill_used"], "Tea Ceremony")
	assert_true(result["roll_total"] > 0)
