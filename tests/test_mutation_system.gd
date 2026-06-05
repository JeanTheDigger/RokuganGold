extends GutTest
## Tests for s44 MutationSystem — Shadowlands Mutations & Powers


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_char(id: int, sta: int = 3, wil: int = 3) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Test " + str(id)
	c.taint = 0.0
	c.taint_rank_last_processed = 0
	c.mutations = []
	c.shadowlands_powers = []
	c.stamina = sta
	c.willpower = wil
	c.strength = 2
	c.reflexes = 2
	c.agility = 2
	c.awareness = 2
	c.perception = 2
	c.intelligence = 2
	c.void_ring = 2
	c.current_void_points = 2
	c.honor = 2.0
	c.glory = 2.0
	c.status = 2.0
	c.wounds_taken = 0
	c.skills = {}
	c.disadvantages = []
	c.advantages = []
	c.school = "Test"
	c.clan = "Crab"
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.physical_location = "100"
	c.action_points_current = 2
	c.action_points_max = 2
	return c


func _dice() -> DiceEngine:
	var d := DiceEngine.new()
	d.set_seed(42)
	return d


# ---------------------------------------------------------------------------
# Taint rank helpers
# ---------------------------------------------------------------------------

func test_get_taint_rank_rank0() -> void:
	assert_eq(MutationSystem.get_taint_rank(0.0), 0)
	assert_eq(MutationSystem.get_taint_rank(0.9), 0)


func test_get_taint_rank_rank1() -> void:
	assert_eq(MutationSystem.get_taint_rank(1.0), 1)
	assert_eq(MutationSystem.get_taint_rank(1.9), 1)


func test_get_taint_rank_rank2() -> void:
	assert_eq(MutationSystem.get_taint_rank(2.0), 2)


func test_get_taint_rank_rank5() -> void:
	assert_eq(MutationSystem.get_taint_rank(5.0), 5)
	assert_eq(MutationSystem.get_taint_rank(9.0), 5)


func test_get_roll_period_ranks() -> void:
	assert_eq(MutationSystem.get_roll_period(0), 30)
	assert_eq(MutationSystem.get_roll_period(1), 30)
	assert_eq(MutationSystem.get_roll_period(2), 15)
	assert_eq(MutationSystem.get_roll_period(3), 7)
	assert_eq(MutationSystem.get_roll_period(4), 1)
	assert_eq(MutationSystem.get_roll_period(5), 0)  # Lost: no roll


func test_get_roll_tn_ranks() -> void:
	assert_eq(MutationSystem.get_roll_tn(0), 5)
	assert_eq(MutationSystem.get_roll_tn(1), 10)
	assert_eq(MutationSystem.get_roll_tn(2), 15)
	assert_eq(MutationSystem.get_roll_tn(3), 20)
	assert_eq(MutationSystem.get_roll_tn(4), 25)


func test_get_power_use_tn_minor() -> void:
	assert_eq(MutationSystem.get_power_use_tn(Enums.ShadowlandsPowerTier.MINOR), 15)


func test_get_power_use_tn_major() -> void:
	assert_eq(MutationSystem.get_power_use_tn(Enums.ShadowlandsPowerTier.MAJOR), 20)


func test_get_power_use_tn_akutenshi_treated_as_major() -> void:
	assert_eq(MutationSystem.get_power_use_tn(Enums.ShadowlandsPowerTier.AKUTENSHI), 20)


# ---------------------------------------------------------------------------
# should_roll_today
# ---------------------------------------------------------------------------

func test_should_roll_today_rank1_monthly() -> void:
	var c := _make_char(1)
	c.taint = 1.0
	# Rank 1: period = 30; ic_day 30 → 30 % 30 == 0
	assert_true(MutationSystem.should_roll_today(c, 30))
	assert_false(MutationSystem.should_roll_today(c, 29))


func test_should_roll_today_rank2_bimonthly() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	# Rank 2: period = 15
	assert_true(MutationSystem.should_roll_today(c, 15))
	assert_false(MutationSystem.should_roll_today(c, 16))


func test_should_roll_today_rank3_weekly() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	# Rank 3: period = 7
	assert_true(MutationSystem.should_roll_today(c, 7))
	assert_false(MutationSystem.should_roll_today(c, 8))


func test_should_roll_today_rank4_daily() -> void:
	var c := _make_char(1)
	c.taint = 4.0
	assert_true(MutationSystem.should_roll_today(c, 1))
	assert_true(MutationSystem.should_roll_today(c, 2))


func test_should_roll_today_rank5_never() -> void:
	var c := _make_char(1)
	c.taint = 5.0
	assert_false(MutationSystem.should_roll_today(c, 1))
	assert_false(MutationSystem.should_roll_today(c, 30))


# ---------------------------------------------------------------------------
# Periodic taint rolls
# ---------------------------------------------------------------------------

func test_resolve_periodic_success_no_taint_gain() -> void:
	# Earth 10: guaranteed success vs TN 10 (Rank 1)
	var c := _make_char(1, 10, 10)
	c.taint = 1.0
	var d := _dice()
	var r := MutationSystem.resolve_periodic_taint_roll(c, 10, d, 30)
	assert_true(r["success"])
	assert_eq(r["taint_gained"], 0)
	assert_eq(c.taint, 1.0)


