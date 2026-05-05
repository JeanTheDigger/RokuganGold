class_name Enums


enum Ring {
	AIR,
	EARTH,
	FIRE,
	WATER,
	VOID,
}

enum Trait {
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
	JIN,
	YU,
	REI,
	CHUGI,
	GI,
	MEIYO,
	MAKOTO,
}

enum ShouridoVirtue {
	SEIGYO,
	KETSUI,
	DOSATSU,
	CHISHIKI,
	KANPEKI,
	KYORYOKU,
	ISHI,
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
