extends GutTest
## Tests for TogashiOversight per GDD s55.10.2.


var _state: Dictionary
var _fc: L5RCharacterData


func before_each() -> void:
	_state = TogashiOversight.make_initial_state()
	_fc = L5RCharacterData.new()
	_fc.character_id = 1
	_fc.character_name = "Mirumoto Hitomi"
	_fc.clan = "Dragon"
	_fc.family = "Mirumoto"
	_fc.bushido_virtue = Enums.BushidoVirtue.CHUGI
	_fc.shourido_virtue = Enums.ShouridoVirtue.NONE


# -- Initial state -----------------------------------------------------------

func test_initial_state_zero_dissatisfaction() -> void:
	for axis in [
		TogashiOversight.Axis.BALANCE_OF_POWER,
		TogashiOversight.Axis.IMPERIAL_COHESION,
		TogashiOversight.Axis.SPIRITUAL_HEALTH,
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT,
	]:
		assert_eq(float(_state["dissatisfaction"][axis]), 0.0)


func test_initial_state_no_active_directives() -> void:
	assert_eq(_state["active_forced_directives"].size(), 0)
	assert_eq(_state["defiance_count"], 0)
	assert_eq(_state["stage"], 0)
	assert_eq(_state["last_directive_axis"], -1)


# -- Concern checks ----------------------------------------------------------

func test_balance_concern_fires_when_dominant_clan_30_percent_ahead() -> void:
	var ws: Dictionary = {
		"clan_strengths": {"Lion": 130.0, "Crab": 100.0, "Crane": 90.0},
	}
	# Top=130, second=100, ratio=(30/100)=0.30. Strict > → false at exactly 30.
	# Need slightly more than 30%.
	assert_false(TogashiOversight.balance_concern_fires(ws))
	ws["clan_strengths"]["Lion"] = 131.0
	assert_true(TogashiOversight.balance_concern_fires(ws))


func test_balance_concern_no_fire_with_close_clans() -> void:
	var ws: Dictionary = {
		"clan_strengths": {"Lion": 100.0, "Crab": 95.0, "Crane": 90.0},
	}
	assert_false(TogashiOversight.balance_concern_fires(ws))


func test_balance_concern_handles_single_clan() -> void:
	var ws: Dictionary = {"clan_strengths": {"Lion": 100.0}}
	assert_false(TogashiOversight.balance_concern_fires(ws))


func test_imperial_cohesion_2_wars() -> void:
	var ws: Dictionary = {"active_inter_clan_wars": 2}
	assert_true(TogashiOversight.imperial_cohesion_concern_fires(ws))


func test_imperial_cohesion_emperor_vacant() -> void:
	var ws: Dictionary = {"emperor_vacant": true}
	assert_true(TogashiOversight.imperial_cohesion_concern_fires(ws))


func test_imperial_cohesion_rebellion() -> void:
	var ws: Dictionary = {"provinces_in_rebellion": 6}
	assert_true(TogashiOversight.imperial_cohesion_concern_fires(ws))
	ws["provinces_in_rebellion"] = 5
	assert_false(TogashiOversight.imperial_cohesion_concern_fires(ws))  # >5 strict


func test_imperial_cohesion_quiet() -> void:
	var ws: Dictionary = {"active_inter_clan_wars": 1}
	assert_false(TogashiOversight.imperial_cohesion_concern_fires(ws))


func test_spiritual_failing_worship() -> void:
	var ws: Dictionary = {"failing_worship_provinces": 10}
	assert_true(TogashiOversight.spiritual_health_concern_fires(ws))


func test_spiritual_dragon_realm_overlap() -> void:
	var ws: Dictionary = {"realm_overlap_in_dragon_territory": true}
	assert_true(TogashiOversight.spiritual_health_concern_fires(ws))


func test_spiritual_global_realm_overlaps() -> void:
	var ws: Dictionary = {"realm_overlaps_empire_wide": 3}
	assert_true(TogashiOversight.spiritual_health_concern_fires(ws))


func test_spiritual_high_ptl_outside_shadowlands() -> void:
	var ws: Dictionary = {"max_non_shadowlands_ptl": 4.0}
	assert_true(TogashiOversight.spiritual_health_concern_fires(ws))


