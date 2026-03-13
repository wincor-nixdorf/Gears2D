# effect_system.gd
class_name EffectSystem
extends RefCounted

class ModifierEntry:
	var source: Object
	var tag: String
	var data: Dictionary
	
	func _init(p_source: Object, p_tag: String, p_data: Dictionary = {}) -> void:
		source = p_source
		tag = p_tag
		data = p_data

class DelayedEffectEntry:
	var source: Object
	var trigger: int
	var effect: AbilityEffect
	var remaining_turns: int
	var context: Dictionary
	
	func _init(p_source: Object, p_trigger: int, p_effect: AbilityEffect, p_duration: int, p_context: Dictionary = {}) -> void:
		source = p_source
		trigger = p_trigger
		effect = p_effect
		remaining_turns = p_duration
		context = p_context

var _modifiers: Dictionary = {}           # ключ: целевой объект, значение: массив ModifierEntry
var _delayed_effects: Array[DelayedEffectEntry] = []
var _prevent_counts: Dictionary[int, int] = {}   # owner_id -> количество предотвращений

# Добавляет модификатор к цели
func add_modifier(target: Object, source: Object, tag: String, data: Dictionary = {}) -> void:
	if not _modifiers.has(target):
		_modifiers[target] = []
	_modifiers[target].append(ModifierEntry.new(source, tag, data))
	GameLogger.debug("EffectSystem: added modifier '%s' to %s from %s" % [tag, target, source])

# Удаляет конкретный модификатор (по источнику и тегу)
func remove_modifier(target: Object, source: Object, tag: String) -> void:
	if not _modifiers.has(target):
		return
	var entries = _modifiers[target]
	for i in range(entries.size() - 1, -1, -1):
		var entry = entries[i]
		if entry.source == source and entry.tag == tag:
			entries.remove_at(i)
			GameLogger.debug("EffectSystem: removed modifier '%s' from %s (source: %s)" % [tag, target, source])
	if entries.is_empty():
		_modifiers.erase(target)

# Удаляет все модификаторы с заданным тегом (независимо от источника)
func remove_modifier_by_tag(target: Object, tag: String) -> void:
	if not _modifiers.has(target):
		return
	var entries = _modifiers[target]
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].tag == tag:
			entries.remove_at(i)
	if entries.is_empty():
		_modifiers.erase(target)

# Удаляет все модификаторы, источником которых является заданный объект
func remove_modifiers_from_source(source: Object) -> void:
	for target in _modifiers.keys():
		var entries = _modifiers[target]
		var modified = false
		for i in range(entries.size() - 1, -1, -1):
			if entries[i].source == source:
				entries.remove_at(i)
				modified = true
		if modified and entries.is_empty():
			_modifiers.erase(target)

# Удаляет все модификаторы с заданной цели
func remove_modifiers_from_target(target: Object) -> void:
	if _modifiers.has(target):
		_modifiers.erase(target)
		GameLogger.debug("EffectSystem: removed all modifiers from target %s" % target)

# Проверяет наличие модификатора с заданным тегом на цели
func has_modifier(target: Object, tag: String) -> bool:
	if not _modifiers.has(target):
		return false
	for entry in _modifiers[target]:
		if entry.tag == tag:
			return true
	return false

# Возвращает список тегов всех модификаторов на цели
func get_modifier_tags(target: Object) -> Array[String]:
	if not _modifiers.has(target):
		return []
	var tags: Array[String] = []
	for entry in _modifiers[target]:
		tags.append(entry.tag)
	return tags

# Добавляет отложенный эффект
func add_delayed_effect(source: Object, trigger: int, effect: AbilityEffect, duration: int, context: Dictionary = {}) -> void:
	_delayed_effects.append(DelayedEffectEntry.new(source, trigger, effect, duration, context))
	GameLogger.debug("EffectSystem: added delayed effect (trigger: %d, duration: %d) from %s" % [trigger, duration, source])

# Обрабатывает все отложенные эффекты для данного триггера
func process_delayed_effects(event_trigger: int, global_context: Dictionary = {}) -> void:
	var to_remove = []
	for entry in _delayed_effects:
		if entry.trigger == event_trigger:
			var exec_context = global_context.duplicate()
			exec_context.merge(entry.context)
			exec_context["source"] = entry.source
			entry.effect.execute(exec_context)
			
			entry.remaining_turns -= 1
			if entry.remaining_turns <= 0:
				to_remove.append(entry)
	
	for entry in to_remove:
		_delayed_effects.erase(entry)
		GameLogger.debug("EffectSystem: delayed effect expired from %s" % entry.source)

# Добавляет одно предотвращение для владельца (используется Mana Leak)
func add_prevent(owner_id: int) -> void:
	_prevent_counts[owner_id] = _prevent_counts.get(owner_id, 0) + 1
	GameLogger.debug("EffectSystem: added prevent for owner %d, now %d" % [owner_id, _prevent_counts[owner_id]])

# Пытается использовать одно предотвращение для врага (enemy_id)
# Возвращает true, если предотвращение было и успешно использовано
func use_prevent(enemy_id: int) -> bool:
	if _prevent_counts.has(enemy_id) and _prevent_counts[enemy_id] > 0:
		_prevent_counts[enemy_id] -= 1
		if _prevent_counts[enemy_id] == 0:
			_prevent_counts.erase(enemy_id)
		GameLogger.debug("EffectSystem: used prevent for enemy %d, remaining %d" % [enemy_id, _prevent_counts.get(enemy_id, 0)])
		return true
	return false

# Очищает все эффекты и счётчики (при сбросе игры)
func clear() -> void:
	_modifiers.clear()
	_delayed_effects.clear()
	_prevent_counts.clear()

# Очищает только счётчики предотвращений (в конце раунда)
func clear_prevent_counts() -> void:
	_prevent_counts.clear()
