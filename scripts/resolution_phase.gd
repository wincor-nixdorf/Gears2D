# resolution_phase.gd
class_name ResolutionPhase
extends Phase

enum ResolveStep {
	BEFORE,
	RESOLVE,
	AFTER
}

enum InterruptState {
	NONE,
	WAITING_FOR_INTERRUPT,
	INTERRUPT_PLAYED
}

var _current_resolve_step: ResolveStep = ResolveStep.BEFORE
var _current_gear: Gear = null
var _resolve_queue: Array[Vector2i] = []
var _current_index: int = 0
var _is_waiting_for_priority: bool = false
var _interrupt_state: InterruptState = InterruptState.NONE
var _interrupt_player: int = -1
var _interrupt_gear: Gear = null
var _interrupt_pos: Vector2i = Vector2i(-1, -1)
var _priority_cycle_completed: bool = false
var _is_restarting_resolution: bool = false

func enter() -> void:
	GameLogger.debug("ResolutionPhase: enter")
	EventBus.stack_resolved.connect(_on_stack_resolved)
	EventBus.target_selection_cancelled.connect(_on_target_selection_cancelled)
	start_chain_resolution()

func exit() -> void:
	EventBus.stack_resolved.disconnect(_on_stack_resolved)
	EventBus.target_selection_cancelled.disconnect(_on_target_selection_cancelled)
	_is_waiting_for_priority = false
	_interrupt_state = InterruptState.NONE
	_priority_cycle_completed = false
	_is_restarting_resolution = false
	super()

func start_chain_resolution() -> void:
	GameLogger.debug("start_chain_resolution called, chain_order size: " + str(game_state.chain_order.size()))
	
	if game_state.chain_order.is_empty():
		game_manager.end_chain_resolution()
		return
	
	_resolve_queue = game_state.chain_order.duplicate()
	_resolve_queue.reverse()
	_current_index = 0
	
	if game_manager.turn_history_manager:
		var order_str = ""
		for pos in _resolve_queue:
			if order_str != "":
				order_str += " -> "
			order_str += Game.pos_to_chess(pos)
		game_manager.turn_history_manager.add_action(
			"Chain resolution started. Order: %s" % order_str,
			-1
		)
	
	_resolve_next()

func _resolve_next() -> void:
	if _current_index >= _resolve_queue.size():
		GameLogger.debug("ResolutionPhase: all gears resolved")
		game_manager.end_chain_resolution()
		return
	
	game_state.current_resolve_pos = _resolve_queue[_current_index]
	_set_active_cell(game_state.current_resolve_pos)
	game_state.came_from_edge = -1
	
	_current_gear = board_manager.get_gear_at(game_state.current_resolve_pos)
	
	if not _current_gear:
		GameLogger.debug("ResolutionPhase: gear at %s no longer exists, skipping" % Game.pos_to_chess(game_state.current_resolve_pos))
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Skipping destroyed gear at %s" % Game.pos_to_chess(game_state.current_resolve_pos),
				-1
			)
		_current_index += 1
		_resolve_next()
		return
	
	GameLogger.debug("ResolutionPhase: resolving gear %s at %s (face_up=%s, type=%s)" % [
		_current_gear.gear_name,
		Game.pos_to_chess(game_state.current_resolve_pos),
		_current_gear.is_face_up,
		_current_gear.type
	])
	
	game_state.active_player_id = _current_gear.owner_id
	EventBus.player_changed.emit(game_state.active_player_id)
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Resolving gear at %s (Player %d)" % [Game.pos_to_chess(game_state.current_resolve_pos), game_state.active_player_id + 1],
			game_state.active_player_id,
			{"gear": _current_gear.gear_name, "position": Game.pos_to_chess(game_state.current_resolve_pos)}
		)
	
	_current_resolve_step = ResolveStep.BEFORE
	_start_before_resolve()

