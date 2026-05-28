extends GutTest

var _dice: DiceEngine
var _author: L5RCharacterData
var _learner: L5RCharacterData
var _witness: L5RCharacterData


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	_author = L5RCharacterData.new()
	_author.character_id = 1
	_author.clan = "Crane"
	_author.intelligence = 3
	_author.awareness = 3
	_author.skills = {"Poetry": 4, "Acting": 3, "Courtier": 3}

	_learner = L5RCharacterData.new()
	_learner.character_id = 2
	_learner.clan = "Lion"
	_learner.intelligence = 2
	_learner.awareness = 2
	_learner.skills = {"Acting": 3}

	_witness = L5RCharacterData.new()
	_witness.character_id = 3
	_witness.clan = "Scorpion"


# ============================================================================
# COMPOSITION THRESHOLD
# ============================================================================

func test_composition_threshold_base() -> void:
	assert_eq(TheaterSystem.get_composition_threshold(1, 1), 10)
	assert_eq(TheaterSystem.get_composition_threshold(3, 1), 35)
	assert_eq(TheaterSystem.get_composition_threshold(5, 1), 80)


func test_composition_threshold_multi_role() -> void:
	var base_3: int = TheaterSystem.COMPOSITION_THRESHOLD[3]  # 35
	var two_role: int = TheaterSystem.get_composition_threshold(3, 2)
	assert_eq(two_role, base_3 + TheaterSystem.MULTI_ROLE_COST[2])


func test_composition_progress_zero_on_failure() -> void:
	var progress: int = TheaterSystem.compose_progress_per_ap(5, 0)
	assert_eq(progress, 0)


func test_composition_progress_success() -> void:
	# Roll of 25 vs TN 15 (no raises): base 25-15 = 10 + 0 = 10 min 1 = 10
	var progress: int = TheaterSystem.compose_progress_per_ap(25, 0)
	assert_gt(progress, 0)


func test_completing_roll_overreach() -> void:
	# Roll 16 (meets base TN 15) but raises TN = 25 (2 raises): piece doesn't complete
	var result: Dictionary = TheaterSystem.completing_roll_progress(16, 2)
	assert_false(result.get("succeeded", true))
	assert_gt(result.get("earned", 0), 0)


func test_completing_roll_success() -> void:
	# Roll 30 meets TN 25 (2 raises): piece completes
	var result: Dictionary = TheaterSystem.completing_roll_progress(30, 2)
	assert_true(result.get("succeeded", false))


# ============================================================================
# SKILL GATES
# ============================================================================

func test_composition_skill_gate_pass() -> void:
	assert_true(TheaterSystem.check_composition_skill_gate(_author, 3))


func test_composition_skill_gate_fail() -> void:
	var low_author: L5RCharacterData = L5RCharacterData.new()
	low_author.skills = {"Poetry": 1}
	assert_false(TheaterSystem.check_composition_skill_gate(low_author, 3))


func test_learning_skill_gate_pass() -> void:
	var piece: TheaterPieceData = _make_piece(1, 3)
	assert_true(TheaterSystem.check_learning_skill_gate(_learner, piece))


func test_learning_skill_gate_fail() -> void:
	var piece: TheaterPieceData = _make_piece(1, 5)
	assert_false(TheaterSystem.check_learning_skill_gate(_learner, piece))


# ============================================================================
# COMPLETE_PIECE
# ============================================================================

func test_complete_piece_marks_done() -> void:
	var piece: TheaterPieceData = _make_wip(1, 2)
	piece.craft_progress = 20  # at threshold
	TheaterSystem.complete_piece(piece, _author.character_id)
	assert_eq(piece.craft_progress, -1)
	assert_true(_author.character_id in piece.known_by)


# ============================================================================
# LEARNING THRESHOLD AND PROGRESS
# ============================================================================

func test_learning_threshold() -> void:
	assert_eq(TheaterSystem.get_learning_threshold(1), 5)
	assert_eq(TheaterSystem.get_learning_threshold(3), 18)
	assert_eq(TheaterSystem.get_learning_threshold(5), 40)


