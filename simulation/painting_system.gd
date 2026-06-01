class_name PaintingSystem
## Painting system per GDD s57.27. Locked in s57.27_painting_system_locked.md.
## Three ActionIDs: COMPOSE_PAINTING, DISPLAY_PAINTING, PRESENT_EMAKIMONO.
## No Node dependency — plain simulation class.

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum Format { KAKEMONO = 0, BYOBU = 1, EMAKIMONO = 2, FUSUMA = 3 }

enum SubjectType {
	SEASONAL   = 0,  # shiki-e — season_affinity required
	NATURE     = 1,  # kachō-ga — birds, flowers, generic landscape
	PORTRAIT   = 2,  # nise-e — specific character (subject_id = char_id)
	RELIGIOUS  = 3,  # butsu-e — Fortune (subject_id = fortune_id)
	BATTLE     = 4,  # kassen-e — battle/historical (subject_id = clan_id or char_id)
	CLAN       = 5,  # mon-e — clan/family (subject_id = clan_id or family_id)
	LITERARY   = 6,  # literary/court scene — neutral prestige, no subject_id
}

enum Style { YAMATO_E = 0, SUMI_E = 1, NONE = 2 }

## Art slots in a settlement (zone proxy for the three-slot system, s57.27.4).
enum DisplaySlot { WALL_ART = 0, DISPLAYED_ART = 1, FUSUMA = 2 }

# ---------------------------------------------------------------------------
# Composition progress thresholds (s57.27.5)
# Keys: Format enum → quality tier (1-5) → int progress required.
# ---------------------------------------------------------------------------

const PROGRESS_THRESHOLDS: Dictionary = {
	Format.KAKEMONO:  {1: 5,  2: 10, 3: 20, 4: 35,  5: 55},
	Format.BYOBU:     {1: 10, 2: 20, 3: 35, 4: 55,  5: 80},
	Format.EMAKIMONO: {1: 8,  2: 15, 3: 30, 4: 45,  5: 65},
	Format.FUSUMA:    {1: 15, 2: 30, 3: 50, 4: 75,  5: 100},
}

## Quality tier values for COMPOSE_PAINTING roll: TN = 15, progress = max(1, roll - 15) (s57.27.5).
const COMPOSE_TN: int = 15

## Skill gate: Artisan: Painting rank must equal or exceed quality tier (s57.27.5).
const QUALITY_SKILL_GATE: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}

## IC days without composition AP before degradation fires for byōbu/emakimono (s57.27.5).
const COMPOSITION_DEGRADATION_DAYS: int = 90

# ---------------------------------------------------------------------------
# Visitor effect constants (s57.27.10)
# ---------------------------------------------------------------------------

## Visitor disposition toward creator by quality tier (s57.27.10, P4).
const VISITOR_DISPOSITION_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 5, 5: 7}

## Duration of the visitor disposition bonus in IC days (4 IC months × 30 days).
const VISITOR_BONUS_DURATION_DAYS: int = 120

## Byōbu visitor effects calculate at quality tier +1 (capped at Legendary = 5).
const BYOBU_TIER_BONUS: int = 1

## Visitors needed to trigger one Glory tick (s57.27.10).
const GLORY_TICK_THRESHOLD: int = 5

## Creator Glory per tick (s57.27.10).
const CREATOR_GLORY_PER_TICK: float = 0.1

## Zone lord Glory per visitor tick (s57.27.10). Lower bonus for hosting.
const DAIMYO_GLORY_PER_TICK: float = 0.01

## IC seasons between allowed Glory ticks per painting (s57.27.10).
const GLORY_TICK_COOLDOWN_SEASONS: int = 1

## Kakemono seasonal harmony: visitor effects doubled (s57.27.10, s57.27.6).
const SEASONAL_HARMONY_MULTIPLIER: int = 2

## Kakemono seasonal harmony lord Glory tick rate increase (s57.27.10).
const SEASONAL_HARMONY_DAIMYO_GLORY: float = 0.05

## Ambient art topic cap per character (s57.27.11). PROVISIONAL.
const AMBIENT_TOPIC_CAP: int = 20

# ---------------------------------------------------------------------------
# Emakimono constants (s57.27.8)
# ---------------------------------------------------------------------------

## Polarization magnitude = quality tier value (Normal=1 … Legendary=5) (s57.27.8).
const EMAKIMONO_MAGNITUDE_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}

## Immunity window in IC days before a character can be affected by the same painting again (P13).
const IMMUNITY_WINDOW_DAYS: int = 14

## Raises needed to add a topic_id to an emakimono at completion (s57.27.5).
const EMAKIMONO_TOPIC_RAISES: int = 2

# ---------------------------------------------------------------------------
# Emakimono copy constants (s57.27.20)
# ---------------------------------------------------------------------------

## Copy composition threshold = original threshold ÷ 2 (s57.27.20).
const COPY_THRESHOLD_DIVISOR: int = 2

## TN to detect a copy by quality tier (Fine=25, Exceptional=30, Masterwork=35, Legendary=40).
const COPY_DETECTION_TN: Dictionary = {2: 25, 3: 30, 4: 35, 5: 40}

## Free Raise bonus on copy detection roll for Artisan: Painting rank 3+ (s57.27.20).
const COPY_DETECTION_FREE_RAISE_RANK: int = 3

