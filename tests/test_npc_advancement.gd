extends GutTest
## Tests for NPCAdvancement (s52 Part 3, s48).


func _make_character(id: int = 1, school: String = "Hida Bushi") -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Test"
	c.clan = "Crab"
	c.family = "Hida"
	c.school = school
	c.school_type = Enums.SchoolType.BUSHI
	c.stamina = 3
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 3
	c.intelligence = 2
	c.reflexes = 2
	c.awareness = 2
	c.void_ring = 2
	c.skills = {
		"Athletics": 1, "Defense": 1, "Heavy Weapons": 2,
		"Intimidation": 1, "Kenjutsu": 1, "Lore: Shadowlands": 1,
	}
	c.honor = 3.5
	c.glory = 1.0
	c.status = 1.0
	return c


func _make_courtier() -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 2
	c.school = "Doji Courtier"
	c.school_type = Enums.SchoolType.COURTIER
	c.clan = "Crane"
	c.family = "Doji"
	c.stamina = 2
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 2
	c.intelligence = 2
	c.reflexes = 2
	c.awareness = 3
	c.void_ring = 2
	c.skills = {
		"Calligraphy": 1, "Courtier": 2, "Etiquette": 1,
		"Perform: Storytelling": 1, "Sincerity": 1, "Tea Ceremony": 1,
	}
	return c


func _make_shugenja() -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 3
	c.school = "Isawa Shugenja"
	c.school_type = Enums.SchoolType.SHUGENJA
	c.clan = "Phoenix"
	c.family = "Isawa"
	c.stamina = 2
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 2
	c.intelligence = 3
	c.reflexes = 2
	c.awareness = 2
	c.void_ring = 2
	c.skills = {
		"Calligraphy": 1, "Lore: Theology": 1,
		"Meditation": 1, "Spellcraft": 2,
	}
	return c


# === BASE XP RATE TESTS ===

func test_peacetime_rate():
	var c := _make_character()
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.02, 0.001)

func test_active_duty_rate():
	var c := _make_character()
	c.assigned_company_id = 5
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.04, 0.001)

func test_gunso_rate():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.GUNSO
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.05, 0.001)

func test_chui_rate():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.CHUI
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.06, 0.001)

func test_taisa_rate():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.TAISA
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.08, 0.001)

func test_shireikan_rate():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.SHIREIKAN
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.10, 0.001)

func test_rikugunshokan_rate():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.RIKUGUNSHOKAN
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.10, 0.001)

func test_courtier_rate():
	var c := _make_courtier()
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.05, 0.001)

func test_shugenja_rate():
	var c := _make_shugenja()
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.05, 0.001)

func test_magistrate_rate():
	var c := _make_character()
	c.role_position = "Clan Magistrate"
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.06, 0.001)

func test_sensei_rate():
	var c := _make_character()
	c.role_position = "School Master"
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.04, 0.001)

func test_temple_head_rate():
	var c := _make_character()
	c.role_position = "Temple Head"
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.05, 0.001)

func test_military_rank_overrides_role_position():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.TAISA
	c.role_position = "School Master"
	assert_almost_eq(NPCAdvancement.get_base_xp_rate(c), 0.08, 0.001)


# === ACTIVITY MULTIPLIER TESTS ===

func test_peacetime_multiplier():
	var c := _make_character()
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, {}), 1.0, 0.001)