func _start_before_resolve() -> void:
	if not _current_gear or not is_instance_valid(_current_gear):
		GameLogger.debug("ResolutionPhase: gear no longer exists, skipping BEFORE RESOLVE")
		proceed_to_next_cell()
		return
	
	GameLogger.debug("ResolutionPhase: BEFORE RESOLVE step for gear at %s" % Game.pos_to_chess(game_state.current_resolve_pos))
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_step(
			"Before Resolve: %s at %s" % [_current_gear.gear_name if _current_gear else "None", Game.pos_to_chess(game_state.current_resolve_pos)],
			game_state.active_player_id
		)
	
	var context = {"gear": _current_gear, "position": game_state.current_resolve_pos}
	game_state.effect_system.process_delayed_effects(GameEnums.TriggerCondition.ON_PHASE_START, context)
	
	_priority_cycle_completed = false
	await _run_priority_cycle("Before Resolve")
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.end_step()
	
	if not _current_gear or not is_instance_valid(_current_gear):
		GameLogger.debug("ResolutionPhase: gear destroyed during priority cycle, skipping RESOLVE")
		proceed_to_next_cell()
		return
	
	GameLogger.debug("ResolutionPhase: BEFORE RESOLVE completed for %s, moving to RESOLVE" % _current_gear.gear_name)
	
	_current_resolve_step = ResolveStep.RESOLVE
	_start_resolve()

func _start_resolve() -> void:
	if not _current_gear or not is_instance_valid(_current_gear):
		GameLogger.debug("ResolutionPhase: gear no longer exists, skipping RESOLVE")
		_current_resolve_step = ResolveStep.AFTER
		_start_after_resolve()
		return
	
	GameLogger.debug("ResolutionPhase: RESOLVE step for gear at %s (face_up=%s, type=%s, current_ticks=%d, max_ticks=%d)" % [
		Game.pos_to_chess(game_state.current_resolve_pos),
		_current_gear.is_face_up,
		_current_gear.type,
		_current_gear.current_ticks,
		_current_gear.max_ticks
	])
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_step(
			"Resolve: %s at %s" % [_current_gear.gear_name if _current_gear else "None", Game.pos_to_chess(game_state.current_resolve_pos)],
			game_state.active_player_id
		)
	
	if _current_gear and not _current_gear.is_face_up:
		var skip = game_state.effect_system.has_modifier(_current_gear, "no_auto_tick")
		if skip:
			GameLogger.debug("Auto-tick prevented by Time Swarm")
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action("Auto-tick prevented by Time Swarm", -1)
		else:
			await _current_gear.do_tick(1)
			GameLogger.debug("Auto-tick performed on gear at %s" % Game.pos_to_chess(game_state.current_resolve_pos))
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action(
					"Auto-tick on %s at %s" % [_current_gear.gear_name, Game.pos_to_chess(game_state.current_resolve_pos)],
					-1,
					{"gear": _current_gear.gear_name, "position": Game.pos_to_chess(game_state.current_resolve_pos), "new_ticks": _current_gear.current_ticks}
				)
		
		if not _current_gear or not is_instance_valid(_current_gear):
			GameLogger.debug("ResolutionPhase: gear destroyed during auto-tick, skipping")
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.end_step()
			_current_resolve_step = ResolveStep.AFTER
			_start_after_resolve()
			return
	
	var was_face_up_before = _current_gear.is_face_up if _current_gear else false
	var should_flip = _current_gear and not _current_gear.is_face_up and _current_gear.current_ticks >= _current_gear.max_ticks
	
	if should_flip:
		GameLogger.debug("ResolutionPhase: %s reached max_ticks, flipping" % _current_gear.gear_name)
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"%s reached max_ticks, flipping" % _current_gear.gear_name,
				_current_gear.owner_id,
				{"gear": _current_gear.gear_name, "position": Game.pos_to_chess(game_state.current_resolve_pos)}
			)
		_current_gear.flip()
		EventBus.gear_resolved.emit(_current_gear, was_face_up_before)
	
	if _current_gear and _current_gear.is_face_up:
		var has_trigger = false
		for slot in _current_gear.ability_slots:
			if slot.type == GameEnums.AbilityType.TRIGGERED and slot.trigger == GameEnums.TriggerCondition.ON_TRIGGER:
				has_trigger = true
				break
		
		if has_trigger:
			GameLogger.debug("ResolutionPhase: %s is face-up, adding triggered abilities to stack" % _current_gear.gear_name)
			if game_manager.turn_history_manager:
				game_manager.turn_history_manager.add_action(
					"%s triggered (already face-up)" % _current_gear.gear_name,
					_current_gear.owner_id,
					{"gear": _current_gear.gear_name, "position": Game.pos_to_chess(game_state.current_resolve_pos)}
				)
			
			_current_gear.push_triggered_abilities_to_stack()
			
			await _wait_for_target_selection_complete()
			
			EventBus.gear_resolved.emit(_current_gear, was_face_up_before)
	
	await _handle_stack_and_interrupts()
	
	if _interrupt_state == InterruptState.INTERRUPT_PLAYED:
		GameLogger.debug("ResolutionPhase: interrupt was played, will restart resolution from _resolve_next")
		_interrupt_state = InterruptState.NONE
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.end_step()
		
		_current_index = 0
		_resolve_next()
		return
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.end_step()
	
	_current_resolve_step = ResolveStep.AFTER
	_start_after_resolve()

