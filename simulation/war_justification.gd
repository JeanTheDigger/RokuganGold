class_name WarJustification
## War justification and casus belli evaluation per GDD s53.1.
## Five-step decision sequence determining whether an AI lord can initiate
## military action. Pure static functions.


# -- Tier Classification ---------------------------------------------------------

enum MilitaryTier {
	RAID,
	FORMAL_WAR,
	TOTAL_WAR,
}


# -- Standing Objectives → Justified Tiers (s53.1) ------------------------------

const STANDING_OBJECTIVE_TIERS: Dictionary = {
	"EXPAND_TERRITORY": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"MILITARY_DOMINANCE": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR],
	"ELIMINATE_SHADOWLANDS": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"STRENGTHEN_WALL": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR],
	"BUILD_STRONGEST_FORCE": [MilitaryTier.RAID],
	"SEEK_VENGEANCE": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"ADVANCE_GLORY": [MilitaryTier.RAID],
	"UNDERMINE_CLAN": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR],
	"PREVENT_SHORTAGE": [MilitaryTier.RAID],
}

const SITUATIONAL_OBJECTIVES: Dictionary = {
	"ADVANCE_FAMILY": [MilitaryTier.RAID],
	"CONTROL_TRADE": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR],
	"HONOR_ANCESTORS": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"ELEVATE_FAMILY": [MilitaryTier.RAID],
	"PERSONAL_EXCELLENCE": [MilitaryTier.RAID],
}

const PEACE_OBJECTIVES: Array[String] = [
	"MAINTAIN_BALANCE",
	"MAINTAIN_PEACE",
	"STRENGTHEN_IMPERIAL",
	"ACCUMULATE_LEVERAGE",
	"MAXIMIZE_PROSPERITY",
	"PROTECT_DEPENDENTS",
	"ACCUMULATE_KNOWLEDGE",
	"LIVE_BY_BUSHIDO",
]


# -- Primary Objectives → Justified Tiers (s53.1) -------------------------------

const PRIMARY_OBJECTIVE_TIERS: Dictionary = {
	"CONQUER_PROVINCE": [MilitaryTier.FORMAL_WAR],
	"DEFEND_PROVINCE": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"RESOLVE_SHADOWLANDS_INCURSION": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"DESTROY_ARMY": [MilitaryTier.FORMAL_WAR],
	"RELIEVE_SIEGE": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"RESTORE_ORDER": [MilitaryTier.RAID],
	"SECURE_TRADE_ROUTE": [MilitaryTier.RAID],
	"SABOTAGE_ECONOMY": [MilitaryTier.RAID],
	"AVENGE": [MilitaryTier.RAID, MilitaryTier.FORMAL_WAR, MilitaryTier.TOTAL_WAR],
	"ELIMINATE_CHARACTER": [MilitaryTier.RAID],
}


# -- Personality-Driven Aggression Virtues (s53.1) -------------------------------

const AGGRESSION_BUSHIDO: Array[String] = ["YU"]
const AGGRESSION_SHOURIDO: Array[String] = ["KYORYOKU", "KETSUI"]


# -- Personality Gates (s53.1) ---------------------------------------------------

const JIN_EXHAUST_GATE: Array[String] = [
	"EXPAND_TERRITORY",
]

const JIN_TOTAL_WAR_BLOCK: Array[String] = [
	"SEEK_VENGEANCE",
]

const GI_MAKOTO_COVERT_BLOCK: Array[String] = [
	"UNDERMINE_CLAN", "SABOTAGE_ECONOMY", "ELIMINATE_CHARACTER",
]

const PREVENT_SHORTAGE_BLOCKED_VIRTUES: Array[String] = [
	"JIN", "GI",
]


# -- Step 1: Objective Justification ---------------------------------------------

static func get_objective_tiers(
	standing_objective: String,
	primary_objective: String,
) -> Array:
	if PRIMARY_OBJECTIVE_TIERS.has(primary_objective):
		return PRIMARY_OBJECTIVE_TIERS[primary_objective]

	if STANDING_OBJECTIVE_TIERS.has(standing_objective):
		return STANDING_OBJECTIVE_TIERS[standing_objective]

	if SITUATIONAL_OBJECTIVES.has(standing_objective):
		return SITUATIONAL_OBJECTIVES[standing_objective]

	return []


