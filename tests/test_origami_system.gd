extends GutTest
## Tests for s57.26 Origami System (noshi, gohei, senbazuru).
## Covers: OrigamiSystem constants/helpers, SenbazuruData.compute_quality,
## ActionExecutor origami executors, DayOrchestrator writebacks,
## NPCDecisionEngine precondition filter, context injection.


var _dice: DiceEngine
var _folder: L5RCharacterData
var _recipient: L5RCharacterData
var _witness: L5RCharacterData


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	_folder = L5RCharacterData.new()
	_folder.character_id = 1
	_folder.clan = "Crane"
	_folder.awareness = 3
	_folder.void_ring = 3
	_folder.void_points = 1
	_folder.honor = 5.0
	_folder.glory = 5.0
	_folder.skills = {"Artisan: Origami": 4}
	_folder.items = []
	_folder.topic_pool = []
	_folder.physical_location = "village_a"

	_recipient = L5RCharacterData.new()
	_recipient.character_id = 2
	_recipient.clan = "Lion"
	_recipient.void_ring = 3
	_recipient.current_void_points = 1
	_recipient.physical_location = "village_a"

	_witness = L5RCharacterData.new()
	_witness.character_id = 3
	_witness.clan = "Scorpion"
	_witness.physical_location = "village_a"


# --------------------------------------------------------------------------
# OrigamiSystem — compute_quality_from_raises
# --------------------------------------------------------------------------

func test_compute_quality_failure_returns_mundane() -> void:
	var result: int = OrigamiSystem.compute_quality_from_raises(2, false)
	assert_eq(result, GiftGivingSystem.QualityTier.MUNDANE)


func test_compute_quality_0_raises_normal() -> void:
	var result: int = OrigamiSystem.compute_quality_from_raises(0, true)
	assert_eq(result, GiftGivingSystem.QualityTier.NORMAL)


func test_compute_quality_1_raise_fine() -> void:
	var result: int = OrigamiSystem.compute_quality_from_raises(1, true)
	assert_eq(result, GiftGivingSystem.QualityTier.FINE)


func test_compute_quality_2_raises_exceptional() -> void:
	var result: int = OrigamiSystem.compute_quality_from_raises(2, true)
	assert_eq(result, GiftGivingSystem.QualityTier.EXCEPTIONAL)


func test_compute_quality_3_raises_masterwork() -> void:
	var result: int = OrigamiSystem.compute_quality_from_raises(3, true)
	assert_eq(result, GiftGivingSystem.QualityTier.MASTERWORK)


func test_compute_quality_4_raises_legendary() -> void:
	var result: int = OrigamiSystem.compute_quality_from_raises(4, true)
	assert_eq(result, GiftGivingSystem.QualityTier.LEGENDARY)


# --------------------------------------------------------------------------
# OrigamiSystem — free_raises_from_tier
# --------------------------------------------------------------------------

func test_free_raises_mundane_zero() -> void:
	assert_eq(OrigamiSystem.free_raises_from_tier(GiftGivingSystem.QualityTier.MUNDANE), 0)


func test_free_raises_normal_zero() -> void:
	assert_eq(OrigamiSystem.free_raises_from_tier(GiftGivingSystem.QualityTier.NORMAL), 0)


func test_free_raises_fine_one() -> void:
	assert_eq(OrigamiSystem.free_raises_from_tier(GiftGivingSystem.QualityTier.FINE), 1)


func test_free_raises_exceptional_two() -> void:
	assert_eq(OrigamiSystem.free_raises_from_tier(GiftGivingSystem.QualityTier.EXCEPTIONAL), 2)


func test_free_raises_masterwork_three() -> void:
	assert_eq(OrigamiSystem.free_raises_from_tier(GiftGivingSystem.QualityTier.MASTERWORK), 3)


func test_free_raises_legendary_four() -> void:
	assert_eq(OrigamiSystem.free_raises_from_tier(GiftGivingSystem.QualityTier.LEGENDARY), 4)


# --------------------------------------------------------------------------
# OrigamiSystem — completion_topic_tier
# --------------------------------------------------------------------------

func test_completion_tier_normal_is_tier4() -> void:
	var tier: int = OrigamiSystem.completion_topic_tier(GiftGivingSystem.QualityTier.NORMAL)
	assert_eq(tier, TopicData.Tier.TIER_4)


func test_completion_tier_fine_is_tier4() -> void:
	var tier: int = OrigamiSystem.completion_topic_tier(GiftGivingSystem.QualityTier.FINE)
	assert_eq(tier, TopicData.Tier.TIER_4)


func test_completion_tier_exceptional_is_tier3() -> void:
	var tier: int = OrigamiSystem.completion_topic_tier(GiftGivingSystem.QualityTier.EXCEPTIONAL)
	assert_eq(tier, TopicData.Tier.TIER_3)


