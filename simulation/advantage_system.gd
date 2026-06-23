class_name AdvantageSystem
## GDD s45 — Advantages and Disadvantages.
## Pure query and effect layer. No dice rolls; callers supply context dicts.
##
## Context dict keys (all optional; unrecognised keys are silently ignored):
##   "is_contested"               bool   — this roll is part of a contested check
##   "is_school_skill"            bool   — skill is in the character's school list
##   "is_social"                  bool   — Etiquette / Courtier / Sincerity / Temptation
##   "is_voice_perform"           bool   — Perform roll using voice (Singing, Oratory)
##   "is_memory"                  bool   — remembering something exactly (PRECISE_MEMORY)
##   "is_stealth"                 bool   — any Stealth roll
##   "is_ambush_detection"        bool   — Investigation(Notice)/Perception vs ambush
##   "is_spell_casting"           bool   — casting a spell
##   "spell_type"                 String — "sense", "commune", "summon" for FRIENDLY_KAMI
##   "element"                    Enums.Ring — element of spell / ring roll
##   "is_ring_roll"               bool   — pure Trait/Ring roll (no skill)
##   "is_resist_temptation"       bool   — resisting a Temptation roll
##   "is_resist_intimidation"     bool   — resisting Intimidation
##   "is_resist_fear"             bool   — resisting a Fear effect
##   "is_vs_persuasion"           bool   — HEARTLESS: being target of Courtier/Sin/Temp
##   "honor_rank_adding"          bool   — roll adds Honor Rank (BALANCE fires here)
##   "attacker_gender_matches"    bool   — for DANGEROUS_BEAUTY / LECHERY
##   "opponent_clan"              String — clan of the other character (contested)
##   "opponent_family"            String — family of the other character
##   "opponent_is_shugenja"       bool
##   "opponent_is_artisan"        bool
##   "opponent_is_imperial"       bool
##   "opponent_is_naga"           bool
##   "opponent_is_commoner"       bool   — opponent is non-samurai Rokugani
##   "opponent_is_spirit"         bool   — opponent is a spirit entity (CURSED Maigo_no_Musha)
##   "opponent_id"                int    — character_id of opponent
##   "is_resist_manipulation"     bool   — CLEAR_THINKER: opponent confusing/manipulating
##   "is_calligraphy"             bool   — Calligraphy skill roll (IMPERIAL_SCRIBE FR)
##   "is_athletics"               bool   — Athletics roll (DAREDEVIL)
##   "is_void_spend"              bool   — spending Void on this roll (DAREDEVIL, TOUCH_OF_VOID)
##   "is_unarmed_damage"          bool   — HANDS_OF_STONE
##   "is_weapon_skill"            bool   — CRAB_HANDS unskilled gate
##   "is_low_skill"               bool   — CRAFTY unskilled gate (Low Skills)
##   "is_lore_skill"              bool   — SAGE unskilled gate
##   "is_perform_skill"           bool   — SENSATION unskilled gate
##   "is_artisan_skill"           bool   — SOUL_OF_ARTISTRY
##   "is_craft_skill"             bool   — SOUL_OF_ARTISTRY
##   "is_detecting_intentions"    bool   — SHADOWED_HEART: opponent reading your intent
##   "is_navigation"              bool   — Navigation emphasis roll (WANDERER)
##   "situation_tags"             Array  — tags matching phobia/compulsion triggers
##   "lost_love_clan"             String — clan/family being interacted with (LOST_LOVE)
##   "lost_love_province_id"      int    — province_id being entered (LOST_LOVE)
##   "is_debate"                  bool   — public debate in progress (CONTRARY)
##   "max_glory_rank"             float  — highest Glory Rank of debate participants
##   "debater_direction"          int    — +1 or -1 position direction (CONTRARY NPC)
##   "is_perception_based"        bool   — Perception-based roll (BAD_EYESIGHT, CURSED Meido)
##   "is_unoccupied"              bool   — character is idle/unoccupied (CURSED Meido)
##   "is_resist_disease_or_poison" bool  — resisting disease or poison (SEVEN_FORTUNES_CURSE Jurojin)
##   "is_in_celestial_temple"     bool   — inside a celestial temple (CURSED Tengoku)
##   "is_sensing_feelings"        bool   — Courtier roll to sense feelings (INNER_GIFT Empathy)
##   "is_void_enhance"            bool   — standard +1k1 void spend (CONSUMED Determination)
##   "is_honest_sincerity"        bool   — Sincerity (Honesty) roll (FAILURE_OF_BUSHIDO Honesty)
##   "is_negate_wounds"           bool   — void spend to negate wound penalties (FAILURE_OF_BUSHIDO Duty)
##   "is_new_topic"               bool   — encountering a new topic (CONSUMED Knowledge)
##   "is_resist_taint"            bool   — resisting Taint (CURSED Jigoku, BAD_FORTUNE Moto_Curse)
##   "is_honest"                  bool   — Sincerity Honesty emphasis roll (PARAGON Honesty)
##   "is_deceit"                  bool   — Sincerity Deceit emphasis roll (TOUCH Sakkaku)
##   "is_conviction"              bool   — Sincerity conviction roll (FAILURE_OF_BUSHIDO Sincerity)
##   "is_physical_trait"          bool   — Physical Trait roll (TOUCH_OF_SPIRIT Jigoku)
##   "is_combat"                  bool   — attack or damage roll (TOUCH_OF_SPIRIT Jigoku)
##   "is_coercion"                bool   — coercive social roll (SEVEN_FORTUNES_BLESSING Benten)
##   "using_alternate_identity"   bool   — STOLEN_IDENTITY
##   "bland_active"               bool   — BLAND voluntary TN increase
##   "opponent_higher_glory"      bool   — FAILURE_OF_BUSHIDO Courage: facing higher-ranked foe
##   "opponent_is_shadowlands"    bool   — FAILURE_OF_BUSHIDO Courage: Shadowlands opponent
##   "is_technique_void_spend"    bool   — void spend required by a School Technique
##   "involves_missing_limb"      bool   — task requires the missing limb (MISSING_LIMB)
##   "is_leg_agility_roll"        bool   — Agility roll involving lower limbs (LAME)
##   "is_wound_check"             bool   — wound rank or disease resistance check (BAD_HEALTH)
##   "is_move_action"             bool   — movement action (LAME, SMALL, BLIND)
##   "is_bribery"                 bool   — Temptation Bribery emphasis (GREEDY)
##   "is_seduction"               bool   — Temptation Seduction emphasis (LECHERY)
##   "is_willpower_contest"       bool   — Willpower contested roll (FRAIL_MIND)
##   "is_acting_for_lower_status" bool   — acting on behalf of someone of lower Status (PARAGON Compassion, FAILURE_OF_BUSHIDO Compassion, INSENSITIVE)
##   "is_acting_at_personal_risk_for_other" bool — placing self at personal risk for another's welfare (INSENSITIVE)
##   "is_known_territory"         bool   — character is in their WAY_OF_THE_LAND known region

# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

static func has_advantage(character: L5RCharacterData, type: Enums.Advantage) -> bool:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == type:
			return true
	return false


static func get_advantage(character: L5RCharacterData, type: Enums.Advantage) -> AdvantageData:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == type:
			return adv
	return null


static func has_disadvantage(character: L5RCharacterData, type: Enums.Disadvantage) -> bool:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == type:
			return true
	return false


static func get_disadvantage(character: L5RCharacterData, type: Enums.Disadvantage) -> DisadvantageData:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == type:
			return dis
	return null


# ---------------------------------------------------------------------------
# Advantage / Disadvantage category + point catalog (transcribed from GDD s45).
# category ∈ {Mental, Physical, Social, Spiritual, Material, Mystical, Varies,
# compound "A/B", or "" when s45 gives none — e.g. Wanderer}. points = base point
# cost (0 = variable; use the held entry's rank). Used by the s38 Disadvantage kiho.
# ---------------------------------------------------------------------------

const ADVANTAGE_CATALOG: Dictionary = {
	Enums.Advantage.ABSOLUTE_DIRECTION: {"category": "Mental", "points": 1},
	Enums.Advantage.ALLIES: {"category": "Social", "points": 0},
	Enums.Advantage.BALANCE: {"category": "Mental", "points": 2},
	Enums.Advantage.BATTLE_HEALING: {"category": "Mystical", "points": 5},
	Enums.Advantage.BLACKMAIL: {"category": "Social", "points": 0},
	Enums.Advantage.BLAND: {"category": "Physical", "points": 2},
	Enums.Advantage.BLISSFUL_BETROTHAL: {"category": "Social", "points": 3},
	Enums.Advantage.BLOOD_OF_OSANO_WO: {"category": "Spiritual", "points": 4},
	Enums.Advantage.CHOSEN_BY_THE_ORACLES: {"category": "Spiritual", "points": 6},
	Enums.Advantage.CLEAR_THINKER: {"category": "Mental", "points": 3},
	Enums.Advantage.CRAB_HANDS: {"category": "Physical", "points": 3},
	Enums.Advantage.CRAFTY: {"category": "Mental", "points": 3},
	Enums.Advantage.DANGEROUS_BEAUTY: {"category": "Physical", "points": 3},
	Enums.Advantage.DAREDEVIL: {"category": "Mental", "points": 3},
	Enums.Advantage.DARK_PARAGON: {"category": "Mental", "points": 5},
	Enums.Advantage.DARLING_OF_THE_COURT: {"category": "Social", "points": 2},
	Enums.Advantage.DIFFERENT_SCHOOL: {"category": "Social", "points": 5},
	Enums.Advantage.ELEMENTAL_BLESSING: {"category": "Spiritual", "points": 4},
	Enums.Advantage.ENLIGHTENED: {"category": "Spiritual", "points": 6},
	Enums.Advantage.FAME: {"category": "Social", "points": 3},
	Enums.Advantage.FORBIDDEN_KNOWLEDGE: {"category": "Mental", "points": 5},
	Enums.Advantage.FRIENDLY_KAMI: {"category": "Spiritual", "points": 5},
	Enums.Advantage.FRIEND_OF_THE_BROTHERHOOD: {"category": "Spiritual", "points": 5},
	Enums.Advantage.FRIEND_OF_THE_ELEMENTS: {"category": "Spiritual", "points": 4},
	Enums.Advantage.GAIJIN_GEAR: {"category": "Material", "points": 5},
	Enums.Advantage.GENTRY: {"category": "Material", "points": 0},
	Enums.Advantage.GREAT_DESTINY: {"category": "Spiritual", "points": 5},
	Enums.Advantage.GREAT_POTENTIAL: {"category": "Varies", "points": 5},
	Enums.Advantage.HANDS_OF_STONE: {"category": "Physical", "points": 6},
	Enums.Advantage.HEARTLESS: {"category": "Mental", "points": 4},
	Enums.Advantage.HEART_OF_VENGEANCE: {"category": "Social", "points": 5},
	Enums.Advantage.HERO_OF_THE_PEOPLE: {"category": "Social", "points": 2},
	Enums.Advantage.HIGHER_PURPOSE: {"category": "Mental", "points": 3},
	Enums.Advantage.IMPERIAL_SCRIBE: {"category": "Social", "points": 4},
	Enums.Advantage.IMPERIAL_SPOUSE: {"category": "Social", "points": 5},
	Enums.Advantage.INHERITANCE: {"category": "Material", "points": 5},
	Enums.Advantage.INHERITANCE_ASAHINA_BLADE: {"category": "Material", "points": 9},
	Enums.Advantage.INHERITANCE_KOBUNE: {"category": "Material", "points": 10},
	Enums.Advantage.INHERITANCE_TRAINED_FALCON: {"category": "Material", "points": 2},
	Enums.Advantage.INHERITANCE_WATER_HAMMER_ARMOR: {"category": "Material", "points": 0},
	Enums.Advantage.INNER_GIFT: {"category": "Spiritual", "points": 7},
	Enums.Advantage.IRREPROACHABLE: {"category": "Mental", "points": 2},
	Enums.Advantage.ISHIKEN_DO: {"category": "Spiritual", "points": 8},
	Enums.Advantage.LANGUAGES: {"category": "Mental", "points": 1},
	Enums.Advantage.LARGE: {"category": "Physical", "points": 4},
	Enums.Advantage.MAGIC_RESISTANCE: {"category": "Spiritual", "points": 0},
	Enums.Advantage.MEDIUM: {"category": "Spiritual", "points": 4},
	Enums.Advantage.MULTIPLE_SCHOOLS: {"category": "Social", "points": 10},
	Enums.Advantage.NAGA_ANCESTRY: {"category": "Physical/Spiritual", "points": 7},
	Enums.Advantage.PARAGON: {"category": "Mental", "points": 7},
	Enums.Advantage.PERCEIVED_HONOR: {"category": "Social", "points": 0},
	Enums.Advantage.PRECISE_MEMORY: {"category": "Mental", "points": 3},
	Enums.Advantage.PRODIGY: {"category": "Physical", "points": 12},
	Enums.Advantage.QUICK: {"category": "Physical", "points": 6},
	Enums.Advantage.QUICK_HEALER: {"category": "Physical", "points": 3},
	Enums.Advantage.READ_LIPS: {"category": "Mental", "points": 4},
	Enums.Advantage.REINCARNATED: {"category": "Spiritual", "points": 6},
	Enums.Advantage.SACROSANCT: {"category": "Social", "points": 4},
	Enums.Advantage.SAGE: {"category": "Mental", "points": 4},
	Enums.Advantage.SAGE_OF_SWORD_AND_FAN: {"category": "Mental", "points": 7},
	Enums.Advantage.SENSATION: {"category": "Social", "points": 3},
	Enums.Advantage.SERVANT: {"category": "Material", "points": 5},
	Enums.Advantage.SEVEN_FORTUNES_BLESSING: {"category": "Spiritual", "points": 4},
	Enums.Advantage.SHADOWED_HEART: {"category": "Mental", "points": 5},
	Enums.Advantage.SILENT: {"category": "Physical", "points": 3},
	Enums.Advantage.SOCIAL_POSITION: {"category": "Social", "points": 6},
	Enums.Advantage.SOUL_OF_ARTISTRY: {"category": "Mental", "points": 4},
	Enums.Advantage.SPY_NETWORK: {"category": "Social", "points": 8},
	Enums.Advantage.STOLEN_IDENTITY: {"category": "Social", "points": 6},
	Enums.Advantage.STRATEGIST: {"category": "Mental", "points": 5},
	Enums.Advantage.STRENGTH_OF_THE_EARTH: {"category": "Physical", "points": 3},
	Enums.Advantage.STUDENT_OF_SHOURIDO: {"category": "Mental", "points": 9},
	Enums.Advantage.TACTICIAN: {"category": "Mental", "points": 4},
	Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS: {"category": "Spiritual", "points": 5},
	Enums.Advantage.VIRTUOUS: {"category": "Mental", "points": 3},
	Enums.Advantage.VOICE: {"category": "Physical", "points": 3},
	Enums.Advantage.VOID_VERSATILITY: {"category": "Spiritual", "points": 4},
	Enums.Advantage.WARY: {"category": "Mental", "points": 3},
	Enums.Advantage.WATANU_TRAINED: {"category": "Mental", "points": 1},
	Enums.Advantage.WAY_OF_THE_LAND: {"category": "Mental", "points": 2},
	Enums.Advantage.WEALTHY: {"category": "Material", "points": 0},
	Enums.Advantage.WELL_CONNECTED: {"category": "Social", "points": 0},
}

