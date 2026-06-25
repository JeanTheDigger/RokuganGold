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
		Enums.TileType.VOID, Enums.TileType.WALL_STONE, Enums.TileType.WALL_WOOD, Enums.TileType.WALL_PAPER, Enums.TileType.WATER_DEEP, Enums.TileType.TREE_EVERGREEN, Enums.TileType.TREE_DECIDUOUS, Enums.TileType.TREE_CHERRY, Enums.TileType.TREE_DEAD, Enums.TileType.BAMBOO, Enums.TileType.DOOR_SHOJI_CLOSED, Enums.TileType.DOOR_WOOD_CLOSED, Enums.TileType.GATE_CLOSED, Enums.TileType.FURNITURE_HEARTH, Enums.TileType.FURNITURE_CHEST, Enums.TileType.FURNITURE_TABLE, Enums.TileType.FURNITURE_JAR, Enums.TileType.FURNITURE_BRAZIER, Enums.TileType.FURNITURE_DAIS, Enums.TileType.FURNITURE_WEAPON_STAND, Enums.TileType.FURNITURE_ALTAR, Enums.TileType.FURNITURE_OFFERING_BOX, Enums.TileType.FURNITURE_INCENSE, Enums.TileType.FURNITURE_STATUE, Enums.TileType.FURNITURE_STALL, Enums.TileType.FURNITURE_CRATE, Enums.TileType.FURNITURE_WELL, Enums.TileType.FURNITURE_DUMMY, Enums.TileType.FURNITURE_SHELF, Enums.TileType.FURNITURE_STOVE, Enums.TileType.ROOF:
			return 0
		Enums.TileType.WATER_SHALLOW, Enums.TileType.WATER_PADDY, Enums.TileType.WATER_RAPID, Enums.TileType.CROPS, Enums.TileType.RUBBLE:
			return 2
		_:
			return 1


static func is_passable(tile: int) -> bool:
	return terrain_cost(tile) > 0


# ── Flight (s4.4; owner-defined 2026-06-24: "flight = occupy an empty space") ──
## The impassable set splits in two: SOLID obstructions (walls, trees, bamboo,
## closed doors/gates, furniture, roofs) a flyer cannot pass through, and OPEN
## spaces (open air / VOID, deep water) a flyer hovers over. A flying combatant may
## occupy any tile that is NOT a solid obstruction.
static func is_solid_obstruction(tile: int) -> bool:
	match tile:
		Enums.TileType.WALL_STONE, Enums.TileType.WALL_WOOD, Enums.TileType.WALL_PAPER, \
		Enums.TileType.TREE_EVERGREEN, Enums.TileType.TREE_DECIDUOUS, Enums.TileType.TREE_CHERRY, \
		Enums.TileType.TREE_DEAD, Enums.TileType.BAMBOO, Enums.TileType.DOOR_SHOJI_CLOSED, \
		Enums.TileType.DOOR_WOOD_CLOSED, Enums.TileType.GATE_CLOSED, Enums.TileType.FURNITURE_HEARTH, \
		Enums.TileType.FURNITURE_CHEST, Enums.TileType.FURNITURE_TABLE, Enums.TileType.FURNITURE_JAR, \
		Enums.TileType.FURNITURE_BRAZIER, Enums.TileType.FURNITURE_DAIS, Enums.TileType.FURNITURE_WEAPON_STAND, \
		Enums.TileType.FURNITURE_ALTAR, Enums.TileType.FURNITURE_OFFERING_BOX, Enums.TileType.FURNITURE_INCENSE, \
		Enums.TileType.FURNITURE_STATUE, Enums.TileType.FURNITURE_STALL, Enums.TileType.FURNITURE_CRATE, \
		Enums.TileType.FURNITURE_WELL, Enums.TileType.FURNITURE_DUMMY, Enums.TileType.FURNITURE_SHELF, \
		Enums.TileType.FURNITURE_STOVE, Enums.TileType.ROOF:
			return true
		_:
			return false


## A flying combatant may enter this tile: open ground, difficult terrain, open air
## (VOID), and water — everything except a solid obstruction it cannot fly through.
static func is_flyable(tile: int) -> bool:
	return not is_solid_obstruction(tile)


# ── Elevation / Z-axis (s4.4; numeric model locked by owner 2026-06-23) ───────
# 1 elevation level = one tile-height ≈ 5 ft (matching 1 tile = 5 ft).
## A single step rising by CLIFF_THRESHOLD or more levels is a vertical face:
## normal movement cannot scale it — a deliberate climb action is required.
const CLIFF_THRESHOLD: int = 2
## A single step dropping by FALL_THRESHOLD or more levels is a fall. Casual
## movement does not walk off such a ledge; a fall is produced by forced movement
## (knockback), where the combat orchestrator applies the falling damage.
const FALL_THRESHOLD: int = 2


## Elevation change (to_elev − from_elev) for a step. Always 0 on a flat map
## (one without a computed elevation grid), so flat maps are unaffected.
static func elevation_delta(map: AsciiMapData, fx: int, fy: int, tx: int, ty: int) -> int:
	if map == null or not map.has_elevation():
		return 0
	return map.elevation_at(tx, ty) - map.elevation_at(fx, fy)


## True if a single step from (fx,fy) to (tx,ty) crosses an impassable elevation
## face — too steep to climb up (rise ≥ CLIFF_THRESHOLD) or too far to step down
## (drop ≥ FALL_THRESHOLD). Such steps are blocked for normal movement and
## pathfinding; a ≥-drop becomes a fall only under forced movement.
static func is_cliff_step(map: AsciiMapData, fx: int, fy: int, tx: int, ty: int) -> bool:
	var d: int = elevation_delta(map, fx, fy, tx, ty)
	return d >= CLIFF_THRESHOLD or d <= -FALL_THRESHOLD


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
##   ok        bool  — move is physically valid
##   cost      int   — budget tiles consumed (0 when ok==false)
##   is_door   bool  — target is a closed door (bump to open, player stays)
##   is_exit   bool  — target is a ZONE_EXIT tile (triggers zone transition)
##   is_cliff  bool  — blocked by an elevation face (rise/drop too steep to walk)
##   elev_delta int  — to_elev − from_elev (0 on flat maps)
static func check_step(
	map: AsciiMapData,
	from_x: int, from_y: int,
	to_x: int, to_y: int,
) -> Dictionary:
	if to_x < 0 or to_y < 0 or to_x >= map.width or to_y >= map.height:
		return {ok = false, cost = 0, is_door = false, is_exit = false, is_cliff = false, elev_delta = 0}
	var tile: int = map.get_tile(to_x, to_y)
	if is_closed_door(tile):
		return {ok = false, cost = 0, is_door = true, is_exit = false, is_cliff = false, elev_delta = 0}
	var ed: int = elevation_delta(map, from_x, from_y, to_x, to_y)
	# ZONE_EXIT tiles sit at the map edge; they are always steppable (never gated
	# by an elevation face).
	if tile == Enums.TileType.ZONE_EXIT:
		return {ok = true, cost = 1, is_door = false, is_exit = true, is_cliff = false, elev_delta = ed}
	if is_cliff_step(map, from_x, from_y, to_x, to_y):
		return {ok = false, cost = 0, is_door = false, is_exit = false, is_cliff = true, elev_delta = ed}
	var cost: int = terrain_cost(tile)
	return {ok = cost > 0, cost = cost, is_door = false, is_exit = false, is_cliff = false, elev_delta = ed}
