class_name TheaterSystem
## Theater piece mechanics per GDD s57.22.
## Covers composition, learning, performance, and dedication.

enum Style {
	NOH = 0,
	KABUKI = 1,
	KYOGEN = 2,
	BUNRAKU = 3,
}

enum SubjectType {
	CLAN = 0,
	FAMILY = 1,
	CHARACTER = 2,
	ARCHETYPE = 3,
	ABSTRACT = 4,  # Fortune, spirit, mythological figure with no clan
}

# -- Composition thresholds (per GDD s57.22.5) --------------------------------

const COMPOSITION_THRESHOLD: Dictionary = {
	1: 10,
	2: 20,
	3: 35,
	4: 55,
	5: 80,
}

# Multi-role threshold modifier (added per role beyond the first)
const MULTI_ROLE_COST: Dictionary = {
	2: 10,
	3: 20,
	4: 35,
}
const MULTI_ROLE_COST_5_PLUS: int = 50  # per role beyond 4

# -- Learning thresholds (per GDD s57.22.6) -----------------------------------

const LEARNING_THRESHOLD: Dictionary = {
	1: 5,
	2: 10,
	3: 18,
	4: 28,
	5: 40,
}

const COMPOSITION_BASE_TN: int = 15
const LEARNING_BASE_TN: int = 15
const PERFORMANCE_BASE_TN: int = 15

# -- Casting TN modifiers (per GDD s57.22.4) ----------------------------------

const CASTING_MISMATCH_PENALTY: int = 5   # per mismatched feature
const CASTING_SAME_CLAN_BONUS: int = -5   # TN reduction for same-clan subject
const CASTING_ENEMY_CLAN_PENALTY: int = 5

# -- Dedication (per GDD s57.22.10) -------------------------------------------

const DEDICATION_BASE_TN: int = 10  # + magnitude * 2

# -- Performance disposition multipliers (per GDD s57.22.8) ------------------

const DISP_MULTIPLIER: Dictionary = {
	"strong_ally":  2.0,   # +51 to +100
	"ally":         1.5,   # +11 to +50
	"rival":        1.5,   # -11 to -50
	"enemy":        2.0,   # -51 to -100
}
const DISP_NEUTRAL_FLAT: int = 2   # flat push for -10 to +10

# -- Degradation (per GDD s57.22.5a) -----------------------------------------

const DEGRADATION_SEASON_DAYS: int = 90  # one IC season

# -- Performance critical success margin (per GDD s57.22.7) ------------------

const CRITICAL_SUCCESS_MARGIN: int = 15
const CRITICAL_SUCCESS_MAGNITUDE_BONUS: int = 2

# -- Bunraku bonuses (per GDD s57.22.3) --------------------------------------

const BUNRAKU_MAGNITUDE_BONUS: int = 1

# -- Immunity window (per GDD s57.22.8) --------------------------------------

const IMMUNITY_WINDOW_DAYS: int = 30

# -- Kyogen minimum Acting rank (per GDD s57.22.3) ---------------------------

const KYOGEN_MIN_ACTING_RANK: int = 3

# -- Authorship glory (per GDD s57.22.2) -------------------------------------

const AUTHORSHIP_GLORY: float = 0.1  # +0.1 Glory to living author each time another character performs their piece


# ============================================================================
# DATA CONSTRUCTORS
# ============================================================================

static func make_role(
	role_id: int,
	subject_character: String,
	subject_type: int,
	framing: bool,
	clan_requirement: String = "",
	gender_requirement: String = "",
	profession_requirement: String = "",
) -> Dictionary:
	return {
		"role_id": role_id,
		"subject_character": subject_character,
		"subject_type": subject_type,
		"framing": framing,
		"clan_requirement": clan_requirement,
		"gender_requirement": gender_requirement,
		"profession_requirement": profession_requirement,
		"assigned_performer": -1,
	}


