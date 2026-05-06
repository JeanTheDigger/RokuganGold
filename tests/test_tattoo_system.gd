extends GutTest


var _tattoos: Array[TattooData]


func _make_tattoo(
	id: int,
	recipient: int,
	artist: int,
	quality: Enums.TattooQualityTier,
	location: Enums.TattooBodyLocation,
	is_ability: bool = false,
	ability: Enums.TattooAbility = Enums.TattooAbility.NONE,
) -> TattooData:
	var t := TattooData.new()
	t.tattoo_id = id
	t.recipient_id = recipient
	t.artist_id = artist
	t.quality_tier = quality
	t.body_location = location
	t.is_ability_tattoo = is_ability
	t.ability_granted = ability
	t.date_applied = 100
	return t


func before_each() -> void:
	_tattoos = [] as Array[TattooData]


# =============================================================================
# Cultural Reluctance
# =============================================================================

func test_dragon_no_reluctance():
	var r := TattooSystem.get_cultural_reluctance("Dragon", "Mirumoto", Enums.TattooBodyLocation.CHEST_TORSO)
	assert_eq(r, Enums.CulturalReluctance.NO_RELUCTANCE)

func test_crab_no_reluctance():
	var r := TattooSystem.get_cultural_reluctance("Crab", "Hida", Enums.TattooBodyLocation.BACK)
	assert_eq(r, Enums.CulturalReluctance.NO_RELUCTANCE)

func test_mantis_no_reluctance():
	var r := TattooSystem.get_cultural_reluctance("Mantis", "Yoritomo", Enums.TattooBodyLocation.LEFT_UPPER_ARM_SHOULDER)
	assert_eq(r, Enums.CulturalReluctance.NO_RELUCTANCE)

func test_daidoji_wrist_no_reluctance():
	var r := TattooSystem.get_cultural_reluctance("Crane", "Daidoji", Enums.TattooBodyLocation.LEFT_WRIST_FOREARM)
	assert_eq(r, Enums.CulturalReluctance.NO_RELUCTANCE)

func test_daidoji_chest_reluctant():
	var r := TattooSystem.get_cultural_reluctance("Crane", "Daidoji", Enums.TattooBodyLocation.CHEST_TORSO)
	assert_eq(r, Enums.CulturalReluctance.RELUCTANT)

func test_lion_reluctant():
	var r := TattooSystem.get_cultural_reluctance("Lion", "Akodo", Enums.TattooBodyLocation.BACK)
	assert_eq(r, Enums.CulturalReluctance.RELUCTANT)

func test_crane_reluctant():
	var r := TattooSystem.get_cultural_reluctance("Crane", "Kakita", Enums.TattooBodyLocation.BACK)
	assert_eq(r, Enums.CulturalReluctance.RELUCTANT)

func test_scorpion_reluctant():
	var r := TattooSystem.get_cultural_reluctance("Scorpion", "Bayushi", Enums.TattooBodyLocation.BACK)
	assert_eq(r, Enums.CulturalReluctance.RELUCTANT)

func test_imperial_very_reluctant():
	var r := TattooSystem.get_cultural_reluctance("Imperial", "Otomo", Enums.TattooBodyLocation.LEFT_WRIST_FOREARM)
	assert_eq(r, Enums.CulturalReluctance.VERY_RELUCTANT)

func test_seppun_very_reluctant():
	var r := TattooSystem.get_cultural_reluctance("Imperial", "Seppun", Enums.TattooBodyLocation.BACK)
	assert_eq(r, Enums.CulturalReluctance.VERY_RELUCTANT)


# =============================================================================
# Consent Checks
# =============================================================================

func test_dragon_consents_at_zero():
	assert_true(TattooSystem.check_consent("Dragon", "Mirumoto", Enums.TattooBodyLocation.BACK, 0, false, false))

func test_lion_refuses_below_threshold():
	assert_false(TattooSystem.check_consent("Lion", "Akodo", Enums.TattooBodyLocation.BACK, 45, false, false))

