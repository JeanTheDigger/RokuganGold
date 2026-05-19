class_name TopicMomentumSystem
## Topic & Momentum System per GDD s16.
## Tracks crisis momentum (Tier 1-3), Tier 4 topic decay, personal relevance,
## and public knowledge broadcast.


# -- Momentum Thresholds (s16.1) -----------------------------------------------

enum MomentumLevel {
	RUMOR,
	MINOR_TOPIC,
	SECONDARY_TOPIC,
	MAJOR_TOPIC,
	UNAVOIDABLE_CRISIS,
}

const MOMENTUM_THRESHOLDS: Array[Array] = [
	[0, 10],
	[11, 25],
	[26, 50],
	[51, 75],
	[76, 100],
]

# Floor values for each momentum band (s16.1). Use these as initial momentum
# when creating a topic that should enter a specific visibility bracket.
const MOMENTUM_MINOR_FLOOR: float = 11.0
const MOMENTUM_SECONDARY_FLOOR: float = 26.0
const MOMENTUM_MAJOR_FLOOR: float = 51.0
const MOMENTUM_UNAVOIDABLE_FLOOR: float = 76.0

# Default initial momentum for a newly created topic based on its tier.
# TIER_4 → Minor, TIER_3 → Secondary, TIER_2 → Major, TIER_1 → Unavoidable.
const TIER_INITIAL_MOMENTUM: Dictionary = {
	TopicData.Tier.TIER_4: 11.0,
	TopicData.Tier.TIER_3: 26.0,
	TopicData.Tier.TIER_2: 51.0,
	TopicData.Tier.TIER_1: 80.0,
}

static func initial_momentum_for_tier(tier: TopicData.Tier) -> float:
	return TIER_INITIAL_MOMENTUM.get(tier, MOMENTUM_MINOR_FLOOR)

static func get_momentum_level(momentum: float) -> MomentumLevel:
	if momentum <= 10:
		return MomentumLevel.RUMOR
	if momentum <= 25:
		return MomentumLevel.MINOR_TOPIC
	if momentum <= 50:
		return MomentumLevel.SECONDARY_TOPIC
	if momentum <= 75:
		return MomentumLevel.MAJOR_TOPIC
	return MomentumLevel.UNAVOIDABLE_CRISIS


# -- Momentum Gain Per Tick (s16.1) --------------------------------------------

const TIER_MOMENTUM_RATE: Dictionary = {
	TopicData.Tier.TIER_1: 3.0,
	TopicData.Tier.TIER_2: 2.0,
	TopicData.Tier.TIER_3: 1.0,
	TopicData.Tier.TIER_4: 0.0,
}

static func get_scope_multiplier(provinces_affected: int) -> float:
	if provinces_affected <= 1:
		return 1.0
	if provinces_affected <= 3:
		return 1.5
	if provinces_affected <= 6:
		return 2.0
	return 3.0


static func calculate_momentum_gain(topic: TopicData) -> float:
	if topic.tier == TopicData.Tier.TIER_4:
		return 0.0
	var base: float = TIER_MOMENTUM_RATE.get(topic.tier, 0.0)
	var scope: float = get_scope_multiplier(topic.provinces_affected.size())
	return base * scope


static func advance_crisis_momentum(topic: TopicData) -> float:
	if topic.resolved:
		return 0.0
	var gain: float = calculate_momentum_gain(topic)
	var old: float = topic.momentum
	topic.momentum = minf(topic.momentum + gain, 100.0)
	return topic.momentum - old


# -- Tier 4 Topic Decay (s16.5) ------------------------------------------------
# Discussion-driven: loses momentum when not discussed, holds when discussed.

const TIER4_DECAY_PER_DAY: float = 2.0
const TIER4_DISCUSSION_HOLD: float = 1.0

static func decay_tier4_topic(topic: TopicData) -> float:
	if topic.tier != TopicData.Tier.TIER_4:
		return 0.0
	if topic.resolved:
		return 0.0

	var old: float = topic.momentum
	if topic.discussion_count_this_day > 0:
		var boost: float = topic.discussion_count_this_day * TIER4_DISCUSSION_HOLD
		topic.momentum = minf(topic.momentum + boost - TIER4_DECAY_PER_DAY, 100.0)
	else:
		topic.momentum -= TIER4_DECAY_PER_DAY

	topic.momentum = maxf(topic.momentum, 0.0)
	topic.discussion_count_this_day = 0
	return topic.momentum - old


static func is_topic_expired(topic: TopicData) -> bool:
	return topic.tier == TopicData.Tier.TIER_4 and topic.momentum <= 0.0 and not topic.resolved


