class_name KolatMasterSelector
## Kolat Master selection at world generation (GDD s54.7a, locked s54.7j2).
## Pure simulation class — no Node inheritance. Selects one Master per Sect from
## the named-NPC pool via a weighted-tier draw, in a fixed processing order that
## doubles as conflict resolution. Applies Sect skill boosts and the hidden
## Master fields. Special rules (koku reserves, world-start sleeper/contact
## counts) are surfaced as flags for the world generator to act on.
##
## Tier criteria from s54.7a are mapped to queryable character data (clan,
## school_name, role_position, skills, status, glory, school_type, lord-tier via
## role_position). Criteria that the data model cannot express (e.g. "institutional
## access to isolated people") are relaxed to the Sect's skill thresholds —
## flagged PROVISIONAL in the per-Sect notes.

const TIER_WEIGHTS: Dictionary = {1: 5, 2: 2, 3: 1}

# Processing order = conflict-resolution priority (s54.7a). Roc has no profile
# (standard agent); it still gets a seat via the generic min/tier path.
const PROCESSING_ORDER: Array[int] = [
	Enums.KolatSect.TIGER,
	Enums.KolatSect.CHRYSANTHEMUM,
	Enums.KolatSect.SILK,
	Enums.KolatSect.COIN,
	Enums.KolatSect.CLOUD,
	Enums.KolatSect.JADE,
	Enums.KolatSect.DREAM,
	Enums.KolatSect.LOTUS,
	Enums.KolatSect.ROC,
	Enums.KolatSect.STEEL,
]

# Sect-specific skill boosts (max rule — never lowers a skill). s54.7a.
const SECT_BOOSTS: Dictionary = {
	Enums.KolatSect.TIGER: {"Courtier (Manipulation)": 8, "Investigation": 7, "Intimidation (Control)": 7, "Sincerity (Deceit)": 7},
	Enums.KolatSect.CHRYSANTHEMUM: {"Courtier": 8, "Etiquette": 8, "Sincerity (Deceit)": 7, "Investigation (Notice)": 6},
	Enums.KolatSect.SILK: {"Acting": 8, "Sincerity (Deceit)": 8, "Courtier (Manipulation)": 7, "Forgery": 6},
	Enums.KolatSect.COIN: {"Commerce (Appraisal)": 8, "Commerce (Mathematics)": 8, "Courtier": 7, "Sincerity (Deceit)": 6, "Forgery": 6},
	Enums.KolatSect.CLOUD: {"Spellcraft": 8, "Lore: History": 7, "Calligraphy (Cipher)": 7, "Meditation": 6},
	Enums.KolatSect.JADE: {"Investigation": 8, "Lore: Shadowlands": 7, "Medicine": 6, "Spellcraft": 6},
	Enums.KolatSect.DREAM: {"Temptation": 8, "Intimidation (Control)": 8, "Medicine": 7, "Sincerity (Deceit)": 6},
	Enums.KolatSect.LOTUS: {"Stealth (Sneaking)": 8, "Acting": 7, "Knives": 6, "Ninjutsu": 5},
	Enums.KolatSect.STEEL: {"Battle": 8, "Defense": 7, "Intimidation (Bullying)": 6},
	Enums.KolatSect.ROC: {},
}

const WEAPON_SKILLS: Array[String] = [
	"Kenjutsu", "Iaijutsu", "Polearms", "Heavy Weapons", "Kyujutsu",
	"Knives", "Jiujutsu", "War Fan", "Ninjutsu", "Staves", "Spears",
]

# Bushido virtue hard blocks (s54.7b): virtue → Sects it can never master.
# Shourido virtues carry no hard blocks (they shape pursuit, not eligibility).
const BUSHIDO_HARD_BLOCKS: Dictionary = {
	Enums.BushidoVirtue.GI: [
		Enums.KolatSect.TIGER, Enums.KolatSect.SILK, Enums.KolatSect.COIN,
		Enums.KolatSect.DREAM, Enums.KolatSect.LOTUS,
	],
	Enums.BushidoVirtue.MAKOTO: [
		Enums.KolatSect.TIGER, Enums.KolatSect.SILK,
		Enums.KolatSect.DREAM, Enums.KolatSect.LOTUS,
	],
	Enums.BushidoVirtue.REI: [Enums.KolatSect.DREAM],
	Enums.BushidoVirtue.JIN: [Enums.KolatSect.DREAM, Enums.KolatSect.LOTUS],
	Enums.BushidoVirtue.CHUGI: [Enums.KolatSect.TIGER],
}


