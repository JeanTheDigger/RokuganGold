class_name RoleRegistry
## Centralized role and position definitions.
## All role string constants, position lookups, and lord rank helpers live here.


# -- Position Type Enum --------------------------------------------------------

enum PositionType {
	EMPEROR,
	IMPERIAL_HEIR,
	IMPERIAL_ADVISOR,
	IMPERIAL_CHANCELLOR,
	IMPERIAL_HERALD,
	IMPERIAL_TREASURER,
	VOICE_OF_EMPEROR,
	EMERALD_CHAMPION,
	JADE_CHAMPION,
	AMETHYST_CHAMPION,
	TURQUOISE_CHAMPION,
	TOPAZ_CHAMPION,
	RUBY_CHAMPION,
	IMPERIAL_FAMILY_DAIMYO,
	CLAN_CHAMPION,
	FAMILY_DAIMYO,
	RIKUGUNSHOKAN,
	SENIOR_COURTIER,
	CLAN_MAGISTRATE_COMMANDER,
	SCHOOL_MASTER,
	PROVINCIAL_DAIMYO,
	LOCAL_DAIMYO,
	CLAN_MAGISTRATE,
	GARRISON_COMMANDER,
	SHIREIKAN,
	TAISA,
	CHUI,
	TEMPLE_HEAD,
	MONASTERY_ABBOT,
	EMERALD_MAGISTRATE,
	JADE_MAGISTRATE,
	INQUISITOR_LEADER,
	WITCH_HUNTER_LEADER,
	KUROIBAN_LEADER,
	YORIKI,
	MINOR_CLAN_CHAMPION,
	MINOR_CLAN_SENIOR,
	WALL_SEGMENT_COMMANDER,
	HIRUMA_SCOUT_COMMANDER,
	SAMURAI,
	# Otosan Uchi governance (s2.3.23) — appended last to keep existing enum
	# values stable across saves.
	SENTAKU_TRIBUNAL_CHAIR,
	SENTAKU_TRIBUNAL_MEMBER,
	GOVERNOR_OTOSAN_UCHI,
}


# -- Position Name Constants ---------------------------------------------------
# Use these instead of string literals when comparing role_position.

const EMPEROR: String = "Emperor"
const IMPERIAL_HEIR: String = "Imperial Heir"
const IMPERIAL_ADVISOR: String = "Imperial Advisor"
const IMPERIAL_CHANCELLOR: String = "Imperial Chancellor"
const IMPERIAL_HERALD: String = "Imperial Herald"
const IMPERIAL_TREASURER: String = "Imperial Treasurer"
const VOICE_OF_EMPEROR: String = "Voice of the Emperor"
const EMERALD_CHAMPION: String = "Emerald Champion"
const JADE_CHAMPION: String = "Jade Champion"
const AMETHYST_CHAMPION: String = "Amethyst Champion"
const TURQUOISE_CHAMPION: String = "Turquoise Champion"
const TOPAZ_CHAMPION: String = "Topaz Champion"
const RUBY_CHAMPION: String = "Ruby Champion"
const IMPERIAL_FAMILY_DAIMYO: String = "Imperial Family Daimyo"
const CLAN_CHAMPION: String = "Clan Champion"
const FAMILY_DAIMYO: String = "Family Daimyo"
const RIKUGUNSHOKAN: String = "Rikugunshokan"
const SENIOR_COURTIER: String = "Senior Courtier"
const CLAN_MAGISTRATE_COMMANDER: String = "Clan Magistrate Commander"
const SCHOOL_MASTER: String = "School Master"
const PROVINCIAL_DAIMYO: String = "Provincial Daimyo"
const LOCAL_DAIMYO: String = "Local Daimyo"
const CLAN_MAGISTRATE: String = "Clan Magistrate"
const GARRISON_COMMANDER: String = "Garrison Commander"
const SHIREIKAN: String = "Shireikan"
const TAISA: String = "Taisa"
const CHUI: String = "Chui"
const TEMPLE_HEAD: String = "Temple Head"
const MONASTERY_ABBOT: String = "Monastery Abbot"
const EMERALD_MAGISTRATE: String = "Emerald Magistrate"
const JADE_MAGISTRATE: String = "Jade Magistrate"
const INQUISITOR_LEADER: String = "Inquisitor Leader"
const WITCH_HUNTER_LEADER: String = "Witch Hunter Leader"
const KUROIBAN_LEADER: String = "Kuroiban Leader"
const YORIKI: String = "Yoriki"
const MINOR_CLAN_CHAMPION: String = "Minor Clan Champion"
const MINOR_CLAN_SENIOR: String = "Minor Clan Senior"
const WALL_SEGMENT_COMMANDER: String = "Wall Segment Commander"
const HIRUMA_SCOUT_COMMANDER: String = "Hiruma Scout Commander"
const SENTAKU_TRIBUNAL_CHAIR: String = "Sentaku Tribunal Chair"
const SENTAKU_TRIBUNAL_MEMBER: String = "Sentaku Tribunal Member"
# All 15 Otosan Uchi Governors share role_position "Governor"; the district they
# rule is distinguished by L5RCharacterData.governed_zone_id (s2.3.23).
const GOVERNOR_OTOSAN_UCHI: String = "Governor"


