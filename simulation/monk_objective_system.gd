class_name MonkObjectiveSystem
## Named monk standing objective assignment and decomposition per GDD s55.11b.
## Monks use existing NeedTypes and ActionIDs — no new engine components.
## Five standing objective types: HELP_PEOPLE, FIGHT_BANDITS, MEDITATE_DEEPLY,
## TRAIN_MASTERY, WORSHIP_KAMI.


const MONK_STANDING_OBJECTIVES: Array[String] = [
	"HELP_PEOPLE",
	"FIGHT_BANDITS",
	"MEDITATE_DEEPLY",
	"TRAIN_MASTERY",
	"WORSHIP_KAMI",
]

const SOHEI_SCHOOLS: Array[String] = [
	"Temple of Osano-Wo Monk",
	"Order of Rebirth",
	"Temple of Persistence",
	"Order of the Wind",
	"Tengoku's Fist",
	"Wind's Grace Order",
]

const CONTEMPLATIVE_SCHOOLS: Array[String] = [
	"Shrine of the Seven Thunders Monk",
	"Shinmaki Order",
	"Order of Eternity",
	"Order of the Nameless Gift",
	"Order of Peaceful Repose",
	"Fudoist Order",
]

const SOCIAL_SCHOOLS: Array[String] = [
	"Four Temples Monk",
	"Temple of Heavenly Wisdom",
	"Temple of Kaimetsu-uo Monk",
	"First Dawn Scholars",
	"Order of Five Rings",
	"Order of Heroes Monk",
]

const FORTUNIST_SCHOOLS: Array[String] = [
	"Temples of the Thousand Fortunes Monk",
	"Temple of Osano-Wo Monk",
	"Order of Rebirth",
	"Temple of Persistence",
	"Order of the Wind",
	"Order of Peaceful Repose",
	"Temple of Kaimetsu-uo Monk",
	"First Dawn Scholars",
	"Temple of Heavenly Wisdom",
]


static func is_monk(character: L5RCharacterData) -> bool:
	return character.school_type == Enums.SchoolType.MONK


static func is_monk_objective(need_type: String) -> bool:
	return need_type in MONK_STANDING_OBJECTIVES


static func assign_standing_objective(
	character: L5RCharacterData,
) -> Dictionary:
	if not is_monk(character):
		return {}

	var standing_type: String = _select_standing_type(character)
	return {
		"need_type": standing_type,
		"priority": 2,
		"auto_assigned": true,
		"monk_standing": true,
	}


static func _select_standing_type(character: L5RCharacterData) -> String:
	var school: String = character.school_name
	if school in SOHEI_SCHOOLS:
		return _sohei_standing(character)
	if school in CONTEMPLATIVE_SCHOOLS:
		return _contemplative_standing(character)
	if school in SOCIAL_SCHOOLS:
		return _social_standing(character)
	return _personality_fallback(character)


static func _sohei_standing(character: L5RCharacterData) -> String:
	match character.bushido_virtue:
		Enums.BushidoVirtue.JIN:
			return "HELP_PEOPLE"
		Enums.BushidoVirtue.GI:
			return "TRAIN_MASTERY"
	return "FIGHT_BANDITS"


static func _contemplative_standing(character: L5RCharacterData) -> String:
	match character.bushido_virtue:
		Enums.BushidoVirtue.YU:
			return "FIGHT_BANDITS"
		Enums.BushidoVirtue.JIN:
			return "HELP_PEOPLE"
	if character.school_name in FORTUNIST_SCHOOLS:
		if character.bushido_virtue in [Enums.BushidoVirtue.CHUGI, Enums.BushidoVirtue.REI]:
			return "WORSHIP_KAMI"
	return "MEDITATE_DEEPLY"


static func _social_standing(character: L5RCharacterData) -> String:
	match character.bushido_virtue:
		Enums.BushidoVirtue.YU:
			return "FIGHT_BANDITS"
		Enums.BushidoVirtue.MEIYO, Enums.BushidoVirtue.GI:
			return "TRAIN_MASTERY"
	if character.school_name in FORTUNIST_SCHOOLS:
		if character.bushido_virtue in [Enums.BushidoVirtue.CHUGI, Enums.BushidoVirtue.REI]:
			return "WORSHIP_KAMI"
	return "HELP_PEOPLE"


static func _personality_fallback(character: L5RCharacterData) -> String:
	match character.bushido_virtue:
		Enums.BushidoVirtue.JIN:
			return "HELP_PEOPLE"
		Enums.BushidoVirtue.YU:
			return "FIGHT_BANDITS"
		Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO:
			return "TRAIN_MASTERY"
		Enums.BushidoVirtue.CHUGI, Enums.BushidoVirtue.REI:
			return "WORSHIP_KAMI"
		Enums.BushidoVirtue.MAKOTO:
			return "MEDITATE_DEEPLY"
	return "MEDITATE_DEEPLY"


