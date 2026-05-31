class_name SculptureSystem
## Sculpture system per GDD s57.28. Locked in s57.28_sculpture_system_locked.md.
## One ActionID: COMPOSE_SCULPTURE.
## No Node dependency — plain simulation class.


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum Format { STATUARY = 0, GUARDIAN = 1, FIGURINE = 2 }

enum Material { WOOD = 0, STONE = 1, BRONZE = 2 }

enum SubjectType {
	FORTUNE       = 0,  # butsuzo/devotional
	GUARDIAN_SPIRIT = 1, # komainu-type
	KAMI          = 2,  # kami figure
	PORTRAIT      = 3,  # specific character
	ANIMAL        = 4,  # sea creatures, birds, horses
	SCENIC        = 5,  # wave, mountain, ship in miniature
}

enum FigurineTheme {
	SEA_FORTUNE = 0,
	SEA_ANIMAL  = 1,
	PERSON      = 2,
	SAILING     = 3,
	OTHER       = 4,
}

enum DisplaySlot { STATUE_SLOT = 0, GUARDIAN_SLOT = 1 }

# ---------------------------------------------------------------------------
# Composition progress thresholds (s57.28.4 / s57.28_sculpture_system_locked.md B)
# ---------------------------------------------------------------------------

const PROGRESS_THRESHOLDS: Dictionary = {
	Format.STATUARY:  {1: 20,  2: 40,  3: 65,  4: 95,  5: 130},
	Format.GUARDIAN:  {1: 25,  2: 50,  3: 80,  4: 110, 5: 150},
	Format.FIGURINE:  {1: 5,   2: 10,  3: 18,  4: 28,  5: 40},
}

## Base TN for all COMPOSE_SCULPTURE rolls (s57.28.4 A1).
const COMPOSE_TN: int = 15

## Stone material TN penalty (s57.28.4 A4).
const STONE_TN_PENALTY: int = 5

## Skill gate: Artisan: Sculpture rank must equal or exceed quality tier (A7).
const QUALITY_SKILL_GATE: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}

## IC days without composition AP before degradation fires for statuary/guardian (A6).
const COMPOSITION_DEGRADATION_DAYS: int = 90

# ---------------------------------------------------------------------------
# Worship Free Raises (s57.28.6, s57.28.7 — locked section C)
# ---------------------------------------------------------------------------

## Statuary worship FRs (must target same Fortune as statue's subject_id).
const STATUARY_WORSHIP_FR: Dictionary = {1: 0, 2: 1, 3: 1, 4: 2, 5: 2}

## Guardian worship FRs (fires for any worship within same shrine complex).
const GUARDIAN_WORSHIP_FR: Dictionary = {1: 0, 2: 0, 3: 1, 4: 1, 5: 2}

## Maximum combined worship FRs from all external artisan sources (PROVISIONAL — locked C).
const WORSHIP_FR_CAP: int = 5

# ---------------------------------------------------------------------------
# Passive Worship Points (PROVISIONAL — locked section D)
# ---------------------------------------------------------------------------

const PASSIVE_WP_BY_TIER: Dictionary = {1: 0.1, 2: 0.25, 3: 0.5, 4: 0.75, 5: 1.0}

# ---------------------------------------------------------------------------
# Guardian spiritual ward (locked section E)
# ---------------------------------------------------------------------------

## Non-Jigoku overlap progress subtracted per tick when pair_intact=true.
const GUARDIAN_WARD_BY_TIER: Dictionary = {1: -1, 2: -2, 3: -3, 4: -4, 5: -5}

# ---------------------------------------------------------------------------
# Visitor effects (locked section F)
# ---------------------------------------------------------------------------

const VISITOR_DISPOSITION_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}
const VISITOR_BONUS_DURATION_DAYS: int = 120
const GLORY_TICK_THRESHOLD: int = 5
const CREATOR_GLORY_PER_TICK: float = 0.1
const DAIMYO_GLORY_PER_TICK: float = 0.01

const VISITOR_MEMORY_CAP: int = 200
const VISITOR_MEMORY_PURGE_DAYS: int = 1800  # 5 IC years

# ---------------------------------------------------------------------------
# Wood guardian outdoor degradation (locked section G)
# ---------------------------------------------------------------------------

## IC days per 1-tier quality loss (5 IC years = 5 × 360 = 1800 days).
const WOOD_OUTDOOR_DEGRADATION_DAYS: int = 1800

