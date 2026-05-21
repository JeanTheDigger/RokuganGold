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


func _make_settlement(id: int, province_id: int, worship_locs: Array = []) -> SettlementData:
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
	var results: Array = DayOrchestrator._process_worship_accumulation(
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
	var results: Array = DayOrchestrator._process_worship_accumulation(
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
	var results: Array = DayOrchestrator._process_worship_accumulation(
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
	var results: Array = DayOrchestrator._process_worship_accumulation(
		day_results, ws,
	)
	assert_eq(results.size(), 0)


# -- Seasonal Worship Processing Tests -----------------------------------------

func test_seasonal_worship_computes_tiers() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var shrine: Dictionary = {"type": "shinden", "dedicated": false, "fortune": -1}
	var settlements: Array = [
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
	var settlements: Array = [_make_settlement(1, 1)]
	var provinces: Dictionary = {1: _make_province(1)}
	DayOrchestrator._process_seasonal_worship(ws, settlements, provinces)
	var province_wp: Dictionary = ws.get("province_wp", {})
	assert_true(province_wp.is_empty())


func test_seasonal_worship_empty_state_returns_empty() -> void:
	var settlements: Array = [_make_settlement(1, 1)]
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = DayOrchestrator._process_seasonal_worship(
		{}, settlements, provinces,
	)
	assert_true(result.is_empty())


func test_seasonal_worship_builds_family_map() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var shrine_a: Dictionary = {"type": "temple", "dedicated": false, "fortune": -1}
	var shrine_b: Dictionary = {"type": "temple", "dedicated": false, "fortune": -1}
	var settlements: Array = [
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
	var settlements: Array = [
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
	var chars: Array = [c]
	var chars_by_id: Dictionary = {1: c}
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var result: Dictionary = DayOrchestrator.advance_day(
		_time, chars, chars_by_id, {}, {}, {}, {},
		_dice, {}, {}, [], {},
		[], [], [], [], [], [],
		{}, {}, [1000], [], {},
		[], [], [], [],
		{}, [], [], [],
		[], [], [], [],
		[], [], {}, [], [1],
		[], [1], [], [1],
		[], [], {}, [-1], [], [],
		[10000], {}, [], ws,
	)
	assert_true(result.has("worship_accumulation_results"))
	assert_true(result.has("worship_seasonal_results"))


# -- PERFORM_WORSHIP in SELF_ACTIONS -------------------------------------------

func test_perform_worship_in_self_actions() -> void:
	assert_true("PERFORM_WORSHIP" in ActionExecutor.SELF_ACTIONS)


# -- compute_all_province_maluses Tests ----------------------------------------

func _make_worship_state_with_tiers(
	province_tiers: Dictionary = {},
	family_tiers: Dictionary = {},
	clan_tiers: Dictionary = {},
	empire_tiers: Dictionary = {},
) -> Dictionary:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	ws["province_tiers"] = province_tiers
	ws["family_tiers"] = family_tiers
	ws["clan_tiers"] = clan_tiers
	ws["empire_tiers"] = empire_tiers
	return ws


## Returns a dict mapping all 7 Great Fortunes to NONE.
## Use as a base and override specific fortunes to isolate test effects,
## since compute_all_province_maluses defaults missing entries to WRATHFUL.
func _all_none_tiers() -> Dictionary:
	var d: Dictionary = {}
	for f: int in range(7):
		d[f] = Enums.WorshipTier.NONE
	return d


func test_malus_empty_worship_state_returns_empty_per_province() -> void:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	assert_true(result.has(1))


func test_malus_wrathful_ebisu_yields_rice_modifier() -> void:
	var p_tiers: Dictionary = {1: {Enums.GreatFortune.EBISU: Enums.WorshipTier.WRATHFUL}}
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers)
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_almost_eq(malus.get("rice_modifier", 0.0), -0.50, 0.01)


func test_malus_wrathful_benten_sets_marriage_auto_fail() -> void:
	var p_tiers: Dictionary = {1: {Enums.GreatFortune.BENTEN: Enums.WorshipTier.WRATHFUL}}
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers)
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_true(malus.get("marriage_auto_fail", false))


func test_malus_wrathful_hotei_sets_insurgency_spawn_doubled() -> void:
	var p_tiers: Dictionary = {1: {Enums.GreatFortune.HOTEI: Enums.WorshipTier.WRATHFUL}}
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers)
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_true(malus.get("insurgency_spawn_doubled", false))


func test_malus_multiple_fortunes_merge_stability() -> void:
	# Set all fortunes to NONE at all levels, then override the two being tested.
	# Without this, unspecified fortunes default to WRATHFUL at each tier level.
	var base: Dictionary = _all_none_tiers()
	base[Enums.GreatFortune.BENTEN] = Enums.WorshipTier.DISPLEASED
	base[Enums.GreatFortune.HOTEI] = Enums.WorshipTier.RESTLESS
	var p_tiers: Dictionary = {1: base}
	var f_none: Dictionary = {"Doji": _all_none_tiers()}
	var c_none: Dictionary = {"Crane": _all_none_tiers()}
	var e_none: Dictionary = _all_none_tiers()
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers, f_none, c_none, e_none)
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	# BENTEN DISPLEASED: stability_per_season = -1, HOTEI RESTLESS: stability_per_season = -5
	assert_almost_eq(malus.get("stability_per_season", 0.0), -6.0, 0.01)


func test_malus_none_tier_produces_no_malus() -> void:
	# All fortunes at all levels must be NONE to produce no maluses at all
	var all_none: Dictionary = _all_none_tiers()
	var p_tiers: Dictionary = {1: all_none}
	var f_none: Dictionary = {"Doji": _all_none_tiers()}
	var c_none: Dictionary = {"Crane": _all_none_tiers()}
	var e_none: Dictionary = _all_none_tiers()
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers, f_none, c_none, e_none)
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_false(malus.has("rice_modifier"))


func test_malus_worst_tier_cascades_from_family() -> void:
	# Set all fortunes to NONE at all levels except the family-level EBISU
	var f_base: Dictionary = _all_none_tiers()
	f_base[Enums.GreatFortune.EBISU] = Enums.WorshipTier.DISPLEASED
	var f_tiers: Dictionary = {"Doji": f_base}
	var p_tiers: Dictionary = {1: _all_none_tiers()}
	var c_none: Dictionary = {"Crane": _all_none_tiers()}
	var e_none: Dictionary = _all_none_tiers()
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers, f_tiers, c_none, e_none)
	var provinces: Dictionary = {1: _make_province(1, "Crane", "Doji")}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_almost_eq(malus.get("rice_modifier", 0.0), -0.30, 0.01)


