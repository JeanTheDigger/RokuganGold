class_name InsurgencySystem
## Province-level insurgency lifecycle per GDD s11.11.
## Shared mechanics: spawning, hidden growth, detection, spread, suppression.
## Seven types with type-specific modifiers.


# =============================================================================
# Stability Thresholds (s11.11)
# =============================================================================

const STABILITY_STABLE_MIN: float = 76.0
const STABILITY_RESTLESS_MIN: float = 51.0
const STABILITY_VOLATILE_MIN: float = 26.0

const SPAWN_CHANCE_RESTLESS: float = 0.10
const SPAWN_CHANCE_VOLATILE: float = 0.25
const SPAWN_CHANCE_BROKEN: float = 0.50

const GARRISON_EFFECTIVENESS: Dictionary = {
	Enums.StabilityTier.STABLE: 1.0,
	Enums.StabilityTier.RESTLESS: 0.9,
	Enums.StabilityTier.VOLATILE: 0.75,
	Enums.StabilityTier.BROKEN: 0.5,
}

const KOKU_MULTIPLIER: Dictionary = {
	Enums.StabilityTier.STABLE: 1.0,
	Enums.StabilityTier.RESTLESS: 0.9,
	Enums.StabilityTier.VOLATILE: 0.75,
	Enums.StabilityTier.BROKEN: 0.5,
}


static func get_stability_tier(stability: float) -> Enums.StabilityTier:
	if stability >= STABILITY_STABLE_MIN:
		return Enums.StabilityTier.STABLE
	if stability >= STABILITY_RESTLESS_MIN:
		return Enums.StabilityTier.RESTLESS
	if stability >= STABILITY_VOLATILE_MIN:
		return Enums.StabilityTier.VOLATILE
	return Enums.StabilityTier.BROKEN


# =============================================================================
# Stability Gains/Losses (s11.11)
# =============================================================================

static func compute_stability_change(
	province: ProvinceData,
	active_insurgencies: Array,
	starvation_stage: int,
	war_status_active: bool,
	raided_this_season: bool,
	peace_bonus_seasons: int,
	population_pu: int = 0,
	garrison_pu: int = 0,
) -> float:
	var delta: float = 0.0

	match starvation_stage:
		1: delta -= 1.0
		2: delta -= 3.0
		3: delta -= 10.0

	var garrison_min: float = population_pu * 0.05
	if garrison_pu < garrison_min:
		delta -= 2.0

	if war_status_active:
		delta -= 2.0

	if raided_this_season:
		delta -= 5.0

	var insurgency_count: int = 0
	for ins: InsurgencyData in active_insurgencies:
		if ins.province_id == province.province_id:
			insurgency_count += 1
	delta -= insurgency_count

	var has_starvation: bool = starvation_stage > ResourceTick.StarvationStage.CLEAR
	var has_insurgency: bool = insurgency_count > 0
	if not has_starvation and garrison_pu >= garrison_min and not has_insurgency and not war_status_active:
		delta += 2.0
		if peace_bonus_seasons >= 4:
			delta += 1.0

	return delta


# =============================================================================
# Base Concealment per Type (s11.11)
# =============================================================================

const BASE_CONCEALMENT: Dictionary = {
	Enums.InsurgencyType.MAHO_CULT: 8,
	Enums.InsurgencyType.PEASANT_REVOLT: 3,
	Enums.InsurgencyType.RONIN_BANDIT: 5,
	Enums.InsurgencyType.TAINT_MANIFESTATION: 6,
	Enums.InsurgencyType.NEZUMI_INFESTATION: 7,
	Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK: 7,
	Enums.InsurgencyType.PIRATE_FLEET: 6,
}


# =============================================================================
# Types eligible per stability tier
# =============================================================================

const RESTLESS_TYPES: Array[int] = [
	Enums.InsurgencyType.RONIN_BANDIT,
	Enums.InsurgencyType.NEZUMI_INFESTATION,
]

const VOLATILE_TYPES: Array[int] = [
	Enums.InsurgencyType.RONIN_BANDIT,
	Enums.InsurgencyType.PEASANT_REVOLT,
	Enums.InsurgencyType.NEZUMI_INFESTATION,
]

