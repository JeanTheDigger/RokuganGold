class_name KihoSystem
## Kiho eligibility, acquisition, activation rules, and stub effect registry.
## GDD s38 (catalog & rules) + s38a (locked values). Pure simulation class —
## no Node inheritance.
##
## Kiho fall between spells and bushi Techniques — elemental abilities of the
## Brotherhood of Shinsei. This system covers learning, eligibility, the cost
## multiplier and knowledge cap for non-Brotherhood characters, the activation
## rules, and the active-slot constraint. Per-kiho COMBAT EFFECTS are deferred
## (stub registry), mirroring KataSystem — wiring ~73 distinct effects into the
## s40 layer is a separate pass.

enum KihoType { INTERNAL, KHARMIC, MARTIAL, MYSTICAL }

# Activation roll TNs (GDD s38): Meditation/Void roll, TN 15 = Complex Action,
# TN 30 = Simple Action. A Void Point activates as a Free Action (no roll).
const ACTIVATION_TN_COMPLEX: int = 15
const ACTIVATION_TN_SIMPLE: int = 30

# Cost multipliers (GDD s38): non-Brotherhood monks pay 1.5×, shugenja pay 2×.
const COST_MULT_BROTHERHOOD: float = 1.0
const COST_MULT_NON_BROTHERHOOD_MONK: float = 1.5
const COST_MULT_SHUGENJA: float = 2.0

