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


# ============================================================================
# §57.22.13 PERFORM_THEATER_PIECE PIECE SELECTION SCORING
# ============================================================================

## Build a minimal ContextSnapshot for piece selection tests.
## performer_id=1, location="loc_a", ic_day=100 by default.
func _make_perform_ctx(performer_id: int = 1) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = performer_id
	ctx.clan = "Crane"
	ctx.location_id = "loc_a"
	ctx.ic_day = 100
	ctx.status = 2.0
	ctx.characters_present = []
	ctx.disposition_values = {}
	ctx.known_contacts = []
	ctx.known_contacts_by_clan = {}
	ctx.contact_clans = {}
	ctx.known_topics = []
	ctx.known_topic_momentums = {}
	ctx.action_log = []
	ctx.known_objectives = {}
	return ctx


## Build a minimal witness L5RCharacterData.
func _make_witness(char_id: int, loc: String = "loc_a") -> L5RCharacterData:
	var w := L5RCharacterData.new()
	w.character_id = char_id
	w.clan = "Lion"
	w.family = "Matsu"
	w.physical_location = loc
	w.status = 1.0
	w.wounds_taken = 0
	w.pieces_seen = {}
	w.disposition_values = {}
	return w


## Inject piece + pieces_by_id into ctx.known_objectives and return chars_by_id.
func _inject_piece(
	ctx: NPCDataStructures.ContextSnapshot,
	piece: TheaterPieceData,
	witnesses: Array,
) -> Dictionary:
	ctx.known_objectives["theater_pieces_to_perform"] = [piece.piece_id]
	ctx.known_objectives["_theater_pieces_by_id"] = {piece.piece_id: piece}
	var chars_by_id: Dictionary = {}
	for w: L5RCharacterData in witnesses:
		chars_by_id[w.character_id] = w
		ctx.characters_present.append(w.character_id)
	return chars_by_id


func test_piece_selection_returns_piece_id_for_viable_piece() -> void:
	# One non-immune witness, performer knows piece → base 50, -30 (<3 witnesses) = 20 > 0.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(10, 2)
	piece.known_by = [1]  # performer knows it
	var w1 := _make_witness(2)
	var chars_by_id := _inject_piece(ctx, piece, [w1])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 10)


func test_piece_selection_hard_gate_zero_non_immune_witnesses() -> void:
	# All witnesses are in known_by → permanent immunity → hard gate → piece_id -1.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(11, 2)
	var w1 := _make_witness(2)
	piece.known_by = [1, 2]  # both performer and witness know it
	var chars_by_id := _inject_piece(ctx, piece, [w1])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], -1)


func test_piece_selection_hard_gate_30_day_immunity_window() -> void:
	# Witness saw piece 20 days ago (within 30-day window) → immune → hard gate.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(12, 2)
	piece.known_by = [1]
	var w1 := _make_witness(2)
	w1.pieces_seen[12] = 85  # ic_day 100 - 85 = 15 days ago → immune
	var chars_by_id := _inject_piece(ctx, piece, [w1])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], -1)


func test_piece_selection_immunity_window_expired() -> void:
	# Witness saw piece 31 days ago → immunity expired → piece selectable.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(13, 2)
	piece.known_by = [1]
	var w1 := _make_witness(2)
	w1.pieces_seen[13] = 69  # ic_day 100 - 69 = 31 days ago → expired
	var chars_by_id := _inject_piece(ctx, piece, [w1])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 13)


func test_piece_selection_hard_gate_insufficient_colocated_knowers() -> void:
	# Piece has 2 roles, only performer (1 knower) present → gate: need >= 2.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(14, 2)
	piece.known_by = [1]
	# Add a second role to require 2 co-located knowers.
	piece.roles = [
		TheaterSystem.make_role(0, "Crane", TheaterSystem.SubjectType.CLAN, true),
		TheaterSystem.make_role(1, "Lion", TheaterSystem.SubjectType.CLAN, false),
	]
	var w1 := _make_witness(2)  # not in known_by → only 1 knower (performer)
	var chars_by_id := _inject_piece(ctx, piece, [w1])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], -1)


