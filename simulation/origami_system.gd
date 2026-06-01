class_name OrigamiSystem


## s57.26 Origami System constants and helpers.
## Locked: noshi, gohei, senbazuru, shide (s57.26b settlement-level proxy).


# -- Craft TNs (s57.26.6, s57.26.12, s57.26.15) ----------------------------------

const NOSHI_TN: int = 15
const GOHEI_TN: int = 20
const SENBAZURU_SESSION_TN: int = 15


# -- Senbazuru session crane counts (s57.26.15) -----------------------------------

const CRANES_BASE: int = 10
const CRANES_PER_RAISE: int = 5


# -- Gohei uses_remaining by quality tier (A2, s57.26.12) -------------------------

const GOHEI_USES: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 3,
	GiftGivingSystem.QualityTier.FINE: 5,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 8,
	GiftGivingSystem.QualityTier.MASTERWORK: 12,
	GiftGivingSystem.QualityTier.LEGENDARY: 20,
}


# -- Noshi wrapper disposition bonus by tier (A1, s57.26.8) -----------------------

const NOSHI_WRAPPER_BONUS: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 2,
	GiftGivingSystem.QualityTier.FINE: 4,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 6,
	GiftGivingSystem.QualityTier.MASTERWORK: 8,
	GiftGivingSystem.QualityTier.LEGENDARY: 10,
}

const NOSHI_WRAPPER_DURATION: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 30,
	GiftGivingSystem.QualityTier.FINE: 45,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 60,
	GiftGivingSystem.QualityTier.MASTERWORK: 75,
	GiftGivingSystem.QualityTier.LEGENDARY: 90,
}


# -- Senbazuru presentation — Healing and Protection disposition (s57.26.17) -------

const SENBAZURU_HEAL_PROT_DISP: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 3,
	GiftGivingSystem.QualityTier.FINE: 5,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 8,
	GiftGivingSystem.QualityTier.MASTERWORK: 12,
	GiftGivingSystem.QualityTier.LEGENDARY: 15,
}

## Category 3 durations (s57.26.17).
const SENBAZURU_HEAL_PROT_DURATION: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 30,
	GiftGivingSystem.QualityTier.FINE: 45,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 60,
	GiftGivingSystem.QualityTier.MASTERWORK: 75,
	GiftGivingSystem.QualityTier.LEGENDARY: 90,
}

## Free Raises on next qualifying roll for Healing (s57.26.17 second effect).
const SENBAZURU_HEAL_FREE_RAISES: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 0,
	GiftGivingSystem.QualityTier.FINE: 1,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 2,
	GiftGivingSystem.QualityTier.MASTERWORK: 3,
	GiftGivingSystem.QualityTier.LEGENDARY: 4,
}


# -- Senbazuru presentation — Remembrance (s57.26.17) -----------------------------

const SENBAZURU_REMEMBRANCE_WITNESS_DISP: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 2,
	GiftGivingSystem.QualityTier.FINE: 4,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 6,
	GiftGivingSystem.QualityTier.MASTERWORK: 8,
	GiftGivingSystem.QualityTier.LEGENDARY: 10,
}

const SENBAZURU_REMEMBRANCE_GLORY: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 0.1,
	GiftGivingSystem.QualityTier.FINE: 0.2,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 0.3,
	GiftGivingSystem.QualityTier.MASTERWORK: 0.4,
	GiftGivingSystem.QualityTier.LEGENDARY: 0.5,
}


# -- Senbazuru presentation — Atonement (s57.26.17) -------------------------------

const SENBAZURU_ATONEMENT_HONOR: Dictionary = {
	GiftGivingSystem.QualityTier.NORMAL: 0.05,
	GiftGivingSystem.QualityTier.FINE: 0.1,
	GiftGivingSystem.QualityTier.EXCEPTIONAL: 0.15,
	GiftGivingSystem.QualityTier.MASTERWORK: 0.2,
	GiftGivingSystem.QualityTier.LEGENDARY: 0.3,
}


# -- Topic tiers (s57.26.14–57.26.17) -------------------------------------------

## Completion: TIER_3 for Exceptional+, TIER_4 for Fine/Normal.
const COMPLETION_TOPIC_TIER_HIGH: int = TopicData.Tier.TIER_3
const COMPLETION_TOPIC_TIER_LOW: int = TopicData.Tier.TIER_4

## Declaration, dedication shift, creator death: TIER_4.
const DECLARATION_TOPIC_TIER: int = TopicData.Tier.TIER_4
const DEDICATION_SHIFT_TOPIC_TIER: int = TopicData.Tier.TIER_4
const CREATOR_DECEASED_TOPIC_TIER: int = TopicData.Tier.TIER_4


# -- Quality helpers -------------------------------------------------------------

static func compute_quality_from_raises(
	raises_declared: int,
	success: bool,
) -> int:
	## Maps declared raises to GiftGivingSystem.QualityTier on success.
	## Returns MUNDANE (0) on failure.
	if not success:
		return GiftGivingSystem.QualityTier.MUNDANE
	match raises_declared:
		0:
			return GiftGivingSystem.QualityTier.NORMAL
		1:
			return GiftGivingSystem.QualityTier.FINE
		2:
			return GiftGivingSystem.QualityTier.EXCEPTIONAL
		3:
			return GiftGivingSystem.QualityTier.MASTERWORK
		_:
			return GiftGivingSystem.QualityTier.LEGENDARY


