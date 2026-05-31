extends GutTest
## Tests for s57.28 Sculpture System.
## Covers: composition progress, completion, degradation, slot placement,
## permissions, worship FRs, visitor effects, wood degradation, lifecycle topics,
## sacking survival, world-gen helpers, death cleanup, constants.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_settlement(
		stype: Enums.SettlementType = Enums.SettlementType.TEMPLE,
		sid: int = 200,
		lord_id: int = 1,
) -> SettlementData:
	var s: SettlementData = SettlementData.new()
	s.settlement_id = sid
	s.settlement_type = stype
	s.lord_character_id = lord_id
	s.statue_slot = -1
	s.guardian_slot = -1
	s.statue_permissions = {}
	s.guardian_permissions = {}
	return s


func _make_statuary_wip(
		sculpture_id: int = 1,
		quality: int = 2,
		creator: int = 10,
		material: int = SculptureSystem.Material.WOOD,
		ic_day: int = 1,
) -> SculptureData:
	return SculptureSystem.declare_composition(
		SculptureSystem.Format.STATUARY,
		material,
		SculptureSystem.SubjectType.FORTUNE,
		5,  # subject_id (fortune_id)
		quality,
		creator,
		sculpture_id,
		ic_day,
	)


func _make_guardian_wip(
		sculpture_id: int = 2,
		quality: int = 2,
		creator: int = 10,
		ic_day: int = 1,
) -> SculptureData:
	return SculptureSystem.declare_composition(
		SculptureSystem.Format.GUARDIAN,
		SculptureSystem.Material.STONE,
		SculptureSystem.SubjectType.GUARDIAN_SPIRIT,
		-1,
		quality,
		creator,
		sculpture_id,
		ic_day,
	)


func _make_figurine_wip(
		sculpture_id: int = 3,
		quality: int = 1,
		creator: int = 10,
		ic_day: int = 1,
) -> SculptureData:
	return SculptureSystem.declare_composition(
		SculptureSystem.Format.FIGURINE,
		SculptureSystem.Material.WOOD,
		SculptureSystem.SubjectType.ANIMAL,
		-1,
		quality,
		creator,
		sculpture_id,
		ic_day,
		SculptureSystem.FigurineTheme.SEA_ANIMAL,
	)


func _complete_sculpture(sc: SculptureData) -> void:
	## Force sculpture to complete state.
	sc.craft_progress = -1
	sc.quality_tier = sc.target_quality_tier
	sc.date_completed = 100
	if sc.format == SculptureSystem.Format.GUARDIAN:
		sc.pair_intact = true


# ---------------------------------------------------------------------------
# 1. Constants
# ---------------------------------------------------------------------------

func test_compose_tn_is_15() -> void:
	assert_eq(SculptureSystem.COMPOSE_TN, 15)


func test_stone_tn_penalty_is_5() -> void:
	assert_eq(SculptureSystem.STONE_TN_PENALTY, 5)


func test_degradation_days_is_90() -> void:
	assert_eq(SculptureSystem.COMPOSITION_DEGRADATION_DAYS, 90)


func test_worship_fr_cap_is_5() -> void:
	assert_eq(SculptureSystem.WORSHIP_FR_CAP, 5)


func test_visitor_bonus_duration_is_120() -> void:
	assert_eq(SculptureSystem.VISITOR_BONUS_DURATION_DAYS, 120)


func test_mantis_figurine_fr_bonus_is_3() -> void:
	assert_eq(SculptureSystem.MANTIS_FIGURINE_FR_BONUS, 3)


# ---------------------------------------------------------------------------
# 2. declare_composition
# ---------------------------------------------------------------------------

func test_declare_composition_statuary_sets_wip_fields() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 2, 10, SculptureSystem.Material.WOOD, 50)
	assert_eq(sc.sculpture_id, 1)
	assert_eq(sc.format, SculptureSystem.Format.STATUARY)
	assert_eq(sc.material, SculptureSystem.Material.WOOD)
	assert_eq(sc.creator_id, 10)
	assert_eq(sc.target_quality_tier, 2)
	assert_eq(sc.craft_progress, 0)
	assert_eq(sc.ic_day_last_composition_ap, 50)
	assert_false(sc.pair_intact)


func test_declare_composition_guardian_sets_paired_flag() -> void:
	var sc: SculptureData = _make_guardian_wip(2, 3, 10, 1)
	assert_eq(sc.format, SculptureSystem.Format.GUARDIAN)
	assert_true(sc.paired)
	assert_false(sc.pair_intact)  # Not complete yet


