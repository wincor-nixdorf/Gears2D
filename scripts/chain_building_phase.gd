# chain_building_phase.gd
class_name ChainBuildingPhase
extends Phase

enum EmbedStep {
	BEFORE,
	EMBED,
	AFTER
}

var _selected_creature: Gear = null
var _current_embed_step: EmbedStep = EmbedStep.BEFORE
var _is_waiting_for_priority: bool = false
var _starter_player_id: int = 0

func enter() -> void:
	GameLogger.debug("ChainBuildingPhase: enter - start")
	ui.cancel_target_selection()
	ui.clear_selection()
	_clear_selected_creature()
	_current_embed_step = EmbedStep.BEFORE
	
	_starter_player_id = game_state.start_player_id
	GameLogger.debug("ChainBuildingPhase: starter player = %d" % (_starter_player_id + 1))
	
	await game_manager.get_tree().process_frame
	
	_process_embed_step()
	GameLogger.debug("ChainBuildingPhase: enter - end")

func exit() -> void:
	_clear_selected_creature()
	_is_waiting_for_priority = false
	super()

func _clear_selected_creature() -> void:
	if _selected_creature:
		_selected_creature.set_selected(false)
		_selected_creature = null
		board_manager.reset_highlights()
	game_state.selected_creature = null

func _process_embed_step() -> void:
	match _current_embed_step:
		EmbedStep.BEFORE:
			_start_before_embed()
		EmbedStep.EMBED:
			_start_embed()
		EmbedStep.AFTER:
			_start_after_embed()

func _start_before_embed() -> void:
	GameLogger.debug("ChainBuildingPhase: BEFORE EMBED step")
	
	game_state.active_player_id = _starter_player_id
	EventBus.player_changed.emit(game_state.active_player_id)
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_step("Before Embed", game_state.active_player_id)
	
	var context = {"phase": game_state.current_phase, "step": "before_embed"}
	game_state.effect_system.process_delayed_effects(GameEnums.TriggerCondition.ON_PHASE_START, context)
	
	await _run_priority_cycle("Before")
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.end_step()
	
	_current_embed_step = EmbedStep.EMBED
	_process_embed_step()

func _start_embed() -> void:
	GameLogger.debug("ChainBuildingPhase: EMBED step")
	
	game_state.active_player_id = _starter_player_id
	EventBus.player_changed.emit(game_state.active_player_id)
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_step("Embed", game_state.active_player_id)
	
	game_state.has_placed_this_turn = false
	
	await _run_action_cycle()
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.end_step()
	
	_current_embed_step = EmbedStep.AFTER
	_process_embed_step()

func _start_after_embed() -> void:
	GameLogger.debug("ChainBuildingPhase: AFTER EMBED step")
	
	game_state.active_player_id = _starter_player_id
	EventBus.player_changed.emit(game_state.active_player_id)
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_step("After Embed", game_state.active_player_id)
	
	var context = {"phase": game_state.current_phase, "step": "after_embed"}
	game_state.effect_system.process_delayed_effects(GameEnums.TriggerCondition.ON_PHASE_END, context)
	
	print("Calling _run_priority_cycle for After")
	await _run_priority_cycle("After")
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.end_step()
	
	_end_embed_cycle()

func _run_priority_cycle(step_name: String) -> void:
	var players_passed = 0
	var current_player = game_state.active_player_id
	
	while players_passed < 2:
		game_state.waiting_for_player = true
		game_state.priority_player = current_player
		game_manager.update_ui()
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Priority to Player %d (%s)" % [current_player + 1, step_name],
				current_player
			)
		
		await _wait_for_player_pass()
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Player %d passed" % (current_player + 1),
				current_player
			)
		
		players_passed += 1
		game_state.waiting_for_player = false
		game_state.priority_player = -1
		
		if players_passed < 2:
			current_player = 1 - current_player
			await _wait_for_timer(0.1)
	
	game_state.waiting_for_player = false
	game_state.priority_player = -1

