class_name SettlementZoneBuilder
## Factory that constructs the zone graph for a SettlementData.
## Rules: s4.4.1 LOCKED + Amendment v564 + s57.36.2 LOCKED.
##
## Output dict keys:
##   "greater_zone"      : GreaterZoneData
##   "navigation_zones"  : Array of NavigationZoneData
##   "lesser_zones"      : Array of LesserZoneData
##
## Zone IDs are deterministic from settlement_id — identical inputs always
## produce the same graph. No random state is used.
##
## Key rules:
##   Castle/Estate Compound is always a Navigation Zone for CITY_DAIMYO+ rank
##   or any military settlement type (s4.4.1 v564).
##   Village Headman civilian settlements skip the nav tier: Lesser Zones
##   parent directly to the Greater Zone (s4.4.1 v564).

# PU thresholds per s4.4.1 LOCKED
const PU_TOWN: int = 500
const PU_CITY: int = 2000
const PU_MAJOR: int = 5000

# Castle interior zone subtype lists by lord rank (s57.36.2 LOCKED).
# Array index == Enums.LordRank enum value (0 = VILLAGE_HEADMAN … 5 = IMPERIAL).
const CASTLE_SUBTYPES_BY_RANK: Array = [
	# VILLAGE_HEADMAN — 2 interior zones (combined great hall + yard)
	[Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.OUTER_COURTYARD],
	# CITY_DAIMYO — 3 interior zones (GUEST_WING absorbed into AUDIENCE_CHAMBER, s57.36.2)
	[Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.AUDIENCE_CHAMBER,
	 Enums.ZoneSubtype.OUTER_COURTYARD],
	# PROVINCIAL_DAIMYO — 4 interior zones
	[Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.AUDIENCE_CHAMBER,
	 Enums.ZoneSubtype.GUEST_WING, Enums.ZoneSubtype.OUTER_COURTYARD],
	# FAMILY_DAIMYO — 6 interior zones
	[Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.AUDIENCE_CHAMBER,
	 Enums.ZoneSubtype.GUEST_WING, Enums.ZoneSubtype.ENKAI_HALL,
	 Enums.ZoneSubtype.TSUBONIWA, Enums.ZoneSubtype.CASTLE_SHRINE],
	# CLAN_CHAMPION — 8 interior zones
	[Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.AUDIENCE_CHAMBER,
	 Enums.ZoneSubtype.GUEST_WING, Enums.ZoneSubtype.ENKAI_HALL,
	 Enums.ZoneSubtype.TSUBONIWA, Enums.ZoneSubtype.CASTLE_SHRINE,
	 Enums.ZoneSubtype.DOJO, Enums.ZoneSubtype.WAR_COUNCIL_ROOM],
	# IMPERIAL — 10 base zones (Otosan Uchi is handcrafted; this is the procedural fallback)
	[Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.AUDIENCE_CHAMBER,
	 Enums.ZoneSubtype.GUEST_WING, Enums.ZoneSubtype.ENKAI_HALL,
	 Enums.ZoneSubtype.TSUBONIWA, Enums.ZoneSubtype.CASTLE_SHRINE,
	 Enums.ZoneSubtype.LORD_QUARTERS, Enums.ZoneSubtype.CHASHITSU,
	 Enums.ZoneSubtype.DOJO, Enums.ZoneSubtype.WAR_COUNCIL_ROOM],
]

# Compass direction pairs for exit wiring: (forward, reverse).
# Hub-and-spoke: hub (index 0) gets dir_fwd, spoke gets dir_rev.
const _HUB_DIRS: Array[String] = ["N", "E", "S", "W", "NE", "NW", "SE", "SW"]
const _HUB_DIRS_REV: Array[String] = ["S", "W", "N", "E", "SW", "SE", "NW", "NE"]

# Sequential direction pairs for civilian zone chains: (forward, reverse).
const _SEQ_DIRS: Array[String] = ["N", "E", "S", "W"]
const _SEQ_DIRS_REV: Array[String] = ["S", "W", "N", "E"]

