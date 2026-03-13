# event_bus.gd
extends Node

# Сигналы основных игровых событий
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
signal gear_resolved(gear: Gear, was_face_up: bool)
signal player_icon_clicked(player_id: int)
signal target_selection_started()

# Сигналы для стека эффектов
signal stack_updated(stack_snapshot: Array)           # массив словарей с данными о стеке
signal stack_step_started(entry_data: Dictionary)     # данные текущего выполняемого элемента
signal stack_step_finished(entry_data: Dictionary)    # данные завершённого элемента
signal stack_resolved()                                # стек полностью разрешён
