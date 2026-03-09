# trigger_condition.gd
enum TriggerCondition {
	ON_TRIGGER,        # когда G срабатывает (переворачивается)
	ON_PLACED,         # когда G установлена на доску
	ON_DESTROYED,      # когда G уничтожена
	ON_TICK,           # когда G делает тик
	ON_TOCK,           # когда G делает так
	ON_PHASE_START,    # начало фазы
	ON_PHASE_END,      # конец фазы
	# ...
}
