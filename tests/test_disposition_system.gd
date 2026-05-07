extends GutTest
## Tests for DispositionSystem per GDD s12.2.


# -- Tier tests ---------------------------------------------------------------

func test_blood_enemy_tier():
	assert_eq(DispositionSystem.get_tier(-100), DispositionSystem.Tier.BLOOD_ENEMY)
	assert_eq(DispositionSystem.get_tier(-61), DispositionSystem.Tier.BLOOD_ENEMY)


func test_enemy_tier():
	assert_eq(DispositionSystem.get_tier(-60), DispositionSystem.Tier.ENEMY)
	assert_eq(DispositionSystem.get_tier(-31), DispositionSystem.Tier.ENEMY)


func test_rival_tier():
	assert_eq(DispositionSystem.get_tier(-30), DispositionSystem.Tier.RIVAL)
	assert_eq(DispositionSystem.get_tier(-11), DispositionSystem.Tier.RIVAL)


func test_stranger_tier():
	assert_eq(DispositionSystem.get_tier(-10), DispositionSystem.Tier.STRANGER)
	assert_eq(DispositionSystem.get_tier(0), DispositionSystem.Tier.STRANGER)
	assert_eq(DispositionSystem.get_tier(10), DispositionSystem.Tier.STRANGER)


func test_acquaintance_tier():
	assert_eq(DispositionSystem.get_tier(11), DispositionSystem.Tier.ACQUAINTANCE)
	assert_eq(DispositionSystem.get_tier(30), DispositionSystem.Tier.ACQUAINTANCE)


func test_friend_tier():
	assert_eq(DispositionSystem.get_tier(31), DispositionSystem.Tier.FRIEND)
	assert_eq(DispositionSystem.get_tier(60), DispositionSystem.Tier.FRIEND)


func test_trusted_ally_tier():
	assert_eq(DispositionSystem.get_tier(61), DispositionSystem.Tier.TRUSTED_ALLY)
	assert_eq(DispositionSystem.get_tier(90), DispositionSystem.Tier.TRUSTED_ALLY)


func test_devoted_tier():
	assert_eq(DispositionSystem.get_tier(91), DispositionSystem.Tier.DEVOTED)
	assert_eq(DispositionSystem.get_tier(100), DispositionSystem.Tier.DEVOTED)


func test_tier_names():
	assert_eq(DispositionSystem.get_tier_name(0), "Stranger")
	assert_eq(DispositionSystem.get_tier_name(-50), "Enemy")
	assert_eq(DispositionSystem.get_tier_name(95), "Devoted")


# -- Roll modifier tests ------------------------------------------------------

func test_raise_modifier_blood_enemy():
	assert_eq(DispositionSystem.get_raise_modifier(-80), 2)


func test_raise_modifier_enemy():
	assert_eq(DispositionSystem.get_raise_modifier(-40), 1)


func test_raise_modifier_stranger():
	assert_eq(DispositionSystem.get_raise_modifier(0), 0)


func test_raise_modifier_friend():
	assert_eq(DispositionSystem.get_raise_modifier(45), -1)


func test_raise_modifier_trusted_ally():
	assert_eq(DispositionSystem.get_raise_modifier(75), -2)


func test_raise_modifier_devoted():
	assert_eq(DispositionSystem.get_raise_modifier(95), -3)


# -- Authenticity modifier tests ----------------------------------------------

func test_authenticity_hostile_devoted():
	assert_eq(DispositionSystem.get_authenticity_modifier(95, true), -2)


func test_authenticity_hostile_friend():
	assert_eq(DispositionSystem.get_authenticity_modifier(40, true), -1)


func test_authenticity_hostile_neutral():
	assert_eq(DispositionSystem.get_authenticity_modifier(0, true), 0)


func test_authenticity_positive_blood_enemy():
	assert_eq(DispositionSystem.get_authenticity_modifier(-95, false), -2)


func test_authenticity_positive_rival():
	assert_eq(DispositionSystem.get_authenticity_modifier(-40, false), -1)