# ---------------------------------------------------------------------------
# Mantis figurine bonus (locked section H)
# ---------------------------------------------------------------------------

## DELIVER_GIFT Free Raise bonus when recipient is Mantis Clan.
const MANTIS_FIGURINE_FR_BONUS: int = 3

## Figurines needed to trigger a collection topic.
const MANTIS_COLLECTION_THRESHOLD: int = 3

# ---------------------------------------------------------------------------
# Lifecycle topic tiers (locked section I)
# ---------------------------------------------------------------------------

## quality_tier → TopicData.Tier enum. Shared for statuary and guardian.
const COMPLETION_TOPIC_TIER: Dictionary = {1: 3, 2: 3, 3: 2, 4: 2, 5: 1}

## Guardian damage: Exceptional+ = TIER_3, Fine and below = TIER_4.
const GUARDIAN_DAMAGE_TIER_THRESHOLD: int = 3

# ---------------------------------------------------------------------------
# Settlement eligibility (locked section J — settlement-level zone proxy)
# ---------------------------------------------------------------------------

const STATUE_ELIGIBLE_TYPES: Array = ["TEMPLE", "SHINDEN", "MONASTERY"]
const GUARDIAN_ELIGIBLE_TYPES: Array = ["TEMPLE", "SHINDEN", "MONASTERY"]

# ---------------------------------------------------------------------------
# Siege/sacking survival (locked section K)
# ---------------------------------------------------------------------------

const SACKING_SURVIVAL_WOOD: Dictionary   = {1: 0.30, 2: 0.40, 3: 0.50, 4: 0.60, 5: 0.70}
const SACKING_SURVIVAL_STONE_BONUS: float = 0.20
const SACKING_SURVIVAL_BRONZE_BONUS: float = 0.30
const DESTRUCTION_SURVIVAL_STONE: float = 0.50
const DESTRUCTION_SURVIVAL_BRONZE: float = 0.70

# ---------------------------------------------------------------------------
# Provenance investigation (locked section O)
# ---------------------------------------------------------------------------

## Creator identification TNs are reduced by this amount compared to paintings.
const IDENTIFICATION_TN_REDUCTION: int = 5

## Minimum Artisan: Sculpture rank to receive a Free Raise on identification rolls.
const IDENTIFICATION_FR_RANK: int = 2

## Free Raise bonus granted at or above IDENTIFICATION_FR_RANK (locked section O).
const IDENTIFICATION_FR_BONUS: int = 1

# ---------------------------------------------------------------------------
# Core composition functions
# ---------------------------------------------------------------------------

## Create a new in-progress SculptureData with declared parameters.
## Returns the SculptureData object (craft_progress = 0, date_completed = -1).
static func declare_composition(
		format: int,
		material: int,
		subject_type: int,
		subject_id: int,
		target_quality_tier: int,
		creator_id: int,
		sculpture_id: int,
		ic_day: int,
		theme: int = FigurineTheme.OTHER,
		subject_description: String = "",
) -> SculptureData:
	var s: SculptureData = SculptureData.new()
	s.sculpture_id = sculpture_id
	s.format = format
	s.creator_id = creator_id
	s.quality_tier = 1
	s.target_quality_tier = target_quality_tier
	s.target_format = format
	s.material = material
	s.subject_type = subject_type
	s.subject_id = subject_id
	s.subject_description = subject_description
	s.theme = theme
	s.paired = format == Format.GUARDIAN
	s.pair_intact = false  # Not complete yet
	s.craft_progress = 0
	s.ic_day_last_composition_ap = ic_day
	return s


