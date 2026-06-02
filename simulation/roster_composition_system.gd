class_name RosterCompositionSystem
## s56.10 Quest seed roster composition --- LOCKED.
## Pure data layer. Returns unit type specs and role assignments for ASCII map population.
## Stat blocks deferred to s54.x; mechanical effects deferred to s40.
## All ranges are GDD-locked unless annotated PROVISIONAL.

# -- Seed type constants -------------------------------------------------------
# Mirror Enums.InsurgencyType values; SEED_WALL_SORTIE has no InsurgencyType entry.
const SEED_MAHO_CULT:              int = 0   # Enums.InsurgencyType.MAHO_CULT
const SEED_PEASANT_REVOLT:         int = 1   # Enums.InsurgencyType.PEASANT_REVOLT
const SEED_RONIN_BANDIT:           int = 2   # Enums.InsurgencyType.RONIN_BANDIT
const SEED_TAINT_MANIFESTATION:    int = 3   # Enums.InsurgencyType.TAINT_MANIFESTATION
const SEED_NEZUMI_INFESTATION:     int = 4   # Enums.InsurgencyType.NEZUMI_INFESTATION
const SEED_URBAN_CRIMINAL_NETWORK: int = 5   # Enums.InsurgencyType.URBAN_CRIMINAL_NETWORK
const SEED_WALL_SORTIE:            int = 100

# -- Unit type ID strings -------------------------------------------------------
# Ronin / Bandit (s54.8)
const SIMPLE_BANDIT:      String = "SIMPLE_BANDIT"
const EXPERIENCED_BANDIT: String = "EXPERIENCED_BANDIT"
const BANDIT_LORD:        String = "BANDIT_LORD"
const BANDIT_THUG:        String = "BANDIT_THUG"
const BANDIT_RABBLE:      String = "BANDIT_RABBLE"
# Peasant Revolt (s54.8)
const REBEL_LEADER:   String = "REBEL_LEADER"
const REBEL_ASHIGARU: String = "REBEL_ASHIGARU"
const REBEL_PEASANT:  String = "REBEL_PEASANT"
# Nezumi (s54.2)
const NEZUMI_CHIEFTAIN:   String = "NEZUMI_CHIEFTAIN"
const NEZUMI_WARRIOR:     String = "NEZUMI_WARRIOR"
const NEZUMI_ARCHER:      String = "NEZUMI_ARCHER"
const NEZUMI_SCOUT:       String = "NEZUMI_SCOUT"
const NEZUMI_BROODMOTHER: String = "NEZUMI_BROODMOTHER"
# Maho Cult (s54.3)
const CULT_INITIATE:      String = "CULT_INITIATE"
const MAHO_CULTIST:       String = "MAHO_CULTIST"
const BLOODSPEAKER_ADEPT: String = "BLOODSPEAKER_ADEPT"
const ZOMBIE:             String = "ZOMBIE"
# Province Taint Manifestation (s54.1 / s54.2)
const TAINTED_ANIMAL:  String = "TAINTED_ANIMAL"
const UNDEAD_REVENANT: String = "UNDEAD_REVENANT"
const TAINTED_HUMAN:   String = "TAINTED_HUMAN"
# Crab soldiers — Wall Sortie friendly (s11.6)
const HIDA_BUSHI:        String = "HIDA_BUSHI"
const HIRUMA_SCOUT:      String = "HIRUMA_SCOUT"
const KUNI_WITCH_HUNTER: String = "KUNI_WITCH_HUNTER"
# Shadowlands — Wall Sortie enemy (s54.9)
const BAKEMONO:         String = "BAKEMONO"
const BAKEMONO_WARRIOR: String = "BAKEMONO_WARRIOR"
const BAKEMONO_ARCHER:  String = "BAKEMONO_ARCHER"
const BAKEMONO_SHAMAN:  String = "BAKEMONO_SHAMAN"
const SKELETON_WARRIOR: String = "SKELETON_WARRIOR"
const MAHO_TSUKAI:      String = "MAHO_TSUKAI"
const OGRE_WARRIOR:     String = "OGRE_WARRIOR"
const OGRE_RAVENOUS:    String = "OGRE_RAVENOUS"
const OGRE_WARLORD:     String = "OGRE_WARLORD"
const TROLL:            String = "TROLL"
const ONI_SPAWN:        String = "ONI_SPAWN"
# Urban Criminal Network (s54.8)
const RONIN_ENFORCER:   String = "RONIN_ENFORCER"
const LOOKOUT:          String = "LOOKOUT"
const CORRUPTED_DOSHIN: String = "CORRUPTED_DOSHIN"
const NETWORK_BOSS:     String = "NETWORK_BOSS"

# -- Role ID strings ------------------------------------------------------------
const ROLE_LEADER:              String = "LEADER"
const ROLE_GUARD_POST:          String = "GUARD_POST"
const ROLE_EDGE_DEFENDER:       String = "EDGE_DEFENDER"
const ROLE_RIM_WATCHER:         String = "RIM_WATCHER"
const ROLE_CAMP_GROUP:          String = "CAMP_GROUP"
const ROLE_PATROL_LEADER:       String = "PATROL_LEADER"
const ROLE_PATROL_FOLLOWER:     String = "PATROL_FOLLOWER"
const ROLE_SENTRY:              String = "SENTRY"
const ROLE_RUBBLE_LURKER:       String = "RUBBLE_LURKER"
const ROLE_CHOKEPOINT_HOLDER:   String = "CHOKEPOINT_HOLDER"
const ROLE_RITUAL_SPACE:        String = "RITUAL_SPACE"
# Province Taint behavior tags (s56.10.10g — no organized structure)
const ROLE_WANDERER:             String = "WANDERER"
const ROLE_EMERGENT_UNDEAD:      String = "EMERGENT_UNDEAD"
const ROLE_CLUSTERED_PACK:       String = "CLUSTERED_PACK"
const ROLE_FOCAL_POINT_GUARDIAN: String = "FOCAL_POINT_GUARDIAN"
# Urban Criminal
const ROLE_LOOKOUT_POSITION: String = "LOOKOUT_POSITION"
const ROLE_ESCAPE_GUARD:     String = "ESCAPE_GUARD"

