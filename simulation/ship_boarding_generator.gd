class_name ShipBoardingGenerator
## s56.18 Ship Boarding map generator --- LOCKED.
## Generates the ASCII tile map for a ship-boarding mission.
## Layout: 15×10 — player ship (rows 0-3), water gap (rows 4-5),
##         enemy ship (rows 6-9).  Planks bridge the water gap.
## Quarterdeck elevation and water-hazard mechanics are metadata only;
## effects blocked on s40 individual combat.
## All static functions; no instance state.

const _T := Enums.TileType

const _WALL  := _T.WALL_STONE
const _DECK  := _T.FLOOR_WOOD
const _QD    := _T.FLOOR_STONE    # quarterdeck — elevated marker tile
const _WATER := _T.WATER_DEEP
const _PLANK := _T.FLOOR_WOOD     # plank bridging tile (same visual as deck)
const _EXIT  := _T.ZONE_EXIT

# -- Public entry point -------------------------------------------------------

## Generates a complete ShipBoardingMapData.
## seed_str     : deterministic seed string
## ship_type    : ShipBoardingMapData.ShipType int
## boarding_mode: ShipBoardingMapData.BoardingMode int
static func generate(_seed_str: String, ship_type: int, boarding_mode: int) -> ShipBoardingMapData:
	var map := ShipBoardingMapData.new()
	map.ship_type     = ship_type
	map.boarding_mode = boarding_mode
	map.width         = ShipBoardingMapData.MAP_W
	map.height        = ShipBoardingMapData.MAP_H
	map.init_tiles(_WATER)

	var planks: Array = ShipBoardingMapData.PLANK_COLS[ship_type]
	map.plank_cols = planks.duplicate()

	_build_player_ship(map, planks)
	_build_water_gap(map, planks)
	_build_enemy_ship(map, planks)
	_place_entrance(map, boarding_mode)
	_place_objective(map, boarding_mode)
	_stamp_elevation(map)
	return map

# -- Elevation (s4.4 Z-axis — raised quarterdecks) ----------------------------

## Raises both quarterdecks to layer 1 (the rest of the ship stays at layer 0).
## Deck → quarterdeck is a single +1 ramp (walkable), so a defender holding the
## quarterdeck gains the high-ground attack bonus over boarders on the open deck.
## A 2-of-3-layer map.
static func _stamp_elevation(map: ShipBoardingMapData) -> void:
	map.init_elevation(0)
	for y in ShipBoardingMapData.PLAYER_DECK_ROWS:
		for x in ShipBoardingMapData.PLAYER_QUARTERDECK_COLS:
			map.set_elevation(x, y, 1)
	for y in ShipBoardingMapData.ENEMY_DECK_ROWS:
		for x in ShipBoardingMapData.ENEMY_QUARTERDECK_COLS:
			map.set_elevation(x, y, 1)

# -- Ship builders ------------------------------------------------------------

static func _build_player_ship(map: ShipBoardingMapData, planks: Array) -> void:
	var w: int = ShipBoardingMapData.MAP_W

	# Row 0: north hull — solid wall across the full width.
	for x in range(w):
		map.set_tile(x, 0, _WALL)

	# Rows 1-2: player deck.
	for y in [1, 2]:
		for x in range(w):
			map.set_tile(x, y, _DECK)

	# Quarterdeck overlay on cols 0-2, rows 1-2.
	for y in ShipBoardingMapData.PLAYER_DECK_ROWS:
		for x in ShipBoardingMapData.PLAYER_QUARTERDECK_COLS:
			map.set_tile(x, y, _QD)

	# Mast: impassable wall tile at center of row 2.
	map.set_tile(ShipBoardingMapData.PLAYER_MAST_COL, ShipBoardingMapData.PLAYER_MAST_ROW, _WALL)

	# Row 3: south hull — wall everywhere except plank columns.
	for x in range(w):
		map.set_tile(x, 3, _WALL)
	for pc in planks:
		map.set_tile(pc, 3, _DECK)

static func _build_water_gap(map: ShipBoardingMapData, planks: Array) -> void:
	# Rows 4-5 are pre-filled WATER_DEEP by init_tiles.
	# Place plank tiles at plank column positions.
	for y in ShipBoardingMapData.WATER_ROWS:
		for pc in planks:
			map.set_tile(pc, y, _PLANK)

static func _build_enemy_ship(map: ShipBoardingMapData, planks: Array) -> void:
	var w: int = ShipBoardingMapData.MAP_W

	# Row 6: north hull — wall everywhere except plank columns.
	for x in range(w):
		map.set_tile(x, 6, _WALL)
	for pc in planks:
		map.set_tile(pc, 6, _DECK)

	# Rows 7-8: enemy deck.
	for y in [7, 8]:
		for x in range(w):
			map.set_tile(x, y, _DECK)

	# Quarterdeck overlay on cols 12-14, rows 7-8.
	for y in ShipBoardingMapData.ENEMY_DECK_ROWS:
		for x in ShipBoardingMapData.ENEMY_QUARTERDECK_COLS:
			map.set_tile(x, y, _QD)

	# Mast: impassable wall tile at center of row 7.
	map.set_tile(ShipBoardingMapData.ENEMY_MAST_COL, ShipBoardingMapData.ENEMY_MAST_ROW, _WALL)

	# Row 9: south hull — solid wall across the full width.
	for x in range(w):
		map.set_tile(x, 9, _WALL)

# -- Special tile placement ---------------------------------------------------

static func _place_entrance(map: ShipBoardingMapData, boarding_mode: int) -> void:
	# In ASSAULT mode, players board from the north (row 0 of player ship).
	# In DEFENSE mode, players already hold the south (row 9 is the enemy hull).
	# Either way, the zone exit marker goes on the player's north hull center.
	var exit_x: int = ShipBoardingMapData.MAP_W / 2
	map.set_tile(exit_x, 0, _EXIT)
	map.entrance_x = exit_x
	map.entrance_y = 0

static func _place_objective(map: ShipBoardingMapData, boarding_mode: int) -> void:
	# Primary objective is always on the enemy quarterdeck region (enemy captain).
	# Col 13 (center of quarterdeck cols 12-14), row 8.
	var obj_x: int = 13
	var obj_y: int = 8
	if boarding_mode == ShipBoardingMapData.BoardingMode.DEFENSE:
		# In defense mode the objective is the player's own quarterdeck.
		obj_x = 1
		obj_y = 1
	map.objective_x = obj_x
	map.objective_y = obj_y

# -- FNV-1a hash for deterministic seeding (mirrored from other generators) ---

static func _fnv1a(s: String) -> int:
	var h: int = 0x811c9dc5
	for c in s.to_utf8_buffer():
		h ^= c
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