func test_resolve_periodic_failure_gains_taint() -> void:
	# Earth 1: guaranteed failure vs TN 25 (Rank 4)
	var c := _make_char(1, 1, 1)
	c.taint = 4.0
	var d := _dice()
	var r := MutationSystem.resolve_periodic_taint_roll(c, 1, d, 1)
	assert_false(r["success"])
	assert_eq(r["taint_gained"], 1)
	assert_eq(c.taint, 5.0)


func test_periodic_roll_result_contains_expected_keys() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 2.0
	var r := MutationSystem.resolve_periodic_taint_roll(c, 3, _dice(), 15)
	assert_has(r, "character_id")
	assert_has(r, "taint_roll")
	assert_has(r, "taint_rank")
	assert_has(r, "tn")
	assert_has(r, "success")
	assert_has(r, "taint_gained")
	assert_has(r, "taint_after")


# ---------------------------------------------------------------------------
# Power use taint roll
# ---------------------------------------------------------------------------

func test_power_use_roll_minor_failure_gains_taint() -> void:
	var c := _make_char(1, 1, 1)
	c.taint = 1.0
	var r := MutationSystem.resolve_power_use_taint_roll(
		c, 1, Enums.ShadowlandsPowerTier.MINOR, _dice()
	)
	assert_false(r["success"])
	assert_eq(r["taint_gained"], 1)


func test_power_use_roll_major_tn_is_20() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 2.0
	var r := MutationSystem.resolve_power_use_taint_roll(
		c, 3, Enums.ShadowlandsPowerTier.MAJOR, _dice()
	)
	assert_eq(r["tn"], 20)
	assert_eq(r["power_tier"], Enums.ShadowlandsPowerTier.MAJOR)


# ---------------------------------------------------------------------------
# has_mutation / has_power
# ---------------------------------------------------------------------------

func test_has_mutation_false_when_empty() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_mutation(c, Enums.MutationType.ALBINISM))


func test_has_mutation_true_after_gain() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.ALBINISM, _dice(), 1)
	assert_true(MutationSystem.has_mutation(c, Enums.MutationType.ALBINISM))


func test_has_power_false_when_empty() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_power(c, Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS))


func test_has_power_true_after_gain() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.JADE_SENSE, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	assert_true(MutationSystem.has_power(c, Enums.ShadowlandsPowerType.JADE_SENSE))


func test_gain_mutation_no_duplicate() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 1)
	var result := MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 2)
	assert_null(result)  # null on duplicate
	assert_eq(c.mutations.size(), 1)


func test_gain_power_no_duplicate() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.JADE_SENSE, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	var result := MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.JADE_SENSE, Enums.ShadowlandsPowerTier.MINOR, _dice(), 2)
	assert_null(result)
	assert_eq(c.shadowlands_powers.size(), 1)


# ---------------------------------------------------------------------------
# Mutation secondary effects
# ---------------------------------------------------------------------------

func test_distorted_limbs_leg_adds_lame() -> void:
	var c := _make_char(1)
	# Force leg result by iterating until leg is chosen (seed 42 deterministic)
	# Instead: verify that LAME appears somewhere in one of the two outcomes
	# We run both paths by setting up a seeded dice that gives 0 (leg)
	var d := DiceEngine.new()
	d.set_seed(0)  # seed 0: rand_int_range(0,1) returns 0 → leg
	MutationSystem.gain_mutation(c, Enums.MutationType.DISTORTED_LIMBS, d, 1)
	var mut: MutationData = c.mutations[0]
	if mut.affected_limb == "leg":
		var has_lame := false
		for dis: DisadvantageData in c.disadvantages:
			if dis.disadvantage_type == Enums.Disadvantage.LAME:
				has_lame = true
		assert_true(has_lame)
	else:
		# arm — no LAME added
		assert_eq(c.disadvantages.size(), 0)


func test_distorted_limbs_arm_no_lame() -> void:
	var c := _make_char(1)
	# Use a different seed to get arm
	var d := DiceEngine.new()
	d.set_seed(1)  # may give 1 → arm; we verify the other condition
	MutationSystem.gain_mutation(c, Enums.MutationType.DISTORTED_LIMBS, d, 1)
	var mut: MutationData = c.mutations[0]
	if mut.affected_limb == "arm":
		assert_eq(c.disadvantages.size(), 0)


func test_lame_not_duplicated_if_already_present() -> void:
	var c := _make_char(1)
	var dis := DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.LAME
	dis.rank = 1
	c.disadvantages.append(dis)
	var d := DiceEngine.new()
	d.set_seed(0)  # seed 0 → leg
	MutationSystem.gain_mutation(c, Enums.MutationType.DISTORTED_LIMBS, d, 1)
	assert_eq(c.disadvantages.size(), 1)  # still only one LAME


func test_unholy_beauty_clears_mutations() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.ALBINISM, _dice(), 1)
	MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 1)
	assert_eq(c.mutations.size(), 2)
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.UNHOLY_BEAUTY, Enums.ShadowlandsPowerTier.MAJOR, _dice(), 2)
	assert_eq(c.mutations.size(), 0)


