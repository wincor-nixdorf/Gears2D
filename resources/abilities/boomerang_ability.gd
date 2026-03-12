# boomerang_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.SPRING
	ability_name = "Boomerang"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	target_type = GameEnums.TargetType.GEAR
	description = "When triggered, return any gear to its owner's hand."

func execute(context: Dictionary) -> void:
	var source = context.get("source_gear") as Gear
	var target = context.get("target") as Gear
	if not source or not target:
		return
	
	var owner = game_manager.get_players()[target.owner_id]
	# Возврат может быть асинхронным? Нет, он синхронный.
	owner.return_gear_to_hand(target)
	GameLogger.info("Boomerang returned gear %s to owner's hand" % target.gear_name)
	# Обновляем UI после возврата
	game_manager.update_ui()

func get_possible_targets(context: Dictionary) -> Array:
	return game_manager.get_board_manager().get_all_gears()