# -- Enum ↔ String Mapping -----------------------------------------------------

const POSITION_NAMES: Dictionary = {
	PositionType.EMPEROR: EMPEROR,
	PositionType.IMPERIAL_HEIR: IMPERIAL_HEIR,
	PositionType.IMPERIAL_ADVISOR: IMPERIAL_ADVISOR,
	PositionType.IMPERIAL_CHANCELLOR: IMPERIAL_CHANCELLOR,
	PositionType.IMPERIAL_HERALD: IMPERIAL_HERALD,
	PositionType.IMPERIAL_TREASURER: IMPERIAL_TREASURER,
	PositionType.VOICE_OF_EMPEROR: VOICE_OF_EMPEROR,
	PositionType.EMERALD_CHAMPION: EMERALD_CHAMPION,
	PositionType.JADE_CHAMPION: JADE_CHAMPION,
	PositionType.AMETHYST_CHAMPION: AMETHYST_CHAMPION,
	PositionType.TURQUOISE_CHAMPION: TURQUOISE_CHAMPION,
	PositionType.TOPAZ_CHAMPION: TOPAZ_CHAMPION,
	PositionType.RUBY_CHAMPION: RUBY_CHAMPION,
	PositionType.IMPERIAL_FAMILY_DAIMYO: IMPERIAL_FAMILY_DAIMYO,
	PositionType.CLAN_CHAMPION: CLAN_CHAMPION,
	PositionType.FAMILY_DAIMYO: FAMILY_DAIMYO,
	PositionType.RIKUGUNSHOKAN: RIKUGUNSHOKAN,
	PositionType.SENIOR_COURTIER: SENIOR_COURTIER,
	PositionType.CLAN_MAGISTRATE_COMMANDER: CLAN_MAGISTRATE_COMMANDER,
	PositionType.SCHOOL_MASTER: SCHOOL_MASTER,
	PositionType.PROVINCIAL_DAIMYO: PROVINCIAL_DAIMYO,
	PositionType.LOCAL_DAIMYO: LOCAL_DAIMYO,
	PositionType.CLAN_MAGISTRATE: CLAN_MAGISTRATE,
	PositionType.GARRISON_COMMANDER: GARRISON_COMMANDER,
	PositionType.SHIREIKAN: SHIREIKAN,
	PositionType.TAISA: TAISA,
	PositionType.CHUI: CHUI,
	PositionType.TEMPLE_HEAD: TEMPLE_HEAD,
	PositionType.MONASTERY_ABBOT: MONASTERY_ABBOT,
	PositionType.EMERALD_MAGISTRATE: EMERALD_MAGISTRATE,
	PositionType.JADE_MAGISTRATE: JADE_MAGISTRATE,
	PositionType.INQUISITOR_LEADER: INQUISITOR_LEADER,
	PositionType.WITCH_HUNTER_LEADER: WITCH_HUNTER_LEADER,
	PositionType.KUROIBAN_LEADER: KUROIBAN_LEADER,
	PositionType.YORIKI: YORIKI,
	PositionType.MINOR_CLAN_CHAMPION: MINOR_CLAN_CHAMPION,
	PositionType.MINOR_CLAN_SENIOR: MINOR_CLAN_SENIOR,
	PositionType.WALL_SEGMENT_COMMANDER: WALL_SEGMENT_COMMANDER,
	PositionType.HIRUMA_SCOUT_COMMANDER: HIRUMA_SCOUT_COMMANDER,
	PositionType.SAMURAI: "",
	PositionType.SENTAKU_TRIBUNAL_CHAIR: SENTAKU_TRIBUNAL_CHAIR,
	PositionType.SENTAKU_TRIBUNAL_MEMBER: SENTAKU_TRIBUNAL_MEMBER,
	PositionType.GOVERNOR_OTOSAN_UCHI: GOVERNOR_OTOSAN_UCHI,
}


