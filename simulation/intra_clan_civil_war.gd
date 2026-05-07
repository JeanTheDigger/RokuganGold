class_name IntraClanCivilWar
## Generalized Intra-Clan Civil War per GDD s53.2.
##
## Triggered when a Family Daimyo (or higher) refuses lawful authority. All
## named NPCs in the clan choose a faction; armies reconstitute; province
## stability bleeds; the war score climbs toward Legitimacy or Rebel
## victory. Civil-war-specific clan exceptions (Dragon, Phoenix) are
## queryable but the full Schism Crisis routing for those is in the
## clan-specific governance modules (s55.10.2, s55.10.3).
##
## Pure simulation class — no Node inheritance, no scene tree.
##
## State is a plain Dictionary owned by the caller, shaped:
##   {
##     "rebel_lord_id": int,
##     "authority_lord_id": int,
##     "clan": String,
##     "trigger_topic_id": int,
##     "season_started": int,
##     "season_resolved": int,            # -1 while active
##     "war_score": int,                  # 0..100, 50 = even
##     "faction_assignments": Dictionary, # character_id -> Faction
##     "consecutive_rebel_victory_seasons": int,
##     "active": bool,
##   }


# -- Faction enum ------------------------------------------------------------

enum Faction {
	NONE,
	LEGITIMACY,
	REBEL,
	RONIN,
}


# -- Loyalty factor weights (s53.2.2) ----------------------------------------

const WEIGHT_CHUGI: int = 30
const WEIGHT_DISPOSITION: int = 25
const WEIGHT_COMPETENCE: int = 20
const WEIGHT_GRIEVANCE: int = 15
const WEIGHT_AMBITION: int = 10

const REBEL_THRESHOLD: int = 50              # ≥50 chooses Rebel
const RONIN_PULL_THRESHOLD: int = 40         # both Chugi pull and disposition pull below 40 → ronin eligible

# Competence brackets per s53.2.2.
const COMPETENCE_PTS_STRONG: int = 20        # ≥75% completion
const COMPETENCE_PTS_MODERATE: int = 10      # 50-74%
const COMPETENCE_PTS_POOR: int = 3           # <50%

# Grievance points per s53.2.2.
const GRIEVANCE_PTS_STRONG: int = 12         # arbitrary/political removal — strong
const GRIEVANCE_PTS_NO_INFO: int = 5         # no info → safe default toward Legitimacy
const GRIEVANCE_PTS_WEAK: int = 2            # rebel was clearly failing → grievance is weak


# -- Stability penalty escalation (s53.2.6) ---------------------------------

const STABILITY_PENALTY_BASE: int = -3       # 0–7 seasons
const STABILITY_PENALTY_LONG: int = -5       # 8–11 seasons
const STABILITY_PENALTY_GRINDING: int = -7   # 12+ seasons

const HONOR_HEMORRHAGE_REBEL_PER_SEASON: float = -0.3
const COLLECTIVE_DIPLOMATIC_PENALTY: int = -10


# -- Resolution thresholds (s53.2.7) ----------------------------------------

const REBEL_VICTORY_SEASONS_REQUIRED: int = 6
const REBEL_VICTORY_HONOR_FLOOR: float = 1.0
const REBEL_LORD_DISGRACE_HONOR: float = 0.0

const CHAMPIONSHIP_SEIZURE_WAR_SCORE: int = 90
const SEIZURE_FORBIDDEN_CLANS: Array[String] = ["Dragon", "Phoenix"]


# -- War Score shifts (s53.2.5) ---------------------------------------------

const WS_FAMILY_DAIMYO_DEFECT: int = 12
const WS_PROVINCIAL_DAIMYO_DEFECT: int = 5
const WS_REBEL_DISGRACED: int = 15           # Rebel honor below 1.0
const WS_IMPERIAL_EDICT: int = 10
const WS_FOREIGN_INTERVENTION: int = 8


