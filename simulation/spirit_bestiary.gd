class_name SpiritBestiary
## Spirit-realm creature catalogue for the s56.16 Spiritual Insurgency encounters.
## Pure simulation class (no Node). Stats are a faithful transcription of the
## LOCKED bestiary (s54.10 Spirits of Gaki-do; Shozai-Gaki from s54.2) — no
## invented values. The zone pools follow the LOCKED Gaki-do Roster (s56.16.6b)
## and Encounter Flow (s56.16.6c).
##
## Scope (owner-approved 2026-06-16): roster DATA for the realms whose stat blocks
## are fully LOCKED — Gaki-do (s56.16.6b), Toshigoku (s56.16.8e), Sakkaku
## (s56.16.9c). DEFERRED: Chikushudo (s56.16.7b) — its territorial defenders are
## natural-animal bases (s54.1) with only the bear's +2-Earth overlay documented,
## so a faithful transcription needs the natural-creature stats + the overlay
## rule; and Meido / Yume-do — s56.16 gives them NO roster or encounter section
## (only the 56.16.5c restoration approach), so there is nothing to transcribe.
## Live ASCII-map creature combat (special abilities) is a later tranche.

## Builds and returns the Gaki-do creature catalogue keyed by id.
## Fresh instances each call (Resources are mutable — callers may stamp variants
## such as the Jigoku-corrupted Shozai-gaki, s56.16.6d).
static func gaki_do_catalog() -> Dictionary:
	var c: Dictionary = {}

	c["muzai_gaki"] = _make("muzai_gaki", "Muzai-gaki", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"awareness": 3},
		2, 1, "Spectral Touch", 3, 1, 1, 1, 15, 0, [], 5, 1,
		["spirit", "incorporeal", "swarm_presence", "poltergeist"])

	c["usai_gaki_swarm"] = _make("usai_gaki_swarm", "Usai-gaki Swarm", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 2, {"agility": 3},
		3, 2, "Swarm Bite", 0, 0, 2, 1, 5, 10, [], 30, 0,
		["spirit", "swarm", "area_denial", "automatic_hit", "fire_counter"])

	c["jikininki"] = _make("jikininki", "Jikininki", SpiritCreatureData.Tier.MID,
		2, 2, 2, 3, {"reflexes": 3, "agility": 3, "strength": 4},
		3, 3, "Claws", 5, 3, 4, 2, 20, 3, [8, 16, 24], 32, 2,
		["spirit", "corpse_frenzy", "pack_feeder", "night_hunter", "recognizable_dead"])

	c["haraigaki"] = _make("haraigaki", "Haraigaki", SpiritCreatureData.Tier.MID,
		3, 1, 2, 2, {"awareness": 4, "perception": 5},
		4, 3, "Wail of the Starving", 0, 0, 0, 0, 15, 0, [4, 8], 16, 3,
		["spirit", "wail", "area_denial", "stationary", "scent_of_life", "fragile"])

	c["fukuregaki"] = _make("fukuregaki", "Fukuregaki", SpiritCreatureData.Tier.MID,
		1, 3, 1, 3, {"strength": 5, "willpower": 4},
		1, 1, "Engulf", 5, 3, 3, 3, 10, 8, [12, 24, 36], 48, 2,
		["spirit", "hunger_pull", "engulf", "immobile", "difficult_terrain"])

	c["kagaki"] = _make("kagaki", "Kagaki", SpiritCreatureData.Tier.MID,
		2, 2, 3, 1, {"agility": 3, "intelligence": 1},
		3, 2, "Flame Bite", 5, 3, 3, 2, 20, 0, [8, 16, 24], 32, 1,
		["spirit", "fire_trail", "flame_immune", "water_vulnerable", "incidental"])

	c["shozai_gaki"] = _make("shozai_gaki", "Shozai-Gaki", SpiritCreatureData.Tier.HEAVY,
		2, 2, 2, 3, {"reflexes": 4, "agility": 4, "strength": 4},
		4, 4, "Claw", 4, 4, 3, 3, 25, 5, [12, 24], 36, 3,
		["spirit", "blood_drain", "invisibility", "immortality", "shapeshift",
			"superior_invuln", "possession", "ignores_armor", "jigoku_corruptible"])

	c["gashadokuro"] = _make("gashadokuro", "Gashadokuro", SpiritCreatureData.Tier.BOSS,
		2, 5, 3, 4, {"reflexes": 3, "agility": 2, "strength": 8, "willpower": 6},
		3, 3, "Crushing Fist", 8, 4, 6, 4, 15, 15,
		[25, 50, 75, 100, 125, 150, 175], 200, 0,
		["spirit", "famine_only", "night_only", "regeneration", "boss", "bone_rattle"])

	c["o_toyo"] = _make("o_toyo", "O-Toyo", SpiritCreatureData.Tier.TERRAIN,
		2, 2, 2, 3, {"awareness": 4, "agility": 4, "perception": 4},
		2, 1, "Fangs", 9, 4, 5, 3, 25, 3, [20], 40, 0,
		["spirit", "forest_only", "deceptive_visage", "life_drain"])

	c["mokumokuren"] = _make("mokumokuren", "Mokumokuren", SpiritCreatureData.Tier.TERRAIN,
		0, 1, 0, 0, {"awareness": 4, "intelligence": 1, "perception": 6},
		2, 1, "Mental Attack", 6, 4, 4, 4, 5, 0, [10], 20, 0,
		["spirit", "settlement_only", "gaze_attack", "superior_invuln", "paper_walls"])

	c["buruburu"] = _make("buruburu", "Buruburu", SpiritCreatureData.Tier.POST_ENCOUNTER,
		2, 1, 2, 1, {"awareness": 5, "willpower": 4, "intelligence": 4, "perception": 3},
		3, 2, "", 0, 0, 0, 0, 10, 10, [10], 20, 0,
		["spirit", "post_encounter", "invisible", "possession", "nightmares"])

	return c


