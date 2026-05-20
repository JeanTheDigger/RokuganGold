class_name FavorSystem
## Favor System per GDD s12.10.
## Tracks political obligations between characters — offering, invoking,
## honoring, breaking, expiring, and disputing favors.


# -- Constants ----------------------------------------------------------------

const DISPOSITION_ON_OFFER: Dictionary = {
	FavorData.FavorTier.MINOR: 6,
	FavorData.FavorTier.MODERATE: 10,
	FavorData.FavorTier.MAJOR: 15,
}

const DISPOSITION_RAISE_BONUS: Dictionary = {
	FavorData.FavorTier.MINOR: 2,
	FavorData.FavorTier.MODERATE: 3,
	FavorData.FavorTier.MAJOR: 4,
}

const DISPOSITION_CRITICAL_FAILURE: int = -5

const BREAK_DISPOSITION: Dictionary = {
	FavorData.FavorTier.MINOR: -20,
	FavorData.FavorTier.MODERATE: -35,
	FavorData.FavorTier.MAJOR: -50,
}

const BREAK_DISPOSITION_FLOOR: Dictionary = {
	FavorData.FavorTier.MINOR: -15,
	FavorData.FavorTier.MODERATE: -30,
	FavorData.FavorTier.MAJOR: -50,
}

const BREAK_HONOR_LOSS: Dictionary = {
	FavorData.FavorTier.MINOR: -0.5,
	FavorData.FavorTier.MODERATE: -1.0,
	FavorData.FavorTier.MAJOR: -2.0,
}

const BREAK_WITNESS_DISPOSITION: Dictionary = {
	FavorData.FavorTier.MINOR: 0,
	FavorData.FavorTier.MODERATE: -5,
	FavorData.FavorTier.MAJOR: -10,
}

const BREAK_GLORY_LOSS: Dictionary = {
	FavorData.FavorTier.MINOR: 0.0,
	FavorData.FavorTier.MODERATE: 0.0,
	FavorData.FavorTier.MAJOR: -0.5,
}

const BREAK_TOPIC_TIER: Dictionary = {
	FavorData.FavorTier.MINOR: 4,
	FavorData.FavorTier.MODERATE: 4,
	FavorData.FavorTier.MAJOR: 2,
}

const HONOR_ON_FULFILL: float = 0.1

const EXPIRATION_DAYS: Dictionary = {
	FavorData.FavorTier.MINOR: 360,
	FavorData.FavorTier.MODERATE: 1080,
	FavorData.FavorTier.MAJOR: -1,
}

const RESPONSE_WINDOW_LETTER: int = 90
const RESPONSE_WINDOW_COURT: int = 1
const RESPONSE_WINDOW_VISIT: int = 90


# -- Offering -----------------------------------------------------------------

static func offer_favor(
	favor_type: FavorData.FavorType,
	tier: FavorData.FavorTier,
	creditor_id: int,
	debtor_id: int,
	created_ic_day: int,
	terms: String = "",
	source_action: String = "OFFER_FAVOR",
	next_favor_id: int = 0,
) -> FavorData:
	var favor := FavorData.new()
	favor.favor_id = next_favor_id
	favor.favor_type = favor_type
	favor.tier = tier
	favor.creditor_id = creditor_id
	favor.debtor_id = debtor_id
	favor.created_ic_day = created_ic_day
	favor.terms = terms
	favor.source_action = source_action
	return favor


static func get_offer_disposition(tier: FavorData.FavorTier, raises: int, critical_failure: bool) -> int:
	if critical_failure:
		return DISPOSITION_CRITICAL_FAILURE
	var base: int = DISPOSITION_ON_OFFER.get(tier, 6)
	var raise_bonus: int = DISPOSITION_RAISE_BONUS.get(tier, 2)
	return base + (raise_bonus * raises)


# -- Invoking -----------------------------------------------------------------

static func invoke_favor(
	favor: FavorData,
	method: FavorData.InvocationMethod,
	current_ic_day: int,
) -> Dictionary:
	favor.invoked = true
	favor.invoked_ic_day = current_ic_day
	favor.invocation_method = method

	var window: int = _get_response_window(method)
	if window > 0:
		favor.response_deadline_ic_day = current_ic_day + window
	else:
		favor.response_deadline_ic_day = current_ic_day + 1

	return {
		"favor_id": favor.favor_id,
		"method": method,
		"deadline_ic_day": favor.response_deadline_ic_day,
	}


static func _get_response_window(method: FavorData.InvocationMethod) -> int:
	match method:
		FavorData.InvocationMethod.LETTER:
			return RESPONSE_WINDOW_LETTER
		FavorData.InvocationMethod.COURT:
			return RESPONSE_WINDOW_COURT
		FavorData.InvocationMethod.PERSONAL_VISIT:
			return RESPONSE_WINDOW_VISIT
	return RESPONSE_WINDOW_LETTER


# -- Honoring -----------------------------------------------------------------

static func honor_favor(favor: FavorData) -> Dictionary:
	return {
		"favor_id": favor.favor_id,
		"debtor_id": favor.debtor_id,
		"honor_change": HONOR_ON_FULFILL,
		"resolved": true,
	}


# -- Breaking -----------------------------------------------------------------

