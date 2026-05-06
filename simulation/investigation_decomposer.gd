class_name InvestigationDecomposer
## Decomposes INVESTIGATE_CRIME objectives into ImmediateNeeds per GDD s57.16.
## Seven-phase investigation loop: travel → examine scene → interview witnesses →
## interview suspects → check alibis → follow leads → resolve (accuse or close).
## Stateless — evaluates objective state each AP and returns the next step.

const ACCUSATION_THRESHOLD: int = 40


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

	# Phase 2: Examine the crime scene
	if not scene_examined:
		return _make_investigate_threat_need(crime_location)

	# Phase 3: Interview uninterviewed witnesses
	var uninterviewed: Array = _get_uninterviewed(witness_pool, interviewed_witnesses)
	if uninterviewed.size() > 0:
		var target_id: int = _prioritize_witness(uninterviewed, ctx)
		var target_location: String = _get_npc_location(target_id, objective)
		if ctx.location_id != target_location:
			return _make_travel_need(target_location)
		return _make_gather_intelligence_need(target_id)

	# Phase 4: Interview suspects
	for suspect_id: Variant in known_suspects:
		if suspect_id is int and suspect_id not in interviewed_suspects:
			var suspect_location: String = _get_npc_location(suspect_id, objective)
			if ctx.location_id != suspect_location:
				return _make_travel_need(suspect_location)
			return _make_gather_intelligence_need(suspect_id)

	# Phase 5: Check alibis
	var unchecked: Array = _get_unchecked_alibis(objective, checked_alibis)
	if unchecked.size() > 0:
		var alibi_witness_id: int = unchecked[0].get("claimed_with", -1)
		if alibi_witness_id > 0:
			var alibi_location: String = _get_npc_location(alibi_witness_id, objective)
			if ctx.location_id != alibi_location:
				return _make_travel_need(alibi_location)
			return _make_gather_intelligence_need(alibi_witness_id)

	# Phase 6: Follow unresolved leads
	if unresolved_leads.size() > 0:
		var lead: Dictionary = unresolved_leads[0] if unresolved_leads[0] is Dictionary else {}
		return _decompose_lead(lead, ctx, objective)

	# Phase 7: Resolution
	if evidence_total >= ACCUSATION_THRESHOLD:
		return _make_accuse_need(known_suspects)
	else:
		return _make_close_case_need()


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
	need.need_type = "ASSIGN_OBJECTIVE"
	need.source = "INVESTIGATE_CRIME"
	need.target_intent = "FORMALLY_ACCUSE"
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


static func _get_npc_location(npc_id: int, objective: Dictionary) -> String:
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
		var loc: String = _get_npc_location(lead_target, objective)
		if ctx.location_id != loc:
			return _make_travel_need(loc)
		return _make_gather_intelligence_need(lead_target)

	if lead_type == "location":
		var loc: String = lead.get("location", "")
		if not loc.is_empty() and ctx.location_id != loc:
			return _make_travel_need(loc)
		return _make_investigate_threat_need(loc)

	return _make_close_case_need()