const _CASTLE_SUBTYPE_NAMES: Dictionary = {
	Enums.ZoneSubtype.OHIROMA: "Ohiroma",
	Enums.ZoneSubtype.AUDIENCE_CHAMBER: "Audience Chamber",
	Enums.ZoneSubtype.GUEST_WING: "Guest Wing",
	Enums.ZoneSubtype.LORD_QUARTERS: "Lord's Quarters",
	Enums.ZoneSubtype.ENKAI_HALL: "Enkai Hall",
	Enums.ZoneSubtype.CHASHITSU: "Chashitsu",
	Enums.ZoneSubtype.WAR_COUNCIL_ROOM: "War Council Room",
	Enums.ZoneSubtype.DOJO: "Dojo",
	Enums.ZoneSubtype.OUTER_COURTYARD: "Outer Courtyard",
	Enums.ZoneSubtype.TSUBONIWA: "Tsuboniwa",
	Enums.ZoneSubtype.CASTLE_SHRINE: "Castle Shrine",
}


static func build(
	settlement: SettlementData,
	is_coastal: bool,
	lord_rank: int,
) -> Dictionary:
	var sid: int = settlement.settlement_id
	var sname: String = settlement.settlement_name
	var stype: int = settlement.settlement_type
	var pu: int = settlement.population_pu

	var gz: GreaterZoneData = _make_gz(sid, sname)
	var nav_zones: Array = []
	var lesser_zones: Array = []

	var is_military: bool = stype in Enums.MILITARY_SETTLEMENT_TYPES
	var is_religious: bool = stype in Enums.RELIGIOUS_SETTLEMENT_TYPES

	# Castle Compound Navigation Zone: created for military types or CITY_DAIMYO+ rank.
	# Village Headman with civilian settlement: nav tier skipped per s4.4.1 v564.
	var use_castle_nav: bool = is_military or lord_rank >= Enums.LordRank.CITY_DAIMYO

	if use_castle_nav:
		var castle_nav: NavigationZoneData = _make_nav(
			"%d_nav_castle" % sid,
			"%s — Castle Compound" % sname,
			Enums.NavigationZoneType.CASTLE_COMPOUND,
			"%d_gz" % sid,
		)
		nav_zones.append(castle_nav)
		gz.add_child_zone(castle_nav.zone_id)

		var rank_idx: int = clamp(lord_rank, 0, CASTLE_SUBTYPES_BY_RANK.size() - 1)
		var subtypes: Array = CASTLE_SUBTYPES_BY_RANK[rank_idx]
		var castle_lzs: Array = []
		for i: int in range(subtypes.size()):
			var subtype: int = subtypes[i]
			var lz: LesserZoneData = _make_lz(
				"%d_lz_castle_%d" % [sid, i],
				"%s — %s" % [sname, _castle_name(subtype)],
				subtype,
				castle_nav.zone_id,
			)
			castle_lzs.append(lz)
			castle_nav.add_child_zone(lz.zone_id)
		_wire_castle_hub(castle_lzs)
		lesser_zones.append_array(castle_lzs)

	elif lord_rank == Enums.LordRank.VILLAGE_HEADMAN:
		# Nav tier skipped: 2 interior Lesser Zones parent directly to Greater Zone.
		var headman_subtypes: Array = CASTLE_SUBTYPES_BY_RANK[Enums.LordRank.VILLAGE_HEADMAN]
		var headman_lzs: Array = []
		for i: int in range(headman_subtypes.size()):
			var subtype: int = headman_subtypes[i]
			var lz: LesserZoneData = _make_lz(
				"%d_lz_castle_%d" % [sid, i],
				"%s — %s" % [sname, _castle_name(subtype)],
				subtype,
				"%d_gz" % sid,
			)
			headman_lzs.append(lz)
			gz.add_child_zone(lz.zone_id)
		_wire_castle_hub(headman_lzs)
		lesser_zones.append_array(headman_lzs)

	# Fill zones (urban / wilderness) — parented to the Greater Zone.
	var fill_lzs: Array
	if is_religious:
		fill_lzs = _build_religious_fill(stype, is_coastal, sid, sname, gz.zone_id)
	else:
		fill_lzs = _build_civilian_fill(
			stype, pu, is_coastal, use_castle_nav, sid, sname, gz.zone_id
		)

	for lz: LesserZoneData in fill_lzs:
		lesser_zones.append(lz)
		gz.add_child_zone(lz.zone_id)
	_wire_sequential(fill_lzs)

	return {
		"greater_zone": gz,
		"navigation_zones": nav_zones,
		"lesser_zones": lesser_zones,
	}


# -- Fill zone builders -------------------------------------------------------

