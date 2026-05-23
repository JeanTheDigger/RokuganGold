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
	ctx.school = character.school
	ctx.school_type = character.school_type
	ctx.is_lord = world_state.get("is_lord", false)
	ctx.is_hostage = character.captive_status != ""
	ctx.lord_rank = CivilianOrderBudget.lord_rank_from_status(character.status)
	ctx.civilian_orders_remaining = character.civilian_orders_remaining

	# Location & situation
	ctx.location_id = character.physical_location
	if TravelSystem.is_traveling(character):
		ctx.context_flag = Enums.ContextFlag.TRAVELING
	else:
		ctx.context_flag = world_state.get("context_flag", Enums.ContextFlag.AT_OWN_HOLDINGS) as Enums.ContextFlag
	ctx.season = world_state.get("season", 0)
	ctx.ic_day = world_state.get("ic_day", 0)
	ctx.sublocation = world_state.get("sublocation", Enums.Sublocation.PUBLIC) as Enums.Sublocation
	var ws_zone_subtype: int = world_state.get("zone_subtype", -1)
	if ws_zone_subtype >= 0:
		ctx.zone_subtype = ws_zone_subtype as Enums.ZoneSubtype
		ctx.zone_flags = ZoneFlagMatrix.get_flags(ctx.zone_subtype)
	else:
		ctx.zone_flags = {}

	# Lord & court (s55.34)
	ctx.lord_id = character.lord_id
	ctx.active_court_at_location = world_state.get("active_court_at_location", {})
	ctx.upcoming_courts = world_state.get("upcoming_courts", [])
	ctx.held_leverage = world_state.get("held_leverage", [])
	ctx.known_npc_locations = world_state.get("known_npc_locations", {})
	ctx.court_session_state = world_state.get("court_session_state", {})
	ctx.court_settlement_id = world_state.get("court_settlement_id", -1)

	# Stats
	ctx.skill_ranks = character.skills.duplicate()
	# Store void ring alongside skills so subsystems (tea ceremony) can read it.
	ctx.skill_ranks["_void_ring"] = character.void_ring
	ctx.honor = character.honor
	ctx.glory = character.glory
	ctx.status = character.status
	ctx.insight_rank = CharacterStats.get_insight_rank(character)

	# Social knowledge — read through legitimate channels only (GDD s20)
	ctx.characters_present = world_state.get("characters_present", [])
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
	ctx.known_topics = character.topic_pool.duplicate()
	ctx.known_positions = character.topic_positions.duplicate()
	ctx.known_topic_types = _build_known_topic_types(
		character.topic_pool, world_state.get("active_topics", []),
	)
	ctx.known_objectives = world_state.get("known_objectives", {})
	ctx.known_contacts_by_clan = character.known_contacts_by_clan.duplicate()
	var flat_contacts: Array = []
	var clan_lookup: Dictionary = {}
	for clan_key: String in character.known_contacts_by_clan:
		for cid: int in character.known_contacts_by_clan[clan_key]:
			if cid not in flat_contacts:
				flat_contacts.append(cid)
			clan_lookup[cid] = clan_key
	ctx.known_contacts = flat_contacts
	ctx.contact_clans = clan_lookup
	ctx.met_characters = character.met_characters.duplicate()
	ctx.knowledge_pool = character.knowledge_pool.duplicate()
	ctx.known_secrets = world_state.get("known_secrets", [])

	# Lord-tier fields
	if ctx.is_lord:
		ctx.resource_stockpiles = world_state.get("resource_stockpiles", {})
		ctx.province_statuses = world_state.get("province_statuses", [])
		if ctx.province_statuses.is_empty():
			var prov_data: Array = world_state.get("province_data", [])
			var settlements_arr: Array = world_state.get("settlements", [])
			var armies_arr: Array = world_state.get("active_armies", [])
			var insurgencies_arr: Array = world_state.get("active_insurgencies", [])
			if not prov_data.is_empty():
				ctx.province_statuses = build_province_statuses_from_data(
					prov_data, settlements_arr, armies_arr, insurgencies_arr,
				)
		ctx.feasibility_data = _build_feasibility_data(character, world_state)

	# Vacancy detection (s57.20.3)
	if ctx.is_lord:
		var vkey: String = "vacant_positions_%d" % character.character_id
		var vdata: Variant = world_state.get(vkey, [])
		if vdata is Array:
			for v: Variant in vdata:
				if v is Dictionary:
					ctx.vacant_positions.append(v as Dictionary)

	# Marriage — find unmarried vassals/children for lord-tier marriage arrangement
	if ctx.is_lord and not chars_by_id.is_empty():
		ctx.marriageable_vassal_ids = _find_marriageable_vassals(
			character, chars_by_id,
		)
	if ctx.is_lord:
		ctx.lord_is_unmarried = character.spouse_id < 0
		ctx.succession_insecure = (
			character.designated_heir_id < 0
			and character.children_ids.is_empty()
		)

	# Military
	ctx.military_rank = character.military_rank
	ctx.commanded_unit_id = character.commanded_unit_id
	ctx.assigned_company_id = character.assigned_company_id

	# Military intelligence (s55.23)
	ctx.wall_statuses = world_state.get("wall_statuses", [])
	# Garrison shortage personality scores for known contacts (s2.4.12–13).
	# Only computed when the character has wall management responsibilities.
	if not ctx.wall_statuses.is_empty() and not chars_by_id.is_empty():
		for cid: int in ctx.known_contacts:
			var contact: L5RCharacterData = chars_by_id.get(cid)
			if contact != null and not CharacterStats.is_dead(contact):
				ctx.contact_garrison_scores[cid] = \
					WallSystem.compute_garrison_shortage_personality_modifier(
						contact.bushido_virtue, contact.shourido_virtue
					)
	ctx.known_clan_strengths = world_state.get("known_clan_strengths", {})
	ctx.unit_training_counts = world_state.get("unit_training_counts", {})
	ctx.available_levy_pu = world_state.get("available_levy_pu", 0.0)
	ctx.can_sustain_iron_upkeep = world_state.get("can_sustain_iron_upkeep", true)
	ctx.active_wars = world_state.get("active_wars", [])
	ctx.escalating_conflicts = world_state.get("escalating_conflicts", [])
	ctx.taint_topic_province_ids = world_state.get("taint_topic_province_ids", [])
	ctx.active_insurgency_id = world_state.get("active_insurgency_id", -1)
	ctx.famine_crisis_province_ids = _extract_famine_province_ids(
		character, world_state.get("active_topics", [])
	)

	# Infrastructure intelligence (s4.3.22) — filtered to lord's own clan
	ctx.worship_failing_province_ids = _filter_province_ids_by_clan(
		world_state.get("worship_failing_province_ids", {}), character.clan,
	)
	ctx.border_province_ids_without_fort = _filter_province_ids_by_clan(
		world_state.get("border_province_ids_without_fort", {}), character.clan,
	)
	ctx.surplus_pu_province_ids = _filter_province_ids_by_clan(
		world_state.get("surplus_pu_province_ids", {}), character.clan,
	)
	ctx.is_coastal = world_state.get("is_coastal", false)
	ctx.has_naval_assets = world_state.get("has_naval_assets", false)
	ctx.has_naval_threat = world_state.get("has_naval_threat", false)

	# Festival state (s11.5)
	ctx.is_ceasefire_day = world_state.get("is_ceasefire_day", false)
	ctx.is_labor_halt_day = world_state.get("is_labor_halt_day", false)
	ctx.is_taian = world_state.get("is_taian", false)
	ctx.is_inauspicious_for_social = world_state.get("is_inauspicious_for_social", false)
	ctx.festival_honor_gain = world_state.get("festival_honor_gain", 0.0)
	ctx.festival_has_lion_honor = world_state.get("festival_has_lion_honor", false)
	ctx.festival_glory_poetry = world_state.get("festival_glory_poetry", 0.0)
	ctx.festival_glory_martial = world_state.get("festival_glory_martial", 0.0)

	# State
	ctx.pending_events = world_state.get("pending_events", [])
	ctx.ap_remaining = character.action_points_current
	ctx.action_log = world_state.get("action_log", [])

	# TEND_WOUNDED_ALLY opportunity injection (s57.31.7).
	# Fires when: healer has Medicine 1+, has kit, wounded ally present, not yet treated today.
	if not chars_by_id.is_empty() \
			and character.skills.get("Medicine", 0) >= 1 \
			and MedicineSystem.has_medicine_kit(character):
		var best_priority: int = 0
		var best_target_id: int = -1
		for present_id: int in ctx.characters_present:
			if present_id == character.character_id:
				continue
			var candidate: L5RCharacterData = chars_by_id.get(present_id)
			if candidate == null or CharacterStats.is_dead(candidate):
				continue
			if candidate.wounds_taken <= 0:
				continue
			if candidate.last_medicine_treatment_ic_day == ctx.ic_day:
				continue
			if ctx.disposition_values.get(present_id, 0) < 0:
				continue
			var pri: int = MedicineSystem.compute_tend_priority(character, candidate)
			if pri > best_priority:
				best_priority = pri
				best_target_id = present_id
		if best_target_id >= 0:
			ctx.pending_events.append({
				"type": "tend_wounded_ally_opportunity",
				"target_npc_id": best_target_id,
				"priority": best_priority,
			})

	# Open performance request check (s57.33.3).
	if not ctx.active_court_at_location.is_empty():
		var open_requests: Array = world_state.get("pending_performance_requests", [])
		for req: Dictionary in open_requests:
			if req.get("target_performer_id", -1) >= 0:
				continue
			if RequestPerformanceSystem.can_fulfill(character, req):
				ctx.pending_events.append({
					"type": "open_performance_request",
					"request_id": req.get("request_id", -1),
					"requesting_lord_id": req.get("requesting_lord_id", -1),
					"performance_type": req.get("performance_type", ""),
					"venue_mode": req.get("venue_mode", "public"),
				})
				break

	# Personality
	ctx.bushido_virtue = character.bushido_virtue
	ctx.shourido_virtue = character.shourido_virtue

	# Urgency evaluation fields
	ctx.expiring_favor_ids = _extract_expiring_favor_ids(
		world_state.get("favors", []), character.character_id, ctx.ic_day
	)
	ctx.starvation_province_ids = _extract_starvation_province_ids(ctx.province_statuses)
	ctx.cut_supply_army_ids = _extract_cut_supply_army_ids(world_state)
	ctx.besieged_settlement_health_pct = world_state.get("besieged_settlement_health_pct", 1.0)
	ctx.objective_stalled_seasons = world_state.get("objective_stalled_seasons", 0)

	# Phoenix governance (s55.10.3.7) — set when the Champion holds autonomous authority.
	ctx.phoenix_champion_authority = world_state.get("phoenix_champion_authority", false)

	# Atonement (s4.6)
	var raw_offenses: Variant = world_state.get("self_offenses", [])
	if raw_offenses is Array:
		for off: Variant in raw_offenses:
			if off is Dictionary:
				ctx.self_offenses.append(off as Dictionary)

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

	# Void recovery — fires as fallback when pool is fully depleted and no other
	# need pressed. Full anticipation escalation (high-stakes upcoming actions)
	# is deferred: that requires queued-need inspection not yet implemented.
	var void_need := _check_void_recovery_need(character, ctx)
	if void_need != null:
		return void_need

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
	character: L5RCharacterData = null,
) -> Array:
	var options: Array = []
	var available_actions: Array = _get_actions_for_context(ctx.context_flag)
	var has_mil_rank: bool = ctx.military_rank > Enums.MilitaryRank.NONE

	if need.need_type == "RESPOND_TO_SEPPUKU":
		available_actions = ["ACCEPT_SEPPUKU", "REFUSE_SEPPUKU"]

	for action_id: String in available_actions:
		if _is_zone_blocked(action_id, ctx.zone_flags):
			continue
		if _is_military_blocked(action_id, ctx):
			continue
		if _is_lord_only_blocked(action_id, ctx):
			continue
		if ctx.is_ceasefire_day and _is_ceasefire_blocked(action_id):
			continue
		if ctx.is_labor_halt_day and _is_labor_halt_blocked(action_id):
			continue
		# RESTORE_COUNCIL_COMPACT is only available to Phoenix Champions holding
		# autonomous rule (s55.10.3.7 — only the Champion can give back the authority).
		if action_id == "RESTORE_COUNCIL_COMPACT" and not ctx.phoenix_champion_authority:
			continue
		var option := NPCDataStructures.ScoredAction.new()
		option.action_id = action_id
		option.target_npc_id = need.target_npc_id
		option.target_npc_id_secondary = need.target_npc_id_secondary
		option.target_settlement_id = need.target_settlement_id
		option.target_province_id = need.target_province_id
		option.ap_cost = _get_ap_cost(action_id)
		option.is_order = CivilianOrderBudget.is_order_action(action_id, ctx.is_lord, has_mil_rank)
		if option.is_order:
			# Dual-cost actions (SEND_INVITATION) keep 1 AP; all others drop to 0 AP.
			if not (action_id in CivilianOrderBudget.DUAL_COST_ACTIONS):
				option.ap_cost = 0
			# Filter out if no civilian orders available (military orders handled separately).
			if ctx.civilian_orders_remaining <= 0:
				if not CivilianOrderBudget.draws_from_military_pool(action_id, has_mil_rank):
					continue
		_populate_action_metadata(option, need, ctx, character)
		options.append(option)

	return options


