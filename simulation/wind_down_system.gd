class_name WindDownSystem
## Wind-Down System per GDD s57.44. Pure static functions.
## Fires once per OOC Day Tick alongside Void Point refresh and natural healing.
## Each method sets wind_down_void_modifier on the character and returns a
## result dict of secondary effects for the caller (DayOrchestrator) to apply.


# -- Settlement infrastructure feature keys (s57.44) --------------------------

const FEATURE_INN: String = "inn"
const FEATURE_SAKE_HOUSE: String = "sake_house"
const FEATURE_OKIYA: String = "okiya"
const FEATURE_SHRINE: String = "shrine"
const FEATURE_TEMPLE: String = "temple"
const FEATURE_GARDEN: String = "garden"
const FEATURE_TEA_HOUSE: String = "tea_house"
const FEATURE_GAME_HOUSE: String = "game_house"
const FEATURE_BATHHOUSE: String = "bathhouse"
const FEATURE_PLEASURE_QUARTER: String = "pleasure_quarter"

# -- Item tag strings for Music and Incense Ceremony availability (s57.44.9, s57.44.13)

const ITEM_TAG_INSTRUMENT: String = "instrument"
const ITEM_TAG_KODO_SET: String = "kodo_set"
const ITEM_TAG_INCENSE: String = "incense_material"

# -- Void Point refresh multipliers (s57.44.16) --------------------------------

const VOID_MODIFIER_FULL: float = 1.0
const VOID_MODIFIER_PARTIAL: float = 0.75
const VOID_MODIFIER_REST: float = 0.5

# -- Locked secondary effect values --------------------------------------------

const GEISHA_TOPIC_LEAK_CHANCE: float = 0.40    # s57.44.5
const TEMPLE_TOPIC_LEAK_CHANCE: float = 0.25    # s57.44.7
const PLEASURE_TOPIC_LEAK_CHANCE: float = 0.60  # s57.44.14

const SHRINE_WP_CONTRIBUTION: float = 0.5       # s57.44.6
const TEMPLE_WP_CONTRIBUTION: float = 0.5       # s57.44.7

const GEISHA_GLORY_GAIN: float = 0.05           # s57.44.5
const GO_PARLOR_WIN_GLORY: float = 0.1          # s57.44.11
const PLEASURE_HONOR_LOSS: float = 0.1          # s57.44.14

const BATHHOUSE_DISPOSITION_GAIN: int = 1       # s57.44.8
const TEA_HOUSE_DISPOSITION_GAIN: int = 2       # s57.44.10

# -- Provisional values — exact numbers pending balancing (s57.44.4–.15) -------
# Do not tune without a GDD amendment to s57.44.

const PROV_SAKE_DISHONORABLE_CHANCE: float = 0.0  # % scaled by Willpower, unspecified
const PROV_GEISHA_KOKU_COST: float = 0.0           # per quality tier, unspecified
const PROV_SHRINE_KOKU_COST: float = 0.0           # small offering, unspecified
const PROV_BATHHOUSE_KOKU_COST: float = 0.0        # admission fee, unspecified
const PROV_INCENSE_KOKU_COST: float = 0.0          # significant cost, unspecified
const PROV_PLEASURE_KOKU_COST: float = 0.0         # low cost, unspecified

# Threshold below which a character is considered "low-Honor" for NPC selection.
# s57.44.15 specifies the lean but not the numeric cutoff — provisional.
const PROV_LOW_HONOR_THRESHOLD: float = 3.0

# NPC personality weight baselines — relative ordering LOCKED, absolute values PROVISIONAL.
const PROV_WEIGHT_HIGH: int = 60
const PROV_WEIGHT_MED: int = 30
const PROV_WEIGHT_LOW: int = 10
const PROV_WEIGHT_CLAN: int = 80


# -- Method enum ---------------------------------------------------------------

enum Method {
	REST,
	SAKE_HOUSE,
	GEISHA_HOUSE,
	SHRINE_PRAYER,
	TEMPLE_STAY,
	GARDEN_WALKING,
	TEA_HOUSE,
	GO_PARLOR,
	MUSIC,
	INCENSE_CEREMONY,
	BATHHOUSE,
	PLEASURE_QUARTER,
}

