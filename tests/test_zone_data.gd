extends GutTest
## Tests for LesserZoneData, NavigationZoneData, and GreaterZoneData (s4.4.1).

# ---------------------------------------------------------------------------
# LesserZoneData
# ---------------------------------------------------------------------------

func test_lesser_zone_default_values() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	assert_eq(z.zone_id, "")
	assert_eq(z.zone_name, "")
	assert_eq(z.zone_subtype, Enums.ZoneSubtype.SHRINE_CLEARING)
	assert_eq(z.parent_zone_id, "")
	assert_eq(z.exits.size(), 0)
	assert_eq(z.zone_event_log.size(), 0)
	assert_eq(z.map_deltas.size(), 0)


func test_lesser_zone_event_log_retention_constant() -> void:
	# One IC season = 90 days (shortest season in TimeSystem.SEASON_BOUNDARIES).
	assert_eq(LesserZoneData.EVENT_LOG_RETENTION_DAYS, 90)


func test_lesser_zone_add_exit() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.add_exit("N", "zone_market")
	assert_eq(z.exits.size(), 1)
	assert_eq(z.get_exit("N"), "zone_market")


func test_lesser_zone_add_exit_updates_existing_direction() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.add_exit("N", "zone_a")
	z.add_exit("N", "zone_b")
	assert_eq(z.exits.size(), 1)
	assert_eq(z.get_exit("N"), "zone_b")


func test_lesser_zone_get_exit_missing_returns_empty() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	assert_eq(z.get_exit("N"), "")


func test_lesser_zone_remove_exit() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.add_exit("N", "zone_a")
	z.add_exit("S", "zone_b")
	z.remove_exit("N")
	assert_eq(z.exits.size(), 1)
	assert_eq(z.get_exit("N"), "")
	assert_eq(z.get_exit("S"), "zone_b")


func test_lesser_zone_apply_delta() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.apply_delta(5, 7, Enums.TileType.WALL_STONE)
	assert_true(z.has_delta(5, 7))
	assert_eq(z.map_deltas.get("5,7"), Enums.TileType.WALL_STONE)


func test_lesser_zone_remove_delta() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.apply_delta(3, 4, Enums.TileType.FLOOR_GRASS)
	z.remove_delta(3, 4)
	assert_false(z.has_delta(3, 4))


func test_lesser_zone_has_delta_false_when_empty() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	assert_false(z.has_delta(10, 10))


func test_lesser_zone_log_event() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.log_event(42, "EXAMINE_CRIME_SCENE", 100, 15, 15)
	assert_eq(z.zone_event_log.size(), 1)
	var e: Dictionary = z.zone_event_log[0]
	assert_eq(e["character_id"], 42)
	assert_eq(e["action_id"], "EXAMINE_CRIME_SCENE")
	assert_eq(e["ic_day"], 100)
	assert_eq(e["x"], 15)
	assert_eq(e["y"], 15)


func test_lesser_zone_log_event_no_position_defaults_minus_one() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.log_event(1, "SHADOW_TARGET", 50)
	var e: Dictionary = z.zone_event_log[0]
	assert_eq(e["x"], -1)
	assert_eq(e["y"], -1)


func test_lesser_zone_purge_old_events_removes_stale() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.log_event(1, "A", 0)    # day 0 — old
	z.log_event(2, "B", 50)   # day 50 — old (cutoff at current-90)
	z.log_event(3, "C", 200)  # day 200 — fresh
	z.purge_old_events(290)   # cutoff = 200
	assert_eq(z.zone_event_log.size(), 1)
	assert_eq(z.zone_event_log[0]["character_id"], 3)


func test_lesser_zone_purge_old_events_keeps_all_fresh() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.log_event(1, "A", 100)
	z.log_event(2, "B", 150)
	z.purge_old_events(180)  # cutoff = 90; both at 100 and 150 survive
	assert_eq(z.zone_event_log.size(), 2)


