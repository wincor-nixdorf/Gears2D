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

func request_selection(ability: Ability, source: Gear, targets: Array, context: Dictionary) -> void:
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
	
	event_bus.target_selection_cancelled.emit()  # убираем подсветку
	
	if ability == null:
		GameLogger.error("TargetSelector: current_ability is null in select_target")
		return
	
	context["target"] = target
	# НЕ вызываем ability.execute здесь! Только возвращаем цель через сигнал.
	# Диспетчер сам решит, что делать.
	
	# Возвращаем цель через сигнал
	event_bus.target_selected.emit(target)

func cancel_selection() -> void:
	if not is_waiting:
		return
	is_waiting = false
	event_bus.target_selection_cancelled.emit()
	current_ability = null
	current_source = null
	current_context = {}
	possible_targets = []
