extends GutTest
## GUT tests for MissionEntryPolicy (simulation/mission_entry_policy.gd).
## Verifies the LOCKED s56.19 per-seed-type entry classification.


func test_auto_seeds() -> void:
	assert_true(MissionEntryPolicy.is_auto(QuestSeedSelector.SEED_ROAD_ENCOUNTER),
		"ROAD_ENCOUNTER auto-launches (travel ambush)")
	assert_true(MissionEntryPolicy.is_auto(RosterCompositionSystem.SEED_RONIN_BANDIT),
		"RONIN_BANDIT auto-launches (bandit ambush)")
	assert_true(MissionEntryPolicy.is_auto(QuestSeedSelector.SEED_ONI_MANIFESTATION),
		"ONI_MANIFESTATION auto-launches (erupts)")
	assert_true(MissionEntryPolicy.is_auto(RosterCompositionSystem.SEED_TAINT_MANIFESTATION),
		"TAINT_MANIFESTATION auto-launches (erupts)")


func test_player_initiated_seeds() -> void:
	assert_true(MissionEntryPolicy.is_player_initiated(RosterCompositionSystem.SEED_MAHO_CULT),
		"MAHO_CULT is player-initiated (assault the cell)")
	assert_true(MissionEntryPolicy.is_player_initiated(
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK),
		"URBAN_CRIMINAL_NETWORK is player-initiated (raid the hideout)")
	assert_true(MissionEntryPolicy.is_player_initiated(
		RosterCompositionSystem.SEED_NEZUMI_INFESTATION),
		"NEZUMI_INFESTATION is player-initiated (clear the warren)")
	assert_true(MissionEntryPolicy.is_player_initiated(RosterCompositionSystem.SEED_PEASANT_REVOLT),
		"PEASANT_REVOLT is player-initiated (deliberate suppression)")
	assert_true(MissionEntryPolicy.is_player_initiated(RosterCompositionSystem.SEED_WALL_SORTIE),
		"WALL_SORTIE is player-initiated (choose to sortie)")


func test_auto_and_player_initiated_are_exclusive() -> void:
	var all_seeds: Array[int] = [
		QuestSeedSelector.SEED_ROAD_ENCOUNTER,
		QuestSeedSelector.SEED_ONI_MANIFESTATION,
		RosterCompositionSystem.SEED_RONIN_BANDIT,
		RosterCompositionSystem.SEED_TAINT_MANIFESTATION,
		RosterCompositionSystem.SEED_MAHO_CULT,
		RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK,
		RosterCompositionSystem.SEED_NEZUMI_INFESTATION,
		RosterCompositionSystem.SEED_PEASANT_REVOLT,
		RosterCompositionSystem.SEED_WALL_SORTIE,
	]
	for s: int in all_seeds:
		assert_ne(MissionEntryPolicy.is_auto(s), MissionEntryPolicy.is_player_initiated(s),
			"Each seed is exactly one of AUTO / PLAYER_INITIATED")


func test_unknown_seed_defaults_to_player_initiated() -> void:
	assert_true(MissionEntryPolicy.is_player_initiated(-1),
		"Unknown seed defaults to player-initiated (never auto-launch on contact)")
	assert_false(MissionEntryPolicy.is_auto(999),
		"Unknown seed is not AUTO")
