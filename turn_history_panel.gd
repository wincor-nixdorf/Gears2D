# turn_history_panel.gd
class_name TurnHistoryPanel
extends Panel

var history_tree: Tree = null
var clear_button: Button = null
var export_button: Button = null
var close_button: Button = null

var _turn_history_manager: TurnHistoryManager
var _update_pending: bool = false
var _current_scroll_target: TreeItem = null

const COLORS = {
	"ROUND": Color(1.0, 0.8, 0.0, 1.0),
	"PHASE": Color(0.0, 0.8, 0.8, 1.0),
	"STEP": Color(0.6, 0.8, 1.0, 1.0),
	"ACTION": Color(0.4, 0.9, 0.4, 1.0),
	"TRIGGER": Color(1.0, 0.6, 0.2, 1.0),
	"PRIORITY_CHANGE": Color(0.9, 0.5, 1.0, 1.0)
}

var _icons: Dictionary = {}
var _icon_size: int = 24

func _ready() -> void:
	_load_icons()
	_setup_panel_style()
	visible = false

func _load_icons() -> void:
	var icon_paths = {
		"ROUND": "res://assets/icons/round_icon.png",
		"PHASE": "res://assets/icons/phase_icon.png",
		"STEP": "res://assets/icons/step_icon.png",
		"ACTION": "res://assets/icons/action_icon.png",
		"TRIGGER": "res://assets/icons/trigger_icon.png",
		"PRIORITY_CHANGE": "res://assets/icons/priority_icon.png"
	}
	
	for type_name in icon_paths:
		var original_texture = load(icon_paths[type_name])
		if original_texture:
			_icons[type_name] = _resize_texture(original_texture, _icon_size)

func _resize_texture(texture: Texture2D, target_size: int) -> Texture2D:
	if not texture:
		return null
	var image = texture.get_image()
	if not image:
		return texture
	image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _setup_panel_style() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.22, 0.28, 0.95)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.5, 0.6, 0.9, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel_style)

func setup(history_manager: TurnHistoryManager) -> void:
	_turn_history_manager = history_manager
	_turn_history_manager.history_updated.connect(_on_history_updated)
	
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
		_style_button(clear_button)
		
	if export_button:
		export_button.pressed.connect(_on_export_pressed)
		_style_button(export_button)
		
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		_style_button(close_button)
	
	_setup_tree()
	
	await get_tree().process_frame
	if history_tree:
		history_tree.size = size
	
	visible = true

func _style_button(button: Button) -> void:
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.35, 0.45, 0.65, 1.0)
	button_style.border_width_left = 1
	button_style.border_width_right = 1
	button_style.border_width_top = 1
	button_style.border_width_bottom = 1
	button_style.border_color = Color(0.7, 0.8, 1.0, 1.0)
	button_style.corner_radius_top_left = 4
	button_style.corner_radius_top_right = 4
	button_style.corner_radius_bottom_left = 4
	button_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", button_style)
	
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.45, 0.55, 0.75, 1.0)
	button.add_theme_stylebox_override("hover", hover_style)
	
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _setup_tree() -> void:
	if not history_tree:
		return
		
	history_tree.columns = 3
	history_tree.set_column_title(0, "")
	history_tree.set_column_title(1, "Entry")
	history_tree.set_column_title(2, "Priority")
	history_tree.set_column_expand(0, false)
	history_tree.set_column_expand(1, true)
	history_tree.set_column_expand(2, false)
	
	history_tree.set_column_custom_minimum_width(0, _icon_size + 8)
	history_tree.set_column_custom_minimum_width(2, 70)
	
	history_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	history_tree.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	history_tree.add_theme_color_override("font_selected_color", Color(1, 1, 0.5, 1))
	history_tree.add_theme_color_override("guide_color", Color(0.6, 0.6, 0.7, 1))
	history_tree.add_theme_font_size_override("font_size", 13)
	
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.3, 0.35, 0.45, 1.0)
	header_style.border_width_bottom = 1
	header_style.border_color = Color(0.5, 0.6, 0.8, 1.0)
	history_tree.add_theme_stylebox_override("header", header_style)
	history_tree.add_theme_color_override("header_font_color", Color(1, 1, 1, 1))
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	history_tree.add_theme_stylebox_override("bg", bg_style)
	
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.3, 0.4, 0.6, 0.8)
	history_tree.add_theme_stylebox_override("selected", selected_style)
	history_tree.add_theme_stylebox_override("selected_focus", selected_style)
	
	var scroll_container = history_tree.get_parent()
	if scroll_container and scroll_container is ScrollContainer:
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	history_tree.item_activated.connect(_on_item_activated)

