class_name WorldBootstrap
## One-time world initialization from GDD s2.3 province data.
## Creates all provinces, default settlements, and population on first run.
## After bootstrap, WorldStateSaver persists state between sessions.


# -- Province Reference Table (GDD s2.3.90 Adjacency Index) ------------------
# Each entry: [name, clan, family, is_coastal, is_island, is_ungovernable]
# Adjacent province names are stored separately in ADJACENCY_TABLE.

const GREAT_CLANS: Array[String] = [
	"Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn",
]

const PROVINCE_TABLE: Array[Array] = [
	# --- Crab Clan ---
	# Hida Family
	["Garanto", "Crab", "Hida", false, false, false],
	["Ishibei", "Crab", "Hida", true, false, false],
	["Ishigaki", "Crab", "Hida", false, false, false],
	["Juuin", "Crab", "Hida", false, false, false],
	["Kyoukan", "Crab", "Hida", true, false, false],
	# Kaiu Family
	["Hokufuu", "Crab", "Kaiu", false, false, false],
	["Yoake", "Crab", "Kaiu", false, false, false],
	["Kuda", "Crab", "Kaiu", false, false, false],
	# Kuni Family
	["Midakai", "Crab", "Kuni", false, false, false],
	["Adauchi", "Crab", "Kuni", false, false, false],
	# Hiruma Family (beyond Wall, ungovernable)
	["Hissori", "Crab", "Hiruma", false, false, true],
	["Ienikaeru", "Crab", "Hiruma", false, false, true],
	["Kinbou", "Crab", "Hiruma", true, false, true],
	# Yasuki Family
	["Junkin", "Crab", "Yasuki", true, false, false],
	["Sunda Mizu", "Crab", "Yasuki", true, false, false],
	# Toritaka Family
	["Toritaka", "Crab", "Toritaka", false, false, false],

	# --- Crane Clan ---
	# Asahina Family
	["Anshin", "Crane", "Asahina", true, false, false],
	["Wakiaiai", "Crane", "Asahina", true, false, false],
	["Shinkyou", "Crane", "Asahina", true, false, false],
	# Daidoji Family
	["Kosaten", "Crane", "Daidoji", false, false, false],
	["Hayaku", "Crane", "Daidoji", false, false, false],
	["Sabishii", "Crane", "Daidoji", true, false, false],
	["Ichigun", "Crane", "Daidoji", true, false, false],
	# Doji Family
	["Kazenmuketsu", "Crane", "Doji", true, false, false],
	["Oyomesan", "Crane", "Doji", true, false, false],
	["Itoshii", "Crane", "Doji", true, false, false],
	["Umoeru", "Crane", "Doji", true, false, false],
	["Kougen", "Crane", "Doji", false, false, false],
	# Kakita Family
	["Takuetsu", "Crane", "Kakita", false, false, false],
	["Nanhan", "Crane", "Kakita", false, false, false],
	["Gyousha", "Crane", "Kakita", true, false, false],
	["Kishou", "Crane", "Kakita", true, false, false],

	# --- Dragon Clan ---
	# Kitsuki Family
	["Shinpi", "Dragon", "Kitsuki", false, false, false],
	["Kaitou", "Dragon", "Kitsuki", false, false, false],
	["Sinjutsu", "Dragon", "Kitsuki", false, false, false],
	# Mirumoto Family
	["Gaien", "Dragon", "Mirumoto", false, false, false],
	["Yakeishi", "Dragon", "Mirumoto", false, false, false],
	["Toshibu", "Dragon", "Mirumoto", false, false, false],
	["Kousou", "Dragon", "Mirumoto", false, false, false],
	# Tamori Family
	["Sabishii_Dragon", "Dragon", "Tamori", false, false, false],
	["Kinenkan", "Dragon", "Tamori", false, false, false],
	# Togashi Family
	["Mucha", "Dragon", "Togashi", false, false, false],

	# --- Phoenix Clan ---
	# Asako Family
	["En-Ju", "Phoenix", "Asako", false, false, false],
	["Ki-Rin", "Phoenix", "Asako", false, false, false],
	["Kyuukai", "Phoenix", "Asako", false, false, false],
	["Yogen", "Phoenix", "Asako", false, false, false],
	# Agasha Family (Phoenix)
	["Anshin_Phoenix", "Phoenix", "Agasha", false, false, false],
	["Mihari", "Phoenix", "Agasha", false, false, false],
	["Omoidasu", "Phoenix", "Agasha", true, false, false],
	["Haimaato", "Phoenix", "Agasha", true, false, false],
	# Shiba Family
	["Enjaku", "Phoenix", "Shiba", false, false, false],
	["Ukabu", "Phoenix", "Shiba", false, false, false],
	["Nanimo", "Phoenix", "Shiba", true, false, false],
	["Bachiatari", "Phoenix", "Shiba", true, false, false],
	["Nejiro", "Phoenix", "Shiba", true, false, false],
	# Isawa Family
	["Yosomono", "Phoenix", "Isawa", false, false, false],
	["Kougen_Phoenix", "Phoenix", "Isawa", false, false, false],
	["Garanto_Phoenix", "Phoenix", "Isawa", false, false, false],
	["Aoijiroi", "Phoenix", "Isawa", false, false, false],
	["Kinkaku", "Phoenix", "Isawa", false, false, false],
	["Maryoku", "Phoenix", "Isawa", false, false, false],

	# --- Lion Clan ---
	# Akodo Family
	["Henkyou", "Lion", "Akodo", false, false, false],
	["Ken-ryu", "Lion", "Akodo", false, false, false],
	["Kokoro", "Lion", "Akodo", false, false, false],
	["Oiku", "Lion", "Akodo", false, false, false],
	["Renga", "Lion", "Akodo", false, false, false],
	["Shimizu", "Lion", "Akodo", false, false, false],
	# Ikoma Family
	["Eiyu", "Lion", "Ikoma", false, false, false],
	["Gisei", "Lion", "Ikoma", false, false, false],
	["Gunsho", "Lion", "Ikoma", false, false, false],
	["Ikota", "Lion", "Ikoma", false, false, false],
	["Shiranai", "Lion", "Ikoma", false, false, false],
	# Kitsu Family
	["Dairiki", "Lion", "Kitsu", false, false, false],
	["Foshi", "Lion", "Kitsu", false, false, false],
	["Hayai", "Lion", "Kitsu", false, false, false],
	["Rugashi", "Lion", "Kitsu", false, false, false],
	# Matsu Family
	["Azuma", "Lion", "Matsu", false, false, false],
	["Chuugen", "Lion", "Matsu", false, false, false],
	["Gakka", "Lion", "Matsu", false, false, false],
	["Heigen", "Lion", "Matsu", false, false, false],
	["Kaeru", "Lion", "Matsu", false, false, false],
	["Tonfajutsen", "Lion", "Matsu", false, false, false],
	["Yama", "Lion", "Matsu", false, false, false],
	["Yojin", "Lion", "Matsu", false, false, false],

	# --- Scorpion Clan ---
	# Bayushi Family
	["Kunizakai", "Scorpion", "Bayushi", false, false, false],
	["Hizoku", "Scorpion", "Bayushi", false, false, false],
	["Nezuban", "Scorpion", "Bayushi", false, false, false],
	["Chuuou", "Scorpion", "Bayushi", false, false, false],
	# Shosuro Family
	["Ryoko", "Scorpion", "Shosuro", false, false, false],
	["Kakushikoto", "Scorpion", "Shosuro", false, false, false],
	["Kawa", "Scorpion", "Shosuro", false, false, false],
	# Soshi Family
	["Kinbou_Scorpion", "Scorpion", "Soshi", false, false, false],
	["An'ei", "Scorpion", "Soshi", false, false, false],
	["Yuma", "Scorpion", "Soshi", false, false, false],
	# Yogo Family
	["Fukitsu", "Scorpion", "Yogo", false, false, false],
	["Beiden", "Scorpion", "Yogo", false, false, false],

	# --- Unicorn Clan ---
	# Ide Family
	["Eijitsu", "Unicorn", "Ide", false, false, false],
	["Garanto_Unicorn", "Unicorn", "Ide", false, false, false],
	# Iuchi Family
	["Kaihi", "Unicorn", "Iuchi", false, false, false],
	["Shinten", "Unicorn", "Iuchi", false, false, false],
	["Ujidera", "Unicorn", "Iuchi", false, false, false],
	# Moto Family
	["Enkaku", "Unicorn", "Moto", false, false, false],
	["Ikoku", "Unicorn", "Moto", false, false, false],
	["Kawabe", "Unicorn", "Moto", false, false, false],
	["Zenzan", "Unicorn", "Moto", false, false, false],
	# Shinjo Family
	["Aishou", "Unicorn", "Shinjo", false, false, false],
	["Bugaisha", "Unicorn", "Shinjo", false, false, false],
	["Haisho", "Unicorn", "Shinjo", false, false, false],
	["Kouryo", "Unicorn", "Shinjo", false, false, false],
	# Utaku Family
	["Isei", "Unicorn", "Utaku", false, false, false],
	["Koubaku", "Unicorn", "Utaku", false, false, false],
	["Manaka", "Unicorn", "Utaku", false, false, false],
	["Senseki", "Unicorn", "Utaku", false, false, false],
	["Tsuriai", "Unicorn", "Utaku", false, false, false],

	# --- Mantis Clan (Islands) ---
	["Gotai", "Mantis", "Yoritomo", true, true, false],
	["Koutetsukan", "Mantis", "Yoritomo", true, true, false],
	["Kaze", "Mantis", "Yoritomo", true, true, false],
	["Tokigogachu", "Mantis", "Yoritomo", true, true, false],
	["Inazuma", "Mantis", "Yoritomo", true, true, false],
	["Irie", "Mantis", "Yoritomo", true, true, false],
	["Maigosera", "Mantis", "Yoritomo", true, true, false],
	["Kaigen's Island", "Mantis", "Yoritomo", true, true, false],

	# --- Minor Clans ---
	["Kakusu", "Fox", "Kitsune", false, false, false],
	["Ashinagabachi", "Wasp", "Tsuruchi", false, false, false],
	["Enzan", "Wasp", "Tsuruchi", false, false, false],
	["Chuuhan", "Wasp", "Tsuruchi", false, false, false],
	["Douro", "Wasp", "Tsuruchi", false, false, false],
	["Shaiga", "Wasp", "Tsuruchi", false, false, false],
	["Valley of the Centipede", "Centipede", "Moshi", false, false, false],
	["Badger Clan Lands", "Badger", "Ichiro", false, false, false],
	["Boar Clan Lands", "Boar", "Heichi", false, false, true],
	["Dragonfly Clan Lands", "Dragonfly", "Tonbo", false, false, false],
	["Hare Clan Lands", "Hare", "Usagi", false, false, false],
	["Monkey Clan Lands", "Monkey", "Toku", false, false, false],
	["Ox Clan Lands", "Ox", "Morito", false, false, false],
	["Sparrow Clan Lands", "Sparrow", "Suzume", false, false, false],
	["Tortoise Clan Lands", "Tortoise", "Kasuga", true, false, false],

	# --- Imperial ---
	["Toshi Ranbo", "Imperial", "Otomo", false, false, false],
	["Hub Villages", "Imperial", "Seppun", true, false, false],
	["Seppun Province", "Imperial", "Seppun", true, false, false],
	["Yogasha Heigen", "Imperial", "Seppun", false, false, false],
	["Miya Province", "Imperial", "Miya", false, false, false],
]


