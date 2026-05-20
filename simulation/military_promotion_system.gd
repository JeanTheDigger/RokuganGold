class_name MilitaryPromotionSystem
## Military promotion, vacancy filling, demotion, and battle record per GDD s11.7a.
## Pure static functions. Caller owns all state.


# -- Minimum Thresholds ----------------------------------------------------------

const CHUI_MIN_BATTLE: int = 3
const TAISA_MIN_BATTLE: int = 4
const TAISA_MIN_BATTLES_AS_CHUI: int = 1
const SHIREIKAN_MIN_BATTLE: int = 5
const SHIREIKAN_MIN_BATTLES_AS_TAISA: int = 2
const RIKUGUNSHOKAN_MIN_BATTLE: int = 5

const HOHEI_TO_NIKUTAI_MIN_BATTLE: int = 2
const HOHEI_TO_NIKUTAI_MIN_BATTLES_FOUGHT: int = 1
const NIKUTAI_TO_GUNSO_MIN_BATTLE: int = 2
const NIKUTAI_TO_GUNSO_MIN_BATTLES_FOUGHT: int = 1


# -- Scoring Weights (by promotion level) ----------------------------------------

const CHUI_WEIGHTS: Dictionary = {
	"battle_skill": 30,
	"insight_rank": 20,
	"school_rank": 15,
	"glory": 10,
	"disposition": 15,
	"personality_fit": 10,
}

const TAISA_WEIGHTS: Dictionary = {
	"battle_skill": 35,
	"insight_rank": 20,
	"battles_commanded": 15,
	"glory": 10,
	"disposition": 10,
	"personality_fit": 10,
}

const SHIREIKAN_WEIGHTS: Dictionary = {
	"battle_skill": 35,
	"battles_commanded": 20,
	"insight_rank": 15,
	"glory": 10,
	"disposition": 10,
	"personality_fit": 10,
}

const RIKUGUNSHOKAN_WEIGHTS: Dictionary = {
	"battle_skill": 30,
	"insight_rank": 15,
	"battles_commanded": 15,
	"glory": 10,
	"disposition": 20,
	"personality_fit": 10,
}


# -- Personality Fit Scores -------------------------------------------------------

const CHUI_PERSONALITY: Dictionary = {
	"YU": 10, "CHUGI": 8, "KETSUI": 6, "SEIGYO": 4,
}

const TAISA_PERSONALITY: Dictionary = {
	"YU": 8, "CHUGI": 8, "SEIGYO": 7, "DOSATSU": 6,
}

const SHIREIKAN_PERSONALITY: Dictionary = {
	"DOSATSU": 10, "SEIGYO": 9, "CHUGI": 8, "YU": 5,
}

const RIKUGUNSHOKAN_PERSONALITY: Dictionary = {
	"DOSATSU": 10, "SEIGYO": 8, "CHUGI": 7, "YU": 6,
}

const GARRISON_PERSONALITY: Dictionary = {
	"SEIGYO": 10, "CHUGI": 8, "DOSATSU": 6,
}


# -- Demotion Constants ----------------------------------------------------------

const DEMOTION_GLORY_LOSS: float = 0.5
const REMOVAL_DISPOSITION_THRESHOLD: int = -10


# -- Battle Record Factory -------------------------------------------------------

static func create_battle_record() -> Dictionary:
	return {
		"battles_fought": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"companies_destroyed_under_command": 0,
	}


static func record_battle(
	battle_record: Dictionary,
	won: bool,
	companies_destroyed: int = 0,
) -> void:
	battle_record["battles_fought"] += 1
	if won:
		battle_record["battles_won"] += 1
	else:
		battle_record["battles_lost"] += 1
	battle_record["companies_destroyed_under_command"] += companies_destroyed


# -- Enlisted Promotion (Below Chui) ---------------------------------------------

