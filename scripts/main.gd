extends Node2D

var move_speed = 60.0
var direction = Vector2(1, 0)

var is_moving = true
var is_minimized = false
var is_jumping = false
var is_faded_out = false  # NEW: tracks if pet is currently invisible

var text_edit: TextEdit
var okay_button: Button
var talk_timer: Timer
var is_talking = false
const TALK_BUTTON_DELAY = 4.0  # seconds before Okay appears

const WALK_ANIM = &"walking"
const IDLE_ANIM = &"idle"
const JUMP_ANIM = &"jump"
const RESUME_DELAY = 3.0
const FADE_OUT_DELAY = 10.0  # NEW: seconds before auto-fade
const FADE_DURATION = 1.0    # NEW: how long the fade takes

var window: Window
var tareas: Window
var popup_window: Window
var animated_sprite: AnimatedSprite2D
var menu_button: MenuButton
var resume_timer: Timer
var fade_timer: Timer       # NEW
var fade_tween: Tween       # NEW: keep reference to kill if needed

var status_indicator: StatusIndicator

func _ready() -> void:
	# ... existing setup ...
	
	text_edit = $TextEdit      # ADD: TextEdit node
	okay_button = $Button      # ADD: Button node ("Okay")
	
	# Configure TextEdit
	text_edit.hide()
	text_edit.editable = false
	
	# Configure Okay button
	okay_button.hide()
	okay_button.pressed.connect(_on_okay_pressed)
	
	# Talk timer (for button delay)
	talk_timer = Timer.new()
	talk_timer.one_shot = true
	talk_timer.wait_time = TALK_BUTTON_DELAY
	talk_timer.timeout.connect(_on_talk_timer_timeout)
	add_child(talk_timer)
	window = get_window()
	animated_sprite = $AnimatedSprite2D
	menu_button = $MenuButton
	tareas = $Window
	popup_window = $PopupWindow
	status_indicator = $StatusIndicator  # NEW
	
	get_viewport().transparent_bg = true
	window.transparent_bg = true
	window.borderless = true
	window.always_on_top = true
	window.unresizable = false
	
	popup_window.hide()
	popup_window.transient = true
	popup_window.exclusive = false
	popup_window.close_requested.connect(_on_popup_window_close_requested)
	
	# NEW: Connect tray icon click
	status_indicator.pressed.connect(_on_status_indicator_pressed)
	
	
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
	
	# NEW: Fade-out timer
	fade_timer = Timer.new()
	fade_timer.one_shot = true
	fade_timer.wait_time = FADE_OUT_DELAY
	fade_timer.timeout.connect(_on_fade_timer_timeout)
	add_child(fade_timer)
	fade_timer.start()  # start counting down immediately


func _on_popup_window_close_requested() -> void:
	popup_window.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			if is_click_on_sprite(event.position):
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
	if not is_moving or is_minimized:
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
	is_moving = !is_moving
	if is_moving:
		resume_timer.stop()
		if not is_jumping:
			animated_sprite.play(WALK_ANIM)
	else:
		animated_sprite.play(IDLE_ANIM)
		resume_timer.start()


func _on_menu_item_pressed(id: int) -> void:
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
	if not is_moving and not is_minimized and not is_jumping:
		is_moving = true
		animated_sprite.play(WALK_ANIM)


# NEW: Fade out after 10 seconds of inactivity
func _on_fade_timer_timeout() -> void:
	if not is_faded_out:
		fade_out()


# NEW: Fade out animation
func fade_out() -> void:
	is_faded_out = true
	fade_timer.stop()
	
	# Kill any existing fade tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), FADE_DURATION)
	fade_tween.tween_callback(_on_fade_out_complete)


# NEW: Called when fade-out finishes — NOW hide the sprite
func _on_fade_out_complete() -> void:
	animated_sprite.hide()
	# Optional: also hide the window borders so only tray icon remains
	# window.hide()


# NEW: Fade in (called from tray icon click)
func fade_in() -> void:
	if not is_faded_out:
		return
	
	is_faded_out = false
	animated_sprite.show()
	animated_sprite.modulate = Color(1, 1, 1, 0)  # start fully transparent
	
	# Reset fade timer since there's activity
	fade_timer.start()
	
	# Kill any existing fade tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), FADE_DURATION)
	fade_tween.tween_callback(_on_fade_in_complete)


# NEW: Called when fade-in finishes
func _on_fade_in_complete() -> void:
	# Resume normal behavior
	if not is_moving and not is_jumping:
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

# Call this to make the pet talk
func talk(text: String) -> void:
	if is_talking:
		return
	
	is_talking = true
	is_moving = false
	animated_sprite.play(IDLE_ANIM)
	
	# Stop other timers
	resume_timer.stop()
	fade_timer.stop()
	
	# Show and configure TextEdit
	text_edit.text = text
	text_edit.show()
	text_edit.editable = false
	
	# Hide Okay button initially, show after delay
	okay_button.hide()
	talk_timer.start()


func _on_talk_timer_timeout() -> void:
	okay_button.show()


func _on_okay_pressed() -> void:
	# Clear text and hide UI
	text_edit.text = ""
	text_edit.hide()
	text_edit.editable = true
	okay_button.hide()
	
	is_talking = false
	
	# Resume normal behavior
	fade_timer.start()
	is_moving = true
	animated_sprite.play(WALK_ANIM)


func minimize_to_tray() -> void:
	is_minimized = true
	is_moving = false
	resume_timer.stop()
	fade_timer.stop()  # NEW: don't fade while minimized
	animated_sprite.pause()
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	window.position = Vector2i(usable_rect.end.x, window.position.y)


func _on_status_indicator_pressed() -> void:
	if is_faded_out:
		fade_in()
	elif is_minimized:
		restore_from_tray()

func restore_from_tray() -> void:
	is_minimized = false
	is_moving = true
	resume_timer.stop()
	fade_timer.start()  # NEW: restart fade countdown
	animated_sprite.play(WALK_ANIM)
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	window.position = Vector2i(usable_rect.end.x - window.size.x, window.position.y)
	
	direction = Vector2(-1, 0)
	animated_sprite.flip_h = false
