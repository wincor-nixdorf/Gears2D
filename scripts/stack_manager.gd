# stack_manager.gd
class_name StackManager
extends RefCounted

class StackEntry:
	var ability: Ability
	var source: Gear
	var target: Object
	var context: Dictionary
	var id: int
	var source_pos: Vector2i   # позиция источника (для отображения)
	
	static var _next_id: int = 0
	
	func _init(p_ability: Ability, p_source: Gear, p_target: Object = null, p_context: Dictionary = {}):
		ability = p_ability
		source = p_source
		target = p_target
		context = p_context
		source_pos = p_source.board_position
		id = _next_id
		_next_id += 1
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"ability_id": ability.ability_id,
			"ability_name": ability.ability_name,
			"source_gear_id": source.get_instance_id(),
			"source_gear_name": source.gear_name,
			"source_owner_id": source.owner_id,
			"source_pos_x": source_pos.x,
			"source_pos_y": source_pos.y,
			"target": target.get_instance_id() if target else 0,
			"context": context.duplicate()
		}

var _stacks: Dictionary = {
	0: [],
	1: []
}

var _pending_target_entry: StackEntry = null
var _game_manager: GameManager
var _game_state: GameState
var _event_bus: EventBus

func _init(gm: GameManager, gs: GameState, eb: EventBus):
	_game_manager = gm
	_game_state = gs
	_event_bus = eb
	_event_bus.target_selected.connect(_on_target_selected)
	_event_bus.target_selection_cancelled.connect(_on_target_selection_cancelled)

func push_effect(ability: Ability, source: Gear, target: Object = null, context: Dictionary = {}) -> void:
	if not source:
		push_error("StackManager: push_effect called without source")
		return
	var owner_id = source.owner_id
	_stacks[owner_id].push_front(StackEntry.new(ability, source, target, context))
	GameLogger.debug("Stack: pushed effect %s from %s at %s" % [ability.ability_name, source.gear_name, Game.pos_to_chess(source.board_position)])
	_event_bus.stack_updated.emit(_get_stack_snapshot())

func get_stack_snapshot() -> Array:
	return _get_stack_snapshot()

func _get_stack_snapshot() -> Array:
	var all_entries = []
	all_entries.append_array(_stacks[1])
	all_entries.append_array(_stacks[0])
	
	var snapshot = []
	for entry in all_entries:
		snapshot.append(entry.to_dict())
	return snapshot

func resolve_next() -> void:
	if _pending_target_entry != null:
		GameLogger.debug("Cannot resolve next while waiting for target selection")
		return
	
	if _stacks[0].is_empty() and _stacks[1].is_empty():
		_event_bus.stack_resolved.emit()
		_event_bus.stack_updated.emit(_get_stack_snapshot())
		return
	
	var entry: StackEntry
	if not _stacks[1].is_empty():
		entry = _stacks[1].pop_front()
	elif not _stacks[0].is_empty():
		entry = _stacks[0].pop_front()
	else:
		return
	
	var entry_data = entry.to_dict()
	_event_bus.stack_step_started.emit(entry_data)
	GameLogger.debug("Stack: resolving effect %s from %s" % [entry.ability.ability_name, entry.source.gear_name])
	
	if entry.ability.target_type != GameEnums.TargetType.NO_TARGET and entry.target == null:
		var possible_targets = entry.ability.get_possible_targets({"source_gear": entry.source})
		if possible_targets.is_empty():
			GameLogger.debug("Ability %s has no valid targets, skipping" % entry.ability.ability_name)
			_event_bus.stack_step_finished.emit(entry_data)
			_event_bus.stack_updated.emit(_get_stack_snapshot())
			# Проверяем, не стал ли стек пуст после пропуска
			if _stacks[0].is_empty() and _stacks[1].is_empty() and _pending_target_entry == null:
				_event_bus.stack_resolved.emit()
			return
		
		_pending_target_entry = entry
		_event_bus.target_selection_started.emit()
		GameLogger.debug("Stack: requesting target for %s" % entry.ability.ability_name)
		_event_bus.target_selection_requested.emit(entry.ability, entry.source, possible_targets, {})
		return
	
	await _execute_entry(entry)
	_event_bus.stack_step_finished.emit(entry_data)
	_event_bus.stack_updated.emit(_get_stack_snapshot())
	# После выполнения проверяем, не стал ли стек пуст
	if _stacks[0].is_empty() and _stacks[1].is_empty() and _pending_target_entry == null:
		_event_bus.stack_resolved.emit()

func _execute_entry(entry: StackEntry) -> void:
	var context = entry.context.duplicate()
	context["source_gear"] = entry.source
	if entry.target:
		context["target"] = entry.target
	await entry.ability.execute(context)

func _on_target_selected(target: Object) -> void:
	if _pending_target_entry == null:
		GameLogger.debug("Stack: target selected but no pending entry")
		return
	
	var entry = _pending_target_entry
	_pending_target_entry = null
	entry.target = target
	
	_event_bus.target_selection_cancelled.emit()
	
	await _execute_entry(entry)
	
	_event_bus.stack_step_finished.emit(entry.to_dict())
	_event_bus.stack_updated.emit(_get_stack_snapshot())
	# После выполнения проверяем, не стал ли стек пуст
	if _stacks[0].is_empty() and _stacks[1].is_empty() and _pending_target_entry == null:
		_event_bus.stack_resolved.emit()

func _on_target_selection_cancelled() -> void:
	if _pending_target_entry == null:
		return
	
	GameLogger.debug("Stack: target selection cancelled for %s" % _pending_target_entry.ability.ability_name)
	_pending_target_entry = null
	_event_bus.stack_updated.emit(_get_stack_snapshot())
	# Не продолжаем

func clear_stack() -> void:
	_stacks[0].clear()
	_stacks[1].clear()
	_pending_target_entry = null
	_event_bus.stack_updated.emit(_get_stack_snapshot())

func is_stack_empty() -> bool:
	return _stacks[0].is_empty() and _stacks[1].is_empty() and _pending_target_entry == null

# --- Методы для восстановления из словарей ---
func _find_ability_by_id(id: int) -> Ability:
	for gear in _game_manager.get_board_manager().get_all_gears():
		if not is_instance_valid(gear):
			continue
		for ability in gear.abilities:
			if ability.ability_id == id:
				return ability
	return null

func _find_gear_by_id(instance_id: int) -> Gear:
	var obj = instance_from_id(instance_id)
	if obj and obj is Gear:
		return obj
	return null

func _find_object_by_id(instance_id: int) -> Object:
	if instance_id == 0:
		return null
	var obj = instance_from_id(instance_id)
	return obj if is_instance_valid(obj) else null

func set_stack_order(ordered_entries_data: Array) -> void:
	_stacks[0].clear()
	_stacks[1].clear()
	for data in ordered_entries_data:
		var ability = _find_ability_by_id(data["ability_id"])
		var source = _find_gear_by_id(data["source_gear_id"])
		var target = _find_object_by_id(data["target"])
		var context = data["context"]
		if ability == null or source == null:
			push_error("StackManager: could not restore entry")
			continue
		var entry = StackEntry.new(ability, source, target, context)
		entry.id = data["id"]  # восстанавливаем id
		_stacks[entry.source.owner_id].append(entry)
	_event_bus.stack_updated.emit(_get_stack_snapshot())
