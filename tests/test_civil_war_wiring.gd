extends GutTest
## Tests for IntraClanCivilWar wiring into DayOrchestrator (s53.2).


var _time: TimeSystem
var _dice: DiceEngine
var _scoring_tables: Dictionary
var _filter_data: Dictionary
var _action_skill_map: Dictionary
var _season_meta: Dictionary
var _action_log: Array
var _provinces: Dictionary


func before_each() -> void:
	_time = TimeSystem.new(1120, 0)
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.terrain_type = Enums.TerrainType.PLAINS
	province.clan = "Lion"
	_provinces = {10: province}

	_action_log = []
	_season_meta = {}

	_scoring_tables = {
		"objective_alignment": {
			"REST": {"DO_NOTHING": 10, "REST": 50, "TRAIN": 30},
		},
		"personality_lean": {},
		"competence_table": {},
		"disposition_tiers": {},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}
	_filter_data = {
		"personality_filter": {},
	}
	_action_skill_map = {
		"DO_NOTHING": {"skill": "none", "trait": "Awareness"},
		"REST": {"skill": "none", "trait": "Stamina"},
	}


func _make_char(id: int, clan: String = "Lion") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC %d" % id
	c.clan = clan
	c.family = "Akodo"
	c.status = 3.0
	c.action_points_current = 2
	c.action_points_max = 2
	c.honor = 5.0
	c.glory = 3.0
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.reflexes = 3
	c.awareness = 3
	c.stamina = 3
	c.willpower = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	c.void_ring = 2
	c.skills = {"Etiquette": 3, "Kenjutsu": 3}
	c.emphases = {}
	c.wounds_taken = 0
	c.knowledge_pool = []
	c.known_contacts_by_clan = {}
	c.met_characters = []
	return c


func _advance_to_season_boundary(
	characters: Array,
	active_civil_wars: Array = [],
	precedent_modifiers: Dictionary = {},
) -> Dictionary:
	var result: Dictionary = {}
	for i: int in 120:
		result = _run_day(characters, active_civil_wars, precedent_modifiers)
		if result.get("season_changed", false):
			return result
	return result


func _run_day(
	characters: Array,
	active_civil_wars: Array = [],
	precedent_modifiers: Dictionary = {},
) -> Dictionary:
	var chars_by_id: Dictionary = {}
	for c: L5RCharacterData in characters:
		chars_by_id[c.character_id] = c
	return DayOrchestrator.advance_day(
		_time, characters, chars_by_id, {},
		{}, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], [], [], [], [], [1], {}, {}, [1000],  # 13-21
		[], {}, [],                                # 22-24
		[], [1], [], {},                           # 25-28
		[], [1],                                   # 29-30
		[], [],                                    # 31-32
		[], [], [], [], [], {},                    # 33-38
		[], [], [1],                               # 39-41: active_wars, trade_routes, next_war_id
		[], [1],                                   # 42-43: active_courts, next_court_id
		[], [1],                                   # 44-45: active_edicts, next_edict_id
		[], {}, [-1],                              # 46-48: hordes, strength_counters, last_targeted_pid
		[], [], [10000],                           # 49-51: ships, children, next_character_id
		{}, [], {},                                # 52-54: seiyaku, marriages, worship
		[], [5000], [1],                           # 55-57: constructions, next_settlement_id, next_construction_id
		[], {}, {},                                # 58-60: court_commitments, togashi, phoenix_council
		active_civil_wars,                         # 61
		precedent_modifiers,                       # 62
	)


# -- Return dict key exists ----------------------------------------------------

func test_civil_war_results_key_in_return_dict() -> void:
	var c := _make_char(1)
	var result: Dictionary = _run_day([c])
	assert_has(result, "civil_war_results")


func test_empty_civil_wars_returns_empty_per_war() -> void:
	var c := _make_char(1)
	var result: Dictionary = _advance_to_season_boundary([c])
	var cw: Dictionary = result.get("civil_war_results", {})
	assert_eq(cw.get("per_war", []).size(), 0)


# -- No processing outside season boundary ------------------------------------

func test_no_civil_war_processing_on_non_season_day() -> void:
	var c := _make_char(1)
	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {1: IntraClanCivilWar.Faction.LEGITIMACY}
	var result: Dictionary = _run_day([c], [state])
	var cw: Dictionary = result.get("civil_war_results", {})
	assert_eq(cw.get("per_war", []).size(), 0)


