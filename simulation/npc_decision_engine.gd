class_name NPCDecisionEngine
## The Seven-Phase Decision Loop per GDD s55.4.
## Runs identically for every named NPC regardless of context.
## Pure data — no Node inheritance, no scene tree dependency.


# -- Phase 1: Build Context ----------------------------------------------------

static func build_context(
	character: L5RCharacterData,
	world_state: Dictionary,
	chars_by_id: Dictionary = {},
) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()

	# Identity
	ctx.character_id = character.character_id
	ctx.character_name = character.character_name
	ctx.clan = character.clan
	ctx.family = character.family
	ctx.school_type = character.school_type
	ctx.is_lord = world_state.get("is_lord", false)

	# Location & situation
	ctx.location_id = character.physical_location
	if TravelSystem.is_traveling(character):
		ctx.context_flag = Enums.ContextFlag.TRAVELING
	else:
		ctx.context_flag = world_state.get("context_flag", Enums.ContextFlag.AT_OWN_HOLDINGS)
	ctx.season = world_state.get("season", 0)
	ctx.ic_day = world_state.get("ic_day", 0)
	ctx.sublocation = world_state.get("sublocation", Enums.Sublocation.PUBLIC)
	var ws_zone_subtype: int = world_state.get("zone_subtype", -1)
	if ws_zone_subtype >= 0:
		ctx.zone_subtype = ws_zone_subtype as Enums.ZoneSubtype
		ctx.zone_flags = ZoneFlagMatrix.get_flags(ctx.zone_subtype)
	else:
		ctx.zone_flags = {}

	# Lord & court (s55.34)
	ctx.lord_id = character.lord_id
	ctx.active_court_at_location = world_state.get("active_court_at_location", {})
	ctx.upcoming_courts = world_state.get("upcoming_courts", [] as Array[Dictionary])
	ctx.held_leverage = world_state.get("held_leverage", [] as Array[Dictionary])
	ctx.known_npc_locations = world_state.get("known_npc_locations", {})

	# Stats
	ctx.skill_ranks = character.skills.duplicate()
	ctx.honor = character.honor
	ctx.glory = character.glory
	ctx.status = character.status
	ctx.insight_rank = CharacterStats.get_insight_rank(character)

	# Social knowledge — read through legitimate channels only (GDD s20)
	ctx.characters_present = world_state.get("characters_present", [] as Array[int])
	ctx.dispositions = character.disposition_values.duplicate()
	ctx.disposition_values = character.disposition_values.duplicate()

	# Permanent family bonds layered on top of stored disposition (s22.6).
	# Bonds are recomputed each context build — they never decay and stay
	# in sync with the family graph automatically.
	if not chars_by_id.is_empty():
		var bonds: Dictionary = BiologicalFamily.compute_all_family_bonds(
			character, chars_by_id
		)
		for other_id: int in bonds:
			var bond: int = bonds[other_id]
			var current: int = ctx.dispositions.get(other_id, 0)
			var combined: int = clampi(current + bond, -100, 100)
			ctx.dispositions[other_id] = combined
			ctx.disposition_values[other_id] = combined
	ctx.known_topics = world_state.get("known_topics", [] as Array[int])
	ctx.known_positions = world_state.get("known_positions", {})
	ctx.known_objectives = world_state.get("known_objectives", {})
	ctx.known_contacts = world_state.get("known_contacts", [] as Array[int])
	ctx.contact_clans = world_state.get("contact_clans", {})
	ctx.known_contacts_by_clan = character.known_contacts_by_clan.duplicate()
	ctx.met_characters = character.met_characters.duplicate()
	ctx.knowledge_pool = character.knowledge_pool

	# Lord-tier fields
	if ctx.is_lord:
		ctx.resource_stockpiles = world_state.get("resource_stockpiles", {})
		ctx.province_statuses = world_state.get("province_statuses", [])
		if ctx.province_statuses.is_empty():
			var prov_data: Array = world_state.get("province_data", [])
			var settlements_arr: Array = world_state.get("settlements", [])
			var armies_arr: Array = world_state.get("active_armies", [])
			if not prov_data.is_empty():
				ctx.province_statuses = build_province_statuses_from_data(
					prov_data, settlements_arr, armies_arr,
				)
		ctx.feasibility_data = _build_feasibility_data(character, world_state)

	# Military
	ctx.military_rank = character.military_rank
	ctx.commanded_unit_id = character.commanded_unit_id
	ctx.assigned_company_id = character.assigned_company_id

	# Military intelligence (s55.23)
	ctx.wall_statuses = world_state.get("wall_statuses", [])
	ctx.known_clan_strengths = world_state.get("known_clan_strengths", {})
	ctx.unit_training_counts = world_state.get("unit_training_counts", {})
	ctx.available_levy_pu = world_state.get("available_levy_pu", 0.0)
	ctx.can_sustain_iron_upkeep = world_state.get("can_sustain_iron_upkeep", true)
	ctx.active_wars = world_state.get("active_wars", [])
	ctx.escalating_conflicts = world_state.get("escalating_conflicts", [])
	ctx.taint_topic_province_ids = world_state.get("taint_topic_province_ids", [] as Array[int])

	# Festival state (s11.5)
	ctx.is_ceasefire_day = world_state.get("is_ceasefire_day", false)
	ctx.is_labor_halt_day = world_state.get("is_labor_halt_day", false)
	ctx.is_taian = world_state.get("is_taian", false)
	ctx.is_inauspicious_for_social = world_state.get("is_inauspicious_for_social", false)

	# State
	ctx.pending_events = world_state.get("pending_events", [])
	ctx.ap_remaining = character.action_points_current
	ctx.action_log = world_state.get("action_log", [] as Array[Dictionary])

	# Personality
	ctx.bushido_virtue = character.bushido_virtue
	ctx.shourido_virtue = character.shourido_virtue

	return ctx


# -- Phase 2: Resolve Goal & Decompose ----------------------------------------
# Priority cascade: Reactive Event > Crisis Override > Primary Objective >
# Standing Objective. Winner decomposes into an ImmediateNeed.