func test_piece_selection_hard_gate_bunraku_needs_3_knowers() -> void:
	# Bunraku piece with only 2 co-located knowers → hard gate.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(15, 2)
	piece.style = TheaterSystem.Style.BUNRAKU
	var knower2 := _make_witness(2)
	piece.known_by = [1, 2]  # only 2 knowers present
	var w_non_knower := _make_witness(3)
	var chars_by_id := _inject_piece(ctx, piece, [knower2, w_non_knower])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], -1)


func test_piece_selection_bunraku_passes_with_3_knowers() -> void:
	# Bunraku piece with 3 co-located knowers and 1 non-immune witness → selectable.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(16, 2)
	piece.style = TheaterSystem.Style.BUNRAKU
	var k2 := _make_witness(2)
	var k3 := _make_witness(3)
	piece.known_by = [1, 2, 3]
	var non_knower := _make_witness(4)
	var chars_by_id := _inject_piece(ctx, piece, [k2, k3, non_knower])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 16)


func test_piece_selection_topic_momentum_bonus() -> void:
	# Two pieces: piece A has linked topic with momentum 35 (+30), piece B is base only.
	# With 3 witnesses each: A = 50+30 = 80, B = 50. A wins.
	var ctx := _make_perform_ctx()

	var piece_a := _make_piece(20, 2)
	piece_a.known_by = [1]
	piece_a.topic_ids = [99]

	var piece_b := _make_piece(21, 2)
	piece_b.known_by = [1]

	ctx.known_topics = [99]
	ctx.known_topic_momentums = {99: 35}  # > 30

	# 3 non-immune witnesses for each piece.
	var w2 := _make_witness(2)
	var w3 := _make_witness(3)
	var w4 := _make_witness(4)

	ctx.known_objectives["theater_pieces_to_perform"] = [20, 21]
	ctx.known_objectives["_theater_pieces_by_id"] = {20: piece_a, 21: piece_b}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 20)


func test_piece_selection_low_momentum_no_bonus() -> void:
	# Topic momentum exactly 30 (not > 30) → no bonus.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(22, 2)
	piece.known_by = [1]
	piece.topic_ids = [88]
	ctx.known_topics = [88]
	ctx.known_topic_momentums = {88: 30}  # exactly 30, not > 30

	var w2 := _make_witness(2)
	var w3 := _make_witness(3)
	var w4 := _make_witness(4)
	var chars_by_id := _inject_piece(ctx, piece, [w2, w3, w4])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	# Score = 50 (no -30 since 3+ witnesses). Topic bonus must NOT add +30.
	# Score of exactly 50 → selectable.
	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 22)
	# Verify no extra topic boost by checking against a piece with high momentum.
	# (Selection itself proves the piece was viable at base score.)


func test_piece_selection_majority_aligned_bonus() -> void:
	# 2 of 3 witnesses aligned with framing (>50%) → +20.
	# Two pieces; aligned piece wins.
	var ctx := _make_perform_ctx()

	var piece_aligned := _make_piece(30, 2)
	piece_aligned.known_by = [1]
	piece_aligned.framing = true  # positive framing
	piece_aligned.roles = [TheaterSystem.make_role(0, "10", TheaterSystem.SubjectType.CHARACTER, true)]

	var piece_plain := _make_piece(31, 2)
	piece_plain.known_by = [1]

	# Subject character_id=10, framing=true → witnesses who like char 10 (disp >= 11) align.
	var w2 := _make_witness(2)
	w2.disposition_values = {10: 20}  # likes subject → aligned
	var w3 := _make_witness(3)
	w3.disposition_values = {10: 20}  # aligned
	var w4 := _make_witness(4)
	w4.disposition_values = {10: -5}  # neutral → not aligned

	ctx.known_objectives["theater_pieces_to_perform"] = [30, 31]
	ctx.known_objectives["_theater_pieces_by_id"] = {30: piece_aligned, 31: piece_plain}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 30)


