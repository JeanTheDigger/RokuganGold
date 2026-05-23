class_name InformationSystem
## Manages NPC knowledge per GDD s55.12 and s20.
## Five sources: Direct Observation, Daily Conversation, Letters,
## Intelligence Actions, Public Knowledge.
## Confidence: FRESH (this season), RECENT (1-2 seasons), STALE (3+ seasons).
## Disposition values never go stale.


const STALE_THRESHOLD_SEASONS: int = 3
const RECENT_THRESHOLD_SEASONS: int = 1


# -- Knowledge Entry Creation --------------------------------------------------

static func make_entry(
	source: Enums.KnowledgeSource,
	entry_type: String,
	data: Dictionary,
	season: int,
) -> KnowledgeEntry:
	var entry := KnowledgeEntry.new()
	entry.source = source
	entry.entry_type = entry_type
	entry.data = data
	entry.confidence = Enums.KnowledgeConfidence.FRESH
	entry.season_acquired = season
	return entry


# -- Adding Knowledge ----------------------------------------------------------

static func add_knowledge(
	character: L5RCharacterData,
	entry: KnowledgeEntry,
) -> void:
	character.knowledge_pool.append(entry)


const _DEDUP_ENTRY_TYPES: Array[String] = [
	"personality_insight", "disposition_toward",
	"topic_attitude", "topic_position", "court_objective",
	"priority_objective",
]


static func update_intelligence_knowledge(
	character: L5RCharacterData,
	entry: KnowledgeEntry,
) -> void:
	if entry.entry_type not in _DEDUP_ENTRY_TYPES:
		character.knowledge_pool.append(entry)
		return
	var target_id: int = entry.data.get("target_character_id", -1)
	for i: int in range(character.knowledge_pool.size() - 1, -1, -1):
		var existing: KnowledgeEntry = character.knowledge_pool[i]
		if existing.entry_type == entry.entry_type \
				and existing.data.get("target_character_id", -1) == target_id:
			character.knowledge_pool.remove_at(i)
			break
	character.knowledge_pool.append(entry)


static func add_contact(
	character: L5RCharacterData,
	contact_id: int,
	clan_id: String,
	contact: L5RCharacterData = null,
	clan_baselines: Dictionary = {},
	family_baselines: Dictionary = {},
) -> void:
	if contact_id in character.met_characters:
		return
	character.met_characters.append(contact_id)
	if not character.known_contacts_by_clan.has(clan_id):
		character.known_contacts_by_clan[clan_id] = []
	if contact_id not in character.known_contacts_by_clan[clan_id]:
		character.known_contacts_by_clan[clan_id].append(contact_id)

	# Seed starting personal disposition from clan + family baselines (s12.2b)
	# on first meeting. No-op if the caller didn't supply baselines or the
	# contact char itself.
	if contact != null and (not clan_baselines.is_empty() or not family_baselines.is_empty()):
		CollectiveDisposition.seed_first_meeting(
			character, contact, clan_baselines, family_baselines
		)


# -- Probe Visibility (GDD s55.4.7) -------------------------------------------

static func process_probe_result(
	prober: L5RCharacterData,
	target_id: int,
	action_log: Array,
	current_season: int,
	quality: int,
) -> Array:
	var discovered: Array = []
	var target_actions: Array = _get_target_actions(target_id, action_log)

	var max_entries: int = clampi(quality, 1, 5)
	var count: int = 0
	for i: int in range(target_actions.size() - 1, -1, -1):
		if count >= max_entries:
			break
		var action: Dictionary = target_actions[i]
		var entry: KnowledgeEntry = make_entry(
			Enums.KnowledgeSource.INTELLIGENCE,
			"observed_action",
			{
				"target_character_id": target_id,
				"action_id": action.get("action_id", ""),
				"target_npc_id": action.get("target_npc_id", -1),
				"ic_day": action.get("ic_day", 0),
				"success": action.get("success", false),
			},
			current_season,
		)
		add_knowledge(prober, entry)
		discovered.append(entry)
		count += 1

	return discovered


static func _get_target_actions(target_id: int, action_log: Array) -> Array:
	var actions: Array = []
	for entry: Dictionary in action_log:
		if entry.get("character_id", -1) == target_id:
			actions.append(entry)
	return actions


# -- Contact Discovery (GDD s55.7) --------------------------------------------

