class_name TemplateSelector
## s56.2 ASCII map template probability pools --- LOCKED.
## Selects the correct map template for a given terrain type and province history.
## All weights are GDD-locked; do not adjust without a spec change.

# -- Template ID strings -------------------------------------------------------
# These must match the class_name of the generator that produces each template.

const OCCUPIED_VILLAGE:    String = "OccupiedVillage"
const MAKESHIFT_STOCKADE:  String = "MakeshiftStockade"
const RUINED_STRUCTURE:    String = "RuinedStructure"
const RAVINE_CAMP:         String = "RavineCamp"
const FOREST_APPROACH_CAMP: String = "ForestApproachCamp"
const CAVE:                String = "Cave"
const HILLTOP_POSITION:    String = "HilltopPosition"

# -- Ruin-eligibility province history tags ------------------------------------
# Province histories containing any of these tags unlock RUINED_STRUCTURE.

const RUIN_TAGS: Array = [
	"war_damage",
	"famine",
	"taint_corruption",
	"peasant_revolt",
	"natural_decay",
]

# -- Probability pools per terrain (GDD s56.2) ---------------------------------
# Each entry: {template: String, weight: int}
# Weights are relative; they sum to 100 for readability but don't need to.
# RUINED_STRUCTURE weight is redistributed when no ruin condition applies.

const _POOLS: Dictionary = {
	# Plains / River Delta / Coastal share the flatlands pool.
	Enums.TerrainType.PLAINS: [
		{template = OCCUPIED_VILLAGE,   weight = 45},
		{template = MAKESHIFT_STOCKADE, weight = 35},
		{template = RUINED_STRUCTURE,   weight = 15},
		{template = RAVINE_CAMP,        weight = 5},
	],
	Enums.TerrainType.RIVER_DELTA: [
		{template = OCCUPIED_VILLAGE,   weight = 50},
		{template = MAKESHIFT_STOCKADE, weight = 20},
		{template = RUINED_STRUCTURE,   weight = 20},
		{template = RAVINE_CAMP,        weight = 10},
	],
	Enums.TerrainType.COASTAL: [
		{template = OCCUPIED_VILLAGE,   weight = 50},
		{template = MAKESHIFT_STOCKADE, weight = 20},
		{template = RUINED_STRUCTURE,   weight = 20},
		{template = RAVINE_CAMP,        weight = 10},
	],
	# Forest / light hills pool.
	Enums.TerrainType.FOREST: [
		{template = FOREST_APPROACH_CAMP, weight = 40},
		{template = CAVE,                 weight = 20},
		{template = HILLTOP_POSITION,     weight = 15},
		{template = OCCUPIED_VILLAGE,     weight = 15},
		{template = RUINED_STRUCTURE,     weight = 10},
	],
	# Heavy hills pool (Hills enum).
	Enums.TerrainType.HILLS: [
		{template = CAVE,                 weight = 30},
		{template = HILLTOP_POSITION,     weight = 25},
		{template = RAVINE_CAMP,          weight = 20},
		{template = RUINED_STRUCTURE,     weight = 15},
		{template = FOREST_APPROACH_CAMP, weight = 10},
	],
	# Mountains pool.
	Enums.TerrainType.MOUNTAINS: [
		{template = CAVE,             weight = 50},
		{template = RAVINE_CAMP,      weight = 20},
		{template = HILLTOP_POSITION, weight = 20},
		{template = RUINED_STRUCTURE, weight = 10},
	],
	# Wasteland: same pool as plains (flat, degraded terrain).
	Enums.TerrainType.WASTELAND: [
		{template = OCCUPIED_VILLAGE,   weight = 45},
		{template = MAKESHIFT_STOCKADE, weight = 35},
		{template = RUINED_STRUCTURE,   weight = 15},
		{template = RAVINE_CAMP,        weight = 5},
	],
	# Swamp: same pool as forest (overgrown, no open ground).
	Enums.TerrainType.SWAMP: [
		{template = FOREST_APPROACH_CAMP, weight = 40},
		{template = CAVE,                 weight = 20},
		{template = HILLTOP_POSITION,     weight = 15},
		{template = OCCUPIED_VILLAGE,     weight = 15},
		{template = RUINED_STRUCTURE,     weight = 10},
	],
}

# -- Public API ----------------------------------------------------------------

## Returns the template ID string for the given terrain and province history.
## seed_str is used to break ties deterministically.
static func select_template(terrain: int, province_history: Array, seed_str: String) -> String:
	var pool: Array = _get_pool(terrain)
	var has_ruin: bool = province_has_ruin(province_history)
	var effective_pool: Array = _apply_ruin_condition(pool, has_ruin)
	return _weighted_pick(effective_pool, seed_str)

## Returns true when the province history contains at least one ruin-eligible tag.
static func province_has_ruin(province_history: Array) -> bool:
	for tag in province_history:
		if tag in RUIN_TAGS:
			return true
	return false

# -- Internal helpers ----------------------------------------------------------

static func _get_pool(terrain: int) -> Array:
	if _POOLS.has(terrain):
		return _POOLS[terrain]
	# Default fallback: plains pool.
	return _POOLS[Enums.TerrainType.PLAINS]

## When no ruin condition is present, redistribute the RUINED_STRUCTURE weight
## proportionally among the remaining templates.
static func _apply_ruin_condition(pool: Array, has_ruin: bool) -> Array:
	if has_ruin:
		return pool
	# Find ruin entry and its weight.
	var ruin_weight: int = 0
	var others: Array = []
	for entry in pool:
		if entry["template"] == RUINED_STRUCTURE:
			ruin_weight = entry["weight"]
		else:
			others.append({template = entry["template"], weight = entry["weight"]})
	if ruin_weight == 0 or others.is_empty():
		return pool
	# Distribute ruin weight to remaining entries proportionally by their weights.
	var total_other: int = 0
	for e in others:
		total_other += e["weight"]
	var result: Array = []
	var distributed: int = 0
	for i in range(others.size()):
		var e: Dictionary = others[i]
		var extra: int = int(round(float(ruin_weight) * e["weight"] / total_other))
		if i == others.size() - 1:
			# Assign remainder to last entry to guarantee total is preserved.
			result.append({template = e["template"], weight = e["weight"] + ruin_weight - distributed})
		else:
			result.append({template = e["template"], weight = e["weight"] + extra})
			distributed += extra
	return result

## FNV-1a hash of seed_str into a pick value; walks the pool with it.
static func _weighted_pick(pool: Array, seed_str: String) -> String:
	var total: int = 0
	for entry in pool:
		total += entry["weight"]
	if total == 0:
		return pool[0]["template"] if not pool.is_empty() else OCCUPIED_VILLAGE
	var h: int = _fnv1a(seed_str)
	var pick: int = h % total
	var cumulative: int = 0
	for entry in pool:
		cumulative += entry["weight"]
		if pick < cumulative:
			return entry["template"]
	return pool[pool.size() - 1]["template"]

static func _fnv1a(s: String) -> int:
	var h: int = 0x811c9dc5
	for c in s.to_utf8_buffer():
		h ^= c
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
