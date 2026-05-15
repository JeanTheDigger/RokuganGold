extends GutTest
## Tests for IntraClanCivilWar per GDD s53.2.


var _state: Dictionary
var _rebel: L5RCharacterData
var _authority: L5RCharacterData


func before_each() -> void:
	_state = IntraClanCivilWar.make_initial_state(101, 1, "Lion", 5000, 100)
	_rebel = L5RCharacterData.new()
	_rebel.character_id = 101
	_rebel.character_name = "Matsu Tsuko"
	_rebel.clan = "Lion"
	_rebel.family = "Matsu"
	_rebel.honor = 5.0

	_authority = L5RCharacterData.new()
	_authority.character_id = 1
	_authority.character_name = "Akodo Toturi"
	_authority.clan = "Lion"
	_authority.family = "Akodo"
	_authority.honor = 7.0


func _make_npc(cid: int, virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE,
		shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
		disp_to_rebel: int = 0) -> L5RCharacterData:
	var n := L5RCharacterData.new()
	n.character_id = cid
	n.bushido_virtue = virtue
	n.shourido_virtue = shourido
	n.disposition_values = {101: disp_to_rebel}
	return n


# -- Initial state -----------------------------------------------------------

func test_initial_state_active_with_50_50_war_score() -> void:
	assert_true(_state["active"])
	assert_eq(_state["war_score"], 50)
	assert_eq(_state["season_resolved"], -1)
	assert_eq(_state["consecutive_rebel_victory_seasons"], 0)


func test_initial_state_records_metadata() -> void:
	assert_eq(_state["rebel_lord_id"], 101)
	assert_eq(_state["authority_lord_id"], 1)
	assert_eq(_state["clan"], "Lion")
	assert_eq(_state["trigger_topic_id"], 5000)
	assert_eq(_state["season_started"], 100)


# -- Per-NPC factor scoring --------------------------------------------------

func test_chugi_pull_max_for_chugi_virtue() -> void:
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.CHUGI)
	assert_eq(IntraClanCivilWar.compute_chugi_pull(n), 100)


func test_chugi_pull_baseline_for_no_virtue() -> void:
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.NONE)
	assert_eq(IntraClanCivilWar.compute_chugi_pull(n), 30)


func test_disposition_pull_normalized_zero_to_hundred() -> void:
	var loyal: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.NONE,
		Enums.ShouridoVirtue.NONE, 80)   # +80 disposition
	# (80 + 100) / 2 = 90.
	assert_eq(IntraClanCivilWar.compute_disposition_pull(loyal, 101), 90)
	var enemy: L5RCharacterData = _make_npc(3, Enums.BushidoVirtue.NONE,
		Enums.ShouridoVirtue.NONE, -100)
	assert_eq(IntraClanCivilWar.compute_disposition_pull(enemy, 101), 0)


func test_ambition_pull_max_for_ishi() -> void:
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.NONE,
		Enums.ShouridoVirtue.ISHI)
	assert_eq(IntraClanCivilWar.compute_ambition_pull(n), 100)


func test_competence_brackets() -> void:
	assert_eq(IntraClanCivilWar.competence_points(0.80),
		IntraClanCivilWar.COMPETENCE_PTS_STRONG)
	assert_eq(IntraClanCivilWar.competence_points(0.60),
		IntraClanCivilWar.COMPETENCE_PTS_MODERATE)
	assert_eq(IntraClanCivilWar.competence_points(0.30),
		IntraClanCivilWar.COMPETENCE_PTS_POOR)
	# Boundary at 0.75.
	assert_eq(IntraClanCivilWar.competence_points(0.75),
		IntraClanCivilWar.COMPETENCE_PTS_STRONG)
	# Boundary at 0.50.
	assert_eq(IntraClanCivilWar.competence_points(0.50),
		IntraClanCivilWar.COMPETENCE_PTS_MODERATE)


func test_grievance_no_info_defaults_safe() -> void:
	# Topic not in known_topics → 5/15 points toward Rebel (safe Legitimacy default).
	assert_eq(IntraClanCivilWar.grievance_points(false, false),
		IntraClanCivilWar.GRIEVANCE_PTS_NO_INFO)
	assert_eq(IntraClanCivilWar.grievance_points(false, true),
		IntraClanCivilWar.GRIEVANCE_PTS_NO_INFO)


