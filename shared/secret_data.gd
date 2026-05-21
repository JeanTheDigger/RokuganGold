class_name SecretData
extends Resource

enum Severity {
	TIER_4 = 4,
	TIER_3 = 3,
	TIER_2 = 2,
	TIER_1 = 1,
}

@export var secret_id: int = -1
@export var subject_id: int = -1
@export var severity: Severity = Severity.TIER_4
@export var fabricated: bool = false
@export var fabricator_id: int = -1
@export var detection_tn: int = 15
@export var exposed: bool = false
@export var exposed_publicly: bool = false
@export var slug: String = ""
@export var description: String = ""
@export var topic_id: int = -1
@export var physical_proof_item_id: int = -1
@export var known_by_ids: Array = []