# Family seats — the province containing the clan's family castle (kyuden).
# First province listed for each family is treated as the family seat.
const FAMILY_SEAT_PROVINCES: Dictionary = {
	# Crab
	"Hida": "Kyoukan",
	"Kaiu": "Yoake",
	"Kuni": "Midakai",
	"Yasuki": "Sunda Mizu",
	"Toritaka": "Toritaka",
	# Crane
	"Asahina": "Anshin",
	"Daidoji": "Kosaten",
	"Doji": "Kazenmuketsu",
	"Kakita": "Takuetsu",
	# Dragon
	"Kitsuki": "Shinpi",
	"Mirumoto": "Yakeishi",
	"Tamori": "Kinenkan",
	"Togashi": "Mucha",
	# Phoenix
	"Asako": "En-Ju",
	"Agasha": "Anshin_Phoenix",
	"Shiba": "Enjaku",
	"Isawa": "Aoijiroi",
	# Lion
	"Akodo": "Oiku",
	"Ikoma": "Eiyu",
	"Kitsu": "Hayai",
	"Matsu": "Heigen",
	# Scorpion
	"Bayushi": "Chuuou",
	"Shosuro": "Kakushikoto",
	"Soshi": "Kinbou_Scorpion",
	"Yogo": "Beiden",
	# Unicorn
	"Ide": "Eijitsu",
	"Iuchi": "Kaihi",
	"Moto": "Enkaku",
	"Shinjo": "Haisho",
	"Utaku": "Isei",
	# Mantis
	"Yoritomo": "Gotai",
	# Minor clans
	"Kitsune": "Kakusu",
	"Tsuruchi": "Ashinagabachi",
	"Moshi": "Valley of the Centipede",
	"Ichiro": "Badger Clan Lands",
	"Tonbo": "Dragonfly Clan Lands",
	"Usagi": "Hare Clan Lands",
	"Toku": "Monkey Clan Lands",
	"Morito": "Ox Clan Lands",
	"Suzume": "Sparrow Clan Lands",
	"Kasuga": "Tortoise Clan Lands",
	"Komori": "Maigosera",
	"Tsi": "Hub Villages",
	# Imperial
	"Otomo": "Toshi Ranbo",
	"Seppun": "Seppun Province",
	"Miya": "Miya Province",
}


