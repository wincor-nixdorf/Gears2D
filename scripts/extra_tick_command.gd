# extra_tick_command.gd
class_name ExtraTickCommand
extends GameCommand

var gear: Gear

func _init(p_gear: Gear, gm: GameManager, gs: GameState) -> void:
	super(gm, gs)
	gear = p_gear

func can_execute() -> bool:
	if not game_manager.stack_manager.is_stack_empty():
		return false
	if game_state.current_phase != Game.GamePhase.CHAIN_RESOLUTION:
		return false
	if not game_state.waiting_for_player:
		return false
	if not gear.is_owned_by(game_state.active_player_id):
		return false
	if not gear.can_rotate():
		return false
	if game_state.t_pool[game_state.active_player_id] <= 0:
		return false
	return true

func execute() -> void:
	var success = await gear.do_tick(1)
	if success:
		game_state.t_pool[game_state.active_player_id] -= 1
		EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
		GameLogger.info("Spent 1 T on extra tick")