# -- Monk Self-Selection (parallel to lord strategic review self-selection) -----

static func select_primary_from_standing(
	character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Dictionary:
	var opportunities: Array = scan_monk_opportunities(character, standing_type, world_state)
	if opportunities.is_empty():
		return {}

	opportunities.sort_custom(func(a: OpportunityScanner.Opportunity, b: OpportunityScanner.Opportunity) -> bool:
		return a.get_score() > b.get_score()
	)

	var best: OpportunityScanner.Opportunity = opportunities[0]
	return {
		"need_type": best.objective_type,
		"objective_type": best.objective_type,
		"target_fields": best.target_fields,
		"score": best.get_score(),
		"source": "MONK_SELF_SELECTED",
	}


static func scan_monk_opportunities(
	character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	match standing_type:
		"HELP_PEOPLE":
			results.append_array(_scan_help_opportunities(character, world_state))
		"FIGHT_BANDITS":
			results.append_array(_scan_bandit_opportunities(character, world_state))
		"MEDITATE_DEEPLY":
			results.append_array(_scan_meditate_opportunities(character, world_state))
		"TRAIN_MASTERY":
			results.append_array(_scan_train_opportunities(character, world_state))
		"WORSHIP_KAMI":
			results.append_array(_scan_worship_opportunities(character, world_state))

	for opp: OpportunityScanner.Opportunity in results:
		opp.personality_fit = _compute_monk_personality_fit(character, opp)

	return results


static func _scan_help_opportunities(
	_character: L5RCharacterData,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	var famine_provinces: Array = world_state.get("famine_provinces", [])
	for prov: Dictionary in famine_provinces:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "RAISE_DISPOSITION"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 90.0
		opp.feasibility = 60.0
		opp.urgency = 90.0
		results.append(opp)

	var insurgent_provinces: Array = world_state.get("insurgent_provinces", [])
	for prov: Dictionary in insurgent_provinces:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "RAISE_DISPOSITION"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 70.0
		opp.feasibility = 65.0
		opp.urgency = prov.get("urgency", 60.0)
		results.append(opp)

	return results


static func _scan_bandit_opportunities(
	_character: L5RCharacterData,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	var insurgent_provinces: Array = world_state.get("insurgent_provinces", [])
	for prov: Dictionary in insurgent_provinces:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "PATROL_PROVINCE"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 90.0
		opp.feasibility = 75.0
		opp.urgency = prov.get("urgency", 60.0)
		results.append(opp)

	var tainted_provinces: Array = world_state.get("tainted_provinces", [])
	for prov: Dictionary in tainted_provinces:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "INVESTIGATE_THREAT"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 80.0
		opp.feasibility = 60.0
		opp.urgency = prov.get("urgency", 75.0)
		results.append(opp)

	return results


static func _scan_meditate_opportunities(
	_character: L5RCharacterData,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	var temples: Array = world_state.get("known_temples", [])
	for temple: Dictionary in temples:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "PERFORM_RITUAL"
		opp.target_fields = {"target_settlement_id": temple.get("settlement_id", -1)}
		opp.standing_alignment = 85.0
		opp.feasibility = 80.0
		opp.urgency = 20.0
		results.append(opp)

	if results.is_empty():
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "PERFORM_RITUAL"
		opp.target_fields = {}
		opp.standing_alignment = 70.0
		opp.feasibility = 90.0
		opp.urgency = 10.0
		results.append(opp)

	return results


static func _scan_train_opportunities(
	_character: L5RCharacterData,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	var dojos: Array = world_state.get("known_dojos", [])
	for dojo: Dictionary in dojos:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "TRAIN_SKILL"
		opp.target_fields = {"target_settlement_id": dojo.get("settlement_id", -1)}
		opp.standing_alignment = 85.0
		opp.feasibility = 80.0
		opp.urgency = 20.0
		results.append(opp)

	var opp := OpportunityScanner.Opportunity.new()
	opp.objective_type = "TRAIN_SKILL"
	opp.target_fields = {}
	opp.standing_alignment = 70.0
	opp.feasibility = 90.0
	opp.urgency = 10.0
	results.append(opp)

	return results


static func _scan_worship_opportunities(
	_character: L5RCharacterData,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	var temples: Array = world_state.get("known_temples", [])
	for temple: Dictionary in temples:
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "PERFORM_RITUAL"
		opp.target_fields = {"target_settlement_id": temple.get("settlement_id", -1)}
		opp.standing_alignment = 90.0
		opp.feasibility = 80.0
		opp.urgency = 30.0
		results.append(opp)

	if results.is_empty():
		var opp := OpportunityScanner.Opportunity.new()
		opp.objective_type = "PERFORM_RITUAL"
		opp.target_fields = {}
		opp.standing_alignment = 75.0
		opp.feasibility = 90.0
		opp.urgency = 15.0
		results.append(opp)

	return results


static func _compute_monk_personality_fit(
	character: L5RCharacterData,
	opp: OpportunityScanner.Opportunity,
) -> float:
	match opp.objective_type:
		"RAISE_DISPOSITION":
			if character.bushido_virtue == Enums.BushidoVirtue.JIN:
				return 90.0
			if character.bushido_virtue == Enums.BushidoVirtue.REI:
				return 80.0
		"PATROL_PROVINCE", "INVESTIGATE_THREAT":
			if character.bushido_virtue == Enums.BushidoVirtue.YU:
				return 90.0
			if character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
				return 80.0
		"PERFORM_RITUAL":
			if character.bushido_virtue in [Enums.BushidoVirtue.CHUGI, Enums.BushidoVirtue.REI]:
				return 85.0
			if character.bushido_virtue == Enums.BushidoVirtue.MAKOTO:
				return 80.0
		"TRAIN_SKILL":
			if character.bushido_virtue in [Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO]:
				return 85.0
	return 50.0


# -- Decomposition Trees -------------------------------------------------------

static func decompose(
	need_type: String,
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match need_type:
		"HELP_PEOPLE":
			return _decompose_help_people(ctx)
		"FIGHT_BANDITS":
			return _decompose_fight_bandits(ctx)
		"MEDITATE_DEEPLY":
			return _decompose_meditate_deeply(ctx)
		"TRAIN_MASTERY":
			return _decompose_train_mastery(ctx)
		"WORSHIP_KAMI":
			return _decompose_worship_kami(ctx)
	return null


static func _decompose_help_people(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.famine_crisis_province_ids.is_empty():
		var target_pid: int = ctx.famine_crisis_province_ids[0]
		if ctx.context_flag == Enums.ContextFlag.TRAVELING:
			return _make_need("RAISE_DISPOSITION", 2)
		return _make_need("RAISE_DISPOSITION", 2, {"target_province_id": target_pid, "target_intent": "famine_relief"})

	var worst: Dictionary = _find_worst_stability_province(ctx)
	if not worst.is_empty() and worst.get("stability", 100.0) < 60.0:
		if ctx.context_flag != Enums.ContextFlag.TRAVELING:
			return _make_need("RAISE_DISPOSITION", 2, {"target_province_id": worst.get("province_id", -1)})

	match ctx.context_flag:
		Enums.ContextFlag.AT_TEMPLE, Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("RAISE_DISPOSITION", 2)
		Enums.ContextFlag.AT_COURT:
			return _make_need("RAISE_DISPOSITION", 1)
		_:
			return _make_need("RAISE_DISPOSITION", 2)


static func _decompose_fight_bandits(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.active_insurgency_id >= 0:
		return _make_need("PATROL_PROVINCE", 2)

	for ps: NPCDataStructures.ProvinceStatus in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			if ps.insurgency_type == "RONIN_BANDIT" or ps.insurgency_type == "PEASANT_REVOLT" or ps.stability < 50.0:
				return _make_need("INVESTIGATE_THREAT", 2, {"target_province_id": ps.province_id})

	match ctx.context_flag:
		Enums.ContextFlag.AT_TEMPLE, Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("TRAIN_SKILL", 1)
		_:
			return _make_need("PATROL_PROVINCE", 1)


static func _decompose_meditate_deeply(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_TEMPLE:
			return _make_need("PERFORM_RITUAL", 3)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("PERFORM_RITUAL", 2)
		Enums.ContextFlag.AT_COURT:
			return _make_need("PERFORM_RITUAL", 1)
		_:
			return _make_need("PERFORM_RITUAL", 2)


static func _decompose_train_mastery(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_DOJO:
			return _make_need("TRAIN_SKILL", 3)
		Enums.ContextFlag.AT_TEMPLE, Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("TRAIN_SKILL", 2)
		_:
			return _make_need("TRAIN_SKILL", 1)


static func _decompose_worship_kami(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_TEMPLE:
			return _make_need("PERFORM_RITUAL", 3)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if ctx.zone_flags.get("shrine_eligible", false):
				return _make_need("PERFORM_RITUAL", 2)
			return _make_need("PERFORM_RITUAL", 1)
		Enums.ContextFlag.AT_COURT:
			return _make_need("PERFORM_RITUAL", 1)
		_:
			return _make_need("PERFORM_RITUAL", 2)


# -- Helpers ------------------------------------------------------------------

static func _make_need(
	need_type: String,
	priority: int,
	extras: Dictionary = {},
) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = need_type
	need.priority = priority
	need.source = "monk_decomposition"
	need.target_npc_id = extras.get("target_npc_id", -1)
	need.target_province_id = extras.get("target_province_id", -1)
	need.target_intent = extras.get("target_intent", "")
	return need


static func _find_worst_stability_province(
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var worst: Dictionary = {}
	var worst_stability: float = 100.0
	for ps: NPCDataStructures.ProvinceStatus in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			if ps.stability < worst_stability:
				worst_stability = ps.stability
				worst = {"province_id": ps.province_id, "stability": ps.stability}
	return worst
