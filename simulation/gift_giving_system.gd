class_name GiftGivingSystem
## Gift-giving per GDD s12.3, with mechanics drawn from s49 (quality tiers,
## Free Raises) and s15.4 (Deliver Gift court action). Disposition values
## and the gift_obligation modifier live in DispositionSystem (s12.2).
##
## Pure simulation class — no Node inheritance, no scene tree, no I/O.


# -- Quality tiers (s49) ------------------------------------------------------

enum QualityTier {
	MUNDANE,      # below TN 15 — failed craftsmanship, not gift-worthy
	NORMAL,       # 0 Free Raises
	FINE,         # +1
	EXCEPTIONAL,  # +2
	MASTERWORK,   # +3
	LEGENDARY,    # +4
}

const QUALITY_FREE_RAISES: Dictionary = {
	QualityTier.MUNDANE: 0,
	QualityTier.NORMAL: 0,
	QualityTier.FINE: 1,
	QualityTier.EXCEPTIONAL: 2,
	QualityTier.MASTERWORK: 3,
	QualityTier.LEGENDARY: 4,
}


# -- Gift categories (s12.3) --------------------------------------------------

enum GiftCategory {
	ART,                 # paintings, calligraphy, ceramics, lacquerware
	WRITING_IMPLEMENTS,  # fine paper, ink sticks, brushes
	TEA_IMPLEMENTS,      # universally appreciated
	POETRY_SCROLLS,      # books, lore, scholarly works
	INCENSE,             # incense, perfumes, pressed flowers
	ACCESSORIES,         # netsuke, hairpieces, fans, fine silk
	FOOD_DRINK,          # rare teas, aged sake, regional delicacies
	RITUAL_OBJECTS,      # prayer beads, small shrine pieces
	WEAPON,              # forbidden as gift unless Legendary blade (s12.3)
	ARMOR,               # forbidden as gift, no exception
}


# -- Recipient archetype ------------------------------------------------------
# Used to select an appropriateness row. Callers map clan/school/role to one
# of these archetypes — the GDD specifies taste varies "within" the appropriate
# range, not between forbidden and acceptable categories.

enum RecipientArchetype {
	BUSHI,     # warrior — values arms, but arms are forbidden as gifts
	COURTIER,  # values art, paper, refined accessories
	SHUGENJA,  # values ritual implements, scholarly works
	SCHOLAR,   # Dragon/Phoenix — values writing implements, lore
	MONK,      # devout — values ritual and tea, rejects worldly accessories
}


# -- Appropriateness ----------------------------------------------------------

enum Appropriateness {
	IDEAL,         # full Free Raises
	APPROPRIATE,   # full Free Raises
	NEUTRAL,       # full Free Raises (acceptable but unremarkable)
	REDUCED,       # half Free Raises (rounded down)
	INAPPROPRIATE, # 0 Free Raises (object is appreciated, gesture is not)
	INSULTING,     # 0 Free Raises and the gift offends — used for forbidden categories
}

