class_name CourtPrioritySystem
## Court Priority System per GDD s15.8.
## NPC court selection logic, early departure costs, objective negligence,
## and Otomo institutional behavior leans.


# -- Court Selection ----------------------------------------------------------

static func select_court(
	courts: Array,
	primary_objective: Dictionary,
	standing_objective: String,
	character_status: float,
) -> Dictionary:
	if courts.is_empty():
		return {}
	if courts.size() == 1:
		return courts[0]

	var best: Dictionary = courts[0]
	var best_score: float = _score_court(courts[0], primary_objective, standing_objective, character_status)

	for i in range(1, courts.size()):
		var score: float = _score_court(courts[i], primary_objective, standing_objective, character_status)
		if score > best_score:
			best_score = score
			best = courts[i]
	return best


static func _score_court(
	court: Dictionary,
	primary_objective: Dictionary,
	standing_objective: String,
	_character_status: float,
) -> float:
	var score: float = 0.0

	if court.get("assigned_by_lord", false):
		score += 1000.0

	var obj_target: String = primary_objective.get("target_court_id", "")
	if obj_target != "" and court.get("court_id", "") == obj_target:
		score += 500.0

	score += court.get("personal_relevance", 0.0) * 10.0

	if _court_serves_standing(court, standing_objective):
		score += 50.0

	score += court.get("court_status", 0.0)

	return score


static func _court_serves_standing(court: Dictionary, standing_objective: String) -> bool:
	if standing_objective == "":
		return false
	var topics: Array = court.get("topics", [])
	for topic: Dictionary in topics:
		if topic is Dictionary and topic.get("related_objective", "") == standing_objective:
			return true
	return false


# -- Early Departure Costs ---------------------------------------------------

const HOST_LEAVING_HONOR_LOSS: float = -1.0
const HOST_LEAVING_GLORY_LOSS: float = -0.5
const GUEST_LEAVING_DISPOSITION_COST: int = -3

static func get_early_departure_cost(is_host: bool, is_proxy: bool) -> Dictionary:
	if is_host:
		return {
			"honor_loss": HOST_LEAVING_HONOR_LOSS,
			"glory_loss": HOST_LEAVING_GLORY_LOSS,
			"disposition_cost": 0,
			"mandate_violation": false,
		}
	elif is_proxy:
		return {
			"honor_loss": 0.0,
			"glory_loss": 0.0,
			"disposition_cost": GUEST_LEAVING_DISPOSITION_COST,
			"mandate_violation": true,
		}
	return {
		"honor_loss": 0.0,
		"glory_loss": 0.0,
		"disposition_cost": GUEST_LEAVING_DISPOSITION_COST,
		"mandate_violation": false,
	}


# -- Objective Negligence -----------------------------------------------------

const PASSIVE_NEGLIGENCE_HONOR: float = -0.1
const ACTIVE_NEGLIGENCE_HONOR: float = -0.5

static func get_negligence_cost(deliberate: bool) -> float:
	return ACTIVE_NEGLIGENCE_HONOR if deliberate else PASSIVE_NEGLIGENCE_HONOR


# -- Otomo Institutional Leans ------------------------------------------------

const OTOMO_GOSSIP_LEAN: int = 15
const OTOMO_DISCLOSE_LEAN: int = 10
const OTOMO_INTER_CLAN_DAMAGE_LEAN: int = 10

static func get_otomo_lean(action_id: String) -> int:
	match action_id:
		"GOSSIP":
			return OTOMO_GOSSIP_LEAN
		"DISCLOSE":
			return OTOMO_DISCLOSE_LEAN
	return 0


static func is_otomo_blocked_action(_action_id: String, builds_inter_clan_goodwill: bool) -> bool:
	return builds_inter_clan_goodwill


static func should_otomo_escalate(disposition_toward_clan: int) -> bool:
	return disposition_toward_clan <= -11