# ---------------------------------------------------------------------------
# Negative framing (s57.27.13)
# ---------------------------------------------------------------------------

## On subject visit: disposition loss = quality tier value (−1 to −5) (s57.27.13).
const NEGATIVE_FRAMING_DISP_BY_TIER: Dictionary = {1: -1, 2: -2, 3: -3, 4: -4, 5: -5}

## Placement topic tier by quality: Exceptional+ = TIER_3, Fine/below = TIER_4.
const NEGATIVE_PLACEMENT_TIER_THRESHOLD: int = 3  # Exceptional = quality tier 3

# ---------------------------------------------------------------------------
# Lifecycle topic constants (s57.27.21)
# ---------------------------------------------------------------------------

## Completion topic tier: quality ≤ 3 → TIER_4, quality ≥ 4 → TIER_3 (s57.27.21 table).
const COMPLETION_TOPIC_TIER: Dictionary = {1: 3, 2: 3, 3: 3, 4: 2, 5: 2}  # TopicData.Tier enum

## Placement topic tier: Tier 4. Removal of Fine+ = Tier 4.
const PLACEMENT_TOPIC_TIER: int = 3  # TIER_4

## Fusuma repainting topic tier: Exceptional+ original = TIER_3, Fine = TIER_4.
const FUSUMA_REPAINT_TIER_THRESHOLD: int = 3

# ---------------------------------------------------------------------------
# Artist grief (s57.27.25)
# ---------------------------------------------------------------------------

## Admirer disposition loss on creator death: -(quality_tier / 2), ceiling (s57.27.25).
const ARTIST_GRIEF_BY_TIER: Dictionary = {1: -1, 2: -1, 3: -2, 4: -2, 5: -3}

# ---------------------------------------------------------------------------
# Siege/sacking survival (s57.27.25)
# ---------------------------------------------------------------------------

## Probability (0.0–1.0) that a portable painting survives a sacking by quality tier.
const SACKING_SURVIVAL_BY_TIER: Dictionary = {1: 0.20, 2: 0.30, 3: 0.40, 4: 0.50, 5: 0.60}

# ---------------------------------------------------------------------------
# Settlement eligibility (settlement-level zone proxy)
# ---------------------------------------------------------------------------

## Settlement types that support interior art slots (s57.27.4 — zone proxy).
const ELIGIBLE_SETTLEMENT_TYPES: Array = [
	"FAMILY_CASTLE", "CASTLE", "KEEP", "CITY",
	"TEMPLE", "SHINDEN", "MONASTERY",
]

## Only these settlement types support the displayed_art_slot (prestige byōbu venues).
const BYOBU_ELIGIBLE_TYPES: Array = ["FAMILY_CASTLE", "CASTLE", "CITY"]

## Gold leaf Status perception modifier (s57.27.7). Displayed while byōbu in slot.
const GOLD_LEAF_STATUS_BONUS: float = 0.5

# ---------------------------------------------------------------------------
# Clan painting disposition modifier (s57.27.11)
# ---------------------------------------------------------------------------

## ±1 disposition toward depicted clan for 30 IC days (s57.27.11, s12.2 Category 3).
const CLAN_PAINTING_DISPOSITION: int = 1
const CLAN_PAINTING_DURATION_DAYS: int = 30

# ---------------------------------------------------------------------------
# Passive Worship Points (s57.27.12) — PROVISIONAL, all zeroed
# ---------------------------------------------------------------------------

const PASSIVE_WP_BY_TIER: Dictionary = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0}  # PROVISIONAL

# ---------------------------------------------------------------------------
# Familiarity decay (s57.27.10) — PROVISIONAL, zeroed
# ---------------------------------------------------------------------------

const FAMILIARITY_DECAY_RATE: float = 0.0    # PROVISIONAL
const FAMILIARITY_DECAY_FLOOR: float = 0.0   # PROVISIONAL

# ---------------------------------------------------------------------------
# Visitor memory cap (s57.27.10)
# ---------------------------------------------------------------------------

const VISITOR_MEMORY_CAP: int = 200
const VISITOR_MEMORY_PURGE_DAYS: int = 1800  # 5 IC years

# ---------------------------------------------------------------------------
# Core composition functions
# ---------------------------------------------------------------------------

## Create a new in-progress PaintingData with declared parameters.
## Returns the PaintingData object (craft_progress = 0, date_completed = -1).
static func declare_composition(
		format: int,
		target_quality_tier: int,
		subject_type: int,
		framing: bool,
		creator_id: int,
		painting_id: int,
		ic_day: int,
		style: int = Style.NONE,
		subject_id: int = -1,
		subject_description: String = "",
		season_affinity: int = -1,
		target_topic_ids: Array = [],
		copy_of_id: int = -1,
) -> PaintingData:
	var p: PaintingData = PaintingData.new()
	p.painting_id = painting_id
	p.format = format
	p.creator_id = creator_id
	p.quality_tier = 1
	p.target_quality_tier = target_quality_tier
	p.style = style
	p.subject_type = subject_type
	p.subject_id = subject_id
	p.subject_description = subject_description
	p.framing = framing
	p.season_affinity = season_affinity
	p.target_topic_ids = target_topic_ids
	p.craft_progress = 0
	p.ic_day_last_composition_ap = ic_day
	p.is_original = copy_of_id < 0
	p.copy_of = copy_of_id
	p.generation = 0
	return p


