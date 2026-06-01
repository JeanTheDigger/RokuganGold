extends GutTest
## Tests for CollectiveDisposition per GDD s12.2b.


var _baselines: Dictionary
var _clan_baselines: Dictionary
var _family_baselines: Dictionary


func before_each() -> void:
	_baselines = CollectiveDisposition.make_starting_baselines()
	_clan_baselines = _baselines["clan"]
	_family_baselines = _baselines["family"]


func _make(id: int, clan: String, family: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.family = family
	return c


# -- Pair key composition ----------------------------------------------------

func test_pair_key_is_symmetric() -> void:
	assert_eq(
		CollectiveDisposition.make_pair_key("Crab", "Crane"),
		CollectiveDisposition.make_pair_key("Crane", "Crab"),
	)


func test_pair_key_lexicographic_order() -> void:
	assert_eq(CollectiveDisposition.make_pair_key("Crane", "Crab"), "Crab||Crane")


# -- Starting baseline values match GDD --------------------------------------

func test_crane_lion_baseline_minus_30() -> void:
	# The Empire's bitterest rivalry per GDD s12.2b.
	assert_eq(
		CollectiveDisposition.get_clan_baseline("Crane", "Lion", _clan_baselines),
		-30,
	)


func test_crane_phoenix_baseline_plus_20() -> void:
	# Strongest positive Great Clan pair.
	assert_eq(
		CollectiveDisposition.get_clan_baseline("Crane", "Phoenix", _clan_baselines),
		20,
	)


func test_crab_crane_baseline_minus_25() -> void:
	assert_eq(
		CollectiveDisposition.get_clan_baseline("Crab", "Crane", _clan_baselines),
		-25,
	)


func test_dragon_dragonfly_baseline_plus_20() -> void:
	# Highest Minor Clan ↔ Great Clan baseline.
	assert_eq(
		CollectiveDisposition.get_clan_baseline("Dragon", "Dragonfly", _clan_baselines),
		20,
	)


func test_unlisted_clan_pair_is_zero() -> void:
	assert_eq(
		CollectiveDisposition.get_clan_baseline("Badger", "Hare", _clan_baselines),
		0,
	)


func test_same_clan_baseline_is_zero() -> void:
	assert_eq(
		CollectiveDisposition.get_clan_baseline("Lion", "Lion", _clan_baselines),
		0,
	)


func test_empty_clan_baseline_is_zero() -> void:
	assert_eq(
		CollectiveDisposition.get_clan_baseline("", "Lion", _clan_baselines),
		0,
	)


func test_doji_kakita_family_baseline_plus_15() -> void:
	# Tightest intra-Crane partnership.
	assert_eq(
		CollectiveDisposition.get_family_baseline("Doji", "Kakita", _family_baselines),
		15,
	)


func test_yasuki_doji_family_baseline_minus_20() -> void:
	# The Yasuki War.
	assert_eq(
		CollectiveDisposition.get_family_baseline("Yasuki", "Doji", _family_baselines),
		-20,
	)


func test_kakita_mirumoto_dueling_rivalry() -> void:
	assert_eq(
		CollectiveDisposition.get_family_baseline("Kakita", "Mirumoto", _family_baselines),
		-15,
	)


func test_unlisted_family_pair_is_zero() -> void:
	assert_eq(
		CollectiveDisposition.get_family_baseline("Hida", "Akodo", _family_baselines),
		0,
	)


# -- Seed disposition --------------------------------------------------------

func test_seed_for_intra_clan_intra_family_is_zero() -> void:
	var a: L5RCharacterData = _make(1, "Lion", "Akodo")
	var b: L5RCharacterData = _make(2, "Lion", "Akodo")
	assert_eq(
		CollectiveDisposition.compute_seed_disposition(a, b, _clan_baselines, _family_baselines),
		0,
	)


func test_seed_uses_only_family_baseline_for_same_clan() -> void:
	# Two Crane from different families: clan baseline 0 (same clan), family
	# baseline applies. Doji ↔ Kakita = +15 → seed = 15 * 0.50 = 8 (rounded).
	var a: L5RCharacterData = _make(1, "Crane", "Doji")
	var b: L5RCharacterData = _make(2, "Crane", "Kakita")
	assert_eq(
		CollectiveDisposition.compute_seed_disposition(a, b, _clan_baselines, _family_baselines),
		8,
	)


func test_seed_combines_clan_and_family_for_cross_clan() -> void:
	# Crab Yasuki meets Crane Doji.
	# Clan: Crab ↔ Crane = -25 → -25 * 0.25 = -6.25
	# Family: Yasuki ↔ Doji = -20 → -20 * 0.50 = -10
	# Sum: -16.25 → rounded to -16.
	var a: L5RCharacterData = _make(1, "Crab", "Yasuki")
	var b: L5RCharacterData = _make(2, "Crane", "Doji")
	assert_eq(
		CollectiveDisposition.compute_seed_disposition(a, b, _clan_baselines, _family_baselines),
		-16,
	)


func test_seed_gdd_example() -> void:
	# Example from GDD: Clan-to-Clan = +20, Family-to-Family = -10.
	# (20 * 0.25) + (-10 * 0.50) = 5 - 5 = 0.
	var clan_baselines: Dictionary = {"X||Y": 20}
	var family_baselines: Dictionary = {"FA||FB": -10}
	var a: L5RCharacterData = _make(1, "X", "FA")
	var b: L5RCharacterData = _make(2, "Y", "FB")
	assert_eq(
		CollectiveDisposition.compute_seed_disposition(a, b, clan_baselines, family_baselines),
		0,
	)


func test_seed_handles_null_actors() -> void:
	assert_eq(
		CollectiveDisposition.compute_seed_disposition(null, null, {}, {}),
		0,
	)


# -- seed_first_meeting ------------------------------------------------------

func test_seed_first_meeting_writes_disposition_value() -> void:
	var a: L5RCharacterData = _make(1, "Crane", "Doji")
	var b: L5RCharacterData = _make(2, "Crane", "Kakita")
	CollectiveDisposition.seed_first_meeting(a, b, _clan_baselines, _family_baselines)
	assert_eq(a.disposition_values[2], 8)


func test_seed_first_meeting_preserves_existing_value() -> void:
	# Already-met characters: stored value wins, no overwrite.
	var a: L5RCharacterData = _make(1, "Crane", "Doji")
	var b: L5RCharacterData = _make(2, "Crane", "Kakita")
	a.disposition_values = {2: 50}
	var ret: int = CollectiveDisposition.seed_first_meeting(a, b, _clan_baselines, _family_baselines)
	assert_eq(ret, 50)
	assert_eq(a.disposition_values[2], 50)


# -- Event ripple ------------------------------------------------------------

func test_ripple_updates_clan_and_family_baselines() -> void:
	# Crab (Hida) raids Crane (Doji) — personal disposition -20.
	# Family ripple: -20 * 0.20 = -4.
	# Clan ripple: -20 * 0.05 = -1.
	# Hida ↔ Doji starting baseline = 0 (unlisted) → -4.
	# Crab ↔ Crane starting baseline = -25 → -26.
	var a: L5RCharacterData = _make(1, "Crab", "Hida")
	var b: L5RCharacterData = _make(2, "Crane", "Doji")
	var result: Dictionary = CollectiveDisposition.apply_event_ripple(
		a, b, -20, _clan_baselines, _family_baselines,
	)
	assert_eq(result["family_change"], -4)
	assert_eq(result["clan_change"], -1)
	assert_eq(_family_baselines[CollectiveDisposition.make_pair_key("Hida", "Doji")], -4)
	assert_eq(_clan_baselines[CollectiveDisposition.make_pair_key("Crab", "Crane")], -26)


func test_ripple_skips_clan_when_intra_clan() -> void:
	var a: L5RCharacterData = _make(1, "Lion", "Akodo")
	var b: L5RCharacterData = _make(2, "Lion", "Matsu")
	var result: Dictionary = CollectiveDisposition.apply_event_ripple(
		a, b, 20, _clan_baselines, _family_baselines,
	)
	assert_eq(result["clan_change"], 0)
	assert_eq(result["family_change"], 4)


func test_ripple_skips_family_when_same_family() -> void:
	var a: L5RCharacterData = _make(1, "Lion", "Akodo")
	var b: L5RCharacterData = _make(2, "Lion", "Akodo")
	var result: Dictionary = CollectiveDisposition.apply_event_ripple(
		a, b, 100, _clan_baselines, _family_baselines,
	)
	assert_eq(result["family_change"], 0)
	assert_eq(result["clan_change"], 0)


func test_ripple_zero_personal_change_no_op() -> void:
	var a: L5RCharacterData = _make(1, "Crab", "Hida")
	var b: L5RCharacterData = _make(2, "Crane", "Doji")
	var result: Dictionary = CollectiveDisposition.apply_event_ripple(
		a, b, 0, _clan_baselines, _family_baselines,
	)
	assert_eq(result["family_change"], 0)
	assert_eq(result["clan_change"], 0)


# -- Specific events ---------------------------------------------------------

func test_marriage_applies_standard_deltas() -> void:
	# s22.7 wins over s12.2b: marriage goes into the decaying boost layer,
	# NOT permanent baselines. Both standard and champion-level get the same
	# clan boost (8) because the decaying layer doesn't differentiate.
	var marriage_clan_boosts: Dictionary = {}
	var marriage_family_boosts: Dictionary = {}
	var ret: Dictionary = CollectiveDisposition.apply_marriage(
		"Crab", "Crane", "Hida", "Doji",
		_clan_baselines, _family_baselines, false,
		marriage_clan_boosts, marriage_family_boosts,
	)
	# Decaying layer is updated.
	var fkey: String = CollectiveDisposition.make_pair_key("Hida", "Doji")
	var ckey: String = CollectiveDisposition.make_pair_key("Crab", "Crane")
	assert_eq(marriage_family_boosts[fkey]["value"], CollectiveDisposition.MARRIAGE_FAMILY_BOOST)
	assert_eq(marriage_clan_boosts[ckey]["value"], CollectiveDisposition.MARRIAGE_CLAN_BOOST)
	assert_eq(ret["family_boost"], CollectiveDisposition.MARRIAGE_FAMILY_BOOST)
	assert_eq(ret["clan_boost"], CollectiveDisposition.MARRIAGE_CLAN_BOOST)
	# Permanent baselines are NOT modified (s22.7 won over s12.2b line 303).
	assert_false(_family_baselines.has(fkey), "apply_marriage must not touch permanent family baselines")


func test_champion_marriage_applies_higher_deltas() -> void:
	# champion_level flag has no effect in the s22.7 decaying layer; both
	# tiers give the same boost values. s12.2b champion distinction is superseded.
	var marriage_clan_boosts: Dictionary = {}
	var marriage_family_boosts: Dictionary = {}
	var ret: Dictionary = CollectiveDisposition.apply_marriage(
		"Crab", "Crane", "Hida", "Doji",
		_clan_baselines, _family_baselines, true,
		marriage_clan_boosts, marriage_family_boosts,
	)
	assert_eq(ret.get("clan_boost", -1), CollectiveDisposition.MARRIAGE_CLAN_BOOST)
	assert_eq(ret.get("family_boost", -1), CollectiveDisposition.MARRIAGE_FAMILY_BOOST)


func test_clan_war_declared_minus_10_clan_only() -> void:
	var delta: int = CollectiveDisposition.apply_clan_war_declared(
		"Crab", "Crane", _clan_baselines,
	)
	assert_eq(delta, -10)
	assert_eq(_clan_baselines[CollectiveDisposition.make_pair_key("Crab", "Crane")], -35)


func test_clan_peace_treaty_plus_5() -> void:
	var delta: int = CollectiveDisposition.apply_clan_peace_treaty(
		"Crab", "Crane", _clan_baselines,
	)
	assert_eq(delta, 5)
	assert_eq(_clan_baselines[CollectiveDisposition.make_pair_key("Crab", "Crane")], -20)


func test_family_betrayal_minus_10_no_decay_marker() -> void:
	var delta: int = CollectiveDisposition.apply_family_betrayal(
		"Bayushi", "Doji", _family_baselines,
	)
	assert_eq(delta, -10)
	# Bayushi ↔ Doji starting -15 + -10 = -25.
	assert_eq(_family_baselines[CollectiveDisposition.make_pair_key("Bayushi", "Doji")], -25)


func test_intra_clan_rice_sharing_plus_2() -> void:
	var delta: int = CollectiveDisposition.apply_intra_clan_rice_sharing(
		"Hida", "Yasuki", _family_baselines,
	)
	assert_eq(delta, 2)
	assert_eq(_family_baselines[CollectiveDisposition.make_pair_key("Hida", "Yasuki")], 7)


func test_family_lord_raid_minus_3() -> void:
	var delta: int = CollectiveDisposition.apply_family_lord_raid(
		"Hida", "Doji", _family_baselines,
	)
	assert_eq(delta, -3)


func test_family_duel_death_minus_5() -> void:
	var delta: int = CollectiveDisposition.apply_family_duel_death(
		"Kakita", "Mirumoto", _family_baselines,
	)
	assert_eq(delta, -5)
	assert_eq(_family_baselines[CollectiveDisposition.make_pair_key("Kakita", "Mirumoto")], -20)


func test_harvest_destruction_minus_5() -> void:
	var delta: int = CollectiveDisposition.apply_harvest_destruction(
		"Lion", "Crane", _clan_baselines,
	)
	assert_eq(delta, -5)
	assert_eq(_clan_baselines[CollectiveDisposition.make_pair_key("Crane", "Lion")], -35)


func test_specific_event_skips_intra_clan_intra_family() -> void:
	var clan_delta: int = CollectiveDisposition.apply_clan_war_declared(
		"Lion", "Lion", _clan_baselines,
	)
	assert_eq(clan_delta, 0)
	var fam_delta: int = CollectiveDisposition.apply_family_betrayal(
		"Akodo", "Akodo", _family_baselines,
	)
	assert_eq(fam_delta, 0)


# -- Factory -----------------------------------------------------------------

func test_make_starting_baselines_returns_independent_copies() -> void:
	# Mutating one returned dict must not affect another caller's copy.
	var a: Dictionary = CollectiveDisposition.make_starting_baselines()
	var b: Dictionary = CollectiveDisposition.make_starting_baselines()
	a["clan"][CollectiveDisposition.make_pair_key("Crab", "Crane")] = 999
	assert_eq(
		b["clan"][CollectiveDisposition.make_pair_key("Crab", "Crane")],
		-25,
	)


func test_make_starting_baselines_does_not_mutate_const() -> void:
	var fresh: Dictionary = CollectiveDisposition.make_starting_baselines()
	fresh["clan"][CollectiveDisposition.make_pair_key("Crab", "Crane")] = 999
	# Re-fetch the const value through another fresh copy.
	var second: Dictionary = CollectiveDisposition.make_starting_baselines()
	assert_eq(
		second["clan"][CollectiveDisposition.make_pair_key("Crab", "Crane")],
		-25,
	)


# -- Compounding events ------------------------------------------------------

func test_repeated_raids_compound_negative_baseline() -> void:
	var a: L5RCharacterData = _make(1, "Crab", "Hida")
	var b: L5RCharacterData = _make(2, "Crane", "Doji")
	for i in 5:
		CollectiveDisposition.apply_event_ripple(
			a, b, -20, _clan_baselines, _family_baselines,
		)
	# 5 × -1 = -5 ripple on Crab||Crane (starting -25) → -30.
	assert_eq(_clan_baselines[CollectiveDisposition.make_pair_key("Crab", "Crane")], -30)
	# 5 × -4 = -20 ripple on Hida||Doji (starting 0) → -20.
	assert_eq(_family_baselines[CollectiveDisposition.make_pair_key("Hida", "Doji")], -20)


func test_seed_disposition_clamped_to_range() -> void:
	var a: L5RCharacterData = _make(1, "Crab", "Hida")
	var b: L5RCharacterData = _make(2, "Crane", "Doji")
	var extreme_clan: Dictionary = {}
	extreme_clan[CollectiveDisposition.make_pair_key("Crab", "Crane")] = -100
	var extreme_family: Dictionary = {}
	extreme_family[CollectiveDisposition.make_pair_key("Hida", "Doji")] = -100
	var result: int = CollectiveDisposition.seed_first_meeting(
		a, b, extreme_clan, extreme_family,
	)
	assert_true(result >= -100 and result <= 100,
		"Seed disposition should be clamped to [-100, 100]")
	assert_true(a.disposition_values[b.character_id] >= -100,
		"Stored disposition should be >= -100")
	assert_true(a.disposition_values[b.character_id] <= 100,
		"Stored disposition should be <= 100")
