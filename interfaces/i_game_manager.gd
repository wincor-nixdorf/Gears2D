# i_game_manager.gd
class_name IGameManager
extends Node

# Виртуальные методы (должны быть переопределены)
func get_board_manager() -> BoardManager:
	push_error("IGameManager.get_board_manager() not implemented")
	return null

func get_players() -> Array:
	push_error("IGameManager.get_players() not implemented")
	return []

func update_ui() -> void:
	push_error("IGameManager.update_ui() not implemented")

func proceed_to_next_cell() -> void:
	push_error("IGameManager.proceed_to_next_cell() not implemented")

func restart_chain_resolution() -> void:
	push_error("IGameManager.restart_chain_resolution() not implemented")

func is_ability_used_on_gear(gear: Gear, ability_id: int) -> bool:
	push_error("IGameManager.is_ability_used_on_gear() not implemented")
	return false

func mark_ability_used_on_gear(gear: Gear, ability_id: int) -> void:
	push_error("IGameManager.mark_ability_used_on_gear() not implemented")

func register_static_effect(gear: Gear, ability: Ability) -> void:
	push_error("IGameManager.register_static_effect() not implemented")

func unregister_gear_effects(gear: Gear) -> void:
	push_error("IGameManager.unregister_gear_effects() not implemented")

func end_chain_building() -> void:
	push_error("IGameManager.end_chain_building() not implemented")

func end_upturn() -> void:
	push_error("IGameManager.end_upturn() not implemented")

func end_chain_resolution() -> void:
	push_error("IGameManager.end_chain_resolution() not implemented")

func get_available_cells() -> Array[Cell]:
	push_error("IGameManager.get_available_cells() not implemented")
	return []

func is_valid_start_position(pos: Vector2i) -> bool:
	push_error("IGameManager.is_valid_start_position() not implemented")
	return false

func add_edge(from_pos: Vector2i, to_pos: Vector2i) -> void:
	push_error("IGameManager.add_edge() not implemented")

func on_successful_placement() -> void:
	push_error("IGameManager.on_successful_placement() not implemented")

func can_pass() -> bool:
	push_error("IGameManager.can_pass() not implemented")
	return false

func set_active_cell(pos: Vector2i) -> void:
	push_error("IGameManager.set_active_cell() not implemented")

func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	push_error("IGameManager.get_start_positions_for_player() not implemented")
	return []

func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	push_error("IGameManager.is_adjacent() not implemented")
	return false

func clear_used_abilities() -> void:
	push_error("IGameManager.clear_used_abilities() not implemented")
