extends GutTest


# =============================================================================
# Lord-Dependency Classification
# =============================================================================

func test_conquer_province_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("CONQUER_PROVINCE"))


func test_break_alliance_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("BREAK_ALLIANCE"))


func test_isolate_character_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("ISOLATE_CHARACTER"))


func test_gain_invitation_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("GAIN_WINTER_COURT_INVITATION"))


func test_appoint_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("APPOINT_TO_POSITION"))


func test_remove_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("REMOVE_FROM_POSITION"))


func test_resolve_war_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("RESOLVE_CLAN_WAR"))


func test_edict_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("OBTAIN_IMPERIAL_EDICT"))


func test_sabotage_is_lord_dependent() -> void:
	assert_true(OrphanedObjectives.is_lord_dependent("SABOTAGE_ECONOMY"))


func test_expose_secret_is_target_dependent() -> void:
	assert_true(OrphanedObjectives.is_target_dependent("EXPOSE_SECRET"))


func test_increase_koku_is_target_dependent() -> void:
	assert_true(OrphanedObjectives.is_target_dependent("INCREASE_KOKU"))


func test_avenge_is_target_dependent() -> void:
	assert_true(OrphanedObjectives.is_target_dependent("AVENGE"))


func test_lord_dependent_not_target() -> void:
	assert_false(OrphanedObjectives.is_target_dependent("CONQUER_PROVINCE"))


func test_target_dependent_not_lord() -> void:
	assert_false(OrphanedObjectives.is_lord_dependent("AVENGE"))


# =============================================================================
# Objective Validity Check
# =============================================================================

func test_lord_dependent_objective_orphans_on_lord_death() -> void:
	var obj: Dictionary = {
		"objective_type": "CONQUER_PROVINCE",
		"assigning_lord_id": 10,
	}
	var result: String = OrphanedObjectives.check_objective_validity(obj, 10)
	assert_eq(result, "ORPHANED")


func test_target_dependent_objective_persists() -> void:
	var obj: Dictionary = {
		"objective_type": "AVENGE",
		"assigning_lord_id": 10,
	}
	var result: String = OrphanedObjectives.check_objective_validity(obj, 10)
	assert_eq(result, "ACTIVE")


func test_different_lord_death_does_not_orphan() -> void:
	var obj: Dictionary = {
		"objective_type": "CONQUER_PROVINCE",
		"assigning_lord_id": 10,
	}
	var result: String = OrphanedObjectives.check_objective_validity(obj, 99)
	assert_eq(result, "ACTIVE")


func test_unknown_objective_type_stays_active() -> void:
	var obj: Dictionary = {
		"objective_type": "UNKNOWN_TYPE",
		"assigning_lord_id": 10,
	}
	var result: String = OrphanedObjectives.check_objective_validity(obj, 10)
	assert_eq(result, "ACTIVE")


# =============================================================================
# Process Lord Death
# =============================================================================

func test_process_lord_death_orphans_vassals() -> void:
	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	vassal.lord_id = 10

	var vassals: Array[L5RCharacterData] = [vassal]
	var objectives: Dictionary = {
		1: {
			"primary": {
				"objective_type": "CONQUER_PROVINCE",
				"assigning_lord_id": 10,
			},
		},
	}

	var results: Array[Dictionary] = OrphanedObjectives.process_lord_death(
		vassals, 10, 20, objectives
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0]["vassal_id"], 1)
	assert_eq(results[0]["status"], "ORPHANED")
	assert_eq(results[0]["report_target_id"], 20)
	assert_eq(objectives[1]["primary"]["status"], "ORPHANED")


func test_process_lord_death_skips_target_dependent() -> void:
	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	vassal.lord_id = 10

	var vassals: Array[L5RCharacterData] = [vassal]
	var objectives: Dictionary = {
		1: {
			"primary": {
				"objective_type": "AVENGE",
				"assigning_lord_id": 10,
			},
		},
	}

	var results: Array[Dictionary] = OrphanedObjectives.process_lord_death(
		vassals, 10, 20, objectives
	)

	assert_eq(results.size(), 0)


func test_process_lord_death_skips_non_vassals() -> void:
	var non_vassal := L5RCharacterData.new()
	non_vassal.character_id = 1
	non_vassal.lord_id = 99

	var vassals: Array[L5RCharacterData] = [non_vassal]
	var objectives: Dictionary = {
		1: {
			"primary": {
				"objective_type": "CONQUER_PROVINCE",
				"assigning_lord_id": 99,
			},
		},
	}

	var results: Array[Dictionary] = OrphanedObjectives.process_lord_death(
		vassals, 10, 20, objectives
	)

	assert_eq(results.size(), 0)


func test_process_lord_death_no_successor_uses_operational_superior() -> void:
	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	vassal.lord_id = 10
	vassal.operational_superior_id = 50

	var vassals: Array[L5RCharacterData] = [vassal]
	var objectives: Dictionary = {
		1: {
			"primary": {
				"objective_type": "CONQUER_PROVINCE",
				"assigning_lord_id": 10,
			},
		},
	}

	var results: Array[Dictionary] = OrphanedObjectives.process_lord_death(
		vassals, 10, -1, objectives
	)

	assert_eq(results[0]["report_target_id"], 50)