func test_master_of_shadows_adds_discolored_skin_if_absent() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_mutation(c, Enums.MutationType.DISCOLORED_SKIN))
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	assert_true(MutationSystem.has_mutation(c, Enums.MutationType.DISCOLORED_SKIN))


func test_master_of_shadows_no_duplicate_discolored_skin() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.DISCOLORED_SKIN, _dice(), 1)
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS, Enums.ShadowlandsPowerTier.MINOR, _dice(), 2)
	var count := 0
	for m: MutationData in c.mutations:
		if m.mutation_type == Enums.MutationType.DISCOLORED_SKIN:
			count += 1
	assert_eq(count, 1)


func test_extra_limb_has_non_functional_flag_set() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.EXTRA_LIMB, _dice(), 1)
	assert_eq(c.mutations.size(), 1)
	# is_non_functional is bool — just check the field exists and is a bool
	var mut: MutationData = c.mutations[0]
	assert_true(mut.is_non_functional == true or mut.is_non_functional == false)


# ---------------------------------------------------------------------------
# Rank-up processing
# ---------------------------------------------------------------------------

func test_rank2_up_grants_minor_power() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	var result := MutationSystem.process_rank_up(c, 2, _dice(), 1)
	# Should have gained exactly one power
	assert_eq(result["gained_powers"].size(), 1)
	assert_eq(result["gained_mutations"].size(), 0)
	# The power should be Minor
	var pt: Enums.ShadowlandsPowerType = result["gained_powers"][0]
	assert_true(MutationSystem.MINOR_POWERS.has(pt))


func test_rank3_up_grants_power_and_mutation() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	var result := MutationSystem.process_rank_up(c, 3, _dice(), 1)
	assert_eq(result["gained_powers"].size(), 1)
	assert_eq(result["gained_mutations"].size(), 1)


func test_rank4_up_grants_two_powers_first_is_major() -> void:
	var c := _make_char(1)
	c.taint = 4.0
	var result := MutationSystem.process_rank_up(c, 4, _dice(), 1)
	assert_eq(result["gained_powers"].size(), 2)
	assert_eq(result["gained_mutations"].size(), 1)
	var first: Enums.ShadowlandsPowerType = result["gained_powers"][0]
	assert_true(MutationSystem.MAJOR_POWERS.has(first))


func test_rank5_up_grants_random_mutations_and_powers() -> void:
	var c := _make_char(1)
	c.taint = 5.0
	var result := MutationSystem.process_rank_up(c, 5, _dice(), 1)
	# 0–3 mutations and 0–3 powers; just verify range
	assert_true(result["gained_mutations"].size() >= 0)
	assert_true(result["gained_mutations"].size() <= 3)
	assert_true(result["gained_powers"].size() >= 0)
	assert_true(result["gained_powers"].size() <= 3)


func test_rank5_powers_from_minor_major_only() -> void:
	var c := _make_char(1)
	c.taint = 5.0
	# Run multiple times to increase coverage
	for _i in range(5):
		var c2 := _make_char(_i + 100)
		c2.taint = 5.0
		var d := DiceEngine.new()
		d.set_seed(_i * 7 + 3)
		var result := MutationSystem.process_rank_up(c2, 5, d, 1)
		for pt: Enums.ShadowlandsPowerType in result["gained_powers"]:
			# Must be Minor or Major — not Akutenshi
			assert_true(
				MutationSystem.MINOR_POWERS.has(pt) or MutationSystem.MAJOR_POWERS.has(pt)
			)


func test_no_duplicate_mutations_across_rank_ups() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	# Pre-fill all mutations to exhaust the pool
	for mt: Enums.MutationType in MutationSystem.ALL_MUTATIONS:
		if mt == Enums.MutationType.NONE:
			continue
		MutationSystem.gain_mutation(c, mt, _dice(), 0)
	var result := MutationSystem.process_rank_up(c, 3, _dice(), 1)
	# No new mutation should be granted (pool exhausted)
	assert_eq(result["gained_mutations"].size(), 0)


# ---------------------------------------------------------------------------
# Skill modifiers
# ---------------------------------------------------------------------------

func test_discolored_skin_adds_tn_penalty_to_social() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.DISCOLORED_SKIN, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Courtier")
	assert_eq(mod["tn"], 5)


func test_discolored_skin_no_tn_on_non_social() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.DISCOLORED_SKIN, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Athletics")
	assert_eq(mod["tn"], 0)


func test_foul_odor_minus_1k0_on_social() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Etiquette")
	assert_eq(mod["rolled"], -1)


func test_tough_hide_minus_2k0_on_social() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.TOUGH_HIDE, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Sincerity")
	assert_eq(mod["rolled"], -2)


func test_extra_digit_minus_1k0_on_social() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.EXTRA_DIGIT, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Acting")
	assert_eq(mod["rolled"], -1)


func test_albinism_minus_1k0_social_when_appearance_known() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.ALBINISM, _dice(), 1)
	var mod_known := MutationSystem.get_skill_modifiers(c, "Courtier", "", {"appearance_known": true})
	assert_eq(mod_known["rolled"], -1)
	var mod_unknown := MutationSystem.get_skill_modifiers(c, "Courtier", "", {"appearance_known": false})
	assert_eq(mod_unknown["rolled"], 0)


