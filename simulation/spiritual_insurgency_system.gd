class_name SpiritualInsurgencySystem
## Spiritual insurgency trigger and NPC resolution per GDD s56.16.
## Detects worship failure thresholds, selects realm/element, determines
## severity, and resolves via dice engine for NPC-only provinces.
## ASCII map encounter layer deferred to s56 quest system.


# -- Trigger Thresholds (s56.16) -----------------------------------------------

const DISPLEASED_TRIGGER_COUNT: int = 2

const SEVERITY_THRESHOLDS: Dictionary = {
	2: Enums.SpiritualSeverity.MILD,
	3: Enums.SpiritualSeverity.MODERATE,
}

const WRATHFUL_SEVERITY_FLOOR: Enums.SpiritualSeverity = Enums.SpiritualSeverity.SEVERE
const CATASTROPHIC_WRATHFUL_COUNT: int = 5


# -- Realm Weights (s56.16.1a) -------------------------------------------------

const BASE_REALM_WEIGHTS: Dictionary = {
	Enums.SpiritRealm.GAKI_DO: 10.0,
	Enums.SpiritRealm.TOSHIGOKU: 10.0,
	Enums.SpiritRealm.CHIKUSHUDO: 10.0,
	Enums.SpiritRealm.SAKKAKU: 10.0,
	Enums.SpiritRealm.MEIDO: 10.0,
	Enums.SpiritRealm.YUME_DO: 10.0,
}

const FAMINE_GAKI_DO_BONUS: float = 30.0
const BATTLE_TOSHIGOKU_BONUS: float = 25.0
const BATTLE_GAKI_DO_BONUS: float = 15.0
const FOREST_CHIKUSHUDO_BONUS: float = 20.0
const INTRIGUE_SAKKAKU_BONUS: float = 20.0
const POPULATION_LOSS_MEIDO_BONUS: float = 25.0
const SHUGENJA_YUME_DO_BONUS: float = 15.0


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

const NPC_RESOLUTION_BASE_TN: Dictionary = {
	Enums.SpiritualSeverity.MILD: 15,
	Enums.SpiritualSeverity.MODERATE: 20,
	Enums.SpiritualSeverity.SEVERE: 25,
	Enums.SpiritualSeverity.CATASTROPHIC: 30,
}


# -- Events per Season (s56.16.3) ---------------------------------------------

const EVENTS_PER_SEASON: Dictionary = {
	Enums.SpiritualSeverity.MILD: 1,
	Enums.SpiritualSeverity.MODERATE: 2,
	Enums.SpiritualSeverity.SEVERE: 3,
	Enums.SpiritualSeverity.CATASTROPHIC: 4,
}


# -- Mass Battle Trigger (s56.16.4) -------------------------------------------

const BATTLE_CASUALTY_TRIGGER_THRESHOLD: int = 50


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
# Realm Selection (s56.16.1a — weighted by province conditions)
# =============================================================================

static func select_realm(
	province_conditions: Dictionary,
	dice: DiceEngine,
) -> Enums.SpiritRealm:
	var weights: Dictionary = BASE_REALM_WEIGHTS.duplicate()

	if province_conditions.get("famine_active", false):
		weights[Enums.SpiritRealm.GAKI_DO] += FAMINE_GAKI_DO_BONUS
	if province_conditions.get("starvation_stage", 0) >= 2:
		weights[Enums.SpiritRealm.GAKI_DO] += FAMINE_GAKI_DO_BONUS * 0.5

	if province_conditions.get("recent_battle", false):
		weights[Enums.SpiritRealm.TOSHIGOKU] += BATTLE_TOSHIGOKU_BONUS
		weights[Enums.SpiritRealm.GAKI_DO] += BATTLE_GAKI_DO_BONUS

	if province_conditions.get("forest_province", false):
		weights[Enums.SpiritRealm.CHIKUSHUDO] += FOREST_CHIKUSHUDO_BONUS

	if province_conditions.get("court_intrigue_active", false):
		weights[Enums.SpiritRealm.SAKKAKU] += INTRIGUE_SAKKAKU_BONUS

	var secrets_count: int = province_conditions.get("secrets_count", 0)
	if secrets_count >= 3:
		weights[Enums.SpiritRealm.SAKKAKU] += INTRIGUE_SAKKAKU_BONUS * 0.5

	if province_conditions.get("recent_population_loss", false):
		weights[Enums.SpiritRealm.MEIDO] += POPULATION_LOSS_MEIDO_BONUS

	if province_conditions.get("shugenja_activity_surplus", false):
		weights[Enums.SpiritRealm.YUME_DO] += SHUGENJA_YUME_DO_BONUS

	return _weighted_select(weights, dice)


static func _weighted_select(
	weights: Dictionary,
	dice: DiceEngine,
) -> Enums.SpiritRealm:
	var total: float = 0.0
	for realm: int in weights:
		total += weights[realm]

	var roll: float = dice.randf() * total
	var cumulative: float = 0.0
	for realm: int in weights:
		cumulative += weights[realm]
		if roll <= cumulative:
			return realm as Enums.SpiritRealm

	return Enums.SpiritRealm.YUME_DO


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
	province_conditions: Dictionary,
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
		event.realm = select_realm(province_conditions, dice)
		event.element = Enums.Ring.NONE
	else:
		event.element = select_element(dice)
		event.realm = Enums.SpiritRealm.GAKI_DO

	return event


