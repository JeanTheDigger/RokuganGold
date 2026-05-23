class_name GempukkuSystem
## Gempukku NPC spawning system per GDD s52, s22.4, s22.7.
## Handles: child-to-character promotion at age 18, school assignment by
## clan/family tendency, population threshold replenishment (Trigger 3),
## procedural name generation, gender/orientation assignment, and natural
## death checks.

const GEMPUKKU_AGE_DAYS: int = 6480  # 18 IC years × 360 days/year


# -- Orientation Distribution (s52 Trigger 2) ---------------------------------

const ORIENTATION_STRAIGHT: int = 85
const ORIENTATION_GAY: int = 10
const ORIENTATION_BISEXUAL: int = 5


static func roll_orientation(dice_engine: DiceEngine) -> String:
	var roll: int = dice_engine.rand_int_range(1, 100)
	if roll <= ORIENTATION_STRAIGHT:
		return "straight"
	if roll <= ORIENTATION_STRAIGHT + ORIENTATION_GAY:
		return "gay"
	return "bisexual"


# -- Gender Distribution (s52 Part 7) -----------------------------------------

const GENDER_WEIGHTS: Dictionary = {
	"default": 55,
	"Matsu Berserker": 20,
	"Daidoji Iron Warrior": 70,
	"Utaku Battle Maiden": 0,
	"Asahina Shugenja": 40,
}


static func roll_gender(dice_engine: DiceEngine, school: String = "") -> String:
	var male_pct: int = GENDER_WEIGHTS.get(school, GENDER_WEIGHTS["default"])
	var roll: int = dice_engine.rand_int_range(1, 100)
	if roll <= male_pct:
		return "male"
	return "female"


static func roll_child_gender(dice_engine: DiceEngine) -> String:
	return roll_gender(dice_engine)


# -- School Assignment (s52 Trigger 2) ----------------------------------------
# Each family has a default school. The lord assigns school at gempukku
# based on clan/family tendency.

const FAMILY_DEFAULT_SCHOOL: Dictionary = {
	"Hida": "Hida Bushi",
	"Hiruma": "Hiruma Bushi",
	"Kaiu": "Kaiu Engineer",
	"Kuni": "Kuni Shugenja",
	"Yasuki": "Yasuki Courtier",
	"Kakita": "Kakita Bushi",
	"Daidoji": "Daidoji Iron Warrior",
	"Doji": "Doji Courtier",
	"Asahina": "Asahina Shugenja",
	"Mirumoto": "Mirumoto Bushi",
	"Kitsuki": "Kitsuki Investigator",
	"Tamori": "Tamori Shugenja",
	"Akodo": "Akodo Bushi",
	"Matsu": "Matsu Berserker",
	"Ikoma": "Ikoma Bard",
	"Kitsu": "Kitsu Shugenja",
	"Shiba": "Shiba Bushi",
	"Isawa": "Isawa Shugenja",
	"Asako": "Asako Loremaster",
	"Bayushi": "Bayushi Bushi",
	"Soshi": "Soshi Shugenja",
	"Shosuro": "Shosuro Infiltrator",
	"Shinjo": "Shinjo Bushi",
	"Moto": "Moto Bushi",
	"Ide": "Ide Emissary",
	"Iuchi": "Iuchi Shugenja",
	"Utaku": "Utaku Battle Maiden",
	"Yoritomo": "Yoritomo Bushi",
	"Moshi": "Moshi Shugenja",
	"Tsuruchi": "Tsuruchi Archer",
}

const GENDER_RESTRICTED_SCHOOLS: Dictionary = {
	"Utaku Battle Maiden": "female",
}


static func assign_school(family: String, gender: String) -> String:
	var school: String = FAMILY_DEFAULT_SCHOOL.get(family, "")
	if school.is_empty():
		return ""
	var restriction: String = GENDER_RESTRICTED_SCHOOLS.get(school, "")
	if not restriction.is_empty() and gender != restriction:
		return _get_fallback_school(family)
	return school


static func _get_fallback_school(family: String) -> String:
	match family:
		"Utaku":
			return "Shinjo Bushi"
	return ""


# -- Name Generation (s52 Part 6) ---------------------------------------------

