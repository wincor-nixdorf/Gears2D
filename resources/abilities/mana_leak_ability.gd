extends Ability

func _init():
	ability_id = GameEnums.AbilityID.MANA_LEAK
	ability_name = "Mana Leak"
	ability_type = GameEnums.AbilityType.ACTIVATED
	activation_cost = 1
	target_type = GameEnums.TargetType.GEAR
	description = "Pay 1 T: target enemy gear's next trigger is prevented."

func execute(context: Dictionary):
	var target = context.get("target") as Gear
	var source = context.get("source_gear") as Gear
	if target and source and target.owner_id != source.owner_id:
		GameManager.ref.apply_mana_leak(target)
		GameLogger.info("Mana Leak applied to gear")
