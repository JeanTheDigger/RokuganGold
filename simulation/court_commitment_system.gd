class_name CourtCommitmentSystem
## Commitment Execution Bridge per GDD s16.4.
## Manages court-declared and edict-compelled commitments: creation,
## HONOR_COMMITMENT NeedType decomposition, fulfillment detection, and
## renege consequences.

const HONOR_COMMITMENT_BASE_PRIORITY: int = 95
const HONOR_COMMITMENT_CHUGI_PRIORITY: int = 100
const EDICT_RENEGE_HONOR_COST: float = -3.0
const RENEGE_DISPOSITION_PENALTY: int = -15


const COMMITMENT_TYPE_TO_ACTION: Dictionary = {
	"send_military_aid": "ORDER_DEPLOY",
	"send_supplies": "SHARE_SUPPLIES",
	"send_shugenja": "ASSIGN_VASSAL_OBJECTIVE",
	"send_magistrates": "ASSIGN_VASSAL_OBJECTIVE",
}

const FULFILLMENT_ACTIONS: Array[String] = [
	"ORDER_DEPLOY",
	"SHARE_SUPPLIES",
	"ASSIGN_VASSAL_OBJECTIVE",
]


# -- Factory -------------------------------------------------------------------

static func create_commitment(
	lord_id: int,
	topic_id: int,
	commitment_type: String,
	source: CourtCommitmentData.CommitmentSource,
	declared_at_ic_day: int,
	deadline_ic_day: int,
	resource_amount: int = -1,
) -> CourtCommitmentData:
	var c := CourtCommitmentData.new()
	c.lord_id = lord_id
	c.topic_id = topic_id
	c.commitment_type = commitment_type
	c.source = source
	c.declared_at_ic_day = declared_at_ic_day
	c.deadline_ic_day = deadline_ic_day
	c.resource_amount = resource_amount
	return c


static func create_edict_commitment(
	lord_id: int,
	topic_id: int,
	commitment_type: String,
	ic_day: int,
	deadline_ic_day: int,
	resource_amount: int = -1,
) -> CourtCommitmentData:
	return create_commitment(
		lord_id, topic_id, commitment_type,
		CourtCommitmentData.CommitmentSource.EDICT,
		ic_day, deadline_ic_day, resource_amount,
	)


# -- HONOR_COMMITMENT NeedType Decomposition -----------------------------------

static func get_priority(virtue: Enums.BushidoVirtue) -> int:
	if virtue == Enums.BushidoVirtue.CHUGI:
		return HONOR_COMMITMENT_CHUGI_PRIORITY
	return HONOR_COMMITMENT_BASE_PRIORITY


static func decompose_commitment(commitment: CourtCommitmentData) -> Dictionary:
	var action_id: String = COMMITMENT_TYPE_TO_ACTION.get(
		commitment.commitment_type, ""
	)
	if action_id.is_empty():
		return {"need_type": "HONOR_COMMITMENT", "action_id": "DO_NOTHING"}

	return {
		"need_type": "HONOR_COMMITMENT",
		"action_id": action_id,
		"topic_id": commitment.topic_id,
		"commitment_type": commitment.commitment_type,
		"resource_amount": commitment.resource_amount,
	}


static func should_deprioritize(
	virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
) -> bool:
	if shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return true
	if virtue == Enums.BushidoVirtue.MAKOTO:
		return false
	return false


static func get_renege_willingness(
	virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
) -> float:
	if shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return 0.0
	if virtue == Enums.BushidoVirtue.MAKOTO:
		return 0.0
	if virtue == Enums.BushidoVirtue.CHUGI:
		return 0.0
	return 0.0


# -- Fulfillment Detection (Seasonal) -----------------------------------------

static func check_fulfillment(
	commitment: CourtCommitmentData,
	action_log: Array,
) -> bool:
	if commitment.fulfilled:
		return true

	var ap_count: int = 0
	for entry: Dictionary in action_log:
		if entry.get("character_id", -1) != commitment.lord_id:
			continue
		var action: String = entry.get("action_id", "")
		if action in FULFILLMENT_ACTIONS:
			ap_count += 1

	commitment.ap_spent_toward = ap_count

	if commitment.resource_amount > 0:
		return _check_resource_fulfillment(commitment, action_log)

	return _check_dispatch_fulfillment(commitment, action_log)


static func _check_resource_fulfillment(
	commitment: CourtCommitmentData,
	action_log: Array,
) -> bool:
	var total_sent: int = 0
	for entry: Dictionary in action_log:
		if entry.get("character_id", -1) != commitment.lord_id:
			continue
		if entry.get("action_id", "") == "SHARE_SUPPLIES":
			total_sent += entry.get("amount", 0)
	return total_sent >= commitment.resource_amount


