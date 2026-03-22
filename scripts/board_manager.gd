# board_manager.gd
class_name BoardManager
extends RefCounted

var board: Node2D
var cells: Array = []  # двумерный массив клеток
var pulse_tween: Tween

func _init(p_board: Node2D) -> void:
	board = p_board
	cells = board.cells

func get_cell(pos: Vector2i) -> Cell:
	if pos.x < 0 or pos.x >= cells.size() or pos.y < 0 or pos.y >= cells[0].size():
		return null
	return cells[pos.x][pos.y]

func is_cell_empty(pos: Vector2i) -> bool:
	var cell = get_cell(pos)
	return cell == null or cell.is_empty()

func get_gear_at(pos: Vector2i) -> Gear:
	var cell = get_cell(pos)
	if cell:
		return cell.occupied_gear
	return null

func place_gear(gear: Gear, pos: Vector2i) -> bool:
	var cell = get_cell(pos)
	if not cell or not cell.is_empty():
		return false
	cell.set_occupied(gear)
	gear.board_position = pos
	gear.zone = Gear.Zone.BOARD
	return true

func clear_gear(pos: Vector2i) -> void:
	var cell = get_cell(pos)
	if cell and cell.occupied_gear:
		cell.occupied_gear = null

func get_all_cells() -> Array[Cell]:
	var all: Array[Cell] = []
	for row in cells:
		for cell in row:
			all.append(cell)
	return all

func get_all_gears() -> Array[Gear]:
	var gears: Array[Gear] = []
	for row in cells:
		for cell in row:
			if cell.occupied_gear:
				gears.append(cell.occupied_gear)
	return gears

func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var n = pos + d
		if get_cell(n) != null:
			neighbors.append(n)
	return neighbors

func is_white(pos: Vector2i) -> bool:
	return Game.is_cell_white(pos)

func highlight_cells(cells_to_highlight: Array[Cell], color: Color = Color.YELLOW) -> void:
	reset_highlights()
	for cell in cells_to_highlight:
		cell.sprite.modulate = color

func reset_highlights() -> void:
	for row in cells:
		for cell in row:
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)

func set_cell_highlighted(pos: Vector2i, highlighted: bool) -> void:
	var cell = get_cell(pos)
	if cell:
		cell.set_highlighted(highlighted)

func set_cell_active(pos: Vector2i, active: bool) -> void:
	var cell = get_cell(pos)
	if cell:
		cell.set_active(active)

func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	if player == 0:
		return [Vector2i(3,4), Vector2i(4,3)]
	else:
		return [Vector2i(3,3), Vector2i(4,4)]

# ---------- Визуализация цепочки ----------

func update_chain_visuals(chain_graph: ChainGraph, chain_order: Array[Vector2i], phase: Game.GamePhase) -> void:
	_draw_chain_lines(chain_graph)
	_start_chain_pulse(chain_graph)

# Рисует линии между соединёнными клетками (каждое ребро – отдельная линия)
func _draw_chain_lines(graph: ChainGraph) -> void:
	for child in board.get_children():
		if child is Line2D:
			child.queue_free()
	
	var edge_index = 0
	var colors = [Color(1, 0.8, 0.2), Color(0.2, 0.8, 1), Color(0.8, 0.2, 1), Color(0.2, 1, 0.5)]
	
	for pos1 in graph.get_vertices():
		for pos2 in graph.get_neighbors(pos1):
			if pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y < pos2.y):
				if abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) != 1:
					continue
				var cell1 = get_cell(pos1)
				var cell2 = get_cell(pos2)
				if cell1 and cell2:
					var line = Line2D.new()
					line.name = "ChainLine_%d" % edge_index
					line.default_color = colors[edge_index % colors.size()]
					line.width = 3.0
					line.antialiased = true
					line.points = [cell1.global_position, cell2.global_position]
					board.add_child(line)
					
					var glow = Line2D.new()
					glow.name = "ChainLineGlow_%d" % edge_index
					glow.default_color = Color(1, 1, 1, 0.5)
					glow.width = 6.0
					glow.antialiased = true
					glow.points = [cell1.global_position, cell2.global_position]
					board.add_child(glow)
					
					edge_index += 1

func _start_chain_pulse(graph: ChainGraph) -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	
	var chain_positions = graph.get_vertices()
	for pos in chain_positions:
		var cell = get_cell(pos)
		if cell:
			cell.set_pulsing(true)
	
	pulse_tween = board.create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_method(_set_pulse_opacity, 0.3, 0.8, 0.8)
	pulse_tween.tween_method(_set_pulse_opacity, 0.8, 0.3, 0.8)

func _set_pulse_opacity(alpha: float) -> void:
	for row in cells:
		for cell in row:
			if cell.pulse_rect and cell.pulse_rect.visible:
				var style = cell.pulse_rect.get_theme_stylebox("panel")
				if style is StyleBoxFlat:
					style.bg_color.a = alpha * 0.4
					cell.pulse_rect.add_theme_stylebox_override("panel", style)


func stop_chain_pulse() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	for row in cells:
		for cell in row:
			cell.set_pulsing(false)

func clear_chain_visuals() -> void:
	stop_chain_pulse()
	for child in board.get_children():
		if child is Line2D:
			child.queue_free()
