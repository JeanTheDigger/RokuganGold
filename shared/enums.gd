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
	AT_WALL_TOWER,
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
	VIOLATION_EMPERORS_PEACE,
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
	DECREED_GUILTY,
	CLEAR,
	PARDONED,
	ACQUITTED,
	FUGITIVE,
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
	# Wall / Military
	WALL_TOWER,
}

enum LordRank {
	VILLAGE_HEADMAN,
	CITY_DAIMYO,
	PROVINCIAL_DAIMYO,
	FAMILY_DAIMYO,
	CLAN_CHAMPION,
	IMPERIAL,
}


enum TattooBodyLocation {
	LEFT_WRIST_FOREARM,
	RIGHT_WRIST_FOREARM,
	LEFT_UPPER_ARM_SHOULDER,
	RIGHT_UPPER_ARM_SHOULDER,
	CHEST_TORSO,
	BACK,
	LEFT_LEG_THIGH,
	RIGHT_LEG_THIGH,
	HEAD,
}

enum TattooQualityTier {
	MUNDANE,
	NORMAL,
	FINE,
	EXCEPTIONAL,
	MASTERWORK,
	LEGENDARY,
}

enum TattooSubjectType {
	IMAGE,
	TOPIC,
}

enum TattooAbility {
	NONE,
	BALANCE,
	BAMBOO,
	BEAR,
	BLAZE,
	CENTIPEDE,
	CLOUD,
	CRAB,
	CRANE,
	DRAGON,
	HAWK,
	KI_RIN,
	LION,
	MANTIS,
	MOUNTAIN,
	OCEAN,
	PHOENIX,
	SCORPION,
	SPIDER,
	STORM,
	VOID,
	VOLCANO,
	WAVE,
	WHISPER,
	WIND,
	WOLF,
}

enum CulturalReluctance {
	NO_RELUCTANCE,
	RELUCTANT,
	VERY_RELUCTANT,
}


enum MilitaryRank {
	NONE,
	HOHEI,
	NIKUTAI,
	GUNSO,
	CHUI,
	TAISA,
	SHIREIKAN,
	RIKUGUNSHOKAN,
}

enum OperationalHierarchyType {
	NONE,
	LEGAL,
	MILITARY,
	DELEGATION,
}

enum KolatSect {
	NONE,
	CHRYSANTHEMUM,
	CLOUD,
	COIN,
	DREAM,
	LOTUS,
	SILK,
	TIGER,
}

enum KnowledgeSource {
	DIRECT_OBSERVATION,
	DAILY_CONVERSATION,
	LETTER,
	INTELLIGENCE,
	PUBLIC_KNOWLEDGE,
	TESTIMONY,
}

enum KnowledgeConfidence {
	FRESH,
	RECENT,
	STALE,
}