static func break_favor(favor: FavorData, witnesses: Array = []) -> Dictionary:
	var tier: FavorData.FavorTier = favor.tier
	var result: Dictionary = {
		"favor_id": favor.favor_id,
		"creditor_id": favor.creditor_id,
		"debtor_id": favor.debtor_id,
		"disposition_change": BREAK_DISPOSITION.get(tier, -20),
		"disposition_floor": BREAK_DISPOSITION_FLOOR.get(tier, -15),
		"honor_loss": BREAK_HONOR_LOSS.get(tier, -0.5),
		"glory_loss": BREAK_GLORY_LOSS.get(tier, 0.0),
		"witness_disposition_loss": BREAK_WITNESS_DISPOSITION.get(tier, 0),
		"witnesses": witnesses,
		"topic_tier": BREAK_TOPIC_TIER.get(tier, 4),
		"topic_type": "POLITICAL",
		"topic_category": "BETRAYAL",
		"resolved": true,
	}
	return result


# -- Disputes (General Favors) ------------------------------------------------

static func can_dispute(favor: FavorData) -> bool:
	return favor.favor_type == FavorData.FavorType.GENERAL


static func resolve_dispute(creditor_total: int, debtor_total: int) -> Dictionary:
	if creditor_total >= debtor_total:
		return {"creditor_wins": true, "renegotiated": false}
	else:
		return {"creditor_wins": false, "renegotiated": true}


# -- Expiration ---------------------------------------------------------------

static func check_expiration(favor: FavorData, current_ic_day: int) -> bool:
	if favor.invoked:
		return false
	var max_days: int = EXPIRATION_DAYS.get(favor.tier, -1)
	if max_days < 0:
		return false
	return (current_ic_day - favor.created_ic_day) >= max_days


static func process_expirations(favors: Array, current_ic_day: int) -> Array:
	var expired_ids: Array[int] = []
	for favor: FavorData in favors:
		if favor is FavorData and check_expiration(favor, current_ic_day):
			expired_ids.append(favor.favor_id)
	return expired_ids


# -- Deadline enforcement -----------------------------------------------------

static func check_deadline_breach(favor: FavorData, current_ic_day: int) -> bool:
	if not favor.invoked:
		return false
	if favor.response_deadline_ic_day < 0:
		return false
	return current_ic_day > favor.response_deadline_ic_day


static func process_deadline_breaches(favors: Array, current_ic_day: int) -> Array:
	var breaches: Array[Dictionary] = []
	for favor: FavorData in favors:
		if favor is FavorData and check_deadline_breach(favor, current_ic_day):
			breaches.append(break_favor(favor))
	return breaches


# -- Death handling -----------------------------------------------------------

static func process_creditor_death(favors: Array, dead_creditor_id: int, heir_id: int) -> Dictionary:
	var inherited: Array[int] = []
	var dissolved: Array[int] = []

	for favor: FavorData in favors:
		if not (favor is FavorData):
			continue
		if favor.creditor_id != dead_creditor_id:
			continue
		if favor.tier == FavorData.FavorTier.MAJOR and heir_id >= 0:
			favor.creditor_id = heir_id
			favor.heir_id = heir_id
			inherited.append(favor.favor_id)
		else:
			dissolved.append(favor.favor_id)

	return {"inherited": inherited, "dissolved": dissolved}


static func process_debtor_death(favors: Array, dead_debtor_id: int) -> Array:
	var dissolved: Array[int] = []
	for favor: FavorData in favors:
		if favor is FavorData and favor.debtor_id == dead_debtor_id:
			dissolved.append(favor.favor_id)
	return dissolved


# -- Blackmail extraction -----------------------------------------------------

static func extract_blackmail_favor(
	secret_tier: int,
	creditor_id: int,
	debtor_id: int,
	raises: int,
	created_ic_day: int,
	next_favor_id: int = 0,
) -> Array:
	var favor_tier: FavorData.FavorTier = _secret_tier_to_favor_tier(secret_tier)
	if favor_tier == FavorData.FavorTier.MINOR and secret_tier >= 4:
		return []

	var favors: Array[FavorData] = []
	for i in range(raises):
		var favor := offer_favor(
			FavorData.FavorType.GENERAL,
			favor_tier,
			creditor_id,
			debtor_id,
			created_ic_day,
			"",
			"BLACKMAIL",
			next_favor_id + i,
		)
		favor.is_blackmail_extracted = true
		favors.append(favor)
	return favors


static func _secret_tier_to_favor_tier(secret_tier: int) -> FavorData.FavorTier:
	match secret_tier:
		1:
			return FavorData.FavorTier.MAJOR
		2:
			return FavorData.FavorTier.MODERATE
		3:
			return FavorData.FavorTier.MINOR
	return FavorData.FavorTier.MINOR


# -- Supply sharing unlock ----------------------------------------------------

static func can_unlock_supply_sharing(favor_tier: FavorData.FavorTier) -> bool:
	return favor_tier == FavorData.FavorTier.MODERATE or favor_tier == FavorData.FavorTier.MAJOR


# -- Heir forgiveness --------------------------------------------------------

static func forgive_favor(favor: FavorData) -> Dictionary:
	return {
		"favor_id": favor.favor_id,
		"debtor_id": favor.debtor_id,
		"creditor_id": favor.creditor_id,
		"forgiven": true,
		"resolved": true,
	}


# -- Blackmail exposure risk --------------------------------------------------

static func is_blackmail_exposure_risk(favor: FavorData, invocation_is_public: bool) -> bool:
	return favor.is_blackmail_extracted and invocation_is_public


# -- Witness disposition on dispute win ---------------------------------------

static func get_dispute_witness_disposition(creditor_won: bool) -> int:
	if creditor_won:
		return 2
	return 0
