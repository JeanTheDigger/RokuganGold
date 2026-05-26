extends GutTest
## Tests for GempukkuSystem per GDD s52, s22.4, s22.7.
## Covers: orientation distribution, gender distribution, school assignment,
## name generation, population thresholds, natural death, gempukku processing,
## child creation, replenishment, DayOrchestrator wiring.


var _dice: DiceEngine
var _char: L5RCharacterData


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.character_name = "Test Samurai"
	_char.clan = "Crab"
	_char.family = "Hida"
	_char.school = "Hida Bushi"
	_char.school_type = Enums.SchoolType.BUSHI
	_char.age = 25
	_char.gender = "male"
	_char.stamina = 3
	_char.willpower = 3
	_char.strength = 2
	_char.perception = 2
	_char.agility = 2
	_char.intelligence = 2
	_char.reflexes = 2
	_char.awareness = 2
	_char.void_ring = 2
	_char.honor = 3.5
	_char.glory = 1.0
	_char.status = 1.0
	_char.skills = {"Battle": 3, "Kenjutsu": 2}


# =============================================================================
# ORIENTATION
# =============================================================================

func test_roll_orientation_returns_valid_values() -> void:
	for i: int in range(50):
		var o: String = GempukkuSystem.roll_orientation(_dice)
		assert_true(o in ["straight", "gay", "bisexual"],
			"Orientation should be one of the three valid values")


func test_orientation_distribution_roughly_correct() -> void:
	_dice.set_seed(100)
	var counts: Dictionary = {"straight": 0, "gay": 0, "bisexual": 0}
	for i: int in range(1000):
		counts[GempukkuSystem.roll_orientation(_dice)] += 1
	assert_true(counts["straight"] > 700, "Straight should be majority")
	assert_true(counts["gay"] > 30, "Gay should appear sometimes")
	assert_true(counts["bisexual"] > 10, "Bisexual should appear sometimes")


# =============================================================================
# GENDER
# =============================================================================

func test_roll_gender_returns_male_or_female() -> void:
	for i: int in range(20):
		var g: String = GempukkuSystem.roll_gender(_dice)
		assert_true(g in ["male", "female"])


func test_gender_default_distribution() -> void:
	_dice.set_seed(200)
	var male_count: int = 0
	for i: int in range(1000):
		if GempukkuSystem.roll_gender(_dice) == "male":
			male_count += 1
	assert_true(male_count > 450 and male_count < 650,
		"Default should be roughly 55%% male: got %d" % male_count)


func test_utaku_battle_maiden_always_female() -> void:
	for i: int in range(20):
		var g: String = GempukkuSystem.roll_gender(_dice, "Utaku Battle Maiden")
		assert_eq(g, "female")


func test_matsu_berserker_skews_female() -> void:
	_dice.set_seed(300)
	var female_count: int = 0
	for i: int in range(500):
		if GempukkuSystem.roll_gender(_dice, "Matsu Berserker") == "female":
			female_count += 1
	assert_true(female_count > 300, "Matsu should skew female: got %d" % female_count)


# =============================================================================
# SCHOOL ASSIGNMENT
# =============================================================================

func test_family_default_school_hida() -> void:
	assert_eq(GempukkuSystem.assign_school("Hida", "male"), "Hida Bushi")


func test_family_default_school_doji() -> void:
	assert_eq(GempukkuSystem.assign_school("Doji", "female"), "Doji Courtier")


func test_family_default_school_isawa() -> void:
	assert_eq(GempukkuSystem.assign_school("Isawa", "male"), "Isawa Shugenja")


func test_utaku_female_gets_battle_maiden() -> void:
	assert_eq(GempukkuSystem.assign_school("Utaku", "female"), "Utaku Battle Maiden")


func test_utaku_male_gets_fallback_shinjo() -> void:
	assert_eq(GempukkuSystem.assign_school("Utaku", "male"), "Shinjo Bushi")


func test_unknown_family_returns_empty() -> void:
	assert_eq(GempukkuSystem.assign_school("Unknown", "male"), "")


