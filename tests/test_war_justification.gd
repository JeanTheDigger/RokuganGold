extends GutTest


# -- Step 1: Objective Justification Tests -----------------------------------------

func test_expand_territory_justifies_all_tiers() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("EXPAND_TERRITORY", "")
	assert_true(WarJustification.MilitaryTier.RAID in tiers)
	assert_true(WarJustification.MilitaryTier.FORMAL_WAR in tiers)
	assert_true(WarJustification.MilitaryTier.TOTAL_WAR in tiers)


func test_military_dominance_justifies_raid_and_formal() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("MILITARY_DOMINANCE", "")
	assert_true(WarJustification.MilitaryTier.RAID in tiers)
	assert_true(WarJustification.MilitaryTier.FORMAL_WAR in tiers)
	assert_false(WarJustification.MilitaryTier.TOTAL_WAR in tiers)


func test_build_strongest_force_raid_only() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("BUILD_STRONGEST_FORCE", "")
	assert_eq(tiers.size(), 1)
	assert_true(WarJustification.MilitaryTier.RAID in tiers)


func test_prevent_shortage_raid_only() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("PREVENT_SHORTAGE", "")
	assert_eq(tiers.size(), 1)
	assert_true(WarJustification.MilitaryTier.RAID in tiers)


func test_peace_objective_not_justified() -> void:
	assert_false(WarJustification.is_objective_justified("MAINTAIN_PEACE", ""))
	assert_false(WarJustification.is_objective_justified("MAINTAIN_BALANCE", ""))
	assert_false(WarJustification.is_objective_justified("PROTECT_DEPENDENTS", ""))
	assert_false(WarJustification.is_objective_justified("LIVE_BY_BUSHIDO", ""))


func test_peace_objective_allows_defend() -> void:
	assert_true(WarJustification.is_objective_justified("MAINTAIN_PEACE", "DEFEND_PROVINCE"))


func test_primary_conquer_formal_war() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("", "CONQUER_PROVINCE")
	assert_true(WarJustification.MilitaryTier.FORMAL_WAR in tiers)
	assert_false(WarJustification.MilitaryTier.RAID in tiers)


func test_primary_defend_all_tiers() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("", "DEFEND_PROVINCE")
	assert_eq(tiers.size(), 3)


func test_primary_avenge_all_tiers() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("", "AVENGE")
	assert_eq(tiers.size(), 3)


func test_primary_sabotage_raid_only() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("", "SABOTAGE_ECONOMY")
	assert_eq(tiers.size(), 1)
	assert_true(WarJustification.MilitaryTier.RAID in tiers)


func test_unknown_objective_no_tiers() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("UNKNOWN", "UNKNOWN")
	assert_eq(tiers.size(), 0)


func test_primary_overrides_standing() -> void:
	var tiers: Array = WarJustification.get_objective_tiers(
		"PREVENT_SHORTAGE", "CONQUER_PROVINCE",
	)
	assert_true(WarJustification.MilitaryTier.FORMAL_WAR in tiers)


func test_situational_advance_family_raid_only() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("ADVANCE_FAMILY", "")
	assert_eq(tiers.size(), 1)
	assert_true(WarJustification.MilitaryTier.RAID in tiers)


func test_situational_honor_ancestors_all_tiers() -> void:
	var tiers: Array = WarJustification.get_objective_tiers("HONOR_ANCESTORS", "")
	assert_eq(tiers.size(), 3)


# -- Step 2: Personality-Driven Aggression Tests -----------------------------------

func test_yu_qualifies_for_aggression() -> void:
	assert_true(WarJustification.qualifies_for_personality_aggression(
		"Yu", "EXPAND_TERRITORY",
	))


func test_kyoryoku_qualifies() -> void:
	assert_true(WarJustification.qualifies_for_personality_aggression(
		"Kyoryoku", "MILITARY_DOMINANCE",
	))


func test_ketsui_qualifies() -> void:
	assert_true(WarJustification.qualifies_for_personality_aggression(
		"Ketsui", "ADVANCE_GLORY",
	))


func test_jin_does_not_qualify() -> void:
	assert_false(WarJustification.qualifies_for_personality_aggression(
		"Jin", "EXPAND_TERRITORY",
	))


func test_peace_objective_blocks_aggression() -> void:
	assert_false(WarJustification.qualifies_for_personality_aggression(
		"Yu", "MAINTAIN_PEACE",
	))


func test_raid_weakness_all_conditions() -> void:
	assert_true(WarJustification.check_raid_weakness(true, true, true))
	assert_false(WarJustification.check_raid_weakness(false, true, true))
	assert_false(WarJustification.check_raid_weakness(true, false, true))
	assert_false(WarJustification.check_raid_weakness(true, true, false))


func test_formal_war_weakness_2x_ratio() -> void:
	assert_true(WarJustification.check_formal_war_weakness(true, 10.0, 5.0))
	assert_true(WarJustification.check_formal_war_weakness(true, 10.0, 4.0))
	assert_false(WarJustification.check_formal_war_weakness(true, 10.0, 6.0))


