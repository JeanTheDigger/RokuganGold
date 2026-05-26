class_name WinterCourtSystem
## Winter Court lifecycle per GDD s55.10.
## Castle-level host selection, three-phase invitation pipeline,
## Emperor's Peace, regent substitution, host prestige & advantages.
## Pure static functions — no Node inheritance.


# -- Constants -----------------------------------------------------------------

const GRACE_PERIOD_DAYS: int = 15
const WINTER_START_IC_DAY: int = 241
const COURT_CLOSE_IC_DAY: int = 361
const ANNOUNCEMENT_IC_DAY: int = 200

const AGENDA_TOPIC_DAYS: Array[int] = [45, 35, 25]

const HOST_SKILL_BONUS: int = 5
const HOST_SKILL_IDS: Array[String] = ["Etiquette", "Courtier", "Sincerity"]

const GLORY_HOST_FAMILY_DAIMYO: float = 0.5
const GLORY_HOST_CLAN_CHAMPION: float = 0.3
const GLORY_HOST_CLAN_DELEGATE: float = 0.1

const REGENT_PRESTIGE: int = 2

const CLAN_RECENCY_CAP_YEARS: int = 7

const HOSTILE_ACTIONS: Array[String] = [
	"ATTACK", "INTIMIDATE", "CHALLENGE_TO_DUEL", "ASSASSINATION",
	"POISON", "SABOTAGE", "RAID_HARVEST", "ORDER_BATTLE",
]

const EMPERORS_PEACE_EXEMPT: Array[String] = [
	"CHALLENGE_TO_DUEL",
]

const COVERT_ACTIONS_PERMITTED: Array[String] = [
	"EAVESDROP", "FABRICATE_SECRET", "INTERCEPT_LETTER",
	"SEARCH_QUARTERS", "BRIBE_FOR_INFO",
]

const DELEGATION_CAPACITY: Dictionary = {
	Enums.LordRank.PROVINCIAL_DAIMYO: {
		"total": 70, "emperor_retinue": 10, "personal_invitations": 3,
		"clan_slots_total": 57, "per_clan": 8,
	},
	Enums.LordRank.FAMILY_DAIMYO: {
		"total": 105, "emperor_retinue": 10, "personal_invitations": 4,
		"clan_slots_total": 91, "per_clan": 13,
	},
	Enums.LordRank.CLAN_CHAMPION: {
		"total": 150, "emperor_retinue": 10, "personal_invitations": 5,
		"clan_slots_total": 135, "per_clan": 19,
	},
}

const HOST_SELECTION_WEIGHTS: Dictionary = {
	StrategicReview.EmperorArchetype.BENEVOLENT: {
		"disposition": 5, "clan_recency": 15, "province_stability": 5,
		"crisis_relevance": 20, "family_prestige": 5,
	},
	StrategicReview.EmperorArchetype.IRON: {
		"disposition": 5, "clan_recency": 25, "province_stability": 10,
		"crisis_relevance": 0, "family_prestige": 10,
	},
	StrategicReview.EmperorArchetype.CUNNING: {
		"disposition": 15, "clan_recency": 0, "province_stability": 5,
		"crisis_relevance": 20, "family_prestige": 10,
	},
	StrategicReview.EmperorArchetype.WARLIKE: {
		"disposition": 5, "clan_recency": 5, "province_stability": 0,
		"crisis_relevance": 25, "family_prestige": 15,
	},
	StrategicReview.EmperorArchetype.TYRANT: {
		"disposition": 20, "clan_recency": 0, "province_stability": 10,
		"crisis_relevance": 0, "family_prestige": 20,
	},
}

const PERSONAL_INVITATION_WEIGHTS: Dictionary = {
	StrategicReview.EmperorArchetype.BENEVOLENT: {
		"disposition": 5, "prestige": 3, "crisis_relevance": 17, "school_type": 5,
	},
	StrategicReview.EmperorArchetype.IRON: {
		"disposition": 3, "prestige": 10, "crisis_relevance": 10, "school_type": 7,
	},
	StrategicReview.EmperorArchetype.CUNNING: {
		"disposition": 10, "prestige": 5, "crisis_relevance": 12, "school_type": 3,
	},
	StrategicReview.EmperorArchetype.WARLIKE: {
		"disposition": 3, "prestige": 7, "crisis_relevance": 10, "school_type": 10,
	},
	StrategicReview.EmperorArchetype.TYRANT: {
		"disposition": 15, "prestige": 10, "crisis_relevance": 0, "school_type": 5,
	},
}

