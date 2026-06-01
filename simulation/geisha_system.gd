class_name GeishaSystem
## Geisha Intelligence System per GDD s57.45 (locked s57.45a).
## Entirely passive — no new ActionIDs. NPCs visit via WindDownSystem (s57.44).
## Handles topic routing: patron → geisha → okaasan → Bayushi handler, with
## parallel Kolat eavesdropping path.

# -- Koku costs per visit (A1–A3) ----------------------------------------------

const GEISHA_KOKU_TIER_1: float = 0.1  # Provincial House
const GEISHA_KOKU_TIER_2: float = 0.3  # Established House
const GEISHA_KOKU_TIER_3: float = 1.0  # Famous House

## Index 0 = no okiya (unused), 1–3 = tier.
const KOKU_BY_TIER: Array = [0.0, GEISHA_KOKU_TIER_1, GEISHA_KOKU_TIER_2, GEISHA_KOKU_TIER_3]

# -- Patron visit disposition gain (A4) ----------------------------------------

const PATRON_VISIT_DISPOSITION_GAIN: int = 1  # per visit, toward assigned geisha

# -- Geisha routing probability (A5–A14) ---------------------------------------

const GEISHA_BASE_ROUTE_CHANCE: float = 0.50
const GEISHA_OKAASAN_DISP_WEIGHT: float = 0.003   # per point of disp_toward_okaasan
const GEISHA_PATRON_DISP_WEIGHT: float = 0.003    # per point of disp_toward_patron (negative)
const GEISHA_CHUGI_BONUS: float = 0.15
const GEISHA_JIN_PENALTY: float = -0.15
const GEISHA_SEIGYO_BONUS: float = 0.10
const GEISHA_ISHI_PENALTY: float = -0.15
const GEISHA_TOPIC_TIER_PENALTY: float = -0.10    # per severity step above TIER_4
const GEISHA_ROUTE_MIN: float = 0.05
const GEISHA_ROUTE_MAX: float = 0.95

# -- Okaasan routing probability (A15–A22) -------------------------------------

const OKAASAN_BASE_ROUTE_CHANCE: float = 0.65
const OKAASAN_HANDLER_DISP_WEIGHT: float = 0.004  # per point of disp_toward_handler
const OKAASAN_CHUGI_BONUS: float = 0.10
const OKAASAN_SEIGYO_BONUS: float = 0.15
const OKAASAN_ISHI_PENALTY: float = -0.20
const OKAASAN_TOPIC_TIER_BONUS: float = 0.10      # per severity step above TIER_4
const OKAASAN_ROUTE_MIN: float = 0.05
const OKAASAN_ROUTE_MAX: float = 0.95

# -- Kolat eavesdropping (A23–A24) ---------------------------------------------

const KOLAT_BASE_TN: int = 10
const KOLAT_STEALTH_MULTIPLIER: int = 5  # per Stealth rank of okaasan

# -- World generation (A25–A34) ------------------------------------------------

## Scorpion-controlled probability by territory clan (0.0–1.0).
const HANDLER_CHANCE: Dictionary = {
	"Scorpion": 0.90,
	"Crane":    0.40,
	"Imperial": 0.60,
	"Lion":     0.30,
	"Phoenix":  0.30,
	"Dragon":   0.30,
	"Crab":     0.20,
	"Unicorn":  0.25,
}
const HANDLER_CHANCE_DEFAULT: float = 0.25  # unrecognized clan

const KOLAT_INFILTRATION_CHANCE: float = 0.15  # flat rate all okiya

const IMPERIAL_CAPITAL_OKIYA_COUNT: int = 3
const CASTLE_OKIYA_CHANCE: float = 0.70

## Okiya tier by settlement type and clan context. Crane/Scorpion cities get tier 3.
## Clan lists that upgrade tier for CITY and FAMILY_CASTLE.
const CITY_UPGRADE_CLANS: Array = ["Crane", "Scorpion"]


# ============================================================================
# PRIMARY ENTRY POINT — called per patron per geisha wind-down visit
# ============================================================================

