extends GutTest
## Tests for ObjectiveProgress per GDD s55.29.3.


func _make_character(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = "castle_a"
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 4
	ctx.disposition_values = {}
	ctx.characters_present = []
	ctx.known_contacts_by_clan = {}
	ctx.known_npc_locations = {}
	ctx.action_log = []
	ctx.province_statuses = []
	return ctx


# =============================================================================
# Dispatcher
# =============================================================================

func test_unknown_objective_returns_zero() -> void:
	var ctx := _make_ctx()
	assert_eq(ObjectiveProgress.get_progress({"need_type": "UNKNOWN"}, ctx), 0.0)


# =============================================================================
# AVENGE
# =============================================================================

func test_avenge_empty_state() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 10}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_eq(p, 0.0)


func test_avenge_culprit_known() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 10, "culprit_known": true}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_almost_eq(p, 0.2, 0.01)


func test_avenge_target_present() -> void:
	var ctx := _make_ctx()
	ctx.characters_present = [10]
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 10, "culprit_known": true}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_almost_eq(p, 0.4, 0.01)


func test_avenge_known_location_fresh() -> void:
	var ctx := _make_ctx()
	ctx.known_npc_locations = {10: {"staleness": "fresh"}}
	var obj: Dictionary = {"need_type": "AVENGE", "target_npc_id": 10, "culprit_known": true}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_almost_eq(p, 0.4, 0.01)


# =============================================================================
# BREAK_ALLIANCE
# =============================================================================

func test_break_alliance_no_contacts() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "BREAK_ALLIANCE",
		"target_clan_id": "crane",
		"target_clan_id_secondary": "lion",
	}
	assert_eq(ObjectiveProgress.get_progress(obj, ctx), 0.0)


func test_break_alliance_has_contacts() -> void:
	var ctx := _make_ctx()
	ctx.known_contacts_by_clan = {"crane": [5], "lion": [6]}
	var obj: Dictionary = {
		"need_type": "BREAK_ALLIANCE",
		"target_clan_id": "crane",
		"target_clan_id_secondary": "lion",
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_almost_eq(p, 0.2, 0.01)


func test_break_alliance_disp_below_threshold() -> void:
	var ctx := _make_ctx()
	ctx.known_contacts_by_clan = {"crane": [5], "lion": [6]}
	ctx.disposition_values = {6: 20}
	var obj: Dictionary = {
		"need_type": "BREAK_ALLIANCE",
		"target_clan_id": "crane",
		"target_clan_id_secondary": "lion",
		"anchor_x_id": 5,
		"anchor_y_id": 6,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_eq(p, 1.0)


# =============================================================================
# ISOLATE_CHARACTER
# =============================================================================

func test_isolate_no_known_allies() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "ISOLATE_CHARACTER", "target_npc_id": 10}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_eq(p, 0.0)


func test_isolate_all_severed_with_confidence() -> void:
	var ctx := _make_ctx()
	# Ally 5 was originally Friend+ but NPC has lowered their disposition
	ctx.disposition_values = {5: 10}
	ctx.action_log = [
		{"target_npc_id": 10, "action_id": "PROBE"},
		{"target_npc_id": 10, "action_id": "PROBE"},
		{"target_npc_id": 10, "action_id": "READ_CHARACTER"},
		{"target_npc_id": 10, "action_id": "READ_CHARACTER"},
	]
	var obj: Dictionary = {
		"need_type": "ISOLATE_CHARACTER",
		"target_npc_id": 10,
		"created_season": 0,
		"known_allies": [5],
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.8)


# =============================================================================
# WINTER_COURT_INVITATION
# =============================================================================

func test_winter_court_unknown_host() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "GAIN_WINTER_COURT_INVITATION", "target_npc_id": 10}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_almost_eq(p, 0.1, 0.01)


func test_winter_court_host_friendly() -> void:
	var ctx := _make_ctx()
	ctx.disposition_values = {10: 35}
	var obj: Dictionary = {"need_type": "GAIN_WINTER_COURT_INVITATION", "target_npc_id": 10}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_eq(p, 0.95)


func test_winter_court_host_present() -> void:
	var ctx := _make_ctx()
	ctx.disposition_values = {10: 15}
	ctx.characters_present = [10]
	var obj: Dictionary = {"need_type": "GAIN_WINTER_COURT_INVITATION", "target_npc_id": 10}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.4)


# =============================================================================
# APPOINT_TO_POSITION
# =============================================================================

func test_appoint_no_appointer() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "APPOINT_TO_POSITION", "target_npc_id": 10}
	assert_lt(ObjectiveProgress.get_progress(obj, ctx), 0.15)


func test_appoint_appointer_friendly() -> void:
	var ctx := _make_ctx()
	ctx.disposition_values = {20: 40}
	var obj: Dictionary = {
		"need_type": "APPOINT_TO_POSITION",
		"target_npc_id": 10,
		"appointer_id": 20,
		"position_vacant": true,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.5)


# =============================================================================
# REMOVE_FROM_POSITION
# =============================================================================

func test_remove_no_lord() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "REMOVE_FROM_POSITION", "target_npc_id": 10}
	assert_almost_eq(ObjectiveProgress.get_progress(obj, ctx), 0.05, 0.01)


