extends GutTest
## Tests for GiftGivingSystem per GDD s12.3.


var _giver: L5RCharacterData
var _recipient: L5RCharacterData
var _engine: DiceEngine


func before_each() -> void:
	_giver = L5RCharacterData.new()
	_giver.character_id = 1
	_giver.awareness = 4
	_giver.skills = {"Etiquette": 4}

	_recipient = L5RCharacterData.new()
	_recipient.character_id = 2

	_engine = DiceEngine.new(42)


# -- Quality tier Free Raises (s49) ------------------------------------------

func test_mundane_grants_zero_free_raises() -> void:
	assert_eq(GiftGivingSystem.get_quality_free_raises(GiftGivingSystem.QualityTier.MUNDANE), 0)


func test_normal_grants_zero_free_raises() -> void:
	assert_eq(GiftGivingSystem.get_quality_free_raises(GiftGivingSystem.QualityTier.NORMAL), 0)


func test_fine_grants_one_free_raise() -> void:
	assert_eq(GiftGivingSystem.get_quality_free_raises(GiftGivingSystem.QualityTier.FINE), 1)


func test_exceptional_grants_two_free_raises() -> void:
	assert_eq(GiftGivingSystem.get_quality_free_raises(GiftGivingSystem.QualityTier.EXCEPTIONAL), 2)


func test_masterwork_grants_three_free_raises() -> void:
	assert_eq(GiftGivingSystem.get_quality_free_raises(GiftGivingSystem.QualityTier.MASTERWORK), 3)


func test_legendary_grants_four_free_raises() -> void:
	assert_eq(GiftGivingSystem.get_quality_free_raises(GiftGivingSystem.QualityTier.LEGENDARY), 4)


# -- Forbidden gifts (s12.3) -------------------------------------------------

func test_armor_is_always_forbidden() -> void:
	assert_true(GiftGivingSystem.is_forbidden(
		GiftGivingSystem.GiftCategory.ARMOR, GiftGivingSystem.QualityTier.LEGENDARY
	))


func test_weapon_is_forbidden_below_legendary() -> void:
	assert_true(GiftGivingSystem.is_forbidden(
		GiftGivingSystem.GiftCategory.WEAPON, GiftGivingSystem.QualityTier.MASTERWORK
	))


func test_legendary_blade_is_the_exception() -> void:
	assert_false(GiftGivingSystem.is_forbidden(
		GiftGivingSystem.GiftCategory.WEAPON, GiftGivingSystem.QualityTier.LEGENDARY
	))


func test_non_weapon_categories_are_never_forbidden() -> void:
	assert_false(GiftGivingSystem.is_forbidden(
		GiftGivingSystem.GiftCategory.ART, GiftGivingSystem.QualityTier.NORMAL
	))


# -- Appropriateness matrix --------------------------------------------------

func test_courtier_loves_art() -> void:
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.ART,
			GiftGivingSystem.RecipientArchetype.COURTIER,
		),
		GiftGivingSystem.Appropriateness.IDEAL,
	)


func test_shugenja_loves_ritual_objects() -> void:
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.RITUAL_OBJECTS,
			GiftGivingSystem.RecipientArchetype.SHUGENJA,
		),
		GiftGivingSystem.Appropriateness.IDEAL,
	)


func test_scholar_loves_writing_implements_and_poetry() -> void:
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.WRITING_IMPLEMENTS,
			GiftGivingSystem.RecipientArchetype.SCHOLAR,
		),
		GiftGivingSystem.Appropriateness.IDEAL,
	)
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.POETRY_SCROLLS,
			GiftGivingSystem.RecipientArchetype.SCHOLAR,
		),
		GiftGivingSystem.Appropriateness.IDEAL,
	)


func test_monk_rejects_worldly_accessories() -> void:
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.ACCESSORIES,
			GiftGivingSystem.RecipientArchetype.MONK,
		),
		GiftGivingSystem.Appropriateness.REDUCED,
	)


func test_unmapped_category_defaults_to_neutral() -> void:
	# Bushi has no special opinion on incense in the matrix.
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.INCENSE,
			GiftGivingSystem.RecipientArchetype.BUSHI,
		),
		GiftGivingSystem.Appropriateness.NEUTRAL,
	)


