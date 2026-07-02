extends Node2D

var move_speed = 60.0
var direction = Vector2(1, 0)

var is_moving = true
var is_minimized = false
var is_jumping = false
var is_faded_out = false
var is_talking = false

const WALK_ANIM = &"walking"
const IDLE_ANIM = &"idle"
const JUMP_ANIM = &"jump"
const RESUME_DELAY = 3.0
const FADE_OUT_DELAY = 10.0
const FADE_DURATION = 1.0
const TALK_BUTTON_DELAY = 1.0

var window: Window
var tareas: Window
var popup_window: Window
var animated_sprite: AnimatedSprite2D
var menu_button: MenuButton
var status_indicator: StatusIndicator
var text_edit: TextEdit
var okay_button: Button
var resume_timer: Timer
var fade_timer: Timer
var fade_tween: Tween
var talk_timer: Timer

# Dialogue JSON
var dialogues: Array = []

# Task system
var tasks: Array[Dictionary] = []
var task_check_timer: Timer
var task_name_input: LineEdit
var hour_input: SpinBox
var minute_input: SpinBox
var add_task_button: Button
var task_list: VBoxContainer
const TASKS_SAVE_PATH = "user://tasks.json"


func _ready() -> void:
	window = get_window()
	animated_sprite = $AnimatedSprite2D
	menu_button = $MenuButton
	tareas = $Window
	popup_window = $PopupWindow
	status_indicator = $StatusIndicator
	text_edit = $TextEdit
	okay_button = $Button
	
	get_viewport().transparent_bg = true
	window.transparent_bg = true
	window.borderless = true
	window.always_on_top = true
	window.unresizable = false
	
	popup_window.hide()
	popup_window.transient = true
	popup_window.exclusive = false
	popup_window.close_requested.connect(_on_popup_window_close_requested)
	
	status_indicator.pressed.connect(_on_status_indicator_pressed)
	
	text_edit.hide()
	text_edit.editable = false
	okay_button.hide()
	okay_button.pressed.connect(_on_okay_pressed)
	

	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	var target_y = usable_rect.end.y - window.size.y
	window.position = Vector2i(0, target_y)
	
	var popup = menu_button.get_popup()
	popup.id_pressed.connect(_on_menu_item_pressed)
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(WALK_ANIM)
	
	# Resume timer
	resume_timer = Timer.new()
	resume_timer.one_shot = true
	resume_timer.wait_time = RESUME_DELAY
	resume_timer.timeout.connect(_on_resume_timer_timeout)
	add_child(resume_timer)
	
	# Fade timer
	fade_timer = Timer.new()
	fade_timer.one_shot = true
	fade_timer.wait_time = FADE_OUT_DELAY
	fade_timer.timeout.connect(_on_fade_timer_timeout)
	add_child(fade_timer)
	fade_timer.start()
	
	# Talk timer
	talk_timer = Timer.new()
	talk_timer.one_shot = true
	talk_timer.wait_time = TALK_BUTTON_DELAY
	talk_timer.timeout.connect(_on_talk_timer_timeout)
	add_child(talk_timer)
	
	# Load dialogues
	load_dialogues()
	
	# Setup task system
	setup_task_system()


func load_dialogues() -> void:
	var file = FileAccess.open("res://dialogues.json", FileAccess.READ)
	if file == null:
		push_error("Failed to open dialogues.json")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Dictionary and data.has("dialogues"):
		dialogues = data["dialogues"]
	else:
		push_error("Invalid JSON structure: expected {'dialogues': [...]}")


func get_random_dialogue() -> String:
	if dialogues.is_empty():
		return "..."
	var index = randi() % dialogues.size()
	return dialogues[index]


