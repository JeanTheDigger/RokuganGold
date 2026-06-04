extends GutTest
## s31-s37 Spell System tests.

var _char: L5RCharacterData
var _dice: DiceEngine


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.school_type = Enums.SchoolType.SHUGENJA
	_char.school = "Kuni Shugenja"
	_char.insight_rank = 3
	_char.stamina = 3
	_char.willpower = 3
	_char.reflexes = 3
	_char.awareness = 2
	_char.agility = 2
	_char.intelligence = 3
	_char.strength = 2
	_char.perception = 3
	_char.void_ring = 2
	_char.affinity_element = Enums.Ring.NONE
	_char.deficiency_element = Enums.Ring.NONE
	_char.spells_known = ["jurojins_balm", "jade_strike", "sense", "commune"]
	_dice = DiceEngine.new()
	_dice.set_seed(42)


# -- Ring values ---------------------------------------------------------------

func test_get_ring_value_air() -> void:
	# AIR = min(reflexes, awareness) = min(3, 2) = 2
	assert_eq(SpellSystem.get_ring_value(_char, 0), 2)


func test_get_ring_value_earth() -> void:
	# EARTH = min(stamina, willpower) = min(3, 3) = 3
	assert_eq(SpellSystem.get_ring_value(_char, 1), 3)


func test_get_ring_value_fire() -> void:
	# FIRE = min(agility, intelligence) = min(2, 3) = 2
	assert_eq(SpellSystem.get_ring_value(_char, 2), 2)


func test_get_ring_value_water() -> void:
	# WATER = min(strength, perception) = min(2, 3) = 2
	assert_eq(SpellSystem.get_ring_value(_char, 3), 2)


func test_get_ring_value_void() -> void:
	assert_eq(SpellSystem.get_ring_value(_char, 4), 2)


func test_get_ring_value_invalid() -> void:
	assert_eq(SpellSystem.get_ring_value(_char, 9), 0)


# -- Effective school rank -----------------------------------------------------

func test_effective_rank_no_affinity_no_deficiency() -> void:
	assert_eq(SpellSystem.get_effective_school_rank(_char, 1), 3)  # rank 3, no mod


func test_effective_rank_with_affinity() -> void:
	_char.affinity_element = Enums.Ring.EARTH
	assert_eq(SpellSystem.get_effective_school_rank(_char, 1), 4)  # +1


func test_effective_rank_with_deficiency() -> void:
	_char.deficiency_element = Enums.Ring.EARTH
	assert_eq(SpellSystem.get_effective_school_rank(_char, 1), 2)  # -1


func test_effective_rank_deficiency_floor_zero() -> void:
	_char.insight_rank = 1
	_char.deficiency_element = Enums.Ring.EARTH
	assert_eq(SpellSystem.get_effective_school_rank(_char, 1), 0)  # 1-1=0


# -- Casting TN ----------------------------------------------------------------

func test_casting_tn_ml1() -> void:
	assert_eq(SpellSystem.get_casting_tn(1), 10)


func test_casting_tn_ml2() -> void:
	assert_eq(SpellSystem.get_casting_tn(2), 15)


func test_casting_tn_ml3() -> void:
	assert_eq(SpellSystem.get_casting_tn(3), 20)


func test_casting_tn_ml6() -> void:
	assert_eq(SpellSystem.get_casting_tn(6), 35)


# -- Best cast ring ------------------------------------------------------------

func test_best_cast_ring_elemental_earth() -> void:
	# earth spell always returns ring 1
	assert_eq(SpellSystem.get_best_cast_ring(_char, "jade_strike"), 1)


func test_best_cast_ring_universal_picks_best() -> void:
	# Universal: picks ring with highest (ring_val + eff_rank)
	# Earth: 3 + 3 = 6, others lower. Should pick Earth (ring 1).
	var ring: int = SpellSystem.get_best_cast_ring(_char, "sense")
	assert_eq(ring, 1)


func test_best_cast_ring_unknown_spell() -> void:
	assert_eq(SpellSystem.get_best_cast_ring(_char, "no_such_spell"), -1)


# -- Daily slots ---------------------------------------------------------------

func test_get_daily_slots_earth() -> void:
	# Earth ring = 3, so 3 earth slots
	assert_eq(SpellSystem.get_daily_slots(_char, 1), 3)


func test_get_daily_slots_void() -> void:
	assert_eq(SpellSystem.get_daily_slots(_char, 4), 2)


# -- Slot tracking -------------------------------------------------------------

func test_get_slots_used_empty() -> void:
	assert_eq(SpellSystem.get_slots_used(_char, 1), 0)


func test_consume_slot_increments() -> void:
	SpellSystem.consume_slot(_char, 1)
	assert_eq(SpellSystem.get_slots_used(_char, 1), 1)


func test_consume_slot_fills_to_ring_value() -> void:
	# Earth ring = 3, consume 3 times
	SpellSystem.consume_slot(_char, 1)
	SpellSystem.consume_slot(_char, 1)
	SpellSystem.consume_slot(_char, 1)
	assert_eq(SpellSystem.get_slots_used(_char, 1), 3)
	# 4th consume overflows to void bonus
	SpellSystem.consume_slot(_char, 1)
	assert_eq(SpellSystem.get_slots_used(_char, 1), 3)
	assert_eq(SpellSystem.get_void_bonus_used(_char), 1)


func test_can_afford_slot_when_available() -> void:
	assert_true(SpellSystem.can_afford_slot(_char, 1))


func test_can_afford_slot_after_exhaustion() -> void:
	# Exhaust primary and void bonus
	for _i in range(3):
		SpellSystem.consume_slot(_char, 1)
	for _i in range(2):  # void ring = 2
		SpellSystem.consume_slot(_char, 1)  # overflow to void
	assert_false(SpellSystem.can_afford_slot(_char, 1))


