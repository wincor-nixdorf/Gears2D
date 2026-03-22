# draw_phase.gd
class_name DrawPhase
extends Phase

func enter() -> void:
	GameLogger.debug("DrawPhase: enter")
	
	# Активный игрок берёт одну карту
	var player = game_manager.players[game_state.active_player_id]
	player.draw_card()
	
	# После взятия карты переходим к построению цепочки
	game_manager.phase_machine.call_deferred("change_phase", Game.GamePhase.CHAIN_BUILDING)

func exit() -> void:
	GameLogger.debug("DrawPhase: exit")
	super()

# В фазе Draw взаимодействие с игрой не требуется
func handle_cell_clicked(cell: Cell) -> void:
	pass

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	pass

func handle_player_clicked(player: Player) -> void:
	pass

func handle_action_button() -> void:
	pass
