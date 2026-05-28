extends GutTest
## Tests for OniGenerator — s2.4.8 LOCKED procedural Oni generation.


# -- Helpers -------------------------------------------------------------------

func _make_dice(seed_val: int) -> DiceEngine:
	var d := DiceEngine.new()
	d.set_seed(seed_val)
	return d


# -- Size (Step 1) -------------------------------------------------------------

func test_size_options_has_four_entries() -> void:
	assert_eq(OniGenerator.SIZE_OPTIONS.size(), 4)


func test_size_options_contains_small() -> void:
	assert_true(Enums.OniSize.SMALL in OniGenerator.SIZE_OPTIONS)


func test_size_options_contains_medium() -> void:
	assert_true(Enums.OniSize.MEDIUM in OniGenerator.SIZE_OPTIONS)


func test_size_options_contains_large() -> void:
	assert_true(Enums.OniSize.LARGE in OniGenerator.SIZE_OPTIONS)


func test_size_options_contains_massive() -> void:
	assert_true(Enums.OniSize.MASSIVE in OniGenerator.SIZE_OPTIONS)


# -- Ring Budget (Step 1 derived) ----------------------------------------------

func test_ring_budget_small() -> void:
	assert_eq(OniGenerator.RING_BUDGET[Enums.OniSize.SMALL], 9)


func test_ring_budget_medium() -> void:
	assert_eq(OniGenerator.RING_BUDGET[Enums.OniSize.MEDIUM], 12)


func test_ring_budget_large() -> void:
	assert_eq(OniGenerator.RING_BUDGET[Enums.OniSize.LARGE], 15)


func test_ring_budget_massive() -> void:
	assert_eq(OniGenerator.RING_BUDGET[Enums.OniSize.MASSIVE], 19)


# -- MB Health (Step 4) --------------------------------------------------------

func test_mb_health_small() -> void:
	assert_eq(OniGenerator.MB_HEALTH[Enums.OniSize.SMALL], 50)


func test_mb_health_medium() -> void:
	assert_eq(OniGenerator.MB_HEALTH[Enums.OniSize.MEDIUM], 100)


func test_mb_health_large() -> void:
	assert_eq(OniGenerator.MB_HEALTH[Enums.OniSize.LARGE], 175)


func test_mb_health_massive() -> void:
	assert_eq(OniGenerator.MB_HEALTH[Enums.OniSize.MASSIVE], 300)


# -- MB Attack Floor (Step 4) --------------------------------------------------

func test_mb_attack_floor_small() -> void:
	assert_eq(OniGenerator.MB_ATTACK_FLOOR[Enums.OniSize.SMALL], 5)


func test_mb_attack_floor_medium() -> void:
	assert_eq(OniGenerator.MB_ATTACK_FLOOR[Enums.OniSize.MEDIUM], 7)


func test_mb_attack_floor_large() -> void:
	assert_eq(OniGenerator.MB_ATTACK_FLOOR[Enums.OniSize.LARGE], 9)


func test_mb_attack_floor_massive() -> void:
	assert_eq(OniGenerator.MB_ATTACK_FLOOR[Enums.OniSize.MASSIVE], 11)


# -- Fear Rating (Pool 1) ------------------------------------------------------

func test_fear_rating_small() -> void:
	assert_eq(OniGenerator.FEAR_RATING[Enums.OniSize.SMALL], 1)


func test_fear_rating_medium() -> void:
	assert_eq(OniGenerator.FEAR_RATING[Enums.OniSize.MEDIUM], 2)


func test_fear_rating_large() -> void:
	assert_eq(OniGenerator.FEAR_RATING[Enums.OniSize.LARGE], 3)


func test_fear_rating_massive() -> void:
	assert_eq(OniGenerator.FEAR_RATING[Enums.OniSize.MASSIVE], 5)


# -- Pool 2 & 3 Counts ---------------------------------------------------------

func test_pool_2_has_five_options() -> void:
	assert_eq(OniGenerator.POOL_2_OPTIONS.size(), 5)


func test_pool_3_options_has_six_entries() -> void:
	assert_eq(OniGenerator.POOL_3_OPTIONS.size(), 6)


