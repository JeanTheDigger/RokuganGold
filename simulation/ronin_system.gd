class_name RoninSystem
## Ronin status transitions per GDD s52 Part 5 and s52.5.
## Handles conversion to/from ronin status, hiring, income tracking,
## and desperation escalation toward insurgency seeding.


enum RoninCause {
	LORD_DEATH_NO_HEIR,
	DISMISSAL,
	DISMISSAL_DISGRACE,
	CLAN_DESTROYED,
	VOLUNTARY_DEPARTURE,
}

const RONIN_CLAN: String = "Ronin"
const SEASONS_BEFORE_DEBT: int = 4
const SEASONS_BEFORE_DESPERATE: int = 8

# Honor transitions on becoming ronin — locked in s52.5 A38-A41.
const HONOR_LOSS_ON_RONIN: float = 0.0           # LORD_DEATH_NO_HEIR, CLAN_DESTROYED
const HONOR_LOSS_VOLUNTARY: float = 0.5           # VOLUNTARY_DEPARTURE (s52.5 A39)
const HONOR_LOSS_DISMISSAL: float = 0.3           # DISMISSAL formal release (s52.5 A40)
const HONOR_LOSS_DISMISSAL_DISGRACE: float = 1.0  # DISMISSAL_DISGRACE (s52.5 A41)

# Honor recovery on acceptance into service — locked in s52.5 A42.
const HIRING_HONOR_RECOVERY: float = 0.3

# Petition mechanics — locked in s52.5 A43-A45.
const BASE_PETITION_TN: int = 20
const PETITION_FAILURE_DISPOSITION_PENALTY: int = -3
const PETITION_COOLDOWN_DAYS: int = 90

# Disposition TN modifiers for petition (Part B table, s52.5).
const PETITION_DISP_COLD_MODIFIER: int = 5       # disposition == 0 (pure Stranger)
const PETITION_DISP_FRIEND_MODIFIER: int = -5    # disposition +31 to +60
const PETITION_DISP_ALLY_MODIFIER: int = -10     # disposition +61+

# Permanent ronin disgrace-count threshold.
const PERMANENT_RONIN_DISGRACE_COUNT: int = 3

# Kept for external callers (no mechanic — stipend loss handled by ResourceTick).
const STIPEND_LOSS_HONOR_COST: float = 0.0
# Legacy alias kept for any callers that used the old zero constant name.
const PETITION_TN: int = BASE_PETITION_TN


static func make_ronin(character: L5RCharacterData, cause: RoninCause) -> Dictionary:
	var old_clan: String = character.clan
	var old_role: String = character.role_position
	var old_lord: int = character.lord_id

	character.original_lord_id = character.lord_id if character.original_lord_id == -1 else character.original_lord_id
	character.lord_id = -1
	character.role_position = ""
	character.operational_superior_id = -1
	character.operational_hierarchy_type = Enums.OperationalHierarchyType.NONE
	character.assigned_company_id = -1
	character.commanded_unit_id = -1
	character.military_rank = Enums.MilitaryRank.NONE

	var status_loss: float = 2.0 if cause == RoninCause.DISMISSAL_DISGRACE else 1.0
	HonorGlorySystem.apply_status_change(character, -status_loss)

	var honor_loss: float = _honor_loss_for_cause(cause)
	HonorGlorySystem.apply_honor_change(character, -honor_loss)

	return {
		"character_id": character.character_id,
		"cause": cause,
		"old_clan": old_clan,
		"old_role": old_role,
		"old_lord_id": old_lord,
		"honor_loss": honor_loss,
	}


static func _honor_loss_for_cause(cause: RoninCause) -> float:
	match cause:
		RoninCause.VOLUNTARY_DEPARTURE:
			return HONOR_LOSS_VOLUNTARY
		RoninCause.DISMISSAL:
			return HONOR_LOSS_DISMISSAL
		RoninCause.DISMISSAL_DISGRACE:
			return HONOR_LOSS_DISMISSAL_DISGRACE
		_:
			return HONOR_LOSS_ON_RONIN


