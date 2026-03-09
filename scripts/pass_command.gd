# pass_command.gd
class_name PassCommand
extends GameCommand

func can_execute() -> bool:
	return GameState.current_phase == Game.GamePhase.CHAIN_BUILDING and GameManager.ref.can_pass()

func execute() -> void:
	GameLogger.info("Player %d passes. Chain ends." % (GameState.active_player_id + 1))
	GameManager.ref.end_chain_building()