func test_grievance_strong_when_no_visible_failure() -> void:
	assert_eq(IntraClanCivilWar.grievance_points(true, false),
		IntraClanCivilWar.GRIEVANCE_PTS_STRONG)


func test_grievance_weak_when_rebel_was_failing() -> void:
	assert_eq(IntraClanCivilWar.grievance_points(true, true),
		IntraClanCivilWar.GRIEVANCE_PTS_WEAK)


# -- Loyalty evaluation ------------------------------------------------------

func test_high_chugi_chooses_legitimacy() -> void:
	# Chugi virtue → 100 chugi pull → almost full legitimacy contribution.
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.CHUGI,
		Enums.ShouridoVirtue.NONE, 0)
	var ev: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false)
	assert_eq(ev["faction"], IntraClanCivilWar.Faction.LEGITIMACY)


func test_high_ishi_with_loyal_rebel_chooses_rebel() -> void:
	# Low chugi (no virtue) + high ambition (Ishi) + high disposition toward
	# rebel + strong competence → rebel score should clear 50.
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.NONE,
		Enums.ShouridoVirtue.ISHI, 80)
	var ev: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.80, true, false)
	assert_eq(ev["faction"], IntraClanCivilWar.Faction.REBEL)


func test_low_chugi_low_disposition_yields_ronin() -> void:
	# bushido=NONE → chugi pull 30 (< 40); disposition -50 → pull 25 (< 40).
	# Both sub-thresholds → Ronin.
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.NONE,
		Enums.ShouridoVirtue.NONE, -50)
	var ev: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false)
	assert_eq(ev["faction"], IntraClanCivilWar.Faction.RONIN)


func test_high_chugi_blocks_ronin_path() -> void:
	# Chugi virtue → chugi pull 100, even with negative disposition still not Ronin.
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.CHUGI,
		Enums.ShouridoVirtue.NONE, -50)
	var ev: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false)
	assert_eq(ev["faction"], IntraClanCivilWar.Faction.LEGITIMACY)


func test_high_disposition_blocks_ronin_path() -> void:
	# bushido=NONE → chugi pull 30, but disposition pull 90 → not Ronin.
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.NONE,
		Enums.ShouridoVirtue.NONE, 80)
	var ev: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false)
	assert_ne(ev["faction"], IntraClanCivilWar.Faction.RONIN)


func test_loyalty_includes_pull_diagnostics() -> void:
	var n: L5RCharacterData = _make_npc(2, Enums.BushidoVirtue.CHUGI,
		Enums.ShouridoVirtue.NONE, 0)
	var ev: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false)
	assert_true(ev.has("rebel_score"))
	assert_true(ev.has("chugi_pull"))
	assert_true(ev.has("disposition_pull"))


# -- Faction assignment ------------------------------------------------------

func test_assign_and_get_faction() -> void:
	IntraClanCivilWar.assign_faction(_state, 5, IntraClanCivilWar.Faction.LEGITIMACY)
	assert_eq(IntraClanCivilWar.get_faction(_state, 5),
		IntraClanCivilWar.Faction.LEGITIMACY)


func test_unassigned_character_returns_none() -> void:
	assert_eq(IntraClanCivilWar.get_faction(_state, 99),
		IntraClanCivilWar.Faction.NONE)


# -- Stability penalty escalation -------------------------------------------

func test_stability_penalty_base_under_8_seasons() -> void:
	assert_eq(IntraClanCivilWar.get_stability_penalty(0), -3)
	assert_eq(IntraClanCivilWar.get_stability_penalty(7), -3)


func test_stability_penalty_long_at_8_seasons() -> void:
	assert_eq(IntraClanCivilWar.get_stability_penalty(8), -5)
	assert_eq(IntraClanCivilWar.get_stability_penalty(11), -5)


func test_stability_penalty_grinding_at_12_seasons() -> void:
	assert_eq(IntraClanCivilWar.get_stability_penalty(12), -7)
	assert_eq(IntraClanCivilWar.get_stability_penalty(20), -7)


