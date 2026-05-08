extends GutTest

# ==============================================================================
# Tests for succession system wiring into DayOrchestrator
# ==============================================================================

var _time: TimeSystem
var _dice: DiceEngine
var _scoring_tables: Dictionary
var _filter_data: Dictionary
var _action_skill_map: Dictionary
var _season_meta: Dictionary
var _action_log: Array[Dictionary]
var _provinces: Dictionary


func before_each() -> void:
	_time = TimeSystem.new(1120, 0)
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.terrain_type = Enums.TerrainType.PLAINS
	_provinces = {10: province}

	_action_log = []
	_season_meta = {}

	_scoring_tables = {
		"objective_alignment": {
			"REST": {"DO_NOTHING": 10, "REST": 50, "TRAIN": 30},
		},
		"personality_lean": {},
		"competence_table": {},
		"disposition_tiers": {},
		"urgency_rules": {},
		"topic_position_alignment": {},
	}
	_filter_data = {
		"personality_filter": {},
	}
	_action_skill_map = {
		"DO_NOTHING": {"skill": "none", "trait": "Awareness"},
		"REST": {"skill": "none", "trait": "Stamina"},
	}


func _make_char(id: int, clan: String = "Crane") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC %d" % id
	c.clan = clan
	c.family = "Doji"
	c.status = 3.0
	c.action_points_current = 2
	c.action_points_max = 2
	c.honor = 5.0
	c.glory = 3.0
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.reflexes = 3
	c.awareness = 3
	c.stamina = 3
	c.willpower = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	c.void_ring = 2
	c.skills = {"Etiquette": 3, "Kenjutsu": 3}
	c.emphases = {}
	c.wounds_taken = 0
	c.knowledge_pool = []
	c.known_contacts_by_clan = {}
	c.met_characters = []
	return c


func _run_day(
	characters: Array[L5RCharacterData],
	death_events: Array[Dictionary] = [],
	successor_map: Dictionary = {},
	active_successions: Array[SuccessionData] = [],
	next_succession_id: Array[int] = [1],
) -> Dictionary:
	var chars_by_id: Dictionary = {}
	for c in characters:
		chars_by_id[c.character_id] = c
	return DayOrchestrator.advance_day(
		_time, characters, chars_by_id, {},
		{}, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], [], [], [], [], [1], {}, {}, [1000],
		death_events, successor_map, [],
		[], [1], [], {},
		active_successions, next_succession_id,
	)


# ==============================================================================
# Lord death triggers succession
# ==============================================================================

func test_lord_death_creates_succession() -> void:
	var lord := _make_char(1)
	lord.status = 6.0
	lord.wounds_taken = 999
	var child := _make_char(10)
	child.age = 25
	lord.children_ids = [10]

	var confirmer := _make_char(20)
	confirmer.status = 7.0
	confirmer.clan = "Crane"
	confirmer.disposition_values[10] = 40

	var death_events: Array[Dictionary] = [
		{"character_id": 1, "is_lord": true, "position_tier": Enums.LordRank.PROVINCIAL_DAIMYO}
	]
	var active_successions: Array[SuccessionData] = []
	var next_id: Array[int] = [1]

	var result := _run_day(
		[lord, child, confirmer], death_events, {}, active_successions, next_id
	)

	assert_eq(active_successions.size(), 1)
	assert_eq(active_successions[0].deceased_id, 1)
	assert_eq(next_id[0], 2)


func test_clean_succession_auto_confirms() -> void:
	var lord := _make_char(1)
	lord.status = 6.0
	lord.wounds_taken = 999
	lord.designated_heir_id = 10
	var heir := _make_char(10)
	heir.honor = 8.0
	heir.glory = 5.0
	heir.status = 4.0

	var confirmer := _make_char(20)
	confirmer.status = 7.0
	confirmer.clan = "Crane"
	confirmer.disposition_values[10] = 50

	var death_events: Array[Dictionary] = [
		{"character_id": 1, "is_lord": true, "position_tier": Enums.LordRank.PROVINCIAL_DAIMYO}
	]
	var active_successions: Array[SuccessionData] = []
	var successor_map: Dictionary = {}

	_run_day(
		[lord, heir, confirmer], death_events, successor_map, active_successions
	)

	assert_eq(active_successions.size(), 1)
	assert_eq(active_successions[0].state, SuccessionData.SuccessionState.CONFIRMED)
	assert_eq(active_successions[0].successor_id, 10)
	assert_eq(successor_map.get(1, -1), 10)


