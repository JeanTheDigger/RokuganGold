class_name UnsanctionedKillingSystem
## Unsanctioned killing of a samurai per GDD s11.3.9.
## Three severity tiers, status modifiers, trial by combat, self-defense,
## wartime exception, conspiracy, attempted murder.


enum KillingTier {
	UNSANCTIONED_DUEL_DEATH,
	OPEN_KILLING,
	COVERT_KILLING,
}

enum TrialOutcome {
	ACCUSED_WINS,
	ACCUSED_LOSES,
}

const HONOR_LOSS: Dictionary = {
	KillingTier.UNSANCTIONED_DUEL_DEATH: -0.3,
	KillingTier.OPEN_KILLING: -1.0,
	KillingTier.COVERT_KILLING: -2.0,
}

const GLORY_LOSS: Dictionary = {
	KillingTier.UNSANCTIONED_DUEL_DEATH: 0.0,
	KillingTier.OPEN_KILLING: -0.5,
	KillingTier.COVERT_KILLING: -1.0,
}

const INFAMY_GAIN: Dictionary = {
	KillingTier.UNSANCTIONED_DUEL_DEATH: 0.0,
	KillingTier.OPEN_KILLING: 1.0,
	KillingTier.COVERT_KILLING: 1.0,
}

const TOPIC_TIER: Dictionary = {
	KillingTier.UNSANCTIONED_DUEL_DEATH: 4,
	KillingTier.OPEN_KILLING: 3,
	KillingTier.COVERT_KILLING: 3,
}

const HIGH_STATUS_THRESHOLD: float = 5.0
const ATTEMPTED_MURDER_HONOR_OPEN: float = -1.0
const ATTEMPTED_MURDER_HONOR_COVERT: float = -2.0


static func classify_killing(
	method_tier: KillingTier,
	attacker_status: float,
	victim_status: float,
) -> Dictionary:
	var effective_tier: KillingTier = method_tier
	var status_escalated: bool = false

	if attacker_status < victim_status:
		if method_tier == KillingTier.UNSANCTIONED_DUEL_DEATH:
			effective_tier = KillingTier.OPEN_KILLING
			status_escalated = true
		elif method_tier == KillingTier.OPEN_KILLING:
			effective_tier = KillingTier.COVERT_KILLING
			status_escalated = true

	return {
		"method_tier": method_tier,
		"effective_tier": effective_tier,
		"status_escalated": status_escalated,
		"killing_upward": attacker_status < victim_status,
		"killing_downward": attacker_status > victim_status,
	}


static func get_consequences(
	effective_tier: KillingTier,
	victim_status: float,
	is_public: bool,
) -> Dictionary:
	var honor_loss: float = HONOR_LOSS[effective_tier]
	var glory_loss: float = GLORY_LOSS[effective_tier]
	var infamy: float = 0.0
	var topic_tier: int = TOPIC_TIER[effective_tier]

	match effective_tier:
		KillingTier.UNSANCTIONED_DUEL_DEATH:
			infamy = 0.0
		KillingTier.OPEN_KILLING:
			infamy = INFAMY_GAIN[effective_tier] if is_public else 0.0
		KillingTier.COVERT_KILLING:
			infamy = INFAMY_GAIN[effective_tier]

	if effective_tier == KillingTier.COVERT_KILLING and victim_status >= HIGH_STATUS_THRESHOLD:
		topic_tier = 2

	var seppuku_offered: bool = effective_tier != KillingTier.UNSANCTIONED_DUEL_DEATH
	var capital: bool = effective_tier == KillingTier.COVERT_KILLING
	var leniency_possible: bool = effective_tier == KillingTier.OPEN_KILLING

	return {
		"honor_loss": honor_loss,
		"glory_loss": glory_loss,
		"infamy_gain": infamy,
		"topic_tier": topic_tier,
		"seppuku_offered": seppuku_offered,
		"capital": capital,
		"leniency_possible": leniency_possible,
	}


static func get_punishment_range(effective_tier: KillingTier) -> Dictionary:
	match effective_tier:
		KillingTier.UNSANCTIONED_DUEL_DEATH:
			return {
				"min": "house_arrest",
				"max": "recompense",
				"seppuku": false,
				"exile_possible": false,
			}
		KillingTier.OPEN_KILLING:
			return {
				"min": "exile",
				"max": "seppuku",
				"seppuku": true,
				"exile_possible": true,
			}
		KillingTier.COVERT_KILLING:
			return {
				"min": "seppuku",
				"max": "execution",
				"seppuku": true,
				"exile_possible": false,
			}
	return {}


