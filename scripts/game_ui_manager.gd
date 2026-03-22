# game_ui_manager.gd
class_name GameUIManager
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var ui: UI
var board_manager: BoardManager
var rule_validator: GameRuleValidator

var _update_pending: bool = false

func _init(gm: GameManager, gs: GameState, ui_node: UI, bm: BoardManager, rv: GameRuleValidator) -> void:
	game_manager = gm
	game_state = gs
	ui = ui_node
	board_manager = bm
	rule_validator = rv
	_subscribe_to_events()

func _subscribe_to_events() -> void:
	EventBus.phase_changed.connect(_request_update)
	EventBus.player_changed.connect(_request_update)
	EventBus.t_pool_updated.connect(_request_update)
	EventBus.hand_updated.connect(_request_update)
	EventBus.gear_placed.connect(_request_update)
	EventBus.gear_triggered.connect(_request_update)
	EventBus.gear_destroyed.connect(_request_update)
	EventBus.gear_rotated.connect(_request_update)
	EventBus.chain_built.connect(_request_update)
	EventBus.gear_resolved.connect(_request_update)

func _request_update(_arg1 = null, _arg2 = null, _arg3 = null, _arg4 = null) -> void:
	GameLogger.debug("GameUIManager: update requested, phase = %s" % game_state.current_phase)
	if _update_pending:
		return
	_update_pending = true
	call_deferred("_do_update")

func _do_update() -> void:
	_update_pending = false
	
	if game_manager.players.is_empty():
		return
	if ui.is_target_selection_active():
		return
	
	var start_time = Time.get_ticks_msec()
	
	var stack_empty = game_manager.stack_manager.is_stack_empty()
	
	ui.update_player(game_state.active_player_id)
	ui.update_phase(game_state.current_phase)
	ui.update_t_pool(game_state.t_pool[0], game_state.t_pool[1])
	ui.update_action_button(
		game_state.current_phase,
		game_state.has_placed_this_turn,
		game_state.active_player_id,
		rule_validator.can_pass(),
		stack_empty
	)
	ui.update_hands(
		game_manager.players[0].hand,
		game_manager.players[1].hand,
		game_state.active_player_id,
		stack_empty
	)
	ui.update_round(game_state.round_number)
	ui.update_chain_length(game_state.chain_graph.size())
	ui.update_prompt(get_prompt_text())
	ui.update_damage(game_manager.players[0].damage, game_manager.players[1].damage)
	highlight_available_cells()
	_highlight_tappable_gears()
	
	var elapsed = Time.get_ticks_msec() - start_time
	if elapsed > 30:
		GameLogger.debug("update_ui took %d ms" % elapsed)

func get_prompt_text() -> String:
	if ui.is_target_selection_active():
		return ""
	
	var player_num = game_state.active_player_id + 1
	
	# Добавляем информацию об активной клетке в фазе разрешения
	if game_state.current_phase == Game.GamePhase.CHAIN_RESOLUTION:
		if game_state.current_resolve_pos != Vector2i(-1, -1):
			var pos_text = Game.pos_to_chess(game_state.current_resolve_pos)
			var gear = board_manager.get_gear_at(game_state.current_resolve_pos)
			var gear_name = gear.gear_name if gear else "None"
			return "Resolving: %s at %s (Player %d)" % [gear_name, pos_text, player_num]
	
	match game_state.current_phase:
		Game.GamePhase.UPKEEP:
			return "Player %d: Upkeep phase..." % player_num
		Game.GamePhase.DRAW:
			return "Player %d: Drawing a card..." % player_num
		Game.GamePhase.CHAIN_BUILDING:
			if game_state.last_cell_pos == Vector2i(-1, -1):
				return "Player %d: Select a starting cell and a gear from hand" % player_num
			elif not game_state.has_placed_this_turn:
				if game_state.moves_in_round < 2:
					return "Player %d: You must make a move (continue the chain)" % player_num
				else:
					return "Player %d: You can make a move or press Pass" % player_num
			else:
				return "Player %d: Press Pass to end the chain building phase" % player_num
		Game.GamePhase.SWING_BACK:
			return "Player %d: Click on an opponent's gear to peek for 1 T or press End Swing Back" % player_num
		Game.GamePhase.CHAIN_RESOLUTION:
			if game_state.waiting_for_player:
				return "Player %d: Click on current gear for an extra tick for 1 T or press Skip" % player_num
			else:
				return "Resolving chain..."
		Game.GamePhase.END:
			return "End phase..."
		Game.GamePhase.CLEANUP:
			return "Cleanup..."
		_:
			return ""

func highlight_available_cells() -> void:
	board_manager.reset_highlights()
	
	if game_state.current_phase != Game.GamePhase.CHAIN_BUILDING:
		return
	
	var available = rule_validator.get_available_cells()
	for cell in available:
		cell.sprite.modulate = Color(0, 1, 1, 0.5)

func _highlight_tappable_gears() -> void:
	# Если нет приоритета у активного игрока, не подсвечиваем
	if not game_state.waiting_for_player or game_state.priority_player != game_state.active_player_id:
		return
	
	for gear in board_manager.get_all_gears():
		# Только свои шестерни
		if gear.owner_id != game_state.active_player_id:
			continue
		# Только спящие (лицом вниз)
		if gear.is_face_up:
			continue
		# Проверка возможности поворота
		if not gear.can_rotate():
			continue
		
		# НЕ подсвечиваем шестерни, которые находятся в текущей цепочке
		if game_state.chain_graph.has_vertex(gear.board_position):
			continue
		
		var cell = board_manager.get_cell(gear.board_position)
		if cell:
			# Если клетка уже подсвечена другим цветом (например, доступна для хода), не перезаписываем
			if cell.sprite.modulate != Color(0, 1, 1, 0.5):
				cell.sprite.modulate = Color.GREEN
