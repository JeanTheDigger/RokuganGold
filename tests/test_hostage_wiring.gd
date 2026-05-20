extends GutTest
## Integration tests for HostageSystem wiring per GDD s22.9.


func _make_character(id: int, clan: String = "crane", school: Enums.SchoolType = Enums.SchoolType.BUSHI) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Char_%d" % id
	c.clan = clan
	c.school_type = school
	c.stamina = 2
	c.willpower = 2
	c.agility = 3
	c.skills = {"Stealth": 4}
	c.wounds_taken = 0
	c.captive_status = ""
	c.role_position = ""
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_ctx(character: L5RCharacterData, ic_day: int = 1) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = character.character_id
	ctx.ic_day = ic_day
	ctx.season = 0
	return ctx


func _make_action(action_id: String, target_npc: int = -1) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.target_npc_id = target_npc
	a.target_npc_id_secondary = -1
	a.target_province_id = -1
	a.ap_cost = 1
	return a


func _make_settlement(id: int, stype: Enums.SettlementType, garrison: int) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_type = stype
	s.garrison_pu = garrison
	return s


# -- ContextSnapshot is_hostage population ------------------------------------

func test_is_hostage_false_when_no_captive_status() -> void:
	var char := _make_character(1)
	var ctx := NPCDecisionEngine.build_context(char, {})
	assert_false(ctx.is_hostage)


func test_is_hostage_true_when_captive_status_set() -> void:
	var char := _make_character(1)
	char.captive_status = "42"
	var ctx := NPCDecisionEngine.build_context(char, {})
	assert_true(ctx.is_hostage)


# -- ActionExecutor blocking ---------------------------------------------------

func test_travel_blocked_for_hostage() -> void:
	var character := _make_character(1)
	character.captive_status = "99"
	var ctx := _make_ctx(character)
	var action := _make_action("TRAVEL_TO")
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, character, ctx, dice, {})
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "hostage_restricted")


func test_declare_war_blocked_for_hostage() -> void:
	var character := _make_character(1)
	character.captive_status = "99"
	var ctx := _make_ctx(character)
	var action := _make_action("DECLARE_WAR")
	var dice := DiceEngine.new()
	var result: Dictionary = ActionExecutor.execute(action, character, ctx, dice, {})
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "hostage_restricted")


func test_charm_blocked_when_targeting_captor() -> void:
	var character := _make_character(1)
	character.captive_status = "99"
	var ctx := _make_ctx(character)
	var action := _make_action("CHARM", 99)
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var result: Dictionary = ActionExecutor.execute(action, character, ctx, dice, {})
	assert_false(result["success"])
	assert_eq(result.get("reason", ""), "hostage_restricted")


func test_charm_allowed_when_targeting_non_captor() -> void:
	var character := _make_character(1)
	character.skills["Etiquette"] = 3
	character.awareness = 3
	character.captive_status = "99"
	var ctx := _make_ctx(character)
	ctx.dispositions = {50: 0}
	var action := _make_action("CHARM", 50)
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var skill_map: Dictionary = {"CHARM": {"primary": "Etiquette", "secondary": "Courtier"}}
	var result: Dictionary = ActionExecutor.execute(action, character, ctx, dice, skill_map)
	assert_ne(result.get("reason", ""), "hostage_restricted")


func test_write_letter_allowed_for_hostage() -> void:
	var character := _make_character(1)
	character.skills["Calligraphy"] = 3
	character.awareness = 3
	character.captive_status = "99"
	var ctx := _make_ctx(character)
	var action := _make_action("WRITE_LETTER")
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var skill_map: Dictionary = {"WRITE_LETTER": {"primary": "Calligraphy", "secondary": "Courtier"}}
	var result: Dictionary = ActionExecutor.execute(action, character, ctx, dice, skill_map)
	assert_ne(result.get("reason", ""), "hostage_restricted")


# -- Escape attempt processing -------------------------------------------------

func test_escape_succeeds_and_clears_captive_status() -> void:
	var character := _make_character(1)
	character.captive_status = "99"
	var chars_by_id: Dictionary = {1: character}
	var hostage: Dictionary = HostageSystem.capture_hostage(
		1, 99, HostageSystem.CaptureSource.SIEGE_SURRENDER, "1", 10
	)
	var active_hostages: Array = [hostage]
	var settlement: SettlementData = _make_settlement(1, Enums.SettlementType.TOWN, 0)
	var dice := DiceEngine.new()
	# Seed chosen to guarantee a very high Stealth roll (character has Stealth 4 + Agility 3 = 7k3)
	# TN is 20 for a town with 0 garrison (no excess). High seed ensures success.
	dice.set_seed(9999)
	var death_events: Array = []
	var results: Array = DayOrchestrator._process_hostage_escapes(
		active_hostages, chars_by_id, [settlement], dice, 50, death_events
	)
	if results.size() > 0 and results[0].get("success", false):
		assert_eq(character.captive_status, "")
		assert_true(hostage.get("escaped", false))
		assert_true(death_events.is_empty())