# -- Sortie size IDs -----------------------------------------------------------
const SORTIE_SMALL:  String = "SMALL"
const SORTIE_MEDIUM: String = "MEDIUM"
const SORTIE_LARGE:  String = "LARGE"

# -- Maho Cult establishment path IDs -----------------------------------------
const MAHO_PATH_WHISPERING_CELL:   String = "AGENT_INFILTRATION"
const MAHO_PATH_BLOODSPEAKER:      String = "PTL_CORRUPTION"
const MAHO_PATH_FALLEN_PILLAR_NPC: String = "NAMED_NPC_FALL"
const MAHO_PATH_FALLEN_PILLAR_ART: String = "ARTIFACT_DISCOVERY"

# -- Individual variance (s56.10.0a) ------------------------------------------
const INDIVIDUAL_VARIANCE_CHANCE_MIN: float = 0.30
const INDIVIDUAL_VARIANCE_CHANCE_MAX: float = 0.40

# -- Ronin Bandit (s56.10.1b-c) -----------------------------------------------
const BANDIT_STABILITY_RESTLESS_MIN: int = 51   # 51-100
const BANDIT_STABILITY_VOLATILE_MIN: int = 26   # 26-50; below = Broken (0-25)
const BANDIT_HEADCOUNT_RESTLESS: Array = [3, 4]  # per Strength point
const BANDIT_HEADCOUNT_VOLATILE: Array = [4, 5]
const BANDIT_HEADCOUNT_BROKEN:   Array = [5, 6]
const BANDIT_RONIN_PCT_RESTLESS: Array = [60, 70]
const BANDIT_THUG_PCT_RESTLESS:  Array = [15, 25]
const BANDIT_RONIN_PCT_VOLATILE: Array = [25, 35]
const BANDIT_THUG_PCT_VOLATILE:  Array = [20, 30]
const BANDIT_RONIN_PCT_BROKEN:   Array = [15, 20]
const BANDIT_THUG_PCT_BROKEN:    Array = [15, 25]

# -- Peasant Revolt (s56.10.4b-c) ---------------------------------------------
const PEASANT_HEADCOUNT_PER_STR: Array = [5, 6]
const PEASANT_PCT_MIN:   int = 70
const PEASANT_PCT_MAX:   int = 80
const ASHIGARU_PCT_MIN:  int = 15
const ASHIGARU_PCT_MAX:  int = 25

# -- Nezumi Infestation (s56.10.6b) -------------------------------------------
const NEZUMI_HEADCOUNT_PER_STR:   Array = [4, 5]
const NEZUMI_WARRIOR_PCT_MIN:     int = 50
const NEZUMI_WARRIOR_PCT_MAX:     int = 60
const NEZUMI_ARCHER_PCT_MIN:      int = 15
const NEZUMI_ARCHER_PCT_MAX:      int = 20
const NEZUMI_SCOUT_PCT_MIN:       int = 10
const NEZUMI_SCOUT_PCT_MAX:       int = 15
const NEZUMI_BROODMOTHER_PCT_MIN: int = 5
const NEZUMI_BROODMOTHER_PCT_MAX: int = 10

# -- Maho Cult (s56.10.8a-d) --------------------------------------------------
const MAHO_LIVING_PER_STR:          Array = [1, 2]
const MAHO_ZOMBIE_CAP:              int   = 10
const MAHO_ZOMBIE_RATE_NORMAL:      int   = 1   # per season active
const MAHO_ZOMBIE_RATE_HIGH_CORPSE: int   = 2   # famine or battle province
const MAHO_WC_INITIATE_PCT_MIN: int = 50   # Whispering Cell
const MAHO_WC_INITIATE_PCT_MAX: int = 60
const MAHO_WC_CULTIST_PCT_MIN:  int = 30
const MAHO_WC_CULTIST_PCT_MAX:  int = 40
const MAHO_BP_INITIATE_PCT_MIN: int = 30   # Bloodspeaker Proper
const MAHO_BP_INITIATE_PCT_MAX: int = 40
const MAHO_BP_CULTIST_PCT_MIN:  int = 30
const MAHO_BP_CULTIST_PCT_MAX:  int = 40
const MAHO_BP_ADEPT_PCT_MIN:    int = 10
const MAHO_BP_ADEPT_PCT_MAX:    int = 20
const MAHO_FP_INITIATE_PCT_MIN: int = 40   # Fallen Pillar (of followers, not counting leader)
const MAHO_FP_INITIATE_PCT_MAX: int = 50
const MAHO_FP_CULTIST_PCT_MIN:  int = 30
const MAHO_FP_CULTIST_PCT_MAX:  int = 40

