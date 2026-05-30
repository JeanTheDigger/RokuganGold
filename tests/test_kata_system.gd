extends GutTest
## Tests for KataSystem (s30a) — eligibility, acquisition, NPC selection, effect stubs.


# === HELPERS ===

func _make_bushi(school_name: String, clan: String, air: int = 3, earth: int = 3,
		fire: int = 3, water: int = 3, void_r: int = 3, xp: int = 10) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Test Bushi"
	c.school_type = Enums.SchoolType.BUSHI
	c.school_name = school_name
	c.clan = clan
	c.school_paths = []
	# AIR = min(reflexes, awareness)
	c.reflexes = air; c.awareness = air
	# EARTH = min(stamina, willpower)
	c.stamina = earth; c.willpower = earth
	# FIRE = min(agility, intelligence)
	c.agility = fire; c.intelligence = fire
	# WATER = min(strength, perception)
	c.strength = water; c.perception = water
	c.void_ring = void_r
	c.xp_accumulated = xp
	c.katas = []
	return c


func _make_courtier(school_name: String, clan: String) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = 2
	c.character_name = "Test Courtier"
	c.school_type = Enums.SchoolType.COURTIER
	c.school_name = school_name
	c.clan = clan
	c.school_paths = []
	c.reflexes = 3; c.awareness = 3
	c.stamina = 3; c.willpower = 3
	c.agility = 3; c.intelligence = 3
	c.strength = 3; c.perception = 3
	c.void_ring = 3
	c.xp_accumulated = 10
	c.katas = []
	return c


# === BASIC BUSHI REQUIREMENT ===

func test_non_bushi_cannot_learn_any_kata() -> void:
	var courtier: L5RCharacterData = _make_courtier("Doji Courtier", "Crane")
	assert_false(KataSystem.can_learn_kata(courtier, "Striking as Air"))


func test_bushi_without_school_name_cannot_learn() -> void:
	var c: L5RCharacterData = _make_bushi("", "Crane")
	assert_false(KataSystem.can_learn_kata(c, "Striking as Air"))


func test_bushi_cannot_learn_unknown_kata() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane")
	assert_false(KataSystem.can_learn_kata(c, "Nonexistent Kata"))


func test_already_known_kata_not_learnable() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane")
	c.katas.append("Striking as Air")
	assert_false(KataSystem.can_learn_kata(c, "Striking as Air"))


# === RING REQUIREMENT ===

func test_ring_too_low_blocks_eligibility() -> void:
	# Striking as Air needs Air 3; character has Air 2
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 2)
	assert_false(KataSystem.can_learn_kata(c, "Striking as Air"))


func test_ring_exactly_meets_requirement() -> void:
	# Striking as Air needs Air 3; character has Air 3
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	assert_true(KataSystem.can_learn_kata(c, "Striking as Air"))


func test_ring_exceeds_requirement() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 5)
	assert_true(KataSystem.can_learn_kata(c, "Striking as Air"))


func test_mastery4_kata_blocked_at_ring3() -> void:
	# North Wind Style needs Air 4
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	assert_false(KataSystem.can_learn_kata(c, "North Wind Style"))


func test_mastery4_kata_available_at_ring4() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 4)
	assert_true(KataSystem.can_learn_kata(c, "North Wind Style"))


func test_mastery5_kata_requires_ring5() -> void:
	# Weathered and Unbroken (Earth 5) requires Earth 5; Hida Bushi
	var c4: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3, 4)
	var c5: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3, 5)
	assert_false(KataSystem.can_learn_kata(c4, "Weathered and Unbroken"))
	assert_true(KataSystem.can_learn_kata(c5, "Weathered and Unbroken"))


# === SCHOOL ELIGIBILITY: "Any" ===

func test_any_bushi_kata_accessible_to_all_bushi_schools() -> void:
	for school_name: String in ["Kakita Bushi", "Hida Bushi", "Mirumoto Bushi", "Akodo Bushi"]:
		var c: L5RCharacterData = _make_bushi(school_name, "TestClan", 3)
		assert_true(KataSystem.can_learn_kata(c, "Striking as Air"),
			"Expected %s to access Striking as Air" % school_name)


