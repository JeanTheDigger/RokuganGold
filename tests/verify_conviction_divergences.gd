extends SceneTree
## Runtime driver for two "canonical arbiter bypassed by a divergent inline copy" fixes.
##
## FIX #1 (s16.1 crisis-band momentum): InvestigationSystem.generate_conviction_topic minted its
## topic momentum from a local TOPIC_INITIAL_MOMENTUM table whose tiers 2/3/4 were each 1 point
## BELOW the canonical TopicMomentumSystem.TIER_INITIAL_MOMENTUM (they landed at the top of the
## band below), so every crime-conviction topic entered court discussion one crisis-band weaker
## than any other topic of the same tier. Now routes through initial_momentum_for_tier.
##
## FIX #2 (s57.47:33 SERIOUS): the assassination-detected-on-failure writeback hand-built a
## CrimeRecord and hardcoded severity = CAPITAL for UNSANCTIONED_COVERT_KILLING, conflating the
## execution SENTENCE with the CrimeSeverity.CAPITAL CLASSIFICATION. Canonical get_severity (and
## the sibling create_crime_record sites) classify it SERIOUS.
## Run: godot --headless -s tests/verify_conviction_divergences.gd

const _INV := preload("res://simulation/investigation_system.gd")
const _CS := preload("res://simulation/crime_system.gd")
const _TM := preload("res://simulation/topic_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- Conviction-topic momentum + covert-killing severity divergences ---")
	_test_conviction_momentum()
	_test_covert_killing_severity()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _conviction_momentum(tier: int) -> float:
	var rec := CrimeRecord.new()
	rec.crime_type = Enums.CrimeType.UNSANCTIONED_OPEN_KILLING
	var conv := L5RCharacterData.new()
	conv.character_id = 1
	conv.character_name = "Test"
	var nid: Array = [500]
	var t: TopicData = _INV.generate_conviction_topic(rec, conv, tier, nid, 40)
	return t.momentum if t != null else -999.0


func _test_conviction_momentum() -> void:
	print("[1] conviction-topic momentum == canonical per-tier table (no off-by-one)")
	for tier: int in [TopicData.Tier.TIER_1, TopicData.Tier.TIER_2, TopicData.Tier.TIER_3, TopicData.Tier.TIER_4]:
		var got: float = _conviction_momentum(tier)
		var want: float = _TM.initial_momentum_for_tier(tier as TopicData.Tier)
		_ok(abs(got - want) < 0.001, "tier %d momentum %s == canonical %s" % [tier, got, want])

	# The KEY guarantee: each tier now classifies at the SAME crisis band as any other topic of
	# its tier -- the prior inline copy put tiers 2/3/4 one band too weak.
	_ok(_TM.get_momentum_level(_conviction_momentum(TopicData.Tier.TIER_4)) == _TM.MomentumLevel.MINOR_TOPIC,
		"tier-4 conviction topic is MINOR_TOPIC (was RUMOR at 10.0)")
	_ok(_TM.get_momentum_level(_conviction_momentum(TopicData.Tier.TIER_3)) == _TM.MomentumLevel.SECONDARY_TOPIC,
		"tier-3 conviction topic is SECONDARY_TOPIC (was MINOR at 25.0)")
	_ok(_TM.get_momentum_level(_conviction_momentum(TopicData.Tier.TIER_2)) == _TM.MomentumLevel.MAJOR_TOPIC,
		"tier-2 conviction topic is MAJOR_TOPIC (was SECONDARY at 50.0)")
	_ok(_TM.get_momentum_level(_conviction_momentum(TopicData.Tier.TIER_1)) == _TM.MomentumLevel.UNAVOIDABLE_CRISIS,
		"tier-1 conviction topic is UNAVOIDABLE_CRISIS (80.0, unchanged)")


func _test_covert_killing_severity() -> void:
	print("[2] covert-killing severity is SERIOUS (canonical), not CAPITAL")
	var sev: Enums.CrimeSeverity = _CS.get_severity(Enums.CrimeType.UNSANCTIONED_COVERT_KILLING)
	_ok(sev == Enums.CrimeSeverity.SERIOUS, "get_severity(UNSANCTIONED_COVERT_KILLING) == SERIOUS")
	_ok(sev != Enums.CrimeSeverity.CAPITAL, "NOT the CAPITAL the inline writeback hardcoded")

	# The sibling factory (used by the other covert-killing sites) agrees.
	var rec: CrimeRecord = _CS.create_crime_record(
		1, Enums.CrimeType.UNSANCTIONED_COVERT_KILLING, 10, "loc", 40, 20, 15, [],
	)
	_ok(rec.severity == Enums.CrimeSeverity.SERIOUS, "create_crime_record covert killing -> SERIOUS")

	# TREASON stays CAPITAL (the assassination fix is scoped to covert killing only).
	_ok(_CS.get_severity(Enums.CrimeType.TREASON) == Enums.CrimeSeverity.CAPITAL, "TREASON still CAPITAL")
