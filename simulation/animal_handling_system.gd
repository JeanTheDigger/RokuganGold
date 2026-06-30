class_name AnimalHandlingSystem
## Animal Handling and Trained Companions per GDD s57.39.
## TRAIN_ANIMAL ActionID, companion cap by rank, training progression,
## companion creation and training-tier logic.

# -- Companion cap by Animal Handling rank (s57.39.4) -------------------------
const COMPANION_CAP_TABLE: Array[int] = [
	0,  # rank 0 — cannot train
	1,  # rank 1
	1,  # rank 2
	2,  # rank 3
	2,  # rank 4
	3,  # rank 5
	3,  # rank 6
	4,  # rank 7+
]

# -- Training table (s57.39.6) — keyed by species string ----------------------
# Fields: tn, threshold, wound_threshold, terrain (informational)
const SPECIES_TABLE: Dictionary = {
	"DOG": {
		"tn": 10,
		"threshold": 20,
		"wound_threshold": 5,
		"terrain": "rural",
	},
	"PIGEON": {
		"tn": 10,
		"threshold": 20,
		"wound_threshold": 2,
		"terrain": "settled",
	},
	"RIDING_HORSE": {
		"tn": 15,
		"threshold": 40,
		"wound_threshold": 10,
		"terrain": "plains_or_unicorn",
	},
	"FALCON": {
		"tn": 15,
		"threshold": 40,
		"wound_threshold": 3,
		"terrain": "mountain_hills_or_crane_crab_dragon",
	},
	"WAR_DOG": {
		"tn": 20,
		"threshold": 60,
		"wound_threshold": 8,
		"terrain": "unicorn_only",
	},
	"WARHORSE": {
		"tn": 20,
		"threshold": 60,
		"wound_threshold": 12,
		"terrain": "plains_or_unicorn",
	},
	"WARCAT": {
		"tn": 25,
		"threshold": 100,
		"wound_threshold": 15,
		"terrain": "lion_only",
	},
}

# -- Rank Mastery thresholds ---------------------------------------------------
const MASTERY_TRAIN_FOR_OTHERS_RANK: int = 3  # s57.39 R3 / s24 (agree)
const MASTERY_COMMAND_RANK: int = 5
const MASTERY_NO_FLEE_RANK: int = 7
# R7 = the "Never Flees" no-flee override (has_no_flee_override below). The project GDD is
# internally consistent: s24.3 ("will not flee from combat even when badly wounded; the Rank 5
# default flee-when-wounded behaviour is overridden") AND s57.39.8 both specify no-flee. (The
# external L5R 4e book's "issued commands non-verbally" R7 was deliberately NOT adopted by the
# project GDD — so there is no conflict and nothing to adjudicate.)

# -- Training tier thresholds (s57.39.3) ---------------------------------------
const TRAINING_TIER_FOLLOWING_SESSION: int = 3  # from 3rd session onward → "following"

# -- AP cost -------------------------------------------------------------------
const AP_COST: int = 1

# -- School lean lists (s57.39.11) --------------------------------------------
const POSITIVE_SCHOOL_PREFIXES: Array[String] = [
	"Matsu", "Shinjo", "Moto", "Utaku", "Hiruma", "Toritaka", "Ichiro", "Kitsune",
]
const NEGATIVE_SCHOOL_PREFIXES: Array[String] = [
	"Otomo", "Doji Courtier", "Soshi",
]
const SCHOOL_LEAN_POSITIVE: int = 10
const SCHOOL_LEAN_NEGATIVE: int = -10

# -- Objective alignment scores (Annex A, s57.39.11) --------------------------
const TRAIN_SKILL_SCORE: int = 70
const REST_SCORE: int = 15


# -- Companion cap -------------------------------------------------------------

## Returns the companion cap for a given Animal Handling rank.
static func get_companion_cap(skill_rank: int) -> int:
	if skill_rank <= 0:
		return 0
	if skill_rank >= 7:
		return COMPANION_CAP_TABLE[7]
	return COMPANION_CAP_TABLE[skill_rank]


## Returns the number of companions the character currently has (alive + in training).
static func count_active_companions(character: L5RCharacterData) -> int:
	var count: int = 0
	for c: Variant in character.trained_companions:
		var comp: Dictionary = c as Dictionary
		if comp.get("is_alive", false):
			count += 1
	return count


## Returns true if the character can take on another companion.
static func under_cap(character: L5RCharacterData) -> bool:
	var skill_rank: int = SkillResolver.get_skill_rank(character, "Animal Handling")
	var cap: int = get_companion_cap(skill_rank)
	return count_active_companions(character) < cap


# -- Training tier (s57.39.3) -------------------------------------------------

## Returns "wild", "following", or "trained" based on training state.
static func training_tier(companion: Dictionary) -> String:
	if companion.get("fully_trained", false):
		return "trained"
	var sessions: int = companion.get("sessions_completed", 0)
	if sessions < TRAINING_TIER_FOLLOWING_SESSION:
		return "wild"
	return "following"


# -- Precondition checks -------------------------------------------------------

