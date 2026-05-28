class_name ExtraditionSystem
## Fugitive extradition evaluation per GDD s11.3.16.
## When a convicted fugitive flees to another clan's territory, the harboring
## lord evaluates whether to cooperate, negotiate, refuse, or deny knowledge.


enum Response {
	COOPERATE,
	NEGOTIATE,
	REFUSE,
	DENY_KNOWLEDGE,
}


const COOPERATION_THRESHOLD: int = 0

# Disposition toward requesting clan (s11.3.16c)
const DISP_FRIEND_BONUS: int = 20
const DISP_NEUTRAL_BONUS: int = 0
const DISP_RIVAL_PENALTY: int = -20
const DISP_FRIEND_FLOOR: int = 31
const DISP_RIVAL_CEILING: int = -11

# Fugitive usefulness (s11.3.16c)
const USEFUL_COMPETENT: int = -15
const USEFUL_INTELLIGENCE: int = -25
const USEFUL_NONE: int = 0

# Political leverage (s11.3.16c)
const LEVERAGE_CHIP: int = -20
const LEVERAGE_NONE: int = 0

# Crime severity pressure (s11.3.16c) — negative values = resist cooperation
const SEVERITY_TIER_PRESSURE: Dictionary = {
	TopicData.Tier.TIER_4: 0,
	TopicData.Tier.TIER_3: -5,
	TopicData.Tier.TIER_2: -15,
	TopicData.Tier.TIER_1: -30,
}

# Fugitive status visibility (s11.3.16c)
const STATUS_LOW: int = 0
const STATUS_MID: int = -5
const STATUS_HIGH: int = -15
const STATUS_MID_FLOOR: float = 3.0
const STATUS_HIGH_FLOOR: float = 5.0

# Personality base for harboring lord (s11.3.16c)
const BUSHIDO_COOPERATION: Dictionary = {
	Enums.BushidoVirtue.GI: 30,
	Enums.BushidoVirtue.MEIYO: 20,
	Enums.BushidoVirtue.REI: 15,
	Enums.BushidoVirtue.CHUGI: 10,
	Enums.BushidoVirtue.JIN: 10,
	Enums.BushidoVirtue.MAKOTO: 10,
	Enums.BushidoVirtue.YU: 0,
}

const SHOURIDO_COOPERATION: Dictionary = {
	Enums.ShouridoVirtue.KANPEKI: 10,
	Enums.ShouridoVirtue.SEIGYO: -20,
	Enums.ShouridoVirtue.DOSATSU: -10,
	Enums.ShouridoVirtue.CHISHIKI: -10,
	Enums.ShouridoVirtue.KETSUI: 0,
	Enums.ShouridoVirtue.KYORYOKU: -15,
	Enums.ShouridoVirtue.ISHI: -15,
}

# Cooperation disposition rewards (s11.3.16d)
const COOPERATE_DISPOSITION_MIN: int = 5
const COOPERATE_DISPOSITION_MAX: int = 10

# Refusal disposition penalties (s11.3.16d)
const REFUSE_DISPOSITION_MIN: int = -10
const REFUSE_DISPOSITION_MAX: int = -20

# Deny knowledge additional penalty (s11.3.16d)
const DENY_INSULT_PENALTY: int = -5


static func evaluate_extradition(
	harboring_lord: L5RCharacterData,
	requesting_clan_disposition: int,
	fugitive_status: float,
	crime_topic_tier: int,
	fugitive_is_useful: bool,
	fugitive_has_intelligence: bool,
	lord_sees_leverage: bool,
) -> Dictionary:
	var score: int = 0

	# Disposition toward requesting clan
	score += _disposition_factor(requesting_clan_disposition)

	# Fugitive usefulness
	if fugitive_has_intelligence:
		score += USEFUL_INTELLIGENCE
	elif fugitive_is_useful:
		score += USEFUL_COMPETENT

	# Political leverage
	if lord_sees_leverage:
		score += LEVERAGE_CHIP

	# Crime severity
	score += SEVERITY_TIER_PRESSURE.get(crime_topic_tier, 0)

	# Fugitive status visibility
	score += _status_factor(fugitive_status)

	# Personality base
	score += _personality_factor(harboring_lord)

	var response: Response = _determine_response(harboring_lord, score, fugitive_status)

	return {
		"cooperation_score": score,
		"cooperates": score >= COOPERATION_THRESHOLD,
		"response": response,
	}