static func _build_civilian_fill(
	stype: int,
	pu: int,
	is_coastal: bool,
	has_castle: bool,
	sid: int,
	sname: String,
	parent_id: String,
) -> Array:
	# Pure military fortifications and wall towers carry no civilian population.
	if stype == Enums.SettlementType.WALL_TOWER or stype == Enums.SettlementType.FORTIFICATION:
		return []

	var pool: Array = _civilian_pool(stype, pu, is_coastal)

	# Castle zones already contribute to the Lesser Zone budget.
	# Trim the fill pool so the total stays within the GDD range.
	if has_castle:
		if pu >= PU_MAJOR:
			pool = pool.slice(0, mini(pool.size(), 6))
		elif pu >= PU_CITY:
			pool = pool.slice(0, mini(pool.size(), 4))
		elif pu >= PU_TOWN:
			pool = pool.slice(0, mini(pool.size(), 2))
		else:
			pool = pool.slice(0, mini(pool.size(), 1))

	var lzs: Array = []
	for i: int in range(pool.size()):
		var subtype: int = pool[i]
		lzs.append(_make_lz(
			"%d_lz_%d" % [sid, i],
			"%s — %s" % [sname, _urban_name(subtype)],
			subtype,
			parent_id,
		))
	return lzs


static func _build_religious_fill(
	stype: int,
	is_coastal: bool,
	sid: int,
	sname: String,
	parent_id: String,
) -> Array:
	var pool: Array = []
	match stype:
		Enums.SettlementType.SHINDEN:
			pool = [
				Enums.ZoneSubtype.TEMPLE_GROUNDS,
				Enums.ZoneSubtype.TEMPLE_GROUNDS,
				Enums.ZoneSubtype.SHRINE_CLEARING,
			]
		Enums.SettlementType.MONASTERY:
			pool = [
				Enums.ZoneSubtype.TEMPLE_GROUNDS,
				Enums.ZoneSubtype.SHRINE_CLEARING,
				Enums.ZoneSubtype.FARMLAND,
			]
		_:  # TEMPLE
			pool = [Enums.ZoneSubtype.TEMPLE_GROUNDS, Enums.ZoneSubtype.SHRINE_CLEARING]
			if is_coastal:
				pool.append(Enums.ZoneSubtype.DOCKS_WATERFRONT)

	var lzs: Array = []
	for i: int in range(pool.size()):
		var subtype: int = pool[i]
		lzs.append(_make_lz(
			"%d_lz_%d" % [sid, i],
			"%s — %s" % [sname, _urban_name(subtype)],
			subtype,
			parent_id,
		))
	return lzs


# Pool of civilian zone subtypes ordered by priority for the given PU tier.
static func _civilian_pool(stype: int, pu: int, is_coastal: bool) -> Array:
	# Military settlements (KEEP, CASTLE, FAMILY_CASTLE) get a support market.
	if stype in Enums.MILITARY_SETTLEMENT_TYPES:
		var mp: Array = [Enums.ZoneSubtype.MARKET_STREET]
		if pu >= PU_TOWN:
			mp.append(Enums.ZoneSubtype.RESIDENTIAL_QUARTER)
		if pu >= PU_CITY:
			mp.append(Enums.ZoneSubtype.TEMPLE_GROUNDS)
		return mp

	if pu < PU_TOWN:  # Village: 2–3 total zones
		var p: Array = [Enums.ZoneSubtype.FARMLAND, Enums.ZoneSubtype.SHRINE_CLEARING]
		if is_coastal:
			p.append(Enums.ZoneSubtype.DOCKS_WATERFRONT)
		return p

	if pu < PU_CITY:  # Town: 4–6 total zones
		var p: Array = [
			Enums.ZoneSubtype.MARKET_STREET,
			Enums.ZoneSubtype.RESIDENTIAL_QUARTER,
			Enums.ZoneSubtype.TEMPLE_GROUNDS,
			Enums.ZoneSubtype.POOR_QUARTER,
		]
		if is_coastal:
			p.insert(3, Enums.ZoneSubtype.DOCKS_WATERFRONT)
		return p

	if pu < PU_MAJOR:  # City: 7–10 total zones
		var p: Array = [
			Enums.ZoneSubtype.MARKET_STREET,
			Enums.ZoneSubtype.RESIDENTIAL_QUARTER,
			Enums.ZoneSubtype.TEMPLE_GROUNDS,
			Enums.ZoneSubtype.PLEASURE_QUARTER,
			Enums.ZoneSubtype.POOR_QUARTER,
			Enums.ZoneSubtype.GOVERNMENT_QUARTER,
		]
		if is_coastal:
			p.insert(4, Enums.ZoneSubtype.DOCKS_WATERFRONT)
		return p

	# Major city: 10–15 total zones
	var p: Array = [
		Enums.ZoneSubtype.MARKET_STREET,
		Enums.ZoneSubtype.RESIDENTIAL_QUARTER,
		Enums.ZoneSubtype.TEMPLE_GROUNDS,
		Enums.ZoneSubtype.PLEASURE_QUARTER,
		Enums.ZoneSubtype.POOR_QUARTER,
		Enums.ZoneSubtype.GOVERNMENT_QUARTER,
		Enums.ZoneSubtype.MARKET_STREET,
		Enums.ZoneSubtype.RESIDENTIAL_QUARTER,
		Enums.ZoneSubtype.GOVERNMENT_QUARTER,
	]
	if is_coastal:
		p.insert(4, Enums.ZoneSubtype.DOCKS_WATERFRONT)
	return p


