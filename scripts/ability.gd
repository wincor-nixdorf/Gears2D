# ability.gd
class_name Ability
extends Resource

var game_manager: GameManager
var effect_system: EffectSystem
var event_bus: EventBus

@export var ability_id: int                # GameEnums.AbilityID
@export var ability_name: String = ""
@export var ability_type: GameEnums.AbilityType
@export var trigger: int = -1              # GameEnums.TriggerCondition
@export var activation_cost: int = 0
@export var target_type: GameEnums.TargetType = GameEnums.TargetType.NO_TARGET
@export var description: String = ""

# Инициализация зависимостей
func init(gm: GameManager, es: EffectSystem, eb: EventBus):
	game_manager = gm
	effect_system = es
	event_bus = eb

# Без ключевого слова async – оно не требуется
func execute(context: Dictionary) -> void:
	push_error("Ability.execute() not implemented for ", ability_name)

# Возвращает список возможных целей для этой способности в данном контексте.
func get_possible_targets(context: Dictionary) -> Array:
	return []
