class_name OtosanUchiZoneBuilder
## Zone graph builder for Otosan Uchi, the Imperial Capital (GDD s2.3.23).
##
## Otosan Uchi is the only IMPERIAL_CAPITAL settlement in the Empire. Instead of
## the procedural city fill SettlementZoneBuilder produces for ordinary cities,
## the capital is a fixed set of 16 hand-defined districts across three concentric
## access tiers (Toshisoto 11, Ekohikei 4, Forbidden City 1).
##
## This file is the SINGLE SOURCE OF TRUTH for district data. The world population
## generator reads DISTRICTS (and district_zone_id) to create the matching Governor
## roster, and the bootstrap links each Governor to its district zone after the
## graph is built. Both sides join on the deterministic zone_id, so the district
## table never has to be duplicated.
##
## Tier-1 handcrafted interior maps (Section 4.3.4) are out of scope: these
## districts are pure MUD-navigation containers (has_ascii_map = false) for now.
##
## PU subdivision sums to the canonical 100 (Toshisoto 82 + Ekohikei 15 +
## Forbidden 3), matching the settlement's population_pu.

const TOSHISOTO := Enums.AccessLayer.TOSHISOTO
const EKOHIKEI := Enums.AccessLayer.EKOHIKEI
const FORBIDDEN := Enums.AccessLayer.FORBIDDEN_CITY

# The 16 districts in canonical order (indices are stable join keys).
# Each entry:
#   sentaku  — permanent internal name (s2.3.23)
#   name     — display zone name
#   layer    — Enums.AccessLayer
#   pu       — district population units (s2.3.23 District Economics)
#   pref     — Governor clan-preference convention (not a hard gate)
#   governor — true if the district has a Governor (Forbidden City has none)
const DISTRICTS: Array = [
	# -- Toshisoto (Outer City) — 11 districts, 82 PU, Governor Status 4.5 -----
	{"sentaku": "Tsai", "name": "Brutal Flame District", "layer": TOSHISOTO,
		"pu": 5, "pref": ["Scorpion", "Crab", "Tortoise"], "governor": true},
	{"sentaku": "Hidari", "name": "Emperor's Road District", "layer": TOSHISOTO,
		"pu": 7, "pref": ["Crane", "Imperial"], "governor": true},
	{"sentaku": "Juramashi", "name": "Juramashi District", "layer": TOSHISOTO,
		"pu": 15, "pref": [], "governor": true},
	{"sentaku": "Ochiyo", "name": "Spiritual District", "layer": TOSHISOTO,
		"pu": 6, "pref": ["Imperial", "Phoenix", "Lion"], "governor": true},
	{"sentaku": "Hayasu", "name": "Gilded Hill District", "layer": TOSHISOTO,
		"pu": 8, "pref": ["Crane", "Imperial"], "governor": true},
	{"sentaku": "Hojize", "name": "Rich Crescent District", "layer": TOSHISOTO,
		"pu": 10, "pref": ["Lion", "Imperial"], "governor": true},
	{"sentaku": "Hinjaku", "name": "Eta's Island District", "layer": TOSHISOTO,
		"pu": 3, "pref": ["Crab"], "governor": true},
	{"sentaku": "Toyotomi", "name": "Prison/Moon District", "layer": TOSHISOTO,
		"pu": 5, "pref": ["Scorpion", "Crab", "Lion"], "governor": true},
	{"sentaku": "Meiyoko", "name": "Tenari's Ruin District", "layer": TOSHISOTO,
		"pu": 5, "pref": ["Scorpion", "Lion", "Crab"], "governor": true},
	{"sentaku": "Higshikawa", "name": "North Dock District", "layer": TOSHISOTO,
		"pu": 6, "pref": ["Lion", "Crab", "Unicorn"], "governor": true},
	{"sentaku": "Kosuga", "name": "South Dock District", "layer": TOSHISOTO,
		"pu": 12, "pref": ["Crab", "Unicorn", "Imperial"], "governor": true},
	# -- Ekohikei (Inner City) — 4 districts, 15 PU, Governor Status 5.0 -------
	{"sentaku": "Kanjo", "name": "Kanjo District", "layer": EKOHIKEI,
		"pu": 5, "pref": ["Imperial"], "governor": true},
	{"sentaku": "Chisei", "name": "Chisei District", "layer": EKOHIKEI,
		"pu": 4, "pref": ["Crane"], "governor": true},
	{"sentaku": "Karada", "name": "Karada District", "layer": EKOHIKEI,
		"pu": 3, "pref": ["Crab"], "governor": true},
	{"sentaku": "Hito", "name": "Hito District", "layer": EKOHIKEI,
		"pu": 3, "pref": ["Lion"], "governor": true},
	# -- Forbidden City — 1 district, 3 PU, no Governor (Emperor's domain) -----
	{"sentaku": "Forbidden City", "name": "Forbidden City", "layer": FORBIDDEN,
		"pu": 3, "pref": [], "governor": false},
]


# Governor Status by access tier (s2.3.23 Mechanical Notes).
static func governor_status_for_layer(layer: int) -> float:
	return 5.0 if layer == EKOHIKEI else 4.5


# NavigationZoneType for a district's access tier.
static func _zone_type_for_layer(layer: int) -> int:
	match layer:
		EKOHIKEI:
			return Enums.NavigationZoneType.EKOHIKEI_DISTRICT
		FORBIDDEN:
			return Enums.NavigationZoneType.FORBIDDEN_CITY
		_:
			return Enums.NavigationZoneType.CITY_DISTRICT


# Deterministic zone_id for district `index` of the capital settlement.
# Used by both this builder and the governance generator as the join key.
static func district_zone_id(settlement_id: int, index: int) -> String:
	return "%d_nav_district_%d" % [settlement_id, index]


static func build(settlement: SettlementData) -> Dictionary:
	var sid: int = settlement.settlement_id
	var sname: String = settlement.settlement_name

	var gz: GreaterZoneData = GreaterZoneData.new()
	gz.zone_id = "%d_gz" % sid
	gz.zone_name = sname
	gz.zone_type = Enums.GreaterZoneType.SETTLEMENT
	gz.settlement_id = sid

	var nav_zones: Array = []
	for i: int in range(DISTRICTS.size()):
		var d: Dictionary = DISTRICTS[i]
		var layer: int = d["layer"]
		var nz: NavigationZoneData = NavigationZoneData.new()
		nz.zone_id = district_zone_id(sid, i)
		nz.zone_name = "%s — %s" % [sname, d["name"]]
		nz.zone_type = _zone_type_for_layer(layer)
		nz.parent_zone_id = gz.zone_id
		nz.district_pu = d["pu"]
		nz.sentaku_name = d["sentaku"]
		nz.access_layer = layer
		var pref: Array[String] = []
		pref.assign(d["pref"])
		nz.clan_preference = pref
		nz.zone_lord_id = -1  # linked to a Governor after the population pass
		nav_zones.append(nz)
		gz.add_child_zone(nz.zone_id)

	# Wire a connected navigation chain across all districts (N forward / S back).
	# Access-tier gating is enforced by the petition flag system, not the graph.
	for i: int in range(nav_zones.size() - 1):
		var a: NavigationZoneData = nav_zones[i]
		var b: NavigationZoneData = nav_zones[i + 1]
		a.add_exit("N", b.zone_id)
		b.add_exit("S", a.zone_id)

	return {
		"greater_zone": gz,
		"navigation_zones": nav_zones,
		"lesser_zones": [],
	}
