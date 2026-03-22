# game_manager.gd
class_name GameManager
extends Node

static var ref: GameManager = null

@onready var board: Node2D = $Board
@onready var ui: UI = $UI

var board_manager: BoardManager
var round_manager: RoundManager
var ability_dispatcher: AbilityDispatcher
var players: Array[Player] = []
var phase_machine: PhaseMachine
var game_state: GameState
var stack_manager: StackManager

var initializer: GameInitializer
var rule_validator: GameRuleValidator
var event_handler: GameEventHandler
var ui_manager: GameUIManager
var turn_history_manager: TurnHistoryManager

var _state_based_check_pending: bool = false

const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const GEAR_SCENE = preload("res://scenes/Gear.tscn")

func _ready() -> void:
	ref = self
	game_state = GameState.new()
	board_manager = BoardManager.new(board)
	phase_machine = PhaseMachine.new(self, game_state)
	round_manager = RoundManager.new(self, game_state)
	stack_manager = StackManager.new(self, game_state, EventBus)
	ability_dispatcher = AbilityDispatcher.new(self, game_state, EventBus)
	
	initializer = GameInitializer.new(self, board)
	rule_validator = GameRuleValidator.new(self, game_state, board_manager)
	event_handler = GameEventHandler.new(self, game_state, ui, phase_machine)
	
	turn_history_manager = TurnHistoryManager.new(self, game_state)
	
	ui_manager = GameUIManager.new(self, game_state, ui, board_manager, rule_validator)
	
	if ui:
		ui.set_game_manager(self)
		ui.stack_panel.set_stack_manager(stack_manager)
		ui.setup_turn_history(turn_history_manager)
		ui.interrupt_played.connect(_on_interrupt_played)
	
	EventBus.chain_built.connect(_on_chain_built)
	
	initialize_game()
	
	if ui:
		ui.action_pressed.connect(event_handler._on_action_button_pressed)
		ui.hand_gear_selected.connect(event_handler._on_hand_gear_selected)
	
	EventBus.player_icon_clicked.connect(event_handler._on_player_icon_clicked)
	GameLogger.info("GameManager ready")

func _on_chain_built(chain_dict: Dictionary) -> void:
	board_manager.update_chain_visuals(game_state.chain_graph, game_state.chain_order, game_state.current_phase)

func initialize_game() -> void:
	game_state.reset()
	initializer.initialize_game()
	round_manager.start_round(true)
	GameLogger.info("Game initialized")

func _on_interrupt_played(gear: Gear, cell: Cell) -> void:
	GameLogger.debug("GameManager: Interrupt played - %s at %s" % [gear.gear_name, Game.pos_to_chess(cell.board_pos)])
	
	if game_state.current_phase != Game.GamePhase.CHAIN_RESOLUTION:
		GameLogger.warning("Interrupt can only be played during resolution phase")
		return
	
	var cost = gear.get_interrupt_cost()
	if game_state.t_pool[gear.owner_id] < cost:
		GameLogger.warning("Not enough T for Interrupt")
		return
	
	if not cell.is_empty():
		GameLogger.warning("Target cell is not empty")
		return
	
	var current_pos = game_state.current_resolve_pos
	if not rule_validator.is_adjacent(current_pos, cell.board_pos):
		GameLogger.warning("Target cell not adjacent to resolving gear")
		return
	
	if (gear.owner_id == 0 and not cell.is_white()) or (gear.owner_id == 1 and cell.is_white()):
		GameLogger.warning("Wrong cell color for Interrupt")
		return
	
	game_state.t_pool[gear.owner_id] -= cost
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	var player = players[gear.owner_id]
	player.remove_from_hand(gear)
	
	cell.set_occupied(gear)
	gear.set_cell_size(Game.CELL_SIZE, Game.CELL_INDENT)
	gear.board_position = cell.board_pos
	gear.zone = Gear.Zone.BOARD
	
	gear.is_face_up = true
	gear.revealed = true
	gear.update_texture()
	gear.sprite.rotation_degrees = 0
	
	gear._apply_static_effects()
	
	if event_handler:
		gear.rotated.connect(event_handler._on_gear_rotated)
		gear.destroyed.connect(event_handler._on_gear_destroyed)
		gear.clicked.connect(event_handler._on_gear_clicked)
		gear.mouse_entered.connect(event_handler._on_gear_mouse_entered)
		gear.mouse_exited.connect(event_handler._on_gear_mouse_exited)
	
	EventBus.gear_placed.emit(gear, cell)
	
	game_state.chain_graph.add_vertex(cell.board_pos)
	game_state.chain_order.append(cell.board_pos)
	
	game_state.interrupt_played = true
	game_state.interrupt_pos = cell.board_pos
	game_state.interrupt_player = gear.owner_id
	
	stack_manager.clear_stack()
	
	if phase_machine.current_phase is ResolutionPhase:
		var res_phase = phase_machine.current_phase as ResolutionPhase
		res_phase.set_interrupt_played(gear, cell.board_pos)
		res_phase.restart_with_interrupt()
	
	GameLogger.info("Interrupt %s played at %s (cost %d T) - now ACTIVE, stack cleared" % [gear.gear_name, Game.pos_to_chess(cell.board_pos), cost])
	
	if turn_history_manager:
		turn_history_manager.add_action(
			"Interrupt: %s played at %s (cost %d T) - now ACTIVE" % [gear.gear_name, Game.pos_to_chess(cell.board_pos), cost],
			gear.owner_id
		)
	
	update_ui()

