extends GutTest

const _WB := preload("res://simulation/world_bootstrap.gd")

var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(1120)


# -- Province Table Integrity --------------------------------------------------

func test_province_table_has_142_entries() -> void:
	assert_eq(
		_WB.PROVINCE_TABLE.size(), 142,
		"GDD s2.3 specifies 142 provinces (Great+Minor+Imperial+Boar)",
	)


func test_province_table_entries_have_6_fields() -> void:
	for entry: Array in _WB.PROVINCE_TABLE:
		assert_eq(
			entry.size(), 6,
			"Entry %s should have [name, clan, family, coastal, island, ungovernable]" % entry[0],
		)


func test_no_duplicate_province_names() -> void:
	var seen: Dictionary = {}
	for entry: Array in _WB.PROVINCE_TABLE:
		var name: String = entry[0]
		assert_false(seen.has(name), "Duplicate province name: %s" % name)
		seen[name] = true


func test_every_province_has_adjacency_entry() -> void:
	for entry: Array in _WB.PROVINCE_TABLE:
		var name: String = entry[0]
		assert_true(
			_WB.ADJACENCY_TABLE.has(name),
			"Province %s missing from ADJACENCY_TABLE" % name,
		)


func test_adjacency_is_bidirectional() -> void:
	var failures: Array[String] = []
	for prov_name: String in _WB.ADJACENCY_TABLE:
		var adj_names: Array = _WB.ADJACENCY_TABLE[prov_name]
		for adj: String in adj_names:
			if not _WB.ADJACENCY_TABLE.has(adj):
				failures.append("%s → %s (target not in table)" % [prov_name, adj])
				continue
			var reverse: Array = _WB.ADJACENCY_TABLE[adj]
			if not reverse.has(prov_name):
				failures.append("%s → %s (not bidirectional)" % [prov_name, adj])
	assert_eq(failures.size(), 0, "Adjacency failures: %s" % str(failures))


func test_every_family_seat_references_valid_province() -> void:
	var prov_names: Dictionary = {}
	for entry: Array in _WB.PROVINCE_TABLE:
		prov_names[entry[0]] = true

	for family: String in _WB.FAMILY_SEAT_PROVINCES:
		var seat_name: String = _WB.FAMILY_SEAT_PROVINCES[family]
		assert_true(
			prov_names.has(seat_name),
			"Family %s seat %s not in PROVINCE_TABLE" % [family, seat_name],
		)


# -- Bootstrap Result Structure -----------------------------------------------

func test_bootstrap_returns_provinces() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result.has("provinces"), "Result should have provinces key")
	assert_true(result["provinces"].size() > 0, "Should create at least one province")


func test_bootstrap_returns_settlements() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result.has("settlements"), "Result should have settlements key")
	assert_true(result["settlements"].size() > 0, "Should create at least one settlement")


func test_bootstrap_returns_characters() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result.has("characters"), "Result should have characters key")
	assert_true(result["characters"].size() > 0, "Should create at least one character")


func test_bootstrap_returns_clans() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result.has("clans"), "Result should have clans key")
	for clan: String in ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn"]:
		assert_true(result["clans"].has(clan), "Should have clan: %s" % clan)


func test_bootstrap_returns_emperor_id() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result["emperor_id"] >= 0, "Emperor ID should be non-negative")


func test_bootstrap_returns_military_data() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result.has("military_data"), "Result should have military_data key")
	var mil: Dictionary = result["military_data"]
	assert_true(mil.has("companies"), "Military data should have companies")
	assert_true(mil.has("next_company_id"), "Military data should have next_company_id")


# -- Province Creation ---------------------------------------------------------

func test_bootstrap_creates_142_provinces() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_eq(result["provinces"].size(), 142, "Should create 142 provinces")


