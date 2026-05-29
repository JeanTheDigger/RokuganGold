extends GutTest
## Tests for WorldStateSaver — full world state persistence round-trips.

const WorldStateSaverScript = preload("res://scripts/managers/world_state_saver.gd")
const TEST_BASE := "user://test_world_saves/"

var _saver: WorldStateSaver
var _ws: Node


func before_each() -> void:
	_saver = WorldStateSaverScript.new()
	_saver.BASE_DIR = TEST_BASE
	_ws = _make_world_state()


func after_each() -> void:
	_ws.free()
	_purge_test_dir(TEST_BASE)


func _purge_test_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			_purge_test_dir(dir_path + fname + "/")
			DirAccess.remove_absolute(dir_path + fname)
		else:
			DirAccess.remove_absolute(dir_path + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _make_world_state() -> Node:
	var script: GDScript = preload("res://scripts/managers/world_state.gd")
	var ws: Node = script.new()
	return ws


func _make_character(id: int, name: String = "Test") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = name
	c.clan = "Crane"
	c.family = "Doji"
	c.school = "Doji Courtier"
	c.honor = 6.5
	c.glory = 3.0
	c.status = 4.0
	return c


# -- Basic Round-Trip ----------------------------------------------------------

func test_save_returns_true_on_fresh_world() -> void:
	var ok: bool = _saver.save_world(_ws)
	assert_true(ok, "save_world should succeed on a fresh world state")


func test_load_returns_false_when_no_save_exists() -> void:
	var ws2 := Node.new()
	ws2.set_script(preload("res://scripts/managers/world_state.gd"))
	_saver.BASE_DIR = "user://nonexistent_dir/"
	var ok: bool = _saver.load_world(ws2)
	assert_false(ok, "load_world should return false when no save directory exists")
	ws2.free()


# -- Characters ----------------------------------------------------------------

func test_characters_round_trip() -> void:
	var c1 := _make_character(1, "Doji Hotaru")
	var c2 := _make_character(2, "Doji Kuwanan")
	c2.honor = 4.5
	_ws.characters = [c1, c2]
	_ws.rebuild_characters_by_id()

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.characters.size(), 2, "Should restore 2 characters")
	var ids: Array = []
	for c: L5RCharacterData in ws2.characters:
		ids.append(c.character_id)
	ids.sort()
	assert_eq(ids, [1, 2], "Character IDs should survive round-trip")

	var hotaru: L5RCharacterData = ws2.characters_by_id.get(1)
	assert_not_null(hotaru, "Should find character 1 in characters_by_id")
	assert_eq(hotaru.character_name, "Doji Hotaru")
	assert_eq(hotaru.honor, 6.5)

	var kuwanan: L5RCharacterData = ws2.characters_by_id.get(2)
	assert_eq(kuwanan.honor, 4.5)

	ws2.free()


# -- Topics --------------------------------------------------------------------

func test_topics_round_trip() -> void:
	var t := TopicData.new()
	t.topic_id = 42
	t.slug = "crane_scandal"
	t.title = "Crane Scandal"
	t.tier = TopicData.Tier.TIER_3
	t.category = TopicData.Category.POLITICAL
	t.momentum = 5.5
	t.ic_day_created = 100
	_ws.active_topics = [t]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.active_topics.size(), 1)
	var loaded: TopicData = ws2.active_topics[0]
	assert_eq(loaded.topic_id, 42)
	assert_eq(loaded.slug, "crane_scandal")
	assert_eq(loaded.title, "Crane Scandal")
	assert_eq(loaded.tier, TopicData.Tier.TIER_3)
	assert_eq(loaded.momentum, 5.5)

	ws2.free()


# -- Provinces -----------------------------------------------------------------

func test_provinces_round_trip() -> void:
	var p := ProvinceData.new()
	p.province_id = 7
	p.province_name = "Asahina Lands"
	p.clan = "Crane"
	p.stability = 85.0
	p.province_taint_level = 1.5
	_ws.provinces = {7: p}

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.provinces.size(), 1)
	assert_true(ws2.provinces.has(7))
	var loaded: ProvinceData = ws2.provinces[7]
	assert_eq(loaded.province_name, "Asahina Lands")
	assert_eq(loaded.stability, 85.0)
	assert_eq(loaded.province_taint_level, 1.5)

	ws2.free()


