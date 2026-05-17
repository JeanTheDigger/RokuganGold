class_name HonorGlorySystem
## Honor, Glory, Status, and Infamy management per GDD s4.6.
## All values on 0.0–10.0 scale. 1 "point" = 0.1, 1 "rank" = 1.0.
## Changes apply immediately — no batching.


# -- Core Modification ---------------------------------------------------------

static func apply_honor_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.honor
	character.honor = clampf(character.honor + delta, 0.0, 10.0)
	return character.honor - old


static func apply_glory_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.glory
	character.glory = clampf(character.glory + delta, 0.0, 10.0)
	return character.glory - old


static func apply_status_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.status
	character.status = clampf(character.status + delta, 0.0, 10.0)
	return character.status - old


static func apply_infamy_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.infamy
	character.infamy = clampf(character.infamy + delta, 0.0, 10.0)
	return character.infamy - old


# -- Rank Queries --------------------------------------------------------------

static func get_honor_rank(character: L5RCharacterData) -> int:
	return int(character.honor)


static func get_glory_rank(character: L5RCharacterData) -> int:
	return int(character.glory)


static func get_status_rank(character: L5RCharacterData) -> int:
	return int(character.status)


static func get_infamy_rank(character: L5RCharacterData) -> int:
	return int(character.infamy)


# -- Court Credibility (s4.6 Honor as Court Credibility) -----------------------
# Returns the number of Free Raises (positive) or additional Raises required
# (negative) for Public Declarations and Offer a Favor actions.

static func get_court_honor_modifier(character: L5RCharacterData) -> int:
	var rank: int = get_honor_rank(character)
	if rank >= 7:
		return 2
	if rank >= 5:
		return 1
	if rank >= 3:
		return 0
	if rank >= 2:
		return -1
	return -2


# -- Recognition ---------------------------------------------------------------
# Combined Glory + Infamy ranks determine how widely known someone is.

static func get_recognition_rank(character: L5RCharacterData) -> int:
	return get_glory_rank(character) + get_infamy_rank(character)


# -- Court Event Table Constants -----------------------------------------------

const GLORY_PUBLIC_PERFORMANCE_SUCCESS: float = 0.3
const GLORY_PUBLIC_PERFORMANCE_MASTERFUL: float = 0.5
const GLORY_PUBLIC_DEBATE_DECISIVE_WIN: float = 0.3
const GLORY_PUBLICLY_PRAISE_SELF: float = 0.1
const GLORY_PUBLICLY_PRAISE_TARGET: float = 0.2
const GLORY_PUBLIC_DECLARATION_HONORED: float = 0.2
const GLORY_DUEL_WON_HONORABLY: float = 0.5
const GLORY_PERFORM_PERSONALLY_MASTERFUL: float = 0.2

const GLORY_PERFORMANCE_CRITICAL_FAIL: float = -0.3
const GLORY_DEBATE_DECISIVE_LOSS: float = -0.2
const GLORY_INSULT_BACKFIRED: float = -0.2
const GLORY_EXPOSE_SECRET_FAIL: float = -0.3

const HONOR_PUBLIC_DECLARATION_KEPT: float = 0.2
const HONOR_FAVOR_HONORED: float = 0.1
const HONOR_VIRTUE_REFUSAL: float = 0.1

const HONOR_RENEGE_DECLARATION: float = -1.0
const HONOR_FABRICATED_SECRET_EXPOSED: float = -0.5
const HONOR_PROXY_COMMIT_ACCEPTED_LORD: float = -0.3
const HONOR_PROXY_COMMIT_ACCEPTED_PROXY: float = -0.5
const HONOR_PROXY_COMMIT_REFUSED_LORD: float = -0.2
const HONOR_PROXY_COMMIT_REFUSED_PROXY: float = -1.0
const HONOR_GOSSIP_VIRTUE_BREACH: float = -0.5

# Public Atonement
const ATONEMENT_GLORY_LOSS: float = -0.3
const ATONEMENT_CRITICAL_FAIL_GLORY_LOSS: float = -0.5
const ATONEMENT_CRITICAL_FAIL_HONOR_LOSS: float = -0.3
const ATONEMENT_HONOR_PER_RAISE: float = 0.1

const ATONEMENT_HONOR_BY_TIER: Dictionary = {
	4: 0.3,
	3: 0.5,
	2: 0.8,
	1: 1.0,
}

const ATONEMENT_TN_BY_TIER: Dictionary = {
	4: 15,
	3: 20,
	2: 25,
	1: 30,
}


static func can_atone(character: L5RCharacterData, offense_key: String) -> bool:
	return offense_key not in character.atoned_offenses


static func record_atonement(character: L5RCharacterData, offense_key: String) -> void:
	if offense_key not in character.atoned_offenses:
		character.atoned_offenses.append(offense_key)
