# chain_building_phase.gd
class_name ChainBuildingPhase
extends Phase

func enter() -> void:
	GameLogger.debug("ChainBuildingPhase: enter")
	ui.cancel_target_selection()
	ui.clear_selection()
	game_manager.update_ui()

func handle_cell_clicked(cell: Cell) -> void:
	GameLogger.debug("ChainBuildingPhase.handle_cell_clicked: cell %s" % Game.pos_to_chess(cell.board_pos))
	var board_pos = cell.board_pos
	var active_player = game_state.active_player_id
	GameLogger.debug("Clicked cell %s, active player %d, last_cell_pos %s, has_placed=%s" % [
		Game.pos_to_chess(board_pos), active_player, Game.pos_to_chess(game_state.last_cell_pos), game_state.has_placed_this_turn])
	
	# Если уже сделали ход и кликнули по своей шестерне, интерпретируем как клик по шестерне (снятие T)
	if game_state.has_placed_this_turn and not cell.is_empty() and cell.occupied_gear.is_owned_by(active_player):
		handle_gear_clicked(cell.occupied_gear)
		return
	
	if game_state.has_placed_this_turn:
		GameLogger.warning("You have already made a move. Press 'End Turn' button to pass the turn.")
		return
	
	var is_white = cell.is_white()
	var current_player = players[active_player]
	
	var is_using_existing = not cell.is_empty() and cell.occupied_gear.is_owned_by(active_player)
	
	if not is_using_existing:
		if current_player.owner_id == 0 and not is_white:
			GameLogger.warning("Player 1 can only place on white cells")
			return
		if current_player.owner_id == 1 and is_white:
			GameLogger.warning("Player 2 can only place on black cells")
			return
	
	if game_state.last_cell_pos == Vector2i(-1, -1):
		GameLogger.debug("First move attempt")
		if not game_manager.is_valid_start_position(board_pos):
			GameLogger.warning("Cannot start chain from this cell")
			return
		if not cell.is_empty():
			GameLogger.warning("Starting cell must be empty")
			return
		if not game_state.selected_gear:
			GameLogger.warning("No gear selected")
			return
		
		var cmd = PlaceGearCommand.new(cell, current_player, game_state.selected_gear, game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()
			game_state.last_cell_pos = board_pos
			game_state.selected_gear = null
			ui.clear_selection()
			game_manager.update_ui()
			GameLogger.info("First move of the round: gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), game_state.t_pool[active_player]])
		else:
			GameLogger.warning("Cannot place gear")
		return
	
	if not game_manager.is_adjacent(game_state.last_cell_pos, board_pos):
		GameLogger.warning("Cell is not adjacent to the last one")
		return
	
	# Запрет на возврат назад (использование G на last_from_pos)
	if board_pos == game_state.last_from_pos:
		GameLogger.warning("Cannot go back to the previous gear")
		return
	
	if cell.is_empty():
		GameLogger.debug("Empty cell, attempting to place new gear")
		if not game_state.selected_gear:
			GameLogger.warning("No gear selected")
			return
		
		var cmd = PlaceGearCommand.new(cell, current_player, game_state.selected_gear, game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()
			game_manager.add_edge(game_state.last_cell_pos, board_pos)
			game_state.last_from_pos = game_state.last_cell_pos
			game_state.last_cell_pos = board_pos
			game_state.selected_gear = null
			ui.clear_selection()
			game_manager.update_ui()
			GameLogger.info("New gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), game_state.t_pool[active_player]])
		else:
			GameLogger.warning("Cannot place gear")
		return
	
	var gear = cell.occupied_gear
	GameLogger.debug("Occupied cell, gear owner %d, active player %d" % [gear.owner_id, active_player])
	if not gear.is_owned_by(active_player):
		GameLogger.warning("This is not your gear")
		return
	
	if game_state.chain_graph.has_edge(game_state.last_cell_pos, board_pos):
		GameLogger.warning("Cannot create double connection (2-cycle)")
		return
	
	# Проверяем, образуется ли цикл (цель уже есть в графе до добавления ребра)
	var forms_cycle = game_state.chain_graph.has_vertex(board_pos)
	
	# Добавляем ребро и начисляем T за использование существующей G
	game_manager.add_edge(game_state.last_cell_pos, board_pos)
	game_state.last_from_pos = game_state.last_cell_pos
	game_state.last_cell_pos = board_pos
	
	# Начисляем T за использование существующей G
	game_state.t_pool[active_player] += 1
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	if forms_cycle:
		GameLogger.info("Cycle formed at %s. Chain building phase ends." % Game.pos_to_chess(board_pos))
		game_manager.on_successful_placement()
		game_manager.end_chain_building()
		return
	else:
		GameLogger.info("Existing gear on board used at %s" % Game.pos_to_chess(board_pos))
		game_manager.on_successful_placement()
		return

func handle_gear_clicked(gear: Gear) -> void:
	var cell = gear.get_parent() as Cell
	if not cell:
		return
	
	if game_state.has_placed_this_turn:
		if not gear.is_owned_by(game_state.active_player_id):
			GameLogger.warning("This is not your gear")
			return
		if not cell or not game_state.chain_graph.has_vertex(cell.board_pos):
			GameLogger.warning("This gear is not in the current chain")
			return
		if not gear.can_rotate():
			GameLogger.warning("Gear has already triggered and cannot rotate")
			return
		
		# Проверяем, что это последняя G в цепочке
		if cell.board_pos != game_state.last_cell_pos:
			GameLogger.warning("You can only take T from the last gear placed in the chain")
			return
		
		var cmd = TakeTCommand.new(gear, 1, game_manager, game_state)
		if cmd.can_execute():
			await cmd.execute()
			game_manager.update_ui()
		else:
			GameLogger.warning("Could not take T from gear")
		return
	
	# Если ещё не сделали ход, но кликнули на свою G, интерпретируем как использование существующей для продолжения
	if gear.is_owned_by(game_state.active_player_id) and game_manager.is_adjacent(game_state.last_cell_pos, cell.board_pos):
		GameLogger.debug("Gear click interpreted as cell click for chain continuation")
		handle_cell_clicked(cell)
		return
	
	GameLogger.warning("You need to place a gear in the chain first")

func handle_action_button() -> void:
	if game_state.has_placed_this_turn:
		var cmd = EndTurnCommand.new(game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()
	else:
		var cmd = PassCommand.new(game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()
		else:
			GameLogger.warning("Pass not available: you haven't made a move this round or the round just started.")

func update_ui() -> void:
	game_manager.update_ui()
