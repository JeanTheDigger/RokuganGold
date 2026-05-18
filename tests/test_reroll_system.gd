extends GutTest
## Tests for RerollSystem per GDD s29.15.24.
## Covers: self-reroll entry creation, charge consumption, skill swap,
## granted reroll with bonus dice, failure penalty passthrough,
## weekly refresh, expiry cleanup.


var _character: L5RCharacterData
var _dice_engine: DiceEngine


func before_each() -> void:
	_character = _make_character()
	_dice_engine = DiceEngine.new(42)


func _make_character() -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Test Courtier"
	c.clan = "Crane"
	c.family = "Doji"
	c.awareness = 3
	c.intelligence = 3
	c.perception = 2
	c.reflexes = 2
	c.agility = 2
	c.skills = {"Courtier": 3, "Etiquette": 3, "Sincerity": 2, "Commerce": 1}
	c.emphases = {}
	c.wounds_taken = 0
	c.self_reroll = []
	c.granted_reroll = []
	return c


# -- Self-Reroll Entry Creation ------------------------------------------------

func test_create_self_reroll_entry_fields() -> void:
	var entry: Dictionary = RerollSystem.create_self_reroll_entry(
		"Yasuki R2", ["Commerce", "Sincerity"], 2,
	)
	assert_eq(entry["source"], "Yasuki R2")
	assert_eq(entry["eligible_skills"], ["Commerce", "Sincerity"])
	assert_eq(entry["charges_current"], 2)
	assert_eq(entry["charges_max"], 2)
	assert_eq(entry["refresh"], "weekly")
	assert_eq(entry["skill_swap"], "")


func test_create_self_reroll_entry_with_skill_swap() -> void:
	var entry: Dictionary = RerollSystem.create_self_reroll_entry(
		"Kasuga R5", ["Commerce"], 1, "weekly", "Sincerity",
	)
	assert_eq(entry["skill_swap"], "Sincerity")


# -- Self-Reroll: Find ----------------------------------------------------------

func test_find_self_reroll_returns_index_when_eligible() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce", "Sincerity"], 2),
	)
	var idx: int = RerollSystem.find_self_reroll(_character, "Commerce")
	assert_eq(idx, 0)


func test_find_self_reroll_returns_neg1_when_no_match() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 2),
	)
	var idx: int = RerollSystem.find_self_reroll(_character, "Etiquette")
	assert_eq(idx, -1)


func test_find_self_reroll_returns_neg1_when_charges_depleted() -> void:
	var entry: Dictionary = RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 1)
	entry["charges_current"] = 0
	_character.self_reroll.append(entry)
	var idx: int = RerollSystem.find_self_reroll(_character, "Commerce")
	assert_eq(idx, -1)


func test_find_self_reroll_skips_depleted_returns_second() -> void:
	var depleted: Dictionary = RerollSystem.create_self_reroll_entry("Source A", ["Commerce"], 1)
	depleted["charges_current"] = 0
	_character.self_reroll.append(depleted)
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Source B", ["Commerce"], 2),
	)
	var idx: int = RerollSystem.find_self_reroll(_character, "Commerce")
	assert_eq(idx, 1)


# -- Self-Reroll: Apply ---------------------------------------------------------

func test_apply_self_reroll_decrements_charge() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 2),
	)
	RerollSystem.apply_self_reroll(_character, 0, _dice_engine, "Commerce", 15)
	assert_eq(_character.self_reroll[0]["charges_current"], 1)


func test_apply_self_reroll_marks_result_as_rerolled() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 2),
	)
	var result: Dictionary = RerollSystem.apply_self_reroll(
		_character, 0, _dice_engine, "Commerce", 15,
	)
	assert_true(result.get("rerolled", false))
	assert_eq(result.get("reroll_source", ""), "Yasuki R2")


func test_apply_self_reroll_uses_skill_swap() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Kasuga R5", ["Commerce"], 1, "weekly", "Sincerity"),
	)
	var result: Dictionary = RerollSystem.apply_self_reroll(
		_character, 0, _dice_engine, "Commerce", 15,
	)
	assert_eq(result.get("skill_swapped_to", ""), "Sincerity")
	assert_eq(result["skill"], "Sincerity")


func test_apply_self_reroll_no_swap_uses_original_skill() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 2),
	)
	var result: Dictionary = RerollSystem.apply_self_reroll(
		_character, 0, _dice_engine, "Commerce", 15,
	)
	assert_eq(result["skill"], "Commerce")
	assert_false(result.has("skill_swapped_to"))


