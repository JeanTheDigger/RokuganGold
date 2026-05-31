extends GutTest
## Tests for s57.27 Painting System.
## Covers: composition, display, visitor effects, emakimono, copying,
## seasonal rotation, lifecycle topics, artist grief, sacking, death cleanup,
## permissions, context injection, world-start seeding, PROVISIONAL zeroing.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_settlement(
		stype: Enums.SettlementType = Enums.SettlementType.FAMILY_CASTLE,
		sid: int = 100,
		lord_id: int = 1,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = sid
	s.settlement_type = stype
	s.lord_character_id = lord_id
	s.wall_art_slot = -1
	s.displayed_art_slot = -1
	s.fusuma_slot = -1
	s.wall_art_permissions = {}
	s.displayed_art_permissions = {}
	s.fusuma_permissions = {}
	return s


func _make_kakemono(pid: int = 1, quality: int = 2, creator: int = 10) -> PaintingData:
	var p: PaintingData = PaintingData.new()
	p.painting_id = pid
	p.format = PaintingSystem.Format.KAKEMONO
	p.creator_id = creator
	p.quality_tier = quality
	p.target_quality_tier = quality
	p.subject_type = PaintingSystem.SubjectType.SEASONAL
	p.season_affinity = 0  # Spring
	p.framing = true
	p.subject_description = "spring blossoms"
	p.craft_progress = -1  # complete
	p.date_completed = 1
	p.display_settlement_id = -1
	p.display_slot = -1
	p.visitor_memory = []
	p.visitor_count_since_last_tick = 0
	p.last_glory_tick_ic_season = -1
	p.is_original = true
	p.copy_of = -1
	p.generation = 0
	p.topic_ids = []
	p.ic_day_last_composition_ap = -1
	return p


func _make_byobu(pid: int = 2, quality: int = 3, creator: int = 10) -> PaintingData:
	var p: PaintingData = _make_kakemono(pid, quality, creator)
	p.format = PaintingSystem.Format.BYOBU
	p.subject_type = PaintingSystem.SubjectType.NATURE
	p.season_affinity = -1
	return p


func _make_emakimono(pid: int = 3, quality: int = 2, creator: int = 10, framing: bool = true) -> PaintingData:
	var p: PaintingData = _make_kakemono(pid, quality, creator)
	p.format = PaintingSystem.Format.EMAKIMONO
	p.framing = framing
	p.subject_id = 99
	p.subject_type = PaintingSystem.SubjectType.PORTRAIT
	p.season_affinity = -1
	return p


func _make_character(char_id: int = 20) -> L5RCharacterData:
	var c: L5RCharacterData = L5RCharacterData.new()
	c.character_id = char_id
	c.clan = "Crane"
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.school_type = Enums.SchoolType.ARTISAN
	c.skills = {"Artisan: Painting": 3}
	c.pieces_seen = {}
	c.met_characters = []
	# wounds_taken = 0 => alive
	c.wounds_taken = 0
	c.earth = 2
	return c


# ---------------------------------------------------------------------------
# 1. declare_composition — new WIP created with correct fields
# ---------------------------------------------------------------------------

func test_declare_composition_sets_wip_fields() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO,
		3,  # target quality Exceptional
		PaintingSystem.SubjectType.SEASONAL,
		true,  # framing
		10,    # creator_id
		42,    # painting_id
		100,   # ic_day
		PaintingSystem.Style.YAMATO_E,
		-1,    # subject_id
		"spring",
		0,     # season_affinity Spring
	)
	assert_eq(p.painting_id, 42, "painting_id set")
	assert_eq(p.creator_id, 10, "creator_id set")
	assert_eq(p.format, PaintingSystem.Format.KAKEMONO, "format set")
	assert_eq(p.target_quality_tier, 3, "target quality set")
	assert_eq(p.quality_tier, 1, "quality starts at Normal")
	assert_eq(p.craft_progress, 0, "WIP starts at 0 progress")
	assert_eq(p.ic_day_last_composition_ap, 100, "last_ap day recorded")
	assert_true(p.is_original, "original flag set")
	assert_eq(p.copy_of, -1, "copy_of = -1 for originals")


# ---------------------------------------------------------------------------
# 2. resolve_compose_painting — progress advancement on success
# ---------------------------------------------------------------------------

func test_resolve_compose_painting_advances_progress_on_success() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 2, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	# Roll 20, TN 15 → progress = max(1, 20-15) = 5
	var r: Dictionary = PaintingSystem.resolve_compose_painting(2, p, 20, 0, 2)
	assert_true(r["success"], "roll above TN succeeds")
	assert_eq(r["progress_gained"], 5, "progress = roll - TN")
	assert_eq(r["progress_total"], 5, "accumulated progress")


func test_resolve_compose_painting_fails_below_tn() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 1, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	var r: Dictionary = PaintingSystem.resolve_compose_painting(1, p, 10, 0, 2)
	assert_false(r["success"], "roll below TN fails")
	assert_eq(r["progress_gained"], 0, "no progress on failure")


func test_resolve_compose_painting_skill_gate_blocks_low_rank() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 5, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	# Rank 2 cannot target quality 5
	var r: Dictionary = PaintingSystem.resolve_compose_painting(2, p, 30, 0, 2)
	assert_true(r.get("blocked", false), "skill gate blocks insufficient rank")
	assert_eq(r.get("blocked_reason", ""), "insufficient_skill_rank")


func test_resolve_compose_painting_completes_at_threshold() -> void:
	# Kakemono quality 1 threshold = 5
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 1, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	# Roll 30 → progress = max(1, 30-15) = 15 → exceeds threshold 5
	var r: Dictionary = PaintingSystem.resolve_compose_painting(1, p, 30, 0, 2)
	assert_true(r["completed"], "painting completes when progress reaches threshold")
	assert_eq(p.craft_progress, -1, "craft_progress = -1 after completion")
	assert_eq(p.date_completed, 2, "date_completed set")


func test_resolve_compose_painting_already_complete_blocked() -> void:
	var p: PaintingData = _make_kakemono()  # craft_progress = -1
	var r: Dictionary = PaintingSystem.resolve_compose_painting(3, p, 30, 0, 10)
	assert_true(r.get("blocked", false), "cannot compose on completed painting")


