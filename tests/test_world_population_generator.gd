extends GutTest

var dice: DiceEngine


func before_each() -> void:
	dice = DiceEngine.new()
	dice.set_seed(42)


# -- Helpers -------------------------------------------------------------------

func _make_province(id: int, clan: String, family: String) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.clan = clan
	p.family = family
	p.province_name = clan + " Province " + str(id)
	return p


func _make_settlement(
	id: int,
	province_id: int,
	type: Enums.SettlementType,
	garrison: int = 0,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.settlement_type = type
	s.garrison_pu = garrison
	s.population_pu = 10
	return s


func _make_minimal_world() -> Dictionary:
	var provinces: Dictionary = {}
	var settlements: Array = []

	var p1: ProvinceData = _make_province(1, "Crab", "Hida")
	provinces[1] = p1
	settlements.append(_make_settlement(100, 1, Enums.SettlementType.CASTLE, 2))
	settlements.append(_make_settlement(101, 1, Enums.SettlementType.TOWN))

	var p2: ProvinceData = _make_province(2, "Crane", "Doji")
	provinces[2] = p2
	settlements.append(_make_settlement(200, 2, Enums.SettlementType.CITY, 1))

	return {"provinces": provinces, "settlements": settlements}


# -- Position Registry Tests ---------------------------------------------------

func test_position_rank_table_complete():
	for pt: int in WorldPopulationGenerator.PositionType.values():
		assert_true(
			WorldPopulationGenerator.POSITION_RANK.has(pt),
			"Missing rank for position type %d" % pt,
		)


func test_position_status_table_complete():
	for pt: int in WorldPopulationGenerator.PositionType.values():
		assert_true(
			WorldPopulationGenerator.POSITION_STATUS.has(pt),
			"Missing status for position type %d" % pt,
		)


func test_emperor_is_highest_rank():
	assert_eq(
		WorldPopulationGenerator.POSITION_RANK[WorldPopulationGenerator.PositionType.EMPEROR],
		6,
	)


func test_emperor_is_highest_status():
	assert_eq(
		WorldPopulationGenerator.POSITION_STATUS[WorldPopulationGenerator.PositionType.EMPEROR],
		10.0,
	)


func test_clan_champion_rank():
	assert_eq(
		WorldPopulationGenerator.POSITION_RANK[WorldPopulationGenerator.PositionType.CLAN_CHAMPION],
		5,
	)


func test_chui_rank():
	assert_eq(
		WorldPopulationGenerator.POSITION_RANK[WorldPopulationGenerator.PositionType.CHUI],
		2,
	)


# -- Clan Family Data ---------------------------------------------------------

func test_great_clans_count():
	assert_eq(WorldPopulationGenerator.GREAT_CLANS.size(), 7)


func test_clan_families_all_clans():
	for clan: String in WorldPopulationGenerator.GREAT_CLANS:
		assert_true(
			WorldPopulationGenerator.CLAN_FAMILIES.has(clan),
			"Missing families for " + clan,
		)


func test_minor_clans_count():
	assert_true(WorldPopulationGenerator.MINOR_CLANS.size() >= 14)


# -- School Selection ---------------------------------------------------------

func test_bushi_school_for_bushi_position():
	var school: String = WorldPopulationGenerator._get_school_for_position(
		WorldPopulationGenerator.PositionType.GARRISON_COMMANDER,
		"Crab", "Hida", dice,
	)
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	assert_eq(sd.get("type", -1), Enums.SchoolType.BUSHI)


func test_courtier_school_for_courtier_position():
	var school: String = WorldPopulationGenerator._get_school_for_position(
		WorldPopulationGenerator.PositionType.SENIOR_COURTIER,
		"Crab", "Yasuki", dice,
	)
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	assert_eq(sd.get("type", -1), Enums.SchoolType.COURTIER)


func test_shugenja_school_for_temple_head():
	var school: String = WorldPopulationGenerator._get_school_for_position(
		WorldPopulationGenerator.PositionType.TEMPLE_HEAD,
		"Crab", "Kuni", dice,
	)
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	assert_eq(sd.get("type", -1), Enums.SchoolType.SHUGENJA)


func test_school_master_uses_family_school():
	var school: String = WorldPopulationGenerator._get_school_for_position(
		WorldPopulationGenerator.PositionType.SCHOOL_MASTER,
		"Crane", "Kakita", dice,
	)
	assert_eq(school, "Kakita Bushi")


func test_bushi_school_fallback_across_families():
	var school: String = WorldPopulationGenerator._get_school_for_position(
		WorldPopulationGenerator.PositionType.RIKUGUNSHOKAN,
		"Crab", "Yasuki", dice,
	)
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	assert_eq(sd.get("type", -1), Enums.SchoolType.BUSHI)


# -- Character Generation Helper -----------------------------------------------

func test_generate_positioned_character():
	var next_id: Array = [1]
	var c: L5RCharacterData = WorldPopulationGenerator._generate_positioned_character(
		next_id, WorldPopulationGenerator.PositionType.CLAN_CHAMPION,
		"Lion", "Akodo", dice,
	)
	assert_eq(c.character_id, 1)
	assert_eq(c.clan, "Lion")
	assert_eq(c.family, "Akodo")
	assert_eq(c.status, 8.0)
	assert_eq(next_id[0], 2)


func test_positioned_character_has_orientation():
	var next_id: Array = [1]
	var c: L5RCharacterData = WorldPopulationGenerator._generate_positioned_character(
		next_id, WorldPopulationGenerator.PositionType.SAMURAI,
		"Crab", "Hida", dice,
	)
	assert_true(c.orientation in ["straight", "gay", "bisexual"])


func test_positioned_character_has_name():
	var next_id: Array = [1]
	var c: L5RCharacterData = WorldPopulationGenerator._generate_positioned_character(
		next_id, WorldPopulationGenerator.PositionType.SAMURAI,
		"Crane", "Doji", dice,
	)
	assert_true(c.character_name.length() > 0)


# -- Imperial Positions --------------------------------------------------------

func test_imperial_positions_count():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_imperial_positions(
		next_id, dice,
	)
	assert_true(chars.size() >= 15, "Expected at least 15 imperial characters, got %d" % chars.size())


func test_emperor_is_first():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_imperial_positions(
		next_id, dice,
	)
	assert_eq(chars[0].status, 10.0)


func test_imperial_heir_has_emperor_lord():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_imperial_positions(
		next_id, dice,
	)
	var emperor_id: int = chars[0].character_id
	assert_eq(chars[1].lord_id, emperor_id)


func test_imperial_family_daimyo_count():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_imperial_positions(
		next_id, dice,
	)
	var fd_count: int = 0
	for c: L5RCharacterData in chars:
		if c.status == 6.0 and c.clan == "Imperial":
			fd_count += 1
	assert_eq(fd_count, 3)


# -- Clan Leadership -----------------------------------------------------------

func test_clan_leadership_has_champion():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_clan_leadership(
		"Lion", next_id, dice,
	)
	var champ_count: int = 0
	for c: L5RCharacterData in chars:
		if c.status >= 8.0:
			champ_count += 1
	assert_eq(champ_count, 1)


func test_clan_leadership_has_family_daimyo():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_clan_leadership(
		"Crab", next_id, dice,
	)
	var fd_count: int = 0
	for c: L5RCharacterData in chars:
		if c.status == 6.0:
			fd_count += 1
	assert_eq(fd_count, 5)


func test_clan_champion_is_lordless():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_clan_leadership(
		"Dragon", next_id, dice,
	)
	assert_eq(chars[0].lord_id, -1)


func test_clan_leadership_has_school_masters():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_clan_leadership(
		"Crane", next_id, dice,
	)
	var sm_count: int = 0
	for c: L5RCharacterData in chars:
		if c.status == 5.0:
			sm_count += 1
	assert_true(sm_count >= 3)


# -- Military Commanders ------------------------------------------------------

func test_military_commanders_count():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_military_commanders(
		"Lion", -1, next_id, dice,
	)
	var army_count: int = WorldPopulationGenerator.CLAN_ARMY_COUNT["Lion"]
	var expected_taisa: int = army_count * WorldPopulationGenerator.LEGIONS_PER_ARMY
	var expected_chui: int = expected_taisa * WorldPopulationGenerator.COMPANIES_PER_LEGION
	assert_eq(chars.size(), expected_taisa + expected_chui)


func test_military_commanders_have_lord_chain():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_military_commanders(
		"Crab", 999, next_id, dice,
	)
	var taisa: L5RCharacterData = chars[0]
	assert_eq(taisa.lord_id, 999)
	var chui: L5RCharacterData = chars[1]
	assert_eq(chui.lord_id, taisa.character_id)


# -- Province Positions --------------------------------------------------------

func test_province_positions_provincial_daimyo():
	var next_id: Array = [1]
	var prov: ProvinceData = _make_province(1, "Crab", "Hida")
	var setts: Array = [
		_make_settlement(100, 1, Enums.SettlementType.CASTLE, 2),
	]
	var chars: Array = WorldPopulationGenerator._generate_province_positions(
		prov, setts, "Crab", -1, next_id, dice,
	)
	assert_true(chars.size() >= 2)
	assert_eq(chars[0].status, 4.0)


func test_province_town_gets_local_daimyo():
	var next_id: Array = [1]
	var prov: ProvinceData = _make_province(1, "Crane", "Doji")
	var setts: Array = [
		_make_settlement(100, 1, Enums.SettlementType.TOWN),
	]
	var chars: Array = WorldPopulationGenerator._generate_province_positions(
		prov, setts, "Crane", -1, next_id, dice,
	)
	var local_daimyo_count: int = 0
	for c: L5RCharacterData in chars:
		if c.status == 3.0:
			local_daimyo_count += 1
	assert_true(local_daimyo_count >= 1)


func test_province_temple_gets_temple_head():
	var next_id: Array = [1]
	var prov: ProvinceData = _make_province(1, "Phoenix", "Isawa")
	var setts: Array = [
		_make_settlement(100, 1, Enums.SettlementType.TEMPLE),
	]
	var chars: Array = WorldPopulationGenerator._generate_province_positions(
		prov, setts, "Phoenix", -1, next_id, dice,
	)
	var head_count: int = 0
	for c: L5RCharacterData in chars:
		if c.status == 3.5:
			head_count += 1
	assert_true(head_count >= 1)


# -- Minor Clans ---------------------------------------------------------------

func test_minor_clan_characters():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_minor_clan_characters(
		next_id, dice,
	)
	assert_eq(chars.size(), WorldPopulationGenerator.MINOR_CLANS.size() * 2)


func test_minor_clan_champion_lordless():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_minor_clan_characters(
		next_id, dice,
	)
	assert_eq(chars[0].lord_id, -1)


func test_minor_clan_senior_has_champion_lord():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_minor_clan_characters(
		next_id, dice,
	)
	assert_eq(chars[1].lord_id, chars[0].character_id)


# -- Wall Characters -----------------------------------------------------------

func test_wall_characters_count():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_wall_characters(
		next_id, dice, -1,
	)
	assert_eq(chars.size(), 5)


func test_wall_segment_commanders_are_kaiu():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_wall_characters(
		next_id, dice, -1,
	)
	for i: int in range(4):
		assert_eq(chars[i].family, "Kaiu")


func test_hiruma_scout_commander():
	var next_id: Array = [1]
	var chars: Array = WorldPopulationGenerator._generate_wall_characters(
		next_id, dice, -1,
	)
	assert_eq(chars[4].family, "Hiruma")


# -- Rank Filling --------------------------------------------------------------

func test_rank_filling_generates_deficit():
	var next_id: Array = [1]
	var existing: Dictionary = {1: 50, 2: 10, 3: 5, 4: 1, 5: 0}
	var chars: Array = WorldPopulationGenerator._generate_rank_filling(
		"Dragon", existing, next_id, dice,
	)
	assert_true(chars.size() > 0, "Should generate characters to fill deficit")


func test_rank_filling_no_deficit():
	var next_id: Array = [1]
	var existing: Dictionary = {1: 500, 2: 500, 3: 500, 4: 500, 5: 500}
	var chars: Array = WorldPopulationGenerator._generate_rank_filling(
		"Dragon", existing, next_id, dice,
	)
	assert_eq(chars.size(), 0)


# -- Family Web ----------------------------------------------------------------

func test_assign_parents_creates_links():
	var c1 := L5RCharacterData.new()
	c1.character_id = 1
	c1.age = 45
	c1.gender = "male"
	c1.family = "Hida"
	c1.clan = "Crab"

	var c2 := L5RCharacterData.new()
	c2.character_id = 2
	c2.age = 20
	c2.gender = "male"
	c2.family = "Hida"
	c2.clan = "Crab"

	var chars: Array = [c1, c2]
	var d := DiceEngine.new()
	d.set_seed(1)

	var found_parent: bool = false
	for _attempt: int in range(20):
		c2.father_id = -1
		c2.mother_id = -1
		c1.children_ids.clear()
		d.set_seed(_attempt)
		WorldPopulationGenerator._assign_parents(chars, d)
		if c2.father_id == 1:
			found_parent = true
			break

	assert_true(found_parent, "Parent should be assigned at least once in 20 attempts")


func test_assign_marriages_creates_pairs():
	var chars: Array = []
	for i: int in range(20):
		var c := L5RCharacterData.new()
		c.character_id = i
		c.age = 25 + (i % 5)
		c.gender = "male" if i % 2 == 0 else "female"
		c.family = "Hida"
		c.clan = "Crab"
		chars.append(c)

	var d := DiceEngine.new()
	d.set_seed(7)
	var all_by_clan: Dictionary = {"Crab": chars}
	WorldPopulationGenerator._assign_marriages(chars, all_by_clan, d)

	var married_count: int = 0
	for c: L5RCharacterData in chars:
		if c.spouse_id >= 0:
			married_count += 1
	assert_true(married_count > 0, "At least one marriage should occur")


func test_assign_siblings_from_shared_parents():
	var parent := L5RCharacterData.new()
	parent.character_id = 1
	parent.age = 45
	parent.gender = "male"
	parent.family = "Hida"
	parent.clan = "Crab"

	var child_a := L5RCharacterData.new()
	child_a.character_id = 2
	child_a.age = 20
	child_a.father_id = 1
	child_a.family = "Hida"
	child_a.clan = "Crab"

	var child_b := L5RCharacterData.new()
	child_b.character_id = 3
	child_b.age = 18
	child_b.father_id = 1
	child_b.family = "Hida"
	child_b.clan = "Crab"

	parent.children_ids = [2, 3]

	var chars: Array = [parent, child_a, child_b]
	WorldPopulationGenerator._assign_siblings(chars, dice)

	assert_true(3 in child_a.sibling_ids)
	assert_true(2 in child_b.sibling_ids)


# -- Ancestor Records ---------------------------------------------------------

func test_ancestor_records_generated():
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Crane"
	c.family = "Doji"
	c.age = 30
	var chars: Array = [c]
	WorldPopulationGenerator._generate_ancestor_records(chars, dice)
	assert_true(c.grandparent_records.size() > 0)


# -- Count Helpers -------------------------------------------------------------

func test_count_by_rank():
	var chars: Array = []
	for _i: int in range(5):
		var c := L5RCharacterData.new()
		c.clan = "Crab"
		c.stamina = 2
		c.willpower = 2
		c.strength = 2
		c.perception = 2
		c.reflexes = 2
		c.awareness = 2
		c.agility = 2
		c.intelligence = 2
		chars.append(c)
	var counts: Dictionary = WorldPopulationGenerator._count_by_rank(chars, "Crab")
	assert_eq(counts.get(1, 0), 5)


func test_count_by_rank_filters_clan():
	var chars: Array = []
	var c1 := L5RCharacterData.new()
	c1.clan = "Crab"
	c1.stamina = 2
	c1.willpower = 2
	c1.strength = 2
	c1.perception = 2
	c1.reflexes = 2
	c1.awareness = 2
	c1.agility = 2
	c1.intelligence = 2
	chars.append(c1)

	var c2 := L5RCharacterData.new()
	c2.clan = "Crane"
	c2.stamina = 2
	c2.willpower = 2
	c2.strength = 2
	c2.perception = 2
	c2.reflexes = 2
	c2.awareness = 2
	c2.agility = 2
	c2.intelligence = 2
	chars.append(c2)

	var counts: Dictionary = WorldPopulationGenerator._count_by_rank(chars, "Crab")
	assert_eq(counts.get(1, 0), 1)


# -- Full Integration ----------------------------------------------------------

func test_generate_world_population_returns_characters():
	var world: Dictionary = _make_minimal_world()
	var next_id: Array = [1]
	var result: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], dice, next_id,
	)
	assert_true(result.has("characters"))
	assert_true(result["total_count"] > 100)