# -- Dominant Rings ------------------------------------------------------------

func test_dominant_rings_excludes_void() -> void:
	for r: int in OniGenerator.DOMINANT_RINGS:
		assert_ne(r, Enums.Ring.VOID, "VOID must not appear in DOMINANT_RINGS")


func test_dominant_rings_has_four_elements() -> void:
	assert_eq(OniGenerator.DOMINANT_RINGS.size(), 4)


# -- generate() returns OniData ------------------------------------------------

func test_generate_returns_oni_data() -> void:
	var dice := _make_dice(1)
	var oni := OniGenerator.generate(dice, 1)
	assert_not_null(oni)
	assert_is(oni, OniData)


func test_generate_records_ic_day() -> void:
	var dice := _make_dice(2)
	var oni := OniGenerator.generate(dice, 500)
	assert_eq(oni.ic_day_generated, 500)


func test_generate_size_is_valid_enum() -> void:
	var dice := _make_dice(3)
	var oni := OniGenerator.generate(dice, 1)
	var valid_sizes: Array = [
		Enums.OniSize.SMALL, Enums.OniSize.MEDIUM,
		Enums.OniSize.LARGE, Enums.OniSize.MASSIVE,
	]
	assert_true(oni.size in valid_sizes)


func test_generate_body_form_in_range() -> void:
	var dice := _make_dice(4)
	var oni := OniGenerator.generate(dice, 1)
	assert_true(oni.body_form >= 0 and oni.body_form < OniGenerator.BODY_FORM_COUNT)


func test_generate_dominant_ring_not_void() -> void:
	var dice := _make_dice(5)
	var oni := OniGenerator.generate(dice, 1)
	assert_ne(oni.dominant_ring, Enums.Ring.VOID)


# -- Ring Budget Distribution --------------------------------------------------

func test_rings_dict_has_all_five_rings() -> void:
	var dice := _make_dice(6)
	var oni := OniGenerator.generate(dice, 1)
	assert_true(oni.rings.has(Enums.Ring.EARTH))
	assert_true(oni.rings.has(Enums.Ring.WATER))
	assert_true(oni.rings.has(Enums.Ring.FIRE))
	assert_true(oni.rings.has(Enums.Ring.AIR))
	assert_true(oni.rings.has(Enums.Ring.VOID))


func test_void_ring_is_always_zero() -> void:
	var dice := _make_dice(7)
	for _i: int in range(20):
		var oni := OniGenerator.generate(dice, 1)
		assert_eq(int(oni.rings.get(Enums.Ring.VOID, -1)), 0)


func test_dominant_ring_has_highest_value() -> void:
	var dice := _make_dice(8)
	for _i: int in range(20):
		var oni := OniGenerator.generate(dice, 1)
		var dom_val: int = int(oni.rings.get(oni.dominant_ring, 0))
		for r: int in OniGenerator.DOMINANT_RINGS:
			if r != oni.dominant_ring:
				assert_true(
					dom_val > int(oni.rings.get(r, 0)),
					"dominant ring (%d=%d) must exceed ring %d (%d)" % [
						oni.dominant_ring, dom_val, r, int(oni.rings.get(r, 0))
					]
				)


func test_ring_budget_sums_correctly() -> void:
	var dice := _make_dice(9)
	for _i: int in range(20):
		var oni := OniGenerator.generate(dice, 1)
		var expected_budget: int = OniGenerator.RING_BUDGET.get(oni.size, 9)
		var actual_sum: int = 0
		for r: int in OniGenerator.DOMINANT_RINGS:
			actual_sum += int(oni.rings.get(r, 0))
		# Void adds 0; sum of the 4 non-Void rings should equal budget.
		assert_eq(actual_sum, expected_budget,
			"Ring sum %d != budget %d for size %d" % [actual_sum, expected_budget, oni.size])


func test_non_dominant_rings_all_at_least_one() -> void:
	var dice := _make_dice(10)
	for _i: int in range(20):
		var oni := OniGenerator.generate(dice, 1)
		for r: int in OniGenerator.DOMINANT_RINGS:
			if r != oni.dominant_ring:
				assert_true(
					int(oni.rings.get(r, 0)) >= 1,
					"Non-dominant ring %d must be at least 1" % r
				)