const BENEVOLENT_CRISIS_TYPES: Array[String] = [
	"famine", "plague", "spiritual", "refugee",
]

const WARLIKE_CRISIS_TYPES: Array[String] = [
	"war", "shadowlands", "bandit", "insurgent", "military",
]

const GREAT_CLANS: Array[String] = [
	"Crab", "Crane", "Dragon", "Lion", "Mantis", "Phoenix", "Scorpion", "Unicorn",
]


# -- Host Selection (Castle-Level) --------------------------------------------

static func select_host_castle(
	emperor: L5RCharacterData,
	archetype: int,
	characters_by_id: Dictionary,
	provinces: Array,
	settlements: Array,
	active_topics: Array,
	world_state: Dictionary,
) -> Dictionary:
	var current_season: int = world_state.get("current_season", 0)
	if current_season != TimeSystem.Season.AUTUMN:
		return {}

	var weights: Dictionary = HOST_SELECTION_WEIGHTS.get(archetype, HOST_SELECTION_WEIGHTS[StrategicReview.EmperorArchetype.IRON])
	return _select_host_with_weights(
		emperor, characters_by_id, provinces, settlements,
		active_topics, world_state, weights, archetype,
	)


static func select_host_regent(
	chancellor: L5RCharacterData,
	characters_by_id: Dictionary,
	provinces: Array,
	settlements: Array,
	active_topics: Array,
	world_state: Dictionary,
) -> Dictionary:
	var regent_state: Dictionary = world_state.duplicate()
	regent_state["current_season"] = TimeSystem.Season.AUTUMN
	var result: Dictionary = _select_host_with_weights(
		chancellor, characters_by_id, provinces, settlements,
		active_topics, regent_state,
		{"disposition": 10, "clan_recency": 10, "province_stability": 10,
		 "crisis_relevance": 10, "family_prestige": 10},
		-1,
	)
	if not result.is_empty():
		result["is_regent_court"] = true
	return result


# -- Scoring Helpers -----------------------------------------------------------

static func _score_disposition(
	emperor: L5RCharacterData,
	champion: L5RCharacterData,
	archetype: int,
) -> float:
	if champion == null:
		return 5.0
	var disp: float = emperor.disposition_values.get(champion.character_id, 0.0)
	if archetype == StrategicReview.EmperorArchetype.CUNNING:
		return _inverse_bell_curve(disp)
	return clampf((disp + 100.0) / 200.0 * 10.0, 0.0, 10.0)


static func _inverse_bell_curve(disposition: float) -> float:
	var abs_disp: float = absf(disposition)
	if abs_disp <= 30.0:
		return 10.0
	if abs_disp >= 100.0:
		return 0.0
	return (100.0 - abs_disp) / 70.0 * 10.0


static func _score_clan_recency(
	clan: String,
	last_host_clan_years: Dictionary,
	current_ic_year: int,
) -> float:
	if not last_host_clan_years.has(clan):
		return 10.0
	var years_since: int = current_ic_year - int(last_host_clan_years[clan])
	return clampf(float(years_since) / float(CLAN_RECENCY_CAP_YEARS) * 10.0, 0.0, 10.0)


static func _score_province_stability(province: ProvinceData) -> float:
	return clampf(province.stability / 10.0, 0.0, 10.0)


static func _score_crisis_relevance(
	province: ProvinceData,
	active_topics: Array,
	archetype: int,
) -> float:
	var max_momentum: float = 0.0
	for topic: TopicData in active_topics:
		if topic.resolved:
			continue
		if province.province_id not in topic.provinces_affected:
			continue
		if not _crisis_type_matches_archetype(topic, archetype):
			continue
		if topic.momentum > max_momentum:
			max_momentum = topic.momentum

	return clampf(max_momentum / 10.0, 0.0, 10.0)


