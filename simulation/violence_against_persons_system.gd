class_name ViolenceAgainstPersonsSystem
## Violence Against Persons crime handling per GDD s11.3.12.
## Covers: severity classification, status modifiers, punishment scaling,
## repeated offense tracking, duel pretext generation, detection rules.


# -- Severity Constants (s11.3.12a) -----

const HONOR_LOSS: float = -0.2
const GLORY_LOSS: float = -0.1
const TOPIC_TIER_FIRST: int = 4
const TOPIC_TIER_REPEATED: int = 3
const REPEATED_OFFENSE_WINDOW_SEASONS: int = 4
const REPEATED_OFFENSE_TOPIC_THRESHOLD: int = 3


# -- Detection (s11.3.12b) -----

static func is_always_detected() -> bool:
	return true


static func get_detection_result(doshin_present: bool) -> Dictionary:
	return {
		"detected": true,
		"witnesses_plentiful": true,
		"doshin_response": doshin_present,
		"zone_event_log_recorded": true,
	}


# -- Status Modifier (s11.3.12c) -----

enum StatusDirection {
	UPWARD,
	EQUAL,
	DOWNWARD,
}

enum PunishmentTier {
	REPRIMAND,
	HOUSE_ARREST_SHORT,
	HOUSE_ARREST_LONG,
	BANISHMENT,
	FORMAL_CENSURE,
}


static func get_status_direction(
	attacker_status: float,
	victim_status: float,
) -> StatusDirection:
	if attacker_status < victim_status:
		return StatusDirection.UPWARD
	if attacker_status > victim_status:
		return StatusDirection.DOWNWARD
	return StatusDirection.EQUAL


static func get_base_punishment(direction: StatusDirection) -> PunishmentTier:
	match direction:
		StatusDirection.UPWARD:
			return PunishmentTier.HOUSE_ARREST_LONG
		StatusDirection.EQUAL:
			return PunishmentTier.HOUSE_ARREST_SHORT
		StatusDirection.DOWNWARD:
			return PunishmentTier.REPRIMAND
		_:
			return PunishmentTier.HOUSE_ARREST_SHORT


# -- Repeated Offenses (s11.3.12e) -----

static func count_offenses_in_window(
	offense_seasons: Array[int],
	current_season: int,
) -> int:
	var count: int = 0
	for season in offense_seasons:
		if current_season - season <= REPEATED_OFFENSE_WINDOW_SEASONS:
			count += 1
	return count


static func get_infamy_for_repeated(offense_count_in_window: int) -> float:
	if offense_count_in_window <= 1:
		return 0.0
	return 0.1 * float(offense_count_in_window - 1)


static func get_topic_tier(offense_count_in_window: int) -> int:
	if offense_count_in_window >= REPEATED_OFFENSE_TOPIC_THRESHOLD:
		return TOPIC_TIER_REPEATED
	return TOPIC_TIER_FIRST


static func get_punishment_escalation(
	base_tier: PunishmentTier,
	offense_count_in_window: int,
) -> PunishmentTier:
	var tier_value: int = base_tier
	tier_value += maxi(offense_count_in_window - 1, 0)
	return mini(tier_value, PunishmentTier.FORMAL_CENSURE) as PunishmentTier


# -- Duel Pretext (s11.3.12d) -----

static func generates_duel_pretext() -> bool:
	return true


static func get_provocation_result(
	attacker_id: int,
	victim_id: int,
) -> Dictionary:
	return {
		"provocation_flag": true,
		"provoked_character_id": victim_id,
		"provoking_character_id": attacker_id,
		"duel_challenge_permitted": true,
	}


# -- Cross-Clan (s11.3.12c) -----

static func is_cross_clan(attacker_clan_id: int, victim_clan_id: int) -> bool:
	return attacker_clan_id != victim_clan_id


static func get_jurisdiction(
	attacker_clan_id: int,
	victim_clan_id: int,
) -> Dictionary:
	if attacker_clan_id == victim_clan_id:
		return {
			"primary_jurisdiction": victim_clan_id,
			"cross_clan": false,
			"emerald_escalation_possible": false,
		}
	return {
		"primary_jurisdiction": victim_clan_id,
		"cross_clan": true,
		"emerald_escalation_possible": true,
	}


# -- Consequence Summary -----

static func get_conviction_consequences(
	direction: StatusDirection,
	offense_count_in_window: int,
	property_damage_koku: int,
) -> Dictionary:
	var base_punishment: PunishmentTier = get_base_punishment(direction)
	var final_punishment: PunishmentTier = get_punishment_escalation(
		base_punishment, offense_count_in_window
	)
	var infamy: float = get_infamy_for_repeated(offense_count_in_window)
	var topic_tier: int = get_topic_tier(offense_count_in_window)

	return {
		"honor_loss": HONOR_LOSS,
		"glory_loss": GLORY_LOSS,
		"infamy_gain": infamy,
		"punishment_tier": final_punishment,
		"topic_tier": topic_tier,
		"property_damage_restitution": property_damage_koku,
		"duel_pretext_generated": true,
	}


# -- Heimin Exception (s11.3.12) -----

static func is_legally_actionable(
	attacker_is_samurai: bool,
	victim_is_samurai: bool,
	disrupts_productivity: bool,
) -> bool:
	if attacker_is_samurai and victim_is_samurai:
		return true
	if attacker_is_samurai and not victim_is_samurai:
		return disrupts_productivity
	return false
