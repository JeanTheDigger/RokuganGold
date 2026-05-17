class_name MagistrateAllocationSystem
## Magistrate allocation rules and conviction cascade per GDD s11.3.17.
## Defines: magistrate count per administrative unit, yoriki capacity,
## Emerald Magistrate scarcity constraints, and office-holder conviction
## cascade effects (case suspension, stability hits, appointment gaps).


# -- Magistrate Count (s11.3.17a) -----

const BASE_MAGISTRATES_PER_PROVINCE: int = 1
const ADDITIONAL_PER_CITY: int = 1
const OTOSAN_UCHI_PER_DISTRICT: int = 1
const OTOSAN_UCHI_DISTRICTS: int = 17


static func get_magistrate_count(
	has_city: bool,
	city_count: int,
	is_otosan_uchi: bool,
	district_count: int = 0,
) -> int:
	if is_otosan_uchi:
		var districts: int = district_count if district_count > 0 else OTOSAN_UCHI_DISTRICTS
		return districts * OTOSAN_UCHI_PER_DISTRICT

	var count: int = BASE_MAGISTRATES_PER_PROVINCE
	if has_city:
		count += city_count * ADDITIONAL_PER_CITY
	return count


# -- Yoriki (s11.3.17b) -----

const YORIKI_MIN_RURAL: int = 1
const YORIKI_MAX_RURAL: int = 2
const YORIKI_MIN_CITY: int = 4
const YORIKI_MAX_CITY: int = 5
const YORIKI_MAX_MAJOR: int = 12

enum JurisdictionType {
	RURAL,
	CITY,
	MAJOR,
}


static func get_yoriki_range(jurisdiction: JurisdictionType) -> Dictionary:
	match jurisdiction:
		JurisdictionType.RURAL:
			return {"min": YORIKI_MIN_RURAL, "max": YORIKI_MAX_RURAL}
		JurisdictionType.CITY:
			return {"min": YORIKI_MIN_CITY, "max": YORIKI_MAX_CITY}
		JurisdictionType.MAJOR:
			return {"min": YORIKI_MIN_CITY, "max": YORIKI_MAX_MAJOR}
	return {"min": 1, "max": 2}


static func get_investigation_capacity(yoriki_count: int) -> int:
	return 1 + yoriki_count


# -- Case Load and Availability (s11.3.17d) -----

static func is_magistrate_available(
	active_case_count: int,
) -> bool:
	return active_case_count == 0


static func get_case_queue_status(
	active_cases: int,
	pending_crimes: int,
) -> Dictionary:
	return {
		"magistrate_occupied": active_cases > 0,
		"crimes_waiting": pending_crimes,
		"legal_coverage_compromised": active_cases > 0 and pending_crimes > 0,
	}


# -- Conviction Cascade (s11.3.17e) -----

enum ConvictedPosition {
	MAGISTRATE,
	GOVERNOR,
	FAMILY_DAIMYO,
	CLAN_CHAMPION,
}

const STABILITY_HIT_GOVERNOR: int = -5
const STABILITY_HIT_FAMILY_DAIMYO: int = -5
const STABILITY_HIT_CLAN_CHAMPION: int = -5


static func get_conviction_cascade(
	position: ConvictedPosition,
) -> Dictionary:
	match position:
		ConvictedPosition.MAGISTRATE:
			return {
				"position": "magistrate",
				"cases_suspended": true,
				"replacement_required": true,
				"replacement_re_examines_evidence": true,
				"stability_hit": 0,
				"topic_tier": 4,
				"scope": "province",
			}
		ConvictedPosition.GOVERNOR:
			return {
				"position": "governor",
				"succession_fires": true,
				"stability_hit": STABILITY_HIT_GOVERNOR,
				"stability_scope": "province",
				"topic_tier": 3,
				"scope": "province",
			}
		ConvictedPosition.FAMILY_DAIMYO:
			return {
				"position": "family_daimyo",
				"succession_fires": true,
				"stability_hit": STABILITY_HIT_FAMILY_DAIMYO,
				"stability_scope": "family_provinces",
				"topic_tier": 2,
				"scope": "clan",
			}
		ConvictedPosition.CLAN_CHAMPION:
			return {
				"position": "clan_champion",
				"succession_fires": true,
				"stability_hit": STABILITY_HIT_CLAN_CHAMPION,
				"stability_scope": "all_clan_provinces",
				"topic_tier": 2,
				"scope": "empire",
			}
	return {}


static func resolve_magistrate_conviction(
	magistrate_id: int,
	crime_records: Array[CrimeRecord],
) -> Dictionary:
	var suspended_cases: Array[int] = []
	for record: CrimeRecord in crime_records:
		if record.investigating_magistrate_id == magistrate_id:
			if record.legal_status == Enums.LegalStatus.UNDER_INVESTIGATION \
					or record.legal_status == Enums.LegalStatus.ACCUSED:
				suspended_cases.append(record.case_id)

	return {
		"suspended_case_ids": suspended_cases,
		"case_count": suspended_cases.size(),
		"replacement_needed": true,
		"evidence_preserved": true,
	}


static func assign_replacement_magistrate(
	suspended_case_ids: Array[int],
	new_magistrate_id: int,
	crime_records: Array[CrimeRecord],
) -> Dictionary:
	var reassigned: int = 0
	for record: CrimeRecord in crime_records:
		if record.case_id in suspended_case_ids:
			record.investigating_magistrate_id = new_magistrate_id
			reassigned += 1

	return {
		"new_magistrate_id": new_magistrate_id,
		"cases_reassigned": reassigned,
		"must_re_examine_evidence": true,
	}


# -- Appointment Gap (s11.3.17e) -----

static func get_vacancy_effects(position: ConvictedPosition) -> Dictionary:
	match position:
		ConvictedPosition.MAGISTRATE:
			return {
				"investigations_blocked": true,
				"new_crimes_unprocessed": true,
				"existing_cases_frozen": true,
			}
		ConvictedPosition.GOVERNOR:
			return {
				"tax_rates_frozen": true,
				"no_new_construction": true,
				"no_levy_orders": true,
				"stability_decays": true,
			}
		_:
			return {
				"administrative_paralysis": true,
				"stability_decays": true,
				"appointment_urgency": "critical",
			}


# -- Emerald Magistrate (s11.3.17c) -----

const EMERALD_MAGISTRATE_TOTAL: int = 6

enum EmeraldJurisdictionTrigger {
	CROSS_CLAN_CRIME,
	TREASON,
	MAHO,
	LOCAL_JUSTICE_FAILED,
}


static func is_emerald_jurisdiction(trigger: EmeraldJurisdictionTrigger) -> bool:
	return true


static func can_override_clan_magistrate() -> bool:
	return true


static func get_emerald_assignment_topic_tier() -> int:
	return 3
