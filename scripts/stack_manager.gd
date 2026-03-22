# stack_manager.gd
class_name StackManager
extends RefCounted

class StackEntry:
	var ability: Ability
	var source: Gear
	var target: Object
	var context: Dictionary
	var id: int
	var source_pos: Vector2i
	
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

var _stack: Array[StackEntry] = []
var _pending_target_entry: StackEntry = null
var _batch_mode: bool = false
var _pending_batch: Array[StackEntry] = []
var _batch_active_player: int = -1
var _batch_in_progress: bool = false
var _game_manager: GameManager
var _game_state: GameState
var _event_bus: EventBus

func _init(gm: GameManager, gs: GameState, eb: EventBus):
	_game_manager = gm
	_game_state = gs
	_event_bus = eb
	_event_bus.target_selected.connect(_on_target_selected)
	_event_bus.target_selection_cancelled.connect(_on_target_selection_cancelled)

func begin_batch(active_player_id: int) -> void:
	_batch_mode = true
	_batch_in_progress = true
	_batch_active_player = active_player_id
	_pending_batch.clear()

func end_batch() -> void:
	_batch_mode = false
	if _pending_batch.is_empty():
		_batch_in_progress = false
		return
	_process_batch()

func push_effect(ability: Ability, source: Gear, target: Object = null, context: Dictionary = {}) -> void:
	if not source:
		push_error("StackManager: push_effect called without source")
		return
	var entry = StackEntry.new(ability, source, target, context)
	if _batch_mode:
		_pending_batch.append(entry)
		GameLogger.debug("Stack (batch): added effect %s from %s" % [ability.ability_name, source.gear_name])
	else:
		_stack.push_front(entry)
		GameLogger.debug("Stack: pushed effect %s from %s at %s" % [ability.ability_name, source.gear_name, Game.pos_to_chess(source.board_position)])
		_event_bus.stack_updated.emit(get_stack_snapshot())

func push_effect_with_target(ability: Ability, source: Gear, context: Dictionary = {}) -> void:
	if not source:
		push_error("StackManager: push_effect_with_target called without source")
		return
	
	var entry = StackEntry.new(ability, source, null, context)
	
	# Если способность требует цель, запрашиваем её сейчас
	if ability.target_type != GameEnums.TargetType.NO_TARGET:
		_pending_target_entry = entry
		_event_bus.target_selection_requested.emit(ability, source, ability.get_possible_targets(context), context)
		return
	
	# Если цель не требуется, добавляем в стек
	if _batch_mode:
		_pending_batch.append(entry)
	else:
		_stack.push_front(entry)
		_event_bus.stack_updated.emit(get_stack_snapshot())
		
func _process_batch() -> void:
	var active_id = _batch_active_player
	var active_entries: Array[StackEntry] = []
	var inactive_entries: Array[StackEntry] = []
	
	for entry in _pending_batch:
		if entry.source.owner_id == active_id:
			active_entries.append(entry)
		else:
			inactive_entries.append(entry)
	
	GameLogger.debug("Processing batch: active_id=%d, active_entries=%d, inactive_entries=%d" % [active_id, active_entries.size(), inactive_entries.size()])
	
	var active_ordered: Array[StackEntry] = []
	if not active_entries.is_empty():
		if active_entries.size() == 1:
			active_ordered = active_entries
			GameLogger.debug("Active player %d has single entry, skipping order dialog" % active_id)
		else:
			_event_bus.batch_ordering_requested.emit(active_id, active_entries)
			var result = await _event_bus.batch_ordering_completed
			active_ordered = result if result != null else active_entries
			GameLogger.debug("Active player %d returned %d entries" % [active_id, active_ordered.size()])
	
	var inactive_ordered: Array[StackEntry] = []
	if not inactive_entries.is_empty():
		if inactive_entries.size() == 1:
			inactive_ordered = inactive_entries
			GameLogger.debug("Inactive player %d has single entry, skipping order dialog" % (1 - active_id))
		else:
			_event_bus.batch_ordering_requested.emit(1 - active_id, inactive_entries)
			var result = await _event_bus.batch_ordering_completed
			inactive_ordered = result if result != null else inactive_entries
			GameLogger.debug("Inactive player %d returned %d entries" % [1 - active_id, inactive_ordered.size()])
	
	_stack.clear()
	
	for i in range(active_ordered.size()):
		_stack.push_front(active_ordered[i])
	
	for i in range(inactive_ordered.size()):
		_stack.push_front(inactive_ordered[i])
	
	_pending_batch.clear()
	_batch_in_progress = false
	_event_bus.stack_updated.emit(get_stack_snapshot())
	GameLogger.debug("Batch processed, stack size: %d" % _stack.size())

func get_stack_snapshot() -> Array:
	var snapshot = []
	for entry in _stack:
		snapshot.append(entry.to_dict())
	return snapshot

