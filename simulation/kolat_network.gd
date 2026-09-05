class_name KolatNetwork
## Kolat agent-network record data layer (GDD s54.7h schemas, s54.7d universal
## rules). Pure simulation class — no Node inheritance.
##
## Every Master keeps a per-Sect network record in their special_data under a
## Sect-specific field name (s54.7h). The detailed per-Sect schemas in s54.7h are
## authoritative; s54.7d's "universal triple" paragraph is the older minimal form
## and is internally inconsistent (it lists Silk/Lotus as both using and not using
## a record). The GDD is read-only, so this follows the s54.7h field definitions.
##
## World-start population is NOT done here: only Silk contacts and Dream sleepers
## have LOCKED world-start counts (s54.7a), and the operative-selection criteria
## for the other Sects are not fully specified. Networks therefore populate during
## play through recruitment (RECRUIT_KOLAT_AGENT / CONDITION_SLEEPER). These helpers
## create, query, and maintain the records once entries exist.

# -- Universal capacity + silence rules (s54.7d) -------------------------------
const MAX_AGENTS: int = 6                 # active + dark + suspended (burned excluded)
const MAX_ACTIVE_KOLAT_OBJECTIVES: int = 3
const SILENCE_THRESHOLD_CITY: int = 30    # IC days
const SILENCE_THRESHOLD_REMOTE: int = 60  # IC days

# agent_status values that count toward the capacity cap (s54.7d).
const CAP_COUNTING_STATUS: Array[String] = ["active", "dark", "suspended"]

# -- Compromise threat classification (s54.7d MANAGE_COMPROMISED_AGENT) --------
# The GDD locks the four agent_status values and their meanings (s54.7h) and the
# unconditional Stage-1 go-dark, but leaves the Stage-2 threat classification only
# qualitatively described (s54.7b: "two axes — how much the investigator has, and
# how capable they are"). Owner-approved numeric rule (2026-09-04, PROVISIONAL):
# base tier from the legal status of the most-advanced crime record naming the
# agent, +1 tier for an Emerald/Imperial investigator, +1 tier for a CAPITAL
# crime, capped at DEEP. Tier → outcome: LOW = stay dark and lie low (recovers to
# active when the case resolves); MODERATE = suspended (awaiting Tiger); DEEP =
# burned (routed Tiger → Lotus for silencing; entry purged after one season).
const THREAT_LOW: String = "low"
const THREAT_MODERATE: String = "moderate"
const THREAT_DEEP: String = "deep"

# agent_status values that mean "silence is expected / agent gone" — the seasonal
# silence-detection pass skips these (s54.7h: dark = "silence expected").
const SILENCE_EXEMPT_STATUS: Array[String] = ["dark", "suspended", "burned"]


## True when a crime record's legal status actively names its subject (an open
## investigation, accusation, or standing guilt/fugitive state) — the s54.7d
## "investigation, arrest, or accusation" trigger. Cleared/closed states
## (NONE/CLEAR/PARDONED/ACQUITTED) do not name the agent.
static func is_active_naming_status(legal_status: int) -> bool:
	return legal_status in [
		Enums.LegalStatus.SUSPECTED, Enums.LegalStatus.UNDER_INVESTIGATION,
		Enums.LegalStatus.ACCUSED, Enums.LegalStatus.DECREED_GUILTY,
		Enums.LegalStatus.FUGITIVE,
	]


## Base threat tier (0 low / 1 moderate / 2 deep) from a naming legal status, or
## -1 for a non-naming status. Owner-approved mapping (s54.7d, PROVISIONAL).
static func compromise_base_tier(legal_status: int) -> int:
	match legal_status:
		Enums.LegalStatus.SUSPECTED, Enums.LegalStatus.UNDER_INVESTIGATION:
			return 0
		Enums.LegalStatus.ACCUSED:
			return 1
		Enums.LegalStatus.DECREED_GUILTY, Enums.LegalStatus.FUGITIVE:
			return 2
	return -1


## Classify a compromise given the most-advanced naming legal status and the two
## escalators. Returns THREAT_LOW / THREAT_MODERATE / THREAT_DEEP, or "" when the
## status does not name the agent. Owner-approved rule (s54.7d, PROVISIONAL).
static func classify_compromise(
	legal_status: int, is_emerald_or_imperial: bool, is_capital: bool
) -> String:
	var tier: int = compromise_base_tier(legal_status)
	if tier < 0:
		return ""
	if is_emerald_or_imperial:
		tier += 1
	if is_capital:
		tier += 1
	tier = clampi(tier, 0, 2)
	return [THREAT_LOW, THREAT_MODERATE, THREAT_DEEP][tier]


