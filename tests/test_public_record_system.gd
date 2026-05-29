extends GutTest
## Tests for PublicRecordSystem per GDD s57.50.


func _make_settlement(id: int = 1) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = id
	s.settlement_name = "Test Settlement"
	return s


func _seed(settlement: SettlementData, tier: int, ic_day: int, topic_id: int = -1) -> void:
	PublicRecordSystem.seed_event(
		settlement, "violence", tier, ic_day, topic_id, 42
	)


# -- Seeding ------------------------------------------------------------------

func test_seed_adds_entry():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	assert_eq(s.public_record.size(), 1)


func test_seed_stores_all_fields():
	var s := _make_settlement()
	PublicRecordSystem.seed_event(s, "violence", TopicData.Tier.TIER_4, 100, 55, 7, "MARKET_STREET")
	var entry: Dictionary = s.public_record[0]
	assert_eq(entry["event_type"], "violence")
	assert_eq(entry["tier"], TopicData.Tier.TIER_4)
	assert_eq(entry["ic_day"], 100)
	assert_eq(entry["topic_id"], 55)
	assert_eq(entry["subject_id"], 7)
	assert_eq(entry["zone_subtype"], "MARKET_STREET")


func test_seed_multiple_entries():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	_seed(s, TopicData.Tier.TIER_3, 200)
	assert_eq(s.public_record.size(), 2)


# -- Ambient Window -----------------------------------------------------------

func test_tier4_ambient_within_14_days():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	var ambient := PublicRecordSystem.get_ambient_events(s, 113)  # 13 days later
	assert_eq(ambient.size(), 1)


func test_tier4_not_ambient_after_14_days():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	var ambient := PublicRecordSystem.get_ambient_events(s, 115)  # 15 days later
	assert_eq(ambient.size(), 0)


func test_tier3_ambient_within_90_days():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_3, 100)
	var ambient := PublicRecordSystem.get_ambient_events(s, 189)  # 89 days later
	assert_eq(ambient.size(), 1)


func test_tier3_not_ambient_after_90_days():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_3, 100)
	var ambient := PublicRecordSystem.get_ambient_events(s, 191)  # 91 days later
	assert_eq(ambient.size(), 0)


func test_tier1_always_ambient():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_1, 100)
	var ambient := PublicRecordSystem.get_ambient_events(s, 10000)  # very old
	assert_eq(ambient.size(), 1)


# -- Investigation TN ---------------------------------------------------------

func test_investigation_tn_within_ambient_not_applicable():
	# Within ambient window: ambient path handles it, not investigation
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	var results := PublicRecordSystem.query_by_investigation(s, 5, 110)
	assert_eq(results.size(), 0)  # still ambient, not returned by investigation path


func test_investigation_tn_just_past_ambient_base_10():
	var entry: Dictionary = {"tier": TopicData.Tier.TIER_4, "ic_day": 100}
	var tn: int = PublicRecordSystem.get_investigation_tn(entry, 114 + 1)  # 1 day past window
	assert_eq(tn, 10)  # base TN, less than 10 days past window


func test_investigation_tn_rises_with_age():
	var entry: Dictionary = {"tier": TopicData.Tier.TIER_4, "ic_day": 100}
	var tn_20: int = PublicRecordSystem.get_investigation_tn(entry, 114 + 20)  # 20 days past
	assert_eq(tn_20, 12)  # 10 + floor(20/10)


func test_investigation_tn_capped_at_30():
	var entry: Dictionary = {"tier": TopicData.Tier.TIER_4, "ic_day": 100}
	# 14 + 200 = 214 days past seed date → 200 days past window → TN = 10 + 20 = 30
	var tn: int = PublicRecordSystem.get_investigation_tn(entry, 314)
	assert_eq(tn, 30)
	# Even older should still cap at 30
	var tn_old: int = PublicRecordSystem.get_investigation_tn(entry, 1000)
	assert_eq(tn_old, 30)


func test_investigation_query_success():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100, 99)
	# Query at day 125 (11 days past ambient window of 14) → TN = 10
	var results := PublicRecordSystem.query_by_investigation(s, 20, 125)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["topic_id"], 99)


func test_investigation_query_fail_low_roll():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	# Query at day 200 (86 days past window) → TN = 10 + floor(86/10) = 18
	var results := PublicRecordSystem.query_by_investigation(s, 15, 200)
	assert_eq(results.size(), 0)


# -- Purge Expired Entries ----------------------------------------------------

func test_purge_removes_expired_tier4():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	PublicRecordSystem.purge_expired(s, 100 + 91)  # 1 day past 90-day retention
	assert_eq(s.public_record.size(), 0)


func test_purge_keeps_tier4_within_retention():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)
	PublicRecordSystem.purge_expired(s, 100 + 89)  # 1 day before expiry
	assert_eq(s.public_record.size(), 1)


func test_purge_keeps_tier3_within_retention():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_3, 100)
	PublicRecordSystem.purge_expired(s, 100 + 359)  # 1 day before 360-day expiry
	assert_eq(s.public_record.size(), 1)


func test_purge_removes_tier3_expired():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_3, 100)
	PublicRecordSystem.purge_expired(s, 100 + 361)
	assert_eq(s.public_record.size(), 0)


func test_purge_never_removes_tier1():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_1, 100)
	PublicRecordSystem.purge_expired(s, 100 + 99999)
	assert_eq(s.public_record.size(), 1)


func test_purge_selective_mixed_tiers():
	var s := _make_settlement()
	_seed(s, TopicData.Tier.TIER_4, 100)   # expires at 190
	_seed(s, TopicData.Tier.TIER_3, 100)   # expires at 460
	_seed(s, TopicData.Tier.TIER_1, 100)   # permanent
	PublicRecordSystem.purge_expired(s, 100 + 91)  # TIER_4 expires, others survive
	assert_eq(s.public_record.size(), 2)
	for entry: Variant in s.public_record:
		assert_ne((entry as Dictionary).get("tier", -1), TopicData.Tier.TIER_4)
