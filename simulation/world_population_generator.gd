class_name WorldPopulationGenerator
## One-time world population pass per GDD s52 Part 1, s22.4, s22.8.
## Fills every named position in the world at game start.
## After this pass, all new characters enter at Rank 1 via GempukkuSystem.


# -- Clan / Family Data -------------------------------------------------------

const GREAT_CLANS: Array[String] = [
	"Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn",
]

const CLAN_FAMILIES: Dictionary = {
	"Crab": ["Hida", "Hiruma", "Kaiu", "Kuni", "Yasuki", "Toritaka"],
	"Crane": ["Kakita", "Daidoji", "Doji", "Asahina"],
	"Dragon": ["Mirumoto", "Kitsuki", "Tamori", "Togashi"],
	"Lion": ["Akodo", "Matsu", "Ikoma", "Kitsu"],
	"Phoenix": ["Shiba", "Isawa", "Asako", "Agasha"],
	"Scorpion": ["Bayushi", "Soshi", "Shosuro", "Yogo"],
	"Unicorn": ["Shinjo", "Moto", "Ide", "Iuchi", "Utaku"],
	"Mantis": ["Yoritomo", "Moshi", "Tsuruchi"],
	"Imperial": ["Otomo", "Seppun", "Miya"],
	"Badger": ["Ichiro"],
	"Dragonfly": ["Tonbo"],
	"Fox": ["Kitsune"],
	"Hare": ["Usagi"],
	"Monkey": ["Toku"],
	"Ox": ["Morito"],
	"Sparrow": ["Suzume"],
	"Tortoise": ["Kasuga"],
	"Wasp": ["Tsuruchi"],
	"Centipede": ["Moshi"],
	"Bat": ["Komori"],
	"Oriole": ["Tsi"],
}

const MINOR_CLANS: Array[String] = [
	"Badger", "Bat", "Centipede", "Dragonfly",
	"Fox", "Hare", "Monkey", "Oriole", "Ox",
	"Sparrow", "Tortoise", "Wasp",
]


# -- Position Definitions (s22.8) ---------------------------------------------

enum PositionType {
	EMPEROR,
	IMPERIAL_HEIR,
	IMPERIAL_ADVISOR,
	IMPERIAL_CHANCELLOR,
	IMPERIAL_HERALD,
	IMPERIAL_TREASURER,
	VOICE_OF_EMPEROR,
	EMERALD_CHAMPION,
	JADE_CHAMPION,
	AMETHYST_CHAMPION,
	TURQUOISE_CHAMPION,
	TOPAZ_CHAMPION,
	RUBY_CHAMPION,
	IMPERIAL_FAMILY_DAIMYO,
	CLAN_CHAMPION,
	FAMILY_DAIMYO,
	RIKUGUNSHOKAN,
	SENIOR_COURTIER,
	CLAN_MAGISTRATE_COMMANDER,
	SCHOOL_MASTER,
	PROVINCIAL_DAIMYO,
	LOCAL_DAIMYO,
	CLAN_MAGISTRATE,
	GARRISON_COMMANDER,
	TAISA,
	CHUI,
	TEMPLE_HEAD,
	MONASTERY_ABBOT,
	EMERALD_MAGISTRATE,
	JADE_MAGISTRATE,
	INQUISITOR_LEADER,
	WITCH_HUNTER_LEADER,
	KUROIBAN_LEADER,
	YORIKI,
	MINOR_CLAN_CHAMPION,
	MINOR_CLAN_SENIOR,
	WALL_SEGMENT_COMMANDER,
	HIRUMA_SCOUT_COMMANDER,
	SAMURAI,
}

const POSITION_RANK: Dictionary = {
	PositionType.EMPEROR: 6,
	PositionType.IMPERIAL_HEIR: 5,
	PositionType.IMPERIAL_ADVISOR: 5,
	PositionType.IMPERIAL_CHANCELLOR: 5,
	PositionType.IMPERIAL_HERALD: 4,
	PositionType.IMPERIAL_TREASURER: 4,
	PositionType.VOICE_OF_EMPEROR: 4,
	PositionType.EMERALD_CHAMPION: 5,
	PositionType.JADE_CHAMPION: 5,
	PositionType.AMETHYST_CHAMPION: 4,
	PositionType.TURQUOISE_CHAMPION: 4,
	PositionType.TOPAZ_CHAMPION: 3,
	PositionType.RUBY_CHAMPION: 4,
	PositionType.IMPERIAL_FAMILY_DAIMYO: 4,
	PositionType.CLAN_CHAMPION: 5,
	PositionType.FAMILY_DAIMYO: 4,
	PositionType.RIKUGUNSHOKAN: 4,
	PositionType.SENIOR_COURTIER: 4,
	PositionType.CLAN_MAGISTRATE_COMMANDER: 3,
	PositionType.SCHOOL_MASTER: 4,
	PositionType.PROVINCIAL_DAIMYO: 3,
	PositionType.LOCAL_DAIMYO: 2,
	PositionType.CLAN_MAGISTRATE: 2,
	PositionType.GARRISON_COMMANDER: 2,
	PositionType.TAISA: 3,
	PositionType.CHUI: 2,
	PositionType.TEMPLE_HEAD: 3,
	PositionType.MONASTERY_ABBOT: 3,
	PositionType.EMERALD_MAGISTRATE: 3,
	PositionType.JADE_MAGISTRATE: 3,
	PositionType.INQUISITOR_LEADER: 3,
	PositionType.WITCH_HUNTER_LEADER: 3,
	PositionType.KUROIBAN_LEADER: 3,
	PositionType.YORIKI: 2,
	PositionType.MINOR_CLAN_CHAMPION: 4,
	PositionType.MINOR_CLAN_SENIOR: 3,
	PositionType.WALL_SEGMENT_COMMANDER: 3,
	PositionType.HIRUMA_SCOUT_COMMANDER: 3,
	PositionType.SAMURAI: 1,
}

