class_name MushaShugyo
## Warrior's pilgrimage system per GDD s57.48.
## Evaluated once at Gempukku. 1 IC year duration. SEEK_EXPERIENCE standing
## objective. School-type destination weighting. Return-to-service pipeline.

const PILGRIMAGE_DURATION_DAYS: int = 360

const BASE_CHANCE: float = 0.10

const CLAN_MODIFIER: Dictionary = {
	"Crab": -0.05,
	"Crane": 0.05,
	"Dragon": 0.10,
	"Lion": -0.03,
	"Mantis": 0.0,
	"Phoenix": 0.05,
	"Scorpion": 0.02,
	"Unicorn": 0.03,
	"Imperial": -0.03,
}

const BUSHIDO_MODIFIER: Dictionary = {
	Enums.BushidoVirtue.YU: 0.03,
	Enums.BushidoVirtue.GI: 0.01,
	Enums.BushidoVirtue.JIN: 0.01,
	Enums.BushidoVirtue.MEIYO: 0.0,
	Enums.BushidoVirtue.MAKOTO: 0.0,
	Enums.BushidoVirtue.REI: -0.01,
	Enums.BushidoVirtue.CHUGI: -0.03,
}

const SHOURIDO_MODIFIER: Dictionary = {
	Enums.ShouridoVirtue.DOSATSU: 0.03,
	Enums.ShouridoVirtue.KETSUI: 0.02,
	Enums.ShouridoVirtue.CHISHIKI: 0.02,
	Enums.ShouridoVirtue.ISHI: 0.01,
	Enums.ShouridoVirtue.KYORYOKU: 0.0,
	Enums.ShouridoVirtue.SEIGYO: -0.02,
	Enums.ShouridoVirtue.KANPEKI: -0.01,
}


static func compute_probability(character: L5RCharacterData) -> float:
	var prob: float = BASE_CHANCE
	prob += CLAN_MODIFIER.get(character.clan, 0.0)
	if character.bushido_virtue != Enums.BushidoVirtue.NONE:
		prob += BUSHIDO_MODIFIER.get(character.bushido_virtue, 0.0)
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		prob += SHOURIDO_MODIFIER.get(character.shourido_virtue, 0.0)
	return clampf(prob, 0.0, 1.0)


static func evaluate_at_gempukku(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	ic_day: int,
) -> bool:
	var prob: float = compute_probability(character)
	if prob <= 0.0:
		return false
	var roll: int = (dice_engine.roll_and_keep(1, 1, false).total % 100) + 1
	if roll > int(prob * 100.0):
		return false
	begin_pilgrimage(character, ic_day)
	return true


static func begin_pilgrimage(character: L5RCharacterData, ic_day: int) -> void:
	character.musha_shugyo = true
	character.musha_shugyo_end_ic_day = ic_day + PILGRIMAGE_DURATION_DAYS
	character.original_lord_id = character.lord_id
	character.lord_id = -1
	character.current_objective = "SEEK_EXPERIENCE"


static func end_pilgrimage(character: L5RCharacterData) -> Dictionary:
	var result: Dictionary = {
		"character_id": character.character_id,
		"original_lord_id": character.original_lord_id,
		"lord_restored": false,
		"travel_target": "",
	}
	character.musha_shugyo = false
	character.musha_shugyo_end_ic_day = -1

	var lord_id: int = character.original_lord_id
	character.original_lord_id = -1
	character.lord_id = lord_id
	character.current_objective = ""
	result["lord_restored"] = true

	return result


static func is_on_pilgrimage(character: L5RCharacterData) -> bool:
	return character.musha_shugyo


static func should_end_pilgrimage(character: L5RCharacterData, ic_day: int) -> bool:
	if not character.musha_shugyo:
		return false
	if character.musha_shugyo_end_ic_day < 0:
		return false
	return ic_day >= character.musha_shugyo_end_ic_day


static func is_lord_dead_or_missing(
	lord_id: int,
	characters_by_id: Dictionary,
) -> bool:
	if lord_id < 0:
		return true
	if not characters_by_id.has(lord_id):
		return true
	var lord: L5RCharacterData = characters_by_id[lord_id]
	if lord.wounds_taken > 0:
		var earth: int = CharacterStats.get_ring_value(lord, Enums.Ring.EARTH)
		if CharacterStats.is_dead(lord.wounds_taken, earth):
			return true
	return false


static func get_seek_experience_objective() -> Dictionary:
	return {"need_type": "SEEK_EXPERIENCE", "priority": 2}


static func populate_objectives_map(character_id: int, objectives_map: Dictionary) -> void:
	if not objectives_map.has(character_id):
		objectives_map[character_id] = {}
	objectives_map[character_id]["standing"] = get_seek_experience_objective()
	objectives_map[character_id].erase("primary")


# -- SEEK_EXPERIENCE Decomposition ---------------------------------------------

const SEEK_EXPERIENCE_NEED: String = "SEEK_EXPERIENCE"


