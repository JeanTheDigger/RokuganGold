class_name OperationalHierarchySystem
## Operational hierarchy management per GDD s11.3.18.
## Covers: assignment/clearing lifecycle, chain traversal, override rules,
## objective priority resolution, order refusal consequences, starting
## disposition baselines, and death-of-superior cascading clear.


# -- Starting Disposition Baselines (s11.3.18i) -----

const BASELINE_MILITARY: int = 5
const BASELINE_LEGAL: int = 5
const BASELINE_DELEGATION: int = 10

# -- Order Refusal Consequences (s11.3.18h) -----

const REFUSAL_DISPOSITION_HIT_MINOR: int = -10
const REFUSAL_DISPOSITION_HIT_CRITICAL: int = -20

# -- Escalation Outcomes (s11.3.18h) -----

const VINDICATION_DISPOSITION_GAIN_MIN: int = 5
const VINDICATION_DISPOSITION_GAIN_MAX: int = 10
const VINDICATION_ENEMY_FLOOR: int = -50
const INSUBORDINATION_HONOR_LOSS: float = -0.3
const INSUBORDINATION_DAIMYO_DISPOSITION_LOSS: int = -10


# -- Assignment (s11.3.18g) -----

static func assign_operational_superior(
	character: L5RCharacterData,
	superior_id: int,
	hierarchy_type: Enums.OperationalHierarchyType,
) -> Dictionary:
	var old_superior: int = character.operational_superior_id
	var old_type: Enums.OperationalHierarchyType = character.operational_hierarchy_type

	character.operational_superior_id = superior_id
	character.operational_hierarchy_type = hierarchy_type

	return {
		"character_id": character.character_id,
		"old_superior_id": old_superior,
		"old_hierarchy_type": old_type,
		"new_superior_id": superior_id,
		"new_hierarchy_type": hierarchy_type,
		"overwrote_existing": old_superior >= 0 and old_superior != superior_id,
	}


static func clear_operational_superior(
	character: L5RCharacterData,
) -> Dictionary:
	var old_superior: int = character.operational_superior_id
	var old_type: Enums.OperationalHierarchyType = character.operational_hierarchy_type

	character.operational_superior_id = -1
	character.operational_hierarchy_type = Enums.OperationalHierarchyType.NONE

	return {
		"character_id": character.character_id,
		"cleared_superior_id": old_superior,
		"cleared_hierarchy_type": old_type,
	}


# -- Chain Traversal (s11.3.18b) -----

static func get_operational_chain(
	character: L5RCharacterData,
	all_characters: Dictionary,
) -> Array:
	var chain: Array[int] = []
	var current_id: int = character.operational_superior_id
	var visited: Dictionary = {}

	while current_id >= 0 and not visited.has(current_id):
		chain.append(current_id)
		visited[current_id] = true
		var superior: L5RCharacterData = all_characters.get(current_id)
		if superior == null:
			break
		current_id = superior.operational_superior_id

	return chain


static func get_operational_subordinates(
	superior_id: int,
	all_characters: Array[L5RCharacterData],
) -> Array:
	var result: Array[L5RCharacterData] = []
	for c: L5RCharacterData in all_characters:
		if c.operational_superior_id == superior_id:
			result.append(c)
	return result


static func shares_operational_chain(
	character_a: L5RCharacterData,
	character_b: L5RCharacterData,
	all_characters: Dictionary,
) -> bool:
	var chain_a: Array = get_operational_chain(character_a, all_characters)
	if character_b.character_id in chain_a:
		return true
	var chain_b: Array = get_operational_chain(character_b, all_characters)
	if character_a.character_id in chain_b:
		return true
	return false


# -- Override Rules (s11.3.18f) -----

static func can_feudal_lord_override(
	lord_id: int,
	character: L5RCharacterData,
) -> bool:
	return character.lord_id == lord_id


static func can_higher_superior_override(
	overrider_id: int,
	subordinate: L5RCharacterData,
	all_characters: Dictionary,
) -> bool:
	var chain: Array = get_operational_chain(subordinate, all_characters)
	return overrider_id in chain


static func execute_feudal_override(
	character: L5RCharacterData,
	new_superior_id: int,
	new_hierarchy_type: Enums.OperationalHierarchyType,
) -> Dictionary:
	var previous_superior_id: int = character.operational_superior_id
	var result: Dictionary = assign_operational_superior(
		character, new_superior_id, new_hierarchy_type
	)
	result["feudal_override"] = true
	result["disrupted_superior_id"] = previous_superior_id
	return result


# -- Objective Priority (s11.3.18f) -----

enum ObjectiveSource {
	FEUDAL_LORD,
	OPERATIONAL_SUPERIOR,
}


static func get_objective_priority(character: L5RCharacterData) -> ObjectiveSource:
	if character.operational_superior_id >= 0:
		return ObjectiveSource.OPERATIONAL_SUPERIOR
	return ObjectiveSource.FEUDAL_LORD


