class_name NavalMovementSystem
## Sub-tile naval movement / voyage engine per GDD s11.9 ("N real days per sub-tile"
## by ship class) and s57.43 (voyage play). Routes a ship or named vessel across the
## water-movement graph (WaterSubtileData nodes), gated by class traversability
## (NavalSystem.can_traverse) and paying the class's per-sub-tile day cost.
##
## Pure static functions. Operates on ShipData AND NamedVesselData interchangeably by
## duck typing — both expose ship_class / current_province_id / current_subtile_id /
## is_moving / destination_subtile_id / movement_days_remaining / voyage_route /
## voyage_destination_province / is_destroyed.
##
## LOCATION-DATA DEPENDENCY: the graph (`water_subtiles`) is empty until the real
## world-map coordinates exist. Every function here is inert on an empty graph
## (build_index returns {}, find_route returns []), so the engine is turnkey — it
## activates the moment WaterSubtileData instances are populated. No numeric game
## values are invented: hop cost comes from NavalSystem.get_movement_days, traversal
## from NavalSystem.can_traverse, deep-ocean loss from NavalSystem.get_deep_ocean_loss_chance.


# -- Graph Index ---------------------------------------------------------------

## Build a fast subtile_id -> WaterSubtileData lookup from the world's water_subtiles
## Array. Call once per tick; pass the result to the other functions.
static func build_index(water_subtiles: Array) -> Dictionary:
	var index: Dictionary = {}
	for st: WaterSubtileData in water_subtiles:
		if st == null or st.subtile_id < 0:
			continue
		index[st.subtile_id] = st
	return index


## First port sub-tile of `province_id` that `ship_class` can traverse (a ship can
## only dock where it can float). -1 if the province has no reachable port for this
## class (or no port at all).
static func port_subtile_for_province(index: Dictionary, province_id: int, ship_class: int) -> int:
	if province_id < 0:
		return -1
	for subtile_id: int in index:
		var st: WaterSubtileData = index[subtile_id]
		if province_id in st.port_province_ids and NavalSystem.can_traverse(ship_class, st.water_type):
			return subtile_id
	return -1


# -- Routing (Dijkstra over the adjacency graph) -------------------------------

## Shortest traversable route from `from_subtile` to `to_subtile` for `ship_class`,
## as the ordered list of sub-tile ids to ENTER (excludes the origin, includes the
## destination). Edge cost = NavalSystem.get_movement_days(ship_class) (days to enter
## a neighbour). Sub-tiles the class cannot traverse are excluded. Returns [] if no
## route exists, if either endpoint is untraversable/unknown, or from == to.
static func find_route(index: Dictionary, from_subtile: int, to_subtile: int, ship_class: int) -> PackedInt32Array:
	var empty: PackedInt32Array = PackedInt32Array()
	if from_subtile == to_subtile:
		return empty
	if not index.has(from_subtile) or not index.has(to_subtile):
		return empty
	if not _traversable(index, to_subtile, ship_class):
		return empty
	if not _traversable(index, from_subtile, ship_class):
		return empty

	var hop_cost: int = maxi(1, NavalSystem.get_movement_days(ship_class))
	var dist: Dictionary = {from_subtile: 0}
	var prev: Dictionary = {}
	var visited: Dictionary = {}
	# Simple O(V^2) Dijkstra — sub-tile graphs are small and this runs per voyage-start.
	while true:
		var current: int = -1
		var best: int = -1
		for node: int in dist:
			if visited.has(node):
				continue
			var d: int = dist[node]
			if best < 0 or d < best:
				best = d
				current = node
		if current < 0:
			break
		if current == to_subtile:
			break
		visited[current] = true
		var st: WaterSubtileData = index[current]
		for neighbour: int in st.adjacent_subtile_ids:
			if not _traversable(index, neighbour, ship_class):
				continue
			if visited.has(neighbour):
				continue
			var nd: int = dist[current] + hop_cost
			if not dist.has(neighbour) or nd < dist[neighbour]:
				dist[neighbour] = nd
				prev[neighbour] = current

	if not prev.has(to_subtile) and to_subtile != from_subtile:
		return empty

	# Reconstruct origin-exclusive, destination-inclusive path.
	var reversed: Array[int] = []
	var walk: int = to_subtile
	while walk != from_subtile:
		reversed.append(walk)
		if not prev.has(walk):
			return empty
		walk = prev[walk]
	var route: PackedInt32Array = PackedInt32Array()
	for i: int in range(reversed.size() - 1, -1, -1):
		route.append(reversed[i])
	return route


