class_name RoninSystem
## Ronin status transitions per GDD s52 Part 5.
## Handles conversion to/from ronin status, hiring, income tracking,
## and desperation escalation toward insurgency seeding.


enum RoninCause {
	LORD_DEATH_NO_HEIR,
	DISMISSAL,
	CLAN_DESTROYED,
	VOLUNTARY_DEPARTURE,
}

const RONIN_CLAN: String = "Ronin"
const SEASONS_BEFORE_DEBT: int = 4
const SEASONS_BEFORE_DESPERATE: int = 8
const HONOR_LOSS_ON_RONIN: float = 0.0
const HONOR_LOSS_VOLUNTARY: float = 0.0
const STIPEND_LOSS_HONOR_COST: float = 0.0
const HIRING_HONOR_RECOVERY: float = 0.0
const PETITION_TN: int = 0


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

	var honor_loss: float = HONOR_LOSS_VOLUNTARY if cause == RoninCause.VOLUNTARY_DEPARTURE else HONOR_LOSS_ON_RONIN
	HonorGlorySystem.apply_honor_change(character, -honor_loss)

	return {
		"character_id": character.character_id,
		"cause": cause,
		"old_clan": old_clan,
		"old_role": old_role,
		"old_lord_id": old_lord,
		"honor_loss": honor_loss,
	}


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


static func resolve_petition(
	character: L5RCharacterData,
	target_lord: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if character.permanent_ronin:
		return {"success": false, "rejected": true, "reason": "permanent_ronin", "character_id": character.character_id, "lord_id": target_lord.character_id}
	var tn: int = PETITION_TN

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