static func make_single_role_piece(
	piece_id: int,
	title: String,
	style: int,
	author_id: int,
	subject: String,
	subject_type: int,
	framing: bool,
	magnitude: int,
	topic_weight: int,
	ic_day: int,
	clan_req: String = "",
	gender_req: String = "",
	profession_req: String = "",
) -> TheaterPieceData:
	var p := TheaterPieceData.new()
	p.piece_id = piece_id
	p.title = title
	p.style = style
	p.author_id = author_id
	p.subject = subject
	p.subject_type = subject_type
	p.framing = framing
	p.disposition_magnitude = magnitude
	p.topic_weight = topic_weight
	p.ic_day_created = ic_day
	p.num_roles_declared = 1
	p.target_magnitude = magnitude
	p.target_topic_weight = topic_weight
	var role := make_role(0, subject, subject_type, framing, clan_req, gender_req, profession_req)
	p.roles = [role]
	return p


# ============================================================================
# COMPOSITION
# ============================================================================

static func get_composition_threshold(magnitude: int, num_roles: int) -> int:
	var base: int = COMPOSITION_THRESHOLD.get(clampi(magnitude, 1, 5), 10)
	var extra: int = 0
	if num_roles >= 5:
		extra = MULTI_ROLE_COST.get(4, 35) + (num_roles - 4) * MULTI_ROLE_COST_5_PLUS
	else:
		extra = MULTI_ROLE_COST.get(num_roles, 0)
	return base + extra


static func compose_progress_per_ap(roll_total: int, raises_called: int) -> int:
	## Standard progress AP (non-completing). Per GDD s57.22.5:
	## Raises called but TN not met → 0 progress.
	## Base failure → 0 progress.
	var effective_tn: int = COMPOSITION_BASE_TN + raises_called * 5
	if roll_total < effective_tn:
		return 0
	return maxi(1, roll_total - COMPOSITION_BASE_TN) + raises_called * 5


static func completing_roll_progress(roll_total: int, completion_raises: int) -> Dictionary:
	## At-completion roll mechanics per GDD s57.22.5.
	## Returns {earned: int, raises_count: int, succeeded: bool}.
	## If raised TN not met: base progress still earned, piece doesn't complete.
	## If raised TN met: piece completes with upgrades.
	var base_tn: int = COMPOSITION_BASE_TN
	var effective_tn: int = base_tn + completion_raises * 5
	if roll_total < base_tn:
		return {"earned": 0, "raises_count": 0, "succeeded": false}
	if roll_total < effective_tn:
		# Overreached: earn base progress, piece doesn't complete this AP
		return {"earned": maxi(1, roll_total - base_tn), "raises_count": 0, "succeeded": false}
	# Success with all raises
	var progress: int = maxi(1, roll_total - base_tn) + completion_raises * 5
	return {"earned": progress, "raises_count": completion_raises, "succeeded": true}


static func apply_completion_raises(
	piece: TheaterPieceData,
	raises_count: int,
	topic_id_1: int = -1,
	topic_id_2: int = -1,
	add_magnitude: int = 0,
	add_topic_weight: int = 0,
) -> void:
	## Permanently upgrade piece using completion Raises per GDD s57.22.5.
	var remaining: int = raises_count
	# +magnitude costs 1 Raise each (max 5)
	if add_magnitude > 0 and remaining >= add_magnitude:
		piece.disposition_magnitude = mini(5, piece.disposition_magnitude + add_magnitude)
		remaining -= add_magnitude
	# +topic_weight costs 1 Raise each (max 3)
	if add_topic_weight > 0 and remaining >= add_topic_weight:
		piece.topic_weight = mini(3, piece.topic_weight + add_topic_weight)
		remaining -= add_topic_weight
	# Add topic_id linkage costs 2 Raises per topic
	if topic_id_1 >= 0 and remaining >= 2 and piece.topic_ids.size() < 2:
		piece.topic_ids.append(topic_id_1)
		remaining -= 2
	if topic_id_2 >= 0 and remaining >= 2 and piece.topic_ids.size() < 2:
		piece.topic_ids.append(topic_id_2)


static func complete_piece(
	piece: TheaterPieceData,
	author_id: int,
) -> void:
	## Finalize a completed composition.
	piece.craft_progress = -1
	piece.disposition_magnitude = piece.target_magnitude
	piece.topic_weight = piece.target_topic_weight
	if author_id >= 0 and author_id not in piece.known_by:
		piece.known_by.append(author_id)