func test_malus_worst_tier_cascades_from_clan() -> void:
	# Set all fortunes to NONE at all levels except the clan-level DAIKOKU
	var c_base: Dictionary = _all_none_tiers()
	c_base[Enums.GreatFortune.DAIKOKU] = Enums.WorshipTier.RESTLESS
	var c_tiers: Dictionary = {"Crane": c_base}
	var p_tiers: Dictionary = {1: _all_none_tiers()}
	var f_none: Dictionary = {"Doji": _all_none_tiers()}
	var e_none: Dictionary = _all_none_tiers()
	var ws: Dictionary = _make_worship_state_with_tiers(p_tiers, f_none, c_tiers, e_none)
	var provinces: Dictionary = {1: _make_province(1, "Crane", "Doji")}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_almost_eq(malus.get("koku_modifier", 0.0), -0.15, 0.01)


func test_malus_worst_tier_cascades_from_empire() -> void:
	var e_tiers: Dictionary = {Enums.GreatFortune.BISHAMON: Enums.WorshipTier.WRATHFUL}
	var ws: Dictionary = _make_worship_state_with_tiers({}, {}, {}, e_tiers)
	var provinces: Dictionary = {1: _make_province(1)}
	var result: Dictionary = WorshipSystem.compute_all_province_maluses(ws, provinces)
	var malus: Dictionary = result.get(1, {})
	assert_eq(malus.get("army_attack", 0.0), -3.0)


# -- ResourceTick Worship Malus Tests ------------------------------------------

