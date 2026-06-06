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
		if gz.settlement_id >= 0:
			_gz_by_settlement[gz.settlement_id] = gz

	for nav: NavigationZoneData in ws.navigation_zones:
		_zone_by_id[nav.zone_id] = nav
		# Bug 11 FIX: NavigationZoneData has no settlement_id field.
		# Derive settlement by walking up to the parent GreaterZoneData.
		var parent_gz: GreaterZoneData = _zone_by_id.get(nav.parent_zone_id) as GreaterZoneData
		if parent_gz != null and parent_gz.settlement_id >= 0:
			var sid: int = parent_gz.settlement_id
			if not _nav_by_settlement.has(sid):
				_nav_by_settlement[sid] = []
			_nav_by_settlement[sid].append(nav)

	for lz: LesserZoneData in ws.lesser_zones:
		_zone_by_id[lz.zone_id] = lz
		# Bug 11 FIX: correct field is parent_zone_id, not the non-existent parent_nav_zone_id.
		var lz_parent_id: String = lz.parent_zone_id
		if not _lz_by_nav.has(lz_parent_id):
			_lz_by_nav[lz_parent_id] = []
		_lz_by_nav[lz_parent_id].append(lz)
		# Bug 11 FIX: LesserZoneData has no settlement_id field.
		# Derive settlement by walking up through parent NavigationZone or directly to GreaterZone.
		var gz: GreaterZoneData = null
		var parent: Resource = _zone_by_id.get(lz_parent_id)
		if parent is GreaterZoneData:
			gz = parent as GreaterZoneData
		elif parent is NavigationZoneData:
			gz = _zone_by_id.get((parent as NavigationZoneData).parent_zone_id) as GreaterZoneData
		if gz != null and gz.settlement_id >= 0:
			var sid: int = gz.settlement_id
			if not _lz_by_settlement.has(sid):
				_lz_by_settlement[sid] = []
			_lz_by_settlement[sid].append(lz)


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
