# mana_leak_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.MANA_LEAK
	ability_name = "Mana Leak"
	target_type = GameEnums.TargetType.GEAR
	description = "Prevent the next trigger of target gear."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	var target = context.get("target") as Gear
	
	if not source or not target:
		GameLogger.error("Mana Leak: missing source or target")
		return
	
	# Добавляем модификатор prevent_trigger на целевую шестерню
	effect_system.add_modifier(target, source, "prevent_trigger")
	GameLogger.debug("Mana Leak: added prevent_trigger to %s" % target.gear_name)

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	
	var targets: Array = []
	
	# Можно выбрать любую вражескую шестерню
	for gear in game_manager.board_manager.get_all_gears():
		if gear.owner_id != source.owner_id:
			targets.append(gear)
	
	return targets
