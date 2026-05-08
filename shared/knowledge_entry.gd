class_name KnowledgeEntry
extends Resource

@export var source: Enums.KnowledgeSource = Enums.KnowledgeSource.DIRECT_OBSERVATION
@export var entry_type: String = ""
@export var data: Dictionary = {}
@export var confidence: Enums.KnowledgeConfidence = Enums.KnowledgeConfidence.FRESH
@export var season_acquired: int = -1