## Advance composition progress. Returns result dict.
## die_result: raw roll result (before TN comparison).
## raises_declared: number of raises the NPC attempted.
static func resolve_compose_painting(
		painter_skill_rank: int,
		painting: PaintingData,
		die_result: int,
		raises_declared: int,
		ic_day: int,
) -> Dictionary:
	if not painting or painting.craft_progress < 0:
		return {"blocked": true, "blocked_reason": "painting_already_complete"}
	if painting.format == Format.FUSUMA and painting.display_settlement_id < 0:
		# Fusuma must be AT_ZONE; settlement must be set at declare time.
		pass  # Validated at precondition stage; allow if settlement set.

	# Skill gate: rank must equal or exceed target quality tier.
	if painter_skill_rank < QUALITY_SKILL_GATE.get(painting.target_quality_tier, 1):
		return {"blocked": true, "blocked_reason": "insufficient_skill_rank"}

	var threshold: int = _composition_threshold(painting)
	var success: bool = die_result >= COMPOSE_TN
	var progress_gained: int = 0
	if success:
		var base_progress: int = maxi(1, die_result - COMPOSE_TN)
		var raise_bonus: int = raises_declared * 5
		progress_gained = base_progress + raise_bonus
		painting.craft_progress += progress_gained
	painting.ic_day_last_composition_ap = ic_day

	# Check completion.
	var completed: bool = painting.craft_progress >= threshold
	var completion_raises: int = 0
	if completed:
		# Raises on the completing roll can upgrade quality.
		# Each raise upgrades one step (capped at Legendary = 5).
		completion_raises = raises_declared if success else 0
		var final_quality: int = mini(5, painting.target_quality_tier + completion_raises)
		# For emakimono: 2 Raises on the completing roll links target_topic_ids (s57.27.3).
		# Without 2+ raises, topic link is not established.
		if painting.format == Format.EMAKIMONO and success and raises_declared >= EMAKIMONO_TOPIC_RAISES:
			painting.topic_ids = painting.target_topic_ids.duplicate()
		else:
			painting.topic_ids = []
		painting.quality_tier = final_quality
		painting.craft_progress = -1
		painting.date_completed = ic_day
	return {
		"success": success,
		"progress_gained": progress_gained,
		"progress_total": painting.craft_progress,
		"threshold": threshold,
		"completed": completed,
		"quality_tier": painting.quality_tier,
		"completion_raises": completion_raises,
	}


## Apply composition degradation (byōbu and emakimono only).
## Returns new progress value after halving.
static func apply_composition_degradation(painting: PaintingData, ic_day: int) -> int:
	if painting.format == Format.KAKEMONO or painting.format == Format.FUSUMA:
		return painting.craft_progress  # No degradation for these formats.
	if painting.craft_progress < 0:
		return -1  # Already complete.
	var last_ap: int = painting.ic_day_last_composition_ap if painting.ic_day_last_composition_ap >= 0 else 0
	if ic_day - last_ap >= COMPOSITION_DEGRADATION_DAYS:
		painting.craft_progress = painting.craft_progress / 2
	return painting.craft_progress


# ---------------------------------------------------------------------------
# Display / placement functions
# ---------------------------------------------------------------------------

## Evaluate whether a character may place a painting in the given slot.
## Returns {can_display, blocked_reason}.
static func can_display(
		actor_id: int,
		actor_lord_id: int,
		painting: PaintingData,
		settlement: SettlementData,
		slot: int,
) -> Dictionary:
	if not painting or painting.craft_progress >= 0:
		return {"can_display": false, "blocked_reason": "painting_not_complete"}
	if not settlement:
		return {"can_display": false, "blocked_reason": "no_settlement"}

	var eligible: bool = settlement.settlement_type in ELIGIBLE_SETTLEMENT_TYPES
	if not eligible:
		return {"can_display": false, "blocked_reason": "ineligible_settlement_type"}
	if slot == DisplaySlot.DISPLAYED_ART and settlement.settlement_type not in BYOBU_ELIGIBLE_TYPES:
		return {"can_display": false, "blocked_reason": "byobu_ineligible_type"}

	# Format must match slot.
	var format_ok: bool = (
		(slot == DisplaySlot.WALL_ART and painting.format == Format.KAKEMONO) or
		(slot == DisplaySlot.DISPLAYED_ART and painting.format == Format.BYOBU) or
		(slot == DisplaySlot.FUSUMA and painting.format == Format.FUSUMA)
	)
	if not format_ok:
		return {"can_display": false, "blocked_reason": "format_slot_mismatch"}

	# Permission check: zone lord OR has permission for the slot.
	var is_lord: bool = _is_zone_lord(actor_id, settlement)
	var has_permission: bool = _has_slot_permission(actor_id, settlement, slot)
	if not is_lord and not has_permission:
		return {"can_display": false, "blocked_reason": "no_permission"}

	return {"can_display": true}


## Resolve a DISPLAY_PAINTING action. Handles slot swap.
## Returns the displaced painting_id (if any), or -1.
static func resolve_display_painting(
		actor_id: int,
		actor_lord_id: int,
		painting: PaintingData,
		settlement: SettlementData,
		slot: int,
		ic_day: int,
) -> Dictionary:
	var check: Dictionary = can_display(actor_id, actor_lord_id, painting, settlement, slot)
	if not check.get("can_display", false):
		return {"success": false, "blocked_reason": check.get("blocked_reason", "")}

	var displaced_id: int = _get_slot(settlement, slot)
	_set_slot(settlement, slot, painting.painting_id)
	painting.display_settlement_id = settlement.settlement_id
	painting.display_slot = slot
	painting.continuous_display_start_ic_day = ic_day

	return {
		"success": true,
		"displaced_painting_id": displaced_id,
		"slot": slot,
	}