func setup_task_system() -> void:
	task_name_input = popup_window.find_child("TaskNameInput", true, false)
	hour_input = popup_window.find_child("HourInput", true, false)
	minute_input = popup_window.find_child("MinuteInput", true, false)
	add_task_button = popup_window.find_child("AddTaskButton", true, false)
	task_list = popup_window.find_child("TaskList", true, false)
	
	if hour_input:
		hour_input.min_value = 0
		hour_input.max_value = 23
		hour_input.value = 12
	if minute_input:
		minute_input.min_value = 0
		minute_input.max_value = 59
		minute_input.value = 0
	
	if add_task_button:
		add_task_button.pressed.connect(_on_add_task_pressed)
	
	task_check_timer = Timer.new()
	task_check_timer.wait_time = 15.0
	task_check_timer.timeout.connect(_check_tasks)
	add_child(task_check_timer)
	task_check_timer.start()
	
	load_tasks()
	update_task_display()


func _on_add_task_pressed() -> void:
	if task_name_input == null:
		return
	
	var name = task_name_input.text.strip_edges()
	if name.is_empty():
		return
	
	var hour = 12
	var minute = 0
	if hour_input:
		hour = int(hour_input.value)
	if minute_input:
		minute = int(minute_input.value)
	
	add_task(name, hour, minute)
	task_name_input.text = ""


func add_task(name: String, hour: int, minute: int) -> void:
	tasks.append({
		"name": name,
		"hour": hour,
		"minute": minute
	})
	save_tasks()
	update_task_display()


func remove_task(index: int) -> void:
	if index >= 0 and index < tasks.size():
		tasks.remove_at(index)
		save_tasks()
		update_task_display()


func update_task_display() -> void:
	if task_list == null:
		return
	
	for child in task_list.get_children():
		child.queue_free()
	
	for i in range(tasks.size()):
		var task = tasks[i]
		var row = HBoxContainer.new()
		
		var label = Label.new()
		label.text = "%02d:%02d  —  %s" % [task.hour, task.minute, task.name]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.pressed.connect(remove_task.bind(i))
		
		row.add_child(label)
		row.add_child(del_btn)
		task_list.add_child(row)


func _check_tasks() -> void:
	var time = Time.get_time_dict_from_system()
	var current_hour = time.hour
	var current_minute = time.minute
	
	var triggered_indices: Array[int] = []
	
	for i in range(tasks.size()):
		var task = tasks[i]
		if task.hour == current_hour and task.minute == current_minute:
			triggered_indices.append(i)
			alert_task(task.name)
	
	for i in range(triggered_indices.size() - 1, -1, -1):
		tasks.remove_at(triggered_indices[i])
	
	if not triggered_indices.is_empty():
		save_tasks()
		update_task_display()


func alert_task(task_name: String) -> void:
	if is_minimized:
		restore_from_tray()
	if is_faded_out:
		fade_in()
	talk(task_name)


func _on_popup_window_close_requested() -> void:
	popup_window.hide()


func _input(event: InputEvent) -> void:
	if is_talking:
		return
	
	if event is InputEventMouseButton:
		if event.pressed:
			if is_click_on_sprite(event.position):
				if event.button_index == MOUSE_BUTTON_LEFT:
					if not is_talking:
						talk(get_random_dialogue())
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					toggle_movement()


func is_click_on_sprite(mouse_pos: Vector2) -> bool:
	var sprite_pos = animated_sprite.global_position
	var sprite_size: Vector2
	
	var sprite_frames = animated_sprite.sprite_frames
	if sprite_frames != null:
		var current_anim = animated_sprite.animation
		var current_frame = animated_sprite.frame
		var texture = sprite_frames.get_frame_texture(current_anim, current_frame)
		if texture != null:
			sprite_size = texture.get_size()
		else:
			return false
	else:
		return false
	
	if animated_sprite.centered:
		sprite_pos -= sprite_size / 2
	
	var sprite_rect = Rect2(sprite_pos, sprite_size)
	return sprite_rect.has_point(mouse_pos)


func _process(delta):
	if not is_moving or is_minimized or is_talking:
		return
	
	var move_amount = move_speed * delta
	window.position += Vector2i(direction * move_amount)
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	
	if window.position.x + window.size.x > usable_rect.end.x:
		direction.x = -1
		animated_sprite.flip_h = false
	elif window.position.x < usable_rect.position.x:
		direction.x = 1
		animated_sprite.flip_h = true