func test_spiritual_quiet() -> void:
	var ws: Dictionary = {
		"failing_worship_provinces": 5,
		"realm_overlaps_empire_wide": 1,
		"max_non_shadowlands_ptl": 2.0,
	}
	assert_false(TogashiOversight.spiritual_health_concern_fires(ws))


func test_shadowlands_wall_breach() -> void:
	var ws: Dictionary = {"wall_breach_active": true}
	assert_true(TogashiOversight.shadowlands_concern_fires(ws))


func test_shadowlands_incursion_tier_2() -> void:
	var ws: Dictionary = {"shadowlands_incursion_tier": 2}
	assert_true(TogashiOversight.shadowlands_concern_fires(ws))


func test_shadowlands_low_crab_readiness() -> void:
	var ws: Dictionary = {"crab_military_readiness": 0.4}
	assert_true(TogashiOversight.shadowlands_concern_fires(ws))


func test_shadowlands_quiet() -> void:
	var ws: Dictionary = {
		"crab_military_readiness": 0.8,
		"shadowlands_incursion_tier": 1,
	}
	assert_false(TogashiOversight.shadowlands_concern_fires(ws))


# -- Tick decay / increment --------------------------------------------------

func test_no_concern_decays_dissatisfaction() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 30.0
	TogashiOversight.tick_oversight(_state, {}, [])
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		20.0,
	)


func test_decay_floors_at_zero() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 5.0
	TogashiOversight.tick_oversight(_state, {}, [])
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		0.0,
	)


func test_concern_aligned_decays_more_slowly() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT] = 30.0
	var ws: Dictionary = {"wall_breach_active": true}
	var aligned_directive: Array = [
		{"directive": StrategicReview.Directive.WAR_READINESS, "addresses_shadowlands": true}
	]
	TogashiOversight.tick_oversight(_state, ws, aligned_directive)
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT]),
		25.0,
	)


func test_concern_unaligned_increments() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 30.0
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	TogashiOversight.tick_oversight(_state, ws, [])
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		45.0,
	)


func test_threshold_triggers_intervention() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 40.0
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	var result: Dictionary = TogashiOversight.tick_oversight(_state, ws, [])
	assert_eq(int(result["primary_axis"]), TogashiOversight.Axis.SPIRITUAL_HEALTH)
	assert_almost_eq(float(result["primary_dissatisfaction"]), 55.0, 0.001)


func test_multi_axis_picks_highest_dissatisfaction() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 60.0
	_state["dissatisfaction"][TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT] = 70.0
	# Force both concerns active without alignment.
	var ws: Dictionary = {
		"realm_overlaps_empire_wide": 5,
		"wall_breach_active": true,
	}
	var result: Dictionary = TogashiOversight.tick_oversight(_state, ws, [])
	assert_eq(
		int(result["primary_axis"]),
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT,
	)
	assert_eq(result["axes_triggered"].size(), 2)


# -- Forced directive generation ---------------------------------------------

func test_forced_directive_carries_axis_and_flag() -> void:
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
	)
	assert_eq(int(d["axis"]), TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT)
	assert_true(d["forced_by_champion"])
	assert_true(d["addresses_shadowlands"])
	assert_false(d["addresses_spiritual"])


func test_spiritual_directive_addresses_spiritual() -> void:
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	assert_true(d["addresses_spiritual"])
	assert_false(d["addresses_shadowlands"])


# -- Compliance evaluation ---------------------------------------------------

func test_chugi_fc_complies_with_bare_directive() -> void:
	# Comply: 10 (Chugi). Defy: 0. Comply wins.
	_fc.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
	)
	var ev: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1)
	assert_true(ev["comply"])


func test_ishi_fc_defies_directive() -> void:
	# Comply: 0 (no Chugi/Rei, no disposition). Defy: 10 (Ishi). Defy wins.
	_fc.bushido_virtue = Enums.BushidoVirtue.NONE
	_fc.shourido_virtue = Enums.ShouridoVirtue.ISHI
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	var ev: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1)
	assert_false(ev["comply"])


func test_high_disposition_toward_togashi_tips_compliance() -> void:
	# Neutral virtues, but loves Togashi (+20 disposition).
	_fc.bushido_virtue = Enums.BushidoVirtue.NONE
	_fc.shourido_virtue = Enums.ShouridoVirtue.ISHI   # +10 defy
	_fc.disposition_values = {99: 30}                 # clamped to +20 comply
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.BALANCE_OF_POWER
	)
	var ev: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, 99)
	# Comply 20, Defy 10 — comply.
	assert_true(ev["comply"])
	assert_eq(int(ev["comply_score"]), 20)
	assert_eq(int(ev["defy_score"]), 10)


