extends Node2D

var move_speed = 1
var direction = Vector2(1,0) #moving right

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var window = get_window()
	
	get_viewport().transparent_bg=true
	window.transparent_bg = true
	
	window.borderless = true
	
	window.always_on_top = true
	
	window.unresizable = false



func _process(_delta):
	var window = get_window()
	var move_vector = Vector2i(direction * move_speed)
	
	# apply to the OS window
	window.position += move_vector
	
	# the safezone
	# screen.get_usable_rect() returns screen area MINUS taskbar or docs linux
	var usable_rect = DisplayServer.screen_get_usable_rect()
	
	#if right side of window > right side of screen
	if window.position.x + window.size.x > usable_rect.x:
		direction.x = -1
		$AnimatedSprite2D.flip_h = true

	elif window.position.x < usable_rect.position.x:
		direction.x = 1
		$AnimatedSprite2D.flip_h = false
