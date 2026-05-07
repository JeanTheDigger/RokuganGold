class_name DailyConversation
## Daily Conversation System per GDD s12.6.
## Models organic social interaction between co-located characters who know
## each other. Fires once per IC day per qualifying pair. Exchanges one topic
## per character and grants +1 mutual disposition.

const MAX_CONVERSATIONS_PER_DAY: int = 5
const DISPOSITION_BONUS: int = 1
const MIN_DISPOSITION_THRESHOLD: int = 11

const CONVERSATION_PROBABILITY: Array[Array] = [
	[11, 30, 10],
	[31, 45, 15],
	[46, 60, 20],
	[61, 75, 28],
	[76, 90, 35],
	[91, 99, 50],
	[100, 100, 65],
]


# -- Probability Lookup --------------------------------------------------------

static func get_conversation_chance(disposition: int) -> int:
	if disposition < MIN_DISPOSITION_THRESHOLD:
		return 0
	for bracket: Array in CONVERSATION_PROBABILITY:
		if disposition >= bracket[0] and disposition <= bracket[1]:
			return bracket[2]
	return 0


static func get_effective_disposition(char_a: L5RCharacterData, char_b: L5RCharacterData) -> int:
	var disp_a: int = char_a.disposition_values.get(char_b.character_id, 0)
	var disp_b: int = char_b.disposition_values.get(char_a.character_id, 0)
	return mini(disp_a, disp_b)


# -- Conversation Check --------------------------------------------------------

static func should_converse(
	char_a: L5RCharacterData,
	char_b: L5RCharacterData,
	roll: int,
) -> bool:
	var effective_disp: int = get_effective_disposition(char_a, char_b)
	var chance: int = get_conversation_chance(effective_disp)
	return roll < chance


# -- Topic Exchange ------------------------------------------------------------

static func select_topic_to_share(character: L5RCharacterData, rng_value: int) -> int:
	if character.topic_pool.is_empty():
		return -1
	var index: int = rng_value % character.topic_pool.size()
	return character.topic_pool[index]


static func transfer_topic(
	from_char: L5RCharacterData,
	to_char: L5RCharacterData,
	topic: int,
) -> bool:
	if topic < 0:
		return false
	if topic in to_char.topic_pool:
		return false
	to_char.topic_pool.append(topic)
	return true


# -- Disposition Bonus ---------------------------------------------------------

static func apply_disposition_bonus(char_a: L5RCharacterData, char_b: L5RCharacterData) -> void:
	var current_a: int = char_a.disposition_values.get(char_b.character_id, 0)
	char_a.disposition_values[char_b.character_id] = clampi(current_a + DISPOSITION_BONUS, -100, 100)
	var current_b: int = char_b.disposition_values.get(char_a.character_id, 0)
	char_b.disposition_values[char_a.character_id] = clampi(current_b + DISPOSITION_BONUS, -100, 100)


# -- Full Conversation Resolution ----------------------------------------------

static func resolve_conversation(
	char_a: L5RCharacterData,
	char_b: L5RCharacterData,
	rng_a: int,
	rng_b: int,
	current_season: int,
) -> Dictionary:
	var topic_a: int = select_topic_to_share(char_a, rng_a)
	var topic_b: int = select_topic_to_share(char_b, rng_b)

	var transferred_to_b: bool = transfer_topic(char_a, char_b, topic_a)
	var transferred_to_a: bool = transfer_topic(char_b, char_a, topic_b)

	if transferred_to_b and topic_a >= 0:
		InformationSystem.add_knowledge(char_b, InformationSystem.make_entry(
			Enums.KnowledgeSource.DAILY_CONVERSATION,
			"topic_learned",
			{"topic": topic_a, "from_character_id": char_a.character_id},
			current_season,
		))

	if transferred_to_a and topic_b >= 0:
		InformationSystem.add_knowledge(char_a, InformationSystem.make_entry(
			Enums.KnowledgeSource.DAILY_CONVERSATION,
			"topic_learned",
			{"topic": topic_b, "from_character_id": char_b.character_id},
			current_season,
		))

	apply_disposition_bonus(char_a, char_b)

	return {
		"topic_shared_by_a": topic_a,
		"topic_shared_by_b": topic_b,
		"transferred_to_a": transferred_to_a,
		"transferred_to_b": transferred_to_b,
	}


# -- Settlement-Wide Day Resolution --------------------------------------------

static func resolve_settlement_conversations(
	characters: Array[L5RCharacterData],
	rng: Array[int],
	current_season: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var conversation_counts: Dictionary = {}
	var rng_index: int = 0

	for i: int in range(characters.size()):
		for j: int in range(i + 1, characters.size()):
			var char_a: L5RCharacterData = characters[i]
			var char_b: L5RCharacterData = characters[j]

			var count_a: int = conversation_counts.get(char_a.character_id, 0)
			var count_b: int = conversation_counts.get(char_b.character_id, 0)
			if count_a >= MAX_CONVERSATIONS_PER_DAY or count_b >= MAX_CONVERSATIONS_PER_DAY:
				continue

			if rng_index >= rng.size():
				break

			var roll: int = rng[rng_index]
			rng_index += 1

			if not should_converse(char_a, char_b, roll):
				continue

			var rng_a: int = rng[rng_index] if rng_index < rng.size() else 0
			rng_index += 1
			var rng_b: int = rng[rng_index] if rng_index < rng.size() else 0
			rng_index += 1

			var result: Dictionary = resolve_conversation(char_a, char_b, rng_a, rng_b, current_season)
			result["char_a_id"] = char_a.character_id
			result["char_b_id"] = char_b.character_id
			results.append(result)

			conversation_counts[char_a.character_id] = count_a + 1
			conversation_counts[char_b.character_id] = count_b + 1

	return results
