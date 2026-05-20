class_name SentencingSystem
## Personality-driven punishment selection per GDD s11.3.15.
## When a character is convicted (decreed_guilty), the daimyo decides
## punishment using a leniency score = personality_base + disposition_modifier
## + pressure_modifier. Higher leniency = lighter punishment.


enum PunishmentLevel {
	LIGHTEST,
	LIGHT,
	STANDARD,
	HARSH,
	HARSHEST,
}

enum Punishment {
	VERBAL_REPRIMAND,
	TEMPORARY_EXILE,
	HOUSE_ARREST,
	RECOMPENSE,
	PUBLIC_APOLOGY,
	RESTITUTION,
	DEMOTION,
	LOSS_OF_OFFICE,
	EXILE_PERMANENT,
	SEPPUKU_OFFERED,
	EXECUTION,
	EXECUTION_WITHOUT_SEPPUKU,
}


const BUSHIDO_LENIENCY: Dictionary = {
	Enums.BushidoVirtue.JIN: 30,
	Enums.BushidoVirtue.GI: 0,
	Enums.BushidoVirtue.REI: 15,
	Enums.BushidoVirtue.YU: -10,
	Enums.BushidoVirtue.CHUGI: 0,
	Enums.BushidoVirtue.MEIYO: -10,
	Enums.BushidoVirtue.MAKOTO: 10,
}

const SHOURIDO_LENIENCY: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: 0,
	Enums.ShouridoVirtue.KETSUI: -15,
	Enums.ShouridoVirtue.DOSATSU: 0,
	Enums.ShouridoVirtue.CHISHIKI: 0,
	Enums.ShouridoVirtue.KANPEKI: -20,
	Enums.ShouridoVirtue.KYORYOKU: -15,
	Enums.ShouridoVirtue.ISHI: -20,
}

const DISPOSITION_LENIENCY_THRESHOLDS: Array[Array] = [
	[50, 100, 20],
	[20, 49, 10],
	[-10, 19, 0],
	[-30, -11, -10],
	[-100, -31, -20],
]

const TOPIC_TIER_PRESSURE: Dictionary = {
	0: 0,
	4: -5,
	3: -10,
	2: -20,
	1: -30,
}

const CROSS_CLAN_VICTIM_PRESSURE: int = -10
const CROSS_CLAN_PUSHING_PRESSURE: int = -15

# Punishment ranges per crime type.
# Each array is ordered: [lightest, light, standard, harsh, harshest]
# Some crimes have fixed punishments (e.g. maho = execution without seppuku always).
const PUNISHMENT_RANGES: Dictionary = {
	Enums.CrimeType.DISHONORABLE_CONDUCT: [
		Punishment.VERBAL_REPRIMAND,
		Punishment.VERBAL_REPRIMAND,
		Punishment.TEMPORARY_EXILE,
		Punishment.TEMPORARY_EXILE,
		Punishment.HOUSE_ARREST,
	],
	Enums.CrimeType.VIOLENCE: [
		Punishment.PUBLIC_APOLOGY,
		Punishment.HOUSE_ARREST,
		Punishment.HOUSE_ARREST,
		Punishment.RECOMPENSE,
		Punishment.RECOMPENSE,
	],
	Enums.CrimeType.UNSANCTIONED_DUEL_DEATH: [
		Punishment.HOUSE_ARREST,
		Punishment.HOUSE_ARREST,
		Punishment.RECOMPENSE,
		Punishment.RECOMPENSE,
		Punishment.SEPPUKU_OFFERED,
	],
	Enums.CrimeType.SKIMMING: [
		Punishment.RESTITUTION,
		Punishment.RESTITUTION,
		Punishment.DEMOTION,
		Punishment.LOSS_OF_OFFICE,
		Punishment.SEPPUKU_OFFERED,
	],
	Enums.CrimeType.UNSANCTIONED_OPEN_KILLING: [
		Punishment.EXILE_PERMANENT,
		Punishment.EXILE_PERMANENT,
		Punishment.SEPPUKU_OFFERED,
		Punishment.SEPPUKU_OFFERED,
		Punishment.EXECUTION,
	],
	Enums.CrimeType.UNSANCTIONED_COVERT_KILLING: [
		Punishment.SEPPUKU_OFFERED,
		Punishment.SEPPUKU_OFFERED,
		Punishment.EXECUTION,
		Punishment.EXECUTION,
		Punishment.EXECUTION,
	],
	Enums.CrimeType.MAGISTRATE_CORRUPTION: [
		Punishment.LOSS_OF_OFFICE,
		Punishment.LOSS_OF_OFFICE,
		Punishment.SEPPUKU_OFFERED,
		Punishment.SEPPUKU_OFFERED,
		Punishment.EXECUTION,
	],
	Enums.CrimeType.DUEL_DEFILEMENT: [
		Punishment.PUBLIC_APOLOGY,
		Punishment.HOUSE_ARREST,
		Punishment.RECOMPENSE,
		Punishment.EXILE_PERMANENT,
		Punishment.SEPPUKU_OFFERED,
	],
	Enums.CrimeType.TREASON: [
		Punishment.EXILE_PERMANENT,
		Punishment.SEPPUKU_OFFERED,
		Punishment.SEPPUKU_OFFERED,
		Punishment.EXECUTION,
		Punishment.EXECUTION,
	],
	Enums.CrimeType.MAHO: [
		Punishment.EXECUTION_WITHOUT_SEPPUKU,
		Punishment.EXECUTION_WITHOUT_SEPPUKU,
		Punishment.EXECUTION_WITHOUT_SEPPUKU,
		Punishment.EXECUTION_WITHOUT_SEPPUKU,
		Punishment.EXECUTION_WITHOUT_SEPPUKU,
	],
	Enums.CrimeType.OTHER: [
		Punishment.VERBAL_REPRIMAND,
		Punishment.PUBLIC_APOLOGY,
		Punishment.HOUSE_ARREST,
		Punishment.TEMPORARY_EXILE,
		Punishment.EXILE_PERMANENT,
	],
}