# -- Province Taint Manifestation (s56.10.10f) --------------------------------
const PTL_CORRUPTED_MIN: float = 6.0
const PTL_BLIGHTED_MIN:  float = 9.0
const TAINT_HEADCOUNT_TOUCHED:   Array = [3, 5]
const TAINT_HEADCOUNT_CORRUPTED: Array = [4, 6]
const TAINT_HEADCOUNT_BLIGHTED:  Array = [5, 8]
# Creature mix % — PROVISIONAL (GDD s56.10.10f gives qualitative descriptions, not exact %s)
const TAINT_TOUCHED_ANIMAL_PCT_MIN:   int = 60
const TAINT_TOUCHED_ANIMAL_PCT_MAX:   int = 70
const TAINT_TOUCHED_UNDEAD_PCT_MIN:   int = 25
const TAINT_TOUCHED_UNDEAD_PCT_MAX:   int = 35
const TAINT_CORRUPTED_ANIMAL_PCT_MIN: int = 30
const TAINT_CORRUPTED_ANIMAL_PCT_MAX: int = 40
const TAINT_CORRUPTED_UNDEAD_PCT_MIN: int = 40
const TAINT_CORRUPTED_UNDEAD_PCT_MAX: int = 50
const TAINT_BLIGHTED_ANIMAL_PCT_MIN:  int = 10
const TAINT_BLIGHTED_ANIMAL_PCT_MAX:  int = 20
const TAINT_BLIGHTED_UNDEAD_PCT_MIN:  int = 40
const TAINT_BLIGHTED_UNDEAD_PCT_MAX:  int = 50

# -- Wall Sortie (s56.10.11) — all values PROVISIONAL pending playtest --------
const SORTIE_FRIENDLY_SMALL:  Array = [4,  6]
const SORTIE_FRIENDLY_MEDIUM: Array = [8,  12]
const SORTIE_FRIENDLY_LARGE:  Array = [12, 18]
const SORTIE_ENEMY_SMALL:  Array = [8,  12]
const SORTIE_ENEMY_MEDIUM: Array = [15, 20]
const SORTIE_ENEMY_LARGE:  Array = [25, 35]

# -- Urban Criminal Network (s56.10.15) ---------------------------------------
const CRIMINAL_STR_TIER1_MAX:   int = 2
const CRIMINAL_STR_TIER2_MAX:   int = 4
const CRIMINAL_STR_TIER3_MAX:   int = 6
const CRIMINAL_HEADCOUNT_TIER1: Array = [3,  6]
const CRIMINAL_HEADCOUNT_TIER2: Array = [8,  12]
const CRIMINAL_HEADCOUNT_TIER3: Array = [14, 20]
const CRIMINAL_HEADCOUNT_TIER4: Array = [20, 30]

# -- Public API ----------------------------------------------------------------

## Returns roster spec dict for the given quest seed type.
## options keys by seed:
##   RONIN_BANDIT:    "stability" int (0-100; default 75 = Restless)
##   MAHO_CULT:       "establishment_path" String, "seasons_active" int, "high_corpse_availability" bool
##   TAINT_MANIFEST:  "ptl" float
##   WALL_SORTIE:     "sortie_size" String (SORTIE_SMALL / MEDIUM / LARGE)
## seed drives deterministic RNG.
static func compose_roster(seed_type: int, strength: int, options: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed_type) + "_" + str(strength) + "_" + str(seed))
	match seed_type:
		SEED_RONIN_BANDIT:
			return _compose_ronin_bandit(strength, options.get("stability", 75), rng)
		SEED_PEASANT_REVOLT:
			return _compose_peasant_revolt(strength, rng)
		SEED_NEZUMI_INFESTATION:
			return _compose_nezumi(strength, rng)
		SEED_MAHO_CULT:
			return _compose_maho_cult(
				strength,
				options.get("establishment_path", MAHO_PATH_BLOODSPEAKER),
				options.get("seasons_active", 1),
				options.get("high_corpse_availability", false),
				rng
			)
		SEED_TAINT_MANIFESTATION:
			return _compose_taint_manifestation(strength, options.get("ptl", 3.0), rng)
		SEED_URBAN_CRIMINAL_NETWORK:
			return _compose_urban_criminal(strength, rng)
		SEED_WALL_SORTIE:
			return _compose_wall_sortie(options.get("sortie_size", SORTIE_SMALL), rng)
		_:
			return _compose_ronin_bandit(strength, 75, rng)

# -- Tiny helpers --------------------------------------------------------------

static func _rng_range(rng: RandomNumberGenerator, lo: int, hi: int) -> int:
	if lo >= hi:
		return lo
	return rng.randi_range(lo, hi)

static func _variance_chance(rng: RandomNumberGenerator) -> float:
	return INDIVIDUAL_VARIANCE_CHANCE_MIN + rng.randf() * (INDIVIDUAL_VARIANCE_CHANCE_MAX - INDIVIDUAL_VARIANCE_CHANCE_MIN)

static func _group(unit_type: String, count: int, role: String) -> Dictionary:
	return {"unit_type": unit_type, "count": count, "role": role}

# -- Ronin Bandit (s56.10.1) --------------------------------------------------

