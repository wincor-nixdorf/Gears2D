# end_turn_command.gd
class_name EndTurnCommand
extends GameCommand

func _init(gm: GameManager, gs: GameState) -> void:
	super(gm, gs)

func can_execute() -> bool:
	return game_state.current_phase == Game.GamePhase.CHAIN_BUILDING and game_state.has_placed_this_turn

func execute() -> void:
	game_state.active_player_id = 1 - game_state.active_player_id
	EventBus.player_changed.emit(game_state.active_player_id)
	game_state.has_placed_this_turn = false
	if game_manager.get_available_cells().is_empty():
		GameLogger.info("Player %d has no available moves. Chain ends." % (game_state.active_player_id + 1))
		game_manager.end_chain_building()
	else:
		GameLogger.info("Turn passed to player %d" % (game_state.active_player_id + 1))
	# Удален game_manager.update_ui()