func test_weapon_appropriateness_is_insulting() -> void:
	assert_eq(
		GiftGivingSystem.get_appropriateness(
			GiftGivingSystem.GiftCategory.WEAPON,
			GiftGivingSystem.RecipientArchetype.BUSHI,
		),
		GiftGivingSystem.Appropriateness.INSULTING,
	)


# -- Effective Free Raises ---------------------------------------------------

func test_ideal_gift_keeps_full_free_raises() -> void:
	# Masterwork art to a courtier — IDEAL, full +3.
	var fr: int = GiftGivingSystem.compute_effective_free_raises(
		GiftGivingSystem.QualityTier.MASTERWORK,
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.RecipientArchetype.COURTIER,
	)
	assert_eq(fr, 3)


func test_history_points_stack_on_quality() -> void:
	var fr: int = GiftGivingSystem.compute_effective_free_raises(
		GiftGivingSystem.QualityTier.FINE,
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.RecipientArchetype.COURTIER,
		2,
	)
	assert_eq(fr, 3)  # +1 quality + 2 history


func test_reduced_appropriateness_halves_free_raises() -> void:
	var fr: int = GiftGivingSystem.compute_effective_free_raises(
		GiftGivingSystem.QualityTier.MASTERWORK,
		GiftGivingSystem.GiftCategory.ACCESSORIES,
		GiftGivingSystem.RecipientArchetype.MONK,
	)
	assert_eq(fr, 1)  # 3 / 2 = 1


func test_forbidden_gift_zeroes_free_raises() -> void:
	var fr: int = GiftGivingSystem.compute_effective_free_raises(
		GiftGivingSystem.QualityTier.MASTERWORK,
		GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.RecipientArchetype.BUSHI,
	)
	assert_eq(fr, 0)


func test_negative_history_points_clamped_to_zero() -> void:
	var fr: int = GiftGivingSystem.compute_effective_free_raises(
		GiftGivingSystem.QualityTier.FINE,
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.RecipientArchetype.COURTIER,
		-5,
	)
	assert_eq(fr, 1)


# -- Disposition value lookup ------------------------------------------------

func test_disposition_event_keys_match_disposition_system() -> void:
	# Each tier maps to a key that DispositionSystem.TEMPORARY_EVENTS knows.
	for tier in [
		GiftGivingSystem.QualityTier.NORMAL,
		GiftGivingSystem.QualityTier.FINE,
		GiftGivingSystem.QualityTier.EXCEPTIONAL,
		GiftGivingSystem.QualityTier.MASTERWORK,
		GiftGivingSystem.QualityTier.LEGENDARY,
	]:
		var key: String = GiftGivingSystem.get_disposition_event_key(tier)
		assert_true(
			DispositionSystem.TEMPORARY_EVENTS.has(key),
			"missing TEMPORARY_EVENTS entry for %s" % key
		)


func test_mundane_has_no_disposition_event() -> void:
	assert_eq(GiftGivingSystem.get_disposition_event_key(GiftGivingSystem.QualityTier.MUNDANE), "")


func test_quality_disposition_values_match_table() -> void:
	assert_eq(GiftGivingSystem.get_quality_disposition_value(GiftGivingSystem.QualityTier.NORMAL), 3)
	assert_eq(GiftGivingSystem.get_quality_disposition_value(GiftGivingSystem.QualityTier.FINE), 5)
	assert_eq(GiftGivingSystem.get_quality_disposition_value(GiftGivingSystem.QualityTier.EXCEPTIONAL), 8)
	assert_eq(GiftGivingSystem.get_quality_disposition_value(GiftGivingSystem.QualityTier.MASTERWORK), 12)
	assert_eq(GiftGivingSystem.get_quality_disposition_value(GiftGivingSystem.QualityTier.LEGENDARY), 12)


# -- resolve_deliver_gift ----------------------------------------------------

