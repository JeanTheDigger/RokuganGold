extends GutTest


var _char_a: L5RCharacterData
var _char_b: L5RCharacterData
var _char_c: L5RCharacterData


func before_each() -> void:
	_char_a = L5RCharacterData.new()
	_char_a.character_id = 1
	_char_a.character_name = "Akodo Toturi"
	_char_a.clan = "Lion"
	_char_a.family = "Akodo"
	_char_a.status = 5.0
	_char_a.met_characters = []
	_char_a.knowledge_pool = []
	_char_a.known_contacts_by_clan = {}
	_char_a.disposition_values = {}

	_char_b = L5RCharacterData.new()
	_char_b.character_id = 2
	_char_b.character_name = "Bayushi Kachiko"
	_char_b.clan = "Scorpion"
	_char_b.family = "Bayushi"
	_char_b.status = 6.0

	_char_c = L5RCharacterData.new()
	_char_c.character_id = 3
	_char_c.character_name = "Hida Kisada"
	_char_c.clan = "Crab"
	_char_c.family = "Hida"
	_char_c.status = 7.5


# -- Knowledge Entry Creation -------------------------------------------------

func test_make_entry_sets_fields() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"observed_action",
		{"action_id": "CHARM"},
		4,
	)
	assert_eq(entry.source, Enums.KnowledgeSource.INTELLIGENCE)
	assert_eq(entry.entry_type, "observed_action")
	assert_eq(entry.confidence, Enums.KnowledgeConfidence.FRESH)
	assert_eq(entry.season_acquired, 4)
	assert_eq(entry.data["action_id"], "CHARM")


func test_make_entry_always_fresh() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.DIRECT_OBSERVATION, "test", {}, 1
	)
	assert_eq(entry.confidence, Enums.KnowledgeConfidence.FRESH)


# -- Adding Knowledge ----------------------------------------------------------

func test_add_knowledge_appends_to_pool() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 1
	)
	InformationSystem.add_knowledge(_char_a, entry)
	assert_eq(_char_a.knowledge_pool.size(), 1)


func test_add_knowledge_multiple_entries() -> void:
	for i: int in range(3):
		InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
			Enums.KnowledgeSource.INTELLIGENCE, "test", {"i": i}, 1
		))
	assert_eq(_char_a.knowledge_pool.size(), 3)


# -- Contact Discovery --------------------------------------------------------

func test_add_contact_updates_met_characters() -> void:
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	assert_true(2 in _char_a.met_characters)


func test_add_contact_updates_known_contacts_by_clan() -> void:
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	assert_true(_char_a.known_contacts_by_clan.has("Scorpion"))
	assert_true(2 in _char_a.known_contacts_by_clan["Scorpion"])


func test_add_contact_no_duplicate() -> void:
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	assert_eq(_char_a.met_characters.size(), 1)
	assert_eq(_char_a.known_contacts_by_clan["Scorpion"].size(), 1)


func test_add_contact_multiple_clans() -> void:
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	InformationSystem.add_contact(_char_a, 3, "Crab")
	assert_eq(_char_a.known_contacts_by_clan.keys().size(), 2)


# -- Probe Visibility ----------------------------------------------------------

func test_probe_discovers_target_actions() -> void:
	var action_log: Array[Dictionary] = [
		{"character_id": 2, "action_id": "CHARM", "target_npc_id": 3, "ic_day": 5, "success": true},
		{"character_id": 2, "action_id": "GOSSIP", "target_npc_id": 1, "ic_day": 6, "success": true},
	]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
		_char_a, 2, action_log, 1, 3
	)
	assert_eq(discovered.size(), 2)
	assert_eq(_char_a.knowledge_pool.size(), 2)


func test_probe_quality_limits_entries() -> void:
	var action_log: Array[Dictionary] = [
		{"character_id": 2, "action_id": "CHARM", "target_npc_id": 3, "ic_day": 5, "success": true},
		{"character_id": 2, "action_id": "GOSSIP", "target_npc_id": 1, "ic_day": 6, "success": true},
		{"character_id": 2, "action_id": "TRAIN", "target_npc_id": -1, "ic_day": 7, "success": true},
	]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
		_char_a, 2, action_log, 1, 1
	)
	assert_eq(discovered.size(), 1)