func _wait_for_target_selection_complete() -> void:
	while game_manager.ui.is_target_selection_active():
		await _wait_for_next_frame()
	GameLogger.debug("_wait_for_target_selection_complete: all targets selected")

func _start_after_resolve() -> void:
	var gear_name = _current_gear.gear_name if _current_gear and is_instance_valid(_current_gear) else "Destroyed Gear"
	
	GameLogger.debug("ResolutionPhase: AFTER RESOLVE step for gear at %s (%s)" % [Game.pos_to_chess(game_state.current_resolve_pos), gear_name])
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_step(
			"After Resolve: %s at %s" % [gear_name, Game.pos_to_chess(game_state.current_resolve_pos)],
			game_state.active_player_id
		)
	
	var context = {"gear": _current_gear, "position": game_state.current_resolve_pos}
	game_state.effect_system.process_delayed_effects(GameEnums.TriggerCondition.ON_PHASE_END, context)
	
	_priority_cycle_completed = false
	await _run_priority_cycle("After Resolve")
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.end_step()
	
	proceed_to_next_cell()

func _handle_stack_and_interrupts() -> void:
	var stack_empty = game_manager.stack_manager.is_stack_empty()
	
	while true:
		if not stack_empty:
			if game_manager.ui.is_target_selection_active():
				GameLogger.debug("_handle_stack_and_interrupts: target selection active, waiting...")
				await _wait_for_target_selection()
				stack_empty = game_manager.stack_manager.is_stack_empty()
				continue
			
			if game_manager.stack_manager.has_pending_target():
				GameLogger.debug("_handle_stack_and_interrupts: pending target selection, waiting...")
				await _wait_for_target_selection()
				stack_empty = game_manager.stack_manager.is_stack_empty()
				continue
			
			await _run_interrupt_window_before_resolve()
			
			if _interrupt_state == InterruptState.INTERRUPT_PLAYED:
				GameLogger.info("Interrupt played before resolving stack entry, restarting resolution")
				
				if game_manager.turn_history_manager:
					game_manager.turn_history_manager.add_action(
						"Interrupt played before resolve, restarting resolution with new chain order",
						_interrupt_player
					)
				
				_resolve_queue.insert(0, _interrupt_pos)
				_current_index = 0
				
				game_state.current_resolve_pos = _interrupt_pos
				_current_gear = board_manager.get_gear_at(_interrupt_pos)
				game_state.active_player_id = _current_gear.owner_id
				EventBus.player_changed.emit(game_state.active_player_id)
				
				game_manager.stack_manager.clear_stack()
				
				return
			
			GameLogger.debug("_handle_stack_and_interrupts: resolving next stack entry")
			game_manager.stack_manager.resolve_next()
			
			await _wait_for_stack_or_interrupt()
			
			stack_empty = game_manager.stack_manager.is_stack_empty()
			GameLogger.debug("_handle_stack_and_interrupts: stack empty after resolve = %s" % stack_empty)
		else:
			GameLogger.debug("_handle_stack_and_interrupts: stack empty, exiting")
			break

func _wait_for_target_selection() -> void:
	_is_waiting_for_priority = true
	while _is_waiting_for_priority:
		await _wait_for_next_frame()
		if not game_manager.ui.is_target_selection_active():
			_is_waiting_for_priority = false
			break
		if game_manager.stack_manager.is_stack_empty():
			_is_waiting_for_priority = false
			break
		if not game_manager.stack_manager.has_pending_target():
			_is_waiting_for_priority = false
			break
	GameLogger.debug("_wait_for_target_selection: finished")