## Write an entry's lifecycle status into whichever status key its Sect schema
## uses (agent_status / operative_status / asset_status), defaulting to
## agent_status. Stamps burned_ic_day when burning so the seasonal purge can
## retain a burned entry for one season before deleting it (s54.7h).
static func set_entry_status(entry: Dictionary, status: String, ic_day: int) -> void:
	var key: String = "agent_status"
	if entry.has("operative_status"):
		key = "operative_status"
	elif entry.has("asset_status"):
		key = "asset_status"
	elif not entry.has("agent_status"):
		key = "agent_status"
	entry[key] = status
	if status == "burned":
		entry["burned_ic_day"] = ic_day


## True when a burned entry has survived at least one seasonal tick since it was
## burned and may now be deleted (s54.7h: "retained for 1 season then deleted").
## Because the purge runs only at the Seasonal Tick, a burned_ic_day strictly
## before the current tick's day means the entry was burned in a prior season.
static func is_burned_purgeable(entry: Variant, ic_day: int) -> bool:
	if not entry is Dictionary:
		return false
	var d: Dictionary = entry
	if status_of(d) != "burned":
		return false
	var burned_day: int = int(d.get("burned_ic_day", -1))
	return burned_day >= 0 and burned_day < ic_day


## Count of the Master's own registered agents currently carrying an active Kolat
## objective (s54.7d ≤3 sub-cap). Reads the live objectives_map so it reflects
## assignments made this tick. Forward-wired: the live agent-directive channel
## (Tiger SEND_KOLAT_DIRECTIVE executor) is deferred, so no over-assignment path
## exists to gate yet — this makes the cap enforceable once it lands.
static func active_kolat_objective_count(
	master: L5RCharacterData, objectives_map: Dictionary
) -> int:
	var n: int = 0
	var record: Dictionary = get_network(master, master.kolat_sect)
	for code_name: Variant in record:
		var e: Variant = record[code_name]
		if not e is Dictionary:
			continue
		var nid: int = int((e as Dictionary).get("npc_id", -1))
		if nid < 0:
			continue
		var objs: Dictionary = objectives_map.get(nid, {})
		if not (objs.get("kolat", {}) as Dictionary).is_empty():
			n += 1
	return n

# Sect → special_data field holding that Sect's network record (s54.7h).
# kolat_sect is an Enums.KolatSect on the character sheet (the codebase truth),
# not the Enums.KolatSect.SILK string the GDD prose uses — these helpers key by the enum.
const SECT_NETWORK_FIELD: Dictionary = {
	Enums.KolatSect.SILK: "silk_network_record",
	Enums.KolatSect.COIN: "coin_network_record",
	Enums.KolatSect.JADE: "jade_asset_network",
	Enums.KolatSect.LOTUS: "lotus_network_record",
	Enums.KolatSect.CHRYSANTHEMUM: "chrysanthemum_network_record",
	Enums.KolatSect.STEEL: "steel_garrison_record",
}


# -- Generic record access ----------------------------------------------------

static func network_field_for_sect(sect: Enums.KolatSect) -> String:
	return String(SECT_NETWORK_FIELD.get(sect, ""))


static func get_network(master: L5RCharacterData, sect: Enums.KolatSect) -> Dictionary:
	var field: String = network_field_for_sect(sect)
	if field == "":
		return {}
	return master.special_data.get(field, {})


static func _store_network(master: L5RCharacterData, sect: Enums.KolatSect, record: Dictionary) -> void:
	var field: String = network_field_for_sect(sect)
	if field != "":
		master.special_data[field] = record


## Capacity count per s54.7d: active + dark + suspended; burned excluded. Works on
## the detailed dict schemas (entry["operative_status"]/["agent_status"]) and the
## universal triple form (entry[2]).
static func agent_count(master: L5RCharacterData, sect: Enums.KolatSect) -> int:
	var record: Dictionary = get_network(master, sect)
	var n: int = 0
	for code_name: String in record:
		if _status_of(record[code_name]) in CAP_COUNTING_STATUS:
			n += 1
	return n