# -- Phase 4: Personality Filter -----------------------------------------------
# Hard removal of blocked actions. No score can override this gate.

static func apply_personality_filter(
	options: Array,
	ctx: NPCDataStructures.ContextSnapshot,
	filter_data: Dictionary,
) -> Array:
	var filtered: Array = []

	for option: NPCDataStructures.ScoredAction in options:
		if _is_action_blocked(option.action_id, ctx, filter_data):
			continue
		filtered.append(option)

	return filtered


# -- Phase 4b: Allowlist Filter (s57.1) ----------------------------------------
# Only actions listed in objective_alignment.json for the current NeedType
# may enter scoring. Missing entries are BLOCKED, not scored at 0.

static func apply_allowlist_filter(
	options: Array,
	need_type: String,
	scoring_tables: Dictionary,
) -> Array:
	var alignment_table: Dictionary = scoring_tables.get("objective_alignment", {})
	var need_entry: Dictionary = alignment_table.get(need_type, {})
	if need_entry.is_empty():
		return options

	var filtered: Array = []
	for option: NPCDataStructures.ScoredAction in options:
		if need_entry.has(option.action_id):
			filtered.append(option)
	return filtered


# -- Phase 4c: APPLY_TATTOO Precondition Filter (s57.25.3) --------------------
# Removes APPLY_TATTOO if cultural reluctance blocks consent or if the
# target is a Togashi monk with unfilled ability slots (decorative gate).

static func _apply_tattoo_precondition_filter(
	options: Array,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
	world_state: Dictionary,
) -> Array:
	var has_tattoo_action: bool = false
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id == "APPLY_TATTOO":
			has_tattoo_action = true
			break
	if not has_tattoo_action:
		return options

	var tattooing_rank: int = character.skills.get("Artisan: Tattooing", 0)
	if tattooing_rank < 1:
		return _remove_action(options, "APPLY_TATTOO")

	var world_tattoos: Array = world_state.get("tattoos", [])
	var recipient_id: int = -1
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id == "APPLY_TATTOO":
			recipient_id = option.target_npc_id
			break

	var recipient: L5RCharacterData = chars_by_id.get(recipient_id)
	if recipient == null:
		return _remove_action(options, "APPLY_TATTOO")

	var available_locs: Array = TattooSystem.get_available_locations(
		world_tattoos, recipient_id, false
	)
	if available_locs.is_empty():
		return _remove_action(options, "APPLY_TATTOO")

	var is_ability: bool = false
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id == "APPLY_TATTOO":
			is_ability = option.metadata.get("is_ability_tattoo", false)
			break

	if not is_ability:
		if not TattooSystem.can_receive_decorative(
			world_tattoos, recipient_id,
			recipient.school_name, recipient.school_rank,
		):
			return _remove_action(options, "APPLY_TATTOO")

	var disp: int = ctx.dispositions.get(recipient_id, 0)
	var body_loc: Enums.TattooBodyLocation = available_locs[0]
	if not TattooSystem.check_consent(
		recipient.clan, recipient.family, body_loc, disp, false, false,
	):
		return _remove_action(options, "APPLY_TATTOO")

	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id == "APPLY_TATTOO":
			option.metadata["body_location"] = body_loc
			option.metadata["world_tattoos"] = world_tattoos
			break

	return options


static func _remove_action(
	options: Array,
	action_id: String,
) -> Array:
	var filtered: Array = []
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id != action_id:
			filtered.append(option)
	return filtered


# -- Phase 5: Score All Options ------------------------------------------------
# Eight components per s55.4.5 / s55.3.3.

