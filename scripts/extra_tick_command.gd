# extra_tick_command.gd
class_name ExtraTickCommand
extends GameCommand

var gear: Gear

func _init(p_gear: Gear, gm: GameManager, gs: GameState):
	super(gm, gs)
	gear = p_gear

func can_execute() -> bool:
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
	print("ExtraTickCommand: about to call do_tick on ", gear.gear_name)
	var success = await gear.do_tick(1)
	print("ExtraTickCommand: do_tick finished, success=", success)
	if success:
		game_state.t_pool[game_state.active_player_id] -= 1
		EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
		game_manager.update_ui()
		GameLogger.info("Spent 1 T on extra tick")
