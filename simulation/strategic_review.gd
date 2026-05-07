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


static func run_seasonal_review(
	lord: L5RCharacterData,
	vassals: Array[L5RCharacterData],
	objectives_map: Dictionary,
	world_state: Dictionary,
) -> Array[Dictionary]:
	var directives: Array[Dictionary] = []

	var self_select: Dictionary = _evaluate_self_selection(lord, objectives_map, world_state)
	if not self_select.is_empty():
		directives.append(self_select)

	var orphan_directives: Array[Dictionary] = _resolve_orphaned_vassals(
		lord, vassals, objectives_map
	)
	directives.append_array(orphan_directives)

	var court_directive: Dictionary = _evaluate_call_court(lord, vassals, world_state)
	if not court_directive.is_empty():
		directives.append(court_directive)

	var reassign_directives: Array[Dictionary] = _evaluate_vassal_objectives(
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
	vassals: Array[L5RCharacterData],
	objectives_map: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var orphaned_ids: Array[int] = OrphanedObjectives.has_orphaned_vassals(
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
	vassals: Array[L5RCharacterData],
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
	vassals: Array[L5RCharacterData],
	objectives_map: Dictionary,
	world_state: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var province_statuses: Array = world_state.get("province_statuses", [])
	var triage_results: Array[ProvinceTriage.TriageResult] = ProvinceTriage.get_top_provinces(
		province_statuses, 3
	)

	var threats: Array = world_state.get("province_threats", [])
	if threats.is_empty() and not triage_results.is_empty():
		for t: ProvinceTriage.TriageResult in triage_results:
			if t.score >= ProvinceTriage.SCORE_VOLATILE_STABILITY:
				threats.append({"type": "instability", "target_province_id": t.province_id})

	var idle_vassals: Array[int] = []
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
			return {
				"objective_type": "ELIMINATE_SHADOWLANDS" if top_threat.get("type", "") == "shadowlands" else "MAINTAIN_PEACE",
				"assigning_lord_id": lord.character_id,
				"status": "ACTIVE",
				"target": top_threat.get("target", ""),
			}

	var low_stability: Array = world_state.get("low_stability_provinces", [])
	if not low_stability.is_empty():
		return {
			"objective_type": "MAXIMIZE_PROSPERITY",
			"assigning_lord_id": lord.character_id,
			"status": "ACTIVE",
			"target_province_id": low_stability[0] if low_stability[0] is int else -1,
		}

	return {
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
	clan_champions: Array[L5RCharacterData],
	world_state: Dictionary,
	objectives_map: Dictionary,
) -> Array[Dictionary]:
	var directives: Array[Dictionary] = []

	var vassals: Array[L5RCharacterData] = clan_champions
	var lord_directives: Array[Dictionary] = run_seasonal_review(
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

	return directives


static func _evaluate_winter_court_host(
	emperor: L5RCharacterData,
	archetype: int,
	clan_champions: Array[L5RCharacterData],
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

	var delay: int = ARCHETYPE_VACANCY_DELAY.get(archetype, 30)
	var ticks_since_vacancy: int = world_state.get("ticks_since_oldest_vacancy", 0)

	if ticks_since_vacancy < delay:
		return {}

	return {
		"directive": "FILL_VACANCY",
		"lord_id": emperor.character_id,
		"vacancy": vacancies[0],
		"disposition_weight": ARCHETYPE_DISPOSITION_WEIGHT.get(archetype, 15),
		"skill_weight": ARCHETYPE_SKILL_WEIGHT.get(archetype, 20),
	}


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
			"objective_type": selected["objective_type"],
			"target_fields": selected["target_fields"],
			"assigning_lord_id": lord.character_id,
			"status": "ACTIVE",
			"source": "SELF_SELECTED",
		},
		"score": selected.get("score", 0.0),
	}
