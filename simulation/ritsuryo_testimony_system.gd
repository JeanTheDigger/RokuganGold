class_name RitsuryoTestimonySystem
## Honor and Infamy in legal proceedings per GDD s11.3.10.
## The Ritsuryo Principle: a samurai's word carries weight proportional to
## their Honor. Testimony weight = (Honor Rank × 5) - (Infamy × 3), floor 0.
## Applies to accused denial, accuser testimony, and contested claims.


# -- Testimony Weight Formula (s11.3.10) -----

const HONOR_WEIGHT_MULTIPLIER: int = 5
const INFAMY_PENALTY_MULTIPLIER: int = 3
const TESTIMONY_WEIGHT_FLOOR: int = 0


static func get_testimony_weight(honor_rank: int, infamy: float) -> int:
	var weight: int = (honor_rank * HONOR_WEIGHT_MULTIPLIER) - int(infamy * float(INFAMY_PENALTY_MULTIPLIER))
	return maxi(weight, TESTIMONY_WEIGHT_FLOOR)


# -- Accused Denial (s11.3.10) -----

static func get_accused_denial_weight(accused: L5RCharacterData) -> int:
	return get_testimony_weight(int(accused.honor), accused.infamy)


# -- Accuser Testimony (s11.3.10) -----

static func get_accuser_testimony_weight(accuser: L5RCharacterData) -> int:
	return get_testimony_weight(int(accuser.honor), accuser.infamy)


# -- Contested Testimony (s11.3.10, s11.3.11h) -----

enum ContestedOutcome {
	CLAIMANT_WINS,
	DENIER_WINS,
	TIED,
}


static func resolve_contested_testimony(
	claimant_honor_rank: int,
	claimant_infamy: float,
	denier_honor_rank: int,
	denier_infamy: float,
) -> Dictionary:
	var claimant_weight: int = get_testimony_weight(claimant_honor_rank, claimant_infamy)
	var denier_weight: int = get_testimony_weight(denier_honor_rank, denier_infamy)

	var outcome: ContestedOutcome
	if claimant_weight > denier_weight:
		outcome = ContestedOutcome.CLAIMANT_WINS
	elif denier_weight > claimant_weight:
		outcome = ContestedOutcome.DENIER_WINS
	else:
		outcome = ContestedOutcome.TIED

	return {
		"outcome": outcome,
		"claimant_weight": claimant_weight,
		"denier_weight": denier_weight,
		"weight_difference": claimant_weight - denier_weight,
	}


# -- Prosecution vs Defense -----

static func can_convict_on_testimony_alone(
	evidence_total: int,
	accused_denial_weight: int,
) -> bool:
	return evidence_total > accused_denial_weight


static func get_effective_evidence_after_denial(
	evidence_total: int,
	accused_denial_weight: int,
) -> int:
	return maxi(evidence_total - accused_denial_weight, 0)


# -- Low-Honor Thresholds (s11.3.10) -----

const LOW_HONOR_THRESHOLD: int = 3


static func is_low_honor(honor_rank: int) -> bool:
	return honor_rank <= LOW_HONOR_THRESHOLD


static func is_testimony_worthless(honor_rank: int, infamy: float) -> bool:
	return get_testimony_weight(honor_rank, infamy) <= 0


# -- Magistrate Conviction Risk (s11.3.9e) -----

static func get_conviction_risk(
	accused_honor_rank: int,
	accused_infamy: float,
	evidence_total: int,
) -> Dictionary:
	var denial_weight: int = get_testimony_weight(accused_honor_rank, accused_infamy)
	var can_convict: bool = evidence_total > denial_weight
	var margin: int = evidence_total - denial_weight
	var risky: bool = accused_honor_rank >= 7 and margin < 20

	return {
		"can_convict": can_convict,
		"margin": margin,
		"high_honor_risk": risky,
		"denial_weight": denial_weight,
	}


# -- Trial by Combat Bypass (s11.3.10) -----

static func trial_by_combat_bypasses_testimony() -> bool:
	return true