# -- Required Rank by Position (s52a A23) ---------------------------------------

const POSITION_RANK: Dictionary = {
	PositionType.EMPEROR: 5,
	PositionType.IMPERIAL_HEIR: 4,
	PositionType.IMPERIAL_ADVISOR: 4,
	PositionType.IMPERIAL_CHANCELLOR: 4,
	PositionType.IMPERIAL_HERALD: 3,
	PositionType.IMPERIAL_TREASURER: 3,
	PositionType.VOICE_OF_EMPEROR: 3,
	PositionType.EMERALD_CHAMPION: 5,
	PositionType.JADE_CHAMPION: 5,
	PositionType.AMETHYST_CHAMPION: 4,
	PositionType.TURQUOISE_CHAMPION: 3,
	PositionType.TOPAZ_CHAMPION: 2,
	PositionType.RUBY_CHAMPION: 4,
	PositionType.IMPERIAL_FAMILY_DAIMYO: 4,
	PositionType.CLAN_CHAMPION: 5,
	PositionType.FAMILY_DAIMYO: 4,
	PositionType.RIKUGUNSHOKAN: 4,
	PositionType.SENIOR_COURTIER: 3,
	PositionType.CLAN_MAGISTRATE_COMMANDER: 3,
	PositionType.SCHOOL_MASTER: 5,
	PositionType.PROVINCIAL_DAIMYO: 3,
	PositionType.LOCAL_DAIMYO: 2,
	PositionType.CLAN_MAGISTRATE: 2,
	PositionType.GARRISON_COMMANDER: 2,
	PositionType.SHIREIKAN: 4,
	PositionType.TAISA: 3,
	PositionType.CHUI: 2,
	PositionType.TEMPLE_HEAD: 5,
	PositionType.MONASTERY_ABBOT: 5,
	PositionType.EMERALD_MAGISTRATE: 4,
	PositionType.JADE_MAGISTRATE: 4,
	PositionType.INQUISITOR_LEADER: 5,
	PositionType.WITCH_HUNTER_LEADER: 5,
	PositionType.KUROIBAN_LEADER: 5,
	PositionType.YORIKI: 2,
	PositionType.MINOR_CLAN_CHAMPION: 4,
	PositionType.MINOR_CLAN_SENIOR: 3,
	PositionType.WALL_SEGMENT_COMMANDER: 4,
	PositionType.HIRUMA_SCOUT_COMMANDER: 4,
	PositionType.SAMURAI: 1,
	# PROVISIONAL (s52a world-init category): insight ranks mirror comparable
	# positions (Imperial Family Daimyo 4 / Senior Courtier 3). GDD s2.3.23 gives
	# Status but not insight rank for these.
	PositionType.SENTAKU_TRIBUNAL_CHAIR: 4,
	PositionType.SENTAKU_TRIBUNAL_MEMBER: 3,
	PositionType.GOVERNOR_OTOSAN_UCHI: 3,
}


# -- Status by Position (s52a A24) ----------------------------------------------

const POSITION_STATUS: Dictionary = {
	PositionType.EMPEROR: 10.0,
	PositionType.IMPERIAL_HEIR: 8.0,
	PositionType.IMPERIAL_ADVISOR: 7.0,
	PositionType.IMPERIAL_CHANCELLOR: 7.0,
	PositionType.IMPERIAL_HERALD: 6.5,
	PositionType.IMPERIAL_TREASURER: 6.5,
	PositionType.VOICE_OF_EMPEROR: 6.5,
	PositionType.EMERALD_CHAMPION: 7.5,
	PositionType.JADE_CHAMPION: 7.0,
	PositionType.AMETHYST_CHAMPION: 6.0,
	PositionType.TURQUOISE_CHAMPION: 6.0,
	PositionType.TOPAZ_CHAMPION: 5.0,
	PositionType.RUBY_CHAMPION: 6.0,
	PositionType.IMPERIAL_FAMILY_DAIMYO: 6.0,
	PositionType.CLAN_CHAMPION: 8.0,
	PositionType.FAMILY_DAIMYO: 6.0,
	PositionType.RIKUGUNSHOKAN: 5.5,
	PositionType.SENIOR_COURTIER: 5.0,
	PositionType.CLAN_MAGISTRATE_COMMANDER: 4.5,
	PositionType.SCHOOL_MASTER: 5.0,
	PositionType.PROVINCIAL_DAIMYO: 5.0,
	PositionType.LOCAL_DAIMYO: 4.0,
	PositionType.CLAN_MAGISTRATE: 3.0,
	PositionType.GARRISON_COMMANDER: 2.5,
	PositionType.SHIREIKAN: 4.5,
	PositionType.TAISA: 3.5,
	PositionType.CHUI: 2.5,
	PositionType.TEMPLE_HEAD: 3.5,
	PositionType.MONASTERY_ABBOT: 3.5,
	PositionType.EMERALD_MAGISTRATE: 4.0,
	PositionType.JADE_MAGISTRATE: 4.0,
	PositionType.INQUISITOR_LEADER: 4.0,
	PositionType.WITCH_HUNTER_LEADER: 4.0,
	PositionType.KUROIBAN_LEADER: 4.0,
	PositionType.YORIKI: 2.0,
	PositionType.MINOR_CLAN_CHAMPION: 5.0,
	PositionType.MINOR_CLAN_SENIOR: 3.5,
	PositionType.WALL_SEGMENT_COMMANDER: 3.5,
	PositionType.HIRUMA_SCOUT_COMMANDER: 3.5,
	PositionType.SAMURAI: 1.0,
	# s2.3.23: Chair 6.5, members 6.0. Governor default 4.5 (Toshisoto); Ekohikei
	# Governors are raised to 5.0 at creation (rarer honour).
	PositionType.SENTAKU_TRIBUNAL_CHAIR: 6.5,
	PositionType.SENTAKU_TRIBUNAL_MEMBER: 6.0,
	PositionType.GOVERNOR_OTOSAN_UCHI: 4.5,
}


