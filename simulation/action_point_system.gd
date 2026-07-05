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
	if CharacterStats.is_dead(character):
		character.action_points_current = 0
		character.action_points_max = 0
		return
	# s54.10 Kitsune-tsuki possession: a controlled victim cannot act for the 24h window.
	if String(character.possession_affliction.get("kind", "")) == "kitsune_tsuki":
		character.action_points_current = 0
		character.action_points_max = 0
		return
	# s57.43.6 shipwreck drift: adrift in open ocean, the character cannot act.
	if character.drift_day >= 1:
		character.action_points_current = 0
		character.action_points_max = 0
		return
	if character.is_pc:
		# PCs never enter the NPC wave; AP accrues to banked_ap instead (s60.5).
		character.action_points_current = 0
		character.action_points_max = 0
		PcSystem.bank_daily_ap(character, AP_PER_IC_DAY)
		return
	character.action_points_current = AP_PER_IC_DAY
	character.action_points_max = AP_PER_IC_DAY
	character.spell_slots_used = {}
	character.spell_void_bonus_used = 0
	character.spell_slot_adjustment = {}


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