## Process a patron's geisha house visit. `topic_id` is the topic that leaked.
## Returns a dict describing the routing outcome for the orchestrator.
##
## result keys:
##   patron_id, okiya_id, topic_id,
##   geisha_routed (bool), okaasan_received (bool),
##   handler_received (bool), kolat_received (bool),
##   disposition_gain_applied (bool), visit_count (int).
static func process_geisha_visit(
	patron: L5RCharacterData,
	okiya: OkiyaData,
	topic_id: int,
	topics_by_id: Dictionary,
	characters_by_id: Dictionary,
	dice: DiceEngine,
) -> Dictionary:
	var result: Dictionary = {
		"patron_id": patron.character_id,
		"okiya_id": okiya.okiya_id,
		"topic_id": topic_id,
		"geisha_routed": false,
		"okaasan_received": false,
		"handler_received": false,
		"kolat_received": false,
		"disposition_gain_applied": false,
		"visit_count": 0,
	}

	if not okiya.is_active:
		return result

	# -- Record visit ----------------------------------------------------------
	var okiya_key: int = okiya.okiya_id
	var visits: int = patron.okiya_visit_counts.get(okiya_key, 0) + 1
	patron.okiya_visit_counts[okiya_key] = visits
	result["visit_count"] = visits

	# -- Assign geisha ---------------------------------------------------------
	var geisha_id: int = _get_or_assign_geisha(patron, okiya)
	var geisha: L5RCharacterData = null
	if geisha_id >= 0 and characters_by_id.has(geisha_id):
		geisha = characters_by_id[geisha_id] as L5RCharacterData

	# -- Patron disposition gain toward assigned geisha (A4) -------------------
	if geisha != null and not CharacterStats.is_dead(geisha):
		var old_disp: int = patron.disposition_values.get(geisha_id, 0)
		patron.disposition_values[geisha_id] = clampi(old_disp + PATRON_VISIT_DISPOSITION_GAIN, -100, 100)
		result["disposition_gain_applied"] = true

	# -- Geisha routing roll ---------------------------------------------------
	var topic_tier: int = _get_topic_tier(topic_id, topics_by_id)
	var geisha_p: float = _geisha_routing_chance(geisha, patron, okiya, topic_tier)
	var geisha_rolled: float = dice.randf()
	if geisha_rolled >= geisha_p:
		return result  # geisha withholds

	result["geisha_routed"] = true

	# -- Okaasan receives topic ------------------------------------------------
	var okaasan: L5RCharacterData = null
	if okiya.okaasan_id >= 0 and characters_by_id.has(okiya.okaasan_id):
		okaasan = characters_by_id[okiya.okaasan_id] as L5RCharacterData
		if CharacterStats.is_dead(okaasan):
			okaasan = null

	result["okaasan_received"] = true
	if okaasan != null and not okaasan.topic_pool.has(topic_id):
		okaasan.topic_pool.append(topic_id)

	# -- Kolat eavesdrop (parallel — fires regardless of okaasan routing) ------
	if okiya.kolat_agent_id >= 0 and characters_by_id.has(okiya.kolat_agent_id):
		var kolat: L5RCharacterData = characters_by_id[okiya.kolat_agent_id] as L5RCharacterData
		if not CharacterStats.is_dead(kolat):
			var kolat_success: bool = _kolat_eavesdrop_roll(okaasan, kolat, dice)
			if kolat_success:
				result["kolat_received"] = true
				if not kolat.topic_pool.has(topic_id):
					kolat.topic_pool.append(topic_id)

	# -- Okaasan routing roll --------------------------------------------------
	if okiya.handler_id < 0:
		return result  # Independent okiya — no handler to route to

	var handler: L5RCharacterData = null
	if characters_by_id.has(okiya.handler_id):
		handler = characters_by_id[okiya.handler_id] as L5RCharacterData
		if CharacterStats.is_dead(handler):
			handler = null

	var okaasan_p: float = _okaasan_routing_chance(okaasan, okiya, topic_tier)
	var okaasan_rolled: float = dice.randf()
	if okaasan_rolled >= okaasan_p:
		return result  # okaasan withholds

	result["handler_received"] = true
	if handler != null and not handler.topic_pool.has(topic_id):
		handler.topic_pool.append(topic_id)

	return result


# ============================================================================
# WORLD GENERATION
# ============================================================================