func test_learning_progress_zero_on_fail() -> void:
	assert_eq(TheaterSystem.learning_progress_per_ap(10), 0)


func test_learning_progress_success() -> void:
	var p: int = TheaterSystem.learning_progress_per_ap(20)
	assert_gt(p, 0)


func test_already_known_true() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.known_by.append(2)
	assert_true(TheaterSystem.is_already_known(2, piece))


func test_already_known_false() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	assert_false(TheaterSystem.is_already_known(99, piece))


# ============================================================================
# EFFECTIVE MAGNITUDE
# ============================================================================

func test_effective_magnitude_base() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	var mag: int = TheaterSystem.get_effective_magnitude(piece, false, 0, false)
	assert_eq(mag, 2)


func test_effective_magnitude_bunraku_bonus() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	var mag: int = TheaterSystem.get_effective_magnitude(piece, true, 0, false)
	assert_eq(mag, 2 + TheaterSystem.BUNRAKU_MAGNITUDE_BONUS)


func test_effective_magnitude_critical_bonus() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	var mag: int = TheaterSystem.get_effective_magnitude(piece, false, 0, true)
	assert_eq(mag, 2 + TheaterSystem.CRITICAL_SUCCESS_MAGNITUDE_BONUS)


func test_effective_magnitude_raises() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	var mag: int = TheaterSystem.get_effective_magnitude(piece, false, 2, false)
	assert_eq(mag, 4)


# ============================================================================
# DISPOSITION SHIFTS (POLARIZATION)
# ============================================================================

func test_disposition_shift_strong_ally() -> void:
	var shift: int = TheaterSystem.compute_disposition_shift(60, 3)
	assert_gt(shift, 0)


func test_disposition_shift_enemy() -> void:
	var shift: int = TheaterSystem.compute_disposition_shift(-60, 3)
	assert_lt(shift, 0)


func test_disposition_shift_neutral_returns_zero() -> void:
	# Neutral witnesses return 0 from polarization (flat seed handled separately)
	var shift: int = TheaterSystem.compute_disposition_shift(0, 3)
	assert_eq(shift, 0)


func test_neutral_seed_positive() -> void:
	assert_eq(TheaterSystem.compute_neutral_seed(), TheaterSystem.DISP_NEUTRAL_FLAT)


# ============================================================================
# IMMUNITY WINDOW
# ============================================================================

func test_immunity_known_by_member() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.known_by.append(3)
	assert_true(TheaterSystem.check_witness_immunity(3, piece, 100))


func test_no_immunity_unknown_member() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	assert_false(TheaterSystem.check_witness_immunity(99, piece, 100))


# ============================================================================
# COMPUTE_PERFORMANCE_EFFECTS — WITNESS DISPOSITION
# ============================================================================

func test_performance_effects_neutral_witness_gets_seed() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.canonized = true
	# framing = true (positive), witness neutral disposition
	_witness.disposition_values = {}
	var chars_by_id: Dictionary = {
		_witness.character_id: _witness,
	}
	var effects: Dictionary = TheaterSystem.compute_performance_effects(
		piece, [_witness.character_id], chars_by_id, 100, 2, false, [],
	)
	var witness_effects: Array = effects.get("witness_effects", [])
	assert_eq(witness_effects.size(), 1)
	# Role effects should contain a seed push
	var we: Dictionary = witness_effects[0]
	var role_effects: Array = we.get("role_effects", [])
	assert_gt(role_effects.size(), 0)


func test_performance_effects_immune_witness_skipped() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.canonized = true
	piece.known_by.append(_witness.character_id)
	var chars_by_id: Dictionary = {_witness.character_id: _witness}
	var effects: Dictionary = TheaterSystem.compute_performance_effects(
		piece, [_witness.character_id], chars_by_id, 100, 2, false, [],
	)
	var we: Array = effects.get("witness_effects", [])
	assert_eq(we.size(), 0)