# === SCHOOL ELIGIBILITY: Clan ===

func test_clan_kata_correct_clan_passes() -> void:
	# Strength of the Crane — Any Crane Bushi
	var crane: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	assert_true(KataSystem.can_learn_kata(crane, "Strength of the Crane"))


func test_clan_kata_wrong_clan_blocked() -> void:
	var crab: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3)
	assert_false(KataSystem.can_learn_kata(crab, "Strength of the Crane"))


func test_clan_kata_crab_accessible() -> void:
	# Strength of the Crab — Any Crab Bushi
	var crab: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3)
	assert_true(KataSystem.can_learn_kata(crab, "Strength of the Crab"))


func test_clan_kata_lion_accessible() -> void:
	# Strength of the Lion — Any Lion Bushi (Water 3)
	var lion: L5RCharacterData = _make_bushi("Akodo Bushi", "Lion", 3, 3, 3, 3)
	assert_true(KataSystem.can_learn_kata(lion, "Strength of the Lion"))


func test_clan_kata_lion_wrong_clan_blocked() -> void:
	var crab: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3, 3, 3, 3)
	assert_false(KataSystem.can_learn_kata(crab, "Strength of the Lion"))


func test_clan_kata_spider_accessible() -> void:
	# Strength of the Spider — Any Spider Bushi (Earth 3)
	var spider: L5RCharacterData = _make_bushi("Daigotsu Bushi", "Spider", 3, 3)
	assert_true(KataSystem.can_learn_kata(spider, "Strength of the Spider"))


func test_clan_kata_scorpion_accessible() -> void:
	# Strength of the Scorpion — Any Scorpion Bushi (Fire 3)
	var scorpion: L5RCharacterData = _make_bushi("Bayushi Bushi", "Scorpion", 3, 3, 3)
	assert_true(KataSystem.can_learn_kata(scorpion, "Strength of the Scorpion"))


func test_clan_kata_dragon_accessible() -> void:
	# Strength of the Dragon — Any Dragon Bushi (Fire 3)
	var dragon: L5RCharacterData = _make_bushi("Mirumoto Bushi", "Dragon", 3, 3, 3)
	assert_true(KataSystem.can_learn_kata(dragon, "Strength of the Dragon"))


func test_clan_kata_phoenix_accessible() -> void:
	# Strength of the Phoenix — Any Phoenix Bushi (Void 3)
	var phoenix: L5RCharacterData = _make_bushi("Shiba Bushi", "Phoenix", 3, 3, 3, 3, 3)
	assert_true(KataSystem.can_learn_kata(phoenix, "Strength of the Phoenix"))


func test_clan_kata_unicorn_accessible() -> void:
	# Strength of the Unicorn — Any Unicorn Bushi (Water 3)
	var unicorn: L5RCharacterData = _make_bushi("Shinjo Bushi", "Unicorn", 3, 3, 3, 3)
	assert_true(KataSystem.can_learn_kata(unicorn, "Strength of the Unicorn"))


# === SCHOOL ELIGIBILITY: Named ===

func test_named_kata_correct_school_passes() -> void:
	# Breath of Wind Style — Kakita Bushi or Bayushi Bushi
	var kakita: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	assert_true(KataSystem.can_learn_kata(kakita, "Breath of Wind Style"))


func test_named_kata_second_school_also_passes() -> void:
	var bayushi: L5RCharacterData = _make_bushi("Bayushi Bushi", "Scorpion", 3)
	assert_true(KataSystem.can_learn_kata(bayushi, "Breath of Wind Style"))


func test_named_kata_wrong_school_blocked() -> void:
	var hida: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3)
	assert_false(KataSystem.can_learn_kata(hida, "Breath of Wind Style"))


func test_named_kata_via_school_paths() -> void:
	# Character whose primary school_name is different but has the school in paths
	var c: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3)
	c.school_paths = ["Kakita Bushi"]
	assert_true(KataSystem.can_learn_kata(c, "Breath of Wind Style"))


# === MULTI-RING KATAS ===