# -- Personal Relevance Score (s16.4) ------------------------------------------

const TIER1_MINIMUM_RELEVANCE: float = 50.0
const TIER3_MAXIMUM_RELEVANCE: float = 60.0

const CLAN_OWN_MULTIPLIER: float = 2.0
const CLAN_NEIGHBOR_MULTIPLIER: float = 1.5
const CLAN_ALLIED_MULTIPLIER: float = 1.5
const CLAN_DISTANT_MULTIPLIER: float = 1.0
const CLAN_ENEMY_MULTIPLIER: float = 0.75

const FAMILY_OWN_BONUS: float = 20.0
const FAMILY_SAME_CLAN_BONUS: float = 10.0

enum ClanRelation { OWN, NEIGHBOR, ALLIED, DISTANT, ENEMY }

static func get_clan_multiplier(relation: ClanRelation) -> float:
	match relation:
		ClanRelation.OWN: return CLAN_OWN_MULTIPLIER
		ClanRelation.NEIGHBOR: return CLAN_NEIGHBOR_MULTIPLIER
		ClanRelation.ALLIED: return CLAN_ALLIED_MULTIPLIER
		ClanRelation.DISTANT: return CLAN_DISTANT_MULTIPLIER
		ClanRelation.ENEMY: return CLAN_ENEMY_MULTIPLIER
		_: return CLAN_DISTANT_MULTIPLIER


static func calculate_personal_relevance(
	topic: TopicData,
	clan_relation: ClanRelation,
	is_own_family: bool,
	is_same_clan_family: bool,
) -> float:
	var base: float = topic.momentum
	var clan_mult: float = get_clan_multiplier(clan_relation)
	var relevance: float = base * clan_mult

	if is_own_family:
		relevance += FAMILY_OWN_BONUS
	elif is_same_clan_family:
		relevance += FAMILY_SAME_CLAN_BONUS

	match topic.tier:
		TopicData.Tier.TIER_1:
			relevance = maxf(relevance, TIER1_MINIMUM_RELEVANCE)
		TopicData.Tier.TIER_3:
			relevance = minf(relevance, TIER3_MAXIMUM_RELEVANCE)

	return clampf(relevance, 0.0, 100.0)


# -- Position Resistance (s16.4) -----------------------------------------------

static func calculate_position_resistance(base_movement: float, relevance: float) -> float:
	return base_movement / (1.0 + relevance / 100.0)


# -- Position Weight (s16.4) ---------------------------------------------------

static func calculate_position_weight(status: float, relevance: float) -> float:
	return status * (relevance / 50.0)


# -- Aggregate Weighted Opinion (s16.4) ----------------------------------------

static func calculate_aggregate_opinion(
	positions: Array[float],
	weights: Array[float],
) -> float:
	if positions.size() != weights.size() or positions.size() == 0:
		return 0.0
	var weighted_sum: float = 0.0
	var weight_total: float = 0.0
	for i: int in range(positions.size()):
		weighted_sum += positions[i] * weights[i]
		weight_total += weights[i]
	if weight_total <= 0.0:
		return 0.0
	return weighted_sum / weight_total


# -- Daily Tick Processing -----------------------------------------------------

static func process_daily_tick(topics: Array[TopicData]) -> Dictionary:
	var expired: Array[int] = []
	var momentum_changes: Dictionary = {}

	for topic: TopicData in topics:
		if topic.resolved:
			continue

		var change: float = 0.0
		if topic.tier == TopicData.Tier.TIER_4:
			change = decay_tier4_topic(topic)
			if is_topic_expired(topic):
				expired.append(topic.topic_id)
		else:
			change = advance_crisis_momentum(topic)

		if absf(change) > 0.001:
			momentum_changes[topic.topic_id] = change

	return {
		"momentum_changes": momentum_changes,
		"expired_topic_ids": expired,
	}


# -- Topic Factory -------------------------------------------------------------

static func create_topic(
	topic_id: int,
	title: String,
	tier: TopicData.Tier,
	category: TopicData.Category,
	ic_day: int,
	initial_momentum: float = MOMENTUM_MINOR_FLOOR,
	provinces_affected: Array[int] = [],
	clan_involved: String = "",
	family_involved: String = "",
	subject_character_id: int = -1,
	topic_type: String = "",
	variant: String = "",
) -> TopicData:
	var t := TopicData.new()
	t.topic_id = topic_id
	t.title = title
	t.topic_type = topic_type
	t.variant = variant
	t.tier = tier
	t.category = category
	t.ic_day_created = ic_day
	t.momentum = initial_momentum
	t.provinces_affected = provinces_affected
	t.clan_involved = clan_involved
	t.family_involved = family_involved
	t.subject_character_id = subject_character_id
	return t