# -- Seasonal consequences ---------------------------------------------------

func test_apply_seasonal_consequences_bleeds_provinces_and_honor() -> void:
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = 10
	p1.stability = 80.0
	var p2: ProvinceData = ProvinceData.new()
	p2.province_id = 11
	p2.stability = 60.0
	var result: Dictionary = IntraClanCivilWar.apply_seasonal_consequences(
		_state, _rebel, [p1, p2], 101
	)
	assert_eq(result["penalty_applied"], -3)
	assert_eq(p1.stability, 77.0)
	assert_eq(p2.stability, 57.0)
	assert_almost_eq(_rebel.honor, 4.7, 0.001)


func test_seasonal_consequences_honor_floors_at_zero() -> void:
	_rebel.honor = 0.1
	IntraClanCivilWar.apply_seasonal_consequences(_state, _rebel, [], 101)
	assert_eq(_rebel.honor, 0.0)


func test_seasonal_consequences_suppress_hemorrhage_skips_honor_loss() -> void:
	# Council Overreach Path: no automatic honor hemorrhage (s55.10.3.7).
	_rebel.honor = 5.0
	var result: Dictionary = IntraClanCivilWar.apply_seasonal_consequences(
		_state, _rebel, [], 101, true
	)
	assert_almost_eq(_rebel.honor, 5.0, 0.001)
	assert_true(result["hemorrhage_suppressed"])


func test_seasonal_consequences_suppress_false_still_bleeds() -> void:
	_rebel.honor = 5.0
	var result: Dictionary = IntraClanCivilWar.apply_seasonal_consequences(
		_state, _rebel, [], 101, false
	)
	assert_almost_eq(_rebel.honor, 4.7, 0.001)
	assert_false(result["hemorrhage_suppressed"])


func test_get_dragon_treaty_penalty_active_war() -> void:
	var dragon_state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Dragon", 1, 0)
	dragon_state["dragon_treaty_penalty"] = -15
	assert_eq(IntraClanCivilWar.get_dragon_treaty_penalty([dragon_state]), -15)


func test_get_dragon_treaty_penalty_no_dragon_war() -> void:
	var lion_state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Lion", 1, 0)
	assert_eq(IntraClanCivilWar.get_dragon_treaty_penalty([lion_state]), 0)


func test_get_dragon_treaty_penalty_inactive_war_ignored() -> void:
	var dragon_state: Dictionary = IntraClanCivilWar.make_initial_state(10, 20, "Dragon", 1, 0)
	dragon_state["dragon_treaty_penalty"] = -15
	dragon_state["active"] = false
	assert_eq(IntraClanCivilWar.get_dragon_treaty_penalty([dragon_state]), 0)


func test_seasonal_consequences_uses_correct_escalation() -> void:
	var p1: ProvinceData = ProvinceData.new()
	p1.province_id = 10
	p1.stability = 100.0
	# 8 seasons elapsed (started at 100, current 108).
	IntraClanCivilWar.apply_seasonal_consequences(_state, _rebel, [p1], 108)
	assert_eq(p1.stability, 95.0)  # -5


# -- War Score shifts -------------------------------------------------------

func test_shift_war_score_clamps() -> void:
	IntraClanCivilWar.shift_war_score(_state, 60)
	assert_eq(_state["war_score"], 100)
	IntraClanCivilWar.shift_war_score(_state, -200)
	assert_eq(_state["war_score"], 0)


func test_record_defection_family_daimyo_to_legitimacy() -> void:
	_state["faction_assignments"][50] = IntraClanCivilWar.Faction.REBEL
	var ws: int = IntraClanCivilWar.record_defection(_state, 50, true, true)
	assert_eq(ws, 62)  # 50 + 12
	assert_eq(IntraClanCivilWar.get_faction(_state, 50),
		IntraClanCivilWar.Faction.LEGITIMACY)


func test_record_defection_provincial_daimyo_to_rebel() -> void:
	_state["faction_assignments"][51] = IntraClanCivilWar.Faction.LEGITIMACY
	var ws: int = IntraClanCivilWar.record_defection(_state, 51, false, false)
	assert_eq(ws, 45)  # 50 - 5
	assert_eq(IntraClanCivilWar.get_faction(_state, 51),
		IntraClanCivilWar.Faction.REBEL)