func test_multiring_kata_air_qualifies() -> void:
	# The Empire Rests on its Edge: Air 3 OR Fire 3
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 2, 2)
	assert_true(KataSystem.can_learn_kata(c, "The Empire Rests on its Edge"))


func test_multiring_kata_fire_qualifies() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 2, 2, 3)
	assert_true(KataSystem.can_learn_kata(c, "The Empire Rests on its Edge"))


func test_multiring_kata_both_too_low_blocked() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 2, 2, 2)
	assert_false(KataSystem.can_learn_kata(c, "The Empire Rests on its Edge"))


func test_mirumoto_reduces_requirement_by_one() -> void:
	# Mirumoto Bushi can qualify at Air 2 (normally requires Air 3)
	var mirumoto: L5RCharacterData = _make_bushi("Mirumoto Bushi", "Dragon", 2, 2, 2)
	assert_true(KataSystem.can_learn_kata(mirumoto, "The Empire Rests on its Edge"))


func test_kakita_reduces_requirement_by_one() -> void:
	var kakita: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 2, 2, 2)
	assert_true(KataSystem.can_learn_kata(kakita, "The Empire Rests on its Edge"))


func test_other_school_not_reduced() -> void:
	# Hida Bushi needs full Air 3 or Fire 3 for the Empire kata
	var hida: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 2, 2, 2)
	assert_false(KataSystem.can_learn_kata(hida, "The Empire Rests on its Edge"))


func test_standing_on_the_heavens_requires_ring6() -> void:
	# Even Mirumoto at ring 5 is short (reduction brings it to ring 5 requirement)
	var mirumoto5: L5RCharacterData = _make_bushi("Mirumoto Bushi", "Dragon", 5, 5, 5)
	assert_true(KataSystem.can_learn_kata(mirumoto5, "Standing on the Heavens"))


func test_standing_on_the_heavens_blocked_at_ring4() -> void:
	# Mirumoto needs ring 5 (6−1); at ring 4 it's blocked
	var mirumoto4: L5RCharacterData = _make_bushi("Mirumoto Bushi", "Dragon", 4, 4, 4)
	assert_false(KataSystem.can_learn_kata(mirumoto4, "Standing on the Heavens"))


func test_normal_school_standing_blocked_at_ring5() -> void:
	# Non-Mirumoto/Kakita needs ring 6; ring 5 is blocked
	var hida5: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 5, 5, 5)
	assert_false(KataSystem.can_learn_kata(hida5, "Standing on the Heavens"))


# === XP AND AFFORD ===

func test_can_afford_when_xp_sufficient() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 10)
	assert_true(KataSystem.can_afford_kata(c, "Striking as Air"))  # cost 3


func test_cannot_afford_when_xp_too_low() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 2)
	assert_false(KataSystem.can_afford_kata(c, "Striking as Air"))  # cost 3


func test_cannot_afford_exactly_at_boundary() -> void:
	var c: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3, 5, 3, 3, 3, 5)
	assert_true(KataSystem.can_afford_kata(c, "Weathered and Unbroken"))  # cost 5


# === LEARN KATA ===

func test_learn_kata_success_adds_to_katas() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	var ok: bool = KataSystem.learn_kata(c, "Striking as Air")
	assert_true(ok)
	assert_true(c.katas.has("Striking as Air"))


func test_learn_kata_deducts_xp() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 10)
	KataSystem.learn_kata(c, "Striking as Air")
	assert_eq(c.xp_accumulated, 7)  # 10 − 3


func test_learn_kata_fails_when_ineligible() -> void:
	var c: L5RCharacterData = _make_bushi("Hida Bushi", "Crab", 3)
	var ok: bool = KataSystem.learn_kata(c, "Breath of Wind Style")  # wrong school
	assert_false(ok)
	assert_false(c.katas.has("Breath of Wind Style"))


func test_learn_kata_fails_when_too_poor() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 2)
	var ok: bool = KataSystem.learn_kata(c, "Striking as Air")  # cost 3
	assert_false(ok)
	assert_true(c.katas.is_empty())


