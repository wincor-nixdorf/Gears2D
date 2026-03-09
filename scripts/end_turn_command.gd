# end_turn_command.gd
class_name EndTurnCommand
extends GameCommand

func can_execute() -> bool:
	return GameState.current_phase == Game.GamePhase.CHAIN_BUILDING and GameState.has_placed_this_turn

func execute() -> void:
	GameState.active_player_id = 1 - GameState.active_player_id
	EventBus.player_changed.emit(GameState.active_player_id)
	GameState.has_placed_this_turn = false
	if GameManager.ref.get_available_cells().is_empty():
		GameLogger.info("Player %d has no available moves. Chain ends." % (GameState.active_player_id + 1))
		GameManager.ref.end_chain_building()
	else:
		GameLogger.info("Turn passed to player %d" % (GameState.active_player_id + 1))
	GameManager.ref.update_ui()