func test_completion_tier_masterwork_is_tier3() -> void:
	var tier: int = OrigamiSystem.completion_topic_tier(GiftGivingSystem.QualityTier.MASTERWORK)
	assert_eq(tier, TopicData.Tier.TIER_3)


# --------------------------------------------------------------------------
# SenbazuruData — compute_quality
# --------------------------------------------------------------------------

func test_senbazuru_quality_no_sessions_normal() -> void:
	assert_eq(SenbazuruData.compute_quality(0, 0), GiftGivingSystem.QualityTier.NORMAL)


func test_senbazuru_quality_avg0_normal() -> void:
	assert_eq(SenbazuruData.compute_quality(0, 5), GiftGivingSystem.QualityTier.NORMAL)


func test_senbazuru_quality_avg1_fine() -> void:
	assert_eq(SenbazuruData.compute_quality(5, 5), GiftGivingSystem.QualityTier.FINE)


func test_senbazuru_quality_avg2_exceptional() -> void:
	assert_eq(SenbazuruData.compute_quality(10, 5), GiftGivingSystem.QualityTier.EXCEPTIONAL)


func test_senbazuru_quality_rounds_down() -> void:
	# 7 raises / 4 sessions = 1.75 → rounds to 1 → FINE
	assert_eq(SenbazuruData.compute_quality(7, 4), GiftGivingSystem.QualityTier.FINE)


func test_senbazuru_quality_avg3_masterwork() -> void:
	assert_eq(SenbazuruData.compute_quality(15, 5), GiftGivingSystem.QualityTier.MASTERWORK)


func test_senbazuru_quality_avg4plus_legendary() -> void:
	assert_eq(SenbazuruData.compute_quality(20, 4), GiftGivingSystem.QualityTier.LEGENDARY)


# --------------------------------------------------------------------------
# Gohei uses_remaining constants
# --------------------------------------------------------------------------

func test_gohei_uses_normal() -> void:
	assert_eq(OrigamiSystem.GOHEI_USES[GiftGivingSystem.QualityTier.NORMAL], 3)


func test_gohei_uses_fine() -> void:
	assert_eq(OrigamiSystem.GOHEI_USES[GiftGivingSystem.QualityTier.FINE], 5)


func test_gohei_uses_exceptional() -> void:
	assert_eq(OrigamiSystem.GOHEI_USES[GiftGivingSystem.QualityTier.EXCEPTIONAL], 8)


func test_gohei_uses_masterwork() -> void:
	assert_eq(OrigamiSystem.GOHEI_USES[GiftGivingSystem.QualityTier.MASTERWORK], 12)


func test_gohei_uses_legendary() -> void:
	assert_eq(OrigamiSystem.GOHEI_USES[GiftGivingSystem.QualityTier.LEGENDARY], 20)


# --------------------------------------------------------------------------
# _process_craft_origami_writebacks — noshi
# --------------------------------------------------------------------------

func _make_craft_noshi_result(
	char_id: int,
	quality_tier: int,
	is_mundane: bool,
	wrapper_target_id: int,
) -> Dictionary:
	return {
		"action_id": "CRAFT",
		"character_id": char_id,
		"success": not is_mundane,
		"effects": {
			"origami_type": "noshi",
			"quality_tier": quality_tier,
			"requires_noshi_creation": true,
			"noshi_is_mundane": is_mundane,
			"wrapper_target_id": wrapper_target_id,
		},
	}


func test_noshi_item_created_on_success() -> void:
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	var next_item_id: Array = [100]
	var topics: Array = []
	var next_topic_id: Array = [1]
	var result: Dictionary = _make_craft_noshi_result(
		1, GiftGivingSystem.QualityTier.FINE, false, 2)
	DayOrchestrator._process_craft_origami_writebacks(
		[result], chars_by_id, next_item_id, topics, next_topic_id, 10)
	assert_eq(_folder.items.size(), 1)
	assert_eq(_folder.items[0]["item_type"], "noshi")
	assert_eq(_folder.items[0]["quality_tier"], GiftGivingSystem.QualityTier.FINE)
	assert_false(_folder.items[0]["is_mundane"])


func test_noshi_item_created_on_failure_as_mundane() -> void:
	var chars_by_id: Dictionary = {1: _folder}
	var next_item_id: Array = [100]
	var topics: Array = []
	var next_topic_id: Array = [1]
	var result: Dictionary = _make_craft_noshi_result(
		1, GiftGivingSystem.QualityTier.MUNDANE, true, -1)
	DayOrchestrator._process_craft_origami_writebacks(
		[result], chars_by_id, next_item_id, topics, next_topic_id, 10)
	assert_eq(_folder.items.size(), 1)
	assert_true(_folder.items[0]["is_mundane"])