func test_performance_effects_immunity_window_skips() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.canonized = true
	# Witness saw this 10 days ago (within 30-day window)
	_witness.pieces_seen[piece.piece_id] = 90
	var chars_by_id: Dictionary = {_witness.character_id: _witness}
	var effects: Dictionary = TheaterSystem.compute_performance_effects(
		piece, [_witness.character_id], chars_by_id, 100, 2, false, [],
	)
	var we: Array = effects.get("witness_effects", [])
	assert_eq(we.size(), 0)


# ============================================================================
# TOPIC AMPLIFICATION
# ============================================================================

func test_topic_amplification_fires() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.canonized = true
	piece.topic_ids = [10]
	piece.topic_weight = 2

	var topic := TopicData.new()
	topic.topic_id = 10
	topic.momentum = 50
	topic.resolved = false

	_witness.disposition_values = {}
	var chars_by_id: Dictionary = {_witness.character_id: _witness}
	var effects: Dictionary = TheaterSystem.compute_performance_effects(
		piece, [_witness.character_id], chars_by_id, 100, 2, false, [topic],
	)
	var amps: Array = effects.get("topic_amplifications", [])
	assert_gt(amps.size(), 0)
	var amp: Dictionary = amps[0]
	assert_eq(amp.get("topic_id", -1), 10)
	assert_gt(amp.get("momentum_gain", 0), 0)


# ============================================================================
# DEDICATION
# ============================================================================

func test_dedication_tn() -> void:
	var piece: TheaterPieceData = _make_piece(1, 3)
	var expected_tn: int = TheaterSystem.DEDICATION_BASE_TN + 3 * 2
	assert_eq(TheaterSystem.get_dedication_tn(piece), expected_tn)


func test_can_dedicate_pass() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.known_by.append(_author.character_id)
	_author.topic_pool = [5]
	assert_true(TheaterSystem.can_dedicate(_author.character_id, piece, 5, _author))


func test_can_dedicate_already_full() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.known_by.append(_author.character_id)
	piece.topic_ids = [1, 2]
	_author.topic_pool = [3]
	assert_false(TheaterSystem.can_dedicate(_author.character_id, piece, 3, _author))


func test_can_dedicate_duplicate_topic() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.known_by.append(_author.character_id)
	piece.topic_ids = [5]
	_author.topic_pool = [5]
	assert_false(TheaterSystem.can_dedicate(_author.character_id, piece, 5, _author))


# ============================================================================
# DEGRADATION
# ============================================================================

func test_degradation_halves_progress() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_wip(1, 2)
	p.craft_progress = 10
	p.ic_day_last_composition_ap = 0
	pieces.append(p)
	# Process at day 91 (past one full season)
	TheaterSystem.process_degradation(pieces, 91)
	assert_eq(p.craft_progress, 5)


func test_degradation_skips_completed_piece() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_piece(1, 2)
	p.craft_progress = -1
	pieces.append(p)
	TheaterSystem.process_degradation(pieces, 91)
	assert_eq(p.craft_progress, -1)


func test_degradation_skips_recent_work() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_wip(1, 2)
	p.craft_progress = 10
	p.ic_day_last_composition_ap = 80
	pieces.append(p)
	TheaterSystem.process_degradation(pieces, 91)
	assert_eq(p.craft_progress, 10)


# ============================================================================
# HANDLE_CHARACTER_DEATH
# ============================================================================

func test_death_removes_from_known_by() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_piece(1, 2)
	p.known_by = [1, 2]
	pieces.append(p)
	TheaterSystem.handle_character_death(1, pieces)
	assert_false(1 in p.known_by)
	assert_true(2 in p.known_by)


func test_death_marks_private_piece_lost_when_no_known_by() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_piece(1, 2)
	p.canonized = false
	p.known_by = [1]
	pieces.append(p)
	TheaterSystem.handle_character_death(1, pieces)
	assert_true(p.lost)


