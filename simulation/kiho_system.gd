class_name KihoSystem
## Kiho eligibility, acquisition, activation rules, and stub effect registry.
## GDD s38 (catalog & rules) + s38a (locked values). Pure simulation class —
## no Node inheritance.
##
## Kiho fall between spells and bushi Techniques — elemental abilities of the
## Brotherhood of Shinsei. This system covers learning, eligibility, the cost
## multiplier and knowledge cap for non-Brotherhood monks, the activation rules,
## and the active-slot constraint.
##
## MONK-ONLY (owner override, 2026-06-06, s38a): only MONK characters may learn
## kiho. This overrides s38's provision that shugenja may learn kiho at 2× cost —
## shugenja are excluded entirely. Combined with the rule that PCs may not be
## monks (s60.2), PCs never learn kiho.

enum KihoType { INTERNAL, KHARMIC, MARTIAL, MYSTICAL }

# Activation roll TNs (GDD s38): Meditation/Void roll, TN 15 = Complex Action,
# TN 30 = Simple Action. A Void Point activates as a Free Action (no roll).
const ACTIVATION_TN_COMPLEX: int = 15
const ACTIVATION_TN_SIMPLE: int = 30

# Cost multipliers (GDD s38): non-Brotherhood monks pay 1.5× (Brotherhood ×1).
# Shugenja are excluded from kiho entirely (s38a monk-only override).
const COST_MULT_BROTHERHOOD: float = 1.0
const COST_MULT_NON_BROTHERHOOD_MONK: float = 1.5

