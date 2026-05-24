extends GutTest
## Tests for SentencingSystem per GDD s11.3.15.


func _make_daimyo(virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE, shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE) -> L5RCharacterData:
	var d := L5RCharacterData.new()
	d.character_id = 1
	d.bushido_virtue = virtue
	d.shourido_virtue = shourido
	return d


func _make_record(crime_type: Enums.CrimeType = Enums.CrimeType.VIOLENCE) -> CrimeRecord:
	var r := CrimeRecord.new()
	r.crime_type = crime_type
	r.perpetrator_id = 99
	return r


# -- Personality Base Tests ----

func test_jin_gives_positive_30():
	var d := _make_daimyo(Enums.BushidoVirtue.JIN)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, 30, "JIN personality base should be +30")


func test_kanpeki_gives_negative_20():
	var d := _make_daimyo(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KANPEKI)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, -20, "KANPEKI personality base should be -20")


func test_yu_gives_negative_10():
	var d := _make_daimyo(Enums.BushidoVirtue.YU)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, -10, "YU personality base should be -10")


func test_makoto_gives_positive_10():
	var d := _make_daimyo(Enums.BushidoVirtue.MAKOTO)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, 10, "MAKOTO personality base should be +10")


# -- Gi Override ----

func test_gi_override_ignores_all_modifiers():
	var d := _make_daimyo(Enums.BushidoVirtue.GI)
	d.disposition_values[99] = 80
	var leniency := SentencingSystem.calculate_leniency(d, 99, TopicData.Tier.TIER_1, true, true)
	assert_eq(leniency, 0, "GI daimyo always returns 0 leniency regardless of context")


func test_gi_override_flagged_in_result():
	var d := _make_daimyo(Enums.BushidoVirtue.GI)
	var r := _make_record()
	var result := SentencingSystem.select_punishment(d, r)
	assert_true(result["gi_override"], "Result should flag GI override")


# -- Disposition Modifier Tests ----

func test_disposition_friend_gives_plus_20():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	d.disposition_values[99] = 60
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, 20, "CHUGI(0) + Friend disposition(+20) = 20")


func test_disposition_enemy_gives_minus_20():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	d.disposition_values[99] = -50
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, -20, "CHUGI(0) + Enemy disposition(-20) = -20")


func test_disposition_neutral_gives_zero():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	d.disposition_values[99] = 5
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, 0, "CHUGI(0) + Neutral disposition(0) = 0")


# -- Pressure Modifier Tests ----

func test_tier_2_topic_gives_minus_20():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	var leniency := SentencingSystem.calculate_leniency(d, 99, TopicData.Tier.TIER_2, false, false)
	assert_eq(leniency, -20, "Tier 2 topic pressure = -20")


func test_tier_1_cross_clan_pushing_gives_max_pressure():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	var leniency := SentencingSystem.calculate_leniency(d, 99, TopicData.Tier.TIER_1, true, true)
	# -30 (tier 1) + -10 (cross clan) + -15 (pushing) = -55
	assert_eq(leniency, -55, "Max pressure: tier 1 + cross clan + pushing = -55")


func test_no_topic_no_pressure():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false)
	assert_eq(leniency, 0, "No topic = no pressure")


# -- Seigyo Special Case ----

func test_seigyo_useful_convicted_gives_plus_20():
	var d := _make_daimyo(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false, 20)
	assert_eq(leniency, 20, "SEIGYO with useful convicted = +20")


func test_seigyo_liability_gives_minus_20():
	var d := _make_daimyo(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false, -20)
	assert_eq(leniency, -20, "SEIGYO with liability convicted = -20")


