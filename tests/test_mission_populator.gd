class_name TestMissionPopulator
extends GutTest
## Tests for MissionPopulator (s56.10) — spatial distribution of roster groups
## across population_slots produced by map template generators.

# -- Helpers -------------------------------------------------------------------

func _make_cave_map() -> CaveMapData:
	var m := CaveMapData.new()
	m.seed_string = "test_cave_pop"
	m.width  = 40
	m.height = 30
	m.population_slots = [
		{"x": 5,  "y": 5,  "role": 4, "room_id": 0},  # LEADER       → TIER_LEADER
		{"x": 10, "y": 10, "role": 3, "room_id": 0},  # GUARD_POST   → TIER_GUARD
		{"x": 15, "y": 15, "role": 3, "room_id": 1},  # GUARD_POST   → TIER_GUARD
		{"x": 20, "y": 8,  "role": 1, "room_id": 1},  # PATROL_WAYPOINT → TIER_PATROL
		{"x": 25, "y": 12, "role": 1, "room_id": 2},  # PATROL_WAYPOINT → TIER_PATROL
		{"x": 30, "y": 20, "role": 0, "room_id": 2},  # SENTRY       → TIER_PATROL
		{"x": 8,  "y": 22, "role": 2, "room_id": 3},  # CAMP_GROUP   → TIER_BULK
		{"x": 12, "y": 25, "role": 2, "room_id": 3},  # CAMP_GROUP   → TIER_BULK
		{"x": 18, "y": 18, "role": 2, "room_id": 4},  # CAMP_GROUP   → TIER_BULK
	]
	return m


func _make_village_map() -> OccupiedVillageMapData:
	var m := OccupiedVillageMapData.new()
	m.seed_string = "test_village_pop"
	m.width  = 40
	m.height = 36
	m.population_slots = [
		{"x": 5,  "y": 5,  "role": 3},  # LEADER     → TIER_LEADER
		{"x": 10, "y": 10, "role": 0},  # SENTRY     → TIER_PATROL
		{"x": 15, "y": 15, "role": 1},  # PATROL     → TIER_PATROL
		{"x": 8,  "y": 20, "role": 2},  # CAMP_GROUP → TIER_BULK
		{"x": 12, "y": 25, "role": 2},  # CAMP_GROUP → TIER_BULK
	]
	return m


## Sortie map: slots straddling the x = width/2 midpoint (width=40, midpoint=20).
func _make_sortie_map() -> CaveMapData:
	var m := CaveMapData.new()
	m.seed_string = "test_sortie_pop"
	m.width  = 40
	m.height = 30
	m.population_slots = [
		{"x": 5,  "y": 5,  "role": 4},  # friendly — LEADER
		{"x": 8,  "y": 15, "role": 1},  # friendly — PATROL
		{"x": 12, "y": 20, "role": 2},  # friendly — BULK
		{"x": 20, "y": 10, "role": 2},  # friendly — at exact midpoint (≤)
		{"x": 25, "y": 5,  "role": 4},  # enemy    — LEADER
		{"x": 30, "y": 15, "role": 1},  # enemy    — PATROL
		{"x": 35, "y": 20, "role": 2},  # enemy    — BULK
	]
	return m


func _roster(groups: Array, variance_chance: float = -1.0) -> Dictionary:
	var d := {"groups": groups}
	if variance_chance >= 0.0:
		d["individual_variance_chance"] = variance_chance
	return d


func _sortie_roster(
		friendly: Array, enemy: Array,
		variance_chance: float = -1.0) -> Dictionary:
	var d := {"friendly_groups": friendly, "enemy_groups": enemy}
	if variance_chance >= 0.0:
		d["individual_variance_chance"] = variance_chance
	return d


func _grp(role: String, unit_type: String, count: int) -> Dictionary:
	return {"role": role, "unit_type": unit_type, "count": count}


# -- populate: basic contract --------------------------------------------------

func test_populate_returns_array():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_not_null(result)
	assert_true(result is Array)


func test_populate_count_equals_sum_of_group_counts():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER,     "boss",  1),
		_grp(RosterCompositionSystem.ROLE_GUARD_POST, "guard", 2),
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 3),
	]), 1)
	assert_eq(result.size(), 6)