# Matrix is sparse: any archetype/category pair not listed defaults to NEUTRAL.
# WEAPON and ARMOR are handled by is_forbidden() before consulting this matrix.
const APPROPRIATENESS_MATRIX: Dictionary = {
	RecipientArchetype.BUSHI: {
		GiftCategory.TEA_IMPLEMENTS: Appropriateness.APPROPRIATE,
		GiftCategory.ACCESSORIES: Appropriateness.APPROPRIATE,
		GiftCategory.FOOD_DRINK: Appropriateness.APPROPRIATE,
	},
	RecipientArchetype.COURTIER: {
		GiftCategory.ART: Appropriateness.IDEAL,
		GiftCategory.WRITING_IMPLEMENTS: Appropriateness.IDEAL,
		GiftCategory.TEA_IMPLEMENTS: Appropriateness.APPROPRIATE,
		GiftCategory.POETRY_SCROLLS: Appropriateness.APPROPRIATE,
		GiftCategory.INCENSE: Appropriateness.APPROPRIATE,
		GiftCategory.ACCESSORIES: Appropriateness.APPROPRIATE,
	},
	RecipientArchetype.SHUGENJA: {
		GiftCategory.RITUAL_OBJECTS: Appropriateness.IDEAL,
		GiftCategory.WRITING_IMPLEMENTS: Appropriateness.APPROPRIATE,
		GiftCategory.TEA_IMPLEMENTS: Appropriateness.APPROPRIATE,
		GiftCategory.POETRY_SCROLLS: Appropriateness.APPROPRIATE,
		GiftCategory.INCENSE: Appropriateness.APPROPRIATE,
	},
	RecipientArchetype.SCHOLAR: {
		GiftCategory.WRITING_IMPLEMENTS: Appropriateness.IDEAL,
		GiftCategory.POETRY_SCROLLS: Appropriateness.IDEAL,
		GiftCategory.ART: Appropriateness.APPROPRIATE,
		GiftCategory.TEA_IMPLEMENTS: Appropriateness.APPROPRIATE,
		GiftCategory.RITUAL_OBJECTS: Appropriateness.APPROPRIATE,
	},
	RecipientArchetype.MONK: {
		GiftCategory.TEA_IMPLEMENTS: Appropriateness.IDEAL,
		GiftCategory.RITUAL_OBJECTS: Appropriateness.IDEAL,
		GiftCategory.WRITING_IMPLEMENTS: Appropriateness.APPROPRIATE,
		GiftCategory.POETRY_SCROLLS: Appropriateness.APPROPRIATE,
		GiftCategory.INCENSE: Appropriateness.APPROPRIATE,
		# A monk has renounced worldly accessories.
		GiftCategory.ACCESSORIES: Appropriateness.REDUCED,
	},
}


# -- Outcome constants --------------------------------------------------------

const TN_DELIVER_GIFT: int = 15

# Critical failure threshold: total falls 10+ short of TN, OR the gift is
# forbidden (a non-Legendary weapon, or any armor).
const CRITICAL_FAILURE_MARGIN: int = -10

# Disposition bonus per Raise achieved on the Etiquette roll (s12.2).
const DISPOSITION_PER_RAISE: int = 3

# Disposition loss when the gift itself is the offense (forbidden item, or
# a presentation so botched the gesture undermines the object).
const FORBIDDEN_GIFT_DISPOSITION_LOSS: int = -5
const CRITICAL_FAILURE_DISPOSITION_LOSS: int = -5


# -- Free Raise computation ---------------------------------------------------

static func get_quality_free_raises(tier: QualityTier) -> int:
	return QUALITY_FREE_RAISES.get(tier, 0)


static func get_appropriateness(
	category: GiftCategory,
	archetype: RecipientArchetype,
) -> Appropriateness:
	if category == GiftCategory.WEAPON or category == GiftCategory.ARMOR:
		return Appropriateness.INSULTING
	var row: Dictionary = APPROPRIATENESS_MATRIX.get(archetype, {})
	return row.get(category, Appropriateness.NEUTRAL)


# Weapons are forbidden as gifts (s12.3) — implying "the recipient lacks one"
# is an insult. The sole exception is a Legendary blade of extraordinary
# provenance. Armor has no such exception.
static func is_forbidden(category: GiftCategory, tier: QualityTier) -> bool:
	if category == GiftCategory.ARMOR:
		return true
	if category == GiftCategory.WEAPON:
		return tier != QualityTier.LEGENDARY
	return false


static func compute_effective_free_raises(
	tier: QualityTier,
	category: GiftCategory,
	archetype: RecipientArchetype,
	history_point_bonus: int = 0,
) -> int:
	if is_forbidden(category, tier):
		return 0
	var base: int = get_quality_free_raises(tier) + maxi(history_point_bonus, 0)
	var appro: Appropriateness = get_appropriateness(category, archetype)
	match appro:
		Appropriateness.IDEAL, Appropriateness.APPROPRIATE, Appropriateness.NEUTRAL:
			return base
		Appropriateness.REDUCED:
			return int(base / 2)
		Appropriateness.INAPPROPRIATE, Appropriateness.INSULTING:
			return 0
	return base


