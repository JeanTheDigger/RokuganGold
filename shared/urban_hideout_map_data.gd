class_name UrbanHideoutMapData
extends AsciiMapData
## Urban Hideout hidden-level map for ASCII map missions (s56.15 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Two-zone structure: surface search phase (blocked on s4.4.1) + hidden level below.
## This class represents the HIDDEN LEVEL only. Surface search phase requires
## the Settlement Building Framework (s4.4.1, NOT STARTED).
## Tile types: WALL_STONE interior walls, FLOOR_STONE floors, DOOR_WOOD_CLOSED
## between passages, ZONE_EXIT at entrance trapdoor.
##
## DIMS are PROVISIONAL: derived from Cave analog comparison per s56.15.2
## ("Connected Basements play like a small Cave" / "Catacombs play like a full Cave").
## 31×31 is the viewport; maps are 24×20 (SINGLE_BASEMENT), 40×36 (CONNECTED_BASEMENTS),
## 60×52 (CATACOMBS).

# -- Size categories (s56.15.1) -----------------------------------------------

enum SizeCategory {
	SINGLE_BASEMENT     = 0,  # 1–2 rooms, entrance + optional alcove. Strength ≤ 3.
	CONNECTED_BASEMENTS = 1,  # Several rooms connected by tunnels. Strength ≤ 6.
	CATACOMBS           = 2,  # Extensive underground network. Strength ≤ 9.
}

# -- Population placement roles (s56.15.3) ------------------------------------

enum PopRole {
	LOOKOUT       = 0,  # Surface lookout posing as civilian (BLOCKED — requires s4.4.1).
	SYMPATHIZER   = 1,  # Non-combatant surface contact (BLOCKED — requires s4.4.1).
	DOOR_GUARD    = 2,  # At entrance from above; first combat encounter.
	ZOMBIE_SCREEN = 3,  # Standing in corridors; CONNECTED_BASEMENTS and CATACOMBS only.
	CULTIST_GROUP = 4,  # In rooms; 2–3 per occupied room.
	LEADER        = 5,  # In ritual space; deepest, most central room.
}

# -- Zone identifiers ---------------------------------------------------------

enum Zone {
	ENTRANCE     = 0,  # Near the trapdoor; Door Guard position.
	CORRIDOR     = 1,  # Connecting passages between rooms; zombie placement zone.
	ROOM         = 2,  # General cultist rooms.
	RITUAL_SPACE = 3,  # Deepest room; always furthest from entrance.
}

# -- Objective types (s56.15.5) ------------------------------------------------

enum ObjType {
	LOCATE_ENTRANCE     = 0,  # Surface phase — BLOCKED (requires s4.4.1).
	SUPPRESS_CELL       = 1,  # Kill or capture cultists in hidden level.
	KILL_CAPTURE_LEADER = 2,  # Leader in ritual space.
	DESTROY_RITUAL_SPACE = 3, # Purify or demolish ritual implements.
	RECOVER_EVIDENCE    = 4,  # Scrolls, letters, names in rooms and ritual space.
	PREVENT_ESCAPE      = 5,  # Time-sensitive; controls entrance tile.
}

# -- Dimensional constraints (PROVISIONAL — s56.15 does not specify tile counts) ---

const DIMS: Array[Vector2i] = [
	Vector2i(24, 20),  # SINGLE_BASEMENT     (PROVISIONAL)
	Vector2i(40, 36),  # CONNECTED_BASEMENTS (PROVISIONAL — ≈ SMALL Cave per s56.15.2)
	Vector2i(60, 52),  # CATACOMBS           (PROVISIONAL — ≈ MEDIUM Cave per s56.15.2)
]

const ROOM_COUNT_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),   # SINGLE_BASEMENT: one or two rooms (s56.15.1)
	Vector2i(3, 5),   # CONNECTED_BASEMENTS: several rooms (s56.15.1)
	Vector2i(6, 10),  # CATACOMBS: extensive (s56.15.1)
]

# -- Identity -----------------------------------------------------------------

@export var size_category: int = SizeCategory.SINGLE_BASEMENT

# Entrance: ZONE_EXIT trapdoor tile position (top-edge, center).
@export var entrance_x: int = -1
@export var entrance_y: int = -1

# Ritual space: the deepest room (furthest from entrance).
@export var ritual_space_room_id: int = -1

# -- Layout data --------------------------------------------------------------

# Rooms in the hidden level.
# Each dict: { id, lx, ly, rx, ry, zone (Zone), taint_level (0–3) }
# taint_level: 0=relatively clean (entrance), 1=noticeable, 2=strong, 3=ritual space
# Zone ENTRANCE for room containing entrance tile.
# Zone RITUAL_SPACE for deepest room.
# Zone ROOM for all others.
@export var rooms: Array = []

# Connecting passages between rooms.
# Each dict: { id, from_room_id, to_room_id, lx, ly, rx, ry }
# Passages are 1 tile wide per s56.15.4 ("narrow tunnels").
@export var corridors: Array = []

# Evidence markers (s56.15.4 "Evidence" and s56.15.5 RECOVER_EVIDENCE).
# Each dict: { id, x, y, room_id }
@export var evidence_markers: Array = []

# Zombie screen positions in corridors (s56.15.3 ZOMBIE_SCREEN).
# Only in CONNECTED_BASEMENTS and CATACOMBS.
# Each dict: { x, y, corridor_id }
@export var zombie_positions: Array = []

# Enemy combatant slots.
# Each dict: { x, y, role (PopRole), zone (Zone), room_id }

# Objective markers.
# Each dict: { x, y, obj_type (ObjType), room_id }
@export var objective_slots: Array = []
