extends GutTest
## Tests for SettlementZoneBuilder (s4.4.1 LOCKED + Amendment v564 + s57.36.2 LOCKED).

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_settlement(id: int, name: String, stype: int, pu: int) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = id
	s.settlement_name = name
	s.settlement_type = stype
	s.population_pu = pu
	return s


func _build(id: int, name: String, stype: int, pu: int,
		coastal: bool = false,
		lord_rank: int = Enums.LordRank.VILLAGE_HEADMAN) -> Dictionary:
	var s: SettlementData = _make_settlement(id, name, stype, pu)
	return SettlementZoneBuilder.build(s, coastal, lord_rank)


# ---------------------------------------------------------------------------
# Return structure
# ---------------------------------------------------------------------------

func test_build_returns_expected_keys() -> void:
	var r: Dictionary = _build(1, "Mura", Enums.SettlementType.VILLAGE, 100)
	assert_true(r.has("greater_zone"))
	assert_true(r.has("navigation_zones"))
	assert_true(r.has("lesser_zones"))


func test_greater_zone_is_settlement_type() -> void:
	var r: Dictionary = _build(1, "Mura", Enums.SettlementType.VILLAGE, 100)
	var gz: GreaterZoneData = r["greater_zone"]
	assert_eq(gz.zone_type, Enums.GreaterZoneType.SETTLEMENT)


func test_greater_zone_id_is_deterministic() -> void:
	var r: Dictionary = _build(42, "Shiro Hida", Enums.SettlementType.CASTLE, 3000,
			false, Enums.LordRank.FAMILY_DAIMYO)
	var gz: GreaterZoneData = r["greater_zone"]
	assert_eq(gz.zone_id, "42_gz")


func test_greater_zone_settlement_id_stored() -> void:
	var r: Dictionary = _build(7, "Foo", Enums.SettlementType.VILLAGE, 200)
	var gz: GreaterZoneData = r["greater_zone"]
	assert_eq(gz.settlement_id, "7")


func test_greater_zone_name_matches_settlement_name() -> void:
	var r: Dictionary = _build(3, "Toshi Test", Enums.SettlementType.TOWN, 1000)
	var gz: GreaterZoneData = r["greater_zone"]
	assert_eq(gz.zone_name, "Toshi Test")


# ---------------------------------------------------------------------------
# Castle Compound Navigation Zone
# ---------------------------------------------------------------------------

func test_military_type_always_has_castle_nav_zone() -> void:
	for stype: int in Enums.MILITARY_SETTLEMENT_TYPES:
		var r: Dictionary = _build(10, "Fort", stype, 300,
				false, Enums.LordRank.VILLAGE_HEADMAN)
		assert_eq(r["navigation_zones"].size(), 1,
			"Military stype %d must have Castle Compound nav zone" % stype)


func test_city_daimyo_plus_civilian_gets_castle_nav_zone() -> void:
	var r: Dictionary = _build(11, "Toshi", Enums.SettlementType.CITY, 3000,
			false, Enums.LordRank.CITY_DAIMYO)
	assert_eq(r["navigation_zones"].size(), 1)
	var nav: NavigationZoneData = r["navigation_zones"][0]
	assert_eq(nav.zone_type, Enums.NavigationZoneType.CASTLE_COMPOUND)


