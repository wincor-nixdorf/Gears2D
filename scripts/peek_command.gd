# peek_command.gd
class_name PeekCommand
extends GameCommand

var gear: Gear

func _init(p_gear: Gear):
	gear = p_gear

func can_execute() -> bool:
	if GameState.current_phase != Game.GamePhase.UPTURN:
		return false
	if gear.is_owned_by(GameState.active_player_id) or gear.is_face_up:
		return false
	if GameState.t_pool[GameState.active_player_id] <= 0:
		return false
	return true

func execute() -> void:
	GameState.t_pool[GameState.active_player_id] -= 1
	EventBus.t_pool_updated.emit(GameState.t_pool[0], GameState.t_pool[1])
	gear.show_obverse_temporarily()
	GameManager.ref.update_ui()
	GameLogger.info("Spent T to peek. Remaining T%d: %d" % [GameState.active_player_id, GameState.t_pool[GameState.active_player_id]])