# -- Defection (s53.2.8) ----------------------------------------------------

const DEFECTION_WAR_SCORE_DESPERATE: int = 25
const DEFECTION_DISPOSITION_ENEMY: int = -20
const DEFECTION_HONOR_PENALTY: float = -0.5
const DEFECTOR_DISPOSITION_PENALTY: int = -15


# -- Precedent Effect (s53.2.10) --------------------------------------------

const PRECEDENT_DEFY_BONUS_STANDARD: int = 3
const PRECEDENT_DEFY_BONUS_SEIZURE: int = 5
const PRECEDENT_DURATION_SEASONS: int = 5


# -- State factory ----------------------------------------------------------

static func make_initial_state(
	rebel_lord_id: int,
	authority_lord_id: int,
	clan: String,
	trigger_topic_id: int,
	current_season: int,
) -> Dictionary:
	return {
		"rebel_lord_id": rebel_lord_id,
		"authority_lord_id": authority_lord_id,
		"clan": clan,
		"trigger_topic_id": trigger_topic_id,
		"season_started": current_season,
		"season_resolved": -1,
		"war_score": 50,
		"faction_assignments": {},
		"consecutive_rebel_victory_seasons": 0,
		"active": true,
	}


# -- Per-NPC factor scoring -------------------------------------------------

static func compute_chugi_pull(npc: L5RCharacterData) -> int:
	## Returns 0..100 — higher Chugi alignment means stronger Legitimacy pull.
	if npc == null:
		return 0
	if npc.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		return 100
	if npc.bushido_virtue == Enums.BushidoVirtue.NONE:
		return 30
	# Other bushido virtues: moderate baseline duty.
	return 50


static func compute_disposition_pull(npc: L5RCharacterData, rebel_lord_id: int) -> int:
	## Returns 0..100 — higher disposition toward the rebel lord = stronger Rebel pull.
	if npc == null or rebel_lord_id < 0:
		return 0
	var raw: int = int(npc.disposition_values.get(rebel_lord_id, 0))
	# Map -100..100 → 0..100.
	return clampi((raw + 100) / 2, 0, 100)


static func compute_ambition_pull(npc: L5RCharacterData) -> int:
	## Higher Ishi (Will) → seizes opportunities → Rebel pull.
	if npc == null:
		return 0
	if npc.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		return 100
	if npc.shourido_virtue == Enums.ShouridoVirtue.NONE:
		return 30
	return 50


static func competence_points(rebel_completion_rate: float) -> int:
	if rebel_completion_rate >= 0.75:
		return COMPETENCE_PTS_STRONG
	if rebel_completion_rate >= 0.50:
		return COMPETENCE_PTS_MODERATE
	return COMPETENCE_PTS_POOR


static func grievance_points(visibility_in_known_topics: bool, rebel_was_failing: bool) -> int:
	## - Topic not in known_topics → default to "no info" (5/15 toward Rebel).
	## - Topic known and rebel was failing → grievance is weak (2/15).
	## - Topic known and rebel was not failing → grievance is strong (12/15).
	if not visibility_in_known_topics:
		return GRIEVANCE_PTS_NO_INFO
	if rebel_was_failing:
		return GRIEVANCE_PTS_WEAK
	return GRIEVANCE_PTS_STRONG


# -- Loyalty evaluation (s53.2.2) -------------------------------------------

