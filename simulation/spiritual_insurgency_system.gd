class_name SpiritualInsurgencySystem
## Spiritual insurgency trigger layer per GDD s56.16.
## Detects worship failure thresholds, selects realm/element, determines
## severity. ASCII map encounter layer deferred to s56 quest system.
##
## REMOVED (2026-05-26): invented content not specified in GDD s56.16.
## - BASE_REALM_WEIGHTS and 7 condition bonus constants (FAMINE_GAKI_DO_BONUS,
##   etc.) — GDD s56.16.1a describes qualitative weighting factors but gives no
##   numeric weights. Realm selection is now equal-probability random.
## - NPC_RESOLUTION_BASE_TN dictionary — GDD s56.16.5b specifies ritual rounds
##   and skill rolls but no NPC-only resolution TN table.
## - BATTLE_CASUALTY_TRIGGER_THRESHOLD — GDD s56.16.4 says "significant
##   casualties" and "major battle" but gives no numeric threshold.
## - generate_battle_triggered_event() — invented thresholds (50/100/200 PU)
##   and 60/40 Gaki-do/Toshigoku split not in GDD.
## - resolve_npc_event() — invented TNs (15/20/25/30) and margin-based
##   resolution tiers not in GDD. Resolution spectrum (s56.16.5f) describes
##   player encounter outcomes, not NPC dice rolls.
## - get_resolution_effects() — invented honor/glory values (0.3/0.5, 0.1/0.2)
##   not in GDD.
## - _build_province_conditions() — only existed to feed removed weighted
##   realm selection.
## - _weighted_select() — only existed for removed weighted realm selection.
## - create_event_topic() severity-to-tier mapping — GDD does not specify
##   which topic tier corresponds to which severity level.
## - EVENTS_PER_SEASON for MODERATE/SEVERE/CATASTROPHIC — GDD says "one or
##   two" (MODERATE), "multiple" (SEVERE), "near-permanent" (CATASTROPHIC)
##   but gives no counts beyond MILD = 1.


# -- Trigger Thresholds (s56.16) -----------------------------------------------

const DISPLEASED_TRIGGER_COUNT: int = 2

const SEVERITY_THRESHOLDS: Dictionary = {
	2: Enums.SpiritualSeverity.MILD,
	3: Enums.SpiritualSeverity.MODERATE,
}

const WRATHFUL_SEVERITY_FLOOR: Enums.SpiritualSeverity = Enums.SpiritualSeverity.SEVERE
const CATASTROPHIC_WRATHFUL_COUNT: int = 5


# -- Elemental Counter Pairs (s56.16.5d) --------------------------------------

const ELEMENTAL_COUNTER: Dictionary = {
	Enums.Ring.FIRE: Enums.Ring.WATER,
	Enums.Ring.WATER: Enums.Ring.EARTH,
	Enums.Ring.EARTH: Enums.Ring.FIRE,
	Enums.Ring.AIR: Enums.Ring.EARTH,
	Enums.Ring.VOID: Enums.Ring.NONE,
}


# -- Restoration Ritual (s56.16.5b) -------------------------------------------

const RITUAL_ROUNDS: Dictionary = {
	Enums.SpiritualSeverity.MILD: 10,
	Enums.SpiritualSeverity.MODERATE: 20,
	Enums.SpiritualSeverity.SEVERE: 30,
	Enums.SpiritualSeverity.CATASTROPHIC: 50,
}

const REALM_RESTORATION_TRAIT: Dictionary = {
	Enums.SpiritRealm.GAKI_DO: "awareness",
	Enums.SpiritRealm.TOSHIGOKU: "willpower",
	Enums.SpiritRealm.CHIKUSHUDO: "perception",
	Enums.SpiritRealm.SAKKAKU: "intelligence",
	Enums.SpiritRealm.MEIDO: "awareness",
	Enums.SpiritRealm.YUME_DO: "willpower",
}


# -- Events per Season (s56.16.3) ---------------------------------------------
# GDD confirms: MILD = 1 ("One bleed event per season").
# MODERATE says "one or two" but does not specify probability — use 1.
# SEVERE ("multiple") and CATASTROPHIC ("near-permanent") have no explicit
# counts. Only GDD-confirmed values are included.

