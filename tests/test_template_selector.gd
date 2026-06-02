extends GutTest
## Tests for TemplateSelector (s56.2 --- LOCKED).

# -- province_has_ruin ---------------------------------------------------------

func test_war_damage_is_ruin() -> void:
	assert_true(TemplateSelector.province_has_ruin(["war_damage"]))

func test_famine_is_ruin() -> void:
	assert_true(TemplateSelector.province_has_ruin(["famine"]))

func test_taint_corruption_is_ruin() -> void:
	assert_true(TemplateSelector.province_has_ruin(["taint_corruption"]))

func test_peasant_revolt_is_ruin() -> void:
	assert_true(TemplateSelector.province_has_ruin(["peasant_revolt"]))

func test_natural_decay_is_ruin() -> void:
	assert_true(TemplateSelector.province_has_ruin(["natural_decay"]))

func test_prosperity_is_not_ruin() -> void:
	assert_false(TemplateSelector.province_has_ruin(["prosperity", "trade_boom"]))

func test_empty_history_is_not_ruin() -> void:
	assert_false(TemplateSelector.province_has_ruin([]))

func test_ruin_tag_among_others() -> void:
	assert_true(TemplateSelector.province_has_ruin(["prosperity", "war_damage", "growth"]))

# -- select_template: plains with ruin ----------------------------------------

func test_plains_with_ruin_can_produce_ruined_structure() -> void:
	# Drive with many seeds until RuinedStructure appears.
	var found := false
	for i in range(200):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.PLAINS, ["war_damage"], "seed_%d" % i)
		if t == TemplateSelector.RUINED_STRUCTURE:
			found = true
			break
	assert_true(found, "RuinedStructure never selected on plains with ruin condition")

func test_plains_without_ruin_never_produces_ruined_structure() -> void:
	for i in range(500):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.PLAINS, ["prosperity"], "no_ruin_%d" % i)
		assert_true(t != TemplateSelector.RUINED_STRUCTURE,
			"RuinedStructure selected without ruin condition (seed %d)" % i)

# -- select_template: plains pool templates -----------------------------------

func test_plains_can_produce_occupied_village() -> void:
	var found := false
	for i in range(200):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.PLAINS, [], "pv_%d" % i)
		if t == TemplateSelector.OCCUPIED_VILLAGE:
			found = true
			break
	assert_true(found)

func test_plains_can_produce_makeshift_stockade() -> void:
	var found := false
	for i in range(200):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.PLAINS, [], "ps_%d" % i)
		if t == TemplateSelector.MAKESHIFT_STOCKADE:
			found = true
			break
	assert_true(found)

func test_plains_can_produce_ravine_camp() -> void:
	var found := false
	for i in range(500):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.PLAINS, [], "pr_%d" % i)
		if t == TemplateSelector.RAVINE_CAMP:
			found = true
			break
	assert_true(found)

# -- select_template: mountains pool ------------------------------------------

func test_mountains_can_produce_cave() -> void:
	var found := false
	for i in range(100):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.MOUNTAINS, [], "mc_%d" % i)
		if t == TemplateSelector.CAVE:
			found = true
			break
	assert_true(found)

func test_mountains_never_produce_makeshift_stockade() -> void:
	for i in range(500):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.MOUNTAINS, [], "mno_%d" % i)
		assert_true(t != TemplateSelector.MAKESHIFT_STOCKADE)

# -- select_template: forest pool ---------------------------------------------

func test_forest_can_produce_forest_approach_camp() -> void:
	var found := false
	for i in range(100):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.FOREST, [], "fc_%d" % i)
		if t == TemplateSelector.FOREST_APPROACH_CAMP:
			found = true
			break
	assert_true(found)

# -- Terrain aliasing ---------------------------------------------------------

func test_swamp_uses_forest_pool_templates() -> void:
	# Swamp must not produce Stockade or Ravine (not in forest pool).
	for i in range(300):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.SWAMP, [], "sw_%d" % i)
		assert_true(t != TemplateSelector.MAKESHIFT_STOCKADE)

func test_wasteland_uses_plains_pool() -> void:
	var found := false
	for i in range(200):
		var t := TemplateSelector.select_template(
			Enums.TerrainType.WASTELAND, [], "wl_%d" % i)
		if t == TemplateSelector.MAKESHIFT_STOCKADE:
			found = true
			break
	assert_true(found, "Wasteland should use plains pool (includes Stockade)")

# -- Determinism --------------------------------------------------------------

func test_same_seed_same_result() -> void:
	var t1 := TemplateSelector.select_template(
		Enums.TerrainType.PLAINS, [], "det_seed")
	var t2 := TemplateSelector.select_template(
		Enums.TerrainType.PLAINS, [], "det_seed")
	assert_eq(t1, t2)

func test_different_seeds_can_differ() -> void:
	var results: Array = []
	for i in range(20):
		results.append(TemplateSelector.select_template(
			Enums.TerrainType.PLAINS, ["war_damage"], "vary_%d" % i))
	# Plains with ruin has 4 possible templates; at least 2 should appear.
	var unique := {}
	for r in results:
		unique[r] = true
	assert_true(unique.size() >= 2, "Expected variety across seeds")
