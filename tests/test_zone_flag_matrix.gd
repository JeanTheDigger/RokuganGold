extends GutTest


# =============================================================================
# Castle Interior — Performance
# =============================================================================

func test_ohiroma_permits_performance():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.OHIROMA))

func test_enkai_hall_permits_performance():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.ENKAI_HALL))

func test_chashitsu_permits_performance():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.CHASHITSU))

func test_outer_courtyard_permits_performance():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.OUTER_COURTYARD))

func test_audience_chamber_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.AUDIENCE_CHAMBER))

func test_guest_wing_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.GUEST_WING))

func test_lord_quarters_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.LORD_QUARTERS))

func test_war_council_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.WAR_COUNCIL_ROOM))

func test_dojo_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.DOJO))

func test_tsuboniwa_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.TSUBONIWA))

func test_castle_shrine_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.CASTLE_SHRINE))


# =============================================================================
# Castle Interior — Tokonoma
# =============================================================================

func test_audience_chamber_has_tokonoma():
	assert_true(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.AUDIENCE_CHAMBER))

func test_chashitsu_has_tokonoma():
	assert_true(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.CHASHITSU))

func test_guest_wing_has_tokonoma():
	assert_true(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.GUEST_WING))

func test_lord_quarters_has_tokonoma():
	assert_true(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.LORD_QUARTERS))

func test_tsuboniwa_has_tokonoma():
	assert_true(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.TSUBONIWA))

func test_ohiroma_no_tokonoma():
	assert_false(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.OHIROMA))


# =============================================================================
# Castle Interior — Art Slots
# =============================================================================

func test_ohiroma_all_art_slots():
	assert_true(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.OHIROMA))
	assert_true(ZoneFlagMatrix.can_display_art(Enums.ZoneSubtype.OHIROMA))
	assert_true(ZoneFlagMatrix.has_fusuma(Enums.ZoneSubtype.OHIROMA))

func test_chashitsu_wall_art_only():
	assert_true(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.CHASHITSU))
	assert_false(ZoneFlagMatrix.can_display_art(Enums.ZoneSubtype.CHASHITSU))
	assert_false(ZoneFlagMatrix.has_fusuma(Enums.ZoneSubtype.CHASHITSU))

func test_war_council_no_art():
	assert_false(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.WAR_COUNCIL_ROOM))
	assert_false(ZoneFlagMatrix.can_display_art(Enums.ZoneSubtype.WAR_COUNCIL_ROOM))
	assert_false(ZoneFlagMatrix.has_fusuma(Enums.ZoneSubtype.WAR_COUNCIL_ROOM))

func test_castle_shrine_wall_art_only():
	assert_true(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.CASTLE_SHRINE))
	assert_false(ZoneFlagMatrix.can_display_art(Enums.ZoneSubtype.CASTLE_SHRINE))


# =============================================================================
# Castle Interior — Garden and Bonsai
# =============================================================================

func test_outer_courtyard_garden_and_bonsai():
	assert_true(ZoneFlagMatrix.can_garden(Enums.ZoneSubtype.OUTER_COURTYARD))
	assert_true(ZoneFlagMatrix.can_display_bonsai(Enums.ZoneSubtype.OUTER_COURTYARD))

func test_tsuboniwa_garden_and_bonsai():
	assert_true(ZoneFlagMatrix.can_garden(Enums.ZoneSubtype.TSUBONIWA))
	assert_true(ZoneFlagMatrix.can_display_bonsai(Enums.ZoneSubtype.TSUBONIWA))

func test_ohiroma_no_garden():
	assert_false(ZoneFlagMatrix.can_garden(Enums.ZoneSubtype.OHIROMA))
	assert_false(ZoneFlagMatrix.can_display_bonsai(Enums.ZoneSubtype.OHIROMA))


# =============================================================================
# Castle Interior — Shrine
# =============================================================================

func test_castle_shrine_eligible():
	assert_true(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.CASTLE_SHRINE))

func test_ohiroma_not_shrine():
	assert_false(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.OHIROMA))


# =============================================================================
# Tea Ceremony — Tokonoma OR Shrine
# =============================================================================

func test_tea_ceremony_in_chashitsu():
	assert_true(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.CHASHITSU))

func test_tea_ceremony_in_tsuboniwa():
	assert_true(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.TSUBONIWA))

func test_tea_ceremony_in_castle_shrine():
	assert_true(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.CASTLE_SHRINE))

func test_tea_ceremony_in_temple():
	assert_true(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.TEMPLE_GROUNDS))

func test_no_tea_ceremony_in_ohiroma():
	assert_false(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.OHIROMA))

func test_no_tea_ceremony_in_market():
	assert_false(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.MARKET_STREET))


# =============================================================================
# Urban Districts
# =============================================================================

func test_market_street_performance_only():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.MARKET_STREET))
	assert_false(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.MARKET_STREET))

