class_name LetterSystem
## Letter System per GDD s12.7.
## Handles writing, transit, delivery, and reply generation.
## Letters are the primary mechanism for long-distance topic propagation.

# Calligraphy TN and raise thresholds
const BASE_TN: int = 15
const RAISE_TN: int = 5

# Disposition bonuses by quality tier
const QUALITY_BONUS: Array[int] = [0, 1, 2, 3]

# Reply modifiers
const BASE_REPLY_CHANCE: float = 0.20
const DISPOSITION_REPLY_BONUS: float = 0.008   # per disposition point above 0
const COURTESY_REPLY_BONUS: float = 0.15       # for Courtesy bushido virtue
const HOSTILE_REPLY_THRESHOLD: int = -30       # won't reply below this

# Delivery rate: provinces per IC day
const PROVINCES_PER_DAY: int = 3

# Per-province modifiers (IC days)
const MOUNTAIN_DELAY: int = 1
const WARZONE_DELAY: int = 1
const OCEAN_SEGMENT_DELAY: int = 2
const MIYA_BONUS: int = -1

# Non-lord daily free letter allowance and batch AP cost
const FREE_LETTERS_PER_DAY: int = 1
const BATCH_SIZE: int = 4


# -- Delivery Time Formula (GDD s12.7) -----------------------------------------

static func calculate_delivery_time(
	province_distance: int,
	mountain_provinces: int = 0,
	warzone_provinces: int = 0,
	ocean_segments: int = 0,
	has_miya_route: bool = false,
) -> int:
	if province_distance <= 0 and ocean_segments <= 0:
		return 0
	var base: int = ceili(float(province_distance) / float(PROVINCES_PER_DAY))
	var total: int = base + mountain_provinces * MOUNTAIN_DELAY \
		+ warzone_provinces * WARZONE_DELAY \
		+ ocean_segments * OCEAN_SEGMENT_DELAY
	if has_miya_route:
		total += MIYA_BONUS
	return maxi(0, total)


# -- AP / Budget Check ----------------------------------------------------------

static func can_send_free_letter(
	is_lord: bool,
	letters_sent_today: int,
) -> bool:
	if not is_lord:
		return letters_sent_today < FREE_LETTERS_PER_DAY
	return false


static func can_send_batch(character: L5RCharacterData, is_lord: bool) -> bool:
	if is_lord:
		return false
	return ActionPointSystem.can_spend(character, 1)


# -- Calligraphy Quality Roll --------------------------------------------------

static func roll_letter_quality(
	sender: L5RCharacterData,
	dice_engine: DiceEngine,
	trait_override: Enums.Trait = Enums.Trait.AWARENESS,
) -> int:
	var result: Dictionary = SkillResolver.resolve_skill_check(
		sender, dice_engine, "Calligraphy", BASE_TN, 0, "", trait_override
	)
	if not result["success"]:
		return 0
	var margin: int = result["margin"]
	# Each raise = 5 points above TN; max 2 raises matter (quality 3)
	var raises: int = mini(margin / RAISE_TN, 2)
	return 1 + raises


static func _quality_to_disposition_bonus(quality: int) -> int:
	if quality < 0 or quality >= QUALITY_BONUS.size():
		return 0
	return QUALITY_BONUS[quality]


# -- Write Letter --------------------------------------------------------------

static func write_letter(
	letter_id: int,
	sender: L5RCharacterData,
	recipient_id: int,
	topic: String,
	ic_day_sent: int,
	dice_engine: DiceEngine,
	province_distance: int = 0,
	mountain_provinces: int = 0,
	warzone_provinces: int = 0,
	ocean_segments: int = 0,
	has_miya_route: bool = false,
	trait_override: Enums.Trait = Enums.Trait.AWARENESS,
	is_reply: bool = false,
) -> LetterData:
	var letter := LetterData.new()
	letter.letter_id = letter_id
	letter.sender_id = sender.character_id
	letter.recipient_id = recipient_id
	letter.topic = topic
	letter.ic_day_sent = ic_day_sent
	letter.is_reply = is_reply
	letter.province_distance = province_distance
	letter.mountain_provinces = mountain_provinces
	letter.warzone_provinces = warzone_provinces
	letter.ocean_segments = ocean_segments
	letter.has_miya_route = has_miya_route

	letter.quality = roll_letter_quality(sender, dice_engine, trait_override)
	letter.disposition_bonus = _quality_to_disposition_bonus(letter.quality)

	var transit: int = calculate_delivery_time(
		province_distance, mountain_provinces, warzone_provinces,
		ocean_segments, has_miya_route
	)
	letter.ic_day_arrival = ic_day_sent + transit

	return letter


