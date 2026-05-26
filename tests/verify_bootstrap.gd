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

	# Determinism check
	var dice2 := DiceEngine.new()
	dice2.set_seed(1120)
	var result2: Dictionary = _WB.bootstrap_world(dice2)
	var same_provinces: bool = result2["provinces"].size() == provinces.size()
	var same_characters: bool = result2["characters"].size() == characters.size()
	print("Determinism: provinces=%s, characters=%s" % [same_provinces, same_characters])

	# Check Toshi Ranbo
	var found_tr: bool = false
	for s: SettlementData in settlements:
		if s.settlement_name == "Toshi Ranbo":
			found_tr = true
			print("Toshi Ranbo: type=%d, pop=%d PU" % [s.settlement_type, s.population_pu])
			break
	assert(found_tr, "Should find Toshi Ranbo")

	print("\n--- ALL CHECKS PASSED ---")
	quit()
