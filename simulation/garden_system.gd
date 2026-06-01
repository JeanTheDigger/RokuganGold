class_name GardenSystem
## Garden and bonsai system per GDD s57.23 and s57.24.
## All values locked in s57.23a. No Node dependency — plain simulation class.

# ---------------------------------------------------------------------------
# Garden constants (s57.23a A1–A16)
# ---------------------------------------------------------------------------

## Artisan: Gardening roll TN keyed by target quality tier.
const QUALITY_TN: Dictionary = {1: 15, 2: 20, 3: 25, 4: 30, 5: 35}

## Cumulative progress required to complete a garden at each quality tier.
const QUALITY_THRESHOLD: Dictionary = {1: 20, 2: 40, 3: 70, 4: 110, 5: 160}

## Minimum Artisan: Gardening rank required to attempt each quality tier (A2).
const QUALITY_SKILL_GATE: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}

## Completion obligation window (IC seasons) by quality tier for vassal commissions (A8).
const COMPLETION_WINDOW_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}

## Visitor disposition bonus toward creator by current_tier (A6).
const VISITOR_DISPOSITION_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}

## Duration in IC days for the visitor disposition bonus (4 months × 30 IC days) (A6).
const VISITOR_BONUS_DURATION_DAYS: int = 120

## Number of visitors required to trigger a Glory tick (A7).
const GLORY_TICK_THRESHOLD: int = 5

## Creator Glory awarded per Glory tick (A7).
const CREATOR_GLORY_PER_TICK: float = 0.1

## Zone Daimyo Glory awarded per Glory tick (A7).
const DAIMYO_GLORY_PER_TICK: float = 0.01

## Glory per excess raise at Legendary (A3).
const EXCESS_RAISE_GLORY: float = 0.2

## Honor cost for an artisan who abandons a vassal commission (A9).
const ABANDONMENT_HONOR_LOSS: float = 0.5

## Disposition loss from the Daimyo upon abandonment (A9).
const ABANDONMENT_DISPOSITION_LOSS: int = 8

## Fraction of QUALITY_THRESHOLD progress that qualifies for partial mitigation (A9).
const PARTIAL_MITIGATION_THRESHOLD: float = 0.5

## Honor cost for using Sincerity (Deceit) in a forgiveness appeal, regardless of outcome (A10).
const DECEIT_HONOR_COST: float = 0.1

## Honor cost when Sincerity (Deceit) deception is detected (A10).
const DECEIT_DETECTION_HONOR_LOSS: float = 0.5

## Disposition penalty toward the artisan when deception is detected (A10).
const DECEIT_DETECTION_DISPOSITION_LOSS: int = 10

## Disposition loss from the artisan side toward the Daimyo on Daimyo-forced removal (A11).
## The Daimyo's social cost is topic-based; this is only the artisan's disposition shift.
const DAIMYO_REMOVAL_DISPOSITION_LOSS: int = 3

## Score threshold at or above which an NPC artisan voluntarily removes their garden when departing (A13).
const VOLUNTARY_REMOVAL_SCORE_THRESHOLD: int = 60

## Maximum number of visitor memory entries stored on a GardenData (A15).
const VISITOR_MEMORY_CAP: int = 200

## IC days after which visitor memory entries are purged (5 IC years) (A15).
const VISITOR_MEMORY_PURGE_DAYS: int = 1800

## Bonus score for artisan_school NPCs in cultural interest calculation.
const ARTISAN_SCHOOL_CULTURAL_INTEREST: int = 10

## Minimum cultural_interest_score required to fire cultural interest (C1).
const CULTURAL_INTEREST_THRESHOLD: int = 2

## Disposition bonus to the Daimyo based on raises at completion (A4).
const COMPLETION_BONUS_BY_RAISES: Dictionary = {0: 5, 1: 8, 2: 12, 3: 16, 4: 20}

