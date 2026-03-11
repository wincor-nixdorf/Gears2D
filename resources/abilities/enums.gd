# enums.gd
class_name GameEnums

enum AbilityID {
	SPRING,
	TIME_SWARM,
	REPEAT,
	MANA_LEAK,
	SPARK,
}

enum TriggerCondition {
	ON_TRIGGER,
	ON_PLACED,
	ON_DESTROYED,
	ON_TICK,
	ON_TOCK,
	ON_PHASE_START,
	ON_PHASE_END,
}

enum AbilityType {
	TRIGGERED,
	ACTIVATED,
	STATIC,
	DELAYED,
}

enum TargetType {
	NO_TARGET,
	GEAR,
	CELL,
	PLAYER,
	ANY,
}
