extends GutTest
## Tests for MahoSystem per GDD s43 and s57.47.7.
## Covers: blood costs, wound application, taint gain, honor loss,
## PTL increment, crime record, and caster-as-own-blood-source.


var _caster: L5RCharacterData
var _blood_source: L5RCharacterData
var _province: ProvinceData


func before_each() -> void:
	_caster = L5RCharacterData.new()
	_caster.character_id = 1
	_caster.character_name = "Bloodspeaker Test"
	_caster.clan = "Scorpion"
	_caster.family = "Soshi"
	_caster.school = "Soshi Shugenja"
	_caster.school_type = Enums.SchoolType.SHUGENJA
	_caster.stamina = 3
	_caster.willpower = 3
	_caster.strength = 2
	_caster.perception = 2
	_caster.agility = 2
	_caster.intelligence = 3
	_caster.reflexes = 2
	_caster.awareness = 3
	_caster.void_ring = 2
	_caster.honor = 5.0
	_caster.glory = 2.0
	_caster.status = 2.0
	_caster.taint = 0.0
	_caster.wounds_taken = 0
	_caster.armor_reduction = 3
	_caster.skills = {"Spellcraft": 3, "Calligraphy": 2}

	_blood_source = L5RCharacterData.new()
	_blood_source.character_id = 2
	_blood_source.character_name = "Blood Source"
	_blood_source.stamina = 3
	_blood_source.willpower = 2
	_blood_source.wounds_taken = 0
	_blood_source.armor_reduction = 5

	_province = ProvinceData.new()
	_province.province_id = 99
	_province.province_taint_level = 0.0


# =============================================================================
# Blood Cost Helpers
# =============================================================================

func test_base_blood_cost_is_twice_mastery_level() -> void:
	assert_eq(MahoSystem.base_blood_cost(1), 2)
	assert_eq(MahoSystem.base_blood_cost(2), 4)
	assert_eq(MahoSystem.base_blood_cost(3), 6)
	assert_eq(MahoSystem.base_blood_cost(5), 10)


func test_raise_blood_cost_is_mastery_times_two_times_raises() -> void:
	assert_eq(MahoSystem.raise_blood_cost(1, 0), 0)
	assert_eq(MahoSystem.raise_blood_cost(1, 1), 2)
	assert_eq(MahoSystem.raise_blood_cost(1, 3), 6)
	assert_eq(MahoSystem.raise_blood_cost(2, 2), 8)
	assert_eq(MahoSystem.raise_blood_cost(3, 1), 6)


func test_total_blood_cost_adds_base_and_raise_costs() -> void:
	assert_eq(MahoSystem.total_blood_cost(1, 0), 2)
	assert_eq(MahoSystem.total_blood_cost(1, 2), 6)
	assert_eq(MahoSystem.total_blood_cost(2, 1), 8)
	assert_eq(MahoSystem.total_blood_cost(3, 3), 24)


# =============================================================================
# Taint Gain
# =============================================================================

func test_taint_gain_is_mastery_minus_one_minimum_one() -> void:
	assert_eq(MahoSystem.taint_gain(1), 1, "ML 1 → taint 1 (minimum 1)")
	assert_eq(MahoSystem.taint_gain(2), 1, "ML 2 → taint 1")
	assert_eq(MahoSystem.taint_gain(3), 2, "ML 3 → taint 2")
	assert_eq(MahoSystem.taint_gain(4), 3, "ML 4 → taint 3")
	assert_eq(MahoSystem.taint_gain(5), 4, "ML 5 → taint 4")
	assert_eq(MahoSystem.taint_gain(6), 5, "ML 6 → taint 5")


# =============================================================================
# resolve_cast — Blood Wounds Applied to blood_source
# =============================================================================

func test_resolve_cast_applies_wounds_to_blood_source() -> void:
	_blood_source.wounds_taken = 0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 0, 100, 10, "Province_99"
	)
	assert_eq(_blood_source.wounds_taken, 4,
		"ML2 base cast = 4 wounds to blood_source (bypasses armor)")


