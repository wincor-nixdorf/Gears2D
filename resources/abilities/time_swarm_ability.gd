extends Ability

func _init():
	ability_id = GameEnums.AbilityID.TIME_SWARM
	ability_name = "Time Swarm"
	ability_type = GameEnums.AbilityType.STATIC
	description = "All enemy gears do not make automatic tick during resolution."

func execute(context: Dictionary):
	# Статический эффект обрабатывается в should_skip_auto_tick
	pass
