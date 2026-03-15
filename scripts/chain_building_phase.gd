# chain_building_phase.gd
class_name ChainBuildingPhase
extends Phase

var _selected_creature: Gear = null

func enter() -> void:
	GameLogger.debug("ChainBuildingPhase: enter")
	ui.cancel_target_selection()
	ui.clear_selection()
	_clear_selected_creature()
	game_manager.update_ui()

func exit() -> void:
	_clear_selected_creature()
	super()

func _clear_selected_creature() -> void:
	if _selected_creature:
		_selected_creature.set_selected(false)
		_selected_creature = null
		board_manager.reset_highlights()
	game_state.selected_creature = null

func handle_cell_clicked(cell: Cell) -> void:
	GameLogger.debug("ChainBuildingPhase.handle_cell_clicked: cell %s" % Game.pos_to_chess(cell.board_pos))
	
	if _selected_creature:
		_handle_creature_move(cell)
		return
	
	var board_pos = cell.board_pos
	var active_player = game_state.active_player_id
	GameLogger.debug("Clicked cell %s, active player %d, last_cell_pos %s, has_placed=%s" % [
		Game.pos_to_chess(board_pos), active_player, Game.pos_to_chess(game_state.last_cell_pos), game_state.has_placed_this_turn])
	
	# Если уже сделали ход и кликнули по своей шестерне, интерпретируем как клик по шестерне (снятие T)
	if game_state.has_placed_this_turn and not cell.is_empty() and cell.occupied_gear.is_owned_by(active_player):
		handle_gear_clicked(cell.occupied_gear, MOUSE_BUTTON_LEFT)
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

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	var cell = gear.get_parent() as Cell
	if not cell:
		return
	
	# Логирование для диагностики
	GameLogger.debug("handle_gear_clicked: gear=%s, owned=%s, type=%s, in_chain=%s, selected_gear=%s, selected_creature=%s, last_cell_pos=%s, button=%s" % [
		gear.gear_name,
		gear.is_owned_by(game_state.active_player_id),
		GameEnums.GearType.keys()[gear.type] if gear.type != null else "null",
		game_state.chain_graph.has_vertex(cell.board_pos),
		game_state.selected_gear,
		_selected_creature,
		Game.pos_to_chess(game_state.last_cell_pos),
		button_index
	])
	
	# Если есть выбранное существо, но кликнули на другое существо – возможно, хотим выбрать другое
	if _selected_creature:
		# Если кликнули на другое своё существо, которое не в цепочке, переключаем выделение
		if gear != _selected_creature and gear.is_owned_by(game_state.active_player_id) and gear.type == GameEnums.GearType.CREATURE and not game_state.chain_graph.has_vertex(cell.board_pos):
			_clear_selected_creature()
			if button_index == MOUSE_BUTTON_RIGHT:
				_select_creature(gear)
			else:
				# Если ЛКМ, интерпретируем как обычный клик
				pass
		else:
			# Если кликнули на то же или неподходящее, сбрасываем
			_clear_selected_creature()
		return
	
	# Различаем ЛКМ и ПКМ
	if button_index == MOUSE_BUTTON_RIGHT:
		# ПКМ - выбор существа для перемещения
		if not game_state.selected_gear and gear.is_owned_by(game_state.active_player_id) and gear.type == GameEnums.GearType.CREATURE and not game_state.chain_graph.has_vertex(cell.board_pos):
			_select_creature(gear)
		else:
			GameLogger.warning("Cannot select creature with right click")
		return
	
	# Далее обработка ЛКМ (обычные действия)
	# Обычная обработка клика по шестерне
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
	
	# Если кликнули на своё существо, которое не в цепочке, и нет выбранной карты из руки, то выбираем его для перемещения (ЛКМ тоже может выбирать, но лучше ПКМ, оставим для совместимости)
	if not game_state.selected_gear and gear.is_owned_by(game_state.active_player_id) and gear.type == GameEnums.GearType.CREATURE and not game_state.chain_graph.has_vertex(cell.board_pos):
		_select_creature(gear)
		return
	
	GameLogger.warning("You need to place a gear in the chain first")