# ---------------------------------------------------------------------------
# Bonsai constants (s57.23a B1–B7)
# ---------------------------------------------------------------------------

## quality_points threshold to advance one tier (B3).
## Key = current tier (1=Normal..4=Masterwork). Reaching threshold advances to next tier.
const BONSAI_QUALITY_THRESHOLDS: Dictionary = {1: 10, 2: 20, 3: 35, 4: 55}

## TEND_BONSAI roll TN (B2).
const BONSAI_TEND_TN: int = 10

## Glory per excess raise when tending a Legendary bonsai (B3).
const BONSAI_EXCESS_RAISE_GLORY: float = 0.05

## COLLECT_BONSAI_SPECIMEN roll TN (B1).
const BONSAI_COLLECT_TN: int = 10

## Mundane quality tier value (below Normal — bonsai at risk of death) (B4).
const BONSAI_MUNDANE: int = 0

## Settlement types eligible for bonsai display (B5).
const BONSAI_DISPLAY_ELIGIBLE_TYPES: Array = [
	Enums.SettlementType.FAMILY_CASTLE,
	Enums.SettlementType.CASTLE,
	Enums.SettlementType.CITY,
	Enums.SettlementType.KEEP,
	Enums.SettlementType.TEMPLE,
	Enums.SettlementType.SHINDEN,
	Enums.SettlementType.MONASTERY,
]

# ---------------------------------------------------------------------------
# Garden zone eligibility (settlement-level proxy for AT_ZONE, per s57.23a)
# ---------------------------------------------------------------------------

static func get_garden_eligible_zones(settlement_type: int) -> Array[String]:
	## Returns the list of zone_type Strings available at this settlement type.
	## FAMILY_CASTLE and CASTLE have both slots; CITY has only the outer courtyard;
	## all other types have no garden slots.
	match settlement_type:
		Enums.SettlementType.FAMILY_CASTLE, Enums.SettlementType.CASTLE:
			return ["CASTLE_OUTER_COURTYARD", "TSUBONIWA"]
		Enums.SettlementType.CITY:
			return ["CASTLE_OUTER_COURTYARD"]
		_:
			return []


static func has_garden_permission(settlement: SettlementData, zone_type: String, artisan_id: int) -> bool:
	## Returns true when the named artisan holds the cultivation permission for this zone.
	return settlement.garden_permissions.get(zone_type, -1) == artisan_id


static func is_zone_committed(settlement: SettlementData, zone_type: String) -> bool:
	## Returns true when any artisan holds the cultivation permission for this zone.
	return settlement.garden_permissions.get(zone_type, -1) >= 0


static func grant_permission(settlement: SettlementData, zone_type: String, artisan_id: int) -> void:
	## Grants the artisan exclusive cultivation rights for this zone.
	settlement.garden_permissions[zone_type] = artisan_id


static func clear_permission(settlement: SettlementData, zone_type: String) -> void:
	## Clears the cultivation permission for this zone (slot becomes open).
	settlement.garden_permissions[zone_type] = -1


static func has_garden(settlement: SettlementData, zone_type: String) -> bool:
	## Returns true when a completed garden occupies this zone slot.
	return settlement.garden_slots.get(zone_type, -1) >= 0

# ---------------------------------------------------------------------------
# Commission records
# ---------------------------------------------------------------------------

