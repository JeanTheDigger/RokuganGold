class_name ShipInteriorGenerator
## s57.43 Ship interior (voyage) map generator.
##
## Builds the SHIP_INTERIOR Lesser Zone map for a vessel carrying a player
## character (aboard_ship_id non-null). Deterministic from ship_id + ship_class
## (s57.43.2): the same ship always produces the same deck/cabin/hold layout.
##
## The ship's deck footprint is sized by class (s57.43.2); a one-tile WATER_DEEP
## margin surrounds it — "every map edge is water" (s57.43.1). There is NO
## ZONE_EXIT tile: the zone exits only to itself until the ship docks and the
## engine clears aboard_ship_id (s57.43.2 / s57.43.8).
##
## Tile set aligns with the s56.18 Ship Boarding template and s57.43.3:
##   deck        → FLOOR_WOOD
##   quarterdeck → FLOOR_STONE (+ elevation layer 1, high-ground per s4.4 Z-axis)
##   mast        → WALL_WOOD  (brown, impassable, LOS-blocking, s57.43.3)
##   cabin wall  → WALL_WOOD  (armored hulls use WALL_STONE — Koutetsukan)
##   cabin floor → FLOOR_TATAMI (captain's cabin) / FLOOR_WOOD (modest)
##   cargo       → FURNITURE_CRATE (+5 Armor TN cover, s57.43.3)
##   brazier     → FURNITURE_BRAZIER (deck Bo-Hiya fire pot, s57.43.3)
##   ship edge   → WATER_DEEP (impassable on foot; step-off = JUMP_OVERBOARD)
##
## Rigging climb, quarterdeck +1k0, wet-deck −1k0, and the brazier fire-arrow
## mechanic are s40 individual-combat effects; positions are carried as metadata
## anchors on ShipInteriorMapData and applied when s40 is live (same deferral as
## the s56.18 boarding template).
##
## All static functions; no instance state.

const _T := Enums.TileType
const _SC := Enums.ShipClass

const _WATER   := _T.WATER_DEEP
const _DECK    := _T.FLOOR_WOOD
const _QD       := _T.FLOOR_STONE     # quarterdeck — elevated marker tile
const _MAST     := _T.WALL_WOOD
const _CABIN_W  := _T.WALL_WOOD       # cabin wall (wood)
const _ARMOR_W  := _T.WALL_STONE      # armored bulkhead (Koutetsukan iron cladding)
const _CABIN_F  := _T.FLOOR_TATAMI    # captain's cabin floor (upscale)
const _HOLD_F   := _T.FLOOR_WOOD      # modest / below-decks floor
const _CARGO    := _T.FURNITURE_CRATE
const _BRAZIER  := _T.FURNITURE_BRAZIER
const _DOOR     := _T.DOOR_WOOD_CLOSED

# Deck footprint (deck_w × deck_h) by ship class, per s57.43.2. The map is the
# deck plus a one-tile water margin on every side.
# TORTOISE_OCEANGOING is PROVISIONAL — s57.43.2 does not list it; it mirrors the
# Sengokobune profile (both are ocean-crossing vessels, Sailing 3 minimum).
const _DECK_DIMS: Dictionary = {
	_SC.SAMPAN:              Vector2i(6, 3),
	_SC.MERCHANT_BARGE:      Vector2i(10, 4),
	_SC.KOBUNE:              Vector2i(12, 5),
	_SC.SENGOKOBUNE:         Vector2i(18, 7),
	_SC.KOUTETSUKAN:         Vector2i(15, 8),
	_SC.ATAKEBUNE:           Vector2i(25, 10),
	_SC.TORTOISE_OCEANGOING: Vector2i(18, 7),
}

const _MARGIN: int = 1  # water tiles around the deck footprint


# -- Public entry point -------------------------------------------------------