static func free_raises_from_tier(quality_tier: int) -> int:
	## Free Raises from quality tier: NORMAL(1)→0, FINE(2)→+1, EXCEPTIONAL(3)→+2, etc.
	## Used for noshi on DELIVER_GIFT and gohei on PERFORM_WORSHIP (s57.26.6, s57.26.13).
	return maxi(0, quality_tier - 1)


static func completion_topic_tier(quality_tier: int) -> int:
	## TIER_3 for Exceptional+, TIER_4 for Fine/Normal (s57.26 Completion).
	if quality_tier >= GiftGivingSystem.QualityTier.EXCEPTIONAL:
		return COMPLETION_TOPIC_TIER_HIGH
	return COMPLETION_TOPIC_TIER_LOW


# -- Shide constants (s57.26b settlement-level proxy) ----------------------------

const SHIDE_CRAFT_TN: int = 15                     # A1
const SHIDE_PERMISSION_GRACE_DAYS: int = 90        # A5 (1 IC season)
const SHIDE_AUTO_GRANT_MIN_RANK: int = 2           # A12
const SHIDE_WORSHIP_FR_CAP: int = 5                # shared cap with all artisan FRs

## int tier (0–4) → Free Raises on PERFORM_WORSHIP (A3).
const SHIDE_FREE_RAISES: Dictionary = {
	0: 0,  # Normal
	1: 1,  # Fine
	2: 2,  # Exceptional
	3: 3,  # Masterwork
	4: 4,  # Legendary
}

## Provenance investigation TN by placement quality tier (A9).
const SHIDE_PROVENANCE_TN: Dictionary = {
	4: 15,  # Legendary
	3: 20,  # Masterwork
	2: 25,  # Exceptional
	1: 30,  # Fine
	0: 35,  # Normal
}


static func shide_worship_fr(settlement: SettlementData) -> int:
	## Free Raises from shrine shide at this settlement (s57.26b A3).
	## Returns 0 when no shide is present.
	return maxi(0, SHIDE_FREE_RAISES.get(settlement.shrine_shide_current_tier, 0))


static func shide_quality_from_raises(raises: int) -> int:
	## Quality tier 0–4 from Raises (s57.26b A2).
	return mini(4, raises)


static func craft_shide(actor: L5RCharacterData, raises: int, next_item_id: Array) -> Dictionary:
	## Create a shide item in actor.items. Called from craft writeback (s57.26b).
	var quality_tier: int = shide_quality_from_raises(raises)
	var item_id: int = next_item_id[0]
	next_item_id[0] += 1
	var item: Dictionary = {
		"item_type": "shide",
		"item_id": item_id,
		"quality_tier": quality_tier,
		"crafter_id": actor.character_id,
		"uses_remaining": 1,
	}
	actor.items.append(item)
	return {"item_id": item_id, "quality_tier": quality_tier}


static func place_shide(
	actor: L5RCharacterData,
	settlement: SettlementData,
	shide_item: Dictionary,
	ic_day: int,
) -> Dictionary:
	## Place a shide item at settlement's shrine slot (s57.26b A20).
	## Removes shide from actor.items, writes to settlement fields.
	## Returns: {success, old_tier, new_tier, crafter_id, is_replacement_upgrade}
	var old_tier: int = settlement.shrine_shide_current_tier
	var new_tier: int = shide_item.get("quality_tier", 0)
	actor.items = actor.items.filter(
		func(it): return it.get("item_id", -1) != shide_item.get("item_id", -1)
	)
	settlement.shrine_shide_current_tier = new_tier
	settlement.shrine_shide_quality_tier = new_tier
	settlement.shrine_shide_crafter_id = actor.character_id
	settlement.shrine_shide_ic_day_placed = ic_day
	return {
		"success": true,
		"old_tier": old_tier,
		"new_tier": new_tier,
		"crafter_id": actor.character_id,
		"is_replacement_upgrade": old_tier >= 0 and new_tier > old_tier,
	}


static func try_auto_grant_permission(
	actor: L5RCharacterData,
	settlement: SettlementData,
	characters_by_id: Dictionary,
) -> bool:
	## Auto-grant shide permission when conditions from s57.26b A12 are met.
	## Returns true if permission was granted.
	if settlement.shrine_custodian_id < 0:
		return false
	var custodian: L5RCharacterData = characters_by_id.get(settlement.shrine_custodian_id)
	if custodian == null or CharacterStats.is_dead(custodian):
		return false
	var disp: int = custodian.disposition_values.get(actor.character_id, 0)
	var origami_rank: int = actor.skills.get("Artisan: Origami", 0)
	if disp >= 0 and origami_rank >= SHIDE_AUTO_GRANT_MIN_RANK:
		settlement.shrine_shide_permission = actor.character_id
		return true
	return false
