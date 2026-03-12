# ui.gd
class_name UI
extends CanvasLayer

signal action_pressed
signal hand_gear_selected(gear: Node2D)

@onready var player_label: Label = %PlayerLabel
@onready var phase_label: Label = %PhaseLabel
@onready var t0_label: Label = %T0Label
@onready var t1_label: Label = %T1Label
@onready var action_button: Button = %ActionButton
@onready var hand_container_player1: HBoxContainer = %HandContainerPlayer1
@onready var hand_container_player2: HBoxContainer = %HandContainerPlayer2
@onready var tooltip_panel: Panel = %TooltipPanel
@onready var tooltip_label: Label = %TooltipLabel
@onready var round_label: Label = %RoundLabel
@onready var chain_length_label: Label = %ChainLengthLabel
@onready var prompt_label: Label = %PromptLabel

# Метки для отображения урона
@onready var damage0_label: Label = %DamagePlayer0Label
@onready var damage1_label: Label = %DamagePlayer1Label

# Кнопки-иконки игроков
@onready var player0_button: Button = %Player0Button
@onready var player1_button: Button = %Player1Button

# Элементы панели логов
@onready var log_panel: Panel = %LogPanel
@onready var log_text: RichTextLabel = %LogText
@onready var filter_debug: CheckBox = %FilterDebug
@onready var filter_info: CheckBox = %FilterInfo
@onready var filter_warning: CheckBox = %FilterWarning
@onready var filter_error: CheckBox = %FilterError
@onready var clear_log_button: Button = %ClearLogButton

@onready var tooltip_icon: TextureRect = %TooltipIcon

# Переменные для выбора цели
var _target_selection_active: bool = false
var _current_possible_targets: Array = []
var _original_colors: Dictionary = {}  # для восстановления подсветки клеток/шестерён/игроков

var game_manager: GameManager  # будет установлен из GameManager

func set_game_manager(gm: GameManager):
	game_manager = gm

func _ready():
	action_button.pressed.connect(_on_action_button_pressed)
	tooltip_panel.hide()
	
	GameLogger.message_logged.connect(_on_log_message)
	clear_log_button.pressed.connect(_on_clear_log)
	filter_debug.button_pressed = true
	filter_info.button_pressed = true
	filter_warning.button_pressed = true
	filter_error.button_pressed = true
	
	# Подключаем сигналы для выбора цели
	EventBus.target_selection_requested.connect(_on_target_selection_requested)
	EventBus.target_selection_cancelled.connect(_on_target_selection_cancelled)
	
	# Подключаем кнопки игроков
	player0_button.pressed.connect(_on_player_button_pressed.bind(0))
	player1_button.pressed.connect(_on_player_button_pressed.bind(1))

func _input(event):
	if not _target_selection_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		EventBus.target_selection_cancelled.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_object = _get_clicked_object()
		if clicked_object and clicked_object in _current_possible_targets:
			EventBus.target_selected.emit(clicked_object)
			_clear_target_selection()
			get_viewport().set_input_as_handled()

func _on_action_button_pressed():
	action_pressed.emit()

func _on_player_button_pressed(player_id: int):
	if not game_manager:
		return
	var player = game_manager.get_players()[player_id]
	if not player:
		return
	# Если активен выбор цели, отправляем сигнал с выбранным игроком
	if _target_selection_active and player in _current_possible_targets:
		EventBus.target_selected.emit(player)
		_clear_target_selection()
	else:
		# Иначе просто эмитим общий сигнал (может быть обработан phase_machine)
		EventBus.player_clicked.emit(player)

func update_player(active_player_id: int):
	player_label.text = "Active Player: " + str(active_player_id + 1)

func update_phase(phase: Game.GamePhase):
	var phase_names = ["Chain Building", "Upturn", "Resolution", "Renewal"]
	phase_label.text = "Phase: " + phase_names[phase]

func update_t_pool(t0: int, t1: int):
	t0_label.text = "T: " + str(t0)
	t1_label.text = "T: " + str(t1)

func update_action_button(phase: Game.GamePhase, placed: bool, active_player_id: int, can_pass: bool):
	match phase:
		Game.GamePhase.CHAIN_BUILDING:
			if placed:
				action_button.text = "End Turn (Player " + str(active_player_id + 1) + ")"
				action_button.disabled = false
			else:
				action_button.text = "Pass"
				action_button.disabled = not can_pass
		Game.GamePhase.UPTURN:
			action_button.text = "End Peek"
			action_button.disabled = false
		Game.GamePhase.CHAIN_RESOLUTION:
			action_button.text = "Skip"
			action_button.disabled = false
		_:
			action_button.text = "Action"
			action_button.disabled = false

func update_round(round: int):
	round_label.text = "Round: " + str(round)

func update_chain_length(length: int):
	chain_length_label.text = "Chain: " + str(length) + " G"

