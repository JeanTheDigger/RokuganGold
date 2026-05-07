class_name RicePostingData
extends Resource
## A lord's rice market listing per GDD s4.3.18 Rice Market System.


@export var lord_id: int = -1
@export var province_id: int = -1
@export var quantity: float = 0.0
@export var price_per_unit: float = 1.0
@export var seasons_sold: int = 0
@export var seasons_unsold: int = 0