func test_noshi_wrapper_bonus_applied_for_other_target() -> void:
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	var next_item_id: Array = [100]
	var topics: Array = []
	var next_topic_id: Array = [1]
	var result: Dictionary = _make_craft_noshi_result(
		1, GiftGivingSystem.QualityTier.FINE, false, 2)
	DayOrchestrator._process_craft_origami_writebacks(
		[result], chars_by_id, next_item_id, topics, next_topic_id, 10)
	# Recipient's temporary_modifiers[folder_id=1] should contain noshi_wrapper_bonus
	var bucket: Array = _recipient.temporary_modifiers.get(1, [])
	var found: bool = false
	for mod: Variant in bucket:
		if (mod as Dictionary).get("event_type", "") == "noshi_wrapper_bonus":
			found = true
			assert_eq(mod.get("value", 0),
				OrigamiSystem.NOSHI_WRAPPER_BONUS[GiftGivingSystem.QualityTier.FINE])
	assert_true(found)


func test_noshi_wrapper_bonus_not_applied_for_self() -> void:
	# Self-wrap: wrapper_target_id == char_id — no bonus
	var chars_by_id: Dictionary = {1: _folder}
	var next_item_id: Array = [100]
	var topics: Array = []
	var next_topic_id: Array = [1]
	var result: Dictionary = _make_craft_noshi_result(
		1, GiftGivingSystem.QualityTier.FINE, false, 1)
	DayOrchestrator._process_craft_origami_writebacks(
		[result], chars_by_id, next_item_id, topics, next_topic_id, 10)
	# Self: no temporary_modifiers bucket should exist from self to self with noshi_wrapper_bonus
	var bucket: Array = _folder.temporary_modifiers.get(1, [])
	var found: bool = false
	for mod: Variant in bucket:
		if (mod as Dictionary).get("event_type", "") == "noshi_wrapper_bonus":
			found = true
	assert_false(found)


func test_noshi_mundane_no_wrapper_bonus() -> void:
	# Mundane noshi: quality_tier < NORMAL, no bonus
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	var next_item_id: Array = [100]
	var topics: Array = []
	var next_topic_id: Array = [1]
	var result: Dictionary = _make_craft_noshi_result(
		1, GiftGivingSystem.QualityTier.MUNDANE, true, 2)
	DayOrchestrator._process_craft_origami_writebacks(
		[result], chars_by_id, next_item_id, topics, next_topic_id, 10)
	var bucket: Array = _recipient.temporary_modifiers.get(1, [])
	var found: bool = false
	for mod: Variant in bucket:
		if (mod as Dictionary).get("event_type", "") == "noshi_wrapper_bonus":
			found = true
	assert_false(found)


# --------------------------------------------------------------------------
# _process_craft_origami_writebacks — gohei
# --------------------------------------------------------------------------

func _make_craft_gohei_result(char_id: int, success: bool, tier: int, uses: int) -> Dictionary:
	var effects: Dictionary = {
		"origami_type": "gohei",
		"quality_tier": tier,
		"requires_gohei_creation": success,
	}
	if success:
		effects["uses_remaining"] = uses
	return {
		"action_id": "CRAFT",
		"character_id": char_id,
		"success": success,
		"effects": effects,
	}


func test_gohei_item_created_on_success() -> void:
	var chars_by_id: Dictionary = {1: _folder}
	var next_item_id: Array = [50]
	DayOrchestrator._process_craft_origami_writebacks(
		[_make_craft_gohei_result(1, true, GiftGivingSystem.QualityTier.EXCEPTIONAL, 8)],
		chars_by_id, next_item_id, [], [1], 10)
	assert_eq(_folder.items.size(), 1)
	assert_eq(_folder.items[0]["item_type"], "gohei")
	assert_eq(_folder.items[0]["uses_remaining"], 8)


func test_gohei_not_created_on_failure() -> void:
	var chars_by_id: Dictionary = {1: _folder}
	var next_item_id: Array = [50]
	DayOrchestrator._process_craft_origami_writebacks(
		[_make_craft_gohei_result(1, false, GiftGivingSystem.QualityTier.NORMAL, 0)],
		chars_by_id, next_item_id, [], [1], 10)
	assert_eq(_folder.items.size(), 0)


# --------------------------------------------------------------------------
# _process_declare_senbazuru_writebacks
# --------------------------------------------------------------------------

func _make_declare_result(char_id: int, dedication: String, recipient_id: int) -> Dictionary:
	return {
		"action_id": "DECLARE_SENBAZURU",
		"character_id": char_id,
		"success": true,
		"effects": {
			"requires_senbazuru_creation": true,
			"dedication_type": dedication,
			"recipient_id": recipient_id,
		},
	}


