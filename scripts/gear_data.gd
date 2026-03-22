# gear_data.gd
class_name GearData
extends Resource

@export var gear_name: String = "Unnamed"
@export var supertype: GameEnums.GearSupertype = GameEnums.GearSupertype.NONE
@export var type: GameEnums.GearType = GameEnums.GearType.ROUTINE
@export var subtype: GameEnums.GearSubtype = GameEnums.GearSubtype.NONE
@export var speed: int = 0
@export var is_flying: bool = false
@export var texture_reverse: Texture2D
@export var texture_obverse: Texture2D
@export var max_ticks: int = 3
@export var max_tocks: int = 2
@export var ability_slots: Array[AbilitySlotData] = []
@export var impact: int = 0      # новая характеристика (сила атаки)
@export var resistance: int = 0  # новая характеристика (защита)
