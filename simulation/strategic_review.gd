class_name StrategicReview
## Lord-tier seasonal Strategic Review per GDD s55.10.
## Runs at each seasonal tick for lord-tier NPCs.
## Produces directives: Reassign Vassal Objectives, Adjust Tax/Stipend,
## War Readiness, Seek Peace, Call Court, or No Change.
## Also runs Clan Champion Strategic Evaluation per GDD s57.54.


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

	var vassals_by_id: Dictionary = {}
	for v: L5RCharacterData in vassals:
		vassals_by_id[v.character_id] = v

	for vassal_id: int in idle_vassals:
		var vassal_char: L5RCharacterData = vassals_by_id.get(vassal_id)
		var new_objective: Dictionary = _select_objective_for_vassal(
			lord, vassal_char, threats, world_state
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
	vassal: L5RCharacterData,
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
	marriages: Array = [],
	active_wars: Array = [],
	characters_by_id: Dictionary = {},
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

	# Pathway 4 — Imperial Decree: dissolve marriages between warring clans (s57.49.7).
	var war_marriage_directives: Array = _evaluate_war_marriages(
		emperor, marriages, active_wars, characters_by_id,
	)
	directives.append_array(war_marriage_directives)

	return directives


static func _evaluate_war_marriages(
	emperor: L5RCharacterData,
	marriages: Array,
	active_wars: Array,
	characters_by_id: Dictionary,
) -> Array:
	# Find cross-clan marriages where both clans are currently at war with each other.
	# Returns IMPERIAL_DISSOLVE_MARRIAGE directives per s57.49.7 Pathway 4.
	var belligerent_pairs: Array = []
	for war: Variant in active_wars:
		if not war is WarData:
			continue
		if not (war as WarData).is_active:
			continue
		belligerent_pairs.append([war.clan_a, war.clan_b])

	if belligerent_pairs.is_empty():
		return []

	var directives: Array = []
	for m: Variant in marriages:
		if not (m is Dictionary):
			continue
		if not m.get("active", false):
			continue
		var a_id: int = m.get("character_a_id", -1)
		var b_id: int = m.get("character_b_id", -1)
		var char_a: L5RCharacterData = characters_by_id.get(a_id) as L5RCharacterData
		var char_b: L5RCharacterData = characters_by_id.get(b_id) as L5RCharacterData
		if char_a == null or char_b == null:
			continue
		if CharacterStats.is_dead(char_a) or CharacterStats.is_dead(char_b):
			continue
		var a_clan: String = char_a.clan
		var b_clan: String = char_b.clan
		if a_clan.is_empty() or b_clan.is_empty() or a_clan == b_clan:
			continue
		for pair: Array in belligerent_pairs:
			if (pair[0] == a_clan and pair[1] == b_clan) or \
			   (pair[0] == b_clan and pair[1] == a_clan):
				directives.append({
					"directive": "IMPERIAL_DISSOLVE_MARRIAGE",
					"lord_id": emperor.character_id,
					"spouse_a_id": a_id,
					"spouse_b_id": b_id,
				})
				break  # One directive per marriage.
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


# =============================================================================
# s57.54 Clan Champion Strategic Evaluation System
# =============================================================================

# -- Personality Preference Matrix (s57.54.14) ---------------------------------
# Maps (virtue_key → conclusion_type) → preference score.
# +25 = core affinity, +15 = natural weight, 0 = neutral, -15 = deprioritize.
# Hard-block uses a sentinel INT_MIN (filtered out before scoring).
const HARD_BLOCK: int = -9999

# Rows: bushido JIN/YU/REI/CHUGI/GI/MEIYO/MAKOTO,
#       shourido DOSATSU/KYORYOKU/KANPEKI/SEIGYO/CHISHIKI/KETSUI/ISHI
# Columns match ConclusionType enum order:
#   AGG LNC SUP SHD DEF ALL PEA UND CRT EDC RES INF DMG WOR SPC CUL

const _PREF_MATRIX: Dictionary = {
	# Bushido
	Enums.BushidoVirtue.JIN:   [-15, -15,  15,  25,  25,  25,  25, -15,  15,  15,  15,  15,  25,  15,  15,   0],
	Enums.BushidoVirtue.YU:    [ 25,  25,  15,  15,   0,   0, -15, HARD_BLOCK, -15,   0,   0, -15,   0,   0,  15, -15],
	Enums.BushidoVirtue.REI:   [-15, -15,   0,   0,   0,  25,  15, -15,  25,  15,   0,   0,   0,  15,   0,  25],
	Enums.BushidoVirtue.CHUGI: [ 15,  15,  25,  25,  15,  15,  15,   0,  15,  25,  15,  15,  15,  25,  25,   0],
	Enums.BushidoVirtue.GI:    [  0,   0,  15,  15,  15,  15,  15, -15,   0,  15,   0,   0,  15,  15,  15,   0],
	Enums.BushidoVirtue.MEIYO: [  0,   0,  15,  15,  15,   0,   0, -15,  15,  15,   0,   0,   0,  15,   0,  15],
	Enums.BushidoVirtue.MAKOTO:[  0,   0,   0,   0,  15,  15,  15, HARD_BLOCK,  15,  15,   0,   0,  15,  15,   0,  15],
	# Shourido
	Enums.ShouridoVirtue.DOSATSU:  [ 15,   0,  15,   0,   0,  15,   0,  25,  15,   0,  15,   0,   0,   0,  15,   0],
	Enums.ShouridoVirtue.KYORYOKU: [ 25,  25,  15,  15,  15, -15, -15, -15, -15,   0,   0,   0,   0,   0,  15, -15],
	Enums.ShouridoVirtue.KANPEKI:  [  0,   0,  15,   0,   0,  15,   0,  15,  25,  15,   0,  15,  15,  15,   0,  25],
	Enums.ShouridoVirtue.SEIGYO:   [ 15,   0,  25,   0,  15,  15,   0,  25,  15, -15,  25,  15,   0,   0,   0,  15],
	Enums.ShouridoVirtue.CHISHIKI: [  0,   0,   0,  15,   0,   0,   0,  15,   0,   0,  15,  15,   0,  25,  25,  15],
	Enums.ShouridoVirtue.KETSUI:   [ 15,  15,  15,  15,  15,   0, -15,   0,   0,   0,  15,   0,  15,   0,   0,   0],
	Enums.ShouridoVirtue.ISHI:     [ 15,  15,  15,   0,  15, -15, -15,  15,   0, -15,  15,   0,   0,   0,   0, -15],
}

# Domain for each ConclusionType (index matches enum ordinal).
const _CONCLUSION_DOMAINS: Array[StrategicConclusionData.Domain] = [
	StrategicConclusionData.Domain.MILITARY,   # AGGRESSIVE_POSTURE
	StrategicConclusionData.Domain.MILITARY,   # LAUNCH_OFFENSIVE
	StrategicConclusionData.Domain.MILITARY,   # SUPPRESS_INSTABILITY
	StrategicConclusionData.Domain.MILITARY,   # SUPPORT_SHADOWLANDS
	StrategicConclusionData.Domain.MILITARY,   # DEFEND_TERRITORY
	StrategicConclusionData.Domain.DIPLOMATIC, # PURSUE_ALLIANCE
	StrategicConclusionData.Domain.DIPLOMATIC, # SEEK_PEACE
	StrategicConclusionData.Domain.DIPLOMATIC, # UNDERMINE_POSITION
	StrategicConclusionData.Domain.DIPLOMATIC, # STRENGTHEN_COURT
	StrategicConclusionData.Domain.DIPLOMATIC, # COMPLY_EDICT
	StrategicConclusionData.Domain.ECONOMIC,   # SECURE_RESOURCE
	StrategicConclusionData.Domain.ECONOMIC,   # DEVELOP_INFRASTRUCTURE
	StrategicConclusionData.Domain.ECONOMIC,   # RECOVER_DAMAGE
	StrategicConclusionData.Domain.SPIRITUAL,  # RESTORE_WORSHIP
	StrategicConclusionData.Domain.SPIRITUAL,  # RESPOND_SPIRITUAL_CRISIS
	StrategicConclusionData.Domain.SOCIAL,     # BUILD_CULTURAL_PRESTIGE
]

# Standing objective need_type → dominant domain (for Standing Objective Match bonus).
const _STANDING_OBJ_DOMAIN: Dictionary = {
	"MAINTAIN_PEACE": StrategicConclusionData.Domain.DIPLOMATIC,
	"SECURE_ALLIANCE": StrategicConclusionData.Domain.DIPLOMATIC,
	"ARRANGE_MARRIAGE": StrategicConclusionData.Domain.DIPLOMATIC,
	"UNDERMINE_RIVAL": StrategicConclusionData.Domain.DIPLOMATIC,
	"STRENGTHEN_COURT": StrategicConclusionData.Domain.DIPLOMATIC,
	"EXPAND_INFLUENCE": StrategicConclusionData.Domain.MILITARY,
	"MILITARY_DOMINANCE": StrategicConclusionData.Domain.MILITARY,
	"DEFEND_PROVINCE": StrategicConclusionData.Domain.MILITARY,
	"ELIMINATE_SHADOWLANDS": StrategicConclusionData.Domain.MILITARY,
	"SUPPRESS_INSTABILITY": StrategicConclusionData.Domain.MILITARY,
	"MAXIMIZE_PROSPERITY": StrategicConclusionData.Domain.ECONOMIC,
	"RESOURCE_SECURITY": StrategicConclusionData.Domain.ECONOMIC,
	"TRADE_CONTROL": StrategicConclusionData.Domain.ECONOMIC,
	"PRESERVE_SPIRITUAL": StrategicConclusionData.Domain.SPIRITUAL,
	"SEEK_GLORY": StrategicConclusionData.Domain.SOCIAL,
	"FAMILY_STANDING": StrategicConclusionData.Domain.SOCIAL,
	"CULTURAL_PRESTIGE": StrategicConclusionData.Domain.SOCIAL,
}

# Conclusion types that require a target_clan_id (s57.54.4).
const _REQUIRES_TARGET_CLAN: Array[StrategicConclusionData.ConclusionType] = [
	StrategicConclusionData.ConclusionType.AGGRESSIVE_POSTURE,
	StrategicConclusionData.ConclusionType.LAUNCH_OFFENSIVE,
	StrategicConclusionData.ConclusionType.DEFEND_TERRITORY,
	StrategicConclusionData.ConclusionType.PURSUE_ALLIANCE,
	StrategicConclusionData.ConclusionType.SEEK_PEACE,
	StrategicConclusionData.ConclusionType.UNDERMINE_POSITION,
]

# Personality base slot counts (s57.54 Step 4).
const _PERSONALITY_BASE_SLOTS: Dictionary = {
	Enums.ShouridoVirtue.KETSUI:  2,
	Enums.BushidoVirtue.YU:       2,
	Enums.ShouridoVirtue.KYORYOKU: 2,
}
const _DEFAULT_SLOT_COUNT: int = 3

# Continuation bonus per personality (s57.54.6).
const _CONTINUATION_BONUS_BASE: int = 10
const _CONTINUATION_BONUS_MAKOTO: int = 20
const _CONTINUATION_BONUS_KETSUI: int = 15


# -- Entry Point: run_clan_champion_evaluation ---------------------------------

## Runs the six-step Champion evaluation (s57.54.3).
## Updates clan.clan_strategic_priorities and champion.strategic_evaluation_log.
## Returns Array of letter-dispatch Dictionaries for absent Family Daimyo.
## Requires: active_topics keyed by topic_id int; active_wars Array[WarData];
##           active_edicts Array[EdictData]; characters_by_id Dictionary.
static func run_clan_champion_evaluation(
	champion: L5RCharacterData,
	clan: ClanData,
	active_topics_by_id: Dictionary,
	active_wars: Array,
	active_edicts: Array,
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
	current_season: int,
	dice_engine: DiceEngine,
	family_daimyo_ids: Array = [],
) -> Array:
	if CharacterStats.is_dead(champion):
		return []

	var virtue_key = _get_virtue_key(champion)
	var standing_domain = _standing_obj_domain(champion, objectives_map)

	# Step 1 — Threat Scan: forced conclusions from Tier 1/2 topics.
	var forced: Array[StrategicConclusionData] = _step1_threat_scan(
		champion, clan, active_topics_by_id, active_edicts, active_wars,
		current_season,
	)

	# Step 2 — Opportunity Scan: candidate pool from Tier 3/4 topics + world conditions.
	var candidates: Array[StrategicConclusionData] = _step2_opportunity_scan(
		champion, clan, active_topics_by_id, active_wars, active_edicts,
		current_season, forced,
	)

	# Step 3 — Scoring.
	var prev_types: Dictionary = _prev_conclusion_types(clan)
	for sc: StrategicConclusionData in candidates:
		sc.score = _step3_score(
			sc, champion, virtue_key, standing_domain,
			active_topics_by_id, prev_types,
		)

	# Remove hard-blocked candidates (score == HARD_BLOCK).
	var scored_candidates: Array[StrategicConclusionData] = []
	for sc: StrategicConclusionData in candidates:
		if sc.score != HARD_BLOCK:
			scored_candidates.append(sc)

	# Step 4 — Selection.
	var selected: Array[StrategicConclusionData] = _step4_select(
		forced, scored_candidates, champion, virtue_key, current_season, clan,
	)

	# Log full candidate list for debugging (s57.54.4).
	var log_entry: Dictionary = {"season": current_season, "candidates": []}
	for sc: StrategicConclusionData in scored_candidates:
		log_entry["candidates"].append({
			"type": sc.conclusion_type,
			"score": sc.score,
			"target_clan_id": sc.target_clan_id,
		})
	champion.strategic_evaluation_log = [log_entry]

	# Step 5 — Write conclusions to clan and notify Family Daimyo.
	clan.clan_strategic_priorities.assign(selected)

	# Build letter dispatches for absent Family Daimyo (Step 5 + Step 6).
	var letter_dispatches: Array = _build_family_daimyo_dispatches(
		champion, selected, family_daimyo_ids, characters_by_id,
	)
	return letter_dispatches


## Mid-season Trigger 2: new Tier 1/2 topic forces partial reevaluation.
## Inserts the new forced conclusion if it outranks the lowest-scored non-forced.
## Returns Array of letter-dispatch Dictionaries for absent Family Daimyo.
static func run_midseason_crisis_update(
	champion: L5RCharacterData,
	clan: ClanData,
	new_topic: TopicData,
	active_topics_by_id: Dictionary,
	current_season: int,
	characters_by_id: Dictionary,
	family_daimyo_ids: Array,
) -> Array:
	if CharacterStats.is_dead(champion):
		return []
	if new_topic.tier != TopicData.Tier.TIER_1 and new_topic.tier != TopicData.Tier.TIER_2:
		return []

	var new_conclusion := _forced_conclusion_from_topic(
		champion, clan, new_topic, current_season,
	)
	if new_conclusion == null:
		return []

	# Find lowest-scored non-forced entry to displace (s57.54.3 Step 6).
	var priorities: Array[StrategicConclusionData] = clan.clan_strategic_priorities
	var lowest_idx: int = -1
	var lowest_score: int = 999999
	for i: int in range(priorities.size()):
		var sc: StrategicConclusionData = priorities[i]
		if not sc.is_forced and sc.score < lowest_score:
			lowest_score = sc.score
			lowest_idx = i
	if lowest_idx >= 0:
		priorities[lowest_idx] = new_conclusion
	else:
		priorities.append(new_conclusion)

	return _build_family_daimyo_dispatches(
		champion, priorities, family_daimyo_ids, characters_by_id,
	)


## Trigger 3/4: priority achieved or impossible. Removes entry from array.
## Ketsui immediately fills the slot via Steps 2–4 (partial re-evaluation).
## Returns letter dispatches notifying absent Family Daimyo.
static func run_priority_resolved(
	champion: L5RCharacterData,
	clan: ClanData,
	conclusion_id: int,
	active_topics_by_id: Dictionary,
	active_wars: Array,
	active_edicts: Array,
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
	current_season: int,
	dice_engine: DiceEngine,
	family_daimyo_ids: Array,
) -> Array:
	var priorities: Array[StrategicConclusionData] = clan.clan_strategic_priorities
	var removed_idx: int = -1
	for i: int in range(priorities.size()):
		if priorities[i].conclusion_id == conclusion_id:
			removed_idx = i
			break
	if removed_idx < 0:
		return []
	priorities.remove_at(removed_idx)

	# Ketsui immediately refills (s57.54.1 Trigger 3).
	var virtue_key = _get_virtue_key(champion)
	if virtue_key == Enums.ShouridoVirtue.KETSUI:
		return run_clan_champion_evaluation(
			champion, clan, active_topics_by_id, active_wars, active_edicts,
			characters_by_id, objectives_map, current_season, dice_engine,
			family_daimyo_ids,
		)

	return _build_family_daimyo_dispatches(
		champion, priorities, family_daimyo_ids, characters_by_id,
	)


# -- Step 1: Threat Scan -------------------------------------------------------

static func _step1_threat_scan(
	champion: L5RCharacterData,
	clan: ClanData,
	active_topics_by_id: Dictionary,
	active_edicts: Array,
	active_wars: Array,
	current_season: int,
) -> Array[StrategicConclusionData]:
	var forced: Array[StrategicConclusionData] = []
	for topic_id: int in champion.topic_pool:
		var topic: TopicData = active_topics_by_id.get(topic_id)
		if topic == null or topic.resolved:
			continue
		if topic.tier != TopicData.Tier.TIER_1 and topic.tier != TopicData.Tier.TIER_2:
			continue
		var sc := _forced_conclusion_from_topic(champion, clan, topic, current_season)
		if sc != null:
			forced.append(sc)
	# COMPLY_EDICT: forced whenever binding Edict applies to clan (Trigger 5).
	for edict in active_edicts:
		if edict == null:
			continue
		var applies_to_clan: bool = (
			edict.get("target_clan", "") == champion.clan
			or edict.get("target_clan", "") == "ALL"
		)
		if applies_to_clan:
			var sc := _make_conclusion(
				clan, StrategicConclusionData.ConclusionType.COMPLY_EDICT,
				current_season,
			)
			sc.edict_id = edict.get("edict_id", -1) if edict is Dictionary else -1
			sc.score = 140  # Treat as Tier 2 forced (compelling but overridable by Tier 1).
			sc.is_forced = true
			sc.source_topic_ids = []
			forced.append(sc)
	return forced


## Maps a Tier 1/2 topic to the appropriate forced StrategicConclusion.
## Returns null if the topic doesn't map to a known crisis pattern.
static func _forced_conclusion_from_topic(
	champion: L5RCharacterData,
	clan: ClanData,
	topic: TopicData,
	current_season: int,
) -> StrategicConclusionData:
	var ct: StrategicConclusionData.ConclusionType
	var target_clan_id: int = -1
	var forced_score: int = 150 if topic.tier == TopicData.Tier.TIER_1 else 140

	match topic.topic_type:
		"shadowlands_incursion", "oni_manifestation", "taint_insurgency":
			if champion.clan == "Crab":
				ct = StrategicConclusionData.ConclusionType.SUPPRESS_INSTABILITY
			else:
				ct = StrategicConclusionData.ConclusionType.SUPPORT_SHADOWLANDS
		"insurgency", "civil_war_triggered", "crime_surge":
			ct = StrategicConclusionData.ConclusionType.SUPPRESS_INSTABILITY
		"war_declaration", "border_raid", "army_movement":
			ct = StrategicConclusionData.ConclusionType.DEFEND_TERRITORY
			target_clan_id = _clan_name_to_id(topic.clan_involved)
		"realm_overlap", "elemental_imbalance", "spiritual_crisis":
			ct = StrategicConclusionData.ConclusionType.RESPOND_SPIRITUAL_CRISIS
		"famine", "starvation":
			ct = StrategicConclusionData.ConclusionType.SECURE_RESOURCE
		_:
			return null

	var sc := _make_conclusion(clan, ct, current_season)
	sc.target_clan_id = target_clan_id
	sc.score = forced_score
	sc.is_forced = true
	sc.source_topic_ids = [topic.topic_id]
	return sc


# -- Step 2: Opportunity Scan --------------------------------------------------

static func _step2_opportunity_scan(
	champion: L5RCharacterData,
	clan: ClanData,
	active_topics_by_id: Dictionary,
	active_wars: Array,
	active_edicts: Array,
	current_season: int,
	forced: Array[StrategicConclusionData],
) -> Array[StrategicConclusionData]:
	var candidates: Array[StrategicConclusionData] = []
	var forced_types: Dictionary = {}
	for sc: StrategicConclusionData in forced:
		forced_types[sc.conclusion_type] = true

	var known_topic_ids: Array = champion.topic_pool

	# Scan Tier 3/4 topics for trigger matches.
	for topic_id: int in known_topic_ids:
		var topic: TopicData = active_topics_by_id.get(topic_id)
		if topic == null or topic.resolved:
			continue
		if topic.tier == TopicData.Tier.TIER_1 or topic.tier == TopicData.Tier.TIER_2:
			continue
		_scan_topic_for_candidates(
			champion, clan, topic, candidates, forced_types, current_season,
		)

	# Condition-based candidates (not purely topic-driven).
	_scan_war_conditions(champion, clan, active_wars, candidates, forced_types, current_season)
	_scan_edict_conditions(champion, clan, active_edicts, candidates, forced_types, current_season)
	_scan_standing_objective(champion, clan, candidates, forced_types, current_season)

	return candidates


static func _scan_topic_for_candidates(
	champion: L5RCharacterData,
	clan: ClanData,
	topic: TopicData,
	candidates: Array[StrategicConclusionData],
	forced_types: Dictionary,
	current_season: int,
) -> void:
	var tt: String = topic.topic_type

	match tt:
		"insurgency", "crime_surge":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.SUPPRESS_INSTABILITY,
					current_season, [topic.topic_id]),
			)
		"worship_failure", "fortune_restless", "fortune_displeased", "fortune_wrathful":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.RESTORE_WORSHIP,
					current_season, [topic.topic_id]),
			)
		"realm_overlap", "elemental_imbalance":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.RESPOND_SPIRITUAL_CRISIS,
					current_season, [topic.topic_id]),
			)
		"border_dispute", "territorial_grievance", "hostile_action":
			var tcid: int = _clan_name_to_id(topic.clan_involved)
			var sc := _make_with_source(clan, StrategicConclusionData.ConclusionType.AGGRESSIVE_POSTURE,
				current_season, [topic.topic_id])
			sc.target_clan_id = tcid
			_add_candidate_if_new(candidates, forced_types, sc)
		"rice_shortage", "iron_shortage", "koku_shortage", "starvation":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.SECURE_RESOURCE,
					current_season, [topic.topic_id]),
			)
		"art_removal_slight", "art_removal_minor", "legendary_artisan_completion",
		"masterful_performance":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.BUILD_CULTURAL_PRESTIGE,
					current_season, [topic.topic_id]),
			)
		"court_dominance", "alliance_formed":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.STRENGTHEN_COURT,
					current_season, [topic.topic_id]),
			)
		"war_ended", "major_crisis_resolved":
			_add_candidate_if_new(
				candidates, forced_types,
				_make_with_source(clan, StrategicConclusionData.ConclusionType.RECOVER_DAMAGE,
					current_season, [topic.topic_id]),
			)
		"shadowlands_incursion_minor", "shadowlands_horde":
			if champion.clan != "Crab":
				_add_candidate_if_new(
					candidates, forced_types,
					_make_with_source(clan, StrategicConclusionData.ConclusionType.SUPPORT_SHADOWLANDS,
						current_season, [topic.topic_id]),
				)


