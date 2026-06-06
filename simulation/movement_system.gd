class_name MovementSystem
## ASCII map movement rules per GDD s4.4 and s4.5 (LOCKED).
## 1 tile = 5 feet.  Water Ring determines tile budget per action type.
## Free Action = WR tiles, Simple Move = WR×2, Full Move = WR×4.

enum MoveAction { FREE, SIMPLE, FULL_MOVE }

# ── Terrain passability ──────────────────────────────────────────────────────

## Returns the movement cost for entering a tile.
## 0 = impassable, 1 = normal, 2 = difficult (+1 extra budget consumed).
static func terrain_cost(tile: int) -> int:
	match tile:
		Enums.TileType.VOID,
		Enums.TileType.WALL_STONE, Enums.TileType.WALL_WOOD, Enums.TileType.WALL_PAPER,
		Enums.TileType.WATER_DEEP,
		Enums.TileType.TREE_EVERGREEN, Enums.TileType.TREE_DECIDUOUS,
		Enums.TileType.TREE_CHERRY, Enums.TileType.TREE_DEAD, Enums.TileType.BAMBOO,
		Enums.TileType.DOOR_SHOJI_CLOSED, Enums.TileType.DOOR_WOOD_CLOSED,
		Enums.TileType.GATE_CLOSED:
			return 0
		Enums.TileType.WATER_SHALLOW, Enums.TileType.WATER_PADDY,
		Enums.TileType.WATER_RAPID, Enums.TileType.CROPS, Enums.TileType.RUBBLE:
			return 2
		_:
			return 1


static func is_passable(tile: int) -> bool:
	return terrain_cost(tile) > 0


static func is_closed_door(tile: int) -> bool:
	return tile == Enums.TileType.DOOR_SHOJI_CLOSED \
		or tile == Enums.TileType.DOOR_WOOD_CLOSED \
		or tile == Enums.TileType.GATE_CLOSED


## Returns the open-state tile for a closed door tile (identity if not a door).
static func open_door(closed_tile: int) -> int:
	match closed_tile:
		Enums.TileType.DOOR_SHOJI_CLOSED: return Enums.TileType.DOOR_SHOJI_OPEN
		Enums.TileType.DOOR_WOOD_CLOSED:  return Enums.TileType.DOOR_WOOD_OPEN
		Enums.TileType.GATE_CLOSED:       return Enums.TileType.GATE_OPEN
	return closed_tile


## Returns the closed-state tile for an open door tile (identity if not a door).
static func close_door(open_tile: int) -> int:
	match open_tile:
		Enums.TileType.DOOR_SHOJI_OPEN: return Enums.TileType.DOOR_SHOJI_CLOSED
		Enums.TileType.DOOR_WOOD_OPEN:  return Enums.TileType.DOOR_WOOD_CLOSED
		Enums.TileType.GATE_OPEN:       return Enums.TileType.GATE_CLOSED
	return open_tile


# ── Action budgets (s4.5 LOCKED) ────────────────────────────────────────────

## Tile budget for a move action given the character's Water Ring.
## FREE = WR tiles, SIMPLE = WR × 2, FULL_MOVE = WR × 4.
static func budget(water_ring: int, action: MoveAction) -> int:
	var wr: int = clampi(water_ring, 1, 10)
	match action:
		MoveAction.FREE:      return wr
		MoveAction.SIMPLE:    return wr * 2
		MoveAction.FULL_MOVE: return wr * 4
	return 0


# ── Step validation ──────────────────────────────────────────────────────────

## Validate a single step from (from_x, from_y) to (to_x, to_y) on map.
## Returns a Dictionary:
##   ok      bool  — move is physically valid
##   cost    int   — budget tiles consumed (0 when ok==false)
##   is_door bool  — target is a closed door (bump to open, player stays)
##   is_exit bool  — target is a ZONE_EXIT tile (triggers zone transition)
static func check_step(
	map: AsciiMapData,
	_from_x: int, _from_y: int,
	to_x: int, to_y: int,
) -> Dictionary:
	if to_x < 0 or to_y < 0 or to_x >= map.width or to_y >= map.height:
		return {ok = false, cost = 0, is_door = false, is_exit = false}
	var tile: int = map.get_tile(to_x, to_y)
	if is_closed_door(tile):
		return {ok = false, cost = 0, is_door = true, is_exit = false}
	if tile == Enums.TileType.ZONE_EXIT:
		return {ok = true, cost = 1, is_door = false, is_exit = true}
	var cost: int = terrain_cost(tile)
	return {ok = cost > 0, cost = cost, is_door = false, is_exit = false}
