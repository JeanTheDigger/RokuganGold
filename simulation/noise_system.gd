class_name NoiseSystem
## s56.6.3 Enemy Alert and Investigation System — noise propagation --- LOCKED.
## Computes the set of map tiles that noise from a source position reaches.
## Walls block propagation entirely. Corridors extend range 50% along their axis.
## Vegetation and water tiles reduce range by 25% (cost multiplier 4/3).
## Ravine echo treats noise as one level higher. Rain weather reduces budget 25%.
## All static functions; no instance state.

const _T := Enums.TileType
const _NL := AsciiMapEnvironment.NoiseLevel
const _WS := AsciiMapEnvironment.WeatherState

# -- Tile classification constants --------------------------------------------

# Tiles that block noise propagation entirely (solid structural barriers).
const BLOCKING_TILES: Array[int] = [
	_T.VOID,
	_T.WALL_STONE,
	_T.WALL_WOOD,
	_T.WALL_PAPER,
]

# Tiles that dampen noise: reduce effective radius by 25% (cost = 4/3 per step).
# Vegetation: forested areas, undergrowth, bamboo, crops.
const VEGETATION_TILES: Array[int] = [
	_T.TREE_EVERGREEN,
	_T.TREE_DECIDUOUS,
	_T.TREE_CHERRY,
	_T.TREE_DEAD,
	_T.BAMBOO,
	_T.BUSH,
	_T.CROPS,
	_T.GROUNDCOVER,
	_T.FLOWERS,
]

# Tiles that dampen noise: streams mask sound, reducing radius by 25%.
const WATER_TILES: Array[int] = [
	_T.WATER_SHALLOW,
	_T.WATER_DEEP,
	_T.WATER_RAPID,
	_T.WATER_PADDY,
]

# Weather states that apply rainfall noise masking (additional 25% budget reduction).
const RAIN_WEATHER_STATES: Array[int] = [
	_WS.RAIN,
	_WS.STORM,
	_WS.TYPHOON,
]

# -- Propagation cost constants ------------------------------------------------

# Corridor bonus: noise travels 50% farther along corridor axis.
# Cost per step = 1 / 1.5 = 2/3.
const CORRIDOR_COST_MULT: float = 2.0 / 3.0

# Vegetation / water damping: radius reduced by 25%.
# Cost per step = 1 / 0.75 = 4/3.
const DAMPING_COST_MULT: float = 4.0 / 3.0

# Rain weather reduces total noise budget by 25%.
const RAIN_BUDGET_MULT: float = 0.75

# -- Public API ---------------------------------------------------------------

## Returns all map tiles (as Vector2i) that noise from (sx, sy) reaches.
## noise_level : AsciiMapEnvironment.NoiseLevel int
## weather_state : AsciiMapEnvironment.WeatherState int
## is_ravine : true when the map is a ravine/canyon (all noise +1 level)
static func compute_noise_reaches(
		map: AsciiMapData,
		sx: int, sy: int,
		noise_level: int,
		weather_state: int,
		is_ravine: bool
) -> Array[Vector2i]:
	if noise_level == _NL.SILENT:
		return []

	# Ravine echo: treat noise as one level higher (capped at VERY_LOUD).
	var effective_level: int = noise_level
	if is_ravine and noise_level < _NL.VERY_LOUD:
		effective_level = noise_level + 1

	var budget: float = float(AsciiMapEnvironment.NOISE_RADIUS[effective_level])

	# Rain weather: additional 25% radius reduction (stacks with water tile damping).
	if weather_state in RAIN_WEATHER_STATES:
		budget *= RAIN_BUDGET_MULT

	return _dijkstra(map, sx, sy, budget)

## Returns the noise level one step higher (capped at VERY_LOUD).
## Used for ravine echo and other mechanics that elevate noise.
static func noise_level_up(noise_level: int) -> int:
	if noise_level >= _NL.VERY_LOUD:
		return _NL.VERY_LOUD
	return noise_level + 1

