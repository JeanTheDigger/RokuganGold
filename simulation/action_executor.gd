class_name ActionExecutor
## Routes chosen ActionIDs to owning systems per GDD s55.4.7.
## Receives a ScoredAction + character + context, performs the skill roll
## (if applicable), applies effects, and returns a result dictionary.
## This is the bridge between NPC decision and world-state mutation.


# -- Action Categories --------------------------------------------------------

const SOCIAL_ACTIONS: Array[String] = [
	"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
	"PROBE", "READ_CHARACTER", "LISTEN_REFLECT", "IMPRESS",
	"PUBLIC_DEBATE", "PUBLIC_INSULT", "PUBLIC_DECLARATION",
	"PUBLIC_PERFORMANCE", "DELIVER_GIFT", "OFFER_FAVOR",
	"PERFORM_FOR", "DISCLOSE", "ASK_FOR_INTRODUCTION",
]

const COVERT_ACTIONS: Array[String] = [
	"BRIBE_FOR_INFO", "EAVESDROP", "INTERCEPT_LETTER",
	"SEARCH_QUARTERS", "FABRICATE_SECRET",
]

const MILITARY_ORDERS: Array[String] = [
	"ORDER_LEVY", "ORDER_DEPLOY", "ORDER_FORTIFY", "ORDER_RETREAT",
	"ORDER_BATTLE", "ORDER_PATROL", "ASSIGN_GARRISON",
	"CONDUCT_RAID", "RAID_HARVEST", "CONDUCT_SORTIE",
	"CONDUCT_STORM_ASSAULT", "MAINTAIN_SIEGE", "DRILL_TROOPS",
	"BLOCKADE_TRADE_ROUTE",
]

const ADMINISTRATIVE_ACTIONS: Array[String] = [
	"SET_TAX_RATE", "SET_STIPEND_RATE", "PURCHASE_MARKET",
	"SHARE_SUPPLIES", "ASSESS_PROVINCE_STATUS", "EVALUATE_WAR_READINESS",
	"ASSIGN_VASSAL_OBJECTIVE", "CALL_COURT", "SEND_INVITATION",
	"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID", "INVESTIGATE_PROVINCE",
	"INVESTIGATE_RUMOR", "NEGOTIATE_SURRENDER", "CONDUCT_COMMERCE",
	"DISPATCH_COURTIER",
]

const SELF_ACTIONS: Array[String] = [
	"TRAIN", "MEDITATE", "REST", "DO_NOTHING", "CRAFT",
	"WRITE_LETTER", "PERFORM_RITUAL", "PERFORM_WORSHIP",
	"PUBLIC_ATONEMENT", "MENTOR", "BEGIN_TRAVEL",
	"OBSERVE_COURT_ATTENDEES",
]

const NO_ROLL_ACTIONS: Array[String] = [
	"DO_NOTHING", "REST", "BEGIN_TRAVEL", "CHANGE_DESTINATION",
	"REQUEST_ART", "OFFER_ART_COMMISSION", "DISPLAY_BONSAI",
]

# -- TN Table -----------------------------------------------------------------

const BASE_TN: Dictionary = {
	"trivial": 5,
	"easy": 10,
	"average": 15,
	"hard": 20,
	"very_hard": 25,
	"heroic": 30,
}

const SOCIAL_BASE_TN: int = 15
const COVERT_BASE_TN: int = 20
const MILITARY_BASE_TN: int = 15
const ADMIN_BASE_TN: int = 10


# -- Main Entry Point ---------------------------------------------------------

static func execute(
	action: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
) -> Dictionary:
	var action_id: String = action.action_id

	if action_id in NO_ROLL_ACTIONS:
		return _execute_no_roll(action, character, ctx)

	var skill_info: Dictionary = action_skill_map.get(action_id, {})
	var primary_skill: String = skill_info.get("primary", "")

	if primary_skill.is_empty() or primary_skill.begins_with("_"):
		return _execute_no_roll(action, character, ctx)

	var tn: int = _get_tn_for_action(action_id, action, ctx)
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, primary_skill, tn
	)

	var result: Dictionary = {
		"success": roll_result.get("success", false),
		"action_id": action_id,
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"skill_used": primary_skill,
		"roll_total": roll_result.get("total", 0),
		"tn": tn,
		"margin": roll_result.get("total", 0) - tn,
	}

	_apply_effects(result, action, character, ctx)
	return result


