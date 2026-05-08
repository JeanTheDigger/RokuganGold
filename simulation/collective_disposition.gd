class_name CollectiveDisposition
## Clan-to-clan and family-to-family collective disposition baselines per
## GDD s12.2b. Pre-Scorpion-Coup era starting values.
##
## Two baselines exist per pair of groups:
##   - Clan-to-Clan baseline applies at 25% to the starting personal
##     disposition seed when characters from different clans first meet.
##   - Family-to-Family baseline applies at 50% to the same seed.
##
## After the seed, personal disposition is owned by disposition_values and
## evolves through events. Events also produce smaller ripple effects on
## the collective baselines (s12.2b "Event Ripple"):
##   - Personal change × 0.20 → Family baseline change
##   - Personal change × 0.05 → Clan baseline change
##
## Baselines do not decay — they're collective historical memory. Negative
## baselines only improve via deliberate diplomatic action (peace treaties,
## marriages, formal apologies). All values are PROVISIONAL per GDD.
##
## Pure simulation class — no Node inheritance, no scene tree.


# -- Seed and ripple weights --------------------------------------------------

const CLAN_SEED_WEIGHT: float = 0.25
const FAMILY_SEED_WEIGHT: float = 0.50

const CLAN_RIPPLE_WEIGHT: float = 0.05
const FAMILY_RIPPLE_WEIGHT: float = 0.20


# -- Specific event deltas (s12.2b) ------------------------------------------

const MARRIAGE_FAMILY_DELTA: int = 5
const MARRIAGE_CLAN_DELTA: int = 1
const FAMILY_LORD_RAID_DELTA: int = -3
const FAMILY_BETRAYAL_DELTA: int = -10
const INTRA_CLAN_RICE_SHARING_DELTA: int = 2
const FAMILY_DUEL_DEATH_DELTA: int = -5
const CLAN_WAR_DECLARED_DELTA: int = -10
const CLAN_PEACE_TREATY_DELTA: int = 5
const CHAMPION_MARRIAGE_CLAN_DELTA: int = 8
const CHAMPION_MARRIAGE_FAMILY_DELTA: int = 5
const HARVEST_DESTRUCTION_CLAN_DELTA: int = -5


# -- Starting clan-to-clan baselines (pre-Scorpion Coup) ---------------------
# Keys are formed by lexicographic sort + "||" so lookup is symmetric.
# All listed pairs are PROVISIONAL.

const STARTING_CLAN_BASELINES: Dictionary = {
	# Great Clan pairs
	"Crab||Crane": -25,
	"Crab||Dragon": -5,
	"Crab||Lion": 5,
	"Crab||Phoenix": -5,
	"Crab||Scorpion": -15,
	"Crab||Unicorn": 0,
	"Crane||Dragon": 0,
	"Crane||Lion": -30,
	"Crane||Phoenix": 20,
	"Crane||Scorpion": -20,
	"Crane||Unicorn": -10,
	"Dragon||Lion": -5,
	"Dragon||Phoenix": 15,
	"Dragon||Scorpion": -5,
	"Dragon||Unicorn": 5,
	"Lion||Phoenix": 0,
	"Lion||Scorpion": -15,
	"Lion||Unicorn": -15,
	"Phoenix||Scorpion": -15,
	"Phoenix||Unicorn": -5,
	"Scorpion||Unicorn": 5,

	# Minor Clan ↔ Great Clan
	"Badger||Crab": 10,
	"Badger||Dragon": 5,
	"Bat||Phoenix": 5,
	"Centipede||Phoenix": 10,
	"Dragon||Dragonfly": 20,
	"Dragonfly||Lion": -10,
	"Dragonfly||Phoenix": 5,
	"Fox||Lion": -10,
	"Hare||Scorpion": -5,
	"Crab||Mantis": 10,
	"Crane||Mantis": -10,
	"Lion||Mantis": -5,
	"Mantis||Phoenix": 5,
	"Mantis||Scorpion": 5,
	"Crane||Monkey": -5,
	"Lion||Monkey": 5,
	"Monkey||Scorpion": 10,
	"Crab||Oriole": 5,
	"Crane||Oriole": 5,
	"Dragon||Oriole": 5,
	"Oriole||Phoenix": 5,
	"Ox||Phoenix": 5,
	"Ox||Scorpion": -5,
	"Ox||Unicorn": -5,
	"Crab||Sparrow": -5,
	"Mantis||Tortoise": 5,
	"Scorpion||Tortoise": 5,
	"Lion||Wasp": -5,
	"Phoenix||Wasp": -5,

	# Minor Clan ↔ Minor Clan
	"Bat||Fox": 5,
	"Bat||Mantis": 10,
	"Fox||Mantis": 5,
	"Fox||Sparrow": 5,
	"Fox||Wasp": 5,
	"Centipede||Mantis": 5,
	"Mantis||Wasp": 5,
	"Sparrow||Wasp": 5,
}


