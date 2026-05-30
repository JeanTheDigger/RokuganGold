class_name IkebanaSystem
## Ikebana flower arrangement system per GDD s57.29.
## Performance IS creation IS display. Arrangements occupy the zone ikebana_slot
## (proxied to settlement level), generate visitor effects, and expire naturally.
## No new ActionIDs — uses PERFORM_FOR and PUBLIC_PERFORMANCE with
## Artisan: Ikebana as the _performance_skill.

# -- Lifespan by quality tier (s57.29.7) ----------------------------------------
# Keys: GiftGivingSystem.QualityTier values (NORMAL=1..LEGENDARY=5)
const LIFESPAN: Dictionary = {
	1: 7,   # Normal  — ~1 IC week
	2: 14,  # Fine    — ~2 IC weeks
	3: 21,  # Exceptional — ~3 IC weeks
	4: 30,  # Masterwork  — ~1 IC month
	5: 45,  # Legendary   — ~6 IC weeks
}

# -- Visitor disposition bonus by quality tier (s57.29.8) ------------------------
const VISITOR_BONUS: Dictionary = {
	1: 1,   # Normal
	2: 2,   # Fine
	3: 3,   # Exceptional
	4: 4,   # Masterwork
	5: 5,   # Legendary
}

# -- Duration of visitor temporary modifier: 4 IC months (s57.29.8) --------------
const VISITOR_BONUS_DURATION: int = 120  # 4 × 30-day months

# -- Glory ticking (s57.29.8) ---------------------------------------------------
const VISITORS_PER_GLORY_TICK: int = 5
const CREATOR_GLORY_PER_TICK: float = 0.1
const ZONE_LORD_GLORY_PER_TICK: float = 0.01

# -- Garden synergy Free Raises (s57.29.6) --------------------------------------
# Applied when materials_source (garden_id) is set. Keys are garden quality tier.
const GARDEN_FR_BONUS: Dictionary = {
	1: 0,   # Normal  garden → +0 FR
	2: 1,   # Fine    garden → +1 FR
	3: 1,   # Exceptional → +1 FR
	4: 2,   # Masterwork  → +2 FR
	5: 2,   # Legendary   → +2 FR
}

# -- Shrine/temple worship enhancement Free Raises (s57.29.9) -------------------
# Temporary bonus for PERFORM_WORSHIP at zones with displayed arrangements.
# Normal and Fine arrangements provide no worship bonus.
const WORSHIP_FR: Dictionary = {
	1: 0,   # Normal
	2: 0,   # Fine
	3: 1,   # Exceptional → +1 FR
	4: 1,   # Masterwork  → +1 FR
	5: 1,   # Legendary   → +1 FR
}

# -- Section 49 canonical price for gift appraisal (s57.29.14) -----------------
const IKEBANA_PRICE_BU: int = 2

# -- Urgency bonus for empty ikebana slot (s57.29.10) --------------------------
const URGENCY_SLOT_EMPTY_BONUS: int = 10

# -- Eligible settlement types for the ikebana_slot (s57.29.3) -----------------
# Castle/Shiro, court locations, Temple/Shinden, estate/private quarters.
# Zone subtype (private quarters, tea room) blocked on s57.36 zone data.
const ELIGIBLE_DISPLAY_TYPES: Array = [
	Enums.SettlementType.CASTLE,
	Enums.SettlementType.FAMILY_CASTLE,
	Enums.SettlementType.KEEP,
	Enums.SettlementType.CITY,
	Enums.SettlementType.TEMPLE,
	Enums.SettlementType.SHINDEN,
	Enums.SettlementType.MONASTERY,
]

# -- Seasonal flower material tables (s57.29.6a) --------------------------------
# Each entry: [name, rarity_tag] — rarity is flavour (Common/Uncommon/Rare).
const SPRING_MATERIALS: Array = [
	["Sakura", "Common"], ["Shidarezakura", "Uncommon"], ["Ume", "Common"],
	["Momo", "Common"], ["Fuji", "Uncommon"], ["Kakitsubata", "Common"],
	["Ayame", "Common"], ["Botan", "Uncommon"], ["Suisen", "Common"],
	["Rengyō", "Common"], ["Yanagi", "Common"], ["Tsubaki", "Common"],
]

