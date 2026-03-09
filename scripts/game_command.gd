# game_command.gd
class_name GameCommand
extends RefCounted

func can_execute() -> bool:
	return false

func execute() -> void:
	pass

func undo() -> void:
	pass