## Advance composition progress. Returns result dict.
## die_result: raw roll result (before TN comparison).
## raises_declared: number of raises the sculptor attempted.
static func resolve_compose_sculpture(
		sculptor_skill_rank: int,
		sculpture: SculptureData,
		die_result: int,
		raises_declared: int,
		ic_day: int,
) -> Dictionary:
	if not sculpture or sculpture.craft_progress < 0:
		return {"blocked": true, "blocked_reason": "sculpture_already_complete"}

	# Skill gate: rank must equal or exceed target quality tier.
	if sculptor_skill_rank < QUALITY_SKILL_GATE.get(sculpture.target_quality_tier, 1):
		return {"blocked": true, "blocked_reason": "insufficient_skill_rank"}

	# Effective TN: base + raises_cost + material modifier.
	var effective_tn: int = COMPOSE_TN
	if sculpture.material == Material.STONE:
		effective_tn += STONE_TN_PENALTY
	var tn_with_raises: int = effective_tn + raises_declared * 5

	var success: bool = die_result >= tn_with_raises
	var progress_gained: int = 0
	if success:
		var base_progress: int = maxi(1, die_result - tn_with_raises + raises_declared * 5)
		# Note: progress = max(1, roll_total - base_TN); raises cost TN but add progress.
		# Re-derive: effective_total vs base_TN = effective progress base.
		base_progress = maxi(1, die_result - effective_tn)
		var raise_bonus: int = raises_declared * 5
		progress_gained = base_progress + raise_bonus
		sculpture.craft_progress += progress_gained
	sculpture.ic_day_last_composition_ap = ic_day

	var threshold: int = _composition_threshold(sculpture)
	var completed: bool = sculpture.craft_progress >= threshold
	var completion_raises: int = 0
	if completed:
		completion_raises = raises_declared if success else 0
		var final_quality: int = mini(5, sculpture.target_quality_tier + completion_raises)
		sculpture.quality_tier = final_quality
		sculpture.craft_progress = -1
		sculpture.date_completed = ic_day
		# Guardian pair becomes intact on completion.
		if sculpture.format == Format.GUARDIAN:
			sculpture.pair_intact = true

	return {
		"success": success,
		"progress_gained": progress_gained,
		"progress_total": sculpture.craft_progress,
		"threshold": threshold,
		"completed": completed,
		"quality_tier": sculpture.quality_tier,
		"completion_raises": completion_raises,
	}


## Apply composition degradation (statuary and guardian only — not figurines).
static func apply_composition_degradation(sculpture: SculptureData, ic_day: int) -> int:
	if sculpture.format == Format.FIGURINE:
		return sculpture.craft_progress  # No degradation for figurines.
	if sculpture.craft_progress < 0:
		return -1  # Already complete.
	var last_ap: int = sculpture.ic_day_last_composition_ap if \
			sculpture.ic_day_last_composition_ap >= 0 else 0
	if ic_day - last_ap >= COMPOSITION_DEGRADATION_DAYS:
		sculpture.craft_progress = sculpture.craft_progress / 2
	return sculpture.craft_progress


# ---------------------------------------------------------------------------
# Slot / permission helpers
# ---------------------------------------------------------------------------

## True when the settlement type supports a statue_slot.
static func is_statue_eligible(settlement: SettlementData) -> bool:
	if settlement == null:
		return false
	return Enums.SettlementType.keys()[settlement.settlement_type] in STATUE_ELIGIBLE_TYPES


## True when the settlement type supports a guardian_slot.
static func is_guardian_eligible(settlement: SettlementData) -> bool:
	if settlement == null:
		return false
	return Enums.SettlementType.keys()[settlement.settlement_type] in GUARDIAN_ELIGIBLE_TYPES


## Place a completed sculpture into the appropriate slot on the settlement.
## Returns {success, displaced_sculpture_id, slot}.
static func place_sculpture(
		sculpture: SculptureData,
		settlement: SettlementData,
		ic_day: int,
) -> Dictionary:
	if sculpture == null or sculpture.craft_progress >= 0:
		return {"success": false, "blocked_reason": "sculpture_not_complete"}
	if settlement == null:
		return {"success": false, "blocked_reason": "no_settlement"}

	if sculpture.format == Format.STATUARY:
		if not is_statue_eligible(settlement):
			return {"success": false, "blocked_reason": "ineligible_settlement_type"}
		var displaced: int = settlement.statue_slot
		settlement.statue_slot = sculpture.sculpture_id
		sculpture.display_settlement_id = settlement.settlement_id
		sculpture.display_slot = DisplaySlot.STATUE_SLOT
		return {"success": true, "displaced_sculpture_id": displaced, "slot": DisplaySlot.STATUE_SLOT}

	elif sculpture.format == Format.GUARDIAN:
		if not is_guardian_eligible(settlement):
			return {"success": false, "blocked_reason": "ineligible_settlement_type"}
		var displaced_g: int = settlement.guardian_slot
		settlement.guardian_slot = sculpture.sculpture_id
		sculpture.display_settlement_id = settlement.settlement_id
		sculpture.display_slot = DisplaySlot.GUARDIAN_SLOT
		# Wood guardians are outdoors.
		if sculpture.material == Material.WOOD:
			sculpture.ic_day_placed_outdoor = ic_day
		return {"success": true, "displaced_sculpture_id": displaced_g, "slot": DisplaySlot.GUARDIAN_SLOT}

	return {"success": false, "blocked_reason": "figurines_not_placed"}


