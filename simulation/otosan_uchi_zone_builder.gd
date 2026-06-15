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
## Each district Navigation Zone carries a thematic zone_subtype and has_ascii_map
## = true (s4.4 procedural tier, owner-approved 2026-06-15), so AsciiMapGenerator
## renders a deterministic street-level map per district on entry. Each district
## also contains child Lesser Zones for its s2.3.23 named landmarks (LANDMARKS),
## each rendering via the nearest existing interior generator (reuse approach,
## owner-approved 2026-06-15) — bespoke per-archetype generators can swap in later.
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
#   subtype  — ZoneSubtype the AsciiMapGenerator renders for the district's
#              street-level map (owner-approved 2026-06-15; see s2.3.23 landmarks)
const DISTRICTS: Array = [
	# -- Toshisoto (Outer City) — 11 districts, 82 PU, Governor Status 4.5 -----
	{"sentaku": "Tsai", "name": "Brutal Flame District", "layer": TOSHISOTO,
		"pu": 5, "pref": ["Scorpion", "Crab", "Tortoise"], "governor": true,
		"subtype": Enums.ZoneSubtype.PLEASURE_QUARTER},
	{"sentaku": "Hidari", "name": "Emperor's Road District", "layer": TOSHISOTO,
		"pu": 7, "pref": ["Crane", "Imperial"], "governor": true,
		"subtype": Enums.ZoneSubtype.MARKET_STREET},
	{"sentaku": "Juramashi", "name": "Juramashi District", "layer": TOSHISOTO,
		"pu": 15, "pref": [], "governor": true,
		"subtype": Enums.ZoneSubtype.MARKET_STREET},
	{"sentaku": "Ochiyo", "name": "Spiritual District", "layer": TOSHISOTO,
		"pu": 6, "pref": ["Imperial", "Phoenix", "Lion"], "governor": true,
		"subtype": Enums.ZoneSubtype.TEMPLE_GROUNDS},
	{"sentaku": "Hayasu", "name": "Gilded Hill District", "layer": TOSHISOTO,
		"pu": 8, "pref": ["Crane", "Imperial"], "governor": true,
		"subtype": Enums.ZoneSubtype.RESIDENTIAL_QUARTER},
	{"sentaku": "Hojize", "name": "Rich Crescent District", "layer": TOSHISOTO,
		"pu": 10, "pref": ["Lion", "Imperial"], "governor": true,
		"subtype": Enums.ZoneSubtype.DOCKS_WATERFRONT},
	{"sentaku": "Hinjaku", "name": "Eta's Island District", "layer": TOSHISOTO,
		"pu": 3, "pref": ["Crab"], "governor": true,
		"subtype": Enums.ZoneSubtype.POOR_QUARTER},
	{"sentaku": "Toyotomi", "name": "Prison/Moon District", "layer": TOSHISOTO,
		"pu": 5, "pref": ["Scorpion", "Crab", "Lion"], "governor": true,
		"subtype": Enums.ZoneSubtype.GOVERNMENT_QUARTER},
	{"sentaku": "Meiyoko", "name": "Tenari's Ruin District", "layer": TOSHISOTO,
		"pu": 5, "pref": ["Scorpion", "Lion", "Crab"], "governor": true,
		"subtype": Enums.ZoneSubtype.RESIDENTIAL_QUARTER},
	{"sentaku": "Higshikawa", "name": "North Dock District", "layer": TOSHISOTO,
		"pu": 6, "pref": ["Lion", "Crab", "Unicorn"], "governor": true,
		"subtype": Enums.ZoneSubtype.DOCKS_WATERFRONT},
	{"sentaku": "Kosuga", "name": "South Dock District", "layer": TOSHISOTO,
		"pu": 12, "pref": ["Crab", "Unicorn", "Imperial"], "governor": true,
		"subtype": Enums.ZoneSubtype.DOCKS_WATERFRONT},
	# -- Ekohikei (Inner City) — 4 districts, 15 PU, Governor Status 5.0 -------
	{"sentaku": "Kanjo", "name": "Kanjo District", "layer": EKOHIKEI,
		"pu": 5, "pref": ["Imperial"], "governor": true,
		"subtype": Enums.ZoneSubtype.GOVERNMENT_QUARTER},
	{"sentaku": "Chisei", "name": "Chisei District", "layer": EKOHIKEI,
		"pu": 4, "pref": ["Crane"], "governor": true,
		"subtype": Enums.ZoneSubtype.RESIDENTIAL_QUARTER},
	{"sentaku": "Karada", "name": "Karada District", "layer": EKOHIKEI,
		"pu": 3, "pref": ["Crab"], "governor": true,
		"subtype": Enums.ZoneSubtype.POOR_QUARTER},
	{"sentaku": "Hito", "name": "Hito District", "layer": EKOHIKEI,
		"pu": 3, "pref": ["Lion"], "governor": true,
		"subtype": Enums.ZoneSubtype.RESIDENTIAL_QUARTER},
	# -- Forbidden City — 1 district, 3 PU, no Governor (Emperor's domain) -----
	{"sentaku": "Forbidden City", "name": "Forbidden City", "layer": FORBIDDEN,
		"pu": 3, "pref": [], "governor": false,
		"subtype": Enums.ZoneSubtype.AUDIENCE_CHAMBER},
]