func test_death_leaves_canonized_piece_intact() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_piece(1, 2)
	p.canonized = true
	p.known_by = [1]
	pieces.append(p)
	TheaterSystem.handle_character_death(1, pieces)
	assert_false(p.lost)


func test_death_abandons_wip_if_author_dies() -> void:
	var pieces: Array[TheaterPieceData] = []
	var p: TheaterPieceData = _make_wip(1, 2)
	p.author_id = 1
	p.craft_progress = 5
	pieces.append(p)
	TheaterSystem.handle_character_death(1, pieces)
	assert_true(p.abandoned_incomplete)


# ============================================================================
# GENERATE_CANONIZED_PIECES (world start)
# ============================================================================

func test_generate_canonized_pieces_produces_results() -> void:
	var next_id: Array[int] = [1]
	var pieces: Array[TheaterPieceData] = TheaterSystem.generate_canonized_pieces(
		_dice, next_id, 0,
	)
	assert_gt(pieces.size(), 0)


func test_generate_canonized_pieces_all_canonized() -> void:
	var next_id: Array[int] = [1]
	var pieces: Array[TheaterPieceData] = TheaterSystem.generate_canonized_pieces(
		_dice, next_id, 0,
	)
	for piece: TheaterPieceData in pieces:
		assert_true(piece.canonized)
		assert_eq(piece.craft_progress, -1)


func test_generate_canonized_pieces_ids_unique() -> void:
	var next_id: Array[int] = [1]
	var pieces: Array[TheaterPieceData] = TheaterSystem.generate_canonized_pieces(
		_dice, next_id, 0,
	)
	var ids: Dictionary = {}
	for piece: TheaterPieceData in pieces:
		assert_false(piece.piece_id in ids)
		ids[piece.piece_id] = true


func test_generate_canonized_pieces_crane_has_most() -> void:
	var next_id: Array[int] = [1]
	var pieces: Array[TheaterPieceData] = TheaterSystem.generate_canonized_pieces(
		_dice, next_id, 0,
	)
	var crane_count: int = 0
	var crab_count: int = 0
	for piece: TheaterPieceData in pieces:
		if piece.subject.begins_with("Crane"):
			crane_count += 1
		elif piece.subject.begins_with("Crab"):
			crab_count += 1
	assert_ge(crane_count, crab_count)


# ============================================================================
# APPLY_COMPLETION_RAISES
# ============================================================================

func test_apply_completion_raises_magnitude() -> void:
	var p: TheaterPieceData = _make_piece(1, 2)
	p.disposition_magnitude = 2
	TheaterSystem.apply_completion_raises(p, 1, -1, -1, 1, 0)
	assert_eq(p.disposition_magnitude, 3)


func test_apply_completion_raises_adds_topic() -> void:
	var p: TheaterPieceData = _make_piece(1, 2)
	p.topic_ids = []
	TheaterSystem.apply_completion_raises(p, 2, 99, -1, 0, 0)
	assert_true(99 in p.topic_ids)


# ============================================================================
# HELPERS
# ============================================================================

func _make_piece(piece_id: int, magnitude: int) -> TheaterPieceData:
	var p := TheaterPieceData.new()
	p.piece_id = piece_id
	p.title = "Test Piece"
	p.style = TheaterSystem.Style.NOH
	p.author_id = _author.character_id
	p.subject = "Crane"
	p.subject_type = TheaterSystem.SubjectType.CLAN
	p.framing = true
	p.disposition_magnitude = magnitude
	p.target_magnitude = magnitude
	p.topic_weight = 1
	p.target_topic_weight = 1
	p.num_roles_declared = 1
	p.craft_progress = -1
	p.canonized = false
	var role := TheaterSystem.make_role(0, "Crane", TheaterSystem.SubjectType.CLAN, true)
	p.roles = [role]
	return p


func _make_wip(piece_id: int, magnitude: int) -> TheaterPieceData:
	var p: TheaterPieceData = _make_piece(piece_id, magnitude)
	p.craft_progress = 0
	p.canonized = false
	return p