func _on_history_updated(root_entries: Array) -> void:
	if not history_tree or _update_pending:
		return
	_update_pending = true
	
	history_tree.clear()
	var root = history_tree.create_item()
	
	if root:
		for entry_dict in root_entries:
			_add_entry_to_tree(root, entry_dict)
		_find_and_expand_current_path(root)
		call_deferred("_scroll_to_bottom")
	
	_update_pending = false

func _find_and_expand_current_path(item: TreeItem) -> bool:
	if not item or not is_instance_valid(item):
		return false
	
	var entry_data = item.get_metadata(0)
	if not entry_data:
		return false
	
	var entry_name = entry_data.get("name", "")
	var entry_type = entry_data.get("type", -1)
	
	var current_step_name = ""
	if _turn_history_manager and _turn_history_manager._current_step:
		current_step_name = _turn_history_manager._current_step.name
	
	var is_current_step = false
	if entry_type == TurnHistoryEntry.EntryType.STEP and current_step_name != "":
		if entry_name == current_step_name:
			is_current_step = true
	
	var is_current_phase = false
	if _turn_history_manager and _turn_history_manager._current_phase:
		if entry_type == TurnHistoryEntry.EntryType.PHASE and entry_name == _turn_history_manager._current_phase.name:
			is_current_phase = true
	
	var child = item.get_first_child()
	var has_active_child = false
	while child and is_instance_valid(child):
		if _find_and_expand_current_path(child):
			has_active_child = true
		child = child.get_next()
	
	if not is_instance_valid(item):
		return false
	
	if is_current_step or is_current_phase or has_active_child:
		item.set_collapsed(false)
		if is_current_step:
			_current_scroll_target = item
		return true
	else:
		item.set_collapsed(true)
		return false

func _scroll_to_bottom() -> void:
	if not history_tree or not is_instance_valid(history_tree):
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(history_tree):
		return
	
	if _current_scroll_target and is_instance_valid(_current_scroll_target):
		_expand_parents(_current_scroll_target)
		await get_tree().process_frame
		
		if is_instance_valid(_current_scroll_target) and is_instance_valid(history_tree):
			history_tree.scroll_to_item(_current_scroll_target)
			if is_instance_valid(_current_scroll_target):
				_current_scroll_target.select(0)
	elif history_tree.get_root() and is_instance_valid(history_tree.get_root()):
		if history_tree.get_root().get_child_count() > 0:
			var last_step = _find_last_step(history_tree.get_root())
			if last_step and is_instance_valid(last_step):
				_expand_parents(last_step)
				await get_tree().process_frame
				
				if is_instance_valid(last_step) and is_instance_valid(history_tree):
					history_tree.scroll_to_item(last_step)
					if is_instance_valid(last_step):
						last_step.select(0)

func _expand_parents(item: TreeItem) -> void:
	if not item or not is_instance_valid(item):
		return
	var parent = item.get_parent()
	while parent and is_instance_valid(parent):
		parent.set_collapsed(false)
		parent = parent.get_parent()

func _find_last_step(item: TreeItem) -> TreeItem:
	if not item or not is_instance_valid(item):
		return null
	
	var last_step: TreeItem = null
	var child = item.get_first_child()
	while child and is_instance_valid(child):
		var candidate = _find_last_step(child)
		if candidate and is_instance_valid(candidate):
			last_step = candidate
		child = child.get_next()
	
	if not is_instance_valid(item):
		return last_step
	
	var entry_data = item.get_metadata(0)
	if entry_data and entry_data.get("type", -1) == TurnHistoryEntry.EntryType.STEP:
		if not last_step:
			last_step = item
		elif is_instance_valid(last_step):
			var last_time = last_step.get_metadata(0).get("timestamp", 0) if last_step.get_metadata(0) else 0
			var current_time = entry_data.get("timestamp", 0)
			if current_time > last_time:
				last_step = item
	
	return last_step