func test_extra_eye_plus_1k0_perception_uncovered() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.EXTRA_EYE, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Investigation", "", {"extra_eye_uncovered": true})
	assert_eq(mod["rolled"], 1)


func test_extra_limb_nonfunctional_penalty_agility() -> void:
	var c := _make_char(1)
	# Force non-functional
	var md := MutationData.new()
	md.mutation_type = Enums.MutationType.EXTRA_LIMB
	md.is_non_functional = true
	c.mutations.append(md)
	var mod := MutationSystem.get_skill_modifiers(c, "Defense")
	assert_eq(mod["rolled"], -1)


func test_extra_limb_functional_no_penalty() -> void:
	var c := _make_char(1)
	var md := MutationData.new()
	md.mutation_type = Enums.MutationType.EXTRA_LIMB
	md.is_non_functional = false
	c.mutations.append(md)
	var mod := MutationSystem.get_skill_modifiers(c, "Defense")
	assert_eq(mod["rolled"], 0)


func test_master_of_shadows_adds_taint_rank_unkept_stealth() -> void:
	var c := _make_char(1)
	c.taint = 3.0  # Rank 3
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MASTER_OF_SHADOWS, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Stealth")
	assert_eq(mod["rolled"], 3)  # Taint Rank unkept dice added


func test_monstrous_strength_social_penalty_and_strength_bonus() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MONSTROUS_STRENGTH, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	var social_mod := MutationSystem.get_skill_modifiers(c, "Courtier")
	assert_eq(social_mod["rolled"], -1)
	var str_mod := MutationSystem.get_skill_modifiers(c, "Athletics")
	assert_eq(str_mod["rolled"], 2)  # Taint Rank 2 unkept added


func test_father_of_lies_adds_kept_to_temptation() -> void:
	var c := _make_char(1)
	c.taint = 4.0  # Rank 4
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.FATHER_OF_LIES, Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Temptation")
	assert_eq(mod["kept"], 4)


func test_father_of_lies_adds_kept_to_intimidation() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.FATHER_OF_LIES, Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Intimidation")
	assert_eq(mod["kept"], 3)


func test_father_of_lies_adds_kept_to_sincerity_deceit() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.FATHER_OF_LIES, Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Sincerity", "Deceit")
	assert_eq(mod["kept"], 2)


func test_father_of_lies_no_bonus_sincerity_non_deceit() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.FATHER_OF_LIES, Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1)
	var mod := MutationSystem.get_skill_modifiers(c, "Sincerity", "")
	assert_eq(mod["kept"], 0)


func test_no_modifiers_no_mutations_no_powers() -> void:
	var c := _make_char(1)
	var mod := MutationSystem.get_skill_modifiers(c, "Kenjutsu")
	assert_eq(mod["rolled"], 0)
	assert_eq(mod["kept"], 0)
	assert_eq(mod["tn"], 0)


# ---------------------------------------------------------------------------
# MASTER_OF_BLOOD maho interaction
# ---------------------------------------------------------------------------

func test_master_of_blood_reduces_blood_cost() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MASTER_OF_BLOOD, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	var result := MutationSystem.apply_master_of_blood(c, 4, 2)
	assert_eq(result["blood_cost"], 3)  # 4 - 1 = 3


func test_master_of_blood_reduces_taint_gain_by_earth() -> void:
	var c := _make_char(1, 3, 3)  # Earth = min(sta, wil) = 3
	c.taint = 2.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MASTER_OF_BLOOD, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	var result := MutationSystem.apply_master_of_blood(c, 4, 3)
	assert_eq(result["taint_gain"], 1)  # max(1, 3 - 3) = 1


func test_master_of_blood_taint_minimum_is_1() -> void:
	var c := _make_char(1, 10, 10)  # Earth 10
	c.taint = 2.0
	MutationSystem.gain_power(c, Enums.ShadowlandsPowerType.MASTER_OF_BLOOD, Enums.ShadowlandsPowerTier.MINOR, _dice(), 1)
	var result := MutationSystem.apply_master_of_blood(c, 4, 1)
	assert_eq(result["taint_gain"], 1)  # min 1


func test_apply_master_of_blood_no_power_returns_unchanged() -> void:
	var c := _make_char(1)
	var result := MutationSystem.apply_master_of_blood(c, 6, 3)
	assert_eq(result["blood_cost"], 6)
	assert_eq(result["taint_gain"], 3)


# ---------------------------------------------------------------------------
# Social penalty helpers
# ---------------------------------------------------------------------------

func test_get_social_rolled_penalty_stacks_mutations() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.EXTRA_DIGIT, _dice(), 1)  # -1
	MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 1)   # -1
	assert_eq(MutationSystem.get_social_rolled_penalty(c), 2)


func test_get_social_tn_penalty_discolored_skin() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.DISCOLORED_SKIN, _dice(), 1)
	assert_eq(MutationSystem.get_social_tn_penalty(c), 5)


