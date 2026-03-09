# skip_command.gd
class_name SkipCommand
extends GameCommand

func can_execute() -> bool:
	return GameState.current_phase == Game.GamePhase.CHAIN_RESOLUTION and GameState.waiting_for_player

func execute() -> void:
	GameLogger.debug("Skipping current gear")
	GameManager.ref.proceed_to_next_cell()