func test_declare_creates_senbazuru_data() -> void:
	var chars_by_id: Dictionary = {1: _folder}
	var senbazurus: Array = []
	var next_sb_id: Array = [1]
	DayOrchestrator._process_declare_senbazuru_writebacks(
		[_make_declare_result(1, "Healing", 2)],
		senbazurus, next_sb_id, chars_by_id, [], [1], 10)
	assert_eq(senbazurus.size(), 1)
	var sb: SenbazuruData = senbazurus[0] as SenbazuruData
	assert_eq(sb.folder_id, 1)
	assert_eq(sb.dedication_type, "Healing")
	assert_eq(sb.recipient_id, 2)
	assert_eq(sb.state, "active")
	assert_eq(sb.crane_count, 0)
	assert_eq(sb.declaration_date, 10)


func test_declare_creates_tier4_topic() -> void:
	var chars_by_id: Dictionary = {1: _folder}
	var senbazurus: Array = []
	var next_sb_id: Array = [1]
	var topics: Array = []
	var next_topic_id: Array = [100]
	DayOrchestrator._process_declare_senbazuru_writebacks(
		[_make_declare_result(1, "Atonement", -1)],
		senbazurus, next_sb_id, chars_by_id, topics, next_topic_id, 10)
	assert_eq(topics.size(), 1)
	var topic: TopicData = topics[0] as TopicData
	assert_eq(topic.tier, TopicData.Tier.TIER_4)
	assert_eq(topic.topic_type, "senbazuru_declaration")


func test_declare_dedup_blocks_second_active() -> void:
	var chars_by_id: Dictionary = {1: _folder}
	var existing_sb := SenbazuruData.new()
	existing_sb.senbazuru_id = 1
	existing_sb.folder_id = 1
	existing_sb.state = "active"
	var senbazurus: Array = [existing_sb]
	var next_sb_id: Array = [2]
	DayOrchestrator._process_declare_senbazuru_writebacks(
		[_make_declare_result(1, "Healing", 2)],
		senbazurus, next_sb_id, chars_by_id, [], [1], 10)
	assert_eq(senbazurus.size(), 1)  # no new one added


# --------------------------------------------------------------------------
# _process_senbazuru_progress_writebacks — cranes and completion
# --------------------------------------------------------------------------

func _make_progress_result(
	char_id: int,
	senbazuru_id: int,
	cranes_added: int,
	raises_declared: int,
	session_success: bool,
) -> Dictionary:
	return {
		"action_id": "CRAFT",
		"character_id": char_id,
		"success": session_success,
		"effects": {
			"origami_type": "senbazuru_progress",
			"senbazuru_id": senbazuru_id,
			"cranes_added": cranes_added,
			"raises_declared": raises_declared,
			"session_success": session_success,
		},
	}


func _make_active_senbazuru(sb_id: int, folder_id: int, dedication: String = "Healing") -> SenbazuruData:
	var sb := SenbazuruData.new()
	sb.senbazuru_id = sb_id
	sb.folder_id = folder_id
	sb.dedication_type = dedication
	sb.recipient_id = 2
	sb.state = "active"
	sb.crane_count = 0
	sb.total_raises = 0
	sb.successful_session_count = 0
	return sb


func test_progress_adds_cranes() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	var chars_by_id: Dictionary = {1: _folder}
	DayOrchestrator._process_senbazuru_progress_writebacks(
		[_make_progress_result(1, 1, 15, 1, true)],
		[sb], chars_by_id, [], [1], 10)
	assert_eq(sb.crane_count, 15)
	assert_eq(sb.total_raises, 1)
	assert_eq(sb.successful_session_count, 1)


func test_progress_failed_session_adds_zero_cranes() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	var chars_by_id: Dictionary = {1: _folder}
	DayOrchestrator._process_senbazuru_progress_writebacks(
		[_make_progress_result(1, 1, 0, 1, false)],
		[sb], chars_by_id, [], [1], 10)
	assert_eq(sb.crane_count, 0)
	assert_eq(sb.total_raises, 0)
	assert_eq(sb.successful_session_count, 0)


func test_progress_completion_detected_at_1000() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	sb.crane_count = 990
	sb.total_raises = 5
	sb.successful_session_count = 5
	var chars_by_id: Dictionary = {1: _folder}
	var topics: Array = []
	var next_topic_id: Array = [1]
	DayOrchestrator._process_senbazuru_progress_writebacks(
		[_make_progress_result(1, 1, 15, 1, true)],
		[sb], chars_by_id, topics, next_topic_id, 20)
	assert_true(sb.is_complete)
	assert_eq(sb.crane_count, 1000)  # clamped
	assert_eq(sb.completion_date, 20)
	assert_eq(topics.size(), 1)