static func resolve_topic(topic: TopicData) -> void:
	topic.resolved = true
	topic.momentum = 0.0


# -- Discussion Count Wiring (s16.5) -------------------------------------------

static func increment_discussion_counts(
	topics: Array[TopicData],
	discussed_topic_ids: Array[int],
) -> void:
	var topic_map: Dictionary = {}
	for topic: TopicData in topics:
		topic_map[topic.topic_id] = topic
	for tid: int in discussed_topic_ids:
		var topic: TopicData = topic_map.get(tid)
		if topic != null:
			topic.discussion_count_this_day += 1


# -- Public Knowledge Broadcast (s16.1) ----------------------------------------

const BROADCAST_MINOR: float = 11.0
const BROADCAST_SECONDARY: float = 26.0
const BROADCAST_MAJOR: float = 51.0
const BROADCAST_UNAVOIDABLE: float = 76.0

static func broadcast_public_knowledge(
	topics: Array[TopicData],
	characters: Array[L5RCharacterData],
	character_province_map: Dictionary,
	province_clan_map: Dictionary,
	provinces: Dictionary = {},
	current_season: int = 0,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for topic: TopicData in topics:
		if topic.resolved or topic.momentum < BROADCAST_MINOR:
			continue

		var target_chars: Array[L5RCharacterData] = _get_broadcast_targets(
			topic, characters, character_province_map, province_clan_map, provinces
		)

		for c: L5RCharacterData in target_chars:
			if topic.topic_id in c.topic_pool:
				continue
			c.topic_pool.append(topic.topic_id)
			InformationSystem.add_knowledge(c, InformationSystem.make_entry(
				Enums.KnowledgeSource.PUBLIC_KNOWLEDGE,
				"topic_learned",
				{"topic": topic.topic_id, "momentum": topic.momentum},
				current_season,
			))
			results.append({
				"character_id": c.character_id,
				"topic_id": topic.topic_id,
				"source": "public_knowledge",
			})

	return results


static func _get_broadcast_targets(
	topic: TopicData,
	characters: Array[L5RCharacterData],
	character_province_map: Dictionary,
	province_clan_map: Dictionary,
	provinces: Dictionary = {},
) -> Array[L5RCharacterData]:
	var targets: Array[L5RCharacterData] = []

	if topic.momentum >= BROADCAST_UNAVOIDABLE:
		targets.assign(characters)
		return targets

	var affected_provinces: Array[int] = topic.provinces_affected
	var affected_clans: Array[String] = []
	if topic.momentum >= BROADCAST_MAJOR:
		for pid: int in affected_provinces:
			var clan: String = province_clan_map.get(pid, "")
			if not clan.is_empty() and clan not in affected_clans:
				affected_clans.append(clan)
		if not topic.clan_involved.is_empty() and topic.clan_involved not in affected_clans:
			affected_clans.append(topic.clan_involved)

	for c: L5RCharacterData in characters:
		var char_province: int = character_province_map.get(c.character_id, -1)

		if topic.momentum >= BROADCAST_MAJOR and not affected_clans.is_empty():
			var char_clan: String = province_clan_map.get(char_province, "")
			if char_clan in affected_clans:
				targets.append(c)
				continue

		if char_province < 0:
			continue

		if topic.momentum >= BROADCAST_SECONDARY:
			if char_province in affected_provinces:
				targets.append(c)
				continue
			var adjacent: bool = _is_adjacent_to_affected(
				char_province, affected_provinces, provinces
			)
			if adjacent:
				targets.append(c)
		elif topic.momentum >= BROADCAST_MINOR:
			if char_province in affected_provinces:
				targets.append(c)

	return targets


static func _is_adjacent_to_affected(
	province_id: int,
	affected: Array[int],
	provinces: Dictionary,
) -> bool:
	var province: ProvinceData = provinces.get(province_id)
	if province == null:
		return false
	for adj_id: int in province.adjacent_province_ids:
		if adj_id in affected:
			return true
	return false


# -- Starting Position Calculation (s15.5) -------------------------------------

static func calculate_starting_position(
	topic: TopicData,
	character_dispositions: Dictionary,
	bushido_virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
) -> float:
	var anchor_sum: float = _compute_disposition_anchors(topic, character_dispositions)
	var personality_mod: float = _get_personality_modifier(
		topic.topic_type, topic.variant, bushido_virtue, shourido_virtue
	)
	var position: float = (anchor_sum * 0.5) + personality_mod
	return clampf(position, -100.0, 100.0)


static func _compute_disposition_anchors(
	topic: TopicData,
	dispositions: Dictionary,
) -> float:
	var anchor: float = 0.0
	var subject_id: int = topic.subject_character_id
	if subject_id > 0 and dispositions.has(subject_id):
		var disp: float = float(dispositions.get(subject_id, 0))
		match topic.subject_role:
			"BENEFICIARY":
				anchor += disp
			"VICTIM":
				anchor -= disp
			"PERPETRATOR":
				anchor -= disp
			"NEUTRAL":
				anchor += disp * 0.25
			_:
				anchor += disp * 0.25
	return anchor


static func _get_personality_modifier(
	topic_type: String,
	variant: String,
	bushido: Enums.BushidoVirtue,
	shourido: Enums.ShouridoVirtue,
) -> float:
	var modifier: float = 0.0
	var key: String = topic_type
	if not variant.is_empty():
		key = topic_type + ":" + variant

	if bushido != Enums.BushidoVirtue.NONE:
		var virtue_name: String = _bushido_to_key(bushido)
		var table: Dictionary = VIRTUE_MODIFIERS.get(virtue_name, {})
		if table.has(key):
			modifier += table[key]
		elif table.has(topic_type):
			modifier += table[topic_type]

	if shourido != Enums.ShouridoVirtue.NONE:
		var virtue_name: String = _shourido_to_key(shourido)
		var table: Dictionary = VIRTUE_MODIFIERS.get(virtue_name, {})
		if table.has(key):
			modifier += table[key]
		elif table.has(topic_type):
			modifier += table[topic_type]

	return modifier


static func _bushido_to_key(virtue: Enums.BushidoVirtue) -> String:
	match virtue:
		Enums.BushidoVirtue.GI: return "gi"
		Enums.BushidoVirtue.YU: return "yu"
		Enums.BushidoVirtue.REI: return "rei"
		Enums.BushidoVirtue.CHUGI: return "chugi"
		Enums.BushidoVirtue.MEIYO: return "meiyo"
		Enums.BushidoVirtue.MAKOTO: return "makoto"
		Enums.BushidoVirtue.JIN: return "jin"
	return ""


static func _shourido_to_key(virtue: Enums.ShouridoVirtue) -> String:
	match virtue:
		Enums.ShouridoVirtue.SEIGYO: return "seigyo"
		Enums.ShouridoVirtue.KETSUI: return "ketsui"
		Enums.ShouridoVirtue.DOSATSU: return "dosatsu"
		Enums.ShouridoVirtue.CHISHIKI: return "chishiki"
		Enums.ShouridoVirtue.KANPEKI: return "kanpeki"
		Enums.ShouridoVirtue.KYORYOKU: return "kyoryoku"
		Enums.ShouridoVirtue.ISHI: return "ishi"
	return ""


# -- Virtue-to-Topic Modifier Table (s15.6) ------------------------------------

const VIRTUE_MODIFIERS: Dictionary = {
	"jin": {
		"multi_province_famine": -12, "provincial_famine": -10,
		"harvest_failure": -8, "resource_shortage": -8,
		"plague_outbreak": -10, "shadowlands_incursion": -8,
		"oni_manifestation": -8,
		"death:suspicious": -8, "death:violent_murder": -8, "death:honorable": 0,
		"injury_or_illness": -8, "clan_war": -8,
		"battle_outcome:heavy_casualties": -6, "siege_beginning": -6,
		"famine_relief": 12, "provincial_famine_relief": 10,
		"alliance_formed:ending_conflict": 8, "wedding": 5,
		"birth": 5, "trade_route_disruption": -5, "trade_route_collapse": -8,
		"banditry": -6, "siege_ending:negotiated_peace": 8,
	},
	"yu": {
		"duel": 10, "battle_outcome:victory": 10, "battle_outcome:defeat": -5,
		"clan_war": 8, "shadowlands_incursion": 10, "oni_manifestation": 10,
		"provincial_raid": 6, "border_conflict": 6,
		"desertion_or_defection": -12,
		"unit_destroyed_or_dishonored:cowardice": -10,
		"retirement_or_exile:forced_weakness": -5,
		"siege_beginning": 6, "siege_ending:successful_defense": 10,
	},
	"rei": {
		"disgrace": -10, "formal_insult": -10, "romantic_scandal": -8,
		"gempuku": 8, "wedding": 8,
		"edict_issued:proper_order": 5,
		"battle_outcome:forbidden_tactics": -12,
		"clan_war:atrocity": -10,
		"significant_gift:properly_presented": 6,
		"champions_decision:honorable": 5,
		"betrayal": -8,
	},
	"chugi": {
		"betrayal": -15, "desertion_or_defection": -15,
		"alliance_broken": -10, "spy_uncovered": -8,
		"retirement_or_exile:lord_departure": -8,
		"battle_outcome:victory_duty": 8,
		"edict_issued": 8, "hostage_exchange": 6,
		"alliance_formed": 8, "commander_death": -8,
		"adoption": 5,
	},
	"gi": {
		"betrayal": -12, "spy_uncovered": -10,
		"romantic_scandal:deceptive": -8,
		"kolat_conspiracy": -15,
		"formal_insult:false_fabricated": -10,
		"disgrace:unjust": -10,
		"alliance_formed:sincere": 8,
		"edict_issued:just_ruling": 8,
		"champions_decision:just_ruling": 8,
		"succession_dispute:legitimate_claim": 6,
		"unusual_gift_or_bribe": -8, "criminal_organization": -10,
		"adoption:questionable_legitimacy": -6,
	},
	"meiyo": {
		"disgrace": -15, "desertion_or_defection": -12, "betrayal": -12,
		"battle_outcome:forbidden_tactics": -15,
		"duel": 10, "death:honorable": 8, "death:seppuku": 10,
		"unit_destroyed_or_dishonored": -10,
		"formal_insult": -8, "gempuku": 8,
		"champions_decision:honorable": 8,
		"criminal_organization": -10,
	},
	"makoto": {
		"betrayal": -10, "romantic_scandal:deceptive": -8,
		"spy_uncovered": -8, "kolat_conspiracy": -12,
		"public_declaration:honest": 8,
		"alliance_formed:sincere": 6, "wedding:genuine": 6,
		"formal_insult:false_fabricated": -8,
	},
	"seigyo": {
		"spy_uncovered": 10, "kolat_conspiracy": 10,
		"champions_decision:power_shift": 8,
		"promotion_or_appointment": 8,
		"alliance_formed": 8, "alliance_broken": 6,
		"succession_dispute": 10, "assassination_of_major_lord": 8,
		"edict_issued:restricting_action": -8,
		"natural_disaster": -5, "shadowlands_incursion": -5,
	},
	"ketsui": {
		"battle_outcome:victory": 8, "siege_beginning": 8,
		"clan_war": 6, "desertion_or_defection": -10,
		"battle_outcome:retreat_or_surrender": -8,
		"death:died_fighting": 6,
		"provincial_raid": 5, "border_conflict": 5,
		"shadowlands_incursion": 8,
	},
	"dosatsu": {
		"spy_uncovered": 12, "kolat_conspiracy": 12,
		"omen_observed": 10, "ancestors_displeasure": 10,
		"disappearance": 10, "death:suspicious": 10,
		"unusual_shugenja_casting": 8, "spirit_manifestation": 8,
		"succession_dispute": 8, "betrayal": 8,
	},
	"chishiki": {
		"omen_observed": 10, "spirit_manifestation": 10,
		"unusual_shugenja_casting": 10,
		"cursed_location_discovered": 8,
		"low_level_taint_discovered": 8,
		"ancestral_spirit_disruption": 10,
		"maho_cult_spreading": 8,
		"promotion_or_appointment": 5, "new_appointment": 5,
	},
	"kanpeki": {
		"disgrace": -12, "unit_destroyed_or_dishonored": -10,
		"battle_outcome:poor_tactics": -8,
		"tactical_surprise": 8, "gempuku": 6,
		"death:honorable": 5, "romantic_scandal": -8,
	},
	"kyoryoku": {
		"battle_outcome:victory": 10, "clan_war": 10,
		"shadowlands_incursion": 8, "oni_manifestation": 8,
		"duel": 10, "provincial_raid": 8, "border_conflict": 8,
		"siege_beginning": 8, "desertion_or_defection": -8,
		"alliance_formed:military": 6, "banditry": 5,
	},
	"ishi": {
		"desertion_or_defection": -15,
		"battle_outcome:retreat_or_surrender": -12,
		"clan_war": 8, "shadowlands_incursion": 10,
		"siege_beginning": 10, "death:died_fighting": 8,
		"edict_issued:overriding_personal": -10,
		"battle_outcome:victory_persistence": 8,
		"siege_ending:surrender_forced": -10,
	},
}