# -- Starting family-to-family baselines -------------------------------------
# Same key convention. Intra-clan and cross-clan pairs share one dict.

const STARTING_FAMILY_BASELINES: Dictionary = {
	# Crab
	"Hida||Hiruma": 10,
	"Hida||Kaiu": 10,
	"Hida||Kuni": 5,
	"Hida||Yasuki": 5,
	"Hiruma||Kuni": 5,
	"Hiruma||Kaiu": 5,
	"Kaiu||Kuni": 5,
	"Kaiu||Yasuki": 5,

	# Crane
	"Doji||Kakita": 15,
	"Asahina||Doji": 10,
	"Daidoji||Doji": 5,
	"Asahina||Kakita": 10,
	"Asahina||Daidoji": -5,

	# Lion
	"Akodo||Ikoma": 10,
	"Akodo||Matsu": 5,
	"Akodo||Kitsu": 5,
	"Kitsu||Matsu": 5,
	"Ikoma||Matsu": 5,
	"Ikoma||Kitsu": 5,

	# Dragon
	"Mirumoto||Tamori": 10,
	"Kitsuki||Mirumoto": 10,
	"Mirumoto||Togashi": 5,
	"Kitsuki||Tamori": 5,

	# Scorpion
	"Bayushi||Shosuro": 15,
	"Bayushi||Soshi": 10,
	"Shosuro||Soshi": 10,
	"Bayushi||Yogo": 5,
	"Shosuro||Yogo": 5,
	"Soshi||Yogo": 5,

	# Phoenix
	"Isawa||Shiba": 5,
	"Asako||Isawa": 5,
	"Agasha||Isawa": -5,
	"Asako||Shiba": 5,

	# Unicorn
	"Shinjo||Utaku": 10,
	"Ide||Shinjo": 10,
	"Horiuchi||Shinjo": 10,
	"Horiuchi||Iuchi": 10,
	"Moto||Shinjo": 5,
	"Iuchi||Shinjo": 5,
	"Ide||Utaku": 5,
	"Iuchi||Utaku": 5,
	"Ide||Iuchi": 5,
	"Moto||Utaku": -5,
	"Ide||Moto": -5,

	# Cross-clan (Yasuki War, dueling rivalries, defections)
	"Doji||Yasuki": -20,
	"Daidoji||Yasuki": -15,
	"Daidoji||Hida": 10,
	"Kuni||Yogo": 10,
	"Kakita||Mirumoto": -15,
	"Agasha||Tamori": -15,
	"Isawa||Iuchi": -10,
	"Asahina||Isawa": 10,
	"Bayushi||Doji": -15,
	"Kakita||Matsu": -15,
	"Daidoji||Matsu": -10,
}


# -- Key composition ---------------------------------------------------------

static func make_pair_key(a: String, b: String) -> String:
	## Symmetric lookup key. Lexicographic sort guarantees
	## make_pair_key("Crab", "Crane") == make_pair_key("Crane", "Crab").
	if a <= b:
		return a + "||" + b
	return b + "||" + a


# -- Baseline lookups --------------------------------------------------------

static func get_clan_baseline(
	clan_a: String,
	clan_b: String,
	clan_baselines: Dictionary,
) -> int:
	if clan_a == "" or clan_b == "":
		return 0
	if clan_a == clan_b:
		return 0  # Same clan — collective sentiment is intra-clan, no baseline.
	return int(clan_baselines.get(make_pair_key(clan_a, clan_b), 0))


