extends SceneTree
## Runtime driver for s57.25.8 world-gen DECORATIVE tattoo seeding.
## Before this, world-gen seeded ZERO tattoos -- the whole LOCKED s57.25.8 section was inert
## (no NPC started with any tattoo). TattooSystem.seed_world_start_tattoos now seeds the
## decorative slice: Crab-Hida / Mantis bushi 40-60% of 1-2, Daidoji 50% wrist, Dragon non-monk
## 0-2. Togashi ability tattoos + artist-NPC seeding are DEFERRED. Verifies eligibility gating,
## location/quality/artist constraints, id uniqueness, and the seed-probability bands.
## Run: godot --headless -s tests/verify_worldgen_tattoos.gd

const _TS := preload("res://simulation/tattoo_system.gd")
const _CH := preload("res://shared/character_data.gd")
const _DICE := preload("res://simulation/dice_engine.gd")

var _pass: int = 0
var _fail: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _char(cid: int, clan: String, family: String, school: String, stype: int) -> L5RCharacterData:
	var c: L5RCharacterData = _CH.new()
	c.character_id = cid
	c.clan = clan
	c.family = family
	c.school = school
	c.school_type = stype
	return c


func _dice(seed_val: int) -> DiceEngine:
	var d: DiceEngine = _DICE.new()
	d.set_seed(seed_val)
	return d


func _init() -> void:
	print("--- s57.25.8 world-gen decorative tattoo seeding ---")
	_test_gating()
	_test_constraints()
	_test_probability_bands()
	_test_id_uniqueness()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_gating() -> void:
	print("[1] eligibility gating: ineligible clans/schools/dead get NOTHING")
	var d := _dice(99)
	var nid: Array = [1]
	# Togashi tattooed-monk -> ability tattoos (deferred), NOT decorative here.
	var togashi := _char(1, "Dragon", "Togashi", "Togashi Tattooed Order", Enums.SchoolType.MONK)
	var t_out: Array = _TS.seed_world_start_tattoos(togashi, d, nid)
	_ok(t_out.is_empty(), "Togashi Tattooed Order monk seeds no decorative tattoo (excluded)")
	# A non-tattoo clan (Lion Akodo bushi) -> nothing, over many rolls.
	var any_lion := false
	for i in 200:
		var lion := _char(2, "Lion", "Akodo", "Akodo Bushi", Enums.SchoolType.BUSHI)
		if not _TS.seed_world_start_tattoos(lion, d, nid).is_empty():
			any_lion = true
			break
	_ok(not any_lion, "Lion Akodo bushi never seeded a tattoo")
	# A non-Hida Crab (e.g. Kuni shugenja) -> nothing (only Hida warriors qualify for Crab).
	var any_kuni := false
	for i in 200:
		var kuni := _char(3, "Crab", "Kuni", "Kuni Shugenja", Enums.SchoolType.SHUGENJA)
		if not _TS.seed_world_start_tattoos(kuni, d, nid).is_empty():
			any_kuni = true
			break
	_ok(not any_kuni, "Crab Kuni shugenja never seeded a tattoo (Crab is Hida-warriors-only)")
	# Dead character -> nothing.
	var dead := _char(4, "Dragon", "Mirumoto", "Mirumoto Bushi", Enums.SchoolType.BUSHI)
	dead.wounds_taken = 9999
	_ok(_TS.seed_world_start_tattoos(dead, d, nid).is_empty(), "dead character seeds nothing")


