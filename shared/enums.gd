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
