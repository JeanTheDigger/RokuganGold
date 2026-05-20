extends GutTest
## Tests for DayOrchestrator._process_wall_seasonal_pressure per GDD s2.4.3, s2.4.10.


func _make_wall_tower(sid: int, province_id: int, si: int = 10) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = sid
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = si
	return s


func _make_wall_province(pid: int, ss: int = 0, adjacent: Array[int] = []) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.shadowlands_strength = ss
	p.province_taint_level = 0.0
	p.adjacent_province_ids = adjacent
	return p


# =============================================================================
# Empty / No Wall Towers
# =============================================================================

func test_no_settlements_returns_empty() -> void:
	var result: Dictionary = DayOrchestrator._process_wall_seasonal_pressure(
		[], {}, TimeSystem.Season.SPRING, {}
	)
	assert_eq(result, {})


func test_non_wall_settlement_not_processed() -> void:
	var s := SettlementData.new()
	s.settlement_id = 1
	s.province_id = 10
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = 10
	var p := _make_wall_province(10, 0)
	var result: Dictionary = DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.WINTER, {}
	)
	assert_eq(result, {})


# =============================================================================
# SI Decay — Seasonal Pressure (s2.4.3)
# =============================================================================

func test_spring_si_decay_1() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 0)
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SPRING, meta
	)
	assert_eq(s.wall_si, 9, "Spring baseline decay -1")


func test_summer_si_no_decay() -> void:
	var s := _make_wall_tower(1, 10, 8)
	var p := _make_wall_province(10, 0)
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SUMMER, meta
	)
	assert_eq(s.wall_si, 8, "Summer baseline decay 0")


func test_winter_si_decay_2() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 0)
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.WINTER, meta
	)
	assert_eq(s.wall_si, 8, "Winter baseline decay -2")


func test_si_clamped_at_zero() -> void:
	var s := _make_wall_tower(1, 10, 1)
	var p := _make_wall_province(10, 0)
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.WINTER, meta
	)
	assert_eq(s.wall_si, 0, "SI cannot go below 0")


# =============================================================================
# SI Decay — Shadowlands Strength Modifier (s2.4.10)
# =============================================================================

func test_medium_ss_adds_decay_spring() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 5)  # SS=5 → Medium
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SPRING, meta
	)
	# Spring base -1, Medium +0.5 → total 1.5 → floor to 1
	assert_eq(s.wall_si, 9, "Medium SS spring: 1.5 floored to 1")


func test_high_ss_adds_decay_winter() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 9)  # SS=9 → High
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.WINTER, meta
	)
	# Winter base -2, High +1.0 → total 3.0 → floor to 3
	assert_eq(s.wall_si, 7, "High SS winter: base -2 + high -1 = -3")


func test_low_ss_no_extra_decay() -> void:
	var s := _make_wall_tower(1, 10, 8)
	var p := _make_wall_province(10, 3)  # SS=3 → Low
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.AUTUMN, meta
	)
	# Autumn base -1, Low SS → no extra
	assert_eq(s.wall_si, 7)


# =============================================================================
# Result Dict Structure
# =============================================================================

func test_result_has_si_decay_results() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 0)
	var result: Dictionary = DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SPRING, {}
	)
	assert_true(result.has("si_decay_results"))
	assert_eq(result["si_decay_results"].size(), 1)

func test_result_has_ptl_updates() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 0)
	var result: Dictionary = DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SPRING, {}
	)
	assert_true(result.has("ptl_updates"))

func test_si_decay_result_fields() -> void:
	var s := _make_wall_tower(5, 10, 10)
	var p := _make_wall_province(10, 0)
	var result: Dictionary = DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.WINTER, {}
	)
	var entry: Dictionary = result["si_decay_results"][0]
	assert_eq(entry["settlement_id"], 5)
	assert_eq(entry["province_id"], 10)
	assert_eq(entry["old_si"], 10)
	assert_eq(entry["new_si"], 8)
	assert_eq(entry["decay_applied"], 2)