const NAME_TABLES: Dictionary = {
	"Crab": {
		"male_initial": ["Ya", "Ka", "O", "Hi", "To", "Ku", "Sa", "Ta", "No", "Ha", "Shi", "Mu"],
		"male_middle": ["ki", "su", "ra", "ko", "ta", "ru", "ni", "ma"],
		"male_final": ["mo", "ro", "to", "shi", "ki", "su", "da", "ka", "zu"],
		"female_initial": ["O", "Ya", "Ka", "Hi", "Sa", "Na", "Tsu", "Mi"],
		"female_middle": ["su", "ki", "ru", "na", "ko"],
		"female_final": ["ko", "ru", "shi", "ka", "me", "e", "mi", "na"],
	},
	"Crane": {
		"male_initial": ["Ho", "Ka", "Sa", "Ku", "Yo", "To", "Na", "Ha", "Do", "Shi"],
		"male_middle": ["wa", "tu", "su", "ku", "na", "ri", "shi"],
		"male_final": ["ri", "shi", "na", "wa", "ru", "i", "to", "e", "yu"],
		"female_initial": ["Yo", "Sa", "Ka", "Ha", "Na", "Ki", "Mi", "Tsu", "Shi"],
		"female_middle": ["su", "na", "ki", "wa", "ri"],
		"female_final": ["ko", "me", "e", "ka", "na", "mi", "yo", "ne", "ra"],
	},
	"Dragon": {
		"male_initial": ["Hi", "Sa", "Ka", "To", "Mi", "Na", "U", "Kaze", "Tsu"],
		"male_middle": ["to", "su", "ru", "mi", "na", "ko"],
		"male_final": ["mi", "su", "to", "ru", "shi", "ko", "so", "ka"],
		"female_initial": ["Hi", "Sa", "Ka", "Mi", "Na", "Tsu", "U", "Shi"],
		"female_middle": ["to", "su", "na", "mi", "ru"],
		"female_final": ["mi", "ko", "na", "ka", "e", "ru", "shi", "to"],
	},
	"Lion": {
		"male_initial": ["To", "Gin", "A", "Ka", "Shi", "Ha", "Na", "Ta", "Ma"],
		"male_middle": ["wa", "ka", "ru", "to", "su", "ta"],
		"male_final": ["ri", "wa", "ki", "to", "ru", "shi", "ka", "su"],
		"female_initial": ["Tsu", "Ma", "Ka", "Gin", "Na", "Sa", "A", "Hi"],
		"female_middle": ["su", "ru", "ko", "ta", "na"],
		"female_final": ["ko", "ka", "ru", "me", "na", "e", "shi", "mi"],
	},
	"Phoenix": {
		"male_initial": ["Ta", "Ho", "U", "Shi", "Tsu", "Ka", "Hi", "A", "Mi"],
		"male_middle": ["da", "chi", "ko", "su", "ta", "ru", "na"],
		"male_final": ["ka", "da", "ko", "ru", "na", "shi", "to", "mi"],
		"female_initial": ["Mi", "Sa", "Ka", "Na", "Tsu", "Hi", "A", "Shi"],
		"female_middle": ["su", "na", "ko", "ru", "ki"],
		"female_final": ["ko", "na", "mi", "ka", "e", "ru", "me", "shi"],
	},
	"Scorpion": {
		"male_initial": ["A", "Ba", "Shi", "Ka", "To", "Ku", "Sa", "Ya"],
		"male_middle": ["ra", "mo", "ru", "ku", "shi", "ta"],
		"male_final": ["ro", "ru", "shi", "ku", "to", "mo", "ra", "su"],
		"female_initial": ["Ka", "Sa", "Mi", "Shi", "A", "To", "Ya", "Na"],
		"female_middle": ["chi", "ko", "su", "na", "ru"],
		"female_final": ["ko", "chi", "ka", "mi", "na", "e", "ru", "shi"],
	},
	"Unicorn": {
		"male_initial": ["Ka", "Ta", "Shi", "Mo", "Na", "Chen", "Bao", "To", "U"],
		"male_middle": ["ge", "ta", "su", "ru", "ko", "na"],
		"male_final": ["ge", "su", "ko", "to", "ru", "ka", "shi", "mo"],
		"female_initial": ["Ka", "Mi", "Tsu", "Na", "Sa", "U", "Hi", "Shi"],
		"female_middle": ["mo", "ko", "na", "su", "ru"],
		"female_final": ["ko", "mo", "ka", "mi", "na", "e", "ru", "shi"],
	},
	"Mantis": {
		"male_initial": ["A", "Ku", "Ta", "Hi", "Ka", "To", "Na", "Tsu"],
		"male_middle": ["ra", "su", "mi", "ko", "ru", "ta"],
		"male_final": ["su", "mi", "ko", "ra", "to", "ka", "ru", "shi"],
		"female_initial": ["Mi", "Ka", "Ku", "Hi", "Na", "Tsu", "Sa", "A"],
		"female_middle": ["mi", "ko", "su", "na", "ru"],
		"female_final": ["ko", "mi", "ka", "na", "e", "ru", "me", "shi"],
	},
}