const BROKEN_TYPES: Array[int] = [
	Enums.InsurgencyType.RONIN_BANDIT,
	Enums.InsurgencyType.PEASANT_REVOLT,
	Enums.InsurgencyType.NEZUMI_INFESTATION,
	Enums.InsurgencyType.MAHO_CULT,
	Enums.InsurgencyType.TAINT_MANIFESTATION,
]


static func get_eligible_types(
	tier: Enums.StabilityTier,
	province: ProvinceData,
	ptl: float,
) -> Array:
	var types: Array = []
	match tier:
		Enums.StabilityTier.RESTLESS:
			types = RESTLESS_TYPES.duplicate()
		Enums.StabilityTier.VOLATILE:
			types = VOLATILE_TYPES.duplicate()
		Enums.StabilityTier.BROKEN:
			types = BROKEN_TYPES.duplicate()

	# Maho cult: 2% in stable provinces
	if tier == Enums.StabilityTier.STABLE:
		types.append(Enums.InsurgencyType.MAHO_CULT)

	# Taint manifestation spawns from PTL >= 3 regardless of stability
	if ptl >= 3.0 and Enums.InsurgencyType.TAINT_MANIFESTATION not in types:
		types.append(Enums.InsurgencyType.TAINT_MANIFESTATION)

	# Nezumi can spawn anywhere at 5% base
	if Enums.InsurgencyType.NEZUMI_INFESTATION not in types:
		types.append(Enums.InsurgencyType.NEZUMI_INFESTATION)

	# Pirate fleet only on coastal provinces
	if province.is_coastal:
		types.append(Enums.InsurgencyType.PIRATE_FLEET)

	return types


# =============================================================================
# Phase 1 — Spawning (s11.11)
# =============================================================================

static func get_spawn_chance(
	insurgency_type: Enums.InsurgencyType,
	tier: Enums.StabilityTier,
	province: ProvinceData,
	world_state: Dictionary,
) -> float:
	var base: float = 0.0

	# Standard stability-based chance
	match tier:
		Enums.StabilityTier.RESTLESS: base = SPAWN_CHANCE_RESTLESS
		Enums.StabilityTier.VOLATILE: base = SPAWN_CHANCE_VOLATILE
		Enums.StabilityTier.BROKEN: base = SPAWN_CHANCE_BROKEN

	# Type-specific overrides and modifiers
	match insurgency_type:
		Enums.InsurgencyType.MAHO_CULT:
			if tier == Enums.StabilityTier.STABLE:
				base = 0.02
			if world_state.get("recent_maho_in_province", false):
				base += 0.05
		Enums.InsurgencyType.PEASANT_REVOLT:
			if tier == Enums.StabilityTier.STABLE or tier == Enums.StabilityTier.RESTLESS:
				return 0.0
			if world_state.get("starvation_stage", 0) >= ResourceTick.StarvationStage.HUNGER:
				base += 0.10
			if world_state.get("under_garrisoned", false):
				base += 0.10
			if world_state.get("lord_bushido_virtue", Enums.BushidoVirtue.NONE) == Enums.BushidoVirtue.JIN:
				base -= 0.10
		Enums.InsurgencyType.RONIN_BANDIT:
			if world_state.get("adjacent_war_ended_recently", false):
				base += 0.15
			if world_state.get("disbanded_units_unpaid", false):
				base += 0.10
		Enums.InsurgencyType.TAINT_MANIFESTATION:
			var ptl: float = world_state.get("ptl", 0.0)
			if ptl < 3.0:
				return 0.0
			base = 1.0  # automatic at PTL >= 3
		Enums.InsurgencyType.NEZUMI_INFESTATION:
			base = 0.05
			if world_state.get("adjacent_to_shinomen_or_shadowlands", false):
				base += 0.10
			if world_state.get("nezumi_suppressed_recently", false):
				base += 0.10
		Enums.InsurgencyType.PIRATE_FLEET:
			if not province.is_coastal:
				return 0.0
			base = 0.0
			if world_state.get("empire_at_war", false):
				base = 0.05
			if world_state.get("clan_at_war", false):
				base += 0.10
			if province.stability < 50.0:
				base += 0.10
			if world_state.get("adjacent_pirate_count", 0) > 0:
				base += world_state.get("adjacent_pirate_count", 0) * 0.05
			if province.clan == "Mantis":
				base -= 0.10

	return maxf(base, 0.0)