# Terrain type assignment by clan+family patterns (GDD s2.3 descriptions).
const TERRAIN_HINTS: Dictionary = {
	"Hida": Enums.TerrainType.MOUNTAINS,
	"Hiruma": Enums.TerrainType.WASTELAND,
	"Kaiu": Enums.TerrainType.MOUNTAINS,
	"Kuni": Enums.TerrainType.MOUNTAINS,
	"Toritaka": Enums.TerrainType.FOREST,
	"Doji": Enums.TerrainType.PLAINS,
	"Daidoji": Enums.TerrainType.PLAINS,
	"Kakita": Enums.TerrainType.PLAINS,
	"Asahina": Enums.TerrainType.PLAINS,
	"Mirumoto": Enums.TerrainType.MOUNTAINS,
	"Kitsuki": Enums.TerrainType.MOUNTAINS,
	"Tamori": Enums.TerrainType.MOUNTAINS,
	"Togashi": Enums.TerrainType.MOUNTAINS,
	"Akodo": Enums.TerrainType.PLAINS,
	"Matsu": Enums.TerrainType.PLAINS,
	"Ikoma": Enums.TerrainType.PLAINS,
	"Kitsu": Enums.TerrainType.PLAINS,
	"Shiba": Enums.TerrainType.FOREST,
	"Isawa": Enums.TerrainType.FOREST,
	"Asako": Enums.TerrainType.PLAINS,
	"Agasha": Enums.TerrainType.PLAINS,
	"Bayushi": Enums.TerrainType.PLAINS,
	"Shosuro": Enums.TerrainType.SWAMP,
	"Soshi": Enums.TerrainType.PLAINS,
	"Yogo": Enums.TerrainType.PLAINS,
	"Shinjo": Enums.TerrainType.PLAINS,
	"Ide": Enums.TerrainType.PLAINS,
	"Iuchi": Enums.TerrainType.PLAINS,
	"Moto": Enums.TerrainType.PLAINS,
	"Utaku": Enums.TerrainType.PLAINS,
	"Yoritomo": Enums.TerrainType.COASTAL,
	"Kitsune": Enums.TerrainType.FOREST,
	"Tsuruchi": Enums.TerrainType.PLAINS,
	"Moshi": Enums.TerrainType.PLAINS,
	"Ichiro": Enums.TerrainType.MOUNTAINS,
	"Tonbo": Enums.TerrainType.MOUNTAINS,
	"Usagi": Enums.TerrainType.PLAINS,
	"Toku": Enums.TerrainType.PLAINS,
	"Morito": Enums.TerrainType.MOUNTAINS,
	"Suzume": Enums.TerrainType.PLAINS,
	"Kasuga": Enums.TerrainType.COASTAL,
	"Komori": Enums.TerrainType.COASTAL,
	"Tsi": Enums.TerrainType.PLAINS,
	"Otomo": Enums.TerrainType.PLAINS,
	"Heichi": Enums.TerrainType.MOUNTAINS,
	"Seppun": Enums.TerrainType.PLAINS,
	"Miya": Enums.TerrainType.PLAINS,
}