func test_record_rebel_disgrace_swings_war_score() -> void:
	IntraClanCivilWar.record_rebel_disgrace(_state)
	assert_eq(_state["war_score"], 65)


func test_imperial_edict_against_rebel() -> void:
	IntraClanCivilWar.record_imperial_edict(_state, true)
	assert_eq(_state["war_score"], 60)
	IntraClanCivilWar.record_imperial_edict(_state, false)
	assert_eq(_state["war_score"], 50)


func test_foreign_intervention_for_legitimacy() -> void:
	IntraClanCivilWar.record_foreign_intervention(_state, true)
	assert_eq(_state["war_score"], 58)


# -- Resolution: Legitimacy victory -----------------------------------------

func test_legitimacy_victory_on_capitulation() -> void:
	assert_true(IntraClanCivilWar.check_legitimacy_victory(_state, _rebel, true, false))


func test_legitimacy_victory_on_disgrace() -> void:
	# Honor strictly below 0 → disgrace per s4.6 / s53.2.7. The L5RCharacterData
	# field has no enforced clamp, so we set it directly for this test.
	_rebel.honor = -0.5
	assert_true(IntraClanCivilWar.check_legitimacy_victory(_state, _rebel))


func test_no_legitimacy_victory_at_honor_exactly_zero() -> void:
	# 0.0 is the boundary; strict < 0 means 0.0 is NOT disgrace yet.
	_rebel.honor = 0.0
	assert_false(IntraClanCivilWar.check_legitimacy_victory(_state, _rebel))


func test_legitimacy_victory_on_seat_lost() -> void:
	assert_true(IntraClanCivilWar.check_legitimacy_victory(_state, _rebel, false, true))


func test_legitimacy_victory_handles_null_rebel() -> void:
	assert_false(IntraClanCivilWar.check_legitimacy_victory(_state, null, true, false))


# -- Resolution: Rebel victory counter --------------------------------------

func test_rebel_victory_counter_increments_with_all_conditions() -> void:
	IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, true, true)
	assert_eq(_state["consecutive_rebel_victory_seasons"], 1)
	IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, true, true)
	assert_eq(_state["consecutive_rebel_victory_seasons"], 2)


func test_rebel_victory_counter_resets_on_honor_drop() -> void:
	_state["consecutive_rebel_victory_seasons"] = 4
	_rebel.honor = 0.5
	IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, true, true)
	assert_eq(_state["consecutive_rebel_victory_seasons"], 0)


func test_rebel_victory_counter_resets_on_seat_loss() -> void:
	_state["consecutive_rebel_victory_seasons"] = 3
	IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, false, true)
	assert_eq(_state["consecutive_rebel_victory_seasons"], 0)


func test_rebel_victory_counter_resets_on_no_allies() -> void:
	_state["consecutive_rebel_victory_seasons"] = 5
	IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, true, false)
	assert_eq(_state["consecutive_rebel_victory_seasons"], 0)


func test_rebel_victory_at_6_consecutive_seasons() -> void:
	for i in 6:
		IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, true, true)
	assert_true(IntraClanCivilWar.is_rebel_victory_achieved(_state))


func test_rebel_victory_not_achieved_at_5_seasons() -> void:
	for i in 5:
		IntraClanCivilWar.tick_rebel_victory_counter(_state, _rebel, true, true)
	assert_false(IntraClanCivilWar.is_rebel_victory_achieved(_state))


# -- Championship Seizure ---------------------------------------------------

func test_seizure_requires_war_score_90() -> void:
	_state["war_score"] = 11
	assert_false(IntraClanCivilWar.can_seize_championship(_state, "Lion", true, true))
	_state["war_score"] = 10
	assert_true(IntraClanCivilWar.can_seize_championship(_state, "Lion", true, true))


func test_seizure_requires_family_daimyo_rebel() -> void:
	_state["war_score"] = 5
	assert_false(IntraClanCivilWar.can_seize_championship(_state, "Lion", false, true))


