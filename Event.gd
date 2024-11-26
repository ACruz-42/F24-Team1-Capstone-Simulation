class_name Event extends RefCounted

signal movement_done()

# Note: ints are faster than floats, but premature optimization is the enemy
# of completion
# Note 2: Export is a prefix that makes debugging easier
@export var rotation_difference:float
@export var desired_distance:float

func _init(rotation:float, distance:float) -> void:
	rotation_difference = rotation
	desired_distance = distance