# -- Zone object constructors -------------------------------------------------

static func _make_gz(sid: int, sname: String) -> GreaterZoneData:
	var gz: GreaterZoneData = GreaterZoneData.new()
	gz.zone_id = "%d_gz" % sid
	gz.zone_name = sname
	gz.zone_type = Enums.GreaterZoneType.SETTLEMENT
	gz.settlement_id = sid  # Bug 11 FIX: was str(sid); field is now int
	return gz


static func _make_nav(
	zone_id: String,
	zone_name: String,
	zone_type: int,
	parent_id: String,
) -> NavigationZoneData:
	var n: NavigationZoneData = NavigationZoneData.new()
	n.zone_id = zone_id
	n.zone_name = zone_name
	n.zone_type = zone_type
	n.parent_zone_id = parent_id
	return n


static func _make_lz(
	zone_id: String,
	zone_name: String,
	subtype: int,
	parent_id: String,
) -> LesserZoneData:
	var lz: LesserZoneData = LesserZoneData.new()
	lz.zone_id = zone_id
	lz.zone_name = zone_name
	lz.zone_subtype = subtype
	lz.parent_zone_id = parent_id
	return lz


# -- Exit wiring --------------------------------------------------------------

# Hub-and-spoke: zones[0] is the hub (OHIROMA); all others connect to it.
static func _wire_castle_hub(zones: Array) -> void:
	if zones.size() < 2:
		return
	var hub: LesserZoneData = zones[0]
	for i: int in range(1, zones.size()):
		var spoke: LesserZoneData = zones[i]
		var dir_idx: int = (i - 1) % _HUB_DIRS.size()
		hub.add_exit(_HUB_DIRS[dir_idx], spoke.zone_id)
		spoke.add_exit(_HUB_DIRS_REV[dir_idx], hub.zone_id)


# Sequential chain: zones[i] → zones[i+1] with N/E/S/W cycling.
static func _wire_sequential(zones: Array) -> void:
	for i: int in range(zones.size() - 1):
		var a: LesserZoneData = zones[i]
		var b: LesserZoneData = zones[i + 1]
		var dir_idx: int = i % _SEQ_DIRS.size()
		a.add_exit(_SEQ_DIRS[dir_idx], b.zone_id)
		b.add_exit(_SEQ_DIRS_REV[dir_idx], a.zone_id)


# -- Name helpers -------------------------------------------------------------

static func _castle_name(subtype: int) -> String:
	return _CASTLE_SUBTYPE_NAMES.get(subtype, "Room")


static func _urban_name(subtype: int) -> String:
	match subtype:
		Enums.ZoneSubtype.MARKET_STREET:       return "Market Street"
		Enums.ZoneSubtype.RESIDENTIAL_QUARTER: return "Residential Quarter"
		Enums.ZoneSubtype.TEMPLE_GROUNDS:      return "Temple Grounds"
		Enums.ZoneSubtype.PLEASURE_QUARTER:    return "Pleasure Quarter"
		Enums.ZoneSubtype.DOCKS_WATERFRONT:    return "Docks and Waterfront"
		Enums.ZoneSubtype.POOR_QUARTER:        return "Poor Quarter"
		Enums.ZoneSubtype.GOVERNMENT_QUARTER:  return "Government Quarter"
		Enums.ZoneSubtype.FARMLAND:            return "Farmland"
		Enums.ZoneSubtype.SHRINE_CLEARING:     return "Shrine Clearing"
		_:                                      return "Zone"
