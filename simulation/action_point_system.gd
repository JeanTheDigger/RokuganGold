class_name ActionPointSystem
## Action Point budget per GDD s14.1. Every character gets 2 AP per IC day
## (Morning and Afternoon slots). 8 AP per real day. No carryover. Flat
## across all characters — skill makes actions better, not more numerous.

const AP_PER_IC_DAY: int = 2
const IC_DAYS_PER_REAL_DAY: int = 4
const AP_PER_REAL_DAY: int = AP_PER_IC_DAY * IC_DAYS_PER_REAL_DAY  # 8

enum TimeSlot {
	MORNING,
	AFTERNOON,
}


static func reset_daily_ap(character: L5RCharacterData) -> void:
	character.action_points_current = AP_PER_IC_DAY
	character.action_points_max = AP_PER_IC_DAY


static func can_spend(character: L5RCharacterData, cost: int) -> bool:
	return character.action_points_current >= cost


static func spend_ap(character: L5RCharacterData, cost: int) -> Dictionary:
	if cost <= 0:
		return {"success": false, "reason": "invalid_cost"}
	if not can_spend(character, cost):
		return {
			"success": false,
			"reason": "insufficient_ap",
			"available": character.action_points_current,
			"required": cost,
		}

	character.action_points_current -= cost
	return {
		"success": true,
		"remaining": character.action_points_current,
		"spent": cost,
	}


static func get_remaining_ap(character: L5RCharacterData) -> int:
	return character.action_points_current
