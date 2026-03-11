# take_t_command.gd
class_name TakeTCommand
extends GameCommand

var gear: Gear
var amount: int

func _init(p_gear: Gear, p_amount: int = 1, gm: GameManager = null, gs: GameState = null):
	super(gm, gs)
	gear = p_gear
	amount = p_amount

func can_execute() -> bool:
	if not gear or not gear.can_rotate():
		return false
	if not gear.is_owned_by(game_state.active_player_id):
		return false
	var cell = gear.get_parent() as Cell
	if not cell or not game_state.chain_graph.has_vertex(cell.board_pos):
		return false
	return true

func execute() -> void:
	print("TakeTCommand: about to call do_tock on ", gear.gear_name)
	var success = await gear.do_tock(amount)
	print("TakeTCommand: do_tock finished, success=", success)
	if success:
		game_state.t_pool[game_state.active_player_id] += amount
		EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
		GameLogger.info("Taken %d T from gear. Total T%d: %d" % [amount, game_state.active_player_id, game_state.t_pool[game_state.active_player_id]])