func test_daily_reset_clears_slots() -> void:
	SpellSystem.consume_slot(_char, 1)
	SpellSystem.consume_slot(_char, 1)
	_char.spell_slots_used = {}
	_char.spell_void_bonus_used = 0
	assert_eq(SpellSystem.get_slots_used(_char, 1), 0)


# -- can_cast ------------------------------------------------------------------

func test_can_cast_unknown_spell() -> void:
	assert_false(SpellSystem.can_cast(_char, "no_such_spell"))


func test_can_cast_not_in_spells_known() -> void:
	assert_false(SpellSystem.can_cast(_char, "wholeness_of_the_world"))


func test_can_cast_rank_gate() -> void:
	_char.spells_known.append("earthquake")  # ML5 earth
	_char.insight_rank = 4  # ML5 requires rank 5
	assert_false(SpellSystem.can_cast(_char, "earthquake"))


func test_can_cast_success() -> void:
	assert_true(SpellSystem.can_cast(_char, "jurojins_balm"))


func test_can_cast_false_when_slots_exhausted() -> void:
	# Exhaust all earth + void bonus slots
	for _i in range(3 + 2):
		SpellSystem.consume_slot(_char, 1)
	assert_false(SpellSystem.can_cast(_char, "jurojins_balm"))


func test_can_cast_ishiken_restriction_blocks_non_ishiken() -> void:
	_char.spells_known.append("see_through_lies")  # void ML1, Ishiken-only
	_char.insight_rank = 1
	assert_false(SpellSystem.can_cast(_char, "see_through_lies"))


func test_can_cast_ishiken_allowed_for_ishiken() -> void:
	_char.school = "Isawa Ishiken"
	_char.spells_known.append("see_through_lies")
	_char.insight_rank = 1
	assert_true(SpellSystem.can_cast(_char, "see_through_lies"))


# -- resolve_cast --------------------------------------------------------------

func test_resolve_cast_unknown_spell() -> void:
	var r: Dictionary = SpellSystem.resolve_cast(_char, "no_such_spell", _dice)
	assert_false(r["success"])
	assert_eq(r.get("error", ""), "unknown_spell")


func test_resolve_cast_returns_expected_keys() -> void:
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_true(r.has("success"))
	assert_true(r.has("total"))
	assert_true(r.has("tn"))
	assert_true(r.has("margin"))
	assert_true(r.has("spell_id"))
	assert_true(r.has("sim_effect"))
	assert_true(r.has("cast_ring"))


func test_resolve_cast_spell_id_matches() -> void:
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_eq(r["spell_id"], "jurojins_balm")


func test_resolve_cast_consumes_slot_on_attempt() -> void:
	var before: int = SpellSystem.get_slots_used(_char, 1)
	SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_eq(SpellSystem.get_slots_used(_char, 1), before + 1)


func test_resolve_cast_tn_is_casting_tn_for_ml() -> void:
	# jurojins_balm is ML1 earth, TN = 10
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_eq(r["tn"], 10)


func test_resolve_cast_raises_increase_tn() -> void:
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice, 2)
	assert_eq(r["tn"], 20)  # 10 + 2*5


# -- apply_healing -------------------------------------------------------------

func test_apply_healing_reduces_wounds() -> void:
	_char.wounds_taken = 5
	var r: Dictionary = SpellSystem.apply_healing(_char, "jurojins_balm", 10)
	assert_true(_char.wounds_taken < 5)
	assert_true(r["healed_wounds"] > 0)


func test_apply_healing_cannot_go_negative() -> void:
	_char.wounds_taken = 0
	SpellSystem.apply_healing(_char, "jurojins_balm", 100)
	assert_eq(_char.wounds_taken, 0)


# -- apply_taint_removal -------------------------------------------------------

func test_apply_taint_removal_reduces_taint() -> void:
	_char.taint = 3.0
	var r: Dictionary = SpellSystem.apply_taint_removal(_char, "purge_the_taint", 10)
	assert_true(_char.taint < 3.0)
	assert_true(r["taint_removed"] > 0.0)


func test_apply_taint_removal_floor_zero() -> void:
	_char.taint = 0.0
	SpellSystem.apply_taint_removal(_char, "purge_the_taint", 100)
	assert_eq(_char.taint, 0.0)


# -- assign_starting_spells ----------------------------------------------------

func test_assign_starting_spells_known_school() -> void:
	_char.spells_known = []
	SpellSystem.assign_starting_spells(_char, "Kuni Shugenja")
	assert_true("sense" in _char.spells_known)
	assert_true("commune" in _char.spells_known)
	assert_true("jade_strike" in _char.spells_known)


func test_assign_starting_spells_default_unknown_school() -> void:
	_char.spells_known = []
	SpellSystem.assign_starting_spells(_char, "Unknown School XYZ")
	assert_true("sense" in _char.spells_known)
	assert_true("commune" in _char.spells_known)


func test_assign_starting_spells_no_duplicates() -> void:
	_char.spells_known = ["sense"]
	SpellSystem.assign_starting_spells(_char, "Kuni Shugenja")
	var count: int = 0
	for s: String in _char.spells_known:
		if s == "sense":
			count += 1
	assert_eq(count, 1)


# -- is_shugenja ---------------------------------------------------------------

func test_is_shugenja_true_for_shugenja() -> void:
	assert_true(SpellSystem.is_shugenja(_char))


func test_is_shugenja_false_for_bushi() -> void:
	var bushi: L5RCharacterData = L5RCharacterData.new()
	bushi.school_type = Enums.SchoolType.BUSHI
	assert_false(SpellSystem.is_shugenja(bushi))


# -- get_spells_by_sim_effect --------------------------------------------------

