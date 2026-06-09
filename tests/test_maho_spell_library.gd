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


func test_pick_highest_affordable_ml() -> void:
	# Rings 4 → ML capped at 4 by ring support (ML5 needs ring >= 5).
	var s := MahoSpellLibrary.pick_cast_spell(_caster(4))
	assert_eq(int(s["mastery_level"]), 4, "strong caster picks ML4 (ring-bounded)")


func test_pick_ring_bounds_ml() -> void:
	var s := MahoSpellLibrary.pick_cast_spell(_caster(2))
	assert_eq(int(s["mastery_level"]), 2, "ring 2 caster bounded to ML2")


func test_pick_survivability_bounds_ml() -> void:
	# Rings 5 but nearly dead: capacity = Earth*2*8 = 80; leave only 3 wounds room.
	var c := _caster(5, 0)
	c.wounds_taken = CharacterStats.get_total_wound_capacity(c) - 3  # remaining = 3
	var s := MahoSpellLibrary.pick_cast_spell(c)
	# 2*ML <= 3 → ML 1 only (2 wounds); ML2 would cost 4 > 3.
	assert_eq(int(s["mastery_level"]), 1, "self-blood survivability caps ML")


func test_pick_none_when_cannot_afford() -> void:
	var c := _caster(3, 0)
	c.wounds_taken = CharacterStats.get_total_wound_capacity(c) - 1  # remaining 1 < 2
	assert_eq(MahoSpellLibrary.pick_cast_spell(c), {}, "no castable spell when even ML1 kills")
