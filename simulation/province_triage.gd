class_name ProvinceTriage
## Multi-target comparative evaluation per GDD s55.9.
## Scores each province to determine which needs attention most.
## Used by lord-tier NPCs to prioritize across multiple provinces.


class TriageResult:
	var province_id: int = -1
	var score: float = 0.0
	var recommended_need: String = ""
	var priority: int = 1


const SCORE_ACTIVE_CRISIS: float = 100.0
const SCORE_ACTIVE_INSURGENCY: float = 80.0
const SCORE_BROKEN_STABILITY: float = 60.0
const SCORE_VOLATILE_STABILITY: float = 30.0
const SCORE_RESTLESS_STABILITY: float = 10.0
const SCORE_GARRISON_DEFICIT: float = 20.0
const SCORE_STALE_INFORMATION: float = 25.0


static func score_province(ps: NPCDataStructures.ProvinceStatus) -> float:
	var score: float = 0.0

	if ps.active_crisis_id >= 0:
		score += SCORE_ACTIVE_CRISIS
	if ps.active_insurgency_id >= 0:
		score += SCORE_ACTIVE_INSURGENCY
	if ps.stability <= 25.0:
		score += SCORE_BROKEN_STABILITY
	elif ps.stability <= 50.0:
		score += SCORE_VOLATILE_STABILITY
	elif ps.stability <= 75.0:
		score += SCORE_RESTLESS_STABILITY
	if ps.garrison_pu < 1:
		score += SCORE_GARRISON_DEFICIT
	if ps.confidence == 0:
		score += SCORE_STALE_INFORMATION

	return score


static func triage_provinces(
	province_statuses: Array,
) -> Array[TriageResult]:
	var results: Array[TriageResult] = []

	for ps: Variant in province_statuses:
		if not ps is NPCDataStructures.ProvinceStatus:
			continue
		var p: NPCDataStructures.ProvinceStatus = ps as NPCDataStructures.ProvinceStatus
		var result := TriageResult.new()
		result.province_id = p.province_id
		result.score = score_province(p)
		result.recommended_need = _determine_need(p)
		result.priority = _determine_priority(p)
		results.append(result)

	results.sort_custom(func(a: TriageResult, b: TriageResult) -> bool:
		return a.score > b.score
	)

	return results


static func get_worst_province(
	province_statuses: Array,
) -> TriageResult:
	var results: Array[TriageResult] = triage_provinces(province_statuses)
	if results.is_empty():
		return TriageResult.new()
	return results[0]


static func get_top_provinces(
	province_statuses: Array,
	count: int = 2,
) -> Array[TriageResult]:
	var results: Array[TriageResult] = triage_provinces(province_statuses)
	var top: Array[TriageResult] = []
	for i: int in range(mini(count, results.size())):
		if results[i].score > 0.0:
			top.append(results[i])
	return top


static func _determine_need(ps: NPCDataStructures.ProvinceStatus) -> String:
	if ps.active_crisis_id >= 0:
		return "DEFEND_PROVINCE"
	if ps.confidence == 0:
		return "INVESTIGATE_THREAT"
	if ps.stability <= 50.0:
		return "PATROL_PROVINCE"
	return "REST"


static func _determine_priority(ps: NPCDataStructures.ProvinceStatus) -> int:
	if ps.active_crisis_id >= 0:
		return 3
	if ps.active_insurgency_id >= 0:
		return 3
	if ps.stability <= 25.0:
		return 3
	if ps.confidence == 0:
		return 2
	if ps.stability <= 50.0:
		return 2
	return 1