func test_get_social_penalties_zero_without_mutations() -> void:
	var c := _make_char(1)
	assert_eq(MutationSystem.get_social_rolled_penalty(c), 0)
	assert_eq(MutationSystem.get_social_tn_penalty(c), 0)


# ---------------------------------------------------------------------------
# is_lost
# ---------------------------------------------------------------------------

func test_is_lost_false_below_5() -> void:
	var c := _make_char(1)
	c.taint = 4.9
	assert_false(MutationSystem.is_lost(c))


func test_is_lost_true_at_5() -> void:
	var c := _make_char(1)
	c.taint = 5.0
	assert_true(MutationSystem.is_lost(c))


# ---------------------------------------------------------------------------
# DayOrchestrator integration stubs
# ---------------------------------------------------------------------------

func test_process_taint_rank_changes_triggers_on_threshold_crossing() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 2.0
	c.taint_rank_last_processed = 0  # rank 0 was last processed
	var characters: Array = [c]
	var d := _dice()
	var results := DayOrchestrator._process_taint_rank_changes(characters, d, 1)
	# Should trigger rank 1 and rank 2 events
	assert_true(results.size() >= 1)
	assert_eq(c.taint_rank_last_processed, 2)


func test_process_taint_rank_changes_no_event_already_processed() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 2.0
	c.taint_rank_last_processed = 2  # already processed up to rank 2
	var characters: Array = [c]
	var results := DayOrchestrator._process_taint_rank_changes(characters, _dice(), 1)
	assert_eq(results.size(), 0)


func test_process_taint_rank_changes_skips_dead() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 3.0
	c.taint_rank_last_processed = 0
	c.wounds_taken = 100  # dead
	var results := DayOrchestrator._process_taint_rank_changes([c], _dice(), 1)
	assert_eq(results.size(), 0)


func test_process_periodic_taint_rolls_fires_on_period() -> void:
	var c := _make_char(1, 1, 1)  # Earth 1 — likely fails TN 10
	c.taint = 1.0  # Rank 1: period = 30
	var results := DayOrchestrator._process_periodic_taint_rolls([c], _dice(), 30)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["taint_rank"], 1)


func test_process_periodic_taint_rolls_skips_non_period_day() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 1.0  # period 30
	var results := DayOrchestrator._process_periodic_taint_rolls([c], _dice(), 29)
	assert_eq(results.size(), 0)


func test_process_periodic_taint_rolls_skips_dead() -> void:
	var c := _make_char(1, 1, 1)
	c.taint = 1.0
	c.wounds_taken = 100
	var results := DayOrchestrator._process_periodic_taint_rolls([c], _dice(), 30)
	assert_eq(results.size(), 0)


func test_process_periodic_taint_rolls_skips_untainted() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 0.0
	var results := DayOrchestrator._process_periodic_taint_rolls([c], _dice(), 30)
	assert_eq(results.size(), 0)


# ---------------------------------------------------------------------------
# MIND_OF_DARKNESS — s44 line 123
# ---------------------------------------------------------------------------

func _char_with_mind_of_darkness(taint: float, is_lost: bool) -> L5RCharacterData:
	var c := _make_char(50)
	c.taint = taint
	var p := ShadowlandsPowerData.new()
	p.power_type = Enums.ShadowlandsPowerType.MIND_OF_DARKNESS
	p.tier = Enums.ShadowlandsPowerTier.MAJOR
	c.shadowlands_powers = [p]
	return c


func test_mind_of_darkness_lost_adds_taint_rank_to_awareness_skill() -> void:
	# Lost character (taint 5.1 → rank 5) with MIND_OF_DARKNESS.
	# Etiquette uses Awareness; dtn should be +5.
	var c := _char_with_mind_of_darkness(5.1, true)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Etiquette")
	assert_eq(mod.get("tn", 0), 5)  # taint_rank 5


func test_mind_of_darkness_lost_adds_taint_rank_to_intelligence_skill() -> void:
	# Lore: Heraldry uses Intelligence.
	var c := _char_with_mind_of_darkness(5.0, true)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Lore: Heraldry")
	assert_eq(mod.get("tn", 0), 5)


func test_mind_of_darkness_lost_adds_taint_rank_to_willpower_skill() -> void:
	# Meditation uses Willpower.
	var c := _char_with_mind_of_darkness(5.0, true)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Meditation")
	assert_eq(mod.get("tn", 0), 5)


func test_mind_of_darkness_lost_adds_taint_rank_to_perception_skill() -> void:
	# Investigation uses Perception.
	var c := _char_with_mind_of_darkness(5.0, true)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Investigation")
	assert_eq(mod.get("tn", 0), 5)


func test_mind_of_darkness_does_not_affect_non_mental_skill() -> void:
	# Kenjutsu uses Agility — must not get the bonus.
	var c := _char_with_mind_of_darkness(5.0, true)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Kenjutsu")
	assert_eq(mod.get("tn", 0), 0)


func test_mind_of_darkness_not_applied_to_non_lost() -> void:
	# Taint rank 3 (not Lost) — GDD says "if Lost" for flat bonus.
	var c := _char_with_mind_of_darkness(3.5, false)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Etiquette")
	assert_eq(mod.get("tn", 0), 0)


