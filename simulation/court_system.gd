class_name CourtSystem
## Court Session lifecycle per GDD s15.1 and s15.2.
## Manages creation, daily advancement, attendance, and closure of courts.


const WINTER_COURT_DURATION: int = 120
const CLAN_COURT_MIN_DURATION: int = 7
const CLAN_COURT_MAX_DURATION: int = 14
const PROVINCIAL_COURT_MIN_DURATION: int = 3
const PROVINCIAL_COURT_MAX_DURATION: int = 5
const PEACE_COURT_MIN_DURATION: int = 7
const PEACE_COURT_MAX_DURATION: int = 21

const PRESTIGE_IMPERIAL: int = 3
const PRESTIGE_CLAN: int = 2
const PRESTIGE_PROVINCIAL: int = 1

const CRISIS_MOMENTUM_THRESHOLD: Dictionary = {
	Enums.LordRank.VILLAGE_HEADMAN: 15,
	Enums.LordRank.CITY_DAIMYO: 20,
	Enums.LordRank.PROVINCIAL_DAIMYO: 25,
	Enums.LordRank.FAMILY_DAIMYO: 35,
	Enums.LordRank.CLAN_CHAMPION: 50,
	Enums.LordRank.IMPERIAL: 60,
}

const MAX_AGENDA_TOPICS: int = 3
const MAX_AGENDA_TOPICS_WINTER_COURT: int = 3


# -- Factory -------------------------------------------------------------------

static func create_court(
	court_id: int,
	court_type: CourtSessionData.CourtType,
	host_lord_id: int,
	host_settlement_id: int,
	host_clan: String,
	start_ic_day: int,
	duration_ticks: int = -1,
	emperor_present: bool = false,
) -> CourtSessionData:
	var court := CourtSessionData.new()
	court.court_id = court_id
	court.court_type = court_type
	court.host_lord_id = host_lord_id
	court.host_settlement_id = host_settlement_id
	court.host_clan = host_clan
	court.start_ic_day = start_ic_day
	court.phase = CourtSessionData.CourtPhase.SCHEDULED
	court.emperor_present = emperor_present

	if duration_ticks > 0:
		court.duration_ticks = duration_ticks
	else:
		court.duration_ticks = get_default_duration(court_type)

	court.prestige = _get_prestige(court_type)
	return court


static func get_default_duration(court_type: CourtSessionData.CourtType) -> int:
	match court_type:
		CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
			return WINTER_COURT_DURATION
		CourtSessionData.CourtType.CLAN_CHAMPION_COURT:
			return CLAN_COURT_MAX_DURATION
		CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT:
			return PROVINCIAL_COURT_MAX_DURATION
		CourtSessionData.CourtType.PEACE_COURT:
			return PEACE_COURT_MAX_DURATION
		_:
			return PROVINCIAL_COURT_MAX_DURATION


static func _get_prestige(court_type: CourtSessionData.CourtType) -> int:
	match court_type:
		CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
			return PRESTIGE_IMPERIAL
		CourtSessionData.CourtType.CLAN_CHAMPION_COURT:
			return PRESTIGE_CLAN
		CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT:
			return PRESTIGE_PROVINCIAL
		CourtSessionData.CourtType.PEACE_COURT:
			return PRESTIGE_CLAN
		_:
			return PRESTIGE_PROVINCIAL


# -- Lifecycle -----------------------------------------------------------------

static func open_court(court: CourtSessionData, ic_day: int) -> void:
	if court.phase != CourtSessionData.CourtPhase.SCHEDULED:
		return
	court.phase = CourtSessionData.CourtPhase.ACTIVE
	court.start_ic_day = ic_day
	court.elapsed_ticks = 0