# -- Disposition helpers ------------------------------------------------------

# Quality tier -> DispositionSystem.GIFT_DISPOSITION key.
# Mundane has no associated disposition value — gifting nothing remarkable
# produces no temp modifier.
static func get_disposition_event_key(tier: QualityTier) -> String:
	match tier:
		QualityTier.NORMAL:
			return "gift_normal"
		QualityTier.FINE:
			return "gift_fine"
		QualityTier.EXCEPTIONAL:
			return "gift_exceptional"
		QualityTier.MASTERWORK, QualityTier.LEGENDARY:
			# Legendary uses the Masterwork temp modifier (same +12 base).
			# The Legendary blade exception covers presentation weight, not
			# additional disposition tier.
			return "gift_masterwork"
	return ""


static func get_quality_disposition_value(tier: QualityTier) -> int:
	match tier:
		QualityTier.NORMAL:
			return DispositionSystem.GIFT_DISPOSITION.get("normal", 0)
		QualityTier.FINE:
			return DispositionSystem.GIFT_DISPOSITION.get("fine", 0)
		QualityTier.EXCEPTIONAL:
			return DispositionSystem.GIFT_DISPOSITION.get("exceptional", 0)
		QualityTier.MASTERWORK:
			return DispositionSystem.GIFT_DISPOSITION.get("masterwork", 0)
		QualityTier.LEGENDARY:
			return DispositionSystem.GIFT_DISPOSITION.get("legendary", 0)
	return 0


# -- Resolution ---------------------------------------------------------------
#
# Returns a dict shaped:
#   {
#       "giver_id": int,
#       "recipient_id": int,
#       "tier": QualityTier,
#       "category": GiftCategory,
#       "archetype": RecipientArchetype,
#       "free_raises_applied": int,
#       "outcome": "success" | "failure" | "critical_failure" | "forbidden",
#       "disposition_change": int,
#       "obligation_created": bool,
#       "modifiers_to_apply": Array[Dictionary],   # temp modifiers ready to
#                                                  # append to recipient
#       "roll": Dictionary,                        # SkillResolver output;
#                                                  # empty for forbidden gifts
#   }
#
# The caller is responsible for actually mutating recipient state with the
# disposition change and modifiers. This keeps the resolver pure.