func test_authenticity_positive_neutral():
	assert_eq(DispositionSystem.get_authenticity_modifier(0, false), 0)


# -- Virtue compatibility tests -----------------------------------------------

func test_bushido_bushido_jin_jin():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Jin", "Jin"), 10)


func test_bushido_bushido_gi_makoto():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Gi", "Makoto"), 15)


func test_bushido_bushido_yu_rei():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Yu", "Rei"), -8)


func test_bushido_bushido_meiyo_meiyo():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Meiyo", "Meiyo"), -5)


func test_shourido_shourido_seigyo_dosatsu():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Seigyo", "Dosatsu"), 15)


func test_shourido_shourido_kanpeki_kanpeki():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Kanpeki", "Kanpeki"), -12)


func test_shourido_shourido_ishi_ishi():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Ishi", "Ishi"), -10)


func test_cross_yu_kyoryoku():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Yu", "Kyoryoku"), 20)


func test_cross_gi_seigyo():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Gi", "Seigyo"), -20)


func test_cross_makoto_seigyo():
	assert_eq(DispositionSystem.get_virtue_pair_modifier("Makoto", "Seigyo"), -20)


func test_symmetric_lookup():
	assert_eq(
		DispositionSystem.get_virtue_pair_modifier("Jin", "Seigyo"),
		DispositionSystem.get_virtue_pair_modifier("Seigyo", "Jin"),
	)


func test_compute_permanent_jin_gi():
	var mod := DispositionSystem.compute_permanent_modifier(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE,
		Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.NONE,
	)
	assert_eq(mod, 10)


func test_compute_permanent_two_virtues_each():
	var mod := DispositionSystem.compute_permanent_modifier(
		Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE,
		Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO,
	)
	# Jin×Gi=10, Jin×Seigyo=-15 → -5
	assert_eq(mod, -5)


func test_compute_permanent_no_virtues():
	var mod := DispositionSystem.compute_permanent_modifier(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE,
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE,
	)
	assert_eq(mod, 0)


# -- Historical modifier tests ------------------------------------------------

func test_create_historical_saved_life():
	var mod := DispositionSystem.create_historical_modifier("saved_life", 100)
	assert_eq(mod["current_value"], 20)
	assert_eq(mod["floor"], 10)
	assert_true(mod["decays"])


func test_create_historical_killed_family():
	var mod := DispositionSystem.create_historical_modifier("killed_family_member", 50)
	assert_eq(mod["current_value"], -50)
	assert_eq(mod["floor"], -50)
	assert_false(mod["decays"])


func test_decay_positive_modifier():
	var mod := DispositionSystem.create_historical_modifier("saved_life", 0)
	DispositionSystem.decay_historical_modifier(mod, 100)
	assert_eq(mod["current_value"], 10)  # 20 - (100/10) = 10 = floor


func test_decay_stops_at_floor():
	var mod := DispositionSystem.create_historical_modifier("saved_life", 0)
	DispositionSystem.decay_historical_modifier(mod, 200)
	assert_eq(mod["current_value"], 10)  # capped at floor


func test_no_decay_modifier():
	var mod := DispositionSystem.create_historical_modifier("killed_family_member", 0)
	DispositionSystem.decay_historical_modifier(mod, 1000)
	assert_eq(mod["current_value"], -50)


func test_decay_negative_toward_floor():
	var mod := DispositionSystem.create_historical_modifier("same_battle_opposite", 0)
	# start=-10, floor=-3
	DispositionSystem.decay_historical_modifier(mod, 70)
	assert_eq(mod["current_value"], -3)  # -10 + 7 = -3 = floor


func test_invalid_event_type():
	var mod := DispositionSystem.create_historical_modifier("nonexistent", 0)
	assert_true(mod.is_empty())


# -- Temporary modifier tests -------------------------------------------------

func test_create_temporary_same_court():
	var mod := DispositionSystem.create_temporary_modifier("same_court", 100)
	assert_eq(mod["value"], 3)
	assert_eq(mod["duration"], 30)


