extends GutTest
## GUT tests for KolatNetwork (simulation/kolat_network.gd). GDD s54.7h / s54.7d.


func _master(id: int = 1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.is_kolat_master = true
	return c


func _topic(id: int = 70) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.title = "Lion border raid"
	t.tier = TopicData.Tier.TIER_2
	t.category = TopicData.Category.MILITARY
	t.subject_character_id = 9
	t.clan_involved = "Lion"
	t.momentum = 40.0
	return t


# === Field mapping ===

func test_network_field_for_sect() -> void:
	assert_eq(KolatNetwork.network_field_for_sect("kolat_silk"), "silk_network_record")
	assert_eq(KolatNetwork.network_field_for_sect("kolat_jade"), "jade_asset_network")
	assert_eq(KolatNetwork.network_field_for_sect("kolat_dream"), "", "Dream uses the sleeper registry, not a network record")
	assert_eq(KolatNetwork.network_field_for_sect("kolat_roc"), "")


# === Registration + capacity ===

func test_register_silk_operative() -> void:
	var silk := _master()
	assert_true(KolatNetwork.register_silk_operative(silk, "Heron", 12, "Lion court courtier", 100))
	var rec := KolatNetwork.get_network(silk, "kolat_silk")
	assert_true(rec.has("Heron"))
	assert_eq(rec["Heron"]["npc_id"], 12)
	assert_eq(rec["Heron"]["operative_status"], "active")
	assert_eq(KolatNetwork.find_code_name_by_npc_id(silk, "kolat_silk", 12), "Heron")


func test_capacity_cap_six() -> void:
	var silk := _master()
	for i: int in range(KolatNetwork.MAX_AGENTS):
		assert_true(KolatNetwork.register_silk_operative(silk, "op%d" % i, 100 + i, "merchant", 10))
	assert_true(KolatNetwork.at_capacity(silk, "kolat_silk"))
	assert_eq(KolatNetwork.agent_count(silk, "kolat_silk"), 6)
	# 7th refused.
	assert_false(KolatNetwork.register_silk_operative(silk, "overflow", 200, "merchant", 10))


func test_burned_excluded_from_capacity() -> void:
	var silk := _master()
	for i: int in range(KolatNetwork.MAX_AGENTS):
		KolatNetwork.register_silk_operative(silk, "op%d" % i, 100 + i, "merchant", 10)
	# Burn one — capacity opens up (burned entries do not count, s54.7d).
	silk.special_data["silk_network_record"]["op0"]["operative_status"] = "burned"
	assert_eq(KolatNetwork.agent_count(silk, "kolat_silk"), 5)
	assert_false(KolatNetwork.at_capacity(silk, "kolat_silk"))


func test_jade_cap_three() -> void:
	var jade := _master()
	assert_true(KolatNetwork.register_jade_asset(jade, "a", 1, "Kuni Witch Hunters", "Crab lands"))
	assert_true(KolatNetwork.register_jade_asset(jade, "b", 2, "Jade Magistrates", "Phoenix lands"))
	assert_true(KolatNetwork.register_jade_asset(jade, "c", 3, "Phoenix Inquisitors", "Dragon lands"))
	assert_false(KolatNetwork.register_jade_asset(jade, "d", 4, "Jade Magistrates", "Lion lands"),
		"Jade asset network caps at 3")


# === Sleeper registry ===

func test_register_sleeper() -> void:
	var dream := _master()
	KolatNetwork.register_sleeper(dream, "slp_1", 22, "the tide turns", "ELIMINATE: Lord Akodo", 100, true)
	var reg: Dictionary = dream.special_data["dream_sleeper_registry"]
	assert_true(reg.has("slp_1"))
	assert_eq(reg["slp_1"]["sleeper_status"], "dormant")
	assert_eq(reg["slp_1"]["conditioning_stability"], 100.0)
	assert_true(reg["slp_1"]["tiger_requested"])


# === Silence detection ===

func test_silence_overdue() -> void:
	# City threshold 30: silent 31 days → overdue.
	var entry := {"last_report_ic_day": 100, "threshold": 30}
	assert_true(KolatNetwork.silence_overdue(entry, 131))
	assert_false(KolatNetwork.silence_overdue(entry, 130))
	# Never-contacted (sentinel) is not overdue.
	assert_false(KolatNetwork.silence_overdue({"last_report_ic_day": -1, "threshold": 30}, 999))


# === Cloud archive (s54.7h schema) ===

func test_archive_and_retrieve_topic() -> void:
	var cloud := _master()
	var aid := KolatNetwork.archive_topic(cloud, _topic(70), 200, 3)
	assert_eq(aid, "arc_70")
	var entry := KolatNetwork.get_archived_topic(cloud, 70)
	assert_eq(entry["topic_id"], 70)
	assert_eq(entry["content_summary"], "Lion border raid")
	assert_eq(entry["parties_named"], [9])
	assert_eq(entry["original_momentum"], 40)
	assert_eq(entry["ic_day_archived"], 200)
	assert_eq(entry["leverage_value"], 3)
	assert_eq(entry["clan_involved"], "Lion", "reconstruction extra retained")


func test_get_archived_topic_missing() -> void:
	var cloud := _master()
	assert_true(KolatNetwork.get_archived_topic(cloud, 999).is_empty())


func test_leverage_value_clamped() -> void:
	var cloud := _master()
	KolatNetwork.archive_topic(cloud, _topic(71), 10, 9)  # over-range
	assert_eq(KolatNetwork.get_archived_topic(cloud, 71)["leverage_value"], 3)
