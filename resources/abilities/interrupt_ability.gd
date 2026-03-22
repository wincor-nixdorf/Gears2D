# interrupt_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.INTERRUPT
	ability_name = "Interrupt"
	target_type = GameEnums.TargetType.NO_TARGET
	description = "Interrupt"

func execute(context: Dictionary):
	# Эта способность не выполняется при разрешении
	# Она используется только для того, чтобы карта могла быть сыграна как Interrupt
	pass