func _run_action_cycle() -> void:
	var current_player = _starter_player_id
	
	while true:
		game_state.waiting_for_player = true
		game_state.priority_player = current_player
		game_manager.update_ui()
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Priority to Player %d (Embed)" % (current_player + 1),
				current_player
			)
		
		await _wait_for_player_action()
		
		if game_state.has_placed_this_turn:
			_starter_player_id = current_player
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action(
					"Player %d made a move" % (current_player + 1),
					current_player
				)
			break
		else:
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action(
					"Player %d passed" % (current_player + 1),
					current_player
				)
			
			game_state.waiting_for_player = false
			game_state.priority_player = -1
			
			if current_player == _starter_player_id:
				GameLogger.debug("Starter player %d passed, ending chain building phase" % (current_player + 1))
				game_state.has_placed_this_turn = false
				GameLogger.info("Starter player passed - no move made. Chain building phase ends.")
				game_manager.end_chain_building()
				return
			
			await _wait_for_timer(0.1)
			
			current_player = 1 - current_player
			game_state.priority_player = current_player
	
	game_state.waiting_for_player = false
	game_state.priority_player = -1

func _wait_for_player_pass() -> void:
	_is_waiting_for_priority = true
	while _is_waiting_for_priority:
		await _wait_for_next_frame()
		if not game_state.waiting_for_player and game_manager.stack_manager.is_stack_empty():
			_is_waiting_for_priority = false

func _wait_for_player_action() -> void:
	_is_waiting_for_priority = true
	while _is_waiting_for_priority:
		await _wait_for_next_frame()
		if game_state.has_placed_this_turn or not game_state.waiting_for_player:
			_is_waiting_for_priority = false

func _wait_for_next_frame() -> void:
	await game_manager.get_tree().process_frame

func _wait_for_timer(seconds: float) -> void:
	await game_manager.get_tree().create_timer(seconds).timeout

func _end_embed_cycle() -> void:
	GameLogger.debug("ChainBuildingPhase: Embed cycle completed")
	
	if game_state.has_placed_this_turn:
		game_state.has_placed_this_turn = false
		
		_starter_player_id = 1 - _starter_player_id
		game_state.start_player_id = _starter_player_id
		game_state.active_player_id = _starter_player_id
		EventBus.player_changed.emit(game_state.active_player_id)
		GameLogger.info("Turn passed to player %d for next cycle" % (_starter_player_id + 1))
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Turn passed to Player %d for next cycle" % (_starter_player_id + 1),
				_starter_player_id
			)
		
		if game_manager.get_available_cells().is_empty():
			GameLogger.info("Player %d has no available moves. Ending chain building phase." % (_starter_player_id + 1))
			game_manager.end_chain_building()
			return
		
		_current_embed_step = EmbedStep.BEFORE
		_process_embed_step()
		return
	
	GameLogger.info("No moves made in Embed step. Chain building phase ends.")
	game_manager.end_chain_building()