static func calculate_leniency(
	daimyo: L5RCharacterData,
	convicted_id: int,
	crime_topic_tier: int,
	is_cross_clan_victim: bool,
	victim_clan_pushing: bool,
	seigyo_usefulness: int = 0,
) -> int:
	var personality_base: int = _get_personality_base(daimyo, seigyo_usefulness)
	var disposition_mod: int = _get_disposition_modifier(daimyo, convicted_id)
	var pressure_mod: int = _get_pressure_modifier(crime_topic_tier, is_cross_clan_victim, victim_clan_pushing)

	if daimyo.bushido_virtue == Enums.BushidoVirtue.GI:
		return 0

	return personality_base + disposition_mod + pressure_mod


static func select_punishment(
	daimyo: L5RCharacterData,
	record: CrimeRecord,
	crime_topic_tier: int = 0,
	is_cross_clan_victim: bool = false,
	victim_clan_pushing: bool = false,
	seigyo_usefulness: int = 0,
) -> Dictionary:
	var leniency: int = calculate_leniency(
		daimyo, record.perpetrator_id, crime_topic_tier,
		is_cross_clan_victim, victim_clan_pushing, seigyo_usefulness
	)
	var level: PunishmentLevel = _leniency_to_level(leniency)
	var punishment: Punishment = _get_punishment_for_crime(record.crime_type, level)

	return {
		"leniency_score": leniency,
		"punishment_level": level,
		"punishment": punishment,
		"gi_override": daimyo.bushido_virtue == Enums.BushidoVirtue.GI,
	}


static func _get_personality_base(daimyo: L5RCharacterData, seigyo_usefulness: int) -> int:
	if daimyo.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return clampi(seigyo_usefulness, -20, 20)
	if daimyo.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return SHOURIDO_LENIENCY.get(daimyo.shourido_virtue, 0)
	return BUSHIDO_LENIENCY.get(daimyo.bushido_virtue, 0)


static func _get_disposition_modifier(daimyo: L5RCharacterData, convicted_id: int) -> int:
	var disposition: int = daimyo.disposition_values.get(convicted_id, 0)
	for threshold: Array[int] in DISPOSITION_LENIENCY_THRESHOLDS:
		if disposition >= threshold[0] and disposition <= threshold[1]:
			return threshold[2]
	return 0


static func _get_pressure_modifier(
	crime_topic_tier: int,
	is_cross_clan_victim: bool,
	victim_clan_pushing: bool,
) -> int:
	var base: int = TOPIC_TIER_PRESSURE.get(crime_topic_tier, 0)
	if is_cross_clan_victim:
		base += CROSS_CLAN_VICTIM_PRESSURE
	if victim_clan_pushing:
		base += CROSS_CLAN_PUSHING_PRESSURE
	return base


static func _leniency_to_level(leniency: int) -> PunishmentLevel:
	if leniency >= 30:
		return PunishmentLevel.LIGHTEST
	if leniency >= 10:
		return PunishmentLevel.LIGHT
	if leniency >= -10:
		return PunishmentLevel.STANDARD
	if leniency >= -30:
		return PunishmentLevel.HARSH
	return PunishmentLevel.HARSHEST


static func _get_punishment_for_crime(crime_type: Enums.CrimeType, level: PunishmentLevel) -> Punishment:
	var range_arr: Array = PUNISHMENT_RANGES.get(crime_type, PUNISHMENT_RANGES[Enums.CrimeType.OTHER])
	return range_arr[level] as Punishment
