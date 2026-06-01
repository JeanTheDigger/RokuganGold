extends GutTest

var _registry: ZoneRegistry


func before_each() -> void:
	_registry = ZoneRegistry.new()


func _make_gz(zone_id: String, settlement_id: int) -> GreaterZoneData:
	var gz := GreaterZoneData.new()
	gz.zone_id = zone_id
	gz.settlement_id = settlement_id
	return gz


func _make_nav(zone_id: String, settlement_id: int) -> NavigationZoneData:
	var nav := NavigationZoneData.new()
	nav.zone_id = zone_id
	nav.settlement_id = settlement_id
	return nav


func _make_lz(zone_id: String, settlement_id: int, nav_id: String) -> LesserZoneData:
	var lz := LesserZoneData.new()
	lz.zone_id = zone_id
	lz.settlement_id = settlement_id
	lz.parent_nav_zone_id = nav_id
	return lz


func _make_ws(gzs: Array, navs: Array, lzs: Array) -> Object:
	var ws := Object.new()
	ws.set_meta("greater_zones", gzs)
	ws.set_meta("navigation_zones", navs)
	ws.set_meta("lesser_zones", lzs)
	# Wrap in a script-less helper that supports .greater_zones etc.
	# Use a Dictionary-backed stub instead.
	return ws


# Helper: a lightweight stub that exposes typed array fields
class WsStub:
	var greater_zones: Array = []
	var navigation_zones: Array = []
	var lesser_zones: Array = []


func _make_stub(gzs: Array, navs: Array, lzs: Array) -> WsStub:
	var ws := WsStub.new()
	ws.greater_zones = gzs
	ws.navigation_zones = navs
	ws.lesser_zones = lzs
	return ws


# ---------------------------------------------------------------------------

func test_empty_world_state_builds_without_crash() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_zone("anything"), null)


func test_get_zone_returns_greater_zone() -> void:
	var gz := _make_gz("10_gz", 10)
	var ws := _make_stub([gz], [], [])
	_registry.build_from_world_state(ws)
	var found: Resource = _registry.get_zone("10_gz")
	assert_not_null(found)
	assert_eq((found as GreaterZoneData).settlement_id, 10)


func test_get_zone_returns_nav_zone() -> void:
	var nav := _make_nav("10_nav_castle", 10)
	var ws := _make_stub([], [nav], [])
	_registry.build_from_world_state(ws)
	var found: Resource = _registry.get_zone("10_nav_castle")
	assert_not_null(found)
	assert_eq((found as NavigationZoneData).settlement_id, 10)


func test_get_zone_returns_lesser_zone() -> void:
	var lz := _make_lz("10_lz_0", 10, "10_nav_castle")
	var ws := _make_stub([], [], [lz])
	_registry.build_from_world_state(ws)
	var found: Resource = _registry.get_zone("10_lz_0")
	assert_not_null(found)
	assert_eq((found as LesserZoneData).settlement_id, 10)


func test_get_zone_returns_null_for_missing_id() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_null(_registry.get_zone("99_gz"))


func test_get_greater_zone_for_settlement() -> void:
	var gz := _make_gz("5_gz", 5)
	var ws := _make_stub([gz], [], [])
	_registry.build_from_world_state(ws)
	var found := _registry.get_greater_zone_for_settlement(5)
	assert_not_null(found)
	assert_eq(found.zone_id, "5_gz")


func test_get_greater_zone_returns_null_for_missing_settlement() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_null(_registry.get_greater_zone_for_settlement(99))


func test_get_nav_zones_for_settlement_returns_all() -> void:
	var nav1 := _make_nav("3_nav_castle", 3)
	var nav2 := _make_nav("3_nav_market", 3)
	var nav3 := _make_nav("7_nav_castle", 7)
	var ws := _make_stub([], [nav1, nav2, nav3], [])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_nav_zones_for_settlement(3)
	assert_eq(found.size(), 2)


func test_get_nav_zones_for_settlement_returns_empty_array_for_missing() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_nav_zones_for_settlement(99).size(), 0)


func test_get_lesser_zones_for_nav() -> void:
	var lz1 := _make_lz("3_lz_castle_0", 3, "3_nav_castle")
	var lz2 := _make_lz("3_lz_castle_1", 3, "3_nav_castle")
	var lz3 := _make_lz("3_lz_market_0", 3, "3_nav_market")
	var ws := _make_stub([], [], [lz1, lz2, lz3])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_lesser_zones_for_nav("3_nav_castle")
	assert_eq(found.size(), 2)


func test_get_lesser_zones_for_nav_returns_empty_for_missing() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_lesser_zones_for_nav("99_nav_castle").size(), 0)


func test_get_all_lesser_zones_for_settlement() -> void:
	var lz1 := _make_lz("4_lz_castle_0", 4, "4_nav_castle")
	var lz2 := _make_lz("4_lz_market_0", 4, "4_nav_market")
	var lz3 := _make_lz("9_lz_castle_0", 9, "9_nav_castle")
	var ws := _make_stub([], [], [lz1, lz2, lz3])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_all_lesser_zones_for_settlement(4)
	assert_eq(found.size(), 2)


func test_get_all_lesser_zones_for_settlement_returns_empty_for_missing() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_all_lesser_zones_for_settlement(99).size(), 0)


func test_rebuild_clears_previous_state() -> void:
	var gz_a := _make_gz("1_gz", 1)
	var ws_a := _make_stub([gz_a], [], [])
	_registry.build_from_world_state(ws_a)
	assert_not_null(_registry.get_greater_zone_for_settlement(1))

	var gz_b := _make_gz("2_gz", 2)
	var ws_b := _make_stub([gz_b], [], [])
	_registry.build_from_world_state(ws_b)
	assert_null(_registry.get_greater_zone_for_settlement(1))
	assert_not_null(_registry.get_greater_zone_for_settlement(2))


func test_multiple_settlements_independent() -> void:
	var gz1 := _make_gz("1_gz", 1)
	var gz2 := _make_gz("2_gz", 2)
	var nav1 := _make_nav("1_nav_castle", 1)
	var nav2 := _make_nav("2_nav_castle", 2)
	var lz1 := _make_lz("1_lz_0", 1, "1_nav_castle")
	var lz2 := _make_lz("2_lz_0", 2, "2_nav_castle")
	var ws := _make_stub([gz1, gz2], [nav1, nav2], [lz1, lz2])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_all_lesser_zones_for_settlement(1).size(), 1)
	assert_eq(_registry.get_all_lesser_zones_for_settlement(2).size(), 1)
	assert_eq(_registry.get_nav_zones_for_settlement(1).size(), 1)
	assert_eq(_registry.get_nav_zones_for_settlement(2).size(), 1)
