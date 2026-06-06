class_name MissionPopulator
## s56.10 Mission population placement --- LOCKED.
## Distributes RosterCompositionSystem unit groups across the population_slots
## produced by the map template generators. Pure geometry — stat blocks (s54)
## and mechanical effects (s40) are deferred.
## Individual variance per s56.10.0a: 30-40% chance per unit, +1 to one trait.

# -- Slot tier constants -------------------------------------------------------
# Each map template's PopRole ints are mapped to one of four tiers so the
# distribution algorithm works the same across all template types.
#   TIER_LEADER (0) — deepest / most-protected command position.
#   TIER_GUARD  (1) — chokepoint, elevated, or secondary defensive.
#   TIER_PATROL (2) — sentry / patrol / outer perimeter.
#   TIER_BULK   (3) — main camp / bulk filler.

const TIER_LEADER: int = 0
const TIER_GUARD:  int = 1
const TIER_PATROL: int = 2
const TIER_BULK:   int = 3

# Per-template PopRole int → placement tier.
# Keyed by AsciiMapData subclass name (from get_class()).
const _TEMPLATE_TIERS: Dictionary = {
	"CaveMapData": {
		4: TIER_LEADER,   # LEADER
		3: TIER_GUARD,    # GUARD_POST
		1: TIER_PATROL,   # PATROL_WAYPOINT
		0: TIER_PATROL,   # SENTRY
		2: TIER_BULK,     # CAMP_GROUP
	},
	"OccupiedVillageMapData": {
		3: TIER_LEADER,   # LEADER
		1: TIER_PATROL,   # PATROL
		0: TIER_PATROL,   # SENTRY
		2: TIER_BULK,     # CAMP_GROUP
	},
	"ForestApproachCampMapData": {
		3: TIER_LEADER,   # LEADER_GROUP
		1: TIER_PATROL,   # FOREST_PATROL
		0: TIER_PATROL,   # OUTER_SENTRY
		2: TIER_BULK,     # CAMP_GROUP
	},
	"MakeshiftStockadeMapData": {
		4: TIER_LEADER,   # LEADER_GROUP
		2: TIER_GUARD,    # WATCHTOWER
		1: TIER_GUARD,    # GATE_GUARD
		0: TIER_PATROL,   # WALL_WATCHER
		3: TIER_BULK,     # CAMP_GROUP
	},
	"HilltopPositionMapData": {
		3: TIER_LEADER,   # LEADER_GROUP
		4: TIER_GUARD,    # EDGE_DEFENDER
		1: TIER_PATROL,   # PATH_GUARD
		0: TIER_PATROL,   # LOOKOUT
		2: TIER_BULK,     # CAMP_GROUP
	},
	"RavineCampMapData": {
		3: TIER_LEADER,   # LEADER_GROUP
		4: TIER_GUARD,    # RIM_WATCHER
		1: TIER_GUARD,    # CHOKEPOINT_HOLDER
		0: TIER_PATROL,   # MOUTH_GUARD
		2: TIER_BULK,     # CAMP_GROUP
	},
	"RuinedStructureMapData": {
		4: TIER_LEADER,   # LEADER_GROUP
		3: TIER_GUARD,    # UPPER_FLOOR_HOLDER
		2: TIER_GUARD,    # RUBBLE_LURKER
		0: TIER_PATROL,   # SENTRY
		1: TIER_BULK,     # ROOM_GROUP
	},
	"UrbanHideoutMapData": {
		5: TIER_LEADER,   # LEADER
		2: TIER_GUARD,    # DOOR_GUARD
		0: TIER_PATROL,   # LOOKOUT (surface)
		1: TIER_PATROL,   # SYMPATHIZER (surface)
		3: TIER_BULK,     # ZOMBIE_SCREEN
		4: TIER_BULK,     # CULTIST_GROUP
	},
	"CastleSiegeMapData": {
		4: TIER_LEADER,   # GARRISON_COMMANDER (tenshu / command building)
		1: TIER_GUARD,    # GATE_GUARD (chokepoint approach)
		2: TIER_GUARD,    # MURDER_HOLE_GUARD (elevated, flanking)
		0: TIER_PATROL,   # WALL_DEFENDER (wall walkways)
		3: TIER_BULK,     # BAILEY_DEFENDER (open courtyard)
		5: TIER_BULK,     # FRIENDLY_SOLDIER (player allies — own side)
	},
}

