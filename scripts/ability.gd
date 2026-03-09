# ability.gd
class_name Ability
extends Resource

@export var ability_id: int                # GameEnums.AbilityID
@export var ability_name: String = ""
@export var ability_type: GameEnums.AbilityType
@export var trigger: int = -1              # GameEnums.TriggerCondition
@export var activation_cost: int = 0
@export var target_type: GameEnums.TargetType = GameEnums.TargetType.NO_TARGET
@export var description: String = ""

func execute(context: Dictionary):
	push_error("Ability.execute() not implemented for ", ability_name)

# Возвращает список возможных целей для этой способности в данном контексте.
func get_possible_targets(context: Dictionary) -> Array:
	return []
