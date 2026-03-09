# resolution_phase.gd
class_name ResolutionPhase
extends Phase

func enter() -> void:
	GameLogger.debug("ResolutionPhase: enter")
	start_chain_resolution()

func start_chain_resolution() -> void:
	GameLogger.debug("start_chain_resolution called, chain_graph size: " + str(GameState.chain_graph.size()))
	if GameState.chain_graph.is_empty():
		game_manager.end_chain_resolution()
		return
	GameState.current_resolve_pos = GameState.last_cell_pos
	_set_active_cell(GameState.current_resolve_pos)
	GameState.came_from_edge = -1
	GameState.waiting_for_player = false
	var gear = board_manager.get_gear_at(GameState.current_resolve_pos)
	if gear:
		GameState.active_player_id = gear.owner_id
		EventBus.player_changed.emit(GameState.active_player_id)
	resolve_current_gear()

func resolve_current_gear() -> void:
	_set_active_cell(GameState.current_resolve_pos)
	GameLogger.debug("resolve_current_gear called, pos: " + Game.pos_to_chess(GameState.current_resolve_pos))
	if GameState.current_resolve_pos == Vector2i(-1, -1):
		game_manager.end_chain_resolution()
		return
	var gear = board_manager.get_gear_at(GameState.current_resolve_pos)
	if not gear:
		GameState.current_resolve_pos = get_next_cell()
		resolve_current_gear()
		return
	
	GameLogger.info("Resolving gear at %s" % Game.pos_to_chess(GameState.current_resolve_pos))
	EventBus.chain_resolution_step.emit(gear)
	
	var skip = GameState.effect_system.has_modifier(gear, "no_auto_tick")
	GameLogger.debug("Auto tick skip: %s, can_rotate: %s, ticks: %d/%d" % [skip, gear.can_rotate(), gear.current_ticks, gear.max_ticks])
	if not skip:
		if gear.can_rotate():
			gear.do_tick(1)
			game_manager.update_ui()
	else:
		GameLogger.debug("Auto tick prevented by Time Swarm")
	
	# Испускаем сигнал разрешения для текущей шестерни
	EventBus.gear_resolved.emit(gear)
	
	GameState.waiting_for_player = true
	GameLogger.debug("Waiting for player action for gear at %s" % Game.pos_to_chess(GameState.current_resolve_pos))

func get_next_cell() -> Vector2i:
	var edges = GameState.chain_graph.get_edges_from(GameState.current_resolve_pos).duplicate()
	if GameState.came_from_edge != -1:
		for neighbor in edges.keys():
			if edges[neighbor] == GameState.came_from_edge:
				edges.erase(neighbor)
				break
	if edges.is_empty():
		GameLogger.debug("No available edges from %s – end of chain" % Game.pos_to_chess(GameState.current_resolve_pos))
		return Vector2i(-1, -1)
	var max_edge = -1
	var next_pos = Vector2i(-1, -1)
	for neighbor in edges:
		var eid = edges[neighbor]
		if eid > max_edge:
			max_edge = eid
			next_pos = neighbor
	GameState.came_from_edge = max_edge
	GameLogger.debug("From %s going to %s via edge %d" % [Game.pos_to_chess(GameState.current_resolve_pos), Game.pos_to_chess(next_pos), max_edge])
	return next_pos

func proceed_to_next_cell() -> void:
	GameState.waiting_for_player = false
	var next_pos = get_next_cell()
	if next_pos == Vector2i(-1, -1):
		game_manager.end_chain_resolution()
		# Принудительно отменяем выбор цели, если он ещё активен
		game_manager.ui.cancel_target_selection()
	else:
		GameState.current_resolve_pos = next_pos
		var gear = board_manager.get_gear_at(GameState.current_resolve_pos)
		if gear:
			GameState.active_player_id = gear.owner_id
			EventBus.player_changed.emit(GameState.active_player_id)
		resolve_current_gear()

func restart_chain_resolution() -> void:
	GameLogger.info("Restarting chain resolution from last cell")
	GameState.waiting_for_player = false
	GameState.current_resolve_pos = GameState.last_cell_pos
	_set_active_cell(GameState.current_resolve_pos)
	GameState.came_from_edge = -1
	if GameState.current_resolve_pos == Vector2i(-1, -1):
		GameLogger.warning("No last cell to restart from")
		game_manager.end_chain_resolution()
		return
	var gear = board_manager.get_gear_at(GameState.current_resolve_pos)
	if gear:
		GameState.active_player_id = gear.owner_id
		EventBus.player_changed.emit(GameState.active_player_id)
	resolve_current_gear()

func handle_gear_clicked(gear: Gear) -> void:
	GameLogger.debug("ResolutionPhase handle_gear_clicked: " + gear.gear_name)
	if not GameState.waiting_for_player:
		GameLogger.debug("Not waiting for player, ignoring")
		return
	if gear != board_manager.get_gear_at(GameState.current_resolve_pos):
		GameLogger.debug("Gear mismatch: clicked gear not at current resolve pos")
		return
	
	var cmd = ExtraTickCommand.new(gear)
	if cmd.can_execute():
		cmd.execute()
	else:
		GameLogger.warning("Could not spend T on extra tick")

func handle_action_button() -> void:
	if GameState.waiting_for_player:
		var cmd = SkipCommand.new()
		if cmd.can_execute():
			cmd.execute()

func _set_active_cell(pos: Vector2i) -> void:
	game_manager.set_active_cell(pos)
