class_name FugitiveExtraditionSystem
## Cross-clan fugitive recovery per GDD s11.3.16.
## Handles: fugitive visibility/concealment, extradition request generation,
## harboring lord's scored decision, response options with consequences,
## and escalation paths (Imperial warrant, covert extraction).


# -- Fugitive Visibility (s11.3.16a) -----

const STATUS_VISIBILITY_TOPIC_THRESHOLD: float = 3.0
const STATUS_CONCEALMENT_BONUS_PER_RANK: int = 5

enum ConcealmentMethod {
	SINCERITY_DECEIT,
	STEALTH,
	REMOTE_PROVINCE,
}


static func get_visibility_tier(fugitive_status: float) -> int:
	if fugitive_status >= 5.0:
		return 3
	if fugitive_status >= 3.0:
		return 2
	return 1


static func generates_sighting_topic(fugitive_status: float) -> bool:
	return fugitive_status >= STATUS_VISIBILITY_TOPIC_THRESHOLD


static func get_concealment_tn(
	fugitive_status: float,
	fugitive_glory: float,
) -> int:
	var base: int = 15
	base += int(fugitive_status) * STATUS_CONCEALMENT_BONUS_PER_RANK
	base += int(fugitive_glory) * 3
	return base


# -- Extradition Request (s11.3.16b) -----

static func create_extradition_request(
	requesting_clan: String,
	harboring_clan: String,
	fugitive_name: String,
	crime_type: Enums.CrimeType,
) -> Dictionary:
	return {
		"requesting_clan": requesting_clan,
		"harboring_clan": harboring_clan,
		"fugitive_name": fugitive_name,
		"crime_type": crime_type,
		"topic_tier": TopicData.Tier.TIER_4,
		"topic_title": "%s requests extradition of %s from %s" % [
			requesting_clan, fugitive_name, harboring_clan
		],
	}


# -- Harboring Lord Decision (s11.3.16c) -----

const COOPERATION_THRESHOLD: int = 0

const DISPOSITION_COOPERATION: Dictionary = {
	"friend_or_above": 20,
	"neutral": 0,
	"rival_or_below": -20,
}

const USEFULNESS_SCORES: Dictionary = {
	"none": 0,
	"competent_needed": -15,
	"valuable_intelligence": -25,
}

const LEVERAGE_SCORES: Dictionary = {
	"bargaining_chip": -20,
	"no_value": 0,
}

const CRIME_SEVERITY_COOPERATION: Dictionary = {
	TopicData.Tier.TIER_4: 0,
	TopicData.Tier.TIER_3: -5,
	TopicData.Tier.TIER_2: -15,
	TopicData.Tier.TIER_1: -30,
}

const FUGITIVE_STATUS_COOPERATION: Dictionary = {
	1: 0,
	2: 0,
	3: -5,
	4: -5,
	5: -15,
}

const PERSONALITY_BASE_BUSHIDO: Dictionary = {
	Enums.BushidoVirtue.GI: 30,
	Enums.BushidoVirtue.MEIYO: 20,
	Enums.BushidoVirtue.CHUGI: 10,
	Enums.BushidoVirtue.JIN: 10,
	Enums.BushidoVirtue.REI: 15,
	Enums.BushidoVirtue.MAKOTO: 10,
	Enums.BushidoVirtue.YU: 0,
}

const PERSONALITY_BASE_SHOURIDO: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: -20,
	Enums.ShouridoVirtue.KETSUI: 0,
	Enums.ShouridoVirtue.DOSATSU: -10,
	Enums.ShouridoVirtue.CHISHIKI: -10,
	Enums.ShouridoVirtue.KANPEKI: 10,
	Enums.ShouridoVirtue.KYORYOKU: -15,
	Enums.ShouridoVirtue.ISHI: -15,
}


static func evaluate_extradition(
	harboring_lord: L5RCharacterData,
	requesting_clan: String,
	fugitive_status: float,
	crime_severity_tier: int,
	fugitive_usefulness: String,
	leverage_value: String,
) -> Dictionary:
	var disposition: int = harboring_lord.disposition_values.get(
		requesting_clan.hash(), 0
	)

	var disp_score: int = 0
	if disposition >= 31:
		disp_score = DISPOSITION_COOPERATION["friend_or_above"]
	elif disposition <= -11:
		disp_score = DISPOSITION_COOPERATION["rival_or_below"]

	var usefulness_score: int = USEFULNESS_SCORES.get(fugitive_usefulness, 0)
	var leverage_score: int = LEVERAGE_SCORES.get(leverage_value, 0)
	var severity_score: int = CRIME_SEVERITY_COOPERATION.get(crime_severity_tier, 0)

	var status_bracket: int = clampi(int(fugitive_status), 1, 5)
	var status_score: int = FUGITIVE_STATUS_COOPERATION.get(status_bracket, 0)

	var personality_score: int = _get_personality_score(harboring_lord)

	var total: int = (
		disp_score + usefulness_score + leverage_score +
		severity_score + status_score + personality_score
	)

	var cooperates: bool = total >= COOPERATION_THRESHOLD

	return {
		"total_score": total,
		"cooperates": cooperates,
		"disposition_score": disp_score,
		"usefulness_score": usefulness_score,
		"leverage_score": leverage_score,
		"severity_score": severity_score,
		"status_score": status_score,
		"personality_score": personality_score,
	}


