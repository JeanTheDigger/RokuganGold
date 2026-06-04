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