## Grant statue placement permission for a sculptor at a settlement.
static func grant_statue_permission(settlement: SettlementData, sculptor_id: int) -> void:
	if settlement == null:
		return
	settlement.statue_permissions[sculptor_id] = true


## Grant guardian placement permission for a sculptor at a settlement.
static func grant_guardian_permission(settlement: SettlementData, sculptor_id: int) -> void:
	if settlement == null:
		return
	settlement.guardian_permissions[sculptor_id] = true


## True when actor is the shrine custodian (lord) OR has explicit permission for statuary.
static func has_statue_permission(actor_id: int, settlement: SettlementData) -> bool:
	if settlement == null:
		return false
	if settlement.lord_character_id == actor_id:
		return true
	return settlement.statue_permissions.get(actor_id, false)


## True when actor is the shrine custodian (lord) OR has explicit permission for guardian pairs.
static func has_guardian_permission(actor_id: int, settlement: SettlementData) -> bool:
	if settlement == null:
		return false
	if settlement.lord_character_id == actor_id:
		return true
	return settlement.guardian_permissions.get(actor_id, false)


# ---------------------------------------------------------------------------
# Worship FR helpers
# ---------------------------------------------------------------------------

## Statuary FR bonus for PERFORM_WORSHIP (fortune-match required by caller).
static func statuary_worship_fr(quality_tier: int) -> int:
	return STATUARY_WORSHIP_FR.get(quality_tier, 0)


## Guardian FR bonus for PERFORM_WORSHIP (complex-wide).
static func guardian_worship_fr(quality_tier: int) -> int:
	return GUARDIAN_WORSHIP_FR.get(quality_tier, 0)


## Passive WP generated by a placed statuary per season.
static func passive_wp_per_season(quality_tier: int) -> float:
	return PASSIVE_WP_BY_TIER.get(quality_tier, 0.0)


## Guardian ward modifier on non-Jigoku realm overlap tick.
static func guardian_ward_value(quality_tier: int, pair_intact: bool) -> int:
	if not pair_intact:
		return 0
	return GUARDIAN_WARD_BY_TIER.get(quality_tier, 0)


# ---------------------------------------------------------------------------
# Visitor effects
# ---------------------------------------------------------------------------

## Returns disposition change for a visitor and whether a Glory tick fires.
## Caller checks pair_intact for guardian slot entries.
static func apply_visitor_effect(
		visitor_id: int,
		sculpture: SculptureData,
		current_ic_season: int,
		ic_day: int,
) -> Dictionary:
	if sculpture == null or sculpture.craft_progress >= 0:
		return {}
	if sculpture.creator_id < 0:
		return {}  # Ancient / unknown creator

	# Check visitor memory — 120-day immunity window.
	for entry_v: Variant in sculpture.visitor_memory:
		var entry: Dictionary = entry_v as Dictionary
		if entry.get("char_id", -1) == visitor_id:
			if ic_day - entry.get("last_visit_ic_day", 0) < VISITOR_BONUS_DURATION_DAYS:
				return {"immune": true}
			# Expired entry — will be updated below.
			break

	# Update visitor memory.
	var found_entry: bool = false
	for i: int in range(sculpture.visitor_memory.size()):
		var entry: Dictionary = sculpture.visitor_memory[i]
		if entry.get("char_id", -1) == visitor_id:
			sculpture.visitor_memory[i] = {"char_id": visitor_id, "last_visit_ic_day": ic_day}
			found_entry = true
			break
	if not found_entry:
		sculpture.visitor_memory.append({"char_id": visitor_id, "last_visit_ic_day": ic_day})

	# Cap visitor memory.
	if sculpture.visitor_memory.size() > VISITOR_MEMORY_CAP:
		sculpture.visitor_memory = sculpture.visitor_memory.slice(
				sculpture.visitor_memory.size() - VISITOR_MEMORY_CAP)

	# Check for glory tick.
	sculpture.visitor_count_since_last_tick += 1
	var glory_tick: bool = false
	if sculpture.visitor_count_since_last_tick >= GLORY_TICK_THRESHOLD and \
			sculpture.last_glory_tick_ic_season != current_ic_season:
		glory_tick = true
		sculpture.visitor_count_since_last_tick = 0
		sculpture.last_glory_tick_ic_season = current_ic_season

	var disp: int = VISITOR_DISPOSITION_BY_TIER.get(sculpture.quality_tier, 1)
	return {
		"disposition_change": disp,
		"glory_tick": glory_tick,
		"creator_glory_gain": CREATOR_GLORY_PER_TICK if glory_tick else 0.0,
		"daimyo_glory_gain": DAIMYO_GLORY_PER_TICK if glory_tick else 0.0,
	}