func toggle_movement() -> void:
	if is_talking:
		return
	
	is_moving = !is_moving
	if is_moving:
		resume_timer.stop()
		if not is_jumping:
			animated_sprite.play(WALK_ANIM)
	else:
		animated_sprite.play(IDLE_ANIM)
		resume_timer.start()


func _on_menu_item_pressed(id: int) -> void:
	if is_talking:
		return
	
	resume_movement()
	
	match id:
		0:
			show_popup_window()
		1:
			play_jump_animation()
		2:
			pass
		3:
			pass


func resume_movement() -> void:
	if not is_moving:
		is_moving = true
		resume_timer.stop()
		if not is_jumping:
			animated_sprite.play(WALK_ANIM)


func _on_resume_timer_timeout() -> void:
	if not is_moving and not is_minimized and not is_jumping and not is_talking:
		is_moving = true
		animated_sprite.play(WALK_ANIM)


func _on_fade_timer_timeout() -> void:
	if not is_faded_out and not is_talking:
		fade_out()


func fade_out() -> void:
	is_faded_out = true
	fade_timer.stop()
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), FADE_DURATION)
	fade_tween.tween_callback(_on_fade_out_complete)


func _on_fade_out_complete() -> void:
	animated_sprite.hide()


func fade_in() -> void:
	if not is_faded_out:
		return
	
	is_faded_out = false
	animated_sprite.show()
	animated_sprite.modulate = Color(1, 1, 1, 0)
	
	fade_timer.start()
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), FADE_DURATION)
	fade_tween.tween_callback(_on_fade_in_complete)


func _on_fade_in_complete() -> void:
	if not is_talking:
		is_moving = true
		animated_sprite.play(WALK_ANIM)


func _on_status_indicator_pressed() -> void:
	# FIX: Handle both independently — restore position first, then fade in
	if is_minimized:
		restore_from_tray()
	if is_faded_out:
		fade_in()


func talk(text: String) -> void:
	is_talking = true
	is_moving = false
	animated_sprite.play(IDLE_ANIM)
	
	resume_timer.stop()
	fade_timer.stop()
	
	text_edit.text = text
	text_edit.show()
	text_edit.editable = false
	
	okay_button.hide()
	talk_timer.start()


func _on_talk_timer_timeout() -> void:
	okay_button.show()


func _on_okay_pressed() -> void:
	text_edit.text = ""
	text_edit.hide()
	text_edit.editable = true
	okay_button.hide()
	
	is_talking = false
	
	fade_timer.start()
	is_moving = true
	animated_sprite.play(WALK_ANIM)


func show_popup_window() -> void:
	popup_window.popup_centered()


func play_jump_animation() -> void:
	is_jumping = true
	resume_timer.stop()
	animated_sprite.play(JUMP_ANIM)


func _on_animation_finished() -> void:
	if is_jumping:
		is_jumping = false
		if is_moving:
			animated_sprite.play(WALK_ANIM)
		else:
			animated_sprite.play(IDLE_ANIM)
			resume_timer.start()


func minimize_to_tray() -> void:
	is_minimized = true
	is_moving = false
	resume_timer.stop()
	fade_timer.stop()
	animated_sprite.pause()
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	window.position = Vector2i(usable_rect.end.x, window.position.y)


func restore_from_tray() -> void:
	is_minimized = false
	is_moving = true
	resume_timer.stop()
	fade_timer.start()
	
	# FIX: Ensure sprite is visible and fully opaque
	animated_sprite.show()
	animated_sprite.modulate = Color(1, 1, 1, 1)
	animated_sprite.play(WALK_ANIM)
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	window.position = Vector2i(usable_rect.end.x - window.size.x, window.position.y)
	
	direction = Vector2(-1, 0)
	animated_sprite.flip_h = false


func save_tasks() -> void:
	var file = FileAccess.open(TASKS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(tasks))
		file.close()


func load_tasks() -> void:
	if not FileAccess.file_exists(TASKS_SAVE_PATH):
		return
	
	var file = FileAccess.open(TASKS_SAVE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			var data = json.get_data()
			if data is Array:
				tasks.assign(data)
