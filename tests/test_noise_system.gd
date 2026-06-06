extends GutTest
## Tests for NoiseSystem (s56.6.3 Enemy Alert and Investigation System --- LOCKED).

const _T := Enums.TileType
const _NL := AsciiMapEnvironment.NoiseLevel
const _WS := AsciiMapEnvironment.WeatherState

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _open_map(w: int = 31, h: int = 31) -> AsciiMapData:
	var m: AsciiMapData = AsciiMapData.new()
	m.width = w
	m.height = h
	m.init_tiles(_T.FLOOR_STONE)
	return m

# Returns a map that is a single row of floor flanked by walls (EW corridor).
# Width 20, height 5: walls on rows 0,1,3,4; floor on row 2.
func _ew_corridor_map() -> AsciiMapData:
	var m: AsciiMapData = AsciiMapData.new()
	m.width = 20
	m.height = 5
	m.init_tiles(_T.WALL_STONE)
	for x in range(20):
		m.set_tile(x, 2, _T.FLOOR_STONE)  # corridor floor
	return m

# ---------------------------------------------------------------------------
# Tile classification
# ---------------------------------------------------------------------------

func test_walls_are_blocking() -> void:
	assert_true(NoiseSystem.is_blocking_tile(_T.WALL_STONE))
	assert_true(NoiseSystem.is_blocking_tile(_T.WALL_WOOD))
	assert_true(NoiseSystem.is_blocking_tile(_T.WALL_PAPER))

func test_void_is_blocking() -> void:
	assert_true(NoiseSystem.is_blocking_tile(_T.VOID))

func test_floor_tiles_are_not_blocking() -> void:
	assert_false(NoiseSystem.is_blocking_tile(_T.FLOOR_STONE))
	assert_false(NoiseSystem.is_blocking_tile(_T.FLOOR_GRASS))
	assert_false(NoiseSystem.is_blocking_tile(_T.FLOOR_WOOD))

func test_trees_are_not_blocking_for_noise() -> void:
	# Trees dampen noise but do not block it (unlike LOS).
	assert_false(NoiseSystem.is_blocking_tile(_T.TREE_EVERGREEN))
	assert_false(NoiseSystem.is_blocking_tile(_T.BAMBOO))

# ---------------------------------------------------------------------------
# noise_level_up helper
# ---------------------------------------------------------------------------

func test_noise_level_up_quiet_to_moderate() -> void:
	assert_eq(NoiseSystem.noise_level_up(_NL.QUIET), _NL.MODERATE)

func test_noise_level_up_moderate_to_loud() -> void:
	assert_eq(NoiseSystem.noise_level_up(_NL.MODERATE), _NL.LOUD)

func test_noise_level_up_very_loud_stays_very_loud() -> void:
	assert_eq(NoiseSystem.noise_level_up(_NL.VERY_LOUD), _NL.VERY_LOUD)

# ---------------------------------------------------------------------------
# Corridor axis detection
# ---------------------------------------------------------------------------

func test_ew_corridor_detected_when_walls_north_and_south() -> void:
	# Corridor: floor at (5, 2) with walls at (5, 1) and (5, 3).
	var m: AsciiMapData = _open_map()
	m.set_tile(5, 1, _T.WALL_STONE)
	m.set_tile(5, 3, _T.WALL_STONE)
	assert_true(NoiseSystem.is_corridor_ew(m, 5, 2))

func test_ew_corridor_false_when_open_north() -> void:
	var m: AsciiMapData = _open_map()
	# Only wall to south, not north.
	m.set_tile(5, 3, _T.WALL_STONE)
	assert_false(NoiseSystem.is_corridor_ew(m, 5, 2))

func test_ns_corridor_detected_when_walls_east_and_west() -> void:
	var m: AsciiMapData = _open_map()
	m.set_tile(4, 5, _T.WALL_STONE)
	m.set_tile(6, 5, _T.WALL_STONE)
	assert_true(NoiseSystem.is_corridor_ns(m, 5, 5))

# ---------------------------------------------------------------------------
# SILENT: no propagation
# ---------------------------------------------------------------------------

func test_silent_returns_empty() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 15, 15, _NL.SILENT, _WS.CLEAR, false)
	assert_eq(reaches.size(), 0)

# ---------------------------------------------------------------------------
# Open-ground radius in clear weather
# ---------------------------------------------------------------------------

func test_quiet_radius_excludes_source_tile() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 15, 15, _NL.QUIET, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(15, 15)))

func test_quiet_reaches_tile_at_distance_3() -> void:
	# QUIET radius = 3; a tile 3 steps away should be reached.
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(13, 10)))

func test_quiet_does_not_reach_tile_at_distance_4() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(14, 10)))

