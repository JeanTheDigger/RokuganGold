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


# -- Probe Visibility (s15.4) --------------------------------------------------
# process_probe_result() is now a stub returning empty array.
# Action log scanning was an invented mechanic (GDD s15.4 Probe only reveals
# topic positions and court objectives via _process_intelligence_info_writebacks).

func test_probe_returns_empty_array() -> void:
	var action_log: Array = [
		{"character_id": 2, "action_id": "CHARM", "target_npc_id": 3, "ic_day": 5, "success": true},
	]
	var discovered: Array = InformationSystem.process_probe_result(
		_char_a, 2, action_log, 1, 3
	)
	assert_eq(discovered.size(), 0)
	assert_eq(_char_a.knowledge_pool.size(), 0)


# -- Observe Court Attendees ---------------------------------------------------

func test_observe_court_discovers_unknown() -> void:
	var attendees: Array = [_char_b, _char_c]
	var discovered: Array = InformationSystem.process_observe_court(
		_char_a, attendees, 2, 1
	)
	assert_eq(discovered.size(), 2)
	assert_true(2 in _char_a.met_characters)
	assert_true(3 in _char_a.met_characters)


func test_observe_court_skips_known() -> void:
	_char_a.met_characters = [2]
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	var attendees: Array = [_char_b, _char_c]
	var discovered: Array = InformationSystem.process_observe_court(
		_char_a, attendees, 3, 1
	)
	assert_eq(discovered.size(), 1)
	assert_eq(discovered[0].data["character_id"], 3)


func test_observe_court_skips_self() -> void:
	var attendees: Array = [_char_a, _char_b]
	var discovered: Array = InformationSystem.process_observe_court(
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
	var attendees: Array = [_char_b, _char_c, c4]
	var discovered: Array = InformationSystem.process_observe_court(
		_char_a, attendees, 5, 1
	)
	assert_eq(discovered.size(), 3)


func test_observe_court_records_clan_info() -> void:
	var attendees: Array = [_char_b]
	var discovered: Array = InformationSystem.process_observe_court(
		_char_a, attendees, 1, 1
	)
	assert_eq(discovered[0].data["clan"], "Scorpion")
	assert_eq(discovered[0].data["family"], "Bayushi")


func test_observe_court_direct_observation_source() -> void:
	var attendees: Array = [_char_b]
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
	_char_a.met_characters.append(2)
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
	var transferred: Array = InformationSystem.transfer_objective_knowledge(
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
	var transferred: Array = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 1
	)
	assert_eq(transferred.size(), 1)


# -- Queries -------------------------------------------------------------------

func test_get_known_contacts_for_clan() -> void:
	InformationSystem.add_contact(_char_a, 2, "Scorpion")
	InformationSystem.add_contact(_char_a, 5, "Scorpion")
	var contacts: Array = InformationSystem.get_known_contacts_for_clan(_char_a, "Scorpion")
	assert_eq(contacts.size(), 2)
	assert_true(2 in contacts)
	assert_true(5 in contacts)


func test_get_known_contacts_empty_clan() -> void:
	var contacts: Array = InformationSystem.get_known_contacts_for_clan(_char_a, "Phoenix")
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
	var stale_entries: Array = InformationSystem.get_stale_entries(_char_a)
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
	var transferred: Array = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	var province_entries: Array = []
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
	var transferred: Array = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	var crisis_entries: Array = []
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
	var transferred: Array = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	for e: KnowledgeEntry in transferred:
		assert_ne(e.entry_type, "crisis_data")


func test_transfer_province_wrong_id_ignored() -> void:
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 20
	ps.stability = 60.0

	var objective: Dictionary = {"target_province_id": 10}
	var transferred: Array = InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 2, [ps]
	)
	for e: KnowledgeEntry in transferred:
		assert_ne(e.entry_type, "province_status")
	pass_test("No province_status entry transferred for mismatched province ID")


# -- Collective Disposition Seed Wiring (s12.2b) -----------------------------