static func generate_name(clan: String, gender: String, dice_engine: DiceEngine) -> String:
	var tables: Dictionary = NAME_TABLES.get(clan, {})
	if tables.is_empty():
		return "Unknown"

	var prefix: String = "male" if gender == "male" else "female"
	var initials: Array = tables.get(prefix + "_initial", [])
	var middles: Array = tables.get(prefix + "_middle", [])
	var finals: Array = tables.get(prefix + "_final", [])

	if initials.is_empty() or finals.is_empty():
		return "Unknown"

	var use_middle: bool = dice_engine.rand_int_range(1, 100) <= 30
	var name: String = initials[dice_engine.rand_int_range(0, initials.size() - 1)] as String

	if use_middle and not middles.is_empty():
		name += middles[dice_engine.rand_int_range(0, middles.size() - 1)] as String

	name += finals[dice_engine.rand_int_range(0, finals.size() - 1)] as String
	return name


# -- Population Thresholds (s52 Part 2 Trigger 3) -----------------------------

const CLAN_POPULATION_THRESHOLDS: Dictionary = {
	"Crab":    {"rank_5": 3, "rank_4": 8, "rank_3": 25, "rank_2": 60, "rank_1": 100},
	"Crane":   {"rank_5": 3, "rank_4": 8, "rank_3": 25, "rank_2": 60, "rank_1": 100},
	"Dragon":  {"rank_5": 1, "rank_4": 3, "rank_3": 10, "rank_2": 25, "rank_1": 40},
	"Lion":    {"rank_5": 4, "rank_4": 10, "rank_3": 30, "rank_2": 80, "rank_1": 130},
	"Phoenix": {"rank_5": 2, "rank_4": 6, "rank_3": 18, "rank_2": 45, "rank_1": 75},
	"Scorpion":{"rank_5": 2, "rank_4": 6, "rank_3": 18, "rank_2": 45, "rank_1": 75},
	"Unicorn": {"rank_5": 2, "rank_4": 6, "rank_3": 18, "rank_2": 45, "rank_1": 75},
	"Mantis":  {"rank_5": 1, "rank_4": 3, "rank_3": 10, "rank_2": 25, "rank_1": 40},
}


static func count_clan_population(
	characters: Array,
	clan: String,
) -> Dictionary:
	var counts: Dictionary = {"rank_5": 0, "rank_4": 0, "rank_3": 0, "rank_2": 0, "rank_1": 0}
	for c: L5RCharacterData in characters:
		if c.clan != clan:
			continue
		if c.wounds_taken > 0:
			if CharacterStats.is_dead(c):
				continue
		var rank: int = CharacterStats.get_insight_rank(c)
		if rank >= 5:
			counts["rank_5"] += 1
		elif rank == 4:
			counts["rank_4"] += 1
		elif rank == 3:
			counts["rank_3"] += 1
		elif rank == 2:
			counts["rank_2"] += 1
		else:
			counts["rank_1"] += 1
	return counts


static func get_replenishment_needed(
	clan: String,
	current_counts: Dictionary,
) -> int:
	var thresholds: Dictionary = CLAN_POPULATION_THRESHOLDS.get(clan, {})
	if thresholds.is_empty():
		return 0
	var rank_1_min: int = thresholds.get("rank_1", 0)
	var rank_1_current: int = current_counts.get("rank_1", 0)
	if rank_1_current < rank_1_min:
		return rank_1_min - rank_1_current
	return 0


# -- Natural Death (s52 Part 4) -----------------------------------------------

const NATURAL_DEATH_CHANCES: Array[Array] = [
	[50, 0],
	[65, 1],
	[75, 3],
	[85, 8],
	[999, 20],
]


static func get_natural_death_chance(age: int) -> int:
	if age < 50:
		return 0
	for bracket: Array in NATURAL_DEATH_CHANCES:
		if age < bracket[0] as int:
			return bracket[1] as int
	return 20


static func roll_natural_death(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	worship_malus: Dictionary = {},
) -> bool:
	var chance: int = get_natural_death_chance(character.age)
	if worship_malus.get("natural_death_increase", false):
		chance = ceili(float(chance) * 1.5)
	if worship_malus.get("aging_accelerated", false):
		chance = ceili(float(chance) * 2.0)
	if chance <= 0:
		return false
	var roll: int = dice_engine.rand_int_range(1, 100)
	return roll <= chance


# -- Gempukku Processing (s52 Trigger 2) --------------------------------------

static func process_gempukku(
	child: ChildRecord,
	next_character_id: int,
	dice_engine: DiceEngine,
	ic_day: int,
) -> L5RCharacterData:
	if not child.is_alive:
		return null
	if not child.is_gempukku_ready(ic_day):
		return null

	var school: String = assign_school(child.family, child.gender)
	if school.is_empty():
		return null

	var character: L5RCharacterData = WorldGenerator.generate_character(
		next_character_id,
		child.child_name,
		child.clan,
		child.family,
		school,
		1,
		dice_engine,
		child.gender,
	)
	character.orientation = child.orientation
	character.mother_id = child.mother_id
	character.father_id = child.father_id
	return character