static func degrade_abandoned_piece(piece: TheaterPieceData) -> void:
	## Halve craft_progress per GDD s57.22.5a (one abandoned season).
	if piece.craft_progress > 0:
		piece.craft_progress = maxi(1, piece.craft_progress / 2)


static func check_composition_skill_gate(character: L5RCharacterData, target_magnitude: int) -> bool:
	## Poetry rank must equal or exceed target magnitude at completion per GDD s57.22.5.
	var poetry_rank: int = character.skills.get("Poetry", 0)
	return poetry_rank >= target_magnitude


static func select_composition_piece_to_advance(
	character_id: int,
	theater_pieces: Array,
	active_need_type: String,
) -> TheaterPieceData:
	## Select which WIP piece to advance per GDD s57.22.5 priority ordering.
	## Priority: (1) political NeedType pieces, (2) highest progress ratio, (3) most recent.
	var political_types: Array[String] = ["DAMAGE_RELATIONSHIP", "MOVE_TOPIC_POSITION"]
	var candidates: Array[TheaterPieceData] = []
	for p: TheaterPieceData in theater_pieces:
		if p.craft_progress < 0 or p.lost or p.abandoned_incomplete:
			continue
		if p.author_id != character_id:
			continue
		candidates.append(p)
	if candidates.is_empty():
		return null
	var threshold_func := func(pp: TheaterPieceData) -> int:
		return get_composition_threshold(pp.target_magnitude, pp.num_roles_declared)
	# Sort: political-need pieces first, then by progress ratio, then most recent
	var is_political: bool = active_need_type in political_types
	candidates.sort_custom(func(a: TheaterPieceData, b: TheaterPieceData) -> bool:
		var ta: int = threshold_func.call(a)
		var tb: int = threshold_func.call(b)
		var ra: float = float(a.craft_progress) / float(maxi(1, ta))
		var rb: float = float(b.craft_progress) / float(maxi(1, tb))
		if ra != rb:
			return ra > rb
		return a.piece_id > b.piece_id
	)
	return candidates[0]


# ============================================================================
# LEARNING
# ============================================================================

static func get_learning_threshold(magnitude: int) -> int:
	return LEARNING_THRESHOLD.get(clampi(magnitude, 1, 5), 5)


static func learning_progress_per_ap(roll_total: int) -> int:
	## Per GDD s57.22.6: progress = roll result minus TN (min 1 on success, 0 on failure).
	if roll_total < LEARNING_BASE_TN:
		return 0
	return maxi(1, roll_total - LEARNING_BASE_TN)


static func is_already_known(character_id: int, piece: TheaterPieceData) -> bool:
	return character_id in piece.known_by


static func check_learning_skill_gate(character: L5RCharacterData, piece: TheaterPieceData) -> bool:
	## Acting rank must equal or exceed piece's disposition_magnitude per GDD s57.22.6.
	var acting_rank: int = character.skills.get("Acting", 0)
	return acting_rank >= piece.disposition_magnitude


static func find_willing_teacher(
	student_id: int,
	piece: TheaterPieceData,
	characters_by_id: Dictionary,
) -> int:
	## For private pieces: find co-located willing teacher per GDD s57.22.6.
	## Returns teacher character_id or -1.
	var student: L5RCharacterData = characters_by_id.get(student_id)
	if student == null:
		return -1
	for known_id: int in piece.known_by:
		if known_id == student_id:
			continue
		var teacher: L5RCharacterData = characters_by_id.get(known_id)
		if teacher == null or CharacterStats.is_dead(teacher):
			continue
		# Must be co-located
		if teacher.physical_location != student.physical_location:
			continue
		# Teacher willing if disposition >= 0
		var disp: int = teacher.disposition_values.get(student_id, 0)
		if disp >= 0:
			return known_id
	return -1


# ============================================================================
# CASTING
# ============================================================================

