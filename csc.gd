extends Area2D

enum material_type {
	NEBULITE, GEODINIUM
}

@export var type := material_type.GEODINIUM

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func is_nebulite() -> bool:
	if type == material_type.NEBULITE:
		return true
	else:
		return false