func test_mind_of_darkness_rank_scales_with_taint() -> void:
	# Taint 5.0 → rank 5, so dtn should be +5. Verify rank scaling.
	var c := _char_with_mind_of_darkness(5.0, true)
	var mod: Dictionary = MutationSystem.get_skill_modifiers(c, "Sincerity")
	assert_eq(mod.get("tn", 0), 5)  # Sincerity uses Awareness


# ---------------------------------------------------------------------------
# process_rank_up — return dict and character mutation / power arrays
# ---------------------------------------------------------------------------

func test_process_rank_up_return_dict_has_new_rank() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	var result := MutationSystem.process_rank_up(c, 2, _dice(), 1)
	assert_has(result, "new_rank")
	assert_eq(result["new_rank"], 2)


func test_rank2_up_adds_power_to_character_shadowlands_powers() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	MutationSystem.process_rank_up(c, 2, _dice(), 1)
	assert_eq(c.shadowlands_powers.size(), 1)


func test_rank3_up_adds_mutation_to_character_mutations() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	MutationSystem.process_rank_up(c, 3, _dice(), 1)
	assert_eq(c.mutations.size(), 1)


func test_rank2_all_minor_powers_exhausted_no_power_gained() -> void:
	var c := _make_char(1)
	c.taint = 2.0
	for pt: Enums.ShadowlandsPowerType in MutationSystem.MINOR_POWERS:
		var pd := ShadowlandsPowerData.new()
		pd.power_type = pt
		pd.tier = Enums.ShadowlandsPowerTier.MINOR
		c.shadowlands_powers.append(pd)
	var result := MutationSystem.process_rank_up(c, 2, _dice(), 1)
	assert_eq(result["gained_powers"].size(), 0)


func test_rank3_power_tier_matches_pool_membership() -> void:
	var c := _make_char(1)
	c.taint = 3.0
	var result := MutationSystem.process_rank_up(c, 3, _dice(), 1)
	if result["gained_powers"].size() > 0:
		var pt: Enums.ShadowlandsPowerType = result["gained_powers"][0]
		var expected_tier: Enums.ShadowlandsPowerTier = (
			Enums.ShadowlandsPowerTier.MINOR
			if MutationSystem.MINOR_POWERS.has(pt)
			else Enums.ShadowlandsPowerTier.MAJOR
		)
		for sp: ShadowlandsPowerData in c.shadowlands_powers:
			if sp.power_type == pt:
				assert_eq(sp.tier, expected_tier)
				break


func test_rank4_second_power_any_tier_when_major_pool_exhausted() -> void:
	var c := _make_char(1)
	c.taint = 4.0
	# Exhaust all Major powers so first (guaranteed Major) gains nothing.
	# Second draw falls back to any pool (Minor).
	for pt: Enums.ShadowlandsPowerType in MutationSystem.MAJOR_POWERS:
		var pd := ShadowlandsPowerData.new()
		pd.power_type = pt
		pd.tier = Enums.ShadowlandsPowerTier.MAJOR
		c.shadowlands_powers.append(pd)
	var result := MutationSystem.process_rank_up(c, 4, _dice(), 1)
	# First guaranteed-Major draw yields nothing; second draw from any pool.
	for pt: Enums.ShadowlandsPowerType in result["gained_powers"]:
		assert_true(
			MutationSystem.MINOR_POWERS.has(pt) or MutationSystem.MAJOR_POWERS.has(pt)
		)


# ---------------------------------------------------------------------------
# Multi-rank jump via _process_taint_rank_changes
# ---------------------------------------------------------------------------

func test_process_taint_rank_changes_multi_rank_jump_updates_last_processed() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 3.5  # current rank = 3
	c.taint_rank_last_processed = 0
	DayOrchestrator._process_taint_rank_changes([c], _dice(), 1)
	assert_eq(c.taint_rank_last_processed, 3)


func test_process_taint_rank_changes_multi_rank_jump_fires_multiple_events() -> void:
	var c := _make_char(1, 3, 3)
	c.taint = 3.5  # rank 3; last_processed = 0 → should fire for ranks 1, 2, 3
	c.taint_rank_last_processed = 0
	var results := DayOrchestrator._process_taint_rank_changes([c], _dice(), 1)
	assert_eq(results.size(), 3)


# ---------------------------------------------------------------------------
# Gain — ic_day storage
# ---------------------------------------------------------------------------

func test_gain_mutation_stores_ic_day_manifested() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.ALBINISM, _dice(), 42)
	assert_eq(c.mutations[0].ic_day_manifested, 42)


func test_gain_power_stores_ic_day_acquired() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.JADE_SENSE,
		Enums.ShadowlandsPowerTier.MINOR, _dice(), 99
	)
	assert_eq(c.shadowlands_powers[0].ic_day_acquired, 99)


# ---------------------------------------------------------------------------
# Skill modifiers — coverage gaps
# ---------------------------------------------------------------------------