## Generates a complete ShipInteriorMapData for a vessel.
## ship_id    : the ship's globally-unique id (ShipData.ship_id / NamedVesselData.vessel_id)
## ship_class : Enums.ShipClass value
static func generate(ship_id: int, ship_class: int) -> ShipInteriorMapData:
	var dims: Vector2i = _DECK_DIMS.get(ship_class, _DECK_DIMS[_SC.KOBUNE])
	var map := ShipInteriorMapData.new()
	map.ship_id = ship_id
	map.ship_class = ship_class
	map.zone_subtype = Enums.ZoneSubtype.SHIP_INTERIOR
	map.zone_id = "ship_%d" % ship_id
	map.zone_name = "Ship Interior"
	map.seed_string = "ship:%d:%d" % [ship_id, ship_class]
	map.width = dims.x + _MARGIN * 2
	map.height = dims.y + _MARGIN * 2
	map.init_tiles(_WATER)
	map.init_elevation(0)

	var deck: Rect2i = Rect2i(_MARGIN, _MARGIN, dims.x, dims.y)
	map.deck_rect = deck

	var rng := RandomNumberGenerator.new()
	rng.seed = _fnv1a(map.seed_string)

	match ship_class:
		_SC.SAMPAN:
			_build_sampan(map, deck, rng)
		_SC.MERCHANT_BARGE:
			_build_merchant_barge(map, deck, rng)
		_SC.KOBUNE:
			_build_kobune(map, deck, rng)
		_SC.KOUTETSUKAN:
			_build_koutetsukan(map, deck, rng)
		_SC.ATAKEBUNE:
			_build_atakebune(map, deck, rng)
		_SC.SENGOKOBUNE, _SC.TORTOISE_OCEANGOING:
			_build_sengokobune(map, deck, rng)
		_:
			_build_kobune(map, deck, rng)

	return map


# -- Per-class builders -------------------------------------------------------

## Sampan (6×3): single open deck, no cabin, no quarterdeck. A river/harbour boat.
static func _build_sampan(map: ShipInteriorMapData, deck: Rect2i, _rng: RandomNumberGenerator) -> void:
	_lay_deck(map, deck)
	# Single mast forward of centre (kept off the mid row so the deck stays open).
	map.set_tile(deck.position.x + deck.size.x - 2, deck.position.y, _MAST)
	# Captain steers from the stern (west end), on the open deck.
	map.captain_tile = Vector2i(deck.position.x, deck.position.y + deck.size.y / 2)
	map.has_cabin = false


## Merchant Barge (10×4): open deck plus a small stern cabin. No quarterdeck.
static func _build_merchant_barge(map: ShipInteriorMapData, deck: Rect2i, rng: RandomNumberGenerator) -> void:
	_lay_deck(map, deck)
	# Small modest cabin at the stern (west, 3 wide, full height); door faces the deck.
	var cabin := Rect2i(deck.position.x, deck.position.y, 3, deck.size.y)
	_build_cabin(map, cabin, _CABIN_W, _HOLD_F, _door_on_east(cabin))
	map.has_cabin = true
	# Mast amidships, off the central lane.
	map.set_tile(deck.position.x + (deck.size.x * 2) / 3, deck.position.y, _MAST)
	# Cargo — a merchant carries goods (bow half), central lane kept clear.
	_scatter_cargo(map, deck, rng, deck.position.x + 4, 3)
	# Captain on the open deck just outside the cabin door.
	map.captain_tile = Vector2i(deck.position.x + 3, deck.position.y + deck.size.y / 2)


## Kobune (12×5): stern cabin, elevated quarterdeck aft of it, mast, brazier.
static func _build_kobune(map: ShipInteriorMapData, deck: Rect2i, rng: RandomNumberGenerator) -> void:
	_lay_deck(map, deck)
	var seat: Vector2i = _build_stern_castle(map, deck, 3, _CABIN_F, 2)
	map.captain_tile = seat
	# Mast amidships + rigging (kept off the mid lane).
	var mast_x: int = deck.position.x + (deck.size.x * 3) / 4
	map.set_tile(mast_x, deck.position.y, _MAST)
	_add_rigging(map, mast_x, deck.position.y, deck)
	# Deck brazier (Bo-Hiya) near the bow.
	_add_brazier(map, deck.position.x + deck.size.x - 2, deck.position.y + deck.size.y - 1)


## Sengokobune (18×7): stern cabin + quarterdeck, mast, below-decks cargo hold.
static func _build_sengokobune(map: ShipInteriorMapData, deck: Rect2i, rng: RandomNumberGenerator) -> void:
	_lay_deck(map, deck)
	var seat: Vector2i = _build_stern_castle(map, deck, 4, _CABIN_F, 3)
	map.captain_tile = seat
	var mid_y: int = deck.position.y + deck.size.y / 2
	# Mast + rigging amidships (off the mid lane).
	var mast_x: int = deck.position.x + deck.size.x / 2
	map.set_tile(mast_x, deck.position.y + 1, _MAST)
	_add_rigging(map, mast_x, deck.position.y + 1, deck)
	# Below-decks cargo hold — a walled crate store toward the bow; door on the
	# stern side, and the door's row is left clear so the hold stays enterable.
	var hold := Rect2i(deck.position.x + deck.size.x - 4, deck.position.y, 4, deck.size.y)
	_build_cabin(map, hold, _CABIN_W, _HOLD_F, _door_on_west(hold))
	_fill_cargo(map, Rect2i(hold.position.x + 1, hold.position.y + 1, hold.size.x - 2, hold.size.y - 2), mid_y)
	# Two deck braziers.
	_add_brazier(map, mast_x - 1, deck.position.y)
	_add_brazier(map, mast_x - 1, deck.position.y + deck.size.y - 1)