# === PUBLIC ENTRY ============================================================

## Select Masters from `npcs` (Array of L5RCharacterData). Mutates selected
## characters (applies boosts + hidden fields). Returns a Dictionary mapping
## KolatSect → npc_id (or -1 for a seat left vacant when no eligible candidate
## exists). Deterministic given the DiceEngine seed.
static func select_masters(npcs: Array, dice: DiceEngine) -> Dictionary:
	var taken: Dictionary = {}        # npc_id → true
	var result: Dictionary = {}
	var tiger_id: int = -1
	for sect: int in PROCESSING_ORDER:
		var pool: Array = []          # weighted draw pool of npc_ids
		for npc: L5RCharacterData in npcs:
			if npc == null or taken.has(npc.character_id) or CharacterStats.is_dead(npc):
				continue
			if not _meets_minimums(sect, npc):
				continue
			var tier: int = _classify_tier(sect, npc)
			for _w: int in range(TIER_WEIGHTS.get(tier, 1)):
				pool.append(npc.character_id)
		if pool.is_empty():
			result[sect] = -1
			continue
		var pick_id: int = pool[dice.rand_int_range(0, pool.size() - 1)]
		taken[pick_id] = true
		result[sect] = pick_id
		var master: L5RCharacterData = _find(npcs, pick_id)
		if sect == Enums.KolatSect.TIGER:
			tiger_id = pick_id
		_apply_master(master, sect)
		_apply_special_rules(master, sect, dice)
	# Wire the Kolat chain: every Master reports to Tiger; Tiger reports to none.
	# Every Master also carries a Tear (s54.7c/d), and Tiger holds the only complete
	# Sect → npc_id identity map (s54.7h kolat_master_identities).
	var identities: Dictionary = {}
	for sect: int in result.keys():
		var nid: int = result[sect]
		if nid < 0:
			continue
		var m: L5RCharacterData = _find(npcs, nid)
		if m == null:
			continue
		m.kolat_superior_id = -1 if sect == Enums.KolatSect.TIGER else tiger_id
		m.holds_tear = true
		identities[sect] = nid
	if tiger_id >= 0:
		var tiger: L5RCharacterData = _find(npcs, tiger_id)
		if tiger != null:
			tiger.special_data["kolat_master_identities"] = identities
	return result


# === MASTER SUCCESSION (s54.7g) ==============================================

## Resolve a vacant Master seat (s54.7g). Runs the three-ranked-heir cascade,
## then Tiger's discretionary selection from the Sect's senior conscious agents
## if all three heirs are unavailable. Mutates the elevated agent (applies boosts
## + hidden fields, NOT the world-gen special-rule reserves) and re-points the
## Kolat chain. Returns the new Master's npc_id, or -1 if the Sect cannot be
## filled (no valid heir and no eligible agent).
##
## `heir_designations`: Dictionary[kolat_sect: int → Array[npc_id, npc_id, npc_id]]
##   (the Cloud-archive cipher record; ranked in order of preference).
## `under_investigation_ids`: npc_ids currently under active investigation — an
##   heir condition the pure selector cannot read from character data alone, so
##   the caller (which holds CrimeRecords) supplies it. Default empty = none.
static func evaluate_succession(
	sect: int,
	npcs: Array,
	heir_designations: Dictionary,
	dice: DiceEngine,
	under_investigation_ids: Array = [],
) -> int:
	var new_master: L5RCharacterData = null
	# 1) Three ranked heirs in order (s54.7g Succession Cascade).
	var heirs: Array = heir_designations.get(sect, [])
	for heir_id: int in heirs:
		var heir: L5RCharacterData = _find(npcs, int(heir_id))
		if _heir_valid(heir, sect, under_investigation_ids):
			new_master = heir
			break
	# 2) Tiger's discretionary selection from the Sect's senior conscious agents.
	if new_master == null:
		new_master = _discretionary_select(sect, npcs, dice, under_investigation_ids)
	if new_master == null:
		return -1
	_apply_master(new_master, sect)  # boosts + hidden fields; no world-gen reserves
	# Orientation, not inherited tasks (s54.7g): clear the Kolat objective slot.
	new_master.special_data.erase("kolat_objective")
	_repoint_chain_after_succession(sect, new_master, npcs)
	return new_master.character_id