static func _traversable(index: Dictionary, subtile_id: int, ship_class: int) -> bool:
	var st: WaterSubtileData = index.get(subtile_id)
	if st == null:
		return false
	return NavalSystem.can_traverse(ship_class, st.water_type)


## Total day cost of a computed route for `ship_class`.
static func route_day_cost(route: PackedInt32Array, ship_class: int) -> int:
	return route.size() * maxi(1, NavalSystem.get_movement_days(ship_class))


# -- Pirate Hazard (s57.43.7) --------------------------------------------------

## Map subtile_id -> pirate fleet strength lurking on it, derived from active
## PIRATE_FLEET insurgencies (s11.11): a sub-tile that ports to a pirate-infested
## province carries that insurgency's strength (pirates operate off the coast they
## infest). Strongest infestation wins per sub-tile. Empty if no pirate fleets or no
## graph. Consumed by step_movement for the per-hop interception roll.
static func build_pirate_strength_map(index: Dictionary, insurgencies: Array) -> Dictionary:
	var out: Dictionary = {}
	if index.is_empty():
		return out
	var pirate_provinces: Dictionary = {}  # province_id -> max strength
	for ins: InsurgencyData in insurgencies:
		if ins == null or ins.insurgency_type != Enums.InsurgencyType.PIRATE_FLEET:
			continue
		if ins.strength <= 0 or ins.province_id < 0:
			continue
		pirate_provinces[ins.province_id] = maxi(pirate_provinces.get(ins.province_id, 0), ins.strength)
	if pirate_provinces.is_empty():
		return out
	for subtile_id: int in index:
		var st: WaterSubtileData = index[subtile_id]
		var best: int = 0
		for prov: int in st.port_province_ids:
			if pirate_provinces.has(prov):
				best = maxi(best, pirate_provinces[prov])
		if best > 0:
			out[subtile_id] = best
	return out


# -- Voyage Commands -----------------------------------------------------------

## Begin a voyage: route the mover (ship or vessel) from where it is now to a port of
## `dest_province`, and launch its first hop. If the mover is docked (current_subtile_id
## < 0) it undocks into its current province's port sub-tile first. Returns
## {success, reason?, route_len, total_days, destination_subtile}.
static func begin_voyage(mover: Object, index: Dictionary, dest_province: int) -> Dictionary:
	if mover.is_destroyed:
		return {"success": false, "reason": "destroyed"}
	if mover.is_moving:
		return {"success": false, "reason": "already_moving"}
	if index.is_empty():
		return {"success": false, "reason": "no_water_graph"}

	var ship_class: int = mover.ship_class
	var origin: int = mover.current_subtile_id
	if origin < 0:
		origin = port_subtile_for_province(index, mover.current_province_id, ship_class)
		if origin < 0:
			return {"success": false, "reason": "no_origin_port"}

	var dest: int = port_subtile_for_province(index, dest_province, ship_class)
	if dest < 0:
		return {"success": false, "reason": "no_destination_port"}
	if dest == origin:
		return {"success": false, "reason": "already_at_destination"}

	var route: PackedInt32Array = find_route(index, origin, dest, ship_class)
	if route.is_empty():
		return {"success": false, "reason": "no_route"}

	# Undock into the water at the origin sub-tile, then launch the first hop.
	mover.current_subtile_id = origin
	mover.voyage_destination_province = dest_province
	var hop_cost: int = maxi(1, NavalSystem.get_movement_days(ship_class))
	mover.destination_subtile_id = route[0]
	mover.movement_days_remaining = hop_cost
	mover.is_moving = true
	# Store the hops AFTER the first (the first is the active destination_subtile_id).
	var remaining: PackedInt32Array = PackedInt32Array()
	for i: int in range(1, route.size()):
		remaining.append(route[i])
	mover.voyage_route = remaining

	return {
		"success": true,
		"route_len": route.size(),
		"total_days": route_day_cost(route, ship_class),
		"destination_subtile": dest,
	}