# Returns:
#   {
#     "faction": Faction,                # LEGITIMACY | REBEL | RONIN
#     "rebel_score": int,                # 0..100
#     "chugi_pull": int,                 # 0..100
#     "disposition_pull": int,           # 0..100
#   }
static func evaluate_loyalty(
	npc: L5RCharacterData,
	rebel_lord_id: int,
	rebel_completion_rate: float,
	grievance_visible: bool,
	rebel_was_failing: bool,
) -> Dictionary:
	if npc == null:
		return {"faction": Faction.NONE, "rebel_score": 0, "chugi_pull": 0, "disposition_pull": 0}

	var chugi_pull: int = compute_chugi_pull(npc)
	var disp_pull: int = compute_disposition_pull(npc, rebel_lord_id)
	var ambition_pull: int = compute_ambition_pull(npc)

	# Rebel-favoring contribution from each factor:
	#   Low Chugi → high contribution (1.0 - chugi/100) * weight
	#   High disposition toward rebel → high contribution (disp/100) * weight
	#   Strong rebel competence → high contribution
	#   Strong grievance → high contribution
	#   High Ishi → high contribution
	var chugi_contrib: float = (1.0 - float(chugi_pull) / 100.0) * float(WEIGHT_CHUGI)
	var disp_contrib: float = float(disp_pull) / 100.0 * float(WEIGHT_DISPOSITION)
	var comp_contrib: float = float(competence_points(rebel_completion_rate))
	var griev_contrib: float = float(grievance_points(grievance_visible, rebel_was_failing))
	var amb_contrib: float = float(ambition_pull) / 100.0 * float(WEIGHT_AMBITION)

	var rebel_score: int = int(round(
		chugi_contrib + disp_contrib + comp_contrib + griev_contrib + amb_contrib
	))
	rebel_score = clampi(rebel_score, 0, 100)

	# Ronin path — low Chugi (weak Legitimacy pull) AND low disposition
	# toward rebel (weak Rebel pull) — character has no strong attachment.
	if chugi_pull < RONIN_PULL_THRESHOLD and disp_pull < RONIN_PULL_THRESHOLD:
		return {
			"faction": Faction.RONIN,
			"rebel_score": rebel_score,
			"chugi_pull": chugi_pull,
			"disposition_pull": disp_pull,
		}

	var faction: Faction = (
		Faction.REBEL if rebel_score >= REBEL_THRESHOLD else Faction.LEGITIMACY
	)
	return {
		"faction": faction,
		"rebel_score": rebel_score,
		"chugi_pull": chugi_pull,
		"disposition_pull": disp_pull,
	}


static func assign_faction(state: Dictionary, character_id: int, faction: Faction) -> void:
	state["faction_assignments"][character_id] = faction


static func get_faction(state: Dictionary, character_id: int) -> Faction:
	return state["faction_assignments"].get(character_id, Faction.NONE)


# -- Stability penalty per season (s53.2.6) ---------------------------------

static func get_stability_penalty(seasons_active: int) -> int:
	if seasons_active >= 12:
		return STABILITY_PENALTY_GRINDING
	if seasons_active >= 8:
		return STABILITY_PENALTY_LONG
	return STABILITY_PENALTY_BASE


static func apply_seasonal_consequences(
	state: Dictionary,
	rebel_lord: L5RCharacterData,
	provinces_in_clan: Array,
	current_season: int,
) -> Dictionary:
	## Applies stability penalty to all clan provinces and the rebel lord's
	## per-season Honor hemorrhage. Returns a result dict describing what
	## changed.
	var seasons_active: int = current_season - int(state.get("season_started", current_season))
	var penalty: int = get_stability_penalty(seasons_active)
	var stability_changes: Array[Dictionary] = []
	for prov in provinces_in_clan:
		if prov == null:
			continue
		var before: float = prov.stability
		prov.stability = clampf(prov.stability + float(penalty), 0.0, 100.0)
		stability_changes.append({
			"province_id": prov.province_id,
			"before": before,
			"after": prov.stability,
		})
	if rebel_lord != null:
		rebel_lord.honor = clampf(
			rebel_lord.honor + HONOR_HEMORRHAGE_REBEL_PER_SEASON, 0.0, 10.0
		)
	return {
		"penalty_applied": penalty,
		"seasons_active": seasons_active,
		"stability_changes": stability_changes,
	}


