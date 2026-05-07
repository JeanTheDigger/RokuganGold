extends GutTest


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)


# =============================================================================
# Character Generation — Identity
# =============================================================================

func test_generate_character_sets_identity() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Hida Kenji", "Crab", "Hida", "Hida Bushi", 1, _dice, "male"
	)
	assert_eq(c.character_id, 1)
	assert_eq(c.character_name, "Hida Kenji")
	assert_eq(c.clan, "Crab")
	assert_eq(c.family, "Hida")
	assert_eq(c.school, "Hida Bushi")
	assert_eq(c.gender, "male")
	assert_eq(c.school_type, Enums.SchoolType.BUSHI)


func test_generate_character_unknown_school_returns_defaults() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		99, "Ronin", "Ronin", "None", "Unknown School", 1, _dice
	)
	assert_eq(c.character_id, 99)
	assert_eq(c.stamina, 2)
	assert_eq(c.awareness, 2)


# =============================================================================
# Character Generation — Trait Bonuses
# =============================================================================

func test_family_trait_bonus_applied() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Hida Kenji", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	# Hida family: +1 Stamina, Hida Bushi school: +1 Stamina → base 2 + 2 = 4
	assert_eq(c.stamina, 4)


func test_different_family_and_school_bonus() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		2, "Doji Satsume", "Crane", "Doji", "Kakita Bushi", 1, _dice
	)
	# Doji family: +1 Awareness (→ 3), Kakita Bushi: +1 Reflexes (→ 3)
	assert_eq(c.awareness, 3)
	assert_eq(c.reflexes, 3)


func test_stacking_bonuses() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		3, "Kakita Toshimoko", "Crane", "Kakita", "Kakita Bushi", 1, _dice
	)
	# Kakita family: +1 Reflexes, Kakita Bushi: +1 Reflexes → 2 + 2 = 4
	assert_eq(c.reflexes, 4)


# =============================================================================
# Character Generation — Trait Advancement
# =============================================================================

func test_rank1_has_base_traits() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Rank1", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	var total: int = (c.stamina + c.willpower + c.strength + c.perception
		+ c.agility + c.intelligence + c.reflexes + c.awareness)
	# Base 16 + 2 bonuses = 18
	assert_eq(total, 18)


func test_higher_rank_has_higher_traits() -> void:
	_dice.set_seed(42)
	var c1: L5RCharacterData = WorldGenerator.generate_character(
		1, "Rank1", "Lion", "Akodo", "Akodo Bushi", 1, _dice
	)
	_dice.set_seed(42)
	var c3: L5RCharacterData = WorldGenerator.generate_character(
		2, "Rank3", "Lion", "Akodo", "Akodo Bushi", 3, _dice
	)
	var total1: int = (c1.stamina + c1.willpower + c1.strength + c1.perception
		+ c1.agility + c1.intelligence + c1.reflexes + c1.awareness)
	var total3: int = (c3.stamina + c3.willpower + c3.strength + c3.perception
		+ c3.agility + c3.intelligence + c3.reflexes + c3.awareness)
	assert_true(total3 > total1, "Rank 3 should have more trait points than Rank 1")


func test_traits_capped_at_5() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Elite", "Crab", "Hida", "Hida Bushi", 5, _dice
	)
	assert_true(c.stamina <= 5)
	assert_true(c.willpower <= 5)
	assert_true(c.agility <= 5)
	assert_true(c.intelligence <= 5)
	assert_true(c.reflexes <= 5)
	assert_true(c.awareness <= 5)
	assert_true(c.strength <= 5)
	assert_true(c.perception <= 5)


func test_void_advances_faster_for_shugenja() -> void:
	_dice.set_seed(42)
	var shugenja: L5RCharacterData = WorldGenerator.generate_character(
		1, "Shugenja", "Crab", "Kuni", "Kuni Shugenja", 3, _dice
	)
	_dice.set_seed(42)
	var bushi: L5RCharacterData = WorldGenerator.generate_character(
		2, "Bushi", "Crab", "Hida", "Hida Bushi", 3, _dice
	)
	# Shugenja rank 3: void = 2 + 2 = 4. Bushi rank 3: void = 2 + 1 = 3
	assert_eq(shugenja.void_ring, 4)
	assert_eq(bushi.void_ring, 3)


func test_void_points_match_ring() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Dragon", "Tamori", "Tamori Shugenja", 2, _dice
	)
	assert_eq(c.void_points_max, c.void_ring)
	assert_eq(c.void_points_current, c.void_ring)


# =============================================================================
# Character Generation — Skills
# =============================================================================

