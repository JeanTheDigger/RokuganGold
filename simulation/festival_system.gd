class_name FestivalSystem
## Festival System per GDD s11.5.
## Empire-wide canonical festivals, Rokuyo cycle, championship resolution,
## and local settlement festival generation.


# -- Rokuyo Cycle -------------------------------------------------------------

enum Rokuyo {
	SENSHO,
	TOMOBIKI,
	SENBU,
	BUTSUMETSU,
	TAIAN,
	SHAKKO,
}

const ROKUYO_NAMES: Dictionary = {
	Rokuyo.SENSHO: "Sensho",
	Rokuyo.TOMOBIKI: "Tomobiki",
	Rokuyo.SENBU: "Senbu",
	Rokuyo.BUTSUMETSU: "Butsumetsu",
	Rokuyo.TAIAN: "Taian",
	Rokuyo.SHAKKO: "Shakko",
}

static func get_rokuyo(ic_day: int) -> Rokuyo:
	return ((ic_day - 1) % 6) as Rokuyo

static func get_rokuyo_name(ic_day: int) -> String:
	return ROKUYO_NAMES.get(get_rokuyo(ic_day), "Unknown")

static func get_taian_bonus(ic_day: int) -> int:
	return 1 if get_rokuyo(ic_day) == Rokuyo.TAIAN else 0

static func is_inauspicious_for_social(ic_day: int) -> bool:
	var r: Rokuyo = get_rokuyo(ic_day)
	return r == Rokuyo.BUTSUMETSU or r == Rokuyo.TOMOBIKI


# -- Calendar Helpers ---------------------------------------------------------

static func get_month(ic_day: int) -> int:
	return ((ic_day - 1) % 360) / 30 + 1

static func get_day_of_month(ic_day: int) -> int:
	return ((ic_day - 1) % 360) % 30 + 1

static func get_season(ic_day: int) -> int:
	var day_of_year: int = (ic_day - 1) % 360
	if day_of_year < 90:
		return 0  # Spring
	elif day_of_year < 180:
		return 1  # Summer
	elif day_of_year < 240:
		return 2  # Autumn
	return 3  # Winter


# -- Empire-Wide Canonical Festivals ------------------------------------------

const CANONICAL_FESTIVALS: Array[Dictionary] = [
	{"name": "New Year's Festival", "month": 1, "day": 1, "effects": ["stability_bonus"]},
	{"name": "Cherry Blossom Festival", "month": 1, "day": 15, "effects": ["planting_blessing"]},
	{"name": "Festival of Leaves", "month": 1, "day": 10, "effects": ["poetry_exchange"]},
	{"name": "Festival of Akodo", "month": 1, "day": 20, "effects": ["lion_honor"]},
	{"name": "Holi", "month": 2, "day": 15, "effects": ["informal_court"]},
	{"name": "Devil Chase", "month": 1, "day": 5, "effects": ["taint_assessment"]},
	{"name": "Iris Festival", "month": 3, "day": 25, "effects": ["gift_giving", "morale_bonus"]},
	{"name": "Spring Patrols", "month": 1, "day": 25, "effects": ["military_activation"]},
	{"name": "Tilling of the Fields", "month": 1, "day": 28, "effects": ["planting_tick"]},
	{"name": "Festival of the Sea Dragon", "month": 3, "day": 10, "effects": ["trade_bonus"]},
	{"name": "Chrysanthemum Festival", "month": 4, "day": 6, "effects": ["labor_halt"]},
	{"name": "Lotus Blossoms", "month": 4, "day": 1, "effects": ["poetry_exchange"]},
	{"name": "Ning Panchiman", "month": 4, "day": 15, "effects": ["duel_honor", "martial_glory"]},
	{"name": "Day of Remembrance", "month": 5, "day": 10, "effects": ["crab_honor"]},
	{"name": "Baisakh", "month": 5, "day": 20, "effects": ["stability_bonus"]},
	{"name": "Kanto Festival", "month": 7, "day": 2, "effects": ["production_bonus"]},
	{"name": "Setsuban Festival", "month": 6, "day": 8, "effects": ["ceasefire"]},
	{"name": "Bon Festival", "month": 8, "day": 28, "effects": ["ancestor_worship", "honor_gain"]},
	{"name": "Pearl Harvest", "month": 8, "day": 15, "effects": ["trade_bonus"]},
	{"name": "Bayushi's Tears", "month": 7, "day": 15, "effects": ["scorpion_disposition"]},
	{"name": "Viper Festival", "month": 3, "day": 20, "effects": ["scorpion_event"]},
	{"name": "Festival of the River of Stars", "month": 11, "day": 9, "effects": ["marriage_bonus"]},
	{"name": "New Year's Eve", "month": 12, "day": 28, "effects": ["wp_reset"]},
]

