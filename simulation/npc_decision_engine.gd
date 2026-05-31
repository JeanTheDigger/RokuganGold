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
			var other_char: L5RCharacterData = chars_by_id.get(other_id)
			if other_char == null or CharacterStats.is_dead(other_char):
				continue
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
	ctx.known_topic_momentums = _build_known_topic_momentums(
		character.topic_pool, world_state.get("active_topics", []),
	)
	ctx.known_topic_subjects = _build_known_topic_subjects(
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

	# Champion conclusion combined pool (s57.54.10b) — Family Daimyo+.
	if ctx.is_lord and ctx.lord_rank >= Enums.LordRank.FAMILY_DAIMYO:
		ctx.champion_conclusion_candidates = world_state.get("champion_conclusion_candidates", [])
		ctx.local_tier3_candidates = world_state.get("local_tier3_candidates", [])

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
# Standard cascade: Reactive Event > Crisis Override > Primary Objective >
# Standing Objective.
# For lord-tier characters, amended cascade per GDD s57.54.10b:
# Reactive Event > Crisis Override > Combined Pool (Champion conclusions +
# local Tier 3 needs) > Opportunity Scanner > Standing Objective.

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

	# Family Daimyo tier: Combined Pool (Champion conclusions + local Tier 3 needs)
	# replaces the Primary Objective step per s57.54.10b. Only FAMILY_DAIMYO uses
	# this pool — Champion/Imperial have no conclusions injected and use the
	# standard primary path. An externally assigned primary still takes precedence.
	if ctx.is_lord and ctx.lord_rank == Enums.LordRank.FAMILY_DAIMYO:
		var primary: Dictionary = objectives.get("primary", {})
		var has_lord_assigned_primary: bool = (
			primary.size() > 0
			and primary.get("assigned_by", -1) >= 0
			and primary.get("assigned_by", -1) != character.character_id
		)
		if has_lord_assigned_primary:
			var primary_need := _decompose_objective(primary, ctx)
			if primary_need != null:
				return primary_need
		var combined_need := _check_combined_pool(ctx, objectives)
		if combined_need != null:
			return combined_need
	else:
		# Standard primary objective step (non-lord-tier, Champion, and Imperial).
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


## Combined pool for lord-tier characters (s57.54.10b).
## Champion conclusions and local Tier 3 needs compete for the highest score.
## Returns the winning ImmediateNeed, or null if no viable candidate.
static func _check_combined_pool(
	ctx: NPCDataStructures.ContextSnapshot,
	objectives: Dictionary,
) -> NPCDataStructures.ImmediateNeed:
	var champion_candidates: Array = ctx.champion_conclusion_candidates
	var local_candidates: Array = ctx.local_tier3_candidates

	# Merge and find highest-scoring candidate.
	var all_candidates: Array = []
	for c: Dictionary in champion_candidates:
		all_candidates.append(c)
	for c: Dictionary in local_candidates:
		all_candidates.append(c)
	if all_candidates.is_empty():
		return null

	var best: Dictionary = {}
	var best_score: int = -1
	for c: Dictionary in all_candidates:
		var s: int = c.get("score", 0)
		if s > best_score:
			best_score = s
			best = c

	if best.is_empty() or best_score <= 0:
		return null

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = best.get("need_type", "")
	need.priority = 2
	need.source = best.get("source", "combined_pool")
	need.target_clan_id = best.get("target_clan_id", "")
	return need


# -- Phase 3: Generate Options -------------------------------------------------
# Lists every ActionID available given the ContextFlag.

static func generate_options(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	character: L5RCharacterData = null,
	chars_by_id: Dictionary = {},
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
		# DISSOLVE_MARRIAGE requires Family Daimyo or higher (s57.49.7).
		if action_id == "DISSOLVE_MARRIAGE" and ctx.lord_rank < Enums.LordRank.FAMILY_DAIMYO:
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
		_populate_action_metadata(option, need, ctx, character, chars_by_id)
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


# -- Phase 4c: Origami Precondition Filter (s57.26) ----------------------------
# Removes CRAFT when character lacks Artisan: Origami.
# Removes DECLARE_SENBAZURU when an active senbazuru already exists.
# Removes PRESENT_SENBAZURU when no complete senbazuru is ready.

static func _apply_origami_precondition_filter(
	options: Array,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Array:
	# CRAFT: remove if the character has no Artisan: Origami skill.
	# (Other CRAFT uses via s49 are non-functional for NPCs; origami is the only path.)
	var origami_rank: int = character.skills.get("Artisan: Origami", 0)
	if origami_rank < 1:
		options = _remove_action(options, "CRAFT")

	var active_id: int = ctx.known_objectives.get("active_senbazuru_id", -1)
	var is_complete: bool = ctx.known_objectives.get("senbazuru_is_complete", false)

	# DECLARE_SENBAZURU: blocked while an active senbazuru already exists.
	if active_id >= 0:
		options = _remove_action(options, "DECLARE_SENBAZURU")

	# PRESENT_SENBAZURU: blocked unless active senbazuru is complete.
	if not is_complete:
		options = _remove_action(options, "PRESENT_SENBAZURU")

	return options


# -- Phase 4c: Garden / Bonsai Precondition Filter (s57.23a) ------------------
# Removes garden and bonsai actions when required state is absent.

static func _apply_garden_precondition_filter(
	options: Array,
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Array:
	# CULTIVATE_GARDEN: requires an active commission and Artisan: Gardening rank ≥ 1.
	var commission_id: int = ctx.known_objectives.get("active_commission_id", -1)
	var gardening_rank: int = character.skills.get("Artisan: Gardening", 0)
	if commission_id < 0 or gardening_rank < 1:
		options = _remove_action(options, "CULTIVATE_GARDEN")

	# MAINTAIN_GARDEN: requires a local garden and Artisan: Gardening rank ≥ 1.
	var local_garden_id: int = ctx.known_objectives.get("local_garden_id", -1)
	if local_garden_id < 0 or gardening_rank < 1:
		options = _remove_action(options, "MAINTAIN_GARDEN")

	# OFFER_ART_COMMISSION: requires a garden zone available at this settlement.
	if not ctx.known_objectives.get("garden_zone_available", false):
		options = _remove_action(options, "OFFER_ART_COMMISSION")

	# TEND_BONSAI / DISPLAY_BONSAI: requires an owned bonsai.
	var owned_bonsai_id: int = ctx.known_objectives.get("owned_bonsai_id", -1)
	if owned_bonsai_id < 0:
		options = _remove_action(options, "TEND_BONSAI")
		options = _remove_action(options, "DISPLAY_BONSAI")

	# DISPLAY_BONSAI: also requires bonsai_display_eligible flag.
	if not ctx.known_objectives.get("bonsai_display_eligible", false):
		options = _remove_action(options, "DISPLAY_BONSAI")

	# COLLECT_BONSAI_SPECIMEN: requires Artisan: Gardening rank ≥ 1.
	if gardening_rank < 1:
		options = _remove_action(options, "COLLECT_BONSAI_SPECIMEN")

	return options


static func _build_garden_commission_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	chars_by_id: Dictionary,
	is_request: bool,
) -> Dictionary:
	## REQUEST_ART: select available artisan with Artisan: Gardening, pick open zone.
	## OFFER_ART_COMMISSION: pick the settlement lord as daimyo target, pick open zone.
	var loc_int: int = int(ctx.location_id) if ctx.location_id.is_valid_int() else -1
	var zone_type: String = ctx.known_objectives.get("available_garden_zone", "")
	var quality_tier: int = clampi(
		ctx.skill_ranks.get("Artisan: Gardening", 1), 1, 5
	)

	if is_request:
		# Daimyo picks an artisan — prefer the need target if available.
		var artisan_id: int = need.target_npc_id if need.target_npc_id >= 0 else -1
		if artisan_id < 0:
			for cid: Variant in ctx.disposition_values:
				var c_int: int = int(cid)
				var c_char: L5RCharacterData = chars_by_id.get(c_int)
				if c_char == null or CharacterStats.is_dead(c_char):
					continue
				if c_char.skills.get("Artisan: Gardening", 0) >= 1:
					artisan_id = c_int
					break
		return {
			"artisan_id": artisan_id,
			"daimyo_id": ctx.character_id,
			"settlement_id": loc_int,
			"zone_type": zone_type,
			"target_quality_tier": quality_tier,
		}
	else:
		# Artisan offers: pick the lord of the current settlement as daimyo.
		var daimyo_id: int = need.target_npc_id if need.target_npc_id >= 0 else -1
		return {
			"artisan_id": ctx.character_id,
			"daimyo_id": daimyo_id,
			"settlement_id": loc_int,
			"zone_type": zone_type,
			"target_quality_tier": quality_tier,
		}


# -- Phase 4c: TERMINATE_CONTRACT Precondition Filter (s52.8 A79) -------------
# Removes TERMINATE_CONTRACT when the lord has no active contracts.

static func _apply_terminate_contract_precondition_filter(
	options: Array,
	world_state: Dictionary,
) -> Array:
	var has_action: bool = false
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id == "TERMINATE_CONTRACT":
			has_action = true
			break
	if not has_action:
		return options
	if world_state.get("has_active_contracts", false):
		return options
	return _remove_action(options, "TERMINATE_CONTRACT")


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

	# §57.22.12/13 COMPOSE_THEATER_PIECE political scoring modifiers.
	# Base alignment score 60 comes from objective_alignment.json for DAMAGE_RELATIONSHIP
	# and MOVE_TOPIC_POSITION. These post-loop modifiers adjust based on context.
	for option: NPCDataStructures.ScoredAction in options:
		if option.action_id != "COMPOSE_THEATER_PIECE":
			continue
		var political_need: bool = need.need_type in ["DAMAGE_RELATIONSHIP", "MOVE_TOPIC_POSITION"]
		if not political_need:
			continue
		var poetry_rank: int = ctx.skill_ranks.get("Poetry", 0)
		if poetry_rank < 1:
			continue

		# §57.22.13: AT_COURT with no viable pieces → override alignment to 40 (fallback trigger).
		# This is intentionally lower than the standard 60 to reflect that composition at court
		# competes against immediate social options.
		var has_viable_pieces: bool = not ctx.known_objectives.get(
			"theater_pieces_to_perform", []
		).is_empty()
		if ctx.context_flag == "AT_COURT" and not has_viable_pieces:
			option.objective_alignment = 40.0

		# §57.22.12: +20 if not AT_COURT (writing is available regardless of location)
		if ctx.context_flag != "AT_COURT":
			option.disposition_modifier += 20.0

		# §57.22.12: +15 if active topic matching intended subject has momentum > 40
		var intended_subject: String = option.metadata.get("subject", ctx.clan)
		var subject_type: int = option.metadata.get("subject_type", TheaterSystem.SubjectType.CLAN)
		for tid: int in ctx.known_topic_momentums:
			var momentum: int = ctx.known_topic_momentums.get(tid, 0)
			if momentum <= 40:
				continue
			var subj_data: Dictionary = ctx.known_topic_subjects.get(tid, {})
			var match_found: bool = false
			match subject_type:
				TheaterSystem.SubjectType.CLAN:
					match_found = (subj_data.get("clan", "") == intended_subject)
				TheaterSystem.SubjectType.FAMILY:
					match_found = (subj_data.get("family", "") == intended_subject)
				TheaterSystem.SubjectType.CHARACTER:
					if intended_subject.is_valid_int():
						match_found = (subj_data.get("char_id", -1) == int(intended_subject))
			if match_found:
				option.disposition_modifier += 15.0
				break  # one matching topic is sufficient

		# §57.22.12: -20 if no audience (no co-located named characters in zone)
		if ctx.characters_present.is_empty():
			option.disposition_modifier -= 20.0


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
	var options := generate_options(ctx, need, character, chars_by_id)

	# Phase 4
	options = apply_personality_filter(options, ctx, filter_data)
	options = apply_allowlist_filter(options, need.need_type, scoring_tables)
	options = _apply_tattoo_precondition_filter(options, character, ctx, chars_by_id, world_state)
	options = _apply_terminate_contract_precondition_filter(options, world_state)
	options = _apply_origami_precondition_filter(options, character, ctx)
	options = _apply_garden_precondition_filter(options, character, ctx)

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
				"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION", "DISSOLVE_MARRIAGE",
				"PURIFY_TAINTED_GROUND",
				"DISPATCH_COURTIER",
				"DECLARE_WAR", "NEGOTIATE_SURRENDER",
				"COMPLY_WITH_EDICT", "DEFY_EDICT",
				"RESTORE_COUNCIL_COMPACT",
				"SHARE_SUPPLIES", "TRANSFER_KOKU",
				"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID",
				"MENTOR",
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
				"INVOKE_FAVOR",
				"ISSUE_DUEL_CHALLENGE",
				"SHADOW_TARGET", "SEARCH_PERSON", "CONCEAL_ITEM",
				"FABRICATE_SECRET", "EXPOSE_SECRET_PRIVATELY", "EXPOSE_SECRET_PUBLICLY",
				"FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
				"SEDUCE", "SEDUCE_FOR_INFO", "SEDUCE_FOR_ACCESS",
				"SEDUCE_FOR_LEVERAGE", "SEDUCE_TO_COMPROMISE",
				"COMPOSE_THEATER_PIECE", "LEARN_THEATER_PIECE",
				"PERFORM_THEATER_PIECE", "DEDICATE_PIECE",
				"ACCEPT_RONIN_PETITION",
				"HIRE_RONIN",
				"PERFORM_CLAN_INDUCTION",
				"APPROVE_CLAN_INDUCTION",
				"TERMINATE_CONTRACT",
				"CRAFT",
				"CULTIVATE_GARDEN", "MAINTAIN_GARDEN",
				"COLLECT_BONSAI_SPECIMEN", "TEND_BONSAI", "DISPLAY_BONSAI",
				"OFFER_ART_COMMISSION",
				"DECLARE_SENBAZURU", "PRESENT_SENBAZURU",
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
				"ARRANGE_MARRIAGE", "APPOINT_TO_POSITION", "DISSOLVE_MARRIAGE",
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
				"TRANSFER_KOKU",
				"INVOKE_FAVOR",
				"ISSUE_DUEL_CHALLENGE",
				"COMPOSE_THEATER_PIECE", "LEARN_THEATER_PIECE",
				"PERFORM_THEATER_PIECE", "DEDICATE_PIECE",
				"APPROVE_CLAN_INDUCTION",
				"CRAFT",
				"OFFER_ART_COMMISSION", "TEND_BONSAI", "DISPLAY_BONSAI",
				"DECLARE_SENBAZURU", "PRESENT_SENBAZURU",
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
				"INVOKE_FAVOR",
				"ISSUE_DUEL_CHALLENGE",
				"COMPOSE_THEATER_PIECE", "LEARN_THEATER_PIECE",
				"PERFORM_THEATER_PIECE", "DEDICATE_PIECE",
				"PETITION_RONIN",
				"HIRE_RONIN",
				"TERMINATE_CONTRACT",
				"CRAFT",
				"CULTIVATE_GARDEN", "TEND_BONSAI", "DISPLAY_BONSAI",
				"DECLARE_SENBAZURU", "PRESENT_SENBAZURU",
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
	"TRANSFER_KOKU": 1,
		"PURIFY_TAINTED_GROUND": 1,
		"FORTIFY_WALL_SECTION": 1,
		"SEAL_WALL_BREACH": 2,
		"DECLARE_WAR": 2,
		"COMPLY_WITH_EDICT": 1,
		"DEFY_EDICT": 1,
		"APPOINT_TO_POSITION": 1,
		"ACCEPT_RONIN_PETITION": 1,
		"PETITION_RONIN": 1,
		"HIRE_RONIN": 1,
		"PERFORM_CLAN_INDUCTION": 2,
		"APPROVE_CLAN_INDUCTION": 0,
		"TERMINATE_CONTRACT": 0,
		"ARRANGE_MARRIAGE": 1,
		"DISSOLVE_MARRIAGE": 1,
		"FOUND_VILLAGE": 1,
		"BUILD_FORTIFICATION": 1,
		"BUILD_SHRINE": 1,
		"FOUND_TEMPLE": 1,
		"FOUND_MONASTERY": 1,
		"COMMISSION_SHIP": 1,
		"RESTORE_COUNCIL_COMPACT": 1,
		"INVOKE_FAVOR": 1,
		"TREAT_WOUND": 1,
		"REQUEST_PERFORMANCE": 0,
		"ANNOUNCE_HUNT": 0,
		"REQUEST_HUNT_INVITATION": 0,
		"CANCEL_HUNT": 0,
		"TRAIN_ANIMAL": 1,
		"APPLY_TATTOO": 2,
		"COMPOSE_THEATER_PIECE": 1,
		"LEARN_THEATER_PIECE": 1,
		"PERFORM_THEATER_PIECE": 1,
		"DEDICATE_PIECE": 1,
		"CRAFT": 1,
		"REQUEST_ART": 1,
		"OFFER_ART_COMMISSION": 1,
		"CULTIVATE_GARDEN": 1,
		"MAINTAIN_GARDEN": 1,
		"COLLECT_BONSAI_SPECIMEN": 1,
		"TEND_BONSAI": 1,
		"DISPLAY_BONSAI": 1,
		"DECLARE_SENBAZURU": 0,
		"PRESENT_SENBAZURU": 1,
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
		"ikebana_slot_empty":
			if ctx.skill_ranks.get("Artisan: Ikebana", 0) < 1:
				return []
			if ctx.known_objectives.get("ikebana_slot_empty", false):
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


static func _build_known_topic_momentums(
	topic_pool: Array,
	active_topics: Array,
) -> Dictionary:
	## Map topic_id → momentum for topics the character knows.
	var result: Dictionary = {}
	for topic: Variant in active_topics:
		var tid: int = -1
		var momentum: int = 0
		if topic is Dictionary:
			tid = int(topic.get("topic_id", -1))
			momentum = int(topic.get("momentum", 0))
		elif topic is Resource:
			tid = topic.topic_id
			momentum = topic.momentum
		if tid >= 0 and tid in topic_pool:
			result[tid] = momentum
	return result


static func _build_known_topic_subjects(
	topic_pool: Array,
	active_topics: Array,
) -> Dictionary:
	## Map topic_id → {clan, family, char_id} for subject matching in scoring.
	var result: Dictionary = {}
	for topic: Variant in active_topics:
		var tid: int = -1
		var clan_inv: String = ""
		var family_inv: String = ""
		var char_id_inv: int = -1
		if topic is Dictionary:
			tid = int(topic.get("topic_id", -1))
			clan_inv = topic.get("clan_involved", "")
			family_inv = topic.get("family_involved", "")
			char_id_inv = int(topic.get("subject_character_id", -1))
		elif topic is Resource:
			tid = topic.topic_id
			clan_inv = topic.clan_involved
			family_inv = topic.family_involved
			char_id_inv = topic.subject_character_id
		if tid >= 0 and tid in topic_pool:
			result[tid] = {"clan": clan_inv, "family": family_inv, "char_id": char_id_inv}
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
	"FOUND_MONASTERY", "COMMISSION_SHIP", "ARRANGE_MARRIAGE", "DISSOLVE_MARRIAGE",
	# Reclassified from AP to Civilian Order per s57.34.4 — lord-only
	"SET_TAX_RATE", "SET_STIPEND_RATE",
	"REQUEST_ART", "REQUEST_PERFORMANCE",
	"ASSIGN_VASSAL_OBJECTIVE", "ASSIGN_TO_MILITARY_SERVICE",
	"SEND_INVITATION", "CALL_COURT",
	"COMMISSION_ASSASSINATION",
	"DEMAND_TRIBUTE", "REQUEST_ALLIED_AID",
	"TRANSFER_KOKU", "SHARE_SUPPLIES",
	"ACCEPT_RONIN_PETITION",
	"HIRE_RONIN",
	"PERFORM_CLAN_INDUCTION",
	"APPROVE_CLAN_INDUCTION",
	"TERMINATE_CONTRACT",
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

static func _is_ceasefire_blocked(action_id: String) -> bool:
	return action_id in CEASEFIRE_BLOCKED_ACTIONS


static func _is_labor_halt_blocked(action_id: String) -> bool:
	return action_id in LABOR_HALT_BLOCKED_ACTIONS


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
			ps.starvation_stage = ResourceTick.StarvationStage.SHORTAGE
		ps.garrison_pu = settlement_garrison.get(pd.province_id, 0)
		ps.total_settlement_pu = settlement_total_pu.get(pd.province_id, 0)
		ps.rice_stockpile = settlement_rice.get(pd.province_id, 0.0)
		ps.confidence = NPCDataStructures.ProvinceStatus.CONFIDENCE_FRESH
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
	chars_by_id: Dictionary = {},
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
	elif option.action_id == "DISSOLVE_MARRIAGE":
		option.metadata = _build_dissolve_marriage_metadata(need, ctx, chars_by_id)
	elif option.action_id == "APPOINT_TO_POSITION":
		option.metadata = {
			"target_npc_id": need.target_npc_id,
			"position": need.target_intent,
		}
	elif option.action_id == "PERFORM_WORSHIP":
		option.metadata = {
			"directed_fortune": need.target_npc_id if need.target_npc_id >= 0 else -1,
			"location_type": _zone_to_worship_location(ctx.zone_subtype),
			"ikebana_worship_fr": ctx.known_objectives.get("ikebana_worship_fr", 0),
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
		else:
			var roll: int = (ctx.character_id * 7 + option.target_npc_id * 13) % 100
			if roll >= 90:
				insult_type = "ancestors"
			elif roll >= 70:
				insult_type = "clan"
		option.metadata = {"insult_type": insult_type}
	elif option.action_id == "INTIMIDATE":
		var target_id: int = need.target_npc_id if need.target_npc_id >= 0 else option.target_npc_id
		var secret_meta: Dictionary = _pick_secret_about_target(ctx, target_id)
		option.metadata = secret_meta
	elif option.action_id == "INVOKE_FAVOR":
		option.metadata = _pick_best_favor_to_invoke(ctx)
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
			"accepted_invitee_ids": ctx.known_objectives.get("hunt_accepted_invitee_ids", []),
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
		option.metadata = _build_forge_letter_metadata(ctx, need, chars_by_id)
	elif option.action_id == "FORGE_ORDER":
		option.metadata = _build_forge_order_metadata(ctx, need, chars_by_id)
	elif option.action_id == "TRANSFER_KOKU":
		option.metadata = {"target_npc_id": need.target_npc_id}
	elif option.action_id == "MENTOR":
		option.metadata = _build_mentor_metadata(ctx, need, chars_by_id)
	elif option.action_id == "TRAIN":
		# Surface the training target skill name for competence scoring.
		# The executor calls NPCAdvancement.apply_solo_training_progress() directly.
		if character != null:
			var target: Dictionary = NPCAdvancement.get_best_training_target(character)
			option.metadata = {
				"training_skill": target.get("skill", ""),
				"training_ring": int(target.get("ring", Enums.Ring.EARTH)),
			}
		else:
			option.metadata = {"training_skill": "", "training_ring": int(Enums.Ring.EARTH)}
	elif option.action_id == "COMPOSE_THEATER_PIECE":
		option.metadata = _build_compose_theater_metadata(ctx, need)
	elif option.action_id == "LEARN_THEATER_PIECE":
		option.metadata = _build_learn_theater_metadata(ctx, need, chars_by_id)
	elif option.action_id == "PERFORM_THEATER_PIECE":
		option.metadata = _build_perform_theater_metadata(ctx, need, chars_by_id)
	elif option.action_id == "DEDICATE_PIECE":
		option.metadata = _build_dedicate_piece_metadata(ctx, need)
	elif option.action_id == "PETITION_RONIN":
		option.metadata = {"target_lord_id": _pick_lord_for_petition(ctx, chars_by_id)}
		option.target_npc_id = option.metadata.get("target_lord_id", -1)
	elif option.action_id == "ACCEPT_RONIN_PETITION":
		option.metadata = {"target_ronin_id": _pick_ronin_for_acceptance(ctx, chars_by_id)}
		option.target_npc_id = option.metadata.get("target_ronin_id", -1)
	elif option.action_id == "HIRE_RONIN":
		var hire_meta: Dictionary = _build_hire_ronin_metadata(ctx, chars_by_id)
		option.metadata = hire_meta
		option.target_npc_id = hire_meta.get("target_ronin_id", -1)
	elif option.action_id == "PERFORM_CLAN_INDUCTION":
		var ind_meta: Dictionary = _build_induction_metadata(ctx, chars_by_id)
		option.metadata = ind_meta
		option.target_npc_id = ind_meta.get("target_ronin_id", -1)
	elif option.action_id == "APPROVE_CLAN_INDUCTION":
		var appr_meta: Dictionary = _build_approve_induction_metadata(ctx, chars_by_id)
		option.metadata = appr_meta
		option.target_npc_id = appr_meta.get("target_ronin_id", -1)
	elif option.action_id == "TERMINATE_CONTRACT":
		var term_meta: Dictionary = _build_terminate_contract_metadata(ctx, chars_by_id)
		option.metadata = term_meta
		option.target_npc_id = term_meta.get("target_ronin_id", -1)
	elif option.action_id == "CRAFT":
		var orig_rank: int = ctx.skill_ranks.get("Artisan: Origami", 0)
		if orig_rank > 0:
			option.metadata = _build_craft_origami_metadata(ctx, need, orig_rank)
	elif option.action_id == "DECLARE_SENBAZURU":
		option.metadata = _build_declare_senbazuru_metadata(ctx, need, chars_by_id)
	elif option.action_id == "PRESENT_SENBAZURU":
		var sb_id: int = ctx.known_objectives.get("active_senbazuru_id", -1)
		option.metadata = {"senbazuru_id": sb_id}
	elif option.action_id in ["REQUEST_ART", "OFFER_ART_COMMISSION"]:
		option.metadata = _build_garden_commission_metadata(ctx, need, chars_by_id, option.action_id == "REQUEST_ART")
		option.target_npc_id = option.metadata.get("artisan_id", -1) if option.action_id == "REQUEST_ART" else option.metadata.get("daimyo_id", -1)
	elif option.action_id == "CULTIVATE_GARDEN":
		option.metadata = {
			"commission_id": ctx.known_objectives.get("active_commission_id", -1),
			"target_quality_tier": ctx.known_objectives.get("commission_quality_tier", 1),
		}
	elif option.action_id == "MAINTAIN_GARDEN":
		option.metadata = {
			"garden_id": ctx.known_objectives.get("local_garden_id", -1),
			"garden_tier": ctx.known_objectives.get("local_garden_tier", 1),
		}
	elif option.action_id == "COLLECT_BONSAI_SPECIMEN":
		option.target_province_id = ctx.known_objectives.get("character_province_id", -1)
		option.metadata = {"province_id": option.target_province_id}
	elif option.action_id in ["TEND_BONSAI", "DISPLAY_BONSAI"]:
		var bonsai_id_meta: int = ctx.known_objectives.get("owned_bonsai_id", -1)
		option.metadata = {
			"bonsai_id": bonsai_id_meta,
			"settlement_id": int(ctx.location_id) if ctx.location_id.is_valid_int() else -1,
		}


static func _build_compose_theater_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
) -> Dictionary:
	## Compose: select WIP piece to advance or declare a new composition.
	## wip_piece_ids injected by _inject_theater_context.
	var wip_ids: Array = ctx.known_objectives.get("wip_piece_ids", [])
	if not wip_ids.is_empty():
		return {
			"piece_id": int(wip_ids[0]),
			"is_new": false,
			"raises": 0,
		}
	var poetry_rank: int = ctx.skill_ranks.get("Poetry", 0)
	var target_magnitude: int = clampi(poetry_rank, 1, 3)

	if need.need_type == "ARTISTIC_EXPRESSION":
		return _build_artistic_expression_compose_metadata(ctx, target_magnitude)

	# Declare a new piece: magnitude from Poetry rank (capped 1-3 for NPCs per GDD s57.22)
	# Negative framing if DAMAGE_RELATIONSHIP need
	var framing: bool = need.need_type != "DAMAGE_RELATIONSHIP"
	var subject_type: int = TheaterSystem.SubjectType.CLAN
	var subject: String = need.target_intent if not need.target_intent.is_empty() else ctx.clan
	return {
		"piece_id": -1,
		"is_new": true,
		"target_magnitude": target_magnitude,
		"target_topic_weight": 1,
		"num_roles": 1,
		"framing": framing,
		"subject": subject,
		"subject_type": subject_type,
		"topic_id": need.target_province_id if need.target_province_id >= 0 else -1,
		"raises": 0,
		"political_need_type": need.need_type if need.need_type in ["DAMAGE_RELATIONSHIP", "MOVE_TOPIC_POSITION"] else "",
	}


static func _build_artistic_expression_compose_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	target_magnitude: int,
) -> Dictionary:
	## §57.22.11 — new piece declaration for ARTISTIC_EXPRESSION need type.
	## Subject: strongest disposition target. Style: school/personality weighted.
	## Role count: 1 by default; 2 if Ambition-equivalent conditions met.

	# Subject selection: scan disposition map for strongest opinion.
	var strongest_disp: float = 0.0
	var strongest_target: int = -1
	var second_disp: float = 0.0
	var second_target: int = -1
	for cid: Variant in ctx.disposition_values:
		var disp: float = float(ctx.disposition_values[cid])
		if absf(disp) > absf(strongest_disp):
			second_disp = strongest_disp
			second_target = strongest_target
			strongest_disp = disp
			strongest_target = int(cid)
		elif absf(disp) > absf(second_disp) and int(cid) != strongest_target:
			second_disp = disp
			second_target = int(cid)

	var subject: String = str(strongest_target) if strongest_target >= 0 else ctx.clan
	var subject_type: int = TheaterSystem.SubjectType.CHARACTER if strongest_target >= 0 else TheaterSystem.SubjectType.CLAN
	var framing: bool = strongest_disp >= 0.0

	# Prefer active-topic subject when two subjects score equally (GDD §57.22.11).
	if strongest_target >= 0 and second_target >= 0 \
			and absf(strongest_disp) == absf(second_disp):
		var strongest_has_topic: bool = false
		var second_has_topic: bool = false
		for tid: int in ctx.known_topics:
			var topic_subject: int = ctx.known_objectives.get("_topic_subject_%d" % tid, -1)
			if topic_subject == strongest_target:
				strongest_has_topic = true
			elif topic_subject == second_target:
				second_has_topic = true
		if second_has_topic and not strongest_has_topic:
			strongest_target = second_target
			strongest_disp = second_disp
			subject = str(second_target)
			framing = second_disp >= 0.0

	# Style selection: weighted by school type and personality (GDD §57.22.11).
	var style: int = _pick_artistic_expression_style(ctx, framing)

	# Kyogen requires negative framing; reject and default to NOH if framing is positive.
	if style == TheaterSystem.Style.KYOGEN and framing:
		style = TheaterSystem.Style.NOH

	# Role count: default 1; choose 2 if personality-equivalent conditions met.
	# GDD §57.22.11: personality Ambition weight ≥ +10, Acting rank ≥ 3,
	# and at least one met_character has Acting rank ≥ target magnitude.
	var num_roles: int = 1
	var acting_rank: int = ctx.skill_ranks.get("Acting", 0)
	# "Ambition" has no explicit Shourido enum mapping; proxy via ISHI or KETSUI
	# (determination/drive), the closest Shourido equivalents to ambition.
	var has_ambition: bool = ctx.shourido_virtue in [
		Enums.ShouridoVirtue.ISHI, Enums.ShouridoVirtue.KETSUI,
	]
	# Kyogen cannot have more than 2 roles; NPC already capped at 2.
	if has_ambition and acting_rank >= 3 and second_target >= 0 \
			and absf(second_disp) >= 11.0 and second_target != strongest_target:
		num_roles = 2

	var meta: Dictionary = {
		"piece_id": -1,
		"is_new": true,
		"target_magnitude": target_magnitude,
		"target_topic_weight": 1,
		"num_roles": num_roles,
		"framing": framing,
		"subject": subject,
		"subject_type": subject_type,
		"topic_id": -1,
		"raises": 0,
		"style": style,
		"political_need_type": "",
	}

	# Second role: if 2 roles, add second strongest disposition subject.
	if num_roles == 2 and second_target >= 0:
		meta["subject_2"] = str(second_target)
		meta["subject_type_2"] = TheaterSystem.SubjectType.CHARACTER
		meta["framing_2"] = second_disp >= 0.0

	return meta


static func _pick_artistic_expression_style(
	ctx: NPCDataStructures.ContextSnapshot,
	framing: bool,
) -> int:
	## §57.22.11 style selection: school type and personality weighted.
	var manipulation: int = ctx.skill_ranks.get("Manipulation", 0)
	var deceit: int = ctx.skill_ranks.get("Deceit", 0)
	var satirical: bool = manipulation >= 3 or deceit >= 3

	# Kyogen: strong negative disposition AND satirical personality profile.
	if not framing and satirical:
		return TheaterSystem.Style.KYOGEN

	# Personality overrides (applied before school defaults).
	if ctx.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return TheaterSystem.Style.KABUKI
	if ctx.bushido_virtue == Enums.BushidoVirtue.JIN:
		return TheaterSystem.Style.NOH

	# School type defaults.
	match ctx.school_type:
		Enums.SchoolType.BUSHI:
			return TheaterSystem.Style.NOH
		Enums.SchoolType.SHUGENJA:
			return TheaterSystem.Style.NOH
		Enums.SchoolType.COURTIER:
			# Equally weighted Noh / Kabuki — deterministic via character_id parity.
			return TheaterSystem.Style.NOH if (ctx.character_id % 2 == 0) else TheaterSystem.Style.KABUKI

	return TheaterSystem.Style.NOH


static func _build_learn_theater_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	_need: NPCDataStructures.ImmediateNeed,
	chars_by_id: Dictionary = {},
) -> Dictionary:
	## §57.22.6 — Select the best learnable piece for LEARN_THEATER_PIECE.
	## Pieces scored by: political relevance (active topic momentum > 30) and
	## personal disposition toward piece subject (§57.22.6 post-learning rationale).
	var learnable_ids: Array = ctx.known_objectives.get("learnable_piece_ids", [])
	var pieces_by_id: Dictionary = ctx.known_objectives.get("_theater_pieces_by_id", {})

	if learnable_ids.is_empty():
		return {"piece_id": -1}

	var best_id: int = -1
	var best_score: int = -1

	for pid: Variant in learnable_ids:
		var piece_id: int = int(pid)
		var piece: TheaterPieceData = pieces_by_id.get(piece_id) as TheaterPieceData
		if piece == null:
			continue

		# For private pieces validate teacher still available (chars_by_id may have changed).
		if not piece.canonized and not chars_by_id.is_empty():
			var teacher_id: int = TheaterSystem.find_willing_teacher(
				ctx.character_id, piece, chars_by_id
			)
			if teacher_id < 0:
				continue

		var score: int = 50  # base

		# +30 if any linked topic is still politically live (momentum > 30).
		for tid: int in piece.topic_ids:
			if (tid in ctx.known_topics) and ctx.known_topic_momentums.get(tid, 0) > 30:
				score += 30
				break

		# +20 if NPC holds a strong personal disposition toward the piece's subject character.
		if piece.subject != "":
			var subject_as_id: int = piece.subject.to_int()
			if subject_as_id > 0:
				var disp: float = float(ctx.disposition_values.get(subject_as_id, 0.0))
				if absf(disp) >= 11.0:
					score += 20

		if score > best_score:
			best_score = score
			best_id = piece_id

	return {"piece_id": best_id}


static func _build_perform_theater_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	chars_by_id: Dictionary = {},
) -> Dictionary:
	## §57.22.13 — Score each performable piece and select the best.
	var pieces_by_id: Dictionary = ctx.known_objectives.get("_theater_pieces_by_id", {})
	var performable: Array = ctx.known_objectives.get("theater_pieces_to_perform", [])

	var best_id: int = -1
	var best_score: int = -1
	var best_is_bunraku: bool = false

	for pid: Variant in performable:
		var piece_id: int = int(pid)
		var piece: TheaterPieceData = pieces_by_id.get(piece_id) as TheaterPieceData
		if piece == null:
			continue

		# Hard gate 1: need at least 1 non-immune non-known_by witness.
		var non_immune_count: int = _count_non_immune_theater_witnesses(ctx, piece, chars_by_id)
		if non_immune_count == 0:
			continue

		# Hard gate 2: co-located known_by members must cover all named roles.
		var num_named_roles: int = maxi(1, piece.roles.size())
		var colocated_knowers: int = _count_colocated_theater_knowers(ctx, piece, chars_by_id)
		if colocated_knowers < num_named_roles:
			continue

		# Bunraku needs at least 3 co-located known_by members (§57.22.3).
		if piece.style == TheaterSystem.Style.BUNRAKU and colocated_knowers < 3:
			continue

		var score: int = 50  # base

		# +30 if any topic_id is in known_topics with momentum > 30 (§57.22.13).
		for tid: int in piece.topic_ids:
			if (tid in ctx.known_topics) and (ctx.known_topic_momentums.get(tid, 0) > 30):
				score += 30
				break

		# +20 if >50% non-immune non-known_by witnesses aligned with piece framing.
		if _theater_majority_aligned(ctx, piece, chars_by_id, non_immune_count):
			score += 20

		# +20 if NPC holds strong personal disposition toward any role's subject.
		if _npc_strong_theater_disposition(ctx, piece):
			score += 20

		# +15 if NPC is author; -20 if already performed this piece today.
		if piece.author_id == ctx.character_id:
			score += 15
			if _theater_author_performed_today(ctx, piece_id):
				score -= 20

		# -25 if >50% of non-known_by witnesses have active immunity.
		if _theater_majority_immune(ctx, piece, chars_by_id):
			score -= 25

		# -30 if fewer than 3 non-immune named witnesses.
		if non_immune_count < 3:
			score -= 30

		# +15 if at least one non-immune non-known_by witness has Status >= 3.
		if _theater_has_high_value_witness(ctx, piece, chars_by_id):
			score += 15

		# Kyogen additional modifiers (§57.22.13).
		if piece.style == TheaterSystem.Style.KYOGEN:
			if _kyogen_subject_present(ctx, piece, chars_by_id):
				score += 25
			if not _kyogen_has_provocation_pretext(ctx, piece, chars_by_id):
				var subj_status: float = _kyogen_subject_max_status(ctx, piece, chars_by_id)
				if subj_status > ctx.status:
					score -= 40

		if score > best_score:
			best_score = score
			best_id = piece_id
			best_is_bunraku = (piece.style == TheaterSystem.Style.BUNRAKU)

	# If no piece scores above 0, do not fire.
	if best_score <= 0:
		best_id = -1

	var raises: int = 0
	if need.need_type == "SEEK_GLORY":
		raises = 1
	return {
		"piece_id": best_id,
		"is_bunraku_performance": best_is_bunraku,
		"raises": raises,
	}