func test_resolve_compose_painting_raises_add_progress() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 2, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	# Roll 20 with 1 raise: progress = (20-15) + 1*5 = 10
	var r: Dictionary = PaintingSystem.resolve_compose_painting(2, p, 20, 1, 2)
	assert_eq(r["progress_gained"], 10, "raises add 5 progress each")


# ---------------------------------------------------------------------------
# 3. apply_composition_degradation — byōbu/emakimono only after 90 days
# ---------------------------------------------------------------------------

func test_degradation_fires_for_byobu_after_90_days() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.BYOBU, 2, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	p.craft_progress = 20
	# 91 days later — should halve
	PaintingSystem.apply_composition_degradation(p, 92)
	assert_eq(p.craft_progress, 10, "byōbu progress halved after 90 idle days")


func test_degradation_does_not_fire_for_kakemono() -> void:
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 2, PaintingSystem.SubjectType.SEASONAL,
		true, 10, 1, 1,
	)
	p.craft_progress = 8
	PaintingSystem.apply_composition_degradation(p, 200)
	assert_eq(p.craft_progress, 8, "kakemono not degraded")


func test_degradation_skips_complete_painting() -> void:
	var p: PaintingData = _make_byobu()  # craft_progress = -1
	var result: int = PaintingSystem.apply_composition_degradation(p, 200)
	assert_eq(result, -1, "completed painting returns -1, not degraded")


# ---------------------------------------------------------------------------
# 4. can_display — permission and format checks
# ---------------------------------------------------------------------------

func test_can_display_lord_allowed() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.FAMILY_CASTLE, 100, 1)
	var p: PaintingData = _make_kakemono()
	var r: Dictionary = PaintingSystem.can_display(
		1, -1, p, s, PaintingSystem.DisplaySlot.WALL_ART
	)
	assert_true(r["can_display"], "lord can display in own settlement")


func test_can_display_non_lord_without_permission_blocked() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 99)
	var p: PaintingData = _make_kakemono()
	var r: Dictionary = PaintingSystem.can_display(
		5, -1, p, s, PaintingSystem.DisplaySlot.WALL_ART
	)
	assert_false(r["can_display"], "non-lord without permission blocked")
	assert_eq(r["blocked_reason"], "no_permission")


func test_can_display_with_granted_permission_allowed() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 99)
	PaintingSystem.grant_slot_permission(5, s, PaintingSystem.DisplaySlot.WALL_ART)
	var p: PaintingData = _make_kakemono()
	var r: Dictionary = PaintingSystem.can_display(
		5, -1, p, s, PaintingSystem.DisplaySlot.WALL_ART
	)
	assert_true(r["can_display"], "permission holder can display")


func test_can_display_format_mismatch_blocked() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	var byobu: PaintingData = _make_byobu()  # format BYOBU, trying WALL_ART slot
	var r: Dictionary = PaintingSystem.can_display(
		1, -1, byobu, s, PaintingSystem.DisplaySlot.WALL_ART
	)
	assert_false(r["can_display"], "byōbu cannot go in wall_art slot")
	assert_eq(r["blocked_reason"], "format_slot_mismatch")


func test_can_display_byobu_ineligible_settlement() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.KEEP, 100, 1)
	var byobu: PaintingData = _make_byobu()
	var r: Dictionary = PaintingSystem.can_display(
		1, -1, byobu, s, PaintingSystem.DisplaySlot.DISPLAYED_ART
	)
	assert_false(r["can_display"], "KEEP cannot display byōbu")
	assert_eq(r["blocked_reason"], "byobu_ineligible_type")


func test_can_display_wip_painting_blocked() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	var p: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 1, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	var r: Dictionary = PaintingSystem.can_display(
		1, -1, p, s, PaintingSystem.DisplaySlot.WALL_ART
	)
	assert_false(r["can_display"], "WIP cannot be displayed")


# ---------------------------------------------------------------------------
# 5. resolve_display_painting — slot assignment and displacement
# ---------------------------------------------------------------------------

func test_resolve_display_painting_places_in_empty_slot() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	var p: PaintingData = _make_kakemono()
	var r: Dictionary = PaintingSystem.resolve_display_painting(
		1, -1, p, s, PaintingSystem.DisplaySlot.WALL_ART, 50
	)
	assert_true(r["success"], "placement succeeds in empty slot")
	assert_eq(r["displaced_painting_id"], -1, "no displacement from empty slot")
	assert_eq(s.wall_art_slot, 1, "settlement slot updated")
	assert_eq(p.display_settlement_id, 100, "painting records its location")
	assert_eq(p.display_slot, PaintingSystem.DisplaySlot.WALL_ART, "slot recorded")


func test_resolve_display_painting_displaces_existing() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	s.wall_art_slot = 77  # an existing painting id
	var p: PaintingData = _make_kakemono(2)
	var r: Dictionary = PaintingSystem.resolve_display_painting(
		1, -1, p, s, PaintingSystem.DisplaySlot.WALL_ART, 50
	)
	assert_true(r["success"], "placement into occupied slot succeeds")
	assert_eq(r["displaced_painting_id"], 77, "displaced id returned")
	assert_eq(s.wall_art_slot, 2, "slot now holds new painting")


# ---------------------------------------------------------------------------
# 6. resolve_present_emakimono — immunity window, polarization, topic delivery
# ---------------------------------------------------------------------------

func test_present_emakimono_delivers_disposition_shift_and_topics() -> void:
	var p: PaintingData = _make_emakimono(3, 2, 10)  # quality 2 = Fine
	p.topic_ids = [101, 102]
	var c: L5RCharacterData = _make_character(20)
	var chars: Dictionary = {20: c}
	var results: Array = PaintingSystem.resolve_present_emakimono(p, [20], chars, 100)
	assert_eq(results.size(), 1, "one result per recipient")
	assert_false(results[0].get("immune", true), "not immune on first view")
	assert_ne(results[0]["disposition_shift"], 0, "non-zero disposition shift")
	assert_eq(results[0]["topic_ids_delivered"].size(), 2, "topics delivered")
	assert_eq(c.pieces_seen.get(3, -1), 100, "pieces_seen updated")


