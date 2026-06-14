extends GutTest
## GUT tests for KihoSystem (simulation/kiho_system.gd). GDD s38 / s38a.


func _monk(brotherhood: bool = true, rank: int = 1, xp: int = 50) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 801
	c.school_type = Enums.SchoolType.MONK
	c.school_name = "Brotherhood Monk"
	c.school_rank = rank
	c.brotherhood_sect = "Order of Osano-Wo" if brotherhood else ""
	c.xp_total = xp
	c.xp_spent = 0
	# Air ring 2 (min reflexes/awareness), Void 2.
	c.reflexes = 2; c.awareness = 2
	c.stamina = 2; c.willpower = 2
	c.agility = 2; c.intelligence = 2
	c.strength = 2; c.perception = 2
	c.void_ring = 2
	return c


func _shugenja(rank: int = 3, xp: int = 50) -> L5RCharacterData:
	var c := _monk(true, rank, xp)
	c.character_id = 802
	c.school_type = Enums.SchoolType.SHUGENJA
	c.school_name = "Isawa Shugenja"
	c.brotherhood_sect = ""
	return c


# === ELIGIBILITY (mastery) ===

func test_monk_meets_mastery_school_rank_plus_ring() -> void:
	# Air Fist = Air 3. Monk rank 1 + Air ring 2 = 3 ≥ 3 → meets.
	var m := _monk(true, 1)
	assert_true(KihoSystem.meets_mastery(m, "Air Fist"), "rank1 + Air2 meets Air 3")


func test_monk_below_mastery() -> void:
	# Calling the East Wind = Air 5. rank 1 + Air 2 = 3 < 5.
	assert_false(KihoSystem.meets_mastery(_monk(true, 1), "Calling the East Wind"))


func test_shugenja_cannot_learn_kiho() -> void:
	# MONK-ONLY (s38a): shugenja are excluded entirely, even with high rings.
	var s := _shugenja(5)
	s.reflexes = 5; s.awareness = 5  # Air ring 5
	assert_false(KihoSystem.can_learn(s, "Air Fist"),
		"Shugenja cannot learn kiho (monk-only override)")
	assert_true(KihoSystem.get_eligible_kiho(s).is_empty(),
		"Shugenja have no eligible kiho")


func test_monk_sever_requires_fire_5() -> void:
	# Sever the Dark Lord's Touch = Fire 5. No Kuni reduction (monk-only).
	var m := _monk(true, 1)
	m.agility = 3; m.intelligence = 3  # Fire 3 → 1+3=4 < 5
	assert_false(KihoSystem.meets_mastery(m, "Sever the Dark Lord's Touch"))
	m.agility = 4; m.intelligence = 4  # Fire 4 → 1+4=5 ≥ 5
	assert_true(KihoSystem.meets_mastery(m, "Sever the Dark Lord's Touch"))


# === COST MULTIPLIER & LEARN COST ===

func test_cost_multipliers() -> void:
	assert_eq(KihoSystem.cost_multiplier(_monk(true)), 1.0, "Brotherhood ×1")
	assert_eq(KihoSystem.cost_multiplier(_monk(false)), 1.5, "Non-Brotherhood monk ×1.5")


func test_learn_cost_ceils_by_multiplier() -> void:
	# Air Fist mastery 3.
	assert_eq(KihoSystem.learn_cost(_monk(true), "Air Fist"), 3, "Brotherhood: 3")
	assert_eq(KihoSystem.learn_cost(_monk(false), "Air Fist"), 5, "Non-Brotherhood: ceil(4.5)=5")


# === KNOWLEDGE CAP ===

func test_brotherhood_uncapped() -> void:
	assert_eq(KihoSystem.knowledge_cap(_monk(true)), -1, "Brotherhood uncapped")
	assert_false(KihoSystem.at_knowledge_cap(_monk(true)))


func test_non_brotherhood_capped_at_school_rank() -> void:
	var m := _monk(false, 2)
	assert_eq(KihoSystem.knowledge_cap(m), 2, "Cap = school rank 2")
	m.kiho = ["Air Fist", "Riding the Clouds"]
	assert_true(KihoSystem.at_knowledge_cap(m), "At cap with 2 known")
	assert_false(KihoSystem.can_learn(m, "Soul of the Four Winds"),
		"Cannot learn beyond cap")


