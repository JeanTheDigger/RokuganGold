extends SceneTree
## Runtime driver for wiring SeppukuDecision.will_accept_seppuku into the live NPC
## decision. Before this fix the RESPOND_TO_SEPPUKU need resolved via a soft 70/30
## objective_alignment tilt toward ACCEPT for everyone, so the deterministic
## personality arbiter (Honor rank + Bushido/Shourido virtue) never actually
## decided. Verifies: (1) the arbiter's own verdicts, and (2) that score_all now
## makes the arbiter's verdict win decisively for the two seppuku options.
## Run: godot --headless -s tests/verify_seppuku_arbiter.gd

const _NPC := preload("res://simulation/npc_decision_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(honor: float, bushido: Enums.BushidoVirtue, shourido: Enums.ShouridoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Accused"
	c.honor = honor
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	return c


func _ctx(c: L5RCharacterData) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = c.character_id
	ctx.bushido_virtue = c.bushido_virtue
	ctx.shourido_virtue = c.shourido_virtue
	ctx.honor = c.honor
	return ctx


func _need() -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RESPOND_TO_SEPPUKU"
	need.source = "seppuku_offered"
	need.target_intent = "case_7"
	return need


func _opts() -> Array:
	var accept := NPCDataStructures.ScoredAction.new()
	accept.action_id = "ACCEPT_SEPPUKU"
	var refuse := NPCDataStructures.ScoredAction.new()
	refuse.action_id = "REFUSE_SEPPUKU"
	return [accept, refuse]


func _load_tables() -> Dictionary:
	# Minimal: only objective_alignment is needed to prove the override REPLACES the
	# baseline 70/30 tilt; the other lookups .get() gracefully to defaults.
	var tables: Dictionary = {}
	var f := FileAccess.open("res://systems/npc_engine/data/tables/objective_alignment.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			tables["objective_alignment"] = parsed
	return tables


## Runs score_all with the arbiter override and returns which action_id wins the
## final total score.
func _decide(c: L5RCharacterData, tables: Dictionary) -> Dictionary:
	var opts: Array = _opts()
	_NPC.score_all(opts, _need(), _ctx(c), tables, [], [], c, 0, {})
	var accept: NPCDataStructures.ScoredAction = opts[0]
	var refuse: NPCDataStructures.ScoredAction = opts[1]
	var winner: String = accept.action_id if accept.get_total_score() >= refuse.get_total_score() else refuse.action_id
	return {
		"winner": winner,
		"accept_align": accept.objective_alignment,
		"refuse_align": refuse.objective_alignment,
	}


func _init() -> void:
	print("--- Seppuku Arbiter Wiring Verification (s57.47.4 / s18-19) ---")
	_test_arbiter_verdicts()
	_test_baseline_tilt_present()
	_test_wiring_decisive()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_arbiter_verdicts() -> void:
	print("[1] the deterministic arbiter itself")
	# Meiyo bushi at honor rank 5 → accepts (code demands it).
	_ok(SeppukuDecision.will_accept_seppuku(
		_char(5.0, Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE)).get("accepts", false),
		"Meiyo bushi accepts")
	# Honor rank 0 → always refuses, even a Meiyo one (no investment in the code).
	_ok(not SeppukuDecision.will_accept_seppuku(
		_char(0.5, Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE)).get("accepts", true),
		"Honor Rank 0 always refuses (overrides virtue)")
	# Ketsui shourido → refuses (self-preservation).
	_ok(not SeppukuDecision.will_accept_seppuku(
		_char(5.0, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI)).get("accepts", true),
		"Ketsui shourido refuses")
	# Dosatsu shourido at honor >= 1 → calculated acceptance.
	_ok(SeppukuDecision.will_accept_seppuku(
		_char(3.0, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.DOSATSU)).get("accepts", false),
		"Dosatsu shourido accepts at honor rank >= 0")


func _test_baseline_tilt_present() -> void:
	print("[2] baseline objective_alignment (the tilt the arbiter overrides) is loaded")
	var tables: Dictionary = _load_tables()
	var oa: Dictionary = tables.get("objective_alignment", {})
	var seppuku: Dictionary = oa.get("RESPOND_TO_SEPPUKU", {})
	_ok(int(seppuku.get("ACCEPT_SEPPUKU", -1)) == 70 and int(seppuku.get("REFUSE_SEPPUKU", -1)) == 30,
		"JSON baseline is the 70/30 accept tilt")


func _test_wiring_decisive() -> void:
	print("[3] score_all makes the arbiter's verdict win decisively")
	var tables: Dictionary = _load_tables()
	# Meiyo bushi (arbiter accepts) → ACCEPT wins; override sets +100 / -1000.
	var d1: Dictionary = _decide(_char(5.0, Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE), tables)
	_ok(d1["winner"] == "ACCEPT_SEPPUKU", "Meiyo bushi → ACCEPT wins")
	_ok(float(d1["accept_align"]) == 100.0 and float(d1["refuse_align"]) == -1000.0,
		"override replaced the 70/30 tilt (accept 100, refuse -1000)")
	# Honor Rank 0 (arbiter refuses) → REFUSE wins, DESPITE the baseline favoring accept.
	var d2: Dictionary = _decide(_char(0.5, Enums.BushidoVirtue.MEIYO, Enums.ShouridoVirtue.NONE), tables)
	_ok(d2["winner"] == "REFUSE_SEPPUKU", "Honor Rank 0 → REFUSE wins over the accept tilt")
	_ok(float(d2["refuse_align"]) == 100.0 and float(d2["accept_align"]) == -1000.0,
		"override flipped to refuse (refuse 100, accept -1000)")
	# Ketsui shourido (arbiter refuses) → REFUSE wins.
	var d3: Dictionary = _decide(_char(5.0, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI), tables)
	_ok(d3["winner"] == "REFUSE_SEPPUKU", "Ketsui shourido → REFUSE wins")
	# Dosatsu shourido (arbiter accepts) → ACCEPT wins.
	var d4: Dictionary = _decide(_char(3.0, Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.DOSATSU), tables)
	_ok(d4["winner"] == "ACCEPT_SEPPUKU", "Dosatsu shourido → ACCEPT wins")