static func _scan_war_conditions(
	champion: L5RCharacterData,
	clan: ClanData,
	active_wars: Array,
	candidates: Array[StrategicConclusionData],
	forced_types: Dictionary,
	current_season: int,
) -> void:
	for war in active_wars:
		if war == null or not war.is_active:
			continue
		var is_clan_a: bool = (war.clan_a == champion.clan)
		var is_clan_b: bool = (war.clan_b == champion.clan)
		if not is_clan_a and not is_clan_b:
			continue
		var my_score: int = war.war_score_a if is_clan_a else war.war_score_b
		var enemy_clan: String = war.clan_b if is_clan_a else war.clan_a
		var tcid: int = _clan_name_to_id(enemy_clan)

		# SEEK_PEACE trigger: war score below 40 (s57.54.5 #6).
		if my_score < 40:
			var sc := _make_with_source(clan, StrategicConclusionData.ConclusionType.SEEK_PEACE,
				current_season, [])
			sc.target_clan_id = tcid
			_add_candidate_if_new(candidates, forced_types, sc)

		# AGGRESSIVE_POSTURE: war at tension (War Status implies existing tension).
		var ap_sc := _make_with_source(clan, StrategicConclusionData.ConclusionType.AGGRESSIVE_POSTURE,
			current_season, [])
		ap_sc.target_clan_id = tcid
		_add_candidate_if_new(candidates, forced_types, ap_sc)


