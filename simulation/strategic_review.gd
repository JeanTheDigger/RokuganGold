class_name StrategicReview
## Lord-tier seasonal Strategic Review per GDD s55.10.
## Runs at each seasonal tick for lord-tier NPCs.
## Produces directives: Reassign Vassal Objectives, Adjust Tax/Stipend,
## War Readiness, Seek Peace, Call Court, or No Change.


enum Directive {
	NO_CHANGE,
	REASSIGN_VASSAL_OBJECTIVE,
	ADJUST_TAX,
	WAR_READINESS,
	SEEK_PEACE,
	CALL_COURT,
}

enum EmperorArchetype {
	BENEVOLENT,
	IRON,
	CUNNING,
	WARLIKE,
	TYRANT,
}

const ARCHETYPE_TAX_MODIFIER: Dictionary = {
	EmperorArchetype.BENEVOLENT: -5,
	EmperorArchetype.IRON: 0,
	EmperorArchetype.CUNNING: 0,
	EmperorArchetype.WARLIKE: 5,
	EmperorArchetype.TYRANT: 10,
}

const ARCHETYPE_VACANCY_DELAY: Dictionary = {
	EmperorArchetype.BENEVOLENT: 14,
	EmperorArchetype.IRON: 14,
	EmperorArchetype.CUNNING: 45,
	EmperorArchetype.WARLIKE: 14,
	EmperorArchetype.TYRANT: 14,
}

const WARLIKE_POLITICAL_VACANCY_DELAY: int = 45

const ARCHETYPE_VACANCY_MIN_SEASONS: Dictionary = {
	EmperorArchetype.BENEVOLENT: {"military": 0, "political": 0},
	EmperorArchetype.IRON: {"military": 0, "political": 0},
	EmperorArchetype.CUNNING: {"military": 1, "political": 1},
	EmperorArchetype.WARLIKE: {"military": 0, "political": 1},
	EmperorArchetype.TYRANT: {"military": 0, "political": 0},
}

const WARLIKE_BUSHI_CHAMPION_BASELINE: int = 15
const WARLIKE_COURTIER_CHAMPION_BASELINE: int = 0

const CUNNING_CLAN_BALANCE_WEIGHT: int = 25

const ARCHETYPE_DISPOSITION_WEIGHT: Dictionary = {
	EmperorArchetype.BENEVOLENT: 15,
	EmperorArchetype.IRON: 10,
	EmperorArchetype.CUNNING: 15,
	EmperorArchetype.WARLIKE: 15,
	EmperorArchetype.TYRANT: 30,
}

const ARCHETYPE_SKILL_WEIGHT: Dictionary = {
	EmperorArchetype.BENEVOLENT: 20,
	EmperorArchetype.IRON: 25,
	EmperorArchetype.CUNNING: 15,
	EmperorArchetype.WARLIKE: 20,
	EmperorArchetype.TYRANT: 5,
}

const ORPHAN_RESOLUTION_BY_VIRTUE: Dictionary = {
	Enums.BushidoVirtue.CHUGI: "CONFIRM",
	Enums.BushidoVirtue.GI: "MODIFY",
	Enums.BushidoVirtue.JIN: "CANCEL",
	Enums.BushidoVirtue.MEIYO: "CONFIRM",
	Enums.BushidoVirtue.MAKOTO: "MODIFY",
	Enums.BushidoVirtue.REI: "MODIFY",
	Enums.BushidoVirtue.YU: "CONFIRM",
}

const TYRANT_STABILITY_PENALTY: float = -2.0
const TYRANT_COURT_HONOR_PENALTY: float = -0.5
const BREAKING_POINT_CLAN_COUNT: int = 3

const GREAT_CLANS: Array[String] = [
	"Crab", "Crane", "Dragon", "Lion", "Mantis", "Phoenix", "Scorpion", "Unicorn",
]


