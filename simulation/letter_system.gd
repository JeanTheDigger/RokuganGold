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
const MEETING_ACCEPT_DISPOSITION: int = 0      # PROVISIONAL: non-hostile disposition needed

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

# Forgery Rank 5 mastery bonus
const FORGERY_RANK5_DETECT_BONUS: int = 1


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
	if is_lord:
		return false
	return letters_sent_today < FREE_LETTERS_PER_DAY


static func can_send_batch(character: L5RCharacterData, is_lord: bool) -> bool:
	if is_lord:
		return character.civilian_orders_remaining > 0
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
	topic: int,
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
	topics_by_id: Dictionary = {},
) -> Dictionary:
	if letter.delivered:
		return {}

	letter.delivered = true

	# Transfer topic to recipient or refresh momentum if already known
	var topic_transferred: bool = false
	if letter.topic >= 0:
		if letter.topic not in recipient.topic_pool:
			recipient.topic_pool.append(letter.topic)
			topic_transferred = true
			InformationSystem.add_knowledge(recipient, InformationSystem.make_entry(
				Enums.KnowledgeSource.LETTER,
				"topic_learned",
				{
					"topic": letter.topic,
					"from_character_id": letter.sender_id,
					"letter_id": letter.letter_id,
				},
				current_season,
			))
		_refresh_topic_momentum(letter.topic, topics_by_id)

	# Apply disposition bonus from calligraphy quality
	if letter.disposition_bonus > 0:
		var current: int = recipient.disposition_values.get(letter.sender_id, 0)
		recipient.disposition_values[letter.sender_id] = clampi(current + letter.disposition_bonus, -100, 100)

	action_log.append({
		"character_id": letter.sender_id,
		"action_id": "WRITE_LETTER",
		"target_npc_id": recipient.character_id,
		"target_province_id": -1,
		"ic_day": letter.ic_day_arrival,
		"season": current_season,
		"success": true,
		"skill_used": "Calligraphy",
		"is_order": false,
		"roll_result": 0,
		"tn": 0,
		"observable_effect": false,
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
	sender.disposition_values[recipient.character_id] = clampi(s_val + 1, -100, 100)
	var r_val: int = recipient.disposition_values.get(sender.character_id, 0)
	recipient.disposition_values[sender.character_id] = clampi(r_val + 1, -100, 100)


# -- Forgery Auto-Detection on Receipt -----------------------------------------
# Per GDD s12.7: when a letter arrives, the recipient automatically performs a
# silent detection check IF they have previously received an authentic letter
# from the apparent sender (providing a reference for comparison).

static func has_prior_correspondence(
	recipient: L5RCharacterData,
	apparent_sender_id: int,
	pending_letters: Array[LetterData],
) -> bool:
	for item: LetterData in pending_letters:
		if item is LetterData and item.delivered and not item.is_forged:
			if item.recipient_id == recipient.character_id \
				and item.sender_id == apparent_sender_id:
				return true
	return false


static func auto_detect_forgery(
	letter: LetterData,
	recipient: L5RCharacterData,
	dice_engine: DiceEngine,
	pending_letters: Array[LetterData],
) -> bool:
	if not letter.is_forged:
		return false
	if not has_prior_correspondence(recipient, letter.sender_id, pending_letters):
		return false
	var check: Dictionary = SkillResolver.resolve_skill_check(
		recipient, dice_engine, "Investigation", letter.forgery_tn,
	)
	return check.get("success", false)


static func deliberate_examine_letter(
	letter: LetterData,
	examiner: L5RCharacterData,
	dice_engine: DiceEngine,
	pending_letters: Array[LetterData],
) -> Dictionary:
	if not has_prior_correspondence(examiner, letter.sender_id, pending_letters):
		return {"detected": false, "no_reference": true}
	if not letter.is_forged:
		return {"detected": false, "authentic": true}
	var forgery_rank: int = examiner.skills.get("Forgery", 0)
	var extra_rolled: int = FORGERY_RANK5_DETECT_BONUS if forgery_rank >= 5 else 0
	var check: Dictionary = SkillResolver.resolve_skill_check(
		examiner, dice_engine, "Investigation", letter.forgery_tn,
		0, "", Enums.Trait.NONE, extra_rolled,
	)
	var detected: bool = check.get("success", false)
	if detected:
		letter.forgery_detected = true
	return {
		"detected": detected,
		"roll_total": check.get("total", 0),
		"forgery_tn": letter.forgery_tn,
	}


# -- Blockade Check ------------------------------------------------------------
# Per GDD s12.7: letters with ocean segments are blocked when a naval blockade
# is active between the sender and recipient clans.

static func is_blocked_by_blockade(
	letter: LetterData,
	active_wars: Array[Variant] = [],
) -> bool:
	if letter.ocean_segments <= 0:
		return false
	for war: Variant in active_wars:
		if war is Dictionary:
			var has_naval: bool = war.get("has_naval_component", false)
			if not has_naval:
				continue
			return true
		elif war.has_method("get"):
			return true
	return false


# -- Dead Recipient Check ------------------------------------------------------

static func is_recipient_dead(
	recipient: L5RCharacterData,
) -> bool:
	return CharacterStats.is_dead(recipient)


# -- Batch Processing ----------------------------------------------------------
# Processes all pending letters due for delivery on current_ic_day.
# Returns list of delivery result dicts.

static func process_pending_letters(
	pending_letters: Array[LetterData],
	characters_by_id: Dictionary,
	current_ic_day: int,
	current_season: int,
	action_log: Array[Dictionary],
	active_wars: Array[Variant] = [],
	dice_engine: DiceEngine = null,
	topics_by_id: Dictionary = {},
) -> Array:
	var results: Array[Dictionary] = []

	for item: LetterData in pending_letters:
		if item is LetterData and not item.delivered:
			if item.ic_day_arrival <= current_ic_day:
				var recipient: L5RCharacterData = characters_by_id.get(item.recipient_id)
				if recipient == null:
					continue
				if is_recipient_dead(recipient):
					item.delivered = true
					results.append({
						"letter_id": item.letter_id,
						"sender_id": item.sender_id,
						"recipient_id": item.recipient_id,
						"topic": item.topic,
						"undeliverable": true,
						"reason": "recipient_dead",
					})
					continue
				if item.ocean_segments > 0 and is_blocked_by_blockade(item, active_wars):
					item.blocked_by_blockade = true
					continue
				if item.is_forged and dice_engine != null:
					var detected: bool = auto_detect_forgery(
						item, recipient, dice_engine, pending_letters
					)
					if detected:
						item.forgery_detected = true
						item.delivered = true
						results.append({
							"letter_id": item.letter_id,
							"sender_id": item.sender_id,
							"recipient_id": item.recipient_id,
							"topic": item.topic,
							"is_forged": true,
							"forged_sender_id": item.forged_sender_id,
							"forgery_detected": true,
						})
						continue
				var delivery: Dictionary = deliver_letter(
					item, recipient, current_season, action_log, topics_by_id
				)
				if not delivery.is_empty():
					delivery["letter_id"] = item.letter_id
					delivery["sender_id"] = item.sender_id
					delivery["recipient_id"] = item.recipient_id
					delivery["topic"] = item.topic
					if item.is_forged:
						delivery["is_forged"] = true
						delivery["forged_sender_id"] = item.forged_sender_id
						delivery["forgery_detected"] = false
					if item.is_reply:
						var sender_char: L5RCharacterData = characters_by_id.get(item.sender_id)
						if sender_char != null:
							apply_exchange_bonus(sender_char, recipient)
							delivery["exchange_bonus_applied"] = true
					results.append(delivery)

	return results


# -- Reply Processing ---------------------------------------------------------
# Generates reply letters for delivered letters. Called after process_pending_letters.

static func generate_replies(
	delivery_results: Array[Dictionary],
	pending_letters: Array[LetterData],
	characters_by_id: Dictionary,
	ic_day: int,
	dice_engine: DiceEngine,
	next_letter_id: Array[int],
) -> Array:
	var replies: Array[LetterData] = []

	for result: Dictionary in delivery_results:
		if result.get("undeliverable", false):
			continue
		if result.get("forgery_detected", false):
			continue
		var recipient_id: int = result.get("recipient_id", -1)
		var sender_id: int = result.get("sender_id", -1)
		var recipient: L5RCharacterData = characters_by_id.get(recipient_id)
		var sender: L5RCharacterData = characters_by_id.get(sender_id)
		if recipient == null or sender == null:
			continue
		if CharacterStats.is_dead(recipient) or CharacterStats.is_dead(sender):
			continue

		var disposition: int = recipient.disposition_values.get(sender_id, 0)
		var rng_roll: int = dice_engine.roll_and_keep(1, 1, false).total % 100
		if not should_reply(recipient, disposition, rng_roll):
			continue

		var reply_topic: int = _pick_reply_topic(recipient, result.get("topic", -1))
		var original_letter: LetterData = _find_letter_by_id(
			pending_letters, result.get("letter_id", -1)
		)
		var prov_dist: int = 0
		var mtn: int = 0
		var wz: int = 0
		var ocean: int = 0
		var miya: bool = false
		if original_letter != null:
			prov_dist = original_letter.province_distance
			mtn = original_letter.mountain_provinces
			wz = original_letter.warzone_provinces
			ocean = original_letter.ocean_segments
			miya = original_letter.has_miya_route

		var lid: int = next_letter_id[0]
		next_letter_id[0] = lid + 1

		var reply: LetterData = write_letter(
			lid, recipient, sender_id, reply_topic, ic_day, dice_engine,
			prov_dist, mtn, wz, ocean, miya,
			Enums.Trait.AWARENESS, true,
		)
		if original_letter != null:
			if original_letter.is_forged and not original_letter.forgery_detected:
				reply.reply_to_forged = true
				reply.original_forger_id = original_letter.forged_sender_id
			if original_letter.meeting_proposal:
				if disposition >= MEETING_ACCEPT_DISPOSITION:
					reply.meeting_proposal = true
					reply.meeting_settlement_id = original_letter.meeting_settlement_id
					reply.meeting_deadline_ic_day = original_letter.meeting_deadline_ic_day
		replies.append(reply)

	return replies


static func _pick_reply_topic(
	recipient: L5RCharacterData,
	original_topic: int,
) -> int:
	if recipient.topic_pool.is_empty():
		return original_topic
	if original_topic >= 0 and original_topic in recipient.topic_pool:
		return original_topic
	return recipient.topic_pool[0]


static func _find_letter_by_id(pending_letters: Array, letter_id: int) -> LetterData:
	for item: LetterData in pending_letters:
		if item is LetterData and item.letter_id == letter_id:
			return item
	return null


static func _refresh_topic_momentum(topic_id: int, topics_by_id: Dictionary) -> void:
	if topic_id < 0 or topics_by_id.is_empty():
		return
	var topic: TopicData = topics_by_id.get(topic_id)
	if topic != null:
		topic.discussion_count_this_day += 1


# -- Unblock Letters on Blockade Lift ------------------------------------------

static func unblock_letters(pending_letters: Array) -> int:
	var count: int = 0
	for item: LetterData in pending_letters:
		if item is LetterData and item.blocked_by_blockade and not item.delivered:
			item.blocked_by_blockade = false
			count += 1
	return count