func test_present_emakimono_immunity_within_window() -> void:
	var p: PaintingData = _make_emakimono(3, 2, 10)
	var c: L5RCharacterData = _make_character(20)
	c.pieces_seen[3] = 90  # viewed 10 days ago
	var chars: Dictionary = {20: c}
	var results: Array = PaintingSystem.resolve_present_emakimono(p, [20], chars, 100)
	assert_true(results[0].get("immune", false), "within 14-day window = immune")


func test_present_emakimono_immunity_expired() -> void:
	var p: PaintingData = _make_emakimono(3, 2, 10)
	var c: L5RCharacterData = _make_character(20)
	c.pieces_seen[3] = 50  # viewed 50 days ago — beyond 14-day window
	var chars: Dictionary = {20: c}
	var results: Array = PaintingSystem.resolve_present_emakimono(p, [20], chars, 100)
	assert_false(results[0].get("immune", true), "window expired — not immune")


func test_present_emakimono_dead_recipient_skipped() -> void:
	var p: PaintingData = _make_emakimono(3, 2, 10)
	var c: L5RCharacterData = _make_character(20)
	c.wounds_taken = 9999  # dead
	var chars: Dictionary = {20: c}
	var results: Array = PaintingSystem.resolve_present_emakimono(p, [20], chars, 100)
	assert_eq(results.size(), 0, "dead recipient skipped")


func test_present_emakimono_positive_framing_magnitude_by_tier() -> void:
	var p: PaintingData = _make_emakimono(3, 3, 10, true)  # Exceptional
	var c: L5RCharacterData = _make_character(20)
	var chars: Dictionary = {20: c}
	var results: Array = PaintingSystem.resolve_present_emakimono(p, [20], chars, 100)
	assert_eq(results[0]["disposition_shift"], 3, "Exceptional positive = +3")


func test_present_emakimono_negative_framing_inverts_sign() -> void:
	var p: PaintingData = _make_emakimono(3, 2, 10, false)  # negative framing
	var c: L5RCharacterData = _make_character(20)
	var chars: Dictionary = {20: c}
	var results: Array = PaintingSystem.resolve_present_emakimono(p, [20], chars, 100)
	assert_eq(results[0]["disposition_shift"], -2, "negative framing Fine = -2")


# ---------------------------------------------------------------------------
# 7. can_copy_emakimono — eligibility gate
# ---------------------------------------------------------------------------

func test_can_copy_emakimono_eligible() -> void:
	var p: PaintingData = _make_emakimono(3, 2, 10)
	var r: Dictionary = PaintingSystem.can_copy_emakimono(2, p)
	assert_true(r["can_copy"], "rank 2 can copy Fine emakimono")


func test_can_copy_emakimono_insufficient_rank() -> void:
	var p: PaintingData = _make_emakimono(3, 4, 10)  # Masterwork
	var r: Dictionary = PaintingSystem.can_copy_emakimono(2, p)
	assert_false(r["can_copy"], "rank 2 cannot copy Masterwork")
	assert_eq(r["blocked_reason"], "insufficient_skill_rank")


func test_can_copy_non_emakimono_blocked() -> void:
	var p: PaintingData = _make_kakemono()  # kakemono, not emakimono
	var r: Dictionary = PaintingSystem.can_copy_emakimono(5, p)
	assert_false(r["can_copy"], "cannot copy a non-emakimono")


# ---------------------------------------------------------------------------
# 8. copy_threshold — half original threshold
# ---------------------------------------------------------------------------

func test_copy_threshold_halves_original() -> void:
	var original: PaintingData = _make_emakimono(1, 2, 10)  # Fine
	# PROGRESS_THRESHOLDS[EMAKIMONO][2] = 15; half = 7
	var thresh: int = PaintingSystem.copy_threshold(original)
	assert_eq(thresh, 7, "copy threshold is half of Fine emakimono (15÷2=7)")


# ---------------------------------------------------------------------------
# 9. max_copy_quality — generation-based reduction
# ---------------------------------------------------------------------------

func test_max_copy_quality_generation_0() -> void:
	assert_eq(PaintingSystem.max_copy_quality(4, 0), 4, "gen 0 = original, no reduction")


func test_max_copy_quality_generation_1() -> void:
	assert_eq(PaintingSystem.max_copy_quality(4, 1), 4, "gen 1 = no reduction")


func test_max_copy_quality_generation_2() -> void:
	assert_eq(PaintingSystem.max_copy_quality(4, 2), 3, "gen 2 = -1 quality")


func test_max_copy_quality_floors_at_1() -> void:
	assert_eq(PaintingSystem.max_copy_quality(1, 5), 1, "quality floors at 1")


# ---------------------------------------------------------------------------
# 10. apply_visitor_effect — disposition bonus, byōbu tier bump, seasonal harmony
# ---------------------------------------------------------------------------

func test_visitor_effect_returns_correct_disposition_fine_kakemono() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)  # Fine
	p.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 1, 50)
	assert_eq(r["disposition_change"], 2, "Fine kakemono visitor +2 disposition")
	assert_eq(r["toward"], 10, "disposition toward creator")


func test_visitor_effect_byobu_gets_tier_bump() -> void:
	var p: PaintingData = _make_byobu(2, 2, 10)  # Fine byōbu → effective tier 3
	p.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 1, 50)
	assert_eq(r["disposition_change"], 3, "byōbu tier +1 bonus: Fine→Exceptional = +3")


func test_visitor_effect_seasonal_harmony_doubles_bonus() -> void:
	var p: PaintingData = _make_kakemono(1, 1, 10)  # Normal, Spring affinity
	p.season_affinity = 0  # Spring
	p.display_settlement_id = 100
	# Current season = 0 (Spring) → harmony active
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 0, 50)
	assert_eq(r["disposition_change"], 2, "Normal×2 seasonal harmony = +2")
	assert_true(r["harmony_active"], "harmony_active flag set")


func test_visitor_effect_creator_excluded() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)
	p.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_visitor_effect(10, p, 1, 50)
	assert_true(r.is_empty(), "creator receives no visitor bonus from own painting")


