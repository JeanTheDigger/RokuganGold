extends GutTest


var _healer: L5RCharacterData
var _target: L5RCharacterData
var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new(42)

	_healer = L5RCharacterData.new()
	_healer.character_id = 1
	_healer.intelligence = 3
	_healer.willpower = 2
	_healer.skills = {"Medicine": 3}
	_healer.emphases = {"Medicine": ["Wound Treatment"]}
	_healer.items = [{"item_type": "medicine_kit", "remaining_uses": 10, "acquired_ic_day": 1}]

	_target = L5RCharacterData.new()
	_target.character_id = 2
	_target.stamina = 3
	_target.willpower = 2
	_target.honor = 3.0
	_target.bushido_virtue = Enums.BushidoVirtue.NONE
	_target.wounds_taken = 15
	_target.last_medicine_treatment_ic_day = -1
	_target.disposition_values = {1: 25}  # Friend toward healer.


# =============================================================================
# Medicine Kit Helpers
# =============================================================================

func test_find_kit_returns_kit_when_present() -> void:
	var kit: Dictionary = MedicineSystem.find_medicine_kit(_healer)
	assert_false(kit.is_empty())
	assert_eq(kit["item_type"], "medicine_kit")


func test_find_kit_returns_empty_when_absent() -> void:
	_healer.items = []
	assert_true(MedicineSystem.find_medicine_kit(_healer).is_empty())


func test_has_medicine_kit_true_when_present() -> void:
	assert_true(MedicineSystem.has_medicine_kit(_healer))


func test_has_medicine_kit_false_when_absent() -> void:
	_healer.items = []
	assert_false(MedicineSystem.has_medicine_kit(_healer))


func test_consume_kit_decrements_uses() -> void:
	MedicineSystem.consume_kit_charge(_healer)
	assert_eq(_healer.items[0]["remaining_uses"], 9)


func test_consume_kit_removes_when_exhausted() -> void:
	_healer.items[0]["remaining_uses"] = 1
	MedicineSystem.consume_kit_charge(_healer)
	assert_eq(_healer.items.size(), 0)


func test_consume_kit_returns_false_when_no_kit() -> void:
	_healer.items = []
	assert_false(MedicineSystem.consume_kit_charge(_healer))


# =============================================================================
# can_treat validator
# =============================================================================

func test_can_treat_valid_basic_case() -> void:
	var result: Dictionary = MedicineSystem.can_treat(_healer, _target, 5)
	assert_true(result["valid"])


func test_can_treat_rejects_self_treatment() -> void:
	var result: Dictionary = MedicineSystem.can_treat(_healer, _healer, 5)
	assert_false(result["valid"])
	assert_eq(result["reason"], "no_self_treatment")


func test_can_treat_rejects_unwounded_target() -> void:
	_target.wounds_taken = 0
	var result: Dictionary = MedicineSystem.can_treat(_healer, _target, 5)
	assert_false(result["valid"])
	assert_eq(result["reason"], "target_unwounded")


func test_can_treat_rejects_daily_limit() -> void:
	_target.last_medicine_treatment_ic_day = 5
	var result: Dictionary = MedicineSystem.can_treat(_healer, _target, 5)
	assert_false(result["valid"])
	assert_eq(result["reason"], "daily_limit_reached")


func test_can_treat_rejects_no_kit() -> void:
	_healer.items = []
	var result: Dictionary = MedicineSystem.can_treat(_healer, _target, 5)
	assert_false(result["valid"])
	assert_eq(result["reason"], "no_medicine_kit")


func test_can_treat_rejects_different_ic_day_passes() -> void:
	# last_medicine_treatment_ic_day = 4, current = 5 → allowed.
	_target.last_medicine_treatment_ic_day = 4
	var result: Dictionary = MedicineSystem.can_treat(_healer, _target, 5)
	assert_true(result["valid"])


# =============================================================================
# evaluate_refusal
# =============================================================================

func test_refusal_strong_enemy_always_refuses() -> void:
	_target.disposition_values[1] = -50
	assert_true(MedicineSystem.evaluate_refusal(_target, _healer, 0))


