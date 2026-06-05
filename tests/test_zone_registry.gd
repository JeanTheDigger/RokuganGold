extends GutTest

var _registry: ZoneRegistry


func before_each() -> void:
	_registry = ZoneRegistry.new()


func _make_gz(zone_id: String, settlement_id: int) -> GreaterZoneData:
	var gz := GreaterZoneData.new()
	gz.zone_id = zone_id
	gz.settlement_id = settlement_id
	return gz


func _make_nav(zone_id: String, parent_gz_zone_id: String) -> NavigationZoneData:
	# Bug 11 FIX: NavigationZoneData has no settlement_id; wire via parent_zone_id relationship.
	var nav := NavigationZoneData.new()
	nav.zone_id = zone_id
	nav.parent_zone_id = parent_gz_zone_id
	return nav


func _make_lz(zone_id: String, parent_id: String) -> LesserZoneData:
	# Bug 11 FIX: LesserZoneData has no settlement_id or parent_nav_zone_id;
	# use parent_zone_id only. Parent can be gz or nav zone_id.
	var lz := LesserZoneData.new()
	lz.zone_id = zone_id
	lz.parent_zone_id = parent_id
	return lz


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
	# Bug 11 FIX: NavigationZoneData has no settlement_id; verify zone_id and type only.
	var gz := _make_gz("10_gz", 10)
	var nav := _make_nav("10_nav_castle", "10_gz")
	var ws := _make_stub([gz], [nav], [])
	_registry.build_from_world_state(ws)
	var found: Resource = _registry.get_zone("10_nav_castle")
	assert_not_null(found)
	assert_true(found is NavigationZoneData, "returned resource must be NavigationZoneData")
	assert_eq(found.zone_id, "10_nav_castle")


func test_get_zone_returns_lesser_zone() -> void:
	# Bug 11 FIX: LesserZoneData has no settlement_id; verify zone_id and type only.
	var gz := _make_gz("10_gz", 10)
	var nav := _make_nav("10_nav_castle", "10_gz")
	var lz := _make_lz("10_lz_0", "10_nav_castle")
	var ws := _make_stub([gz], [nav], [lz])
	_registry.build_from_world_state(ws)
	var found: Resource = _registry.get_zone("10_lz_0")
	assert_not_null(found)
	assert_true(found is LesserZoneData, "returned resource must be LesserZoneData")
	assert_eq(found.zone_id, "10_lz_0")


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
	# Bug 11 FIX: registry derives settlement for nav zones by traversing parent_zone_id to gz.
	# Must include gz nodes so the parent chain resolves.
	var gz3 := _make_gz("3_gz", 3)
	var gz7 := _make_gz("7_gz", 7)
	var nav1 := _make_nav("3_nav_castle", "3_gz")
	var nav2 := _make_nav("3_nav_market", "3_gz")
	var nav3 := _make_nav("7_nav_castle", "7_gz")
	var ws := _make_stub([gz3, gz7], [nav1, nav2, nav3], [])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_nav_zones_for_settlement(3)
	assert_eq(found.size(), 2)


func test_get_nav_zones_for_settlement_returns_empty_array_for_missing() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_nav_zones_for_settlement(99).size(), 0)


func test_get_lesser_zones_for_nav() -> void:
	# _lz_by_nav is keyed directly by lz.parent_zone_id string — no gz needed here.
	var lz1 := _make_lz("3_lz_castle_0", "3_nav_castle")
	var lz2 := _make_lz("3_lz_castle_1", "3_nav_castle")
	var lz3 := _make_lz("3_lz_market_0", "3_nav_market")
	var ws := _make_stub([], [], [lz1, lz2, lz3])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_lesser_zones_for_nav("3_nav_castle")
	assert_eq(found.size(), 2)


func test_get_lesser_zones_for_nav_returns_empty_for_missing() -> void:
	var ws := _make_stub([], [], [])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_lesser_zones_for_nav("99_nav_castle").size(), 0)


func test_get_all_lesser_zones_for_settlement() -> void:
	# Bug 11 FIX: registry derives settlement for lz zones via nav→gz parent chain.
	# Must include both gz and nav nodes for the chain to resolve.
	var gz4 := _make_gz("4_gz", 4)
	var gz9 := _make_gz("9_gz", 9)
	var nav_castle4 := _make_nav("4_nav_castle", "4_gz")
	var nav_market4 := _make_nav("4_nav_market", "4_gz")
	var nav_castle9 := _make_nav("9_nav_castle", "9_gz")
	var lz1 := _make_lz("4_lz_castle_0", "4_nav_castle")
	var lz2 := _make_lz("4_lz_market_0", "4_nav_market")
	var lz3 := _make_lz("9_lz_castle_0", "9_nav_castle")
	var ws := _make_stub([gz4, gz9], [nav_castle4, nav_market4, nav_castle9], [lz1, lz2, lz3])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_all_lesser_zones_for_settlement(4)
	assert_eq(found.size(), 2)


func test_get_all_lesser_zones_for_settlement_direct_gz_parent() -> void:
	# Simple settlements skip the Navigation Zone tier: lzs parent directly to the gz.
	var gz := _make_gz("20_gz", 20)
	var lz1 := _make_lz("20_lz_shrine", "20_gz")
	var lz2 := _make_lz("20_lz_market", "20_gz")
	var ws := _make_stub([gz], [], [lz1, lz2])
	_registry.build_from_world_state(ws)
	var found: Array = _registry.get_all_lesser_zones_for_settlement(20)
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
	# Bug 11 FIX: navs and lzs now wired via parent_zone_id to their gz.
	# gz nodes included so the parent chain resolves for both nav and lz lookups.
	var gz1 := _make_gz("1_gz", 1)
	var gz2 := _make_gz("2_gz", 2)
	var nav1 := _make_nav("1_nav_castle", "1_gz")
	var nav2 := _make_nav("2_nav_castle", "2_gz")
	var lz1 := _make_lz("1_lz_0", "1_nav_castle")
	var lz2 := _make_lz("2_lz_0", "2_nav_castle")
	var ws := _make_stub([gz1, gz2], [nav1, nav2], [lz1, lz2])
	_registry.build_from_world_state(ws)
	assert_eq(_registry.get_all_lesser_zones_for_settlement(1).size(), 1)
	assert_eq(_registry.get_all_lesser_zones_for_settlement(2).size(), 1)
	assert_eq(_registry.get_nav_zones_for_settlement(1).size(), 1)
	assert_eq(_registry.get_nav_zones_for_settlement(2).size(), 1)


func test_gz_with_no_settlement_not_indexed() -> void:
	# gz.settlement_id == -1 (sentinel) must not produce a registry entry.
	var gz := _make_gz("wild_gz", -1)
	var ws := _make_stub([gz], [], [])
	_registry.build_from_world_state(ws)
	assert_null(_registry.get_greater_zone_for_settlement(-1))
	assert_not_null(_registry.get_zone("wild_gz"), "zone is still reachable by ID")


func test_nav_with_unregistered_parent_not_indexed_for_settlement() -> void:
	# If the nav's parent gz is missing from the stub, the nav cannot be
	# resolved to a settlement but must still appear in get_zone().
	var nav := _make_nav("orphan_nav", "nonexistent_gz")
	var ws := _make_stub([], [nav], [])
	_registry.build_from_world_state(ws)
	assert_not_null(_registry.get_zone("orphan_nav"))
	assert_eq(_registry.get_nav_zones_for_settlement(5).size(), 0)