static func derive_emperor_archetype(emperor: L5RCharacterData) -> int:
	var bv: int = emperor.bushido_virtue
	var sv: int = emperor.shourido_virtue
	# Tyrant: Ishi shourido with no strong bushido counterbalance (s55.10)
	if sv == Enums.ShouridoVirtue.ISHI:
		if bv == Enums.BushidoVirtue.NONE or bv == Enums.BushidoVirtue.MEIYO:
			return EmperorArchetype.TYRANT
	# Bushido-dominant archetypes
	if bv == Enums.BushidoVirtue.JIN:
		return EmperorArchetype.BENEVOLENT
	if bv == Enums.BushidoVirtue.CHUGI or bv == Enums.BushidoVirtue.MEIYO:
		return EmperorArchetype.IRON
	if bv == Enums.BushidoVirtue.YU:
		return EmperorArchetype.WARLIKE
	# Shourido-dominant archetypes (bushido is NONE or weak)
	if sv == Enums.ShouridoVirtue.KYORYOKU:
		return EmperorArchetype.WARLIKE
	if sv == Enums.ShouridoVirtue.SEIGYO or sv == Enums.ShouridoVirtue.DOSATSU:
		return EmperorArchetype.CUNNING
	return EmperorArchetype.IRON


static func run_seasonal_review(
	lord: L5RCharacterData,
	vassals: Array,
	objectives_map: Dictionary,
	world_state: Dictionary,
) -> Array:
	var directives: Array = []

	var self_select: Dictionary = _evaluate_self_selection(lord, objectives_map, world_state)
	if not self_select.is_empty():
		directives.append(self_select)

	var orphan_directives: Array = _resolve_orphaned_vassals(
		lord, vassals, objectives_map
	)
	directives.append_array(orphan_directives)

	var court_directive: Dictionary = _evaluate_call_court(lord, vassals, world_state)
	if not court_directive.is_empty():
		directives.append(court_directive)

	var reassign_directives: Array = _evaluate_vassal_objectives(
		lord, vassals, objectives_map, world_state
	)
	directives.append_array(reassign_directives)

	var tax_directive: Dictionary = _evaluate_tax_adjustment(lord, world_state)
	if not tax_directive.is_empty():
		directives.append(tax_directive)

	var war_directive: Dictionary = _evaluate_war_readiness(lord, world_state)
	if not war_directive.is_empty():
		directives.append(war_directive)

	var peace_directive: Dictionary = _evaluate_seek_peace(lord, world_state)
	if not peace_directive.is_empty():
		directives.append(peace_directive)

	if directives.is_empty():
		directives.append({"directive": Directive.NO_CHANGE, "lord_id": lord.character_id})

	return directives


static func _resolve_orphaned_vassals(
	lord: L5RCharacterData,
	vassals: Array,
	objectives_map: Dictionary,
) -> Array:
	var results: Array = []

	var orphaned_ids: Array = OrphanedObjectives.has_orphaned_vassals(
		vassals, lord.character_id, objectives_map
	)
	if orphaned_ids.is_empty():
		return results

	var decision: String = _get_orphan_resolution_for_personality(lord)

	for vassal_id: int in orphaned_ids:
		var vassal_objectives: Dictionary = objectives_map.get(vassal_id, {})
		var resolution: Dictionary = OrphanedObjectives.resolve_orphaned_objective(
			vassal_objectives, decision
		)
		results.append({
			"directive": Directive.REASSIGN_VASSAL_OBJECTIVE,
			"lord_id": lord.character_id,
			"vassal_id": vassal_id,
			"decision": decision,
			"resolution": resolution,
		})

	return results


static func _get_orphan_resolution_for_personality(lord: L5RCharacterData) -> String:
	if ORPHAN_RESOLUTION_BY_VIRTUE.has(lord.bushido_virtue):
		return ORPHAN_RESOLUTION_BY_VIRTUE[lord.bushido_virtue]
	return "CONFIRM"


static func _evaluate_call_court(
	lord: L5RCharacterData,
	vassals: Array,
	world_state: Dictionary,
) -> Dictionary:
	var last_court_season: int = world_state.get("last_court_season", -1)
	var current_season: int = world_state.get("current_season", 0)

	if last_court_season == current_season:
		return {}

	var active_crises: Array = world_state.get("active_crises", [])
	var vassal_count: int = vassals.size()

	var court_score: int = 0
	court_score += vassal_count * 5
	court_score += active_crises.size() * 10

	if current_season == TimeSystem.Season.WINTER:
		court_score += 20

	if lord.bushido_virtue == Enums.BushidoVirtue.REI:
		court_score += 15

	if court_score >= 30:
		return {
			"directive": Directive.CALL_COURT,
			"lord_id": lord.character_id,
			"score": court_score,
			"season": current_season,
		}

	return {}