static func _check_dispatch_fulfillment(
	commitment: CourtCommitmentData,
	action_log: Array,
) -> bool:
	for entry: Dictionary in action_log:
		if entry.get("character_id", -1) != commitment.lord_id:
			continue
		var action: String = entry.get("action_id", "")
		if action == "ORDER_DEPLOY" or action == "ASSIGN_VASSAL_OBJECTIVE":
			if entry.get("fulfilled", false):
				return true
	return false


# -- Renege Detection (Seasonal) -----------------------------------------------

static func check_renege(
	commitment: CourtCommitmentData,
	current_ic_day: int,
) -> bool:
	if commitment.fulfilled:
		return false
	if current_ic_day < commitment.deadline_ic_day:
		return false
	return commitment.ap_spent_toward == 0


static func compute_renege_consequences(
	commitment: CourtCommitmentData,
	lord: L5RCharacterData,
) -> Dictionary:
	var base_honor: float = CrimeSystem.get_disloyalty_honor(lord)

	var result: Dictionary = {
		"honor_change": base_honor,
		"disposition_penalty": RENEGE_DISPOSITION_PENALTY,
		"topic_tier": TopicData.Tier.TIER_3,
		"topic_type": "renege",
		"topic_variant": "commitment_broken",
	}

	if commitment.source == CourtCommitmentData.CommitmentSource.EDICT:
		result["honor_change"] = base_honor + EDICT_RENEGE_HONOR_COST
		result["topic_tier"] = TopicData.Tier.TIER_3

	return result


# -- Good Faith Evaluation ----------------------------------------------------

static func evaluate_good_faith(
	commitment: CourtCommitmentData,
	current_ic_day: int,
) -> bool:
	if commitment.fulfilled:
		return true
	if current_ic_day < commitment.deadline_ic_day:
		return commitment.ap_spent_toward > 0
	return commitment.ap_spent_toward > 0


# -- Seasonal Processing ------------------------------------------------------

static func process_seasonal_commitments(
	commitments: Array,
	action_log: Array,
	current_ic_day: int,
	characters_by_id: Dictionary,
) -> Dictionary:
	var fulfilled_ids: Array = []
	var reneged: Array = []

	for i: int in range(commitments.size()):
		var c: CourtCommitmentData = commitments[i]
		if c.fulfilled:
			continue

		if check_fulfillment(c, action_log):
			c.fulfilled = true
			fulfilled_ids.append(i)
			continue

		c.good_faith = evaluate_good_faith(c, current_ic_day)

		if check_renege(c, current_ic_day):
			var lord: L5RCharacterData = characters_by_id.get(c.lord_id)
			if lord != null and not CharacterStats.is_dead(lord):
				var consequences: Dictionary = compute_renege_consequences(c, lord)
				consequences["lord_id"] = c.lord_id
				consequences["commitment_index"] = i
				consequences["topic_id"] = c.topic_id
				consequences["witness_ids"] = c.witness_ids.duplicate()
				reneged.append(consequences)

	return {
		"fulfilled_count": fulfilled_ids.size(),
		"fulfilled_indices": fulfilled_ids,
		"reneged": reneged,
	}


# -- Queries -------------------------------------------------------------------

static func get_active_commitments(
	commitments: Array,
	lord_id: int,
) -> Array:
	var result: Array = []
	for c: CourtCommitmentData in commitments:
		if c.lord_id == lord_id and not c.fulfilled:
			result.append(c)
	return result


static func has_unfulfilled_commitments(
	commitments: Array,
	lord_id: int,
) -> bool:
	for c: CourtCommitmentData in commitments:
		if c.lord_id == lord_id and not c.fulfilled:
			return true
	return false


static func has_commitment_on_topic(
	commitments: Array,
	lord_id: int,
	topic_id: int,
) -> bool:
	for c: CourtCommitmentData in commitments:
		if c.lord_id == lord_id and c.topic_id == topic_id:
			return true
	return false


const VOLUNTARY_POSITION_THRESHOLD: float = 50.0


static func find_declarable_topics(
	lord: L5RCharacterData,
	agenda_topic_ids: Array,
	active_topics: Array,
	commitments: Array,
) -> Array:
	## Returns action topics on the agenda where the lord's position exceeds +50
	## and no existing commitment exists. Used to detect voluntary declaration
	## opportunities per GDD s16.4.
	var result: Array = []
	for topic: TopicData in active_topics:
		if topic.topic_id not in agenda_topic_ids:
			continue
		if topic.resolved:
			continue
		var commitment_type: String = ImperialEdictSystem.get_commitment_type_for_topic(topic)
		if commitment_type.is_empty():
			continue
		var position: float = lord.topic_positions.get(topic.topic_id, 0.0)
		if position < VOLUNTARY_POSITION_THRESHOLD:
			continue
		if has_commitment_on_topic(commitments, lord.character_id, topic.topic_id):
			continue
		result.append(topic)
	return result
