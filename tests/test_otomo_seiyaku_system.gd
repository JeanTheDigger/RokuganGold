extends GutTest

# -- Helpers -------------------------------------------------------------------

func _make_char(id: int, clan: String, family: String = "", status: float = 5.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.family = family
	c.status = status
	c.lord_id = -1
	c.school_type = Enums.SchoolType.BUSHI
	c.stamina = 3
	c.willpower = 3
	return c


func _make_champion(id: int, clan: String) -> L5RCharacterData:
	return _make_char(id, clan, "", 8.0)


func _make_otomo_courtier(id: int) -> L5RCharacterData:
	var c := _make_char(id, "Imperial", "Otomo", 4.0)
	c.school_type = Enums.SchoolType.COURTIER
	return c


# -- Threshold Tests -----------------------------------------------------------

func test_default_threshold():
	assert_eq(OtomoSeiyakuSystem.get_alarm_threshold(-1), 45)


func test_benevolent_threshold():
	assert_eq(
		OtomoSeiyakuSystem.get_alarm_threshold(StrategicReview.EmperorArchetype.BENEVOLENT),
		55,
	)


func test_cunning_threshold():
	assert_eq(
		OtomoSeiyakuSystem.get_alarm_threshold(StrategicReview.EmperorArchetype.CUNNING),
		35,
	)


func test_tyrant_threshold():
	assert_eq(
		OtomoSeiyakuSystem.get_alarm_threshold(StrategicReview.EmperorArchetype.TYRANT),
		25,
	)


func test_iron_threshold():
	assert_eq(
		OtomoSeiyakuSystem.get_alarm_threshold(StrategicReview.EmperorArchetype.IRON),
		45,
	)


func test_warlike_threshold():
	assert_eq(
		OtomoSeiyakuSystem.get_alarm_threshold(StrategicReview.EmperorArchetype.WARLIKE),
		45,
	)


# -- Operative Pool Tests -----------------------------------------------------

func test_base_pool_no_bonus():
	var pool: int = OtomoSeiyakuSystem.get_operative_pool_size(
		StrategicReview.EmperorArchetype.IRON, 0,
	)
	assert_eq(pool, 3)


func test_cunning_pool_bonus():
	var pool: int = OtomoSeiyakuSystem.get_operative_pool_size(
		StrategicReview.EmperorArchetype.CUNNING, 0,
	)
	assert_eq(pool, 4)


func test_tyrant_pool_bonus():
	var pool: int = OtomoSeiyakuSystem.get_operative_pool_size(
		StrategicReview.EmperorArchetype.TYRANT, 0,
	)
	assert_eq(pool, 5)


func test_courtier_count_adds_half():
	var pool: int = OtomoSeiyakuSystem.get_operative_pool_size(
		StrategicReview.EmperorArchetype.IRON, 4,
	)
	assert_eq(pool, 5)


func test_courtier_count_odd():
	var pool: int = OtomoSeiyakuSystem.get_operative_pool_size(
		StrategicReview.EmperorArchetype.IRON, 3,
	)
	assert_eq(pool, 4)


# -- Pair Key Tests ------------------------------------------------------------

func test_pair_key_sorted():
	assert_eq(OtomoSeiyakuSystem.make_pair_key("Crane", "Crab"), "Crab||Crane")


func test_pair_key_already_sorted():
	assert_eq(OtomoSeiyakuSystem.make_pair_key("Crab", "Crane"), "Crab||Crane")


func test_get_all_clan_pairs_count():
	var pairs: Array[String] = OtomoSeiyakuSystem.get_all_clan_pairs()
	assert_eq(pairs.size(), 21)


func test_pair_key_symmetry():
	var k1: String = OtomoSeiyakuSystem.make_pair_key("Lion", "Crane")
	var k2: String = OtomoSeiyakuSystem.make_pair_key("Crane", "Lion")
	assert_eq(k1, k2)


# -- Valid Target Tests --------------------------------------------------------

func test_valid_target_pair():
	assert_true(OtomoSeiyakuSystem.is_valid_target_pair("Crab", "Crane"))


func test_invalid_imperial_pair():
	assert_false(OtomoSeiyakuSystem.is_valid_target_pair("Imperial", "Crane"))


func test_invalid_same_clan():
	assert_false(OtomoSeiyakuSystem.is_valid_target_pair("Crab", "Crab"))


func test_invalid_non_great_clan():
	assert_false(OtomoSeiyakuSystem.is_valid_target_pair("Mantis", "Crab"))


# -- Alarm Scanning Tests -----------------------------------------------------

func test_scan_no_alarms_below_threshold():
	var disps: Dictionary = {"Crab||Crane": 30}
	var alarms: Array[Dictionary] = OtomoSeiyakuSystem.scan_champion_dispositions(
		disps, 45,
	)
	assert_eq(alarms.size(), 0)


func test_scan_alarm_at_threshold():
	var pair_key: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	var disps: Dictionary = {pair_key: 45}
	var alarms: Array[Dictionary] = OtomoSeiyakuSystem.scan_champion_dispositions(
		disps, 45,
	)
	assert_eq(alarms.size(), 1)
	assert_eq(alarms[0]["pair_key"], pair_key)


func test_scan_alarms_sorted_by_disposition_desc():
	var k1: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	var k2: String = OtomoSeiyakuSystem.make_pair_key("Lion", "Dragon")
	var disps: Dictionary = {k1: 50, k2: 70}
	var alarms: Array[Dictionary] = OtomoSeiyakuSystem.scan_champion_dispositions(
		disps, 45,
	)
	assert_eq(alarms.size(), 2)
	assert_eq(alarms[0]["pair_key"], k2)
	assert_eq(alarms[1]["pair_key"], k1)


func test_scan_war_exemption_warlike():
	var k1: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	var disps: Dictionary = {k1: 60}
	var wars: Array = [{"clan_a": "Crab", "clan_b": "Dragon", "allied_clans_a": ["Crane"], "allied_clans_b": []}]
	var alarms: Array[Dictionary] = OtomoSeiyakuSystem.scan_champion_dispositions(
		disps, 45, wars, true,
	)
	assert_eq(alarms.size(), 0)


func test_scan_war_exemption_not_warlike():
	var k1: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	var disps: Dictionary = {k1: 60}
	var wars: Array = [{"clan_a": "Crab", "clan_b": "Dragon", "allied_clans_a": ["Crane"], "allied_clans_b": []}]
	var alarms: Array[Dictionary] = OtomoSeiyakuSystem.scan_champion_dispositions(
		disps, 45, wars, false,
	)
	assert_eq(alarms.size(), 1)


# -- State Management Tests ---------------------------------------------------

func test_initial_state():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	assert_true(state.has("active_directives"))
	assert_true(state.has("assigned_operatives"))
	assert_true(state.has("seasons_above_threshold"))
	assert_true(state.has("formal_alliances"))
	assert_false(state["exhaustion_topic_generated"])


# -- Directive Tests -----------------------------------------------------------

func test_create_directive():
	var d: Dictionary = OtomoSeiyakuSystem.create_directive("Crab||Crane", 1, "Crab", "Crane")
	assert_eq(d["pair_key"], "Crab||Crane")
	assert_eq(d["operative_id"], 1)
	assert_false(d["escalated"])
	assert_eq(d["seasons_active"], 0)
	assert_false(d["effectiveness_halved"])


func test_assign_directives():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var alarms: Array[Dictionary] = [
		{"pair_key": "Crab||Crane", "clan_a": "Crab", "clan_b": "Crane", "disposition": 50},
	]
	var ops: Array[int] = [100, 101, 102]
	var new_dirs: Array[Dictionary] = OtomoSeiyakuSystem.assign_directives(state, alarms, ops, 3)
	assert_eq(new_dirs.size(), 1)
	assert_eq(state["active_directives"].size(), 1)
	assert_eq(state["assigned_operatives"].size(), 1)


func test_assign_respects_pool_limit():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var alarms: Array[Dictionary] = [
		{"pair_key": "Crab||Crane", "clan_a": "Crab", "clan_b": "Crane", "disposition": 60},
		{"pair_key": "Dragon||Lion", "clan_a": "Dragon", "clan_b": "Lion", "disposition": 55},
		{"pair_key": "Phoenix||Scorpion", "clan_a": "Phoenix", "clan_b": "Scorpion", "disposition": 50},
	]
	var ops: Array[int] = [100, 101, 102]
	var new_dirs: Array[Dictionary] = OtomoSeiyakuSystem.assign_directives(state, alarms, ops, 2)
	assert_eq(new_dirs.size(), 2)
	assert_eq(state["active_directives"].size(), 2)


func test_assign_skips_existing_directive():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	state["assigned_operatives"][100] = "Crab||Crane"
	var alarms: Array[Dictionary] = [
		{"pair_key": "Crab||Crane", "clan_a": "Crab", "clan_b": "Crane", "disposition": 60},
		{"pair_key": "Dragon||Lion", "clan_a": "Dragon", "clan_b": "Lion", "disposition": 55},
	]
	var ops: Array[int] = [100, 101, 102]
	var new_dirs: Array[Dictionary] = OtomoSeiyakuSystem.assign_directives(state, alarms, ops, 3)
	assert_eq(new_dirs.size(), 1)
	assert_eq(new_dirs[0]["pair_key"], "Dragon||Lion")


func test_cancel_directive():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	state["assigned_operatives"][100] = "Crab||Crane"
	state["seasons_above_threshold"]["Crab||Crane"] = 3
	OtomoSeiyakuSystem.cancel_directive(state, "Crab||Crane")
	assert_eq(state["active_directives"].size(), 0)
	assert_eq(state["assigned_operatives"].size(), 0)
	assert_false(state["seasons_above_threshold"].has("Crab||Crane"))


# -- Escalation Tests ----------------------------------------------------------

func test_escalation_after_two_seasons():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	var disps: Dictionary = {"Crab||Crane": 50}
	OtomoSeiyakuSystem.update_escalation(state, disps, 45)
	assert_eq(state["seasons_above_threshold"].get("Crab||Crane", 0), 1)
	assert_false(state["active_directives"]["Crab||Crane"]["escalated"])
	var escalated: Array[String] = OtomoSeiyakuSystem.update_escalation(state, disps, 45)
	assert_eq(escalated.size(), 1)
	assert_true(state["active_directives"]["Crab||Crane"]["escalated"])


func test_escalation_resets_when_below():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	var disps: Dictionary = {"Crab||Crane": 50}
	OtomoSeiyakuSystem.update_escalation(state, disps, 45)
	assert_eq(state["seasons_above_threshold"]["Crab||Crane"], 1)
	disps["Crab||Crane"] = 30
	OtomoSeiyakuSystem.update_escalation(state, disps, 45)
	assert_eq(state["seasons_above_threshold"]["Crab||Crane"], 0)


# -- Cancellation Check Tests --------------------------------------------------

func test_check_cancellation_below_buffer():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	state["assigned_operatives"][100] = "Crab||Crane"
	var disps: Dictionary = {"Crab||Crane": 34}
	var cancelled: Array[String] = OtomoSeiyakuSystem.check_cancellations(state, disps, 45)
	assert_eq(cancelled.size(), 1)
	assert_eq(state["active_directives"].size(), 0)


func test_check_cancellation_not_below_buffer():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	state["assigned_operatives"][100] = "Crab||Crane"
	var disps: Dictionary = {"Crab||Crane": 36}
	var cancelled: Array[String] = OtomoSeiyakuSystem.check_cancellations(state, disps, 45)
	assert_eq(cancelled.size(), 0)
	assert_eq(state["active_directives"].size(), 1)


# -- Exhaustion Tests ----------------------------------------------------------

func test_pool_exhausted():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["assigned_operatives"][100] = "Crab||Crane"
	state["assigned_operatives"][101] = "Dragon||Lion"
	state["assigned_operatives"][102] = "Phoenix||Scorpion"
	assert_true(OtomoSeiyakuSystem.is_pool_exhausted(state, 3))


func test_pool_not_exhausted():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["assigned_operatives"][100] = "Crab||Crane"
	assert_false(OtomoSeiyakuSystem.is_pool_exhausted(state, 3))


func test_exhaustion_topic_fires_once():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["assigned_operatives"][100] = "Crab||Crane"
	state["assigned_operatives"][101] = "Dragon||Lion"
	state["assigned_operatives"][102] = "Phoenix||Scorpion"
	assert_true(OtomoSeiyakuSystem.check_exhaustion_topic(state, 3, 1))
	assert_false(OtomoSeiyakuSystem.check_exhaustion_topic(state, 3, 1))


func test_exhaustion_topic_no_alarms():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["assigned_operatives"][100] = "Crab||Crane"
	state["assigned_operatives"][101] = "Dragon||Lion"
	state["assigned_operatives"][102] = "Phoenix||Scorpion"
	assert_false(OtomoSeiyakuSystem.check_exhaustion_topic(state, 3, 0))


# -- Formal Alliance Tests ----------------------------------------------------

func test_declare_formal_alliance():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	OtomoSeiyakuSystem.declare_formal_alliance(state, "Crab||Crane")
	assert_true(OtomoSeiyakuSystem.is_formal_alliance(state, "Crab||Crane"))


func test_formal_alliance_escalates_directive():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	OtomoSeiyakuSystem.declare_formal_alliance(state, "Crab||Crane")
	assert_true(state["active_directives"]["Crab||Crane"]["escalated"])


func test_alliance_disposition_floor():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	OtomoSeiyakuSystem.declare_formal_alliance(state, "Crab||Crane")
	assert_eq(OtomoSeiyakuSystem.get_alliance_disposition_floor(state, "Crab||Crane"), 31)


func test_no_alliance_disposition_floor():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	assert_eq(OtomoSeiyakuSystem.get_alliance_disposition_floor(state, "Crab||Crane"), -100)


func test_dissolve_formal_alliance():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	OtomoSeiyakuSystem.declare_formal_alliance(state, "Crab||Crane")
	OtomoSeiyakuSystem.dissolve_formal_alliance(state, "Crab||Crane")
	assert_false(OtomoSeiyakuSystem.is_formal_alliance(state, "Crab||Crane"))


# -- Detection Tests -----------------------------------------------------------

func test_detection_success():
	assert_true(OtomoSeiyakuSystem.resolve_detection(25, 20))


func test_detection_failure():
	assert_false(OtomoSeiyakuSystem.resolve_detection(20, 25))


func test_detection_tie_fails():
	assert_false(OtomoSeiyakuSystem.resolve_detection(20, 20))


func test_apply_detection_halves_effectiveness():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["active_directives"]["Crab||Crane"] = OtomoSeiyakuSystem.create_directive(
		"Crab||Crane", 100, "Crab", "Crane",
	)
	var result: Dictionary = OtomoSeiyakuSystem.apply_detection(state, "Crab||Crane")
	assert_true(state["active_directives"]["Crab||Crane"]["effectiveness_halved"])
	assert_eq(result["sympathy_bonus"], 5)


func test_apply_detection_no_directive():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var result: Dictionary = OtomoSeiyakuSystem.apply_detection(state, "Crab||Crane")
	assert_eq(result.size(), 0)


# -- Seasonal Effect Tests ----------------------------------------------------

func test_estimate_effect_court_access():
	var d: Dictionary = OtomoSeiyakuSystem.create_directive("Crab||Crane", 1, "Crab", "Crane")
	var effect: int = OtomoSeiyakuSystem.estimate_seasonal_effect(d, true, 0, false)
	assert_eq(effect, OtomoSeiyakuSystem.COURT_EFFECT_MIN)


func test_estimate_effect_combined():
	var d: Dictionary = OtomoSeiyakuSystem.create_directive("Crab||Crane", 1, "Crab", "Crane")
	var effect: int = OtomoSeiyakuSystem.estimate_seasonal_effect(d, true, 1, true)
	assert_eq(effect, OtomoSeiyakuSystem.COURT_EFFECT_MIN + OtomoSeiyakuSystem.VISIT_EFFECT_MIN + OtomoSeiyakuSystem.LETTER_EFFECT_MIN)


func test_estimate_effect_halved():
	var d: Dictionary = OtomoSeiyakuSystem.create_directive("Crab||Crane", 1, "Crab", "Crane")
	d["effectiveness_halved"] = true
	var effect: int = OtomoSeiyakuSystem.estimate_seasonal_effect(d, true, 1, true)
	var raw: int = OtomoSeiyakuSystem.COURT_EFFECT_MIN + OtomoSeiyakuSystem.VISIT_EFFECT_MIN + OtomoSeiyakuSystem.LETTER_EFFECT_MIN
	assert_eq(effect, raw / 2)


func test_estimate_effect_clamped():
	var d: Dictionary = OtomoSeiyakuSystem.create_directive("Crab||Crane", 1, "Crab", "Crane")
	var effect: int = OtomoSeiyakuSystem.estimate_seasonal_effect(d, true, 10, true)
	assert_true(effect >= OtomoSeiyakuSystem.COMBINED_EFFECT_MAX)


# -- Operative Skill Bonus Tests -----------------------------------------------

func test_skill_bonus_assigned():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	state["assigned_operatives"][100] = "Crab||Crane"
	assert_eq(OtomoSeiyakuSystem.get_operative_skill_bonus(state, 100), 10)


func test_skill_bonus_unassigned():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	assert_eq(OtomoSeiyakuSystem.get_operative_skill_bonus(state, 100), 0)


# -- Seasonal Review Integration Tests ----------------------------------------

func test_process_seasonal_review_full():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var disps: Dictionary = {
		OtomoSeiyakuSystem.make_pair_key("Crab", "Crane"): 50,
		OtomoSeiyakuSystem.make_pair_key("Lion", "Dragon"): 30,
	}
	var ops: Array[int] = [100, 101, 102]
	var result: Dictionary = OtomoSeiyakuSystem.process_seasonal_review(
		state, disps, StrategicReview.EmperorArchetype.IRON, ops, 2,
	)
	assert_eq(result["threshold"], 45)
	assert_eq(result["alarms"].size(), 1)
	assert_eq(result["new_directives"].size(), 1)
	assert_eq(result["active_directive_count"], 1)


func test_seasonal_review_increments_seasons_active():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var pair: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	state["active_directives"][pair] = OtomoSeiyakuSystem.create_directive(
		pair, 100, "Crab", "Crane",
	)
	state["assigned_operatives"][100] = pair
	var disps: Dictionary = {pair: 50}
	var ops: Array[int] = [100, 101, 102]
	OtomoSeiyakuSystem.process_seasonal_review(
		state, disps, StrategicReview.EmperorArchetype.IRON, ops, 0,
	)
	assert_eq(state["active_directives"][pair]["seasons_active"], 1)


func test_seasonal_review_cancels_low_disp():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var pair: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	state["active_directives"][pair] = OtomoSeiyakuSystem.create_directive(
		pair, 100, "Crab", "Crane",
	)
	state["assigned_operatives"][100] = pair
	var disps: Dictionary = {pair: 20}
	var ops: Array[int] = [100, 101, 102]
	var result: Dictionary = OtomoSeiyakuSystem.process_seasonal_review(
		state, disps, StrategicReview.EmperorArchetype.IRON, ops, 0,
	)
	assert_eq(result["cancelled"].size(), 1)
	assert_eq(state["active_directives"].size(), 0)


func test_seasonal_review_uncovered_count():
	var state: Dictionary = OtomoSeiyakuSystem.make_initial_state()
	var k1: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	var k2: String = OtomoSeiyakuSystem.make_pair_key("Lion", "Dragon")
	var k3: String = OtomoSeiyakuSystem.make_pair_key("Phoenix", "Scorpion")
	var k4: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Lion")
	var disps: Dictionary = {k1: 50, k2: 55, k3: 60, k4: 48}
	var ops: Array[int] = [100, 101, 102]
	var result: Dictionary = OtomoSeiyakuSystem.process_seasonal_review(
		state, disps, StrategicReview.EmperorArchetype.IRON, ops, 0,
	)
	assert_eq(result["new_directives"].size(), 3)
	assert_eq(result["uncovered_alarm_count"], 1)


# -- DayOrchestrator Wiring Helpers -------------------------------------------

func test_build_champion_dispositions():
	var champ_crab := _make_champion(1, "Crab")
	var champ_crane := _make_champion(2, "Crane")
	champ_crab.disposition_values[2] = 40
	champ_crane.disposition_values[1] = 60
	var chars: Array[L5RCharacterData] = [champ_crab, champ_crane]
	var by_id: Dictionary = {1: champ_crab, 2: champ_crane}
	var disps: Dictionary = DayOrchestrator._build_champion_dispositions(chars, by_id)
	var key: String = OtomoSeiyakuSystem.make_pair_key("Crab", "Crane")
	assert_true(disps.has(key))
	assert_eq(disps[key], 50)


func test_build_champion_dispositions_skips_dead():
	var champ_crab := _make_champion(1, "Crab")
	var champ_crane := _make_champion(2, "Crane")
	champ_crane.wounds_taken = 999
	champ_crab.disposition_values[2] = 40
	var chars: Array[L5RCharacterData] = [champ_crab, champ_crane]
	var by_id: Dictionary = {1: champ_crab, 2: champ_crane}
	var disps: Dictionary = DayOrchestrator._build_champion_dispositions(chars, by_id)
	assert_eq(disps.size(), 0)


func test_build_champion_dispositions_skips_vassals():
	var champ_crab := _make_champion(1, "Crab")
	var vassal := _make_char(2, "Crane", "", 8.0)
	vassal.lord_id = 5
	champ_crab.disposition_values[2] = 40
	var chars: Array[L5RCharacterData] = [champ_crab, vassal]
	var by_id: Dictionary = {1: champ_crab, 2: vassal}
	var disps: Dictionary = DayOrchestrator._build_champion_dispositions(chars, by_id)
	assert_eq(disps.size(), 0)


func test_get_otomo_courtier_ids():
	var otomo1 := _make_otomo_courtier(10)
	var otomo2 := _make_otomo_courtier(11)
	var bushi := _make_char(12, "Imperial", "Otomo", 4.0)
	bushi.school_type = Enums.SchoolType.BUSHI
	var chars: Array[L5RCharacterData] = [otomo1, otomo2, bushi]
	var ids: Array[int] = DayOrchestrator._get_otomo_courtier_ids(chars)
	assert_eq(ids.size(), 2)
	assert_true(10 in ids)
	assert_true(11 in ids)


func test_get_otomo_courtier_ids_excludes_dead():
	var otomo := _make_otomo_courtier(10)
	otomo.wounds_taken = 999
	var chars: Array[L5RCharacterData] = [otomo]
	var ids: Array[int] = DayOrchestrator._get_otomo_courtier_ids(chars)
	assert_eq(ids.size(), 0)


# -- War Alliance Exemption ---------------------------------------------------

func test_allied_in_war_same_side():
	var wars: Array = [{
		"clan_a": "Crab", "clan_b": "Scorpion",
		"allied_clans_a": ["Crane"], "allied_clans_b": [],
	}]
	assert_true(OtomoSeiyakuSystem._are_clans_allied_in_war("Crab", "Crane", wars))


func test_not_allied_different_sides():
	var wars: Array = [{
		"clan_a": "Crab", "clan_b": "Scorpion",
		"allied_clans_a": ["Crane"], "allied_clans_b": ["Lion"],
	}]
	assert_false(OtomoSeiyakuSystem._are_clans_allied_in_war("Crane", "Lion", wars))


func test_not_allied_no_war():
	assert_false(OtomoSeiyakuSystem._are_clans_allied_in_war("Crab", "Crane", []))
