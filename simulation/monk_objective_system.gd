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


static func is_monk(character: L5RCharacterData) -> bool:
	return character.school_type == Enums.SchoolType.MONK


static func is_monk_objective(need_type: String) -> bool:
	return need_type in MONK_STANDING_OBJECTIVES


static func is_combat_monk(character: L5RCharacterData) -> bool:
	var school: String = character.school
	return school.begins_with("Sohei") or school.begins_with("Yamabushi")


static func assign_standing_objective(
	character: L5RCharacterData,
) -> Dictionary:
	if not is_monk(character):
		return {}

	if is_combat_monk(character):
		return {"need_type": "FIGHT_BANDITS", "priority": 2}

	var virtue: int = character.bushido_virtue
	match virtue:
		Enums.BushidoVirtue.JIN:
			return {"need_type": "HELP_PEOPLE", "priority": 2}
		Enums.BushidoVirtue.CHUGI:
			return {"need_type": "WORSHIP_KAMI", "priority": 2}
		Enums.BushidoVirtue.REI:
			return {"need_type": "WORSHIP_KAMI", "priority": 2}
		Enums.BushidoVirtue.GI:
			return {"need_type": "TRAIN_MASTERY", "priority": 2}
		Enums.BushidoVirtue.MAKOTO:
			return {"need_type": "MEDITATE_DEEPLY", "priority": 2}
		Enums.BushidoVirtue.MEIYO:
			return {"need_type": "TRAIN_MASTERY", "priority": 2}
		Enums.BushidoVirtue.YU:
			return {"need_type": "FIGHT_BANDITS", "priority": 2}

	return {"need_type": "MEDITATE_DEEPLY", "priority": 2}


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
		Enums.ContextFlag.TRAVELING:
			return _make_need("RAISE_DISPOSITION", 2)
		_:
			return _make_need("RAISE_DISPOSITION", 2)


static func _decompose_fight_bandits(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.active_insurgency_id >= 0:
		return _make_need("PATROL_PROVINCE", 2)

	for ps in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			if ps.crisis_type == "bandit" or ps.crisis_type == "ronin" or ps.stability < 50.0:
				return _make_need("INVESTIGATE_THREAT", 2, {"target_province_id": ps.province_id})

	match ctx.context_flag:
		Enums.ContextFlag.TRAVELING:
			return _make_need("PATROL_PROVINCE", 1)
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
		Enums.ContextFlag.TRAVELING:
			return _make_need("PERFORM_RITUAL", 1)
		_:
			return _make_need("PERFORM_RITUAL", 2)


static func _decompose_train_mastery(
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_DOJO:
			return _make_need("TRAIN_SKILL", 3)
		Enums.ContextFlag.AT_TEMPLE:
			return _make_need("TRAIN_SKILL", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("TRAIN_SKILL", 2)
		Enums.ContextFlag.TRAVELING:
			return _make_need("TRAIN_SKILL", 1)
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
		Enums.ContextFlag.TRAVELING:
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
	for ps in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			if ps.stability < worst_stability:
				worst_stability = ps.stability
				worst = {"province_id": ps.province_id, "stability": ps.stability}
	return worst