static func get_active_festivals(ic_day: int) -> Array[Dictionary]:
	var month: int = get_month(ic_day)
	var day: int = get_day_of_month(ic_day)
	var active: Array[Dictionary] = []
	for fest in CANONICAL_FESTIVALS:
		if fest["month"] == month and fest["day"] == day:
			active.append(fest)
	return active

static func is_ceasefire_day(ic_day: int) -> bool:
	for fest in get_active_festivals(ic_day):
		if "ceasefire" in fest.get("effects", []):
			return true
	return false

static func is_labor_halt_day(ic_day: int) -> bool:
	var month: int = get_month(ic_day)
	var day: int = get_day_of_month(ic_day)
	return month == 4 and day >= 6 and day <= 12

static func is_marriage_bonus_day(ic_day: int) -> bool:
	return get_month(ic_day) == 11 and get_day_of_month(ic_day) == 9


# -- Festival Effects ---------------------------------------------------------

static func get_festival_effects(ic_day: int) -> Array[String]:
	var effects: Array[String] = []
	for fest in get_active_festivals(ic_day):
		for e in fest.get("effects", []):
			if not effects.has(e):
				effects.append(e)
	return effects

static func get_honor_gain_festivals(ic_day: int) -> float:
	var gain: float = 0.0
	for fest in get_active_festivals(ic_day):
		if "honor_gain" in fest.get("effects", []):
			gain += 0.1
	return gain

static func get_glory_gain_festivals(ic_day: int) -> float:
	var gain: float = 0.0
	for fest in get_active_festivals(ic_day):
		if "martial_glory" in fest.get("effects", []) or "poetry_exchange" in fest.get("effects", []):
			gain += 0.1
	return gain


# -- Championship System ------------------------------------------------------

enum ChampionshipType {
	EMERALD,
	JADE,
	AMETHYST,
	RUBY,
	TURQUOISE,
	TOPAZ,
}

const CHAMPIONSHIP_STAGES: Dictionary = {
	ChampionshipType.EMERALD: [
		{"skill": "Iaijutsu", "trait": "reflexes"},
		{"skill": "Battle", "trait": "perception"},
		{"skill": "Courtier", "trait": "awareness"},
	],
	ChampionshipType.JADE: [
		{"skill": "Spellcraft", "trait": "intelligence"},
		{"skill": "Lore: Theology", "trait": "intelligence"},
		{"skill": "elemental_ring", "trait": "highest_ring"},
	],
	ChampionshipType.AMETHYST: [
		{"skill": "Courtier", "trait": "awareness"},
		{"skill": "Etiquette", "trait": "awareness"},
		{"skill": "Lore: History", "trait": "intelligence"},
	],
	ChampionshipType.RUBY: [
		{"skill": "Kenjutsu", "trait": "agility"},
		{"skill": "Battle", "trait": "perception"},
		{"skill": "Lore: War", "trait": "intelligence"},
	],
	ChampionshipType.TURQUOISE: [
		{"skill": "Artisan", "trait": "awareness"},
		{"skill": "Etiquette", "trait": "awareness"},
		{"skill": "Performance", "trait": "awareness"},
	],
	ChampionshipType.TOPAZ: [
		{"skill": "Athletics", "trait": "strength"},
		{"skill": "Kenjutsu", "trait": "agility"},
		{"skill": "Etiquette", "trait": "intelligence"},
	],
}

const CHAMPIONSHIP_SCHOOL_PREFERENCE: Dictionary = {
	ChampionshipType.EMERALD: Enums.SchoolType.BUSHI,
	ChampionshipType.JADE: Enums.SchoolType.SHUGENJA,
	ChampionshipType.RUBY: Enums.SchoolType.BUSHI,
	ChampionshipType.TURQUOISE: Enums.SchoolType.ARTISAN,
}

const ANNUAL_CHAMPIONSHIPS: Array[ChampionshipType] = [ChampionshipType.TOPAZ]

static func is_vacancy_triggered(championship: ChampionshipType) -> bool:
	return championship not in ANNUAL_CHAMPIONSHIPS

static func resolve_championship(
	candidates: Array[Dictionary],
	dice: Object,
) -> Dictionary:
	if candidates.is_empty():
		return {}

	var championship_type: ChampionshipType = candidates[0].get("championship", ChampionshipType.TOPAZ) as ChampionshipType
	var stages: Array = CHAMPIONSHIP_STAGES.get(championship_type, [])
	if stages.is_empty():
		return {}

	var best_id: int = -1
	var best_total: int = -1
	var best_honor: float = 0.0

	for candidate in candidates:
		var total: int = 0
		for stage in stages:
			var skill_rank: int = candidate.get("skill_ranks", {}).get(stage["skill"], 0)
			var trait_val: int = candidate.get("traits", {}).get(stage["trait"], 2)
			var roll_k: int = mini(skill_rank + trait_val, 10)
			var keep: int = trait_val
			total += roll_k * 5 + keep * 3

		candidate["total_score"] = total
		var honor: float = candidate.get("honor", 0.0)

		if total > best_total or (total == best_total and honor > best_honor):
			best_total = total
			best_id = candidate.get("character_id", -1)
			best_honor = honor

	return {
		"winner_id": best_id,
		"winning_score": best_total,
		"championship": championship_type,
		"topic_tier": 4,
	}


