class_name SecretSystem

# -- Severity Consequence Tables -----------------------------------------------

const PRIVATE_EXPOSURE_DISP: Dictionary = {
	SecretData.Severity.TIER_4: -8,
	SecretData.Severity.TIER_3: -15,
	SecretData.Severity.TIER_2: -30,
	SecretData.Severity.TIER_1: -50,
}

const PUBLIC_EXPOSURE_DISP_PER_WITNESS: Dictionary = {
	SecretData.Severity.TIER_4: -5,
	SecretData.Severity.TIER_3: -10,
	SecretData.Severity.TIER_2: -20,
	SecretData.Severity.TIER_1: -35,
}

const SUBJECT_HONOR_LOSS: Dictionary = {
	SecretData.Severity.TIER_4: 0.0,
	SecretData.Severity.TIER_3: -0.3,
	SecretData.Severity.TIER_2: -1.0,
	SecretData.Severity.TIER_1: -2.0,
}

const SUBJECT_GLORY_LOSS: Dictionary = {
	SecretData.Severity.TIER_4: -0.1,
	SecretData.Severity.TIER_3: -0.3,
	SecretData.Severity.TIER_2: -0.5,
	SecretData.Severity.TIER_1: -1.0,
}

const SUBJECT_INFAMY_GAIN: Dictionary = {
	SecretData.Severity.TIER_4: 0.0,
	SecretData.Severity.TIER_3: 0.0,
	SecretData.Severity.TIER_2: 0.3,
	SecretData.Severity.TIER_1: 0.5,
}

# -- Context Modifier (severity upgrade) --------------------------------------

const STATUS_UPGRADE_THRESHOLD: float = 0.0
const RECENCY_SEASONS: int = 4

# -- Fabrication TNs -----------------------------------------------------------

const FABRICATION_TN: Dictionary = {
	SecretData.Severity.TIER_1: 15,
	SecretData.Severity.TIER_2: 20,
	SecretData.Severity.TIER_3: 25,
	SecretData.Severity.TIER_4: 30,
}

const FABRICATION_HONOR_COST: Dictionary = {
	SecretData.Severity.TIER_1: -0.3,
	SecretData.Severity.TIER_2: -0.5,
	SecretData.Severity.TIER_3: -0.8,
	SecretData.Severity.TIER_4: -1.5,
}

const FABRICATION_INFAMY: float = 0.2

# -- Covert Acquisition Honor/Infamy Costs ------------------------------------

const BRIBE_HONOR_COST: float = -0.2
const BRIBE_INFAMY: float = 0.1
const EAVESDROP_HONOR_COST: float = -0.1
const EAVESDROP_INFAMY: float = 0.05
const INTERCEPT_HONOR_COST: float = -0.3
const INTERCEPT_INFAMY: float = 0.1
const SEARCH_HONOR_COST: float = -0.3
const SEARCH_INFAMY: float = 0.1

# -- Assassination Ordering Honor Cost ----------------------------------------

const ASSASSINATION_ORDER_HONOR: Dictionary = {
	"low": -2.0,
	"mid": -3.0,
	"high": -4.0,
	"imperial": -5.0,
}

# -- Physical Proof Bonus ------------------------------------------------------

const PHYSICAL_PROOF_FREE_RAISES: int = 1

# -- Reputation threshold ------------------------------------------------------

const INFAMY_REPUTATION_THRESHOLD: float = 0.5

# -- Fabrication Exposure Disposition ------------------------------------------

const FABRICATION_EXPOSED_DISP: int = -25


# ==============================================================================
# Secret Creation
# ==============================================================================

static func create_secret(
	secret_id: int,
	subject_id: int,
	severity: SecretData.Severity,
	slug: String = "",
	description: String = "",
) -> SecretData:
	var s := SecretData.new()
	s.secret_id = secret_id
	s.subject_id = subject_id
	s.severity = severity
	s.slug = slug
	s.description = description
	return s


# ==============================================================================
# Context Modifier — Severity Upgrade
# ==============================================================================

static func get_effective_severity(
	secret: SecretData,
	subject_status: float,
	involved_status: float,
	seasons_since_act: int,
) -> SecretData.Severity:
	var sev: int = secret.severity
	var should_upgrade: bool = false

	if involved_status > subject_status:
		should_upgrade = true

	if seasons_since_act >= 0 and seasons_since_act < RECENCY_SEASONS:
		should_upgrade = true

	if should_upgrade and sev < SecretData.Severity.TIER_4:
		sev += 1

	return sev as SecretData.Severity


# ==============================================================================
# Private Exposure (Reveal a Secret Privately)
# ==============================================================================

