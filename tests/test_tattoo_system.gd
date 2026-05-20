extends GutTest


var _tattoos: Array


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
	_tattoos = []


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

func test_hoshi_allotment_at_rank_3():
	assert_eq(TattooSystem.get_allotment_for_rank("Hoshi Tsurui Zumi", 3), 1)

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

func test_urgency_initial_season():
	assert_eq(TattooSystem.get_seek_tattoo_urgency(0), TattooSystem.SEEK_TATTOO_STANDARD_SCORE)

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

func test_provenance_tn_masterwork():
	assert_eq(TattooSystem.get_provenance_tn(Enums.TattooQualityTier.MASTERWORK), 20)

func test_provenance_tn_normal():
	assert_eq(TattooSystem.get_provenance_tn(Enums.TattooQualityTier.NORMAL), 30)


# =============================================================================
# Commission
# =============================================================================

func test_commission_completion_bonus():
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.NORMAL), 2)
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.FINE), 3)
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.EXCEPTIONAL), 5)
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.MASTERWORK), 7)
	assert_eq(TattooSystem.get_commission_completion_bonus(Enums.TattooQualityTier.LEGENDARY), 10)

func test_commission_not_expired():
	assert_false(TattooSystem.is_commission_expired(100, 180, 90))

func test_commission_expired():
	assert_true(TattooSystem.is_commission_expired(100, 190, 90))

func test_commission_not_expired_one_before_boundary():
	assert_false(TattooSystem.is_commission_expired(100, 189, 90))


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
# get_active_ability_tattoo
# =============================================================================

func test_get_active_ability_tattoo_found():
	_tattoos.append(_make_tattoo(1, 1, 2, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.BEAR))
	var t := TattooSystem.get_active_ability_tattoo(_tattoos, 1, Enums.TattooAbility.BEAR)
	assert_not_null(t)
	assert_eq(t.ability_granted, Enums.TattooAbility.BEAR)

func test_get_active_ability_tattoo_none():
	var t := TattooSystem.get_active_ability_tattoo(_tattoos, 1, Enums.TattooAbility.NONE)
	assert_null(t)

func test_get_active_ability_tattoo_wrong_character():
	_tattoos.append(_make_tattoo(1, 2, 3, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.BACK, true, Enums.TattooAbility.BEAR))
	var t := TattooSystem.get_active_ability_tattoo(_tattoos, 1, Enums.TattooAbility.BEAR)
	assert_null(t)

func test_disposition_bond_mundane_is_zero():
	assert_eq(TattooSystem.get_disposition_bond(Enums.TattooQualityTier.MUNDANE), 0)


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


# =============================================================================
# APPLY_TATTOO Executor Wiring
# =============================================================================

func _make_artist(tattooing_rank: int = 3, ap: int = 6) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 100
	c.character_name = "Togashi Artisan"
	c.agility = 4
	c.skills = {"Artisan: Tattooing": tattooing_rank}
	c.school_name = "Togashi Tattooed Order"
	c.school_rank = 3
	c.action_points_current = ap
	c.action_points_max = ap
	return c

func _make_recipient() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 200
	c.character_name = "Mirumoto Recipient"
	c.clan = "Dragon"
	c.family = "Mirumoto"
	return c

func _make_tattoo_action(
	target_id: int = 200,
	tier: Enums.TattooQualityTier = Enums.TattooQualityTier.NORMAL,
	loc: Enums.TattooBodyLocation = Enums.TattooBodyLocation.CHEST_TORSO,
) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "APPLY_TATTOO"
	a.target_npc_id = target_id
	a.ap_cost = 2
	a.metadata = {
		"target_tier": tier,
		"body_location": loc,
		"is_ability_tattoo": false,
		"ability": Enums.TattooAbility.NONE,
		"world_tattoos": [],
		"recipient_is_bald": false,
		"subject_type": Enums.TattooSubjectType.IMAGE,
		"subject_description": "Dragon coiling",
		"subject_topic_id": -1,
	}
	return a

func _make_tattoo_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 100
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.ic_day = 50
	ctx.season = 0  # SPRING
	return ctx