static func _scan_edict_conditions(
	champion: L5RCharacterData,
	clan: ClanData,
	active_edicts: Array,
	candidates: Array[StrategicConclusionData],
	forced_types: Dictionary,
	current_season: int,
) -> void:
	for edict in active_edicts:
		if edict == null:
			continue
		var applies: bool
		if edict is Dictionary:
			applies = (edict.get("target_clan", "") == champion.clan
				or edict.get("target_clan", "") == "ALL")
		else:
			applies = false
		if applies and not (StrategicConclusionData.ConclusionType.COMPLY_EDICT in forced_types):
			var sc := _make_with_source(clan,
				StrategicConclusionData.ConclusionType.COMPLY_EDICT, current_season, [])
			sc.edict_id = edict.get("edict_id", -1) if edict is Dictionary else -1
			_add_candidate_if_new(candidates, forced_types, sc)


static func _scan_standing_objective(
	champion: L5RCharacterData,
	clan: ClanData,
	candidates: Array[StrategicConclusionData],
	forced_types: Dictionary,
	current_season: int,
) -> void:
	# Always-available candidates driven by standing objective.
	# SUPPRESS_INSTABILITY and SECURE_RESOURCE are always in the pool at low urgency.
	_add_candidate_if_new(
		candidates, forced_types,
		_make_with_source(clan, StrategicConclusionData.ConclusionType.SUPPRESS_INSTABILITY,
			current_season, []),
	)
	_add_candidate_if_new(
		candidates, forced_types,
		_make_with_source(clan, StrategicConclusionData.ConclusionType.SECURE_RESOURCE,
			current_season, []),
	)
	_add_candidate_if_new(
		candidates, forced_types,
		_make_with_source(clan, StrategicConclusionData.ConclusionType.STRENGTHEN_COURT,
			current_season, []),
	)
	_add_candidate_if_new(
		candidates, forced_types,
		_make_with_source(clan, StrategicConclusionData.ConclusionType.RESTORE_WORSHIP,
			current_season, []),
	)


