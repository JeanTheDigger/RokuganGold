class_name OniGenerator
## Procedural Oni generation per GDD s2.4.8 — LOCKED.
## Pure static functions — caller owns all OniData.


# -- Step 1: Size (s2.4.8 — LOCKED) -------------------------------------------

## Size probabilities: rolled uniformly 1d10. Adjust thresholds for lore rarity.
## GDD gives no explicit size probability — using equal-weight d4 roll.
## Small=1-3, Medium=4-6, Large=7-9, Massive=10 (approximate; GDD defers to GM).
const SIZE_TABLE: Dictionary = {
	1: Enums.OniSize.SMALL,
	2: Enums.OniSize.SMALL,
	3: Enums.OniSize.SMALL,
	4: Enums.OniSize.MEDIUM,
	5: Enums.OniSize.MEDIUM,
	6: Enums.OniSize.MEDIUM,
	7: Enums.OniSize.LARGE,
	8: Enums.OniSize.LARGE,
	9: Enums.OniSize.LARGE,
	10: Enums.OniSize.MASSIVE,
}

## Ring budgets per size (s2.4.8 Step 1 — LOCKED).
const RING_BUDGET: Dictionary = {
	Enums.OniSize.SMALL: 9,
	Enums.OniSize.MEDIUM: 12,
	Enums.OniSize.LARGE: 15,
	Enums.OniSize.MASSIVE: 19,
}

## Mass Battle Health per size (s2.4.8 Mass Battle translation — LOCKED).
const MB_HEALTH: Dictionary = {
	Enums.OniSize.SMALL: 50,
	Enums.OniSize.MEDIUM: 100,
	Enums.OniSize.LARGE: 175,
	Enums.OniSize.MASSIVE: 300,
}

## Mass Battle Attack size floors (s2.4.8 Mass Battle translation — LOCKED).
const MB_ATTACK_FLOOR: Dictionary = {
	Enums.OniSize.SMALL: 5,
	Enums.OniSize.MEDIUM: 7,
	Enums.OniSize.LARGE: 9,
	Enums.OniSize.MASSIVE: 11,
}

## Fear rating per size (s2.4.8 Pool 1 — LOCKED).
const FEAR_RATING: Dictionary = {
	Enums.OniSize.SMALL: 1,
	Enums.OniSize.MEDIUM: 2,
	Enums.OniSize.LARGE: 3,
	Enums.OniSize.MASSIVE: 5,
}


# -- Step 2: Body Form (s2.4.8 — LOCKED) --------------------------------------

## 7 base forms (WINGED is a secondary flag — see generate()).
## Probability spread: 6 base forms equally likely, WINGED is a 20% additive flag.
const BODY_FORM_COUNT: int = 6  # HUMANOID through INSECTOID


# -- Step 3: Dominant Ring Budget Distribution (s2.4.8 — LOCKED) ---------------

## Dominant Ring receives 35–45% of budget (rounded).
## Min per non-dominant Ring: 1. Max per non-dominant: dominant_value - 1.
## Void never allocated.

const DOMINANT_RING_FRACTION_MIN: float = 0.35
const DOMINANT_RING_FRACTION_MAX: float = 0.45

## Available dominant rings (no Void per s2.4.8 — LOCKED).
const DOMINANT_RINGS: Array = [
	Enums.Ring.EARTH,
	Enums.Ring.WATER,
	Enums.Ring.FIRE,
	Enums.Ring.AIR,
]


# -- Step 5: Special Ability Pools (s2.4.8 — LOCKED) --------------------------

## Pool 2 — Invulnerability (one rolled randomly from 5 options).
const POOL_2_OPTIONS: Array = [
	Enums.OniInvulnerability.ARROW_IMMUNITY,
	Enums.OniInvulnerability.BLADE_IMMUNITY,
	Enums.OniInvulnerability.FIRE_IMMUNITY,
	Enums.OniInvulnerability.SPELL_IMMUNITY,
	Enums.OniInvulnerability.POISON_IMMUNITY,
]