func test_all_families_have_schools() -> void:
	var families: Array = [
		"Hida", "Hiruma", "Kaiu", "Kuni", "Yasuki", "Toritaka",
		"Kakita", "Daidoji", "Doji", "Asahina",
		"Mirumoto", "Kitsuki", "Tamori", "Togashi",
		"Akodo", "Matsu", "Ikoma", "Kitsu",
		"Shiba", "Isawa", "Asako", "Agasha",
		"Bayushi", "Soshi", "Shosuro", "Yogo",
		"Shinjo", "Moto", "Ide", "Iuchi", "Utaku",
		"Yoritomo", "Moshi", "Tsuruchi",
	]
	for f: String in families:
		var school: String = GempukkuSystem.assign_school(f, "female")
		assert_true(not school.is_empty(), "Family %s should have a school" % f)


# =============================================================================
# NAME GENERATION
# =============================================================================

func test_generate_name_returns_nonempty() -> void:
	var name: String = GempukkuSystem.generate_name("Crab", "male", _dice)
	assert_true(name.length() > 0)
	assert_ne(name, "Unknown")


func test_generate_name_all_clans_male() -> void:
	var clans: Array = ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn", "Mantis"]
	for clan: String in clans:
		var name: String = GempukkuSystem.generate_name(clan, "male", _dice)
		assert_ne(name, "Unknown", "Clan %s male should produce a name" % clan)


func test_generate_name_all_clans_female() -> void:
	var clans: Array = ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn", "Mantis"]
	for clan: String in clans:
		var name: String = GempukkuSystem.generate_name(clan, "female", _dice)
		assert_ne(name, "Unknown", "Clan %s female should produce a name" % clan)


func test_generate_name_unknown_clan_returns_unknown() -> void:
	assert_eq(GempukkuSystem.generate_name("Badger", "male", _dice), "Unknown")


func test_name_variance() -> void:
	_dice.set_seed(1)
	var name1: String = GempukkuSystem.generate_name("Lion", "male", _dice)
	_dice.set_seed(2)
	var name2: String = GempukkuSystem.generate_name("Lion", "male", _dice)
	_dice.set_seed(3)
	var name3: String = GempukkuSystem.generate_name("Lion", "male", _dice)
	var names: Array = [name1, name2, name3]
	var unique: Dictionary = {}
	for n: String in names:
		unique[n] = true
	assert_true(unique.size() >= 2, "Different seeds should produce different names")


# =============================================================================
# POPULATION THRESHOLDS
# =============================================================================

func test_count_clan_population_empty() -> void:
	var chars: Array = []
	var counts: Dictionary = GempukkuSystem.count_clan_population(chars, "Crab")
	assert_eq(counts["rank_1"], 0)
	assert_eq(counts["rank_5"], 0)


func test_count_clan_population_single_rank1() -> void:
	var c := L5RCharacterData.new()
	c.clan = "Crab"
	c.skills = {"Battle": 1}
	c.stamina = 2
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 2
	c.intelligence = 2
	c.reflexes = 2
	c.awareness = 2
	c.void_ring = 2
	var chars: Array = [c]
	var counts: Dictionary = GempukkuSystem.count_clan_population(chars, "Crab")
	assert_eq(counts["rank_1"], 1)


func test_count_excludes_dead_characters() -> void:
	var c := L5RCharacterData.new()
	c.clan = "Crab"
	c.stamina = 2
	c.willpower = 2
	c.wounds_taken = 999
	var chars: Array = [c]
	var counts: Dictionary = GempukkuSystem.count_clan_population(chars, "Crab")
	assert_eq(counts["rank_1"], 0)


func test_count_excludes_other_clan() -> void:
	var c := L5RCharacterData.new()
	c.clan = "Crane"
	c.skills = {"Battle": 1}
	c.stamina = 2
	c.willpower = 2
	var chars: Array = [c]
	var counts: Dictionary = GempukkuSystem.count_clan_population(chars, "Crab")
	assert_eq(counts["rank_1"], 0)


func test_replenishment_needed_below_threshold() -> void:
	var counts: Dictionary = {"rank_5": 3, "rank_4": 8, "rank_3": 25, "rank_2": 60, "rank_1": 50}
	var needed: int = GempukkuSystem.get_replenishment_needed("Crab", counts)
	assert_eq(needed, 50)