enum ShipClass {
	SAMPAN,
	MERCHANT_BARGE,
	KOBUNE,
	SENGOKOBUNE,
	KOUTETSUKAN,
	ATAKEBUNE,
	TORTOISE_OCEANGOING,
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


enum InsurgencyType {
	MAHO_CULT,
	PEASANT_REVOLT,
	RONIN_BANDIT,
	TAINT_MANIFESTATION,
	NEZUMI_INFESTATION,
	URBAN_CRIMINAL_NETWORK,
	PIRATE_FLEET,
}

enum StabilityTier {
	STABLE,
	RESTLESS,
	VOLATILE,
	BROKEN,
}

enum CompanyUnitType {
	PEASANT_LEVY,
	ASHIGARU_SPEARMEN,
	ASHIGARU_ARCHERS,
	BUSHI_RETAINER,
	LIGHT_CAVALRY,
	RONIN,
	GARRISON,
	# Crab Clan
	HIDA_BUSHI,
	CRAB_BERSERKERS,
	HIRUMA_SCOUTS,
	# Crane Clan
	KAKITA_BUSHI,
	KENSHINZEN,
	DAIDOJI_HEAVY_SPEARMEN,
	# Dragon Clan
	MIRUMOTO_BUSHI,
	DRAGON_TALONS,
	YAMABUSHI,
	# Lion Clan
	AKODO_BUSHI,
	LIONS_PRIDE,
	DEATHSEEKERS,
	# Phoenix Clan
	SHIBA_BUSHI,
	ELEMENTAL_GUARD,
	ELEMENTAL_LEGIONS,
	# Scorpion Clan
	BAYUSHI_BUSHI,
	BLACK_CABAL,
	SCORPIONS_CLAWS,
	# Unicorn Clan
	SHINJO_BUSHI,
	UTAKU_BATTLE_MAIDENS,
	WHITE_GUARD,
	# Mantis Clan (Minor)
	YORITOMO_BUSHI,
	STORM_RIDERS,
	STORM_LEGION,
}

enum BattleTerrainType {
	PLAINS,
	FOREST,
	HILLS,
	MOUNTAIN,
	URBAN,
	COASTAL_BEACH,
}

# -- Shadowlands Unit Roster (s2.4.7 — LOCKED) ---------------------------------

enum ShadowlandsUnitType {
	# Bakemono
	BAKEMONO,
	BAKEMONO_WARRIOR,
	BAKEMONO_ARCHERS,
	BAKEMONO_SHAMAN,
	OMONI_BAKEMONO,
	# Undead
	ZOMBIE,
	SKELETON_WARRIOR,
	UNDEAD_REVENANT,
	MAHO_TSUKAI,
	# Ogres
	OGRE_WARRIOR,
	RAVENOUS_OGRE,
	OGRE_WARLORD,
}

# -- Horde Invasion Types (s2.4.6 — LOCKED) ------------------------------------

enum InvasionType {
	JIGOKU_HORDE,       # 60% — Bakemono and Ogres
	UNDEAD_LEGION,      # 25% — Undead and maho-tsukai
	ONI_LED,            # 15% — Oni at head of Bakemono/Ogre army
	ONI_LED_SPAWN,      # Spawn variant of Oni-Led (Spawn Pool 3 ability)
}

# -- Oni Procedural Generation (s2.4.8 — LOCKED) --------------------------------

enum OniSize {
	SMALL,    # MB Health 50,  Ring budget 9,  MB Atk floor 5
	MEDIUM,   # MB Health 100, Ring budget 12, MB Atk floor 7
	LARGE,    # MB Health 175, Ring budget 15, MB Atk floor 9
	MASSIVE,  # MB Health 300, Ring budget 19, MB Atk floor 11
}

enum OniBodyForm {
	HUMANOID,    # Standard movement
	SERPENTINE,  # Slow, ignores difficult terrain; +1 Atk, -1 Def
	BESTIAL,     # Fast; +1 Atk when charging
	TOWERING,    # Slow, 3-tile reach; +2 Atk, -1 Def
	AMORPHOUS,   # Squeezes through any gap; Immune to flanking
	INSECTOID,   # Fast, can climb walls; +2 Def
}

enum OniInvulnerability {
	ARROW_IMMUNITY,   # Immune to non armor-piercing arrows
	BLADE_IMMUNITY,   # Reduce all blade damage by half before Reduction
	FIRE_IMMUNITY,    # Immune to fire-based attacks and spells
	SPELL_IMMUNITY,   # Immune to 1d3 randomly determined spells
	POISON_IMMUNITY,  # Immune to all poison effects
}

enum OniSpecialAttack {
	BREATH_WEAPON,   # Common  — ranged line attack, damage = Fire k Fire
	CRUSHING_GRIP,   # Common  — grapple, target cannot act until Strength opposed roll won
	TAINT_SPIT,      # Uncommon — single-target ranged, +1 Taint Rank on hit
	REGENERATION,    # Uncommon — recovers Earth Wounds per round
	SPAWN,           # Rare    — produces 1d3 Bakemono Companies once per combat
	TAINT_AURA,      # Rare    — passive, all within Earth×5 ft gain +0.5 Taint/round
}

enum OniWeakness {
	FIRE,                  # Double damage from fire
	WATER,                 # Movement halved near water; -2 to all rolls in water
	SPECIFIC_SPELL_SCHOOL, # Full damage from one element's spells, ignoring Reduction
	SPECIFIC_WEAPON_TYPE,  # Reduction halved vs one weapon type (rolled at generation)
	SUNLIGHT,              # -2 to all rolls during daylight
	SOUND,                 # Earth check TN 20 or lose action vs specific sound
	NAMED_INDIVIDUAL,      # One character type deals full damage ignoring Reduction
}

# -- Horde Battle Outcome (s2.4.5 — LOCKED) ------------------------------------

enum HordeBattleOutcome {
	DECISIVE_DEFENDER_VICTORY,  # Horde routed quickly         → -1 SI
	CONTESTED_BATTLE,           # Horde fought hard before routing → -2 SI
	ATTACKER_PUSHED_BACK,       # Defender wins but pushed back  → -3 SI
	DEFENDER_OVERRUN,           # Garrison destroyed or routed   → -4 SI / breach
}

# -- Naval Enums (s11.9 — LOCKED) ------------------------------------------------

enum NavalWeather {
	CLEAR,
	WIND,
	RAIN,
	STORM,
	TYPHOON,
}

enum WaterSubtileType {
	RIVER,
	LAKE,
	COASTAL,
	OCEAN,
}

enum NavalEngagementLevel {
	RESERVES,
	DISENGAGED,
	ENGAGED,
	HEAVILY_ENGAGED,
}


enum GreatFortune {
	BENTEN,
	BISHAMON,
	DAIKOKU,
	EBISU,
	FUKUROKUJIN,
	HOTEI,
	JUROJIN,
}


enum WorshipTier {
	NONE,
	RESTLESS,
	DISPLEASED,
	WRATHFUL,
}


enum MinorFortune {
	INARI,
	KENRO_JI_JIN,
	KUROSHIN,
	TOYOUKE_OMIKAMA,
	HACHIMAN,
	OSANO_WO,
	GOEMON,
	KISADA,
	KOSHIN,
	HARUHIKO,
	TSI_XING_GUO,
	SUITENGU,
	HUJOKUKO,
	JIZO,
	KOJI,
	HAMANRI,
	SAIBANKAN,
	EMMA_O,
	TENGEN,
	SADAHAKO,
	KO_NO_HAMA,
	MEGUMI,
	MUZAKA,
}


enum MinorBlessingTier {
	NONE,
	NOTICED,
	FAVORED,
	BELOVED,
}

# -- Companion Species (s57.39.6 — LOCKED) -------------------------------------
enum CompanionSpecies {
	DOG,
	PIGEON,
	RIDING_HORSE,
	FALCON,
	WAR_DOG,
	WARHORSE,
	WARCAT,
}


# -- Spiritual Insurgency (s56.16 — LOCKED) ------------------------------------
enum SpiritRealm {
	GAKI_DO,
	TOSHIGOKU,
	CHIKUSHUDO,
	SAKKAKU,
	MEIDO,
	YUME_DO,
}


enum SpiritualEventType {
	REALM_OVERLAP,
	ELEMENTAL_IMBALANCE,
}


enum SpiritualSeverity {
	MILD,
	MODERATE,
	SEVERE,
	CATASTROPHIC,
}
