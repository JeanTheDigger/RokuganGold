extends GutTest
## Tests for QuestSeedSelector (s56.1 --- LOCKED).

# -- Helpers -------------------------------------------------------------------

func _make_province(
		province_id: int = 1,
		stability: float = 80.0,
		ptl: float = 0.0,
		is_coastal: bool = false) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id   = province_id
	p.stability     = stability
	p.province_taint_level = ptl
	p.is_coastal    = is_coastal
	return p


func _make_insurgency(
		ins_id: int,
		ins_type: Enums.InsurgencyType,
		strength: int = 3,
		detected: bool = true,
		seasons_active: int = 1,
		province_id: int = 1) -> InsurgencyData:
	var ins := InsurgencyData.new()
	ins.insurgency_id   = ins_id
	ins.insurgency_type = ins_type
	ins.strength        = strength
	ins.detected        = detected
	ins.seasons_active  = seasons_active
	ins.province_id     = province_id
	return ins


func _make_cell(cell_id: int, insurgency_id: int, path: int) -> BloodspeakerCellData:
	var c := BloodspeakerCellData.new()
	c.cell_id            = cell_id
	c.insurgency_id      = insurgency_id
	c.establishment_path = path  # Enums.CellEstablishmentPath int
	return c


func _find_seed(results: Array, seed_label: String) -> Dictionary:
	for r in results:
		if r.get("seed_label", "") == seed_label:
			return r
	return {}

# -- Basic routing -------------------------------------------------------

func test_empty_province_returns_no_seeds() -> void:
	var province := _make_province(1, 80.0, 0.0)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	assert_eq(results.size(), 0)


func test_undetected_insurgency_excluded() -> void:
	var province := _make_province(1, 80.0, 0.0)
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 3, false)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results.size(), 0)

# -- Ronin Bandit ----------------------------------------------------------

func test_ronin_bandit_seed_produced() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 4)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results.size(), 1)
	var seed: Dictionary = results[0]
	assert_eq(seed["seed_type"],   RosterCompositionSystem.SEED_RONIN_BANDIT)
	assert_eq(seed["seed_label"],  "RONIN_BANDIT")
	assert_eq(seed["source"],      "insurgency")
	assert_eq(seed["strength"],    4)
	assert_true(seed["roster_ready"])


func test_ronin_bandit_carries_stability_option() -> void:
	var province := _make_province(1, 60.0)
	var ins := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var seed: Dictionary = results[0]
	assert_eq(seed["options"]["stability"], 60)


func test_ronin_bandit_source_insurgency_id_set() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(7, Enums.InsurgencyType.RONIN_BANDIT)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results[0]["source_insurgency_id"], 7)

# -- Peasant Revolt --------------------------------------------------------

func test_peasant_revolt_seed_produced() -> void:
	var province := _make_province(1, 40.0)
	var ins := _make_insurgency(2, Enums.InsurgencyType.PEASANT_REVOLT, 3)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results.size(), 1)
	var seed: Dictionary = results[0]
	assert_eq(seed["seed_type"],  RosterCompositionSystem.SEED_PEASANT_REVOLT)
	assert_eq(seed["seed_label"], "PEASANT_REVOLT")
	assert_eq(seed["options"],    {})
	assert_true(seed["roster_ready"])

# -- Nezumi Infestation ----------------------------------------------------

func test_nezumi_seed_produced() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(3, Enums.InsurgencyType.NEZUMI_INFESTATION, 2)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results.size(), 1)
	var seed: Dictionary = results[0]
	assert_eq(seed["seed_type"],  RosterCompositionSystem.SEED_NEZUMI_INFESTATION)
	assert_eq(seed["options"],    {})

# -- Urban Criminal Network ------------------------------------------------

func test_urban_criminal_seed_produced() -> void:
	var province := _make_province(1, 70.0)
	var ins := _make_insurgency(4, Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK, 3)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["seed_type"], RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK)
	assert_eq(results[0]["options"],   {})

# -- Maho Cult: options derivation -----------------------------------------

func test_maho_cult_defaults_to_ptl_corruption_path_when_no_cell() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_false(seed.is_empty())
	assert_eq(seed["options"]["establishment_path"], RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER)


