# ability_dispatcher.gd
class_name AbilityDispatcher
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var event_bus: EventBus
var target_selector: TargetSelector

func _init(gm: GameManager, gs: GameState, eb):
	game_manager = gm
	game_state = gs
	event_bus = eb
	target_selector = TargetSelector.new(eb, gm, gs)  # добавлен gs
	_connect_signals()

func _connect_signals():
	event_bus.gear_triggered.connect(_on_gear_triggered)
	event_bus.gear_placed.connect(_on_gear_placed)
	event_bus.gear_destroyed.connect(_on_gear_destroyed)
	event_bus.gear_rotated.connect(_on_gear_rotated)
	event_bus.phase_changed.connect(_on_phase_changed)
	event_bus.target_selected.connect(_on_target_selected)
	event_bus.target_selection_cancelled.connect(_on_target_selection_cancelled)
	event_bus.gear_resolved.connect(_on_gear_resolved)

func _on_gear_triggered(gear: Gear):
	_trigger_abilities_on_gear(gear, GameEnums.TriggerCondition.ON_TRIGGER, {"source_gear": gear})

func _on_gear_resolved(gear: Gear, was_face_up: bool):
	# Если шестерня уже была перевёрнута до разрешения, активируем её триггерные способности
	if was_face_up:
		_trigger_abilities_on_gear(gear, GameEnums.TriggerCondition.ON_TRIGGER, {"source_gear": gear})

func _on_gear_placed(gear: Gear, cell: Cell):
	_trigger_abilities_on_gear(gear, GameEnums.TriggerCondition.ON_PLACED, {"source_gear": gear, "cell": cell})
	
	var enemy_id = 1 - gear.owner_id
	for enemy_gear in game_manager.get_board_manager().get_all_gears():
		if enemy_gear.owner_id == enemy_id and game_state.effect_system.has_modifier(enemy_gear, "time_swarm_source"):
			game_state.effect_system.add_modifier(gear, enemy_gear, "no_auto_tick")
			GameLogger.debug("Time Swarm: added no_auto_tick to new gear %s from %s" % [gear.gear_name, enemy_gear.gear_name])

func _on_gear_destroyed(gear: Gear):
	_trigger_abilities_on_gear(gear, GameEnums.TriggerCondition.ON_DESTROYED, {"source_gear": gear})

func _on_gear_rotated(gear: Gear, old_ticks: int, new_ticks: int):
	var direction = "tick" if new_ticks > old_ticks else "tock"
	var context = {"source_gear": gear, "old_ticks": old_ticks, "new_ticks": new_ticks, "direction": direction}
	_trigger_abilities_on_gear(gear, GameEnums.TriggerCondition.ON_TICK if direction == "tick" else GameEnums.TriggerCondition.ON_TOCK, context)

func _on_phase_changed(old_phase: Game.GamePhase, new_phase: Game.GamePhase):
	var context = {"old_phase": old_phase, "new_phase": new_phase}
	if new_phase != old_phase:
		_trigger_abilities_global(GameEnums.TriggerCondition.ON_PHASE_START, context)
		_trigger_abilities_global(GameEnums.TriggerCondition.ON_PHASE_END, {"phase": old_phase})

func _on_target_selected(target: Object):
	print("AbilityDispatcher._on_target_selected: ", target)
	if target_selector.is_waiting:
		target_selector.select_target(target)
	else:
		GameLogger.debug("Target selected but no waiting selector, ignoring")

func _on_target_selection_cancelled():
	if target_selector.is_waiting:
		target_selector.cancel_selection()
	else:
		GameLogger.debug("Target selection cancelled but no waiting selector")

func _trigger_abilities_on_gear(gear: Gear, trigger: int, base_context: Dictionary):
	for ability in gear.abilities:
		if ability.trigger == trigger:
			_handle_ability(ability, base_context)

func _trigger_abilities_global(trigger: int, base_context: Dictionary):
	for gear in game_manager.get_board_manager().get_all_gears():
		for ability in gear.abilities:
			if ability.trigger == trigger:
				_handle_ability(ability, base_context)

func _handle_ability(ability: Ability, base_context: Dictionary):
	if ability.target_type != GameEnums.TargetType.NO_TARGET:
		var possible_targets = ability.get_possible_targets(base_context)
		if possible_targets.is_empty():
			GameLogger.debug("Ability %s has no valid targets, skipping" % ability.ability_name)
			return
		if possible_targets.size() == 1 and ability.target_type != GameEnums.TargetType.ANY:
			base_context["target"] = possible_targets[0]
			ability.execute(base_context)
			game_manager.update_ui()  # добавлено
			if target_selector.is_waiting:
				target_selector.cancel_selection()
			else:
				event_bus.target_selection_cancelled.emit()
			return
		target_selector.request_selection(ability, base_context.get("source_gear"), possible_targets, base_context)
	else:
		ability.execute(base_context)
		game_manager.update_ui()  # добавлено (на всякий случай для способностей без цели)