static func try_spawn(
	insurgency_type: Enums.InsurgencyType,
	province: ProvinceData,
	spawn_chance: float,
	dice: DiceEngine,
	next_id: int,
	current_season: int,
) -> InsurgencyData:
	var roll: int = dice.rand_int_range(1, 100)
	if roll > int(spawn_chance * 100):
		return null
	var ins := InsurgencyData.new()
	ins.insurgency_id = next_id
	ins.insurgency_type = insurgency_type
	ins.province_id = province.province_id
	ins.strength = 1
	ins.concealment = BASE_CONCEALMENT.get(insurgency_type, 5)
	ins.detected = false
	ins.seasons_active = 0
	ins.season_spawned = current_season
	return ins


# =============================================================================
# Phase 2 — Hidden Growth (s11.11)
# =============================================================================

static func process_hidden_growth(ins: InsurgencyData) -> Dictionary:
	var result: Dictionary = {"hint_generated": false, "auto_detected": false}
	if ins.detected:
		return result

	ins.strength = mini(ins.strength + 1, 10)
	ins.concealment = maxi(ins.concealment - 1, 0)
	ins.seasons_active += 1

	if ins.strength >= 5 and not result["hint_generated"]:
		result["hint_generated"] = true

	if ins.concealment <= 0:
		ins.detected = true
		result["auto_detected"] = true

	return result


# =============================================================================
# Phase 3 — Detection (s11.11)
# =============================================================================

const DETECTION_TN_MULTIPLIER: int = 5

static func get_detection_tn(ins: InsurgencyData) -> int:
	return ins.concealment * DETECTION_TN_MULTIPLIER


static func attempt_detection(
	ins: InsurgencyData,
	roll_total: int,
) -> Dictionary:
	var tn: int = get_detection_tn(ins)
	if roll_total >= tn + 5:
		ins.detected = true
		return {"result": "success", "type_revealed": true, "strength_estimate": ins.strength}
	elif roll_total >= tn:
		ins.detected = true
		return {"result": "partial", "type_revealed": true, "strength_estimate": -1}
	else:
		ins.concealment += 1
		return {"result": "failure", "type_revealed": false}


# =============================================================================
# Phase 4 — Active Crisis Growth (s11.11)
# =============================================================================

static func process_active_growth(ins: InsurgencyData) -> void:
	if not ins.detected:
		return
	ins.strength = mini(ins.strength + 1, 10)
	ins.seasons_active += 1


# =============================================================================
# Spread Checks (s11.11)
# =============================================================================

const HIDDEN_SPREAD_THRESHOLD: int = 7
const DETECTED_SPREAD_THRESHOLD: int = 5
const HIDDEN_SPREAD_BASE: float = 0.075
const DETECTED_SPREAD_BASE: float = 0.15

const SPREAD_STABILITY_MULT: Dictionary = {
	Enums.StabilityTier.STABLE: 0.0,
	Enums.StabilityTier.RESTLESS: 1.0,
	Enums.StabilityTier.VOLATILE: 2.0,
	Enums.StabilityTier.BROKEN: 3.0,
}


static func get_spread_chance(
	ins: InsurgencyData,
	target_tier: Enums.StabilityTier,
) -> float:
	var threshold: int = DETECTED_SPREAD_THRESHOLD if ins.detected else HIDDEN_SPREAD_THRESHOLD
	if ins.strength < threshold:
		return 0.0

	var base: float = DETECTED_SPREAD_BASE if ins.detected else HIDDEN_SPREAD_BASE
	var mult: float = SPREAD_STABILITY_MULT.get(target_tier, 0.0)

	# Nezumi can spread into stable provinces
	if ins.insurgency_type == Enums.InsurgencyType.NEZUMI_INFESTATION:
		if target_tier == Enums.StabilityTier.STABLE:
			return 0.05

	if mult <= 0.0:
		return 0.0
	return base * mult


