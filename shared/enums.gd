class_name Enums


enum Ring {
	NONE = -1,
	AIR,
	EARTH,
	FIRE,
	WATER,
	VOID,
}

enum Trait {
	NONE = -1,
	REFLEXES,
	AWARENESS,
	STAMINA,
	WILLPOWER,
	AGILITY,
	INTELLIGENCE,
	STRENGTH,
	PERCEPTION,
	VOID,
}

enum WoundLevel {
	HEALTHY,
	NICKED,
	GRAZED,
	HURT,
	INJURED,
	CRIPPLED,
	DOWN,
	OUT,
	DEAD,
}

enum Stance {
	ATTACK,
	FULL_ATTACK,
	DEFENSE,
	FULL_DEFENSE,
	CENTER,
}

enum SchoolType {
	BUSHI,
	COURTIER,
	SHUGENJA,
	MONK,
	NINJA,
	ARTISAN,
}

const RING_TRAITS: Dictionary = {
	Ring.AIR: [Trait.REFLEXES, Trait.AWARENESS],
	Ring.EARTH: [Trait.STAMINA, Trait.WILLPOWER],
	Ring.FIRE: [Trait.AGILITY, Trait.INTELLIGENCE],
	Ring.WATER: [Trait.STRENGTH, Trait.PERCEPTION],
	Ring.VOID: [Trait.VOID],
}

enum ContextFlag {
	AT_OWN_HOLDINGS,
	AT_COURT,
	VISITING,
	TRAVELING,
	ON_CAMPAIGN,
	UNDER_SIEGE,
	IN_EXILE,
	AT_TEMPLE,
	AT_DOJO,
}

enum BushidoVirtue {
	NONE = -1,
	JIN,
	YU,
	REI,
	CHUGI,
	GI,
	MEIYO,
	MAKOTO,
}

enum ShouridoVirtue {
	NONE = -1,
	SEIGYO,
	KETSUI,
	DOSATSU,
	CHISHIKI,
	KANPEKI,
	KYORYOKU,
	ISHI,
}

enum TerrainType {
	PLAINS,
	RIVER_DELTA,
	FOREST,
	HILLS,
	MOUNTAINS,
}

enum SettlementType {
	VILLAGE,
	TOWN,
	CITY,
	IMPERIAL_CAPITAL,
	FORTIFICATION,
	KEEP,
	CASTLE,
	FAMILY_CASTLE,
	WALL_TOWER,
	TEMPLE,
	SHINDEN,
	MONASTERY,
}

const WOUND_PENALTIES: Dictionary = {
	WoundLevel.HEALTHY: 0,
	WoundLevel.NICKED: -3,
	WoundLevel.GRAZED: -5,
	WoundLevel.HURT: -10,
	WoundLevel.INJURED: -15,
	WoundLevel.CRIPPLED: -20,
	WoundLevel.DOWN: -40,
	WoundLevel.OUT: 0,
	WoundLevel.DEAD: 0,
}

const TERRAIN_RICE_MULTIPLIER: Dictionary = {
	TerrainType.PLAINS: 1.0,
	TerrainType.RIVER_DELTA: 1.5,
	TerrainType.FOREST: 0.75,
	TerrainType.HILLS: 0.75,
	TerrainType.MOUNTAINS: 0.5,
}

const MILITARY_SETTLEMENT_TYPES: Array[SettlementType] = [
	SettlementType.FORTIFICATION,
	SettlementType.KEEP,
	SettlementType.CASTLE,
	SettlementType.FAMILY_CASTLE,
	SettlementType.WALL_TOWER,
]

const RELIGIOUS_SETTLEMENT_TYPES: Array[SettlementType] = [
	SettlementType.TEMPLE,
	SettlementType.SHINDEN,
	SettlementType.MONASTERY,
]


enum CrimeType {
	DISHONORABLE_CONDUCT,
	VIOLENCE,
	UNSANCTIONED_DUEL_DEATH,
	SKIMMING,
	UNSANCTIONED_OPEN_KILLING,
	UNSANCTIONED_COVERT_KILLING,
	MAGISTRATE_CORRUPTION,
	DUEL_DEFILEMENT,
	TREASON,
	MAHO,
	OTHER,
}

enum CrimeSeverity {
	MINOR,
	MODERATE,
	SERIOUS,
	CAPITAL,
}

enum LegalStatus {
	NONE,
	SUSPECTED,
	UNDER_INVESTIGATION,
	ACCUSED,
	CONVICTED,
	CLEAR,
	PARDONED,
}

enum Sublocation {
	PUBLIC,
	COURT,
	PRIVATE,
	RESTRICTED,
}

enum AccessDenialReason {
	INSUFFICIENT_STATUS,
	NO_INVITATION,
	HOSTILE_CLAN,
	RESTRICTED_ROLE,
	HOST_REFUSAL,
}


enum CommitmentType {
	COURT_ATTENDANCE,
	FAVOR_OBLIGATION,
	VISIT_PROMISE,
	SUPPORT_PLEDGE,
	RESOURCE_PROMISE,
	MEETING_ARRANGEMENT,
}

enum CommitmentStatus {
	PENDING,
	FULFILLED,
	BROKEN_NO_NOTICE,
	BROKEN_WITH_NOTICE,
	BROKEN_WITH_PROXY,
	BROKEN_FORCE_MAJEURE,
	EXPIRED,
}


enum DeploymentStatus {
	WITH_LEGION,
	GARRISONED,
	DETACHED,
	ON_CAMPAIGN,
}

enum ZoneSubtype {
	# Castle Interior
	OHIROMA,
	ENKAI_HALL,
	AUDIENCE_CHAMBER,
	CHASHITSU,
	GUEST_WING,
	LORD_QUARTERS,
	WAR_COUNCIL_ROOM,
	DOJO,
	OUTER_COURTYARD,
	TSUBONIWA,
	CASTLE_SHRINE,
	# Urban District
	MARKET_STREET,
	RESIDENTIAL_QUARTER,
	TEMPLE_GROUNDS,
	PLEASURE_QUARTER,
	DOCKS_WATERFRONT,
	POOR_QUARTER,
	GOVERNMENT_QUARTER,
	# Wilderness
	ROAD,
	FOREST_PATH,
	MOUNTAIN_PASS,
	RIVER_CROSSING,
	FARMLAND,
	SHRINE_CLEARING,
}

enum LordRank {
	VILLAGE_HEADMAN,
	CITY_DAIMYO,
	PROVINCIAL_DAIMYO,
	FAMILY_DAIMYO,
	CLAN_CHAMPION,
	IMPERIAL,
}


static func bushido_virtue_name(v: BushidoVirtue) -> String:
	var idx: int = BushidoVirtue.values().find(v)
	if idx < 0:
		return ""
	return BushidoVirtue.keys()[idx]


static func shourido_virtue_name(v: ShouridoVirtue) -> String:
	var idx: int = ShouridoVirtue.values().find(v)
	if idx < 0:
		return ""
	return ShouridoVirtue.keys()[idx]
