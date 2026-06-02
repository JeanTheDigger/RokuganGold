extends GutTest
## Tests for RosterCompositionSystem (s56.10 --- LOCKED).

# -- Helpers -------------------------------------------------------------------

func _find_group_by_role(groups: Array, role: String) -> Dictionary:
	for g in groups:
		if g["role"] == role:
			return g
	return {}

func _find_group_by_type(groups: Array, unit_type: String) -> Dictionary:
	for g in groups:
		if g["unit_type"] == unit_type:
			return g
	return {}

func _has_type(groups: Array, unit_type: String) -> bool:
	return not _find_group_by_type(groups, unit_type).is_empty()

func _has_role(groups: Array, role: String) -> bool:
	return not _find_group_by_role(groups, role).is_empty()

func _sum_groups(groups: Array) -> int:
	var total: int = 0
	for g in groups:
		total += g["count"]
	return total

# -- Ronin Bandit leader type --------------------------------------------------

func test_bandit_str1_leader_is_simple_bandit() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 1, {"stability": 75}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.SIMPLE_BANDIT)

func test_bandit_str3_leader_is_experienced_bandit() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 3, {"stability": 75}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.EXPERIENCED_BANDIT)

func test_bandit_str5_leader_is_bandit_lord() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 5, {"stability": 75}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.BANDIT_LORD)

# -- Ronin Bandit headcount range by stability tier ----------------------------

func test_bandit_restless_headcount_in_range() -> void:
	# Restless tier: 3-4 per strength point.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 3, {"stability": 75}, 42)
	assert_true(r["total_count"] >= 3 * 3 and r["total_count"] <= 3 * 4,
		"Restless headcount out of [9,12] for str 3")

func test_bandit_broken_headcount_in_range() -> void:
	# Broken tier: 5-6 per strength point.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 3, {"stability": 10}, 42)
	assert_true(r["total_count"] >= 3 * 5 and r["total_count"] <= 3 * 6,
		"Broken headcount out of [15,18] for str 3")

# -- Ronin Bandit named NPC slot -----------------------------------------------

func test_bandit_has_no_named_npc_slot() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 5, {}, 1)
	assert_false(r["has_named_npc_slot"])

# -- Peasant Revolt leader and ashigaru guards ---------------------------------

func test_revolt_leader_is_rebel_leader() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_PEASANT_REVOLT, 4, {}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.REBEL_LEADER)

func test_revolt_str4_has_no_guard_ashigaru() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_PEASANT_REVOLT, 4, {}, 1)
	# Guard post group must have 0 units or not exist at all.
	var guard := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_GUARD_POST)
	assert_true(guard.is_empty() or guard["count"] == 0,
		"Str 4 revolt should have no guard ashigaru")

func test_revolt_str5_has_one_guard_ashigaru() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_PEASANT_REVOLT, 5, {}, 1)
	var guard := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_GUARD_POST)
	assert_false(guard.is_empty(), "Str 5 revolt should have a GUARD_POST group")
	assert_eq(guard["count"], 1)

func test_revolt_str8_has_two_guard_ashigaru() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_PEASANT_REVOLT, 8, {}, 1)
	var guard := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_GUARD_POST)
	assert_false(guard.is_empty(), "Str 8 revolt should have a GUARD_POST group")
	assert_eq(guard["count"], 2)

# -- Nezumi Infestation --------------------------------------------------------

func test_nezumi_always_has_chieftain() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_NEZUMI_INFESTATION, 3, {}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.NEZUMI_CHIEFTAIN)

func test_nezumi_broodmother_has_rim_watcher_role() -> void:
	# With high enough strength, broodmother count > 0 and role is RIM_WATCHER.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_NEZUMI_INFESTATION, 6, {}, 1)
	var brood := _find_group_by_type(r["groups"], RosterCompositionSystem.NEZUMI_BROODMOTHER)
	if brood.is_empty():
		pending("No broodmother rolled at this seed; rerun with different seed")
		return
	assert_eq(brood["role"], RosterCompositionSystem.ROLE_RIM_WATCHER)

