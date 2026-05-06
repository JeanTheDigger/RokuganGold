class_name TopicData
extends Resource
## A single topic in the world — either a crisis (Tier 1-3) or social news
## (Tier 4). Per GDD s16: momentum tracks urgency, personal relevance
## determines how much each character cares.

enum Tier { TIER_1, TIER_2, TIER_3, TIER_4 }

enum Category {
	PERSONAL,
	POLITICAL,
	MILITARY,
	SUPERNATURAL,
	ECONOMIC,
}

@export var topic_id: int = -1
@export var slug: String = ""
@export var title: String = ""
@export var tier: Tier = Tier.TIER_4
@export var category: Category = Category.PERSONAL
@export var momentum: float = 0.0
@export var provinces_affected: Array[int] = []
@export var clan_involved: String = ""
@export var family_involved: String = ""
@export var subject_character_id: int = -1
@export var subject_role: String = "NEUTRAL"
@export var ic_day_created: int = 0
@export var resolved: bool = false
@export var discussion_count_this_day: int = 0