## Returns true if the tile blocks noise propagation.
static func is_blocking_tile(tile_type: int) -> bool:
	return tile_type in BLOCKING_TILES

## Returns true if the tile is an EW corridor at (x, y) on the map.
## A corridor exists along an axis when walls flank both sides perpendicularly.
static func is_corridor_ew(map: AsciiMapData, x: int, y: int) -> bool:
	return _is_wall_tile(map, x, y - 1) and _is_wall_tile(map, x, y + 1)

## Returns true if the tile is an NS corridor at (x, y) on the map.
static func is_corridor_ns(map: AsciiMapData, x: int, y: int) -> bool:
	return _is_wall_tile(map, x - 1, y) and _is_wall_tile(map, x + 1, y)

# -- Internal helpers ---------------------------------------------------------

static func _dijkstra(
		map: AsciiMapData,
		sx: int, sy: int,
		budget: float
) -> Array[Vector2i]:
	# dist: Vector2i -> float minimum cost to reach that tile.
	var dist: Dictionary = {}
	var source: Vector2i = Vector2i(sx, sy)
	dist[source] = 0.0

	# Priority queue as Array of [cost: float, x: int, y: int].
	# Simple O(V²) extraction is fast enough for 31×31 maps.
	var queue: Array = [[0.0, sx, sy]]

	while queue.size() > 0:
		# Extract minimum-cost entry.
		var min_idx: int = 0
		for i in range(1, queue.size()):
			if queue[i][0] < queue[min_idx][0]:
				min_idx = i
		var entry: Array = queue[min_idx]
		queue.remove_at(min_idx)

		var cur_cost: float = entry[0]
		var cx: int = entry[1]
		var cy: int = entry[2]
		var cur_pos: Vector2i = Vector2i(cx, cy)

		if cur_cost > dist.get(cur_pos, INF):
			continue  # Stale entry.

		# Expand cardinal neighbours.
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or nx >= map.width or ny < 0 or ny >= map.height:
				continue

			var tile: int = map.get_tile(nx, ny)
			if tile in BLOCKING_TILES:
				continue  # Walls stop propagation.

			var step: float = _step_cost(map, nx, ny, d.x, d.y)
			var new_cost: float = cur_cost + step

			if new_cost > budget:
				continue  # Outside noise range.

			var npos: Vector2i = Vector2i(nx, ny)
			if new_cost < dist.get(npos, INF):
				dist[npos] = new_cost
				queue.append([new_cost, nx, ny])

	# Collect reachable tiles (exclude source — enemies there are adjacent to actor).
	var result: Array[Vector2i] = []
	for pos: Vector2i in dist.keys():
		if pos != source:
			result.append(pos)
	return result

## Cost to enter tile (nx, ny) when moving from direction (dx, dy).
static func _step_cost(map: AsciiMapData, nx: int, ny: int, dx: int, dy: int) -> float:
	var tile: int = map.get_tile(nx, ny)

	# Base cost from tile type.
	var cost: float
	if tile in VEGETATION_TILES or tile in WATER_TILES:
		cost = DAMPING_COST_MULT  # 4/3: reduces effective reach by 25%.
	else:
		cost = 1.0

	# Corridor bonus: if tile is flanked by walls perpendicular to movement,
	# noise travels 50% farther along the corridor axis.
	if dx != 0:
		if is_corridor_ew(map, nx, ny):
			cost *= CORRIDOR_COST_MULT
	elif dy != 0:
		if is_corridor_ns(map, nx, ny):
			cost *= CORRIDOR_COST_MULT

	return cost

static func _is_wall_tile(map: AsciiMapData, x: int, y: int) -> bool:
	# get_tile() returns WALL_STONE for out-of-bounds — map edges act as walls.
	var t: int = map.get_tile(x, y)
	return t == _T.WALL_STONE or t == _T.WALL_WOOD or t == _T.WALL_PAPER
