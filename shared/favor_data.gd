class_name FavorData
extends Resource
## A tracked political obligation between two characters per GDD s12.10.

enum FavorType {
	SPECIFIC,
	GENERAL,
}

enum FavorTier {
	MAJOR = 1,
	MODERATE = 2,
	MINOR = 3,
}

enum InvocationMethod {
	LETTER,
	COURT,
	PERSONAL_VISIT,
}

@export var favor_id: int = -1
@export var favor_type: FavorType = FavorType.GENERAL
@export var tier: FavorTier = FavorTier.MINOR
@export var creditor_id: int = -1
@export var debtor_id: int = -1
@export var created_ic_day: int = 0
@export var terms: String = ""
@export var source_action: String = ""
@export var is_blackmail_extracted: bool = false
@export var invoked: bool = false
@export var invoked_ic_day: int = -1
@export var invocation_method: InvocationMethod = InvocationMethod.LETTER
@export var response_deadline_ic_day: int = -1
@export var heir_id: int = -1