static func create_commission_record(
	commission_id: int,
	artisan_id: int,
	daimyo_id: int,
	settlement_id: int,
	zone_type: String,
	source_action_id: String,
	target_quality_tier: int,
	ic_day: int,
) -> CommissionRecordData:
	## Creates and returns a new CommissionRecordData.
	## Completion window is set from COMPLETION_WINDOW_BY_TIER only for
	## ASSIGN_VASSAL_OBJECTIVE commissions; all others are non-obligated (window = 0).
	var record: CommissionRecordData = CommissionRecordData.new()
	record.commission_id = commission_id
	record.artisan_id = artisan_id
	record.daimyo_id = daimyo_id
	record.settlement_id = settlement_id
	record.zone_type = zone_type
	record.art_form = "garden"
	record.source_action_id = source_action_id
	record.status = "ACTIVE"
	record.cultivation_progress = 0
	record.target_quality_tier = target_quality_tier
	record.neglect_timer = 0
	record.creation_date = ic_day
	record.window_start_date = -1
	record.progress_at_abandonment = -1
	record.forgiveness_appeal_season = -1

	if source_action_id == "ASSIGN_VASSAL_OBJECTIVE":
		record.completion_window = COMPLETION_WINDOW_BY_TIER.get(target_quality_tier, 1)
	else:
		record.completion_window = 0

	return record


static func evaluate_neglect_tick(record: CommissionRecordData, had_cultivate_ap: bool) -> void:
	## Increments the neglect timer by one season when:
	## - The window_start_date has been set (artisan has begun work)
	## - The commission is ACTIVE
	## - No CULTIVATE_GARDEN AP was spent this season
	if record.window_start_date < 0:
		return
	if record.status != "ACTIVE":
		return
	if had_cultivate_ap:
		return
	record.neglect_timer += 1


static func check_abandonment(record: CommissionRecordData) -> bool:
	## Returns true when the neglect timer has exceeded the completion window.
	## Only obligated commissions (completion_window > 0) can be formally abandoned.
	if record.completion_window <= 0:
		return false
	return record.neglect_timer > record.completion_window

# ---------------------------------------------------------------------------
# Cultivation progress
# ---------------------------------------------------------------------------

static func apply_cultivate_progress(
	record: CommissionRecordData,
	roll_result: int,
	tn: int,
	raises: int,
	ic_day: int,
) -> Dictionary:
	## Applies one session of CULTIVATE_GARDEN progress to the commission record.
	## Sets window_start_date on the first call.
	## Returns: {"progress_gained": int, "completed": bool, "completion_raises": int}

	if record.window_start_date < 0:
		record.window_start_date = ic_day

	var progress_gained: int = 0
	var completed: bool = false
	var completion_raises: int = 0

	if roll_result >= tn:
		# Success: progress = margin + raises bonus (minimum 1 from margin on exact TN hit)
		var margin: int = roll_result - tn
		progress_gained = maxi(1, margin) + raises * 5
	# Failure: progress_gained stays 0

	record.cultivation_progress += progress_gained

	var threshold: int = QUALITY_THRESHOLD.get(record.target_quality_tier, 20)
	if record.cultivation_progress >= threshold:
		completed = true
		completion_raises = raises
		record.status = "COMPLETED"

	return {
		"progress_gained": progress_gained,
		"completed": completed,
		"completion_raises": completion_raises,
	}


static func compute_completion_bonus(completion_raises: int) -> int:
	## Returns the disposition bonus to the Daimyo based on raises at completion (A4).
	## Capped at the key 4 entry for 4+ raises.
	var capped: int = mini(completion_raises, 4)
	return COMPLETION_BONUS_BY_RAISES.get(capped, 5)


static func create_garden(
	garden_id: int,
	creator_id: int,
	settlement_id: int,
	zone_type: String,
	quality_tier: int,
	completion_raises: int,
	commission_record_id: int,
	installation_date: int,
) -> GardenData:
	## Returns a new GardenData populated from commission results.
	var garden: GardenData = GardenData.new()
	garden.garden_id = garden_id
	garden.creator_id = creator_id
	garden.settlement_id = settlement_id
	garden.zone_type = zone_type
	garden.quality_tier = quality_tier
	garden.current_tier = quality_tier
	garden.installation_date = installation_date
	garden.last_maintained_season = -1
	garden.completion_raises = completion_raises
	garden.visitor_count_since_last_tick = 0
	garden.last_glory_tick_season = -1
	garden.commission_record_id = commission_record_id
	garden.destroyed = false
	garden.destruction_date = -1
	garden.destruction_cause = ""
	garden.visitor_memory = []
	return garden