## Remove a displayed painting from its slot.
## Returns result dict. Only lord or permission holder may remove.
static func resolve_remove_painting(
		actor_id: int,
		painting: PaintingData,
		settlement: SettlementData,
) -> Dictionary:
	if not painting or painting.display_settlement_id != settlement.settlement_id:
		return {"success": false, "blocked_reason": "not_displayed_here"}
	var is_lord: bool = _is_zone_lord(actor_id, settlement)
	var slot: int = painting.display_slot
	var has_permission: bool = _has_slot_permission(actor_id, settlement, slot)
	if not is_lord and not has_permission:
		return {"success": false, "blocked_reason": "no_permission"}

	_set_slot(settlement, slot, -1)
	painting.display_settlement_id = -1
	painting.display_slot = -1
	painting.continuous_display_start_ic_day = -1
	return {"success": true, "slot": slot}


# ---------------------------------------------------------------------------
# Emakimono — presentation
# ---------------------------------------------------------------------------

## Resolve PRESENT_EMAKIMONO. Applies reading effects to all eligible recipients.
## Returns per-recipient effect list.
static func resolve_present_emakimono(
		painting: PaintingData,
		recipient_ids: Array,
		chars_by_id: Dictionary,
		ic_day: int,
) -> Array:
	if painting.format != Format.EMAKIMONO or painting.craft_progress >= 0:
		return []
	var results: Array = []
	for rid: int in recipient_ids:
		var char_data = chars_by_id.get(rid)
		if not char_data:
			continue
		if CharacterStats.is_dead(char_data):
			continue
		# Immunity check.
		var last_seen: int = char_data.pieces_seen.get(painting.painting_id, -1)
		if last_seen >= 0 and ic_day - last_seen < IMMUNITY_WINDOW_DAYS:
			results.append({"recipient_id": rid, "immune": true})
			continue
		# Polarization and topic delivery.
		var disposition_shift: int = _emakimono_disposition_shift(painting)
		results.append({
			"recipient_id": rid,
			"immune": false,
			"disposition_shift": disposition_shift,
			"topic_ids_delivered": painting.topic_ids.duplicate(),
			"subject_type": painting.subject_type,
			"subject_id": painting.subject_id,
			"framing": painting.framing,
		})
		char_data.pieces_seen[painting.painting_id] = ic_day
	return results


## Compute the signed disposition shift magnitude for emakimono reading.
## Positive framing pushes positive opinions higher; negative framing inverts.
## Here we return the base magnitude; the caller applies it according to
## viewer's current disposition toward the subject (polarization rule s57.22.8).
static func _emakimono_disposition_shift(painting: PaintingData) -> int:
	var mag: int = EMAKIMONO_MAGNITUDE_BY_TIER.get(painting.quality_tier, 1)
	return mag if painting.framing else -mag


# ---------------------------------------------------------------------------
# Emakimono — copying
# ---------------------------------------------------------------------------

## Evaluate whether a character can copy an emakimono. Returns {can_copy, blocked_reason}.
static func can_copy_emakimono(copier_skill_rank: int, original: PaintingData) -> Dictionary:
	if original.format != Format.EMAKIMONO or original.craft_progress >= 0:
		return {"can_copy": false, "blocked_reason": "original_not_complete_emakimono"}
	if copier_skill_rank < original.quality_tier:
		return {"can_copy": false, "blocked_reason": "insufficient_skill_rank"}
	return {"can_copy": true}


## Start a copy composition. Returns a new PaintingData WIP.
## The copy threshold is half the original's format threshold.
static func declare_copy(
		original: PaintingData,
		copier_id: int,
		painting_id: int,
		ic_day: int,
) -> PaintingData:
	var p: PaintingData = PaintingData.new()
	p.painting_id = painting_id
	p.format = Format.EMAKIMONO
	p.creator_id = copier_id
	p.quality_tier = 1
	p.target_quality_tier = original.quality_tier
	p.subject_type = original.subject_type
	p.subject_id = original.subject_id
	p.subject_description = original.subject_description
	p.framing = original.framing
	p.season_affinity = original.season_affinity
	p.target_topic_ids = original.topic_ids.duplicate()
	p.craft_progress = 0
	p.ic_day_last_composition_ap = ic_day
	p.is_original = false
	p.copy_of = original.painting_id
	p.generation = original.generation + 1
	return p


## Composition threshold for a copy (half the original format threshold).
static func copy_threshold(original: PaintingData) -> int:
	var full: int = PROGRESS_THRESHOLDS.get(Format.EMAKIMONO, {}).get(original.quality_tier, 40)
	return maxi(1, full / COPY_THRESHOLD_DIVISOR)


## Maximum quality a copy of given generation can achieve (s57.27.20).
static func max_copy_quality(original_quality: int, generation: int) -> int:
	# Generation 0 = original; generation 1 = no reduction; generation 2 = -1; etc.
	var reduction: int = maxi(0, generation - 1)
	return maxi(1, original_quality - reduction)


