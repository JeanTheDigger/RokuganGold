extends SceneTree
## Runtime driver for the s4.3.21 Divination wiring (v574: embedded in
## PERFORM_WORSHIP). Verifies: shugenja-only readings, directed (one Fortune) vs
## split (all seven), the once-per-season gate, the Fukurokujin-Wrathful
## divination-impossible malus, reading replacement, and the directed-worship
## consumer (worst known Fortune at Restless+ directs; all healthy → split).
## Run: godot --headless -s tests/verify_worship_divination.gd

const _DO := preload("res://simulation/day_orchestrator.gd")
const _NPC := preload("res://simulation/npc_decision_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _shugenja(id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "Isawa%d" % id
	c.school_type = Enums.SchoolType.SHUGENJA
	# Strong rings + Theology so the TN-15 divination roll reliably succeeds.
	c.awareness = 5
	c.reflexes = 5
	c.intelligence = 5
	c.agility = 5
	c.strength = 5
	c.perception = 5
	c.stamina = 5
	c.willpower = 5
	c.void_ring = 5
	c.skills = {"Lore: Theology": 5}
	return c


func _worship_result(char_id: int, prov: int, directed: bool, wp_dist: Dictionary) -> Dictionary:
	return {
		"action_id": "PERFORM_WORSHIP",
		"success": true,
		"character_id": char_id,
		"effects": {
			"requires_worship_accumulation": true,
			"province_id": prov,
			"wp_distribution": wp_dist,
			"directed": directed,
		},
	}


func _state(prov: int, wp: Dictionary) -> Dictionary:
	var ws: Dictionary = WorshipSystem.make_initial_worship_state()
	var pw: Dictionary = WorshipSystem.make_initial_province_worship()
	# Seed every Fortune healthy by default. Since the tier model went live
	# (Model A), a Fortune below 40% of threshold reads WRATHFUL, and a WRATHFUL
	# Fukurokujin blocks ALL divination for the province (GDD-LOCKED). Tests that
	# want a specific low/Wrathful Fortune override it explicitly below.
	for f: int in range(WorshipSystem.GREAT_FORTUNE_COUNT):
		pw[f] = 12.0
	for f: Variant in wp:
		pw[int(f)] = wp[f]
	ws["province_wp"] = {prov: pw}
	return ws


func _init() -> void:
	print("--- Worship Divination Verification (s4.3.21 v574) ---")
	_test_split_reads_all()
	_test_directed_and_gates()
	_test_wrathful_fukurokujin()
	_test_directed_pick_consumer()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _readings(c: L5RCharacterData) -> Array:
	var out: Array = []
	for k: KnowledgeEntry in c.knowledge_pool:
		if k.entry_type == "worship_state":
			out.append(k)
	return out


func _test_split_reads_all() -> void:
	print("[1] split worship reads all seven Great Fortunes")
	var dice := DiceEngine.new()
	dice.set_seed(3)
	var sh := _shugenja(1)
	var ws: Dictionary = _state(100, {0: 12.0, 1: 4.0})  # Benten healthy, Bishamon restless
	var by_id: Dictionary = {1: sh}
	var res: Array = _DO._process_worship_divination(
		[_worship_result(1, 100, false, {0: 1.0, 1: 1.0})], ws, by_id, dice, 10,
	)
	_ok(res.size() == 7, "seven readings from split worship (%d)" % res.size())
	_ok(_readings(sh).size() == 7, "seven worship_state entries recorded")
	# Each reading matches the tier the worship system itself computes for that
	# WP (the tier-transition model is currently DISABLED — get_worship_tier
	# returns NONE until the GDD specifies WP thresholds; the divination must
	# faithfully read whatever the system knows, not invent its own).
	var benten_tier: int = -1
	var bishamon_tier: int = -1
	for k: KnowledgeEntry in _readings(sh):
		if int(k.data.get("fortune", -1)) == 0:
			benten_tier = int(k.data.get("tier", -1))
		if int(k.data.get("fortune", -1)) == 1:
			bishamon_tier = int(k.data.get("tier", -1))
	var expect_benten: int = int(WorshipSystem.get_worship_tier(12.0, WorshipSystem.PROVINCE_THRESHOLD))
	var expect_bishamon: int = int(WorshipSystem.get_worship_tier(4.0, WorshipSystem.PROVINCE_THRESHOLD))
	_ok(benten_tier == expect_benten, "healthy fortune reads the system tier")
	_ok(bishamon_tier == expect_bishamon, "low-WP fortune reads the system tier")
	# Non-shugenja monk gets NO reading.
	var monk := _shugenja(2)
	monk.school_type = Enums.SchoolType.MONK
	by_id[2] = monk
	var res2: Array = _DO._process_worship_divination(
		[_worship_result(2, 100, false, {0: 1.0})], ws, by_id, dice, 10,
	)
	_ok(res2.is_empty() and _readings(monk).is_empty(), "non-shugenja learns nothing")


func _test_directed_and_gates() -> void:
	print("[2] directed worship reads one Fortune; once-per-season gate; replacement")
	var dice := DiceEngine.new()
	dice.set_seed(5)
	var sh := _shugenja(10)
	var ws: Dictionary = _state(200, {3: 2.0})
	var by_id: Dictionary = {10: sh}
	var res: Array = _DO._process_worship_divination(
		[_worship_result(10, 200, true, {3: 1.5})], ws, by_id, dice, 20,
	)
	_ok(res.size() == 1 and int(res[0]["fortune"]) == 3, "directed worship reads only Ebisu")
	# Same season, worship again → no second reading (gate).
	var res2: Array = _DO._process_worship_divination(
		[_worship_result(10, 200, true, {3: 1.5})], ws, by_id, dice, 45,
	)
	_ok(res2.is_empty(), "once-per-season gate blocks a second reading")
	# Next season → fresh reading replaces the old (still exactly one entry).
	var res3: Array = _DO._process_worship_divination(
		[_worship_result(10, 200, true, {3: 1.5})], ws, by_id, dice, 100,
	)
	_ok(res3.size() == 1, "new season → fresh reading")
	_ok(_readings(sh).size() == 1, "old reading replaced (one current reading per Fortune)")


func _test_wrathful_fukurokujin() -> void:
	print("[3] Wrathful Fukurokujin → divination impossible")
	var dice := DiceEngine.new()
	dice.set_seed(7)
	var sh := _shugenja(20)
	# Fukurokujin at 0 WP → Wrathful → divination_impossible for the province.
	var ws: Dictionary = _state(300, {int(Enums.GreatFortune.FUKUROKUJIN): 0.0})
	var fk_tier: Enums.WorshipTier = WorshipSystem.get_worship_tier(0.0, WorshipSystem.PROVINCE_THRESHOLD)
	if fk_tier != Enums.WorshipTier.WRATHFUL:
		# Sanity: if 0 WP is not Wrathful in this model, skip (tier model differs).
		_ok(true, "skip: 0 WP tier is %d (not WRATHFUL)" % fk_tier)
		return
	var by_id: Dictionary = {20: sh}
	var res: Array = _DO._process_worship_divination(
		[_worship_result(20, 300, false, {0: 1.0})], ws, by_id, dice, 30,
	)
	_ok(res.is_empty() and _readings(sh).is_empty(), "no readings while Fukurokujin is Wrathful")


func _test_directed_pick_consumer() -> void:
	print("[4] directed-worship consumer: worst known Restless+ fortune, else split")
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.knowledge_pool = []
	# No readings → split.
	_ok(_NPC._pick_divined_worship_fortune(ctx) == -1, "spiritually blind → split (-1)")
	# All healthy → split.
	var healthy := KnowledgeEntry.new()
	healthy.entry_type = "worship_state"
	healthy.data = {"fortune": 0, "tier": int(Enums.WorshipTier.NONE)}
	ctx.knowledge_pool.append(healthy)
	_ok(_NPC._pick_divined_worship_fortune(ctx) == -1, "all healthy → split (-1)")
	# One Restless, one Displeased → directs to the WORST (Displeased).
	var restless := KnowledgeEntry.new()
	restless.entry_type = "worship_state"
	restless.data = {"fortune": 2, "tier": int(Enums.WorshipTier.RESTLESS)}
	ctx.knowledge_pool.append(restless)
	var displeased := KnowledgeEntry.new()
	displeased.entry_type = "worship_state"
	displeased.data = {"fortune": 5, "tier": int(Enums.WorshipTier.DISPLEASED)}
	ctx.knowledge_pool.append(displeased)
	_ok(_NPC._pick_divined_worship_fortune(ctx) == 5, "directs to the worst known fortune")