static func apply_excess_raises_glory(base_tier: int, completion_raises: int) -> float:
	## Awards +0.2 Glory per raise that pushed past the Legendary cap (A3).
	## Fires when the base quality tier was already Legendary (5) before any raise upgrade,
	## or when completion_raises would have pushed the tier above Legendary.
	## In practice, raises that advance from tier 4 to 5 and beyond all contribute.
	## Returns total excess Glory to award to the creator.
	if base_tier < 5:
		return 0.0
	# All raises at Legendary become excess
	return completion_raises * EXCESS_RAISE_GLORY

# ---------------------------------------------------------------------------
# Visitor effects
# ---------------------------------------------------------------------------

static func apply_visitor(
	garden: GardenData,
	visitor_id: int,
	creator_id: int,
	ic_day: int,
) -> Dictionary:
	## Records a visit and returns the visitor effects.
	## Creator visits are excluded from visitor counting and bonuses.
	## Returns: {"bonus": int, "glory_tick": bool, "creator_glory": float, "daimyo_glory": float}

	if visitor_id == creator_id:
		return {"bonus": 0, "glory_tick": false, "creator_glory": 0.0, "daimyo_glory": 0.0}

	var bonus: int = VISITOR_DISPOSITION_BY_TIER.get(garden.current_tier, 1)

	# Update visitor memory (purge old entries, enforce cap)
	_add_visitor_memory(garden, visitor_id, ic_day)

	# Increment visitor count for glory tick
	garden.visitor_count_since_last_tick += 1

	var glory_tick: bool = false
	var creator_glory: float = 0.0
	var daimyo_glory: float = 0.0

	if garden.visitor_count_since_last_tick >= GLORY_TICK_THRESHOLD:
		glory_tick = true
		creator_glory = CREATOR_GLORY_PER_TICK
		daimyo_glory = DAIMYO_GLORY_PER_TICK
		garden.visitor_count_since_last_tick = 0

	return {
		"bonus": bonus,
		"glory_tick": glory_tick,
		"creator_glory": creator_glory,
		"daimyo_glory": daimyo_glory,
	}


static func _add_visitor_memory(garden: GardenData, visitor_id: int, ic_day: int) -> void:
	## Appends visitor entry and enforces the VISITOR_MEMORY_CAP and VISITOR_MEMORY_PURGE_DAYS.
	var entry: Dictionary = {"character_id": visitor_id, "visit_date": ic_day}
	garden.visitor_memory.append(entry)

	# Purge entries older than 1800 IC days
	var cutoff: int = ic_day - VISITOR_MEMORY_PURGE_DAYS
	var kept: Array = []
	for e: Variant in garden.visitor_memory:
		var ed: Dictionary = e as Dictionary
		if ed.get("visit_date", 0) >= cutoff:
			kept.append(ed)
	garden.visitor_memory = kept

	# Enforce cap: keep only the most recent VISITOR_MEMORY_CAP entries
	if garden.visitor_memory.size() > VISITOR_MEMORY_CAP:
		garden.visitor_memory = garden.visitor_memory.slice(
			garden.visitor_memory.size() - VISITOR_MEMORY_CAP
		)


static func has_active_bonus(character: L5RCharacterData, garden_id: int, ic_day: int) -> bool:
	## Returns true when the character has an unexpired visitor bonus entry for this garden.
	for entry_v: Variant in character.active_garden_bonuses:
		var entry: Dictionary = entry_v as Dictionary
		if entry.get("garden_id", -1) == garden_id:
			if entry.get("expires_ic_day", 0) > ic_day:
				return true
	return false

# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------

static func get_maintain_tn(garden: GardenData) -> int:
	## Returns the TN for a MAINTAIN_GARDEN roll at the current tier.
	return QUALITY_TN.get(garden.current_tier, 15)