## Pool 3 — Special Attack (rarity weighted: Common=40%, Uncommon=20%, Rare=7%).
## 6 entries with cumulative d100 thresholds.
const POOL_3_THRESHOLDS: Array = [
	{"max": 40, "ability": Enums.OniSpecialAttack.BREATH_WEAPON},    # Common 40%
	{"max": 80, "ability": Enums.OniSpecialAttack.CRUSHING_GRIP},    # Common 40%
	{"max": 90, "ability": Enums.OniSpecialAttack.TAINT_SPIT},       # Uncommon 10%
	{"max": 94, "ability": Enums.OniSpecialAttack.REGENERATION},     # Uncommon 4%
	{"max": 97, "ability": Enums.OniSpecialAttack.SPAWN},            # Rare 3%
	{"max": 100, "ability": Enums.OniSpecialAttack.TAINT_AURA},      # Rare 3%
]


# -- Step 6: Weakness (s2.4.8 — LOCKED) ----------------------------------------

## 7 weaknesses, equally weighted (d7).
const WEAKNESS_COUNT: int = 7

## Weapon types for SPECIFIC_WEAPON_TYPE weakness.
const WEAPON_TYPES: Array[String] = [
	"spears", "bows", "no-dachi", "katana", "kama", "naginata",
]

## Spell schools for SPECIFIC_SPELL_SCHOOL weakness.
const SPELL_SCHOOLS: Array[String] = [
	"Water", "Fire", "Air", "Earth", "Void",
]

## Named individual types for NAMED_INDIVIDUAL weakness.
const NAMED_INDIVIDUAL_TYPES: Array[String] = [
	"Kuni Witch Hunter", "Hida Bushi", "Kaiu Engineer",
	"Hiruma Scout", "Crab Clan Champion",
]


# -- Generation -----------------------------------------------------------------