func test_maho_cult_agent_infiltration_path_from_matching_cell() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var cell := _make_cell(1, 5, 0)  # AGENT_INFILTRATION = 0
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [cell], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_eq(seed["options"]["establishment_path"], RosterCompositionSystem.MAHO_PATH_WHISPERING_CELL)


func test_maho_cult_named_npc_fall_path_from_matching_cell() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var cell := _make_cell(1, 5, 2)  # NAMED_NPC_FALL = 2
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [cell], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_eq(seed["options"]["establishment_path"], RosterCompositionSystem.MAHO_PATH_FALLEN_PILLAR_NPC)


func test_maho_cult_artifact_discovery_path_from_matching_cell() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var cell := _make_cell(1, 5, 3)  # ARTIFACT_DISCOVERY = 3
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [cell], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_eq(seed["options"]["establishment_path"], RosterCompositionSystem.MAHO_PATH_FALLEN_PILLAR_ART)


func test_maho_cult_non_matching_cell_falls_through_to_default() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var cell := _make_cell(1, 99, 2)  # different insurgency_id
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [cell], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_eq(seed["options"]["establishment_path"], RosterCompositionSystem.MAHO_PATH_BLOODSPEAKER)


func test_maho_cult_seasons_active_from_insurgency() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 7)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_eq(seed["options"]["seasons_active"], 7)


func test_maho_cult_high_corpse_true_when_stability_broken() -> void:
	var province := _make_province(1, 20.0)  # Broken tier
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_true(seed["options"]["high_corpse_availability"])


func test_maho_cult_high_corpse_false_when_stability_volatile() -> void:
	var province := _make_province(1, 40.0)  # Volatile tier (26-50)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 3, true, 2)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var seed: Dictionary = _find_seed(results, "MAHO_CULT")
	assert_false(seed["options"]["high_corpse_availability"])

# -- Taint Manifestation: insurgency-sourced --------------------------------

func test_taint_insurgency_carries_ptl_option() -> void:
	var province := _make_province(1, 80.0, 5.0)
	var ins := _make_insurgency(6, Enums.InsurgencyType.TAINT_MANIFESTATION, 2)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var seed: Dictionary = _find_seed(results, "TAINT_MANIFESTATION")
	assert_false(seed.is_empty())
	assert_eq(seed["options"]["ptl"], 5.0)
	assert_eq(seed["source"], "insurgency")

# -- Taint Manifestation: PTL-only (no insurgency) -------------------------

func test_ptl_only_taint_seed_when_ptl_at_trigger() -> void:
	var province := _make_province(1, 80.0, 3.0)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	assert_eq(results.size(), 1)
	var seed: Dictionary = results[0]
	assert_eq(seed["seed_type"],  RosterCompositionSystem.SEED_TAINT_MANIFESTATION)
	assert_eq(seed["source"],     "ptl_only")
	assert_eq(seed["options"]["ptl"], 3.0)
	assert_true(seed["roster_ready"])


func test_ptl_below_trigger_produces_no_seed() -> void:
	var province := _make_province(1, 80.0, 2.9)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	assert_eq(results.size(), 0)


func test_ptl_only_strength_ptl3_gives_strength_1() -> void:
	var province := _make_province(1, 80.0, 3.0)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	assert_eq(results[0]["strength"], 1)


func test_ptl_only_strength_ptl6_gives_strength_2() -> void:
	var province := _make_province(1, 80.0, 6.0)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	var seed: Dictionary = _find_seed(results, "TAINT_MANIFESTATION")
	assert_eq(seed["strength"], 2)


func test_ptl_only_taint_suppressed_when_taint_insurgency_already_detected() -> void:
	var province := _make_province(1, 80.0, 5.0)
	var ins := _make_insurgency(6, Enums.InsurgencyType.TAINT_MANIFESTATION, 2, true)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	# Only one TAINT_MANIFESTATION seed (the insurgency-sourced one, not PTL-only)
	var taint_seeds: Array = results.filter(func(r): return r["seed_label"] == "TAINT_MANIFESTATION")
	assert_eq(taint_seeds.size(), 1)
	assert_eq(taint_seeds[0]["source"], "insurgency")

# -- Oni Manifestation: from Maho Cult strength >= 10 ----------------------