static func apply_maintain_result(garden: GardenData, success: bool, ic_season: int) -> Dictionary:
	## Applies the outcome of a MAINTAIN_GARDEN roll.
	## Success: updates last_maintained_season.
	## Failure: degrades current_tier by 1; if tier drops below 1, destroys the garden.
	## Returns: {"degraded": bool, "destroyed": bool}

	if success:
		garden.last_maintained_season = ic_season
		return {"degraded": false, "destroyed": false}

	garden.current_tier -= 1
	if garden.current_tier < 1:
		garden.destroyed = true
		garden.destruction_cause = "MAINTENANCE_FAILURE"
		return {"degraded": true, "destroyed": true}

	return {"degraded": true, "destroyed": false}


static func apply_seasonal_auto_degradation(garden: GardenData, ic_season: int) -> Dictionary:
	## Fires when a full IC season passes without any MAINTAIN_GARDEN attempt.
	## Equivalent to a maintenance failure (s57.23a A5).
	## Returns: {"degraded": bool, "destroyed": bool}
	return apply_maintain_result(garden, false, ic_season)

# ---------------------------------------------------------------------------
# Removal
# ---------------------------------------------------------------------------

static func voluntary_remove(garden: GardenData, ic_day: int) -> Dictionary:
	## The artisan voluntarily removes their own garden before departing.
	## Returns: {"topic_tier": int, "topic_type": String, "fire_topic": bool}
	## No topic fires for a Normal-quality garden with no recent visitors (A12).

	garden.destroyed = true
	garden.destruction_cause = "VOLUNTARY_REMOVAL"
	garden.destruction_date = ic_day

	# Normal with no recent visitors: silent removal
	if garden.current_tier == 1 and garden.visitor_count_since_last_tick == 0:
		return {"topic_tier": -1, "topic_type": "garden_removed", "fire_topic": false}

	# Fine or Exceptional: Tier 4 social topic
	if garden.current_tier <= 3:
		return {"topic_tier": 4, "topic_type": "garden_removed", "fire_topic": true}

	# Masterwork or Legendary: Tier 3 social topic
	return {"topic_tier": 3, "topic_type": "garden_removed", "fire_topic": true}


static func daimyo_remove(garden: GardenData, ic_day: int) -> Dictionary:
	## The Daimyo orders removal of the garden (FORCED_REMOVAL).
	## Returns: {"topic_tier": int, "fire_topic": bool, "creator_notified": bool}
	## Topic fires for Fine or above gardens (A11 / A12).

	garden.destroyed = true
	garden.destruction_cause = "FORCED_REMOVAL"
	garden.destruction_date = ic_day

	if garden.current_tier >= 2:
		return {"topic_tier": 3, "fire_topic": true, "creator_notified": true}

	return {"topic_tier": -1, "fire_topic": false, "creator_notified": false}

# ---------------------------------------------------------------------------
# Lifecycle topics (A12)
# ---------------------------------------------------------------------------

static func make_completion_topic(
	garden: GardenData,
	creator_name: String,
	zone_name: String,
	lord_name: String,
) -> Dictionary:
	## Returns a topic dict for garden completion. Tier from A12 completion row.
	var tier: int
	match garden.current_tier:
		1, 2:
			tier = 4  # Normal / Fine
		3, 4:
			tier = 3  # Exceptional / Masterwork
		_:
			tier = 2  # Legendary

	var quality_name: String = _tier_to_name(garden.current_tier)
	return {
		"tier": tier,
		"topic_type": "garden_completed",
		"title": "%s completes a %s garden at %s for %s" % [creator_name, quality_name, zone_name, lord_name],
		"subject_creator_id": garden.creator_id,
		"garden_id": garden.garden_id,
	}