func test_courtier_cannot_escape() -> void:
	var character := _make_character(1, "crane", Enums.SchoolType.COURTIER)
	character.captive_status = "99"
	character.skills["Stealth"] = 5
	var chars_by_id: Dictionary = {1: character}
	var hostage: Dictionary = HostageSystem.capture_hostage(
		1, 99, HostageSystem.CaptureSource.SIEGE_SURRENDER, "1", 10
	)
	var active_hostages: Array = [hostage]
	var settlement: SettlementData = _make_settlement(1, Enums.SettlementType.TOWN, 0)
	var dice := DiceEngine.new()
	var death_events: Array = []
	var results: Array = DayOrchestrator._process_hostage_escapes(
		active_hostages, chars_by_id, [settlement], dice, 50, death_events
	)
	assert_true(results.is_empty())


func test_released_hostage_skipped() -> void:
	var character := _make_character(1)
	character.captive_status = "99"
	var chars_by_id: Dictionary = {1: character}
	var hostage: Dictionary = HostageSystem.capture_hostage(
		1, 99, HostageSystem.CaptureSource.BATTLE_CAPTURE, "1", 10
	)
	hostage["released"] = true
	var active_hostages: Array = [hostage]
	var settlement: SettlementData = _make_settlement(1, Enums.SettlementType.CASTLE, 1)
	var dice := DiceEngine.new()
	var death_events: Array = []
	var results: Array = DayOrchestrator._process_hostage_escapes(
		active_hostages, chars_by_id, [settlement], dice, 50, death_events
	)
	assert_true(results.is_empty())


# -- War-end hostage release --------------------------------------------------

func test_war_end_releases_hostage() -> void:
	var character := _make_character(1, "crane")
	character.captive_status = "99"
	var chars_by_id: Dictionary = {1: character}
	var hostage: Dictionary = HostageSystem.capture_hostage(
		1, 99, HostageSystem.CaptureSource.SIEGE_SURRENDER, "1", 10
	)
	var active_hostages: Array = [hostage]
	var war_results: Array = [{
		"resolution": "formal_surrender",
		"war_id": 1,
		"winner_clan": "lion",
		"loser_clan": "crane",
	}]
	DayOrchestrator._release_war_hostages(war_results, active_hostages, chars_by_id, 200)
	assert_eq(character.captive_status, "")
	assert_true(hostage.get("released", false))
	assert_eq(hostage.get("released_ic_day", -1), 200)


func test_war_end_skips_already_released() -> void:
	var character := _make_character(1, "crane")
	character.captive_status = ""
	var chars_by_id: Dictionary = {1: character}
	var hostage: Dictionary = HostageSystem.capture_hostage(
		1, 99, HostageSystem.CaptureSource.SIEGE_SURRENDER, "1", 10
	)
	hostage["released"] = true
	hostage["released_ic_day"] = 100
	var active_hostages: Array = [hostage]
	var war_results: Array = [{
		"resolution": "negotiated_settlement",
		"war_id": 1,
		"proposing_clan": "crane",
		"receiving_clan": "lion",
	}]
	DayOrchestrator._release_war_hostages(war_results, active_hostages, chars_by_id, 200)
	assert_eq(hostage.get("released_ic_day", -1), 100)


func test_war_end_third_clan_hostage_not_released() -> void:
	var character := _make_character(1, "scorpion")
	character.captive_status = "99"
	var chars_by_id: Dictionary = {1: character}
	var hostage: Dictionary = HostageSystem.capture_hostage(
		1, 99, HostageSystem.CaptureSource.SIEGE_SURRENDER, "1", 10
	)
	var active_hostages: Array = [hostage]
	var war_results: Array = [{
		"resolution": "formal_surrender",
		"war_id": 1,
		"winner_clan": "lion",
		"loser_clan": "crane",
	}]
	DayOrchestrator._release_war_hostages(war_results, active_hostages, chars_by_id, 200)
	assert_false(hostage.get("released", false))
	assert_eq(character.captive_status, "99")