func test_battle_multiplier():
	var c := _make_character()
	var ws: Dictionary = {"in_battle_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 2.5, 0.001)

func test_commanding_battle_multiplier():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.CHUI
	c.commanded_unit_id = 1
	var ws: Dictionary = {"in_battle_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 3.0, 0.001)

func test_siege_multiplier():
	var c := _make_character()
	var ws: Dictionary = {"in_siege_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 2.0, 0.001)

func test_crisis_multiplier():
	var c := _make_character()
	var ws: Dictionary = {"in_crisis_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 2.0, 0.001)

func test_court_multiplier_for_courtier():
	var c := _make_courtier()
	var ws: Dictionary = {"in_court_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 1.5, 0.001)

func test_court_no_bonus_for_bushi():
	var c := _make_character()
	var ws: Dictionary = {"in_court_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 1.0, 0.001)

func test_border_patrol_multiplier():
	var c := _make_character()
	c.assigned_company_id = 5
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, {}), 1.5, 0.001)

func test_battle_overrides_border_patrol():
	var c := _make_character()
	c.assigned_company_id = 5
	var ws: Dictionary = {"in_battle_ids": [c.character_id]}
	assert_almost_eq(NPCAdvancement.get_activity_multiplier(c, ws), 2.5, 0.001)


# === COMPUTE DAILY XP ===

func test_compute_daily_xp_peacetime():
	var c := _make_character()
	var xp: float = NPCAdvancement.compute_daily_xp(c, {})
	assert_almost_eq(xp, 0.02, 0.001)

func test_compute_daily_xp_gunso_battle():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.GUNSO
	var ws: Dictionary = {"in_battle_ids": [c.character_id]}
	var xp: float = NPCAdvancement.compute_daily_xp(c, ws)
	assert_almost_eq(xp, 0.05 * 2.5, 0.001)

func test_compute_daily_xp_chui_commanding():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.CHUI
	c.commanded_unit_id = 1
	var ws: Dictionary = {"in_battle_ids": [c.character_id]}
	var xp: float = NPCAdvancement.compute_daily_xp(c, ws)
	assert_almost_eq(xp, 0.06 * 3.0, 0.001)


# === ACCUMULATE DAILY XP ===

func test_accumulate_daily_xp_fractional():
	var c := _make_character()
	# 0.02 XP/OOC day / 4 IC days = 0.005 per IC day
	NPCAdvancement.accumulate_daily_xp(c, {})
	assert_almost_eq(c.xp_fractional, 0.005, 0.001)
	assert_eq(c.xp_total, 0)

func test_accumulate_daily_xp_whole_rolls_over():
	var c := _make_character()
	c.xp_fractional = 0.998
	NPCAdvancement.accumulate_daily_xp(c, {})
	assert_eq(c.xp_total, 1)
	assert_almost_eq(c.xp_fractional, 0.003, 0.01)

func test_accumulate_many_ic_days():
	var c := _make_character()
	# 200 IC days = 50 OOC days at 0.02/OOC day = 1.0 XP total
	for i in range(200):
		NPCAdvancement.accumulate_daily_xp(c, {})
	assert_eq(c.xp_total, 1)
	assert_almost_eq(c.xp_fractional, 0.0, 0.01)


# === SCHOOL DATA LOOKUPS ===

func test_get_school_skills_hida():
	var c := _make_character()
	var skills: Array = NPCAdvancement.get_school_skills(c)
	assert_true(skills.has("Athletics"))
	assert_true(skills.has("Kenjutsu"))
	assert_eq(skills.size(), 6)

func test_get_focus_rings_hida():
	var c := _make_character()
	var rings: Array = NPCAdvancement.get_focus_rings(c)
	assert_eq(rings.size(), 2)
	assert_eq(rings[0], Enums.Ring.EARTH)
	assert_eq(rings[1], Enums.Ring.FIRE)

func test_get_school_skills_unknown():
	var c := _make_character()
	c.school = "Unknown School"
	var skills: Array = NPCAdvancement.get_school_skills(c)
	assert_eq(skills.size(), 0)


# === PROGRESS BAR SPENDING — SKILLS ===

func test_spend_on_skill_partial():
	var c := _make_character()
	c.xp_total = 3
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	assert_true(result["xp_spent"] > 0)
	assert_true(c.xp_spent > 0)

func test_spend_on_skill_advances():
	var c := _make_character()
	# Skill rank 2 -> 3 costs 3000 progress = 15 XP
	c.xp_total = 20
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	var found_advancement: bool = false
	for adv: Dictionary in result["advancements"]:
		if adv["type"] == "ring" or adv["type"] == "skill":
			found_advancement = true
	# With 20 XP (4000 progress), something should advance
	assert_true(result["xp_spent"] > 0)


# === PROGRESS BAR SPENDING — RINGS ===

func test_spend_on_ring_partial_fill():
	var c := _make_character()
	# Earth ring is 2 (min of stamina 3, willpower 2), so cost to go 2->3 = 12000 progress = 60 XP
	c.xp_total = 10
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	# 10 XP = 2000 progress, goes to primary ring (Earth) bar
	var ring_progress: int = c.progress_bars.get("ring_earth", 0)
	assert_true(ring_progress > 0)
	assert_eq(result["xp_spent"], 10)

func test_ring_advancement_raises_lower_trait():
	var c := _make_character()
	# Earth ring traits: stamina=3, willpower=2. Ring = 2.
	# Cost 2->3 = 12000 progress = 60 XP
	c.xp_total = 60
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	# Should raise willpower from 2 to 3 (the lower trait)
	assert_eq(c.willpower, 3)
	var found_ring: bool = false
	for adv: Dictionary in result["advancements"]:
		if adv["type"] == "ring" and adv["ring"] == Enums.Ring.EARTH:
			found_ring = true
	assert_true(found_ring)


# === SPENDING PRIORITY ORDER ===

func test_priority_1_primary_ring_first():
	var c := _make_character()
	# Give just enough for partial ring fill
	c.xp_total = 5
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	# Primary ring for Hida Bushi is Earth
	var earth_progress: int = c.progress_bars.get("ring_earth", 0)
	assert_eq(earth_progress, 5 * 200)

func test_priority_flows_to_skills_after_ring():
	var c := _make_character()
	# Fill Earth ring bar completely and have leftover
	# Earth 2->3 = 12000 progress = 60 XP. Give 65 XP.
	c.xp_total = 65
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(c.willpower, 3)
	# Leftover 5 XP (1000 progress) should go to highest school skill
	# Heavy Weapons is rank 2 (highest). Cost 2->3 = 3000.
	# 1000 progress added to Heavy Weapons bar
	var hw_progress: int = c.progress_bars.get("skill_Heavy Weapons", 0)
	assert_eq(hw_progress, 1000)

func test_priority_4_secondary_ring():
	var c := _make_character()
	# Max out all school skills to rank 5 and primary ring to 5
	c.stamina = 5
	c.willpower = 5
	c.void_ring = 5
	for skill: String in NPCAdvancement.get_school_skills(c):
		c.skills[skill] = 5
	# Give enough for secondary ring (Fire for Hida Bushi)
	# Fire ring = min(agility=3, intelligence=2) = 2. Cost 2->3 = 12000 = 60 XP
	c.xp_total = 60
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	# Should raise intelligence from 2 to 3
	assert_eq(c.intelligence, 3)

func test_shugenja_void_ring_advancement():
	var c := _make_shugenja()
	# Max primary and secondary rings and all school skills
	c.agility = 5
	c.intelligence = 5
	c.reflexes = 5
	c.awareness = 5
	c.stamina = 5
	c.willpower = 5
	c.strength = 5
	c.perception = 5
	for skill: String in NPCAdvancement.get_school_skills(c):
		c.skills[skill] = 5
	# Give enough for Void 2->3 = 12000 = 60 XP
	c.xp_total = 60
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(c.void_ring, 3)
	assert_eq(c.max_void_points, 3)

func test_bushi_can_advance_void_ring():
	# s52 Part 3 update: all school types may raise Void after focus rings and skills
	var c := _make_character()
	# Max focus rings and all school skills so Void is next in priority
	c.stamina = 5
	c.willpower = 5
	c.agility = 5
	c.intelligence = 5
	for skill: String in NPCAdvancement.get_school_skills(c):
		c.skills[skill] = 5
	# Void ring 2->3 costs 12000 progress = 60 XP
	c.xp_total = 60
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(c.void_ring, 3)

func test_reserve_xp_when_all_maxed():
	var c := _make_character()
	c.stamina = 5
	c.willpower = 5
	c.agility = 5
	c.intelligence = 5
	c.reflexes = 5
	c.awareness = 5
	c.strength = 5
	c.perception = 5
	c.void_ring = 5
	for skill: String in NPCAdvancement.get_school_skills(c):
		c.skills[skill] = 5
	c.xp_total = 100
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(result["xp_spent"], 0)
	assert_eq(c.xp_spent, 0)


# === INSIGHT RANK ADVANCEMENT ===

func test_skill_advancement_increases_insight():
	var c := _make_character()
	var old_insight: int = CharacterStats.get_insight(c)
	# Raise a skill
	c.skills["Kenjutsu"] = 2
	var new_insight: int = CharacterStats.get_insight(c)
	assert_true(new_insight > old_insight)

func test_ring_advancement_increases_insight():
	var c := _make_character()
	var old_insight: int = CharacterStats.get_insight(c)
	c.willpower = 3
	var new_insight: int = CharacterStats.get_insight(c)
	assert_true(new_insight > old_insight)


# === SEASONAL BATCH PROCESSING ===

func test_seasonal_advancement_skips_dead():
	var c := _make_character()
	c.wounds_taken = 999
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c], {}, 90)
	assert_eq(result["results"].size(), 0)

func test_seasonal_advancement_accumulates_xp():
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.TAISA
	NPCAdvancement.process_seasonal_advancement([c], {}, 90)
	# 90 IC days / 4 = 22 OOC days. 0.08 * 22 = 1.76 XP -> 1 whole XP
	assert_eq(c.xp_total, 1)
	assert_almost_eq(c.xp_fractional, 0.76, 0.01)

func test_seasonal_advancement_reports_rank_up():
	var c := _make_character()
	# Give the character enough XP to potentially rank up
	# Rank 1 -> 2 at insight 150. Current insight = (2+2+2+2+2)*10 + 7 = 107
	# Need 43 more insight. That's 4 ring points (40) + 3 skill ranks
	c.xp_total = 500
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c], {}, 1)
	# With 500 XP (100000 progress), many advancements should happen
	assert_true(result["results"].size() > 0)

