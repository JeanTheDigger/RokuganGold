class_name CommitmentRegistry
## Social obligation tracking per GDD s55.31.
## Tracks promises NPCs make, checks fulfillment at deadline,
## fires consequences for broken commitments, and provides
## Phase 5 scoring modifiers.


# =============================================================================
# 55.31.5 — Consequence Tables
# =============================================================================

const BROKEN_NO_NOTICE: Dictionary = {
	3: {"honor": -0.1, "creditor_disp": -3, "witness_disp": 0, "topic_tier": 4},
	2: {"honor": -0.2, "creditor_disp": -6, "witness_disp": -2, "topic_tier": 3},
	1: {"honor": -0.5, "creditor_disp": -10, "witness_disp": -5, "topic_tier": 2},
}

const BROKEN_WITH_NOTICE: Dictionary = {
	3: {"honor": 0.0, "creditor_disp": -1, "witness_disp": 0, "topic_tier": -1},
	2: {"honor": -0.1, "creditor_disp": -3, "witness_disp": 0, "topic_tier": -1},
	1: {"honor": -0.2, "creditor_disp": -5, "witness_disp": -2, "topic_tier": 3},
}

const BROKEN_WITH_PROXY: Dictionary = {
	3: {"honor": 0.0, "creditor_disp": 0, "witness_disp": 0, "topic_tier": -1},
	2: {"honor": 0.0, "creditor_disp": -1, "witness_disp": 0, "topic_tier": -1},
	1: {"honor": -0.1, "creditor_disp": -2, "witness_disp": 0, "topic_tier": -1},
}

const BROKEN_FORCE_MAJEURE: Dictionary = {
	3: {"honor": 0.0, "creditor_disp": -1, "witness_disp": 0, "topic_tier": -1},
	2: {"honor": -0.1, "creditor_disp": -3, "witness_disp": 0, "topic_tier": -1},
	1: {"honor": -0.2, "creditor_disp": -5, "witness_disp": -2, "topic_tier": 3},
}


# =============================================================================
# 55.31.7 — Phase 5 Commitment-at-Risk Penalties
# =============================================================================

const BASE_AT_RISK_PENALTY: Dictionary = {
	3: -5,
	2: -15,
	1: -25,
}

const MAX_AT_RISK_PENALTY: int = -40

const PERSONALITY_AT_RISK_MODIFIERS: Dictionary = {
	Enums.BushidoVirtue.MEIYO: -5,
	Enums.BushidoVirtue.GI: -8,
	Enums.BushidoVirtue.CHUGI: -5,
	Enums.BushidoVirtue.REI: -5,
}

const CHUGI_EXTERNAL_REDUCTION: int = 3

const REDUCED_PENALTY_VIRTUES: Array[int] = [
	Enums.ShouridoVirtue.SEIGYO,
	Enums.ShouridoVirtue.KYORYOKU,
]

const REDUCED_AT_RISK_PENALTY: Dictionary = {
	3: -3,
	2: -10,
	1: -20,
}


# =============================================================================
# 55.31.11.3 — Forgiveness Rates
# =============================================================================

const DEFAULT_FORGIVENESS_RATE: float = 0.5

const FORGIVENESS_RATES_BUSHIDO: Dictionary = {
	Enums.BushidoVirtue.JIN: 1.0,
	Enums.BushidoVirtue.GI: 0.75,
	Enums.BushidoVirtue.CHUGI: 0.75,
	Enums.BushidoVirtue.REI: 0.5,
	Enums.BushidoVirtue.MEIYO: 0.5,
	Enums.BushidoVirtue.YU: 0.5,
	Enums.BushidoVirtue.MAKOTO: 0.5,
	Enums.BushidoVirtue.NONE: 0.5,
}

const FORGIVENESS_RATES_SHOURIDO: Dictionary = {
	Enums.ShouridoVirtue.DOSATSU: 0.5,
	Enums.ShouridoVirtue.SEIGYO: 0.25,
	Enums.ShouridoVirtue.KYORYOKU: 0.25,
	Enums.ShouridoVirtue.KETSUI: 0.5,
	Enums.ShouridoVirtue.CHISHIKI: 0.5,
	Enums.ShouridoVirtue.KANPEKI: 0.5,
	Enums.ShouridoVirtue.ISHI: 0.5,
	Enums.ShouridoVirtue.NONE: 0.5,
}

