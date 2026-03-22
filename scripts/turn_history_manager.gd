# turn_history_manager.gd
class_name TurnHistoryManager
extends RefCounted

var _current_round: TurnHistoryEntry = null
var _current_phase: TurnHistoryEntry = null
var _current_step: TurnHistoryEntry = null
var _history: Array[TurnHistoryEntry] = []
var _game_manager: GameManager
var _game_state: GameState

signal history_updated(root_entries: Array)

func _init(gm: GameManager, gs: GameState) -> void:
	_game_manager = gm
	_game_state = gs
	_connect_signals()
	GameLogger.debug("TurnHistoryManager initialized")

func _connect_signals() -> void:
	if not EventBus:
		GameLogger.error("EventBus is null in TurnHistoryManager")
		return
		
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.player_changed.connect(_on_player_changed)
	EventBus.gear_placed.connect(_on_gear_placed)
	EventBus.gear_triggered.connect(_on_gear_triggered)
	EventBus.gear_destroyed.connect(_on_gear_destroyed)
	EventBus.target_selected.connect(_on_target_selected)
	EventBus.stack_step_started.connect(_on_stack_step_started)
	EventBus.stack_resolved.connect(_on_stack_resolved)

func start_new_round(round_number: int, starter_id: int) -> void:
	GameLogger.debug("TurnHistoryManager: start_new_round called for round %d" % round_number)
	_current_round = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.ROUND,
		"Round %d" % round_number,
		-1,
		starter_id
	)
	_history.append(_current_round)
	_current_phase = null
	_current_step = null
	_emit_full_history()

func _on_phase_changed(old_phase: Game.GamePhase, new_phase: Game.GamePhase) -> void:
	GameLogger.debug("TurnHistoryManager: phase_changed from %d to %d" % [old_phase, new_phase])
	
	var phase_names = {
		Game.GamePhase.UPKEEP: "Upkeep",
		Game.GamePhase.DRAW: "Draw",
		Game.GamePhase.CHAIN_BUILDING: "Chain Building",
		Game.GamePhase.SWING_BACK: "Swing Back",
		Game.GamePhase.CHAIN_RESOLUTION: "Resolution",
		Game.GamePhase.END: "End",
		Game.GamePhase.CLEANUP: "Cleanup"
	}
	
	var phase_entry = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.PHASE,
		phase_names[new_phase],
		_game_state.active_player_id,
		_game_state.priority_player
	)
	
	if _current_round:
		_current_round.add_child(phase_entry)
		GameLogger.debug("Added phase %s to round" % phase_names[new_phase])
	
	_current_phase = phase_entry
	_current_step = null
	_emit_full_history()

func start_step(step_name: String, player_id: int = -1) -> void:
	GameLogger.debug("TurnHistoryManager: start_step %s" % step_name)
	
	if not _current_phase:
		GameLogger.error("start_step called but no current phase! Step '%s' will be lost!" % step_name)
		# НЕ создаём placeholder, просто выходим
		return
		
	var step_entry = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.STEP,
		step_name,
		player_id,
		_game_state.priority_player
	)
	
	_current_phase.add_child(step_entry)
	GameLogger.debug("Added step %s to phase %s" % [step_name, _current_phase.name])
	
	_current_step = step_entry
	_emit_full_history()

func end_step() -> void:
	GameLogger.debug("TurnHistoryManager: end_step")
	_current_step = null
	_emit_full_history()

func add_action(action_name: String, player_id: int, data: Dictionary = {}) -> void:
	print("TurnHistoryManager: add_action - ", action_name)
	
	var action_entry = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.ACTION,
		action_name,
		player_id,
		_game_state.priority_player
	)
	action_entry.data = data
	
	if _current_step:
		_current_step.add_child(action_entry)
		print("Added action to step: ", action_name, " (step: ", _current_step.name, ")")
	elif _current_phase:
		_current_phase.add_child(action_entry)
		print("Added action to phase: ", action_name, " (phase: ", _current_phase.name, ")")
	elif _current_round:
		_current_round.add_child(action_entry)
		print("Added action to round: ", action_name)
	else:
		print("ERROR: No container for action: ", action_name)
	
	_emit_full_history()

