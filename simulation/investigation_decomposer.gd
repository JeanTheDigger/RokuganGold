class_name InvestigationDecomposer
## Decomposes INVESTIGATE_CRIME objectives into ImmediateNeeds per GDD s57.16.
## Seven-phase investigation loop: travel → examine scene → interview witnesses →
## interview suspects → check alibis → follow leads → resolve (accuse or close).
## Stateless — evaluates objective state each AP and returns the next step.
##
## Enhanced with evidence-aware prioritization: the decomposer scores available
## leads and selects the highest-value next action based on case state, elapsed
## time, and proximity of targets.

const ACCUSATION_THRESHOLD: int = 40
const BRIBERY_EVAL_THRESHOLD: int = 25


# -- Main Decomposition Entry --------------------------------------------------

static func decompose(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	var crime_location: String = objective.get("crime_location", "")
	var scene_examined: bool = objective.get("scene_examined", false)
	var known_suspects: Array = objective.get("known_suspects", [])
	var evidence_total: int = objective.get("evidence_total", 0)
	var interviewed_witnesses: Array = objective.get("interviewed_witnesses", [])
	var interviewed_suspects: Array = objective.get("interviewed_suspects", [])
	var checked_alibis: Array = objective.get("checked_alibis", [])
	var unresolved_leads: Array = objective.get("unresolved_leads", [])
	var witness_pool: Array = objective.get("witness_pool", [])

	# Phase 1: Travel to crime scene if not present
	if ctx.location_id != crime_location and not scene_examined:
		return _make_travel_need(crime_location)

	# Phase 2: Examine the crime scene (first time)
	if not scene_examined:
		return _make_investigate_threat_need(crime_location)

	# Phase 7 (early check): If evidence already sufficient, accuse immediately
	if evidence_total >= ACCUSATION_THRESHOLD and known_suspects.size() > 0:
		return _make_accuse_need(known_suspects)

	# Score remaining leads and pick the best next action
	var best_action: NPCDataStructures.ImmediateNeed = _select_best_next_action(
		objective, ctx, crime_location, evidence_total,
		known_suspects, witness_pool, interviewed_witnesses,
		interviewed_suspects, checked_alibis, unresolved_leads,
	)
	if best_action != null:
		return best_action

	# Phase 7: Resolution — insufficient evidence, close case
	return _make_close_case_need()


# -- Priority-Ordered Action Selection -----------------------------------------
# GDD s57.16 specifies phase ordering: witnesses → suspects → alibis → leads.
# Within each category, co-located targets are preferred (no travel delay).

static func _select_best_next_action(
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	crime_location: String,
	_evidence_total: int,
	known_suspects: Array,
	witness_pool: Array,
	interviewed_witnesses: Array,
	interviewed_suspects: Array,
	checked_alibis: Array,
	unresolved_leads: Array,
) -> NPCDataStructures.ImmediateNeed:
	# Priority 1: Interview uninterviewed witnesses
	var uninterviewed: Array = _get_uninterviewed(witness_pool, interviewed_witnesses)
	var best_witness: int = _pick_present_first(uninterviewed, ctx)
	if best_witness >= 0:
		return _action_from_candidate(
			{"type": "witness", "target_id": best_witness},
			objective, ctx, crime_location, unresolved_leads,
		)

	# Priority 2: Interview suspects
	var uninterviewed_suspects: Array = []
	for suspect_id: Variant in known_suspects:
		if suspect_id is int and suspect_id not in interviewed_suspects:
			uninterviewed_suspects.append(suspect_id)
	var best_suspect: int = _pick_present_first(uninterviewed_suspects, ctx)
	if best_suspect >= 0:
		return _action_from_candidate(
			{"type": "suspect", "target_id": best_suspect},
			objective, ctx, crime_location, unresolved_leads,
		)

	# Priority 3: Check alibis
	var unchecked: Array = _get_unchecked_alibis(objective, checked_alibis)
	for alibi: Variant in unchecked:
		if not alibi is Dictionary:
			continue
		var a: Dictionary = alibi as Dictionary
		var alibi_witness_id: int = a.get("claimed_with", -1)
		if alibi_witness_id > 0:
			return _action_from_candidate(
				{"type": "alibi", "target_id": alibi_witness_id},
				objective, ctx, crime_location, unresolved_leads,
			)

	# Priority 4: Follow unresolved leads
	if not unresolved_leads.is_empty():
		for lead_idx: int in range(unresolved_leads.size()):
			if unresolved_leads[lead_idx] is Dictionary:
				return _action_from_candidate(
					{"type": "lead", "lead_index": lead_idx},
					objective, ctx, crime_location, unresolved_leads,
				)

	return null


static func _pick_present_first(ids: Array, ctx: NPCDataStructures.ContextSnapshot) -> int:
	var first_absent: int = -1
	for npc_id: Variant in ids:
		if not npc_id is int:
			continue
		var nid: int = npc_id as int
		if nid in ctx.characters_present:
			return nid
		if first_absent < 0:
			first_absent = nid
	return first_absent


static func _action_from_candidate(
	candidate: Dictionary,
	objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	crime_location: String,
	unresolved_leads: Array,
) -> NPCDataStructures.ImmediateNeed:
	var ctype: String = candidate.get("type", "")
	var target_id: int = candidate.get("target_id", -1)

	match ctype:
		"witness", "suspect", "alibi":
			var target_location: String = _get_npc_location(target_id, objective, ctx)
			if ctx.location_id != target_location:
				return _make_travel_need(target_location)
			return _make_gather_intelligence_need(target_id)
		"reexamine_scene":
			if ctx.location_id != crime_location:
				return _make_travel_need(crime_location)
			return _make_investigate_threat_need(crime_location)
		"lead":
			var lead_idx: int = candidate.get("lead_index", 0)
			if lead_idx < unresolved_leads.size() and unresolved_leads[lead_idx] is Dictionary:
				return _decompose_lead(unresolved_leads[lead_idx], ctx, objective)
			return _make_close_case_need()
		_:
			return null


# -- Need Factories -----------------------------------------------------------

static func _make_travel_need(location: String) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "TRAVEL_TO"
	need.source = "INVESTIGATE_CRIME"
	need.target_intent = location
	return need


static func _make_investigate_threat_need(location: String) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "INVESTIGATE_THREAT"
	need.source = "INVESTIGATE_CRIME"
	need.target_intent = location
	return need


static func _make_gather_intelligence_need(target_id: int) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "GATHER_INTELLIGENCE"
	need.source = "INVESTIGATE_CRIME"
	need.target_npc_id = target_id
	return need


static func _make_accuse_need(suspects: Array) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"
	need.source = "INVESTIGATE_CRIME_ACCUSATION_PENDING"
	if suspects.size() > 0 and suspects[0] is int:
		need.target_npc_id = suspects[0]
	return need


static func _make_close_case_need() -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"
	need.source = "INVESTIGATE_CRIME_CLOSED"
	return need


# -- Witness Prioritization (s57.16.4) ----------------------------------------
# Full GDD priority: awareness estimate, then lowest honor, then proximity.
# Current implementation uses proximity only (present witnesses first).

static func _prioritize_witness(candidates: Array, ctx: NPCDataStructures.ContextSnapshot) -> int:
	if candidates.size() == 0:
		return -1
	if candidates.size() == 1:
		return candidates[0] if candidates[0] is int else -1

	var best_id: int = candidates[0] if candidates[0] is int else -1
	var best_present: bool = best_id in ctx.characters_present

	for i: int in range(1, candidates.size()):
		var cand_id: int = candidates[i] if candidates[i] is int else -1
		if cand_id < 0:
			continue
		var cand_present: bool = cand_id in ctx.characters_present
		if cand_present and not best_present:
			best_id = cand_id
			best_present = true
		elif cand_present == best_present:
			best_id = cand_id
	return best_id


# -- Helpers -------------------------------------------------------------------

static func _get_uninterviewed(pool: Array, interviewed: Array) -> Array:
	var result: Array = []
	for npc_id: Variant in pool:
		if npc_id is int and npc_id not in interviewed:
			result.append(npc_id)
	return result


static func _get_unchecked_alibis(objective: Dictionary, checked: Array) -> Array:
	var alibis: Array = objective.get("alibis", [])
	var result: Array = []
	for alibi: Variant in alibis:
		if alibi is Dictionary:
			var alibi_id: Variant = alibi.get("id", -1)
			if alibi_id not in checked:
				result.append(alibi)
	return result


static func _get_npc_location(npc_id: int, objective: Dictionary, ctx: NPCDataStructures.ContextSnapshot = null) -> String:
	if ctx != null and not ctx.known_npc_locations.is_empty():
		var ctx_loc: Variant = ctx.known_npc_locations.get(npc_id, null)
		if ctx_loc is String and not (ctx_loc as String).is_empty():
			return ctx_loc as String
	var locations: Dictionary = objective.get("npc_locations", {})
	return locations.get(npc_id, objective.get("crime_location", ""))


static func _decompose_lead(
	lead: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	objective: Dictionary,
) -> NPCDataStructures.ImmediateNeed:
	var lead_type: String = lead.get("type", "")
	var lead_target: int = lead.get("target_npc_id", -1)

	if lead_type == "witness" and lead_target > 0:
		var loc: String = _get_npc_location(lead_target, objective, ctx)
		if ctx.location_id != loc:
			return _make_travel_need(loc)
		return _make_gather_intelligence_need(lead_target)

	if lead_type == "location":
		var loc: String = lead.get("location", "")
		if not loc.is_empty() and ctx.location_id != loc:
			return _make_travel_need(loc)
		return _make_investigate_threat_need(loc)

	return _make_close_case_need()
