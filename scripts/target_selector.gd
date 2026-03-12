# target_selector.gd
class_name TargetSelector
extends RefCounted

var is_waiting: bool = false
var current_ability: Ability
var current_source: Gear
var current_context: Dictionary
var possible_targets: Array = []
var event_bus
var game_manager: GameManager
var game_state: GameState

func _init(eb, gm: GameManager, gs: GameState):
	event_bus = eb
	game_manager = gm
	game_state = gs

func request_selection(ability: Ability, source: Gear, targets: Array, context: Dictionary):
	is_waiting = true
	current_ability = ability
	current_source = source
	current_context = context
	possible_targets = targets
	event_bus.target_selection_requested.emit(ability, source, targets, context)

func select_target(target: Object) -> void:
	if not is_waiting:
		return
	
	# Сохраняем ссылки перед сбросом
	var ability = current_ability
	var context = current_context.duplicate()
	var source = current_source
	
	is_waiting = false
	current_ability = null
	current_source = null
	current_context = {}
	possible_targets = []
	
	event_bus.target_selection_cancelled.emit()
	
	if ability == null:
		GameLogger.error("TargetSelector: current_ability is null in select_target")
		return
	
	context["target"] = target
	# Ждём завершения выполнения способности
	await ability.execute(context)
	game_manager.update_ui()
	
	# Автоматический переход к следующей G в цепочке, если текущая G стала face-up
	if game_state.current_phase == Game.GamePhase.CHAIN_RESOLUTION:
		var current_gear = game_manager.board_manager.get_gear_at(game_state.current_resolve_pos)
		if current_gear and current_gear.is_face_up:
			game_manager.proceed_to_next_cell()

func cancel_selection():
	if not is_waiting:
		return
	is_waiting = false
	event_bus.target_selection_cancelled.emit()
	current_ability = null
	current_source = null
	current_context = {}
	possible_targets = []