# Catalog (GDD s38). Each entry: ring, mastery, type, atemi, staff, optional flags.
const KIHO_DATA: Dictionary = {
	# -- AIR --
	"Air Fist":               {"ring": Enums.Ring.AIR, "mastery": 3, "type": KihoType.INTERNAL, "effect_id": "kiho_air_fist_initiative"},
	"Calling the East Wind":  {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.MARTIAL},
	"Censure of Thunder":     {"ring": Enums.Ring.AIR, "mastery": 7, "type": KihoType.MARTIAL, "atemi": true, "atemi_effect": {"damage": {"rolled": 1, "kept": 1, "bypass_reduction": true}, "disarm": true, "vp_negate": {"vp_cost": 2, "extra_rolled": 2, "extra_kept": 2}}},
	"Eye of the Eagle":       {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.INTERNAL},
	"Flee the Darkness":      {"ring": Enums.Ring.AIR, "mastery": 6, "type": KihoType.KHARMIC},
	"The Great Silence":      {"ring": Enums.Ring.AIR, "mastery": 4, "type": KihoType.MYSTICAL, "atemi": true, "atemi_effect": {"condition": "silenced"}},
	"Harmony of the Mind":    {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.MYSTICAL},
	"Hurricane Palm":         {"ring": Enums.Ring.AIR, "mastery": 7, "type": KihoType.MARTIAL},
	"Inari's Wrath":          {"ring": Enums.Ring.AIR, "mastery": 8, "type": KihoType.MYSTICAL},
	"Riding the Clouds":      {"ring": Enums.Ring.AIR, "mastery": 3, "type": KihoType.MYSTICAL},
	"Soul of the Four Winds": {"ring": Enums.Ring.AIR, "mastery": 4, "type": KihoType.INTERNAL, "effect_id": "kiho_soul_four_winds_armor"},
	"Stain Upon the Soul":    {"ring": Enums.Ring.AIR, "mastery": 3, "type": KihoType.MARTIAL, "atemi": true, "atemi_effect": {"wound_rank_penalty": {"rank_ring": Enums.Ring.AIR, "duration_rings": [Enums.Ring.AIR], "duration_insight": true, "source": "stain_soul"}}},
	"Steal the Air Dragon":   {"ring": Enums.Ring.AIR, "mastery": 7, "type": KihoType.KHARMIC},
	"Strike Through the Wind": {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.MYSTICAL},
	"Touch of the Storm":     {"ring": Enums.Ring.AIR, "mastery": 6, "type": KihoType.MARTIAL, "atemi": true},
	"Thunder's Word":         {"ring": Enums.Ring.AIR, "mastery": 6, "type": KihoType.MYSTICAL},
	"Way of the Willow":      {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.INTERNAL},
	"The Wind's Vision":      {"ring": Enums.Ring.AIR, "mastery": 4, "type": KihoType.INTERNAL},
	# -- EARTH --
	"Bishamon's Grasp":       {"ring": Enums.Ring.EARTH, "mastery": 7, "type": KihoType.KHARMIC},
	"Cleansing Spirit":       {"ring": Enums.Ring.EARTH, "mastery": 4, "type": KihoType.INTERNAL},
	"Depths of the World":    {"ring": Enums.Ring.EARTH, "mastery": 4, "type": KihoType.INTERNAL},
	"Earthen Fist":           {"ring": Enums.Ring.EARTH, "mastery": 3, "type": KihoType.INTERNAL},
	"Earth Needs No Eyes":    {"ring": Enums.Ring.EARTH, "mastery": 3, "type": KihoType.INTERNAL},
	"Earth Palm":             {"ring": Enums.Ring.EARTH, "mastery": 6, "type": KihoType.MARTIAL, "atemi": true},
	"Embrace the Stone":      {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.MYSTICAL, "effect_id": "kiho_embrace_stone_reduction"},
	"Grasp the Earth Dragon": {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.INTERNAL, "effect_id": "kiho_grasp_earth_dragon_wound"},
	"Harmony in Earth":       {"ring": Enums.Ring.EARTH, "mastery": 6, "type": KihoType.INTERNAL},
	"Rest, My Brother":       {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.MARTIAL, "atemi": true},
	"Rising Mountain":        {"ring": Enums.Ring.EARTH, "mastery": 6, "type": KihoType.KHARMIC},
	"The Rolling Avalanche":  {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.MARTIAL, "atemi": true},
	"Root the Mountain":      {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.INTERNAL},
	"Shadowed Mountain":      {"ring": Enums.Ring.EARTH, "mastery": 6, "type": KihoType.INTERNAL},
	"Speed of the Mountains": {"ring": Enums.Ring.EARTH, "mastery": 4, "type": KihoType.KHARMIC, "atemi": true},
	"Way of the Earth":       {"ring": Enums.Ring.EARTH, "mastery": 4, "type": KihoType.MARTIAL},
	"Wholeness in All":       {"ring": Enums.Ring.EARTH, "mastery": 6, "type": KihoType.KHARMIC},
	# -- FIRE --
	"The Body is an Anvil":   {"ring": Enums.Ring.FIRE, "mastery": 4, "type": KihoType.MYSTICAL},
	"Breaking Blow":          {"ring": Enums.Ring.FIRE, "mastery": 3, "type": KihoType.MARTIAL},
	"Channel the Fire Dragon": {"ring": Enums.Ring.FIRE, "mastery": 6, "type": KihoType.INTERNAL},
	"Dance of the Flames":    {"ring": Enums.Ring.FIRE, "mastery": 6, "type": KihoType.MARTIAL},
	"Destiny's Strike":       {"ring": Enums.Ring.FIRE, "mastery": 4, "type": KihoType.MARTIAL},
	"Falling Star Strike":    {"ring": Enums.Ring.FIRE, "mastery": 7, "type": KihoType.MARTIAL, "atemi": true},
	"Fire's Fleeting Speed":  {"ring": Enums.Ring.FIRE, "mastery": 4, "type": KihoType.KHARMIC},
	"Flame Fist":             {"ring": Enums.Ring.FIRE, "mastery": 3, "type": KihoType.MARTIAL, "atemi": true, "atemi_effect": {"timed": {"kind": "all_rolls", "value_ring": Enums.Ring.FIRE, "value_mult": -3, "duration_ring": Enums.Ring.FIRE, "source": "flame_fist"}}},
	"The Mind's Fire":        {"ring": Enums.Ring.FIRE, "mastery": 4, "type": KihoType.INTERNAL},
	"Seven Storm's Fist":     {"ring": Enums.Ring.FIRE, "mastery": 6, "type": KihoType.MARTIAL, "atemi": true, "atemi_effect": {"condition": "stunned", "contest": {"attacker_ring": Enums.Ring.FIRE, "defender_ring": Enums.Ring.FIRE}}},
	"Sever the Dark Lord's Touch": {"ring": Enums.Ring.FIRE, "mastery": 5, "type": KihoType.MYSTICAL, "atemi": true, "kuni_reduce": true},
	"Unbalance the Mind":     {"ring": Enums.Ring.FIRE, "mastery": 5, "type": KihoType.MYSTICAL, "atemi": true, "atemi_effect": {"condition": "dazed"}},
	# -- WATER --
	"As the Breakers":        {"ring": Enums.Ring.WATER, "mastery": 4, "type": KihoType.KHARMIC, "atemi": true},
	"Buoyed by the Kami":     {"ring": Enums.Ring.WATER, "mastery": 3, "type": KihoType.MYSTICAL},
	"Chi Protection":         {"ring": Enums.Ring.WATER, "mastery": 4, "type": KihoType.MARTIAL, "atemi": true},
	"Dharma Technique":       {"ring": Enums.Ring.WATER, "mastery": 7, "type": KihoType.MARTIAL, "staff": true},
	"Freezing the Lifeblood": {"ring": Enums.Ring.WATER, "mastery": 7, "type": KihoType.MARTIAL, "atemi": true, "atemi_effect": {"condition": "stunned"}},
	"Musubi":                 {"ring": Enums.Ring.WATER, "mastery": 5, "type": KihoType.INTERNAL, "staff": true},
	"Partaking the Waters":   {"ring": Enums.Ring.WATER, "mastery": 6, "type": KihoType.INTERNAL, "effect_id": "kiho_partaking_waters_reduction"},
	"Ride the Water Dragon":  {"ring": Enums.Ring.WATER, "mastery": 3, "type": KihoType.KHARMIC},
	"Slap the Wave":          {"ring": Enums.Ring.WATER, "mastery": 7, "type": KihoType.MYSTICAL},
	"Tasaii-Do":              {"ring": Enums.Ring.WATER, "mastery": 6, "type": KihoType.MARTIAL, "staff": true, "atemi": true, "atemi_effect": {"condition": "stunned", "contest": {"attacker_ring": Enums.Ring.WATER, "defender_ring": Enums.Ring.EARTH}}},
	"Waves in All Things":    {"ring": Enums.Ring.WATER, "mastery": 4, "type": KihoType.MYSTICAL},
	# -- VOID --
	"Banish All Shadows":     {"ring": Enums.Ring.VOID, "mastery": 4, "type": KihoType.KHARMIC, "atemi": true},
	"Death Touch":            {"ring": Enums.Ring.VOID, "mastery": 7, "type": KihoType.MYSTICAL, "atemi": true},
	"Eight Directions Awareness": {"ring": Enums.Ring.VOID, "mastery": 5, "type": KihoType.MYSTICAL},
	"Knowledge from Within":  {"ring": Enums.Ring.VOID, "mastery": 4, "type": KihoType.INTERNAL},
	"Mind/No-Mind":           {"ring": Enums.Ring.VOID, "mastery": 6, "type": KihoType.MYSTICAL, "atemi": true, "atemi_effect": {"condition": "dazed", "contest": {"attacker_ring": Enums.Ring.VOID, "defender_ring": Enums.Ring.FIRE}}},
	"Rebuke of the Heavens":  {"ring": Enums.Ring.VOID, "mastery": 5, "type": KihoType.KHARMIC, "monks_only": true},
	"Sense the Balance":      {"ring": Enums.Ring.VOID, "mastery": 6, "type": KihoType.KHARMIC, "atemi": true},
	"Silent Solace":          {"ring": Enums.Ring.VOID, "mastery": 5, "type": KihoType.KHARMIC, "atemi": true},
	"Song of the World":      {"ring": Enums.Ring.VOID, "mastery": 3, "type": KihoType.KHARMIC},
	"Spin the Kharmic Wheel": {"ring": Enums.Ring.VOID, "mastery": 8, "type": KihoType.KHARMIC, "atemi": true},
	"Striking Through the Void": {"ring": Enums.Ring.VOID, "mastery": 7, "type": KihoType.MARTIAL},
	"Touch the Void Dragon":  {"ring": Enums.Ring.VOID, "mastery": 4, "type": KihoType.INTERNAL},
	"To the Last Breath":     {"ring": Enums.Ring.VOID, "mastery": 3, "type": KihoType.KHARMIC},
	"Void Fist":              {"ring": Enums.Ring.VOID, "mastery": 4, "type": KihoType.MARTIAL, "atemi": true},
	"The World Disappears":   {"ring": Enums.Ring.VOID, "mastery": 6, "type": KihoType.INTERNAL},
}