const DISADVANTAGE_CATALOG: Dictionary = {
	Enums.Disadvantage.ANACHRONISM: {"category": "Mental/Social", "points": 2},
	Enums.Disadvantage.ANTISOCIAL: {"category": "Social", "points": 0},
	Enums.Disadvantage.ASCETIC: {"category": "Mental", "points": 2},
	Enums.Disadvantage.BAD_EYESIGHT: {"category": "Physical", "points": 3},
	Enums.Disadvantage.BAD_FORTUNE: {"category": "Spiritual", "points": 3},
	Enums.Disadvantage.BAD_HEALTH: {"category": "Physical", "points": 4},
	Enums.Disadvantage.BITTER_BETROTHAL: {"category": "Social", "points": 2},
	Enums.Disadvantage.BLACKMAILED: {"category": "Social", "points": 0},
	Enums.Disadvantage.BLACK_SHEEP: {"category": "Social", "points": 3},
	Enums.Disadvantage.BLIND: {"category": "Physical", "points": 6},
	Enums.Disadvantage.BOUNTY: {"category": "Social", "points": 0},
	Enums.Disadvantage.BRASH: {"category": "Mental", "points": 3},
	Enums.Disadvantage.CANT_LIE: {"category": "Mental", "points": 2},
	Enums.Disadvantage.CAST_OUT: {"category": "Social", "points": 0},
	Enums.Disadvantage.COMPULSION: {"category": "Mental", "points": 2},
	Enums.Disadvantage.CONSUMED: {"category": "Mental", "points": 0},
	Enums.Disadvantage.CONTRARY: {"category": "Mental", "points": 3},
	Enums.Disadvantage.CURSED_BY_THE_REALM: {"category": "Spiritual", "points": 4},
	Enums.Disadvantage.DARK_SECRET: {"category": "Social", "points": 4},
	Enums.Disadvantage.DEBT: {"category": "Material/Social", "points": 0},
	Enums.Disadvantage.DISBELIEVER: {"category": "Mental", "points": 3},
	Enums.Disadvantage.DISHONORED: {"category": "Social", "points": 5},
	Enums.Disadvantage.DISTURBING_COUNTENANCE: {"category": "Physical", "points": 3},
	Enums.Disadvantage.DOUBT: {"category": "Mental", "points": 4},
	Enums.Disadvantage.ELEMENTAL_IMBALANCE: {"category": "Spiritual", "points": 0},
	Enums.Disadvantage.EPILEPSY: {"category": "Physical", "points": 4},
	Enums.Disadvantage.FAILURE_OF_BUSHIDO: {"category": "Mental", "points": 0},
	Enums.Disadvantage.FORCED_RETIREMENT: {"category": "Social", "points": 4},
	Enums.Disadvantage.FRAIL_MIND: {"category": "Mental", "points": 3},
	Enums.Disadvantage.GAIJIN_NAME: {"category": "Social", "points": 1},
	Enums.Disadvantage.GREEDY: {"category": "Mental", "points": 3},
	Enums.Disadvantage.GULLIBLE: {"category": "Mental", "points": 4},
	Enums.Disadvantage.HOSTAGE: {"category": "Social", "points": 3},
	Enums.Disadvantage.IDEALISTIC: {"category": "Mental", "points": 2},
	Enums.Disadvantage.INFAMOUS: {"category": "Social", "points": 2},
	Enums.Disadvantage.INSENSITIVE: {"category": "Mental", "points": 2},
	Enums.Disadvantage.JEALOUSY: {"category": "Mental", "points": 3},
	Enums.Disadvantage.LAME: {"category": "Physical", "points": 4},
	Enums.Disadvantage.LECHERY: {"category": "Social", "points": 2},
	Enums.Disadvantage.LOST_LOVE: {"category": "Mental", "points": 3},
	Enums.Disadvantage.LOW_PAIN_THRESHOLD: {"category": "Physical", "points": 4},
	Enums.Disadvantage.MEMBER_OF_CHRYSANTHEMUM_COURT: {"category": "Social", "points": 5},
	Enums.Disadvantage.MISSING_LIMB: {"category": "Physical", "points": 6},
	Enums.Disadvantage.MOMOKU: {"category": "Spiritual", "points": 8},
	Enums.Disadvantage.OBLIGATION: {"category": "Social", "points": 0},
	Enums.Disadvantage.OBTUSE: {"category": "Mental", "points": 3},
	Enums.Disadvantage.OVERCONFIDENT: {"category": "Mental", "points": 3},
	Enums.Disadvantage.PERMANENT_WOUND: {"category": "Physical", "points": 4},
	Enums.Disadvantage.PHOBIA: {"category": "Mental", "points": 1},
	Enums.Disadvantage.RUMORMONGER: {"category": "Social", "points": 4},
	Enums.Disadvantage.SEVEN_FORTUNES_CURSE: {"category": "Spiritual", "points": 3},
	Enums.Disadvantage.SHADOWLANDS_TAINT: {"category": "Spiritual", "points": 4},
	Enums.Disadvantage.SLEEPER_AGENT: {"category": "Mental", "points": 5},
	Enums.Disadvantage.SMALL: {"category": "Physical", "points": 3},
	Enums.Disadvantage.SOCIAL_DISADVANTAGE: {"category": "Social", "points": 3},
	Enums.Disadvantage.SOFT_HEARTED: {"category": "Mental", "points": 2},
	Enums.Disadvantage.SWORN_ENEMY: {"category": "Social", "points": 3},
	Enums.Disadvantage.TOUCH_OF_THE_VOID: {"category": "Spiritual", "points": 3},
	Enums.Disadvantage.TRUE_LOVE: {"category": "Mental", "points": 3},
	Enums.Disadvantage.UNCENTERED: {"category": "Spiritual", "points": 2},
	Enums.Disadvantage.WANDERER: {"category": "", "points": 2},
	Enums.Disadvantage.WEAKNESS: {"category": "Physical", "points": 6},
	Enums.Disadvantage.WRATH_OF_THE_KAMI: {"category": "Spiritual", "points": 3},
}


## Category string for an Advantage type (s45). "" if unknown.
static func get_advantage_category(t: Enums.Advantage) -> String:
	return ADVANTAGE_CATALOG.get(t, {}).get("category", "")


## Category string for a Disadvantage type (s45). "" if unknown.
static func get_disadvantage_category(t: Enums.Disadvantage) -> String:
	return DISADVANTAGE_CATALOG.get(t, {}).get("category", "")


## Effective point value of a held Advantage: the catalog base, or the entry's rank
## when the catalog lists it as variable (points 0).
static func get_advantage_points(adv: AdvantageData) -> int:
	var base: int = int(ADVANTAGE_CATALOG.get(adv.advantage_type, {}).get("points", 0))
	return base if base > 0 else maxi(1, adv.rank)


## Effective point value of a held Disadvantage: the catalog base, or the entry's
## rank when the catalog lists it as variable (points 0).
static func get_disadvantage_points(dis: DisadvantageData) -> int:
	var base: int = int(DISADVANTAGE_CATALOG.get(dis.disadvantage_type, {}).get("points", 0))
	return base if base > 0 else maxi(1, dis.rank)


## True when this Disadvantage's combat effects are transiently suppressed (s38
## Banish All Shadows). Read at the top of the combat-roll disadvantage loops.
static func _is_suppressed(character: L5RCharacterData, dis_type: Enums.Disadvantage) -> bool:
	if character.suppressed_disadvantage_type == int(dis_type):
		return true
	# Touch of Air's Grace (s33): negates the Disturbing Countenance Disadvantage while active.
	if character.has_day_buff("touch_of_airs_grace") and dis_type == Enums.Disadvantage.DISTURBING_COUNTENANCE:
		return true
	return false


## Count of Spiritual Advantages / Disadvantages (s38 Sense the Balance).
static func count_spiritual_advantages(character: L5RCharacterData) -> int:
	var n: int = 0
	for adv: AdvantageData in character.advantages:
		if "Spiritual" in get_advantage_category(adv.advantage_type):
			n += 1
	return n


static func count_spiritual_disadvantages(character: L5RCharacterData) -> int:
	var n: int = 0
	for dis: DisadvantageData in character.disadvantages:
		if "Spiritual" in get_disadvantage_category(dis.disadvantage_type):
			n += 1
	return n


## Highest-point Spiritual Advantage / Disadvantage not in exclude_types (s38 Sense
## the Balance reveal). Returns the Enums int, or −1 when none remain unrevealed.
static func get_highest_spiritual_advantage(character: L5RCharacterData, exclude_types: Array) -> int:
	var best: int = -1
	var best_pts: int = -1
	for adv: AdvantageData in character.advantages:
		if "Spiritual" not in get_advantage_category(adv.advantage_type):
			continue
		if int(adv.advantage_type) in exclude_types:
			continue
		var pts: int = get_advantage_points(adv)
		if pts > best_pts:
			best_pts = pts
			best = int(adv.advantage_type)
	return best


static func get_highest_spiritual_disadvantage(character: L5RCharacterData, exclude_types: Array) -> int:
	var best: int = -1
	var best_pts: int = -1
	for dis: DisadvantageData in character.disadvantages:
		if "Spiritual" not in get_disadvantage_category(dis.disadvantage_type):
			continue
		if int(dis.disadvantage_type) in exclude_types:
			continue
		var pts: int = get_disadvantage_points(dis)
		if pts > best_pts:
			best_pts = pts
			best = int(dis.disadvantage_type)
	return best


## Held Disadvantages whose category is Social, Spiritual, or Mental (s38 Spin the
## Kharmic Wheel — the swappable set).
static func get_swappable_disadvantages(character: L5RCharacterData) -> Array:
	var out: Array = []
	for dis: DisadvantageData in character.disadvantages:
		var cat: String = get_disadvantage_category(dis.disadvantage_type)
		if "Social" in cat or "Spiritual" in cat or "Mental" in cat:
			out.append(dis)
	return out


## A random fixed-point Disadvantage (Social/Spiritual/Mental) of the given point
## value, excluding types in exclude_types. r ∈ [0,1). −1 if none available. (s38
## Spin the Kharmic Wheel — the equal-value replacement.)
static func pick_equal_value_disadvantage(points: int, exclude_types: Array, r: float) -> int:
	var pool: Array = []
	for t: int in DISADVANTAGE_CATALOG:
		var e: Dictionary = DISADVANTAGE_CATALOG[t]
		if int(e.get("points", 0)) != points:
			continue
		var cat: String = e.get("category", "")
		if not ("Social" in cat or "Spiritual" in cat or "Mental" in cat):
			continue
		if t in exclude_types:
			continue
		pool.append(t)
	if pool.is_empty():
		return -1
	pool.sort()
	return int(pool[clampi(int(r * pool.size()), 0, pool.size() - 1)])


## Highest-point Disadvantage that is neither Spiritual nor Social (s38 Banish All
## Shadows target selection). null if the character has none.
static func get_highest_non_spiritual_social_disadvantage(character: L5RCharacterData) -> DisadvantageData:
	var best: DisadvantageData = null
	var best_pts: int = -1
	for dis: DisadvantageData in character.disadvantages:
		var cat: String = get_disadvantage_category(dis.disadvantage_type)
		if "Spiritual" in cat or "Social" in cat:
			continue
		var pts: int = get_disadvantage_points(dis)
		if pts > best_pts:
			best_pts = pts
			best = dis
	return best


# s37 The Void's Caress: negate one Mental OR Spiritual Disadvantage the target possesses, up to
# `max_points` in value (5 per the GDD). Returns the highest-point qualifying Disadvantage, or null.
static func get_highest_mental_or_spiritual_disadvantage(
		character: L5RCharacterData, max_points: int = 5) -> DisadvantageData:
	var best: DisadvantageData = null
	var best_pts: int = -1
	for dis: DisadvantageData in character.disadvantages:
		var cat: String = get_disadvantage_category(dis.disadvantage_type)
		if not ("Mental" in cat or "Spiritual" in cat):
			continue
		var pts: int = get_disadvantage_points(dis)
		if pts > max_points:
			continue
		if pts > best_pts:
			best_pts = pts
			best = dis
	return best



# ---------------------------------------------------------------------------
# Skill-roll bonus aggregator
# Returns {rolled: int, kept: int, free_raises: int}.
# Callers add returned values to their bonus_rolled / bonus_kept / flat_bonus.
# Negative values reduce dice (disadvantage penalties).
# ---------------------------------------------------------------------------