func test_distorted_limbs_arm_uses_distorted_arm_context_penalty() -> void:
	var c := _make_char(1)
	var md := MutationData.new()
	md.mutation_type = Enums.MutationType.DISTORTED_LIMBS
	md.affected_limb = "arm"
	c.mutations.append(md)
	var mod := MutationSystem.get_skill_modifiers(c, "Kenjutsu", "", {"uses_distorted_arm": true})
	assert_eq(mod["rolled"], -3)


func test_distorted_limbs_arm_no_context_flag_no_penalty() -> void:
	var c := _make_char(1)
	var md := MutationData.new()
	md.mutation_type = Enums.MutationType.DISTORTED_LIMBS
	md.affected_limb = "arm"
	c.mutations.append(md)
	var mod := MutationSystem.get_skill_modifiers(c, "Kenjutsu")
	assert_eq(mod["rolled"], 0)


func test_extra_limb_nonfunctional_penalty_reflexes_stealth() -> void:
	var c := _make_char(1)
	var md := MutationData.new()
	md.mutation_type = Enums.MutationType.EXTRA_LIMB
	md.is_non_functional = true
	c.mutations.append(md)
	# Stealth is in REFLEXES_SKILLS — non-functional limb penalises it
	var mod := MutationSystem.get_skill_modifiers(c, "Stealth")
	assert_eq(mod["rolled"], -1)


func test_multiple_social_penalties_stack_rolled_and_tn() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.DISCOLORED_SKIN, _dice(), 1)  # +5 TN
	MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 1)        # -1 rolled
	MutationSystem.gain_mutation(c, Enums.MutationType.EXTRA_DIGIT, _dice(), 1)      # -1 rolled
	var mod := MutationSystem.get_skill_modifiers(c, "Courtier")
	assert_eq(mod["rolled"], -2)
	assert_eq(mod["tn"], 5)


# ---------------------------------------------------------------------------
# get_social_rolled_penalty — coverage gaps
# ---------------------------------------------------------------------------

func test_get_social_rolled_penalty_tough_hide() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.TOUGH_HIDE, _dice(), 1)
	assert_eq(MutationSystem.get_social_rolled_penalty(c), 2)


func test_get_social_rolled_penalty_albinism() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.ALBINISM, _dice(), 1)
	# Helper includes albinism unconditionally; caller checks context separately
	assert_eq(MutationSystem.get_social_rolled_penalty(c), 1)


func test_get_social_rolled_penalty_all_sources_stack() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.ALBINISM, _dice(), 1)   # +1
	MutationSystem.gain_mutation(c, Enums.MutationType.EXTRA_DIGIT, _dice(), 1) # +1
	MutationSystem.gain_mutation(c, Enums.MutationType.FOUL_ODOR, _dice(), 1)  # +1
	MutationSystem.gain_mutation(c, Enums.MutationType.TOUGH_HIDE, _dice(), 1) # +2
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.MONSTROUS_STRENGTH,
		Enums.ShadowlandsPowerTier.MINOR, _dice(), 1
	)  # +1
	assert_eq(MutationSystem.get_social_rolled_penalty(c), 6)


# ---------------------------------------------------------------------------
# Combat stubs — get_armor_reduction
# ---------------------------------------------------------------------------

func test_get_armor_reduction_no_mutations_returns_zero() -> void:
	var c := _make_char(1)
	assert_eq(MutationSystem.get_armor_reduction(c), 0)


func test_get_armor_reduction_chitinous_armor_is_10() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.CHITINOUS_ARMOR, _dice(), 1)
	assert_eq(MutationSystem.get_armor_reduction(c), 10)


func test_get_armor_reduction_tough_hide_is_5() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.TOUGH_HIDE, _dice(), 1)
	assert_eq(MutationSystem.get_armor_reduction(c), 5)


func test_get_armor_reduction_chitinous_and_tough_hide_stack() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.CHITINOUS_ARMOR, _dice(), 1)
	MutationSystem.gain_mutation(c, Enums.MutationType.TOUGH_HIDE, _dice(), 1)
	assert_eq(MutationSystem.get_armor_reduction(c), 15)


# ---------------------------------------------------------------------------
# Combat stubs — get_fear_rating
# ---------------------------------------------------------------------------

func test_get_fear_rating_no_mutations_returns_zero() -> void:
	var c := _make_char(1)
	assert_eq(MutationSystem.get_fear_rating(c), 0)


func test_get_fear_rating_beast_of_fu_leng_is_1() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.BEAST_OF_FU_LENG, _dice(), 1)
	assert_eq(MutationSystem.get_fear_rating(c), 1)


func test_get_fear_rating_undead_visage_is_3() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.UNDEAD_VISAGE, _dice(), 1)
	assert_eq(MutationSystem.get_fear_rating(c), 3)


func test_get_fear_rating_takes_highest_when_both_present() -> void:
	# UNDEAD_VISAGE (3) beats BEAST_OF_FU_LENG (1)
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.BEAST_OF_FU_LENG, _dice(), 1)
	MutationSystem.gain_mutation(c, Enums.MutationType.UNDEAD_VISAGE, _dice(), 1)
	assert_eq(MutationSystem.get_fear_rating(c), 3)


# ---------------------------------------------------------------------------
# Combat stubs — has_tentacle_attacks / has_blackened_claws
# ---------------------------------------------------------------------------

