class_name SpiritualPalette
## s56.16.1b — The Gradient: Visual Transformation (LOCKED).
##
## A spirit realm does not rip open; it overlaps. The ASCII tiles shift gradually
## as the player walks toward the heart of the overlap (the deepest reachable
## point), with no announced borders. Each tile carries an overlap intensity
## 0.0..1.0 — 0.0 at the entry, 1.0 at the heart. Tile assets shift with
## intensity in bands. On ritual success the overlap reverts, "spreading outward
## from the heart" (s56.16.5f / .191): raising restoration_progress heals the
## high-intensity tiles first, then progressively the lower ones.
##
## Pure layer (no Node). Base tiles are NEVER mutated — display_tile() derives the
## shown tile from base + intensity, so reversion is just lowering an intensity
## scalar. Intensity is driven by AsciiMapData.depth_grid (s56.21).
##
## Per-realm/element flavour is LOCKED in s56.16.1/.2. The band thresholds and the
## exact TileType substitutions below were owner-approved 2026-06-16 (the GDD
## specifies the flavour, not the tile vocabulary — which is mortal-realm only, so
## these picks approximate "otherworldly" with the tiles that exist). PROVISIONAL.

# Band cutoffs on the 0.0..1.0 intensity scale (owner-approved 2026-06-16).
# < MIDDLE_BAND  → outer / untouched (base tile).
# >= MIDDLE_BAND → middle band (partial transformation).
# >= HEART_BAND  → heart band (full transformation).
const MIDDLE_BAND: float = 0.33
const HEART_BAND: float  = 0.66

# Deterministic Gaki-do/Toshigoku rubble sprinkle at the heart (fraction PROVISIONAL).
const _RUBBLE_HASH_MOD: int = 4


# ── Application ───────────────────────────────────────────────────────────────

## Stamps the overlap-intensity gradient onto `map` from its depth_grid and tags
## the realm/element. Call AFTER AsciiMapData.compute_depth_grid(). Reachable tile
## intensity = depth / max_depth (entry 0.0 → heart 1.0); unreachable (-1) → 0.0.
## Degrades gracefully to an all-zero (visually inert) overlap when depth is
## uncomputed or the map is a single tile.
static func apply_overlap(
	map: AsciiMapData,
	event_type: int,
	realm: int = Enums.SpiritRealm.GAKI_DO,
	element: int = Enums.Ring.NONE,
) -> void:
	var n: int = map.width * map.height
	var intens: PackedFloat32Array = PackedFloat32Array()
	intens.resize(n)
	var max_depth: int = 0
	if map.has_depth_grid():
		for i in range(n):
			if map.depth_grid[i] > max_depth:
				max_depth = map.depth_grid[i]
	if max_depth > 0 and map.has_depth_grid():
		for i in range(n):
			var d: int = map.depth_grid[i]
			intens[i] = 0.0 if d < 0 else float(d) / float(max_depth)
	# else: intens stays all 0.0 — overlap is tagged but visually inert.
	map.overlap_intensity = intens
	map.spiritual_event_type = event_type
	map.spiritual_realm = realm
	map.spiritual_element = element
	map.overlap_max_depth = max_depth
	map.restoration_progress = 0.0


## Advances ritual healing. Healing spreads outward from the heart: a tile is
## healed once its intensity >= 1.0 - restoration_progress (the heart, intensity
## ~1.0, heals first). Returns the new progress (clamped 0..1).
static func advance_restoration(map: AsciiMapData, amount: float) -> float:
	map.restoration_progress = clampf(map.restoration_progress + amount, 0.0, 1.0)
	return map.restoration_progress


# ── Query ─────────────────────────────────────────────────────────────────────

## Overlap intensity at (x,y) AFTER restoration healing. Returns 0.0 for healed
## tiles (intensity >= 1.0 - restoration_progress while progress > 0).
static func current_intensity_at(map: AsciiMapData, x: int, y: int) -> float:
	var inten: float = map.intensity_at(x, y)
	if map.restoration_progress > 0.0 and inten >= 1.0 - map.restoration_progress:
		return 0.0
	return inten


## The tile to DISPLAY at (x,y): the base tile when no overlap / below the middle
## band / healed, otherwise the realm- or element-transformed tile.
static func display_tile(map: AsciiMapData, x: int, y: int) -> int:
	var base: int = map.get_tile(x, y)
	if not map.has_overlap():
		return base
	var inten: float = current_intensity_at(map, x, y)
	if inten < MIDDLE_BAND:
		return base
	var band: int = 2 if inten >= HEART_BAND else 1
	if map.spiritual_event_type == Enums.SpiritualEventType.ELEMENTAL_IMBALANCE:
		return _transform_element(base, map.spiritual_element, band, x, y)
	return _transform_realm(base, map.spiritual_realm, band, x, y)


# ── Tile classification helpers ───────────────────────────────────────────────