# ---------------------------------------------------------------------------
# Visitor effects
# ---------------------------------------------------------------------------

## Apply visitor disposition bonus toward creator when a character enters a zone.
## Returns a dict of effects or empty dict if no effect fires.
static func apply_visitor_effect(
		visitor_id: int,
		painting: PaintingData,
		current_ic_season: int,
		ic_day: int,
) -> Dictionary:
	if not painting or painting.craft_progress >= 0:
		return {}
	if painting.display_settlement_id < 0:
		return {}
	if visitor_id == painting.creator_id:
		return {}  # Creator excluded from own bonus.
	if painting.creator_id < 0:
		return {}  # Ancient/unknown creator — no disposition target.

	# Check visitor memory — already received bonus from this painting recently?
	for entry: Dictionary in painting.visitor_memory:
		if entry.get("char_id", -1) == visitor_id:
			if ic_day - entry.get("last_visit_ic_day", 0) < VISITOR_BONUS_DURATION_DAYS:
				return {}  # Still within bonus window.

	var base_tier: int = painting.quality_tier
	# Byōbu gets +1 to effective tier (capped at 5).
	if painting.format == Format.BYOBU:
		base_tier = mini(5, base_tier + BYOBU_TIER_BONUS)
	var disp_bonus: int = VISITOR_DISPOSITION_BY_TIER.get(base_tier, 1)

	# Kakemono seasonal harmony — double the bonus.
	var harmony_active: bool = false
	if painting.format == Format.KAKEMONO and painting.season_affinity == current_ic_season:
		disp_bonus *= SEASONAL_HARMONY_MULTIPLIER
		harmony_active = true

	# Update visitor memory.
	_update_visitor_memory(painting, visitor_id, ic_day)

	# Increment visitor count for Glory tick.
	painting.visitor_count_since_last_tick += 1
	var glory_tick: bool = painting.visitor_count_since_last_tick >= GLORY_TICK_THRESHOLD
	if glory_tick:
		painting.visitor_count_since_last_tick = 0

	return {
		"creator_id": painting.creator_id,
		"disposition_change": disp_bonus,
		"toward": painting.creator_id,
		"source": "painting_visit",
		"painting_id": painting.painting_id,
		"harmony_active": harmony_active,
		"glory_tick": glory_tick,
		"creator_glory_gain": CREATOR_GLORY_PER_TICK if glory_tick else 0.0,
		"daimyo_glory_gain": (SEASONAL_HARMONY_DAIMYO_GLORY if harmony_active else DAIMYO_GLORY_PER_TICK) if glory_tick else 0.0,
	}


## Apply passive effects that fire when the subject of a negative painting visits.
## Returns disposition modifier to add as permanent historical modifier.
static func apply_negative_framing_on_subject_visit(
		painting: PaintingData,
		visitor_id: int,
) -> Dictionary:
	if painting.framing:
		return {}
	if painting.display_settlement_id < 0:
		return {}
	# Check if visitor is the subject or a member of the negatively depicted clan/family.
	var is_target: bool = (
		(painting.subject_type == SubjectType.PORTRAIT and painting.subject_id == visitor_id) or
		painting.subject_type in [SubjectType.CLAN, SubjectType.BATTLE]
	)
	if not is_target:
		return {}
	var disp_loss: int = NEGATIVE_FRAMING_DISP_BY_TIER.get(painting.quality_tier, -1)
	return {
		"disposition_change": disp_loss,
		"toward": -1,  # toward zone lord (caller resolves zone lord id)
		"source": "negative_framing_subject_visit",
		"painting_id": painting.painting_id,
		"permanent": true,
	}


# ---------------------------------------------------------------------------
# Seasonal rotation (s57.27.6, s57.27.16a)
# ---------------------------------------------------------------------------

## Evaluate whether the wall_art_slot of a settlement needs seasonal rotation.
## Returns {"needs_rotation": bool, "has_replacement": bool, "replacement_painting_id": int}.
static func evaluate_seasonal_rotation(
		settlement: SettlementData,
		paintings_by_id: Dictionary,
		inventory_paintings: Array,
		current_ic_season: int,
) -> Dictionary:
	var current_id: int = settlement.wall_art_slot
	if current_id < 0:
		return {"needs_rotation": false}
	var current: PaintingData = paintings_by_id.get(current_id)
	if not current:
		return {"needs_rotation": false}
	# Only kakemono with season_affinity triggers rotation logic.
	if current.format != Format.KAKEMONO or current.season_affinity < 0:
		return {"needs_rotation": false}
	if current.season_affinity == current_ic_season:
		return {"needs_rotation": false}
	# Needs rotation. Check if a matching kakemono is in inventory.
	for pid: int in inventory_paintings:
		var p: PaintingData = paintings_by_id.get(pid)
		if not p:
			continue
		if p.format == Format.KAKEMONO and p.season_affinity == current_ic_season and p.craft_progress < 0:
			return {
				"needs_rotation": true,
				"has_replacement": true,
				"replacement_painting_id": pid,
			}
	return {"needs_rotation": true, "has_replacement": false, "replacement_painting_id": -1}


# ---------------------------------------------------------------------------
# Lifecycle topics
# ---------------------------------------------------------------------------