func test_formal_war_weakness_requires_raid() -> void:
	assert_false(WarJustification.check_formal_war_weakness(false, 100.0, 1.0))


func test_formal_war_weakness_zero_defender() -> void:
	assert_true(WarJustification.check_formal_war_weakness(true, 5.0, 0.0))


# -- Step 3: Tier Validation Tests -------------------------------------------------

func test_tier_supported_expand_all() -> void:
	assert_true(WarJustification.is_tier_supported(
		WarJustification.MilitaryTier.RAID, "EXPAND_TERRITORY", "",
	))
	assert_true(WarJustification.is_tier_supported(
		WarJustification.MilitaryTier.TOTAL_WAR, "EXPAND_TERRITORY", "",
	))


func test_tier_not_supported_build_strongest_formal() -> void:
	assert_false(WarJustification.is_tier_supported(
		WarJustification.MilitaryTier.FORMAL_WAR, "BUILD_STRONGEST_FORCE", "",
	))


func test_tier_supported_defend_total() -> void:
	assert_true(WarJustification.is_tier_supported(
		WarJustification.MilitaryTier.TOTAL_WAR, "", "DEFEND_PROVINCE",
	))


# -- Step 4: Personality Gate Tests ------------------------------------------------

func test_jin_blocks_total_war_expand() -> void:
	var gate: Dictionary = WarJustification.check_personality_gate(
		WarJustification.MilitaryTier.TOTAL_WAR, "EXPAND_TERRITORY", "", "Jin",
	)
	assert_true(gate["blocked"])
	assert_eq(gate["reason"], "jin_blocks_total_war")


func test_jin_allows_raid_expand() -> void:
	var gate: Dictionary = WarJustification.check_personality_gate(
		WarJustification.MilitaryTier.RAID, "EXPAND_TERRITORY", "", "Jin",
	)
	assert_false(gate["blocked"])


func test_jin_blocks_resource_raid() -> void:
	var gate: Dictionary = WarJustification.check_personality_gate(
		WarJustification.MilitaryTier.RAID, "PREVENT_SHORTAGE", "", "Jin",
	)
	assert_true(gate["blocked"])


func test_gi_blocks_covert_warfare() -> void:
	var gate: Dictionary = WarJustification.check_personality_gate(
		WarJustification.MilitaryTier.RAID, "UNDERMINE_CLAN", "", "Gi",
	)
	assert_true(gate["blocked"])


func test_makoto_blocks_covert_warfare() -> void:
	var gate: Dictionary = WarJustification.check_personality_gate(
		WarJustification.MilitaryTier.RAID, "", "SABOTAGE_ECONOMY", "Makoto",
	)
	assert_true(gate["blocked"])


func test_yu_no_gate() -> void:
	var gate: Dictionary = WarJustification.check_personality_gate(
		WarJustification.MilitaryTier.TOTAL_WAR, "EXPAND_TERRITORY", "", "Yu",
	)
	assert_false(gate["blocked"])


# -- Full 5-Step Decision Tests ----------------------------------------------------

func test_full_justified_raid() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.RAID, "Yu",
	)
	assert_true(r["justified"])
	assert_eq(r["reason"], "objective_justified")
	assert_false(r["personality_driven"])


func test_full_no_objective_no_personality() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"MAINTAIN_PEACE", "", WarJustification.MilitaryTier.RAID, "Gi",
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 1)


func test_full_personality_aggression_raid() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"ACCUMULATE_KNOWLEDGE", "", WarJustification.MilitaryTier.RAID, "Yu",
		true, true, true,
	)
	assert_true(r["justified"])
	assert_true(r["personality_driven"])


func test_full_personality_aggression_weakness_fails() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"ACCUMULATE_KNOWLEDGE", "", WarJustification.MilitaryTier.RAID, "Yu",
		false, true, true,
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 2)


func test_full_personality_formal_war_needs_2x() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"ACCUMULATE_KNOWLEDGE", "", WarJustification.MilitaryTier.FORMAL_WAR, "Yu",
		true, true, true, 10.0, 6.0,
	)
	assert_false(r["justified"])
	assert_eq(r["reason"], "formal_war_weakness_not_met")


func test_full_personality_formal_war_passes_2x() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"ACCUMULATE_KNOWLEDGE", "", WarJustification.MilitaryTier.FORMAL_WAR, "Yu",
		true, true, true, 12.0, 5.0,
	)
	assert_true(r["justified"])
	assert_true(r["personality_driven"])


func test_full_tier_not_supported() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"BUILD_STRONGEST_FORCE", "", WarJustification.MilitaryTier.FORMAL_WAR, "Yu",
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 3)


func test_full_personality_gate_blocks() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "", WarJustification.MilitaryTier.TOTAL_WAR, "Jin",
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 4)
	assert_eq(r["reason"], "jin_blocks_total_war")


