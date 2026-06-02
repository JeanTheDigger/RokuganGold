extends GutTest
## Tests for AsciiMapEnvironment (s56.6 --- LOCKED).

# -- s56.6.1 BiomeType enum ---------------------------------------------------

func test_biome_northern_highland() -> void:
	assert_eq(AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND, 0)

func test_biome_central_plains() -> void:
	assert_eq(AsciiMapEnvironment.BiomeType.CENTRAL_PLAINS, 1)

func test_biome_shadowlands() -> void:
	assert_eq(AsciiMapEnvironment.BiomeType.SHADOWLANDS, 6)

func test_biome_count() -> void:
	assert_eq(AsciiMapEnvironment.BiomeType.size(), 7)

# -- s56.6.2 WeatherState constants -------------------------------------------

func test_clear_ranged_tn_mod_is_zero() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.CLEAR)
	assert_eq(d["ranged_tn_mod"], 0)

func test_rain_ranged_tn_mod_is_5() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.RAIN)
	assert_eq(d["ranged_tn_mod"], 5)

func test_storm_ranged_tn_mod_is_10() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.STORM)
	assert_eq(d["ranged_tn_mod"], 10)

func test_typhoon_ranged_tn_mod_is_10() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.TYPHOON)
	assert_eq(d["ranged_tn_mod"], 10)

func test_rain_stealth_mod_is_5() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.RAIN)
	assert_eq(d["stealth_mod"], 5)

func test_storm_movement_mult_is_3() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.STORM)
	assert_eq(d["movement_mult"], 3.0)

func test_typhoon_is_coastal_only() -> void:
	assert_true(AsciiMapEnvironment.is_coastal_only(AsciiMapEnvironment.WeatherState.TYPHOON))

func test_storm_is_not_coastal_only() -> void:
	assert_false(AsciiMapEnvironment.is_coastal_only(AsciiMapEnvironment.WeatherState.STORM))

func test_mist_dawn_chance_is_20_percent() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.MIST)
	assert_almost_eq(d.get("dawn_chance", 0.0), 0.20, 0.001)

func test_mist_clears_midday() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.MIST)
	assert_true(d.get("clears_midday", false))

func test_snow_tracking_bonus_is_10() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.SNOW)
	assert_eq(d.get("tracking_bonus", 0), 10)

func test_snow_movement_mult_is_1_5() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.SNOW)
	assert_almost_eq(d["movement_mult"], 1.5, 0.001)

func test_storm_has_no_fires_flag() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.STORM)
	assert_true(d.get("no_fires", false))

func test_rain_vision_mod_is_2() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.RAIN)
	assert_eq(d["vision_mod"], 2)

func test_storm_vision_mod_is_4() -> void:
	var d: Dictionary = AsciiMapEnvironment.get_weather_data(AsciiMapEnvironment.WeatherState.STORM)
	assert_eq(d["vision_mod"], 4)

# -- s56.6.3 NoiseLevel constants ---------------------------------------------

func test_quiet_radius_is_3() -> void:
	assert_eq(AsciiMapEnvironment.radius_for_noise(AsciiMapEnvironment.NoiseLevel.QUIET), 3)

func test_moderate_radius_is_6() -> void:
	assert_eq(AsciiMapEnvironment.radius_for_noise(AsciiMapEnvironment.NoiseLevel.MODERATE), 6)

func test_loud_radius_is_12() -> void:
	assert_eq(AsciiMapEnvironment.radius_for_noise(AsciiMapEnvironment.NoiseLevel.LOUD), 12)

func test_silent_radius_is_0() -> void:
	assert_eq(AsciiMapEnvironment.radius_for_noise(AsciiMapEnvironment.NoiseLevel.SILENT), 0)

func test_quiet_detection_tn_is_20() -> void:
	assert_eq(AsciiMapEnvironment.detection_tn_for_noise(AsciiMapEnvironment.NoiseLevel.QUIET), 20)

func test_moderate_detection_tn_is_15() -> void:
	assert_eq(AsciiMapEnvironment.detection_tn_for_noise(AsciiMapEnvironment.NoiseLevel.MODERATE), 15)

func test_loud_detection_tn_is_10() -> void:
	assert_eq(AsciiMapEnvironment.detection_tn_for_noise(AsciiMapEnvironment.NoiseLevel.LOUD), 10)

func test_very_loud_is_automatic_detection() -> void:
	assert_true(AsciiMapEnvironment.is_automatic_detection(AsciiMapEnvironment.NoiseLevel.VERY_LOUD))

func test_loud_is_not_automatic_detection() -> void:
	assert_false(AsciiMapEnvironment.is_automatic_detection(AsciiMapEnvironment.NoiseLevel.LOUD))

func test_ground_stealth_tn_soft_is_10() -> void:
	assert_eq(AsciiMapEnvironment.GROUND_STEALTH_TN["soft"], 10)

func test_ground_stealth_tn_hard_is_15() -> void:
	assert_eq(AsciiMapEnvironment.GROUND_STEALTH_TN["hard"], 15)