func test_populate_placement_dict_has_required_keys():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_eq(result.size(), 1)
	var p: Dictionary = result[0]
	assert_true(p.has("unit_type"),       "missing unit_type")
	assert_true(p.has("x"),               "missing x")
	assert_true(p.has("y"),               "missing y")
	assert_true(p.has("map_role_int"),    "missing map_role_int")
	assert_true(p.has("roster_role_str"), "missing roster_role_str")
	assert_true(p.has("variance"),        "missing variance")


func test_populate_unit_type_propagated():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "my_unique_boss", 1),
	]), 1)
	assert_eq(result[0]["unit_type"], "my_unique_boss")


func test_populate_roster_role_str_propagated():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_eq(result[0]["roster_role_str"], RosterCompositionSystem.ROLE_LEADER)


func test_populate_x_y_come_from_slot_position():
	var m        := CaveMapData.new()
	m.seed_string = "coord_test"
	m.width       = 50
	m.height      = 50
	# Single known slot at a precise coordinate.
	m.population_slots = [{"x": 17, "y": 23, "role": 4}]
	var result = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["x"], 17)
	assert_eq(result[0]["y"], 23)


# -- populate: empty and edge cases -------------------------------------------

func test_populate_empty_groups_returns_empty():
	var result = MissionPopulator.populate(_make_cave_map(), _roster([]), 1)
	assert_eq(result.size(), 0)


func test_populate_empty_slots_returns_empty():
	var m        := CaveMapData.new()
	m.seed_string = "empty_slots"
	m.width       = 10
	m.height      = 10
	m.population_slots = []
	var result = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_eq(result.size(), 0)


func test_populate_zero_count_groups_skipped():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER,     "boss",  0),
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 2),
	]), 1)
	assert_eq(result.size(), 2)
	for p in result:
		assert_eq(p["roster_role_str"], RosterCompositionSystem.ROLE_CAMP_GROUP)


func test_populate_empty_unit_type_skipped():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		{"role": RosterCompositionSystem.ROLE_LEADER, "unit_type": "", "count": 1},
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 1),
	]), 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["roster_role_str"], RosterCompositionSystem.ROLE_CAMP_GROUP)


# -- populate: tier placement priority ----------------------------------------

func test_leader_placed_in_leader_slot_cave():
	# Cave: role 4 = LEADER → TIER_LEADER
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["map_role_int"], 4)


func test_guard_group_prefers_guard_slot_over_patrol_cave():
	# Cave guard slots: role 3 (GUARD_POST)
	# Cave patrol slots: role 1 (PATROL_WAYPOINT), 0 (SENTRY)
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_GUARD_POST, "guard", 1),
	]), 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["map_role_int"], 3)


func test_camp_group_placed_in_bulk_slot_cave():
	# Cave bulk slots: role 2 (CAMP_GROUP)
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 1),
	]), 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["map_role_int"], 2)


func test_leader_placed_in_role_3_slot_occupied_village():
	# OccupiedVillage: role 3 = LEADER → TIER_LEADER
	var m      := _make_village_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER, "boss", 1),
	]), 1)
	assert_eq(result.size(), 1)
	assert_eq(result[0]["map_role_int"], 3)


func test_leader_processed_before_bulk_regardless_of_input_order():
	# Groups submitted bulk-first; leader should still land in TIER_LEADER slot.
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 5),
		_grp(RosterCompositionSystem.ROLE_LEADER,     "boss",  1),
	]), 1)
	var leader_placements: Array = result.filter(
		func(p): return p["roster_role_str"] == RosterCompositionSystem.ROLE_LEADER
	)
	assert_eq(leader_placements.size(), 1)
	assert_eq(leader_placements[0]["map_role_int"], 4)


# -- populate: coordinate validity -------------------------------------------

func test_placement_coordinates_within_map_bounds():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER,     "boss",  1),
		_grp(RosterCompositionSystem.ROLE_GUARD_POST, "guard", 2),
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 4),
	]), 1)
	for p in result:
		assert_true(p["x"] >= 0 and p["x"] < m.width,
			"x=%d out of bounds [0,%d)" % [p["x"], m.width])
		assert_true(p["y"] >= 0 and p["y"] < m.height,
			"y=%d out of bounds [0,%d)" % [p["y"], m.height])