func test_get_spells_by_sim_effect_returns_matching() -> void:
	_char.spells_known = ["jurojins_balm", "jade_strike", "sense"]
	var healers: Array[String] = SpellSystem.get_spells_by_sim_effect(
		_char, SpellSystem.SpellSimEffect.HEAL_WOUNDS
	)
	assert_true("jurojins_balm" in healers)
	assert_false("jade_strike" in healers)


func test_get_spells_by_sim_effect_empty_when_none() -> void:
	_char.spells_known = ["jade_strike"]
	var result: Array[String] = SpellSystem.get_spells_by_sim_effect(
		_char, SpellSystem.SpellSimEffect.HEAL_WOUNDS
	)
	assert_eq(result.size(), 0)


# -- get_best_spell_by_effect --------------------------------------------------

func test_get_best_spell_by_effect_picks_highest_ml() -> void:
	_char.spells_known = ["jurojins_balm", "wholeness_of_the_world", "drawing_on_the_mountain"]
	# jurojins_balm=ML1, wholeness=ML2, drawing=ML5 — all HEAL_WOUNDS
	var best: String = SpellSystem.get_best_spell_by_effect(
		_char, SpellSystem.SpellSimEffect.HEAL_WOUNDS
	)
	assert_eq(best, "drawing_on_the_mountain")


func test_get_best_spell_by_effect_empty_string_when_none() -> void:
	_char.spells_known = []
	var best: String = SpellSystem.get_best_spell_by_effect(
		_char, SpellSystem.SpellSimEffect.HEAL_WOUNDS
	)
	assert_eq(best, "")


# -- get_spells_for_element_ml -------------------------------------------------

func test_get_spells_for_element_ml_returns_correct_set() -> void:
	var earth_ml1: Array[String] = SpellSystem.get_spells_for_element_ml(1, 1)
	assert_true("jurojins_balm" in earth_ml1)
	assert_true("jade_strike" in earth_ml1)
	assert_false("sense" in earth_ml1)  # sense is universal (e=-1)


func test_get_spells_for_element_ml_universal_not_included() -> void:
	var universal_ml1: Array[String] = SpellSystem.get_spells_for_element_ml(-1, 1)
	assert_true("sense" in universal_ml1)
	assert_true("commune" in universal_ml1)
	assert_false("jade_strike" in universal_ml1)


# -- WRATH_OF_THE_KAMI (s45) --------------------------------------------------

func test_wrath_of_kami_result_has_bonus_key() -> void:
	# resolve_cast always includes wrath_of_kami_bonus in return dict.
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_true(r.has("wrath_of_kami_bonus"))


func test_wrath_of_kami_no_target_bonus_is_zero() -> void:
	# When no target is provided, the bonus is 0 and TN is unmodified.
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_eq(r.get("wrath_of_kami_bonus", -1), 0)
	assert_eq(r.get("tn", -1), 10)  # ML1 base TN with no raises


func test_wrath_of_kami_matching_element_reduces_tn() -> void:
	# Target cursed for EARTH; caster casts an earth spell → TN is 5 lower.
	var target: L5RCharacterData = L5RCharacterData.new()
	target.character_id = 99
	target.advantages = []
	var dis: DisadvantageData = DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.WRATH_OF_THE_KAMI
	dis.metadata = {"element": Enums.Ring.EARTH}
	target.disadvantages = [dis]

	# jurojins_balm is ML1 earth → base TN = 10; with wrath bonus = 1 FR, TN = 10 - 5 = 5.
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice, 0, target)
	assert_eq(r.get("wrath_of_kami_bonus", -1), 1)
	assert_eq(r.get("tn", -1), 5)


func test_wrath_of_kami_wrong_element_no_reduction() -> void:
	# Target cursed for FIRE; caster casts an EARTH spell → no bonus, TN unchanged.
	var target: L5RCharacterData = L5RCharacterData.new()
	target.character_id = 99
	target.advantages = []
	var dis: DisadvantageData = DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.WRATH_OF_THE_KAMI
	dis.metadata = {"element": Enums.Ring.FIRE}
	target.disadvantages = [dis]

	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice, 0, target)
	assert_eq(r.get("wrath_of_kami_bonus", -1), 0)
	assert_eq(r.get("tn", -1), 10)  # ML1 base TN, unmodified


func test_wrath_of_kami_target_without_disadvantage_no_bonus() -> void:
	# Target exists but has no WRATH_OF_THE_KAMI disadvantage.
	var target: L5RCharacterData = L5RCharacterData.new()
	target.character_id = 99
	target.advantages = []
	target.disadvantages = []

	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice, 0, target)
	assert_eq(r.get("wrath_of_kami_bonus", -1), 0)


func test_wrath_of_kami_stacks_with_raises() -> void:
	# WRATH bonus still applies when caster also declares raises.
	# jurojins_balm ML1: base TN 10, 1 raise → effective TN = 15; wrath → 15 - 5 = 10.
	var target: L5RCharacterData = L5RCharacterData.new()
	target.character_id = 99
	target.advantages = []
	var dis: DisadvantageData = DisadvantageData.new()
	dis.disadvantage_type = Enums.Disadvantage.WRATH_OF_THE_KAMI
	dis.metadata = {"element": Enums.Ring.EARTH}
	target.disadvantages = [dis]

	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice, 1, target)
	assert_eq(r.get("wrath_of_kami_bonus", -1), 1)
	assert_eq(r.get("tn", -1), 10)  # 10 + 5 (raise) - 5 (wrath) = 10


# -- MASTER_OF_BLOOD +10 TN on non-maho spells (s44 line 117) --------------------

func _add_master_of_blood(char: L5RCharacterData) -> void:
	char.mutations = []
	char.shadowlands_powers = []
	var p: ShadowlandsPowerData = ShadowlandsPowerData.new()
	p.power_type = Enums.ShadowlandsPowerType.MASTER_OF_BLOOD
	p.tier = Enums.ShadowlandsPowerTier.MAJOR
	char.shadowlands_powers = [p]
	char.taint = 3.0