static func reveal_privately(
	secret: SecretData,
	revealer: L5RCharacterData,
	recipient: L5RCharacterData,
	subject: L5RCharacterData,
	has_proof: bool = false,
) -> Dictionary:
	var sev: SecretData.Severity = secret.severity
	var disp_change: int = PRIVATE_EXPOSURE_DISP.get(sev, -8)
	var honor_loss: float = SUBJECT_HONOR_LOSS.get(sev, 0.0)
	var glory_loss: float = SUBJECT_GLORY_LOSS.get(sev, 0.0)
	var infamy_gain: float = SUBJECT_INFAMY_GAIN.get(sev, 0.0)

	var free_raises: int = PHYSICAL_PROOF_FREE_RAISES if has_proof else 0

	secret.exposed = true

	subject.honor = clampf(subject.honor + honor_loss, 0.0, 10.0)
	subject.glory = clampf(subject.glory + glory_loss, 0.0, 10.0)
	subject.infamy = clampf(subject.infamy + infamy_gain, 0.0, 10.0)

	var current_disp: int = recipient.disposition_values.get(subject.character_id, 0)
	recipient.disposition_values[subject.character_id] = clampi(
		current_disp + disp_change, -100, 100
	)

	var generates_topic: bool = (sev == SecretData.Severity.TIER_1)

	return {
		"disposition_change": disp_change,
		"honor_loss": honor_loss,
		"glory_loss": glory_loss,
		"infamy_gain": infamy_gain,
		"free_raises": free_raises,
		"generates_betrayal_topic": generates_topic,
		"severity": sev,
	}


# ==============================================================================
# Public Exposure (Expose a Secret Publicly)
# ==============================================================================

static func expose_publicly(
	secret: SecretData,
	exposer: L5RCharacterData,
	subject: L5RCharacterData,
	witness_ids: Array[int],
	characters_by_id: Dictionary,
	has_proof: bool = false,
) -> Dictionary:
	var sev: SecretData.Severity = secret.severity
	var disp_per_witness: int = PUBLIC_EXPOSURE_DISP_PER_WITNESS.get(sev, -5)
	var honor_loss: float = SUBJECT_HONOR_LOSS.get(sev, 0.0)
	var glory_loss: float = SUBJECT_GLORY_LOSS.get(sev, 0.0)
	var infamy_gain: float = SUBJECT_INFAMY_GAIN.get(sev, 0.0)

	var free_raises: int = PHYSICAL_PROOF_FREE_RAISES if has_proof else 0

	secret.exposed = true
	secret.exposed_publicly = true

	subject.honor = clampf(subject.honor + honor_loss, 0.0, 10.0)
	subject.glory = clampf(subject.glory + glory_loss, 0.0, 10.0)
	subject.infamy = clampf(subject.infamy + infamy_gain, 0.0, 10.0)

	var witness_effects: Array[Dictionary] = []
	for wid in witness_ids:
		var w: L5RCharacterData = characters_by_id.get(wid)
		if w != null:
			var current: int = w.disposition_values.get(subject.character_id, 0)
			w.disposition_values[subject.character_id] = clampi(
				current + disp_per_witness, -100, 100
			)
			witness_effects.append({
				"character_id": wid,
				"disposition_change": disp_per_witness,
			})

	var generates_topic: bool = (sev == SecretData.Severity.TIER_1)

	return {
		"disposition_per_witness": disp_per_witness,
		"witness_count": witness_ids.size(),
		"witness_effects": witness_effects,
		"honor_loss": honor_loss,
		"glory_loss": glory_loss,
		"infamy_gain": infamy_gain,
		"free_raises": free_raises,
		"generates_betrayal_topic": generates_topic,
		"severity": sev,
	}


# ==============================================================================
# Fabrication
# ==============================================================================

static func get_fabrication_tn(severity: SecretData.Severity) -> int:
	return FABRICATION_TN.get(severity, 25)


static func fabricate_secret(
	fabricator: L5RCharacterData,
	target_id: int,
	severity: SecretData.Severity,
	secret_id: int,
	dice_engine: DiceEngine,
	raises_called: int = 0,
) -> Dictionary:
	var tn: int = get_fabrication_tn(severity)
	var skill_rank: int = fabricator.skills.get("Forgery", 0)
	if skill_rank == 0:
		return {"success": false, "reason": "no_forgery_skill"}

	var trait_val: int = fabricator.agility
	var roll_result: DiceResult = dice_engine.roll_and_keep(trait_val, skill_rank)
	var total: int = roll_result.total
	var needed: int = tn + (raises_called * 5)
	var success: bool = total >= needed

	var honor_cost: float = FABRICATION_HONOR_COST.get(severity, -0.5)
	fabricator.honor = clampf(fabricator.honor + honor_cost, 0.0, 10.0)
	fabricator.infamy = clampf(fabricator.infamy + FABRICATION_INFAMY, 0.0, 10.0)

	if not success:
		return {"success": false, "roll_total": total, "tn": needed, "honor_cost": honor_cost}

	var detection_tn: int = tn + (raises_called * 5)

	var secret := SecretData.new()
	secret.secret_id = secret_id
	secret.subject_id = target_id
	secret.severity = severity
	secret.fabricated = true
	secret.fabricator_id = fabricator.character_id
	secret.detection_tn = detection_tn

	return {
		"success": true,
		"secret": secret,
		"roll_total": total,
		"tn": needed,
		"detection_tn": detection_tn,
		"honor_cost": honor_cost,
	}