func test_multiple_units_share_slot_when_count_exceeds_available():
	# 2 bulk slots, 5 bulk units → round-robin causes sharing.
	var m        := CaveMapData.new()
	m.seed_string = "share_test"
	m.width       = 20
	m.height      = 20
	m.population_slots = [
		{"x": 5, "y": 5,  "role": 2},
		{"x": 8, "y": 10, "role": 2},
	]
	var result = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 5),
	]), 1)
	assert_eq(result.size(), 5)
	var seen: Dictionary = {}
	var shared := false
	for p in result:
		var key := "%d_%d" % [p["x"], p["y"]]
		if seen.has(key):
			shared = true
		seen[key] = true
	assert_true(shared, "expected coordinate sharing when count > slot count")


# -- populate: unknown template class fallback --------------------------------

func test_unknown_template_class_falls_back_to_tier_bulk():
	# AsciiMapData has no entry in _TEMPLATE_TIERS → all slots are TIER_BULK.
	var m        := AsciiMapData.new()
	m.seed_string = "base_class_test"
	m.width       = 20
	m.height      = 20
	m.population_slots = [
		{"x": 5,  "y": 5,  "role": 99},
		{"x": 10, "y": 10, "role": 88},
	]
	var result = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 2),
	]), 1)
	assert_eq(result.size(), 2)


# -- populate: determinism ----------------------------------------------------

func test_same_inputs_produce_identical_placements():
	var m := _make_cave_map()
	var r := _roster([
		_grp(RosterCompositionSystem.ROLE_LEADER,     "boss",  1),
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 3),
	])
	var r1 = MissionPopulator.populate(m, r, 42)
	var r2 = MissionPopulator.populate(m, r, 42)
	assert_eq(r1.size(), r2.size())
	for i in range(r1.size()):
		assert_eq(r1[i]["x"],        r2[i]["x"])
		assert_eq(r1[i]["y"],        r2[i]["y"])
		assert_eq(r1[i]["variance"], r2[i]["variance"])


func test_different_seeds_both_produce_valid_output():
	var m := _make_cave_map()
	var r := _roster([_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 10)])
	var r1 = MissionPopulator.populate(m, r, 1)
	var r2 = MissionPopulator.populate(m, r, 9999)
	assert_eq(r1.size(), 10)
	assert_eq(r2.size(), 10)


# -- populate: individual variance (s56.10.0a) --------------------------------

func test_variance_field_is_dictionary():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 5),
	]), 1)
	for p in result:
		assert_true(p["variance"] is Dictionary)


func test_variance_entry_has_stat_and_bonus():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 30),
	]), 1)
	for p in result:
		var v: Dictionary = p["variance"]
		if not v.is_empty():
			assert_true(v.has("stat"),  "non-empty variance must have 'stat'")
			assert_true(v.has("bonus"), "non-empty variance must have 'bonus'")
			assert_eq(v["bonus"], 1)


func test_variance_stat_is_valid_l5r_4e_trait():
	const VALID_TRAITS := [
		"Agility", "Awareness", "Intelligence", "Perception",
		"Reflexes", "Stamina", "Strength", "Willpower",
	]
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m, _roster([
		_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 50),
	]), 1)
	for p in result:
		var v: Dictionary = p["variance"]
		if not v.is_empty():
			assert_true(VALID_TRAITS.has(v["stat"]),
				"'%s' is not a valid L5R 4e trait" % v["stat"])


func test_variance_rate_within_expected_range():
	# s56.10.0a: 30–40% chance. Test over 200 units with loose band to avoid flakiness.
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m,
		_roster([_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 200)],
			RosterCompositionSystem.INDIVIDUAL_VARIANCE_CHANCE_MIN),
		1)
	assert_eq(result.size(), 200)
	var count := 0
	for p in result:
		if not (p["variance"] as Dictionary).is_empty():
			count += 1
	var rate: float = float(count) / 200.0
	assert_true(rate >= 0.20 and rate <= 0.55,
		"variance rate %.2f out of expected range [0.20, 0.55]" % rate)


func test_variance_chance_zero_produces_no_variance():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m,
		_roster([_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 20)], 0.0),
		1)
	for p in result:
		assert_true((p["variance"] as Dictionary).is_empty(),
			"expected empty variance with chance=0.0")