func test_full_defend_bypasses_peace_objective() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"MAINTAIN_PEACE", "DEFEND_PROVINCE", WarJustification.MilitaryTier.TOTAL_WAR, "Gi",
	)
	assert_true(r["justified"])


func test_full_conquer_requires_formal() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"EXPAND_TERRITORY", "CONQUER_PROVINCE", WarJustification.MilitaryTier.RAID, "Yu",
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 3)


func test_full_avenge_total_war() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"SEEK_VENGEANCE", "AVENGE", WarJustification.MilitaryTier.TOTAL_WAR, "Yu",
	)
	assert_true(r["justified"])


func test_full_sabotage_blocked_by_makoto() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"UNDERMINE_CLAN", "SABOTAGE_ECONOMY", WarJustification.MilitaryTier.RAID, "Makoto",
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 4)


func test_eliminate_shadowlands_all_tiers() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"ELIMINATE_SHADOWLANDS", "", WarJustification.MilitaryTier.TOTAL_WAR, "Yu",
	)
	assert_true(r["justified"])


func test_prevent_shortage_gi_blocked() -> void:
	var r: Dictionary = WarJustification.evaluate_war_justification(
		"PREVENT_SHORTAGE", "", WarJustification.MilitaryTier.RAID, "Gi",
	)
	assert_false(r["justified"])
	assert_eq(r["step_failed"], 4)


func test_all_peace_objectives_listed() -> void:
	var expected: Array[String] = [
		"MAINTAIN_BALANCE", "MAINTAIN_PEACE", "STRENGTHEN_IMPERIAL",
		"ACCUMULATE_LEVERAGE", "MAXIMIZE_PROSPERITY", "PROTECT_DEPENDENTS",
		"ACCUMULATE_KNOWLEDGE", "LIVE_BY_BUSHIDO",
	]
	for obj: String in expected:
		assert_true(
			obj in WarJustification.PEACE_OBJECTIVES,
			"Missing peace objective: %s" % obj,
		)


func test_all_standing_objectives_covered() -> void:
	var all_standings: Array[String] = [
		"EXPAND_TERRITORY", "MILITARY_DOMINANCE", "ELIMINATE_SHADOWLANDS",
		"STRENGTHEN_WALL", "BUILD_STRONGEST_FORCE", "SEEK_VENGEANCE",
		"ADVANCE_GLORY", "UNDERMINE_CLAN", "PREVENT_SHORTAGE",
	]
	for obj: String in all_standings:
		assert_true(
			WarJustification.STANDING_OBJECTIVE_TIERS.has(obj),
			"Missing standing objective: %s" % obj,
		)


# -- Personality-Driven Tier Selection -------------------------------------------

func test_yu_selects_highest_tier_expand() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"EXPAND_TERRITORY", "", "Yu",
	)
	assert_eq(tier, WarJustification.MilitaryTier.TOTAL_WAR)


func test_kyoryoku_selects_highest_tier() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"SEEK_VENGEANCE", "", "Kyoryoku",
	)
	assert_eq(tier, WarJustification.MilitaryTier.TOTAL_WAR)


func test_ketsui_selects_formal_for_dominance() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"MILITARY_DOMINANCE", "", "Ketsui",
	)
	assert_eq(tier, WarJustification.MilitaryTier.FORMAL_WAR)


func test_jin_caps_at_formal_war() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"EXPAND_TERRITORY", "", "Jin",
	)
	assert_ne(tier, WarJustification.MilitaryTier.TOTAL_WAR)
	assert_eq(tier, WarJustification.MilitaryTier.RAID)


func test_jin_caps_at_formal_for_seek_vengeance() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"SEEK_VENGEANCE", "", "Jin",
	)
	assert_ne(tier, WarJustification.MilitaryTier.TOTAL_WAR)


func test_default_virtue_selects_first_supported() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"EXPAND_TERRITORY", "", "Rei",
	)
	assert_eq(tier, WarJustification.MilitaryTier.RAID)


func test_build_strongest_force_always_raid() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"BUILD_STRONGEST_FORCE", "", "Yu",
	)
	assert_eq(tier, WarJustification.MilitaryTier.RAID)


func test_unknown_objective_defaults_to_raid() -> void:
	var tier: WarJustification.MilitaryTier = WarJustification.select_intended_tier(
		"NONEXISTENT", "", "Yu",
	)
	assert_eq(tier, WarJustification.MilitaryTier.RAID)


func test_authority_for_tier_mapping() -> void:
	assert_eq(
		WarJustification.get_authority_for_tier(WarJustification.MilitaryTier.RAID),
		WarData.AuthorityLevel.PROVINCIAL_RAID,
	)
	assert_eq(
		WarJustification.get_authority_for_tier(WarJustification.MilitaryTier.FORMAL_WAR),
		WarData.AuthorityLevel.BORDER_CONFLICT,
	)
	assert_eq(
		WarJustification.get_authority_for_tier(WarJustification.MilitaryTier.TOTAL_WAR),
		WarData.AuthorityLevel.CLAN_WAR,
	)