func test_village_headman_civilian_has_no_nav_zone() -> void:
	var r: Dictionary = _build(12, "Mura", Enums.SettlementType.VILLAGE, 200,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	assert_eq(r["navigation_zones"].size(), 0)


func test_religious_settlement_has_no_nav_zone() -> void:
	for stype: int in Enums.RELIGIOUS_SETTLEMENT_TYPES:
		var r: Dictionary = _build(20, "Temple", stype, 300)
		assert_eq(r["navigation_zones"].size(), 0,
			"Religious stype %d must not have a nav zone" % stype)


func test_castle_nav_zone_id_is_deterministic() -> void:
	var r: Dictionary = _build(99, "Shiro", Enums.SettlementType.CASTLE, 2000,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	var nav: NavigationZoneData = r["navigation_zones"][0]
	assert_eq(nav.zone_id, "99_nav_castle")


func test_castle_nav_zone_parent_is_greater_zone() -> void:
	var r: Dictionary = _build(99, "Shiro", Enums.SettlementType.CASTLE, 2000,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	var nav: NavigationZoneData = r["navigation_zones"][0]
	assert_eq(nav.parent_zone_id, "99_gz")


func test_greater_zone_has_castle_nav_as_child() -> void:
	var r: Dictionary = _build(99, "Shiro", Enums.SettlementType.CASTLE, 2000,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	var gz: GreaterZoneData = r["greater_zone"]
	assert_true(gz.has_child_zone("99_nav_castle"))


# ---------------------------------------------------------------------------
# Castle interior zones by lord rank (s57.36.2 LOCKED)
# ---------------------------------------------------------------------------

func _castle_subtypes(r: Dictionary) -> Array:
	var result: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_id.contains("_lz_castle_"):
			result.append(lz.zone_subtype)
	return result


func test_headman_castle_has_2_interior_zones() -> void:
	var r: Dictionary = _build(5, "Mura", Enums.SettlementType.CASTLE, 200,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	assert_eq(_castle_subtypes(r).size(), 2)


func test_headman_castle_has_ohiroma_and_outer_courtyard() -> void:
	var r: Dictionary = _build(5, "Mura", Enums.SettlementType.CASTLE, 200,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	var subs: Array = _castle_subtypes(r)
	assert_true(Enums.ZoneSubtype.OHIROMA in subs)
	assert_true(Enums.ZoneSubtype.OUTER_COURTYARD in subs)


func test_city_daimyo_castle_has_3_interior_zones() -> void:
	var r: Dictionary = _build(6, "Toshi", Enums.SettlementType.CASTLE, 1200,
			false, Enums.LordRank.CITY_DAIMYO)
	assert_eq(_castle_subtypes(r).size(), 3)


func test_city_daimyo_castle_includes_audience_chamber() -> void:
	var r: Dictionary = _build(6, "Toshi", Enums.SettlementType.CASTLE, 1200,
			false, Enums.LordRank.CITY_DAIMYO)
	var subs: Array = _castle_subtypes(r)
	assert_true(Enums.ZoneSubtype.OHIROMA in subs)
	assert_true(Enums.ZoneSubtype.AUDIENCE_CHAMBER in subs)
	assert_true(Enums.ZoneSubtype.OUTER_COURTYARD in subs)


func test_provincial_daimyo_castle_has_4_interior_zones() -> void:
	var r: Dictionary = _build(7, "Province", Enums.SettlementType.CASTLE, 2500,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	assert_eq(_castle_subtypes(r).size(), 4)


func test_provincial_daimyo_includes_guest_wing() -> void:
	var r: Dictionary = _build(7, "Province", Enums.SettlementType.CASTLE, 2500,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	var subs: Array = _castle_subtypes(r)
	assert_true(Enums.ZoneSubtype.GUEST_WING in subs)


func test_family_daimyo_castle_has_6_interior_zones() -> void:
	var r: Dictionary = _build(8, "Family", Enums.SettlementType.FAMILY_CASTLE, 4000,
			false, Enums.LordRank.FAMILY_DAIMYO)
	assert_eq(_castle_subtypes(r).size(), 6)


func test_family_daimyo_includes_enkai_tsuboniwa_shrine() -> void:
	var r: Dictionary = _build(8, "Family", Enums.SettlementType.FAMILY_CASTLE, 4000,
			false, Enums.LordRank.FAMILY_DAIMYO)
	var subs: Array = _castle_subtypes(r)
	assert_true(Enums.ZoneSubtype.ENKAI_HALL in subs)
	assert_true(Enums.ZoneSubtype.TSUBONIWA in subs)
	assert_true(Enums.ZoneSubtype.CASTLE_SHRINE in subs)


func test_clan_champion_castle_has_8_interior_zones() -> void:
	var r: Dictionary = _build(9, "Champion", Enums.SettlementType.FAMILY_CASTLE, 8000,
			false, Enums.LordRank.CLAN_CHAMPION)
	assert_eq(_castle_subtypes(r).size(), 8)


func test_clan_champion_includes_dojo_and_war_council() -> void:
	var r: Dictionary = _build(9, "Champion", Enums.SettlementType.FAMILY_CASTLE, 8000,
			false, Enums.LordRank.CLAN_CHAMPION)
	var subs: Array = _castle_subtypes(r)
	assert_true(Enums.ZoneSubtype.DOJO in subs)
	assert_true(Enums.ZoneSubtype.WAR_COUNCIL_ROOM in subs)


func test_castle_interior_zones_parent_to_castle_nav() -> void:
	var r: Dictionary = _build(50, "Shiro", Enums.SettlementType.CASTLE, 2500,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_id.contains("_lz_castle_"):
			assert_eq(lz.parent_zone_id, "50_nav_castle")


func test_castle_nav_contains_castle_interior_zones_as_children() -> void:
	var r: Dictionary = _build(50, "Shiro", Enums.SettlementType.CASTLE, 2500,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	var nav: NavigationZoneData = r["navigation_zones"][0]
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_id.contains("_lz_castle_"):
			assert_true(nav.has_child_zone(lz.zone_id))


# ---------------------------------------------------------------------------
# Headman nav-tier skip
# ---------------------------------------------------------------------------

func test_headman_military_lesser_zones_parent_to_greater_zone() -> void:
	var r: Dictionary = _build(30, "Fort", Enums.SettlementType.CASTLE, 200,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	# No nav zone, so nav_zones should be empty for HEADMAN + military type
	# BUT: military type triggers use_castle_nav = true regardless of rank.
	# So castle nav DOES exist for military types even at headman rank.
	# This test verifies the specific no-nav case: HEADMAN + civilian type.
	var r2: Dictionary = _build(31, "Mura", Enums.SettlementType.VILLAGE, 200,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	assert_eq(r2["navigation_zones"].size(), 0)
	for lz: LesserZoneData in r2["lesser_zones"]:
		assert_eq(lz.parent_zone_id, "31_gz")


# ---------------------------------------------------------------------------
# Civilian fill zones by PU scale
# ---------------------------------------------------------------------------

func test_village_has_farmland_and_shrine() -> void:
	var r: Dictionary = _build(40, "Mura", Enums.SettlementType.VILLAGE, 300)
	var fill_subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		fill_subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.FARMLAND in fill_subtypes)
	assert_true(Enums.ZoneSubtype.SHRINE_CLEARING in fill_subtypes)


func test_village_total_zone_count_in_range() -> void:
	var r: Dictionary = _build(40, "Mura", Enums.SettlementType.VILLAGE, 300)
	var total: int = r["lesser_zones"].size()
	assert_true(total >= 2 and total <= 3,
		"Village zone count %d not in 2–3 range" % total)


func test_town_has_market_street_and_residential() -> void:
	var r: Dictionary = _build(41, "Machi", Enums.SettlementType.TOWN, 1000)
	var fill_subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		fill_subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.MARKET_STREET in fill_subtypes)
	assert_true(Enums.ZoneSubtype.RESIDENTIAL_QUARTER in fill_subtypes)


func test_town_total_zone_count_in_range() -> void:
	var r: Dictionary = _build(41, "Machi", Enums.SettlementType.TOWN, 1000)
	var total: int = r["lesser_zones"].size()
	assert_true(total >= 4 and total <= 6,
		"Town zone count %d not in 4–6 range" % total)


func test_city_has_pleasure_quarter_and_government_quarter() -> void:
	var r: Dictionary = _build(42, "Toshi", Enums.SettlementType.CITY, 3500)
	var fill_subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		fill_subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.PLEASURE_QUARTER in fill_subtypes)
	assert_true(Enums.ZoneSubtype.GOVERNMENT_QUARTER in fill_subtypes)


func test_city_total_zone_count_in_range() -> void:
	var r: Dictionary = _build(42, "Toshi", Enums.SettlementType.CITY, 3500)
	var total: int = r["lesser_zones"].size()
	assert_true(total >= 7 and total <= 10,
		"City zone count %d not in 7–10 range" % total)


func test_major_city_total_zone_count_in_range() -> void:
	var r: Dictionary = _build(43, "Toshi Ranbo", Enums.SettlementType.CITY, 9000)
	var total: int = r["lesser_zones"].size()
	assert_true(total >= 10 and total <= 15,
		"Major city zone count %d not in 10–15 range" % total)


# ---------------------------------------------------------------------------
# Coastal settlements
# ---------------------------------------------------------------------------

func test_coastal_village_has_docks_waterfront() -> void:
	var r: Dictionary = _build(50, "Port Mura", Enums.SettlementType.VILLAGE, 200, true)
	var subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.DOCKS_WATERFRONT in subtypes)


func test_inland_village_has_no_docks_waterfront() -> void:
	var r: Dictionary = _build(51, "Inland Mura", Enums.SettlementType.VILLAGE, 200, false)
	for lz: LesserZoneData in r["lesser_zones"]:
		assert_ne(lz.zone_subtype, Enums.ZoneSubtype.DOCKS_WATERFRONT)


func test_coastal_city_has_docks_waterfront() -> void:
	var r: Dictionary = _build(52, "Port Toshi", Enums.SettlementType.CITY, 4000, true)
	var subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.DOCKS_WATERFRONT in subtypes)


# ---------------------------------------------------------------------------
# Military settlement fill zones
# ---------------------------------------------------------------------------

func test_wall_tower_has_no_civilian_fill_zones() -> void:
	var r: Dictionary = _build(60, "Tower", Enums.SettlementType.WALL_TOWER, 50,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	# All lesser zones should be castle interior zones only
	for lz: LesserZoneData in r["lesser_zones"]:
		assert_true(lz.zone_id.contains("_lz_castle_"))


func test_fortification_has_no_civilian_fill_zones() -> void:
	var r: Dictionary = _build(61, "Fort", Enums.SettlementType.FORTIFICATION, 150,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	for lz: LesserZoneData in r["lesser_zones"]:
		assert_true(lz.zone_id.contains("_lz_castle_"))


func test_keep_has_market_street_support_zone() -> void:
	var r: Dictionary = _build(62, "Keep", Enums.SettlementType.KEEP, 400,
			false, Enums.LordRank.VILLAGE_HEADMAN)
	var subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.MARKET_STREET in subtypes)


# ---------------------------------------------------------------------------
# Religious settlements
# ---------------------------------------------------------------------------

func test_temple_has_temple_grounds_and_shrine_clearing() -> void:
	var r: Dictionary = _build(70, "Temple", Enums.SettlementType.TEMPLE, 200)
	var subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.TEMPLE_GROUNDS in subtypes)
	assert_true(Enums.ZoneSubtype.SHRINE_CLEARING in subtypes)


func test_monastery_has_farmland() -> void:
	var r: Dictionary = _build(71, "Monastery", Enums.SettlementType.MONASTERY, 250)
	var subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		subtypes.append(lz.zone_subtype)
	assert_true(Enums.ZoneSubtype.FARMLAND in subtypes)


func test_shinden_has_two_temple_grounds_and_shrine() -> void:
	var r: Dictionary = _build(72, "Shinden", Enums.SettlementType.SHINDEN, 300)
	var subtypes: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		subtypes.append(lz.zone_subtype)
	var temple_count: int = 0
	for s: int in subtypes:
		if s == Enums.ZoneSubtype.TEMPLE_GROUNDS:
			temple_count += 1
	assert_eq(temple_count, 2)
	assert_true(Enums.ZoneSubtype.SHRINE_CLEARING in subtypes)


# ---------------------------------------------------------------------------
# Exit wiring
# ---------------------------------------------------------------------------

func test_castle_interior_ohiroma_has_exits_to_siblings() -> void:
	var r: Dictionary = _build(80, "Shiro", Enums.SettlementType.CASTLE, 2000,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	# Find OHIROMA
	var ohiroma: LesserZoneData = null
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_subtype == Enums.ZoneSubtype.OHIROMA:
			ohiroma = lz
			break
	assert_not_null(ohiroma)
	# OHIROMA is the hub: should have exits to all other castle interior zones
	var castle_lzs: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_id.contains("_lz_castle_") and lz != ohiroma:
			castle_lzs.append(lz.zone_id)
	for cid: String in castle_lzs:
		var found: bool = false
		for e: Dictionary in ohiroma.exits:
			if e.get("target_zone_id", "") == cid:
				found = true
				break
		assert_true(found, "OHIROMA missing exit to %s" % cid)


func test_castle_interior_spokes_have_exit_back_to_ohiroma() -> void:
	var r: Dictionary = _build(80, "Shiro", Enums.SettlementType.CASTLE, 2000,
			false, Enums.LordRank.PROVINCIAL_DAIMYO)
	var ohiroma_id: String = ""
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_subtype == Enums.ZoneSubtype.OHIROMA:
			ohiroma_id = lz.zone_id
			break
	# Every non-OHIROMA castle interior zone should exit back to OHIROMA
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.zone_id.contains("_lz_castle_") and lz.zone_subtype != Enums.ZoneSubtype.OHIROMA:
			var found: bool = false
			for e: Dictionary in lz.exits:
				if e.get("target_zone_id", "") == ohiroma_id:
					found = true
					break
			assert_true(found, "%s missing exit back to OHIROMA" % lz.zone_id)


func test_fill_zones_have_sequential_exits() -> void:
	var r: Dictionary = _build(81, "Machi", Enums.SettlementType.TOWN, 1000)
	var fill_lzs: Array = []
	for lz: LesserZoneData in r["lesser_zones"]:
		if not lz.zone_id.contains("_lz_castle_"):
			fill_lzs.append(lz)
	# Adjacent fill zones should have exits to each other
	if fill_lzs.size() >= 2:
		var a: LesserZoneData = fill_lzs[0]
		var b: LesserZoneData = fill_lzs[1]
		var a_has_b: bool = false
		var b_has_a: bool = false
		for e: Dictionary in a.exits:
			if e.get("target_zone_id", "") == b.zone_id:
				a_has_b = true
		for e: Dictionary in b.exits:
			if e.get("target_zone_id", "") == a.zone_id:
				b_has_a = true
		assert_true(a_has_b, "Fill zone 0 has no exit to fill zone 1")
		assert_true(b_has_a, "Fill zone 1 has no exit back to fill zone 0")


# ---------------------------------------------------------------------------
# Zone ID determinism
# ---------------------------------------------------------------------------

func test_same_inputs_produce_same_zone_ids() -> void:
	var r1: Dictionary = _build(99, "Shiro", Enums.SettlementType.FAMILY_CASTLE, 5000,
			true, Enums.LordRank.FAMILY_DAIMYO)
	var r2: Dictionary = _build(99, "Shiro", Enums.SettlementType.FAMILY_CASTLE, 5000,
			true, Enums.LordRank.FAMILY_DAIMYO)
	var ids1: Array = []
	var ids2: Array = []
	for lz: LesserZoneData in r1["lesser_zones"]:
		ids1.append(lz.zone_id)
	for lz: LesserZoneData in r2["lesser_zones"]:
		ids2.append(lz.zone_id)
	assert_eq(ids1, ids2)


func test_different_settlement_ids_produce_different_zone_ids() -> void:
	var r1: Dictionary = _build(10, "Mura", Enums.SettlementType.VILLAGE, 200)
	var r2: Dictionary = _build(20, "Mura", Enums.SettlementType.VILLAGE, 200)
	var gz1: GreaterZoneData = r1["greater_zone"]
	var gz2: GreaterZoneData = r2["greater_zone"]
	assert_ne(gz1.zone_id, gz2.zone_id)


# ---------------------------------------------------------------------------
# Greater Zone children registry
# ---------------------------------------------------------------------------

func test_greater_zone_lists_all_direct_child_zones() -> void:
	var r: Dictionary = _build(55, "Machi", Enums.SettlementType.TOWN, 800)
	var gz: GreaterZoneData = r["greater_zone"]
	# All fill lesser zones should be listed in gz.child_zone_ids
	for lz: LesserZoneData in r["lesser_zones"]:
		if lz.parent_zone_id == gz.zone_id:
			assert_true(gz.has_child_zone(lz.zone_id),
				"GZ missing child entry for %s" % lz.zone_id)


func test_castle_nav_listed_as_greater_zone_child() -> void:
	var r: Dictionary = _build(56, "Shiro", Enums.SettlementType.CASTLE, 2000,
			false, Enums.LordRank.CITY_DAIMYO)
	var gz: GreaterZoneData = r["greater_zone"]
	assert_true(gz.has_child_zone("56_nav_castle"))


# ---------------------------------------------------------------------------
# Lesser zone parent links
# ---------------------------------------------------------------------------

func test_fill_zones_parent_to_greater_zone() -> void:
	var r: Dictionary = _build(57, "Machi", Enums.SettlementType.TOWN, 1000)
	for lz: LesserZoneData in r["lesser_zones"]:
		if not lz.zone_id.contains("_lz_castle_"):
			assert_eq(lz.parent_zone_id, "57_gz")