func test_completion_topic_tier_normal_quality_is_tier4() -> void:
	# avg raises = 0 → NORMAL → TIER_4 completion topic
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	sb.crane_count = 990
	sb.total_raises = 0
	sb.successful_session_count = 5
	var chars_by_id: Dictionary = {1: _folder}
	var topics: Array = []
	DayOrchestrator._process_senbazuru_progress_writebacks(
		[_make_progress_result(1, 1, 15, 0, true)],
		[sb], chars_by_id, topics, [1], 20)
	assert_true(sb.is_complete)
	var topic: TopicData = topics[0] as TopicData
	assert_eq(topic.tier, TopicData.Tier.TIER_4)


func test_completion_topic_tier_exceptional_quality_is_tier3() -> void:
	# avg raises = 2 → EXCEPTIONAL → TIER_3 completion topic
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	sb.crane_count = 990
	sb.total_raises = 10
	sb.successful_session_count = 5
	var chars_by_id: Dictionary = {1: _folder}
	var topics: Array = []
	DayOrchestrator._process_senbazuru_progress_writebacks(
		[_make_progress_result(1, 1, 15, 2, true)],
		[sb], chars_by_id, topics, [1], 20)
	assert_true(sb.is_complete)
	var topic: TopicData = topics[0] as TopicData
	assert_eq(topic.tier, TopicData.Tier.TIER_3)


# --------------------------------------------------------------------------
# _process_present_senbazuru_writebacks — Healing
# --------------------------------------------------------------------------

func _make_complete_senbazuru(sb_id: int, folder_id: int, dedication: String, tier: int) -> SenbazuruData:
	var sb := SenbazuruData.new()
	sb.senbazuru_id = sb_id
	sb.folder_id = folder_id
	sb.dedication_type = dedication
	sb.recipient_id = 2
	sb.state = "active"
	sb.is_complete = true
	sb.crane_count = 1000
	sb.quality_tier = tier
	return sb


func _make_present_result(char_id: int, sb_id: int) -> Dictionary:
	return {
		"action_id": "PRESENT_SENBAZURU",
		"character_id": char_id,
		"success": true,
		"effects": {
			"requires_senbazuru_presentation": true,
			"senbazuru_id": sb_id,
		},
	}


func test_present_healing_applies_disposition_to_recipient() -> void:
	var sb: SenbazuruData = _make_complete_senbazuru(
		1, 1, "Healing", GiftGivingSystem.QualityTier.FINE)
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	DayOrchestrator._process_present_senbazuru_writebacks(
		[_make_present_result(1, 1)], [sb], chars_by_id, [], [1], 50)
	assert_eq(sb.state, "presented")
	# Recipient's temporary_modifiers[folder_id=1] should contain senbazuru_presentation
	var bucket: Array = _recipient.temporary_modifiers.get(1, [])
	var found: bool = false
	for mod: Variant in bucket:
		if (mod as Dictionary).get("event_type", "") == "senbazuru_presentation":
			found = true
			assert_eq(mod.get("value", 0),
				OrigamiSystem.SENBAZURU_HEAL_PROT_DISP[GiftGivingSystem.QualityTier.FINE])
	assert_true(found)


func test_present_protection_recovers_void_points() -> void:
	_recipient.void_ring = 3
	_recipient.current_void_points = 0
	var sb: SenbazuruData = _make_complete_senbazuru(
		1, 1, "Protection", GiftGivingSystem.QualityTier.NORMAL)
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	DayOrchestrator._process_present_senbazuru_writebacks(
		[_make_present_result(1, 1)], [sb], chars_by_id, [], [1], 50)
	assert_eq(_recipient.current_void_points, _recipient.void_ring)


func test_present_remembrance_applies_witness_disposition() -> void:
	var sb: SenbazuruData = _make_complete_senbazuru(
		1, 1, "Remembrance", GiftGivingSystem.QualityTier.EXCEPTIONAL)
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient, 3: _witness}
	DayOrchestrator._process_present_senbazuru_writebacks(
		[_make_present_result(1, 1)], [sb], chars_by_id, [], [1], 50)
	# Witness's temporary_modifiers[folder_id=1] should contain senbazuru_remembrance_witness
	var bucket: Array = _witness.temporary_modifiers.get(1, [])
	var found: bool = false
	for mod: Variant in bucket:
		if (mod as Dictionary).get("event_type", "") == "senbazuru_remembrance_witness":
			found = true
	assert_true(found)


func test_present_remembrance_applies_glory_to_folder() -> void:
	var sb: SenbazuruData = _make_complete_senbazuru(
		1, 1, "Remembrance", GiftGivingSystem.QualityTier.FINE)
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	var initial_glory: float = _folder.glory
	DayOrchestrator._process_present_senbazuru_writebacks(
		[_make_present_result(1, 1)], [sb], chars_by_id, [], [1], 50)
	var expected_gain: float = OrigamiSystem.SENBAZURU_REMEMBRANCE_GLORY[GiftGivingSystem.QualityTier.FINE]
	assert_almost_eq(_folder.glory, initial_glory + expected_gain, 0.001)


