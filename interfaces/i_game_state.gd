# i_game_state.gd
class_name IGameState
extends Node

# Свойства (должны быть реализованы через переменные)
var current_phase: Game.GamePhase:
	get:
		push_error("IGameState.current_phase getter not implemented")
		return Game.GamePhase.CHAIN_BUILDING
	set(value):
		push_error("IGameState.current_phase setter not implemented")

var active_player_id: int:
	get:
		push_error("IGameState.active_player_id getter not implemented")
		return 0
	set(value):
		push_error("IGameState.active_player_id setter not implemented")

var round_number: int:
	get:
		push_error("IGameState.round_number getter not implemented")
		return 1
	set(value):
		push_error("IGameState.round_number setter not implemented")

var start_player_id: int:
	get:
		push_error("IGameState.start_player_id getter not implemented")
		return 0
	set(value):
		push_error("IGameState.start_player_id setter not implemented")

var t_pool: Array[int]:
	get:
		push_error("IGameState.t_pool getter not implemented")
		return [0, 0]
	set(value):
		push_error("IGameState.t_pool setter not implemented")

var passed: bool:
	get:
		push_error("IGameState.passed getter not implemented")
		return false
	set(value):
		push_error("IGameState.passed setter not implemented")

var chain_graph: ChainGraph:
	get:
		push_error("IGameState.chain_graph getter not implemented")
		return null
	set(value):
		push_error("IGameState.chain_graph setter not implemented")

var last_cell_pos: Vector2i:
	get:
		push_error("IGameState.last_cell_pos getter not implemented")
		return Vector2i(-1, -1)
	set(value):
		push_error("IGameState.last_cell_pos setter not implemented")

var last_from_pos: Vector2i:
	get:
		push_error("IGameState.last_from_pos getter not implemented")
		return Vector2i(-1, -1)
	set(value):
		push_error("IGameState.last_from_pos setter not implemented")

var has_placed_this_turn: bool:
	get:
		push_error("IGameState.has_placed_this_turn getter not implemented")
		return false
	set(value):
		push_error("IGameState.has_placed_this_turn setter not implemented")

var moves_in_round: int:
	get:
		push_error("IGameState.moves_in_round getter not implemented")
		return 0
	set(value):
		push_error("IGameState.moves_in_round setter not implemented")

var selected_gear: Gear:
	get:
		push_error("IGameState.selected_gear getter not implemented")
		return null
	set(value):
		push_error("IGameState.selected_gear setter not implemented")

var current_resolve_pos: Vector2i:
	get:
		push_error("IGameState.current_resolve_pos getter not implemented")
		return Vector2i(-1, -1)
	set(value):
		push_error("IGameState.current_resolve_pos setter not implemented")

var came_from_edge: int:
	get:
		push_error("IGameState.came_from_edge getter not implemented")
		return -1
	set(value):
		push_error("IGameState.came_from_edge setter not implemented")

var waiting_for_player: bool:
	get:
		push_error("IGameState.waiting_for_player getter not implemented")
		return false
	set(value):
		push_error("IGameState.waiting_for_player setter not implemented")

var used_abilities_on_gear: Dictionary:
	get:
		push_error("IGameState.used_abilities_on_gear getter not implemented")
		return {}
	set(value):
		push_error("IGameState.used_abilities_on_gear setter not implemented")

var last_active_pos: Vector2i:
	get:
		push_error("IGameState.last_active_pos getter not implemented")
		return Vector2i(-1, -1)
	set(value):
		push_error("IGameState.last_active_pos setter not implemented")

var effect_system: EffectSystem:
	get:
		push_error("IGameState.effect_system getter not implemented")
		return null
	set(value):
		push_error("IGameState.effect_system setter not implemented")

func reset() -> void:
	push_error("IGameState.reset() not implemented")