func test_lion_consents_at_threshold():
	assert_true(TattooSystem.check_consent("Lion", "Akodo", Enums.TattooBodyLocation.BACK, 46, false, false))

func test_imperial_refuses_below_71():
	assert_false(TattooSystem.check_consent("Imperial", "Otomo", Enums.TattooBodyLocation.BACK, 70, false, false))

func test_imperial_consents_at_71():
	assert_true(TattooSystem.check_consent("Imperial", "Otomo", Enums.TattooBodyLocation.BACK, 71, false, false))

func test_meaningful_subject_drops_reluctant_to_none():
	assert_true(TattooSystem.check_consent("Lion", "Akodo", Enums.TattooBodyLocation.BACK, 0, true, false))

func test_meaningful_subject_drops_very_reluctant_to_reluctant():
	assert_false(TattooSystem.check_consent("Imperial", "Otomo", Enums.TattooBodyLocation.BACK, 45, true, false))
	assert_true(TattooSystem.check_consent("Imperial", "Otomo", Enums.TattooBodyLocation.BACK, 46, true, false))

func test_scorpion_leverage_drops_to_none():
	assert_true(TattooSystem.check_consent("Scorpion", "Bayushi", Enums.TattooBodyLocation.BACK, 0, false, true))

func test_scorpion_leverage_non_scorpion_ignored():
	assert_false(TattooSystem.check_consent("Lion", "Akodo", Enums.TattooBodyLocation.BACK, 0, false, true))


# =============================================================================
# Body Location Management
# =============================================================================

func test_all_locations_available_initially():
	var avail := TattooSystem.get_available_locations(_tattoos, 1, true)
	assert_eq(avail.size(), 9)

func test_head_unavailable_when_not_bald():
	var avail := TattooSystem.get_available_locations(_tattoos, 1, false)
	assert_eq(avail.size(), 8)
	assert_false(Enums.TattooBodyLocation.HEAD in avail)

func test_occupied_location_not_available():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK))
	var avail := TattooSystem.get_available_locations(_tattoos, 1, true)
	assert_eq(avail.size(), 8)
	assert_false(Enums.TattooBodyLocation.BACK in avail)

func test_location_available_for_different_character():
	_tattoos.append(_make_tattoo(1, 2, 3, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK))
	assert_true(TattooSystem.is_location_available(_tattoos, 1, Enums.TattooBodyLocation.BACK, true))

func test_head_location_requires_bald():
	assert_false(TattooSystem.is_location_available(_tattoos, 1, Enums.TattooBodyLocation.HEAD, false))
	assert_true(TattooSystem.is_location_available(_tattoos, 1, Enums.TattooBodyLocation.HEAD, true))

func test_get_character_tattoos():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK))
	_tattoos.append(_make_tattoo(2, 1, 2, Enums.TattooQualityTier.FINE, Enums.TattooBodyLocation.CHEST_TORSO))
	_tattoos.append(_make_tattoo(3, 3, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK))
	var result := TattooSystem.get_character_tattoos(_tattoos, 1)
	assert_eq(result.size(), 2)


# =============================================================================
# Visibility
# =============================================================================

func test_wrist_visible_normally():
	assert_true(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.LEFT_WRIST_FOREARM, false, true, false, false, false, false
	))

func test_wrist_hidden_in_formal_sleeves():
	assert_false(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.LEFT_WRIST_FOREARM, true, true, false, false, false, false
	))

func test_upper_arm_visible_without_outer():
	assert_true(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.LEFT_UPPER_ARM_SHOULDER, false, false, false, false, false, false
	))

func test_upper_arm_hidden_with_outer():
	assert_false(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.LEFT_UPPER_ARM_SHOULDER, false, true, false, false, false, false
	))

func test_chest_visible_when_upper_removed():
	assert_true(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.CHEST_TORSO, false, false, true, false, false, false
	))

func test_chest_hidden_normally():
	assert_false(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.CHEST_TORSO, false, false, false, false, false, false
	))

