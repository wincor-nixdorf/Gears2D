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
func _on_gear_clicked(gear: Gear) -> void:
	GameLogger.debug("GameEventHandler._on_gear_clicked: %s" % gear.gear_name)
	if ui.is_target_selection_active():
		if ui.is_valid_target(gear):
			EventBus.target_selected.emit(gear)
		return
	phase_machine.handle_gear_clicked(gear)

func _on_gear_mouse_entered(gear: Gear) -> void:
	if gear.is_owned_by(game_state.active_player_id):
		ui.show_gear_tooltip(gear, game_manager.get_viewport().get_mouse_position())

func _on_gear_mouse_exited(_gear: Gear) -> void:
	ui.hide_gear_tooltip()

func _on_gear_rotated(gear: Gear, old_ticks: int, new_ticks: int) -> void:
	EventBus.gear_rotated.emit(gear, old_ticks, new_ticks)
	# UI обновится через событие gear_rotated

func _on_gear_triggered(gear: Gear) -> void:
	for ability in gear.abilities:
		if ability.ability_type == GameEnums.AbilityType.STATIC:
			if not game_manager.is_ability_used_on_gear(gear, ability.ability_id):
				game_manager.register_static_effect(gear, ability)
				game_manager.mark_ability_used_on_gear(gear, ability.ability_id)
	
	EventBus.gear_triggered.emit(gear)
	# UI обновится через событие gear_triggered

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
	phase_machine.handle_cell_clicked(cell)

func _on_player_icon_clicked(player_id: int) -> void:
	var player = game_manager.players[player_id]
	GameLogger.debug("GameEventHandler._on_player_icon_clicked: player %d" % player_id)
	if ui.is_target_selection_active():
		if ui.is_valid_target(player):
			EventBus.target_selected.emit(player)
		return
	phase_machine.handle_player_clicked(player)

func _on_action_button_pressed() -> void:
	phase_machine.handle_action_button()
