extends SceneTree
## Runtime driver for s12.8:39 context-severity upgrade — a dormant LOCKED arbiter now owner-authorized.
## SecretSystem.get_effective_severity (a secret moves UP one tier if a higher-Status character is
## involved OR the act is < RECENCY_SEASONS old) had ZERO callers -- reveal_privately/expose_publicly
## used the raw secret.severity. Two of its three inputs had no producer: SecretData carried no
## involved_id and no creation-day. FIX (owner-approved 2026-07-09): SecretData gains involved_id +
## ic_day_created; the affair mint stamps them (involved = seducer, created = ic_day); new
## SecretSystem.get_exposure_severity resolves the effective tier (graceful raw severity when unset),
## wired into both exposure funcs (+ ctx.ic_day/characters_by_id from the executor).
## Run: godot --headless -s tests/verify_secret_context_severity.gd

const _SEC := preload("res://simulation/secret_system.gd")
const _SD := preload("res://shared/secret_data.gd")
const _CH := preload("res://shared/character_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, status: float) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.status = status
	return c


func _secret(sev: int, subject: int, involved: int, created: int) -> SecretData:
	var s: SecretData = _SD.new()
	s.secret_id = 1
	s.subject_id = subject
	s.severity = sev
	s.involved_id = involved
	s.ic_day_created = created
	return s


func _init() -> void:
	print("--- s12.8:39 context-severity upgrade ---")
	_test_helper()
	_test_exposure_integration()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_helper() -> void:
	print("[1] get_exposure_severity: involved-higher / recency bumps; graceful raw; T4/T1 guard")
	var subject := _char(1, 3.0)      # subject status 3
	var high := _char(2, 6.0)         # involved out-ranks subject
	var low := _char(3, 1.0)          # involved below subject
	var chars := {1: subject, 2: high, 3: low}
	var now := 500

	# T3 secret, no context (involved unset, created unset) -> raw T3.
	var raw := _secret(_SD.Severity.TIER_3, 1, -1, -1)
	_ok(_SEC.get_exposure_severity(raw, subject, chars, now) == _SD.Severity.TIER_3, "no context -> raw T3")

	# T3 + higher-status involved -> bump to T2.
	var inv_hi := _secret(_SD.Severity.TIER_3, 1, 2, -1)
	_ok(_SEC.get_exposure_severity(inv_hi, subject, chars, now) == _SD.Severity.TIER_2,
		"higher-status involved -> T3 bumps to T2")

	# T3 + lower-status involved (no recency) -> stays T3.
	var inv_lo := _secret(_SD.Severity.TIER_3, 1, 3, -1)
	_ok(_SEC.get_exposure_severity(inv_lo, subject, chars, now) == _SD.Severity.TIER_3,
		"lower-status involved -> no bump (T3)")

	# T3 + recent act (created this season, seasons_since 0 < 4) -> bump to T2.
	var recent := _secret(_SD.Severity.TIER_3, 1, -1, now)
	_ok(_SEC.get_exposure_severity(recent, subject, chars, now) == _SD.Severity.TIER_2,
		"recent act -> T3 bumps to T2")

	# T3 + old act (created ~11 seasons ago) -> no recency bump -> T3.
	var old := _secret(_SD.Severity.TIER_3, 1, -1, 0)
	_ok(_SEC.get_exposure_severity(old, subject, chars, 1000) == _SD.Severity.TIER_3,
		"old act (>= RECENCY_SEASONS) -> no bump (T3)")

	# graceful: involved_id set but not resolvable -> no bump.
	var missing := _secret(_SD.Severity.TIER_3, 1, 99, -1)
	_ok(_SEC.get_exposure_severity(missing, subject, chars, now) == _SD.Severity.TIER_3,
		"unresolvable involved id -> graceful raw T3")

	# arbiter guard: T4 with higher involved + recent still stays T4 (its `sev < TIER_4` excludes it).
	var t4 := _secret(_SD.Severity.TIER_4, 1, 2, now)
	_ok(_SEC.get_exposure_severity(t4, subject, chars, now) == _SD.Severity.TIER_4,
		"T4 not upgraded (arbiter's own LOCKED guard)")

	# arbiter guard: T2 with higher involved -> T1 (upgrade reaches the ceiling).
	var t2 := _secret(_SD.Severity.TIER_2, 1, 2, -1)
	_ok(_SEC.get_exposure_severity(t2, subject, chars, now) == _SD.Severity.TIER_1,
		"T2 + higher involved -> T1")


func _test_exposure_integration() -> void:
	print("[2] expose_publicly / reveal_privately apply the EFFECTIVE severity")
	var subject := _char(1, 3.0)
	var high := _char(2, 6.0)
	var witness := _char(9, 4.0)
	var chars := {1: subject, 2: high, 9: witness}
	var now := 500

	# A T3 married-affair secret with a higher-status seducer -> effective T2 on exposure.
	var s_bump := _secret(_SD.Severity.TIER_3, 1, 2, -1)
	var r_bump: Dictionary = _SEC.expose_publicly(s_bump, high, subject, [9], chars, false, now)
	_ok(int(r_bump.get("severity", -1)) == _SD.Severity.TIER_2, "expose returns effective T2 (bumped)")

	# Control: same tier, no context -> stays T3, weaker per-witness disposition hit.
	var subject2 := _char(1, 3.0)
	var witness2 := _char(9, 4.0)
	var s_raw := _secret(_SD.Severity.TIER_3, 1, -1, -1)
	var r_raw: Dictionary = _SEC.expose_publicly(s_raw, high, subject2, [9], {1: subject2, 9: witness2}, false, now)
	_ok(int(r_raw.get("severity", -1)) == _SD.Severity.TIER_3, "control expose stays raw T3")
	# T2 (more severe) inflicts a stronger per-witness disposition loss than T3.
	_ok(int(r_bump.get("disposition_per_witness", 0)) < int(r_raw.get("disposition_per_witness", 0)),
		"bumped T2 exposure inflicts a harsher per-witness disposition hit than raw T3")

	# reveal_privately likewise uses the effective severity.
	var subject3 := _char(1, 3.0)
	var recipient := _char(9, 4.0)
	var s_priv := _secret(_SD.Severity.TIER_3, 1, 2, -1)
	var r_priv: Dictionary = _SEC.reveal_privately(s_priv, high, recipient, subject3, false, {1: subject3, 2: high}, now)
	_ok(int(r_priv.get("severity", -1)) == _SD.Severity.TIER_2, "reveal_privately returns effective T2")

	# backward-compat: reveal_privately with no context args -> raw severity (no crash).
	var subject4 := _char(1, 3.0)
	var recip4 := _char(9, 4.0)
	var s_compat := _secret(_SD.Severity.TIER_3, 1, 2, now)
	var r_compat: Dictionary = _SEC.reveal_privately(s_compat, high, recip4, subject4)
	_ok(int(r_compat.get("severity", -1)) == _SD.Severity.TIER_3,
		"reveal_privately without context args -> raw T3 (backward-compatible)")
