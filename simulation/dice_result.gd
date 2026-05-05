class_name DiceResult


var kept_dice: Array[int] = []
var dropped_dice: Array[int] = []
var total: int = 0
var explosions: int = 0
var overflow_bonus: int = 0


func _init(p_kept: Array[int] = [], p_dropped: Array[int] = [], p_explosions: int = 0, p_overflow: int = 0) -> void:
	kept_dice = p_kept
	dropped_dice = p_dropped
	explosions = p_explosions
	overflow_bonus = p_overflow
	total = overflow_bonus
	for die_value: int in kept_dice:
		total += die_value
