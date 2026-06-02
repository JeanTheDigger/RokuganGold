class_name ZoneRegistry
## Runtime lookup index for the zone graph (s4.4.1).
## Build once from WorldState after load; query throughout the day.
## Plain class — no Node inheritance.

var _zone_by_id: Dictionary = {}
var _gz_by_settlement: Dictionary = {}
var _nav_by_settlement: Dictionary = {}
var _lz_by_nav: Dictionary = {}
var _lz_by_settlement: Dictionary = {}


func build_from_world_state(ws: Object) -> void:
	_zone_by_id.clear()
	_gz_by_settlement.clear()
	_nav_by_settlement.clear()
	_lz_by_nav.clear()
	_lz_by_settlement.clear()

	for gz: GreaterZoneData in ws.greater_zones:
		_zone_by_id[gz.zone_id] = gz
		_gz_by_settlement[gz.settlement_id] = gz

	for nav: NavigationZoneData in ws.navigation_zones:
		_zone_by_id[nav.zone_id] = nav
		if not _nav_by_settlement.has(nav.settlement_id):
			_nav_by_settlement[nav.settlement_id] = []
		_nav_by_settlement[nav.settlement_id].append(nav)

	for lz: LesserZoneData in ws.lesser_zones:
		_zone_by_id[lz.zone_id] = lz
		if not _lz_by_nav.has(lz.parent_nav_zone_id):
			_lz_by_nav[lz.parent_nav_zone_id] = []
		_lz_by_nav[lz.parent_nav_zone_id].append(lz)
		if not _lz_by_settlement.has(lz.settlement_id):
			_lz_by_settlement[lz.settlement_id] = []
		_lz_by_settlement[lz.settlement_id].append(lz)


func get_zone(zone_id: String) -> Resource:
	return _zone_by_id.get(zone_id, null)


func get_greater_zone_for_settlement(settlement_id: int) -> GreaterZoneData:
	return _gz_by_settlement.get(settlement_id, null)


func get_nav_zones_for_settlement(settlement_id: int) -> Array:
	return _nav_by_settlement.get(settlement_id, [])


func get_lesser_zones_for_nav(nav_zone_id: String) -> Array:
	return _lz_by_nav.get(nav_zone_id, [])


func get_all_lesser_zones_for_settlement(settlement_id: int) -> Array:
	return _lz_by_settlement.get(settlement_id, [])
