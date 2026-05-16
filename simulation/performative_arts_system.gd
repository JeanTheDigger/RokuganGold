class_name PerformativeArtsSystem

enum ArtForm {
	POETRY,
	DANCE,
	THEATER,
	MUSIC,
	TEA_CEREMONY,
}

enum PerformanceOutcome {
	CRITICAL_FAILURE,
	FAILURE,
	SUCCESS,
	MASTERFUL,
}

const PERFORMANCE_TN: int = 15

const SUCCESS_DISPOSITION: int = 2
const SUCCESS_GLORY: float = 0.3
const MASTERFUL_GLORY: float = 0.2
const FAILURE_DISPOSITION: int = 0
const CRITICAL_FAILURE_DISPOSITION: int = -2
const CRITICAL_FAILURE_GLORY: float = -0.3
const CRITICAL_FAILURE_MARGIN: int = -10

const PERFORM_FOR_SUCCESS_DISPOSITION: int = 3
const PERFORM_FOR_FAILURE_DISPOSITION: int = -1

const FATIGUE_FULL: float = 1.0
const FATIGUE_HALF: float = 0.5
const FATIGUE_ZERO: float = 0.0

const ART_FORM_SKILLS: Dictionary = {
	ArtForm.POETRY: "Artisan",
	ArtForm.DANCE: "Perform",
	ArtForm.THEATER: "Acting",
	ArtForm.MUSIC: "Perform",
	ArtForm.TEA_CEREMONY: "Tea Ceremony",
}


static func get_performance_skill(art_form: ArtForm) -> String:
	return ART_FORM_SKILLS.get(art_form, "Perform")


static func resolve_public_performance(
	performer: L5RCharacterData,
	art_form: ArtForm,
	witness_ids: Array[int],
	dice_engine: DiceEngine,
	fatigue_count: int = 0,
) -> Dictionary:
	var skill_name: String = get_performance_skill(art_form)
	var skill_rank: int = performer.skills.get(skill_name, 0)
	var trait_val: int = performer.awareness

	if art_form == ArtForm.DANCE or art_form == ArtForm.MUSIC:
		trait_val = performer.agility
	if art_form == ArtForm.TEA_CEREMONY:
		trait_val = performer.void_ring

	var roll_k: int = trait_val
	var roll_r: int = skill_rank if skill_rank > 0 else 1

	var dice_result: DiceResult = dice_engine.roll_and_keep(roll_k, roll_r)
	var total: int = dice_result.total
	var margin: int = total - PERFORMANCE_TN

	var outcome: PerformanceOutcome
	var raises: int = 0
	if margin < CRITICAL_FAILURE_MARGIN:
		outcome = PerformanceOutcome.CRITICAL_FAILURE
	elif margin < 0:
		outcome = PerformanceOutcome.FAILURE
	else:
		raises = int(margin / 5)
		outcome = PerformanceOutcome.MASTERFUL if raises >= 3 else PerformanceOutcome.SUCCESS

	var fatigue_mult: float = get_fatigue_multiplier(fatigue_count)

	var disp_per_witness: int = 0
	var glory_change: float = 0.0
	match outcome:
		PerformanceOutcome.SUCCESS, PerformanceOutcome.MASTERFUL:
			disp_per_witness = SUCCESS_DISPOSITION + raises
			glory_change = SUCCESS_GLORY
			if outcome == PerformanceOutcome.MASTERFUL:
				glory_change += MASTERFUL_GLORY
		PerformanceOutcome.FAILURE:
			disp_per_witness = FAILURE_DISPOSITION
			glory_change = 0.0
		PerformanceOutcome.CRITICAL_FAILURE:
			disp_per_witness = CRITICAL_FAILURE_DISPOSITION
			glory_change = CRITICAL_FAILURE_GLORY

	disp_per_witness = int(float(disp_per_witness) * fatigue_mult)
	glory_change = glory_change * fatigue_mult

	var witness_effects: Array[Dictionary] = []
	for wid in witness_ids:
		witness_effects.append({
			"character_id": wid,
			"disposition_change": disp_per_witness,
		})

	return {
		"outcome": outcome,
		"roll_total": total,
		"margin": margin,
		"raises": raises,
		"glory_change": glory_change,
		"disposition_per_witness": disp_per_witness,
		"witness_effects": witness_effects,
		"fatigue_multiplier": fatigue_mult,
		"art_form": art_form,
		"skill_used": skill_name,
	}


