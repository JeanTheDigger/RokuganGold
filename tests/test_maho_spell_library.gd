extends GutTest
## s43 maho spell library + highest-affordable-ML selector.

func _caster(rings: int, wounds: int = 0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.reflexes = rings; c.awareness = rings   # Air
	c.stamina = rings; c.willpower = rings     # Earth
	c.agility = rings; c.intelligence = rings  # Fire
	c.strength = rings; c.perception = rings   # Water
	c.wounds_taken = wounds
	return c


func test_library_transcribed() -> void:
	assert_eq(MahoSpellLibrary.MAHO_LIBRARY.size(), 46, "all s43 spells transcribed")
	var b := MahoSpellLibrary.get_spell("bleeding")
	assert_eq(b["mastery_level"], 1)
	assert_eq(b["ring"], Enums.Ring.FIRE)
	assert_eq(b["spell_id"], "bleeding")
	assert_eq(MahoSpellLibrary.get_spell("nope"), {})


func test_spell_ids_by_ml() -> void:
	assert_eq(MahoSpellLibrary.spell_ids_by_ml(6), ["take_the_body"])
	assert_eq(MahoSpellLibrary.spell_ids_by_ml(5).size(), 5)


func test_pick_lowest_ml_fallback() -> void:
	# Victim-blood model: the generic fallback casts the LOWEST Ring-supported ML
	# to minimise the caster's self-Taint, even for a strong caster.
	var s := MahoSpellLibrary.pick_cast_spell(_caster(4))
	assert_eq(int(s["mastery_level"]), 1, "strong caster still falls back to ML1")


func test_pick_lowest_ml_weak_ring() -> void:
	var s := MahoSpellLibrary.pick_cast_spell(_caster(2))
	assert_eq(int(s["mastery_level"]), 1, "lowest ML chosen regardless of Ring strength")


func test_pick_ignores_survivability() -> void:
	# Victim-blood: the caster's own wounds no longer bound the cast.
	var c := _caster(5, 0)
	c.wounds_taken = CharacterStats.get_total_wound_capacity(c) - 1  # nearly dead
	var s := MahoSpellLibrary.pick_cast_spell(c)
	assert_eq(int(s["mastery_level"]), 1, "survivability no longer caps the cast")


func test_pick_none_when_ring_unsupported() -> void:
	# Only fails when no spell's Ring is supported at all (all Rings 0).
	assert_eq(MahoSpellLibrary.pick_cast_spell(_caster(0)), {},
		"no castable spell with no Ring support")