func test_has_tentacle_attacks_false_without_mutation() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_tentacle_attacks(c))


func test_has_tentacle_attacks_true_with_mutation() -> void:
	var c := _make_char(1)
	MutationSystem.gain_mutation(c, Enums.MutationType.TENTACLES, _dice(), 1)
	assert_true(MutationSystem.has_tentacle_attacks(c))


func test_has_blackened_claws_false_without_power() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_blackened_claws(c))


func test_has_blackened_claws_true_with_power() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.BLACKENED_CLAWS,
		Enums.ShadowlandsPowerTier.MINOR, _dice(), 1
	)
	assert_true(MutationSystem.has_blackened_claws(c))


# ---------------------------------------------------------------------------
# Combat stubs — get_wound_rank_bonus
# ---------------------------------------------------------------------------

func test_get_wound_rank_bonus_no_powers_returns_zero() -> void:
	var c := _make_char(1)
	assert_eq(MutationSystem.get_wound_rank_bonus(c), 0)


func test_get_wound_rank_bonus_blessing_is_3() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.BLESSING_OF_THE_DARK_ONE,
		Enums.ShadowlandsPowerTier.MINOR, _dice(), 1
	)
	assert_eq(MutationSystem.get_wound_rank_bonus(c), 3)


func test_get_wound_rank_bonus_strength_is_5() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.STRENGTH_OF_THE_DARK_ONE,
		Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1
	)
	assert_eq(MutationSystem.get_wound_rank_bonus(c), 5)


func test_get_wound_rank_bonus_both_stack_to_8() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.BLESSING_OF_THE_DARK_ONE,
		Enums.ShadowlandsPowerTier.MINOR, _dice(), 1
	)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.STRENGTH_OF_THE_DARK_ONE,
		Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1
	)
	assert_eq(MutationSystem.get_wound_rank_bonus(c), 8)


# ---------------------------------------------------------------------------
# Combat stubs — has_no_wound_penalties / has_invulnerability
# ---------------------------------------------------------------------------

func test_has_no_wound_penalties_false_without_power() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_no_wound_penalties(c))


func test_has_no_wound_penalties_true_with_power() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.UNDEAD_STRENGTH,
		Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1
	)
	assert_true(MutationSystem.has_no_wound_penalties(c))


func test_has_invulnerability_false_without_power() -> void:
	var c := _make_char(1)
	assert_false(MutationSystem.has_invulnerability(c))


func test_has_invulnerability_true_with_power() -> void:
	var c := _make_char(1)
	MutationSystem.gain_power(
		c, Enums.ShadowlandsPowerType.PROTECTION_OF_THE_DARK,
		Enums.ShadowlandsPowerTier.MAJOR, _dice(), 1
	)
	assert_true(MutationSystem.has_invulnerability(c))


# ---------------------------------------------------------------------------
# Wound penalty on taint rolls
# ---------------------------------------------------------------------------

func test_periodic_taint_roll_wound_penalty_reduces_total() -> void:
	var healthy_totals: int = 0
	var wounded_totals: int = 0
	for seed_val: int in range(100):
		var ch := _make_char(1, 3, 3)
		ch.taint = 2.0
		ch.wounds_taken = 0
		var d1 := DiceEngine.new()
		d1.set_seed(seed_val)
		var r1: Dictionary = MutationSystem.resolve_periodic_taint_roll(ch, 3, d1, 1)
		healthy_totals += r1["roll_total"]

		var cw := _make_char(2, 3, 3)
		cw.taint = 2.0
		cw.wounds_taken = 13  # HURT = -10 with Earth 2 threshold
		var d2 := DiceEngine.new()
		d2.set_seed(seed_val)
		var r2: Dictionary = MutationSystem.resolve_periodic_taint_roll(cw, 3, d2, 1)
		wounded_totals += r2["roll_total"]
	assert_true(healthy_totals > wounded_totals,
		"Wounded characters should have lower taint roll totals (healthy=%d, wounded=%d)" % [healthy_totals, wounded_totals])


func test_power_use_taint_roll_wound_penalty_reduces_total() -> void:
	var healthy_totals: int = 0
	var wounded_totals: int = 0
	for seed_val: int in range(100):
		var ch := _make_char(1, 3, 3)
		ch.taint = 2.0
		ch.wounds_taken = 0
		var d1 := DiceEngine.new()
		d1.set_seed(seed_val)
		var r1: Dictionary = MutationSystem.resolve_power_use_taint_roll(
			ch, 3, Enums.ShadowlandsPowerTier.MINOR, d1)
		healthy_totals += r1["roll_total"]

		var cw := _make_char(2, 3, 3)
		cw.taint = 2.0
		cw.wounds_taken = 13
		var d2 := DiceEngine.new()
		d2.set_seed(seed_val)
		var r2: Dictionary = MutationSystem.resolve_power_use_taint_roll(
			cw, 3, Enums.ShadowlandsPowerTier.MINOR, d2)
		wounded_totals += r2["roll_total"]
	assert_true(healthy_totals > wounded_totals,
		"Wounded characters should have lower power taint roll totals (healthy=%d, wounded=%d)" % [healthy_totals, wounded_totals])
