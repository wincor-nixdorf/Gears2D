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
	ui_manager = GameUIManager.new(self, game_state, ui, board_manager, rule_validator)
	ui.stack_panel.set_stack_manager(stack_manager)
	
	initialize_game()
	ui.action_pressed.connect(event_handler._on_action_button_pressed)
	ui.hand_gear_selected.connect(event_handler._on_hand_gear_selected)
	EventBus.player_icon_clicked.connect(event_handler._on_player_icon_clicked)
	GameLogger.info("GameManager ready")

func initialize_game() -> void:
	game_state.reset()
	initializer.initialize_game()
	round_manager.start_round()
	GameLogger.info("Game initialized")

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
	var enemy_id = 1 - gear.owner_id
	return game_state.effect_system.use_prevent(enemy_id)

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
		board_manager.set_cell_active(game_state.last_active_pos, false)
	if pos != Vector2i(-1, -1):
		board_manager.set_cell_active(pos, true)
	game_state.last_active_pos = pos

func proceed_to_next_cell() -> void:
	if phase_machine.current_phase is ResolutionPhase:
		(phase_machine.current_phase as ResolutionPhase).proceed_to_next_cell()
	else:
		GameLogger.error("proceed_to_next_cell called but current phase is not ResolutionPhase")

func restart_chain_resolution() -> void:
	if phase_machine.current_phase is ResolutionPhase:
		await (phase_machine.current_phase as ResolutionPhase).restart_chain_resolution()
	else:
		GameLogger.error("restart_chain_resolution called but current phase is not ResolutionPhase")

func end_chain_building() -> void:
	GameLogger.debug("GameManager: end_chain_building called (will call change_phase to UPTURN)")  # добавлено
	phase_machine.change_phase(Game.GamePhase.UPTURN)
	GameLogger.info("Chain building phase ended. Starting upturn phase.")

func end_upturn() -> void:
	GameLogger.debug("GameManager: end_upturn called from %s (will call change_phase to RESOLUTION)" % str(get_stack()))  # добавлено
	phase_machine.change_phase(Game.GamePhase.CHAIN_RESOLUTION)
	GameLogger.info("Upturn phase ended. Starting chain resolution.")

func end_chain_resolution() -> void:
	GameLogger.debug("GameManager: end_chain_resolution called (will call round_manager.end_chain_resolution)")  # добавлено
	round_manager.end_chain_resolution()

func end_game(winner_id: int) -> void:
	round_manager.end_game(winner_id)

func _check_state_based_actions() -> void:
	var max_iterations = 100
	var iterations = 0
	while true:
		iterations += 1
		if iterations > max_iterations:
			GameLogger.error("_check_state_based_actions: too many iterations, possible infinite loop")
			break
		
		var actions_taken = false
		for gear in board_manager.get_all_gears():
			if gear.current_ticks <= -gear.max_tocks:
				gear.destroy()
				actions_taken = true
				continue
			if gear.current_ticks >= gear.max_ticks and not gear.is_triggered:
				var prevented = game_state.effect_system.has_modifier(gear, "prevent_trigger")
				if not prevented:
					gear.trigger()
				else:
					game_state.effect_system.remove_modifier_by_tag(gear, "prevent_trigger")
					GameLogger.debug("Trigger prevented by Mana Leak")
				actions_taken = true
		
		if not actions_taken:
			break