func test_resolve_cast_bypasses_armor_on_blood_source() -> void:
	_blood_source.armor_reduction = 10
	_blood_source.wounds_taken = 0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 101, 10, "Province_99"
	)
	assert_eq(_blood_source.wounds_taken, 2,
		"Blood-letting bypasses armor reduction — ML1 = 2 wounds regardless")


func test_resolve_cast_raises_increase_blood_wounds() -> void:
	_blood_source.wounds_taken = 0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 2, 102, 10, "Province_99"
	)
	# base = 2, raises = 2 × 1 × 2 = 4, total = 6
	assert_eq(_blood_source.wounds_taken, 6,
		"2 raises at ML1 = 6 total blood wounds")


func test_resolve_cast_returns_blood_wounds_count() -> void:
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 3, 1, 103, 10, "Province_99"
	)
	# ML3 base = 6, 1 raise = 6, total = 12
	assert_eq(result["blood_wounds"], 12)


func test_resolve_cast_does_not_apply_wounds_to_caster_when_separate_source() -> void:
	_caster.wounds_taken = 0
	_blood_source.wounds_taken = 0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 0, 104, 10, "Province_99"
	)
	assert_eq(_caster.wounds_taken, 0,
		"When blood_source is separate, caster takes no wounds from blood cost")
	assert_eq(_blood_source.wounds_taken, 4)


func test_resolve_cast_caster_as_own_blood_source() -> void:
	_caster.wounds_taken = 0
	MahoSystem.resolve_cast(
		_caster, _caster, _province, 1, 0, 105, 10, "Province_99"
	)
	assert_eq(_caster.wounds_taken, 2,
		"Caster using own blood: 2 wounds applied to caster")


func test_blood_source_died_false_when_source_survives() -> void:
	_blood_source.wounds_taken = 0
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 106, 10, "Province_99"
	)
	assert_false(result["blood_source_died"],
		"blood_source_died should be false when source survives")


func test_blood_source_died_true_when_wounds_fatal() -> void:
	# ML5 + 3 raises = total 40 wounds — will kill a standard character
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 5, 3, 107, 10, "Province_99"
	)
	assert_true(result["blood_source_died"],
		"blood_source_died should be true when wounds exceed capacity")


# =============================================================================
# resolve_cast — Taint
# =============================================================================

func test_resolve_cast_adds_taint_to_caster() -> void:
	_caster.taint = 0.0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 200, 10, "Province_99"
	)
	assert_eq(_caster.taint, 1.0, "ML1 cast should add 1 Taint Point to caster")


func test_resolve_cast_ml3_adds_two_taint() -> void:
	_caster.taint = 0.0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 3, 0, 201, 10, "Province_99"
	)
	assert_eq(_caster.taint, 2.0, "ML3 cast should add 2 Taint Points")


func test_resolve_cast_taint_accumulates() -> void:
	_caster.taint = 1.5
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 0, 202, 11, "Province_99"
	)
	assert_eq(_caster.taint, 2.5, "Taint accumulates over multiple casts")


func test_taint_always_goes_to_caster_not_blood_source() -> void:
	_blood_source.taint = 0.0
	_caster.taint = 0.0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 0, 203, 10, "Province_99"
	)
	assert_eq(_blood_source.taint, 0.0, "blood_source does not gain Taint")
	assert_eq(_caster.taint, 1.0, "caster gains Taint regardless of blood source")


# =============================================================================
# resolve_cast — Honor Loss (at-act, Table 2.3 blasphemous)
# =============================================================================

func test_resolve_cast_causes_at_act_honor_loss() -> void:
	_caster.honor = 5.0
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 300, 10, "Province_99"
	)
	assert_true(_caster.honor < 5.0, "Maho cast must cause at-act Honor loss")
	assert_true(result["honor_delta"] < 0.0, "honor_delta must be negative")


