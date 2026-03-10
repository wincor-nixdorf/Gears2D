# i_event_bus.gd
class_name IEventBus
extends Node

# Сигналы (будут унаследованы реальным классом)
signal phase_changed(old_phase: Game.GamePhase, new_phase: Game.GamePhase)
signal player_changed(active_player_id: int)
signal t_pool_updated(t0: int, t1: int)
signal hand_updated(player_id: int, hand: Array)
signal gear_placed(gear: Gear, cell: Cell)
signal gear_triggered(gear: Gear)
signal gear_destroyed(gear: Gear)
signal gear_rotated(gear: Gear, old_ticks: int, new_ticks: int)
signal gear_clicked(gear: Gear)
signal cell_clicked(cell: Cell)
signal chain_built(chain_graph: Dictionary)
signal chain_resolution_step(gear: Gear)
signal static_effect_registered(source: Node, effect: AbilityEffect)
signal static_effect_unregistered(source: Node, effect: AbilityEffect)
signal target_selection_requested(ability: Ability, source: Gear, possible_targets: Array, context: Dictionary)
signal target_selected(target: Object)
signal target_selection_cancelled()
signal gear_resolved(gear: Gear)

# Методы для эмиссии сигналов (если нужны)
# В реальном классе они не нужны, так как сигналы можно вызывать напрямую
# Но для единообразия можно объявить виртуальные методы
func emit_phase_changed(old_phase, new_phase) -> void:
	push_error("IEventBus.emit_phase_changed() not implemented")

func emit_player_changed(active_player_id) -> void:
	push_error("IEventBus.emit_player_changed() not implemented")

# ... аналогично для всех сигналов (можно не добавлять, если мы будем использовать прямые emit)