func test_process_lord_death_multiple_vassals() -> void:
	var v1 := L5RCharacterData.new()
	v1.character_id = 1
	v1.lord_id = 10

	var v2 := L5RCharacterData.new()
	v2.character_id = 2
	v2.lord_id = 10

	var vassals: Array[L5RCharacterData] = [v1, v2]
	var objectives: Dictionary = {
		1: {"primary": {"objective_type": "CONQUER_PROVINCE", "assigning_lord_id": 10}},
		2: {"primary": {"objective_type": "ISOLATE_CHARACTER", "assigning_lord_id": 10}},
	}

	var results: Array[Dictionary] = OrphanedObjectives.process_lord_death(
		vassals, 10, 20, objectives
	)

	assert_eq(results.size(), 2)


# =============================================================================
# Generate Report Need
# =============================================================================

func test_generate_report_need_with_successor() -> void:
	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	var result: Dictionary = OrphanedObjectives.generate_report_need(vassal, 20)
	assert_eq(result["need_type"], "REPORT_TO_NEW_LORD")
	assert_eq(result["target_npc_id"], 20)
	assert_eq(result["priority"], 2)


func test_generate_report_need_no_successor_uses_superior() -> void:
	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	vassal.operational_superior_id = 50
	var result: Dictionary = OrphanedObjectives.generate_report_need(vassal, -1)
	assert_eq(result["target_npc_id"], 50)


func test_generate_report_need_no_one_returns_empty() -> void:
	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	var result: Dictionary = OrphanedObjectives.generate_report_need(vassal, -1)
	assert_true(result.is_empty())


# =============================================================================
# Resolve Orphaned Objective
# =============================================================================

func test_confirm_reactivates_objective() -> void:
	var objectives: Dictionary = {
		"primary": {
			"objective_type": "CONQUER_PROVINCE",
			"status": "ORPHANED",
		},
	}
	var result: Dictionary = OrphanedObjectives.resolve_orphaned_objective(
		objectives, "CONFIRM"
	)
	assert_eq(result["action"], "CONFIRM")
	assert_eq(objectives["primary"]["status"], "ACTIVE")


func test_modify_replaces_objective() -> void:
	var objectives: Dictionary = {
		"primary": {
			"objective_type": "CONQUER_PROVINCE",
			"status": "ORPHANED",
		},
	}
	var new_obj: Dictionary = {
		"objective_type": "DEFEND_PROVINCE",
		"target_province_id": 5,
	}
	var result: Dictionary = OrphanedObjectives.resolve_orphaned_objective(
		objectives, "MODIFY", new_obj
	)
	assert_eq(result["action"], "MODIFY")
	assert_eq(objectives["primary"]["objective_type"], "DEFEND_PROVINCE")
	assert_eq(objectives["primary"]["status"], "ACTIVE")


func test_cancel_removes_objective() -> void:
	var objectives: Dictionary = {
		"primary": {
			"objective_type": "CONQUER_PROVINCE",
			"status": "ORPHANED",
		},
	}
	var result: Dictionary = OrphanedObjectives.resolve_orphaned_objective(
		objectives, "CANCEL"
	)
	assert_eq(result["action"], "CANCEL")
	assert_false(objectives.has("primary"))


# =============================================================================
# Has Orphaned Vassals
# =============================================================================

func test_has_orphaned_vassals_finds_them() -> void:
	var v1 := L5RCharacterData.new()
	v1.character_id = 1
	v1.lord_id = 20

	var v2 := L5RCharacterData.new()
	v2.character_id = 2
	v2.lord_id = 20

	var vassals: Array[L5RCharacterData] = [v1, v2]
	var objectives: Dictionary = {
		1: {"primary": {"status": "ORPHANED"}},
		2: {"primary": {"status": "ACTIVE"}},
	}

	var orphaned: Array[int] = OrphanedObjectives.has_orphaned_vassals(
		vassals, 20, objectives
	)
	assert_eq(orphaned.size(), 1)
	assert_true(1 in orphaned)


func test_has_orphaned_vassals_empty_when_none() -> void:
	var v1 := L5RCharacterData.new()
	v1.character_id = 1
	v1.lord_id = 20

	var vassals: Array[L5RCharacterData] = [v1]
	var objectives: Dictionary = {
		1: {"primary": {"status": "ACTIVE"}},
	}

	var orphaned: Array[int] = OrphanedObjectives.has_orphaned_vassals(
		vassals, 20, objectives
	)
	assert_eq(orphaned.size(), 0)


# =============================================================================
# GDD s55.33.3 Ratio — 9 Lord-Dependent, 3 Target-Dependent
# =============================================================================

func test_lord_dependent_count() -> void:
	assert_eq(OrphanedObjectives.LORD_DEPENDENT_OBJECTIVES.size(), 9)


func test_target_dependent_count() -> void:
	assert_eq(OrphanedObjectives.TARGET_DEPENDENT_OBJECTIVES.size(), 3)
