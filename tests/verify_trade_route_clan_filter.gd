extends SceneTree
## Runtime driver for the s4.3.17 Rung-3 trade-route clan filter. _has_active_trade_routes ignored its
## _clan param and returned true if ANY undisrupted route existed anywhere in the world, so the feasibility
## ladder's Market-Purchase rung (blocked when has_trade_routes is false) mis-fired: a clan with NO routes
## of its own wrongly passed the gate, and disrupting a clan's routes failed to block their market purchase
## (defeating trade-disruption as a war-pressure mechanic). Fix: filter to undisrupted routes that connect
## one of the clan's OWN provinces (s4.3.18 a route connects two provinces; the caller already computes the
## clan's province ids). No invented values -- pure structural filter.
## Run: godot --headless -s tests/verify_trade_route_clan_filter.gd

const _NPC := preload("res://simulation/npc_decision_engine.gd")
const _TRD := preload("res://shared/trade_route_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _route(a: int, b: int, disrupted: bool) -> TradeRouteData:
	var r: TradeRouteData = _TRD.new()
	r.province_a_id = a
	r.province_b_id = b
	r.is_disrupted = disrupted
	return r


func _init() -> void:
	print("--- s4.3.17 trade-route clan filter ---")
	# Clan controls provinces [10, 11]. Another clan controls [20, 21].
	var clan_pids: Array = [10, 11]
	# A route entirely between the OTHER clan's provinces, undisrupted -> must NOT count for our clan.
	var foreign_route: TradeRouteData = _route(20, 21, false)
	_ok(not _NPC._has_active_trade_routes([foreign_route], clan_pids),
		"undisrupted route between OTHER clan's provinces -> not our route (was the bug: returned true)")
	# A route connecting one of our provinces (10) to a neighbor (20), undisrupted -> counts.
	var our_route: TradeRouteData = _route(10, 20, false)
	_ok(_NPC._has_active_trade_routes([our_route], clan_pids),
		"undisrupted route touching our province -> has active route")
	# Same route, but DISRUPTED -> does not count (trade-disruption blocks the rung).
	var our_disrupted: TradeRouteData = _route(10, 20, true)
	_ok(not _NPC._has_active_trade_routes([our_disrupted], clan_pids),
		"our route disrupted -> no active route (disruption blocks market purchase)")
	# Mixed: our disrupted route + a foreign undisrupted route -> still no active route for us.
	_ok(not _NPC._has_active_trade_routes([our_disrupted, foreign_route], clan_pids),
		"our route cut + foreign route active -> still blocked for us")
	# Our route on province_b side (province 11) -> counts (connects() is symmetric).
	var our_route_b: TradeRouteData = _route(30, 11, false)
	_ok(_NPC._has_active_trade_routes([our_route_b], clan_pids),
		"route touching our province on the b-side -> counts")
	# No routes at all -> false.
	_ok(not _NPC._has_active_trade_routes([], clan_pids), "no routes -> false")
	# Clan with no provinces -> never has active routes even with world routes present.
	_ok(not _NPC._has_active_trade_routes([our_route, foreign_route], []),
		"clan with no provinces -> no active route")
	# Dictionary-form route (defensive fallback) filters by province ids too.
	var dict_route_ours: Dictionary = {"province_a_id": 10, "province_b_id": 40, "is_disrupted": false}
	var dict_route_foreign: Dictionary = {"province_a_id": 20, "province_b_id": 40, "is_disrupted": false}
	_ok(_NPC._has_active_trade_routes([dict_route_ours], clan_pids), "dict route touching our province -> counts")
	_ok(not _NPC._has_active_trade_routes([dict_route_foreign], clan_pids), "dict route not touching us -> no")
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