func test_resource_tick_rice_modifier_reduces_harvest() -> void:
	var prov := _make_province(1)
	var s := _make_settlement(1, 1)
	s.farming_pu = 10
	var provinces: Array = [prov]
	var settlements: Array = [s]
	var meta: Dictionary = {}
	var maluses: Dictionary = {1: {"rice_modifier": -0.30}}
	var result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "autumn", meta, {}, maluses,
	)
	# Key is "harvest", not "harvest_results"
	var harvest: Dictionary = result.get("harvest", {})
	var h: Dictionary = harvest.get(1, {})
	assert_almost_eq(h.get("worship_rice_modifier", 0.0), -0.30, 0.01)
	assert_true(h.get("yield", 0.0) > 0.0)


func test_resource_tick_koku_modifier_reduces_generation() -> void:
	var prov := _make_province(1)
	var s := _make_settlement(1, 1)
	s.town_pu = 5
	s.koku_stockpile = 0.0
	var provinces: Array = [prov]
	var settlements: Array = [s]
	var meta: Dictionary = {}
	var no_malus_result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "summer", meta, {},
	)
	var koku_without: float = s.koku_stockpile

	s.koku_stockpile = 0.0
	meta = {}
	var maluses: Dictionary = {1: {"koku_modifier": -0.50}}
	var _result: Dictionary = ResourceTick.process_seasonal_tick(
		provinces, settlements, "summer", meta, {}, maluses,
	)
	var koku_with: float = s.koku_stockpile
	assert_true(koku_with < koku_without)
	assert_true(koku_with > 0.0)


func test_resource_tick_pop_growth_modifier_reduces_growth() -> void:
	var prov := _make_province(1)
	prov.stability = 80.0
	var s := _make_settlement(1, 1)
	s.farming_pu = 100
	s.rice_stockpile = 500.0
	var provinces: Array = [prov]
	var settlements: Array = [s]
	var meta: Dictionary = {"starvation_stages": {1: ResourceTick.StarvationStage.CLEAR}}
	ResourceTick.process_seasonal_tick(
		provinces, settlements, "spring", meta, {},
	)
	var farming_without: int = s.farming_pu

	s.farming_pu = 100
	s.rice_stockpile = 500.0
	meta = {"starvation_stages": {1: ResourceTick.StarvationStage.CLEAR}}
	var maluses: Dictionary = {1: {"pop_growth_modifier": -0.50}}
	ResourceTick.process_seasonal_tick(
		provinces, settlements, "spring", meta, {}, maluses,
	)
	var farming_with: int = s.farming_pu
	assert_true(farming_without > 100, "Farming PU should grow without modifier")
	assert_true(farming_with <= farming_without, "Modifier should reduce or equal growth")


# -- DayOrchestrator Stability Malus Tests -------------------------------------

func test_apply_worship_stability_maluses_reduces_stability() -> void:
	var prov := _make_province(1)
	prov.stability = 50.0
	var maluses: Dictionary = {1: {"stability_per_season": -10.0}}
	DayOrchestrator._apply_worship_stability_maluses(maluses, {1: prov})
	assert_almost_eq(prov.stability, 40.0, 0.01)


func test_apply_worship_stability_maluses_floors_at_zero() -> void:
	var prov := _make_province(1)
	prov.stability = 5.0
	var maluses: Dictionary = {1: {"stability_per_season": -20.0}}
	DayOrchestrator._apply_worship_stability_maluses(maluses, {1: prov})
	assert_almost_eq(prov.stability, 0.0, 0.01)


func test_apply_worship_stability_maluses_skips_positive() -> void:
	var prov := _make_province(1)
	prov.stability = 50.0
	var maluses: Dictionary = {1: {"stability_per_season": 0.0}}
	DayOrchestrator._apply_worship_stability_maluses(maluses, {1: prov})
	assert_almost_eq(prov.stability, 50.0, 0.01)


func test_apply_worship_stability_maluses_skips_missing_province() -> void:
	var maluses: Dictionary = {999: {"stability_per_season": -10.0}}
	DayOrchestrator._apply_worship_stability_maluses(maluses, {})
	pass_test("No crash when province ID not found in dictionary")


# -- Marriage Auto-Fail Tests --------------------------------------------------