func test_nezumi_headcount_in_range() -> void:
	# 4-5 per strength point.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_NEZUMI_INFESTATION, 3, {}, 42)
	assert_true(r["total_count"] >= 3 * 4 and r["total_count"] <= 3 * 5,
		"Nezumi headcount out of [12,15] for str 3")

# -- Maho Cult zombie counts ---------------------------------------------------

func test_maho_cult_zombie_count_normal_rate() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 3,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER,
		 "seasons_active": 3, "high_corpse_availability": false}, 1)
	# Normal rate=1 × 3 seasons = 3.
	assert_eq(r["zombie_count"], 3)

func test_maho_cult_zombie_count_high_corpse_rate() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 3,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER,
		 "seasons_active": 3, "high_corpse_availability": true}, 1)
	# High-corpse rate=2 × 3 seasons = 6.
	assert_eq(r["zombie_count"], 6)

func test_maho_cult_zombie_count_capped_at_ten() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 5,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER,
		 "seasons_active": 7, "high_corpse_availability": true}, 1)
	# High-corpse rate=2 × 7 = 14 → capped at 10.
	assert_eq(r["zombie_count"], RosterCompositionSystem.MAHO_ZOMBIE_CAP)

# -- Maho Cult path: Fallen Pillar ---------------------------------------------

func test_maho_fallen_pillar_has_named_npc_slot() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 4,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_FALLEN_PILLAR_NPC,
		 "seasons_active": 1, "high_corpse_availability": false}, 1)
	assert_true(r["has_named_npc_slot"])

func test_maho_fallen_pillar_leader_is_bloodspeaker_adept() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 4,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_FALLEN_PILLAR_NPC,
		 "seasons_active": 1, "high_corpse_availability": false}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.BLOODSPEAKER_ADEPT)

# -- Maho Cult path: Whispering Cell -------------------------------------------

func test_maho_whispering_cell_no_named_npc_slot() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 4,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_WHISPERING_CELL,
		 "seasons_active": 1, "high_corpse_availability": false}, 1)
	assert_false(r["has_named_npc_slot"])

func test_maho_whispering_cell_leader_is_maho_cultist() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_MAHO_CULT, 4,
		{"establishment_path": RosterCompositionSystem.MAHO_PATH_WHISPERING_CELL,
		 "seasons_active": 1, "high_corpse_availability": false}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.MAHO_CULTIST)

# -- Province Taint Manifestation focal point guardian ------------------------

func test_taint_touched_focal_guardian_is_tainted_animal() -> void:
	# PTL 3.0 → Touched tier.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_TAINT_MANIFESTATION, 3, {"ptl": 3.0}, 1)
	var fg := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_FOCAL_POINT_GUARDIAN)
	assert_eq(fg["unit_type"], RosterCompositionSystem.TAINTED_ANIMAL)

func test_taint_corrupted_focal_guardian_is_undead_revenant() -> void:
	# PTL 7.0 → Corrupted tier.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_TAINT_MANIFESTATION, 3, {"ptl": 7.0}, 1)
	var fg := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_FOCAL_POINT_GUARDIAN)
	assert_eq(fg["unit_type"], RosterCompositionSystem.UNDEAD_REVENANT)

func test_taint_blighted_focal_guardian_is_tainted_human() -> void:
	# PTL 9.0 → Blighted tier.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_TAINT_MANIFESTATION, 3, {"ptl": 9.0}, 1)
	var fg := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_FOCAL_POINT_GUARDIAN)
	assert_eq(fg["unit_type"], RosterCompositionSystem.TAINTED_HUMAN)

func test_taint_has_no_leader_role() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_TAINT_MANIFESTATION, 4, {"ptl": 5.0}, 1)
	assert_false(_has_role(r["groups"], RosterCompositionSystem.ROLE_LEADER))
	assert_false(r["has_leader"])

# -- Wall Sortie: friendly and enemy groups ------------------------------------

func test_sortie_small_has_both_friendly_and_enemy_groups() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_WALL_SORTIE, 0,
		{"sortie_size": RosterCompositionSystem.SORTIE_SMALL}, 1)
	assert_false((r["friendly_groups"] as Array).is_empty(),
		"Small sortie should have friendly groups")
	assert_false((r["enemy_groups"] as Array).is_empty(),
		"Small sortie should have enemy groups")

