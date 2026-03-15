# renewal_phase.gd
class_name RenewalPhase
extends Phase

func enter() -> void:
	GameLogger.debug("RenewalPhase: enter")
	game_manager.update_ui()

# В фазе обновления клики по шестерням обычно не обрабатываются,
# но для соответствия сигнатуре оставляем заглушку
func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	pass

func handle_action_button() -> void:
	# В этой фазе кнопка действия не используется
	pass