func test_moderate_reaches_tile_at_distance_6() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.MODERATE, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(16, 10)))

func test_moderate_does_not_reach_tile_at_distance_7() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.MODERATE, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(17, 10)))

func test_loud_reaches_tile_at_distance_12() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 5, 15, _NL.LOUD, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(17, 15)))

func test_loud_does_not_reach_tile_at_distance_13() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 5, 15, _NL.LOUD, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(18, 15)))

# ---------------------------------------------------------------------------
# Wall blocking
# ---------------------------------------------------------------------------

func test_wall_blocks_propagation() -> void:
	# Source at (5, 5), wall at (6, 5), target at (7, 5) — should not be reached.
	var m: AsciiMapData = _open_map()
	m.set_tile(6, 5, _T.WALL_STONE)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 5, 5, _NL.LOUD, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(7, 5)))

func test_wall_does_not_block_perpendicular_path() -> void:
	# Wall at (6, 5) blocks east, but north path (5,4 → 5,3 …) is unobstructed.
	var m: AsciiMapData = _open_map()
	m.set_tile(6, 5, _T.WALL_STONE)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 5, 5, _NL.LOUD, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(5, 3)))

func test_wall_tile_itself_not_in_reaches() -> void:
	var m: AsciiMapData = _open_map()
	m.set_tile(6, 5, _T.WALL_STONE)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 5, 5, _NL.LOUD, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(6, 5)))

# ---------------------------------------------------------------------------
# Corridor extension (50% extra range along corridor axis)
# ---------------------------------------------------------------------------

func test_corridor_extends_loud_range_to_18_tiles() -> void:
	# LOUD base radius = 12. Each step along EW corridor costs 2/3 instead of 1.
	# Max steps = floor(12 / (2/3)) = 18. Source at x=0, y=2 in corridor.
	var m: AsciiMapData = _ew_corridor_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 0, 2, _NL.LOUD, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(18, 2)))

func test_corridor_does_not_extend_beyond_18_tiles() -> void:
	var m: AsciiMapData = _ew_corridor_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 0, 2, _NL.LOUD, _WS.CLEAR, false)
	# At x=19 the cost would be 19 * (2/3) = 12.67 > 12 — out of range.
	assert_false(reaches.has(Vector2i(19, 2)))

func test_corridor_bonus_only_applies_along_axis() -> void:
	# In the EW corridor, moving perpendicular (NS) would be into walls — blocked.
	# So we only get corridor bonus along X.
	var m: AsciiMapData = _ew_corridor_map()
	# The corridor floor is at y=2. Tiles above/below are walls, so no NS reach.
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 0, 2, _NL.QUIET, _WS.CLEAR, false)
	# QUIET = radius 3; along corridor with bonus: 3 / (2/3) = 4.5 → 4 tiles.
	assert_true(reaches.has(Vector2i(4, 2)))
	assert_false(reaches.has(Vector2i(0, 1)))  # wall above, blocked

# ---------------------------------------------------------------------------
# Vegetation damping (radius reduced 25%)
# ---------------------------------------------------------------------------

func test_vegetation_reduces_quiet_range() -> void:
	# QUIET radius = 3. Vegetation costs 4/3 per step.
	# Effective reach = 3 / (4/3) = 2.25 → only 2 tiles in a straight vegetation path.
	var m: AsciiMapData = _open_map()
	for x in range(31):
		for y in range(31):
			m.set_tile(x, y, _T.BUSH)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	# 2 tiles along X: (12, 10) is 2 steps × 4/3 = 8/3 = 2.67 > 3? No wait.
	# 2 steps × 4/3 = 2.67 ≤ 3 → reached.
	# 3 steps × 4/3 = 4.0 > 3 → not reached.
	assert_true(reaches.has(Vector2i(12, 10)))
	assert_false(reaches.has(Vector2i(13, 10)))

func test_water_reduces_quiet_range() -> void:
	# Same math as vegetation.
	var m: AsciiMapData = _open_map()
	for x in range(31):
		for y in range(31):
			m.set_tile(x, y, _T.WATER_SHALLOW)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(12, 10)))
	assert_false(reaches.has(Vector2i(13, 10)))

# ---------------------------------------------------------------------------
# Rain weather (additional 25% budget reduction)
# ---------------------------------------------------------------------------

func test_rain_reduces_quiet_budget() -> void:
	# QUIET budget = 3. Rain reduces to 3 * 0.75 = 2.25.
	# Tile at distance 3 not reached; tile at distance 2 still reached.
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.RAIN, false)
	assert_true(reaches.has(Vector2i(12, 10)))
	assert_false(reaches.has(Vector2i(13, 10)))