## An heir is valid only if alive, a conscious agent in the vacant Sect, not
## already a Master, not Broken, and not under active investigation (s54.7g).
static func _heir_valid(heir: L5RCharacterData, sect: int, under_investigation_ids: Array) -> bool:
	if heir == null or CharacterStats.is_dead(heir):
		return false
	if heir.kolat_sect != sect:
		return false
	if heir.is_kolat_master:
		return false  # already holds a seat
	if bool(heir.special_data.get("kolat_broken", false)):
		return false
	if heir.character_id in under_investigation_ids:
		return false
	return true


## Tiger's discretionary fallback (s54.7g): the s54.7a weighted tier draw,
## restricted to conscious agents already in the vacant Sect.
static func _discretionary_select(
	sect: int, npcs: Array, dice: DiceEngine, under_investigation_ids: Array,
) -> L5RCharacterData:
	var pool: Array = []
	for npc: L5RCharacterData in npcs:
		if not is_designable_agent(sect, npc, under_investigation_ids):
			continue
		var tier: int = _classify_tier(sect, npc)
		for _w: int in range(TIER_WEIGHTS.get(tier, 1)):
			pool.append(npc.character_id)
	if pool.is_empty():
		return null
	return _find(npcs, pool[dice.rand_int_range(0, pool.size() - 1)])


# === HEIR DESIGNATION (s54.7g, owner-authorized 2026-09-04) ==================
# A Master privately designates exactly three ranked heirs (s54.7g "Designation").
# The GDD locks the eligible pool + heir conditions but leaves the actual pick as
# "the Master's judgment expressed in the ordering." Owner ruling (2026-09-04):
# select the top three eligible same-Sect conscious agents by s54.7a tier weight,
# deterministically. Tiebreak within a tier: higher Insight, then higher Status,
# then lower character_id (a stable, reproducible structural order). PROVISIONAL
# — the ranking rule is a structural selection choice, not a GDD-locked value.

## True if `npc` may be designated an heir of (or discretionarily seated into)
## `sect`: alive, conscious, a same-Sect Kolat agent, not already a Master, not
## Broken, not under active investigation, and meeting the Sect minimums (s54.7g
## heir conditions + s54.7a floor). This is the single eligibility predicate
## shared by heir designation and Tiger's discretionary fallback.
static func is_designable_agent(sect: int, npc: L5RCharacterData, under_investigation_ids: Array) -> bool:
	if npc == null or CharacterStats.is_dead(npc) or npc.is_kolat_master:
		return false
	if npc.kolat_sect != sect:
		return false
	if bool(npc.special_data.get("kolat_broken", false)):
		return false
	if npc.character_id in under_investigation_ids:
		return false
	if not _meets_minimums(sect, npc):
		return false
	return true


## Rank the pre-filtered `eligible_agents` and return the top three as an ordered
## Array of npc_ids (fewer than three when the pool is short; the ranked-heir
## cascade + Tiger's discretionary fallback cover a short or empty list). Callers
## pass a list already filtered by is_designable_agent().
static func designate_heirs(sect: int, eligible_agents: Array) -> Array:
	var ranked: Array = eligible_agents.duplicate()
	ranked.sort_custom(func(a: L5RCharacterData, b: L5RCharacterData) -> bool:
		return _heir_rank_less(sect, a, b))
	var out: Array = []
	for i: int in range(mini(3, ranked.size())):
		out.append(ranked[i].character_id)
	return out