static func is_objective_justified(
	standing_objective: String,
	primary_objective: String,
) -> bool:
	if standing_objective in PEACE_OBJECTIVES:
		if primary_objective == "DEFEND_PROVINCE":
			return true
		return false
	return not get_objective_tiers(standing_objective, primary_objective).is_empty()


# -- Step 2: Personality-Driven Aggression ----------------------------------------

static func qualifies_for_personality_aggression(
	primary_virtue: String,
	standing_objective: String,
) -> bool:
	var virtue_upper: String = primary_virtue.to_upper()
	var has_virtue: bool = (
		virtue_upper in AGGRESSION_BUSHIDO
		or virtue_upper in AGGRESSION_SHOURIDO
	)
	if not has_virtue:
		return false
	if standing_objective in PEACE_OBJECTIVES:
		return false
	return true


const GARRISON_MINIMUM_RATIO: float = 0.05


static func is_garrison_at_minimum(garrison_pu: int, total_settlement_pu: int) -> bool:
	if total_settlement_pu <= 0:
		return garrison_pu <= 0
	var required: float = total_settlement_pu * GARRISON_MINIMUM_RATIO
	return float(garrison_pu) <= required


static func evaluate_province_weakness(
	ps: NPCDataStructures.ProvinceStatus,
) -> Dictionary:
	var at_minimum: bool = is_garrison_at_minimum(
		ps.garrison_pu, ps.total_settlement_pu,
	)
	var no_army: bool = not ps.has_field_army_nearby
	var no_alliance: bool = not ps.has_alliance_protection
	var is_weak: bool = at_minimum and no_army and no_alliance
	return {
		"is_weak": is_weak,
		"garrison_at_minimum": at_minimum,
		"no_field_army_nearby": no_army,
		"no_alliance_protection": no_alliance,
	}


static func check_raid_weakness(
	target_garrison_at_minimum: bool,
	no_field_army_nearby: bool,
	no_alliance_protection: bool,
) -> bool:
	return target_garrison_at_minimum and no_field_army_nearby and no_alliance_protection


static func check_formal_war_weakness(
	raid_weakness_met: bool,
	attacker_pu: float,
	defender_observable_pu: float,
) -> bool:
	if not raid_weakness_met:
		return false
	if defender_observable_pu <= 0.0:
		return true
	return attacker_pu >= defender_observable_pu * 2.0


# -- Step 3: Tier Validation ------------------------------------------------------

static func is_tier_supported(
	tier: MilitaryTier,
	standing_objective: String,
	primary_objective: String,
) -> bool:
	var supported: Array = get_objective_tiers(standing_objective, primary_objective)
	return tier in supported


# -- Step 4: Personality Gates ----------------------------------------------------

static func check_personality_gate(
	tier: MilitaryTier,
	standing_objective: String,
	primary_objective: String,
	primary_virtue: String,
) -> Dictionary:
	var blocked: bool = false
	var reason: String = ""
	var virtue_upper: String = primary_virtue.to_upper()

	if virtue_upper == "JIN":
		if standing_objective in JIN_TOTAL_WAR_BLOCK:
			if tier == MilitaryTier.TOTAL_WAR:
				blocked = true
				reason = "jin_blocks_total_war"
		if standing_objective in JIN_EXHAUST_GATE:
			if tier == MilitaryTier.TOTAL_WAR:
				blocked = true
				reason = "jin_blocks_total_war"
		if standing_objective == "PREVENT_SHORTAGE":
			blocked = true
			reason = "jin_blocks_resource_raid"

	if virtue_upper == "GI" or virtue_upper == "MAKOTO":
		if standing_objective in GI_MAKOTO_COVERT_BLOCK:
			blocked = true
			reason = "gi_makoto_blocks_covert_warfare"
		if primary_objective in GI_MAKOTO_COVERT_BLOCK:
			blocked = true
			reason = "gi_makoto_blocks_covert_warfare"

	if virtue_upper in PREVENT_SHORTAGE_BLOCKED_VIRTUES:
		if standing_objective == "PREVENT_SHORTAGE":
			blocked = true
			reason = "%s_blocks_resource_raid" % virtue_upper.to_lower()

	return {"blocked": blocked, "reason": reason}