func reset_tuning_gears() -> void:
	if game_state.tuning_to_reset.is_empty():
		return
	for gear in game_state.tuning_to_reset:
		if is_instance_valid(gear) and gear.zone == Gear.Zone.BOARD and gear.is_face_up:
			gear.reset_tuning()
	game_state.tuning_to_reset.clear()

func get_players() -> Array:
	return players

func get_board_manager() -> BoardManager:
	return board_manager

func get_ability_by_id(id: int) -> Ability:
	return initializer.get_ability_by_id(id)

func is_valid_start_position(pos: Vector2i) -> bool:
	return rule_validator.is_valid_start_position(pos)

func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return rule_validator.is_adjacent(pos1, pos2)

func can_pass() -> bool:
	return rule_validator.can_pass()

func get_available_cells() -> Array[Cell]:
	return rule_validator.get_available_cells()

func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	return rule_validator.get_start_positions_for_player(player)

func update_ui() -> void:
	ui_manager._request_update()

func register_static_effect(gear: Gear, ability: Ability) -> void:
	var ctx = {"source_gear": gear}
	ability.execute(ctx)
	EventBus.static_effect_registered.emit(gear, ability)
	GameLogger.debug("Activated static effect: " + ability.ability_name + " for gear " + gear.gear_name)

func unregister_gear_effects(gear: Gear) -> void:
	game_state.effect_system.remove_modifiers_from_source(gear)
	EventBus.static_effect_unregistered.emit(gear, null)
	GameLogger.debug("Unregistered static effect for gear")

func is_ability_used_on_gear(gear: Gear, ability_id: int) -> bool:
	var dict = game_state.used_abilities_on_gear.get(gear)
	return dict != null and dict.has(ability_id)

func mark_ability_used_on_gear(gear: Gear, ability_id: int) -> void:
	if not game_state.used_abilities_on_gear.has(gear):
		game_state.used_abilities_on_gear[gear] = {}
	game_state.used_abilities_on_gear[gear][ability_id] = true

func clear_used_abilities() -> void:
	game_state.used_abilities_on_gear.clear()

func is_trigger_prevented(gear: Gear) -> bool:
	# Проверяем модификатор prevent_trigger на самой шестерне
	if game_state.effect_system.has_prevent_trigger(gear):
		GameLogger.debug("Trigger prevented by Mana Leak for %s" % gear.gear_name)
		return true
	
	# Также проверяем предотвращение от врага (для совместимости со старым кодом)
	var enemy_id = 1 - gear.owner_id
	if game_state.effect_system.use_prevent(enemy_id):
		GameLogger.debug("Trigger prevented by Mana Leak from enemy for %s" % gear.gear_name)
		return true
	
	return false
	
