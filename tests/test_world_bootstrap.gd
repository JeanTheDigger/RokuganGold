extends GutTest


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(1120)


# -- Province Table Integrity --------------------------------------------------

func test_province_table_has_142_entries() -> void:
	assert_eq(
		WorldBootstrap.PROVINCE_TABLE.size(), 142,
		"GDD s2.3 specifies 142 provinces (Great+Minor+Imperial+Boar)",
	)


func test_province_table_entries_have_6_fields() -> void:
	for entry: Array in WorldBootstrap.PROVINCE_TABLE:
		assert_eq(
			entry.size(), 6,
			"Entry %s should have [name, clan, family, coastal, island, ungovernable]" % entry[0],
		)


func test_no_duplicate_province_names() -> void:
	var seen: Dictionary = {}
	for entry: Array in WorldBootstrap.PROVINCE_TABLE:
		var name: String = entry[0]
		assert_false(seen.has(name), "Duplicate province name: %s" % name)
		seen[name] = true


func test_every_province_has_adjacency_entry() -> void:
	for entry: Array in WorldBootstrap.PROVINCE_TABLE:
		var name: String = entry[0]
		assert_true(
			WorldBootstrap.ADJACENCY_TABLE.has(name),
			"Province %s missing from ADJACENCY_TABLE" % name,
		)


func test_adjacency_is_bidirectional() -> void:
	var failures: Array[String] = []
	for prov_name: String in WorldBootstrap.ADJACENCY_TABLE:
		var adj_names: Array = WorldBootstrap.ADJACENCY_TABLE[prov_name]
		for adj: String in adj_names:
			if not WorldBootstrap.ADJACENCY_TABLE.has(adj):
				failures.append("%s → %s (target not in table)" % [prov_name, adj])
				continue
			var reverse: Array = WorldBootstrap.ADJACENCY_TABLE[adj]
			if not reverse.has(prov_name):
				failures.append("%s → %s (not bidirectional)" % [prov_name, adj])
	assert_eq(failures.size(), 0, "Adjacency failures: %s" % str(failures))


func test_every_family_seat_references_valid_province() -> void:
	var prov_names: Dictionary = {}
	for entry: Array in WorldBootstrap.PROVINCE_TABLE:
		prov_names[entry[0]] = true

	for family: String in WorldBootstrap.FAMILY_SEAT_PROVINCES:
		var seat_name: String = WorldBootstrap.FAMILY_SEAT_PROVINCES[family]
		assert_true(
			prov_names.has(seat_name),
			"Family %s seat %s not in PROVINCE_TABLE" % [family, seat_name],
		)


# -- Bootstrap Result Structure -----------------------------------------------

func test_bootstrap_returns_provinces() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result.has("provinces"), "Result should have provinces key")
	assert_true(result["provinces"].size() > 0, "Should create at least one province")


func test_bootstrap_returns_settlements() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result.has("settlements"), "Result should have settlements key")
	assert_true(result["settlements"].size() > 0, "Should create at least one settlement")


func test_bootstrap_returns_characters() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result.has("characters"), "Result should have characters key")
	assert_true(result["characters"].size() > 0, "Should create at least one character")


func test_bootstrap_returns_clans() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result.has("clans"), "Result should have clans key")
	for clan: String in ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn"]:
		assert_true(result["clans"].has(clan), "Should have clan: %s" % clan)


func test_bootstrap_returns_emperor_id() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result["emperor_id"] >= 0, "Emperor ID should be non-negative")


func test_bootstrap_returns_military_data() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result.has("military_data"), "Result should have military_data key")
	var mil: Dictionary = result["military_data"]
	assert_true(mil.has("companies"), "Military data should have companies")
	assert_true(mil.has("next_company_id"), "Military data should have next_company_id")


# -- Province Creation ---------------------------------------------------------

func test_bootstrap_creates_142_provinces() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_eq(result["provinces"].size(), 142, "Should create 142 provinces")


func test_ungovernable_provinces_have_taint() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var found_ungovernable: bool = false
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		if prov.family == "Hiruma":
			found_ungovernable = true
			assert_true(
				prov.province_taint_level >= 3.0,
				"Hiruma province %s should have elevated PTL" % prov.province_name,
			)
			assert_true(
				prov.shadowlands_strength >= 5,
				"Hiruma province %s should have SS >= 5" % prov.province_name,
			)
	assert_true(found_ungovernable, "Should find at least one Hiruma province")