func test_repeated_letter_adds_meiyo_pressure() -> void:
	# Otherwise tied: Chugi (10 comply) vs Ketsui (8 defy) + conflict 4 = 12 defy.
	_fc.bushido_virtue = Enums.BushidoVirtue.CHUGI
	_fc.shourido_virtue = Enums.ShouridoVirtue.KETSUI
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	var first: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1, false, 4)
	assert_false(first["comply"])  # 10 < 12

	# Repeated: +5 Meiyo bonus → 15 vs 12. Comply.
	var second: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1, true, 4)
	assert_true(second["comply"])


func test_meiyo_fc_gets_extra_repeated_bonus() -> void:
	_fc.bushido_virtue = Enums.BushidoVirtue.MEIYO
	_fc.shourido_virtue = Enums.ShouridoVirtue.KETSUI
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	# First letter: 0 comply (no Chugi/Rei) vs 8 defy → defy.
	var first: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1)
	assert_false(first["comply"])
	# Second letter: 5 (repeated) + 5 (Meiyo bonus) = 10 vs 8 → comply.
	var second: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1, true)
	assert_true(second["comply"])


func test_conflict_modifier_increases_defiance() -> void:
	_fc.bushido_virtue = Enums.BushidoVirtue.CHUGI   # 10 comply
	var d: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	var no_conflict: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1, false, 0)
	assert_true(no_conflict["comply"])
	# 20 conflict overrides duty.
	var high_conflict: Dictionary = TogashiOversight.evaluate_compliance(_fc, d, -1, false, 20)
	assert_false(high_conflict["comply"])


# -- Defiance / stage transitions --------------------------------------------

func test_defiance_increments_count_and_stage() -> void:
	TogashiOversight.handle_defiance(_state, TogashiOversight.Axis.SPIRITUAL_HEALTH)
	assert_eq(_state["defiance_count"], 1)
	assert_eq(_state["stage"], 1)
	TogashiOversight.handle_defiance(_state, TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT)
	assert_eq(_state["defiance_count"], 2)
	assert_eq(_state["stage"], 2)


func test_stage_caps_at_4() -> void:
	for i in 6:
		TogashiOversight.handle_defiance(_state, TogashiOversight.Axis.SPIRITUAL_HEALTH)
	assert_eq(_state["stage"], 4)


func test_compliance_unwinds_stage_one_step() -> void:
	# Start at Stage 3 (3 defiances).
	for i in 3:
		TogashiOversight.handle_defiance(_state, TogashiOversight.Axis.SPIRITUAL_HEALTH)
	assert_eq(_state["stage"], 3)
	TogashiOversight.handle_compliance_response(
		_state, TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	assert_eq(_state["stage"], 2)
	# Dissatisfaction reset to 30 on the triggering axis.
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		30.0,
	)


func test_compliance_preserves_defiance_count() -> void:
	TogashiOversight.handle_defiance(_state, TogashiOversight.Axis.SPIRITUAL_HEALTH)
	assert_eq(_state["defiance_count"], 1)
	TogashiOversight.handle_compliance_response(
		_state, TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	assert_eq(_state["stage"], 0)
	assert_eq(_state["defiance_count"], 1)


# -- Authority lockout / Order withdrawal ------------------------------------

func test_authority_unlocked_at_stage_0_and_1() -> void:
	assert_false(TogashiOversight.is_authority_locked(_state))
	_state["stage"] = 1
	assert_false(TogashiOversight.is_authority_locked(_state))


func test_authority_locked_at_stage_2() -> void:
	_state["stage"] = 2
	assert_true(TogashiOversight.is_authority_locked(_state))


func test_order_withdrawn_at_stage_3() -> void:
	_state["stage"] = 2
	assert_false(TogashiOversight.is_order_withdrawn(_state))
	_state["stage"] = 3
	assert_true(TogashiOversight.is_order_withdrawn(_state))


func test_removal_triggered_at_stage_4() -> void:
	_state["stage"] = 3
	assert_false(TogashiOversight.is_removal_triggered(_state))
	_state["stage"] = 4
	assert_true(TogashiOversight.is_removal_triggered(_state))


func test_diplomatic_modifier_only_at_stage_2_plus() -> void:
	_state["stage"] = 1
	assert_eq(TogashiOversight.get_diplomatic_credibility_modifier(_state), 0)
	_state["stage"] = 2
	assert_eq(TogashiOversight.get_diplomatic_credibility_modifier(_state), -5)


# -- Forced directive lifecycle ----------------------------------------------

func test_forced_directive_added_replaces_same_axis() -> void:
	var d1: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
	)
	var d2: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
	)
	d2["description"] = "Updated"
	TogashiOversight.add_forced_directive(_state, d1)
	TogashiOversight.add_forced_directive(_state, d2)
	assert_eq(_state["active_forced_directives"].size(), 1)
	assert_eq(_state["active_forced_directives"][0]["description"], "Updated")