func test_master_of_blood_adds_10_tn_to_non_maho_spell() -> void:
	# jurojins_balm ML1: base TN = 10. With MASTER_OF_BLOOD TN must be 20.
	_char.spell_slots_used = {}
	_char.spell_void_bonus_used = 0
	_char.advantages = []
	_char.disadvantages = []
	_add_master_of_blood(_char)
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_eq(r.get("tn", -1), 20)


func test_master_of_blood_stacks_with_raises() -> void:
	# 1 raise adds +5; MASTER_OF_BLOOD adds +10 → TN = 25.
	_char.spell_slots_used = {}
	_char.spell_void_bonus_used = 0
	_char.advantages = []
	_char.disadvantages = []
	_add_master_of_blood(_char)
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice, 1)
	assert_eq(r.get("tn", -1), 25)


func test_no_master_of_blood_no_extra_tn() -> void:
	# Without the power TN is the base 10 for ML1.
	_char.spell_slots_used = {}
	_char.spell_void_bonus_used = 0
	_char.advantages = []
	_char.disadvantages = []
	_char.mutations = []
	_char.shadowlands_powers = []
	var r: Dictionary = SpellSystem.resolve_cast(_char, "jurojins_balm", _dice)
	assert_eq(r.get("tn", -1), 10)


# -- sim_effect classification corrections ------------------------------------

func test_purge_the_taint_is_purify_area() -> void:
	# GDD s34: purges Taint from land/objects, cannot remove from living creatures.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["purge_the_taint"].get("s"),
		SpellSystem.SpellSimEffect.PURIFY_AREA
	)


func test_fires_that_cleanse_is_combat_only() -> void:
	# GDD s35: area fire damage spell — no taint removal in description.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["the_fires_that_cleanse"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_essence_of_jade_is_ward_creation() -> void:
	# GDD s34: prevents gaining Taint and blocks maho — a protection ward, not removal.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["essence_of_jade"].get("s"),
		SpellSystem.SpellSimEffect.WARD_CREATION
	)


# -- apply_purify_area --------------------------------------------------------

func test_apply_purify_area_reduces_province_ptl() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_taint_level = 3.0
	var result: Dictionary = SpellSystem.apply_purify_area(province, "purge_the_taint", 0)
	assert_true(province.province_taint_level < 3.0)
	assert_true(result.get("ptl_reduced", 0.0) > 0.0)


func test_apply_purify_area_higher_margin_removes_more() -> void:
	var p1: ProvinceData = ProvinceData.new()
	p1.province_taint_level = 5.0
	var p2: ProvinceData = ProvinceData.new()
	p2.province_taint_level = 5.0
	SpellSystem.apply_purify_area(p1, "purge_the_taint", 0)
	SpellSystem.apply_purify_area(p2, "purge_the_taint", 10)
	assert_true(p2.province_taint_level < p1.province_taint_level)


func test_apply_purify_area_floors_at_zero() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_taint_level = 0.2
	SpellSystem.apply_purify_area(province, "purge_the_taint", 100)
	assert_eq(province.province_taint_level, 0.0)


func test_apply_purify_area_returns_actual_reduced_amount() -> void:
	var province: ProvinceData = ProvinceData.new()
	province.province_taint_level = 0.5
	# purge_the_taint base=1.0 + 0*0.1 = 1.0, but PTL only 0.5 → reduced = 0.5
	var result: Dictionary = SpellSystem.apply_purify_area(province, "purge_the_taint", 0)
	assert_almost_eq(result.get("ptl_reduced", -1.0), 0.5, 0.001)


# -- get_best_purify_spell ----------------------------------------------------

func test_get_best_purify_spell_returns_purge_the_taint() -> void:
	_char.spells_known = ["sense", "commune", "purge_the_taint"]
	_char.insight_rank = 3
	assert_eq(SpellSystem.get_best_purify_spell(_char), "purge_the_taint")


func test_get_best_purify_spell_empty_when_none_known() -> void:
	# No PURIFY_AREA spells in default kit.
	assert_eq(SpellSystem.get_best_purify_spell(_char), "")


# -- apply_ward_creation -------------------------------------------------------

func test_apply_ward_creation_clean_caster_applies_ward() -> void:
	# Taint < 1.0 = rank 0 — jade spirits do not recoil.
	_char.taint = 0.9
	var result: Dictionary = SpellSystem.apply_ward_creation(_char, "essence_of_jade")
	assert_eq(result.get("ward_applied"), true)


func test_apply_ward_creation_clean_caster_no_taint_reveal() -> void:
	_char.taint = 0.0
	var result: Dictionary = SpellSystem.apply_ward_creation(_char, "essence_of_jade")
	assert_eq(result.get("taint_revealed"), false)


func test_apply_ward_creation_blocked_at_rank1() -> void:
	# Taint 1.0 = rank 1 — GDD s34: cannot cast on anyone with at least 1 full Rank of Taint.
	_char.taint = 1.0
	var result: Dictionary = SpellSystem.apply_ward_creation(_char, "essence_of_jade")
	assert_eq(result.get("ward_applied"), false)


func test_apply_ward_creation_reveals_taint_when_blocked() -> void:
	# s34: jade spirits "immediately alerting the caster to their Tainted nature."
	_char.taint = 1.0
	var result: Dictionary = SpellSystem.apply_ward_creation(_char, "essence_of_jade")
	assert_eq(result.get("taint_revealed"), true)


func test_apply_ward_creation_blocked_at_higher_rank() -> void:
	# Rank 3 is also blocked — gate is >= 1, not exactly == 1.
	_char.taint = 3.5
	var result: Dictionary = SpellSystem.apply_ward_creation(_char, "essence_of_jade")
	assert_eq(result.get("ward_applied"), false)
	assert_eq(result.get("taint_revealed"), true)


