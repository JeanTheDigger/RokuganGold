extends GutTest
## Validates all character sheet fields per GDD s57.35 exist on L5RCharacterData.


var _char: L5RCharacterData


func before_each() -> void:
	_char = L5RCharacterData.new()


# =============================================================================
# Core Identity (Section 22.3)
# =============================================================================

func test_identity_fields():
	assert_eq(_char.character_id, -1)
	assert_eq(_char.character_name, "")
	assert_eq(_char.clan, "")
	assert_eq(_char.family, "")
	assert_eq(_char.school, "")
	assert_eq(_char.school_type, Enums.SchoolType.BUSHI)
	assert_eq(_char.age, 16)
	assert_eq(_char.gender, "")


# =============================================================================
# Traits and Rings (Section 4.5)
# =============================================================================

func test_trait_defaults():
	assert_eq(_char.stamina, 2)
	assert_eq(_char.willpower, 2)
	assert_eq(_char.strength, 2)
	assert_eq(_char.perception, 2)
	assert_eq(_char.agility, 2)
	assert_eq(_char.intelligence, 2)
	assert_eq(_char.reflexes, 2)
	assert_eq(_char.awareness, 2)
	assert_eq(_char.void_ring, 2)

func test_void_points():
	assert_eq(_char.current_void_points, 2)
	assert_eq(_char.max_void_points, 2)


# =============================================================================
# Skills (Section 22.3)
# =============================================================================

func test_skills_defaults():
	assert_eq(_char.skills.size(), 0)
	assert_eq(_char.emphases.size(), 0)


# =============================================================================
# Honor, Glory, Status, Infamy (Section 4.6)
# =============================================================================

func test_social_score_defaults():
	assert_almost_eq(_char.honor, 3.5, 0.01)
	assert_almost_eq(_char.glory, 1.0, 0.01)
	assert_almost_eq(_char.status, 1.0, 0.01)
	assert_almost_eq(_char.infamy, 0.0, 0.01)


# =============================================================================
# Wounds (Section 4.5)
# =============================================================================

func test_wounds_default():
	assert_eq(_char.wounds_taken, 0)

func test_taint_default():
	assert_almost_eq(_char.taint, 0.0, 0.01)


# =============================================================================
# Operational Hierarchy (Section 11.3.18)
# =============================================================================

func test_operational_hierarchy_fields():
	assert_eq(_char.operational_superior_id, -1)
	assert_eq(_char.operational_hierarchy_type, Enums.OperationalHierarchyType.NONE)
	assert_eq(_char.military_rank, Enums.MilitaryRank.NONE)
	assert_eq(_char.commanded_unit_id, -1)
	assert_eq(_char.assigned_company_id, -1)


# =============================================================================
# Legal System (Section 11.3.14)
# =============================================================================

func test_legal_cases_default():
	assert_eq(_char.legal_cases.size(), 0)


# =============================================================================
# Theater System (Section 57.22)
# =============================================================================

func test_theater_fields():
	assert_eq(_char.pieces_seen.size(), 0)
	assert_eq(_char.learning_progress.size(), 0)


# =============================================================================
# Meditation System (Section 57.32)
# =============================================================================

func test_void_refresh_blocked_until():
	assert_eq(_char.void_refresh_blocked_until, -1)


# =============================================================================
# Medicine System (Section 57.31)
# =============================================================================

func test_medicine_fields():
	assert_eq(_char.last_medicine_treatment_ic_day, -1)
	assert_true(_char.rested_last_night)


# =============================================================================
# Civilian Order Budget (Section 57.34)
# =============================================================================

func test_civilian_order_budget():
	assert_eq(_char.civilian_order_budget_max, 0)
	assert_eq(_char.civilian_orders_remaining, 0)


# =============================================================================
# Kolat System (Section 54.7c)
# =============================================================================

func test_kolat_fields():
	assert_eq(_char.kolat_superior_id, -1)
	assert_eq(_char.kolat_sect, Enums.KolatSect.NONE)


# =============================================================================
# Samurai Hunting Party (Section 57.38)
# =============================================================================

func test_hunt_trophies_default():
	assert_eq(_char.hunt_trophies.size(), 0)


# =============================================================================
# Animal Companions (Section 57.39)
# =============================================================================

func test_trained_companions_default():
	assert_eq(_char.trained_companions.size(), 0)


# =============================================================================
# Sailing and Passage (Section 57.42)
# =============================================================================

func test_sailing_fields():
	assert_eq(_char.aboard_ship_id, -1)
	assert_eq(_char.passage_request_count_today, 0)
	assert_eq(_char.assigned_ship_id, -1)


# =============================================================================
# Tattoo Ability State (Section 57.25.11)
# =============================================================================

func test_tattoo_ability_defaults():
	assert_false(_char.mantis_tattoo)
	assert_false(_char.ocean_tattoo)
	assert_eq(_char.ocean_last_used_ooc_day, -1)
	assert_eq(_char.phoenix_last_used_ic_day, -1)
	assert_eq(_char.crane_pool, 0)
	assert_false(_char.kirin_reroll_available)
	assert_eq(_char.active_tattoo_ability, Enums.TattooAbility.NONE)
	assert_false(_char.is_bald)


# =============================================================================
# Social & Dynamic Fields (Section 22.3)
# =============================================================================