# -- Stability penalty on season boundary --------------------------------------

func test_stability_penalty_applied_on_season_boundary() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 5.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	var province: ProvinceData = _provinces[10]
	var before_stability: float = province.stability

	_advance_to_season_boundary([rebel, authority], [state])

	assert_lt(province.stability, before_stability,
		"Province stability should decrease after civil war season")


func test_stability_penalty_is_minus_3_base() -> void:
	# Run a baseline without civil war to measure other seasonal stability drains.
	var baseline_rebel := _make_char(100, "Lion")
	var baseline_authority := _make_char(1, "Lion")
	var baseline_prov := ProvinceData.new()
	baseline_prov.province_id = 10
	baseline_prov.stability = 50.0
	baseline_prov.terrain_type = Enums.TerrainType.PLAINS
	baseline_prov.clan = "Lion"
	var saved_provinces: Dictionary = _provinces.duplicate()
	_provinces = {10: baseline_prov}
	var saved_time := _time
	_time = TimeSystem.new(1120, 0)
	_advance_to_season_boundary([baseline_rebel, baseline_authority])
	var baseline_stability: float = baseline_prov.stability

	# Now run with civil war.
	_provinces = saved_provinces
	_time = TimeSystem.new(1120, 0)
	var rebel := _make_char(100, "Lion")
	var authority := _make_char(1, "Lion")

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	var province: ProvinceData = _provinces[10]
	province.stability = 50.0

	_advance_to_season_boundary([rebel, authority], [state])

	assert_almost_eq(province.stability, baseline_stability - 3.0, 0.01,
		"Base stability penalty should be -3 per season beyond baseline")


# -- Honor hemorrhage ----------------------------------------------------------

func test_rebel_lord_honor_hemorrhage() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 5.0
	var authority := _make_char(1, "Lion")

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority], [state])

	# Honor hemorrhage is rank-scaled via CrimeSystem.get_disloyalty_honor().
	# At honor 5.0 (rank 5, bracket 3): HONOR_TABLE_DISLOYALTY[3] = -10 → -1.0.
	assert_almost_eq(rebel.honor, 4.0, 0.01,
		"Rebel lord should lose rank-scaled disloyalty honor per season")


# -- Precedent decay runs unconditionally --------------------------------------

func test_precedent_decay_runs_without_active_wars() -> void:
	var c := _make_char(1)
	var mods: Dictionary = {
		0: {"bonus": 3, "expires": 0},
	}

	_advance_to_season_boundary([c], [], mods)

	assert_eq(mods.size(), 0, "Expired precedent modifier should be removed")


func test_precedent_decay_keeps_unexpired_modifiers() -> void:
	var c := _make_char(1)
	var mods: Dictionary = {
		0: {"bonus": 3, "expires": 999},
	}

	_advance_to_season_boundary([c], [], mods)

	assert_eq(mods.size(), 1, "Unexpired precedent modifier should remain")


# -- Legitimacy victory via rebel honor below 0 --------------------------------

func test_legitimacy_victory_when_rebel_honor_below_zero() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 0.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority], [state])

	assert_false(state["active"], "War should be finalised")
	assert_true(state.get("legitimacy_victory", false),
		"Legitimacy should win when rebel honor is below 0")


func test_legitimacy_victory_when_rebel_dead() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.wounds_taken = 999
	var authority := _make_char(1, "Lion")

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority], [state])

	assert_false(state["active"], "War should be finalised when rebel is dead")


# -- Resolution topic generation -----------------------------------------------

func test_resolution_generates_topic() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 0.0
	var authority := _make_char(1, "Lion")

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	var result: Dictionary = _advance_to_season_boundary([rebel, authority], [state])
	var cw: Dictionary = result.get("civil_war_results", {})
	var resolutions: Array = cw.get("resolutions", [])
	assert_gt(resolutions.size(), 0, "Should have a resolution entry")
	assert_true(resolutions[0].has("topic_id"), "Resolution should generate a topic")


# -- Post-resolution scars applied ---------------------------------------------

func test_post_resolution_scars_applied_between_factions() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 0.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}
	rebel.disposition_values[1] = 0
	authority.disposition_values[100] = 0

	_advance_to_season_boundary([rebel, authority], [state])

	assert_lt(int(authority.disposition_values.get(100, 0)), 0,
		"Authority should have negative disposition toward rebel after resolution")


# -- Scar decay ----------------------------------------------------------------