func test_add_contact_skips_seed_when_no_baselines_provided() -> void:
	# Existing 3-arg form: no seed, disposition_values stays empty.
	InformationSystem.add_contact(_char_a, _char_b.character_id, _char_b.clan)
	assert_false(_char_a.disposition_values.has(_char_b.character_id))


func test_add_contact_seeds_disposition_when_contact_and_baselines_provided() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	# Lion (Akodo) ↔ Scorpion (Bayushi):
	# Clan Lion-Scorpion = -15 → -15 * 0.25 = -3.75
	# Family Akodo-Bayushi = 0 (unlisted) → 0
	# Seed = round(-3.75) = -4.
	InformationSystem.add_contact(
		_char_a, _char_b.character_id, _char_b.clan,
		_char_b, baselines["clan"], baselines["family"],
	)
	assert_eq(_char_a.disposition_values[_char_b.character_id], -4)


func test_add_contact_does_not_overwrite_existing_disposition() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	_char_a.disposition_values[_char_b.character_id] = 50
	# Already-met-or-known: add_contact returns early on met_characters check,
	# but this character was added to met_characters via a previous interaction.
	_char_a.met_characters = [_char_b.character_id]
	InformationSystem.add_contact(
		_char_a, _char_b.character_id, _char_b.clan,
		_char_b, baselines["clan"], baselines["family"],
	)
	assert_eq(_char_a.disposition_values[_char_b.character_id], 50)


func test_observe_court_seeds_disposition_for_new_contacts() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	# Lion observer meets Crab Hida: Crab-Lion clan baseline +5 → seed +1.
	# Family unlisted → 0. Seed = round(1.25) = 1.
	InformationSystem.process_observe_court(
		_char_a, [_char_c], 3, 0,
		baselines["clan"], baselines["family"],
	)
	assert_eq(_char_a.disposition_values.get(_char_c.character_id, 0), 1)


func test_introduction_layers_bonus_on_top_of_seed() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	# Crane (Doji) ↔ Phoenix (Isawa) example would be the strongest positive,
	# but we use the existing fixtures: Lion (Akodo) ↔ Scorpion (Bayushi).
	# Seed = -4 (computed above). Introduction (non-kuge) bonus = +3.
	# Final stored disposition = -4 + 3 = -1.
	InformationSystem.process_introduction(
		_char_a, _char_b, false, 0,
		baselines["clan"], baselines["family"],
	)
	assert_eq(_char_a.disposition_values[_char_b.character_id], -1)


func test_introduction_kuge_bonus_layered_on_seed() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	# Same seed (-4) + kuge bonus (+2) = -2.
	InformationSystem.process_introduction(
		_char_a, _char_b, true, 0,
		baselines["clan"], baselines["family"],
	)
	assert_eq(_char_a.disposition_values[_char_b.character_id], -2)


func test_introduction_without_baselines_keeps_legacy_behavior() -> void:
	# 4-arg form: no baselines. Introduction bonus alone should land.
	InformationSystem.process_introduction(_char_a, _char_b, false, 0)
	assert_eq(_char_a.disposition_values[_char_b.character_id], 3)


func test_introduction_skips_bonus_when_already_met() -> void:
	# Existing met character doesn't get re-bonused.
	_char_a.met_characters = [_char_b.character_id]
	_char_a.disposition_values[_char_b.character_id] = 25
	InformationSystem.process_introduction(_char_a, _char_b, false, 0)
	assert_eq(_char_a.disposition_values[_char_b.character_id], 25)


# =============================================================================
# s55.6 — Information Transfer on Vassal Objective Assignment
# =============================================================================


