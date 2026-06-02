class_name ShipBoardingMapData
extends AsciiMapData
## s56.18 Ship Boarding mission map data --- LOCKED.
## 15 wide × 10 tall fixed layout: two ships bridged by planks over a water gap.
## Quarterdeck elevation and water swimming mechanics are metadata only;
## mechanical effects are blocked on s40 individual combat.

# -- Enums --------------------------------------------------------------------

enum ShipType {
	KOBUNE       = 0,  # small; 2 planks
	SENGOKUBUNE  = 1,  # medium warship; 3 planks
	ATAKEBUNE    = 2,  # large warship; 3 planks
}

enum BoardingMode {
	ASSAULT = 0,  # PC side is boarding the enemy ship
	DEFENSE = 1,  # PC side is defending their own ship
}

# -- Layout constants ---------------------------------------------------------

const MAP_W: int = 15
const MAP_H: int = 10

# Plank column sets indexed by ShipType.
const PLANK_COLS: Array = [
	[4, 10],        # KOBUNE       — 2 planks
	[3, 7, 11],     # SENGOKUBUNE  — 3 planks
	[3, 7, 11],     # ATAKEBUNE    — 3 planks
]

# Player-ship quarterdeck: rows 1-2, cols 0-2 (stern at west).
const PLAYER_QUARTERDECK_COLS: Array = [0, 1, 2]
const PLAYER_DECK_ROWS: Array = [1, 2]

# Enemy-ship quarterdeck: rows 7-8, cols 12-14 (stern at east).
const ENEMY_QUARTERDECK_COLS: Array = [12, 13, 14]
const ENEMY_DECK_ROWS: Array = [7, 8]

# Mast column (center of each deck; one per ship).
const PLAYER_MAST_COL: int = 7
const PLAYER_MAST_ROW: int = 2
const ENEMY_MAST_COL: int = 7
const ENEMY_MAST_ROW: int = 7

# Hull rows (solid wall rows that delimit each ship).
const PLAYER_HULL_N: int = 0   # top row, always solid
const PLAYER_HULL_S: int = 3   # bottom of player ship, open at plank cols
const ENEMY_HULL_N:  int = 6   # top of enemy ship, open at plank cols
const ENEMY_HULL_S:  int = 9   # bottom row, always solid

# Water gap rows.
const WATER_ROWS: Array = [4, 5]

# -- Map state ----------------------------------------------------------------

@export var ship_type: int      = ShipType.KOBUNE
@export var boarding_mode: int  = BoardingMode.ASSAULT

# Tile coordinates for the player entry zone-exit marker.
@export var entrance_x: int = 7
@export var entrance_y: int = 0

# Tile coordinates for the primary objective (enemy captain's position).
@export var objective_x: int = 7
@export var objective_y: int = 8

# Plank columns active for this map (copy of PLANK_COLS[ship_type]).
@export var plank_cols: Array = []

# Metadata-only: quarterdeck advantage (+1k0 attack/defense — blocked on s40).
@export var player_quarterdeck_active: bool = true
@export var enemy_quarterdeck_active: bool  = true

# Metadata-only: water hazard TN per round for swimming (blocked on s40).
@export var water_swim_tn: int = 15