func _add_entry_to_tree(parent: TreeItem, entry_dict: Dictionary) -> TreeItem:
	if not parent or not history_tree:
		return null
		
	var item = history_tree.create_item(parent)
	item.set_metadata(0, entry_dict)
	
	var type_val = entry_dict.get("type", 0)
	var type_name = TurnHistoryEntry.EntryType.keys()[type_val] if type_val < TurnHistoryEntry.EntryType.keys().size() else "UNKNOWN"
	
	if _icons.has(type_name) and _icons[type_name]:
		item.set_icon(0, _icons[type_name])
	
	var text = entry_dict.get("name", "Unknown")
	var player_id = entry_dict.get("player_id", -1)
	if player_id != -1:
		text += " [P%d]" % (player_id + 1)
	item.set_text(1, text)
	
	var priority_player = entry_dict.get("priority_player", -1)
	if priority_player != -1:
		item.set_text(2, "P%d" % (priority_player + 1))
		if priority_player == player_id:
			item.set_custom_color(1, Color(1, 0.8, 0.2, 1))
	
	var text_color = COLORS.get(type_name, Color(0.8, 0.8, 0.8, 1.0))
	item.set_custom_color(0, text_color)
	item.set_custom_color(1, text_color)
	
	for child_dict in entry_dict.get("children", []):
		_add_entry_to_tree(item, child_dict)
	
	return item

func _on_item_activated() -> void:
	var selected = history_tree.get_selected()
	if selected and selected.get_metadata(0):
		_show_entry_details(selected.get_metadata(0))

func _show_entry_details(entry_data: Dictionary) -> void:
	var details_panel = Panel.new()
	details_panel.size = Vector2(450, 350)
	details_panel.position = (get_viewport_rect().size - details_panel.size) / 2
	details_panel.z_index = 200
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.17, 0.22, 0.98)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.5, 0.6, 0.9, 1.0)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	details_panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	details_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = entry_data.get("name", "Unknown")
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.4, 1.0))
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var details_label = Label.new()
	details_label.text = _format_entry_details(entry_data)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	scroll.add_child(details_label)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	_style_button(close_btn)
	close_btn.pressed.connect(details_panel.queue_free)
	vbox.add_child(close_btn)
	
	add_child(details_panel)

func _format_entry_details(entry_data: Dictionary) -> String:
	var type_val = entry_data.get("type", 0)
	var type_name = TurnHistoryEntry.EntryType.keys()[type_val] if type_val < TurnHistoryEntry.EntryType.keys().size() else "UNKNOWN"
	
	var text = ""
	text += "Type: %s\n" % type_name
	text += "Time: %.2f seconds\n" % entry_data.get("timestamp", 0.0)
	
	var player_id = entry_data.get("player_id", -1)
	if player_id != -1:
		text += "Player: %d\n" % (player_id + 1)
	
	var priority_player = entry_data.get("priority_player", -1)
	if priority_player != -1:
		text += "Priority: Player %d\n" % (priority_player + 1)
	
	var data = entry_data.get("data", {})
	if not data.is_empty():
		text += "\n--- Additional Data ---\n"
		for key in data:
			text += "  %s: %s\n" % [key.capitalize(), data[key]]
	
	var children = entry_data.get("children", [])
	if children.size() > 0:
		text += "\n--- Children (%d) ---\n" % children.size()
		for child in children:
			text += "  • %s\n" % child.get("name", "Unknown")
	
	return text

func _on_clear_pressed() -> void:
	if _turn_history_manager:
		_turn_history_manager.clear_history()

func _on_export_pressed() -> void:
	if not _turn_history_manager:
		return
	
	var history_data = []
	for entry in _turn_history_manager.get_history():
		history_data.append(entry.to_dict())
	
	var json_string = JSON.stringify(history_data, "\t")
	var file_name = "game_history_%d.json" % Time.get_unix_time_from_system()
	var file_path = "user://" + file_name
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		var full_path = OS.get_user_data_dir() + "/" + file_name
		_show_notification("History exported to:\n%s" % full_path)

func _on_close_pressed() -> void:
	visible = false

func _show_notification(message: String) -> void:
	var notification = AcceptDialog.new()
	notification.dialog_text = message
	notification.popup_centered()
	add_child(notification)