# =============================================================================
# Adjacent Bleed (s2.4.3)
# =============================================================================

func test_adjacent_bleed_accumulates_in_season_meta() -> void:
	var s1 := _make_wall_tower(1, 10, 4)  # SI=4, at bleed threshold
	var s2 := _make_wall_tower(2, 20, 8)  # adjacent
	var p1 := _make_wall_province(10, 0, [20])
	var p2 := _make_wall_province(20, 0, [10])
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s1, s2], {10: p1, 20: p2}, TimeSystem.Season.SUMMER, meta
	)
	# No SI decay (summer), s1.wall_si stays at 4, bleed triggers
	# adjacent bleed = 0.5 per season — accumulates in season_meta
	assert_true(meta.has("_wall_bleed_accum"), "Bleed accum stored in season_meta")
	var accum: Dictionary = meta["_wall_bleed_accum"]
	assert_true("2" in accum, "Settlement 2 has bleed accumulator entry")
	assert_almost_eq(float(accum["2"]), 0.5, 0.001)
	assert_eq(s2.wall_si, 8, "Accum not yet >= 1.0 so no SI loss this season")


func test_adjacent_bleed_applies_when_accum_reaches_one() -> void:
	var s1 := _make_wall_tower(1, 10, 4)  # SI=4, at threshold
	var s2 := _make_wall_tower(2, 20, 8)
	var p1 := _make_wall_province(10, 0, [20])
	var p2 := _make_wall_province(20, 0, [10])
	# Pre-load accum with 0.5 from a previous season
	var meta: Dictionary = {"_wall_bleed_accum": {"2": 0.5}}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s1, s2], {10: p1, 20: p2}, TimeSystem.Season.SUMMER, meta
	)
	# 0.5 (existing) + 0.5 (this season) = 1.0 → apply -1 SI, reset to 0
	assert_eq(s2.wall_si, 7, "Bleed applied when accum hits 1.0")
	var accum: Dictionary = meta["_wall_bleed_accum"]
	assert_almost_eq(float(accum["2"]), 0.0, 0.001, "Accum reset after applying bleed")


func test_no_bleed_when_si_above_threshold() -> void:
	var s1 := _make_wall_tower(1, 10, 5)  # SI=5, above ADJACENT_BLEED_THRESHOLD=4
	var s2 := _make_wall_tower(2, 20, 8)
	var p1 := _make_wall_province(10, 0, [20])
	var p2 := _make_wall_province(20, 0)
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s1, s2], {10: p1, 20: p2}, TimeSystem.Season.SUMMER, meta
	)
	var accum: Dictionary = meta.get("_wall_bleed_accum", {})
	assert_false("2" in accum, "No bleed when SI above threshold")


func test_bleed_only_affects_adjacent_wall_provinces() -> void:
	var s1 := _make_wall_tower(1, 10, 4)  # SI=4, at threshold
	var s2 := _make_wall_tower(2, 30, 8)  # NOT adjacent to province 10
	var p1 := _make_wall_province(10, 0, [20])  # adjacent to 20, not 30
	var p2_nonwall := ProvinceData.new()
	p2_nonwall.province_id = 20
	var p3 := _make_wall_province(30, 0)
	var meta: Dictionary = {}
	DayOrchestrator._process_wall_seasonal_pressure(
		[s1, s2], {10: p1, 20: p2_nonwall, 30: p3}, TimeSystem.Season.SUMMER, meta
	)
	var accum: Dictionary = meta.get("_wall_bleed_accum", {})
	# Province 30 is not adjacent to province 10, so no bleed to settlement 2
	assert_false("2" in accum, "Non-adjacent wall tower not affected")


# =============================================================================
# PTL Accumulation (s2.4.2)
# =============================================================================