const CHUGI_EXTERNAL_FORGIVENESS: float = 0.25


# =============================================================================
# 55.31.1 — Registry Queries
# =============================================================================

static func get_pending(
	commitments: Array,
	npc_id: int,
) -> Array:
	var result: Array = []
	for c: CommitmentData in commitments:
		if c.debtor_npc_id == npc_id and c.status == Enums.CommitmentStatus.PENDING:
			result.append(c)
	return result


static func get_by_crisis(
	commitments: Array,
	crisis_id: int,
) -> Array:
	var result: Array = []
	for c: CommitmentData in commitments:
		if c.crisis_id == crisis_id:
			result.append(c)
	return result


# =============================================================================
# 55.31.3 — Commitment Creation
# =============================================================================

static func create_commitment(
	commitment_id: int,
	commitment_type: Enums.CommitmentType,
	creditor_id: int,
	debtor_id: int,
	deadline_ic_day: int,
	tier: int,
	created_ic_day: int,
	source_action: String = "",
	fulfillment_target: int = -1,
	witnesses: Array = [],
) -> CommitmentData:
	var c := CommitmentData.new()
	c.commitment_id = commitment_id
	c.commitment_type = commitment_type
	c.source_action_id = source_action
	c.creditor_npc_id = creditor_id
	c.debtor_npc_id = debtor_id
	c.deadline_ic_day = deadline_ic_day
	c.fulfillment_target = fulfillment_target
	c.tier = clampi(tier, 1, 3)
	c.created_ic_day = created_ic_day
	c.witnesses = witnesses.duplicate()
	return c


# =============================================================================
# 55.31.6 — Proactive Management
# =============================================================================

static func send_advance_notice(
	commitment: CommitmentData,
	current_ic_day: int,
) -> bool:
	if commitment.status != Enums.CommitmentStatus.PENDING:
		return false
	if current_ic_day >= commitment.deadline_ic_day:
		return false
	commitment.advance_notice_sent = true
	commitment.notice_ic_day = current_ic_day
	return true


static func register_proxy(commitment: CommitmentData) -> bool:
	if commitment.status != Enums.CommitmentStatus.PENDING:
		return false
	if commitment.commitment_type == Enums.CommitmentType.SUPPORT_PLEDGE:
		return false
	commitment.proxy_sent = true
	return true


# =============================================================================
# 55.31.4 — Deadline Check
# =============================================================================

static func check_deadline(
	commitment: CommitmentData,
	is_fulfilled: bool,
) -> Enums.CommitmentStatus:
	if commitment.status != Enums.CommitmentStatus.PENDING:
		return commitment.status

	if is_fulfilled:
		commitment.status = Enums.CommitmentStatus.FULFILLED
		return Enums.CommitmentStatus.FULFILLED

	if commitment.crisis_id >= 0:
		commitment.status = Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE
	elif commitment.proxy_sent:
		if commitment.commitment_type == Enums.CommitmentType.SUPPORT_PLEDGE:
			commitment.status = Enums.CommitmentStatus.BROKEN_WITH_NOTICE
		else:
			commitment.status = Enums.CommitmentStatus.BROKEN_WITH_PROXY
	elif commitment.advance_notice_sent:
		commitment.status = Enums.CommitmentStatus.BROKEN_WITH_NOTICE
	else:
		commitment.status = Enums.CommitmentStatus.BROKEN_NO_NOTICE

	return commitment.status


# =============================================================================
# 55.31.5 — Consequence Calculation
# =============================================================================

static func get_consequences(commitment: CommitmentData) -> Dictionary:
	if commitment.commitment_type == Enums.CommitmentType.FAVOR_OBLIGATION:
		return {"honor": 0.0, "creditor_disp": 0, "witness_disp": 0, "topic_tier": -1}

	var table: Dictionary = {}
	match commitment.status:
		Enums.CommitmentStatus.BROKEN_NO_NOTICE:
			table = BROKEN_NO_NOTICE
		Enums.CommitmentStatus.BROKEN_WITH_NOTICE:
			table = BROKEN_WITH_NOTICE
		Enums.CommitmentStatus.BROKEN_WITH_PROXY:
			table = BROKEN_WITH_PROXY
		Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE:
			table = BROKEN_FORCE_MAJEURE
		_:
			return {"honor": 0.0, "creditor_disp": 0, "witness_disp": 0, "topic_tier": -1}

	var tier: int = clampi(commitment.tier, 1, 3)
	return table.get(tier, {"honor": 0.0, "creditor_disp": 0, "witness_disp": 0, "topic_tier": -1})


