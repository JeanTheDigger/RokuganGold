class_name NaturalCreatureBestiary
## The Natural Creatures catalogue (GDD s54.1). Pure simulation class (no Node). Faithful
## transcription of the LOCKED stat blocks — no invented values. Reuses SpiritCreatureData so
## every animal is combat-ready via SpiritCombatant.to_character_data() and spawnable by id
## through SpiritCombatant.spawn_by_id (for s57.38 hunts, mission fauna, encounters).
##
## realm: every natural animal is a mundane mortal creature → NINGEN_DO. All carry the "animal"
## + "natural" tags. (realm is a classification field; combat reads the stat block, not the realm.)
##
## RELATION TO animal_combatant.gd (s57.39): the trained-companion adapter transcribes SIX of these
## same s54.1 blocks under UPPERCASE species keys (DOG/WAR_DOG/FALCON/RIDING_HORSE=Rokugani Pony/
## WARHORSE=Unicorn Riding Horse/WARCAT=Lion) for the companion contract, keyed by SPECIES enum and
## NOT part of find_creature's catalog. This bestiary is the standalone WILD-FAUNA spawn roster
## (lowercase ids, in find_creature). The two catalogs are disjoint in keys and consumers — no id
## collision — so the six shared blocks are faithfully re-transcribed here for the wild-spawn path.
##
## ID de-confliction (checked against the cross-bestiary find_creature catalog): the natural Crane
## uses id `crane` (not `tsuru` — that id is the Chikushudo crane SPIRIT in AdditionalCreaturesBestiary)
## and the natural Fox uses id `fox` (not `kitsune` — the fox SPIRIT in SpiritBestiary).
##
## Tag/field mapping (mirrors the s54.5/s54.6/s54.9/s54.10/s54.11/s54.12 bestiaries):
##  - A creature with two listed attacks (e.g. Claws + Bite) → primary attack + `multi_attack` + `_with2`.
##  - Grapple-and-drain "hold + Xk X each Turn" (Crocodile Tenacious Jaws, Constrictor Squeeze) →
##    `swallow_damage_*` (the wired grapple-crush drain), plus a descriptive tag.
##  - Swift value: for fliers/gliders the "Swift N when flying/gliding" value is stored in `swift`
##    with a `flying`/`glider` tag (the animal_combatant convention for Falcon).
##  - Every bespoke ability carries a descriptive (unwired) tag pending its combat-layer consumer:
##    Scent, Charge, Eye Attack, Furious Charge, Disembowel/Goring Charge, Echolocation/Disease
##    Carrier, Cat Scratch Fever/Low-light Vision, Blood Frenzy/nose Vulnerability, Poison Bite/
##    Color Change, Venom trait-drain, Rut, Headbutt, damage-cannot-explode (Flying Squirrel), etc.
##  - The Hare has NO attack (it flees) → attack/damage 0 + a `no_attack` tag.
##
## Wound track: `wound_thresholds` = the numbers before each "+X" penalty step; `wounds_dead`
## = the terminal "Dead" total. Reduction 0 where the stat block lists "None" / no Reduction line.