static func _evaluate_vassal_objectives(
	lord: L5RCharacterData,
	vassals: Array,
	objectives_map: Dictionary,
	world_state: Dictionary,
) -> Array:
	var results: Array = []

	var province_statuses: Array = world_state.get("province_statuses", [])
	var triage_results: Array = ProvinceTriage.get_top_provinces(
		province_statuses, 3
	)

	var threats: Array = world_state.get("province_threats", [])
	if threats.is_empty() and not triage_results.is_empty():
		for t: ProvinceTriage.TriageResult in triage_results:
			if t.score >= ProvinceTriage.SCORE_VOLATILE_STABILITY:
				threats.append({"type": "instability", "target_province_id": t.province_id})

	var idle_vassals: Array = []
	for vassal: L5RCharacterData in vassals:
		if vassal.lord_id != lord.character_id:
			continue
		var objectives: Dictionary = objectives_map.get(vassal.character_id, {})
		var primary: Dictionary = objectives.get("primary", {})
		if primary.is_empty() or primary.get("status", "") == "COMPLETED":
			idle_vassals.append(vassal.character_id)

	for vassal_id: int in idle_vassals:
		var new_objective: Dictionary = _select_objective_for_vassal(
			lord, vassal_id, threats, world_state
		)
		if new_objective.is_empty():
			continue
		results.append({
			"directive": Directive.REASSIGN_VASSAL_OBJECTIVE,
			"lord_id": lord.character_id,
			"vassal_id": vassal_id,
			"decision": "ASSIGN",
			"new_objective": new_objective,
		})

	return results


static func _select_objective_for_vassal(
	lord: L5RCharacterData,
	_vassal_id: int,
	threats: Array,
	world_state: Dictionary,
) -> Dictionary:
	if not threats.is_empty():
		var top_threat: Dictionary = threats[0] if threats[0] is Dictionary else {}
		if not top_threat.is_empty():
			var nt: String = "ELIMINATE_SHADOWLANDS" if top_threat.get("type", "") == "shadowlands" else "MAINTAIN_PEACE"
			return {
				"need_type": nt,
				"objective_type": nt,
				"assigning_lord_id": lord.character_id,
				"status": "ACTIVE",
				"target": top_threat.get("target", ""),
			}

	var low_stability: Array = world_state.get("low_stability_provinces", [])
	if not low_stability.is_empty():
		return {
			"need_type": "MAXIMIZE_PROSPERITY",
			"objective_type": "MAXIMIZE_PROSPERITY",
			"assigning_lord_id": lord.character_id,
			"status": "ACTIVE",
			"target_province_id": low_stability[0] if low_stability[0] is int else -1,
		}

	return {
		"need_type": "MAINTAIN_PEACE",
		"objective_type": "MAINTAIN_PEACE",
		"assigning_lord_id": lord.character_id,
		"status": "ACTIVE",
	}


static func _evaluate_tax_adjustment(
	lord: L5RCharacterData,
	world_state: Dictionary,
) -> Dictionary:
	var province_stability: float = world_state.get("avg_province_stability", 50.0)
	var treasury_ratio: float = world_state.get("treasury_ratio", 1.0)

	var should_lower: bool = province_stability < 30.0 and treasury_ratio > 1.5
	var should_raise: bool = treasury_ratio < 0.5 and province_stability > 60.0

	if lord.bushido_virtue == Enums.BushidoVirtue.JIN:
		should_lower = should_lower or province_stability < 40.0
	if lord.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		should_raise = should_raise or treasury_ratio < 1.0

	if should_lower:
		return {
			"directive": Directive.ADJUST_TAX,
			"lord_id": lord.character_id,
			"direction": "LOWER",
			"reason": "low_stability",
		}
	elif should_raise:
		return {
			"directive": Directive.ADJUST_TAX,
			"lord_id": lord.character_id,
			"direction": "RAISE",
			"reason": "low_treasury",
		}

	return {}