static func apply_consequences(
	commitment: CommitmentData,
	debtor: L5RCharacterData,
	characters_by_id: Dictionary,
) -> Dictionary:
	var conseq: Dictionary = get_consequences(commitment)
	var result: Dictionary = {
		"honor_change": 0.0,
		"disposition_changes": [],
	}

	var honor_change: float = conseq.get("honor", 0.0)
	if absf(honor_change) > 0.001:
		HonorGlorySystem.apply_honor_change(debtor, honor_change)
		result["honor_change"] = honor_change

	var creditor_disp: int = conseq.get("creditor_disp", 0)
	if creditor_disp != 0:
		var creditor: L5RCharacterData = characters_by_id.get(commitment.creditor_npc_id)
		if creditor != null:
			var old_val: int = creditor.disposition_values.get(debtor.character_id, 0)
			var new_val: int = clampi(old_val + creditor_disp, -100, 100)
			creditor.disposition_values[debtor.character_id] = new_val
			result["disposition_changes"].append({
				"npc_id": commitment.creditor_npc_id,
				"old": old_val,
				"new": new_val,
				"delta": creditor_disp,
			})
			commitment.penalty_records.append({
				"npc_id": commitment.creditor_npc_id,
				"disposition_change": creditor_disp,
				"forgiveness_applied": false,
			})

	var witness_disp: int = conseq.get("witness_disp", 0)
	if witness_disp != 0:
		for w_id: int in commitment.witnesses:
			if w_id == commitment.creditor_npc_id or w_id == commitment.debtor_npc_id:
				continue
			var witness: L5RCharacterData = characters_by_id.get(w_id)
			if witness == null:
				continue
			var old_val: int = witness.disposition_values.get(debtor.character_id, 0)
			var new_val: int = clampi(old_val + witness_disp, -100, 100)
			witness.disposition_values[debtor.character_id] = new_val
			result["disposition_changes"].append({
				"npc_id": w_id,
				"old": old_val,
				"new": new_val,
				"delta": witness_disp,
			})
			commitment.penalty_records.append({
				"npc_id": w_id,
				"disposition_change": witness_disp,
				"forgiveness_applied": false,
			})

	return result


# =============================================================================
# 55.31.4 — Batch Deadline Processing
# =============================================================================

static func process_deadlines(
	commitments: Array,
	current_ic_day: int,
	fulfillment_checker: Callable,
	debtor_lookup: Dictionary,
	characters_by_id: Dictionary,
) -> Array:
	var results: Array = []
	for c: CommitmentData in commitments:
		if c.status != Enums.CommitmentStatus.PENDING:
			continue
		if c.commitment_type == Enums.CommitmentType.FAVOR_OBLIGATION:
			continue
		if c.deadline_ic_day > current_ic_day:
			continue
		var is_fulfilled: bool = fulfillment_checker.call(c)
		var new_status: Enums.CommitmentStatus = check_deadline(c, is_fulfilled)

		if new_status == Enums.CommitmentStatus.FULFILLED:
			results.append({
				"commitment_id": c.commitment_id,
				"status": "FULFILLED",
			})
			continue

		var debtor: L5RCharacterData = debtor_lookup.get(c.debtor_npc_id)
		if debtor == null:
			continue
		var conseq: Dictionary = apply_consequences(c, debtor, characters_by_id)
		results.append({
			"commitment_id": c.commitment_id,
			"status": Enums.CommitmentStatus.keys()[new_status],
			"honor_change": conseq["honor_change"],
			"disposition_changes": conseq["disposition_changes"],
			"tier": c.tier,
		})
	return results


# =============================================================================
# 55.31.11 — Force Majeure
# =============================================================================

static func link_crisis(
	commitments: Array,
	debtor_id: int,
	crisis_id: int,
) -> int:
	var linked: int = 0
	for c: CommitmentData in commitments:
		if c.debtor_npc_id == debtor_id and c.status == Enums.CommitmentStatus.PENDING:
			c.crisis_id = crisis_id
			linked += 1
	return linked


# =============================================================================
# 55.31.11.2 — Retroactive Forgiveness
# =============================================================================