# === RING / PATH HELPERS =====================================================

static func _get_ring_rank(character: L5RCharacterData, ring: Enums.Ring) -> int:
	match ring:
		Enums.Ring.AIR:   return mini(character.reflexes, character.awareness)
		Enums.Ring.EARTH: return mini(character.stamina, character.willpower)
		Enums.Ring.FIRE:  return mini(character.agility, character.intelligence)
		Enums.Ring.WATER: return mini(character.strength, character.perception)
		Enums.Ring.VOID:  return character.void_ring
	return 0


static func _is_monk(character: L5RCharacterData) -> bool:
	return character.school_type == Enums.SchoolType.MONK


## A Brotherhood-affiliated monk (Brotherhood of Shinsei). Non-Brotherhood monks
## (e.g. Togashi Tattooed Order) have an empty brotherhood_sect.
static func _is_brotherhood_monk(character: L5RCharacterData) -> bool:
	return _is_monk(character) and character.brotherhood_sect != ""


## Cost multiplier for learning kiho (GDD s38). Monk-only: Brotherhood ×1,
## non-Brotherhood monk ×1.5.
static func cost_multiplier(character: L5RCharacterData) -> float:
	if _is_monk(character) and character.brotherhood_sect == "":
		return COST_MULT_NON_BROTHERHOOD_MONK
	return COST_MULT_BROTHERHOOD