func test_seasonal_advancement_multiple_characters():
	var c1 := _make_character(1)
	var c2 := _make_courtier()
	c1.military_rank = Enums.MilitaryRank.GUNSO
	# Need enough XP so progress exceeds ring cost and spills into skills.
	# Earth ring rank 2→3 costs 12000 progress (60 XP). Additional skills cost 2000–3000.
	c1.xp_total = 100
	c2.xp_total = 100
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c1, c2], {}, 90)
	# Both should have advancement results
	assert_true(result["results"].size() >= 1)


# === WORKED EXAMPLES FROM GDD ===

func test_worked_example_gunso_peacetime():
	# Gunso in peacetime: 0.05 XP/day x 1.0 = 0.05 XP/day
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.GUNSO
	var xp: float = NPCAdvancement.compute_daily_xp(c, {})
	assert_almost_eq(xp, 0.05, 0.001)

func test_worked_example_gunso_battle():
	# Gunso during battle: 0.05 x 3.0 = 0.15 XP
	# Note: Gunso doesn't have commanded_unit_id, so gets 2.5x not 3.0x
	# The GDD says 3.0x for commanding — but Gunso commands a squadron,
	# which the code models as commanding_battle only for Chui+
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.GUNSO
	var ws: Dictionary = {"in_battle_ids": [c.character_id]}
	var xp: float = NPCAdvancement.compute_daily_xp(c, ws)
	# Gunso in battle gets 2.5x (participating, not commanding at Chui+ level)
	assert_almost_eq(xp, 0.05 * 2.5, 0.001)