# -- ID Counters ---------------------------------------------------------------

func test_id_counters_round_trip() -> void:
	_ws.next_topic_id[0] = 999
	_ws.next_character_id[0] = 50000
	_ws.next_war_id[0] = 7
	_ws.next_secret_id[0] = 42
	_ws.next_hunt_id[0] = 3

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.next_topic_id[0], 999)
	assert_eq(ws2.next_character_id[0], 50000)
	assert_eq(ws2.next_war_id[0], 7)
	assert_eq(ws2.next_secret_id[0], 42)
	assert_eq(ws2.next_hunt_id[0], 3)

	ws2.free()


# -- Emperor State -------------------------------------------------------------

func test_emperor_state_round_trip() -> void:
	_ws.emperor_id = 500
	_ws.emperor_settlement_id = 200
	_ws.miya_representative_id = 501

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.emperor_id, 500)
	assert_eq(ws2.emperor_settlement_id, 200)
	assert_eq(ws2.miya_representative_id, 501)

	ws2.free()


# -- Commitments ---------------------------------------------------------------

func test_commitments_round_trip() -> void:
	var cd := CommitmentData.new()
	cd.commitment_id = 5
	cd.commitment_type = Enums.CommitmentType.VISIT_PROMISE
	cd.creditor_npc_id = 100
	cd.debtor_npc_id = 200
	cd.deadline_ic_day = 500
	cd.tier = 2
	cd.witnesses = [101, 102, 103]
	_ws.commitments = [cd]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.commitments.size(), 1)
	var loaded: CommitmentData = ws2.commitments[0]
	assert_eq(loaded.commitment_id, 5)
	assert_eq(loaded.commitment_type, Enums.CommitmentType.VISIT_PROMISE)
	assert_eq(loaded.creditor_npc_id, 100)
	assert_eq(loaded.debtor_npc_id, 200)
	assert_eq(loaded.witnesses.size(), 3)

	ws2.free()


# -- Secrets -------------------------------------------------------------------

func test_secrets_round_trip() -> void:
	var s := SecretData.new()
	s.secret_id = 10
	s.subject_id = 300
	s.severity = SecretData.Severity.TIER_2
	s.fabricated = true
	s.fabricator_id = 400
	s.known_by_ids = [400, 500]
	_ws.active_secrets = [s]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.active_secrets.size(), 1)
	var loaded: SecretData = ws2.active_secrets[0]
	assert_eq(loaded.secret_id, 10)
	assert_eq(loaded.subject_id, 300)
	assert_eq(loaded.severity, SecretData.Severity.TIER_2)
	assert_eq(loaded.fabricated, true)
	assert_eq(loaded.known_by_ids.size(), 2)

	ws2.free()


# -- Wars ----------------------------------------------------------------------

func test_wars_round_trip() -> void:
	var w := WarData.new()
	w.war_id = 3
	w.clan_a = "Lion"
	w.clan_b = "Crane"
	w.war_score_a = 15
	w.war_score_b = 5
	w.allied_clans_a = ["Scorpion"]
	_ws.active_wars = [w]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.active_wars.size(), 1)
	var loaded: WarData = ws2.active_wars[0]
	assert_eq(loaded.war_id, 3)
	assert_eq(loaded.clan_a, "Lion")
	assert_eq(loaded.clan_b, "Crane")
	assert_eq(loaded.war_score_a, 15)
	assert_eq(loaded.allied_clans_a, ["Scorpion"])

	ws2.free()


# -- Objectives Map (JSON dict) -----------------------------------------------

func test_objectives_map_round_trip() -> void:
	_ws.objectives_map = {
		"100": {"primary": "SECURE_ALLIANCE", "target_clan": "Lion"},
		"200": {"primary": "DEFEND_PROVINCE", "target_province_id": 7},
	}

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.objectives_map.size(), 2)
	assert_true(ws2.objectives_map.has("100"))
	assert_eq(ws2.objectives_map["100"]["primary"], "SECURE_ALLIANCE")

	ws2.free()