func test_declare_composition_figurine_sets_theme() -> void:
	var sc: SculptureData = SculptureSystem.declare_composition(
		SculptureSystem.Format.FIGURINE,
		SculptureSystem.Material.WOOD,
		SculptureSystem.SubjectType.ANIMAL,
		-1,
		1,
		10,
		3,
		1,
		SculptureSystem.FigurineTheme.SEA_ANIMAL,
	)
	assert_eq(sc.theme, SculptureSystem.FigurineTheme.SEA_ANIMAL)


# ---------------------------------------------------------------------------
# 3. resolve_compose_sculpture — progress and completion
# ---------------------------------------------------------------------------

func test_resolve_compose_failure_no_progress() -> void:
	var sc: SculptureData = _make_statuary_wip()
	# Roll 10 < TN 15
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(2, sc, 10, 0, 5)
	assert_false(r["success"])
	assert_eq(r["progress_gained"], 0)
	assert_eq(sc.craft_progress, 0)


func test_resolve_compose_success_adds_progress() -> void:
	var sc: SculptureData = _make_statuary_wip()
	# Roll 25, TN 15 → margin 10 → progress = max(1, 25-15) = 10
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(2, sc, 25, 0, 5)
	assert_true(r["success"])
	assert_gt(r["progress_gained"], 0)
	assert_gt(sc.craft_progress, 0)


func test_resolve_compose_stone_increases_tn() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 1, 10, SculptureSystem.Material.STONE, 1)
	# TN = 15 + 5 (stone) = 20; roll 18 → failure
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(1, sc, 18, 0, 5)
	assert_false(r["success"])


func test_resolve_compose_stone_success_above_20() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 1, 10, SculptureSystem.Material.STONE, 1)
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(1, sc, 22, 0, 5)
	assert_true(r["success"])


func test_resolve_compose_stone_progress_uses_base_tn_not_effective() -> void:
	# GDD A2: progress = max(1, roll_total - 15). Stone adds +5 TN to check for success
	# but does NOT reduce progress on a successful roll.
	# Roll 30 on a stone sculpture (effective TN = 20): base = max(1, 30-15) = 15, not max(1, 30-20) = 10.
	var sc: SculptureData = _make_statuary_wip(1, 1, 0, SculptureSystem.Material.STONE, 1)
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(1, sc, 30, 0, 5)
	assert_true(r["success"])
	assert_eq(r["progress_gained"], 15)  # max(1, 30-15) = 15; not 10 (max(1, 30-20))


func test_resolve_compose_stone_progress_with_raises_uses_base_tn() -> void:
	# Roll 35 on stone with 2 raises: effective_tn = 20+10=30, success.
	# Progress = max(1, 35-15) + 2*5 = 20 + 10 = 30. Not max(1, 35-30)+10 = 1+10 = 11.
	var sc: SculptureData = _make_statuary_wip(2, 2, 0, SculptureSystem.Material.STONE, 1)
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(2, sc, 35, 2, 5)
	assert_true(r["success"])
	assert_eq(r["progress_gained"], 30)


func test_resolve_compose_skill_gate_blocks_below_rank() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 3, 10, SculptureSystem.Material.WOOD, 1)
	# quality tier 3 requires rank 3; sculptor rank 2
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(2, sc, 100, 0, 5)
	assert_true(r["blocked"])
	assert_eq(r["blocked_reason"], "insufficient_skill_rank")


func test_resolve_compose_already_complete_blocked() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(2, sc, 100, 0, 5)
	assert_true(r["blocked"])


func test_resolve_compose_completes_at_threshold() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 1, 10)
	# STATUARY tier-1 threshold = 20. Big roll ensures completion.
	var r: Dictionary = SculptureSystem.resolve_compose_sculpture(1, sc, 200, 0, 10)
	assert_true(r["completed"])
	assert_eq(sc.craft_progress, -1)
	assert_eq(sc.quality_tier, 1)
	assert_eq(sc.date_completed, 10)


func test_resolve_compose_guardian_sets_pair_intact_on_complete() -> void:
	var sc: SculptureData = _make_guardian_wip(2, 1, 10)
	SculptureSystem.resolve_compose_sculpture(1, sc, 200, 0, 15)
	assert_true(sc.pair_intact)


func test_resolve_compose_raises_improve_quality_on_completion() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 1, 10)
	# 2 raises on completion → quality bumped by min(raises, headroom)
	SculptureSystem.resolve_compose_sculpture(3, sc, 200, 2, 10)
	assert_gt(sc.quality_tier, 1)


