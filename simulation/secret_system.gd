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


# ==============================================================================
# Eavesdrop Resolution (Contested)
# ==============================================================================

const EAVESDROP_SKILL: String = "Stealth"
const EAVESDROP_DETECT_SKILL: String = "Investigation"

static func resolve_eavesdrop(
	eavesdropper: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	apply_eavesdrop_costs(eavesdropper)

	var stealth_rank: int = eavesdropper.skills.get(EAVESDROP_SKILL, 0)
	var rolled_a: int = eavesdropper.agility + stealth_rank
	var kept_a: int = eavesdropper.agility
	var explodes_a: bool = stealth_rank > 0

	var inv_rank: int = target.skills.get(EAVESDROP_DETECT_SKILL, 0)
	var rolled_b: int = target.perception + inv_rank
	var kept_b: int = target.perception
	var explodes_b: bool = inv_rank > 0

	var result_a: DiceResult = dice_engine.roll_and_keep(rolled_a, kept_a, explodes_a)
	var result_b: DiceResult = dice_engine.roll_and_keep(rolled_b, kept_b, explodes_b)

	var success: bool = result_a.total >= result_b.total
	var detected: bool = not success
	var margin: int = result_a.total - result_b.total

	return {
		"success": success,
		"detected": detected,
		"margin": margin,
		"eavesdropper_total": result_a.total,
		"target_total": result_b.total,
		"detection_risk": detected,
	}


# ==============================================================================
# Intercept Letter Resolution (Two-Step)
# ==============================================================================

const INTERCEPT_STEALTH_TN: int = 15
const INTERCEPT_FORGERY_TN: int = 15
const INTERCEPT_GEOGRAPHIC_BONUS: int = 5

static func resolve_intercept_letter(
	interceptor: L5RCharacterData,
	dice_engine: DiceEngine,
	is_same_location: bool = false,
) -> Dictionary:
	apply_intercept_costs(interceptor)

	var geographic_mod: int = -INTERCEPT_GEOGRAPHIC_BONUS if is_same_location else 0

	var stealth_rank: int = interceptor.skills.get("Stealth", 0)
	var stealth_rolled: int = interceptor.agility + stealth_rank
	var stealth_kept: int = interceptor.agility
	var stealth_result: DiceResult = dice_engine.roll_and_keep(stealth_rolled, stealth_kept, stealth_rank > 0)
	var stealth_tn: int = INTERCEPT_STEALTH_TN + geographic_mod
	var stealth_success: bool = stealth_result.total >= stealth_tn

	if not stealth_success:
		return {
			"success": false,
			"phase_failed": "stealth",
			"stealth_total": stealth_result.total,
			"stealth_tn": stealth_tn,
			"detection_risk": true,
		}

	var forgery_rank: int = interceptor.skills.get("Forgery", 0)
	var forgery_rolled: int = interceptor.intelligence + forgery_rank
	var forgery_kept: int = interceptor.intelligence
	var forgery_result: DiceResult = dice_engine.roll_and_keep(forgery_rolled, forgery_kept, forgery_rank > 0)
	var forgery_success: bool = forgery_result.total >= INTERCEPT_FORGERY_TN

	return {
		"success": forgery_success,
		"phase_failed": "" if forgery_success else "forgery",
		"stealth_total": stealth_result.total,
		"stealth_tn": stealth_tn,
		"forgery_total": forgery_result.total,
		"forgery_tn": INTERCEPT_FORGERY_TN,
		"detection_risk": not forgery_success,
	}


# ==============================================================================
# Search Quarters Resolution
# ==============================================================================

const SEARCH_BASE_TN: int = 15

static func resolve_search_quarters(
	searcher: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	apply_search_costs(searcher)

	var inv_rank: int = target.skills.get("Investigation", 0)
	var tn: int = SEARCH_BASE_TN + inv_rank

	var stealth_rank: int = searcher.skills.get("Stealth", 0)
	var rolled: int = searcher.agility + stealth_rank
	var kept: int = searcher.agility
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, stealth_rank > 0)
	var success: bool = result.total >= tn
	var margin: int = result.total - tn

	return {
		"success": success,
		"roll_total": result.total,
		"tn": tn,
		"margin": margin,
		"detection_risk": not success,
	}


# ==============================================================================
# Shadow Target Resolution (Contested, 1 IC Day)
# ==============================================================================

static func resolve_shadow_target(
	shadow: L5RCharacterData,
	target: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var stealth_rank: int = shadow.skills.get("Stealth", 0)
	var rolled_a: int = shadow.agility + stealth_rank
	var kept_a: int = shadow.agility
	var explodes_a: bool = stealth_rank > 0

	var inv_rank: int = target.skills.get("Investigation", 0)
	var rolled_b: int = target.perception + inv_rank
	var kept_b: int = target.perception
	var explodes_b: bool = inv_rank > 0

	var result_a: DiceResult = dice_engine.roll_and_keep(rolled_a, kept_a, explodes_a)
	var result_b: DiceResult = dice_engine.roll_and_keep(rolled_b, kept_b, explodes_b)

	var success: bool = result_a.total >= result_b.total
	var margin: int = result_a.total - result_b.total

	return {
		"success": success,
		"detected": not success,
		"shadow_total": result_a.total,
		"target_total": result_b.total,
		"margin": margin,
	}


# ==============================================================================
# Conceal Item
# ==============================================================================

const CONCEAL_TN_SMALL: int = 10
const CONCEAL_TN_MEDIUM: int = 15
const CONCEAL_TN_LARGE: int = 20
const CONCEAL_WEAPON_SKILL_GATE: int = 5

static func get_conceal_tn(item_size: String) -> int:
	match item_size:
		"SMALL":
			return CONCEAL_TN_SMALL
		"MEDIUM":
			return CONCEAL_TN_MEDIUM
		"LARGE":
			return CONCEAL_TN_LARGE
		_:
			return CONCEAL_TN_MEDIUM


static func resolve_conceal_item(
	actor: L5RCharacterData,
	item_size: String,
	is_weapon: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	if is_weapon:
		var soh_rank: int = actor.skills.get("Sleight of Hand", 0)
		if soh_rank < CONCEAL_WEAPON_SKILL_GATE:
			return {"success": false, "reason": "weapon_skill_gate", "required_rank": CONCEAL_WEAPON_SKILL_GATE}

	var tn: int = get_conceal_tn(item_size)
	var soh_rank: int = actor.skills.get("Sleight of Hand", 0)
	var rolled: int = actor.agility + soh_rank
	var kept: int = actor.agility
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, soh_rank > 0)
	var success: bool = result.total >= tn

	return {
		"success": success,
		"roll_total": result.total,
		"tn": tn,
		"concealment_tn": result.total if success else 0,
	}


# ==============================================================================
# Search Person
# ==============================================================================

const SEARCH_PERSON_GLORY_COST: float = -0.3

static func resolve_search_person(
	searcher: L5RCharacterData,
	target: L5RCharacterData,
	concealment_tn: int,
	dice_engine: DiceEngine,
	has_magistrate_authority: bool = false,
) -> Dictionary:
	var inv_rank: int = searcher.skills.get("Investigation", 0)
	var rolled: int = searcher.perception + inv_rank
	var kept: int = searcher.perception
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, inv_rank > 0)
	var success: bool = result.total >= concealment_tn

	var glory_cost: float = 0.0
	if not has_magistrate_authority and not success:
		glory_cost = SEARCH_PERSON_GLORY_COST
		searcher.glory = clampf(searcher.glory + glory_cost, 0.0, 10.0)

	return {
		"success": success,
		"roll_total": result.total,
		"concealment_tn": concealment_tn,
		"glory_cost": glory_cost,
	}


# ==============================================================================
# Forge Impersonation Letter
# ==============================================================================

const FORGE_LETTER_TN: Dictionary = {
	"minor": 15,
	"moderate": 20,
	"major": 25,
}

static func resolve_forge_impersonation_letter(
	forger: L5RCharacterData,
	authority_level: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	var tn: int = FORGE_LETTER_TN.get(authority_level, 20)

	var forgery_rank: int = forger.skills.get("Forgery", 0)
	if forgery_rank == 0:
		return {"success": false, "reason": "no_forgery_skill"}

	var rolled: int = forger.intelligence + forgery_rank
	var kept: int = forger.intelligence
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept)
	var success: bool = result.total >= tn

	var detection_tn: int = result.total if success else 0

	forger.honor = clampf(forger.honor - 0.3, 0.0, 10.0)
	forger.infamy = clampf(forger.infamy + 0.1, 0.0, 10.0)

	return {
		"success": success,
		"roll_total": result.total,
		"tn": tn,
		"detection_tn": detection_tn,
		"detection_risk": not success,
	}


# ==============================================================================
# Forge Order
# ==============================================================================

const FORGE_ORDER_TN: Dictionary = {
	"minor": 20,
	"moderate": 25,
	"major": 30,
}

static func resolve_forge_order(
	forger: L5RCharacterData,
	authority_level: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	var tn: int = FORGE_ORDER_TN.get(authority_level, 25)

	var forgery_rank: int = forger.skills.get("Forgery", 0)
	if forgery_rank == 0:
		return {"success": false, "reason": "no_forgery_skill"}

	var rolled: int = forger.intelligence + forgery_rank
	var kept: int = forger.intelligence
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept)
	var success: bool = result.total >= tn

	var detection_tn: int = result.total if success else 0

	forger.honor = clampf(forger.honor - 0.5, 0.0, 10.0)
	forger.infamy = clampf(forger.infamy + 0.2, 0.0, 10.0)

	return {
		"success": success,
		"roll_total": result.total,
		"tn": tn,
		"detection_tn": detection_tn,
		"detection_risk": not success,
	}