func test_present_atonement_applies_honor_to_folder() -> void:
	var sb: SenbazuruData = _make_complete_senbazuru(
		1, 1, "Atonement", GiftGivingSystem.QualityTier.FINE)
	sb.recipient_id = -1
	var chars_by_id: Dictionary = {1: _folder}
	var initial_honor: float = _folder.honor
	DayOrchestrator._process_present_senbazuru_writebacks(
		[_make_present_result(1, 1)], [sb], chars_by_id, [], [1], 50)
	var expected_gain: float = OrigamiSystem.SENBAZURU_ATONEMENT_HONOR[GiftGivingSystem.QualityTier.FINE]
	assert_almost_eq(_folder.honor, initial_honor + expected_gain, 0.001)


func test_present_incomplete_senbazuru_blocked() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	sb.is_complete = false
	var chars_by_id: Dictionary = {1: _folder}
	DayOrchestrator._process_present_senbazuru_writebacks(
		[_make_present_result(1, 1)], [sb], chars_by_id, [], [1], 50)
	assert_eq(sb.state, "active")  # unchanged


# --------------------------------------------------------------------------
# _process_senbazuru_lifecycle_events
# --------------------------------------------------------------------------

func test_lifecycle_creator_death_sets_creator_deceased() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1)
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	var topics: Array = []
	var next_topic_id: Array = [1]
	var death_events: Array = [{"character_id": 1}]  # folder dies
	DayOrchestrator._process_senbazuru_lifecycle_events(
		death_events, [sb], chars_by_id, topics, next_topic_id, 30)
	assert_eq(sb.state, "creator_deceased")
	assert_eq(topics.size(), 1)
	assert_eq((topics[0] as TopicData).topic_type, "senbazuru_creator_deceased")
	assert_eq((topics[0] as TopicData).tier, TopicData.Tier.TIER_4)
	assert_eq((topics[0] as TopicData).subject_role, "NEUTRAL")


func test_lifecycle_recipient_death_shifts_healing_to_remembrance() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1, "Healing")
	var chars_by_id: Dictionary = {1: _folder, 2: _recipient}
	var topics: Array = []
	var next_topic_id: Array = [1]
	var death_events: Array = [{"character_id": 2}]  # recipient dies
	DayOrchestrator._process_senbazuru_lifecycle_events(
		death_events, [sb], chars_by_id, topics, next_topic_id, 30)
	assert_eq(sb.dedication_type, "Remembrance")
	assert_eq(topics.size(), 1)
	assert_eq((topics[0] as TopicData).topic_type, "senbazuru_dedication_shift")
	assert_eq((topics[0] as TopicData).tier, TopicData.Tier.TIER_4)


func test_lifecycle_recipient_death_shifts_protection_to_remembrance() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(1, 1, "Protection")
	var chars_by_id: Dictionary = {1: _folder}
	var topics: Array = []
	DayOrchestrator._process_senbazuru_lifecycle_events(
		[{"character_id": 2}], [sb], chars_by_id, topics, [1], 30)
	assert_eq(sb.dedication_type, "Remembrance")


func test_lifecycle_atonement_recipient_death_no_shift() -> void:
	# Atonement has no recipient — unrelated death should not change state
	var sb: SenbazuruData = _make_active_senbazuru(1, 1, "Atonement")
	sb.recipient_id = -1
	var chars_by_id: Dictionary = {1: _folder}
	var topics: Array = []
	DayOrchestrator._process_senbazuru_lifecycle_events(
		[{"character_id": 99}], [sb], chars_by_id, topics, [1], 30)
	assert_eq(sb.dedication_type, "Atonement")
	assert_eq(topics.size(), 0)


# --------------------------------------------------------------------------
# _process_noshi_consumption_writebacks
# --------------------------------------------------------------------------

func test_noshi_consumed_on_deliver_gift() -> void:
	_folder.items = [
		{"item_type": "noshi", "item_id": 10, "quality_tier": GiftGivingSystem.QualityTier.FINE},
		{"item_type": "noshi", "item_id": 11, "quality_tier": GiftGivingSystem.QualityTier.NORMAL},
	]
	var chars_by_id: Dictionary = {1: _folder}
	var result: Dictionary = {
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"effects": {"noshi_item_id": 10},
	}
	DayOrchestrator._process_noshi_consumption_writebacks([result], chars_by_id)
	assert_eq(_folder.items.size(), 1)
	assert_eq(_folder.items[0]["item_id"], 11)


