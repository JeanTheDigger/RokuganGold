extends GutTest


func _make_ctx(location: String = "zone_a", present: Array[int] = []) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.location_id = location
	ctx.characters_present = present
	return ctx


func _make_objective(overrides: Dictionary = {}) -> Dictionary:
	var obj: Dictionary = {
		"need_type": "INVESTIGATE_CRIME",
		"crime_location": "zone_a",
		"scene_examined": false,
		"known_suspects": [],
		"evidence_total": 0,
		"witness_pool": [],
		"interviewed_witnesses": [],
		"interviewed_suspects": [],
		"checked_alibis": [],
		"alibis": [],
		"unresolved_leads": [],
		"npc_locations": {},
	}
	obj.merge(overrides, true)
	return obj


# -- Phase 1: Travel to scene --------------------------------------------------

func test_phase1_travel_to_scene():
	var ctx := _make_ctx("zone_b")
	var obj := _make_objective()
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_a")
	assert_eq(need.source, "INVESTIGATE_CRIME")


# -- Phase 2: Examine crime scene ----------------------------------------------

func test_phase2_examine_scene():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective()
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_intent, "zone_a")


func test_phase2_skipped_if_already_examined():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({"scene_examined": true})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_ne(need.need_type, "INVESTIGATE_THREAT")


# -- Phase 3: Interview witnesses ----------------------------------------------

func test_phase3_interview_witness():
	var ctx := _make_ctx("zone_a", [200])
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200, 201],
		"npc_locations": {200: "zone_a", 201: "zone_b"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 200)


func test_phase3_travel_to_witness():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200],
		"npc_locations": {200: "zone_b"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_b")


func test_phase3_skip_already_interviewed():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200],
		"interviewed_witnesses": [200],
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_ne(need.need_type, "GATHER_INTELLIGENCE")


# -- Phase 4: Interview suspects -----------------------------------------------

func test_phase4_interview_suspect():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"npc_locations": {300: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 300)


func test_phase4_travel_to_suspect():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"npc_locations": {300: "zone_c"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_c")


func test_phase4_skip_interviewed_suspect():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"interviewed_suspects": [300],
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_ne(need.target_npc_id, 300)


# -- Phase 5: Check alibis ----------------------------------------------------

func test_phase5_check_alibi():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"interviewed_suspects": [300],
		"alibis": [{"id": 1, "claimed_with": 400}],
		"npc_locations": {400: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 400)


func test_phase5_travel_for_alibi():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"interviewed_suspects": [300],
		"alibis": [{"id": 1, "claimed_with": 400}],
		"npc_locations": {400: "zone_d"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_d")


func test_phase5_skip_checked_alibi():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"interviewed_suspects": [300],
		"alibis": [{"id": 1, "claimed_with": 400}],
		"checked_alibis": [1],
		"npc_locations": {400: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_ne(need.target_npc_id, 400)


# -- Phase 6: Follow leads ----------------------------------------------------

func test_phase6_follow_witness_lead():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"unresolved_leads": [{"type": "witness", "target_npc_id": 500}],
		"npc_locations": {500: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 500)


func test_phase6_follow_location_lead():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"unresolved_leads": [{"type": "location", "location": "zone_e"}],
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_e")


# -- Phase 7: Resolution ------------------------------------------------------

func test_phase7_accuse_when_threshold_met():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"evidence_total": 40,
		"known_suspects": [300],
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "ASSIGN_OBJECTIVE")
	assert_eq(need.target_intent, "FORMALLY_ACCUSE")
	assert_eq(need.target_npc_id, 300)


func test_phase7_accuse_above_threshold():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"evidence_total": 55,
		"known_suspects": [300],
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "ASSIGN_OBJECTIVE")
	assert_eq(need.target_intent, "FORMALLY_ACCUSE")


func test_phase7_close_case_insufficient_evidence():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"evidence_total": 20,
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")
	assert_eq(need.source, "INVESTIGATE_CRIME_CLOSED")


# -- Witness prioritization ----------------------------------------------------

func test_prioritize_present_witness():
	var ctx := _make_ctx("zone_a", [201])
	var candidates: Array = [200, 201]
	var result: int = InvestigationDecomposer._prioritize_witness(candidates, ctx)
	assert_eq(result, 201)


func test_prioritize_single_witness():
	var ctx := _make_ctx("zone_a")
	var result: int = InvestigationDecomposer._prioritize_witness([200], ctx)
	assert_eq(result, 200)


# -- Integration with ObjectiveDecomposer -------------------------------------

func test_objective_decomposer_routes_investigate_crime():
	var ctx := _make_ctx("zone_b")
	var obj: Dictionary = {
		"need_type": "INVESTIGATE_CRIME",
		"crime_location": "zone_a",
		"scene_examined": false,
		"known_suspects": [],
		"evidence_total": 0,
		"witness_pool": [],
		"interviewed_witnesses": [],
		"interviewed_suspects": [],
		"checked_alibis": [],
		"alibis": [],
		"unresolved_leads": [],
		"npc_locations": {},
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.source, "INVESTIGATE_CRIME")


func test_objective_decomposer_routes_uphold_law():
	var ctx := _make_ctx("zone_b")
	var case_data: Dictionary = {
		"crime_location": "zone_a",
		"scene_examined": false,
		"known_suspects": [],
		"evidence_total": 0,
		"witness_pool": [],
		"interviewed_witnesses": [],
		"interviewed_suspects": [],
		"checked_alibis": [],
		"alibis": [],
		"unresolved_leads": [],
		"npc_locations": {},
	}
	var obj: Dictionary = {
		"need_type": "UPHOLD_LAW",
		"active_case": case_data,
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.source, "INVESTIGATE_CRIME")


func test_uphold_law_no_active_case_patrols():
	var ctx := _make_ctx("zone_a")
	var obj: Dictionary = {
		"need_type": "UPHOLD_LAW",
		"active_case": {},
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")


func test_uphold_law_idle_travels_to_jurisdiction():
	var ctx := _make_ctx("crane_castle")
	var obj: Dictionary = {
		"need_type": "UPHOLD_LAW",
		"active_case": {},
		"jurisdiction_province": "lion",
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "lion")


func test_uphold_law_idle_patrols_after_recent_investigation():
	var ctx := _make_ctx("zone_a")
	ctx.ic_day = 50
	var obj: Dictionary = {
		"need_type": "UPHOLD_LAW",
		"active_case": {},
		"last_patrol_ic_day": 48,
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "PATROL_PROVINCE")


func test_uphold_law_idle_investigates_after_interval():
	var ctx := _make_ctx("zone_a")
	ctx.ic_day = 50
	var obj: Dictionary = {
		"need_type": "UPHOLD_LAW",
		"active_case": {},
		"last_patrol_ic_day": 40,
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")


# -- Evidence-Aware Scoring Tests ----------------------------------------------

func test_scoring_witness_prioritized_over_suspect():
	var ctx := _make_ctx("zone_a", [200, 300])
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200],
		"known_suspects": [300],
		"npc_locations": {200: "zone_a", 300: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 200)


func test_scoring_present_witness_beats_absent_witness():
	var ctx := _make_ctx("zone_a", [201])
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200, 201],
		"npc_locations": {200: "zone_b", 201: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 201)


func test_scoring_suspect_chosen_when_no_witnesses():
	var ctx := _make_ctx("zone_a", [300])
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"npc_locations": {300: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 300)


func test_scoring_reexamine_scene_low_evidence():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"scene_exam_count": 0,
		"evidence_total": 5,
		"ic_day_committed": 1,
	})
	ctx.ic_day = 10
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_intent, "zone_a")