static func is_on_operational_assignment(character: L5RCharacterData) -> bool:
	return character.operational_superior_id >= 0


# -- Order Refusal (s11.3.18h) -----

enum RefusalSeverity {
	MINOR,
	CRITICAL,
}

enum EscalationOutcome {
	DAIMYO_BELIEVES_SUBORDINATE,
	DAIMYO_SIDES_WITH_SUPERIOR,
	DAIMYO_DISMISSES,
}


static func get_refusal_disposition_hit(severity: RefusalSeverity) -> int:
	if severity == RefusalSeverity.CRITICAL:
		return REFUSAL_DISPOSITION_HIT_CRITICAL
	return REFUSAL_DISPOSITION_HIT_MINOR


static func will_escalate_refusal(
	subordinate: L5RCharacterData,
) -> bool:
	if subordinate.shourido_virtue != Enums.ShouridoVirtue.NONE:
		match subordinate.shourido_virtue:
			Enums.ShouridoVirtue.SEIGYO:
				return false
			_:
				return false

	match subordinate.bushido_virtue:
		Enums.BushidoVirtue.GI:
			return true
		Enums.BushidoVirtue.MAKOTO:
			return true
		Enums.BushidoVirtue.CHUGI:
			return false
		Enums.BushidoVirtue.YU:
			return false
		_:
			return false


static func get_escalation_outcome(
	daimyo: L5RCharacterData,
) -> EscalationOutcome:
	if daimyo.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return EscalationOutcome.DAIMYO_DISMISSES

	match daimyo.bushido_virtue:
		Enums.BushidoVirtue.GI:
			return EscalationOutcome.DAIMYO_BELIEVES_SUBORDINATE
		Enums.BushidoVirtue.MAKOTO:
			return EscalationOutcome.DAIMYO_BELIEVES_SUBORDINATE
		Enums.BushidoVirtue.MEIYO:
			return EscalationOutcome.DAIMYO_BELIEVES_SUBORDINATE
		_:
			return EscalationOutcome.DAIMYO_SIDES_WITH_SUPERIOR


static func get_escalation_consequences(
	outcome: EscalationOutcome,
	subordinate: L5RCharacterData = null,
) -> Dictionary:
	match outcome:
		EscalationOutcome.DAIMYO_BELIEVES_SUBORDINATE:
			return {
				"subordinate_vindicated": true,
				"superior_investigated": true,
				"subordinate_disposition_gain": VINDICATION_DISPOSITION_GAIN_MIN,
				"enemy_disposition_floor": VINDICATION_ENEMY_FLOOR,
			}
		EscalationOutcome.DAIMYO_SIDES_WITH_SUPERIOR:
			var _honor: float = CrimeSystem.get_disobeying_lord_honor(subordinate) if subordinate != null else INSUBORDINATION_HONOR_LOSS
			return {
				"insubordination_guilty": true,
				"honor_loss": _honor,
				"daimyo_disposition_loss": INSUBORDINATION_DAIMYO_DISPOSITION_LOSS,
				"reassignment_to_lesser_posting": true,
			}
		EscalationOutcome.DAIMYO_DISMISSES:
			return {
				"complaint_dismissed": true,
				"daimyo_disposition_loss": -5,
				"superior_disposition_loss": -5,
				"subordinate_exposed": true,
			}
	return {}


# -- Death of Superior (s11.3.18g) -----

static func clear_subordinates_on_death(
	dead_superior_id: int,
	all_characters: Array[L5RCharacterData],
) -> Array:
	var cleared_ids: Array[int] = []
	for c: L5RCharacterData in all_characters:
		if c.operational_superior_id == dead_superior_id:
			c.operational_superior_id = -1
			c.operational_hierarchy_type = Enums.OperationalHierarchyType.NONE
			cleared_ids.append(c.character_id)
	return cleared_ids


# -- Starting Disposition Baseline (s11.3.18i) -----

static func get_starting_baseline(
	hierarchy_type: Enums.OperationalHierarchyType,
) -> int:
	match hierarchy_type:
		Enums.OperationalHierarchyType.MILITARY:
			return BASELINE_MILITARY
		Enums.OperationalHierarchyType.LEGAL:
			return BASELINE_LEGAL
		Enums.OperationalHierarchyType.DELEGATION:
			return BASELINE_DELEGATION
	return 0


# -- Hierarchy Type Queries -----

static func is_legal_subordinate(character: L5RCharacterData) -> bool:
	return (
		character.operational_superior_id >= 0
		and character.operational_hierarchy_type == Enums.OperationalHierarchyType.LEGAL
	)


static func is_military_subordinate(character: L5RCharacterData) -> bool:
	return (
		character.operational_superior_id >= 0
		and character.operational_hierarchy_type == Enums.OperationalHierarchyType.MILITARY
	)


static func is_delegation_member(character: L5RCharacterData) -> bool:
	return (
		character.operational_superior_id >= 0
		and character.operational_hierarchy_type == Enums.OperationalHierarchyType.DELEGATION
	)
