extends SceneTree
## Runtime driver for hardening ViolenceSystem.apply_consequences against the CLAUDE.md naming guard
## (Effect Application Design Decision #6). It pre-applies honor/glory/infamy to the attacker (Pattern B)
## and previously ALSO returned honor_change/glory_change/infamy_change -- the exact Pattern-A keys
## EffectApplicator consumes. Not a live double (the sole caller discards the return), but a footgun:
## routing the dict through EffectApplicator would double-charge. The returned stat deltas now use the
## guard-compliant subject_* pre-applied names. This driver proves the Pattern-B mutation still fires
## once AND the return dict no longer carries the re-appliable Pattern-A keys.
## Run: godot --headless -s tests/verify_violence_naming_guard.gd

const _VS := preload("res://simulation/violence_system.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _init() -> void:
	print("--- ViolenceSystem.apply_consequences: Pattern-B + naming guard (s11.3.12 / DD#6) ---")
	var attacker := L5RCharacterData.new()
	attacker.character_id = 1
	attacker.honor = 5.0
	attacker.glory = 3.0
	attacker.infamy = 0.0

	var eval: Dictionary = {
		"honor_loss": -0.2,
		"glory_loss": -0.1,
		"infamy_gain": 0.1,
		"punishment": "reprimand",
		"topic_tier": TopicData.Tier.TIER_4,
	}
	var result: Dictionary = _VS.apply_consequences(attacker, eval)

	print("[1] Pattern-B mutations still fire exactly once on the attacker")
	_ok(is_equal_approx(attacker.honor, 4.8), "honor 5.0 - 0.2 = 4.8 (got %.3f)" % attacker.honor)
	_ok(is_equal_approx(attacker.glory, 2.9), "glory 3.0 - 0.1 = 2.9 (got %.3f)" % attacker.glory)
	_ok(is_equal_approx(attacker.infamy, 0.1), "infamy 0.0 + 0.1 = 0.1 (got %.3f)" % attacker.infamy)

	print("[2] return dict does NOT carry the EffectApplicator-consumed Pattern-A keys")
	_ok(not result.has("honor_change"), "no honor_change key")
	_ok(not result.has("glory_change"), "no glory_change key")
	_ok(not result.has("infamy_change"), "no infamy_change key")
	_ok(not result.has("infamy_gain"), "no infamy_gain key")

	print("[3] return dict carries the guard-compliant subject_* metadata + non-stat fields")
	_ok(is_equal_approx(result.get("subject_honor_loss", 0.0), -0.2), "subject_honor_loss == -0.2")
	_ok(is_equal_approx(result.get("subject_glory_loss", 0.0), -0.1), "subject_glory_loss == -0.1")
	_ok(is_equal_approx(result.get("subject_infamy_gain", 0.0), 0.1), "subject_infamy_gain == 0.1")
	_ok(result.get("punishment", "") == "reprimand", "punishment metadata preserved")
	_ok(int(result.get("topic_tier", -1)) == int(TopicData.Tier.TIER_4), "topic_tier metadata preserved")

	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