static func advance_court_day(court: CourtSessionData) -> Dictionary:
	if court.phase != CourtSessionData.CourtPhase.ACTIVE:
		return {"advanced": false, "reason": "not_active"}
	court.elapsed_ticks += 1
	var should_close: bool = court.elapsed_ticks >= court.duration_ticks
	return {
		"advanced": true,
		"elapsed": court.elapsed_ticks,
		"duration": court.duration_ticks,
		"should_close": should_close,
	}


static func close_court(court: CourtSessionData) -> Dictionary:
	if court.phase != CourtSessionData.CourtPhase.ACTIVE:
		return {"closed": false, "reason": "not_active"}
	court.phase = CourtSessionData.CourtPhase.CLOSED
	return {
		"closed": true,
		"court_id": court.court_id,
		"court_type": court.court_type,
		"host_clan": court.host_clan,
		"elapsed_ticks": court.elapsed_ticks,
		"commitments_count": court.commitments_made.size(),
		"wars_resolved": court.wars_resolved_during.duplicate(),
		"emperor_present": court.emperor_present,
	}


static func is_active(court: CourtSessionData) -> bool:
	return court.phase == CourtSessionData.CourtPhase.ACTIVE


static func is_expired(court: CourtSessionData) -> bool:
	return court.phase == CourtSessionData.CourtPhase.ACTIVE and court.elapsed_ticks >= court.duration_ticks


# -- Attendance ----------------------------------------------------------------

static func add_attendee(court: CourtSessionData, character_id: int) -> bool:
	if character_id in court.attendee_ids:
		return false
	court.attendee_ids.append(character_id)
	return true


static func remove_attendee(court: CourtSessionData, character_id: int) -> bool:
	var idx: int = court.attendee_ids.find(character_id)
	if idx < 0:
		return false
	court.attendee_ids.remove_at(idx)
	return true


static func is_attending(court: CourtSessionData, character_id: int) -> bool:
	return character_id in court.attendee_ids


static func get_attendee_count(court: CourtSessionData) -> int:
	return court.attendee_ids.size()


# -- Agenda Topics -------------------------------------------------------------

static func select_agenda_topics(
	topics: Array[TopicData],
	court_type: CourtSessionData.CourtType,
	crisis_trigger_topic_id: int = -1,
) -> Array[int]:
	var max_topics: int = MAX_AGENDA_TOPICS
	if court_type == CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
		max_topics = MAX_AGENDA_TOPICS_WINTER_COURT

	var candidates: Array[TopicData] = []
	for t: TopicData in topics:
		if t.resolved:
			continue
		candidates.append(t)

	candidates.sort_custom(func(a: TopicData, b: TopicData) -> bool:
		return a.momentum > b.momentum
	)

	var result: Array[int] = []

	if crisis_trigger_topic_id >= 0:
		result.append(crisis_trigger_topic_id)

	for t: TopicData in candidates:
		if t.topic_id in result:
			continue
		result.append(t.topic_id)
		if result.size() >= max_topics:
			break

	return result


static func set_agenda(court: CourtSessionData, topic_ids: Array[int]) -> void:
	court.agenda_topic_ids = topic_ids.duplicate()


# -- Crisis-Triggered Court Evaluation -----------------------------------------

static func should_call_court(
	lord_rank: Enums.LordRank,
	topics: Array[TopicData],
	active_courts_at_settlement: Array[CourtSessionData],
) -> Dictionary:
	for c: CourtSessionData in active_courts_at_settlement:
		if c.phase != CourtSessionData.CourtPhase.CLOSED:
			return {}

	var threshold: int = CRISIS_MOMENTUM_THRESHOLD.get(lord_rank, 30)

	for t: TopicData in topics:
		if t.resolved:
			continue
		if t.momentum >= threshold:
			return {
				"should_call": true,
				"trigger_topic_id": t.topic_id,
				"trigger_momentum": t.momentum,
				"threshold": threshold,
			}
	return {}


# -- Commitment Recording -----------------------------------------------------