static func _crisis_type_matches_archetype(topic: TopicData, archetype: int) -> bool:
	match archetype:
		StrategicReview.EmperorArchetype.BENEVOLENT:
			var tt: String = topic.topic_type if topic.topic_type != "" else ""
			var tv: String = topic.variant if topic.variant != "" else ""
			for ct: String in BENEVOLENT_CRISIS_TYPES:
				if ct in tt or ct in tv:
					return true
			return false
		StrategicReview.EmperorArchetype.WARLIKE:
			var tt: String = topic.topic_type if topic.topic_type != "" else ""
			var tv: String = topic.variant if topic.variant != "" else ""
			for ct: String in WARLIKE_CRISIS_TYPES:
				if ct in tt or ct in tv:
					return true
			return false
		StrategicReview.EmperorArchetype.CUNNING:
			return true
		_:
			return true


static func _score_family_prestige(daimyo: L5RCharacterData) -> float:
	var combined: float = (daimyo.status + daimyo.glory) / 2.0
	return clampf(combined, 0.0, 10.0)


# -- Delegation Pipeline -------------------------------------------------------

static func get_delegation_capacity(host_lord_rank: Enums.LordRank) -> Dictionary:
	if DELEGATION_CAPACITY.has(host_lord_rank):
		return DELEGATION_CAPACITY[host_lord_rank].duplicate()
	return DELEGATION_CAPACITY[Enums.LordRank.PROVINCIAL_DAIMYO].duplicate()


static func select_clan_delegation(
	champion: L5RCharacterData,
	vassals: Array,
	slots: int,
	agenda_topic_ids: Array,
	topic_pool_map: Dictionary,
) -> Array:
	if vassals.is_empty() or slots <= 0:
		return []

	var scored: Array = []
	for vassal: L5RCharacterData in vassals:
		if CharacterStats.is_dead(vassal):
			continue
		var score: float = _score_delegate_candidate(vassal, champion, agenda_topic_ids, topic_pool_map)
		scored.append({"id": vassal.character_id, "score": score, "char": vassal})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	var selected_ids: Array = []
	for i: int in range(mini(slots, scored.size())):
		selected_ids.append(int(scored[i]["id"]))

	selected_ids = _apply_yojimbo_pull_in(selected_ids, vassals)

	return selected_ids


static func _score_delegate_candidate(
	candidate: L5RCharacterData,
	champion: L5RCharacterData,
	agenda_topic_ids: Array,
	topic_pool_map: Dictionary,
) -> float:
	var court_skills: float = 0.0
	court_skills += float(candidate.skills.get("Etiquette", 0))
	court_skills += float(candidate.skills.get("Sincerity", 0))
	court_skills += float(candidate.skills.get("Courtier", 0))
	court_skills += float(candidate.skills.get("Perform", 0))
	var court_skill_score: float = clampf(court_skills / 4.0, 0.0, 10.0) * 15.0 / 10.0

	var prestige_val: float = (candidate.status + candidate.glory) / 2.0
	var prestige_score: float = clampf(prestige_val, 0.0, 10.0) * 10.0 / 10.0

	var disp: float = champion.disposition_values.get(candidate.character_id, 0.0)
	var disp_score: float = clampf((disp + 100.0) / 200.0 * 10.0, 0.0, 10.0) * 10.0 / 10.0

	var agenda_score: float = 0.0
	var candidate_topics: Array = topic_pool_map.get(candidate.character_id, [])
	for tid: int in agenda_topic_ids:
		if tid in candidate_topics:
			agenda_score += 3.33
	agenda_score = clampf(agenda_score, 0.0, 10.0) * 10.0 / 10.0

	var school_score: float = 0.0
	match candidate.school_type:
		Enums.SchoolType.COURTIER:
			school_score = 10.0
		Enums.SchoolType.SHUGENJA:
			school_score = 6.0
		Enums.SchoolType.BUSHI:
			school_score = 3.0
		_:
			school_score = 5.0
	school_score = school_score * 5.0 / 10.0

	return court_skill_score + prestige_score + disp_score + agenda_score + school_score


