class_name OtomoSeiyakuSystem
## Otomo Seiyaku System — Faction-level alliance suppression per GDD s55.22b.
## The Otomo family monitors clan-to-clan Champion disposition and assigns
## operatives to degrade dangerously warm relationships across all channels
## (court, visits, letters, daily conversation).

const DEFAULT_ALARM_THRESHOLD: int = 45
const CANCEL_BUFFER: int = 10  # Directive cancelled when disp drops below threshold - buffer
const ESCALATION_SEASONS: int = 2
const BASE_OPERATIVE_POOL: int = 3
const DETECTION_TOPIC_TIER: int = 4  # TopicData.Tier.TIER_4
const FORMAL_ALLIANCE_FLOOR: int = 31

const GREAT_CLANS: Array[String] = [
	"Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn",
]


# -- Emperor Archetype Modifiers (s55.22b §5) ----------------------------------

const ARCHETYPE_THRESHOLDS: Dictionary = {
	StrategicReview.EmperorArchetype.BENEVOLENT: 55,
	StrategicReview.EmperorArchetype.IRON: 45,
	StrategicReview.EmperorArchetype.CUNNING: 35,
	StrategicReview.EmperorArchetype.WARLIKE: 45,
	StrategicReview.EmperorArchetype.TYRANT: 25,
}

const ARCHETYPE_POOL_BONUS: Dictionary = {
	StrategicReview.EmperorArchetype.BENEVOLENT: 0,
	StrategicReview.EmperorArchetype.IRON: 0,
	StrategicReview.EmperorArchetype.CUNNING: 1,
	StrategicReview.EmperorArchetype.WARLIKE: 0,
	StrategicReview.EmperorArchetype.TYRANT: 2,
}


static func get_alarm_threshold(archetype: int) -> int:
	return ARCHETYPE_THRESHOLDS.get(archetype, DEFAULT_ALARM_THRESHOLD)


static func get_operative_pool_size(
	archetype: int,
	otomo_courtier_count: int,
) -> int:
	var base: int = BASE_OPERATIVE_POOL
	base += ARCHETYPE_POOL_BONUS.get(archetype, 0)
	base += otomo_courtier_count / 2
	return base


# -- Clan Pair Key Helper ------------------------------------------------------

static func make_pair_key(clan_a: String, clan_b: String) -> String:
	if clan_a < clan_b:
		return clan_a + "||" + clan_b
	return clan_b + "||" + clan_a


static func get_all_clan_pairs() -> Array[String]:
	var pairs: Array[String] = []
	for i: int in range(GREAT_CLANS.size()):
		for j: int in range(i + 1, GREAT_CLANS.size()):
			pairs.append(make_pair_key(GREAT_CLANS[i], GREAT_CLANS[j]))
	return pairs


# -- Alliance Alarm Scanning (s55.22b §2) --------------------------------------

static func scan_champion_dispositions(
	champion_dispositions: Dictionary,
	threshold: int,
	active_wars: Array = [],
	emperor_war_exemptions: bool = false,
) -> Array[Dictionary]:
	var alarms: Array[Dictionary] = []
	var pairs: Array[String] = get_all_clan_pairs()
	for pair_key: String in pairs:
		var disp: int = champion_dispositions.get(pair_key, 0)
		if disp < threshold:
			continue
		var parts: Array = pair_key.split("||")
		var clan_a: String = parts[0]
		var clan_b: String = parts[1]
		if emperor_war_exemptions and _are_clans_allied_in_war(clan_a, clan_b, active_wars):
			continue
		alarms.append({
			"pair_key": pair_key,
			"clan_a": clan_a,
			"clan_b": clan_b,
			"disposition": disp,
		})
	alarms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["disposition"] > b["disposition"]
	)
	return alarms


static func _are_clans_allied_in_war(
	clan_a: String,
	clan_b: String,
	active_wars: Array,
) -> bool:
	for war: Variant in active_wars:
		if war is Dictionary:
			var side_a: String = war.get("clan_a", "")
			var side_b: String = war.get("clan_b", "")
			var allies_a: Array = war.get("allied_clans_a", [])
			var allies_b: Array = war.get("allied_clans_b", [])
			var side_a_all: Array = [side_a] + allies_a
			var side_b_all: Array = [side_b] + allies_b
			if clan_a in side_a_all and clan_b in side_a_all:
				return true
			if clan_a in side_b_all and clan_b in side_b_all:
				return true
	return false


# -- Seiyaku Directive Management (s55.22b §3) ---------------------------------