# -- Governance States ---------------------------------------------------------

func test_governance_states_round_trip() -> void:
	_ws.togashi_state["dissatisfaction"] = 3
	_ws.togashi_state["togashi_vanished"] = true

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.togashi_state.get("dissatisfaction"), 3)
	assert_eq(ws2.togashi_state.get("togashi_vanished"), true)

	ws2.free()


# -- Clans ---------------------------------------------------------------------

func test_clans_round_trip() -> void:
	var cd := ClanData.new()
	cd.clan_name = "Crane"
	cd.iron_stockpile = 15.5
	cd.arms_stockpile = 8.0
	cd.champion_id = 1
	cd.province_ids = [1, 2, 3, 7]
	_ws.clans = {"Crane": cd}

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.clans.size(), 1)
	assert_true(ws2.clans.has("Crane"))
	var loaded: ClanData = ws2.clans["Crane"]
	assert_eq(loaded.clan_name, "Crane")
	assert_eq(loaded.iron_stockpile, 15.5)
	assert_eq(loaded.champion_id, 1)
	assert_eq(loaded.province_ids.size(), 4)

	ws2.free()


# -- Dictionary State (entanglements, assassinations, etc.) --------------------

func test_dictionary_arrays_round_trip() -> void:
	_ws.entanglements = [
		{"seducer_id": 100, "target_id": 200, "state": "ACTIVE", "variant": "SEDUCE"},
	]
	_ws.active_assassination_ops = [
		{"assassin_id": 300, "target_id": 400, "phase": "ACCESS", "access_days": 3},
	]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.entanglements.size(), 1)
	assert_eq(ws2.entanglements[0]["seducer_id"], 100)
	assert_eq(ws2.active_assassination_ops.size(), 1)
	assert_eq(ws2.active_assassination_ops[0]["assassin_id"], 300)

	ws2.free()


# -- Collective Disposition Baselines ------------------------------------------

func test_baselines_round_trip() -> void:
	_ws.clan_baselines = {"Crane||Lion": -10, "Crab||Scorpion": 5}
	_ws.family_baselines = {"Hida||Doji": -5}

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.clan_baselines.get("Crane||Lion"), -10)
	assert_eq(ws2.clan_baselines.get("Crab||Scorpion"), 5)
	assert_eq(ws2.family_baselines.get("Hida||Doji"), -5)

	ws2.free()


# -- Character Complex Fields (knowledge_pool, disposition_values) ------------

func test_character_complex_fields_round_trip() -> void:
	var c := _make_character(1, "Doji Hotaru")
	c.disposition_values = {200: 15, 300: -8}
	c.skills = {"Courtier": 5, "Etiquette": 4, "Sincerity": 3}
	c.topic_pool = [42, 43, 44]
	c.met_characters = [200, 300, 400]

	var ke := KnowledgeEntry.new()
	ke.source = Enums.KnowledgeSource.DIRECT_OBSERVATION
	ke.entry_type = "personality_insight"
	ke.data = {"virtue": "JIN", "target_character_id": 200}
	ke.confidence = Enums.KnowledgeConfidence.FRESH
	ke.season_acquired = 5
	c.knowledge_pool = [ke]

	_ws.characters = [c]
	_ws.rebuild_characters_by_id()

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.characters.size(), 1)
	var loaded: L5RCharacterData = ws2.characters[0]
	assert_eq(loaded.skills.get("Courtier"), 5)
	assert_eq(loaded.topic_pool.size(), 3)
	assert_eq(loaded.met_characters.size(), 3)
	assert_eq(loaded.knowledge_pool.size(), 1)

	var loaded_ke: KnowledgeEntry = loaded.knowledge_pool[0]
	assert_eq(loaded_ke.entry_type, "personality_insight")
	assert_eq(loaded_ke.confidence, Enums.KnowledgeConfidence.FRESH)
	assert_eq(loaded_ke.data.get("virtue"), "JIN")

	ws2.free()