func test_apply_tattoo_success():
	var artist := _make_artist()
	var recipient := _make_recipient()
	var action := _make_tattoo_action()
	var ctx := _make_tattoo_ctx()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars: Dictionary = {100: artist, 200: recipient}
	var result: Dictionary = ActionExecutor.execute(
		action, artist, ctx, dice, {"APPLY_TATTOO": {"primary": "Artisan: Tattooing", "secondary": "Agility"}},
		{}, chars,
	)
	assert_true(result.get("success", false), "Should succeed with rank 3 artist on NORMAL tier")
	assert_eq(result.get("action_id", ""), "APPLY_TATTOO")
	var effects: Dictionary = result.get("effects", {})
	assert_true(effects.get("requires_tattoo_creation", false), "Should flag tattoo creation")
	assert_true(effects.get("disposition_change", 0) > 0, "Should have positive disposition bond")

func test_apply_tattoo_skill_gate_blocks():
	var artist := _make_artist(0)
	var recipient := _make_recipient()
	var action := _make_tattoo_action()
	var ctx := _make_tattoo_ctx()
	var dice := DiceEngine.new()
	var chars: Dictionary = {100: artist, 200: recipient}
	var result: Dictionary = ActionExecutor.execute(
		action, artist, ctx, dice, {"APPLY_TATTOO": {"primary": "Artisan: Tattooing", "secondary": "Agility"}},
		{}, chars,
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "skill_gate_failed")

func test_apply_tattoo_insufficient_ap():
	var artist := _make_artist(3, 1)
	var recipient := _make_recipient()
	var action := _make_tattoo_action()
	var ctx := _make_tattoo_ctx()
	var dice := DiceEngine.new()
	var chars: Dictionary = {100: artist, 200: recipient}
	var result: Dictionary = ActionExecutor.execute(
		action, artist, ctx, dice, {"APPLY_TATTOO": {"primary": "Artisan: Tattooing", "secondary": "Agility"}},
		{}, chars,
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "insufficient_ap")

func test_apply_tattoo_location_occupied():
	var artist := _make_artist()
	var recipient := _make_recipient()
	var existing := _make_tattoo(1, 200, 100, Enums.TattooQualityTier.NORMAL, Enums.TattooBodyLocation.CHEST_TORSO)
	var action := _make_tattoo_action()
	action.metadata["world_tattoos"] = [existing]
	var ctx := _make_tattoo_ctx()
	var dice := DiceEngine.new()
	var chars: Dictionary = {100: artist, 200: recipient}
	var result: Dictionary = ActionExecutor.execute(
		action, artist, ctx, dice, {"APPLY_TATTOO": {"primary": "Artisan: Tattooing", "secondary": "Agility"}},
		{}, chars,
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "location_occupied")