static func generate_battle_triggered_event(
	province_id: int,
	casualties: int,
	event_id: int,
	season: int,
	dice: DiceEngine,
) -> SpiritualInsurgencyData:
	if casualties < BATTLE_CASUALTY_TRIGGER_THRESHOLD:
		return null

	var event := SpiritualInsurgencyData.new()
	event.event_id = event_id
	event.province_id = province_id
	event.event_type = Enums.SpiritualEventType.REALM_OVERLAP
	event.element = Enums.Ring.NONE
	event.season_spawned = season

	if dice.randf() < 0.6:
		event.realm = Enums.SpiritRealm.GAKI_DO
	else:
		event.realm = Enums.SpiritRealm.TOSHIGOKU

	if casualties >= 200:
		event.severity = Enums.SpiritualSeverity.SEVERE
	elif casualties >= 100:
		event.severity = Enums.SpiritualSeverity.MODERATE
	else:
		event.severity = Enums.SpiritualSeverity.MILD

	return event


# =============================================================================
# NPC-Only Resolution (dice engine path — s56.16.5b)
# =============================================================================

static func resolve_npc_event(
	event: SpiritualInsurgencyData,
	shugenja: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var tn: int = NPC_RESOLUTION_BASE_TN.get(event.severity, 20)
	var theology_rank: int = shugenja.skills.get("Theology", 0)
	var trait_name: String = ""
	var trait_value: int = 0

	if event.event_type == Enums.SpiritualEventType.REALM_OVERLAP:
		trait_name = REALM_RESTORATION_TRAIT.get(event.realm, "awareness")
		trait_value = _get_trait_value(shugenja, trait_name)
	else:
		var counter: int = ELEMENTAL_COUNTER.get(event.element, Enums.Ring.NONE)
		if counter == Enums.Ring.NONE:
			trait_value = shugenja.void_ring
			trait_name = "void"
		else:
			trait_name = _ring_to_trait_name(counter)
			trait_value = _get_trait_value(shugenja, trait_name)

	var roll_result: DiceResult = dice_engine.roll_and_keep(
		theology_rank + trait_value, trait_value, theology_rank > 0
	)
	var total: int = roll_result.total
	var margin: int = total - tn

	var result: Dictionary = {
		"event_id": event.event_id,
		"province_id": event.province_id,
		"shugenja_id": shugenja.character_id,
		"tn": tn,
		"total": total,
		"success": margin >= 0,
		"margin": margin,
	}

	if margin >= 0:
		if margin >= 15:
			result["resolution_type"] = "full"
		else:
			result["resolution_type"] = "partial"
		event.resolved = true
		event.resolution_type = result["resolution_type"]
	else:
		if margin >= -10:
			result["resolution_type"] = "retreat"
		else:
			result["resolution_type"] = "failure"
		event.resolution_type = result["resolution_type"]

	event.npc_resolution_attempted = true
	return result


# =============================================================================
# Seasonal Processing
# =============================================================================

static func process_seasonal_check(
	worship_state: Dictionary,
	provinces: Dictionary,
	existing_events: Array,
	next_event_id: Array,
	current_season: int,
	dice: DiceEngine,
	season_meta: Dictionary = {},
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
		var conditions: Dictionary = _build_province_conditions(pid, provinces, season_meta)

		for _i: int in range(events_to_generate):
			var eid: int = next_event_id[0]
			next_event_id[0] += 1
			var event: SpiritualInsurgencyData = generate_event(
				int(pid), tiers, conditions, eid, current_season, dice
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


static func _build_province_conditions(
	province_id: Variant,
	provinces: Dictionary,
	season_meta: Dictionary = {},
) -> Dictionary:
	var conditions: Dictionary = {}
	var province: ProvinceData = provinces.get(province_id, null) as ProvinceData
	if province == null:
		province = provinces.get(int(province_id), null) as ProvinceData
	if province == null:
		return conditions

	var famine_tracking: Dictionary = season_meta.get("_famine_tracking", {})
	var pid_famine: Dictionary = famine_tracking.get(int(province_id), {})
	var famine_seasons: int = pid_famine.get("consecutive_seasons", 0)
	conditions["famine_active"] = famine_seasons >= 1
	conditions["starvation_stage"] = famine_seasons
	conditions["recent_battle"] = province.active_crisis_id >= 0
	conditions["forest_province"] = province.terrain_type == Enums.TerrainType.FOREST
	conditions["court_intrigue_active"] = false
	conditions["secrets_count"] = 0
	conditions["recent_population_loss"] = province.stability < 75.0
	conditions["shugenja_activity_surplus"] = false

	return conditions


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
	var tier: int = TopicData.Tier.TIER_4
	match event.severity:
		Enums.SpiritualSeverity.MILD:
			tier = TopicData.Tier.TIER_3
		Enums.SpiritualSeverity.MODERATE:
			tier = TopicData.Tier.TIER_2
		Enums.SpiritualSeverity.SEVERE:
			tier = TopicData.Tier.TIER_1
		Enums.SpiritualSeverity.CATASTROPHIC:
			tier = TopicData.Tier.TIER_1

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
		"tier": tier,
		"category": TopicData.Category.SUPERNATURAL,
		"subject_character_id": -1,
		"ic_day_created": ic_day,
		"province_id": event.province_id,
		"event_id": event.event_id,
		"crisis_id": -1,
	}


# =============================================================================
# Resolution Effects
# =============================================================================

static func get_resolution_effects(result: Dictionary) -> Dictionary:
	var effects: Dictionary = {}

	match result.get("resolution_type", ""):
		"full":
			effects["overlap_dissolves"] = true
			effects["honor_gain"] = 0.3
			effects["glory_gain"] = 0.5
		"partial":
			effects["overlap_weakened"] = true
			effects["honor_gain"] = 0.1
			effects["glory_gain"] = 0.2
		"retreat":
			effects["overlap_agitated"] = true
			effects["severity_increase_duration"] = 1
		"failure":
			effects["overlap_fully_agitated"] = true
			effects["severity_increase_duration"] = 1

	return effects


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