static func _apply_yojimbo_pull_in(
	selected_ids: Array,
	all_vassals: Array,
) -> Array:
	var result: Array = selected_ids.duplicate()
	var vassal_map: Dictionary = {}
	for v: L5RCharacterData in all_vassals:
		if CharacterStats.is_dead(v):
			continue
		vassal_map[v.character_id] = v

	for sel_id: int in selected_ids:
		var sel: L5RCharacterData = vassal_map.get(sel_id) as L5RCharacterData
		if sel == null:
			continue
		if sel.school_type != Enums.SchoolType.COURTIER:
			continue
		for v: L5RCharacterData in all_vassals:
			if CharacterStats.is_dead(v):
				continue
			if v.operational_superior_id == sel_id and v.school_type == Enums.SchoolType.BUSHI:
				if v.character_id not in result:
					result.append(v.character_id)
				break

	return result


static func select_personal_invitations(
	emperor: L5RCharacterData,
	archetype: int,
	pool_size: int,
	candidates: Array,
	agenda_topic_ids: Array,
	topic_pool_map: Dictionary,
	already_invited: Array,
) -> Array:
	if candidates.is_empty() or pool_size <= 0:
		return []

	var weights: Dictionary = PERSONAL_INVITATION_WEIGHTS.get(
		archetype, PERSONAL_INVITATION_WEIGHTS[StrategicReview.EmperorArchetype.IRON]
	)

	var scored: Array = []
	for candidate: L5RCharacterData in candidates:
		if CharacterStats.is_dead(candidate):
			continue
		if candidate.character_id in already_invited:
			continue
		if candidate.character_id == emperor.character_id:
			continue

		var disp: float = emperor.disposition_values.get(candidate.character_id, 0.0)
		var disp_score: float
		if archetype == StrategicReview.EmperorArchetype.CUNNING:
			disp_score = _inverse_bell_curve(disp)
		else:
			disp_score = clampf((disp + 100.0) / 200.0 * 10.0, 0.0, 10.0)

		var prestige_val: float = (candidate.status + candidate.glory) / 2.0
		var prestige_score: float = clampf(prestige_val, 0.0, 10.0)

		var crisis_score: float = 0.0
		var candidate_topics: Array = topic_pool_map.get(candidate.character_id, [])
		for tid: int in agenda_topic_ids:
			if tid in candidate_topics:
				crisis_score += 3.33
		crisis_score = clampf(crisis_score, 0.0, 10.0)

		var school_score: float = _score_school_type_for_invitation(candidate.school_type, archetype)

		var total: float = (
			disp_score * weights.get("disposition", 0)
			+ prestige_score * weights.get("prestige", 0)
			+ crisis_score * weights.get("crisis_relevance", 0)
			+ school_score * weights.get("school_type", 0)
		)

		scored.append({"id": candidate.character_id, "score": total})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	var result: Array = []
	for i: int in range(mini(pool_size, scored.size())):
		result.append(int(scored[i]["id"]))
	return result


static func _score_school_type_for_invitation(school_type: int, archetype: int) -> float:
	var is_warlike: bool = archetype == StrategicReview.EmperorArchetype.WARLIKE
	match school_type:
		Enums.SchoolType.COURTIER:
			return 10.0 if not is_warlike else 3.0
		Enums.SchoolType.SHUGENJA:
			return 6.0
		Enums.SchoolType.BUSHI:
			return 3.0 if not is_warlike else 10.0
		Enums.SchoolType.MONK:
			return 4.0
		_:
			return 5.0


# -- Emperor's Peace -----------------------------------------------------------

static func is_action_blocked_by_emperors_peace(
	action_id: String,
	actor_settlement_id: int,
	court: CourtSessionData,
	has_duel_sanction: bool,
) -> bool:
	if court == null:
		return false
	if court.phase != CourtSessionData.CourtPhase.ACTIVE:
		return false
	if actor_settlement_id != court.host_settlement_id:
		return false
	if action_id in COVERT_ACTIONS_PERMITTED:
		return false
	if action_id in EMPERORS_PEACE_EXEMPT and has_duel_sanction:
		return false
	if action_id in HOSTILE_ACTIONS:
		return true
	return false


# -- Emperor's Peace Violation Crime (s57.47 v624) ----------------------------

