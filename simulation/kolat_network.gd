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

# Sect → special_data field holding that Sect's network record (s54.7h).
const SECT_NETWORK_FIELD: Dictionary = {
	"kolat_silk": "silk_network_record",
	"kolat_coin": "coin_network_record",
	"kolat_jade": "jade_asset_network",
	"kolat_lotus": "lotus_network_record",
	"kolat_chrysanthemum": "chrysanthemum_network_record",
	"kolat_steel": "steel_garrison_record",
}


# -- Generic record access ----------------------------------------------------

static func network_field_for_sect(sect: String) -> String:
	return String(SECT_NETWORK_FIELD.get(sect, ""))


static func get_network(master: L5RCharacterData, sect: String) -> Dictionary:
	var field: String = network_field_for_sect(sect)
	if field == "":
		return {}
	return master.special_data.get(field, {})


static func _store_network(master: L5RCharacterData, sect: String, record: Dictionary) -> void:
	var field: String = network_field_for_sect(sect)
	if field != "":
		master.special_data[field] = record


## Capacity count per s54.7d: active + dark + suspended; burned excluded. Works on
## the detailed dict schemas (entry["operative_status"]/["agent_status"]) and the
## universal triple form (entry[2]).
static func agent_count(master: L5RCharacterData, sect: String) -> int:
	var record: Dictionary = get_network(master, sect)
	var n: int = 0
	for code_name: String in record:
		if _status_of(record[code_name]) in CAP_COUNTING_STATUS:
			n += 1
	return n


static func at_capacity(master: L5RCharacterData, sect: String) -> bool:
	return agent_count(master, sect) >= MAX_AGENTS


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


static func find_code_name_by_npc_id(master: L5RCharacterData, sect: String, npc_id: int) -> String:
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
	if at_capacity(master, "kolat_silk"):
		return false
	var record: Dictionary = get_network(master, "kolat_silk")
	record[code_name] = {
		"npc_id": npc_id, "position": position, "operative_status": "active",
		"last_report_ic_day": ic_day, "last_delivery_ic_day": -1,
		"current_delivery_target": "", "tiger_priority_topics": [],
		"reposition_in_transit": false,
	}
	_store_network(master, "kolat_silk", record)
	return true


static func register_coin_operative(
	master: L5RCharacterData, code_name: String, npc_id: int,
	cover_role: String, province_base: String, ic_day: int, skim_rate: float = 0.25
) -> bool:
	if at_capacity(master, "kolat_coin"):
		return false
	var record: Dictionary = get_network(master, "kolat_coin")
	record[code_name] = {
		"npc_id": npc_id, "cover_role": cover_role, "province_base": province_base,
		"operative_status": "active", "current_assignment": null,
		"last_contact_ic_day": ic_day, "assignment_target_province_id": null,
		"assignment_method": null, "assignment_koku_cost_per_season": 0,
		"local_reserve_koku": 0, "skim_rate": skim_rate,
		"expected_yield_per_season": 0.0,
	}
	_store_network(master, "kolat_coin", record)
	return true


static func register_jade_asset(
	master: L5RCharacterData, code_name: String, npc_id: int,
	institution: String, province_coverage: String
) -> bool:
	# Jade has a tighter cap of 3 (s54.7h).
	var record: Dictionary = get_network(master, "kolat_jade")
	if record.size() >= 3:
		return false
	record[code_name] = {
		"npc_id": npc_id, "institution": institution,
		"province_coverage": province_coverage, "last_tip_ic_day": -1,
		"last_report_ic_day": null, "asset_status": "active",
	}
	_store_network(master, "kolat_jade", record)
	return true


static func register_lotus_operative(
	master: L5RCharacterData, code_name: String, npc_id: int,
	dead_drop_settlement_id: String, confirmation_drop_settlement_id: String
) -> bool:
	if at_capacity(master, "kolat_lotus"):
		return false
	var record: Dictionary = get_network(master, "kolat_lotus")
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
	_store_network(master, "kolat_lotus", record)
	return true


static func register_chrysanthemum_agent(
	master: L5RCharacterData, code_name: String, npc_id: int, threshold: int, ic_day: int
) -> bool:
	if at_capacity(master, "kolat_chrysanthemum"):
		return false
	var record: Dictionary = get_network(master, "kolat_chrysanthemum")
	# Universal triple schema (s54.7h chrysanthemum reference) + npc_id for lookup.
	record[code_name] = {
		"npc_id": npc_id, "last_contact": ic_day, "threshold": threshold,
		"agent_status": "active",
	}
	_store_network(master, "kolat_chrysanthemum", record)
	return true


static func register_steel_ronin(
	master: L5RCharacterData, code_name: String, npc_id: int, role: String, ic_day: int
) -> bool:
	if at_capacity(master, "kolat_steel"):
		return false
	var record: Dictionary = get_network(master, "kolat_steel")
	record[code_name] = {
		"npc_id": npc_id, "role": role, "posting_ic_day": ic_day,
		"last_paid_ic_day": ic_day, "seasons_unpaid": 0,
		"morale_status": "loyal", "cover_identity": null,
	}
	_store_network(master, "kolat_steel", record)
	return true


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