func test_seizure_requires_incumbent_disgraced_or_dead() -> void:
	_state["war_score"] = 5
	assert_false(IntraClanCivilWar.can_seize_championship(_state, "Lion", true, false))


func test_seizure_forbidden_for_dragon() -> void:
	_state["war_score"] = 0
	assert_false(IntraClanCivilWar.can_seize_championship(_state, "Dragon", true, true))


func test_seizure_forbidden_for_phoenix() -> void:
	_state["war_score"] = 0
	assert_false(IntraClanCivilWar.can_seize_championship(_state, "Phoenix", true, true))


# -- Defection triggers (s53.2.8) -------------------------------------------

func test_defection_lord_killed_fires_trigger() -> void:
	var n: L5RCharacterData = _make_npc(50)
	IntraClanCivilWar.assign_faction(_state, 50, IntraClanCivilWar.Faction.REBEL)
	assert_true(IntraClanCivilWar.defection_trigger_fired(_state, n, 101, true, false))


func test_defection_imperial_edict_fires() -> void:
	var n: L5RCharacterData = _make_npc(50)
	assert_true(IntraClanCivilWar.defection_trigger_fired(_state, n, 101, false, true))


func test_defection_war_score_desperate_legitimacy() -> void:
	var n: L5RCharacterData = _make_npc(50)
	IntraClanCivilWar.assign_faction(_state, 50, IntraClanCivilWar.Faction.LEGITIMACY)
	_state["war_score"] = 20  # Legitimacy desperate
	assert_true(IntraClanCivilWar.defection_trigger_fired(_state, n, 1))


func test_defection_war_score_desperate_rebel() -> void:
	var n: L5RCharacterData = _make_npc(50)
	IntraClanCivilWar.assign_faction(_state, 50, IntraClanCivilWar.Faction.REBEL)
	_state["war_score"] = 80  # Rebel desperate (100-80=20 < 25)
	assert_true(IntraClanCivilWar.defection_trigger_fired(_state, n, 101))


func test_defection_disposition_enemy_fires() -> void:
	var n: L5RCharacterData = _make_npc(50)
	n.disposition_values = {1: -25}  # Below -20 toward leader
	IntraClanCivilWar.assign_faction(_state, 50, IntraClanCivilWar.Faction.LEGITIMACY)
	assert_true(IntraClanCivilWar.defection_trigger_fired(_state, n, 1))


func test_defection_no_trigger_in_normal_state() -> void:
	var n: L5RCharacterData = _make_npc(50)
	n.disposition_values = {1: 30}
	IntraClanCivilWar.assign_faction(_state, 50, IntraClanCivilWar.Faction.LEGITIMACY)
	assert_false(IntraClanCivilWar.defection_trigger_fired(_state, n, 1))


# -- Defection consequences -------------------------------------------------

func test_defection_costs_half_honor() -> void:
	var defector: L5RCharacterData = _make_npc(50)
	defector.honor = 4.0
	IntraClanCivilWar.apply_defection_consequences(defector, [])
	assert_almost_eq(defector.honor, 3.5, 0.001)


func test_defection_creates_disposition_penalty_among_former_allies() -> void:
	var defector: L5RCharacterData = _make_npc(50)
	var ally1: L5RCharacterData = _make_npc(60)
	ally1.disposition_values = {50: 20}
	var ally2: L5RCharacterData = _make_npc(61)
	ally2.disposition_values = {}
	IntraClanCivilWar.apply_defection_consequences(defector, [ally1, ally2])
	assert_eq(int(ally1.disposition_values[50]), 5)   # 20 - 15
	assert_eq(int(ally2.disposition_values[50]), -15) # 0 - 15


# -- Precedent Effect (s53.2.10) -------------------------------------------

func test_precedent_standard_victory_adds_3() -> void:
	var mods: Dictionary = {}
	IntraClanCivilWar.apply_precedent_effect(mods, 200, false)
	assert_eq(mods.size(), 1)
	assert_eq(IntraClanCivilWar.get_active_precedent_bonus(mods), 3)


