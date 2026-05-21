class_name ViolenceSystem
## Non-lethal violence between samurai per GDD s11.3.12.
## Covers severity, status modifiers, duel pretext, and repeated offense escalation.


enum PunishmentLevel {
	REPRIMAND,
	HOUSE_ARREST,
	BANISHMENT,
	FORMAL_CENSURE,
}

const HONOR_LOSS: float = -0.2
const GLORY_LOSS: float = -0.1
const BASE_TOPIC_TIER: int = 4
const REPEATED_OFFENSE_TIER: int = 3
const REPEAT_WINDOW_SEASONS: int = 4
const REPEAT_THRESHOLD_FOR_ESCALATION: int = 3
const INFAMY_PER_REPEATED_OFFENSE: float = 0.5


static func evaluate_violence(
	attacker: L5RCharacterData,
	victim: L5RCharacterData,
	prior_offenses_in_window: int,
	is_brutal: bool,
) -> Dictionary:
	var status_direction: String = _get_status_direction(attacker, victim)
	var punishment: PunishmentLevel = _determine_punishment(status_direction, prior_offenses_in_window)
	var topic_tier: int = _determine_topic_tier(prior_offenses_in_window)
	var infamy_gain: float = _determine_infamy(prior_offenses_in_window, is_brutal)

	return {
		"crime_type": Enums.CrimeType.VIOLENCE,
		"severity": Enums.CrimeSeverity.MINOR,
		"honor_loss": HONOR_LOSS,
		"glory_loss": GLORY_LOSS,
		"infamy_gain": infamy_gain,
		"topic_tier": topic_tier,
		"punishment": punishment,
		"status_direction": status_direction,
		"creates_duel_pretext": true,
		"auto_detected": true,
	}


static func _get_status_direction(attacker: L5RCharacterData, victim: L5RCharacterData) -> String:
	if attacker.status < victim.status:
		return "upward"
	elif attacker.status > victim.status:
		return "downward"
	return "equal"


static func _determine_punishment(status_direction: String, prior_offenses: int) -> PunishmentLevel:
	if status_direction == "upward":
		if prior_offenses >= REPEAT_THRESHOLD_FOR_ESCALATION:
			return PunishmentLevel.FORMAL_CENSURE
		return PunishmentLevel.BANISHMENT

	if prior_offenses >= REPEAT_THRESHOLD_FOR_ESCALATION:
		return PunishmentLevel.BANISHMENT

	if status_direction == "downward":
		return PunishmentLevel.REPRIMAND

	return PunishmentLevel.HOUSE_ARREST


static func _determine_topic_tier(prior_offenses: int) -> int:
	if prior_offenses >= REPEAT_THRESHOLD_FOR_ESCALATION:
		return REPEATED_OFFENSE_TIER
	return BASE_TOPIC_TIER


static func _determine_infamy(prior_offenses: int, is_brutal: bool) -> float:
	if is_brutal:
		return INFAMY_PER_REPEATED_OFFENSE
	if prior_offenses >= 1:
		return INFAMY_PER_REPEATED_OFFENSE
	return 0.0


static func apply_consequences(
	attacker: L5RCharacterData,
	evaluation: Dictionary,
) -> Dictionary:
	HonorGlorySystem.apply_honor_change(attacker, evaluation["honor_loss"])
	HonorGlorySystem.apply_glory_change(attacker, evaluation["glory_loss"])
	if evaluation["infamy_gain"] > 0.0:
		attacker.infamy += evaluation["infamy_gain"]

	return {
		"honor_change": evaluation["honor_loss"],
		"glory_change": evaluation["glory_loss"],
		"infamy_change": evaluation["infamy_gain"],
		"punishment": evaluation["punishment"],
		"topic_tier": evaluation["topic_tier"],
	}


static func creates_duel_pretext(
	_attacker: L5RCharacterData,
	_victim: L5RCharacterData,
) -> Dictionary:
	return {
		"pretext_granted": true,
		"pretext_type": "violence_provocation",
	}


static func count_offenses_in_window(
	offense_days: Array,
	current_ic_day: int,
	days_per_season: int = 90,
) -> int:
	var window_start: int = current_ic_day - (REPEAT_WINDOW_SEASONS * days_per_season)
	var count: int = 0
	for day: int in offense_days:
		if day >= window_start:
			count += 1
	return count


static func should_escalate_to_killing(blades_drawn: bool, victim_died: bool) -> bool:
	return blades_drawn and victim_died
