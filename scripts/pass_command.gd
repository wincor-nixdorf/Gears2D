# pass_command.gd
class_name PassCommand
extends GameCommand

func _init(gm: GameManager, gs: GameState) -> void:
	super(gm, gs)

func can_execute() -> bool:
	return game_state.current_phase == Game.GamePhase.CHAIN_BUILDING and game_manager.can_pass()

func execute() -> void:
	GameLogger.info("Player %d passes. Chain ends." % (game_state.active_player_id + 1))
	game_manager.end_chain_building()