func test_remove_lord_hostile() -> void:
	var ctx := _make_ctx()
	ctx.disposition_values = {20: -5}
	var obj: Dictionary = {
		"need_type": "REMOVE_FROM_POSITION",
		"target_npc_id": 10,
		"appointer_id": 20,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.4)


# =============================================================================
# NEGOTIATE_PEACE
# =============================================================================

func test_negotiate_no_war() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "RESOLVE_CLAN_WAR",
		"target_clan_id": "crane",
		"target_clan_id_secondary": "lion",
	}
	var ws: Dictionary = {"active_wars": []}
	ctx.known_contacts_by_clan = {"crane": [5], "lion": [6]}
	var p: float = ObjectiveProgress.get_progress(obj, ctx, ws)
	assert_eq(p, 1.0)


func test_negotiate_active_war_no_trust() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "RESOLVE_CLAN_WAR",
		"target_clan_id": "crane",
		"target_clan_id_secondary": "lion",
		"leader_a_id": 5,
		"leader_b_id": 6,
	}
	ctx.known_contacts_by_clan = {"crane": [5], "lion": [6]}
	ctx.disposition_values = {5: -30, 6: -30}
	var ws: Dictionary = {"active_wars": [{"clan_a": "crane", "clan_b": "lion"}]}
	var p: float = ObjectiveProgress.get_progress(obj, ctx, ws)
	assert_gt(p, 0.1)
	assert_lt(p, 0.5)


# =============================================================================
# OBTAIN_IMPERIAL_EDICT
# =============================================================================

func test_edict_no_topic() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "OBTAIN_IMPERIAL_EDICT"}
	assert_almost_eq(ObjectiveProgress.get_progress(obj, ctx), 0.05, 0.01)


func test_edict_high_momentum_emperor_present() -> void:
	var ctx := _make_ctx()
	ctx.characters_present = [99]
	ctx.disposition_values = {99: 30}
	var obj: Dictionary = {
		"need_type": "OBTAIN_IMPERIAL_EDICT",
		"target_topic_id": 5,
		"topic_momentum": 60.0,
	}
	var ws: Dictionary = {"emperor_id": 99}
	var p: float = ObjectiveProgress.get_progress(obj, ctx, ws)
	assert_gt(p, 0.4)


# =============================================================================
# EXPOSE_SECRET
# =============================================================================

func test_expose_no_secrets() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {"need_type": "EXPOSE_SECRET", "target_npc_id": 10}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_eq(p, 0.0)


func test_expose_has_severity_1_secret() -> void:
	var ctx := _make_ctx()
	ctx.context_flag = Enums.ContextFlag.AT_COURT
	ctx.characters_present = [2, 3, 4, 5, 6]
	var obj: Dictionary = {
		"need_type": "EXPOSE_SECRET",
		"target_npc_id": 10,
		"has_secrets_on_target": true,
		"best_secret_severity": 1,
		"has_physical_proof": true,
		"fabricated": false,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.5)


# =============================================================================
# CONQUER_PROVINCE
# =============================================================================

func test_conquer_not_at_war() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "CONQUER_PROVINCE",
		"target_province_id": 5,
		"at_war": false,
		"war_readiness": 0.8,
		"has_justification": true,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.05)
	assert_lt(p, 0.2)


func test_conquer_at_war_with_army() -> void:
	var ctx := _make_ctx()
	ctx.commanded_unit_id = 1
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 5
	ps.stability = 20.0
	ctx.province_statuses = [ps]
	var obj: Dictionary = {
		"need_type": "CONQUER_PROVINCE",
		"target_province_id": 5,
		"at_war": true,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.3)


# =============================================================================
# INCREASE_KOKU
# =============================================================================

func test_increase_koku_met_threshold() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "INCREASE_KOKU",
		"target_province_id": 3,
		"current_koku_output": 100.0,
		"threshold": 80.0,
	}
	assert_eq(ObjectiveProgress.get_progress(obj, ctx), 1.0)


func test_increase_koku_partial() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "INCREASE_KOKU",
		"target_province_id": 3,
		"current_koku_output": 40.0,
		"threshold": 100.0,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_almost_eq(p, 0.2, 0.01)


# =============================================================================
# SABOTAGE_ECONOMY
# =============================================================================

func test_sabotage_no_provinces_known() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "SABOTAGE_ECONOMY",
		"target_clan_id": "crane",
	}
	assert_eq(ObjectiveProgress.get_progress(obj, ctx), 0.0)


