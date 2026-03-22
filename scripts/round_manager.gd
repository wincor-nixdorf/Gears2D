# round_manager.gd
class_name RoundManager
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var board_manager: BoardManager
var phase_machine: PhaseMachine
var ui: UI

var _round_start_time: float = 0.0
var _round_end_time: float = 0.0

func _init(gm: GameManager, gs: GameState) -> void:
	game_manager = gm
	game_state = gs
	board_manager = gm.board_manager
	phase_machine = gm.phase_machine
	ui = gm.ui  # Сохраняем ссылку на UI

func start_round(skip_beginning: bool = false) -> void:
	_round_start_time = Time.get_ticks_msec() / 1000.0
	GameLogger.debug("RoundManager: start_round called (skip_beginning=%s)" % skip_beginning)
	
	game_manager.set_active_cell(Vector2i(-1, -1))
	game_manager.clear_used_abilities()
	game_state.start_player_id = game_state.active_player_id
	
	# Начинаем новый раунд в истории
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.start_new_round(game_state.round_number, game_state.start_player_id)
		GameLogger.debug("RoundManager: started new round %d in history" % game_state.round_number)
	
	# Очищаем граф цепочки
	game_state.chain_graph.clear()
	game_state.chain_order.clear()
	
	# Сбрасываем визуальные элементы цепочки
	board_manager.clear_chain_visuals()
	
	game_state.last_cell_pos = Vector2i(-1, -1)
	game_state.last_from_pos = Vector2i(-1, -1)
	game_state.passed = false
	game_state.has_placed_this_turn = false
	game_state.moves_in_round = 0
	game_state.selected_gear = null
	game_state.selected_creature = null
	game_state.consecutive_passes = 0
	
	if ui:
		ui.clear_selection()
	
	# Записываем начало раунда в историю
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Round %d started. Starter: Player %d" % [game_state.round_number, game_state.start_player_id + 1],
			game_state.start_player_id,
			{"round": game_state.round_number, "starter": game_state.start_player_id + 1}
		)
	
	if skip_beginning:
		phase_machine.call_deferred("change_phase", Game.GamePhase.CHAIN_BUILDING)
	else:
		phase_machine.call_deferred("change_phase", Game.GamePhase.UPKEEP)

# Вызывается после завершения фазы разрешения цепочки
func end_chain_resolution() -> void:
	_round_end_time = Time.get_ticks_msec() / 1000.0
	var round_duration = _round_end_time - _round_start_time
	
	game_manager.set_active_cell(Vector2i(-1, -1))
	
	# Записываем завершение раунда в историю
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"Round %d completed. Duration: %.2f seconds" % [game_state.round_number, round_duration],
			-1,
			{"round": game_state.round_number, "duration": round_duration}
		)
	
	# Переходим в фазу END
	phase_machine.call_deferred("change_phase", Game.GamePhase.END)
	GameLogger.info("Chain resolution phase ended. Starting end phase.")

func end_game(winner_id: int) -> void:
	var winner_name = "Player %d" % (winner_id + 1)
	GameLogger.info("%s wins!" % winner_name)
	
	# Записываем победу в историю
	if game_manager.turn_history_manager:
		game_manager.turn_history_manager.add_action(
			"GAME ENDED - %s wins!" % winner_name,
			winner_id,
			{"winner": winner_id + 1}
		)
	
	if game_manager.get_tree():
		game_manager.get_tree().paused = true
	
	# Показываем диалог победы
	_show_winner_dialog(winner_id)

func _show_winner_dialog(winner_id: int) -> void:
	if not ui:
		return
		
	var dialog = AcceptDialog.new()
	dialog.title = "Game Over"
	dialog.dialog_text = "Player %d wins the game!" % (winner_id + 1)
	dialog.popup_centered()
	ui.add_child(dialog)
	
	var new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.pressed.connect(_restart_game)
	dialog.add_child(new_game_button)

func _restart_game() -> void:
	if game_manager.get_tree():
		game_manager.get_tree().paused = false
	game_manager.initialize_game()
