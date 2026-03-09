# target_selector.gd
class_name TargetSelector
extends RefCounted

var is_waiting: bool = false
var current_ability: Ability
var current_source: Gear
var current_context: Dictionary
var possible_targets: Array = []

func request_selection(ability: Ability, source: Gear, targets: Array, context: Dictionary):
	is_waiting = true
	current_ability = ability
	current_source = source
	current_context = context
	possible_targets = targets
	EventBus.target_selection_requested.emit(ability, source, targets, context)

func select_target(target: Object):
	if not is_waiting:
		return
	is_waiting = false
	current_context["target"] = target
	current_ability.execute(current_context)
	current_ability = null
	current_source = null
	current_context = {}
	possible_targets = []
	EventBus.target_selection_cancelled.emit()

func cancel_selection():
	if not is_waiting:
		return
	is_waiting = false
	current_ability = null
	current_source = null
	current_context = {}
	possible_targets = []
	EventBus.target_selection_cancelled.emit()