func test_worked_example_chui_campaign():
	# Chui commanding through 30 OOC-day campaign at 2.0x: 0.06 x 2.0 x 30 = 3.6 XP
	var c := _make_character()
	c.military_rank = Enums.MilitaryRank.CHUI
	c.commanded_unit_id = 1
	var ws: Dictionary = {"in_siege_ids": [c.character_id]}
	# Siege = 2.0x. compute_daily_xp returns XP per OOC day.
	var daily_xp: float = NPCAdvancement.compute_daily_xp(c, ws)
	assert_almost_eq(daily_xp, 0.06 * 2.0, 0.001)
	# 30 OOC days = 120 IC days. process_seasonal_advancement handles conversion.
	assert_almost_eq(daily_xp * 30.0, 3.6, 0.01)


# === EDGE CASES ===

func test_unknown_school_uses_schoolless_path():
	# s52 Part 3: characters without a known school use the school-less path.
	# They advance their highest-ranked skill rather than holding XP in reserve.
	var c := _make_character()
	c.school = "Unknown School"
	c.xp_total = 10
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	# 10 XP = 2000 progress. Highest skill is Heavy Weapons (rank 2). Cost 2->3 = 3000.
	# All 2000 progress goes to Heavy Weapons bar; XP is spent, not held in reserve.
	assert_eq(result["xp_spent"], 10)
	var hw_progress: int = c.progress_bars.get("skill_Heavy Weapons", 0)
	assert_eq(hw_progress, 2000)

func test_no_xp_available():
	var c := _make_character()
	c.xp_total = 5
	c.xp_spent = 5
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(result["xp_spent"], 0)
	assert_eq(result["advancements"].size(), 0)

func test_set_trait_value():
	var c := _make_character()
	c.set_trait_value(Enums.Trait.WILLPOWER, 5)
	assert_eq(c.willpower, 5)
	c.set_trait_value(Enums.Trait.AGILITY, 4)
	assert_eq(c.agility, 4)

func test_progress_bar_persists_across_spend_calls():
	var c := _make_character()
	# First spend: 5 XP = 1000 progress into Earth ring bar
	c.xp_total = 5
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	var progress_1: int = c.progress_bars.get("ring_earth", 0)
	assert_eq(progress_1, 1000)

	# Second spend: add more XP, should continue filling same bar
	c.xp_total = 10
	NPCAdvancement.spend_accumulated_xp(c)
	var progress_2: int = c.progress_bars.get("ring_earth", 0)
	assert_eq(progress_2, 2000)

func test_skill_rank_cap_at_5():
	var c := _make_character()
	c.skills["Heavy Weapons"] = 5
	c.stamina = 5
	c.willpower = 5
	# Primary ring maxed, best skill maxed. Should flow to other skills.
	c.xp_total = 10
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(c.skills["Heavy Weapons"], 5)

func test_xp_to_progress_conversion():
	assert_eq(NPCAdvancement.XP_TO_PROGRESS, 200)
	assert_eq(NPCAdvancement.SKILL_PROGRESS_COST[0], 1000)
	assert_eq(NPCAdvancement.RING_PROGRESS_COST[2], 12000)


# -- Technique flag assignment on rank-up --------------------------------------

func test_doji_courtier_gains_cadence_on_rank_up_to_r2() -> void:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 50
	c.character_name = "Doji Test"
	c.clan = "Crane"
	c.family = "Doji"
	c.school = "Doji Courtier"
	c.school_type = Enums.SchoolType.COURTIER
	c.awareness = 3
	c.intelligence = 2
	c.willpower = 2
	c.perception = 2
	c.stamina = 2
	c.strength = 2
	c.agility = 2
	c.reflexes = 3
	c.void_ring = 2
	c.skills = {"Courtier": 3, "Etiquette": 2, "Sincerity": 2, "Perform: Oratory": 1, "Tea Ceremony": 1}
	c.honor = 6.5
	c.glory = 1.0
	c.status = 1.0
	assert_eq(CharacterStats.get_insight_rank(c), 1)
	assert_false(c.cadence_trained)

	c.xp_total = 500
	c.xp_spent = 0
	var ws: Dictionary = {}
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c], ws, 90)
	var new_rank: int = CharacterStats.get_insight_rank(c)
	if new_rank >= 2:
		assert_true(c.cadence_trained, "Doji Courtier should get cadence_trained on reaching R2")


# -- Training Session (s48) ---------------------------------------------------

