class_name OrigamiSystem


## s57.26 Origami System constants and helpers (LOCKED: noshi, gohei, senbazuru).
## Shide deferred — zone-dependent (blocked on zone system data).


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