# ---------------------------------------------------------------------------
# Wood guardian outdoor degradation
# ---------------------------------------------------------------------------

## Apply outdoor degradation to a wood guardian. Returns new quality tier.
## Call once per season if ic_day - ic_day_placed_outdoor >= WOOD_OUTDOOR_DEGRADATION_DAYS.
static func apply_outdoor_degradation(sculpture: SculptureData, ic_day: int) -> int:
	if sculpture.format != Format.GUARDIAN:
		return sculpture.quality_tier
	if sculpture.material != Material.WOOD:
		return sculpture.quality_tier
	if sculpture.ic_day_placed_outdoor < 0:
		return sculpture.quality_tier
	if sculpture.craft_progress >= 0:
		return sculpture.quality_tier  # WIP — not yet placed outdoors

	var elapsed: int = ic_day - sculpture.ic_day_placed_outdoor
	var tiers_lost: int = elapsed / WOOD_OUTDOOR_DEGRADATION_DAYS
	if tiers_lost > 0:
		var new_tier: int = maxi(1, sculpture.quality_tier - tiers_lost)
		if new_tier != sculpture.quality_tier:
			sculpture.quality_tier = new_tier
			# Re-anchor degradation clock.
			sculpture.ic_day_placed_outdoor = ic_day - (elapsed % WOOD_OUTDOOR_DEGRADATION_DAYS)
	return sculpture.quality_tier


# ---------------------------------------------------------------------------
# Lifecycle topic generation
# ---------------------------------------------------------------------------

## Generate a topic dict for a lifecycle event. Returns {} if no topic warranted.
## event: "completion", "guardian_damage", "destruction"
static func generate_lifecycle_topic(
		sculpture: SculptureData,
		event: String,
		settlement_name: String,
		ic_day: int,
) -> Dictionary:
	var tier: int = 3  # TIER_4 default

	if event == "completion":
		tier = COMPLETION_TOPIC_TIER.get(sculpture.quality_tier, 3)
		var format_str: String = "statue"
		if sculpture.format == Format.GUARDIAN:
			format_str = "guardian pair"
		elif sculpture.format == Format.FIGURINE:
			tier = 3  # Always TIER_4 for figurines
			format_str = "figurine"
		var subject_str: String = sculpture.subject_description if \
				not sculpture.subject_description.is_empty() else "a sacred subject"
		var title: String = "[Creator] has completed a %s %s %s" % [
			_quality_name(sculpture.quality_tier),
			_material_name(sculpture.material),
			format_str,
		]
		if not settlement_name.is_empty() and sculpture.format != Format.FIGURINE:
			title += " at %s" % settlement_name
		return {
			"tier": tier,
			"category": "SOCIAL",
			"topic_type": "sculpture_completion",
			"title": title,
			"subject_character_id": sculpture.creator_id,
			"ic_day_created": ic_day,
		}

	elif event == "guardian_damage":
		tier = GUARDIAN_DAMAGE_TIER_THRESHOLD - 1 if \
				sculpture.quality_tier >= GUARDIAN_DAMAGE_TIER_THRESHOLD else 3
		return {
			"tier": tier,
			"category": "SOCIAL",
			"topic_type": "guardian_damaged",
			"title": "A guardian statue at %s has been damaged." % settlement_name,
			"subject_character_id": -1,
			"ic_day_created": ic_day,
		}

	elif event == "destruction":
		tier = 2 if sculpture.quality_tier >= GUARDIAN_DAMAGE_TIER_THRESHOLD else 3
		return {
			"tier": tier,
			"category": "SOCIAL",
			"topic_type": "sculpture_destroyed",
			"title": "A %s statue of %s at %s has been destroyed." % [
				_quality_name(sculpture.quality_tier),
				sculpture.subject_description,
				settlement_name,
			],
			"subject_character_id": sculpture.creator_id,
			"ic_day_created": ic_day,
		}

	return {}