static func record_commitment(
	court: CourtSessionData,
	character_id: int,
	commitment_type: String,
	description: String,
	witnesses: Array[int] = [],
) -> Dictionary:
	if court.phase != CourtSessionData.CourtPhase.ACTIVE:
		return {"recorded": false, "reason": "court_not_active"}

	var entry: Dictionary = {
		"character_id": character_id,
		"commitment_type": commitment_type,
		"description": description,
		"witnesses": witnesses.duplicate() if not witnesses.is_empty() else court.attendee_ids.duplicate(),
		"ic_day": court.start_ic_day + court.elapsed_ticks,
	}
	court.commitments_made.append(entry)
	return {"recorded": true, "entry": entry}


static func record_war_resolution(court: CourtSessionData, war_id: int) -> void:
	if war_id not in court.wars_resolved_during:
		court.wars_resolved_during.append(war_id)


# -- Context Helpers -----------------------------------------------------------

static func get_active_court_at_settlement(
	courts: Array[CourtSessionData],
	settlement_id: int,
) -> CourtSessionData:
	for c: CourtSessionData in courts:
		if c.phase == CourtSessionData.CourtPhase.ACTIVE and c.host_settlement_id == settlement_id:
			return c
	return null


static func get_active_courts(courts: Array[CourtSessionData]) -> Array[CourtSessionData]:
	var result: Array[CourtSessionData] = []
	for c: CourtSessionData in courts:
		if c.phase == CourtSessionData.CourtPhase.ACTIVE:
			result.append(c)
	return result


static func get_upcoming_courts(
	courts: Array[CourtSessionData],
	current_ic_day: int,
) -> Array[CourtSessionData]:
	var result: Array[CourtSessionData] = []
	for c: CourtSessionData in courts:
		if c.phase == CourtSessionData.CourtPhase.SCHEDULED and c.start_ic_day > current_ic_day:
			result.append(c)
	return result


static func to_context_dict(court: CourtSessionData) -> Dictionary:
	return {
		"court_id": court.court_id,
		"settlement_id": court.host_settlement_id,
		"host_clan": court.host_clan,
		"prestige": court.prestige,
		"court_type": court.court_type,
		"topics": court.agenda_topic_ids.duplicate(),
		"emperor_present": court.emperor_present,
		"attendee_count": court.attendee_ids.size(),
	}


static func get_character_context_flag(
	courts: Array[CourtSessionData],
	character_id: int,
) -> bool:
	for c: CourtSessionData in courts:
		if c.phase == CourtSessionData.CourtPhase.ACTIVE and character_id in c.attendee_ids:
			return true
	return false


# -- Topic Generation on Court Close -------------------------------------------

static func generate_court_close_topic(court: CourtSessionData) -> Dictionary:
	if court.commitments_made.is_empty() and court.wars_resolved_during.is_empty():
		return {
			"topic_type": "court_session",
			"variant": "no_resolution",
			"slug": "court_%d_no_resolution" % court.court_id,
			"tier": TopicData.Tier.TIER_4,
			"category": TopicData.Category.POLITICAL,
			"momentum": 5.0,
			"clan_involved": court.host_clan,
		}

	var tier: TopicData.Tier = TopicData.Tier.TIER_4
	var momentum: float = 11.0
	if court.court_type == CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
		tier = TopicData.Tier.TIER_2
		momentum = 50.0
	elif court.court_type == CourtSessionData.CourtType.CLAN_CHAMPION_COURT:
		tier = TopicData.Tier.TIER_3
		momentum = 25.0

	if not court.wars_resolved_during.is_empty():
		tier = TopicData.Tier.TIER_2
		momentum = maxf(momentum, 40.0)

	return {
		"topic_type": "court_session",
		"variant": "concluded",
		"slug": "court_%d_concluded" % court.court_id,
		"tier": tier,
		"category": TopicData.Category.POLITICAL,
		"momentum": momentum,
		"clan_involved": court.host_clan,
		"commitments_count": court.commitments_made.size(),
		"wars_resolved": court.wars_resolved_during.size(),
	}