# Topic leak routing labels returned in the result dict.
const ROUTING_NONE: String = "none"
const ROUTING_RANDOM_PRESENT: String = "random_present"
const ROUTING_HANDLER_PIPELINE: String = "handler_pipeline"
const ROUTING_BROTHERHOOD: String = "brotherhood"


# -- Method name lookup --------------------------------------------------------

static func method_name(method: Method) -> String:
	match method:
		Method.REST:
			return "rest"
		Method.SAKE_HOUSE:
			return "sake_house"
		Method.GEISHA_HOUSE:
			return "geisha_house"
		Method.SHRINE_PRAYER:
			return "shrine_prayer"
		Method.TEMPLE_STAY:
			return "temple_stay"
		Method.GARDEN_WALKING:
			return "garden_walking"
		Method.TEA_HOUSE:
			return "tea_house"
		Method.GO_PARLOR:
			return "go_parlor"
		Method.MUSIC:
			return "music"
		Method.INCENSE_CEREMONY:
			return "incense_ceremony"
		Method.BATHHOUSE:
			return "bathhouse"
		Method.PLEASURE_QUARTER:
			return "pleasure_quarter"
	return "rest"


# -- Void modifier lookup (s57.44.16) ------------------------------------------

static func get_void_modifier(method: Method) -> float:
	match method:
		Method.SAKE_HOUSE, Method.GEISHA_HOUSE, Method.BATHHOUSE, \
		Method.INCENSE_CEREMONY, Method.PLEASURE_QUARTER:
			return VOID_MODIFIER_FULL
		Method.SHRINE_PRAYER, Method.TEMPLE_STAY, Method.GARDEN_WALKING, \
		Method.TEA_HOUSE, Method.GO_PARLOR, Method.MUSIC:
			return VOID_MODIFIER_PARTIAL
	return VOID_MODIFIER_REST


# -- Availability --------------------------------------------------------------

static func _has_perform_skill(character: L5RCharacterData) -> bool:
	for key: String in character.skills:
		if (key == "Perform" or key.begins_with("Perform:")) \
				and character.skills[key] >= 1:
			return true
	return false


static func _has_item_tag(items: Array, tag: String) -> bool:
	for item: Dictionary in items:
		var item_tag: String = item.get("tag", "")
		if item_tag == tag:
			return true
		var tags: Array = item.get("tags", [])
		if tags.has(tag):
			return true
	return false


## Returns the list of methods available to `character` at their current location.
## `settlement` provides the infrastructure feature list.
## `companion_present` is true when another named character willing to share tea
## is in the same settlement (required for TEA_HOUSE).
static func get_available_methods(
	character: L5RCharacterData,
	settlement: SettlementData,
	companion_present: bool,
) -> Array[Method]:
	var available: Array[Method] = [Method.REST]

	# Sake House: inn or sake house present.
	if settlement.has_infrastructure(FEATURE_INN) or \
			settlement.has_infrastructure(FEATURE_SAKE_HOUSE):
		available.append(Method.SAKE_HOUSE)

	# Geisha House: okiya present.
	if settlement.has_infrastructure(FEATURE_OKIYA):
		available.append(Method.GEISHA_HOUSE)

	# Shrine Prayer: shrine present.
	if settlement.has_infrastructure(FEATURE_SHRINE):
		available.append(Method.SHRINE_PRAYER)

	# Temple Stay: temple present.
	if settlement.has_infrastructure(FEATURE_TEMPLE):
		available.append(Method.TEMPLE_STAY)

	# Garden Walking: cultivated garden present.
	if settlement.has_infrastructure(FEATURE_GARDEN):
		available.append(Method.GARDEN_WALKING)

	# Tea House: tea house present AND willing companion.
	if settlement.has_infrastructure(FEATURE_TEA_HOUSE) and companion_present:
		available.append(Method.TEA_HOUSE)

	# Go Parlor: game house or inn with game room present.
	if settlement.has_infrastructure(FEATURE_GAME_HOUSE) or \
			settlement.has_infrastructure(FEATURE_INN):
		available.append(Method.GO_PARLOR)

	# Music: Perform skill Rank 1+ AND an instrument in inventory.
	if _has_perform_skill(character) and \
			_has_item_tag(character.items, ITEM_TAG_INSTRUMENT):
		available.append(Method.MUSIC)

	# Incense Ceremony: kōdō set AND incense materials in inventory.
	if _has_item_tag(character.items, ITEM_TAG_KODO_SET) and \
			_has_item_tag(character.items, ITEM_TAG_INCENSE):
		available.append(Method.INCENSE_CEREMONY)

	# Bathhouse: bathhouse present.
	if settlement.has_infrastructure(FEATURE_BATHHOUSE):
		available.append(Method.BATHHOUSE)

	# Pleasure Quarter: pleasure quarter or entertainment district present.
	if settlement.has_infrastructure(FEATURE_PLEASURE_QUARTER):
		available.append(Method.PLEASURE_QUARTER)

	return available