func test_resolve_compose_updates_last_ap_day() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 1, 10, SculptureSystem.Material.WOOD, 1)
	SculptureSystem.resolve_compose_sculpture(1, sc, 20, 0, 99)
	assert_eq(sc.ic_day_last_composition_ap, 99)


# ---------------------------------------------------------------------------
# 4. apply_composition_degradation
# ---------------------------------------------------------------------------

func test_degradation_skips_figurines() -> void:
	var sc: SculptureData = _make_figurine_wip()
	sc.craft_progress = 10
	sc.ic_day_last_composition_ap = 1
	SculptureSystem.apply_composition_degradation(sc, 1000)
	assert_eq(sc.craft_progress, 10)


func test_degradation_skips_complete_sculpture() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	var result: int = SculptureSystem.apply_composition_degradation(sc, 1000)
	assert_eq(result, -1)


func test_degradation_fires_after_90_days() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 2, 10, SculptureSystem.Material.WOOD, 1)
	sc.craft_progress = 40
	SculptureSystem.apply_composition_degradation(sc, 91)
	assert_eq(sc.craft_progress, 20)  # halved


func test_degradation_does_not_fire_before_90_days() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 2, 10, SculptureSystem.Material.WOOD, 1)
	sc.craft_progress = 40
	SculptureSystem.apply_composition_degradation(sc, 89)
	assert_eq(sc.craft_progress, 40)


# ---------------------------------------------------------------------------
# 5. Slot eligibility and placement
# ---------------------------------------------------------------------------

func test_is_statue_eligible_temple_true() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE)
	assert_true(SculptureSystem.is_statue_eligible(s))


func test_is_statue_eligible_city_false() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.CITY)
	assert_false(SculptureSystem.is_statue_eligible(s))


func test_is_guardian_eligible_shinden_true() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.SHINDEN)
	assert_true(SculptureSystem.is_guardian_eligible(s))


func test_place_statuary_sets_slot() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	var settlement: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 200, 1)
	var r: Dictionary = SculptureSystem.place_sculpture(sc, settlement, 100)
	assert_true(r["success"])
	assert_eq(settlement.statue_slot, sc.sculpture_id)
	assert_eq(sc.display_settlement_id, 200)


func test_place_guardian_sets_guardian_slot() -> void:
	var sc: SculptureData = _make_guardian_wip()
	_complete_sculpture(sc)
	var settlement: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 200, 1)
	var r: Dictionary = SculptureSystem.place_sculpture(sc, settlement, 100)
	assert_true(r["success"])
	assert_eq(settlement.guardian_slot, sc.sculpture_id)


func test_place_ineligible_settlement_blocked() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	var settlement: SettlementData = _make_settlement(Enums.SettlementType.CITY, 300, 1)
	var r: Dictionary = SculptureSystem.place_sculpture(sc, settlement, 100)
	assert_false(r["success"])


func test_place_figurine_blocked() -> void:
	var sc: SculptureData = _make_figurine_wip()
	_complete_sculpture(sc)
	var settlement: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 200, 1)
	var r: Dictionary = SculptureSystem.place_sculpture(sc, settlement, 100)
	assert_false(r["success"])


func test_place_wip_blocked() -> void:
	var sc: SculptureData = _make_statuary_wip()
	sc.craft_progress = 10
	var settlement: SettlementData = _make_settlement()
	var r: Dictionary = SculptureSystem.place_sculpture(sc, settlement, 100)
	assert_false(r["success"])


func test_place_records_displaced_id() -> void:
	var sc_old: SculptureData = _make_statuary_wip(1, 1, 10)
	var sc_new: SculptureData = _make_statuary_wip(2, 2, 11)
	_complete_sculpture(sc_old)
	_complete_sculpture(sc_new)
	var settlement: SettlementData = _make_settlement()
	settlement.statue_slot = sc_old.sculpture_id
	var r: Dictionary = SculptureSystem.place_sculpture(sc_new, settlement, 100)
	assert_eq(r["displaced_sculpture_id"], sc_old.sculpture_id)


# ---------------------------------------------------------------------------
# 6. Permissions
# ---------------------------------------------------------------------------

func test_lord_has_statue_permission() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 200, 1)
	assert_true(SculptureSystem.has_statue_permission(1, s))


func test_non_lord_without_grant_lacks_permission() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 200, 1)
	assert_false(SculptureSystem.has_statue_permission(99, s))


