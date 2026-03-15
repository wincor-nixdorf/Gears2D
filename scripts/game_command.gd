# game_command.gd
class_name GameCommand
extends RefCounted

var game_manager: GameManager
var game_state: GameState

func _init(gm: GameManager, gs: GameState) -> void:
	game_manager = gm
	game_state = gs

func can_execute() -> bool:
	return false

func execute() -> void:
	pass

func undo() -> void:
	pass