func test_resolve_cast_honor_rank0_loses_one_point() -> void:
	_caster.honor = 0.5
	var before: float = _caster.honor
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 301, 10, "Province_99"
	)
	assert_almost_eq(before - _caster.honor, 0.1, 0.001,
		"Rank 0 blasphemy = -1 point = -0.1")


func test_resolve_cast_honor_rank5_loses_ten_points() -> void:
	_caster.honor = 5.0
	var before: float = _caster.honor
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 302, 10, "Province_99"
	)
	assert_almost_eq(before - _caster.honor, 1.0, 0.001,
		"Rank 5-6 blasphemy = -10 points = -1.0")


func test_resolve_cast_honor_rank9_loses_twenty_points() -> void:
	_caster.honor = 9.5
	var before: float = _caster.honor
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 303, 10, "Province_99"
	)
	assert_almost_eq(before - _caster.honor, 2.0, 0.001,
		"Rank 9-10 blasphemy = -20 points = -2.0")


# =============================================================================
# resolve_cast — PTL
# =============================================================================

func test_resolve_cast_increments_province_ptl() -> void:
	_province.province_taint_level = 0.0
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 400, 10, "Province_99"
	)
	assert_eq(_province.province_taint_level, 1.0,
		"Any maho cast raises PTL by 1 regardless of detection")


func test_resolve_cast_ptl_increments_are_cumulative() -> void:
	_province.province_taint_level = 2.5
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 401, 10, "Province_99"
	)
	MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 0, 402, 11, "Province_99"
	)
	assert_almost_eq(_province.province_taint_level, 4.5, 0.001,
		"Two casts should raise PTL by 2 total")


func test_ptl_delta_in_result() -> void:
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 403, 10, "Province_99"
	)
	assert_eq(result["ptl_delta"], MahoSystem.PTL_PER_CAST)


# =============================================================================
# resolve_cast — Crime Record
# =============================================================================

func test_resolve_cast_returns_crime_record() -> void:
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 500, 10, "Province_99"
	)
	assert_not_null(result["crime_record"])


func test_crime_record_type_is_maho() -> void:
	var rec: CrimeRecord = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 501, 10, "Province_99"
	)["crime_record"]
	assert_eq(rec.crime_type, Enums.CrimeType.MAHO)


func test_crime_record_severity_is_capital() -> void:
	var rec: CrimeRecord = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 502, 10, "Province_99"
	)["crime_record"]
	assert_eq(rec.severity, Enums.CrimeSeverity.CAPITAL)


func test_crime_record_perpetrator_is_caster() -> void:
	var rec: CrimeRecord = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 503, 10, "Province_99"
	)["crime_record"]
	assert_eq(rec.perpetrator_id, _caster.character_id)


func test_crime_record_uses_provided_case_id() -> void:
	var rec: CrimeRecord = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 777, 10, "Province_99"
	)["crime_record"]
	assert_eq(rec.case_id, 777)


func test_crime_record_records_ic_day() -> void:
	var rec: CrimeRecord = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 504, 42, "Province_99"
	)["crime_record"]
	assert_eq(rec.ic_day_committed, 42)


func test_crime_record_records_witnesses() -> void:
	var witnesses: Array[int] = [10, 11, 12]
	var rec: CrimeRecord = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 1, 0, 505, 10, "Province_99",
		witnesses
	)["crime_record"]
	assert_eq(rec.witnesses.size(), 3)
	assert_true(rec.witnesses.has(11))


# =============================================================================
# resolve_cast — Raises
# =============================================================================

func test_raises_zero_when_none_purchased() -> void:
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 0, 600, 10, "Province_99"
	)
	assert_eq(result["raises_available"], 0)


func test_raises_equal_purchased_raises() -> void:
	var result: Dictionary = MahoSystem.resolve_cast(
		_caster, _blood_source, _province, 2, 3, 601, 10, "Province_99"
	)
	assert_eq(result["raises_available"], 3)