func test_grant_statue_permission_works() -> void:
	var s: SettlementData = _make_settlement(Enums.SettlementType.TEMPLE, 200, 1)
	SculptureSystem.grant_statue_permission(s, 99)
	assert_true(SculptureSystem.has_statue_permission(99, s))


func test_grant_guardian_permission_works() -> void:
	var s: SettlementData = _make_settlement()
	SculptureSystem.grant_guardian_permission(s, 77)
	assert_true(SculptureSystem.has_guardian_permission(77, s))


# ---------------------------------------------------------------------------
# 7. Worship FRs
# ---------------------------------------------------------------------------

func test_statuary_worship_fr_tier1_is_0() -> void:
	assert_eq(SculptureSystem.statuary_worship_fr(1), 0)


func test_statuary_worship_fr_tier2_is_1() -> void:
	assert_eq(SculptureSystem.statuary_worship_fr(2), 1)


func test_statuary_worship_fr_tier5_is_2() -> void:
	assert_eq(SculptureSystem.statuary_worship_fr(5), 2)


func test_guardian_worship_fr_tier1_is_0() -> void:
	assert_eq(SculptureSystem.guardian_worship_fr(1), 0)


func test_guardian_worship_fr_tier3_is_1() -> void:
	assert_eq(SculptureSystem.guardian_worship_fr(3), 1)


func test_guardian_worship_fr_tier5_is_2() -> void:
	assert_eq(SculptureSystem.guardian_worship_fr(5), 2)


# ---------------------------------------------------------------------------
# 8. Guardian ward
# ---------------------------------------------------------------------------

func test_guardian_ward_intact_pair_tier3() -> void:
	assert_eq(SculptureSystem.guardian_ward_value(3, true), -3)


func test_guardian_ward_not_intact_is_zero() -> void:
	assert_eq(SculptureSystem.guardian_ward_value(3, false), 0)


# ---------------------------------------------------------------------------
# 9. Visitor effects
# ---------------------------------------------------------------------------

func test_visitor_effect_returns_disposition_change() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 2
	var r: Dictionary = SculptureSystem.apply_visitor_effect(50, sc, 1, 100)
	assert_eq(r.get("disposition_change", 0), 2)


func test_visitor_effect_immune_within_window() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 2
	# First visit at day 100
	SculptureSystem.apply_visitor_effect(50, sc, 1, 100)
	# Second visit at day 110 — within 120-day window → immune
	var r: Dictionary = SculptureSystem.apply_visitor_effect(50, sc, 1, 110)
	assert_true(r.get("immune", false))


func test_visitor_effect_not_immune_after_window() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 2
	SculptureSystem.apply_visitor_effect(50, sc, 1, 100)
	var r: Dictionary = SculptureSystem.apply_visitor_effect(50, sc, 2, 221)  # 121 days later
	assert_false(r.get("immune", false))
	assert_eq(r.get("disposition_change", 0), 2)


func test_glory_tick_fires_at_threshold() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 3
	var last_r: Dictionary = {}
	for i: int in range(SculptureSystem.GLORY_TICK_THRESHOLD):
		last_r = SculptureSystem.apply_visitor_effect(i + 100, sc, 1, i * 200)
	assert_true(last_r.get("glory_tick", false))


func test_no_visitor_effect_for_wip() -> void:
	var sc: SculptureData = _make_statuary_wip()
	var r: Dictionary = SculptureSystem.apply_visitor_effect(50, sc, 1, 100)
	assert_true(r.is_empty())


# ---------------------------------------------------------------------------
# 10. Wood guardian outdoor degradation
# ---------------------------------------------------------------------------

func test_wood_guardian_degrades_after_1800_days() -> void:
	var sc: SculptureData = SculptureSystem.gen_guardian(1, 3, SculptureSystem.Material.WOOD,
		SculptureSystem.SubjectType.GUARDIAN_SPIRIT, 200)
	sc.ic_day_placed_outdoor = 1
	var new_tier: int = SculptureSystem.apply_outdoor_degradation(sc, 1801)
	assert_lt(new_tier, 3)


func test_non_wood_guardian_no_degradation() -> void:
	var sc: SculptureData = SculptureSystem.gen_guardian(1, 3, SculptureSystem.Material.STONE,
		SculptureSystem.SubjectType.GUARDIAN_SPIRIT, 200)
	sc.ic_day_placed_outdoor = 1
	var new_tier: int = SculptureSystem.apply_outdoor_degradation(sc, 5000)
	assert_eq(new_tier, 3)