# -- Tier Selection by Personality -----------------------------------------------

const TIER_ORDER: Array[int] = [
	MilitaryTier.RAID,
	MilitaryTier.FORMAL_WAR,
	MilitaryTier.TOTAL_WAR,
]

const AUTHORITY_FOR_TIER: Dictionary = {
	MilitaryTier.RAID: WarData.AuthorityLevel.PROVINCIAL_RAID,
	MilitaryTier.FORMAL_WAR: WarData.AuthorityLevel.BORDER_CONFLICT,
	MilitaryTier.TOTAL_WAR: WarData.AuthorityLevel.CLAN_WAR,
}


static func select_intended_tier(
	standing_objective: String,
	primary_objective: String,
	primary_virtue: String,
) -> MilitaryTier:
	var supported: Array = get_objective_tiers(standing_objective, primary_objective)
	if supported.is_empty():
		return MilitaryTier.RAID

	var virtue_upper: String = primary_virtue.to_upper()
	var is_aggressive: bool = (
		virtue_upper in AGGRESSION_BUSHIDO
		or virtue_upper in AGGRESSION_SHOURIDO
	)

	if is_aggressive:
		for i: int in range(TIER_ORDER.size() - 1, -1, -1):
			if TIER_ORDER[i] in supported:
				var candidate: MilitaryTier = TIER_ORDER[i] as MilitaryTier
				var gate: Dictionary = check_personality_gate(
					candidate, standing_objective, primary_objective, primary_virtue,
				)
				if not gate["blocked"]:
					return candidate
		return supported[0] as MilitaryTier

	for tier_val: Variant in supported:
		var t: MilitaryTier = tier_val as MilitaryTier
		var gate: Dictionary = check_personality_gate(
			t, standing_objective, primary_objective, primary_virtue,
		)
		if not gate["blocked"]:
			return t
	return supported[0] as MilitaryTier


static func get_authority_for_tier(tier: MilitaryTier) -> int:
	return AUTHORITY_FOR_TIER.get(tier, WarData.AuthorityLevel.PROVINCIAL_RAID)


# -- Full 5-Step Decision Sequence ------------------------------------------------