func test_lesser_zone_get_events_for_character() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.log_event(10, "A", 100)
	z.log_event(20, "B", 101)
	z.log_event(10, "C", 102)
	var ev: Array = z.get_events_for_character(10)
	assert_eq(ev.size(), 2)
	assert_eq(ev[0]["action_id"], "A")
	assert_eq(ev[1]["action_id"], "C")


func test_lesser_zone_build_map_returns_correct_size() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.zone_id = "test_zone"
	z.zone_name = "Test Zone"
	z.zone_subtype = Enums.ZoneSubtype.ROAD
	var map: AsciiMapData = z.build_map("TestSettlement")
	assert_eq(map.tile_types.size(), map.width * map.height)


func test_lesser_zone_build_map_applies_deltas() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.zone_id = "delta_test"
	z.zone_name = "Delta Test"
	z.zone_subtype = Enums.ZoneSubtype.SHRINE_CLEARING
	z.apply_delta(15, 15, Enums.TileType.WALL_STONE)
	var map: AsciiMapData = z.build_map()
	assert_eq(map.get_tile(15, 15), Enums.TileType.WALL_STONE)


func test_lesser_zone_build_map_no_delta_not_wall() -> void:
	var z: LesserZoneData = LesserZoneData.new()
	z.zone_id = "nodelay"
	z.zone_name = "No Delta"
	z.zone_subtype = Enums.ZoneSubtype.FARMLAND
	var map: AsciiMapData = z.build_map()
	# Farmland center (15,15) should be a crop or floor tile, not WALL_STONE.
	assert_ne(map.get_tile(15, 15), Enums.TileType.WALL_STONE)


# ---------------------------------------------------------------------------
# NavigationZoneData
# ---------------------------------------------------------------------------

func test_nav_zone_default_values() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	assert_eq(n.zone_id, "")
	assert_eq(n.zone_type, Enums.NavigationZoneType.STREET)
	assert_eq(n.parent_zone_id, "")
	assert_eq(n.child_zone_ids.size(), 0)
	assert_eq(n.exits.size(), 0)
	assert_false(n.has_ascii_map)
	assert_eq(n.zone_event_log.size(), 0)
	assert_eq(n.map_deltas.size(), 0)


func test_nav_zone_add_remove_child() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.add_child_zone("lesser_forge")
	n.add_child_zone("lesser_tea")
	assert_eq(n.child_zone_ids.size(), 2)
	assert_true(n.has_child_zone("lesser_forge"))
	n.remove_child_zone("lesser_forge")
	assert_eq(n.child_zone_ids.size(), 1)
	assert_false(n.has_child_zone("lesser_forge"))


func test_nav_zone_add_child_dedup() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.add_child_zone("lesser_a")
	n.add_child_zone("lesser_a")
	assert_eq(n.child_zone_ids.size(), 1)


func test_nav_zone_add_get_exit() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.add_exit("E", "nav_market")
	assert_eq(n.get_exit("E"), "nav_market")
	assert_eq(n.get_exit("W"), "")


func test_nav_zone_exit_update_existing() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.add_exit("N", "nav_a")
	n.add_exit("N", "nav_b")
	assert_eq(n.exits.size(), 1)
	assert_eq(n.get_exit("N"), "nav_b")


func test_nav_zone_log_event_requires_ascii_map() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.has_ascii_map = false
	n.log_event(1, "GOSSIP", 100)
	assert_eq(n.zone_event_log.size(), 0)


func test_nav_zone_log_event_with_ascii_map() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.has_ascii_map = true
	n.log_event(5, "PUBLIC_INSULT", 200, 10, 12)
	assert_eq(n.zone_event_log.size(), 1)
	assert_eq(n.zone_event_log[0]["character_id"], 5)


func test_nav_zone_apply_delta_requires_ascii_map() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.has_ascii_map = false
	n.apply_delta(5, 5, Enums.TileType.WALL_WOOD)
	assert_eq(n.map_deltas.size(), 0)