func resolve_next() -> void:
	if _pending_target_entry != null:
		GameLogger.debug("Cannot resolve next while waiting for target selection")
		return
	
	if _stack.is_empty():
		if not _batch_in_progress:
			_event_bus.stack_resolved.emit()
			_event_bus.stack_updated.emit(get_stack_snapshot())
			if _game_manager:
				_game_manager.request_state_based_check()
				_game_manager.reset_tuning_gears()
		return
	
	var entry = _stack.pop_front()
	var entry_data = entry.to_dict()
	_event_bus.stack_step_started.emit(entry_data)
	GameLogger.debug("Stack: resolving effect %s from %s" % [entry.ability.ability_name, entry.source.gear_name])
	
	# Проверяем легальность цели (цель уже должна быть выбрана)
	if entry.ability.target_type != GameEnums.TargetType.NO_TARGET:
		if entry.target == null:
			GameLogger.debug("Ability %s: no target selected, fizzles" % entry.ability.ability_name)
			_event_bus.stack_step_finished.emit(entry_data)
			_event_bus.stack_updated.emit(get_stack_snapshot())
			if _stack.is_empty() and _pending_target_entry == null and not _batch_in_progress:
				_event_bus.stack_resolved.emit()
				if _game_manager:
					_game_manager.request_state_based_check()
					_game_manager.reset_tuning_gears()
			return
		
		var possible_targets = entry.ability.get_possible_targets({"source_gear": entry.source})
		if entry.target not in possible_targets:
			GameLogger.debug("Ability %s: target is no longer legal, fizzles" % entry.ability.ability_name)
			_event_bus.stack_step_finished.emit(entry_data)
			_event_bus.stack_updated.emit(get_stack_snapshot())
			if _stack.is_empty() and _pending_target_entry == null and not _batch_in_progress:
				_event_bus.stack_resolved.emit()
				if _game_manager:
					_game_manager.request_state_based_check()
					_game_manager.reset_tuning_gears()
			return
	
	await _execute_entry(entry)
	_event_bus.stack_step_finished.emit(entry_data)
	_event_bus.stack_updated.emit(get_stack_snapshot())
	if _stack.is_empty() and _pending_target_entry == null and not _batch_in_progress:
		_event_bus.stack_resolved.emit()
		if _game_manager:
			_game_manager.request_state_based_check()
			_game_manager.reset_tuning_gears()

func _execute_entry(entry: StackEntry) -> void:
	# Проверка, что цель всё ещё существует
	if entry.target and not is_instance_valid(entry.target):
		GameLogger.debug("Ability %s: target destroyed, fizzles" % entry.ability.ability_name)
		return
	
	if entry.target != null and entry.ability.target_type != GameEnums.TargetType.NO_TARGET:
		var possible_targets = entry.ability.get_possible_targets({"source_gear": entry.source})
		if entry.target not in possible_targets:
			GameLogger.debug("Ability %s: target is no longer legal, fizzles" % entry.ability.ability_name)
			return
	
	var context = entry.context.duplicate()
	context["source_gear"] = entry.source
	if entry.target:
		context["target"] = entry.target
	await entry.ability.execute(context)

func has_pending_target() -> bool:
	return _pending_target_entry != null
	
func _on_target_selected(target: Object) -> void:
	if _pending_target_entry == null:
		GameLogger.debug("Stack: target selected but no pending entry")
		return
	
	var entry = _pending_target_entry
	_pending_target_entry = null
	
	# Проверяем, что цель легальна
	var possible_targets = entry.ability.get_possible_targets({"source_gear": entry.source})
	if target not in possible_targets:
		GameLogger.debug("Ability %s: target is not legal, cancelling" % entry.ability.ability_name)
		_event_bus.target_selection_cancelled.emit()
		return
	
	entry.target = target
	
	# Убираем подсветку
	_event_bus.target_selection_cancelled.emit()
	
	# Добавляем способность с выбранной целью в стек
	if _batch_mode:
		_pending_batch.append(entry)
	else:
		_stack.push_front(entry)
		_event_bus.stack_updated.emit(get_stack_snapshot())
	
	GameLogger.debug("Stack: added effect %s from %s with target %s" % [entry.ability.ability_name, entry.source.gear_name, target])

func _on_target_selection_cancelled() -> void:
	if _pending_target_entry == null:
		return
	
	GameLogger.debug("Stack: target selection cancelled for %s" % _pending_target_entry.ability.ability_name)
	_pending_target_entry = null
	_event_bus.stack_updated.emit(get_stack_snapshot())

func clear_stack() -> void:
	_stack.clear()
	_pending_target_entry = null
	_event_bus.stack_updated.emit(get_stack_snapshot())

func is_stack_empty() -> bool:
	return _stack.is_empty() and _pending_target_entry == null

func is_batch_active() -> bool:
	return _batch_mode

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
	_stack.clear()
	for data in ordered_entries_data:
		var ability = _find_ability_by_id(data["ability_id"])
		var source = _find_gear_by_id(data["source_gear_id"])
		var target = _find_object_by_id(data["target"])
		var context = data["context"]
		if ability == null or source == null:
			push_error("StackManager: could not restore entry")
			continue
		var entry = StackEntry.new(ability, source, target, context)
		entry.id = data["id"]
		_stack.append(entry)
	_event_bus.stack_updated.emit(get_stack_snapshot())