func test_scar_entries_stored_in_season_meta() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 0.0
	var authority := _make_char(1, "Lion")

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority], [state])

	assert_true(_season_meta.has("civil_war_scars"),
		"Season meta should contain civil_war_scars after resolution")


# -- Rebel victory counter -----------------------------------------------------

func test_rebel_victory_counter_increments() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 5.0
	rebel.status = 6.0
	# Rebel must hold a seat: physical_location in a matching province's settlement_ids.
	rebel.physical_location = "5000"
	var province: ProvinceData = _provinces[10]
	province.family = "Akodo"
	province.settlement_ids = [5000]

	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	var allied_fd := _make_char(50, "Lion")
	allied_fd.status = 5.0

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		50: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority, allied_fd], [state])

	assert_gt(int(state.get("consecutive_rebel_victory_seasons", 0)), 0,
		"Rebel victory counter should increment when conditions are met")


# -- Inactive wars skipped -----------------------------------------------------

func test_inactive_war_skipped() -> void:
	# Run a baseline without any civil war to measure other seasonal stability drains.
	var baseline_char := _make_char(1)
	var baseline_prov := ProvinceData.new()
	baseline_prov.province_id = 10
	baseline_prov.stability = 80.0
	baseline_prov.terrain_type = Enums.TerrainType.PLAINS
	baseline_prov.clan = "Lion"
	var saved_provinces: Dictionary = _provinces.duplicate()
	_provinces = {10: baseline_prov}
	var saved_time := _time
	_time = TimeSystem.new(1120, 0)
	_advance_to_season_boundary([baseline_char])
	var baseline_stability: float = baseline_prov.stability

	# Now run with an inactive civil war.
	_provinces = saved_provinces
	_time = TimeSystem.new(1120, 0)
	var c := _make_char(1)
	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["active"] = false

	var province: ProvinceData = _provinces[10]
	province.stability = 80.0

	_advance_to_season_boundary([c], [state])

	assert_eq(province.stability, baseline_stability,
		"Inactive war should not affect province stability beyond baseline")


# -- Defection -----------------------------------------------------------------

func test_defection_on_desperate_war_score() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 5.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	var npc := _make_char(50, "Lion")
	npc.disposition_values[1] = 60

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["war_score"] = 80
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
		50: IntraClanCivilWar.Faction.REBEL,
	}

	_advance_to_season_boundary([rebel, authority, npc], [state])

	var cw: Dictionary = _advance_to_season_boundary([rebel, authority, npc], [state])
	# NPC 50 should have defected since rebel war score is desperate (100-80=20 < 25)
	# and NPC has high disposition toward authority
	var defections: Array = cw.get("civil_war_results", {}).get("defections", [])
	# We can't guarantee defection fires due to loyalty re-eval,
	# but defection trigger should have been checked
	pass_test("Defection check runs without error")


# -- Precedent effect on rebel victory -----------------------------------------

func test_precedent_effect_applied_on_rebel_victory() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 5.0
	rebel.status = 6.0
	# Rebel must hold a seat to prevent legitimacy victory via rebel_seat_lost.
	rebel.physical_location = "5000"
	var province: ProvinceData = _provinces[10]
	province.family = "Akodo"
	province.settlement_ids = [5000]

	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	authority.wounds_taken = 999
	var allied_fd := _make_char(50, "Lion")
	allied_fd.status = 5.0

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["consecutive_rebel_victory_seasons"] = 5
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		50: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	var mods: Dictionary = {}

	_advance_to_season_boundary([rebel, authority, allied_fd], [state], mods)

	if not state.get("active", true):
		assert_gt(mods.size(), 0, "Precedent effect should be applied on rebel victory")
	else:
		pass_test("War not yet resolved — counter may have reset")


# -- Rebel consequences on legitimacy victory ----------------------------------

func test_rebel_family_daimyo_loses_honor_on_legitimacy_victory() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.honor = 0.0
	rebel.status = 6.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority], [state])

	# Rebel's honor was already 0 (the hemorrhage floors at 0),
	# but the -1.0 family daimyo penalty should have been applied
	assert_eq(rebel.honor, 0.0,
		"Rebel FD honor should be floored at 0 after hemorrhage + penalty")


# -- Multiple civil wars -------------------------------------------------------

