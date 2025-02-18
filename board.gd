extends Node2D

# This lets me drag and drop the rover in the editor
@export var rover: CharacterBody2D

# These are defining the areas where the nebulite and geodinium can spawn
@export var outside_area: Area2D
@export var cave_area: Area2D

# These are where the astral material are loaded from
@export var geo_scene: PackedScene 
@export var neb_scene: PackedScene

# How many of each astral material will spawn, and where
var num_geodinium_nodes_outside: int = 6
var num_nebulite_nodes_outside: int = 8
var num_geodinium_nodes_cave: int = 12
var num_nebulite_nodes_cave: int = 8

# Minimum allowed distance between nodes. Does nothing at the moment.
@export var min_distance: float = 50.0 

#
var outside_geodinium_positions: Array = []
var outside_nebulite_positions: Array = []
var cave_geodinium_positions: Array = []
var cave_nebulite_positions: Array =  []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# We assert rover because I keep changing it and forgetting to change it here
	assert(rover)
	$CanvasLayer/Button.pressed.connect(get_tree().reload_current_scene)
	$CanvasLayer/Button2.pressed.connect($Rover.start_state_machine)
	scatter_nodes()



func is_point_inside_any_shape(point: Vector2, area: Area2D) -> bool:
	for child:CollisionShape2D in area.get_children():
		var rect = child.shape.get_rect()
		if rect.has_point(point):
			return true
	return false

func get_random_position_in_area(area: Area2D) -> Vector2:
	var shapes = []
	
	# Collect all CollisionShape2D nodes inside the Area2D
	for child in area.get_children():
		if child is CollisionShape2D and child.shape:
			shapes.append(child)

	var max_attempts = 100
	for i in range(max_attempts):
		var random_shape = shapes.pick_random()
		var rect = random_shape.shape.get_rect()
		# Generate a random position inside this shape's bounding box
		var rand_pos = Vector2(
			randf_range(rect.position.x, rect.position.x + rect.size.x),
			randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
		# Verify that the position is inside any shape in the area
		if is_point_inside_any_shape(rand_pos, area):
			return rand_pos + random_shape.global_position
	return Vector2.ZERO  # Failed to find a valid position

func scatter_nodes():
	# We clear these out, just in case
	cave_geodinium_positions.clear()
	cave_nebulite_positions.clear()
	outside_geodinium_positions.clear()
	outside_nebulite_positions.clear()

# The following 4 for statements instantiate and place the astral material
	for idx: int in range(num_geodinium_nodes_outside):
		var geo_position = get_random_position_in_area(outside_area)
		if geo_position != Vector2.ZERO:
			var node = geo_scene.instantiate()
			node.position = geo_position
			add_child(node)
			outside_geodinium_positions.append(geo_position)
		else:
			print("Wasn't able to place geodinium outside")

	for idx: int in range(num_nebulite_nodes_outside):
		var neb_position = get_random_position_in_area(outside_area)
		if neb_position != Vector2.ZERO:
			var node = neb_scene.instantiate()
			node.position = neb_position
			add_child(node)
			outside_nebulite_positions.append(neb_position)
		else:
			print("Wasn't able to place nebulite outside")
		
	for idx: int in range(num_geodinium_nodes_cave):
		var geo_position = get_random_position_in_area(cave_area)
		if geo_position != Vector2.ZERO:
			var node = geo_scene.instantiate()
			node.position = geo_position
			add_child(node)
			cave_geodinium_positions.append(geo_position)
		else:
			print("Wasn't able to place geodinium cave")

	for idx: int in range(num_nebulite_nodes_cave):
		var neb_position = get_random_position_in_area(cave_area)
		if neb_position != Vector2.ZERO:
			var node = neb_scene.instantiate()
			node.position = neb_position
			add_child(node)
			cave_nebulite_positions.append(neb_position)
		else:
			print("Wasn't able toplace nebulite cave")	
	
	# I'm not a huge fan of tightly coupling like this, but this shouldn't need to
	# be expanded, and if it does, this can maybe be converted to signals
	rover.cave_geodinium = cave_geodinium_positions
	rover.cave_nebulite = cave_nebulite_positions
	rover.outside_geodinium = outside_geodinium_positions
	rover.outside_nebulite = outside_nebulite_positions