static func get_casting_tn_modifier(
	performer: L5RCharacterData,
	role: Dictionary,
	style: int,
) -> int:
	## Compute TN modifier for performing a given role per GDD s57.22.4.
	var subject_type_val: int = role.get("subject_type", SubjectType.ABSTRACT)
	var total_mod: int = 0

	if subject_type_val == SubjectType.ABSTRACT:
		return 0  # No casting requirements

	var clan_req: String = role.get("clan_requirement", "")
	var gender_req: String = role.get("gender_requirement", "")
	var profession_req: String = role.get("profession_requirement", "")

	# Noh mask rule: removes Clan and Gender mismatch/bonuses per GDD s57.22.3
	var noh_mask: bool = (style == Style.NOH)

	# Clan-based modifiers
	if not noh_mask:
		if subject_type_val == SubjectType.CLAN:
			var subject_clan: String = role.get("subject_character", "")
			if performer.clan == subject_clan:
				total_mod += CASTING_SAME_CLAN_BONUS
			elif _clans_are_traditional_enemies(performer.clan, subject_clan):
				total_mod += CASTING_ENEMY_CLAN_PENALTY
		elif subject_type_val == SubjectType.FAMILY:
			var subject_family_clan: String = role.get("subject_character", "")  # family's parent clan stored here
			if performer.clan == subject_family_clan:
				if performer.family == role.get("clan_requirement", ""):
					total_mod += CASTING_SAME_CLAN_BONUS
			elif _clans_are_traditional_enemies(performer.clan, subject_family_clan):
				total_mod += CASTING_ENEMY_CLAN_PENALTY
		elif subject_type_val in [SubjectType.CHARACTER, SubjectType.ARCHETYPE]:
			if not clan_req.is_empty():
				if performer.clan == clan_req:
					total_mod += CASTING_SAME_CLAN_BONUS if false else 0  # same-clan bonus only for clan subjects
				elif performer.clan != clan_req:
					var has_clan_emphasis: bool = "Acting" in performer.skills and performer.skills.get("Acting", 0) >= 1  # placeholder
					# Check for Clan Emphasis
					if not _has_emphasis(performer, "Acting", "Clan"):
						total_mod += CASTING_MISMATCH_PENALTY

	# Gender modifier (Noh mask removes this)
	if not noh_mask and not gender_req.is_empty():
		if performer.gender != gender_req:
			if not _has_emphasis(performer, "Acting", "Gender"):
				total_mod += CASTING_MISMATCH_PENALTY

	# Profession modifier (Noh mask does NOT remove this)
	if not profession_req.is_empty():
		if not _professions_match(performer, profession_req):
			if not _has_emphasis(performer, "Acting", "Profession"):
				total_mod += CASTING_MISMATCH_PENALTY

	return total_mod


static func _has_emphasis(_character: L5RCharacterData, _skill: String, _emphasis: String) -> bool:
	## Emphasis check — placeholder until emphasis system is detailed.
	## GDD s57.22.4 says Emphasis negates the mismatch penalty.
	return false


static func _professions_match(performer: L5RCharacterData, required_profession: String) -> bool:
	## Per GDD s57.22.4: five broad categories.
	var performer_prof: String = _school_type_to_profession(performer.school_type)
	return performer_prof == required_profession


static func _school_type_to_profession(school_type: Enums.SchoolType) -> String:
	match school_type:
		Enums.SchoolType.BUSHI:
			return "Bushi"
		Enums.SchoolType.COURTIER:
			return "Courtier"
		Enums.SchoolType.SHUGENJA:
			return "Shugenja"
		Enums.SchoolType.ARTISAN:
			return "Artisan"
		Enums.SchoolType.MONK:
			return "Monk"
	return "Bushi"


static func _clans_are_traditional_enemies(clan_a: String, clan_b: String) -> bool:
	## Per GDD s57.22.4: traditional enmity = starting inter-clan disposition Rival (-11 or below).
	## Using well-known L5R rivalries as structural reference.
	const ENMITIES: Array[String] = [
		"Crane|Scorpion", "Scorpion|Crane",
		"Lion|Crane", "Crane|Lion",
		"Crab|Crane", "Crane|Crab",
		"Lion|Scorpion", "Scorpion|Lion",
		"Crab|Shadowlands", "Shadowlands|Crab",
		"Dragon|Phoenix", "Phoenix|Dragon",
	]
	var key: String = "%s|%s" % [clan_a, clan_b]
	return key in ENMITIES


# ============================================================================
# PERFORMANCE EFFECTS
# ============================================================================

