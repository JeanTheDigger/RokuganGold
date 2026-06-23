class_name FovSystem
## Field-of-vision computation for the ASCII map (s4.4.2).
##
## Base vision radius = character's Perception trait in tiles.
## Environmental modifiers subtract from Perception; minimum effective radius
## is always 1 (adjacent tiles always visible).
##
## Uses recursive shadowcasting (8-octant) for consistent LOS.  Wall tiles at
## the shadow edge are visible (you see the wall, not past it).


# Environmental modifier constants (s4.4.2, LOCKED).
const ENV_CLEAR: int = 0
const ENV_OVERCAST: int = 1
const ENV_HEAVY_RAIN: int = 2
const ENV_NIGHT: int = 3
const ENV_SUPERNATURAL: int = 4

# Lookout expanded radius bonus (s56.10, LOCKED). Also granted on raised ground
# (elevation > 0) — high ground sees farther (s4.4 Z-axis; owner-locked 2026-06-23).
const LOOKOUT_BONUS: int = 3

# Height-aware FOV occlusion (s4.4 Z-axis). Mirrors the combat-LOS sight model:
# the viewer's eye sits FOV_EYE_HEIGHT above their tile; an LOS-blocking tile
# (wall/tree) rises FOV_OBSTACLE_HEIGHT above its elevation, open ground only its
# raw elevation (a ridge can still block). An obstacle occludes only when its top
# reaches the viewer's eye height — so a viewer on high ground sees over lower
# obstacles. On a flat map (no elevation grid) this reduces to the binary
# blocks_los model exactly (zero regression).
const FOV_EYE_HEIGHT: int = 1
const FOV_OBSTACLE_HEIGHT: int = 2

# Octant transform multipliers for recursive shadowcasting.
const _XX: PackedInt32Array = [ 1,  0,  0, -1, -1,  0,  0,  1]
const _XY: PackedInt32Array = [ 0,  1, -1,  0,  0, -1,  1,  0]
const _YX: PackedInt32Array = [ 0,  1,  1,  0,  0, -1, -1,  0]
const _YY: PackedInt32Array = [ 1,  0,  0,  1, -1,  0,  0, -1]


static func effective_radius(perception: int, env_modifier: int) -> int:
	return maxi(1, perception - env_modifier)


static func lookout_radius(perception: int, env_modifier: int) -> int:
	return maxi(1, perception + LOOKOUT_BONUS - env_modifier)


# Returns a Dictionary keyed by Vector2i → true for every tile visible from
# (cx, cy) within the given radius.  The viewer's own tile is always included.
static func compute_visible(
	cx: int,
	cy: int,
	radius: int,
	map: AsciiMapData,
) -> Dictionary:
	var visible: Dictionary = {}
	visible[Vector2i(cx, cy)] = true
	# Height-aware occlusion when the map carries elevation (s4.4 Z-axis).
	var height_aware: bool = map.has_elevation()
	var viewer_eye: int = (map.elevation_at(cx, cy) + FOV_EYE_HEIGHT) if height_aware else 0
	for octant in range(8):
		_cast_light(cx, cy, radius, 1, 1.0, 0.0, octant, map, visible, height_aware, viewer_eye)
	return visible


# Point-to-point LOS check via Bresenham (no radius limit).
# Returns true if there is an unobstructed line between two tiles.
# The target tile is considered "reachable" even if it blocks LOS itself
# (you can see the wall, just not past it).
static func has_los(
	from_x: int, from_y: int,
	to_x: int, to_y: int,
	map: AsciiMapData,
) -> bool:
	return _has_line_of_sight(from_x, from_y, to_x, to_y, map)


# Convenience: checks both radius and LOS for a single target tile.
static func is_visible(
	from_x: int, from_y: int,
	to_x: int, to_y: int,
	radius: int,
	map: AsciiMapData,
) -> bool:
	var dx: int = to_x - from_x
	var dy: int = to_y - from_y
	if dx * dx + dy * dy > radius * radius:
		return false
	var visible: Dictionary = compute_visible(from_x, from_y, radius, map)
	return visible.has(Vector2i(to_x, to_y))


# -- Recursive shadowcasting (8-octant) --------------------------------------

static func _cast_light(
	cx: int, cy: int, radius: int,
	row: int, start_slope: float, end_slope: float,
	octant: int, map: AsciiMapData, visible: Dictionary,
	height_aware: bool = false, viewer_eye: int = 0,
) -> void:
	if start_slope < end_slope:
		return
	var radius_sq: int = radius * radius
	var new_start: float = 0.0
	for j in range(row, radius + 1):
		var dx: int = -j - 1
		var dy: int = -j
		var blocked: bool = false
		while dx <= 0:
			dx += 1
			var mx: int = cx + dx * _XX[octant] + dy * _XY[octant]
			var my: int = cy + dx * _YX[octant] + dy * _YY[octant]
			var l_slope: float = (float(dx) - 0.5) / (float(dy) + 0.5)
			var r_slope: float = (float(dx) + 0.5) / (float(dy) - 0.5)
			if start_slope < r_slope:
				continue
			if end_slope > l_slope:
				break
			if dx * dx + dy * dy <= radius_sq:
				if mx >= 0 and mx < map.width \
						and my >= 0 and my < map.height:
					visible[Vector2i(mx, my)] = true
			if blocked:
				if _is_opaque(mx, my, map, height_aware, viewer_eye):
					new_start = r_slope
				else:
					blocked = false
					start_slope = new_start
			elif _is_opaque(mx, my, map, height_aware, viewer_eye) and j < radius:
				blocked = true
				_cast_light(
					cx, cy, radius, j + 1, start_slope, l_slope,
					octant, map, visible, height_aware, viewer_eye,
				)
				new_start = r_slope
		if blocked:
			break


static func _is_opaque(
	x: int, y: int, map: AsciiMapData,
	height_aware: bool = false, viewer_eye: int = 0,
) -> bool:
	if x < 0 or x >= map.width or y < 0 or y >= map.height:
		return true
	var tile: int = map.get_tile(x, y)
	if not height_aware:
		return AsciiMapData.blocks_los(tile)
	# Height-aware: a tile occludes only when its top reaches the viewer's eye.
	var top: int = map.elevation_at(x, y)
	if AsciiMapData.blocks_los(tile):
		top += FOV_OBSTACLE_HEIGHT
	return top >= viewer_eye


# -- Bresenham line-of-sight (point-to-point) ---------------------------------

static func _has_line_of_sight(
	x0: int, y0: int,
	x1: int, y1: int,
	map: AsciiMapData,
) -> bool:
	var steps: Array[Vector2i] = _bresenham(x0, y0, x1, y1)
	var last: int = steps.size() - 1
	for i in range(1, steps.size()):
		var p: Vector2i = steps[i]
		var tile: int = map.get_tile(p.x, p.y)
		if AsciiMapData.blocks_los(tile):
			return i == last
	return true


static func _bresenham(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var adx: int = absi(x1 - x0)
	var ady: int = absi(y1 - y0)
	var sx: int = 1 if x1 > x0 else -1
	var sy: int = 1 if y1 > y0 else -1
	var err: int = adx - ady
	var cx: int = x0
	var cy: int = y0
	while true:
		pts.append(Vector2i(cx, cy))
		if cx == x1 and cy == y1:
			break
		var e2: int = 2 * err
		if e2 > -ady:
			err -= ady
			cx += sx
		if e2 < adx:
			err += adx
			cy += sy
	return pts