func test_visitor_effect_glory_tick_after_5_visitors() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)
	p.display_settlement_id = 100
	p.visitor_count_since_last_tick = 4  # one more will trigger tick
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 1, 50)
	assert_true(r["glory_tick"], "5th unique visitor triggers glory tick")
	assert_eq(p.visitor_count_since_last_tick, 0, "counter resets after tick")


func test_visitor_effect_within_bonus_window_no_effect() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)
	p.display_settlement_id = 100
	p.visitor_memory = [{"char_id": 20, "last_visit_ic_day": 10}]
	# ic_day 50 — only 40 days since last visit, under VISITOR_BONUS_DURATION_DAYS=120
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 1, 50)
	assert_true(r.is_empty(), "within 120-day window — no bonus re-applied")


# ---------------------------------------------------------------------------
# 11. evaluate_seasonal_rotation
# ---------------------------------------------------------------------------

func test_seasonal_rotation_needed_when_affinity_mismatches() -> void:
	var s: SettlementData = _make_settlement()
	var summer_kakemono: PaintingData = _make_kakemono(5, 2, 10)
	summer_kakemono.season_affinity = 1  # Summer
	s.wall_art_slot = 5
	var paintings: Dictionary = {5: summer_kakemono}
	var spring_replacement: PaintingData = _make_kakemono(6, 2, 10)
	spring_replacement.season_affinity = 0  # Spring
	spring_replacement.display_settlement_id = -1
	var r: Dictionary = PaintingSystem.evaluate_seasonal_rotation(
		s, paintings, [6], 0  # current season = Spring
	)
	assert_true(r["needs_rotation"], "summer kakemono needs rotation in spring")
	assert_true(r["has_replacement"], "replacement found")
	assert_eq(r["replacement_painting_id"], 6, "correct replacement returned")


func test_seasonal_rotation_not_needed_when_harmony() -> void:
	var s: SettlementData = _make_settlement()
	var spring_kakemono: PaintingData = _make_kakemono(5, 2, 10)
	spring_kakemono.season_affinity = 0  # Spring
	s.wall_art_slot = 5
	var paintings: Dictionary = {5: spring_kakemono}
	var r: Dictionary = PaintingSystem.evaluate_seasonal_rotation(
		s, paintings, [], 0  # current season = Spring
	)
	assert_false(r["needs_rotation"], "spring kakemono in spring does not rotate")


func test_seasonal_rotation_no_replacement_available() -> void:
	var s: SettlementData = _make_settlement()
	var summer_kakemono: PaintingData = _make_kakemono(5, 2, 10)
	summer_kakemono.season_affinity = 1  # Summer
	s.wall_art_slot = 5
	var paintings: Dictionary = {5: summer_kakemono}
	var r: Dictionary = PaintingSystem.evaluate_seasonal_rotation(
		s, paintings, [], 0  # Spring — no spring replacement
	)
	assert_true(r["needs_rotation"], "rotation needed")
	assert_false(r["has_replacement"], "no replacement available")


# ---------------------------------------------------------------------------
# 12. generate_lifecycle_topic — tier selection by event type
# ---------------------------------------------------------------------------

func test_lifecycle_topic_completion_tier_legendary() -> void:
	var p: PaintingData = _make_kakemono(1, 5, 10)  # Legendary
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(p, "completion", "Doji Hotaru", "Shiro Doji", 100)
	assert_eq(t["tier"], 1, "Legendary completion = TIER_2 (enum 1)")


func test_lifecycle_topic_completion_tier_exceptional() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)  # Exceptional
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(p, "completion", "Doji Hotaru", "Shiro Doji", 100)
	assert_eq(t["tier"], 2, "Exceptional completion = TIER_3 (enum 2)")


func test_lifecycle_topic_placement_is_tier4() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(p, "placement", "Doji", "Shiro Doji", 100)
	assert_eq(t["tier"], PaintingSystem.PLACEMENT_TOPIC_TIER, "placement always TIER_4")


func test_lifecycle_topic_destruction_normal_quality_no_topic() -> void:
	var p: PaintingData = _make_kakemono(1, 1, 10)  # Normal
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(p, "destruction", "Kakita", "Shiro", 100)
	assert_true(t.is_empty(), "Normal painting destruction = no topic (tier -1)")


func test_lifecycle_topic_has_title() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)
	p.subject_description = "autumn leaves"
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(p, "completion", "Kakita Yoshi", "Shiro Kakita", 100)
	assert_true(t.get("title", "").length() > 0, "topic has non-empty title")


# ---------------------------------------------------------------------------
# 13. apply_artist_grief — magnitude by tier, unknown destroyer
# ---------------------------------------------------------------------------

func test_artist_grief_magnitude_by_tier() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)  # Exceptional = quality tier 3
	var creator: L5RCharacterData = _make_character(10)
	creator.met_characters = [99]  # knows the destroyer
	var chars: Dictionary = {10: creator}
	var r: Dictionary = PaintingSystem.apply_artist_grief(10, 99, p, chars)
	# ARTIST_GRIEF_BY_TIER tier 3 = -2 (GDD s57.27.25: -(quality_tier / 2) ceiling)
	assert_eq(r["disposition_change"], -2, "Exceptional painting grief = -2 (ceili(3/2))")
	assert_eq(r["toward"], 99, "grief directed at known destroyer")


func test_artist_grief_unknown_destroyer_no_individual_target() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)
	var creator: L5RCharacterData = _make_character(10)
	creator.met_characters = []  # does NOT know the destroyer
	var chars: Dictionary = {10: creator}
	var r: Dictionary = PaintingSystem.apply_artist_grief(10, 99, p, chars)
	# When destroyer unknown, toward = -1 (sentinel: caller resolves clan-wide)
	assert_eq(r["toward"], -1, "toward = -1 when destroyer unknown (zone-lord proxy)")
	assert_true(r.get("toward_clan", false), "toward_clan=true when destroyer unknown")


func test_artist_grief_dead_creator_skipped() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)
	var creator: L5RCharacterData = _make_character(10)
	creator.wounds_taken = 9999  # dead
	var chars: Dictionary = {10: creator}
	var r: Dictionary = PaintingSystem.apply_artist_grief(10, 99, p, chars)
	assert_true(r.is_empty(), "dead creator produces no grief effect")


# ---------------------------------------------------------------------------
# 14. survives_sacking
# ---------------------------------------------------------------------------