# -- Military Rank by Position --------------------------------------------------

const POSITION_MILITARY_RANK: Dictionary = {
	PositionType.RIKUGUNSHOKAN: Enums.MilitaryRank.RIKUGUNSHOKAN,
	PositionType.SHIREIKAN: Enums.MilitaryRank.SHIREIKAN,
	PositionType.TAISA: Enums.MilitaryRank.TAISA,
	PositionType.CHUI: Enums.MilitaryRank.CHUI,
	PositionType.GARRISON_COMMANDER: Enums.MilitaryRank.GUNSO,
	PositionType.WALL_SEGMENT_COMMANDER: Enums.MilitaryRank.CHUI,
}


# -- Stipend by Position (s4.3) -------------------------------------------------

const POSITION_STIPEND: Dictionary = {
	PositionType.CLAN_CHAMPION: 5.0,
	PositionType.MINOR_CLAN_CHAMPION: 3.0,
	PositionType.FAMILY_DAIMYO: 3.0,
	PositionType.PROVINCIAL_DAIMYO: 2.0,
	PositionType.LOCAL_DAIMYO: 1.0,
}


# -- School Type Preferences for Position Assignment ----------------------------

const BUSHI_POSITION_TYPES: Array[int] = [
	PositionType.EMERALD_CHAMPION,
	PositionType.JADE_CHAMPION,
	PositionType.RIKUGUNSHOKAN,
	PositionType.GARRISON_COMMANDER,
	PositionType.SHIREIKAN,
	PositionType.TAISA,
	PositionType.CHUI,
	PositionType.WALL_SEGMENT_COMMANDER,
	PositionType.HIRUMA_SCOUT_COMMANDER,
	PositionType.MINOR_CLAN_CHAMPION,
]

const COURTIER_POSITION_TYPES: Array[int] = [
	PositionType.IMPERIAL_ADVISOR,
	PositionType.IMPERIAL_CHANCELLOR,
	PositionType.IMPERIAL_HERALD,
	PositionType.IMPERIAL_TREASURER,
	PositionType.VOICE_OF_EMPEROR,
	PositionType.SENIOR_COURTIER,
	PositionType.EMERALD_MAGISTRATE,
	# Otosan Uchi governance is politics (s2.3.23: "Courtier — primary").
	PositionType.SENTAKU_TRIBUNAL_CHAIR,
	PositionType.SENTAKU_TRIBUNAL_MEMBER,
	PositionType.GOVERNOR_OTOSAN_UCHI,
]

const SHUGENJA_POSITION_TYPES: Array[int] = [
	PositionType.JADE_MAGISTRATE,
	PositionType.TEMPLE_HEAD,
]


# -- Position Categories -------------------------------------------------------

const MAGISTRATE_POSITIONS: Array[String] = [
	CLAN_MAGISTRATE,
	EMERALD_MAGISTRATE,
	CLAN_MAGISTRATE_COMMANDER,
]