func _run_interrupt_window_before_resolve() -> void:
	if not _current_gear:
		GameLogger.debug("_run_interrupt_window_before_resolve: no current gear, skipping")
		return
	
	var current_gear_owner = _current_gear.owner_id
	var active_player = game_state.active_player_id
	var eligible_player = -1
	
	if current_gear_owner == active_player:
		eligible_player = 1 - active_player
	else:
		eligible_player = active_player
	
	var has_interrupt = false
	var player_hand = game_manager.players[eligible_player].hand
	for gear in player_hand:
		if gear.type == GameEnums.GearType.INTERRUPT:
			has_interrupt = true
			break
	
	if not has_interrupt:
		GameLogger.debug("_run_interrupt_window_before_resolve: player %d has no interrupt in hand, skipping" % (eligible_player + 1))
		return
	
	GameLogger.debug("_run_interrupt_window_before_resolve: opening interrupt window for player %d" % (eligible_player + 1))
	
	game_state.waiting_for_player = true
	game_state.priority_player = eligible_player
	game_manager.update_ui()
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Priority to Player %d (Interrupt Window)" % (eligible_player + 1),
			eligible_player
		)
	
	await _wait_for_interrupt_or_pass(eligible_player)
	
	game_state.waiting_for_player = false
	game_state.priority_player = -1
	
	if _interrupt_state == InterruptState.INTERRUPT_PLAYED:
		GameLogger.debug("_run_interrupt_window_before_resolve: interrupt played")
		return
	
	GameLogger.debug("_run_interrupt_window_before_resolve: player passed, continuing")

func _wait_for_interrupt_or_pass(player_id: int) -> void:
	_is_waiting_for_priority = true
	while _is_waiting_for_priority:
		await _wait_for_next_frame()
		
		if not game_state.waiting_for_player:
			_is_waiting_for_priority = false
			break
		if _interrupt_state == InterruptState.INTERRUPT_PLAYED:
			_is_waiting_for_priority = false
			break
		if game_state.selected_interrupt_gear:
			pass

func _run_priority_cycle(step_name: String) -> void:
	var players_passed = 0
	var current_player = game_state.active_player_id
	
	GameLogger.debug("_run_priority_cycle: starting %s with current_player=%d" % [step_name, current_player])
	
	while players_passed < 2:
		if game_manager.ui.is_target_selection_active():
			GameLogger.debug("_run_priority_cycle: target selection appeared, breaking")
			game_state.waiting_for_player = false
			game_state.priority_player = -1
			return
		
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
		
		GameLogger.debug("_run_priority_cycle: player %d passed, players_passed=%d" % [current_player, players_passed])
		
		if players_passed < 2:
			current_player = 1 - current_player
			await _wait_for_next_frame()
			await _wait_for_next_frame()
	
	game_state.waiting_for_player = false
	game_state.priority_player = -1
	GameLogger.debug("_run_priority_cycle: completed %s" % step_name)

func _wait_for_player_pass() -> void:
	_is_waiting_for_priority = true
	while _is_waiting_for_priority:
		await _wait_for_next_frame()
		
		if not game_state.waiting_for_player:
			GameLogger.debug("_wait_for_player_pass: waiting_for_player became false")
			_is_waiting_for_priority = false
			break
		if game_manager.ui.is_target_selection_active():
			GameLogger.debug("_wait_for_player_pass: target selection active")
			_is_waiting_for_priority = false
			break

func _wait_for_stack_or_interrupt() -> void:
	_is_waiting_for_priority = true
	while _is_waiting_for_priority:
		await _wait_for_next_frame()
		
		if game_manager.stack_manager.is_stack_empty():
			_is_waiting_for_priority = false
			break
		if _interrupt_state == InterruptState.INTERRUPT_PLAYED:
			_is_waiting_for_priority = false
			break
		if game_manager.ui.is_target_selection_active():
			_is_waiting_for_priority = false
			break
		if game_manager.stack_manager.has_pending_target():
			_is_waiting_for_priority = false
			break

func _wait_for_next_frame() -> void:
	await game_manager.get_tree().process_frame