func test_vassal_assignment_transfers_knowledge() -> void:
	# Lord has knowledge about province 5; vassal should receive it
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.character_name = "Lord"
	lord.clan = "Lion"
	lord.knowledge_pool = []
	var province_entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.DIRECT_OBSERVATION, "province_status",
		{"target_province_id": 5, "stability": 80.0}, 0
	)
	InformationSystem.add_knowledge(lord, province_entry)

	var vassal := L5RCharacterData.new()
	vassal.character_id = 20
	vassal.character_name = "Vassal"
	vassal.clan = "Lion"
	vassal.lord_id = 10
	vassal.knowledge_pool = []

	var characters_by_id: Dictionary = {10: lord, 20: vassal}
	var objectives_map: Dictionary = {}

	var applied: Dictionary = {
		"character_id": 10,
		"effects": {
			"requires_vassal_objective_assignment": true,
			"vassal_id": 20,
			"assigned_need_type": "STABILIZE_PROVINCE",
			"target_province_id": 5,
		},
	}

	var result: Dictionary = DayOrchestrator._apply_vassal_objective_assignment(
		applied, characters_by_id, objectives_map, 0
	)
	assert_eq(result.get("type", ""), "vassal_objective_assigned")
	assert_eq(vassal.knowledge_pool.size(), 1)
	assert_eq(vassal.knowledge_pool[0].entry_type, "province_status")
	assert_eq(vassal.knowledge_pool[0].data.get("target_province_id", -1), 5)


func test_vassal_assignment_transfers_clan_contacts() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.character_name = "Lord"
	lord.clan = "Lion"
	lord.knowledge_pool = []
	lord.known_contacts_by_clan = {"Crane": [30]}

	var vassal := L5RCharacterData.new()
	vassal.character_id = 20
	vassal.character_name = "Vassal"
	vassal.clan = "Lion"
	vassal.lord_id = 10
	vassal.knowledge_pool = []
	vassal.met_characters = []
	vassal.known_contacts_by_clan = {}

	var contact := L5RCharacterData.new()
	contact.character_id = 30
	contact.character_name = "Crane Contact"
	contact.clan = "Crane"

	var characters_by_id: Dictionary = {10: lord, 20: vassal, 30: contact}
	var objectives_map: Dictionary = {}

	var applied: Dictionary = {
		"character_id": 10,
		"effects": {
			"requires_vassal_objective_assignment": true,
			"vassal_id": 20,
			"assigned_need_type": "IMPROVE_RELATIONS",
			"target_clan": "Crane",
		},
	}

	DayOrchestrator._apply_vassal_objective_assignment(
		applied, characters_by_id, objectives_map, 0
	)
	assert_true(30 in vassal.met_characters)
	var crane_contacts: Array = vassal.known_contacts_by_clan.get("Crane", [])
	assert_true(30 in crane_contacts)


func test_vassal_assignment_objective_has_target_fields() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.knowledge_pool = []

	var vassal := L5RCharacterData.new()
	vassal.character_id = 20
	vassal.lord_id = 10
	vassal.knowledge_pool = []

	var characters_by_id: Dictionary = {10: lord, 20: vassal}
	var objectives_map: Dictionary = {}

	var applied: Dictionary = {
		"character_id": 10,
		"effects": {
			"requires_vassal_objective_assignment": true,
			"vassal_id": 20,
			"assigned_need_type": "DEFEND_PROVINCE",
			"target_province_id": 7,
			"target_clan": "Crab",
		},
	}

	DayOrchestrator._apply_vassal_objective_assignment(
		applied, characters_by_id, objectives_map, 0
	)
	var obj: Dictionary = objectives_map[20]["primary"]
	assert_eq(obj.get("target_province_id", -1), 7)
	assert_eq(obj.get("target_clan", ""), "Crab")


func test_transfer_objective_knowledge_seeds_contacts() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	_char_a.known_contacts_by_clan = {"Crab": [_char_c.character_id]}
	var chars_by_id: Dictionary = {_char_c.character_id: _char_c}
	var objective: Dictionary = {"target_clan": "Crab"}
	# Recipient is Scorpion (_char_b). Crab-Scorpion baseline -15 → -3.75 → -4.
	# Bayushi-Hida unlisted → 0. Seed = -4.
	InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 0,
		[], chars_by_id, baselines["clan"], baselines["family"],
	)
	assert_eq(_char_b.disposition_values.get(_char_c.character_id, 999), -4)


