class_name KansenSystem
## s56.6.4 Kansen Environmental Hazards on ASCII Maps --- LOCKED.
## Generates per-tile kansen density grids and applies jade suppression/banishment.
## Density tiers: NONE=0, LOW=1, MODERATE=2, HIGH=3 (AsciiMapEnvironment.KansenDensity).
## For maho-related quest seeds, density varies spatially around objective positions.
## For all other seeds, density is flat based on Province Taint Level (PTL).
## All static functions; no instance state.

const _KD := AsciiMapEnvironment.KansenDensity

# -- Quest seed classification ------------------------------------------------

# Quest seeds that generate spatially-varying kansen density (maho-origin missions).
# For these, density is HIGH within 2 tiles of an objective, MODERATE within 5,
# LOW within 10, outer tiles use base PTL density (one tier below objective zone).
const MAHO_QUEST_SEEDS: Array[String] = [
	"MAHO_CULT",
	"PROVINCE_TAINT_MANIFESTATION",
	"ONI_MANIFESTATION",
	"HUNT_THE_DEFECTOR",
	"GAKI_DO_MANIFESTATION",
	"TOSHIGOKU_BLEED",
]

# -- Spatial density thresholds (Chebyshev distance from objective tile) -------

# Tiles within this Chebyshev distance of an objective → HIGH density.
const HIGH_DENSITY_RADIUS: int = 2

# Tiles within this Chebyshev distance of an objective → MODERATE density.
const MODERATE_DENSITY_RADIUS: int = 5

# Tiles within this Chebyshev distance of an objective → LOW density.
const LOW_DENSITY_RADIUS: int = 10

# -- Public API ---------------------------------------------------------------

## Generates a flat PackedByteArray density grid of size map.width * map.height.
## Each byte is an AsciiMapEnvironment.KansenDensity int (0=NONE … 3=HIGH).
##
## map                : AsciiMapData whose dimensions define the grid.
## ptl                : Province Taint Level (0.0–10.0+) for baseline density.
## quest_seed_type    : String from MAHO_QUEST_SEEDS for spatial overlay, else flat.
## objective_positions: tiles representing the mission objective (ritual chamber etc.).
static func generate_density_grid(
		map: AsciiMapData,
		ptl: float,
		quest_seed_type: String,
		objective_positions: Array[Vector2i]
) -> PackedByteArray:
	var w: int = map.width
	var h: int = map.height
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(w * h)

	var base_density: int = AsciiMapEnvironment.density_from_ptl(ptl)

	if quest_seed_type in MAHO_QUEST_SEEDS and objective_positions.size() > 0:
		# Outer areas: one tier below PTL baseline, floor at NONE.
		var outer_density: int = maxi(_KD.NONE, base_density - 1)
		for i in range(w * h):
			grid[i] = outer_density

		# Overlay objective-proximity zones using Chebyshev distance.
		for y in range(h):
			for x in range(w):
				var min_d: int = _min_chebyshev_distance(x, y, objective_positions)

				var overlay: int
				if min_d <= HIGH_DENSITY_RADIUS:
					overlay = _KD.HIGH
				elif min_d <= MODERATE_DENSITY_RADIUS:
					overlay = _KD.MODERATE
				elif min_d <= LOW_DENSITY_RADIUS:
					overlay = _KD.LOW
				else:
					overlay = outer_density

				grid[y * w + x] = overlay
	else:
		# Non-maho quest: flat density derived from PTL.
		for i in range(w * h):
			grid[i] = base_density

	return grid

## Returns the kansen density at tile (x, y) from a density grid.
static func density_at(grid: PackedByteArray, map_width: int, x: int, y: int) -> int:
	if x < 0 or y < 0:
		return _KD.NONE
	var idx: int = y * map_width + x
	if idx >= grid.size():
		return _KD.NONE
	return grid[idx]

## Applies jade suppression: reduces density by one tier within JADE_SUPPRESSION_RADIUS
## tiles (Chebyshev) of the center tile. Returns a new grid (does not mutate input).
## Jade protection is consumed on placement and lasts for the remainder of the mission.
static func apply_jade_suppression(
		grid: PackedByteArray,
		map_width: int,
		map_height: int,
		center: Vector2i
) -> PackedByteArray:
	var result: PackedByteArray = grid.duplicate()
	var radius: int = AsciiMapEnvironment.JADE_SUPPRESSION_RADIUS
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x: int = center.x + dx
			var y: int = center.y + dy
			if x < 0 or x >= map_width or y < 0 or y >= map_height:
				continue
			var idx: int = y * map_width + x
			if result[idx] > _KD.NONE:
				result[idx] = result[idx] - 1
	return result

## Applies banishment: reduces density by one tier on the target tile and its
## immediately adjacent tiles (4 cardinal directions). Returns a new grid.
static func apply_banishment(
		grid: PackedByteArray,
		map_width: int,
		map_height: int,
		x: int,
		y: int
) -> PackedByteArray:
	var result: PackedByteArray = grid.duplicate()
	var targets: Array[Vector2i] = [
		Vector2i(x, y),
		Vector2i(x + 1, y),
		Vector2i(x - 1, y),
		Vector2i(x, y + 1),
		Vector2i(x, y - 1),
	]
	for pos: Vector2i in targets:
		if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
			continue
		var idx: int = pos.y * map_width + pos.x
		if result[idx] > _KD.NONE:
			result[idx] = result[idx] - 1
	return result

# -- Internal helpers ---------------------------------------------------------

## Minimum Chebyshev distance from (x, y) to any position in a list.
static func _min_chebyshev_distance(x: int, y: int, positions: Array[Vector2i]) -> int:
	var min_d: int = 9999
	for pos: Vector2i in positions:
		var d: int = maxi(absi(x - pos.x), absi(y - pos.y))
		if d < min_d:
			min_d = d
	return min_d
