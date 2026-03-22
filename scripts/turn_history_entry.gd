# turn_history_entry.gd
class_name TurnHistoryEntry
extends RefCounted

enum EntryType {
	ROUND,
	PHASE,
	STEP,
	ACTION,
	TRIGGER,
	PRIORITY_CHANGE
}

var type: EntryType
var name: String
var timestamp: float
var player_id: int = -1  # -1 = никто/система
var priority_player: int = -1  # кто имеет приоритет в этот момент
var children: Array[TurnHistoryEntry] = []
var parent: TurnHistoryEntry = null
var data: Dictionary = {}  # дополнительные данные (координаты, способность и т.д.)

func _init(p_type: EntryType, p_name: String, p_player: int = -1, p_priority: int = -1) -> void:
	type = p_type
	name = p_name
	player_id = p_player
	priority_player = p_priority
	timestamp = Time.get_ticks_msec() / 1000.0

func add_child(child: TurnHistoryEntry) -> void:
	child.parent = self
	children.append(child)

func to_dict() -> Dictionary:
	return {
		"type": type,
		"name": name,
		"timestamp": timestamp,
		"player_id": player_id,
		"priority_player": priority_player,
		"children": children.map(func(c): return c.to_dict()),  # Важно!
		"data": data
	}
