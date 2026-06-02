class_name AsciiMapEnvironment
## s56.6 Shared outdoor ASCII map environment data layer --- LOCKED.
## Pure data and lookup layer: biome types, weather states, noise levels,
## alert state transitions, kansen density.  All runtime simulation of
## mechanical effects (wound application, movement cost multipliers, spell
## disruption rolls) is blocked on s40 individual combat / s4.4 Local Interface.
## No instance state; all constants and static helpers.

# -- s56.6.1 BiomeType ---------------------------------------------------------

enum BiomeType {
	NORTHERN_HIGHLAND = 0,
	CENTRAL_PLAINS    = 1,
	WESTERN_STEPPE    = 2,
	EASTERN_COAST     = 3,
	SOUTHERN_BORDER   = 4,
	SHINOMEN          = 5,
	SHADOWLANDS       = 6,
}

# -- s56.6.2 WeatherState ------------------------------------------------------

enum WeatherState {
	CLEAR   = 0,
	WIND    = 1,
	RAIN    = 2,
	STORM   = 3,
	TYPHOON = 4,
	MIST    = 5,
	SNOW    = 6,   # biome variant of RAIN in winter (NORTHERN_HIGHLAND)
	BLIZZARD = 7,  # biome variant of STORM in winter (NORTHERN_HIGHLAND)
}

# TN modifiers keyed by WeatherState.
# Blocked entries are stored as metadata (value present) but effects blocked on s40.
# ranged_tn_mod: bonus TN to all ranged attacks.
# vision_mod: tiles of vision range reduction (blocked — s40 FOV system).
# stealth_mod: bonus TN to Stealth rolls (blocked — s40 detection system).
# movement_mult: movement cost multiplier for mud/snow (blocked — s40).
# wound_per_10_rounds: wounds per 10 rounds of exposure (blocked — s40).
const WEATHER_DATA: Dictionary = {
	WeatherState.CLEAR: {
		ranged_tn_mod      = 0,
		vision_mod         = 0,
		stealth_mod        = 0,
		movement_mult      = 1.0,
		wound_per_10_rounds = 0,
		coastal_only       = false,
	},
	WeatherState.WIND: {
		ranged_tn_mod      = 5,
		vision_mod         = 0,
		stealth_mod        = 0,
		movement_mult      = 1.0,
		wound_per_10_rounds = 0,
		coastal_only       = false,
	},
	WeatherState.RAIN: {
		ranged_tn_mod      = 5,
		vision_mod         = 2,
		stealth_mod        = 5,
		movement_mult      = 2.0,
		wound_per_10_rounds = 0,
		coastal_only       = false,
	},
	WeatherState.STORM: {
		ranged_tn_mod      = 10,
		vision_mod         = 4,
		stealth_mod        = 0,
		movement_mult      = 3.0,
		wound_per_10_rounds = 0,
		coastal_only       = false,
		no_fires           = true,
	},
	WeatherState.TYPHOON: {
		ranged_tn_mod      = 10,
		vision_mod         = 4,
		stealth_mod        = 0,
		movement_mult      = 3.0,
		wound_per_10_rounds = 1,
		coastal_only       = true,
		no_fires           = true,
	},
	WeatherState.MIST: {
		ranged_tn_mod      = 0,
		vision_mod         = 3,
		stealth_mod        = 5,
		movement_mult      = 1.0,
		wound_per_10_rounds = 0,
		coastal_only       = false,
		dawn_chance        = 0.20,
		clears_midday      = true,
	},
	WeatherState.SNOW: {
		ranged_tn_mod      = 5,
		vision_mod         = 2,
		stealth_mod        = 5,
		movement_mult      = 1.5,
		wound_per_10_rounds = 0,
		coastal_only       = false,
		tracking_bonus     = 10,
	},
	WeatherState.BLIZZARD: {
		ranged_tn_mod      = 10,
		vision_mod         = 4,
		stealth_mod        = 0,
		movement_mult      = 3.0,
		wound_per_10_rounds = 1,
		coastal_only       = false,
		no_fires           = true,
	},
}

# -- s56.6.3 Noise Levels ------------------------------------------------------

enum NoiseLevel {
	SILENT    = 0,
	QUIET     = 1,
	MODERATE  = 2,
	LOUD      = 3,
	VERY_LOUD = 4,
}