# === ELIGIBILITY =============================================================

## True if the character meets a kiho's Mastery Level (GDD s38): a monk meets it
## if School Rank + relevant Ring ≥ Mastery. (Monk-only — s38a override.)
static func meets_mastery(character: L5RCharacterData, kiho_name: String) -> bool:
	if not KIHO_DATA.has(kiho_name):
		return false
	var kiho: Dictionary = KIHO_DATA[kiho_name]
	var ring_rank: int = _get_ring_rank(character, kiho["ring"])
	return (character.school_rank + ring_rank) >= int(kiho["mastery"])


## Knowledge cap (GDD s38): non-Brotherhood characters may know ≤ their school
## rank in kiho. Brotherhood monks are uncapped. Returns -1 when uncapped.
static func knowledge_cap(character: L5RCharacterData) -> int:
	if _is_brotherhood_monk(character):
		return -1
	return character.school_rank


static func at_knowledge_cap(character: L5RCharacterData) -> bool:
	var cap: int = knowledge_cap(character)
	return cap >= 0 and character.kiho.size() >= cap


## XP cost to learn a kiho (s38a): ceil(mastery × cost_multiplier). Base mastery
## cost mirrors the KataSystem convention (xp_cost = mastery).
static func learn_cost(character: L5RCharacterData, kiho_name: String) -> int:
	if not KIHO_DATA.has(kiho_name):
		return 0
	var base: int = KIHO_DATA[kiho_name]["mastery"]
	return int(ceil(base * cost_multiplier(character)))


## True if the character may learn `kiho_name` (ignores XP — see can_afford).
## MONK-ONLY (s38a override): only monk characters channel kiho.
static func can_learn(character: L5RCharacterData, kiho_name: String) -> bool:
	if not KIHO_DATA.has(kiho_name):
		return false
	if not _is_monk(character):
		return false
	if character.school.is_empty():
		return false
	# Already known?
	if character.kiho.has(kiho_name):
		return false
	# Knowledge cap for non-Brotherhood monks.
	if at_knowledge_cap(character):
		return false
	return meets_mastery(character, kiho_name)