func test_generate_world_population_has_emperor():
	var world: Dictionary = _make_minimal_world()
	var next_id: Array = [1]
	var result: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], dice, next_id,
	)
	assert_true(result["emperor_id"] > 0)


func test_generate_world_population_has_clan_champions():
	var world: Dictionary = _make_minimal_world()
	var next_id: Array = [1]
	var result: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], dice, next_id,
	)
	assert_eq(result["clan_champions"].size(), 7)


func test_generate_world_population_deterministic():
	var world: Dictionary = _make_minimal_world()
	var next_id1: Array = [1]
	var d1 := DiceEngine.new()
	d1.set_seed(99)
	var r1: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], d1, next_id1,
	)

	var next_id2: Array = [1]
	var d2 := DiceEngine.new()
	d2.set_seed(99)
	var r2: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], d2, next_id2,
	)
	assert_eq(r1["total_count"], r2["total_count"])


func test_generate_world_population_unique_ids():
	var world: Dictionary = _make_minimal_world()
	var next_id: Array = [1]
	var result: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], dice, next_id,
	)
	var ids: Dictionary = {}
	for c: L5RCharacterData in result["characters"]:
		assert_false(ids.has(c.character_id), "Duplicate ID: %d" % c.character_id)
		ids[c.character_id] = true