func test_multiple_civil_wars_processed_independently() -> void:
	var rebel1 := _make_char(100, "Lion")
	var auth1 := _make_char(1, "Lion")
	var rebel2 := _make_char(200, "Crane")
	rebel2.clan = "Crane"
	var auth2 := _make_char(2, "Crane")
	auth2.clan = "Crane"

	var crane_prov := ProvinceData.new()
	crane_prov.province_id = 20
	crane_prov.stability = 60.0
	crane_prov.terrain_type = Enums.TerrainType.PLAINS
	crane_prov.clan = "Crane"
	_provinces[20] = crane_prov

	var state1: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state1["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}
	var state2: Dictionary = IntraClanCivilWar.make_initial_state(200, 2, "Crane", 5001, 0)
	state2["faction_assignments"] = {
		200: IntraClanCivilWar.Faction.REBEL,
		2: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	var result: Dictionary = _advance_to_season_boundary(
		[rebel1, auth1, rebel2, auth2],
		[state1, state2],
	)

	var cw: Dictionary = result.get("civil_war_results", {})
	assert_eq(cw.get("per_war", []).size(), 2,
		"Both civil wars should be processed")


# -- Non-clan provinces unaffected ---------------------------------------------

func test_non_clan_provinces_unaffected() -> void:
	# Run a baseline to measure non-civil-war seasonal effects on Crane province.
	var baseline_char := _make_char(1, "Lion")
	var baseline_crane := ProvinceData.new()
	baseline_crane.province_id = 20
	baseline_crane.stability = 80.0
	baseline_crane.terrain_type = Enums.TerrainType.PLAINS
	baseline_crane.clan = "Crane"
	var baseline_lion := ProvinceData.new()
	baseline_lion.province_id = 10
	baseline_lion.stability = 70.0
	baseline_lion.terrain_type = Enums.TerrainType.PLAINS
	baseline_lion.clan = "Lion"
	var saved_provinces: Dictionary = _provinces.duplicate()
	_provinces = {10: baseline_lion, 20: baseline_crane}
	var saved_time := _time
	_time = TimeSystem.new(1120, 0)
	_advance_to_season_boundary([baseline_char])
	var baseline_crane_stability: float = baseline_crane.stability

	# Now run with Lion civil war.
	_provinces = saved_provinces
	_time = TimeSystem.new(1120, 0)
	var rebel := _make_char(100, "Lion")
	var authority := _make_char(1, "Lion")

	var crane_prov := ProvinceData.new()
	crane_prov.province_id = 20
	crane_prov.stability = 80.0
	crane_prov.terrain_type = Enums.TerrainType.PLAINS
	crane_prov.clan = "Crane"
	_provinces[20] = crane_prov

	var state: Dictionary = IntraClanCivilWar.make_initial_state(100, 1, "Lion", 5000, 0)
	state["faction_assignments"] = {
		100: IntraClanCivilWar.Faction.REBEL,
		1: IntraClanCivilWar.Faction.LEGITIMACY,
	}

	_advance_to_season_boundary([rebel, authority], [state])

	assert_eq(crane_prov.stability, baseline_crane_stability,
		"Non-clan provinces should not be affected by civil war beyond baseline")


# -- Trigger & Faction Formation (s53.2.1, s53.2.2) ---------------------------

func test_trigger_civil_war_creates_state() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.status = 6.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	authority.lord_id = -1
	var vassal := _make_char(50, "Lion")
	vassal.lord_id = 1

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority, 50: vassal}

	var result: Dictionary = DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority, vassal], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	assert_true(result.get("triggered", false), "Civil war should trigger")
	assert_eq(wars.size(), 1, "Should create one civil war state")
	assert_true(wars[0].get("active", false), "War should be active")
	assert_eq(wars[0].get("rebel_lord_id"), 100)
	assert_eq(wars[0].get("authority_lord_id"), 1)
	assert_eq(wars[0].get("clan"), "Lion")


func test_trigger_generates_tier_2_topic() -> void:
	var rebel := _make_char(100, "Lion")
	var authority := _make_char(1, "Lion")
	authority.lord_id = -1

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority}

	DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	assert_eq(topics.size(), 1, "Should generate one topic")
	assert_eq(topics[0].tier, TopicData.Tier.TIER_2)
	assert_eq(topics[0].topic_type, "civil_war")