# PROVISIONAL — GDD does not specify base PU per province tier.
const BASE_PU_FAMILY_SEAT: int = 20
const BASE_PU_GREAT_CLAN: int = 10
const BASE_PU_MINOR_CLAN: int = 5
const BASE_PU_UNGOVERNABLE: int = 1


static func bootstrap_world(
	dice: DiceEngine,
) -> Dictionary:
	var provinces: Dictionary = {}
	var settlements: Array[SettlementData] = []
	var province_name_to_id: Dictionary = {}
	var next_province_id: int = 1
	var next_settlement_id: int = 1000

	for entry: Array in PROVINCE_TABLE:
		var prov_name: String = entry[0]
		var clan: String = entry[1]
		var family: String = entry[2]
		var is_coastal: bool = entry[3]
		var is_island: bool = entry[4]
		var is_ungovernable: bool = entry[5]

		var terrain: Enums.TerrainType = TERRAIN_HINTS.get(
			family, Enums.TerrainType.PLAINS
		)

		var base_pu: int = _get_base_pu(clan, family, prov_name, is_ungovernable)
		var pu: int = _scale_pu_by_terrain(base_pu, terrain, dice)

		var province: ProvinceData = WorldGenerator.generate_province(
			next_province_id, prov_name, clan, family, terrain, pu, dice, is_coastal,
		)

		if is_ungovernable:
			province.stability = 0.0
			province.province_taint_level = float(dice.rand_int_range(3, 8))
			province.shadowlands_strength = dice.rand_int_range(5, 15)

		provinces[next_province_id] = province
		province_name_to_id[prov_name] = next_province_id

		var prov_settlements: Array[SettlementData] = _create_province_settlements(
			province, clan, family, prov_name, is_ungovernable, is_island,
			next_settlement_id, pu, dice,
		)
		for s: SettlementData in prov_settlements:
			settlements.append(s)
			province.settlement_ids.append(s.settlement_id)
		next_settlement_id += prov_settlements.size()

		next_province_id += 1

	_wire_adjacencies(provinces, province_name_to_id)

	var clans: Dictionary = _create_clan_data(provinces)

	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	var pop_result: Dictionary = WorldPopulationGenerator.generate_world_population(
		provinces, settlements, dice, [1],
	)

	var characters: Array = pop_result.get("characters", [])

	_assign_physical_locations(characters, provinces, settlements, dice)
	WorldPopulationGenerator._seed_co_located_contacts(
		characters, baselines.get("clan", {}), baselines.get("family", {}),
	)

	var military_data: Dictionary = _create_initial_military(
		characters, clans, provinces, dice, settlements,
	)

	var chars_by_id: Dictionary = {}
	for _c: L5RCharacterData in characters:
		chars_by_id[_c.character_id] = _c

	var next_cell_id: Array = [1]
	var next_insurgency_id: Array = [1]
	var bloodspeaker_result: Dictionary = BloodspeakerNetworkSystem.generate_initial_cells(
		provinces, dice, next_cell_id, 0, next_insurgency_id,
	)

	return {
		"provinces": provinces,
		"settlements": settlements,
		"characters": characters,
		"clans": clans,
		"emperor_id": pop_result.get("emperor_id", -1),
		"herald_id": pop_result.get("herald_id", -1),
		"clan_champions": pop_result.get("clan_champions", {}),
		"military_data": military_data,
		"next_character_id": pop_result.get("next_character_id", pop_result.get("total_count", 0) + 1),
		"next_settlement_id": next_settlement_id,
		"bloodspeaker_cells": bloodspeaker_result.get("cells", []),
		"bloodspeaker_insurgencies": bloodspeaker_result.get("insurgencies", []),
		"next_cell_id": next_cell_id[0],
		"next_insurgency_id": next_insurgency_id[0],
	}


static func _get_base_pu(
	clan: String, family: String, prov_name: String, is_ungovernable: bool,
) -> int:
	if is_ungovernable:
		return BASE_PU_UNGOVERNABLE

	var is_seat: bool = FAMILY_SEAT_PROVINCES.get(family, "") == prov_name

	if clan in ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn"]:
		return BASE_PU_FAMILY_SEAT if is_seat else BASE_PU_GREAT_CLAN
	if clan == "Mantis":
		return BASE_PU_FAMILY_SEAT if is_seat else 8
	if clan == "Imperial":
		return 25
	return BASE_PU_MINOR_CLAN


# PROVISIONAL — PU scaling multipliers not in GDD (distinct from Rice production modifiers in s4.3).
static func _scale_pu_by_terrain(
	base_pu: int, terrain: Enums.TerrainType, dice: DiceEngine,
) -> int:
	var multiplier: float = 1.0
	match terrain:
		Enums.TerrainType.PLAINS:
			multiplier = 1.2
		Enums.TerrainType.FOREST:
			multiplier = 0.9
		Enums.TerrainType.MOUNTAINS:
			multiplier = 0.7
		Enums.TerrainType.SWAMP:
			multiplier = 0.6
		Enums.TerrainType.WASTELAND:
			multiplier = 0.3
		Enums.TerrainType.COASTAL:
			multiplier = 1.0

	var variance: float = 1.0 + (float(dice.rand_int_range(-10, 10)) / 100.0)
	return maxi(1, int(float(base_pu) * multiplier * variance))


