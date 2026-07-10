extends SceneTree
## Runtime driver for s12.8:271 affair-secret minting — a dormant arbiter now owner-authorized.
## SeductionSystem.get_affair_severity (the LOCKED tier arbiter: cross-clan+political -> T2 /
## married -> T3 / unmarried similar -> T4) had ZERO callers and NO affair secret was ever minted,
## so the whole "the entanglement generates a secret object" clause (discovery -> blackmail ->
## expose) was inert. FIX: DayOrchestrator._process_seduction_entanglements now mints the affair
## secret on a NEW entanglement via _mint_affair_secret -- subject = the seduced target, known_by =
## the two participants (LOCKED), severity from the arbiter, "political tension" = cross-clan
## (owner-approved default), deduped per (seducer,target) pair.
## Run: godot --headless -s tests/verify_affair_secret.gd

const _SS := preload("res://simulation/seduction_system.gd")
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


func _char(cid: int, clan: String, spouse: int, name: String) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.clan = clan
	c.spouse_id = spouse
	c.character_name = name
	return c


func _init() -> void:
	print("--- s12.8:271 affair-secret minting ---")
	_test_arbiter()
	_test_mint()
	_test_end_to_end()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


# -- 1. the LOCKED severity arbiter --------------------------------------------
func _test_arbiter() -> void:
	print("[1] get_affair_severity: T4 unmarried / T3 married / T2 cross-clan+political (T2 first)")
	_ok(_SS.get_affair_severity(false, false, false, false) == _SD.Severity.TIER_4, "unmarried same-clan -> T4")
	_ok(_SS.get_affair_severity(true, false, false, false) == _SD.Severity.TIER_3, "seducer married -> T3")
	_ok(_SS.get_affair_severity(false, true, false, false) == _SD.Severity.TIER_3, "target married -> T3")
	_ok(_SS.get_affair_severity(false, false, true, true) == _SD.Severity.TIER_2, "cross-clan+political -> T2")
	# T2 precedence: cross-clan+political overrides the married branch.
	_ok(_SS.get_affair_severity(true, true, true, true) == _SD.Severity.TIER_2, "cross-clan+political beats married -> T2")


# -- 2. _mint_affair_secret: subject/known_by/dedup/guard -----------------------
func _test_mint() -> void:
	print("[2] _mint_affair_secret: subject=target, known_by=[both], severity, dedup, null-guard")
	var seducer := _char(1, "Scorpion", -1, "Bayushi")
	var target := _char(2, "Scorpion", 5, "Shosuro")  # married, same clan -> T3
	var chars := {1: seducer, 2: target}
	var secrets: Array = []
	var nsi: Array = [1]
	DayOrchestrator._mint_affair_secret(1, 2, chars, secrets, nsi)
	_ok(secrets.size() == 1, "one affair secret minted")
	var sec: SecretData = secrets[0] as SecretData
	_ok(sec != null and sec.subject_id == 2, "subject = the seduced target")
	_ok(sec.severity == _SD.Severity.TIER_3, "married target -> Tier 3")
	_ok(sec.known_by_ids.has(1) and sec.known_by_ids.has(2) and sec.known_by_ids.size() == 2,
		"known_by = the two participants only")
	_ok(sec.slug == "affair_1_2", "slug affair_<seducer>_<target>")
	_ok(sec.fabricated == false, "not fabricated (a real affair)")
	_ok(nsi[0] == 2, "next_secret_id advanced")

	# cross-clan -> political tension default -> Tier 2 (overrides married)
	var s2 := _char(10, "Crane", -1, "Doji")
	var t2 := _char(11, "Lion", 7, "Matsu")  # married AND cross-clan -> political -> T2
	var secrets2: Array = []
	var nsi2: Array = [1]
	DayOrchestrator._mint_affair_secret(10, 11, {10: s2, 11: t2}, secrets2, nsi2)
	_ok((secrets2[0] as SecretData).severity == _SD.Severity.TIER_2, "cross-clan affair -> Tier 2 (political=cross-clan)")

	# dedup: minting the same pair again does not add a second secret
	DayOrchestrator._mint_affair_secret(1, 2, chars, secrets, nsi)
	_ok(secrets.size() == 1, "re-mint for same pair -> deduped (secret persists past a break)")

	# null guard: empty characters_by_id -> no mint, no crash
	var secrets3: Array = []
	DayOrchestrator._mint_affair_secret(1, 2, {}, secrets3, [1])
	_ok(secrets3.size() == 0, "unresolvable participants -> no mint, no crash")


# -- 3. end-to-end through the entanglement pass -------------------------------
func _test_end_to_end() -> void:
	print("[3] _process_seduction_entanglements mints the affair secret on a new entanglement")
	var seducer := _char(1, "Scorpion", -1, "Bayushi")
	var target := _char(2, "Crab", -1, "Hida")  # cross-clan, unmarried -> T2 (political=cross-clan)
	var chars := {1: seducer, 2: target}
	var day_results: Array = [{
		"action_id": "SEDUCE",
		"success": true,
		"character_id": 1,
		"target_npc_id": 2,
		"effects": {"creates_entanglement": true},
	}]
	var entanglements: Array = []
	var secrets: Array = []
	var nsi: Array = [1]
	DayOrchestrator._process_seduction_entanglements(day_results, entanglements, 100, chars, secrets, nsi)
	_ok(entanglements.size() == 1, "entanglement created")
	_ok(secrets.size() == 1, "affair secret minted end-to-end")
	var sec: SecretData = secrets[0] as SecretData
	_ok(sec != null and sec.subject_id == 2 and sec.severity == _SD.Severity.TIER_2,
		"end-to-end secret: subject=target, cross-clan -> T2")
	_ok(sec.known_by_ids.has(1) and sec.known_by_ids.has(2),
		"end-to-end secret known by both participants (feeds EAVESDROP/SHADOW discovery)")

	# a FAILED seduction mints nothing
	var day_results_fail: Array = [{
		"action_id": "SEDUCE", "success": false, "character_id": 1, "target_npc_id": 2,
		"effects": {"creates_entanglement": true},
	}]
	var ent2: Array = []
	var sec2: Array = []
	DayOrchestrator._process_seduction_entanglements(day_results_fail, ent2, 100, chars, sec2, [1])
	_ok(ent2.is_empty() and sec2.is_empty(), "failed seduction -> no entanglement, no secret")