static func at_capacity(master: L5RCharacterData, sect: Enums.KolatSect) -> bool:
	return agent_count(master, sect) >= MAX_AGENTS


## npc_ids of every field agent in the Master's own Sect network record (s54.7h).
## Used by the Stage-5 damage-assessment recall sweep (s54.7) when a Master is
## eliminated — the agents who had contact are cut off. Sects with no agent-network
## record (Dream/Tiger/Cloud/Roc) return an empty list.
static func collect_field_agent_ids(master: L5RCharacterData) -> Array[int]:
	var ids: Array[int] = []
	var record: Dictionary = get_network(master, master.kolat_sect)
	for code_name: Variant in record:
		var e: Variant = record[code_name]
		if e is Dictionary:
			var nid: int = int((e as Dictionary).get("npc_id", -1))
			if nid >= 0:
				ids.append(nid)
	return ids


## Public accessor for an entry's capacity/lifecycle status (s54.7d).
static func status_of(entry: Variant) -> String:
	return _status_of(entry)


static func _status_of(entry: Variant) -> String:
	# Detailed schemas use "operative_status" (Silk/Coin/Lotus) or "agent_status"
	# (Chrysanthemum/universal) or "asset_status" (Jade); steel uses "morale_status"
	# for morale, not capacity — its presence flag is the entry itself.
	if entry is Dictionary:
		var d: Dictionary = entry
		if d.has("operative_status"):
			return String(d["operative_status"])
		if d.has("agent_status"):
			return String(d["agent_status"])
		if d.has("asset_status"):
			return String(d["asset_status"])
		return "active"
	if entry is Array and (entry as Array).size() >= 3:
		return String((entry as Array)[2])  # universal triple [last_contact, threshold, agent_status]
	return "active"


static func find_code_name_by_npc_id(master: L5RCharacterData, sect: Enums.KolatSect, npc_id: int) -> String:
	var record: Dictionary = get_network(master, sect)
	for code_name: String in record:
		var entry: Variant = record[code_name]
		if entry is Dictionary and int((entry as Dictionary).get("npc_id", -1)) == npc_id:
			return code_name
	return ""


# -- Registration helpers (per-Sect schemas, s54.7h) --------------------------
# Each respects the capacity cap (s54.7d): registration is refused at MAX_AGENTS.

static func register_silk_operative(
	master: L5RCharacterData, code_name: String, npc_id: int, position: String, ic_day: int
) -> bool:
	if at_capacity(master, Enums.KolatSect.SILK):
		return false
	var record: Dictionary = get_network(master, Enums.KolatSect.SILK)
	record[code_name] = {
		"npc_id": npc_id, "position": position, "operative_status": "active",
		"last_report_ic_day": ic_day, "last_delivery_ic_day": -1,
		"current_delivery_target": "", "tiger_priority_topics": [],
		"reposition_in_transit": false,
	}
	_store_network(master, Enums.KolatSect.SILK, record)
	return true


static func register_coin_operative(
	master: L5RCharacterData, code_name: String, npc_id: int,
	cover_role: String, province_base: String, ic_day: int, skim_rate: float = 0.25
) -> bool:
	if at_capacity(master, Enums.KolatSect.COIN):
		return false
	var record: Dictionary = get_network(master, Enums.KolatSect.COIN)
	record[code_name] = {
		"npc_id": npc_id, "cover_role": cover_role, "province_base": province_base,
		"operative_status": "active", "current_assignment": null,
		"last_contact_ic_day": ic_day, "assignment_target_province_id": null,
		"assignment_method": null, "assignment_koku_cost_per_season": 0,
		"local_reserve_koku": 0, "skim_rate": skim_rate,
		"expected_yield_per_season": 0.0,
	}
	_store_network(master, Enums.KolatSect.COIN, record)
	return true


static func register_jade_asset(
	master: L5RCharacterData, code_name: String, npc_id: int,
	institution: String, province_coverage: String
) -> bool:
	# Jade has a tighter cap of 3 (s54.7h).
	var record: Dictionary = get_network(master, Enums.KolatSect.JADE)
	if record.size() >= 3:
		return false
	record[code_name] = {
		"npc_id": npc_id, "institution": institution,
		"province_coverage": province_coverage, "last_tip_ic_day": -1,
		"last_report_ic_day": null, "asset_status": "active",
	}
	_store_network(master, Enums.KolatSect.JADE, record)
	return true


