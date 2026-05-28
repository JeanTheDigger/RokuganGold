class_name LevySystem
## Levy authority, mobilization, and disbanding per GDD s11.7a.
## Provincial Daimyo can raise Peasant Levy and Ashigaru from settlement PU.
## Levy Companies exist outside the Go-hatamoto hierarchy.
## Pure static functions. Caller owns all state.


# -- Constants -------------------------------------------------------------------

const LEVY_UNIT_TYPES: Array[int] = [
	Enums.CompanyUnitType.PEASANT_LEVY,
	Enums.CompanyUnitType.ASHIGARU_SPEARMEN,
	Enums.CompanyUnitType.ASHIGARU_ARCHERS,
]

const PU_PER_COMPANY: float = 1.0

const SUSPICION_THRESHOLD_SEASONS: int = 1
const SUSPICION_ESCALATION_SEASONS: int = 3
const SUSPICION_DISPOSITION_LOSS_PER_SEASON: int = -5
const SUSPICION_NEIGHBOR_DISPOSITION_LOSS: int = -3

const TOPIC_TIER_INITIAL: int = TopicData.Tier.TIER_4
const TOPIC_TIER_ESCALATED: int = TopicData.Tier.TIER_3


# -- Commitment Protection Scores -----------------------------------------------

const COMMITMENT_SCORES: Dictionary = {
	"yojimbo_high_status": -30,
	"yojimbo_mid_status": -15,
	"magistrate_insurgency": -25,
	"magistrate_stable": -15,
	"yoriki_active": -10,
	"yoriki_idle": -5,
	"courtier_imperial": -15,
	"courtier_clan": -10,
	"shugenja_shrine": -5,
	"uncommitted": 0,
}

const PERSONALITY_MODIFIERS: Dictionary = {
	"JIN": {"yojimbo_multiplier": 2.0, "penalty_modifier": 0},
	"YU": {"yojimbo_multiplier": 1.0, "penalty_modifier": 0, "halve_penalties": true},
	"SEIGYO": {"yojimbo_multiplier": 1.0, "penalty_modifier": 0, "keep_political": true},
	"CHUGI": {"yojimbo_multiplier": 1.0, "penalty_modifier": -10},
}


# -- Levy Mobilization -----------------------------------------------------------

static func can_raise_levy(
	settlement_military_pu: float,
	settlement_garrison_pu: float,
	unit_type: Enums.CompanyUnitType,
) -> Dictionary:
	if unit_type not in LEVY_UNIT_TYPES:
		return {"can_raise": false, "reason": "invalid_unit_type"}

	var available_pu: float = settlement_military_pu - settlement_garrison_pu
	if available_pu < PU_PER_COMPANY:
		return {"can_raise": false, "reason": "insufficient_pu", "available": available_pu}

	return {"can_raise": true, "available_pu": available_pu}


static func raise_levy(
	company_id: int,
	unit_type: Enums.CompanyUnitType,
	lord_id: int,
	source_province_id: int,
	source_settlement_id: int,
) -> Dictionary:
	if unit_type not in LEVY_UNIT_TYPES:
		return {"success": false, "reason": "invalid_unit_type"}

	var company: MilitaryUnitData.CompanyData = ArmyCombatSystem.create_company(
		company_id, unit_type,
	)
	company.parent_legion_id = -1
	company.commander_id = -1
	company.source_province_id = source_province_id

	return {
		"success": true,
		"company": company,
		"lord_id": lord_id,
		"source_settlement_id": source_settlement_id,
		"pu_consumed": PU_PER_COMPANY,
		"arms_cost": ArmyUpkeepSystem.get_arms_equip_cost(unit_type),
	}


static func assign_commander(
	company: MilitaryUnitData.CompanyData,
	commander_id: int,
) -> void:
	company.commander_id = commander_id


# -- Disbanding ------------------------------------------------------------------

static func disband_levy(
	company: MilitaryUnitData.CompanyData,
) -> Dictionary:
	var pu_returned: float = PU_PER_COMPANY
	var health_ratio: float = float(company.health) / float(ArmyCombatSystem.UNIT_STATS[company.unit_type]["health"])  # Use actual starting health (153 for standard units)
	if health_ratio < 1.0:
		pu_returned *= health_ratio

	return {
		"pu_returned": pu_returned,
		"arms_retained": true,
		"source_province_id": company.source_province_id,
	}


# -- Private Army Suspicion ------------------------------------------------------

static func check_suspicion(
	seasons_maintained: int,
	is_wartime: bool,
) -> Dictionary:
	if is_wartime:
		return {"suspicion": false, "topic_tier": 0, "disposition_loss": 0}

	if seasons_maintained < SUSPICION_THRESHOLD_SEASONS:
		return {"suspicion": false, "topic_tier": 0, "disposition_loss": 0}

	var topic_tier: int = TOPIC_TIER_INITIAL
	if seasons_maintained >= SUSPICION_ESCALATION_SEASONS:
		topic_tier = TOPIC_TIER_ESCALATED

	var total_loss: int = seasons_maintained * SUSPICION_DISPOSITION_LOSS_PER_SEASON

	return {
		"suspicion": true,
		"topic_tier": topic_tier,
		"disposition_loss_lord": total_loss,
		"disposition_loss_neighbor": SUSPICION_NEIGHBOR_DISPOSITION_LOSS,
		"escalated": seasons_maintained >= SUSPICION_ESCALATION_SEASONS,
	}


# -- Commitment Protection -------------------------------------------------------

static func get_commitment_score(role: String) -> int:
	return COMMITMENT_SCORES.get(role, 0)


static func evaluate_candidate(
	candidate_role: String,
	personality_virtue: String,
) -> int:
	var base_score: int = get_commitment_score(candidate_role)
	var mods: Dictionary = PERSONALITY_MODIFIERS.get(personality_virtue.to_upper(), {})

	if mods.is_empty():
		return base_score

	if candidate_role.begins_with("yojimbo"):
		var mult: float = mods.get("yojimbo_multiplier", 1.0)
		base_score = roundi(float(base_score) * mult)

	if mods.get("halve_penalties", false) and base_score < 0:
		base_score = int(base_score / 2)

	var penalty_mod: int = mods.get("penalty_modifier", 0)
	if base_score < 0 and penalty_mod != 0:
		base_score = mini(base_score - penalty_mod, 0)

	return base_score


static func rank_candidates(
	candidates: Array,
	personality_virtue: String,
) -> Array:
	var scored: Array = []
	for c: Dictionary in candidates:
		var role: String = c.get("role", "uncommitted")
		var score: int = evaluate_candidate(role, personality_virtue)
		scored.append({
			"character_id": c["character_id"],
			"role": role,
			"commitment_score": score,
		})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["commitment_score"] > b["commitment_score"]
	)
	return scored


# -- Dual Authority Check --------------------------------------------------------

static func has_dual_authority(
	is_daimyo: bool,
	military_rank: Enums.MilitaryRank,
) -> bool:
	if not is_daimyo:
		return false
	return military_rank >= Enums.MilitaryRank.TAISA


# -- Available Levy Count --------------------------------------------------------

static func get_max_levy_companies(
	settlement_military_pu: float,
	settlement_garrison_pu: float,
) -> int:
	var available: float = settlement_military_pu - settlement_garrison_pu
	return maxi(floori(available / PU_PER_COMPANY), 0)