## Deterministic "a ranks ahead of b" comparator for heir designation. Lower
## s54.7a tier wins (Tier 1 Ideal ahead of Tier 3 Last Resort); ties break by
## higher Insight rank, then higher Status, then lower character_id.
static func _heir_rank_less(sect: int, a: L5RCharacterData, b: L5RCharacterData) -> bool:
	var ta: int = _classify_tier(sect, a)
	var tb: int = _classify_tier(sect, b)
	if ta != tb:
		return ta < tb
	var ia: int = CharacterStats.get_insight_rank(a)
	var ib: int = CharacterStats.get_insight_rank(b)
	if ia != ib:
		return ia > ib
	if a.status != b.status:
		return a.status > b.status
	return a.character_id < b.character_id


## Re-point the Kolat chain after a succession. A new non-Tiger Master reports to
## the living Tiger. A new Tiger reports to no one and every other living Master
## re-points to them (s54.7g Tiger's Succession).
static func _repoint_chain_after_succession(sect: int, new_master: L5RCharacterData, npcs: Array) -> void:
	if sect == Enums.KolatSect.TIGER:
		new_master.kolat_superior_id = -1
		for npc: L5RCharacterData in npcs:
			if npc == null or npc.character_id == new_master.character_id:
				continue
			if npc.is_kolat_master and npc.kolat_sect != Enums.KolatSect.TIGER and not CharacterStats.is_dead(npc):
				npc.kolat_superior_id = new_master.character_id
		return
	new_master.kolat_superior_id = _living_tiger_id(npcs)


static func _living_tiger_id(npcs: Array) -> int:
	for npc: L5RCharacterData in npcs:
		if npc != null and npc.is_kolat_master and npc.kolat_sect == Enums.KolatSect.TIGER \
			and not CharacterStats.is_dead(npc):
			return npc.character_id
	return -1


# === ELIGIBILITY (universal filters + Sect minimums, s54.7a) =================

## Bushido virtue hard block check (s54.7b). Returns false if the NPC's virtue
## forbids this Sect. Shourido and NONE never block.
static func _personality_permits(sect: int, npc: L5RCharacterData) -> bool:
	var blocked: Array = BUSHIDO_HARD_BLOCKS.get(npc.bushido_virtue, [])
	return sect not in blocked


static func _meets_minimums(sect: int, npc: L5RCharacterData) -> bool:
	# Universal: Insight 3+, not the Emperor. ("Not already selected" handled by caller.)
	if CharacterStats.get_insight_rank(npc) < 3:
		return false
	if npc.role_position == "Emperor":
		return false
	# Bushido virtue hard blocks (s54.7b): some virtues make an NPC ineligible
	# for a Sect entirely — they are never added to that Sect's draw pool.
	if not _personality_permits(sect, npc):
		return false
	match sect:
		Enums.KolatSect.TIGER:
			return _skill(npc, "Courtier (Manipulation)") >= 3 and _skill(npc, "Investigation") >= 3
		Enums.KolatSect.CHRYSANTHEMUM:
			return npc.status >= 5.0 and _skill(npc, "Courtier") >= 4 and _skill(npc, "Etiquette") >= 3
		Enums.KolatSect.SILK:
			return _skill(npc, "Acting") >= 3 and _skill(npc, "Courtier") >= 3 and npc.awareness >= 3
		Enums.KolatSect.COIN:
			return _skill(npc, "Commerce") >= 4 and _is_lord(npc)
		Enums.KolatSect.CLOUD:
			return npc.school_type == Enums.SchoolType.SHUGENJA \
				and _skill(npc, "Spellcraft") >= 3 and _skill(npc, "Calligraphy") >= 3 \
				and _lore_count_at(npc, 3) >= 2
		Enums.KolatSect.JADE:
			return (npc.school_type == Enums.SchoolType.SHUGENJA or _is_witch_hunter(npc)) \
				and _skill(npc, "Lore: Shadowlands") >= 3 and _skill(npc, "Investigation") >= 3
		Enums.KolatSect.DREAM:
			return _skill(npc, "Temptation") >= 3 and _skill(npc, "Intimidation (Control)") >= 2 \
				and _skill(npc, "Medicine") >= 2
		Enums.KolatSect.LOTUS:
			return _skill(npc, "Stealth") >= 3 and _best_weapon_skill(npc) >= 4
		Enums.KolatSect.STEEL:
			return _skill(npc, "Battle") >= 3 and _best_weapon_skill(npc) >= 4
		Enums.KolatSect.ROC:
			# No profile; standard agent. Generic floor: a capable named samurai.
			return true
	return false


