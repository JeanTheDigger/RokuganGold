class_name PrimaryObjectiveDecomposer
## Decomposes completable primary objectives per GDD s55.28.
## Unlike standing objectives, these have clear done/not-done states.
## The decomposition fires fresh each AP, checks prerequisites, and returns
## whichever ImmediateNeed is appropriate at this moment.


const PRIMARY_OBJECTIVES: Array[String] = [
	"BREAK_ALLIANCE",
	"ISOLATE_CHARACTER",
	"GAIN_WINTER_COURT_INVITATION",
	"APPOINT_TO_POSITION",
	"REMOVE_FROM_POSITION",
	"RESOLVE_CLAN_WAR",
	"OBTAIN_IMPERIAL_EDICT",
	"EXPOSE_SECRET",
	"CONQUER_PROVINCE",
	"INCREASE_KOKU",
	"SABOTAGE_ECONOMY",
	"AVENGE",
]


static func is_primary_objective(need_type: String) -> bool:
	return need_type in PRIMARY_OBJECTIVES


static func decompose(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var need_type: String = objective.get("need_type", "")
	match need_type:
		"BREAK_ALLIANCE":
			return _decompose_break_alliance(objective, ctx)
		"ISOLATE_CHARACTER":
			return _decompose_isolate_character(objective, ctx)
		"GAIN_WINTER_COURT_INVITATION":
			return _decompose_gain_court_invitation(objective, ctx)
		"APPOINT_TO_POSITION":
			return _decompose_appoint_to_position(objective, ctx)
		"REMOVE_FROM_POSITION":
			return _decompose_remove_from_position(objective, ctx)
		"RESOLVE_CLAN_WAR":
			return _decompose_resolve_clan_war(objective, ctx)
		"OBTAIN_IMPERIAL_EDICT":
			return _decompose_obtain_imperial_edict(objective, ctx)
		"EXPOSE_SECRET":
			return _decompose_expose_secret(objective, ctx)
		"CONQUER_PROVINCE":
			return _decompose_conquer_province(objective, ctx)
		"INCREASE_KOKU":
			return _decompose_increase_koku(objective, ctx)
		"SABOTAGE_ECONOMY":
			return _decompose_sabotage_economy(objective, ctx)
		"AVENGE":
			return _decompose_avenge(objective, ctx)
	return null


# =============================================================================
# Political Primary Objectives (s55.28.1–55.28.8)
# =============================================================================


static func _decompose_break_alliance(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var clan_x: String = objective.get("target_clan_id", "")
	var clan_y: String = objective.get("target_clan_id_secondary", "")

	var contacts_x: Array = ctx.known_contacts_by_clan.get(clan_x, [])
	var contacts_y: Array = ctx.known_contacts_by_clan.get(clan_y, [])

	if contacts_x.is_empty() and contacts_y.is_empty():
		return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": clan_x})
	if contacts_x.is_empty():
		return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": clan_x})
	if contacts_y.is_empty():
		return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": clan_y})

	var anchor_x: int = _get_anchor(contacts_x)
	var anchor_y: int = _get_anchor(contacts_y)

	var disp_known: bool = _has_disposition_intel(ctx, anchor_x, anchor_y)
	if not disp_known:
		return _make_need("GATHER_INTELLIGENCE", 2, {"target_npc_id": anchor_x})

	var vulnerable: int = _pick_vulnerable_anchor(ctx, anchor_x, anchor_y)
	var other: int = anchor_y if vulnerable == anchor_x else anchor_x

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if _has_leverage_on(ctx, vulnerable):
				if other in ctx.characters_present:
					return _make_need("DAMAGE_RELATIONSHIP", 3, {
						"target_npc_id": vulnerable,
						"target_npc_id_secondary": other,
						"target_intent": "LEVERAGE_NEGATIVE",
					})
				return _make_need("SEND_LETTER", 2, {"target_npc_id": other})
			if vulnerable in ctx.characters_present:
				return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": vulnerable})
			if other in ctx.characters_present:
				return _make_need("DAMAGE_RELATIONSHIP", 2, {
					"target_npc_id": other,
					"target_npc_id_secondary": vulnerable,
					"target_intent": "TRIAGE_TARGET_NETWORK",
				})
			return _make_need("DAMAGE_RELATIONSHIP", 1, {"target_npc_id": vulnerable})
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if not _has_leverage_on(ctx, vulnerable):
				return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": vulnerable})
			return _court_or_alternative(ctx, vulnerable, 2)
		_:
			return _court_or_alternative(ctx, vulnerable, 1)


static func _decompose_isolate_character(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_id: int = objective.get("target_npc_id", -1)
	if target_id < 0:
		return _make_need("REST", 1)

	var known_allies: Array = _get_known_allies(ctx, target_id)
	if known_allies.is_empty():
		var has_fresh_intel: bool = _has_fresh_intel_on(ctx, target_id)
		if has_fresh_intel:
			return null
		return _make_need("GATHER_INTELLIGENCE", 2, {"target_npc_id": target_id})

	var weakest_ally: int = _find_weakest_ally(ctx, target_id, known_allies)

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if weakest_ally in ctx.characters_present:
				if _has_leverage_on(ctx, target_id):
					return _make_need("DAMAGE_RELATIONSHIP", 3, {
						"target_npc_id": weakest_ally,
						"target_npc_id_secondary": target_id,
					})
				return _make_need("PERSUADE", 2, {
					"target_npc_id": weakest_ally,
					"target_intent": "against_" + str(target_id),
				})
			return _make_need("GOSSIP", 2, {
				"target_npc_id": target_id,
			})
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("SEND_LETTER", 2, {"target_npc_id": weakest_ally})
		_:
			return _court_or_alternative(ctx, weakest_ally, 1)


static func _decompose_gain_court_invitation(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var lord_id: int = ctx.lord_id
	if lord_id < 0:
		lord_id = ctx.character_id

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if lord_id in ctx.characters_present:
				return _make_need("RAISE_DISPOSITION", 2, {"target_npc_id": lord_id})
			return _make_need("GATHER_INTELLIGENCE", 1)
		_:
			var court_need := _court_or_alternative(ctx, lord_id, 2)
			if court_need != null:
				return court_need
			return _make_need("SEND_LETTER", 2, {"target_npc_id": lord_id})


static func _decompose_appoint_to_position(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var candidate_id: int = objective.get("target_npc_id", -1)
	var appointing_authority: int = objective.get("authority_id", -1)

	if appointing_authority < 0:
		return _make_need("GATHER_INTELLIGENCE", 2)

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if appointing_authority in ctx.characters_present:
				return _make_need("PERSUADE", 3, {
					"target_npc_id": appointing_authority,
					"target_intent": "appoint_" + str(candidate_id),
				})
			return _make_need("MOVE_TOPIC_POSITION", 2)
		_:
			return _court_or_alternative(ctx, appointing_authority, 2)


static func _decompose_remove_from_position(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_id: int = objective.get("target_npc_id", -1)
	if target_id < 0:
		return _make_need("REST", 1)

	if _has_leverage_on(ctx, target_id):
		match ctx.context_flag:
			Enums.ContextFlag.AT_COURT:
				return _make_need("EXPOSE_SECRET_PUBLIC", 3, {"target_npc_id": target_id})
			_:
				return _court_or_alternative(ctx, target_id, 2)

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if target_id in ctx.characters_present:
				return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target_id})
			return _make_need("GATHER_INTELLIGENCE", 2, {"target_npc_id": target_id})
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target_id})
		_:
			return _court_or_alternative(ctx, target_id, 1)


static func _decompose_resolve_clan_war(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var enemy_clan: String = objective.get("target_clan_id", "")
	var contacts: Array = ctx.known_contacts_by_clan.get(enemy_clan, [])

	if contacts.is_empty():
		return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": enemy_clan})

	var negotiation_target: int = contacts[0] if not contacts.is_empty() else -1

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if negotiation_target in ctx.characters_present:
				return _make_need("NEGOTIATE", 3, {"target_npc_id": negotiation_target})
			return _make_need("MOVE_TOPIC_POSITION", 2)
		_:
			return _court_or_alternative(ctx, negotiation_target, 2)


static func _decompose_obtain_imperial_edict(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var emperor_id: int = objective.get("authority_id", -1)

	if emperor_id < 0:
		return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": "Imperial"})

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			if emperor_id in ctx.characters_present:
				return _make_need("PETITION", 3, {"target_npc_id": emperor_id})
			return _make_need("RAISE_DISPOSITION", 2, {"target_npc_id": emperor_id})
		_:
			return _court_or_alternative(ctx, emperor_id, 2)


static func _decompose_expose_secret(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_id: int = objective.get("target_npc_id", -1)
	if target_id < 0:
		return _make_need("REST", 1)

	if _has_leverage_on(ctx, target_id):
		match ctx.context_flag:
			Enums.ContextFlag.AT_COURT:
				return _make_need("EXPOSE_SECRET_PUBLIC", 3, {"target_npc_id": target_id})
			_:
				return _court_or_alternative(ctx, target_id, 3)

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target_id})
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target_id})
		_:
			return _court_or_alternative(ctx, target_id, 1)


# =============================================================================
# Military/Economic Primary Objectives (s55.28.9–55.28.11)
# =============================================================================


static func _decompose_conquer_province(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_province: int = objective.get("target_province_id", -1)

	if not ctx.is_lord:
		match ctx.context_flag:
			Enums.ContextFlag.ON_CAMPAIGN:
				return _make_need("FIGHT", 3)
			_:
				return _make_need("TRAIN_SKILL", 1)

	var war_active: bool = not ctx.active_wars.is_empty()
	if war_active:
		var readiness: float = _assess_military_readiness(ctx)
		if readiness >= 0.7:
			return _make_need("ORDER_BATTLE", 3, {"target_province_id": target_province})
		return _make_need("LEVY_TROOPS", 3)

	var readiness: float = _assess_military_readiness(ctx)
	if readiness < 0.5:
		return _make_need("LEVY_TROOPS", 2)
	return _make_need("DECLARE_WAR", 3, {"target_province_id": target_province})


static func _decompose_increase_koku(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_province: int = objective.get("target_province_id", -1)

	if not ctx.is_lord:
		match ctx.context_flag:
			Enums.ContextFlag.AT_OWN_HOLDINGS:
				return _make_need("CONDUCT_COMMERCE", 1)
			_:
				return _make_need("SEND_LETTER", 1, {"target_npc_id": ctx.lord_id})

	var ps: NPCDataStructures.ProvinceStatus = _get_province_status(ctx, target_province)
	if ps != null and ps.stability < 50.0:
		return _make_need("PATROL_PROVINCE", 2, {"target_province_id": target_province})

	if ps != null and ps.active_crisis_id >= 0:
		return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": target_province})

	return _make_need("ADJUST_TAX", 1, {"target_province_id": target_province})


static func _decompose_sabotage_economy(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_clan: String = objective.get("target_clan_id", "")
	var contacts: Array = ctx.known_contacts_by_clan.get(target_clan, [])

	if contacts.is_empty():
		return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": target_clan})

	var target_id: int = contacts[0]

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target_id})
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("INTERCEPT_LETTER", 2, {"target_npc_id": target_id})
		_:
			return _court_or_alternative(ctx, target_id, 1)


# =============================================================================
# Personal Primary Objective: Avenge (s55.28.12)
# =============================================================================


static func _decompose_avenge(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_id: int = objective.get("target_npc_id", -1)
	var variant: String = objective.get("variant", "death")

	if target_id < 0:
		return _make_need("GATHER_INTELLIGENCE", 2)

	if target_id in ctx.characters_present:
		if variant == "death":
			return _make_need("ISSUE_DUEL_CHALLENGE", 3, {"target_npc_id": target_id})
		return _make_need("EXPOSE_SECRET_PUBLIC", 3, {"target_npc_id": target_id})

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("GATHER_INTELLIGENCE", 2, {"target_npc_id": target_id})
		_:
			var court_need := _court_or_alternative(ctx, target_id, 2)
			if court_need != null:
				return court_need
			return _make_need("GATHER_INTELLIGENCE", 1, {"target_npc_id": target_id})


# =============================================================================
# Helper Functions
# =============================================================================


static func _make_need(
	need_type: String,
	priority: int,
	extras: Dictionary = {},
) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = need_type
	need.priority = priority
	need.source = "primary_decomposition"
	need.target_npc_id = extras.get("target_npc_id", -1)
	need.target_npc_id_secondary = extras.get("target_npc_id_secondary", -1)
	need.target_settlement_id = extras.get("target_settlement_id", -1)
	need.target_province_id = extras.get("target_province_id", -1)
	need.target_clan_id = extras.get("target_clan_id", "")
	need.target_topic_id = extras.get("target_topic_id", -1)
	need.target_resource = extras.get("target_resource", "")
	need.target_army_id = extras.get("target_army_id", -1)
	need.target_intent = extras.get("target_intent", "")
	need.threshold = extras.get("threshold", 0.0)
	need.threshold_type = extras.get("threshold_type", "")
	return need


static func _court_or_alternative(
	ctx: NPCDataStructures.ContextSnapshot,
	target_npc_id: int = -1,
	priority: int = 1,
) -> NPCDataStructures.ImmediateNeed:
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		ctx.active_court_at_location,
		ctx.upcoming_courts,
		_make_court_stub(ctx),
		target_npc_id,
		ctx.held_leverage,
		ctx.action_log,
		ctx.season,
		ctx.known_npc_locations,
	)
	if result == null:
		return null
	return _make_need(
		result.get("need_type", ""),
		maxi(result.get("priority", 1), priority),
		result,
	)


static func _make_court_stub(ctx: NPCDataStructures.ContextSnapshot) -> L5RCharacterData:
	var stub := L5RCharacterData.new()
	stub.character_id = ctx.character_id
	stub.lord_id = ctx.lord_id
	stub.operational_superior_id = -1
	return stub


static func _get_anchor(contacts: Array) -> int:
	if contacts.is_empty():
		return -1
	return contacts[0] if contacts[0] is int else -1


static func _has_disposition_intel(
	ctx: NPCDataStructures.ContextSnapshot,
	anchor_x: int,
	anchor_y: int,
) -> bool:
	for entry: KnowledgeEntry in ctx.knowledge_pool:
		if entry.entry_type == "disposition_observation":
			var tid: int = entry.data.get("target_character_id", entry.data.get("target_id", -1))
			if tid == anchor_x or tid == anchor_y:
				return true
	return false


static func _pick_vulnerable_anchor(
	ctx: NPCDataStructures.ContextSnapshot,
	anchor_x: int,
	anchor_y: int,
) -> int:
	var my_disp_x: float = ctx.disposition_values.get(anchor_x, 0.0)
	var my_disp_y: float = ctx.disposition_values.get(anchor_y, 0.0)
	if my_disp_y > my_disp_x:
		return anchor_y
	return anchor_x


static func _has_leverage_on(ctx: NPCDataStructures.ContextSnapshot, target_id: int) -> bool:
	for entry: Variant in ctx.held_leverage:
		if entry is Dictionary and entry.get("target_id", -1) == target_id:
			return true
	return false


static func _get_known_allies(
	ctx: NPCDataStructures.ContextSnapshot,
	target_id: int,
) -> Array:
	var allies: Array = []
	for entry: KnowledgeEntry in ctx.knowledge_pool:
		if entry.entry_type == "disposition_observation":
			var data: Dictionary = entry.data if entry.data is Dictionary else {}
			if data.get("observer_id", -1) == target_id and data.get("disposition", 0.0) >= 25.0:
				var ally_id: int = data.get("target_id", -1)
				if ally_id >= 0:
					allies.append(ally_id)
	return allies


static func _find_weakest_ally(
	ctx: NPCDataStructures.ContextSnapshot,
	_target_id: int,
	allies: Array,
) -> int:
	var weakest: int = -1
	var lowest_disp: float = 999.0
	for ally_id: Variant in allies:
		if not ally_id is int:
			continue
		var disp: float = ctx.disposition_values.get(ally_id, 0.0)
		if disp < lowest_disp:
			lowest_disp = disp
			weakest = ally_id
	if weakest < 0 and not allies.is_empty():
		weakest = allies[0]
	return weakest


static func _has_fresh_intel_on(ctx: NPCDataStructures.ContextSnapshot, target_id: int) -> bool:
	for entry: KnowledgeEntry in ctx.knowledge_pool:
		if entry.data is Dictionary and entry.data.get("target_id", -1) == target_id:
			if entry.confidence == Enums.KnowledgeConfidence.FRESH:
				return true
	return false


static func _get_province_status(
	ctx: NPCDataStructures.ContextSnapshot,
	province_id: int,
) -> NPCDataStructures.ProvinceStatus:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.province_id == province_id:
			return ps
	return null


static func _assess_military_readiness(ctx: NPCDataStructures.ContextSnapshot) -> float:
	if ctx.unit_training_counts.is_empty():
		return 0.5
	var total: int = 0
	var trained: int = 0
	for level: int in ctx.unit_training_counts:
		var count: int = ctx.unit_training_counts[level]
		total += count
		if level >= 3:
			trained += count
	if total == 0:
		return 0.5
	return float(trained) / float(total)