const POSITION_STATUS: Dictionary = {
	PositionType.EMPEROR: 10.0,
	PositionType.IMPERIAL_HEIR: 8.0,
	PositionType.IMPERIAL_ADVISOR: 7.0,
	PositionType.IMPERIAL_CHANCELLOR: 7.0,
	PositionType.IMPERIAL_HERALD: 6.5,
	PositionType.IMPERIAL_TREASURER: 6.5,
	PositionType.VOICE_OF_EMPEROR: 6.5,
	PositionType.EMERALD_CHAMPION: 7.5,
	PositionType.JADE_CHAMPION: 7.0,
	PositionType.AMETHYST_CHAMPION: 6.0,
	PositionType.TURQUOISE_CHAMPION: 6.0,
	PositionType.TOPAZ_CHAMPION: 5.0,
	PositionType.RUBY_CHAMPION: 6.0,
	PositionType.IMPERIAL_FAMILY_DAIMYO: 6.0,
	PositionType.CLAN_CHAMPION: 8.0,
	PositionType.FAMILY_DAIMYO: 6.0,
	PositionType.RIKUGUNSHOKAN: 5.5,
	PositionType.SENIOR_COURTIER: 5.0,
	PositionType.CLAN_MAGISTRATE_COMMANDER: 4.5,
	PositionType.SCHOOL_MASTER: 5.0,
	PositionType.PROVINCIAL_DAIMYO: 4.0,
	PositionType.LOCAL_DAIMYO: 3.0,
	PositionType.CLAN_MAGISTRATE: 3.0,
	PositionType.GARRISON_COMMANDER: 2.5,
	PositionType.TAISA: 3.5,
	PositionType.CHUI: 2.5,
	PositionType.TEMPLE_HEAD: 3.5,
	PositionType.MONASTERY_ABBOT: 3.5,
	PositionType.EMERALD_MAGISTRATE: 4.0,
	PositionType.JADE_MAGISTRATE: 4.0,
	PositionType.INQUISITOR_LEADER: 4.0,
	PositionType.WITCH_HUNTER_LEADER: 4.0,
	PositionType.KUROIBAN_LEADER: 4.0,
	PositionType.YORIKI: 2.0,
	PositionType.MINOR_CLAN_CHAMPION: 5.0,
	PositionType.MINOR_CLAN_SENIOR: 3.5,
	PositionType.WALL_SEGMENT_COMMANDER: 3.5,
	PositionType.HIRUMA_SCOUT_COMMANDER: 3.5,
	PositionType.SAMURAI: 1.0,
}


const POSITION_ROLE_NAMES: Dictionary = {
	PositionType.EMPEROR: "Emperor",
	PositionType.IMPERIAL_HEIR: "Imperial Heir",
	PositionType.IMPERIAL_ADVISOR: "Imperial Advisor",
	PositionType.IMPERIAL_CHANCELLOR: "Imperial Chancellor",
	PositionType.IMPERIAL_HERALD: "Imperial Herald",
	PositionType.IMPERIAL_TREASURER: "Imperial Treasurer",
	PositionType.VOICE_OF_EMPEROR: "Voice of the Emperor",
	PositionType.EMERALD_CHAMPION: "Emerald Champion",
	PositionType.JADE_CHAMPION: "Jade Champion",
	PositionType.AMETHYST_CHAMPION: "Amethyst Champion",
	PositionType.TURQUOISE_CHAMPION: "Turquoise Champion",
	PositionType.TOPAZ_CHAMPION: "Topaz Champion",
	PositionType.RUBY_CHAMPION: "Ruby Champion",
	PositionType.IMPERIAL_FAMILY_DAIMYO: "Imperial Family Daimyo",
	PositionType.CLAN_CHAMPION: "Clan Champion",
	PositionType.FAMILY_DAIMYO: "Family Daimyo",
	PositionType.RIKUGUNSHOKAN: "Rikugunshokan",
	PositionType.SENIOR_COURTIER: "Senior Courtier",
	PositionType.CLAN_MAGISTRATE_COMMANDER: "Clan Magistrate Commander",
	PositionType.SCHOOL_MASTER: "School Master",
	PositionType.PROVINCIAL_DAIMYO: "Provincial Daimyo",
	PositionType.LOCAL_DAIMYO: "Local Daimyo",
	PositionType.CLAN_MAGISTRATE: "Clan Magistrate",
	PositionType.GARRISON_COMMANDER: "Garrison Commander",
	PositionType.TAISA: "Taisa",
	PositionType.CHUI: "Chui",
	PositionType.TEMPLE_HEAD: "Temple Head",
	PositionType.MONASTERY_ABBOT: "Monastery Abbot",
	PositionType.EMERALD_MAGISTRATE: "Emerald Magistrate",
	PositionType.JADE_MAGISTRATE: "Jade Magistrate",
	PositionType.INQUISITOR_LEADER: "Inquisitor Leader",
	PositionType.WITCH_HUNTER_LEADER: "Witch Hunter Leader",
	PositionType.KUROIBAN_LEADER: "Kuroiban Leader",
	PositionType.YORIKI: "Yoriki",
	PositionType.MINOR_CLAN_CHAMPION: "Minor Clan Champion",
	PositionType.MINOR_CLAN_SENIOR: "Minor Clan Senior",
	PositionType.WALL_SEGMENT_COMMANDER: "Wall Segment Commander",
	PositionType.HIRUMA_SCOUT_COMMANDER: "Hiruma Scout Commander",
}

