class_name AdditionalCreaturesBestiary
## Additional creatures + Elemental Terrors (GDD s54.12). Pure simulation class (no Node).
## Faithful transcription of the LOCKED stat blocks — no invented values. Reuses
## SpiritCreatureData so all are combat-ready via SpiritCombatant.to_character_data().
##
## realm: Elemental Terrors / jinmenju / Tainted → JIGOKU; Chikushudo bird/animal spirits
## → CHIKUSHUDO; Sakkaku water spirits → SAKKAKU; mortal-world spirits & mundane animals →
## NINGEN_DO. (realm is a classification field; combat reads the stat block, not the realm.)
##
## Tag mapping (as elsewhere): oni-style "Invulnerability" (resists mundane weapons) →
## wired `partial_invuln`. "Superior Invulnerability" / "Insubstantial" (immune to physical
## attacks, only magic/jade/crystal/obsidian) → wired `superior_invuln`. Element-specific
## immunities and other powers carry descriptive (unwired) tags pending a wiring tranche.

const _J: int = Enums.SpiritRealm.JIGOKU
const _C: int = Enums.SpiritRealm.CHIKUSHUDO
const _S: int = Enums.SpiritRealm.SAKKAKU
const _N: int = Enums.SpiritRealm.NINGEN_DO


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Elemental Terrors of Air (s54.12) ----------------------------------
	c["kaze_no_oni"] = _make("kaze_no_oni", "Kaze no Oni (Greater Terror of Air)", SpiritCreatureData.Tier.BOSS,
		6, 3, 3, 2, {"agility": 4},
		8, 6, "Bite", 6, 4, 4, 2, 35, 5, [30, 60], 90, 0,
		["elemental_terror", "huge", "partial_invuln", "reduction_bypassed_jade_crystal_obsidian",
			"magic_resistance", "spell_filching"], 0, _J)

	c["yosuchi_no_oni"] = _make("yosuchi_no_oni", "Yosuchi no Oni (Lesser Terror of Air)", SpiritCreatureData.Tier.HEAVY,
		4, 1, 3, 1, {"reflexes": 6, "willpower": 3, "perception": 3},
		7, 6, "Appendage", 7, 3, 1, 1, 35, 0, [25], 50, 0,
		["elemental_terror", "insubstantial", "life_drain", "magic_resistance", "superior_invuln"], 2, _J)

	# --- Additional spirits & natural creatures (s54.12) --------------------
	c["nue"] = _make("nue", "Nue", SpiritCreatureData.Tier.MID,
		2, 2, 2, 2, {"reflexes": 5, "agility": 4, "perception": 3},
		6, 5, "Claw/Beak", 6, 4, 4, 2, 30, 3, [15], 30, 0,
		["spirit", "diving_attack"], 2, _C)

	c["tsuru"] = _make("tsuru", "Tsuru, Spirit of Chikushudo", SpiritCreatureData.Tier.MID,
		4, 2, 2, 1, {"agility": 3, "perception": 4},
		5, 4, "Sword", 7, 3, 4, 2, 25, 3, [15, 30, 45], 60, 0,
		["spirit", "shapeshifting", "duelist"], 2, _C)

	c["wyrm"] = _make("wyrm", "Wyrm", SpiritCreatureData.Tier.BOSS,
		3, 4, 1, 3, {"reflexes": 5, "agility": 4, "strength": 5},
		5, 5, "Bite", 6, 4, 7, 2, 35, 6, [32, 64], 96, 5,
		["huge", "constriction_attack"], 2, _N)

	# --- New supernatural creatures (s54.12) --------------------------------
	c["kodama"] = _make("kodama", "Kodama", SpiritCreatureData.Tier.MID,
		2, 3, 1, 3, {"agility": 2},
		2, 2, "Fist", 3, 2, 3, 2, 15, 3, [15], 30, 0,
		["spirit", "kodamas_curse", "magic_resistance", "tree_bound", "taking_cover"], 0, _C)

	c["myobu"] = _make("myobu", "Myobu", SpiritCreatureData.Tier.MID,
		2, 3, 2, 1, {"awareness": 5, "perception": 4},
		5, 3, "Bite", 4, 2, 2, 1, 20, 0, [15, 30], 45, 0,
		["spirit", "inari_curse", "shapeshifting"], 3, _C)

	c["yobuko"] = _make("yobuko", "Yobuko", SpiritCreatureData.Tier.MID,
		1, 3, 2, 2, {"reflexes": 2, "stamina": 4, "strength": 4},
		3, 2, "Fist", 4, 2, 4, 1, 15, 3, [15], 30, 0,
		["spirit", "earthquake", "reduction_bypassed_crystal", "mimicry"], 0, _C)

	# --- New Shadowlands creatures (s54.12) ---------------------------------
	c["jinmenju"] = _make("jinmenju", "Jinmenju", SpiritCreatureData.Tier.HEAVY,
		0, 5, 1, 2, {"awareness": 4, "agility": 2, "strength": 4},
		1, 1, "Bite", 4, 2, 4, 2, 5, 15, [40, 80], 120, 2,
		["immobile", "poison_stamina", "screaming_fruit", "reduction_vs_jade_crystal_obsidian"], 0, _J)

	# --- Elemental Terrors of Earth (s54.12) --------------------------------
	c["jimen_no_oni"] = _make("jimen_no_oni", "Jimen no Oni (Greater Terror of Earth)", SpiritCreatureData.Tier.BOSS,
		2, 8, 2, 3, {"reflexes": 4, "agility": 4, "strength": 6},
		6, 4, "Smashing Fist", 8, 4, 7, 3, 30, 8, [30, 60, 90], 120, 4,
		["elemental_terror", "huge", "partial_invuln", "earth_movement", "magic_resistance",
			"trembling_earth", "reduction_halved_crystal_obsidian"], 0, _J)

	c["toichi_no_kansen"] = _make("toichi_no_kansen", "Toichi no Kansen (Lesser Terror of Earth)", SpiritCreatureData.Tier.HEAVY,
		1, 5, 2, 2, {"reflexes": 3, "agility": 3, "strength": 4},
		5, 2, "Fist", 6, 3, 4, 2, 25, 4, [20, 40, 60], 80, 3,
		["elemental_terror", "huge", "bury", "earth_movement", "magic_resistance",
			"reduction_bypassed_crystal_obsidian"], 0, _J)

	# --- Legendary creatures of Earth (s54.12) ------------------------------
	c["daidarabochi"] = _make("daidarabochi", "Daidarabochi", SpiritCreatureData.Tier.BOSS,
		2, 4, 2, 2, {"reflexes": 3, "stamina": 7, "agility": 3, "strength": 6},
		4, 3, "Club", 8, 3, 8, 2, 20, 10, [30, 60], 90, 2,
		["huge"], 0, _N)

	c["hibagon"] = _make("hibagon", "Hibagon", SpiritCreatureData.Tier.MID,
		2, 3, 2, 2, {"reflexes": 4, "agility": 3, "strength": 3},
		4, 4, "Thrown Rock", 7, 4, 3, 1, 25, 0, [16, 32], 48, 0,
		["ape_man", "hates_taint", "weapon_user"], 0, _N)

	# --- New mundane animals (s54.12) ---------------------------------------
	c["cougar"] = _make("cougar", "Cougar", SpiritCreatureData.Tier.MID,
		2, 3, 1, 3, {"reflexes": 3, "agility": 3, "strength": 4},
		4, 3, "Claw", 5, 3, 4, 2, 20, 3, [12, 24, 36], 48, 1,
		["animal", "ambush"], 0, _N)

	c["komodo_dragon"] = _make("komodo_dragon", "Komodo Dragon", SpiritCreatureData.Tier.MID,
		1, 2, 1, 2, {"reflexes": 3, "stamina": 3, "agility": 4, "perception": 4},
		4, 3, "Bite", 5, 4, 3, 2, 20, 4, [24], 48, 2,
		["animal", "poison_bite", "vibration_sense"], 2, _N)

	c["mongoose"] = _make("mongoose", "Mongoose", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 4, "stamina": 2, "agility": 4, "perception": 3},
		4, 4, "Bite", 6, 4, 2, 2, 25, 0, [8], 16, 0,
		["animal", "snake_killer"], 3, _N)

	c["panda"] = _make("panda", "Panda", SpiritCreatureData.Tier.HEAVY,
		1, 6, 1, 2, {"reflexes": 2, "agility": 2, "strength": 6},
		3, 2, "Claw", 3, 2, 6, 1, 15, 9, [30, 60], 90, 0,
		["animal", "huge"], 0, _N)

	c["rhinoceros"] = _make("rhinoceros", "Rhinoceros", SpiritCreatureData.Tier.HEAVY,
		1, 5, 1, 2, {"reflexes": 3, "agility": 3, "strength": 6},
		4, 3, "Gore", 6, 3, 7, 2, 25, 6, [30, 60, 90], 120, 2,
		["animal", "huge", "furious_charge", "trample_prone"], 2, _N)

	# --- Additional supernatural creatures (s54.12) -------------------------
	c["basan"] = _make("basan", "Basan", SpiritCreatureData.Tier.MID,
		1, 1, 2, 1, {"reflexes": 3},
		3, 3, "Spur", 4, 2, 2, 1, 20, 3, [10], 20, 0,
		["spirit", "breathe_flames", "plumage_camouflage"], 3, _C)

	c["furaribi"] = _make("furaribi", "Furaribi", SpiritCreatureData.Tier.MID,
		0, 1, 1, 0, {"reflexes": 3, "agility": 3, "perception": 2},
		3, 3, "Touch", 3, 3, 0, 0, 20, 0, [], 0, 2,
		["spirit", "insubstantial", "superior_invuln", "soul_touch", "ignores_armor",
			"ward_vulnerability"], 4, _N)

	# --- Elemental Terrors of Fire (s54.12) ---------------------------------
	c["taki_bi_no_oni"] = _make("taki_bi_no_oni", "Taki-bi no Oni (Greater Terror of Fire)", SpiritCreatureData.Tier.BOSS,
		3, 4, 7, 2, {"reflexes": 4},
		6, 4, "Flaming Fist", 7, 7, 4, 1, 25, 10, [30, 60], 90, 4,
		["elemental_terror", "partial_invuln", "flame_immune", "aura_of_heat", "burning_touch",
			"ignores_armor", "flying", "gout_of_flame"], 2, _J)
	# Gout of Flame: hurl a fireball (long range), 5k4 fire to everyone within 10' (2 tiles)
	# of impact; an explosion (auto-hit, no dodge), at-will (s54.12).
	c["taki_bi_no_oni"].ranged_damage_rolled = 5
	c["taki_bi_no_oni"].ranged_damage_kept = 4
	c["taki_bi_no_oni"].ranged_range_tiles = 20
	c["taki_bi_no_oni"].ranged_fire = true
	c["taki_bi_no_oni"].ranged_aoe_radius = 2

	c["moetechi_no_oni"] = _make("moetechi_no_oni", "Moetechi no Oni (Lesser Terror of Fire)", SpiritCreatureData.Tier.HEAVY,
		2, 2, 4, 1, {"reflexes": 3},
		4, 3, "Burning Touch", 6, 4, 1, 1, 20, 6, [20, 40], 60, 3,
		["elemental_terror", "partial_invuln", "flame_immune", "burning_touch", "ignores_armor",
			"fusion", "incorporeal", "magic_resistance"], 3, _J)

	c["wanyudo"] = _make("wanyudo", "Wanyudo", SpiritCreatureData.Tier.HEAVY,
		1, 3, 3, 2, {"reflexes": 3, "agility": 4, "strength": 3},
		4, 3, "Crush", 5, 4, 5, 2, 20, 10, [30, 60], 90, 4,
		["spirit", "partial_invuln", "flame_immune", "burning_touch", "flying",
			"strength_of_the_dead", "reduction_vs_crystal_obsidian"], 2, _J)

	# --- Elemental Terrors of Void (s54.12) ---------------------------------
	c["akeru_no_oni"] = _make("akeru_no_oni", "Akeru no Oni (Greater Terror of Void)", SpiritCreatureData.Tier.BOSS,
		4, 4, 4, 4, {},
		9, 4, "Claws", 9, 4, 3, 3, 30, 6, [32, 64], 128, 5,
		["elemental_terror", "huge", "partial_invuln", "reduction_bypassed_jade_crystal_obsidian",
			"magic_resistance", "sap_the_void", "telepathy", "void_strike", "walk_through_nothing"], 0, _J)
	c["akeru_no_oni"].void_rank = 1  # default Void Rank 1, accumulates to 7 via Sap the Void (s54.12)

	c["kukanchi_no_kansen"] = _make("kukanchi_no_kansen", "Kukanchi no Kansen (Lesser Terror of Void)", SpiritCreatureData.Tier.HEAVY,
		2, 2, 2, 2, {"reflexes": 4, "agility": 3, "perception": 3},
		5, 4, "Void Leech", 4, 3, 2, 1, 25, 0, [16, 32], 48, 0,
		["elemental_terror", "insubstantial", "invisibility", "partial_invuln", "spirit",
			"telepathy", "void_leech"], 3, _J)

	# --- Children of the Last Wish (s54.12) ---------------------------------
	c["child_of_the_last_wish"] = _make("child_of_the_last_wish", "Child of the Last Wish", SpiritCreatureData.Tier.HEAVY,
		1, 2, 2, 1, {"awareness": 4, "willpower": 4, "agility": 3, "perception": 3},
		6, 4, "Sword", 6, 3, 4, 2, 25, 10, [], 100, 0,
		["spirit", "incorporeal", "superior_invuln", "spellcasting_void_r3", "void_weapon",
			"ignores_armor"], 0, _N)

	# --- Water-realm supernatural creatures (s54.12) ------------------------
	c["hinotama"] = _make("hinotama", "Hinotama", SpiritCreatureData.Tier.MID,
		2, 0, 2, 2, {"reflexes": 4, "willpower": 3, "perception": 4},
		4, 4, "Touch", 4, 2, 0, 0, 20, 0, [], 40, 3,
		["spirit", "insubstantial", "ignores_armor", "stunning_jolt", "elemental_immunities",
			"magic_resistance", "cannot_be_killed"], 4, _S)

	c["nure_onna"] = _make("nure_onna", "Nure-Onna (the Wet Woman)", SpiritCreatureData.Tier.HEAVY,
		3, 3, 2, 3, {"awareness": 4, "agility": 4, "strength": 4},
		4, 3, "Constriction Grapple", 8, 4, 4, 2, 30, 10, [24, 48], 72, 4,
		["spirit", "huge", "constricting_attack", "shapechanging"], 0, _S)

	c["yamato_no_orochi"] = _with2(_make("yamato_no_orochi", "Yamato no Orochi (the Eight-Forked Serpent)", SpiritCreatureData.Tier.BOSS,
		1, 5, 2, 6, {"reflexes": 6, "agility": 5, "strength": 9},
		8, 6, "Bite", 8, 5, 9, 4, 40, 15, [40, 80, 120], 200, 5,
		["aquatic", "huge", "multi_attack", "torso_bludgeon"], 4, _N),
		"Torso Bludgeon", 10, 6, 9, 2)

	# --- Elemental Terrors of Water (s54.12) --------------------------------
	c["mizu_no_oni"] = _make("mizu_no_oni", "Mizu no Oni (Greater Terror of Water)", SpiritCreatureData.Tier.BOSS,
		4, 3, 2, 7, {"intelligence": 3},
		6, 4, "Engulf", 8, 4, 7, 3, 25, 15, [30, 60, 90], 120, 4,
		["elemental_terror", "aquatic", "huge", "partial_invuln", "engulf", "instantaneous_movement",
			"shapeshifting", "water_immune", "water_vulnerable_fire", "reduction_vs_jade_crystal"], 0, _J)

	c["oyuchi_no_kansen"] = _make("oyuchi_no_kansen", "Oyuchi no Kansen (Lesser Terror of Water)", SpiritCreatureData.Tier.HEAVY,
		2, 2, 1, 4, {"intelligence": 2},
		3, 2, "Pseudopod", 4, 2, 4, 1, 15, 5, [16, 32], 64, 2,
		["elemental_terror", "aquatic", "aquatic_camouflage", "corpse_animation", "magic_resistance",
			"water_vulnerable_fire"], 0, _J)

	# --- Additional mundane animals: aquatic (s54.12) -----------------------
	c["den_unagi"] = _make("den_unagi", "Eel (Den Unagi)", SpiritCreatureData.Tier.SWARM,
		1, 2, 0, 2, {"reflexes": 3, "agility": 2},
		3, 3, "Bite", 3, 2, 2, 1, 15, 0, [5], 10, 0,
		["animal", "aquatic", "electrical_jolt"], 1, _N)

	c["sting_ray"] = _make("sting_ray", "Sting Ray (Kosen o Sasu)", SpiritCreatureData.Tier.SWARM,
		1, 1, 0, 1, {"agility": 2, "perception": 2},
		2, 2, "Stinger", 3, 2, 2, 1, 10, 0, [10], 20, 0,
		["animal", "aquatic", "poison_stinger"], 1, _N)

	c["blue_whale"] = _make("blue_whale", "Blue Whale (Kujira)", SpiritCreatureData.Tier.HEAVY,
		2, 7, 2, 4, {"agility": 3},
		2, 2, "Tail Smash", 6, 3, 4, 4, 20, 0, [30, 60], 90, 0,
		["animal", "aquatic", "huge", "tail_smash"], 0, _N)

	c["killer_whale"] = _make("killer_whale", "Killer Whale (Blackfish)", SpiritCreatureData.Tier.HEAVY,
		3, 4, 2, 3, {"agility": 4, "perception": 4},
		4, 3, "Bite", 6, 4, 5, 3, 25, 0, [32, 48], 64, 0,
		["animal", "aquatic", "huge"], 1, _N)

	# --- Additional mundane animals: birds (s54.12) -------------------------
	c["night_heron"] = _make("night_heron", "Night Heron", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 3, "agility": 3, "perception": 3},
		3, 3, "Beak", 3, 3, 2, 1, 20, 0, [8], 16, 0,
		["animal", "eye_strike"], 3, _N)

	c["rooster"] = _make("rooster", "Rooster", SpiritCreatureData.Tier.SWARM,
		0, 1, 1, 1, {"reflexes": 2, "willpower": 2, "agility": 2, "perception": 2},
		2, 2, "Spur", 3, 2, 1, 1, 15, 0, [5], 10, 0,
		["animal"], 1, _N)

	return c


static func creature_ids() -> Array:
	return catalog().keys()


static func get_creature(id: String) -> SpiritCreatureData:
	return catalog().get(id, null)


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
		tags: Array, swift: int = 0, realm: int = _N) -> SpiritCreatureData:
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
	s.swift = swift
	var tg: Array[String] = []
	for t in tags:
		tg.append(String(t))
	s.tags = tg
	return s