static func is_self_defense(
	attacker_acted_first: bool,
	has_witnesses: bool,
	has_zone_log_evidence: bool,
) -> Dictionary:
	var proved: bool = false
	var evidence_source: String = "none"

	if attacker_acted_first and has_zone_log_evidence:
		proved = true
		evidence_source = "zone_event_log"
	elif attacker_acted_first and has_witnesses:
		proved = true
		evidence_source = "witness_testimony"

	return {
		"self_defense_proved": proved,
		"evidence_source": evidence_source,
		"no_crime": proved,
	}


static func is_wartime_exception(
	clans_at_war: bool,
	is_battlefield: bool,
	is_prisoner: bool,
) -> Dictionary:
	if not clans_at_war:
		return {"exception_applies": false, "reason": "not_at_war"}

	if is_battlefield:
		return {"exception_applies": true, "reason": "battlefield_killing", "no_crime": true}

	if is_prisoner:
		return {
			"exception_applies": true,
			"reason": "prisoner_killing",
			"no_crime": true,
			"honor_loss": -0.5,
			"infamy_if_public": true,
		}

	return {"exception_applies": true, "reason": "wartime_standing_permission", "no_crime": true}


static func resolve_trial_by_combat(
	outcome: TrialOutcome,
	victim_status: float,
) -> Dictionary:
	if outcome == TrialOutcome.ACCUSED_WINS:
		var disposition_hit: int = -10
		if victim_status >= HIGH_STATUS_THRESHOLD:
			disposition_hit = -30
		elif victim_status >= 3.0:
			disposition_hit = -20

		return {
			"case_cleared": true,
			"accused_alive": true,
			"evidence_wiped": true,
			"disposition_hit_from_victim_clan": disposition_hit,
			"cannot_reaccuse_same_evidence": true,
		}

	return {
		"case_cleared": true,
		"accused_alive": false,
		"divine_judgment": true,
	}


static func evaluate_attempted_murder(
	method_tier: KillingTier,
	attacker_status: float,
	victim_status: float,
) -> Dictionary:
	var honor_loss: float = ATTEMPTED_MURDER_HONOR_OPEN
	if method_tier == KillingTier.COVERT_KILLING:
		honor_loss = ATTEMPTED_MURDER_HONOR_COVERT

	var standard_punishment: String = "exile"
	if attacker_status < victim_status:
		standard_punishment = "capital"

	return {
		"honor_loss": honor_loss,
		"standard_punishment": standard_punishment,
		"seppuku_may_be_demanded": true,
		"escalated_by_status": attacker_status < victim_status,
	}


static func is_ronin_killing_prosecutable(
	victim_has_patron: bool,
	victim_has_powerful_friends: bool,
) -> bool:
	return victim_has_patron or victim_has_powerful_friends


static func evaluate_conspiracy(
	method_tier: KillingTier,
	orderer_status: float,
	victim_status: float,
) -> Dictionary:
	var classification := classify_killing(method_tier, orderer_status, victim_status)
	var consequences := get_consequences(
		classification["effective_tier"], victim_status, false
	)
	consequences["is_conspiracy"] = true
	consequences["same_tier_as_executioner"] = true
	return consequences


static func is_manslaughter(is_accidental: bool) -> Dictionary:
	if is_accidental:
		return {
			"no_crime": true,
			"legal_status_progression": false,
			"disposition_hit_applies": true,
		}
	return {"no_crime": false}


static func get_jurisdiction(
	attacker_clan: String,
	victim_clan: String,
) -> Dictionary:
	if attacker_clan == victim_clan:
		return {
			"type": "same_clan",
			"investigating_clan": attacker_clan,
			"can_escalate_to_emerald": false,
		}
	return {
		"type": "cross_clan",
		"investigating_clan": victim_clan,
		"observer_clan": attacker_clan,
		"can_escalate_to_emerald": true,
	}


static func get_cross_clan_disposition_hit(
	cooperated: bool,
	effective_tier: KillingTier,
) -> int:
	var base_hit: int = -10
	if effective_tier == KillingTier.OPEN_KILLING:
		base_hit = -15
	elif effective_tier == KillingTier.COVERT_KILLING:
		base_hit = -25

	if cooperated:
		return base_hit / 2
	return base_hit
