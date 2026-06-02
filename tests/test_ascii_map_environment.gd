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

# -- biome_for_terrain (PROVISIONAL fallback) ---------------------------------

func test_biome_mountains_is_northern_highland() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.MOUNTAINS),
		AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND)

func test_biome_forest_is_shinomen() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.FOREST),
		AsciiMapEnvironment.BiomeType.SHINOMEN)

func test_biome_coastal_is_eastern_coast() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.COASTAL),
		AsciiMapEnvironment.BiomeType.EASTERN_COAST)

func test_biome_river_delta_is_eastern_coast() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.RIVER_DELTA),
		AsciiMapEnvironment.BiomeType.EASTERN_COAST)

func test_biome_swamp_is_southern_border() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.SWAMP),
		AsciiMapEnvironment.BiomeType.SOUTHERN_BORDER)

func test_biome_wasteland_is_southern_border() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.WASTELAND),
		AsciiMapEnvironment.BiomeType.SOUTHERN_BORDER)

func test_biome_hills_is_central_plains() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.HILLS),
		AsciiMapEnvironment.BiomeType.CENTRAL_PLAINS)

func test_biome_plains_is_central_plains() -> void:
	assert_eq(AsciiMapEnvironment.biome_for_terrain(Enums.TerrainType.PLAINS),
		AsciiMapEnvironment.BiomeType.CENTRAL_PLAINS)

# -- apply_biome_weather_conversion (s56.6.2 LOCKED) -------------------------

func test_rain_northern_highland_winter_becomes_snow() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.RAIN,
			AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.SNOW)

func test_storm_northern_highland_winter_becomes_blizzard() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.STORM,
			AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.BLIZZARD)

func test_rain_central_plains_winter_becomes_snow() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.RAIN,
			AsciiMapEnvironment.BiomeType.CENTRAL_PLAINS,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.SNOW)

func test_rain_western_steppe_winter_becomes_snow() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.RAIN,
			AsciiMapEnvironment.BiomeType.WESTERN_STEPPE,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.SNOW)

func test_storm_central_plains_winter_stays_storm() -> void:
	# Only NORTHERN_HIGHLAND gets blizzard conversion per s56.6.2.
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.STORM,
			AsciiMapEnvironment.BiomeType.CENTRAL_PLAINS,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.STORM)

func test_rain_northern_highland_summer_stays_rain() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.RAIN,
			AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND,
			TimeSystem.Season.SUMMER),
		AsciiMapEnvironment.WeatherState.RAIN)

func test_rain_eastern_coast_winter_stays_rain() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.RAIN,
			AsciiMapEnvironment.BiomeType.EASTERN_COAST,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.RAIN)

func test_clear_northern_highland_winter_stays_clear() -> void:
	assert_eq(
		AsciiMapEnvironment.apply_biome_weather_conversion(
			AsciiMapEnvironment.WeatherState.CLEAR,
			AsciiMapEnvironment.BiomeType.NORTHERN_HIGHLAND,
			TimeSystem.Season.WINTER),
		AsciiMapEnvironment.WeatherState.CLEAR)

# -- weather_to_fov_modifier (s56.6.2 LOCKED) ---------------------------------

func test_fov_modifier_clear_is_zero() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.CLEAR), 0)

func test_fov_modifier_wind_is_zero() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.WIND), 0)

func test_fov_modifier_rain_is_2() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.RAIN), 2)

func test_fov_modifier_storm_is_4() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.STORM), 4)

func test_fov_modifier_typhoon_is_4() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.TYPHOON), 4)

func test_fov_modifier_mist_is_3() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.MIST), 3)

func test_fov_modifier_snow_is_2() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.SNOW), 2)

func test_fov_modifier_blizzard_is_4() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(
		AsciiMapEnvironment.WeatherState.BLIZZARD), 4)

func test_fov_modifier_unknown_state_defaults_to_zero() -> void:
	assert_eq(AsciiMapEnvironment.weather_to_fov_modifier(999), 0)