static func make_degradation_topic(
	garden: GardenData,
	creator_name: String,
	creator_alive: bool,
	creator_glory: float,
	zone_name: String,
	from_tier: int,
) -> Dictionary:
	## Returns a topic dict for tier degradation, or {} if no topic should fire.
	## Two trigger conditions (A12 degradation rows):
	## 1. Garden drops from Exceptional+ to Fine AND the creator has Glory >= 3.
	## 2. Garden drops from Fine to Normal (always fires if the creator is alive).

	# No topic if creator is dead
	if not creator_alive:
		return {}

	var to_tier: int = garden.current_tier

	# Trigger 1: Exceptional or above degraded to Fine
	if from_tier >= 3 and to_tier == 2:
		if creator_glory >= 3.0:
			return {
				"tier": 4,
				"topic_type": "garden_degraded",
				"title": "%s's garden at %s has degraded from %s to Fine" % [
					creator_name, zone_name, _tier_to_name(from_tier)
				],
				"subject_creator_id": garden.creator_id,
				"garden_id": garden.garden_id,
			}
		return {}

	# Trigger 2: Fine degraded to Normal
	if from_tier == 2 and to_tier == 1:
		return {
			"tier": 4,
			"topic_type": "garden_degraded",
			"title": "%s's garden at %s has degraded from Fine to Normal" % [creator_name, zone_name],
			"subject_creator_id": garden.creator_id,
			"garden_id": garden.garden_id,
		}

	return {}


static func make_destruction_topic(
	garden: GardenData,
	creator_name: String,
	creator_alive: bool,
	zone_name: String,
) -> Dictionary:
	## Returns a topic dict for garden destruction by neglect or maintenance failure (A12).
	## Tier by original quality_tier (the quality at installation, not current_tier).
	var _ = creator_alive  # Destruction topics fire regardless of creator status

	var tier: int
	match garden.quality_tier:
		1, 2:
			tier = 4  # Normal / Fine original
		3, 4:
			tier = 3  # Exceptional / Masterwork original
		_:
			tier = 2  # Legendary original

	return {
		"tier": tier,
		"topic_type": "garden_destroyed",
		"title": "%s's garden at %s has been lost to neglect" % [creator_name, zone_name],
		"subject_creator_id": garden.creator_id,
		"garden_id": garden.garden_id,
	}


static func make_daimyo_removal_topic(
	garden: GardenData,
	lord_name: String,
	creator_name: String,
	zone_name: String,
) -> Dictionary:
	## Returns a Tier 3 topic dict for Daimyo-forced removal of a Fine+ garden (A11 / A12).
	return {
		"tier": 3,
		"topic_type": "garden_forced_removed",
		"title": "%s ordered the removal of %s's garden at %s" % [lord_name, creator_name, zone_name],
		"subject_creator_id": garden.creator_id,
		"garden_id": garden.garden_id,
	}

# ---------------------------------------------------------------------------
# NPC evaluation (s57.23a C1, A13)
# ---------------------------------------------------------------------------

static func get_cultural_interest_score(character: L5RCharacterData) -> int:
	## Computes the cultural interest score for a character (C1).
	## rei_weight: REI virtue = 3, JIN virtue = 2, all others = 1.
	## clan_bonus: Crane/Phoenix/Dragon = +1, Crab/Scorpion = -1, others = 0.
	## artisan_school_bonus: primary school SchoolType.ARTISAN = +10.

	var rei_weight: int = 1
	var bushido: Enums.BushidoVirtue = character.bushido_virtue
	if bushido == Enums.BushidoVirtue.REI:
		rei_weight = 3
	elif bushido == Enums.BushidoVirtue.JIN:
		rei_weight = 2
	# Shourido characters have no Bushido virtue mapping to REI, default stays 1

	var clan_bonus: int = 0
	match character.clan:
		"Crane", "Phoenix", "Dragon":
			clan_bonus = 1
		"Crab", "Scorpion":
			clan_bonus = -1

	var artisan_school_bonus: int = 0
	if character.school_type == Enums.SchoolType.ARTISAN:
		artisan_school_bonus = ARTISAN_SCHOOL_CULTURAL_INTEREST

	return rei_weight + clan_bonus + artisan_school_bonus