# -- NPC selection (s57.44.15) -------------------------------------------------

static func _add_weight(weights: Dictionary, method: Method, amount: int) -> void:
	if weights.has(method):
		weights[method] += amount


static func _build_npc_weights(
	character: L5RCharacterData,
	available: Array[Method],
) -> Dictionary:
	var weights: Dictionary = {}
	for m: Method in available:
		weights[m] = PROV_WEIGHT_LOW

	var virtue: Enums.BushidoVirtue = character.bushido_virtue
	var shourido: Enums.ShouridoVirtue = character.shourido_virtue
	var clan: String = character.clan
	var low_honor: bool = character.honor < PROV_LOW_HONOR_THRESHOLD

	# GI and MEIYO → shrine prayer, garden walking, go parlor (clean, disciplined).
	if virtue == Enums.BushidoVirtue.GI or virtue == Enums.BushidoVirtue.MEIYO:
		_add_weight(weights, Method.SHRINE_PRAYER, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.GARDEN_WALKING, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.GO_PARLOR, PROV_WEIGHT_HIGH)

	# YU and KETSUI/KYORYOKU → sake house and pleasure quarter (direct, unsubtle).
	if virtue == Enums.BushidoVirtue.YU or \
			shourido == Enums.ShouridoVirtue.KETSUI or \
			shourido == Enums.ShouridoVirtue.KYORYOKU:
		_add_weight(weights, Method.SAKE_HOUSE, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.PLEASURE_QUARTER, PROV_WEIGHT_HIGH)

	# REI → tea house, garden walking, incense ceremony, go parlor (refined, controlled).
	if virtue == Enums.BushidoVirtue.REI:
		_add_weight(weights, Method.TEA_HOUSE, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.GARDEN_WALKING, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.INCENSE_CEREMONY, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.GO_PARLOR, PROV_WEIGHT_HIGH)

	# SEIGYO → bathhouse (physical) and geisha house (strategic social investment).
	if shourido == Enums.ShouridoVirtue.SEIGYO:
		_add_weight(weights, Method.BATHHOUSE, PROV_WEIGHT_HIGH)
		_add_weight(weights, Method.GEISHA_HOUSE, PROV_WEIGHT_HIGH)

	# Low-Honor → pleasure quarter and sake house.
	if low_honor:
		_add_weight(weights, Method.PLEASURE_QUARTER, PROV_WEIGHT_MED)
		_add_weight(weights, Method.SAKE_HOUSE, PROV_WEIGHT_MED)

	# Perform skill → music when other options are limited.
	if _has_perform_skill(character):
		_add_weight(weights, Method.MUSIC, PROV_WEIGHT_MED)

	# Clan cultural biases (override personality via PROV_WEIGHT_CLAN).
	match clan:
		"Scorpion":
			_add_weight(weights, Method.GEISHA_HOUSE, PROV_WEIGHT_CLAN)
		"Crab":
			_add_weight(weights, Method.SAKE_HOUSE, PROV_WEIGHT_CLAN)
		"Crane":
			_add_weight(weights, Method.TEA_HOUSE, PROV_WEIGHT_CLAN)
			_add_weight(weights, Method.GARDEN_WALKING, PROV_WEIGHT_CLAN)
			_add_weight(weights, Method.INCENSE_CEREMONY, PROV_WEIGHT_CLAN)
		"Phoenix", "Dragon":
			_add_weight(weights, Method.INCENSE_CEREMONY, PROV_WEIGHT_CLAN)
			_add_weight(weights, Method.SHRINE_PRAYER, PROV_WEIGHT_CLAN)

	return weights


static func _weighted_pick(weights: Dictionary, dice: DiceEngine) -> Method:
	var total: int = 0
	for m: Method in weights:
		total += weights[m]
	if total <= 0:
		return Method.REST
	var roll: int = dice.rand_int_range(0, total - 1)
	var cumulative: int = 0
	for m: Method in weights:
		cumulative += weights[m]
		if roll < cumulative:
			return m
	return Method.REST