func test_maho_cult_strength_10_adds_oni_seed() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 10)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var oni: Dictionary = _find_seed(results, "ONI_MANIFESTATION")
	assert_false(oni.is_empty())
	assert_eq(oni["seed_type"],   QuestSeedSelector.SEED_ONI_MANIFESTATION)
	assert_eq(oni["strength"],    10)
	# roster_ready flipped true (2026-07-05): the s54.5 oni stat blocks now exist,
	# so a solo BOSS-tier oni roster is composed (s56.1.2 boss encounter).
	assert_true(oni["roster_ready"])


func test_maho_cult_strength_9_no_oni_seed() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 9)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var oni: Dictionary = _find_seed(results, "ONI_MANIFESTATION")
	assert_true(oni.is_empty())


func test_oni_from_maho_cult_has_insurgency_id() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 10)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var oni: Dictionary = _find_seed(results, "ONI_MANIFESTATION")
	assert_eq(oni["source_insurgency_id"], 5)

# -- Oni Manifestation: from extreme PTL -----------------------------------

func test_ptl_oni_trigger_adds_oni_seed() -> void:
	var province := _make_province(1, 80.0, 9.0)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	var oni: Dictionary = _find_seed(results, "ONI_MANIFESTATION")
	assert_false(oni.is_empty())
	assert_eq(oni["source_insurgency_id"], -1)


func test_ptl_below_oni_trigger_no_extra_oni() -> void:
	var province := _make_province(1, 80.0, 8.9)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], {}, [], 0)
	var oni: Dictionary = _find_seed(results, "ONI_MANIFESTATION")
	assert_true(oni.is_empty())


func test_ptl_oni_suppressed_when_maho_cult_already_at_10() -> void:
	# PTL >= 9 AND Maho Cult strength >= 10: only one ONI seed (via cult path)
	var province := _make_province(1, 80.0, 9.5)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 10)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	var oni_seeds: Array = results.filter(func(r): return r["seed_label"] == "ONI_MANIFESTATION")
	assert_eq(oni_seeds.size(), 1)
	assert_eq(oni_seeds[0]["source_insurgency_id"], 5)  # via maho cult, not ptl-only

# -- Wall Sortie -----------------------------------------------------------

func test_wall_sortie_medium_ss_produces_small_sortie() -> void:
	var province := _make_province(1, 80.0)
	var ws: Dictionary = {1: {"ss": 6, "si": 80.0}}  # ss=6 is medium tier
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], ws, [], 0)
	var seed: Dictionary = _find_seed(results, "WALL_SORTIE")
	assert_false(seed.is_empty())
	assert_eq(seed["seed_type"],         RosterCompositionSystem.SEED_WALL_SORTIE)
	assert_eq(seed["options"]["sortie_size"], "SMALL")  # uppercase
	assert_true(seed["roster_ready"])


func test_wall_sortie_high_ss_produces_medium_sortie() -> void:
	var province := _make_province(1, 80.0)
	var ws: Dictionary = {1: {"ss": 10, "si": 80.0}}  # ss=10 is high tier
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], ws, [], 0)
	var seed: Dictionary = _find_seed(results, "WALL_SORTIE")
	assert_eq(seed["options"]["sortie_size"], "MEDIUM")


func test_wall_sortie_low_ss_produces_no_seed() -> void:
	var province := _make_province(1, 80.0)
	var ws: Dictionary = {1: {"ss": 3, "si": 80.0}}  # ss=3 is low tier
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], ws, [], 0)
	var seed: Dictionary = _find_seed(results, "WALL_SORTIE")
	assert_true(seed.is_empty())


func test_wall_sortie_not_generated_when_province_not_in_statuses() -> void:
	var province := _make_province(1, 80.0)
	var ws: Dictionary = {99: {"ss": 10, "si": 80.0}}  # different province
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], ws, [], 0)
	assert_eq(results.size(), 0)


func test_wall_sortie_strength_from_ss() -> void:
	var province := _make_province(1, 80.0)
	var ws: Dictionary = {1: {"ss": 7, "si": 80.0}}
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [], ws, [], 0)
	var seed: Dictionary = _find_seed(results, "WALL_SORTIE")
	assert_eq(seed["strength"], 7)

# -- Multiple seeds in one province ----------------------------------------