const PEACE_VIOLATION_EMPEROR_DISP_HIT: int = -15
const PEACE_VIOLATION_FAMILY_DAIMYO_GLORY: float = -1.0


static func record_emperors_peace_violation(
	offender: L5RCharacterData,
	action_id: String,
	court: CourtSessionData,
	ic_day: int,
	next_case_id: Array,
	next_topic_id: Array,
	characters_by_id: Dictionary,
) -> Dictionary:
	var witnesses: Array = []
	for aid: int in court.attendee_ids:
		if aid == offender.character_id:
			continue
		var att: L5RCharacterData = characters_by_id.get(aid) as L5RCharacterData
		if att == null or CharacterStats.is_dead(att):
			continue
		witnesses.append(aid)

	var case_id: int = next_case_id[0]
	next_case_id[0] = case_id + 1

	var record: CrimeRecord = CrimeSystem.create_crime_record(
		case_id,
		Enums.CrimeType.VIOLATION_EMPERORS_PEACE,
		offender.character_id,
		"winter_court_%d" % court.host_settlement_id,
		ic_day,
		-1,
		0,
		witnesses,
	)
	record.legal_status = Enums.LegalStatus.ACCUSED
	record.evidence_total = 100

	var honor_loss: float = CrimeSystem.get_at_act_honor_loss(
		Enums.CrimeType.VIOLATION_EMPERORS_PEACE,
		HonorGlorySystem.get_honor_rank(offender),
	)
	HonorGlorySystem.apply_honor_change(offender, honor_loss)

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1
	var title: String = "%s violated the Emperor's Peace at Winter Court" % offender.character_name
	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id, title,
		TopicData.Tier.TIER_1, TopicData.Category.LEGAL,
		ic_day, 80.0, [],
		offender.clan, offender.family,
		offender.character_id,
		"crime", "violation_emperors_peace",
	)
	topic.slug = "emperors_peace_%d" % case_id
	topic.subject_role = "PERPETRATOR"

	var family_daimyo_glory_applied: float = 0.0
	for cid: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[cid] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.family == offender.family and c.role_position == "Family Daimyo":
			family_daimyo_glory_applied = HonorGlorySystem.apply_glory_change(
				c, PEACE_VIOLATION_FAMILY_DAIMYO_GLORY
			)
			break

	return {
		"crime_record": record,
		"topic": topic,
		"honor_loss": honor_loss,
		"offender_id": offender.character_id,
		"action_id": action_id,
		"case_id": case_id,
		"emperor_disposition_hit": PEACE_VIOLATION_EMPEROR_DISP_HIT,
		"offender_clan": offender.clan,
		"family_daimyo_glory_change": family_daimyo_glory_applied,
	}


# -- Host Prestige & Advantages -----------------------------------------------

static func compute_glory_rewards(
	court: CourtSessionData,
	characters_by_id: Dictionary,
) -> Array:
	var rewards: Array = []

	var host_daimyo_id: int = court.host_lord_id
	if host_daimyo_id >= 0:
		var host_daimyo: L5RCharacterData = characters_by_id.get(host_daimyo_id) as L5RCharacterData
		if host_daimyo != null and not CharacterStats.is_dead(host_daimyo):
			rewards.append({"character_id": host_daimyo_id, "glory_change": GLORY_HOST_FAMILY_DAIMYO})

	var host_champion: L5RCharacterData = _find_clan_champion(court.host_clan, characters_by_id)
	if host_champion != null and not CharacterStats.is_dead(host_champion) and host_champion.character_id != host_daimyo_id:
		rewards.append({"character_id": host_champion.character_id, "glory_change": GLORY_HOST_CLAN_CHAMPION})

	for attendee_id: int in court.attendee_ids:
		if attendee_id == host_daimyo_id:
			continue
		if host_champion != null and attendee_id == host_champion.character_id:
			continue
		var attendee: L5RCharacterData = characters_by_id.get(attendee_id) as L5RCharacterData
		if attendee != null and not CharacterStats.is_dead(attendee) and attendee.clan == court.host_clan:
			rewards.append({"character_id": attendee_id, "glory_change": GLORY_HOST_CLAN_DELEGATE})

	return rewards


