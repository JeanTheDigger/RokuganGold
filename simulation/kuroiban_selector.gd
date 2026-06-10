class_name KuroibanSelector

# s11.3.5 Kuroiban (Black Watch) — world-gen membership selection.
#
# The Kuroiban is the Scorpion Clan's secretive anti-maho order, "maintained by
# the clan's two shugenja families, the Soshi and the Yogo" (s11.3.5). Unlike the
# Kuni Witch-Hunters and Asako Inquisitors (each a named school), Kuroiban
# membership is covert — it is not a school, so it is carried as a hidden flag
# (L5RCharacterData.is_kuroiban), selected once at world generation. The order is
# small and elite (owner: fixed small count). Drawn from the highest anti-maho
# expertise among living adult Soshi/Yogo shugenja; the existing KUROIBAN_LEADER
# (assigned by WorldPopulationGenerator) is always flagged.
#
# All numeric values below are PROVISIONAL — the GDD establishes the order, its
# families, mandate, and secrecy, but gives no roster size or selection rule.

const KUROIBAN_FAMILIES: Array = ["Soshi", "Yogo"]
const KUROIBAN_MIN: int = 6   # owner-set range 6–10 (PROVISIONAL)
const KUROIBAN_MAX: int = 10
const MIN_ANTI_MAHO_SCORE: int = 1  # must have some Shadowlands/Theology lore


static func _anti_maho_score(c: L5RCharacterData) -> int:
	# Anti-maho expertise: Lore: Shadowlands weighted over Lore: Theology.
	return int(c.skills.get("Lore: Shadowlands", 0)) * 2 + int(c.skills.get("Lore: Theology", 0))


# Flags is_kuroiban on the selected members. Mutates the character objects.
static func select_kuroiban(characters: Array, dice: DiceEngine) -> int:
	var pool: Array = []
	for ch: Variant in characters:
		if not ch is L5RCharacterData:
			continue
		var c: L5RCharacterData = ch
		if CharacterStats.is_dead(c):
			continue
		if c.clan != "Scorpion" or not (c.family in KUROIBAN_FAMILIES):
			continue
		pool.append(c)

	var flagged: int = 0

	# Always flag the existing leader (assigned by WorldPopulationGenerator),
	# regardless of school type or lore.
	for c: L5RCharacterData in pool:
		if c.role_position == RoleRegistry.KUROIBAN_LEADER:
			c.is_kuroiban = true
			flagged += 1

	# Members: shugenja with anti-maho expertise, highest score first.
	var candidates: Array = []
	for c: L5RCharacterData in pool:
		if c.is_kuroiban:
			continue  # already flagged (the leader)
		if c.school_type != Enums.SchoolType.SHUGENJA:
			continue
		if _anti_maho_score(c) < MIN_ANTI_MAHO_SCORE:
			continue
		candidates.append(c)
	candidates.sort_custom(func(a: L5RCharacterData, b: L5RCharacterData) -> bool:
		return _anti_maho_score(a) > _anti_maho_score(b))

	# Target total (6–10); the leader counts toward it.
	var target: int = KUROIBAN_MIN + (dice.roll_die(KUROIBAN_MAX - KUROIBAN_MIN + 1) - 1)
	for c: L5RCharacterData in candidates:
		if flagged >= target:
			break
		c.is_kuroiban = true
		flagged += 1

	return flagged