const SUMMER_MATERIALS: Array = [
	["Hasu", "Uncommon"], ["Ajisai", "Common"], ["Asagao", "Common"],
	["Yuri", "Uncommon"], ["Himawari", "Common"], ["Hōsenka", "Common"],
	["Take", "Common"], ["Hōzuki", "Uncommon"], ["Ran", "Rare"],
]

const AUTUMN_MATERIALS: Array = [
	["Kiku", "Common"], ["Momiji", "Common"], ["Susuki", "Common"],
	["Hagi", "Common"], ["Nadeshiko", "Common"], ["Rindō", "Uncommon"],
	["Ominaeshi", "Common"], ["Kuzu", "Common"], ["Fujibakama", "Uncommon"],
]

const WINTER_MATERIALS: Array = [
	["Matsu", "Common"], ["Ume", "Common"], ["Tsubaki", "Common"],
	["Sazanka", "Common"], ["Nanten", "Common"], ["Fukujusō", "Uncommon"],
	["Suisen", "Common"], ["Sasa", "Common"],
]

# Personality-weighted material sets: virtue → preferred materials
# Per GDD s57.29.6a composition algorithm.
const PERSONALITY_LEAN_MATERIALS: Dictionary = {
	"Rei":    ["Botan", "Fuji", "Ran", "Kiku"],
	"Jin":    ["Nadeshiko", "Suisen", "Hagi"],
	"Ketsui": ["Matsu", "Ume", "Take"],
	"Ishi":   ["Sakura", "Himawari", "Momiji"],
}

# Canonical seasonal combinations (s57.29.6a)
const CANONICAL_WINTER_SHOCHIKUBAI: Array = ["Matsu", "Take", "Ume"]

# Vessel types by clan (flavour, weighted during description generation)
const VESSEL_BY_CLAN: Dictionary = {
	"Crane":   "celadon vessel",
	"Phoenix": "white porcelain vessel",
	"Dragon":  "dark stoneware vessel",
	"Lion":    "bronze vessel",
	"Scorpion": "lacquered vessel",
	"Crab":    "simple clay vessel",
	"Unicorn": "painted ceramic vessel",
}
const VESSEL_DEFAULT: String = "ceramic vessel"


static func quality_from_raises(raises: int) -> int:
	## Maps performance raises to quality tier (GiftGivingSystem.QualityTier).
	## Per GDD s57.29.4: 0→Normal, 1→Fine, 2→Exceptional, 3→Masterwork, 4+→Legendary.
	match raises:
		0: return GiftGivingSystem.QualityTier.NORMAL      # 1
		1: return GiftGivingSystem.QualityTier.FINE        # 2
		2: return GiftGivingSystem.QualityTier.EXCEPTIONAL # 3
		3: return GiftGivingSystem.QualityTier.MASTERWORK  # 4
		_: return GiftGivingSystem.QualityTier.LEGENDARY   # 5


static func default_lifespan(quality_tier: int) -> int:
	return LIFESPAN.get(quality_tier, 7)


static func visitor_bonus_for_quality(quality_tier: int) -> int:
	return VISITOR_BONUS.get(quality_tier, 1)


static func worship_fr_for_quality(quality_tier: int) -> int:
	return WORSHIP_FR.get(quality_tier, 0)


static func garden_fr_for_quality(garden_quality: int) -> int:
	return GARDEN_FR_BONUS.get(garden_quality, 0)


static func is_eligible_display_settlement(settlement: SettlementData) -> bool:
	return settlement.settlement_type in ELIGIBLE_DISPLAY_TYPES


static func is_shrine_eligible(settlement: SettlementData) -> bool:
	## True for shrine/temple display — qualifies as flower offering (s57.29.9).
	return settlement.settlement_type in Enums.RELIGIOUS_SETTLEMENT_TYPES


