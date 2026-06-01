class_name FovSystem
## Field-of-vision computation for the ASCII map (s4.4).
##
## Base vision radius = character's Perception trait (s4.4.2).
## Environmental modifiers subtract from Perception before computing radius;
## minimum effective radius is always 1 regardless of modifiers.
##
## LOS is computed by tracing a line from the viewer to each candidate tile
## using Bresenham's algorithm. A tile is visible if the line reaches it without
## passing through any LOS-blocking tile (other than the candidate itself).
## The blocking tile at the exact edge of radius is visible — you can see the
## wall in front of you, just not past it.


# Environmental modifier constants (s4.4.2, LOCKED).
const ENV_CLEAR: int = 0
const ENV_OVERCAST: int = 1
const ENV_HEAVY_RAIN: int = 2
const ENV_NIGHT: int = 3
const ENV_SUPERNATURAL: int = 4


static func effective_radius(perception: int, env_modifier: int) -> int:
	return maxi(1, perception - env_modifier)


# Returns a Dictionary keyed by Vector2i with value true for every tile
# visible from (cx, cy) within the given radius on the supplied map.
# The viewer's own tile is always included.
static func compute_visible(
	cx: int,
	cy: int,
	radius: int,
	map: AsciiMapData,
) -> Dictionary:
	var visible: Dictionary = {}
	# Viewer's own tile is always visible.
	visible[Vector2i(cx, cy)] = true

	# Iterate all tiles within the bounding square then filter by circular radius.
	for ty in range(cy - radius, cy + radius + 1):
		for tx in range(cx - radius, cx + radius + 1):
			if tx == cx and ty == cy:
				continue
			# Circular radius check.
			var dx: int = tx - cx
			var dy: int = ty - cy
			if dx * dx + dy * dy > radius * radius:
				continue
			# Trace line; candidate tile is visible if line reaches it unobstructed.
			if _has_line_of_sight(cx, cy, tx, ty, map):
				visible[Vector2i(tx, ty)] = true
	return visible


# Returns true if there is unobstructed LOS from (x0,y0) to (x1,y1).
# Uses Bresenham's line algorithm. The start tile is never blocking; the end
# tile may be a wall (visible but not see-through).
static func _has_line_of_sight(
	x0: int, y0: int,
	x1: int, y1: int,
	map: AsciiMapData,
) -> bool:
	var steps: Array[Vector2i] = _bresenham(x0, y0, x1, y1)
	# Skip index 0 (start tile). Check every intermediate tile; if blocked,
	# LOS fails. The last tile (index == steps.size()-1) is always included
	# as visible even if it blocks LOS — you can see the wall itself.
	var last: int = steps.size() - 1
	for i in range(1, steps.size()):
		var p: Vector2i = steps[i]
		var tile: int = map.get_tile(p.x, p.y)
		if AsciiMapData.blocks_los(tile):
			# The blocking tile itself is visible, but nothing behind it.
			return i == last
	return true


# Returns the sequence of grid cells traversed by Bresenham's line from
# (x0,y0) to (x1,y1), inclusive of both endpoints.
static func _bresenham(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x1 > x0 else -1
	var sy: int = 1 if y1 > y0 else -1
	var err: int = dx - dy
	var cx: int = x0
	var cy: int = y0
	while true:
		pts.append(Vector2i(cx, cy))
		if cx == x1 and cy == y1:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			cx += sx
		if e2 < dx:
			err += dx
			cy += sy
	return pts
