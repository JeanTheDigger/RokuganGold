extends GutTest
## GUT tests for KolatExecutor (simulation/kolat_executor.gd). GDD s54.7c / s54.7j.


func _coin(id: int = 1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.willpower = 3; c.intelligence = 4; c.perception = 3
	c.skills = {"Medicine": 4, "Temptation": 6}
	return c


func _temple(vault: int = 100) -> SettlementData:
	var s := SettlementData.new()
	s.temple_vault_koku = vault
	return s


func _dice() -> DiceEngine:
	return DiceEngine.new(11)


# === Koku ===

func test_launder() -> void:
	var coin := _coin()
	coin.dirty_koku = 12
	var r := KolatExecutor.execute("LAUNDER_KOKU", coin, {}, _dice())
	assert_true(r["ok"])
	assert_eq(r["laundered"], 5)
	assert_eq(coin.kolat_koku, 5)
	assert_eq(coin.dirty_koku, 7)
	assert_eq(r["action"], "LAUNDER_KOKU")


func test_underreport_requires_amount() -> void:
	var coin := _coin()
	assert_false(KolatExecutor.execute("UNDERREPORT_KOKU", coin, {}, _dice())["ok"])
	var r := KolatExecutor.execute("UNDERREPORT_KOKU", coin, {"amount": 8}, _dice())
	assert_true(r["ok"])
	assert_eq(coin.dirty_koku, 8)


func test_transfer_to_vault() -> void:
	var coin := _coin(); coin.kolat_koku = 30
	var temple := _temple(100)
	var r := KolatExecutor.execute("TRANSFER_KOLAT_FUNDS", coin, {"temple": temple, "amount": 25}, _dice())
	assert_true(r["ok"])
	assert_eq(r["transferred"], 25)
	assert_eq(temple.temple_vault_koku, 125)


func test_contribute_to_reserve_skims() -> void:
	var coin := _coin()
	var r := KolatExecutor.execute("CONTRIBUTE_TO_RESERVE", coin, {"commerce_yield": 10.4, "skim_rate": 0.25}, _dice())
	assert_eq(r["diverted"], 2, "floor(10.4 * 0.25) = 2")
	assert_eq(coin.dirty_koku, 2)


# === Sleeper ===

func test_conduct_conditioning_resolves_session() -> void:
	var dream := _coin(); dream.skills = {"Temptation": 8}; dream.intelligence = 5
	var target := _coin(2); target.willpower = 1
	var r := KolatExecutor.execute("CONDUCT_CONDITIONING", dream, {"target": target}, _dice())
	assert_true(r["ok"])
	assert_true(r.has("progressed"))
	assert_eq(r["sessions_required"], 3, "Willpower 1 × 3")


func test_maintain_sleeper_contact() -> void:
	var dream := _coin()
	var sleeper := _coin(2)
	KolatSystem.complete_conditioning(sleeper, dream, "phrase", {"need": "X"})
	sleeper.conditioning_stability = 80.0
	var r := KolatExecutor.execute("MAINTAIN_SLEEPER_CONTACT", dream, {"sleeper": sleeper}, _dice())
	assert_true(r["ok"])
	assert_eq(r["conditioning_stability"], 90.0, "+10 restore")


func test_activate_sleeper() -> void:
	var dream := _coin()
	var sleeper := _coin(2)
	KolatSystem.complete_conditioning(sleeper, dream, "the tide turns", {"need": "ELIMINATE"})
	var r := KolatExecutor.execute("ACTIVATE_SLEEPER", dream, {"sleeper": sleeper, "spoken_phrase": "the tide turns"}, _dice())
	assert_true(r["ok"])
	assert_false(sleeper.active_sleeper_command.is_empty())
	# Wrong phrase fails.
	var sleeper2 := _coin(3)
	KolatSystem.complete_conditioning(sleeper2, dream, "correct", {"need": "X"})
	assert_false(KolatExecutor.execute("ACTIVATE_SLEEPER", dream, {"sleeper": sleeper2, "spoken_phrase": "wrong"}, _dice())["ok"])


# === Dead drops ===

func test_establish_and_visit_dead_drop() -> void:
	var lotus := _coin()
	var est := KolatExecutor.execute("ESTABLISH_DEAD_DROP", lotus, {"concealment": 1}, _dice())
	var drop: Dictionary = est["drop"]
	assert_eq(drop["concealment"], 1)
	# 4th visit drops concealment to 0 → abandoned.
	for i: int in range(4):
		KolatExecutor.execute("CHECK_DEAD_DROP", lotus, {"drop": drop}, _dice())
	assert_true(drop["abandoned"])


# === Disruption ===

func test_sponsor_insurgency_deducts_reserve() -> void:
	var coin := _coin(); coin.kolat_koku = 40
	var r := KolatExecutor.execute("SPONSOR_INSURGENCY", coin, {"strength": 3}, _dice())
	assert_true(r["ok"])
	assert_eq(r["cost"], 30)
	assert_eq(coin.kolat_koku, 10)
	# Insufficient funds fails.
	assert_false(KolatExecutor.execute("SPONSOR_INSURGENCY", coin, {"strength": 3}, _dice())["ok"])


func test_sponsor_insurgency_from_vault() -> void:
	var coin := _coin()
	var temple := _temple(50)
	var r := KolatExecutor.execute("SPONSOR_INSURGENCY", coin, {"strength": 2, "temple": temple}, _dice())
	assert_true(r["ok"])
	assert_eq(temple.temple_vault_koku, 30, "20 drawn from the vault when at-temple")


func test_bribe_garrison_pays_and_rolls() -> void:
	var coin := _coin(); coin.kolat_koku = 5
	coin.skills = {"Commerce": 8}
	var commander := _coin(2); commander.willpower = 2  # TN 10
	var r := KolatExecutor.execute("BRIBE_GARRISON_COMMANDER", coin, {"target": commander}, _dice())
	assert_true(r["ok"])
	assert_eq(r["cost"], 5)
	assert_eq(coin.kolat_koku, 0, "first installment paid")
	assert_true(r.has("bribe_established"))
	assert_true(r.has("creates_threat_topic"))


func test_bribe_garrison_requires_commander() -> void:
	var coin := _coin(); coin.kolat_koku = 5
	var r := KolatExecutor.execute("BRIBE_GARRISON_COMMANDER", coin, {}, _dice())
	assert_false(r["ok"], "no commander target")


# === Cloud archive / topic (s54.7c) ===

func _topic(id: int = 50) -> TopicData:
	var t := TopicData.new()
	t.topic_id = id
	t.title = "Crane scandal"
	t.tier = TopicData.Tier.TIER_2
	t.category = TopicData.Category.POLITICAL
	t.subject_character_id = 9
	t.momentum = 40.0
	t.ic_day_created = 100
	return t


func test_archive_topic_requires_topic() -> void:
	var cloud := _coin()
	assert_false(KolatExecutor.execute("ARCHIVE_TOPIC", cloud, {}, _dice())["ok"])


func test_archive_topic_stores_snapshot() -> void:
	var cloud := _coin()
	var r := KolatExecutor.execute("ARCHIVE_TOPIC", cloud, {"topic": _topic(50), "leverage_value": 3, "ic_day": 200}, _dice())
	assert_true(r["ok"])
	assert_eq(r["archived_topic_id"], 50)
	assert_eq(r["archive_id"], "arc_50")
	# s54.7h cloud_archive: keyed by archive_id, with the locked sub-dict fields.
	var entry: Dictionary = KolatNetwork.get_archived_topic(cloud, 50)
	assert_eq(entry["tier"], int(TopicData.Tier.TIER_2))
	assert_eq(entry["leverage_value"], 3)
	assert_eq(entry["content_summary"], "Crane scandal")
	assert_eq(entry["ic_day_archived"], 200)
	assert_eq(entry["parties_named"], [9])


func test_anonymous_tip_requires_org_and_subject() -> void:
	var jade := _coin()
	assert_false(KolatExecutor.execute("ANONYMOUS_TIP", jade, {}, _dice())["ok"])
	assert_false(KolatExecutor.execute("ANONYMOUS_TIP", jade, {"tip_org": "Kuni Witch Hunters"}, _dice())["ok"])


func test_anonymous_tip_returns_topic_flags() -> void:
	var jade := _coin()
	var r := KolatExecutor.execute("ANONYMOUS_TIP", jade,
		{"tip_org": "Kuni Witch Hunters", "tip_subject": "Asako Tadaji", "tip_subject_id": 7}, _dice())
	assert_true(r["ok"])
	assert_true(r["creates_anon_tip"])
	assert_eq(r["tip_subject_id"], 7)


func test_resurrect_topic_requires_archived_entry() -> void:
	var cloud := _coin()
	var r := KolatExecutor.execute("RESURRECT_TOPIC", cloud, {"archive_topic_id": 50}, _dice())
	assert_false(r["ok"], "no archived topic with that id")


func test_resurrect_topic_reinjects_and_costs_honor() -> void:
	var cloud := _coin()
	cloud.skills = {"Calligraphy": 5}
	KolatExecutor.execute("ARCHIVE_TOPIC", cloud, {"topic": _topic(50)}, _dice())
	var r := KolatExecutor.execute("RESURRECT_TOPIC", cloud, {"archive_topic_id": 50}, _dice())
	assert_true(r["ok"])
	assert_true(r["resurrects_topic"])
	assert_eq(r["honor_loss"], 0.5)
	assert_eq(r["archive_entry"]["topic_id"], 50)


func test_sponsor_insurgency_returns_seed_flags() -> void:
	var coin := _coin(); coin.kolat_koku = 40
	var r := KolatExecutor.execute("SPONSOR_INSURGENCY", coin, {"strength": 1}, _dice())
	assert_true(r["ok"])
	assert_true(r["seeds_insurgency"])
	assert_true(r.has("routing_detected"))
	assert_true(r.has("compromised"))


# === Silk / Jade courier routing (s54.7c) ===

func test_deliver_sealed_letter_requires_recipient() -> void:
	var silk := _coin()
	assert_false(KolatExecutor.execute("DELIVER_SEALED_LETTER", silk, {}, _dice())["ok"])


func test_deliver_sealed_letter_returns_flags() -> void:
	var silk := _coin(); silk.skills = {"Sincerity": 6}
	var r := KolatExecutor.execute("DELIVER_SEALED_LETTER", silk,
		{"recipient_id": 12, "payload_topic_id": 88}, _dice())
	assert_true(r["ok"])
	assert_true(r["delivers_letter"])
	assert_eq(r["recipient_id"], 12)
	assert_eq(r["payload_topic_id"], 88)
	assert_true(r.has("courier_noticed"))


func test_route_anonymous_intelligence_requires_target() -> void:
	var jade := _coin()
	assert_false(KolatExecutor.execute("ROUTE_ANONYMOUS_INTELLIGENCE", jade, {}, _dice())["ok"])


func test_route_anonymous_intelligence_asset_gain() -> void:
	var jade := _coin(); jade.skills = {"Calligraphy": 8}  # easily beats TN 15
	var r := KolatExecutor.execute("ROUTE_ANONYMOUS_INTELLIGENCE", jade, {"asset_id": 4}, _dice())
	assert_true(r["ok"])
	assert_true(r["routes_anon_intel"])
	assert_eq(r["asset_id"], 4)
	assert_true(r.has("asset_disposition_gain"))


# === Still-deferred actions ===

func test_topic_spell_actions_deferred() -> void:
	var coin := _coin()
	for a: String in ["USE_CLOUDS_EYES", "DISTRIBUTE_INTELLIGENCE", "TRANSMIT_VIA_TEAR", "OBSERVE_VIA_EYE"]:
		var r := KolatExecutor.execute(a, coin, {}, _dice())
		assert_false(r["ok"], a + " is deferred")
		assert_eq(r["reason"], "deferred_system")
