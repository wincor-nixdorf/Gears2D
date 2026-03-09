# extra_tick_command.gd
class_name ExtraTickCommand
extends GameCommand

var gear: Gear

func _init(p_gear: Gear):
	gear = p_gear

func can_execute() -> bool:
	if GameState.current_phase != Game.GamePhase.CHAIN_RESOLUTION:
		return false
	if not GameState.waiting_for_player:
		return false
	if not gear.is_owned_by(GameState.active_player_id):
		return false
	if not gear.can_rotate():
		return false
	if GameState.t_pool[GameState.active_player_id] <= 0:
		return false
	return true

func execute() -> void:
	var success = gear.do_tick(1)
	if success:
		GameState.t_pool[GameState.active_player_id] -= 1
		EventBus.t_pool_updated.emit(GameState.t_pool[0], GameState.t_pool[1])
		GameManager.ref.update_ui()
		GameLogger.info("Spent 1 T on extra tick")