func _on_stack_resolved() -> void:
	GameLogger.debug("ResolutionPhase: stack resolved")
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action("Stack resolved", -1)
	
	if game_state.waiting_for_player:
		game_state.waiting_for_player = false
		_priority_cycle_completed = true

func _on_target_selection_cancelled() -> void:
	GameLogger.debug("ResolutionPhase: target selection cancelled")
	if _is_waiting_for_priority:
		_is_waiting_for_priority = false
		_priority_cycle_completed = true

func proceed_to_next_cell() -> void:
	GameLogger.debug("ResolutionPhase: proceed_to_next_cell called")
	
	_current_index += 1
	
	if _current_index >= _resolve_queue.size():
		GameLogger.debug("ResolutionPhase: no next cell, calling game_manager.end_chain_resolution()")
		game_manager.end_chain_resolution()
		game_manager.ui.cancel_target_selection()
		_is_restarting_resolution = false
	else:
		_resolve_next()

func get_next_cell() -> Vector2i:
	if _current_index < _resolve_queue.size():
		return _resolve_queue[_current_index]
	return Vector2i(-1, -1)

func set_interrupt_played(gear: Gear, pos: Vector2i) -> void:
	_interrupt_state = InterruptState.INTERRUPT_PLAYED
	_interrupt_player = gear.owner_id
	_interrupt_gear = gear
	_interrupt_pos = pos

func restart_with_interrupt() -> void:
	GameLogger.debug("ResolutionPhase: restart_with_interrupt called")
	
	_resolve_queue.insert(0, game_state.interrupt_pos)
	_current_index = 0
	
	game_state.current_resolve_pos = game_state.interrupt_pos
	_current_gear = board_manager.get_gear_at(game_state.interrupt_pos)
	
	game_state.active_player_id = _current_gear.owner_id
	EventBus.player_changed.emit(game_state.active_player_id)
	
	game_state.interrupt_played = false
	
	_current_resolve_step = ResolveStep.BEFORE
	_start_before_resolve()

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_LEFT and game_state.waiting_for_player and game_state.priority_player == game_state.active_player_id:
		var cmd = TakeTCommand.new(gear, 1, game_manager, game_state)
		if cmd.can_execute():
			await cmd.execute()
			game_manager.update_ui()
			return
	
	if _current_resolve_step == ResolveStep.RESOLVE and game_state.waiting_for_player:
		if button_index == MOUSE_BUTTON_LEFT and gear == _current_gear:
			var cmd = ExtraTickCommand.new(gear, game_manager, game_state)
			if cmd.can_execute():
				await cmd.execute()
				if game_manager.turn_history_manager:
					game_manager.turn_history_manager.add_action(
						"Extra tick on %s (cost 1 T)" % gear.gear_name,
						game_state.active_player_id,
						{"gear": gear.gear_name, "position": Game.pos_to_chess(gear.board_position)}
					)
		elif button_index == MOUSE_BUTTON_RIGHT and gear == _current_gear:
			_activate_ability(gear)

func _can_play_interrupt(gear: Gear, target_cell: Cell) -> bool:
	if gear.type != GameEnums.GearType.INTERRUPT:
		return false
	
	if gear.zone != Gear.Zone.HAND:
		return false
	
	var cost = gear.get_interrupt_cost()
	if game_state.t_pool[gear.owner_id] < cost:
		GameLogger.debug("Not enough T for Interrupt (need %d, have %d)" % [cost, game_state.t_pool[gear.owner_id]])
		return false
	
	if not target_cell or not _current_gear:
		return false
	
	if _current_gear.owner_id == gear.owner_id:
		GameLogger.debug("Cannot play Interrupt in response to your own gear")
		return false
	
	var last_pos = game_state.current_resolve_pos
	if not game_manager.is_adjacent(last_pos, target_cell.board_pos):
		GameLogger.debug("Interrupt target cell not adjacent to current gear")
		return false
	
	var is_white = target_cell.is_white()
	if (gear.owner_id == 0 and not is_white) or (gear.owner_id == 1 and is_white):
		GameLogger.debug("Wrong cell color for Interrupt")
		return false
	
	if not target_cell.is_empty():
		GameLogger.debug("Target cell is not empty")
		return false
	
	return true

