# end_phase.gd
class_name EndPhase
extends Phase

func enter() -> void:
	GameLogger.debug("EndPhase: enter")
	game_manager.update_ui()
	
	# Срабатывают триггеры "В начале шага конца хода..."
	# Здесь будет вызов триггеров
	
	# Переходим к Cleanup после завершения (используем call_deferred)
	game_manager.phase_machine.call_deferred("change_phase", Game.GamePhase.CLEANUP)

func exit() -> void:
	GameLogger.debug("EndPhase: exit")
	super()

func handle_cell_clicked(cell: Cell) -> void:
	pass

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	pass

func handle_player_clicked(player: Player) -> void:
	pass

func handle_action_button() -> void:
	pass