# -- War Score shifts (s53.2.5) ---------------------------------------------
# Positive shifts favor the Legitimacy faction; negative favor the Rebel.

static func shift_war_score(state: Dictionary, delta: int) -> int:
	var new_score: int = clampi(int(state.get("war_score", 50)) + delta, 0, 100)
	state["war_score"] = new_score
	return new_score


static func record_defection(
	state: Dictionary,
	defector_id: int,
	defector_was_family_daimyo: bool,
	to_legitimacy: bool,
) -> int:
	## Updates war_score and re-assigns the defector. Returns the new war score.
	var magnitude: int = (
		WS_FAMILY_DAIMYO_DEFECT if defector_was_family_daimyo
		else WS_PROVINCIAL_DAIMYO_DEFECT
	)
	var delta: int = magnitude if to_legitimacy else -magnitude
	state["faction_assignments"][defector_id] = (
		Faction.LEGITIMACY if to_legitimacy else Faction.REBEL
	)
	return shift_war_score(state, delta)


static func record_rebel_disgrace(state: Dictionary) -> int:
	## Rebel lord's Honor dropped below 1.0 — major Legitimacy boost.
	return shift_war_score(state, WS_REBEL_DISGRACED)


static func record_imperial_edict(state: Dictionary, supports_legitimacy: bool) -> int:
	var delta: int = WS_IMPERIAL_EDICT if supports_legitimacy else -WS_IMPERIAL_EDICT
	return shift_war_score(state, delta)


static func record_foreign_intervention(state: Dictionary, supports_legitimacy: bool) -> int:
	var delta: int = WS_FOREIGN_INTERVENTION if supports_legitimacy else -WS_FOREIGN_INTERVENTION
	return shift_war_score(state, delta)


# -- Resolution (s53.2.7) ---------------------------------------------------

static func check_legitimacy_victory(
	state: Dictionary,
	rebel_lord: L5RCharacterData,
	rebel_capitulated: bool = false,
	rebel_seat_lost: bool = false,
) -> bool:
	if rebel_lord == null:
		return false
	if rebel_capitulated:
		return true
	# Disgrace — Honor below 0.0 means automatic vassal loss per Section 4.6.
	if rebel_lord.honor < REBEL_LORD_DISGRACE_HONOR:
		return true
	if rebel_seat_lost:
		return true
	# Death is signaled via rebel_lord being treated as deceased; left to caller.
	return false


static func tick_rebel_victory_counter(
	state: Dictionary,
	rebel_lord: L5RCharacterData,
	holds_seat: bool,
	has_allied_family_daimyo: bool,
) -> int:
	## Per s53.2.7 Rebel Victory: 6 consecutive seasons meeting all three
	## conditions. Counter resets on any failure.
	if rebel_lord == null:
		state["consecutive_rebel_victory_seasons"] = 0
		return 0
	if rebel_lord.honor < REBEL_VICTORY_HONOR_FLOOR or not holds_seat or not has_allied_family_daimyo:
		state["consecutive_rebel_victory_seasons"] = 0
		return 0
	var n: int = int(state.get("consecutive_rebel_victory_seasons", 0)) + 1
	state["consecutive_rebel_victory_seasons"] = n
	return n


static func is_rebel_victory_achieved(state: Dictionary) -> bool:
	return int(state.get("consecutive_rebel_victory_seasons", 0)) >= REBEL_VICTORY_SEASONS_REQUIRED


# -- Championship Seizure (s53.2.7) -----------------------------------------

static func can_seize_championship(
	state: Dictionary,
	clan: String,
	rebel_lord_was_family_daimyo: bool,
	incumbent_disgraced_or_dead: bool,
) -> bool:
	## Returns true when the rebel may claim the Clan Champion position.
	## Dragon and Phoenix have absolute exceptions (s55.10.2 / s55.10.3).
	if clan in SEIZURE_FORBIDDEN_CLANS:
		return false
	if not rebel_lord_was_family_daimyo:
		return false
	if not incumbent_disgraced_or_dead:
		return false
	return int(state.get("war_score", 50)) >= CHAMPIONSHIP_SEIZURE_WAR_SCORE