const POSITION_MILITARY_RANK: Dictionary = {
	PositionType.RIKUGUNSHOKAN: Enums.MilitaryRank.RIKUGUNSHOKAN,
	PositionType.TAISA: Enums.MilitaryRank.TAISA,
	PositionType.CHUI: Enums.MilitaryRank.CHUI,
	PositionType.GARRISON_COMMANDER: Enums.MilitaryRank.GUNSO,
	PositionType.WALL_SEGMENT_COMMANDER: Enums.MilitaryRank.CHUI,
}


# -- Position School Type Preferences -----------------------------------------

const BUSHI_POSITION_TYPES: Array[int] = [
	PositionType.EMERALD_CHAMPION,
	PositionType.JADE_CHAMPION,
	PositionType.RIKUGUNSHOKAN,
	PositionType.GARRISON_COMMANDER,
	PositionType.TAISA,
	PositionType.CHUI,
	PositionType.WALL_SEGMENT_COMMANDER,
	PositionType.HIRUMA_SCOUT_COMMANDER,
	PositionType.MINOR_CLAN_CHAMPION,
]

const COURTIER_POSITION_TYPES: Array[int] = [
	PositionType.IMPERIAL_ADVISOR,
	PositionType.IMPERIAL_CHANCELLOR,
	PositionType.IMPERIAL_HERALD,
	PositionType.IMPERIAL_TREASURER,
	PositionType.VOICE_OF_EMPEROR,
	PositionType.SENIOR_COURTIER,
	PositionType.EMERALD_MAGISTRATE,
]

const SHUGENJA_POSITION_TYPES: Array[int] = [
	PositionType.JADE_MAGISTRATE,
	PositionType.TEMPLE_HEAD,
]


# -- Population Multiplier (s52) -----------------------------------------------
# Healthy game start is ~3-4x the minimum threshold. Per-rank targets.

const POPULATION_MULTIPLIER: float = 3.0

const RANK_DISTRIBUTION: Dictionary = {
	"Crab": {5: 9, 4: 24, 3: 75, 2: 180, 1: 300},
	"Crane": {5: 9, 4: 24, 3: 75, 2: 180, 1: 300},
	"Dragon": {5: 3, 4: 9, 3: 30, 2: 75, 1: 120},
	"Lion": {5: 12, 4: 30, 3: 90, 2: 240, 1: 390},
	"Phoenix": {5: 6, 4: 18, 3: 54, 2: 135, 1: 225},
	"Scorpion": {5: 6, 4: 18, 3: 54, 2: 135, 1: 225},
	"Unicorn": {5: 6, 4: 18, 3: 54, 2: 135, 1: 225},
	"Mantis": {5: 3, 4: 9, 3: 30, 2: 75, 1: 120},
}


# -- Military Hierarchy Constants (from MilitaryHierarchy) ---------------------

const CLAN_ARMY_COUNT: Dictionary = {
	"Crab": 4, "Crane": 2, "Dragon": 2, "Lion": 4,
	"Mantis": 3, "Phoenix": 1, "Scorpion": 1, "Unicorn": 3,
	"Imperial": 1,
}

const LEGIONS_PER_ARMY: int = 3
const COMPANIES_PER_LEGION: int = 7


# -- School Selection by Position Type -----------------------------------------

static func _get_school_for_position(
	position_type: int,
	clan: String,
	family: String,
	dice: DiceEngine,
) -> String:
	if position_type in BUSHI_POSITION_TYPES:
		return _get_bushi_school(clan, family)
	if position_type in COURTIER_POSITION_TYPES:
		return _get_courtier_school(clan, family)
	if position_type in SHUGENJA_POSITION_TYPES:
		return _get_shugenja_school(clan, family)
	if position_type == PositionType.MONASTERY_ABBOT:
		return _get_shugenja_school(clan, family)
	if position_type == PositionType.SCHOOL_MASTER:
		return GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(family, "")
	if position_type == PositionType.CLAN_MAGISTRATE:
		var roll: int = dice.rand_int_range(1, 3)
		if roll == 1:
			return _get_courtier_school(clan, family)
		return _get_bushi_school(clan, family)
	return GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(family, "")


static func _get_bushi_school(clan: String, family: String) -> String:
	var school: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(family, "")
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	if not sd.is_empty() and sd["type"] == Enums.SchoolType.BUSHI:
		return school
	var families: Array = CLAN_FAMILIES.get(clan, [])
	for f: String in families:
		var s: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(f, "")
		var d: Dictionary = WorldGenerator.SCHOOL_DATA.get(s, {})
		if not d.is_empty() and d["type"] == Enums.SchoolType.BUSHI:
			return s
	return school


static func _get_courtier_school(clan: String, family: String) -> String:
	var school: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(family, "")
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	if not sd.is_empty() and sd["type"] == Enums.SchoolType.COURTIER:
		return school
	var families: Array = CLAN_FAMILIES.get(clan, [])
	for f: String in families:
		var s: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(f, "")
		var d: Dictionary = WorldGenerator.SCHOOL_DATA.get(s, {})
		if not d.is_empty() and d["type"] == Enums.SchoolType.COURTIER:
			return s
	return school