func test_probe_returns_most_recent_first() -> void:
	var action_log: Array[Dictionary] = [
		{"character_id": 2, "action_id": "CHARM", "target_npc_id": 3, "ic_day": 5, "success": true},
		{"character_id": 2, "action_id": "GOSSIP", "target_npc_id": 1, "ic_day": 6, "success": true},
	]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
		_char_a, 2, action_log, 1, 1
	)
	assert_eq(discovered[0].data["action_id"], "GOSSIP")


func test_probe_ignores_other_characters() -> void:
	var action_log: Array[Dictionary] = [
		{"character_id": 2, "action_id": "CHARM", "target_npc_id": 3, "ic_day": 5, "success": true},
		{"character_id": 3, "action_id": "TRAIN", "target_npc_id": -1, "ic_day": 6, "success": true},
	]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
		_char_a, 2, action_log, 1, 5
	)
	assert_eq(discovered.size(), 1)


func test_probe_empty_log_returns_nothing() -> void:
	var action_log: Array[Dictionary] = []
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
		_char_a, 2, action_log, 1, 3
	)
	assert_eq(discovered.size(), 0)


func test_probe_entries_are_intelligence_source() -> void:
	var action_log: Array[Dictionary] = [
		{"character_id": 2, "action_id": "CHARM", "target_npc_id": 3, "ic_day": 5, "success": true},
	]
	InformationSystem.process_probe_result(_char_a, 2, action_log, 1, 3)
	assert_eq(_char_a.knowledge_pool[0].source, Enums.KnowledgeSource.INTELLIGENCE)


# -- Observe Court Attendees ---------------------------------------------------

func test_observe_court_discovers_unknown() -> void:
	var attendees: Array[L5RCharacterData] = [_char_b, _char_c]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_observe_court(
		_char_a, attendees, 2, 1
	)
	assert_eq(discovered.size(), 2)
	assert_true(2 in _char_a.met_characters)
	assert_true(3 in _char_a.met_characters)


func test_observe_court_skips_known() -> void:
	_char_a.met_characters = [2]
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	var attendees: Array[L5RCharacterData] = [_char_b, _char_c]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_observe_court(
		_char_a, attendees, 3, 1
	)
	assert_eq(discovered.size(), 1)
	assert_eq(discovered[0].data["character_id"], 3)


func test_observe_court_skips_self() -> void:
	var attendees: Array[L5RCharacterData] = [_char_a, _char_b]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_observe_court(
		_char_a, attendees, 3, 1
	)
	assert_eq(discovered.size(), 1)
	assert_eq(discovered[0].data["character_id"], 2)


func test_observe_court_quality_caps_at_3() -> void:
	var c4 := L5RCharacterData.new()
	c4.character_id = 4
	c4.character_name = "Doji Hotaru"
	c4.clan = "Crane"
	c4.family = "Doji"
	c4.status = 6.0
	var attendees: Array[L5RCharacterData] = [_char_b, _char_c, c4]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_observe_court(
		_char_a, attendees, 5, 1
	)
	assert_eq(discovered.size(), 3)


func test_observe_court_records_clan_info() -> void:
	var attendees: Array[L5RCharacterData] = [_char_b]
	var discovered: Array[KnowledgeEntry] = InformationSystem.process_observe_court(
		_char_a, attendees, 1, 1
	)
	assert_eq(discovered[0].data["clan"], "Scorpion")
	assert_eq(discovered[0].data["family"], "Bayushi")


func test_observe_court_direct_observation_source() -> void:
	var attendees: Array[L5RCharacterData] = [_char_b]
	InformationSystem.process_observe_court(_char_a, attendees, 1, 1)
	assert_eq(_char_a.knowledge_pool[0].source, Enums.KnowledgeSource.DIRECT_OBSERVATION)


# -- Introduction --------------------------------------------------------------

