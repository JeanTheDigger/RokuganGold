class_name DefenseHearingSystem
## Defense mechanics between accused and verdict per GDD s11.3.8c, s11.3.9f.
## Covers: trial by combat eligibility, champion substitution, political
## intervention, re-accusation protection, and disposition consequences.


# -- Trial by Combat (s11.3.9f) -----

const TRIAL_BY_COMBAT_EVIDENCE_WIPE: bool = true
const RE_ACCUSATION_NEW_EVIDENCE_MINIMUM: int = 20


enum TrialByCombatOutcome {
	ACCUSED_WINS,
	ACCUSED_LOSES,
	ACCUSER_DECLINES,
}


static func can_demand_trial_by_combat(
	accused: L5RCharacterData,
	crime_type: int,
) -> bool:
	if CharacterStats.is_dead(accused):
		return false
	if crime_type == Enums.CrimeType.MAHO:
		return false
	return true


static func get_trial_by_combat_result(
	outcome: TrialByCombatOutcome,
	victim_status: float,
) -> Dictionary:
	match outcome:
		TrialByCombatOutcome.ACCUSED_WINS:
			var disp_hit: int = _get_acquittal_disposition_hit(victim_status)
			return {
				"case_cleared": true,
				"evidence_wiped": true,
				"no_re_accusation": true,
				"victim_clan_disposition_hit": disp_hit,
				"divine_judgment": true,
			}
		TrialByCombatOutcome.ACCUSED_LOSES:
			return {
				"case_cleared": true,
				"accused_dead": true,
				"divine_judgment": true,
			}
		TrialByCombatOutcome.ACCUSER_DECLINES:
			return {
				"case_cleared": true,
				"evidence_wiped": true,
				"no_re_accusation": true,
				"accuser_implicit_agreement": true,
			}
		_:
			return {}


static func _get_acquittal_disposition_hit(victim_status: float) -> int:
	if victim_status >= 6.0:
		return -30
	if victim_status >= 4.0:
		return -20
	if victim_status >= 2.0:
		return -10
	return -5


# -- Champion Substitution (s11.3.9f) -----

static func can_appoint_champion(_accused: L5RCharacterData) -> bool:
	# s11.3.9f: either side may appoint a champion regardless of school type.
	return true


static func get_champion_political_cost() -> Dictionary:
	return {
		"political_capital_spent": true,
		"perceived_as_hiding": true,
	}


# -- Political Intervention -----

enum InterventionType {
	PARDON,
	COMMUTE,
	DISMISS_CHARGES,
}


static func can_intervene(
	intervener_status: float,
	lord_status: float,
) -> bool:
	return intervener_status > lord_status


static func get_intervention_cost(
	intervention_type: InterventionType,
) -> Dictionary:
	match intervention_type:
		InterventionType.PARDON:
			return {
				"honor_cost": -0.3,
				"topic_tier": 3,
				"undermines_authority": true,
			}
		InterventionType.COMMUTE:
			return {
				"honor_cost": -0.1,
				"topic_tier": 4,
				"undermines_authority": false,
			}
		InterventionType.DISMISS_CHARGES:
			return {
				"honor_cost": -0.5,
				"topic_tier": 2,
				"undermines_authority": true,
			}
		_:
			return {}


# -- Re-Accusation Protection (s11.3.8c) -----

static func can_re_accuse(
	new_evidence_since_acquittal: int,
) -> bool:
	return new_evidence_since_acquittal >= RE_ACCUSATION_NEW_EVIDENCE_MINIMUM


static func get_false_persecution_cost() -> Dictionary:
	return {
		"lord_honor_loss": -0.3,
		"vassal_disposition_loss_from_all": -10,
	}


# -- Sincerity Defense (s11.3.8c) -----

static func resolve_sincerity_defense(
	sincerity_roll: int,
	testimony_weight: int,
	evidence_total: int,
) -> Dictionary:
	var defense_total: int = sincerity_roll + testimony_weight
	var defense_succeeded: bool = defense_total >= evidence_total

	if defense_succeeded:
		return {
			"defense_succeeded": true,
			"evidence_halved_to": evidence_total / 2,
			"political_shield_active": true,
		}
	return {
		"defense_succeeded": false,
		"proceed_to_judgment": true,
	}


# -- NPC Decision: Should Demand Trial by Combat -----

static func should_demand_trial(
	accused: L5RCharacterData,
	testimony_weight: int,
	evidence_total: int,
) -> bool:
	if testimony_weight >= evidence_total:
		return false
	if accused.school_type == Enums.SchoolType.BUSHI:
		return true
	if accused.bushido_virtue == Enums.BushidoVirtue.YU:
		return true
	return false
