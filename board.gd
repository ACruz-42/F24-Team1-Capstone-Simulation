extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CanvasLayer/Button.pressed.connect(get_tree().reload_current_scene)