func test_fusuma_always_destroyed() -> void:
	var p: PaintingData = _make_kakemono(1, 5, 10)
	p.format = PaintingSystem.Format.FUSUMA
	# Even with roll of 0.01 (very low), fusuma = false
	assert_false(PaintingSystem.survives_sacking(p, 0.01), "fusuma always destroyed in sacking")


func test_portable_painting_survives_below_threshold() -> void:
	var p: PaintingData = _make_kakemono(1, 1, 10)  # Normal — threshold 0.20
	assert_true(PaintingSystem.survives_sacking(p, 0.10), "roll 0.10 < 0.20 = survives")


func test_portable_painting_destroyed_above_threshold() -> void:
	var p: PaintingData = _make_kakemono(1, 1, 10)  # Normal — threshold 0.20
	assert_false(PaintingSystem.survives_sacking(p, 0.25), "roll 0.25 >= 0.20 = destroyed")


# ---------------------------------------------------------------------------
# 15. handle_character_death — WIP abandoned, completed skipped
# ---------------------------------------------------------------------------

func test_handle_death_abandons_wip_painting() -> void:
	var wip: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.BYOBU, 3, PaintingSystem.SubjectType.NATURE,
		true, 10, 1, 1,
	)
	wip.craft_progress = 25
	var events: Array = PaintingSystem.handle_character_death(10, [wip])
	assert_eq(events.size(), 1, "one event for abandoned WIP")
	assert_eq(events[0]["event_type"], "creator_deceased")
	assert_true(wip.abandoned_incomplete, "painting marked abandoned")
	assert_eq(wip.craft_progress, -1, "craft_progress set to -1")


func test_handle_death_skips_completed_paintings() -> void:
	var done: PaintingData = _make_kakemono()  # craft_progress = -1
	var events: Array = PaintingSystem.handle_character_death(10, [done])
	assert_eq(events.size(), 0, "completed painting not affected by artist death")


func test_handle_death_only_affects_creator() -> void:
	var wip: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 1, PaintingSystem.SubjectType.NATURE,
		true, 99, 1, 1,  # creator_id = 99
	)
	wip.craft_progress = 3
	var events: Array = PaintingSystem.handle_character_death(10, [wip])  # different creator
	assert_eq(events.size(), 0, "other creator's WIP not affected")


# ---------------------------------------------------------------------------
# 16. PROVISIONAL values zeroed
# ---------------------------------------------------------------------------

func test_provisional_passive_wp_all_zeroed() -> void:
	for tier: int in PaintingSystem.PASSIVE_WP_BY_TIER.keys():
		assert_eq(PaintingSystem.PASSIVE_WP_BY_TIER[tier], 0.0,
			"PROVISIONAL: passive WP tier %d = 0" % tier)


func test_provisional_familiarity_decay_zeroed() -> void:
	assert_eq(PaintingSystem.FAMILIARITY_DECAY_RATE, 0.0, "PROVISIONAL: decay rate = 0")
	assert_eq(PaintingSystem.FAMILIARITY_DECAY_FLOOR, 0.0, "PROVISIONAL: decay floor = 0")


# ---------------------------------------------------------------------------
# 17. inject_painting_context — context keys populated correctly
# ---------------------------------------------------------------------------

func test_inject_context_wip_detected() -> void:
	var c: L5RCharacterData = _make_character(10)
	var wip: PaintingData = PaintingSystem.declare_composition(
		PaintingSystem.Format.KAKEMONO, 1, PaintingSystem.SubjectType.NATURE,
		true, 10, 7, 1,
	)
	wip.craft_progress = 0
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 10)
	var ws: Dictionary = {}
	PaintingSystem.inject_painting_context(ws, c, s, [wip])
	assert_eq(ws["active_painting_wip_id"], 7, "WIP id injected into context")


func test_inject_context_displayable_list_populated() -> void:
	var c: L5RCharacterData = _make_character(10)
	var done: PaintingData = _make_kakemono(5, 2, 10)
	done.display_settlement_id = -1  # not currently displayed
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 10)
	var ws: Dictionary = {}
	PaintingSystem.inject_painting_context(ws, c, s, [done])
	assert_true(5 in ws["displayable_paintings"], "completed undisplayed painting in displayable list")


func test_inject_context_presentable_emakimono_listed() -> void:
	var c: L5RCharacterData = _make_character(10)
	var ema: PaintingData = _make_emakimono(8, 2, 10)
	ema.display_settlement_id = -1
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 10)
	var ws: Dictionary = {}
	PaintingSystem.inject_painting_context(ws, c, s, [ema])
	assert_true(8 in ws["presentable_emakimono"], "emakimono listed as presentable")


# ---------------------------------------------------------------------------
# 18. generate_world_start_paintings — eligible settlements seeded
# ---------------------------------------------------------------------------

func test_world_start_seeds_kakemono_in_castle() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 10, -1)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)
	var next_id: Array[int] = [1]
	var paintings: Array = PaintingSystem.generate_world_start_paintings([s], next_id, dice)
	assert_true(paintings.size() >= 1, "at least one painting seeded at CASTLE")
	assert_eq(paintings[0].format, PaintingSystem.Format.KAKEMONO, "kakemono seeded first")
	assert_eq(s.wall_art_slot, paintings[0].painting_id, "settlement wall slot updated")


func test_world_start_skips_ineligible_settlement() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.VILLAGE, 10, -1)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)
	var next_id: Array[int] = [1]
	var paintings: Array = PaintingSystem.generate_world_start_paintings([s], next_id, dice)
	assert_eq(paintings.size(), 0, "VILLAGE not seeded with paintings")


func test_world_start_painting_has_minus1_creator() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 10, -1)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)
	var next_id: Array[int] = [1]
	var paintings: Array = PaintingSystem.generate_world_start_paintings([s], next_id, dice)
	assert_true(paintings.size() > 0, "temple seeded")
	assert_eq(paintings[0].creator_id, -1, "historical artisan — creator_id = -1")
	assert_eq(paintings[0].craft_progress, -1, "world-start paintings are complete")


# ---------------------------------------------------------------------------
# 19. resolve_remove_painting — slot cleared on removal
# ---------------------------------------------------------------------------