static func get_family_baseline(
	family_a: String,
	family_b: String,
	family_baselines: Dictionary,
) -> int:
	if family_a == "" or family_b == "":
		return 0
	if family_a == family_b:
		return 0
	return int(family_baselines.get(make_pair_key(family_a, family_b), 0))


# -- Seed disposition for first-meeting --------------------------------------

static func compute_seed_disposition(
	actor: L5RCharacterData,
	target: L5RCharacterData,
	clan_baselines: Dictionary,
	family_baselines: Dictionary,
) -> int:
	if actor == null or target == null:
		return 0
	var clan_val: int = get_clan_baseline(actor.clan, target.clan, clan_baselines)
	var family_val: int = get_family_baseline(actor.family, target.family, family_baselines)
	var seed: float = (float(clan_val) * CLAN_SEED_WEIGHT) + (float(family_val) * FAMILY_SEED_WEIGHT)
	return int(round(seed))


static func seed_first_meeting(
	actor: L5RCharacterData,
	target: L5RCharacterData,
	clan_baselines: Dictionary,
	family_baselines: Dictionary,
) -> int:
	## Sets actor.disposition_values[target.character_id] to the computed
	## seed value if not already set. Returns the value applied (or the
	## existing value if the entry already exists).
	if actor == null or target == null:
		return 0
	if actor.disposition_values.has(target.character_id):
		return actor.disposition_values[target.character_id]
	var seed: int = compute_seed_disposition(actor, target, clan_baselines, family_baselines)
	actor.disposition_values[target.character_id] = seed
	return seed


# -- Event ripple ------------------------------------------------------------

static func apply_event_ripple(
	actor: L5RCharacterData,
	target: L5RCharacterData,
	personal_change: int,
	clan_baselines: Dictionary,
	family_baselines: Dictionary,
) -> Dictionary:
	## Mutates clan_baselines and family_baselines with proportional ripple
	## changes. Returns a dict describing what changed.
	var family_change: int = int(round(float(personal_change) * FAMILY_RIPPLE_WEIGHT))
	var clan_change: int = int(round(float(personal_change) * CLAN_RIPPLE_WEIGHT))
	var result: Dictionary = {
		"family_change": 0,
		"clan_change": 0,
		"family_key": "",
		"clan_key": "",
	}
	if actor == null or target == null:
		return result
	if actor.clan != target.clan and actor.clan != "" and target.clan != "" and clan_change != 0:
		var ckey: String = make_pair_key(actor.clan, target.clan)
		var current: int = int(clan_baselines.get(ckey, 0))
		clan_baselines[ckey] = clampi(current + clan_change, -100, 100)
		result["clan_change"] = clan_change
		result["clan_key"] = ckey
	if actor.family != target.family and actor.family != "" and target.family != "" and family_change != 0:
		var fkey: String = make_pair_key(actor.family, target.family)
		var current: int = int(family_baselines.get(fkey, 0))
		family_baselines[fkey] = clampi(current + family_change, -100, 100)
		result["family_change"] = family_change
		result["family_key"] = fkey
	return result


# -- Specific events ---------------------------------------------------------

static func apply_marriage(
	clan_a: String, clan_b: String,
	family_a: String, family_b: String,
	clan_baselines: Dictionary, family_baselines: Dictionary,
	champion_level: bool = false,
) -> Dictionary:
	var fam_delta: int = (
		CHAMPION_MARRIAGE_FAMILY_DELTA if champion_level else MARRIAGE_FAMILY_DELTA
	)
	var clan_delta: int = (
		CHAMPION_MARRIAGE_CLAN_DELTA if champion_level else MARRIAGE_CLAN_DELTA
	)
	return _apply_baseline_delta(
		clan_a, clan_b, family_a, family_b,
		clan_delta, fam_delta,
		clan_baselines, family_baselines,
	)


static func apply_clan_war_declared(
	clan_a: String, clan_b: String,
	clan_baselines: Dictionary,
) -> int:
	if clan_a == clan_b or clan_a == "" or clan_b == "":
		return 0
	var key: String = make_pair_key(clan_a, clan_b)
	clan_baselines[key] = clampi(int(clan_baselines.get(key, 0)) + CLAN_WAR_DECLARED_DELTA, -100, 100)
	return CLAN_WAR_DECLARED_DELTA


