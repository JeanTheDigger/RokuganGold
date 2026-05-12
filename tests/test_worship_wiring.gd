extends GutTest
## Tests for worship system wiring: executor intercept, orchestrator
## accumulation, and seasonal worship evaluation.


var _dice: DiceEngine
var _time: TimeSystem


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)
	_time = TimeSystem.new()


func _make_char(id: int, clan: String = "Crane", school_type: Enums.SchoolType = Enums.SchoolType.BUSHI) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC_" + str(id)
	c.clan = clan
	c.family = "Doji"
	c.school_type = school_type
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.honor = 5.0
	c.glory = 3.0
	c.status = 4.0
	c.skills = {"Theology": 3, "Courtier": 3}
	c.emphases = {}
	c.reflexes = 3
	c.awareness = 3
	c.stamina = 3
	c.willpower = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	c.void_ring = 3
	c.wounds_taken = 0
	c.knowledge_pool = []
	c.known_contacts_by_clan = {}
	c.met_characters = []
	c.physical_location = "100"
	c.lord_id = -1
	ActionPointSystem.reset_daily_ap(c)
	return c


func _make_action(directed_fortune: int = -1, location_type: String = "roadside_shrine") -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "PERFORM_WORSHIP"
	a.target_npc_id = -1
	a.target_province_id = 1
	a.metadata = {
		"directed_fortune": directed_fortune,
		"location_type": location_type,
	}
	return a


func _make_ctx(ic_day: int = 10, season: int = 0) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = ic_day
	ctx.season = season
	return ctx


func _make_settlement(id: int, province_id: int, worship_locs: Array[Dictionary] = []) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.VILLAGE
	s.population_pu = 5
	s.worship_locations = worship_locs
	return s


func _make_province(id: int, clan: String = "Crane", family: String = "Doji") -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = id
	p.clan = clan
	p.family = family
	return p


# -- Executor Intercept Tests --------------------------------------------------

func test_executor_returns_worship_accumulation_flag() -> void:
	var c := _make_char(1)
	var action := _make_action()
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	assert_true(result.get("success", false))
	assert_eq(result.get("action_id"), "PERFORM_WORSHIP")
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("requires_worship_accumulation", false))


func test_executor_normal_char_generates_1_wp() -> void:
	var c := _make_char(1)
	var action := _make_action()
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	var effects: Dictionary = result.get("effects", {})
	assert_almost_eq(effects.get("total_wp", 0.0), 1.0, 0.01)


func test_executor_monk_generates_2_wp() -> void:
	var c := _make_char(1, "Dragon", Enums.SchoolType.MONK)
	var action := _make_action()
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	var effects: Dictionary = result.get("effects", {})
	assert_almost_eq(effects.get("total_wp", 0.0), 2.0, 0.01)


func test_executor_shugenja_gets_bonus_wp() -> void:
	var c := _make_char(1, "Phoenix", Enums.SchoolType.SHUGENJA)
	c.skills["Theology"] = 5
	c.intelligence = 4
	c.agility = 4
	var action := _make_action(Enums.GreatFortune.BISHAMON, "temple")
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("total_wp", 0.0) >= 1.0)


func test_executor_directed_fortune_sets_flag() -> void:
	var c := _make_char(1)
	var action := _make_action(Enums.GreatFortune.BENTEN)
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("directed", false))


func test_executor_undirected_worship_splits_wp() -> void:
	var c := _make_char(1)
	var action := _make_action(-1)
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	var effects: Dictionary = result.get("effects", {})
	var wp_dist: Dictionary = effects.get("wp_distribution", {})
	assert_eq(wp_dist.size(), 7)
	for f: int in range(7):
		assert_true(wp_dist.has(f))


func test_executor_province_id_from_action() -> void:
	var c := _make_char(1)
	var action := _make_action()
	action.target_province_id = 42
	var ctx := _make_ctx()
	var result: Dictionary = ActionExecutor.execute(action, c, ctx, _dice, {})
	var effects: Dictionary = result.get("effects", {})
	assert_eq(effects.get("province_id", -1), 42)


