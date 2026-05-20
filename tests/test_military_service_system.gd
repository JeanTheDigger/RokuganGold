extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_retainer(id: int, role: String = "uncommitted") -> Dictionary:
	return {"character_id": id, "role": role}


func _make_char_data(id: int, lord_id: int = 100) -> Dictionary:
	return {
		"character_id": id,
		"lord_id": lord_id,
		"operational_superior_id": lord_id,
		"assigned_company_id": -1,
	}


# -- Service Request Tests -------------------------------------------------------

func test_create_service_request() -> void:
	var r: Dictionary = MilitaryServiceSystem.create_service_request(
		1, 10, Enums.MilitaryRank.CHUI, 3,
	)
	assert_eq(r["requesting_commander_id"], 1)
	assert_eq(r["target_unit_id"], 10)
	assert_eq(r["rank_needed"], Enums.MilitaryRank.CHUI)
	assert_eq(r["count"], 3)
	assert_eq(r["fulfilled"], 0)
	assert_eq(r["assigned_character_ids"].size(), 0)


func test_create_service_request_default_count() -> void:
	var r: Dictionary = MilitaryServiceSystem.create_service_request(
		1, 10, Enums.MilitaryRank.CHUI,
	)
	assert_eq(r["count"], 1)


# -- Cascade Request Tests -------------------------------------------------------

func test_cascade_even_split() -> void:
	var vassals: Array = [10, 20, 30]
	var assignments: Array = MilitaryServiceSystem.cascade_request_to_vassals(
		1, vassals, 6,
	)
	assert_eq(assignments.size(), 3)
	assert_eq(assignments[0]["count_requested"], 2)
	assert_eq(assignments[1]["count_requested"], 2)
	assert_eq(assignments[2]["count_requested"], 2)
	assert_eq(assignments[0]["from_lord_id"], 1)


func test_cascade_uneven_split() -> void:
	var vassals: Array = [10, 20, 30]
	var assignments: Array = MilitaryServiceSystem.cascade_request_to_vassals(
		1, vassals, 5,
	)
	# 5 / 3 = 1 each, remainder 2 → first two get +1
	assert_eq(assignments[0]["count_requested"], 2)
	assert_eq(assignments[1]["count_requested"], 2)
	assert_eq(assignments[2]["count_requested"], 1)


func test_cascade_single_vassal() -> void:
	var vassals: Array = [10]
	var assignments: Array = MilitaryServiceSystem.cascade_request_to_vassals(
		1, vassals, 4,
	)
	assert_eq(assignments.size(), 1)
	assert_eq(assignments[0]["count_requested"], 4)


func test_cascade_empty_vassals() -> void:
	var vassals: Array = []
	var assignments: Array = MilitaryServiceSystem.cascade_request_to_vassals(
		1, vassals, 3,
	)
	assert_eq(assignments.size(), 0)


func test_cascade_more_vassals_than_needed() -> void:
	var vassals: Array = [10, 20, 30, 40]
	var assignments: Array = MilitaryServiceSystem.cascade_request_to_vassals(
		1, vassals, 2,
	)
	# 2 / 4 = 0 each, remainder 2 → first two get 1
	var total: int = 0
	for a: Dictionary in assignments:
		total += a["count_requested"]
	assert_eq(total, 2)


# -- Commitment Protection Tests (delegates to LevySystem) -----------------------

func test_commitment_score_uncommitted() -> void:
	assert_eq(MilitaryServiceSystem.get_commitment_score("uncommitted"), 0)


func test_commitment_score_yojimbo_high() -> void:
	assert_eq(MilitaryServiceSystem.get_commitment_score("yojimbo_high_status"), -30)


func test_commitment_score_magistrate_insurgency() -> void:
	assert_eq(MilitaryServiceSystem.get_commitment_score("magistrate_insurgency"), -25)


func test_evaluate_candidate_jin_doubles_yojimbo() -> void:
	var score: int = MilitaryServiceSystem.evaluate_candidate("yojimbo_high_status", "Jin")
	assert_eq(score, -60)


func test_evaluate_candidate_yu_halves() -> void:
	var score: int = MilitaryServiceSystem.evaluate_candidate("magistrate_insurgency", "Yu")
	assert_eq(score, -12)