static func _get_shugenja_school(clan: String, family: String) -> String:
	var school: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(family, "")
	var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(school, {})
	if not sd.is_empty() and sd["type"] == Enums.SchoolType.SHUGENJA:
		return school
	var families: Array = CLAN_FAMILIES.get(clan, [])
	for f: String in families:
		var s: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(f, "")
		var d: Dictionary = WorldGenerator.SCHOOL_DATA.get(s, {})
		if not d.is_empty() and d["type"] == Enums.SchoolType.SHUGENJA:
			return s
	return school


# -- Character Generation Helper -----------------------------------------------

static func _generate_positioned_character(
	next_id: Array,
	position_type: int,
	clan: String,
	family: String,
	dice: DiceEngine,
	lord_id: int = -1,
) -> L5RCharacterData:
	var rank: int = POSITION_RANK.get(position_type, 1)
	var status: float = POSITION_STATUS.get(position_type, 1.0)
	var school: String = _get_school_for_position(position_type, clan, family, dice)
	if school.is_empty():
		school = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(family, "")

	var gender: String = GempukkuSystem.roll_gender(dice, school)
	var name: String = GempukkuSystem.generate_name(clan, gender, dice)

	var char_id: int = next_id[0]
	next_id[0] += 1

	var c: L5RCharacterData = WorldGenerator.generate_character(
		char_id, name, clan, family, school, rank, dice, gender,
	)
	c.status = status
	c.lord_id = lord_id
	c.orientation = GempukkuSystem.roll_orientation(dice)
	c.role_position = POSITION_ROLE_NAMES.get(position_type, "")
	c.military_rank = POSITION_MILITARY_RANK.get(position_type, Enums.MilitaryRank.NONE)
	return c


static func _pick_family(clan: String, dice: DiceEngine) -> String:
	var families: Array = CLAN_FAMILIES.get(clan, [])
	if families.is_empty():
		return ""
	return families[dice.rand_int_range(0, families.size() - 1)]


# -- Step 1-2: Imperial Positions (s22.8) --------------------------------------

static func _generate_imperial_positions(
	next_id: Array,
	dice: DiceEngine,
) -> Dictionary:
	var chars: Array = []

	var emperor: L5RCharacterData = _generate_positioned_character(
		next_id, PositionType.EMPEROR, "Imperial", "Seppun", dice,
	)
	emperor.lord_id = -1
	chars.append(emperor)
	var emperor_id: int = emperor.character_id

	chars.append(_generate_positioned_character(
		next_id, PositionType.IMPERIAL_HEIR, "Imperial", "Seppun", dice, emperor_id,
	))

	var imp_positions: Array = [
		[PositionType.IMPERIAL_ADVISOR, "Otomo"],
		[PositionType.IMPERIAL_CHANCELLOR, "Otomo"],
		[PositionType.IMPERIAL_HERALD, "Miya"],
		[PositionType.IMPERIAL_TREASURER, "Otomo"],
		[PositionType.VOICE_OF_EMPEROR, "Seppun"],
	]
	var herald_id: int = -1
	for pos: Array in imp_positions:
		var imp_char: L5RCharacterData = _generate_positioned_character(
			next_id, pos[0], "Imperial", pos[1], dice, emperor_id,
		)
		chars.append(imp_char)
		if pos[0] == PositionType.IMPERIAL_HERALD:
			herald_id = imp_char.character_id

	var champion_clans: Array = [
		[PositionType.EMERALD_CHAMPION, "Crane", "Kakita"],
		[PositionType.JADE_CHAMPION, "Crab", "Kuni"],
		[PositionType.AMETHYST_CHAMPION, "Scorpion", "Bayushi"],
		[PositionType.TURQUOISE_CHAMPION, "Unicorn", "Ide"],
		[PositionType.TOPAZ_CHAMPION, "Lion", "Akodo"],
		[PositionType.RUBY_CHAMPION, "Crane", "Daidoji"],
	]
	for info: Array in champion_clans:
		chars.append(_generate_positioned_character(
			next_id, info[0], info[1], info[2], dice, emperor_id,
		))

	var imp_families: Array = ["Seppun", "Otomo", "Miya"]
	for fam: String in imp_families:
		chars.append(_generate_positioned_character(
			next_id, PositionType.IMPERIAL_FAMILY_DAIMYO,
			"Imperial", fam, dice, emperor_id,
		))

	return {"characters": chars, "emperor_id": emperor_id, "herald_id": herald_id}


# -- Step 2: Per-Clan Fixed Positions (s22.8) ----------------------------------