static func is_ronin(character: L5RCharacterData) -> bool:
	return character.lord_id == -1 and character.role_position == "" and character.status < 1.0


static func accept_into_service(
	character: L5RCharacterData,
	new_lord_id: int,
	new_role: String,
	new_clan: String,
) -> Dictionary:
	if character.permanent_ronin:
		return {"character_id": character.character_id, "rejected": true, "reason": "permanent_ronin"}
	character.lord_id = new_lord_id
	character.role_position = new_role
	character.clan = new_clan
	if character.status < 1.0:
		HonorGlorySystem.apply_status_change(character, 1.0 - character.status)
	HonorGlorySystem.apply_honor_change(character, HIRING_HONOR_RECOVERY)
	character.supply_ledger.erase("petition_refused_until")

	return {
		"character_id": character.character_id,
		"new_lord_id": new_lord_id,
		"new_role": new_role,
		"new_clan": new_clan,
		"honor_recovery": HIRING_HONOR_RECOVERY,
	}


static func get_seasons_without_income(character: L5RCharacterData, current_season_count: int) -> int:
	var became_ronin_season: int = character.supply_ledger.get("ronin_since_season", -1)
	if became_ronin_season < 0:
		return 0
	var last_income_season: int = character.supply_ledger.get("last_income_season", became_ronin_season)
	return current_season_count - last_income_season


static func check_desperation(character: L5RCharacterData, current_season_count: int) -> Dictionary:
	var seasons_no_income: int = get_seasons_without_income(character, current_season_count)

	if seasons_no_income >= SEASONS_BEFORE_DESPERATE:
		return {"state": "desperate", "seasons": seasons_no_income}
	if seasons_no_income >= SEASONS_BEFORE_DEBT:
		if not character.disadvantages.has("Debt"):
			character.disadvantages.append("Debt")
		return {"state": "debt", "seasons": seasons_no_income}

	return {"state": "stable", "seasons": seasons_no_income}


static func record_income(character: L5RCharacterData, current_season_count: int) -> void:
	character.supply_ledger["last_income_season"] = current_season_count


static func mark_ronin_start(character: L5RCharacterData, current_season_count: int) -> void:
	character.supply_ledger["ronin_since_season"] = current_season_count
	character.supply_ledger["last_income_season"] = current_season_count


static func is_desperate(character: L5RCharacterData, current_season_count: int) -> bool:
	return get_seasons_without_income(character, current_season_count) >= SEASONS_BEFORE_DESPERATE


static func can_seed_insurgency(character: L5RCharacterData, current_season_count: int) -> bool:
	if not is_desperate(character, current_season_count):
		return false
	return true


## Compute the petition TN from the lord's disposition toward the petitioner (s52.5 Part B).
static func compute_petition_tn(lord_disposition: int) -> int:
	if lord_disposition >= 61:
		return BASE_PETITION_TN + PETITION_DISP_ALLY_MODIFIER
	if lord_disposition >= 31:
		return BASE_PETITION_TN + PETITION_DISP_FRIEND_MODIFIER
	if lord_disposition >= 1:
		return BASE_PETITION_TN
	if lord_disposition == 0:
		return BASE_PETITION_TN + PETITION_DISP_COLD_MODIFIER
	# Negative disposition — petition should not proceed (caller should gate on >= 0)
	return BASE_PETITION_TN + PETITION_DISP_COLD_MODIFIER