static func compute_disposition_shift(
	witness_disp: int,
	effective_magnitude: int,
) -> int:
	## Per GDD s57.22.8 Step 2: polarization rule.
	## Both framings always push existing opinions further from center.
	## The direction of push = away from neutral (toward extremes).
	if witness_disp > 50:
		return int(float(effective_magnitude) * DISP_MULTIPLIER["strong_ally"])
	elif witness_disp >= 11:
		return int(float(effective_magnitude) * DISP_MULTIPLIER["ally"])
	elif witness_disp >= -10:
		return 0  # neutral: handled by Step 3 flat seed
	elif witness_disp >= -50:
		return -int(float(effective_magnitude) * DISP_MULTIPLIER["rival"])
	else:
		return -int(float(effective_magnitude) * DISP_MULTIPLIER["enemy"])


static func compute_neutral_seed() -> int:
	## Per GDD s57.22.8 Step 3: flat push for neutral witnesses (-10 to +10).
	## Direction determined at call site based on framing.
	return DISP_NEUTRAL_FLAT


static func check_witness_immunity(
	character_id: int,
	piece: TheaterPieceData,
	ic_day: int,
) -> bool:
	## Per GDD s57.22.8: permanent immunity for known_by members.
	## 30-day window immunity for pieces seen recently.
	if character_id in piece.known_by:
		return true
	var character_obj: Object = null  # resolved by caller via pieces_seen field
	return false  # caller checks pieces_seen directly


static func get_effective_magnitude(
	piece: TheaterPieceData,
	is_bunraku_perf: bool,
	raises_succeeded: int,
	is_critical: bool,
) -> int:
	## Compute effective magnitude for this performance.
	var mag: int = piece.disposition_magnitude
	if is_bunraku_perf:
		mag += BUNRAKU_MAGNITUDE_BONUS
	if is_critical:
		mag += CRITICAL_SUCCESS_MAGNITUDE_BONUS
	else:
		mag += raises_succeeded
	return mini(mag, 10)  # no hard cap specified but keep reasonable


static func resolve_performance_roll(
	performer: L5RCharacterData,
	piece: TheaterPieceData,
	dice_engine: DiceEngine,
	raises_called: int = 0,
	ic_day: int = -1,
) -> Dictionary:
	## Resolve lead performer's Acting/Awareness roll per GDD s57.22.7.
	var style: int = piece.style
	var role: Dictionary = piece.roles[0] if not piece.roles.is_empty() else {}
	var cast_mod: int = get_casting_tn_modifier(performer, role, style)
	var tn: int = PERFORMANCE_BASE_TN + cast_mod + raises_called * 5

	# Kyogen minimum Acting rank gate
	if style == Style.KYOGEN:
		var acting_rank: int = performer.skills.get("Acting", 0)
		if acting_rank < KYOGEN_MIN_ACTING_RANK:
			return {
				"success": false, "roll_total": 0, "tn": tn, "margin": -tn,
				"raises": 0, "cast_mod": cast_mod, "blocked_kyogen_rank": true,
			}

	var roll: Dictionary = SkillResolver.resolve_skill_check(
		performer, dice_engine, "Acting", tn,
		0, "", Enums.Trait.AWARENESS, 0, 0, 0, ic_day,
	)
	var total: int = roll.get("total", 0)
	var margin: int = total - PERFORMANCE_BASE_TN - cast_mod  # margin vs base TN without raises
	var success: bool = total >= tn
	var is_critical: bool = success and margin >= CRITICAL_SUCCESS_MARGIN
	var raises_succeeded: int = raises_called if success else 0

	return {
		"success": success,
		"roll_total": total,
		"tn": tn,
		"margin": margin,
		"raises": raises_succeeded,
		"cast_mod": cast_mod,
		"is_critical": is_critical,
	}


