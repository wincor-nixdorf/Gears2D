# end_turn_command.gd - помечен как устаревший, используйте PassCommand
class_name EndTurnCommand
extends GameCommand

func _init(gm: GameManager, gs: GameState) -> void:
	super(gm, gs)

func can_execute() -> bool:
	# Этот класс больше не используется в новой системе фаз
	GameLogger.warning("EndTurnCommand is deprecated. Use PassCommand instead.")
	return false

func execute() -> void:
	pass