static func _compose_ronin_bandit(strength: int, stability: int, rng: RandomNumberGenerator) -> Dictionary:
	var headcount_range: Array
	var ronin_range: Array
	var thug_range: Array
	if stability >= BANDIT_STABILITY_RESTLESS_MIN:
		headcount_range = BANDIT_HEADCOUNT_RESTLESS
		ronin_range     = BANDIT_RONIN_PCT_RESTLESS
		thug_range      = BANDIT_THUG_PCT_RESTLESS
	elif stability >= BANDIT_STABILITY_VOLATILE_MIN:
		headcount_range = BANDIT_HEADCOUNT_VOLATILE
		ronin_range     = BANDIT_RONIN_PCT_VOLATILE
		thug_range      = BANDIT_THUG_PCT_VOLATILE
	else:
		headcount_range = BANDIT_HEADCOUNT_BROKEN
		ronin_range     = BANDIT_RONIN_PCT_BROKEN
		thug_range      = BANDIT_THUG_PCT_BROKEN

	var per_str: int = _rng_range(rng, headcount_range[0], headcount_range[1])
	var total: int   = maxi(1, strength * per_str)

	var ronin_pct: int = _rng_range(rng, ronin_range[0], ronin_range[1])
	var thug_pct:  int = _rng_range(rng, thug_range[0], thug_range[1])
	if ronin_pct + thug_pct > 100:
		thug_pct = 100 - ronin_pct

	var ronin_count:  int = maxi(1, int(total * ronin_pct / 100.0))
	var thug_count:   int = maxi(0, int(total * thug_pct  / 100.0))
	var rabble_count: int = maxi(0, total - ronin_count - thug_count)

	var leader_type: String
	var guard_type: String
	if strength >= 5:
		leader_type = BANDIT_LORD
		guard_type  = EXPERIENCED_BANDIT
	elif strength >= 3:
		leader_type = EXPERIENCED_BANDIT
		guard_type  = SIMPLE_BANDIT
	else:
		leader_type = SIMPLE_BANDIT
		guard_type  = SIMPLE_BANDIT

	var guard_count: int    = maxi(0, ronin_count - 1)
	var patrol_count: int   = mini(thug_count, rabble_count)
	var extra_rabble: int   = maxi(0, rabble_count - patrol_count)
	var extra_thugs:  int   = maxi(0, thug_count  - patrol_count)

	var groups: Array = []
	groups.append(_group(leader_type, 1, ROLE_LEADER))
	if guard_count > 0:
		groups.append(_group(guard_type, guard_count, ROLE_GUARD_POST))
	if patrol_count > 0:
		groups.append(_group(BANDIT_THUG,   patrol_count, ROLE_PATROL_LEADER))
		groups.append(_group(BANDIT_RABBLE, patrol_count, ROLE_PATROL_FOLLOWER))
	if extra_thugs > 0:
		groups.append(_group(BANDIT_THUG, extra_thugs, ROLE_GUARD_POST))
	if extra_rabble > 0:
		groups.append(_group(BANDIT_RABBLE, extra_rabble, ROLE_SENTRY))

	return {
		"seed_type": SEED_RONIN_BANDIT,
		"total_count": total,
		"groups": groups,
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": false,
	}

# -- Peasant Revolt (s56.10.4) ------------------------------------------------

static func _compose_peasant_revolt(strength: int, rng: RandomNumberGenerator) -> Dictionary:
	var per_str: int = _rng_range(rng, PEASANT_HEADCOUNT_PER_STR[0], PEASANT_HEADCOUNT_PER_STR[1])
	var total: int   = maxi(1, strength * per_str)

	# Ashigaru guard adjacent to the leader — threshold per s56.10.4c.
	var guard_ashigaru: int
	if strength >= 8:
		guard_ashigaru = 2
	elif strength >= 5:
		guard_ashigaru = 1
	else:
		guard_ashigaru = 0

	var remaining: int = maxi(0, total - 1 - guard_ashigaru)
	var ashigaru_pct: int = _rng_range(rng, ASHIGARU_PCT_MIN, ASHIGARU_PCT_MAX)
	var rank_ashigaru: int = maxi(0, int(remaining * ashigaru_pct / 100.0))
	var peasant_count: int = maxi(0, remaining - rank_ashigaru)

	var groups: Array = []
	groups.append(_group(REBEL_LEADER, 1, ROLE_LEADER))
	if guard_ashigaru > 0:
		groups.append(_group(REBEL_ASHIGARU, guard_ashigaru, ROLE_GUARD_POST))
	if rank_ashigaru > 0:
		groups.append(_group(REBEL_ASHIGARU, rank_ashigaru, ROLE_CHOKEPOINT_HOLDER))
	if peasant_count > 0:
		groups.append(_group(REBEL_PEASANT, peasant_count, ROLE_CAMP_GROUP))

	return {
		"seed_type": SEED_PEASANT_REVOLT,
		"total_count": total,
		"groups": groups,
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": false,
	}

# -- Nezumi Infestation (s56.10.6) --------------------------------------------

static func _compose_nezumi(strength: int, rng: RandomNumberGenerator) -> Dictionary:
	var per_str: int = _rng_range(rng, NEZUMI_HEADCOUNT_PER_STR[0], NEZUMI_HEADCOUNT_PER_STR[1])
	var total: int   = maxi(1, strength * per_str)
	var remaining: int = maxi(0, total - 1)

	var warrior_pct:    int = _rng_range(rng, NEZUMI_WARRIOR_PCT_MIN,    NEZUMI_WARRIOR_PCT_MAX)
	var archer_pct:     int = _rng_range(rng, NEZUMI_ARCHER_PCT_MIN,     NEZUMI_ARCHER_PCT_MAX)
	var scout_pct:      int = _rng_range(rng, NEZUMI_SCOUT_PCT_MIN,      NEZUMI_SCOUT_PCT_MAX)
	var brood_pct:      int = _rng_range(rng, NEZUMI_BROODMOTHER_PCT_MIN, NEZUMI_BROODMOTHER_PCT_MAX)
	var pct_sum: int = warrior_pct + archer_pct + scout_pct + brood_pct
	if pct_sum > 100:
		var scale: float = 100.0 / pct_sum
		warrior_pct = int(warrior_pct * scale)
		archer_pct  = int(archer_pct  * scale)
		scout_pct   = int(scout_pct   * scale)
		brood_pct   = int(brood_pct   * scale)

	var warrior_count: int = maxi(0, int(remaining * warrior_pct / 100.0))
	var archer_count:  int = maxi(0, int(remaining * archer_pct  / 100.0))
	var scout_count:   int = maxi(0, int(remaining * scout_pct   / 100.0))
	var brood_count:   int = maxi(0, int(remaining * brood_pct   / 100.0))
	var assigned: int = warrior_count + archer_count + scout_count + brood_count
	if assigned < remaining:
		warrior_count += remaining - assigned

	var groups: Array = []
	groups.append(_group(NEZUMI_CHIEFTAIN, 1, ROLE_LEADER))
	if warrior_count > 0:
		groups.append(_group(NEZUMI_WARRIOR,     warrior_count, ROLE_GUARD_POST))
	if archer_count > 0:
		groups.append(_group(NEZUMI_ARCHER,      archer_count,  ROLE_EDGE_DEFENDER))
	if scout_count > 0:
		groups.append(_group(NEZUMI_SCOUT,       scout_count,   ROLE_SENTRY))
	if brood_count > 0:
		groups.append(_group(NEZUMI_BROODMOTHER, brood_count,   ROLE_RIM_WATCHER))

	return {
		"seed_type": SEED_NEZUMI_INFESTATION,
		"total_count": total,
		"groups": groups,
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": false,
	}