# -- Roster role → preferred placement tiers -----------------------------------
# Each entry lists tiers to try in priority order; overflow to the next.
const _ROLE_TIERS: Dictionary = {
	RosterCompositionSystem.ROLE_LEADER:               [TIER_LEADER, TIER_GUARD],
	RosterCompositionSystem.ROLE_FOCAL_POINT_GUARDIAN: [TIER_LEADER, TIER_GUARD],
	RosterCompositionSystem.ROLE_GUARD_POST:           [TIER_GUARD,  TIER_PATROL, TIER_BULK],
	RosterCompositionSystem.ROLE_CHOKEPOINT_HOLDER:    [TIER_GUARD,  TIER_PATROL, TIER_BULK],
	RosterCompositionSystem.ROLE_EDGE_DEFENDER:        [TIER_GUARD,  TIER_PATROL],
	RosterCompositionSystem.ROLE_RIM_WATCHER:          [TIER_GUARD,  TIER_PATROL],
	RosterCompositionSystem.ROLE_ESCAPE_GUARD:         [TIER_GUARD,  TIER_BULK],
	RosterCompositionSystem.ROLE_SENTRY:               [TIER_PATROL, TIER_GUARD,  TIER_BULK],
	RosterCompositionSystem.ROLE_PATROL_LEADER:        [TIER_PATROL, TIER_BULK],
	RosterCompositionSystem.ROLE_PATROL_FOLLOWER:      [TIER_PATROL, TIER_BULK],
	RosterCompositionSystem.ROLE_LOOKOUT_POSITION:     [TIER_PATROL, TIER_BULK],
	RosterCompositionSystem.ROLE_RITUAL_SPACE:         [TIER_BULK,   TIER_GUARD],
	RosterCompositionSystem.ROLE_CAMP_GROUP:           [TIER_BULK,   TIER_PATROL],
	RosterCompositionSystem.ROLE_WANDERER:             [TIER_BULK,   TIER_PATROL],
	RosterCompositionSystem.ROLE_EMERGENT_UNDEAD:      [TIER_BULK,   TIER_PATROL],
	RosterCompositionSystem.ROLE_CLUSTERED_PACK:       [TIER_BULK,   TIER_PATROL],
}

# Process order for groups: LEADER-class first, then GUARD-class, then the rest.
# Groups not listed here are processed last.
const _ROLE_ORDER: Array = [
	RosterCompositionSystem.ROLE_LEADER,
	RosterCompositionSystem.ROLE_FOCAL_POINT_GUARDIAN,
	RosterCompositionSystem.ROLE_GUARD_POST,
	RosterCompositionSystem.ROLE_CHOKEPOINT_HOLDER,
	RosterCompositionSystem.ROLE_EDGE_DEFENDER,
	RosterCompositionSystem.ROLE_RIM_WATCHER,
	RosterCompositionSystem.ROLE_ESCAPE_GUARD,
	RosterCompositionSystem.ROLE_SENTRY,
	RosterCompositionSystem.ROLE_PATROL_LEADER,
	RosterCompositionSystem.ROLE_LOOKOUT_POSITION,
	RosterCompositionSystem.ROLE_PATROL_FOLLOWER,
	RosterCompositionSystem.ROLE_RITUAL_SPACE,
	RosterCompositionSystem.ROLE_CAMP_GROUP,
	RosterCompositionSystem.ROLE_WANDERER,
	RosterCompositionSystem.ROLE_EMERGENT_UNDEAD,
	RosterCompositionSystem.ROLE_CLUSTERED_PACK,
]

# Individual variance trait pool (s56.10.0a) — eight L5R 4e core traits.
# Skill-specific variance deferred to s54 stat blocks.
const _VARIANCE_TRAITS: Array = [
	"Agility", "Awareness", "Intelligence", "Perception",
	"Reflexes", "Stamina", "Strength", "Willpower",
]