# -- Birth Helper (s52 Trigger 2) ---------------------------------------------

static func create_child_at_birth(
	child_id: int,
	father: L5RCharacterData,
	mother: L5RCharacterData,
	clan: String,
	family: String,
	ic_day: int,
	dice_engine: DiceEngine,
) -> ChildRecord:
	var child := ChildRecord.new()
	child.child_id = child_id
	child.father_id = father.character_id
	child.mother_id = mother.character_id
	child.clan = clan
	child.family = family
	child.ic_day_born = ic_day
	child.gender = roll_child_gender(dice_engine)
	child.orientation = roll_orientation(dice_engine)
	child.child_name = generate_name(clan, child.gender, dice_engine)
	return child


# -- Replenishment (s52 Trigger 3) --------------------------------------------

static func generate_replenishment_character(
	next_character_id: int,
	clan: String,
	dice_engine: DiceEngine,
) -> L5RCharacterData:
	var families: Array = _get_clan_families(clan)
	if families.is_empty():
		return null

	var family: String = families[dice_engine.rand_int_range(0, families.size() - 1)] as String
	var gender: String = roll_gender(dice_engine)
	var school: String = assign_school(family, gender)
	if school.is_empty():
		gender = "female" if gender == "male" else "male"
		school = assign_school(family, gender)
	if school.is_empty():
		return null

	var name: String = generate_name(clan, gender, dice_engine)
	var character: L5RCharacterData = WorldGenerator.generate_character(
		next_character_id,
		name,
		clan,
		family,
		school,
		1,
		dice_engine,
		gender,
	)
	character.orientation = roll_orientation(dice_engine)
	return character


static func _get_clan_families(clan: String) -> Array:
	match clan:
		"Crab":
			return ["Hida", "Hiruma", "Kaiu", "Kuni", "Yasuki"]
		"Crane":
			return ["Kakita", "Daidoji", "Doji", "Asahina"]
		"Dragon":
			return ["Mirumoto", "Kitsuki", "Tamori"]
		"Lion":
			return ["Akodo", "Matsu", "Ikoma", "Kitsu"]
		"Phoenix":
			return ["Shiba", "Isawa", "Asako"]
		"Scorpion":
			return ["Bayushi", "Soshi", "Shosuro"]
		"Unicorn":
			return ["Shinjo", "Moto", "Ide", "Iuchi", "Utaku"]
		"Mantis":
			return ["Yoritomo", "Moshi", "Tsuruchi"]
	return []


# -- Season-Boundary Entry Point -----------------------------------------------

static func process_seasonal_gempukku(
	children: Array,
	characters: Array,
	next_character_id: Array,
	dice_engine: DiceEngine,
	ic_day: int,
	worship_maluses: Dictionary = {},
	settlement_province_map: Dictionary = {},
) -> Dictionary:
	var results: Dictionary = {
		"new_characters": [],
		"graduated_child_ids": [],
		"replenishment_characters": [],
		"natural_deaths": [],
		"musha_shugyo_triggered": [],
	}

	for child: ChildRecord in children:
		if not child.is_gempukku_ready(ic_day):
			continue
		var character: L5RCharacterData = process_gempukku(
			child, next_character_id[0], dice_engine, ic_day,
		)
		if character == null:
			continue
		next_character_id[0] += 1
		results["new_characters"].append(character)
		results["graduated_child_ids"].append(child.child_id)

		if MushaShugyo.evaluate_at_gempukku(character, dice_engine, ic_day):
			results["musha_shugyo_triggered"].append(character.character_id)

	var all_characters: Array = characters.duplicate()
	for nc: L5RCharacterData in results["new_characters"]:
		all_characters.append(nc)

	for clan: String in CLAN_POPULATION_THRESHOLDS:
		var counts: Dictionary = count_clan_population(all_characters, clan)
		var needed: int = get_replenishment_needed(clan, counts)
		for i: int in range(needed):
			var rc: L5RCharacterData = generate_replenishment_character(
				next_character_id[0], clan, dice_engine,
			)
			if rc == null:
				continue
			next_character_id[0] += 1
			results["replenishment_characters"].append(rc)
			all_characters.append(rc)

	for character: L5RCharacterData in characters:
		if CharacterStats.is_dead(character):
			continue
		var char_province: int = settlement_province_map.get(
			int(character.physical_location) if character.physical_location.is_valid_int() else -1, -1,
		)
		var char_malus: Dictionary = worship_maluses.get(char_province, {})
		if roll_natural_death(character, dice_engine, char_malus):
			results["natural_deaths"].append(character.character_id)

	return results