static func get_home_ground_bonus(
	character: L5RCharacterData,
	court: CourtSessionData,
) -> int:
	if court == null:
		return 0
	if court.phase != CourtSessionData.CourtPhase.ACTIVE:
		return 0
	if character.clan != court.host_clan:
		return 0
	if character.character_id not in court.attendee_ids:
		return 0
	return HOST_SKILL_BONUS


static func is_home_ground_skill(skill_name: String) -> bool:
	return skill_name in HOST_SKILL_IDS


static func get_agenda_day_allocation() -> Array:
	return AGENDA_TOPIC_DAYS.duplicate()


## Reorders the three Winter Court agenda topics per s55.10 Champion ordering AI.
## The host Champion places the topic they want the most attention on in slot 1
## (45 court days) and buries rivals' crises in slot 3 (25 court days).
##
## Ordering rules (per GDD s55.10 — Tactical Advantage, Agenda Topic Ordering):
## 1. Topics where clan_involved == host_clan → slot 1 (own crises get maximum floor).
## 2. Topics where the host Champion's disposition toward the affected clan's
##    Champion is at Rival or below (< -20) → slot 3 (bury rival's crisis).
## 3. Remaining topics fill the middle slot, ordered by descending momentum.
## If multiple topics compete for the same slot, descending momentum breaks ties.
static func order_agenda_for_host(
	topic_ids: Array,
	active_topics: Array,
	host_clan: String,
	host_champion: L5RCharacterData,
	characters_by_id: Dictionary,
) -> Array:
	if topic_ids.size() <= 1:
		return topic_ids.duplicate()
	# Build a map of topic_id → TopicData for fast lookup.
	var topic_map: Dictionary = {}
	for t: TopicData in active_topics:
		topic_map[t.topic_id] = t
	# Build a map of clan → champion character_id (for disposition check).
	var clan_champion_id: Dictionary = {}
	for cid: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[cid] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.lord_id == -1 and c.status >= 7.0:
			clan_champion_id[c.clan] = c.character_id
	# Score each topic: 2 = own clan, 0 = rival clan, 1 = other.
	var scored: Array = []
	for tid: int in topic_ids:
		var topic: TopicData = topic_map.get(tid) as TopicData
		var momentum: float = topic.momentum if topic != null else 0.0
		var involved_clan: String = topic.clan_involved if topic != null else ""
		var priority: int = 1
		if involved_clan == host_clan:
			priority = 2
		elif host_champion != null and not involved_clan.is_empty():
			var rival_champ_id: int = clan_champion_id.get(involved_clan, -1)
			if rival_champ_id >= 0:
				var disp: int = int(host_champion.disposition_values.get(rival_champ_id, 0))
				if disp < -20:
					priority = 0
		scored.append({"topic_id": tid, "priority": priority, "momentum": momentum})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		return a["momentum"] > b["momentum"]
	)
	var result: Array = []
	for entry: Dictionary in scored:
		result.append(int(entry["topic_id"]))
	return result


# -- Regent Substitution -------------------------------------------------------

static func should_use_regent(
	emperor_id: int,
	characters_by_id: Dictionary,
) -> bool:
	if emperor_id < 0:
		return true
	var emperor: L5RCharacterData = characters_by_id.get(emperor_id) as L5RCharacterData
	if emperor == null:
		return true
	return CharacterStats.is_dead(emperor)


static func find_imperial_chancellor(characters_by_id: Dictionary) -> L5RCharacterData:
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c == null:
			continue
		if CharacterStats.is_dead(c):
			continue
		if c.clan == "Imperial" and c.role_position == "Imperial Chancellor":
			return c
	return null


# -- Topic Generation ---------------------------------------------------------

static func generate_announcement_topic(
	host_daimyo_id: int,
	host_clan: String,
	host_province_id: int,
) -> Dictionary:
	return {
		"topic_type": "winter_court_announced",
		"variant": "host_selected",
		"slug": "winter_court_announced_%s" % host_clan.to_lower(),
		"tier": TopicData.Tier.TIER_3,
		"category": TopicData.Category.POLITICAL,
		"momentum": 40.0,
		"subject_character_id": host_daimyo_id,
		"subject_role": "NEUTRAL",
		"clan_involved": host_clan,
		"provinces_affected": [host_province_id],
		"non_positional": true,
	}


