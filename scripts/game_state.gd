# game_state.gd
class_name GameState
extends RefCounted

var effect_system: EffectSystem = EffectSystem.new()

var current_phase: Game.GamePhase = Game.GamePhase.CHAIN_BUILDING
var active_player_id: int = 0
var round_number: int = 1
var start_player_id: int = 0
var t_pool: Array[int] = [0, 0]
var passed: bool = false
var consecutive_passes: int = 0           # Количество последовательных пасов
var priority_player: int = -1             # Игрок, у которого сейчас приоритет (-1 = никто)

# -------------------- Построение цепочки --------------------
var chain_graph: ChainGraph = ChainGraph.new()
var chain_order: Array[Vector2i] = []
var last_cell_pos: Vector2i = Vector2i(-1, -1)
var last_from_pos: Vector2i = Vector2i(-1, -1)
var has_placed_this_turn: bool = false
var moves_in_round: int = 0
var selected_gear: Gear = null
var selected_creature: Gear = null

var selected_interrupt_gear: Gear = null
var interrupt_played: bool = false
var interrupt_pos: Vector2i = Vector2i(-1, -1)
var interrupt_player: int = -1

# -------------------- Разрешение цепочки --------------------
var current_resolve_pos: Vector2i = Vector2i(-1, -1)
var came_from_edge: int = -1
var waiting_for_player: bool = false

# -------------------- Способности и эффекты --------------------
var used_abilities_on_gear: Dictionary = {}

# -------------------- Подсветка активной клетки --------------------
var last_active_pos: Vector2i = Vector2i(-1, -1)

# -------------------- TUNING reset --------------------
var tuning_to_reset: Array[Gear] = []

func reset():
	effect_system.clear()
	current_phase = Game.GamePhase.CHAIN_BUILDING
	active_player_id = 0
	round_number = 1
	start_player_id = 0
	t_pool = [0, 0]
	passed = false
	consecutive_passes = 0
	priority_player = -1
	chain_graph.clear()
	chain_order.clear()
	last_cell_pos = Vector2i(-1, -1)
	last_from_pos = Vector2i(-1, -1)
	has_placed_this_turn = false
	moves_in_round = 0
	selected_gear = null
	selected_creature = null
	current_resolve_pos = Vector2i(-1, -1)
	came_from_edge = -1
	waiting_for_player = false
	used_abilities_on_gear.clear()
	last_active_pos = Vector2i(-1, -1)
	tuning_to_reset.clear()
