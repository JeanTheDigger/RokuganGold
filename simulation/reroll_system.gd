class_name RerollSystem
## Generic reroll charge system per GDD s29.15.24.
## Covers self-rerolls (Yasuki R2, Yoritomo R3, Kasuga R5) and
## granted rerolls (Ikoma R4, Shiba Advisor).
##
## Self-reroll: character's own technique charges. Fires when a skill
## check fails and an eligible entry has charges remaining.
## Granted reroll: ally-granted entry on the character's sheet. May add
## bonus dice. May carry a failure penalty on the grantor.


const REFRESH_WEEKLY: String = "weekly"


# -- Self-Reroll Entry Creation ------------------------------------------------

static func create_self_reroll_entry(
	source: String,
	eligible_skills: Array[String],
	charges_max: int,
	refresh: String = REFRESH_WEEKLY,
	skill_swap: String = "",
) -> Dictionary:
	return {
		"source": source,
		"eligible_skills": eligible_skills,
		"charges_current": charges_max,
		"charges_max": charges_max,
		"refresh": refresh,
		"skill_swap": skill_swap,
	}


# -- Granted Reroll Entry Creation ---------------------------------------------

static func create_granted_reroll_entry(
	source_id: int,
	source_technique: String,
	bonus_dice: int,
	bonus_type: String,
	uses: int,
	expires_ic_day: int,
	failure_penalty: Dictionary = {},
) -> Dictionary:
	return {
		"source_id": source_id,
		"source_technique": source_technique,
		"bonus_dice": bonus_dice,
		"bonus_type": bonus_type,
		"uses": uses,
		"expires": expires_ic_day,
		"failure_penalty": failure_penalty,
	}


# -- Self-Reroll: Check & Apply ------------------------------------------------

static func find_self_reroll(
	character: L5RCharacterData,
	skill_name: String,
) -> int:
	for i: int in range(character.self_reroll.size()):
		var entry: Dictionary = character.self_reroll[i]
		if entry.get("charges_current", 0) <= 0:
			continue
		var eligible: Array = entry.get("eligible_skills", [])
		if skill_name in eligible:
			return i
	return -1


static func apply_self_reroll(
	character: L5RCharacterData,
	entry_index: int,
	dice_engine: DiceEngine,
	skill_name: String,
	tn: int,
	raises: int = 0,
	emphasis_name: String = "",
	trait_override: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled: int = 0,
	bonus_kept: int = 0,
	flat_bonus: int = 0,
) -> Dictionary:
	var entry: Dictionary = character.self_reroll[entry_index]
	entry["charges_current"] = entry.get("charges_current", 1) - 1

	var swap: String = entry.get("skill_swap", "")
	var actual_skill: String = swap if not swap.is_empty() else skill_name

	var result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, actual_skill, tn, raises,
		emphasis_name, trait_override, bonus_rolled, bonus_kept, flat_bonus,
	)
	result["rerolled"] = true
	result["reroll_source"] = entry.get("source", "")
	if not swap.is_empty():
		result["skill_swapped_to"] = swap
	return result


static func try_self_reroll(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_name: String,
	tn: int,
	original_result: Dictionary,
	raises: int = 0,
	emphasis_name: String = "",
	trait_override: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled: int = 0,
	bonus_kept: int = 0,
	flat_bonus: int = 0,
) -> Dictionary:
	if original_result.get("success", false):
		return original_result

	var idx: int = find_self_reroll(character, skill_name)
	if idx < 0:
		return original_result

	return apply_self_reroll(
		character, idx, dice_engine, skill_name, tn, raises,
		emphasis_name, trait_override, bonus_rolled, bonus_kept, flat_bonus,
	)


# -- Granted Reroll: Check & Apply ---------------------------------------------

static func find_granted_reroll(
	character: L5RCharacterData,
	ic_day: int,
) -> int:
	for i: int in range(character.granted_reroll.size()):
		var entry: Dictionary = character.granted_reroll[i]
		if entry.get("uses", 0) <= 0:
			continue
		var expires: int = entry.get("expires", -1)
		if expires >= 0 and ic_day > expires:
			continue
		return i
	return -1


static func apply_granted_reroll(
	character: L5RCharacterData,
	entry_index: int,
	dice_engine: DiceEngine,
	skill_name: String,
	tn: int,
	raises: int = 0,
	emphasis_name: String = "",
	trait_override: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled: int = 0,
	bonus_kept: int = 0,
	flat_bonus: int = 0,
) -> Dictionary:
	var entry: Dictionary = character.granted_reroll[entry_index]
	entry["uses"] = entry.get("uses", 1) - 1

	var extra_rolled: int = 0
	var extra_kept: int = 0
	var bd: int = entry.get("bonus_dice", 0)
	if bd > 0:
		if entry.get("bonus_type", "unkept") == "kept":
			extra_kept = bd
		else:
			extra_rolled = bd

	var result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, skill_name, tn, raises,
		emphasis_name, trait_override,
		bonus_rolled + extra_rolled, bonus_kept + extra_kept, flat_bonus,
	)
	result["rerolled"] = true
	result["reroll_source"] = entry.get("source_technique", "")
	result["granted_by"] = entry.get("source_id", -1)

	if not result.get("success", false) and not entry.get("failure_penalty", {}).is_empty():
		result["failure_penalty"] = entry["failure_penalty"]

	return result


static func try_granted_reroll(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_name: String,
	tn: int,
	original_result: Dictionary,
	ic_day: int,
	raises: int = 0,
	emphasis_name: String = "",
	trait_override: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled: int = 0,
	bonus_kept: int = 0,
	flat_bonus: int = 0,
) -> Dictionary:
	if original_result.get("success", false):
		return original_result

	var idx: int = find_granted_reroll(character, ic_day)
	if idx < 0:
		return original_result

	return apply_granted_reroll(
		character, idx, dice_engine, skill_name, tn, raises,
		emphasis_name, trait_override, bonus_rolled, bonus_kept, flat_bonus,
	)


# -- Charge Refresh (Weekly Tick) ----------------------------------------------

static func refresh_weekly_charges(character: L5RCharacterData) -> int:
	var refreshed: int = 0
	for entry: Dictionary in character.self_reroll:
		if entry.get("refresh", "") == REFRESH_WEEKLY:
			var max_c: int = entry.get("charges_max", 0)
			if entry.get("charges_current", 0) < max_c:
				entry["charges_current"] = max_c
				refreshed += 1
	return refreshed


# -- Granted Reroll Expiry Cleanup ---------------------------------------------

static func expire_granted_rerolls(character: L5RCharacterData, ic_day: int) -> int:
	var removed: int = 0
	var i: int = character.granted_reroll.size() - 1
	while i >= 0:
		var entry: Dictionary = character.granted_reroll[i]
		var expires: int = entry.get("expires", -1)
		if expires >= 0 and ic_day > expires:
			character.granted_reroll.remove_at(i)
			removed += 1
		elif entry.get("uses", 0) <= 0:
			character.granted_reroll.remove_at(i)
			removed += 1
		i -= 1
	return removed