static func _evaluate_war_readiness(
	lord: L5RCharacterData,
	world_state: Dictionary,
) -> Dictionary:
	var active_wars: Array = world_state.get("active_wars", [])
	var escalating_conflicts: Array = world_state.get("escalating_conflicts", [])
	var military_readiness: float = world_state.get("military_readiness", 1.0)

	var needs_readiness: bool = false
	if not active_wars.is_empty():
		needs_readiness = true
	elif not escalating_conflicts.is_empty() and military_readiness < 0.7:
		needs_readiness = true

	if lord.bushido_virtue == Enums.BushidoVirtue.YU:
		if not escalating_conflicts.is_empty():
			needs_readiness = true

	if needs_readiness:
		return {
			"directive": Directive.WAR_READINESS,
			"lord_id": lord.character_id,
			"active_wars": active_wars.size(),
			"escalating": escalating_conflicts.size(),
		}

	return {}


static func _evaluate_seek_peace(
	lord: L5RCharacterData,
	world_state: Dictionary,
) -> Dictionary:
	var active_wars: Array = world_state.get("active_wars", [])
	if active_wars.is_empty():
		return {}

	var war_duration_seasons: int = world_state.get("longest_war_duration_seasons", 0)
	var wants_peace: bool = false

	if lord.bushido_virtue == Enums.BushidoVirtue.JIN:
		wants_peace = true
	elif war_duration_seasons >= 3:
		wants_peace = true
	elif lord.bushido_virtue == Enums.BushidoVirtue.REI and war_duration_seasons >= 2:
		wants_peace = true

	if lord.bushido_virtue == Enums.BushidoVirtue.YU:
		wants_peace = false
	if lord.shourido_virtue == Enums.ShouridoVirtue.KYORYOKU:
		wants_peace = false

	if wants_peace:
		return {
			"directive": Directive.SEEK_PEACE,
			"lord_id": lord.character_id,
			"war_duration": war_duration_seasons,
		}

	return {}


# -- Emperor-Specific ----------------------------------------------------------

static func run_emperor_review(
	emperor: L5RCharacterData,
	archetype: int,
	clan_champions: Array,
	world_state: Dictionary,
	objectives_map: Dictionary,
) -> Array:
	_seed_archetype_champion_baselines(emperor, archetype, clan_champions)

	var directives: Array = []

	var vassals: Array = clan_champions
	var lord_directives: Array = run_seasonal_review(
		emperor, vassals, objectives_map, world_state
	)
	directives.append_array(lord_directives)

	var winter_court: Dictionary = _evaluate_winter_court_host(
		emperor, archetype, clan_champions, world_state
	)
	if not winter_court.is_empty():
		directives.append(winter_court)

	var vacancy: Dictionary = _evaluate_vacancy_fill(
		emperor, archetype, world_state
	)
	if not vacancy.is_empty():
		directives.append(vacancy)

	var shogun: Dictionary = _evaluate_shogun_creation(
		archetype, world_state
	)
	if not shogun.is_empty():
		directives.append(shogun)

	var disgrace_directives: Array = _evaluate_disgrace_fabrication(
		emperor, archetype, clan_champions
	)
	directives.append_array(disgrace_directives)

	var breaking_point: Dictionary = _evaluate_breaking_point(
		emperor, archetype, clan_champions
	)
	if not breaking_point.is_empty():
		directives.append(breaking_point)

	return directives