static func resolve_deliver_gift(
	giver: L5RCharacterData,
	recipient: L5RCharacterData,
	tier: QualityTier,
	category: GiftCategory,
	recipient_archetype: RecipientArchetype,
	dice_engine: DiceEngine,
	current_ic_day: int,
	history_point_bonus: int = 0,
) -> Dictionary:
	var result: Dictionary = {
		"giver_id": giver.character_id,
		"recipient_id": recipient.character_id,
		"tier": tier,
		"category": category,
		"archetype": recipient_archetype,
		"free_raises_applied": 0,
		"outcome": "",
		"disposition_change": 0,
		"obligation_created": false,
		"modifiers_to_apply": [],
		"roll": {},
	}

	if is_forbidden(category, tier):
		result["outcome"] = "forbidden"
		result["disposition_change"] = FORBIDDEN_GIFT_DISPOSITION_LOSS
		return result

	var free_raises: int = compute_effective_free_raises(
		tier, category, recipient_archetype, history_point_bonus
	)
	result["free_raises_applied"] = free_raises

	# Free Raises from gift quality apply to the roll itself (s49) — modeled
	# here as a flat +5 each toward the roll total.
	var flat_bonus: int = free_raises * 5
	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		giver,
		dice_engine,
		"Etiquette",
		TN_DELIVER_GIFT,
		0,        # raises
		"",       # emphasis
		Enums.Trait.NONE,
		0,        # bonus_rolled
		0,        # bonus_kept
		flat_bonus,
	)
	result["roll"] = roll_result

	var quality_disp: int = get_quality_disposition_value(tier)
	var success: bool = roll_result.get("success", false)
	var margin: int = roll_result.get("margin", 0)

	if success:
		var raises_achieved: int = maxi(margin / 5, 0)
		result["outcome"] = "success"
		result["disposition_change"] = quality_disp + (raises_achieved * DISPOSITION_PER_RAISE)
		result["obligation_created"] = true
		var disp_mod: Dictionary = DispositionSystem.create_temporary_modifier(
			get_disposition_event_key(tier), current_ic_day
		)
		if not disp_mod.is_empty():
			result["modifiers_to_apply"].append(disp_mod)
		var obligation: Dictionary = DispositionSystem.create_temporary_modifier(
			"gift_obligation", current_ic_day
		)
		if not obligation.is_empty():
			result["modifiers_to_apply"].append(obligation)
	elif margin <= CRITICAL_FAILURE_MARGIN:
		# Presentation undermined the gift entirely.
		result["outcome"] = "critical_failure"
		result["disposition_change"] = CRITICAL_FAILURE_DISPOSITION_LOSS
	else:
		# Object appreciated, moment was not. Half disposition, no obligation.
		result["outcome"] = "failure"
		result["disposition_change"] = int(quality_disp / 2)
		var disp_mod: Dictionary = DispositionSystem.create_temporary_modifier(
			get_disposition_event_key(tier), current_ic_day
		)
		if not disp_mod.is_empty():
			disp_mod["value"] = int(int(disp_mod.get("value", 0)) / 2)
			result["modifiers_to_apply"].append(disp_mod)

	return result


# -- Gift selection from inventory -------------------------------------------
#
# Items are dicts shaped per InventorySystem.create_gift_item:
#   {
#       "item_id": int,
#       "name": String,
#       "category": InventorySystem.ItemCategory.GIFT,
#       "quality_tier": int (matches QualityTier enum value),
#       "gift_subtype": int (matches GiftCategory enum value),
#       "storage_tier": ...,
#       ...
#   }
#
# Forbidden categories (WEAPON, ARMOR) are skipped — they cannot be selected
# as gifts even if present in inventory.

static func select_best_gift(
	items: Array,
	archetype: RecipientArchetype,
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -1
	for item in items:
		if not _is_giftable(item):
			continue
		var tier: int = item.get("quality_tier", 0)
		var subtype: int = item.get("gift_subtype", -1)
		if subtype < 0:
			continue
		if is_forbidden(subtype, tier):
			continue
		var fr: int = compute_effective_free_raises(tier, subtype, archetype)
		# Score: weight effective FR strongly, break ties on raw quality.
		var score: int = (fr * 100) + tier
		if score > best_score:
			best_score = score
			best = item
	return best


static func _is_giftable(item: Dictionary) -> bool:
	if not item.has("category"):
		return false
	if item.get("category", -1) != InventorySystem.ItemCategory.GIFT:
		return false
	if item.get("in_transit", false):
		return false
	return true


# -- Convenience archetype mapping -------------------------------------------
# Maps a school type to a default archetype. Callers can override based on
# specific role (e.g. a Crab BUSHI who is also a magistrate may still prefer
# bushi gifts; the system stays opinionated rather than guess).

static func default_archetype_for_school(school_type: Enums.SchoolType) -> RecipientArchetype:
	match school_type:
		Enums.SchoolType.BUSHI:
			return RecipientArchetype.BUSHI
		Enums.SchoolType.COURTIER:
			return RecipientArchetype.COURTIER
		Enums.SchoolType.SHUGENJA:
			return RecipientArchetype.SHUGENJA
		Enums.SchoolType.MONK:
			return RecipientArchetype.MONK
		Enums.SchoolType.NINJA:
			return RecipientArchetype.BUSHI
		Enums.SchoolType.ARTISAN:
			return RecipientArchetype.SCHOLAR
	return RecipientArchetype.BUSHI