static func _generate_clan_leadership(
	clan: String,
	next_id: Array,
	dice: DiceEngine,
) -> Array:
	var chars: Array = []
	var families: Array = CLAN_FAMILIES.get(clan, [])
	if families.is_empty():
		return chars

	var champion: L5RCharacterData = _generate_positioned_character(
		next_id, PositionType.CLAN_CHAMPION, clan, families[0], dice,
	)
	champion.lord_id = -1
	chars.append(champion)
	var champ_id: int = champion.character_id

	for fam: String in families:
		var fd: L5RCharacterData = _generate_positioned_character(
			next_id, PositionType.FAMILY_DAIMYO, clan, fam, dice, champ_id,
		)
		chars.append(fd)

	chars.append(_generate_positioned_character(
		next_id, PositionType.RIKUGUNSHOKAN, clan, families[0], dice, champ_id,
	))

	var courtier_fam: String = families[0]
	for f: String in families:
		var s: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(f, "")
		var sd: Dictionary = WorldGenerator.SCHOOL_DATA.get(s, {})
		if not sd.is_empty() and sd["type"] == Enums.SchoolType.COURTIER:
			courtier_fam = f
			break
	chars.append(_generate_positioned_character(
		next_id, PositionType.SENIOR_COURTIER, clan, courtier_fam, dice, champ_id,
	))

	chars.append(_generate_positioned_character(
		next_id, PositionType.CLAN_MAGISTRATE_COMMANDER, clan, families[0], dice, champ_id,
	))

	for fam: String in families:
		var school: String = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(fam, "")
		if school.is_empty():
			continue
		if not WorldGenerator.SCHOOL_DATA.has(school):
			continue
		chars.append(_generate_positioned_character(
			next_id, PositionType.SCHOOL_MASTER, clan, fam, dice, champ_id,
		))

	if clan == "Phoenix":
		var master_elements: Array = ["Fire", "Water", "Air", "Earth", "Void"]
		for element: String in master_elements:
			var master: L5RCharacterData = _generate_positioned_character(
				next_id, PositionType.SENIOR_COURTIER, "Phoenix", "Isawa", dice, champ_id,
			)
			master.role_position = "Master of " + element
			master.school_type = Enums.SchoolType.SHUGENJA
			master.status = 7.0
			chars.append(master)

	return chars


# -- Step 2: Military Positions (s22.8) ----------------------------------------

static func _generate_military_commanders(
	clan: String,
	rikugunshokan_id: int,
	next_id: Array,
	dice: DiceEngine,
) -> Array:
	var chars: Array = []
	var army_count: int = CLAN_ARMY_COUNT.get(clan, 0)
	var families: Array = CLAN_FAMILIES.get(clan, [])
	if families.is_empty() or army_count == 0:
		return chars

	for _a: int in range(army_count):
		for _l: int in range(LEGIONS_PER_ARMY):
			var fam: String = families[dice.rand_int_range(0, families.size() - 1)]
			var taisa: L5RCharacterData = _generate_positioned_character(
				next_id, PositionType.TAISA, clan, fam, dice, rikugunshokan_id,
			)
			chars.append(taisa)

			for _c: int in range(COMPANIES_PER_LEGION):
				fam = families[dice.rand_int_range(0, families.size() - 1)]
				chars.append(_generate_positioned_character(
					next_id, PositionType.CHUI, clan, fam, dice, taisa.character_id,
				))

	return chars


# -- Step 2: Province-Scaled Positions -----------------------------------------

static func _generate_province_positions(
	province: ProvinceData,
	settlements: Array,
	clan: String,
	family_daimyo_id: int,
	next_id: Array,
	dice: DiceEngine,
) -> Array:
	var chars: Array = []
	var families: Array = CLAN_FAMILIES.get(clan, [])
	if families.is_empty():
		return chars

	var fam: String = families[dice.rand_int_range(0, families.size() - 1)]
	var prov_daimyo: L5RCharacterData = _generate_positioned_character(
		next_id, PositionType.PROVINCIAL_DAIMYO, clan, fam, dice, family_daimyo_id,
	)
	chars.append(prov_daimyo)

	fam = families[dice.rand_int_range(0, families.size() - 1)]
	chars.append(_generate_positioned_character(
		next_id, PositionType.CLAN_MAGISTRATE, clan, fam, dice, prov_daimyo.character_id,
	))

	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.CITY or s.settlement_type == Enums.SettlementType.TOWN:
			fam = families[dice.rand_int_range(0, families.size() - 1)]
			chars.append(_generate_positioned_character(
				next_id, PositionType.LOCAL_DAIMYO, clan, fam, dice, prov_daimyo.character_id,
			))
		if s.garrison_pu > 0:
			fam = families[dice.rand_int_range(0, families.size() - 1)]
			chars.append(_generate_positioned_character(
				next_id, PositionType.GARRISON_COMMANDER, clan, fam, dice, prov_daimyo.character_id,
			))
		if s.settlement_type == Enums.SettlementType.TEMPLE or s.settlement_type == Enums.SettlementType.SHINDEN:
			fam = families[dice.rand_int_range(0, families.size() - 1)]
			chars.append(_generate_positioned_character(
				next_id, PositionType.TEMPLE_HEAD, clan, fam, dice, prov_daimyo.character_id,
			))
		if s.settlement_type == Enums.SettlementType.MONASTERY:
			fam = families[dice.rand_int_range(0, families.size() - 1)]
			chars.append(_generate_positioned_character(
				next_id, PositionType.MONASTERY_ABBOT, clan, fam, dice, prov_daimyo.character_id,
			))

	return chars


# -- Step 2: Magistrate System (s22.8) ----------------------------------------

static func _generate_magistrate_system(
	next_id: Array,
	dice: DiceEngine,
	emperor_id: int,
) -> Array:
	var chars: Array = []

	for _i: int in range(3):
		chars.append(_generate_positioned_character(
			next_id, PositionType.INQUISITOR_LEADER, "Phoenix", "Asako", dice, emperor_id,
		))
	for _i: int in range(3):
		chars.append(_generate_positioned_character(
			next_id, PositionType.WITCH_HUNTER_LEADER, "Crab", "Kuni", dice, emperor_id,
		))
	for _i: int in range(2):
		chars.append(_generate_positioned_character(
			next_id, PositionType.KUROIBAN_LEADER, "Scorpion", "Soshi", dice, emperor_id,
		))

	return chars