func test_ungovernable_provinces_have_taint() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
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
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var clan_counts: Dictionary = {}
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		clan_counts[prov.clan] = clan_counts.get(prov.clan, 0) + 1
	assert_eq(clan_counts.get("Crab", 0), 16, "Crab should have 16 provinces")
	assert_eq(clan_counts.get("Mantis", 0), 8, "Mantis should have 8 provinces")
	assert_eq(clan_counts.get("Imperial", 0), 1, "Imperial should have 1 province")


# -- Settlement Creation -------------------------------------------------------

func test_ungovernable_provinces_have_no_settlements() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		if prov.family == "Hiruma":
			assert_eq(
				prov.settlement_ids.size(), 0,
				"Hiruma province %s should have 0 settlements" % prov.province_name,
			)


func test_toshi_ranbo_is_a_city() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var found: bool = false
	for s: SettlementData in result["settlements"]:
		if s.settlement_name == "Toshi Ranbo":
			found = true
			assert_eq(s.settlement_type, Enums.SettlementType.CITY)
			assert_eq(s.population_pu, 30)
	assert_true(found, "Should create Toshi Ranbo settlement")


func test_family_seats_get_castles() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
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
	var result: Dictionary = _WB.bootstrap_world(_dice)
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
	var result: Dictionary = _WB.bootstrap_world(_dice)
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

func test_all_characters_have_physical_locations() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var chars: Array = result["characters"]
	var without_location: int = 0
	for c: L5RCharacterData in chars:
		if c.physical_location.is_empty():
			without_location += 1
	assert_eq(without_location, 0, "All characters should have physical_location set")


# -- Clan Data -----------------------------------------------------------------

func test_clan_data_has_province_ids() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var crab: ClanData = result["clans"]["Crab"]
	assert_true(crab.province_ids.size() > 0, "Crab should have province IDs")
	assert_eq(crab.clan_name, "Crab")


func test_minor_clans_have_clan_data() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result["clans"].has("Mantis"), "Should have Mantis clan data")
	assert_true(result["clans"].has("Fox"), "Should have Fox clan data")
	assert_true(result["clans"].has("Bat"), "Should have Bat clan data")
	assert_true(result["clans"].has("Oriole"), "Should have Oriole clan data")
	assert_true(result["clans"].has("Tortoise"), "Should have Tortoise clan data")


# -- Military Company Fields ---------------------------------------------------

func test_military_companies_have_correct_field_names() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var mil: Dictionary = result["military_data"]
	var companies: Array = mil["companies"]
	assert_true(companies.size() > 0, "Should create at least one company")
	for co: Dictionary in companies:
		assert_true(co.has("company_id"), "Company should have company_id")
		assert_true(co.has("clan_name"), "Company should have clan_name (not 'clan')")
		assert_true(co.has("commander_id"), "Company should have commander_id")
		assert_true(co.has("lord_id"), "Company should have lord_id")
		assert_true(co.has("unit_type"), "Company should have unit_type")
		assert_true(co.has("training_level"), "Company should have training_level")
		assert_true(co.has("destroyed"), "Company should have destroyed")
		assert_false(co.has("clan"), "Company should NOT have bare 'clan' key")


func test_military_companies_created_for_ranked_officers() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var mil: Dictionary = result["military_data"]
	var companies: Array = mil["companies"]
	var chars: Array = result["characters"]
	var commander_ids: Array[int] = []
	for co: Dictionary in companies:
		commander_ids.append(co["commander_id"])
	for c: L5RCharacterData in chars:
		if c.military_rank >= 2:
			assert_true(
				commander_ids.has(c.character_id),
				"Character %d with military_rank %d should command a company" % [
					c.character_id, c.military_rank,
				],
			)


func test_military_rank_assigned_to_positioned_characters() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var chars: Array = result["characters"]
	var found_ranked: int = 0
	for c: L5RCharacterData in chars:
		if c.role_position in ["Rikugunshokan", "Taisa", "Chui", "Garrison Commander"]:
			assert_true(
				c.military_rank > 0,
				"Character with position %s should have military_rank > 0" % c.role_position,
			)
			found_ranked += 1
	assert_true(found_ranked > 0, "Should find at least one character with military position")


