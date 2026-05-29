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

const PROPOSAL_FAVOR_TIER_MULTIPLIER: int = 10  # MINOR=0, MODERATE=10, MAJOR=20 — locked s22.7a
const PROPOSAL_MILITARY_BONUS: int = 10          # pressing military need — locked s22.7a

static func evaluate_proposal(
	proposing_clan_disposition: int,
	character_value: int,
	favor_tier: int,
	has_military_objective: bool,
) -> int:
	var score: int = proposing_clan_disposition
	score += character_value
	score += favor_tier * PROPOSAL_FAVOR_TIER_MULTIPLIER
	if has_military_objective:
		score += PROPOSAL_MILITARY_BONUS
	return score


# -- Dissolution Constants (s57.49.7) -----------------------------------------

# Honor / Glory losses per GDD s57.49.7 Pathway 1.
# DISSOLUTION_HONOR_LOSS_LORD: Table 2.3 Lord-Commanded Dissolution (s57.49.1, confirmed).
const DISSOLUTION_HONOR_LOSS_LORD: float = -1.0
# DISSOLUTION_GLORY_LOSS_SPOUSE: s46 Table 2.4 anchor: "Family Dishonor = −1 Glory Rank."
# Dissolution is comparable but less severe (no personal act of dishonor by the spouse),
# so half that magnitude = −0.5 (s57.49b).
const DISSOLUTION_GLORY_LOSS_SPOUSE: float = -0.5
# Disposition penalties — derived in s57.49b from s12.2 tier boundaries.
# FAMILY: mid-Rival tier (−20, within −11 to −30 bounds). CLAN: Stranger/Rival
# boundary (−10, keeps clan-level cooling in Stranger without forcing Rival).
const DISSOLUTION_FAMILY_DISP_PENALTY: int = -20
const DISSOLUTION_CLAN_DISP_PENALTY: int = -10  # cross-clan only


static func dissolve_marriage(marriage: Dictionary) -> void:
	marriage["active"] = false


static func find_active_marriage_for_character(
	char_id: int,
	marriages: Array,
) -> Dictionary:
	for m: Dictionary in marriages:
		if not m.get("active", false):
			continue
		if m.get("character_a_id", -1) == char_id or m.get("character_b_id", -1) == char_id:
			return m
	return {}


static func get_dissolution_topic_variant(pathway: int) -> String:
	match pathway:
		2:
			return "criminal_conviction"
		3:
			return "monastic_retirement"
		4:
			return "imperial_decree"
	return "lord_command"


# -- Benten Festival Bonus ----------------------------------------------------

const BENTEN_FESTIVAL_DAY: int = 9
const BENTEN_FESTIVAL_MONTH: int = 11

const BENTEN_FESTIVAL_BONUS: int = 15  # most auspicious marriage day — locked s22.7a

static func is_benten_festival(ic_day: int) -> bool:
	var day_of_year: int = ic_day % 360
	var month: int = int(day_of_year / 30) + 1
	var day_of_month: int = (day_of_year % 30) + 1
	return month == BENTEN_FESTIVAL_MONTH and day_of_month == BENTEN_FESTIVAL_DAY
