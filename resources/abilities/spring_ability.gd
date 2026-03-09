# spring_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.SPRING
	ability_name = "Spring"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	target_type = GameEnums.TargetType.GEAR
	description = "When triggered, return target enemy gear (not in current chain) to its owner's hand."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	var target = context.get("target") as Gear
	if not source or not target:
		return
	
	# Цель должна принадлежать противнику
	if target.owner_id == source.owner_id:
		GameLogger.debug("Spring: target must be enemy gear")
		return
	
	# Нельзя вернуть шестерню из текущей цепочки (опционально)
	if GameState.chain_graph.has_vertex(target.board_position):
		GameLogger.debug("Spring: target is in current chain, cannot return")
		return
	
	var owner = GameManager.ref.players[target.owner_id]
	owner.return_gear_to_hand(target)
	GameLogger.info("Spring returned enemy gear %s to opponent's hand" % target.gear_name)

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	
	var result = []
	for gear in GameManager.ref.board_manager.get_all_gears():
		# Вражеская шестерня, не в текущей цепочке
		if gear.owner_id != source.owner_id and not GameState.chain_graph.has_vertex(gear.board_position):
			result.append(gear)
	return result