## Build a raw topic dictionary for a painting lifecycle event.
## topic_type: "completion", "placement", "removal", "fusuma_completion",
##              "fusuma_repaint", "negative_placement", "presentation",
##              "copy_completion", "creator_deceased", "loot", "destruction".
static func generate_lifecycle_topic(
		painting: PaintingData,
		event_type: String,
		actor_name: String,
		zone_name: String,
		ic_day: int,
) -> Dictionary:
	var tier: int = _topic_tier_for_event(painting, event_type)
	if tier < 0:
		return {}
	var title: String = _topic_title(painting, event_type, actor_name, zone_name)
	return {
		"title": title,
		"tier": tier,
		# GDD s57.27.21: all topics PERSONAL except negative_placement, loot, destruction.
		"category": "POLITICAL" if event_type in ["negative_placement", "loot", "destruction"] else "PERSONAL",
		"ic_day_created": ic_day,
		"subject_character_id": painting.subject_id if painting.subject_type == SubjectType.PORTRAIT else -1,
		"painting_id": painting.painting_id,
		"creator_id": painting.creator_id,
	}


static func _topic_tier_for_event(painting: PaintingData, event_type: String) -> int:
	match event_type:
		"completion", "copy_completion":
			return COMPLETION_TOPIC_TIER.get(painting.quality_tier, 3)
		"placement":
			return PLACEMENT_TOPIC_TIER  # TIER_4
		"fusuma_completion":
			return COMPLETION_TOPIC_TIER.get(painting.quality_tier, 3)
		"fusuma_repaint":
			return 2 if painting.quality_tier >= FUSUMA_REPAINT_TIER_THRESHOLD else 3  # TIER_3 / TIER_4
		"negative_placement":
			return 2 if painting.quality_tier >= NEGATIVE_PLACEMENT_TIER_THRESHOLD else 3
		"presentation":
			return 4  # TIER_5 for targeted; TIER_4 for gathering (caller differentiates)
		"creator_deceased":
			return 3  # TIER_4
		"loot", "destruction":
			if painting.quality_tier >= 3:
				return 2  # TIER_3
			elif painting.quality_tier >= 2:
				return 3  # TIER_4
			else:
				return -1  # Normal quality doesn't warrant a topic
	return -1


static func _topic_title(painting: PaintingData, event_type: String, actor_name: String, zone_name: String) -> String:
	var fmt_name: String = _format_name(painting.format)
	var tier_name: String = _quality_name(painting.quality_tier)
	match event_type:
		"completion":
			return "%s has completed a %s %s depicting %s." % [actor_name, tier_name, fmt_name, painting.subject_description]
		"placement":
			return "%s has displayed a %s %s at %s." % [actor_name, tier_name, fmt_name, zone_name]
		"negative_placement":
			return "%s has displayed a %s painting depicting %s unfavorably at %s." % [actor_name, tier_name, painting.subject_description, zone_name]
		"fusuma_completion":
			return "%s has completed a %s fusuma painting at %s." % [actor_name, tier_name, zone_name]
		"fusuma_repaint":
			return "%s has ordered a fusuma at %s repainted." % [actor_name, zone_name]
		"copy_completion":
			return "%s has produced a copy of a %s." % [actor_name, fmt_name]
		"creator_deceased":
			return "%s died before completing a %s depicting %s." % [actor_name, fmt_name, painting.subject_description]
		"loot":
			return "A %s %s was seized from %s." % [tier_name, fmt_name, zone_name]
		"destruction":
			return "A %s %s was destroyed at %s." % [tier_name, fmt_name, zone_name]
	return ""


# ---------------------------------------------------------------------------
# Artist grief (s57.27.25)
# ---------------------------------------------------------------------------

## Build artist grief effect when a creator's work is destroyed/looted/overwritten.
static func apply_artist_grief(
		creator_id: int,
		destroyer_id: int,
		painting: PaintingData,
		chars_by_id: Dictionary,
) -> Dictionary:
	if creator_id < 0:
		return {}
	var creator = chars_by_id.get(creator_id)
	if not creator or CharacterStats.is_dead(creator):
		return {}
	var disp_loss: int = ARTIST_GRIEF_BY_TIER.get(painting.quality_tier, -2)
	var target_id: int = destroyer_id
	# If destroyer is unknown to creator: blame the destroyer's clan (no individual target).
	var knows_destroyer: bool = destroyer_id in creator.met_characters
	return {
		"creator_id": creator_id,
		"disposition_change": disp_loss,
		"toward": target_id if knows_destroyer else -1,
		"toward_clan": not knows_destroyer,
		"permanent": true,
		"source": "artist_grief",
	}


# ---------------------------------------------------------------------------
# Siege/sacking survival (s57.27.25)
# ---------------------------------------------------------------------------

## Evaluate whether a portable painting survives a sacking.
## Returns true/false (caller supplies a random float 0.0–1.0).
static func survives_sacking(painting: PaintingData, random_float: float) -> bool:
	if painting.format == Format.FUSUMA:
		return false  # Architectural — destroyed with the building.
	var threshold: float = SACKING_SURVIVAL_BY_TIER.get(painting.quality_tier, 0.2)
	return random_float < threshold


# ---------------------------------------------------------------------------
# Death cleanup
# ---------------------------------------------------------------------------

