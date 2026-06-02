extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var window = get_window()
	
	get_viewport().transparent_bg=true
	window.transparent_bg = true
	
	window.borderless = true
	
	window.always_on_top = true
	
	window.unresizable = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("click"): ###LMB
		is_dragging = true
		drag_offset = get_viewport().get_mouse_position()
	if Input.is_action_just_released("click"): ###As I said
		is_dragging = false
		drag_offset = Vector2.ZERO
	if is_dragging:
		var current_mouse_pos: Vector2 = DisplayServer.mouse_get_position()
		var window_pos: Vector2 = current_mouse_pos - drag_offset
		DisplayServer.window_set_position(window_pos)
