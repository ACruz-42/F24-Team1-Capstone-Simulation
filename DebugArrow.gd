extends Node2D

@export var start_position: Vector2 = Vector2.ZERO
@export var length: float = 100.0
@export var angle_degrees: float = 0.0

@onready var arrow_line = $ArrowLine
@onready var arrow_head = $ArrowLine/ArrowHead

func _ready():
	draw_arrow()

func draw_arrow():
	angle_degrees -= 90
	var end_position = start_position + Vector2(length, 0).rotated(deg_to_rad(angle_degrees))

	# Draw main line
	arrow_line.points = PackedVector2Array([start_position, end_position])

	# Position arrowhead
	arrow_head.position = end_position
	arrow_head.rotation_degrees = angle_degrees
