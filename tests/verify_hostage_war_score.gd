extends SceneTree
## Runtime driver for wiring hostage capture leverage into the War Score (s22.9 line 97 /
## s53, LOCKED): capturing a high-value hostage shifts the War Score between the captor's
## and hostage's clans -- Rank 3+ hostage +3/-3, Rank 5+ or a Champion's-family hostage
## +8/-8. Both capture sites minted the hostage record but never applied this leverage, so
## WarSystem.SCORE_SHIFTS' "hostage_rank3"/"hostage_rank5_champion" keys were dead. The
## rank->tier decision is delegated to the canonical HostageSystem.get_leverage_value arbiter.
## Verifies: rank-3 tier (+3/-3), rank-5 tier (+8/-8), champion-family override (rank 2 ->
## +8/-8), rank<3 no-op, no-war no-op, self-clan no-op, allied-captor lands on the principal
## side, and side direction (captor on side b -> b gains / a loses).
## Run: godot --headless -s tests/verify_hostage_war_score.gd

const _DO := preload("res://simulation/day_orchestrator.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, clan: String, family: String, insight: int, role: String = "") -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.character_name = "C%d" % cid
	c.clan = clan
	c.family = family
	c.insight_rank = insight
	c.role_position = role
	return c


func _war(clan_a: String, clan_b: String) -> WarData:
	var w := WarData.new()
	w.war_id = 1
	w.clan_a = clan_a
	w.clan_b = clan_b
	w.war_score_a = 50
	w.war_score_b = 50
	w.is_active = true
	return w


func _init() -> void:
	print("--- Hostage Leverage -> War Score (s22.9 line 97 / s53) ---")
	_test_rank_tiers()
	_test_champion_family()
	_test_noops()
	_test_side_direction_and_ally()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_rank_tiers() -> void:
	print("[1] rank thresholds -> tier shift")
	# Captor Crab (clan_a), hostage Lion (clan_b), rank-3 hostage -> +3 / -3.
	var captor := _char(1, "Crab", "Hida", 4)
	var by_id: Dictionary = {1: captor}
	var w := _war("Crab", "Lion")
	var h3 := _char(2, "Lion", "Akodo", 3)
	_DO._apply_hostage_war_score(h3, 1, [w], by_id)
	_ok(w.war_score_a == 53 and w.war_score_b == 47, "rank-3 hostage -> Crab +3 / Lion -3")

	# Rank-5 hostage -> +8 / -8.
	var w5 := _war("Crab", "Lion")
	var h5 := _char(3, "Lion", "Akodo", 5)
	_DO._apply_hostage_war_score(h5, 1, [w5], by_id)
	_ok(w5.war_score_a == 58 and w5.war_score_b == 42, "rank-5 hostage -> Crab +8 / Lion -8")

	# Rank-4 (>=3, <5) -> rank-3 tier.
	var w4 := _war("Crab", "Lion")
	var h4 := _char(4, "Lion", "Akodo", 4)
	_DO._apply_hostage_war_score(h4, 1, [w4], by_id)
	_ok(w4.war_score_a == 53 and w4.war_score_b == 47, "rank-4 hostage -> rank-3 tier (+3/-3)")


func _test_champion_family() -> void:
	print("[2] Champion's-family override")
	# A living Lion Champion of family Akodo is present; a rank-2 Akodo hostage is
	# champion-family -> the +8/-8 tier despite being below rank 3.
	var captor := _char(1, "Crab", "Hida", 4)
	var champ := _char(9, "Lion", "Akodo", 5, RoleRegistry.CLAN_CHAMPION)
	var h_champ_fam := _char(2, "Lion", "Akodo", 2)
	var by_id: Dictionary = {1: captor, 9: champ, 2: h_champ_fam}
	var w := _war("Crab", "Lion")
	_DO._apply_hostage_war_score(h_champ_fam, 1, [w], by_id)
	_ok(w.war_score_a == 58 and w.war_score_b == 42, "rank-2 champion-family -> +8/-8")

	# A rank-2 hostage of a DIFFERENT family (Matsu) is NOT champion-family -> no event.
	var w2 := _war("Crab", "Lion")
	var h_other := _char(3, "Lion", "Matsu", 2)
	_DO._apply_hostage_war_score(h_other, 1, [w2], {1: captor, 9: champ, 3: h_other})
	_ok(w2.war_score_a == 50 and w2.war_score_b == 50, "rank-2 non-champion-family -> no event")


func _test_noops() -> void:
	print("[3] no-op guards")
	var captor := _char(1, "Crab", "Hida", 4)
	# Rank < 3, not champion-family -> no War Score event.
	var w := _war("Crab", "Lion")
	var h2 := _char(2, "Lion", "Akodo", 2)
	_DO._apply_hostage_war_score(h2, 1, [w], {1: captor, 2: h2})
	_ok(w.war_score_a == 50 and w.war_score_b == 50, "rank-2, no champion present -> no event")

	# No war between the two clans -> no shift.
	var w_other := _war("Crane", "Scorpion")
	var h5 := _char(3, "Lion", "Akodo", 5)
	_DO._apply_hostage_war_score(h5, 1, [w_other], {1: captor, 3: h5})
	_ok(w_other.war_score_a == 50 and w_other.war_score_b == 50, "no war between clans -> no shift")

	# Same clan (captor's own clansman captured somehow) -> no shift.
	var w_self := _war("Crab", "Lion")
	var h_self := _char(4, "Crab", "Hida", 5)
	_DO._apply_hostage_war_score(h_self, 1, [w_self], {1: captor, 4: h_self})
	_ok(w_self.war_score_a == 50 and w_self.war_score_b == 50, "hostage same clan as captor -> no shift")

	# Missing captor -> no crash, no shift.
	var w_missing := _war("Crab", "Lion")
	var h_ok := _char(5, "Lion", "Akodo", 5)
	_DO._apply_hostage_war_score(h_ok, 999, [w_missing], {5: h_ok})
	_ok(w_missing.war_score_a == 50 and w_missing.war_score_b == 50, "captor not found -> no shift")


func _test_side_direction_and_ally() -> void:
	print("[4] side direction + allied captor")
	# Captor Lion is clan_b of the war -> capturing a Crab (clan_a) hostage shifts b up, a down.
	var captor := _char(1, "Lion", "Akodo", 4)
	var w := _war("Crab", "Lion")
	var h := _char(2, "Crab", "Hida", 5)
	_DO._apply_hostage_war_score(h, 1, [w], {1: captor, 2: h})
	_ok(w.war_score_b == 58 and w.war_score_a == 42, "captor on side b -> Lion +8 / Crab -8")

	# Allied captor: captor's clan (Bayushi->Scorpion) is an ally on side a. The shift must
	# land on side a's principal clan (Crab), not silently no-op.
	var w_ally := _war("Crab", "Lion")
	w_ally.allied_clans_a = ["Scorpion"]
	var ally_captor := _char(3, "Scorpion", "Bayushi", 4)
	var h_lion := _char(4, "Lion", "Akodo", 5)
	_DO._apply_hostage_war_score(h_lion, 3, [w_ally], {3: ally_captor, 4: h_lion})
	_ok(w_ally.war_score_a == 58 and w_ally.war_score_b == 42,
		"allied captor (side a) -> principal Crab +8 / Lion -8")