static func make_initial_state() -> Dictionary:
	return {
		"active_directives": {},  # pair_key -> directive dict
		"assigned_operatives": {},  # operative_id -> pair_key
		"seasons_above_threshold": {},  # pair_key -> int
		"formal_alliances": {},  # pair_key -> bool
		"exhaustion_topic_generated": false,
	}


static func create_directive(
	pair_key: String,
	operative_id: int,
	clan_a: String,
	clan_b: String,
) -> Dictionary:
	return {
		"pair_key": pair_key,
		"operative_id": operative_id,
		"clan_a": clan_a,
		"clan_b": clan_b,
		"escalated": false,
		"seasons_active": 0,
		"effectiveness_halved": false,
	}


static func assign_directives(
	state: Dictionary,
	alarms: Array[Dictionary],
	available_operative_ids: Array[int],
	pool_size: int,
) -> Array[Dictionary]:
	var new_directives: Array[Dictionary] = []
	var directives: Dictionary = state["active_directives"]
	var assigned: Dictionary = state["assigned_operatives"]

	var used_count: int = assigned.size()

	for alarm: Dictionary in alarms:
		var pair_key: String = alarm["pair_key"]
		if directives.has(pair_key):
			continue
		if used_count >= pool_size:
			break

		var operative_id: int = -1
		for oid: int in available_operative_ids:
			if not assigned.has(oid):
				operative_id = oid
				break
		if operative_id < 0:
			break

		var directive: Dictionary = create_directive(
			pair_key, operative_id, alarm["clan_a"], alarm["clan_b"],
		)
		directives[pair_key] = directive
		assigned[operative_id] = pair_key
		used_count += 1
		new_directives.append(directive)

	return new_directives


static func cancel_directive(state: Dictionary, pair_key: String) -> void:
	var directives: Dictionary = state["active_directives"]
	if not directives.has(pair_key):
		return
	var directive: Dictionary = directives[pair_key]
	var operative_id: int = directive.get("operative_id", -1)
	if operative_id >= 0:
		state["assigned_operatives"].erase(operative_id)
	directives.erase(pair_key)
	state["seasons_above_threshold"].erase(pair_key)


# -- Escalation (s55.22b §3.2) ------------------------------------------------

static func update_escalation(
	state: Dictionary,
	champion_dispositions: Dictionary,
	threshold: int,
) -> Array[String]:
	var escalated_pairs: Array[String] = []
	var seasons: Dictionary = state["seasons_above_threshold"]
	var directives: Dictionary = state["active_directives"]

	for pair_key: String in directives:
		var disp: int = champion_dispositions.get(pair_key, 0)
		if disp >= threshold:
			seasons[pair_key] = seasons.get(pair_key, 0) + 1
		else:
			seasons[pair_key] = 0

		if seasons.get(pair_key, 0) >= ESCALATION_SEASONS:
			if not directives[pair_key].get("escalated", false):
				directives[pair_key]["escalated"] = true
				escalated_pairs.append(pair_key)

	return escalated_pairs


# -- Directive Cancellation Check (s55.22b §4.1) ------------------------------

static func check_cancellations(
	state: Dictionary,
	champion_dispositions: Dictionary,
	threshold: int,
) -> Array[String]:
	var cancelled: Array[String] = []
	var cancel_threshold: int = threshold - CANCEL_BUFFER
	var directives: Dictionary = state["active_directives"]
	var keys: Array = directives.keys()

	for pair_key: Variant in keys:
		var disp: int = champion_dispositions.get(pair_key as String, 0)
		if disp < cancel_threshold:
			cancel_directive(state, pair_key as String)
			cancelled.append(pair_key as String)

	return cancelled


# -- Operative Exhaustion (s55.22b §4.3) --------------------------------------

static func is_pool_exhausted(state: Dictionary, pool_size: int) -> bool:
	return state["assigned_operatives"].size() >= pool_size


static func check_exhaustion_topic(
	state: Dictionary,
	pool_size: int,
	pending_alarms: int,
) -> bool:
	if pending_alarms <= 0:
		return false
	if not is_pool_exhausted(state, pool_size):
		return false
	if state.get("exhaustion_topic_generated", false):
		return false
	state["exhaustion_topic_generated"] = true
	return true


# -- Formal Alliance (s55.22b §6.2) -------------------------------------------

static func declare_formal_alliance(
	state: Dictionary,
	pair_key: String,
) -> void:
	state["formal_alliances"][pair_key] = true
	var directives: Dictionary = state["active_directives"]
	if directives.has(pair_key):
		directives[pair_key]["escalated"] = true