static func _is_living_tree(t: int) -> bool:
	return t == Enums.TileType.TREE_EVERGREEN or t == Enums.TileType.TREE_DECIDUOUS \
		or t == Enums.TileType.TREE_CHERRY or t == Enums.TileType.BAMBOO

static func _is_ground_veg(t: int) -> bool:
	return t == Enums.TileType.FLOOR_GRASS or t == Enums.TileType.GROUNDCOVER \
		or t == Enums.TileType.FLOWERS or t == Enums.TileType.BUSH or t == Enums.TileType.CROPS

## Passable natural/built floors that a realm can re-skin (excludes water/walls/doors).
static func _is_passable_floor(t: int) -> bool:
	return t == Enums.TileType.FLOOR_GRASS or t == Enums.TileType.FLOOR_DIRT \
		or t == Enums.TileType.FLOOR_WOOD or t == Enums.TileType.FLOOR_TATAMI \
		or t == Enums.TileType.FLOOR_STONE or t == Enums.TileType.FLOOR_MUD \
		or t == Enums.TileType.FLOOR_SNOW or t == Enums.TileType.FLOOR_SAND

static func _rubble_sprinkle(x: int, y: int) -> bool:
	return ((x * 31 + y * 17) % _RUBBLE_HASH_MOD) == 0


# ── Realm transforms (s56.16.1) ───────────────────────────────────────────────

static func _transform_realm(base: int, realm: int, band: int, x: int, y: int) -> int:
	match realm:
		Enums.SpiritRealm.GAKI_DO:
			# Grey, hollow, decaying.
			if _is_living_tree(base):
				return Enums.TileType.TREE_DEAD
			if band >= 2 and (_is_passable_floor(base) or _is_ground_veg(base)):
				return Enums.TileType.RUBBLE if _rubble_sprinkle(x, y) else Enums.TileType.FLOOR_ASH
			if _is_ground_veg(base):
				return Enums.TileType.FLOOR_DIRT
		Enums.SpiritRealm.TOSHIGOKU:
			# Old battlefield — churned, ruined ground.
			if _is_living_tree(base):
				return Enums.TileType.TREE_DEAD
			if band >= 2 and (_is_passable_floor(base) or _is_ground_veg(base)):
				return Enums.TileType.RUBBLE
			if _is_ground_veg(base):
				return Enums.TileType.FLOOR_DIRT
		Enums.SpiritRealm.CHIKUSHUDO:
			# Deeper, older forest — open ground thickens into woodland.
			if band >= 2:
				if base == Enums.TileType.FLOWERS:
					return Enums.TileType.BAMBOO
				if base == Enums.TileType.FLOOR_GRASS or base == Enums.TileType.FLOOR_DIRT \
						or base == Enums.TileType.GROUNDCOVER or base == Enums.TileType.BUSH:
					return Enums.TileType.TREE_EVERGREEN
			else:
				if base == Enums.TileType.BUSH:
					return Enums.TileType.TREE_DECIDUOUS
				if base == Enums.TileType.FLOOR_GRASS or base == Enums.TileType.GROUNDCOVER:
					return Enums.TileType.BUSH
		Enums.SpiritRealm.MEIDO:
			# Cold, colourless, still.
			if _is_living_tree(base):
				return Enums.TileType.TREE_DEAD
			if band >= 2 and (_is_passable_floor(base) or _is_ground_veg(base)):
				return Enums.TileType.FLOOR_ASH
			if _is_ground_veg(base):
				return Enums.TileType.FLOOR_SNOW
		_:
			# SAKKAKU / YUME_DO: illusion / dream-logic realms — the wrongness is
			# perceptual, not in the terrain palette (s56.16.1b). No tile change.
			return base
	return base


# ── Element transforms (s56.16.2) ─────────────────────────────────────────────

static func _transform_element(base: int, element: int, band: int, _x: int, _y: int) -> int:
	match element:
		Enums.Ring.FIRE:
			# Scorched earth → glowing/burning ground.
			if band >= 2:
				if _is_passable_floor(base) or _is_ground_veg(base) or _is_living_tree(base):
					return Enums.TileType.FIRE
			else:
				if _is_living_tree(base):
					return Enums.TileType.TREE_DEAD
				if _is_passable_floor(base) or _is_ground_veg(base):
					return Enums.TileType.FLOOR_ASH
		Enums.Ring.WATER:
			# Flooding.
			if _is_passable_floor(base) or _is_ground_veg(base):
				return Enums.TileType.WATER_DEEP if band >= 2 else Enums.TileType.WATER_SHALLOW
		Enums.Ring.EARTH:
			# Collapsing ground.
			if _is_passable_floor(base) or _is_ground_veg(base):
				return Enums.TileType.RUBBLE
		_:
			# AIR (wind) / VOID (disorientation): mechanical/perceptual hazards,
			# not a terrain palette shift (s56.16.2). No tile change.
			return base
	return base