## Validate TRAIN_ANIMAL for a first session (new companion acquisition).
static func can_train_first_session(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	species_str: String,
) -> Dictionary:
	var skill_rank: int = SkillResolver.get_skill_rank(character, "Animal Handling")
	if skill_rank < 1:
		return {"valid": false, "reason": "no_animal_handling_skill"}
	var valid_contexts: Array = [
		Enums.ContextFlag.AT_OWN_HOLDINGS,
		Enums.ContextFlag.VISITING,
		Enums.ContextFlag.AT_COURT,
	]
	if not (ctx.context_flag in valid_contexts):
		return {"valid": false, "reason": "invalid_context"}
	if not under_cap(character):
		return {"valid": false, "reason": "at_companion_cap"}
	if not SPECIES_TABLE.has(species_str):
		return {"valid": false, "reason": "invalid_species"}
	return {"valid": true}


## Validate TRAIN_ANIMAL for a subsequent session (advancing existing companion).
static func can_train_subsequent_session(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
	companion: Dictionary,
) -> Dictionary:
	if SkillResolver.get_skill_rank(character, "Animal Handling") < 1:
		return {"valid": false, "reason": "no_animal_handling_skill"}
	var valid_contexts: Array = [
		Enums.ContextFlag.AT_OWN_HOLDINGS,
		Enums.ContextFlag.VISITING,
		Enums.ContextFlag.AT_COURT,
	]
	if not (ctx.context_flag in valid_contexts):
		return {"valid": false, "reason": "invalid_context"}
	if not companion.get("is_alive", false):
		return {"valid": false, "reason": "companion_not_alive"}
	# A fully-trained companion is no longer trainable — UNLESS it is in the rebonding
	# window after an ownership transfer (s57.39.2): those TRAIN_ANIMAL sessions establish
	# the new owner's bond (they do not add training_progress).
	if companion.get("fully_trained", false) and int(companion.get("rebond_sessions_remaining", 0)) <= 0:
		return {"valid": false, "reason": "already_fully_trained"}
	if companion.get("owner_id", -1) != character.character_id:
		return {"valid": false, "reason": "not_owner"}
	return {"valid": true}


# -- Training roll and progress ------------------------------------------------