static func get_cooperation_disposition_reward(crime_topic_tier: int) -> int:
	if crime_topic_tier <= TopicData.Tier.TIER_2:
		return COOPERATE_DISPOSITION_MAX
	return COOPERATE_DISPOSITION_MIN


static func get_refusal_disposition_penalty(crime_topic_tier: int) -> int:
	if crime_topic_tier <= TopicData.Tier.TIER_2:
		return REFUSE_DISPOSITION_MAX
	return REFUSE_DISPOSITION_MIN


static func _disposition_factor(disposition: int) -> int:
	if disposition >= DISP_FRIEND_FLOOR:
		return DISP_FRIEND_BONUS
	if disposition <= DISP_RIVAL_CEILING:
		return DISP_RIVAL_PENALTY
	return DISP_NEUTRAL_BONUS


static func _status_factor(fugitive_status: float) -> int:
	if fugitive_status >= STATUS_HIGH_FLOOR:
		return STATUS_HIGH
	if fugitive_status >= STATUS_MID_FLOOR:
		return STATUS_MID
	return STATUS_LOW


static func _personality_factor(lord: L5RCharacterData) -> int:
	if lord.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return SHOURIDO_COOPERATION.get(lord.shourido_virtue, 0)
	return BUSHIDO_COOPERATION.get(lord.bushido_virtue, 0)


static func _determine_response(lord: L5RCharacterData, score: int, fugitive_status: float) -> Response:
	if score >= COOPERATION_THRESHOLD:
		return Response.COOPERATE

	# Below threshold: personality determines response type
	if lord.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return Response.NEGOTIATE

	if lord.bushido_virtue == Enums.BushidoVirtue.REI:
		if score >= -10:
			return Response.NEGOTIATE

	# Low-status fugitives allow deny_knowledge
	if fugitive_status < STATUS_MID_FLOOR and score > -30:
		return Response.DENY_KNOWLEDGE

	return Response.REFUSE


static func apply_cooperation(
	harboring_lord: L5RCharacterData,
	requesting_clan_lord_id: int,
	crime_topic_tier: int,
) -> Dictionary:
	var disp_gain: int = get_cooperation_disposition_reward(crime_topic_tier)
	var current: int = harboring_lord.disposition_values.get(requesting_clan_lord_id, 0)
	harboring_lord.disposition_values[requesting_clan_lord_id] = clampi(current + disp_gain, -100, 100)
	return {
		"disposition_change": disp_gain,
		"fugitive_returned": true,
	}


static func apply_refusal(
	harboring_lord: L5RCharacterData,
	requesting_clan_lord_id: int,
	crime_topic_tier: int,
	is_denial: bool,
) -> Dictionary:
	var disp_loss: int = get_refusal_disposition_penalty(crime_topic_tier)
	if is_denial:
		disp_loss += DENY_INSULT_PENALTY
	var current: int = harboring_lord.disposition_values.get(requesting_clan_lord_id, 0)
	harboring_lord.disposition_values[requesting_clan_lord_id] = clampi(current + disp_loss, -100, 100)
	return {
		"disposition_change": disp_loss,
		"topic_escalation": true,
		"escalated_tier": TopicData.Tier.TIER_3,
	}


static func can_petition_emerald_champion(crime_topic_tier: int) -> bool:
	return crime_topic_tier <= TopicData.Tier.TIER_2