# -- Public API ----------------------------------------------------------------

## Distributes all groups in roster["groups"] across the map's population_slots.
## Returns Array of placement dicts:
##   { "unit_type": String, "x": int, "y": int,
##     "map_role_int": int, "roster_role_str": String,
##     "variance": Dictionary }   # {} or {"stat": String, "bonus": 1}
## Multiple placements can share the same (x, y) — tiles are approximate
## positions, not strict one-unit-per-tile rules.
static func populate(map: AsciiMapData, roster: Dictionary, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pop_" + map.seed_string + "_" + str(seed))

	var groups: Array = roster.get("groups", [])
	if groups.is_empty() or map.population_slots.is_empty():
		return []

	var tier_map: Dictionary  = _build_tier_map(map)
	var slots_by_tier: Dictionary = _bucket_slots(map.population_slots, tier_map)
	var sorted_groups: Array  = _sort_groups(groups)

	var placements: Array = []
	for group in sorted_groups:
		var role_str: String  = group.get("role", "")
		var unit_type: String = group.get("unit_type", "")
		var count: int        = group.get("count", 0)
		if count <= 0 or unit_type.is_empty():
			continue

		var tier_order: Array = _ROLE_TIERS.get(role_str,
			[TIER_BULK, TIER_PATROL, TIER_GUARD, TIER_LEADER])
		var candidate_slots: Array = _gather_candidates(slots_by_tier, tier_order)

		var variance_chance: float = roster.get("individual_variance_chance",
			RosterCompositionSystem.INDIVIDUAL_VARIANCE_CHANCE_MIN)

		for i in range(count):
			var slot_dict: Dictionary = _pick_slot(
				candidate_slots, map.population_slots, i)
			placements.append({
				"unit_type":       unit_type,
				"x":               slot_dict.get("x", 0),
				"y":               slot_dict.get("y", 0),
				"map_role_int":    slot_dict.get("role", -1),
				"roster_role_str": role_str,
				"variance":        _roll_variance(rng, variance_chance),
			})

	return placements


## Wall-sortie variant: returns { "friendly": [...], "enemy": [...] }.
## Splits population_slots at map midpoint (x < width/2 → friendly side).
## PROVISIONAL midpoint split — final allocation deferred to s40 (ship/wall
## boarding templates define proper entry zones).
static func populate_sortie(
		map: AsciiMapData, roster: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("sortie_" + map.seed_string + "_" + str(seed))

	var tier_map: Dictionary = _build_tier_map(map)
	var midpoint_x: int      = map.width / 2

	# Split population_slots by x-coordinate.
	var entry_slots: Array = []
	var far_slots:   Array = []
	for sl: Dictionary in map.population_slots:
		if sl.get("x", 0) <= midpoint_x:
			entry_slots.append(sl)
		else:
			far_slots.append(sl)

	# Entry side (x <= midpoint) → friendly units.
	# Far side   (x > midpoint)  → enemy units.
	var friendly_slots_by_tier: Dictionary = _bucket_slots(entry_slots, tier_map)
	var enemy_slots_by_tier:    Dictionary = _bucket_slots(far_slots,   tier_map)

	var variance_chance: float = roster.get("individual_variance_chance",
		RosterCompositionSystem.INDIVIDUAL_VARIANCE_CHANCE_MIN)

	var friendly_placements: Array = _place_group_list(
		_sort_groups(roster.get("friendly_groups", [])),
		friendly_slots_by_tier,
		map.population_slots,
		"friendly",
		rng,
		variance_chance
	)
	var enemy_placements: Array = _place_group_list(
		_sort_groups(roster.get("enemy_groups", [])),
		enemy_slots_by_tier,
		map.population_slots,
		"enemy",
		rng,
		variance_chance
	)

	return {"friendly": friendly_placements, "enemy": enemy_placements}


# -- Internal helpers ----------------------------------------------------------

# Returns the tier map for the given map's class name.
# Falls back to treating all roles as TIER_BULK for unknown templates.
static func _build_tier_map(map: AsciiMapData) -> Dictionary:
	return _TEMPLATE_TIERS.get(map.get_class(), {})


# Groups population_slots Array by tier.
# Returns { TIER_LEADER: [slot_dicts...], TIER_GUARD: [...], ... }.
static func _bucket_slots(slots: Array, tier_map: Dictionary) -> Dictionary:
	var buckets: Dictionary = {
		TIER_LEADER: [],
		TIER_GUARD:  [],
		TIER_PATROL: [],
		TIER_BULK:   [],
	}
	for sl: Dictionary in slots:
		var role_int: int = sl.get("role", -1)
		var tier: int     = tier_map.get(role_int, TIER_BULK)
		buckets[tier].append(sl)
	return buckets


# Returns slots from slots_by_tier in tier_order priority; earlier tiers first.
static func _gather_candidates(
		slots_by_tier: Dictionary, tier_order: Array) -> Array:
	var result: Array = []
	for tier in tier_order:
		var bucket: Array = slots_by_tier.get(tier, [])
		result.append_array(bucket)
	return result


# Picks a slot for unit index i from candidates (round-robin).
# Falls back to first slot in full set if candidates is empty.
static func _pick_slot(
		candidates: Array,
		all_slots: Array,
		unit_index: int) -> Dictionary:
	if not candidates.is_empty():
		return candidates[unit_index % candidates.size()]
	if not all_slots.is_empty():
		return all_slots[unit_index % all_slots.size()]
	return {}


# Sorts groups by ROLE_ORDER priority so LEADER is placed first.
# Uses index-tracking for dedup to avoid false positives from value-equal dicts.
static func _sort_groups(groups: Array) -> Array:
	var sorted: Array = []
	var added_indices: Dictionary = {}   # index:int → true

	# First pass: ordered roles.
	for role in _ROLE_ORDER:
		for i: int in range(groups.size()):
			var g: Dictionary = groups[i]
			if g.get("role", "") == role and not added_indices.has(i):
				sorted.append(g)
				added_indices[i] = true
	# Second pass: any roles not in _ROLE_ORDER (forward-compatible).
	for i: int in range(groups.size()):
		if not added_indices.has(i):
			sorted.append(groups[i])
	return sorted


# Common placement loop used by both standard and sortie paths.
static func _place_group_list(
		sorted_groups: Array,
		slots_by_tier: Dictionary,
		all_slots: Array,
		side: String,
		rng: RandomNumberGenerator,
		variance_chance: float) -> Array:
	var placements: Array = []
	for group: Dictionary in sorted_groups:
		var role_str: String  = group.get("role", "")
		var unit_type: String = group.get("unit_type", "")
		var count: int        = group.get("count", 0)
		if count <= 0 or unit_type.is_empty():
			continue
		var tier_order: Array    = _ROLE_TIERS.get(role_str,
			[TIER_BULK, TIER_PATROL, TIER_GUARD, TIER_LEADER])
		var candidates: Array    = _gather_candidates(slots_by_tier, tier_order)
		for i in range(count):
			var slot_dict: Dictionary = _pick_slot(candidates, all_slots, i)
			var entry: Dictionary = {
				"unit_type":       unit_type,
				"x":               slot_dict.get("x", 0),
				"y":               slot_dict.get("y", 0),
				"map_role_int":    slot_dict.get("role", -1),
				"roster_role_str": role_str,
				"variance":        _roll_variance(rng, variance_chance),
			}
			if not side.is_empty():
				entry["side"] = side
			placements.append(entry)
	return placements


# Rolls individual variance for one unit (s56.10.0a).
# Returns {} (no variance) or {"stat": TraitName, "bonus": 1}.
static func _roll_variance(rng: RandomNumberGenerator, chance: float) -> Dictionary:
	if rng.randf() >= chance:
		return {}
	var idx: int = rng.randi() % _VARIANCE_TRAITS.size()
	return {"stat": _VARIANCE_TRAITS[idx], "bonus": 1}
