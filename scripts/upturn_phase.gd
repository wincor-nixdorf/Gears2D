# upturn_phase.gd
class_name UpturnPhase
extends Phase

func enter() -> void:
	GameLogger.debug("UpturnPhase: enter")
	game_manager.update_ui()

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	# В фазе upturn левая кнопка используется для peek (подглядывания)
	# Правая кнопка может игнорироваться или использоваться для отмены
	if button_index != MOUSE_BUTTON_LEFT:
		return
	
	var cmd = PeekCommand.new(gear, game_manager, game_state)
	if cmd.can_execute():
		cmd.execute()
	else:
		if gear.is_owned_by(game_state.active_player_id):
			GameLogger.warning("Cannot peek at your own gear")
		elif gear.is_face_up:
			GameLogger.warning("Gear already flipped")
		else:
			GameLogger.warning("Not enough T to peek")

func handle_action_button() -> void:
	GameLogger.info("Ending upturn phase")
	game_manager.end_upturn()