# ---------------------------------------------------------------------------
# Siege helpers (locked section K)
# ---------------------------------------------------------------------------

## Returns survival probability (0.0–1.0) for a statuary/guardian during sacking.
static func sacking_survival_chance(sculpture: SculptureData) -> float:
	var base: float = SACKING_SURVIVAL_WOOD.get(sculpture.quality_tier, 0.3)
	if sculpture.material == Material.STONE:
		base += SACKING_SURVIVAL_STONE_BONUS
	elif sculpture.material == Material.BRONZE:
		base += SACKING_SURVIVAL_BRONZE_BONUS
	return minf(1.0, base)


## Returns survival probability during zone destruction.
static func zone_destruction_survival_chance(sculpture: SculptureData) -> float:
	if sculpture.material == Material.WOOD:
		return 0.0
	if sculpture.material == Material.STONE:
		return DESTRUCTION_SURVIVAL_STONE
	return DESTRUCTION_SURVIVAL_BRONZE  # BRONZE


# ---------------------------------------------------------------------------
# World generation helpers (locked section — s57.28.12)
# ---------------------------------------------------------------------------

## Generate a statuary object for world gen (creator_id = -1, ancient).
static func gen_statuary(
		sculpture_id: int,
		quality_tier: int,
		material: int,
		subject_type: int,
		subject_id: int,
		settlement_id: int,
) -> SculptureData:
	var s: SculptureData = SculptureData.new()
	s.sculpture_id = sculpture_id
	s.format = Format.STATUARY
	s.creator_id = -1
	s.quality_tier = quality_tier
	s.target_quality_tier = quality_tier
	s.target_format = Format.STATUARY
	s.material = material
	s.subject_type = subject_type
	s.subject_id = subject_id
	s.craft_progress = -1  # Complete
	s.date_completed = -1
	s.display_settlement_id = settlement_id
	s.display_slot = DisplaySlot.STATUE_SLOT
	return s


## Generate a guardian pair for world gen.
static func gen_guardian(
		sculpture_id: int,
		quality_tier: int,
		material: int,
		subject_type: int,
		settlement_id: int,
) -> SculptureData:
	var s: SculptureData = SculptureData.new()
	s.sculpture_id = sculpture_id
	s.format = Format.GUARDIAN
	s.creator_id = -1
	s.quality_tier = quality_tier
	s.target_quality_tier = quality_tier
	s.target_format = Format.GUARDIAN
	s.material = material
	s.subject_type = subject_type
	s.paired = true
	s.pair_intact = true
	s.craft_progress = -1  # Complete
	s.date_completed = -1
	s.display_settlement_id = settlement_id
	s.display_slot = DisplaySlot.GUARDIAN_SLOT
	if material == Material.WOOD:
		# Ancient pieces assumed to have degraded to Normal already; no further tracking.
		s.ic_day_placed_outdoor = -1
	return s


## Generate a figurine for world gen (Mantis lords).
static func gen_figurine(
		sculpture_id: int,
		quality_tier: int,
		subject_type: int,
		theme: int,
		owner_id: int,
) -> SculptureData:
	var s: SculptureData = SculptureData.new()
	s.sculpture_id = sculpture_id
	s.format = Format.FIGURINE
	s.creator_id = -1
	s.quality_tier = quality_tier
	s.target_quality_tier = quality_tier
	s.target_format = Format.FIGURINE
	s.material = Material.WOOD
	s.subject_type = subject_type
	s.subject_id = owner_id  # Owned by; tracked through inventory
	s.theme = theme
	s.craft_progress = -1
	s.date_completed = -1
	return s


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _composition_threshold(sculpture: SculptureData) -> int:
	return PROGRESS_THRESHOLDS.get(sculpture.format, {}).get(sculpture.target_quality_tier, 20)


static func _quality_name(tier: int) -> String:
	match tier:
		1: return "Normal"
		2: return "Fine"
		3: return "Exceptional"
		4: return "Masterwork"
		5: return "Legendary"
	return "Unknown"


static func _material_name(mat: int) -> String:
	match mat:
		Material.WOOD: return "wood"
		Material.STONE: return "stone"
		Material.BRONZE: return "bronze"
	return "unknown"