# -- Derived Stats (Step 4) ----------------------------------------------------

func test_mb_health_matches_size_table() -> void:
	var dice := _make_dice(11)
	var oni := OniGenerator.generate(dice, 1)
	assert_eq(oni.mb_health, OniGenerator.MB_HEALTH.get(oni.size, 50))


func test_mb_attack_floor_plus_fire() -> void:
	var dice := _make_dice(12)
	var oni := OniGenerator.generate(dice, 1)
	var fire_val: int = int(oni.rings.get(Enums.Ring.FIRE, 1))
	var expected: int = OniGenerator.MB_ATTACK_FLOOR.get(oni.size, 5) + fire_val
	assert_eq(oni.mb_attack, expected)


func test_mb_defense_is_earth_plus_air() -> void:
	var dice := _make_dice(13)
	var oni := OniGenerator.generate(dice, 1)
	var earth_val: int = int(oni.rings.get(Enums.Ring.EARTH, 1))
	var air_val: int = int(oni.rings.get(Enums.Ring.AIR, 1))
	assert_eq(oni.mb_defense, earth_val + air_val)


func test_wounds_is_earth_times_16() -> void:
	var dice := _make_dice(14)
	var oni := OniGenerator.generate(dice, 1)
	var earth_val: int = int(oni.rings.get(Enums.Ring.EARTH, 1))
	assert_eq(oni.wounds, earth_val * 16)


func test_armor_tn_is_air_times_5() -> void:
	var dice := _make_dice(15)
	var oni := OniGenerator.generate(dice, 1)
	var air_val: int = int(oni.rings.get(Enums.Ring.AIR, 1))
	assert_eq(oni.armor_tn, air_val * 5)


func test_reduction_is_earth_times_4() -> void:
	var dice := _make_dice(16)
	var oni := OniGenerator.generate(dice, 1)
	var earth_val: int = int(oni.rings.get(Enums.Ring.EARTH, 1))
	assert_eq(oni.reduction, earth_val * 4)


# -- Fear Rating (Pool 1) -------------------------------------------------------

func test_fear_rating_matches_size() -> void:
	var dice := _make_dice(17)
	var oni := OniGenerator.generate(dice, 1)
	assert_eq(oni.fear_rating, OniGenerator.FEAR_RATING.get(oni.size, 1))


# -- Pool 2: Invulnerability ---------------------------------------------------

func test_invulnerability_is_valid_enum() -> void:
	var dice := _make_dice(18)
	var oni := OniGenerator.generate(dice, 1)
	assert_true(oni.invulnerability in OniGenerator.POOL_2_OPTIONS)


func test_spell_immunity_count_in_range_when_present() -> void:
	# Run many seeds to find a SPELL_IMMUNITY result.
	var found_spell: bool = false
	for seed_val: int in range(1, 200):
		var dice := _make_dice(seed_val)
		var oni := OniGenerator.generate(dice, 1)
		if oni.invulnerability == Enums.OniInvulnerability.SPELL_IMMUNITY:
			assert_true(oni.spell_immunity_count >= 1 and oni.spell_immunity_count <= 3,
				"spell_immunity_count must be 1–3, got %d" % oni.spell_immunity_count)
			found_spell = true
			break
	if not found_spell:
		pass  # Acceptable if the random seed range doesn't hit SPELL_IMMUNITY.


func test_spell_immunity_count_zero_when_not_spell() -> void:
	for seed_val: int in range(1, 50):
		var dice := _make_dice(seed_val)
		var oni := OniGenerator.generate(dice, 1)
		if oni.invulnerability != Enums.OniInvulnerability.SPELL_IMMUNITY:
			assert_eq(oni.spell_immunity_count, 0)
			return  # One non-spell case is sufficient.


# -- Pool 3: Special Attack ----------------------------------------------------