func test_piece_selection_strong_npc_disposition_bonus() -> void:
	# NPC has strong disposition (≥+11) toward piece subject → +20.
	# Piece A: NPC disp 20 toward subject → +20. Piece B: no strong disp.
	var ctx := _make_perform_ctx()
	ctx.disposition_values = {42: 20}  # strong positive toward char 42
	ctx.known_contacts_by_clan = {}

	var piece_a := _make_piece(40, 2)
	piece_a.known_by = [1]
	piece_a.roles = [TheaterSystem.make_role(0, "42", TheaterSystem.SubjectType.CHARACTER, true)]

	var piece_b := _make_piece(41, 2)
	piece_b.known_by = [1]
	# plain Crane CLAN subject with no strong contacts

	var w2 := _make_witness(2)
	var w3 := _make_witness(3)
	var w4 := _make_witness(4)

	ctx.known_objectives["theater_pieces_to_perform"] = [40, 41]
	ctx.known_objectives["_theater_pieces_by_id"] = {40: piece_a, 41: piece_b}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 40)


func test_piece_selection_author_bonus() -> void:
	# Piece authored by NPC → +15. Two pieces; authored piece wins over anonymous.
	var ctx := _make_perform_ctx(1)  # performer_id = 1

	var piece_authored := _make_piece(50, 2)
	piece_authored.author_id = 1  # is author
	piece_authored.known_by = [1]

	var piece_other := _make_piece(51, 2)
	piece_other.author_id = 99  # someone else
	piece_other.known_by = [1]

	var w2 := _make_witness(2)
	var w3 := _make_witness(3)
	var w4 := _make_witness(4)

	ctx.known_objectives["theater_pieces_to_perform"] = [50, 51]
	ctx.known_objectives["_theater_pieces_by_id"] = {50: piece_authored, 51: piece_other}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 50)


func test_piece_selection_author_already_performed_penalty() -> void:
	# Author already performed the piece today (-20 on top of +15 = net -5 vs base).
	# Two pieces: piece A authored+already-performed, piece B authored-only.
	# piece A score: 50+15-20-30=15 (1 witness), piece B score: 50+15-30=35 (1 witness). B wins.
	var ctx := _make_perform_ctx(1)
	ctx.action_log = [{
		"action_id": "PERFORM_THEATER_PIECE",
		"metadata": {"piece_id": 60},
	}]

	var piece_a := _make_piece(60, 2)
	piece_a.author_id = 1
	piece_a.known_by = [1]

	var piece_b := _make_piece(61, 2)
	piece_b.author_id = 1
	piece_b.known_by = [1]

	var w2 := _make_witness(2)

	ctx.known_objectives["theater_pieces_to_perform"] = [60, 61]
	ctx.known_objectives["_theater_pieces_by_id"] = {60: piece_a, 61: piece_b}
	ctx.characters_present = [2]
	var chars_by_id: Dictionary = {2: w2}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 61)


func test_piece_selection_majority_immune_penalty() -> void:
	# 2 of 3 non-known_by witnesses are immune (>50%) → -25.
	# Piece A: majority immune. Piece B: no immunity. B wins.
	var ctx := _make_perform_ctx()

	var piece_a := _make_piece(70, 2)
	piece_a.known_by = [1]

	var piece_b := _make_piece(71, 2)
	piece_b.known_by = [1]

	var w2 := _make_witness(2)
	w2.pieces_seen[70] = 90  # saw piece A 10 days ago → immune
	var w3 := _make_witness(3)
	w3.pieces_seen[70] = 90  # immune too (2 of 3 > 50%)
	var w4 := _make_witness(4)
	# w4 not immune for piece A

	ctx.known_objectives["theater_pieces_to_perform"] = [70, 71]
	ctx.known_objectives["_theater_pieces_by_id"] = {70: piece_a, 71: piece_b}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	# Piece A: 50 - 25 (majority immune) - 30 (only 1 non-immune) = -5 → piece_id = -1 for A
	# Piece B: 50 (3 witnesses, none immune) → B wins.
	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 71)