static func detect_fabrication(
	investigator: L5RCharacterData,
	secret: SecretData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if not secret.fabricated:
		return {"checked": false, "reason": "not_fabricated"}

	var skill_rank: int = investigator.skills.get("Investigation", 0)
	var trait_val: int = investigator.perception
	var roll_result: DiceResult = dice_engine.roll_and_keep(trait_val, skill_rank)
	var total: int = roll_result.total
	var success: bool = total >= secret.detection_tn

	return {
		"checked": true,
		"detected": success,
		"roll_total": total,
		"detection_tn": secret.detection_tn,
	}


# ==============================================================================
# Covert Acquisition Cost Helpers
# ==============================================================================

static func apply_bribe_costs(actor: L5RCharacterData) -> void:
	actor.honor = clampf(actor.honor + BRIBE_HONOR_COST, 0.0, 10.0)
	actor.infamy = clampf(actor.infamy + BRIBE_INFAMY, 0.0, 10.0)


static func apply_eavesdrop_costs(actor: L5RCharacterData) -> void:
	actor.honor = clampf(actor.honor + EAVESDROP_HONOR_COST, 0.0, 10.0)
	actor.infamy = clampf(actor.infamy + EAVESDROP_INFAMY, 0.0, 10.0)


static func apply_intercept_costs(actor: L5RCharacterData) -> void:
	actor.honor = clampf(actor.honor + INTERCEPT_HONOR_COST, 0.0, 10.0)
	actor.infamy = clampf(actor.infamy + INTERCEPT_INFAMY, 0.0, 10.0)


static func apply_search_costs(actor: L5RCharacterData) -> void:
	actor.honor = clampf(actor.honor + SEARCH_HONOR_COST, 0.0, 10.0)
	actor.infamy = clampf(actor.infamy + SEARCH_INFAMY, 0.0, 10.0)


# ==============================================================================
# Bribe TN Calculation
# ==============================================================================

static func get_bribe_tn(lord_disposition_toward_servant: int) -> int:
	return 10 + (lord_disposition_toward_servant / 5)


# ==============================================================================
# Assassination Order Honor Cost
# ==============================================================================

static func get_assassination_order_honor_cost(target_status: float) -> float:
	if target_status >= 8.0:
		return ASSASSINATION_ORDER_HONOR["imperial"]
	if target_status >= 6.0:
		return ASSASSINATION_ORDER_HONOR["high"]
	if target_status >= 3.0:
		return ASSASSINATION_ORDER_HONOR["mid"]
	return ASSASSINATION_ORDER_HONOR["low"]


# ==============================================================================
# Reputation Check
# ==============================================================================

static func should_generate_reputation_topic(
	covert_infamy_accumulated: float,
) -> bool:
	return covert_infamy_accumulated >= INFAMY_REPUTATION_THRESHOLD


# ==============================================================================
# NPC Covert Method Filters
# ==============================================================================

const CLAN_RELUCTANCE: Dictionary = {
	"Scorpion": 0,
	"Unicorn": 1,
	"Crab": 2,
	"Mantis": 2,
	"Dragon": 3,
	"Crane": 4,
	"Phoenix": 4,
	"Lion": 5,
}

const HONOR_THRESHOLD_NEVER: float = 3.5
const HONOR_THRESHOLD_PRESSURE: float = 2.0

static func passes_covert_filters(
	character: L5RCharacterData,
	target_disposition: int,
	has_lord_assignment: bool,
) -> bool:
	if character.bushido_virtue == Enums.BushidoVirtue.GI:
		return false
	if character.bushido_virtue == Enums.BushidoVirtue.MAKOTO:
		return false

	if character.honor > HONOR_THRESHOLD_NEVER:
		var clan_reluctance: int = CLAN_RELUCTANCE.get(character.clan, 3)
		if clan_reluctance > 0:
			return false

	if target_disposition > -31 and not has_lord_assignment:
		return false

	return true


# ==============================================================================
# Personality Fabrication Gate
# ==============================================================================

static func can_fabricate(character: L5RCharacterData) -> bool:
	if character.bushido_virtue == Enums.BushidoVirtue.GI:
		return false
	if character.bushido_virtue == Enums.BushidoVirtue.MAKOTO:
		return false
	return true
