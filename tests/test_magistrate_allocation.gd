extends GutTest
## Tests for MagistrateAllocation per GDD s11.3.17 and s11.3.19e.


# -- Magistrate Count (s11.3.17a) ----

func test_rural_province_one_magistrate():
	assert_eq(MagistrateAllocation.get_magistrate_count(0), 1)


func test_province_with_one_city():
	assert_eq(MagistrateAllocation.get_magistrate_count(1), 2)


func test_province_with_two_cities():
	assert_eq(MagistrateAllocation.get_magistrate_count(2), 3)


func test_otosan_uchi_17_districts():
	assert_eq(MagistrateAllocation.get_magistrate_count(0, true), 17)


# -- Doshin Baseline (s11.3.19e.vi) ----

func test_remote_settlement_no_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(1.0, true)
	assert_eq(result["count"], 0)


func test_below_village_threshold_no_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(0.3)
	assert_eq(result["count"], 0)


func test_village_one_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(0.7)
	assert_eq(result["count"], 1)
	assert_eq(result["tier"], MagistrateAllocation.DoshinTier.VILLAGE)
	assert_false(result["has_headman"])


func test_large_village_two_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(1.5)
	assert_eq(result["count"], 2)
	assert_eq(result["tier"], MagistrateAllocation.DoshinTier.VILLAGE)


func test_castle_town_city_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(3.0)
	assert_eq(result["count"], 3)
	assert_eq(result["tier"], MagistrateAllocation.DoshinTier.CITY)
	assert_false(result["has_headman"])


func test_town_has_headman():
	var result := MagistrateAllocation.get_doshin_baseline(7.0)
	assert_eq(result["count"], 5)
	assert_eq(result["tier"], MagistrateAllocation.DoshinTier.CITY)
	assert_true(result["has_headman"])


func test_city_ten_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(15.0)
	assert_eq(result["count"], 10)
	assert_true(result["has_headman"])


func test_major_city_fifteen_doshin():
	var result := MagistrateAllocation.get_doshin_baseline(25.0)
	assert_eq(result["count"], 15)
	assert_true(result["has_headman"])


# -- Available Doshin (s11.3.19e.vii) ----

func test_available_subtracts_losses():
	var available := MagistrateAllocation.get_available_doshin(7.0, 2, false, false, false, 50)
	assert_eq(available, 3, "Town baseline 5 - 2 losses = 3")


func test_village_seasonal_halving():
	var available := MagistrateAllocation.get_available_doshin(1.5, 0, false, true, true, 50)
	assert_eq(available, 1, "Large village 2 doshin, harvest season = ceil(2/2) = 1")


func test_village_no_halving_outside_season():
	var available := MagistrateAllocation.get_available_doshin(1.5, 0, false, true, false, 50)
	assert_eq(available, 2, "Large village 2 doshin, normal season = 2")


func test_low_stability_penalty():
	var available := MagistrateAllocation.get_available_doshin(7.0, 0, false, false, false, 20)
	assert_eq(available, 3, "Town 5 doshin - 2 stability penalty = 3")


func test_available_never_negative():
	var available := MagistrateAllocation.get_available_doshin(0.7, 5, false, true, true, 10)
	assert_eq(available, 0, "Cannot go below 0")


func test_combined_losses_seasonal_stability():
	var available := MagistrateAllocation.get_available_doshin(1.5, 1, false, true, true, 20)
	# baseline 2 - 1 loss = 1, seasonal ceil(1/2) = 1, stability -2 → -1 → clamped to 0
	assert_eq(available, 0)


# -- Recruitment Limits (s11.3.19e.viii) ----

func test_max_recruitable_half_rounded_up():
	assert_eq(MagistrateAllocation.get_max_recruitable(5), 3)
	assert_eq(MagistrateAllocation.get_max_recruitable(4), 2)
	assert_eq(MagistrateAllocation.get_max_recruitable(1), 1)
	assert_eq(MagistrateAllocation.get_max_recruitable(0), 0)


# -- Investigation Bonus (s11.3.19e.ii) ----

func test_no_doshin_no_bonus():
	assert_eq(MagistrateAllocation.get_investigation_bonus(0, false), 0)


func test_small_force_bonus():
	assert_eq(MagistrateAllocation.get_investigation_bonus(1, false), 3)
	assert_eq(MagistrateAllocation.get_investigation_bonus(2, false), 3)


func test_medium_force_bonus():
	assert_eq(MagistrateAllocation.get_investigation_bonus(3, false), 5)
	assert_eq(MagistrateAllocation.get_investigation_bonus(5, false), 5)


func test_large_force_bonus():
	assert_eq(MagistrateAllocation.get_investigation_bonus(6, false), 8)
	assert_eq(MagistrateAllocation.get_investigation_bonus(10, false), 8)


func test_samurai_target_flat_bonus():
	assert_eq(MagistrateAllocation.get_investigation_bonus(1, true), 3)
	assert_eq(MagistrateAllocation.get_investigation_bonus(10, true), 3,
		"Samurai investigation bonus doesn't scale with doshin count")


# -- Suppression Bonus (s11.3.19e.ii) ----

func test_suppression_bonus_scales():
	assert_eq(MagistrateAllocation.get_suppression_bonus(0), 0)
	assert_eq(MagistrateAllocation.get_suppression_bonus(2), 3)
	assert_eq(MagistrateAllocation.get_suppression_bonus(4), 5)
	assert_eq(MagistrateAllocation.get_suppression_bonus(8), 8)


# -- Loss and Recovery (s11.3.19e.iii/vii) ----

func test_apply_doshin_loss():
	assert_eq(MagistrateAllocation.apply_doshin_loss(1, 2), 3)


func test_apply_seasonal_recovery():
	assert_eq(MagistrateAllocation.apply_seasonal_recovery(3), 2)
	assert_eq(MagistrateAllocation.apply_seasonal_recovery(1), 0)
	assert_eq(MagistrateAllocation.apply_seasonal_recovery(0), 0)