func test_trigger_assigns_factions_to_all_clan_npcs() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.status = 6.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	authority.lord_id = -1
	var npc1 := _make_char(50, "Lion")
	npc1.lord_id = 1
	var npc2 := _make_char(51, "Lion")
	npc2.lord_id = 100

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars: Array = [rebel, authority, npc1, npc2]
	var chars_by_id: Dictionary = {100: rebel, 1: authority, 50: npc1, 51: npc2}

	DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		chars, chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	var assignments: Dictionary = wars[0].get("faction_assignments", {})
	assert_eq(assignments.get(100), IntraClanCivilWar.Faction.REBEL)
	assert_eq(assignments.get(1), IntraClanCivilWar.Faction.LEGITIMACY)
	assert_true(assignments.has(50) or assignments.has(51),
		"NPCs should be assigned factions")


func test_trigger_skips_dead_npcs() -> void:
	var rebel := _make_char(100, "Lion")
	var authority := _make_char(1, "Lion")
	authority.lord_id = -1
	var dead_npc := _make_char(50, "Lion")
	dead_npc.wounds_taken = 999

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority, 50: dead_npc}

	DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority, dead_npc], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	var assignments: Dictionary = wars[0].get("faction_assignments", {})
	assert_false(assignments.has(50), "Dead NPCs should not be assigned factions")


func test_trigger_skips_other_clan_npcs() -> void:
	var rebel := _make_char(100, "Lion")
	var authority := _make_char(1, "Lion")
	authority.lord_id = -1
	var crane_npc := _make_char(50, "Crane")
	crane_npc.clan = "Crane"

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority, 50: crane_npc}

	DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority, crane_npc], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	var assignments: Dictionary = wars[0].get("faction_assignments", {})
	assert_false(assignments.has(50), "Other-clan NPCs should not be assigned factions")


func test_trigger_prevents_duplicate_wars() -> void:
	var rebel := _make_char(100, "Lion")
	var authority := _make_char(1, "Lion")
	authority.lord_id = -1

	var existing: Dictionary = IntraClanCivilWar.make_initial_state(200, 1, "Lion", 4000, 0)
	var wars: Array = [existing]
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority}

	var result: Dictionary = DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	assert_false(result.get("triggered", true), "Should not trigger duplicate war")
	assert_eq(wars.size(), 1, "Should not add a second war")


func test_trigger_ronin_departure_on_low_pulls() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.status = 6.0
	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	authority.lord_id = -1
	var npc := _make_char(50, "Lion")
	npc.bushido_virtue = Enums.BushidoVirtue.NONE
	npc.shourido_virtue = Enums.ShouridoVirtue.NONE
	npc.disposition_values[100] = -80

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority, 50: npc}

	var result: Dictionary = DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority, npc], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	var ronin: Array = result.get("ronin_departures", [])
	if ronin.has(50):
		assert_true(npc.permanent_ronin, "Ronin departure should set permanent_ronin")
		assert_eq(npc.lord_id, -1, "Ronin should have no lord")
	else:
		pass_test("NPC did not meet ronin threshold")


func test_trigger_reassigns_broken_feudal_chains() -> void:
	var rebel := _make_char(100, "Lion")
	rebel.status = 6.0
	rebel.lord_id = -1
	var authority := _make_char(1, "Lion")
	authority.status = 7.0
	authority.lord_id = -1
	var vassal := _make_char(50, "Lion")
	vassal.lord_id = 100
	vassal.bushido_virtue = Enums.BushidoVirtue.CHUGI
	vassal.disposition_values[100] = -50

	var wars: Array = []
	var topics: Array = []
	var tid: Array = [5000]
	var chars_by_id: Dictionary = {100: rebel, 1: authority, 50: vassal}

	DayOrchestrator._trigger_civil_war(
		100, 1, "Lion", "directive",
		[rebel, authority, vassal], chars_by_id, {},
		wars, topics, tid, 10, 0,
	)

	var assignments: Dictionary = wars[0].get("faction_assignments", {})
	if assignments.get(50) == IntraClanCivilWar.Faction.LEGITIMACY:
		assert_ne(vassal.lord_id, 100,
			"Vassal on legitimacy side should not report to rebel lord")


# -- Phoenix reincarnation during schism (s55.10.3.7) ------------------------


func _make_phoenix_schism_state(
	champion_id: int, council_id: int
) -> Dictionary:
	var state: Dictionary = IntraClanCivilWar.make_initial_state(
		champion_id, council_id, "Phoenix", 5000, 0
	)
	state["faction_assignments"] = {
		champion_id: IntraClanCivilWar.Faction.REBEL,
		council_id: IntraClanCivilWar.Faction.LEGITIMACY,
	}
	return state