# -- Time System ---------------------------------------------------------------

func test_time_system_round_trip() -> void:
	_ws.time_system.current_tick = 500

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.time_system.current_tick, 500)

	ws2.free()


# -- Tattoos -------------------------------------------------------------------

func test_tattoos_round_trip() -> void:
	var t := TattooData.new()
	t.tattoo_id = 1
	t.recipient_id = 100
	t.artist_id = 200
	t.quality_tier = Enums.TattooQualityTier.NORMAL
	t.body_location = Enums.TattooBodyLocation.LEFT_WRIST_FOREARM
	t.is_ability_tattoo = false
	t.date_applied = 50
	_ws.tattoos = [t]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.tattoos.size(), 1)
	var loaded: TattooData = ws2.tattoos[0]
	assert_eq(loaded.tattoo_id, 1)
	assert_eq(loaded.recipient_id, 100)
	assert_eq(loaded.artist_id, 200)
	assert_eq(loaded.date_applied, 50)

	ws2.free()


# -- Settlements ---------------------------------------------------------------

func test_settlements_round_trip() -> void:
	var s := SettlementData.new()
	s.settlement_id = 100
	s.settlement_name = "Kyuden Doji"
	s.province_id = 7
	s.settlement_type = Enums.SettlementType.CASTLE
	s.population_pu = 50
	s.rice_stockpile = 120.5
	_ws.settlements = [s]

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.settlements.size(), 1)
	var loaded: SettlementData = ws2.settlements[0]
	assert_eq(loaded.settlement_id, 100)
	assert_eq(loaded.settlement_name, "Kyuden Doji")
	assert_eq(loaded.rice_stockpile, 120.5)

	ws2.free()


# -- ID Counter Reconciliation -------------------------------------------------

func test_reconcile_advances_counter_when_item_id_exceeds_counter() -> void:
	var t := TopicData.new()
	t.topic_id = 500
	t.slug = "test_topic"
	t.title = "Test"
	t.tier = TopicData.Tier.TIER_4
	t.category = TopicData.Category.PERSONAL
	_ws.active_topics = [t]
	_ws.next_topic_id[0] = 100

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_true(
		ws2.next_topic_id[0] > 500,
		"Counter should advance past highest loaded ID (got %d)" % ws2.next_topic_id[0],
	)
	ws2.free()


func test_reconcile_does_not_regress_valid_counter() -> void:
	var c := _make_character(5, "Test")
	_ws.characters = [c]
	_ws.next_character_id[0] = 100

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.next_character_id[0], 100, "Counter should not regress when already valid")


# -- Theater Pieces ------------------------------------------------------------

func test_theater_pieces_round_trip() -> void:
	var p := TheaterPieceData.new()
	p.piece_id = 7
	p.title = "The Fallen Crane"
	p.author_id = 1
	p.canonized = false
	p.craft_progress = -1
	p.disposition_magnitude = 3
	p.topic_weight = 2
	p.topic_ids = [42, 43]
	p.known_by = [1, 2, 5]
	p.times_performed = 4
	_ws.theater_pieces = [p]
	_ws.next_piece_id[0] = 10

	_saver.save_world(_ws)

	var ws2 := _make_world_state()
	_saver.load_world(ws2)

	assert_eq(ws2.theater_pieces.size(), 1, "Should restore 1 theater piece")
	var loaded: TheaterPieceData = ws2.theater_pieces[0]
	assert_eq(loaded.piece_id, 7)
	assert_eq(loaded.title, "The Fallen Crane")
	assert_eq(loaded.author_id, 1)
	assert_eq(loaded.disposition_magnitude, 3)
	assert_eq(loaded.topic_weight, 2)
	assert_eq(loaded.topic_ids.size(), 2)
	assert_eq(loaded.known_by.size(), 3)
	assert_eq(loaded.times_performed, 4)
	assert_gte(ws2.next_piece_id[0], 7, "next_piece_id counter should survive round-trip")

	ws2.free()