func test_sortie_small_friendly_has_no_kuni_witch_hunter() -> void:
	# GDD s56.10.11: Small sortie has NO Kuni Witch-Hunter.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_WALL_SORTIE, 0,
		{"sortie_size": RosterCompositionSystem.SORTIE_SMALL}, 1)
	assert_false(_has_type(r["friendly_groups"], RosterCompositionSystem.KUNI_WITCH_HUNTER),
		"Small sortie should not include a Kuni Witch-Hunter")

func test_sortie_medium_friendly_has_kuni_witch_hunter() -> void:
	# GDD s56.10.11: Medium sortie includes exactly 1 Kuni Witch-Hunter.
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_WALL_SORTIE, 0,
		{"sortie_size": RosterCompositionSystem.SORTIE_MEDIUM}, 1)
	var wh := _find_group_by_type(r["friendly_groups"], RosterCompositionSystem.KUNI_WITCH_HUNTER)
	assert_false(wh.is_empty(), "Medium sortie should have a Kuni Witch-Hunter group")
	assert_eq(wh["count"], 1)

func test_sortie_small_friendly_total_in_range() -> void:
	# SORTIE_FRIENDLY_SMALL = [4, 6].
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_WALL_SORTIE, 0,
		{"sortie_size": RosterCompositionSystem.SORTIE_SMALL}, 42)
	assert_true(r["friendly_total"] >= 4 and r["friendly_total"] <= 6,
		"Friendly small total out of [4,6]: %d" % r["friendly_total"])

# -- Urban Criminal Network ----------------------------------------------------

func test_criminal_boss_always_present() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 1, {}, 1)
	assert_true(_has_role(r["groups"], RosterCompositionSystem.ROLE_LEADER))

func test_criminal_str2_boss_is_bandit_thug() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 2, {}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.BANDIT_THUG)

func test_criminal_str3_boss_is_network_boss() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 3, {}, 1)
	var leader := _find_group_by_role(r["groups"], RosterCompositionSystem.ROLE_LEADER)
	assert_eq(leader["unit_type"], RosterCompositionSystem.NETWORK_BOSS)

func test_criminal_str2_has_no_lookout() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 2, {}, 1)
	assert_false(_has_type(r["groups"], RosterCompositionSystem.LOOKOUT),
		"Str 2 network should have no lookout")

func test_criminal_str3_has_lookout() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 3, {}, 1)
	assert_true(_has_type(r["groups"], RosterCompositionSystem.LOOKOUT),
		"Str 3 network should have at least one lookout")

func test_criminal_str5_has_corrupted_doshin() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 5, {}, 1)
	assert_true(_has_type(r["groups"], RosterCompositionSystem.CORRUPTED_DOSHIN),
		"Str 5 network should have a Corrupted Doshin")

func test_criminal_tier1_headcount_in_range() -> void:
	# Str 1, CRIMINAL_HEADCOUNT_TIER1 = [3, 6].
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 1, {}, 42)
	assert_true(r["total_count"] >= 3 and r["total_count"] <= 6,
		"Tier1 headcount out of [3,6]: %d" % r["total_count"])

func test_criminal_tier3_headcount_in_range() -> void:
	# Str 5, CRIMINAL_HEADCOUNT_TIER3 = [14, 20].
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 5, {}, 42)
	assert_true(r["total_count"] >= 14 and r["total_count"] <= 20,
		"Tier3 headcount out of [14,20]: %d" % r["total_count"])

func test_criminal_escape_tunnel_flag_always_set() -> void:
	var r := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK, 3, {}, 1)
	assert_true(r["boss_has_escape_tunnel"])

# -- Determinism ---------------------------------------------------------------

func test_same_seed_produces_same_result() -> void:
	var r1 := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 4, {"stability": 60}, 9999)
	var r2 := RosterCompositionSystem.compose_roster(
		RosterCompositionSystem.SEED_RONIN_BANDIT, 4, {"stability": 60}, 9999)
	assert_eq(r1["total_count"], r2["total_count"])
	assert_eq(r1["groups"].size(), r2["groups"].size())