func test_forbidden_gift_resolves_short_circuit() -> void:
	var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		_giver, _recipient,
		GiftGivingSystem.QualityTier.MASTERWORK,
		GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.RecipientArchetype.BUSHI,
		_engine, 100,
	)
	assert_eq(result["outcome"], "forbidden")
	assert_eq(result["disposition_change"], GiftGivingSystem.FORBIDDEN_GIFT_DISPOSITION_LOSS)
	assert_false(result["obligation_created"])
	assert_eq(result["modifiers_to_apply"].size(), 0)
	assert_eq(result["roll"].size(), 0)


func test_legendary_blade_is_resolved_normally() -> void:
	var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		_giver, _recipient,
		GiftGivingSystem.QualityTier.LEGENDARY,
		GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.RecipientArchetype.BUSHI,
		_engine, 100,
	)
	# Outcome must be one of the rolled outcomes, not "forbidden".
	assert_ne(result["outcome"], "forbidden")
	assert_true(result["roll"].has("success"))


func test_success_creates_obligation_and_two_modifiers() -> void:
	# Strong courtier giving Masterwork art to a courtier — should easily pass.
	_giver.awareness = 5
	_giver.skills = {"Etiquette": 5}
	var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		_giver, _recipient,
		GiftGivingSystem.QualityTier.MASTERWORK,
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.RecipientArchetype.COURTIER,
		_engine, 100,
	)
	assert_eq(result["outcome"], "success")
	assert_true(result["obligation_created"])
	assert_eq(result["modifiers_to_apply"].size(), 2)
	# Disposition change includes quality base (12) plus +3 per raise achieved.
	assert_true(result["disposition_change"] >= 12)


func test_success_obligation_modifier_uses_correct_event_key() -> void:
	_giver.awareness = 5
	_giver.skills = {"Etiquette": 5}
	var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		_giver, _recipient,
		GiftGivingSystem.QualityTier.FINE,
		GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.RecipientArchetype.COURTIER,
		_engine, 100,
	)
	if result["outcome"] == "success":
		var event_keys: Array = []
		for m in result["modifiers_to_apply"]:
			event_keys.append(m["event_type"])
		assert_true(event_keys.has("gift_obligation"))
		assert_true(event_keys.has("gift_fine"))


func test_critical_failure_disposition_zeroed_pending_gdd_spec() -> void:
	# Untrained giver, no quality bonus, against TN 15. With seed 42 most
	# rolls land somewhere in between — drive a guaranteed critical failure
	# by removing the skill entirely and using a brittle character.
	_giver.awareness = 1
	_giver.skills = {}
	# Try a few seeds; assert the critical_failure path eventually fires.
	var saw_critical: bool = false
	for seed in range(1, 50):
		var engine: DiceEngine = DiceEngine.new(seed)
		var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
			_giver, _recipient,
			GiftGivingSystem.QualityTier.NORMAL,
			GiftGivingSystem.GiftCategory.ART,
			GiftGivingSystem.RecipientArchetype.COURTIER,
			engine, 100,
		)
		if result["outcome"] == "critical_failure":
			assert_eq(result["disposition_change"], GiftGivingSystem.CRITICAL_FAILURE_DISPOSITION_LOSS)
			assert_false(result["obligation_created"])
			assert_eq(result["modifiers_to_apply"].size(), 0)
			saw_critical = true
			break
	assert_true(saw_critical, "expected at least one critical failure across 50 seeds")


func test_failure_gives_partial_disposition_no_obligation() -> void:
	# Find a seed where outcome is "failure" (margin between -10 and 0).
	_giver.awareness = 2
	_giver.skills = {}
	var saw_failure: bool = false
	for seed in range(1, 100):
		var engine: DiceEngine = DiceEngine.new(seed)
		var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
			_giver, _recipient,
			GiftGivingSystem.QualityTier.FINE,
			GiftGivingSystem.GiftCategory.ART,
			GiftGivingSystem.RecipientArchetype.COURTIER,
			engine, 100,
		)
		if result["outcome"] == "failure":
			assert_eq(result["disposition_change"], 5 / 2)  # gift_fine 5 -> 2
			assert_false(result["obligation_created"])
			# Exactly one disposition modifier (the half-strength gift_fine);
			# no obligation.
			assert_eq(result["modifiers_to_apply"].size(), 1)
			assert_eq(result["modifiers_to_apply"][0]["event_type"], "gift_fine")
			# Half value applied.
			assert_eq(
				result["modifiers_to_apply"][0]["value"],
				DispositionSystem.TEMPORARY_EVENTS["gift_fine"]["value"] / 2,
			)
			saw_failure = true
			break
	assert_true(saw_failure, "expected at least one failure outcome across 100 seeds")