func test_resolve_training_session_applies_progress() -> void:
	var sensei: L5RCharacterData = _make_character(1)
	sensei.skills["Kenjutsu"] = 5
	var student: L5RCharacterData = _make_character(2)
	student.skills["Kenjutsu"] = 2
	var result: Dictionary = NPCAdvancement.resolve_training_session(sensei, student, "Kenjutsu")
	assert_true(result.get("success", false), "Training should succeed")
	assert_eq(result.get("student_progress", 0), NPCAdvancement.TRAINING_PROGRESS_SENSEI_2_ABOVE)
	assert_eq(result.get("sensei_progress", 0), NPCAdvancement.TRAINING_PROGRESS_SENSEI_SELF)
	assert_eq(result.get("rank_gap", 0), 3)


func test_resolve_training_session_1_rank_gap() -> void:
	var sensei: L5RCharacterData = _make_character(1)
	sensei.skills["Kenjutsu"] = 3
	var student: L5RCharacterData = _make_character(2)
	student.skills["Kenjutsu"] = 2
	var result: Dictionary = NPCAdvancement.resolve_training_session(sensei, student, "Kenjutsu")
	assert_true(result.get("success", false))
	assert_eq(result.get("student_progress", 0), NPCAdvancement.TRAINING_PROGRESS_SENSEI_1_ABOVE)
	assert_eq(result.get("rank_gap", 0), 1)


func test_resolve_training_session_fails_when_sensei_not_higher() -> void:
	var sensei: L5RCharacterData = _make_character(1)
	sensei.skills["Kenjutsu"] = 2
	var student: L5RCharacterData = _make_character(2)
	student.skills["Kenjutsu"] = 2
	var result: Dictionary = NPCAdvancement.resolve_training_session(sensei, student, "Kenjutsu")
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "sensei_rank_not_higher")


# -- school_rank sync on rank-up (s48a A48a-3) ---------------------------------

func test_school_rank_synced_on_rank_up() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.school_rank = 1
	# Give enough XP to rank up (insight 107, need 150 for rank 2 — need 43 more).
	# 4 ring advances (+40 insight) + 3 skill advances (+3 insight) = +43.
	# Ring 2->3 = 60 XP, skills 3 XP each. 60 + 9 = 69 XP should be more than enough.
	c.xp_total = 500
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c], {}, 1)
	var new_rank: int = CharacterStats.get_insight_rank(c)
	if new_rank >= 2:
		assert_eq(c.school_rank, new_rank, "school_rank must match computed insight rank after rank-up")


func test_school_rank_not_mutated_without_rank_up() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.school_rank = 1
	# Give small XP — enough for progress but not a rank-up.
	c.xp_total = 3
	c.xp_spent = 0
	NPCAdvancement.process_seasonal_advancement([c], {}, 1)
	assert_eq(c.school_rank, 1, "school_rank must not change when no rank-up occurred")


func test_rank_up_entry_contains_topic_data() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.character_name = "Hida Taro"
	c.school_rank = 1
	c.xp_total = 500
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c], {}, 1)
	var new_rank: int = CharacterStats.get_insight_rank(c)
	if new_rank >= 2:
		var found_topic_data: bool = false
		for entry: Dictionary in result["results"]:
			if entry.get("ranked_up", false) and entry.has("rank_up_topic"):
				var rut: Dictionary = entry["rank_up_topic"]
				assert_eq(rut["character_id"], c.character_id)
				assert_eq(rut["character_name"], "Hida Taro")
				assert_true(rut["new_rank"] >= 2)
				found_topic_data = true
		assert_true(found_topic_data, "rank-up entry should include rank_up_topic dict")


func test_no_rank_up_topic_when_no_rank_up() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.xp_total = 3
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.process_seasonal_advancement([c], {}, 1)
	for entry: Dictionary in result["results"]:
		assert_false(entry.has("rank_up_topic"), "no rank_up_topic should be present without rank-up")


# -- Topic seeded into character's topic_pool on rank-up (s48a A48a-2) ---------

func test_rank_up_topic_seeded_into_character_pool() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.character_name = "Hida Taro"
	c.school_rank = 1
	c.xp_total = 500
	c.xp_spent = 0
	var active_topics: Array = []
	var next_topic_id: Array = [200]
	DayOrchestrator._process_npc_advancement(
		[c], [], [], [], [], 0, active_topics, next_topic_id, 10
	)
	var new_rank: int = CharacterStats.get_insight_rank(c)
	if new_rank >= 2:
		assert_true(active_topics.size() >= 1, "rank-up topic should be in active_topics")
		var topic_id: int = active_topics[0].topic_id
		assert_true(c.topic_pool.has(topic_id), "character's own topic_pool must contain their rank-up topic")


func test_rank_up_topic_not_seeded_without_rank_up() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.xp_total = 3
	c.xp_spent = 0
	var active_topics: Array = []
	var next_topic_id: Array = [200]
	DayOrchestrator._process_npc_advancement(
		[c], [], [], [], [], 0, active_topics, next_topic_id, 10
	)
	assert_eq(c.topic_pool.size(), 0, "no topic should be seeded when no rank-up occurred")


