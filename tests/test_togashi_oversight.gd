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
