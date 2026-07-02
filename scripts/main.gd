extends Node2D

var move_speed = 60.0
var direction = Vector2(1, 0)

var is_moving = true
var is_minimized = false
var is_jumping = false

const WALK_ANIM = &"walking"
const IDLE_ANIM = &"idle"
const JUMP_ANIM = &"jump"
const RESUME_DELAY = 3.0  # seconds to wait before auto-resuming

var window: Window
var tareas: Window
var popup_window: Window
var animated_sprite: AnimatedSprite2D
var menu_button: MenuButton
var resume_timer: Timer  # NEW


func _ready() -> void:
	window = get_window()
	animated_sprite = $AnimatedSprite2D
	menu_button = $MenuButton
	tareas = $Window
	popup_window = $PopupWindow
	
	get_viewport().transparent_bg = true
	window.transparent_bg = true
	window.borderless = true
	window.always_on_top = true
	window.unresizable = false
	
	popup_window.hide()
	popup_window.transient = true
	popup_window.exclusive = false
	popup_window.close_requested.connect(_on_popup_window_close_requested)
	
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	var target_y = usable_rect.end.y - window.size.y
	window.position = Vector2i(0, target_y)
	
	var popup = menu_button.get_popup()
	popup.id_pressed.connect(_on_menu_item_pressed)
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(WALK_ANIM)
	
	# NEW: Create resume timer
	resume_timer = Timer.new()
	resume_timer.one_shot = true
	resume_timer.wait_time = RESUME_DELAY
	resume_timer.timeout.connect(_on_resume_timer_timeout)
	add_child(resume_timer)


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
		resume_timer.stop()  # NEW: cancel auto-resume if manually resumed
		if not is_jumping:
			animated_sprite.play(WALK_ANIM)
	else:
		animated_sprite.play(IDLE_ANIM)
		resume_timer.start()  # NEW: start countdown to auto-resume


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
		resume_timer.stop()  # NEW: cancel auto-resume if menu resumes movement
		if not is_jumping:
			animated_sprite.play(WALK_ANIM)


# NEW: Auto-resume after delay
func _on_resume_timer_timeout() -> void:
	if not is_moving and not is_minimized and not is_jumping:
		is_moving = true
		animated_sprite.play(WALK_ANIM)


func show_popup_window() -> void:
	popup_window.popup_centered()


func play_jump_animation() -> void:
	is_jumping = true
	resume_timer.stop()  # NEW: don't auto-resume during jump
	animated_sprite.play(JUMP_ANIM)


func _on_animation_finished() -> void:
	if is_jumping:
		is_jumping = false
		if is_moving:
			animated_sprite.play(WALK_ANIM)
		else:
			animated_sprite.play(IDLE_ANIM)
			resume_timer.start()  # NEW: restart timer if still stopped after jump


func minimize_to_tray() -> void:
	is_minimized = true
	is_moving = false
	resume_timer.stop()  # NEW: stop timer when minimized
	animated_sprite.pause()
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	window.position = Vector2i(usable_rect.end.x, window.position.y)


func restore_from_tray() -> void:
	is_minimized = false
	is_moving = true
	resume_timer.stop()  # NEW: stop timer when restored
	animated_sprite.play(WALK_ANIM)
	
	var usable_rect = DisplayServer.screen_get_usable_rect()
	window.position = Vector2i(usable_rect.end.x - window.size.x, window.position.y)
	
	direction = Vector2(-1, 0)
	animated_sprite.flip_h = false