## The zone → creature-id pool for a Gaki-do overlap (s56.16.6b/6c).
## Availability gates: Gashadokuro only in mass-famine overlaps; O-Toyo only in
## forest overlaps; Mokumokuren only in settlement overlaps. Buruburu is the
## post-encounter attachment (s56.16.6e), not a placed threat.
static func gaki_do_pool(terrain_type: int, famine: bool, settlement: bool) -> Dictionary:
	var terrain_pool: Array[String] = []
	if terrain_type == Enums.TerrainType.FOREST:
		terrain_pool.append("o_toyo")
	if settlement:
		terrain_pool.append("mokumokuren")
	return {
		"outer":   ["muzai_gaki"],
		"middle":  ["jikininki", "usai_gaki_swarm", "kagaki"],
		"heart":   ["fukuregaki", "haraigaki", "shozai_gaki"],
		"boss":    (["gashadokuro"] if famine else []),
		"terrain": terrain_pool,
		"post":    ["buruburu"],
	}


# ── Toshigoku (s56.16.8e roster, s54.10 Spirits of Toshigoku) ─────────────────

## Toshigoku (Realm of Slaughter) creature catalogue, keyed by id. All stats from
## s54.10 (full explicit blocks). Fresh instances each call.
static func toshigoku_catalog() -> Dictionary:
	var R: int = Enums.SpiritRealm.TOSHIGOKU
	var c: Dictionary = {}

	c["musha_recruit"] = _make("musha_recruit", "Musha Recruit", SpiritCreatureData.Tier.SWARM,
		2, 2, 2, 2, {"reflexes": 3, "agility": 3},
		4, 3, "Ghostly Weapon", 5, 3, 4, 2, 20, 3, [8, 16, 24], 32, 0,
		["spirit", "cannon_fodder", "retains_identity"], R)

	c["ashigaru_musha_spear"] = _make("ashigaru_musha_spear", "Ashigaru Musha (Spear)",
		SpiritCreatureData.Tier.SWARM,
		2, 2, 2, 2, {"agility": 3, "strength": 3},
		3, 2, "Ghostly Yari", 4, 2, 4, 2, 15, 2, [8, 16, 24], 32, 0,
		["spirit", "cannon_fodder", "mob_frenzy", "formation"], R)

	c["bow_ashigaru_musha"] = _make("bow_ashigaru_musha", "Bow Ashigaru Musha",
		SpiritCreatureData.Tier.SWARM,
		2, 2, 2, 2, {"perception": 3},
		3, 2, "Ghostly Yumi", 4, 2, 3, 2, 10, 0, [8, 16, 24], 32, 0,
		["spirit", "ranged", "high_ground", "range_12"], R)

	c["musha_soldier"] = _make("musha_soldier", "Musha Soldier", SpiritCreatureData.Tier.MID,
		2, 3, 3, 3, {"reflexes": 3, "agility": 3, "strength": 4},
		5, 3, "Ghostly Weapon", 6, 3, 5, 3, 25, 5, [12, 24, 36], 48, 0,
		["spirit", "standard", "simple_action"], R)

	c["musha_commander"] = _make("musha_commander", "Musha Commander", SpiritCreatureData.Tier.HEAVY,
		3, 4, 4, 3, {"reflexes": 4, "agility": 4, "strength": 5, "willpower": 5},
		6, 4, "Ghostly Weapon", 8, 4, 6, 3, 30, 8, [16, 32, 48], 64, 0,
		["spirit", "elite", "rally", "tactical", "cannot_be_flanked", "simple_action"], R)

	c["ancient_general_toshigoku"] = _make("ancient_general_toshigoku", "Ancient General",
		SpiritCreatureData.Tier.BOSS,
		4, 5, 5, 4, {"reflexes": 6, "agility": 5, "strength": 7, "willpower": 7,
			"awareness": 5, "perception": 5},
		8, 6, "Ancestral Weapon", 10, 5, 8, 4, 35, 12,
		[25, 50, 75, 100, 125, 150, 175], 200, 0,
		["spirit", "boss", "partial_invuln", "adapts", "reforms_once", "duel_offer", "simple_action"], R)

	c["phantom_battle"] = _make("phantom_battle", "Phantom Battle", SpiritCreatureData.Tier.TERRAIN,
		0, 0, 0, 0, {},
		0, 0, "", 0, 0, 2, 2, 0, 0, [], 0, 0,
		["environmental_hazard", "not_creature", "spiritual_damage", "shifts", "cannot_be_fought"], R)

	return c


