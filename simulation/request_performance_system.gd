class_name RequestPerformanceSystem
## Lord-tier court commission system per GDD s57.33.
## REQUEST_PERFORMANCE ActionID: 1 Civilian Order, no roll. Creates a
## pending_performance_request on the court. Fulfillment by any qualified
## performer triggers patron Glory for the commissioning lord.


# -- Constants (s57.33.4 and s57.33.6) -----------------------------------------

const EXPIRY_IC_DAYS: int = 90

const PATRON_GLORY_PUBLIC_SUCCESS: float = 0.2
const PATRON_GLORY_PUBLIC_MASTERFUL: float = 0.3
const PATRON_GLORY_PUBLIC_CRITICAL_FAIL: float = -0.1
const PATRON_GLORY_PRIVATE_MULTIPLIER: float = 0.5

const DISP_STRONG_ALLY: int = 20
const DISP_FRIEND: int = 15
const DISP_ACQUAINTANCE: int = 10
const DISP_NEUTRAL: int = 5
const DISP_RIVAL: int = -10

const SKILL_RANK5_BONUS: int = 15
const TRAVEL_PENALTY_PER_PROVINCE: int = 3
const LORD_CHAMPION_BONUS: int = 20
const LORD_MINOR_BONUS: int = 5

const NEED_TYPE_FULFILL: String = "FULFILL_PERFORMANCE_REQUEST"


# -- Public API ----------------------------------------------------------------

static func create_request(
	request_id: int,
	requesting_lord_id: int,
	performance_type: String,
	target_performer_id: int,
	venue_mode: String,
	created_on_ic_day: int,
) -> Dictionary:
	return {
		"request_id": request_id,
		"requesting_lord_id": requesting_lord_id,
		"performance_type": performance_type,
		"target_performer_id": target_performer_id,
		"venue_mode": venue_mode,
		"created_on_ic_day": created_on_ic_day,
		"expires_ic_day": created_on_ic_day + EXPIRY_IC_DAYS,
	}


static func can_request(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	performance_type: String,
	pending_requests: Array,
) -> Dictionary:
	if not ctx.is_lord:
		return {"valid": false, "reason": "not_a_lord"}

	if character.civilian_orders_remaining <= 0:
		return {"valid": false, "reason": "no_civilian_orders"}

	var flag: Enums.ContextFlag = ctx.context_flag
	if flag != Enums.ContextFlag.AT_OWN_HOLDINGS and flag != Enums.ContextFlag.AT_COURT:
		return {"valid": false, "reason": "wrong_context"}

	for req: Variant in pending_requests:
		if req is Dictionary:
			var r: Dictionary = req as Dictionary
			if r.get("requesting_lord_id", -1) == character.character_id \
					and r.get("performance_type", "") == performance_type:
				return {"valid": false, "reason": "duplicate_performance_type"}

	return {"valid": true, "reason": ""}


static func score_acceptance(
	performer: L5RCharacterData,
	request: Dictionary,
	requesting_lord: L5RCharacterData,
	distance_provinces: int,
) -> int:
	var target_id: int = request.get("target_performer_id", -1)
	if target_id >= 0 and target_id != performer.character_id:
		return 0

	var lord_id: int = requesting_lord.character_id
	var disp: int = performer.disposition_values.get(lord_id, 0)
	var score: int = 0

	# Thresholds from s12.2 disposition tier boundaries.
	if disp >= 51:
		score += DISP_STRONG_ALLY
	elif disp >= 31:
		score += DISP_FRIEND
	elif disp >= 11:
		score += DISP_ACQUAINTANCE
	elif disp >= -10:
		score += DISP_NEUTRAL
	else:
		score += DISP_RIVAL

	score -= distance_provinces * TRAVEL_PENALTY_PER_PROVINCE

	var perf_type: String = request.get("performance_type", "")
	var skill_name: String = _skill_for_type(perf_type)
	var rank: int = SkillResolver.get_skill_rank(performer, skill_name)
	if rank >= 5:
		score += SKILL_RANK5_BONUS

	if requesting_lord.status >= 8.0:
		score += LORD_CHAMPION_BONUS
	else:
		score += LORD_MINOR_BONUS

	return score


static func compute_patron_glory(
	performance_outcome: int,
	venue_mode: String,
	fatigue_modifier: float,
) -> float:
	var base: float
	match performance_outcome:
		PerformativeArtsSystem.PerformanceOutcome.CRITICAL_FAILURE:
			base = PATRON_GLORY_PUBLIC_CRITICAL_FAIL
		PerformativeArtsSystem.PerformanceOutcome.FAILURE:
			base = 0.0
		PerformativeArtsSystem.PerformanceOutcome.SUCCESS:
			base = PATRON_GLORY_PUBLIC_SUCCESS
		PerformativeArtsSystem.PerformanceOutcome.MASTERFUL:
			base = PATRON_GLORY_PUBLIC_MASTERFUL
		_:
			base = 0.0

	if venue_mode == "private":
		base *= PATRON_GLORY_PRIVATE_MULTIPLIER

	return base * fatigue_modifier


static func can_fulfill(performer: L5RCharacterData, request: Dictionary) -> bool:
	var perf_type: String = request.get("performance_type", "")
	return SkillResolver.get_skill_rank(performer, _skill_for_type(perf_type)) >= 1


static func expire_requests(pending_requests: Array, current_ic_day: int) -> Array:
	var result: Array = []
	for req: Variant in pending_requests:
		if req is Dictionary:
			var r: Dictionary = req as Dictionary
			if r.get("expires_ic_day", 0) > current_ic_day:
				result.append(r)
	return result


# -- Private Helpers -----------------------------------------------------------

static func _skill_for_type(performance_type: String) -> String:
	match performance_type:
		"biwa":
			return "Perform: Biwa"
		"dance":
			return "Perform: Dance"
		"drums":
			return "Perform: Drums"
		"flute":
			return "Perform: Flute"
		"oratory":
			return "Perform: Oratory"
		"samisen":
			return "Perform: Samisen"
		"song":
			return "Perform: Song"
		"storytelling":
			return "Perform: Storytelling"
		"poetry":
			return "Artisan: Poetry"
		"ikebana":
			return "Artisan: Ikebana"
		"origami":
			return "Artisan: Origami"
		_:
			return "Perform: Song"