## Generate all okiya for the given settlements at world start.
## Returns Array[OkiyaData]. Modifies settlements in-place (sets okiya_tier,
## appends "okiya" to infrastructure).
static func generate_initial_okiya(
	settlements: Array,
	clans_by_settlement: Dictionary,
	dice: DiceEngine,
	next_okiya_id: Array,
) -> Array:
	var result: Array = []

	for s: SettlementData in settlements:
		var clan: String = clans_by_settlement.get(s.settlement_id, "")
		var okiya_entries: Array = _okiya_entries_for_settlement(s, clan, dice, next_okiya_id)
		for entry: OkiyaData in okiya_entries:
			s.infrastructure.append("okiya")
			result.append(entry)

	return result


# ============================================================================
# PRIVATE HELPERS — ROUTING
# ============================================================================

static func _get_or_assign_geisha(patron: L5RCharacterData, okiya: OkiyaData) -> int:
	var okiya_key: int = okiya.okiya_id
	if patron.assigned_geisha_ids.has(okiya_key):
		return patron.assigned_geisha_ids[okiya_key]
	if okiya.geisha_ids.is_empty():
		return -1
	# Assign deterministically from the list using patron ID as seed.
	var idx: int = patron.character_id % okiya.geisha_ids.size()
	var gid: int = okiya.geisha_ids[idx]
	patron.assigned_geisha_ids[okiya_key] = gid
	return gid


static func _get_topic_tier(topic_id: int, topics_by_id: Dictionary) -> int:
	## Returns TopicData.Tier enum value (0=TIER_1 … 3=TIER_4), or 3 (TIER_4) if unknown.
	if topic_id < 0 or not topics_by_id.has(topic_id):
		return 3  # default to least sensitive
	var topic: TopicData = topics_by_id[topic_id] as TopicData
	return int(topic.tier)


## Severity steps = max(0, 3 - tier_enum_value). TIER_4=0 steps, TIER_1=3 steps.
static func _severity_steps(tier_enum: int) -> int:
	return maxi(0, 3 - tier_enum)


static func _geisha_routing_chance(
	geisha: L5RCharacterData,
	patron: L5RCharacterData,
	okiya: OkiyaData,
	topic_tier: int,
) -> float:
	var p: float = GEISHA_BASE_ROUTE_CHANCE

	# Topic severity penalty.
	p += _severity_steps(topic_tier) * GEISHA_TOPIC_TIER_PENALTY

	if geisha == null:
		return clampf(p, GEISHA_ROUTE_MIN, GEISHA_ROUTE_MAX)

	# Disposition toward okaasan (positive = more likely to route).
	var disp_okaasan: int = 0
	if okiya.okaasan_id >= 0:
		disp_okaasan = geisha.disposition_values.get(okiya.okaasan_id, 0)
	p += float(disp_okaasan) * GEISHA_OKAASAN_DISP_WEIGHT

	# Disposition toward patron (positive = less likely to betray).
	var disp_patron: int = geisha.disposition_values.get(patron.character_id, 0)
	p -= float(disp_patron) * GEISHA_PATRON_DISP_WEIGHT

	# Virtue modifiers.
	match geisha.bushido_virtue:
		Enums.BushidoVirtue.CHUGI:
			p += GEISHA_CHUGI_BONUS
		Enums.BushidoVirtue.JIN:
			p += GEISHA_JIN_PENALTY
	match geisha.shourido_virtue:
		Enums.ShouridoVirtue.SEIGYO:
			p += GEISHA_SEIGYO_BONUS
		Enums.ShouridoVirtue.ISHI:
			p += GEISHA_ISHI_PENALTY

	return clampf(p, GEISHA_ROUTE_MIN, GEISHA_ROUTE_MAX)


static func _okaasan_routing_chance(
	okaasan: L5RCharacterData,
	okiya: OkiyaData,
	topic_tier: int,
) -> float:
	var p: float = OKAASAN_BASE_ROUTE_CHANCE

	# Topic value bonus (higher tier = more worth reporting).
	p += _severity_steps(topic_tier) * OKAASAN_TOPIC_TIER_BONUS

	if okaasan == null:
		return clampf(p, OKAASAN_ROUTE_MIN, OKAASAN_ROUTE_MAX)

	# Disposition toward handler (positive = more likely to route).
	var disp_handler: int = 0
	if okiya.handler_id >= 0:
		disp_handler = okaasan.disposition_values.get(okiya.handler_id, 0)
	p += float(disp_handler) * OKAASAN_HANDLER_DISP_WEIGHT

	# Virtue modifiers.
	match okaasan.bushido_virtue:
		Enums.BushidoVirtue.CHUGI:
			p += OKAASAN_CHUGI_BONUS
	match okaasan.shourido_virtue:
		Enums.ShouridoVirtue.SEIGYO:
			p += OKAASAN_SEIGYO_BONUS
		Enums.ShouridoVirtue.ISHI:
			p += OKAASAN_ISHI_PENALTY

	return clampf(p, OKAASAN_ROUTE_MIN, OKAASAN_ROUTE_MAX)