# Noise propagation radius in tiles. VERY_LOUD propagates map-wide.
const NOISE_RADIUS: Dictionary = {
	NoiseLevel.SILENT:    0,
	NoiseLevel.QUIET:     3,
	NoiseLevel.MODERATE:  6,
	NoiseLevel.LOUD:      12,
	NoiseLevel.VERY_LOUD: 9999,
}

# Detection TN for NPCs when noise reaches them (blocked — s40 detection).
const NOISE_DETECTION_TN: Dictionary = {
	NoiseLevel.SILENT:    0,    # no roll triggered
	NoiseLevel.QUIET:     20,
	NoiseLevel.MODERATE:  15,
	NoiseLevel.LOUD:      10,
	NoiseLevel.VERY_LOUD: 0,    # automatic detection
}

# Ground surface base TNs for making a STEALTH (Sneaking) roll (blocked — s40).
const GROUND_STEALTH_TN: Dictionary = {
	"soft":  10,
	"hard":  15,
	"noisy": 20,
}

# -- s56.6.3 Alert States ------------------------------------------------------

enum AlertState {
	UNAWARE    = 0,
	SUSPICIOUS = 1,
	ALERT      = 2,
	FLEEING    = 3,
}

# Duration (in rounds) of each alert state before escalation (blocked — s40).
const ALERT_DURATION_ROUNDS: Dictionary = {
	AlertState.SUSPICIOUS: 3,  # 3-round investigation window; +5 scan TN bonus
	AlertState.ALERT:      5,  # 5 rounds before raising general alarm
}

# Perception/Investigation scan bonus while SUSPICIOUS (blocked — s40).
const SUSPICIOUS_SCAN_BONUS: int = 5

# -- s56.6.4 Kansen Density ----------------------------------------------------

enum KansenDensity {
	NONE     = 0,
	LOW      = 1,
	MODERATE = 2,
	HIGH     = 3,
}

# Exposure interval in rounds per density level (blocked — s40).
const KANSEN_EXPOSURE_INTERVAL_ROUNDS: Dictionary = {
	KansenDensity.NONE:     0,
	KansenDensity.LOW:      10,
	KansenDensity.MODERATE: 5,
	KansenDensity.HIGH:     1,
}

# Fortitude TN per density level for Taint exposure (blocked — s40).
const KANSEN_EXPOSURE_TN: Dictionary = {
	KansenDensity.NONE:     0,
	KansenDensity.LOW:      10,
	KansenDensity.MODERATE: 15,
	KansenDensity.HIGH:     20,
}

# Bonus TN added to spell casting rolls from kansen disruption (blocked — s40).
const KANSEN_SPELL_DISRUPTION_TN: Dictionary = {
	KansenDensity.NONE:     0,
	KansenDensity.LOW:      5,
	KansenDensity.MODERATE: 10,
	KansenDensity.HIGH:     15,
}

# TN to resist kansen whispers (blocked — s40).
const KANSEN_WHISPER_TN: Dictionary = {
	KansenDensity.NONE:     0,
	KansenDensity.LOW:      0,
	KansenDensity.MODERATE: 10,
	KansenDensity.HIGH:     15,
}

# TN for banishment ritual (blocked — s40 / spell system).
const KANSEN_BANISHMENT_TN: Dictionary = {
	KansenDensity.NONE:     0,
	KansenDensity.LOW:      15,
	KansenDensity.MODERATE: 20,
	KansenDensity.HIGH:     25,
}

# Jade suppression radius (tiles).  Jade negates kansen effects in radius.
const JADE_SUPPRESSION_RADIUS: int = 3

# TN for a Sense spell to detect kansen density (blocked — s40 / spell system).
const SENSE_KANSEN_TN: int = 15

# -- Static helpers ------------------------------------------------------------

## Returns the KansenDensity tier corresponding to a province taint level.
## PTL < 3 → NONE, 3-5 → LOW, 6-8 → MODERATE, 9+ → HIGH.
static func density_from_ptl(ptl: float) -> int:
	if ptl >= 9.0:
		return KansenDensity.HIGH
	elif ptl >= 6.0:
		return KansenDensity.MODERATE
	elif ptl >= 3.0:
		return KansenDensity.LOW
	return KansenDensity.NONE