# Handcrafted landmark Lesser Zones per district (s2.3.23 "Handcrafted map
# landmarks" + s4.4 District Nav Zone → building Lesser Zones). Keyed by DISTRICTS
# index. Each entry: n = display name (verbatim from s2.3.23), s = the nearest
# existing AsciiMapGenerator ZoneSubtype for its interior (reuse approach,
# owner-approved 2026-06-15 — bespoke per-archetype generators are a future swap).
# Only GDD-named landmarks become zones; no invented buildings.
const _ZS := Enums.ZoneSubtype
const LANDMARKS: Dictionary = {
	0: [  # Tsai — Brutal Flame
		{"n": "Zankoku Hon'O (lighthouse)", "s": _ZS.WALL_TOWER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
		{"n": "Bayushi's Mask (okiya)", "s": _ZS.PLEASURE_QUARTER},
		{"n": "Leaves of Shosuro (tea house)", "s": _ZS.CHASHITSU},
		{"n": "The Tear (theater)", "s": _ZS.ENKAI_HALL},
		{"n": "Shrine of Hofukushu", "s": _ZS.CASTLE_SHRINE},
		{"n": "Bayushi's Bane (hospital)", "s": _ZS.GUEST_WING},
		{"n": "Dragon's Mists (hospital)", "s": _ZS.GUEST_WING},
		{"n": "Life's Waterfall (sake house)", "s": _ZS.ENKAI_HALL},
		{"n": "Light as the Wind (kite shop)", "s": _ZS.MARKET_STREET},
		{"n": "Abandoned waterway houses", "s": _ZS.RUINED_STRUCTURE},
	],
	1: [  # Hidari — Emperor's Road
		{"n": "Road of the Most High", "s": _ZS.ROAD},
		{"n": "Jade torii arches", "s": _ZS.CASTLE_SHRINE},
		{"n": "Emerald Coin (market plaza)", "s": _ZS.MARKET_STREET},
		{"n": "Doji's Children (okiya)", "s": _ZS.PLEASURE_QUARTER},
		{"n": "Inn of the Last Rite", "s": _ZS.GUEST_WING},
		{"n": "Light from Above (dining house)", "s": _ZS.ENKAI_HALL},
		{"n": "Soshiuchi / House of Loss", "s": _ZS.LORD_QUARTERS},
		{"n": "Origami shop", "s": _ZS.MARKET_STREET},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	2: [  # Juramashi
		{"n": "Craftsman's Quarter", "s": _ZS.MARKET_STREET},
		{"n": "Bright Wind (geisha house)", "s": _ZS.PLEASURE_QUARTER},
		{"n": "Natsu-Togumara Shrine", "s": _ZS.CASTLE_SHRINE},
		{"n": "Juramashi District Meeting Hall", "s": _ZS.OHIROMA},
		{"n": "Maratu's Origata (gift shop)", "s": _ZS.MARKET_STREET},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
		{"n": "Underground Lake", "s": _ZS.UNDERGROUND_LAKE},
	],
	3: [  # Ochiyo — Spiritual
		{"n": "Temple of the Sun Goddess", "s": _ZS.TEMPLE_GROUNDS},
		{"n": "Temple of Daikoku", "s": _ZS.TEMPLE_GROUNDS},
		{"n": "Temple of Ebisu", "s": _ZS.TEMPLE_GROUNDS},
		{"n": "Temple of Benten", "s": _ZS.TEMPLE_GROUNDS},
		{"n": "Simple Pleasures (okiya)", "s": _ZS.PLEASURE_QUARTER},
		{"n": "Seppun's Path", "s": _ZS.TSUBONIWA},
		{"n": "Meditation gardens", "s": _ZS.TSUBONIWA},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	4: [  # Hayasu — Gilded Hill
		{"n": "Shining Square", "s": _ZS.MARKET_STREET},
		{"n": "Riverside Merchant Plaza", "s": _ZS.MARKET_STREET},
		{"n": "Cherry Blossom Row", "s": _ZS.TSUBONIWA},
		{"n": "Chirping Crickets Neighborhood", "s": _ZS.RESIDENTIAL_QUARTER},
		{"n": "Governor's residence (hilltop)", "s": _ZS.LORD_QUARTERS},
		{"n": "Farms outside the walls", "s": _ZS.FARMLAND},
	],
	5: [  # Hojize — Rich Crescent
		{"n": "Wharves", "s": _ZS.DOCKS_WATERFRONT},
		{"n": "Clan Guide Houses (inn)", "s": _ZS.GUEST_WING},
		{"n": "Kinjiren Tombs", "s": _ZS.CASTLE_SHRINE},
		{"n": "Chiken / Bloodhawk Bridge", "s": _ZS.RIVER_CROSSING},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
		{"n": "Koku Seal office", "s": _ZS.GOVERNMENT_QUARTER},
	],
	6: [  # Hinjaku — Eta's Island
		{"n": "Takusanno Sakanaya (fishery)", "s": _ZS.DOCKS_WATERFRONT},
		{"n": "Shizukomen (residential)", "s": _ZS.POOR_QUARTER},
		{"n": "Eta quarter", "s": _ZS.POOR_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	7: [  # Toyotomi — Prison/Moon
		{"n": "Kyuden Kokai (prison)", "s": _ZS.GOVERNMENT_QUARTER},
		{"n": "Magistrate station", "s": _ZS.GOVERNMENT_QUARTER},
		{"n": "Jumping Frog (okiya)", "s": _ZS.PLEASURE_QUARTER},
		{"n": "The Moon (gambling quarter)", "s": _ZS.PLEASURE_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	8: [  # Meiyoko — Tenari's Ruin
		{"n": "Tenari's ruins", "s": _ZS.RUINED_STRUCTURE},
		{"n": "Hana Garden", "s": _ZS.TSUBONIWA},
		{"n": "Gokenin quarters", "s": _ZS.RESIDENTIAL_QUARTER},
		{"n": "Criminal refuge areas", "s": _ZS.POOR_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	9: [  # Higshikawa — North Dock
		{"n": "Morning Star Wharves", "s": _ZS.DOCKS_WATERFRONT},
		{"n": "Takeo Library", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Imperial Guard kaisha (barracks)", "s": _ZS.BARRACKS},
		{"n": "Pleasure houses", "s": _ZS.PLEASURE_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	10: [  # Kosuga — South Dock
		{"n": "Primary trade port", "s": _ZS.DOCKS_WATERFRONT},
		{"n": "Flooded Merchant Bazaar", "s": _ZS.MARKET_STREET},
		{"n": "Daikoku Arch", "s": _ZS.CASTLE_SHRINE},
		{"n": "Yatoshin warehouse district", "s": _ZS.DOCKS_WATERFRONT},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
		{"n": "Koku Seal inspection point", "s": _ZS.GOVERNMENT_QUARTER},
	],
	11: [  # Kanjo — Ekohikei
		{"n": "Lion Embassy (south)", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Phoenix Embassy", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Scorpion Embassy", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Sorrow's Fall", "s": _ZS.TSUBONIWA},
		{"n": "Sentaku Tribunal Hall", "s": _ZS.OHIROMA},
		{"n": "Imperial Treasury", "s": _ZS.GOVERNMENT_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	12: [  # Chisei — Ekohikei
		{"n": "Seppun Hill", "s": _ZS.TEMPLE_GROUNDS},
		{"n": "Crane Embassy (Storyhouse)", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Phoenix secondary embassy", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Minor Clan embassy row", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Art galleries & performance halls", "s": _ZS.ENKAI_HALL},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	13: [  # Karada — Ekohikei
		{"n": "Crab Embassy", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Oni Warai (the Oni's Smile)", "s": _ZS.ONI_WARAI},
		{"n": "Yasuki Trading Grounds", "s": _ZS.MARKET_STREET},
		{"n": "Lower-caste residential quarters", "s": _ZS.POOR_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	14: [  # Hito — Ekohikei
		{"n": "Lion Embassy (barracks)", "s": _ZS.BARRACKS},
		{"n": "Unicorn Embassy", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Fox Embassy", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Road of Fast Hopes", "s": _ZS.ROAD},
		{"n": "Samurai residential compounds", "s": _ZS.RESIDENTIAL_QUARTER},
		{"n": "Governor's residence", "s": _ZS.LORD_QUARTERS},
	],
	15: [  # Forbidden City
		# Imperial Palace — 10+ interior sub-zones (s2.3.23 / s57.36). The grandest
		# structure in the Empire carries the full castle-interior set.
		{"n": "Imperial Palace — Throne Room", "s": _ZS.THRONE_ROOM},
		{"n": "Imperial Palace — Imperial Court Chambers", "s": _ZS.AUDIENCE_CHAMBER},
		{"n": "Imperial Palace — Banquet Hall", "s": _ZS.ENKAI_HALL},
		{"n": "Imperial Palace — Tea Pavilion", "s": _ZS.CHASHITSU},
		{"n": "Imperial Palace — Guest Wing", "s": _ZS.GUEST_WING},
		{"n": "Imperial Palace — Emperor's Private Chambers", "s": _ZS.LORD_QUARTERS},
		{"n": "Imperial Palace — War Council Room", "s": _ZS.WAR_COUNCIL_ROOM},
		{"n": "Imperial Palace — Dojo", "s": _ZS.DOJO},
		{"n": "Imperial Palace — Outer Courtyard", "s": _ZS.OUTER_COURTYARD},
		{"n": "Imperial Palace — Inner Garden", "s": _ZS.TSUBONIWA},
		{"n": "Imperial Palace — Palace Shrine", "s": _ZS.CASTLE_SHRINE},
		# Other palaces and grounds named in s2.3.23.
		{"n": "Otomo Palace", "s": _ZS.LORD_QUARTERS},
		{"n": "Seppun Palace", "s": _ZS.LORD_QUARTERS},
		{"n": "Miya Palace", "s": _ZS.LORD_QUARTERS},
		# Guest Homes — one per Great Clan (s2.3.23).
		{"n": "Guest Home — Crab Clan", "s": _ZS.GUEST_WING},
		{"n": "Guest Home — Crane Clan", "s": _ZS.GUEST_WING},
		{"n": "Guest Home — Dragon Clan", "s": _ZS.GUEST_WING},
		{"n": "Guest Home — Lion Clan", "s": _ZS.GUEST_WING},
		{"n": "Guest Home — Phoenix Clan", "s": _ZS.GUEST_WING},
		{"n": "Guest Home — Scorpion Clan", "s": _ZS.GUEST_WING},
		{"n": "Guest Home — Unicorn Clan", "s": _ZS.GUEST_WING},
		# Shrines, gardens, guard, and the tunnel complex.
		{"n": "Shrine of the First Hantei", "s": _ZS.CASTLE_SHRINE},
		{"n": "Imperial Gardens", "s": _ZS.TSUBONIWA},
		{"n": "Seppun Guard barracks", "s": _ZS.BARRACKS},
		{"n": "Emperor's Chosen quarters", "s": _ZS.LORD_QUARTERS},
		{"n": "Emperor's Labyrinth (tunnels)", "s": _ZS.LABYRINTH},
	],
}


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
	var lesser_zones: Array = []
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
		nz.has_governor = d.get("governor", false)
		nz.zone_lord_id = -1  # linked to a Governor after the population pass
		# Thematic street-level ASCII map per district (s4.4 procedural tier).
		nz.zone_subtype = d.get("subtype", Enums.ZoneSubtype.MARKET_STREET)
		nz.has_ascii_map = true
		nav_zones.append(nz)
		gz.add_child_zone(nz.zone_id)
		# Handcrafted landmark buildings: one child Lesser Zone each (s4.4 tier).
		var lms: Array = LANDMARKS.get(i, [])
		for j: int in range(lms.size()):
			var lm: Dictionary = lms[j]
			var lz: LesserZoneData = LesserZoneData.new()
			lz.zone_id = "%s_lz_%d" % [nz.zone_id, j]
			lz.zone_name = "%s — %s" % [d["name"], lm["n"]]
			lz.zone_subtype = lm["s"]
			lz.parent_zone_id = nz.zone_id
			lz.add_exit("up", nz.zone_id)
			nz.add_child_zone(lz.zone_id)
			lesser_zones.append(lz)

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
		"lesser_zones": lesser_zones,
	}