func test_back_visible_when_upper_removed():
	assert_true(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.BACK, false, false, true, false, false, false
	))

func test_leg_visible_when_lower_removed():
	assert_true(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.LEFT_LEG_THIGH, false, false, false, true, false, false
	))

func test_leg_hidden_normally():
	assert_false(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.LEFT_LEG_THIGH, false, false, false, false, false, false
	))

func test_head_visible_bald_no_hood():
	assert_true(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.HEAD, false, false, false, false, true, false
	))

func test_head_hidden_with_hood():
	assert_false(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.HEAD, false, false, false, false, true, true
	))

func test_head_hidden_not_bald():
	assert_false(TattooSystem.compute_visibility(
		Enums.TattooBodyLocation.HEAD, false, false, false, false, false, false
	))


# =============================================================================
# Quality Resolution
# =============================================================================

func test_success_at_tn():
	var q := TattooSystem.resolve_quality(Enums.TattooQualityTier.FINE, 20, 0)
	assert_eq(q, Enums.TattooQualityTier.FINE)

func test_success_with_raises():
	var q := TattooSystem.resolve_quality(Enums.TattooQualityTier.FINE, 20, 2)
	assert_eq(q, Enums.TattooQualityTier.MASTERWORK)

func test_raises_cap_at_legendary():
	var q := TattooSystem.resolve_quality(Enums.TattooQualityTier.EXCEPTIONAL, 25, 5)
	assert_eq(q, Enums.TattooQualityTier.LEGENDARY)

func test_failure_downgrades():
	var q := TattooSystem.resolve_quality(Enums.TattooQualityTier.FINE, 10, 0)
	assert_eq(q, Enums.TattooQualityTier.NORMAL)

func test_failure_normal_produces_mundane():
	var q := TattooSystem.resolve_quality(Enums.TattooQualityTier.NORMAL, 10, 0)
	assert_eq(q, Enums.TattooQualityTier.MUNDANE)


# =============================================================================
# Skill Gate
# =============================================================================

func test_skill_gate_normal():
	assert_true(TattooSystem.meets_skill_gate(1, Enums.TattooQualityTier.NORMAL))
	assert_false(TattooSystem.meets_skill_gate(0, Enums.TattooQualityTier.NORMAL))

func test_skill_gate_legendary():
	assert_true(TattooSystem.meets_skill_gate(5, Enums.TattooQualityTier.LEGENDARY))
	assert_false(TattooSystem.meets_skill_gate(4, Enums.TattooQualityTier.LEGENDARY))


# =============================================================================
# Create Tattoo
# =============================================================================

func test_create_tattoo_normal():
	var t := TattooSystem.create_tattoo(
		1, 10, 20, Enums.TattooQualityTier.FINE,
		Enums.TattooBodyLocation.BACK,
		Enums.TattooSubjectType.IMAGE, "A dragon in flight", -1,
		false, Enums.TattooAbility.NONE, 50
	)
	assert_not_null(t)
	assert_eq(t.recipient_id, 10)
	assert_eq(t.artist_id, 20)
	assert_eq(t.quality_tier, Enums.TattooQualityTier.FINE)
	assert_eq(t.subject_description, "A dragon in flight")
	assert_false(t.is_ability_tattoo)

func test_create_tattoo_mundane_returns_null():
	var t := TattooSystem.create_tattoo(
		1, 10, 20, Enums.TattooQualityTier.MUNDANE,
		Enums.TattooBodyLocation.BACK,
		Enums.TattooSubjectType.IMAGE, "Bad work", -1,
		false, Enums.TattooAbility.NONE, 50
	)
	assert_null(t)

func test_create_ability_tattoo():
	var t := TattooSystem.create_tattoo(
		1, 10, 20, Enums.TattooQualityTier.EXCEPTIONAL,
		Enums.TattooBodyLocation.CHEST_TORSO,
		Enums.TattooSubjectType.IMAGE, "Bear tattoo", -1,
		true, Enums.TattooAbility.BEAR, 50
	)
	assert_not_null(t)
	assert_true(t.is_ability_tattoo)
	assert_eq(t.ability_granted, Enums.TattooAbility.BEAR)