func test_temporary_not_expired():
	var mod := DispositionSystem.create_temporary_modifier("same_court", 100)
	assert_false(DispositionSystem.is_temporary_expired(mod, 129))


func test_temporary_expired():
	var mod := DispositionSystem.create_temporary_modifier("same_court", 100)
	assert_true(DispositionSystem.is_temporary_expired(mod, 130))


func test_conditional_temporary_never_expires():
	var mod := DispositionSystem.create_temporary_modifier("at_war", 0)
	assert_false(DispositionSystem.is_temporary_expired(mod, 9999))


func test_gift_temporary_values():
	var normal := DispositionSystem.create_temporary_modifier("gift_normal", 0)
	var fine := DispositionSystem.create_temporary_modifier("gift_fine", 0)
	var exceptional := DispositionSystem.create_temporary_modifier("gift_exceptional", 0)
	var masterwork := DispositionSystem.create_temporary_modifier("gift_masterwork", 0)
	assert_eq(normal["value"], 3)
	assert_eq(fine["value"], 5)
	assert_eq(exceptional["value"], 8)
	assert_eq(masterwork["value"], 12)


# -- Composite calculation tests ----------------------------------------------

func test_compute_total_basic():
	var total := DispositionSystem.compute_total_disposition(10, [], [])
	assert_eq(total, 10)


func test_compute_total_with_historical():
	var hist := [{"current_value": 15}, {"current_value": -5}]
	var total := DispositionSystem.compute_total_disposition(10, hist, [])
	assert_eq(total, 20)


func test_compute_total_with_temporary():
	var temp := [{"value": 3}, {"value": -5}]
	var total := DispositionSystem.compute_total_disposition(10, [], temp)
	assert_eq(total, 8)


func test_compute_total_clamped_high():
	var hist := [{"current_value": 90}]
	var total := DispositionSystem.compute_total_disposition(50, hist, [])
	assert_eq(total, 100)


func test_compute_total_clamped_low():
	var hist := [{"current_value": -80}]
	var total := DispositionSystem.compute_total_disposition(-50, hist, [])
	assert_eq(total, -100)


func test_compute_total_with_cohabitation():
	var total := DispositionSystem.compute_total_disposition(0, [], [], 12.0)
	assert_eq(total, 12)


# -- Supply sharing tests -----------------------------------------------------

func test_supply_sharing_devoted():
	assert_true(DispositionSystem.will_share_supplies(95))
	assert_almost_eq(DispositionSystem.get_supply_share_ratio(95), 1.0, 0.01)


func test_supply_sharing_friend_low():
	assert_true(DispositionSystem.will_share_supplies(31))
	assert_almost_eq(DispositionSystem.get_supply_share_ratio(31), 0.5, 0.02)


func test_supply_sharing_friend_high():
	assert_almost_eq(DispositionSystem.get_supply_share_ratio(60), 1.0, 0.02)


func test_supply_sharing_stranger_refuses():
	assert_false(DispositionSystem.will_share_supplies(20))
	assert_eq(DispositionSystem.get_supply_share_ratio(20), 0.0)


# -- Action disposition values tests ------------------------------------------

func test_charm_disposition_values():
	var charm: Dictionary = DispositionSystem.ACTION_DISPOSITION["CHARM"]
	assert_eq(charm["success"], 8)
	assert_eq(charm["per_raise"], 3)
	assert_eq(charm["critical_failure"], -5)


func test_persuade_disposition_values():
	var persuade: Dictionary = DispositionSystem.ACTION_DISPOSITION["PERSUADE"]
	assert_eq(persuade["success"], 11)
	assert_eq(persuade["critical_failure"], -7)


func test_listen_reflect_matches_persuade():
	var lr: Dictionary = DispositionSystem.ACTION_DISPOSITION["LISTEN_REFLECT"]
	assert_eq(lr["success"], 11)


func test_perform_for_disposition():
	var pf: Dictionary = DispositionSystem.ACTION_DISPOSITION["PERFORM_FOR"]
	assert_eq(pf["success"], 10)
	assert_eq(pf["critical_failure"], -4)