static func evaluate_war_justification(
	standing_objective: String,
	primary_objective: String,
	intended_tier: MilitaryTier,
	primary_virtue: String,
	target_garrison_at_minimum: bool = false,
	no_field_army_nearby: bool = false,
	no_alliance_protection: bool = false,
	attacker_pu: float = 0.0,
	defender_observable_pu: float = 0.0,
	feasibility_inputs: Dictionary = {},
) -> Dictionary:
	# Step 1: Objective justification
	var objective_justified: bool = is_objective_justified(
		standing_objective, primary_objective,
	)

	# Step 2: Personality-driven aggression (fallback if Step 1 fails)
	var personality_aggression: bool = false
	if not objective_justified:
		personality_aggression = qualifies_for_personality_aggression(
			primary_virtue, standing_objective,
		)
		if personality_aggression:
			var raid_weak: bool = check_raid_weakness(
				target_garrison_at_minimum, no_field_army_nearby,
				no_alliance_protection,
			)
			if not raid_weak:
				return {
					"justified": false,
					"reason": "weakness_condition_not_met",
					"step_failed": 2,
				}
			if intended_tier == MilitaryTier.FORMAL_WAR or intended_tier == MilitaryTier.TOTAL_WAR:
				var formal_weak: bool = check_formal_war_weakness(
					raid_weak, attacker_pu, defender_observable_pu,
				)
				if not formal_weak:
					return {
						"justified": false,
						"reason": "formal_war_weakness_not_met",
						"step_failed": 2,
					}
		else:
			return {
				"justified": false,
				"reason": "no_objective_justification",
				"step_failed": 1,
			}

	# Step 3: Tier validation (only for objective-justified, not personality)
	if objective_justified and not personality_aggression:
		if not is_tier_supported(
			intended_tier, standing_objective, primary_objective,
		):
			return {
				"justified": false,
				"reason": "tier_not_supported",
				"step_failed": 3,
			}

	# Step 4: Personality gates
	var gate: Dictionary = check_personality_gate(
		intended_tier, standing_objective, primary_objective, primary_virtue,
	)
	if gate["blocked"]:
		return {
			"justified": false,
			"reason": gate["reason"],
			"step_failed": 4,
		}

	# Step 5: Feasibility Ledger
	if not feasibility_inputs.is_empty():
		var ledger: Dictionary = FeasibilityLedger.evaluate_feasibility(
			feasibility_inputs,
		)
		if not ledger["feasible"]:
			var ladder_ctx: Dictionary = feasibility_inputs.get("ladder_context", {})
			if not ladder_ctx.is_empty():
				var ladder_result: Dictionary = _run_alternative_ladder(
					feasibility_inputs, primary_virtue, ladder_ctx,
					standing_objective,
				)
				if ladder_result.get("outcome", "") == "desperation_override" or (
					ladder_result.has("final_ledger")
					and ladder_result["final_ledger"].get("feasible", false)
				):
					var reason_str: String = (
						"personality_aggression" if personality_aggression
						else "objective_justified"
					)
					return {
						"justified": true,
						"reason": reason_str,
						"step_failed": 0,
						"personality_driven": personality_aggression,
						"feasibility": ladder_result.get("final_ledger", ledger),
						"ladder_outcome": ladder_result["outcome"],
						"ladder_side_effects": ladder_result.get("side_effects", {}),
						"ladder_rungs_tried": ladder_result.get("rungs_tried", []),
					}
			return {
				"justified": false,
				"reason": "feasibility_failed",
				"step_failed": 5,
				"personality_driven": personality_aggression,
				"feasibility": ledger,
			}
		return {
			"justified": true,
			"reason": "personality_aggression" if personality_aggression else "objective_justified",
			"step_failed": 0,
			"personality_driven": personality_aggression,
			"feasibility": ledger,
		}

	return {
		"justified": true,
		"reason": "personality_aggression" if personality_aggression else "objective_justified",
		"step_failed": 0,
		"personality_driven": personality_aggression,
	}


static func _run_alternative_ladder(
	feasibility_inputs: Dictionary,
	primary_virtue: String,
	ladder_ctx: Dictionary,
	standing_objective: String,
) -> Dictionary:
	var current_season: String = ladder_ctx.get("current_season", "spring")
	var vassal_stockpiles: Array = ladder_ctx.get("vassal_stockpiles", [])
	var allied_surplus: Array = ladder_ctx.get("allied_surplus", [])
	var raidable_provinces: Array = ladder_ctx.get("raidable_provinces", [])
	var has_trade_routes: bool = ladder_ctx.get("has_trade_routes", false)
	var has_grievance: bool = ladder_ctx.get("has_grievance", false)
	var has_issued_demand: bool = ladder_ctx.get("has_issued_demand", false)
	var war_score: int = ladder_ctx.get("war_score", 50)
	var is_defending: bool = ladder_ctx.get("is_defending", false)

	var has_critical: bool = standing_objective in [
		"DEFEND_PROVINCE", "DEFEND_TERRITORY",
		"RESOLVE_CLAN_WAR", "RESOLVE_SHADOWLANDS_INCURSION",
		"SEEK_VENGEANCE", "AVENGE",
	]

	return FeasibilityLedger.walk_alternative_ladder(
		feasibility_inputs, primary_virtue, current_season,
		vassal_stockpiles, allied_surplus, raidable_provinces,
		has_trade_routes, has_grievance, has_issued_demand,
		has_critical, war_score, is_defending,
	)