func test_piece_selection_fewer_than_3_witnesses_penalty() -> void:
	# Only 2 non-immune witnesses → -30. Score = 50 - 30 = 20 > 0 → still selected.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(80, 2)
	piece.known_by = [1]

	var w2 := _make_witness(2)
	var w3 := _make_witness(3)
	var chars_by_id := _inject_piece(ctx, piece, [w2, w3])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 80)


func test_piece_selection_high_value_witness_bonus() -> void:
	# One witness has Status >= 3 (+15). Two pieces; piece with high-value witness wins.
	var ctx := _make_perform_ctx()

	var piece_hvw := _make_piece(90, 2)
	piece_hvw.known_by = [1]

	var piece_plain := _make_piece(91, 2)
	piece_plain.known_by = [1]

	# High-value witness (Status 3.0) only for piece_hvw (not immune to it).
	var w2 := _make_witness(2)
	w2.status = 3.5
	w2.pieces_seen[91] = 95  # immune to piece_plain

	var w3 := _make_witness(3)
	var w4 := _make_witness(4)

	ctx.known_objectives["theater_pieces_to_perform"] = [90, 91]
	ctx.known_objectives["_theater_pieces_by_id"] = {90: piece_hvw, 91: piece_plain}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	# piece_hvw: 50 + 15 (high-value w2) = 65
	# piece_plain: 50 (w2 is immune, only w3+w4 non-immune, so 2 witnesses → -30 = 20)
	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 90)


func test_piece_selection_score_zero_or_below_returns_minus_one() -> void:
	# Score at or below 0 → piece_id -1.
	# 1 witness (no -30 offset) + majority immune -25 + author already performed -5 net.
	# Actually simplest: 1 witness → 50 - 30 = 20. Need something that pushes to 0.
	# Use majority immune (-25) + author already performed today (-5 net from +15-20).
	# Score: 50 + 15 (author) - 20 (already performed) - 25 (majority immune) - 30 (<3 witnesses) = -10 ≤ 0.
	var ctx := _make_perform_ctx(1)
	ctx.action_log = [{"action_id": "PERFORM_THEATER_PIECE", "metadata": {"piece_id": 100}}]

	var piece := _make_piece(100, 2)
	piece.author_id = 1
	piece.known_by = [1]

	var w2 := _make_witness(2)
	w2.pieces_seen[100] = 95  # immune (5 days ago)
	var w3 := _make_witness(3)
	w3.pieces_seen[100] = 95  # immune (2 of 2 non-knowers → >50% immune)

	# Only 1 non-immune non-knower needed to pass hard gate 1.
	# But we need at least 1. Let's add a 3rd witness who is non-immune.
	var w4 := _make_witness(4)
	# w4 is not immune → non_immune_count = 1 → hard gate passes
	# majority immune: 2 immune / 3 total = 66% > 50% → -25

	var chars_by_id := _inject_piece(ctx, piece, [w2, w3, w4])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], -1)


func test_piece_selection_kyogen_subject_present_bonus() -> void:
	# Kyogen piece: subject (CHARACTER id=5) is in zone → +25.
	var ctx := _make_perform_ctx()
	ctx.status = 3.0  # performer status >= subject status → no -40

	var piece := _make_piece(110, 2)
	piece.style = TheaterSystem.Style.KYOGEN
	piece.known_by = [1]
	piece.roles = [TheaterSystem.make_role(0, "5", TheaterSystem.SubjectType.CHARACTER, false)]

	var subject_char := _make_witness(5)
	subject_char.status = 2.0  # subject status < performer (3.0) → no -40
	var non_subject := _make_witness(2)
	var chars_by_id := _inject_piece(ctx, piece, [subject_char, non_subject])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	# subject is present (char_id=5 in characters_present) → +25
	# 2 witnesses (non-immune) → -30 (<3)
	# Score = 50 + 25 - 30 = 45 > 0 → selected.
	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 110)