static func is_formal_alliance(state: Dictionary, pair_key: String) -> bool:
	return state["formal_alliances"].get(pair_key, false)


static func get_alliance_disposition_floor(state: Dictionary, pair_key: String) -> int:
	if is_formal_alliance(state, pair_key):
		return FORMAL_ALLIANCE_FLOOR
	return -100


static func dissolve_formal_alliance(state: Dictionary, pair_key: String) -> void:
	state["formal_alliances"].erase(pair_key)


# -- Detection (s55.22b §6.1) -------------------------------------------------

static func resolve_detection(
	detector_courtier_roll: int,
	operative_courtier_roll: int,
) -> bool:
	return detector_courtier_roll > operative_courtier_roll


static func apply_detection(
	state: Dictionary,
	pair_key: String,
) -> Dictionary:
	var directives: Dictionary = state["active_directives"]
	if not directives.has(pair_key):
		return {}
	directives[pair_key]["effectiveness_halved"] = true
	return {
		"pair_key": pair_key,
		"sympathy_bonus": 5,
	}


# -- Operative Effect Estimation (s55.22b §3.1) --------------------------------

const COURT_EFFECT_MIN: int = -3
const COURT_EFFECT_MAX: int = -8
const VISIT_EFFECT_MIN: int = -2
const VISIT_EFFECT_MAX: int = -5
const LETTER_EFFECT_MIN: int = -1
const LETTER_EFFECT_MAX: int = -2
const COMBINED_EFFECT_MIN: int = -5
const COMBINED_EFFECT_MAX: int = -12


static func estimate_seasonal_effect(
	directive: Dictionary,
	has_court_access: bool,
	visits_conducted: int,
	letters_sent: bool,
) -> int:
	var effect: int = 0
	var halved: bool = directive.get("effectiveness_halved", false)

	if has_court_access:
		effect += COURT_EFFECT_MIN
	if visits_conducted > 0:
		effect += VISIT_EFFECT_MIN * visits_conducted
	if letters_sent:
		effect += LETTER_EFFECT_MIN

	if halved:
		effect = effect / 2

	return clampi(effect, COMBINED_EFFECT_MAX, 0)


# -- Interaction Skill Bonus (s55.22b §3.1) -----------------------------------

const OPERATIVE_COURT_SKILL_BONUS: int = 10


static func get_operative_skill_bonus(
	state: Dictionary,
	operative_id: int,
) -> int:
	if not state["assigned_operatives"].has(operative_id):
		return 0
	return OPERATIVE_COURT_SKILL_BONUS


# -- Limitations (s55.22b §6.3) -----------------------------------------------

static func is_valid_target_pair(clan_a: String, clan_b: String) -> bool:
	if clan_a == "Imperial" or clan_b == "Imperial":
		return false
	if clan_a == clan_b:
		return false
	return clan_a in GREAT_CLANS and clan_b in GREAT_CLANS


# -- Seasonal Processing Entry Point -------------------------------------------

static func process_seasonal_review(
	state: Dictionary,
	champion_dispositions: Dictionary,
	archetype: int,
	available_operative_ids: Array[int],
	otomo_courtier_count: int,
	active_wars: Array = [],
) -> Dictionary:
	var threshold: int = get_alarm_threshold(archetype)
	var pool_size: int = get_operative_pool_size(archetype, otomo_courtier_count)
	var emperor_war_exemptions: bool = (archetype == StrategicReview.EmperorArchetype.WARLIKE)

	var cancelled: Array[String] = check_cancellations(state, champion_dispositions, threshold)

	var alarms: Array[Dictionary] = scan_champion_dispositions(
		champion_dispositions, threshold, active_wars, emperor_war_exemptions,
	)

	var new_directives: Array[Dictionary] = assign_directives(
		state, alarms, available_operative_ids, pool_size,
	)

	var escalated: Array[String] = update_escalation(
		state, champion_dispositions, threshold,
	)

	for pair_key: String in state["active_directives"]:
		state["active_directives"][pair_key]["seasons_active"] += 1

	var uncovered_count: int = 0
	for alarm: Dictionary in alarms:
		if not state["active_directives"].has(alarm["pair_key"]):
			uncovered_count += 1

	var exhaustion_topic: bool = check_exhaustion_topic(state, pool_size, uncovered_count)

	return {
		"threshold": threshold,
		"pool_size": pool_size,
		"alarms": alarms,
		"new_directives": new_directives,
		"cancelled": cancelled,
		"escalated": escalated,
		"exhaustion_topic": exhaustion_topic,
		"active_directive_count": state["active_directives"].size(),
		"uncovered_alarm_count": uncovered_count,
	}