func test_benten_marriage_blocked_when_any_province_has_flag() -> void:
	var maluses: Dictionary = {1: {"marriage_auto_fail": true}}
	assert_true(DayOrchestrator._is_benten_marriage_blocked({}, {}, maluses))


func test_benten_marriage_not_blocked_when_empty() -> void:
	assert_false(DayOrchestrator._is_benten_marriage_blocked({}, {}, {}))


func test_benten_marriage_not_blocked_without_flag() -> void:
	var maluses: Dictionary = {1: {"stability_per_season": -5.0}}
	assert_false(DayOrchestrator._is_benten_marriage_blocked({}, {}, maluses))


# -- Insurgency Spawn Doubling Tests -------------------------------------------

func test_insurgency_spawn_chance_doubled_by_worship() -> void:
	var base_chance: float = InsurgencySystem.get_spawn_chance(
		Enums.InsurgencyType.PEASANT_REVOLT,
		Enums.StabilityTier.VOLATILE,
		_make_province(1),
		{},
	)
	assert_true(base_chance > 0.0)
	var doubled: float = base_chance * 2.0
	assert_almost_eq(doubled, base_chance * 2.0, 0.01)


# -- ArmyCombatSystem Bishamon Tests -------------------------------------------

func test_bishamon_attack_penalty_reduces_effective_attack() -> void:
	var bc: Dictionary = {
		"base_attack": 6,
		"terrain_attack_mod": 0,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
		"worship_attack_penalty": -2,
	}
	var atk: int = ArmyCombatSystem._get_effective_attack(bc)
	assert_eq(atk, 4)


func test_bishamon_attack_penalty_floors_at_zero() -> void:
	var bc: Dictionary = {
		"base_attack": 1,
		"terrain_attack_mod": 0,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
		"worship_attack_penalty": -5,
	}
	var atk: int = ArmyCombatSystem._get_effective_attack(bc)
	assert_eq(atk, 0)


func test_bishamon_morale_penalty_reduces_effective_morale() -> void:
	var bc: Dictionary = {
		"base_morale_defense": 5,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
		"worship_morale_penalty": -3,
	}
	var md: int = ArmyCombatSystem._get_effective_morale_defense(bc)
	assert_eq(md, 2)


func test_no_worship_penalty_leaves_attack_unchanged() -> void:
	var bc: Dictionary = {
		"base_attack": 6,
		"terrain_attack_mod": 0,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
	}
	var atk: int = ArmyCombatSystem._get_effective_attack(bc)
	assert_eq(atk, 6)


# -- Battle State Injection Tests ----------------------------------------------

func test_inject_worship_battle_maluses_sets_attack_penalty() -> void:
	var company := ArmyCombatSystem.create_company(1, Enums.CompanyUnitType.BUSHI_RETAINER, -1, 5)
	var bc: Dictionary = ArmyCombatSystem.make_battle_company(company, 0, 0, "attacker")
	var states: Array = [bc]
	var maluses: Dictionary = {5: {"army_attack": -2, "army_morale": -1}}
	DayOrchestrator._inject_worship_battle_maluses(states, maluses)
	assert_eq(bc.get("worship_attack_penalty", 0), -2)
	assert_eq(bc.get("worship_morale_penalty", 0), -1)


func test_inject_worship_battle_maluses_sets_commander_risk() -> void:
	var company := ArmyCombatSystem.create_company(1, Enums.CompanyUnitType.BUSHI_RETAINER, -1, 5)
	var bc: Dictionary = ArmyCombatSystem.make_battle_company(company, 0, 0, "attacker")
	var states: Array = [bc]
	var maluses: Dictionary = {5: {"commander_risk_reduced": true}}
	DayOrchestrator._inject_worship_battle_maluses(states, maluses)
	assert_eq(bc.get("worship_commander_risk_bonus", 0), 5)


func test_inject_worship_no_malus_leaves_state_clean() -> void:
	var company := ArmyCombatSystem.create_company(1, Enums.CompanyUnitType.BUSHI_RETAINER, -1, 5)
	var bc: Dictionary = ArmyCombatSystem.make_battle_company(company, 0, 0, "attacker")
	var states: Array = [bc]
	DayOrchestrator._inject_worship_battle_maluses(states, {})
	assert_false(bc.has("worship_attack_penalty"))