func test_residential_all_false():
	var flags: Dictionary = ZoneFlagMatrix.get_flags(Enums.ZoneSubtype.RESIDENTIAL_QUARTER)
	for key: String in ZoneFlagMatrix.FLAG_KEYS:
		assert_false(flags[key], "Flag %s should be false" % key)

func test_temple_grounds_full_flags():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_true(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_true(ZoneFlagMatrix.can_display_art(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_true(ZoneFlagMatrix.has_fusuma(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_true(ZoneFlagMatrix.can_display_bonsai(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_true(ZoneFlagMatrix.can_garden(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_true(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.TEMPLE_GROUNDS))
	assert_false(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.TEMPLE_GROUNDS))

func test_pleasure_quarter_flags():
	assert_true(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.PLEASURE_QUARTER))
	assert_true(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.PLEASURE_QUARTER))
	assert_true(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.PLEASURE_QUARTER))
	assert_false(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.PLEASURE_QUARTER))

func test_docks_all_false():
	var flags: Dictionary = ZoneFlagMatrix.get_flags(Enums.ZoneSubtype.DOCKS_WATERFRONT)
	for key: String in ZoneFlagMatrix.FLAG_KEYS:
		assert_false(flags[key])

func test_poor_quarter_all_false():
	var flags: Dictionary = ZoneFlagMatrix.get_flags(Enums.ZoneSubtype.POOR_QUARTER)
	for key: String in ZoneFlagMatrix.FLAG_KEYS:
		assert_false(flags[key])

func test_government_quarter_wall_art_only():
	assert_true(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.GOVERNMENT_QUARTER))
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.GOVERNMENT_QUARTER))
	assert_false(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.GOVERNMENT_QUARTER))


# =============================================================================
# Wilderness
# =============================================================================

func test_road_all_false():
	var flags: Dictionary = ZoneFlagMatrix.get_flags(Enums.ZoneSubtype.ROAD)
	for key: String in ZoneFlagMatrix.FLAG_KEYS:
		assert_false(flags[key])

func test_forest_path_all_false():
	var flags: Dictionary = ZoneFlagMatrix.get_flags(Enums.ZoneSubtype.FOREST_PATH)
	for key: String in ZoneFlagMatrix.FLAG_KEYS:
		assert_false(flags[key])

func test_shrine_clearing_only_shrine():
	assert_true(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.SHRINE_CLEARING))
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.SHRINE_CLEARING))
	assert_false(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.SHRINE_CLEARING))


# =============================================================================
# Zone Categories
# =============================================================================

func test_ohiroma_is_castle_interior():
	assert_true(ZoneFlagMatrix.is_castle_interior(Enums.ZoneSubtype.OHIROMA))

func test_market_is_urban():
	assert_true(ZoneFlagMatrix.is_urban(Enums.ZoneSubtype.MARKET_STREET))

func test_road_is_wilderness():
	assert_true(ZoneFlagMatrix.is_wilderness(Enums.ZoneSubtype.ROAD))

func test_shrine_clearing_is_wilderness():
	assert_true(ZoneFlagMatrix.is_wilderness(Enums.ZoneSubtype.SHRINE_CLEARING))

func test_categories_do_not_overlap():
	for z: int in Enums.ZoneSubtype.values():
		var zone: Enums.ZoneSubtype = z as Enums.ZoneSubtype
		var count: int = 0
		if ZoneFlagMatrix.is_castle_interior(zone):
			count += 1
		if ZoneFlagMatrix.is_urban(zone):
			count += 1
		if ZoneFlagMatrix.is_wilderness(zone):
			count += 1
		if ZoneFlagMatrix.is_wall_zone(zone):
			count += 1
		assert_eq(count, 1, "Zone %d should be in exactly one category" % z)


# =============================================================================
# Castle Scaling
# =============================================================================

func test_village_headman_max_two_zones():
	assert_eq(ZoneFlagMatrix.get_max_zones(Enums.LordRank.VILLAGE_HEADMAN), 2)

func test_village_headman_min_one_zone():
	assert_eq(ZoneFlagMatrix.get_min_zones(Enums.LordRank.VILLAGE_HEADMAN), 1)

func test_provincial_daimyo_max_four():
	assert_eq(ZoneFlagMatrix.get_max_zones(Enums.LordRank.PROVINCIAL_DAIMYO), 4)

func test_family_daimyo_max_six():
	assert_eq(ZoneFlagMatrix.get_max_zones(Enums.LordRank.FAMILY_DAIMYO), 6)

func test_clan_champion_max_eight():
	assert_eq(ZoneFlagMatrix.get_max_zones(Enums.LordRank.CLAN_CHAMPION), 8)