static func select_season_materials(
	season: int,
	artisan: L5RCharacterData,
	quality_tier: int,
	dice: DiceEngine,
) -> Array[String]:
	## Select 1–3 materials from the current season's table per GDD s57.29.6a.
	## Count by quality: Normal=1, Fine=1, Exceptional=2, Masterwork=3, Legendary=3.
	var count: int
	match quality_tier:
		1, 2: count = 1   # Normal, Fine
		3:    count = 2   # Exceptional
		_:    count = 3   # Masterwork, Legendary

	var pool: Array
	match season:
		TimeSystem.Season.SPRING: pool = SPRING_MATERIALS
		TimeSystem.Season.SUMMER: pool = SUMMER_MATERIALS
		TimeSystem.Season.AUTUMN: pool = AUTUMN_MATERIALS
		_:                        pool = WINTER_MATERIALS

	# Determine personality lean (s57.29.6a step 2)
	var preferred: Array[String] = []
	var virtue: String = artisan.bushido_virtue
	var shourido: String = artisan.shourido_virtue
	if virtue == "Rei" or shourido == "Rei":
		preferred = Array(PERSONALITY_LEAN_MATERIALS.get("Rei", []), TYPE_STRING, "", null)
	elif virtue == "Jin":
		preferred = Array(PERSONALITY_LEAN_MATERIALS.get("Jin", []), TYPE_STRING, "", null)
	elif shourido == "Ketsui":
		preferred = Array(PERSONALITY_LEAN_MATERIALS.get("Ketsui", []), TYPE_STRING, "", null)
	elif shourido == "Ishi" or shourido == "Ketsui":
		preferred = Array(PERSONALITY_LEAN_MATERIALS.get("Ishi", []), TYPE_STRING, "", null)

	# Build candidate list: preferred materials that are in season come first.
	var ordered: Array[String] = []
	for entry: Variant in pool:
		var mat_name: String = (entry as Array)[0]
		if mat_name in preferred:
			ordered.append(mat_name)
	for entry: Variant in pool:
		var mat_name: String = (entry as Array)[0]
		if mat_name not in ordered:
			ordered.append(mat_name)

	# Check for canonical winter shōchikubai combination
	if season == TimeSystem.Season.WINTER and quality_tier >= 3:
		var can_do_shochikubai: bool = true
		for m: String in CANONICAL_WINTER_SHOCHIKUBAI:
			if m not in ordered:
				can_do_shochikubai = false
				break
		if can_do_shochikubai and dice.rand_int_range(0, 99) < 40:
			var result: Array[String] = []
			result.assign(CANONICAL_WINTER_SHOCHIKUBAI)
			return result

	var chosen: Array[String] = []
	var idx: int = 0
	while chosen.size() < count and idx < ordered.size():
		if ordered[idx] not in chosen:
			chosen.append(ordered[idx])
		idx += 1

	return chosen


static func generate_composition_description(
	materials: Array[String],
	quality_tier: int,
	season: int,
	creator_clan: String,
) -> String:
	## Procedurally generate a short description of the arrangement (s57.29.2).
	var season_name: String
	match season:
		TimeSystem.Season.SPRING: season_name = "spring"
		TimeSystem.Season.SUMMER: season_name = "summer"
		TimeSystem.Season.AUTUMN: season_name = "autumn"
		_:                        season_name = "winter"

	var vessel: String = VESSEL_BY_CLAN.get(creator_clan, VESSEL_DEFAULT)

	var tier_phrase: String
	match quality_tier:
		1: tier_phrase = "a simple arrangement"
		2: tier_phrase = "a careful arrangement"
		3: tier_phrase = "an elegant arrangement"
		4: tier_phrase = "a masterful arrangement"
		_: tier_phrase = "an extraordinary arrangement"

	var mat_list: String = ", ".join(materials)
	if materials.size() == 1:
		return "%s of %s in a %s, evoking the essence of %s." % [
			tier_phrase, mat_list, vessel, season_name,
		]
	elif materials.size() == 2:
		return "%s of %s and %s in a %s, capturing the spirit of %s." % [
			tier_phrase, materials[0], materials[1], vessel, season_name,
		]
	else:
		# Check for shōchikubai
		var has_all_three: bool = (
			"Matsu" in materials and "Take" in materials and "Ume" in materials
		)
		if has_all_three:
			return (
				"A shōchikubai arrangement of pine (matsu), bamboo (take), and "
				"plum (ume) in a %s — the Three Friends of Winter, auspicious for the new year."
			) % vessel
		return "%s of %s in a %s, the composition speaking of %s." % [
			tier_phrase, mat_list, vessel, season_name,
		]