static func can_promote_to_nikutai(
	battle_skill: int,
	battles_fought: int,
) -> bool:
	return battle_skill >= HOHEI_TO_NIKUTAI_MIN_BATTLE and battles_fought >= HOHEI_TO_NIKUTAI_MIN_BATTLES_FOUGHT


static func can_promote_to_gunso(
	battle_skill: int,
	battles_fought: int,
	vacancy_exists: bool,
) -> bool:
	return (
		battle_skill >= NIKUTAI_TO_GUNSO_MIN_BATTLE
		and battles_fought >= NIKUTAI_TO_GUNSO_MIN_BATTLES_FOUGHT
		and vacancy_exists
	)


# -- Officer Promotion Eligibility -----------------------------------------------

static func is_eligible_for_chui(
	battle_skill: int,
) -> bool:
	return battle_skill >= CHUI_MIN_BATTLE


static func is_eligible_for_taisa(
	battle_skill: int,
	battles_as_chui: int,
) -> bool:
	return battle_skill >= TAISA_MIN_BATTLE and battles_as_chui >= TAISA_MIN_BATTLES_AS_CHUI


static func is_eligible_for_shireikan(
	battle_skill: int,
	battles_as_taisa: int,
) -> bool:
	return battle_skill >= SHIREIKAN_MIN_BATTLE and battles_as_taisa >= SHIREIKAN_MIN_BATTLES_AS_TAISA


static func is_eligible_for_rikugunshokan(
	battle_skill: int,
) -> bool:
	return battle_skill >= RIKUGUNSHOKAN_MIN_BATTLE


# -- Candidate Scoring -----------------------------------------------------------

static func score_chui_candidate(
	battle_skill: int,
	insight_rank: int,
	school_rank: int,
	glory: float,
	disposition: int,
	personality_virtue: String,
	is_garrison: bool = false,
) -> float:
	var w: Dictionary = CHUI_WEIGHTS
	var personality_table: Dictionary = GARRISON_PERSONALITY if is_garrison else CHUI_PERSONALITY
	var personality_score: float = float(personality_table.get(personality_virtue.to_upper(), 0))

	return (
		float(battle_skill) * w["battle_skill"]
		+ float(insight_rank) * w["insight_rank"]
		+ float(school_rank) * w["school_rank"]
		+ glory * w["glory"]
		+ float(disposition) * 0.5
		+ personality_score * w["personality_fit"]
	)


static func score_taisa_candidate(
	battle_skill: int,
	insight_rank: int,
	battles_commanded: int,
	glory: float,
	disposition: int,
	personality_virtue: String,
) -> float:
	var w: Dictionary = TAISA_WEIGHTS
	var personality_score: float = float(TAISA_PERSONALITY.get(personality_virtue.to_upper(), 0))

	return (
		float(battle_skill) * w["battle_skill"]
		+ float(insight_rank) * w["insight_rank"]
		+ float(battles_commanded) * w["battles_commanded"]
		+ glory * w["glory"]
		+ float(disposition) * 0.5
		+ personality_score * w["personality_fit"]
	)


static func score_shireikan_candidate(
	battle_skill: int,
	insight_rank: int,
	battles_commanded: int,
	glory: float,
	disposition: int,
	personality_virtue: String,
) -> float:
	var w: Dictionary = SHIREIKAN_WEIGHTS
	var personality_score: float = float(SHIREIKAN_PERSONALITY.get(personality_virtue.to_upper(), 0))

	return (
		float(battle_skill) * w["battle_skill"]
		+ float(insight_rank) * w["insight_rank"]
		+ float(battles_commanded) * w["battles_commanded"]
		+ glory * w["glory"]
		+ float(disposition) * 0.5
		+ personality_score * w["personality_fit"]
	)