# -- Full Pipeline Orchestration -----------------------------------------------

static func run_winter_court_selection(
	emperor: L5RCharacterData,
	archetype: int,
	characters_by_id: Dictionary,
	provinces: Array,
	settlements: Array,
	active_topics: Array,
	world_state: Dictionary,
) -> Dictionary:
	var is_regent: bool = should_use_regent(emperor.character_id if emperor != null else -1, characters_by_id)

	if is_regent:
		var chancellor: L5RCharacterData = find_imperial_chancellor(characters_by_id)
		if chancellor == null:
			return {"skipped": true, "reason": "no_chancellor"}
		var host: Dictionary = select_host_regent(
			chancellor, characters_by_id, provinces, settlements, active_topics, world_state
		)
		if host.is_empty():
			return {"skipped": true, "reason": "no_suitable_castle"}
		host["is_regent_court"] = true
		host["prestige"] = REGENT_PRESTIGE
		host["no_edicts"] = true
		host["selector_id"] = chancellor.character_id
		return host

	var host: Dictionary = select_host_castle(
		emperor, archetype, characters_by_id, provinces, settlements, active_topics, world_state
	)
	if host.is_empty():
		return {"skipped": true, "reason": "no_suitable_castle"}

	host["is_regent_court"] = false
	host["prestige"] = CourtSystem.PRESTIGE_IMPERIAL
	host["no_edicts"] = false
	host["selector_id"] = emperor.character_id
	return host


static func run_invitation_pipeline(
	host_result: Dictionary,
	emperor: L5RCharacterData,
	archetype: int,
	characters_by_id: Dictionary,
	host_lord_rank: Enums.LordRank,
	agenda_topic_ids: Array,
) -> Dictionary:
	var capacity: Dictionary = get_delegation_capacity(host_lord_rank)
	var per_clan: int = capacity.get("per_clan", 8)
	var personal_pool: int = capacity.get("personal_invitations", 3)

	var host_clan: String = host_result.get("host_clan", "")
	var all_invited: Array = []

	if emperor != null:
		all_invited.append(emperor.character_id)
	var host_daimyo_id: int = host_result.get("host_daimyo_id", -1)
	if host_daimyo_id >= 0 and host_daimyo_id not in all_invited:
		all_invited.append(host_daimyo_id)
	var host_champion_id: int = host_result.get("clan_champion_id", -1)
	if host_champion_id >= 0 and host_champion_id not in all_invited:
		all_invited.append(host_champion_id)

	var topic_pool_map: Dictionary = _build_topic_pool_map(characters_by_id)

	var clan_delegations: Dictionary = {}
	for clan: String in GREAT_CLANS:
		if clan == host_clan:
			continue
		var champion: L5RCharacterData = _find_clan_champion(clan, characters_by_id)
		if champion == null:
			continue
		var vassals: Array = _get_clan_vassals(clan, characters_by_id)
		var delegation: Array = select_clan_delegation(
			champion, vassals, per_clan, agenda_topic_ids, topic_pool_map
		)
		clan_delegations[clan] = delegation
		all_invited.append_array(delegation)
		if champion.character_id not in all_invited:
			all_invited.append(champion.character_id)

	var personal_candidates: Array = []
	if emperor != null:
		for char_id: int in characters_by_id:
			var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
			if c == null or CharacterStats.is_dead(c):
				continue
			if c.character_id in all_invited:
				continue
			if c.character_id in emperor.met_characters:
				personal_candidates.append(c)

	var personal_invites: Array = []
	if not host_result.get("is_regent_court", false) and emperor != null:
		personal_invites = select_personal_invitations(
			emperor, archetype, personal_pool, personal_candidates,
			agenda_topic_ids, topic_pool_map, all_invited
		)
		all_invited.append_array(personal_invites)

	return {
		"all_invited": all_invited,
		"clan_delegations": clan_delegations,
		"personal_invitations": personal_invites,
		"capacity": capacity,
	}


# -- Internal Helpers ----------------------------------------------------------

