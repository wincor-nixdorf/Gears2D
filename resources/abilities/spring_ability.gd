extends Ability

func _init():
	ability_id = GameEnums.AbilityID.SPRING
	ability_name = "Spring"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	target_type = GameEnums.TargetType.GEAR
	description = "When triggered, return target gear (not in current chain) to owner's hand."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	var target = context.get("target") as Gear
	if target and source:
		if not GameManager.ref.chain_graph.has(target.board_position):
			var owner = GameManager.ref.players[target.owner_id]
			owner.return_gear_to_hand(target)
			GameLogger.info("Spring returned gear to hand")