# -- Step 3: Scoring -----------------------------------------------------------

static func _step3_score(
	sc: StrategicConclusionData,
	champion: L5RCharacterData,
	virtue_key,
	standing_domain: int,
	active_topics_by_id: Dictionary,
	prev_types: Dictionary,
) -> int:
	# Standing Objective Match: +30 if conclusion domain matches standing obj domain.
	var domain_int: int = _CONCLUSION_DOMAINS[sc.conclusion_type]
	var standing_match: int = 30 if domain_int == standing_domain else 0

	# Personality Preference from matrix.
	var pref: int = _get_preference(virtue_key, sc.conclusion_type)
	if pref == HARD_BLOCK:
		return HARD_BLOCK

	# Topic Urgency: best triggering topic drives the score.
	var urgency: int = 0
	var momentum_bonus: int = 0
	for tid: int in sc.source_topic_ids:
		var topic: TopicData = active_topics_by_id.get(tid)
		if topic == null or topic.resolved:
			continue
		var tier_bonus: int = 25 if topic.tier == TopicData.Tier.TIER_3 else 10
		if tier_bonus > urgency:
			urgency = tier_bonus
		# Momentum: rising +10, falling -10, stable 0.
		var mom_val: int = 0
		if topic.momentum > 5.0:
			mom_val = 10
		elif topic.momentum < -5.0:
			mom_val = -10
		if mom_val > momentum_bonus:
			momentum_bonus = mom_val

	# Convergent Topics: +5 per additional source topic beyond the first.
	var convergent: int = max(0, sc.source_topic_ids.size() - 1) * 5

	# Continuation Bonus: +10 base if same conclusion type was active last season.
	var continuation: int = 0
	if sc.conclusion_type in prev_types and sc.source_topic_ids.size() > 0:
		continuation = _continuation_bonus(virtue_key)

	return standing_match + urgency + momentum_bonus + convergent + pref + continuation


