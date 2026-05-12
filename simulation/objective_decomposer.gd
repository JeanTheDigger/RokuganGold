class_name ObjectiveDecomposer
## Objective decomposition functions per GDD s55.22 (political), s55.24 (economic),
## s55.25 (personal). Routes standing objectives to type-specific decomposition
## trees that examine ContextSnapshot and return the most productive ImmediateNeed
## for the current AP. Stateless — fires fresh every AP per GDD s55.4.2.


# -- Standing Objective NeedType Constants ------------------------------------

const POLITICAL_OBJECTIVES: Array[String] = [
	"EXPAND_TERRITORY",
	"MAINTAIN_BALANCE",
	"ADVANCE_FAMILY",
	"UNDERMINE_CLAN",
	"STRENGTHEN_IMPERIAL",
	"ACCUMULATE_LEVERAGE",
]

const ECONOMIC_OBJECTIVES: Array[String] = [
	"MAXIMIZE_PROSPERITY",
	"CONTROL_TRADE",
	"PREVENT_SHORTAGE",
	"ACCUMULATE_WEALTH",
	"GROW_COMMERCE",
]

const PERSONAL_OBJECTIVES: Array[String] = [
	"HONOR_ANCESTORS",
	"PROTECT_DEPENDENTS",
	"ACCUMULATE_KNOWLEDGE",
	"PERSONAL_EXCELLENCE",
	"ELEVATE_FAMILY",
	"LIVE_BY_BUSHIDO",
	"ADVANCE_GLORY",
	"SEEK_VENGEANCE",
]

const MILITARY_OBJECTIVES: Array[String] = [
	"DEFEND_TERRITORY",
	"STRENGTHEN_FORTIFICATION",
	"STRENGTHEN_WALL",
	"MILITARY_DOMINANCE",
	"ELIMINATE_SHADOWLANDS",
	"MAINTAIN_PEACE",
	"BUILD_STRONGEST_FORCE",
]

const INVESTIGATION_OBJECTIVES: Array[String] = [
	"INVESTIGATE_CRIME",
	"UPHOLD_LAW",
]


# -- Main Entry Point ---------------------------------------------------------