# === ACQUISITION ===

func test_learn_kiho_deducts_xp_and_records() -> void:
	var m := _monk(true, 1, 50)
	assert_true(KihoSystem.learn_kiho(m, "Air Fist"), "learns Air Fist")
	assert_eq(m.xp_spent, 3, "3 XP spent")
	assert_true("Air Fist" in m.kiho, "recorded")
	assert_false(KihoSystem.learn_kiho(m, "Air Fist"), "cannot re-learn")


func test_cannot_learn_without_xp() -> void:
	var m := _monk(true, 1, 1)  # only 1 XP
	assert_false(KihoSystem.can_afford(m, "Air Fist"), "3 XP needed, has 1")
	assert_false(KihoSystem.learn_kiho(m, "Air Fist"))


func test_bushi_cannot_learn_kiho() -> void:
	var b := _monk(true, 5, 50)
	b.school_type = Enums.SchoolType.BUSHI
	assert_false(KihoSystem.can_learn(b, "Air Fist"), "Bushi channel no kiho")


func test_monk_can_learn_rebuke_of_the_heavens() -> void:
	# Rebuke of the Heavens (Void 5). Learnable by a monk meeting the mastery.
	var m := _monk(true, 1, 50); m.void_ring = 5  # 1 + 5 = 6 ≥ 5
	assert_true(KihoSystem.can_learn(m, "Rebuke of the Heavens"), "Monk can learn it")


# === NPC SELECTION ===

func test_select_kiho_prefers_highest_mastery() -> void:
	# High rings + rank so several kiho are eligible.
	var m := _monk(true, 5, 100)
	m.reflexes = 4; m.awareness = 4  # Air 4
	var pick: String = KihoSystem.select_kiho_for_npc(m)
	assert_false(pick.is_empty(), "selects something")
	# Whatever is picked must be eligible and the highest available mastery.
	assert_true(KihoSystem.can_learn(m, pick))


func test_select_returns_empty_when_none() -> void:
	var m := _monk(true, 1, 0)  # no XP
	assert_eq(KihoSystem.select_kiho_for_npc(m), "", "no affordable kiho → empty")


# === ACTIVATION RULES ===

func test_activation_options() -> void:
	var opt: Dictionary = KihoSystem.activation_options("Censure of Thunder")
	assert_true(opt["void_point_free"], "Void Point is a Free activation")
	assert_eq(opt["meditation_tn_complex"], 15)
	assert_eq(opt["meditation_tn_simple"], 30)
	assert_true(opt["is_atemi"], "Censure of Thunder is atemi")


func test_active_slot_one_internal_at_a_time() -> void:
	# Air Fist and Soul of the Four Winds are both Internal.
	var r := KihoSystem.can_activate("Soul of the Four Winds", ["Air Fist"])
	assert_false(r["ok"], "second Internal blocked")
	assert_eq(r["reason"], "slot_occupied")


func test_active_slot_martial_unlimited() -> void:
	# Hurricane Palm and Way of the Earth are both Martial.
	var r := KihoSystem.can_activate("Way of the Earth", ["Hurricane Palm"])
	assert_true(r["ok"], "multiple Martial allowed")


func test_active_slot_rejects_already_active() -> void:
	var r := KihoSystem.can_activate("Air Fist", ["Air Fist"])
	assert_false(r["ok"])
	assert_eq(r["reason"], "already_active")


func test_internal_and_kharmic_can_coexist() -> void:
	# Air Fist (Internal) + Steal the Air Dragon (Kharmic) — different slots.
	var r := KihoSystem.can_activate("Steal the Air Dragon", ["Air Fist"])
	assert_true(r["ok"], "Internal + Kharmic coexist")


# === CATALOG INTEGRITY ===

func test_catalog_has_full_roster() -> void:
	assert_eq(KihoSystem.KIHO_DATA.size(), 73, "all s38 kiho catalogued")
	for name: String in KihoSystem.KIHO_DATA.keys():
		var k: Dictionary = KihoSystem.KIHO_DATA[name]
		assert_true(k.has("ring") and k.has("mastery") and k.has("type"),
			"%s has required fields" % name)
		assert_true(k["mastery"] >= 3 and k["mastery"] <= 8,
			"%s mastery in range" % name)
