class_name EventDurations

enum EventType {
	MASS_BATTLE,
	SIEGE,
	COURT_SEASON,
	FESTIVAL,
	DIPLOMATIC_SUMMIT,
	TOURNAMENT,
}

const OOC_TO_IC_RATIO: int = 4

const DURATIONS_OOC: Dictionary = {
	EventType.MASS_BATTLE: {"min": 1, "max": 1},
	EventType.SIEGE: {"min": 15, "max": 30},
	EventType.COURT_SEASON: {"min": 30, "max": 30},
	EventType.FESTIVAL: {"min": 3, "max": 3},
	EventType.DIPLOMATIC_SUMMIT: {"min": 5, "max": 7},
	EventType.TOURNAMENT: {"min": 3, "max": 5},
}


static func get_ooc_duration(event_type: EventType, variant: String = "min") -> int:
	var entry: Dictionary = DURATIONS_OOC.get(event_type, {"min": 1, "max": 1})
	if variant == "max":
		return entry["max"]
	return entry["min"]


static func get_ic_duration(event_type: EventType, variant: String = "min") -> int:
	return get_ooc_duration(event_type, variant) * OOC_TO_IC_RATIO


static func get_ic_ticks(event_type: EventType, variant: String = "min") -> int:
	return get_ic_duration(event_type, variant)


static func is_variable_duration(event_type: EventType) -> bool:
	var entry: Dictionary = DURATIONS_OOC.get(event_type, {"min": 1, "max": 1})
	return entry["min"] != entry["max"]


static func get_all_durations() -> Dictionary:
	var result: Dictionary = {}
	for event_type in EventType.values():
		var entry: Dictionary = DURATIONS_OOC.get(event_type, {"min": 1, "max": 1})
		result[event_type] = {
			"ooc_min": entry["min"],
			"ooc_max": entry["max"],
			"ic_min": entry["min"] * OOC_TO_IC_RATIO,
			"ic_max": entry["max"] * OOC_TO_IC_RATIO,
		}
	return result