func test_variance_chance_one_produces_all_variance():
	var m      := _make_cave_map()
	var result  = MissionPopulator.populate(m,
		_roster([_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "ronin", 20)], 1.0),
		1)
	for p in result:
		assert_false((p["variance"] as Dictionary).is_empty(),
			"expected non-empty variance with chance=1.0")


# -- populate_sortie: basic contract ------------------------------------------

func test_populate_sortie_returns_dict_with_friendly_and_enemy_keys():
	var result = MissionPopulator.populate_sortie(_make_sortie_map(),
		_sortie_roster(
			[_grp(RosterCompositionSystem.ROLE_LEADER, "samurai",    1)],
			[_grp(RosterCompositionSystem.ROLE_LEADER, "enemy_boss", 1)]
		), 1)
	assert_true(result is Dictionary)
	assert_true(result.has("friendly"), "missing 'friendly' key")
	assert_true(result.has("enemy"),    "missing 'enemy' key")
	assert_true(result["friendly"] is Array)
	assert_true(result["enemy"]    is Array)


func test_populate_sortie_friendly_units_on_entry_side():
	# Midpoint = 40/2 = 20; friendly slots at x ≤ 20.
	var m      := _make_sortie_map()
	var result  = MissionPopulator.populate_sortie(m,
		_sortie_roster(
			[_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "samurai", 3)], []
		), 1)
	for p in result["friendly"]:
		assert_true(p["x"] <= m.width / 2,
			"friendly unit x=%d > midpoint %d" % [p["x"], m.width / 2])


func test_populate_sortie_enemy_units_on_far_side():
	# Enemy slots at x > 20.
	var m      := _make_sortie_map()
	var result  = MissionPopulator.populate_sortie(m,
		_sortie_roster(
			[], [_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "enemy", 2)]
		), 1)
	for p in result["enemy"]:
		assert_true(p["x"] > m.width / 2,
			"enemy unit x=%d ≤ midpoint %d" % [p["x"], m.width / 2])


func test_populate_sortie_placements_carry_side_key():
	var result = MissionPopulator.populate_sortie(_make_sortie_map(),
		_sortie_roster(
			[_grp(RosterCompositionSystem.ROLE_LEADER, "samurai",    1)],
			[_grp(RosterCompositionSystem.ROLE_LEADER, "enemy_boss", 1)]
		), 1)
	for p in result["friendly"]:
		assert_eq(p.get("side", ""), "friendly")
	for p in result["enemy"]:
		assert_eq(p.get("side", ""), "enemy")


func test_populate_sortie_empty_groups_returns_empty_arrays():
	var result = MissionPopulator.populate_sortie(_make_sortie_map(),
		_sortie_roster([], []), 1)
	assert_eq(result["friendly"].size(), 0)
	assert_eq(result["enemy"].size(),    0)


func test_populate_sortie_deterministic():
	var m := _make_sortie_map()
	var r := _sortie_roster(
		[_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "samurai", 2)],
		[_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "enemy",   2)]
	)
	var r1 = MissionPopulator.populate_sortie(m, r, 7)
	var r2 = MissionPopulator.populate_sortie(m, r, 7)
	assert_eq(r1["friendly"].size(), r2["friendly"].size())
	assert_eq(r1["enemy"].size(),    r2["enemy"].size())
	for i in range(r1["friendly"].size()):
		assert_eq(r1["friendly"][i]["x"], r2["friendly"][i]["x"])
		assert_eq(r1["friendly"][i]["y"], r2["friendly"][i]["y"])


# -- populate: all eight template types produce valid output ------------------

func test_all_eight_templates_produce_valid_output():
	var templates: Array = [
		CaveMapData.new(),
		OccupiedVillageMapData.new(),
		ForestApproachCampMapData.new(),
		MakeshiftStockadeMapData.new(),
		HilltopPositionMapData.new(),
		RavineCampMapData.new(),
		RuinedStructureMapData.new(),
		UrbanHideoutMapData.new(),
	]
	for tmpl in templates:
		tmpl.seed_string       = "multi_template_test"
		tmpl.width             = 20
		tmpl.height            = 20
		tmpl.population_slots  = [{"x": 5, "y": 5, "role": 0}]
		var result = MissionPopulator.populate(tmpl, _roster([
			_grp(RosterCompositionSystem.ROLE_CAMP_GROUP, "unit", 1),
		]), 1)
		assert_eq(result.size(), 1,
			"%s should produce 1 placement" % tmpl.get_class())