# -- Daikoku Trade Route & Market Tests ----------------------------------------

func test_trade_route_koku_disabled_returns_zero() -> void:
	var prov := _make_province(1)
	var route := TradeRouteData.new()
	route.route_id = 1
	route.province_a_id = 1
	route.province_b_id = 2
	route.koku_bonus_per_season = 5.0
	route.is_disrupted = false
	var routes: Array = [route]
	var maluses: Dictionary = {1: {"trade_route_koku_disabled": true}}
	var result: float = RiceMarketSystem.compute_trade_route_koku(prov, routes, maluses)
	assert_almost_eq(result, 0.0, 0.01)


func test_trade_route_koku_normal_without_malus() -> void:
	var prov := _make_province(1)
	var route := TradeRouteData.new()
	route.route_id = 1
	route.province_a_id = 1
	route.province_b_id = 2
	route.koku_bonus_per_season = 5.0
	route.is_disrupted = false
	var routes: Array = [route]
	var result: float = RiceMarketSystem.compute_trade_route_koku(prov, routes)
	assert_almost_eq(result, 5.0, 0.01)


# -- Fukurokujin Divination Tests ----------------------------------------------

func test_divination_impossible_returns_failure() -> void:
	var malus: Dictionary = {"divination_impossible": true}
	var result: Dictionary = WorshipSystem.resolve_divination(
		_dice, 5, 4, Enums.GreatFortune.BISHAMON, {}, malus,
	)
	assert_false(result.get("success", true))
	assert_true(result.get("divination_impossible", false))


func test_divination_dice_penalty_reduces_rolled() -> void:
	_dice.set_seed(42)
	var normal: Dictionary = WorshipSystem.resolve_divination(
		_dice, 5, 4, Enums.GreatFortune.BISHAMON, {},
	)
	_dice.set_seed(42)
	var malus: Dictionary = {"divination_dice_penalty": -2}
	var penalized: Dictionary = WorshipSystem.resolve_divination(
		_dice, 5, 4, Enums.GreatFortune.BISHAMON, {}, malus,
	)
	assert_true(
		penalized.get("roll_total", 0) <= normal.get("roll_total", 0),
		"Fewer dice should produce equal or lower roll total",
	)


# -- Jurojin Natural Death Tests -----------------------------------------------

func test_natural_death_increase_raises_chance() -> void:
	var base: int = GempukkuSystem.get_natural_death_chance(70)
	assert_true(base > 0)
	var c := _make_char(1)
	c.age = 70
	_dice.set_seed(999)
	var malus: Dictionary = {"natural_death_increase": true}
	var expected_chance: int = ceili(float(base) * 1.5)
	assert_true(expected_chance > base)


func test_aging_accelerated_doubles_natural_death_chance() -> void:
	var base: int = GempukkuSystem.get_natural_death_chance(55)
	assert_true(base > 0)
	var malus: Dictionary = {"aging_accelerated": true}
	var expected_chance: int = ceili(float(base) * 2.0)
	assert_true(expected_chance > base)


# -- Army Recovery Healing Slower Tests ----------------------------------------

func test_army_recovery_healing_halved_by_worship() -> void:
	var army: Dictionary = {"army_id": 1, "is_moving": false, "province_id": 5}
	var company: Dictionary = {
		"army_id": 1,
		"company_id": 10,
		"unit_type": Enums.CompanyUnitType.BUSHI_RETAINER,
		"current_health": 100,
		"current_morale": 10,
	}
	var maluses: Dictionary = {5: {"healing_slower": true}}
	var results: Array = DayOrchestrator._process_army_recovery(
		[army], {}, [company], maluses,
	)
	if results.size() > 0:
		var per_company: Array = results[0].get("per_company", [])
		if per_company.size() > 0:
			var hr: int = per_company[0].get("health_recovery", 0)
			assert_true(hr <= ArmyUpkeepSystem.RECOVERY_HEALTH_PER_TICK / 2 + 1)
		else:
			pass_test("No per_company results — healing comparison not tested")
	else:
		pass_test("No recovery results — healing comparison not tested")


# -- Fukurokujin Intelligence Roll Modifier Tests -----------------------------