func test_introduction_adds_contact() -> void:
	InformationSystem.process_introduction(_char_a, _char_b, false, 1)
	assert_true(2 in _char_a.met_characters)


func test_introduction_sets_starting_disposition_3() -> void:
	InformationSystem.process_introduction(_char_a, _char_b, false, 1)
	assert_eq(_char_a.disposition_values[2], 3)


func test_introduction_kuge_sets_disposition_2() -> void:
	InformationSystem.process_introduction(_char_a, _char_c, true, 1)
	assert_eq(_char_a.disposition_values[3], 2)


func test_introduction_does_not_overwrite_existing_disposition() -> void:
	_char_a.disposition_values[2] = 30
	InformationSystem.process_introduction(_char_a, _char_b, false, 1)
	assert_eq(_char_a.disposition_values[2], 30)


func test_introduction_creates_knowledge_entry() -> void:
	InformationSystem.process_introduction(_char_a, _char_b, false, 1)
	assert_eq(_char_a.knowledge_pool.size(), 1)
	assert_eq(_char_a.knowledge_pool[0].entry_type, "introduction")


# -- Confidence Decay ----------------------------------------------------------

func test_decay_fresh_stays_fresh_same_season() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 4
	))
	var decayed: int = InformationSystem.decay_confidence(_char_a, 4)
	assert_eq(decayed, 0)
	assert_eq(_char_a.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.FRESH)


func test_decay_to_recent_after_one_season() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 1
	))
	var decayed: int = InformationSystem.decay_confidence(_char_a, 2)
	assert_eq(decayed, 1)
	assert_eq(_char_a.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.RECENT)


func test_decay_to_stale_after_three_seasons() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 1
	))
	var decayed: int = InformationSystem.decay_confidence(_char_a, 4)
	assert_eq(decayed, 1)
	assert_eq(_char_a.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.STALE)


func test_decay_skips_disposition_entries() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "disposition", {}, 1
	))
	var decayed: int = InformationSystem.decay_confidence(_char_a, 10)
	assert_eq(decayed, 0)
	assert_eq(_char_a.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.FRESH)


func test_decay_multiple_entries() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test_a", {}, 1
	))
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test_b", {}, 3
	))
	var decayed: int = InformationSystem.decay_confidence(_char_a, 4)
	assert_eq(decayed, 2)
	assert_eq(_char_a.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.STALE)
	assert_eq(_char_a.knowledge_pool[1].confidence, Enums.KnowledgeConfidence.RECENT)


# -- Information Transfer (GDD s55.6) -----------------------------------------

func test_transfer_copies_matching_entries() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "province_intel",
		{"target_province_id": 10, "stability": 50}, 1
	))
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "unrelated",
		{"target_province_id": 20, "stability": 80}, 1
	))
	var objective: Dictionary = {"target_province_id": 10}
	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2
	)
	assert_eq(transferred.size(), 1)
	assert_eq(_char_b.knowledge_pool.size(), 1)
	assert_eq(_char_b.knowledge_pool[0].data["target_province_id"], 10)


func test_transfer_sets_fresh_confidence() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test",
		{"target_province_id": 10}, 1
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char_a, entry)
	var objective: Dictionary = {"target_province_id": 10}
	InformationSystem.transfer_objective_knowledge(_char_a, _char_b, objective, 5)
	assert_eq(_char_b.knowledge_pool[0].confidence, Enums.KnowledgeConfidence.FRESH)


func test_transfer_copies_clan_contacts() -> void:
	InformationSystem.add_contact(_char_a, 5, "Crab")
	InformationSystem.add_contact(_char_a, 6, "Crab")
	var objective: Dictionary = {"target_clan": "Crab"}
	InformationSystem.transfer_objective_knowledge(_char_a, _char_b, objective, 1)
	assert_true(5 in _char_b.met_characters)
	assert_true(6 in _char_b.met_characters)


func test_transfer_npc_targeted_entries() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 5, "action_id": "CHARM"}, 1
	))
	var objective: Dictionary = {"target_npc_id": 5}
	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 1
	)
	assert_eq(transferred.size(), 1)