const LORD_POSITIONS: Array[String] = [
	EMPEROR,
	IMPERIAL_HEIR,
	IMPERIAL_ADVISOR,
	IMPERIAL_CHANCELLOR,
	IMPERIAL_HERALD,
	IMPERIAL_TREASURER,
	VOICE_OF_EMPEROR,
	EMERALD_CHAMPION,
	JADE_CHAMPION,
	AMETHYST_CHAMPION,
	TURQUOISE_CHAMPION,
	TOPAZ_CHAMPION,
	RUBY_CHAMPION,
	IMPERIAL_FAMILY_DAIMYO,
	CLAN_CHAMPION,
	FAMILY_DAIMYO,
	RIKUGUNSHOKAN,
	SENIOR_COURTIER,
	CLAN_MAGISTRATE_COMMANDER,
	SCHOOL_MASTER,
	PROVINCIAL_DAIMYO,
	LOCAL_DAIMYO,
	CLAN_MAGISTRATE,
	GARRISON_COMMANDER,
	SHIREIKAN,
	TAISA,
	CHUI,
	TEMPLE_HEAD,
	MONASTERY_ABBOT,
	EMERALD_MAGISTRATE,
	JADE_MAGISTRATE,
	INQUISITOR_LEADER,
	WITCH_HUNTER_LEADER,
	KUROIBAN_LEADER,
	YORIKI,
	MINOR_CLAN_CHAMPION,
	MINOR_CLAN_SENIOR,
	WALL_SEGMENT_COMMANDER,
	HIRUMA_SCOUT_COMMANDER,
]


# -- Skill and Virtue Weights for Vacancy Candidates ----------------------------

const POSITION_SKILL_WEIGHTS: Dictionary = {
	CLAN_MAGISTRATE: ["Investigation", "Lore: Law", "Etiquette"],
	EMERALD_MAGISTRATE: ["Investigation", "Lore: Law", "Etiquette"],
	GARRISON_COMMANDER: ["Battle", "Defense", "Kenjutsu"],
	"military_commander": ["Battle", "War", "Kenjutsu"],
	TEMPLE_HEAD: ["Lore: Theology", "Meditation"],
	MONASTERY_ABBOT: ["Lore: Theology", "Meditation", "Jiujutsu"],
	SCHOOL_MASTER: ["Lore: Theology", "Instruction"],
}

const POSITION_VIRTUE_BONUSES: Dictionary = {
	CLAN_MAGISTRATE: [Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO],
	EMERALD_MAGISTRATE: [Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO],
	GARRISON_COMMANDER: [Enums.BushidoVirtue.YU, Enums.BushidoVirtue.CHUGI],
	"military_commander": [Enums.BushidoVirtue.YU, Enums.BushidoVirtue.CHUGI],
	TEMPLE_HEAD: [Enums.BushidoVirtue.REI, Enums.BushidoVirtue.JIN],
	MONASTERY_ABBOT: [Enums.BushidoVirtue.REI, Enums.BushidoVirtue.JIN],
	SCHOOL_MASTER: [Enums.BushidoVirtue.MEIYO, Enums.BushidoVirtue.GI],
}

const POSITION_SCHOOL_TYPE_BONUS: Dictionary = {
	TEMPLE_HEAD: [Enums.SchoolType.SHUGENJA, Enums.SchoolType.MONK],
	MONASTERY_ABBOT: [Enums.SchoolType.MONK],
}


# -- Helper Functions -----------------------------------------------------------

static func has_position(character: L5RCharacterData) -> bool:
	return character.role_position != ""


static func is_magistrate(role_position: String) -> bool:
	return role_position in MAGISTRATE_POSITIONS


static func get_position_name(position_type: int) -> String:
	return POSITION_NAMES.get(position_type, "")


static func get_stipend(position_type: int) -> float:
	return POSITION_STIPEND.get(position_type, 0.0)


static func get_stipend_by_name(role_position: String) -> float:
	for pt: int in POSITION_STIPEND:
		if POSITION_NAMES.get(pt, "") == role_position:
			return POSITION_STIPEND[pt]
	return 0.0


static func lord_rank_from_status(status: float) -> Enums.LordRank:
	if status >= 9.0:
		return Enums.LordRank.IMPERIAL
	elif status >= 7.0:
		return Enums.LordRank.CLAN_CHAMPION
	elif status >= 6.0:
		return Enums.LordRank.FAMILY_DAIMYO
	elif status >= 5.0:
		return Enums.LordRank.PROVINCIAL_DAIMYO
	elif status >= 4.0:
		return Enums.LordRank.CITY_DAIMYO
	return Enums.LordRank.VILLAGE_HEADMAN