const EVENTS_PER_SEASON: Dictionary = {
	Enums.SpiritualSeverity.MILD: 1,
	Enums.SpiritualSeverity.MODERATE: 1,
}


# -- All Six Realms (for equal-probability selection) -------------------------

const ALL_REALMS: Array[int] = [
	Enums.SpiritRealm.GAKI_DO,
	Enums.SpiritRealm.TOSHIGOKU,
	Enums.SpiritRealm.CHIKUSHUDO,
	Enums.SpiritRealm.SAKKAKU,
	Enums.SpiritRealm.MEIDO,
	Enums.SpiritRealm.YUME_DO,
]


# =============================================================================
# Trigger Detection
# =============================================================================

static func count_displeased_or_worse(province_tiers: Dictionary) -> int:
	var count: int = 0
	for f: int in range(WorshipSystem.GREAT_FORTUNE_COUNT):
		var tier: int = province_tiers.get(f, Enums.WorshipTier.NONE)
		if tier >= Enums.WorshipTier.DISPLEASED:
			count += 1
	return count


static func count_wrathful(province_tiers: Dictionary) -> int:
	var count: int = 0
	for f: int in range(WorshipSystem.GREAT_FORTUNE_COUNT):
		var tier: int = province_tiers.get(f, Enums.WorshipTier.NONE)
		if tier >= Enums.WorshipTier.WRATHFUL:
			count += 1
	return count


static func should_trigger(province_tiers: Dictionary) -> bool:
	return count_displeased_or_worse(province_tiers) >= DISPLEASED_TRIGGER_COUNT


static func determine_severity(province_tiers: Dictionary) -> Enums.SpiritualSeverity:
	var displeased_count: int = count_displeased_or_worse(province_tiers)
	var wrathful_count: int = count_wrathful(province_tiers)

	if wrathful_count >= CATASTROPHIC_WRATHFUL_COUNT:
		return Enums.SpiritualSeverity.CATASTROPHIC
	if wrathful_count >= 1 or displeased_count >= 4:
		return Enums.SpiritualSeverity.SEVERE
	if displeased_count >= 3:
		return Enums.SpiritualSeverity.MODERATE
	return Enums.SpiritualSeverity.MILD


# =============================================================================
# Event Type Selection
# =============================================================================

static func select_event_type(dice: DiceEngine) -> Enums.SpiritualEventType:
	if dice.randf() < 0.5:
		return Enums.SpiritualEventType.REALM_OVERLAP
	return Enums.SpiritualEventType.ELEMENTAL_IMBALANCE


# =============================================================================
# Realm Selection — Equal Probability
# =============================================================================
# GDD s56.16.1a describes qualitative weighting factors (famine biases
# Gaki-do, battle biases Toshigoku, etc.) but provides no numeric weights.
# Until the GDD specifies weights, selection is equal-probability random
# across all 6 realms.

static func select_realm(dice: DiceEngine) -> Enums.SpiritRealm:
	return ALL_REALMS[dice.rand_int_range(0, ALL_REALMS.size() - 1)] as Enums.SpiritRealm


# =============================================================================
# Element Selection (s56.16.2a — equal probability)
# =============================================================================

static func select_element(dice: DiceEngine) -> Enums.Ring:
	var elements: Array[int] = [
		Enums.Ring.EARTH,
		Enums.Ring.FIRE,
		Enums.Ring.WATER,
		Enums.Ring.AIR,
		Enums.Ring.VOID,
	]
	return elements[dice.rand_int_range(0, elements.size() - 1)] as Enums.Ring


# =============================================================================
# Event Generation
# =============================================================================

static func generate_event(
	province_id: int,
	province_tiers: Dictionary,
	event_id: int,
	season: int,
	dice: DiceEngine,
) -> SpiritualInsurgencyData:
	var event := SpiritualInsurgencyData.new()
	event.event_id = event_id
	event.province_id = province_id
	event.severity = determine_severity(province_tiers)
	event.season_spawned = season
	event.event_type = select_event_type(dice)

	if event.event_type == Enums.SpiritualEventType.REALM_OVERLAP:
		event.realm = select_realm(dice)
		event.element = Enums.Ring.NONE
	else:
		event.element = select_element(dice)
		event.realm = Enums.SpiritRealm.GAKI_DO

	return event


