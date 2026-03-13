# ability.gd
class_name Ability
extends Resource

var game_manager: GameManager
var effect_system: EffectSystem
var event_bus: EventBus
var stack_manager: StackManager

@export var ability_id: int
@export var ability_name: String = ""
@export var ability_type: GameEnums.AbilityType
@export var trigger: int = -1
@export var activation_cost: int = 0
@export var target_type: GameEnums.TargetType = GameEnums.TargetType.NO_TARGET
@export var description: String = ""

func init(gm: GameManager, es: EffectSystem, eb: EventBus, sm: StackManager) -> void:
	game_manager = gm
	effect_system = es
	event_bus = eb
	stack_manager = sm

func execute(context: Dictionary) -> void:
	push_error("Ability.execute() not implemented for ", ability_name)

func get_possible_targets(context: Dictionary) -> Array:
	return []