func _play_interrupt(gear: Gear, target_cell: Cell) -> bool:
	if not _can_play_interrupt(gear, target_cell):
		return false
	
	var cost = gear.get_interrupt_cost()
	game_state.t_pool[gear.owner_id] -= cost
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	var player = game_manager.players[gear.owner_id]
	player.remove_from_hand(gear)
	
	target_cell.set_occupied(gear)
	gear.set_cell_size(Game.CELL_SIZE, Game.CELL_INDENT)
	gear.board_position = target_cell.board_pos
	gear.zone = Gear.Zone.BOARD
	
	gear.is_face_up = true
	gear.revealed = true
	gear.update_texture()
	gear.sprite.rotation_degrees = 0
	
	gear._apply_static_effects()
	
	if game_manager.event_handler:
		gear.rotated.connect(game_manager.event_handler._on_gear_rotated)
		gear.destroyed.connect(game_manager.event_handler._on_gear_destroyed)
		gear.clicked.connect(game_manager.event_handler._on_gear_clicked)
		gear.mouse_entered.connect(game_manager.event_handler._on_gear_mouse_entered)
		gear.mouse_exited.connect(game_manager.event_handler._on_gear_mouse_exited)
	
	EventBus.gear_placed.emit(gear, target_cell)
	
	game_state.chain_graph.add_vertex(target_cell.board_pos)
	game_state.chain_order.append(target_cell.board_pos)
	
	_interrupt_state = InterruptState.INTERRUPT_PLAYED
	_interrupt_player = gear.owner_id
	_interrupt_gear = gear
	_interrupt_pos = target_cell.board_pos
	
	GameLogger.info("Interrupt %s played at %s (cost %d T) and is now ACTIVE" % [gear.gear_name, Game.pos_to_chess(target_cell.board_pos), cost])
	
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Interrupt: %s played at %s (cost %d T) - now ACTIVE" % [gear.gear_name, Game.pos_to_chess(target_cell.board_pos), cost],
			gear.owner_id
		)
	
	game_manager.stack_manager.clear_stack()
	
	return true

func handle_cell_clicked(cell: Cell) -> void:
	if _current_resolve_step == ResolveStep.RESOLVE and game_state.waiting_for_player:
		if game_state.selected_interrupt_gear:
			if _play_interrupt(game_state.selected_interrupt_gear, cell):
				game_state.selected_interrupt_gear = null
				game_manager.ui.clear_selection()
				game_state.waiting_for_player = false
				_priority_cycle_completed = true
			else:
				GameLogger.warning("Cannot play Interrupt at this cell")

func _activate_ability(gear: Gear) -> void:
	for slot in gear.ability_slots:
		if slot.type == GameEnums.AbilityType.ACTIVATED:
			if game_state.t_pool[gear.owner_id] >= slot.cost:
				game_state.t_pool[gear.owner_id] -= slot.cost
				EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
				game_manager.stack_manager.push_effect(slot.ability, gear, null, {"source_gear": gear})
				if game_manager.turn_history_manager:
					game_manager.turn_history_manager.add_action(
						"Activated %s on %s (cost %d T)" % [slot.ability.ability_name, gear.gear_name, slot.cost],
						gear.owner_id
					)
			return

func handle_action_button() -> void:
	GameLogger.debug("ResolutionPhase: action button pressed, step=%s, waiting=%s" % [_current_resolve_step, game_state.waiting_for_player])
	
	if _current_resolve_step == ResolveStep.RESOLVE and game_state.waiting_for_player:
		game_state.waiting_for_player = false
		game_state.priority_player = -1
		_priority_cycle_completed = true
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Skipped current gear at %s" % Game.pos_to_chess(game_state.current_resolve_pos),
				game_state.active_player_id
			)
		GameLogger.info("Skipped current gear, proceeding to next step")
	elif _current_resolve_step == ResolveStep.BEFORE or _current_resolve_step == ResolveStep.AFTER:
		if game_state.waiting_for_player:
			game_state.waiting_for_player = false
			game_state.priority_player = -1
			_priority_cycle_completed = true
			GameLogger.debug("Passed priority in %s step" % _current_resolve_step)

func _set_active_cell(pos: Vector2i) -> void:
	game_manager.set_active_cell(pos)