func test_piece_selection_kyogen_higher_status_penalty() -> void:
	# Kyogen: subject has higher Status than performer, no pretext → -40.
	# With no pretext and subject Status 5 > performer Status 2:
	# score = 50 - 30 (<3 witnesses) - 40 = -20 ≤ 0 → piece_id -1.
	var ctx := _make_perform_ctx()
	ctx.status = 2.0  # performer status

	var piece := _make_piece(120, 2)
	piece.style = TheaterSystem.Style.KYOGEN
	piece.known_by = [1]
	piece.roles = [TheaterSystem.make_role(0, "6", TheaterSystem.SubjectType.CHARACTER, false)]

	var subject_char := _make_witness(6)
	subject_char.status = 5.0  # higher than performer
	# No enemy disposition toward performer → no pretext.
	var non_subject := _make_witness(2)
	var chars_by_id := _inject_piece(ctx, piece, [subject_char, non_subject])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], -1)


func test_piece_selection_kyogen_pretext_negates_status_penalty() -> void:
	# Kyogen: subject has higher Status but holds Enemy disp (≤-51) toward performer.
	# Pretext exists → -40 is NOT applied.
	var ctx := _make_perform_ctx(1)
	ctx.status = 2.0

	var piece := _make_piece(130, 2)
	piece.style = TheaterSystem.Style.KYOGEN
	piece.known_by = [1]
	piece.roles = [TheaterSystem.make_role(0, "7", TheaterSystem.SubjectType.CHARACTER, false)]

	var subject_char := _make_witness(7)
	subject_char.status = 5.0  # higher Status
	subject_char.disposition_values = {1: -55}  # Enemy disp toward performer → pretext

	var non_subject := _make_witness(2)
	var chars_by_id := _inject_piece(ctx, piece, [subject_char, non_subject])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	# Score = 50 - 30 (<3 witnesses) = 20 > 0 → selected (no -40 due to pretext).
	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 130)


func test_piece_selection_seek_glory_sets_raises() -> void:
	# SEEK_GLORY need_type → raises = 1 in returned metadata.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(140, 2)
	piece.known_by = [1]
	var w2 := _make_witness(2)
	var chars_by_id := _inject_piece(ctx, piece, [w2])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["raises"], 1)


func test_piece_selection_non_glory_need_no_raises() -> void:
	# Non-SEEK_GLORY need → raises = 0.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(141, 2)
	piece.known_by = [1]
	var w2 := _make_witness(2)
	var chars_by_id := _inject_piece(ctx, piece, [w2])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DAMAGE_RELATIONSHIP"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["raises"], 0)


func test_piece_selection_bunraku_sets_is_bunraku_flag() -> void:
	# Best piece is Bunraku → is_bunraku_performance = true.
	var ctx := _make_perform_ctx()
	var piece := _make_piece(150, 2)
	piece.style = TheaterSystem.Style.BUNRAKU
	var k2 := _make_witness(2)
	var k3 := _make_witness(3)
	piece.known_by = [1, 2, 3]  # 3 knowers
	var non_knower := _make_witness(4)
	var chars_by_id := _inject_piece(ctx, piece, [k2, k3, non_knower])

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 150)
	assert_true(result["is_bunraku_performance"])


func test_piece_selection_best_scoring_piece_wins() -> void:
	# Multiple pieces; highest score wins.
	# Piece A: base only (50). Piece B: +30 topic + 3 witnesses (50+30=80). B wins.
	var ctx := _make_perform_ctx()
	ctx.known_topics = [55]
	ctx.known_topic_momentums = {55: 40}

	var piece_a := _make_piece(160, 2)
	piece_a.known_by = [1]

	var piece_b := _make_piece(161, 2)
	piece_b.known_by = [1]
	piece_b.topic_ids = [55]

	var w2 := _make_witness(2)
	var w3 := _make_witness(3)
	var w4 := _make_witness(4)

	ctx.known_objectives["theater_pieces_to_perform"] = [160, 161]
	ctx.known_objectives["_theater_pieces_by_id"] = {160: piece_a, 161: piece_b}
	ctx.characters_present = [2, 3, 4]
	var chars_by_id: Dictionary = {2: w2, 3: w3, 4: w4}

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_GLORY"

	var result: Dictionary = NPCDecisionEngine._build_perform_theater_metadata(ctx, need, chars_by_id)
	assert_eq(result["piece_id"], 161)