func test_replenishment_not_needed_at_threshold() -> void:
	var counts: Dictionary = {"rank_5": 3, "rank_4": 8, "rank_3": 25, "rank_2": 60, "rank_1": 100}
	var needed: int = GempukkuSystem.get_replenishment_needed("Crab", counts)
	assert_eq(needed, 0)


func test_replenishment_unknown_clan() -> void:
	var counts: Dictionary = {"rank_1": 0}
	assert_eq(GempukkuSystem.get_replenishment_needed("Badger", counts), 0)


# =============================================================================
# NATURAL DEATH
# =============================================================================

func test_natural_death_chance_under_50() -> void:
	assert_eq(GempukkuSystem.get_natural_death_chance(25), 0)
	assert_eq(GempukkuSystem.get_natural_death_chance(49), 0)


func test_natural_death_chance_50_to_65() -> void:
	assert_eq(GempukkuSystem.get_natural_death_chance(50), 1)
	assert_eq(GempukkuSystem.get_natural_death_chance(64), 1)


func test_natural_death_chance_65_to_75() -> void:
	assert_eq(GempukkuSystem.get_natural_death_chance(65), 3)
	assert_eq(GempukkuSystem.get_natural_death_chance(74), 3)


func test_natural_death_chance_75_to_85() -> void:
	assert_eq(GempukkuSystem.get_natural_death_chance(75), 8)
	assert_eq(GempukkuSystem.get_natural_death_chance(84), 8)


func test_natural_death_chance_85_plus() -> void:
	assert_eq(GempukkuSystem.get_natural_death_chance(85), 20)
	assert_eq(GempukkuSystem.get_natural_death_chance(100), 20)


func test_roll_natural_death_young_never_dies() -> void:
	_char.age = 30
	for i: int in range(50):
		assert_false(GempukkuSystem.roll_natural_death(_char, _dice))


func test_roll_natural_death_old_sometimes_dies() -> void:
	_char.age = 90
	var died: bool = false
	for i: int in range(100):
		_dice.set_seed(i)
		if GempukkuSystem.roll_natural_death(_char, _dice):
			died = true
			break
	assert_true(died, "90-year-old should eventually die")


# =============================================================================
# CHILD RECORD
# =============================================================================

func test_child_record_defaults() -> void:
	var child := ChildRecord.new()
	assert_eq(child.child_id, -1)
	assert_false(child.is_gempukku_ready(0))


func test_child_gempukku_ready_at_18_years() -> void:
	var child := ChildRecord.new()
	child.ic_day_born = 0
	child.is_alive = true
	assert_false(child.is_gempukku_ready(6479))
	assert_true(child.is_gempukku_ready(6480))
	assert_true(child.is_gempukku_ready(7000))


func test_dead_child_not_gempukku_ready() -> void:
	var child := ChildRecord.new()
	child.ic_day_born = 0
	child.is_alive = false
	assert_false(child.is_gempukku_ready(7000))


func test_child_age_days() -> void:
	var child := ChildRecord.new()
	child.ic_day_born = 100
	assert_eq(child.get_age_days(200), 100)
	assert_eq(child.get_age_days(100), 0)


# =============================================================================
# CREATE CHILD AT BIRTH
# =============================================================================

func test_create_child_at_birth() -> void:
	var father := L5RCharacterData.new()
	father.character_id = 10
	var mother := L5RCharacterData.new()
	mother.character_id = 20
	var child: ChildRecord = GempukkuSystem.create_child_at_birth(
		1, father, mother, "Crab", "Hida", 360, _dice,
	)
	assert_eq(child.child_id, 1)
	assert_eq(child.father_id, 10)
	assert_eq(child.mother_id, 20)
	assert_eq(child.clan, "Crab")
	assert_eq(child.family, "Hida")
	assert_eq(child.ic_day_born, 360)
	assert_true(child.is_alive)
	assert_true(child.gender in ["male", "female"])
	assert_true(child.orientation in ["straight", "gay", "bisexual"])
	assert_ne(child.child_name, "Unknown")
	assert_true(child.child_name.length() > 0)


# =============================================================================
# GEMPUKKU PROCESSING
# =============================================================================

