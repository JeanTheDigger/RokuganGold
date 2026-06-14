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


# === Tranche 8: Master succession (s54.7g) ===

## A conscious agent in `sect` (kolat_sect set, not a Master), eligible by Coin minimums.
func _coin_agent(id: int) -> L5RCharacterData:
	var c := _npc(id, {"Commerce": 5}, "Crab", "Yasuki", "Family Daimyo")
	c.kolat_sect = Enums.KolatSect.COIN
	return c


func test_succession_elevates_first_valid_heir() -> void:
	var h1 := _coin_agent(10)
	var h2 := _coin_agent(11)
	var npcs := [h1, h2]
	var designations := {Enums.KolatSect.COIN: [10, 11]}
	var nid := KolatMasterSelector.evaluate_succession(Enums.KolatSect.COIN, npcs, designations, DiceEngine.new(20))
	assert_eq(nid, 10, "first valid heir is elevated")
	assert_true(h1.is_kolat_master)
	assert_eq(h1.kolat_sect, Enums.KolatSect.COIN)
	assert_false(h2.is_kolat_master, "second heir untouched when first is valid")


func test_succession_skips_dead_heir() -> void:
	var h1 := _coin_agent(10)
	h1.wounds_taken = 9999  # dead
	var h2 := _coin_agent(11)
	var npcs := [h1, h2]
	var designations := {Enums.KolatSect.COIN: [10, 11]}
	var nid := KolatMasterSelector.evaluate_succession(Enums.KolatSect.COIN, npcs, designations, DiceEngine.new(21))
	assert_eq(nid, 11, "cascade falls through a dead heir to the next")


func test_succession_skips_heir_under_investigation() -> void:
	var h1 := _coin_agent(10)
	var h2 := _coin_agent(11)
	var npcs := [h1, h2]
	var designations := {Enums.KolatSect.COIN: [10, 11]}
	var nid := KolatMasterSelector.evaluate_succession(
		Enums.KolatSect.COIN, npcs, designations, DiceEngine.new(22), [10])
	assert_eq(nid, 11, "heir under active investigation is skipped")


func test_succession_discretionary_when_no_valid_heir() -> void:
	var stranger := _coin_agent(12)  # not designated, but eligible Coin agent
	var npcs := [stranger]
	var designations := {Enums.KolatSect.COIN: [99, 98]}  # both nonexistent
	var nid := KolatMasterSelector.evaluate_succession(Enums.KolatSect.COIN, npcs, designations, DiceEngine.new(23))
	assert_eq(nid, 12, "discretionary fallback picks an eligible Sect agent")
	assert_true(stranger.is_kolat_master)


func test_succession_returns_vacant_when_unfillable() -> void:
	var npcs: Array = []
	var nid := KolatMasterSelector.evaluate_succession(
		Enums.KolatSect.COIN, npcs, {Enums.KolatSect.COIN: [99]}, DiceEngine.new(24))
	assert_eq(nid, -1, "no heir and no eligible agent leaves the seat vacant")


func test_new_tiger_repoints_other_masters() -> void:
	# A living Coin Master pointing at the old (now dead) Tiger; a new Tiger heir.
	var coin := _npc(2, {"Commerce": 5}, "Crab", "Yasuki", "Family Daimyo")
	KolatMasterSelector.select_masters([coin], DiceEngine.new(25))  # makes Coin a Master, superior -1 (no tiger yet)
	var new_tiger := _tiger_candidate(3)
	new_tiger.kolat_sect = Enums.KolatSect.TIGER  # conscious Tiger agent heir
	var npcs := [coin, new_tiger]
	var nid := KolatMasterSelector.evaluate_succession(
		Enums.KolatSect.TIGER, npcs, {Enums.KolatSect.TIGER: [3]}, DiceEngine.new(26))
	assert_eq(nid, 3, "Tiger heir elevated")
	assert_eq(new_tiger.kolat_superior_id, -1, "new Tiger reports to no one")
	assert_eq(coin.kolat_superior_id, 3, "other living Masters re-point to the new Tiger")


# === Tranche 11: Bushido virtue hard blocks (s54.7b) ===

func test_gi_cannot_be_tiger() -> void:
	var t := _tiger_candidate(1)
	t.bushido_virtue = Enums.BushidoVirtue.GI
	var got := KolatMasterSelector.select_masters([t], DiceEngine.new(30))
	assert_eq(got[Enums.KolatSect.TIGER], -1, "Gi virtue is hard-blocked from Tiger")


func test_chugi_cannot_be_tiger_but_can_be_jade() -> void:
	# Chugi is blocked from Tiger only; a Chugi shugenja can still hold Jade.
	var c := _npc(1, {"Lore: Shadowlands": 4, "Investigation": 4}, "Dragon", "Tamori", "",
		Enums.SchoolType.SHUGENJA)
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var got := KolatMasterSelector.select_masters([c], DiceEngine.new(31))
	assert_eq(got[Enums.KolatSect.JADE], 1, "Chugi is permitted for Jade")


func test_makoto_cannot_be_silk() -> void:
	var s := _npc(1, {"Acting": 4, "Courtier": 4, "Sincerity (Deceit)": 4}, "Scorpion", "Shosuro", "")
	s.bushido_virtue = Enums.BushidoVirtue.MAKOTO
	var got := KolatMasterSelector.select_masters([s], DiceEngine.new(32))
	assert_eq(got[Enums.KolatSect.SILK], -1, "Makoto is hard-blocked from Silk")


func test_jin_cannot_be_dream() -> void:
	var d := _npc(1, {"Temptation": 5, "Intimidation (Control)": 3, "Medicine": 4})
	d.bushido_virtue = Enums.BushidoVirtue.JIN
	var got := KolatMasterSelector.select_masters([d], DiceEngine.new(33))
	assert_eq(got[Enums.KolatSect.DREAM], -1, "Jin is hard-blocked from Dream")


func test_no_virtue_block_for_shourido() -> void:
	# A Shourido-virtue (or NONE bushido) Lotus candidate is never hard-blocked.
	var l := _npc(1, {"Stealth": 4, "Kenjutsu": 5})
	l.bushido_virtue = Enums.BushidoVirtue.NONE
	l.shourido_virtue = Enums.ShouridoVirtue.KETSUI
	var got := KolatMasterSelector.select_masters([l], DiceEngine.new(34))
	assert_eq(got[Enums.KolatSect.LOTUS], 1, "no Bushido virtue → no hard block")