static func decompose(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var need_type: String = objective.get("need_type", "")
	if need_type.is_empty():
		return null

	if PrimaryObjectiveDecomposer.is_primary_objective(need_type):
		return PrimaryObjectiveDecomposer.decompose(objective, ctx)
	if MushaShugyo.is_seek_experience(need_type):
		return MushaShugyo.decompose(objective, ctx, ctx.school_type)
	if MonkObjectiveSystem.is_monk_objective(need_type):
		return MonkObjectiveSystem.decompose(need_type, objective, ctx)
	if need_type in POLITICAL_OBJECTIVES:
		return _decompose_political(need_type, objective, ctx)
	if need_type in ECONOMIC_OBJECTIVES:
		return _decompose_economic(need_type, objective, ctx)
	if need_type in PERSONAL_OBJECTIVES:
		return _decompose_personal(need_type, objective, ctx)
	if need_type in MILITARY_OBJECTIVES:
		return _decompose_military(need_type, objective, ctx)
	if need_type in INVESTIGATION_OBJECTIVES:
		return _decompose_investigation(need_type, objective, ctx)

	return _passthrough(objective)


# -- Political Routing --------------------------------------------------------

static func _decompose_political(
	need_type: String,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match need_type:
		"EXPAND_TERRITORY":
			return _decompose_expand_territory(objective, ctx)
		"MAINTAIN_BALANCE":
			return _decompose_maintain_balance(objective, ctx)
		"ADVANCE_FAMILY":
			return _decompose_advance_family(objective, ctx)
		"UNDERMINE_CLAN":
			return _decompose_undermine_clan(objective, ctx)
		"STRENGTHEN_IMPERIAL":
			return _decompose_strengthen_imperial(objective, ctx)
		"ACCUMULATE_LEVERAGE":
			return _decompose_accumulate_leverage(objective, ctx)
	return _passthrough(objective)


# -- Economic Routing ---------------------------------------------------------

static func _decompose_economic(
	need_type: String,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match need_type:
		"MAXIMIZE_PROSPERITY":
			return _decompose_maximize_prosperity(objective, ctx)
		"CONTROL_TRADE":
			return _decompose_control_trade(objective, ctx)
		"PREVENT_SHORTAGE":
			return _decompose_prevent_shortage(objective, ctx)
		"ACCUMULATE_WEALTH":
			return _decompose_accumulate_wealth(objective, ctx)
		"GROW_COMMERCE":
			return _decompose_grow_commerce(objective, ctx)
	return _passthrough(objective)


# -- Personal Routing ---------------------------------------------------------

static func _decompose_personal(
	need_type: String,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match need_type:
		"HONOR_ANCESTORS":
			return _decompose_honor_ancestors(objective, ctx)
		"PROTECT_DEPENDENTS":
			return _decompose_protect_dependents(objective, ctx)
		"ACCUMULATE_KNOWLEDGE":
			return _decompose_accumulate_knowledge(objective, ctx)
		"PERSONAL_EXCELLENCE":
			return _decompose_personal_excellence(objective, ctx)
		"ELEVATE_FAMILY":
			return _decompose_advance_family(objective, ctx)
		"LIVE_BY_BUSHIDO":
			return _decompose_live_by_bushido(objective, ctx)
		"ADVANCE_GLORY":
			return _decompose_advance_glory(objective, ctx)
		"SEEK_VENGEANCE":
			return _decompose_seek_vengeance(objective, ctx)
	return _passthrough(objective)


# -- Military Routing ---------------------------------------------------------

static func _decompose_military(
	need_type: String,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match need_type:
		"DEFEND_TERRITORY":
			return _decompose_defend_territory(objective, ctx)
		"STRENGTHEN_FORTIFICATION":
			return _decompose_strengthen_fortification(objective, ctx)
		"STRENGTHEN_WALL":
			return _decompose_strengthen_wall(objective, ctx)
		"MILITARY_DOMINANCE":
			return _decompose_military_dominance(objective, ctx)
		"ELIMINATE_SHADOWLANDS":
			return _decompose_eliminate_shadowlands(objective, ctx)
		"MAINTAIN_PEACE":
			return _decompose_maintain_peace(objective, ctx)
		"BUILD_STRONGEST_FORCE":
			return _decompose_build_strongest_force(objective, ctx)
	return _passthrough(objective)


# -- Investigation Routing (GDD s57.16) ----------------------------------------

static func _decompose_investigation(
	need_type: String,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if need_type == "UPHOLD_LAW":
		var case_data: Dictionary = objective.get("active_case", {})
		if case_data.is_empty():
			return _passthrough(objective)
		return InvestigationDecomposer.decompose(case_data, ctx)
	return InvestigationDecomposer.decompose(objective, ctx)


# =============================================================================
# Political Decomposition Trees (GDD s55.22)
# =============================================================================


static func _decompose_expand_territory(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		return _courtier_diplomatic_path(objective, ctx)

	var weak_province_id: int = _find_weak_neighbor_province(ctx)
	if weak_province_id >= 0:
		var ps: Variant = _get_province_status(ctx, weak_province_id)
		if ps == null or (ps is NPCDataStructures.ProvinceStatus and ps.confidence == 0):
			return _make_need("GATHER_INTELLIGENCE", 2, {"target_province_id": weak_province_id})
		return _make_need("INITIATE_WAR_CHECK", 2, {
			"target_province_id": weak_province_id,
			"target_clan_id": objective.get("target_clan_id", ""),
			"target_intent": "EXPAND_TERRITORY",
		})

	return _courtier_diplomatic_path(objective, ctx)


static func _decompose_maintain_balance(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_contact_needing_disposition(ctx, 31)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 2, {
					"target_npc_id": contact,
					"threshold": 31.0,
					"threshold_type": "disposition",
				})
			return _make_need("MOVE_TOPIC_POSITION", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_advance_family(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_contact_needing_disposition(ctx, 31)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 2, {
					"target_npc_id": contact,
					"threshold": 31.0,
					"threshold_type": "disposition",
				})
			return _make_need("SEEK_GLORY", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if ctx.is_lord:
				var crisis: int = _find_crisis_province(ctx)
				if crisis >= 0:
					return _make_need("DEFEND_PROVINCE", 2, {"target_province_id": crisis})
				var marriage_need: Variant = _try_arrange_marriage(ctx, 2, "ADVANCE_FAMILY")
				if marriage_need != null:
					return marriage_need
				var weak: int = _find_weak_neighbor_province(ctx)
				if weak >= 0:
					return _make_need("INITIATE_WAR_CHECK", 1, {
						"target_province_id": weak,
						"target_intent": "ADVANCE_FAMILY",
					})
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_undermine_clan(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_clan: String = objective.get("target_clan_id", "")

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var target_contact: int = _find_clan_contact_present(ctx, target_clan)
			if target_contact >= 0:
				return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target_contact})
			if target_clan.is_empty():
				return _make_need("IDENTIFY_CONTACT", 2)
			return _make_need("DAMAGE_RELATIONSHIP", 2, {"target_clan_id": target_clan})
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if ctx.is_lord and not target_clan.is_empty():
				var weak: int = _find_weak_neighbor_province_for_clan(ctx, target_clan)
				if weak >= 0:
					return _make_need("INITIATE_WAR_CHECK", 2, {
						"target_province_id": weak,
						"target_clan_id": target_clan,
						"target_intent": "UNDERMINE_CLAN",
					})
			return _make_need("ACQUIRE_LEVERAGE", 2, {"target_clan_id": target_clan})
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_strengthen_imperial(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_contact_needing_disposition(ctx, 31)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 2, {
					"target_npc_id": contact,
					"threshold": 31.0,
					"threshold_type": "disposition",
				})
			return _make_need("MOVE_TOPIC_POSITION", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_accumulate_leverage(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var friend_count: int = _count_friends(ctx.dispositions, 31)
			if friend_count < 3:
				var contact: int = _find_contact_needing_disposition(ctx, 31)
				if contact >= 0:
					return _make_need("RAISE_DISPOSITION", 2, {
						"target_npc_id": contact,
						"threshold": 31.0,
						"threshold_type": "disposition",
					})
				return _make_need("IDENTIFY_CONTACT", 1)
			var target: int = _find_highest_status_present(ctx)
			if target >= 0:
				return _make_need("ACQUIRE_LEVERAGE", 2, {"target_npc_id": target})
			return _make_need("GATHER_INTELLIGENCE", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			var marriage_need: Variant = _try_arrange_marriage(ctx, 1, "ACCUMULATE_LEVERAGE")
			if marriage_need != null:
				return marriage_need
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


# =============================================================================
# Economic Decomposition Trees (GDD s55.24)
# =============================================================================


static func _decompose_maximize_prosperity(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		match ctx.context_flag:
			Enums.ContextFlag.AT_COURT:
				return _make_need("MOVE_TOPIC_POSITION", 1)
			_:
				var _court_need := _court_or_alternative(ctx)
				if _court_need != null:
					return _court_need
				return _make_need("REST", 1)

	if not ctx.famine_crisis_province_ids.is_empty() and _get_rice_per_pu(ctx) >= 2.0:
		return _make_need("CONDUCT_COMMERCE", 2, {
			"target_province_id": ctx.famine_crisis_province_ids[0],
			"target_intent": "famine_relief",
		})

	var triage: ProvinceTriage.TriageResult = ProvinceTriage.get_worst_province(
		ctx.province_statuses
	)
	if triage.score > 0.0 and triage.province_id >= 0:
		return _make_need(triage.recommended_need, triage.priority, {
			"target_province_id": triage.province_id,
		})

	var rice_per_pu: float = _get_rice_per_pu(ctx)
	if rice_per_pu < 2.0:
		return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "rice"})

	return _make_need("ADJUST_TAX", 1)


static func _decompose_control_trade(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.is_lord:
		var undergarrisoned: int = _find_undergarrisoned_province(ctx)
		if undergarrisoned >= 0:
			return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": undergarrisoned})

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_contact_needing_disposition(ctx, 31)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 2, {
					"target_npc_id": contact,
					"threshold": 31.0,
					"threshold_type": "disposition",
				})
			return _make_need("MOVE_TOPIC_POSITION", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_prevent_shortage(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		return _make_need("SEND_LETTER", 1)

	var rice_stockpile: float = ctx.resource_stockpiles.get("rice", 0.0)
	var consumption: float = ctx.resource_stockpiles.get("rice_consumption", 1.0)
	var seasons_of_rice: float = rice_stockpile / maxf(consumption, 0.01)

	if seasons_of_rice < 1.0:
		var weak: int = _find_weak_neighbor_province(ctx)
		if weak >= 0:
			return _make_need("INITIATE_WAR_CHECK", 3, {
				"target_province_id": weak,
				"target_intent": "PREVENT_SHORTAGE",
			})
		return _make_need("ACQUIRE_RESOURCE", 3, {"target_resource": "rice"})
	if seasons_of_rice < 2.0:
		return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "rice"})

	var arms: float = ctx.resource_stockpiles.get("arms", 0.0)
	var arms_upkeep: float = ctx.resource_stockpiles.get("arms_upkeep", 0.01)
	if arms / maxf(arms_upkeep, 0.01) < 2.0:
		return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "arms"})

	var iron: float = ctx.resource_stockpiles.get("iron", 0.0)
	if iron < 3.0:
		return _make_need("ACQUIRE_RESOURCE", 1, {"target_resource": "iron"})

	var koku: float = ctx.resource_stockpiles.get("koku", 0.0)
	if koku < 5.0:
		return _make_need("ADJUST_TAX", 1)

	return _make_need("REST", 1)


static func _decompose_accumulate_wealth(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		match ctx.context_flag:
			Enums.ContextFlag.AT_COURT:
				return _make_need("SEEK_GLORY", 1)
			_:
				return _make_need("TRAIN_SKILL", 1)

	var undergarrisoned: int = _find_undergarrisoned_province(ctx)
	if undergarrisoned >= 0:
		return _make_need("DEFEND_PROVINCE", 2, {"target_province_id": undergarrisoned})

	return _make_need("ADJUST_TAX", 1)


static func _decompose_grow_commerce(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.ContextFlag.VISITING:
			return _make_need("CONDUCT_COMMERCE", 2)
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_contact_needing_disposition(ctx, 31)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 1, {"target_npc_id": contact})
			return _make_need("CONDUCT_COMMERCE", 1)
		_:
			return _make_need("TRAIN_SKILL", 1)


# =============================================================================
# Personal Decomposition Trees (GDD s55.25)
# =============================================================================


static func _decompose_honor_ancestors(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("SEEK_GLORY", 2)
		Enums.ContextFlag.AT_TEMPLE:
			return _make_need("PERFORM_RITUAL", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if ctx.is_lord:
				var crisis: int = _find_crisis_province(ctx)
				if crisis >= 0:
					return _make_need("DEFEND_PROVINCE", 2, {"target_province_id": crisis})
				if not ctx.active_wars.is_empty() or not ctx.escalating_conflicts.is_empty():
					var weak: int = _find_weak_neighbor_province(ctx)
					if weak >= 0:
						return _make_need("INITIATE_WAR_CHECK", 2, {
							"target_province_id": weak,
							"target_intent": "HONOR_ANCESTORS",
						})
			return _make_need("TRAIN_SKILL", 1)
		Enums.ContextFlag.ON_CAMPAIGN:
			return _make_need("REST", 1)
		_:
			return _make_need("SEEK_GLORY", 1)


static func _decompose_protect_dependents(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.is_lord:
		var crisis: int = _find_crisis_province(ctx)
		if crisis >= 0:
			return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": crisis})

		var undergarrisoned: int = _find_undergarrisoned_province(ctx)
		if undergarrisoned >= 0:
			return _make_need("DEFEND_PROVINCE", 2, {"target_province_id": undergarrisoned})

		var unstable: int = _find_unstable_province(ctx, 75)
		if unstable >= 0:
			return _make_need("PATROL_PROVINCE", 2, {"target_province_id": unstable})

		var rice_per_pu: float = _get_rice_per_pu(ctx)
		if rice_per_pu < 2.0:
			return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "rice"})

	var contact: int = _find_contact_needing_disposition(ctx, 31)
	if contact >= 0:
		return _make_need("RAISE_DISPOSITION", 1, {"target_npc_id": contact})
	return _make_need("REST", 1)


static func _decompose_accumulate_knowledge(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("GATHER_INTELLIGENCE", 2)
		Enums.ContextFlag.AT_TEMPLE:
			if ctx.school_type == Enums.SchoolType.SHUGENJA:
				return _make_need("INVESTIGATE_THREAT", 2)
			return _make_need("PERFORM_RITUAL", 1)
		Enums.ContextFlag.AT_DOJO:
			return _make_need("TRAIN_SKILL", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("TRAIN_SKILL", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_personal_excellence(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_DOJO:
			return _make_need("TRAIN_SKILL", 3)
		Enums.ContextFlag.AT_COURT:
			if ctx.school_type == Enums.SchoolType.COURTIER:
				return _make_need("SEEK_GLORY", 2)
			if ctx.school_type == Enums.SchoolType.BUSHI:
				return _make_need("TRAIN_SKILL", 1)
			return _make_need("PERFORM_RITUAL", 1)
		Enums.ContextFlag.AT_TEMPLE:
			if ctx.school_type == Enums.SchoolType.SHUGENJA or ctx.school_type == Enums.SchoolType.MONK:
				return _make_need("PERFORM_RITUAL", 3)
			return _make_need("PERFORM_RITUAL", 1)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("TRAIN_SKILL", 2)
		_:
			return _make_need("TRAIN_SKILL", 1)


static func _decompose_live_by_bushido(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.honor < 3.0:
		return _make_need("RESTORE_HONOR", 2)

	match ctx.context_flag:
		Enums.ContextFlag.AT_TEMPLE:
			return _make_need("PERFORM_RITUAL", 2)
		Enums.ContextFlag.AT_COURT:
			return _make_need("SEEK_GLORY", 1)
		_:
			return _make_need("TRAIN_SKILL", 1)


static func _decompose_advance_glory(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("SEEK_GLORY", 2)
		Enums.ContextFlag.ON_CAMPAIGN:
			return _make_need("REST", 1)
		Enums.ContextFlag.UNDER_SIEGE:
			return _make_need("CONDUCT_SORTIE", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if ctx.is_lord and ctx.school_type == Enums.SchoolType.BUSHI:
				var weak: int = _find_weak_neighbor_province(ctx)
				if weak >= 0:
					return _make_need("INITIATE_WAR_CHECK", 1, {
						"target_province_id": weak,
						"target_intent": "ADVANCE_GLORY",
					})
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)
		_:
			return _make_need("TRAIN_SKILL", 1)


static func _decompose_seek_vengeance(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var target_npc: int = objective.get("target_npc_id", -1)
	var target_clan: String = objective.get("target_clan_id", "")

	if target_npc < 0 and not target_clan.is_empty():
		var clan_contact: int = _find_clan_contact_present(ctx, target_clan)
		if clan_contact >= 0:
			target_npc = clan_contact
		else:
			return _make_need("IDENTIFY_CONTACT", 2, {"target_clan_id": target_clan})

	if target_npc < 0:
		return _make_need("GATHER_INTELLIGENCE", 1)

	if target_npc in ctx.characters_present:
		return _make_need("ISSUE_DUEL_CHALLENGE", 3, {"target_npc_id": target_npc})

	if ctx.is_lord and not target_clan.is_empty() and target_clan != ctx.clan:
		if ctx.context_flag == Enums.ContextFlag.AT_OWN_HOLDINGS:
			var weak: int = _find_weak_neighbor_province_for_clan(ctx, target_clan)
			if weak >= 0:
				return _make_need("INITIATE_WAR_CHECK", 2, {
					"target_province_id": weak,
					"target_clan_id": target_clan,
					"target_intent": "SEEK_VENGEANCE",
				})

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("GATHER_INTELLIGENCE", 2, {"target_npc_id": target_npc})
		_:
			var _court_need := _court_or_alternative(ctx, target_npc, 2)
			if _court_need != null:
				return _court_need
			return _make_need("GATHER_INTELLIGENCE", 1, {"target_npc_id": target_npc})


# =============================================================================
# Military Decomposition Trees (GDD s55.23)
# =============================================================================


static func _decompose_defend_territory(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		match ctx.context_flag:
			Enums.ContextFlag.ON_CAMPAIGN:
				return _make_need("REST", 1)
			_:
				return _make_need("TRAIN_SKILL", 1)

	var triage_mil: ProvinceTriage.TriageResult = ProvinceTriage.get_worst_province(
		ctx.province_statuses
	)
	if triage_mil.score > 0.0 and triage_mil.province_id >= 0:
		return _make_need(triage_mil.recommended_need, triage_mil.priority, {
			"target_province_id": triage_mil.province_id,
		})

	return _make_need("EVALUATE_WAR_READINESS", 1)


static func _decompose_strengthen_fortification(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		return _make_need("TRAIN_SKILL", 1)

	var crisis: int = _find_crisis_province(ctx)
	if crisis >= 0:
		return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": crisis})

	return _make_need("MAINTAIN_FORTIFICATION", 2)


static func _decompose_strengthen_wall(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		match ctx.context_flag:
			Enums.ContextFlag.AT_COURT:
				return _make_need("MOVE_TOPIC_POSITION", 2)
			Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.ContextFlag.ON_CAMPAIGN:
				var wall_province: int = _find_wall_province(ctx)
				if wall_province >= 0:
					return _make_need("PATROL_PROVINCE", 2, {"target_province_id": wall_province})
				return _make_need("TRAIN_SKILL", 1)
			_:
				return _make_need("TRAIN_SKILL", 1)

	# Branch A: Lord-tier wall management
	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		var ps: NPCDataStructures.ProvinceStatus = _get_province_status(ctx, w.province_id)
		if ps != null and ps.confidence == 0:
			return _make_need("INVESTIGATE_THREAT", 3, {"target_province_id": w.province_id})

	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		var ps: NPCDataStructures.ProvinceStatus = _get_province_status(ctx, w.province_id)
		if ps != null and ps.garrison_pu < w.minimum_garrison:
			return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": w.province_id})

	var crisis: int = _find_crisis_province(ctx)
	if crisis >= 0:
		return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": crisis})

	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		if not w.scout_deployed or w.scout_report_age > 1:
			return _make_need("DEPLOY_SCOUTS", 3, {"target_province_id": w.province_id})

	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		if w.si < 6:
			return _make_need("MAINTAIN_FORTIFICATION", 3, {"target_province_id": w.province_id})

	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		if w.max_taint_rank >= 3 or w.tea_stockpile_seasons < 1.0:
			return _make_need("MANAGE_TAINT", 3, {"target_province_id": w.province_id})

	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		if w.jade_stockpile_critical:
			return _make_need("ACQUIRE_RESOURCE", 3, {
				"target_resource": "jade",
				"target_province_id": w.province_id,
			})

	for ws: Variant in ctx.wall_statuses:
		if not ws is NPCDataStructures.WallStatus:
			continue
		var w: NPCDataStructures.WallStatus = ws as NPCDataStructures.WallStatus
		if w.scout_report_elevated_activity and w.scout_report_age <= 1:
			if not w.jade_stockpile_critical and w.garrison_above_minimum and w.si >= 6:
				return _make_need("ORDER_SHADOWLANDS_SORTIE", 2, {
					"target_province_id": w.province_id,
				})

	if _has_undertrained_units(ctx, 3):
		return _make_need("TRAIN_TROOPS", 2)

	var arms: float = ctx.resource_stockpiles.get("arms", 0.0)
	if arms < 10.0:
		return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "arms"})

	var iron: float = ctx.resource_stockpiles.get("iron", 0.0)
	if iron < 5.0:
		return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "iron"})

	return _make_need("LEVY_TROOPS", 1)


static func _decompose_military_dominance(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.known_clan_strengths.is_empty():
		if ctx.is_lord:
			return _make_need("SEND_LETTER", 1)
		return _make_need("GATHER_INTELLIGENCE", 2)

	var my_strength: float = ctx.known_clan_strengths.get(ctx.clan, 0.0)
	var strongest_rival: float = 0.0
	for clan_id: String in ctx.known_clan_strengths:
		if clan_id != ctx.clan:
			var rival_str: float = ctx.known_clan_strengths.get(clan_id, 0.0)
			if rival_str > strongest_rival:
				strongest_rival = rival_str

	var dominance_ratio: float = my_strength / maxf(strongest_rival, 1.0)

	if dominance_ratio >= 1.5:
		if _has_undertrained_units(ctx, 3):
			return _make_need("TRAIN_TROOPS", 1)
		return _make_need("ACQUIRE_RESOURCE", 1, {"target_resource": "arms"})

	if dominance_ratio >= 1.0:
		if ctx.is_lord:
			if ctx.available_levy_pu > 0.0:
				return _make_need("LEVY_TROOPS", 2)
			return _make_need("TRAIN_TROOPS", 2)
		return _make_need("TRAIN_SKILL", 1)

	# Behind a rival — urgent buildup or preemptive strike
	if ctx.is_lord:
		if ctx.available_levy_pu <= 0.0 and dominance_ratio >= 0.7:
			var target_province: int = _find_weak_neighbor_province(ctx)
			if target_province >= 0:
				return _make_need("INITIATE_WAR_CHECK", 2, {
					"target_province_id": target_province,
					"target_intent": "MILITARY_DOMINANCE",
				})
		return _make_need("LEVY_TROOPS", 3)
	return _make_need("SEND_LETTER", 2)


static func _decompose_eliminate_shadowlands(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	# Step 1: active Shadowlands crisis
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			var p: NPCDataStructures.ProvinceStatus = ps as NPCDataStructures.ProvinceStatus
			if p.active_crisis_id >= 0 and p.crisis_type == "shadowlands_incursion":
				return _make_need("DEFEND_PROVINCE", 3, {"target_province_id": p.province_id})

	# Step 2: Taint insurgency
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			var p: NPCDataStructures.ProvinceStatus = ps as NPCDataStructures.ProvinceStatus
			if p.active_insurgency_id >= 0:
				return _make_need("INVESTIGATE_THREAT", 3, {"target_province_id": p.province_id})

	# Step 3: Jigoku bleed event topics
	if not ctx.taint_topic_province_ids.is_empty():
		return _make_need("INVESTIGATE_THREAT", 2, {
			"target_province_id": ctx.taint_topic_province_ids[0],
		})

	# Step 4: proactive by context
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _make_need("MOVE_TOPIC_POSITION", 2)
		Enums.ContextFlag.AT_TEMPLE:
			if ctx.school_type == Enums.SchoolType.SHUGENJA:
				return _make_need("INVESTIGATE_THREAT", 2)
			return _make_need("PERFORM_RITUAL", 1)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			if ctx.is_lord:
				return _make_need("PATROL_PROVINCE", 1)
			return _make_need("TRAIN_SKILL", 1)
		_:
			return _make_need("TRAIN_SKILL", 1)


static func _decompose_maintain_peace(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	# Step 1: active war
	if not ctx.active_wars.is_empty():
		var war: Dictionary = ctx.active_wars[0]
		var enemy: String = WarSystem.get_enemy_clan_from_war(war, ctx.clan)
		return _make_need("SEEK_PEACE", 3, {
			"target_clan_id": enemy,
		})

	# Step 2: rising tensions — emit PREVENT_WAR NeedType (GDD s55.23.4)
	# PREVENT_WAR fires before war starts; SEEK_PEACE fires during active war.
	if not ctx.escalating_conflicts.is_empty():
		var tension: Dictionary = ctx.escalating_conflicts[0]
		return _make_need("PREVENT_WAR", 3, {
			"target_topic_id": tension.get("topic_id", -1),
			"target_clan_id": tension.get("clan", ""),
		})

	# Step 3: preventive diplomacy
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_lowest_disposition_contact(ctx)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 1, {
					"target_npc_id": contact,
					"threshold": 31.0,
					"threshold_type": "disposition",
				})
			return _make_need("IDENTIFY_CONTACT", 1)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			var marriage_need: Variant = _try_arrange_marriage(ctx, 2, "MAINTAIN_PEACE")
			if marriage_need != null:
				return marriage_need
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _decompose_build_strongest_force(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		return _make_need("TRAIN_SKILL", 1)

	var raw: int = ctx.unit_training_counts.get(0, 0)
	if raw > 0:
		return _make_need("TRAIN_TROOPS", 3)

	var drilled: int = ctx.unit_training_counts.get(1, 0)
	if drilled > 0:
		return _make_need("TRAIN_TROOPS", 2)

	if not ctx.can_sustain_iron_upkeep:
		return _make_need("ACQUIRE_RESOURCE", 2, {"target_resource": "iron"})

	if ctx.available_levy_pu > 0.0:
		var rice: float = ctx.resource_stockpiles.get("rice", 0.0)
		var upkeep: float = ctx.resource_stockpiles.get("military_upkeep", 1.0)
		if rice > upkeep * 3.0:
			return _make_need("LEVY_TROOPS", 1)

	var trained: int = ctx.unit_training_counts.get(2, 0)
	if trained > 0:
		return _make_need("TRAIN_TROOPS", 1)

	var weak: int = _find_weak_neighbor_province(ctx)
	if weak >= 0:
		return _make_need("INITIATE_WAR_CHECK", 1, {
			"target_province_id": weak,
			"target_intent": "BUILD_STRONGEST_FORCE",
		})

	return _make_need("ACQUIRE_RESOURCE", 1, {"target_resource": "arms"})


# =============================================================================
# Helpers
# =============================================================================


static func _make_need(
	need_type: String,
	priority: int,
	extras: Dictionary = {},
) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = need_type
	need.priority = priority
	need.source = "decomposition"
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


static func _passthrough(objective: Dictionary) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = objective.get("need_type", "")
	need.priority = objective.get("priority", 2)
	need.target_npc_id = objective.get("target_npc_id", -1)
	need.target_npc_id_secondary = objective.get("target_npc_id_secondary", -1)
	need.target_settlement_id = objective.get("target_settlement_id", -1)
	need.target_province_id = objective.get("target_province_id", -1)
	need.target_clan_id = objective.get("target_clan_id", "")
	need.target_topic_id = objective.get("target_topic_id", -1)
	need.target_resource = objective.get("target_resource", "")
	need.target_army_id = objective.get("target_army_id", -1)
	need.target_intent = objective.get("target_intent", "")
	need.threshold = objective.get("threshold", 0.0)
	need.threshold_type = objective.get("threshold_type", "")
	need.source = objective.get("source", "objective")
	return need


static func _courtier_diplomatic_path(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			var contact: int = _find_contact_needing_disposition(ctx, 31)
			if contact >= 0:
				return _make_need("RAISE_DISPOSITION", 2, {
					"target_npc_id": contact,
					"threshold": 31.0,
					"threshold_type": "disposition",
				})
			return _make_need("MOVE_TOPIC_POSITION", 2)
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return _make_need("SEND_LETTER", 1)
		_:
			var _court_need := _court_or_alternative(ctx)
			if _court_need != null:
				return _court_need
			return _make_need("REST", 1)


static func _court_or_alternative(
	ctx: NPCDataStructures.ContextSnapshot,
	target_npc_id: int = -1,
	priority: int = 1,
) -> NPCDataStructures.ImmediateNeed:
	var result: Variant = CourtAvailability.attend_court_or_alternative(
		ctx.active_court_at_location,
		ctx.upcoming_courts,
		_make_court_character_stub(ctx),
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


static func _make_court_character_stub(
	ctx: NPCDataStructures.ContextSnapshot,
) -> L5RCharacterData:
	var stub := L5RCharacterData.new()
	stub.character_id = ctx.character_id
	stub.lord_id = ctx.lord_id
	stub.operational_superior_id = -1
	return stub


static func _find_contact_needing_disposition(
	ctx: NPCDataStructures.ContextSnapshot,
	threshold: int,
) -> int:
	for npc_id: int in ctx.characters_present:
		var disp: int = ctx.dispositions.get(npc_id, 0)
		if disp < threshold and disp > -30:
			return npc_id
	return -1


static func _find_clan_contact_present(
	ctx: NPCDataStructures.ContextSnapshot,
	clan_id: String,
) -> int:
	for npc_id: int in ctx.known_contacts:
		if npc_id in ctx.characters_present:
			if clan_id.is_empty() or ctx.contact_clans.get(npc_id, "") == clan_id:
				return npc_id
	return -1


static func _find_highest_status_present(
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	if ctx.characters_present.size() > 0:
		return ctx.characters_present[0]
	return -1


static func _count_friends(dispositions: Dictionary, threshold: int) -> int:
	var count: int = 0
	for disp: int in dispositions.values():
		if disp >= threshold:
			count += 1
	return count


static func _find_crisis_province(ctx: NPCDataStructures.ContextSnapshot) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.active_crisis_id >= 0:
			return ps.province_id
	return -1


static func _find_undergarrisoned_province(ctx: NPCDataStructures.ContextSnapshot) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.garrison_pu < 1:
			return ps.province_id
	return -1


static func _find_stale_province(ctx: NPCDataStructures.ContextSnapshot) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.confidence == 0:
			return ps.province_id
	return -1


static func _find_unstable_province(
	ctx: NPCDataStructures.ContextSnapshot,
	threshold: float,
) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.stability <= threshold:
			return ps.province_id
	return -1


static func _find_weak_neighbor_province(ctx: NPCDataStructures.ContextSnapshot) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			var status: NPCDataStructures.ProvinceStatus = ps
			if not status.clan.is_empty() and status.clan == ctx.clan:
				continue
			var weakness: Dictionary = WarJustification.evaluate_province_weakness(status)
			if weakness["is_weak"]:
				return status.province_id
	return -1


static func _find_weak_neighbor_province_for_clan(
	ctx: NPCDataStructures.ContextSnapshot,
	target_clan: String,
) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			var status: NPCDataStructures.ProvinceStatus = ps
			if status.clan != target_clan:
				continue
			var weakness: Dictionary = WarJustification.evaluate_province_weakness(status)
			if weakness["is_weak"]:
				return status.province_id
	return -1


static func _get_province_status(
	ctx: NPCDataStructures.ContextSnapshot,
	province_id: int,
) -> NPCDataStructures.ProvinceStatus:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.province_id == province_id:
			return ps
	return null


static func _get_rice_per_pu(ctx: NPCDataStructures.ContextSnapshot) -> float:
	var rice: float = ctx.resource_stockpiles.get("rice", 0.0)
	var pop_pu: float = ctx.resource_stockpiles.get("population_pu", 1.0)
	return rice / maxf(pop_pu, 1.0)


static func _find_wall_province(ctx: NPCDataStructures.ContextSnapshot) -> int:
	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.is_wall_province:
			return ps.province_id
	return -1


static func _find_lowest_disposition_contact(
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var lowest_id: int = -1
	var lowest_disp: int = 999
	for npc_id: int in ctx.characters_present:
		var disp: int = ctx.dispositions.get(npc_id, 0)
		if disp < lowest_disp and disp > -30:
			lowest_disp = disp
			lowest_id = npc_id
	return lowest_id


static func _has_undertrained_units(
	ctx: NPCDataStructures.ContextSnapshot,
	max_level: int,
) -> bool:
	for level: int in ctx.unit_training_counts:
		if level < max_level and ctx.unit_training_counts[level] > 0:
			return true
	return false


static func _try_arrange_marriage(
	ctx: NPCDataStructures.ContextSnapshot,
	priority: int = 2,
	target_intent: String = "",
) -> Variant:
	if not ctx.is_lord:
		return null
	if ctx.context_flag != Enums.ContextFlag.AT_OWN_HOLDINGS:
		return null
	if ctx.marriageable_vassal_ids.is_empty():
		return null

	var candidate_id: int = ctx.marriageable_vassal_ids[0]

	var target_lord_id: int = _find_cross_clan_lord(ctx)
	if target_lord_id < 0:
		return null

	return _make_need("ARRANGE_MARRIAGE", priority, {
		"target_npc_id": candidate_id,
		"target_npc_id_secondary": target_lord_id,
		"target_settlement_id": -1,
		"target_intent": target_intent,
	})


static func _find_cross_clan_lord(
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	for clan_name: String in ctx.known_contacts_by_clan:
		if clan_name == ctx.clan:
			continue
		var contacts: Variant = ctx.known_contacts_by_clan[clan_name]
		if contacts is Array:
			for contact_id: Variant in contacts:
				if contact_id is int and contact_id >= 0:
					var disp: int = ctx.dispositions.get(contact_id, 0)
					if disp >= -10:
						return contact_id as int
	return -1