const _N: int = Enums.SpiritRealm.NINGEN_DO


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Dog (Inu) ----------------------------------------------------------
	c["dog"] = _make("dog", "Dog (Inu)", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 1, {"reflexes": 3, "agility": 3, "perception": 3},
		4, 3, "Bite", 3, 3, 2, 1, 20, 0, [12], 24, 0,
		["animal", "natural", "scent"], 2)

	# --- Dog, Unicorn War Dog -----------------------------------------------
	c["war_dog"] = _make("war_dog", "Unicorn War Dog", SpiritCreatureData.Tier.MID,
		2, 3, 2, 3, {"reflexes": 4, "agility": 4},
		5, 4, "Bite", 5, 4, 3, 2, 25, 3, [18], 36, 0,
		["animal", "natural", "scent", "charge"], 2)

	# --- Falcon -------------------------------------------------------------
	c["falcon"] = _make("falcon", "Falcon", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 4, "agility": 4, "perception": 3},
		5, 5, "Claw/Beak", 5, 4, 3, 2, 30, 0, [5], 10, 0,
		["animal", "natural", "flying", "eye_attack"], 5)

	# --- Horse, Rokugani Pony -----------------------------------------------
	c["rokugani_pony"] = _make("rokugani_pony", "Rokugani Pony", SpiritCreatureData.Tier.MID,
		2, 2, 1, 2, {"stamina": 4, "agility": 2, "strength": 4},
		3, 2, "Kick", 3, 2, 4, 2, 15, 3, [16, 32], 48, 0,
		["animal", "natural", "huge"], 3)

	# --- Horse, Unicorn Riding Horse ----------------------------------------
	c["unicorn_riding_horse"] = _make("unicorn_riding_horse", "Unicorn Riding Horse", SpiritCreatureData.Tier.MID,
		2, 3, 1, 2, {"stamina": 4, "agility": 3, "strength": 5},
		4, 2, "Kick", 4, 3, 5, 2, 15, 3, [12, 24, 36], 48, 0,
		["animal", "natural", "huge"], 3)

	# --- Horse, Utaku Battle Steed ------------------------------------------
	# Kick 4k3 (Simple) primary + Trample 6k4 (Complex); Fear 2 when charging.
	c["utaku_battle_steed"] = _with2(_make("utaku_battle_steed", "Utaku Battle Steed", SpiritCreatureData.Tier.HEAVY,
		2, 4, 2, 3, {"reflexes": 3, "stamina": 4, "agility": 3, "strength": 6},
		4, 3, "Kick", 4, 3, 6, 2, 20, 5, [16, 32, 48], 64, 2,
		["animal", "natural", "huge", "trample", "multi_attack"], 3),
		"Trample", 6, 4, 6, 4)

	# --- Lion ---------------------------------------------------------------
	# Claws 5k3 (Simple) primary + Bite 6k3 (Complex).
	c["lion"] = _with2(_make("lion", "Lion", SpiritCreatureData.Tier.HEAVY,
		2, 4, 1, 2, {"reflexes": 3, "stamina": 4, "agility": 3, "strength": 6},
		4, 3, "Claws", 5, 3, 4, 3, 20, 3, [12, 24, 36], 48, 1,
		["animal", "natural", "multi_attack"]),
		"Bite", 6, 3, 4, 4)

	# --- Ox -----------------------------------------------------------------
	# Gore 3k2 (Complex) primary + Trample 4k3 (Complex); Furious Charge.
	c["ox"] = _with2(_make("ox", "Ox", SpiritCreatureData.Tier.HEAVY,
		2, 2, 1, 2, {"reflexes": 3, "stamina": 6, "agility": 2, "strength": 6},
		2, 2, "Gore", 3, 2, 6, 3, 10, 4, [20, 40], 60, 0,
		["animal", "natural", "huge", "furious_charge", "multi_attack"]),
		"Trample", 4, 3, 6, 4)

	# --- Wolf (Ookami) ------------------------------------------------------
	c["wolf"] = _make("wolf", "Wolf (Ookami)", SpiritCreatureData.Tier.MID,
		1, 3, 2, 3, {"reflexes": 3, "agility": 3, "perception": 4},
		4, 3, "Bite", 4, 3, 5, 2, 20, 3, [18], 36, 0,
		["animal", "natural", "scent"], 2)

	# --- Ape (Ozaru) --------------------------------------------------------
	# Smash 5k4 (Simple) primary + Bite 4k4 (Complex).
	c["ape"] = _with2(_make("ape", "Ape (Ozaru)", SpiritCreatureData.Tier.HEAVY,
		1, 2, 2, 1, {"reflexes": 3, "stamina": 4, "agility": 4, "strength": 5},
		4, 3, "Smash", 5, 4, 5, 2, 20, 4, [10, 20, 30], 40, 1,
		["animal", "natural", "multi_attack"]),
		"Bite", 4, 4, 3, 3)

	# --- Badger (Anaguma) ---------------------------------------------------
	# Claws 3k2 (Simple) primary + Bite 2k2 (Complex).
	c["badger"] = _with2(_make("badger", "Badger (Anaguma)", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 2, "stamina": 2, "agility": 3, "strength": 2},
		2, 2, "Claws", 3, 2, 1, 1, 10, 0, [12], 20, 0,
		["animal", "natural", "multi_attack"]),
		"Bite", 2, 2, 2, 2)

	# --- Bat (Koumori) ------------------------------------------------------
	c["bat"] = _make("bat", "Bat (Koumori)", SpiritCreatureData.Tier.SWARM,
		2, 1, 1, 1, {"reflexes": 3, "agility": 3, "perception": 3},
		3, 3, "Bite", 3, 3, 1, 1, 20, 0, [5], 10, 0,
		["animal", "natural", "flying", "echolocation", "disease_carrier"], 3)

	# --- Bear (Kuma) --------------------------------------------------------
	# Claws 6k4 (Simple) primary + Bite 5k4 (Complex).
	c["bear"] = _with2(_make("bear", "Bear (Kuma)", SpiritCreatureData.Tier.HEAVY,
		1, 6, 1, 2, {"reflexes": 3, "agility": 4, "strength": 7},
		4, 3, "Claws", 6, 4, 7, 3, 20, 9, [30, 60], 90, 2,
		["animal", "natural", "huge", "multi_attack"], 3),
		"Bite", 5, 4, 4, 3)

	# --- Boar (Inoshishi) ---------------------------------------------------
	# Disembowel (grapple-with-tusks, 4k4/round while controlling) → swallow_damage.
	c["boar"] = _make("boar", "Boar (Inoshishi)", SpiritCreatureData.Tier.HEAVY,
		1, 5, 1, 2, {"reflexes": 3, "agility": 3, "strength": 4},
		4, 3, "Tusks", 5, 3, 5, 2, 20, 12, [30], 75, 0,
		["animal", "natural", "huge", "disembowel", "goring_charge"])
	c["boar"].swallow_damage_rolled = 4
	c["boar"].swallow_damage_kept = 4

	# --- Cat (Neko) ---------------------------------------------------------
	# Bite 4k3 (Complex) primary + Claw 3k3 (Complex).
	c["cat"] = _with2(_make("cat", "Cat (Neko)", SpiritCreatureData.Tier.SWARM,
		2, 1, 1, 1, {"reflexes": 4, "agility": 3, "perception": 4},
		4, 4, "Bite", 4, 3, 1, 1, 25, 0, [5, 10], 15, 0,
		["animal", "natural", "disease_carrier", "low_light_vision", "multi_attack"]),
		"Claw", 3, 3, 1, 1)

	# --- Crane (Tsuru) — id `crane` (tsuru = the Chikushudo spirit) ----------
	c["crane"] = _make("crane", "Crane (Tsuru)", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 4, "agility": 3, "perception": 2},
		4, 4, "Beak", 3, 3, 2, 1, 25, 0, [6], 12, 0,
		["animal", "natural", "flying"], 4)

	# --- Crocodile (Wani) ---------------------------------------------------
	# Bite 5k4; Tenacious Jaws (Contested Str hold + 2k2/Turn) → swallow_damage.
	c["crocodile"] = _make("crocodile", "Crocodile (Wani)", SpiritCreatureData.Tier.HEAVY,
		1, 3, 2, 2, {"reflexes": 3, "stamina": 4, "agility": 4, "strength": 4},
		4, 3, "Bite", 5, 4, 4, 4, 20, 5, [24, 36], 64, 2,
		["animal", "natural", "aquatic", "tenacious_jaws"])
	c["crocodile"].swallow_damage_rolled = 2
	c["crocodile"].swallow_damage_kept = 2

	# --- Eagle (Washi) ------------------------------------------------------
	c["eagle"] = _make("eagle", "Eagle (Washi)", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 2, {"reflexes": 5, "agility": 4, "perception": 4},
		5, 5, "Beak/Talons", 5, 4, 2, 2, 30, 0, [7], 15, 0,
		["animal", "natural", "flying"], 3)

	# --- Elephant (Zo) ------------------------------------------------------
	# Tusks 4k3 (Complex) primary + Stamp 5k4 (Complex); Charge.
	c["elephant"] = _with2(_make("elephant", "Elephant (Zo)", SpiritCreatureData.Tier.BOSS,
		1, 4, 2, 2, {"reflexes": 3, "stamina": 6, "agility": 3, "strength": 7},
		4, 3, "Tusks", 4, 3, 7, 2, 20, 7, [20, 40, 60, 80], 100, 2,
		["animal", "natural", "huge", "charge", "multi_attack"]),
		"Stamp", 5, 4, 4, 4)

	# --- Flying Squirrel (Musasabi) — damage cannot explode -----------------
	c["flying_squirrel"] = _make("flying_squirrel", "Flying Squirrel (Musasabi)", SpiritCreatureData.Tier.SWARM,
		2, 1, 1, 1, {"reflexes": 4, "agility": 2, "perception": 2},
		4, 4, "Teeth", 3, 2, 1, 1, 25, 0, [6], 12, 0,
		["animal", "natural", "glider", "damage_no_explode"], 2)

	# --- Fox (Kitsune) — id `fox` (kitsune = the fox spirit) ----------------
	c["fox"] = _make("fox", "Fox (Kitsune)", SpiritCreatureData.Tier.SWARM,
		2, 1, 1, 1, {"reflexes": 4, "stamina": 2, "agility": 3, "perception": 3},
		5, 4, "Bite", 4, 3, 2, 2, 25, 3, [12], 24, 0,
		["animal", "natural"], 2)

	# --- Goat (Kamoshika) ---------------------------------------------------
	c["goat"] = _make("goat", "Goat (Kamoshika)", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 1, {"reflexes": 2, "agility": 3, "strength": 2},
		2, 2, "Horns", 4, 3, 3, 2, 15, 4, [16], 32, 0,
		["animal", "natural", "headbutt"], 2)

	# --- Hare (Usagi) — NO attack (flees) -----------------------------------
	c["hare"] = _make("hare", "Hare (Usagi)", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {"reflexes": 4, "perception": 3},
		4, 4, "", 0, 0, 0, 0, 20, 0, [5], 10, 0,
		["animal", "natural", "no_attack"], 3)

	# --- Monkey (Saru) ------------------------------------------------------
	c["monkey"] = _make("monkey", "Monkey (Saru)", SpiritCreatureData.Tier.SWARM,
		2, 1, 2, 1, {"reflexes": 4, "stamina": 2, "agility": 3, "strength": 3},
		5, 4, "Bite", 3, 3, 3, 1, 25, 0, [8, 16], 24, 0,
		["animal", "natural"], 2)

	# --- Octopus / Squid (Tako) — id `octopus` ------------------------------
	# Tentacles 5k4 (Simple) primary + Beak 4k4 (Complex); Reduction 5 (squid).
	c["octopus"] = _with2(_make("octopus", "Octopus / Squid (Tako)", SpiritCreatureData.Tier.HEAVY,
		2, 2, 2, 2, {"reflexes": 3, "stamina": 4, "agility": 3, "strength": 4},
		4, 3, "Tentacles", 5, 4, 4, 4, 20, 5, [16, 32], 48, 0,
		["animal", "natural", "aquatic", "color_change", "dazing_venom", "multi_attack"]),
		"Beak", 4, 4, 2, 2)

	# --- Shark, Aoizame -----------------------------------------------------
	c["aoizame_shark"] = _make("aoizame_shark", "Shark (Aoizame)", SpiritCreatureData.Tier.MID,
		1, 1, 1, 2, {"reflexes": 4, "stamina": 2, "agility": 3},
		4, 4, "Bite", 4, 3, 4, 2, 30, 3, [12], 24, 0,
		["animal", "natural", "aquatic", "blood_frenzy", "nose_vulnerability"], 4)

	# --- Shark, Hohojirozame ------------------------------------------------
	c["hohojirozame_shark"] = _make("hohojirozame_shark", "Shark (Hohojirozame)", SpiritCreatureData.Tier.HEAVY,
		1, 2, 1, 3, {"reflexes": 4, "stamina": 3, "agility": 4, "strength": 4},
		4, 4, "Bite", 5, 4, 7, 3, 25, 5, [18], 36, 2,
		["animal", "natural", "aquatic", "huge", "blood_frenzy", "nose_vulnerability"], 4)

	# --- Snake (Hebi), Constrictor — id `constrictor_snake` -----------------
	# Bite 3k3 (Complex) primary + Grapple 7k3 (Complex); Squeeze suffocation → swallow_damage.
	c["constrictor_snake"] = _with2(_make("constrictor_snake", "Constrictor Snake (Hebi)", SpiritCreatureData.Tier.HEAVY,
		1, 3, 1, 2, {"reflexes": 3, "stamina": 4, "agility": 3, "strength": 4},
		3, 3, "Bite", 3, 3, 1, 1, 20, 3, [16, 32], 48, 0,
		["animal", "natural", "squeeze", "multi_attack"]),
		"Grapple", 7, 3, 4, 1)
	c["constrictor_snake"].swallow_damage_rolled = 2
	c["constrictor_snake"].swallow_damage_kept = 2

	# --- Snake (Hebi), Poisonous Asp — id `asp_snake` -----------------------
	c["asp_snake"] = _make("asp_snake", "Poisonous Asp (Hebi)", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 1, {"reflexes": 3, "agility": 3, "perception": 2},
		3, 3, "Bite", 3, 3, 1, 1, 20, 0, [6], 12, 0,
		["animal", "natural", "venom_trait_drain"])

	# --- Stag (Shika) -------------------------------------------------------
	c["stag"] = _make("stag", "Stag (Shika)", SpiritCreatureData.Tier.MID,
		2, 1, 1, 2, {"reflexes": 5, "stamina": 3, "agility": 3, "strength": 4},
		5, 5, "Gore", 3, 3, 4, 2, 30, 3, [12, 24], 36, 0,
		["animal", "natural", "rut"], 3)

	# --- Tiger (Tora) -------------------------------------------------------
	# Claws 6k4 (Complex) primary + Bite 4k4 (Complex).
	c["tiger"] = _with2(_make("tiger", "Tiger (Tora)", SpiritCreatureData.Tier.HEAVY,
		2, 3, 2, 3, {"reflexes": 4, "stamina": 4, "agility": 4, "strength": 4},
		5, 4, "Claws", 6, 4, 5, 2, 25, 4, [24], 48, 2,
		["animal", "natural", "multi_attack"], 1),
		"Bite", 4, 4, 3, 3)

	return c


## All s54.1 natural-creature ids (sorted).
static func natural_creature_ids() -> Array:
	var ids: Array = catalog().keys()
	ids.sort()
	return ids


## Fresh instance of one natural creature by id (null if absent).
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