func test_special_attack_is_valid_enum() -> void:
	var valid_attacks: Array = [
		Enums.OniSpecialAttack.BREATH_WEAPON,
		Enums.OniSpecialAttack.CRUSHING_GRIP,
		Enums.OniSpecialAttack.TAINT_SPIT,
		Enums.OniSpecialAttack.REGENERATION,
		Enums.OniSpecialAttack.SPAWN,
		Enums.OniSpecialAttack.TAINT_AURA,
	]
	var dice := _make_dice(19)
	var oni := OniGenerator.generate(dice, 1)
	assert_true(oni.special_attack in valid_attacks)


# -- Weakness (Step 6) ---------------------------------------------------------

func test_weakness_is_valid_enum_value() -> void:
	var dice := _make_dice(21)
	var oni := OniGenerator.generate(dice, 1)
	assert_true(oni.specific_weakness >= 0 and oni.specific_weakness < OniGenerator.WEAKNESS_COUNT)


func test_weapon_type_populated_for_weapon_weakness() -> void:
	for seed_val: int in range(1, 300):
		var dice := _make_dice(seed_val)
		var oni := OniGenerator.generate(dice, 1)
		if oni.specific_weakness == Enums.OniWeakness.SPECIFIC_WEAPON_TYPE:
			assert_true(oni.weakness_weapon_type != "",
				"weakness_weapon_type must be non-empty for SPECIFIC_WEAPON_TYPE")
			assert_true(oni.weakness_weapon_type in OniGenerator.WEAPON_TYPES,
				"weapon type '%s' not in WEAPON_TYPES" % oni.weakness_weapon_type)
			return


func test_spell_school_populated_for_school_weakness() -> void:
	for seed_val: int in range(1, 300):
		var dice := _make_dice(seed_val)
		var oni := OniGenerator.generate(dice, 1)
		if oni.specific_weakness == Enums.OniWeakness.SPECIFIC_SPELL_SCHOOL:
			assert_true(oni.weakness_spell_school != "",
				"weakness_spell_school must be non-empty for SPECIFIC_SPELL_SCHOOL")
			assert_true(oni.weakness_spell_school in OniGenerator.SPELL_SCHOOLS,
				"spell school '%s' not in SPELL_SCHOOLS" % oni.weakness_spell_school)
			return


func test_named_type_populated_for_named_individual_weakness() -> void:
	for seed_val: int in range(1, 300):
		var dice := _make_dice(seed_val)
		var oni := OniGenerator.generate(dice, 1)
		if oni.specific_weakness == Enums.OniWeakness.NAMED_INDIVIDUAL:
			assert_true(oni.weakness_named_type != "",
				"weakness_named_type must be non-empty for NAMED_INDIVIDUAL")
			assert_true(oni.weakness_named_type in OniGenerator.NAMED_INDIVIDUAL_TYPES,
				"named type '%s' not in NAMED_INDIVIDUAL_TYPES" % oni.weakness_named_type)
			return


func test_untyped_weakness_leaves_detail_fields_empty() -> void:
	# Weaknesses 0,2,4,5 (FIRE, SUNLIGHT, SOUND) have no detail fields.
	var untyped: Array = [
		Enums.OniWeakness.FIRE,
		Enums.OniWeakness.WATER,
		Enums.OniWeakness.SUNLIGHT,
		Enums.OniWeakness.SOUND,
	]
	for seed_val: int in range(1, 300):
		var dice := _make_dice(seed_val)
		var oni := OniGenerator.generate(dice, 1)
		if oni.specific_weakness in untyped:
			assert_eq(oni.weakness_weapon_type, "")
			assert_eq(oni.weakness_spell_school, "")
			assert_eq(oni.weakness_named_type, "")
			return


# -- get_mb_stats() ------------------------------------------------------------

func test_get_mb_stats_has_required_keys() -> void:
	var dice := _make_dice(22)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_true(stats.has("unit_type"))
	assert_true(stats.has("health"))
	assert_true(stats.has("current_health"))
	assert_true(stats.has("attack"))
	assert_true(stats.has("defense"))
	assert_true(stats.has("morale"))
	assert_true(stats.has("morale_defense"))
	assert_true(stats.has("no_morale"))
	assert_true(stats.has("is_winged"))
	assert_true(stats.has("fear_rating"))
	assert_true(stats.has("special_attack"))
	assert_true(stats.has("invulnerability"))
	assert_true(stats.has("size"))
	assert_true(stats.has("body_form"))