## Handle painter death: mark in-progress paintings as abandoned.
## Returns Array of {painting_id, event_type} for lifecycle topic generation.
static func handle_character_death(dead_char_id: int, active_paintings: Array) -> Array:
	var events: Array = []
	for painting: PaintingData in active_paintings:
		if painting.craft_progress < 0:
			continue
		if painting.creator_id != dead_char_id:
			continue
		painting.abandoned_incomplete = true
		painting.craft_progress = -1
		events.append({
			"painting_id": painting.painting_id,
			"event_type": "creator_deceased",
		})
	return events


## Collect grief events for admirers of a deceased creator's completed works (s57.27.25).
## Returns Array of {admirer_id, disposition_change, display_settlement_id} dicts.
## Caller resolves display_settlement_id to zone lord and applies the disposition.
static func collect_admirer_grief(
		dead_char_id: int,
		active_paintings: Array,
		ic_day: int,
) -> Array:
	var grief_events: Array = []
	for painting: PaintingData in active_paintings:
		if painting.creator_id != dead_char_id:
			continue
		if painting.craft_progress >= 0:
			continue  # WIP — handle_character_death marks it abandoned
		if painting.display_settlement_id < 0:
			continue  # Not displayed — no admirers to grieve
		var disp_loss: int = ARTIST_GRIEF_BY_TIER.get(painting.quality_tier, -1)
		for entry: Dictionary in painting.visitor_memory:
			var admirer_id: int = entry.get("char_id", -1)
			if admirer_id < 0 or admirer_id == dead_char_id:
				continue
			var last_visit: int = entry.get("last_visit_ic_day", -1)
			if last_visit < 0 or ic_day - last_visit >= VISITOR_BONUS_DURATION_DAYS:
				continue  # Visitor bonus has lapsed — no active admiration
			grief_events.append({
				"admirer_id": admirer_id,
				"disposition_change": disp_loss,
				"display_settlement_id": painting.display_settlement_id,
			})
	return grief_events


# ---------------------------------------------------------------------------
# Permission helpers (settlement-level zone proxy)
# ---------------------------------------------------------------------------

static func grant_slot_permission(actor_id: int, settlement: SettlementData, slot: int) -> void:
	match slot:
		DisplaySlot.WALL_ART:
			settlement.wall_art_permissions[actor_id] = true
		DisplaySlot.DISPLAYED_ART:
			settlement.displayed_art_permissions[actor_id] = true
		DisplaySlot.FUSUMA:
			settlement.fusuma_permissions[actor_id] = true


static func revoke_slot_permission(actor_id: int, settlement: SettlementData, slot: int) -> void:
	match slot:
		DisplaySlot.WALL_ART:
			settlement.wall_art_permissions.erase(actor_id)
		DisplaySlot.DISPLAYED_ART:
			settlement.displayed_art_permissions.erase(actor_id)
		DisplaySlot.FUSUMA:
			settlement.fusuma_permissions.erase(actor_id)


## Lapse all painting permissions after lordship change (1-season grace period handled
## by caller — this function clears all permissions unconditionally).
static func lapse_permissions_on_lordship_change(settlement: SettlementData) -> void:
	settlement.wall_art_permissions.clear()
	settlement.displayed_art_permissions.clear()
	settlement.fusuma_permissions.clear()


# ---------------------------------------------------------------------------
# World generation seeding (s57.27.15)
# ---------------------------------------------------------------------------

## Seed initial paintings at eligible settlements. Returns Array[PaintingData].
static func generate_world_start_paintings(
		settlements: Array,
		next_painting_id: Array,
		dice: DiceEngine,
) -> Array:
	var results: Array = []
	for s: SettlementData in settlements:
		if not s.settlement_type in ELIGIBLE_SETTLEMENT_TYPES:
			continue
		# Elevated-clan bonus handled at FAMILY_CASTLE level for Crane/Phoenix seats
		# (settlement type already encodes prestige via tier floors).
		var tier_floor: int = _world_gen_kakemono_tier(s.settlement_type, false)
		if tier_floor < 1:
			continue
		# Seed one kakemono per eligible settlement.
		var quality: int = mini(5, tier_floor + (1 if dice.roll_die(6) >= 5 else 0))
		var season: int = dice.roll_die(4) - 1  # 0=Spring..3=Winter
		var p: PaintingData = PaintingData.new()
		p.painting_id = next_painting_id[0]
		next_painting_id[0] += 1
		p.format = Format.KAKEMONO
		p.creator_id = -1  # Historical artisan.
		p.quality_tier = quality
		p.target_quality_tier = quality
		p.subject_type = SubjectType.SEASONAL
		p.season_affinity = season
		p.framing = true
		p.subject_description = "seasonal landscape"
		p.craft_progress = -1
		p.date_completed = 1
		p.display_settlement_id = s.settlement_id
		p.display_slot = DisplaySlot.WALL_ART
		p.continuous_display_start_ic_day = 1
		s.wall_art_slot = p.painting_id
		results.append(p)
		# Major settlements also get a byōbu.
		if s.settlement_type in BYOBU_ELIGIBLE_TYPES:
			var elevated_chance: int = 80 if s.settlement_type == "FAMILY_CASTLE" else 50
			if dice.roll_die(100) <= elevated_chance:
				var bq: int = mini(4, tier_floor + (1 if dice.roll_die(4) == 4 else 0))
				var bp: PaintingData = PaintingData.new()
				bp.painting_id = next_painting_id[0]
				next_painting_id[0] += 1
				bp.format = Format.BYOBU
				bp.creator_id = -1
				bp.quality_tier = bq
				bp.target_quality_tier = bq
				bp.subject_type = SubjectType.NATURE
				bp.framing = true
				bp.subject_description = "birds and flowers"
				bp.craft_progress = -1
				bp.date_completed = 1
				bp.display_settlement_id = s.settlement_id
				bp.display_slot = DisplaySlot.DISPLAYED_ART
				bp.continuous_display_start_ic_day = 1
				s.displayed_art_slot = bp.painting_id
				results.append(bp)
	return results