static func _evaluate_winter_court_host(
	emperor: L5RCharacterData,
	archetype: int,
	clan_champions: Array,
	world_state: Dictionary,
) -> Dictionary:
	var current_season: int = world_state.get("current_season", 0)
	if current_season != TimeSystem.Season.AUTUMN:
		return {}

	var best_clan: String = ""
	var best_score: float = -999.0

	var last_host_seasons: Dictionary = world_state.get("last_host_seasons", {})
	var crisis_by_clan: Dictionary = world_state.get("crisis_momentum_by_clan", {})

	for champion: L5RCharacterData in clan_champions:
		if CharacterStats.is_dead(champion):
			continue
		var clan: String = champion.clan
		var score: float = 0.0

		var disp: float = emperor.disposition_values.get(champion.character_id, 0.0)
		score += disp * 0.1

		var seasons_since_host: int = world_state.get("current_season_index", 0) - last_host_seasons.get(clan, -100)
		score += mini(seasons_since_host, 20) * 0.75

		var crisis: float = crisis_by_clan.get(clan, 0.0)
		score += crisis * 0.1

		score += _archetype_host_preference(archetype, clan, crisis, disp)

		if score > best_score:
			best_score = score
			best_clan = clan

	if best_clan.is_empty():
		return {}

	return {
		"directive": "WINTER_COURT_HOST",
		"lord_id": emperor.character_id,
		"host_clan": best_clan,
		"score": best_score,
	}


static func _archetype_host_preference(
	archetype: int,
	_clan: String,
	crisis: float,
	disposition: float,
) -> float:
	match archetype:
		EmperorArchetype.BENEVOLENT:
			return crisis * 0.15
		EmperorArchetype.IRON:
			return 0.0
		EmperorArchetype.CUNNING:
			return -disposition * 0.1
		EmperorArchetype.WARLIKE:
			return 0.0
		EmperorArchetype.TYRANT:
			return disposition * 0.15
	return 0.0


static func _evaluate_vacancy_fill(
	emperor: L5RCharacterData,
	archetype: int,
	world_state: Dictionary,
) -> Dictionary:
	var vacancies: Array = world_state.get("vacancies", [])
	if vacancies.is_empty():
		return {}

	var min_seasons_map: Dictionary = ARCHETYPE_VACANCY_MIN_SEASONS.get(
		archetype, {"military": 0, "political": 0}
	)

	var best_vacancy: Dictionary = {}
	var best_priority: int = -1

	for v: Variant in vacancies:
		if not v is Dictionary:
			continue
		var vacancy: Dictionary = v as Dictionary
		var is_military: bool = vacancy.get("position_type", "") == "military_commander"
		var category: String = "military" if is_military else "political"
		var min_seasons: int = int(min_seasons_map.get(category, 0))
		var seasons_vacant: int = vacancy.get("seasons_vacant", 0)
		if seasons_vacant < min_seasons:
			continue
		var priority: int = vacancy.get("priority", 0)
		if priority > best_priority:
			best_priority = priority
			best_vacancy = vacancy

	if best_vacancy.is_empty():
		return {}

	var disp_weight: int = ARCHETYPE_DISPOSITION_WEIGHT.get(archetype, 15)
	var skill_weight: int = ARCHETYPE_SKILL_WEIGHT.get(archetype, 20)
	var result: Dictionary = {
		"directive": "FILL_VACANCY",
		"lord_id": emperor.character_id,
		"vacancy": best_vacancy,
		"disposition_weight": disp_weight,
		"skill_weight": skill_weight,
	}
	if archetype == EmperorArchetype.CUNNING:
		result["clan_balance_weight"] = CUNNING_CLAN_BALANCE_WEIGHT
	return result


static func _evaluate_shogun_creation(
	archetype: int,
	world_state: Dictionary,
) -> Dictionary:
	if world_state.get("shogun_exists", false):
		return {}

	var create: bool = false
	var reason: String = ""

	match archetype:
		EmperorArchetype.BENEVOLENT:
			var crisis_duration: int = world_state.get("tier1_military_crisis_seasons", 0)
			var diplomacy_attempted: bool = world_state.get("peace_attempted", false)
			if crisis_duration >= 3 and diplomacy_attempted:
				create = true
				reason = "prolonged_crisis_after_diplomacy"
		EmperorArchetype.IRON:
			var readiness: float = world_state.get("military_readiness", 1.0)
			var tier1: bool = world_state.get("tier1_crisis_active", false)
			if readiness < 0.4 or tier1:
				create = true
				reason = "duty_military_demand"
		EmperorArchetype.CUNNING:
			pass
		EmperorArchetype.WARLIKE:
			pass
		EmperorArchetype.TYRANT:
			var has_loyal: bool = world_state.get("has_maximally_loyal_candidate", false)
			if has_loyal:
				create = true
				reason = "personal_enforcer"

	if create:
		return {
			"directive": "CREATE_SHOGUN",
			"lord_id": -1,
			"archetype": archetype,
			"reason": reason,
		}

	return {}