static func score_rikugunshokan_candidate(
	battle_skill: int,
	insight_rank: int,
	battles_commanded: int,
	glory: float,
	disposition: int,
	personality_virtue: String,
) -> float:
	var w: Dictionary = RIKUGUNSHOKAN_WEIGHTS
	var personality_score: float = float(RIKUGUNSHOKAN_PERSONALITY.get(personality_virtue.to_upper(), 0))

	return (
		float(battle_skill) * w["battle_skill"]
		+ float(insight_rank) * w["insight_rank"]
		+ float(battles_commanded) * w["battles_commanded"]
		+ glory * w["glory"]
		+ float(disposition) * 0.5
		+ personality_score * w["personality_fit"]
	)


# -- Candidate Selection ---------------------------------------------------------

static func select_best_candidate(
	candidates: Array[Dictionary],
	rank: Enums.MilitaryRank,
) -> Dictionary:
	if candidates.is_empty():
		return {}

	var best: Dictionary = {}
	var best_score: float = -999999.0

	for c: Dictionary in candidates:
		var eligible: bool = false
		var score: float = 0.0

		match rank:
			Enums.MilitaryRank.CHUI:
				eligible = is_eligible_for_chui(c.get("battle_skill", 0))
				if eligible:
					score = score_chui_candidate(
						c.get("battle_skill", 0),
						c.get("insight_rank", 0),
						c.get("school_rank", 0),
						c.get("glory", 0.0),
						c.get("disposition", 0),
						c.get("personality_virtue", ""),
						c.get("is_garrison", false),
					)
			Enums.MilitaryRank.TAISA:
				eligible = is_eligible_for_taisa(
					c.get("battle_skill", 0),
					c.get("battles_as_chui", 0),
				)
				if eligible:
					score = score_taisa_candidate(
						c.get("battle_skill", 0),
						c.get("insight_rank", 0),
						c.get("battles_commanded", 0),
						c.get("glory", 0.0),
						c.get("disposition", 0),
						c.get("personality_virtue", ""),
					)
			Enums.MilitaryRank.SHIREIKAN:
				eligible = is_eligible_for_shireikan(
					c.get("battle_skill", 0),
					c.get("battles_as_taisa", 0),
				)
				if eligible:
					score = score_shireikan_candidate(
						c.get("battle_skill", 0),
						c.get("insight_rank", 0),
						c.get("battles_commanded", 0),
						c.get("glory", 0.0),
						c.get("disposition", 0),
						c.get("personality_virtue", ""),
					)
			Enums.MilitaryRank.RIKUGUNSHOKAN:
				eligible = is_eligible_for_rikugunshokan(
					c.get("battle_skill", 0),
				)
				if eligible:
					score = score_rikugunshokan_candidate(
						c.get("battle_skill", 0),
						c.get("insight_rank", 0),
						c.get("battles_commanded", 0),
						c.get("glory", 0.0),
						c.get("disposition", 0),
						c.get("personality_virtue", ""),
					)

		if eligible and score > best_score:
			best_score = score
			best = c.duplicate()
			best["score"] = score

	return best


# -- Demotion & Removal ----------------------------------------------------------

static func should_remove_for_disposition(
	disposition_toward_lord: int,
) -> bool:
	return disposition_toward_lord < REMOVAL_DISPOSITION_THRESHOLD


static func apply_demotion(
	character_data: Dictionary,
) -> Dictionary:
	var old_rank: int = character_data.get("military_rank", 0)
	character_data["military_rank"] = Enums.MilitaryRank.NONE
	character_data["commanded_unit_id"] = -1
	return {
		"old_rank": old_rank,
		"glory_loss": DEMOTION_GLORY_LOSS,
	}


# -- Vacancy Detection -----------------------------------------------------------

static func find_vacancies(
	units: Array[Dictionary],
) -> Array:
	var vacancies: Array[Dictionary] = []
	for u: Dictionary in units:
		if u.get("commander_id", -1) < 0:
			vacancies.append({
				"unit_id": u.get("unit_id", -1),
				"rank_needed": u.get("rank_needed", Enums.MilitaryRank.CHUI),
			})
	return vacancies
