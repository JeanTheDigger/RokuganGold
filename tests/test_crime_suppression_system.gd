extends GutTest
## Tests for CrimeSuppressionSystem per GDD s11.3.19.


func _make_magistrate(
	school: Enums.SchoolType = Enums.SchoolType.BUSHI,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.GI,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.school_type = school
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	c.character_name = "Magistrate"
	return c


# -- Suppression Priority (s11.3.19c) ----

func test_priority_bandit_high_severity():
	var m := _make_magistrate()
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.RONIN_BANDIT, 60, m
	)
	assert_eq(p, 15 + 15)


func test_priority_pirate_high_severity():
	var m := _make_magistrate()
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.PIRATE_FLEET, 60, m
	)
	assert_eq(p, 15 + 15)


func test_priority_gang_medium_severity():
	var m := _make_magistrate(Enums.SchoolType.BUSHI, Enums.BushidoVirtue.YU)
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK, 60, m
	)
	assert_eq(p, 10 + 10)


func test_priority_low_stability_below_50():
	var m := _make_magistrate(Enums.SchoolType.BUSHI, Enums.BushidoVirtue.YU)
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.RONIN_BANDIT, 40, m
	)
	assert_eq(p, 15 + 20 + 10)


func test_priority_very_low_stability_below_25():
	var m := _make_magistrate(Enums.SchoolType.BUSHI, Enums.BushidoVirtue.YU)
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.RONIN_BANDIT, 20, m
	)
	assert_eq(p, 15 + 30 + 10)


func test_priority_kyoryoku_personality():
	var m := _make_magistrate(
		Enums.SchoolType.BUSHI, Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.KYORYOKU
	)
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.RONIN_BANDIT, 60, m
	)
	assert_eq(p, 15 + 15)


func test_priority_seigyo_no_personality_bonus():
	var m := _make_magistrate(
		Enums.SchoolType.BUSHI, Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO
	)
	var p := CrimeSuppressionSystem.get_suppression_priority(
		Enums.InsurgencyType.RONIN_BANDIT, 60, m
	)
	assert_eq(p, 15 + 0)


# -- Magistrate Approach (s11.3.19a) ----

func test_bushi_magistrate_personal_combat():
	var m := _make_magistrate(Enums.SchoolType.BUSHI)
	assert_eq(
		CrimeSuppressionSystem.determine_suppression_approach(m, false),
		CrimeSuppressionSystem.SuppressionApproach.PERSONAL_COMBAT
	)


func test_courtier_with_bushi_yoriki():
	var m := _make_magistrate(Enums.SchoolType.COURTIER)
	assert_eq(
		CrimeSuppressionSystem.determine_suppression_approach(m, true),
		CrimeSuppressionSystem.SuppressionApproach.YORIKI_DEPLOYED
	)


func test_courtier_without_bushi_yoriki():
	var m := _make_magistrate(Enums.SchoolType.COURTIER)
	assert_eq(
		CrimeSuppressionSystem.determine_suppression_approach(m, false),
		CrimeSuppressionSystem.SuppressionApproach.MILITARY_SUPPORT_REQUESTED
	)


# -- Doshin Bonus (s11.3.19e.ii) ----

func test_doshin_investigation_bonus_small():
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(1), 3)
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(2), 3)


func test_doshin_investigation_bonus_medium():
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(3), 5)
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(5), 5)


func test_doshin_investigation_bonus_large():
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(6), 8)
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(12), 8)


func test_doshin_investigation_bonus_none():
	assert_eq(CrimeSuppressionSystem.get_doshin_investigation_bonus(0), 0)


func test_doshin_suppression_bonus_matches_investigation():
	assert_eq(CrimeSuppressionSystem.get_doshin_suppression_bonus(2), 3)
	assert_eq(CrimeSuppressionSystem.get_doshin_suppression_bonus(4), 5)
	assert_eq(CrimeSuppressionSystem.get_doshin_suppression_bonus(8), 8)


func test_doshin_samurai_investigation_flat():
	assert_eq(CrimeSuppressionSystem.get_doshin_samurai_investigation_bonus(1), 3)
	assert_eq(CrimeSuppressionSystem.get_doshin_samurai_investigation_bonus(10), 3)
	assert_eq(CrimeSuppressionSystem.get_doshin_samurai_investigation_bonus(0), 0)


# -- Doshin Availability (s11.3.19e.vi, vii) ----

func test_doshin_baseline_remote():
	var b := CrimeSuppressionSystem.get_doshin_baseline(
		CrimeSuppressionSystem.SettlementSize.REMOTE
	)
	assert_eq(b["count"], 0)
	assert_false(b["has_headman"])


func test_doshin_baseline_village():
	var b := CrimeSuppressionSystem.get_doshin_baseline(
		CrimeSuppressionSystem.SettlementSize.VILLAGE
	)
	assert_eq(b["count"], 1)
	assert_eq(b["tier"], CrimeSuppressionSystem.DoshinTier.VILLAGE)


