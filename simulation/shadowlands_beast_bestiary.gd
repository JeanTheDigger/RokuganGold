class_name ShadowlandsBeastBestiary
## The Shadowlands Beasts catalogue (GDD s54.9). Pure simulation class (no Node).
## Faithful transcription of the LOCKED stat blocks — no invented values. Reuses
## SpiritCreatureData so every beast is combat-ready via SpiritCombatant.to_character_data().
##
## realm: every Shadowlands beast is Tainted → JIGOKU. (The Kumo originate in Chikushudo but
## "accepted the Taint willingly" and now dwell in the Shadowlands, so they too are JIGOKU with
## a descriptive `chikushudo_origin` tag.) All carry the "shadowlands" tag.
##
## Tag/field mapping (mirrors the s54.5/s54.10/s54.11/s54.12 bestiaries):
##  - "Invulnerability" / "Invulnerable" (only jade/crystal/obsidian/magic can wound) → wired
##    `partial_invuln` (Goblin King, Onibaba, Yamauba).
##  - Lava Tree "Partial Invulnerability (Fire)" (immune to fire — it IS fire) → wired
##    `flame_immune`, NOT partial_invuln.
##  - Reduction "(X against jade/crystal/obsidian[/fire/magic])" → reduction_jade/crystal/obsidian
##    = X (fire/magic have no reduction field → a descriptive tag records the extra vulnerability).
##  - Unconditional Reactions-Stage regeneration (Garegosu 4, Mountain Goblin 5, Obake 2) → the
##    `regen_wounds` field + a descriptive `regen_per_round` tag (NOT the suppressible
##    Gashadokuro-style `regeneration` tag). Conditional regens (Mamono night-only, O-umi-bozu
##    water-only) stay descriptive with regen_wounds 0 — applying them always would over-buff.
##  - Multi-attack (a Free/Simple attack paired with another) → `multi_attack` + `_with2`.
##  - Web (Dokufu, Kumo) → `ranged_entangle`.
##  - Swallow Whole / attach-and-drain (Sanshu Denki, Tsumunagi) → `swallow_damage_*`.
##  - Waterfall Crush (O-umi-bozu) → the AoE ranged fields.
##  - Every other special ability carries a descriptive (unwired) tag pending a combat-wiring
##    tranche — the established norm for the oni/undead bestiaries.
##
## Wound track: `wound_thresholds` = the numbers before each "+X" penalty step; `wounds_dead`
## = the terminal "Dead" total. Reduction 0 where the stat block lists no Reduction line.