static func register_lotus_operative(
	master: L5RCharacterData, code_name: String, npc_id: int,
	dead_drop_settlement_id: String, confirmation_drop_settlement_id: String
) -> bool:
	if at_capacity(master, Enums.KolatSect.LOTUS):
		return false
	var record: Dictionary = get_network(master, Enums.KolatSect.LOTUS)
	record[code_name] = {
		"dead_drop_settlement_id": dead_drop_settlement_id,
		"dead_drop_compromised": false,
		"confirmation_drop_settlement_id": confirmation_drop_settlement_id,
		"confirmation_drop_compromised": false,
		"operative_status": "idle", "last_drop_check_ic_day": -1,
		"assignment_target_npc_id": null, "assignment_dispatched_ic_day": null,
		"assignment_in_transit_compromised": false, "assignment_method": null,
		"abort_count": 0, "npc_id": npc_id,
	}
	_store_network(master, Enums.KolatSect.LOTUS, record)
	return true


static func register_chrysanthemum_agent(
	master: L5RCharacterData, code_name: String, npc_id: int, threshold: int, ic_day: int
) -> bool:
	if at_capacity(master, Enums.KolatSect.CHRYSANTHEMUM):
		return false
	var record: Dictionary = get_network(master, Enums.KolatSect.CHRYSANTHEMUM)
	# Universal triple schema (s54.7h chrysanthemum reference) + npc_id for lookup.
	record[code_name] = {
		"npc_id": npc_id, "last_contact": ic_day, "threshold": threshold,
		"agent_status": "active",
	}
	_store_network(master, Enums.KolatSect.CHRYSANTHEMUM, record)
	return true


static func register_steel_ronin(
	master: L5RCharacterData, code_name: String, npc_id: int, role: String, ic_day: int
) -> bool:
	if at_capacity(master, Enums.KolatSect.STEEL):
		return false
	var record: Dictionary = get_network(master, Enums.KolatSect.STEEL)
	record[code_name] = {
		"npc_id": npc_id, "role": role, "posting_ic_day": ic_day,
		"last_paid_ic_day": ic_day, "seasons_unpaid": 0,
		"morale_status": "loyal", "cover_identity": null,
	}
	_store_network(master, Enums.KolatSect.STEEL, record)
	return true


## Generic recruitment registration (APPROACH_FOR_RECRUITMENT, s54.7c/d). Adds a
## newly-recruited conscious agent to the recruiting Master's Sect network record
## with sensible defaults, dispatching by the Master's kolat_sect. Sects with no
## agent-network record (Dream sleepers use the registry; Roc/Tiger/Cloud keep no
## such record) return true without creating an entry — the recruit's kolat_sect
## is set by the caller regardless. Returns false only when the record is at the
## capacity cap (s54.7d).
static func register_recruit(master: L5RCharacterData, npc_id: int, position: String, ic_day: int) -> bool:
	var sect: Enums.KolatSect = master.kolat_sect
	var code_name: String = "agent_%d" % npc_id
	match sect:
		Enums.KolatSect.SILK:
			return register_silk_operative(master, code_name, npc_id, position, ic_day)
		Enums.KolatSect.COIN:
			return register_coin_operative(master, code_name, npc_id, "recruit", position, ic_day)
		Enums.KolatSect.JADE:
			return register_jade_asset(master, code_name, npc_id, "", position)
		Enums.KolatSect.LOTUS:
			return register_lotus_operative(master, code_name, npc_id, "", "")
		Enums.KolatSect.CHRYSANTHEMUM:
			return register_chrysanthemum_agent(master, code_name, npc_id, SILENCE_THRESHOLD_CITY, ic_day)
		Enums.KolatSect.STEEL:
			return register_steel_ronin(master, code_name, npc_id, "garnison", ic_day)
		_:
			return true  # Dream/Roc/Tiger/Cloud keep no agent-network record


## ROTATE_DEAD_DROP support (s54.7c). Finds the first Lotus operative whose dead
## drop or confirmation drop is flagged compromised, moves it to new_settlement_id,
## clears the compromised flag, and marks any in-flight package undeliverable.
## Returns the rotated operative's code name, or "" if none was compromised.
static func rotate_dead_drop(master: L5RCharacterData, new_settlement_id: String) -> String:
	var record: Dictionary = get_network(master, Enums.KolatSect.LOTUS)
	for code_name: String in record:
		var entry: Variant = record[code_name]
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry
		if e.get("dead_drop_compromised", false):
			e["dead_drop_settlement_id"] = new_settlement_id
			e["dead_drop_compromised"] = false
			e["assignment_in_transit_compromised"] = true
			_store_network(master, Enums.KolatSect.LOTUS, record)
			return code_name
		if e.get("confirmation_drop_compromised", false):
			e["confirmation_drop_settlement_id"] = new_settlement_id
			e["confirmation_drop_compromised"] = false
			_store_network(master, Enums.KolatSect.LOTUS, record)
			return code_name
	return ""


