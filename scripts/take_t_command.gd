# take_t_command.gd
class_name TakeTCommand
extends GameCommand

var gear: Gear
var amount: int = 1

func _init(p_gear: Gear, p_amount: int = 1):
	gear = p_gear
	amount = p_amount

func can_execute() -> bool:
	if not gear or not gear.can_rotate():
		return false
	if not gear.is_owned_by(GameState.active_player_id):
		return false
	var cell = gear.get_parent() as Cell
	if not cell or not GameState.chain_graph.has_vertex(cell.board_pos):
		return false
	return true

func execute() -> void:
	var success = gear.do_tock(amount)
	if success:
		GameState.t_pool[GameState.active_player_id] += amount
		EventBus.t_pool_updated.emit(GameState.t_pool[0], GameState.t_pool[1])
		GameLogger.info("Taken %d T from gear. Total T%d: %d" % [amount, GameState.active_player_id, GameState.t_pool[GameState.active_player_id]])