# === TIER CLASSIFICATION (s54.7a) ============================================
# Returns 1 (Ideal), 2 (Acceptable), or 3 (Last Resort). Assumes minimums met.

static func _classify_tier(sect: int, npc: L5RCharacterData) -> int:
	match sect:
		Enums.KolatSect.TIGER:
			if (npc.clan == "Scorpion" and npc.role_position in ["Clan Champion", "Family Daimyo"]) \
				or npc.role_position in ["Emerald Champion", "Jade Champion"]:
				return 1
			if _is_magistrate(npc) and _skill(npc, "Investigation") >= 5:
				return 2
			return 3
		Enums.KolatSect.CHRYSANTHEMUM:
			if npc.family in ["Otomo", "Seppun", "Miya"] and npc.role_position == "Family Daimyo":
				return 1
			if npc.family in ["Otomo", "Seppun", "Miya"] and _skill(npc, "Courtier") >= 4:
				return 2
			return 3
		Enums.KolatSect.SILK:
			if npc.school in ["Shosuro Actor", "Doji Courtier", "Kitsuki Investigator"] \
				and npc.school_rank >= 5:
				return 1
			if _skill(npc, "Acting") >= 4 and _skill(npc, "Sincerity (Deceit)") >= 4:
				return 2
			return 3
		Enums.KolatSect.COIN:
			if npc.family in ["Yasuki", "Ide"] and npc.role_position == "Family Daimyo":
				return 1
			if npc.role_position == "Family Daimyo" and _skill(npc, "Commerce") >= 4:
				return 2
			return 3
		Enums.KolatSect.CLOUD:
			if npc.family in ["Isawa", "Agasha", "Tamori"] and npc.role_position == "Family Daimyo":
				return 1
			if npc.school_rank >= 5 and _skill(npc, "Spellcraft") >= 4 and _lore_count_at(npc, 4) >= 3:
				return 2
			return 3
		Enums.KolatSect.JADE:
			if (_is_witch_hunter(npc) and npc.school_rank >= 4) or npc.role_position == "Jade Champion":
				return 1
			if _skill(npc, "Lore: Shadowlands") >= 4:
				return 2
			return 3
		Enums.KolatSect.DREAM:
			# T1 "Head Sensei / senior Abbot / Kuroiban+Medicine" — relaxed
			# (no institutional-access field): high Temptation+Medicine. PROVISIONAL.
			if _skill(npc, "Temptation") >= 5 and _skill(npc, "Medicine") >= 4:
				return 1
			if _skill(npc, "Temptation") >= 4:
				return 2
			return 3
		Enums.KolatSect.LOTUS:
			if npc.school in ["Shosuro Infiltrator", "Shosuro Actor"] and npc.school_rank >= 5:
				return 1
			if _skill(npc, "Stealth") >= 4 and _best_weapon_skill(npc) >= 5:
				return 2
			return 3
		Enums.KolatSect.STEEL:
			if npc.glory >= 5.0 and _best_weapon_skill(npc) >= 5:
				return 1
			if _skill(npc, "Battle") >= 4:
				return 2
			return 3
	return 3


# === MASTER APPLICATION (s54.7a "What Every Master Receives") ================

static func _apply_master(npc: L5RCharacterData, sect: int) -> void:
	if npc == null:
		return
	npc.is_kolat_master = true
	npc.kolat_sect = sect
	WorldGenerator.equip_crystal_weapons(npc)  # s54.7 Kolat crystal weapons (owner 2026-06-18)
	# Apply Sect skill boosts (max rule — never lower).
	for skill_name: String in SECT_BOOSTS.get(sect, {}).keys():
		var boosted: int = SECT_BOOSTS[sect][skill_name]
		if npc.skills.get(skill_name, 0) < boosted:
			npc.skills[skill_name] = boosted
	# Sect special-rule seed values surfaced for the world generator.
	# Coin: hidden untraceable reserves (2d10 × 10), stored as kolat_koku.
	# Dream/Silk world-start sleeper/contact counts are surfaced via
	# get_special_rule_flags(); the generator creates the registry entries.