func test_generate_world_population_with_dispositions():
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	var world: Dictionary = _make_minimal_world()
	var next_id: Array = [1]
	var result: Dictionary = WorldPopulationGenerator.generate_world_population(
		world["provinces"], world["settlements"], dice, next_id,
		baselines["clan"], baselines["family"],
	)
	var chars: Array = result["characters"]
	var found_disp: bool = false
	for c: L5RCharacterData in chars:
		if not c.disposition_values.is_empty():
			found_disp = true
			break
	assert_true(found_disp, "At least some characters should have disposition values set")


# -- Rank Distribution --------------------------------------------------------

func test_rank_distribution_covers_all_great_clans():
	for clan: String in WorldPopulationGenerator.GREAT_CLANS:
		assert_true(
			WorldPopulationGenerator.RANK_DISTRIBUTION.has(clan),
			"Missing rank distribution for " + clan,
		)


func test_rank_distribution_has_mantis():
	assert_true(WorldPopulationGenerator.RANK_DISTRIBUTION.has("Mantis"))


func test_rank_distribution_lion_is_largest():
	var lion_total: int = 0
	var lion_ranks: Dictionary = WorldPopulationGenerator.RANK_DISTRIBUTION["Lion"]
	for rank: int in lion_ranks:
		lion_total += lion_ranks[rank]
	var dragon_total: int = 0
	var dragon_ranks: Dictionary = WorldPopulationGenerator.RANK_DISTRIBUTION["Dragon"]
	for rank: int in dragon_ranks:
		dragon_total += dragon_ranks[rank]
	assert_true(lion_total > dragon_total)


func test_positioned_characters_get_role_position():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var next_id: Array = [1]
	var c: L5RCharacterData = WorldPopulationGenerator._generate_positioned_character(
		next_id, WorldPopulationGenerator.PositionType.SCHOOL_MASTER,
		"Crab", "Hida", dice, 99,
	)
	assert_eq(c.role_position, "School Master")


func test_positioned_magistrate_gets_role_position():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var next_id: Array = [1]
	var c: L5RCharacterData = WorldPopulationGenerator._generate_positioned_character(
		next_id, WorldPopulationGenerator.PositionType.CLAN_MAGISTRATE,
		"Lion", "Akodo", dice, 99,
	)
	assert_eq(c.role_position, "Clan Magistrate")


func test_positioned_samurai_has_empty_role():
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var next_id: Array = [1]
	var c: L5RCharacterData = WorldPopulationGenerator._generate_positioned_character(
		next_id, WorldPopulationGenerator.PositionType.SAMURAI,
		"Crane", "Doji", dice, 99,
	)
	assert_eq(c.role_position, "")