## Returns the noise detection TN. Returns 0 for SILENT and VERY_LOUD
## (no roll for silent; automatic detection for very loud).
static func detection_tn_for_noise(noise_level: int) -> int:
	return NOISE_DETECTION_TN.get(noise_level, 0)

## Returns true if the noise level triggers automatic detection.
static func is_automatic_detection(noise_level: int) -> bool:
	return noise_level == NoiseLevel.VERY_LOUD

## Returns the propagation radius for a noise level.
static func radius_for_noise(noise_level: int) -> int:
	return NOISE_RADIUS.get(noise_level, 0)

## Returns weather data dictionary for a given WeatherState.
static func get_weather_data(weather: int) -> Dictionary:
	return WEATHER_DATA.get(weather, WEATHER_DATA[WeatherState.CLEAR])

## Returns true if the given WeatherState is a coastal-only variant.
static func is_coastal_only(weather: int) -> bool:
	return WEATHER_DATA.get(weather, {}).get("coastal_only", false)

## Returns the kansen exposure interval in rounds (0 = no exposure).
static func exposure_interval(density: int) -> int:
	return KANSEN_EXPOSURE_INTERVAL_ROUNDS.get(density, 0)

## Returns the kansen exposure Fortitude TN.
static func exposure_tn(density: int) -> int:
	return KANSEN_EXPOSURE_TN.get(density, 0)


## Returns the BiomeType that best represents a given TerrainType for ASCII map
## mission generation when no explicit province biome tag is available.
## PROVISIONAL — s56.6.1 says biomes are assigned at world generation by province
## and clan territory, not derived from terrain type alone.  This fallback is used
## only by the mission assembly layer when the explicit biome is absent.
static func biome_for_terrain(terrain_type: int) -> int:
	match terrain_type:
		Enums.TerrainType.MOUNTAINS:
			return BiomeType.NORTHERN_HIGHLAND
		Enums.TerrainType.FOREST:
			return BiomeType.SHINOMEN
		Enums.TerrainType.COASTAL:
			return BiomeType.EASTERN_COAST
		Enums.TerrainType.RIVER_DELTA:
			return BiomeType.EASTERN_COAST
		Enums.TerrainType.SWAMP:
			return BiomeType.SOUTHERN_BORDER
		Enums.TerrainType.WASTELAND:
			return BiomeType.SOUTHERN_BORDER
		Enums.TerrainType.HILLS:
			return BiomeType.CENTRAL_PLAINS
		_:  # PLAINS and unrecognised
			return BiomeType.CENTRAL_PLAINS


## Converts a base (unified 5-state) weather value to its biome-specific variant
## per GDD s56.6.2 LOCKED biome conversion rules.
## Rain → Snow in NORTHERN_HIGHLAND, CENTRAL_PLAINS, and WESTERN_STEPPE during
##   winter.  ("Deep winter" is not a distinct season we model — WINTER applies.)
## Storm → Blizzard in NORTHERN_HIGHLAND during winter only.
## All other biome/season combinations return the base weather unchanged.
static func apply_biome_weather_conversion(
		base_weather: int, biome: int, season: int) -> int:
	if season != TimeSystem.Season.WINTER:
		return base_weather
	match biome:
		BiomeType.NORTHERN_HIGHLAND:
			if base_weather == WeatherState.RAIN:
				return WeatherState.SNOW
			if base_weather == WeatherState.STORM:
				return WeatherState.BLIZZARD
		BiomeType.CENTRAL_PLAINS, BiomeType.WESTERN_STEPPE:
			if base_weather == WeatherState.RAIN:
				return WeatherState.SNOW
	return base_weather


## Returns the env_modifier integer for FovSystem.effective_radius() and
## FovSystem.lookout_radius() that corresponds to the given WeatherState.
## Maps directly from WEATHER_DATA["vision_mod"] (tiles of vision range reduction).
## Pass the result straight to FovSystem as env_modifier.
static func weather_to_fov_modifier(weather: int) -> int:
	return WEATHER_DATA.get(weather, WEATHER_DATA[WeatherState.CLEAR]).get("vision_mod", 0)