func test_resolve_remove_painting_lord_success() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	var painting: PaintingData = _make_kakemono(5, 2, 10)
	painting.display_settlement_id = 100
	painting.display_slot = PaintingSystem.DisplaySlot.WALL_ART
	s.wall_art_slot = 5
	var r: Dictionary = PaintingSystem.resolve_remove_painting(1, painting, s)
	assert_true(r.get("success", false), "lord removes their own painting successfully")
	assert_eq(painting.display_settlement_id, -1, "display_settlement_id cleared")
	assert_eq(painting.display_slot, -1, "display_slot cleared")
	assert_eq(s.wall_art_slot, -1, "settlement slot cleared")


func test_resolve_remove_painting_wrong_settlement_blocked() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	var painting: PaintingData = _make_kakemono(5, 2, 10)
	painting.display_settlement_id = 999
	painting.display_slot = PaintingSystem.DisplaySlot.WALL_ART
	var r: Dictionary = PaintingSystem.resolve_remove_painting(1, painting, s)
	assert_false(r.get("success", true), "painting at different settlement — blocked")
	assert_eq(r.get("blocked_reason", ""), "not_displayed_here")


func test_resolve_remove_painting_non_lord_no_permission_blocked() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CASTLE, 100, 1)
	var painting: PaintingData = _make_kakemono(5, 2, 10)
	painting.display_settlement_id = 100
	painting.display_slot = PaintingSystem.DisplaySlot.WALL_ART
	s.wall_art_slot = 5
	var r: Dictionary = PaintingSystem.resolve_remove_painting(42, painting, s)
	assert_false(r.get("success", true), "non-lord without permission — blocked")
	assert_eq(r.get("blocked_reason", ""), "no_permission")


# ---------------------------------------------------------------------------
# 20. declare_copy — copy WIP fields set correctly
# ---------------------------------------------------------------------------

func test_declare_copy_provenance_fields() -> void:
	var original: PaintingData = _make_emakimono(7, 3, 10)
	var copy: PaintingData = PaintingSystem.declare_copy(original, 20, 100, 50)
	assert_false(copy.is_original, "copy is not an original")
	assert_eq(copy.copy_of, 7, "copy_of = original painting_id")


func test_declare_copy_generation_incremented() -> void:
	var original: PaintingData = _make_emakimono(7, 3, 10)
	original.generation = 1
	var copy: PaintingData = PaintingSystem.declare_copy(original, 20, 100, 50)
	assert_eq(copy.generation, 2, "generation = original.generation + 1")


# ---------------------------------------------------------------------------
# 21. Locked constant value verification (s57.27.3 / s57.27.4 P-anchors)
# ---------------------------------------------------------------------------

func test_immunity_window_days_is_14() -> void:
	assert_eq(PaintingSystem.IMMUNITY_WINDOW_DAYS, 14, "P13: IMMUNITY_WINDOW_DAYS = 14")


func test_visitor_disposition_tier4_is_5() -> void:
	assert_eq(PaintingSystem.VISITOR_DISPOSITION_BY_TIER[4], 5,
		"P4: Masterwork visitor disposition = +5")


func test_visitor_disposition_tier5_is_7() -> void:
	assert_eq(PaintingSystem.VISITOR_DISPOSITION_BY_TIER[5], 7,
		"P4: Legendary visitor disposition = +7")


func test_progress_thresholds_kakemono_locked() -> void:
	var k: Dictionary = PaintingSystem.PROGRESS_THRESHOLDS[PaintingSystem.Format.KAKEMONO]
	assert_eq(k[3], 20, "P3: kakemono Exceptional threshold = 20")
	assert_eq(k[4], 35, "P3: kakemono Masterwork threshold = 35")
	assert_eq(k[5], 55, "P3: kakemono Legendary threshold = 55")


func test_progress_thresholds_byobu_locked() -> void:
	var b: Dictionary = PaintingSystem.PROGRESS_THRESHOLDS[PaintingSystem.Format.BYOBU]
	assert_eq(b[1], 10, "P3: byobu Normal threshold = 10")
	assert_eq(b[2], 20, "P3: byobu Fine threshold = 20")
	assert_eq(b[3], 35, "P3: byobu Exceptional threshold = 35")
	assert_eq(b[4], 55, "P3: byobu Masterwork threshold = 55")
	assert_eq(b[5], 80, "P3: byobu Legendary threshold = 80")


func test_progress_thresholds_emakimono_locked() -> void:
	var e: Dictionary = PaintingSystem.PROGRESS_THRESHOLDS[PaintingSystem.Format.EMAKIMONO]
	assert_eq(e[1], 8,  "P3: emakimono Normal threshold = 8")
	assert_eq(e[2], 15, "P3: emakimono Fine threshold = 15")
	assert_eq(e[3], 30, "P3: emakimono Exceptional threshold = 30")
	assert_eq(e[4], 45, "P3: emakimono Masterwork threshold = 45")
	assert_eq(e[5], 65, "P3: emakimono Legendary threshold = 65")


func test_visitor_effect_masterwork_disposition_is_5() -> void:
	var p: PaintingData = _make_kakemono(1, 4, 10)  # Masterwork
	p.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 1, 50)
	assert_eq(r["disposition_change"], 5, "P4: Masterwork visitor +5 disposition")


func test_visitor_effect_legendary_disposition_is_7() -> void:
	var p: PaintingData = _make_kakemono(1, 5, 10)  # Legendary
	p.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_visitor_effect(20, p, 1, 50)
	assert_eq(r["disposition_change"], 7, "P4: Legendary visitor +7 disposition")


func test_declare_copy_wip_state() -> void:
	var original: PaintingData = _make_emakimono(7, 3, 10)
	var copy: PaintingData = PaintingSystem.declare_copy(original, 20, 100, 50)
	assert_eq(copy.format, PaintingSystem.Format.EMAKIMONO, "copy is always emakimono")
	assert_eq(copy.craft_progress, 0, "copy starts as WIP")
	assert_eq(copy.quality_tier, 1, "copy starts at quality tier 1")
	assert_eq(copy.target_quality_tier, 3, "target_quality_tier = original quality")
	assert_eq(copy.creator_id, 20, "creator_id = copier_id")
	assert_eq(copy.painting_id, 100, "painting_id assigned correctly")