# =============================================================================
# Seasonal Processing
# =============================================================================

static func process_seasonal_check(
	worship_state: Dictionary,
	existing_events: Array,
	next_event_id: Array,
	current_season: int,
	dice: DiceEngine,
) -> Array:
	var new_events: Array = []
	var province_tiers: Dictionary = worship_state.get("province_tiers", {})

	for pid: Variant in province_tiers:
		var tiers: Dictionary = province_tiers[pid]
		if not should_trigger(tiers):
			continue

		var severity: Enums.SpiritualSeverity = determine_severity(tiers)
		var max_events: int = EVENTS_PER_SEASON.get(severity, 1)

		var existing_count: int = _count_active_events_for_province(existing_events, pid)
		if existing_count >= max_events:
			continue

		var events_to_generate: int = max_events - existing_count

		for _i: int in range(events_to_generate):
			var eid: int = next_event_id[0]
			next_event_id[0] += 1
			var event: SpiritualInsurgencyData = generate_event(
				int(pid), tiers, eid, current_season, dice
			)
			new_events.append(event)

	return new_events


static func _count_active_events_for_province(
	events: Array,
	province_id: Variant,
) -> int:
	var count: int = 0
	for event: SpiritualInsurgencyData in events:
		if event is SpiritualInsurgencyData:
			if event.province_id == int(province_id) and not event.resolved:
				count += 1
	return count


static func increment_seasons(events: Array) -> void:
	for event: SpiritualInsurgencyData in events:
		if event is SpiritualInsurgencyData and not event.resolved:
			event.seasons_active += 1


# =============================================================================
# Topic Generation
# =============================================================================

static func create_event_topic(
	event: SpiritualInsurgencyData,
	next_topic_id: Array,
	ic_day: int,
) -> Dictionary:
	var title: String = ""
	if event.event_type == Enums.SpiritualEventType.REALM_OVERLAP:
		title = "Spirit realm disturbance in province %d" % event.province_id
	else:
		title = "Elemental imbalance in province %d" % event.province_id

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1

	return {
		"topic_id": topic_id,
		"title": title,
		"tier": -1,
		"category": TopicData.Category.SUPERNATURAL,
		"subject_character_id": -1,
		"ic_day_created": ic_day,
		"province_id": event.province_id,
		"event_id": event.event_id,
		"crisis_id": -1,
	}


# =============================================================================
# Helpers
# =============================================================================

static func _get_trait_value(character: L5RCharacterData, trait_name: String) -> int:
	match trait_name:
		"reflexes": return character.reflexes
		"awareness": return character.awareness
		"stamina": return character.stamina
		"willpower": return character.willpower
		"agility": return character.agility
		"intelligence": return character.intelligence
		"strength": return character.strength
		"perception": return character.perception
		"void": return character.void_ring
	return 2


static func _ring_to_trait_name(ring: Enums.Ring) -> String:
	match ring:
		Enums.Ring.AIR: return "awareness"
		Enums.Ring.EARTH: return "willpower"
		Enums.Ring.FIRE: return "intelligence"
		Enums.Ring.WATER: return "perception"
		Enums.Ring.VOID: return "void"
	return "awareness"


static func get_realm_name(realm: Enums.SpiritRealm) -> String:
	match realm:
		Enums.SpiritRealm.GAKI_DO: return "Gaki-do"
		Enums.SpiritRealm.TOSHIGOKU: return "Toshigoku"
		Enums.SpiritRealm.CHIKUSHUDO: return "Chikushudo"
		Enums.SpiritRealm.SAKKAKU: return "Sakkaku"
		Enums.SpiritRealm.MEIDO: return "Meido"
		Enums.SpiritRealm.YUME_DO: return "Yume-do"
	return "Unknown"


static func get_element_name(element: Enums.Ring) -> String:
	match element:
		Enums.Ring.EARTH: return "Earth"
		Enums.Ring.FIRE: return "Fire"
		Enums.Ring.WATER: return "Water"
		Enums.Ring.AIR: return "Air"
		Enums.Ring.VOID: return "Void"
	return "Unknown"