static func _world_gen_kakemono_tier(settlement_type: String, elevated_clan: bool) -> int:
	var base: int = 0
	match settlement_type:
		"FAMILY_CASTLE":
			base = 3  # Exceptional minimum
		"CASTLE":
			base = 2  # Fine minimum
		"CITY":
			base = 2
		"KEEP":
			base = 1
		"TEMPLE", "SHINDEN":
			base = 1  # Temples/shinden always seed one painting.
		"MONASTERY":
			base = 1
	if elevated_clan and base > 0:
		base = mini(5, base + 1)
	return base


# ---------------------------------------------------------------------------
# Context injection helpers (called from DayOrchestrator)
# ---------------------------------------------------------------------------

## Build painting context keys for a character's world_state.
## active_paintings: full Array[PaintingData] from WorldState.
static func inject_painting_context(
		ws: Dictionary,
		character,
		settlement: SettlementData,
		active_paintings: Array,
) -> void:
	if not settlement:
		return
	ws["wall_art_slot_empty"] = settlement.wall_art_slot < 0
	ws["displayed_art_slot_empty"] = settlement.displayed_art_slot < 0
	ws["fusuma_slot_empty"] = settlement.fusuma_slot < 0
	ws["has_wall_art_permission"] = _has_slot_permission(character.character_id, settlement, DisplaySlot.WALL_ART)
	# Active WIP painting this character is composing.
	var wip_id: int = -1
	# Completed paintings this character owns that are not currently displayed.
	var displayable: Array = []
	for p: PaintingData in active_paintings:
		if p.creator_id != character.character_id:
			continue
		if p.craft_progress >= 0:
			if wip_id < 0:
				wip_id = p.painting_id
		else:
			# Completed and not displayed — available for placement.
			if p.display_settlement_id < 0:
				displayable.append(p.painting_id)
	ws["active_painting_wip_id"] = wip_id
	ws["displayable_paintings"] = displayable
	# Emakimono available for presentation (completed, owned by character).
	var presentable: Array = []
	for p: PaintingData in active_paintings:
		if p.creator_id == character.character_id and p.format == Format.EMAKIMONO and p.craft_progress < 0:
			presentable.append(p.painting_id)
	ws["presentable_emakimono"] = presentable


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _composition_threshold(painting: PaintingData) -> int:
	var fmt: Dictionary = PROGRESS_THRESHOLDS.get(painting.format, {})
	return fmt.get(painting.target_quality_tier, 10)


static func _is_zone_lord(actor_id: int, settlement: SettlementData) -> bool:
	return settlement.lord_character_id == actor_id


static func _has_slot_permission(actor_id: int, settlement: SettlementData, slot: int) -> bool:
	match slot:
		DisplaySlot.WALL_ART:
			return settlement.wall_art_permissions.get(actor_id, false)
		DisplaySlot.DISPLAYED_ART:
			return settlement.displayed_art_permissions.get(actor_id, false)
		DisplaySlot.FUSUMA:
			return settlement.fusuma_permissions.get(actor_id, false)
	return false


static func _get_slot(settlement: SettlementData, slot: int) -> int:
	match slot:
		DisplaySlot.WALL_ART:
			return settlement.wall_art_slot
		DisplaySlot.DISPLAYED_ART:
			return settlement.displayed_art_slot
		DisplaySlot.FUSUMA:
			return settlement.fusuma_slot
	return -1


static func _set_slot(settlement: SettlementData, slot: int, painting_id: int) -> void:
	match slot:
		DisplaySlot.WALL_ART:
			settlement.wall_art_slot = painting_id
		DisplaySlot.DISPLAYED_ART:
			settlement.displayed_art_slot = painting_id
		DisplaySlot.FUSUMA:
			settlement.fusuma_slot = painting_id


static func _update_visitor_memory(painting: PaintingData, char_id: int, ic_day: int) -> void:
	for entry: Dictionary in painting.visitor_memory:
		if entry.get("char_id", -1) == char_id:
			entry["last_visit_ic_day"] = ic_day
			return
	painting.visitor_memory.append({"char_id": char_id, "last_visit_ic_day": ic_day})
	if painting.visitor_memory.size() > VISITOR_MEMORY_CAP:
		painting.visitor_memory.pop_front()


static func _format_name(format: int) -> String:
	match format:
		Format.KAKEMONO:   return "kakemono"
		Format.BYOBU:      return "byōbu"
		Format.EMAKIMONO:  return "emakimono"
		Format.FUSUMA:     return "fusuma"
	return "painting"


static func _quality_name(tier: int) -> String:
	match tier:
		1: return "Normal"
		2: return "Fine"
		3: return "Exceptional"
		4: return "Masterwork"
		5: return "Legendary"
	return "Unknown"