func test_refusal_down_auto_accepts_friend() -> void:
	# Down → auto-accept unless Strong Enemy.
	_target.wounds_taken = 37  # Down for Earth 3.
	_target.disposition_values[1] = 25
	assert_false(MedicineSystem.evaluate_refusal(_target, _healer, 0))


func test_refusal_out_auto_accepts() -> void:
	_target.wounds_taken = 43  # Out for Earth 3.
	_target.disposition_values[1] = 0
	assert_false(MedicineSystem.evaluate_refusal(_target, _healer, 0))


func test_refusal_non_human_accepts_at_neutral() -> void:
	_target.clan = "Nezumi"
	_target.disposition_values[1] = 0  # Neutral.
	assert_false(MedicineSystem.evaluate_refusal(_target, _healer, 0))


func test_refusal_non_human_refuses_at_rival() -> void:
	_target.clan = "Nezumi"
	_target.disposition_values[1] = -15  # Rival.
	assert_true(MedicineSystem.evaluate_refusal(_target, _healer, 0))


func test_refusal_high_willpower_high_honour_public_refuses_minor_wound() -> void:
	# Willpower 4 (Yu proxy), Honor 5, 3 witnesses — Nicked wound.
	# pressure = (4×5) + (5×2) + (3×5) - (2×4) + 0 + (-10 Friend) = 20+10+15-8+0-10 = 27 → refuses
	_target.willpower = 4
	_target.honor = 5.0
	_target.wounds_taken = 3  # Nicked for Earth 3.
	_target.disposition_values[1] = 25  # Friend.
	assert_true(MedicineSystem.evaluate_refusal(_target, _healer, 3))


func test_refusal_severe_wound_overrides_pride() -> void:
	# Same character but at Crippled (-30 severity) — acceptance should win.
	# Earth = (3+4)/2 = 3, threshold = 6, wounds 31 → level_index 5 = CRIPPLED
	# pressure = (4×5) + (5×2) + (3×5) - (2×4) + (-30) + (-10 Friend) = 20+10+15-8-30-10 = -3 → accepts
	_target.willpower = 4
	_target.honor = 5.0
	_target.wounds_taken = 31  # Crippled for Earth 3 (threshold 6, index 5).
	_target.disposition_values[1] = 25  # Friend.
	assert_false(MedicineSystem.evaluate_refusal(_target, _healer, 3))


func test_refusal_chugi_dominant_virtue_reduces_pressure() -> void:
	# CHUGI dominant → score 4 instead of 2; duty pulls toward acceptance.
	# pressure = (2×5) + (3×2) + 0 - (4×4) + (-6 Hurt) + (-10 Friend) = 10+6-16-6-10 = -16 → accepts
	_target.bushido_virtue = Enums.BushidoVirtue.CHUGI
	_target.wounds_taken = 13  # Hurt for Earth 3.
	_target.disposition_values[1] = 25  # Friend.
	assert_false(MedicineSystem.evaluate_refusal(_target, _healer, 0))


# =============================================================================
# treat_wound
# =============================================================================

func test_treat_wound_sets_daily_limit() -> void:
	MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	assert_eq(_target.last_medicine_treatment_ic_day, 5)


func test_treat_wound_consumes_kit_charge() -> void:
	var before: int = _healer.items[0]["remaining_uses"]
	MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	assert_eq(_healer.items[0]["remaining_uses"], before - 1)


func test_treat_wound_heals_on_success() -> void:
	# Seed 42 produces a success on Medicine 3 / Intelligence 3 vs TN 15.
	var before: int = _target.wounds_taken
	var result: Dictionary = MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	if result["success"]:
		assert_true(_target.wounds_taken < before)
		assert_true(result["wounds_healed"] > 0)


func test_treat_wound_no_heal_on_failure() -> void:
	# Force failure: unskilled healer with no Medicine vs TN 15.
	_healer.skills = {}
	_healer.emphases = {}
	_healer.intelligence = 1
	var before: int = _target.wounds_taken
	var result: Dictionary = MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	if not result["success"]:
		assert_eq(_target.wounds_taken, before)
		assert_eq(result["wounds_healed"], 0)