static func _count_non_immune_theater_witnesses(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> int:
	## Count non-immune non-known_by named witnesses per §57.22.8.
	var count: int = 0
	for cid_v: Variant in ctx.characters_present:
		var wid: int = int(cid_v)
		if wid == ctx.character_id:
			continue
		if wid in piece.known_by:
			continue  # permanent immunity
		var witness: L5RCharacterData = chars_by_id.get(wid) as L5RCharacterData
		if witness == null or CharacterStats.is_dead(witness):
			continue
		var last_seen: int = witness.pieces_seen.get(piece.piece_id, -1)
		if last_seen >= 0 and (ctx.ic_day - last_seen) <= 30:
			continue  # 30-day immunity window
		count += 1
	return count


static func _count_colocated_theater_knowers(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> int:
	## Count co-located known_by members (including the acting NPC).
	var count: int = 0
	for kid: int in piece.known_by:
		if kid == ctx.character_id:
			count += 1
			continue
		var knower: L5RCharacterData = chars_by_id.get(kid) as L5RCharacterData
		if knower == null or CharacterStats.is_dead(knower):
			continue
		if knower.physical_location == ctx.location_id:
			count += 1
	return count


static func _theater_majority_aligned(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
	non_immune_count: int,
) -> bool:
	## +20: >50% non-immune non-known_by witnesses aligned with framing for any role.
	if non_immune_count == 0:
		return false
	var roles_to_check: Array = piece.roles if not piece.roles.is_empty() else [
		{"subject_character": piece.subject, "subject_type": piece.subject_type, "framing": piece.framing}
	]
	for role: Dictionary in roles_to_check:
		var role_subj: String = str(role.get("subject_character", piece.subject))
		var role_stype: int = int(role.get("subject_type", piece.subject_type))
		var role_framing: bool = bool(role.get("framing", piece.framing))
		var aligned: int = 0
		for cid_v: Variant in ctx.characters_present:
			var wid: int = int(cid_v)
			if wid == ctx.character_id:
				continue
			if wid in piece.known_by:
				continue
			var witness: L5RCharacterData = chars_by_id.get(wid) as L5RCharacterData
			if witness == null or CharacterStats.is_dead(witness):
				continue
			var last_seen: int = witness.pieces_seen.get(piece.piece_id, -1)
			if last_seen >= 0 and (ctx.ic_day - last_seen) <= 30:
				continue
			var disp: int = _theater_witness_disp_toward(witness, role_subj, role_stype, chars_by_id)
			if role_framing and disp >= 11:
				aligned += 1
			elif not role_framing and disp <= -11:
				aligned += 1
		if aligned * 2 > non_immune_count:  # strictly more than 50%
			return true
	return false


static func _theater_witness_disp_toward(
	witness: L5RCharacterData,
	subject: String,
	subject_type: int,
	chars_by_id: Dictionary,
) -> int:
	## Get witness disposition toward a theater piece subject.
	match subject_type:
		TheaterSystem.SubjectType.CHARACTER:
			if subject.is_valid_int():
				return witness.disposition_values.get(int(subject), 0)
		TheaterSystem.SubjectType.CLAN:
			# Use strongest disposition toward any character of that clan as proxy.
			var best: int = 0
			for cid_v: Variant in witness.disposition_values:
				var cid_int: int = int(cid_v)
				var c: L5RCharacterData = chars_by_id.get(cid_int) as L5RCharacterData
				if c == null:
					continue
				if c.clan == subject:
					var d: int = int(witness.disposition_values.get(cid_v, 0))
					if absf(float(d)) > absf(float(best)):
						best = d
			return best
		TheaterSystem.SubjectType.FAMILY:
			var best: int = 0
			for cid_v: Variant in witness.disposition_values:
				var cid_int: int = int(cid_v)
				var c: L5RCharacterData = chars_by_id.get(cid_int) as L5RCharacterData
				if c == null:
					continue
				if c.family == subject:
					var d: int = int(witness.disposition_values.get(cid_v, 0))
					if absf(float(d)) > absf(float(best)):
						best = d
			return best
	return 0


static func _npc_strong_theater_disposition(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
) -> bool:
	## +20: NPC holds strong disposition (≥+11 or ≤-11) toward any role's subject.
	var roles_to_check: Array = piece.roles if not piece.roles.is_empty() else [
		{"subject_character": piece.subject, "subject_type": piece.subject_type}
	]
	for role: Dictionary in roles_to_check:
		var subj: String = str(role.get("subject_character", piece.subject))
		var stype: int = int(role.get("subject_type", piece.subject_type))
		var disp: int = _theater_npc_disp_toward(ctx, subj, stype)
		if disp >= 11 or disp <= -11:
			return true
	return false


static func _theater_npc_disp_toward(
	ctx: NPCDataStructures.ContextSnapshot,
	subject: String,
	subject_type: int,
) -> int:
	## Get NPC's own disposition toward a theater piece subject.
	match subject_type:
		TheaterSystem.SubjectType.CHARACTER:
			if subject.is_valid_int():
				return int(ctx.disposition_values.get(int(subject), 0))
		TheaterSystem.SubjectType.CLAN:
			# Use strongest disposition toward any known contact of that clan.
			var contacts: Array = ctx.known_contacts_by_clan.get(subject, [])
			var best: int = 0
			for cid_v: Variant in contacts:
				var d: int = int(ctx.disposition_values.get(int(cid_v), 0))
				if absf(float(d)) > absf(float(best)):
					best = d
			return best
		TheaterSystem.SubjectType.FAMILY:
			var best: int = 0
			for cid_v: Variant in ctx.known_contacts:
				var cid_int: int = int(cid_v)
				var d: int = int(ctx.disposition_values.get(cid_int, 0))
				var clan: String = ctx.contact_clans.get(cid_int, "")
				# Use family from the contact if available (contact_clans stores clan; family
				# not separately tracked — use clan as proxy for family-clan match).
				if clan == subject:
					if absf(float(d)) > absf(float(best)):
						best = d
			return best
	return 0


static func _theater_author_performed_today(
	ctx: NPCDataStructures.ContextSnapshot,
	piece_id: int,
) -> bool:
	## -20: check action_log for PERFORM_THEATER_PIECE with this piece_id today.
	for entry: Variant in ctx.action_log:
		if not entry is Dictionary:
			continue
		if entry.get("action_id", "") != "PERFORM_THEATER_PIECE":
			continue
		var meta: Dictionary = entry.get("metadata", {})
		if meta.get("piece_id", -1) == piece_id:
			return true
	return false


static func _theater_majority_immune(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> bool:
	## -25: >50% of non-known_by named witnesses have active immunity.
	var total: int = 0
	var immune: int = 0
	for cid_v: Variant in ctx.characters_present:
		var wid: int = int(cid_v)
		if wid == ctx.character_id:
			continue
		if wid in piece.known_by:
			continue  # excluded from this count
		var witness: L5RCharacterData = chars_by_id.get(wid) as L5RCharacterData
		if witness == null or CharacterStats.is_dead(witness):
			continue
		total += 1
		var last_seen: int = witness.pieces_seen.get(piece.piece_id, -1)
		if last_seen >= 0 and (ctx.ic_day - last_seen) <= 30:
			immune += 1
	if total == 0:
		return false
	return immune * 2 > total  # strictly more than 50%


static func _theater_has_high_value_witness(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> bool:
	## +15: at least one non-immune non-known_by witness has Status >= 3.
	for cid_v: Variant in ctx.characters_present:
		var wid: int = int(cid_v)
		if wid == ctx.character_id:
			continue
		if wid in piece.known_by:
			continue
		var witness: L5RCharacterData = chars_by_id.get(wid) as L5RCharacterData
		if witness == null or CharacterStats.is_dead(witness):
			continue
		var last_seen: int = witness.pieces_seen.get(piece.piece_id, -1)
		if last_seen >= 0 and (ctx.ic_day - last_seen) <= 30:
			continue
		if witness.status >= 3.0:
			return true
	return false


static func _kyogen_subject_present(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> bool:
	## +25 for Kyogen: subject is physically present in zone.
	var lead_role: Dictionary = piece.roles[0] if not piece.roles.is_empty() else {}
	var subj: String = str(lead_role.get("subject_character", piece.subject))
	var stype: int = int(lead_role.get("subject_type", piece.subject_type))
	match stype:
		TheaterSystem.SubjectType.CHARACTER:
			if subj.is_valid_int():
				return int(subj) in ctx.characters_present
		TheaterSystem.SubjectType.CLAN:
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.clan == subj:
					return true
		TheaterSystem.SubjectType.FAMILY:
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.family == subj:
					return true
		TheaterSystem.SubjectType.ARCHETYPE:
			# For archetype, check if any character matching the clan component is present.
			var clan_req: String = lead_role.get("clan_requirement", "")
			if not clan_req.is_empty():
				for cid_v: Variant in ctx.characters_present:
					var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
					if c != null and not CharacterStats.is_dead(c) and c.clan == clan_req:
						return true
	return false


static func _kyogen_subject_max_status(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> float:
	## Returns highest Status for Kyogen subject present in zone (§57.22.13).
	var lead_role: Dictionary = piece.roles[0] if not piece.roles.is_empty() else {}
	var subj: String = str(lead_role.get("subject_character", piece.subject))
	var stype: int = int(lead_role.get("subject_type", piece.subject_type))
	match stype:
		TheaterSystem.SubjectType.CHARACTER:
			if subj.is_valid_int():
				var c: L5RCharacterData = chars_by_id.get(int(subj)) as L5RCharacterData
				if c != null:
					return c.status
		TheaterSystem.SubjectType.CLAN:
			var max_status: float = 0.0
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.clan == subj:
					max_status = maxf(max_status, c.status)
			return max_status
		TheaterSystem.SubjectType.FAMILY:
			var max_status: float = 0.0
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.family == subj:
					max_status = maxf(max_status, c.status)
			return max_status
		TheaterSystem.SubjectType.ARCHETYPE:
			var clan_req: String = lead_role.get("clan_requirement", "")
			var max_status: float = 0.0
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.clan == clan_req:
					max_status = maxf(max_status, c.status)
			return max_status
	return 0.0


static func _kyogen_has_provocation_pretext(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	chars_by_id: Dictionary,
) -> bool:
	## -40 guard: pretext exists if subject holds Enemy disposition toward performer.
	## Implements GDD condition (4): subject Enemy disp toward performer.
	## Conditions (1)(zone_event_log) and (3)(court session) deferred.
	var lead_role: Dictionary = piece.roles[0] if not piece.roles.is_empty() else {}
	var subj: String = str(lead_role.get("subject_character", piece.subject))
	var stype: int = int(lead_role.get("subject_type", piece.subject_type))
	var npc_id_str: String = str(ctx.character_id)
	match stype:
		TheaterSystem.SubjectType.CHARACTER:
			if subj.is_valid_int():
				var subject: L5RCharacterData = chars_by_id.get(int(subj)) as L5RCharacterData
				if subject != null:
					return int(subject.disposition_values.get(ctx.character_id, 0)) <= -51
		TheaterSystem.SubjectType.CLAN:
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.clan == subj:
					if int(c.disposition_values.get(ctx.character_id, 0)) <= -51:
						return true
		TheaterSystem.SubjectType.FAMILY:
			for cid_v: Variant in ctx.characters_present:
				var c: L5RCharacterData = chars_by_id.get(int(cid_v)) as L5RCharacterData
				if c != null and not CharacterStats.is_dead(c) and c.family == subj:
					if int(c.disposition_values.get(ctx.character_id, 0)) <= -51:
						return true
	return false


static func _build_dedicate_piece_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
) -> Dictionary:
	## Dedicate: pick known completed piece + most relevant topic to link.
	var performable: Array = ctx.known_objectives.get("theater_pieces_to_perform", [])
	var piece_id: int = -1
	for pid: Variant in performable:
		piece_id = int(pid)
		break
	# Best topic: pick first known topic related to the need's target
	var topic_id: int = -1
	if not ctx.known_topics.is_empty():
		topic_id = int(ctx.known_topics[0])
	return {
		"piece_id": piece_id,
		"topic_id": topic_id,
		"raises": 0,
	}


static func _build_mentor_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	chars_by_id: Dictionary = {},
) -> Dictionary:
	var best_student_id: int = -1
	var best_skill: String = ""
	var best_gap: int = 0
	var target_id: int = need.target_npc_id
	if target_id >= 0:
		var target: L5RCharacterData = chars_by_id.get(target_id) as L5RCharacterData
		if target != null and not CharacterStats.is_dead(target):
			if target.physical_location == ctx.location_id:
				var pair: Dictionary = _pick_mentor_skill(ctx, target)
				if pair.get("gap", 0) > 0:
					best_student_id = target_id
					best_skill = pair["skill"]
					best_gap = pair["gap"]
	if best_student_id < 0:
		for cid: Variant in ctx.disposition_values:
			var cid_int: int = int(cid)
			if cid_int == ctx.character_id:
				continue
			var disp: int = int(ctx.disposition_values[cid])
			if disp < 0:
				continue
			var candidate: L5RCharacterData = chars_by_id.get(cid_int) as L5RCharacterData
			if candidate == null or CharacterStats.is_dead(candidate):
				continue
			if candidate.physical_location != ctx.location_id:
				continue
			var pair: Dictionary = _pick_mentor_skill(ctx, candidate)
			var gap: int = pair.get("gap", 0)
			if gap > best_gap:
				best_gap = gap
				best_student_id = cid_int
				best_skill = pair["skill"]
	return {"student_id": best_student_id, "skill_name": best_skill}


static func _pick_mentor_skill(
	ctx: NPCDataStructures.ContextSnapshot,
	student: L5RCharacterData,
) -> Dictionary:
	var best_skill: String = ""
	var best_gap: int = 0
	for skill_name: String in ctx.skill_ranks:
		var sensei_rank: int = int(ctx.skill_ranks[skill_name])
		var student_rank: int = student.skills.get(skill_name, 0)
		if sensei_rank > student_rank and (sensei_rank - student_rank) > best_gap:
			best_gap = sensei_rank - student_rank
			best_skill = skill_name
	return {"skill": best_skill, "gap": best_gap}


static func _build_forge_letter_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	chars_by_id: Dictionary = {},
) -> Dictionary:
	var impersonated_id: int = need.target_npc_id
	var target_rank: Enums.LordRank = _get_target_lord_rank(impersonated_id, chars_by_id, ctx.lord_rank)
	var authority: String = _forge_authority_from_lord_rank(target_rank)
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
	chars_by_id: Dictionary = {},
) -> Dictionary:
	var target_id: int = need.target_npc_id
	var target_char: L5RCharacterData = chars_by_id.get(target_id) as L5RCharacterData
	var impersonated_rank: Enums.LordRank = ctx.lord_rank
	if target_char != null and target_char.lord_id >= 0:
		var lord_char: L5RCharacterData = chars_by_id.get(target_char.lord_id) as L5RCharacterData
		if lord_char != null:
			impersonated_rank = CivilianOrderBudget.lord_rank_from_status(lord_char.status)
	var authority: String = _forge_authority_from_lord_rank(impersonated_rank)
	var order_info: Dictionary = _pick_forged_order_type(need)
	return {
		"authority_level": authority,
		"target_npc_id": target_id,
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


static func _get_target_lord_rank(
	target_id: int, chars_by_id: Dictionary, fallback: Enums.LordRank,
) -> Enums.LordRank:
	if target_id < 0 or chars_by_id.is_empty():
		return fallback
	var target: L5RCharacterData = chars_by_id.get(target_id) as L5RCharacterData
	if target == null:
		return fallback
	return CivilianOrderBudget.lord_rank_from_status(target.status)


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
	# GDD s57.31a: 0-2→0 raises (TN 15), 3-4→1 raise (TN 20), 5+→3 raises (TN 30).
	# GDD s57.31 explicitly uses "At Rank 5 with 3 Raises: 5k1" as canonical expert case.
	var rank: int = ctx.skill_ranks.get("Medicine", 0)
	if rank >= 5:
		return 3
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


static func _build_dissolve_marriage_metadata(
	need: NPCDataStructures.ImmediateNeed,
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> Dictionary:
	# Find a vassal's marriage that meets the dissolution prerequisite gate (s57.49.7):
	# disp <= -31 (Enemy tier) toward the other spouse OR that spouse's immediate lord.
	for cid: int in chars_by_id:
		var c: L5RCharacterData = chars_by_id[cid] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.lord_id != ctx.character_id:
			continue
		if c.spouse_id < 0:
			continue
		var spouse: L5RCharacterData = chars_by_id.get(c.spouse_id) as L5RCharacterData
		if spouse == null or CharacterStats.is_dead(spouse):
			continue
		var disp_toward_spouse: int = ctx.disposition_values.get(c.spouse_id, 0)
		# Also gate on disp toward spouse's immediate lord (s57.49.7).
		var disp_toward_spouse_lord: int = 0
		if spouse.lord_id >= 0:
			disp_toward_spouse_lord = ctx.disposition_values.get(spouse.lord_id, 0)
		if disp_toward_spouse <= -31 or disp_toward_spouse_lord <= -31:
			return {"spouse_a_id": c.character_id, "spouse_b_id": c.spouse_id}
	# Fallback: use need.target_npc_id as the vassal to dissolve from.
	var fallback_a: int = need.target_npc_id
	if fallback_a >= 0:
		var fa: L5RCharacterData = chars_by_id.get(fallback_a) as L5RCharacterData
		if fa != null and not CharacterStats.is_dead(fa) and fa.spouse_id >= 0:
			return {"spouse_a_id": fallback_a, "spouse_b_id": fa.spouse_id}
	return {"spouse_a_id": -1, "spouse_b_id": -1}


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


static func _pick_best_favor_to_invoke(
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var best_favor_id: int = -1
	var best_debtor_id: int = -1
	var best_tier: int = 0
	for lev: Variant in ctx.held_leverage:
		if not lev is Dictionary:
			continue
		var d: Dictionary = lev as Dictionary
		if d.get("invoked", false):
			continue
		if d.get("resolved", false):
			continue
		var tier: int = d.get("tier", 0)
		if tier > best_tier:
			best_tier = tier
			best_favor_id = d.get("favor_id", -1)
			best_debtor_id = d.get("debtor_id", -1)
	return {"favor_id": best_favor_id, "debtor_id": best_debtor_id}


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
		if favor.resolved or favor.debtor_id != character_id:
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
			if status.starvation_stage > ResourceTick.StarvationStage.CLEAR:
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


static func _pick_lord_for_petition(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> int:
	## Find the best co-located lord for a ronin to petition (s52.5 Part B).
	## Only considers lords with disposition >= 0; negative-disposition lords
	## auto-reject and would waste an AP attempting (s52.5 Part B Step 1).
	## Prefers lords with higher disposition among eligible candidates.
	var best_id: int = -1
	var best_disp: int = -999
	for present_id: int in ctx.characters_present:
		var candidate: L5RCharacterData = chars_by_id.get(present_id) as L5RCharacterData
		if candidate == null or CharacterStats.is_dead(candidate):
			continue
		if candidate.role_position.is_empty():
			continue
		var disp: int = int(ctx.disposition_values.get(present_id, 0))
		if disp < 0:
			continue
		if disp > best_disp:
			best_disp = disp
			best_id = present_id
	return best_id


static func _pick_ronin_for_acceptance(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> int:
	## Find the best co-located ronin for a lord to accept into service (s52.5 Part D).
	## Prefers non-permanent-ronin candidates with highest status.
	var best_id: int = -1
	var best_status: float = -1.0
	for present_id: int in ctx.characters_present:
		var candidate: L5RCharacterData = chars_by_id.get(present_id) as L5RCharacterData
		if candidate == null or CharacterStats.is_dead(candidate):
			continue
		if not RoninSystem.is_ronin(candidate):
			continue
		if candidate.permanent_ronin:
			continue
		if candidate.status > best_status:
			best_status = candidate.status
			best_id = present_id
	return best_id


static func _build_hire_ronin_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> Dictionary:
	## Select the best co-located ronin and appropriate contract type (s52.6 Part B).
	## Prefers desperate ronin (higher urgency for lord filling vacancy).
	var best_id: int = -1
	var best_score: float = -1.0
	for present_id: int in ctx.characters_present:
		var c: L5RCharacterData = chars_by_id.get(present_id) as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if not RoninSystem.is_ronin(c):
			continue
		if c.permanent_ronin:
			continue
		if c.supply_ledger.get("contract_end_ic_day", -1) >= 0:
			continue  # already under contract
		var disp: float = ctx.disposition_values.get(present_id, 0.0)
		if disp <= -1.0:
			continue  # auto-reject gate
		var score: float = disp + c.status * 2.0
		if score > best_score:
			best_score = score
			best_id = present_id

	# Pick contract type from need context: military need → MILITARY_SERVICE, etc.
	var contract_type: String = "PROVINCE_DEFENSE"
	var need_type: String = ctx.known_objectives.get("primary", {}).get("need_type", "")
	if need_type == "LEVY_TROOPS" or need_type == "RAISE_ARMY":
		contract_type = "MILITARY_SERVICE"
	elif need_type == "UPHOLD_LAW" or need_type == "INVESTIGATE_THREAT":
		contract_type = "MAGISTRATE_AIDE"

	return {
		"target_ronin_id": best_id,
		"contract_type": contract_type,
		"duration_seasons": 1,
	}


static func _build_induction_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> Dictionary:
	## Select the best co-located ronin eligible for induction ceremony (s52.7 Part D).
	## Sponsoring lord must be Provincial Daimyo+; ronin needs 8 deeds, 1 extraordinary
	## deed, and prior Family Daimyo approval. Prefer highest deed count.
	var sponsor: L5RCharacterData = chars_by_id.get(ctx.character_id) as L5RCharacterData
	if sponsor == null:
		return {"target_ronin_id": -1}
	if sponsor.lord_rank < Enums.LordRank.PROVINCIAL_DAIMYO:
		return {"target_ronin_id": -1}
	var best_id: int = -1
	var best_deeds: int = -1
	for present_id: int in ctx.characters_present:
		var c: L5RCharacterData = chars_by_id.get(present_id) as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.permanent_ronin:
			continue
		if c.clan == sponsor.clan:
			continue
		var disp: float = ctx.disposition_values.get(present_id, 0.0)
		if disp < RoninSystem.INDUCTION_MIN_DISPOSITION:
			continue
		var deeds: int = RoninSystem.get_deed_count(c, sponsor.family)
		if deeds < RoninSystem.INDUCTION_DEED_THRESHOLD:
			continue
		if RoninSystem.get_extraordinary_deed_count(c, sponsor.family) < RoninSystem.INDUCTION_EXTRAORDINARY_DEED_REQUIRED:
			continue
		if int(c.supply_ledger.get("family_daimyo_approval", -1)) < 0:
			continue
		if deeds > best_deeds:
			best_deeds = deeds
			best_id = present_id
	return {"target_ronin_id": best_id}


static func _build_approve_induction_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> Dictionary:
	## Family Daimyo selects the best known ronin to grant induction approval (s52.7 Part C).
	## Requires 8 deeds + 1 extraordinary deed for the FD's family.
	## Ronin does not need to be co-located — approval can be granted remotely.
	var fd: L5RCharacterData = chars_by_id.get(ctx.character_id) as L5RCharacterData
	if fd == null:
		return {"target_ronin_id": -1}
	if fd.lord_rank < Enums.LordRank.FAMILY_DAIMYO:
		return {"target_ronin_id": -1}
	var best_id: int = -1
	var best_deeds: int = -1
	# Check all known characters for ronins who qualify but lack FD approval.
	for known_id: int in ctx.met_characters:
		var c: L5RCharacterData = chars_by_id.get(known_id) as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.permanent_ronin:
			continue
		if c.clan == fd.clan:
			continue
		if c.supply_ledger.get("family_daimyo_approval", -1) >= 0:
			continue  # already has approval
		var deeds: int = RoninSystem.get_deed_count(c, fd.family)
		if deeds < RoninSystem.INDUCTION_DEED_THRESHOLD:
			continue
		if RoninSystem.get_extraordinary_deed_count(c, fd.family) < RoninSystem.INDUCTION_EXTRAORDINARY_DEED_REQUIRED:
			continue
		var disp: float = ctx.disposition_values.get(known_id, 0.0)
		if disp < RoninSystem.INDUCTION_MIN_DISPOSITION:
			continue
		if deeds > best_deeds:
			best_deeds = deeds
			best_id = known_id
	return {"target_ronin_id": best_id}


static func _build_terminate_contract_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> Dictionary:
	## Find a co-located contracted ronin serving under this lord (s52.6 Part G).
	for present_id: int in ctx.characters_present:
		var c: L5RCharacterData = chars_by_id.get(present_id) as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.lord_id != ctx.character_id:
			continue
		if c.supply_ledger.get("contract_end_ic_day", -1) < 0:
			continue
		return {"target_ronin_id": present_id}
	return {"target_ronin_id": -1}


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


# -- s57.26 Origami Metadata Builders ------------------------------------------


static func _build_craft_origami_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	origami_rank: int,
) -> Dictionary:
	## Select origami sub-type and raises based on NeedType and context.
	var raises: int = _pick_origami_raises(origami_rank)
	var active_id: int = ctx.known_objectives.get("active_senbazuru_id", -1)

	match need.need_type:
		"RESTORE_WORSHIP":
			# Gohei supports worship (s57.26.12-13).
			return {"origami_type": "gohei", "raises": raises}
		"RAISE_DISPOSITION":
			# Noshi wraps a gift for the disposition target (s57.26.6-8).
			return {
				"origami_type": "noshi",
				"raises": raises,
				"target_npc_id": need.target_npc_id,
			}
		_:
			# Advance active senbazuru if present; else gohei; else noshi.
			if active_id >= 0:
				return {
					"origami_type": "senbazuru_progress",
					"raises": raises,
					"senbazuru_id": active_id,
				}
			return {"origami_type": "gohei", "raises": raises}


static func _pick_origami_raises(origami_rank: int) -> int:
	## NPC raise selection for origami rolls (0-2 based on skill rank).
	if origami_rank <= 2:
		return 0
	elif origami_rank <= 4:
		return 1
	return 2


static func _build_declare_senbazuru_metadata(
	ctx: NPCDataStructures.ContextSnapshot,
	need: NPCDataStructures.ImmediateNeed,
	chars_by_id: Dictionary,
) -> Dictionary:
	## Select dedication type and recipient. Defaults to Atonement.
	if need.need_type == "SEEK_GLORY":
		# Remembrance: find a deceased known character.
		var deceased_id: int = _pick_deceased_known_character(ctx, chars_by_id)
		if deceased_id >= 0:
			return {"dedication_type": "Remembrance", "recipient_id": deceased_id}

	if need.target_npc_id >= 0:
		var target: L5RCharacterData = chars_by_id.get(need.target_npc_id)
		if target != null and not CharacterStats.is_dead(target):
			# Healing if recipient is wounded or tainted; Protection otherwise.
			if CharacterStats.is_wounded(target) or target.taint_rank > 0:
				return {
					"dedication_type": "Healing",
					"recipient_id": need.target_npc_id,
				}
			return {
				"dedication_type": "Protection",
				"recipient_id": need.target_npc_id,
			}

	return {"dedication_type": "Atonement", "recipient_id": -1}


static func _pick_deceased_known_character(
	ctx: NPCDataStructures.ContextSnapshot,
	chars_by_id: Dictionary,
) -> int:
	## Find any deceased character with whom this NPC has a disposition relationship.
	## Simplified: any dead known character (GDD requires "within last IC season"
	## but no death timestamp exists on L5RCharacterData).
	for cid_v: Variant in ctx.disposition_values.keys():
		var cid: int = int(cid_v)
		var known: L5RCharacterData = chars_by_id.get(cid)
		if known != null and CharacterStats.is_dead(known):
			return cid
	return -1