func test_ground_stealth_tn_noisy_is_20() -> void:
	assert_eq(AsciiMapEnvironment.GROUND_STEALTH_TN["noisy"], 20)

func test_suspicious_scan_bonus_is_5() -> void:
	assert_eq(AsciiMapEnvironment.SUSPICIOUS_SCAN_BONUS, 5)

func test_suspicious_duration_is_3_rounds() -> void:
	assert_eq(AsciiMapEnvironment.ALERT_DURATION_ROUNDS[AsciiMapEnvironment.AlertState.SUSPICIOUS], 3)

func test_alert_duration_is_5_rounds() -> void:
	assert_eq(AsciiMapEnvironment.ALERT_DURATION_ROUNDS[AsciiMapEnvironment.AlertState.ALERT], 5)

# -- s56.6.4 KansenDensity constants ------------------------------------------

func test_kansen_none_exposure_interval_is_0() -> void:
	assert_eq(AsciiMapEnvironment.exposure_interval(AsciiMapEnvironment.KansenDensity.NONE), 0)

func test_kansen_low_exposure_interval_is_10() -> void:
	assert_eq(AsciiMapEnvironment.exposure_interval(AsciiMapEnvironment.KansenDensity.LOW), 10)

func test_kansen_moderate_exposure_interval_is_5() -> void:
	assert_eq(AsciiMapEnvironment.exposure_interval(AsciiMapEnvironment.KansenDensity.MODERATE), 5)

func test_kansen_high_exposure_interval_is_1() -> void:
	assert_eq(AsciiMapEnvironment.exposure_interval(AsciiMapEnvironment.KansenDensity.HIGH), 1)

func test_kansen_low_exposure_tn_is_10() -> void:
	assert_eq(AsciiMapEnvironment.exposure_tn(AsciiMapEnvironment.KansenDensity.LOW), 10)

func test_kansen_moderate_exposure_tn_is_15() -> void:
	assert_eq(AsciiMapEnvironment.exposure_tn(AsciiMapEnvironment.KansenDensity.MODERATE), 15)

func test_kansen_high_exposure_tn_is_20() -> void:
	assert_eq(AsciiMapEnvironment.exposure_tn(AsciiMapEnvironment.KansenDensity.HIGH), 20)

func test_kansen_low_spell_disruption_is_5() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_SPELL_DISRUPTION_TN[AsciiMapEnvironment.KansenDensity.LOW], 5)

func test_kansen_moderate_spell_disruption_is_10() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_SPELL_DISRUPTION_TN[AsciiMapEnvironment.KansenDensity.MODERATE], 10)

func test_kansen_high_spell_disruption_is_15() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_SPELL_DISRUPTION_TN[AsciiMapEnvironment.KansenDensity.HIGH], 15)

func test_kansen_moderate_whisper_tn_is_10() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_WHISPER_TN[AsciiMapEnvironment.KansenDensity.MODERATE], 10)

func test_kansen_high_whisper_tn_is_15() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_WHISPER_TN[AsciiMapEnvironment.KansenDensity.HIGH], 15)

func test_kansen_low_banishment_tn_is_15() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_BANISHMENT_TN[AsciiMapEnvironment.KansenDensity.LOW], 15)

func test_kansen_moderate_banishment_tn_is_20() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_BANISHMENT_TN[AsciiMapEnvironment.KansenDensity.MODERATE], 20)

func test_kansen_high_banishment_tn_is_25() -> void:
	assert_eq(AsciiMapEnvironment.KANSEN_BANISHMENT_TN[AsciiMapEnvironment.KansenDensity.HIGH], 25)

func test_jade_suppression_radius_is_3() -> void:
	assert_eq(AsciiMapEnvironment.JADE_SUPPRESSION_RADIUS, 3)

func test_sense_kansen_tn_is_15() -> void:
	assert_eq(AsciiMapEnvironment.SENSE_KANSEN_TN, 15)

# -- density_from_ptl ---------------------------------------------------------

func test_ptl_below_3_is_none() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(2.9), AsciiMapEnvironment.KansenDensity.NONE)

func test_ptl_0_is_none() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(0.0), AsciiMapEnvironment.KansenDensity.NONE)

func test_ptl_3_is_low() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(3.0), AsciiMapEnvironment.KansenDensity.LOW)

func test_ptl_5_is_low() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(5.9), AsciiMapEnvironment.KansenDensity.LOW)

func test_ptl_6_is_moderate() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(6.0), AsciiMapEnvironment.KansenDensity.MODERATE)

func test_ptl_8_is_moderate() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(8.9), AsciiMapEnvironment.KansenDensity.MODERATE)

func test_ptl_9_is_high() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(9.0), AsciiMapEnvironment.KansenDensity.HIGH)

func test_ptl_10_is_high() -> void:
	assert_eq(AsciiMapEnvironment.density_from_ptl(10.0), AsciiMapEnvironment.KansenDensity.HIGH)
