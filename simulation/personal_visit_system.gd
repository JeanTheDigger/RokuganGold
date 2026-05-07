class_name PersonalVisitSystem
## Personal Visits System per GDD s17.
## Handles visit initiation, host response, intimate setting bonuses,
## and available action filtering during visits.


# -- Enums & Constants --------------------------------------------------------

enum VisitType {
	INVITATION_SENT,
	LETTER_ANNOUNCING_ARRIVAL,
	UNINVITED,
}

enum HostResponse {
	ACCEPT,
	REFUSE,
}

const INTIMATE_SETTING_BONUS: int = 3

const DECLINE_INVITATION_DISPOSITION: int = -3
const REFUSE_AFTER_INVITATION_DISPOSITION: int = -10
const REFUSE_AFTER_INVITATION_HONOR: float = -0.3
const REFUSE_LETTER_ARRIVAL_DISPOSITION: int = -2
const REFUSE_UNINVITED_DISPOSITION: int = 0
const RECEIVE_UNINVITED_DISPOSITION: int = 5

const CATEGORY_1_ACTIONS: Array[String] = [
	"CHARM",
	"FLATTERY",
	"SINCERE_COMPLIMENT",
	"SHARED_INTEREST",
	"DELIVER_GIFT",
	"OFFER_FAVOR",
	"PERFORM_FOR",
]

const CATEGORY_3_ACTIONS: Array[String] = [
	"GOSSIP",
	"DISCLOSE",
	"REVEAL_SECRET_PRIVATELY",
]

const CATEGORY_5_ACTIONS: Array[String] = [
	"READ_CHARACTER",
	"PROBE",
]

const VISIT_ACTIONS: Array[String] = [
	"CHARM",
	"FLATTERY",
	"SINCERE_COMPLIMENT",
	"SHARED_INTEREST",
	"DELIVER_GIFT",
	"OFFER_FAVOR",
	"PERFORM_FOR",
	"GOSSIP",
	"DISCLOSE",
	"REVEAL_SECRET_PRIVATELY",
	"READ_CHARACTER",
	"PROBE",
]


# -- Visit Initiation ---------------------------------------------------------

static func initiate_visit(
	visitor_id: int,
	host_id: int,
	visit_type: VisitType,
	current_ic_day: int,
) -> Dictionary:
	return {
		"visitor_id": visitor_id,
		"host_id": host_id,
		"visit_type": visit_type,
		"initiated_ic_day": current_ic_day,
		"active": false,
		"started_ic_day": -1,
	}


# -- Host Response ------------------------------------------------------------

static func resolve_host_response(
	visit: Dictionary,
	response: HostResponse,
) -> Dictionary:
	var visit_type: VisitType = visit["visit_type"] as VisitType
	var effects: Dictionary = {
		"accepted": response == HostResponse.ACCEPT,
		"visitor_id": visit["visitor_id"],
		"host_id": visit["host_id"],
		"disposition_change_to_host": 0,
		"disposition_change_to_visitor": 0,
		"honor_change_host": 0.0,
	}

	if response == HostResponse.REFUSE:
		match visit_type:
			VisitType.INVITATION_SENT:
				effects["disposition_change_to_host"] = REFUSE_AFTER_INVITATION_DISPOSITION
				effects["honor_change_host"] = REFUSE_AFTER_INVITATION_HONOR
			VisitType.LETTER_ANNOUNCING_ARRIVAL:
				effects["disposition_change_to_host"] = REFUSE_LETTER_ARRIVAL_DISPOSITION
			VisitType.UNINVITED:
				effects["disposition_change_to_host"] = REFUSE_UNINVITED_DISPOSITION
	elif response == HostResponse.ACCEPT:
		if visit_type == VisitType.UNINVITED:
			effects["disposition_change_to_visitor"] = RECEIVE_UNINVITED_DISPOSITION

	return effects


static func decline_invitation_effects() -> Dictionary:
	return {
		"disposition_change": DECLINE_INVITATION_DISPOSITION,
	}


# -- Action Filtering ---------------------------------------------------------

static func get_available_actions() -> Array[String]:
	var actions: Array[String] = []
	actions.append_array(VISIT_ACTIONS)
	return actions


static func is_action_available_during_visit(action_id: String) -> bool:
	return action_id in VISIT_ACTIONS


static func is_category_1_action(action_id: String) -> bool:
	return action_id in CATEGORY_1_ACTIONS


# -- Intimate Setting Bonus ---------------------------------------------------

static func apply_intimate_bonus(action_id: String, base_disposition: int) -> int:
	if is_category_1_action(action_id):
		return base_disposition + INTIMATE_SETTING_BONUS
	return base_disposition


static func get_intimate_bonus(action_id: String) -> int:
	if is_category_1_action(action_id):
		return INTIMATE_SETTING_BONUS
	return 0
