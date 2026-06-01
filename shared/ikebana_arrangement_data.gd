class_name IkebanaArrangementData
extends Resource
## World object for an ikebana flower arrangement per GDD s57.29.
## An arrangement is simultaneously the performance, the creation, and the display.
## It occupies the ikebana_slot of a zone (proxied to settlement level until zone
## data is available) and generates visitor disposition bonuses until it expires.

@export var arrangement_id: int = -1
@export var creator_id: int = -1

## GiftGivingSystem.QualityTier: NORMAL=1, FINE=2, EXCEPTIONAL=3, MASTERWORK=4, LEGENDARY=5
@export var quality_tier: int = 1

## IC season during which the arrangement was made (TimeSystem.Season int).
@export var season_created: int = -1

## Garden_id that provided materials, or -1 if wild-gathered/purchased.
@export var materials_source: int = -1

## IC day on which the arrangement was created.
@export var date_created: int = -1

## Days remaining until the arrangement expires. Decremented daily.
@export var lifespan_remaining: int = 7

## Settlement ID of the zone holding the display. Empty string = arrangement is in
## owner_id's inventory (not yet displayed or performer lacked permission).
@export var display_settlement_id: String = ""

## Character who carries the arrangement in inventory when display_settlement_id is "".
@export var owner_id: int = -1

## True when lifespan_remaining reaches 0. Slot empties, no further effects.
@export var expired: bool = false

## 1–3 material names selected from the seasonal table at creation time.
@export var composition_materials: Array[String] = []

## Procedurally generated description of the arrangement (style, vessel, aesthetic phrase).
@export var composition_description: String = ""

## True when displayed at a TEMPLE or SHINDEN settlement (shrine offering context).
@export var is_shrine_offering: bool = false

## IDs of characters who have already received the visitor disposition bonus.
## Each new visitor adds one entry. Every 5 unique visitors = 1 glory tick.
@export var visitors_who_received_bonus: Array[int] = []

## Number of glory ticks (creator +0.1, zone lord +0.01) already applied.
@export var glory_ticks_applied: int = 0

## True once the creator-deceased topic has fired (prevents repeat fires).
@export var creator_deceased_topic_fired: bool = false