func test_social_fields():
	assert_eq(_char.lord_id, -1)
	assert_eq(_char.disposition_values.size(), 0)
	assert_eq(_char.met_characters.size(), 0)
	assert_eq(_char.knowledge_pool.size(), 0)
	assert_eq(_char.known_contacts_by_clan.size(), 0)
	assert_eq(_char.topic_pool.size(), 0)
	assert_eq(_char.fear_rating, 0)


# =============================================================================
# Family Web
# =============================================================================

func test_family_fields():
	assert_eq(_char.mother_id, -1)
	assert_eq(_char.father_id, -1)
	assert_eq(_char.sibling_ids.size(), 0)
	assert_eq(_char.children_ids.size(), 0)
	assert_eq(_char.spouse_id, -1)


# =============================================================================
# Progression (Section 48)
# =============================================================================

func test_progression_fields():
	assert_eq(_char.xp_total, 0)
	assert_eq(_char.xp_spent, 0)
	assert_eq(_char.progress_bars.size(), 0)
	assert_eq(_char.training_relationships.size(), 0)


# =============================================================================
# Action Points (Section 14.1)
# =============================================================================

func test_action_point_fields():
	assert_eq(_char.action_points_current, 2)
	assert_eq(_char.action_points_max, 2)


# =============================================================================
# Enum Existence — MilitaryRank
# =============================================================================

func test_military_rank_enum():
	assert_eq(Enums.MilitaryRank.NONE, 0)
	assert_eq(Enums.MilitaryRank.HOHEI, 1)
	assert_eq(Enums.MilitaryRank.NIKUTAI, 2)
	assert_eq(Enums.MilitaryRank.GUNSO, 3)
	assert_eq(Enums.MilitaryRank.CHUI, 4)
	assert_eq(Enums.MilitaryRank.TAISA, 5)
	assert_eq(Enums.MilitaryRank.SHIREIKAN, 6)
	assert_eq(Enums.MilitaryRank.RIKUGUNSHOKAN, 7)


# =============================================================================
# Enum Existence — OperationalHierarchyType
# =============================================================================

func test_operational_hierarchy_type_enum():
	assert_eq(Enums.OperationalHierarchyType.NONE, 0)
	assert_eq(Enums.OperationalHierarchyType.LEGAL, 1)
	assert_eq(Enums.OperationalHierarchyType.MILITARY, 2)
	assert_eq(Enums.OperationalHierarchyType.DELEGATION, 3)


# =============================================================================
# Enum Existence — KolatSect
# =============================================================================

func test_kolat_sect_enum():
	assert_eq(Enums.KolatSect.NONE, 0)
	assert_eq(Enums.KolatSect.CHRYSANTHEMUM, 1)
	assert_eq(Enums.KolatSect.CLOUD, 2)
	assert_eq(Enums.KolatSect.COIN, 3)
	assert_eq(Enums.KolatSect.DREAM, 4)
	assert_eq(Enums.KolatSect.LOTUS, 5)
	assert_eq(Enums.KolatSect.SILK, 6)
	assert_eq(Enums.KolatSect.TIGER, 7)


# =============================================================================
# Enum Existence — ShipClass
# =============================================================================

func test_ship_class_enum():
	assert_eq(Enums.ShipClass.SAMPAN, 0)
	assert_eq(Enums.ShipClass.MERCHANT_BARGE, 1)
	assert_eq(Enums.ShipClass.KOBUNE, 2)
	assert_eq(Enums.ShipClass.SENGOKOBUNE, 3)
	assert_eq(Enums.ShipClass.KOUTETSUKAN, 4)
	assert_eq(Enums.ShipClass.ATAKEBUNE, 5)
	assert_eq(Enums.ShipClass.TORTOISE_OCEANGOING, 6)


# =============================================================================
# Field Mutability — verify fields can be set and read back
# =============================================================================

func test_set_military_rank():
	_char.military_rank = Enums.MilitaryRank.TAISA
	assert_eq(_char.military_rank, Enums.MilitaryRank.TAISA)

func test_set_commanded_unit():
	_char.commanded_unit_id = 42
	assert_eq(_char.commanded_unit_id, 42)

func test_set_assigned_company():
	_char.assigned_company_id = 1001
	assert_eq(_char.assigned_company_id, 1001)

func test_set_legal_cases():
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = 1
	entry.state = Enums.LegalStatus.SUSPECTED
	_char.legal_cases.append(entry)
	assert_eq(_char.legal_cases.size(), 1)

func test_set_kolat_sect():
	_char.kolat_sect = Enums.KolatSect.TIGER
	assert_eq(_char.kolat_sect, Enums.KolatSect.TIGER)

func test_set_aboard_ship():
	_char.aboard_ship_id = 5
	assert_eq(_char.aboard_ship_id, 5)

func test_set_active_tattoo_ability():
	_char.active_tattoo_ability = Enums.TattooAbility.BEAR
	assert_eq(_char.active_tattoo_ability, Enums.TattooAbility.BEAR)

func test_set_mantis_tattoo_flag():
	_char.mantis_tattoo = true
	assert_true(_char.mantis_tattoo)

func test_set_ocean_tattoo_flag():
	_char.ocean_tattoo = true
	assert_true(_char.ocean_tattoo)

func test_set_void_refresh_blocked():
	_char.void_refresh_blocked_until = 100
	assert_eq(_char.void_refresh_blocked_until, 100)

func test_set_is_bald():
	_char.is_bald = true
	assert_true(_char.is_bald)
