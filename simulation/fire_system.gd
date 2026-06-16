class_name FireSystem
## s56.6.6 Fire Propagation Mechanics (PROVISIONAL — all values written in the GDD
## as PROVISIONAL; none invented here). A pure, headless layer over AsciiMapData's
## fire tiles (`burning_tiles` dict + FIRE tile type). Fire is an environmental
## hazard: it ignites flammable tiles, spreads round by round (wind-directional),
## burns for a fuel-dependent number of rounds, then leaves Burned Out ash, and
## deals armour-ignoring damage to anyone standing in it.
##
## Tile scale: 1 tile = 5 feet (s56.6.5). All damage/spread numbers are PROVISIONAL
## per s56.6.6. Pure class — no Node inheritance, no autoload state.

# Burn duration by fuel type, in rounds (s56.6.6 PROVISIONAL).
const DURATION_GRASS_LEAVES: int = 3   # dry grass, fallen leaves
const DURATION_CROPS: int = 4          # standing crops
const DURATION_WOOD_UNDERGROWTH: int = 5  # undergrowth, light wood structures
const DURATION_DEFAULT: int = 3

# Spread chance per adjacent flammable tile per round (s56.6.6 PROVISIONAL).
const SPREAD_NO_WIND: float = 0.30     # Clear / Mist — uniform to all 8 neighbours
const SPREAD_DOWNWIND: float = 0.60    # Wind — 3 downwind tiles
const SPREAD_LATERAL: float = 0.15     # Wind — 2 perpendicular tiles
# (upwind = 0.0 — fire does not spread against the wind)

# 8-directional neighbour offsets (matches MovementSystem's diagonal model).
const _NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## True when the tile is currently on fire.
static func is_burning(map: AsciiMapData, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= map.width or y >= map.height:
		return false
	return map.get_tile(x, y) == Enums.TileType.FIRE


## Fuel-dependent burn duration for a tile that is about to ignite.
static func fuel_rounds(tile: int) -> int:
	match tile:
		Enums.TileType.CROPS:
			return DURATION_CROPS
		Enums.TileType.FLOOR_GRASS, Enums.TileType.GROUNDCOVER:
			return DURATION_GRASS_LEAVES
		Enums.TileType.BUSH, Enums.TileType.BAMBOO, Enums.TileType.WALL_WOOD, \
		Enums.TileType.WALL_PAPER, Enums.TileType.DOOR_SHOJI_CLOSED, \
		Enums.TileType.DOOR_SHOJI_OPEN, Enums.TileType.DOOR_WOOD_CLOSED, \
		Enums.TileType.DOOR_WOOD_OPEN, Enums.TileType.FLOOR_WOOD, \
		Enums.TileType.TREE_EVERGREEN, Enums.TileType.TREE_DECIDUOUS, \
		Enums.TileType.TREE_CHERRY, Enums.TileType.TREE_DEAD:
			return DURATION_WOOD_UNDERGROWTH
		_:
			return DURATION_DEFAULT


## Ignite a tile from a fire source (spell, arson, environmental). The tile ignites
## only if it contains flammable material and is not already burning. Records the
## fuel-based burn duration. Returns true if it caught.
static func ignite(map: AsciiMapData, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= map.width or y >= map.height:
		return false
	var tile: int = map.get_tile(x, y)
	if tile == Enums.TileType.FIRE:
		return false  # already burning
	if not AsciiMapData.is_flammable(tile):
		return false
	var rounds: int = fuel_rounds(tile)
	map.set_delta(x, y, Enums.TileType.FIRE)
	map.burning_tiles[y * map.width + x] = rounds
	return true


## Spread chance for one neighbour offset under the current weather/wind.
## Clear/Mist (no directional wind): uniform SPREAD_NO_WIND. Wind: 60% downwind,
## 15% lateral, 0% upwind (classified by dot product with the wind bearing).
static func spread_chance(weather: int, wind_dir: Vector2i, offset: Vector2i) -> float:
	if weather != AsciiMapEnvironment.WeatherState.WIND or wind_dir == Vector2i.ZERO:
		return SPREAD_NO_WIND
	var dot: int = offset.x * wind_dir.x + offset.y * wind_dir.y
	if dot > 0:
		return SPREAD_DOWNWIND
	if dot == 0:
		return SPREAD_LATERAL
	return 0.0


## End-of-round fire tick (s56.6.6): weather override, then spread to flammable
## neighbours, then burn-duration decrement and Burned Out conversion. Returns
## {ignited: Array[Vector2i], burned_out: Array[Vector2i]} for logging.
static func process_round_end(map: AsciiMapData, weather: int, dice: DiceEngine) -> Dictionary:
	var ignited: Array = []
	var burned_out: Array = []

	# Storm extinguishes all fires immediately (s56.6.6).
	if weather == AsciiMapEnvironment.WeatherState.STORM \
			or weather == AsciiMapEnvironment.WeatherState.BLIZZARD:
		for idx in map.burning_tiles.keys():
			var bx: int = idx % map.width
			var by: int = idx / map.width
			map.set_delta(bx, by, Enums.TileType.FLOOR_ASH)
			burned_out.append(Vector2i(bx, by))
		map.burning_tiles.clear()
		return {"ignited": ignited, "burned_out": burned_out}

	var rain: bool = weather == AsciiMapEnvironment.WeatherState.RAIN
	# Spread is suppressed in Rain and Snow/Blizzard (Non-Flammable / no ignition).
	var spread_ok: bool = not rain and weather != AsciiMapEnvironment.WeatherState.SNOW

	# 1. Spread to flammable neighbours (collected, applied after the tick so a
	#    fresh ignition does not cascade or get decremented this same round).
	if spread_ok:
		for idx in map.burning_tiles.keys():
			var sx: int = idx % map.width
			var sy: int = idx / map.width
			for off: Vector2i in _NEIGHBORS:
				var nx: int = sx + off.x
				var ny: int = sy + off.y
				if nx < 0 or ny < 0 or nx >= map.width or ny >= map.height:
					continue
				var ntile: int = map.get_tile(nx, ny)
				if ntile == Enums.TileType.FIRE or not AsciiMapData.is_flammable(ntile):
					continue
				if dice.randf() < spread_chance(weather, map.wind_dir, off):
					ignited.append(Vector2i(nx, ny))

	# 2. Burn-duration decrement on the EXISTING fires (Rain forces a 1-round burnout).
	for idx in map.burning_tiles.keys():
		var rounds: int = int(map.burning_tiles[idx])
		if rain:
			rounds = mini(rounds, 1)
		rounds -= 1
		if rounds <= 0:
			var ex: int = idx % map.width
			var ey: int = idx / map.width
			map.set_delta(ex, ey, Enums.TileType.FLOOR_ASH)
			map.burning_tiles.erase(idx)
			burned_out.append(Vector2i(ex, ey))
		else:
			map.burning_tiles[idx] = rounds

	# 3. Apply the new ignitions (full fuel duration, fresh this round).
	for pos: Vector2i in ignited:
		ignite(map, pos.x, pos.y)

	return {"ignited": ignited, "burned_out": burned_out}


## Wounds for a character standing on a burning tile at the start of their turn
## (s56.6.6: 1k1, armour does not reduce). Apply via WoundSystem.apply_damage(c, n, 0).
static func standing_damage(dice: DiceEngine) -> int:
	return dice.roll_and_keep(1, 1, true).total


## Wounds for a character who moves through a burning tile without stopping
## (s56.6.6: 0k1, armour does not reduce).
static func passthrough_damage(dice: DiceEngine) -> int:
	return dice.roll_and_keep(0, 1, true).total