# -- Step 2: Minor Clan Positions (s22.8) --------------------------------------

static func _generate_minor_clan_characters(
	next_id: Array,
	dice: DiceEngine,
) -> Array:
	var chars: Array = []
	for mc: String in MINOR_CLANS:
		var families: Array = CLAN_FAMILIES.get(mc, [])
		if families.is_empty():
			continue
		var primary_family: String = families[0]
		var champ: L5RCharacterData = _generate_positioned_character(
			next_id, PositionType.MINOR_CLAN_CHAMPION, mc, primary_family, dice,
		)
		champ.lord_id = -1
		chars.append(champ)
		chars.append(_generate_positioned_character(
			next_id, PositionType.MINOR_CLAN_SENIOR, mc, primary_family, dice, champ.character_id,
		))
	return chars


# -- Step 2: Kaiu Wall (s22.8) ------------------------------------------------

static func _generate_wall_characters(
	next_id: Array,
	dice: DiceEngine,
	crab_rikugunshokan_id: int,
) -> Array:
	var chars: Array = []
	for _i: int in range(4):
		chars.append(_generate_positioned_character(
			next_id, PositionType.WALL_SEGMENT_COMMANDER,
			"Crab", "Kaiu", dice, crab_rikugunshokan_id,
		))
	chars.append(_generate_positioned_character(
		next_id, PositionType.HIRUMA_SCOUT_COMMANDER,
		"Crab", "Hiruma", dice, crab_rikugunshokan_id,
	))
	return chars


# -- Step 3: Rank-Filling Samurai (s52 Trigger 3) ------------------------------

static func _generate_rank_filling(
	clan: String,
	existing_count_by_rank: Dictionary,
	next_id: Array,
	dice: DiceEngine,
) -> Array:
	var chars: Array = []
	var targets: Dictionary = RANK_DISTRIBUTION.get(clan, {})
	if targets.is_empty():
		return chars

	for rank: int in [5, 4, 3, 2, 1]:
		var target: int = targets.get(rank, 0)
		var current: int = existing_count_by_rank.get(rank, 0)
		var deficit: int = target - current
		for _i: int in range(deficit):
			var fam: String = _pick_family(clan, dice)
			var school: String = GempukkuSystem.assign_school(
				fam, GempukkuSystem.roll_gender(dice),
			)
			if school.is_empty():
				school = GempukkuSystem.FAMILY_DEFAULT_SCHOOL.get(fam, "")
			var gender: String = GempukkuSystem.roll_gender(dice, school)
			var name: String = GempukkuSystem.generate_name(clan, gender, dice)
			var char_id: int = next_id[0]
			next_id[0] += 1
			var c: L5RCharacterData = WorldGenerator.generate_character(
				char_id, name, clan, fam, school, rank, dice, gender,
			)
			c.orientation = GempukkuSystem.roll_orientation(dice)
			chars.append(c)

	return chars


# -- Step 3b: Lord ID Assignment ------------------------------------------------

static func _assign_lord_ids(
	characters: Array,
	clan_champions: Dictionary,
) -> void:
	var family_daimyos: Dictionary = {}
	var provincial_daimyos_by_clan: Dictionary = {}

	for c: L5RCharacterData in characters:
		if c.role_position == "Family Daimyo":
			var key: String = "%s_%s" % [c.clan, c.family]
			family_daimyos[key] = c.character_id
		elif c.role_position == "Provincial Daimyo":
			if not provincial_daimyos_by_clan.has(c.clan):
				provincial_daimyos_by_clan[c.clan] = []
			provincial_daimyos_by_clan[c.clan].append(c.character_id)

	var prov_idx: Dictionary = {}

	for c: L5RCharacterData in characters:
		if c.lord_id >= 0:
			continue
		if not c.role_position.is_empty():
			continue

		var fd_key: String = "%s_%s" % [c.clan, c.family]
		var fd_id: int = family_daimyos.get(fd_key, -1)
		if fd_id < 0:
			for k: String in family_daimyos:
				if k.begins_with(c.clan + "_"):
					fd_id = family_daimyos[k]
					break
		if fd_id < 0:
			fd_id = clan_champions.get(c.clan, -1)
		if fd_id < 0:
			continue

		var prov_daimyos: Array = provincial_daimyos_by_clan.get(c.clan, [])
		if prov_daimyos.is_empty():
			c.lord_id = fd_id
		else:
			var idx: int = prov_idx.get(c.clan, 0)
			c.lord_id = prov_daimyos[idx % prov_daimyos.size()]
			prov_idx[c.clan] = idx + 1


# -- Step 4: Family Web Construction (s52, s22.6) -----------------------------

static func _build_family_web(
	characters: Array,
	dice: DiceEngine,
) -> void:
	var by_clan: Dictionary = {}
	for c: L5RCharacterData in characters:
		if not by_clan.has(c.clan):
			by_clan[c.clan] = []
		by_clan[c.clan].append(c)

	for clan: String in by_clan:
		var clan_chars: Array = by_clan[clan]
		_assign_parents(clan_chars, dice)
		_assign_marriages(clan_chars, by_clan, dice)
		_assign_siblings(clan_chars, dice)