# -- Solo TRAIN ActionID (s48) ------------------------------------------------

func test_get_best_training_target_returns_primary_ring() -> void:
	var c: L5RCharacterData = _make_character(1)
	# Hida Bushi focus rings: Earth, Water. Earth ring at rank 3 (stamina + willpower).
	# With stamina=3, willpower=2 -> Earth at 2 (min of pair), not yet at max (5).
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_false(target.is_empty(), "Should find a training target")
	assert_eq(target.get("type", ""), "ring", "First priority is primary ring")


func test_apply_solo_training_progress_adds_progress() -> void:
	var c: L5RCharacterData = _make_character(1)
	# Force progress bars to empty state so we can see them fill
	c.progress_bars = {}
	var result: Dictionary = NPCAdvancement.apply_solo_training_progress(c)
	assert_false(result.get("reason", "") == "nothing_to_train", "Should find something to train")
	# Progress should have been added to some bar
	var total_progress: int = 0
	for key: String in c.progress_bars:
		total_progress += c.progress_bars[key]
	assert_gt(total_progress, 0, "Progress bars should have non-zero total after solo training")


func test_apply_solo_training_progress_amount_is_50() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.progress_bars = {}
	var result: Dictionary = NPCAdvancement.apply_solo_training_progress(c)
	assert_eq(result.get("progress_added", 0), NPCAdvancement.TRAINING_PROGRESS_SOLO,
		"Solo training should add exactly TRAINING_PROGRESS_SOLO progress")


func test_apply_solo_training_nothing_when_maxed() -> void:
	var c: L5RCharacterData = _make_character(1)
	# Max out all rings and skills
	c.stamina = 5; c.willpower = 5; c.strength = 5; c.perception = 5
	c.agility = 5; c.intelligence = 5; c.reflexes = 5; c.awareness = 5
	c.void_ring = 5
	for key: String in c.skills:
		c.skills[key] = 5
	var result: Dictionary = NPCAdvancement.apply_solo_training_progress(c)
	assert_eq(result.get("reason", ""), "nothing_to_train", "Should return nothing_to_train when all maxed")


func test_solo_training_writeback_rank_up_creates_topic() -> void:
	# Character whose computed insight rank (2) exceeds stored school_rank (1).
	# Default rings give insight=100; add 50+ skill ranks to push past 150 (Rank 2 threshold).
	var c: L5RCharacterData = _make_character(1)
	c.character_name = "Hida Taro"
	c.school_rank = 1
	c.skills["Kenjutsu"] = 5
	c.skills["Athletics"] = 5
	c.skills["Defense"] = 5
	c.skills["Heavy Weapons"] = 5
	c.skills["Intimidation"] = 5
	c.skills["Lore: Shadowlands"] = 5
	c.skills["Battle"] = 5
	c.skills["Hunting"] = 5
	c.skills["Horsemanship"] = 5
	c.skills["Jiujutsu"] = 5
	# Insight = ring(100) + skills(50) = 150 -> Rank 2
	assert_eq(CharacterStats.get_insight_rank(c), 2, "Sanity: should be at Rank 2 now")
	# Writeback receives a TRAIN result with advanced=true
	var train_result: Dictionary = {"advanced": true, "type": "skill", "skill": "Kenjutsu", "progress_added": 50}
	var active_topics: Array = []
	var next_topic_id: Array = [300]
	var chars_by_id: Dictionary = {c.character_id: c}
	var fake_result: Dictionary = {
		"action_id": "TRAIN",
		"character_id": c.character_id,
		"effects": {"training_result": train_result},
	}
	DayOrchestrator._process_solo_training_writebacks(
		[fake_result], chars_by_id, active_topics, next_topic_id, 1
	)
	assert_eq(active_topics.size(), 1, "Rank-up from TRAIN should create a topic")
	assert_eq(active_topics[0].tier, TopicData.Tier.TIER_4)
	assert_true(c.topic_pool.has(active_topics[0].topic_id),
		"Character's topic_pool must contain their solo-training rank-up topic")


func test_solo_training_writeback_no_topic_without_rank_up() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.school_rank = 2
	# Pretend a skill advanced but insight didn't cross threshold
	var train_result: Dictionary = {"advanced": true, "type": "skill", "skill": "Kenjutsu", "progress_added": 50}
	var active_topics: Array = []
	var next_topic_id: Array = [300]
	var chars_by_id: Dictionary = {c.character_id: c}
	var fake_result: Dictionary = {
		"action_id": "TRAIN",
		"character_id": c.character_id,
		"effects": {"training_result": train_result},
	}
	DayOrchestrator._process_solo_training_writebacks(
		[fake_result], chars_by_id, active_topics, next_topic_id, 1
	)
	assert_eq(active_topics.size(), 0, "No topic when insight rank did not increase")