# -- Orchestrator Accumulation Tests -------------------------------------------

func test_accumulation_adds_wp_to_worship_state() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var day_results: Array = [{
		"character_id": 1,
		"effects": {
			"requires_worship_accumulation": true,
			"province_id": 5,
			"wp_distribution": {0: 1.0},
			"total_wp": 1.0,
		},
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_worship_accumulation(
		day_results, ws,
	)
	assert_eq(results.size(), 1)
	var province_wp: Dictionary = ws.get("province_wp", {})
	assert_true(province_wp.has(5))
	assert_almost_eq(province_wp[5].get(0, 0.0), 1.0, 0.01)


func test_accumulation_skips_when_no_flag() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var day_results: Array = [{
		"character_id": 1,
		"effects": {"some_other": true},
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_worship_accumulation(
		day_results, ws,
	)
	assert_eq(results.size(), 0)


func test_accumulation_skips_empty_worship_state() -> void:
	var day_results: Array = [{
		"character_id": 1,
		"effects": {
			"requires_worship_accumulation": true,
			"province_id": 5,
			"wp_distribution": {0: 1.0},
			"total_wp": 1.0,
		},
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_worship_accumulation(
		day_results, {},
	)
	assert_eq(results.size(), 0)


func test_accumulation_multiple_characters_stack() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var day_results: Array = [
		{
			"character_id": 1,
			"effects": {
				"requires_worship_accumulation": true,
				"province_id": 5,
				"wp_distribution": {0: 1.0},
				"total_wp": 1.0,
			},
		},
		{
			"character_id": 2,
			"effects": {
				"requires_worship_accumulation": true,
				"province_id": 5,
				"wp_distribution": {0: 2.0},
				"total_wp": 2.0,
			},
		},
	]
	DayOrchestrator._process_worship_accumulation(day_results, ws)
	var province_wp: Dictionary = ws.get("province_wp", {})
	assert_almost_eq(province_wp[5].get(0, 0.0), 3.0, 0.01)


func test_accumulation_skips_negative_province_id() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var day_results: Array = [{
		"character_id": 1,
		"effects": {
			"requires_worship_accumulation": true,
			"province_id": -1,
			"wp_distribution": {0: 1.0},
			"total_wp": 1.0,
		},
	}]
	var results: Array[Dictionary] = DayOrchestrator._process_worship_accumulation(
		day_results, ws,
	)
	assert_eq(results.size(), 0)


# -- Seasonal Worship Processing Tests -----------------------------------------

func test_seasonal_worship_computes_tiers() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var shrine: Dictionary = {"type": "shinden", "dedicated": false, "fortune": -1}
	var settlements: Array[SettlementData] = [
		_make_settlement(1, 1, [shrine]),
	]
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = DayOrchestrator._process_seasonal_worship(
		ws, settlements, provinces,
	)
	assert_true(result.has("province_tiers"))
	assert_true(result.has("clan_tiers"))
	assert_true(result.has("empire_tiers"))


func test_seasonal_worship_resets_wp_after_evaluation() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	WorshipSystem.add_active_worship_to_province(ws, 1, {0: 5.0})
	var settlements: Array[SettlementData] = [_make_settlement(1, 1)]
	var provinces: Dictionary = {1: _make_province(1)}
	DayOrchestrator._process_seasonal_worship(ws, settlements, provinces)
	var province_wp: Dictionary = ws.get("province_wp", {})
	assert_true(province_wp.is_empty())


func test_seasonal_worship_empty_state_returns_empty() -> void:
	var settlements: Array[SettlementData] = [_make_settlement(1, 1)]
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = DayOrchestrator._process_seasonal_worship(
		{}, settlements, provinces,
	)
	assert_true(result.is_empty())


func test_seasonal_worship_builds_family_map() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var shrine_a: Dictionary = {"type": "temple", "dedicated": false, "fortune": -1}
	var shrine_b: Dictionary = {"type": "temple", "dedicated": false, "fortune": -1}
	var settlements: Array[SettlementData] = [
		_make_settlement(1, 1, [shrine_a]),
		_make_settlement(2, 2, [shrine_b]),
	]
	var provinces: Dictionary = {
		1: _make_province(1, "Crane", "Doji"),
		2: _make_province(2, "Crane", "Doji"),
	}
	var result: Dictionary = DayOrchestrator._process_seasonal_worship(
		ws, settlements, provinces,
	)
	assert_true(result.has("family_tiers"))
	var family_tiers: Dictionary = result.get("family_tiers", {})
	assert_true(family_tiers.has("Doji"))


func test_seasonal_worship_builds_clan_map() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var shrine: Dictionary = {"type": "shinden", "dedicated": false, "fortune": -1}
	var settlements: Array[SettlementData] = [
		_make_settlement(1, 1, [shrine]),
	]
	var provinces: Dictionary = {1: _make_province(1, "Crane", "Doji")}
	var result: Dictionary = DayOrchestrator._process_seasonal_worship(
		ws, settlements, provinces,
	)
	var clan_tiers: Dictionary = result.get("clan_tiers", {})
	assert_true(clan_tiers.has("Crane"))


# -- Zone-to-Location Mapping Tests -------------------------------------------

func test_zone_castle_shrine_maps_to_village_shrine() -> void:
	var loc: String = NPCDecisionEngine._zone_to_worship_location(Enums.ZoneSubtype.CASTLE_SHRINE)
	assert_eq(loc, "village_shrine")


func test_zone_shrine_clearing_maps_to_roadside() -> void:
	var loc: String = NPCDecisionEngine._zone_to_worship_location(Enums.ZoneSubtype.SHRINE_CLEARING)
	assert_eq(loc, "roadside_shrine")


func test_zone_temple_grounds_maps_to_local_shrine() -> void:
	var loc: String = NPCDecisionEngine._zone_to_worship_location(Enums.ZoneSubtype.TEMPLE_GROUNDS)
	assert_eq(loc, "local_shrine")


func test_zone_unknown_defaults_to_roadside() -> void:
	var loc: String = NPCDecisionEngine._zone_to_worship_location(Enums.ZoneSubtype.MARKET_STREET)
	assert_eq(loc, "roadside_shrine")


# -- Metadata Population Tests -------------------------------------------------

func test_worship_metadata_populates_directed_fortune() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = Enums.GreatFortune.BISHAMON
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "PERFORM_WORSHIP"
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.zone_subtype = Enums.ZoneSubtype.TEMPLE_GROUNDS
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata.get("directed_fortune"), Enums.GreatFortune.BISHAMON)
	assert_eq(option.metadata.get("location_type"), "local_shrine")


func test_worship_metadata_undirected_uses_negative() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = -1
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "PERFORM_WORSHIP"
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.zone_subtype = Enums.ZoneSubtype.CASTLE_SHRINE
	NPCDecisionEngine._populate_action_metadata(option, need, ctx)
	assert_eq(option.metadata.get("directed_fortune"), -1)
	assert_eq(option.metadata.get("location_type"), "village_shrine")


# -- Full Day Integration Test -------------------------------------------------

func test_advance_day_includes_worship_results() -> void:
	var c := _make_char(1)
	var chars: Array[L5RCharacterData] = [c]
	var chars_by_id: Dictionary = {1: c}
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, chars, chars_by_id, {}, {}, {}, {},
		_dice, {}, {}, [], {},
		[], [], [], [], [], [],
		{}, {}, [1000], [], {},
		[], [], [], [],
		{}, [], [], [],
		[], [], [], {},
		[], [], [1], [], [1],
		[], [1], [], [1],
		[], {}, [-1], [], [], [10000],
		{}, [], ws,
	)
	assert_true(result.has("worship_accumulation_results"))
	assert_true(result.has("worship_seasonal_results"))


# -- PERFORM_WORSHIP in SELF_ACTIONS -------------------------------------------

func test_perform_worship_in_self_actions() -> void:
	assert_true("PERFORM_WORSHIP" in ActionExecutor.SELF_ACTIONS)
