class_name OniBestiary
## Oni of the Shadowlands catalogue (GDD s54.5). Pure simulation class (no Node).
## Stats are a faithful transcription of the LOCKED oni stat blocks — no invented
## values. Reuses SpiritCreatureData (realm = JIGOKU, the Realm of Evil) so oni are
## combat-ready via SpiritCombatant.to_character_data() like the spirit-realm roster.
##
## DATA TRANCHE (2026-06-17): the stat blocks + ability tags. Combat WIRING reuses the
## SpiritAbilitySystem tag layer where the meaning matches exactly — oni "Invulnerability"
## → partial_invuln (mundane weapons do nothing; jade/crystal/magic work); "Superior
## Invulnerability" → superior_invuln + flame_immune; Fear/Swift via the dedicated fields.
## Oni-specific abilities (Plague Bearer, Swallow Whole, Burning Blood, soul/spawn powers,
## etc.) carry DESCRIPTIVE tags only and are NOT yet wired — element-nuanced immunities and
## differing regen rates deliberately avoid the generic wired tags so the combat layer never
## mis-applies them. Multi-attack oni store their primary (representative) attack; the second
## attack is a combat-layer refinement (same single-attack limitation as the spirit roster).

const _R: int = Enums.SpiritRealm.JIGOKU


## Builds and returns the full oni catalogue keyed by id (fresh instances each call —
## Resources are mutable, and spawning oni stamp variants/spawn).
static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Core oni (alphabetical, s54.5) -------------------------------------
	c["akaru_no_oni"] = _with2(_make("akaru_no_oni", "Akaru no Oni, the Web Lord", SpiritCreatureData.Tier.HEAVY,
		3, 4, 1, 4, {"agility": 4},
		4, 3, "Claws", 6, 4, 4, 4, 20, 5, [25, 50], 75, 0,
		["oni", "spinnerets", "web_traps", "entangle", "multi_attack"]), "Bite", 4, 4, 6, 4)
	# Spinnerets: Complex web attack 6k4, no damage, target Entangled (escape Strength TN 20).
	c["akaru_no_oni"].ranged_attack_rolled = 6  # 6k4 to-hit (s54.5)
	c["akaru_no_oni"].ranged_attack_kept = 4
	c["akaru_no_oni"].ranged_entangle = true
	c["akaru_no_oni"].ranged_range_tiles = 6  # PROVISIONAL (Spinnerets range unspecified)

	c["arugai_no_oni"] = _with2(_make("arugai_no_oni", "Arugai no Oni, Immortal Engine of Destruction", SpiritCreatureData.Tier.BOSS,
		4, 7, 2, 6, {"stamina": 8, "agility": 5, "strength": 8},
		9, 4, "Claws", 10, 5, 10, 4, 25, 20, [50, 100, 150], 200, 5,
		["oni", "huge", "superior_invuln", "flame_immune", "regen_per_round", "heart_kill",
			"tail_knockdown", "multi_attack"], 2), "Tail", 10, 5, 10, 3)
	c["arugai_no_oni"].regen_wounds = 10  # Nearly Immortal: regenerates 10 Wounds/Round (s54.5)

	c["byoki_no_oni"] = _make("byoki_no_oni", "Byoki no Oni, Harbinger of Pestilence", SpiritCreatureData.Tier.HEAVY,
		2, 5, 2, 3, {"agility": 3},
		3, 2, "Claws", 4, 2, 3, 3, 15, 2, [30, 60], 90, 2,
		["oni", "plague_bearer", "splatter"])

	c["daku_no_oni"] = _make("daku_no_oni", "Daku no Oni, Scourge of the Forest", SpiritCreatureData.Tier.HEAVY,
		3, 4, 3, 3, {"agility": 4, "strength": 5},
		6, 3, "Claws", 6, 4, 5, 2, 25, 8, [32, 48], 72, 2,
		["oni", "eyeless", "flaming_bark", "flaming_regeneration", "wreathed_in_flames",
			"fire_resist_mundane"])
	c["daku_no_oni"].ranged_attack_name = "Flaming Bark"  # 6k3 to-hit, DR 3k2, 30 ft (s54.5)
	c["daku_no_oni"].ranged_attack_rolled = 6
	c["daku_no_oni"].ranged_attack_kept = 3
	c["daku_no_oni"].ranged_damage_rolled = 3
	c["daku_no_oni"].ranged_damage_kept = 2
	c["daku_no_oni"].ranged_range_tiles = 6
	c["daku_no_oni"].ranged_fire = true

	c["furu_no_oni"] = _make("furu_no_oni", "Furu no Oni, Serpent of Flames", SpiritCreatureData.Tier.BOSS,
		6, 8, 8, 6, {"awareness": 7, "intelligence": 9, "strength": 8},
		10, 8, "Tentacles", 10, 10, 10, 5, 40, 25, [80, 160, 240], 320, 5,
		["oni", "unique", "burning_blood", "create_spawn_naga", "extreme_heat", "fiery_impalement",
			"flame_sight", "hurl_flaming_blood", "many_tentacles", "pearl_vulnerability",
			"superior_invuln", "flame_immune"], 4)
	c["furu_no_oni"].burning_blood_rolled = 5  # 5k5 splatter, save TN 40 (s54.5)
	c["furu_no_oni"].burning_blood_kept = 5
	c["furu_no_oni"].burning_blood_tn = 40
	c["furu_no_oni"].ranged_attack_name = "Hurl Flaming Blood"  # 10k9 to-hit, 4k4 fire, 30 ft (s54.5)
	c["furu_no_oni"].ranged_attack_rolled = 10
	c["furu_no_oni"].ranged_attack_kept = 9
	c["furu_no_oni"].ranged_damage_rolled = 4
	c["furu_no_oni"].ranged_damage_kept = 4
	c["furu_no_oni"].ranged_range_tiles = 6
	c["furu_no_oni"].ranged_fire = true

	c["furu_no_oni_spawn"] = _make("furu_no_oni_spawn", "Furu no Oni Spawn", SpiritCreatureData.Tier.HEAVY,
		4, 4, 6, 4, {"strength": 5},
		8, 5, "Tentacles", 8, 6, 6, 3, 30, 10, [24, 48, 72], 96, 3,
		["oni", "burning_blood", "fiery_impalement", "hurl_flaming_blood", "many_tentacles",
			"pearl_vulnerability", "flame_immune"], 2)
	c["furu_no_oni_spawn"].burning_blood_rolled = 2  # 2k2 splatter, save TN 25 (s54.5)
	c["furu_no_oni_spawn"].burning_blood_kept = 2
	c["furu_no_oni_spawn"].burning_blood_tn = 25

	c["gagoze_no_oni"] = _make("gagoze_no_oni", "Gagoze no Oni, Plague of the Forest", SpiritCreatureData.Tier.BOSS,
		3, 4, 5, 4, {"reflexes": 4},
		4, 4, "Claws", 5, 5, 4, 4, 25, 5, [25, 50, 75, 125], 150, 3,
		["oni", "huge", "partial_invuln", "spell_mastery_r3", "taint_affliction"])

	c["genso_no_oni"] = _with2(_make("genso_no_oni", "Genso no Oni, Dark Warrior", SpiritCreatureData.Tier.BOSS,
		3, 4, 4, 4, {"reflexes": 5},
		5, 5, "Obsidian Katana", 9, 4, 7, 2, 30, 4, [40, 80, 120, 160, 200], 240, 3,
		["oni", "obsidian_daisho", "no_disarm", "taunts", "multi_attack"]), "Talons", 8, 4, 4, 4)

	c["ianwa_no_oni"] = _make("ianwa_no_oni", "Ianwa no Oni, Dark Bargainer", SpiritCreatureData.Tier.HEAVY,
		3, 3, 2, 3, {"awareness": 5, "intelligence": 6, "perception": 6},
		3, 3, "Claw", 2, 2, 3, 3, 20, 3, [12, 24, 36], 48, 5,
		["oni", "dark_demands", "fear_enhancement", "partial_invuln", "teleport", "coward"])

	c["kamu_no_oni"] = _with2(_make("kamu_no_oni", "Kamu no Oni, the Killing Maw", SpiritCreatureData.Tier.BOSS,
		2, 5, 2, 3, {"reflexes": 3, "agility": 4, "strength": 6},
		3, 3, "Claw", 7, 4, 6, 3, 25, 5, [50, 75, 100, 125], 150, 4,
		["oni", "devour", "partial_invuln", "multi_attack"]), "Bite", 4, 4, 7, 5)
	c["kamu_no_oni"].swallow_damage_rolled = 7  # Devour: swallowed victim suffers bite damage (s54.5)
	c["kamu_no_oni"].swallow_damage_kept = 5

	c["kommei_no_oni"] = _make("kommei_no_oni", "Kommei no Oni, Demon of Confusion", SpiritCreatureData.Tier.BOSS,
		5, 5, 3, 3, {"awareness": 6, "strength": 4},
		7, 4, "Claws", 7, 3, 6, 3, 25, 10, [20, 40, 60], 80, 3,
		["oni", "all_around_vision", "double_jointed", "shapeshifting_soul", "spirit_leeching",
			"spirit_trading"])

	c["manesuru_no_oni"] = _make("manesuru_no_oni", "Manesuru no Oni, the Dark Mirror", SpiritCreatureData.Tier.HEAVY,
		1, 4, 3, 4, {"awareness": 4, "intelligence": 4, "perception": 5},
		4, 1, "Pseudopod", 4, 3, 4, 1, 10, 8, [12, 24, 36], 48, 0,
		["oni", "malleable_form", "magic_resistance", "spawn_dark_mirror", "uncanny_insight",
			"ambush"])

	c["morei_no_oni"] = _make("morei_no_oni", "Morei no Oni, the Grain Demon", SpiritCreatureData.Tier.MID,
		2, 2, 1, 1, {"strength": 2},
		3, 2, "Claws", 3, 2, 3, 1, 15, 10, [12, 24], 36, 0,
		["oni", "immobile", "seed_spawn"])

	c["muduro_no_oni"] = _with2(_make("muduro_no_oni", "Muduro no Oni, the Corrupted Mountain", SpiritCreatureData.Tier.BOSS,
		3, 7, 2, 4, {"agility": 3, "strength": 8},
		6, 3, "Claws", 7, 3, 10, 3, 15, 20, [100, 150], 200, 4,
		["oni", "huge", "partial_invuln", "swallow_whole", "multi_attack"]), "Bite", 8, 3, 10, 5)
	c["muduro_no_oni"].swallow_damage_rolled = 3  # Swallow Whole 3k3 + 1 Taint/round (s54.5)
	c["muduro_no_oni"].swallow_damage_kept = 3
	c["muduro_no_oni"].swallow_taint = true

	c["nairu_no_oni"] = _make("nairu_no_oni", "Nairu no Oni, Scourge of the Skies", SpiritCreatureData.Tier.HEAVY,
		3, 2, 2, 2, {"agility": 4, "strength": 4},
		4, 3, "Talons", 6, 4, 4, 4, 20, 4, [20, 40, 60], 80, 2,
		["oni", "diving_attack", "partial_invuln", "flying"], 3)  # Swift 3 when flying

	c["nosloc_no_oni"] = _make("nosloc_no_oni", "Nosloc no Oni, Vassals of the Demon Lords", SpiritCreatureData.Tier.HEAVY,
		2, 4, 3, 4, {"reflexes": 3, "agility": 4},
		5, 3, "Heavy Weapon", 7, 4, 8, 2, 20, 5, [16, 24, 32, 48], 80, 2,
		["oni", "battlefield_acumen", "partial_invuln", "weapon_user", "intelligent"])

	c["pekkle_no_oni"] = _make("pekkle_no_oni", "Pekkle no Oni, the Pretender", SpiritCreatureData.Tier.HEAVY,
		5, 3, 2, 2, {"willpower": 6, "intelligence": 5, "perception": 5},
		5, 5, "Claws", 4, 2, 4, 3, 30, 0, [20, 30, 40, 65], 80, 0,
		["oni", "hidden_darkness", "retributive_taint", "blackened_claws", "shapeshifting_human"])

	c["quiet_death"] = _make("quiet_death", "Quiet Death", SpiritCreatureData.Tier.MID,
		1, 2, 1, 4, {"reflexes": 3, "stamina": 5, "agility": 4},
		3, 3, "Touch", 4, 4, 4, 1, 20, 10, [30, 60], 120, 0,
		["oni", "amorphous", "suffocation", "fire_susceptible", "reduction_vs_cutting"])

	c["ryokaku_no_oni"] = _with2(_make("ryokaku_no_oni", "Ryokaku no Oni, the Demon of Purity", SpiritCreatureData.Tier.BOSS,
		4, 4, 4, 4, {},
		8, 4, "Katana", 9, 4, 7, 2, 25, 8, [16, 32, 48], 72, 3,
		["oni", "duel_bound", "insidious_beauty", "partial_invuln", "black_fog_of_purity",
			"reduction_vs_crystal", "multi_attack"]), "Claws", 7, 4, 4, 2)

	c["shikage_no_oni"] = _with2(_make("shikage_no_oni", "Shikage no Oni, Many-Armed Death", SpiritCreatureData.Tier.BOSS,
		4, 4, 4, 4, {"willpower": 5, "agility": 5, "perception": 6},
		8, 4, "Claws", 7, 5, 5, 3, 30, 8, [24, 48, 72], 96, 3,
		["oni", "demon_silk", "entangle", "partial_invuln", "mind_breaking_poison",
			"paralyzing_poison", "poison_constitution", "wall_climbing", "multi_attack"]), "Tongue-Stinger", 8, 5, 4, 2)

	# --- Shokansuru's Brood (s54.5) -----------------------------------------
	c["hasaiki_no_oni"] = _with2(_make("hasaiki_no_oni", "Hasaiki no Oni, the Burning Sea", SpiritCreatureData.Tier.BOSS,
		3, 6, 2, 3, {"agility": 3, "strength": 6},
		3, 3, "Stomp", 7, 3, 8, 6, 20, 5, [32, 48, 64, 100], 200, 3,
		["oni", "huge", "partial_invuln", "brood", "mortal", "leaping", "regen_per_round",
			"acid_vomit", "multi_attack"]), "Bite", 7, 7, 6, 6)
	c["hasaiki_no_oni"].regen_wounds = 5  # Regeneration: heals 5 Wounds/Round until dead (s54.5)

	c["munemitsu_no_oni"] = _with2(_make("munemitsu_no_oni", "Munemitsu no Oni, the Earth Breaker", SpiritCreatureData.Tier.BOSS,
		2, 7, 1, 5, {"reflexes": 4, "agility": 4, "strength": 8},
		4, 2, "Trample", 4, 4, 6, 4, 25, 6, [32, 64, 96, 128, 160], 224, 3,
		["oni", "huge", "partial_invuln", "brood", "mortal", "gore", "trample_prone", "multi_attack"]), "Gore", 6, 4, 8, 6)

	c["sentei_no_oni"] = _with2(_make("sentei_no_oni", "Sentei no Oni, the Many-Legged Death", SpiritCreatureData.Tier.BOSS,
		2, 6, 4, 4, {"reflexes": 4},
		6, 4, "Talons", 4, 4, 4, 4, 25, 5, [30, 60, 120], 180, 4,
		["oni", "huge", "partial_invuln", "brood", "mortal", "superior_regeneration", "multi_attack"]), "Bite", 6, 4, 5, 5)

	c["yojireju_no_oni"] = _make("yojireju_no_oni", "Yojireju no Oni, the Soul Drinker", SpiritCreatureData.Tier.BOSS,
		3, 3, 3, 3, {"reflexes": 5, "agility": 5},
		4, 3, "Claws", 6, 5, 5, 3, 30, 5, [20, 40, 60, 80], 100, 3,
		["oni", "partial_invuln", "brood", "mortal", "corpse_absorption", "soul_absorption"])

	# --- Further oni (s54.5) ------------------------------------------------
	c["sodatsu_no_oni"] = _make("sodatsu_no_oni", "Sodatsu no Oni, Shugenja's Bane", SpiritCreatureData.Tier.BOSS,
		4, 6, 4, 4, {"reflexes": 5, "strength": 6},
		8, 4, "Pseudopods", 8, 4, 6, 4, 25, 15, [40, 80], 120, 5,
		["oni", "huge", "malleable", "shugenjas_bane"])

	c["tasu_no_oni"] = _make("tasu_no_oni", "Tasu no Oni, Plague of Flesh", SpiritCreatureData.Tier.HEAVY,
		1, 3, 1, 3, {"reflexes": 3, "agility": 4},
		3, 3, "Leg", 4, 4, 3, 2, 20, 5, [20, 40], 60, 3,
		["oni", "spawn_on_death"])
	c["tasu_no_oni"].death_spawn_id = "tasu_spawn"  # releases spawn on death (s54.5; count capped)
	c["tasu_no_oni"].death_spawn_count = 2

	# Tasu newborn (s54.5): foot-long, all Rings 1, ATN 15, 12 wounds, little defense.
	c["tasu_spawn"] = _make("tasu_spawn", "Tasu Spawn", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {},
		1, 1, "Bite", 1, 1, 1, 1, 15, 0, [], 12, 0,
		["oni", "newborn", "scatter"])

	c["utogu_no_oni"] = _with2(_make("utogu_no_oni", "Utogu no Oni, the Endless Hunger", SpiritCreatureData.Tier.BOSS,
		2, 5, 1, 5, {"agility": 4},
		3, 2, "Trample", 4, 4, 5, 3, 20, 8, [60, 90], 120, 3,
		["oni", "huge", "partial_invuln", "charge", "devour", "trample_prone", "multi_attack"]), "Bite", 6, 4, 5, 5)
	c["utogu_no_oni"].swallow_damage_rolled = 5  # Devour 5k5/round (s54.5)
	c["utogu_no_oni"].swallow_damage_kept = 5

	c["uzaki_no_oni"] = _with2(_make("uzaki_no_oni", "Uzaki no Oni, the Demon Commander", SpiritCreatureData.Tier.BOSS,
		5, 5, 5, 5, {"awareness": 6, "intelligence": 6, "perception": 6},
		9, 5, "Obsidian Katana", 10, 5, 9, 3, 30, 8, [16, 32, 48], 72, 3,
		["oni", "huge", "partial_invuln", "flaming_weapon", "commanders_voice", "eternal_enmity",
			"leader_of_oni", "tactician", "multi_attack"]), "Claws", 9, 5, 6, 2)

	c["wakeru_no_oni"] = _make("wakeru_no_oni", "Wakeru no Oni, the Endless Horde", SpiritCreatureData.Tier.HEAVY,
		2, 5, 2, 2, {"reflexes": 5, "agility": 5, "strength": 5},
		8, 5, "Claws", 6, 5, 6, 2, 20, 5, [], 50, 2,
		["oni", "endless_horde", "heedless_rage"])
	c["wakeru_no_oni"].death_spawn_id = "wakeru_lesser"  # splits into two lesser copies on death (s54.5)
	c["wakeru_no_oni"].death_spawn_count = 2

	# Wakeru lesser copy (s54.5): physical traits -1, Wounds -5, Armor TN +5, attack/damage
	# -1k1. No further death_spawn_id — the split is modelled as one generation.
	c["wakeru_lesser"] = _make("wakeru_lesser", "Wakeru no Oni (Lesser)", SpiritCreatureData.Tier.MID,
		2, 5, 2, 2, {"reflexes": 4, "agility": 4, "strength": 4},
		7, 4, "Claws", 5, 4, 5, 1, 25, 5, [], 45, 2,
		["oni", "endless_horde", "heedless_rage", "lesser"])

	c["wanizame_no_oni"] = _make("wanizame_no_oni", "Wanizame no Oni, the Finned Maw", SpiritCreatureData.Tier.HEAVY,
		2, 2, 1, 4, {"reflexes": 4, "agility": 4},
		4, 4, "Bite", 6, 4, 4, 4, 25, 3, [15, 30, 45], 60, 2,
		["oni", "aquatic", "blood_scent", "feeding_frenzy"])

	# --- Oni Lord Spawn (s54.5) ---------------------------------------------
	c["akuma_no_oni_spawn"] = _make("akuma_no_oni_spawn", "Akuma no Oni Spawn", SpiritCreatureData.Tier.BOSS,
		5, 5, 4, 5, {"intelligence": 5},
		9, 5, "Claws", 8, 4, 7, 3, 40, 10, [25, 50, 75], 100, 4,
		["oni", "huge", "partial_invuln", "oni_lord_spawn", "burning_saliva", "multiple_tongues"])

	c["kyoso_no_oni_spawn"] = _make("kyoso_no_oni_spawn", "Kyoso no Oni Spawn", SpiritCreatureData.Tier.BOSS,
		4, 4, 4, 4, {"reflexes": 5, "strength": 5},
		9, 5, "Claws", 5, 4, 4, 3, 35, 10, [16, 32, 48], 72, 3,
		["oni", "partial_invuln", "oni_lord_spawn", "black_fire", "feed_upon_soul",
			"magical_talent_r3", "multiple_arms"])

	c["shikibu_no_oni_spawn"] = _make("shikibu_no_oni_spawn", "Shikibu no Oni Spawn", SpiritCreatureData.Tier.HEAVY,
		4, 3, 4, 3, {"willpower": 5},
		7, 4, "Claws", 6, 4, 5, 2, 25, 5, [12, 24, 36], 48, 2,
		["oni", "oni_lord_spawn", "corpse_inhabitation", "preserve_corpse"], 2)

	c["tsuburu_no_oni_spawn"] = _make("tsuburu_no_oni_spawn", "Tsuburu no Oni Spawn", SpiritCreatureData.Tier.BOSS,
		1, 1, 3, 1, {"stamina": 7, "strength": 7},
		4, 1, "Grab", 8, 3, 7, 2, 15, 15, [40, 80, 120], 160, 5,
		["oni", "huge", "partial_invuln", "oni_lord_spawn", "swallow_whole", "teleport"])
	c["tsuburu_no_oni_spawn"].swallow_damage_rolled = 2  # Swallow Whole 2k2 + 1 Taint/round (s54.5)
	c["tsuburu_no_oni_spawn"].swallow_damage_kept = 2
	c["tsuburu_no_oni_spawn"].swallow_taint = true

	c["yuhmi_no_oni"] = _with2(_make("yuhmi_no_oni", "Yuhmi no Oni, Flesh of the Dark Lord", SpiritCreatureData.Tier.BOSS,
		2, 4, 2, 3, {"reflexes": 4, "agility": 4, "strength": 6},
		4, 3, "Claw", 6, 4, 6, 2, 25, 5, [40, 80, 120], 160, 4,
		["oni", "huge", "partial_invuln", "unique", "mai_chong", "singular_spawn", "multi_attack"]), "Mai Chong", 8, 4, 6, 3)

	return c