static func _create_province_settlements(
	province: ProvinceData,
	clan: String,
	family: String,
	prov_name: String,
	is_ungovernable: bool,
	is_island: bool,
	next_id: int,
	pu: int,
	dice: DiceEngine,
) -> Array[SettlementData]:
	var result: Array[SettlementData] = []

	if is_ungovernable:
		return result

	var is_seat: bool = FAMILY_SEAT_PROVINCES.get(family, "") == prov_name
	var terrain: Enums.TerrainType = province.terrain_type

	if prov_name == "Toshi Ranbo":
		var capital: SettlementData = WorldGenerator.generate_settlement(
			next_id, "Toshi Ranbo", province,
			Enums.SettlementType.CITY, 30, terrain, true,
		)
		result.append(capital)
		return result

	if is_seat:
		var castle_name: String = "Kyuden %s" % family
		if clan in GREAT_CLANS:
			var castle: SettlementData = WorldGenerator.generate_settlement(
				next_id, castle_name, province,
				Enums.SettlementType.FAMILY_CASTLE,
				maxi(5, pu / 2 if pu > 0 else 10),
				terrain, true,
			)
			result.append(castle)
			next_id += 1

		else:
			var keep: SettlementData = WorldGenerator.generate_settlement(
				next_id, castle_name, province,
				Enums.SettlementType.CASTLE,
				maxi(3, pu / 2 if pu > 0 else 5),
				terrain, true,
			)
			result.append(keep)
			next_id += 1

	var remaining_pu: int = pu
	for s: SettlementData in result:
		remaining_pu -= s.population_pu

	if remaining_pu >= 3 and not is_seat:
		var village: SettlementData = WorldGenerator.generate_settlement(
			next_id, "%s Mura" % prov_name, province,
			Enums.SettlementType.VILLAGE,
			mini(remaining_pu, dice.rand_int_range(2, 5)),
			terrain,
		)
		result.append(village)
		next_id += 1

	if is_island and result.is_empty():
		var port: SettlementData = WorldGenerator.generate_settlement(
			next_id, "%s Port" % prov_name, province,
			Enums.SettlementType.VILLAGE, maxi(2, pu),
			Enums.TerrainType.COASTAL,
		)
		port.infrastructure.append("port")
		result.append(port)

	return result


static func _wire_adjacencies(
	provinces: Dictionary,
	name_to_id: Dictionary,
) -> void:
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		var adj_names: Array = ADJACENCY_TABLE.get(prov.province_name, [])
		for adj_name: String in adj_names:
			var adj_id: int = name_to_id.get(adj_name, -1)
			if adj_id >= 0 and not prov.adjacent_province_ids.has(adj_id):
				prov.adjacent_province_ids.append(adj_id)


static func _create_clan_data(provinces: Dictionary) -> Dictionary:
	var clans: Dictionary = {}
	for clan_name: String in GREAT_CLANS:
		var cd := ClanData.new()
		cd.clan_name = clan_name
		cd.iron_stockpile = 50.0
		cd.arms_stockpile = 30.0
		for pid: Variant in provinces:
			var prov: ProvinceData = provinces[pid]
			if prov.clan == clan_name:
				cd.province_ids.append(pid)
		clans[clan_name] = cd

	for minor: String in ["Mantis", "Fox", "Wasp", "Centipede", "Badger",
			"Bat", "Boar", "Dragonfly", "Hare", "Monkey", "Oriole", "Ox",
			"Sparrow", "Tortoise", "Imperial"]:
		var cd := ClanData.new()
		cd.clan_name = minor
		cd.iron_stockpile = 10.0
		cd.arms_stockpile = 5.0
		for pid: Variant in provinces:
			var prov: ProvinceData = provinces[pid]
			if prov.clan == minor:
				cd.province_ids.append(pid)
		clans[minor] = cd

	return clans


static func _assign_physical_locations(
	characters: Array,
	provinces: Dictionary,
	settlements: Array[SettlementData],
	_dice: DiceEngine,
) -> void:
	var settlement_by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if not settlement_by_province.has(s.province_id):
			settlement_by_province[s.province_id] = []
		settlement_by_province[s.province_id].append(s)

	var clan_family_to_province: Dictionary = {}
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		var key: String = "%s_%s" % [prov.clan, prov.family]
		if not clan_family_to_province.has(key):
			clan_family_to_province[key] = []
		clan_family_to_province[key].append(pid)

	var seat_name_to_pid: Dictionary = {}
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		seat_name_to_pid[prov.province_name] = pid

	for c: L5RCharacterData in characters:
		if not c.physical_location.is_empty():
			continue

		var key: String = "%s_%s" % [c.clan, c.family]
		var prov_ids: Array = clan_family_to_province.get(key, [])
		if prov_ids.is_empty():
			var clan_provs: Array = []
			for k: String in clan_family_to_province:
				if k.begins_with(c.clan + "_"):
					clan_provs.append_array(clan_family_to_province[k])
			prov_ids = clan_provs

		if prov_ids.is_empty():
			var seat_prov: String = FAMILY_SEAT_PROVINCES.get(c.family, "")
			if not seat_prov.is_empty() and seat_name_to_pid.has(seat_prov):
				prov_ids = [seat_name_to_pid[seat_prov]]

		if prov_ids.is_empty():
			continue

		var target_settlements: Array = []
		for try_pid: Variant in prov_ids:
			target_settlements = settlement_by_province.get(try_pid, [])
			if not target_settlements.is_empty():
				break

		if target_settlements.is_empty():
			for k: String in clan_family_to_province:
				if k.begins_with(c.clan + "_"):
					for fallback_pid: Variant in clan_family_to_province[k]:
						target_settlements = settlement_by_province.get(fallback_pid, [])
						if not target_settlements.is_empty():
							break
				if not target_settlements.is_empty():
					break

		if not target_settlements.is_empty():
			c.physical_location = str(target_settlements[0].settlement_id)