func test_evaluate_candidate_chugi_reduces() -> void:
	var score: int = MilitaryServiceSystem.evaluate_candidate("magistrate_stable", "Chugi")
	assert_eq(score, -5)


# -- Candidate Evaluation Tests --------------------------------------------------

func test_evaluate_candidates_uncommitted_first() -> void:
	var candidates: Array = [
		_make_retainer(1, "magistrate_stable"),
		_make_retainer(2, "uncommitted"),
		_make_retainer(3, "yoriki_idle"),
	]
	var ranked: Array = MilitaryServiceSystem.evaluate_candidates(
		candidates, "",
	)
	assert_eq(ranked[0]["character_id"], 2)
	assert_eq(ranked[0]["commitment_score"], 0)


func test_evaluate_candidates_yu_personality() -> void:
	var candidates: Array = [
		_make_retainer(1, "magistrate_insurgency"),
		_make_retainer(2, "uncommitted"),
	]
	var ranked: Array = MilitaryServiceSystem.evaluate_candidates(
		candidates, "Yu",
	)
	assert_eq(ranked[0]["character_id"], 2)
	assert_eq(ranked[1]["commitment_score"], -12)


# -- Assignment Execution Tests --------------------------------------------------

func test_assign_to_military_service() -> void:
	var char_data: Dictionary = _make_char_data(5, 100)
	var r: Dictionary = MilitaryServiceSystem.assign_to_military_service(
		char_data, 200, 10,
	)
	assert_true(r["success"])
	assert_eq(r["character_id"], 5)
	assert_eq(r["old_operational_superior_id"], 100)
	assert_eq(r["new_operational_superior_id"], 200)
	assert_eq(r["assigned_unit_id"], 10)
	assert_eq(r["lord_id_unchanged"], 100)
	# Verify mutations on character data
	assert_eq(char_data["operational_superior_id"], 200)
	assert_eq(char_data["assigned_company_id"], 10)
	# lord_id must NOT change
	assert_eq(char_data["lord_id"], 100)


func test_release_from_military_service() -> void:
	var char_data: Dictionary = _make_char_data(5, 100)
	char_data["operational_superior_id"] = 200
	char_data["assigned_company_id"] = 10
	var r: Dictionary = MilitaryServiceSystem.release_from_military_service(char_data)
	assert_true(r["released"])
	assert_eq(r["character_id"], 5)
	assert_eq(r["old_commander_id"], 200)
	assert_eq(r["old_unit_id"], 10)
	assert_eq(r["returned_to_lord_id"], 100)
	# Verify mutations
	assert_eq(char_data["operational_superior_id"], 100)
	assert_eq(char_data["assigned_company_id"], -1)


# -- Authority Validation Tests --------------------------------------------------

func test_provincial_daimyo_can_assign() -> void:
	assert_true(MilitaryServiceSystem.can_assign_military_service("provincial_daimyo"))


func test_city_daimyo_can_assign() -> void:
	assert_true(MilitaryServiceSystem.can_assign_military_service("city_daimyo"))


func test_family_daimyo_cannot_directly_assign() -> void:
	assert_false(MilitaryServiceSystem.can_assign_military_service("family_daimyo"))


func test_retainer_cannot_assign() -> void:
	assert_false(MilitaryServiceSystem.can_assign_military_service("retainer"))


func test_shireikan_can_request() -> void:
	assert_true(MilitaryServiceSystem.can_request_service(Enums.MilitaryRank.SHIREIKAN))


func test_rikugunshokan_can_request() -> void:
	assert_true(MilitaryServiceSystem.can_request_service(Enums.MilitaryRank.RIKUGUNSHOKAN))


func test_taisa_cannot_request() -> void:
	assert_false(MilitaryServiceSystem.can_request_service(Enums.MilitaryRank.TAISA))


func test_chui_cannot_request() -> void:
	assert_false(MilitaryServiceSystem.can_request_service(Enums.MilitaryRank.CHUI))


# -- Bulk Selection Tests --------------------------------------------------------

