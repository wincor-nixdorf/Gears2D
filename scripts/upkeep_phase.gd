# upkeep_phase.gd
class_name UpkeepPhase
extends Phase

func enter() -> void:
	GameLogger.debug("UpkeepPhase: enter")
	game_manager.update_ui()
	
	# Срабатывают триггеры "В начале вашего Upkeep..."
	# Здесь будет вызов триггеров
	
	# Переходим к фазе Draw после завершения
	game_manager.phase_machine.call_deferred("change_phase", Game.GamePhase.DRAW)

func exit() -> void:
	GameLogger.debug("UpkeepPhase: exit")
	super()

# В фазе Upkeep взаимодействие с игрой не требуется
func handle_cell_clicked(cell: Cell) -> void:
	pass

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	pass

func handle_player_clicked(player: Player) -> void:
	pass

func handle_action_button() -> void:
	# В этой фазе кнопка действия не используется
	pass