func test_process_gempukku_creates_character() -> void:
	var child := ChildRecord.new()
	child.child_id = 1
	child.child_name = "Yakamo"
	child.clan = "Crab"
	child.family = "Hida"
	child.gender = "male"
	child.orientation = "straight"
	child.ic_day_born = 0
	child.is_alive = true

	var result: L5RCharacterData = GempukkuSystem.process_gempukku(
		child, 500, _dice, 6480,
	)
	assert_not_null(result)
	assert_eq(result.character_id, 500)
	assert_eq(result.character_name, "Yakamo")
	assert_eq(result.clan, "Crab")
	assert_eq(result.family, "Hida")
	assert_eq(result.school, "Hida Bushi")
	assert_eq(result.school_type, Enums.SchoolType.BUSHI)
	assert_eq(result.gender, "male")
	assert_eq(result.orientation, "straight")
	assert_eq(result.mother_id, -1)
	assert_eq(result.father_id, -1)


func test_process_gempukku_not_ready_returns_null() -> void:
	var child := ChildRecord.new()
	child.child_id = 1
	child.ic_day_born = 0
	child.is_alive = true
	child.clan = "Crab"
	child.family = "Hida"
	child.gender = "male"
	var result: L5RCharacterData = GempukkuSystem.process_gempukku(
		child, 500, _dice, 6000,
	)
	assert_null(result)


func test_process_gempukku_dead_child_returns_null() -> void:
	var child := ChildRecord.new()
	child.child_id = 1
	child.ic_day_born = 0
	child.is_alive = false
	child.clan = "Crab"
	child.family = "Hida"
	child.gender = "male"
	var result: L5RCharacterData = GempukkuSystem.process_gempukku(
		child, 500, _dice, 7000,
	)
	assert_null(result)


func test_process_gempukku_utaku_male_gets_shinjo() -> void:
	var child := ChildRecord.new()
	child.child_id = 1
	child.child_name = "Shinrai"
	child.clan = "Unicorn"
	child.family = "Utaku"
	child.gender = "male"
	child.orientation = "straight"
	child.ic_day_born = 0
	child.is_alive = true
	var result: L5RCharacterData = GempukkuSystem.process_gempukku(
		child, 600, _dice, 6480,
	)
	assert_not_null(result)
	assert_eq(result.school, "Shinjo Bushi")


func test_process_gempukku_preserves_parent_ids() -> void:
	var child := ChildRecord.new()
	child.child_id = 1
	child.child_name = "Taro"
	child.clan = "Lion"
	child.family = "Akodo"
	child.gender = "male"
	child.orientation = "straight"
	child.ic_day_born = 0
	child.is_alive = true
	child.father_id = 100
	child.mother_id = 200
	var result: L5RCharacterData = GempukkuSystem.process_gempukku(
		child, 700, _dice, 6480,
	)
	assert_not_null(result)
	assert_eq(result.father_id, 100)
	assert_eq(result.mother_id, 200)


# =============================================================================
# REPLENISHMENT
# =============================================================================

func test_generate_replenishment_character() -> void:
	var rc: L5RCharacterData = GempukkuSystem.generate_replenishment_character(
		800, "Crane", _dice,
	)
	assert_not_null(rc)
	assert_eq(rc.character_id, 800)
	assert_eq(rc.clan, "Crane")
	assert_true(rc.family in ["Kakita", "Daidoji", "Doji", "Asahina"])
	assert_true(rc.school.length() > 0)
	assert_true(rc.orientation in ["straight", "gay", "bisexual"])


func test_replenishment_unknown_clan_returns_null() -> void:
	var rc: L5RCharacterData = GempukkuSystem.generate_replenishment_character(
		800, "Badger", _dice,
	)
	assert_null(rc)


# =============================================================================
# SEASONAL PROCESSING
# =============================================================================

func _make_child(id: int, clan: String, family: String, gender: String, born_day: int) -> ChildRecord:
	var c := ChildRecord.new()
	c.child_id = id
	c.child_name = "Child" + str(id)
	c.clan = clan
	c.family = family
	c.gender = gender
	c.orientation = "straight"
	c.ic_day_born = born_day
	c.is_alive = true
	return c