## Koutetsukan (15×8): iron-clad, enclosed fighting spaces, no open deck.
static func _build_koutetsukan(map: ShipInteriorMapData, deck: Rect2i, _rng: RandomNumberGenerator) -> void:
	# Armored hull: outer bulkhead of stone (iron cladding), wooden interior.
	_fill_rect(map, deck.position.x, deck.position.y,
		deck.position.x + deck.size.x - 1, deck.position.y + deck.size.y - 1, _ARMOR_W)
	_fill_rect(map, deck.position.x + 1, deck.position.y + 1,
		deck.position.x + deck.size.x - 2, deck.position.y + deck.size.y - 2, _HOLD_F)
	# A central fore-and-aft corridor; fighting chambers split by transverse
	# bulkheads, each pierced by a door on the corridor's mid row.
	var mid_y: int = deck.position.y + deck.size.y / 2
	var third: int = deck.position.x + deck.size.x / 3
	var two_third: int = deck.position.x + (deck.size.x * 2) / 3
	for y in range(deck.position.y + 1, deck.position.y + deck.size.y - 1):
		if y != mid_y:
			map.set_tile(third, y, _ARMOR_W)
			map.set_tile(two_third, y, _ARMOR_W)
	map.set_tile(third, mid_y, _T.DOOR_WOOD_OPEN)
	map.set_tile(two_third, mid_y, _T.DOOR_WOOD_OPEN)
	# Command chamber at the stern (captain's enclosed position — no open quarterdeck).
	map.captain_tile = Vector2i(deck.position.x + 1, mid_y)
	# Ammunition/cargo crates in the fore chamber, mid-row lane left clear so the
	# door into the fore chamber is not sealed.
	_fill_cargo(map, Rect2i(two_third + 1, deck.position.y + 1,
		deck.position.x + deck.size.x - 2 - (two_third + 1), deck.size.y - 2), mid_y)
	map.has_cabin = true
	# No brazier (no open deck for Bo-Hiya); no rigging (enclosed).


## Atakebune (25×10): multi-deck floating fortress, significant interior.
static func _build_atakebune(map: ShipInteriorMapData, deck: Rect2i, rng: RandomNumberGenerator) -> void:
	_lay_deck(map, deck)
	# Raised command castle at the stern: a captain's cabin with a wide elevated
	# quarterdeck aft of it (the command platform).
	var seat: Vector2i = _build_stern_castle(map, deck, 4, _CABIN_F, 4)
	map.captain_tile = seat
	var mid_y: int = deck.position.y + deck.size.y / 2
	# Two masts + rigging (off the mid lane).
	var mast1_x: int = deck.position.x + deck.size.x / 2
	var mast2_x: int = deck.position.x + (deck.size.x * 5) / 6
	map.set_tile(mast1_x, deck.position.y + 1, _MAST)
	map.set_tile(mast2_x, deck.position.y + deck.size.y - 2, _MAST)
	_add_rigging(map, mast1_x, deck.position.y + 1, deck)
	_add_rigging(map, mast2_x, deck.position.y + deck.size.y - 2, deck)
	# Cargo amidships (central lane kept clear by _scatter_cargo).
	_scatter_cargo(map, deck, rng, deck.position.x + deck.size.x / 2 + 1, 6)
	# Bow braziers for Bo-Hiya.
	_add_brazier(map, deck.position.x + deck.size.x - 1, deck.position.y)
	_add_brazier(map, deck.position.x + deck.size.x - 1, deck.position.y + deck.size.y - 1)


# -- Shared build helpers -----------------------------------------------------

static func _lay_deck(map: ShipInteriorMapData, deck: Rect2i) -> void:
	_fill_rect(map, deck.position.x, deck.position.y,
		deck.position.x + deck.size.x - 1, deck.position.y + deck.size.y - 1, _DECK)


