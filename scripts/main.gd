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



func _process(delta: float) -> void:
	pass