static func _get_personality_score(lord: L5RCharacterData) -> int:
	if lord.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return PERSONALITY_BASE_SHOURIDO.get(lord.shourido_virtue, 0)
	return PERSONALITY_BASE_BUSHIDO.get(lord.bushido_virtue, 0)


# -- Response Options (s11.3.16d) -----

enum ExtraditionResponse {
	COOPERATE,
	NEGOTIATE,
	REFUSE,
	DENY_KNOWLEDGE,
}


static func get_cooperation_consequences(crime_severity_tier: int) -> Dictionary:
	var disp_gain: int = 5
	if crime_severity_tier <= TopicData.Tier.TIER_2:
		disp_gain = 10

	return {
		"response": ExtraditionResponse.COOPERATE,
		"fugitive_returned": true,
		"disposition_gain": disp_gain,
		"topic_resolved": true,
	}


static func get_negotiate_consequences() -> Dictionary:
	return {
		"response": ExtraditionResponse.NEGOTIATE,
		"fugitive_returned": false,
		"demands_concession": true,
		"topic_remains_active": true,
		"favored_by_seigyo": true,
	}


static func get_refusal_consequences(crime_severity_tier: int) -> Dictionary:
	var disp_hit: int = -10
	if crime_severity_tier <= TopicData.Tier.TIER_2:
		disp_hit = -20

	return {
		"response": ExtraditionResponse.REFUSE,
		"fugitive_returned": false,
		"disposition_hit": disp_hit,
		"topic_escalates": true,
		"escalated_topic_tier": TopicData.Tier.TIER_3,
	}


static func get_deny_knowledge_consequences(
	fugitive_status: float,
	requesting_clan_has_intel: bool,
) -> Dictionary:
	var viable: bool = fugitive_status < 3.0 and not requesting_clan_has_intel

	if not viable:
		var refusal := get_refusal_consequences(TopicData.Tier.TIER_3)
		refusal["denial_transparent"] = true
		refusal["additional_disposition_hit"] = -5
		return refusal

	return {
		"response": ExtraditionResponse.DENY_KNOWLEDGE,
		"fugitive_returned": false,
		"viable": true,
		"topic_stalls": true,
		"requires_further_intelligence": true,
	}


static func select_response(
	evaluation: Dictionary,
	lord: L5RCharacterData,
	fugitive_status: float,
) -> ExtraditionResponse:
	if evaluation["cooperates"]:
		return ExtraditionResponse.COOPERATE

	if lord.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return ExtraditionResponse.NEGOTIATE

	if fugitive_status < 3.0 and lord.bushido_virtue != Enums.BushidoVirtue.GI:
		return ExtraditionResponse.DENY_KNOWLEDGE

	var personality_aggressive: bool = (
		lord.shourido_virtue == Enums.ShouridoVirtue.ISHI or
		lord.shourido_virtue == Enums.ShouridoVirtue.KYORYOKU
	)
	if personality_aggressive:
		return ExtraditionResponse.REFUSE

	return ExtraditionResponse.NEGOTIATE


# -- Escalation (s11.3.16e) -----

const IMPERIAL_WARRANT_SEVERITY_THRESHOLD: int = TopicData.Tier.TIER_2


static func can_request_imperial_warrant(crime_severity_tier: int) -> bool:
	return crime_severity_tier <= IMPERIAL_WARRANT_SEVERITY_THRESHOLD


static func evaluate_imperial_warrant_compliance(
	lord: L5RCharacterData,
) -> Dictionary:
	if lord.bushido_virtue == Enums.BushidoVirtue.GI:
		return {"complies": true, "reason": "gi_principle"}
	if lord.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		return {"complies": true, "reason": "duty_to_emperor"}

	if lord.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return {"complies": false, "reason": "calculates_benefit"}
	if lord.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		return {"complies": false, "reason": "will_does_not_yield"}

	return {"complies": true, "reason": "imperial_authority"}


static func get_covert_extraction_risk() -> Dictionary:
	return {
		"sovereignty_violation": true,
		"topic_tier_if_caught": TopicData.Tier.TIER_3,
		"topic_title_template": "%s agents operating illegally in %s territory",
		"disposition_hit_if_caught": -20,
		"uses_stealth_mechanics": true,
	}


static func get_standing_warrant_consequences() -> Dictionary:
	return {
		"fugitive_remains_free": true,
		"warrant_persists": true,
		"arrest_on_return": true,
		"topic_persists_low_momentum": true,
	}