func test_rank1_has_school_skills() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	assert_true(c.skills.has("Athletics"))
	assert_true(c.skills.has("Defense"))
	assert_true(c.skills.has("Heavy Weapons"))
	assert_true(c.skills.has("Kenjutsu"))
	assert_true(c.skills.has("Lore: Shadowlands"))


func test_wildcard_adds_extra_skill() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	# Hida Bushi has 6 named skills + 1 Bugei wildcard = 7 minimum
	assert_true(c.skills.size() >= 7)


func test_higher_rank_has_more_skills() -> void:
	_dice.set_seed(42)
	var c1: L5RCharacterData = WorldGenerator.generate_character(
		1, "R1", "Crane", "Doji", "Doji Courtier", 1, _dice
	)
	_dice.set_seed(42)
	var c4: L5RCharacterData = WorldGenerator.generate_character(
		2, "R4", "Crane", "Doji", "Doji Courtier", 4, _dice
	)
	assert_true(c4.skills.size() > c1.skills.size())


func test_higher_rank_advances_school_skills() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Veteran", "Lion", "Akodo", "Akodo Bushi", 4, _dice
	)
	var max_school_skill: int = 0
	for skill: String in ["Battle", "Defense", "Kenjutsu", "Kyujutsu", "Lore: History", "Sincerity"]:
		max_school_skill = maxi(max_school_skill, c.skills.get(skill, 0))
	assert_true(max_school_skill >= 3, "Rank 4 should have at least one school skill at 3+")


func test_skill_rank_2_starting() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Dragon", "Mirumoto", "Mirumoto Bushi", 1, _dice
	)
	# Mirumoto Bushi has Kenjutsu at rank 2
	assert_eq(c.skills.get("Kenjutsu", 0), 2)


# =============================================================================
# Character Generation — Honor, Glory, Status
# =============================================================================

func test_honor_from_school() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crane", "Kakita", "Kakita Bushi", 1, _dice
	)
	# Kakita Bushi: 6.5 base ± 0.5 variance
	assert_almost_eq(c.honor, 6.5, 0.6)


func test_honor_increases_with_rank() -> void:
	_dice.set_seed(42)
	var c1: L5RCharacterData = WorldGenerator.generate_character(
		1, "R1", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	_dice.set_seed(42)
	var c3: L5RCharacterData = WorldGenerator.generate_character(
		2, "R3", "Crab", "Hida", "Hida Bushi", 3, _dice
	)
	assert_true(c3.honor > c1.honor - 0.5, "Higher rank should generally have higher honor")


func test_glory_scales_with_rank() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Lion", "Akodo", "Akodo Bushi", 3, _dice
	)
	# Glory = 1.0 + (3-1) * 0.5 = 2.0
	assert_almost_eq(c.glory, 2.0, 0.001)


func test_glory_rank1() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Lion", "Akodo", "Akodo Bushi", 1, _dice
	)
	assert_almost_eq(c.glory, 1.0, 0.001)


func test_status_default() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	assert_almost_eq(c.status, 1.0, 0.001)


# =============================================================================
# Character Generation — Personality
# =============================================================================

func test_personality_assigned() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Lion", "Akodo", "Akodo Bushi", 1, _dice
	)
	assert_ne(c.bushido_virtue, Enums.BushidoVirtue.NONE)
	assert_ne(c.shourido_virtue, Enums.ShouridoVirtue.NONE)


func test_personality_valid_range() -> void:
	for _i: int in range(20):
		var c: L5RCharacterData = WorldGenerator.generate_character(
			_i, "Test", "Scorpion", "Bayushi", "Bayushi Bushi", 1, _dice
		)
		assert_true(c.bushido_virtue >= 0 and c.bushido_virtue <= 6)
		assert_true(c.shourido_virtue >= 0 and c.shourido_virtue <= 6)


func test_clan_personality_weights_affect_distribution() -> void:
	var yu_count: int = 0
	for i: int in range(100):
		_dice.set_seed(i)
		var c: L5RCharacterData = WorldGenerator.generate_character(
			i, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
		)
		if c.bushido_virtue == Enums.BushidoVirtue.YU:
			yu_count += 1
	# Crab has Yu at weight 30/95 ≈ 31.6% — should appear ~25-40 times
	assert_true(yu_count >= 15, "Crab should favor Yu (Courage): got %d/100" % yu_count)


# =============================================================================
# Character Generation — Age & Koku
# =============================================================================

func test_age_rank1_in_range() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Young", "Crane", "Kakita", "Kakita Bushi", 1, _dice
	)
	assert_true(c.age >= 15 and c.age <= 20)


func test_age_rank5_in_range() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Elder", "Crane", "Kakita", "Kakita Bushi", 5, _dice
	)
	assert_true(c.age >= 38 and c.age <= 55)