func test_precedent_seizure_adds_5() -> void:
	var mods: Dictionary = {}
	IntraClanCivilWar.apply_precedent_effect(mods, 200, true)
	assert_eq(IntraClanCivilWar.get_active_precedent_bonus(mods), 5)


func test_precedent_modifiers_stack() -> void:
	var mods: Dictionary = {}
	IntraClanCivilWar.apply_precedent_effect(mods, 200, false)
	IntraClanCivilWar.apply_precedent_effect(mods, 201, true)
	assert_eq(IntraClanCivilWar.get_active_precedent_bonus(mods), 8)


func test_precedent_decays_after_5_seasons() -> void:
	var mods: Dictionary = {}
	IntraClanCivilWar.apply_precedent_effect(mods, 200, false)
	# At season 204, mod expires at 200 + 5 = 205. Still active.
	IntraClanCivilWar.tick_precedent_decay(mods, 204)
	assert_eq(mods.size(), 1)
	# At season 205, expires.
	var removed: int = IntraClanCivilWar.tick_precedent_decay(mods, 205)
	assert_eq(removed, 1)
	assert_eq(mods.size(), 0)


# -- Finalisation ------------------------------------------------------------

func test_finalise_marks_resolved() -> void:
	IntraClanCivilWar.finalise(_state, 200, true)
	assert_false(_state["active"])
	assert_eq(_state["season_resolved"], 200)
	assert_true(_state["legitimacy_victory"])
	assert_false(_state["rebel_victory"])


# -- Ronin departure --------------------------------------------------------

func test_ronin_departure_costs_honor() -> void:
	var n: L5RCharacterData = _make_npc(50)
	n.honor = 3.0
	IntraClanCivilWar.apply_ronin_departure(n)
	assert_eq(n.honor, 2.0)


func test_ronin_departure_honor_floors_at_zero() -> void:
	var n: L5RCharacterData = _make_npc(50)
	n.honor = 0.5
	IntraClanCivilWar.apply_ronin_departure(n)
	assert_eq(n.honor, 0.0)


# -- Post-resolution consequences -------------------------------------------