## NPC selects a wind-down method from `available` based on personality weights.
static func select_npc_method(
	character: L5RCharacterData,
	available: Array[Method],
	dice: DiceEngine,
) -> Method:
	if available.is_empty():
		return Method.REST
	if available.size() == 1:
		return available[0]
	var weights: Dictionary = _build_npc_weights(character, available)
	return _weighted_pick(weights, dice)


# -- Apply wind-down (primary entry point) -------------------------------------

static func _pick_topic(character: L5RCharacterData, dice: DiceEngine) -> int:
	if character.topic_pool.is_empty():
		return -1
	var idx: int = dice.rand_int_range(0, character.topic_pool.size() - 1)
	return character.topic_pool[idx]


static func _pick_random_present(present_character_ids: Array[int], dice: DiceEngine) -> int:
	if present_character_ids.is_empty():
		return -1
	return present_character_ids[dice.rand_int_range(0, present_character_ids.size() - 1)]


## Apply the selected wind-down method to `character`. Sets `last_wind_down_method`
## and `wind_down_void_modifier` directly on the character. Returns a result dict
## of secondary effects for the caller to apply.
##
## Parameters:
##   present_character_ids — IDs of other characters present this evening.
##     Used for Sake House leak target, Bathhouse met_characters / disposition,
##     Pleasure Quarter leak target.
##   companion_id — ID of the companion for Tea House (+2 disposition target).
##     Pass -1 if no companion.
##   go_parlor_opponent — Dictionary with keys "intelligence" (int) and
##     "games_rank" (int). Pass empty dict if no opponent is available, in
##     which case no glory is awarded.
##   fortune_id — Fortune index for Shrine Prayer and Temple Stay WP contribution.
##     Pass -1 for an undirected WP offering (divided across all Fortunes).
##
## Result dict keys:
##   method, method_name, void_modifier, honor_change, glory_change,
##   wp_contribution, fortune_id, disposition_changes [{target_id, delta}],
##   met_character_ids, topic_leaked, leak_target_id, leak_routing,
##   go_parlor_roll, go_parlor_opponent_roll, go_parlor_win,
##   dishonorable_conduct, temple_info_received, koku_cost.
static func apply_wind_down(
	character: L5RCharacterData,
	method: Method,
	dice: DiceEngine,
	present_character_ids: Array[int],
	companion_id: int,
	go_parlor_opponent: Dictionary,
	fortune_id: int,
) -> Dictionary:
	character.last_wind_down_method = method_name(method)
	character.wind_down_void_modifier = get_void_modifier(method)

	var result: Dictionary = {
		"method": method,
		"method_name": character.last_wind_down_method,
		"void_modifier": character.wind_down_void_modifier,
		"honor_change": 0.0,
		"glory_change": 0.0,
		"wp_contribution": 0.0,
		"fortune_id": -1,
		"disposition_changes": [],
		"met_character_ids": [],
		"topic_leaked": -1,
		"leak_target_id": -1,
		"leak_routing": ROUTING_NONE,
		"go_parlor_roll": 0,
		"go_parlor_opponent_roll": 0,
		"go_parlor_win": false,
		"dishonorable_conduct": false,
		"temple_info_received": false,
		"koku_cost": 0.0,
	}

	match method:
		Method.REST:
			pass  # 50% Void, no effects.

		Method.SAKE_HOUSE:
			# No Koku cost (s57.44.4).
			# Leak one random topic to a random present character.
			var topic: int = _pick_topic(character, dice)
			if topic != -1:
				result["topic_leaked"] = topic
				result["leak_routing"] = ROUTING_RANDOM_PRESENT
				result["leak_target_id"] = _pick_random_present(present_character_ids, dice)
			# Dishonorable Conduct risk scaled by Willpower — PROVISIONAL base chance.
			if PROV_SAKE_DISHONORABLE_CHANCE > 0.0:
				var roll_100: int = dice.rand_int_range(1, 100)
				var threshold: int = maxi(1, int(PROV_SAKE_DISHONORABLE_CHANCE) - character.willpower * 5)
				if roll_100 <= threshold:
					result["dishonorable_conduct"] = true
					result["glory_change"] = -0.2

		Method.GEISHA_HOUSE:
			result["koku_cost"] = PROV_GEISHA_KOKU_COST
			result["glory_change"] = GEISHA_GLORY_GAIN
			# 40% chance of one topic leaking to the handler pipeline.
			if dice.rand_int_range(1, 100) <= int(GEISHA_TOPIC_LEAK_CHANCE * 100):
				var topic: int = _pick_topic(character, dice)
				if topic != -1:
					result["topic_leaked"] = topic
					result["leak_routing"] = ROUTING_HANDLER_PIPELINE
					result["leak_target_id"] = -1  # Routed to okiya handler, not a character.

		Method.SHRINE_PRAYER:
			result["koku_cost"] = PROV_SHRINE_KOKU_COST
			result["wp_contribution"] = SHRINE_WP_CONTRIBUTION
			result["fortune_id"] = fortune_id

		Method.TEMPLE_STAY:
			# 75% Void, +0.5 WP, one piece of info received, 25% topic leak to Brotherhood.
			result["wp_contribution"] = TEMPLE_WP_CONTRIBUTION
			result["fortune_id"] = fortune_id
			result["temple_info_received"] = true
			if dice.rand_int_range(1, 100) <= int(TEMPLE_TOPIC_LEAK_CHANCE * 100):
				var topic: int = _pick_topic(character, dice)
				if topic != -1:
					result["topic_leaked"] = topic
					result["leak_routing"] = ROUTING_BROTHERHOOD
					result["leak_target_id"] = -1  # Diffuse Brotherhood network.

		Method.GARDEN_WALKING:
			pass  # 75% Void, no cost, no information exposure, no social interaction.

		Method.TEA_HOUSE:
			# +2 disposition with companion.
			if companion_id != -1:
				result["disposition_changes"].append({"target_id": companion_id, "delta": TEA_HOUSE_DISPOSITION_GAIN})

		Method.GO_PARLOR:
			# met_characters fires with the opponent only (s57.44.11).
			if not go_parlor_opponent.is_empty():
				var opp_id: int = go_parlor_opponent.get("id", -1)
				if opp_id != -1:
					result["met_character_ids"] = [opp_id]
				var char_intel: int = character.intelligence
				var char_games: int = SkillResolver.get_skill_rank(character, "Games: Go")
				if char_games == 0:
					char_games = SkillResolver.get_skill_rank(character, "Games")
				var opp_intel: int = go_parlor_opponent.get("intelligence", 2)
				var opp_games: int = go_parlor_opponent.get("games_rank", 1)
				var rolled_char: int = char_intel + char_games
				var kept_char: int = char_intel
				var rolled_opp: int = opp_intel + opp_games
				var kept_opp: int = opp_intel
				var contest: Dictionary = dice.contested_roll(
					maxi(1, rolled_char), maxi(1, kept_char),
					maxi(1, rolled_opp), maxi(1, kept_opp),
				)
				result["go_parlor_roll"] = contest["total_a"]
				result["go_parlor_opponent_roll"] = contest["total_b"]
				result["go_parlor_win"] = contest["winner"] == "a"
				if result["go_parlor_win"]:
					result["glory_change"] = GO_PARLOR_WIN_GLORY

		Method.MUSIC:
			pass  # 75% Void, private, no effects.

		Method.INCENSE_CEREMONY:
			result["koku_cost"] = PROV_INCENSE_KOKU_COST
			# 100% Void, completely private, zero social exposure.

		Method.BATHHOUSE:
			result["koku_cost"] = PROV_BATHHOUSE_KOKU_COST
			result["met_character_ids"] = present_character_ids.duplicate()
			for char_id: int in present_character_ids:
				result["disposition_changes"].append({"target_id": char_id, "delta": BATHHOUSE_DISPOSITION_GAIN})

		Method.PLEASURE_QUARTER:
			result["koku_cost"] = PROV_PLEASURE_KOKU_COST
			result["honor_change"] = -PLEASURE_HONOR_LOSS
			# 60% chance of one topic leaking to a random present character.
			if dice.rand_int_range(1, 100) <= int(PLEASURE_TOPIC_LEAK_CHANCE * 100):
				var topic: int = _pick_topic(character, dice)
				if topic != -1:
					result["topic_leaked"] = topic
					result["leak_routing"] = ROUTING_RANDOM_PRESENT
					result["leak_target_id"] = _pick_random_present(present_character_ids, dice)

	return result