func test_apply_ward_creation_boundary_below_rank1() -> void:
	# Taint 0.999 = still rank 0 — ward succeeds (int(0.999) = 0).
	_char.taint = 0.999
	var result: Dictionary = SpellSystem.apply_ward_creation(_char, "essence_of_jade")
	assert_eq(result.get("ward_applied"), true)


# -- spell library classification fixes ----------------------------------------

func test_taming_the_beast_is_combat_only() -> void:
	# GDD s34: tames a natural animal; not a spirit-binding spell.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["taming_the_beast"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_the_ties_that_bind_is_information_gather() -> void:
	# GDD s36: locates a specific familiar object — Divination, not spirit binding.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["the_ties_that_bind"].get("s"),
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


func test_the_final_bond_is_information_gather() -> void:
	# GDD s36: locates a well-known person regardless of location — Divination, not binding.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["the_final_bond"].get("s"),
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


# -- can_bind_realm / find_bindable_spirit_event --------------------------------

func test_bonds_of_ningen_do_can_bind_gaki_do() -> void:
	assert_true(SpellSystem.can_bind_realm("bonds_of_ningen_do", Enums.SpiritRealm.GAKI_DO))


func test_bonds_of_ningen_do_can_bind_toshigoku() -> void:
	assert_true(SpellSystem.can_bind_realm("bonds_of_ningen_do", Enums.SpiritRealm.TOSHIGOKU))


func test_bonds_of_ningen_do_cannot_bind_meido() -> void:
	# GDD s34 ML3: explicitly lists Sakkaku/Chikushudo/Gaki-Do/Toshigoku/Yume-Do.
	# Meido (realm of the dead) is not listed.
	assert_false(SpellSystem.can_bind_realm("bonds_of_ningen_do", Enums.SpiritRealm.MEIDO))


func test_minor_binding_cannot_bind_realm_spirits() -> void:
	# minor_binding targets Shadowlands creatures — no realm list.
	assert_false(SpellSystem.can_bind_realm("minor_binding", Enums.SpiritRealm.GAKI_DO))


func test_find_bindable_spirit_event_returns_matching_event() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencyData.new()
	event.event_id = 1
	event.province_id = 5
	event.event_type = Enums.SpiritualEventType.REALM_OVERLAP
	event.realm = Enums.SpiritRealm.GAKI_DO
	event.resolved = false
	var found: SpiritualInsurgencyData = SpellSystem.find_bindable_spirit_event(
		"bonds_of_ningen_do", 5, [event]
	)
	assert_eq(found, event)


func test_find_bindable_spirit_event_skips_resolved_events() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencyData.new()
	event.event_id = 1
	event.province_id = 5
	event.event_type = Enums.SpiritualEventType.REALM_OVERLAP
	event.realm = Enums.SpiritRealm.GAKI_DO
	event.resolved = true
	var found: SpiritualInsurgencyData = SpellSystem.find_bindable_spirit_event(
		"bonds_of_ningen_do", 5, [event]
	)
	assert_null(found)


func test_find_bindable_spirit_event_skips_wrong_province() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencyData.new()
	event.event_id = 1
	event.province_id = 99
	event.event_type = Enums.SpiritualEventType.REALM_OVERLAP
	event.realm = Enums.SpiritRealm.GAKI_DO
	event.resolved = false
	var found: SpiritualInsurgencyData = SpellSystem.find_bindable_spirit_event(
		"bonds_of_ningen_do", 5, [event]
	)
	assert_null(found)


func test_find_bindable_spirit_event_skips_elemental_imbalance() -> void:
	# ELEMENTAL_IMBALANCE events are not REALM_OVERLAP — binding spells cannot target them.
	var event: SpiritualInsurgencyData = SpiritualInsurgencyData.new()
	event.event_id = 1
	event.province_id = 5
	event.event_type = Enums.SpiritualEventType.ELEMENTAL_IMBALANCE
	event.realm = Enums.SpiritRealm.GAKI_DO
	event.resolved = false
	var found: SpiritualInsurgencyData = SpellSystem.find_bindable_spirit_event(
		"bonds_of_ningen_do", 5, [event]
	)
	assert_null(found)


# -- binding spell reclassifications (minor_binding / major_binding) --------------

func test_minor_binding_is_combat_only() -> void:
	# GDD s34 ML1: binds Shadowlands/Tainted creatures for 2 hours — combat duration only.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["minor_binding"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_major_binding_is_combat_only() -> void:
	# GDD s34 ML5: binds any Lost/Shadowlands/Tainted creature for 12 hours — combat duration.
	# Does not suppress REALM_OVERLAP spiritual insurgency events.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["major_binding"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


# -- freedom_of_the_air: SPIRIT_BIND reclassification from DISPEL_MAGIC ---------

func test_freedom_of_the_air_is_spirit_bind() -> void:
	# GDD s33 ML2: "kansen, ghosts, and other hostile disembodied spirits within
	# are compelled to leave for the spell's duration" — realm-agnostic, hours duration.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["freedom_of_the_air"].get("s"),
		SpellSystem.SpellSimEffect.SPIRIT_BIND
	)


func test_freedom_of_the_air_can_bind_gaki_do() -> void:
	assert_true(SpellSystem.can_bind_realm("freedom_of_the_air", Enums.SpiritRealm.GAKI_DO))


func test_freedom_of_the_air_can_bind_meido() -> void:
	# Unlike bonds_of_ningen_do, freedom_of_the_air affects all spirits including Meido.
	assert_true(SpellSystem.can_bind_realm("freedom_of_the_air", Enums.SpiritRealm.MEIDO))