func test_koku_positive() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	assert_true(c.koku > 0.0)


# =============================================================================
# Character Generation — Shugenja Fields
# =============================================================================

func test_shugenja_affinity_set() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Kuni", "Kuni Shugenja", 1, _dice
	)
	assert_eq(c.affinity_element, Enums.Ring.EARTH)
	assert_eq(c.deficiency_element, Enums.Ring.AIR)


func test_bushi_no_affinity() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	assert_eq(c.affinity_element, Enums.Ring.NONE)


# =============================================================================
# Character Generation — AP
# =============================================================================

func test_ap_initialized() -> void:
	var c: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Crab", "Hida", "Hida Bushi", 1, _dice
	)
	assert_eq(c.action_points_current, 2)
	assert_eq(c.action_points_max, 2)


# =============================================================================
# Province Generation — Basic Fields
# =============================================================================

func test_generate_province_sets_identity() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		10, "Hida Province", "Crab", "Hida",
		Enums.TerrainType.MOUNTAINS, 20, _dice
	)
	assert_eq(p.province_id, 10)
	assert_eq(p.province_name, "Hida Province")
	assert_eq(p.clan, "Crab")
	assert_eq(p.family, "Hida")
	assert_eq(p.terrain_type, Enums.TerrainType.MOUNTAINS)


func test_generate_province_coastal() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		11, "Coastal", "Crane", "Daidoji",
		Enums.TerrainType.PLAINS, 15, _dice, true
	)
	assert_true(p.is_coastal)


# =============================================================================
# Province Generation — PU Distribution
# =============================================================================

func test_pu_distribution_sums_to_total() -> void:
	for terrain: int in [0, 1, 2, 3, 4]:
		var p: ProvinceData = WorldGenerator.generate_province(
			terrain, "Test", "Lion", "Akodo",
			terrain as Enums.TerrainType, 20, _dice
		)
		var total: int = p.farming_pu + p.town_pu + p.mining_pu + p.military_pu
		assert_eq(total, 20, "PU should sum to total for terrain %d" % terrain)


func test_mountains_have_more_mining() -> void:
	var mountain: ProvinceData = WorldGenerator.generate_province(
		1, "Mountain", "Dragon", "Mirumoto",
		Enums.TerrainType.MOUNTAINS, 20, _dice
	)
	var plains: ProvinceData = WorldGenerator.generate_province(
		2, "Plains", "Lion", "Akodo",
		Enums.TerrainType.PLAINS, 20, _dice
	)
	assert_true(mountain.mining_pu > plains.mining_pu,
		"Mountains should have more mining PU than plains")


func test_river_delta_has_most_farming() -> void:
	var delta: ProvinceData = WorldGenerator.generate_province(
		1, "Delta", "Crane", "Doji",
		Enums.TerrainType.RIVER_DELTA, 20, _dice
	)
	assert_true(delta.farming_pu >= 12, "River delta should have high farming PU")


func test_river_delta_has_no_mining() -> void:
	var delta: ProvinceData = WorldGenerator.generate_province(
		1, "Delta", "Crane", "Doji",
		Enums.TerrainType.RIVER_DELTA, 20, _dice
	)
	assert_eq(delta.mining_pu, 0)


# =============================================================================
# Province Generation — Garrison
# =============================================================================

func test_garrison_is_five_percent() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		1, "Test", "Lion", "Akodo",
		Enums.TerrainType.PLAINS, 40, _dice
	)
	assert_eq(p.garrison_pu, 2)


func test_garrison_minimum_one() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		1, "Tiny", "Dragon", "Togashi",
		Enums.TerrainType.MOUNTAINS, 5, _dice
	)
	assert_eq(p.garrison_pu, 1)


# =============================================================================
# Province Generation — Stockpiles
# =============================================================================

func test_rice_stockpile_two_seasons() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		1, "Test", "Lion", "Akodo",
		Enums.TerrainType.PLAINS, 20, _dice
	)
	# 20 PU * 0.25 per season * 2 seasons = 10.0
	assert_almost_eq(p.rice_stockpile, 10.0, 0.001)


func test_koku_stockpile_from_town() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		1, "Test", "Crane", "Doji",
		Enums.TerrainType.PLAINS, 20, _dice
	)
	# town_pu * 0.5
	assert_almost_eq(p.koku_stockpile, float(p.town_pu) * 0.5, 0.001)


func test_iron_stockpile_from_mining() -> void:
	var p: ProvinceData = WorldGenerator.generate_province(
		1, "Test", "Crab", "Kaiu",
		Enums.TerrainType.MOUNTAINS, 20, _dice
	)
	assert_almost_eq(p.iron_stockpile, float(p.mining_pu) * 0.5, 0.001)