# -- Worship Locations ---------------------------------------------------------

func test_settlements_have_worship_locations() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var setts: Array = result["settlements"]
	var with_worship: int = 0
	for s: SettlementData in setts:
		if s.worship_locations.size() > 0:
			with_worship += 1
	assert_eq(
		with_worship, setts.size(),
		"All settlements should have at least one worship location",
	)


func test_family_castle_has_shrine_worship() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for s: SettlementData in result["settlements"]:
		if s.settlement_type == Enums.SettlementType.FAMILY_CASTLE:
			assert_true(
				s.worship_locations.size() > 0,
				"Family castle %s should have worship locations" % s.settlement_name,
			)
			var has_shrine: bool = false
			for loc: Dictionary in s.worship_locations:
				if loc.get("type", "") == "local_shrine":
					has_shrine = true
					break
			assert_true(has_shrine, "Family castle %s should have a local_shrine" % s.settlement_name)
			return
	assert_true(false, "Should find at least one family castle")


# -- Co-located Contacts -------------------------------------------------------

func test_co_located_characters_are_mutual_contacts() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var chars: Array = result["characters"]
	var by_location: Dictionary = {}
	for c: L5RCharacterData in chars:
		if c.physical_location.is_empty():
			continue
		if not by_location.has(c.physical_location):
			by_location[c.physical_location] = []
		by_location[c.physical_location].append(c)
	var tested: int = 0
	for loc: String in by_location:
		var group: Array = by_location[loc]
		if group.size() < 2:
			continue
		var a: L5RCharacterData = group[0]
		var b: L5RCharacterData = group[1]
		assert_true(
			a.met_characters.has(b.character_id),
			"Character %d should know co-located character %d" % [a.character_id, b.character_id],
		)
		assert_true(
			b.met_characters.has(a.character_id),
			"Character %d should know co-located character %d" % [b.character_id, a.character_id],
		)
		tested += 1
		if tested >= 3:
			break
	assert_true(tested > 0, "Should find locations with multiple characters")


# -- Next Character ID ---------------------------------------------------------

func test_next_character_id_exceeds_all_character_ids() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var next_id: int = result["next_character_id"]
	var max_id: int = 0
	for c: L5RCharacterData in result["characters"]:
		if c.character_id > max_id:
			max_id = c.character_id
	assert_true(
		next_id > max_id,
		"next_character_id (%d) should exceed highest character ID (%d)" % [next_id, max_id],
	)


# -- Deterministic Seeding ----------------------------------------------------

func test_bootstrap_is_deterministic() -> void:
	var dice1 := DiceEngine.new()
	dice1.set_seed(42)
	var result1: Dictionary = _WB.bootstrap_world(dice1)

	var dice2 := DiceEngine.new()
	dice2.set_seed(42)
	var result2: Dictionary = _WB.bootstrap_world(dice2)

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


# -- Minor Clan Data Gaps (Bat, Oriole, Tortoise) ----------------------------

func test_bat_clan_characters_created() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var bat_count: int = 0
	for c: L5RCharacterData in result["characters"]:
		if c.clan == "Bat":
			bat_count += 1
	assert_true(bat_count > 0, "Should create Bat clan characters")


func test_oriole_clan_characters_created() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var oriole_count: int = 0
	for c: L5RCharacterData in result["characters"]:
		if c.clan == "Oriole":
			oriole_count += 1
	assert_true(oriole_count > 0, "Should create Oriole clan characters")


func test_bat_characters_have_physical_locations() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for c: L5RCharacterData in result["characters"]:
		if c.clan == "Bat":
			assert_false(
				c.physical_location.is_empty(),
				"Bat character %d should have a physical location" % c.character_id,
			)
			return
	assert_true(false, "Should find at least one Bat character")