func test_freedom_of_the_air_can_bind_all_realms() -> void:
	for realm: int in Enums.SpiritRealm.values():
		assert_true(
			SpellSystem.can_bind_realm("freedom_of_the_air", realm as Enums.SpiritRealm),
			"freedom_of_the_air should bind realm %d" % realm
		)


func test_freedom_of_the_air_find_bindable_event_meido() -> void:
	# Verify find_bindable_spirit_event finds a MEIDO REALM_OVERLAP event for freedom_of_the_air.
	var event: SpiritualInsurgencyData = SpiritualInsurgencyData.new()
	event.event_id = 10
	event.province_id = 3
	event.event_type = Enums.SpiritualEventType.REALM_OVERLAP
	event.realm = Enums.SpiritRealm.MEIDO
	event.resolved = false
	var found: SpiritualInsurgencyData = SpellSystem.find_bindable_spirit_event(
		"freedom_of_the_air", 3, [event]
	)
	assert_eq(found, event)


# -- DISPEL_MAGIC → COMBAT_ONLY reclassifications --------------------------------

func test_draw_back_the_shadow_is_combat_only() -> void:
	# GDD s33 ML5: dispels illusions — combat-duration effect.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["draw_back_the_shadow"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_grounding_energy_is_combat_only() -> void:
	# GDD s34 ML5: anti-maho TN boost for 3 rounds — combat only.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["grounding_energy"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_extinguish_is_combat_only() -> void:
	# GDD s35 ML1: dismisses fire kami / extinguishes fire — instantaneous combat effect.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["extinguish"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_banish_the_void_is_combat_only() -> void:
	# GDD s37 ML3: thickens the Void veil for 5 rounds — combat only.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["banish_the_void"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_void_release_is_combat_only() -> void:
	# GDD s37 ML3: transfers Void Points — combat aid, not a dispel.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["void_release"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_unbound_essence_is_combat_only() -> void:
	# GDD s37 ML5: randomly reorders Rings for 1 hour — no trackable simulation state.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["unbound_essence"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


# -- HEAL_WOUNDS spell classification -------------------------------------------

func test_regrow_the_wound_is_heal_wounds() -> void:
	# GDD s36 ML3: "Target recovers Wounds equal to Water Ring + School Rank each Round."
	assert_eq(
		SpellSystem.SPELL_LIBRARY["regrow_the_wound"].get("s"),
		SpellSystem.SpellSimEffect.HEAL_WOUNDS
	)


func test_rise_from_the_ashes_is_heal_wounds() -> void:
	# GDD s37 ML6: restores existence to how it was 8 hours prior, undoing injuries.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["rise_from_the_ashes"].get("s"),
		SpellSystem.SpellSimEffect.HEAL_WOUNDS
	)


# -- Buff spells reclassified COMBAT_ONLY (were incorrectly HEAL_WOUNDS) ---------

func test_wholeness_of_the_world_is_combat_only() -> void:
	# GDD s34 ML2: Rings/Traits resistant to change — buff, not wound healing.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["wholeness_of_the_world"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_drawing_on_the_mountain_is_combat_only() -> void:
	# GDD s34 ML5: doubles structure Wounds/Reduction for siege — structure buff.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["drawing_on_the_mountain"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_sympathetic_energies_is_combat_only() -> void:
	# GDD s36 ML1: transfers an existing spell effect to another target — not wound healing.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["sympathetic_energies"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_rejuvenating_vapors_is_combat_only() -> void:
	# GDD s36 ML2: removes fatigue, restores Void Ring spell slots — not wound healing.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["rejuvenating_vapors"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_fill_the_emptiness_is_combat_only() -> void:
	# GDD s37 ML4: restores Void Points — not wound healing.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["fill_the_emptiness"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


# -- s31-37a WEATHER_SHIFT reclassifications and province weather helpers ------

func test_blessed_wind_is_combat_only() -> void:
	# Air ML1: concentration ranged defence — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["blessed_wind"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_blessed_wind_of_lady_sun_is_combat_only() -> void:
	# Air ML2: concentration area aura — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["blessed_wind_of_lady_sun"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_summoning_the_gale_is_combat_only() -> void:
	# Air ML3: concentration area wind block — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["summoning_the_gale"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_summon_fog_is_combat_only() -> void:
	# Air ML3: concentration fog ("while maintained") — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["summon_fog"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_howl_of_isora_is_combat_only() -> void:
	# Air ML4: one-time damage blast — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["howl_of_isora"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_the_swell_of_the_storm_is_combat_only() -> void:
	# Water ML1: one-time knockdown — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["the_swell_of_the_storm"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_heavens_tears_is_combat_only() -> void:
	# Water ML2: brief per-round deluge, outdoors only — no province weather write.
	assert_eq(
		SpellSystem.SPELL_LIBRARY["heavens_tears"].get("s"),
		SpellSystem.SpellSimEffect.COMBAT_ONLY
	)


func test_endless_deluge_is_weather_shift() -> void:
	# Water ML3 ritual — only province-scale WEATHER_SHIFT spell (A80).
	assert_eq(
		SpellSystem.SPELL_LIBRARY["endless_deluge"].get("s"),
		SpellSystem.SpellSimEffect.WEATHER_SHIFT
	)


func test_breath_of_mist_is_weather_shift() -> void:
	# Water ML6 — province-scale mist (A82).
	assert_eq(
		SpellSystem.SPELL_LIBRARY["breath_of_mist"].get("s"),
		SpellSystem.SpellSimEffect.WEATHER_SHIFT
	)


func test_get_weather_shift_state_endless_deluge() -> void:
	# A80: endless_deluge → WeatherState.STORM (3).
	assert_eq(SpellSystem.get_weather_shift_state("endless_deluge"), 3)