static func score_all(
	options: Array,
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
	scoring_tables: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
	character: L5RCharacterData = null,
	travel_redirects: int = 0,
	chars_by_id: Dictionary = {},
) -> void:
	for option: NPCDataStructures.ScoredAction in options:
		option.objective_alignment = _lookup_objective_alignment(
			need.need_type, option.action_id, scoring_tables
		)
		option.disposition_modifier = _lookup_disposition_modifier(
			option.target_npc_id, ctx.dispositions, scoring_tables, option.action_id
		)
		option.personality_lean = _lookup_personality_lean(
			option.action_id, ctx.bushido_virtue, ctx.shourido_virtue, scoring_tables
		)
		option.competence_modifier = _compute_competence_modifier(
			option.action_id, ctx.skill_ranks, scoring_tables
		)
		option.urgency_bonus = _compute_urgency_bonus(
			option.action_id, need, ctx, scoring_tables
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
			option.commitment_at_risk = float(CommitmentRegistry.get_action_commitment_modifier(
				option.action_id, option.target_settlement_id,
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

		if option.action_id in SkillResolver.DECEPTIVE_ACTION_IDS and option.target_npc_id > 0:
			var target: L5RCharacterData = chars_by_id.get(option.target_npc_id)
			if target != null:
				option.deception_defense_penalty = float(-SkillResolver.get_deception_defense_bonus(target))

		option.festival_modifier = _compute_festival_modifier(option.action_id, ctx)

		if option.action_id in COVERT_ACTION_IDS:
			option.honor_covert_penalty = _compute_honor_covert_penalty(
				ctx.honor, ctx.school, ctx.clan
			)
			option.virtue_covert_modifier = _compute_virtue_covert_modifier(ctx)

	# Tea ceremony: +10 per eligible guest (s57.37.4 social multiplier).
	# Clan affinity bonuses (Crane +10, Phoenix +5) applied via disposition_modifier.
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id != "CONDUCT_TEA_CEREMONY":
			continue
		var guest_count: int = option.metadata.get("participant_count", 1) - 1
		option.disposition_modifier += float(guest_count * 10)
		if ctx.clan == "Crane":
			option.disposition_modifier += 10.0
		elif ctx.clan == "Phoenix":
			option.disposition_modifier += 5.0

	# ANNOUNCE_HUNT school lean (Annex C, s57.38.2):
	# Hiruma/Shinjo/Matsu/Usagi/Hida/Toritaka +15; Doji/Otomo/Soshi/Miya -15
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id != "ANNOUNCE_HUNT":
			continue
		if HuntSystem.has_hunt_positive_lean(ctx.school):
			option.disposition_modifier += float(HuntSystem.HUNT_SCHOOL_LEAN)
		elif HuntSystem.has_hunt_negative_lean(ctx.school):
			option.disposition_modifier -= float(HuntSystem.HUNT_SCHOOL_LEAN)

	# TRAIN_ANIMAL school lean (Annex C, s57.39.11):
	# Wilderness-adjacent schools +10; courtier schools -10
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id != "TRAIN_ANIMAL":
			continue
		if AnimalHandlingSystem.has_positive_school_lean(ctx.school):
			option.disposition_modifier += float(AnimalHandlingSystem.SCHOOL_LEAN_POSITIVE)
		elif AnimalHandlingSystem.has_negative_school_lean(ctx.school):
			option.disposition_modifier += float(AnimalHandlingSystem.SCHOOL_LEAN_NEGATIVE)

	# DISCERN_NEED school lean (s29.15.24): Yasuki and Doji courtiers have
	# DISCERN_NEED as a core Rank 1 technique — strong preference.
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id != "DISCERN_NEED":
			continue
		if ctx.school.begins_with("Yasuki") or ctx.school.begins_with("Doji Courtier"):
			option.disposition_modifier += 20.0
		elif ctx.school.begins_with("Kitsuki"):
			option.disposition_modifier += 10.0

	# Public Commerce school lean + honor self-regulation (Annex C, s57.40.7):
	# Mercantile schools +5 or +10 (Ide Trader); high-caste ritual schools -10; Miya -5.
	# Honor 5–6 → -3 avoid lean; Honor 7+ → -5 avoid lean. Applies only to public rolls.
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id not in ["PURCHASE_MARKET", "CONDUCT_COMMERCE"]:
			continue
		if not CommerceStigmaSystem.is_public_commerce(option.action_id, ctx):
			continue
		var school_lean: int = CommerceStigmaSystem.get_school_lean(ctx.school)
		if school_lean != 0:
			option.disposition_modifier += float(school_lean)
		if ctx.honor >= 7.0:
			option.disposition_modifier += float(CommerceStigmaSystem.HONOR_SELF_REG_7_PLUS)
		elif ctx.honor >= 5.0:
			option.disposition_modifier += float(CommerceStigmaSystem.HONOR_SELF_REG_5_6)


# -- Phase 6: Selection -------------------------------------------------------
# Highest total wins. Tiebreakers: ObjAlign > disposition > lower AP > seed.

static func select_action(
	options: Array,
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
	if chosen.ap_cost > 0:
		var result := ActionPointSystem.spend_ap(character, chosen.ap_cost)
		if not result["success"]:
			return {
				"success": false,
				"reason": "insufficient_ap",
				"action_id": chosen.action_id,
			}

	var orders_spent: int = 0
	if chosen.is_order:
		var has_mil_rank: bool = character.military_rank > Enums.MilitaryRank.NONE
		if not CivilianOrderBudget.draws_from_military_pool(chosen.action_id, has_mil_rank):
			var order_result: Dictionary = CivilianOrderBudget.spend_order(character)
			if not order_result["success"]:
				# Refund the AP already spent and abort.
				character.action_points_current += chosen.ap_cost
				return {
					"success": false,
					"reason": "insufficient_civilian_orders",
					"action_id": chosen.action_id,
				}
			orders_spent = 1

	if ResourceAvailability.has_resource_cost(chosen.action_id):
		var prov_data: Dictionary = _build_province_data_for_resource_check(ctx)
		if not ResourceAvailability.can_afford(chosen.action_id, character, prov_data):
			character.action_points_current += chosen.ap_cost
			if orders_spent > 0:
				character.civilian_orders_remaining += 1
			return {
				"success": false,
				"reason": "insufficient_resources",
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
		"orders_spent": orders_spent,
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
	approach_penalties: Array = [],
	commitments: Array = [],
	travel_redirects: int = 0,
	chars_by_id: Dictionary = {},
) -> Dictionary:
	# Phase 1
	var ctx := build_context(character, world_state, chars_by_id)

	# Phase 2
	var need := resolve_goal(character, ctx, objectives)

	# Phase 3
	var options := generate_options(ctx, need, character)

	# Phase 4
	options = apply_personality_filter(options, ctx, filter_data)
	options = apply_allowlist_filter(options, need.need_type, scoring_tables)
	options = _apply_tattoo_precondition_filter(options, character, ctx, chars_by_id, world_state)

	# Phase 5
	score_all(options, need, ctx, scoring_tables,
		approach_penalties, commitments, character, travel_redirects, chars_by_id)

	# Phase 6
	var chosen := select_action(options, ctx)

	# Phase 7
	var result: Dictionary = execute_action(chosen, character, ctx)
	result["need_source"] = need.source
	result["need_type"] = need.need_type
	return result


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
	if not event is Dictionary:
		return null
	var ev: Dictionary = event as Dictionary

	if ev.has("need_type"):
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = ev["need_type"]
		need.priority = ev.get("priority", 1)
		need.target_npc_id = ev.get("target_npc_id", -1)
		need.target_npc_id_secondary = ev.get("target_npc_id_secondary", -1)
		need.target_settlement_id = ev.get("target_settlement_id", -1)
		need.target_province_id = ev.get("target_province_id", -1)
		need.target_clan_id = ev.get("target_clan_id", "")
		need.source = ev.get("source", "reactive")
		return need

	if ev.get("type", "") == "bribery_eval":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "SUPPRESS_INVESTIGATION"
		need.priority = 2
		need.source = "bribery_eval"
		need.target_npc_id = ev.get("magistrate_id", -1)
		need.target_npc_id_secondary = ev.get("witness_id", -1)
		need.threshold = float(ev.get("evidence_total", 0))
		return need

	if ev.get("type", "") == "extortion_opportunity":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "EXTORT_ACCUSED"
		need.priority = 2
		need.source = "extortion_opportunity"
		need.target_npc_id = ev.get("suspect_id", -1)
		need.threshold = float(ev.get("evidence_total", 0))
		return need

	if ev.get("type", "") == "seppuku_offered":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "RESPOND_TO_SEPPUKU"
		need.priority = 1
		need.source = "seppuku_offered"
		need.target_intent = "case_%d" % ev.get("case_id", -1)
		return need

	if ev.get("type", "") == "witness_report_motivated":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "SEEK_MAGISTRATE"
		need.priority = 2
		need.source = "witness_report_motivated"
		need.target_npc_id = ev.get("magistrate_id", -1)
		need.target_npc_id_secondary = ev.get("criminal_id", -1)
		need.target_intent = "case_%d" % ev.get("case_id", -1)
		return need

	if ev.get("type", "") == "provocation":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "REST"
		need.priority = 3
		need.source = "provocation_received"
		need.target_npc_id = ev.get("source_id", -1)
		return need

	if ev.get("type", "") == "tend_wounded_ally_opportunity":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "TEND_WOUNDED_ALLY"
		need.priority = ev.get("priority", 1)
		need.source = "tend_wounded_ally_opportunity"
		need.target_npc_id = ev.get("target_npc_id", -1)
		return need

	if ev.get("type", "") == "performance_invitation_received":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "FULFILL_PERFORMANCE_REQUEST"
		need.priority = 2
		need.source = "performance_invitation_received"
		need.target_npc_id = ev.get("requesting_lord_id", -1)
		need.target_settlement_id = ev.get("request_id", -1)
		need.target_intent = ev.get("venue_mode", "public")
		return need

	if ev.get("type", "") == "open_performance_request":
		var need := NPCDataStructures.ImmediateNeed.new()
		need.need_type = "FULFILL_PERFORMANCE_REQUEST"
		need.priority = 1
		need.source = "open_performance_request"
		need.target_npc_id = ev.get("requesting_lord_id", -1)
		need.target_settlement_id = ev.get("request_id", -1)
		need.target_intent = ev.get("venue_mode", "public")
		return need

	return null


static func _check_void_recovery_need(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	# Fires only when pool is depleted and MEDITATE is available in context (s57.32.5).
	# Priority 3 (urgent) when pool is empty — only then overrides primary objectives.
	if character.max_void_points <= 0 or character.current_void_points > 0:
		return null
	if "MEDITATE" not in _get_actions_for_context(ctx.context_flag):
		return null
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RECOVER_VOID_POINTS"
	need.priority = 3
	need.source = "void_depleted"
	return need


static func _check_crisis_override(
	ctx: NPCDataStructures.ContextSnapshot,
	_objectives: Dictionary,
) -> NPCDataStructures.ImmediateNeed:
	if not ctx.is_lord:
		return null

	for ps: Variant in ctx.province_statuses:
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


static func _get_actions_for_context(context_flag: Enums.ContextFlag) -> Array:
	match context_flag:
		Enums.ContextFlag.AT_OWN_HOLDINGS:
			return [
				"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
				"PROBE", "READ_CHARACTER", "PUBLIC_DEBATE",
				"ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
				"TRAIN", "MEDITATE", "CONDUCT_TEA_CEREMONY",
				"ASSESS_PROVINCE_STATUS", "INVESTIGATE_PROVINCE",
				"INVESTIGATE_RUMOR", "ORDER_PATROL",
				"EXAMINE_LETTER",
				"SCOUT_ENEMY",
				"FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
				"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP",
				"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION",
				"PURIFY_TAINTED_GROUND",
				"DISPATCH_COURTIER",
				"DECLARE_WAR", "NEGOTIATE_SURRENDER",
				"COMPLY_WITH_EDICT", "DEFY_EDICT",
				"RESTORE_COUNCIL_COMPACT",
				"SHARE_SUPPLIES",
				"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID",
				"CRAFT", "MENTOR",
				"TREAT_WOUND",
				"CONDUCT_COMMERCE", "PURCHASE_MARKET",
				"EXAMINE_CRIME_SCENE",
				"REQUEST_PERFORMANCE",
				"ANNOUNCE_HUNT", "CANCEL_HUNT",
				"TRAIN_ANIMAL",
				"APPLY_TATTOO",
				"SET_TAX_RATE", "SET_STIPEND_RATE",
				"REQUEST_ART", "ASSIGN_VASSAL_OBJECTIVE",
				"ASSIGN_TO_MILITARY_SERVICE",
				"ASSIGN_GARRISON", "ORDER_LEVY",
				"ORDER_DEPLOY", "ORDER_FORTIFY",
				"SEND_INVITATION", "CALL_COURT",
				"COMMISSION_ASSASSINATION",
				"ISSUE_DUEL_CHALLENGE",
				"SHADOW_TARGET", "SEARCH_PERSON", "CONCEAL_ITEM",
				"FABRICATE_SECRET", "EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
				"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
				"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
				"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_COURT:
			return [
				"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
				"PROBE", "READ_CHARACTER", "LISTEN_REFLECT", "IMPRESS",
				"PUBLIC_DEBATE", "PUBLIC_INSULT", "PUBLIC_DECLARATION",
				"PUBLIC_PERFORMANCE", "DELIVER_GIFT", "OFFER_FAVOR",
				"PERFORM_FOR", "DISCLOSE",
				"PROVOKE_EMOTION", "PLAY_GAME", "DISCERN_NEED",
				"ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
				"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION",
				"COMPLY_WITH_EDICT", "DEFY_EDICT",
				"TRAIN", "MEDITATE", "CONDUCT_TEA_CEREMONY",
				"BRIBE_FOR_INFO", "EAVESDROP",
				"INTERCEPT_LETTER", "SEARCH_QUARTERS",
				"SHADOW_TARGET", "SEARCH_PERSON", "CONCEAL_ITEM",
				"FABRICATE_SECRET", "EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
				"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
				"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
				"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
				"EXAMINE_LETTER",
				"TREAT_WOUND",
				"REQUEST_PERFORMANCE",
				"ANNOUNCE_HUNT", "REQUEST_HUNT_INVITATION", "CANCEL_HUNT",
				"TRAIN_ANIMAL",
				"SET_TAX_RATE", "SET_STIPEND_RATE",
				"REQUEST_ART", "ASSIGN_VASSAL_OBJECTIVE",
				"SEND_INVITATION",
				"CONDUCT_COMMERCE", "PURCHASE_MARKET",
				"REQUEST_ALLIED_AID",
				"ISSUE_DUEL_CHALLENGE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.VISITING:
			return [
				"CHARM", "INTIMIDATE", "GOSSIP", "PERSUADE", "NEGOTIATE",
				"PROBE", "READ_CHARACTER", "LISTEN_REFLECT",
				"DELIVER_GIFT", "OFFER_FAVOR", "DISCERN_NEED",
				"ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
				"TRAIN", "MEDITATE", "CONDUCT_TEA_CEREMONY",
				"TREAT_WOUND",
				"ANNOUNCE_HUNT", "REQUEST_HUNT_INVITATION", "CANCEL_HUNT",
				"TRAIN_ANIMAL",
				"APPLY_TATTOO",
				"SET_TAX_RATE", "SET_STIPEND_RATE",
				"SHADOW_TARGET", "SEARCH_PERSON", "CONCEAL_ITEM",
				"FABRICATE_SECRET", "EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
				"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
				"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
				"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
				"CONDUCT_COMMERCE", "PURCHASE_MARKET",
				"EXAMINE_CRIME_SCENE",
				"ISSUE_DUEL_CHALLENGE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.TRAVELING:
			return [
				"CHANGE_DESTINATION",
				"TRAIN", "MEDITATE",
				"CANCEL_HUNT",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.ON_CAMPAIGN:
			return [
				"ORDER_BATTLE", "CONDUCT_RAID", "RAID_HARVEST",
				"DRILL_TROOPS", "EVALUATE_WAR_READINESS",
				"SCOUT_ENEMY",
				"INTIMIDATE", "NEGOTIATE",
				"TREAT_WOUND",
				"TRAIN",
				"ORDER_DEPLOY", "ORDER_FORTIFY", "ORDER_RETREAT",
				"ASSIGN_GARRISON",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.UNDER_SIEGE:
			return [
				"CONDUCT_SORTIE", "CONDUCT_STORM_ASSAULT",
				"NEGOTIATE_SURRENDER", "MAINTAIN_SIEGE",
				"TREAT_WOUND",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.IN_EXILE:
			return [
				"TRAIN", "MEDITATE",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_TEMPLE:
			return [
				"PERFORM_RITUAL", "PERFORM_WORSHIP", "MEDITATE", "CONDUCT_TEA_CEREMONY",
				"PUBLIC_ATONEMENT", "TRAIN",
				"CHARM", "PROBE", "READ_CHARACTER",
				"TREAT_WOUND",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_DOJO:
			return [
				"TRAIN", "MENTOR", "DRILL_TROOPS",
				"CHARM", "PROBE",
				"TREAT_WOUND",
				"DO_NOTHING", "REST",
			]
		Enums.ContextFlag.AT_WALL_TOWER:
			return [
				"FORTIFY_WALL_SECTION", "SEAL_WALL_BREACH",
				"CONDUCT_SORTIE",
				"SCOUT_ENEMY",
				"ASSESS_PROVINCE_STATUS",
				"DISPATCH_COURTIER",
				"TREAT_WOUND",
				"TRAIN",
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
		"CONDUCT_TEA_CEREMONY": 1,
		"CRAFT": 1,
		"DRILL_TROOPS": 1,
		"EVALUATE_WAR_READINESS": 1,
		"BRIBE_FOR_INFO": 1,
		"EAVESDROP": 1,
		"INTERCEPT_LETTER": 1,
		"SEARCH_QUARTERS": 1,
		"BEGIN_TRAVEL": 1,
		"DISPATCH_COURTIER": 1,
		"SCOUT_ENEMY": 1,
		"CONDUCT_COMMERCE": 1,
		"PURCHASE_MARKET": 1,
		"EXAMINE_CRIME_SCENE": 1,
		"ISSUE_DUEL_CHALLENGE": 1,
		"FORGE_IMPERSONATION_LETTER": 1,
		"FORGE_ORDER": 1,
		"SHARE_SUPPLIES": 1,
		"PURIFY_TAINTED_GROUND": 1,
		"FORTIFY_WALL_SECTION": 1,
		"SEAL_WALL_BREACH": 2,
		"DECLARE_WAR": 2,
		"COMPLY_WITH_EDICT": 1,
		"DEFY_EDICT": 1,
		"APPOINT_TO_POSITION": 1,
		"ARRANGE_MARRIAGE": 1,
		"FOUND_VILLAGE": 1,
		"BUILD_FORTIFICATION": 1,
		"BUILD_SHRINE": 1,
		"FOUND_TEMPLE": 1,
		"FOUND_MONASTERY": 1,
		"COMMISSION_SHIP": 1,
		"RESTORE_COUNCIL_COMPACT": 1,
		"TREAT_WOUND": 1,
		"REQUEST_PERFORMANCE": 0,
		"ANNOUNCE_HUNT": 0,
		"REQUEST_HUNT_INVITATION": 0,
		"CANCEL_HUNT": 0,
		"TRAIN_ANIMAL": 1,
		"APPLY_TATTOO": 2,
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

	if _is_conditional_blocked(action_id, ctx, filter_data):
		return true

	if action_id == "RAID_HARVEST":
		return _is_harvest_blocked_by_virtue(ctx)

	# School filter per s57.19 Annex C.
	if SCHOOL_REQUIRED_ACTIONS.has(action_id):
		var required: String = SCHOOL_REQUIRED_ACTIONS[action_id]
		if ctx.school != required:
			return true
		if action_id == "SEAL_WALL_BREACH" and ctx.insight_rank < SEAL_WALL_BREACH_MIN_RANK:
			return true

	return false


static func _is_conditional_blocked(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
	filter_data: Dictionary,
) -> bool:
	if action_id == "RAID_HARVEST":
		return false

	if ctx.bushido_virtue != Enums.BushidoVirtue.NONE:
		var virtue_name: String = Enums.bushido_virtue_name(ctx.bushido_virtue)
		var conditionals: Array = filter_data.get("bushido", {}).get(virtue_name, {}).get("conditional", [])
		for entry: Variant in conditionals:
			if entry is Dictionary:
				var target_action: String = entry.get("action", "")
				if target_action == action_id or target_action == "_ANY_ACTION":
					var condition: String = entry.get("blocked_when", "")
					if _evaluate_condition(condition, action_id, ctx):
						return true

	if ctx.shourido_virtue != Enums.ShouridoVirtue.NONE:
		var virtue_name: String = Enums.shourido_virtue_name(ctx.shourido_virtue)
		var conditionals: Array = filter_data.get("shourido", {}).get(virtue_name, {}).get("conditional", [])
		for entry: Variant in conditionals:
			if entry is Dictionary:
				var target_action: String = entry.get("action", "")
				if target_action == action_id or target_action == "_ANY_ACTION":
					var condition: String = entry.get("blocked_when", "")
					if _evaluate_condition(condition, action_id, ctx):
						return true
				if target_action == "_CHANGE_COURSE" and action_id in _CHANGE_COURSE_ACTIONS:
					var condition: String = entry.get("blocked_when", "")
					if _evaluate_condition(condition, action_id, ctx):
						return true
				if target_action == "_COMMIT_ACTION" and action_id not in _OBSERVATION_ACTIONS:
					var condition: String = entry.get("blocked_when", "")
					if _evaluate_condition(condition, action_id, ctx):
						return true

	return false


const _CHANGE_COURSE_ACTIONS: Array[String] = [
	"ABORT_RAID", "SEEK_PEACE", "NEGOTIATE_PEACE", "CHANGE_OBJECTIVE",
]

const _OBSERVATION_ACTIONS: Array[String] = [
	"OBSERVE", "EAVESDROP", "SHADOW_TARGET", "GATHER_INTELLIGENCE",
	"INVESTIGATE_PROVINCE", "EXAMINE_CRIME_SCENE",
]


static func _evaluate_condition(
	condition: String,
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	match condition:
		"war_score_above_25_and_army_capable":
			for w: Variant in ctx.active_wars:
				if w is Dictionary:
					var s: int = _get_own_war_score(w, ctx.clan)
					if s > 25:
						return true
			return false

		"any_vassal_at_shortage_or_worse":
			for key: Variant in ctx.resource_stockpiles:
				var val: Variant = ctx.resource_stockpiles[key]
				if val is Dictionary and val.get("rice_months", 12.0) < 3.0:
					return true
			return false

		"levy_would_exceed_65pct_and_no_crisis":
			if not ctx.active_wars.is_empty():
				return false
			if not ctx.starvation_province_ids.is_empty():
				return false
			if ctx.available_levy_pu <= 0.0:
				return false
			return true

		"direct_confrontation_available":
			return not ctx.characters_present.is_empty()

		"already_committed_to_action":
			return not ctx.action_log.is_empty()

		"no_intelligence_gathered_this_session":
			for entry: Dictionary in ctx.action_log:
				var aid: String = entry.get("action_id", "")
				if aid in _OBSERVATION_ACTIONS:
					return false
			return true

		"creates_obligation":
			return true

		"public_declaration_already_made":
			for entry: Dictionary in ctx.action_log:
				if entry.get("action_id", "") == "PUBLIC_DECLARATION":
					return true
			return false

		"intent_publicly_declared":
			for entry: Dictionary in ctx.action_log:
				if entry.get("action_id", "") == "PUBLIC_DECLARATION":
					return true
			return false

		"zero_motivations_known_and_urgency_below_50":
			if not ctx.known_objectives.is_empty():
				return false
			var has_urgency: bool = (
				not ctx.active_wars.is_empty()
				or not ctx.starvation_province_ids.is_empty()
				or not ctx.cut_supply_army_ids.is_empty()
				or not ctx.expiring_favor_ids.is_empty()
			)
			return not has_urgency

		"target_is_innocent_third_party":
			for npc_id: Variant in ctx.characters_present:
				var disp: float = float(ctx.disposition_values.get(npc_id, 0))
				if disp <= -31.0:
					return false
			return true

		"target_not_hated_enemy":
			for npc_id: Variant in ctx.characters_present:
				var disp: float = float(ctx.disposition_values.get(npc_id, 0))
				if disp <= -31.0:
					return false
			return true

		"not_lord_commanded":
			return not ctx.known_objectives.get("lord_assigned", false)

		"not_publicly_declared":
			for entry: Dictionary in ctx.action_log:
				if entry.get("action_id", "") == "PUBLIC_DECLARATION":
					return false
			return true

		"no_prior_formal_demand":
			for entry: Dictionary in ctx.action_log:
				var aid: String = entry.get("action_id", "")
				if aid == "DEMAND_TRIBUTE" or aid == "NEGOTIATE":
					return false
			return true

		"no_prior_grievance_or_lord_directive":
			if ctx.known_objectives.get("lord_assigned", false):
				return false
			for npc_id: Variant in ctx.characters_present:
				var disp: float = float(ctx.disposition_values.get(npc_id, 0))
				if disp <= -31.0:
					return false
			return true

		"other_paths_available":
			if not ctx.active_wars.is_empty():
				return false
			if not ctx.starvation_province_ids.is_empty():
				return false
			return true

		"would_cause_public_scene":
			return ctx.sublocation == Enums.Sublocation.PUBLIC

		"would_execute_below_standard":
			if not ctx.skill_ranks.is_empty():
				var primary: String = _get_primary_skill_for_action(action_id)
				if not primary.is_empty():
					return int(ctx.skill_ranks.get(primary, 0)) < 4
			return false

		"battle_assessed_unwinnable":
			if ctx.commanded_unit_id < 0:
				return true
			return false

		"position_not_certain":
			var observation_count: int = 0
			for entry: Dictionary in ctx.action_log:
				if entry.get("action_id", "") in _OBSERVATION_ACTIONS:
					observation_count += 1
			return observation_count < 2

		"not_all_others_declared":
			var court: Dictionary = ctx.active_court_at_location
			if court.is_empty():
				return true
			var declared_count: int = int(court.get("declarations_made", 0))
			var attendee_count: int = int(court.get("attendee_count", 1))
			return declared_count < (attendee_count - 1)

		"contradicts_lords_known_position":
			return false

		"deviates_from_lord_directive":
			return false

		"information_is_false":
			return false

		"npc_knows_declaration_is_false":
			return false

		"violates_personal_code":
			return false

		"order_violates_personal_code":
			return false

	return false


static func _get_primary_skill_for_action(action_id: String) -> String:
	var skill_map: Dictionary = {
		"ORDER_DEPLOY": "Battle",
		"PUBLIC_DECLARATION": "Courtier",
		"COMMISSION_ASSASSINATION": "Courtier",
		"SHADOW_TARGET": "Stealth",
		"SEARCH_PERSON": "Investigation",
		"CONCEAL_ITEM": "Sleight of Hand",
		"FABRICATE_SECRET": "Forgery",
		"SEDUCE": "Temptation",
		"SEDUCE_FOR_INFO": "Temptation",
		"SEDUCE_FOR_ACCESS": "Temptation",
		"SEDUCE_FOR_LEVERAGE": "Temptation",
		"SEDUCE_TO_COMPROMISE": "Temptation",
	}
	return skill_map.get(action_id, "")


static func _is_harvest_blocked_by_virtue(ctx: NPCDataStructures.ContextSnapshot) -> bool:
	var virtue: String = _get_virtue_string(ctx)
	if virtue == "JIN" or virtue == "GI":
		return true
	var hc: Dictionary = _evaluate_harvest_conditions(ctx)
	if virtue == "YU":
		return not hc.get("no_other_path", false)
	if virtue == "MEIYO":
		return not hc.get("hated_enemy", false)
	if virtue == "CHUGI":
		return not hc.get("lord_commands", false)
	if virtue == "MAKOTO":
		return not hc.get("publicly_declared", false)
	if virtue == "REI":
		return not hc.get("prior_formal_demand", false)
	return false


static func _evaluate_harvest_conditions(ctx: NPCDataStructures.ContextSnapshot) -> Dictionary:
	var no_other_path: bool = false
	for w: Variant in ctx.active_wars:
		if w is Dictionary:
			var score: int = _get_own_war_score(w, ctx.clan)
			if score < 25:
				no_other_path = true
				break

	var hated_enemy: bool = false
	for did: Variant in ctx.disposition_values:
		var val: int = ctx.disposition_values[did]
		if val <= -60:
			hated_enemy = true
			break

	var lord_commands: bool = false
	for ev: Variant in ctx.pending_events:
		if ev is Dictionary and ev.get("need_type", "") in ["RAID_HARVEST", "DESTROY_HARVEST"]:
			lord_commands = true
			break

	var publicly_declared: bool = false
	var prior_formal_demand: bool = false
	for entry: Dictionary in ctx.action_log:
		var aid: String = entry.get("action_id", "")
		if aid == "PUBLIC_DECLARATION":
			publicly_declared = true
		if aid == "DEMAND_TRIBUTE":
			prior_formal_demand = true

	return {
		"no_other_path": no_other_path,
		"hated_enemy": hated_enemy,
		"lord_commands": lord_commands,
		"publicly_declared": publicly_declared,
		"prior_formal_demand": prior_formal_demand,
	}


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


# Actions that target someone adversarially use the "hostile" disposition column.
# All others use "cooperative". Per GDD s55.4.5 / s57.3 scoring examples.
const HOSTILE_ACTIONS: Array[String] = [
	"INTIMIDATE", "PUBLIC_INSULT", "PROVOKE_EMOTION",
	"BRIBE_FOR_INFO", "EAVESDROP", "INTERCEPT_LETTER", "SEARCH_QUARTERS",
	"SHADOW_TARGET", "SEARCH_PERSON",
	"EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY", "FABRICATE_SECRET",
	"CONCEAL_ITEM",
	"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
	"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
	"COMMISSION_ASSASSINATION", "ISSUE_DUEL_CHALLENGE",
]

# Covert actions subject to the honor threshold filter (s12.8 Filter 2).
const COVERT_ACTION_IDS: Array[String] = [
	"SHADOW_TARGET", "CONCEAL_ITEM", "FABRICATE_SECRET",
	"EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
	"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
	"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
	"COMMISSION_ASSASSINATION",
	"BRIBE_FOR_INFO", "EAVESDROP",
	"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
]

# Schools with full covert honor exemption (s12.8, s46).
const _FULL_COVERT_EXEMPT_SCHOOLS: Array[String] = [
	"Shosuro Infiltrator",
	"Bitter Lies",
	"Kasuga Smuggler",
]

# Schools with half covert honor exemption (s12.8, s46).
const _HALF_COVERT_EXEMPT_SCHOOLS: Array[String] = [
	"Daidoji Harrier",
	"Daidoji Spymaster",
	"Ikoma Lion's Shadow",
]


static func _compute_honor_covert_penalty(
	honor: float, school: String, clan: String,
) -> float:
	if honor < 2.0:
		return 0.0

	var base_penalty: float = -50.0 if honor > 3.5 else -25.0

	for s: String in _FULL_COVERT_EXEMPT_SCHOOLS:
		if school.begins_with(s):
			return 0.0

	for s: String in _HALF_COVERT_EXEMPT_SCHOOLS:
		if school.begins_with(s):
			return base_penalty * 0.5

	# Scorpion Reduced Honour Bleed — clan-wide half exemption (s46).
	if clan == "Scorpion":
		return base_penalty * 0.5

	return base_penalty


static func _compute_virtue_covert_modifier(
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var threat: bool = _has_existential_threat(ctx)

	match ctx.bushido_virtue:
		Enums.BushidoVirtue.MEIYO:
			return 15.0 if threat else -15.0
		Enums.BushidoVirtue.CHUGI:
			if ctx.known_objectives.get("lord_assigned", false):
				return 10.0
			return -25.0
		Enums.BushidoVirtue.YU:
			return 10.0 if threat else -15.0

	return 0.0


static func _has_existential_threat(
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if not ctx.active_wars.is_empty():
		return true
	if not ctx.starvation_province_ids.is_empty():
		return true
	if ctx.besieged_settlement_health_pct < 1.0:
		return true
	return false


static func _lookup_disposition_modifier(
	target_npc_id: int,
	dispositions: Dictionary,
	scoring_tables: Dictionary,
	action_id: String = "",
) -> float:
	if target_npc_id < 0:
		return 0.0

	var disp_value: float = float(dispositions.get(target_npc_id, 0))
	var tiers: Array = scoring_tables.get("disposition_tiers", [])
	var column: String = "hostile" if action_id in HOSTILE_ACTIONS else "cooperative"

	for tier: Variant in tiers:
		if tier is Dictionary:
			var min_val: float = float(tier.get("min", -100))
			var max_val: float = float(tier.get("max", 100))
			if disp_value >= min_val and disp_value <= max_val:
				return float(tier.get(column, 0))

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


static func _best_skill_rank(skill_name: String, skill_ranks: Dictionary) -> int:
	if skill_name in ["Lore", "Games", "Perform", "Craft", "Artisan"]:
		var best: int = 0
		var prefix: String = skill_name + ":"
		for sk: String in skill_ranks:
			if sk.begins_with(prefix) and int(skill_ranks[sk]) > best:
				best = int(skill_ranks[sk])
		return best
	return int(skill_ranks.get(skill_name, 0))


static func _compute_competence_modifier(
	action_id: String,
	skill_ranks: Dictionary,
	scoring_tables: Dictionary,
) -> float:
	var skill_map: Dictionary = scoring_tables.get("action_skill_map", {})
	var action_skills: Dictionary = skill_map.get(action_id, {})

	var primary_raw: Variant = action_skills.get("primary", "")
	var primary_skill: String = str(primary_raw) if primary_raw != null else ""
	if primary_skill == "":
		return 0.0

	var competence_table: Dictionary = scoring_tables.get("competence_table", {})
	var rank: int = _best_skill_rank(primary_skill, skill_ranks)
	var modifier: float = float(competence_table.get(str(rank), competence_table.get(rank, -20)))

	var secondary_raw: Variant = action_skills.get("secondary", "")
	var secondary_skill: String = str(secondary_raw) if secondary_raw != null else ""
	if secondary_skill != "":
		var sec_rank: int = int(skill_ranks.get(secondary_skill, 0))
		modifier += float(competence_table.get(str(sec_rank), competence_table.get(sec_rank, -20))) * 0.5

	return clampf(modifier, -20.0, 20.0)


static func _compute_urgency_bonus(
	action_id: String,
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
	scoring_tables: Dictionary,
) -> float:
	var urgency_rules: Array = scoring_tables.get("urgency_rules", [])
	var bonus: float = 0.0

	for rule: Variant in urgency_rules:
		if not (rule is Dictionary):
			continue
		var condition: String = rule.get("condition", "")
		var rule_bonus: float = float(rule.get("bonus", 0))
		var applies_to: Variant = rule.get("applies_to", "")
		var stacks: bool = rule.get("stacks_per_crisis", false)

		var instances: Array = _evaluate_urgency_condition(condition, ctx, scoring_tables)
		if instances.is_empty():
			continue
		if not _action_matches_urgency_category(action_id, applies_to, need.need_type, scoring_tables):
			continue

		if stacks:
			for inst: Dictionary in instances:
				var relevance: float = inst.get("relevance", 1.0)
				bonus += rule_bonus * relevance
		else:
			bonus += rule_bonus

	return clampf(bonus, 0.0, 30.0)


# Returns an array of matching instances. Empty = condition not met.
# Each instance is a dict with optional "relevance" key (0.0-1.0).
static func _evaluate_urgency_condition(
	condition: String,
	ctx: NPCDataStructures.ContextSnapshot,
	_scoring_tables: Dictionary,
) -> Array:
	match condition:
		"active_crisis_in_relevance_range":
			var instances: Array = []
			for ps: Variant in ctx.province_statuses:
				if ps is NPCDataStructures.ProvinceStatus:
					var status: NPCDataStructures.ProvinceStatus = ps
					if status.active_crisis_id >= 0:
						instances.append({"relevance": 1.0, "province_id": status.province_id})
			return instances
		"war_score_below_25":
			for war: Variant in ctx.active_wars:
				if war is Dictionary:
					var score: int = _get_own_war_score(war, ctx.clan)
					if score < 25:
						return [{"relevance": 1.0}]
			return []
		"home_front_famine":
			var instances: Array = []
			for pid: int in ctx.famine_crisis_province_ids:
				instances.append({"relevance": 1.0, "province_id": pid})
			return instances
		"vassal_disposition_below_rival":
			if not ctx.is_lord:
				return []
			var instances: Array = []
			for cid: Variant in ctx.disposition_values:
				var disp: int = ctx.disposition_values[cid]
				if disp <= -11:
					instances.append({"relevance": 1.0, "npc_id": cid})
			return instances
		"court_ending_within_2_ic_days":
			var court: Dictionary = ctx.active_court_at_location
			if court.is_empty():
				return []
			var elapsed: int = court.get("elapsed_ticks", 0)
			var duration: int = court.get("duration_ticks", 999)
			if duration - elapsed <= 2:
				return [{"relevance": 1.0}]
			return []
		"home_front_hunger":
			var instances: Array = []
			for pid: int in ctx.starvation_province_ids:
				instances.append({"relevance": 1.0, "province_id": pid})
			return instances
		"army_supply_cut":
			var instances: Array = []
			for aid: int in ctx.cut_supply_army_ids:
				instances.append({"relevance": 1.0, "army_id": aid})
			return instances
		"under_siege_garrison_below_25pct":
			if ctx.besieged_settlement_health_pct < 0.25:
				return [{"relevance": 1.0}]
			return []
		"objective_stalled_2_plus_seasons":
			if ctx.objective_stalled_seasons >= 2:
				return [{"relevance": 1.0}]
			return []
		_:
			return []


# "actions_addressing_X" = any action with ObjAlign > 30 for the relevant
# NeedType(s). Per GDD s55.G schema definition.
const URGENCY_CATEGORY_NEED_TYPES: Dictionary = {
	"actions_addressing_crisis": ["DEFEND_PROVINCE", "PATROL_PROVINCE", "INVESTIGATE_THREAT"],
	"actions_addressing_war": ["LEVY_TROOPS", "DEPLOY_ARMY", "CONDUCT_SIEGE"],
	"actions_addressing_food_crisis": ["ACQUIRE_RESOURCE", "CONDUCT_COMMERCE"],
	"actions_addressing_primary_objective": [],
}

const URGENCY_EXPLICIT_ACTIONS: Dictionary = {
	"siege_end_actions": [
		"MAINTAIN_SIEGE", "CONDUCT_STORM_ASSAULT", "NEGOTIATE_SURRENDER",
		"CONDUCT_SORTIE", "ORDER_BATTLE",
	],
	"court_actions": [
		"CHARM", "PERSUADE", "NEGOTIATE", "PUBLIC_DEBATE", "PUBLIC_DECLARATION",
		"PUBLIC_PERFORMANCE", "DELIVER_GIFT", "OFFER_FAVOR", "PERFORM_FOR",
		"DISCLOSE", "ASK_FOR_INTRODUCTION", "OBSERVE_COURT_ATTENDEES",
		"GOSSIP", "IMPRESS", "LISTEN_REFLECT", "PUBLIC_INSULT",
		"INTIMIDATE", "PROBE", "READ_CHARACTER",
	],
}


static func _action_matches_urgency_category(
	action_id: String,
	applies_to: Variant,
	_current_need_type: String,
	scoring_tables: Dictionary,
) -> bool:
	if applies_to is Array:
		return action_id in applies_to

	var category: String = str(applies_to)

	if URGENCY_EXPLICIT_ACTIONS.has(category):
		return action_id in URGENCY_EXPLICIT_ACTIONS[category]

	if category == "actions_targeting_vassal":
		return true

	if category == "actions_addressing_primary_objective":
		return true

	var need_types: Array = URGENCY_CATEGORY_NEED_TYPES.get(category, [])
	if need_types.is_empty():
		return false

	var alignment_table: Dictionary = scoring_tables.get("objective_alignment", {})
	for nt: String in need_types:
		var need_entry: Dictionary = alignment_table.get(nt, {})
		var score: float = float(need_entry.get(action_id, 0))
		if score > 30.0:
			return true

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


static func _build_known_topic_types(
	topic_pool: Array,
	active_topics: Array,
) -> Dictionary:
	var result: Dictionary = {}
	for topic: Variant in active_topics:
		var tid: int = -1
		var tt: String = ""
		if topic is Dictionary:
			tid = int(topic.get("topic_id", -1))
			tt = topic.get("topic_type", "")
		elif topic is Resource:
			tid = topic.topic_id
			tt = topic.topic_type
		if tid >= 0 and tid in topic_pool and tt != "":
			result[tid] = tt
	return result


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

	var invert: bool = need.need_type == "SEEK_PEACE"
	var type_filter: Array = need_entry.get("topic_types", [])
	var best_modifier: float = 0.0
	for topic_id: int in ctx.known_topics:
		if not type_filter.is_empty():
			var tt: String = ctx.known_topic_types.get(topic_id, "")
			if not tt.is_empty() and tt not in type_filter:
				continue
		var position: float = float(ctx.known_positions.get(topic_id, 0))
		if invert:
			position = -position
		var modifier: float = _interpolate_topic_position(position, need_entry)
		if absf(modifier) > absf(best_modifier):
			best_modifier = modifier

	return clampf(best_modifier, -15.0, 15.0)


static func _interpolate_topic_position(
	position: float,
	need_entry: Dictionary,
) -> float:
	var cap_pos: float = float(need_entry.get("strong_support", 15))
	var cap_neg: float = float(need_entry.get("strong_opposition", -15))
	if position <= -50.0:
		return cap_neg
	if position >= 50.0:
		return cap_pos
	if position >= -15.0 and position <= 15.0:
		return 0.0
	if position < -15.0:
		return lerpf(0.0, cap_neg, (absf(position) - 15.0) / 35.0)
	return lerpf(0.0, cap_pos, (position - 15.0) / 35.0)


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

const GATHER_INTELLIGENCE_ACTIONS: Array[String] = [
	"PROBE", "READ_CHARACTER", "BRIBE_FOR_INFO", "EAVESDROP",
	"INTERCEPT_LETTER", "SEARCH_QUARTERS", "DISCERN_NEED",
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

# -- School Filter (s57.19 Annex C) --------------------------------------------
# Actions that require a specific school string (from L5RCharacterData.school).

const SCHOOL_REQUIRED_ACTIONS: Dictionary = {
	"FORTIFY_WALL_SECTION": "Kaiu Engineer",
	"SEAL_WALL_BREACH": "Kaiu Engineer",
	"PURIFY_TAINTED_GROUND": "Kuni Shugenja",
}

const SEAL_WALL_BREACH_MIN_RANK: int = 3

static func _is_zone_blocked(action_id: String, zone_flags: Dictionary) -> bool:
	if zone_flags.is_empty():
		return false
	# Tea ceremony requires tokonoma OR shrine_eligible (s57.37.2)
	if action_id == "CONDUCT_TEA_CEREMONY":
		return not TeaCeremonySystem.zone_allows_ceremony(zone_flags)
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
	"ASSIGN_GARRISON", "ORDER_LEVY", "ORDER_DEPLOY",
	"ORDER_FORTIFY", "ORDER_RETREAT",
]

const COMMANDER_RANK_ACTIONS: Dictionary = {
	"DISPATCH_COURTIER": Enums.MilitaryRank.SHIREIKAN,
	"ORDER_LEVY": Enums.MilitaryRank.CHUI,
}

const LORD_ONLY_ACTIONS: Array[String] = [
	"APPOINT_TO_POSITION", "DECLARE_WAR", "FOUND_VILLAGE",
	"BUILD_FORTIFICATION", "BUILD_SHRINE", "FOUND_TEMPLE",
	"FOUND_MONASTERY", "COMMISSION_SHIP", "ARRANGE_MARRIAGE",
	# Reclassified from AP to Civilian Order per s57.34.4 — lord-only
	"SET_TAX_RATE", "SET_STIPEND_RATE",
	"REQUEST_ART", "REQUEST_PERFORMANCE",
	"ASSIGN_VASSAL_OBJECTIVE", "ASSIGN_TO_MILITARY_SERVICE",
	"SEND_INVITATION", "CALL_COURT",
	"COMMISSION_ASSASSINATION",
	"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID",
]


static func _is_lord_only_blocked(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if action_id in LORD_ONLY_ACTIONS:
		return not ctx.is_lord
	return false


static func _is_military_blocked(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if action_id in MILITARY_ORDER_ACTIONS:
		# Lords can issue military-or-civilian order actions via Civilian Orders
		# even without a commanded unit (s57.34.4).
		if ctx.is_lord and action_id in CivilianOrderBudget.MILITARY_OR_CIVILIAN_ACTIONS:
			return false
		return ctx.commanded_unit_id < 0
	if COMMANDER_RANK_ACTIONS.has(action_id):
		if ctx.is_lord and action_id in CivilianOrderBudget.MILITARY_OR_CIVILIAN_ACTIONS:
			return false
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
	"FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
	"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP",
	"ORDER_LEVY", "DRILL_TROOPS",
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
	# Lords write letters via the Civilian Order Budget, not the free daily pass (s57.34.7).
	if character.civilian_order_budget_max > 0:
		return {}
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

	var topic_id: int = _pick_letter_topic(ctx)

	var visit: bool = _should_set_visit_intent(
		character, objectives, target_id, ctx
	)
	var meeting: Dictionary = _should_set_meeting_proposal(
		character, objectives, target_id, ctx
	)

	var result: Dictionary = {
		"character_id": character.character_id,
		"action_id": "WRITE_LETTER",
		"target_npc_id": target_id,
		"need_type": need_type,
		"topic_id": topic_id,
	}
	if not meeting.is_empty():
		result["meeting_proposal"] = true
		result["meeting_settlement_id"] = meeting["settlement_id"]
	elif visit:
		result["visit_intent"] = true
	return result


static func _get_letter_need_type(objectives: Dictionary) -> String:
	var primary: Dictionary = objectives.get("primary", {})
	if not primary.is_empty():
		return primary.get("need_type", "")
	var standing: Dictionary = objectives.get("standing", {})
	if not standing.is_empty():
		return standing.get("need_type", "")
	return ""


const VISIT_INTENT_NEED_TYPES: Array[String] = [
	"RAISE_DISPOSITION", "SECURE_ALLIANCE", "ARRANGE_MARRIAGE",
	"ACQUIRE_LEVERAGE", "GATHER_INTELLIGENCE",
]


static func _should_set_visit_intent(
	character: L5RCharacterData,
	objectives: Dictionary,
	letter_target_id: int,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if ctx.context_flag != Enums.ContextFlag.AT_OWN_HOLDINGS:
		return false
	var primary: Dictionary = objectives.get("primary", {})
	if primary.is_empty():
		return false
	var need_type: String = primary.get("need_type", "")
	if need_type not in VISIT_INTENT_NEED_TYPES:
		return false
	var obj_target: int = primary.get("target_npc_id", -1)
	if obj_target < 0 or obj_target != letter_target_id:
		return false
	return true


const MEETING_PROPOSAL_NEED_TYPES: Array[String] = [
	"SECURE_ALLIANCE", "ARRANGE_MARRIAGE",
]


static func _should_set_meeting_proposal(
	character: L5RCharacterData,
	objectives: Dictionary,
	letter_target_id: int,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	if ctx.context_flag != Enums.ContextFlag.AT_OWN_HOLDINGS:
		return {}
	var primary: Dictionary = objectives.get("primary", {})
	if primary.is_empty():
		return {}
	var need_type: String = primary.get("need_type", "")
	if need_type not in MEETING_PROPOSAL_NEED_TYPES:
		return {}
	var obj_target: int = primary.get("target_npc_id", -1)
	if obj_target < 0 or obj_target != letter_target_id:
		return {}
	var settlement_id: int = _pick_meeting_settlement(character, ctx)
	if settlement_id < 0:
		return {}
	return {"settlement_id": settlement_id}


static func _pick_meeting_settlement(
	character: L5RCharacterData,
	_ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var loc: String = character.physical_location
	if loc.is_valid_int():
		return loc.to_int()
	return -1


static func _select_letter_target(
	objectives: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var primary: Dictionary = objectives.get("primary", {})
	if primary.has("target_npc_id") and primary["target_npc_id"] >= 0:
		return primary["target_npc_id"]

	# Garrison shortage: prefer the known contact with the highest positive
	# personality score for responding to Wall reinforcement requests (s2.4.13).
	var need_type: String = primary.get("need_type", \
		objectives.get("standing", {}).get("need_type", ""))
	if need_type == "STRENGTHEN_WALL" and not ctx.contact_garrison_scores.is_empty():
		var best_id: int = -1
		var best_score: float = -999.0
		for cid: int in ctx.contact_garrison_scores:
			var score: float = ctx.contact_garrison_scores[cid]
			if score > best_score:
				best_score = score
				best_id = cid
		if best_id >= 0:
			return best_id

	if ctx.lord_id >= 0:
		return ctx.lord_id
	var met: Array = ctx.met_characters
	if not met.is_empty():
		return met[0]
	return -1


static func _pick_letter_topic(ctx: NPCDataStructures.ContextSnapshot) -> int:
	if ctx.known_topics.is_empty():
		return -1
	var best_id: int = -1
	var best_pos: float = -1.0
	for tid: int in ctx.known_topics:
		var pos: float = absf(ctx.known_positions.get(tid, 0.0))
		if pos > best_pos:
			best_pos = pos
			best_id = tid
	if best_id >= 0:
		return best_id
	return ctx.known_topics[0]


# -- Province Status Builder ---------------------------------------------------

static func build_province_statuses_from_data(
	province_data: Array,
	settlements: Array = [],
	active_armies: Array = [],
	active_insurgencies: Array = [],
) -> Array:
	var result: Array = []
	var settlement_garrison: Dictionary = {}
	var settlement_total_pu: Dictionary = {}
	var settlement_rice: Dictionary = {}
	for s: Variant in settlements:
		if s is SettlementData:
			var sd: SettlementData = s
			var pid: int = sd.province_id
			settlement_garrison[pid] = settlement_garrison.get(pid, 0) + sd.garrison_pu
			settlement_total_pu[pid] = settlement_total_pu.get(pid, 0) + sd.population_pu
			settlement_rice[pid] = settlement_rice.get(pid, 0.0) + sd.rice_stockpile

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
		ps.crisis_type = pd.crisis_type
		ps.active_insurgency_id = pd.active_insurgency_id
		for ins: Variant in active_insurgencies:
			if ins is InsurgencyData and ins.province_id == pd.province_id:
				ps.insurgency_type = Enums.InsurgencyType.keys()[ins.insurgency_type]
				break
		ps.last_report_ic_day = pd.last_report_ic_day
		ps.province_taint_level = pd.province_taint_level
		ps.is_wall_province = pd.shadowlands_strength > 0
		if pd.crisis_type == "famine":
			ps.starvation_stage = 1
		ps.garrison_pu = settlement_garrison.get(pd.province_id, 0)
		ps.total_settlement_pu = settlement_total_pu.get(pd.province_id, 0)
		ps.rice_stockpile = settlement_rice.get(pd.province_id, 0.0)
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
	character: L5RCharacterData = null,
) -> void:
	if option.action_id == "DECLARE_WAR":
		option.metadata = _build_declare_war_metadata(need, ctx)
	elif option.action_id == "NEGOTIATE_SURRENDER":
		option.metadata = _build_negotiate_surrender_metadata(need, ctx)
	elif option.action_id == "RAID_HARVEST":
		option.metadata = _build_raid_harvest_metadata(need, ctx)
	elif option.action_id == "BLOCKADE_TRADE_ROUTE":
		option.metadata = _build_blockade_metadata(need, ctx)
	elif option.action_id == "COMPLY_WITH_EDICT" or option.action_id == "DEFY_EDICT":
		option.metadata = _build_edict_response_metadata(need, ctx)
	elif option.action_id == "ARRANGE_MARRIAGE":
		var target_lord_id: int = need.target_npc_id_secondary
		var favor: int = _get_favor_tier_held_against(ctx, target_lord_id)
		var mil_need: bool = need.need_type in [
			"SECURE_ALLIANCE", "RAISE_ARMY", "DEFEND_PROVINCE",
		]
		option.metadata = {
			"candidate_id": need.target_npc_id,
			"target_lord_id": target_lord_id,
			"target_candidate_id": need.target_settlement_id,
			"favor_tier": favor,
			"has_military_objective": mil_need,
		}
	elif option.action_id == "APPOINT_TO_POSITION":
		option.metadata = {
			"target_npc_id": need.target_npc_id,
			"position": need.target_intent,
		}
	elif option.action_id == "PERFORM_WORSHIP":
		option.metadata = {
			"directed_fortune": need.target_npc_id if need.target_npc_id >= 0 else -1,
			"location_type": _zone_to_worship_location(ctx.zone_subtype),
		}
	elif option.action_id in ["FOUND_VILLAGE", "BUILD_FORTIFICATION", "BUILD_SHRINE",
			"FOUND_TEMPLE", "FOUND_MONASTERY", "COMMISSION_SHIP"]:
		option.metadata = {
			"province_id": need.target_province_id,
			"settlement_id": need.target_settlement_id,
			"target_intent": need.target_intent,
		}
	elif option.action_id == "GOSSIP":
		var subject: int = need.target_npc_id if need.target_npc_id >= 0 else -1
		if subject < 0:
			subject = _pick_gossip_subject(ctx)
		var split: Dictionary = _compute_gossip_raise_split(ctx)
		option.metadata = {
			"gossip_subject_id": subject,
			"damage_raises": split["damage"],
			"concealment_raises": split["concealment"],
		}
	elif option.action_id == "PUBLIC_INSULT":
		var insult_type: String = "self"
		if need.need_type == "ELIMINATE_CHARACTER":
			insult_type = "ancestors"
		elif need.need_type == "DAMAGE_RELATIONSHIP":
			insult_type = "clan"
		option.metadata = {"insult_type": insult_type}
	elif option.action_id == "INTIMIDATE":
		var target_id: int = need.target_npc_id if need.target_npc_id >= 0 else option.target_npc_id
		var secret_meta: Dictionary = _pick_secret_about_target(ctx, target_id)
		option.metadata = secret_meta
	elif option.action_id == "PLAY_GAME":
		option.metadata = {"game_skill": _pick_best_game_skill(ctx)}
	elif option.action_id in ["NEGOTIATE", "PERSUADE", "PUBLIC_DEBATE",
			"CHARM", "IMPRESS", "LISTEN_REFLECT", "OFFER_FAVOR"]:
		var court_meta: Dictionary = {
			"court_settlement_id": ctx.court_settlement_id,
			"has_topic": _has_known_agenda_topic(ctx),
			"need_type": need.need_type,
		}
		if option.action_id in ["NEGOTIATE", "PERSUADE", "PUBLIC_DEBATE"]:
			court_meta["topic_id"] = _pick_court_agenda_topic(ctx)
		if option.action_id == "NEGOTIATE":
			court_meta["session_negotiate_count"] = ctx.court_session_state.get("negotiate_count", 0)
		elif option.action_id == "CHARM":
			court_meta["session_charm_count"] = ctx.court_session_state.get("charm_count", 0)
		option.metadata = court_meta
	elif option.action_id == "ASSIGN_VASSAL_OBJECTIVE":
		option.metadata = {
			"need_type": need.need_type,
			"lord_id": ctx.character_id,
		}
		if need.target_npc_id >= 0:
			option.metadata["target_npc_id"] = need.target_npc_id
		if not need.target_intent.is_empty():
			option.metadata["target_clan"] = need.target_intent
	elif option.action_id == "DISCLOSE":
		var about_id: int = need.target_npc_id if need.target_npc_id >= 0 else -1
		var opinion: int = 0
		if about_id >= 0:
			opinion = ctx.disposition_values.get(about_id, 0)
		option.metadata = {
			"disclose_about_id": about_id,
			"disclosed_opinion": opinion,
		}
	elif option.action_id == "BRIBE_FOR_INFO" and need.source == "bribery_eval":
		option.metadata = {
			"suppress_case": true,
			"magistrate_id": need.target_npc_id,
		}
		option.target_npc_id = need.target_npc_id
	elif option.action_id == "FLEE_JURISDICTION" and need.source == "bribery_eval":
		option.metadata = {"flee_from_magistrate_id": need.target_npc_id}
	elif option.action_id in ["BRIBE_WITNESS", "INTIMIDATE_WITNESS", "KILL_WITNESS"] and need.source == "bribery_eval":
		if need.target_npc_id_secondary >= 0:
			option.target_npc_id = need.target_npc_id_secondary
			option.metadata = {"witness_id": need.target_npc_id_secondary}
	elif option.action_id == "EXTORT_ACCUSED" and need.source == "extortion_opportunity":
		option.target_npc_id = need.target_npc_id
		option.metadata = {"extort_suspect_id": need.target_npc_id}
	elif option.action_id in ["ACCEPT_SEPPUKU", "REFUSE_SEPPUKU"] and need.source == "seppuku_offered":
		var case_id_str: String = need.target_intent.replace("case_", "")
		option.metadata = {"case_id": case_id_str.to_int()}
	elif option.action_id == "BEGIN_TRAVEL" and need.source == "witness_report_motivated":
		var mag_id: int = need.target_npc_id
		var mag_loc: Variant = ctx.known_npc_locations.get(mag_id, "")
		if mag_loc is String and not (mag_loc as String).is_empty():
			option.target_settlement_id = (mag_loc as String).to_int() if (mag_loc as String).is_valid_int() else -1
			option.metadata = {"destination": mag_loc, "seek_magistrate_id": mag_id}
		else:
			option.objective_alignment = 0.0
	elif option.action_id == "WRITE_LETTER" and need.source == "witness_report_motivated":
		option.target_npc_id = need.target_npc_id
		option.metadata = {
			"report_case_id": need.target_intent.replace("case_", "").to_int(),
			"report_criminal_id": need.target_npc_id_secondary,
		}
	elif option.action_id == "EXAMINE_CRIME_SCENE":
		var active_case: Dictionary = ctx.known_objectives.get("active_case", {})
		option.metadata = {
			"case_id": active_case.get("case_id", -1),
		}
	elif option.action_id == "SEARCH_PERSON":
		var is_magistrate: bool = ctx.known_objectives.get("standing_need_type", "") == "UPHOLD_LAW"
		option.metadata = {
			"magistrate_authority": is_magistrate,
		}
	elif option.action_id == "EXAMINE_LETTER":
		option.metadata = {
			"letter_id": need.target_settlement_id if need.target_settlement_id >= 0 else -1,
		}
	elif option.action_id == "ORDER_LEVY":
		var levy_province_id: int = _pick_levy_province(ctx)
		option.target_province_id = levy_province_id
		option.metadata = {
			"levy_unit_type": _select_levy_unit_type(ctx),
		}
	elif option.action_id in ["CONDUCT_STORM_ASSAULT", "MAINTAIN_SIEGE"]:
		option.metadata = {
			"siege_settlement_id": ctx.location_id.to_int() if not ctx.location_id.is_empty() else -1,
		}
	elif option.action_id == "CONDUCT_TEA_CEREMONY":
		# Select up to (max_viable_count - 1) guests with disp >= Acquaintance.
		var void_ring: int = ctx.skill_ranks.get("_void_ring", 2)
		var tea_rank: int = ctx.skill_ranks.get("Tea Ceremony", 0)
		var max_total: int = TeaCeremonySystem.max_viable_count(void_ring, tea_rank)
		var eligible: Array = TeaCeremonySystem.select_eligible_ids(
			ctx.character_id, ctx.characters_present, ctx.dispositions
		)
		var guests: Array = []
		for eid: int in eligible:
			if guests.size() >= max_total - 1:
				break
			guests.append(eid)
		option.metadata = {
			"participant_ids": guests,
			"participant_count": 1 + guests.size(),
		}
	elif option.action_id == "OBSERVE_COURT_ATTENDEES":
		# Populate the list of attendees this NPC hasn't met yet (s55.7.3).
		var court: Dictionary = ctx.active_court_at_location
		var attendee_ids: Array = court.get("attendee_ids", [])
		var observable: Array = []
		for aid: Variant in attendee_ids:
			var aid_int: int = int(aid)
			if aid_int != ctx.character_id and aid_int not in ctx.met_characters:
				observable.append(aid_int)
		option.metadata = {"observable_attendee_ids": observable}
	elif option.action_id in ["PUBLIC_PERFORMANCE", "PERFORM_FOR"] \
			and need.need_type == "FULFILL_PERFORMANCE_REQUEST":
		option.metadata = {
			"fulfills_request_id": need.target_settlement_id,
			"requesting_lord_id": need.target_npc_id,
			"venue_mode": need.target_intent,
		}
	elif option.action_id == "ANNOUNCE_HUNT":
		# Default: hunt at need's target province (if set), else host's known location
		var province_id: int = need.target_province_id if need.target_province_id >= 0 else -1
		var hunt_date: int = ctx.ic_day + 14  # midpoint of 7–21 day window
		var priority_invitee_id: int = -1
		if need.need_type == "RAISE_DISPOSITION" and need.target_npc_id >= 0:
			priority_invitee_id = need.target_npc_id
		option.target_province_id = province_id
		option.metadata = {
			"target_province_id": province_id,
			"hunt_date_ic_day": hunt_date,
			"priority_invitee_id": priority_invitee_id,
		}
	elif option.action_id == "REQUEST_HUNT_INVITATION":
		# Hunt topic in known_topics — first active hunt topic found
		var hunt_topic_id: int = ctx.known_objectives.get("hunt_topic_id", -1)
		var host_id: int = need.target_npc_id if need.target_npc_id >= 0 else -1
		option.target_npc_id = host_id
		option.metadata = {
			"hunt_topic_id": hunt_topic_id,
			"host_id": host_id,
		}
	elif option.action_id == "CANCEL_HUNT":
		option.metadata = {
			"accepted_invitee_ids": [],
		}
	elif option.action_id == "TRAIN_ANIMAL":
		# Prefer a companion already in progress; otherwise first session with DOG default
		var in_progress_id: int = -1
		if character != null:
			for c_var: Variant in character.trained_companions:
				var comp: Dictionary = c_var as Dictionary
				if comp.get("is_alive", false) and not comp.get("fully_trained", false):
					in_progress_id = comp.get("companion_id", -1)
					break
		if in_progress_id >= 0:
			option.metadata = {
				"is_first_session": false,
				"companion_id": in_progress_id,
				"species": "",
			}
		else:
			option.metadata = {
				"is_first_session": true,
				"companion_id": -1,
				"species": "DOG",
				"companion_name": "companion",
			}
	elif option.action_id == "ASK_FOR_INTRODUCTION":
		# Intermediary: highest-disposition Friend+ contact who is not the target (s55.7.3).
		var target_id: int = option.target_npc_id
		if target_id < 0:
			target_id = need.target_npc_id
		var best_intermediary: int = -1
		var best_disp: int = 30
		for cid: Variant in ctx.disposition_values:
			var cid_int: int = int(cid)
			if cid_int == target_id or cid_int == ctx.character_id:
				continue
			var disp: int = int(ctx.disposition_values[cid])
			if disp >= 31 and disp > best_disp:
				best_disp = disp
				best_intermediary = cid_int
		option.metadata = {"intermediary_id": best_intermediary}
	elif option.action_id == "APPLY_TATTOO":
		var tattooing_rank: int = ctx.skill_ranks.get("Artisan: Tattooing", 0)
		var best_tier: Enums.TattooQualityTier = Enums.TattooQualityTier.NORMAL
		if tattooing_rank >= 5:
			best_tier = Enums.TattooQualityTier.LEGENDARY
		elif tattooing_rank >= 4:
			best_tier = Enums.TattooQualityTier.MASTERWORK
		elif tattooing_rank >= 3:
			best_tier = Enums.TattooQualityTier.EXCEPTIONAL
		elif tattooing_rank >= 2:
			best_tier = Enums.TattooQualityTier.FINE
		option.metadata = {
			"target_tier": best_tier,
			"body_location": Enums.TattooBodyLocation.LEFT_WRIST_FOREARM,
			"is_ability_tattoo": false,
			"ability": Enums.TattooAbility.NONE,
			"subject_type": Enums.TattooSubjectType.IMAGE,
			"subject_description": "",
			"subject_topic_id": -1,
		}
	elif option.action_id == "PURIFY_TAINTED_GROUND":
		var ptl: float = 0.0
		var target_prov_id: int = option.target_province_id
		for ps_var: Variant in ctx.province_statuses:
			if ps_var is NPCDataStructures.ProvinceStatus:
				var ps: NPCDataStructures.ProvinceStatus = ps_var
				if ps.province_id == target_prov_id:
					ptl = ps.province_taint_level
					break
		option.metadata = {"ptl": ptl}
	elif option.action_id == "SCOUT_ENEMY":
		var target_clan_id: String = ""
		for w: Variant in ctx.active_wars:
			if w is Dictionary:
				target_clan_id = WarSystem.get_enemy_clan_from_war(w, ctx.clan)
				if not target_clan_id.is_empty():
					break
		option.metadata = {"target_clan_id": target_clan_id}
	elif option.action_id == "DRILL_TROOPS":
		var target_company_id: int = ctx.assigned_company_id
		if target_company_id < 0:
			target_company_id = ctx.commanded_unit_id
		option.metadata = {"target_company_id": target_company_id}
	elif option.action_id == "REQUEST_PERFORMANCE":
		var target_performer_id: int = need.target_npc_id if need.target_npc_id >= 0 else -1
		option.metadata = {
			"target_performer_id": target_performer_id,
			"performance_type": "song",
			"venue_mode": "public",
		}
	elif option.action_id == "EXPOSE_SECRET_PRIVATELY":
		var best: Dictionary = _pick_best_secret(ctx, need, false)
		option.metadata = best
		if best.get("subject_id", -1) >= 0:
			option.target_npc_id = need.target_npc_id if need.target_npc_id >= 0 else _pick_private_recipient(ctx, best.get("subject_id", -1))
	elif option.action_id == "EXPOSE_SECRET_PUBLICLY":
		var best: Dictionary = _pick_best_secret(ctx, need, true)
		option.metadata = best
	elif option.action_id == "FABRICATE_SECRET":
		var sev: SecretData.Severity = _pick_fabrication_severity(ctx)
		option.metadata = {"severity": sev}
		if need.target_npc_id >= 0:
			option.target_npc_id = need.target_npc_id
	elif option.action_id == "PUBLIC_ATONEMENT":
		var best: Dictionary = _pick_best_offense(ctx)
		option.metadata = best
	elif option.action_id == "ISSUE_DUEL_CHALLENGE":
		var lethal: bool = need.need_type == "ELIMINATE_CHARACTER"
		option.metadata = {"to_death": lethal, "is_sanctioned": true}
	elif option.action_id == "CONDUCT_SORTIE":
		var sortie_meta: Dictionary = _build_sortie_metadata(ctx)
		option.metadata = sortie_meta
	elif option.action_id == "TREAT_WOUND":
		option.metadata = {"raises": _pick_medicine_raises(ctx)}
	elif option.action_id == "FORGE_IMPERSONATION_LETTER":
		option.metadata = _build_forge_letter_metadata(ctx, need)
	elif option.action_id == "FORGE_ORDER":
		option.metadata = _build_forge_order_metadata(ctx, need)


static func _build_forge_letter_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
) -> Dictionary:
	var authority: String = _forge_authority_from_lord_rank(ctx.lord_rank)
	var impersonated_id: int = need.target_npc_id
	var recipient_id: int = -1
	if need.target_npc_id_secondary >= 0:
		recipient_id = need.target_npc_id_secondary
	var topic_id: int = -1
	if not ctx.known_topics.is_empty():
		topic_id = ctx.known_topics[0]
	return {
		"authority_level": authority,
		"target_npc_id": need.target_npc_id,
		"impersonated_id": impersonated_id,
		"recipient_id": recipient_id,
		"topic_id": topic_id,
	}


static func _build_forge_order_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
) -> Dictionary:
	var authority: String = _forge_authority_from_lord_rank(ctx.lord_rank)
	var order_info: Dictionary = _pick_forged_order_type(need)
	return {
		"authority_level": authority,
		"target_npc_id": need.target_npc_id,
		"order_need_type": order_info.get("need_type", "TRAVEL_TO"),
		"order_target_province_id": order_info.get("target_province_id", -1),
		"order_target_npc_id": order_info.get("target_npc_id", -1),
		"order_target_settlement_id": order_info.get("target_settlement_id", -1),
	}


static func _pick_forged_order_type(
	need: NPCDataStructures.ImmediateNeed,
) -> Dictionary:
	match need.need_type:
		"SUPPRESS_INVESTIGATION":
			return {
				"need_type": "TRAVEL_TO",
				"target_settlement_id": need.target_settlement_id,
			}
		"ACQUIRE_LEVERAGE":
			if need.target_settlement_id >= 0:
				return {
					"need_type": "ATTEND_COURT",
					"target_settlement_id": need.target_settlement_id,
				}
			return {
				"need_type": "TRAVEL_TO",
				"target_settlement_id": -1,
			}
		"DAMAGE_RELATIONSHIP":
			if need.target_npc_id >= 0:
				return {
					"need_type": "PATROL_PROVINCE",
					"target_province_id": need.target_province_id,
				}
			return {"need_type": "TRAVEL_TO"}
		_:
			return {"need_type": "TRAVEL_TO"}


# GDD s12.8: authority level = who is being impersonated.
# PROVISIONAL: uses forger's own lord_rank as proxy (the authority
# level the forger is familiar with). Proper derivation requires
# the impersonated person's rank, blocked on target character lookup.
static func _forge_authority_from_lord_rank(
	lord_rank: Enums.LordRank,
) -> String:
	if lord_rank >= Enums.LordRank.IMPERIAL:
		return "major"
	elif lord_rank >= Enums.LordRank.FAMILY_DAIMYO:
		return "moderate"
	return "minor"


static func _pick_fabrication_severity(
	ctx: NPCDataStructures.ContextSnapshot,
) -> SecretData.Severity:
	var forgery: int = ctx.skill_ranks.get("Forgery", 0)
	if forgery >= 7:
		return SecretData.Severity.TIER_1
	elif forgery >= 5:
		return SecretData.Severity.TIER_2
	elif forgery >= 3:
		return SecretData.Severity.TIER_3
	return SecretData.Severity.TIER_4


static func _pick_medicine_raises(
	ctx: NPCDataStructures.ContextSnapshot,
) -> int:
	var rank: int = ctx.skill_ranks.get("Medicine", 0)
	if rank >= 7:
		return 3
	elif rank >= 5:
		return 2
	elif rank >= 3:
		return 1
	return 0


static func _build_sortie_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	for ws_variant: Variant in ctx.wall_statuses:
		if not ws_variant is NPCDataStructures.WallStatus:
			continue
		var ws: NPCDataStructures.WallStatus = ws_variant as NPCDataStructures.WallStatus
		return {"ss": ws.ss, "force_size": ""}
	return {"ss": -1, "force_size": ""}


static func _pick_best_offense(
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var best_tier: int = 5
	var best: Dictionary = {"offense_key": "", "offense_tier": 3}
	for off: Dictionary in ctx.self_offenses:
		var tier: int = off.get("offense_tier", 4)
		if tier < best_tier:
			best_tier = tier
			best = off
	return best


static func _pick_best_secret(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	_public: bool,
) -> Dictionary:
	var best_sev: int = 999
	var best: Dictionary = {"secret_ref": null, "subject_id": -1, "has_proof": false}
	for sd: Variant in ctx.known_secrets:
		if not sd is Dictionary:
			continue
		var d: Dictionary = sd as Dictionary
		var ref: Variant = d.get("_secret_ref")
		if ref == null:
			continue
		if ref is SecretData and (ref as SecretData).exposed:
			continue
		var subj: int = d.get("subject_id", -1)
		if subj < 0 or subj == ctx.character_id:
			continue
		if need.target_npc_id >= 0 and subj != need.target_npc_id:
			continue
		var sev: int = d.get("severity", 0)
		if sev < best_sev:
			best_sev = sev
			best = {
				"secret_ref": ref,
				"subject_id": subj,
				"has_proof": d.get("has_proof", false),
			}
	return best


static func _pick_private_recipient(
	ctx: NPCDataStructures.ContextSnapshot,
	subject_id: int,
) -> int:
	for pid: int in ctx.characters_present:
		if pid != ctx.character_id and pid != subject_id:
			return pid
	return -1


const _GAME_SKILLS: Array[String] = [
	"Games: Go", "Games: Shogi", "Games: Kemari",
	"Games: Fortunes & Winds", "Games: Letters", "Games: Sadane",
]


static func _pick_best_game_skill(
	ctx: NPCDataStructures.ContextSnapshot,
) -> String:
	var best_skill: String = "Games: Go"
	var best_rank: int = 0
	for gs: String in _GAME_SKILLS:
		var rank: int = ctx.skill_ranks.get(gs, 0)
		if rank > best_rank:
			best_rank = rank
			best_skill = gs
	return best_skill


static func _get_favor_tier_held_against(
	ctx: NPCDataStructures.ContextSnapshot,
	target_lord_id: int,
) -> int:
	var best_tier: int = 0
	for lev: Variant in ctx.held_leverage:
		if not lev is Dictionary:
			continue
		var d: Dictionary = lev as Dictionary
		var debtor: int = d.get("debtor_id", -1)
		var lord: int = d.get("target_lord_id", -1)
		if debtor == target_lord_id or lord == target_lord_id:
			var tier: int = d.get("tier", 0)
			if tier > best_tier:
				best_tier = tier
	return best_tier


static func _pick_secret_about_target(
	ctx: NPCDataStructures.ContextSnapshot,
	target_id: int,
) -> Dictionary:
	var best_sev: int = 999
	var best_ref: Variant = null
	for sd: Variant in ctx.known_secrets:
		if not sd is Dictionary:
			continue
		var d: Dictionary = sd as Dictionary
		var ref: Variant = d.get("_secret_ref")
		if ref == null:
			continue
		if ref is SecretData and (ref as SecretData).exposed:
			continue
		var subj: int = d.get("subject_id", -1)
		if subj != target_id:
			continue
		var sev: int = d.get("severity", 0)
		if sev < best_sev:
			best_sev = sev
			best_ref = ref
	if best_ref != null:
		return {
			"secret_ref": best_ref,
			"secret_tier": best_sev,
			"by_letter": false,
		}
	return {}


static func _has_known_agenda_topic(ctx: NPCDataStructures.ContextSnapshot) -> bool:
	var court: Dictionary = ctx.active_court_at_location
	if court.is_empty():
		return false
	var topics: Array = court.get("topics", [])
	for t: Variant in topics:
		if int(t) in ctx.known_topics:
			return true
	return false


static func _pick_court_agenda_topic(ctx: NPCDataStructures.ContextSnapshot) -> int:
	var court: Dictionary = ctx.active_court_at_location
	if court.is_empty():
		return -1
	var topics: Array = court.get("topics", [])
	if topics.is_empty():
		return -1
	var best_id: int = int(topics[0])
	var best_score: float = -1.0
	for t: Variant in topics:
		var tid: int = int(t)
		if tid not in ctx.known_topics:
			continue
		var pos: float = absf(ctx.known_positions.get(tid, 0.0))
		if pos > best_score:
			best_score = pos
			best_id = tid
	return best_id


static func _pick_gossip_subject(ctx: NPCDataStructures.ContextSnapshot) -> int:
	var worst_id: int = -1
	var worst_disp: int = 0
	for cid: Variant in ctx.disposition_values:
		if int(cid) == ctx.character_id:
			continue
		var disp: int = ctx.disposition_values[cid]
		if disp < worst_disp:
			worst_disp = disp
			worst_id = int(cid)
	return worst_id


static func _compute_gossip_raise_split(
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	if ctx.school.begins_with("Bayushi Courtier"):
		return {"damage": 99, "concealment": 0}
	if ctx.bushido_virtue in [
		Enums.BushidoVirtue.GI,
		Enums.BushidoVirtue.MAKOTO,
		Enums.BushidoVirtue.MEIYO,
	]:
		return {"damage": 99, "concealment": 0}
	if ctx.shourido_virtue in [
		Enums.ShouridoVirtue.SEIGYO,
		Enums.ShouridoVirtue.DOSATSU,
		Enums.ShouridoVirtue.CHISHIKI,
	]:
		return {"damage": 98, "concealment": 1}
	if ctx.clan == "Scorpion":
		return {"damage": 98, "concealment": 1}
	return {"damage": 99, "concealment": 0}


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


static func _build_raid_harvest_metadata(
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var target_province: int = need.target_province_id
	var target_clan: String = need.target_clan_id
	if target_clan.is_empty():
		for ps: Variant in ctx.province_statuses:
			if ps is NPCDataStructures.ProvinceStatus:
				var status: NPCDataStructures.ProvinceStatus = ps
				if status.province_id == target_province and not status.clan.is_empty():
					target_clan = status.clan
					break
	return {
		"target_province_id": target_province,
		"target_clan": target_clan,
		"ordering_clan": ctx.clan,
	}


static func _build_blockade_metadata(
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var target_clan: String = need.target_clan_id
	return {
		"route_id": -1,
		"blocking_clan": ctx.clan,
		"target_clan": target_clan,
	}


static func _build_edict_response_metadata(
	need: NPCDataStructures.ImmediateNeed,
	_ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	return {
		"edict_id": need.target_npc_id,
		"target_clan": need.target_clan_id,
	}


static func _build_feasibility_data(
	character: L5RCharacterData,
	world_state: Dictionary,
) -> Dictionary:
	var settlements: Array = world_state.get("settlements", [])
	var provinces: Array = world_state.get("province_data", [])
	var clans: Array = world_state.get("clans", [])

	var controlled: Array = []
	var clan_province_ids: Array = []
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
		if CharacterStats.is_dead(ch):
			continue
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


# TODO: Filter trade routes by clan — requires province-to-clan mapping.
static func _has_active_trade_routes(trade_routes: Array, _clan: String) -> bool:
	for r: Variant in trade_routes:
		if r is TradeRouteData:
			var route: TradeRouteData = r
			if not route.is_disrupted:
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
		if CharacterStats.is_dead(ch):
			continue
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
		var ally_prov_ids: Array = []
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


static func _get_own_war_score(war: Dictionary, clan: String) -> int:
	if war.get("clan_a", "") == clan:
		return war.get("war_score_a", 50)
	if war.get("clan_b", "") == clan:
		return war.get("war_score_b", 50)
	return 50


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
		return Enums.bushido_virtue_name(ctx.bushido_virtue)
	if ctx.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return Enums.shourido_virtue_name(ctx.shourido_virtue)
	return ""


static func _zone_to_worship_location(zone: Enums.ZoneSubtype) -> String:
	match zone:
		Enums.ZoneSubtype.CASTLE_SHRINE:
			return "village_shrine"
		Enums.ZoneSubtype.SHRINE_CLEARING:
			return "roadside_shrine"
		Enums.ZoneSubtype.TEMPLE_GROUNDS:
			return "local_shrine"
	return "roadside_shrine"


static func _pick_levy_province(ctx: NPCDataStructures.ContextSnapshot) -> int:
	var best_id: int = -1
	var best_pu: int = -1
	for ps: Variant in ctx.province_statuses:
		if not ps is NPCDataStructures.ProvinceStatus:
			continue
		var pid: int = (ps as NPCDataStructures.ProvinceStatus).province_id
		var pu: int = (ps as NPCDataStructures.ProvinceStatus).total_settlement_pu
		if pu > best_pu:
			best_pu = pu
			best_id = pid
	return best_id


static func _select_levy_unit_type(ctx: NPCDataStructures.ContextSnapshot) -> int:
	if not ctx.can_sustain_iron_upkeep:
		return Enums.CompanyUnitType.PEASANT_LEVY

	var spear_count: int = ctx.unit_training_counts.get(
		Enums.CompanyUnitType.ASHIGARU_SPEARMEN, 0,
	)
	var archer_count: int = ctx.unit_training_counts.get(
		Enums.CompanyUnitType.ASHIGARU_ARCHERS, 0,
	)
	if spear_count >= 2 and archer_count == 0:
		return Enums.CompanyUnitType.ASHIGARU_ARCHERS

	return Enums.CompanyUnitType.ASHIGARU_SPEARMEN


static func _filter_province_ids_by_clan(
	province_clan_map: Variant,
	clan: String,
) -> Array:
	var result: Array = []
	if province_clan_map is Dictionary:
		for pid: Variant in province_clan_map:
			if province_clan_map[pid] == clan:
				result.append(int(pid))
	elif province_clan_map is Array:
		# Backward compatibility: plain array without clan filtering
		for pid: Variant in province_clan_map:
			result.append(int(pid))
	return result


static func _extract_famine_province_ids(
	character: L5RCharacterData,
	active_topics: Array,
) -> Array:
	var result: Array = []
	var known: Array = character.topic_pool
	for t: Variant in active_topics:
		if not (t is TopicData):
			continue
		var topic: TopicData = t as TopicData
		if topic.resolved:
			continue
		if topic.topic_type != "famine":
			continue
		if topic.topic_id not in known:
			continue
		for pid: int in topic.provinces_affected:
			if pid not in result:
				result.append(pid)
	return result


static func _extract_expiring_favor_ids(
	favors: Array,
	character_id: int,
	ic_day: int,
) -> Array:
	var result: Array = []
	# 7 OOC days = 28 IC days (4 IC days per OOC day)
	var threshold: int = 28
	for f: Variant in favors:
		if not (f is FavorData):
			continue
		var favor: FavorData = f as FavorData
		if favor.debtor_id != character_id:
			continue
		if favor.invoked:
			var deadline: int = favor.response_deadline_ic_day
			if deadline >= 0 and (deadline - ic_day) <= threshold:
				result.append(favor.favor_id)
	return result


static func _extract_starvation_province_ids(
	province_statuses: Array,
) -> Array:
	var result: Array = []
	for ps: Variant in province_statuses:
		if ps is NPCDataStructures.ProvinceStatus:
			var status: NPCDataStructures.ProvinceStatus = ps
			if status.starvation_stage > 0:
				result.append(status.province_id)
	return result


static func _extract_cut_supply_army_ids(
	world_state: Dictionary,
) -> Array:
	var result: Array = []
	var tethers: Array = world_state.get("active_tethers", [])
	for t: Variant in tethers:
		if t is Dictionary:
			if t.get("overall_state", 0) == SupplyTetherSystem.TetherState.BROKEN:
				var aid: int = t.get("army_id", -1)
				if aid >= 0:
					result.append(aid)
	return result


static func _find_marriageable_vassals(
	lord: L5RCharacterData,
	chars_by_id: Dictionary,
) -> Array:
	var result: Array = []
	for cid: int in chars_by_id:
		var c: L5RCharacterData = chars_by_id[cid] as L5RCharacterData
		if c == null:
			continue
		if c.character_id == lord.character_id:
			continue
		if c.spouse_id >= 0:
			continue
		if CharacterStats.is_dead(c):
			continue
		var is_vassal: bool = c.lord_id == lord.character_id
		var is_child: bool = lord.children_ids.has(c.character_id)
		if not is_vassal and not is_child:
			continue
		result.append(c.character_id)
	return result