func test_apply_tattoo_no_recipient():
	var artist := _make_artist()
	var action := _make_tattoo_action(999)
	var ctx := _make_tattoo_ctx()
	var dice := DiceEngine.new()
	var chars: Dictionary = {100: artist}
	var result: Dictionary = ActionExecutor.execute(
		action, artist, ctx, dice, {"APPLY_TATTOO": {"primary": "Artisan: Tattooing", "secondary": "Agility"}},
		{}, chars,
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_recipient")

func test_apply_tattoo_fine_tier_ap_override():
	var artist := _make_artist(3, 6)
	var recipient := _make_recipient()
	var action := _make_tattoo_action(200, Enums.TattooQualityTier.FINE)
	var ctx := _make_tattoo_ctx()
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var chars: Dictionary = {100: artist, 200: recipient}
	var result: Dictionary = ActionExecutor.execute(
		action, artist, ctx, dice, {"APPLY_TATTOO": {"primary": "Artisan: Tattooing", "secondary": "Agility"}},
		{}, chars,
	)
	var effects: Dictionary = result.get("effects", {})
	assert_eq(effects.get("ap_cost_override", 0), 3, "FINE tier should cost 3 AP")

func test_apply_tattoo_writeback_creates_tattoo():
	var artist := _make_artist()
	var recipient := _make_recipient()
	var chars: Dictionary = {100: artist, 200: recipient}
	var tattoos: Array = []
	var next_id: Array = [1]
	var result: Dictionary = {
		"success": true, "action_id": "APPLY_TATTOO",
		"character_id": 100, "target_npc_id": 200,
		"effects": {
			"requires_tattoo_creation": true,
			"result_quality": Enums.TattooQualityTier.FINE,
			"body_location": Enums.TattooBodyLocation.BACK,
			"is_ability_tattoo": false,
			"ability": Enums.TattooAbility.NONE,
			"subject_type": Enums.TattooSubjectType.IMAGE,
			"subject_description": "Mountain",
			"topic_id": -1,
			"ap_cost_override": 3,
		},
	}
	DayOrchestrator._process_tattoo_creation(
		[result], chars, tattoos, next_id, 50,
	)
	assert_eq(tattoos.size(), 1, "Should create one tattoo")
	assert_eq(tattoos[0].recipient_id, 200)
	assert_eq(tattoos[0].artist_id, 100)
	assert_eq(tattoos[0].quality_tier, Enums.TattooQualityTier.FINE)
	assert_eq(tattoos[0].body_location, Enums.TattooBodyLocation.BACK)
	assert_eq(next_id[0], 2, "Should increment tattoo ID")

func test_apply_tattoo_writeback_deducts_extra_ap():
	var artist := _make_artist(5, 6)
	var chars: Dictionary = {100: artist}
	var tattoos: Array = []
	var next_id: Array = [1]
	var result: Dictionary = {
		"success": true, "action_id": "APPLY_TATTOO",
		"character_id": 100, "target_npc_id": 200,
		"effects": {
			"requires_tattoo_creation": true,
			"result_quality": Enums.TattooQualityTier.EXCEPTIONAL,
			"body_location": Enums.TattooBodyLocation.CHEST_TORSO,
			"ap_cost_override": 4,
			"is_ability_tattoo": false,
			"ability": Enums.TattooAbility.NONE,
			"subject_type": Enums.TattooSubjectType.IMAGE,
			"subject_description": "",
			"topic_id": -1,
		},
	}
	DayOrchestrator._process_tattoo_creation(
		[result], chars, tattoos, next_id, 50,
	)
	assert_eq(artist.action_points_current, 4, "Should deduct 2 extra AP (4 - 2 base)")

func test_apply_tattoo_mundane_no_creation():
	var artist := _make_artist()
	var chars: Dictionary = {100: artist}
	var tattoos: Array = []
	var next_id: Array = [1]
	var result: Dictionary = {
		"success": false, "action_id": "APPLY_TATTOO",
		"character_id": 100, "target_npc_id": 200,
		"effects": {
			"ap_cost_override": 2,
			"result_quality": Enums.TattooQualityTier.MUNDANE,
		},
	}
	DayOrchestrator._process_tattoo_creation(
		[result], chars, tattoos, next_id, 50,
	)
	assert_eq(tattoos.size(), 0, "Mundane result should not create a tattoo")

func test_apply_tattoo_context_list_includes_action():
	var at_holdings: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true("APPLY_TATTOO" in at_holdings, "AT_OWN_HOLDINGS should include APPLY_TATTOO")
	var visiting: Array = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.VISITING
	)
	assert_true("APPLY_TATTOO" in visiting, "VISITING should include APPLY_TATTOO")

func test_apply_tattoo_ap_cost_entry():
	assert_eq(NPCDecisionEngine._get_ap_cost("APPLY_TATTOO"), 2)


# =============================================================================
# APPLY_TATTOO Precondition Filter — Consent & Decorative Gate
# =============================================================================

func _make_options_with_tattoo(target_id: int = 200) -> Array:
	var tattoo_opt := NPCDataStructures.ScoredAction.new()
	tattoo_opt.action_id = "APPLY_TATTOO"
	tattoo_opt.target_npc_id = target_id
	tattoo_opt.metadata = {
		"target_tier": Enums.TattooQualityTier.NORMAL,
		"body_location": Enums.TattooBodyLocation.LEFT_WRIST_FOREARM,
		"is_ability_tattoo": false,
		"ability": Enums.TattooAbility.NONE,
	}
	var rest_opt := NPCDataStructures.ScoredAction.new()
	rest_opt.action_id = "REST"
	return [tattoo_opt, rest_opt]