func test_lift_directive_when_dissatisfaction_drops() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT] = 15.0
	assert_true(
		TogashiOversight.should_lift_forced_directive(
			_state, TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
		)
	)


func test_no_lift_above_threshold() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT] = 25.0
	assert_false(
		TogashiOversight.should_lift_forced_directive(
			_state, TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
		)
	)


func test_remove_forced_directive_filters_correct_axis() -> void:
	var d_shadow: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
	)
	var d_spirit: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	TogashiOversight.add_forced_directive(_state, d_shadow)
	TogashiOversight.add_forced_directive(_state, d_spirit)
	TogashiOversight.remove_forced_directive(
		_state, TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT
	)
	assert_eq(_state["active_forced_directives"].size(), 1)
	assert_eq(
		int(_state["active_forced_directives"][0]["axis"]),
		TogashiOversight.Axis.SPIRITUAL_HEALTH,
	)


# -- High-level driver ------------------------------------------------------

func test_process_seasonal_oversight_no_intervention_when_calm() -> void:
	# All axes at 0, no concerns active.
	var result: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, {}, [], _fc, 99
	)
	assert_false(result["intervention_fired"])


func test_process_seasonal_oversight_fires_intervention_at_threshold() -> void:
	# Push spiritual axis just below threshold; concern active and unaligned.
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 40.0
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	# FC has Chugi → complies.
	var result: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, ws, [], _fc, 99
	)
	assert_true(result["intervention_fired"])
	assert_true(result["compliance"]["comply"])
	# Dissatisfaction reset to 30 after compliance.
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		30.0,
	)
	assert_eq(_state["active_forced_directives"].size(), 1)


func test_process_seasonal_oversight_defiance_increments_stage() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 40.0
	_fc.bushido_virtue = Enums.BushidoVirtue.NONE
	_fc.shourido_virtue = Enums.ShouridoVirtue.ISHI
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	var result: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, ws, [], _fc, 99
	)
	assert_true(result["intervention_fired"])
	assert_false(result["compliance"]["comply"])
	assert_eq(_state["defiance_count"], 1)
	assert_eq(_state["stage"], 1)


func test_process_seasonal_oversight_lifts_directive_when_concern_resolves() -> void:
	# Active forced directive on spiritual axis, dissatisfaction at 19 (below lift).
	var directive: Dictionary = TogashiOversight.generate_forced_directive(
		TogashiOversight.Axis.SPIRITUAL_HEALTH
	)
	TogashiOversight.add_forced_directive(_state, directive)
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 19.0
	# Calm world → no concern → decay → 9 → still below lift.
	TogashiOversight.process_seasonal_oversight(_state, {}, [], _fc, 99)
	assert_eq(_state["active_forced_directives"].size(), 0)


# -- Initialize from world state ---------------------------------------------

func test_initialize_from_world_state_seeds_nonzero_dissatisfaction() -> void:
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	TogashiOversight.initialize_from_world_state(_state, ws)
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		25.0,
	)


func test_initialize_from_world_state_calm_stays_zero() -> void:
	TogashiOversight.initialize_from_world_state(_state, {})
	assert_eq(
		float(_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH]),
		0.0,
	)


# -- Repeated letter in process_seasonal_oversight ---------------------------

func test_repeated_letter_detected_when_directive_exists_on_axis() -> void:
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 60.0
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	# First intervention — creates a directive on SPIRITUAL_HEALTH.
	var r1: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, ws, [], _fc, 99
	)
	assert_true(r1["intervention_fired"])
	# Second call — same axis has an active directive, so repeated_letter = true.
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 60.0
	var r2: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, ws, [], _fc, 99
	)
	assert_true(r2["intervention_fired"])