# -- Maho Cult (s56.10.8) -----------------------------------------------------

static func _compose_maho_cult(strength: int, path: String, seasons_active: int, high_corpse: bool, rng: RandomNumberGenerator) -> Dictionary:
	var living_per_str: int = _rng_range(rng, MAHO_LIVING_PER_STR[0], MAHO_LIVING_PER_STR[1])
	var living_total: int   = maxi(1, strength * living_per_str)

	var rate: int = MAHO_ZOMBIE_RATE_HIGH_CORPSE if high_corpse else MAHO_ZOMBIE_RATE_NORMAL
	var zombie_count: int = mini(MAHO_ZOMBIE_CAP, seasons_active * rate)

	var is_fallen_pillar: bool = (path == MAHO_PATH_FALLEN_PILLAR_NPC or path == MAHO_PATH_FALLEN_PILLAR_ART)
	var is_bloodspeaker:  bool = (path == MAHO_PATH_BLOODSPEAKER)

	var groups: Array = []
	var has_named_npc_slot: bool = false

	if is_fallen_pillar:
		has_named_npc_slot = true
		groups.append(_group(BLOODSPEAKER_ADEPT, 1, ROLE_LEADER))
		var followers: int     = maxi(0, living_total - 1)
		var init_pct: int      = _rng_range(rng, MAHO_FP_INITIATE_PCT_MIN, MAHO_FP_INITIATE_PCT_MAX)
		var cult_pct: int      = _rng_range(rng, MAHO_FP_CULTIST_PCT_MIN,  MAHO_FP_CULTIST_PCT_MAX)
		if init_pct + cult_pct > 100:
			cult_pct = 100 - init_pct
		var init_count: int = maxi(0, int(followers * init_pct / 100.0))
		var cult_count: int = maxi(0, followers - init_count)
		if init_count > 0:
			groups.append(_group(CULT_INITIATE, init_count, ROLE_CAMP_GROUP))
		if cult_count > 0:
			groups.append(_group(MAHO_CULTIST,  cult_count, ROLE_RITUAL_SPACE))

	elif is_bloodspeaker:
		var adept_pct: int   = _rng_range(rng, MAHO_BP_ADEPT_PCT_MIN,    MAHO_BP_ADEPT_PCT_MAX)
		var adept_total: int = maxi(0, int(living_total * adept_pct / 100.0))
		has_named_npc_slot   = adept_total >= 1
		if adept_total > 0:
			groups.append(_group(BLOODSPEAKER_ADEPT, 1, ROLE_LEADER))
			adept_total -= 1
		else:
			groups.append(_group(MAHO_CULTIST, 1, ROLE_LEADER))
		var remaining: int = maxi(0, living_total - 1 - adept_total)
		if adept_total > 0:
			groups.append(_group(BLOODSPEAKER_ADEPT, adept_total, ROLE_CHOKEPOINT_HOLDER))
		var init_pct: int  = _rng_range(rng, MAHO_BP_INITIATE_PCT_MIN, MAHO_BP_INITIATE_PCT_MAX)
		var cult_pct: int  = _rng_range(rng, MAHO_BP_CULTIST_PCT_MIN,  MAHO_BP_CULTIST_PCT_MAX)
		if init_pct + cult_pct > 100:
			cult_pct = 100 - init_pct
		var init_count: int = maxi(0, int(remaining * init_pct / 100.0))
		var cult_count: int = maxi(0, remaining - init_count)
		if init_count > 0:
			groups.append(_group(CULT_INITIATE, init_count, ROLE_CAMP_GROUP))
		if cult_count > 0:
			groups.append(_group(MAHO_CULTIST,  cult_count, ROLE_RITUAL_SPACE))

	else: # Whispering Cell (AGENT_INFILTRATION)
		groups.append(_group(MAHO_CULTIST, 1, ROLE_LEADER))
		var remaining: int = maxi(0, living_total - 1)
		var init_pct: int  = _rng_range(rng, MAHO_WC_INITIATE_PCT_MIN, MAHO_WC_INITIATE_PCT_MAX)
		var cult_pct: int  = _rng_range(rng, MAHO_WC_CULTIST_PCT_MIN,  MAHO_WC_CULTIST_PCT_MAX)
		if init_pct + cult_pct > 100:
			cult_pct = 100 - init_pct
		var init_count: int = maxi(0, int(remaining * init_pct / 100.0))
		var cult_count: int = maxi(0, remaining - init_count)
		if init_count > 0:
			groups.append(_group(CULT_INITIATE, init_count, ROLE_CAMP_GROUP))
		if cult_count > 0:
			groups.append(_group(MAHO_CULTIST,  cult_count, ROLE_RITUAL_SPACE))

	if zombie_count > 0:
		groups.append(_group(ZOMBIE, zombie_count, ROLE_GUARD_POST))

	return {
		"seed_type": SEED_MAHO_CULT,
		"total_count": living_total + zombie_count,
		"living_count": living_total,
		"zombie_count": zombie_count,
		"establishment_path": path,
		"groups": groups,
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": has_named_npc_slot,
	}