func test_tattoo_filter_removes_when_no_skill():
	var artist := _make_artist(0)
	var ctx := _make_tattoo_ctx()
	var options := _make_options_with_tattoo()
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist, 200: _make_recipient()}, {}
	)
	for opt: NPCDataStructures.ScoredAction in result:
		assert_ne(opt.action_id, "APPLY_TATTOO", "Should remove APPLY_TATTOO with no skill")
	assert_eq(result.size(), 1)

func test_tattoo_filter_removes_when_no_recipient():
	var artist := _make_artist()
	var ctx := _make_tattoo_ctx()
	var options := _make_options_with_tattoo(999)
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist}, {}
	)
	for opt: NPCDataStructures.ScoredAction in result:
		assert_ne(opt.action_id, "APPLY_TATTOO", "Should remove when recipient not in chars_by_id")

func test_tattoo_filter_removes_when_consent_fails():
	var artist := _make_artist()
	var recipient := _make_recipient()
	recipient.clan = "Phoenix"
	recipient.family = "Isawa"
	var ctx := _make_tattoo_ctx()
	ctx.dispositions = {200: 10}
	var options := _make_options_with_tattoo()
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist, 200: recipient}, {}
	)
	for opt: NPCDataStructures.ScoredAction in result:
		assert_ne(opt.action_id, "APPLY_TATTOO", "Reluctant clan with low disposition should block")

func test_tattoo_filter_passes_when_consent_ok():
	var artist := _make_artist()
	var recipient := _make_recipient()
	var ctx := _make_tattoo_ctx()
	ctx.dispositions = {200: 5}
	var options := _make_options_with_tattoo()
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist, 200: recipient}, {}
	)
	var found: bool = false
	for opt: NPCDataStructures.ScoredAction in result:
		if opt.action_id == "APPLY_TATTOO":
			found = true
	assert_true(found, "Dragon clan recipient at Neutral should consent")

func test_tattoo_filter_decorative_gate_blocks():
	var artist := _make_artist()
	var recipient := _make_recipient()
	recipient.school_name = "Togashi Tattooed Order"
	recipient.school_rank = 1
	var ctx := _make_tattoo_ctx()
	ctx.dispositions = {200: 50}
	var options := _make_options_with_tattoo()
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist, 200: recipient}, {}
	)
	for opt: NPCDataStructures.ScoredAction in result:
		assert_ne(opt.action_id, "APPLY_TATTOO",
			"Togashi R1 with unfilled ability slots should block decorative")

func test_tattoo_filter_decorative_gate_passes_non_togashi():
	var artist := _make_artist()
	var recipient := _make_recipient()
	recipient.school_name = "Mirumoto Bushi"
	recipient.school_rank = 3
	var ctx := _make_tattoo_ctx()
	ctx.dispositions = {200: 5}
	var options := _make_options_with_tattoo()
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist, 200: recipient}, {}
	)
	var found: bool = false
	for opt: NPCDataStructures.ScoredAction in result:
		if opt.action_id == "APPLY_TATTOO":
			found = true
	assert_true(found, "Non-Togashi recipient should pass decorative gate")

func test_tattoo_filter_all_locations_occupied():
	var artist := _make_artist()
	var recipient := _make_recipient()
	var ctx := _make_tattoo_ctx()
	ctx.dispositions = {200: 5}
	var full_tattoos: Array = []
	for loc: Enums.TattooBodyLocation in TattooSystem.ALL_BODY_LOCATIONS:
		full_tattoos.append(_make_tattoo(full_tattoos.size(), 200, 100,
			Enums.TattooQualityTier.NORMAL, loc))
	var options := _make_options_with_tattoo()
	var ws: Dictionary = {"tattoos": full_tattoos}
	var result := NPCDecisionEngine._apply_tattoo_precondition_filter(
		options, artist, ctx, {100: artist, 200: recipient}, ws
	)
	for opt: NPCDataStructures.ScoredAction in result:
		assert_ne(opt.action_id, "APPLY_TATTOO", "All locations full should block")