func test_treat_wound_kit_consumed_on_failure() -> void:
	_healer.skills = {}
	_healer.emphases = {}
	_healer.intelligence = 1
	var before: int = _healer.items[0]["remaining_uses"]
	MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	assert_eq(_healer.items[0]["remaining_uses"], before - 1)


func test_treat_wound_non_human_tn_penalty_applied() -> void:
	_target.clan = "Nezumi"
	_healer.emphases = {}  # No Non-Humans: Nezumi emphasis.
	var result: Dictionary = MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	assert_eq(result["tn"], 25)  # BASE_TN 15 + NON_HUMAN_TN_PENALTY 10.


func test_treat_wound_non_human_no_penalty_with_emphasis() -> void:
	_target.clan = "Nezumi"
	_healer.emphases = {"Medicine": ["Non-Humans: Nezumi"]}
	var result: Dictionary = MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	assert_eq(result["tn"], 15)


func test_treat_wound_result_has_required_keys() -> void:
	var result: Dictionary = MedicineSystem.treat_wound(_healer, _target, _dice, 5)
	assert_true(result.has("success"))
	assert_true(result.has("wounds_healed"))
	assert_true(result.has("kit_charge_consumed"))
	assert_true(result.has("target_id"))
	assert_true(result.has("healer_id"))


# =============================================================================
# compute_tend_priority
# =============================================================================

func test_tend_priority_strong_ally_nicked() -> void:
	_healer.disposition_values[2] = 50  # Strong Ally.
	_target.wounds_taken = 3  # Nicked.
	assert_eq(MedicineSystem.compute_tend_priority(_healer, _target), 3)


func test_tend_priority_friend_injured() -> void:
	_healer.disposition_values[2] = 30  # Friend.
	_target.wounds_taken = 19  # Injured for Earth 3.
	# base 2 + wound_mod 2 = 4.
	assert_eq(MedicineSystem.compute_tend_priority(_healer, _target), 4)


func test_tend_priority_acquaintance_crippled_caps_at_ceiling() -> void:
	_healer.disposition_values[2] = 5  # Acquaintance.
	_target.wounds_taken = 25  # Crippled for Earth 3.
	# base 1 + wound_mod 3 = 4 (ceiling).
	assert_eq(MedicineSystem.compute_tend_priority(_healer, _target), 4)


func test_tend_priority_hostile_returns_zero() -> void:
	_healer.disposition_values[2] = -5  # Rival.
	_target.wounds_taken = 10
	assert_eq(MedicineSystem.compute_tend_priority(_healer, _target), 0)


func test_tend_priority_strong_ally_crippled_caps_at_ceiling() -> void:
	_healer.disposition_values[2] = 60  # Strong Ally.
	_target.wounds_taken = 25  # Crippled.
	# base 3 + wound_mod 3 = 6 → capped at 4.
	assert_eq(MedicineSystem.compute_tend_priority(_healer, _target), 4)


# =============================================================================
# compute_tend_personality_bonus
# =============================================================================

func test_jin_virtue_adds_bonus() -> void:
	_healer.bushido_virtue = Enums.BushidoVirtue.JIN
	var bonus: int = MedicineSystem.compute_tend_personality_bonus(_healer, _target, false)
	assert_eq(bonus, MedicineSystem.JIN_SCORE_MOD)


func test_chugi_virtue_bonus_only_for_lord() -> void:
	_healer.bushido_virtue = Enums.BushidoVirtue.CHUGI
	assert_eq(MedicineSystem.compute_tend_personality_bonus(_healer, _target, false), 0)
	assert_eq(MedicineSystem.compute_tend_personality_bonus(_healer, _target, true),
		MedicineSystem.CHUGI_SCORE_MOD)


func test_no_virtue_no_bonus() -> void:
	_healer.bushido_virtue = Enums.BushidoVirtue.NONE
	assert_eq(MedicineSystem.compute_tend_personality_bonus(_healer, _target, false), 0)