static func can_afford(character: L5RCharacterData, kiho_name: String) -> bool:
	if not KIHO_DATA.has(kiho_name):
		return false
	var available: int = character.xp_total - character.xp_spent
	return available >= learn_cost(character, kiho_name)


# === ACQUISITION =============================================================

## Teaches `kiho_name` and deducts the XP cost. Returns true on success.
static func learn_kiho(character: L5RCharacterData, kiho_name: String) -> bool:
	if not can_learn(character, kiho_name):
		return false
	if not can_afford(character, kiho_name):
		return false
	character.xp_spent += learn_cost(character, kiho_name)
	character.kiho.append(kiho_name)
	return true


static func get_eligible_kiho(character: L5RCharacterData) -> Array:
	var result: Array = []
	for kiho_name: String in KIHO_DATA.keys():
		if can_learn(character, kiho_name):
			result.append(kiho_name)
	return result


# === NPC SELECTION ===========================================================

## Selects the best kiho for an NPC to learn this season: highest mastery that
## is eligible and affordable, alphabetical tie-break. "" if none.
static func select_kiho_for_npc(character: L5RCharacterData) -> String:
	var candidates: Array = []
	for kiho_name: String in KIHO_DATA.keys():
		if can_learn(character, kiho_name) and can_afford(character, kiho_name):
			candidates.append(kiho_name)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ma: int = KIHO_DATA[a]["mastery"]
		var mb: int = KIHO_DATA[b]["mastery"]
		if ma != mb:
			return ma > mb
		return a < b
	)
	return candidates[0]


# === ACTIVATION RULES ========================================================

## Activation options for a kiho (GDD s38). Void Point = Free Action (no roll);
## Meditation/Void roll TN 15 = Complex, TN 30 = Simple; atemi delivery is Free.
static func activation_options(kiho_name: String) -> Dictionary:
	if not KIHO_DATA.has(kiho_name):
		return {}
	var kiho: Dictionary = KIHO_DATA[kiho_name]
	return {
		"void_point_free": true,
		"meditation_tn_complex": ACTIVATION_TN_COMPLEX,
		"meditation_tn_simple": ACTIVATION_TN_SIMPLE,
		"is_atemi": kiho.get("atemi", false),
		"requires_staff": kiho.get("staff", false),
	}


## Validates the active-slot constraint (GDD s38): only one Internal, one Kharmic,
## and one Mystical kiho may be active at a time; multiple Martial may be active.
## `active_kiho` is the list of currently-active kiho names. Returns {ok, reason}.
static func can_activate(kiho_name: String, active_kiho: Array) -> Dictionary:
	if not KIHO_DATA.has(kiho_name):
		return {"ok": false, "reason": "unknown_kiho"}
	if kiho_name in active_kiho:
		return {"ok": false, "reason": "already_active"}
	var t: KihoType = KIHO_DATA[kiho_name]["type"]
	# Martial kiho have no single-slot limit.
	if t == KihoType.MARTIAL:
		return {"ok": true}
	for other: String in active_kiho:
		if not KIHO_DATA.has(other):
			continue
		if KIHO_DATA[other]["type"] == t:
			return {"ok": false, "reason": "slot_occupied"}
	return {"ok": true}


# === EFFECT REGISTRY (stub — combat effects deferred, mirrors KataSystem) =====

## Returns the effect stub for a kiho. No mechanical change is applied; combat
## effect wiring into the s40 layer is a separate pass.
static func get_effect_stub(kiho_name: String) -> Dictionary:
	if not KIHO_DATA.has(kiho_name):
		return {}
	var kiho: Dictionary = KIHO_DATA[kiho_name]
	return {
		"kiho": kiho_name,
		"ring": kiho["ring"],
		"type": kiho["type"],
		"atemi": kiho.get("atemi", false),
		"blocked_on": "s40_effects",
	}
