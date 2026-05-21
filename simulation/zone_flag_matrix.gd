class_name ZoneFlagMatrix
## Zone subtype flag definitions per GDD s57.36.
## Authoritative source for all zone flags — overrides any other section.


# =============================================================================
# 57.36.6 — Flag Keys
# =============================================================================

const FLAG_KEYS: Array[String] = [
	"performance_permitted",
	"wall_art_slot",
	"displayed_art_slot",
	"fusuma_slot",
	"tokonoma",
	"bonsai_display_slot",
	"garden_eligible",
	"shrine_eligible",
]

const ALL_FALSE: Dictionary = {
	"performance_permitted": false,
	"wall_art_slot": false,
	"displayed_art_slot": false,
	"fusuma_slot": false,
	"tokonoma": false,
	"bonsai_display_slot": false,
	"garden_eligible": false,
	"shrine_eligible": false,
}


# =============================================================================
# 57.36.3 — Castle Interior Zone Flags
# =============================================================================

const ZONE_FLAGS: Dictionary = {
	Enums.ZoneSubtype.OHIROMA: {
		"performance_permitted": true,
		"wall_art_slot": true,
		"displayed_art_slot": true,
		"fusuma_slot": true,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.ENKAI_HALL: {
		"performance_permitted": true,
		"wall_art_slot": true,
		"displayed_art_slot": true,
		"fusuma_slot": true,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.AUDIENCE_CHAMBER: {
		"performance_permitted": false,
		"wall_art_slot": true,
		"displayed_art_slot": true,
		"fusuma_slot": true,
		"tokonoma": true,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.CHASHITSU: {
		"performance_permitted": true,
		"wall_art_slot": true,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": true,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.GUEST_WING: {
		"performance_permitted": false,
		"wall_art_slot": true,
		"displayed_art_slot": false,
		"fusuma_slot": true,
		"tokonoma": true,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.LORD_QUARTERS: {
		"performance_permitted": false,
		"wall_art_slot": true,
		"displayed_art_slot": true,
		"fusuma_slot": true,
		"tokonoma": true,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.WAR_COUNCIL_ROOM: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.DOJO: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.OUTER_COURTYARD: {
		"performance_permitted": true,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": true,
		"garden_eligible": true,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.TSUBONIWA: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": true,
		"bonsai_display_slot": true,
		"garden_eligible": true,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.CASTLE_SHRINE: {
		"performance_permitted": false,
		"wall_art_slot": true,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": true,
	},

	# 57.36.4 — Urban District Zone Flags
	Enums.ZoneSubtype.MARKET_STREET: {
		"performance_permitted": true,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.RESIDENTIAL_QUARTER: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.TEMPLE_GROUNDS: {
		"performance_permitted": true,
		"wall_art_slot": true,
		"displayed_art_slot": true,
		"fusuma_slot": true,
		"tokonoma": false,
		"bonsai_display_slot": true,
		"garden_eligible": true,
		"shrine_eligible": true,
	},
	Enums.ZoneSubtype.PLEASURE_QUARTER: {
		"performance_permitted": true,
		"wall_art_slot": true,
		"displayed_art_slot": true,
		"fusuma_slot": true,
		"tokonoma": true,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.DOCKS_WATERFRONT: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.POOR_QUARTER: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.GOVERNMENT_QUARTER: {
		"performance_permitted": false,
		"wall_art_slot": true,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},

	# 57.36.5 — Wilderness Zone Flags
	Enums.ZoneSubtype.ROAD: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.FOREST_PATH: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.MOUNTAIN_PASS: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.RIVER_CROSSING: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.FARMLAND: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
	Enums.ZoneSubtype.SHRINE_CLEARING: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": true,
	},

	# 57.36 extension — Wall Tower (military fortification, no artisan/social flags)
	Enums.ZoneSubtype.WALL_TOWER: {
		"performance_permitted": false,
		"wall_art_slot": false,
		"displayed_art_slot": false,
		"fusuma_slot": false,
		"tokonoma": false,
		"bonsai_display_slot": false,
		"garden_eligible": false,
		"shrine_eligible": false,
	},
}


# =============================================================================
# 57.36.2 — Castle Interior Zone Scaling
# =============================================================================

const CASTLE_ZONE_SCALING: Dictionary = {
	Enums.LordRank.VILLAGE_HEADMAN: {
		"min_zones": 1,
		"max_zones": 2,
		"zones": [
			Enums.ZoneSubtype.OHIROMA,
			Enums.ZoneSubtype.OUTER_COURTYARD,
		],
	},
	Enums.LordRank.CITY_DAIMYO: {
		"min_zones": 3,
		"max_zones": 4,
		"zones": [
			Enums.ZoneSubtype.OHIROMA,
			Enums.ZoneSubtype.AUDIENCE_CHAMBER,
			Enums.ZoneSubtype.GUEST_WING,
			Enums.ZoneSubtype.OUTER_COURTYARD,
		],
	},
	Enums.LordRank.PROVINCIAL_DAIMYO: {
		"min_zones": 3,
		"max_zones": 4,
		"zones": [
			Enums.ZoneSubtype.OHIROMA,
			Enums.ZoneSubtype.AUDIENCE_CHAMBER,
			Enums.ZoneSubtype.GUEST_WING,
			Enums.ZoneSubtype.OUTER_COURTYARD,
		],
		"optional": [Enums.ZoneSubtype.CASTLE_SHRINE],
	},
	Enums.LordRank.FAMILY_DAIMYO: {
		"min_zones": 4,
		"max_zones": 6,
		"zones": [
			Enums.ZoneSubtype.OHIROMA,
			Enums.ZoneSubtype.AUDIENCE_CHAMBER,
			Enums.ZoneSubtype.GUEST_WING,
			Enums.ZoneSubtype.ENKAI_HALL,
			Enums.ZoneSubtype.TSUBONIWA,
			Enums.ZoneSubtype.CASTLE_SHRINE,
		],
		"optional": [
			Enums.ZoneSubtype.LORD_QUARTERS,
			Enums.ZoneSubtype.CHASHITSU,
		],
	},
	Enums.LordRank.CLAN_CHAMPION: {
		"min_zones": 5,
		"max_zones": 8,
		"zones": [
			Enums.ZoneSubtype.OHIROMA,
			Enums.ZoneSubtype.AUDIENCE_CHAMBER,
			Enums.ZoneSubtype.GUEST_WING,
			Enums.ZoneSubtype.ENKAI_HALL,
			Enums.ZoneSubtype.TSUBONIWA,
			Enums.ZoneSubtype.CASTLE_SHRINE,
			Enums.ZoneSubtype.LORD_QUARTERS,
			Enums.ZoneSubtype.CHASHITSU,
		],
		"optional": [
			Enums.ZoneSubtype.DOJO,
			Enums.ZoneSubtype.WAR_COUNCIL_ROOM,
			Enums.ZoneSubtype.OUTER_COURTYARD,
		],
	},
	Enums.LordRank.IMPERIAL: {
		"min_zones": 10,
		"max_zones": 11,
		"zones": [
			Enums.ZoneSubtype.OHIROMA,
			Enums.ZoneSubtype.ENKAI_HALL,
			Enums.ZoneSubtype.AUDIENCE_CHAMBER,
			Enums.ZoneSubtype.CHASHITSU,
			Enums.ZoneSubtype.GUEST_WING,
			Enums.ZoneSubtype.LORD_QUARTERS,
			Enums.ZoneSubtype.WAR_COUNCIL_ROOM,
			Enums.ZoneSubtype.DOJO,
			Enums.ZoneSubtype.OUTER_COURTYARD,
			Enums.ZoneSubtype.TSUBONIWA,
			Enums.ZoneSubtype.CASTLE_SHRINE,
		],
	},
}


# =============================================================================
# Flag Lookups
# =============================================================================

static func get_flags(zone_subtype: Enums.ZoneSubtype) -> Dictionary:
	return ZONE_FLAGS.get(zone_subtype, ALL_FALSE)


static func get_flag(zone_subtype: Enums.ZoneSubtype, flag_name: String) -> bool:
	var flags: Dictionary = ZONE_FLAGS.get(zone_subtype, ALL_FALSE)
	return flags.get(flag_name, false)


static func can_perform(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "performance_permitted")


static func has_tokonoma(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "tokonoma")


static func can_display_wall_art(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "wall_art_slot")


static func can_display_art(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "displayed_art_slot")


static func has_fusuma(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "fusuma_slot")


static func can_display_bonsai(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "bonsai_display_slot")


static func can_garden(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "garden_eligible")


static func can_worship(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "shrine_eligible")


static func can_tea_ceremony(zone_subtype: Enums.ZoneSubtype) -> bool:
	return get_flag(zone_subtype, "tokonoma") or get_flag(zone_subtype, "shrine_eligible")


# =============================================================================
# Zone Category Helpers
# =============================================================================

const CASTLE_INTERIOR_ZONES: Array = [
	Enums.ZoneSubtype.OHIROMA,
	Enums.ZoneSubtype.ENKAI_HALL,
	Enums.ZoneSubtype.AUDIENCE_CHAMBER,
	Enums.ZoneSubtype.CHASHITSU,
	Enums.ZoneSubtype.GUEST_WING,
	Enums.ZoneSubtype.LORD_QUARTERS,
	Enums.ZoneSubtype.WAR_COUNCIL_ROOM,
	Enums.ZoneSubtype.DOJO,
	Enums.ZoneSubtype.OUTER_COURTYARD,
	Enums.ZoneSubtype.TSUBONIWA,
	Enums.ZoneSubtype.CASTLE_SHRINE,
]

const URBAN_ZONES: Array = [
	Enums.ZoneSubtype.MARKET_STREET,
	Enums.ZoneSubtype.RESIDENTIAL_QUARTER,
	Enums.ZoneSubtype.TEMPLE_GROUNDS,
	Enums.ZoneSubtype.PLEASURE_QUARTER,
	Enums.ZoneSubtype.DOCKS_WATERFRONT,
	Enums.ZoneSubtype.POOR_QUARTER,
	Enums.ZoneSubtype.GOVERNMENT_QUARTER,
]

const WILDERNESS_ZONES: Array = [
	Enums.ZoneSubtype.ROAD,
	Enums.ZoneSubtype.FOREST_PATH,
	Enums.ZoneSubtype.MOUNTAIN_PASS,
	Enums.ZoneSubtype.RIVER_CROSSING,
	Enums.ZoneSubtype.FARMLAND,
	Enums.ZoneSubtype.SHRINE_CLEARING,
]

const WALL_ZONES: Array = [
	Enums.ZoneSubtype.WALL_TOWER,
]


static func is_castle_interior(zone_subtype: Enums.ZoneSubtype) -> bool:
	return zone_subtype in CASTLE_INTERIOR_ZONES


static func is_urban(zone_subtype: Enums.ZoneSubtype) -> bool:
	return zone_subtype in URBAN_ZONES


static func is_wilderness(zone_subtype: Enums.ZoneSubtype) -> bool:
	return zone_subtype in WILDERNESS_ZONES


static func is_wall_zone(zone_subtype: Enums.ZoneSubtype) -> bool:
	return zone_subtype in WALL_ZONES


# =============================================================================
# 57.36.2 — Castle Scaling Queries
# =============================================================================

static func get_castle_zones_for_rank(lord_rank: Enums.LordRank) -> Dictionary:
	return CASTLE_ZONE_SCALING.get(lord_rank, {
		"min_zones": 1,
		"max_zones": 2,
		"zones": [Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.OUTER_COURTYARD],
	})


static func get_min_zones(lord_rank: Enums.LordRank) -> int:
	var scaling: Dictionary = get_castle_zones_for_rank(lord_rank)
	return scaling.get("min_zones", 1)


static func get_max_zones(lord_rank: Enums.LordRank) -> int:
	var scaling: Dictionary = get_castle_zones_for_rank(lord_rank)
	return scaling.get("max_zones", 2)