static func _assign_parents(
	clan_chars: Array,
	dice: DiceEngine,
) -> void:
	var sorted_by_age: Array = clan_chars.duplicate()
	sorted_by_age.sort_custom(func(a: L5RCharacterData, b: L5RCharacterData) -> bool:
		return a.age > b.age
	)

	for i: int in range(sorted_by_age.size()):
		var child: L5RCharacterData = sorted_by_age[i]
		if child.father_id >= 0 or child.mother_id >= 0:
			continue

		for j: int in range(i):
			var potential_parent: L5RCharacterData = sorted_by_age[j]
			if potential_parent.age < child.age + 16:
				continue
			if potential_parent.age > child.age + 40:
				continue
			if potential_parent.family != child.family:
				continue

			var children_count: int = potential_parent.children_ids.size()
			if children_count >= 4:
				continue

			if dice.rand_int_range(1, 100) <= 40:
				if potential_parent.gender == "male":
					child.father_id = potential_parent.character_id
				else:
					child.mother_id = potential_parent.character_id
				potential_parent.children_ids.append(child.character_id)
				break


static func _assign_marriages(
	clan_chars: Array,
	all_by_clan: Dictionary,
	dice: DiceEngine,
) -> void:
	var unmarried: Array = []
	for c: L5RCharacterData in clan_chars:
		if c.spouse_id < 0 and c.age >= 18:
			unmarried.append(c)

	var marriage_rate: int = 40
	for c: L5RCharacterData in unmarried:
		if c.spouse_id >= 0:
			continue
		if dice.rand_int_range(1, 100) > marriage_rate:
			continue

		var cross_clan: bool = dice.rand_int_range(1, 100) <= 15
		var pool: Array = clan_chars if not cross_clan else _get_cross_clan_pool(c.clan, all_by_clan)

		for candidate: Variant in pool:
			var other: L5RCharacterData = candidate as L5RCharacterData
			if other.character_id == c.character_id:
				continue
			if other.spouse_id >= 0:
				continue
			if other.gender == c.gender:
				continue
			if absi(other.age - c.age) > 15:
				continue

			c.spouse_id = other.character_id
			other.spouse_id = c.character_id
			break


static func _get_cross_clan_pool(exclude_clan: String, all_by_clan: Dictionary) -> Array:
	var pool: Array = []
	for clan: String in all_by_clan:
		if clan == exclude_clan:
			continue
		pool.append_array(all_by_clan[clan])
	return pool


static func _assign_siblings(
	clan_chars: Array,
	dice: DiceEngine,
) -> void:
	var parent_children: Dictionary = {}
	for c: L5RCharacterData in clan_chars:
		if c.father_id >= 0:
			if not parent_children.has(c.father_id):
				parent_children[c.father_id] = []
			parent_children[c.father_id].append(c.character_id)
		if c.mother_id >= 0:
			if not parent_children.has(c.mother_id):
				parent_children[c.mother_id] = []
			parent_children[c.mother_id].append(c.character_id)

	var chars_by_id: Dictionary = {}
	for c: L5RCharacterData in clan_chars:
		chars_by_id[c.character_id] = c

	for parent_id: int in parent_children:
		var children: Array = parent_children[parent_id]
		for i: int in range(children.size()):
			for j: int in range(i + 1, children.size()):
				var a: L5RCharacterData = chars_by_id.get(children[i])
				var b: L5RCharacterData = chars_by_id.get(children[j])
				if a == null or b == null:
					continue
				if children[j] not in a.sibling_ids:
					a.sibling_ids.append(children[j])
				if children[i] not in b.sibling_ids:
					b.sibling_ids.append(children[i])


# -- Step 4: Ancestor Records (s22.6) -----------------------------------------

static func _generate_ancestor_records(
	characters: Array,
	dice: DiceEngine,
) -> void:
	for c: L5RCharacterData in characters:
		for _i: int in range(dice.rand_int_range(1, 4)):
			var record := AncestorRecord.new()
			record.ancestor_id = dice.rand_int_range(100000, 999999)
			record.name = GempukkuSystem.generate_name(
				c.clan, ["male", "female"][dice.rand_int_range(0, 1)], dice,
			)
			record.clan = c.clan
			record.family = c.family
			record.generation = 3
			record.ic_year_born = 1120 - c.age - dice.rand_int_range(20, 40)
			record.ic_year_died = record.ic_year_born + dice.rand_int_range(45, 75)
			c.grandparent_records.append(record)


# -- Step 5: Starting Dispositions (s12.2b) ------------------------------------

static func _apply_starting_dispositions(
	characters: Array,
	clan_baselines: Dictionary,
	family_baselines: Dictionary,
) -> void:
	for i: int in range(characters.size()):
		var a: L5RCharacterData = characters[i]
		for j: int in range(i + 1, characters.size()):
			var b: L5RCharacterData = characters[j]
			if a.clan == b.clan and a.family == b.family:
				continue
			CollectiveDisposition.seed_first_meeting(
				a, b, clan_baselines, family_baselines,
			)
			CollectiveDisposition.seed_first_meeting(
				b, a, clan_baselines, family_baselines,
			)


static func _seed_co_located_contacts(characters: Array) -> void:
	var by_location: Dictionary = {}
	for c: L5RCharacterData in characters:
		var loc: String = c.physical_location
		if loc.is_empty():
			continue
		if not by_location.has(loc):
			by_location[loc] = []
		by_location[loc].append(c)

	for loc: String in by_location:
		var group: Array = by_location[loc]
		for i: int in range(group.size()):
			var a: L5RCharacterData = group[i]
			for j: int in range(i + 1, group.size()):
				var b: L5RCharacterData = group[j]
				if not a.met_characters.has(b.character_id):
					a.met_characters.append(b.character_id)
				if not b.met_characters.has(a.character_id):
					b.met_characters.append(a.character_id)