static func resolve_goal(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	objectives: Dictionary,
) -> NPCDataStructures.ImmediateNeed:
	# Check reactive events first
	if ctx.pending_events.size() > 0:
		var reactive_need := _decompose_reactive_event(ctx.pending_events[0], ctx)
		if reactive_need != null:
			return reactive_need

	# Crisis override
	var crisis_need := _check_crisis_override(ctx, objectives)
	if crisis_need != null:
		return crisis_need

	# Primary objective
	var primary: Dictionary = objectives.get("primary", {})
	if primary.size() > 0:
		var primary_need := _decompose_objective(primary, ctx)
		if primary_need != null:
			return primary_need

	# Standing objective fallback
	var standing: Dictionary = objectives.get("standing", {})
	if standing.size() > 0:
		var standing_need := _decompose_objective(standing, ctx)
		if standing_need != null:
			return standing_need

	# Absolute fallback — maintenance
	var fallback := NPCDataStructures.ImmediateNeed.new()
	fallback.need_type = "REST"
	fallback.priority = 3
	return fallback


# -- Phase 3: Generate Options -------------------------------------------------
# Lists every ActionID available given the ContextFlag.

static func generate_options(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
) -> Array[NPCDataStructures.ScoredAction]:
	var options: Array[NPCDataStructures.ScoredAction] = []
	var available_actions: Array[String] = _get_actions_for_context(ctx.context_flag)

	for action_id: String in available_actions:
		if _is_zone_blocked(action_id, ctx.zone_flags):
			continue
		if _is_military_blocked(action_id, ctx):
			continue
		if ctx.is_ceasefire_day and _is_ceasefire_blocked(action_id):
			continue
		if ctx.is_labor_halt_day and _is_labor_halt_blocked(action_id):
			continue
		var option := NPCDataStructures.ScoredAction.new()
		option.action_id = action_id
		option.target_npc_id = need.target_npc_id
		option.target_npc_id_secondary = need.target_npc_id_secondary
		option.target_settlement_id = need.target_settlement_id
		option.target_province_id = need.target_province_id
		option.ap_cost = _get_ap_cost(action_id)
		_populate_action_metadata(option, need, ctx)
		options.append(option)

	return options


# -- Phase 4: Personality Filter -----------------------------------------------
# Hard removal of blocked actions. No score can override this gate.

static func apply_personality_filter(
	options: Array[NPCDataStructures.ScoredAction],
	ctx: NPCDataStructures.ContextSnapshot,
	filter_data: Dictionary,
) -> Array[NPCDataStructures.ScoredAction]:
	var filtered: Array[NPCDataStructures.ScoredAction] = []

	for option: NPCDataStructures.ScoredAction in options:
		if _is_action_blocked(option.action_id, ctx, filter_data):
			continue
		filtered.append(option)

	return filtered


# -- Phase 4b: Allowlist Filter (s57.1) ----------------------------------------
# Only actions listed in objective_alignment.json for the current NeedType
# may enter scoring. Missing entries are BLOCKED, not scored at 0.

static func apply_allowlist_filter(
	options: Array[NPCDataStructures.ScoredAction],
	need_type: String,
	scoring_tables: Dictionary,
) -> Array[NPCDataStructures.ScoredAction]:
	var alignment_table: Dictionary = scoring_tables.get("objective_alignment", {})
	var need_entry: Dictionary = alignment_table.get(need_type, {})
	if need_entry.is_empty():
		return options

	var filtered: Array[NPCDataStructures.ScoredAction] = []
	for option: NPCDataStructures.ScoredAction in options:
		if need_entry.has(option.action_id):
			filtered.append(option)
	return filtered


# -- Phase 5: Score All Options ------------------------------------------------
# Eight components per s55.4.5 / s55.3.3.

static func score_all(
	options: Array[NPCDataStructures.ScoredAction],
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
	scoring_tables: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	character: L5RCharacterData = null,
	travel_redirects: int = 0,
) -> void:
	for option: NPCDataStructures.ScoredAction in options:
		option.objective_alignment = _lookup_objective_alignment(
			need.need_type, option.action_id, scoring_tables
		)
		option.disposition_modifier = _lookup_disposition_modifier(
			option.target_npc_id, ctx.dispositions, scoring_tables
		)
		option.personality_lean = _lookup_personality_lean(
			option.action_id, ctx.bushido_virtue, ctx.shourido_virtue, scoring_tables
		)
		option.competence_modifier = _compute_competence_modifier(
			option.action_id, ctx.skill_ranks, scoring_tables
		)
		option.urgency_bonus = _compute_urgency_bonus(
			need, ctx, scoring_tables
		)
		option.standing_influence = _compute_standing_influence(
			option.action_id, ctx, scoring_tables
		)
		option.topic_position_modifier = _compute_topic_position_modifier(
			option.action_id, need, ctx, scoring_tables
		)
		option.resource_modifier = _compute_resource_modifier(
			option, ctx, scoring_tables, character
		)

		option.approach_modifier = float(ApproachEvaluation.get_scoring_modifier(
			option.action_id, ctx.character_id, option.target_npc_id,
			ctx.action_log, approach_penalties, ctx.season, ctx.shourido_virtue
		))

		if character != null and not commitments.is_empty():
			option.commitment_at_risk = float(CommitmentRegistry.get_at_risk_penalty(
				commitments, ctx.character_id, character
			))
		else:
			option.commitment_at_risk = 0.0

		option.travel_redirect_penalty = float(TravelCommitment.get_redirect_penalty(
			travel_redirects
		))

		if character != null and option.target_npc_id > 0:
			option.confidence_penalty = _compute_confidence_penalty(
				character, option.target_npc_id, option.objective_alignment
			)
			option.stale_intel_bonus = _compute_stale_intel_bonus(
				character, option.action_id, option.target_npc_id
			)
		else:
			option.confidence_penalty = 0.0
			option.stale_intel_bonus = 0.0

		option.festival_modifier = _compute_festival_modifier(option.action_id, ctx)


# -- Phase 6: Selection -------------------------------------------------------
# Highest total wins. Tiebreakers: ObjAlign > disposition > lower AP > seed.