func update_prompt(text: String):
	prompt_label.text = text

func update_damage(damage0: int, damage1: int):
	damage0_label.text = str(damage0) + "/" + str(Game.MAX_DAMAGE)
	damage1_label.text = str(damage1) + "/" + str(Game.MAX_DAMAGE)

func update_hands(hand1: Array, hand2: Array, active_player_id: int):
	for child in hand_container_player1.get_children():
		child.queue_free()
	for child in hand_container_player2.get_children():
		child.queue_free()
	
	fill_hand_container(hand_container_player1, hand1, active_player_id == 0, 0)
	fill_hand_container(hand_container_player2, hand2, active_player_id == 1, 1)

func _get_scaled_texture(texture: Texture2D, target_size: int) -> Texture2D:
	if not texture:
		return null
	var image = texture.get_image()
	if not image:
		return texture
	image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
	
func fill_hand_container(container: HBoxContainer, hand: Array, is_active: bool, player_id: int):
	for gear in hand:
		var button = Button.new()
		var icon_texture = gear.texture_reverse
		if gear.owner_id == player_id:
			icon_texture = gear.texture_obverse
		
		if icon_texture:
			button.icon = _get_scaled_texture(icon_texture, 98)
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var abilities_text = gear.get_abilities_description()
		var text = gear.gear_name + "\n" + "Tocks: " + str(gear.max_tocks) + " Ticks: " + str(gear.max_ticks) + "\n" + abilities_text
		button.text = text
		button.set_meta("gear", gear)
		
		if is_active:
			button.pressed.connect(_on_hand_button_pressed.bind(gear))
			button.mouse_entered.connect(_on_hand_button_mouse_entered.bind(gear))
			button.mouse_exited.connect(_on_hand_button_mouse_exited)
		else:
			button.disabled = true
			button.modulate = Color(0.7, 0.7, 0.7)
		
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.custom_minimum_size = Vector2(220, 120)
		container.add_child(button)

func _on_hand_button_pressed(gear: Node2D):
	hand_gear_selected.emit(gear)

func _on_hand_button_mouse_entered(gear: Gear):
	var icon_texture
	if gear.owner_id == GameState.active_player_id:
		icon_texture = gear.texture_obverse
	else:
		icon_texture = gear.texture_reverse
	tooltip_icon.texture = _get_scaled_texture(icon_texture, 98)
	
	var tooltip_text = gear.get_tooltip_text()
	print("Tooltip text: ", tooltip_text)  # отладка
	print("tooltip_label: ", tooltip_label) # отладка
	if tooltip_label:
		tooltip_label.text = tooltip_text
		tooltip_panel.global_position = _adjust_tooltip_position(get_viewport().get_mouse_position())
		tooltip_panel.show()

func show_gear_tooltip(gear: Gear, mouse_pos: Vector2):
	var icon_texture = gear.sprite.texture
	tooltip_icon.texture = _get_scaled_texture(icon_texture, 98)
	tooltip_label.text = gear.get_tooltip_text()
	tooltip_panel.global_position = _adjust_tooltip_position(mouse_pos)
	tooltip_panel.show()

func _on_hand_button_mouse_exited():
	tooltip_panel.hide()

func highlight_gear(gear: Node2D):
	for button in hand_container_player1.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.YELLOW
			return
	for button in hand_container_player2.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.YELLOW
			return

func unhighlight_gear(gear: Node2D):
	for button in hand_container_player1.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.WHITE if not button.disabled else Color(0.7, 0.7, 0.7)
			return
	for button in hand_container_player2.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.WHITE if not button.disabled else Color(0.7, 0.7, 0.7)
			return

func clear_selection():
	for button in hand_container_player1.get_children():
		if button.disabled:
			button.modulate = Color(0.7, 0.7, 0.7)
		else:
			button.modulate = Color.WHITE
	for button in hand_container_player2.get_children():
		if button.disabled:
			button.modulate = Color(0.7, 0.7, 0.7)
		else:
			button.modulate = Color.WHITE

func hide_gear_tooltip():
	tooltip_panel.hide()

func _adjust_tooltip_position(mouse_pos: Vector2) -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = tooltip_panel.get_combined_minimum_size()
	var offset = Vector2(20, 20)

	var x = mouse_pos.x + offset.x
	var y = mouse_pos.y + offset.y

	if x + panel_size.x > viewport_size.x:
		x = mouse_pos.x - panel_size.x - offset.x
	if x < 0:
		x = 0

	if y + panel_size.y > viewport_size.y:
		y = mouse_pos.y - panel_size.y - offset.y
	if y < 0:
		y = 0

	return Vector2(x, y)

