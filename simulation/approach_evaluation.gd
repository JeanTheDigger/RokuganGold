class_name ApproachEvaluation
## Action retry and approach evaluation per GDD s55.30.
## Three components:
##   1. Measurement pressure — detects high-roll-no-effect pattern
##   2. Approach assessment — tags actions as effective/capped/ineffective
##   3. Penalty decay — clears old penalties over seasons


# =============================================================================
# 55.30.2 — Measurement Thresholds
# =============================================================================

const SOCIAL_MEASUREMENT_THRESHOLD: int = 2
const COVERT_MEASUREMENT_THRESHOLD: int = 3

const SOCIAL_ACTIONS: Array[String] = [
	"CHARM", "PERSUADE", "INTIMIDATE", "PUBLIC_INSULT",
	"DELIVER_GIFT", "GOSSIP", "IMPRESS", "LISTEN_REFLECT",
	"OFFER_FAVOR", "PERFORM_FOR", "DISCLOSE",
]

const COVERT_ACTIONS: Array[String] = [
	"BRIBE_FOR_INFO", "EAVESDROP", "PROBE", "SEARCH_QUARTERS",
]

const MEASUREMENT_ACTIONS: Array[String] = ["READ_CHARACTER", "PROBE"]

const MEASUREMENT_BONUS: int = 15
const APPROACH_PENALTY: int = -15
const ALTERNATIVE_BONUS: int = 10

const HIGH_ROLL_MARGIN: int = 5


static func get_measurement_threshold(action_id: String) -> int:
	if action_id in SOCIAL_ACTIONS:
		return SOCIAL_MEASUREMENT_THRESHOLD
	if action_id in COVERT_ACTIONS:
		return COVERT_MEASUREMENT_THRESHOLD
	return -1


# =============================================================================
# 55.30.2 — Measurement Pressure Check
# =============================================================================

static func get_recent_actions(
	action_log: Array[Dictionary],
	character_id: int,
	target_npc_id: int,
	action_id: String,
	current_season: int,
) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry: Dictionary in action_log:
		if entry.get("character_id", -1) != character_id:
			continue
		if entry.get("target_npc_id", -1) != target_npc_id:
			continue
		if entry.get("action_id", "") != action_id:
			continue
		if entry.get("season", -1) != current_season:
			continue
		matches.append(entry)
	return matches


static func check_measurement_needed(
	action_log: Array[Dictionary],
	character_id: int,
	target_npc_id: int,
	action_id: String,
	current_season: int,
) -> bool:
	var threshold: int = get_measurement_threshold(action_id)
	if threshold < 0:
		return false

	var recent: Array[Dictionary] = get_recent_actions(
		action_log, character_id, target_npc_id, action_id, current_season
	)

	var high_roll_count: int = 0
	var any_observable: bool = false
	for entry: Dictionary in recent:
		var roll: int = entry.get("roll_result", 0)
		var tn: int = entry.get("tn", 0)
		if roll >= tn + HIGH_ROLL_MARGIN:
			high_roll_count += 1
		if entry.get("observable_effect", false):
			any_observable = true

	return high_roll_count >= threshold and not any_observable


# =============================================================================
# 55.30.3 — Approach Assessment Tags
# =============================================================================

enum AssessmentTag {
	NONE,
	APPROACH_EFFECTIVE,
	APPROACH_CAPPED,
	APPROACH_INEFFECTIVE,
}

const CHARM_CEILING: int = 40

const ACTION_CEILINGS: Dictionary = {
	"CHARM": 40,
	"DELIVER_GIFT": 40,
	"LISTEN_REFLECT": 40,
	"OFFER_FAVOR": 40,
	"PERFORM_FOR": 40,
}

const MEANINGFUL_PROGRESS_THRESHOLD: int = 3


static func evaluate_approach(
	action_id: String,
	_target_npc_id: int,
	current_disposition: int,
	disposition_at_start: int,
) -> AssessmentTag:
	if action_id in ACTION_CEILINGS:
		var ceiling: int = ACTION_CEILINGS[action_id]
		if current_disposition >= ceiling:
			return AssessmentTag.APPROACH_CAPPED

	var delta: int = current_disposition - disposition_at_start
	if delta >= MEANINGFUL_PROGRESS_THRESHOLD:
		return AssessmentTag.APPROACH_EFFECTIVE

	return AssessmentTag.APPROACH_INEFFECTIVE


# =============================================================================
# 55.30.3 — Approach Penalty Registry
# =============================================================================