func test_oriole_characters_have_physical_locations() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for c: L5RCharacterData in result["characters"]:
		if c.clan == "Oriole":
			assert_false(
				c.physical_location.is_empty(),
				"Oriole character %d should have a physical location" % c.character_id,
			)
			return
	assert_true(false, "Should find at least one Oriole character")


func test_tortoise_has_adjacencies() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for pid: Variant in result["provinces"]:
		var prov: ProvinceData = result["provinces"][pid]
		if prov.province_name == "Tortoise Clan Lands":
			assert_true(
				prov.adjacent_province_ids.size() > 0,
				"Tortoise Clan Lands should have adjacencies",
			)
			return
	assert_true(false, "Should find Tortoise Clan Lands province")


func test_extinct_clans_not_in_population() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for c: L5RCharacterData in result["characters"]:
		assert_ne(c.clan, "Boar", "Boar clan is extinct — should not create characters")
		assert_ne(c.clan, "Snake", "Snake clan is extinct — should not create characters")


# -- Role Position Assignment --------------------------------------------------

func test_emperor_has_role_position() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var emperor_id: int = result["emperor_id"]
	for c: L5RCharacterData in result["characters"]:
		if c.character_id == emperor_id:
			assert_eq(c.role_position, "Emperor", "Emperor should have role_position 'Emperor'")
			return
	assert_true(false, "Should find emperor character")


func test_clan_champions_have_role_position() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var champions: Dictionary = result["clan_champions"]
	for clan: String in champions:
		var champ_id: int = champions[clan]
		for c: L5RCharacterData in result["characters"]:
			if c.character_id == champ_id:
				assert_eq(
					c.role_position, "Clan Champion",
					"%s clan champion should have role_position 'Clan Champion'" % clan,
				)
				break


func test_positioned_characters_have_nonempty_role_position() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var high_status_empty: Array[String] = []
	for c: L5RCharacterData in result["characters"]:
		if c.status >= 4.0 and c.role_position.is_empty():
			high_status_empty.append("id=%d clan=%s status=%.1f" % [c.character_id, c.clan, c.status])
	assert_eq(
		high_status_empty.size(), 0,
		"Characters with status >= 4.0 should have role_position set: %s" % str(high_status_empty),
	)


# -- Herald / Miya Representative -----------------------------------------------

func test_bootstrap_returns_herald_id() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	assert_true(result["herald_id"] >= 0, "Herald ID should be non-negative")


func test_herald_is_imperial_miya() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var herald_id: int = result["herald_id"]
	for c: L5RCharacterData in result["characters"]:
		if c.character_id == herald_id:
			assert_eq(c.clan, "Imperial", "Herald should be Imperial clan")
			assert_eq(c.family, "Miya", "Herald should be Miya family")
			assert_eq(c.role_position, "Imperial Herald", "Herald should have 'Imperial Herald' role")
			return
	assert_true(false, "Should find herald character")


# -- Phoenix Elemental Masters --------------------------------------------------

func test_phoenix_has_five_elemental_masters() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var master_elements: Dictionary = {}
	for c: L5RCharacterData in result["characters"]:
		if c.role_position.begins_with("Master of "):
			var element: String = c.role_position.replace("Master of ", "")
			master_elements[element] = c.character_id
	for element: String in ["Fire", "Water", "Air", "Earth", "Void"]:
		assert_true(
			master_elements.has(element),
			"Should create Master of %s" % element,
		)


func test_elemental_masters_are_phoenix_isawa_shugenja() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for c: L5RCharacterData in result["characters"]:
		if c.role_position.begins_with("Master of "):
			assert_eq(c.clan, "Phoenix", "Elemental Master should be Phoenix")
			assert_eq(c.family, "Isawa", "Elemental Master should be Isawa")
			assert_eq(
				c.school_type, Enums.SchoolType.SHUGENJA,
				"Elemental Master %s should be shugenja" % c.role_position,
			)


