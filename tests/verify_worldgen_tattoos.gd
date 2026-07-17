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
const _WB := preload("res://simulation/world_bootstrap.gd")

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
	print("--- s57.25.8 world-gen tattoo seeding (decorative + Togashi ability) ---")
	_test_gating()
	_test_constraints()
	_test_probability_bands()
	_test_id_uniqueness()
	_test_ability_tattoos()
	_test_artist_seeding()
	_test_artist_id_routing()
	_test_disposition_bonds()
	print("--- %d passed, %d failed ---" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_gating() -> void:
	print("[1] eligibility gating: ineligible clans/dead get NOTHING")
	var d := _dice(99)
	var nid: Array = [1]
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


func _togashi(cid: int, school: String, rank: int) -> L5RCharacterData:
	var c := _char(cid, "Dragon", "Togashi", school, Enums.SchoolType.MONK)
	c.insight_rank = rank
	return c


func _test_ability_tattoos() -> void:
	print("[5] Togashi ability tattoos: LOCKED per-rank allotment, distinct abilities/locations")
	var d := _dice(444)
	var nid: Array = [1]
	var head := Enums.TattooBodyLocation.HEAD

	# LOCKED per-rank allotments (get_allotment_for_rank).
	var r1: Array = _TS.seed_world_start_tattoos(_togashi(1, "Togashi Tattooed Order", 1), d, nid)
	_ok(r1.size() == 2, "Togashi Rank 1 -> 2 ability tattoos (got %d)" % r1.size())
	var r3: Array = _TS.seed_world_start_tattoos(_togashi(2, "Togashi Tattooed Order", 3), d, nid)
	_ok(r3.size() == 4, "Togashi Rank 3 -> 4 ability tattoos, the GDD worked example (got %d)" % r3.size())
	var r5: Array = _TS.seed_world_start_tattoos(_togashi(3, "Togashi Tattooed Order", 5), d, nid)
	_ok(r5.size() == 6, "Togashi Rank 5 -> 6 ability tattoos (got %d)" % r5.size())
	var kik: Array = _TS.seed_world_start_tattoos(_togashi(4, "Kikage Zumi", 3), d, nid)
	_ok(kik.size() == 2, "Kikage Zumi Rank 3 -> 2 (got %d)" % kik.size())
	var ho4: Array = _TS.seed_world_start_tattoos(_togashi(5, "Hoshi Tsurui Zumi", 4), d, nid)
	_ok(ho4.size() == 2, "Hoshi Tsurui Zumi Rank 4 -> 2 (got %d)" % ho4.size())
	var ho1: Array = _TS.seed_world_start_tattoos(_togashi(6, "Hoshi Tsurui Zumi", 1), d, nid)
	_ok(ho1.size() == 1, "Hoshi Tsurui Zumi Rank 1 -> 1 (got %d)" % ho1.size())

	# Every ability tattoo: is_ability true, ability != NONE, artist -1, no HEAD, distinct within monk.
	var bad := false
	var abils_seen: Array = []
	var locs_seen: Array = []
	for t: TattooData in r5:
		if not t.is_ability_tattoo or t.ability_granted == Enums.TattooAbility.NONE:
			bad = true
		if t.artist_id != -1:
			bad = true
		if t.body_location == head:
			bad = true
		if t.ability_granted in abils_seen or t.body_location in locs_seen:
			bad = true  # duplicate ability or location on the same monk
		abils_seen.append(t.ability_granted)
		locs_seen.append(t.body_location)
	_ok(not bad, "Rank-5 monk: 6 ability tattoos, all ability/non-NONE/artist -1/no-HEAD/distinct")


func _test_artist_seeding() -> void:
	print("[6] artist-NPC seeding: 5 artists, correct clan/family/Tattooing rank, ids advance")
	var d := _dice(1234)
	var chars: Array = []
	var next_char: Array = [500]
	var m: Dictionary = _WB._seed_tattoo_artists(chars, d, next_char)
	_ok(chars.size() == 5, "5 tattoo artists created (got %d)" % chars.size())
	_ok(next_char[0] == 505, "next_character_id advanced by 5 (got %d)" % next_char[0])
	# The category map covers every recipient branch.
	for cat: String in ["dragon", "crab", "mantis", "daidoji", "togashi"]:
		_ok(m.has(cat) and int(m[cat]) >= 500, "artist_by_category has '%s'" % cat)
	# LOCKED Tattooing floor ranks per clan/family + real clan membership.
	var want_rank := {"Dragon_Kitsuki": 2, "Crab_Kaiu": 2, "Mantis_Yoritomo": 2, "Crane_Daidoji": 1, "Dragon_Togashi": 3}
	var seen_keys: Array = []
	var ids: Dictionary = {}
	var all_ranked := true
	for c: L5RCharacterData in chars:
		var key: String = "%s_%s" % [c.clan, c.family]
		seen_keys.append(key)
		ids[c.character_id] = true
		var tr: int = int(c.skills.get("Artisan: Tattooing", 0))
		if tr < int(want_rank.get(key, 99)):
			all_ranked = false
	_ok(all_ranked, "every artist has Artisan: Tattooing >= its LOCKED floor rank")
	_ok(ids.size() == 5, "all 5 artist ids distinct")
	for key: String in want_rank:
		_ok(key in seen_keys, "artist for %s exists" % key)


func _test_artist_id_routing() -> void:
	print("[7] artist_by_category routes recipient -> its artist_id on seeded tattoos")
	var d := _dice(88)
	var nid: Array = [1]
	var amap := {"dragon": 900, "crab": 901, "mantis": 902, "daidoji": 903, "togashi": 904}
	# Force a Crab-Hida hit until we get one, then check artist_id == 901.
	var crab_ok := false
	for i in 200:
		var hi := _char(1000 + i, "Crab", "Hida", "Hida Bushi", Enums.SchoolType.BUSHI)
		var ts: Array = _TS.seed_world_start_tattoos(hi, d, nid, 0, amap)
		if ts.size() > 0:
			crab_ok = true
			for t: TattooData in ts:
				if t.artist_id != 901:
					crab_ok = false
			break
	_ok(crab_ok, "Crab-Hida tattoos carry the 'crab' artist_id (901)")
	# Togashi monk -> togashi elder artist_id.
	var mo := _togashi(2000, "Togashi Tattooed Order", 3)
	var mts: Array = _TS.seed_world_start_tattoos(mo, d, nid, 0, amap)
	var tog_ok := mts.size() == 4
	for t: TattooData in mts:
		if t.artist_id != 904:
			tog_ok = false
	_ok(tog_ok, "Togashi ability tattoos carry the 'togashi' elder artist_id (904)")
	# Empty map -> artist_id stays -1 (backward-compatible no-bond degradation).
	var neg := false
	for i in 200:
		var hi2 := _char(3000 + i, "Crab", "Hida", "Hida Bushi", Enums.SchoolType.BUSHI)
		var ts2: Array = _TS.seed_world_start_tattoos(hi2, d, nid)
		if ts2.size() > 0:
			for t: TattooData in ts2:
				if t.artist_id != -1:
					neg = true
			break
	_ok(not neg, "empty artist map -> artist_id -1 (backward compatible)")


func _mk_tattoo(tid: int, recipient: int, artist: int, quality: int) -> TattooData:
	var t: TattooData = TattooData.new()
	t.tattoo_id = tid
	t.recipient_id = recipient
	t.artist_id = artist
	t.quality_tier = quality
	return t


func _test_disposition_bonds() -> void:
	print("[8] s57.25.4 bond: bidirectional +tier, skips artist<0 and self-tattoo")
	var artist := _char(10, "Dragon", "Kitsuki", "S", Enums.SchoolType.ARTISAN)
	var recip := _char(11, "Dragon", "Mirumoto", "S", Enums.SchoolType.BUSHI)
	var lone := _char(12, "Crab", "Hida", "S", Enums.SchoolType.BUSHI)
	var chars_by_id := {10: artist, 11: recip, 12: lone}
	var tattoos: Array = [
		_mk_tattoo(1, 11, 10, Enums.TattooQualityTier.NORMAL),  # +1 both ways
		_mk_tattoo(2, 11, 10, Enums.TattooQualityTier.FINE),    # +2 both ways (stacks)
		_mk_tattoo(3, 12, -1, Enums.TattooQualityTier.FINE),    # no artist -> no bond
		_mk_tattoo(4, 10, 10, Enums.TattooQualityTier.MASTERWORK),  # self -> skipped
	]
	_WB._apply_world_start_tattoo_bonds(tattoos, chars_by_id)
	# recip -> artist and artist -> recip both accumulate +1 (Normal) + +2 (Fine) = +3.
	_ok(int(recip.disposition_values.get(10, 0)) == 3, "recipient -> artist == +3 (Normal+Fine, got %d)" % int(recip.disposition_values.get(10, 0)))
	_ok(int(artist.disposition_values.get(11, 0)) == 3, "artist -> recipient == +3 (got %d)" % int(artist.disposition_values.get(11, 0)))
	# The artist-less tattoo left the lone bushi untouched.
	_ok(lone.disposition_values.is_empty(), "artist_id<0 tattoo applies no bond")
	# The self-tattoo added no self-disposition entry.
	_ok(not artist.disposition_values.has(10), "self-tattoo skipped (no self-disposition)")