# -- No-Roll Execution --------------------------------------------------------

static func _execute_no_roll(
	action: NPCDataStructures.ScoredAction,
	_character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	return {
		"success": true,
		"action_id": action.action_id,
		"character_id": ctx.character_id,
		"target_npc_id": action.target_npc_id,
		"target_province_id": action.target_province_id,
		"ic_day": ctx.ic_day,
		"skill_used": "",
		"roll_total": 0,
		"tn": 0,
		"margin": 0,
		"effects": _get_no_roll_effects(action.action_id),
	}


# -- TN Calculation -----------------------------------------------------------

static func _get_tn_for_action(
	action_id: String,
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	if action_id in SOCIAL_ACTIONS:
		return _get_social_tn(action, ctx)
	if action_id in COVERT_ACTIONS:
		return COVERT_BASE_TN
	if action_id in MILITARY_ORDERS:
		return MILITARY_BASE_TN
	if action_id in ADMINISTRATIVE_ACTIONS:
		return ADMIN_BASE_TN
	return SOCIAL_BASE_TN


static func _get_social_tn(
	action: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var tn: int = SOCIAL_BASE_TN
	var target_disp: int = ctx.dispositions.get(action.target_npc_id, 0)

	if target_disp <= -60:
		tn += 15
	elif target_disp <= -30:
		tn += 10
	elif target_disp <= -10:
		tn += 5
	elif target_disp >= 61:
		tn -= 10
	elif target_disp >= 31:
		tn -= 5

	return maxi(tn, 5)


# -- Effect Application -------------------------------------------------------

static func _apply_effects(
	result: Dictionary,
	action: NPCDataStructures.ScoredAction,
	_character: L5RCharacterData,
	_ctx: NPCDataStructures.ContextSnapshot,
) -> void:
	var effects: Dictionary = {}
	var action_id: String = action.action_id

	if result["success"]:
		if action_id in SOCIAL_ACTIONS:
			effects = _compute_social_effects(action_id, result["margin"])
		elif action_id in COVERT_ACTIONS:
			effects = _compute_covert_effects(action_id, result["margin"])
		elif action_id in MILITARY_ORDERS:
			effects = _compute_military_effects(action_id)
		elif action_id in ADMINISTRATIVE_ACTIONS:
			effects = _compute_admin_effects(action_id)
		else:
			effects = _compute_self_effects(action_id)
	else:
		effects = _compute_failure_effects(action_id)

	result["effects"] = effects


static func _compute_social_effects(action_id: String, margin: int) -> Dictionary:
	var disp_change: int = 0
	var glory_change: float = 0.0
	var info_gained: bool = false

	match action_id:
		"CHARM", "DELIVER_GIFT", "OFFER_FAVOR", "LISTEN_REFLECT":
			disp_change = 3 + clampi(margin / 5, 0, 5)
		"PERSUADE", "NEGOTIATE":
			disp_change = 2 + clampi(margin / 5, 0, 3)
		"INTIMIDATE":
			disp_change = -(3 + clampi(margin / 5, 0, 5))
		"GOSSIP":
			info_gained = true
			disp_change = 1
		"PROBE", "READ_CHARACTER":
			info_gained = true
		"PUBLIC_DEBATE", "PUBLIC_DECLARATION", "PUBLIC_PERFORMANCE":
			glory_change = 0.1
			disp_change = 1
		"PUBLIC_INSULT":
			disp_change = -5
			glory_change = 0.05
		"IMPRESS":
			disp_change = 2
			glory_change = 0.05
		"ASK_FOR_INTRODUCTION":
			info_gained = true
		"DISCLOSE":
			disp_change = 2
			info_gained = true
		"PERFORM_FOR":
			disp_change = 2
			glory_change = 0.05

	return {
		"disposition_change": disp_change,
		"glory_change": glory_change,
		"info_gained": info_gained,
	}


static func _compute_covert_effects(action_id: String, margin: int) -> Dictionary:
	var info_gained: bool = true
	var detection_risk: bool = margin < 5

	match action_id:
		"BRIBE_FOR_INFO":
			detection_risk = false
		"FABRICATE_SECRET":
			info_gained = false

	return {
		"info_gained": info_gained,
		"detection_risk": detection_risk,
		"quality": clampi(margin / 5, 1, 5),
	}


static func _compute_military_effects(action_id: String) -> Dictionary:
	match action_id:
		"ORDER_LEVY":
			return {"effect": "levy_raised"}
		"ORDER_DEPLOY":
			return {"effect": "unit_deployed"}
		"ORDER_FORTIFY":
			return {"effect": "fortification_improved"}
		"ORDER_RETREAT":
			return {"effect": "retreat_ordered"}
		"ORDER_BATTLE":
			return {"effect": "battle_initiated"}
		"ORDER_PATROL":
			return {"effect": "patrol_dispatched"}
		"ASSIGN_GARRISON":
			return {"effect": "garrison_assigned"}
		"DRILL_TROOPS":
			return {"effect": "training_bonus"}
		"CONDUCT_RAID", "RAID_HARVEST":
			return {"effect": "raid_executed"}
		"CONDUCT_SORTIE":
			return {"effect": "sortie_executed"}
		"CONDUCT_STORM_ASSAULT":
			return {"effect": "assault_executed"}
		"MAINTAIN_SIEGE":
			return {"effect": "siege_maintained"}
		"BLOCKADE_TRADE_ROUTE":
			return {"effect": "route_blocked"}
	return {"effect": "military_order_issued"}


static func _compute_admin_effects(action_id: String) -> Dictionary:
	match action_id:
		"SET_TAX_RATE", "SET_STIPEND_RATE":
			return {"effect": "rate_adjusted"}
		"PURCHASE_MARKET":
			return {"effect": "transaction_completed"}
		"SHARE_SUPPLIES":
			return {"effect": "supplies_shared", "honor_change": 0.3}
		"ASSESS_PROVINCE_STATUS", "INVESTIGATE_PROVINCE", "INVESTIGATE_RUMOR":
			return {"effect": "intelligence_gathered", "info_gained": true}
		"EVALUATE_WAR_READINESS":
			return {"effect": "readiness_assessed", "info_gained": true}
		"CONDUCT_COMMERCE":
			return {"effect": "commerce_conducted"}
		"NEGOTIATE_SURRENDER":
			return {"effect": "surrender_negotiated"}
		"DEMAND_TRIBUTE":
			return {"effect": "tribute_demanded"}
		"REQUEST_ALLIED_AID":
			return {"effect": "aid_requested"}
	return {"effect": "administrative_action"}


static func _compute_self_effects(action_id: String) -> Dictionary:
	match action_id:
		"TRAIN":
			return {"effect": "skill_practiced"}
		"MEDITATE":
			return {"effect": "void_point_recovered"}
		"CRAFT":
			return {"effect": "item_progress"}
		"WRITE_LETTER":
			return {"effect": "letter_sent"}
		"PERFORM_RITUAL", "PERFORM_WORSHIP":
			return {"effect": "ritual_completed", "honor_change": 0.1}
		"PUBLIC_ATONEMENT":
			return {"effect": "atonement_performed", "honor_change": 0.5}
		"MENTOR":
			return {"effect": "student_trained"}
		"OBSERVE_COURT_ATTENDEES":
			return {"effect": "court_observed", "info_gained": true}
	return {"effect": "self_action_completed"}


static func _compute_failure_effects(action_id: String) -> Dictionary:
	var effects: Dictionary = {"failed": true}
	if action_id in SOCIAL_ACTIONS:
		effects["disposition_change"] = -1
	if action_id == "PUBLIC_INSULT" or action_id == "PUBLIC_DEBATE":
		effects["glory_change"] = -0.05
	if action_id in COVERT_ACTIONS:
		effects["detection_risk"] = true
	return effects


static func _get_no_roll_effects(action_id: String) -> Dictionary:
	match action_id:
		"DO_NOTHING":
			return {"effect": "nothing"}
		"REST":
			return {"effect": "rested"}
		"BEGIN_TRAVEL", "CHANGE_DESTINATION":
			return {"effect": "travel_started"}
	return {"effect": "completed"}