static func get_forgiveness_rate(character: L5RCharacterData, is_same_loyalty_chain: bool = false) -> float:
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return FORGIVENESS_RATES_SHOURIDO.get(
			character.shourido_virtue, DEFAULT_FORGIVENESS_RATE
		)
	if character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		if is_same_loyalty_chain:
			return 0.75
		return CHUGI_EXTERNAL_FORGIVENESS
	return FORGIVENESS_RATES_BUSHIDO.get(
		character.bushido_virtue, DEFAULT_FORGIVENESS_RATE
	)


static func apply_forgiveness(
	commitment: CommitmentData,
	receiving_npc: L5RCharacterData,
	debtor_id: int,
	is_same_loyalty_chain: bool = false,
) -> float:
	if commitment.status != Enums.CommitmentStatus.BROKEN_FORCE_MAJEURE:
		return 0.0

	var rate: float = get_forgiveness_rate(receiving_npc, is_same_loyalty_chain)
	var total_recovery: float = 0.0

	for record: Dictionary in commitment.penalty_records:
		if record.get("npc_id", -1) != receiving_npc.character_id:
			continue
		if record.get("forgiveness_applied", false):
			continue
		var penalty: int = record.get("disposition_change", 0)
		var recovery: float = absf(float(penalty)) * rate
		var old_disp: int = receiving_npc.disposition_values.get(debtor_id, 0)
		var new_disp: int = clampi(old_disp + int(recovery), -100, 100)
		receiving_npc.disposition_values[debtor_id] = new_disp
		record["forgiveness_applied"] = true
		total_recovery += recovery

	return total_recovery


# =============================================================================
# 55.31.7 — Phase 5 Commitment-at-Risk Modifier
# =============================================================================

static func get_at_risk_penalty(
	commitments: Array,
	debtor_id: int,
	character: L5RCharacterData,
	creditor_in_loyalty_chain: Callable = Callable(),
) -> int:
	var total: int = 0
	var pending: Array = get_pending(commitments, debtor_id)
	var uses_reduced: bool = character.shourido_virtue in REDUCED_PENALTY_VIRTUES

	for c: CommitmentData in pending:
		if c.commitment_type == Enums.CommitmentType.FAVOR_OBLIGATION:
			continue
		var tier: int = clampi(c.tier, 1, 3)
		var base: int = 0
		if uses_reduced:
			base = REDUCED_AT_RISK_PENALTY.get(tier, -5)
		else:
			base = BASE_AT_RISK_PENALTY.get(tier, -5)

		if not uses_reduced:
			if character.bushido_virtue in PERSONALITY_AT_RISK_MODIFIERS:
				var mod: int = PERSONALITY_AT_RISK_MODIFIERS[character.bushido_virtue]
				if character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
					var in_chain: bool = false
					if creditor_in_loyalty_chain.is_valid():
						in_chain = creditor_in_loyalty_chain.call(c.creditor_npc_id)
					if in_chain:
						base += mod
					else:
						base += mod + CHUGI_EXTERNAL_REDUCTION
				else:
					base += mod

		total += base

	return maxi(total, MAX_AT_RISK_PENALTY)


const COMMITMENT_REDIRECTING_ACTIONS: Array[String] = [
	"CHANGE_DESTINATION", "BEGIN_TRAVEL",
]


static func get_action_commitment_modifier(
	action_id: String,
	action_settlement_id: int,
	commitments: Array,
	debtor_id: int,
	character: L5RCharacterData,
	creditor_in_loyalty_chain: Callable = Callable(),
) -> int:
	var pending: Array = get_pending(commitments, debtor_id)
	if pending.is_empty():
		return 0
	var commitment_targets: Array = []
	for c: CommitmentData in pending:
		if c.commitment_type == Enums.CommitmentType.FAVOR_OBLIGATION:
			continue
		if c.fulfillment_target >= 0 and c.fulfillment_target not in commitment_targets:
			commitment_targets.append(c.fulfillment_target)
	if commitment_targets.is_empty():
		return 0
	var raw_penalty: int = get_at_risk_penalty(commitments, debtor_id, character, creditor_in_loyalty_chain)
	if raw_penalty == 0:
		return 0
	var targets_committed: bool = action_settlement_id in commitment_targets
	if action_id in COMMITMENT_REDIRECTING_ACTIONS:
		if targets_committed:
			if action_id == "BEGIN_TRAVEL":
				return -raw_penalty
			return 0
		return raw_penalty
	if targets_committed:
		return -raw_penalty
	return 0