static func try_spread(
	ins: InsurgencyData,
	target_province: ProvinceData,
	spread_chance: float,
	dice: DiceEngine,
	next_id: int,
	current_season: int,
) -> InsurgencyData:
	var roll: int = dice.rand_int_range(1, 100)
	if roll > int(spread_chance * 100):
		return null
	var new_ins := InsurgencyData.new()
	new_ins.insurgency_id = next_id
	new_ins.insurgency_type = ins.insurgency_type
	new_ins.province_id = target_province.province_id
	new_ins.strength = 1
	new_ins.concealment = BASE_CONCEALMENT.get(ins.insurgency_type, 5)
	new_ins.detected = false
	new_ins.seasons_active = 0
	new_ins.season_spawned = current_season
	new_ins.spread_from_id = ins.insurgency_id
	return new_ins


# =============================================================================
# Phase 5 — Suppression (s11.11)
# =============================================================================

const SUPPRESSION_TN_MULTIPLIER: int = 5
const RONIN_TN_MULTIPLIER: int = 7

const SUCCESS_STRENGTH_REDUCTION: int = 3
const PARTIAL_STRENGTH_REDUCTION: int = 1
const CRITICAL_FAIL_STRENGTH_INCREASE: int = 1
const CRITICAL_FAIL_MARGIN: int = 10
const PARTIAL_SUCCESS_MARGIN: int = 5


static func get_suppression_tn(ins: InsurgencyData) -> int:
	var mult: int = SUPPRESSION_TN_MULTIPLIER
	if ins.insurgency_type == Enums.InsurgencyType.RONIN_BANDIT:
		mult = RONIN_TN_MULTIPLIER
	return ins.strength * mult


static func resolve_suppression(
	ins: InsurgencyData,
	roll_total: int,
	has_shugenja: bool,
) -> Dictionary:
	var tn: int = get_suppression_tn(ins)
	var margin: int = roll_total - tn
	var result: Dictionary = {
		"strength_change": 0,
		"outcome": "failure",
		"stability_gain": 0,
		"suppressed": false,
	}

	if margin >= PARTIAL_SUCCESS_MARGIN:
		var reduction: int = SUCCESS_STRENGTH_REDUCTION
		# Maho cult without shugenja: max -1
		if ins.insurgency_type == Enums.InsurgencyType.MAHO_CULT and not has_shugenja:
			reduction = mini(reduction, 1)
		# Taint manifestation without shugenja: max -1
		if ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION and not has_shugenja:
			reduction = mini(reduction, 1)
		ins.strength = maxi(ins.strength - reduction, 0)
		result["strength_change"] = -reduction
		result["outcome"] = "success"
	elif margin >= 0:
		var reduction: int = PARTIAL_STRENGTH_REDUCTION
		if ins.insurgency_type == Enums.InsurgencyType.MAHO_CULT and not has_shugenja:
			reduction = mini(reduction, 1)
		if ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION and not has_shugenja:
			reduction = mini(reduction, 1)
		ins.strength = maxi(ins.strength - reduction, 0)
		result["strength_change"] = -reduction
		result["outcome"] = "partial"
	elif margin <= -CRITICAL_FAIL_MARGIN:
		ins.strength = mini(ins.strength + CRITICAL_FAIL_STRENGTH_INCREASE, 10)
		result["strength_change"] = CRITICAL_FAIL_STRENGTH_INCREASE
		result["outcome"] = "critical_failure"
	else:
		result["outcome"] = "failure"

	if ins.strength <= 0:
		result["suppressed"] = true
		result["stability_gain"] = 5

	return result


# =============================================================================
# Coordinated Suppression (s11.11)
# =============================================================================

