class_name MarriageSystem
## Marriage System per GDD s22.7.
## Political institution: arranged by lords, creates cross-clan bonds,
## generates children, produces disposition boosts and favor obligations.


# -- Constants ----------------------------------------------------------------

const CLAN_BASELINE_BOOST: int = 8
const FAMILY_BASELINE_BOOST: int = 5
const CLAN_BOOST_CAP: int = 20
const FAMILY_BOOST_CAP: int = 15

const CLAN_DECAY_RATE_PER_SEASON: int = 1
const CLAN_DECAY_SEASONS: int = 10
const FAMILY_DECAY_RATE_PER_SEASON: int = 1
const FAMILY_DECAY_SEASONS: int = 8

const BIRTH_FAMILY_DISPOSITION_FLOOR: int = 15
const BIRTH_CLAN_DISPOSITION_FLOOR: int = 8

const GEMPUKU_AGE: int = 18
const GEMPUKU_SEASONS: int = 72

enum MarriageType {
	WITHIN_FAMILY,
	BETWEEN_FAMILIES,
	CROSS_CLAN,
}

const PREGNANCY_CHANCE: Dictionary = {
	"hostile": 0.0,
	"stranger": 0.05,
	"friend": 0.15,
	"close": 0.25,
}


# -- Marriage Creation --------------------------------------------------------

static func create_marriage(
	character_a_id: int,
	character_b_id: int,
	marriage_type: MarriageType,
	moving_character_id: int,
	created_ic_day: int,
) -> Dictionary:
	return {
		"character_a_id": character_a_id,
		"character_b_id": character_b_id,
		"marriage_type": marriage_type,
		"moving_character_id": moving_character_id,
		"created_ic_day": created_ic_day,
		"children_ids": [],
		"active": true,
	}


# -- Disposition Effects on Marriage ------------------------------------------

static func get_marriage_boosts(marriage_type: MarriageType) -> Dictionary:
	match marriage_type:
		MarriageType.CROSS_CLAN:
			return {
				"clan_boost": CLAN_BASELINE_BOOST,
				"family_boost": FAMILY_BASELINE_BOOST,
				"favor_owed": true,
			}
		MarriageType.BETWEEN_FAMILIES:
			return {
				"clan_boost": 0,
				"family_boost": FAMILY_BASELINE_BOOST,
				"favor_owed": false,
			}
		MarriageType.WITHIN_FAMILY:
			return {
				"clan_boost": 0,
				"family_boost": 0,
				"favor_owed": false,
			}
	return {"clan_boost": 0, "family_boost": 0, "favor_owed": false}


static func get_birth_family_floors() -> Dictionary:
	return {
		"birth_family_floor": BIRTH_FAMILY_DISPOSITION_FLOOR,
		"birth_clan_floor": BIRTH_CLAN_DISPOSITION_FLOOR,
	}


# -- Boost Decay --------------------------------------------------------------

static func decay_clan_boost(current_boost: int, seasons_elapsed: int) -> int:
	var decay: int = int(seasons_elapsed / CLAN_DECAY_SEASONS)
	return max(0, current_boost - decay)


static func decay_family_boost(current_boost: int, seasons_elapsed: int) -> int:
	var decay: int = int(seasons_elapsed / FAMILY_DECAY_SEASONS)
	return max(0, current_boost - decay)


# -- Pregnancy ----------------------------------------------------------------

static func get_pregnancy_chance(spouse_disposition: int) -> float:
	if spouse_disposition <= -31:
		return PREGNANCY_CHANCE["hostile"]
	elif spouse_disposition <= 30:
		return PREGNANCY_CHANCE["stranger"]
	elif spouse_disposition <= 60:
		return PREGNANCY_CHANCE["friend"]
	return PREGNANCY_CHANCE["close"]


static func check_pregnancy(spouse_disposition: int, roll: float) -> bool:
	return roll < get_pregnancy_chance(spouse_disposition)


# -- Gempuku ------------------------------------------------------------------

static func is_gempuku_eligible(birth_season: int, current_season: int) -> bool:
	return (current_season - birth_season) >= GEMPUKU_SEASONS


# -- Proposal Evaluation (NPC lord decision) ----------------------------------

static func evaluate_proposal(
	proposing_clan_disposition: int,
	character_value: int,
	favor_tier: int,
	has_military_objective: bool,
) -> int:
	var score: int = proposing_clan_disposition
	score += character_value
	score += favor_tier * 0
	if has_military_objective:
		score += 0
	return score


# -- Benten Festival Bonus ----------------------------------------------------

const BENTEN_FESTIVAL_DAY: int = 9
const BENTEN_FESTIVAL_MONTH: int = 11

const BENTEN_FESTIVAL_BONUS: int = 0

static func is_benten_festival(ic_day: int) -> bool:
	var day_of_year: int = ic_day % 360
	var month: int = int(day_of_year / 30) + 1
	var day_of_month: int = (day_of_year % 30) + 1
	return month == BENTEN_FESTIVAL_MONTH and day_of_month == BENTEN_FESTIVAL_DAY