static func _create_initial_military(
	characters: Array,
	clans: Dictionary,
	_provinces: Dictionary,
	_dice: DiceEngine,
	settlements: Array = [],
) -> Dictionary:
	var settlement_to_province: Dictionary = {}
	for s: SettlementData in settlements:
		settlement_to_province[str(s.settlement_id)] = s.province_id

	var companies: Array[Dictionary] = []
	var next_company_id: int = 1

	for clan_name: String in clans:
		var clan_chars: Array = []
		for c: L5RCharacterData in characters:
			if c.clan == clan_name and c.school_type == Enums.SchoolType.BUSHI:
				clan_chars.append(c)

		var mil_ranked: Array = []
		for c: L5RCharacterData in clan_chars:
			if c.military_rank > 0:
				mil_ranked.append(c)

		for c: L5RCharacterData in mil_ranked:
			if c.military_rank >= 2:
				var src_province: int = settlement_to_province.get(c.physical_location, -1)
				var company: Dictionary = {
					"company_id": next_company_id,
					"clan_name": clan_name,
					"commander_id": c.character_id,
					"lord_id": c.lord_id,
					"current_health": 100,
					"current_morale": 80,
					"arms_deprivation_tick": 0,
					"unit_type": Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
					"training_level": 2,
					"training_points": 0,
					"destroyed": false,
					"levy_raised_season": 0,
					"source_province_id": src_province,
					"parent_legion_id": -1,
					"parent_section_id": -1,
					"army_id": -1,
				}
				c.commanded_unit_id = next_company_id
				companies.append(company)
				next_company_id += 1

	return {
		"companies": companies,
		"next_company_id": next_company_id,
	}


# -- Adjacency Table ----------------------------------------------------------
# Maps province names to arrays of adjacent province names.
# Derived from GDD s2.3.90 Adjacency Index.
# Only same-table province names included (external references like
# "Shadowlands", "unaligned", "Imperial Lands" are omitted).

