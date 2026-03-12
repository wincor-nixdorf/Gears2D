# resolution_phase.gd
class_name ResolutionPhase
extends Phase

func enter() -> void:
	GameLogger.debug("ResolutionPhase: enter")
	start_chain_resolution()

func start_chain_resolution() -> void:
	GameLogger.debug("start_chain_resolution called, chain_graph size: " + str(game_state.chain_graph.size()))
	if game_state.chain_graph.is_empty():
		game_manager.end_chain_resolution()
		return
	game_state.current_resolve_pos = game_state.last_cell_pos
	_set_active_cell(game_state.current_resolve_pos)
	game_state.came_from_edge = -1
	game_state.waiting_for_player = false
	var gear = board_manager.get_gear_at(game_state.current_resolve_pos)
	if gear:
		game_state.active_player_id = gear.owner_id
		EventBus.player_changed.emit(game_state.active_player_id)
	await resolve_current_gear()

func resolve_current_gear() -> void:
	_set_active_cell(game_state.current_resolve_pos)
	GameLogger.debug("resolve_current_gear called, pos: " + Game.pos_to_chess(game_state.current_resolve_pos))
	if game_state.current_resolve_pos == Vector2i(-1, -1):
		game_manager.end_chain_resolution()
		return
	var gear = board_manager.get_gear_at(game_state.current_resolve_pos)
	if not gear:
		game_state.current_resolve_pos = get_next_cell()
		await resolve_current_gear()
		return
	
	GameLogger.info("Resolving gear at %s" % Game.pos_to_chess(game_state.current_resolve_pos))
	
	var was_face_up = gear.is_face_up
	
	var skip = game_state.effect_system.has_modifier(gear, "no_auto_tick")
	GameLogger.debug("Auto tick skip: %s, can_rotate: %s, ticks: %d/%d" % [skip, gear.can_rotate(), gear.current_ticks, gear.max_ticks])
	if not skip and gear.can_rotate():
		print("ResolutionPhase: auto tick on ", gear.gear_name)
		await gear.do_tick(1)
		print("ResolutionPhase: auto tick finished on ", gear.gear_name)
		game_manager.update_ui()
	else:
		GameLogger.debug("Auto tick prevented by Time Swarm or gear already face up")
	
	EventBus.gear_resolved.emit(gear, was_face_up)
	
	game_state.waiting_for_player = true
	GameLogger.debug("Waiting for player action for gear at %s" % Game.pos_to_chess(game_state.current_resolve_pos))

func get_next_cell() -> Vector2i:
	var edges = game_state.chain_graph.get_edges_from(game_state.current_resolve_pos).duplicate()
	if game_state.came_from_edge != -1:
		for neighbor in edges.keys():
			if edges[neighbor] == game_state.came_from_edge:
				edges.erase(neighbor)
				break
	if edges.is_empty():
		GameLogger.debug("No available edges from %s – end of chain" % Game.pos_to_chess(game_state.current_resolve_pos))
		return Vector2i(-1, -1)
	var max_edge = -1
	var next_pos = Vector2i(-1, -1)
	for neighbor in edges:
		var eid = edges[neighbor]
		if eid > max_edge:
			max_edge = eid
			next_pos = neighbor
	game_state.came_from_edge = max_edge
	GameLogger.debug("From %s going to %s via edge %d" % [Game.pos_to_chess(game_state.current_resolve_pos), Game.pos_to_chess(next_pos), max_edge])
	return next_pos

func proceed_to_next_cell() -> void:
	game_state.waiting_for_player = false
	var next_pos = get_next_cell()
	if next_pos == Vector2i(-1, -1):
		game_manager.end_chain_resolution()
		game_manager.ui.cancel_target_selection()
	else:
		game_state.current_resolve_pos = next_pos
		var gear = board_manager.get_gear_at(game_state.current_resolve_pos)
		if gear:
			game_state.active_player_id = gear.owner_id
			EventBus.player_changed.emit(game_state.active_player_id)
		await resolve_current_gear()

func restart_chain_resolution() -> void:
	GameLogger.info("Restarting chain resolution from last cell")
	game_state.waiting_for_player = false
	game_state.current_resolve_pos = game_state.last_cell_pos
	_set_active_cell(game_state.current_resolve_pos)
	game_state.came_from_edge = -1
	if game_state.current_resolve_pos == Vector2i(-1, -1):
		GameLogger.warning("No last cell to restart from")
		game_manager.end_chain_resolution()
		return
	var gear = board_manager.get_gear_at(game_state.current_resolve_pos)
	if gear:
		game_state.active_player_id = gear.owner_id
		EventBus.player_changed.emit(game_state.active_player_id)
	await resolve_current_gear()

func handle_gear_clicked(gear: Gear) -> void:
	GameLogger.debug("ResolutionPhase handle_gear_clicked: " + gear.gear_name)
	if not game_state.waiting_for_player:
		GameLogger.debug("Not waiting for player, ignoring")
		return
	if gear != board_manager.get_gear_at(game_state.current_resolve_pos):
		GameLogger.debug("Gear mismatch: clicked gear not at current resolve pos")
		return
	
	var cmd = ExtraTickCommand.new(gear, game_manager, game_state)
	if cmd.can_execute():
		await cmd.execute()
	else:
		if not gear.can_rotate():
			GameLogger.warning("Cannot spend T on extra tick: gear is already face up or cannot rotate")
		else:
			GameLogger.warning("Could not spend T on extra tick")

func handle_cell_clicked(cell: Cell) -> void:
	if game_state.waiting_for_player and cell.board_pos == game_state.current_resolve_pos:
		var gear = cell.occupied_gear
		if gear:
			await handle_gear_clicked(gear)
			return
	GameLogger.debug("ResolutionPhase: ignoring cell click at %s" % Game.pos_to_chess(cell.board_pos))

func handle_action_button() -> void:
	if game_state.waiting_for_player:
		# Проверяем, не активен ли выбор цели
		if game_manager.ui.is_target_selection_active():
			GameLogger.debug("Cannot skip while target selection is active")
			return
		var cmd = SkipCommand.new(game_manager, game_state)
		if cmd.can_execute():
			cmd.execute()

func _set_active_cell(pos: Vector2i) -> void:
	game_manager.set_active_cell(pos)
