# phase_machine.gd
class_name PhaseMachine
extends RefCounted

var current_phase: Phase
var game_manager: GameManager
var game_state: GameState
var _changing_phase: bool = false

func _init(gm: GameManager, gs: GameState) -> void:
	game_manager = gm
	game_state = gs

# Переключает фазу игры
func change_phase(phase_type: Game.GamePhase) -> void:
	if _changing_phase:
		GameLogger.debug("PhaseMachine: ignoring recursive change_phase to %s" % phase_type)
		return
	_changing_phase = true
	
	GameLogger.debug("PhaseMachine: changing phase to %s (requested) from %s" % [phase_type, _get_phase_name(game_state.current_phase)])
	
	if current_phase:
		game_manager.ui.cancel_target_selection()
		current_phase.exit()
	
	match phase_type:
		Game.GamePhase.UPKEEP:
			current_phase = UpkeepPhase.new(game_manager, game_state)
		Game.GamePhase.DRAW:
			current_phase = DrawPhase.new(game_manager, game_state)
		Game.GamePhase.CHAIN_BUILDING:
			current_phase = ChainBuildingPhase.new(game_manager, game_state)
		Game.GamePhase.SWING_BACK:
			current_phase = SwingBackPhase.new(game_manager, game_state)
		Game.GamePhase.CHAIN_RESOLUTION:
			current_phase = ResolutionPhase.new(game_manager, game_state)
		Game.GamePhase.END:
			current_phase = EndPhase.new(game_manager, game_state)
		Game.GamePhase.CLEANUP:
			current_phase = CleanupPhase.new(game_manager, game_state)
		_:
			push_error("Unknown phase type: ", phase_type)
			_changing_phase = false
			return
	
	current_phase.enter()
	game_state.current_phase = phase_type
	EventBus.phase_changed.emit(-1, phase_type)
	GameLogger.debug("PhaseMachine: signal emitted for phase %s" % _get_phase_name(phase_type))
	GameLogger.debug("PhaseMachine: phase changed to %s (completed)" % _get_phase_name(phase_type))
	_changing_phase = false

func _get_phase_name(phase: Game.GamePhase) -> String:
	match phase:
		Game.GamePhase.UPKEEP:
			return "UPKEEP"
		Game.GamePhase.DRAW:
			return "DRAW"
		Game.GamePhase.CHAIN_BUILDING:
			return "CHAIN_BUILDING"
		Game.GamePhase.SWING_BACK:
			return "SWING_BACK"
		Game.GamePhase.CHAIN_RESOLUTION:
			return "CHAIN_RESOLUTION"
		Game.GamePhase.END:
			return "END"
		Game.GamePhase.CLEANUP:
			return "CLEANUP"
		_:
			return "UNKNOWN"

func handle_cell_clicked(cell: Cell) -> void:
	if current_phase:
		current_phase.handle_cell_clicked(cell)

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	if current_phase:
		current_phase.handle_gear_clicked(gear, button_index)

func handle_player_clicked(player: Player) -> void:
	if current_phase:
		current_phase.handle_player_clicked(player)

func handle_action_button() -> void:
	if current_phase:
		current_phase.handle_action_button()