# -- Tyrant Emperor Effects (s55.10) -------------------------------------------

static func _evaluate_disgrace_fabrication(
	emperor: L5RCharacterData,
	archetype: int,
	clan_champions: Array,
) -> Array:
	if archetype != EmperorArchetype.TYRANT:
		return []

	var results: Array = []
	for champion: L5RCharacterData in clan_champions:
		if CharacterStats.is_dead(champion):
			continue
		var disp: int = emperor.disposition_values.get(champion.character_id, 0)
		var tier: int = DispositionSystem.get_tier(disp)
		if tier <= DispositionSystem.Tier.RIVAL:
			results.append({
				"directive": "FABRICATE_DISGRACE",
				"lord_id": emperor.character_id,
				"target_id": champion.character_id,
				"target_clan": champion.clan,
				"disposition": disp,
			})
	return results


static func _evaluate_breaking_point(
	emperor: L5RCharacterData,
	archetype: int,
	clan_champions: Array,
) -> Dictionary:
	if archetype != EmperorArchetype.TYRANT:
		return {}

	var hostile_clan_count: int = 0
	for champion: L5RCharacterData in clan_champions:
		if CharacterStats.is_dead(champion):
			continue
		if champion.clan not in GREAT_CLANS:
			continue
		var disp: int = champion.disposition_values.get(emperor.character_id, 0)
		if disp <= -31:
			hostile_clan_count += 1

	if hostile_clan_count >= BREAKING_POINT_CLAN_COUNT:
		return {
			"directive": "IMPERIAL_CIVIL_WAR",
			"lord_id": emperor.character_id,
			"hostile_clan_count": hostile_clan_count,
		}
	return {}


static func _seed_archetype_champion_baselines(
	emperor: L5RCharacterData,
	archetype: int,
	clan_champions: Array,
) -> void:
	for champion: L5RCharacterData in clan_champions:
		if CharacterStats.is_dead(champion):
			continue
		if emperor.disposition_values.has(champion.character_id):
			continue
		var baseline: int = get_archetype_champion_baseline(archetype, champion.school_type)
		if baseline != 0:
			emperor.disposition_values[champion.character_id] = clampi(baseline, -100, 100)


static func get_archetype_champion_baseline(
	archetype: int,
	school_type: int,
) -> int:
	if archetype == EmperorArchetype.WARLIKE:
		if school_type == Enums.SchoolType.BUSHI:
			return WARLIKE_BUSHI_CHAMPION_BASELINE
		return WARLIKE_COURTIER_CHAMPION_BASELINE
	if archetype == EmperorArchetype.BENEVOLENT:
		return 15
	if archetype == EmperorArchetype.TYRANT:
		return 0
	return 0


# -- Self-Selection (s55.26.1) -------------------------------------------------

static func _evaluate_self_selection(
	lord: L5RCharacterData,
	objectives_map: Dictionary,
	world_state: Dictionary,
) -> Dictionary:
	var lord_objectives: Dictionary = objectives_map.get(lord.character_id, {})
	var primary: Dictionary = lord_objectives.get("primary", {})

	if not primary.is_empty() and primary.get("status", "") == "ACTIVE":
		return {}

	var standing: Dictionary = lord_objectives.get("standing", {})
	var standing_type: String = standing.get("need_type", "")
	if standing_type.is_empty():
		return {}

	var selected: Dictionary = OpportunityScanner.select_primary_objective(
		lord, standing_type, world_state
	)
	if selected.is_empty():
		return {}

	return {
		"directive": Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": lord.character_id,
		"vassal_id": lord.character_id,
		"decision": "SELF_SELECT",
		"new_objective": {
			"need_type": selected["objective_type"],
			"objective_type": selected["objective_type"],
			"target_fields": selected["target_fields"],
			"assigning_lord_id": lord.character_id,
			"status": "ACTIVE",
			"source": "SELF_SELECTED",
		},
		"score": selected.get("score", 0.0),
	}