func test_nav_zone_apply_delta_with_ascii_map() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.has_ascii_map = true
	n.apply_delta(3, 7, Enums.TileType.DOOR_WOOD_OPEN)
	assert_true(n.has_delta(3, 7))


func test_nav_zone_purge_old_events() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.has_ascii_map = true
	n.log_event(1, "A", 0)
	n.log_event(2, "B", 200)
	n.purge_old_events(290)  # cutoff 200 — day 0 purged, day 200 kept
	assert_eq(n.zone_event_log.size(), 1)
	assert_eq(n.zone_event_log[0]["character_id"], 2)


func test_nav_zone_get_events_for_character() -> void:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.has_ascii_map = true
	n.log_event(7, "A", 10)
	n.log_event(8, "B", 11)
	n.log_event(7, "C", 12)
	var ev: Array = n.get_events_for_character(7)
	assert_eq(ev.size(), 2)


# ---------------------------------------------------------------------------
# GreaterZoneData
# ---------------------------------------------------------------------------

func test_greater_zone_default_values() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	assert_eq(g.zone_id, "")
	assert_eq(g.zone_name, "")
	assert_eq(g.zone_type, Enums.GreaterZoneType.SETTLEMENT)
	assert_eq(g.settlement_id, "")
	assert_eq(g.province_id, "")
	assert_eq(g.subtile_index, -1)
	assert_eq(g.child_zone_ids.size(), 0)
	assert_eq(g.exits.size(), 0)


func test_greater_zone_add_remove_child() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.add_child_zone("nav_market_district")
	g.add_child_zone("nav_castle")
	assert_eq(g.child_zone_ids.size(), 2)
	assert_true(g.has_child_zone("nav_market_district"))
	g.remove_child_zone("nav_market_district")
	assert_false(g.has_child_zone("nav_market_district"))
	assert_eq(g.child_zone_ids.size(), 1)


func test_greater_zone_add_child_dedup() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.add_child_zone("nav_x")
	g.add_child_zone("nav_x")
	assert_eq(g.child_zone_ids.size(), 1)


func test_greater_zone_add_get_exit() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.add_exit("N", "gz_garanto_north")
	assert_eq(g.get_exit("N"), "gz_garanto_north")
	assert_eq(g.get_exit("S"), "")


func test_greater_zone_exit_update_existing_direction() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.add_exit("E", "gz_a")
	g.add_exit("E", "gz_b")
	assert_eq(g.exits.size(), 1)
	assert_eq(g.get_exit("E"), "gz_b")


func test_greater_zone_remove_exit() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.add_exit("N", "gz_north")
	g.add_exit("S", "gz_south")
	g.remove_exit("N")
	assert_eq(g.exits.size(), 1)
	assert_eq(g.get_exit("N"), "")


func test_greater_zone_province_subtile_fields() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.zone_type = Enums.GreaterZoneType.PROVINCE_SUBTILE
	g.province_id = "hida_province"
	g.subtile_index = 2
	assert_eq(g.province_id, "hida_province")
	assert_eq(g.subtile_index, 2)


func test_greater_zone_settlement_fields() -> void:
	var g: GreaterZoneData = GreaterZoneData.new()
	g.zone_type = Enums.GreaterZoneType.SETTLEMENT
	g.settlement_id = "shiro_hida"
	assert_eq(g.settlement_id, "shiro_hida")


# ---------------------------------------------------------------------------
# Enum coverage
# ---------------------------------------------------------------------------

func test_greater_zone_type_has_three_values() -> void:
	# PROVINCE_SUBTILE, SETTLEMENT, TRAVEL_ROUTE
	assert_eq(Enums.GreaterZoneType.size(), 3)


func test_navigation_zone_type_has_twelve_values() -> void:
	# 9 urban + 3 wilderness per GDD v564 (PROVISIONAL)
	assert_eq(Enums.NavigationZoneType.size(), 12)