static func compute_performance_effects(
	piece: TheaterPieceData,
	witness_ids: Array,
	characters_by_id: Dictionary,
	ic_day: int,
	effective_magnitude: int,
	is_critical: bool,
	active_topics: Array,
) -> Dictionary:
	## Compute disposition and topic amplification effects per GDD s57.22.8.
	var witness_effects: Array = []
	var amplification_topic_1: int = 0  # count of witnesses who shifted
	var amplification_topic_2: int = 0

	for wid: int in witness_ids:
		var witness: L5RCharacterData = characters_by_id.get(wid)
		if witness == null or CharacterStats.is_dead(witness):
			continue

		# Check immunity per GDD s57.22.8
		if wid in piece.known_by:
			continue  # permanent immunity for known_by members

		var last_seen: int = witness.pieces_seen.get(piece.piece_id, -1)
		if last_seen >= 0 and (ic_day - last_seen) <= IMMUNITY_WINDOW_DAYS:
			# Update the last_seen timestamp (seen again even if immune)
			witness.pieces_seen[piece.piece_id] = ic_day
			continue  # immune

		# Not immune — update last seen
		witness.pieces_seen[piece.piece_id] = ic_day

		var any_shift: bool = false
		var role_effects: Array = []

		for role: Dictionary in piece.roles:
			var subject_char: String = role.get("subject_character", "")
			var sub_type: int = role.get("subject_type", SubjectType.ABSTRACT)
			var role_framing: bool = role.get("framing", true)

			# Subject-as-witness exception: skip if witness IS the subject
			if sub_type == SubjectType.CHARACTER and str(wid) == subject_char:
				continue

			var target_subject: String = _resolve_disposition_target(subject_char, sub_type, role)
			if target_subject.is_empty():
				continue

			var current_disp: int = _get_disposition_toward_subject(witness, target_subject, sub_type, subject_char)

			var delta: int
			if current_disp >= -10 and current_disp <= 10:
				# Neutral: flat seed push toward framing direction
				delta = DISP_NEUTRAL_FLAT if role_framing else -DISP_NEUTRAL_FLAT
			else:
				# Polarization: push away from center regardless of framing
				delta = compute_disposition_shift(current_disp, effective_magnitude)

			if delta != 0:
				any_shift = true
				role_effects.append({
					"subject": target_subject,
					"subject_type": sub_type,
					"delta": delta,
				})

		if any_shift:
			amplification_topic_1 += 1
			amplification_topic_2 += 1  # same count for both topics per GDD

		witness_effects.append({
			"character_id": wid,
			"role_effects": role_effects,
			"any_shift": any_shift,
		})

	# Topic amplification per GDD s57.22.8 Step 4
	# Runs once per performance regardless of role count
	var topic_amplifications: Array = []
	var amplified_witness_count: int = amplification_topic_1  # same value both topics use
	for tid: int in piece.topic_ids:
		var topic: TopicData = _find_active_topic(tid, active_topics)
		if topic == null:
			continue
		var amp: int = piece.topic_weight * 2 * amplified_witness_count
		if is_critical:
			amp = piece.topic_weight * 3 * amplified_witness_count  # max topic_weight on critical
		topic_amplifications.append({"topic_id": tid, "momentum_gain": amp})

	return {
		"witness_effects": witness_effects,
		"topic_amplifications": topic_amplifications,
		"amplified_witness_count": amplified_witness_count,
	}


static func _resolve_disposition_target(
	subject_char: String,
	sub_type: int,
	role: Dictionary,
) -> String:
	## Resolve what target the disposition shift applies to per GDD s57.22.8 Step 1.
	match sub_type:
		SubjectType.CLAN:
			return subject_char  # clan name
		SubjectType.FAMILY:
			return subject_char  # family name (for family-level disposition)
		SubjectType.CHARACTER:
			return subject_char  # str(character_id)
		SubjectType.ARCHETYPE:
			return role.get("clan_requirement", "")  # archetype → clan component
		SubjectType.ABSTRACT:
			return ""  # no disposition target
	return ""


static func _get_disposition_toward_subject(
	witness: L5RCharacterData,
	target_subject: String,
	sub_type: int,
	subject_char: String,
) -> int:
	## Get witness disposition toward a subject. CHARACTER uses int key lookup.
	if sub_type == SubjectType.CHARACTER and subject_char.is_valid_int():
		var cid: int = int(subject_char)
		return witness.disposition_values.get(cid, 0)
	# Clan/family dispositions — use a representative numeric key via hash
	# (collective disposition is tracked separately; use 0 as baseline)
	return 0


static func _find_active_topic(topic_id: int, active_topics: Array) -> TopicData:
	for t: TopicData in active_topics:
		if t.topic_id == topic_id and not t.resolved:
			return t
	return null