# -- Queries -------------------------------------------------------------------

func test_get_known_contacts_for_clan() -> void:
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	InformationSystem.add_contact(_char_a, 5, "Scorpion")
	var contacts: Array[int] = InformationSystem.get_known_contacts_for_clan(_char_a, "Scorpion")
	assert_eq(contacts.size(), 2)
	assert_true(2 in contacts)
	assert_true(5 in contacts)


func test_get_known_contacts_empty_clan() -> void:
	var contacts: Array[int] = InformationSystem.get_known_contacts_for_clan(_char_a, "Phoenix")
	assert_eq(contacts.size(), 0)


func test_has_fresh_intel_on_target() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2, "action_id": "CHARM"}, 1
	))
	assert_true(InformationSystem.has_fresh_intel_on(_char_a, 2))


func test_has_fresh_intel_false_when_stale() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2, "action_id": "CHARM"}, 1
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char_a, entry)
	assert_false(InformationSystem.has_fresh_intel_on(_char_a, 2))


func test_has_fresh_intel_false_for_unknown() -> void:
	assert_false(InformationSystem.has_fresh_intel_on(_char_a, 99))


func test_get_stale_entries() -> void:
	var fresh: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 4
	)
	var stale: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "test", {}, 1
	)
	stale.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char_a, fresh)
	InformationSystem.add_knowledge(_char_a, stale)
	var stale_entries: Array[KnowledgeEntry] = InformationSystem.get_stale_entries(_char_a)
	assert_eq(stale_entries.size(), 1)


func test_count_by_confidence() -> void:
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "a", {}, 1
	))
	InformationSystem.add_knowledge(_char_a, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "b", {}, 1
	))
	var stale: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "c", {}, 1
	)
	stale.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char_a, stale)
	var counts: Dictionary = InformationSystem.count_by_confidence(_char_a)
	assert_eq(counts[Enums.KnowledgeConfidence.FRESH], 2)
	assert_eq(counts[Enums.KnowledgeConfidence.STALE], 1)


# -- Transfer Province Status & Crisis Data (s55.6) ---------------------------

func test_transfer_province_status() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 10
	ps.stability = 60.0
	ps.garrison_pu = 5
	ps.rice_stockpile = 20.0
	ps.last_report_ic_day = 3

	var objective: Dictionary = {"target_province_id": 10}
	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	var province_entries: Array[KnowledgeEntry] = []
	for e: KnowledgeEntry in transferred:
		if e.entry_type == "province_status":
			province_entries.append(e)
	assert_eq(province_entries.size(), 1)
	assert_eq(province_entries[0].data["stability"], 60.0)
	assert_eq(province_entries[0].data["garrison_pu"], 5)
	assert_eq(province_entries[0].confidence, Enums.KnowledgeConfidence.FRESH)


func test_transfer_crisis_data() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 10
	ps.stability = 40.0
	ps.active_crisis_id = 3
	ps.crisis_type = "shadowlands_incursion"

	var objective: Dictionary = {"target_province_id": 10}
	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	var crisis_entries: Array[KnowledgeEntry] = []
	for e: KnowledgeEntry in transferred:
		if e.entry_type == "crisis_data":
			crisis_entries.append(e)
	assert_eq(crisis_entries.size(), 1)
	assert_eq(crisis_entries[0].data["crisis_id"], 3)
	assert_eq(crisis_entries[0].data["crisis_type"], "shadowlands_incursion")


func test_transfer_no_crisis_when_none_active() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 10
	ps.stability = 80.0
	ps.active_crisis_id = -1

	var objective: Dictionary = {"target_province_id": 10}
	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	for e: KnowledgeEntry in transferred:
		assert_ne(e.entry_type, "crisis_data")


func test_transfer_province_wrong_id_ignored() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 20
	ps.stability = 60.0

	var objective: Dictionary = {"target_province_id": 10}
	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	for e: KnowledgeEntry in transferred:
		assert_ne(e.entry_type, "province_status")