## Toshigoku zone → creature-id pool (s56.16.8e/8f). No terrain/famine gating;
## the Phantom Battle hazard pervades the overlap.
static func toshigoku_pool() -> Dictionary:
	return {
		"outer":   ["musha_recruit"],
		"middle":  ["musha_soldier", "ashigaru_musha_spear", "bow_ashigaru_musha"],
		"heart":   ["musha_soldier", "musha_commander"],
		"boss":    ["ancient_general_toshigoku"],
		"terrain": ["phantom_battle"],
		"post":    [],
	}


# ── Sakkaku (s56.16.9c roster, s54.10 Spirits of Sakkaku; Kappa s54.2) ─────────

## Sakkaku (Realm of Mischief) creature catalogue, keyed by id. Real-threat
## creatures + the Mujina illusion-engine. All stats from s54.10 (Kappa from s54.2).
static func sakkaku_catalog() -> Dictionary:
	var R: int = Enums.SpiritRealm.SAKKAKU
	var c: Dictionary = {}

	c["kappa"] = _make("kappa", "Kappa", SpiritCreatureData.Tier.HEAVY,
		3, 2, 2, 3, {"intelligence": 3},
		4, 3, "Claws", 4, 2, 3, 2, 20, 15, [12, 24], 36, 0,
		["spirit", "real_threat", "aquatic", "ambush", "grapple", "water_of_life", "trickery"], R)

	c["bakeneko"] = _make("bakeneko", "Bakeneko", SpiritCreatureData.Tier.MID,
		2, 2, 2, 2, {},
		3, 2, "Claws", 3, 2, 2, 2, 10, 5, [10, 20], 30, 0,
		["spirit", "real_threat", "shapeshifter", "deceiver", "vindictive"], R)

	c["konak_jiji"] = _make("konak_jiji", "Konak Jiji", SpiritCreatureData.Tier.MID,
		1, 2, 3, 2, {"awareness": 4},
		3, 2, "Claws", 5, 3, 2, 1, 10, 3, [10, 20], 30, 0,
		["spirit", "real_threat", "lethal_trap", "deceptive_weight", "paralysis_venom", "lure"], R)

	c["mujina"] = _make("mujina", "Mujina", SpiritCreatureData.Tier.TERRAIN,
		3, 3, 3, 3, {},
		6, 3, "", 0, 0, 1, 1, 15, 0, [], 50, 0,
		["spirit", "illusion_engine", "ghostly_form", "immortal", "invisibility",
			"magic_resist", "spellcaster", "swift"], R)

	c["pekkle"] = _make("pekkle", "Pekkle", SpiritCreatureData.Tier.HEAVY,
		5, 4, 2, 1, {"awareness": 7, "willpower": 8},
		5, 5, "Claws", 4, 2, 1, 1, 15, 3, [15, 30, 45], 60, 0,
		["spirit", "time_thief", "partial_invuln_half_damage", "no_explode", "lure_child"], R)

	return c


## Sakkaku roster split (s56.16.9c): real threats vs the Mujina-created deceptions.
## The GDD organises Sakkaku by threat-reality, not by zone tier, so this pool
## follows that structure rather than inventing outer/middle/heart placement.
static func sakkaku_pool() -> Dictionary:
	return {
		"real_threats": ["kappa", "bakeneko", "konak_jiji", "pekkle"],
		"deceptions":   ["mujina"],
	}


# -- internal -----------------------------------------------------------------

static func _make(
		id: String, name: String, tier: int,
		air: int, earth: int, fire: int, water: int, traits: Dictionary,
		init_r: int, init_k: int,
		atk_name: String, atk_r: int, atk_k: int, dmg_r: int, dmg_k: int,
		atn: int, reduction: int, thresholds: Array, dead: int, fear: int,
		tags: Array, realm: int = Enums.SpiritRealm.GAKI_DO) -> SpiritCreatureData:
	var s := SpiritCreatureData.new()
	s.id = id
	s.display_name = name
	s.realm = realm
	s.tier = tier
	s.air = air
	s.earth = earth
	s.fire = fire
	s.water = water
	s.traits = traits
	s.initiative_rolled = init_r
	s.initiative_kept = init_k
	s.attack_name = atk_name
	s.attack_rolled = atk_r
	s.attack_kept = atk_k
	s.damage_rolled = dmg_r
	s.damage_kept = dmg_k
	s.armor_tn = atn
	s.reduction = reduction
	var th: Array[int] = []
	for t in thresholds:
		th.append(int(t))
	s.wound_thresholds = th
	s.wounds_dead = dead
	s.fear = fear
	var tg: Array[String] = []
	for t in tags:
		tg.append(String(t))
	s.tags = tg
	return s