static func cultural_interest_fires(character: L5RCharacterData) -> bool:
	## Returns true when the character's cultural interest score meets the threshold (C1).
	return get_cultural_interest_score(character) >= CULTURAL_INTEREST_THRESHOLD


static func compute_voluntary_removal_score(
	garden: GardenData,
	character: L5RCharacterData,
	has_commission: bool,
) -> int:
	## Computes the NPC score for voluntary removal before departure (A13).
	## Returns a score; removal fires if total >= VOLUNTARY_REMOVAL_SCORE_THRESHOLD.
	var score: int = 0

	# Rei virtue weight >= 3: artisan places high cultural value on the garden
	if character.bushido_virtue == Enums.BushidoVirtue.REI:
		score += 40

	# Chugi virtue weight >= 3 AND a commission exists: loyalty to the lord
	if character.bushido_virtue == Enums.BushidoVirtue.CHUGI and has_commission:
		score += 20

	# Quality Exceptional or above: significant cultural investment
	if garden.current_tier >= 3:
		score += 30

	return score

# ---------------------------------------------------------------------------
# Bonsai functions (s57.23a B1–B7)
# ---------------------------------------------------------------------------

static func create_bonsai(
	bonsai_id: int,
	owner_id: int,
	collection_province_id: int,
	ic_day: int,
	world_generated: bool = false,
) -> BonsaiData:
	## Returns a new BonsaiData at Normal quality (B1).
	var bonsai: BonsaiData = BonsaiData.new()
	bonsai.bonsai_id = bonsai_id
	bonsai.owner_id = owner_id
	bonsai.collection_province_id = collection_province_id
	bonsai.collection_date = ic_day
	bonsai.quality_tier = 1  # Normal
	bonsai.quality_points = 0
	bonsai.last_tended_month = -1
	bonsai.consecutive_missed_months = 0
	bonsai.display_settlement_id = -1
	bonsai.is_dead = false
	bonsai.world_generated = world_generated
	bonsai.provenance_history = []
	return bonsai


static func apply_tend_result(
	bonsai: BonsaiData,
	success: bool,
	raises: int,
	ic_month: int,
) -> Dictionary:
	## Applies one TEND_BONSAI attempt to the bonsai (B2, B3, B4).
	## Returns: {"quality_advanced": bool, "new_tier": int, "excess_glory": float, "degraded": bool}

	var quality_advanced: bool = false
	var excess_glory: float = 0.0
	var degraded: bool = false

	if success:
		bonsai.last_tended_month = ic_month
		bonsai.consecutive_missed_months = 0

		if raises > 0:
			if bonsai.quality_tier >= 5:
				# Already Legendary — all raises become excess glory
				excess_glory = raises * BONSAI_EXCESS_RAISE_GLORY
			else:
				bonsai.quality_points += raises
				var threshold: int = BONSAI_QUALITY_THRESHOLDS.get(bonsai.quality_tier, 9999)
				if bonsai.quality_points >= threshold:
					bonsai.quality_points = 0  # Reset points on tier advance
					bonsai.quality_tier += 1
					quality_advanced = true

					# Any further raises beyond the advance at Legendary cap
					if bonsai.quality_tier >= 5 and raises > 1:
						excess_glory = (raises - 1) * BONSAI_EXCESS_RAISE_GLORY
	else:
		bonsai.consecutive_missed_months += 1

		if bonsai.consecutive_missed_months >= 2:
			# Degrade one tier (B4)
			if bonsai.quality_tier > BONSAI_MUNDANE:
				bonsai.quality_tier -= 1
				degraded = true

		if bonsai.consecutive_missed_months >= 3 and bonsai.quality_tier == BONSAI_MUNDANE:
			# At Mundane after 3 missed months → death (B4)
			bonsai.is_dead = true

	return {
		"quality_advanced": quality_advanced,
		"new_tier": bonsai.quality_tier,
		"excess_glory": excess_glory,
		"degraded": degraded,
	}