func test_select_exact_count() -> void:
	var retainers: Array = [
		_make_retainer(1, "uncommitted"),
		_make_retainer(2, "uncommitted"),
		_make_retainer(3, "uncommitted"),
	]
	var r: Dictionary = MilitaryServiceSystem.select_candidates_for_service(
		retainers, 2, "",
	)
	assert_eq(r["count_fulfilled"], 2)
	assert_eq(r["selected"].size(), 2)
	assert_eq(r["rejected"].size(), 1)
	assert_eq(r["shortfall"], 0)


func test_select_with_shortfall() -> void:
	var retainers: Array = [
		_make_retainer(1, "uncommitted"),
	]
	var r: Dictionary = MilitaryServiceSystem.select_candidates_for_service(
		retainers, 3, "",
	)
	assert_eq(r["count_fulfilled"], 1)
	assert_eq(r["shortfall"], 2)


func test_select_uncommitted_before_committed() -> void:
	var retainers: Array = [
		_make_retainer(1, "magistrate_stable"),
		_make_retainer(2, "uncommitted"),
		_make_retainer(3, "yoriki_idle"),
	]
	var r: Dictionary = MilitaryServiceSystem.select_candidates_for_service(
		retainers, 1, "",
	)
	assert_eq(r["selected"][0]["character_id"], 2)


func test_select_all_available() -> void:
	var retainers: Array = [
		_make_retainer(1, "uncommitted"),
		_make_retainer(2, "uncommitted"),
	]
	var r: Dictionary = MilitaryServiceSystem.select_candidates_for_service(
		retainers, 5, "",
	)
	assert_eq(r["count_fulfilled"], 2)
	assert_eq(r["shortfall"], 3)


func test_select_empty_retainers() -> void:
	var retainers: Array = []
	var r: Dictionary = MilitaryServiceSystem.select_candidates_for_service(
		retainers, 2, "",
	)
	assert_eq(r["count_fulfilled"], 0)
	assert_eq(r["shortfall"], 2)


func test_select_personality_affects_order() -> void:
	var retainers: Array = [
		_make_retainer(1, "magistrate_insurgency"),
		_make_retainer(2, "yoriki_idle"),
		_make_retainer(3, "uncommitted"),
	]
	# Yu halves all penalties: magistrate -12, yoriki -2, uncommitted 0
	var r: Dictionary = MilitaryServiceSystem.select_candidates_for_service(
		retainers, 2, "Yu",
	)
	assert_eq(r["selected"][0]["character_id"], 3)
	assert_eq(r["selected"][1]["character_id"], 2)


# -- Apply Assignments Tests -----------------------------------------------------

func test_apply_service_assignments() -> void:
	var selected: Array = [
		{"character_id": 5, "role": "uncommitted", "commitment_score": 0},
		{"character_id": 6, "role": "uncommitted", "commitment_score": 0},
	]
	var chars_by_id: Dictionary = {
		5: _make_char_data(5, 100),
		6: _make_char_data(6, 100),
	}
	var results: Array = MilitaryServiceSystem.apply_service_assignments(
		selected, chars_by_id, 200, 10,
	)
	assert_eq(results.size(), 2)
	assert_true(results[0]["success"])
	assert_eq(results[0]["new_operational_superior_id"], 200)
	# Verify character mutation
	assert_eq(chars_by_id[5]["operational_superior_id"], 200)
	assert_eq(chars_by_id[6]["assigned_company_id"], 10)


func test_apply_assignments_skips_missing_chars() -> void:
	var selected: Array = [
		{"character_id": 5, "role": "uncommitted", "commitment_score": 0},
		{"character_id": 99, "role": "uncommitted", "commitment_score": 0},
	]
	var chars_by_id: Dictionary = {
		5: _make_char_data(5, 100),
	}
	var results: Array = MilitaryServiceSystem.apply_service_assignments(
		selected, chars_by_id, 200, 10,
	)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["character_id"], 5)


func test_apply_assignments_preserves_lord_id() -> void:
	var selected: Array = [
		{"character_id": 5, "role": "uncommitted", "commitment_score": 0},
	]
	var chars_by_id: Dictionary = {
		5: _make_char_data(5, 100),
	}
	MilitaryServiceSystem.apply_service_assignments(
		selected, chars_by_id, 200, 10,
	)
	assert_eq(chars_by_id[5]["lord_id"], 100)
	assert_eq(chars_by_id[5]["operational_superior_id"], 200)