static func get_skill_bonus(
	character: L5RCharacterData,
	skill_name: String,
	context: Dictionary,
) -> Dictionary:
	var rolled: int = 0
	var kept: int = 0
	var free_raises: int = 0

	for adv: AdvantageData in character.advantages:
		match adv.advantage_type:

			Enums.Advantage.BALANCE:
				# +1k0 resist Temptation/Intimidation when adding Honor Rank
				if (context.get("is_resist_temptation", false) or context.get("is_resist_intimidation", false)) \
						and context.get("honor_rank_adding", false):
					rolled += 1

			Enums.Advantage.CHOSEN_BY_THE_ORACLES:
				# +1k1 to all Ring Rolls using the chosen Ring
				if context.get("is_ring_roll", false):
					var chosen: int = adv.metadata.get("ring", Enums.Ring.NONE)
					if chosen != Enums.Ring.NONE and context.get("element", Enums.Ring.NONE) == chosen:
						kept += 1

			Enums.Advantage.CLEAR_THINKER:
				# +1k0 Contested Rolls when opponent is confusing/manipulating you
				if context.get("is_contested", false) and context.get("is_resist_manipulation", false):
					rolled += 1

			Enums.Advantage.CRAB_HANDS:
				# Unskilled Weapon Skill treated as Rank 1 — no die bonus, handled via unskilled_rank
				pass

			Enums.Advantage.CRAFTY:
				# Unskilled Low Skill treated as Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.DANGEROUS_BEAUTY:
				# +1k0 to Temptation rolls against this character by matching-gender attacker.
				# Applied to the ATTACKER, not here. See get_target_temptation_bonus().
				pass

			Enums.Advantage.DAREDEVIL:
				# +3k1 instead of normal +1k1 when spending Void on Athletics.
				# Net advantage: +2k0 on top of normal (the +1k1 normal is already in the pool).
				if context.get("is_athletics", false) and context.get("is_void_spend", false):
					rolled += 2

			Enums.Advantage.FRIEND_OF_THE_ELEMENTS:
				# Free Raise whenever making a Trait Roll with either Trait of chosen Ring
				if context.get("is_ring_roll", false):
					var ring: int = adv.metadata.get("ring", Enums.Ring.NONE)
					if ring != Enums.Ring.NONE and context.get("element", Enums.Ring.NONE) == ring:
						free_raises += 1

			Enums.Advantage.FORBIDDEN_KNOWLEDGE:
				# +1k1 Social with known Gozoku/Kolat members (s45 line 101).
				# Requires opponent_known_faction context key set to the matching faction string.
				if context.get("is_social", false):
					var fk_subj: String = adv.metadata.get("subject", "")
					var opp_faction: String = context.get("opponent_known_faction", "")
					if fk_subj != "" and opp_faction != "" and fk_subj == opp_faction \
							and (fk_subj == "Gozoku" or fk_subj == "Kolat"):
						kept += 1

			Enums.Advantage.FRIENDLY_KAMI:
				# +1k1 to Spell Casting for Sense/Commune/Summon of chosen element. Shugenja only.
				if context.get("is_spell_casting", false):
					var elem: int = adv.metadata.get("element", Enums.Ring.NONE)
					var stype: String = context.get("spell_type", "")
					if elem != Enums.Ring.NONE \
							and context.get("element", Enums.Ring.NONE) == elem \
							and stype in ["sense", "commune", "summon"]:
						kept += 1

			Enums.Advantage.HANDS_OF_STONE:
				# +0k1 to unarmed Damage Rolls
				if context.get("is_unarmed_damage", false):
					kept += 1

			Enums.Advantage.HEART_OF_VENGEANCE:
				# +1k1 Contested Rolls against chosen Clan/faction
				if context.get("is_contested", false):
					var target_clan: String = context.get("opponent_clan", "")
					var chosen_clan: String = adv.metadata.get("clan", "")
					if chosen_clan != "" and target_clan == chosen_clan:
						kept += 1

			Enums.Advantage.HEARTLESS:
				# +1k0 to rolls resisting Courtier/Sincerity/Temptation to persuade/seduce/change mind
				if context.get("is_vs_persuasion", false):
					rolled += 1

			Enums.Advantage.IMPERIAL_SCRIBE:
				# +1k0 Social vs shugenja and artisans; Free Raise on all Calligraphy
				if context.get("is_social", false) \
						and (context.get("opponent_is_shugenja", false) or context.get("opponent_is_artisan", false)):
					rolled += 1
				if context.get("is_calligraphy", false):
					free_raises += 1

			Enums.Advantage.IMPERIAL_SPOUSE:
				# +1k1 Social Skill Rolls with Imperial families
				if context.get("is_social", false) and context.get("opponent_is_imperial", false):
					kept += 1

			Enums.Advantage.INNER_GIFT:
				# Empathy sub-type: +1k1 Courtier rolls to sense feelings
				if adv.metadata.get("gift", "") == "Empathy":
					if skill_name == "Courtier" and context.get("is_sensing_feelings", false):
						kept += 1

			Enums.Advantage.IRREPROACHABLE:
				# +1k0 to rolls resisting Temptation
				if context.get("is_resist_temptation", false):
					rolled += 1

			Enums.Advantage.NAGA_ANCESTRY:
				# +1k0 Social Skill Rolls with Naga
				if context.get("is_social", false) and context.get("opponent_is_naga", false):
					rolled += 1

			Enums.Advantage.PARAGON:
				# Various bonuses by Bushido virtue. Only simulation-relevant tiers.
				var virtue: String = adv.metadata.get("virtue", "")
				match virtue:
					"Courage":
						# +1k1 to resist Intimidation or Fear
						if context.get("is_resist_intimidation", false) or context.get("is_resist_fear", false):
							kept += 1
					"Courtesy":
						# +2k0 on Etiquette to avoid embarrassment
						if skill_name == "Etiquette":
							rolled += 2
					"Honesty":
						# +1k1 on Sincerity (Honesty)
						if skill_name == "Sincerity" and context.get("is_honest", false):
							kept += 1
					"Honor":
						# Add twice Honor Rank to resist Temptation/Intimidation.
						# Honor Rank is already added by callers; this doubles it.
						# Implemented as a flat bonus per the character's honor_rank.
						if context.get("is_resist_temptation", false) or context.get("is_resist_intimidation", false):
							var hr: int = int(character.honor)
							rolled += hr  # effectively doubles the honor rank bonus
					"Sincerity":
						# +2k0 to all Contested Sincerity rolls
						if skill_name == "Sincerity" and context.get("is_contested", false):
							rolled += 2
					"Compassion":
						# +2k2 when spending Void to help someone of lower Status (s45 line 257)
						if context.get("is_void_spend", false) and context.get("is_acting_for_lower_status", false):
							rolled += 2
							kept += 2
					"Duty":
						# Void Point negates all TN/Wound penalties on one roll — handled by Void system
						pass

			Enums.Advantage.PRECISE_MEMORY:
				# +1k1 Intelligence Trait Rolls when remembering
				if context.get("is_memory", false):
					kept += 1

			Enums.Advantage.PRODIGY:
				# +1k0 to all School Skill Rolls
				if context.get("is_school_skill", false):
					rolled += 1

			Enums.Advantage.REINCARNATED:
				# +1k0 to three chosen non-School Skills
				var skills: Array = adv.metadata.get("skills", [])
				if skill_name in skills:
					rolled += 1

			Enums.Advantage.SAGE:
				# Unskilled Lore Skill = Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.SAGE_OF_SWORD_AND_FAN:
				# Use higher of Battle/Courtier rank on Contested rolls (up to Insight Rank/day).
				# Structural — executor must set context; we provide the query helper.
				pass

			Enums.Advantage.SENSATION:
				# Unskilled Perform = Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.SEVEN_FORTUNES_BLESSING:
				var fortune: String = adv.metadata.get("fortune", "")
				match fortune:
					"Benten":
						# +0k1 Social for persuasion (not coercion)
						if context.get("is_social", false) and not context.get("is_coercion", false):
							kept += 1
					"Bishamon":
						# +1k0 Strength Trait Rolls
						if context.get("is_ring_roll", false) and context.get("element", Enums.Ring.NONE) == Enums.Ring.WATER:
							rolled += 1  # Strength is Water trait
					"Daikoku":
						# +1k1 Commerce Skill Rolls
						if skill_name == "Commerce":
							kept += 1
					"Ebisu":
						# +1k1 Social with non-samurai Rokugani
						if context.get("is_social", false) and context.get("opponent_is_commoner", false):
							kept += 1
					"Fukurokujin":
						# +1k1 to chosen Lore Skill
						var lore_skill: String = adv.metadata.get("skill", "")
						if skill_name == lore_skill:
							kept += 1
					"Jurojin":
						# +2k0 to rolls resisting disease or poison (s45 line 321)
						if context.get("is_resist_disease_or_poison", false):
							rolled += 2
					"Hotei":
						# +2 Free Raises (+10) on all Contested Rolls (s45 line 321)
						if context.get("is_contested", false):
							free_raises += 2

			Enums.Advantage.SILENT:
				# +1k0 to all Stealth rolls
				if context.get("is_stealth", false) or skill_name == "Stealth":
					rolled += 1

			Enums.Advantage.SOUL_OF_ARTISTRY:
				# Unskilled Artisan/Craft = Rank 1 — handled via unskilled_rank
				pass

			Enums.Advantage.STOLEN_IDENTITY:
				# Two Free Raises on Acting rolls when using alternate identity
				if skill_name == "Acting" and context.get("using_alternate_identity", false):
					free_raises += 2

			Enums.Advantage.STUDENT_OF_SHOURIDO:
				# May add +5 instead of Honor Rank to resist Temptation/Intimidation/Fear.
				# Not a die bonus — changes how the bonus is computed. Handled in callers.
				pass

			Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS:
				var realm: String = adv.metadata.get("realm", "")
				match realm:
					"Chikushudo":
						if skill_name == "Animal Handling":
							kept += 1
					"Jigoku":
						# Add Taint Rank to attack and Physical Trait rolls.
						# Characters who have become Lost (taint >= 5.0) add twice Taint Rank (s45 line 373).
						if context.get("is_combat", false) or (context.get("is_ring_roll", false) and context.get("is_physical_trait", false)):
							var taint_rank: int = int(character.taint)
							rolled += (taint_rank * 2) if character.taint >= 5.0 else taint_rank
					"Meido":
						# +2k0 Contested Rolls vs social manipulation
						if context.get("is_contested", false) and context.get("is_resist_manipulation", false):
							rolled += 2
					"Sakkaku":
						# +1k1 Sincerity (Deceit)
						if skill_name == "Sincerity" and context.get("is_deceit", false):
							kept += 1
					"Tengoku":
						# +2k0 Earth Ring Rolls to resist Taint
						if context.get("element", Enums.Ring.NONE) == Enums.Ring.EARTH and context.get("is_resist_taint", false):
							rolled += 2
					"Yomi":
						# +1k0 to one chosen School Skill
						var yomi_skill: String = adv.metadata.get("skill", "")
						if skill_name == yomi_skill and context.get("is_school_skill", false):
							rolled += 1

			Enums.Advantage.VOICE:
				# +1k1 to any Perform Skill Roll using voice
				if context.get("is_voice_perform", false):
					kept += 1

			Enums.Advantage.WARY:
				# +1k1 to Investigation (Notice)/Perception rolls to detect ambush
				if context.get("is_ambush_detection", false):
					kept += 1

			Enums.Advantage.WATANU_TRAINED:
				# +1k1 to chosen Craft Skill for metallic goods
				var w_skill: String = adv.metadata.get("skill", "")
				if skill_name == w_skill:
					kept += 1

			Enums.Advantage.GREAT_POTENTIAL:
				# Raises limited by Skill Rank rather than Void Ring — not a die bonus.
				# Executor must enforce this when computing max raises.
				pass

	# Disadvantage penalties
	for dis: DisadvantageData in character.disadvantages:
		if _is_suppressed(character, dis.disadvantage_type):
			continue
		match dis.disadvantage_type:

			Enums.Disadvantage.ANTISOCIAL:
				# 2 pts (-1k0) or 4 pts (-1k1) to all Social Skill Rolls
				if context.get("is_social", false):
					if dis.rank >= 2:  # 4-pt version
						rolled -= 1
						kept -= 1
					else:  # 2-pt version
						rolled -= 1

			Enums.Disadvantage.BAD_EYESIGHT:
				# -1k1 to Perception-based rolls (ranged attack part blocked on s40)
				if context.get("is_perception_based", false):
					rolled -= 1
					kept -= 1

			Enums.Disadvantage.BLIND:
				# May not make Perception rolls based on sight (s45); -1k1 on is_perception_based
				if context.get("is_perception_based", false):
					rolled -= 1
					kept -= 1

			Enums.Disadvantage.BAD_FORTUNE:
				# Moto Curse sub-type: -1k0 to resist Taint
				if dis.metadata.get("type", "") == "Moto_Curse" \
						and context.get("is_resist_taint", false):
					rolled -= 1

			Enums.Disadvantage.CONSUMED:
				var precept: String = dis.metadata.get("precept", "")
				match precept:
					"Control":
						# -1k1 to Etiquette and Sincerity
						if skill_name in ["Etiquette", "Sincerity"]:
							rolled -= 1
							kept -= 1
					"Strength":
						# -1k0 to Etiquette (Called Shot/Feint/Disarm extra Raise blocked on s40)
						if skill_name == "Etiquette":
							rolled -= 1
					"Will":
						# -1k1 to Courtier and Temptation
						if skill_name in ["Courtier", "Temptation"]:
							rolled -= 1
							kept -= 1

			Enums.Disadvantage.CURSED_BY_THE_REALM:
				var c_realm: String = dis.metadata.get("realm", "")
				match c_realm:
					"Chikushudo":
						# -1k1 to Animal Handling
						if skill_name == "Animal Handling":
							rolled -= 1
							kept -= 1
					"Jigoku":
						# -1k1 to rolls resisting Taint
						if context.get("is_resist_taint", false):
							rolled -= 1
							kept -= 1
					"Maigo_no_Musha":
						# -1k1 to all rolls against any spirit
						if context.get("opponent_is_spirit", false):
							rolled -= 1
							kept -= 1
					"Meido":
						# -1k0 to Perception rolls when unoccupied
						if context.get("is_perception_based", false) \
								and context.get("is_unoccupied", false):
							rolled -= 1

			Enums.Disadvantage.SEVEN_FORTUNES_CURSE:
				var sc_fortune: String = dis.metadata.get("fortune", "")
				match sc_fortune:
					"Daikoku":
						# -1k1 to Commerce rolls
						if skill_name == "Commerce":
							rolled -= 1
							kept -= 1
					"Ebisu":
						# -1k1 to Social Skill Rolls with non-samurai Rokugani
						if context.get("is_social", false) \
								and context.get("opponent_is_commoner", false):
							rolled -= 1
							kept -= 1
					"Jurojin":
						# -2k0 to resist all poisons and diseases
						if context.get("is_resist_disease_or_poison", false):
							rolled -= 2

	return {"rolled": rolled, "kept": kept, "free_raises": free_raises}


