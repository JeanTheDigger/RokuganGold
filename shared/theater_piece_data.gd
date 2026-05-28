class_name TheaterPieceData
extends Resource
## World object representing a composed dramatic work per GDD s57.22.2.
## craft_progress = -1 means completed or canonized (not in composition).
## craft_progress >= 0 means composition in progress.

@export var piece_id: int = -1
@export var title: String = ""
@export var style: int = 0  # TheaterSystem.Style enum
@export var author_id: int = -1  # -1 for canonized/anonymous pieces
@export var subject: String = ""  # clan name, family name, str(char_id), or archetype string
@export var subject_type: int = 0  # TheaterSystem.SubjectType enum
@export var framing: bool = true  # true = positive, false = negative
@export var roles: Array = []  # Array of role Dictionaries (see TheaterSystem.make_role)
@export var topic_ids: Array[int] = []  # max 2 entries
@export var topic_weight: int = 1  # 1-3
@export var disposition_magnitude: int = 1  # 1-5
@export var known_by: Array[int] = []  # character_ids
@export var canonized: bool = false
@export var times_performed: int = 0
@export var craft_progress: int = -1  # -1 = complete; >= 0 = in progress
@export var target_magnitude: int = 1  # magnitude declared at composition start
@export var target_topic_weight: int = 1  # topic_weight declared at composition start
@export var num_roles_declared: int = 1  # number of roles declared at composition start
@export var ic_day_last_composition_ap: int = -1  # last AP spent on composition (for degradation)
@export var lost: bool = false
@export var abandoned_incomplete: bool = false
@export var ic_day_created: int = -1