# -- Emperor's Chosen Vacancy -------------------------------------------------

const CHOSEN_POSITIONS: Array[String] = [
	"Imperial Advisor",
	"Imperial Chancellor",
	"Imperial Treasurer",
	"Voice of the Emperor",
]

const CHOSEN_EVALUATION_WEIGHTS: Dictionary = {
	"disposition": 20,
	"clan_balance": 15,
	"skill_relevance": 15,
	"honor": 10,
	"status": 5,
	"personality_alignment": 10,
}

const CHOSEN_MIN_DELAY: int = 14
const CHOSEN_MAX_DELAY_SEASONS: int = 1

static func evaluate_chosen_candidate(
	disposition: int,
	clan_balance_score: int,
	skill_score: int,
	honor: float,
	status: float,
	personality_score: int,
) -> float:
	var w: Dictionary = CHOSEN_EVALUATION_WEIGHTS
	return (
		disposition * w["disposition"] / 100.0 +
		clan_balance_score * w["clan_balance"] / 100.0 +
		skill_score * w["skill_relevance"] / 100.0 +
		honor * w["honor"] / 10.0 +
		status * w["status"] / 10.0 +
		personality_score * w["personality_alignment"] / 100.0
	)


# -- Local Festival Generation (Tier 2) --------------------------------------

const FORMAT_WORDS: Array[String] = [
	"Festival", "Night", "Day", "Viewing", "Prayer", "Gathering",
	"Blessing", "Offering", "Watching", "Dance", "Feast", "Procession",
	"Vigil", "Contest", "Opening", "Closing", "Remembrance",
	"Celebration", "Morning", "Eve",
]

const THEME_CATEGORIES: Array[String] = [
	"agricultural", "maritime", "mountain_forest", "martial",
	"spiritual", "craft_trade", "nature_seasonal", "cultural_social",
	"historical_local", "food_drink", "animal_wildlife", "domestic",
]

const SETTLEMENT_FESTIVAL_COUNT: Dictionary = {
	"village": [1, 2],
	"town": [2, 3],
	"castle_town": [2, 3],
	"fortification": [0, 1],
	"temple": [0, 1],
}

static func generate_local_festivals(
	settlement_type: String,
	terrain: String,
	clan: String,
	rng: Object,
	themes: Array[String] = [],
) -> Array[Dictionary]:
	var count_range: Array = SETTLEMENT_FESTIVAL_COUNT.get(settlement_type, [1, 2])
	var min_count: int = count_range[0]
	var max_count: int = count_range[1]
	var count: int = min_count
	if max_count > min_count and rng.has_method("randi_range"):
		count = rng.randi_range(min_count, max_count)

	var festivals: Array[Dictionary] = []
	var used_days: Array[int] = []

	for i in range(count):
		var theme: String = ""
		if themes.size() > i:
			theme = themes[i]
		else:
			theme = THEME_CATEGORIES[i % THEME_CATEGORIES.size()]

		var format_word: String = FORMAT_WORDS[i % FORMAT_WORDS.size()]
		if rng.has_method("randi_range"):
			format_word = FORMAT_WORDS[rng.randi_range(0, FORMAT_WORDS.size() - 1)]

		var name: String = ""
		if rng.has_method("randi_range") and rng.randi_range(0, 1) == 0:
			name = "The %s of the %s" % [format_word, theme.capitalize()]
		else:
			name = "%s %s" % [theme.capitalize(), format_word]

		var day: int = _pick_festival_day(i, count, used_days, rng)
		used_days.append(day)

		festivals.append({
			"name": name,
			"day_of_year": day,
			"theme_category": theme,
			"mechanical_effect": false,
		})

	return festivals


static func _pick_festival_day(index: int, total: int, used: Array[int], rng: Object) -> int:
	var season_start: int = 0
	if total >= 2:
		season_start = 0 if index == 0 else 180
	var season_end: int = season_start + 179

	var day: int = season_start + 30
	if rng.has_method("randi_range"):
		day = rng.randi_range(season_start + 1, season_end)

	var attempts: int = 0
	while day in used and attempts < 50:
		if rng.has_method("randi_range"):
			day = rng.randi_range(season_start + 1, season_end)
		else:
			day += 1
		attempts += 1
	return day