# ---------------------------------------------------------------------------
# TN modifier from disadvantages/advantages that raise or lower the TN.
# Returns int: positive = harder (TN increases), negative = easier.
# ---------------------------------------------------------------------------

static func get_tn_modifier(
	character: L5RCharacterData,
	context: Dictionary,
) -> int:
	var mod: int = 0

	for dis: DisadvantageData in character.disadvantages:
		if _is_suppressed(character, dis.disadvantage_type):
			continue
		match dis.disadvantage_type:

			Enums.Disadvantage.ANACHRONISM:
				if context.get("is_artisan_skill", false) or context.get("is_craft_skill", false) \
						or context.get("is_social", false):
					mod += 5

			Enums.Disadvantage.DISBELIEVER:
				if context.get("opponent_is_shugenja", false) or context.get("opponent_is_monk", false):
					if context.get("is_social", false):
						mod += 5

			Enums.Disadvantage.DISTURBING_COUNTENANCE:
				if context.get("is_social", false):
					mod += 5

			Enums.Disadvantage.DOUBT:
				# Must declare one Raise that confers no benefit on the chosen School Skill.
				# Equivalent to +5 TN (one wasted Raise) on that skill.
				var doubt_skill: String = dis.metadata.get("skill", "")
				if doubt_skill != "" and skill_name_from_context(context) == doubt_skill:
					mod += 5

			Enums.Disadvantage.FAILURE_OF_BUSHIDO:
				var virtue: String = dis.metadata.get("virtue", "")
				match virtue:
					"Courtesy":
						# Must call one no-effect Raise on Social apology/avoid-offense rolls
						# Represented as +5 effective TN (equivalent to one wasted Raise)
						if context.get("is_social_apology", false) or context.get("is_avoid_offense", false):
							mod += 5
					"Sincerity":
						# Must call one no-effect Raise on Sincerity conviction rolls
						if skill_name_from_context(context) == "Sincerity" and context.get("is_conviction", false):
							mod += 5
					"Courage":
						# +5 TN vs higher Glory/Status or Shadowlands opponents
						if context.get("opponent_higher_glory", false) or context.get("opponent_is_shadowlands", false):
							mod += 5
					"Honor":
						# Cannot add Honor Rank to resist Intimidation/Temptation.
						# Handled at caller; not a TN change.
						pass

			Enums.Disadvantage.LAME:
				# +10 TN on Agility rolls involving lower limbs
				if context.get("is_leg_agility_roll", false):
					mod += 10

			Enums.Disadvantage.MISSING_LIMB:
				# +10 TN on tasks involving the missing limb
				if context.get("involves_missing_limb", false):
					mod += 10

			Enums.Disadvantage.PHOBIA:
				# +5 per rank of the Disadvantage when in a tagged situation
				var tags: Array = dis.metadata.get("situation_tags", [])
				var sit_tags: Array = context.get("situation_tags", [])
				for tag: String in tags:
					if tag in sit_tags:
						mod += 5 * dis.rank
						break

			Enums.Disadvantage.CONSUMED:
				var c_precept: String = dis.metadata.get("precept", "")
				if c_precept == "Perfection":
					# Must call one extra Raise for no effect on every roll — equivalent to +5 TN.
					mod += 5

			Enums.Disadvantage.LOST_LOVE:
				# +5 TN to all rolls while the emotion is triggered (s45); reset daily for NPCs.
				if dis.metadata.get("lost_love_tn_active", false):
					mod += 5

			Enums.Disadvantage.CURSED_BY_THE_REALM:
				var cr_realm: String = dis.metadata.get("realm", "")
				if cr_realm == "Tengoku":
					# +10 TN to all rolls while inside a temple devoted to the Celestial Heavens
					if context.get("is_in_celestial_temple", false):
						mod += 10

			Enums.Disadvantage.SEVEN_FORTUNES_CURSE:
				var sc_fortune: String = dis.metadata.get("fortune", "")
				match sc_fortune:
					"Benten":
						# +10 TN to all Etiquette rolls
						if skill_name_from_context(context) == "Etiquette":
							mod += 10
					"Fukurokujin":
						# +5 TN to Lore Skill Rolls
						var sn: String = skill_name_from_context(context)
						if sn.begins_with("Lore"):
							mod += 5

			Enums.Disadvantage.WANDERER:
				if context.get("is_navigation", false):
					mod += 15

			Enums.Disadvantage.MEMBER_OF_CHRYSANTHEMUM_COURT:
				# The +Status-loss mechanic is situational — handled by court system.
				pass

	for adv: AdvantageData in character.advantages:
		match adv.advantage_type:
			Enums.Advantage.BLAND:
				# May voluntarily increase TN to identify you by +10.
				# Applied on request in context["bland_active"] = true.
				if context.get("bland_active", false):
					mod += 10  # negative: harder to be identified (benefit to self)

	return mod


# Convenience helper used internally
static func skill_name_from_context(ctx: Dictionary) -> String:
	return ctx.get("skill_name", "")


# ---------------------------------------------------------------------------
# TN bonus on rolls made TO detect this character's intentions / identity.
# Returns int: how much the attacker's TN is increased.
# Used by callers who are rolling social-read skills against this character.
# ---------------------------------------------------------------------------

static func get_target_detection_tn_bonus(target: L5RCharacterData) -> int:
	var bonus: int = 0
	if has_advantage(target, Enums.Advantage.SHADOWED_HEART):
		bonus += 5
	return bonus


# ---------------------------------------------------------------------------
# Bonus to ATTACKER's Temptation roll because of this TARGET's advantages.
# Handles DANGEROUS_BEAUTY.
# ---------------------------------------------------------------------------

static func get_target_temptation_bonus(target: L5RCharacterData, attacker_gender_matches: bool) -> int:
	if not attacker_gender_matches:
		return 0
	if has_advantage(target, Enums.Advantage.DANGEROUS_BEAUTY):
		return 1  # +1k0 rolled
	# Touch of Air's Grace (s33) grants the Dangerous Beauty effect when the target lacks
	# Disturbing Countenance (per "if the target lacks it, grant the Advantage instead").
	if target.has_day_buff("touch_of_airs_grace") and not has_disadvantage(target, Enums.Disadvantage.DISTURBING_COUNTENANCE):
		return 1
	return 0


# ---------------------------------------------------------------------------
# Bonus/penalty to attacker's LECHERY / GREEDY / GULLIBLE / FRAIL_MIND rolls.
# Returns {rolled: int, kept: int} bonus for the ATTACKER when targeting this char.
# ---------------------------------------------------------------------------

static func get_attacker_bonus_from_target(
	target: L5RCharacterData,
	skill_name: String,
	context: Dictionary,
) -> Dictionary:
	var rolled: int = 0
	var kept: int = 0

	for dis: DisadvantageData in target.disadvantages:
		match dis.disadvantage_type:

			Enums.Disadvantage.GULLIBLE:
				# Sincerity (Deceit) opponents gain +1k1
				if skill_name == "Sincerity" and context.get("is_deceit", false):
					kept += 1

			Enums.Disadvantage.GREEDY:
				# Temptation (Bribery) opponents gain +1k1
				if skill_name == "Temptation" and context.get("is_bribery", false):
					kept += 1

			Enums.Disadvantage.LECHERY:
				# Temptation (Seduction) opponents +1k0 if gender matches
				if skill_name == "Temptation" and context.get("is_seduction", false) \
						and context.get("attacker_gender_matches", false):
					rolled += 1

			Enums.Disadvantage.FRAIL_MIND:
				# Opponents gain +2k0 in Willpower Contested Rolls
				if context.get("is_contested", false) and context.get("is_willpower_contest", false):
					rolled += 2

	return {"rolled": rolled, "kept": kept}


# ---------------------------------------------------------------------------
# Wound TN modifier (added on top of the normal wound penalty when wounded).
# Returns int: positive = less painful, negative = more painful.
# ---------------------------------------------------------------------------

static func get_wound_tn_modifier(character: L5RCharacterData) -> int:
	var mod: int = 0
	if has_advantage(character, Enums.Advantage.STRENGTH_OF_THE_EARTH):
		mod += 3
	if has_disadvantage(character, Enums.Disadvantage.LOW_PAIN_THRESHOLD):
		mod -= 5
	return mod


# ---------------------------------------------------------------------------
# Magic resistance: returns additional TN that must be overcome by spells
# targeting this character. Only elemental spells (not maho or gaijin).
# ---------------------------------------------------------------------------

static func get_magic_resistance_tn(character: L5RCharacterData) -> int:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.MAGIC_RESISTANCE)
	if adv != null:
		return adv.rank * 3
	return 0


# ---------------------------------------------------------------------------
# Unskilled rank bonus: returns 1 if character should be treated as Rank 1
# when rolling this skill unskilled, 0 otherwise.
# ---------------------------------------------------------------------------

static func get_unskilled_rank_bonus(character: L5RCharacterData, skill_name: String, context: Dictionary) -> int:
	for adv: AdvantageData in character.advantages:
		match adv.advantage_type:
			Enums.Advantage.CRAB_HANDS:
				if context.get("is_weapon_skill", false):
					return 1
			Enums.Advantage.CRAFTY:
				if context.get("is_low_skill", false):
					return 1
			Enums.Advantage.SAGE:
				if context.get("is_lore_skill", false) or skill_name.begins_with("Lore"):
					return 1
			Enums.Advantage.SENSATION:
				if context.get("is_perform_skill", false) or skill_name.begins_with("Perform"):
					return 1
			Enums.Advantage.SOUL_OF_ARTISTRY:
				if context.get("is_artisan_skill", false) or context.get("is_craft_skill", false) \
						or skill_name.begins_with("Artisan") or skill_name.begins_with("Craft"):
					return 1
	return 0


# ---------------------------------------------------------------------------
# Trait modifier: returns adjustment to a specific trait value.
# Positive = higher effective trait, negative = lower.
# ---------------------------------------------------------------------------

static func get_trait_modifier(character: L5RCharacterData, trait_type: Enums.Trait, context: Dictionary) -> int:
	var mod: int = 0

	for dis: DisadvantageData in character.disadvantages:
		if _is_suppressed(character, dis.disadvantage_type):
			continue
		match dis.disadvantage_type:

			Enums.Disadvantage.WEAKNESS:
				var weak_trait: int = dis.metadata.get("trait", Enums.Trait.NONE)
				if weak_trait == trait_type:
					mod -= 1

			Enums.Disadvantage.BAD_HEALTH:
				# Earth Ring Traits considered 1 lower for Wound Ranks and disease resistance.
				# Only applies to Stamina/Willpower in the wound/disease context.
				if (trait_type == Enums.Trait.STAMINA or trait_type == Enums.Trait.WILLPOWER) \
						and context.get("is_wound_check", false):
					mod -= 1

			Enums.Disadvantage.LAME:
				# Water Ring = 1 for Move Actions
				if (trait_type == Enums.Trait.STRENGTH or trait_type == Enums.Trait.PERCEPTION) \
						and context.get("is_move_action", false):
					# Clamp to 1 is applied by the caller; we return the required delta.
					mod -= maxf(0.0, character.get_trait_value(trait_type) - 1.0)
					mod = int(mod)

			Enums.Disadvantage.SMALL:
				# Water Ring considered 1 lower for Move Action distance
				if (trait_type == Enums.Trait.STRENGTH or trait_type == Enums.Trait.PERCEPTION) \
						and context.get("is_move_action", false):
					mod -= 1

			Enums.Disadvantage.BLIND:
				# Water Ring 2 lower for Move Actions
				if (trait_type == Enums.Trait.STRENGTH or trait_type == Enums.Trait.PERCEPTION) \
						and context.get("is_move_action", false):
					mod -= 2

	return mod


# ---------------------------------------------------------------------------
# SMALL disadvantage: melee damage penalty (-1k0)
# ---------------------------------------------------------------------------

static func get_melee_damage_penalty(character: L5RCharacterData) -> int:
	if has_disadvantage(character, Enums.Disadvantage.SMALL):
		return -1  # -1k0 rolled dice on damage
	return 0


# ---------------------------------------------------------------------------
# QUICK_HEALER: Stamina considered 2 ranks higher for wound recovery.
# Returns the bonus Stamina ranks for healing purposes.
# ---------------------------------------------------------------------------

static func get_healing_stamina_bonus(character: L5RCharacterData) -> int:
	if has_advantage(character, Enums.Advantage.QUICK_HEALER):
		return 2
	return 0


# ---------------------------------------------------------------------------
# PERMANENT_WOUND: first wound rank always full.
# Returns true if the first wound box is always considered occupied.
# ---------------------------------------------------------------------------

static func has_permanent_wound(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.PERMANENT_WOUND)


# ---------------------------------------------------------------------------
# IDEALISTIC: Honor losses increased by 1 point.
# ---------------------------------------------------------------------------

static func get_honor_loss_increase(character: L5RCharacterData) -> float:
	if has_disadvantage(character, Enums.Disadvantage.IDEALISTIC):
		return 1.0
	return 0.0


# ---------------------------------------------------------------------------
# Void spend blocking: returns true if the Void spend should be blocked.
# Handles MOMOKU, CONSUMED Determination, FAILURE_OF_BUSHIDO Honesty/Duty.
# ---------------------------------------------------------------------------