func test_degradation_no_fire_before_threshold() -> void:
	var sc: SculptureData = SculptureSystem.gen_guardian(1, 3, SculptureSystem.Material.WOOD,
		SculptureSystem.SubjectType.GUARDIAN_SPIRIT, 200)
	sc.ic_day_placed_outdoor = 1
	var new_tier: int = SculptureSystem.apply_outdoor_degradation(sc, 1799)
	assert_eq(new_tier, 3)


# ---------------------------------------------------------------------------
# 11. Lifecycle topic generation
# ---------------------------------------------------------------------------

func test_completion_topic_tier4_for_tier1() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 1
	var t: Dictionary = SculptureSystem.generate_lifecycle_topic(sc, "completion", "Test Shrine", 100)
	assert_eq(t.get("tier", -1), 3)  # TIER_4 = enum value 3


func test_completion_topic_tier2_for_tier5() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 5
	var t: Dictionary = SculptureSystem.generate_lifecycle_topic(sc, "completion", "Shrine", 100)
	assert_eq(t.get("tier", -1), 1)  # TIER_2 = enum value 1


func test_figurine_completion_always_tier4() -> void:
	var sc: SculptureData = _make_figurine_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 5
	var t: Dictionary = SculptureSystem.generate_lifecycle_topic(sc, "completion", "", 100)
	assert_eq(t.get("tier", -1), 3)  # TIER_4


func test_guardian_damage_topic_generated() -> void:
	var sc: SculptureData = _make_guardian_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 4
	var t: Dictionary = SculptureSystem.generate_lifecycle_topic(sc, "guardian_damage", "Temple", 50)
	assert_false(t.is_empty())
	assert_eq(t.get("topic_type", ""), "guardian_damaged")


func test_destruction_topic_includes_settlement_name() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 3
	sc.subject_description = "Fortune of Fire"
	var t: Dictionary = SculptureSystem.generate_lifecycle_topic(sc, "destruction", "Phoenix Temple", 200)
	assert_true(t.get("title", "").contains("Phoenix Temple"))


# ---------------------------------------------------------------------------
# 12. Sacking survival
# ---------------------------------------------------------------------------

func test_sacking_survival_wood_tier1_is_0_30() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 1
	sc.material = SculptureSystem.Material.WOOD
	assert_eq(SculptureSystem.sacking_survival_chance(sc), 0.30)


func test_sacking_survival_stone_bonus() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 1
	sc.material = SculptureSystem.Material.STONE
	var chance: float = SculptureSystem.sacking_survival_chance(sc)
	assert_gt(chance, 0.30)


func test_zone_destruction_wood_is_0() -> void:
	var sc: SculptureData = _make_statuary_wip()
	sc.material = SculptureSystem.Material.WOOD
	assert_eq(SculptureSystem.zone_destruction_survival_chance(sc), 0.0)


func test_zone_destruction_bronze_is_0_70() -> void:
	var sc: SculptureData = _make_statuary_wip()
	sc.material = SculptureSystem.Material.BRONZE
	assert_eq(SculptureSystem.zone_destruction_survival_chance(sc), 0.70)


# ---------------------------------------------------------------------------
# 13. World-gen helpers
# ---------------------------------------------------------------------------

func test_gen_statuary_creates_complete_sculpture() -> void:
	var sc: SculptureData = SculptureSystem.gen_statuary(
		10, 3, SculptureSystem.Material.STONE,
		SculptureSystem.SubjectType.FORTUNE, 7, 200)
	assert_eq(sc.sculpture_id, 10)
	assert_eq(sc.format, SculptureSystem.Format.STATUARY)
	assert_eq(sc.craft_progress, -1)
	assert_eq(sc.display_settlement_id, 200)
	assert_eq(sc.creator_id, -1)


func test_gen_guardian_creates_complete_pair() -> void:
	var sc: SculptureData = SculptureSystem.gen_guardian(
		11, 2, SculptureSystem.Material.STONE,
		SculptureSystem.SubjectType.GUARDIAN_SPIRIT, 200)
	assert_true(sc.paired)
	assert_true(sc.pair_intact)
	assert_eq(sc.craft_progress, -1)


func test_gen_figurine_sets_theme() -> void:
	var sc: SculptureData = SculptureSystem.gen_figurine(
		12, 2, SculptureSystem.SubjectType.ANIMAL,
		SculptureSystem.FigurineTheme.SEA_FORTUNE, 99)
	assert_eq(sc.format, SculptureSystem.Format.FIGURINE)
	assert_eq(sc.theme, SculptureSystem.FigurineTheme.SEA_FORTUNE)
	assert_eq(sc.subject_id, 99)


