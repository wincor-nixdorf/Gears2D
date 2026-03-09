# renewal_phase.gd
class_name RenewalPhase
extends Phase

func enter() -> void:
	GameLogger.debug("RenewalPhase: enter")
	game_manager.update_ui()

func handle_action_button() -> void:
	# В этой фазе кнопка действия не используется
	pass