func _test_constraints() -> void:
	print("[2] per-tattoo constraints: decorative, Normal/Fine, artist -1, no HEAD, Daidoji wrist-only")
	var d := _dice(7)
	var nid: Array = [1]
	var head := Enums.TattooBodyLocation.HEAD
	var wrists := [Enums.TattooBodyLocation.LEFT_WRIST_FOREARM, Enums.TattooBodyLocation.RIGHT_WRIST_FOREARM]
	var head_seen := false
	var bad_quality := false
	var bad_artist := false
	var bad_ability := false
	var daidoji_nonwrist := false
	var daidoji_multi := false
	# Sample many characters of each eligible type.
	for i in 400:
		var hida := _char(100 + i, "Crab", "Hida", "Hida Bushi", Enums.SchoolType.BUSHI)
		var mantis := _char(2000 + i, "Mantis", "Yoritomo", "Yoritomo Bushi", Enums.SchoolType.BUSHI)
		var dragon := _char(4000 + i, "Dragon", "Mirumoto", "Mirumoto Bushi", Enums.SchoolType.BUSHI)
		var daidoji := _char(6000 + i, "Crane", "Daidoji", "Daidoji Iron Warrior", Enums.SchoolType.BUSHI)
		for src: L5RCharacterData in [hida, mantis, dragon, daidoji]:
			var ts: Array = _TS.seed_world_start_tattoos(src, d, nid)
			var locs_used: Array = []
			for t: TattooData in ts:
				if t.body_location == head:
					head_seen = true
				if t.quality_tier != Enums.TattooQualityTier.NORMAL and t.quality_tier != Enums.TattooQualityTier.FINE:
					bad_quality = true
				if t.artist_id != -1:
					bad_artist = true
				if t.is_ability_tattoo or t.ability_granted != Enums.TattooAbility.NONE:
					bad_ability = true
				if t.body_location in locs_used:
					bad_ability = true  # duplicate location on same character
				locs_used.append(t.body_location)
			# Daidoji-specific: at most 1, wrist/forearm only.
			if src.family == "Daidoji":
				if ts.size() > 1:
					daidoji_multi = true
				for t2: TattooData in ts:
					if not (t2.body_location in wrists):
						daidoji_nonwrist = true
	_ok(not head_seen, "HEAD never seeded (bald-only rule respected)")
	_ok(not bad_quality, "every seeded tattoo is Normal or Fine quality")
	_ok(not bad_artist, "every world-start tattoo has artist_id == -1 (no bond)")
	_ok(not bad_ability, "every seeded tattoo is decorative (not ability) + no location collision")
	_ok(not daidoji_nonwrist, "Daidoji tattoos are wrist/forearm only")
	_ok(not daidoji_multi, "Daidoji seed at most one tattoo")


func _test_probability_bands() -> void:
	print("[3] seed-probability bands land in the LOCKED ranges")
	var d := _dice(31)
	var nid: Array = [1]
	var N := 2000
	# Daidoji ~50%.
	var daidoji_hit := 0
	# Crab-Hida ~<=60% (helper uses the 0.6 max), count 1-2.
	var hida_hit := 0
	var hida_counts_ok := true
	# Dragon 0-2 (~2/3 get >=1).
	var dragon_hit := 0
	var dragon_over2 := false
	for i in N:
		var da := _char(10000 + i, "Crane", "Daidoji", "Daidoji Iron Warrior", Enums.SchoolType.BUSHI)
		if _TS.seed_world_start_tattoos(da, d, nid).size() > 0:
			daidoji_hit += 1
		var hi := _char(20000 + i, "Crab", "Hida", "Hida Bushi", Enums.SchoolType.BUSHI)
		var hts: Array = _TS.seed_world_start_tattoos(hi, d, nid)
		if hts.size() > 0:
			hida_hit += 1
			if hts.size() < 1 or hts.size() > 2:
				hida_counts_ok = false
		var dr := _char(30000 + i, "Dragon", "Mirumoto", "Mirumoto Bushi", Enums.SchoolType.BUSHI)
		var drt: Array = _TS.seed_world_start_tattoos(dr, d, nid)
		if drt.size() > 0:
			dragon_hit += 1
		if drt.size() > 2:
			dragon_over2 = true
	var daidoji_rate := float(daidoji_hit) / float(N)
	var hida_rate := float(hida_hit) / float(N)
	var dragon_rate := float(dragon_hit) / float(N)
	_ok(daidoji_rate > 0.40 and daidoji_rate < 0.60, "Daidoji seed rate ~50%% (got %.2f)" % daidoji_rate)
	_ok(hida_rate > 0.50 and hida_rate < 0.70, "Crab-Hida seed rate ~60%% max (got %.2f)" % hida_rate)
	_ok(hida_counts_ok, "Crab-Hida seeded counts are all 1-2")
	_ok(dragon_rate > 0.55 and dragon_rate < 0.78, "Dragon seed rate ~2/3 (got %.2f)" % dragon_rate)
	_ok(not dragon_over2, "Dragon never seeds more than 2 decorative tattoos")


func _test_id_uniqueness() -> void:
	print("[4] tattoo ids are unique and next_tattoo_id advances")
	var d := _dice(555)
	var nid: Array = [1]
	var seen: Dictionary = {}
	var dup := false
	var total := 0
	for i in 500:
		var hi := _char(50000 + i, "Crab", "Hida", "Hida Bushi", Enums.SchoolType.BUSHI)
		for t: TattooData in _TS.seed_world_start_tattoos(hi, d, nid):
			total += 1
			if seen.has(t.tattoo_id):
				dup = true
			seen[t.tattoo_id] = true
	_ok(not dup, "all seeded tattoo_ids unique")
	_ok(total > 0, "some tattoos were seeded")
	_ok(nid[0] == total + 1, "next_tattoo_id advanced by the seeded count (%d, total %d)" % [nid[0], total])