func add_edge(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if from_pos == to_pos:
		GameLogger.error("Attempted to add edge from cell to itself: %s" % Game.pos_to_chess(from_pos))
		return
	var edge_id = game_state.chain_graph.add_edge(from_pos, to_pos)
	EventBus.chain_built.emit(game_state.chain_graph.to_dict())
	GameLogger.debug("Added edge %d between %s and %s" % [edge_id, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)])

func on_successful_placement() -> void:
	game_state.has_placed_this_turn = true
	game_state.moves_in_round += 1

func set_active_cell(pos: Vector2i) -> void:
	if game_state.last_active_pos != Vector2i(-1, -1):
		var last_cell = board_manager.get_cell(game_state.last_active_pos)
		if last_cell:
			last_cell.set_active(false)
	
	if pos != Vector2i(-1, -1):
		var current_cell = board_manager.get_cell(pos)
		if current_cell:
			current_cell.set_active(true)
			
			# Добавляем лог для отладки
			GameLogger.debug("Active cell set to %s" % Game.pos_to_chess(pos))
	
	game_state.last_active_pos = pos

func proceed_to_next_cell() -> void:
	if phase_machine.current_phase is ResolutionPhase:
		(phase_machine.current_phase as ResolutionPhase).proceed_to_next_cell()
	else:
		GameLogger.error("proceed_to_next_cell called but current phase is not ResolutionPhase")

func end_chain_building() -> void:
	GameLogger.debug("GameManager: end_chain_building called (will call change_phase to SWING_BACK)")
	phase_machine.change_phase(Game.GamePhase.SWING_BACK)
	GameLogger.info("Chain building phase ended. Starting swing back phase.")

func end_swing_back() -> void:
	GameLogger.debug("GameManager: end_swing_back called")
	phase_machine.change_phase(Game.GamePhase.CHAIN_RESOLUTION)
	GameLogger.info("Swing back phase ended. Starting chain resolution.")

func end_chain_resolution() -> void:
	GameLogger.debug("GameManager: end_chain_resolution called (will call round_manager.end_chain_resolution)")
	round_manager.end_chain_resolution()

func end_game(winner_id: int) -> void:
	round_manager.end_game(winner_id)

func request_state_based_check() -> void:
	if _state_based_check_pending:
		return
	_state_based_check_pending = true
	call_deferred("_check_state_based_actions")

func can_control_legendary(gear: Gear, player_id: int) -> bool:
	if gear.supertype != GameEnums.GearSupertype.LEGENDARY:
		return true
	
	var count = 0
	for existing in board_manager.get_all_gears():
		if existing.owner_id == player_id and existing.is_face_up:
			if existing.gear_name == gear.gear_name:
				count += 1
	
	return count == 0

func _check_state_based_actions() -> void:
	_state_based_check_pending = false
	var max_iterations = 100
	var iterations = 0
	while true:
		iterations += 1
		if iterations > max_iterations:
			GameLogger.error("_check_state_based_actions: too many iterations, possible infinite loop")
			break
		
		var actions_taken = false
		
		for gear in board_manager.get_all_gears():
			if gear.type == GameEnums.GearType.CREATURE and gear.get_current_resistance() <= 0:
				gear.destroy()
				actions_taken = true
				continue
		
		for gear in board_manager.get_all_gears():
			if gear.current_ticks >= gear.max_ticks and not gear.is_face_up:
				var prevented = game_state.effect_system.has_modifier(gear, "prevent_trigger")
				if not prevented:
					gear.flip()
				else:
					game_state.effect_system.remove_modifier_by_tag(gear, "prevent_trigger")
					GameLogger.debug("Trigger prevented by Mana Leak")
				actions_taken = true
		
		for gear in board_manager.get_all_gears():
			if gear.current_ticks <= -gear.max_tocks:
				gear.destroy()
				actions_taken = true
				continue
		
		if not actions_taken:
			break