## Builds a stern command structure: a walled cabin at the west end (door facing
## the deck) with an elevated open quarterdeck immediately aft — i.e. on the open
## deck just east of the cabin, so cabin → quarterdeck → main deck stay connected.
## The quarterdeck tiles are FLOOR_STONE at elevation layer 1 (s4.4 high-ground).
## Returns the captain's seat (a quarterdeck tile).
static func _build_stern_castle(
	map: ShipInteriorMapData, deck: Rect2i, cabin_w: int, cabin_floor: int, qcols: int,
) -> Vector2i:
	var cabin := Rect2i(deck.position.x, deck.position.y, cabin_w, deck.size.y)
	_build_cabin(map, cabin, _CABIN_W, cabin_floor, _door_on_east(cabin))
	map.has_cabin = true
	var qx0: int = deck.position.x + cabin_w
	var qd: Array[Vector2i] = []
	for cx in range(qx0, qx0 + qcols):
		for cy in range(deck.position.y, deck.position.y + deck.size.y):
			map.set_tile(cx, cy, _QD)
			map.set_elevation(cx, cy, 1)
			qd.append(Vector2i(cx, cy))
	map.quarterdeck_tiles = qd
	return Vector2i(qx0 + qcols / 2, deck.position.y + deck.size.y / 2)


## Walls a rectangular cabin and lays its floor, cutting one door at `door`.
static func _build_cabin(map: ShipInteriorMapData, room: Rect2i, wall: int, floor_tile: int, door: Vector2i) -> void:
	var x2: int = room.position.x + room.size.x - 1
	var y2: int = room.position.y + room.size.y - 1
	# Perimeter walls.
	for x in range(room.position.x, x2 + 1):
		map.set_tile(x, room.position.y, wall)
		map.set_tile(x, y2, wall)
	for y in range(room.position.y, y2 + 1):
		map.set_tile(room.position.x, y, wall)
		map.set_tile(x2, y, wall)
	# Interior floor.
	for x in range(room.position.x + 1, x2):
		for y in range(room.position.y + 1, y2):
			map.set_tile(x, y, floor_tile)
	# Door.
	map.set_tile(door.x, door.y, _DOOR)


static func _door_on_east(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + room.size.x - 1, room.position.y + room.size.y / 2)


static func _door_on_west(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x, room.position.y + room.size.y / 2)


## Places climbable rigging tiles flanking a mast (metadata only; the underlying
## tile stays walkable deck). Climb/attack-bonus mechanics are s40-deferred.
static func _add_rigging(map: ShipInteriorMapData, mast_x: int, mast_y: int, deck: Rect2i) -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1)]:
		var rx: int = mast_x + d.x
		var ry: int = mast_y + d.y
		if deck.has_point(Vector2i(rx, ry)) and map.get_tile(rx, ry) == _DECK:
			map.rigging_tiles.append(Vector2i(rx, ry))


static func _add_brazier(map: ShipInteriorMapData, x: int, y: int) -> void:
	if not map.deck_rect.has_point(Vector2i(x, y)):
		return
	if map.get_tile(x, y) != _DECK:
		return
	map.set_tile(x, y, _BRAZIER)
	map.brazier_tiles.append(Vector2i(x, y))


## Fills a rectangle solid with cargo crates (clamped inside the deck), leaving
## `keep_row` (if >= 0) clear so an adjoining door / access lane is not sealed.
static func _fill_cargo(map: ShipInteriorMapData, area: Rect2i, keep_row: int = -1) -> void:
	for x in range(area.position.x, area.position.x + area.size.x):
		for y in range(area.position.y, area.position.y + area.size.y):
			if y == keep_row:
				continue
			if map.deck_rect.has_point(Vector2i(x, y)) and map.get_tile(x, y) == _HOLD_F:
				map.set_tile(x, y, _CARGO)


## Scatters `count` cargo crates on open deck from a starting column, leaving a
## clear central lane so the deck stays fully connected.
static func _scatter_cargo(map: ShipInteriorMapData, deck: Rect2i, rng: RandomNumberGenerator, from_x: int, count: int) -> void:
	var placed: int = 0
	var attempts: int = 0
	var mid_y: int = deck.position.y + deck.size.y / 2
	while placed < count and attempts < count * 8:
		attempts += 1
		var x: int = rng.randi_range(from_x, deck.position.x + deck.size.x - 1)
		var y: int = rng.randi_range(deck.position.y, deck.position.y + deck.size.y - 1)
		if y == mid_y:
			continue  # keep the central fore-aft lane clear
		if map.get_tile(x, y) == _DECK:
			map.set_tile(x, y, _CARGO)
			placed += 1


static func _fill_rect(map: ShipInteriorMapData, x1: int, y1: int, x2: int, y2: int, tile: int) -> void:
	for x in range(x1, x2 + 1):
		for y in range(y1, y2 + 1):
			map.set_tile(x, y, tile)


# -- FNV-1a hash for deterministic seeding (mirrored from other generators) ---

static func _fnv1a(s: String) -> int:
	var h: int = 0x811c9dc5
	for c in s.to_utf8_buffer():
		h ^= c
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