# -- Self-Reroll: Try (convenience wrapper) ------------------------------------

func test_try_self_reroll_returns_original_on_success() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 2),
	)
	var original: Dictionary = {"success": true, "total": 20}
	var result: Dictionary = RerollSystem.try_self_reroll(
		_character, _dice_engine, "Commerce", 15, original,
	)
	assert_eq(result, original)
	assert_eq(_character.self_reroll[0]["charges_current"], 2)


func test_try_self_reroll_returns_original_when_no_entry() -> void:
	var original: Dictionary = {"success": false, "total": 5}
	var result: Dictionary = RerollSystem.try_self_reroll(
		_character, _dice_engine, "Commerce", 15, original,
	)
	assert_eq(result, original)


func test_try_self_reroll_rerolls_on_failure_with_entry() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 2),
	)
	var original: Dictionary = {"success": false, "total": 5}
	var result: Dictionary = RerollSystem.try_self_reroll(
		_character, _dice_engine, "Commerce", 15, original,
	)
	assert_true(result.get("rerolled", false))
	assert_eq(_character.self_reroll[0]["charges_current"], 1)


# -- Granted Reroll Entry Creation ---------------------------------------------

func test_create_granted_reroll_entry_fields() -> void:
	var entry: Dictionary = RerollSystem.create_granted_reroll_entry(
		10, "Ikoma R4", 1, "unkept", 2, 30,
	)
	assert_eq(entry["source_id"], 10)
	assert_eq(entry["source_technique"], "Ikoma R4")
	assert_eq(entry["bonus_dice"], 1)
	assert_eq(entry["bonus_type"], "unkept")
	assert_eq(entry["uses"], 2)
	assert_eq(entry["expires"], 30)
	assert_true(entry["failure_penalty"].is_empty())


func test_create_granted_reroll_entry_with_failure_penalty() -> void:
	var penalty: Dictionary = {"type": "honor_loss", "amount": 0.5}
	var entry: Dictionary = RerollSystem.create_granted_reroll_entry(
		10, "Ikoma R4", 1, "unkept", 2, 30, penalty,
	)
	assert_eq(entry["failure_penalty"]["type"], "honor_loss")
	assert_eq(entry["failure_penalty"]["amount"], 0.5)


# -- Granted Reroll: Find -------------------------------------------------------

func test_find_granted_reroll_returns_index() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	var idx: int = RerollSystem.find_granted_reroll(_character, 20)
	assert_eq(idx, 0)


func test_find_granted_reroll_neg1_when_expired() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	var idx: int = RerollSystem.find_granted_reroll(_character, 31)
	assert_eq(idx, -1)


func test_find_granted_reroll_neg1_when_uses_depleted() -> void:
	var entry: Dictionary = RerollSystem.create_granted_reroll_entry(
		10, "Ikoma R4", 1, "unkept", 0, 30,
	)
	_character.granted_reroll.append(entry)
	var idx: int = RerollSystem.find_granted_reroll(_character, 20)
	assert_eq(idx, -1)


func test_find_granted_reroll_on_exact_expiry_day() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 1, 30),
	)
	var idx: int = RerollSystem.find_granted_reroll(_character, 30)
	assert_eq(idx, 0)


# -- Granted Reroll: Apply -------------------------------------------------------

func test_apply_granted_reroll_decrements_uses() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	RerollSystem.apply_granted_reroll(_character, 0, _dice_engine, "Courtier", 15)
	assert_eq(_character.granted_reroll[0]["uses"], 1)


func test_apply_granted_reroll_marks_result() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	var result: Dictionary = RerollSystem.apply_granted_reroll(
		_character, 0, _dice_engine, "Courtier", 15,
	)
	assert_true(result.get("rerolled", false))
	assert_eq(result.get("reroll_source", ""), "Ikoma R4")
	assert_eq(result.get("granted_by", -1), 10)


func test_apply_granted_reroll_failure_penalty_attached_on_fail() -> void:
	var penalty: Dictionary = {"type": "honor_loss", "amount": 0.5}
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 0, "unkept", 2, 30, penalty),
	)
	_dice_engine.set_seed(1)
	var result: Dictionary = RerollSystem.apply_granted_reroll(
		_character, 0, _dice_engine, "Courtier", 999,
	)
	if not result.get("success", false):
		assert_true(result.has("failure_penalty"))
		assert_eq(result["failure_penalty"]["type"], "honor_loss")