static func _continuation_bonus(virtue_key) -> int:
	if virtue_key == Enums.BushidoVirtue.MAKOTO:
		return _CONTINUATION_BONUS_MAKOTO
	if virtue_key == Enums.ShouridoVirtue.KETSUI:
		return _CONTINUATION_BONUS_KETSUI
	return _CONTINUATION_BONUS_BASE


# -- Step 4: Selection ---------------------------------------------------------

static func _step4_select(
	forced: Array[StrategicConclusionData],
	scored_candidates: Array[StrategicConclusionData],
	champion: L5RCharacterData,
	virtue_key,
	current_season: int,
	clan: ClanData,
) -> Array[StrategicConclusionData]:
	var selected: Array[StrategicConclusionData] = []
	selected.assign(forced)

	# Ishi locks previous conclusions (s57.54.6): re-add any Ishi-locked entries
	# from last season that still have valid triggers (source_topic_ids not empty or
	# are standing-objective-driven). Forced crisis conclusions override Ishi lock.
	if virtue_key == Enums.ShouridoVirtue.ISHI:
		for prev_sc: StrategicConclusionData in clan.clan_strategic_priorities:
			if prev_sc.is_forced:
				continue  # Already handled in forced array.
			var already_in_forced: bool = false
			for f: StrategicConclusionData in forced:
				if f.conclusion_type == prev_sc.conclusion_type:
					already_in_forced = true
					break
			if not already_in_forced:
				prev_sc.is_continuation = true
				selected.append(prev_sc)

	# Personality base slot count.
	var base_slots: int = _PERSONALITY_BASE_SLOTS.get(virtue_key, _DEFAULT_SLOT_COUNT)
	var discretionary_slots: int = max(0, base_slots - forced.size())

	# Conditional expansion: +1 if any candidate scores above 50 (s57.54 Step 4).
	var any_above_50: bool = false
	for sc: StrategicConclusionData in scored_candidates:
		if sc.score > 50:
			any_above_50 = true
			break
	if any_above_50:
		discretionary_slots += 1

	# Sort candidates descending by score.
	var sorted_candidates: Array[StrategicConclusionData] = []
	sorted_candidates.assign(scored_candidates)
	sorted_candidates.sort_custom(func(a: StrategicConclusionData, b: StrategicConclusionData) -> bool:
		if a.score != b.score:
			return a.score > b.score
		# Tie-break: continuation first.
		if a.is_continuation != b.is_continuation:
			return a.is_continuation
		return false
	)

	# Assign IDs and fill discretionary slots.
	for sc: StrategicConclusionData in sorted_candidates:
		if discretionary_slots <= 0:
			break
		# Skip types already in selected.
		var already_selected: bool = false
		for s: StrategicConclusionData in selected:
			if s.conclusion_type == sc.conclusion_type and s.target_clan_id == sc.target_clan_id:
				already_selected = true
				break
		if already_selected:
			continue
		sc.conclusion_id = clan.next_conclusion_id
		clan.next_conclusion_id += 1
		selected.append(sc)
		discretionary_slots -= 1

	# Assign IDs to forced conclusions.
	for sc: StrategicConclusionData in forced:
		if sc.conclusion_id < 0:
			sc.conclusion_id = clan.next_conclusion_id
			clan.next_conclusion_id += 1

	return selected


