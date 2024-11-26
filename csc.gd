extends Area2D

enum material_type {
	NEBULITE, GEODINIUM
}

@export var type := material_type.GEODINIUM

func is_nebulite() -> bool:
	if type == material_type.NEBULITE:
		return true
	else:
		return false
