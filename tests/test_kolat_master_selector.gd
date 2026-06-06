extends GutTest
## GUT tests for KolatMasterSelector (simulation/kolat_master_selector.gd).
## GDD s54.7a / s54.7j.


## Build a high-insight NPC (rings 4 → Insight Rank ≥ 3) with given attributes.
func _npc(id: int, skills: Dictionary = {}, clan: String = "", family: String = "",
		role: String = "", st: Enums.SchoolType = Enums.SchoolType.BUSHI,
		status: float = 1.0, glory: float = 1.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.reflexes = 4; c.awareness = 4; c.stamina = 4; c.willpower = 4
	c.agility = 4; c.intelligence = 4; c.strength = 4; c.perception = 4
	c.void_ring = 4
	c.skills = skills.duplicate()
	c.clan = clan; c.family = family; c.role_position = role
	c.school_type = st; c.status = status; c.glory = glory
	return c


func _tiger_candidate(id: int) -> L5RCharacterData:
	return _npc(id, {"Courtier (Manipulation)": 4, "Investigation": 5}, "Scorpion", "Bayushi", "Clan Champion")


func test_assigns_one_master_per_eligible_sect() -> void:
	var t := _tiger_candidate(1)
	var got := KolatMasterSelector.select_masters([t], DiceEngine.new(1))
	assert_eq(got[Enums.KolatSect.TIGER], 1, "the lone Tiger candidate is selected")
	assert_true(t.is_kolat_master)
	assert_eq(t.kolat_sect, Enums.KolatSect.TIGER)


func test_tiger_superior_is_null_others_point_to_tiger() -> void:
	var t := _tiger_candidate(1)
	var coin := _npc(2, {"Commerce": 5}, "Crab", "Yasuki", "Family Daimyo")
	var got := KolatMasterSelector.select_masters([t, coin], DiceEngine.new(2))
	assert_eq(t.kolat_superior_id, -1, "Tiger reports to no one")
	assert_eq(got[Enums.KolatSect.COIN], 2)
	assert_eq(coin.kolat_superior_id, 1, "other Masters report to Tiger")


func test_conflict_resolution_first_sect_claims() -> void:
	# A Scorpion magistrate qualifies for Tiger; also has Acting/Courtier for Silk.
	var both := _npc(1, {
		"Courtier (Manipulation)": 4, "Investigation": 5,
		"Acting": 4, "Courtier": 4, "Sincerity (Deceit)": 4,
	}, "Scorpion", "Bayushi", "Clan Champion")
	var got := KolatMasterSelector.select_masters([both], DiceEngine.new(3))
	assert_eq(got[Enums.KolatSect.TIGER], 1, "Tiger (processed first) claims them")
	assert_eq(got[Enums.KolatSect.SILK], -1, "Silk left vacant — candidate already taken")


func test_insufficient_insight_excluded() -> void:
	var weak := _tiger_candidate(1)
	weak.reflexes = 1; weak.awareness = 1; weak.stamina = 1; weak.willpower = 1
	weak.agility = 1; weak.intelligence = 1; weak.strength = 1; weak.perception = 1
	weak.void_ring = 1  # Insight Rank 1
	var got := KolatMasterSelector.select_masters([weak], DiceEngine.new(4))
	assert_eq(got[Enums.KolatSect.TIGER], -1, "Insight < 3 is filtered out")


func test_emperor_excluded() -> void:
	var emp := _tiger_candidate(1)
	emp.role_position = "Emperor"
	var got := KolatMasterSelector.select_masters([emp], DiceEngine.new(5))
	assert_eq(got[Enums.KolatSect.TIGER], -1, "the Emperor can never be a Master")


func test_coin_requires_lord_tier() -> void:
	var not_lord := _npc(1, {"Commerce": 5}, "Crab", "Yasuki", "Courtier")  # no daimyo seat
	var got := KolatMasterSelector.select_masters([not_lord], DiceEngine.new(6))
	assert_eq(got[Enums.KolatSect.COIN], -1, "Coin minimum requires lord-tier")


func test_skill_boosts_max_rule() -> void:
	var t := _tiger_candidate(1)
	t.skills["Investigation"] = 9  # already above the boost (7)
	KolatMasterSelector.select_masters([t], DiceEngine.new(7))
	assert_eq(t.skills["Investigation"], 9, "boost never lowers an already-higher skill")
	assert_eq(t.skills["Sincerity (Deceit)"], 7, "Tiger boost applied where higher")


func test_vacant_seat_when_no_candidate() -> void:
	# A pool with only a Tiger candidate leaves most seats vacant.
	var got := KolatMasterSelector.select_masters([_tiger_candidate(1)], DiceEngine.new(8))
	assert_eq(got[Enums.KolatSect.DREAM], -1)
	assert_eq(got[Enums.KolatSect.LOTUS], -1)


func test_special_rule_flags() -> void:
	var dice := DiceEngine.new(9)
	var coin_flags := KolatMasterSelector.get_special_rule_flags(Enums.KolatSect.COIN, dice)
	assert_true(coin_flags.has("hidden_kolat_koku"))
	assert_true(coin_flags["hidden_kolat_koku"] >= 20 and coin_flags["hidden_kolat_koku"] <= 200,
		"2d10×10 reserve in [20,200]")
	var dream_flags := KolatMasterSelector.get_special_rule_flags(Enums.KolatSect.DREAM, dice)
	assert_true(dream_flags["world_start_sleepers"] >= 3 and dream_flags["world_start_sleepers"] <= 8,
		"1d6+2 sleepers in [3,8]")
	var silk_flags := KolatMasterSelector.get_special_rule_flags(Enums.KolatSect.SILK, dice)
	assert_true(silk_flags["preplaced_contacts"] >= 3 and silk_flags["preplaced_contacts"] <= 8)


# === Tranche 7: special-rule world mutation applied at selection ===

func test_coin_master_gets_hidden_koku() -> void:
	var coin := _npc(2, {"Commerce": 5}, "Crab", "Yasuki", "Family Daimyo")
	KolatMasterSelector.select_masters([coin], DiceEngine.new(11))
	assert_true(coin.kolat_koku >= 20 and coin.kolat_koku <= 200,
		"Coin Master receives a 2d10×10 hidden reserve at selection")


func test_dream_master_records_sleeper_count() -> void:
	var dream := _npc(3, {"Temptation": 5, "Intimidation (Control)": 3, "Medicine": 4})
	KolatMasterSelector.select_masters([dream], DiceEngine.new(12))
	assert_eq(dream.kolat_sect, Enums.KolatSect.DREAM)
	var n: int = dream.special_data.get("world_start_sleepers", 0)
	assert_true(n >= 3 and n <= 8, "Dream Master records a 1d6+2 world-start sleeper target")


func test_non_coin_master_has_no_hidden_koku() -> void:
	var t := _tiger_candidate(1)
	KolatMasterSelector.select_masters([t], DiceEngine.new(13))
	assert_eq(t.kolat_koku, 0, "non-Coin Masters receive no koku reserve")