## Returns true if the lord should auto-reject the petition before the roll (s52.5 Part C).
static func lord_auto_rejects(
	lord: L5RCharacterData,
	petitioner: L5RCharacterData,
	lord_disposition: int,
	lords_known_crime_types: Array,
) -> bool:
	if petitioner.permanent_ronin:
		return true
	if lord_disposition <= -1:
		return true
	# Known TREASON or MAHO_USE conviction is a hard disqualifier
	for ct: int in lords_known_crime_types:
		if ct == Enums.CrimeType.TREASON or ct == Enums.CrimeType.MAHO_USE:
			return true
	# Former enemy-clan voluntary departure
	if petitioner.supply_ledger.get("ronin_cause", -1) == RoninCause.VOLUNTARY_DEPARTURE:
		if lord.clan != petitioner.clan:
			for w: Dictionary in lord.known_contacts:
				if w.is_empty():
					continue
			# Check if lord's clan is at war with petitioner's original clan — caller passes this
			if lords_known_crime_types.has(-999):  # sentinel passed by caller when at_war
				return true
	return false


static func resolve_petition(
	character: L5RCharacterData,
	target_lord: L5RCharacterData,
	dice_engine: DiceEngine,
	lord_disposition: int = 0,
) -> Dictionary:
	if character.permanent_ronin:
		return {"success": false, "rejected": true, "reason": "permanent_ronin", "character_id": character.character_id, "lord_id": target_lord.character_id}
	if lord_disposition <= -1:
		return {"success": false, "rejected": true, "reason": "disposition_too_low", "character_id": character.character_id, "lord_id": target_lord.character_id}

	var tn: int = compute_petition_tn(lord_disposition)

	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Etiquette", tn,
	)
	return {
		"success": check.get("success", false),
		"rolled": check.get("total", 0),
		"tn": tn,
		"character_id": character.character_id,
		"lord_id": target_lord.character_id,
	}


## Set permanent_ronin on TREASON or MAHO_USE conviction (s52.5 Part E).
static func check_permanent_ronin_on_conviction(
	character: L5RCharacterData,
	crime_type: int,
) -> bool:
	if crime_type == Enums.CrimeType.TREASON or crime_type == Enums.CrimeType.MAHO_USE:
		character.permanent_ronin = true
		return true
	return false


## Count DISMISSAL_DISGRACE events and set permanent_ronin at threshold (s52.5 Part E).
static func check_permanent_ronin_on_disgrace(
	character: L5RCharacterData,
	crime_records: Array,
) -> bool:
	if character.permanent_ronin:
		return true
	var count: int = 0
	for rec in crime_records:
		var cr: CrimeRecord = rec as CrimeRecord
		if cr == null:
			continue
		if cr.perpetrator_id != character.character_id:
			continue
		if cr.source_action == "dismissal_disgrace":
			count += 1
	if count >= PERMANENT_RONIN_DISGRACE_COUNT:
		character.permanent_ronin = true
		return true
	return false


static func hire_as_mercenary(
	character: L5RCharacterData,
	employer_id: int,
	koku_payment: float,
	current_season_count: int,
) -> Dictionary:
	character.koku += koku_payment
	character.operational_superior_id = employer_id
	character.operational_hierarchy_type = Enums.OperationalHierarchyType.MILITARY
	record_income(character, current_season_count)

	return {
		"character_id": character.character_id,
		"employer_id": employer_id,
		"payment": koku_payment,
	}


static func process_seasonal_ronin(
	characters: Array,
	current_season_count: int,
) -> Dictionary:
	var debt_results: Array = []
	var desperate_results: Array = []
	var insurgency_seeds: Array = []

	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if not is_ronin(c):
			continue
		if c.supply_ledger.get("ronin_since_season", -1) < 0:
			continue

		var desp: Dictionary = check_desperation(c, current_season_count)
		if desp["state"] == "desperate":
			desperate_results.append({
				"character_id": c.character_id,
				"seasons": desp["seasons"],
			})
			if can_seed_insurgency(c, current_season_count):
				insurgency_seeds.append(c.character_id)
		elif desp["state"] == "debt":
			debt_results.append({
				"character_id": c.character_id,
				"seasons": desp["seasons"],
			})

	return {
		"debt_results": debt_results,
		"desperate_results": desperate_results,
		"insurgency_seeds": insurgency_seeds,
	}