func handle_cell_clicked(cell: Cell) -> void:
	GameLogger.debug("ChainBuildingPhase.handle_cell_clicked: cell %s, current_step=%s" % [Game.pos_to_chess(cell.board_pos), _current_embed_step])
	
	if _current_embed_step != EmbedStep.EMBED:
		GameLogger.warning("Cannot place gear outside of Embed step (current step: %s)" % _current_embed_step)
		return
	
	if _selected_creature:
		_handle_creature_move(cell)
		return
	
	var board_pos = cell.board_pos
	var active_player = game_state.active_player_id
	
	if game_state.has_placed_this_turn:
		GameLogger.warning("You have already made a move this turn. Press Pass to end your turn.")
		return
	
	var is_white = cell.is_white()
	var current_player = game_manager.players[active_player]
	
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
		
		# Проверка легендарности
		if not game_manager.can_control_legendary(game_state.selected_gear, active_player):
			GameLogger.warning("Cannot control another copy of this legendary gear")
			return
		
		var cmd = PlaceGearCommand.new(cell, current_player, game_state.selected_gear, game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()
			game_state.last_cell_pos = board_pos
			game_state.chain_order.append(board_pos)
			var placed_gear = game_state.selected_gear
			game_state.selected_gear = null
			ui.clear_selection()
			game_manager.on_successful_placement()
			
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action(
					"First move: placed %s at %s" % [placed_gear.gear_name, Game.pos_to_chess(board_pos)],
					active_player,
					{"gear": placed_gear.gear_name, "position": Game.pos_to_chess(board_pos)}
				)
			
			game_state.has_placed_this_turn = true
			game_state.waiting_for_player = false
			game_manager.update_ui()
			GameLogger.info("First move of the round: gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), game_state.t_pool[active_player]])
		else:
			GameLogger.warning("Cannot place gear")
		return
	
	if not game_manager.is_adjacent(game_state.last_cell_pos, board_pos):
		GameLogger.warning("Cell is not adjacent to the last one")
		return
	
	if board_pos == game_state.last_from_pos:
		GameLogger.warning("Cannot go back to the previous gear")
		return
	
	if cell.is_empty():
		GameLogger.debug("Empty cell, attempting to place new gear")
		if not game_state.selected_gear:
			GameLogger.warning("No gear selected")
			return
		
		# Проверка легендарности
		if not game_manager.can_control_legendary(game_state.selected_gear, active_player):
			GameLogger.warning("Cannot control another copy of this legendary gear")
			return
		
		var cmd = PlaceGearCommand.new(cell, current_player, game_state.selected_gear, game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()
			game_manager.add_edge(game_state.last_cell_pos, board_pos)
			game_state.last_from_pos = game_state.last_cell_pos
			game_state.last_cell_pos = board_pos
			game_state.chain_order.append(board_pos)
			var placed_gear = game_state.selected_gear
			game_state.selected_gear = null
			ui.clear_selection()
			game_manager.on_successful_placement()
			
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action(
					"Placed new %s at %s" % [placed_gear.gear_name, Game.pos_to_chess(board_pos)],
					active_player,
					{"gear": placed_gear.gear_name, "position": Game.pos_to_chess(board_pos)}
				)
			
			game_state.has_placed_this_turn = true
			game_state.waiting_for_player = false
			game_manager.update_ui()
			GameLogger.info("New gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), game_state.t_pool[active_player]])
		else:
			GameLogger.warning("Cannot place gear")
		return
	
	var gear = cell.occupied_gear
	if not gear.is_owned_by(active_player):
		GameLogger.warning("This is not your gear")
		return
	
	if game_state.chain_graph.has_edge(game_state.last_cell_pos, board_pos):
		GameLogger.warning("Cannot create double connection (2-cycle)")
		return
	
	var forms_cycle = game_state.chain_graph.has_vertex(board_pos)
	
	game_manager.add_edge(game_state.last_cell_pos, board_pos)
	game_state.last_from_pos = game_state.last_cell_pos
	game_state.last_cell_pos = board_pos
	game_state.chain_order.append(board_pos)
	
	game_state.t_pool[active_player] += 1
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Used existing %s at %s" % [gear.gear_name, Game.pos_to_chess(board_pos)],
			active_player,
			{"gear": gear.gear_name, "position": Game.pos_to_chess(board_pos), "forms_cycle": forms_cycle}
		)
	
	if forms_cycle:
		GameLogger.info("Cycle formed at %s. Chain building phase ends." % Game.pos_to_chess(board_pos))
		game_manager.on_successful_placement()
		game_manager.end_chain_building()
		return
	else:
		GameLogger.info("Existing gear on board used at %s" % Game.pos_to_chess(board_pos))
		game_manager.on_successful_placement()
		game_state.has_placed_this_turn = true
		game_state.waiting_for_player = false
		game_manager.update_ui()
		return

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	var cell = gear.get_parent() as Cell
	if not cell:
		return
	
	# Обработка снятия ресурса (Tapping) - доступно всегда, когда есть приоритет
	if button_index == MOUSE_BUTTON_LEFT and game_state.waiting_for_player and game_state.priority_player == game_state.active_player_id:
		var cmd = TakeTCommand.new(gear, 1, game_manager, game_state)
		if cmd.can_execute():
			await cmd.execute()
			game_manager.update_ui()
			return
	
	if _selected_creature:
		if gear != _selected_creature and gear.is_owned_by(game_state.active_player_id) and gear.type == GameEnums.GearType.CREATURE and not game_state.chain_graph.has_vertex(cell.board_pos):
			_clear_selected_creature()
			if button_index == MOUSE_BUTTON_RIGHT:
				_select_creature(gear)
		else:
			_clear_selected_creature()
		return
	
	if button_index == MOUSE_BUTTON_RIGHT:
		if not game_state.selected_gear and gear.is_owned_by(game_state.active_player_id) and gear.type == GameEnums.GearType.CREATURE and not game_state.chain_graph.has_vertex(cell.board_pos):
			_select_creature(gear)
		else:
			GameLogger.warning("Cannot select creature with right click")
		return
	
	# Обычное встраивание только в Embed шаге
	if _current_embed_step == EmbedStep.EMBED:
		if game_state.has_placed_this_turn:
			GameLogger.warning("You have already made a move this turn. Press Pass to end your turn.")
			return
		
		# Обработка клика по клетке или шестерне для встраивания
		if gear.is_owned_by(game_state.active_player_id) and game_manager.is_adjacent(game_state.last_cell_pos, cell.board_pos):
			GameLogger.debug("Gear click interpreted as cell click for chain continuation")
			handle_cell_clicked(cell)
			return
	
	if not game_state.selected_gear and gear.is_owned_by(game_state.active_player_id) and gear.type == GameEnums.GearType.CREATURE and not game_state.chain_graph.has_vertex(cell.board_pos):
		_select_creature(gear)
		return
	
	GameLogger.warning("You need to place a gear in the chain first")

func _select_creature(gear: Gear) -> void:
	_selected_creature = gear
	gear.set_selected(true)
	game_state.selected_creature = gear
	_highlight_reachable_cells(gear)
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Selected creature %s at %s for move" % [gear.gear_name, Game.pos_to_chess(gear.board_position)],
			game_state.active_player_id,
			{"gear": gear.gear_name, "position": Game.pos_to_chess(gear.board_position), "speed": gear.speed}
		)

func _highlight_reachable_cells(creature: Gear) -> void:
	var from_cell = creature.get_parent() as Cell
	if not from_cell:
		return
	var reachable = game_manager.rule_validator.get_reachable_cells_for_creature(creature, from_cell.board_pos, game_state.last_cell_pos)
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
	
	if not target_cell.is_empty():
		GameLogger.warning("Target cell is not empty")
		_clear_selected_creature()
		return
	
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
	
	var is_white = target_cell.is_white()
	var active_player = game_state.active_player_id
	if (active_player == 0 and not is_white) or (active_player == 1 and is_white):
		GameLogger.warning("Wrong cell color for your creature")
		_clear_selected_creature()
		return
	
	var from_pos = from_cell.board_pos
	var to_pos = target_cell.board_pos
	var dx = abs(to_pos.x - from_pos.x)
	var dy = abs(to_pos.y - from_pos.y)
	var distance = max(dx, dy)
	if distance > creature.speed:
		GameLogger.warning("Creature cannot move that far (speed %d, distance %d)" % [creature.speed, distance])
		_clear_selected_creature()
		return
	
	if not creature.is_flying:
		var player_color_is_white = (active_player == 0)
		if not game_manager.rule_validator.is_path_clear_for_king(from_pos, to_pos, player_color_is_white):
			GameLogger.warning("Path is not clear for non-flying creature")
			_clear_selected_creature()
			return
	
	from_cell.occupied_gear = null
	from_cell.remove_child(creature)
	target_cell.set_occupied(creature)
	creature.board_position = to_pos
	
	game_manager.add_edge(game_state.last_cell_pos, to_pos)
	game_state.last_from_pos = game_state.last_cell_pos
	game_state.last_cell_pos = to_pos
	game_state.chain_order.append(to_pos)
	
	game_manager.on_successful_placement()
	GameLogger.info("Creature %s moved from %s to %s" % [creature.gear_name, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)])
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Moved %s from %s to %s" % [creature.gear_name, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)],
			active_player,
			{"gear": creature.gear_name, "from": Game.pos_to_chess(from_pos), "to": Game.pos_to_chess(to_pos), "distance": distance}
		)
	
	_clear_selected_creature()
	game_state.has_placed_this_turn = true
	game_state.waiting_for_player = false
	game_manager.update_ui()

func is_embed_step() -> bool:
	return _current_embed_step == EmbedStep.EMBED
	
func handle_action_button() -> void:
	match _current_embed_step:
		EmbedStep.BEFORE, EmbedStep.AFTER:
			GameLogger.debug("Passing priority in BEFORE/AFTER step")
			game_state.waiting_for_player = false
			game_state.priority_player = -1
		EmbedStep.EMBED:
			GameLogger.debug("Pass command in EMBED step")
			game_state.waiting_for_player = false
			game_state.priority_player = -1

func update_ui() -> void:
	game_manager.update_ui()
