# ability_slot_data.gd
class_name AbilitySlotData
extends Resource

@export var ability_id: int = -1
@export var type: GameEnums.AbilityType = GameEnums.AbilityType.TRIGGERED
@export var cost: int = 0
@export var trigger: int = -1  # GameEnums.TriggerCondition
