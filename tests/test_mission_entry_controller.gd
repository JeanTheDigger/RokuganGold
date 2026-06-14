extends GutTest
## GUT tests for MissionEntryController (simulation/mission_entry_controller.gd)
## and the PcSystem banked-AP spend helpers (s60.5). GDD s56.19.


func _pc(banked: int = 4) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 501
	c.is_pc = true
	c.banked_ap = banked
	return c


func _npc() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 502
	c.is_pc = false
	c.banked_ap = 4
	return c


func _auto_seed() -> Dictionary:
	return {"seed_type": QuestSeedSelector.SEED_ROAD_ENCOUNTER, "strength": 2}


func _player_seed() -> Dictionary:
	return {"seed_type": RosterCompositionSystem.SEED_MAHO_CULT, "strength": 3}


# -- PcSystem banked-AP spend -------------------------------------------------

func test_spend_banked_ap_deducts() -> void:
	var pc := _pc(3)
	var r := PcSystem.spend_banked_ap(pc, 1)
	assert_true(r.get("success", false), "Spend succeeds with enough banked AP")
	assert_eq(pc.banked_ap, 2, "1 AP deducted from banked pool")


func test_spend_banked_ap_insufficient() -> void:
	var pc := _pc(0)
	var r := PcSystem.spend_banked_ap(pc, 1)
	assert_false(r.get("success", true), "Spend fails with no banked AP")
	assert_eq(pc.banked_ap, 0, "No AP deducted on failure")


func test_can_spend_banked_ap() -> void:
	assert_true(PcSystem.can_spend_banked_ap(_pc(1), 1))
	assert_false(PcSystem.can_spend_banked_ap(_pc(0), 1))


# -- Seed filtering -----------------------------------------------------------

func test_get_auto_launch_seeds_filters_auto() -> void:
	var seeds: Array = [_auto_seed(), _player_seed()]
	var auto: Array = MissionEntryController.get_auto_launch_seeds(seeds)
	assert_eq(auto.size(), 1, "Only the AUTO seed is returned")
	assert_eq(auto[0].get("seed_type"), QuestSeedSelector.SEED_ROAD_ENCOUNTER)


func test_get_engageable_seeds_filters_player_initiated() -> void:
	var seeds: Array = [_auto_seed(), _player_seed()]
	var eng: Array = MissionEntryController.get_engageable_seeds(seeds)
	assert_eq(eng.size(), 1, "Only the PLAYER_INITIATED seed is returned")
	assert_eq(eng[0].get("seed_type"), RosterCompositionSystem.SEED_MAHO_CULT)


# -- ENGAGE_MISSION -----------------------------------------------------------

func test_engage_mission_spends_one_ap() -> void:
	var pc := _pc(2)
	var r := MissionEntryController.engage_mission(pc, _player_seed())
	assert_true(r.get("ok", false), "Engage succeeds on a player-initiated seed")
	assert_eq(pc.banked_ap, 1, "ENGAGE_MISSION costs 1 banked AP")
	assert_eq(r.get("seed", {}).get("seed_type"), RosterCompositionSystem.SEED_MAHO_CULT,
		"Launch request carries the chosen seed")


func test_engage_mission_rejects_auto_seed() -> void:
	var pc := _pc(2)
	var r := MissionEntryController.engage_mission(pc, _auto_seed())
	assert_false(r.get("ok", true), "AUTO seeds cannot be engaged via ENGAGE_MISSION")
	assert_eq(r.get("reason"), "not_player_initiated")
	assert_eq(pc.banked_ap, 2, "No AP spent on a rejected engage")


func test_engage_mission_rejects_npc() -> void:
	var npc := _npc()
	var r := MissionEntryController.engage_mission(npc, _player_seed())
	assert_false(r.get("ok", true), "NPCs cannot engage ASCII missions")
	assert_eq(r.get("reason"), "not_a_pc")


func test_engage_mission_requires_ap() -> void:
	var pc := _pc(0)
	var r := MissionEntryController.engage_mission(pc, _player_seed())
	assert_false(r.get("ok", true), "Engage fails without banked AP")
	assert_eq(r.get("reason"), "insufficient_ap")


func test_can_engage_mission_gates_on_pc_and_ap() -> void:
	assert_true(MissionEntryController.can_engage_mission(_pc(1)), "PC with AP can engage")
	assert_false(MissionEntryController.can_engage_mission(_pc(0)), "PC without AP cannot")
	assert_false(MissionEntryController.can_engage_mission(_npc()), "NPC cannot engage")