# =============================================================================
# Province Generation — Stability
# =============================================================================

func test_stability_in_range() -> void:
	for i: int in range(10):
		_dice.set_seed(i)
		var p: ProvinceData = WorldGenerator.generate_province(
			i, "Test", "Lion", "Akodo",
			Enums.TerrainType.PLAINS, 20, _dice
		)
		assert_true(p.stability >= 70.0 and p.stability <= 90.0,
			"Stability should be 70-90, got %f" % p.stability)


# =============================================================================
# Determinism
# =============================================================================

func test_same_seed_produces_same_character() -> void:
	_dice.set_seed(42)
	var c1: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Scorpion", "Bayushi", "Bayushi Bushi", 3, _dice
	)
	_dice.set_seed(42)
	var c2: L5RCharacterData = WorldGenerator.generate_character(
		1, "Test", "Scorpion", "Bayushi", "Bayushi Bushi", 3, _dice
	)
	assert_eq(c1.stamina, c2.stamina)
	assert_eq(c1.awareness, c2.awareness)
	assert_eq(c1.agility, c2.agility)
	assert_eq(c1.bushido_virtue, c2.bushido_virtue)
	assert_eq(c1.honor, c2.honor)
	assert_eq(c1.age, c2.age)


func test_same_seed_produces_same_province() -> void:
	_dice.set_seed(42)
	var p1: ProvinceData = WorldGenerator.generate_province(
		1, "Test", "Lion", "Akodo",
		Enums.TerrainType.PLAINS, 20, _dice
	)
	_dice.set_seed(42)
	var p2: ProvinceData = WorldGenerator.generate_province(
		1, "Test", "Lion", "Akodo",
		Enums.TerrainType.PLAINS, 20, _dice
	)
	assert_eq(p1.farming_pu, p2.farming_pu)
	assert_eq(p1.stability, p2.stability)
	assert_eq(p1.rice_stockpile, p2.rice_stockpile)


# =============================================================================
# All Schools — Smoke Test
# =============================================================================

func test_all_schools_generate_valid_characters() -> void:
	var schools: Array[String] = [
		"Hida Bushi", "Hiruma Bushi", "Kaiu Engineer", "Kuni Shugenja",
		"Yasuki Courtier", "Kakita Bushi", "Daidoji Iron Warrior",
		"Doji Courtier", "Asahina Shugenja", "Mirumoto Bushi",
		"Kitsuki Investigator", "Tamori Shugenja", "Akodo Bushi",
		"Matsu Berserker", "Ikoma Bard", "Kitsu Shugenja", "Shiba Bushi",
		"Isawa Shugenja", "Asako Loremaster", "Bayushi Bushi",
		"Bayushi Courtier", "Soshi Shugenja", "Shosuro Infiltrator",
		"Shinjo Bushi", "Moto Bushi", "Ide Emissary",
		"Iuchi Shugenja", "Utaku Battle Maiden",
	]
	for i: int in range(schools.size()):
		_dice.set_seed(i)
		var sd: Dictionary = WorldGenerator.SCHOOL_DATA[schools[i]]
		var c: L5RCharacterData = WorldGenerator.generate_character(
			i, "Test_%d" % i, sd["clan"], sd["family"], schools[i], 2, _dice
		)
		assert_true(c.skills.size() >= 6,
			"%s should have at least 6 skills, got %d" % [schools[i], c.skills.size()])
		assert_true(c.honor > 0.0,
			"%s should have positive honor" % schools[i])
		assert_ne(c.bushido_virtue, Enums.BushidoVirtue.NONE,
			"%s should have a bushido virtue" % schools[i])


# =============================================================================
# All Terrains — Smoke Test
# =============================================================================

func test_all_terrains_generate_valid_provinces() -> void:
	var terrains: Array = [
		Enums.TerrainType.PLAINS,
		Enums.TerrainType.RIVER_DELTA,
		Enums.TerrainType.FOREST,
		Enums.TerrainType.HILLS,
		Enums.TerrainType.MOUNTAINS,
	]
	for i: int in range(terrains.size()):
		_dice.set_seed(i)
		var p: ProvinceData = WorldGenerator.generate_province(
			i, "Test_%d" % i, "Lion", "Akodo",
			terrains[i], 20, _dice
		)
		var total: int = p.farming_pu + p.town_pu + p.mining_pu + p.military_pu
		assert_eq(total, 20, "Terrain %d PU should sum to 20" % terrains[i])
		assert_true(p.garrison_pu >= 1)
		assert_true(p.stability >= 70.0)
		assert_true(p.rice_stockpile > 0.0)