# ============================================================================
# AUTHORSHIP GLORY (s57.22.2)
# ============================================================================

func test_authorship_glory_constant_value() -> void:
	assert_eq(TheaterSystem.AUTHORSHIP_GLORY, 0.1)


func test_authorship_glory_wired_in_perform_writeback() -> void:
	# A piece by author_id=1; performer is char_id=2.
	# After perform writeback, author should gain +0.1 Glory.
	var piece: TheaterPieceData = _make_piece(10, 1)
	piece.known_by = [1, 2]
	piece.author_id = 1

	var author: L5RCharacterData = L5RCharacterData.new()
	author.character_id = 1
	author.glory = 3.0
	author.clan = "Crane"

	var performer: L5RCharacterData = L5RCharacterData.new()
	performer.character_id = 2
	performer.clan = "Lion"
	performer.skills = {"Acting": 3}
	performer.awareness = 3
	performer.agility = 2
	performer.physical_location = "crane_castle"

	var chars: Dictionary = {1: author, 2: performer}
	var topics: Array = []
	var next_tid: Array[int] = [1]
	var pieces: Array = [piece]

	var results: Array = [{
		"action_id": "PERFORM_THEATER_PIECE",
		"character_id": 2,
		"success": true,
		"effects": {
			"piece_id": 10,
			"is_bunraku_performance": false,
			"raises_succeeded": 0,
			"is_critical": false,
			"location_id": "crane_castle",
		},
	}]

	DayOrchestrator._process_perform_theater_writebacks(
		results, pieces, chars, topics, next_tid, 1,
	)
	assert_almost_eq(author.glory, 3.1, 0.001)


# ============================================================================
# TOPIC ID PURGE (s57.22.2)
# ============================================================================

func test_purge_stale_removes_resolved_topic() -> void:
	var piece: TheaterPieceData = _make_piece(1, 2)
	piece.topic_ids = [5, 6]

	# topic 5 is resolved, topic 6 is active
	var resolved_t: TopicData = TopicData.new()
	resolved_t.topic_id = 5
	resolved_t.resolved = true

	var active_t: TopicData = TopicData.new()
	active_t.topic_id = 6
	active_t.resolved = false

	var active_topics: Array = [resolved_t, active_t]
	TheaterSystem.purge_stale_topic_ids([piece], active_topics)
	assert_false(5 in piece.topic_ids)
	assert_true(6 in piece.topic_ids)


func test_purge_stale_removes_absent_topic() -> void:
	# topic_id 99 never existed in active_topics
	var piece: TheaterPieceData = _make_piece(2, 2)
	piece.topic_ids = [99]
	TheaterSystem.purge_stale_topic_ids([piece], [])
	assert_true(piece.topic_ids.is_empty())


# ============================================================================
# §57.22.12 COMPOSE_THEATER_PIECE SCORING MODIFIERS
# ============================================================================

func test_compose_not_at_court_bonus() -> void:
	# When context_flag is not AT_COURT, COMPOSE_THEATER_PIECE should receive +20
	var engine: NPCDecisionEngine = NPCDecisionEngine.new()
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.clan = "Crane"
	ctx.context_flag = "AT_OWN_HOLDINGS"
	ctx.skill_ranks = {"Poetry": 2}
	ctx.characters_present = [2]  # one other character for audience
	ctx.known_topic_momentums = {}
	ctx.known_topic_subjects = {}
	ctx.known_objectives = {}

	var option: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	option.action_id = "COMPOSE_THEATER_PIECE"
	option.objective_alignment = 60.0
	option.disposition_modifier = 0.0
	option.metadata = {"subject": "Crane", "subject_type": TheaterSystem.SubjectType.CLAN, "is_new": true}

	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DAMAGE_RELATIONSHIP"
	need.target_npc_id = -1
	need.target_intent = ""

	NPCDecisionEngine.score_all([option], need, ctx, {})
	# +20 for not AT_COURT should be in disposition_modifier
	assert_almost_eq(option.disposition_modifier, 20.0, 0.001)