static func _kolat_eavesdrop_roll(
	okaasan: L5RCharacterData,
	kolat_agent: L5RCharacterData,
	dice: DiceEngine,
) -> bool:
	## Investigation (Notice) / Perception vs TN = BASE + okaasan.Stealth_rank × 5.
	var stealth_rank: int = 0
	if okaasan != null:
		stealth_rank = SkillResolver.get_skill_rank(okaasan, "Stealth")
	var tn: int = KOLAT_BASE_TN + stealth_rank * KOLAT_STEALTH_MULTIPLIER

	var investigation: int = SkillResolver.get_skill_rank(kolat_agent, "Investigation")
	var perception: int = kolat_agent.perception
	var roll: int = DiceEngine.roll_and_keep(investigation + 1, perception, dice)
	return roll >= tn


# ============================================================================
# PRIVATE HELPERS — WORLD GENERATION
# ============================================================================

static func _okiya_entries_for_settlement(
	s: SettlementData,
	clan: String,
	dice: DiceEngine,
	next_okiya_id: Array,
) -> Array:
	var entries: Array = []

	match s.settlement_type:
		Enums.SettlementType.IMPERIAL_CAPITAL:
			# Three okiya: tiers 1, 2, 3 (A33).
			for t: int in [1, 2, 3]:
				entries.append(_make_okiya(next_okiya_id, str(s.settlement_id), t, clan, dice))
			s.okiya_tier = 3

		Enums.SettlementType.CITY:
			var tier: int = 3 if clan in CITY_UPGRADE_CLANS else 2
			entries.append(_make_okiya(next_okiya_id, str(s.settlement_id), tier, clan, dice))
			s.okiya_tier = tier

		Enums.SettlementType.FAMILY_CASTLE:
			var tier: int = 2 if clan in CITY_UPGRADE_CLANS else 1
			entries.append(_make_okiya(next_okiya_id, str(s.settlement_id), tier, clan, dice))
			s.okiya_tier = tier

		Enums.SettlementType.CASTLE:
			# 70% chance (A34 CASTLE_OKIYA_CHANCE).
			if dice.randf() < CASTLE_OKIYA_CHANCE:
				entries.append(_make_okiya(next_okiya_id, str(s.settlement_id), 1, clan, dice))
				s.okiya_tier = 1

	return entries


static func _make_okiya(
	next_okiya_id: Array,
	settlement_id: String,
	tier: int,
	clan: String,
	dice: DiceEngine,
) -> OkiyaData:
	var o := OkiyaData.new()
	o.okiya_id = next_okiya_id[0]
	next_okiya_id[0] += 1
	o.settlement_id = settlement_id
	o.tier = tier
	o.is_scorpion_controlled = _roll_scorpion_control(clan, dice)
	o.handler_id = -1  # handlers are generated separately (Scorpion NPC pipeline)
	o.kolat_agent_id = _roll_kolat_infiltration(dice)
	return o


static func _roll_scorpion_control(clan: String, dice: DiceEngine) -> bool:
	var chance: float = HANDLER_CHANCE.get(clan, HANDLER_CHANCE_DEFAULT)
	return dice.randf() < chance


static func _roll_kolat_infiltration(dice: DiceEngine) -> int:
	## Returns -1 (no agent) or a sentinel -2 (agent present, not yet a character).
	## The orchestrator can replace -2 with a real character ID when Kolat NPCs exist.
	if dice.randf() < KOLAT_INFILTRATION_CHANCE:
		return -2  # present but not a character yet
	return -1


# ============================================================================
# HELPERS — KOKU COST LOOKUP
# ============================================================================

## Returns the koku cost for a visit to an okiya of the given tier.
static func koku_cost_for_tier(tier: int) -> float:
	return KOKU_BY_TIER[clampi(tier, 0, 3)]