# -- Step 5/6: Communication ---------------------------------------------------

static func _build_family_daimyo_dispatches(
	champion: L5RCharacterData,
	selected: Array[StrategicConclusionData],
	family_daimyo_ids: Array,
	characters_by_id: Dictionary,
) -> Array:
	var dispatches: Array = []
	for fd_id: int in family_daimyo_ids:
		var fd: L5RCharacterData = characters_by_id.get(fd_id)
		if fd == null or CharacterStats.is_dead(fd):
			continue
		# Family Daimyo present at court reads directly — no letter needed.
		if fd.physical_location == champion.physical_location:
			continue
		# Build a letter dispatch dict (actual LetterData creation in orchestrator).
		dispatches.append({
			"type": "strategic_conclusion_letter",
			"sender_id": champion.character_id,
			"recipient_id": fd_id,
			"conclusion_count": selected.size(),
		})
	return dispatches


# -- Phase 2 Cascade: Family Daimyo re-weighting helpers ----------------------

## Returns an Array of scored NeedType candidate Dicts for a Family Daimyo,
## derived from the clan's clan_strategic_priorities and the daimyo's personality.
## Format: [{"need_type": String, "score": int, "source": "champion_conclusion",
##            "conclusion_type": int, "target_clan_id": int}, ...]
static func get_champion_conclusion_needtypes(
	daimyo: L5RCharacterData,
	clan: ClanData,
) -> Array:
	var result: Array = []
	if clan == null:
		return result
	var virtue_key = _get_virtue_key(daimyo)
	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		var need_types: Array[String] = _CONCLUSION_TO_NEEDTYPES.get(sc.conclusion_type, [])
		for nt: String in need_types:
			# Re-weight champion score with Family Daimyo personality preference.
			var pref: int = _get_preference(virtue_key, sc.conclusion_type)
			if pref == HARD_BLOCK:
				continue
			var weighted_score: int = sc.score + pref
			result.append({
				"need_type": nt,
				"score": weighted_score,
				"source": "champion_conclusion",
				"conclusion_type": sc.conclusion_type,
				"target_clan_id": sc.target_clan_id,
				"is_forced": sc.is_forced,
			})
	return result