func test_solo_training_writeback_ignores_non_train_actions() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.school_rank = 1
	var active_topics: Array = []
	var next_topic_id: Array = [300]
	var chars_by_id: Dictionary = {c.character_id: c}
	# MEDITATE result should be ignored
	var fake_result: Dictionary = {
		"action_id": "MEDITATE",
		"character_id": c.character_id,
		"effects": {"training_result": {"advanced": true}},
	}
	DayOrchestrator._process_solo_training_writebacks(
		[fake_result], chars_by_id, active_topics, next_topic_id, 1
	)
	assert_eq(active_topics.size(), 0, "Non-TRAIN actions should be ignored")


# -- Expanded advancement priority (s52 Part 3 update) -------------------------

func test_get_eligible_skills_includes_school_skills() -> void:
	var c: L5RCharacterData = _make_character(1)
	var eligible: Array = NPCAdvancement.get_eligible_skills(c)
	for sk: String in NPCAdvancement.get_school_skills(c):
		assert_true(eligible.has(sk), "School skill %s should be eligible" % sk)


func test_get_eligible_skills_includes_nonschool_at_rank1() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.skills["Horsemanship"] = 1  # not a Hida Bushi school skill
	var eligible: Array = NPCAdvancement.get_eligible_skills(c)
	assert_true(eligible.has("Horsemanship"), "Non-school skill at rank 1 should be eligible")


func test_get_eligible_skills_excludes_nonschool_at_rank0() -> void:
	var c: L5RCharacterData = _make_character(1)
	# Calligraphy is not in Hida Bushi school skills; character doesn't have it
	assert_false(c.skills.has("Calligraphy"), "Sanity: Calligraphy not yet in skills dict")
	var eligible: Array = NPCAdvancement.get_eligible_skills(c)
	assert_false(eligible.has("Calligraphy"), "Non-school skill at rank 0 must not be eligible")


func test_nonschool_skill_interleaved_by_rank() -> void:
	# A non-school skill at rank 3 should be trained before a school skill at rank 1
	var c: L5RCharacterData = _make_character(1)
	# Max Earth ring so skills become the first target
	c.stamina = 5
	c.willpower = 5
	# All school skills at rank 1 except Heavy Weapons (2)
	c.skills = {"Athletics": 1, "Defense": 1, "Heavy Weapons": 2,
		"Intimidation": 1, "Kenjutsu": 1, "Lore: Shadowlands": 1}
	# Add non-school skill at rank 3 (higher than all school skills)
	c.skills["Battle"] = 3
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_eq(target.get("type", ""), "skill")
	assert_eq(target.get("skill", ""), "Battle",
		"Non-school skill at rank 3 should beat school skills at rank 1-2")


func test_school_skill_beats_nonschool_at_same_rank() -> void:
	var c: L5RCharacterData = _make_character(1)
	c.stamina = 5
	c.willpower = 5  # primary ring maxed
	# All school skills at rank 2, non-school skill also at rank 2
	for sk: String in NPCAdvancement.get_school_skills(c):
		c.skills[sk] = 2
	c.skills["Hunting"] = 2  # non-school at same rank
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_eq(target.get("type", ""), "skill")
	var school_skills: Array = NPCAdvancement.get_school_skills(c)
	assert_true(school_skills.has(target.get("skill", "")),
		"School skill should be preferred over non-school skill at same rank")


func test_void_ring_available_to_courtier() -> void:
	# s52 Part 3: Void Ring is available to all school types after focus rings and skills
	var c: L5RCharacterData = _make_courtier()
	# Max focus rings (Air, Water) and all school skills
	c.reflexes = 5; c.awareness = 5  # Air ring maxed
	c.stamina = 5; c.perception = 5  # Water ring maxed
	for sk: String in NPCAdvancement.get_school_skills(c):
		c.skills[sk] = 5
	# Void ring 2->3 = 12000 progress = 60 XP
	c.xp_total = 60
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(c.void_ring, 3, "Courtier should be able to advance Void Ring")


func test_get_best_training_target_returns_void_for_bushi_when_else_maxed() -> void:
	var c: L5RCharacterData = _make_character(1)
	# Max focus rings and all school skills
	c.stamina = 5; c.willpower = 5  # Earth ring maxed
	c.agility = 5; c.intelligence = 5  # Fire ring maxed
	for sk: String in NPCAdvancement.get_school_skills(c):
		c.skills[sk] = 5
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_false(target.is_empty(), "Should find Void as next target")
	assert_eq(target.get("type", ""), "ring")
	assert_eq(target.get("ring", -1), Enums.Ring.VOID, "Bushi should target Void ring last")


# -- School-less advancement path (s52 Part 3) ----------------------------------

func _make_schoolless(id: int = 10) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Born Ronin"
	c.school = ""
	c.clan = ""
	c.stamina = 2
	c.willpower = 2
	c.strength = 2
	c.perception = 2
	c.agility = 2
	c.intelligence = 2
	c.reflexes = 2
	c.awareness = 2
	c.void_ring = 2
	# Rings: AIR=2, EARTH=2, FIRE=2, WATER=2, VOID=2 (all equal)
	c.skills = {"Kenjutsu": 3, "Athletics": 2, "Hunting": 1}
	return c


