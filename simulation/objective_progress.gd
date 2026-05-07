class_name ObjectiveProgress
## Per-objective progress functions per GDD s55.29.3.
## Each of the 12 primary objective types has a progress function (0.0–1.0).
## Evaluated once per seasonal tick. Drives stall detection via
## TravelCommitment.update_progress() and TravelCommitment.is_stalled().
##
## Progress functions query existing game state fields only — no new data
## structures required. Where upstream systems don't exist yet (SecretSystem,
## WarSystem, SiegeSystem, DuelSystem), those components contribute 0 and
## will activate when the systems are built.


# -- Dispatcher ----------------------------------------------------------------

static func get_progress(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	world_state: Dictionary = {},
) -> float:
	var need_type: String = objective.get("need_type", "")
	match need_type:
		"AVENGE":
			return _progress_avenge(objective, ctx, world_state)
		"BREAK_ALLIANCE":
			return _progress_break_alliance(objective, ctx)
		"ISOLATE_CHARACTER":
			return _progress_isolate_character(objective, ctx)
		"GAIN_WINTER_COURT_INVITATION":
			return _progress_winter_court_invitation(objective, ctx)
		"APPOINT_TO_POSITION":
			return _progress_appoint_character(objective, ctx)
		"REMOVE_FROM_POSITION":
			return _progress_remove_from_position(objective, ctx)
		"RESOLVE_CLAN_WAR":
			return _progress_negotiate_peace(objective, ctx, world_state)
		"OBTAIN_IMPERIAL_EDICT":
			return _progress_obtain_edict(objective, ctx, world_state)
		"EXPOSE_SECRET":
			return _progress_expose_secret(objective, ctx)
		"CONQUER_PROVINCE":
			return _progress_conquer_province(objective, ctx, world_state)
		"INCREASE_KOKU":
			return _progress_increase_koku(objective, ctx)
		"SABOTAGE_ECONOMY":
			return _progress_sabotage_economy(objective, ctx)
	return 0.0


# -- Discovery Confidence Gate (s55.29.3.1) ------------------------------------
# Applied to: ISOLATE_CHARACTER, REMOVE_FROM_POSITION, EXPOSE_SECRET,
# SABOTAGE_ECONOMY. Caps near-completion when investigation is insufficient.

const CONFIDENCE_GATE_MIN_SEASONS: int = 2
const CONFIDENCE_GATE_MIN_INTEL: int = 4
const CONFIDENT_CAP: float = 0.95
const UNCONFIDENT_CAP: float = 0.85

static func _apply_confidence_gate(
	score: float,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	target_id: int,
	intel_actions: Array[String],
) -> float:
	var seasons: int = _objective_age_seasons(objective, ctx)
	var intel_count: int = _count_intel_actions(ctx, target_id, intel_actions)
	if seasons >= CONFIDENCE_GATE_MIN_SEASONS and intel_count >= CONFIDENCE_GATE_MIN_INTEL:
		return maxf(score, CONFIDENT_CAP)
	return maxf(score, UNCONFIDENT_CAP)


static func _objective_age_seasons(objective: Dictionary, ctx: NPCDataStructures.ContextSnapshot) -> int:
	var created_season: int = objective.get("created_season", ctx.season)
	return maxi(ctx.season - created_season, 0)


static func _count_intel_actions(
	ctx: NPCDataStructures.ContextSnapshot,
	target_id: int,
	action_types: Array[String],
) -> int:
	var count: int = 0
	for entry: Dictionary in ctx.action_log:
		if entry.get("target_npc_id", -1) == target_id or target_id < 0:
			if entry.get("action_id", "") in action_types:
				count += 1
	return count


# -- Helper: known allies of target --------------------------------------------
# Returns the list of character IDs the NPC believes to be allies of the target.
# This is stored on the objective as "known_allies" — a snapshot built from
# intelligence actions over time. The objective dict accumulates these IDs as
# the NPC discovers relationships through PROBE/READ_CHARACTER/OBSERVE actions.
# The current disposition (which may have dropped below Friend threshold) is
# checked separately to determine how many have been "severed."

static func _get_known_allies_from_objective(
	objective: Dictionary,
) -> Array[int]:
	var raw: Array = objective.get("known_allies", [])
	var result: Array[int] = []
	for entry: Variant in raw:
		if entry is int:
			result.append(entry)
	return result


# =============================================================================
# 55.28.12 — Avenge Death/Disgrace of [Character X]
# =============================================================================

static func _progress_avenge(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	world_state: Dictionary,
) -> float:
	var score: float = 0.0
	var target_id: int = objective.get("target_npc_id", -1)

	if objective.get("culprit_known", false):
		score += 0.2

	var known_loc: Dictionary = ctx.known_npc_locations.get(target_id, {})
	if not known_loc.is_empty():
		score += 0.15
		var staleness: String = known_loc.get("staleness", "stale")
		if staleness == "fresh":
			score += 0.05

	var same_settlement: bool = target_id in ctx.characters_present
	if same_settlement:
		score += 0.2

	return minf(score, 1.0)