func test_provinces_have_correct_clan_assignments() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var clan_counts: Dictionary = {}
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		clan_counts[prov.clan] = clan_counts.get(prov.clan, 0) + 1
	assert_eq(clan_counts.get("Crab", 0), 16, "Crab should have 16 provinces")
	assert_eq(clan_counts.get("Mantis", 0), 8, "Mantis should have 8 provinces")
	assert_eq(clan_counts.get("Imperial", 0), 1, "Imperial should have 1 province")


# -- Settlement Creation -------------------------------------------------------

func test_ungovernable_provinces_have_no_settlements() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		if prov.family == "Hiruma":
			assert_eq(
				prov.settlement_ids.size(), 0,
				"Hiruma province %s should have 0 settlements" % prov.province_name,
			)


func test_toshi_ranbo_is_a_city() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var found: bool = false
	for s: SettlementData in result["settlements"]:
		if s.settlement_name == "Toshi Ranbo":
			found = true
			assert_eq(s.settlement_type, Enums.SettlementType.CITY)
			assert_eq(s.population_pu, 30)
	assert_true(found, "Should create Toshi Ranbo settlement")


func test_family_seats_get_castles() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var castle_names: Array[String] = []
	for s: SettlementData in result["settlements"]:
		if s.settlement_type == Enums.SettlementType.FAMILY_CASTLE:
			castle_names.append(s.settlement_name)
	assert_true(castle_names.size() > 0, "Should create family castles")
	assert_true(
		castle_names.has("Kyuden Hida"),
		"Hida family seat should create Kyuden Hida",
	)


func test_island_provinces_get_ports() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var mantis_settlements: Array[SettlementData] = []
	for s: SettlementData in result["settlements"]:
		for pid: Variant in result["provinces"]:
			var prov: ProvinceData = result["provinces"][pid]
			if prov.clan == "Mantis" and prov.settlement_ids.has(s.settlement_id):
				mantis_settlements.append(s)
				break
	assert_true(mantis_settlements.size() > 0, "Mantis islands should have settlements")


# -- Adjacency Wiring ---------------------------------------------------------

func test_adjacencies_wired_to_province_ids() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var toshi_ranbo: ProvinceData = null
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		if prov.province_name == "Toshi Ranbo":
			toshi_ranbo = prov
			break
	assert_not_null(toshi_ranbo, "Should find Toshi Ranbo")
	assert_true(
		toshi_ranbo.adjacent_province_ids.size() > 0,
		"Toshi Ranbo should have adjacencies wired",
	)


# -- Physical Locations --------------------------------------------------------

func test_characters_have_physical_locations() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var chars: Array = result["characters"]
	var with_location: int = 0
	for c: L5RCharacterData in chars:
		if not c.physical_location.is_empty():
			with_location += 1
	var pct: float = float(with_location) / float(chars.size()) * 100.0
	assert_true(pct > 90.0, "Over 90%% of characters should have locations (got %.1f%%)" % pct)


# -- Clan Data -----------------------------------------------------------------

func test_clan_data_has_province_ids() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	var crab: ClanData = result["clans"]["Crab"]
	assert_true(crab.province_ids.size() > 0, "Crab should have province IDs")
	assert_eq(crab.clan_name, "Crab")


func test_minor_clans_have_clan_data() -> void:
	var result: Dictionary = WorldBootstrap.bootstrap_world(_dice)
	assert_true(result["clans"].has("Mantis"), "Should have Mantis clan data")
	assert_true(result["clans"].has("Fox"), "Should have Fox clan data")


# -- Deterministic Seeding ----------------------------------------------------

func test_bootstrap_is_deterministic() -> void:
	var dice1 := DiceEngine.new()
	dice1.set_seed(42)
	var result1: Dictionary = WorldBootstrap.bootstrap_world(dice1)

	var dice2 := DiceEngine.new()
	dice2.set_seed(42)
	var result2: Dictionary = WorldBootstrap.bootstrap_world(dice2)

	assert_eq(
		result1["provinces"].size(),
		result2["provinces"].size(),
		"Same seed should produce same number of provinces",
	)
	assert_eq(
		result1["characters"].size(),
		result2["characters"].size(),
		"Same seed should produce same number of characters",
	)