## Replacement pair threshold: half the original pair threshold when one guardian is destroyed.
## Quality of restored pair = min(surviving_tier, replacement_tier). (GDD section P.)
static func replacement_threshold(original_quality_tier: int) -> int:
	var full: int = PROGRESS_THRESHOLDS.get(Format.GUARDIAN, {}).get(original_quality_tier, 25)
	return full / 2


## True when the sculptor's school grants +1k1 on figurine COMPOSE_SCULPTURE rolls.
## Yoritomo Sculptor technique (GDD section N).
static func has_yoritomo_figurine_bonus(school: String) -> bool:
	return school == "Yoritomo Sculptor"


## Free Raises granted on creator identification rolls for sculptures (locked section O).
## Returns 1 when sculptor_rank >= IDENTIFICATION_FR_RANK, else 0.
static func get_provenance_identification_fr(sculptor_rank: int) -> int:
	return IDENTIFICATION_FR_BONUS if sculptor_rank >= IDENTIFICATION_FR_RANK else 0


## Scan active_sculptures for figurine collection clusters (same creator_id OR same theme).
## Returns Array of topic dicts (TIER_4) for qualifying clusters.
## Fires once per season per qualifying cluster; topic_type = "figurine_collection".
static func collect_figurine_topics(
		active_sculptures: Array,
		ic_day: int,
) -> Array:
	# Group by creator_id (primary) and theme (secondary).
	var by_creator: Dictionary = {}  # creator_id → Array[SculptureData]
	var by_theme: Dictionary = {}    # theme → Array[SculptureData]

	for sc_v: Variant in active_sculptures:
		if not sc_v is SculptureData:
			continue
		var sc: SculptureData = sc_v as SculptureData
		if sc.format != Format.FIGURINE or sc.craft_progress >= 0:
			continue  # Incomplete figurines don't count.
		if sc.creator_id >= 0:
			if not by_creator.has(sc.creator_id):
				by_creator[sc.creator_id] = []
			by_creator[sc.creator_id].append(sc)
		if not by_theme.has(sc.theme):
			by_theme[sc.theme] = []
		by_theme[sc.theme].append(sc)

	var results: Array = []

	# Creator-based clusters.
	for cid: Variant in by_creator:
		var cluster: Array = by_creator[cid]
		if cluster.size() < MANTIS_COLLECTION_THRESHOLD:
			continue
		var avg_q: float = 0.0
		for sc_v: Variant in cluster:
			avg_q += (sc_v as SculptureData).quality_tier
		avg_q /= cluster.size()
		results.append({
			"tier": 3,  # TIER_4
			"category": "SOCIAL",
			"topic_type": "figurine_collection",
			"title": "A collection of figurines by the same sculptor draws admirers.",
			"subject_character_id": int(cid),
			"ic_day_created": ic_day,
		})

	# Theme-based clusters (only if not already reported via creator path).
	for theme_key: Variant in by_theme:
		var cluster: Array = by_theme[theme_key]
		if cluster.size() < MANTIS_COLLECTION_THRESHOLD:
			continue
		# Check if already covered by a creator cluster (all share same creator).
		var first_creator: int = (cluster[0] as SculptureData).creator_id
		var all_same_creator: bool = first_creator >= 0
		for sc_v: Variant in cluster:
			if (sc_v as SculptureData).creator_id != first_creator:
				all_same_creator = false
				break
		if all_same_creator and by_creator.has(first_creator) and \
				by_creator[first_creator].size() >= MANTIS_COLLECTION_THRESHOLD:
			continue  # Already reported under creator cluster.
		results.append({
			"tier": 3,  # TIER_4
			"category": "SOCIAL",
			"topic_type": "figurine_collection",
			"title": "A collection of thematically linked figurines draws admirers.",
			"subject_character_id": -1,
			"ic_day_created": ic_day,
		})

	return results


## Clean up sculpture references when a character dies.
## WIP sculptures by dead creator: mark abandoned.
## Completed sculptures remain (they outlive their creator).
static func handle_character_death(dead_id: int, active_sculptures: Array) -> void:
	for sc_v: Variant in active_sculptures:
		if not sc_v is SculptureData:
			continue
		var sc: SculptureData = sc_v as SculptureData
		if sc.creator_id != dead_id:
			continue
		if sc.craft_progress >= 0:
			sc.abandoned_incomplete = true