# -- Family bond tests --------------------------------------------------------

func test_family_bond_sibling():
	assert_eq(DispositionSystem.FAMILY_BONDS["sibling"], 20)


func test_family_bond_parent_child():
	assert_eq(DispositionSystem.FAMILY_BONDS["parent_child"], 20)


func test_family_bond_cousin():
	assert_eq(DispositionSystem.FAMILY_BONDS["first_cousin"], 6)


# -- Ripple constants ---------------------------------------------------------

func test_family_ripple():
	assert_eq(DispositionSystem.FAMILY_RIPPLE, 2)
	assert_eq(DispositionSystem.CLAN_RIPPLE, 1)


func test_ripple_caps():
	assert_eq(DispositionSystem.FAMILY_RIPPLE_CAP, 30)
	assert_eq(DispositionSystem.CLAN_RIPPLE_CAP, 15)


# -- families_married is permanent --------------------------------------------

func test_families_married_no_decay():
	assert_false(DispositionSystem.HISTORICAL_EVENTS["families_married"]["decay"])


# -- Death of mutual friend ---------------------------------------------------

func test_death_mutual_friend_positive():
	var mod := DispositionSystem.create_death_mutual_friend_modifier(60, 40, 100)
	# avg = 50, start = 50/10 = 5, floor = 2
	assert_eq(mod["current_value"], 5)
	assert_eq(mod["floor"], 2)
	assert_true(mod["decays"])


func test_death_mutual_friend_capped_at_10():
	var mod := DispositionSystem.create_death_mutual_friend_modifier(100, 100, 100)
	# avg = 100, start = 100/10 = 10 (capped), floor = 5
	assert_eq(mod["current_value"], 10)
	assert_eq(mod["floor"], 5)


func test_death_mutual_friend_low_disposition():
	var mod := DispositionSystem.create_death_mutual_friend_modifier(10, 10, 100)
	# avg = 10, start = 10/10 = 1, floor = 0
	assert_eq(mod["current_value"], 1)
	assert_eq(mod["floor"], 0)


# -- Cohabitation bonus -------------------------------------------------------

func test_cohabitation_bonus():
	assert_eq(DispositionSystem.compute_cohabitation_bonus(10), 1.0)


func test_cohabitation_bonus_zero_days():
	assert_eq(DispositionSystem.compute_cohabitation_bonus(0), 0.0)


func test_cohabitation_bonus_40_days():
	var bonus := DispositionSystem.compute_cohabitation_bonus(40)
	assert_almost_eq(bonus, 4.0, 0.01)


# -- Information sharing thresholds -------------------------------------------

func test_shares_sensitive_at_61():
	assert_eq(DispositionSystem.get_info_sharing_tier(61), DispositionSystem.InfoSharingTier.SHARES_SENSITIVE)


func test_shares_relevant_at_31():
	assert_eq(DispositionSystem.get_info_sharing_tier(31), DispositionSystem.InfoSharingTier.SHARES_RELEVANT)


func test_shares_neutral_at_0():
	assert_eq(DispositionSystem.get_info_sharing_tier(0), DispositionSystem.InfoSharingTier.SHARES_NEUTRAL)


func test_shares_nothing_at_minus_11():
	assert_eq(DispositionSystem.get_info_sharing_tier(-11), DispositionSystem.InfoSharingTier.SHARES_NOTHING)


func test_will_share_sensitive_topic():
	assert_true(DispositionSystem.will_share_topic(61, true))
	assert_false(DispositionSystem.will_share_topic(50, true))


func test_will_share_neutral_topic():
	assert_true(DispositionSystem.will_share_topic(0, false))
	assert_false(DispositionSystem.will_share_topic(-20, false))


func test_may_deliberately_mislead():
	assert_true(DispositionSystem.may_deliberately_mislead(-11))
	assert_false(DispositionSystem.may_deliberately_mislead(-10))
	assert_false(DispositionSystem.may_deliberately_mislead(0))