# -- Count Helpers -------------------------------------------------------------

static func _count_by_rank(characters: Array, clan: String) -> Dictionary:
	var counts: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.clan != clan:
			continue
		var rank: int = CharacterStats.get_insight_rank(c)
		counts[rank] = counts.get(rank, 0) + 1
	return counts


# -- Main Entry Point ----------------------------------------------------------

static func generate_world_population(
	provinces: Dictionary,
	settlements: Array,
	dice: DiceEngine,
	next_id: Array,
	clan_baselines: Dictionary = {},
	family_baselines: Dictionary = {},
) -> Dictionary:
	var all_characters: Array = []

	var imperial_result: Dictionary = _generate_imperial_positions(next_id, dice)
	var imperial_chars: Array = imperial_result["characters"]
	all_characters.append_array(imperial_chars)

	var emperor_id: int = imperial_result["emperor_id"]
	var herald_id: int = imperial_result["herald_id"]

	var clan_champions: Dictionary = {}
	var clan_rikugunshokans: Dictionary = {}

	for clan: String in GREAT_CLANS:
		var clan_chars: Array = _generate_clan_leadership(
			clan, next_id, dice,
		)
		all_characters.append_array(clan_chars)
		for c: L5RCharacterData in clan_chars:
			if c.status >= 8.0:
				clan_champions[clan] = c.character_id
			if c.status >= 5.0 and c.status < 6.0:
				if c.school_type == Enums.SchoolType.BUSHI:
					clan_rikugunshokans[clan] = c.character_id

	for clan: String in GREAT_CLANS:
		var rik_id: int = clan_rikugunshokans.get(clan, -1)
		var mil_chars: Array = _generate_military_commanders(
			clan, rik_id, next_id, dice,
		)
		all_characters.append_array(mil_chars)

	var mantis_leadership: Array = _generate_clan_leadership("Mantis", next_id, dice)
	all_characters.append_array(mantis_leadership)
	for c: L5RCharacterData in mantis_leadership:
		if c.status >= 8.0:
			clan_champions["Mantis"] = c.character_id
		if c.role_position == "Rikugunshokan":
			clan_rikugunshokans["Mantis"] = c.character_id

	var mantis_rik_id: int = clan_rikugunshokans.get("Mantis", -1)
	var mantis_mil_chars: Array = _generate_military_commanders(
		"Mantis", mantis_rik_id, next_id, dice,
	)
	all_characters.append_array(mantis_mil_chars)

	var minor_chars: Array = _generate_minor_clan_characters(
		next_id, dice,
	)
	all_characters.append_array(minor_chars)
	for mc: L5RCharacterData in minor_chars:
		if mc.lord_id < 0:
			clan_champions[mc.clan] = mc.character_id

	var province_settlement_map: Dictionary = {}
	for s: SettlementData in settlements:
		if not province_settlement_map.has(s.province_id):
			province_settlement_map[s.province_id] = []
		province_settlement_map[s.province_id].append(s)

	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		var clan: String = prov.clan
		if clan.is_empty() or clan == "Imperial":
			continue

		var fd_id: int = -1
		for c: L5RCharacterData in all_characters:
			if c.clan == clan and c.family == prov.family:
				if POSITION_STATUS.get(PositionType.FAMILY_DAIMYO, 0) == c.status:
					fd_id = c.character_id
					break
		if fd_id < 0:
			fd_id = clan_champions.get(clan, -1)

		var prov_settlements: Array = []
		for s: SettlementData in province_settlement_map.get(prov.province_id, []):
			prov_settlements.append(s)

		var prov_chars: Array = _generate_province_positions(
			prov, prov_settlements, clan, fd_id, next_id, dice,
		)
		all_characters.append_array(prov_chars)

	var magistrate_chars: Array = _generate_magistrate_system(
		next_id, dice, emperor_id,
	)
	all_characters.append_array(magistrate_chars)

	var crab_rik_id: int = clan_rikugunshokans.get("Crab", -1)
	var wall_chars: Array = _generate_wall_characters(
		next_id, dice, crab_rik_id,
	)
	all_characters.append_array(wall_chars)

	for clan: String in GREAT_CLANS:
		var existing_counts: Dictionary = _count_by_rank(all_characters, clan)
		var fill_chars: Array = _generate_rank_filling(
			clan, existing_counts, next_id, dice,
		)
		all_characters.append_array(fill_chars)
	var mantis_counts: Dictionary = _count_by_rank(all_characters, "Mantis")
	var mantis_fill: Array = _generate_rank_filling(
		"Mantis", mantis_counts, next_id, dice,
	)
	all_characters.append_array(mantis_fill)

	_assign_lord_ids(all_characters, clan_champions)

	_build_family_web(all_characters, dice)
	_generate_ancestor_records(all_characters, dice)

	if not clan_baselines.is_empty():
		_apply_starting_dispositions(all_characters, clan_baselines, family_baselines)

	return {
		"characters": all_characters,
		"emperor_id": emperor_id,
		"herald_id": herald_id,
		"clan_champions": clan_champions,
		"total_count": all_characters.size(),
		"next_character_id": next_id[0],
	}