func test_multiple_insurgencies_produce_multiple_seeds() -> void:
	var province := _make_province(1, 40.0)  # volatile
	var ins1 := _make_insurgency(1, Enums.InsurgencyType.RONIN_BANDIT, 3)
	var ins2 := _make_insurgency(2, Enums.InsurgencyType.PEASANT_REVOLT, 2)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins1, ins2], {}, [], 0)
	assert_eq(results.size(), 2)
	var labels: Array = results.map(func(r): return r["seed_label"])
	assert_true("RONIN_BANDIT" in labels)
	assert_true("PEASANT_REVOLT" in labels)


func test_maho_cult_at_10_produces_both_maho_and_oni_seeds() -> void:
	var province := _make_province(1, 80.0)
	var ins := _make_insurgency(5, Enums.InsurgencyType.MAHO_CULT, 10)
	var results: Array = QuestSeedSelector.select_province_seeds(
		province, [ins], {}, [], 0)
	assert_eq(results.size(), 2)
	var labels: Array = results.map(func(r): return r["seed_label"])
	assert_true("MAHO_CULT" in labels)
	assert_true("ONI_MANIFESTATION" in labels)

# -- Road Encounter --------------------------------------------------------

func test_road_encounter_garrison_met_always_false() -> void:
	var province := _make_province(1, 80.0)
	for s in range(20):
		var result: Dictionary = QuestSeedSelector.check_road_encounter(province, true, s)
		assert_false(result["triggered"])


func test_road_encounter_result_struct_when_not_triggered() -> void:
	# Find a seed that definitely doesn't trigger (sweep many)
	var province := _make_province(1, 80.0)
	var not_triggered: Dictionary = {}
	for s in range(100):
		var r := QuestSeedSelector.check_road_encounter(province, false, s)
		if not r["triggered"]:
			not_triggered = r
			break
	assert_false(not_triggered.is_empty())
	assert_eq(not_triggered["seed_type"], -1)
	assert_eq(not_triggered["strength"],  0)
	assert_eq(not_triggered["source"],    "road_encounter")


func test_road_encounter_triggered_at_some_seed() -> void:
	# Verify that at least one seed triggers (statistical sanity check on 15% rate)
	var province := _make_province(1, 80.0)
	var found_trigger := false
	for s in range(100):
		var r := QuestSeedSelector.check_road_encounter(province, false, s)
		if r["triggered"]:
			found_trigger = true
			break
	assert_true(found_trigger)


func test_road_encounter_triggered_result_struct() -> void:
	var province := _make_province(1, 80.0)
	# Find a seed that triggers
	var triggered: Dictionary = {}
	for s in range(100):
		var r := QuestSeedSelector.check_road_encounter(province, false, s)
		if r["triggered"]:
			triggered = r
			break
	assert_false(triggered.is_empty())
	assert_eq(triggered["seed_type"],   RosterCompositionSystem.SEED_RONIN_BANDIT)
	assert_eq(triggered["seed_label"],  "ROAD_ENCOUNTER")
	assert_eq(triggered["strength"],    1)
	assert_eq(triggered["options"]["stability"], 80)
	assert_true(triggered["roster_ready"])
	assert_eq(triggered["source_insurgency_id"], -1)


func test_road_encounter_different_provinces_different_rolls() -> void:
	# Determinism: same province+seed → same result; different province → possibly different
	var pA := _make_province(1, 80.0)
	var pB := _make_province(2, 80.0)
	var rA1 := QuestSeedSelector.check_road_encounter(pA, false, 42)
	var rA2 := QuestSeedSelector.check_road_encounter(pA, false, 42)
	assert_eq(rA1["triggered"], rA2["triggered"])
	# Different province with same seed may differ (not guaranteed, just structure check)
	var rB := QuestSeedSelector.check_road_encounter(pB, false, 42)
	assert_true(rB.has("triggered"))  # valid structure regardless of outcome


func test_road_encounter_carries_province_stability() -> void:
	var province := _make_province(5, 35.0)
	for s in range(100):
		var r := QuestSeedSelector.check_road_encounter(province, false, s)
		if r["triggered"]:
			assert_eq(r["options"]["stability"], 35)
			return
	# If no trigger in 100 tries, pass (extremely unlikely at 15%)