# Mapping table: conclusion_type → NeedTypes (s57.54.10a).
const _CONCLUSION_TO_NEEDTYPES: Dictionary = {
	StrategicConclusionData.ConclusionType.AGGRESSIVE_POSTURE:
		["TRAIN_TROOPS", "GATHER_INTELLIGENCE", "DEFEND_PROVINCE", "ASSESS_POWER_BALANCE"],
	StrategicConclusionData.ConclusionType.LAUNCH_OFFENSIVE:
		["INITIATE_WAR_CHECK", "DEPLOY_ARMY", "LEVY_TROOPS", "ACQUIRE_RESOURCE"],
	StrategicConclusionData.ConclusionType.SUPPRESS_INSTABILITY:
		["DEFEND_PROVINCE", "INVESTIGATE_THREAT", "UPHOLD_LAW", "PATROL_PROVINCE"],
	StrategicConclusionData.ConclusionType.SUPPORT_SHADOWLANDS:
		["DEFEND_PROVINCE", "ACQUIRE_RESOURCE", "MANAGE_TAINT", "PERFORM_RITUAL"],
	StrategicConclusionData.ConclusionType.DEFEND_TERRITORY:
		["DEFEND_PROVINCE", "BUILD_INFRASTRUCTURE", "TRAIN_TROOPS"],
	StrategicConclusionData.ConclusionType.PURSUE_ALLIANCE:
		["RAISE_DISPOSITION", "ARRANGE_MARRIAGE", "SEEK_PEACE", "GATHER_INTELLIGENCE"],
	StrategicConclusionData.ConclusionType.SEEK_PEACE:
		["SEEK_PEACE", "RAISE_DISPOSITION", "GATHER_INTELLIGENCE"],
	StrategicConclusionData.ConclusionType.UNDERMINE_POSITION:
		["DAMAGE_RELATIONSHIP", "GATHER_INTELLIGENCE", "ACQUIRE_LEVERAGE", "ATTEND_COURT"],
	StrategicConclusionData.ConclusionType.STRENGTHEN_COURT:
		["ATTEND_COURT", "RAISE_DISPOSITION", "GATHER_INTELLIGENCE", "SEEK_GLORY"],
	StrategicConclusionData.ConclusionType.COMPLY_EDICT:
		["HONOR_COMMITMENT"],
	StrategicConclusionData.ConclusionType.SECURE_RESOURCE:
		["ACQUIRE_RESOURCE", "CONDUCT_COMMERCE", "EVALUATE_PROVINCES"],
	StrategicConclusionData.ConclusionType.DEVELOP_INFRASTRUCTURE:
		["BUILD_INFRASTRUCTURE", "CONDUCT_COMMERCE", "EVALUATE_PROVINCES"],
	StrategicConclusionData.ConclusionType.RECOVER_DAMAGE:
		["ACQUIRE_RESOURCE", "BUILD_INFRASTRUCTURE", "EVALUATE_PROVINCES"],
	StrategicConclusionData.ConclusionType.RESTORE_WORSHIP:
		["RESTORE_WORSHIP", "PERFORM_RITUAL", "BUILD_INFRASTRUCTURE", "GATHER_INTELLIGENCE"],
	StrategicConclusionData.ConclusionType.RESPOND_SPIRITUAL_CRISIS:
		["INVESTIGATE_THREAT", "PERFORM_RITUAL", "DEFEND_PROVINCE"],
	StrategicConclusionData.ConclusionType.BUILD_CULTURAL_PRESTIGE:
		["PATRONIZE_ARTS", "BUILD_INFRASTRUCTURE", "SEEK_GLORY"],
}


# -- Operational Supervisor CO Budget (s57.54.10d) ----------------------------

## Returns the Civilian Order budget for a character who holds operational_superior_id
## authority over subordinates but is not a lord-tier character.
## Characters with BOTH lord vassals and operational subordinates use the higher budget.
static func get_operational_superior_co_budget(
	character: L5RCharacterData,
	characters_by_id: Dictionary,
) -> int:
	if character == null:
		return 0
	var operational_count: int = 0
	for _id: int in characters_by_id:
		var sub: L5RCharacterData = characters_by_id[_id]
		if sub == null or CharacterStats.is_dead(sub):
			continue
		if sub.operational_superior_id == character.character_id:
			operational_count += 1
	if operational_count == 0:
		return 0
	# 1–3 subordinates = 2 CO/day, 4+ = 3 CO/day (s57.54.10d).
	return 2 if operational_count <= 3 else 3