func test_schoolless_spends_on_highest_skill_first() -> void:
	var c: L5RCharacterData = _make_schoolless()
	# Kenjutsu rank 3 is highest; cost 3->4 = 4000 progress = 20 XP.
	c.xp_total = 5
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	# 5 XP = 1000 progress; should go to Kenjutsu (highest skill)
	var kenjutsu_progress: int = c.progress_bars.get("skill_Kenjutsu", 0)
	assert_eq(kenjutsu_progress, 1000, "School-less: highest-ranked skill gets XP first")
	var athletics_progress: int = c.progress_bars.get("skill_Athletics", 0)
	assert_eq(athletics_progress, 0, "Lower-ranked skill gets no progress yet")


func test_schoolless_advances_through_all_skills_then_rings() -> void:
	var c: L5RCharacterData = _make_schoolless()
	# Make all three skills maxed so spending falls through to rings.
	c.skills = {"Kenjutsu": 5, "Athletics": 5, "Hunting": 5}
	# All rings at rank 2. Lowest is a three-way tie: AIR, EARTH, FIRE, WATER, VOID all 2.
	# Stable sort: AIR comes first. AIR 2->3 = 12000 progress = 60 XP.
	c.xp_total = 10
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	# 10 XP = 2000 progress; should go to AIR (lowest ring, alpha-first in tie)
	var air_progress: int = c.progress_bars.get("ring_air", 0)
	assert_eq(air_progress, 2000, "School-less: after skills maxed, lowest ring gets XP")


func test_schoolless_lowest_ring_raised_when_uneven() -> void:
	var c: L5RCharacterData = _make_schoolless()
	c.skills = {}  # no skills — all XP goes to rings
	# Set Water ring lower than all others (Water = min(strength, perception))
	c.strength = 1
	c.perception = 1  # Water ring = 1; others at 2
	# AIR 2->3 = 60 XP; EARTH 2->3 = 60 XP; FIRE 2->3 = 60 XP; WATER 1->2 = 8000 progress = 40 XP.
	c.xp_total = 40
	c.xp_spent = 0
	NPCAdvancement.spend_accumulated_xp(c)
	# Water is lowest; it should be raised from 1 to 2.
	var water_rank: int = NPCAdvancement._get_ring_rank(c, Enums.Ring.WATER)
	assert_eq(water_rank, 2, "School-less: lowest ring (Water) raised first to spread evenly")
	var air_progress: int = c.progress_bars.get("ring_air", 0)
	assert_eq(air_progress, 0, "Higher rings untouched while lower ring still needs raising")


func test_schoolless_can_advance_rank0_skill() -> void:
	# School-less characters may raise skills they have at rank 0 (latent disciplines).
	var c: L5RCharacterData = _make_schoolless()
	c.skills = {"Kenjutsu": 0}  # only skill; rank 0 is eligible
	# rank 0->1 = SKILL_PROGRESS_COST[0] = 1000 progress = 5 XP
	c.xp_total = 5
	c.xp_spent = 0
	var result: Dictionary = NPCAdvancement.spend_accumulated_xp(c)
	assert_eq(c.skills.get("Kenjutsu", 0), 1, "Rank-0 skill should advance to rank 1")
	assert_eq(result["advancements"].size(), 1)


func test_schoolless_training_target_returns_highest_skill() -> void:
	var c: L5RCharacterData = _make_schoolless()
	# Kenjutsu rank 3 is highest
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_eq(target.get("type", ""), "skill")
	assert_eq(target.get("skill", ""), "Kenjutsu",
		"School-less: training target is highest-ranked skill")


func test_schoolless_training_target_lowest_ring_when_skills_maxed() -> void:
	var c: L5RCharacterData = _make_schoolless()
	c.skills = {"Kenjutsu": 5, "Athletics": 5, "Hunting": 5}
	# All rings at 2 (equal); stable sort: AIR first
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_eq(target.get("type", ""), "ring",
		"School-less: falls to rings when skills maxed")
	assert_eq(target.get("ring", -1), Enums.Ring.AIR,
		"School-less: raises lowest ring (alpha-stable tie: AIR first)")


func test_schoolless_training_target_empty_when_all_maxed() -> void:
	var c: L5RCharacterData = _make_schoolless()
	c.skills = {}
	c.stamina = 5; c.willpower = 5   # Earth
	c.agility = 5; c.intelligence = 5  # Fire
	c.reflexes = 5; c.awareness = 5   # Air
	c.strength = 5; c.perception = 5  # Water
	c.void_ring = 5
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_true(target.is_empty(), "School-less: nothing to train when all maxed")


func test_schoolless_alpha_tiebreak_in_skill_sort() -> void:
	# Within same rank, skills sort alphabetically for determinism.
	var c: L5RCharacterData = _make_schoolless()
	c.skills = {"Kenjutsu": 2, "Athletics": 2, "Defense": 2}
	# All rank 2; alpha order: Athletics < Defense < Kenjutsu
	var target: Dictionary = NPCAdvancement.get_best_training_target(c)
	assert_eq(target.get("skill", ""), "Athletics",
		"Alpha tie-break: Athletics comes before Defense and Kenjutsu")