func test_apply_granted_reroll_no_penalty_on_success() -> void:
	var penalty: Dictionary = {"type": "honor_loss", "amount": 0.5}
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 0, "unkept", 2, 30, penalty),
	)
	var result: Dictionary = RerollSystem.apply_granted_reroll(
		_character, 0, _dice_engine, "Courtier", 1,
	)
	if result.get("success", false):
		assert_false(result.has("failure_penalty"))


# -- Granted Reroll: Try (convenience wrapper) ---------------------------------

func test_try_granted_reroll_returns_original_on_success() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	var original: Dictionary = {"success": true, "total": 20}
	var result: Dictionary = RerollSystem.try_granted_reroll(
		_character, _dice_engine, "Courtier", 15, original, 20,
	)
	assert_eq(result, original)
	assert_eq(_character.granted_reroll[0]["uses"], 2)


func test_try_granted_reroll_rerolls_on_failure() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	var original: Dictionary = {"success": false, "total": 5}
	var result: Dictionary = RerollSystem.try_granted_reroll(
		_character, _dice_engine, "Courtier", 15, original, 20,
	)
	assert_true(result.get("rerolled", false))
	assert_eq(_character.granted_reroll[0]["uses"], 1)


# -- Weekly Refresh -------------------------------------------------------------

func test_refresh_weekly_charges_restores_depleted() -> void:
	var entry: Dictionary = RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 3)
	entry["charges_current"] = 0
	_character.self_reroll.append(entry)
	var refreshed: int = RerollSystem.refresh_weekly_charges(_character)
	assert_eq(refreshed, 1)
	assert_eq(_character.self_reroll[0]["charges_current"], 3)


func test_refresh_weekly_charges_skips_full() -> void:
	_character.self_reroll.append(
		RerollSystem.create_self_reroll_entry("Yasuki R2", ["Commerce"], 3),
	)
	var refreshed: int = RerollSystem.refresh_weekly_charges(_character)
	assert_eq(refreshed, 0)
	assert_eq(_character.self_reroll[0]["charges_current"], 3)


func test_refresh_weekly_charges_multiple_entries() -> void:
	var e1: Dictionary = RerollSystem.create_self_reroll_entry("Source A", ["Commerce"], 2)
	e1["charges_current"] = 1
	var e2: Dictionary = RerollSystem.create_self_reroll_entry("Source B", ["Sincerity"], 3)
	e2["charges_current"] = 0
	_character.self_reroll.append(e1)
	_character.self_reroll.append(e2)
	var refreshed: int = RerollSystem.refresh_weekly_charges(_character)
	assert_eq(refreshed, 2)
	assert_eq(_character.self_reroll[0]["charges_current"], 2)
	assert_eq(_character.self_reroll[1]["charges_current"], 3)


# -- Granted Reroll Expiry Cleanup ----------------------------------------------

func test_expire_granted_rerolls_removes_expired() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 20),
	)
	var removed: int = RerollSystem.expire_granted_rerolls(_character, 21)
	assert_eq(removed, 1)
	assert_eq(_character.granted_reroll.size(), 0)


func test_expire_granted_rerolls_keeps_valid() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "Ikoma R4", 1, "unkept", 2, 30),
	)
	var removed: int = RerollSystem.expire_granted_rerolls(_character, 20)
	assert_eq(removed, 0)
	assert_eq(_character.granted_reroll.size(), 1)


func test_expire_granted_rerolls_removes_zero_uses() -> void:
	var entry: Dictionary = RerollSystem.create_granted_reroll_entry(
		10, "Ikoma R4", 1, "unkept", 0, 30,
	)
	_character.granted_reroll.append(entry)
	var removed: int = RerollSystem.expire_granted_rerolls(_character, 20)
	assert_eq(removed, 1)
	assert_eq(_character.granted_reroll.size(), 0)


func test_expire_granted_rerolls_mixed() -> void:
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(10, "A", 1, "unkept", 2, 20),
	)
	_character.granted_reroll.append(
		RerollSystem.create_granted_reroll_entry(11, "B", 0, "unkept", 1, 50),
	)
	var zero_uses: Dictionary = RerollSystem.create_granted_reroll_entry(
		12, "C", 1, "unkept", 0, 50,
	)
	_character.granted_reroll.append(zero_uses)
	var removed: int = RerollSystem.expire_granted_rerolls(_character, 25)
	assert_eq(removed, 2)
	assert_eq(_character.granted_reroll.size(), 1)
	assert_eq(_character.granted_reroll[0]["source_technique"], "B")