# -- High House assault (s55.10.2.8) -----------------------------------------

func test_assault_high_house_sets_vanished_and_dissolves_order() -> void:
	var togashi: L5RCharacterData = L5RCharacterData.new()
	togashi.character_id = 99
	togashi.physical_location = "high_house_settlement_1"
	togashi.is_kami = true

	var result: Dictionary = TogashiOversight.assault_high_house(
		_state, togashi, 1001, 300
	)

	assert_true(_state["togashi_vanished"])
	assert_true(_state["order_dissolved_by_assault"])
	assert_eq(togashi.physical_location, "")
	assert_almost_eq(float(result["honor_change"]), -2.0, 0.001)
	assert_eq(int(result["empire_disposition_change"]), -20)
	assert_true(result["togashi_vanished"])
	assert_true(result["topic"] is TopicData)
	assert_eq(result["topic"].tier, TopicData.Tier.TIER_1)
	assert_eq(int(result["topic"].topic_id), 1001)


func test_assault_high_house_null_togashi_still_sets_state() -> void:
	var result: Dictionary = TogashiOversight.assault_high_house(
		_state, null, 1002, 300
	)
	assert_true(_state["togashi_vanished"])
	assert_true(result.has("topic"))


func test_is_togashi_off_map_reflects_vanished_flag() -> void:
	assert_false(TogashiOversight.is_togashi_off_map(_state))
	_state["togashi_vanished"] = true
	assert_true(TogashiOversight.is_togashi_off_map(_state))


func test_oversight_skipped_when_togashi_vanished() -> void:
	_state["togashi_vanished"] = true
	_state["dissatisfaction"][TogashiOversight.Axis.SPIRITUAL_HEALTH] = 60.0
	var ws: Dictionary = {"realm_overlaps_empire_wide": 5}
	var result: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, ws, [], _fc, 99
	)
	assert_false(result["intervention_fired"])
	assert_true(result.get("skipped", false))


func test_oversight_skipped_when_dragon_autonomous_rule() -> void:
	_state["dragon_autonomous_rule"] = true
	_state["dissatisfaction"][TogashiOversight.Axis.IMPERIAL_COHESION] = 60.0
	var ws: Dictionary = {"active_inter_clan_wars": 2}
	var result: Dictionary = TogashiOversight.process_seasonal_oversight(
		_state, ws, [], _fc, 99
	)
	assert_false(result["intervention_fired"])
	assert_true(result.get("skipped", false))


# -- Togashi reappearance (s55.10.2.8) ----------------------------------------

func test_reappear_togashi_finds_dragon_temple_first() -> void:
	var togashi: L5RCharacterData = L5RCharacterData.new()
	togashi.character_id = 99
	togashi.physical_location = ""
	_state["togashi_vanished"] = true

	# Build a Dragon temple settlement and province.
	var dragon_prov: ProvinceData = ProvinceData.new()
	dragon_prov.province_id = 1
	dragon_prov.clan = "Dragon"

	var temple_s: SettlementData = SettlementData.new()
	temple_s.settlement_id = 501
	temple_s.province_id = 1
	temple_s.settlement_type = Enums.SettlementType.TEMPLE

	var provinces: Dictionary = {1: dragon_prov}
	var settlements: Array = [temple_s]

	var result: Dictionary = TogashiOversight.reappear_togashi(
		_state, togashi, settlements, provinces, {}
	)

	assert_true(result["reappeared"])
	assert_eq(int(result["settlement_id"]), 501)
	assert_eq(togashi.physical_location, "501")
	assert_false(_state["togashi_vanished"])
	assert_false(_state["dragon_autonomous_rule"])
	assert_eq(_state["order_reconstitution_seasons_remaining"], 4)


func test_reappear_togashi_falls_back_to_non_dragon_temple() -> void:
	var togashi: L5RCharacterData = L5RCharacterData.new()
	togashi.character_id = 99
	_state["togashi_vanished"] = true

	var lion_prov: ProvinceData = ProvinceData.new()
	lion_prov.province_id = 2
	lion_prov.clan = "Lion"

	var temple_s: SettlementData = SettlementData.new()
	temple_s.settlement_id = 502
	temple_s.province_id = 2
	temple_s.settlement_type = Enums.SettlementType.SHINDEN

	var provinces: Dictionary = {2: lion_prov}
	var result: Dictionary = TogashiOversight.reappear_togashi(
		_state, togashi, [temple_s], provinces, {}
	)

	assert_true(result["reappeared"])
	assert_eq(int(result["settlement_id"]), 502)