static func is_seek_experience(need_type: String) -> bool:
	return need_type == SEEK_EXPERIENCE_NEED


static func decompose(
	_objective: Dictionary,
	ctx: NPCDataStructures.ContextSnapshot,
	school_type: Enums.SchoolType,
) -> NPCDataStructures.ImmediateNeed:
	match ctx.context_flag:
		Enums.ContextFlag.AT_COURT:
			return _decompose_at_court(school_type)
		Enums.ContextFlag.AT_TEMPLE:
			return _decompose_at_temple(school_type)
		Enums.ContextFlag.AT_DOJO:
			return _decompose_at_dojo(school_type)
		Enums.ContextFlag.TRAVELING:
			return _decompose_traveling(school_type)
		_:
			return _decompose_default(school_type, ctx)


static func _decompose_at_court(school_type: Enums.SchoolType) -> NPCDataStructures.ImmediateNeed:
	match school_type:
		Enums.SchoolType.COURTIER:
			return _make_need("RAISE_DISPOSITION", 3)
		Enums.SchoolType.SHUGENJA:
			return _make_need("RAISE_DISPOSITION", 2)
		_:
			return _make_need("TRAIN_SKILL", 2)


static func _decompose_at_temple(school_type: Enums.SchoolType) -> NPCDataStructures.ImmediateNeed:
	match school_type:
		Enums.SchoolType.SHUGENJA:
			return _make_need("PERFORM_RITUAL", 3)
		_:
			return _make_need("TRAIN_SKILL", 2)


static func _decompose_at_dojo(school_type: Enums.SchoolType) -> NPCDataStructures.ImmediateNeed:
	match school_type:
		Enums.SchoolType.BUSHI:
			return _make_need("TRAIN_SKILL", 3)
		_:
			return _make_need("TRAIN_SKILL", 2)


static func _decompose_traveling(_school_type: Enums.SchoolType) -> NPCDataStructures.ImmediateNeed:
	return _make_need("REST", 1)


static func _decompose_default(
	school_type: Enums.SchoolType,
	ctx: NPCDataStructures.ContextSnapshot,
) -> NPCDataStructures.ImmediateNeed:
	if ctx.active_insurgency_id >= 0:
		if school_type == Enums.SchoolType.BUSHI:
			return _make_need("PATROL_PROVINCE", 2)
		return _make_need("INVESTIGATE_THREAT", 1)

	match school_type:
		Enums.SchoolType.BUSHI:
			return _make_need("TRAIN_SKILL", 2)
		Enums.SchoolType.COURTIER:
			return _make_need("RAISE_DISPOSITION", 2)
		Enums.SchoolType.SHUGENJA:
			return _make_need("PERFORM_RITUAL", 2)
		_:
			return _make_need("TRAIN_SKILL", 2)


# -- Destination Weighting -----------------------------------------------------

const BUSHI_SETTLEMENT_TYPES: Array[int] = [
	Enums.SettlementType.CASTLE,
	Enums.SettlementType.FAMILY_CASTLE,
	Enums.SettlementType.FORTIFICATION,
	Enums.SettlementType.CITY,
]

const COURTIER_SETTLEMENT_TYPES: Array[int] = [
	Enums.SettlementType.CASTLE,
	Enums.SettlementType.FAMILY_CASTLE,
	Enums.SettlementType.CITY,
	Enums.SettlementType.IMPERIAL_CAPITAL,
]

const SHUGENJA_SETTLEMENT_TYPES: Array[int] = [
	Enums.SettlementType.TEMPLE,
	Enums.SettlementType.SHINDEN,
	Enums.SettlementType.MONASTERY,
]


static func get_preferred_settlement_types(school_type: Enums.SchoolType) -> Array[int]:
	match school_type:
		Enums.SchoolType.BUSHI:
			return BUSHI_SETTLEMENT_TYPES
		Enums.SchoolType.COURTIER:
			return COURTIER_SETTLEMENT_TYPES
		Enums.SchoolType.SHUGENJA:
			return SHUGENJA_SETTLEMENT_TYPES
		_:
			return BUSHI_SETTLEMENT_TYPES


static func score_settlement_for_pilgrimage(
	settlement: SettlementData,
	school_type: Enums.SchoolType,
	is_own_clan: bool,
) -> int:
	var score: int = 0
	var preferred: Array[int] = get_preferred_settlement_types(school_type)
	if settlement.settlement_type in preferred:
		score += 10
	if not is_own_clan:
		score += 5
	if settlement.population_pu > 3:
		score += 3
	return score


# -- Helper -------------------------------------------------------------------

static func _make_need(
	need_type: String,
	priority: int,
	extras: Dictionary = {},
) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = need_type
	need.priority = priority
	need.source = "musha_shugyo_decomposition"
	need.target_npc_id = extras.get("target_npc_id", -1)
	need.target_province_id = extras.get("target_province_id", -1)
	need.target_intent = extras.get("target_intent", "")
	return need