# -- Hidden Temple (s54.7h) ---------------------------------------------------

## Returns the settlement flagged is_hidden_temple, or null if none exists.
static func find_hidden_temple(settlements: Array) -> SettlementData:
	for s: Variant in settlements:
		if s is SettlementData and (s as SettlementData).is_hidden_temple:
			return s
	return null


static func is_at_hidden_temple(character: L5RCharacterData, temple: SettlementData) -> bool:
	return temple != null and character.physical_location == str(temple.settlement_id)


# -- Sleeper registry (Dream, s54.7h) -----------------------------------------

static func register_sleeper(
	dream_master: L5RCharacterData, sleeper_id: String, npc_id: int,
	trigger_phrase: String, command_summary: String, ic_day: int, tiger_requested: bool
) -> void:
	var registry: Dictionary = dream_master.special_data.get("dream_sleeper_registry", {})
	registry[sleeper_id] = {
		"npc_id": npc_id, "conditioning_stability": 100.0,
		"last_contact_ic_day": ic_day, "sleeper_status": "dormant",
		"trigger_phrase": trigger_phrase, "sleeper_command_summary": command_summary,
		"activation_ic_day": null, "tiger_requested": tiger_requested,
	}
	dream_master.special_data["dream_sleeper_registry"] = registry


# -- Silence detection (s54.7d) -----------------------------------------------

## True when an agent has been silent past its threshold. last_contact / threshold
## read from the detailed schema (last_contact_ic_day / last_report_ic_day) or the
## universal triple.
static func silence_overdue(entry: Variant, ic_day: int) -> bool:
	var last_contact: int = -1
	var threshold: int = SILENCE_THRESHOLD_CITY
	if entry is Dictionary:
		var d: Dictionary = entry
		last_contact = int(d.get("last_contact",
			d.get("last_contact_ic_day", d.get("last_report_ic_day", -1))))
		threshold = int(d.get("threshold", SILENCE_THRESHOLD_CITY))
	elif entry is Array and (entry as Array).size() >= 2:
		last_contact = int((entry as Array)[0])
		threshold = int((entry as Array)[1])
	if last_contact < 0:
		return false
	return (ic_day - last_contact) > threshold


# -- Cloud archive (s54.7h cloud_archive schema) ------------------------------
# Keyed by archive_id ("arc_<topic_id>"), one entry per archived topic. The core
# fields match s54.7h exactly; category/clan/family/slug are retained as
# reconstruction extras so RESURRECT_TOPIC can faithfully rebuild the topic.

static func archive_id_for(topic_id: int) -> String:
	return "arc_%d" % topic_id


static func archive_topic(master: L5RCharacterData, topic: TopicData, ic_day: int, leverage_value: int) -> String:
	var archive: Dictionary = master.special_data.get("cloud_archive", {})
	var aid: String = archive_id_for(topic.topic_id)
	archive[aid] = {
		"topic_id": topic.topic_id,
		"tier": int(topic.tier),
		"parties_named": ([topic.subject_character_id] if topic.subject_character_id >= 0 else []),
		"content_summary": topic.title,
		"source": "direct_observation",
		"original_momentum": int(topic.momentum),
		"ic_day_archived": ic_day,
		"leverage_value": clampi(leverage_value, 0, 3),
		# Reconstruction extras (beyond the s54.7h core, used by RESURRECT_TOPIC):
		"category": int(topic.category),
		"clan_involved": topic.clan_involved,
		"family_involved": topic.family_involved,
		"slug": topic.slug,
	}
	master.special_data["cloud_archive"] = archive
	return aid


## Returns the archive entry for the original topic_id, or {} if not archived.
static func get_archived_topic(master: L5RCharacterData, topic_id: int) -> Dictionary:
	var archive: Dictionary = master.special_data.get("cloud_archive", {})
	return archive.get(archive_id_for(topic_id), {})