static func generate_initial_arrangements(
	characters: Array,
	settlements: Array,
	dice: DiceEngine,
	next_id: Array,
	ic_day: int,
) -> Array[IkebanaArrangementData]:
	## Seed world-start arrangements per GDD s57.29.11.
	## Major courts with ikebana artisans get a living arrangement whose lifespan
	## is a random portion of the quality max (arrangement was made before game start).

	var result: Array[IkebanaArrangementData] = []

	# Build settlement → characters at that location map
	var chars_at: Dictionary = {}
	for c_v: Variant in characters:
		var c: L5RCharacterData = c_v as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		var loc: String = c.physical_location
		if loc.is_empty():
			continue
		if not chars_at.has(loc):
			chars_at[loc] = []
		chars_at[loc].append(c)

	for s_v: Variant in settlements:
		var s: SettlementData = s_v as SettlementData
		if s == null:
			continue
		if not is_eligible_display_settlement(s):
			continue

		var sid: String = str(s.settlement_id)
		var present: Array = chars_at.get(sid, [])

		# Find best ikebana artisan at this settlement
		var best_artisan: L5RCharacterData = null
		var best_rank: int = 0
		for char_v: Variant in present:
			var char: L5RCharacterData = char_v as L5RCharacterData
			if char == null:
				continue
			var rank: int = char.skills.get("Artisan: Ikebana", 0)
			if rank > best_rank:
				best_rank = rank
				best_artisan = char

		if best_artisan == null or best_rank < 1:
			continue  # No artisan present — slot empty

		# Quality based on settlement type and artisan skill
		var quality: int = _world_start_quality(s, best_artisan)

		var lifespan_max: int = default_lifespan(quality)
		var lifespan_start: int = dice.rand_int_range(1, lifespan_max)

		var current_season: int = TimeSystem.Season.SPRING  # World starts at Spring
		var materials: Array[String] = select_season_materials(
			current_season, best_artisan, quality, dice,
		)
		var description: String = generate_composition_description(
			materials, quality, current_season, best_artisan.clan,
		)

		var arr: IkebanaArrangementData = IkebanaArrangementData.new()
		arr.arrangement_id = next_id[0]
		next_id[0] += 1
		arr.creator_id = best_artisan.character_id
		arr.quality_tier = quality
		arr.season_created = current_season
		arr.date_created = ic_day
		arr.lifespan_remaining = lifespan_start
		arr.display_settlement_id = sid
		arr.is_shrine_offering = is_shrine_eligible(s)
		arr.composition_materials = materials
		arr.composition_description = description

		result.append(arr)

	return result


static func _world_start_quality(
	settlement: SettlementData,
	artisan: L5RCharacterData,
) -> int:
	## Determine world-start arrangement quality per GDD s57.29.11 guidance.
	## Imperial Court → Masterwork; Crane Family Castle → Exceptional/Masterwork;
	## other major courts with artisans → Fine/Exceptional.
	var rank: int = artisan.skills.get("Artisan: Ikebana", 0)
	if settlement.settlement_type == Enums.SettlementType.FAMILY_CASTLE:
		if artisan.clan == "Crane":
			return GiftGivingSystem.QualityTier.MASTERWORK if rank >= 5 else GiftGivingSystem.QualityTier.EXCEPTIONAL
		return GiftGivingSystem.QualityTier.EXCEPTIONAL if rank >= 4 else GiftGivingSystem.QualityTier.FINE
	# Provincial/regional courts: Fine to Exceptional
	if rank >= 4:
		return GiftGivingSystem.QualityTier.EXCEPTIONAL
	if rank >= 2:
		return GiftGivingSystem.QualityTier.FINE
	return GiftGivingSystem.QualityTier.NORMAL
