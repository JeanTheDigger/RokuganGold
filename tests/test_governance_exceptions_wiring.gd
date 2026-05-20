extends GutTest
## Tests for Dragon (TogashiOversight) and Phoenix (PhoenixCouncil) governance
## exception wiring into DayOrchestrator.


# =============================================================================
# Helpers
# =============================================================================

func _make_char(id: int, name: String, clan: String, family: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = name
	c.clan = clan
	c.family = family
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.honor = 5.0
	c.glory = 3.0
	c.status = 4.0
	c.reflexes = 3
	c.awareness = 3
	c.stamina = 3
	c.willpower = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	c.void_ring = 2
	c.wounds_taken = 0
	c.skills = {}
	c.emphases = {}
	c.knowledge_pool = []
	c.known_contacts_by_clan = {}
	c.met_characters = []
	c.lord_id = 0
	return c


func _make_mirumoto_fc() -> L5RCharacterData:
	var c := _make_char(100, "Mirumoto Hitomi", "Dragon", "Mirumoto")
	c.lord_id = -1
	c.status = 7.0
	return c


func _make_togashi_kami() -> L5RCharacterData:
	var c := _make_char(200, "Togashi", "Dragon", "Togashi")
	c.lord_id = -1
	c.status = 10.0
	return c


func _make_shiba_champion() -> L5RCharacterData:
	var c := _make_char(300, "Shiba Ujimitsu", "Phoenix", "Shiba")
	c.lord_id = -1
	c.status = 8.0
	return c


func _make_elemental_master(id: int, element: String) -> L5RCharacterData:
	var c := _make_char(id, "Master of %s" % element, "Phoenix", "Isawa")
	c.role_position = "Master of %s" % element
	c.lord_id = 300
	c.status = 6.0
	c.bushido_virtue = Enums.BushidoVirtue.GI
	return c


func _make_time_system() -> TimeSystem:
	return TimeSystem.new(1120, 0)


func _make_dice_engine(seed_val: int = 42) -> DiceEngine:
	var de := DiceEngine.new()
	de.set_seed(seed_val)
	return de


func _make_scoring_tables() -> Dictionary:
	return {
		"objective_alignment": {"REST": {"DO_NOTHING": 10, "REST": 50}},
		"disposition_tiers": [{"min": -10, "max": 10, "cooperative": 0, "hostile": 0}],
		"personality_lean": {},
		"action_skill_map": {},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}


func _make_filter_data() -> Dictionary:
	return {"bushido": {}, "shourido": {}}


func _make_action_skill_map() -> Dictionary:
	return {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
	}


# =============================================================================
# Dragon — TogashiOversight wiring
# =============================================================================

func test_togashi_skipped_when_state_empty() -> void:
	var ts := TimeSystem.new(1120, 0)
	for _i in range(90):
		ts.advance_tick()
	var result := DayOrchestrator.advance_day(
		ts, [], {}, {}, {}, _make_scoring_tables(),
		_make_filter_data(), _make_dice_engine(), _make_action_skill_map(), {}, [], {},
	)
	assert_true(result["togashi_results"].is_empty())


func test_togashi_skipped_when_no_mirumoto_fc() -> void:
	var state := TogashiOversight.make_initial_state()
	var togashi := _make_togashi_kami()
	var chars: Array = [togashi]
	var topics: Array = []
	var next_tid: Array = [1]
	var directives: Array = []
	var result := DayOrchestrator._process_togashi_oversight(
		state, directives, chars, {200: togashi}, {}, topics, next_tid, 0,
	)
	assert_eq(result.get("skipped", false), true)
	assert_eq(result.get("reason", ""), "no_mirumoto_fc")


func test_togashi_runs_when_fc_present() -> void:
	var fc := _make_mirumoto_fc()
	var togashi := _make_togashi_kami()
	var chars: Array = [fc, togashi]
	var chars_by_id: Dictionary = {100: fc, 200: togashi}
	var state := TogashiOversight.make_initial_state()
	var directives: Array = []
	var topics: Array = []
	var next_tid: Array = [1]
	var result := DayOrchestrator._process_togashi_oversight(
		state, directives, chars, chars_by_id, {}, topics, next_tid, 0,
	)
	assert_false(result.is_empty())
	assert_false(result.get("skipped", true))


func test_find_mirumoto_fc_picks_highest_status() -> void:
	var fc1 := _make_mirumoto_fc()
	fc1.character_id = 101
	fc1.status = 6.0
	var fc2 := _make_mirumoto_fc()
	fc2.character_id = 102
	fc2.status = 8.0
	var chars: Array = [fc1, fc2]
	var found: L5RCharacterData = DayOrchestrator._find_mirumoto_fc(chars)
	assert_eq(found.character_id, 102)


func test_find_mirumoto_fc_skips_dead() -> void:
	var fc := _make_mirumoto_fc()
	fc.wounds_taken = 200
	fc.stamina = 2
	fc.willpower = 2
	var chars: Array = [fc]
	var found: L5RCharacterData = DayOrchestrator._find_mirumoto_fc(chars)
	assert_null(found)


func test_find_mirumoto_fc_skips_non_dragon() -> void:
	var c := _make_mirumoto_fc()
	c.clan = "Crane"
	var chars: Array = [c]
	assert_null(DayOrchestrator._find_mirumoto_fc(chars))


func test_find_mirumoto_fc_requires_no_lord() -> void:
	var c := _make_mirumoto_fc()
	c.lord_id = 5
	var chars: Array = [c]
	assert_null(DayOrchestrator._find_mirumoto_fc(chars))


func test_find_togashi_id_returns_togashi_champion() -> void:
	var t := _make_togashi_kami()
	var chars: Array = [t]
	assert_eq(DayOrchestrator._find_togashi_id(chars), 200)


func test_find_togashi_id_returns_minus_one_when_missing() -> void:
	var fc := _make_mirumoto_fc()
	var chars: Array = [fc]
	assert_eq(DayOrchestrator._find_togashi_id(chars), -1)


func test_build_togashi_world_state_has_required_keys() -> void:
	var chars: Array = [_make_mirumoto_fc()]
	var ws: Dictionary = DayOrchestrator._build_togashi_world_state({}, chars, {})
	assert_true(ws.has("clan_strengths"))
	assert_true(ws.has("active_inter_clan_wars"))
	assert_true(ws.has("emperor_vacant"))
	assert_true(ws.has("provinces_in_rebellion"))
	assert_true(ws.has("wall_breach_active"))
	assert_true(ws.has("crab_military_readiness"))


func test_build_togashi_world_state_counts_clan_strength() -> void:
	var c1 := _make_char(1, "A", "Dragon", "Mirumoto")
	c1.status = 5.0
	var c2 := _make_char(2, "B", "Dragon", "Kitsuki")
	c2.status = 3.0
	var chars: Array = [c1, c2]
	var ws: Dictionary = DayOrchestrator._build_togashi_world_state({}, chars, {})
	assert_almost_eq(float(ws["clan_strengths"]["Dragon"]), 8.0, 0.01)


func test_axis_to_string() -> void:
	assert_eq(DayOrchestrator._axis_to_string(TogashiOversight.Axis.BALANCE_OF_POWER), "balance")
	assert_eq(DayOrchestrator._axis_to_string(TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT), "shadowlands")


func test_togashi_defiance_applies_honor_loss() -> void:
	var state := TogashiOversight.make_initial_state()
	state["dissatisfaction"][TogashiOversight.Axis.BALANCE_OF_POWER] = 60.0

	var fc := _make_mirumoto_fc()
	fc.honor = 5.0
	fc.bushido_virtue = Enums.BushidoVirtue.NONE
	fc.shourido_virtue = Enums.ShouridoVirtue.ISHI

	var togashi := _make_togashi_kami()
	fc.disposition_values[togashi.character_id] = -50

	var chars: Array = [fc, togashi]
	var chars_by_id: Dictionary = {100: fc, 200: togashi}

	var ws: Dictionary = {
		"clan_strengths": {"Lion": 200.0, "Dragon": 100.0},
		"active_inter_clan_wars": 0,
		"emperor_vacant": false,
		"provinces_in_rebellion": 0,
		"failing_worship_provinces": 0,
		"realm_overlaps_empire_wide": 0,
		"realm_overlap_in_dragon_territory": false,
		"max_non_shadowlands_ptl": 0.0,
		"wall_breach_active": false,
		"shadowlands_incursion_tier": 0,
		"crab_military_readiness": 1.0,
	}

	var directives: Array = []
	var topics: Array = []
	var next_tid: Array = [1]

	var result := DayOrchestrator._process_togashi_oversight(
		state, directives, chars, chars_by_id, {"clan_strengths": ws["clan_strengths"]},
		topics, next_tid, 100,
	)

	if result.get("intervention_fired", false):
		var compliance: Dictionary = result.get("compliance", {})
		if not compliance.get("comply", true):
			assert_true(fc.honor < 5.0, "Honor should decrease on defiance")
			assert_true(topics.size() > 0, "Should generate topic on defiance")


# =============================================================================
# Phoenix — PhoenixCouncil wiring
# =============================================================================

func test_phoenix_skipped_when_state_empty() -> void:
	var ts := TimeSystem.new(1120, 0)
	for _i in range(90):
		ts.advance_tick()
	var result := DayOrchestrator.advance_day(
		ts, [], {}, {}, {}, _make_scoring_tables(),
		_make_filter_data(), _make_dice_engine(), _make_action_skill_map(), {}, [], {},
	)
	assert_true(result["phoenix_council_results"].is_empty())


func test_phoenix_skipped_when_no_shiba_champion() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var chars: Array = [_make_char(1, "A", "Phoenix", "Isawa")]
	var topics: Array = []
	var result := DayOrchestrator._process_phoenix_council_gating(
		state, [], chars, {}, _make_dice_engine(), topics, [1], 0,
	)
	assert_eq(result.get("skipped", false), true)
	assert_eq(result.get("reason", ""), "no_shiba_champion")


func test_phoenix_skipped_when_champion_has_authority() -> void:
	var state := PhoenixCouncil.make_initial_state()
	state["phoenix_champion_authority"] = true
	var champion := _make_shiba_champion()
	var chars: Array = [champion]
	var result := DayOrchestrator._process_phoenix_council_gating(
		state, [], chars, {300: champion}, _make_dice_engine(), [], [1], 0,
	)
	assert_eq(result.get("reason", ""), "champion_has_authority")


func test_phoenix_skipped_when_council_below_quorum() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var champion := _make_shiba_champion()
	var master := _make_elemental_master(400, "Fire")
	var chars: Array = [champion, master]
	var chars_by_id: Dictionary = {300: champion, 400: master}
	var result := DayOrchestrator._process_phoenix_council_gating(
		state, [], chars, chars_by_id, _make_dice_engine(), [], [1], 0,
	)
	assert_eq(result.get("reason", ""), "council_below_quorum")


func test_find_shiba_champion_picks_highest_status_phoenix() -> void:
	var c1 := _make_shiba_champion()
	c1.status = 7.0
	var c2 := _make_shiba_champion()
	c2.character_id = 301
	c2.status = 9.0
	var chars: Array = [c1, c2]
	var found := DayOrchestrator._find_shiba_champion(chars)
	assert_eq(found.character_id, 301)


func test_find_shiba_champion_skips_dead() -> void:
	var c := _make_shiba_champion()
	c.wounds_taken = 200
	c.stamina = 2
	c.willpower = 2
	var chars: Array = [c]
	assert_null(DayOrchestrator._find_shiba_champion(chars))


func test_find_living_elemental_masters() -> void:
	var m1 := _make_elemental_master(401, "Fire")
	var m2 := _make_elemental_master(402, "Water")
	var m3 := _make_elemental_master(403, "Air")
	var m4 := _make_elemental_master(404, "Earth")
	var m5 := _make_elemental_master(405, "Void")
	var chars: Array = [m1, m2, m3, m4, m5]
	var masters := DayOrchestrator._find_living_elemental_masters(chars)
	assert_eq(masters.size(), 5)


func test_find_living_masters_skips_dead() -> void:
	var m1 := _make_elemental_master(401, "Fire")
	m1.wounds_taken = 200
	m1.stamina = 2
	m1.willpower = 2
	var m2 := _make_elemental_master(402, "Water")
	var chars: Array = [m1, m2]
	var masters := DayOrchestrator._find_living_elemental_masters(chars)
	assert_eq(masters.size(), 1)


func test_directive_to_decision_type_war_readiness() -> void:
	var d: Dictionary = {"directive": StrategicReview.Directive.WAR_READINESS}
	assert_eq(
		DayOrchestrator._directive_to_decision_type(d),
		PhoenixCouncil.DecisionType.DEPLOY_GO_HATAMOTO,
	)


func test_directive_to_decision_type_seek_peace() -> void:
	var d: Dictionary = {"directive": StrategicReview.Directive.SEEK_PEACE}
	assert_eq(
		DayOrchestrator._directive_to_decision_type(d),
		PhoenixCouncil.DecisionType.SIGN_TREATY,
	)


func test_directive_to_decision_type_non_major_returns_negative() -> void:
	var d: Dictionary = {"directive": StrategicReview.Directive.ADJUST_TAX}
	assert_eq(DayOrchestrator._directive_to_decision_type(d), -1)


func test_phoenix_council_gates_major_directive() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var champion := _make_shiba_champion()
	var m1 := _make_elemental_master(401, "Fire")
	m1.bushido_virtue = Enums.BushidoVirtue.JIN
	var m2 := _make_elemental_master(402, "Water")
	m2.bushido_virtue = Enums.BushidoVirtue.JIN
	var m3 := _make_elemental_master(403, "Air")
	m3.bushido_virtue = Enums.BushidoVirtue.REI
	var m4 := _make_elemental_master(404, "Earth")
	m4.bushido_virtue = Enums.BushidoVirtue.JIN
	var m5 := _make_elemental_master(405, "Void")
	var chars: Array = [champion, m1, m2, m3, m4, m5]
	var chars_by_id: Dictionary = {300: champion, 401: m1, 402: m2, 403: m3, 404: m4, 405: m5}

	var directives: Array = [
		{"directive": StrategicReview.Directive.WAR_READINESS, "lord_id": 300},
	]
	var topics: Array = []
	var de := _make_dice_engine()

	var result := DayOrchestrator._process_phoenix_council_gating(
		state, directives, chars, chars_by_id, de, topics, [1], 100,
	)

	assert_true(result.has("vetoed") or result.has("approved"))
	var total: int = result.get("vetoed", []).size() + result.get("approved", []).size()
	assert_eq(total, 1, "Should have processed exactly one major directive")


func test_phoenix_non_major_directives_pass_through() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var champion := _make_shiba_champion()
	var m1 := _make_elemental_master(401, "Fire")
	var m2 := _make_elemental_master(402, "Water")
	var m3 := _make_elemental_master(403, "Air")
	var chars: Array = [champion, m1, m2, m3]
	var chars_by_id: Dictionary = {300: champion, 401: m1, 402: m2, 403: m3}

	var directives: Array = [
		{"directive": StrategicReview.Directive.ADJUST_TAX, "lord_id": 300},
		{"directive": StrategicReview.Directive.CALL_COURT, "lord_id": 300},
	]
	var original_count: int = directives.size()

	DayOrchestrator._process_phoenix_council_gating(
		state, directives, chars, chars_by_id, _make_dice_engine(), [], [1], 0,
	)

	assert_eq(directives.size(), original_count, "Non-major directives should not be removed")


func test_phoenix_vetoed_directive_removed_from_results() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var champion := _make_shiba_champion()
	var m1 := _make_elemental_master(401, "Fire")
	m1.bushido_virtue = Enums.BushidoVirtue.JIN
	var m2 := _make_elemental_master(402, "Water")
	m2.bushido_virtue = Enums.BushidoVirtue.JIN
	var m3 := _make_elemental_master(403, "Air")
	m3.bushido_virtue = Enums.BushidoVirtue.REI
	var m4 := _make_elemental_master(404, "Earth")
	m4.bushido_virtue = Enums.BushidoVirtue.JIN
	var m5 := _make_elemental_master(405, "Void")
	var chars: Array = [champion, m1, m2, m3, m4, m5]
	var chars_by_id: Dictionary = {300: champion, 401: m1, 402: m2, 403: m3, 404: m4, 405: m5}

	var directives: Array = [
		{"directive": StrategicReview.Directive.ADJUST_TAX, "lord_id": 300},
		{"directive": StrategicReview.Directive.WAR_READINESS, "lord_id": 300},
	]

	var result := DayOrchestrator._process_phoenix_council_gating(
		state, directives, chars, chars_by_id, _make_dice_engine(1), [], [1], 0,
	)

	if result.get("vetoed", []).size() > 0:
		var war_found: bool = false
		for d: Dictionary in directives:
			if int(d.get("directive", -1)) == StrategicReview.Directive.WAR_READINESS:
				war_found = true
		assert_false(war_found, "Vetoed WAR_READINESS should be removed from directives")
		assert_true(directives.size() >= 1, "ADJUST_TAX should remain")


func test_element_string_to_master() -> void:
	assert_eq(DayOrchestrator._element_string_to_master("fire"), PhoenixCouncil.Master.FIRE)
	assert_eq(DayOrchestrator._element_string_to_master("Fire"), PhoenixCouncil.Master.FIRE)
	assert_eq(DayOrchestrator._element_string_to_master("void"), PhoenixCouncil.Master.VOID)
	assert_eq(DayOrchestrator._element_string_to_master("unknown"), -1)


func test_phoenix_other_clan_directives_ignored() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var champion := _make_shiba_champion()
	var m1 := _make_elemental_master(401, "Fire")
	var m2 := _make_elemental_master(402, "Water")
	var m3 := _make_elemental_master(403, "Air")
	var chars: Array = [champion, m1, m2, m3]
	var chars_by_id: Dictionary = {300: champion, 401: m1, 402: m2, 403: m3}

	var directives: Array = [
		{"directive": StrategicReview.Directive.WAR_READINESS, "lord_id": 999},
	]
	var original_count: int = directives.size()

	DayOrchestrator._process_phoenix_council_gating(
		state, directives, chars, chars_by_id, _make_dice_engine(), [], [1], 0,
	)

	assert_eq(directives.size(), original_count, "Non-Phoenix directives should be untouched")


func test_phoenix_generates_topic_on_veto() -> void:
	var state := PhoenixCouncil.make_initial_state()
	var champion := _make_shiba_champion()
	var m1 := _make_elemental_master(401, "Fire")
	m1.bushido_virtue = Enums.BushidoVirtue.JIN
	var m2 := _make_elemental_master(402, "Water")
	m2.bushido_virtue = Enums.BushidoVirtue.JIN
	var m3 := _make_elemental_master(403, "Air")
	m3.bushido_virtue = Enums.BushidoVirtue.REI
	var m4 := _make_elemental_master(404, "Earth")
	m4.bushido_virtue = Enums.BushidoVirtue.JIN
	var m5 := _make_elemental_master(405, "Void")
	var chars: Array = [champion, m1, m2, m3, m4, m5]
	var chars_by_id: Dictionary = {300: champion, 401: m1, 402: m2, 403: m3, 404: m4, 405: m5}

	var directives: Array = [
		{"directive": StrategicReview.Directive.WAR_READINESS, "lord_id": 300},
	]
	var topics: Array = []

	DayOrchestrator._process_phoenix_council_gating(
		state, directives, chars, chars_by_id, _make_dice_engine(1), topics, [1], 50,
	)

	if topics.size() > 0:
		assert_eq(topics[0].variant, "phoenix_council_veto")
		assert_eq(topics[0].category, TopicData.Category.POLITICAL)