# =============================================================================
# Disposition Bonds
# =============================================================================

func test_disposition_bond_values():
	assert_eq(TattooSystem.get_disposition_bond(Enums.TattooQualityTier.NORMAL), 1)
	assert_eq(TattooSystem.get_disposition_bond(Enums.TattooQualityTier.FINE), 2)
	assert_eq(TattooSystem.get_disposition_bond(Enums.TattooQualityTier.EXCEPTIONAL), 3)
	assert_eq(TattooSystem.get_disposition_bond(Enums.TattooQualityTier.MASTERWORK), 4)
	assert_eq(TattooSystem.get_disposition_bond(Enums.TattooQualityTier.LEGENDARY), 5)

func test_total_bond_single_tattoo():
	_tattoos.append(_make_tattoo(1, 10, 20, Enums.TattooQualityTier.FINE, Enums.TattooBodyLocation.BACK))
	assert_eq(TattooSystem.calculate_total_bond(_tattoos, 10, 20), 2)
	assert_eq(TattooSystem.calculate_total_bond(_tattoos, 20, 10), 2)

func test_total_bond_multiple_tattoos():
	_tattoos.append(_make_tattoo(1, 10, 20, Enums.TattooQualityTier.FINE, Enums.TattooBodyLocation.BACK))
	_tattoos.append(_make_tattoo(2, 10, 20, Enums.TattooQualityTier.LEGENDARY, Enums.TattooBodyLocation.LEFT_WRIST_FOREARM))
	assert_eq(TattooSystem.calculate_total_bond(_tattoos, 10, 20), 7)

func test_total_bond_unrelated_characters():
	_tattoos.append(_make_tattoo(1, 10, 20, Enums.TattooQualityTier.FINE, Enums.TattooBodyLocation.BACK))
	assert_eq(TattooSystem.calculate_total_bond(_tattoos, 10, 99), 0)


# =============================================================================
# Togashi Ability Tattoo Gates
# =============================================================================

func test_is_togashi_school():
	assert_true(TattooSystem.is_togashi_school("Togashi Tattooed Order"))
	assert_true(TattooSystem.is_togashi_school("Kikage Zumi"))
	assert_true(TattooSystem.is_togashi_school("Hoshi Tsurui Zumi"))
	assert_false(TattooSystem.is_togashi_school("Mirumoto Bushi"))

func test_allotment_togashi_rank_1():
	assert_eq(TattooSystem.get_allotment_for_rank("Togashi Tattooed Order", 1), 2)

func test_allotment_togashi_rank_3():
	assert_eq(TattooSystem.get_allotment_for_rank("Togashi Tattooed Order", 3), 4)

func test_allotment_togashi_rank_5():
	assert_eq(TattooSystem.get_allotment_for_rank("Togashi Tattooed Order", 5), 6)

func test_allotment_kikage_rank_5():
	assert_eq(TattooSystem.get_allotment_for_rank("Kikage Zumi", 5), 3)

func test_allotment_hoshi_rank_4():
	assert_eq(TattooSystem.get_allotment_for_rank("Hoshi Tsurui Zumi", 4), 2)

func test_allotment_hoshi_rank_1():
	assert_eq(TattooSystem.get_allotment_for_rank("Hoshi Tsurui Zumi", 1), 1)

func test_current_rank_allotment():
	assert_eq(TattooSystem.get_current_rank_allotment("Togashi Tattooed Order", 1), 2)
	assert_eq(TattooSystem.get_current_rank_allotment("Togashi Tattooed Order", 2), 0)
	assert_eq(TattooSystem.get_current_rank_allotment("Togashi Tattooed Order", 3), 2)

func test_has_unfilled_slots_rank_1():
	assert_true(TattooSystem.has_unfilled_ability_slots(_tattoos, 1, "Togashi Tattooed Order", 1))