# -- Province Taint Manifestation (s56.10.10) ---------------------------------

static func _compose_taint_manifestation(strength: int, ptl: float, rng: RandomNumberGenerator) -> Dictionary:
	var headcount_range: Array
	var animal_min: int
	var animal_max: int
	var undead_min: int
	var undead_max: int
	if ptl >= PTL_BLIGHTED_MIN:
		headcount_range = TAINT_HEADCOUNT_BLIGHTED
		animal_min = TAINT_BLIGHTED_ANIMAL_PCT_MIN
		animal_max = TAINT_BLIGHTED_ANIMAL_PCT_MAX
		undead_min = TAINT_BLIGHTED_UNDEAD_PCT_MIN
		undead_max = TAINT_BLIGHTED_UNDEAD_PCT_MAX
	elif ptl >= PTL_CORRUPTED_MIN:
		headcount_range = TAINT_HEADCOUNT_CORRUPTED
		animal_min = TAINT_CORRUPTED_ANIMAL_PCT_MIN
		animal_max = TAINT_CORRUPTED_ANIMAL_PCT_MAX
		undead_min = TAINT_CORRUPTED_UNDEAD_PCT_MIN
		undead_max = TAINT_CORRUPTED_UNDEAD_PCT_MAX
	else:
		headcount_range = TAINT_HEADCOUNT_TOUCHED
		animal_min = TAINT_TOUCHED_ANIMAL_PCT_MIN
		animal_max = TAINT_TOUCHED_ANIMAL_PCT_MAX
		undead_min = TAINT_TOUCHED_UNDEAD_PCT_MIN
		undead_max = TAINT_TOUCHED_UNDEAD_PCT_MAX

	var per_str: int = _rng_range(rng, headcount_range[0], headcount_range[1])
	var total: int   = maxi(1, strength * per_str)

	# Reserve 1 unit for the focal point guardian.
	var pool: int     = maxi(0, total - 1)
	var animal_pct: int = _rng_range(rng, animal_min, animal_max)
	var undead_pct: int = _rng_range(rng, undead_min, undead_max)
	if animal_pct + undead_pct > 100:
		undead_pct = 100 - animal_pct
	var animal_count: int = maxi(0, int(pool * animal_pct / 100.0))
	var undead_count: int = maxi(0, int(pool * undead_pct / 100.0))
	var human_count:  int = maxi(0, pool - animal_count - undead_count)

	# Focal point guardian is the most corrupted creature type at this PTL tier.
	var guardian_type: String
	if ptl >= PTL_BLIGHTED_MIN:
		guardian_type = TAINTED_HUMAN    # Lost (Rank 5)
	elif ptl >= PTL_CORRUPTED_MIN:
		guardian_type = UNDEAD_REVENANT
	else:
		guardian_type = TAINTED_ANIMAL

	var groups: Array = []
	groups.append(_group(guardian_type, 1, ROLE_FOCAL_POINT_GUARDIAN))
	if animal_count > 0:
		groups.append(_group(TAINTED_ANIMAL,  animal_count, ROLE_WANDERER))
	if undead_count > 0:
		groups.append(_group(UNDEAD_REVENANT, undead_count, ROLE_EMERGENT_UNDEAD))
	if human_count > 0:
		groups.append(_group(TAINTED_HUMAN,   human_count,  ROLE_CLUSTERED_PACK))

	return {
		"seed_type": SEED_TAINT_MANIFESTATION,
		"total_count": total,
		"groups": groups,
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": false,
		"has_leader": false,
	}

# -- Wall Sortie (s56.10.11) — all composition values PROVISIONAL -------------

static func _compose_wall_sortie(size: String, rng: RandomNumberGenerator) -> Dictionary:
	var fr: Array
	var er: Array
	match size:
		SORTIE_MEDIUM:
			fr = SORTIE_FRIENDLY_MEDIUM
			er = SORTIE_ENEMY_MEDIUM
		SORTIE_LARGE:
			fr = SORTIE_FRIENDLY_LARGE
			er = SORTIE_ENEMY_LARGE
		_:
			fr = SORTIE_FRIENDLY_SMALL
			er = SORTIE_ENEMY_SMALL

	var f_total: int = _rng_range(rng, fr[0], fr[1])
	var e_total: int = _rng_range(rng, er[0], er[1])

	return {
		"seed_type": SEED_WALL_SORTIE,
		"sortie_size": size,
		"total_count": f_total + e_total,
		"friendly_total": f_total,
		"enemy_total":    e_total,
		"friendly_groups": _sortie_friendly(size, f_total, rng),
		"enemy_groups":    _sortie_enemy(size, e_total, rng),
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": false,
	}

static func _sortie_friendly(size: String, total: int, rng: RandomNumberGenerator) -> Array:
	var groups: Array = []
	match size:
		SORTIE_LARGE:
			var wh:     int = _rng_range(rng, 1, 2)
			var scouts: int = _rng_range(rng, 3, 4)
			var bushi:  int = maxi(1, total - wh - scouts)
			groups.append(_group(HIDA_BUSHI,        1,        ROLE_LEADER))
			if bushi - 1 > 0:
				groups.append(_group(HIDA_BUSHI,    bushi - 1, ROLE_GUARD_POST))
			groups.append(_group(HIRUMA_SCOUT,      scouts,   ROLE_SENTRY))
			groups.append(_group(KUNI_WITCH_HUNTER, wh,       ROLE_RITUAL_SPACE))
		SORTIE_MEDIUM:
			var scouts: int = _rng_range(rng, 2, 3)
			var bushi:  int = maxi(1, total - 1 - scouts)
			groups.append(_group(HIDA_BUSHI,        1,        ROLE_LEADER))
			if bushi - 1 > 0:
				groups.append(_group(HIDA_BUSHI,    bushi - 1, ROLE_GUARD_POST))
			groups.append(_group(HIRUMA_SCOUT,      scouts,   ROLE_SENTRY))
			groups.append(_group(KUNI_WITCH_HUNTER, 1,        ROLE_RITUAL_SPACE))
		_: # SMALL
			var scouts: int = _rng_range(rng, 1, 2)
			var bushi:  int = maxi(1, total - scouts)
			groups.append(_group(HIDA_BUSHI,   1,        ROLE_LEADER))
			if bushi - 1 > 0:
				groups.append(_group(HIDA_BUSHI, bushi - 1, ROLE_GUARD_POST))
			groups.append(_group(HIRUMA_SCOUT, scouts,   ROLE_SENTRY))
	var out: Array = []
	for g in groups:
		if g["count"] > 0:
			out.append(g)
	return out