static func is_void_spend_blocked(character: L5RCharacterData, context: Dictionary) -> bool:
	# MOMOKU: cannot spend Void on anything except Techniques
	if has_disadvantage(character, Enums.Disadvantage.MOMOKU):
		if not context.get("is_technique_void_spend", false):
			return true

	# CONSUMED Determination: cannot spend Void Points to enhance die rolls
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.CONSUMED:
			if dis.metadata.get("precept", "") == "Determination":
				if context.get("is_void_enhance", false):
					return true

	# FAILURE_OF_BUSHIDO Honesty: cannot spend Void on Sincerity (Honesty) rolls
	# FAILURE_OF_BUSHIDO Duty: cannot spend Void to negate Wounds
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.FAILURE_OF_BUSHIDO:
			var virtue: String = dis.metadata.get("virtue", "")
			match virtue:
				"Honesty":
					if context.get("is_honest_sincerity", false):
						return true
				"Duty":
					if context.get("is_negate_wounds", false):
						return true

	# SWORN_ENEMY: cannot spend Void Points when directly opposing the nemesis (s45 lines 699-701)
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.SWORN_ENEMY:
			var nemesis_id: int = dis.metadata.get("nemesis_id", -1)
			if nemesis_id >= 0 and context.get("opponent_id", -1) == nemesis_id:
				return true

	return false


# ---------------------------------------------------------------------------
# INSENSITIVE / FAILURE_OF_BUSHIDO Compassion: Void Point must be spent before acting.
# Returns true when a Void Point is required to perform the action at all.
# Different from is_void_spend_blocked() — here VP spending is mandatory, not forbidden.
# ---------------------------------------------------------------------------

static func requires_void_to_act(character: L5RCharacterData, context: Dictionary) -> bool:
	# INSENSITIVE: must spend Void to place self at personal risk for any other person's welfare
	if has_disadvantage(character, Enums.Disadvantage.INSENSITIVE):
		if context.get("is_acting_at_personal_risk_for_other", false):
			return true

	# FAILURE_OF_BUSHIDO Compassion: must spend Void before acting on behalf of lower Status
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.FAILURE_OF_BUSHIDO:
			if dis.metadata.get("virtue", "") == "Compassion":
				if context.get("is_acting_for_lower_status", false):
					return true

	return false


# ---------------------------------------------------------------------------
# SEVEN_FORTUNES_CURSE Hotei: any Void spend costs one extra Void Point.
# Returns the number of additional Void Points that must be spent.
# ---------------------------------------------------------------------------

static func get_extra_void_cost(character: L5RCharacterData) -> int:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.SEVEN_FORTUNES_CURSE)
	if dis != null and dis.metadata.get("fortune", "") == "Hotei":
		return 1
	return 0


# ---------------------------------------------------------------------------
# SEVEN_FORTUNES_BLESSING Hotei: any effect that would drain Void Points first
# requires a Contested Void Roll against TN 10 (s45 line 321).
# Returns true if this protection is active.
# ---------------------------------------------------------------------------

static func check_hotei_void_protection(character: L5RCharacterData) -> bool:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.SEVEN_FORTUNES_BLESSING:
			if adv.metadata.get("fortune", "") == "Hotei":
				return true
	return false


# ---------------------------------------------------------------------------
# ASCETIC: Glory gained is halved (normal) or quartered (monk school).
# Returns the multiplier to apply to any Glory award.
# ---------------------------------------------------------------------------

static func get_glory_multiplier(character: L5RCharacterData) -> float:
	if not has_disadvantage(character, Enums.Disadvantage.ASCETIC):
		return 1.0
	if character.school_type == Enums.SchoolType.MONK:
		return 0.25
	return 0.5


# ---------------------------------------------------------------------------
# BOUNTY: returns the TN for Perception + Investigation to identify this character.
# 2 pt (rank 1) → TN 25; 4 pt (rank 2) → TN 15; 6 pt (rank 3) → TN 10.
# Returns -1 if the character has no bounty.
# ---------------------------------------------------------------------------

static func get_recognition_tn(character: L5RCharacterData) -> int:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.BOUNTY)
	if dis == null:
		return -1
	match dis.rank:
		1:
			return 25
		2:
			return 15
		3:
			return 10
		_:
			return 25


# ---------------------------------------------------------------------------
# TACTICIAN: may increase or decrease the Mass Battle Table result by 5.
# Returns 5 as the adjustment magnitude; caller decides direction (+/-).
# ---------------------------------------------------------------------------

static func get_tactician_modifier(character: L5RCharacterData) -> int:
	if has_advantage(character, Enums.Advantage.TACTICIAN):
		return 5
	return 0


# ---------------------------------------------------------------------------
# STRATEGIST: +2k0 to the winning-roll, +1k0 to other Battle Skill rolls.
# Two query functions — callers use the appropriate one for each context.
# ---------------------------------------------------------------------------

## Returns the +2k0 rolled-die bonus to the Battle/Perception who-is-winning roll (s45).
static func get_strategist_winning_modifier(character: L5RCharacterData) -> int:
	if has_advantage(character, Enums.Advantage.STRATEGIST):
		return 2  # +2k0 rolled dice (s45)
	return 0


## Returns the +1k0 rolled-die bonus to all other Battle Skill rolls (s45).
static func get_strategist_battle_modifier(character: L5RCharacterData) -> int:
	if has_advantage(character, Enums.Advantage.STRATEGIST):
		return 1  # +1k0 rolled dice (s45)
	return 0


# ---------------------------------------------------------------------------
# STUDENT_OF_SHOURIDO: may add +5 instead of Honor Rank to resist Temptation,
# Intimidation, or Fear. NPC always picks whichever value is higher (s45).
# ---------------------------------------------------------------------------

## Returns the resistance bonus the character adds on Temptation/Intimidation/Fear.
static func get_shourido_honor_bonus(character: L5RCharacterData, honor_rank: int) -> int:
	if has_advantage(character, Enums.Advantage.STUDENT_OF_SHOURIDO):
		return maxi(5, honor_rank)  # choose better of flat +5 or actual Honor Rank (s45)
	return honor_rank


# ---------------------------------------------------------------------------
# BLOOD_OF_OSANO_WO: immune to penalties or damage from natural weather (s45).
# ---------------------------------------------------------------------------

## Returns true if character is immune to natural weather penalties.
static func has_weather_immunity(character: L5RCharacterData) -> bool:
	return has_advantage(character, Enums.Advantage.BLOOD_OF_OSANO_WO)


# ---------------------------------------------------------------------------
# PERCEIVED_HONOR: others see Honor as (actual + rank) when attempting to discern it.
# Lore: Bushido rolls against TN 15 reveal the true rank — caller's responsibility.
# ---------------------------------------------------------------------------

static func get_perceived_honor(character: L5RCharacterData, ic_day: int = -1) -> float:
	# Wolf's Proposal (s33): +3 perceived Honor Rank while active (stacks with the advantage).
	var spell_bonus: float = 3.0 if character.has_day_buff("wolfs_proposal") else 0.0
	# Air ML3-4 overflow: Perceived Honor advantage fails for 7 IC days (s45 line 537).
	if ic_day >= 0 and character.perceived_honor_blocked_until >= 0 \
			and ic_day < character.perceived_honor_blocked_until:
		return character.honor + spell_bonus
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.PERCEIVED_HONOR)
	if adv == null:
		return character.honor + spell_bonus
	return character.honor + float(adv.rank) + spell_bonus


# ---------------------------------------------------------------------------
# Elemental Imbalance overflow skill penalty (s45 lines 537-545).
# Returns {rolled: int, kept: int} penalty from active timed overflow states.
# Consumes the water one-shot flag on first social roll.
# ---------------------------------------------------------------------------

static func get_imbalance_skill_penalty(
	character: L5RCharacterData,
	is_social: bool,
	ic_day: int = -1,
) -> Dictionary:
	var rolled: int = 0
	var kept: int = 0
	# Void ML3-4: -1k0 to all rolls for 4 IC days (24 hours, s45 line 545).
	if ic_day >= 0 and character.void_imbalance_penalty_until >= 0 \
			and ic_day < character.void_imbalance_penalty_until:
		rolled -= 1
	if is_social:
		# Water ML1-2: -1k0 to next Social Skill Roll (one-shot, s45 line 543).
		if character.water_imbalance_social_penalty:
			rolled -= 1
			character.water_imbalance_social_penalty = false
		# Air ML3-4: -1k1 to all Social Skill Rolls for 7 IC days (s45 line 537).
		if ic_day >= 0 and character.air_imbalance_social_penalty_until >= 0 \
				and ic_day < character.air_imbalance_social_penalty_until:
			rolled -= 1
			kept -= 1
	return {"rolled": rolled, "kept": kept}


# ---------------------------------------------------------------------------
# WAY_OF_THE_LAND: cannot get lost in known territory; knows resource locations.
# Returns true when navigation failure would be blocked.
# ---------------------------------------------------------------------------

static func is_navigation_immune(character: L5RCharacterData, context: Dictionary) -> bool:
	if not has_advantage(character, Enums.Advantage.WAY_OF_THE_LAND):
		return false
	return context.get("is_known_territory", false)


# ---------------------------------------------------------------------------
# GAIJIN_NAME: dice may only explode once on Social Skill Rolls (max result 20/die).
# Returns 1 (one explosion cap) when active, 0 for normal unlimited explosions.
# ---------------------------------------------------------------------------

static func get_die_explosion_cap(character: L5RCharacterData, context: Dictionary) -> int:
	if not has_disadvantage(character, Enums.Disadvantage.GAIJIN_NAME):
		return 0
	if context.get("is_social", false):
		return 1
	return 0


# ---------------------------------------------------------------------------
# TOUCH_OF_THE_VOID: +2k1 instead of +1k1 when spending Void on a roll.
# Returns the extra kept dice (on top of the normal +1k1 = 1 kept).
# The roll also requires Willpower TN 30 or Dazed — checked separately.
# NOTE: dead/forward-wired (no callers). TOUCH_OF_THE_VOID is a Disadvantage per
# GDD s45/s29.12; the +2k1 Void doubling is actually the Phoenix Rank-5 *technique*
# of the same name (s29.5). These functions conflate the two — left referencing the
# real Disadvantage enum so the module compiles, pending owner clarification.
# ---------------------------------------------------------------------------

static func get_void_spend_bonus(character: L5RCharacterData) -> Dictionary:
	if has_disadvantage(character, Enums.Disadvantage.TOUCH_OF_THE_VOID):
		return {"extra_kept": 1}  # +2k1 total vs normal +1k1
	return {"extra_kept": 0}


static func needs_void_dazed_check(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.TOUCH_OF_THE_VOID)


# ---------------------------------------------------------------------------
# SACROSANCT: characters with Honor 5+ may not attack this character unless
# attacked first.  Returns true if NPC should skip violence against this char.
# ---------------------------------------------------------------------------

static func is_sacrosanct(character: L5RCharacterData) -> bool:
	if not has_advantage(character, Enums.Advantage.SACROSANCT):
		return false
	return character.honor >= 6.0


# ---------------------------------------------------------------------------
# GREAT_DESTINY: death-protection query.
# Returns true if the death-protection can fire in the given IC year.
# Call with the character's last_triggered_ic_year stored in metadata.
# ---------------------------------------------------------------------------

static func check_great_destiny(character: L5RCharacterData, current_ic_year: int) -> bool:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.GREAT_DESTINY)
	if adv == null:
		return false
	var last_year: int = adv.metadata.get("last_triggered_ic_year", -1)
	return last_year != current_ic_year


# ---------------------------------------------------------------------------
# DARLING_OF_THE_COURT: +1 effective Status at a specific court.
# Returns 1 if the character has this advantage for the given settlement, 0 otherwise.
# May be purchased multiple times for different courts.
# ---------------------------------------------------------------------------

static func get_darling_status_bonus(character: L5RCharacterData, court_settlement_id: int) -> int:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.DARLING_OF_THE_COURT:
			if adv.metadata.get("settlement_id", -1) == court_settlement_id:
				return 1
	return 0


# ---------------------------------------------------------------------------
# VOID_VERSATILITY: returns true if spell slots from ring may be used to cast
# Void spells. ring must be the non-Void ring whose slots would be spent.
# Only valid if character has Void Affinity (Ishiken-Do advantage).
# ---------------------------------------------------------------------------

static func can_use_void_versatility(character: L5RCharacterData, ring: int) -> bool:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.VOID_VERSATILITY)
	if adv == null:
		return false
	return adv.metadata.get("ring", Enums.Ring.NONE) == ring


# ---------------------------------------------------------------------------
# HERO_OF_THE_PEOPLE: lowers the TN for non-samurai to recognize character.
# Returns -10 when is_non_samurai_recognizer is true and advantage is present.
# Negative return = TN is lowered (easier to recognize).
# ---------------------------------------------------------------------------

static func get_hero_recognition_tn_modifier(character: L5RCharacterData, is_non_samurai_recognizer: bool) -> int:
	if not is_non_samurai_recognizer:
		return 0
	if has_advantage(character, Enums.Advantage.HERO_OF_THE_PEOPLE):
		return -10
	return 0


# ---------------------------------------------------------------------------
# INHERITANCE: +1k1 to non-combat Skill Rolls when using the heirloom item.
# Returns {rolled: int, kept: int} bonus.
# ---------------------------------------------------------------------------

static func get_inheritance_skill_bonus(character: L5RCharacterData, using_heirloom: bool) -> Dictionary:
	if using_heirloom and has_advantage(character, Enums.Advantage.INHERITANCE):
		return {"rolled": 0, "kept": 1}
	return {"rolled": 0, "kept": 0}


# ---------------------------------------------------------------------------
# get_void_recovery_hours: returns hours of rest needed to regain all Void.
# TOUCH_OF_THE_SPIRIT_REALMS Yume-do: 4 hours.
# CURSED_BY_THE_REALM Yume-do: 10 hours.
# Default: 8 hours.
# ---------------------------------------------------------------------------

static func get_void_recovery_hours(character: L5RCharacterData) -> int:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS:
			if adv.metadata.get("realm", "") == "Yume-do":
				return 4
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.CURSED_BY_THE_REALM:
			if dis.metadata.get("realm", "") == "Yume-do":
				return 10
	return 8


# ---------------------------------------------------------------------------
# Behavioral triggers
# ---------------------------------------------------------------------------