func test_post_resolution_scars_between_opposite_factions() -> void:
	var a: L5RCharacterData = _make_npc(10)
	var b: L5RCharacterData = _make_npc(20)
	IntraClanCivilWar.assign_faction(_state, 10, IntraClanCivilWar.Faction.LEGITIMACY)
	IntraClanCivilWar.assign_faction(_state, 20, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.apply_post_resolution_scars(_state, [a, b])
	assert_eq(int(a.disposition_values.get(20, 0)), -10)
	assert_eq(int(b.disposition_values.get(10, 0)), -10)


func test_post_resolution_scars_skip_same_faction() -> void:
	var a: L5RCharacterData = _make_npc(10)
	var b: L5RCharacterData = _make_npc(20)
	IntraClanCivilWar.assign_faction(_state, 10, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.assign_faction(_state, 20, IntraClanCivilWar.Faction.REBEL)
	IntraClanCivilWar.apply_post_resolution_scars(_state, [a, b])
	assert_eq(int(a.disposition_values.get(20, 0)), 0)


func test_post_resolution_family_death_adds_extra_scar() -> void:
	var a: L5RCharacterData = _make_npc(10)
	var b: L5RCharacterData = _make_npc(20)
	IntraClanCivilWar.assign_faction(_state, 10, IntraClanCivilWar.Faction.LEGITIMACY)
	IntraClanCivilWar.assign_faction(_state, 20, IntraClanCivilWar.Faction.REBEL)
	var deaths: Dictionary = {10: [20]}
	IntraClanCivilWar.apply_post_resolution_scars(_state, [a, b], deaths)
	# a lost family member b: -10 + -15 = -25
	assert_eq(int(a.disposition_values.get(20, 0)), -25)
	# b did not lose family member a: -10 only
	assert_eq(int(b.disposition_values.get(10, 0)), -10)


func test_rebel_consequences_family_daimyo() -> void:
	var fd: L5RCharacterData = _make_npc(30)
	fd.status = 6.0
	var result: Dictionary = IntraClanCivilWar.apply_rebel_consequences_on_legitimacy_victory(
		[fd], [30]
	)
	assert_eq(fd.honor, 2.5)  # default 3.5 - 1.0
	assert_eq(result["rebel_consequences"].size(), 1)
	assert_eq(result["rebel_consequences"][0]["consequence"], "removal")


func test_rebel_consequences_provincial_daimyo() -> void:
	var pd: L5RCharacterData = _make_npc(40)
	pd.status = 5.0
	var result: Dictionary = IntraClanCivilWar.apply_rebel_consequences_on_legitimacy_victory(
		[pd], []
	)
	assert_eq(pd.honor, 3.0)  # default 3.5 - 0.5
	assert_eq(result["rebel_consequences"][0]["consequence"], "reassignment")


func test_rebel_consequences_rank_and_file_no_penalty() -> void:
	var rf: L5RCharacterData = _make_npc(50)
	rf.status = 2.0
	var result: Dictionary = IntraClanCivilWar.apply_rebel_consequences_on_legitimacy_victory(
		[rf], []
	)
	assert_eq(rf.honor, 3.5)  # unchanged
	assert_eq(result["rebel_consequences"].size(), 0)


# =============================================================================
# PHOENIX AMBIGUOUS LEGITIMACY (s55.10.3.7)
# =============================================================================

func test_phoenix_chugi_favors_council():
	# Chugi-dominant: the compact is duty → 0 rebel contribution from belief factor.
	var n: L5RCharacterData = _make_npc(10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE, 0)
	# Use is_phoenix_schism=true. Rebel lord 101, low completion, no disp pull.
	var result: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.3, true, false, true)
	# Chugi belief = 0 → less rebel contribution vs standard path.
	assert_eq(result.get("faction", IntraClanCivilWar.Faction.LEGITIMACY), IntraClanCivilWar.Faction.LEGITIMACY)


func test_phoenix_meiyo_favors_champion():
	# Meiyo-dominant: divine mandate → full rebel contribution from belief factor.
	var n: L5RCharacterData = _make_npc(10, Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE, 80)
	n.shourido_virtue = Enums.ShouridoVirtue.NONE
	var result: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.8, true, false, true)
	assert_eq(result.get("faction", IntraClanCivilWar.Faction.LEGITIMACY), IntraClanCivilWar.Faction.REBEL)


func test_phoenix_gi_rebel_failing_weakens_rebel_belief():
	# Gi: "honest side wins." Council (rebel_lord) was failing → weaker rebel support.
	var gi: L5RCharacterData = _make_npc(10, Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.NONE, 0)
	var result_failing: Dictionary = IntraClanCivilWar.evaluate_loyalty(gi, 101, 0.3, true, true, true)
	var result_strong: Dictionary = IntraClanCivilWar.evaluate_loyalty(gi, 101, 0.9, true, false, true)
	assert_true(int(result_strong.get("rebel_score", 0)) > int(result_failing.get("rebel_score", 0)))


func test_phoenix_seigyo_follows_disposition():
	# Seigyo: self-interest. High disposition → believes rebel is right.
	var seigyo_friend: L5RCharacterData = _make_npc(10, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO, 80)
	var seigyo_foe: L5RCharacterData = _make_npc(11, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO, 10)
	var r_friend: Dictionary = IntraClanCivilWar.evaluate_loyalty(seigyo_friend, 101, 0.5, true, false, true)
	var r_foe: Dictionary = IntraClanCivilWar.evaluate_loyalty(seigyo_foe, 101, 0.5, true, false, true)
	assert_true(int(r_friend.get("rebel_score", 0)) > int(r_foe.get("rebel_score", 0)))


func test_phoenix_path_default_is_no_info():
	# Non-Chugi/Meiyo/Gi/Seigyo → GRIEVANCE_PTS_NO_INFO contribution (5/15 neutral).
	var n: L5RCharacterData = _make_npc(10, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE, 0)
	var phoenix_result: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false, true)
	var standard_result: Dictionary = IntraClanCivilWar.evaluate_loyalty(n, 101, 0.5, false, false, false)
	# With no visibility in standard, both use GRIEVANCE_PTS_NO_INFO (5) → scores should match.
	assert_eq(phoenix_result.get("rebel_score", -1), standard_result.get("rebel_score", -2))