func test_doshin_baseline_town():
	var b := CrimeSuppressionSystem.get_doshin_baseline(
		CrimeSuppressionSystem.SettlementSize.TOWN
	)
	assert_eq(b["count"], 5)
	assert_true(b["has_headman"])
	assert_eq(b["tier"], CrimeSuppressionSystem.DoshinTier.CITY)


func test_doshin_baseline_city():
	var b := CrimeSuppressionSystem.get_doshin_baseline(
		CrimeSuppressionSystem.SettlementSize.CITY
	)
	assert_eq(b["count"], 10)
	assert_true(b["has_headman"])


func test_doshin_baseline_otosan_uchi():
	var b := CrimeSuppressionSystem.get_doshin_baseline(
		CrimeSuppressionSystem.SettlementSize.OTOSAN_UCHI
	)
	assert_eq(b["count"], 18)


func test_available_doshin_basic():
	var available := CrimeSuppressionSystem.get_available_doshin(
		CrimeSuppressionSystem.SettlementSize.TOWN, 0, false, 60
	)
	assert_eq(available, 5)


func test_available_doshin_with_losses():
	var available := CrimeSuppressionSystem.get_available_doshin(
		CrimeSuppressionSystem.SettlementSize.TOWN, 2, false, 60
	)
	assert_eq(available, 3)


func test_available_doshin_village_planting_season():
	var available := CrimeSuppressionSystem.get_available_doshin(
		CrimeSuppressionSystem.SettlementSize.LARGE_VILLAGE, 0, true, 60
	)
	assert_eq(available, 1)


func test_available_doshin_city_unaffected_by_season():
	var available := CrimeSuppressionSystem.get_available_doshin(
		CrimeSuppressionSystem.SettlementSize.TOWN, 0, true, 60
	)
	assert_eq(available, 5)


func test_available_doshin_low_stability():
	var available := CrimeSuppressionSystem.get_available_doshin(
		CrimeSuppressionSystem.SettlementSize.TOWN, 0, false, 20
	)
	assert_eq(available, 3)


func test_available_doshin_floor_zero():
	var available := CrimeSuppressionSystem.get_available_doshin(
		CrimeSuppressionSystem.SettlementSize.VILLAGE, 5, false, 10
	)
	assert_eq(available, 0)


# -- Recruitment Limits (s11.3.19e.viii) ----

func test_max_recruitable_half_rounded_up():
	assert_eq(CrimeSuppressionSystem.get_max_recruitable(5), 3)
	assert_eq(CrimeSuppressionSystem.get_max_recruitable(4), 2)
	assert_eq(CrimeSuppressionSystem.get_max_recruitable(1), 1)


func test_max_recruitable_daimyo_override():
	assert_eq(CrimeSuppressionSystem.get_max_recruitable(5, true), 5)


func test_max_recruitable_zero():
	assert_eq(CrimeSuppressionSystem.get_max_recruitable(0), 0)


# -- Doshin Recovery (s11.3.19e.iii) ----

func test_doshin_recovery_reduces_losses():
	assert_eq(CrimeSuppressionSystem.process_doshin_recovery(3), 2)
	assert_eq(CrimeSuppressionSystem.process_doshin_recovery(1), 0)


func test_doshin_recovery_no_losses():
	assert_eq(CrimeSuppressionSystem.process_doshin_recovery(0), 0)


# -- Detection Advantage (s11.3.19a) ----

func test_patrol_detection_chances():
	var r: Dictionary = CrimeSuppressionSystem.get_patrol_detection_chances(1, 2)
	assert_eq(r["magistrate_count"], 1)
	assert_eq(r["yoriki_count"], 2)
	assert_true(r["has_multiple_patrols"])
	var r2: Dictionary = CrimeSuppressionSystem.get_patrol_detection_chances(1, 0)
	assert_eq(r2["magistrate_count"], 1)
	assert_false(r2["has_multiple_patrols"])


# -- Suppression Consequences (s11.3.19d) ----

func test_success_consequences_heimin():
	var r := CrimeSuppressionSystem.get_suppression_success_consequences(false)
	assert_true(r["glory_gain_magistrate"])
	assert_true(r["heimin_swift_justice"])
	assert_false(r["samurai_enter_investigation"])


func test_success_consequences_samurai():
	var r := CrimeSuppressionSystem.get_suppression_success_consequences(true)
	assert_true(r["samurai_enter_investigation"])
	assert_false(r["heimin_swift_justice"])


# -- Mission Type Mapping (s11.3.19b) ----

func test_mission_type_bandit():
	assert_eq(
		CrimeSuppressionSystem.get_mission_type(Enums.InsurgencyType.RONIN_BANDIT),
		CrimeSuppressionSystem.SuppressionMissionType.RAID_BANDIT_CAMP
	)


func test_mission_type_gang():
	assert_eq(
		CrimeSuppressionSystem.get_mission_type(Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK),
		CrimeSuppressionSystem.SuppressionMissionType.RAID_GANG_HIDEOUT
	)


func test_mission_type_pirate():
	assert_eq(
		CrimeSuppressionSystem.get_mission_type(Enums.InsurgencyType.PIRATE_FLEET),
		CrimeSuppressionSystem.SuppressionMissionType.INTERCEPT_PIRATE_VESSEL
	)