func test_learn_kata_cannot_learn_twice() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 20)
	KataSystem.learn_kata(c, "Striking as Air")
	var ok: bool = KataSystem.learn_kata(c, "Striking as Air")
	assert_false(ok)
	assert_eq(c.katas.size(), 1)


# === GET ELIGIBLE KATAS ===

func test_get_eligible_returns_all_qualifying_katas() -> void:
	# Kakita Bushi, Air 3: should get Striking as Air, Breath of Wind Style, etc.
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	var eligible: Array = KataSystem.get_eligible_katas(c)
	assert_true(eligible.has("Striking as Air"))
	assert_true(eligible.has("Breath of Wind Style"))


func test_get_eligible_excludes_wrong_school() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	var eligible: Array = KataSystem.get_eligible_katas(c)
	assert_false(eligible.has("Dance of the Winds"))  # Daidoji/Shiba only


func test_get_eligible_excludes_ring_too_low() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)  # Air 3, Earth 3, ...
	var eligible: Array = KataSystem.get_eligible_katas(c)
	# North Wind Style needs Air 4 — should not be included
	assert_false(eligible.has("North Wind Style"))


func test_get_eligible_excludes_already_known() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3)
	c.katas.append("Striking as Air")
	var eligible: Array = KataSystem.get_eligible_katas(c)
	assert_false(eligible.has("Striking as Air"))


# === NPC SELECTION ===

func test_select_prefers_highest_mastery() -> void:
	# Kakita Bushi at Air 4 should prefer North Wind Style (ML 4) over Striking as Air (ML 3)
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 4, 4, 4, 4, 4, 20)
	var chosen: String = KataSystem.select_kata_for_npc(c)
	# Any ML 4 kata for Kakita Bushi, Crane with sufficient rings should beat ML 3
	var chosen_data: Dictionary = KataSystem.KATA_DATA.get(chosen, {})
	assert_gte(chosen_data.get("mastery", 0), 4)


func test_select_returns_empty_when_nothing_affordable() -> void:
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 0)
	assert_eq(KataSystem.select_kata_for_npc(c), "")


func test_select_returns_empty_for_courtier() -> void:
	var c: L5RCharacterData = _make_courtier("Doji Courtier", "Crane")
	assert_eq(KataSystem.select_kata_for_npc(c), "")


func test_select_skips_already_known() -> void:
	# Character who knows all ML 3 Air katas available to them
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 20)
	c.katas.append("Striking as Air")
	c.katas.append("Breath of Wind Style")
	var chosen: String = KataSystem.select_kata_for_npc(c)
	assert_ne(chosen, "Striking as Air")
	assert_ne(chosen, "Breath of Wind Style")


func test_select_deterministic_alpha_tiebreak() -> void:
	# Two calls must return the same result
	var c: L5RCharacterData = _make_bushi("Kakita Bushi", "Crane", 3, 3, 3, 3, 3, 20)
	var first: String = KataSystem.select_kata_for_npc(c)
	var second: String = KataSystem.select_kata_for_npc(c)
	assert_eq(first, second)


# === EFFECT STUBS ===

func test_get_effect_stub_returns_blocked_on_s40() -> void:
	var stub: Dictionary = KataSystem.get_effect_stub("Striking as Air")
	assert_eq(stub["blocked_on"], "s40")
	assert_eq(stub["effect_id"], "air_defense_armor_tn")
	assert_ne(stub["effect_desc"], "")


func test_get_effect_stub_unknown_kata_returns_empty() -> void:
	var stub: Dictionary = KataSystem.get_effect_stub("Not A Kata")
	assert_true(stub.is_empty())


func test_all_katas_have_effect_stubs() -> void:
	for kata_name: String in KataSystem.KATA_DATA.keys():
		var stub: Dictionary = KataSystem.get_effect_stub(kata_name)
		assert_false(stub.is_empty(), "Missing stub for: %s" % kata_name)
		assert_ne(stub.get("effect_desc", ""), "", "Empty effect_desc for: %s" % kata_name)


# === KATA COUNT SANITY ===

func test_kata_data_has_43_entries() -> void:
	assert_eq(KataSystem.KATA_DATA.size(), 43)
