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

# Glory transitions on becoming ronin — locked in s52.5 A38-A42.
const GLORY_LOSS_LORD_DEATH_NO_HEIR: float = 0.3    # LORD_DEATH_NO_HEIR (s52.5 A38)
const GLORY_LOSS_CLAN_DESTROYED: float = 1.0         # CLAN_DESTROYED (s52.5 A39)
# VOLUNTARY_DEPARTURE uses CrimeSystem.get_disloyalty_honor() rank-scaled (s52.5 A40)
const GLORY_LOSS_DISMISSAL: float = 0.3              # DISMISSAL formal release (s52.5 A41)
const GLORY_LOSS_DISMISSAL_DISGRACE: float = 2.0     # DISMISSAL_DISGRACE (s52.5 A42)

# Glory recovery on acceptance as retainer — locked in s52.5 A43.
const HIRING_GLORY_RECOVERY: float = 0.3

# Petition mechanics — locked in s52.5 A44-A47.
const PETITION_MIN_TN: int = 20
const PETITION_FAILURE_DISPOSITION_PENALTY: int = -3
const PETITION_COOLDOWN_DAYS: int = 90
const PETITION_MARGIN_SCALE: int = 5  # +1 effective disposition per 5 margin

# Permanent ronin disgrace-count threshold — locked in s52.5 A48.
const PERMANENT_RONIN_DISGRACE_COUNT: int = 5

# Contract payment rates (koku/season) — locked in s52.6 A51-A53.
const CONTRACT_PAYMENT_PROVINCE_DEFENSE_PER_SEASON: int = 3
const CONTRACT_PAYMENT_MAGISTRATE_AIDE_PER_SEASON: int = 2
const CONTRACT_PAYMENT_MILITARY_SERVICE_PER_SEASON: int = 2

# Contract outcome constants — locked in s52.6 A54-A57.
const GLORY_CONTRACT_COMPLETION_BONUS: float = 0.5
const CONTRACT_DECLINE_DISPOSITION: int = -1
const CONTRACT_EARLY_TERMINATION_DISPOSITION: int = -3
const CONTRACT_ABANDONED_DISPOSITION: int = -5

# Clan induction thresholds — locked in s52.7 A60-A66.
const INDUCTION_DEED_THRESHOLD: int = 8          # A60 — 8 deeds required
const INDUCTION_EXTRAORDINARY_DEED_REQUIRED: int = 1  # A66 — 1 extraordinary deed required
const INDUCTION_MIN_CONTINUOUS_SEASONS: int = 3  # A65 — 3+ seasons continuous service
const INDUCTION_MIN_DISPOSITION: int = 51
const INDUCTION_KOKU_COST: float = 10.0
const INDUCTION_INDUCTEE_GLORY_GAIN: float = 1.0
const INDUCTION_DAIMYO_GLORY_GAIN: float = 0.3
const INDUCTION_FAMILY_BASELINE_SHIFT: int = 15

# Contract type → NeedType mapping for assigned objectives.
const CONTRACT_TYPE_NEED: Dictionary = {
	"PROVINCE_DEFENSE": "DEFEND_PROVINCE",
	"MAGISTRATE_AIDE": "UPHOLD_LAW",
	"MILITARY_SERVICE": "LEVY_TROOPS",
}

# Legacy aliases.
const BASE_PETITION_TN: int = PETITION_MIN_TN


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

	HonorGlorySystem.apply_status_change(character, -1.0)

	var glory_loss: float = _glory_loss_for_cause(cause, character)
	HonorGlorySystem.apply_glory_change(character, -glory_loss)

	return {
		"character_id": character.character_id,
		"cause": cause,
		"old_clan": old_clan,
		"old_role": old_role,
		"old_lord_id": old_lord,
		"glory_loss": glory_loss,
	}


