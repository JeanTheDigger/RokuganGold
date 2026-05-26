extends SceneTree

const _WB := preload("res://simulation/world_bootstrap.gd")


func _init() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1120)

	print("--- Bootstrap Verification ---")
	var result: Dictionary = _WB.bootstrap_world(dice)

	var provinces: Dictionary = result.get("provinces", {})
	var settlements: Array = result.get("settlements", [])
	var characters: Array = result.get("characters", [])
	var clans: Dictionary = result.get("clans", {})
	var mil: Dictionary = result.get("military_data", {})
	var companies: Array = mil.get("companies", [])

	print("Provinces: %d (expect 142)" % provinces.size())
	print("Settlements: %d" % settlements.size())
	print("Characters: %d" % characters.size())
	print("Companies: %d" % companies.size())
	print("Emperor ID: %d" % result.get("emperor_id", -1))
	print("Next char ID: %d" % result.get("next_character_id", -1))
	print("Next settlement ID: %d" % result.get("next_settlement_id", -1))

	# Province table integrity
	assert(provinces.size() == 142, "Expected 142 provinces")

	# Every province has adjacencies
	var missing_adj: int = 0
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		if prov.adjacent_province_ids.size() == 0:
			missing_adj += 1
	print("Provinces without adjacencies: %d" % missing_adj)

	# Clan province counts
	var clan_counts: Dictionary = {}
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		clan_counts[prov.clan] = clan_counts.get(prov.clan, 0) + 1
	print("Clan province distribution:")
	for clan_name: String in ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn", "Mantis", "Fox", "Sparrow", "Badger", "Centipede", "Bat", "Dragonfly", "Hare", "Monkey", "Oriole", "Ox", "Snake", "Tortoise", "Boar", "Imperial"]:
		print("  %s: %d" % [clan_name, clan_counts.get(clan_name, 0)])

	# All clans have clan data
	var clan_champs: Dictionary = result.get("clan_champions", {})
	print("Clan champions from bootstrap result:")
	for clan_name: String in ["Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn"]:
		assert(clans.has(clan_name), "Missing clan data for %s" % clan_name)
		var cd: ClanData = clans[clan_name]
		assert(cd.province_ids.size() > 0, "Clan %s has no provinces" % clan_name)
		var champ_id: int = clan_champs.get(clan_name, -1)
		print("Clan %s: %d provinces, champion_id=%d (from result dict)" % [clan_name, cd.province_ids.size(), champ_id])
		assert(champ_id >= 0, "Clan %s has no champion" % clan_name)

	# Character locations
	var with_location: int = 0
	var without_location: int = 0
	for c: L5RCharacterData in characters:
		if c.physical_location.is_empty():
			without_location += 1
		else:
			with_location += 1
	print("Characters with location: %d / %d (%.1f%%)" % [
		with_location, characters.size(),
		float(with_location) / float(characters.size()) * 100.0
	])
	assert(without_location == 0, "All characters should have physical_location")

	# Settlement worship locations
	var setts_with_worship: int = 0
	for s: SettlementData in settlements:
		if s.worship_locations.size() > 0:
			setts_with_worship += 1
	print("Settlements with worship: %d / %d" % [setts_with_worship, settlements.size()])

	# Military rank distribution
	var rank_dist: Dictionary = {}
	for c: L5RCharacterData in characters:
		rank_dist[c.military_rank] = rank_dist.get(c.military_rank, 0) + 1
	print("Military rank distribution:")
	for r: Variant in rank_dist:
		print("  rank %d: %d characters" % [r, rank_dist[r]])

	# Ungovernable provinces
	var ungov: int = 0
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		if prov.family == "Hiruma":
			ungov += 1
			assert(prov.province_taint_level >= 3.0, "Hiruma province %s should have PTL >= 3" % prov.province_name)
			assert(prov.settlement_ids.size() == 0, "Hiruma province %s should have no settlements" % prov.province_name)
	print("Ungovernable (Hiruma) provinces: %d" % ungov)

	# Co-located contacts
	var by_location: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.physical_location.is_empty():
			continue
		if not by_location.has(c.physical_location):
			by_location[c.physical_location] = []
		by_location[c.physical_location].append(c)
	var tested_contacts: int = 0
	var contact_failures: int = 0
	for loc: String in by_location:
		var group: Array = by_location[loc]
		if group.size() < 2:
			continue
		var a: L5RCharacterData = group[0]
		var b: L5RCharacterData = group[1]
		if not a.met_characters.has(b.character_id):
			contact_failures += 1
		if not b.met_characters.has(a.character_id):
			contact_failures += 1
		tested_contacts += 1
		if tested_contacts >= 10:
			break
	print("Co-located contact test: %d pairs tested, %d failures" % [tested_contacts, contact_failures])

	# Check Toshi Ranbo
	var found_tr: bool = false
	for s: SettlementData in settlements:
		if s.settlement_name == "Toshi Ranbo":
			found_tr = true
			print("Toshi Ranbo: type=%d, pop=%d PU" % [s.settlement_type, s.population_pu])
			break
	assert(found_tr, "Should find Toshi Ranbo")

	# Herald ID
	var herald_id: int = result.get("herald_id", -1)
	print("Herald ID: %d" % herald_id)
	assert(herald_id >= 0, "Herald ID should be non-negative")
	var herald_found: bool = false
	for c: L5RCharacterData in characters:
		if c.character_id == herald_id:
			herald_found = true
			assert(c.clan == "Imperial", "Herald should be Imperial")
			assert(c.family == "Miya", "Herald should be Miya")
			assert(c.role_position == "Imperial Herald", "Herald role_position mismatch: %s" % c.role_position)
			print("Herald: clan=%s, family=%s, role=%s" % [c.clan, c.family, c.role_position])
			break
	assert(herald_found, "Should find herald character")

	# Role position completeness
	var emperor_id: int = result.get("emperor_id", -1)
	var emperor_role: String = ""
	var high_status_no_role: int = 0
	for c: L5RCharacterData in characters:
		if c.character_id == emperor_id:
			emperor_role = c.role_position
		if c.status >= 4.0 and c.role_position.is_empty():
			high_status_no_role += 1
	print("Emperor role_position: '%s'" % emperor_role)
	assert(emperor_role == "Emperor", "Emperor should have 'Emperor' role_position")
	print("High-status characters (>= 4.0) without role_position: %d" % high_status_no_role)
	assert(high_status_no_role == 0, "All high-status characters should have role_position set")

	# Phoenix Elemental Masters
	var master_elements: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.role_position.begins_with("Master of "):
			var element: String = c.role_position.replace("Master of ", "")
			master_elements[element] = c.character_id
			assert(c.clan == "Phoenix", "Elemental Master should be Phoenix")
			assert(c.family == "Isawa", "Elemental Master should be Isawa")
			assert(c.school_type == Enums.SchoolType.SHUGENJA, "Master should be shugenja")
	print("Elemental Masters found: %s" % str(master_elements.keys()))
	for element: String in ["Fire", "Water", "Air", "Earth", "Void"]:
		assert(master_elements.has(element), "Missing Master of %s" % element)

	# Lord ID assignment
	var lordless_count: int = 0
	var lordless_by_clan: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.lord_id < 0 and c.role_position.is_empty():
			lordless_count += 1
			lordless_by_clan[c.clan] = lordless_by_clan.get(c.clan, 0) + 1
	print("Lordless samurai (no role, lord_id=-1): %d" % lordless_count)
	if not lordless_by_clan.is_empty():
		print("  By clan: %s" % str(lordless_by_clan))
	assert(lordless_count == 0, "All rank-filling samurai should have lord_id assigned")

	# Mantis has full leadership
	var mantis_champ: bool = result.get("clan_champions", {}).has("Mantis")
	assert(mantis_champ, "Mantis should have a clan champion")

	# Province terrain distribution
	var terrain_dist: Dictionary = {}
	for pid2: Variant in provinces:
		var p2: ProvinceData = provinces[pid2]
		terrain_dist[p2.terrain_type] = terrain_dist.get(p2.terrain_type, 0) + 1
	print("Province terrain distribution: %s" % str(terrain_dist))

	# Settlement population
	var with_pop: int = 0
	var total_pop: int = 0
	for s2: SettlementData in settlements:
		if s2.population_pu > 0:
			with_pop += 1
		total_pop += s2.population_pu
	print("Settlements with population: %d / %d (total PU: %d)" % [with_pop, settlements.size(), total_pop])
	assert(with_pop > 0, "At least some settlements should have population")

	# Character skills
	var with_skills: int = 0
	for c3: L5RCharacterData in characters:
		if not c3.skills.is_empty():
			with_skills += 1
	print("Characters with skills: %d / %d" % [with_skills, characters.size()])
	assert(with_skills == characters.size(), "All characters should have skills")

	# Province stability
	var stability_dist: Dictionary = {}
	for pid3: Variant in provinces:
		var p3: ProvinceData = provinces[pid3]
		stability_dist[int(p3.stability)] = stability_dist.get(int(p3.stability), 0) + 1
	print("Province stability distribution: %s" % str(stability_dist))

	# known_contacts_by_clan populated
	var with_clan_contacts: int = 0
	for c4: L5RCharacterData in characters:
		if not c4.known_contacts_by_clan.is_empty():
			with_clan_contacts += 1
	print("Characters with known_contacts_by_clan: %d / %d" % [with_clan_contacts, characters.size()])
	assert(with_clan_contacts == characters.size(), "All characters should have clan contacts indexed")

	# Disposition entries (should be ~500K not 14M)
	var total_disp: int = 0
	for c5: L5RCharacterData in characters:
		total_disp += c5.disposition_values.size()
	print("Total disposition entries: %d (expect ~500K, not 14M)" % total_disp)
	assert(total_disp < 1000000, "Disposition entries should be co-located only, not all-pairs")
	assert(total_disp > 100000, "Should have substantial co-located dispositions")

	print("\n--- ALL CHECKS PASSED ---")
	quit()