func test_ptl_baseline_per_season_healthy_wall() -> void:
	var s := _make_wall_tower(1, 10, 10)  # SI=10, healthy
	var p := _make_wall_province(10, 0)
	p.province_taint_level = 0.0
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SPRING, {}
	)
	# SI=10 > SI_DEGRADED_THRESHOLD=5, so only baseline 0.1
	assert_almost_eq(p.province_taint_level, 0.1, 0.001,
		"Healthy wall adds 0.1 PTL per season baseline")


func test_ptl_extra_when_si_degraded() -> void:
	var s := _make_wall_tower(1, 10, 5)  # SI=5, at degraded threshold
	var p := _make_wall_province(10, 0)
	p.province_taint_level = 0.0
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SUMMER, {}  # Summer: 0 decay, SI stays 5
	)
	# SI=5 <= SI_DEGRADED_THRESHOLD, so baseline 0.1 + extra 0.5 = 0.6
	assert_almost_eq(p.province_taint_level, 0.6, 0.001,
		"Degraded wall (SI<=5) adds 0.6 PTL per season")


func test_ptl_extra_when_si_below_degraded_threshold() -> void:
	var s := _make_wall_tower(1, 10, 3)  # SI=3, well below degraded threshold
	var p := _make_wall_province(10, 0)
	p.province_taint_level = 1.0
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SUMMER, {}
	)
	# baseline 0.1 + extra 0.5 = 0.6
	assert_almost_eq(p.province_taint_level, 1.6, 0.001)


func test_ptl_clamped_at_10() -> void:
	var s := _make_wall_tower(1, 10, 3)  # degraded, +0.6 per season
	var p := _make_wall_province(10, 0)
	p.province_taint_level = 9.8
	DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SUMMER, {}
	)
	assert_almost_eq(p.province_taint_level, 10.0, 0.001, "PTL clamped at 10.0")


func test_ptl_update_result_fields() -> void:
	var s := _make_wall_tower(1, 10, 10)
	var p := _make_wall_province(10, 0)
	p.province_taint_level = 1.0
	var result: Dictionary = DayOrchestrator._process_wall_seasonal_pressure(
		[s], {10: p}, TimeSystem.Season.SPRING, {}
	)
	var updates: Array = result["ptl_updates"]
	assert_eq(updates.size(), 1)
	var entry: Dictionary = updates[0]
	assert_eq(entry["province_id"], 10)
	assert_almost_eq(float(entry["ptl_gain"]), 0.1, 0.001)
	assert_almost_eq(float(entry["new_ptl"]), 1.1, 0.001)


# =============================================================================
# Multiple Wall Towers
# =============================================================================

func test_two_independent_towers_decay_independently() -> void:
	var s1 := _make_wall_tower(1, 10, 10)
	var s2 := _make_wall_tower(2, 20, 8)
	var p1 := _make_wall_province(10, 0)
	var p2 := _make_wall_province(20, 9)  # High SS
	DayOrchestrator._process_wall_seasonal_pressure(
		[s1, s2], {10: p1, 20: p2}, TimeSystem.Season.WINTER, {}
	)
	# p1: Winter base -2, no SS → new_si = 8
	assert_eq(s1.wall_si, 8)
	# p2: Winter base -2, High SS +1 → -3 total → new_si = 5
	assert_eq(s2.wall_si, 5)


func test_two_towers_both_generate_ptl() -> void:
	var s1 := _make_wall_tower(1, 10, 10)
	var s2 := _make_wall_tower(2, 20, 10)
	var p1 := _make_wall_province(10, 0)
	var p2 := _make_wall_province(20, 0)
	p1.province_taint_level = 0.0
	p2.province_taint_level = 0.0
	DayOrchestrator._process_wall_seasonal_pressure(
		[s1, s2], {10: p1, 20: p2}, TimeSystem.Season.SPRING, {}
	)
	assert_almost_eq(p1.province_taint_level, 0.1, 0.001)
	assert_almost_eq(p2.province_taint_level, 0.1, 0.001)