## COMPULSION: returns {triggered: bool, tn: int}.
## Caller rolls Willpower vs TN; on failure action is consumed.
static func check_compulsion_trigger(character: L5RCharacterData, location_tags: Array) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.COMPULSION)
	if dis == null:
		return {"triggered": false, "tn": 0}
	var subject_tags: Array = dis.metadata.get("location_tags", [])
	for tag: String in subject_tags:
		if tag in location_tags:
			var tn: int = 15 + (dis.rank - 1) * 5
			return {"triggered": true, "tn": tn}
	return {"triggered": false, "tn": 0}


## CONTRARY: returns {triggered: bool, tn: int}.
## Caller rolls Willpower vs TN; on failure NPC declares position publicly.
static func check_contrary_trigger(character: L5RCharacterData, max_glory_rank: float) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.CONTRARY):
		return {"triggered": false, "tn": 0}
	var tn: int = int(5.0 * max_glory_rank)
	return {"triggered": true, "tn": tn}


## CONSUMED: returns {triggered: bool, tn: int, precept: String}.
## Insight (4 pts): Willpower TN 20 when using the chosen School Skill or falls into reverie.
## Knowledge (4 pts): Willpower TN 25 when encountering a new topic or must study it.
## Caller passes precept_type to check only one sub-type.
static func check_consumed_trigger(
	character: L5RCharacterData,
	precept_type: String,
	context: Dictionary,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.CONSUMED)
	if dis == null:
		return {"triggered": false, "tn": 0, "precept": ""}
	var precept: String = dis.metadata.get("precept", "")
	if precept != precept_type:
		return {"triggered": false, "tn": 0, "precept": precept}
	match precept:
		"Insight":
			if context.get("is_school_skill", false):
				return {"triggered": true, "tn": 20, "precept": precept}
		"Knowledge":
			if context.get("is_new_topic", false):
				return {"triggered": true, "tn": 25, "precept": precept}
	return {"triggered": false, "tn": 0, "precept": precept}


## CURSED_BY_THE_REALM Toshigoku: must roll Willpower TN 15 or attack any wounded opponent.
## Returns {triggered: bool, tn: int}.
static func check_cursed_toshigoku_trigger(
	character: L5RCharacterData,
	opponent_is_wounded: bool,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.CURSED_BY_THE_REALM)
	if dis == null or dis.metadata.get("realm", "") != "Toshigoku":
		return {"triggered": false, "tn": 0}
	if opponent_is_wounded:
		return {"triggered": true, "tn": 15}
	return {"triggered": false, "tn": 0}


## LOST_LOVE: returns {triggered: bool, tiers_used: int}.
## Returns triggered=true if the interaction context matches the lost love's
## clan/family or the death-province. On trigger, all TNs +5 until Void spent.
## Cannot trigger more than twice per IC day; at least 1 hour between instances.
static func check_lost_love_trigger(
	character: L5RCharacterData,
	context: Dictionary,
	ic_day: int,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.LOST_LOVE)
	if dis == null:
		return {"triggered": false}

	var triggers_today: int = dis.metadata.get("triggers_today", 0)
	var last_trigger_day: int = dis.metadata.get("last_trigger_ic_day", -1)
	if last_trigger_day != ic_day:
		triggers_today = 0

	if triggers_today >= 2:
		return {"triggered": false}

	var love_clan: String = dis.metadata.get("clan", "")
	var love_family: String = dis.metadata.get("family", "")
	var death_province: int = dis.metadata.get("province_id", -1)

	var ctx_clan: String = context.get("lost_love_clan", "")
	var ctx_family: String = context.get("lost_love_family", "")
	var ctx_province: int = context.get("lost_love_province_id", -1)

	var triggered: bool = false
	if love_clan != "" and ctx_clan == love_clan:
		triggered = true
	if love_family != "" and ctx_family == love_family:
		triggered = true
	if death_province >= 0 and ctx_province == death_province:
		triggered = true

	return {"triggered": triggered, "tn_penalty": 5 if triggered else 0}


## PHOBIA: returns {active: bool, tn_penalty: int}.
static func check_phobia_trigger(character: L5RCharacterData, situation_tags: Array) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.PHOBIA)
	if dis == null:
		return {"active": false, "tn_penalty": 0}
	var phobia_tags: Array = dis.metadata.get("situation_tags", [])
	for tag: String in phobia_tags:
		if tag in situation_tags:
			return {"active": true, "tn_penalty": 5 * dis.rank}
	return {"active": false, "tn_penalty": 0}


## RUMORMONGER: returns {triggered: bool, tn: int}.
## Caller rolls Willpower vs TN; on failure NPC spreads the rumor.
static func check_rumormonger_trigger(character: L5RCharacterData, max_glory_rank: float) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.RUMORMONGER):
		return {"triggered": false, "tn": 0}
	var tn: int = int(5.0 * max_glory_rank)
	return {"triggered": true, "tn": tn}


## TRUE_LOVE: returns {void_cost_required: bool}.
## If the pending action would negatively affect the lover, Void must be spent.
## If no Void Points remain, action cannot be taken this tick.
static func check_true_love_constraint(
	character: L5RCharacterData,
	action_harms_lover: bool,
) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.TRUE_LOVE):
		return {"void_cost_required": false}
	if action_harms_lover:
		return {"void_cost_required": true}
	return {"void_cost_required": false}


## DARK_PARAGON: would activating it (retroactively) change the outcome?
## Returns {should_activate: bool}.
## The engine calls this after computing roll result; NPC spends if beneficial.
static func check_dark_paragon_activation(
	character: L5RCharacterData,
	roll_total: int,
	tn: int,
	precept: String,
	ic_day: int = -1,
) -> Dictionary:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.DARK_PARAGON)
	if adv == null:
		return {"should_activate": false}
	var char_precept: String = adv.metadata.get("precept", "")
	if char_precept != precept:
		return {"should_activate": false}
	# Once-per-OOC-week limit (s45:77)
	if ic_day >= 0:
		var current_week: int = ic_day / 7
		if adv.metadata.get("last_activation_week", -1) == current_week:
			return {"should_activate": false}
	# Activate if +5 bonus would turn a miss into a hit
	var would_succeed: bool = (roll_total + 5) >= tn and roll_total < tn
	# Or if Will/Determination would prevent death
	var is_survival_precept: bool = (precept == "Will" or precept == "Determination")
	return {"should_activate": would_succeed or is_survival_precept}


## DARK_PARAGON: deduct cost (1 Void Point if available, else 0.5 Honor) and record weekly limit.
## GDD s45:77 "sacrifice 5 Honor" = 5 points = 0.5 rank on the 0.0–10.0 scale.
## Call immediately after activation is confirmed.
static func apply_dark_paragon_cost(character: L5RCharacterData, ic_day: int) -> void:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.DARK_PARAGON)
	if adv == null:
		return
	if character.current_void_points > 0:
		character.current_void_points -= 1
	else:
		HonorGlorySystem.apply_honor_change(character, -0.5)
	if ic_day >= 0:
		adv.metadata["last_activation_week"] = ic_day / 7


## BRASH: returns {triggered: bool, tn: int}.
## Caller rolls Willpower + Honor Rank vs TN; on failure NPC attacks immediately.
static func check_brash_trigger(character: L5RCharacterData, was_threatened_or_insulted: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.BRASH):
		return {"triggered": false, "tn": 0}
	if was_threatened_or_insulted:
		return {"triggered": true, "tn": 25}
	return {"triggered": false, "tn": 0}


## CANT_LIE: returns {triggered: bool, tn: int}.
## If someone tells a lie the character knows is false, Willpower TN 20 to stay quiet.
static func check_cant_lie_trigger(character: L5RCharacterData, lie_detected: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.CANT_LIE):
		return {"triggered": false, "tn": 0}
	if lie_detected:
		return {"triggered": true, "tn": 20}
	return {"triggered": false, "tn": 0}


## SOFT_HEARTED: returns {triggered: bool, tn: int}.
## Must roll Willpower TN 20 before killing a human; if failing while killing, +10 TN all day.
static func check_soft_hearted_trigger(character: L5RCharacterData, would_kill_human: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.SOFT_HEARTED):
		return {"triggered": false, "tn": 0}
	if would_kill_human:
		return {"triggered": true, "tn": 20}
	return {"triggered": false, "tn": 0}


## EPILEPSY: returns {triggered: bool, tn: int}.
## High stress or flashing lights trigger a Willpower TN 15 roll.
static func check_epilepsy_trigger(character: L5RCharacterData, high_stress: bool) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.EPILEPSY):
		return {"triggered": false, "tn": 0}
	if high_stress:
		return {"triggered": true, "tn": 15}
	return {"triggered": false, "tn": 0}


## ELEMENTAL_IMBALANCE: returns {triggered: bool, tn: int, element: int}.
## Fires when casting a spell of the character's imbalanced element.
static func check_elemental_imbalance_trigger(
	character: L5RCharacterData,
	cast_element: int,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.ELEMENTAL_IMBALANCE)
	if dis == null:
		return {"triggered": false, "tn": 0}
	var imb_elem: int = dis.metadata.get("element", Enums.Ring.NONE)
	if imb_elem != Enums.Ring.NONE and cast_element == imb_elem:
		var tn: int = 15 + (dis.rank - 1) * 5
		return {"triggered": true, "tn": tn, "element": cast_element}
	return {"triggered": false, "tn": 0}


## OVERCONFIDENT: returns {triggered: bool, tn: int}.
## Must succeed at Perception TN 20 to recognize an unwinnable situation and withdraw.
static func check_overconfident_trigger(
	character: L5RCharacterData,
	is_outnumbered: bool,
) -> Dictionary:
	if not has_disadvantage(character, Enums.Disadvantage.OVERCONFIDENT):
		return {"triggered": false, "tn": 0}
	if is_outnumbered:
		return {"triggered": true, "tn": 20}
	return {"triggered": false, "tn": 0}


# ---------------------------------------------------------------------------
# CURSED_BY_THE_REALM Sakkaku: once per IC month a Spirit Prank fires automatically.
# ic_month is an integer counter unique per month in the world (e.g. ic_year * 4 + season).
# Returns {triggered: bool, prank: String, metadata: Dictionary}.
# Caller must update dis.metadata["last_prank_month"] to ic_month after processing.
# ---------------------------------------------------------------------------

static func check_sakkaku_monthly_prank(character: L5RCharacterData, ic_month: int) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.CURSED_BY_THE_REALM)
	if dis == null or dis.metadata.get("realm", "") != "Sakkaku":
		return {"triggered": false, "prank": "", "metadata": {}}

	var last_month: int = dis.metadata.get("last_prank_month", -1)
	if last_month == ic_month:
		return {"triggered": false, "prank": "", "metadata": {}}  # already fired this month

	# Deterministic prank selection: one per character per month (GDD s45 lines 491-510)
	var idx: int = (character.character_id * 7 + ic_month * 13) % 20
	var prank_table: Array[Dictionary] = [
		{"prank": "MISPLACED_ITEM",           "duration_days": 1},
		{"prank": "LOOSE_TONGUE",             "penalty": -1, "skill": "social", "duration_days": 7},
		{"prank": "VOID_DRAIN",               "vp_loss": 1},
		{"prank": "NOISY_SHADOW",             "penalty": -1, "skill": "Stealth", "duration_days": 7},
		{"prank": "SPOILED_PROVISIONS",       "koku_loss": 1},
		{"prank": "FOOL_IMPRESSION",          "disposition_loss": -5},
		{"prank": "STUMBLE",                  "penalty": -1, "next_roll_only": true},
		{"prank": "SMEARED_INK",              "letter_delay_days": 3},
		{"prank": "RESTLESS_NIGHT",           "blocks_vp_recovery": true},
		{"prank": "PHANTOM_SOUNDS",           "penalty": -1, "skill": "Investigation", "duration_days": 7},
		{"prank": "LOOSE_STRAPS",             "armor_tn_penalty": -5},
		{"prank": "WHISPERED_EMBARRASSMENT",  "glory_loss": 1.0},
		{"prank": "UNSETTLING_PRESENCE",      "penalty": -1, "skill": "Willpower", "duration_days": 7},
		{"prank": "STUCK_BLADE",              "penalty": -1, "next_attack_only": true},
		{"prank": "WRONG_PATH",               "travel_extra_days": 1},
		{"prank": "SPILLED_TEA",              "breach_type": "ETIQUETTE_MINOR"},
		{"prank": "SPOOKED_MOUNT",            "penalty": -2, "skill": "Horsemanship"},
		{"prank": "SNAPPED_STRING",           "penalty": -1, "skill": "Perform or Kyujutsu"},
		{"prank": "DISRUPTED_KAMI",           "penalty": -1, "skill": "spell_casting"},
		{"prank": "TAINTED_GIFT",             "disposition_change": -3},
	]

	return {
		"triggered": true,
		"prank": prank_table[idx]["prank"],
		"metadata": prank_table[idx],
	}


# ---------------------------------------------------------------------------
# BAD_FORTUNE Lingering Misfortune: once per IC month, one roll that succeeds
# by fewer than 5 (margin 0–4) is automatically turned into a failure.
# roll_margin = roll_total - tn (positive = success, negative = already failed).
# ic_month is the current IC month counter.
# Caller must update dis.metadata["last_misfortune_month"] to ic_month after trigger.
# Returns {triggered: bool}.
# ---------------------------------------------------------------------------

static func check_lingering_misfortune(
	character: L5RCharacterData,
	roll_margin: int,
	ic_month: int,
) -> Dictionary:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.BAD_FORTUNE)
	if dis == null or dis.metadata.get("type", "") != "Lingering_Misfortune":
		return {"triggered": false}

	var last_month: int = dis.metadata.get("last_misfortune_month", -1)
	if last_month == ic_month:
		return {"triggered": false}  # already fired this month

	# Only narrow successes qualify (margin 0–4: succeeded but by less than 5)
	if roll_margin < 0 or roll_margin >= 5:
		return {"triggered": false}

	return {"triggered": true}


# ---------------------------------------------------------------------------
# WRATH_OF_THE_KAMI: returns the Free Raise bonus granted to a spellcaster
# targeting this character with the marked element.
# ---------------------------------------------------------------------------

