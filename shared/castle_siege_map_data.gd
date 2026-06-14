class_name CastleSiegeMapData
extends AsciiMapData
## Castle Siege map for ASCII map missions (s56.17 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Generated when a storm assault fires with a player character present (s56.17).
## Tile types: WALL_STONE (impassable walls), FLOOR_STONE (walkable interiors, walkways,
##   baileys), FLOOR_DIRT (approach zone outside castle), DOOR_WOOD_CLOSED (gates).
##   ZONE_EXIT marks the player start position (approach edge for attacker,
##   outer-wall walkway for defender).
## Combat mechanics (ladder placement, murder holes 3k2/round, arrow slits +15 Armor TN,
##   fire mechanics) are blocked on s40 individual combat and stored as layout metadata.
##
## Map dimensions (GDD s56.17.1):
##   Fortification: 20×25. Military structure — outer wall, single gate, small courtyard,
##     command building. Two layers.
##   Castle Town: 25×30. Outer wall, outer bailey, inner wall, inner bailey, tenshu.
##     Three layers.
##   City: 30×40. Outer wall, outer district, inner wall, castle compound, tenshu.
##     Four layers. Multiple gates.

# -- Size categories (s56.17.1) -----------------------------------------------

enum SizeCategory {
	FORTIFICATION = 0,  # 20×25, 2 layers. Outer wall + interior.
	CASTLE_TOWN   = 1,  # 25×30, 3 layers. Outer wall, outer/inner bailey, tenshu.
	CITY          = 2,  # 30×40, 4 layers. Outer wall, outer district, inner wall, castle compound + tenshu.
}

# -- Assault mode (s56.17.3–4) -----------------------------------------------

enum AssaultMode {
	ATTACKER = 0,  # Player starts outside outer wall; objective: reach tenshu.
	DEFENDER = 1,  # Player starts on outer wall walkway; objective: hold all layers.
}

# -- Population placement roles (s56.17.2–5) ----------------------------------

enum PopRole {
	WALL_DEFENDER      = 0,  # On wall walkways; +1k0 attack vs enemies below (s56.17.2).
	GATE_GUARD         = 1,  # At gate tile; strongest chokepoint position.
	MURDER_HOLE_GUARD  = 2,  # Above gate; 3k2 damage/round, no attack roll (s56.17.2; s40 blocked).
	BAILEY_DEFENDER    = 3,  # In open bailey; massed combat response.
	GARRISON_COMMANDER = 4,  # In tenshu or command building; high-value target.
	FRIENDLY_SOLDIER   = 5,  # Player's allied force; 10–15 soldiers (s56.17.3–4).
}

# -- Zone identifiers ---------------------------------------------------------

enum Zone {
	APPROACH     = 0,  # FLOOR_DIRT exterior; attacker start zone.
	WALL_TOP     = 1,  # FLOOR_STONE walkway along inner face of wall.
	OUTER_BAILEY = 2,  # FLOOR_STONE; between outer and next wall.
	INNER_BAILEY = 3,  # FLOOR_STONE; between inner wall and tenshu.
	TENSHU       = 4,  # FLOOR_STONE interior of main keep; final objective.
}

# -- Dimensional constraints (s56.17.1) ----------------------------------------

const DIMS: Array[Vector2i] = [
	Vector2i(20, 25),  # FORTIFICATION
	Vector2i(25, 30),  # CASTLE_TOWN
	Vector2i(30, 40),  # CITY
]

const LAYER_COUNT: Array[int] = [2, 3, 4]

# -- Identity -----------------------------------------------------------------

@export var size_category: int = SizeCategory.FORTIFICATION
@export var assault_mode: int = AssaultMode.ATTACKER

# Player start: ZONE_EXIT tile position.
@export var player_start_x: int = -1
@export var player_start_y: int = -1

# -- Layout data --------------------------------------------------------------

# Wall sections defining each layer's perimeter.
# Each dict: { id, lx, ly, rx, ry, layer_idx }
# layer_idx 0 = outermost; increases toward tenshu.
@export var walls: Array = []

# Gate tiles (one per wall per layer, multiple for CITY outer wall).
# Each dict: { id, x, y, layer_idx, wall_id }
# Gate tiles are DOOR_WOOD_CLOSED; can be set on fire per s56.17.2 (s40 blocked).
@export var gates: Array = []

# Wall walkway sections (elevated floor along inner face of each wall).
# Each dict: { id, lx, ly, rx, ry, layer_idx, wall_id }
# Tiles are FLOOR_STONE; defenders here get +1k0 vs enemies below (s40 blocked).
@export var wall_walkways: Array = []

# Murder holes: tiles on walkway directly above gate passage.
# Each dict: { id, x, y, gate_id, layer_idx }
# Defenders here deal 3k2/round with no attack roll (s56.17.2; blocked on s40).
@export var murder_holes: Array = []

# Arrow slits: tiles in outer face of walls for outward ranged fire.
# Each dict: { id, x, y, facing ("N"/"S"/"E"/"W"), wall_id, layer_idx }
# Provide +15 Armor TN from return fire (s56.17.2; blocked on s40).
@export var arrow_slits: Array = []

# Bailey areas between wall layers.
# Each dict: { id, lx, ly, rx, ry, zone_type (Zone), layer_idx }
@export var baileys: Array = []

# Tenshu (main keep) bounds and interior.
# lx, ly, rx, ry of tenshu walls; interior is FLOOR_STONE.
@export var tenshu_lx: int = -1
@export var tenshu_ly: int = -1
@export var tenshu_rx: int = -1
@export var tenshu_ry: int = -1

# Enemy combatant slots.
# Each dict: { x, y, role (PopRole), zone (Zone), layer_idx }

# Objective markers.
# Each dict: { x, y, zone (Zone), layer_idx }
# For attacker: each gate is an intermediate objective; tenshu is the final.
# For defender: outer wall center is the primary hold point.
@export var objective_slots: Array = []