const ADJACENCY_TABLE: Dictionary = {
	# --- Crab ---
	"Garanto": ["Ishigaki", "Midakai", "Yoake"],
	"Ishibei": ["Ishigaki", "Kyoukan", "Adauchi", "Ienikaeru", "Kinbou", "Sparrow Clan Lands"],
	"Ishigaki": ["Yoake", "Garanto", "Midakai", "Adauchi", "Ishibei", "Ienikaeru", "Hissori"],
	"Juuin": ["Kyoukan", "Adauchi", "Midakai", "Sparrow Clan Lands"],
	"Kyoukan": ["Juuin", "Adauchi", "Ishibei", "Sunda Mizu", "Anshin"],
	"Hokufuu": ["Yoake", "Kuda", "Toritaka", "Boar Clan Lands"],
	"Yoake": ["Hokufuu", "Kuda", "Garanto", "Ishigaki"],
	"Kuda": ["Hokufuu", "Yoake"],
	"Midakai": ["Garanto", "Ishigaki", "Adauchi", "Juuin"],
	"Adauchi": ["Midakai", "Ishigaki", "Ishibei", "Kyoukan", "Juuin"],
	"Hissori": ["Ishigaki", "Ienikaeru"],
	"Ienikaeru": ["Hissori", "Kinbou", "Ishigaki", "Ishibei"],
	"Kinbou": ["Ienikaeru", "Ishibei"],
	"Junkin": ["Sunda Mizu", "Shinkyou", "Wakiaiai"],
	"Sunda Mizu": ["Kyoukan", "Junkin", "Wakiaiai", "Anshin"],
	"Toritaka": ["Hokufuu"],

	# --- Crane ---
	"Anshin": ["Wakiaiai", "Kyoukan", "Sunda Mizu", "Ichigun"],
	"Wakiaiai": ["Anshin", "Shinkyou", "Sunda Mizu", "Junkin"],
	"Shinkyou": ["Wakiaiai", "Junkin"],
	"Kosaten": ["Takuetsu", "Nanhan", "Azuma", "Heigen", "Kaeru", "Yama"],
	"Hayaku": ["Nanhan", "Kazenmuketsu", "Oyomesan"],
	"Sabishii": ["Ichigun", "Kougen", "Kakusu"],
	"Ichigun": ["Anshin", "Sabishii", "Kakusu"],
	"Kazenmuketsu": ["Hayaku", "Oyomesan"],
	"Oyomesan": ["Kazenmuketsu", "Hayaku", "Gyousha", "Ashinagabachi", "Enzan"],
	"Itoshii": ["Kishou", "Umoeru", "Kougen", "Shaiga"],
	"Umoeru": ["Itoshii", "Kougen"],
	"Kougen": ["Itoshii", "Umoeru", "Sabishii", "Kakusu", "Shaiga"],
	"Takuetsu": ["Nanhan", "Kaeru", "Kosaten"],
	"Nanhan": ["Takuetsu", "Hayaku", "Kosaten"],
	"Gyousha": ["Oyomesan", "Kishou", "Douro"],
	"Kishou": ["Gyousha", "Itoshii", "Douro"],

	# --- Dragon ---
	"Shinpi": ["Kaitou", "Gaien", "Yakeishi", "Dragonfly Clan Lands"],
	"Kaitou": ["Shinpi", "Yakeishi", "Sinjutsu", "Dragonfly Clan Lands"],
	"Sinjutsu": ["Kaitou", "Dragonfly Clan Lands"],
	"Gaien": ["Shinpi", "Sabishii_Dragon"],
	"Yakeishi": ["Shinpi", "Kaitou", "Kinenkan", "Toshibu"],
	"Toshibu": ["Yakeishi", "Kousou", "Kinenkan", "Ox Clan Lands"],
	"Kousou": ["Toshibu", "Mucha", "Kinenkan"],
	"Sabishii_Dragon": ["Gaien", "Mucha", "Koubaku", "Senseki"],
	"Kinenkan": ["Yakeishi", "Kousou", "Toshibu", "Mucha"],
	"Mucha": ["Kousou", "Kinenkan", "Sabishii_Dragon"],

	# --- Phoenix ---
	"En-Ju": ["Yosomono", "Aoijiroi", "Kyuukai", "Ki-Rin", "Ox Clan Lands"],
	"Ki-Rin": ["En-Ju", "Kyuukai", "Ox Clan Lands"],
	"Kyuukai": ["Ki-Rin", "En-Ju", "Aoijiroi", "Yogen", "Enjaku"],
	"Yogen": ["Aoijiroi", "Kyuukai", "Enjaku", "Ukabu", "Nanimo", "Bachiatari", "Nejiro", "Maryoku"],
	"Anshin_Phoenix": ["Enjaku", "Ukabu", "Nanimo", "Mihari"],
	"Mihari": ["Anshin_Phoenix", "Nanimo", "Omoidasu"],
	"Omoidasu": ["Mihari", "Nanimo", "Haimaato", "Valley of the Centipede"],
	"Haimaato": ["Omoidasu", "Nanimo"],
	"Enjaku": ["Anshin_Phoenix", "Nanimo", "Ukabu", "Kyuukai", "Yogen", "Toshi Ranbo"],
	"Ukabu": ["Enjaku", "Anshin_Phoenix", "Nanimo", "Yogen"],
	"Nanimo": ["Yogen", "Ukabu", "Enjaku", "Anshin_Phoenix", "Mihari", "Omoidasu", "Haimaato", "Bachiatari"],
	"Bachiatari": ["Nanimo", "Yogen", "Nejiro"],
	"Nejiro": ["Yogen", "Aoijiroi", "Maryoku", "Bachiatari"],
	"Yosomono": ["En-Ju", "Kougen_Phoenix", "Aoijiroi", "Ox Clan Lands"],
	"Kougen_Phoenix": ["Yosomono", "Aoijiroi", "Kinkaku", "Maryoku"],
	"Garanto_Phoenix": ["Maryoku", "Kinkaku"],
	"Aoijiroi": ["En-Ju", "Yosomono", "Kyuukai", "Kougen_Phoenix", "Yogen", "Nejiro", "Kinkaku"],
	"Kinkaku": ["Maryoku", "Garanto_Phoenix", "Kougen_Phoenix", "Aoijiroi"],
	"Maryoku": ["Yogen", "Nejiro", "Kougen_Phoenix", "Kinkaku", "Garanto_Phoenix"],

	# --- Lion ---
	"Henkyou": ["Rugashi", "Foshi", "Renga", "Kokoro", "Oiku"],
	"Ken-ryu": ["Kokoro", "Yojin", "Tonfajutsen", "Shimizu", "Renga"],
	"Kokoro": ["Oiku", "Henkyou", "Ken-ryu", "Renga", "Toshi Ranbo"],
	"Oiku": ["Henkyou", "Kokoro", "Hayai", "Rugashi", "Toshi Ranbo", "Dragonfly Clan Lands"],
	"Renga": ["Kokoro", "Ken-ryu", "Shimizu", "Foshi", "Henkyou"],
	"Shimizu": ["Renga", "Ken-ryu", "Yojin", "Tonfajutsen"],
	"Eiyu": ["Hayai", "Ikota", "Dairiki", "Gisei"],
	"Gisei": ["Eiyu", "Ikota", "Gunsho", "Shiranai"],
	"Gunsho": ["Shiranai", "Gisei", "Ikota", "Dairiki", "Chuugen", "Kaihi"],
	"Ikota": ["Eiyu", "Hayai", "Dairiki", "Gunsho", "Shiranai", "Gisei"],
	"Shiranai": ["Kaihi", "Gisei", "Ikota", "Gunsho"],
	"Dairiki": ["Hayai", "Rugashi", "Foshi", "Gakka", "Chuugen", "Gunsho", "Ikota", "Eiyu"],
	"Foshi": ["Dairiki", "Rugashi", "Henkyou", "Renga", "Gakka"],
	"Hayai": ["Eiyu", "Ikota", "Dairiki", "Rugashi", "Oiku", "Dragonfly Clan Lands"],
	"Rugashi": ["Oiku", "Henkyou", "Foshi", "Dairiki", "Hayai"],
	"Azuma": ["Heigen", "Kosaten", "Monkey Clan Lands", "Yama"],
	"Chuugen": ["Gunsho", "Dairiki", "Gakka"],
	"Gakka": ["Chuugen", "Dairiki", "Foshi", "Heigen", "Monkey Clan Lands"],
	"Heigen": ["Gakka", "Tonfajutsen", "Kaeru", "Kosaten", "Azuma", "Monkey Clan Lands"],
	"Kaeru": ["Kosaten", "Takuetsu", "Yojin", "Tonfajutsen", "Heigen"],
	"Tonfajutsen": ["Ken-ryu", "Shimizu", "Yojin", "Kaeru", "Heigen"],
	"Yama": ["Azuma", "Kosaten", "Monkey Clan Lands"],
	"Yojin": ["Ken-ryu", "Shimizu", "Tonfajutsen", "Kaeru"],

	# --- Scorpion ---
	"Kunizakai": ["Fukitsu", "Beiden", "Chuuou", "Hizoku", "Kawa", "Kakushikoto"],
	"Hizoku": ["Kunizakai", "Chuuou", "Kawa"],
	"Nezuban": ["Beiden", "Chuuou", "Ashinagabachi"],
	"Chuuou": ["Beiden", "Nezuban", "Hizoku", "Kunizakai", "Chuuhan"],
	"Ryoko": ["Kinbou_Scorpion", "Yuma", "Kakushikoto", "Kawa"],
	"Kakushikoto": ["Ryoko", "Yuma", "Fukitsu", "Kunizakai", "Kawa"],
	"Kawa": ["Ryoko", "Kakushikoto", "Kunizakai", "Hizoku"],
	"Kinbou_Scorpion": ["Kaihi", "An'ei", "Yuma", "Ryoko"],
	"An'ei": ["Kinbou_Scorpion", "Yuma"],
	"Yuma": ["An'ei", "Kinbou_Scorpion", "Ryoko", "Kakushikoto"],
	"Fukitsu": ["Kakushikoto", "Kunizakai", "Beiden"],
	"Beiden": ["Nezuban", "Chuuou", "Kunizakai", "Fukitsu"],

	# --- Unicorn ---
	"Eijitsu": ["Enkaku", "Garanto_Unicorn", "Kaihi", "Miya Province"],
	"Garanto_Unicorn": ["Enkaku", "Eijitsu", "Isei", "Zenzan", "Ujidera"],
	"Kaihi": ["Shinten", "Shiranai", "Gunsho", "Ujidera", "Eijitsu", "Kinbou_Scorpion", "Miya Province"],
	"Shinten": ["Ikoku", "Kaihi", "Ujidera"],
	"Ujidera": ["Kawabe", "Ikoku", "Shinten", "Kaihi", "Garanto_Unicorn", "Zenzan"],
	"Enkaku": ["Garanto_Unicorn", "Eijitsu"],
	"Ikoku": ["Shinten", "Ujidera", "Kawabe", "Tsuriai", "Koubaku", "Manaka"],
	"Kawabe": ["Ujidera", "Zenzan", "Isei", "Manaka", "Ikoku"],
	"Zenzan": ["Isei", "Manaka", "Kawabe", "Ujidera", "Garanto_Unicorn"],
	"Aishou": ["Haisho", "Bugaisha", "Kouryo"],
	"Bugaisha": ["Aishou", "Isei", "Manaka", "Kouryo"],
	"Haisho": ["Aishou", "Kouryo"],
	"Kouryo": ["Haisho", "Aishou", "Bugaisha", "Manaka", "Tsuriai", "Senseki", "Badger Clan Lands"],
	"Isei": ["Bugaisha", "Garanto_Unicorn", "Zenzan", "Kawabe", "Manaka"],
	"Koubaku": ["Senseki", "Tsuriai", "Ikoku", "Sabishii_Dragon"],
	"Manaka": ["Tsuriai", "Kouryo", "Kawabe", "Zenzan", "Isei", "Bugaisha", "Ikoku"],
	"Senseki": ["Kouryo", "Tsuriai", "Koubaku", "Sabishii_Dragon"],
	"Tsuriai": ["Kouryo", "Senseki", "Koubaku", "Ikoku", "Manaka"],

	# --- Mantis (island — inter-island only) ---
	"Gotai": ["Koutetsukan", "Kaze", "Tokigogachu", "Irie", "Inazuma"],
	"Koutetsukan": ["Gotai"],
	"Kaze": ["Gotai"],
	"Tokigogachu": ["Gotai"],
	"Inazuma": ["Gotai", "Irie", "Maigosera"],
	"Irie": ["Gotai", "Inazuma", "Maigosera"],
	"Maigosera": ["Inazuma", "Irie"],
	"Kaigen's Island": [],

	# --- Minor Clans ---
	"Kakusu": ["Kougen", "Sabishii", "Ichigun", "Hare Clan Lands", "Sparrow Clan Lands"],
	"Ashinagabachi": ["Enzan", "Nezuban", "Chuuhan", "Douro", "Oyomesan"],
	"Enzan": ["Ashinagabachi", "Oyomesan"],
	"Chuuhan": ["Chuuou", "Ashinagabachi", "Douro"],
	"Douro": ["Chuuhan", "Ashinagabachi", "Shaiga", "Gyousha", "Kishou"],
	"Shaiga": ["Douro", "Kougen", "Itoshii"],
	"Valley of the Centipede": ["Omoidasu", "Seppun Province"],
	"Badger Clan Lands": ["Kouryo"],
	"Boar Clan Lands": ["Hokufuu"],
	"Dragonfly Clan Lands": ["Kaitou", "Shinpi", "Sinjutsu", "Oiku", "Hayai"],
	"Hare Clan Lands": ["Kakusu"],
	"Monkey Clan Lands": ["Gakka", "Heigen", "Azuma", "Yama"],
	"Ox Clan Lands": ["Toshibu", "En-Ju", "Ki-Rin", "Yosomono"],
	"Sparrow Clan Lands": ["Kakusu", "Ishibei", "Juuin"],
	"Tortoise Clan Lands": ["Hub Villages", "Seppun Province"],

	# --- Imperial ---
	"Toshi Ranbo": ["Enjaku", "Kokoro", "Oiku", "Hub Villages"],
	"Hub Villages": ["Toshi Ranbo", "Seppun Province", "Yogasha Heigen", "Tortoise Clan Lands"],
	"Seppun Province": ["Hub Villages", "Yogasha Heigen", "Valley of the Centipede", "Tortoise Clan Lands"],
	"Yogasha Heigen": ["Hub Villages", "Seppun Province"],
	"Miya Province": ["Eijitsu", "Kaihi"],
}