# =============================================================================
# 55.28.1 — Break the alliance between [X] and [Y]
# =============================================================================

static func _progress_break_alliance(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var clan_x: String = objective.get("target_clan_id", "")
	var clan_y: String = objective.get("target_clan_id_secondary", "")

	var contacts_x: Array = ctx.known_contacts_by_clan.get(clan_x, [])
	var contacts_y: Array = ctx.known_contacts_by_clan.get(clan_y, [])
	if contacts_x.size() > 0:
		score += 0.1
	if contacts_y.size() > 0:
		score += 0.1

	var anchor_x: int = objective.get("anchor_x_id", -1)
	var anchor_y: int = objective.get("anchor_y_id", -1)

	if anchor_x >= 0 and anchor_y >= 0:
		var disp: int = ctx.disposition_values.get(anchor_y, 50)
		var threshold: int = 25
		if disp <= threshold:
			return 1.0
		score += maxf(0.0, 0.5 - (float(disp - threshold) / 100.0))

	return minf(score, 1.0)


# =============================================================================
# 55.28.2 — Isolate [Character X] politically
# =============================================================================

static func _progress_isolate_character(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var target_x: int = objective.get("target_npc_id", -1)

	var known_allies: Array[int] = _get_known_allies_from_objective(objective)

	if known_allies.is_empty():
		var intel: int = _count_intel_actions(
			ctx, target_x, ["PROBE", "READ_CHARACTER"] as Array[String]
		)
		score += minf(intel * 0.05, 0.1)
		return score

	score += 0.1

	var total: int = known_allies.size()
	var severed: int = 0
	for ally_id: int in known_allies:
		var disp: int = ctx.disposition_values.get(ally_id, 50)
		if disp < 25:
			severed += 1

	score += (float(severed) / float(total)) * 0.6

	if target_x in ctx.characters_present:
		score += 0.1

	# Discovery confidence gate
	if severed == total and total > 0:
		score = _apply_confidence_gate(
			score, objective, ctx, target_x,
			["PROBE", "READ_CHARACTER", "OBSERVE_COURT_ATTENDEES"] as Array[String],
		)

	return minf(score, 1.0)


# =============================================================================
# 55.28.3 — Gain a Winter Court invitation for my lord
# =============================================================================

static func _progress_winter_court_invitation(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var host_id: int = objective.get("target_npc_id", -1)

	var host_disp: int = ctx.disposition_values.get(host_id, -999)
	if host_disp == -999:
		return 0.1

	score += 0.1

	var threshold: int = 31
	if host_disp >= threshold:
		return 0.95

	var distance: int = threshold - host_disp
	score += maxf(0.0, 0.5 * (1.0 - float(distance) / 61.0))

	if host_id in ctx.characters_present:
		score += 0.15

	return minf(score, 1.0)


# =============================================================================
# 55.28.4 — Have [Character X] appointed to [Position]
# =============================================================================

static func _progress_appoint_character(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var target_x: int = objective.get("target_npc_id", -1)

	var is_vacant: bool = objective.get("position_vacant", false)
	if is_vacant:
		score += 0.15

	var appointer_id: int = objective.get("appointer_id", -1)
	if appointer_id < 0:
		return score + 0.05

	var appointer_disp: int = ctx.disposition_values.get(appointer_id, -999)
	if appointer_disp == -999:
		return score + 0.05

	score += 0.05
	var threshold: int = 31
	if appointer_disp >= threshold:
		score += 0.4
	else:
		var distance: int = threshold - appointer_disp
		score += maxf(0.0, 0.4 * (1.0 - float(distance) / 61.0))

	if appointer_id in ctx.characters_present:
		score += 0.1

	return minf(score, 1.0)


# =============================================================================
# 55.28.5 — Remove [Character X] from [Position]
# =============================================================================

static func _progress_remove_from_position(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var target_x: int = objective.get("target_npc_id", -1)

	var removing_lord: int = objective.get("appointer_id", -1)
	if removing_lord < 0:
		return 0.05

	score += 0.1

	var lord_disp: int = ctx.disposition_values.get(removing_lord, -999)
	if lord_disp == -999:
		return score + 0.05

	if lord_disp <= 0:
		score += 0.35
	elif lord_disp <= 15:
		score += 0.2
	elif lord_disp <= 25:
		score += 0.1

	var known_allies: Array[int] = _get_known_allies_from_objective(objective)
	if known_allies.size() > 0:
		var severed: int = 0
		for ally_id: int in known_allies:
			var disp: int = ctx.disposition_values.get(ally_id, 50)
			if disp < 25:
				severed += 1
		score += (float(severed) / float(known_allies.size())) * 0.15
	else:
		score += 0.1

	if removing_lord in ctx.characters_present:
		score += 0.1

	# Discovery confidence gate
	if lord_disp <= 0 and known_allies.is_empty():
		score = _apply_confidence_gate(
			score, objective, ctx, target_x,
			["PROBE", "READ_CHARACTER", "GATHER_INTELLIGENCE"] as Array[String],
		)

	return minf(score, 1.0)


# =============================================================================
# 55.28.6 — Resolve [Clan War crisis] through negotiation
# =============================================================================

static func _progress_negotiate_peace(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	world_state: Dictionary,
) -> float:
	var score: float = 0.0
	var clan_a: String = objective.get("target_clan_id", "")
	var clan_b: String = objective.get("target_clan_id_secondary", "")

	var contacts_a: Array = ctx.known_contacts_by_clan.get(clan_a, [])
	var contacts_b: Array = ctx.known_contacts_by_clan.get(clan_b, [])

	if contacts_a.size() > 0:
		score += 0.05
	if contacts_b.size() > 0:
		score += 0.05
	if contacts_a.is_empty() or contacts_b.is_empty():
		return score

	score += 0.05

	var active_wars: Array = world_state.get("active_wars", [])
	var war_active: bool = false
	for war: Variant in active_wars:
		if war is Dictionary:
			var w: Dictionary = war
			var wc_a: String = w.get("clan_a", "")
			var wc_b: String = w.get("clan_b", "")
			if (wc_a == clan_a and wc_b == clan_b) or (wc_a == clan_b and wc_b == clan_a):
				war_active = true
				break
	if not war_active:
		return 1.0

	var leader_a_id: int = objective.get("leader_a_id", -1)
	var leader_b_id: int = objective.get("leader_b_id", -1)

	var disp_a: int = ctx.disposition_values.get(leader_a_id, 0)
	var disp_b: int = ctx.disposition_values.get(leader_b_id, 0)

	var trust_a: float = clampf(float(disp_a + 30) / 60.0, 0.0, 1.0)
	var trust_b: float = clampf(float(disp_b + 30) / 60.0, 0.0, 1.0)
	score += ((trust_a + trust_b) / 2.0) * 0.25

	return minf(score, 1.0)


# =============================================================================
# 55.28.7 — Obtain an Imperial Edict on [topic]
# =============================================================================

static func _progress_obtain_edict(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	world_state: Dictionary,
) -> float:
	var score: float = 0.0
	var topic_id: int = objective.get("target_topic_id", -1)
	if topic_id < 0:
		return 0.05

	score += 0.05

	var momentum: float = objective.get("topic_momentum", 0.0)
	if momentum >= 50:
		score += 0.2
	elif momentum >= 25:
		score += 0.1
	else:
		score += 0.05

	var emperor_id: int = world_state.get("emperor_id", -1)
	var emperor_disp: int = ctx.disposition_values.get(emperor_id, 0)
	score += clampf(float(emperor_disp) / 60.0, 0.0, 0.15)

	if emperor_id in ctx.characters_present:
		score += 0.15

	return minf(score, 1.0)


# =============================================================================
# 55.28.8 — Expose [Character X]'s secret publicly
# =============================================================================

static func _progress_expose_secret(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var target_x: int = objective.get("target_npc_id", -1)

	var has_secrets: bool = objective.get("has_secrets_on_target", false)
	if not has_secrets:
		var intel: int = _count_intel_actions(
			ctx, target_x,
			["BRIBE_FOR_INFO", "EAVESDROP", "PROBE", "SEARCH_QUARTERS", "INTERCEPT_LETTER"] as Array[String],
		)
		score += minf(intel * 0.03, 0.1)
		return score

	score += 0.2

	var best_severity: int = objective.get("best_secret_severity", 4)
	match best_severity:
		1: score += 0.25
		2: score += 0.15
		3: score += 0.05

	if objective.get("has_physical_proof", false):
		score += 0.1
	if not objective.get("fabricated", false):
		score += 0.05

	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT, Enums.ContextFlag.VISITING:
			var witnesses: int = ctx.characters_present.size()
			score += minf(witnesses * 0.03, 0.15)

	# Discovery confidence gate
	var seasons: int = _objective_age_seasons(objective, ctx)
	var intel: int = _count_intel_actions(
		ctx, target_x,
		["BRIBE_FOR_INFO", "EAVESDROP", "PROBE", "SEARCH_QUARTERS"] as Array[String],
	)
	if best_severity >= 3 and seasons < 2:
		score = minf(score, 0.6)
	elif best_severity >= 3 and intel < 3:
		score = minf(score, 0.65)

	return minf(score, 1.0)


# =============================================================================
# 55.28.9 — Conquer [Province X]
# =============================================================================

static func _progress_conquer_province(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	world_state: Dictionary,
) -> float:
	var score: float = 0.0
	var target_province: int = objective.get("target_province_id", -1)

	var at_war: bool = objective.get("at_war", false)
	if not at_war:
		var readiness: float = objective.get("war_readiness", 0.0)
		score += minf(readiness * 0.05, 0.1)
		if objective.get("has_justification", false):
			score += 0.05
		return score

	score += 0.15

	if ctx.commanded_unit_id < 0:
		return score

	score += 0.1

	for status_entry: Variant in ctx.province_statuses:
		if status_entry is NPCDataStructures.ProvinceStatus:
			var ps: NPCDataStructures.ProvinceStatus = status_entry
			if ps.province_id == target_province:
				if ps.stability <= 25:
					score += 0.1
				elif ps.stability <= 50:
					score += 0.05
				break

	return minf(score, 1.0)


# =============================================================================
# 55.28.10 — Increase Koku output of [Province X]
# =============================================================================

static func _progress_increase_koku(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var target_province: int = objective.get("target_province_id", -1)

	var current_output: float = objective.get("current_koku_output", 0.0)
	var threshold: float = objective.get("threshold", 1.0)

	if current_output >= threshold:
		return 1.0

	if threshold > 0:
		score += (current_output / threshold) * 0.5

	for status_entry: Variant in ctx.province_statuses:
		if status_entry is NPCDataStructures.ProvinceStatus:
			var ps: NPCDataStructures.ProvinceStatus = status_entry
			if ps.province_id == target_province:
				if ps.active_insurgency_id < 0:
					score += 0.1
				if ps.active_crisis_id < 0:
					score += 0.05
				if ps.stability > 75:
					score += 0.1
				elif ps.stability > 50:
					score += 0.05
				break

	return minf(score, 1.0)


# =============================================================================
# 55.28.11 — Sabotage [Clan X]'s economic output
# =============================================================================

static func _progress_sabotage_economy(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> float:
	var score: float = 0.0
	var target_clan: String = objective.get("target_clan_id", "")

	var known_provinces: Array = objective.get("known_enemy_provinces", [])
	if known_provinces.is_empty():
		var intel: int = _count_intel_actions(
			ctx, -1,
			["GATHER_INTELLIGENCE", "PROBE"] as Array[String],
		)
		score += minf(intel * 0.03, 0.1)
		return score

	score += 0.1

	var disrupted: int = objective.get("disrupted_provinces", 0)
	var total: int = known_provinces.size()
	if total > 0:
		score += (float(disrupted) / float(total)) * 0.4

	var insurgencies: int = objective.get("active_insurgencies", 0)
	score += minf(insurgencies * 0.05, 0.1)

	# Discovery confidence gate
	var seasons: int = _objective_age_seasons(objective, ctx)
	var intel_count: int = _count_intel_actions(
		ctx, -1,
		["GATHER_INTELLIGENCE", "PROBE", "INVESTIGATE_PROVINCE"] as Array[String],
	)
	if seasons < 2 or intel_count < 3:
		score = minf(score, 0.7)

	return minf(score, 1.0)


# =============================================================================
# Seasonal Evaluation Entry Point
# =============================================================================

static func evaluate_all_objectives(
	characters: Array[L5RCharacterData],
	objectives_map: Dictionary,
	world_state: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for character: L5RCharacterData in characters:
		var objectives: Dictionary = objectives_map.get(character.character_id, {})
		var primary: Dictionary = objectives.get("primary", {})
		if primary.is_empty():
			continue

		var need_type: String = primary.get("need_type", "")
		if not PrimaryObjectiveDecomposer.is_primary_objective(need_type):
			continue

		var ctx := NPCDataStructures.ContextSnapshot.new()
		ctx.character_id = character.character_id
		ctx.season = world_state.get("season", 0)
		ctx.disposition_values = character.disposition_values
		ctx.characters_present = []
		ctx.known_contacts_by_clan = character.known_contacts_by_clan
		ctx.known_npc_locations = world_state.get("known_npc_locations", {})
		ctx.action_log = world_state.get("action_log_%d" % character.character_id, [] as Array[Dictionary])
		ctx.context_flag = TravelSystem.get_context_flag(character)
		ctx.province_statuses = world_state.get("province_statuses", [])
		ctx.commanded_unit_id = character.commanded_unit_id

		var progress: float = get_progress(primary, ctx, world_state)
		TravelCommitment.update_progress(primary, progress)

		var stalled: bool = TravelCommitment.is_stalled(primary, character)
		results.append({
			"character_id": character.character_id,
			"need_type": need_type,
			"progress": progress,
			"seasons_without_progress": primary.get("seasons_without_progress", 0),
			"stalled": stalled,
		})

	return results