static func process_observe_court(
	observer: L5RCharacterData,
	attendees: Array,
	quality: int,
	current_season: int,
	clan_baselines: Dictionary = {},
	family_baselines: Dictionary = {},
) -> Array:
	var discovered: Array = []
	var unknown: Array = []
	for a: L5RCharacterData in attendees:
		if CharacterStats.is_dead(a):
			continue
		if a.character_id != observer.character_id and a.character_id not in observer.met_characters:
			unknown.append(a)

	var max_discover: int = clampi(quality, 1, 3)
	for i: int in range(mini(max_discover, unknown.size())):
		var target: L5RCharacterData = unknown[i]
		add_contact(observer, target.character_id, target.clan, target, clan_baselines, family_baselines)
		var entry: KnowledgeEntry = make_entry(
			Enums.KnowledgeSource.DIRECT_OBSERVATION,
			"contact_discovered",
			{
				"character_id": target.character_id,
				"character_name": target.character_name,
				"clan": target.clan,
				"family": target.family,
				"status": target.status,
			},
			current_season,
		)
		add_knowledge(observer, entry)
		discovered.append(entry)

	return discovered


static func process_introduction(
	recipient: L5RCharacterData,
	introduced: L5RCharacterData,
	is_kuge: bool,
	current_season: int,
	clan_baselines: Dictionary = {},
	family_baselines: Dictionary = {},
) -> KnowledgeEntry:
	# add_contact may seed disposition from collective baselines (s12.2b).
	# The introduction bonus then layers on top — both should compose, not
	# clobber. A first-time introduction with active baselines puts the
	# recipient at (clan*0.25 + family*0.5) + introduction_bonus.
	var was_first_meeting: bool = introduced.character_id not in recipient.met_characters
	add_contact(
		recipient, introduced.character_id, introduced.clan,
		introduced, clan_baselines, family_baselines,
	)
	var starting_disp: int = 2 if is_kuge else 3
	if was_first_meeting:
		var current: int = recipient.disposition_values.get(introduced.character_id, 0)
		recipient.disposition_values[introduced.character_id] = clampi(
			current + starting_disp, -100, 100
		)

	var entry: KnowledgeEntry = make_entry(
		Enums.KnowledgeSource.DIRECT_OBSERVATION,
		"introduction",
		{
			"character_id": introduced.character_id,
			"character_name": introduced.character_name,
			"clan": introduced.clan,
			"is_kuge": is_kuge,
			"starting_disposition": starting_disp,
		},
		current_season,
	)
	add_knowledge(recipient, entry)
	return entry


# -- Information Transfer (GDD s55.6) -----------------------------------------

static func transfer_objective_knowledge(
	assigner: L5RCharacterData,
	recipient: L5RCharacterData,
	objective: Dictionary,
	current_season: int,
	province_statuses: Array = [],
	chars_by_id: Dictionary = {},
	clan_baselines: Dictionary = {},
	family_baselines: Dictionary = {},
) -> Array:
	var transferred: Array = []
	var target_tags: Array = _extract_target_tags(objective)

	for entry: KnowledgeEntry in assigner.knowledge_pool:
		if _entry_matches_tags(entry, target_tags):
			var copy := KnowledgeEntry.new()
			copy.source = entry.source
			copy.entry_type = entry.entry_type
			copy.data = entry.data.duplicate(true)
			copy.confidence = Enums.KnowledgeConfidence.FRESH
			copy.season_acquired = current_season
			add_knowledge(recipient, copy)
			transferred.append(copy)

	var target_clan: String = objective.get("target_clan", "")
	if target_clan != "" and assigner.known_contacts_by_clan.has(target_clan):
		for contact_id: int in assigner.known_contacts_by_clan[target_clan]:
			var contact: L5RCharacterData = chars_by_id.get(contact_id)
			add_contact(
				recipient, contact_id, target_clan,
				contact, clan_baselines, family_baselines,
			)

	var target_province_id: int = objective.get("target_province_id", -1)
	if target_province_id >= 0:
		for ps: Variant in province_statuses:
			if not ps is NPCDataStructures.ProvinceStatus:
				continue
			var status: NPCDataStructures.ProvinceStatus = ps
			if status.province_id != target_province_id:
				continue
			var province_entry := _make_province_status_entry(status, current_season)
			add_knowledge(recipient, province_entry)
			transferred.append(province_entry)
			if status.active_crisis_id >= 0:
				var crisis_entry := _make_crisis_entry(status, current_season)
				add_knowledge(recipient, crisis_entry)
				transferred.append(crisis_entry)
			break

	return transferred


static func _make_province_status_entry(
	status: NPCDataStructures.ProvinceStatus,
	current_season: int,
) -> KnowledgeEntry:
	return make_entry(
		Enums.KnowledgeSource.DIRECT_OBSERVATION,
		"province_status",
		{
			"target_province_id": status.province_id,
			"stability": status.stability,
			"garrison_pu": status.garrison_pu,
			"rice_stockpile": status.rice_stockpile,
			"last_report_ic_day": status.last_report_ic_day,
		},
		current_season,
	)


static func _make_crisis_entry(
	status: NPCDataStructures.ProvinceStatus,
	current_season: int,
) -> KnowledgeEntry:
	return make_entry(
		Enums.KnowledgeSource.DIRECT_OBSERVATION,
		"crisis_data",
		{
			"target_province_id": status.province_id,
			"crisis_id": status.active_crisis_id,
			"crisis_type": status.crisis_type,
		},
		current_season,
	)


