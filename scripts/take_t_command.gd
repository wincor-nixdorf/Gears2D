# take_t_command.gd
class_name TakeTCommand
extends GameCommand

var gear: Gear
var amount: int

func _init(p_gear: Gear, p_amount: int = 1, gm: GameManager = null, gs: GameState = null) -> void:
	super(gm, gs)
	gear = p_gear
	amount = p_amount

func can_execute() -> bool:
	# Проверка что стек пуст (приоритет у игрока)
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("TakeTCommand: stack not empty")
		return false
	
	# Проверка что есть приоритет у текущего игрока
	if game_state.priority_player != game_state.active_player_id:
		GameLogger.debug("TakeTCommand: not priority player")
		return false
	
	# Проверка что игрок ожидает действия
	if not game_state.waiting_for_player:
		GameLogger.debug("TakeTCommand: not waiting for player action")
		return false
	
	if not gear or not gear.can_rotate():
		GameLogger.debug("TakeTCommand: gear cannot rotate")
		return false
	
	if not gear.is_owned_by(game_state.active_player_id):
		GameLogger.debug("TakeTCommand: not owned by active player")
		return false
	
	var cell = gear.get_parent() as Cell
	if not cell:
		GameLogger.debug("TakeTCommand: gear not on board")
		return false
	
	# G должна быть лицом вниз
	if gear.is_face_up:
		GameLogger.debug("TakeTCommand: gear is face up")
		return false
	
	# НЕЛЬЗЯ брать T с шестерни, которая уже в текущей цепочке
	if game_state.chain_graph.has_vertex(cell.board_pos):
		GameLogger.debug("TakeTCommand: gear is in current chain at %s" % Game.pos_to_chess(cell.board_pos))
		return false
	
	return true

func execute() -> void:
	var success = await gear.do_tock(amount)
	if success:
		game_state.t_pool[game_state.active_player_id] += amount
		EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
		GameLogger.info("Taken %d T from gear %s at %s. Total T%d: %d" % [
			amount, gear.gear_name, Game.pos_to_chess(gear.board_position),
			game_state.active_player_id, game_state.t_pool[game_state.active_player_id]
		])
		
		if game_manager.turn_history_manager:
			game_manager.turn_history_manager.add_action(
				"Took %d T from %s at %s" % [amount, gear.gear_name, Game.pos_to_chess(gear.board_position)],
				game_state.active_player_id,
				{"gear": gear.gear_name, "position": Game.pos_to_chess(gear.board_position), "t_gained": amount}
			)