static func _sortie_enemy(size: String, total: int, rng: RandomNumberGenerator) -> Array:
	var groups: Array = []
	match size:
		SORTIE_LARGE:
			# "Full Shadowlands spectrum" — distribution PROVISIONAL pending playtest (s56.10.11).
			var oni: bool = rng.randf() < 0.20
			var oni_c: int = 1 if oni else 0
			var pool: int  = total - oni_c
			var troll_c:  int = maxi(1, int(pool * 0.10))
			var ogre_c:   int = maxi(2, int(pool * 0.20))
			var undead_c: int = maxi(3, int(pool * 0.25))
			var bak_c:    int = maxi(4, pool - troll_c - ogre_c - undead_c)
			# Ogre split
			var ogre_wl:  int = 1
			var ogre_rav: int = maxi(0, int(ogre_c * 0.40))
			var ogre_war: int = maxi(0, ogre_c - ogre_wl - ogre_rav)
			# Undead split
			var mt_c:  int = mini(2, undead_c / 4)
			var rev_c: int = mini(4, undead_c / 3)
			var skel_c: int = maxi(0, int((undead_c - mt_c - rev_c) * 0.40))
			var zomb_c: int = maxi(0, undead_c - mt_c - rev_c - skel_c)
			# Bakemono split
			var sha_c: int = maxi(1, int(bak_c * 0.10))
			var arc_c: int = maxi(1, int(bak_c * 0.20))
			var bwc:   int = maxi(2, int(bak_c * 0.30))
			var base_c: int = maxi(0, bak_c - sha_c - arc_c - bwc)
			if base_c > 0:   groups.append(_group(BAKEMONO,        base_c,  ROLE_CAMP_GROUP))
			if bwc > 0:      groups.append(_group(BAKEMONO_WARRIOR, bwc,    ROLE_GUARD_POST))
			if arc_c > 0:    groups.append(_group(BAKEMONO_ARCHER,  arc_c,  ROLE_EDGE_DEFENDER))
			if sha_c > 0:    groups.append(_group(BAKEMONO_SHAMAN,  sha_c,  ROLE_RITUAL_SPACE))
			if zomb_c > 0:   groups.append(_group(ZOMBIE,           zomb_c, ROLE_CAMP_GROUP))
			if skel_c > 0:   groups.append(_group(SKELETON_WARRIOR, skel_c, ROLE_GUARD_POST))
			if rev_c > 0:    groups.append(_group(UNDEAD_REVENANT,  rev_c,  ROLE_CHOKEPOINT_HOLDER))
			if mt_c > 0:     groups.append(_group(MAHO_TSUKAI,      mt_c,   ROLE_RITUAL_SPACE))
			if ogre_war > 0: groups.append(_group(OGRE_WARRIOR,     ogre_war, ROLE_GUARD_POST))
			if ogre_rav > 0: groups.append(_group(OGRE_RAVENOUS,    ogre_rav, ROLE_CAMP_GROUP))
			if ogre_wl > 0:  groups.append(_group(OGRE_WARLORD,     ogre_wl,  ROLE_LEADER))
			if troll_c > 0:  groups.append(_group(TROLL,            troll_c,  ROLE_CHOKEPOINT_HOLDER))
			if oni_c > 0:    groups.append(_group(ONI_SPAWN,        oni_c,    ROLE_LEADER))
		SORTIE_MEDIUM:
			# 40% Bakemono, 30% Undead (with Maho-tsukai), 20% Ogre, 10% chance Troll (s56.10.11 LOCKED).
			var troll: bool = rng.randf() < 0.10
			var troll_c: int = 1 if troll else 0
			var ogre_c:    int = maxi(1, int(total * 0.20))
			var undead_c:  int = maxi(2, int(total * 0.30))
			var bak_c:     int = maxi(2, total - ogre_c - undead_c - troll_c)
			# Ogre
			var ogre_wl:  int = 1
			var ogre_rav: int = maxi(0, int((ogre_c - 1) * 0.50))
			var ogre_war: int = maxi(0, ogre_c - ogre_wl - ogre_rav)
			# Undead
			var rev_c:  int = mini(2, undead_c / 4)
			var mt_c:   int = mini(1, rev_c)
			var skel_c: int = maxi(0, int((undead_c - rev_c - mt_c) * 0.40))
			var zomb_c: int = maxi(0, undead_c - rev_c - mt_c - skel_c)
			# Bakemono
			var sha_c: int = maxi(0, int(bak_c * 0.10))
			var arc_c: int = maxi(0, int(bak_c * 0.20))
			var base_c: int = maxi(0, bak_c - sha_c - arc_c)
			if base_c > 0:   groups.append(_group(BAKEMONO,        base_c, ROLE_CAMP_GROUP))
			if arc_c > 0:    groups.append(_group(BAKEMONO_ARCHER,  arc_c, ROLE_EDGE_DEFENDER))
			if sha_c > 0:    groups.append(_group(BAKEMONO_SHAMAN,  sha_c, ROLE_RITUAL_SPACE))
			if zomb_c > 0:   groups.append(_group(ZOMBIE,           zomb_c, ROLE_CAMP_GROUP))
			if skel_c > 0:   groups.append(_group(SKELETON_WARRIOR, skel_c, ROLE_GUARD_POST))
			if rev_c > 0:    groups.append(_group(UNDEAD_REVENANT,  rev_c,  ROLE_CHOKEPOINT_HOLDER))
			if mt_c > 0:     groups.append(_group(MAHO_TSUKAI,      mt_c,   ROLE_LEADER))
			if ogre_war > 0: groups.append(_group(OGRE_WARRIOR,     ogre_war, ROLE_GUARD_POST))
			if ogre_rav > 0: groups.append(_group(OGRE_RAVENOUS,    ogre_rav, ROLE_CAMP_GROUP))
			if ogre_wl > 0:  groups.append(_group(OGRE_WARLORD,     ogre_wl,  ROLE_LEADER))
			if troll_c > 0:  groups.append(_group(TROLL,            troll_c,  ROLE_CHOKEPOINT_HOLDER))
		_: # SMALL — 60% Bakemono, 25% Undead, 15% single Ogre Warrior or none (s56.10.11 LOCKED)
			var has_ogre: bool = rng.randf() < 0.50  # 15% slot = 0 or 1 ogre; PROVISIONAL 50/50
			var ogre_c:   int  = 1 if has_ogre else 0
			var undead_c: int  = maxi(1, int(total * 0.25))
			var bak_c:    int  = maxi(2, total - undead_c - ogre_c)
			var bwc:  int = maxi(0, int(bak_c * 0.30))
			var base_c: int = maxi(0, bak_c - bwc)
			var skel_c: int = maxi(0, int(undead_c * 0.40))
			var zomb_c: int = maxi(0, undead_c - skel_c)
			if base_c > 0:  groups.append(_group(BAKEMONO,        base_c, ROLE_CAMP_GROUP))
			if bwc > 0:     groups.append(_group(BAKEMONO_WARRIOR, bwc,   ROLE_GUARD_POST))
			if zomb_c > 0:  groups.append(_group(ZOMBIE,           zomb_c, ROLE_CAMP_GROUP))
			if skel_c > 0:  groups.append(_group(SKELETON_WARRIOR, skel_c, ROLE_GUARD_POST))
			if ogre_c > 0:  groups.append(_group(OGRE_WARRIOR,     ogre_c, ROLE_CHOKEPOINT_HOLDER))
	return groups