static func _extract_target_tags(objective: Dictionary) -> Array:
	var tags: Array = []
	if objective.has("target_province_id"):
		tags.append("province:" + str(objective["target_province_id"]))
	if objective.has("target_clan"):
		tags.append("clan:" + objective["target_clan"])
	if objective.has("target_npc_id"):
		tags.append("npc:" + str(objective["target_npc_id"]))
	return tags


static func _entry_matches_tags(entry: KnowledgeEntry, tags: Array) -> bool:
	var data: Dictionary = entry.data
	for tag: String in tags:
		var parts: PackedStringArray = tag.split(":")
		if parts.size() != 2:
			continue
		var key: String = parts[0]
		var value: String = parts[1]
		match key:
			"province":
				if str(data.get("target_province_id", "")) == value:
					return true
			"clan":
				if data.get("clan", "") == value:
					return true
			"npc":
				if str(data.get("target_character_id", "")) == value:
					return true
				if str(data.get("character_id", "")) == value:
					return true
	return false


# -- Confidence Decay (GDD s55.12) --------------------------------------------

static func decay_confidence(
	character: L5RCharacterData,
	current_season: int,
) -> int:
	var decayed_count: int = 0
	for entry: KnowledgeEntry in character.knowledge_pool:
		if entry.entry_type == "disposition":
			continue

		var age: int = current_season - entry.season_acquired
		var old_conf: int = entry.confidence
		var new_conf: int = _compute_confidence(age)

		if new_conf != old_conf:
			entry.confidence = new_conf
			decayed_count += 1

	return decayed_count


static func _compute_confidence(seasons_old: int) -> int:
	if seasons_old >= STALE_THRESHOLD_SEASONS:
		return Enums.KnowledgeConfidence.STALE
	if seasons_old >= RECENT_THRESHOLD_SEASONS:
		return Enums.KnowledgeConfidence.RECENT
	return Enums.KnowledgeConfidence.FRESH


# -- Queries -------------------------------------------------------------------

static func get_known_contacts_for_clan(
	character: L5RCharacterData,
	clan_id: String,
) -> Array:
	var contacts: Array = character.known_contacts_by_clan.get(clan_id, [])
	var result: Array = []
	for c: int in contacts:
		result.append(c)
	return result


static func has_fresh_intel_on(
	character: L5RCharacterData,
	target_id: int,
) -> bool:
	for entry: KnowledgeEntry in character.knowledge_pool:
		var char_id: int = entry.data.get("target_character_id", entry.data.get("character_id", -1))
		if char_id == target_id and entry.confidence == Enums.KnowledgeConfidence.FRESH:
			return true
	return false


static func get_stale_entries(character: L5RCharacterData) -> Array:
	var stale: Array = []
	for entry: KnowledgeEntry in character.knowledge_pool:
		if entry.confidence == Enums.KnowledgeConfidence.STALE:
			stale.append(entry)
	return stale


static func count_by_confidence(
	character: L5RCharacterData,
) -> Dictionary:
	var counts: Dictionary = {
		Enums.KnowledgeConfidence.FRESH: 0,
		Enums.KnowledgeConfidence.RECENT: 0,
		Enums.KnowledgeConfidence.STALE: 0,
	}
	for entry: KnowledgeEntry in character.knowledge_pool:
		counts[entry.confidence] = counts.get(entry.confidence, 0) + 1
	return counts


static func get_best_confidence_on_target(
	character: L5RCharacterData,
	target_id: int,
) -> int:
	var best: int = 999
	for entry: KnowledgeEntry in character.knowledge_pool:
		var char_id: int = entry.data.get("target_character_id", entry.data.get("character_id", -1))
		if char_id == target_id and entry.confidence < best:
			best = entry.confidence
	if best == 999:
		return -1
	return best


static func record_location_observation(
	observer: L5RCharacterData,
	observed_id: int,
	settlement_id: String,
	current_season: int,
) -> void:
	for entry: KnowledgeEntry in observer.knowledge_pool:
		if entry.entry_type == "location" and entry.data.get("character_id", -1) == observed_id:
			entry.data["settlement_id"] = settlement_id
			entry.confidence = Enums.KnowledgeConfidence.FRESH
			entry.season_acquired = current_season
			return
	var new_entry := KnowledgeEntry.new()
	new_entry.source = Enums.KnowledgeSource.DIRECT_OBSERVATION
	new_entry.entry_type = "location"
	new_entry.data = {"character_id": observed_id, "settlement_id": settlement_id}
	new_entry.confidence = Enums.KnowledgeConfidence.FRESH
	new_entry.season_acquired = current_season
	observer.knowledge_pool.append(new_entry)