## Apply a Master's Sect special rule at selection (s54.7a). The Coin reserve is
## a number on the Master, so it is applied directly to `kolat_koku`. The Dream
## sleeper count and Silk contact count drive a network-creation pass that needs
## NPC selection (deferred) — they are stamped into `special_data` so that pass
## knows the target count without inventing which NPCs become sleepers/contacts.
static func _apply_special_rules(npc: L5RCharacterData, sect: int, dice: DiceEngine) -> void:
	if npc == null:
		return
	var flags: Dictionary = get_special_rule_flags(sect, dice)
	if flags.has("hidden_kolat_koku"):
		npc.kolat_koku += int(flags["hidden_kolat_koku"])
	if flags.has("world_start_sleepers"):
		npc.special_data["world_start_sleepers"] = int(flags["world_start_sleepers"])
	if flags.has("preplaced_contacts"):
		npc.special_data["preplaced_contacts"] = int(flags["preplaced_contacts"])
	# s33 The World is Truth is a secret Kolat spell — grant it to shugenja Masters (the network
	# heads trusted with the conspiracy's secrets), giving the conspiracy a caster. Actually casting
	# it stays gated on Air School Rank >= 6 + an Air slot (SpellSystem.can_cast).
	if npc.school_type == Enums.SchoolType.SHUGENJA \
			and KolatSystem.WORLD_IS_TRUTH_ID not in npc.spells_known:
		npc.spells_known.append(KolatSystem.WORLD_IS_TRUTH_ID)


## Special-rule flags for the world generator to act on after selection
## (s54.7a special rules). Pure description — no world mutation here.
static func get_special_rule_flags(sect: int, dice: DiceEngine) -> Dictionary:
	match sect:
		Enums.KolatSect.COIN:
			# Hidden koku reserves: 2d10 × 10 (s54.7a).
			return {"hidden_kolat_koku": (dice.rand_int_range(1, 10) + dice.rand_int_range(1, 10)) * 10}
		Enums.KolatSect.DREAM:
			# 1d6+2 world-start sleepers (s54.7a / s54.7c).
			return {"world_start_sleepers": dice.rand_int_range(1, 6) + 2}
		Enums.KolatSect.SILK:
			# 1d6+2 pre-placed conscious agent contacts (s54.7a).
			return {"preplaced_contacts": dice.rand_int_range(1, 6) + 2}
	return {}


# === QUERY HELPERS ===========================================================

static func _find(npcs: Array, npc_id: int) -> L5RCharacterData:
	for n: L5RCharacterData in npcs:
		if n != null and n.character_id == npc_id:
			return n
	return null


static func _skill(npc: L5RCharacterData, name: String) -> int:
	return npc.skills.get(name, 0)


static func _best_weapon_skill(npc: L5RCharacterData) -> int:
	var best: int = 0
	for w: String in WEAPON_SKILLS:
		best = maxi(best, npc.skills.get(w, 0))
	return best


## Count of distinct "Lore: *" skills at or above `rank`.
static func _lore_count_at(npc: L5RCharacterData, rank: int) -> int:
	var n: int = 0
	for skill_name: String in npc.skills.keys():
		if skill_name.begins_with("Lore:") and npc.skills[skill_name] >= rank:
			n += 1
	return n


## Lord-tier: holds a daimyo/champion/headman seat (proxy for "has a province").
static func _is_lord(npc: L5RCharacterData) -> bool:
	var r: String = npc.role_position
	return r.contains("Daimyo") or r.contains("Champion") or r == "Village Headman"


static func _is_magistrate(npc: L5RCharacterData) -> bool:
	return npc.role_position.contains("Magistrate")


static func _is_witch_hunter(npc: L5RCharacterData) -> bool:
	if npc.school.contains("Witch Hunter") or npc.school.contains("Witch-Hunter"):
		return true
	if npc.role_position.contains("Inquisitor"):
		return true
	return false
