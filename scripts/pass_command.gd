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
	GameLogger.debug("PassCommand: can_execute = true")
	return true

func execute() -> void:
	var current_player = game_state.active_player_id
	GameLogger.info("Player %d passes." % (current_player + 1))
	
	# Увеличиваем счётчик последовательных пасов
	game_state.consecutive_passes += 1
	
	# Если оба игрока пасанули подряд, завершаем фазу построения
	if game_state.consecutive_passes >= 2:
		GameLogger.info("Both players passed. Chain building phase ends.")
		game_manager.end_chain_building()
	else:
		# Сбрасываем флаги хода для текущего игрока
		game_state.has_placed_this_turn = false
		game_state.extra_T_available = false
		game_state.extra_T_gear = null
		
		# Меняем активного игрока
		game_state.active_player_id = 1 - current_player
		EventBus.player_changed.emit(game_state.active_player_id)
		GameLogger.info("Turn passed to player %d" % (game_state.active_player_id + 1))
		
		# Проверяем, есть ли у нового игрока доступные ходы
		if game_manager.get_available_cells().is_empty():
			GameLogger.info("Player %d has no available moves. Ending chain building phase." % (game_state.active_player_id + 1))
			game_manager.end_chain_building()
		else:
			game_manager.update_ui()