func test_unfilled_slots_filled():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.BEAR))
	_tattoos.append(_make_tattoo(2, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.CHEST_TORSO, true, Enums.TattooAbility.BAMBOO))
	assert_false(TattooSystem.has_unfilled_ability_slots(_tattoos, 1, "Togashi Tattooed Order", 1))

func test_non_togashi_no_unfilled_slots():
	assert_false(TattooSystem.has_unfilled_ability_slots(_tattoos, 1, "Mirumoto Bushi", 3))

func test_can_receive_decorative_non_togashi():
	assert_true(TattooSystem.can_receive_decorative(_tattoos, 1, "Mirumoto Bushi", 1))

func test_decorative_blocked_while_ability_unfilled():
	assert_false(TattooSystem.can_receive_decorative(_tattoos, 1, "Togashi Tattooed Order", 1))

func test_decorative_allowed_when_ability_filled():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.BEAR))
	_tattoos.append(_make_tattoo(2, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.CHEST_TORSO, true, Enums.TattooAbility.BAMBOO))
	assert_true(TattooSystem.can_receive_decorative(_tattoos, 1, "Togashi Tattooed Order", 1))

func test_can_apply_ability_tattoo():
	assert_true(TattooSystem.can_apply_ability_tattoo("Togashi Tattooed Order", 3, true))

func test_cannot_apply_ability_low_rank():
	assert_false(TattooSystem.can_apply_ability_tattoo("Togashi Tattooed Order", 2, true))

func test_cannot_apply_ability_outside_territory():
	assert_false(TattooSystem.can_apply_ability_tattoo("Togashi Tattooed Order", 5, false))

func test_cannot_apply_ability_non_togashi():
	assert_false(TattooSystem.can_apply_ability_tattoo("Mirumoto Bushi", 5, true))

func test_self_apply_requires_rank_3():
	assert_false(TattooSystem.can_self_apply("Togashi Tattooed Order", 2))
	assert_true(TattooSystem.can_self_apply("Togashi Tattooed Order", 3))


# =============================================================================
# SEEK_TATTOO Blocked
# =============================================================================

func test_seek_tattoo_not_blocked_with_space():
	assert_false(TattooSystem.is_seek_tattoo_blocked(_tattoos, 1))

func test_seek_tattoo_blocked_all_occupied():
	for i: int in range(9):
		_tattoos.append(_make_tattoo(
			i + 1, 1, 2, Enums.TattooQualityTier.NORMAL,
			TattooSystem.ALL_BODY_LOCATIONS[i]
		))
	assert_true(TattooSystem.is_seek_tattoo_blocked(_tattoos, 1))


# =============================================================================
# Urgency Scoring
# =============================================================================

func test_urgency_standard():
	assert_eq(TattooSystem.get_seek_tattoo_urgency(1), TattooSystem.SEEK_TATTOO_STANDARD_SCORE)

func test_urgency_override_at_2():
	assert_eq(TattooSystem.get_seek_tattoo_urgency(2), TattooSystem.SEEK_TATTOO_OVERRIDE_SCORE)

func test_urgency_maximum_at_3():
	assert_eq(TattooSystem.get_seek_tattoo_urgency(3), TattooSystem.SEEK_TATTOO_MAXIMUM_SCORE)

func test_urgency_maximum_at_5():
	assert_eq(TattooSystem.get_seek_tattoo_urgency(5), TattooSystem.SEEK_TATTOO_MAXIMUM_SCORE)


# =============================================================================
# Provenance TNs
# =============================================================================

func test_provenance_tn_legendary():
	assert_eq(TattooSystem.get_provenance_tn(Enums.TattooQualityTier.LEGENDARY), 15)

func test_provenance_tn_exceptional():
	assert_eq(TattooSystem.get_provenance_tn(Enums.TattooQualityTier.EXCEPTIONAL), 20)

func test_provenance_tn_fine():
	assert_eq(TattooSystem.get_provenance_tn(Enums.TattooQualityTier.FINE), 25)