static func _glory_loss_for_cause(cause: RoninCause, character: L5RCharacterData) -> float:
	match cause:
		RoninCause.LORD_DEATH_NO_HEIR:
			return GLORY_LOSS_LORD_DEATH_NO_HEIR
		RoninCause.CLAN_DESTROYED:
			return GLORY_LOSS_CLAN_DESTROYED
		RoninCause.VOLUNTARY_DEPARTURE:
			# Rank-scaled disloyalty per Table 2.3 — applied as Glory (s52.5 A40).
			return absf(CrimeSystem.get_disloyalty_honor(character))
		RoninCause.DISMISSAL:
			return GLORY_LOSS_DISMISSAL
		RoninCause.DISMISSAL_DISGRACE:
			return GLORY_LOSS_DISMISSAL_DISGRACE
		_:
			return 0.0


static func is_ronin(character: L5RCharacterData) -> bool:
	return character.lord_id == -1 and character.role_position == "" and character.status < 1.0


static func accept_into_service(
	character: L5RCharacterData,
	new_lord_id: int,
	new_role: String,
	_new_clan: String = "",
) -> Dictionary:
	if character.permanent_ronin:
		return {"character_id": character.character_id, "rejected": true, "reason": "permanent_ronin"}
	character.lord_id = new_lord_id
	character.role_position = new_role
	# Clan is NOT changed here — acceptance is hiring as retainer, not formal clan induction.
	if character.status < 1.0:
		HonorGlorySystem.apply_status_change(character, 1.0 - character.status)
	HonorGlorySystem.apply_glory_change(character, HIRING_GLORY_RECOVERY)
	character.supply_ledger.erase("petition_refused_until")

	return {
		"character_id": character.character_id,
		"new_lord_id": new_lord_id,
		"new_role": new_role,
		"glory_recovery": HIRING_GLORY_RECOVERY,
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


## Resolve the petition roll: Ronin Courtier/Awareness vs Lord Etiquette/Awareness (s52.5 Part B).
## Returns success (ronin beat PETITION_MIN_TN), the roll totals, and the presentation_modifier.
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

	var check: Dictionary = SkillResolver.resolve_contested_check(
		character, target_lord, dice_engine, "Courtier", "Etiquette",
	)
	var ronin_total: int = check.get("total_a", 0)
	var lord_total: int = check.get("total_b", 0)
	var margin: int = ronin_total - lord_total
	var presentation_modifier: int = margin / PETITION_MARGIN_SCALE
	var success: bool = ronin_total >= PETITION_MIN_TN

	return {
		"success": success,
		"ronin_total": ronin_total,
		"lord_total": lord_total,
		"margin": margin,
		"presentation_modifier": presentation_modifier,
		"character_id": character.character_id,
		"lord_id": target_lord.character_id,
	}


## Returns true if the lord should auto-reject the petition (s52.5 Part B).
static func lord_auto_rejects(
	_lord: L5RCharacterData,
	petitioner: L5RCharacterData,
	lord_disposition: int,
	lords_known_crime_types: Array,
) -> bool:
	if petitioner.permanent_ronin:
		return true
	if lord_disposition <= -1:
		return true
	for ct: int in lords_known_crime_types:
		if ct == Enums.CrimeType.TREASON or ct == Enums.CrimeType.MAHO_USE \
				or ct == Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
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


## Returns the upfront koku cost for a contract (rate × duration_seasons).
static func get_contract_payment(contract_type: String, duration_seasons: int) -> float:
	var rate: int = 0
	match contract_type:
		"PROVINCE_DEFENSE":
			rate = CONTRACT_PAYMENT_PROVINCE_DEFENSE_PER_SEASON
		"MAGISTRATE_AIDE":
			rate = CONTRACT_PAYMENT_MAGISTRATE_AIDE_PER_SEASON
		"MILITARY_SERVICE":
			rate = CONTRACT_PAYMENT_MILITARY_SERVICE_PER_SEASON
	return float(rate * clampi(duration_seasons, 1, 3))


## Resolve a clean contract completion (s52.6 Part F).
## Calls make_ronin with DISMISSAL, applies completion bonus, increments deed credits.
## is_extraordinary: true when the contract qualifies as an extraordinary deed (s52.7 Part B).
static func complete_contract(
	character: L5RCharacterData,
	lord_family: String,
	current_season: int,
	is_extraordinary: bool = false,
) -> Dictionary:
	# Apply completion bonus before the dismissal glory loss.
	HonorGlorySystem.apply_glory_change(character, GLORY_CONTRACT_COMPLETION_BONUS)
	var ronin_result: Dictionary = make_ronin(character, RoninCause.DISMISSAL)
	mark_ronin_start(character, current_season)

	# Increment deed credits for the lord's family.
	var deeds: Dictionary = character.supply_ledger.get("contract_deeds_for_family", {})
	deeds[lord_family] = deeds.get(lord_family, 0) + 1
	character.supply_ledger["contract_deeds_for_family"] = deeds
	character.supply_ledger.erase("contract_end_ic_day")
	character.supply_ledger.erase("contract_duration_seasons")
	character.supply_ledger.erase("contract_type")
	character.supply_ledger.erase("contract_lord_family")

	if is_extraordinary:
		var extra: Dictionary = character.supply_ledger.get("extraordinary_deeds_for_family", {})
		extra[lord_family] = extra.get(lord_family, 0) + 1
		character.supply_ledger["extraordinary_deeds_for_family"] = extra

	return {
		"character_id": character.character_id,
		"lord_family": lord_family,
		"deed_count": deeds[lord_family],
		"is_extraordinary": is_extraordinary,
		"ronin_result": ronin_result,
	}


## Resolve an abandoned contract (ronin failed to fulfil objective, s52.6 Part F).
static func abandon_contract(
	character: L5RCharacterData,
	current_season: int,
) -> Dictionary:
	var ronin_result: Dictionary = make_ronin(character, RoninCause.DISMISSAL)
	mark_ronin_start(character, current_season)
	character.supply_ledger.erase("contract_end_ic_day")
	character.supply_ledger.erase("contract_duration_seasons")
	character.supply_ledger.erase("contract_type")
	character.supply_ledger.erase("contract_lord_family")
	return {
		"character_id": character.character_id,
		"abandoned": true,
		"ronin_result": ronin_result,
	}


## Resolve early termination by the lord (s52.6 Part G).
## Returns koku_refund = half of remaining value rounded down.
static func terminate_contract_early(
	character: L5RCharacterData,
	remaining_seasons: int,
	contract_type: String,
	current_season: int,
) -> Dictionary:
	var refund: float = floorf(get_contract_payment(contract_type, remaining_seasons) * 0.5)
	var ronin_result: Dictionary = make_ronin(character, RoninCause.DISMISSAL)
	mark_ronin_start(character, current_season)
	character.supply_ledger.erase("contract_end_ic_day")
	character.supply_ledger.erase("contract_type")
	character.supply_ledger.erase("contract_lord_family")
	character.supply_ledger.erase("contract_duration_seasons")
	return {
		"character_id": character.character_id,
		"koku_refund": refund,
		"ronin_result": ronin_result,
	}


## Returns total deed count for a specific family (s52.7 Part B).
static func get_deed_count(character: L5RCharacterData, family_name: String) -> int:
	var deeds: Dictionary = character.supply_ledger.get("contract_deeds_for_family", {})
	return int(deeds.get(family_name, 0))


## Returns extraordinary deed count for a specific family (s52.7 Part B).
static func get_extraordinary_deed_count(character: L5RCharacterData, family_name: String) -> int:
	var extra: Dictionary = character.supply_ledger.get("extraordinary_deeds_for_family", {})
	return int(extra.get(family_name, 0))


## Set the Family Daimyo approval flag on a ronin (s52.7 Part A).
static func approve_induction(character: L5RCharacterData, family_daimyo_id: int) -> void:
	character.supply_ledger["family_daimyo_approval"] = family_daimyo_id


## Check all induction prerequisites without modifying state (s52.7 Part C).
## sponsoring_lord: the Provincial Daimyo who would perform the ceremony.
static func can_be_inducted(
	inductee: L5RCharacterData,
	sponsoring_lord: L5RCharacterData,
	sponsoring_lord_disposition: int,
	lords_known_crime_types: Array,
) -> Dictionary:
	if inductee.permanent_ronin:
		return {"eligible": false, "reason": "permanent_ronin"}
	if sponsoring_lord.lord_rank < Enums.LordRank.PROVINCIAL_DAIMYO:
		return {"eligible": false, "reason": "sponsoring_lord_rank_too_low"}
	if sponsoring_lord_disposition < INDUCTION_MIN_DISPOSITION:
		return {"eligible": false, "reason": "disposition_too_low", "current": sponsoring_lord_disposition}
	if get_deed_count(inductee, sponsoring_lord.family) < INDUCTION_DEED_THRESHOLD:
		return {"eligible": false, "reason": "insufficient_deeds",
			"current": get_deed_count(inductee, sponsoring_lord.family)}
	if get_extraordinary_deed_count(inductee, sponsoring_lord.family) < INDUCTION_EXTRAORDINARY_DEED_REQUIRED:
		return {"eligible": false, "reason": "no_extraordinary_deed"}
	var approval_id: int = int(inductee.supply_ledger.get("family_daimyo_approval", -1))
	if approval_id < 0:
		return {"eligible": false, "reason": "no_family_daimyo_approval"}
	if inductee.clan == sponsoring_lord.clan:
		return {"eligible": false, "reason": "already_same_clan"}
	for ct: int in lords_known_crime_types:
		if ct == Enums.CrimeType.TREASON or ct == Enums.CrimeType.MAHO_USE \
				or ct == Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
			return {"eligible": false, "reason": "known_serious_crime"}
	return {"eligible": true}


## Perform the formal clan induction (s52.7 Part D).
## Caller is responsible for koku deduction, topic creation, and collective disposition.
static func perform_induction(
	inductee: L5RCharacterData,
	daimyo: L5RCharacterData,
) -> Dictionary:
	var old_clan: String = inductee.clan
	var old_family: String = inductee.family

	inductee.clan = daimyo.clan
	inductee.family = daimyo.family
	inductee.lord_id = daimyo.character_id
	inductee.role_position = "Samurai"
	if inductee.status < 1.0:
		HonorGlorySystem.apply_status_change(inductee, 1.0 - inductee.status)
	inductee.permanent_ronin = false

	HonorGlorySystem.apply_glory_change(inductee, INDUCTION_INDUCTEE_GLORY_GAIN)
	HonorGlorySystem.apply_glory_change(daimyo, INDUCTION_DAIMYO_GLORY_GAIN)

	# Clear deed credits and approval flag redeemed for this family.
	var deeds: Dictionary = inductee.supply_ledger.get("contract_deeds_for_family", {})
	deeds.erase(daimyo.family)
	inductee.supply_ledger["contract_deeds_for_family"] = deeds
	var extra: Dictionary = inductee.supply_ledger.get("extraordinary_deeds_for_family", {})
	extra.erase(daimyo.family)
	inductee.supply_ledger["extraordinary_deeds_for_family"] = extra
	inductee.supply_ledger.erase("family_daimyo_approval")
	inductee.supply_ledger.erase("contract_end_ic_day")
	inductee.supply_ledger.erase("contract_type")
	inductee.supply_ledger.erase("contract_duration_seasons")
	inductee.supply_ledger["former_ronin_inducted_by"] = daimyo.character_id

	return {
		"character_id": inductee.character_id,
		"daimyo_id": daimyo.character_id,
		"new_clan": inductee.clan,
		"new_family": inductee.family,
		"old_clan": old_clan,
		"old_family": old_family,
		"inductee_glory_gain": INDUCTION_INDUCTEE_GLORY_GAIN,
		"daimyo_glory_gain": INDUCTION_DAIMYO_GLORY_GAIN,
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
