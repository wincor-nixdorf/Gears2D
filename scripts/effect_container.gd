# effect_container.gd
class_name EffectContainer
extends RefCounted

class StaticEffect:
	var source: Node
	var layer: int
	var effect: AbilityEffect
	var condition: Callable
	
	func _init(p_source: Node, p_layer: int, p_effect: AbilityEffect, p_condition: Callable = Callable()):
		source = p_source
		layer = p_layer
		effect = p_effect
		condition = p_condition

class DelayedEffect:
	var source: Node
	var trigger: int   # будет соответствовать Ability.TriggerCondition
	var effect: AbilityEffect
	var remaining_turns: int
	
	func _init(p_source: Node, p_trigger: int, p_effect: AbilityEffect, p_remaining: int):
		source = p_source
		trigger = p_trigger
		effect = p_effect
		remaining_turns = p_remaining

var static_effects: Array[StaticEffect] = []
var delayed_effects: Array[DelayedEffect] = []

func add_static_effect(source: Node, layer: int, effect: AbilityEffect, condition: Callable = Callable()):
	static_effects.append(StaticEffect.new(source, layer, effect, condition))

func add_delayed_effect(source: Node, trigger: int, effect: AbilityEffect, duration: int):
	delayed_effects.append(DelayedEffect.new(source, trigger, effect, duration))

func process_delayed_effects(event_trigger: int):
	var to_remove = []
	for eff in delayed_effects:
		if eff.trigger == event_trigger:
			# Выполнить эффект
			eff.effect.execute({})   # упрощенно, контекст нужно передавать
			eff.remaining_turns -= 1
			if eff.remaining_turns <= 0:
				to_remove.append(eff)
	for eff in to_remove:
		delayed_effects.erase(eff)