func add_trigger(trigger_name: String, source_gear: Gear, data: Dictionary = {}) -> void:
	var trigger_entry = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.TRIGGER,
		trigger_name,
		source_gear.owner_id,
		_game_state.priority_player
	)
	trigger_entry.data = data
	trigger_entry.data["source_gear"] = source_gear.gear_name
	trigger_entry.data["source_pos"] = Game.pos_to_chess(source_gear.board_position)
	
	if _current_step:
		_current_step.add_child(trigger_entry)
	elif _current_phase:
		_current_phase.add_child(trigger_entry)
	
	_emit_full_history()

func _on_player_changed(active_player_id: int) -> void:
	GameLogger.debug("TurnHistoryManager: player_changed to %d" % active_player_id)
	
	# Создаем запись о смене приоритета
	var priority_entry = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.PRIORITY_CHANGE,
		"Priority to Player %d" % (active_player_id + 1),
		active_player_id,
		active_player_id
	)
	
	if _current_step:
		_current_step.add_child(priority_entry)
		GameLogger.debug("Added priority change to step")
	elif _current_phase:
		_current_phase.add_child(priority_entry)
		GameLogger.debug("Added priority change to phase")
	else:
		GameLogger.warning("No container for priority change")
	
	# Также добавляем это как ACTION для наглядности
	var action_entry = TurnHistoryEntry.new(
		TurnHistoryEntry.EntryType.ACTION,
		"Active player changed to Player %d" % (active_player_id + 1),
		active_player_id,
		active_player_id
	)
	
	if _current_step:
		_current_step.add_child(action_entry)
	elif _current_phase:
		_current_phase.add_child(action_entry)
	
	_emit_full_history()

func _on_gear_placed(gear: Gear, cell: Cell) -> void:
	add_action(
		"Place %s" % gear.gear_name,
		gear.owner_id,
		{"position": Game.pos_to_chess(cell.board_pos), "is_new": true}
	)

func _on_gear_triggered(gear: Gear) -> void:
	add_trigger("%s triggered" % gear.gear_name, gear, {"current_ticks": gear.current_ticks})

func _on_gear_destroyed(gear: Gear) -> void:
	add_action(
		"%s destroyed" % gear.gear_name,
		gear.owner_id,
		{"position": Game.pos_to_chess(gear.board_position)}
	)

func _on_target_selected(target: Object) -> void:
	var target_name = ""
	if target is Gear:
		target_name = "%s at %s" % [target.gear_name, Game.pos_to_chess(target.board_position)]
	elif target is Cell:
		target_name = "cell %s" % Game.pos_to_chess(target.board_pos)
	elif target is Player:
		target_name = "Player %d" % (target.player_id + 1)
	
	add_action("Selected target: %s" % target_name, _game_state.active_player_id)

func _on_stack_step_started(entry_data: Dictionary) -> void:
	add_action(
		"Resolving: %s" % entry_data.ability_name,
		entry_data.source_owner_id,
		{"source": entry_data.source_gear_name, "position": Game.pos_to_chess(Vector2i(entry_data.source_pos_x, entry_data.source_pos_y))}
	)

func _on_stack_resolved() -> void:
	add_action("Stack resolved", -1)

func get_history() -> Array[TurnHistoryEntry]:
	return _history

func clear_history() -> void:
	_history.clear()
	_current_round = null
	_current_phase = null
	_current_step = null
	_emit_full_history()

func _emit_full_history() -> void:
	var root_entries = _history.map(func(h): return h.to_dict())
	history_updated.emit(root_entries)

func _count_entries(entries: Array) -> int:
	var count = 0
	for entry in entries:
		count += 1
		count += _count_entries(entry.get("children", []))
	return count