# ---------------------------------------------------------------------------
# 14. Death cleanup
# ---------------------------------------------------------------------------

func test_death_cleanup_marks_wip_abandoned() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 2, 10)
	sc.craft_progress = 15
	var sculptures: Array = [sc]
	SculptureSystem.handle_character_death(10, sculptures)
	assert_true(sc.abandoned_incomplete)


func test_death_cleanup_leaves_completed_intact() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 2, 10)
	_complete_sculpture(sc)
	var sculptures: Array = [sc]
	SculptureSystem.handle_character_death(10, sculptures)
	assert_false(sc.abandoned_incomplete)


func test_death_cleanup_ignores_other_creators() -> void:
	var sc: SculptureData = _make_statuary_wip(1, 2, 99)  # creator 99, not 10
	sc.craft_progress = 15
	var sculptures: Array = [sc]
	SculptureSystem.handle_character_death(10, sculptures)
	assert_false(sc.abandoned_incomplete)


# ---------------------------------------------------------------------------
# 15. Visitor glory gain keys
# ---------------------------------------------------------------------------

func test_visitor_effect_includes_creator_glory_gain() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 3
	for i: int in range(SculptureSystem.GLORY_TICK_THRESHOLD):
		var r: Dictionary = SculptureSystem.apply_visitor_effect(i + 100, sc, 1, i * 200)
		if r.get("glory_tick", false):
			assert_true(r.has("creator_glory_gain"))
			assert_true(r.has("daimyo_glory_gain"))
			assert_gt(r.get("creator_glory_gain", 0.0), 0.0)
			assert_gt(r.get("daimyo_glory_gain", 0.0), 0.0)
			return
	fail_test("glory tick never fired")


func test_visitor_effect_glory_zero_when_no_tick() -> void:
	var sc: SculptureData = _make_statuary_wip()
	_complete_sculpture(sc)
	sc.quality_tier = 2
	var r: Dictionary = SculptureSystem.apply_visitor_effect(42, sc, 1, 500)
	assert_eq(r.get("creator_glory_gain", 0.0), 0.0)
	assert_eq(r.get("daimyo_glory_gain", 0.0), 0.0)


# ---------------------------------------------------------------------------
# 16. Replacement pair threshold
# ---------------------------------------------------------------------------

func test_replacement_threshold_is_half_guardian() -> void:
	# Normal guardian threshold is 25; half is 12 (integer div).
	assert_eq(SculptureSystem.replacement_threshold(1), 12)


func test_replacement_threshold_exceptional() -> void:
	# Exceptional guardian threshold is 80; half is 40.
	assert_eq(SculptureSystem.replacement_threshold(3), 40)


func test_replacement_threshold_legendary() -> void:
	# Legendary guardian threshold is 150; half is 75.
	assert_eq(SculptureSystem.replacement_threshold(5), 75)


# ---------------------------------------------------------------------------
# 17. Yoritomo Sculptor technique
# ---------------------------------------------------------------------------

func test_has_yoritomo_figurine_bonus_true_for_school() -> void:
	assert_true(SculptureSystem.has_yoritomo_figurine_bonus("Yoritomo Sculptor"))


func test_has_yoritomo_figurine_bonus_false_for_other() -> void:
	assert_false(SculptureSystem.has_yoritomo_figurine_bonus("Doji Courtier"))
	assert_false(SculptureSystem.has_yoritomo_figurine_bonus(""))


# ---------------------------------------------------------------------------
# 18. Figurine collection topics
# ---------------------------------------------------------------------------

func _make_complete_figurine(sid: int, creator: int, theme: int) -> SculptureData:
	var sc: SculptureData = SculptureData.new()
	sc.sculpture_id = sid
	sc.format = SculptureSystem.Format.FIGURINE
	sc.creator_id = creator
	sc.quality_tier = 2
	sc.theme = theme
	sc.craft_progress = -1
	sc.date_completed = 1
	return sc