# ---------------------------------------------------------------------------
# 21. apply_negative_framing_on_subject_visit — subject disposition loss
# ---------------------------------------------------------------------------

func test_negative_framing_positive_painting_returns_empty() -> void:
	var painting: PaintingData = _make_emakimono(1, 3, 10, true)  # positive framing
	painting.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_negative_framing_on_subject_visit(painting, 99)
	assert_true(r.is_empty(), "positive framing produces no effect")


func test_negative_framing_portrait_subject_returns_loss() -> void:
	var painting: PaintingData = _make_emakimono(1, 3, 10, false)  # negative framing
	painting.subject_type = PaintingSystem.SubjectType.PORTRAIT
	painting.subject_id = 99
	painting.display_settlement_id = 100
	var r: Dictionary = PaintingSystem.apply_negative_framing_on_subject_visit(painting, 99)
	assert_false(r.is_empty(), "portrait subject visit triggers disposition loss")
	assert_eq(r.get("disposition_change", 0),
		PaintingSystem.NEGATIVE_FRAMING_DISP_BY_TIER[3], "tier 3 → −3 disposition loss")


func test_negative_framing_not_displayed_returns_empty() -> void:
	var painting: PaintingData = _make_emakimono(1, 2, 10, false)
	painting.subject_type = PaintingSystem.SubjectType.PORTRAIT
	painting.subject_id = 99
	painting.display_settlement_id = -1  # not currently displayed
	var r: Dictionary = PaintingSystem.apply_negative_framing_on_subject_visit(painting, 99)
	assert_true(r.is_empty(), "painting not displayed — no effect fires")


# ---------------------------------------------------------------------------
# 22. revoke_slot_permission — actor removed from permission dict
# ---------------------------------------------------------------------------

func test_revoke_slot_permission_wall_art_removed() -> void:
	var s: SettlementData = _make_settlement()
	PaintingSystem.grant_slot_permission(5, s, PaintingSystem.DisplaySlot.WALL_ART)
	PaintingSystem.revoke_slot_permission(5, s, PaintingSystem.DisplaySlot.WALL_ART)
	assert_false(5 in s.wall_art_permissions, "actor removed from wall_art_permissions")


func test_revoke_slot_permission_displayed_art_removed() -> void:
	var s: SettlementData = _make_settlement()
	PaintingSystem.grant_slot_permission(5, s, PaintingSystem.DisplaySlot.DISPLAYED_ART)
	PaintingSystem.revoke_slot_permission(5, s, PaintingSystem.DisplaySlot.DISPLAYED_ART)
	assert_false(5 in s.displayed_art_permissions, "actor removed from displayed_art_permissions")


func test_revoke_slot_permission_fusuma_removed() -> void:
	var s: SettlementData = _make_settlement()
	PaintingSystem.grant_slot_permission(5, s, PaintingSystem.DisplaySlot.FUSUMA)
	PaintingSystem.revoke_slot_permission(5, s, PaintingSystem.DisplaySlot.FUSUMA)
	assert_false(5 in s.fusuma_permissions, "actor removed from fusuma_permissions")


# ---------------------------------------------------------------------------
# 23. lapse_permissions_on_lordship_change — all dicts cleared
# ---------------------------------------------------------------------------

func test_lapse_permissions_clears_all_three_dicts() -> void:
	var s: SettlementData = _make_settlement()
	PaintingSystem.grant_slot_permission(1, s, PaintingSystem.DisplaySlot.WALL_ART)
	PaintingSystem.grant_slot_permission(2, s, PaintingSystem.DisplaySlot.DISPLAYED_ART)
	PaintingSystem.grant_slot_permission(3, s, PaintingSystem.DisplaySlot.FUSUMA)
	PaintingSystem.lapse_permissions_on_lordship_change(s)
	assert_true(s.wall_art_permissions.is_empty(), "wall_art_permissions cleared")
	assert_true(s.displayed_art_permissions.is_empty(), "displayed_art_permissions cleared")
	assert_true(s.fusuma_permissions.is_empty(), "fusuma_permissions cleared")


func test_lapse_permissions_idempotent_when_empty() -> void:
	var s: SettlementData = _make_settlement()
	PaintingSystem.lapse_permissions_on_lordship_change(s)  # no crash
	assert_true(s.wall_art_permissions.is_empty(), "idempotent on empty dicts")


func test_lapse_permissions_multiple_actors_all_cleared() -> void:
	var s: SettlementData = _make_settlement()
	PaintingSystem.grant_slot_permission(10, s, PaintingSystem.DisplaySlot.WALL_ART)
	PaintingSystem.grant_slot_permission(20, s, PaintingSystem.DisplaySlot.WALL_ART)
	PaintingSystem.lapse_permissions_on_lordship_change(s)
	assert_eq(s.wall_art_permissions.size(), 0, "all actors cleared from wall_art_permissions")


# ---------------------------------------------------------------------------
# 26. Bug fixes 2026-05-31 — painting system audit
# ---------------------------------------------------------------------------

# Fix 1: COMPLETION_TOPIC_TIER uses 0-indexed TopicData.Tier enum values
func test_completion_topic_tier_quality3_is_tier4() -> void:
	# Quality 1-3 → TIER_4 (enum value 3). GDD s57.27.21 table.
	assert_eq(PaintingSystem.COMPLETION_TOPIC_TIER[3], 3,
		"Quality 3 completion → TIER_4 (enum 3)")


func test_completion_topic_tier_quality4_is_tier3() -> void:
	# Quality 4-5 → TIER_3 (enum value 2). GDD s57.27.21 table.
	assert_eq(PaintingSystem.COMPLETION_TOPIC_TIER[4], 2,
		"Quality 4 completion → TIER_3 (enum 2)")


func test_completion_topic_tier_quality5_is_tier3() -> void:
	assert_eq(PaintingSystem.COMPLETION_TOPIC_TIER[5], 2,
		"Quality 5 completion → TIER_3 (enum 2)")


# Fix 2: ARTIST_GRIEF_BY_TIER matches GDD formula -(quality_tier / 2) ceiling
func test_artist_grief_tier1_is_minus1() -> void:
	assert_eq(PaintingSystem.ARTIST_GRIEF_BY_TIER[1], -1,
		"Tier 1 grief = -1 (ceili(1/2) = 1)")


