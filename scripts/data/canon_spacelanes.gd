extends RefCounted
class_name CanonSpacelaneData

# Canon hyperspace lane ordering used by Galaxy map generation.
# Categories 2 and 3 are intentionally left as templates for future use.

const CATEGORY_1: Array[Dictionary] = [
]

const CATEGORY_2: Array[Dictionary] = []
const CATEGORY_3: Array[Dictionary] = []

const ALL_LANES: Array[Dictionary] = CATEGORY_1 + CATEGORY_2 + CATEGORY_3

static func get_lane_route(lane_name: String) -> Dictionary:
	for lane_data in ALL_LANES:
		if String(lane_data.get("lane", "")) == lane_name:
			return lane_data
	return {}