static func get_wrath_of_kami_bonus(target: L5RCharacterData, spell_element: int) -> int:
	var dis: DisadvantageData = get_disadvantage(target, Enums.Disadvantage.WRATH_OF_THE_KAMI)
	if dis == null:
		return 0
	var marked_elem: int = dis.metadata.get("element", Enums.Ring.NONE)
	if marked_elem != Enums.Ring.NONE and spell_element == marked_elem:
		return 1  # +1 Free Raise on Spell Casting Roll
	return 0


# ---------------------------------------------------------------------------
# TOUCH_OF_THE_SPIRIT_REALMS Maigo no Musha: +1 bonus Glory when more than 3 Glory awarded.
# glory_awarded is the raw amount being granted. Returns 1 if bonus applies, 0 otherwise.
# ---------------------------------------------------------------------------

static func get_spirit_realm_glory_bonus(character: L5RCharacterData, glory_awarded: float) -> int:
	if glory_awarded <= 3.0:
		return 0
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.TOUCH_OF_THE_SPIRIT_REALMS:
			if adv.metadata.get("realm", "") == "Maigo_no_Musha":
				return 1
	return 0


# ---------------------------------------------------------------------------
# CAST_OUT: members of the character's cast-out sect treat their Glory as Infamy.
# Returns true when observer_sect matches the sect the character was cast out from.
# ---------------------------------------------------------------------------

static func is_glory_treated_as_infamy_by(character: L5RCharacterData, observer_sect: String) -> bool:
	var dis: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.CAST_OUT)
	if dis == null:
		return false
	return dis.metadata.get("sect", "") == observer_sect and observer_sect != ""


# ---------------------------------------------------------------------------
# OBTUSE: XP cost to raise a High Skill (except Investigation or Medicine) is doubled.
# Returns 2 when the doubling applies, 1 otherwise.
# is_high_skill() enumerates the High Skills per L5R 4e (GDD s45 lines 651-653).
# ---------------------------------------------------------------------------

static func is_high_skill(skill_name: String) -> bool:
	if skill_name.begins_with("Lore"):
		return true
	if skill_name.begins_with("Games"):
		return true
	return skill_name in [
		"Calligraphy", "Courtier", "Etiquette", "Horsemanship",
		"Investigation", "Medicine", "Meditation", "Poetry",
		"Sincerity", "Tea Ceremony", "Temptation",
	]


static func get_high_skill_xp_multiplier(character: L5RCharacterData, skill_name: String) -> int:
	if not has_disadvantage(character, Enums.Disadvantage.OBTUSE):
		return 1
	if not is_high_skill(skill_name):
		return 1
	if skill_name in ["Investigation", "Medicine"]:
		return 1
	return 2


# ---------------------------------------------------------------------------
# SPY NETWORK helpers
# ---------------------------------------------------------------------------

## Returns the NPC's chosen focus dict or {} if no focus set.
static func get_spy_network_focus(character: L5RCharacterData) -> Dictionary:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.SPY_NETWORK)
	if adv == null:
		return {}
	return {
		"focus_type": adv.metadata.get("focus_type", ""),
		"focus_id": adv.metadata.get("focus_id", -1),
	}


## Sets the NPC's spy network focus. focus_type: "character", "place", "army".
static func set_spy_network_focus(
	character: L5RCharacterData,
	focus_type: String,
	focus_id: int,
	ooc_day: int,
) -> void:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.SPY_NETWORK)
	if adv == null:
		return
	adv.metadata["focus_type"] = focus_type
	adv.metadata["focus_id"] = focus_id
	adv.metadata["last_update_ooc_day"] = ooc_day


# ---------------------------------------------------------------------------
# WELL_CONNECTED helpers
# ---------------------------------------------------------------------------

## Returns list of settlement_ids where this character is well-connected.
static func get_well_connected_courts(character: L5RCharacterData) -> Array:
	var result: Array = []
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.WELL_CONNECTED:
			var sid: int = adv.metadata.get("settlement_id", -1)
			if sid >= 0:
				result.append(sid)
	return result


# ---------------------------------------------------------------------------
# World generation — derive advantages/disadvantages from existing world state.
# Only derives entries that can be determined from confirmed data.
# ---------------------------------------------------------------------------

static func assign_derived_advantages(
	character: L5RCharacterData,
	active_hostages: Array,
	chars_by_id: Dictionary,
) -> void:
	# ISHIKEN_DO — assigned to Isawa Ishiken school characters
	if character.school == "Isawa Ishiken":
		if not has_advantage(character, Enums.Advantage.ISHIKEN_DO):
			var adv: AdvantageData = AdvantageData.new()
			adv.advantage_type = Enums.Advantage.ISHIKEN_DO
			character.advantages.append(adv)

	# FAME (purchased advantage) — +1 Glory Rank at generation (s45 line 95-97).
	# Must run before the derive block below so the derive block sees the resulting glory.
	if has_advantage(character, Enums.Advantage.FAME):
		character.glory = minf(character.glory + 1.0, 10.0)

	# FAME — assigned if glory >= 2.0 at world start
	if character.glory >= 2.0 and not has_advantage(character, Enums.Advantage.FAME):
		var adv: AdvantageData = AdvantageData.new()
		adv.advantage_type = Enums.Advantage.FAME
		character.advantages.append(adv)

	# SHADOWLANDS_TAINT — assigned if character has taint > 0
	if character.taint > 0.0 and not has_disadvantage(character, Enums.Disadvantage.SHADOWLANDS_TAINT):
		var dis: DisadvantageData = DisadvantageData.new()
		dis.disadvantage_type = Enums.Disadvantage.SHADOWLANDS_TAINT
		character.disadvantages.append(dis)

	# HOSTAGE — assigned if character appears in active_hostages as hostage_id
	for h: Dictionary in active_hostages:
		if h.get("hostage_id", -1) == character.character_id:
			if not has_disadvantage(character, Enums.Disadvantage.HOSTAGE):
				var dis: DisadvantageData = DisadvantageData.new()
				dis.disadvantage_type = Enums.Disadvantage.HOSTAGE
				character.disadvantages.append(dis)
			break

	# DISHONORED — assigned if character has role_position = "" and honor < 1.0
	if character.honor < 1.0 and character.role_position == "" and character.lord_id >= 0:
		if not has_disadvantage(character, Enums.Disadvantage.DISHONORED):
			var dis: DisadvantageData = DisadvantageData.new()
			dis.disadvantage_type = Enums.Disadvantage.DISHONORED
			character.disadvantages.append(dis)

	# SOCIAL_DISADVANTAGE — assigned if status < 0.5 (start with Status 0 per GDD)
	if character.status < 0.5 and not has_disadvantage(character, Enums.Disadvantage.SOCIAL_DISADVANTAGE):
		var dis: DisadvantageData = DisadvantageData.new()
		dis.disadvantage_type = Enums.Disadvantage.SOCIAL_DISADVANTAGE
		character.disadvantages.append(dis)

	# VIRTUOUS — +1 Honor Rank at generation (s45)
	if has_advantage(character, Enums.Advantage.VIRTUOUS):
		character.honor = minf(character.honor + 1.0, 10.0)

	# SOCIAL_POSITION — +1 Status Rank at generation (s45)
	if has_advantage(character, Enums.Advantage.SOCIAL_POSITION):
		character.status = minf(character.status + 1.0, 10.0)

	# IMPERIAL_SPOUSE — +0.5 Status Rank at generation (s45 line 165).
	if has_advantage(character, Enums.Advantage.IMPERIAL_SPOUSE):
		character.status = minf(character.status + 0.5, 10.0)

	# WEALTHY — 2 koku per purchased point at generation (s45 line 403-405).
	# Multiple WEALTHY entries stack.
	var wealth_bonus: int = get_wealth_koku_bonus(character)
	if wealth_bonus > 0:
		character.koku += float(wealth_bonus)

	# FORBIDDEN_KNOWLEDGE — grant skill at rank 1 at generation (s45 line 99-101).
	# Skill capped at rank 1 — does not overwrite higher ranks from school progression.
	var fk_type: String = get_forbidden_knowledge_type(character)
	if fk_type != "":
		match fk_type:
			"Gaijin Pepper":
				if character.skills.get("Craft: Explosives", 0) < 1:
					character.skills["Craft: Explosives"] = 1
			"Gozoku":
				if character.skills.get("Lore: Gozoku", 0) < 1:
					character.skills["Lore: Gozoku"] = 1
			"Kolat":
				if character.skills.get("Lore: Kolat", 0) < 1:
					character.skills["Lore: Kolat"] = 1
			"Lying Darkness":
				if character.skills.get("Lore: Lying Darkness", 0) < 1:
					character.skills["Lore: Lying Darkness"] = 1
			"Maho":
				if character.skills.get("Lore: Maho", 0) < 1:
					character.skills["Lore: Maho"] = 1

	# INFAMOUS — starting Glory Rank replaced with Infamy Rank at generation (s45)
	if has_disadvantage(character, Enums.Disadvantage.INFAMOUS):
		character.infamy = maxf(character.infamy, character.glory)
		character.glory = 0.0

	# UNCENTERED — blocks ISHIKEN_DO and VOID_VERSATILITY (s45)
	if has_disadvantage(character, Enums.Disadvantage.UNCENTERED):
		for i: int in range(character.advantages.size() - 1, -1, -1):
			var blocked_adv: AdvantageData = character.advantages[i]
			if blocked_adv.advantage_type in [
				Enums.Advantage.ISHIKEN_DO,
				Enums.Advantage.VOID_VERSATILITY,
			]:
				character.advantages.remove_at(i)

	# BLACK_SHEEP — apply permanent -40 family / -20 clan disposition modifiers
	# to all named characters' dispositions toward this character.
	if has_disadvantage(character, Enums.Disadvantage.BLACK_SHEEP):
		var char_family: String = character.family
		var char_clan: String = character.clan
		for other_id: int in chars_by_id:
			var other: L5RCharacterData = chars_by_id[other_id]
			if other == null or CharacterStats.is_dead(other):
				continue
			if other.character_id == character.character_id:
				continue
			if other.family == char_family and char_family != "":
				var current_fam: int = other.disposition_values.get(character.character_id, 0)
				other.disposition_values[character.character_id] = clampi(current_fam - 40, -100, 100)
			elif other.clan == char_clan and char_clan != "":
				var current_clan: int = other.disposition_values.get(character.character_id, 0)
				other.disposition_values[character.character_id] = clampi(current_clan - 20, -100, 100)


# =============================================================================
# s45 ADDITIONAL QUERY FUNCTIONS
# =============================================================================

# ABSOLUTE_DIRECTION: always know which direction is north (s45 line 7-9).
# Does not function if more than one day inside the Shadowlands — callers must
# check province taint context if applicable.
static func has_absolute_direction(character: L5RCharacterData) -> bool:
	return has_advantage(character, Enums.Advantage.ABSOLUTE_DIRECTION)


# READ_LIPS: understand speech by observing lip movement (s45 line 279-281).
static func can_read_lips(character: L5RCharacterData) -> bool:
	return has_advantage(character, Enums.Advantage.READ_LIPS)


# READ_LIPS TN formula: Perception Trait Roll (s45: TN 15 + 5 per 20 feet).
static func get_read_lips_tn(distance_feet: int) -> int:
	return 15 + (distance_feet / 20) * 5


# LANGUAGES: true when character has a LANGUAGES advantage entry for this
# language (s45 line 211-213).
static func character_knows_language(character: L5RCharacterData, language: String) -> bool:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.LANGUAGES:
			if adv.metadata.get("language", "") == language:
				return true
	return false


# LANGUAGES: all language strings this character knows (s45).
static func get_known_languages(character: L5RCharacterData) -> Array[String]:
	var langs: Array[String] = []
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.LANGUAGES:
			var lang: String = adv.metadata.get("language", "")
			if lang != "" and lang not in langs:
				langs.append(lang)
	return langs


# FORCED_RETIREMENT: may not advance further in current School (s45 line 563-565).
static func is_school_advancement_blocked(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.FORCED_RETIREMENT)


# OBLIGATION: 0 = none, 3 = minor, 6 = major (s45 line 647-649).
# NOT AVAILABLE AT CHARACTER CREATION — acquired during play only.
static func get_obligation_tier(character: L5RCharacterData) -> int:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.OBLIGATION:
			return dis.metadata.get("tier", 3)
	return 0


# DEBT: 0 = none, 1 = quarter stipend, 2 = full stipend, 3 = exceeds stipend (s45 line 505-507).
static func get_debt_tier(character: L5RCharacterData) -> int:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.DEBT:
			return dis.metadata.get("tier", 1)
	return 0


# DARK_SECRET: character carries a potentially life-ruining secret (s45 line 501-503).
static func has_dark_secret(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.DARK_SECRET)


# BLACKMAILED: someone holds a dark secret over this character (s45 line 445-447).
static func is_blackmailed(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.BLACKMAILED)


# BLACKMAIL (advantage): character_id of the individual being blackmailed (s45 line 23-25).
# Returns -1 if character does not hold blackmail material.
static func get_blackmail_target_id(character: L5RCharacterData) -> int:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.BLACKMAIL:
			return adv.metadata.get("target_id", -1)
	return -1


# UNCENTERED: cannot learn any Void Kiho (s45 line 711-713).
# Advantage-blocking (ISHIKEN_DO, VOID_VERSATILITY) handled in assign_derived_advantages.
static func is_void_kiho_blocked(character: L5RCharacterData) -> bool:
	return has_disadvantage(character, Enums.Disadvantage.UNCENTERED)


# MULTIPLE_SCHOOLS: may study at Schools from different major Schools during play (s45 line 239-241).
static func can_study_multiple_schools(character: L5RCharacterData) -> bool:
	return has_advantage(character, Enums.Advantage.MULTIPLE_SCHOOLS)


# ELEMENTAL_BLESSING: returns the Ring enum int this character is blessed with,
# or -1 if no blessing (s45 line 87-89). Void is never a valid element for this advantage.
static func get_elemental_blessing_ring(character: L5RCharacterData) -> int:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.ELEMENTAL_BLESSING:
			return adv.metadata.get("ring", -1)
	return -1