# -- Deliver Letter ------------------------------------------------------------

static func deliver_letter(
	letter: LetterData,
	recipient: L5RCharacterData,
	current_season: int,
	action_log: Array[Dictionary],
) -> Dictionary:
	if letter.delivered:
		return {}

	letter.delivered = true

	# Transfer topic to recipient
	var topic_transferred: bool = false
	if not letter.topic.is_empty() and letter.topic not in recipient.topic_pool:
		recipient.topic_pool.append(letter.topic)
		topic_transferred = true
		InformationSystem.add_knowledge(recipient, InformationSystem.make_entry(
			InformationSystem.Source.LETTER,
			"topic_learned",
			{
				"topic": letter.topic,
				"from_character_id": letter.sender_id,
				"letter_id": letter.letter_id,
			},
			current_season,
		))

	# Apply disposition bonus from calligraphy quality
	if letter.disposition_bonus > 0:
		var current: int = recipient.disposition_values.get(letter.sender_id, 0)
		recipient.disposition_values[letter.sender_id] = current + letter.disposition_bonus

	action_log.append({
		"action": "LETTER_DELIVERED",
		"sender_id": letter.sender_id,
		"recipient_id": recipient.character_id,
		"topic": letter.topic,
		"topic_transferred": topic_transferred,
		"disposition_bonus": letter.disposition_bonus,
	})

	return {
		"topic_transferred": topic_transferred,
		"disposition_bonus": letter.disposition_bonus,
	}


# -- Reply Generation ----------------------------------------------------------

static func get_reply_chance(
	recipient: L5RCharacterData,
	sender_disposition: int,
) -> float:
	if sender_disposition < HOSTILE_REPLY_THRESHOLD:
		return 0.0

	var chance: float = BASE_REPLY_CHANCE
	if sender_disposition > 0:
		chance += sender_disposition * DISPOSITION_REPLY_BONUS

	if recipient.bushido_virtue == Enums.BushidoVirtue.REI:
		chance += COURTESY_REPLY_BONUS

	return clampf(chance, 0.0, 0.95)


static func should_reply(
	recipient: L5RCharacterData,
	sender_disposition: int,
	rng_roll: int,
) -> bool:
	var chance: float = get_reply_chance(recipient, sender_disposition)
	return rng_roll < int(chance * 100.0)


# -- Completed Exchange (+1 mutual disposition) --------------------------------

static func apply_exchange_bonus(
	sender: L5RCharacterData,
	recipient: L5RCharacterData,
) -> void:
	var s_val: int = sender.disposition_values.get(recipient.character_id, 0)
	sender.disposition_values[recipient.character_id] = s_val + 1
	var r_val: int = recipient.disposition_values.get(sender.character_id, 0)
	recipient.disposition_values[sender.character_id] = r_val + 1


# -- Batch Processing ----------------------------------------------------------
# Processes all pending letters due for delivery on current_ic_day.
# Returns list of delivery result dicts.

static func process_pending_letters(
	pending_letters: Array,
	characters_by_id: Dictionary,
	current_ic_day: int,
	current_season: int,
	action_log: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for item: Variant in pending_letters:
		if item is LetterData and not item.delivered:
			if item.ic_day_arrival <= current_ic_day:
				var recipient: L5RCharacterData = characters_by_id.get(item.recipient_id)
				if recipient == null:
					continue
				var delivery: Dictionary = deliver_letter(
					item, recipient, current_season, action_log
				)
				if not delivery.is_empty():
					delivery["letter_id"] = item.letter_id
					delivery["sender_id"] = item.sender_id
					delivery["recipient_id"] = item.recipient_id
					results.append(delivery)

	return results
