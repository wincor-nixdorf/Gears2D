# skip_command.gd
class_name SkipCommand
extends GameCommand

func _init(gm: GameManager, gs: GameState) -> void:
	super(gm, gs)

func can_execute() -> bool:
	if game_manager.ui.is_target_selection_active():
		return false
	return game_state.current_phase == Game.GamePhase.CHAIN_RESOLUTION and game_state.waiting_for_player

func execute() -> void:
	GameLogger.debug("Skipping current gear")
	game_manager.proceed_to_next_cell()