func test_get_mb_stats_morale_is_minus_one() -> void:
	var dice := _make_dice(23)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(int(stats["morale"]), -1)
	assert_eq(int(stats["morale_defense"]), -1)


func test_get_mb_stats_no_morale_flag() -> void:
	var dice := _make_dice(24)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_true(bool(stats["no_morale"]))


func test_get_mb_stats_unit_type_is_oni() -> void:
	var dice := _make_dice(25)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(str(stats["unit_type"]), "oni")


func test_get_mb_stats_health_matches_oni_mb_health() -> void:
	var dice := _make_dice(26)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(int(stats["health"]), oni.mb_health)
	assert_eq(int(stats["current_health"]), oni.mb_health)


func test_get_mb_stats_attack_matches_oni_mb_attack() -> void:
	var dice := _make_dice(27)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(int(stats["attack"]), oni.mb_attack)


func test_get_mb_stats_defense_matches_oni_mb_defense() -> void:
	var dice := _make_dice(28)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(int(stats["defense"]), oni.mb_defense)


func test_get_mb_stats_is_winged_matches_oni() -> void:
	var dice := _make_dice(29)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(bool(stats["is_winged"]), oni.is_winged)


func test_get_mb_stats_fear_rating_matches_oni() -> void:
	var dice := _make_dice(30)
	var oni := OniGenerator.generate(dice, 1)
	var stats := OniGenerator.get_mb_stats(oni)
	assert_eq(int(stats["fear_rating"]), oni.fear_rating)


# -- Winged distribution -------------------------------------------------------

func test_winged_flag_always_false() -> void:
	var dice := _make_dice(31)
	for _i: int in range(50):
		var oni := OniGenerator.generate(dice, 1)
		assert_false(oni.is_winged, "is_winged must always be false")


# -- Determinism ---------------------------------------------------------------

func test_same_seed_produces_same_oni() -> void:
	var dice_a := _make_dice(42)
	var oni_a := OniGenerator.generate(dice_a, 100)
	var dice_b := _make_dice(42)
	var oni_b := OniGenerator.generate(dice_b, 100)
	assert_eq(oni_a.size, oni_b.size)
	assert_eq(oni_a.body_form, oni_b.body_form)
	assert_eq(oni_a.dominant_ring, oni_b.dominant_ring)
	assert_eq(oni_a.mb_health, oni_b.mb_health)
	assert_eq(oni_a.mb_attack, oni_b.mb_attack)
	assert_eq(oni_a.specific_weakness, oni_b.specific_weakness)
	assert_eq(oni_a.invulnerability, oni_b.invulnerability)
	assert_eq(oni_a.special_attack, oni_b.special_attack)


func test_different_seeds_can_produce_different_oni() -> void:
	var dice_a := _make_dice(1)
	var oni_a := OniGenerator.generate(dice_a, 1)
	var dice_b := _make_dice(99)
	var oni_b := OniGenerator.generate(dice_b, 1)
	# It would be astronomically unlikely for every field to match.
	var differs: bool = (
		oni_a.size != oni_b.size
		or oni_a.body_form != oni_b.body_form
		or oni_a.dominant_ring != oni_b.dominant_ring
		or oni_a.specific_weakness != oni_b.specific_weakness
	)
	assert_true(differs, "Different seeds should generally produce different Oni")


# -- Weakness count ------------------------------------------------------------

func test_weakness_count_is_seven() -> void:
	assert_eq(OniGenerator.WEAKNESS_COUNT, 7)


func test_weapon_types_list_not_empty() -> void:
	assert_true(OniGenerator.WEAPON_TYPES.size() > 0)


func test_spell_schools_list_not_empty() -> void:
	assert_true(OniGenerator.SPELL_SCHOOLS.size() > 0)


func test_named_individual_types_not_empty() -> void:
	assert_true(OniGenerator.NAMED_INDIVIDUAL_TYPES.size() > 0)