## All oni ids in the catalogue.
static func oni_ids() -> Array:
	return catalog().keys()


## Fresh single oni by id, or null if unknown.
static func get_oni(id: String) -> SpiritCreatureData:
	var c: Dictionary = catalog()
	return c.get(id, null)


## Attaches a second attack profile to a multi-attack creature (GDD s54.5: oni with two
## attacks, e.g. Claws + Bite). Returns the same instance for chaining.
static func _with2(s: SpiritCreatureData, name: String, ar: int, ak: int, dr: int, dk: int) -> SpiritCreatureData:
	s.attack2_name = name
	s.attack2_rolled = ar
	s.attack2_kept = ak
	s.damage2_rolled = dr
	s.damage2_kept = dk
	return s


static func _make(
		id: String, name: String, tier: int,
		air: int, earth: int, fire: int, water: int, traits: Dictionary,
		init_r: int, init_k: int,
		atk_name: String, atk_r: int, atk_k: int, dmg_r: int, dmg_k: int,
		atn: int, reduction: int, thresholds: Array, dead: int, fear: int,
		tags: Array, swift: int = 0) -> SpiritCreatureData:
	var s := SpiritCreatureData.new()
	s.id = id
	s.display_name = name
	s.realm = _R
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
	s.swift = swift
	var tg: Array[String] = []
	for t in tags:
		tg.append(String(t))
	s.tags = tg
	return s
