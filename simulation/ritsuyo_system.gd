class_name RitsuyoSystem
## Honor and Infamy in legal proceedings per GDD s11.3.10.
## Cross-cutting rule: calculates testimonial weight for any character
## acting as accused or accuser. Applies to ALL crime types in s11.3.


const HONOR_WEIGHT_MULTIPLIER: int = 5
const INFAMY_PENALTY_MULTIPLIER: int = 3


static func get_testimony_weight(character: L5RCharacterData) -> int:
	var honor_rank: int = HonorGlorySystem.get_honor_rank(character)
	var base_weight: int = honor_rank * HONOR_WEIGHT_MULTIPLIER
	var infamy_penalty: int = int(character.infamy) * INFAMY_PENALTY_MULTIPLIER
	return maxi(0, base_weight - infamy_penalty)


static func get_accused_testimony_weight(accused: L5RCharacterData) -> int:
	return get_testimony_weight(accused)


static func get_accuser_testimony_weight(accuser: L5RCharacterData) -> int:
	return get_testimony_weight(accuser)


static func get_testimonial_advantage(
	accuser: L5RCharacterData,
	accused: L5RCharacterData,
) -> int:
	return get_accuser_testimony_weight(accuser) - get_accused_testimony_weight(accused)


static func is_testimony_worthless(character: L5RCharacterData) -> bool:
	return get_testimony_weight(character) == 0


static func is_low_honor_accused(character: L5RCharacterData) -> bool:
	return HonorGlorySystem.get_honor_rank(character) <= 3


static func get_defense_strength(
	accused: L5RCharacterData,
	evidence_total: int,
) -> Dictionary:
	var testimony: int = get_accused_testimony_weight(accused)
	var net_evidence: int = evidence_total - testimony
	var can_deny_effectively: bool = testimony >= evidence_total
	return {
		"testimony_weight": testimony,
		"evidence_total": evidence_total,
		"net_evidence": net_evidence,
		"can_deny_effectively": can_deny_effectively,
	}


static func get_prosecution_strength(
	accuser: L5RCharacterData,
	evidence_total: int,
	accused: L5RCharacterData,
) -> Dictionary:
	var accuser_weight: int = get_accuser_testimony_weight(accuser)
	var accused_weight: int = get_accused_testimony_weight(accused)
	var effective_evidence: int = evidence_total + accuser_weight - accused_weight
	var structurally_credible: bool = accuser_weight >= accused_weight
	return {
		"accuser_testimony": accuser_weight,
		"accused_testimony": accused_weight,
		"raw_evidence": evidence_total,
		"effective_evidence": maxi(0, effective_evidence),
		"structurally_credible": structurally_credible,
	}