func test_collect_figurine_topics_no_topic_below_threshold() -> void:
	# 2 figurines — below the 3 required.
	var sculptures: Array = [
		_make_complete_figurine(1, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
		_make_complete_figurine(2, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
	]
	var topics: Array = SculptureSystem.collect_figurine_topics(sculptures, 100)
	assert_eq(topics.size(), 0)


func test_collect_figurine_topics_creator_cluster_fires() -> void:
	# 3 figurines by same creator → 1 topic.
	var sculptures: Array = [
		_make_complete_figurine(1, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
		_make_complete_figurine(2, 10, SculptureSystem.FigurineTheme.SAILING),
		_make_complete_figurine(3, 10, SculptureSystem.FigurineTheme.OTHER),
	]
	var topics: Array = SculptureSystem.collect_figurine_topics(sculptures, 100)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].get("tier"), 3)  # TIER_4
	assert_eq(topics[0].get("topic_type"), "figurine_collection")


func test_collect_figurine_topics_theme_cluster_fires_for_different_creators() -> void:
	# 3 figurines, same theme, different creators → 1 topic (theme-based).
	var sculptures: Array = [
		_make_complete_figurine(1, 10, SculptureSystem.FigurineTheme.SEA_FORTUNE),
		_make_complete_figurine(2, 11, SculptureSystem.FigurineTheme.SEA_FORTUNE),
		_make_complete_figurine(3, 12, SculptureSystem.FigurineTheme.SEA_FORTUNE),
	]
	var topics: Array = SculptureSystem.collect_figurine_topics(sculptures, 100)
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].get("topic_type"), "figurine_collection")


