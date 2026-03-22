# swing_back_phase.gd
class_name SwingBackPhase
extends Phase

func enter() -> void:
	GameLogger.debug("SwingBackPhase: enter")
	game_manager.update_ui()

func exit() -> void:
	GameLogger.debug("SwingBackPhase: exit")
	super()

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	# Обработка снятия ресурса (Tapping) - доступно всегда, когда есть приоритет
	if button_index == MOUSE_BUTTON_LEFT and game_state.waiting_for_player and game_state.priority_player == game_state.active_player_id:
		var cmd = TakeTCommand.new(gear, 1, game_manager, game_state)
		if cmd.can_execute():
			await cmd.execute()
			game_manager.update_ui()
			return
	
	# Обычный просмотр вражеских Gear за T
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
	GameLogger.info("Ending swing back phase")
	game_manager.end_swing_back()

func handle_cell_clicked(cell: Cell) -> void:
	# В этой фазе клик по клетке игнорируется
	pass

func handle_player_clicked(player: Player) -> void:
	pass