func test_reappear_togashi_fails_with_no_temples() -> void:
	var togashi: L5RCharacterData = L5RCharacterData.new()
	togashi.character_id = 99
	_state["togashi_vanished"] = true

	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = 3
	prov.clan = "Crab"

	var village: SettlementData = SettlementData.new()
	village.settlement_id = 503
	village.province_id = 3
	village.settlement_type = Enums.SettlementType.VILLAGE

	var result: Dictionary = TogashiOversight.reappear_togashi(
		_state, togashi, [village], {3: prov}, {}
	)

	assert_false(result["reappeared"])
	assert_eq(int(result["settlement_id"]), -1)


func test_reappear_togashi_null_returns_false() -> void:
	var result: Dictionary = TogashiOversight.reappear_togashi(
		_state, null, [], {}, {}
	)
	assert_false(result["reappeared"])


# -- Order reconstitution tick ------------------------------------------------

func test_order_reconstitution_counts_down() -> void:
	_state["order_reconstitution_seasons_remaining"] = 4
	_state["togashi_vanished"] = false
	var done_1: bool = TogashiOversight.tick_order_reconstitution(_state)
	assert_false(done_1)
	assert_eq(_state["order_reconstitution_seasons_remaining"], 3)


func test_order_reconstitution_completes_at_zero() -> void:
	_state["order_reconstitution_seasons_remaining"] = 1
	_state["togashi_vanished"] = false
	var done: bool = TogashiOversight.tick_order_reconstitution(_state)
	assert_true(done)
	assert_eq(_state["order_reconstitution_seasons_remaining"], 0)


func test_order_reconstitution_no_tick_when_already_done() -> void:
	_state["order_reconstitution_seasons_remaining"] = 0
	_state["togashi_vanished"] = false
	var done: bool = TogashiOversight.tick_order_reconstitution(_state)
	assert_true(done)
	assert_eq(_state["order_reconstitution_seasons_remaining"], 0)


# -- Pyrrhic victory ----------------------------------------------------------

func test_order_dissolved_permanently_requires_both_flags() -> void:
	_state["dragon_autonomous_rule"] = false
	_state["order_dissolved_by_assault"] = false
	assert_false(TogashiOversight.is_order_dissolved_permanently(_state))

	_state["dragon_autonomous_rule"] = true
	assert_false(TogashiOversight.is_order_dissolved_permanently(_state))

	_state["order_dissolved_by_assault"] = true
	assert_true(TogashiOversight.is_order_dissolved_permanently(_state))


func test_order_dissolved_by_assault_flag_readable() -> void:
	assert_false(TogashiOversight.is_order_dissolved_by_assault(_state))
	_state["order_dissolved_by_assault"] = true
	assert_true(TogashiOversight.is_order_dissolved_by_assault(_state))


# -- is_kami field on L5RCharacterData ---------------------------------------

func test_togashi_is_kami_flag_defaults_false() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	assert_false(c.is_kami)


func test_togashi_is_kami_flag_settable() -> void:
	var togashi: L5RCharacterData = L5RCharacterData.new()
	togashi.is_kami = true
	assert_true(togashi.is_kami)


# =============================================================================
# ASSAULT HIGH HOUSE: FC ID STORED (wiring)
# =============================================================================

func test_assault_high_house_stores_fc_id() -> void:
	var result: Dictionary = TogashiOversight.assault_high_house(_state, null, 1001, 300, 42)
	assert_eq(int(_state.get("last_assaulter_fc_id", -1)), 42)


func test_assault_high_house_fc_id_defaults_to_minus_one() -> void:
	TogashiOversight.assault_high_house(_state, null, 1001, 300)
	assert_eq(int(_state.get("last_assaulter_fc_id", -1)), -1)


# =============================================================================
# _check_dragon_schism_siege_events (DayOrchestrator wiring)
# =============================================================================