# -- Defection (s53.2.8) ----------------------------------------------------

static func defection_trigger_fired(
	state: Dictionary,
	npc: L5RCharacterData,
	npc_faction_leader_id: int,
	npc_lord_killed: bool = false,
	imperial_edict_against_faction: bool = false,
) -> bool:
	## Returns true if any of the four GDD triggers applies for this NPC.
	if npc == null:
		return false
	if npc_lord_killed:
		return true
	if imperial_edict_against_faction:
		return true
	# Faction war-score-Desperate check.
	var faction: Faction = get_faction(state, npc.character_id)
	var ws: int = int(state.get("war_score", 50))
	if faction == Faction.LEGITIMACY and ws < DEFECTION_WAR_SCORE_DESPERATE:
		return true
	if faction == Faction.REBEL and (100 - ws) < DEFECTION_WAR_SCORE_DESPERATE:
		return true
	# Disposition toward faction leader < Enemy.
	var disp: int = int(npc.disposition_values.get(npc_faction_leader_id, 0))
	if disp < DEFECTION_DISPOSITION_ENEMY:
		return true
	return false


static func apply_defection_consequences(
	defector: L5RCharacterData,
	former_faction_members: Array,
) -> void:
	## Applies the GDD's defection penalties: -0.5 Honor on the defector
	## and -15 disposition on every former faction member toward them.
	if defector == null:
		return
	defector.honor = clampf(defector.honor + DEFECTION_HONOR_PENALTY, 0.0, 10.0)
	for c in former_faction_members:
		if c == null or c == defector:
			continue
		var current: int = int(c.disposition_values.get(defector.character_id, 0))
		c.disposition_values[defector.character_id] = clampi(
			current + DEFECTOR_DISPOSITION_PENALTY, -100, 100
		)


# -- Precedent Effect (s53.2.10) --------------------------------------------
#
# `precedent_modifiers` is a Dictionary owned by the world:
#   { season_added: { "bonus": int, "expires": int } }
# Multiple successful rebellions stack their modifiers.

static func apply_precedent_effect(
	precedent_modifiers: Dictionary,
	current_season: int,
	from_seizure: bool,
) -> void:
	## Adds a new modifier to the world's precedent_modifiers dict. Standard
	## rebel victory grants +3; Championship Seizure grants +5.
	var bonus: int = (
		PRECEDENT_DEFY_BONUS_SEIZURE if from_seizure
		else PRECEDENT_DEFY_BONUS_STANDARD
	)
	precedent_modifiers[current_season] = {
		"bonus": bonus,
		"expires": current_season + PRECEDENT_DURATION_SEASONS,
	}


static func tick_precedent_decay(
	precedent_modifiers: Dictionary,
	current_season: int,
) -> int:
	## Removes expired modifiers. Returns the count removed.
	var removed: int = 0
	var keys: Array = precedent_modifiers.keys().duplicate()
	for k in keys:
		var mod: Dictionary = precedent_modifiers[k]
		if int(mod.get("expires", 0)) <= current_season:
			precedent_modifiers.erase(k)
			removed += 1
	return removed


static func get_active_precedent_bonus(precedent_modifiers: Dictionary) -> int:
	var total: int = 0
	for k in precedent_modifiers:
		total += int(precedent_modifiers[k].get("bonus", 0))
	return total


# -- Resolution finaliser ---------------------------------------------------

static func finalise(
	state: Dictionary,
	current_season: int,
	legitimacy_won: bool,
) -> void:
	state["active"] = false
	state["season_resolved"] = current_season
	state["legitimacy_victory"] = legitimacy_won
	state["rebel_victory"] = not legitimacy_won