static func resolve_coordinated_suppression(
	ins: InsurgencyData,
	participant_rolls: Array,
	has_shugenja: bool,
	leader_bonus: int,
) -> Dictionary:
	var total_reduction: int = 0
	var outcomes: Array = []
	var tn: int = get_suppression_tn(ins)

	for roll: int in participant_rolls:
		var effective: int = roll + leader_bonus
		var margin: int = effective - tn
		if margin >= PARTIAL_SUCCESS_MARGIN:
			var red: int = SUCCESS_STRENGTH_REDUCTION
			if _needs_shugenja(ins.insurgency_type) and not has_shugenja:
				red = mini(red, 1)
			total_reduction += red
			outcomes.append("success")
		elif margin >= 0:
			var red: int = PARTIAL_STRENGTH_REDUCTION
			if _needs_shugenja(ins.insurgency_type) and not has_shugenja:
				red = mini(red, 1)
			total_reduction += red
			outcomes.append("partial")
		elif margin <= -CRITICAL_FAIL_MARGIN:
			total_reduction -= CRITICAL_FAIL_STRENGTH_INCREASE
			outcomes.append("critical_failure")
		else:
			outcomes.append("failure")

	var net_change: int = -total_reduction
	ins.strength = clampi(ins.strength + net_change, 0, 10)

	return {
		"strength_change": net_change,
		"outcomes": outcomes,
		"suppressed": ins.strength <= 0,
		"stability_gain": 5 if ins.strength <= 0 else 0,
	}


static func _needs_shugenja(itype: Enums.InsurgencyType) -> bool:
	return itype == Enums.InsurgencyType.MAHO_CULT or itype == Enums.InsurgencyType.TAINT_MANIFESTATION


# =============================================================================
# Province Taint Level (PTL) (s11.11)
# =============================================================================

static func compute_ptl_change(
	province: ProvinceData,
	_ptl: float,
	active_insurgencies: Array,
	maho_events_this_season: int,
	adjacent_ptls: Dictionary,
	has_jade_stockpile: bool,
	lost_characters_present: int,
	wall_degraded: bool,
	is_shadowlands_adjacent: bool,
	shugenja_purifications: int,
	suppressed_taint_this_season: bool,
) -> float:
	var delta: float = 0.0

	delta += maho_events_this_season

	for ins: InsurgencyData in active_insurgencies:
		if ins.province_id != province.province_id:
			continue
		if ins.insurgency_type == Enums.InsurgencyType.MAHO_CULT:
			delta += 1.0
		if ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION:
			delta += 1.0

	# Maho cult + taint manifestation doubles PTL gain
	var has_maho: bool = false
	var has_taint: bool = false
	for ins: InsurgencyData in active_insurgencies:
		if ins.province_id != province.province_id:
			continue
		if ins.insurgency_type == Enums.InsurgencyType.MAHO_CULT:
			has_maho = true
		if ins.insurgency_type == Enums.InsurgencyType.TAINT_MANIFESTATION:
			has_taint = true
	if has_maho and has_taint:
		delta *= 2.0

	if is_shadowlands_adjacent and wall_degraded:
		delta += 0.5

	delta += lost_characters_present * 0.5

	# Adjacent bleed
	for adj_id: int in adjacent_ptls:
		var adj_ptl: float = adjacent_ptls[adj_id]
		if adj_ptl >= 8.0:
			var bleed: float = 0.5
			if has_jade_stockpile:
				bleed *= 0.5
			delta += bleed
		elif adj_ptl >= 6.0:
			var bleed: float = 0.25
			if has_jade_stockpile:
				bleed *= 0.5
			delta += bleed

	# Losses
	delta -= shugenja_purifications
	if suppressed_taint_this_season:
		delta -= 1.0

	# Natural decay if no gains
	if delta >= 0.0 and maho_events_this_season == 0 and not has_maho and not has_taint:
		delta -= 0.5

	return delta


static func get_ptl_tier(ptl: float) -> String:
	if ptl <= 2.0:
		return "CLEAN"
	if ptl <= 5.0:
		return "TOUCHED"
	if ptl <= 8.0:
		return "CORRUPTED"
	return "BLIGHTED"


static func get_taint_resistance_tn(ptl: float) -> int:
	if ptl <= 2.0:
		return 0
	if ptl <= 5.0:
		return 15
	if ptl <= 8.0:
		return 25
	return 35


# =============================================================================
# Crisis Tiers per Type (s11.11)
# =============================================================================