func test_scoring_no_reexamine_at_max_count():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"scene_exam_count": 1,
		"evidence_total": 5,
		"ic_day_committed": 1,
	})
	ctx.ic_day = 10
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")
	assert_eq(need.source, "INVESTIGATE_CRIME_CLOSED")


func test_scoring_no_reexamine_above_evidence_cap():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"scene_exam_count": 1,
		"evidence_total": 16,
		"ic_day_committed": 1,
	})
	ctx.ic_day = 10
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")
	assert_eq(need.source, "INVESTIGATE_CRIME_CLOSED")


func test_scoring_no_reexamine_scene_too_old():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"scene_exam_count": 1,
		"evidence_total": 5,
		"ic_day_committed": 1,
	})
	ctx.ic_day = 35
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "REST")
	assert_eq(need.source, "INVESTIGATE_CRIME_CLOSED")


func test_scoring_lead_with_high_priority_beats_alibi():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"known_suspects": [300],
		"interviewed_suspects": [300],
		"alibis": [{"id": 1, "claimed_with": 400}],
		"unresolved_leads": [{"type": "witness", "target_npc_id": 500, "priority": 5}],
		"npc_locations": {400: "zone_b", 500: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 500)


func test_scoring_evidence_gap_bonus_for_witnesses():
	var ctx := _make_ctx("zone_a", [200])
	var obj := _make_objective({
		"scene_examined": true,
		"evidence_total": 25,
		"witness_pool": [200],
		"npc_locations": {200: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "GATHER_INTELLIGENCE")
	assert_eq(need.target_npc_id, 200)


func test_scoring_travels_to_best_candidate_location():
	var ctx := _make_ctx("zone_a")
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200],
		"npc_locations": {200: "zone_c"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_c")


func test_early_accusation_skips_scoring():
	var ctx := _make_ctx("zone_a", [200])
	var obj := _make_objective({
		"scene_examined": true,
		"evidence_total": 40,
		"known_suspects": [300],
		"witness_pool": [200],
		"npc_locations": {200: "zone_a"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "ASSIGN_OBJECTIVE")
	assert_eq(need.target_intent, "FORMALLY_ACCUSE")


func test_ctx_known_npc_locations_used_for_travel():
	var ctx := _make_ctx("zone_a")
	ctx.known_npc_locations = {200: "zone_d"}
	var obj := _make_objective({
		"scene_examined": true,
		"witness_pool": [200],
		"npc_locations": {200: "zone_b"},
	})
	var need: NPCDataStructures.ImmediateNeed = InvestigationDecomposer.decompose(obj, ctx)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_intent, "zone_d")