func _make_high_house_settlement(id: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_name = "High House of Light"
	s.settlement_type = Enums.SettlementType.CASTLE
	return s


func _make_dragon_siege_result(settlement_id: int, resolved: String, attacker_clan: String) -> Dictionary:
	return {
		"settlement_id": settlement_id,
		"resolved": resolved,
		"attacker_clan": attacker_clan,
		"defender_clan": "Dragon" if attacker_clan != "Dragon" else "Crane",
	}


func _make_dragon_fc(id: int) -> L5RCharacterData:
	var fc := L5RCharacterData.new()
	fc.character_id = id
	fc.character_name = "Mirumoto Dairuko"
	fc.clan = "Dragon"
	fc.family = "Mirumoto"
	fc.status = 6.0
	fc.lord_id = -1
	fc.honor = 5.0
	fc.wounds_taken = 0
	fc.stamina = 3
	fc.willpower = 3
	fc.void_ring = 2
	return fc


func test_check_dragon_schism_fires_on_high_house_capture():
	var fc: L5RCharacterData = _make_dragon_fc(10)
	var high_house: SettlementData = _make_high_house_settlement(99)
	var military_daily: Dictionary = {
		"siege_results": [_make_dragon_siege_result(99, "attacker_victory", "Dragon")],
	}
	var topics: Array[TopicData] = []
	var next_tid: Array[int] = [1000]

	var result: Dictionary = DayOrchestrator._check_dragon_schism_siege_events(
		military_daily, _state, [fc], {10: fc}, [high_house], topics, next_tid, 300
	)

	assert_true(result.get("togashi_vanished", false))
	assert_true(_state.get("togashi_vanished", false))
	assert_eq(int(_state.get("last_assaulter_fc_id", -1)), 10)
	assert_eq(topics.size(), 1)
	assert_true(fc.honor < 5.0)


func test_check_dragon_schism_no_fire_on_non_dragon_attacker():
	var military_daily: Dictionary = {
		"siege_results": [_make_dragon_siege_result(99, "attacker_victory", "Crane")],
	}
	var high_house: SettlementData = _make_high_house_settlement(99)
	var result: Dictionary = DayOrchestrator._check_dragon_schism_siege_events(
		military_daily, _state, [], {}, [high_house], [], [1000], 300
	)
	assert_true(result.is_empty())
	assert_false(_state.get("togashi_vanished", false))


func test_check_dragon_schism_no_fire_on_wrong_settlement():
	var fc: L5RCharacterData = _make_dragon_fc(10)
	var other_castle := SettlementData.new()
	other_castle.settlement_id = 99
	other_castle.settlement_name = "Some Other Castle"
	var military_daily: Dictionary = {
		"siege_results": [_make_dragon_siege_result(99, "attacker_victory", "Dragon")],
	}
	var result: Dictionary = DayOrchestrator._check_dragon_schism_siege_events(
		military_daily, _state, [fc], {10: fc}, [other_castle], [], [1000], 300
	)
	assert_true(result.is_empty())


func test_check_dragon_schism_no_fire_on_defender_victory():
	var fc: L5RCharacterData = _make_dragon_fc(10)
	var high_house: SettlementData = _make_high_house_settlement(99)
	var military_daily: Dictionary = {
		"siege_results": [_make_dragon_siege_result(99, "defender_victory", "Dragon")],
	}
	var result: Dictionary = DayOrchestrator._check_dragon_schism_siege_events(
		military_daily, _state, [fc], {10: fc}, [high_house], [], [1000], 300
	)
	assert_true(result.is_empty())


# =============================================================================
# ORDER RECONSTITUTION (tick_order_reconstitution)
# =============================================================================

func test_tick_order_reconstitution_decrements_counter():
	_state["order_reconstitution_seasons_remaining"] = 3
	TogashiOversight.tick_order_reconstitution(_state)
	assert_eq(int(_state["order_reconstitution_seasons_remaining"]), 2)


func test_tick_order_reconstitution_returns_true_on_completion():
	_state["order_reconstitution_seasons_remaining"] = 1
	var done: bool = TogashiOversight.tick_order_reconstitution(_state)
	assert_true(done)
	assert_eq(int(_state["order_reconstitution_seasons_remaining"]), 0)


func test_tick_order_reconstitution_no_op_at_zero():
	_state["order_reconstitution_seasons_remaining"] = 0
	var done: bool = TogashiOversight.tick_order_reconstitution(_state)
	# Returns false when already zero and not yet reappeared.
	assert_false(done)