static func get_crisis_tier(ins: InsurgencyData, ptl: float = 0.0) -> int:
	match ins.insurgency_type:
		Enums.InsurgencyType.MAHO_CULT:
			return 1
		Enums.InsurgencyType.PEASANT_REVOLT:
			if ins.strength >= 5:
				return 2
			return 3
		Enums.InsurgencyType.RONIN_BANDIT:
			return 3
		Enums.InsurgencyType.TAINT_MANIFESTATION:
			if ptl >= 9.0:
				return 1
			if ptl >= 6.0:
				return 2
			return 3
		Enums.InsurgencyType.NEZUMI_INFESTATION:
			if ins.strength >= 8:
				return 2
			return 3
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK:
			if ins.strength >= 8:
				return 2
			if ins.strength >= 5:
				return 3
			return 4
		Enums.InsurgencyType.PIRATE_FLEET:
			return 3
	return 3


# =============================================================================
# Strength 10 Consequences (s11.11)
# =============================================================================

static func get_strength_10_consequence(ins: InsurgencyData) -> String:
	if ins.strength < 10:
		return ""
	match ins.insurgency_type:
		Enums.InsurgencyType.MAHO_CULT:
			return "oni_manifestation"
		Enums.InsurgencyType.PEASANT_REVOLT:
			return "province_seized"
		Enums.InsurgencyType.RONIN_BANDIT:
			return "army_scale_threat"
		Enums.InsurgencyType.TAINT_MANIFESTATION:
			return "oni_manifestation"
		Enums.InsurgencyType.NEZUMI_INFESTATION:
			return "permanent_colony"
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK:
			return "economy_captured"
		Enums.InsurgencyType.PIRATE_FLEET:
			return "blockade"
	return ""


# =============================================================================
# Ronin Hiring Option (s11.11)
# =============================================================================

static func get_ronin_hire_cost(ins: InsurgencyData) -> float:
	if ins.insurgency_type != Enums.InsurgencyType.RONIN_BANDIT:
		return -1.0
	return ins.strength * 2.0


static func attempt_ronin_hire(
	ins: InsurgencyData,
	roll_total: int,
) -> Dictionary:
	if ins.insurgency_type != Enums.InsurgencyType.RONIN_BANDIT:
		return {"result": "invalid"}
	var tn: int = ins.strength * 5
	if roll_total >= tn:
		var result: Dictionary = {"result": "success", "suppressed": true}
		ins.strength = 0
		return result
	else:
		ins.strength = mini(ins.strength + 1, 10)
		return {"result": "failure", "strength_change": 1}


# =============================================================================
# Character Susceptibility Framework (s11.11)
# =============================================================================

static func compute_susceptibility(
	character: L5RCharacterData,
	disposition_to_lord: int,
) -> int:
	var score: int = 0

	# Disposition to lord
	if disposition_to_lord <= -31:
		score += 3
	elif disposition_to_lord <= -11:
		score += 2
	elif disposition_to_lord <= 30:
		score += 1

	# Honor rank
	var honor_rank: int = int(character.honor)
	if honor_rank >= 6:
		score -= 2
	elif honor_rank <= 1:
		score += 2
	elif honor_rank <= 3:
		score += 1

	# Glory rank
	var glory_rank: int = int(character.glory)
	if glory_rank >= 5:
		score -= 1
	elif glory_rank == 0:
		score += 2
	elif glory_rank <= 2:
		score += 1

	# Shourido dominance
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		score += 1

	return score


static func compute_susceptibility_maho(
	character: L5RCharacterData,
	disposition_to_lord: int,
) -> int:
	var base: int = compute_susceptibility(character, disposition_to_lord)
	if character.taint >= 2.0:
		base += 2
	elif character.taint >= 1.0:
		base += 1
	return base


# Ishi characters are completely immune
static func is_immune_to_corruption(character: L5RCharacterData) -> bool:
	return character.shourido_virtue == Enums.ShouridoVirtue.ISHI


# =============================================================================
# Economic Effects (s11.11)
# =============================================================================

static func get_koku_drain(ins: InsurgencyData) -> float:
	match ins.insurgency_type:
		Enums.InsurgencyType.RONIN_BANDIT:
			return ins.strength * 0.05
		Enums.InsurgencyType.PIRATE_FLEET:
			return ins.strength * 0.05
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK:
			if ins.strength <= 3:
				return ins.strength * 0.02
			return ins.strength * 0.03
	return 0.0