static func resolve_perform_for(
	performer: L5RCharacterData,
	recipient: L5RCharacterData,
	art_form: ArtForm,
	dice_engine: DiceEngine,
) -> Dictionary:
	var skill_name: String = get_performance_skill(art_form)
	var skill_rank: int = performer.skills.get(skill_name, 0)
	var trait_val: int = performer.awareness

	if art_form == ArtForm.DANCE or art_form == ArtForm.MUSIC:
		trait_val = performer.agility
	if art_form == ArtForm.TEA_CEREMONY:
		trait_val = performer.void_ring

	var roll_k: int = trait_val
	var roll_r: int = skill_rank if skill_rank > 0 else 1

	var dice_result: DiceResult = dice_engine.roll_and_keep(roll_k, roll_r)
	var total: int = dice_result.total
	var margin: int = total - PERFORMANCE_TN

	var outcome: PerformanceOutcome
	var raises: int = 0
	if margin < 0:
		outcome = PerformanceOutcome.FAILURE
	else:
		raises = int(margin / 5)
		outcome = PerformanceOutcome.MASTERFUL if raises >= 3 else PerformanceOutcome.SUCCESS

	var disp_change: int = 0
	var glory_change: float = 0.0
	match outcome:
		PerformanceOutcome.SUCCESS, PerformanceOutcome.MASTERFUL:
			disp_change = PERFORM_FOR_SUCCESS_DISPOSITION + raises
			if outcome == PerformanceOutcome.MASTERFUL:
				glory_change = MASTERFUL_GLORY
		PerformanceOutcome.FAILURE:
			disp_change = PERFORM_FOR_FAILURE_DISPOSITION

	return {
		"outcome": outcome,
		"roll_total": total,
		"margin": margin,
		"raises": raises,
		"disposition_change": disp_change,
		"glory_change": glory_change,
		"recipient_id": recipient.character_id,
		"art_form": art_form,
		"skill_used": skill_name,
	}


static func get_fatigue_multiplier(performance_count: int) -> float:
	match performance_count:
		0:
			return FATIGUE_FULL
		1:
			return FATIGUE_HALF
		_:
			return FATIGUE_ZERO


static func get_best_art_form(performer: L5RCharacterData) -> ArtForm:
	var best_form: ArtForm = ArtForm.POETRY
	var best_rank: int = -1

	for form in ArtForm.values():
		var skill_name: String = get_performance_skill(form)
		var rank: int = performer.skills.get(skill_name, 0)

		var trait_val: int = performer.awareness
		if form == ArtForm.DANCE or form == ArtForm.MUSIC:
			trait_val = performer.agility
		if form == ArtForm.TEA_CEREMONY:
			trait_val = performer.void_ring

		var effective: int = rank + trait_val
		if effective > best_rank:
			best_rank = effective
			best_form = form

	return best_form


static func apply_performance_effects(
	performer: L5RCharacterData,
	result: Dictionary,
	characters_by_id: Dictionary = {},
) -> void:
	HonorGlorySystem.apply_glory_change(performer, result.get("glory_change", 0.0))

	if result.has("witness_effects"):
		for effect in result["witness_effects"]:
			var wid: int = effect.get("character_id", -1)
			var disp_delta: int = effect.get("disposition_change", 0)
			if wid >= 0 and disp_delta != 0:
				var witness: L5RCharacterData = characters_by_id.get(wid)
				if witness != null:
					var current: int = witness.disposition_values.get(performer.character_id, 0)
					witness.disposition_values[performer.character_id] = clampi(current + disp_delta, -100, 100)

	if result.has("disposition_change") and result.has("recipient_id"):
		var rid: int = result["recipient_id"]
		var disp_delta: int = result["disposition_change"]
		var recipient: L5RCharacterData = characters_by_id.get(rid)
		if recipient != null:
			var current: int = recipient.disposition_values.get(performer.character_id, 0)
			recipient.disposition_values[performer.character_id] = clampi(current + disp_delta, -100, 100)