## Make a TRAIN_ANIMAL roll and return the result.
## Returns: {"success": bool, "progress_gained": int, "roll_total": int, "tn": int}
static func make_training_roll(
	character: L5RCharacterData,
	species_str: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	var species_data: Dictionary = SPECIES_TABLE.get(species_str, {})
	var tn: int = species_data.get("tn", 15)

	# Animal Handling + Awareness, keeping Animal Handling rank (s57.39.5)
	# Reversed keep pattern (keeps skill, not trait) — not routable through SkillResolver
	var skill_rank: int = SkillResolver.get_skill_rank(character, "Animal Handling")
	var trait_value: int = character.awareness
	var wound_pen: int = CharacterStats.get_wound_penalty(character)
	var ah_mut: Dictionary = MutationSystem.get_skill_modifiers(character, "Animal Handling")
	var rolled: int = skill_rank + trait_value + ah_mut["rolled"]
	var kept: int = skill_rank + ah_mut["kept"]

	# Clamp to L5R 4e pool limits
	var overflow_bonus: int = 0
	if rolled > 10:
		overflow_bonus += (rolled - 10) * 2
		rolled = 10
	if kept > 10:
		overflow_bonus += (kept - 10) * 2
		kept = 10
	if kept <= 0:
		kept = 1
	if rolled < kept:
		rolled = kept

	var dr: DiceResult = dice_engine.roll_and_keep(rolled, kept, true, false)
	var total: int = dr.total + overflow_bonus + wound_pen

	var success: bool = total >= tn
	var progress_gained: int = 0
	if success:
		progress_gained = (total - tn) + 1  # minimum 1 on success

	return {
		"success": success,
		"progress_gained": progress_gained,
		"roll_total": total,
		"tn": tn,
	}


# -- Companion creation --------------------------------------------------------

## Create a new companion Dictionary for a first-session acquisition.
static func create_companion(
	character_id: int,
	species_str: String,
	companion_id: int,
	companion_name: String,
	ic_day: int,
	province_id: int,
	initial_progress: int,
) -> Dictionary:
	var species_data: Dictionary = SPECIES_TABLE.get(species_str, {})
	var threshold: int = species_data.get("threshold", 20)
	var wound_threshold: int = species_data.get("wound_threshold", 5)
	return {
		"companion_id": companion_id,
		"name": companion_name,
		"species": species_str,
		"owner_id": character_id,
		"wound_total": 0,
		"wound_threshold": wound_threshold,
		"wound_rank": 0,
		"training_progress": initial_progress,
		"training_threshold": threshold,
		"sessions_completed": 1 if initial_progress > 0 else 0,
		"fully_trained": initial_progress >= threshold,
		"acquired_date_ic_day": ic_day,
		"acquired_province_id": province_id,
		"location_province_id": province_id,
		"is_alive": true,
		"rebond_sessions_remaining": 0,
	}


# -- Ownership transfer + rebonding (s57.39.2) --------------------------------

## Transfer a companion to a new owner, preserving its training (training_progress /
## fully_trained) but NOT the bond: owner_id is repointed and rebond_sessions_remaining is
## set to REBOND_SESSIONS (3) — the new owner must establish their own bond before the
## Mastery Abilities (commanding, no-flee) function (s57.39.2). Mutates the companion record.
const REBOND_SESSIONS: int = 3

static func transfer_companion(companion: Dictionary, new_owner_id: int) -> void:
	companion["owner_id"] = new_owner_id
	companion["rebond_sessions_remaining"] = REBOND_SESSIONS


## A rebonding TRAIN_ANIMAL session (s57.39.2): decrement rebond_sessions_remaining by 1
## (floor 0). These sessions do NOT modify training_progress (the animal is already trained).
## Returns the remaining count.
static func apply_rebonding_session(companion: Dictionary) -> int:
	var rem: int = maxi(0, int(companion.get("rebond_sessions_remaining", 0)) - 1)
	companion["rebond_sessions_remaining"] = rem
	return rem


# -- Travel with owner (s57.39.2) ---------------------------------------------

## Companions travel with their owner automatically: set each ALIVE companion's
## location_province_id to the owner's current province. Dead companions (archived
## records, is_alive false) are left untouched. Returns the number synced.
static func sync_companion_locations(owner: L5RCharacterData, owner_province_id: int) -> int:
	var synced: int = 0
	for c: Variant in owner.trained_companions:
		var comp: Dictionary = c as Dictionary
		if comp.get("is_alive", false):
			comp["location_province_id"] = owner_province_id
			synced += 1
	return synced


# -- Companion death (s57.39.9) -----------------------------------------------

## A readable species name for topic text ("WAR_DOG" → "war dog").
static func species_display(species: String) -> String:
	return species.to_lower().replace("_", " ")


## Build the owner's Tier-4 PERSONAL loss topic for a dead companion (s57.39.9):
## "[Owner] lost their [species] [name]." NO Glory or Honor change — a personal loss,
## not a reputation event. subject = the owner; subject_role NEUTRAL (the dead entity is
## an animal, not a character, and no reputation valence attaches). The caller assigns the
## topic_id (passed in) and appends to active_topics. Cap recovery is automatic — an
## archived (is_alive=false) record no longer counts in count_active_companions.
static func build_death_topic(owner: L5RCharacterData, companion: Dictionary, topic_id: int, ic_day: int) -> TopicData:
	var t := TopicData.new()
	t.topic_id = topic_id
	var sp: String = species_display(String(companion.get("species", "animal")))
	var nm: String = String(companion.get("name", ""))
	t.slug = "companion_death_%d_%d" % [owner.character_id, int(companion.get("companion_id", 0))]
	t.title = "%s lost their %s %s" % [owner.character_name, sp, nm]
	t.topic_type = "companion_death"
	t.variant = "companion_death"
	t.tier = TopicData.Tier.TIER_4
	t.category = TopicData.Category.PERSONAL
	t.momentum = TopicMomentumSystem.initial_momentum_for_tier(TopicData.Tier.TIER_4)
	t.subject_character_id = owner.character_id
	t.subject_role = "NEUTRAL"
	t.ic_day_created = ic_day
	return t


## Apply progress from a subsequent TRAIN_ANIMAL session to a companion.
## Mutates the companion dictionary. Returns updated companion.
static func apply_training_progress(companion: Dictionary, progress_gained: int) -> Dictionary:
	if companion.get("fully_trained", false):
		return companion
	var old_progress: int = companion.get("training_progress", 0)
	var threshold: int = companion.get("training_threshold", 20)
	var sessions: int = companion.get("sessions_completed", 0)
	var new_progress: int = old_progress + progress_gained
	companion["training_progress"] = new_progress
	companion["sessions_completed"] = sessions + 1
	if new_progress >= threshold:
		companion["fully_trained"] = true
	return companion


# -- Mastery checks (for ASCII-layer use) --------------------------------------

# s57.39 R3 / s24: commonly-domesticated animals trained by a Rank-3+ character may
# be trained for use by OTHERS (the trained companion is usable by a character other
# than the trainer). NO CONSUMER yet — TRAIN_ANIMAL always trains the actor's own
# companion (owner_id == self, enforced by can_train_subsequent_session) and no
# objective produces cross-owner training, so this is ready-but-dormant.
static func can_train_for_others(trainer_rank: int) -> bool:
	return trainer_rank >= MASTERY_TRAIN_FOR_OTHERS_RANK


static func can_command_to_attack(trainer_rank: int) -> bool:
	return trainer_rank >= MASTERY_COMMAND_RANK


static func has_no_flee_override(trainer_rank: int) -> bool:
	return trainer_rank >= MASTERY_NO_FLEE_RANK


# -- School lean helpers (Annex C) --------------------------------------------

static func has_positive_school_lean(school: String) -> bool:
	for prefix: String in POSITIVE_SCHOOL_PREFIXES:
		if school.begins_with(prefix):
			return true
	return false


static func has_negative_school_lean(school: String) -> bool:
	for prefix: String in NEGATIVE_SCHOOL_PREFIXES:
		if school.begins_with(prefix):
			return true
	return false
