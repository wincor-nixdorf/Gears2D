# mana_leak_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.MANA_LEAK
	ability_name = "Mana Leak"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	description = "When triggered, prevent the next trigger of target enemy gear."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	var target = context.get("target") as Gear
	if not source or not target:
		return
	# Добавляем модификатор предотвращения срабатывания
	effect_system.add_modifier(target, source, "prevent_trigger")
	GameLogger.debug("Mana Leak applied to %s" % target.gear_name)

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	var result = []
	for gear in game_manager.get_board_manager().get_all_gears():
		if gear.owner_id != source.owner_id:
			result.append(gear)
	return result