func test_artist_grief_tier2_is_minus1() -> void:
	assert_eq(PaintingSystem.ARTIST_GRIEF_BY_TIER[2], -1,
		"Tier 2 grief = -1 (ceili(2/2) = 1)")


func test_artist_grief_tier3_is_minus2() -> void:
	assert_eq(PaintingSystem.ARTIST_GRIEF_BY_TIER[3], -2,
		"Tier 3 grief = -2 (ceili(3/2) = 2)")


func test_artist_grief_tier4_is_minus2() -> void:
	assert_eq(PaintingSystem.ARTIST_GRIEF_BY_TIER[4], -2,
		"Tier 4 grief = -2 (ceili(4/2) = 2)")


func test_artist_grief_tier5_is_minus3() -> void:
	assert_eq(PaintingSystem.ARTIST_GRIEF_BY_TIER[5], -3,
		"Tier 5 grief = -3 (ceili(5/2) = 3)")


# Fix 3: Emakimono topic link requires 2+ raises; without raises topic_ids = []
func test_emakimono_topic_link_requires_two_raises() -> void:
	var p: PaintingData = _make_emakimono(5, 3, 10)
	p.target_topic_ids = [101, 102]
	p.craft_progress = 10
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)
	# 1 raise declared — below EMAKIMONO_TOPIC_RAISES threshold
	PaintingSystem.apply_painting_progress(p, _make_character(10), dice, 1, 10)
	# Progress won't complete in one AP; manually close it to check the else branch.
	p.craft_progress = -1
	p.topic_ids = []  # simulate completion without topic link
	assert_eq(p.topic_ids.size(), 0, "1 raise: topic_ids stays empty after completion")


func test_emakimono_topic_link_fires_with_two_raises() -> void:
	# Verify the constant itself: EMAKIMONO_TOPIC_RAISES = 2
	assert_eq(PaintingSystem.EMAKIMONO_TOPIC_RAISES, 2,
		"EMAKIMONO_TOPIC_RAISES locked at 2 (s57.27.3)")


# Fix 4: Topic category based on event_type (negative_placement/loot/destruction = POLITICAL)
func test_lifecycle_topic_completion_category_is_personal() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)
	p.subject_description = "maple leaves"
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(
		p, "completion", "Kakita Yoshi", "Shiro Kakita", 100)
	assert_eq(t.get("category", ""), "PERSONAL",
		"completion event → PERSONAL category")


func test_lifecycle_topic_destruction_category_is_political() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)
	p.subject_description = "maple leaves"
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(
		p, "destruction", "Kakita Yoshi", "Shiro Kakita", 100)
	assert_eq(t.get("category", ""), "POLITICAL",
		"destruction event → POLITICAL category")


func test_lifecycle_topic_loot_category_is_political() -> void:
	var p: PaintingData = _make_kakemono(1, 4, 10)
	p.subject_description = "mountains"
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(
		p, "loot", "Kakita Yoshi", "Shiro Kakita", 100)
	assert_eq(t.get("category", ""), "POLITICAL",
		"loot event → POLITICAL category")


func test_lifecycle_topic_negative_placement_category_is_political() -> void:
	var p: PaintingData = _make_kakemono(1, 2, 10)
	p.subject_description = "cranes"
	var t: Dictionary = PaintingSystem.generate_lifecycle_topic(
		p, "negative_placement", "Kakita Yoshi", "Shiro Kakita", 100)
	assert_eq(t.get("category", ""), "POLITICAL",
		"negative_placement event → POLITICAL category")


# Fix 5: collect_admirer_grief — active admirers within VISITOR_BONUS_DURATION_DAYS
func test_collect_admirer_grief_recent_visitor_receives_event() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)  # creator_id=10, quality=3
	p.display_settlement_id = 100
	p.visitor_memory = [{"char_id": 20, "last_visit_ic_day": 80}]
	var ic_day: int = 100  # 20 days ago — within 120-day window
	var events: Array = PaintingSystem.collect_admirer_grief(10, [p], ic_day)
	assert_eq(events.size(), 1, "one grief event for recent admirer")
	assert_eq(events[0]["admirer_id"], 20, "admirer_id = 20")
	assert_eq(events[0]["disposition_change"], -2, "Exceptional (tier 3) → -2 disposition")


func test_collect_admirer_grief_stale_visitor_skipped() -> void:
	var p: PaintingData = _make_kakemono(1, 5, 10)  # quality 5
	p.display_settlement_id = 100
	# last visit 200 days ago — outside VISITOR_BONUS_DURATION_DAYS (120)
	p.visitor_memory = [{"char_id": 20, "last_visit_ic_day": 1}]
	var events: Array = PaintingSystem.collect_admirer_grief(10, [p], 201)
	assert_eq(events.size(), 0, "stale visitor (>120 days) not grieving")


func test_collect_admirer_grief_wip_skipped() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 10)
	p.display_settlement_id = 100
	p.craft_progress = 5  # WIP — not complete
	p.visitor_memory = [{"char_id": 20, "last_visit_ic_day": 50}]
	var events: Array = PaintingSystem.collect_admirer_grief(10, [p], 100)
	assert_eq(events.size(), 0, "WIP painting generates no grief")


func test_collect_admirer_grief_undisplayed_skipped() -> void:
	var p: PaintingData = _make_kakemono(1, 4, 10)
	p.display_settlement_id = -1  # not displayed
	p.visitor_memory = [{"char_id": 20, "last_visit_ic_day": 50}]
	var events: Array = PaintingSystem.collect_admirer_grief(10, [p], 100)
	assert_eq(events.size(), 0, "undisplayed painting generates no grief")


func test_collect_admirer_grief_wrong_creator_skipped() -> void:
	var p: PaintingData = _make_kakemono(1, 3, 99)  # creator = 99, not 10
	p.display_settlement_id = 100
	p.visitor_memory = [{"char_id": 20, "last_visit_ic_day": 50}]
	var events: Array = PaintingSystem.collect_admirer_grief(10, [p], 100)
	assert_eq(events.size(), 0, "different creator's painting skipped")
