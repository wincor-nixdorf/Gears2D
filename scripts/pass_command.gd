# pass_command.gd
class_name PassCommand
extends GameCommand

func _init(gm: GameManager, gs: GameState) -> void:
	super(gm, gs)

func can_execute() -> bool:
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("PassCommand: stack not empty")
		return false
	if game_state.current_phase != Game.GamePhase.CHAIN_BUILDING:
		GameLogger.debug("PassCommand: wrong phase, current = %s" % game_state.current_phase)
		return false
	if not game_manager.can_pass():
		GameLogger.debug("PassCommand: can_pass returned false")
		return false
	GameLogger.debug("PassCommand: can_execute = true")
	return true

func execute() -> void:
	GameLogger.info("Player %d passes. Chain ends." % (game_state.active_player_id + 1))
	game_manager.end_chain_building()