# ============================================================================
# DEDICATION
# ============================================================================

static func get_dedication_tn(piece: TheaterPieceData) -> int:
	## Per GDD s57.22.10: TN 10 + (magnitude * 2).
	return DEDICATION_BASE_TN + piece.disposition_magnitude * 2


static func can_dedicate(
	character_id: int,
	piece: TheaterPieceData,
	topic_id: int,
	character: L5RCharacterData,
) -> bool:
	## Check all preconditions for DEDICATE_PIECE per GDD s57.22.10.
	if character_id not in piece.known_by:
		return false
	if piece.topic_ids.size() >= 2:
		return false
	if topic_id in piece.topic_ids:
		return false
	# Check not already dedicated same topic by same character
	# (tracked externally via KnowledgeEntry or by checking piece directly)
	var topic_known: bool = topic_id in character.topic_pool
	return topic_known


# ============================================================================
# KNOWN-BY MAINTENANCE (death cleanup)
# ============================================================================

static func handle_character_death(
	dead_id: int,
	theater_pieces: Array,
) -> void:
	## Remove dead character from known_by lists; mark pieces as lost/abandoned
	## per GDD s57.22.9.
	for piece: TheaterPieceData in theater_pieces:
		# Remove from known_by
		var idx: int = piece.known_by.find(dead_id)
		if idx >= 0:
			piece.known_by.remove_at(idx)
			# If private piece now has empty known_by: mark lost
			if not piece.canonized and piece.known_by.is_empty() and not piece.lost:
				piece.lost = true

		# If dead character was author of in-progress piece
		if piece.author_id == dead_id and piece.craft_progress >= 0 and not piece.abandoned_incomplete:
			piece.craft_progress = -1
			piece.abandoned_incomplete = true


# ============================================================================
# TOPIC ID MAINTENANCE
# ============================================================================

static func purge_stale_topic_ids(
	theater_pieces: Array,
	active_topics: Array,
) -> void:
	## Remove resolved or absent topic_ids from all pieces per GDD s57.22.2.
	## "When a referenced topic's momentum reaches zero and the topic is purged,
	## that entry is removed from the list automatically on the next engine pass."
	var active_ids: Dictionary = {}
	for t: Variant in active_topics:
		var tid: int = -1
		var is_resolved: bool = false
		if t is TopicData:
			tid = (t as TopicData).topic_id
			is_resolved = (t as TopicData).resolved
		elif t is Dictionary:
			tid = int(t.get("topic_id", -1))
			is_resolved = bool(t.get("resolved", false))
		if tid >= 0 and not is_resolved:
			active_ids[tid] = true

	for piece: TheaterPieceData in theater_pieces:
		if piece.topic_ids.is_empty():
			continue
		var i: int = piece.topic_ids.size() - 1
		while i >= 0:
			var tid: int = piece.topic_ids[i]
			if not active_ids.has(tid):
				piece.topic_ids.remove_at(i)
			i -= 1


# ============================================================================
# DEGRADATION (seasonal)
# ============================================================================

static func process_degradation(
	theater_pieces: Array,
	ic_day: int,
) -> void:
	## Per GDD s57.22.5a: halve progress for each piece with no composition
	## AP spent in the past season.
	for piece: TheaterPieceData in theater_pieces:
		if piece.craft_progress < 0:
			continue
		if piece.abandoned_incomplete or piece.lost:
			continue
		var last_ap: int = piece.ic_day_last_composition_ap
		if last_ap < 0:
			continue
		var days_idle: int = ic_day - last_ap
		# Only degrade if a full season has passed since last composition AP
		if days_idle >= DEGRADATION_SEASON_DAYS:
			degrade_abandoned_piece(piece)


# ============================================================================
# WORLD START GENERATION (per GDD s57.22.9–10)
# ============================================================================

# Approximate piece counts by clan
const STARTING_PIECE_COUNTS: Dictionary = {
	"Crane": [12, 15],
	"Phoenix": [10, 12],
	"Lion": [7, 9],
	"Scorpion": [6, 8],
	"Dragon": [5, 7],
	"Unicorn": [4, 6],
	"Crab": [2, 4],
	"Imperial": [3, 5],
	"Mantis": [1, 2],
	"Fox": [1, 2],
	"Wasp": [1, 1],
	"Sparrow": [1, 1],
	"Tortoise": [1, 1],
}

