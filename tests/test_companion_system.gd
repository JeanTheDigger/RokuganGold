extends GutTest
## GUT tests for CompanionSystem (simulation/companion_system.gd). GDD s57.46 / s57.46a.


func _comp(type: CompanionData.CompanionType) -> CompanionData:
	var c := CompanionData.new()
	c.companion_id = 1
	c.type = type
	return c


# === Slots ===

func test_slot_cap() -> void:
	var roster: Array = []
	for i: int in range(CompanionSystem.MAX_SLOTS):
		roster.append(_comp(CompanionData.CompanionType.VILLAGE_DOSHIN))
	assert_false(CompanionSystem.can_add_companion(roster), "6 slots is the hard cap")
	roster.pop_back()
	assert_true(CompanionSystem.can_add_companion(roster), "room for one more under cap")


# === Command availability ===

func test_universal_commands_for_named_ally() -> void:
	var cmds := CompanionSystem.available_commands(CompanionData.CompanionType.NAMED_ALLY)
	assert_true(CompanionData.Command.FOLLOW in cmds)
	assert_true(CompanionData.Command.RETREAT in cmds)
	assert_false(CompanionData.Command.GUARD_EXIT in cmds, "named ally has no doshin commands")
	assert_false(CompanionData.Command.PROTECT in cmds)


func test_doshin_commands() -> void:
	var cmds := CompanionSystem.available_commands(CompanionData.CompanionType.CITY_DOSHIN_TEAM)
	assert_true(CompanionData.Command.GUARD_EXIT in cmds)
	assert_true(CompanionData.Command.IDENTIFY in cmds)
	assert_true(CompanionData.Command.SEARCH_AREA in cmds)
	assert_false(CompanionData.Command.PROTECT in cmds)


func test_yojimbo_protect_yoriki_investigate() -> void:
	assert_true(CompanionData.Command.PROTECT in
		CompanionSystem.available_commands(CompanionData.CompanionType.YOJIMBO))
	assert_true(CompanionData.Command.INVESTIGATE in
		CompanionSystem.available_commands(CompanionData.CompanionType.YORIKI))


func test_assign_command_blocked_when_broken() -> void:
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	c.morale = CompanionData.Morale.BROKEN
	assert_false(CompanionSystem.assign_command(c, CompanionData.Command.HOLD),
		"broken companion takes no new orders")


func test_shaken_only_accepts_retreat() -> void:
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	c.morale = CompanionData.Morale.SHAKEN
	assert_false(CompanionSystem.assign_command(c, CompanionData.Command.HOLD),
		"shaken companion cannot be told to hold")
	assert_true(CompanionSystem.assign_command(c, CompanionData.Command.RETREAT),
		"shaken companion can be told to retreat")


# === AI priority stack ===

func test_broken_overrides_command_with_retreat() -> void:
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	c.command = CompanionData.Command.HOLD
	c.morale = CompanionData.Morale.BROKEN
	assert_eq(CompanionSystem.decide_action(c), CompanionData.Command.RETREAT,
		"SURVIVAL priority forces FLEE/RETREAT")


func test_player_command_executed_when_steady() -> void:
	var c := _comp(CompanionData.CompanionType.YOJIMBO)
	c.command = CompanionData.Command.PROTECT
	assert_eq(CompanionSystem.decide_action(c), CompanionData.Command.PROTECT)


func test_default_is_follow() -> void:
	var c := _comp(CompanionData.CompanionType.NAMED_ALLY)
	assert_eq(CompanionSystem.decide_action(c), CompanionData.Command.FOLLOW)


# === Morale thresholds and transitions ===

func test_thresholds_by_type() -> void:
	assert_eq(CompanionSystem.morale_threshold(_comp(CompanionData.CompanionType.VILLAGE_DOSHIN)), 0.30)
	assert_eq(CompanionSystem.morale_threshold(_comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM)), 0.40)
	assert_eq(CompanionSystem.morale_threshold(_comp(CompanionData.CompanionType.DOSHIN_HEADMAN)), 0.50)
	assert_eq(CompanionSystem.morale_threshold(_comp(CompanionData.CompanionType.YOJIMBO)), -1.0,
		"yojimbo never breaks")


func test_named_ally_threshold_by_yu() -> void:
	var hi := _comp(CompanionData.CompanionType.NAMED_ALLY); hi.yu_rank = 8
	var mid := _comp(CompanionData.CompanionType.NAMED_ALLY); mid.yu_rank = 5
	var lo := _comp(CompanionData.CompanionType.NAMED_ALLY); lo.yu_rank = 2
	assert_eq(CompanionSystem.morale_threshold(hi), 0.50)
	assert_eq(CompanionSystem.morale_threshold(mid), 0.35)
	assert_eq(CompanionSystem.morale_threshold(lo), 0.20)


func test_yoriki_threshold_school_dependent() -> void:
	var bushi_hi := _comp(CompanionData.CompanionType.YORIKI)
	bushi_hi.is_bushi_school = true; bushi_hi.yu_rank = 7
	assert_eq(CompanionSystem.morale_threshold(bushi_hi), 0.50)
	var bushi_lo := _comp(CompanionData.CompanionType.YORIKI)
	bushi_lo.is_bushi_school = true; bushi_lo.yu_rank = 2
	assert_eq(CompanionSystem.morale_threshold(bushi_lo), 0.30)
	var non_bushi := _comp(CompanionData.CompanionType.YORIKI)
	assert_eq(CompanionSystem.morale_threshold(non_bushi), 0.35)