func _select_creature(gear: Gear) -> void:
	_selected_creature = gear
	gear.set_selected(true)
	game_state.selected_creature = gear
	_highlight_reachable_cells(gear)

func _highlight_reachable_cells(creature: Gear) -> void:
	var from_cell = creature.get_parent() as Cell
	if not from_cell:
		return
	var reachable = game_manager.rule_validator.get_reachable_cells_for_creature(creature, from_cell.board_pos, game_state.last_cell_pos)
	# Фильтруем только те клетки, которые могут продолжить цепочку (смежны с last_cell_pos и не запрещены)
	var valid_cells: Array[Cell] = []
	for cell in reachable:
		if game_manager.is_adjacent(game_state.last_cell_pos, cell.board_pos) and cell.board_pos != game_state.last_from_pos:
			valid_cells.append(cell)
	board_manager.highlight_cells(valid_cells, Color.GREEN)

func _handle_creature_move(target_cell: Cell) -> void:
	var creature = _selected_creature
	var from_cell = creature.get_parent() as Cell
	if not from_cell:
		_clear_selected_creature()
		return
	
	# Проверяем, что клетка пуста
	if not target_cell.is_empty():
		GameLogger.warning("Target cell is not empty")
		_clear_selected_creature()
		return
	
	# Проверяем, что клетка подходит для продолжения цепочки
	if game_state.last_cell_pos == Vector2i(-1, -1):
		GameLogger.warning("Cannot move creature as first move")
		_clear_selected_creature()
		return
	
	if not game_manager.is_adjacent(game_state.last_cell_pos, target_cell.board_pos):
		GameLogger.warning("Target cell is not adjacent to the last cell")
		_clear_selected_creature()
		return
	
	if target_cell.board_pos == game_state.last_from_pos:
		GameLogger.warning("Cannot go back to the previous gear")
		_clear_selected_creature()
		return
	
	# Проверяем цвет
	var is_white = target_cell.is_white()
	var active_player = game_state.active_player_id
	if (active_player == 0 and not is_white) or (active_player == 1 and is_white):
		GameLogger.warning("Wrong cell color for your creature")
		_clear_selected_creature()
		return
	
	# Проверяем расстояние
	var from_pos = from_cell.board_pos
	var to_pos = target_cell.board_pos
	var dx = abs(to_pos.x - from_pos.x)
	var dy = abs(to_pos.y - from_pos.y)
	var distance = max(dx, dy)
	if distance > creature.speed:
		GameLogger.warning("Creature cannot move that far (speed %d, distance %d)" % [creature.speed, distance])
		_clear_selected_creature()
		return
	
	# Для нелетающих существ проверяем, что путь свободен
	if not creature.is_flying:
		var player_color_is_white = (active_player == 0)
		if not game_manager.rule_validator.is_path_clear_for_king(from_pos, to_pos, player_color_is_white):
			GameLogger.warning("Path is not clear for non-flying creature")
			_clear_selected_creature()
			return
	
	# Выполняем перемещение
	# Убираем существо со старой клетки
	from_cell.occupied_gear = null
	from_cell.remove_child(creature)
	# Помещаем на новую
	target_cell.set_occupied(creature)
	creature.board_position = to_pos
	
	# Добавляем ребро
	game_manager.add_edge(game_state.last_cell_pos, to_pos)
	game_state.last_from_pos = game_state.last_cell_pos
	game_state.last_cell_pos = to_pos
	
	# Отмечаем, что ход сделан
	game_state.has_placed_this_turn = true
	game_state.moves_in_round += 1
	
	GameLogger.info("Creature %s moved from %s to %s" % [creature.gear_name, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)])
	
	# Очищаем выделение
	_clear_selected_creature()
	game_manager.update_ui()

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