# Clan-weighted style distribution (index = Style enum value)
# NOH=0, KABUKI=1, KYOGEN=2, BUNRAKU=3
const CLAN_STYLE_WEIGHTS: Dictionary = {
	"Crane":   [3, 2, 1, 2],
	"Phoenix": [4, 1, 1, 2],
	"Lion":    [3, 3, 1, 1],
	"Scorpion":[2, 2, 4, 1],
	"Dragon":  [4, 1, 1, 2],
	"Unicorn": [2, 3, 1, 2],
	"Crab":    [2, 3, 1, 1],
	"Imperial":[3, 2, 2, 1],
	"_default":[2, 2, 2, 1],
}

const STYLE_NAMES: Array[String] = ["Noh", "Kabuki", "Kyogen", "Bunraku"]

static func generate_canonized_pieces(
	dice_engine: DiceEngine,
	next_piece_id: Array,
	ic_day: int = 0,
) -> Array[TheaterPieceData]:
	## Generate world-start canonized pieces per GDD s57.22.9–10.
	var pieces: Array[TheaterPieceData] = []

	for clan: String in STARTING_PIECE_COUNTS:
		var range_arr: Array = STARTING_PIECE_COUNTS[clan]
		var min_count: int = range_arr[0]
		var max_count: int = range_arr[1]
		var count: int = min_count + (dice_engine.roll_d10() % (max_count - min_count + 1))

		var weights: Array = CLAN_STYLE_WEIGHTS.get(clan, CLAN_STYLE_WEIGHTS["_default"])

		for _i: int in range(count):
			var piece_id: int = next_piece_id[0]
			next_piece_id[0] = piece_id + 1

			var style: int = _weighted_roll(dice_engine, weights)
			# Kyogen: force negative framing per GDD s57.22.9
			var framing: bool = true if style != Style.KYOGEN else false
			if style != Style.KYOGEN:
				framing = dice_engine.roll_d10() > 5

			var magnitude: int = 1 + (dice_engine.roll_d10() % 3)  # 1-3
			var topic_weight: int = 1 + (dice_engine.roll_d10() % 2)  # 1-2

			var sub_roll: int = dice_engine.roll_d10()
			var sub_type: int
			var subject: String
			if sub_roll <= 5:
				sub_type = SubjectType.CLAN
				subject = clan
			elif sub_roll <= 8:
				sub_type = SubjectType.FAMILY
				subject = clan + "_family"  # simplified; no family detail needed
			else:
				sub_type = SubjectType.ABSTRACT
				subject = "legendary_figure"

			var p := TheaterPieceData.new()
			p.piece_id = piece_id
			p.title = _generate_piece_title(clan, style, framing, dice_engine)
			p.style = style
			p.author_id = -1
			p.subject = subject
			p.subject_type = sub_type
			p.framing = framing
			p.disposition_magnitude = magnitude
			p.target_magnitude = magnitude
			p.topic_weight = topic_weight
			p.target_topic_weight = topic_weight
			p.canonized = true
			p.craft_progress = -1
			p.ic_day_created = ic_day
			p.num_roles_declared = 1
			var role := make_role(0, subject, sub_type, framing)
			p.roles = [role]
			pieces.append(p)

	return pieces


static func _weighted_roll(dice_engine: DiceEngine, weights: Array) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = dice_engine.roll_d10() % total
	var cumulative: int = 0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0


static func _generate_piece_title(
	clan: String,
	style: int,
	framing: bool,
	dice_engine: DiceEngine,
) -> String:
	var style_tag: String = STYLE_NAMES[style] if style < STYLE_NAMES.size() else "Noh"
	var mood: String = "The Glory of" if framing else "The Sorrow of"
	var idx: int = dice_engine.roll_d10() % 5
	var suffixes: Array[String] = [
		"the First Bloom", "a Fallen Petal", "the Empty Road",
		"the Silent River", "the Ancient Flame",
	]
	return "%s %s (%s)" % [mood, clan, style_tag]