func test_sabotage_disrupted_provinces() -> void:
	var ctx := _make_ctx()
	var obj: Dictionary = {
		"need_type": "SABOTAGE_ECONOMY",
		"target_clan_id": "crane",
		"known_enemy_provinces": [1, 2, 3],
		"disrupted_provinces": 2,
		"active_insurgencies": 1,
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_gt(p, 0.3)


# =============================================================================
# Stall Detection Integration
# =============================================================================

func test_update_progress_tracks_stall() -> void:
	var obj: Dictionary = {
		"need_type": "AVENGE",
		"last_measured_progress": 0.2,
		"seasons_without_progress": 0,
	}
	TravelCommitment.update_progress(obj, 0.2)
	assert_eq(obj["seasons_without_progress"], 1)
	TravelCommitment.update_progress(obj, 0.2)
	assert_eq(obj["seasons_without_progress"], 2)


func test_update_progress_resets_on_gain() -> void:
	var obj: Dictionary = {
		"need_type": "AVENGE",
		"last_measured_progress": 0.2,
		"seasons_without_progress": 3,
	}
	TravelCommitment.update_progress(obj, 0.3)
	assert_eq(obj["seasons_without_progress"], 0)


func test_stall_triggers_at_threshold() -> void:
	var c := _make_character(1)
	c.bushido_virtue = Enums.BushidoVirtue.JIN
	var obj: Dictionary = {
		"need_type": "AVENGE",
		"seasons_without_progress": 2,
	}
	assert_true(TravelCommitment.is_stalled(obj, c))


func test_stall_not_triggered_below_threshold() -> void:
	var c := _make_character(1)
	c.bushido_virtue = Enums.BushidoVirtue.YU
	var obj: Dictionary = {
		"need_type": "AVENGE",
		"seasons_without_progress": 3,
	}
	assert_false(TravelCommitment.is_stalled(obj, c))


func test_chugi_lord_assigned_never_stalls() -> void:
	var c := _make_character(1)
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var obj: Dictionary = {
		"need_type": "AVENGE",
		"seasons_without_progress": 10,
		"lord_assigned": true,
	}
	assert_false(TravelCommitment.is_stalled(obj, c))


func test_chugi_self_selected_stalls() -> void:
	var c := _make_character(1)
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var obj: Dictionary = {
		"need_type": "AVENGE",
		"seasons_without_progress": 3,
		"lord_assigned": false,
	}
	assert_true(TravelCommitment.is_stalled(obj, c))


# =============================================================================
# evaluate_all_objectives (seasonal entry point)
# =============================================================================

func test_evaluate_all_objectives() -> void:
	var c := _make_character(1)
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	var chars: Array[L5RCharacterData] = [c]
	var objectives_map: Dictionary = {
		1: {
			"primary": {
				"need_type": "AVENGE",
				"target_npc_id": 10,
				"culprit_known": true,
				"last_measured_progress": 0.0,
				"seasons_without_progress": 0,
			},
		},
	}
	var world_state: Dictionary = {"season": 2}
	var results: Array[Dictionary] = ObjectiveProgress.evaluate_all_objectives(
		chars, objectives_map, world_state
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["character_id"], 1)
	assert_gt(results[0]["progress"], 0.0)
	assert_false(results[0]["stalled"])


# =============================================================================
# Discovery Confidence Gate
# =============================================================================

func test_confidence_gate_thorough() -> void:
	var ctx := _make_ctx()
	ctx.disposition_values = {5: 10}
	ctx.action_log = [
		{"target_npc_id": 10, "action_id": "PROBE"},
		{"target_npc_id": 10, "action_id": "PROBE"},
		{"target_npc_id": 10, "action_id": "READ_CHARACTER"},
		{"target_npc_id": 10, "action_id": "READ_CHARACTER"},
	]
	var obj: Dictionary = {
		"need_type": "ISOLATE_CHARACTER",
		"target_npc_id": 10,
		"created_season": 0,
		"known_allies": [5],
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_true(p >= ObjectiveProgress.CONFIDENT_CAP)


func test_confidence_gate_insufficient() -> void:
	var ctx := _make_ctx()
	ctx.disposition_values = {5: 10}
	ctx.action_log = [
		{"target_npc_id": 10, "action_id": "PROBE"},
	]
	var obj: Dictionary = {
		"need_type": "ISOLATE_CHARACTER",
		"target_npc_id": 10,
		"created_season": 3,
		"known_allies": [5],
	}
	var p: float = ObjectiveProgress.get_progress(obj, ctx)
	assert_true(p <= ObjectiveProgress.CONFIDENT_CAP)


# =============================================================================
# Arrival Observation
# =============================================================================

func test_arrival_observation_records_knowledge() -> void:
	var observer := _make_character(1)
	var observed := _make_character(2)
	observed.physical_location = "castle_b"
	InformationSystem.record_location_observation(observer, 2, "castle_b", 3)
	assert_eq(observer.knowledge_pool.size(), 1)
	assert_eq(observer.knowledge_pool[0].entry_type, "location")
	assert_eq(observer.knowledge_pool[0].data["character_id"], 2)
	assert_eq(observer.knowledge_pool[0].data["settlement_id"], "castle_b")
	assert_eq(observer.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.FRESH)


func test_arrival_observation_updates_existing() -> void:
	var observer := _make_character(1)
	InformationSystem.record_location_observation(observer, 2, "castle_a", 1)
	InformationSystem.record_location_observation(observer, 2, "castle_b", 3)
	assert_eq(observer.knowledge_pool.size(), 1)
	assert_eq(observer.knowledge_pool[0].data["settlement_id"], "castle_b")
	assert_eq(observer.knowledge_pool[0].season_acquired, 3)