func test_process_seasonal_graduates_ready_child() -> void:
	var child: ChildRecord = _make_child(1, "Crab", "Hida", "male", 0)
	var children: Array = [child]
	var characters: Array = []
	var next_id: Array = [100]
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_id, _dice, 6480,
	)
	assert_eq(result["new_characters"].size(), 1)
	assert_eq(result["graduated_child_ids"].size(), 1)
	assert_eq(result["graduated_child_ids"][0], 1)
	# next_id is incremented by gempukku (1) plus all clan replenishment
	# characters since the character pool is empty. Just verify it advanced
	# past the gempukku allocation.
	assert_true(next_id[0] >= 101, "next_id should advance past gempukku allocation")


func test_process_seasonal_skips_not_ready_child() -> void:
	var child: ChildRecord = _make_child(1, "Crab", "Hida", "male", 1000)
	var children: Array = [child]
	var characters: Array = []
	var next_id: Array = [100]
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_id, _dice, 6000,
	)
	assert_eq(result["new_characters"].size(), 0)
	assert_eq(result["graduated_child_ids"].size(), 0)


func test_process_seasonal_replenishes_depleted_clan() -> void:
	var children: Array = []
	var characters: Array = []
	var next_id: Array = [100]
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_id, _dice, 100,
	)
	assert_true(result["replenishment_characters"].size() > 0,
		"Should replenish when all clans are below threshold")


func test_process_seasonal_natural_death_check() -> void:
	var old_char := L5RCharacterData.new()
	old_char.character_id = 50
	old_char.clan = "Crab"
	old_char.age = 90
	old_char.stamina = 2
	old_char.willpower = 2
	var children: Array = []
	var characters: Array = [old_char]
	var died: bool = false
	for seed: int in range(100):
		_dice.set_seed(seed)
		old_char.wounds_taken = 0
		var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
			children, characters, [100], _dice, 100,
		)
		if result["natural_deaths"].size() > 0:
			died = true
			break
	assert_true(died, "90-year-old should eventually die in seasonal check")


func test_process_seasonal_musha_shugyo_tracking() -> void:
	_dice.set_seed(999)
	var child: ChildRecord = _make_child(1, "Dragon", "Mirumoto", "male", 0)
	child.clan = "Dragon"
	var children: Array = [child]
	var characters: Array = []
	var next_id: Array = [100]
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_id, _dice, 6480,
	)
	assert_true(result.has("musha_shugyo_triggered"))


# =============================================================================
# DAY ORCHESTRATOR WIRING
# =============================================================================

func _make_time_system(target_day: int) -> TimeSystem:
	var ts := TimeSystem.new()
	for i: int in range(target_day):
		ts.advance_tick()
	return ts


func test_orchestrator_accepts_children_param() -> void:
	var ts: TimeSystem = _make_time_system(0)
	var characters: Array = []
	var children: Array = []
	var result: Dictionary = DayOrchestrator.advance_day(
		ts, characters, {}, {}, {}, {}, {},
		_dice, {}, {}, [], {},
		[], [], [], [], [], [1],
		{}, {}, [1000], [], {},
		[], [], [1], [], {},
		[], [1], [], [], [], [],
		[], [], [], {}, [], [1],
		[], [1], [], [1],
		[], [], {}, [-1],
		[], children, [10000],
	)
	assert_true(result.has("gempukku_results"))


func test_orchestrator_gempukku_on_season_change() -> void:
	# Day 89 is a season boundary (tick 89->90 crosses Spring->Summer).
	# Use day 88 so advance_tick goes to tick 89 (still Spring, no boundary).
	var ts: TimeSystem = _make_time_system(88)
	var child: ChildRecord = _make_child(1, "Crab", "Hida", "male", 0)
	var children: Array = [child]
	var characters: Array = []
	var result: Dictionary = DayOrchestrator.advance_day(
		ts, characters, {}, {}, {}, {}, {},
		_dice, {}, {}, [], {},
		[], [], [], [], [], [1],
		{}, {}, [1000], [], {},
		[], [], [1], [], {},
		[], [1], [], [], [], [],
		[], [], [], {}, [], [1],
		[], [1], [], [1],
		[], [], {}, [-1],
		[], children, [10000],
	)
	var gempukku: Dictionary = result.get("gempukku_results", {})
	assert_true(gempukku.is_empty(), "Should not fire gempukku on non-season boundary")