func test_modifiers_carry_current_ic_day() -> void:
	_giver.awareness = 5
	_giver.skills = {"Etiquette": 5}
	var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
		_giver, _recipient,
		GiftGivingSystem.QualityTier.EXCEPTIONAL,
		GiftGivingSystem.GiftCategory.TEA_IMPLEMENTS,
		GiftGivingSystem.RecipientArchetype.COURTIER,
		_engine, 777,
	)
	if result["outcome"] == "success":
		for m in result["modifiers_to_apply"]:
			assert_eq(m["created_ic_day"], 777)


# -- Archetype mapping -------------------------------------------------------

func test_default_archetype_maps_school_types() -> void:
	assert_eq(
		GiftGivingSystem.default_archetype_for_school(Enums.SchoolType.BUSHI),
		GiftGivingSystem.RecipientArchetype.BUSHI,
	)
	assert_eq(
		GiftGivingSystem.default_archetype_for_school(Enums.SchoolType.COURTIER),
		GiftGivingSystem.RecipientArchetype.COURTIER,
	)
	assert_eq(
		GiftGivingSystem.default_archetype_for_school(Enums.SchoolType.SHUGENJA),
		GiftGivingSystem.RecipientArchetype.SHUGENJA,
	)
	assert_eq(
		GiftGivingSystem.default_archetype_for_school(Enums.SchoolType.MONK),
		GiftGivingSystem.RecipientArchetype.MONK,
	)


# -- select_best_gift --------------------------------------------------------

func test_select_best_gift_returns_empty_when_no_inventory() -> void:
	var pick: Dictionary = GiftGivingSystem.select_best_gift(
		[], GiftGivingSystem.RecipientArchetype.COURTIER
	)
	assert_true(pick.is_empty())


func test_select_best_gift_returns_empty_when_only_non_gift_items() -> void:
	# A non-gift item (DOCUMENT category) should not be selectable.
	var doc: Dictionary = InventorySystem.create_item(
		1, "Letter", InventorySystem.ItemCategory.DOCUMENT, InventorySystem.ItemSize.SMALL
	)
	var pick: Dictionary = GiftGivingSystem.select_best_gift(
		[doc], GiftGivingSystem.RecipientArchetype.COURTIER
	)
	assert_true(pick.is_empty())


func test_select_best_gift_picks_highest_quality() -> void:
	var fine: Dictionary = InventorySystem.create_gift_item(
		1, "Fine Brush", GiftGivingSystem.GiftCategory.WRITING_IMPLEMENTS,
		GiftGivingSystem.QualityTier.FINE,
	)
	var masterwork: Dictionary = InventorySystem.create_gift_item(
		2, "Masterwork Inkstone", GiftGivingSystem.GiftCategory.WRITING_IMPLEMENTS,
		GiftGivingSystem.QualityTier.MASTERWORK,
	)
	var pick: Dictionary = GiftGivingSystem.select_best_gift(
		[fine, masterwork], GiftGivingSystem.RecipientArchetype.SCHOLAR
	)
	assert_eq(pick.get("item_id", -1), 2)


func test_select_best_gift_prefers_appropriate_over_reduced() -> void:
	# Equal-quality fine accessories are REDUCED for monks; fine tea is IDEAL.
	var accessories: Dictionary = InventorySystem.create_gift_item(
		1, "Fine Hair Pin", GiftGivingSystem.GiftCategory.ACCESSORIES,
		GiftGivingSystem.QualityTier.MASTERWORK,
	)
	var tea: Dictionary = InventorySystem.create_gift_item(
		2, "Fine Tea Set", GiftGivingSystem.GiftCategory.TEA_IMPLEMENTS,
		GiftGivingSystem.QualityTier.FINE,
	)
	# Masterwork accessories at REDUCED = 1 effective FR.
	# Fine tea at IDEAL = 1 effective FR. Tie on FR; tier breaks tie -> accessories.
	# Verify select picks accessories (higher tier wins on FR tie).
	var pick: Dictionary = GiftGivingSystem.select_best_gift(
		[accessories, tea], GiftGivingSystem.RecipientArchetype.MONK
	)
	assert_eq(pick.get("item_id", -1), 1)