# ELEMENTAL_BLESSING + ENLIGHTENED: XP discount (in XP, not progress) per trait
# advance for the given ring (s45 lines 87-93).
# ELEMENTAL_BLESSING: -1 XP per trait advance on the blessed element's ring (not Void).
# ENLIGHTENED:       -2 XP per advance of the Void ring.
# Callers multiply by NPCAdvancement.XP_TO_PROGRESS to convert to progress units.
static func get_trait_xp_discount(character: L5RCharacterData, ring: Enums.Ring) -> int:
	if ring == Enums.Ring.VOID:
		if has_advantage(character, Enums.Advantage.ENLIGHTENED):
			return 2
		return 0
	var blessed: int = get_elemental_blessing_ring(character)
	if blessed == int(ring):
		return 1
	return 0


# WEALTHY: 2 additional starting koku per point (per WEALTHY advantage entry) (s45 line 403-405).
static func get_wealth_koku_bonus(character: L5RCharacterData) -> int:
	var total: int = 0
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.WEALTHY:
			total += 2
	return total


# FORBIDDEN_KNOWLEDGE: subject string (e.g. "Kolat", "Maho") for social bonus
# lookups. Returns "" if character does not have this advantage (s45 line 99-101).
static func get_forbidden_knowledge_type(character: L5RCharacterData) -> String:
	for adv: AdvantageData in character.advantages:
		if adv.advantage_type == Enums.Advantage.FORBIDDEN_KNOWLEDGE:
			return adv.metadata.get("subject", "")
	return ""


# SWORN_ENEMY: character_id of this character's sworn enemy (s45 line 699-701).
# Returns -1 if no sworn enemy.
static func get_sworn_enemy_id(character: L5RCharacterData) -> int:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.SWORN_ENEMY:
			return dis.metadata.get("enemy_id", -1)
	return -1


## PARAGON Duty: check whether spending a Void Point to negate all TN/Wound penalties
## would change a failed roll into a success (s45 line 257).
## NPC simulation proxy: retroactive activation matching DARK_PARAGON pattern.
## Preconditions: character has PARAGON Duty, owns ≥1 VP, does not have FAILURE_OF_BUSHIDO Duty.
## Returns {should_activate: bool}.
static func check_paragon_duty_activation(
	character: L5RCharacterData,
	roll_total: int,
	tn: int,
	wound_penalty: int,
) -> Dictionary:
	var adv: AdvantageData = get_advantage(character, Enums.Advantage.PARAGON)
	if adv == null or adv.metadata.get("virtue", "") != "Duty":
		return {"should_activate": false}
	# FAILURE_OF_BUSHIDO Duty: cannot spend Void to negate Wounds (s45 line 561)
	if has_disadvantage(character, Enums.Disadvantage.FAILURE_OF_BUSHIDO):
		var fob: DisadvantageData = get_disadvantage(character, Enums.Disadvantage.FAILURE_OF_BUSHIDO)
		if fob != null and fob.metadata.get("precept", "") == "Duty":
			return {"should_activate": false}
	if character.current_void_points <= 0:
		return {"should_activate": false}
	# Only the wound_penalty portion is tracked in the result dict. Negate it if
	# doing so would turn the failure into a success.
	if wound_penalty >= 0:
		return {"should_activate": false}
	var new_total: int = roll_total - wound_penalty  # wound_penalty is negative; subtracting negates it
	return {"should_activate": new_total >= tn}


## ELEMENTAL_IMBALANCE overflow resolver (s45 lines 535-545).
## Called after a failed Willpower resistance roll while casting the imbalanced element.
## `element` is the cast element (Enums.Ring), `mastery_level` is the spell ML (1–6).
## `dice` may be null for tests; Fire ML1-2 wounds require dice.
## Returns {applied: bool, element: int, tier: String, sim_effects: Array[String],
##          wounds_taken: int, void_points_lost: int, void_blocked_until_ic_day: int}.
## Effect fields set to 0/-1 if not applicable.
## Combat/movement effects (Air, Earth, Water overflows; Fire ML3+) are metadata only —
## blocked on s40 individual combat.
static func apply_elemental_imbalance_overflow(
	character: L5RCharacterData,
	element: int,
	mastery_level: int,
	dice: DiceEngine,
	ic_day: int,
) -> Dictionary:
	var sim_effects: Array[String] = []
	var wounds_taken: int = 0
	var vp_lost: int = 0
	var void_blocked_until: int = -1

	var tier: String = "low" if mastery_level <= 2 else ("mid" if mastery_level <= 4 else "high")

	match element:
		Enums.Ring.VOID:
			if mastery_level <= 2:
				# ML1-2: Lose 1 VP. If no VP remain, take 5 Wounds instead.
				if character.current_void_points > 0:
					character.current_void_points -= 1
					vp_lost = 1
					sim_effects.append("void_drain_1")
				else:
					character.wounds_taken += 5
					wounds_taken = 5
					sim_effects.append("void_overflow_5_wounds")
			elif mastery_level <= 4:
				# ML3-4: All VPs drained; cannot recover for 48 IC days.
				# Also -1k0 to all rolls for 24 hours (4 IC days) per s45 line 545.
				vp_lost = character.current_void_points
				character.current_void_points = 0
				void_blocked_until = ic_day + 48
				character.void_refresh_blocked_until = void_blocked_until
				character.void_imbalance_penalty_until = ic_day + 4
				sim_effects.append("void_drain_all")
				sim_effects.append("void_blocked_48")
				sim_effects.append("void_penalty_4_ic_days")
			else:
				# ML5-6: All VPs lost; blocked 1 IC week (7 days). AoE Fear blocked on s40.
				vp_lost = character.current_void_points
				character.current_void_points = 0
				void_blocked_until = ic_day + 7
				character.void_refresh_blocked_until = void_blocked_until
				sim_effects.append("void_drain_all")
				sim_effects.append("void_blocked_7_days")
				sim_effects.append("aoe_fear_3_blocked_s40")

		Enums.Ring.FIRE:
			if mastery_level <= 2:
				# ML1-2: Caster's hands ignite. Take MLk1 Wounds (s45 line 541).
				var wound_roll: int = 0
				if dice != null:
					var dr: DiceResult = dice.roll_and_keep(mastery_level, 1)
					wound_roll = dr.total
				else:
					wound_roll = mastery_level * 3  # average fallback for tests
				character.wounds_taken += wound_roll
				wounds_taken = wound_roll
				sim_effects.append("fire_hand_wounds_%d" % wound_roll)
			else:
				# ML3-4 and ML5-6 involve AoE effects — blocked on s40.
				sim_effects.append("fire_aoe_blocked_s40")

		Enums.Ring.AIR:
			if mastery_level <= 2:
				# ML1-2: stealth is broken; blocked on s40.
				sim_effects.append("air_stealth_broken_blocked")
			elif mastery_level <= 4:
				# ML3-4: Perceived Honor advantage fails for 7 IC days; if no Perceived Honor,
				# -1k1 to all Social Skill Rolls for 7 IC days (s45 line 537).
				var has_ph: bool = get_advantage(character, Enums.Advantage.PERCEIVED_HONOR) != null
				if has_ph:
					character.perceived_honor_blocked_until = ic_day + 7
					sim_effects.append("air_perceived_honor_blocked_7_ic_days")
				else:
					character.air_imbalance_social_penalty_until = ic_day + 7
					sim_effects.append("air_social_penalty_1k1_7_ic_days")
			else:
				# ML5-6: AoE knockdown — blocked on s40.
				sim_effects.append("air_aoe_knockdown_blocked_s40")

		Enums.Ring.EARTH:
			# All Earth overflows involve movement or trait reduction — blocked on s40.
			sim_effects.append("earth_overflow_blocked_s40")

		Enums.Ring.WATER:
			# ML3-4 and ML5-6 involve trait reduction and AoE — blocked on s40.
			if mastery_level <= 2:
				# ML1-2: -1k0 to next Social Skill Roll (s45 line 543).
				character.water_imbalance_social_penalty = true
				sim_effects.append("water_next_social_minus_1k0")
			else:
				sim_effects.append("water_overflow_blocked_s40")

	return {
		"applied": true,
		"element": element,
		"tier": tier,
		"sim_effects": sim_effects,
		"wounds_taken": wounds_taken,
		"void_points_lost": vp_lost,
		"void_blocked_until_ic_day": void_blocked_until,
	}


## BATTLE_HEALING query: can this character use Battle Healing to restore a Wound Rank?
## Battle Healing requires ≥1 Water slot OR ≥2 combined slots in any other element(s) (s45 line 21).
## GDD: "Once per day per person" — healer may only heal each target once per day.
## Caller must pass element = Enums.Ring.WATER (1 slot) or Enums.Ring.NONE (2 mixed slots).
## Optional target: when provided, checks the per-day-per-person gate.
## Returns {can_use: bool, cost_element: int, cost_slots: int}.
static func can_use_battle_healing(
	character: L5RCharacterData,
	element: int,
	target: L5RCharacterData = null,
) -> Dictionary:
	if not has_advantage(character, Enums.Advantage.BATTLE_HEALING):
		return {"can_use": false, "cost_element": Enums.Ring.NONE, "cost_slots": 0}
	# Once per day per person gate (s45 line 21).
	if target != null:
		var adv: AdvantageData = get_advantage(character, Enums.Advantage.BATTLE_HEALING)
		if adv != null:
			var healed_today: Array = adv.metadata.get("healed_today", [])
			if target.character_id in healed_today:
				return {"can_use": false, "cost_element": Enums.Ring.NONE, "cost_slots": 0}
	if element == Enums.Ring.WATER:
		# One Water slot is sufficient
		var water_used: int = SpellSystem.get_slots_used(character, Enums.Ring.WATER)
		var water_max: int = SpellSystem.get_daily_slots(character, Enums.Ring.WATER)
		if water_max - water_used >= 1:
			return {"can_use": true, "cost_element": Enums.Ring.WATER, "cost_slots": 1}
		return {"can_use": false, "cost_element": Enums.Ring.NONE, "cost_slots": 0}
	else:
		# Two slots from any combination of non-Water elements
		var available: int = 0
		for ring: int in [Enums.Ring.AIR, Enums.Ring.EARTH, Enums.Ring.FIRE, Enums.Ring.VOID]:
			var used: int = SpellSystem.get_slots_used(character, ring)
			var max_slots: int = SpellSystem.get_daily_slots(character, ring)
			available += max_slots - used
		if available >= 2:
			return {"can_use": true, "cost_element": Enums.Ring.NONE, "cost_slots": 2}
		return {"can_use": false, "cost_element": Enums.Ring.NONE, "cost_slots": 0}


## BATTLE_HEALING consumption: spend slots and apply one Wound Rank of healing to target (s45 line 21).
## Caller must verify can_use_battle_healing() first.
## Returns {healed: bool, wounds_removed: int, slots_consumed: int, heal_element: int}.
static func consume_battle_healing_slot(
	healer: L5RCharacterData,
	target: L5RCharacterData,
	element: int,
) -> Dictionary:
	if not has_advantage(healer, Enums.Advantage.BATTLE_HEALING):
		return {"healed": false, "wounds_removed": 0, "slots_consumed": 0, "heal_element": element}
	# Determine slots to consume
	var slots_consumed: int = 0
	if element == Enums.Ring.WATER:
		var water_used: int = SpellSystem.get_slots_used(healer, Enums.Ring.WATER)
		var water_max: int = SpellSystem.get_daily_slots(healer, Enums.Ring.WATER)
		if water_max - water_used < 1:
			return {"healed": false, "wounds_removed": 0, "slots_consumed": 0, "heal_element": element}
		SpellSystem.consume_slot(healer, Enums.Ring.WATER)
		slots_consumed = 1
	else:
		# Consume two slots from available non-Water elements (lowest-remaining first)
		var rings_order: Array[int] = [Enums.Ring.AIR, Enums.Ring.EARTH, Enums.Ring.FIRE, Enums.Ring.VOID]
		var needed: int = 2
		for ring: int in rings_order:
			if needed <= 0:
				break
			var used: int = SpellSystem.get_slots_used(healer, ring)
			var max_slots: int = SpellSystem.get_daily_slots(healer, ring)
			if max_slots - used > 0:
				SpellSystem.consume_slot(healer, ring)
				needed -= 1
				slots_consumed += 1
		if needed > 0:
			return {"healed": false, "wounds_removed": 0, "slots_consumed": 0, "heal_element": element}
	# Heal one Wound Rank (5 wounds per L5R 4e wound track step)
	var WOUNDS_PER_RANK: int = 5
	var before: int = target.wounds_taken
	target.wounds_taken = maxi(0, target.wounds_taken - WOUNDS_PER_RANK)
	# Record target as healed today to enforce once-per-day-per-person limit (s45 line 21).
	var bh_adv: AdvantageData = get_advantage(healer, Enums.Advantage.BATTLE_HEALING)
	if bh_adv != null:
		if not bh_adv.metadata.has("healed_today"):
			bh_adv.metadata["healed_today"] = []
		if target.character_id not in bh_adv.metadata["healed_today"]:
			bh_adv.metadata["healed_today"].append(target.character_id)
	return {
		"healed": true,
		"wounds_removed": before - target.wounds_taken,
		"slots_consumed": slots_consumed,
		"heal_element": element,
	}


# SWORN_ENEMY nemesis variant: cannot spend Void Points when opposing this enemy (s45).
static func is_enemy_nemesis(character: L5RCharacterData, enemy_id: int) -> bool:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.SWORN_ENEMY:
			if dis.metadata.get("enemy_id", -1) == enemy_id:
				return dis.metadata.get("is_nemesis", false)
	return false


# JEALOUSY: character_id of the NPC this character is obsessed with outperforming (s45 line 607-609).
# Returns -1 if none.
static func get_jealousy_target_id(character: L5RCharacterData) -> int:
	for dis: DisadvantageData in character.disadvantages:
		if dis.disadvantage_type == Enums.Disadvantage.JEALOUSY:
			return dis.metadata.get("target_id", -1)
	return -1