func test_orchestrator_gempukku_result_in_return() -> void:
	var ts: TimeSystem = _make_time_system(0)
	var result: Dictionary = DayOrchestrator.advance_day(
		ts, [], {}, {}, {}, {}, {},
		_dice, {}, {}, [], {},
		[], [], [], [], [], [1],
		{}, {}, [1000], [], {},
		[], [], [1], [], {},
		[], [1], [], [], [], [],
		[], [], [], {}, [], [1],
		[], [1], [], [1],
		[], [], {}, [-1],
		[], [], [10000],
	)
	assert_true(result.has("gempukku_results"))


# =============================================================================
# CLAN FAMILIES
# =============================================================================

func test_get_clan_families_all_clans() -> void:
	var clans: Array = ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn", "Mantis"]
	for clan: String in clans:
		var families: Array = GempukkuSystem._get_clan_families(clan)
		assert_true(families.size() >= 3, "Clan %s should have 3+ families" % clan)


func test_get_clan_families_unknown_empty() -> void:
	assert_eq(GempukkuSystem._get_clan_families("Badger").size(), 0)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_multiple_children_graduate_same_season() -> void:
	var c1: ChildRecord = _make_child(1, "Lion", "Akodo", "male", 0)
	var c2: ChildRecord = _make_child(2, "Lion", "Matsu", "female", 0)
	var children: Array = [c1, c2]
	var characters: Array = []
	var next_id: Array = [100]
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_id, _dice, 6480,
	)
	assert_eq(result["new_characters"].size(), 2)
	assert_eq(result["graduated_child_ids"].size(), 2)
	# next_id is incremented by gempukku (2) plus all clan replenishment
	# characters since the character pool is empty.
	assert_true(next_id[0] >= 102, "next_id should advance past both gempukku allocations")
	var ids: Array = []
	for nc: L5RCharacterData in result["new_characters"]:
		ids.append(nc.character_id)
	assert_true(100 in ids)
	assert_true(101 in ids)


func test_orientation_field_on_character_data() -> void:
	var c := L5RCharacterData.new()
	assert_eq(c.orientation, "straight")
	c.orientation = "bisexual"
	assert_eq(c.orientation, "bisexual")


# -- Dead character guards (2026-05-23) ----------------------------------------

func test_natural_death_roll_skips_already_dead_characters() -> void:
	var dead_char := L5RCharacterData.new()
	dead_char.character_id = 50
	dead_char.stamina = 2
	dead_char.willpower = 2
	dead_char.wounds_taken = 999
	dead_char.age = 80  # high age guarantees natural death roll would succeed
	dead_char.physical_location = "100"

	var alive_char := L5RCharacterData.new()
	alive_char.character_id = 51
	alive_char.stamina = 2
	alive_char.willpower = 2
	alive_char.wounds_taken = 0
	alive_char.age = 20  # young age = 0% chance of natural death
	alive_char.physical_location = "100"

	var children: Array = []
	var characters: Array = [dead_char, alive_char]
	var next_id: Array = [200]
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_id, _dice, 6480,
	)
	assert_false(50 in result["natural_deaths"],
		"Already dead character should not appear in natural_deaths")


func test_count_clan_population_skips_dead_characters() -> void:
	var alive := L5RCharacterData.new()
	alive.character_id = 60
	alive.clan = "Lion"
	alive.wounds_taken = 0
	alive.stamina = 2
	alive.willpower = 2
	alive.intelligence = 2
	alive.awareness = 2
	alive.reflexes = 2
	alive.void_ring = 2
	alive.perception = 2

	var dead := L5RCharacterData.new()
	dead.character_id = 61
	dead.clan = "Lion"
	dead.wounds_taken = 999
	dead.stamina = 2
	dead.willpower = 2
	dead.intelligence = 2
	dead.awareness = 2
	dead.reflexes = 2
	dead.void_ring = 2
	dead.perception = 2

	var counts: Dictionary = GempukkuSystem.count_clan_population([alive, dead], "Lion")
	var total: int = counts["rank_1"] + counts["rank_2"] + counts["rank_3"] + counts["rank_4"] + counts["rank_5"]
	assert_eq(total, 1, "Dead character should not be counted in population")