## Advance one day of movement for a ship or vessel. Handles single-hop moves AND
## multi-hop voyages. On entering an OCEAN sub-tile a non-ocean-capable class rolls
## deep-ocean loss (NavalSystem). On voyage completion the mover docks at its
## voyage_destination_province (current_subtile_id -> -1). Returns a per-day result.
static func step_movement(mover: Object, index: Dictionary, dice: DiceEngine,
		pirate_strength_by_subtile: Dictionary = {}) -> Dictionary:
	if not mover.is_moving:
		return {"moved": false}

	mover.movement_days_remaining -= 1
	if mover.movement_days_remaining > 0:
		return {"moved": true, "arrived": false, "days_remaining": mover.movement_days_remaining}

	# Reached the current hop's sub-tile.
	var prev_subtile: int = mover.current_subtile_id
	mover.current_subtile_id = mover.destination_subtile_id

	# Deep-ocean loss for the sub-tile just entered.
	var lost: bool = false
	var entered: WaterSubtileData = index.get(mover.current_subtile_id)
	if entered != null and entered.water_type == Enums.WaterSubtileType.OCEAN:
		var loss_chance: float = NavalSystem.get_deep_ocean_loss_chance(mover.ship_class)
		if loss_chance > 0.0 and dice != null:
			if dice.rand_int_range(1, 100) <= ceili(loss_chance * 100.0):
				lost = true
	if lost:
		mover.is_destroyed = true
		mover.is_moving = false
		mover.destination_subtile_id = -1
		mover.movement_days_remaining = 0
		mover.voyage_route = PackedInt32Array()
		return {
			"moved": true, "arrived": true, "deep_ocean_loss": true,
			"from_subtile": prev_subtile, "to_subtile": mover.current_subtile_id,
		}

	# Pirate interception for the sub-tile just entered (s57.43.7). Detection only:
	# the mover keeps sailing and the caller resolves the encounter (naval mass battle
	# vs deck skirmish) downstream — pirate-fleet combat composition + the ASCII
	# skirmish layer are separate. The chance + resolution branch are GDD-sourced.
	var pirate_strength: int = pirate_strength_by_subtile.get(mover.current_subtile_id, 0)
	var interception: Dictionary = {}
	if pirate_strength > 0 and dice != null:
		var chance: float = SailingSystem.pirate_interception_chance(pirate_strength)
		if dice.rand_int_range(1, 100) <= ceili(chance * 100.0):
			interception = {
				"intercepted": true,
				"pirate_strength": pirate_strength,
				"resolution": SailingSystem.interception_resolution(pirate_strength),
				"subtile": mover.current_subtile_id,
			}

	# More hops on the voyage → launch the next one.
	if mover.voyage_route.size() > 0:
		var next_hop: int = mover.voyage_route[0]
		var remaining: PackedInt32Array = PackedInt32Array()
		for i: int in range(1, mover.voyage_route.size()):
			remaining.append(mover.voyage_route[i])
		mover.voyage_route = remaining
		mover.destination_subtile_id = next_hop
		mover.movement_days_remaining = maxi(1, NavalSystem.get_movement_days(mover.ship_class))
		var hop_result: Dictionary = {
			"moved": true, "arrived": false, "hop_complete": true,
			"from_subtile": prev_subtile, "to_subtile": mover.current_subtile_id,
			"days_remaining": mover.movement_days_remaining,
		}
		hop_result.merge(interception)
		return hop_result

	# Voyage complete (or single-hop finished).
	mover.is_moving = false
	mover.destination_subtile_id = -1
	mover.movement_days_remaining = 0
	var docked_province: int = mover.voyage_destination_province
	if docked_province >= 0:
		mover.current_province_id = docked_province
		mover.current_subtile_id = -1  # docked at the destination settlement
		mover.voyage_destination_province = -1
		var dock_result: Dictionary = {
			"moved": true, "arrived": true, "voyage_complete": true,
			"from_subtile": prev_subtile, "docked_province": docked_province,
		}
		dock_result.merge(interception)
		return dock_result
	# Bare single-hop with no voyage destination — just stop at the sub-tile.
	var stop_result: Dictionary = {
		"moved": true, "arrived": true,
		"from_subtile": prev_subtile, "to_subtile": mover.current_subtile_id,
	}
	stop_result.merge(interception)
	return stop_result