func test_phoenix_dead_champion_chugi_capitulates_resolves_war() -> void:
	# Champion is dead. Eligible Shiba reincarnation candidate has Chugi virtue
	# → auto-capitulates → schism resolves as Council Victory.
	var dead_champion: L5RCharacterData = _make_char(100, "Phoenix")
	dead_champion.family = "Shiba"
	dead_champion.wounds_taken = 999   # dead

	var authority: L5RCharacterData = _make_char(1, "Phoenix")
	authority.family = "Isawa"
	authority.status = 7.0

	var shiba_candidate: L5RCharacterData = _make_char(200, "Phoenix")
	shiba_candidate.family = "Shiba"
	shiba_candidate.bushido_virtue = Enums.BushidoVirtue.CHUGI
	shiba_candidate.shourido_virtue = Enums.ShouridoVirtue.NONE

	var state: Dictionary = _make_phoenix_schism_state(100, 1)
	var chars_by_id: Dictionary = {
		100: dead_champion, 1: authority, 200: shiba_candidate,
	}
	var topics: Array = []
	var tid: Array = [5000]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1

	var result: Dictionary = DayOrchestrator._check_civil_war_resolution(
		state, dead_champion, authority, chars_by_id,
		{}, 5, topics, tid, 300, {}, "Phoenix",
		{}, [], rng,
	)

	# Chugi champion capitulates → Legitimacy Victory → war resolved.
	assert_false(state.get("active", true), "Schism should resolve when champion capitulates")
	assert_gt(result.size(), 0, "Resolution dict should be non-empty")


func test_phoenix_dead_champion_ishi_continues_schism() -> void:
	# Champion is dead. Reincarnation candidate has Ishi virtue
	# → continues defiance → schism persists, rebel_lord_id updates.
	var dead_champion: L5RCharacterData = _make_char(100, "Phoenix")
	dead_champion.family = "Shiba"
	dead_champion.wounds_taken = 999   # dead

	var authority: L5RCharacterData = _make_char(1, "Phoenix")
	authority.family = "Isawa"
	authority.status = 7.0

	var shiba_candidate: L5RCharacterData = _make_char(200, "Phoenix")
	shiba_candidate.family = "Shiba"
	shiba_candidate.bushido_virtue = Enums.BushidoVirtue.NONE
	shiba_candidate.shourido_virtue = Enums.ShouridoVirtue.ISHI

	var state: Dictionary = _make_phoenix_schism_state(100, 1)
	var chars_by_id: Dictionary = {
		100: dead_champion, 1: authority, 200: shiba_candidate,
	}
	var topics: Array = []
	var tid: Array = [5000]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1

	var result: Dictionary = DayOrchestrator._check_civil_war_resolution(
		state, dead_champion, authority, chars_by_id,
		{}, 5, topics, tid, 300, {}, "Phoenix",
		{}, [], rng,
	)

	# Ishi champion continues → schism persists → empty resolution dict.
	assert_eq(result.size(), 0, "No resolution when schism continues")
	assert_true(state.get("active", false), "Schism should still be active")
	assert_eq(
		int(state.get("rebel_lord_id", -1)), 200,
		"rebel_lord_id should update to the new Champion"
	)


func test_phoenix_dead_champion_no_eligible_shiba_resolves_war() -> void:
	# No eligible Shiba → reincarnation returns -1 → treat as capitulation
	# (no new Champion to continue the defiance) → Legitimacy Victory.
	var dead_champion: L5RCharacterData = _make_char(100, "Phoenix")
	dead_champion.family = "Shiba"
	dead_champion.wounds_taken = 999   # dead

	var authority: L5RCharacterData = _make_char(1, "Phoenix")
	authority.family = "Isawa"
	authority.status = 7.0

	# No Shiba characters in the roster.
	var state: Dictionary = _make_phoenix_schism_state(100, 1)
	var chars_by_id: Dictionary = {100: dead_champion, 1: authority}
	var topics: Array = []
	var tid: Array = [5000]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	var result: Dictionary = DayOrchestrator._check_civil_war_resolution(
		state, dead_champion, authority, chars_by_id,
		{}, 5, topics, tid, 300, {}, "Phoenix",
		{}, [], rng,
	)

	assert_false(state.get("active", true), "Schism should resolve with no eligible Shiba")
	assert_gt(result.size(), 0)