static func apply_bonsai_visitor(
	bonsai: BonsaiData,
	visitor_id: int,
	owner_id: int,
	ic_day: int,
) -> Dictionary:
	## Records a visit to a displayed bonsai and returns visitor effects.
	## Owner visits are excluded (matching garden creator exclusion pattern).
	## Returns: {"bonus": int, "glory_tick": bool, "creator_glory": float, "daimyo_glory": float}
	## Uses the same disposition tier table as gardens (A6 / B5).
	if visitor_id == owner_id:
		return {"bonus": 0, "glory_tick": false, "creator_glory": 0.0, "daimyo_glory": 0.0}

	var bonus: int = VISITOR_DISPOSITION_BY_TIER.get(bonsai.quality_tier, 1)

	# Bonsai reuse the GardenData visitor_count field pattern through the caller;
	# the glory tick logic mirrors gardens exactly (every 5 unique visitors).
	# Callers must track visitor_count externally or embed it in bonsai data.
	# This function only returns the per-visit bonus — glory tick management
	# is delegated to the DayOrchestrator writeback (same as gardens).

	return {
		"bonus": bonus,
		"glory_tick": false,  # DayOrchestrator tracks the count
		"creator_glory": 0.0,
		"daimyo_glory": 0.0,
	}


static func get_garden_effective_tier(garden: GardenData, bonsai_display_id: int) -> int:
	## Returns the garden's effective visitor tier including the bonsai integration boost (B6).
	## When a bonsai is displayed at the same settlement, effective tier = current_tier + 1,
	## capped at Legendary (5). The boost is presence-based — bonsai quality_tier is irrelevant.
	if bonsai_display_id >= 0:
		return mini(garden.current_tier + 1, 5)
	return garden.current_tier


static func transfer_bonsai_ownership(
	bonsai: BonsaiData,
	new_owner_id: int,
	ic_day: int,
) -> void:
	## Updates owner and appends a provenance history entry.
	var relinquish_entry: Dictionary = {
		"owner_id": bonsai.owner_id,
		"acquired_date": bonsai.collection_date if bonsai.provenance_history.is_empty() else -1,
		"relinquished_date": ic_day,
	}
	bonsai.provenance_history.append(relinquish_entry)
	bonsai.owner_id = new_owner_id


static func get_bonsai_display_eligible(settlement_type: int) -> bool:
	## Returns true for settlement types that have a bonsai display slot (B5).
	return settlement_type in BONSAI_DISPLAY_ELIGIBLE_TYPES

# ---------------------------------------------------------------------------
# Historical investigation (A16)
# ---------------------------------------------------------------------------

static func get_investigation_tn(garden: GardenData, current_ic_day: int) -> int:
	## Returns the Investigation TN for researching a destroyed garden's history (A16).
	## Returns -1 if the garden is not destroyed (no historical investigation applicable).
	if not garden.destroyed or garden.destruction_date < 0:
		return -1

	var ic_years_since: float = float(current_ic_day - garden.destruction_date) / 365.0

	if ic_years_since <= 1.0:
		return 15
	elif ic_years_since <= 5.0:
		return 20
	elif ic_years_since <= 20.0:
		return 25
	elif ic_years_since <= 50.0:
		return 30
	else:
		return 35


static func apply_gardening_free_raise(gardening_rank: int) -> int:
	## Returns 1 free raise on historical investigation rolls for Artisan: Gardening rank >= 3 (A16).
	if gardening_rank >= 3:
		return 1
	return 0

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _tier_to_name(tier: int) -> String:
	match tier:
		1: return "Normal"
		2: return "Fine"
		3: return "Exceptional"
		4: return "Masterwork"
		5: return "Legendary"
		_: return "Unknown"