static func record_penalty(
	penalties: Array[Dictionary],
	character_id: int,
	target_npc_id: int,
	action_id: String,
	tag: AssessmentTag,
	season_recorded: int,
) -> void:
	for p: Dictionary in penalties:
		if (p.get("character_id", -1) == character_id
			and p.get("target_npc_id", -1) == target_npc_id
			and p.get("action_id", "") == action_id):
			p["tag"] = tag
			p["season_recorded"] = season_recorded
			return

	penalties.append({
		"character_id": character_id,
		"target_npc_id": target_npc_id,
		"action_id": action_id,
		"tag": tag,
		"season_recorded": season_recorded,
	})


static func get_penalty(
	penalties: Array[Dictionary],
	character_id: int,
	target_npc_id: int,
	action_id: String,
	current_season: int,
) -> int:
	for p: Dictionary in penalties:
		if (p.get("character_id", -1) != character_id
			or p.get("target_npc_id", -1) != target_npc_id
			or p.get("action_id", "") != action_id):
			continue
		var tag: int = p.get("tag", AssessmentTag.NONE)
		if tag == AssessmentTag.NONE or tag == AssessmentTag.APPROACH_EFFECTIVE:
			continue
		var seasons_elapsed: int = current_season - p.get("season_recorded", 0)
		if seasons_elapsed <= 0:
			return APPROACH_PENALTY
		elif seasons_elapsed == 1:
			return int(APPROACH_PENALTY / 2)
		else:
			return 0
	return 0


static func get_alternative_bonus(
	penalties: Array[Dictionary],
	character_id: int,
	target_npc_id: int,
	current_season: int,
) -> int:
	for p: Dictionary in penalties:
		if (p.get("character_id", -1) != character_id
			or p.get("target_npc_id", -1) != target_npc_id):
			continue
		var tag: int = p.get("tag", AssessmentTag.NONE)
		if tag != AssessmentTag.APPROACH_CAPPED and tag != AssessmentTag.APPROACH_INEFFECTIVE:
			continue
		var seasons_elapsed: int = current_season - p.get("season_recorded", 0)
		if seasons_elapsed < 2:
			return ALTERNATIVE_BONUS
	return 0


# =============================================================================
# 55.30.3 — Penalty Decay
# =============================================================================

static func decay_penalties(
	penalties: Array[Dictionary],
	current_season: int,
) -> int:
	var removed: int = 0
	var i: int = penalties.size() - 1
	while i >= 0:
		var seasons_elapsed: int = current_season - penalties[i].get("season_recorded", 0)
		if seasons_elapsed >= 2:
			penalties.remove_at(i)
			removed += 1
		i -= 1
	return removed


# =============================================================================
# 55.30.2 — Phase 5 Scoring Modifier
# =============================================================================

static func get_scoring_modifier(
	action_id: String,
	character_id: int,
	target_npc_id: int,
	action_log: Array[Dictionary],
	penalties: Array[Dictionary],
	current_season: int,
	shourido_virtue: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> int:
	if action_id in MEASUREMENT_ACTIONS:
		var needs_measurement: bool = false
		for social_action: String in SOCIAL_ACTIONS:
			if check_measurement_needed(
				action_log, character_id, target_npc_id,
				social_action, current_season
			):
				needs_measurement = true
				break
		if not needs_measurement:
			for covert_action: String in COVERT_ACTIONS:
				if check_measurement_needed(
					action_log, character_id, target_npc_id,
					covert_action, current_season
				):
					needs_measurement = true
					break
		if needs_measurement:
			return MEASUREMENT_BONUS

	# s57.4: Ishi NPCs ignore approach penalties entirely
	if shourido_virtue == Enums.ShouridoVirtue.ISHI:
		return 0

	var penalty: int = get_penalty(
		penalties, character_id, target_npc_id, action_id, current_season
	)
	if penalty < 0:
		return penalty

	var alt_bonus: int = get_alternative_bonus(
		penalties, character_id, target_npc_id, current_season
	)
	if alt_bonus > 0 and action_id not in _get_penalized_actions(penalties, character_id, target_npc_id, current_season):
		return alt_bonus

	return 0


static func _get_penalized_actions(
	penalties: Array[Dictionary],
	character_id: int,
	target_npc_id: int,
	current_season: int,
) -> Array[String]:
	var result: Array[String] = []
	for p: Dictionary in penalties:
		if (p.get("character_id", -1) != character_id
			or p.get("target_npc_id", -1) != target_npc_id):
			continue
		var seasons_elapsed: int = current_season - p.get("season_recorded", 0)
		if seasons_elapsed >= 2:
			continue
		var tag: int = p.get("tag", AssessmentTag.NONE)
		if tag == AssessmentTag.APPROACH_CAPPED or tag == AssessmentTag.APPROACH_INEFFECTIVE:
			result.append(p.get("action_id", ""))
	return result