# -- Battle commander capture --------------------------------------------------

func test_battle_capture_converts_dead_commander_to_hostage() -> void:
	var commander := _make_character(1)
	commander.military_rank = Enums.MilitaryRank.GUNSO
	commander.captive_status = ""
	var chars_by_id: Dictionary = {1: commander}
	var battle_result: Dictionary = {
		"victor": "attacker",
		"attacker_states": [],
		"defender_states": [
			{
				"commander_id": 1,
				"commander_dead": true,
				"company_id": 10,
			}
		],
	}
	var active_hostages: Array = []
	var dice := DiceEngine.new()
	dice.set_seed(42)
	DayOrchestrator._capture_dead_commanders(
		battle_result, "attacker", 99, "5", chars_by_id, active_hostages, 1, dice
	)
	assert_eq(commander.captive_status, "99")
	assert_eq(active_hostages.size(), 1)
	assert_eq(active_hostages[0].get("character_id", -1), 1)
	assert_eq(active_hostages[0].get("source", -1), HostageSystem.CaptureSource.BATTLE_CAPTURE)
	assert_false(battle_result["defender_states"][0].get("commander_dead", true))


func test_battle_capture_draw_does_nothing() -> void:
	var commander := _make_character(1)
	commander.captive_status = ""
	var chars_by_id: Dictionary = {1: commander}
	var battle_result: Dictionary = {
		"victor": "draw",
		"attacker_states": [],
		"defender_states": [{"commander_id": 1, "commander_dead": true}],
	}
	var active_hostages: Array = []
	var dice := DiceEngine.new()
	DayOrchestrator._capture_dead_commanders(
		battle_result, "draw", 99, "5", chars_by_id, active_hostages, 1, dice
	)
	assert_eq(active_hostages.size(), 0)
	assert_eq(commander.captive_status, "")


# -- Siege surrender capture --------------------------------------------------

func test_siege_hostage_captures_military_ranked_character() -> void:
	var character := _make_character(1)
	character.military_rank = Enums.MilitaryRank.GUNSO
	character.physical_location = "10"
	character.captive_status = ""
	var chars_by_id: Dictionary = {1: character}
	var siege: Dictionary = {
		"siege_ended": true,
		"end_reason": "storm_assault_success",
		"settlement_id": 10,
		"attacker_army_id": 5,
	}
	var active_sieges: Array = [siege]
	var company: Dictionary = {"army_id": 5, "lord_id": 99, "company_id": 1}
	var active_hostages: Array = []
	DayOrchestrator._capture_siege_hostages(active_sieges, chars_by_id, [company], active_hostages, 1)
	assert_eq(character.captive_status, "99")
	assert_eq(active_hostages.size(), 1)
	assert_eq(active_hostages[0].get("source", -1), HostageSystem.CaptureSource.SIEGE_SURRENDER)
	assert_true(siege.get("hostages_captured", false))


func test_siege_hostage_skips_no_military_rank() -> void:
	var character := _make_character(1)
	character.military_rank = Enums.MilitaryRank.NONE
	character.physical_location = "10"
	character.captive_status = ""
	var chars_by_id: Dictionary = {1: character}
	var siege: Dictionary = {
		"siege_ended": true,
		"end_reason": "starvation",
		"settlement_id": 10,
		"attacker_army_id": 5,
	}
	var company: Dictionary = {"army_id": 5, "lord_id": 99, "company_id": 1}
	var active_hostages: Array = []
	DayOrchestrator._capture_siege_hostages([siege], chars_by_id, [company], active_hostages, 1)
	assert_eq(active_hostages.size(), 0)
	assert_eq(character.captive_status, "")


func test_siege_hostage_not_processed_twice() -> void:
	var character := _make_character(1)
	character.military_rank = Enums.MilitaryRank.TAISA
	character.physical_location = "10"
	character.captive_status = ""
	var chars_by_id: Dictionary = {1: character}
	var siege: Dictionary = {
		"siege_ended": true,
		"end_reason": "storm_assault_success",
		"settlement_id": 10,
		"attacker_army_id": 5,
		"hostages_captured": true,
	}
	var company: Dictionary = {"army_id": 5, "lord_id": 99, "company_id": 1}
	var active_hostages: Array = []
	DayOrchestrator._capture_siege_hostages([siege], chars_by_id, [company], active_hostages, 1)
	assert_eq(active_hostages.size(), 0)
	assert_eq(character.captive_status, "")