func test_clan_champion_includes_all_core_zones():
	var scaling: Dictionary = ZoneFlagMatrix.get_castle_zones_for_rank(
		Enums.LordRank.CLAN_CHAMPION
	)
	var zones: Array = scaling["zones"]
	assert_true(Enums.ZoneSubtype.OHIROMA in zones)
	assert_true(Enums.ZoneSubtype.LORD_QUARTERS in zones)
	assert_true(Enums.ZoneSubtype.CHASHITSU in zones)
	assert_true(Enums.ZoneSubtype.CASTLE_SHRINE in zones)

func test_imperial_min_ten():
	assert_eq(ZoneFlagMatrix.get_min_zones(Enums.LordRank.IMPERIAL), 10)

func test_imperial_max_eleven():
	assert_eq(ZoneFlagMatrix.get_max_zones(Enums.LordRank.IMPERIAL), 11)

func test_imperial_includes_all_zone_types():
	var scaling: Dictionary = ZoneFlagMatrix.get_castle_zones_for_rank(
		Enums.LordRank.IMPERIAL
	)
	var zones: Array = scaling["zones"]
	assert_eq(zones.size(), 11)
	assert_true(Enums.ZoneSubtype.OHIROMA in zones)
	assert_true(Enums.ZoneSubtype.ENKAI_HALL in zones)
	assert_true(Enums.ZoneSubtype.AUDIENCE_CHAMBER in zones)
	assert_true(Enums.ZoneSubtype.CHASHITSU in zones)
	assert_true(Enums.ZoneSubtype.GUEST_WING in zones)
	assert_true(Enums.ZoneSubtype.LORD_QUARTERS in zones)
	assert_true(Enums.ZoneSubtype.WAR_COUNCIL_ROOM in zones)
	assert_true(Enums.ZoneSubtype.DOJO in zones)
	assert_true(Enums.ZoneSubtype.OUTER_COURTYARD in zones)
	assert_true(Enums.ZoneSubtype.TSUBONIWA in zones)
	assert_true(Enums.ZoneSubtype.CASTLE_SHRINE in zones)

func test_village_headman_zones():
	var scaling: Dictionary = ZoneFlagMatrix.get_castle_zones_for_rank(
		Enums.LordRank.VILLAGE_HEADMAN
	)
	var zones: Array = scaling["zones"]
	assert_eq(zones.size(), 2)
	assert_true(Enums.ZoneSubtype.OHIROMA in zones)
	assert_true(Enums.ZoneSubtype.OUTER_COURTYARD in zones)


# =============================================================================
# All Zone Subtypes Have Flags
# =============================================================================

func test_all_zone_subtypes_have_entries():
	for z: int in Enums.ZoneSubtype.values():
		var zone: Enums.ZoneSubtype = z as Enums.ZoneSubtype
		var flags: Dictionary = ZoneFlagMatrix.get_flags(zone)
		assert_eq(flags.size(), 8, "Zone %d should have 8 flags" % z)

func test_all_flags_are_boolean():
	for z: int in Enums.ZoneSubtype.values():
		var zone: Enums.ZoneSubtype = z as Enums.ZoneSubtype
		var flags: Dictionary = ZoneFlagMatrix.get_flags(zone)
		for key: String in ZoneFlagMatrix.FLAG_KEYS:
			assert_true(flags[key] is bool, "Flag %s on zone %d should be bool" % [key, z])


# =============================================================================
# Wall Tower Zone Flags (s57.36 extension, s57.19)
# =============================================================================

func test_wall_tower_no_performance():
	assert_false(ZoneFlagMatrix.can_perform(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_wall_art():
	assert_false(ZoneFlagMatrix.can_display_wall_art(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_displayed_art():
	assert_false(ZoneFlagMatrix.can_display_art(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_fusuma():
	assert_false(ZoneFlagMatrix.has_fusuma(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_tokonoma():
	assert_false(ZoneFlagMatrix.has_tokonoma(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_bonsai():
	assert_false(ZoneFlagMatrix.can_display_bonsai(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_garden():
	assert_false(ZoneFlagMatrix.can_garden(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_shrine():
	assert_false(ZoneFlagMatrix.can_worship(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_no_tea_ceremony():
	assert_false(ZoneFlagMatrix.can_tea_ceremony(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_is_wall_zone():
	assert_true(ZoneFlagMatrix.is_wall_zone(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_not_castle_interior():
	assert_false(ZoneFlagMatrix.is_castle_interior(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_not_urban():
	assert_false(ZoneFlagMatrix.is_urban(Enums.ZoneSubtype.WALL_TOWER))

func test_wall_tower_not_wilderness():
	assert_false(ZoneFlagMatrix.is_wilderness(Enums.ZoneSubtype.WALL_TOWER))

func test_ohiroma_not_wall_zone():
	assert_false(ZoneFlagMatrix.is_wall_zone(Enums.ZoneSubtype.OHIROMA))