func test_compose_at_court_no_pieces_score_40() -> void:
	# When AT_COURT and no viable pieces, objective_alignment overrides to 40
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.clan = "Crane"
	ctx.context_flag = "AT_COURT"
	ctx.skill_ranks = {"Poetry": 2}
	ctx.characters_present = [2]
	ctx.known_topic_momentums = {}
	ctx.known_topic_subjects = {}
	ctx.known_objectives = {"theater_pieces_to_perform": []}

	var option: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	option.action_id = "COMPOSE_THEATER_PIECE"
	option.objective_alignment = 60.0
	option.disposition_modifier = 0.0
	option.metadata = {"subject": "Crane", "subject_type": TheaterSystem.SubjectType.CLAN, "is_new": true}

	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DAMAGE_RELATIONSHIP"
	need.target_npc_id = -1
	need.target_intent = ""

	NPCDecisionEngine.score_all([option], need, ctx, {})
	assert_almost_eq(option.objective_alignment, 40.0, 0.001)


func test_compose_no_audience_penalty() -> void:
	# No co-located characters → -20 disposition_modifier
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.clan = "Crane"
	ctx.context_flag = "AT_OWN_HOLDINGS"
	ctx.skill_ranks = {"Poetry": 2}
	ctx.characters_present = []  # no audience
	ctx.known_topic_momentums = {}
	ctx.known_topic_subjects = {}
	ctx.known_objectives = {}

	var option: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	option.action_id = "COMPOSE_THEATER_PIECE"
	option.objective_alignment = 60.0
	option.disposition_modifier = 0.0
	option.metadata = {"subject": "Crane", "subject_type": TheaterSystem.SubjectType.CLAN, "is_new": true}

	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DAMAGE_RELATIONSHIP"
	need.target_npc_id = -1
	need.target_intent = ""

	NPCDecisionEngine.score_all([option], need, ctx, {})
	# +20 not AT_COURT, -20 no audience → net 0
	assert_almost_eq(option.disposition_modifier, 0.0, 0.001)


# ============================================================================
# §57.22.13 POLITICAL RAISES AT COMPLETION
# ============================================================================

func test_political_need_type_stored_on_new_piece() -> void:
	var piece: TheaterPieceData = TheaterPieceData.new()
	piece.political_need_type = "DAMAGE_RELATIONSHIP"
	assert_eq(piece.political_need_type, "DAMAGE_RELATIONSHIP")


func test_political_raises_topic_linkage_at_completion() -> void:
	# Piece completes with 2 raises, political_need_type set, matching topic exists.
	# Expect the matching topic to be linked.
	var piece: TheaterPieceData = _make_wip(20, 1)
	piece.political_need_type = "DAMAGE_RELATIONSHIP"
	piece.craft_progress = 9  # one point from threshold of 10

	var author: L5RCharacterData = L5RCharacterData.new()
	author.character_id = 1
	author.clan = "Crane"
	author.skills = {"Poetry": 2}
	author.topic_pool = [77]

	var active_topic: TopicData = TopicData.new()
	active_topic.topic_id = 77
	active_topic.momentum = 50  # > 40
	active_topic.clan_involved = "Crane"
	active_topic.resolved = false

	var chars: Dictionary = {1: author}
	var pieces: Array = [piece]
	var next_id: Array[int] = [100]

	# Progress of 1 enough to complete (total = 10 >= threshold 10)
	var results: Array = [{
		"action_id": "COMPOSE_THEATER_PIECE",
		"character_id": 1,
		"success": true,
		"effects": {
			"piece_id": piece.piece_id,
			"progress_earned": 1,
			"raises": 2,
		},
	}]

	DayOrchestrator._process_compose_theater_writebacks(
		results, pieces, next_id, chars, 10, [active_topic],
	)

	# Piece should be complete and topic 77 should be linked
	assert_eq(piece.craft_progress, -1)
	assert_true(77 in piece.topic_ids)