static func _is_castle_type(settlement: SettlementData) -> bool:
	return settlement.settlement_type in [
		Enums.SettlementType.CASTLE,
		Enums.SettlementType.FAMILY_CASTLE,
		Enums.SettlementType.KEEP,
	]


static func _find_family_daimyo_for_settlement(
	settlement: SettlementData,
	province: ProvinceData,
	characters_by_id: Dictionary,
) -> L5RCharacterData:
	var best: L5RCharacterData = null
	var best_status: float = -1.0
	var target_clan: String = province.clan
	var target_family: String = province.family

	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.clan != target_clan:
			continue
		if target_family != "" and c.family != target_family:
			continue
		if c.status > best_status and c.lord_id == -1:
			best_status = c.status
			best = c

	if best == null:
		for char_id: int in characters_by_id:
			var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
			if c == null or CharacterStats.is_dead(c):
				continue
			if c.clan != target_clan:
				continue
			if c.status > best_status:
				best_status = c.status
				best = c

	return best


static func _find_clan_champion(clan: String, characters_by_id: Dictionary) -> L5RCharacterData:
	var best: L5RCharacterData = null
	var best_status: float = -1.0
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.clan != clan:
			continue
		if c.lord_id == -1 and c.status >= 7.0:
			if c.status > best_status:
				best_status = c.status
				best = c
	return best


static func _get_clan_vassals(clan: String, characters_by_id: Dictionary) -> Array:
	var result: Array = []
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.clan == clan and c.lord_id >= 0:
			result.append(c)
	return result


static func _build_topic_pool_map(characters_by_id: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		result[char_id] = c.topic_pool.duplicate()
	return result


static func _select_host_with_weights(
	selector: L5RCharacterData,
	characters_by_id: Dictionary,
	provinces: Array,
	settlements: Array,
	active_topics: Array,
	world_state: Dictionary,
	weights: Dictionary,
	archetype_override: int,
) -> Dictionary:
	var last_host_clan_years: Dictionary = world_state.get("last_host_clan_years", {})
	var current_ic_year: int = world_state.get("current_ic_year", 0)
	var occupied_provinces: Array = world_state.get("occupied_province_ids", [])
	var capital_settlement_id: int = world_state.get("capital_settlement_id", -1)

	var province_map: Dictionary = {}
	for p: ProvinceData in provinces:
		province_map[p.province_id] = p

	var best_score: float = -999.0
	var best_result: Dictionary = {}

	for settlement: SettlementData in settlements:
		if not _is_castle_type(settlement):
			continue
		if settlement.settlement_id == capital_settlement_id:
			continue
		if settlement.settlement_type == Enums.SettlementType.IMPERIAL_CAPITAL:
			continue

		var province: ProvinceData = province_map.get(settlement.province_id) as ProvinceData
		if province == null:
			continue
		if province.stability < 30.0:
			continue
		if province.province_id in occupied_provinces:
			continue

		var host_daimyo: L5RCharacterData = _find_family_daimyo_for_settlement(
			settlement, province, characters_by_id
		)
		if host_daimyo == null:
			continue

		var clan: String = province.clan
		if clan.is_empty():
			continue

		var clan_champion: L5RCharacterData = _find_clan_champion(clan, characters_by_id)

		var disp_score: float = _score_disposition(selector, clan_champion, archetype_override)
		var recency_score: float = _score_clan_recency(clan, last_host_clan_years, current_ic_year)
		var stability_score: float = _score_province_stability(province)
		var crisis_score: float = _score_crisis_relevance(province, active_topics, archetype_override)
		var prestige_score: float = _score_family_prestige(host_daimyo)

		var total: float = (
			disp_score * weights.get("disposition", 0)
			+ recency_score * weights.get("clan_recency", 0)
			+ stability_score * weights.get("province_stability", 0)
			+ crisis_score * weights.get("crisis_relevance", 0)
			+ prestige_score * weights.get("family_prestige", 0)
		)

		if total > best_score:
			best_score = total
			best_result = {
				"settlement_id": settlement.settlement_id,
				"province_id": province.province_id,
				"host_daimyo_id": host_daimyo.character_id,
				"host_clan": clan,
				"score": total,
				"clan_champion_id": clan_champion.character_id if clan_champion != null else -1,
			}

	return best_result