func test_provenance_tn_normal():
	assert_eq(TattooSystem.get_provenance_tn(Enums.TattooQualityTier.NORMAL), 30)


# =============================================================================
# Commission
# =============================================================================

func test_commission_completion_bonus():
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.NORMAL), 2)
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.LEGENDARY), 10)

func test_commission_not_expired():
	assert_false(TattooSystem.is_commission_expired(100, 180, 90))

func test_commission_expired():
	assert_true(TattooSystem.is_commission_expired(100, 190, 90))

func test_commission_expired_exactly_at_boundary():
	assert_true(TattooSystem.is_commission_expired(100, 190, 90))


# =============================================================================
# Permanent Passive Tattoos
# =============================================================================

func test_has_mantis_tattoo():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.MANTIS))
	assert_true(TattooSystem.has_mantis_tattoo(_tattoos, 1))
	assert_false(TattooSystem.has_mantis_tattoo(_tattoos, 99))

func test_has_ocean_tattoo():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.CHEST_TORSO, true, Enums.TattooAbility.OCEAN))
	assert_true(TattooSystem.has_ocean_tattoo(_tattoos, 1))

func test_no_mantis_without_ability():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, false))
	assert_false(TattooSystem.has_mantis_tattoo(_tattoos, 1))


# =============================================================================
# Activation
# =============================================================================

func test_can_activate_visible_ability():
	var t := _make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.BEAR)
	t.is_visible = true
	assert_true(TattooSystem.can_activate_tattoo(t))

func test_cannot_activate_hidden():
	var t := _make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.BEAR)
	t.is_visible = false
	assert_false(TattooSystem.can_activate_tattoo(t))

func test_cannot_activate_decorative():
	var t := _make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, false)
	t.is_visible = true
	assert_false(TattooSystem.can_activate_tattoo(t))


# =============================================================================
# World Generation Helpers
# =============================================================================

func test_crab_mantis_seed_at_low():
	assert_true(TattooSystem.should_seed_crab_mantis_tattoo(0.3))

func test_crab_mantis_seed_at_boundary():
	assert_true(TattooSystem.should_seed_crab_mantis_tattoo(0.6))

func test_crab_mantis_no_seed_above():
	assert_false(TattooSystem.should_seed_crab_mantis_tattoo(0.7))

func test_daidoji_seed():
	assert_true(TattooSystem.should_seed_daidoji_tattoo(0.4))
	assert_false(TattooSystem.should_seed_daidoji_tattoo(0.6))

func test_dragon_decorative_count():
	assert_eq(TattooSystem.get_dragon_decorative_count(0.1), 0)
	assert_eq(TattooSystem.get_dragon_decorative_count(0.5), 1)
	assert_eq(TattooSystem.get_dragon_decorative_count(0.8), 2)


# =============================================================================
# AP Cost and TN Lookups
# =============================================================================

func test_ap_costs():
	assert_eq(TattooSystem.get_ap_cost(Enums.TattooQualityTier.NORMAL), 2)
	assert_eq(TattooSystem.get_ap_cost(Enums.TattooQualityTier.FINE), 3)
	assert_eq(TattooSystem.get_ap_cost(Enums.TattooQualityTier.EXCEPTIONAL), 4)
	assert_eq(TattooSystem.get_ap_cost(Enums.TattooQualityTier.MASTERWORK), 5)
	assert_eq(TattooSystem.get_ap_cost(Enums.TattooQualityTier.LEGENDARY), 6)

func test_apply_tns():
	assert_eq(TattooSystem.get_apply_tn(Enums.TattooQualityTier.NORMAL), 15)
	assert_eq(TattooSystem.get_apply_tn(Enums.TattooQualityTier.FINE), 20)
	assert_eq(TattooSystem.get_apply_tn(Enums.TattooQualityTier.EXCEPTIONAL), 25)
	assert_eq(TattooSystem.get_apply_tn(Enums.TattooQualityTier.MASTERWORK), 30)
	assert_eq(TattooSystem.get_apply_tn(Enums.TattooQualityTier.LEGENDARY), 35)