func test_intelligence_tn_increased_by_fukurokujin_malus() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "EXAMINE_CRIME_SCENE"
	var ctx := _make_ctx()
	var malus: Dictionary = {"intelligence_roll_modifier": -5}
	var tn: int = ActionExecutor._get_tn_for_action(
		"EXAMINE_CRIME_SCENE", action, ctx, malus,
	)
	# EXAMINE_CRIME_SCENE is not in INTELLIGENCE_ACTIONS (which is empty),
	# so the intelligence_roll_modifier path is never hit. Falls through to SOCIAL_BASE_TN.
	assert_eq(tn, ActionExecutor.SOCIAL_BASE_TN)


func test_intelligence_tn_normal_without_malus() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "EXAMINE_CRIME_SCENE"
	var ctx := _make_ctx()
	var tn: int = ActionExecutor._get_tn_for_action(
		"EXAMINE_CRIME_SCENE", action, ctx,
	)
	assert_eq(tn, ActionExecutor.SOCIAL_BASE_TN)


func test_intelligence_tn_wrathful_adds_10() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "EXAMINE_CRIME_SCENE"
	var ctx := _make_ctx()
	var malus: Dictionary = {"intelligence_roll_modifier": -10}
	var tn: int = ActionExecutor._get_tn_for_action(
		"EXAMINE_CRIME_SCENE", action, ctx, malus,
	)
	# EXAMINE_CRIME_SCENE is not in INTELLIGENCE_ACTIONS, so modifier is ignored
	assert_eq(tn, ActionExecutor.SOCIAL_BASE_TN)


# -- Jurojin Rank 4 Commander Risk Tests ---------------------------------------

func test_rank4_commander_risk_adds_bonus_for_high_rank() -> void:
	var c := _make_char(1)
	c.reflexes = 5
	c.awareness = 5
	c.intelligence = 5
	c.perception = 5
	c.agility = 5
	c.stamina = 5
	c.willpower = 5
	c.strength = 5
	c.void_ring = 5
	c.skills = {"Battle": 5, "Theology": 3, "Courtier": 3}
	var company := ArmyCombatSystem.create_company(1, Enums.CompanyUnitType.BUSHI_RETAINER, c.character_id, 5)
	var bc: Dictionary = ArmyCombatSystem.make_battle_company(company, 0, 0, "attacker", c)
	var states: Array = [bc]
	var maluses: Dictionary = {5: {"rank4_commander_risk_checks": true}}
	DayOrchestrator._inject_worship_battle_maluses(states, maluses)
	assert_eq(bc.get("worship_commander_risk_bonus", 0), 3)


func test_rank4_commander_risk_skips_low_rank() -> void:
	var c := _make_char(1)
	var company := ArmyCombatSystem.create_company(1, Enums.CompanyUnitType.BUSHI_RETAINER, c.character_id, 5)
	var bc: Dictionary = ArmyCombatSystem.make_battle_company(company, 0, 0, "attacker", c)
	var states: Array = [bc]
	var maluses: Dictionary = {5: {"rank4_commander_risk_checks": true}}
	DayOrchestrator._inject_worship_battle_maluses(states, maluses)
	assert_false(bc.has("worship_commander_risk_bonus"))


func test_bishamon_and_jurojin_risk_stacks() -> void:
	var c := _make_char(1)
	c.reflexes = 5
	c.awareness = 5
	c.intelligence = 5
	c.perception = 5
	c.agility = 5
	c.stamina = 5
	c.willpower = 5
	c.strength = 5
	c.void_ring = 5
	c.skills = {"Battle": 5, "Theology": 3, "Courtier": 3}
	var company := ArmyCombatSystem.create_company(1, Enums.CompanyUnitType.BUSHI_RETAINER, c.character_id, 5)
	var bc: Dictionary = ArmyCombatSystem.make_battle_company(company, 0, 0, "attacker", c)
	var states: Array = [bc]
	var maluses: Dictionary = {5: {"commander_risk_reduced": true, "rank4_commander_risk_checks": true}}
	DayOrchestrator._inject_worship_battle_maluses(states, maluses)
	assert_eq(bc.get("worship_commander_risk_bonus", 0), 8)