func test_collect_figurine_topics_wip_ignored() -> void:
	# WIP figurine should not count toward threshold.
	var sc_wip: SculptureData = _make_figurine_wip()
	sc_wip.craft_progress = 5  # Still in progress
	var sculptures: Array = [
		sc_wip,
		_make_complete_figurine(2, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
		_make_complete_figurine(3, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
	]
	var topics: Array = SculptureSystem.collect_figurine_topics(sculptures, 100)
	assert_eq(topics.size(), 0)  # Only 2 complete figurines by creator 10


func test_collect_figurine_topics_same_creator_no_duplicate() -> void:
	# 3 figurines same creator AND same theme — should generate only 1 topic, not 2.
	var sculptures: Array = [
		_make_complete_figurine(1, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
		_make_complete_figurine(2, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
		_make_complete_figurine(3, 10, SculptureSystem.FigurineTheme.SEA_ANIMAL),
	]
	var topics: Array = SculptureSystem.collect_figurine_topics(sculptures, 100)
	assert_eq(topics.size(), 1)


# ---------------------------------------------------------------------------
# Provenance investigation (locked section O)
# ---------------------------------------------------------------------------

func test_provenance_identification_tn_reduction_constant() -> void:
	# Section O: sculpture identification TNs are 5 lower than paintings.
	assert_eq(SculptureSystem.IDENTIFICATION_TN_REDUCTION, 5)


func test_provenance_identification_fr_rank_threshold() -> void:
	# Section O: Free Raise granted at Artisan: Sculpture rank 2+.
	assert_eq(SculptureSystem.IDENTIFICATION_FR_RANK, 2)


func test_provenance_identification_fr_bonus_value() -> void:
	# Section O: the Free Raise bonus is +1.
	assert_eq(SculptureSystem.IDENTIFICATION_FR_BONUS, 1)


func test_get_provenance_identification_fr_below_rank() -> void:
	# Rank 0 and rank 1 grant no Free Raise.
	assert_eq(SculptureSystem.get_provenance_identification_fr(0), 0)
	assert_eq(SculptureSystem.get_provenance_identification_fr(1), 0)


func test_get_provenance_identification_fr_at_rank_threshold() -> void:
	# Rank 2 is exactly the threshold — grants +1 FR.
	assert_eq(SculptureSystem.get_provenance_identification_fr(2), 1)


func test_get_provenance_identification_fr_above_rank() -> void:
	# Rank 3, 4, 5 all grant +1 FR (no stacking above threshold).
	assert_eq(SculptureSystem.get_provenance_identification_fr(3), 1)
	assert_eq(SculptureSystem.get_provenance_identification_fr(5), 1)


# ---------------------------------------------------------------------------
# MAINTAIN_SHRINE cultural motivation weights (locked section M)
# ---------------------------------------------------------------------------

func _make_scored_action(action_id: String) -> NPCDataStructures.ScoredAction:
	var sa: NPCDataStructures.ScoredAction = NPCDataStructures.ScoredAction.new()
	sa.action_id = action_id
	sa.disposition_modifier = 0.0
	sa.objective_alignment = 55.0
	sa.ap_cost = 1
	return sa


func _make_need_for_shrine() -> NPCDataStructures.ImmediateNeed:
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.need_type = "MAINTAIN_SHRINE"
	need.priority = 3
	return need


func _make_ctx_for_clan(clan_name: String) -> NPCDataStructures.ContextSnapshot:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDataStructures.ContextSnapshot.new()
	ctx.clan = clan_name
	ctx.character_id = 1
	ctx.honor = 5.0
	ctx.school = "Generic Shugenja"
	return ctx


func test_maintain_shrine_request_art_phoenix_bonus() -> void:
	# Phoenix gets +20 on REQUEST_ART under MAINTAIN_SHRINE (section M).
	var options: Array = [_make_scored_action("REQUEST_ART")]
	var need: NPCDataStructures.ImmediateNeed = _make_need_for_shrine()
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan("Phoenix")
	var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
		"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
		"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
	NPCDecisionEngine.score_all(options, need, ctx, tables)
	assert_eq(options[0].disposition_modifier, 20.0)


func test_maintain_shrine_request_art_crab_bonus() -> void:
	# Crab gets +10 on REQUEST_ART under MAINTAIN_SHRINE (section M).
	var options: Array = [_make_scored_action("REQUEST_ART")]
	var need: NPCDataStructures.ImmediateNeed = _make_need_for_shrine()
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan("Crab")
	var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
		"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
		"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
	NPCDecisionEngine.score_all(options, need, ctx, tables)
	assert_eq(options[0].disposition_modifier, 10.0)


func test_maintain_shrine_request_art_lion_bonus() -> void:
	# Lion gets +10 on REQUEST_ART under MAINTAIN_SHRINE (section M).
	var options: Array = [_make_scored_action("REQUEST_ART")]
	var need: NPCDataStructures.ImmediateNeed = _make_need_for_shrine()
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan("Lion")
	var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
		"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
		"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
	NPCDecisionEngine.score_all(options, need, ctx, tables)
	assert_eq(options[0].disposition_modifier, 10.0)


func test_maintain_shrine_request_art_dragon_bonus() -> void:
	# Dragon gets +5 on REQUEST_ART under MAINTAIN_SHRINE (section M).
	var options: Array = [_make_scored_action("REQUEST_ART")]
	var need: NPCDataStructures.ImmediateNeed = _make_need_for_shrine()
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan("Dragon")
	var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
		"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
		"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
	NPCDecisionEngine.score_all(options, need, ctx, tables)
	assert_eq(options[0].disposition_modifier, 5.0)


func test_maintain_shrine_request_art_other_clan_no_bonus() -> void:
	# Crane, Scorpion, Unicorn get no bonus on REQUEST_ART under MAINTAIN_SHRINE (section M).
	for clan_name: String in ["Crane", "Scorpion", "Unicorn"]:
		var options: Array = [_make_scored_action("REQUEST_ART")]
		var need: NPCDataStructures.ImmediateNeed = _make_need_for_shrine()
		var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan(clan_name)
		var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
			"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
			"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
		NPCDecisionEngine.score_all(options, need, ctx, tables)
		assert_eq(options[0].disposition_modifier, 0.0,
			"Expected no bonus for %s" % clan_name)


func test_maintain_shrine_cultural_bonus_only_for_request_art() -> void:
	# Cultural bonus does NOT apply to other actions under MAINTAIN_SHRINE.
	var options: Array = [_make_scored_action("COMPOSE_SCULPTURE")]
	var need: NPCDataStructures.ImmediateNeed = _make_need_for_shrine()
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan("Phoenix")
	var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
		"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
		"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
	NPCDecisionEngine.score_all(options, need, ctx, tables)
	assert_eq(options[0].disposition_modifier, 0.0)


func test_maintain_shrine_cultural_bonus_only_for_maintain_shrine_needtype() -> void:
	# Cultural bonus does NOT fire for REQUEST_ART under a different NeedType.
	var options: Array = [_make_scored_action("REQUEST_ART")]
	var need: NPCDataStructures.ImmediateNeed = NPCDataStructures.ImmediateNeed.new()
	need.need_type = "ARTISTIC_EXPRESSION"
	need.priority = 3
	var ctx: NPCDataStructures.ContextSnapshot = _make_ctx_for_clan("Phoenix")
	var tables: Dictionary = {"objective_alignment": {}, "personality_lean": {},
		"competence_table": {}, "disposition_tiers": {}, "urgency_rules": {},
		"topic_position_alignment": {}, "personality_filter": {"bushido": {}, "shourido": {}}}
	NPCDecisionEngine.score_all(options, need, ctx, tables)
	assert_eq(options[0].disposition_modifier, 0.0)