# -- Helpers -------------------------------------------------------------------

static func _make_conclusion(
	clan: ClanData,
	ct: StrategicConclusionData.ConclusionType,
	current_season: int,
) -> StrategicConclusionData:
	var sc := StrategicConclusionData.new()
	sc.conclusion_id = -1  # Assigned in Step 4.
	sc.conclusion_type = ct
	sc.domain = _CONCLUSION_DOMAINS[ct]
	sc.season_originated = current_season
	return sc


static func _make_with_source(
	clan: ClanData,
	ct: StrategicConclusionData.ConclusionType,
	current_season: int,
	source_topic_ids: Array,
) -> StrategicConclusionData:
	var sc := _make_conclusion(clan, ct, current_season)
	sc.source_topic_ids.assign(source_topic_ids)
	return sc


static func _add_candidate_if_new(
	candidates: Array[StrategicConclusionData],
	forced_types: Dictionary,
	sc: StrategicConclusionData,
) -> void:
	if sc == null:
		return
	if sc.conclusion_type in forced_types:
		return
	# Merge: if same type+target already exists, add source_topic_ids to existing entry.
	for existing: StrategicConclusionData in candidates:
		if existing.conclusion_type == sc.conclusion_type \
				and existing.target_clan_id == sc.target_clan_id:
			for tid: int in sc.source_topic_ids:
				if tid not in existing.source_topic_ids:
					existing.source_topic_ids.append(tid)
			return
	candidates.append(sc)


static func _get_virtue_key(character: L5RCharacterData):
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return character.shourido_virtue
	return character.bushido_virtue


static func _get_preference(virtue_key, ct: StrategicConclusionData.ConclusionType) -> int:
	var row: Array = _PREF_MATRIX.get(virtue_key, [])
	if row.is_empty():
		return 0
	var idx: int = ct
	if idx < 0 or idx >= row.size():
		return 0
	return row[idx]


static func _standing_obj_domain(
	champion: L5RCharacterData,
	objectives_map: Dictionary,
) -> int:
	var lord_objectives: Dictionary = objectives_map.get(champion.character_id, {})
	var standing: Dictionary = lord_objectives.get("standing", {})
	var nt: String = standing.get("need_type", "")
	return _STANDING_OBJ_DOMAIN.get(nt, -1)


static func _prev_conclusion_types(clan: ClanData) -> Dictionary:
	var types: Dictionary = {}
	for sc: StrategicConclusionData in clan.clan_strategic_priorities:
		types[sc.conclusion_type] = true
	return types


## Returns true when a conclusion is no longer relevant and should be removed.
## Called by _process_stale_champion_priorities() in DayOrchestrator after
## war and topic cleanup to trigger mid-quarter slot reclamation, especially
## for Ketsui champions (Trigger 3 — s57.54.1).
##
## Stale conditions:
##  - War-targeted types with no active war involving champion_clan vs target.
##  - COMPLY_EDICT when the edict is gone from active_edicts.
##  - Topic-sourced when all source topics are resolved or absent.
static func is_conclusion_stale(
	sc: StrategicConclusionData,
	champion_clan: String,
	active_wars: Array,
	active_edicts: Array,
	active_topics_by_id: Dictionary,
) -> bool:
	var war_targeted: Array = [
		StrategicConclusionData.ConclusionType.AGGRESSIVE_POSTURE,
		StrategicConclusionData.ConclusionType.LAUNCH_OFFENSIVE,
		StrategicConclusionData.ConclusionType.DEFEND_TERRITORY,
		StrategicConclusionData.ConclusionType.SEEK_PEACE,
		StrategicConclusionData.ConclusionType.UNDERMINE_POSITION,
	]
	if sc.conclusion_type in war_targeted and sc.target_clan_id >= 0:
		for war: Variant in active_wars:
			if war == null:
				continue
			var is_active: bool = war.is_active if war is WarData else bool((war as Dictionary).get("is_active", false))
			if not is_active:
				continue
			var ca: String = war.clan_a if war is WarData else String((war as Dictionary).get("clan_a", ""))
			var cb: String = war.clan_b if war is WarData else String((war as Dictionary).get("clan_b", ""))
			var is_a: bool = (ca == champion_clan)
			var is_b: bool = (cb == champion_clan)
			if not is_a and not is_b:
				continue
			var enemy: String = cb if is_a else ca
			if not enemy.is_empty() and enemy.hash() == sc.target_clan_id:
				return false  # War still active with this clan.
		return true  # No active war with the target clan.

	if sc.conclusion_type == StrategicConclusionData.ConclusionType.COMPLY_EDICT and sc.edict_id >= 0:
		for edict: Variant in active_edicts:
			var eid: int = edict.get("edict_id", -1) if edict is Dictionary else -1
			if eid == sc.edict_id:
				return false  # Edict still active.
		return true  # Edict no longer in active list.

	if sc.source_topic_ids.size() > 0:
		for tid: Variant in sc.source_topic_ids:
			var topic: TopicData = active_topics_by_id.get(int(tid))
			if topic != null and not topic.resolved:
				return false  # At least one source topic still active.
		return true  # All source topics resolved or removed.

	return false  # Standing-objective conclusions are never stale.


## Maps a clan name string to an integer ID.
## In this system, target_clan_id is used as an index for the clan in the
## active_wars / topic pipeline. We store -1 when unknown.
## The canonical mapping is done via the characters_by_id scan at call sites.
static func _clan_name_to_id(clan_name: String) -> int:
	# No persistent clan ID registry exists; use -1 and let call sites resolve.
	return -1 if clan_name.is_empty() else clan_name.hash()