# ============================================================================
# §57.22.11 ARTISTIC_EXPRESSION — compose metadata
# ============================================================================

func _make_art_ctx(
	char_id: int = 1,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.JIN,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
	school: Enums.SchoolType = Enums.SchoolType.COURTIER,
	poetry: int = 3,
	acting: int = 2,
) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = char_id
	ctx.clan = "Crane"
	ctx.location_id = "loc_a"
	ctx.bushido_virtue = bushido
	ctx.shourido_virtue = shourido
	ctx.school_type = school
	ctx.skill_ranks = {"Poetry": poetry, "Acting": acting}
	ctx.disposition_values = {}
	ctx.known_topics = []
	ctx.known_objectives = {}
	ctx.action_log = []
	return ctx


func test_artistic_expression_metadata_framing_positive_from_disposition() -> void:
	# Strongest disposition positive → framing = true, subject = str(target_id).
	var ctx := _make_art_ctx()
	ctx.disposition_values = {42: 15.0, 43: -5.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_true(result["framing"])
	assert_eq(result["subject"], "42")
	assert_eq(result["subject_type"], TheaterSystem.SubjectType.CHARACTER)
	assert_eq(result["piece_id"], -1)
	assert_true(result["is_new"])


func test_artistic_expression_metadata_framing_negative_from_disposition() -> void:
	# Strongest disposition negative → framing = false.
	var ctx := _make_art_ctx()
	ctx.disposition_values = {42: -20.0, 43: 5.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_false(result["framing"])
	assert_eq(result["subject"], "42")


func test_artistic_expression_metadata_no_dispositions_falls_back_to_clan() -> void:
	# No disposition values → subject falls back to clan, subject_type = CLAN.
	var ctx := _make_art_ctx()
	ctx.disposition_values = {}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 1)
	assert_eq(result["subject"], "Crane")
	assert_eq(result["subject_type"], TheaterSystem.SubjectType.CLAN)
	assert_true(result["framing"])  # neutral/positive default


func test_artistic_expression_style_jin_selects_noh() -> void:
	# JIN virtue → NOH style.
	var ctx := _make_art_ctx(1, Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE, Enums.SchoolType.COURTIER)
	ctx.disposition_values = {42: 15.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_eq(result["style"], TheaterSystem.Style.NOH)


func test_artistic_expression_style_seigyo_selects_kabuki() -> void:
	# SEIGYO virtue → KABUKI style.
	var ctx := _make_art_ctx(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO, Enums.SchoolType.COURTIER)
	ctx.disposition_values = {42: 15.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_eq(result["style"], TheaterSystem.Style.KABUKI)


func test_artistic_expression_style_satirical_negative_selects_kyogen() -> void:
	# Manipulation >= 3 + negative framing (strongest disp < 0) → KYOGEN.
	var ctx := _make_art_ctx(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE, Enums.SchoolType.COURTIER)
	ctx.skill_ranks["Manipulation"] = 3
	ctx.disposition_values = {42: -20.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_eq(result["style"], TheaterSystem.Style.KYOGEN)
	assert_false(result["framing"])


func test_artistic_expression_style_satirical_positive_rejects_kyogen() -> void:
	# Deceit >= 3 but framing is positive → KYOGEN rejected, falls through to NOH.
	var ctx := _make_art_ctx(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE, Enums.SchoolType.BUSHI)
	ctx.skill_ranks["Deceit"] = 3
	ctx.disposition_values = {42: 15.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	# KYOGEN rejected because framing=true; BUSHI school default = NOH.
	assert_eq(result["style"], TheaterSystem.Style.NOH)
	assert_true(result["framing"])


func test_artistic_expression_two_roles_when_conditions_met() -> void:
	# ISHI + Acting >= 3 + second distinct strong disposition → num_roles = 2.
	var ctx := _make_art_ctx(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI, Enums.SchoolType.COURTIER, 3, 3)
	ctx.disposition_values = {42: 20.0, 43: 15.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_eq(result["num_roles"], 2)
	assert_true(result.has("subject_2"))


func test_artistic_expression_one_role_when_acting_too_low() -> void:
	# ISHI but Acting < 3 → num_roles = 1.
	var ctx := _make_art_ctx(1, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI, Enums.SchoolType.COURTIER, 3, 2)
	ctx.disposition_values = {42: 20.0, 43: 15.0}

	var result: Dictionary = NPCDecisionEngine._build_artistic_expression_compose_metadata(ctx, 2)
	assert_eq(result["num_roles"], 1)
	assert_false(result.has("subject_2"))


func test_artistic_expression_routing_via_build_compose_metadata() -> void:
	# ARTISTIC_EXPRESSION need_type routes through to _build_artistic_expression_compose_metadata.
	var ctx := _make_art_ctx()
	ctx.disposition_values = {42: 20.0}
	ctx.known_objectives["wip_piece_ids"] = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "ARTISTIC_EXPRESSION"

	var result: Dictionary = NPCDecisionEngine._build_compose_theater_metadata(ctx, need)
	assert_true(result["is_new"])
	assert_eq(result["piece_id"], -1)
	assert_true(result.has("style"))  # only set by _build_artistic_expression_compose_metadata


# ============================================================================
# §57.22.6 LEARN_THEATER_PIECE metadata scoring
# ============================================================================

func _make_canonized_piece(pid: int, magnitude: int, topic_ids: Array[int] = []) -> TheaterPieceData:
	var p := _make_piece(pid, magnitude)
	p.canonized = true
	p.known_by = []
	p.topic_ids = topic_ids
	return p


func _make_private_piece(pid: int, magnitude: int, author_id: int) -> TheaterPieceData:
	var p := _make_piece(pid, magnitude)
	p.canonized = false
	p.author_id = author_id
	p.known_by = [author_id]
	p.topic_ids = []
	return p


func _make_learn_ctx(
	char_id: int = 10,
	learnable_ids: Array = [],
	pieces_by_id: Dictionary = {},
	topic_momentums: Dictionary = {},
	dispositions: Dictionary = {},
	known_topics: Array = [],
) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = char_id
	ctx.clan = "Lion"
	ctx.disposition_values = dispositions
	ctx.known_topics = known_topics
	ctx.known_topic_momentums = topic_momentums
	ctx.known_objectives = {
		"learnable_piece_ids": learnable_ids,
		"_theater_pieces_by_id": pieces_by_id,
	}
	ctx.skill_ranks = {}
	ctx.action_log = []
	return ctx


func test_learn_theater_no_learnable_pieces_returns_minus_one() -> void:
	var ctx := _make_learn_ctx(10, [], {})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	assert_eq(result["piece_id"], -1)


func test_learn_theater_selects_only_piece_when_one_available() -> void:
	var piece: TheaterPieceData = _make_canonized_piece(5, 2)
	var ctx := _make_learn_ctx(10, [5], {5: piece})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	assert_eq(result["piece_id"], 5)


func test_learn_theater_selects_piece_with_active_topic() -> void:
	# Two pieces: piece 5 has a linked topic with momentum > 30, piece 6 does not.
	var piece_a: TheaterPieceData = _make_canonized_piece(5, 2, [101])
	var piece_b: TheaterPieceData = _make_canonized_piece(6, 2, [])
	var ctx := _make_learn_ctx(
		10, [5, 6], {5: piece_a, 6: piece_b},
		{101: 35},  # topic 101 has momentum 35 > 30
		{},
		[101],
	)
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	assert_eq(result["piece_id"], 5, "Piece with live topic should score higher")


func test_learn_theater_topic_below_threshold_not_bonus() -> void:
	# Topic momentum 25 < 30 → no bonus; pieces tie at 50, first wins.
	var piece_a: TheaterPieceData = _make_canonized_piece(5, 2, [101])
	var piece_b: TheaterPieceData = _make_canonized_piece(6, 2, [])
	var ctx := _make_learn_ctx(
		10, [5, 6], {5: piece_a, 6: piece_b},
		{101: 25},
		{},
		[101],
	)
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	# Both score 50; piece 5 is first → selected (no topic bonus when momentum <= 30).
	assert_eq(result["piece_id"], 5)


func test_learn_theater_selects_piece_with_strong_disposition_subject() -> void:
	# piece 5 → subject "42" with disposition +20 → +20 bonus; piece 6 no subject.
	var piece_a: TheaterPieceData = _make_canonized_piece(5, 2)
	piece_a.subject = "42"
	piece_a.subject_type = TheaterSystem.SubjectType.CHARACTER
	var piece_b: TheaterPieceData = _make_canonized_piece(6, 2)
	piece_b.subject = "Crane"
	piece_b.subject_type = TheaterSystem.SubjectType.CLAN
	var ctx := _make_learn_ctx(10, [5, 6], {5: piece_a, 6: piece_b}, {}, {42: 20.0})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	assert_eq(result["piece_id"], 5, "Piece with strong-disp subject should score higher")


func test_learn_theater_negative_strong_disposition_also_triggers_bonus() -> void:
	# absf(-15) >= 11 → +20 bonus applies regardless of sign.
	var piece_a: TheaterPieceData = _make_canonized_piece(5, 2)
	piece_a.subject = "42"
	piece_a.subject_type = TheaterSystem.SubjectType.CHARACTER
	var piece_b: TheaterPieceData = _make_canonized_piece(6, 2)
	var ctx := _make_learn_ctx(10, [5, 6], {5: piece_a, 6: piece_b}, {}, {42: -15.0})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	assert_eq(result["piece_id"], 5)


func test_learn_theater_weak_disposition_no_bonus() -> void:
	# Disposition +5 < 11 → no bonus; piece 6 ties and wins (same score as piece 5,
	# but piece 6 comes after; first encountered at equal score wins since > not >=).
	var piece_a: TheaterPieceData = _make_canonized_piece(5, 2)
	piece_a.subject = "42"
	piece_a.subject_type = TheaterSystem.SubjectType.CHARACTER
	var piece_b: TheaterPieceData = _make_canonized_piece(6, 2)
	var ctx := _make_learn_ctx(10, [5, 6], {5: piece_a, 6: piece_b}, {}, {42: 5.0})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	# Both score 50; 5 is first in loop → selected (> not >=).
	assert_eq(result["piece_id"], 5)


func test_learn_theater_private_piece_requires_teacher() -> void:
	# Private piece: chars_by_id is empty → find_willing_teacher returns -1 → skipped.
	var piece: TheaterPieceData = _make_private_piece(7, 2, 99)
	var ctx := _make_learn_ctx(10, [7], {7: piece})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need, {})
	assert_eq(result["piece_id"], -1, "Private piece with no teacher should be skipped")


func test_learn_theater_canonized_piece_no_teacher_required() -> void:
	# Canonized pieces don't need a teacher → selected even with empty chars_by_id.
	var piece: TheaterPieceData = _make_canonized_piece(8, 2)
	var ctx := _make_learn_ctx(10, [8], {8: piece})
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need, {})
	assert_eq(result["piece_id"], 8)


func test_learn_theater_highest_score_wins() -> void:
	# Piece A: topic bonus +30 (score 80). Piece B: disp bonus +20 (score 70).
	# Piece A should win.
	var piece_a: TheaterPieceData = _make_canonized_piece(5, 2, [101])
	piece_a.subject = ""
	var piece_b: TheaterPieceData = _make_canonized_piece(6, 2)
	piece_b.subject = "42"
	piece_b.subject_type = TheaterSystem.SubjectType.CHARACTER
	var ctx := _make_learn_ctx(
		10, [5, 6], {5: piece_a, 6: piece_b},
		{101: 40},
		{42: 20.0},
		[101],
	)
	var need := NPCDataStructures.ImmediateNeed.new()
	var result: Dictionary = NPCDecisionEngine._build_learn_theater_metadata(ctx, need)
	assert_eq(result["piece_id"], 5, "Topic bonus (80) beats disp bonus (70)")