func test_seigyo_clamped_to_bounds():
	var d := _make_daimyo(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	var leniency := SentencingSystem.calculate_leniency(d, 99, -1, false, false, 50)
	assert_eq(leniency, 20, "SEIGYO clamped at +20 max")


# -- Leniency to Punishment Level ----

func test_leniency_30_plus_lightest():
	var level := SentencingSystem._leniency_to_level(30)
	assert_eq(level, SentencingSystem.PunishmentLevel.LIGHTEST)


func test_leniency_10_to_29_light():
	var level := SentencingSystem._leniency_to_level(15)
	assert_eq(level, SentencingSystem.PunishmentLevel.LIGHT)


func test_leniency_minus10_to_9_standard():
	var level := SentencingSystem._leniency_to_level(0)
	assert_eq(level, SentencingSystem.PunishmentLevel.STANDARD)


func test_leniency_minus30_to_minus11_harsh():
	var level := SentencingSystem._leniency_to_level(-20)
	assert_eq(level, SentencingSystem.PunishmentLevel.HARSH)


func test_leniency_below_minus30_harshest():
	var level := SentencingSystem._leniency_to_level(-31)
	assert_eq(level, SentencingSystem.PunishmentLevel.HARSHEST)


# -- Punishment Selection by Crime Type ----

func test_maho_always_execution_without_seppuku():
	var d := _make_daimyo(Enums.BushidoVirtue.JIN)
	d.disposition_values[99] = 90
	var r := _make_record(Enums.CrimeType.MAHO)
	var result := SentencingSystem.select_punishment(d, r)
	assert_eq(result["punishment"], SentencingSystem.Punishment.EXECUTION_WITHOUT_SEPPUKU,
		"Maho is always execution without seppuku regardless of leniency")


func test_violence_lightest_is_public_apology():
	var d := _make_daimyo(Enums.BushidoVirtue.JIN)
	var r := _make_record(Enums.CrimeType.VIOLENCE)
	var result := SentencingSystem.select_punishment(d, r)
	assert_eq(result["punishment"], SentencingSystem.Punishment.PUBLIC_APOLOGY,
		"Violence with max leniency (JIN +30) = public apology")


func test_treason_harshest_is_execution():
	var d := _make_daimyo(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI)
	d.disposition_values[99] = -80
	var r := _make_record(Enums.CrimeType.TREASON)
	# ISHI(-20) + enemy(-20) = -40 → HARSHEST
	var result := SentencingSystem.select_punishment(d, r)
	assert_eq(result["punishment"], SentencingSystem.Punishment.EXECUTION,
		"Treason with very low leniency = execution")


func test_open_killing_standard_is_seppuku_offered():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	var r := _make_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	var result := SentencingSystem.select_punishment(d, r)
	assert_eq(result["punishment"], SentencingSystem.Punishment.SEPPUKU_OFFERED,
		"Open killing with standard leniency = seppuku offered")


func test_dishonorable_conduct_standard_is_temporary_exile():
	var d := _make_daimyo(Enums.BushidoVirtue.CHUGI)
	var r := _make_record(Enums.CrimeType.DISHONORABLE_CONDUCT)
	var result := SentencingSystem.select_punishment(d, r)
	assert_eq(result["punishment"], SentencingSystem.Punishment.TEMPORARY_EXILE,
		"Dishonorable conduct standard = temporary exile")


# -- Combined Scenarios ----

func test_jin_daimyo_friend_no_pressure_covert_killing():
	var d := _make_daimyo(Enums.BushidoVirtue.JIN)
	d.disposition_values[99] = 70
	var r := _make_record(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	# JIN(+30) + Friend(+20) = +50 → LIGHTEST
	var result := SentencingSystem.select_punishment(d, r)
	assert_eq(result["leniency_score"], 50)
	assert_eq(result["punishment"], SentencingSystem.Punishment.SEPPUKU_OFFERED,
		"Even lightest covert killing = seppuku offered (floor)")


func test_harsh_daimyo_enemy_high_pressure_skimming():
	var d := _make_daimyo(Enums.BushidoVirtue.MEIYO)
	d.disposition_values[99] = -40
	var r := _make_record(Enums.CrimeType.SKIMMING)
	# MEIYO(-10) + Enemy(-20) + Tier3(-10) + cross_clan(-10) = -50
	var result := SentencingSystem.select_punishment(d, r, 3, true, false)
	assert_eq(result["leniency_score"], -50)
	assert_eq(result["punishment_level"], SentencingSystem.PunishmentLevel.HARSHEST)
	assert_eq(result["punishment"], SentencingSystem.Punishment.SEPPUKU_OFFERED,
		"Skimming harshest = seppuku offered")


func test_result_contains_all_expected_keys():
	var d := _make_daimyo(Enums.BushidoVirtue.REI)
	var r := _make_record(Enums.CrimeType.VIOLENCE)
	var result := SentencingSystem.select_punishment(d, r)
	assert_has(result, "leniency_score")
	assert_has(result, "punishment_level")
	assert_has(result, "punishment")
	assert_has(result, "gi_override")