# Catalog (GDD s38). Each entry: ring, mastery, type, atemi, staff, optional flags.
const KIHO_DATA: Dictionary = {
	# -- AIR --
	"Air Fist":               {"ring": Enums.Ring.AIR, "mastery": 3, "type": KihoType.INTERNAL},
	"Calling the East Wind":  {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.MARTIAL},
	"Censure of Thunder":     {"ring": Enums.Ring.AIR, "mastery": 7, "type": KihoType.MARTIAL, "atemi": true},
	"Eye of the Eagle":       {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.INTERNAL},
	"Flee the Darkness":      {"ring": Enums.Ring.AIR, "mastery": 6, "type": KihoType.KHARMIC},
	"The Great Silence":      {"ring": Enums.Ring.AIR, "mastery": 4, "type": KihoType.MYSTICAL, "atemi": true},
	"Harmony of the Mind":    {"ring": Enums.Ring.AIR, "mastery": 5, "type": KihoType.MYSTICAL},
	"Hurricane Palm":         {"ring": Enums.Ring.AIR, "mastery": 7, "type": KihoType.MARTIAL},
	"Inari's Wrath":          {"ring": Enums.Ring.AIR, "mastery": 8, "type": KihoType.MYSTICAL},
	"Riding the Clouds":      {"ring": Enums.Ring.AIR, "mastery": 3, "type": KihoType.MYSTICAL},
	"Soul of the Four Winds": {"ring": Enums.Ring.AIR, "mastery": 4, "type": KihoType.INTERNAL},
	"Stain Upon the Soul":    {"ring": Enums.Ring.AIR, "mastery": 3, "type": KihoType.MARTIAL, "atemi": true},
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
	"Embrace the Stone":      {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.MYSTICAL},
	"Grasp the Earth Dragon": {"ring": Enums.Ring.EARTH, "mastery": 5, "type": KihoType.INTERNAL},
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
	"Flame Fist":             {"ring": Enums.Ring.FIRE, "mastery": 3, "type": KihoType.MARTIAL, "atemi": true},
	"The Mind's Fire":        {"ring": Enums.Ring.FIRE, "mastery": 4, "type": KihoType.INTERNAL},
	"Seven Storm's Fist":     {"ring": Enums.Ring.FIRE, "mastery": 6, "type": KihoType.MARTIAL, "atemi": true},
	"Sever the Dark Lord's Touch": {"ring": Enums.Ring.FIRE, "mastery": 5, "type": KihoType.MYSTICAL, "atemi": true, "kuni_reduce": true},
	"Unbalance the Mind":     {"ring": Enums.Ring.FIRE, "mastery": 5, "type": KihoType.MYSTICAL, "atemi": true},
	# -- WATER --
	"As the Breakers":        {"ring": Enums.Ring.WATER, "mastery": 4, "type": KihoType.KHARMIC, "atemi": true},
	"Buoyed by the Kami":     {"ring": Enums.Ring.WATER, "mastery": 3, "type": KihoType.MYSTICAL},
	"Chi Protection":         {"ring": Enums.Ring.WATER, "mastery": 4, "type": KihoType.MARTIAL, "atemi": true},
	"Dharma Technique":       {"ring": Enums.Ring.WATER, "mastery": 7, "type": KihoType.MARTIAL, "staff": true},
	"Freezing the Lifeblood": {"ring": Enums.Ring.WATER, "mastery": 7, "type": KihoType.MARTIAL, "atemi": true},
	"Musubi":                 {"ring": Enums.Ring.WATER, "mastery": 5, "type": KihoType.INTERNAL, "staff": true},
	"Partaking the Waters":   {"ring": Enums.Ring.WATER, "mastery": 6, "type": KihoType.INTERNAL},
	"Ride the Water Dragon":  {"ring": Enums.Ring.WATER, "mastery": 3, "type": KihoType.KHARMIC},
	"Slap the Wave":          {"ring": Enums.Ring.WATER, "mastery": 7, "type": KihoType.MYSTICAL},
	"Tasaii-Do":              {"ring": Enums.Ring.WATER, "mastery": 6, "type": KihoType.MARTIAL, "staff": true, "atemi": true},
	"Waves in All Things":    {"ring": Enums.Ring.WATER, "mastery": 4, "type": KihoType.MYSTICAL},
	# -- VOID --
	"Banish All Shadows":     {"ring": Enums.Ring.VOID, "mastery": 4, "type": KihoType.KHARMIC, "atemi": true},
	"Death Touch":            {"ring": Enums.Ring.VOID, "mastery": 7, "type": KihoType.MYSTICAL, "atemi": true},
	"Eight Directions Awareness": {"ring": Enums.Ring.VOID, "mastery": 5, "type": KihoType.MYSTICAL},
	"Knowledge from Within":  {"ring": Enums.Ring.VOID, "mastery": 4, "type": KihoType.INTERNAL},
	"Mind/No-Mind":           {"ring": Enums.Ring.VOID, "mastery": 6, "type": KihoType.MYSTICAL, "atemi": true},
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


static func _is_shugenja(character: L5RCharacterData) -> bool:
	return character.school_type == Enums.SchoolType.SHUGENJA


## A Brotherhood-affiliated monk (Brotherhood of Shinsei). Non-Brotherhood monks
## (e.g. Togashi Tattooed Order) have an empty brotherhood_sect.
static func _is_brotherhood_monk(character: L5RCharacterData) -> bool:
	return _is_monk(character) and character.brotherhood_sect != ""


static func _is_kuni(character: L5RCharacterData) -> bool:
	if character.school_name in ["Kuni Shugenja", "Kuni Witch-Hunter"]:
		return true
	for path: String in character.school_paths:
		if path in ["Kuni Shugenja", "Kuni Witch-Hunter"]:
			return true
	return false


## Cost multiplier for learning kiho (GDD s38).
static func cost_multiplier(character: L5RCharacterData) -> float:
	if _is_shugenja(character):
		return COST_MULT_SHUGENJA
	if _is_monk(character) and character.brotherhood_sect == "":
		return COST_MULT_NON_BROTHERHOOD_MONK
	return COST_MULT_BROTHERHOOD


# === ELIGIBILITY =============================================================

## Effective mastery requirement (applies Kuni −1 for Sever the Dark Lord's Touch).
static func _effective_mastery(character: L5RCharacterData, kiho: Dictionary) -> int:
	var mastery: int = kiho["mastery"]
	if kiho.get("kuni_reduce", false) and _is_kuni(character):
		return maxi(1, mastery - 1)
	return mastery


## True if the character meets a kiho's Mastery Level (GDD s38): a monk meets it
## if School Rank + relevant Ring ≥ Mastery; a shugenja uses Ring only.
static func meets_mastery(character: L5RCharacterData, kiho_name: String) -> bool:
	if not KIHO_DATA.has(kiho_name):
		return false
	var kiho: Dictionary = KIHO_DATA[kiho_name]
	var ring_rank: int = _get_ring_rank(character, kiho["ring"])
	var req: int = _effective_mastery(character, kiho)
	if _is_shugenja(character):
		return ring_rank >= req
	return (character.school_rank + ring_rank) >= req


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
static func can_learn(character: L5RCharacterData, kiho_name: String) -> bool:
	if not KIHO_DATA.has(kiho_name):
		return false
	# Only monks and shugenja channel kiho, and only with a real school.
	if not (_is_monk(character) or _is_shugenja(character)):
		return false
	if character.school_name.is_empty():
		return false
	# Already known?
	if character.kiho.has(kiho_name):
		return false
	# Monks-only kiho (Rebuke of the Heavens) — shugenja cannot learn.
	if KIHO_DATA[kiho_name].get("monks_only", false) and not _is_monk(character):
		return false
	# Knowledge cap for non-Brotherhood characters.
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