static func apply_clan_peace_treaty(
	clan_a: String, clan_b: String,
	clan_baselines: Dictionary,
) -> int:
	if clan_a == clan_b or clan_a == "" or clan_b == "":
		return 0
	var key: String = make_pair_key(clan_a, clan_b)
	clan_baselines[key] = clampi(int(clan_baselines.get(key, 0)) + CLAN_PEACE_TREATY_DELTA, -100, 100)
	return CLAN_PEACE_TREATY_DELTA


static func apply_harvest_destruction(
	clan_a: String, clan_b: String,
	clan_baselines: Dictionary,
) -> int:
	if clan_a == clan_b or clan_a == "" or clan_b == "":
		return 0
	var key: String = make_pair_key(clan_a, clan_b)
	clan_baselines[key] = clampi(int(clan_baselines.get(key, 0)) + HARVEST_DESTRUCTION_CLAN_DELTA, -100, 100)
	return HARVEST_DESTRUCTION_CLAN_DELTA


static func apply_family_lord_raid(
	family_a: String, family_b: String,
	family_baselines: Dictionary,
) -> int:
	if family_a == family_b or family_a == "" or family_b == "":
		return 0
	var key: String = make_pair_key(family_a, family_b)
	family_baselines[key] = clampi(int(family_baselines.get(key, 0)) + FAMILY_LORD_RAID_DELTA, -100, 100)
	return FAMILY_LORD_RAID_DELTA


static func apply_family_betrayal(
	family_a: String, family_b: String,
	family_baselines: Dictionary,
) -> int:
	if family_a == family_b or family_a == "" or family_b == "":
		return 0
	var key: String = make_pair_key(family_a, family_b)
	family_baselines[key] = clampi(int(family_baselines.get(key, 0)) + FAMILY_BETRAYAL_DELTA, -100, 100)
	return FAMILY_BETRAYAL_DELTA


static func apply_intra_clan_rice_sharing(
	family_a: String, family_b: String,
	family_baselines: Dictionary,
) -> int:
	if family_a == family_b or family_a == "" or family_b == "":
		return 0
	var key: String = make_pair_key(family_a, family_b)
	family_baselines[key] = clampi(int(family_baselines.get(key, 0)) + INTRA_CLAN_RICE_SHARING_DELTA, -100, 100)
	return INTRA_CLAN_RICE_SHARING_DELTA


static func apply_family_duel_death(
	family_a: String, family_b: String,
	family_baselines: Dictionary,
) -> int:
	if family_a == family_b or family_a == "" or family_b == "":
		return 0
	var key: String = make_pair_key(family_a, family_b)
	family_baselines[key] = clampi(int(family_baselines.get(key, 0)) + FAMILY_DUEL_DEATH_DELTA, -100, 100)
	return FAMILY_DUEL_DEATH_DELTA


static func _apply_baseline_delta(
	clan_a: String, clan_b: String,
	family_a: String, family_b: String,
	clan_delta: int, family_delta: int,
	clan_baselines: Dictionary, family_baselines: Dictionary,
) -> Dictionary:
	var result: Dictionary = {"clan_change": 0, "family_change": 0}
	if clan_a != clan_b and clan_a != "" and clan_b != "" and clan_delta != 0:
		var ckey: String = make_pair_key(clan_a, clan_b)
		clan_baselines[ckey] = int(clan_baselines.get(ckey, 0)) + clan_delta
		result["clan_change"] = clan_delta
	if family_a != family_b and family_a != "" and family_b != "" and family_delta != 0:
		var fkey: String = make_pair_key(family_a, family_b)
		family_baselines[fkey] = int(family_baselines.get(fkey, 0)) + family_delta
		result["family_change"] = family_delta
	return result


# -- Factory: starting baselines for a fresh world ---------------------------

static func make_starting_baselines() -> Dictionary:
	## Returns a fresh copy of the locked starting baselines, ready to be
	## stored in world state. Returned dicts are mutable — callers can
	## apply ripples and event deltas to them as the simulation runs.
	return {
		"clan": STARTING_CLAN_BASELINES.duplicate(true),
		"family": STARTING_FAMILY_BASELINES.duplicate(true),
	}
