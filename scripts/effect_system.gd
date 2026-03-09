# effect_system.gd
class_name EffectSystem
extends RefCounted

class ModifierEntry:
	var source: Object
	var tag: String
	var data: Dictionary
	
	func _init(p_source: Object, p_tag: String, p_data: Dictionary = {}):
		source = p_source
		tag = p_tag
		data = p_data

class DelayedEffectEntry:
	var source: Object
	var trigger: int
	var effect: AbilityEffect
	var remaining_turns: int
	var context: Dictionary
	
	func _init(p_source: Object, p_trigger: int, p_effect: AbilityEffect, p_duration: int, p_context: Dictionary = {}):
		source = p_source
		trigger = p_trigger
		effect = p_effect
		remaining_turns = p_duration
		context = p_context

var _modifiers: Dictionary = {}
var _delayed_effects: Array[DelayedEffectEntry] = []

func add_modifier(target: Object, source: Object, tag: String, data: Dictionary = {}):
	if not _modifiers.has(target):
		_modifiers[target] = []
	_modifiers[target].append(ModifierEntry.new(source, tag, data))
	GameLogger.debug("EffectSystem: added modifier '%s' to %s from %s" % [tag, target, source])

func remove_modifier(target: Object, source: Object, tag: String):
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

func remove_modifier_by_tag(target: Object, tag: String):
	if not _modifiers.has(target):
		return
	var entries = _modifiers[target]
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].tag == tag:
			entries.remove_at(i)
	if entries.is_empty():
		_modifiers.erase(target)

func remove_modifiers_from_source(source: Object):
	for target in _modifiers.keys():
		var entries = _modifiers[target]
		var modified = false
		for i in range(entries.size() - 1, -1, -1):
			if entries[i].source == source:
				entries.remove_at(i)
				modified = true
		if modified and entries.is_empty():
			_modifiers.erase(target)

func remove_modifiers_from_target(target: Object):
	if _modifiers.has(target):
		_modifiers.erase(target)
		GameLogger.debug("EffectSystem: removed all modifiers from target %s" % target)
		
func has_modifier(target: Object, tag: String) -> bool:
	if not _modifiers.has(target):
		return false
	for entry in _modifiers[target]:
		if entry.tag == tag:
			return true
	return false

func get_modifier_tags(target: Object) -> Array[String]:
	if not _modifiers.has(target):
		return []
	var tags: Array[String] = []
	for entry in _modifiers[target]:
		tags.append(entry.tag)
	return tags

func add_delayed_effect(source: Object, trigger: int, effect: AbilityEffect, duration: int, context: Dictionary = {}):
	_delayed_effects.append(DelayedEffectEntry.new(source, trigger, effect, duration, context))
	GameLogger.debug("EffectSystem: added delayed effect (trigger: %d, duration: %d) from %s" % [trigger, duration, source])

func process_delayed_effects(event_trigger: int, global_context: Dictionary = {}):
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

func clear():
	_modifiers.clear()
	_delayed_effects.clear()
