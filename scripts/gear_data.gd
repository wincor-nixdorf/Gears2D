# gear_data.gd
class_name GearData
extends Resource

@export var gear_name: String = "Unnamed"
@export var texture_reverse: Texture2D
@export var texture_obverse: Texture2D
@export var max_ticks: int = 3
@export var max_tocks: int = 2
@export var abilities: Array[Ability] = []