func test_mantis_has_clan_champion() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var champs: Dictionary = result.get("clan_champions", {})
	assert_true(champs.has("Mantis"), "Mantis should have a clan champion")
	assert_gt(champs["Mantis"], 0, "Mantis champion ID should be positive")


func test_mantis_has_family_daimyos() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var fd_count: int = 0
	for c: L5RCharacterData in result["characters"]:
		if c.clan == "Mantis" and c.role_position == "Family Daimyo":
			fd_count += 1
	assert_eq(fd_count, 3, "Mantis should have 3 Family Daimyos (Yoritomo, Moshi, Tsuruchi)")


func test_all_samurai_have_lord_id() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var lordless: int = 0
	for c: L5RCharacterData in result["characters"]:
		if c.lord_id < 0 and c.role_position.is_empty():
			lordless += 1
	assert_eq(lordless, 0, "All rank-filling samurai should have lord_id assigned")


# -- Initial Koku (s22.4 Step 6) -----------------------------------------------

func test_koku_includes_stipend_component() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for c: L5RCharacterData in result["characters"]:
		if c.role_position.is_empty() and c.lord_id >= 0:
			assert_true(c.koku >= 2.0, "Rank-filling samurai should have koku >= 2.0 (stipend base)")
			return
	assert_true(false, "Should find at least one rank-filling samurai")


func test_koku_scales_with_rank() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var r1_total: float = 0.0
	var r1_count: int = 0
	var r5_total: float = 0.0
	var r5_count: int = 0
	for c: L5RCharacterData in result["characters"]:
		var rank: int = CharacterStats.get_insight_rank(c)
		if rank == 1:
			r1_total += c.koku
			r1_count += 1
		elif rank == 5:
			r5_total += c.koku
			r5_count += 1
	if r1_count > 0 and r5_count > 0:
		var r1_avg: float = r1_total / float(r1_count)
		var r5_avg: float = r5_total / float(r5_count)
		assert_true(r5_avg > r1_avg, "Rank 5 avg koku (%.1f) should exceed rank 1 (%.1f)" % [r5_avg, r1_avg])


# -- Military Company Integration -------------------------------------------------

func test_military_companies_have_source_province_id() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var mil: Dictionary = result["military_data"]
	var companies: Array = mil["companies"]
	var with_source: int = 0
	for co: Dictionary in companies:
		if co.get("source_province_id", -1) >= 0:
			with_source += 1
	assert_true(
		with_source > companies.size() * 0.9,
		"Over 90%% of companies should have source_province_id (got %d/%d)" % [with_source, companies.size()],
	)


func test_military_companies_have_army_id_key() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var mil: Dictionary = result["military_data"]
	var companies: Array = mil["companies"]
	assert_true(companies.size() > 0, "Should have companies")
	assert_true(companies[0].has("army_id"), "Company should have 'army_id' key")
	assert_false(companies[0].has("parent_army_id"), "Company should NOT have 'parent_army_id' key")


# -- Known Contacts By Clan ----------------------------------------------------

func test_co_located_contacts_populate_known_contacts_by_clan() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	var chars: Array = result["characters"]
	var tested: int = 0
	for c: L5RCharacterData in chars:
		if c.met_characters.size() > 0 and not c.known_contacts_by_clan.is_empty():
			assert_true(
				c.known_contacts_by_clan.size() > 0,
				"Character %d with met_characters should have known_contacts_by_clan" % c.character_id,
			)
			tested += 1
			if tested >= 5:
				break
	assert_true(tested > 0, "Should find characters with populated known_contacts_by_clan")


# -- Hiruma Fallback Placement --------------------------------------------------

func test_hiruma_characters_placed_in_crab_settlements() -> void:
	var result: Dictionary = _WB.bootstrap_world(_dice)
	for c: L5RCharacterData in result["characters"]:
		if c.family == "Hiruma":
			assert_false(
				c.physical_location.is_empty(),
				"Hiruma character %d should have location (fallback to Crab settlements)" % c.character_id,
			)