func test_noshi_not_consumed_without_noshi_item_id() -> void:
	_folder.items = [{"item_type": "noshi", "item_id": 10}]
	var chars_by_id: Dictionary = {1: _folder}
	var result: Dictionary = {
		"action_id": "DELIVER_GIFT",
		"character_id": 1,
		"effects": {},  # no noshi_item_id
	}
	DayOrchestrator._process_noshi_consumption_writebacks([result], chars_by_id)
	assert_eq(_folder.items.size(), 1)


# --------------------------------------------------------------------------
# _process_gohei_usage_writebacks
# --------------------------------------------------------------------------

func test_gohei_uses_decremented_on_worship() -> void:
	_folder.items = [
		{"item_type": "gohei", "item_id": 5, "uses_remaining": 3},
	]
	var chars_by_id: Dictionary = {1: _folder}
	var result: Dictionary = {
		"action_id": "PERFORM_WORSHIP",
		"character_id": 1,
		"effects": {"gohei_item_id": 5},
	}
	DayOrchestrator._process_gohei_usage_writebacks([result], chars_by_id)
	assert_eq(_folder.items.size(), 1)
	assert_eq(_folder.items[0]["uses_remaining"], 2)


func test_gohei_destroyed_when_uses_reach_zero() -> void:
	_folder.items = [
		{"item_type": "gohei", "item_id": 5, "uses_remaining": 1},
	]
	var chars_by_id: Dictionary = {1: _folder}
	var result: Dictionary = {
		"action_id": "PERFORM_WORSHIP",
		"character_id": 1,
		"effects": {"gohei_item_id": 5},
	}
	DayOrchestrator._process_gohei_usage_writebacks([result], chars_by_id)
	assert_eq(_folder.items.size(), 0)


# --------------------------------------------------------------------------
# _inject_senbazuru_context
# --------------------------------------------------------------------------

func test_inject_context_active_senbazuru() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(7, 1, "Atonement")
	sb.is_complete = false
	var world_states: Dictionary = {1: {"known_objectives": {}}}
	DayOrchestrator._inject_senbazuru_context([sb], [_folder], world_states)
	var ws: Dictionary = world_states[1]
	assert_eq(ws["known_objectives"].get("active_senbazuru_id", -1), 7)
	assert_false(ws["known_objectives"].get("senbazuru_is_complete", true))


func test_inject_context_complete_senbazuru() -> void:
	var sb: SenbazuruData = _make_active_senbazuru(7, 1)
	sb.is_complete = true
	var world_states: Dictionary = {1: {"known_objectives": {}}}
	DayOrchestrator._inject_senbazuru_context([sb], [_folder], world_states)
	assert_true(world_states[1]["known_objectives"]["senbazuru_is_complete"])


func test_inject_context_no_senbazuru_leaves_key_absent() -> void:
	var world_states: Dictionary = {1: {"known_objectives": {}}}
	DayOrchestrator._inject_senbazuru_context([], [_folder], world_states)
	assert_false(world_states[1]["known_objectives"].has("active_senbazuru_id"))


func test_inject_context_presented_senbazuru_not_injected() -> void:
	var sb: SenbazuruData = _make_complete_senbazuru(7, 1, "Healing", GiftGivingSystem.QualityTier.FINE)
	sb.state = "presented"
	var world_states: Dictionary = {1: {"known_objectives": {}}}
	DayOrchestrator._inject_senbazuru_context([sb], [_folder], world_states)
	assert_false(world_states[1]["known_objectives"].has("active_senbazuru_id"))


# --------------------------------------------------------------------------
# NPCDecisionEngine precondition filter
# --------------------------------------------------------------------------

func _make_option(action_id: String) -> NPCDataStructures.ScoredAction:
	var opt := NPCDataStructures.ScoredAction.new()
	opt.action_id = action_id
	return opt


func _make_ctx_with_origami(
	skill_rank: int,
	active_sb_id: int,
	is_complete: bool,
) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.skill_ranks = {"Artisan: Origami": skill_rank}
	ctx.known_objectives = {}
	if active_sb_id >= 0:
		ctx.known_objectives["active_senbazuru_id"] = active_sb_id
		ctx.known_objectives["senbazuru_is_complete"] = is_complete
	return ctx


func test_filter_removes_craft_if_no_origami_skill() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_with_origami(0, -1, false)
	var options: Array = [_make_option("CRAFT"), _make_option("DECLARE_SENBAZURU")]
	var filtered: Array = NPCDecisionEngine._apply_origami_precondition_filter(
		options, _folder, ctx)
	var ids: Array = filtered.map(func(o): return o.action_id)
	assert_false(ids.has("CRAFT"))
	assert_true(ids.has("DECLARE_SENBAZURU"))


