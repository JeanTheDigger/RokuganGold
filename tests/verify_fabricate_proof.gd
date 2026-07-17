extends SceneTree
## Runtime driver for the s12.11 narrow producer: a successful FABRICATE_SECRET mints the forged
## document that serves as the secret's physical proof. SecretData.physical_proof_item_id had ZERO
## producers -- world-gen never set it and no production pass wrote it -- so the fully-wired consumer
## chain (day_orchestrator known_secrets injection "has_proof": physical_proof_item_id >= 0 ->
## _pick_best_secret -> executor metadata -> SecretSystem.reveal_privately/expose_publicly ->
## PHYSICAL_PROOF_FREE_RAISES) NEVER fired: no fabricated secret ever carried a proof item, so a
## fabricator never got the +1 Free Raise on Expose/Reveal. Fix: _process_fabricate_secret_writebacks
## now mints a covert-produced Evidence item (ItemCategory.EVIDENCE, is_evidence=true, Small, Normal)
## into the fabricator's on-person inventory and stamps the new secret's physical_proof_item_id.
## No invented values -- the item is the LOCKED s12.11 Evidence category; the free raise is the
## LOCKED s12.8 PHYSICAL_PROOF_FREE_RAISES already in the consumer.
## Run: godot --headless -s tests/verify_fabricate_proof.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _SEC := preload("res://simulation/secret_system.gd")
const _INV := preload("res://simulation/inventory_system.gd")
const _CHAR := preload("res://shared/character_data.gd")
const _SD := preload("res://shared/secret_data.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _mk_char(id: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CHAR.new()
	c.character_id = id
	c.wounds_taken = 0
	return c


func _mk_secret(subject_id: int, sev: int) -> SecretData:
	var s: SecretData = _SD.new()
	s.secret_id = -1
	s.subject_id = subject_id
	s.severity = sev
	s.fabricated = true
	s.description = "A fabricated slander"
	return s


func _result(fab_id: int, secret: SecretData, success: bool) -> Dictionary:
	return {
		"action_id": "FABRICATE_SECRET",
		"success": success,
		"character_id": fab_id,
		"effects": {"secret": secret},
	}


func _init() -> void:
	print("--- s12.11 FABRICATE_SECRET mints physical proof ---")
	_test_mints_proof()
	_test_no_mint_on_failure()
	_test_unresolvable_fabricator()
	_test_no_double_mint()
	_test_end_to_end_free_raise()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_mints_proof() -> void:
	print("[1] successful fabrication mints a forged Evidence item + links proof")
	var fab: L5RCharacterData = _mk_char(1)
	var secret: SecretData = _mk_secret(2, SecretData.Severity.TIER_2)
	var next_secret_id: Array = [10]
	var next_item_id: Array = [100]
	var active_secrets: Array = []
	_DO._process_fabricate_secret_writebacks(
		[_result(1, secret, true)], active_secrets, next_secret_id, next_item_id, {1: fab})
	_ok(secret.physical_proof_item_id == 100, "secret's physical_proof_item_id stamped = 100")
	_ok(next_item_id[0] == 101, "item counter advanced 100 -> 101")
	_ok(fab.items.size() == 1, "fabricator gained one item")
	if fab.items.size() == 1:
		var it: Dictionary = fab.items[0]
		_ok(it.get("item_id") == 100, "item id matches the linked proof id")
		_ok(it.get("category") == _INV.ItemCategory.EVIDENCE, "item category is EVIDENCE")
		_ok(it.get("is_evidence", false) == true, "item flagged is_evidence")
		_ok(it.get("size") == _INV.ItemSize.SMALL, "item is Small (a document)")
		_ok(it.get("quality_tier") == 1, "item quality is Normal (1)")
		_ok(it.get("storage_tier") == _INV.StorageTier.ON_PERSON, "item is on-person")
	_ok(active_secrets.size() == 1 and active_secrets[0] == secret, "secret appended to active_secrets")
	# The has_proof injection predicate the orchestrator uses fires now.
	_ok(secret.physical_proof_item_id >= 0, "has_proof predicate (physical_proof_item_id >= 0) true")


func _test_no_mint_on_failure() -> void:
	print("[2] a FAILED fabrication mints nothing")
	var fab: L5RCharacterData = _mk_char(1)
	var secret: SecretData = _mk_secret(2, SecretData.Severity.TIER_2)
	var next_item_id: Array = [100]
	var active_secrets: Array = []
	_DO._process_fabricate_secret_writebacks(
		[_result(1, secret, false)], active_secrets, [10], next_item_id, {1: fab})
	_ok(fab.items.is_empty(), "no item on failed fabrication")
	_ok(next_item_id[0] == 100, "item counter untouched")
	_ok(active_secrets.is_empty(), "no secret appended on failure")


func _test_unresolvable_fabricator() -> void:
	print("[3] unresolvable/dead fabricator -> no proof minted, secret still appended")
	var secret: SecretData = _mk_secret(2, SecretData.Severity.TIER_2)
	var next_item_id: Array = [100]
	var active_secrets: Array = []
	# Empty characters_by_id -> fabricator not found.
	_DO._process_fabricate_secret_writebacks(
		[_result(1, secret, true)], active_secrets, [10], next_item_id, {})
	_ok(secret.physical_proof_item_id == -1, "no proof link when fabricator unresolvable")
	_ok(next_item_id[0] == 100, "item counter untouched (graceful degradation)")
	_ok(active_secrets.size() == 1, "secret still appended (backward-compatible)")
	# Dead fabricator -> also no mint.
	var dead: L5RCharacterData = _mk_char(1)
	dead.wounds_taken = 9999  # lethal
	var s2: SecretData = _mk_secret(2, SecretData.Severity.TIER_2)
	var ni2: Array = [100]
	var as2: Array = []
	_DO._process_fabricate_secret_writebacks([_result(1, s2, true)], as2, [10], ni2, {1: dead})
	_ok(s2.physical_proof_item_id == -1, "dead fabricator mints no proof")
	_ok(ni2[0] == 100, "item counter untouched for dead fabricator")


func _test_no_double_mint() -> void:
	print("[4] a secret that already carries proof is not re-minted")
	var fab: L5RCharacterData = _mk_char(1)
	var secret: SecretData = _mk_secret(2, SecretData.Severity.TIER_2)
	secret.physical_proof_item_id = 55  # already has proof
	var next_item_id: Array = [100]
	_DO._process_fabricate_secret_writebacks(
		[_result(1, secret, true)], [], [10], next_item_id, {1: fab})
	_ok(secret.physical_proof_item_id == 55, "existing proof link preserved")
	_ok(fab.items.is_empty(), "no second item minted")
	_ok(next_item_id[0] == 100, "item counter untouched")


func _test_end_to_end_free_raise() -> void:
	print("[5] minted proof activates the +1 Free Raise on Expose a Secret Publicly")
	var fab: L5RCharacterData = _mk_char(1)
	var subject: L5RCharacterData = _mk_char(2)
	var secret: SecretData = _mk_secret(2, SecretData.Severity.TIER_3)
	_DO._process_fabricate_secret_writebacks([_result(1, secret, true)], [], [10], [100], {1: fab})
	var has_proof: bool = secret.physical_proof_item_id >= 0  # the orchestrator's injection predicate
	_ok(has_proof, "has_proof true after minting")
	var chars: Dictionary = {1: fab, 2: subject}
	var with_proof: Dictionary = _SEC.expose_publicly(secret, fab, subject, [], chars, has_proof, 100)
	_ok(int(with_proof.get("free_raises", 0)) == _SEC.PHYSICAL_PROOF_FREE_RAISES,
		"expose with proof grants PHYSICAL_PROOF_FREE_RAISES (=%d)" % _SEC.PHYSICAL_PROOF_FREE_RAISES)
	# Control: a proofless exposure grants zero free raises.
	var subject2: L5RCharacterData = _mk_char(3)
	var noproof_secret: SecretData = _mk_secret(3, SecretData.Severity.TIER_3)
	var without: Dictionary = _SEC.expose_publicly(
		noproof_secret, fab, subject2, [], {1: fab, 3: subject2}, false, 100)
	_ok(int(without.get("free_raises", 0)) == 0, "expose WITHOUT proof grants 0 free raises")