static func select_action(
	options: Array[NPCDataStructures.ScoredAction],
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ScoredAction:
	if options.is_empty():
		return _get_fallback_action(ctx)

	options.sort_custom(_compare_scored_actions)
	return options[0]


# -- Phase 7: Execution -------------------------------------------------------
# Deducts AP and returns an action record dictionary.

static func execute_action(
	chosen: NPCDataStructures.ScoredAction,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var result := ActionPointSystem.spend_ap(character, chosen.ap_cost)
	if not result["success"]:
		return {
			"success": false,
			"reason": "insufficient_ap",
			"action_id": chosen.action_id,
		}

	var decision: Dictionary = {
		"success": true,
		"action_id": chosen.action_id,
		"target_npc_id": chosen.target_npc_id,
		"target_npc_id_secondary": chosen.target_npc_id_secondary,
		"target_settlement_id": chosen.target_settlement_id,
		"target_province_id": chosen.target_province_id,
		"ap_spent": chosen.ap_cost,
		"total_score": chosen.get_total_score(),
		"character_id": ctx.character_id,
		"ic_day": ctx.ic_day,
	}
	if not chosen.metadata.is_empty():
		decision["metadata"] = chosen.metadata
	return decision


# -- Main Entry Point ----------------------------------------------------------
# Runs the full seven-phase loop for one NPC spending one AP.

static func run(
	character: L5RCharacterData,
	world_state: Dictionary,
	objectives: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	travel_redirects: int = 0,
	chars_by_id: Dictionary = {},
) -> Dictionary:
	# Phase 1
	var ctx := build_context(character, world_state, chars_by_id)

	# Phase 2
	var need := resolve_goal(character, ctx, objectives)

	# Phase 3
	var options := generate_options(ctx, need)

	# Phase 4
	options = apply_personality_filter(options, ctx, filter_data)
	options = apply_allowlist_filter(options, need.need_type, scoring_tables)

	# Phase 5
	score_all(options, need, ctx, scoring_tables,
		approach_penalties, commitments, character, travel_redirects)

	# Phase 6
	var chosen := select_action(options, ctx)

	# Phase 7
	return execute_action(chosen, character, ctx)


# -- Comparison for Phase 6 tiebreakers ---------------------------------------

static func _compare_scored_actions(a: NPCDataStructures.ScoredAction, b: NPCDataStructures.ScoredAction) -> bool:
	var score_a := a.get_total_score()
	var score_b := b.get_total_score()
	if score_a != score_b:
		return score_a > score_b
	if a.objective_alignment != b.objective_alignment:
		return a.objective_alignment > b.objective_alignment
	if a.disposition_modifier != b.disposition_modifier:
		return a.disposition_modifier > b.disposition_modifier
	if a.ap_cost != b.ap_cost:
		return a.ap_cost < b.ap_cost
	# Deterministic seed: lower action_id string wins
	return a.action_id < b.action_id


# -- Fallback action when all options filtered out ----------------------------

static func _get_fallback_action(_ctx: NPCDataStructures.ContextSnapshot) -> NPCDataStructures.ScoredAction:
	var fallback := NPCDataStructures.ScoredAction.new()
	fallback.action_id = "DO_NOTHING"
	fallback.ap_cost = 0
	return fallback


# -- Stub helpers (to be replaced by JSON table loaders) ----------------------

static func _decompose_reactive_event(
	event: Variant,
	_ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if event is Dictionary and event.has("need_type"):
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = event["need_type"]
		need.priority = event.get("priority", 1)
		need.target_npc_id = event.get("target_npc_id", -1)
		need.target_npc_id_secondary = event.get("target_npc_id_secondary", -1)
		need.target_settlement_id = event.get("target_settlement_id", -1)
		need.target_province_id = event.get("target_province_id", -1)
		need.target_clan_id = event.get("target_clan_id", "")
		need.source = event.get("source", "reactive")
		return need
	return null


static func _check_crisis_override(
	ctx: NPCDataStructures.ContextSnapshot,
	_objectives: Dictionary,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		return null

	for ps in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus and ps.active_crisis_id >= 0:
			var need := NPCDataStructures.ImmediateNeed.new()
			need.need_type = "DEFEND_PROVINCE"
			need.priority = 1
			need.target_province_id = ps.province_id
			need.source = "crisis_override"
			return need

	return null


static func _decompose_objective(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if not objective.has("need_type"):
		return null
	return ObjectiveDecomposer.decompose(objective, ctx)


static func _get_actions_for_context(context_flag: Enums.ContextFlag) -> Array[String]:
	match context_flag:
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return [
				"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
				"PROBE", "READ_CHARACTER", "PUBLIC_DEBATE",
				"ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
				"TRAIN", "MEDITATE",
				"ASSESS_PROVINCE_STATUS", "INVESTIGATE_PROVINCE",
				"INVESTIGATE_RUMOR", "ORDER_PATROL",
				"FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
				"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP",
				"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION",
				"PURIFY_TAINTED_GROUND", "FORTIFY_WALL_SECTION", "SEAL_WALL_BREACH",
				"DECLARE_WAR", "NEGOTIATE_SURRENDER",
				"CRAFT", "MENTOR",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_COURT:
			return [
				"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
				"PROBE", "READ_CHARACTER", "LISTEN_REFLECT", "IMPRESS",
				"PUBLIC_DEBATE", "PUBLIC_INSULT", "PUBLIC_DECLARATION",
				"PUBLIC_PERFORMANCE", "DELIVER_GIFT", "OFFER_FAVOR",
				"PERFORM_FOR", "DISCLOSE",
				"ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
				"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION",
				"TRAIN", "MEDITATE",
				"BRIBE_FOR_INFO", "EAVESDROP",
				"INTERCEPT_LETTER", "SEARCH_QUARTERS",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.VISITING:
			return [
				"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
				"PROBE", "READ_CHARACTER", "LISTEN_REFLECT",
				"DELIVER_GIFT", "OFFER_FAVOR",
				"ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
				"TRAIN", "MEDITATE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.TRAVELING:
			return [
				"CHANGE_DESTINATION",
				"TRAIN", "MEDITATE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.ON_CAMPAIGN:
			return [
				"ORDER_BATTLE", "CONDUCT_RAID", "RAID_HARVEST",
				"DRILL_TROOPS", "EVALUATE_WAR_READINESS",
				"INTIMIDATE", "NEGOTIATE",
				"TRAIN",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.UNDER_SIEGE:
			return [
				"CONDUCT_SORTIE", "CONDUCT_STORM_ASSAULT",
				"NEGOTIATE_SURRENDER", "MAINTAIN_SIEGE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.IN_EXILE:
			return [
				"TRAIN", "MEDITATE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_TEMPLE:
			return [
				"PERFORM_RITUAL", "PERFORM_WORSHIP", "MEDITATE",
				"PUBLIC_ATONEMENT", "TRAIN",
				"CHARM", "PROBE", "READ_CHARACTER",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_DOJO:
			return [
				"TRAIN", "MENTOR", "DRILL_TROOPS",
				"CHARM", "PROBE",
				"DO_NOTHING", "REST",
			]
		_:
			return ["DO_NOTHING", "REST"]


static func _get_ap_cost(action_id: String) -> int:
	var costs: Dictionary = {
		"DO_NOTHING": 0,
		"REST": 1,
		"TRAIN": 1,
		"WRITE_LETTER": 1,
		"CHARM": 1,
		"INTIMIDATE": 1,
		"GOSSIP": 1,
		"PERSUADE": 1,
		"NEGOTIATE": 1,
		"PROBE": 1,
		"READ_CHARACTER": 1,
		"LISTEN_REFLECT": 1,
		"IMPRESS": 1,
		"PUBLIC_DEBATE": 1,
		"PUBLIC_INSULT": 1,
		"PUBLIC_DECLARATION": 1,
		"PUBLIC_PERFORMANCE": 1,
		"DELIVER_GIFT": 1,
		"OFFER_FAVOR": 1,
		"PERFORM_FOR": 1,
		"DISCLOSE": 1,
		"ASK_FOR_INTRODUCTION": 1,
		"OBSERVE_COURT_ATTENDEES": 1,
		"ASSESS_PROVINCE_STATUS": 1,
		"INVESTIGATE_PROVINCE": 1,
		"INVESTIGATE_RUMOR": 1,
		"ORDER_PATROL": 1,
		"ORDER_BATTLE": 1,
		"CONDUCT_RAID": 1,
		"RAID_HARVEST": 1,
		"CONDUCT_SORTIE": 1,
		"CONDUCT_STORM_ASSAULT": 1,
		"NEGOTIATE_SURRENDER": 1,
		"MAINTAIN_SIEGE": 1,
		"PERFORM_RITUAL": 1,
		"PERFORM_WORSHIP": 1,
		"PUBLIC_ATONEMENT": 1,
		"MENTOR": 1,
		"MEDITATE": 1,
		"CRAFT": 1,
		"DRILL_TROOPS": 1,
		"EVALUATE_WAR_READINESS": 1,
		"BRIBE_FOR_INFO": 1,
		"EAVESDROP": 1,
		"INTERCEPT_LETTER": 1,
		"SEARCH_QUARTERS": 1,
		"BEGIN_TRAVEL": 1,
		"DISPATCH_COURTIER": 1,
		"CONDUCT_COMMERCE": 1,
		"ISSUE_DUEL_CHALLENGE": 1,
		"SEEK_PRETEXT": 1,
		"SHARE_SUPPLIES": 1,
		"PURIFY_TAINTED_GROUND": 1,
		"FORTIFY_WALL_SECTION": 1,
		"SEAL_WALL_BREACH": 2,
		"DECLARE_WAR": 2,
	}
	return costs.get(action_id, 1)


static func _is_action_blocked(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
	filter_data: Dictionary,
) -> bool:
	if ctx.bushido_virtue != Enums.BushidoVirtue.NONE:
		var virtue_name: String = Enums.bushido_virtue_name(ctx.bushido_virtue)
		var bushido_filters: Dictionary = filter_data.get("bushido", {})
		var virtue_filter: Dictionary = bushido_filters.get(virtue_name, {})
		var always_blocked: Array = virtue_filter.get("always_blocked", [])
		if action_id in always_blocked:
			return true

	if ctx.shourido_virtue != Enums.ShouridoVirtue.NONE:
		var virtue_name: String = Enums.shourido_virtue_name(ctx.shourido_virtue)
		var shourido_filters: Dictionary = filter_data.get("shourido", {})
		var virtue_filter: Dictionary = shourido_filters.get(virtue_name, {})
		var always_blocked: Array = virtue_filter.get("always_blocked", [])
		if action_id in always_blocked:
			return true

	return false


static func _lookup_objective_alignment(
	need_type: String,
	action_id: String,
	scoring_tables: Dictionary,
) -> float:
	var alignment_table: Dictionary = scoring_tables.get("objective_alignment", {})
	var need_entry: Dictionary = alignment_table.get(need_type, {})
	if not need_entry.has(action_id):
		return 0.0
	return float(need_entry[action_id])


static func _lookup_disposition_modifier(
	target_npc_id: int,
	dispositions: Dictionary,
	scoring_tables: Dictionary,
) -> float:
	if target_npc_id < 0:
		return 0.0

	var disp_value: float = float(dispositions.get(target_npc_id, 0))
	var tiers: Array = scoring_tables.get("disposition_tiers", [])

	for tier in tiers:
		if tier is Dictionary:
			var min_val: float = float(tier.get("min", -100))
			var max_val: float = float(tier.get("max", 100))
			if disp_value >= min_val and disp_value <= max_val:
				return float(tier.get("cooperative", 0))

	return 0.0


static func _lookup_personality_lean(
	action_id: String,
	bushido_virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
	scoring_tables: Dictionary,
) -> float:
	var lean_table: Dictionary = scoring_tables.get("personality_lean", {})
	var total: float = 0.0

	if bushido_virtue != Enums.BushidoVirtue.NONE:
		var virtue_name: String = Enums.bushido_virtue_name(bushido_virtue)
		var bushido_leans: Dictionary = lean_table.get(virtue_name, {})
		total += float(bushido_leans.get(action_id, 0))

	if shourido_virtue != Enums.ShouridoVirtue.NONE:
		var virtue_name: String = Enums.shourido_virtue_name(shourido_virtue)
		var shourido_leans: Dictionary = lean_table.get(virtue_name, {})
		total += float(shourido_leans.get(action_id, 0))

	return clampf(total, -15.0, 15.0)


static func _compute_competence_modifier(
	action_id: String,
	skill_ranks: Dictionary,
	scoring_tables: Dictionary,
) -> float:
	var skill_map: Dictionary = scoring_tables.get("action_skill_map", {})
	var action_skills: Dictionary = skill_map.get(action_id, {})

	var primary_skill: String = action_skills.get("primary", "")
	if primary_skill == "":
		return 0.0

	var rank: int = int(skill_ranks.get(primary_skill, 0))
	var modifier: float = float(NPCDataStructures.get_competence_modifier(rank))

	var secondary_skill: String = action_skills.get("secondary", "")
	if secondary_skill != "":
		var sec_rank: int = int(skill_ranks.get(secondary_skill, 0))
		modifier += float(NPCDataStructures.get_competence_modifier(sec_rank)) * 0.5

	return clampf(modifier, -20.0, 20.0)


static func _compute_urgency_bonus(
	need: NPCDataStructures.ImmediateNeed,
	_ctx: NPCDataStructures.ContextSnapshot,
	scoring_tables: Dictionary,
) -> float:
	var urgency_rules: Array = scoring_tables.get("urgency_rules", [])
	var bonus: float = 0.0

	for rule in urgency_rules:
		if rule is Dictionary:
			var condition: String = rule.get("condition", "")
			if _evaluate_urgency_condition(condition, need):
				bonus += float(rule.get("bonus", 0))

	return clampf(bonus, 0.0, 30.0)


static func _evaluate_urgency_condition(
	condition: String,
	need: NPCDataStructures.ImmediateNeed,
) -> bool:
	match condition:
		"priority_1":
			return need.priority == 1
		"priority_2":
			return need.priority == 2
		_:
			return false


static func _compute_standing_influence(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
	scoring_tables: Dictionary,
) -> float:
	var standing_need_type: String = ctx.known_objectives.get("standing_need_type", "")
	if standing_need_type == "":
		return 0.0

	var alignment_table: Dictionary = scoring_tables.get("objective_alignment", {})
	var need_entry: Dictionary = alignment_table.get(standing_need_type, {})
	if not need_entry.has(action_id):
		return 0.0

	var raw: float = float(need_entry[action_id]) / 10.0
	return clampf(raw, 0.0, 15.0)


static func _compute_topic_position_modifier(
	_action_id: String,
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
	scoring_tables: Dictionary,
) -> float:
	if ctx.known_topics.is_empty():
		return 0.0

	var topic_table: Dictionary = scoring_tables.get("topic_position_alignment", {})
	var need_entry: Dictionary = topic_table.get(need.need_type, {})
	if need_entry.is_empty():
		return 0.0

	var best_modifier: float = 0.0
	for topic_id in ctx.known_topics:
		var position: float = float(ctx.known_positions.get(topic_id, 0))
		var modifier: float = _interpolate_topic_position(position, need_entry)
		if absf(modifier) > absf(best_modifier):
			best_modifier = modifier

	return clampf(best_modifier, -15.0, 15.0)


static func _interpolate_topic_position(
	position: float,
	_need_entry: Dictionary,
) -> float:
	if position <= -50.0:
		return -15.0
	if position >= 50.0:
		return 15.0
	if position >= -15.0 and position <= 15.0:
		return 0.0
	if position < -15.0:
		return lerpf(0.0, -15.0, (absf(position) - 15.0) / 35.0)
	return lerpf(0.0, 15.0, (position - 15.0) / 35.0)


static func _compute_resource_modifier(
	option: NPCDataStructures.ScoredAction,
	ctx: NPCDataStructures.ContextSnapshot,
	_scoring_tables: Dictionary,
	character: L5RCharacterData = null,
) -> float:
	if character == null:
		return 0.0
	var province_data: Dictionary = _build_province_data_for_resource_check(ctx)
	return ResourceAvailability.compute_resource_modifier(
		option.action_id, character, province_data
	)


static func _build_province_data_for_resource_check(
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var data: Dictionary = {
		"available_levy_pu": ctx.available_levy_pu,
	}
	if not ctx.province_statuses.is_empty():
		var ps: Variant = ctx.province_statuses[0]
		if ps is NPCDataStructures.ProvinceStatus:
			data["rice_stockpile"] = ps.rice_stockpile
	return data


# -- Confidence Penalty (s55.12) -----------------------------------------------

const CONFIDENCE_RECENT_PENALTY: float = -10.0

static func _compute_confidence_penalty(
	character: L5RCharacterData,
	target_npc_id: int,
	obj_alignment: float,
) -> float:
	var best: int = InformationSystem.get_best_confidence_on_target(character, target_npc_id)
	if best < 0:
		return 0.0
	if best == Enums.KnowledgeConfidence.STALE:
		return -(obj_alignment * 0.5)
	if best == Enums.KnowledgeConfidence.RECENT:
		return CONFIDENCE_RECENT_PENALTY
	return 0.0


# -- Stale Intel Bonus (s55.12) ------------------------------------------------

const STALE_INTEL_GATHER_BONUS: float = 15.0

const GATHER_INTELLIGENCE_ACTIONS: Array = [
	"PROBE", "READ_CHARACTER", "BRIBE_FOR_INFO", "EAVESDROP",
	"INTERCEPT_LETTER", "SEARCH_QUARTERS",
]

static func _compute_stale_intel_bonus(
	character: L5RCharacterData,
	action_id: String,
	target_npc_id: int,
) -> float:
	if action_id not in GATHER_INTELLIGENCE_ACTIONS:
		return 0.0
	var best: int = InformationSystem.get_best_confidence_on_target(character, target_npc_id)
	if best == Enums.KnowledgeConfidence.STALE:
		return STALE_INTEL_GATHER_BONUS
	return 0.0


# -- Zone Flag Blocking (s57.36) -----------------------------------------------

const ZONE_GATED_ACTIONS: Dictionary = {
	"PUBLIC_PERFORMANCE": "performance_permitted",
	"PERFORM_FOR": "performance_permitted",
	"PERFORM_WORSHIP": "shrine_eligible",
	"PERFORM_RITUAL": "shrine_eligible",
}

static func _is_zone_blocked(action_id: String, zone_flags: Dictionary) -> bool:
	if zone_flags.is_empty():
		return false
	var required_flag: String = ZONE_GATED_ACTIONS.get(action_id, "")
	if required_flag.is_empty():
		return false
	return not zone_flags.get(required_flag, false)


# -- Military Hierarchy Blocking (s57.21) --------------------------------------

const MILITARY_ORDER_ACTIONS: Array[String] = [
	"ORDER_BATTLE", "CONDUCT_RAID", "RAID_HARVEST",
	"DRILL_TROOPS", "EVALUATE_WAR_READINESS",
	"ORDER_PATROL", "CONDUCT_SORTIE", "CONDUCT_STORM_ASSAULT",
	"MAINTAIN_SIEGE", "NEGOTIATE_SURRENDER",
]

const COMMANDER_RANK_ACTIONS: Dictionary = {
	"DISPATCH_COURTIER": Enums.MilitaryRank.SHIREIKAN,
	"LEVY_TROOPS": Enums.MilitaryRank.CHUI,
}

static func _is_military_blocked(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if action_id in MILITARY_ORDER_ACTIONS:
		return ctx.commanded_unit_id < 0
	if COMMANDER_RANK_ACTIONS.has(action_id):
		var min_rank: int = COMMANDER_RANK_ACTIONS[action_id]
		return ctx.military_rank < min_rank
	return false


# -- Festival Blocking (s11.5) ------------------------------------------------

const CEASEFIRE_BLOCKED_ACTIONS: Array[String] = [
	"ORDER_BATTLE", "CONDUCT_RAID", "RAID_HARVEST",
	"CONDUCT_SORTIE", "CONDUCT_STORM_ASSAULT",
	"MAINTAIN_SIEGE", "DECLARE_WAR",
]

const LABOR_HALT_BLOCKED_ACTIONS: Array[String] = [
	"COMMISSION_CONSTRUCTION", "COMMISSION_REPAIR",
	"LEVY_TROOPS", "DRILL_TROOPS",
]

const SOCIAL_ACTIONS: Array[String] = [
	"CHARM", "NEGOTIATE", "PERSUADE", "IMPRESS",
	"LISTEN_REFLECT", "INTIMIDATE", "PERFORM_FOR",
	"GOSSIP", "DISCLOSE", "OFFER_FAVOR",
]

const INAUSPICIOUS_PENALTY: float = -10.0
const TAIAN_BONUS: float = 5.0

static func _is_ceasefire_blocked(action_id: String) -> bool:
	return action_id in CEASEFIRE_BLOCKED_ACTIONS


static func _is_labor_halt_blocked(action_id: String) -> bool:
	return action_id in LABOR_HALT_BLOCKED_ACTIONS


static func _compute_festival_modifier(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	if action_id not in SOCIAL_ACTIONS:
		return 0.0
	var modifier: float = 0.0
	if ctx.is_inauspicious_for_social:
		modifier += INAUSPICIOUS_PENALTY
	if ctx.is_taian:
		modifier += TAIAN_BONUS
	return modifier


# -- Daily Letter Pass (s57.5) ------------------------------------------------
# WRITE_LETTER is not scored in the main decision loop. After AP resolution,
# each NPC gets one free letter per IC day. Selects best recipient using
# SEND_LETTER alignment entries as scoring table.

static func resolve_daily_letter(
	character: L5RCharacterData,
	objectives: Dictionary,
	scoring_tables: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var need_type: String = _get_letter_need_type(objectives)
	if need_type.is_empty():
		return {}

	var alignment_table: Dictionary = scoring_tables.get("objective_alignment", {})
	var send_letter_entry: Dictionary = alignment_table.get(need_type, {})
	var send_letter_score: float = float(send_letter_entry.get("WRITE_LETTER", send_letter_entry.get("SEND_LETTER", 0)))
	if send_letter_score <= 0:
		return {}

	var target_id: int = _select_letter_target(objectives, ctx)
	if target_id < 0:
		return {}

	return {
		"character_id": character.character_id,
		"action_id": "WRITE_LETTER",
		"target_npc_id": target_id,
		"need_type": need_type,
	}


static func _get_letter_need_type(objectives: Dictionary) -> String:
	var primary: Dictionary = objectives.get("primary", {})
	if not primary.is_empty():
		return primary.get("need_type", "")
	var standing: Dictionary = objectives.get("standing", {})
	if not standing.is_empty():
		return standing.get("need_type", "")
	return ""


static func _select_letter_target(
	objectives: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var primary: Dictionary = objectives.get("primary", {})
	if primary.has("target_npc_id") and primary["target_npc_id"] >= 0:
		return primary["target_npc_id"]
	if ctx.lord_id >= 0:
		return ctx.lord_id
	var met: Array[int] = ctx.met_characters
	if not met.is_empty():
		return met[0]
	return -1


# -- Province Status Builder ---------------------------------------------------

static func build_province_statuses_from_data(
	province_data: Array,
	settlements: Array = [],
	active_armies: Array = [],
) -> Array:
	var result: Array = []
	var settlement_garrison: Dictionary = {}
	var settlement_total_pu: Dictionary = {}
	for s: Variant in settlements:
		if s is SettlementData:
			var sd: SettlementData = s
			var pid: int = sd.province_id
			settlement_garrison[pid] = settlement_garrison.get(pid, 0) + sd.garrison_pu
			settlement_total_pu[pid] = settlement_total_pu.get(pid, 0) + sd.population_pu

	var armies_by_province: Dictionary = {}
	for army: Variant in active_armies:
		if not (army is Dictionary):
			continue
		var ad: Dictionary = army
		var apid: int = ad.get("province_id", -1)
		if apid < 0:
			continue
		var clan: String = ad.get("owning_clan", "")
		if clan.is_empty():
			continue
		if not armies_by_province.has(apid):
			armies_by_province[apid] = []
		armies_by_province[apid].append(clan)

	for prov: Variant in province_data:
		if not (prov is ProvinceData):
			continue
		var pd: ProvinceData = prov
		var ps := NPCDataStructures.ProvinceStatus.new()
		ps.province_id = pd.province_id
		ps.clan = pd.clan
		ps.stability = pd.stability
		ps.active_crisis_id = pd.active_crisis_id
		ps.active_insurgency_id = pd.active_insurgency_id
		ps.last_report_ic_day = pd.last_report_ic_day
		ps.garrison_pu = settlement_garrison.get(pd.province_id, 0)
		ps.total_settlement_pu = settlement_total_pu.get(pd.province_id, 0)
		ps.confidence = 2
		var army_clans: Array = armies_by_province.get(pd.province_id, [])
		for ac: Variant in army_clans:
			if ac is String and ac != pd.clan:
				ps.has_field_army_nearby = true
				break
		result.append(ps)
	return result


# -- Action Metadata Population ------------------------------------------------
# Populates action-specific metadata during Phase 3. Actions that need special
# inputs for execution (DECLARE_WAR, NEGOTIATE_SURRENDER) get their metadata
# here from the need and context.

static func _populate_action_metadata(
	option: NPCDataStructures.ScoredAction,
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
) -> void:
	if option.action_id == "DECLARE_WAR":
		option.metadata = _build_declare_war_metadata(need, ctx)
	elif option.action_id == "NEGOTIATE_SURRENDER":
		option.metadata = _build_negotiate_surrender_metadata(need, ctx)


static func _build_declare_war_metadata(
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var target_clan: String = need.target_clan_id
	var target_ps: NPCDataStructures.ProvinceStatus = null
	var own_garrison_total: float = 0.0

	for ps: Variant in ctx.province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			var status: NPCDataStructures.ProvinceStatus = ps
			if not status.clan.is_empty() and status.clan == ctx.clan:
				own_garrison_total += float(status.garrison_pu)
			if status.province_id == need.target_province_id:
				if target_clan.is_empty():
					target_clan = status.clan
				target_ps = status

	var standing: String = need.target_intent
	var primary: String = ""

	var virtue: String = _get_virtue_string(ctx)
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		standing, primary, virtue,
	)

	var authority: int = WarJustification.get_authority_for_tier(tier)

	var meta: Dictionary = {
		"standing_objective": standing,
		"primary_objective": primary,
		"intended_tier": tier,
		"target_clan": target_clan,
		"authority_level": authority,
		"primary_virtue": virtue,
		"attacker_pu": ctx.available_levy_pu + own_garrison_total,
	}

	if target_ps != null:
		var weakness: Dictionary = WarJustification.evaluate_province_weakness(target_ps)
		meta["target_garrison_at_minimum"] = weakness["garrison_at_minimum"]
		meta["no_field_army_nearby"] = weakness["no_field_army_nearby"]
		meta["no_alliance_protection"] = weakness["no_alliance_protection"]
		meta["defender_observable_pu"] = float(target_ps.garrison_pu)

	if not ctx.feasibility_data.is_empty():
		var fi: Dictionary = ctx.feasibility_data.duplicate()
		fi["authority_level"] = authority
		fi["primary_virtue"] = virtue
		fi["proposed_levy_pu"] = ctx.available_levy_pu
		meta["feasibility_inputs"] = fi

	return meta


static func _build_negotiate_surrender_metadata(
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var target_clan: String = need.target_clan_id
	var war_ref: Variant = null
	for war_dict: Variant in ctx.active_wars:
		if not (war_dict is Dictionary):
			continue
		var wd: Dictionary = war_dict
		var enemy: String = WarSystem.get_enemy_clan_from_war(wd, ctx.clan)
		if enemy == target_clan or target_clan.is_empty():
			war_ref = wd.get("_war_ref")
			target_clan = enemy
			break
	return {
		"war_ref": war_ref,
		"target_clan": target_clan,
		"target_virtue": "",
		"hostage_held": false,
		"superior_pressuring": false,
	}


static func _build_feasibility_data(
	character: L5RCharacterData,
	world_state: Dictionary,
) -> Dictionary:
	var settlements: Array = world_state.get("settlements", [])
	var provinces: Array = world_state.get("province_data", [])
	var clans: Array = world_state.get("clans", [])

	var controlled: Array = []
	var clan_province_ids: Array[int] = []
	for p: Variant in provinces:
		if p is ProvinceData and (p as ProvinceData).clan == character.clan:
			clan_province_ids.append((p as ProvinceData).province_id)
	for s: Variant in settlements:
		if s is SettlementData and (s as SettlementData).province_id in clan_province_ids:
			controlled.append(s)

	var clan_arms: float = 0.0
	var clan_iron: float = 0.0
	for c: Variant in clans:
		if c is ClanData and (c as ClanData).clan_name == character.clan:
			clan_arms = (c as ClanData).arms_stockpile
			clan_iron = (c as ClanData).iron_stockpile
			break

	var total_koku: float = 0.0
	for s: Variant in controlled:
		if s is SettlementData:
			total_koku += (s as SettlementData).koku_stockpile

	var current_season: String = world_state.get("current_season", "spring")
	var levy_before_planting: bool = current_season == "spring"
	var spans_autumn: bool = true

	var vassal_stockpiles: Array = _collect_vassal_stockpiles(
		character, world_state, settlements, provinces,
	)
	var active_wars: Array = world_state.get("active_wars", [])
	var raidable: Array = _collect_raidable_provinces(
		character.clan, provinces, settlements, active_wars,
	)
	var trade_routes: Array = world_state.get("trade_routes", [])
	var has_routes: bool = _has_active_trade_routes(trade_routes, character.clan)
	var allied: Array = _collect_allied_surplus(
		character, world_state, settlements, provinces,
	)
	var war_info: Dictionary = _get_war_context(character.clan, active_wars)
	var has_grievance: bool = _has_grievance_against_neighbors(
		character, raidable,
	)

	return {
		"controlled_settlements": controlled,
		"provinces": provinces,
		"clan_arms_stockpile": clan_arms,
		"clan_iron_stockpile": clan_iron,
		"current_koku": total_koku,
		"levy_before_planting": levy_before_planting,
		"spans_autumn": spans_autumn,
		"iron_upkeep_rate_per_pu": 0.10,
		"equip_cost": 0.0,
		"ladder_context": {
			"current_season": current_season,
			"vassal_stockpiles": vassal_stockpiles,
			"allied_surplus": allied,
			"raidable_provinces": raidable,
			"has_trade_routes": has_routes,
			"has_grievance": has_grievance,
			"has_issued_demand": _has_issued_demand(character, world_state),
			"war_score": war_info.get("war_score", 50),
			"is_defending": war_info.get("is_defending", false),
		},
	}


static func _collect_vassal_stockpiles(
	lord: L5RCharacterData,
	world_state: Dictionary,
	settlements: Array,
	provinces: Array,
) -> Array:
	var chars: Dictionary = world_state.get("characters_by_id", {})
	var result: Array = []
	for cid: Variant in chars:
		var c: Variant = chars[cid]
		if not (c is L5RCharacterData):
			continue
		var ch: L5RCharacterData = c
		if ch.lord_id != lord.character_id:
			continue
		var disp: int = ch.disposition_values.get(lord.character_id, 0)
		var vassal_rice: float = 0.0
		var vassal_arms: float = 0.0
		var in_shortage: bool = false
		for s: Variant in settlements:
			if s is SettlementData:
				var sd: SettlementData = s
				for p: Variant in provinces:
					if p is ProvinceData:
						var pd: ProvinceData = p
						if pd.province_id == sd.province_id and pd.clan == ch.clan:
							vassal_rice += sd.rice_stockpile
							if sd.rice_stockpile < float(sd.population_pu) * 0.25:
								in_shortage = true
		if vassal_rice > 0.0:
			result.append({
				"character_id": ch.character_id,
				"disposition": disp,
				"rice_stockpile": vassal_rice,
				"arms_stockpile": vassal_arms,
				"in_shortage": in_shortage,
			})
	return result


static func _collect_raidable_provinces(
	own_clan: String,
	provinces: Array,
	settlements: Array,
	active_wars: Array,
) -> Array:
	var at_war_clans: Dictionary = {}
	for w: Variant in active_wars:
		if w is Dictionary:
			var wd: Dictionary = w
			if wd.get("clan_a", "") == own_clan:
				at_war_clans[wd.get("clan_b", "")] = true
			elif wd.get("clan_b", "") == own_clan:
				at_war_clans[wd.get("clan_a", "")] = true

	var province_rice: Dictionary = {}
	var province_garrison: Dictionary = {}
	for s: Variant in settlements:
		if s is SettlementData:
			var sd: SettlementData = s
			province_rice[sd.province_id] = province_rice.get(sd.province_id, 0.0) + sd.rice_stockpile
			province_garrison[sd.province_id] = province_garrison.get(sd.province_id, 0.0) + float(sd.garrison_pu)

	var result: Array = []
	for p: Variant in provinces:
		if not (p is ProvinceData):
			continue
		var pd: ProvinceData = p
		if pd.clan == own_clan or pd.clan.is_empty():
			continue
		result.append({
			"province_id": pd.province_id,
			"clan": pd.clan,
			"garrison_pu": province_garrison.get(pd.province_id, 0.0),
			"rice_stockpile": province_rice.get(pd.province_id, 0.0),
			"already_at_war": at_war_clans.has(pd.clan),
		})
	return result


static func _has_active_trade_routes(trade_routes: Array, _clan: String) -> bool:
	for r: Variant in trade_routes:
		if r is TradeRouteData:
			var tr: TradeRouteData = r
			if not tr.is_disrupted:
				return true
		elif r is Dictionary:
			if not r.get("is_disrupted", true):
				return true
	return false


static func _collect_allied_surplus(
	character: L5RCharacterData,
	world_state: Dictionary,
	settlements: Array,
	provinces: Array,
) -> Array:
	var chars: Dictionary = world_state.get("characters_by_id", {})
	var result: Array = []
	for cid: Variant in chars:
		var c: Variant = chars[cid]
		if not (c is L5RCharacterData):
			continue
		var ch: L5RCharacterData = c
		if ch.clan == character.clan:
			continue
		if ch.character_id == character.character_id:
			continue
		var is_lord: bool = ch.status >= 5.0 or ch.lord_id == -1
		if not is_lord:
			continue
		var disp: int = character.disposition_values.get(ch.character_id, 0)
		if disp < 31:
			continue
		var ally_rice: float = 0.0
		var ally_koku: float = 0.0
		var ally_prov_ids: Array[int] = []
		for p: Variant in provinces:
			if p is ProvinceData and (p as ProvinceData).clan == ch.clan:
				ally_prov_ids.append((p as ProvinceData).province_id)
		for s: Variant in settlements:
			if s is SettlementData and (s as SettlementData).province_id in ally_prov_ids:
				ally_rice += (s as SettlementData).rice_stockpile
				ally_koku += (s as SettlementData).koku_stockpile
		var ally_civilian_pu: float = 0.0
		for s: Variant in settlements:
			if s is SettlementData and (s as SettlementData).province_id in ally_prov_ids:
				var sd: SettlementData = s
				ally_civilian_pu += float(sd.farming_pu + sd.mining_pu + sd.town_pu)
		var buffer: float = ally_civilian_pu * 0.25 * 4.0
		var surplus_rice: float = maxf(0.0, ally_rice - buffer)
		if surplus_rice > 0.0 or ally_koku > 0.0:
			result.append({
				"character_id": ch.character_id,
				"clan": ch.clan,
				"disposition": disp,
				"surplus_rice": surplus_rice,
				"surplus_koku": maxf(0.0, ally_koku),
			})
	return result


static func _get_war_context(
	clan: String,
	active_wars: Array,
) -> Dictionary:
	var worst_score: int = 50
	var is_defending: bool = false
	for w: Variant in active_wars:
		var wd: Variant = w
		var clan_a: String = ""
		var clan_b: String = ""
		var score_a: int = 50
		var score_b: int = 50
		var initiator: String = ""
		if wd is Dictionary:
			clan_a = (wd as Dictionary).get("clan_a", "")
			clan_b = (wd as Dictionary).get("clan_b", "")
			score_a = (wd as Dictionary).get("war_score_a", 50)
			score_b = (wd as Dictionary).get("war_score_b", 50)
			initiator = (wd as Dictionary).get("initiator_clan", "")
		elif wd is WarData:
			clan_a = (wd as WarData).clan_a
			clan_b = (wd as WarData).clan_b
			score_a = (wd as WarData).war_score_a
			score_b = (wd as WarData).war_score_b
			initiator = (wd as WarData).initiator_clan
		var my_score: int = -1
		if clan_a == clan:
			my_score = score_a
			if initiator == clan_b:
				is_defending = true
		elif clan_b == clan:
			my_score = score_b
			if initiator == clan_a:
				is_defending = true
		if my_score >= 0 and my_score < worst_score:
			worst_score = my_score
	return {"war_score": worst_score, "is_defending": is_defending}


static func _has_grievance_against_neighbors(
	character: L5RCharacterData,
	_raidable_provinces: Array,
) -> bool:
	for cid: Variant in character.disposition_values:
		var disp: int = character.disposition_values[cid]
		if disp <= -31:
			return true
	var obj: String = character.current_objective
	if obj in ["SEEK_VENGEANCE", "UNDERMINE_CLAN", "AVENGE"]:
		return true
	return false


const _VIRTUE_NAMES: Dictionary = {
	Enums.BushidoVirtue.JIN: "Jin",
	Enums.BushidoVirtue.YU: "Yu",
	Enums.BushidoVirtue.REI: "Rei",
	Enums.BushidoVirtue.CHUGI: "Chugi",
	Enums.BushidoVirtue.GI: "Gi",
	Enums.BushidoVirtue.MEIYO: "Meiyo",
	Enums.BushidoVirtue.MAKOTO: "Makoto",
	Enums.ShouridoVirtue.SEIGYO: "Seigyo",
	Enums.ShouridoVirtue.KETSUI: "Ketsui",
	Enums.ShouridoVirtue.DOSATSU: "Dosatsu",
	Enums.ShouridoVirtue.CHISHIKI: "Chishiki",
	Enums.ShouridoVirtue.KANPEKI: "Kanpeki",
	Enums.ShouridoVirtue.ISHI: "Ishi",
	Enums.ShouridoVirtue.KYORYOKU: "Kyoryoku",
}


static func _has_issued_demand(
	character: L5RCharacterData,
	world_state: Dictionary,
) -> bool:
	var active_topics: Array = world_state.get("active_topics", [])
	for t: Variant in active_topics:
		if not (t is TopicData):
			continue
		var topic: TopicData = t as TopicData
		if topic.topic_type == "war_preparation" and topic.variant == "demand_tribute" and topic.clan_involved == character.clan:
			return true
	return false


static func _get_virtue_string(ctx: NPCDataStructures.ContextSnapshot) -> String:
	if ctx.bushido_virtue != Enums.BushidoVirtue.NONE:
		return _VIRTUE_NAMES.get(ctx.bushido_virtue, "")
	if ctx.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return _VIRTUE_NAMES.get(ctx.shourido_virtue, "")
	return ""
