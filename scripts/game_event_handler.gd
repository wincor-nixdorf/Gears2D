# game_event_handler.gd
class_name GameEventHandler
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var ui: UI
var phase_machine: PhaseMachine

func _init(gm: GameManager, gs: GameState, ui_node: UI, pm: PhaseMachine) -> void:
	game_manager = gm
	game_state = gs
	ui = ui_node
	phase_machine = pm

# Подключается к сигналам Gear, Cell, Player, UI
func _on_gear_clicked(gear: Gear, button_index: int) -> void:
	GameLogger.debug("GameEventHandler._on_gear_clicked: %s, button=%d" % [gear.gear_name, button_index])
	
	# Если активен выбор цели – обрабатываем только его
	if ui.is_target_selection_active():
		if ui.is_valid_target(gear):
			EventBus.target_selected.emit(gear)
		return
	
	# Если стек не пуст – блокируем действие
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("Cannot interact while stack is not empty")
		return
	
	phase_machine.handle_gear_clicked(gear, button_index)

func _on_gear_mouse_entered(gear: Gear) -> void:
	if gear.is_owned_by(game_state.active_player_id):
		ui.show_gear_tooltip(gear, game_manager.get_viewport().get_mouse_position())

func _on_gear_mouse_exited(_gear: Gear) -> void:
	ui.hide_gear_tooltip()

func _on_gear_rotated(gear: Gear, old_ticks: int, new_ticks: int) -> void:
	EventBus.gear_rotated.emit(gear, old_ticks, new_ticks)
	# UI обновится через событие gear_rotated

# Обработчик _on_gear_triggered удалён, так как триггерные способности
# добавляются в стек непосредственно в gear.gd.

func _on_gear_destroyed(gear: Gear) -> void:
	var cell = gear.get_parent() as Cell
	if cell:
		game_manager.board_manager.clear_gear(cell.board_pos)
		game_state.chain_graph.remove_vertex(cell.board_pos)
	
	game_state.effect_system.remove_modifiers_from_target(gear)
	game_manager.unregister_gear_effects(gear)
	
	EventBus.gear_destroyed.emit(gear)
	EventBus.chain_built.emit(game_state.chain_graph.to_dict())
	
	if game_state.current_phase == Game.GamePhase.CHAIN_BUILDING and cell and cell.board_pos == game_state.last_cell_pos:
		GameLogger.debug("Last gear in chain destroyed. Ending chain building phase.")
		game_manager.end_chain_building()
	else:
		game_manager._check_state_based_actions()

func _on_hand_gear_selected(gear: Gear) -> void:
	GameLogger.debug("GameEventHandler._on_hand_gear_selected: %s" % gear.gear_name)
	
	# Проверка на пустой стек
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("Cannot select gear from hand while stack is not empty")
		return
	
	if game_state.selected_gear:
		ui.unhighlight_gear(game_state.selected_gear)
	game_state.selected_gear = gear
	ui.highlight_gear(gear)
	GameLogger.debug("Gear selected from hand")

func _on_cell_clicked(cell: Cell) -> void:
	GameLogger.debug("GameEventHandler._on_cell_clicked: cell %s" % Game.pos_to_chess(cell.board_pos))
	
	if ui.is_target_selection_active():
		var target = cell.occupied_gear if cell.occupied_gear else cell
		if ui.is_valid_target(target):
			EventBus.target_selected.emit(target)
		return
	
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("Cannot interact while stack is not empty")
		return
	
	phase_machine.handle_cell_clicked(cell)

func _on_player_icon_clicked(player_id: int) -> void:
	var player = game_manager.players[player_id]
	GameLogger.debug("GameEventHandler._on_player_icon_clicked: player %d" % player_id)
	
	if ui.is_target_selection_active():
		if ui.is_valid_target(player):
			EventBus.target_selected.emit(player)
		return
	
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("Cannot interact while stack is not empty")
		return
	
	phase_machine.handle_player_clicked(player)

func _on_action_button_pressed() -> void:
	GameLogger.debug("GameEventHandler._on_action_button_pressed")
	
	# Если стек не пуст – блокируем нажатие кнопки действия
	if not game_manager.stack_manager.is_stack_empty():
		GameLogger.debug("Cannot press action button while stack is not empty")
		return
	
	phase_machine.handle_action_button()