# =============================================================================
# met_characters wiring — arrival observation uses add_contact
# =============================================================================


func test_arrival_observation_updates_contacts_by_clan() -> void:
	var arriving := L5RCharacterData.new()
	arriving.character_id = 1
	arriving.clan = "Lion"
	arriving.physical_location = "10"
	arriving.met_characters = []
	arriving.known_contacts_by_clan = {}
	arriving.knowledge_pool = []

	var resident := L5RCharacterData.new()
	resident.character_id = 2
	resident.clan = "Crane"
	resident.physical_location = "10"
	resident.met_characters = []
	resident.known_contacts_by_clan = {}
	resident.knowledge_pool = []

	var chars_by_id: Dictionary = {1: arriving, 2: resident}
	var arrivals: Array = [{"character_id": 1, "destination": "10"}]

	DayOrchestrator._process_arrival_observation(arrivals, chars_by_id, 0)
	# Both should be in each other's met_characters
	assert_true(2 in arriving.met_characters)
	assert_true(1 in resident.met_characters)
	# known_contacts_by_clan should be updated
	var lion_contacts: Array = resident.known_contacts_by_clan.get("Lion", [])
	assert_true(1 in lion_contacts)
	var crane_contacts: Array = arriving.known_contacts_by_clan.get("Crane", [])
	assert_true(2 in crane_contacts)


# -- update_intelligence_knowledge dedup tests --------------------------------

func test_update_intelligence_replaces_same_type_same_target() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 800
	c.knowledge_pool = []
	var old_entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 50, "bushido_virtue": Enums.BushidoVirtue.GI},
		0,
	)
	InformationSystem.update_intelligence_knowledge(c, old_entry)
	assert_eq(c.knowledge_pool.size(), 1)

	var new_entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 50, "bushido_virtue": Enums.BushidoVirtue.REI, "is_false": true},
		1,
	)
	InformationSystem.update_intelligence_knowledge(c, new_entry)
	assert_eq(c.knowledge_pool.size(), 1,
		"Should replace existing entry, not append")
	assert_eq(c.knowledge_pool[0].data.get("bushido_virtue"), Enums.BushidoVirtue.REI,
		"Replaced entry should have new data")
	assert_true(c.knowledge_pool[0].data.get("is_false", false),
		"Replaced entry should carry is_false flag")


func test_update_intelligence_keeps_different_targets() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 801
	c.knowledge_pool = []
	var e1 := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 50, "bushido_virtue": Enums.BushidoVirtue.GI},
		0,
	)
	var e2 := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 51, "bushido_virtue": Enums.BushidoVirtue.YU},
		0,
	)
	InformationSystem.update_intelligence_knowledge(c, e1)
	InformationSystem.update_intelligence_knowledge(c, e2)
	assert_eq(c.knowledge_pool.size(), 2,
		"Different targets should not dedup")


func test_update_intelligence_keeps_different_types() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 802
	c.knowledge_pool = []
	var e1 := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 50, "bushido_virtue": Enums.BushidoVirtue.GI},
		0,
	)
	var e2 := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"disposition_toward",
		{"target_character_id": 50, "disposition": 25},
		0,
	)
	InformationSystem.update_intelligence_knowledge(c, e1)
	InformationSystem.update_intelligence_knowledge(c, e2)
	assert_eq(c.knowledge_pool.size(), 2,
		"Different entry types should not dedup")


func test_update_intelligence_non_dedup_type_appends() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 803
	c.knowledge_pool = []
	var e1 := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"shadow_surveillance",
		{"target_character_id": 50, "contacts": [1, 2]},
		0,
	)
	var e2 := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"shadow_surveillance",
		{"target_character_id": 50, "contacts": [3, 4]},
		1,
	)
	InformationSystem.update_intelligence_knowledge(c, e1)
	InformationSystem.update_intelligence_knowledge(c, e2)
	assert_eq(c.knowledge_pool.size(), 2,
		"Non-dedup types should always append")