func test_filter_keeps_craft_with_origami_skill() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_with_origami(3, -1, false)
	var options: Array = [_make_option("CRAFT")]
	var filtered: Array = NPCDecisionEngine._apply_origami_precondition_filter(
		options, _folder, ctx)
	assert_eq(filtered.size(), 1)


func test_filter_removes_declare_if_active_senbazuru_exists() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_with_origami(3, 5, false)
	var options: Array = [_make_option("DECLARE_SENBAZURU")]
	var filtered: Array = NPCDecisionEngine._apply_origami_precondition_filter(
		options, _folder, ctx)
	assert_eq(filtered.size(), 0)


func test_filter_keeps_declare_if_no_active_senbazuru() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_with_origami(3, -1, false)
	var options: Array = [_make_option("DECLARE_SENBAZURU")]
	var filtered: Array = NPCDecisionEngine._apply_origami_precondition_filter(
		options, _folder, ctx)
	assert_eq(filtered.size(), 1)


func test_filter_removes_present_if_not_complete() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_with_origami(3, 5, false)
	var options: Array = [_make_option("PRESENT_SENBAZURU")]
	var filtered: Array = NPCDecisionEngine._apply_origami_precondition_filter(
		options, _folder, ctx)
	assert_eq(filtered.size(), 0)


func test_filter_keeps_present_if_complete() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_with_origami(3, 5, true)
	var options: Array = [_make_option("PRESENT_SENBAZURU")]
	var filtered: Array = NPCDecisionEngine._apply_origami_precondition_filter(
		options, _folder, ctx)
	assert_eq(filtered.size(), 1)


# --------------------------------------------------------------------------
# _execute_declare_senbazuru — gate
# --------------------------------------------------------------------------

func _make_scored_action(action_id: String, metadata: Dictionary = {}) -> NPCDataStructures.ScoredAction:
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = action_id
	a.metadata = metadata
	return a


func _make_ctx_snapshot(active_sb_id: int, is_complete: bool) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.ic_day = 10
	ctx.season = 1
	ctx.known_objectives = {}
	if active_sb_id >= 0:
		ctx.known_objectives["active_senbazuru_id"] = active_sb_id
		ctx.known_objectives["senbazuru_is_complete"] = is_complete
	return ctx


func test_declare_blocked_when_active_senbazuru_exists() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_snapshot(3, false)
	var action: NPCDataStructures.ScoredAction = _make_scored_action(
		"DECLARE_SENBAZURU", {"dedication_type": "Healing", "recipient_id": 2})
	var result: Dictionary = ActionExecutor._execute_declare_senbazuru(action, _folder, ctx)
	assert_false(result["success"])


func test_declare_succeeds_with_no_active_senbazuru() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_snapshot(-1, false)
	var action: NPCDataStructures.ScoredAction = _make_scored_action(
		"DECLARE_SENBAZURU", {"dedication_type": "Protection", "recipient_id": 2})
	var result: Dictionary = ActionExecutor._execute_declare_senbazuru(action, _folder, ctx)
	assert_true(result["success"])
	assert_true(result["effects"]["requires_senbazuru_creation"])
	assert_eq(result["effects"]["dedication_type"], "Protection")


func test_declare_atonement_forces_recipient_minus_one() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_snapshot(-1, false)
	var action: NPCDataStructures.ScoredAction = _make_scored_action(
		"DECLARE_SENBAZURU", {"dedication_type": "Atonement", "recipient_id": 99})
	var result: Dictionary = ActionExecutor._execute_declare_senbazuru(action, _folder, ctx)
	assert_eq(result["effects"]["recipient_id"], -1)


# --------------------------------------------------------------------------
# _execute_present_senbazuru — gates
# --------------------------------------------------------------------------

func test_present_blocked_when_no_active_senbazuru() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_snapshot(-1, false)
	var action: NPCDataStructures.ScoredAction = _make_scored_action("PRESENT_SENBAZURU", {})
	var result: Dictionary = ActionExecutor._execute_present_senbazuru(action, _folder, ctx)
	assert_false(result["success"])


func test_present_blocked_when_not_complete() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_snapshot(5, false)
	var action: NPCDataStructures.ScoredAction = _make_scored_action("PRESENT_SENBAZURU", {})
	var result: Dictionary = ActionExecutor._execute_present_senbazuru(action, _folder, ctx)
	assert_false(result["success"])


func test_present_succeeds_when_complete() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_snapshot(5, true)
	var action: NPCDataStructures.ScoredAction = _make_scored_action("PRESENT_SENBAZURU", {})
	var result: Dictionary = ActionExecutor._execute_present_senbazuru(action, _folder, ctx)
	assert_true(result["success"])
	assert_eq(result["effects"]["senbazuru_id"], 5)