func test_storm_also_reduces_budget() -> void:
	var m: AsciiMapData = _open_map()
	var reaches_clear: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	var reaches_storm: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.STORM, false)
	# Storm reduces range; clear should reach more tiles.
	assert_true(reaches_clear.size() > reaches_storm.size())

func test_clear_weather_no_budget_reduction() -> void:
	# QUIET reaches 3 tiles in clear weather, not rain-reduced.
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(13, 10)))

# ---------------------------------------------------------------------------
# Ravine echo (elevates noise one level)
# ---------------------------------------------------------------------------

func test_ravine_elevates_quiet_to_moderate() -> void:
	# QUIET normally reaches 3 tiles; elevated to MODERATE reaches 6 tiles.
	var m: AsciiMapData = _open_map()
	var normal_reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, false)
	var ravine_reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.QUIET, _WS.CLEAR, true)
	assert_false(normal_reaches.has(Vector2i(16, 10)))
	assert_true(ravine_reaches.has(Vector2i(16, 10)))

func test_ravine_very_loud_stays_very_loud() -> void:
	# VERY_LOUD (9999 radius) remains map-wide — ravine doesn't exceed it.
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 15, 15, _NL.VERY_LOUD, _WS.CLEAR, true)
	assert_true(reaches.size() > 0)

# ---------------------------------------------------------------------------
# VERY_LOUD: map-wide propagation
# ---------------------------------------------------------------------------

func test_very_loud_reaches_far_tile_in_open_space() -> void:
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 0, 0, _NL.VERY_LOUD, _WS.CLEAR, false)
	assert_true(reaches.has(Vector2i(30, 30)))

func test_very_loud_still_blocked_by_wall() -> void:
	# VERY_LOUD propagates everywhere but walls stop it.
	var m: AsciiMapData = _open_map()
	# Build a sealed room: source at (0,0) in an enclosed space.
	for x in range(31):
		m.set_tile(x, 2, _T.WALL_STONE)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 1, 1, _NL.VERY_LOUD, _WS.CLEAR, false)
	# Tile at (1, 5) is behind the wall — not reachable.
	assert_false(reaches.has(Vector2i(1, 5)))

# ---------------------------------------------------------------------------
# Combined: rain + vegetation stacking
# ---------------------------------------------------------------------------

func test_rain_and_vegetation_stack() -> void:
	# MODERATE base = 6. Rain reduces to 4.5. Vegetation steps cost 4/3.
	# 3 steps × 4/3 = 4.0 ≤ 4.5 → reached. 4 steps × 4/3 = 5.33 > 4.5 → not reached.
	var m: AsciiMapData = _open_map()
	for x in range(31):
		for y in range(31):
			m.set_tile(x, y, _T.BUSH)
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 10, 10, _NL.MODERATE, _WS.RAIN, false)
	assert_true(reaches.has(Vector2i(13, 10)))
	assert_false(reaches.has(Vector2i(14, 10)))


# ---------------------------------------------------------------------------
# Section 41 regression: VOID must count as wall for corridor bonus detection
# ---------------------------------------------------------------------------

func test_void_counts_as_wall_for_ew_corridor_bonus() -> void:
	# VOID tiles flanking a floor row must trigger the EW corridor bonus,
	# just like WALL_STONE would. Budget=6 for MODERATE; corridor cost 2/3
	# per step → 8 steps = 5.33 budget consumed < 6 → tile at distance 8
	# reachable. On an open map (no flanking walls) 8 steps costs 8.0 > 6.
	var m: AsciiMapData = AsciiMapData.new()
	m.width = 20
	m.height = 3
	m.init_tiles(_T.VOID)                     # fill with VOID
	for x in range(20):
		m.set_tile(x, 1, _T.FLOOR_STONE)      # single floor corridor on row 1
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 0, 1, _NL.MODERATE, _WS.CLEAR, false)
	# Without corridor bonus: 8 steps × 1.0 = 8 > 6 → not reachable.
	# With corridor bonus  : 8 steps × 2/3 = 5.33 ≤ 6 → reachable.
	assert_true(reaches.has(Vector2i(8, 1)),
		"VOID-flanked corridor must give noise the EW corridor bonus (reach 8 tiles at MODERATE)")


func test_void_does_not_count_as_corridor_on_open_map() -> void:
	# Sanity check: on an open FLOOR map (no perpendicular walls), the corridor
	# bonus is NOT triggered. Distance 7 must not be reachable at MODERATE.
	var m: AsciiMapData = _open_map()
	var reaches: Array[Vector2i] = NoiseSystem.compute_noise_reaches(
			m, 0, 15, _NL.MODERATE, _WS.CLEAR, false)
	assert_false(reaches.has(Vector2i(7, 15)),
		"7-step tile must not be reachable without corridor bonus (MODERATE budget = 6)")