const _R: int = Enums.SpiritRealm.JIGOKU


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Aka-name (s54.9) ---------------------------------------------------
	c["aka_name"] = _make("aka_name", "Aka-name", SpiritCreatureData.Tier.MID,
		1, 2, 1, 3, {"reflexes": 3, "agility": 3},
		4, 3, "Claws", 5, 3, 5, 2, 20, 5, [16], 32, 0,
		["shadowlands", "poison_claws"], 1)
	c["aka_name"].taint_rank = 3
	c["aka_name"].reduction_jade = 0
	c["aka_name"].reduction_crystal = 0
	c["aka_name"].reduction_obsidian = 0

	# --- Dokufu, the Mountain Spider (s54.9) --------------------------------
	c["dokufu"] = _make("dokufu", "Dokufu, the Mountain Spider", SpiritCreatureData.Tier.BOSS,
		3, 8, 3, 3, {"agility": 4, "strength": 9},
		5, 3, "Claws", 9, 4, 10, 6, 20, 30, [40, 80, 120], 160, 4,
		["shadowlands", "huge", "shapeshift_human", "vomit_offspring", "web",
			"reduction_vs_fire_jade_crystal_obsidian"])
	c["dokufu"].taint_rank = 6
	c["dokufu"].reduction_jade = 15
	c["dokufu"].reduction_crystal = 15
	c["dokufu"].reduction_obsidian = 15
	# Web: Complex 8k3 attack, ignores armour's effect on Armor TN, range 40' (8 tiles),
	# Entangle (escape Strength TN 20/Round). (s54.9)
	c["dokufu"].ranged_attack_rolled = 8
	c["dokufu"].ranged_attack_kept = 3
	c["dokufu"].ranged_entangle = true
	c["dokufu"].ranged_range_tiles = 8

	c["dokufu_spawn"] = _make("dokufu_spawn", "Dokufu Spawn", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 2, {"reflexes": 2, "agility": 3},
		3, 2, "Claws", 4, 3, 3, 2, 15, 5, [10], 20, 0,
		["shadowlands"], 1)
	c["dokufu_spawn"].taint_rank = 2

	# --- Garegosu no Bakemono (s54.9) ---------------------------------------
	c["garegosu"] = _with2(_make("garegosu", "Garegosu no Bakemono", SpiritCreatureData.Tier.HEAVY,
		1, 6, 2, 3, {"reflexes": 2, "agility": 4, "strength": 5},
		4, 2, "Tentacles", 8, 4, 5, 1, 20, 10, [36, 48], 72, 2,
		["shadowlands", "huge", "gaze_of_terror", "multi_grapple", "regen_per_round",
			"multi_attack"], 1),
		"Bite", 5, 4, 4, 4)
	c["garegosu"].taint_rank = 4
	c["garegosu"].regen_wounds = 4  # Heals 4 Wounds during the Reactions Stage of each Round (s54.9)

	# --- Goblin (Bakemono) Variants (s54.9) ---------------------------------
	c["goblin_berserker"] = _with2(_make("goblin_berserker", "Goblin Berserker", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 2, {"reflexes": 3, "agility": 3},
		4, 3, "Knife", 4, 3, 4, 2, 20, 3, [10], 20, 0,
		["shadowlands", "goblin", "berserker_rage", "multi_attack"], 2),
		"Bite", 4, 3, 2, 1)
	c["goblin_berserker"].taint_rank = 3

	c["goblin_chucker"] = _make("goblin_chucker", "Goblin Chucker", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 1, {"reflexes": 4, "agility": 2, "strength": 2},
		5, 4, "Knife", 3, 2, 4, 2, 25, 3, [9], 18, 0,
		["shadowlands", "goblin", "thrower"], 2)
	c["goblin_chucker"].taint_rank = 3

	c["goblin_shaman"] = _make("goblin_shaman", "Goblin Shaman", SpiritCreatureData.Tier.MID,
		1, 2, 2, 1, {"reflexes": 2, "perception": 2},
		3, 2, "Knife", 4, 2, 4, 2, 15, 4, [9], 18, 0,
		["shadowlands", "goblin", "spellcaster", "maho_caster"], 2)
	c["goblin_shaman"].taint_rank = 4

	c["goblin_sneak"] = _make("goblin_sneak", "Goblin Sneak", SpiritCreatureData.Tier.SWARM,
		1, 2, 2, 1, {"reflexes": 3, "perception": 3},
		4, 3, "Knife", 4, 2, 3, 2, 20, 3, [9], 18, 0,
		["shadowlands", "goblin", "feign_death", "stealthy"], 3)
	c["goblin_sneak"].taint_rank = 3

	c["goblin_warmonger"] = _make("goblin_warmonger", "Goblin Warmonger", SpiritCreatureData.Tier.MID,
		2, 3, 2, 2, {"reflexes": 3, "agility": 3, "strength": 3},
		6, 3, "Katana", 6, 3, 6, 2, 25, 7, [15, 30], 45, 0,
		["shadowlands", "goblin", "mob_leader", "weapon_user"], 2)
	c["goblin_warmonger"].taint_rank = 4

	c["goblin_omoni"] = _make("goblin_omoni", "Goblins of Omoni", SpiritCreatureData.Tier.MID,
		1, 3, 2, 1, {"reflexes": 3, "agility": 3, "strength": 4},
		5, 3, "Knife", 5, 3, 5, 2, 20, 4, [15], 30, 0,
		["shadowlands", "goblin", "fearless"], 2)
	c["goblin_omoni"].taint_rank = 4

	c["goblin_king"] = _make("goblin_king", "Goblin King", SpiritCreatureData.Tier.MID,
		2, 3, 2, 2, {"reflexes": 3, "agility": 3, "strength": 3},
		6, 3, "Katana", 6, 3, 6, 2, 25, 7, [15, 30], 45, 0,
		["shadowlands", "goblin", "goblin_king", "mob_leader", "partial_invuln", "weapon_user"], 2)
	c["goblin_king"].taint_rank = 4

	# --- Hanemuri (s54.9) ---------------------------------------------------
	c["hanemuri"] = _make("hanemuri", "Hanemuri", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 4, "agility": 4, "perception": 2},
		4, 4, "Bite", 4, 4, 2, 1, 25, 0, [5], 10, 0,
		["shadowlands", "swarm_attack", "aerial"], 4)
	c["hanemuri"].taint_rank = 2

	# --- Kumo (s54.9) -------------------------------------------------------
	c["kumo"] = _make("kumo", "Kumo", SpiritCreatureData.Tier.HEAVY,
		3, 3, 3, 4, {"reflexes": 4, "agility": 4, "strength": 5},
		6, 4, "Bite", 7, 4, 6, 2, 30, 5, [16, 32, 48], 64, 2,
		["shadowlands", "chikushudo_origin", "camouflage", "venom_spit", "web"])
	c["kumo"].taint_rank = 3
	# Web: Complex webbing (range 20' = 4 tiles, 6k4 attack), Entangle (escape Strength TN 20). (s54.9)
	c["kumo"].ranged_attack_rolled = 6
	c["kumo"].ranged_attack_kept = 4
	c["kumo"].ranged_entangle = true
	c["kumo"].ranged_range_tiles = 4

	# --- Mamono (s54.9) -----------------------------------------------------
	c["mamono"] = _make("mamono", "Mamono", SpiritCreatureData.Tier.HEAVY,
		4, 3, 2, 3, {"agility": 4, "strength": 4},
		5, 4, "Claw", 5, 4, 4, 4, 30, 15, [25, 40], 60, 3,
		["shadowlands", "daylight_sensitivity", "shapeshift_human", "invisibility",
			"night_resurrection", "reduction_vs_jade_crystal_obsidian_magic"])
	c["mamono"].taint_rank = 5
	c["mamono"].reduction_jade = 5
	c["mamono"].reduction_crystal = 5
	c["mamono"].reduction_obsidian = 5

	# --- Monstrous Plants (s54.9) — Shadowlands flora -----------------------
	c["fudoshi"] = _make("fudoshi", "Fudoshi (Tanglevines)", SpiritCreatureData.Tier.TERRAIN,
		0, 0, 0, 1, {"reflexes": 1, "agility": 3, "strength": 2},
		2, 2, "Vine Tentacle", 3, 3, 2, 1, 10, 15, [], 6, 0,
		["shadowlands", "terrain", "ensnare", "grappling_tentacles", "suffocation",
			"reduction_vs_jade_crystal_obsidian_magic"])
	c["fudoshi"].taint_rank = 3
	c["fudoshi"].reduction_jade = 5
	c["fudoshi"].reduction_crystal = 5
	c["fudoshi"].reduction_obsidian = 5

	c["lava_tree"] = _make("lava_tree", "Lava Tree", SpiritCreatureData.Tier.TERRAIN,
		0, 5, 0, 4, {"reflexes": 1, "agility": 3},
		2, 1, "Root Tentacle", 5, 3, 4, 2, 10, 10, [], 60, 0,
		["shadowlands", "terrain", "huge", "corrosive_sap", "leaf_senses", "flame_immune",
			"snatch_grapple"])
	c["lava_tree"].taint_rank = 5

	c["takesasu"] = _make("takesasu", "Takesasu (Stinger Plant)", SpiritCreatureData.Tier.TERRAIN,
		0, 1, 0, 1, {"reflexes": 1, "agility": 3},
		2, 1, "Poisonous vine", 4, 3, 1, 1, 5, 10, [], 5, 0,
		["shadowlands", "terrain", "acid_blast", "stinger_paralysis", "fire_vulnerable"])
	c["takesasu"].taint_rank = 5

	# --- Mountain Goblin (s54.9) --------------------------------------------
	c["mountain_goblin"] = _make("mountain_goblin", "Mountain Goblin", SpiritCreatureData.Tier.MID,
		1, 3, 2, 1, {"reflexes": 3, "agility": 3, "strength": 3},
		4, 3, "Claws", 4, 3, 4, 2, 20, 5, [10, 20], 35, 0,
		["shadowlands", "goblin", "mountain_goblin", "night_vision", "regen_per_round",
			"reattach_limb"], 2)
	c["mountain_goblin"].taint_rank = 3
	c["mountain_goblin"].regen_wounds = 5  # Heals 5 Wounds/Round, continuing until killed (s54.9)

	# --- Nikumizu (Heart Grubs) (s54.9) -------------------------------------
	c["nikumizu"] = _make("nikumizu", "Nikumizu (Heart Grub)", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 3},
		3, 3, "Burrowing", 1, 1, 1, 1, 20, 0, [], 4, 0,
		["shadowlands", "tiny", "burrowing"])
	c["nikumizu"].taint_rank = 1

	# --- Obake (s54.9) ------------------------------------------------------
	c["obake"] = _make("obake", "Obake", SpiritCreatureData.Tier.MID,
		2, 3, 4, 1, {"reflexes": 6, "strength": 3},
		6, 6, "Cane", 7, 4, 3, 2, 35, 5, [10, 30], 50, 0,
		["shadowlands", "regen_per_round", "wasp_swarm"], 3)
	c["obake"].taint_rank = 5
	c["obake"].regen_wounds = 2  # Heals 2 Wounds/Round so long as it lives (s54.9)

	# --- Ogres (s54.9) ------------------------------------------------------
	c["ogre_free"] = _make("ogre_free", "Free Ogre", SpiritCreatureData.Tier.HEAVY,
		2, 3, 3, 2, {"reflexes": 3, "stamina": 6, "strength": 6},
		4, 3, "Tetsubo", 8, 4, 9, 3, 30, 15, [20, 40, 60], 80, 2,
		["shadowlands", "ogre", "huge", "weapon_user"])
	c["ogre_free"].taint_rank = 3

	c["ogre_leader"] = _make("ogre_leader", "Free Ogre Leader", SpiritCreatureData.Tier.HEAVY,
		3, 4, 3, 4, {"stamina": 6, "strength": 6},
		6, 3, "Tetsubo", 9, 4, 9, 3, 30, 15, [30, 50, 70], 90, 3,
		["shadowlands", "ogre", "huge", "weapon_user"])
	c["ogre_leader"].taint_rank = 3

	c["ogre_overlord"] = _make("ogre_overlord", "Free Ogre Overlord", SpiritCreatureData.Tier.BOSS,
		4, 5, 4, 4, {"stamina": 6, "strength": 7},
		9, 4, "Tetsubo", 10, 6, 10, 3, 35, 25, [40, 60, 80], 100, 3,
		["shadowlands", "ogre", "huge", "weapon_user"])
	c["ogre_overlord"].taint_rank = 3

	c["ogre_mage"] = _make("ogre_mage", "Ogre Mage/Hag", SpiritCreatureData.Tier.HEAVY,
		2, 4, 4, 3, {"reflexes": 3, "stamina": 6, "strength": 6},
		6, 3, "Club", 7, 5, 9, 3, 25, 10, [20, 40, 60], 80, 2,
		["shadowlands", "ogre", "huge", "spellcaster", "elemental_caster"])
	c["ogre_mage"].taint_rank = 3

	# --- Onibaba (Demon Crone) (s54.9) --------------------------------------
	c["onibaba"] = _with2(_make("onibaba", "Onibaba, Demon Crone", SpiritCreatureData.Tier.BOSS,
		3, 3, 4, 3, {"reflexes": 4, "strength": 4},
		7, 4, "Claws", 7, 4, 4, 3, 25, 5, [15, 35, 55], 75, 3,
		["shadowlands", "named", "demon_hair", "partial_invuln", "shapeshift_human",
			"spellcaster", "maho_caster", "multi_attack"]),
		"Hair Tentacle", 7, 4, 3, 2)
	c["onibaba"].taint_rank = 4

	# --- Onikage (Demon Steed) (s54.9) --------------------------------------
	c["onikage"] = _make("onikage", "Onikage, Demon Steed", SpiritCreatureData.Tier.MID,
		0, 4, 1, 4, {"reflexes": 3, "agility": 3, "strength": 6},
		3, 3, "Clawed Hooves", 4, 3, 6, 3, 20, 10, [], 40, 0,
		["shadowlands", "undead", "huge", "mount"], 3)
	c["onikage"].taint_rank = 6

	# --- Sanshu Denki (Muck Monster) (s54.9) --------------------------------
	c["sanshu_denki"] = _make("sanshu_denki", "Sanshu Denki, Muck Monster", SpiritCreatureData.Tier.HEAVY,
		2, 3, 2, 4, {"reflexes": 4, "agility": 3},
		4, 4, "Bite", 5, 3, 7, 4, 15, 0, [30, 60], 90, 0,
		["shadowlands", "aquatic", "huge", "blind_hunter", "shock", "swallow_whole"])
	c["sanshu_denki"].taint_rank = 3
	# Swallow Whole: after a bite, hold prey (Contested Strength), then swallow — 2k1/Round
	# inside (+ suffocation after Stamina+1 Rounds). (s54.9)
	c["sanshu_denki"].swallow_damage_rolled = 2
	c["sanshu_denki"].swallow_damage_kept = 1

	# --- Swamp Goblin (s54.9) -----------------------------------------------
	c["swamp_goblin"] = _make("swamp_goblin", "Swamp Goblin", SpiritCreatureData.Tier.SWARM,
		2, 2, 1, 1, {"intelligence": 3, "perception": 2},
		3, 2, "Bite", 4, 2, 2, 1, 10, 8, [15], 30, 0,
		["shadowlands", "goblin", "swamp_goblin", "aquatic", "night_vision", "fire_vulnerable"])
	c["swamp_goblin"].taint_rank = 2

	# --- Trolls (s54.9) -----------------------------------------------------
	c["troll_common"] = _make("troll_common", "Troll, Common", SpiritCreatureData.Tier.HEAVY,
		1, 3, 3, 3, {"reflexes": 3, "stamina": 5, "strength": 5},
		5, 3, "Claws", 6, 3, 6, 3, 20, 5, [20, 40, 65], 90, 0,
		["shadowlands", "troll", "aquatic", "low_light_vision"])
	c["troll_common"].taint_rank = 5

	c["troll_sea"] = _with2(_make("troll_sea", "Troll, Sea (Umibozu)", SpiritCreatureData.Tier.HEAVY,
		2, 4, 3, 2, {"strength": 6},
		5, 3, "Claws", 5, 3, 6, 3, 15, 10, [25, 50, 75], 95, 0,
		["shadowlands", "troll", "aquatic", "low_light_vision", "shock", "multi_attack"], 3),
		"Tongue", 6, 4, 4, 4)
	c["troll_sea"].taint_rank = 5

	c["troll_giant_sea"] = _make("troll_giant_sea", "Troll, Giant Sea (O-umi-bozu)", SpiritCreatureData.Tier.BOSS,
		3, 6, 3, 6, {"agility": 5, "strength": 8},
		7, 3, "Claws", 9, 5, 10, 6, 20, 15, [40, 80, 120], 160, 4,
		["shadowlands", "troll", "aquatic", "huge", "supernatural_vision", "waterfall_crush",
			"watery_regeneration", "reduction_vs_jade_crystal_obsidian"])
	c["troll_giant_sea"].taint_rank = 6
	c["troll_giant_sea"].reduction_jade = 5
	c["troll_giant_sea"].reduction_crystal = 5
	c["troll_giant_sea"].reduction_obsidian = 5
	# Waterfall Crush: Complex torrent (range 40' = 8 tiles), 8k4 Wounds to anyone within 10'
	# (2 tiles) of the impact point. Auto-hit blast. (s54.9)
	c["troll_giant_sea"].ranged_attack_rolled = 0
	c["troll_giant_sea"].ranged_damage_rolled = 8
	c["troll_giant_sea"].ranged_damage_kept = 4
	c["troll_giant_sea"].ranged_range_tiles = 8
	c["troll_giant_sea"].ranged_aoe_radius = 2

	# --- Tsumunagi (Blood Eel) (s54.9) --------------------------------------
	c["tsumunagi"] = _make("tsumunagi", "Tsumunagi (Blood Eel)", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 2, {"reflexes": 3, "agility": 2, "strength": 4},
		4, 3, "Bite", 4, 2, 3, 1, 20, 0, [10], 20, 0,
		["shadowlands", "land_crawler", "leech", "fire_vulnerable"], 4)
	c["tsumunagi"].taint_rank = 4
	# Leech: after a hit, wraps around a limb and drains blood — 2k2 Wounds/Round automatically
	# (Contested Strength to tear free). (s54.9)
	c["tsumunagi"].swallow_damage_rolled = 2
	c["tsumunagi"].swallow_damage_kept = 2

	# --- Yamauba (Mountain Ogress) (s54.9) ----------------------------------
	c["yamauba"] = _make("yamauba", "Yamauba, Mountain Ogress", SpiritCreatureData.Tier.BOSS,
		4, 3, 3, 3, {"strength": 5},
		6, 4, "Claws", 6, 3, 6, 2, 25, 8, [20, 50], 80, 0,
		["shadowlands", "named", "partial_invuln", "shapeshift_human", "mothers_face"])
	c["yamauba"].taint_rank = 5

	return c


static func shadowlands_beast_ids() -> Array:
	return catalog().keys()


static func get_beast(id: String) -> SpiritCreatureData:
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
		tags: Array, swift: int = 0, realm: int = _R) -> SpiritCreatureData:
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
