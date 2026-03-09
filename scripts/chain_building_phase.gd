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
	var active_player = GameState.active_player_id
	GameLogger.debug("Clicked cell %s, active player %d, last_cell_pos %s, has_placed=%s" % [
		Game.pos_to_chess(board_pos), active_player, Game.pos_to_chess(GameState.last_cell_pos), GameState.has_placed_this_turn])
	
	# Если уже сделали ход и кликнули по своей шестерне, интерпретируем как клик по шестерне (снятие T)
	if GameState.has_placed_this_turn and not cell.is_empty() and cell.occupied_gear.is_owned_by(active_player):
		handle_gear_clicked(cell.occupied_gear)
		return
	
	if GameState.has_placed_this_turn:
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
	
	if GameState.last_cell_pos == Vector2i(-1, -1):
		GameLogger.debug("First move attempt")
		if not game_manager.is_valid_start_position(board_pos):
			GameLogger.warning("Cannot start chain from this cell")
			return
		if not cell.is_empty():
			GameLogger.warning("Starting cell must be empty")
			return
		if not GameState.selected_gear:
			GameLogger.warning("No gear selected")
			return
		
		var cmd = PlaceGearCommand.new(cell, current_player, GameState.selected_gear)
		if cmd.can_execute():
			cmd.execute()
			GameState.last_cell_pos = board_pos
			GameState.selected_gear = null
			ui.clear_selection()
			game_manager.update_ui()
			GameLogger.info("First move of the round: gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), GameState.t_pool[active_player]])
		else:
			GameLogger.warning("Cannot place gear")
		return
	
	if not game_manager.is_adjacent(GameState.last_cell_pos, board_pos):
		GameLogger.warning("Cell is not adjacent to the last one")
		return
	
	if cell.is_empty():
		GameLogger.debug("Empty cell, attempting to place new gear")
		if not GameState.selected_gear:
			GameLogger.warning("No gear selected")
			return
		
		var cmd = PlaceGearCommand.new(cell, current_player, GameState.selected_gear)
		if cmd.can_execute():
			cmd.execute()
			game_manager.add_edge(GameState.last_cell_pos, board_pos)
			GameState.last_from_pos = GameState.last_cell_pos
			GameState.last_cell_pos = board_pos
			GameState.selected_gear = null
			ui.clear_selection()
			game_manager.update_ui()
			GameLogger.info("New gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), GameState.t_pool[active_player]])
		else:
			GameLogger.warning("Cannot place gear")
		return
	
	var gear = cell.occupied_gear
	GameLogger.debug("Occupied cell, gear owner %d, active player %d" % [gear.owner_id, active_player])
	if not gear.is_owned_by(active_player):
		GameLogger.warning("This is not your gear")
		return
	
	if GameState.chain_graph.has_edge(GameState.last_cell_pos, board_pos):
		GameLogger.warning("Cannot create double connection (2-cycle)")
		return
	
	if GameState.chain_graph.has_vertex(board_pos):
		if board_pos == GameState.last_cell_pos:
			GameLogger.warning("Cannot use the same cell as the last one")
			return
		game_manager.add_edge(GameState.last_cell_pos, board_pos)
		GameState.last_from_pos = GameState.last_cell_pos
		GameState.last_cell_pos = board_pos
		GameLogger.info("Cycle formed at %s. Chain building phase ends." % Game.pos_to_chess(board_pos))
		game_manager.on_successful_placement()
		game_manager.end_chain_building()
		return
	else:
		game_manager.add_edge(GameState.last_cell_pos, board_pos)
		GameState.last_from_pos = GameState.last_cell_pos
		GameState.last_cell_pos = board_pos
		GameLogger.info("Existing gear on board used at %s" % Game.pos_to_chess(board_pos))
		game_manager.on_successful_placement()
		return

func handle_gear_clicked(gear: Gear) -> void:
	var cell = gear.get_parent() as Cell
	if not cell:
		return
	
	if GameState.has_placed_this_turn:
		if not gear.is_owned_by(GameState.active_player_id):
			GameLogger.warning("This is not your gear")
			return
		if not cell or not GameState.chain_graph.has_vertex(cell.board_pos):
			GameLogger.warning("This gear is not in the current chain")
			return
		if not gear.can_rotate():
			GameLogger.warning("Gear has already triggered and cannot rotate")
			return
		
		var cmd = TakeTCommand.new(gear)
		if cmd.can_execute():
			cmd.execute()
			game_manager.update_ui()
		else:
			GameLogger.warning("Could not take T from gear")
		return
	
	if gear.is_owned_by(GameState.active_player_id) and game_manager.is_adjacent(GameState.last_cell_pos, cell.board_pos):
		GameLogger.debug("Gear click interpreted as cell click for chain continuation")
		handle_cell_clicked(cell)
		return
	
	GameLogger.warning("You need to place a gear in the chain first")

func handle_action_button() -> void:
	if GameState.has_placed_this_turn:
		var cmd = EndTurnCommand.new()
		if cmd.can_execute():
			cmd.execute()
	else:
		var cmd = PassCommand.new()
		if cmd.can_execute():
			cmd.execute()
		else:
			GameLogger.warning("Pass not available: you haven't made a move this round or the round just started.")

func update_ui() -> void:
	game_manager.update_ui()