func test_get_weather_shift_state_breath_of_mist() -> void:
	# A82: breath_of_mist → WeatherState.MIST (5).
	assert_eq(SpellSystem.get_weather_shift_state("breath_of_mist"), 5)


func test_get_weather_shift_state_unknown_returns_clear() -> void:
	# Any non-province-weather spell returns 0 (CLEAR).
	assert_eq(SpellSystem.get_weather_shift_state("blessed_wind"), 0)
	assert_eq(SpellSystem.get_weather_shift_state(""), 0)


func test_get_weather_shift_duration_endless_deluge() -> void:
	# A81: 12 hours → 1 IC day tick.
	assert_eq(SpellSystem.get_weather_shift_duration_days("endless_deluge"), 1)


func test_get_weather_shift_duration_breath_of_mist() -> void:
	# A83: Water Ring hours → 1 IC day tick.
	assert_eq(SpellSystem.get_weather_shift_duration_days("breath_of_mist"), 1)


# --- INFORMATION_GATHER reclassification: 21 misclassified spells → COMBAT_ONLY ---

func test_token_of_memory_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["token_of_memory"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_voice_of_the_wind_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["voice_of_the_wind"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_elemental_cipher_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["elemental_cipher"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_flight_of_doves_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["flight_of_doves"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_the_kamis_whisper_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_kamis_whisper"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_request_to_hato_no_kami_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["request_to_hato_no_kami"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_seeking_the_way_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["seeking_the_way"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_tenjins_ear_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["tenjins_ear"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_whispers_of_the_forgotten_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["whispers_of_the_forgotten"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_wisdom_of_the_kami_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["wisdom_of_the_kami"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_murmur_of_earth_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["murmur_of_earth"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_whispering_flames_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["whispering_flames"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_eyes_of_the_phoenix_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["eyes_of_the_phoenix"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_follow_the_flame_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["follow_the_flame"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_judgment_of_yomi_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["judgment_of_yomi"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_wisdom_and_clarity_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["wisdom_and_clarity"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_the_mirrors_smile_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_mirrors_smile"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_the_path_not_taken_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_path_not_taken"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_the_empty_voice_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_empty_voice"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_reach_through_the_void_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["reach_through_the_void"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_kharmic_intent_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["kharmic_intent"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)


# --- Sim-effect audit: misclassified REVEAL_DECEPTION, COMMAND_KAMI, PRESERVATION spells ---

func test_to_seek_the_truth_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["to_seek_the_truth"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_heart_betrays_eyes_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["heart_betrays_eyes"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_your_hearts_enemy_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["your_hearts_enemy"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_the_world_is_truth_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_world_is_truth"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_false_whispers_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["false_whispers"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_look_into_the_soul_is_information_gather() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["look_into_the_soul"]["s"], SpellSystem.SpellSimEffect.INFORMATION_GATHER)

func test_funeral_rites_is_information_gather() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["funeral_rites"]["s"], SpellSystem.SpellSimEffect.INFORMATION_GATHER)

func test_dominion_of_suitengu_is_information_gather() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["dominion_of_suitengu"]["s"], SpellSystem.SpellSimEffect.INFORMATION_GATHER)

func test_see_through_lies_is_information_gather() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["see_through_lies"]["s"], SpellSystem.SpellSimEffect.INFORMATION_GATHER)


# --- TRAVEL_AID audit: 7 combat-duration spells → COMBAT_ONLY, 1 → TRANSMUTE_MATERIAL ---

func test_the_mountains_feet_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_mountains_feet"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_hurried_steps_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["hurried_steps"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_wings_of_fire_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["wings_of_fire"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_wings_of_the_phoenix_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["wings_of_the_phoenix"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_cloak_of_the_miya_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["cloak_of_the_miya"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_wave_borne_speed_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["wave_borne_speed"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_master_of_the_rolling_river_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["master_of_the_rolling_river"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)

func test_flow_through_the_void_is_transmute_material() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["flow_through_the_void"]["s"], SpellSystem.SpellSimEffect.TRANSMUTE_MATERIAL)

func test_the_kamis_will_is_combat_only() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["the_kamis_will"]["s"], SpellSystem.SpellSimEffect.COMBAT_ONLY)


# -- INFORMATION_GATHER pipeline: get_best_spell_by_effect + NPC metadata ----

func test_get_best_information_spell_returns_highest_ml() -> void:
	# know_the_mind=ML4, echoes_in_the_void requires Ishiken; know_the_mind wins
	_char.spells_known = ["reflections_of_pan_ku", "know_the_mind", "the_ties_that_bind"]
	# reflections=ML1 (Water, INFORMATION_GATHER), know_the_mind=ML4 (Air)
	var best: String = SpellSystem.get_best_spell_by_effect(
		_char, SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)
	assert_eq(best, "know_the_mind")


func test_get_best_information_spell_empty_for_non_shugenja() -> void:
	# get_best_spell_by_effect doesn't gate on shugenja; NPC engine gate does.
	# But if spells_known is empty (non-shugenja) the result is empty.
	_char.spells_known = []
	var best: String = SpellSystem.get_best_spell_by_effect(
		_char, SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)
	assert_eq(best, "")


func test_get_best_information_spell_empty_when_none_known() -> void:
	_char.spells_known = ["jade_strike", "touch_of_the_void"]
	var best: String = SpellSystem.get_best_spell_by_effect(
		_char, SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)
	assert_eq(best, "")


func test_information_gather_spells_are_in_library() -> void:
	# Spot-check that the 7 Group-A person-intelligence spells have correct sim_effect.
	var expected: Array[String] = [
		"know_the_mind", "look_into_the_soul",
		"whispering_wind", "master_clouds_eyes",
		"reflections_of_pan_ku", "the_ties_that_bind",
	]
	for spell_id: String in expected:
		assert_true(SpellSystem.SPELL_LIBRARY.has(spell_id), "missing: " + spell_id)
		assert_eq(
			SpellSystem.SPELL_LIBRARY[spell_id]["s"],
			SpellSystem.SpellSimEffect.INFORMATION_GATHER,
			"wrong sim_effect for " + spell_id
		)


func test_look_into_the_soul_is_information_gather() -> void:
	assert_eq(
		SpellSystem.SPELL_LIBRARY["look_into_the_soul"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


func test_know_the_mind_is_information_gather() -> void:
	assert_eq(
		SpellSystem.SPELL_LIBRARY["know_the_mind"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


# -- Group B location-scrying: spell library classification ------------------

func test_boundless_sight_is_information_gather() -> void:
	assert_eq(
		SpellSystem.SPELL_LIBRARY["boundless_sight"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


func test_reflective_pool_is_information_gather() -> void:
	assert_eq(
		SpellSystem.SPELL_LIBRARY["reflective_pool"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


func test_dominion_of_suitengu_is_information_gather() -> void:
	assert_eq(
		SpellSystem.SPELL_LIBRARY["dominion_of_suitengu"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


func test_boundless_sight_is_void_element() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["boundless_sight"]["e"], 4)


func test_boundless_sight_is_ishiken_only() -> void:
	assert_true(SpellSystem.SPELL_LIBRARY["boundless_sight"].get("i", false))


func test_reflective_pool_is_water_element() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["reflective_pool"]["e"], 3)


func test_dominion_of_suitengu_is_water_element() -> void:
	assert_eq(SpellSystem.SPELL_LIBRARY["dominion_of_suitengu"]["e"], 3)


func test_secrets_on_the_wind_is_information_gather() -> void:
	# Classified INFORMATION_GATHER but skipped in writeback (preparation-ritual gate).
	assert_eq(
		SpellSystem.SPELL_LIBRARY["secrets_on_the_wind"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


func test_whispers_of_the_land_is_information_gather() -> void:
	# Classified INFORMATION_GATHER but skipped (local track revelation, not strategic intel).
	assert_eq(
		SpellSystem.SPELL_LIBRARY["whispers_of_the_land"]["s"],
		SpellSystem.SpellSimEffect.INFORMATION_GATHER
	)


# -- INFORMATION_GATHER group constants and NPC selector ----------------------

func test_group_a_contains_exactly_three_spells() -> void:
	assert_eq(SpellSystem.INFORMATION_GATHER_GROUP_A.size(), 3)


func test_group_b_contains_exactly_three_spells() -> void:
	assert_eq(SpellSystem.INFORMATION_GATHER_GROUP_B.size(), 3)


func test_group_a_contains_know_the_mind() -> void:
	assert_true("know_the_mind" in SpellSystem.INFORMATION_GATHER_GROUP_A)


func test_group_a_contains_look_into_the_soul() -> void:
	assert_true("look_into_the_soul" in SpellSystem.INFORMATION_GATHER_GROUP_A)


func test_group_a_contains_see_through_lies() -> void:
	assert_true("see_through_lies" in SpellSystem.INFORMATION_GATHER_GROUP_A)


func test_group_b_contains_boundless_sight() -> void:
	assert_true("boundless_sight" in SpellSystem.INFORMATION_GATHER_GROUP_B)


func test_group_b_contains_reflective_pool() -> void:
	assert_true("reflective_pool" in SpellSystem.INFORMATION_GATHER_GROUP_B)


func test_group_b_contains_dominion_of_suitengu() -> void:
	assert_true("dominion_of_suitengu" in SpellSystem.INFORMATION_GATHER_GROUP_B)


func test_get_best_npc_information_spell_returns_empty_when_no_spells() -> void:
	_char.spells_known = ["sense", "commune"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "")


func test_get_best_npc_information_spell_ignores_transient_spells() -> void:
	# echoes_on_the_breeze is Air ML5 INFORMATION_GATHER but not Group A/B
	_char.spells_known = ["echoes_on_the_breeze", "whispering_wind", "whispers_of_the_land"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "")


func test_get_best_npc_information_spell_ignores_unhandled_water_spells() -> void:
	# waters_sweet_clarity is Water ML6 INFORMATION_GATHER but not Group A/B
	_char.spells_known = ["waters_sweet_clarity", "the_final_bond", "visions_of_the_future"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "")


func test_get_best_npc_information_spell_returns_group_a_spell() -> void:
	_char.spells_known = ["sense", "know_the_mind"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "know_the_mind")


func test_get_best_npc_information_spell_returns_group_b_spell() -> void:
	_char.spells_known = ["sense", "reflective_pool"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "reflective_pool")


func test_get_best_npc_information_spell_prefers_higher_ml() -> void:
	# dominion_of_suitengu ML4 beats know_the_mind ML4 by iteration order;
	# more importantly, a higher-ML processable spell wins over lower-ML.
	_char.spells_known = ["sense", "reflective_pool", "dominion_of_suitengu"]
	# Both are Water Group B; dominion (ML4) > reflective_pool (ML2)
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "dominion_of_suitengu")


func test_get_best_npc_information_spell_high_ml_unhandled_does_not_win() -> void:
	# An Air ML5 shugenja knowing echoes_on_the_breeze + know_the_mind should pick
	# know_the_mind (ML4, Group A) not echoes_on_the_breeze (ML5, not processable).
	_char.spells_known = ["echoes_on_the_breeze", "know_the_mind"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "know_the_mind")


func test_get_best_npc_information_spell_funeral_rites_not_selected() -> void:
	# funeral_rites is Air ML4 INFORMATION_GATHER but targets dead characters;
	# not in Group A/B so NPC engine never selects it.
	_char.spells_known = ["funeral_rites", "know_the_mind"]
	assert_eq(SpellSystem.get_best_npc_information_spell(_char), "know_the_mind")