static func get_rice_drain(ins: InsurgencyData) -> float:
	if ins.insurgency_type == Enums.InsurgencyType.NEZUMI_INFESTATION:
		if ins.strength >= 10:
			return 1.0
		return ins.strength * 0.1
	return 0.0


static func get_pu_loss_on_suppression(ins: InsurgencyData) -> float:
	if ins.insurgency_type == Enums.InsurgencyType.PEASANT_REVOLT:
		return ins.strength * 0.1
	return 0.0


# =============================================================================
# Seasonal Tick (combines growth, spread checks, stability)
# =============================================================================

static func process_season(
	insurgencies: Array,
	provinces: Dictionary,
	ptls: Dictionary,
	dice: DiceEngine,
	current_season: int,
	next_id_counter: int,
	world_states: Dictionary,
	worship_maluses: Dictionary = {},
) -> Dictionary:
	var new_insurgencies: Array = []
	var events: Array = []
	var id_counter: int = next_id_counter

	# Process existing insurgencies
	for ins: InsurgencyData in insurgencies:
		if ins.detected:
			process_active_growth(ins)
		else:
			var growth_result: Dictionary = process_hidden_growth(ins)
			if growth_result["auto_detected"]:
				events.append({"event": "auto_detected", "insurgency_id": ins.insurgency_id})
			if growth_result["hint_generated"]:
				events.append({"event": "detection_hint", "insurgency_id": ins.insurgency_id})

		# Spread checks
		var province: ProvinceData = provinces.get(ins.province_id)
		if province == null:
			continue
		var threshold: int = DETECTED_SPREAD_THRESHOLD if ins.detected else HIDDEN_SPREAD_THRESHOLD
		if ins.strength >= threshold:
			for adj_id: int in province.adjacent_province_ids:
				var adj_province: ProvinceData = provinces.get(adj_id)
				if adj_province == null:
					continue
				var adj_tier: Enums.StabilityTier = get_stability_tier(adj_province.stability)
				var chance: float = get_spread_chance(ins, adj_tier)
				if chance <= 0.0:
					continue
				var spread_ins: InsurgencyData = try_spread(
					ins, adj_province, chance, dice, id_counter, current_season
				)
				if spread_ins != null:
					new_insurgencies.append(spread_ins)
					events.append({
						"event": "spread",
						"source_id": ins.insurgency_id,
						"new_id": id_counter,
						"target_province": adj_id,
					})
					id_counter += 1

		# Strength 10 consequences
		var consequence: String = get_strength_10_consequence(ins)
		if not consequence.is_empty():
			events.append({
				"event": "strength_10",
				"insurgency_id": ins.insurgency_id,
				"consequence": consequence,
			})

	# Spawn checks for new insurgencies
	for pid: int in provinces:
		var province: ProvinceData = provinces[pid]
		var tier: Enums.StabilityTier = get_stability_tier(province.stability)
		var ptl: float = ptls.get(pid, 0.0)
		var eligible: Array = get_eligible_types(tier, province, ptl)
		var ws: Dictionary = world_states.get(pid, {})

		for itype: int in eligible:
			# Skip if already active of this type
			var already_active: bool = false
			for existing: InsurgencyData in insurgencies:
				if existing.province_id == pid and existing.insurgency_type == itype:
					already_active = true
					break
			if not already_active:
				for new_ins: InsurgencyData in new_insurgencies:
					if new_ins.province_id == pid and new_ins.insurgency_type == itype:
						already_active = true
						break
			if already_active:
				continue

			var chance: float = get_spawn_chance(itype as Enums.InsurgencyType, tier, province, ws)
			var wm: Dictionary = worship_maluses.get(pid, {})
			if wm.get("insurgency_spawn_doubled", false):
				chance *= 2.0
			if chance <= 0.0:
				continue
			var spawned: InsurgencyData = try_spawn(
				itype as Enums.InsurgencyType, province, chance, dice, id_counter, current_season
			)
			if spawned != null:
				new_insurgencies.append(spawned)
				events.append({
					"event": "spawned",
					"insurgency_id": id_counter,
					"type": itype,
					"province_id": pid,
				})
				id_counter += 1

	return {
		"new_insurgencies": new_insurgencies,
		"events": events,
		"next_id": id_counter,
	}
