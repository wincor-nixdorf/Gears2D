# game_command.gd
class_name GameCommand
extends RefCounted

var game_manager: GameManager
var game_state: GameState

func _init(gm: GameManager, gs: GameState) -> void:
	game_manager = gm
	game_state = gs

# Проверяет, может ли команда быть выполнена в текущем состоянии
func can_execute() -> bool:
	return false

# Выполняет команду
func execute() -> void:
	pass

# Отменяет команду (опционально)
func undo() -> void:
	pass
