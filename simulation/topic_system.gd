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
	initial_momentum: float = 10.0,
	provinces_affected: Array[int] = [],
	clan_involved: String = "",
	family_involved: String = "",
	subject_character_id: int = -1,
) -> TopicData:
	var t := TopicData.new()
	t.topic_id = topic_id
	t.title = title
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