func test_suspicious_death_creates_dispute() -> void:
	var lord := _make_char(1)
	lord.status = 6.0
	lord.wounds_taken = 999
	lord.designated_heir_id = 10
	var heir := _make_char(10)

	var confirmer := _make_char(20)
	confirmer.status = 7.0
	confirmer.clan = "Crane"
	confirmer.disposition_values[10] = 50

	var death_events: Array[Dictionary] = [
		{"character_id": 1, "is_lord": true,
		 "position_tier": Enums.LordRank.PROVINCIAL_DAIMYO,
		 "suspicious_death": true}
	]
	var active_successions: Array[SuccessionData] = []

	_run_day(
		[lord, heir, confirmer], death_events, {}, active_successions
	)

	assert_eq(active_successions.size(), 1)
	assert_eq(active_successions[0].state, SuccessionData.SuccessionState.DISPUTED)


func test_phoenix_champion_skipped() -> void:
	var lord := _make_char(1, "Phoenix")
	lord.family = "Shiba"
	lord.status = 8.0
	lord.wounds_taken = 999

	var death_events: Array[Dictionary] = [
		{"character_id": 1, "is_lord": true,
		 "position_tier": Enums.LordRank.CLAN_CHAMPION}
	]
	var active_successions: Array[SuccessionData] = []

	_run_day([lord], death_events, {}, active_successions)

	assert_eq(active_successions.size(), 0)


func test_succession_ticks_and_expires() -> void:
	var succ := SuccessionData.new()
	succ.succession_id = 1
	succ.state = SuccessionData.SuccessionState.DISPUTED
	succ.ticks_elapsed = 59
	succ.candidate_ids = [10]

	var candidate := _make_char(10)
	candidate.honor = 7.0

	var confirmer := _make_char(20)
	confirmer.status = 7.0
	confirmer.clan = "Crane"
	succ.confirming_authority_id = 20

	var active_successions: Array[SuccessionData] = [succ]

	_run_day([candidate, confirmer], [], {}, active_successions)

	assert_eq(succ.state, SuccessionData.SuccessionState.CONFIRMED)
	assert_eq(succ.successor_id, 10)


# ==============================================================================
# Heir designation during strategic review
# ==============================================================================

func test_lord_designates_heir_on_season_boundary() -> void:
	var lord := _make_char(1)
	lord.status = 6.0
	lord.lord_id = -1
	lord.designated_heir_id = -1
	var child := _make_char(10)
	child.age = 25
	lord.children_ids = [10]

	# Advance to season boundary
	for i in range(89):
		_time.advance_tick()

	var chars_by_id := {1: lord, 10: child}
	DayOrchestrator.advance_day(
		_time, [lord, child], chars_by_id, {},
		{}, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], [], [], [], [], [1], {}, {}, [1000],
		[], {}, [],
		[], [1], [], {},
		[], [1],
	)

	assert_eq(lord.designated_heir_id, 10)


func test_ishi_lord_does_not_reevaluate_heir() -> void:
	var lord := _make_char(1)
	lord.status = 6.0
	lord.lord_id = -1
	lord.shourido_virtue = Enums.ShouridoVirtue.ISHI
	lord.designated_heir_id = 10
	var old_child := _make_char(10)
	old_child.age = 20
	old_child.honor = 2.0
	var better_child := _make_char(11)
	better_child.age = 25
	better_child.honor = 9.0
	better_child.glory = 8.0
	better_child.status = 5.0
	lord.children_ids = [10, 11]

	for i in range(89):
		_time.advance_tick()

	var chars_by_id := {1: lord, 10: old_child, 11: better_child}
	DayOrchestrator.advance_day(
		_time, [lord, old_child, better_child], chars_by_id, {},
		{}, _scoring_tables, _filter_data, _dice,
		_action_skill_map, _provinces, _action_log, _season_meta,
		[], [], [], [], [], [1], {}, {}, [1000],
		[], {}, [],
		[], [1], [], {},
		[], [1],
	)

	assert_eq(lord.designated_heir_id, 10)


func test_major_favor_inherited_on_clean_succession() -> void:
	var lord := _make_char(1)
	lord.status = 6.0
	lord.wounds_taken = 999
	lord.designated_heir_id = 10
	var major_favor := FavorData.new()
	major_favor.tier = FavorData.FavorTier.MAJOR
	major_favor.creditor_id = 1
	lord.favors = [major_favor]

	var heir := _make_char(10)
	var confirmer := _make_char(20)
	confirmer.status = 7.0
	confirmer.clan = "Crane"
	confirmer.disposition_values[10] = 50

	var death_events: Array[Dictionary] = [
		{"character_id": 1, "is_lord": true,
		 "position_tier": Enums.LordRank.PROVINCIAL_DAIMYO}
	]

	_run_day([lord, heir, confirmer], death_events)

	assert_eq(heir.favors.size(), 1)
	assert_eq(heir.favors[0].tier, FavorData.FavorTier.MAJOR)


func test_non_lord_death_no_succession() -> void:
	var npc := _make_char(1)
	npc.wounds_taken = 999

	var death_events: Array[Dictionary] = [
		{"character_id": 1, "is_lord": false}
	]
	var active_successions: Array[SuccessionData] = []

	_run_day([npc], death_events, {}, active_successions)

	assert_eq(active_successions.size(), 0)