# -- Urban Criminal Network (s56.10.15) ---------------------------------------

static func _compose_urban_criminal(strength: int, rng: RandomNumberGenerator) -> Dictionary:
	var hc_range: Array
	if strength <= CRIMINAL_STR_TIER1_MAX:
		hc_range = CRIMINAL_HEADCOUNT_TIER1
	elif strength <= CRIMINAL_STR_TIER2_MAX:
		hc_range = CRIMINAL_HEADCOUNT_TIER2
	elif strength <= CRIMINAL_STR_TIER3_MAX:
		hc_range = CRIMINAL_HEADCOUNT_TIER3
	else:
		hc_range = CRIMINAL_HEADCOUNT_TIER4

	var total: int = _rng_range(rng, hc_range[0], hc_range[1])

	var boss_type: String
	var has_named_npc_slot: bool
	if strength >= 3:
		boss_type          = NETWORK_BOSS
		has_named_npc_slot = true
	else:
		boss_type          = BANDIT_THUG
		has_named_npc_slot = false

	var lookout_count: int = 0
	var doshin_count:  int = 0
	if strength >= 5:
		lookout_count = _rng_range(rng, 2, 3)
		doshin_count  = 1
	elif strength >= 3:
		lookout_count = _rng_range(rng, 1, 2)

	var allocated: int  = 1 + lookout_count + doshin_count
	var remaining: int  = maxi(0, total - allocated)

	var enforcer_count: int
	if strength >= 5:
		enforcer_count = mini(remaining, _rng_range(rng, 3, 5))
	elif strength >= 3:
		enforcer_count = mini(remaining, _rng_range(rng, 2, 3))
	elif strength >= 2:
		enforcer_count = mini(remaining, 1)
	else:
		enforcer_count = 0
	var thug_count: int = maxi(0, remaining - enforcer_count)

	# Str 7+: one ronin enforcer guards the escape tunnel (separate from regular guard posts).
	var escape_guard: int = 1 if strength >= 7 else 0
	if escape_guard > 0 and enforcer_count > 0:
		enforcer_count -= 1
	elif escape_guard > 0:
		thug_count = maxi(0, thug_count - 1)

	var groups: Array = []
	groups.append(_group(boss_type, 1, ROLE_LEADER))
	if enforcer_count > 0:
		groups.append(_group(RONIN_ENFORCER, enforcer_count, ROLE_GUARD_POST))
	if thug_count > 0:
		groups.append(_group(BANDIT_THUG, thug_count, ROLE_CAMP_GROUP))
	if lookout_count > 0:
		groups.append(_group(LOOKOUT, lookout_count, ROLE_LOOKOUT_POSITION))
	if doshin_count > 0:
		groups.append(_group(CORRUPTED_DOSHIN, doshin_count, ROLE_CHOKEPOINT_HOLDER))
	if escape_guard > 0:
		groups.append(_group(RONIN_ENFORCER, escape_guard, ROLE_ESCAPE_GUARD))

	return {
		"seed_type": SEED_URBAN_CRIMINAL_NETWORK,
		"total_count": total,
		"groups": groups,
		"individual_variance_chance": _variance_chance(rng),
		"has_named_npc_slot": has_named_npc_slot,
		"boss_has_escape_tunnel": true,
	}