static func generate(dice: DiceEngine, ic_day: int) -> OniData:
	var oni := OniData.new()
	oni.ic_day_generated = ic_day

	# Step 1 — Size.
	var size_roll: int = clampi(dice.roll_and_keep(1, 1, 0).total % 10 + 1, 1, 10)
	oni.size = SIZE_TABLE.get(size_roll, Enums.OniSize.SMALL)

	# Step 2 — Body Form.
	var form_roll: int = dice.roll_and_keep(1, 1, 0).total % BODY_FORM_COUNT
	oni.body_form = form_roll  # Maps directly to OniBodyForm enum values 0–5.
	# Winged: 20% additive flag on any base form.
	oni.is_winged = (dice.roll_and_keep(1, 1, 0).total % 5) == 0

	# Step 3 — Dominant Ring.
	var dom_idx: int = dice.roll_and_keep(1, 1, 0).total % DOMINANT_RINGS.size()
	var dominant_ring: int = DOMINANT_RINGS[dom_idx]
	oni.dominant_ring = dominant_ring

	# Step 3 — Ring Budget Distribution.
	var budget: int = RING_BUDGET.get(oni.size, 9)
	# Fraction: 35–45% of budget (11-point range mapped from d11 mod).
	var frac_pct: int = dice.roll_and_keep(1, 1, 0).total % 11  # 0–10
	var frac: float = DOMINANT_RING_FRACTION_MIN + float(frac_pct) * 0.01
	var dominant_value: int = maxi(1, roundi(budget * frac))
	dominant_value = clampi(dominant_value, 1, budget - 3)

	# Distribute remainder across the other 3 rings (each ≥ 1, < dominant).
	var remaining: int = budget - dominant_value
	var other_rings: Array[int] = []
	for r: int in DOMINANT_RINGS:
		if r != dominant_ring:
			other_rings.append(r)

	var ring_values: Dictionary = {}
	ring_values[dominant_ring] = dominant_value

	# Give each non-dominant ring at least 1 point.
	for r: int in other_rings:
		ring_values[r] = 1
		remaining -= 1

	# Distribute remainder randomly across non-dominant rings within cap.
	for _i: int in range(remaining):
		var cands: Array[int] = []
		for r: int in other_rings:
			if ring_values[r] < dominant_value - 1:
				cands.append(r)
		if cands.is_empty():
			break
		var pick_idx: int = dice.roll_and_keep(1, 1, 0).total % cands.size()
		ring_values[cands[pick_idx]] += 1

	ring_values[Enums.Ring.VOID] = 0
	oni.rings = ring_values

	# Step 4 — Derived Stats (Mass Battle translation — LOCKED).
	oni.mb_health = MB_HEALTH.get(oni.size, 50)
	var fire_val: int = int(ring_values.get(Enums.Ring.FIRE, 1))
	var earth_val: int = int(ring_values.get(Enums.Ring.EARTH, 1))
	var air_val: int = int(ring_values.get(Enums.Ring.AIR, 1))
	oni.mb_attack = MB_ATTACK_FLOOR.get(oni.size, 5) + fire_val
	oni.mb_defense = earth_val + air_val

	# Individual combat derived stats.
	oni.wounds = earth_val * 16
	oni.armor_tn = air_val * 5
	oni.reduction = earth_val * 4

	# Step 5 — Pool 1: Fear (always present, scales with size — LOCKED).
	oni.fear_rating = FEAR_RATING.get(oni.size, 1)

	# Step 5 — Pool 2: Invulnerability (one random from 5).
	var p2_roll: int = dice.roll_and_keep(1, 1, 0).total % POOL_2_OPTIONS.size()
	oni.invulnerability = POOL_2_OPTIONS[p2_roll]
	if oni.invulnerability == Enums.OniInvulnerability.SPELL_IMMUNITY:
		# 1d3 spells immune (1–3).
		oni.spell_immunity_count = (dice.roll_and_keep(1, 1, 0).total % 3) + 1

	# Step 5 — Pool 3: Special Attack (rarity weighted d100).
	var p3_roll: int = (dice.roll_and_keep(1, 1, 0).total % 100) + 1
	for entry: Dictionary in POOL_3_THRESHOLDS:
		if p3_roll <= int(entry["max"]):
			oni.special_attack = int(entry["ability"])
			break

	# Step 6 — Weakness (specific, procedurally generated — LOCKED).
	# Jade/crystal/obsidian immunity halving is universal and not stored (always applies).
	var w_roll: int = dice.roll_and_keep(1, 1, 0).total % WEAKNESS_COUNT
	oni.specific_weakness = w_roll  # Maps directly to OniWeakness enum values 0–6.
	_populate_weakness_detail(oni, dice)

	return oni


static func _populate_weakness_detail(oni: OniData, dice: DiceEngine) -> void:
	match oni.specific_weakness:
		Enums.OniWeakness.SPECIFIC_WEAPON_TYPE:
			oni.weakness_weapon_type = WEAPON_TYPES[
				dice.roll_and_keep(1, 1, 0).total % WEAPON_TYPES.size()
			]
		Enums.OniWeakness.SPECIFIC_SPELL_SCHOOL:
			oni.weakness_spell_school = SPELL_SCHOOLS[
				dice.roll_and_keep(1, 1, 0).total % SPELL_SCHOOLS.size()
			]
		Enums.OniWeakness.NAMED_INDIVIDUAL:
			oni.weakness_named_type = NAMED_INDIVIDUAL_TYPES[
				dice.roll_and_keep(1, 1, 0).total % NAMED_INDIVIDUAL_TYPES.size()
			]


# -- Mass Battle Stats Helper --------------------------------------------------

## Returns the Mass Battle stat block for a generated Oni
## (suitable for grid combat resolution).
static func get_mb_stats(oni: OniData) -> Dictionary:
	return {
		"unit_type": "oni",
		"health": oni.mb_health,
		"current_health": oni.mb_health,
		"attack": oni.mb_attack,
		"defense": oni.mb_defense,
		"morale": -1,         # Oni cannot rout per s2.4.8 LOCKED.
		"morale_defense": -1,
		"no_morale": true,
		"is_winged": oni.is_winged,
		"fear_rating": oni.fear_rating,
		"special_attack": oni.special_attack,
		"invulnerability": oni.invulnerability,
		"size": oni.size,
		"body_form": oni.body_form,
	}
