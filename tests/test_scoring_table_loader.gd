extends GutTest


var _loader: ScoringTableLoader


func before_each() -> void:
	_loader = ScoringTableLoader.new()


func test_load_all_succeeds() -> void:
	var ok: bool = _loader.load_all()
	assert_true(ok, "All 8 JSON tables should load successfully")


func test_is_loaded_after_load() -> void:
	_loader.load_all()
	assert_true(_loader.is_loaded())


func test_objective_alignment_has_entries() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("objective_alignment")
	assert_true(table is Dictionary)
	assert_true(table.has("RAISE_DISPOSITION"))
	assert_true(table.has("REST"))


func test_objective_alignment_raise_disposition_charm() -> void:
	_loader.load_all()
	var table: Dictionary = _loader.get_table("objective_alignment")
	var rd: Dictionary = table.get("RAISE_DISPOSITION", {})
	assert_true(rd.has("CHARM"))
	assert_true(int(rd["CHARM"]) > 0)


func test_personality_lean_has_virtues() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("personality_lean")
	assert_true(table is Dictionary)
	assert_true(table.has("JIN"))
	assert_true(table.has("REI"))
	assert_true(table.has("SEIGYO"))


func test_personality_filter_has_bushido_shourido() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("personality_filter")
	assert_true(table is Dictionary)
	assert_true(table.has("bushido"))
	assert_true(table.has("shourido"))


func test_personality_filter_rei_blocks_intimidate() -> void:
	_loader.load_all()
	var table: Dictionary = _loader.get_table("personality_filter")
	var bushido: Dictionary = table.get("bushido", {})
	var rei: Dictionary = bushido.get("REI", {})
	var blocked: Array = rei.get("always_blocked", [])
	assert_has(blocked, "INTIMIDATE")


func test_action_skill_map_has_entries() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("action_skill_map")
	assert_true(table is Dictionary)
	assert_true(table.has("CHARM"))
	assert_true(table.has("NEGOTIATE"))


func test_action_skill_map_charm_primary() -> void:
	_loader.load_all()
	var table: Dictionary = _loader.get_table("action_skill_map")
	var charm: Dictionary = table.get("CHARM", {})
	assert_eq(charm.get("primary", ""), "Etiquette")


func test_competence_table_has_ranks() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("competence_table")
	assert_true(table is Dictionary)
	assert_eq(int(table.get("0", 0)), -20)
	assert_eq(int(table.get("3", 0)), 0)
	assert_eq(int(table.get("7", 0)), 20)


func test_disposition_tiers_is_array() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("disposition_tiers")
	assert_true(table is Array)
	assert_true(table.size() == 8)


func test_disposition_tiers_stranger() -> void:
	_loader.load_all()
	var tiers: Array = _loader.get_table("disposition_tiers")
	var stranger: Dictionary = tiers[3]
	assert_eq(stranger.get("tier", ""), "STRANGER")
	assert_eq(int(stranger.get("cooperative", -1)), 0)


func test_urgency_rules_has_entries() -> void:
	_loader.load_all()
	var table: Variant = _loader.get_table("urgency_rules")
	assert_true(table is Array)
	assert_true(table.size() >= 10)


func test_get_scoring_tables_dict() -> void:
	_loader.load_all()
	var tables: Dictionary = _loader.get_scoring_tables()
	assert_true(tables.has("objective_alignment"))
	assert_true(tables.has("personality_lean"))
	assert_true(tables.has("disposition_tiers"))
	assert_true(tables.has("urgency_rules"))


func test_get_filter_data_matches_personality_filter() -> void:
	_loader.load_all()
	var filter: Dictionary = _loader.get_filter_data()
	assert_true(filter.has("bushido"))
	assert_true(filter.has("shourido"))


func test_missing_table_returns_empty() -> void:
	var result: Variant = _loader.get_table("nonexistent")
	assert_true(result is Dictionary)
	assert_true(result.is_empty())