func test_morale_transitions() -> void:
	# Village doshin threshold 0.30 → SHAKEN at 0.15, BROKEN at 0.30.
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	assert_eq(CompanionSystem.update_morale(c, 0.10), CompanionData.Morale.STEADY)
	assert_eq(CompanionSystem.update_morale(c, 0.20), CompanionData.Morale.SHAKEN)
	assert_eq(CompanionSystem.update_morale(c, 0.30), CompanionData.Morale.BROKEN)


func test_yojimbo_never_breaks() -> void:
	var y := _comp(CompanionData.CompanionType.YOJIMBO)
	assert_eq(CompanionSystem.update_morale(y, 0.99), CompanionData.Morale.STEADY,
		"yojimbo stays steady at total party loss")


func test_morale_does_not_unbreak() -> void:
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	CompanionSystem.update_morale(c, 0.40)  # broken
	assert_eq(CompanionSystem.update_morale(c, 0.0), CompanionData.Morale.BROKEN,
		"a broken companion does not recover this mission")


func test_relieve_shaken() -> void:
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	c.morale = CompanionData.Morale.SHAKEN
	assert_eq(CompanionSystem.relieve_shaken(c, true, 0), CompanionData.Morale.STEADY,
		"threat cleared clears shaken")
	c.morale = CompanionData.Morale.SHAKEN
	assert_eq(CompanionSystem.relieve_shaken(c, false, 12), CompanionData.Morale.STEADY,
		"far from enemy clears shaken")
	c.morale = CompanionData.Morale.SHAKEN
	assert_eq(CompanionSystem.relieve_shaken(c, false, 3), CompanionData.Morale.SHAKEN,
		"still near an active threat stays shaken")


func test_combat_penalty() -> void:
	var c := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	assert_eq(CompanionSystem.combat_penalty(c), 0)
	c.morale = CompanionData.Morale.SHAKEN
	assert_eq(CompanionSystem.combat_penalty(c), -5)


# === Noise ===

func test_doshin_noise_bases() -> void:
	assert_eq(CompanionSystem.noise_contribution(_comp(CompanionData.CompanionType.VILLAGE_DOSHIN)), 1.0)
	assert_eq(CompanionSystem.noise_contribution(_comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM)), 0.5)
	assert_eq(CompanionSystem.noise_contribution(_comp(CompanionData.CompanionType.DOSHIN_HEADMAN)), 0.75)


func test_samurai_noise_by_stealth() -> void:
	var y := _comp(CompanionData.CompanionType.YOJIMBO)
	y.stealth_rank = 0
	assert_eq(CompanionSystem.noise_contribution(y), 1.0)
	y.stealth_rank = 1
	assert_eq(CompanionSystem.noise_contribution(y), 0.5)
	y.stealth_rank = 3
	assert_eq(CompanionSystem.noise_contribution(y), 0.0)


func test_party_noise_sum() -> void:
	# s57.46.13 worked example: 2 city teams (0.5+0.5) + yoriki St0 (1.0) +
	# yojimbo St0 (1.0) = 3.0.
	var roster: Array = [
		_comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM),
		_comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM),
	]
	var yoriki := _comp(CompanionData.CompanionType.YORIKI); yoriki.stealth_rank = 0
	var yojimbo := _comp(CompanionData.CompanionType.YOJIMBO); yojimbo.stealth_rank = 0
	roster.append(yoriki); roster.append(yojimbo)
	assert_eq(CompanionSystem.party_noise_contribution(roster), 3.0)


# === Doshin rules ===

func test_teamwork_bonus() -> void:
	var team := _comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM); team.team_size = 2
	assert_eq(CompanionSystem.teamwork_grapple_bonus(team), 5)
	team.team_size = 1
	assert_eq(CompanionSystem.teamwork_grapple_bonus(team), 0, "bonus lost when down to 1")
	assert_eq(CompanionSystem.teamwork_grapple_bonus(_comp(CompanionData.CompanionType.VILLAGE_DOSHIN)), 0)


func test_samurai_avoidance() -> void:
	var d := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN)
	assert_false(CompanionSystem.will_engage_samurai(d, true, false, false),
		"doshin refuses a samurai with no warrant")
	assert_false(CompanionSystem.will_engage_samurai(d, true, true, false),
		"village doshin still refuses a warranted samurai without a headman")
	assert_true(CompanionSystem.will_engage_samurai(d, true, true, true),
		"village doshin acts with warrant + headman present")
	var city := _comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM)
	assert_true(CompanionSystem.will_engage_samurai(city, true, true, false),
		"city doshin act on a warrant")
	assert_true(CompanionSystem.will_engage_samurai(d, false, false, false),
		"doshin engage non-samurai freely")
	assert_true(CompanionSystem.will_engage_samurai(_comp(CompanionData.CompanionType.YOJIMBO), true, false, false),
		"non-doshin unaffected by samurai avoidance")


func test_guard_exit_penalty() -> void:
	var d := _comp(CompanionData.CompanionType.CITY_DOSHIN_TEAM)
	assert_eq(CompanionSystem.guard_exit_penalty(d, true), -10, "−10 vs a fleeing samurai")
	assert_eq(CompanionSystem.guard_exit_penalty(d, false), 0)


# === Death consequences ===

func test_doshin_death_increments_losses() -> void:
	var d := _comp(CompanionData.CompanionType.VILLAGE_DOSHIN); d.home_settlement_id = 7
	var r := CompanionSystem.death_consequences(d)
	assert_true(r["doshin_loss"])
	assert_false(r["named_vacancy"])
	assert_eq(r["settlement_id"], 7)


func test_named_death_vacancy_and_topic() -> void:
	var y := _comp(CompanionData.CompanionType.YOJIMBO); y.character_id = 42
	var r := CompanionSystem.death_consequences(y)
	assert_true(r["named_vacancy"])
	assert_true(r["generate_topic"])
	assert_false(r["doshin_loss"])
	assert_eq(r["character_id"], 42)