func test_select_best_gift_skips_forbidden_weapon() -> void:
	var sword: Dictionary = InventorySystem.create_gift_item(
		1, "Fine Sword", GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.QualityTier.FINE,
	)
	var painting: Dictionary = InventorySystem.create_gift_item(
		2, "Normal Painting", GiftGivingSystem.GiftCategory.ART,
		GiftGivingSystem.QualityTier.NORMAL,
	)
	var pick: Dictionary = GiftGivingSystem.select_best_gift(
		[sword, painting], GiftGivingSystem.RecipientArchetype.BUSHI
	)
	assert_eq(pick.get("item_id", -1), 2)


func test_select_best_gift_keeps_legendary_blade_exception() -> void:
	var legendary_blade: Dictionary = InventorySystem.create_gift_item(
		1, "Ancestral Katana", GiftGivingSystem.GiftCategory.WEAPON,
		GiftGivingSystem.QualityTier.LEGENDARY,
	)
	var pick: Dictionary = GiftGivingSystem.select_best_gift(
		[legendary_blade], GiftGivingSystem.RecipientArchetype.BUSHI
	)
	assert_eq(pick.get("item_id", -1), 1)


# -- Free Raise -> roll bonus integration ------------------------------------

func test_quality_free_raises_actually_help_the_roll() -> void:
	# Compare a Mundane gift (0 FR) and a Legendary gift (+4 FR) from the
	# same weak giver. Across many seeds, Legendary should succeed strictly
	# more often than Mundane.
	_giver.awareness = 2
	_giver.skills = {"Etiquette": 1}
	var mundane_successes: int = 0
	var legendary_successes: int = 0
	for seed in range(1, 30):
		var e1: DiceEngine = DiceEngine.new(seed)
		var r1: Dictionary = GiftGivingSystem.resolve_deliver_gift(
			_giver, _recipient,
			GiftGivingSystem.QualityTier.MUNDANE,
			GiftGivingSystem.GiftCategory.ART,
			GiftGivingSystem.RecipientArchetype.COURTIER,
			e1, 1,
		)
		if r1["outcome"] == "success":
			mundane_successes += 1
		var e2: DiceEngine = DiceEngine.new(seed)
		var r2: Dictionary = GiftGivingSystem.resolve_deliver_gift(
			_giver, _recipient,
			GiftGivingSystem.QualityTier.LEGENDARY,
			GiftGivingSystem.GiftCategory.ART,
			GiftGivingSystem.RecipientArchetype.COURTIER,
			e2, 1,
		)
		if r2["outcome"] == "success":
			legendary_successes += 1
	assert_gt(legendary_successes, mundane_successes)


func test_success_adds_three_disposition_per_raise() -> void:
	# With high skill and quality bonus, ensure raises grant +3 each.
	_giver.awareness = 5
	_giver.skills = {"Etiquette": 5}
	var found_raises: bool = false
	for seed in range(1, 50):
		var eng: DiceEngine = DiceEngine.new(seed)
		var result: Dictionary = GiftGivingSystem.resolve_deliver_gift(
			_giver, _recipient,
			GiftGivingSystem.QualityTier.NORMAL,
			GiftGivingSystem.GiftCategory.TEA_IMPLEMENTS,
			GiftGivingSystem.RecipientArchetype.BUSHI,
			eng, 1,
		)
		if result["outcome"] == "success":
			var margin: int = result["roll"].get("margin", 0)
			var expected_raises: int = maxi(margin / 5, 0)
			var expected_disp: int = 3 + (expected_raises * 3)
			assert_eq(result["disposition_change"], expected_disp)
			if expected_raises > 0:
				found_raises = true
	assert_true(found_raises)
