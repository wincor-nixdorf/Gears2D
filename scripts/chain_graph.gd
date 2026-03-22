# chain_graph.gd
class_name ChainGraph
extends RefCounted

# Структура графа: словарь, где ключ - позиция (Vector2i), значение - словарь соседей: соседняя позиция -> ID ребра
var _graph: Dictionary = {}
var _next_edge_id: int = 0

# Добавить вершину (если ещё не существует)
func add_vertex(pos: Vector2i) -> void:
	if not _graph.has(pos):
		_graph[pos] = {}

# Удалить вершину и все связанные рёбра
func remove_vertex(pos: Vector2i) -> void:
	if not _graph.has(pos):
		return
	# Удаляем все рёбра, ведущие к этой вершине, из соседей
	for neighbor in _graph[pos].keys():
		if _graph.has(neighbor):
			_graph[neighbor].erase(pos)
	# Удаляем саму вершину
	_graph.erase(pos)

# Добавить ребро между двумя вершинами, возвращает ID ребра
func add_edge(pos1: Vector2i, pos2: Vector2i) -> int:
	# Проверка ортогональности (только соседи по прямой, не по диагонали)
	if abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) != 1:
		push_error("ChainGraph: Attempted to add non-orthogonal edge between %s and %s" % [pos1, pos2])
		return -1
	
	# Убедимся, что обе вершины существуют
	add_vertex(pos1)
	add_vertex(pos2)
	
	# Проверим, не существует ли уже ребра
	if _graph[pos1].has(pos2):
		return _graph[pos1][pos2]
	
	_next_edge_id += 1
	var edge_id = _next_edge_id
	_graph[pos1][pos2] = edge_id
	_graph[pos2][pos1] = edge_id
	return edge_id

# Удалить ребро между двумя вершинами
func remove_edge(pos1: Vector2i, pos2: Vector2i) -> void:
	if not _graph.has(pos1) or not _graph.has(pos2):
		return
	_graph[pos1].erase(pos2)
	_graph[pos2].erase(pos1)

# Получить всех соседей вершины
func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	if not _graph.has(pos):
		return []
	var neighbors: Array[Vector2i] = []
	for n in _graph[pos].keys():
		neighbors.append(n)
	return neighbors

# Получить ID ребра между двумя вершинами (возвращает -1, если ребра нет)
func get_edge_id(pos1: Vector2i, pos2: Vector2i) -> int:
	if not _graph.has(pos1) or not _graph.has(pos2):
		return -1
	return _graph[pos1].get(pos2, -1)

# Проверить, существует ли вершина
func has_vertex(pos: Vector2i) -> bool:
	return _graph.has(pos)

# Проверить, существует ли ребро
func has_edge(pos1: Vector2i, pos2: Vector2i) -> bool:
	return get_edge_id(pos1, pos2) != -1

# Получить все вершины
func get_vertices() -> Array[Vector2i]:
	var vertices: Array[Vector2i] = []
	for pos in _graph.keys():
		vertices.append(pos)
	return vertices

# Получить размер графа (количество вершин)
func size() -> int:
	return _graph.size()

# Проверить, пуст ли граф
func is_empty() -> bool:
	return _graph.size() == 0

# Получить словарь рёбер из заданной вершины (сосед -> ID ребра)
func get_edges_from(pos: Vector2i) -> Dictionary:
	if not _graph.has(pos):
		return {}
	return _graph[pos].duplicate()

# Очистить граф
func clear() -> void:
	_graph.clear()
	_next_edge_id = 0

# Получить копию внутреннего представления (для сохранения/отладки)
func to_dict() -> Dictionary:
	var copy = {}
	for pos in _graph:
		var neighbors = {}
		for n in _graph[pos]:
			neighbors[n] = _graph[pos][n]
		copy[pos] = neighbors
	return copy

# Загрузить из словаря (для восстановления)
func from_dict(data: Dictionary) -> void:
	_graph.clear()
	_next_edge_id = 0
	for pos_key in data:
		# Восстанавливаем Vector2i из ключа (ключ может быть строкой, если сохраняли в JSON)
		var pos: Vector2i
		if pos_key is String:
			pos = str_to_var(pos_key)
		else:
			pos = pos_key
		_graph[pos] = {}
		for n_key in data[pos_key]:
			var n: Vector2i
			if n_key is String:
				n = str_to_var(n_key)
			else:
				n = n_key
			_graph[pos][n] = data[pos_key][n_key]
			if _graph[pos][n] > _next_edge_id:
				_next_edge_id = _graph[pos][n]