# ----- Логирование на экран -----
func _on_log_message(level: int, message: String, timestamp: Dictionary):
	var should_show = false
	match level:
		0: should_show = filter_debug.button_pressed
		1: should_show = filter_info.button_pressed
		2: should_show = filter_warning.button_pressed
		3: should_show = filter_error.button_pressed
		4: should_show = true
	if not should_show:
		return
	
	var time_str = "%02d:%02d:%02d" % [timestamp.hour, timestamp.minute, timestamp.second]
	var color = _get_color_for_level(level)
	log_text.append_text("[color=%s][%s] %s[/color]\n" % [color, time_str, message])
	log_text.scroll_to_line(log_text.get_line_count() - 1)

func _get_color_for_level(level: int) -> String:
	match level:
		0: return "gray"
		1: return "white"
		2: return "yellow"
		3: return "red"
		4: return "#00FF00"
		_: return "white"

func _on_clear_log():
	log_text.text = ""

# ----- Обработка выбора цели -----
func _on_target_selection_requested(ability: Ability, source: Gear, possible_targets: Array, context: Dictionary):
	if _target_selection_active:
		print("=== UI: target selection already active, ignoring new request for ability ", ability.ability_name)
		return
	print("=== UI: _on_target_selection_requested for ability ", ability.ability_name)
	print("   Possible targets: ", possible_targets)
	_target_selection_active = true
	_current_possible_targets = possible_targets
	
	# Подсвечиваем возможные цели
	_highlight_possible_targets(possible_targets)
	
	# Показываем сообщение игроку с указанием номера игрока, если известен
	if game_manager:
		var player_num = game_manager.game_state.active_player_id + 1
		var prompt_text = "Player %d: Select target for %s" % [player_num, ability.ability_name]
		prompt_label.text = prompt_text
		print("   Setting prompt to: ", prompt_text)  # Отладка
	else:
		prompt_label.text = "Select target for " + ability.ability_name
		print("   game_manager is null, prompt set to: ", prompt_label.text)

func _on_target_selection_cancelled():
	print("=== UI: _on_target_selection_cancelled")
	_clear_target_selection()

func cancel_target_selection():
	if _target_selection_active:
		_clear_target_selection()
		EventBus.target_selection_cancelled.emit()

func _clear_target_selection():
	print("=== UI: _clear_target_selection, target_selection_active was: ", _target_selection_active)
	_target_selection_active = false
	_current_possible_targets.clear()
	_restore_highlights()
	prompt_label.text = ""

func _highlight_possible_targets(targets: Array):
	print("=== UI: _highlight_possible_targets called with targets: ", targets)
	_original_colors.clear()
	for target in targets:
		if target is Cell:
			_original_colors[target] = target.sprite.modulate
			print("   Saving color for cell at ", target.board_pos, ": ", target.sprite.modulate)
			target.sprite.modulate = Color.GREEN
			print("   New color: ", target.sprite.modulate)
		elif target is Gear:
			_original_colors[target] = target.modulate
			print("   Saving color for gear: ", target.gear_name, " at ", target.board_position, ": ", target.modulate)
			target.modulate = Color.GREEN
			print("   New color: ", target.modulate)
		elif target is Player:
			var button = player0_button if target.player_id == 0 else player1_button
			_original_colors[target] = button.modulate
			button.modulate = Color.GREEN
			print("   Highlighting player button for player ", target.player_id)
	print("   _original_colors size: ", _original_colors.size())

func _restore_highlights():
	print("=== UI: _restore_highlights, _original_colors size: ", _original_colors.size())
	for obj in _original_colors:
		var valid = is_instance_valid(obj)
		print("   Object: ", obj, " valid: ", valid)
		if not valid:
			continue
		if obj is Cell:
			print("   Restoring cell at ", obj.board_pos, " to color: ", _original_colors[obj])
			obj.sprite.modulate = _original_colors[obj]
			print("   Actual color after restore: ", obj.sprite.modulate)
		elif obj is Gear:
			print("   Restoring gear: ", obj.gear_name, " to color: ", _original_colors[obj])
			obj.modulate = _original_colors[obj]
			print("   Actual color after restore: ", obj.modulate)
		elif obj is Player:
			var button = player0_button if obj.player_id == 0 else player1_button
			button.modulate = _original_colors[obj]
			print("   Restoring player button for player ", obj.player_id, " to color: ", _original_colors[obj])
	_original_colors.clear()

func _get_clicked_object():
	var viewport = get_viewport()
	if not viewport:
		return null
	var camera = viewport.get_camera_2d()
	if not camera:
		return null
	var space_state = camera.get_viewport().get_world_2d().direct_space_state
	var mouse_pos = viewport.get_mouse_position()
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collision_mask = 1
	var result = space_state.intersect_point(params)
	if result.size() > 0:
		var collider = result[0].collider
		if collider is Cell:
			return collider
		elif collider is Gear:
			return collider
		elif collider.get_parent() is Cell:
			return collider.get_parent()
	return null

func is_target_selection_active() -> bool:
	return _target_selection_active

func is_valid_target(obj: Object) -> bool:
	return obj in _current_possible_targets