func test_false_info_replaces_true_info() -> void:
	var actor := L5RCharacterData.new()
	actor.character_id = 804
	actor.knowledge_pool = []
	var true_entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 60, "bushido_virtue": Enums.BushidoVirtue.CHUGI},
		0,
	)
	InformationSystem.update_intelligence_knowledge(actor, true_entry)
	assert_eq(actor.knowledge_pool.size(), 1)
	assert_eq(actor.knowledge_pool[0].data.get("bushido_virtue"),
		Enums.BushidoVirtue.CHUGI)

	var false_entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE,
		"personality_insight",
		{"target_character_id": 60, "bushido_virtue": Enums.BushidoVirtue.JIN, "is_false": true},
		1,
	)
	InformationSystem.update_intelligence_knowledge(actor, false_entry)
	assert_eq(actor.knowledge_pool.size(), 1,
		"False info should replace true info for same target")
	assert_true(actor.knowledge_pool[0].data.get("is_false", false),
		"Entry should now be the false version")


# -- Dead character guards (2026-05-23) ----------------------------------------

func test_process_observe_court_skips_dead_attendees() -> void:
	var observer := L5RCharacterData.new()
	observer.character_id = 10
	observer.character_name = "Observer"
	observer.clan = "Lion"
	observer.family = "Akodo"
	observer.met_characters = []
	observer.knowledge_pool = []
	observer.known_contacts_by_clan = {}
	observer.disposition_values = {}

	var alive_attendee := L5RCharacterData.new()
	alive_attendee.character_id = 20
	alive_attendee.character_name = "Alive Courtier"
	alive_attendee.clan = "Crane"
	alive_attendee.family = "Doji"
	alive_attendee.status = 4.0
	alive_attendee.stamina = 2
	alive_attendee.willpower = 2

	var dead_attendee := L5RCharacterData.new()
	dead_attendee.character_id = 30
	dead_attendee.character_name = "Dead Courtier"
	dead_attendee.clan = "Scorpion"
	dead_attendee.family = "Bayushi"
	dead_attendee.status = 5.0
	dead_attendee.stamina = 2
	dead_attendee.willpower = 2
	dead_attendee.wounds_taken = 999

	var attendees: Array = [alive_attendee, dead_attendee]
	var discovered: Array = InformationSystem.process_observe_court(
		observer, attendees, 3, 1,
	)
	# Only the alive attendee should be discovered
	var discovered_ids: Array = []
	for entry: KnowledgeEntry in discovered:
		discovered_ids.append(entry.data.get("character_id", -1))
	assert_true(20 in discovered_ids,
		"Alive attendee should be discovered")
	assert_false(30 in discovered_ids,
		"Dead attendee should not be discovered")


func test_transfer_objective_knowledge_skips_dead_contacts() -> void:
	var baselines: Dictionary = CollectiveDisposition.make_starting_baselines()
	var dead_contact := L5RCharacterData.new()
	dead_contact.character_id = 50
	dead_contact.clan = "Crab"
	dead_contact.family = "Hida"
	dead_contact.wounds_taken = 999
	_char_a.known_contacts_by_clan = {"Crab": [50]}
	_char_b.met_characters = []
	_char_b.known_contacts_by_clan = {}
	_char_b.knowledge_pool = []
	_char_b.disposition_values = {}
	var chars_by_id: Dictionary = {50: dead_contact}
	var objective: Dictionary = {"target_clan": "Crab"}
	InformationSystem.transfer_objective_knowledge(
		_char_a, _char_b, objective, 0,
		[], chars_by_id, baselines["clan"], baselines["family"],
	)
	var crab_contacts: Array = _char_b.known_contacts_by_clan.get("Crab", [])
	assert_false(50 in crab_contacts, "Dead contact should not be transferred")
