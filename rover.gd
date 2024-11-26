extends CharacterBody2D
## This is a class that controls the internal workings of the simulated rover
# Note: Items that are suffixed with _ are intended to be Godot abstractions
# 	for some function that is not possible to simulate at this moment.
#	i.e., there are no physical motors so move_forward_ is treated as a placeholder
#	Additionally, it is GDScript convention to prefix internal functions with an underscore

# Note: @onready is a Godot keyword that assigns a variable after the 
#		the node is finished loading. Otherwise, the StateMachine component
#		wouldn't be done loading while we attempt to reference it
@onready var state_machine = $StateMachine


# Note: @export is a Godot keyword that lets you change a variable easily.
#		Thus, the values below can be treated as defaults, instead of the actual value
@export var MAX_FORWARD_SPEED = 42*30
@export var MAX_BACKWARD_SPEED = 42*30
@export var MAX_ROTATIONAL_SPEED = 10*30

# Note: A Vector2 in Godot is a pair of numeric values, not a mathematical vector
var internal_position: Vector2
var internal_rotation: float
var grid_array: Array[Array]

# These simulate the data the LIDAR sensors on the sides of the robot will provide
var left_distance_LIDAR: float
var right_distance_LIDAR: float
var back_distance_LIDAR: float

# The final event queue will likely be more sophisticated, but 
# there's no real way for me to simulate it, without just doing it in python
var event_queue: Array
var current_event: StateMachine.Transform

# These simulate the arduino operating the drivetrain, purely placeholder
var move_duration: float = 0.0
var elapsed_move_time: float = 0.0
var move_speed: int = 0
var is_moving: bool = false

var rotation_duration: float = 0.0
var elapsed_rotation_time: float = 0.0
var rotation_speed: float = 0.0
var is_rotating: bool = false

# Is the Nebulite container attached?
var ncsc_attached:bool = false:
	set(attached):
		$"Nebulite CSC".visible = attached
		$NCSCCollider.set_deferred("disabled", not attached)
		ncsc_attached = attached
		
var gcsc_attached:bool = false:
	set(attached):
		$"Geodinium CSC".visible = attached
		$GCSCCollider.set_deferred("disabled", not attached)
		gcsc_attached = attached

# How many nebulite do we have?
var nebulite_count:int = 0:
	set(new_count):
		_update_count_label_($"Nebulite CSC/Material Count", new_count)
		nebulite_count = new_count
		
var geodinium_count:int = 0:
	set(new_count):
		_update_count_label_($"Geodinium CSC/Material Count", new_count)
		geodinium_count = new_count

func _ready() -> void:
	# We cheat a little for debugging purposes and set our internal position
	# to the right one. We should always start in the same position, so this is fine
	internal_position = position
	$roller.area_entered.connect(pick_up_material_)
	$"Geodinium CSC/Collision".area_entered.connect(pick_up_CSC)
	$"Nebulite CSC/Collision".area_entered.connect(pick_up_CSC)
	state_machine.send_event.connect(add_event)
	for i:int in range(16):
		var inner_array: Array
		if i == 0 or i == 15:
			inner_array.resize(32)
			inner_array.fill(0)
		else:
			inner_array.resize(32)
			inner_array.fill(2)
			inner_array[0] = 0
			inner_array[31] = 0
		grid_array.append(inner_array)
	#var starting_position = Godot_to_AStar_Position(Vector2(960,1242))
	#var ending_position =  Godot_to_AStar_Position(Vector2(2379,1085))
#
	#var time_start = Time.get_unix_time_from_system()
	#var path = a_star(starting_position, ending_position, grid_array)
	#var time_end = Time.get_unix_time_from_system()
	#print("Time Elapsed: ", str(time_end-time_start))
	#print(path)
	#for i in path:
		#grid_array[i.y][i.x] = 9
		#for j in grid_array:
			#print(j)
		#print()
	#var test_event = StateMachine.Transform.new(Vector3(200,200,0),false,false)
	#var second_event = StateMachine.Transform.new(Vector3(200,200,180),false,false)
	#var third_event = StateMachine.Transform.new(Vector3(0,0,180),false,false)
	#add_event(test_event)
	#add_event(second_event)
	#add_event(third_event)
	
func start() -> void:
	state_machine.start()


func _physics_process(delta_: float) -> void :
	# continue processing event queue
	if is_rotating:
		# Run the movement function
		rotate_(delta_, rotation_speed, 1)

		# Update elapsed time
		elapsed_rotation_time += delta_
		internal_rotation += delta_*rotation_speed

		# Stop moving after the duration
		if elapsed_rotation_time >= rotation_duration or \
		   is_equal_approx(elapsed_rotation_time, rotation_duration):
			is_rotating = false
	# continue processing event queue
	elif is_moving:
		# Run the movement function
		if move_speed > 0:
			move_forward_(delta_, move_speed)
		else:
			move_backward_(delta_, -move_speed)

		# Update elapsed time
		elapsed_move_time += delta_
		#internal_position = position
		internal_position.x += sin(deg_to_rad(internal_rotation)) * delta_*move_speed
		internal_position.y -= cos(deg_to_rad(internal_rotation)) * delta_*move_speed

	
		# Stop moving after the duration. Accounts for floating point
		if elapsed_move_time >= move_duration or \
		   is_equal_approx(elapsed_move_time, move_duration):
			is_moving = false
	else:
		# We put this here, because an event can have a rotation
		# and distance
		if current_event:
			
			current_event.position_reached.emit()
			current_event = null
		if not event_queue.is_empty():
			parse_event()
		
		# For debugging purposes:
		if Input.is_action_pressed("move_forward"):
			move_forward_(delta_, MAX_FORWARD_SPEED)
		
		# For debugging purposes:
		if Input.is_action_pressed("move_back"):
			move_backward_(delta_,500)

		# For debugging purposes:
		# Note: Input.get_axis returns a normalized Vector2 in the x or -x direction
		var direction = Input.get_axis("rotate_left", "rotate_right")
		if direction:
			rotate_(delta_, MAX_ROTATIONAL_SPEED, direction)
	
	
## This function is an abstraction for sending data to the arduino
func send_distance_to_arduino_(desired_distance: float) -> void:
	if desired_distance > 0:
		move_speed = MAX_FORWARD_SPEED
	else:
		move_speed = -MAX_BACKWARD_SPEED
	move_duration = desired_distance / move_speed
	elapsed_move_time = 0.0
	is_moving = true


## This function is an abstraction for sending data to the arduino
func send_rotation_to_arduino_(desired_rotation: float) -> void:
	if desired_rotation > 0:
		rotation_speed = MAX_ROTATIONAL_SPEED
	else:
		rotation_speed = -MAX_ROTATIONAL_SPEED
	rotation_duration = abs(desired_rotation / MAX_ROTATIONAL_SPEED)
	elapsed_rotation_time = 0.0
	is_rotating = true
	
#region Godot Stuff
## Handle forward movement, given speed.
func move_forward_(delta_: float, speed:int) -> void:
	# Note: We multiply by delta because 1 second = 1 physics tick * delta, and 
	# 		_physics_process happens once each physics tick.
	# Note: move_and_collide is a self-descriptive internal function
	if speed > MAX_FORWARD_SPEED: # Checking we're not going over the max speed
		var max_speed = delta_*MAX_FORWARD_SPEED*Vector2(0,-1).rotated(rotation)
		move_and_collide(max_speed)
	else:
		var desired_speed = delta_*speed*Vector2(0,-1).rotated(rotation)
		move_and_collide(desired_speed)


## Handle backwards movement, given speed.
func move_backward_(delta_: float, speed:float) -> void:
	# Note: See move_forward_
	if speed > MAX_BACKWARD_SPEED:
		var max_speed = delta_*MAX_BACKWARD_SPEED*Vector2(0,1).rotated(rotation)
		move_and_collide(max_speed)
	else:
		var desired_speed = delta_*speed*Vector2(0,1).rotated(rotation)
		move_and_collide(desired_speed)


## Handle rotation, given the desired speed and direction
func rotate_(delta_: float, speed:float, direction: float) -> void:
	var clamped_speed = clampf(speed, -MAX_ROTATIONAL_SPEED, MAX_ROTATIONAL_SPEED)
	rotation_degrees += (delta_ * clamped_speed * direction)


## This is called when the roller Area2D interacts with another Area2D on the same
## collision layer (this should just be astral material)
# Note: This is a slight abstraction of what's likely to be the real function,
# 		so I decided to give it an _ suffix.
func pick_up_material_(astral_material: Area2D) -> void:
	if astral_material.is_nebulite() and ncsc_attached:
		nebulite_count += 1
		print("nebulite")
	elif (not astral_material.is_nebulite() and gcsc_attached):
		geodinium_count += 1
		print("geodinium")
	else:
		return
	astral_material.queue_free()


## See pick_up_material_
func pick_up_CSC(csc: Area2D) -> void:
	assert(csc.has_method("is_nebulite")) # Note: This is a debugging tool
	if csc.is_nebulite():
		ncsc_attached =  true
		csc.queue_free()
		print("nebulite csc")
	elif not csc.is_nebulite():
		gcsc_attached = true
		csc.queue_free()
		print("geodinium csc")
		

## This updates the visual material count on the CSCs. Pure abstraction
func _update_count_label_(label: RichTextLabel, count: int) -> void:
	var new_text = "[center]" + str(count) + "[/center]"
	label.parse_bbcode(new_text)
#endregion


	#### ASTAR STARTS HERE #####
#region AStar
var test_grid : Array[Array]= [
	[1, 0, 1, 1, 1, 1, 0, 1, 1, 1],
	[1, 1, 1, 0, 1, 1, 1, 0, 1, 1],
	[1, 1, 1, 0, 1, 1, 0, 1, 0, 1],
	[0, 0, 1, 0, 1, 0, 0, 0, 0, 1],
	[1, 1, 1, 0, 1, 1, 1, 0, 1, 0],
	[1, 0, 1, 1, 1, 1, 0, 1, 0, 0],
	[1, 0, 0, 0, 0, 1, 0, 0, 0, 1],
	[1, 0, 1, 1, 1, 1, 0, 1, 1, 1],
	[1, 1, 1, 0, 0, 0, 1, 0, 0, 1]
	]

# A structure to represent nodes in the pathfinding grid
class AStar_Node:
	var node_position: Vector2
	var g_cost: float = 0  # Cost from the start node
	var h_cost: float = 0  # Heuristic cost to the goal
	var parent: AStar_Node = null

	func _init(starting_position: Vector2):
		node_position = starting_position

	func f_cost() -> float:
		return g_cost + h_cost


func a_star(start: Vector2, goal: Vector2, grid: Array) -> Array:
	var open_list = []
	var closed_list = []

	var start_node = AStar_Node.new(start)
	var goal_node = AStar_Node.new(goal)

	open_list.append(start_node)

	# Movement offsets for 8 directions (up, down, left, right, and diagonals)
	var offsets = [
		Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),  # Cardinal directions
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)  # Diagonal directions
	]

	while open_list.size() > 0:
		# Sort the open list by F cost and pick the node with the lowest F cost
		open_list.sort_custom(_compare_nodes)
		var current_node = open_list[0]

		if current_node.node_position == goal_node.node_position:
			return construct_path(current_node)

		open_list.erase(current_node)
		closed_list.append(current_node)

		# Get neighbors
		for offset in offsets:
			var neighbor_pos = current_node.node_position + offset

			if !is_valid_position(neighbor_pos, grid) or node_in_list(neighbor_pos, closed_list):
				continue

			var movement_cost = grid[int(neighbor_pos.y)][int(neighbor_pos.x)]
			if movement_cost <= 0:
				continue

			var neighbor_node = AStar_Node.new(neighbor_pos)
			var additional_cost = 10 if (offset.x == 0 or offset.y == 0) else 14  
			neighbor_node.g_cost = current_node.g_cost + movement_cost * additional_cost
			neighbor_node.h_cost = heuristic(neighbor_node.node_position, goal_node.node_position)
			neighbor_node.parent = current_node

			if !node_in_list(neighbor_pos, open_list):
				open_list.append(neighbor_node)
			else:
				var existing_node = get_node_from_list(neighbor_pos, open_list)
				if neighbor_node.g_cost < existing_node.g_cost:
					existing_node.g_cost = neighbor_node.g_cost
					existing_node.parent = current_node

	# No path found
	return []



## Heuristic function (using Euclidean distance)
# Note: this is liable to change. I'm thinking about using distance to nearest
# astral material as the heuristic.
func heuristic(pos_a: Vector2, pos_b: Vector2) -> float:
	return pos_a.distance_to(pos_b)

## Helper function to check if a position is valid
func is_valid_position(pos: Vector2, grid: Array) -> bool:
	if pos.x < 0 or pos.x >= grid[0].size() or pos.y < 0 or pos.y >= grid.size():
		return false
	return grid[int(pos.y)][int(pos.x)] > 0  # Ensure position is walkable

## Helper function to check if a node with a specific position is in a list
func node_in_list(new_position: Vector2, node_list: Array) -> bool:
	for node in node_list:
		if node.node_position == new_position:
			return true
	return false

## Helper function to get a node from a list based on its position
func get_node_from_list(new_position: Vector2, node_list: Array) -> AStar_Node:
	for node in node_list:
		if node.node_position == new_position:
			return node
	return null

## Construct final path by backtracking from the goal node to the start node
func construct_path(node: AStar_Node) -> Array:
	var path = []
	while node != null:
		path.insert(0, node.node_position)
		node = node.parent
	return path
	
## Custom compare function for sorting nodes by total cost
func _compare_nodes(node_a: AStar_Node, node_b: AStar_Node) -> int:
	if node_a.f_cost() <= node_b.f_cost():
		return true
	else:
		return false
	
#endregion
#### AStar <-> Godot Position helper functions ####

## These are kind of abstractions for converting from real position <-> internal grid

func AStar_to_Godot_Position(AStar_Position: Vector2) -> Vector2:
	return ceil(AStar_Position * (90))

func Godot_to_AStar_Position(Godot_Position: Vector2) -> Vector2:
	return ceil(Godot_Position / (90))


## Just adds a transform to the queue
func add_event(desired_transform: StateMachine.Transform) -> void:
	event_queue.append(desired_transform)


func parse_event() -> void:
	assert(not event_queue.is_empty()) # Note: Debugging purposes
	var event = event_queue.pop_front()
	var desired_rotation: float = 0.0
	var desired_distance: float = 0.0
	if event.is_absolute():
		if event.rotation:
			# Note: We're basically checking if it's easier to go left or right
			if abs(event.rotation-internal_rotation) <= abs((event.rotation-360)-internal_rotation):
				desired_rotation = event.rotation - internal_rotation
			else:
				desired_rotation = (event.rotation-360) - internal_rotation
				
		# If we want to use astar, we construct the path, throw the first path point
		# to the microcontroller, and save the rest in the event queue
		if event.position and event.AStar:
			var new_queue: Array
			var path: Array[Vector2] = a_star(Godot_to_AStar_Position(internal_position), \
							  Godot_to_AStar_Position(event.position),\
							  grid_array)
			desired_distance = internal_position.distance_to(path[0])
			desired_rotation = rad_to_deg(internal_position.angle_to(path[0]))
			for i in range(1,len(path)):
				var godot_pos := AStar_to_Godot_Position(path[i])
				var new_rot:float = rad_to_deg(path[i-1].angle_to(path[i]))
				var new_transform := StateMachine.Transform.new\
									(Vector3(godot_pos.x,godot_pos.y,new_rot), true, true)
				new_queue.append(new_transform)
			new_queue.append_array(event_queue)
			event_queue = new_queue
		# If we don't want to use astar, we just get the distance :)
		elif event.position and (not event.AStar):
			desired_distance = internal_position.distance_to(event.position)
			desired_rotation = rad_to_deg(event.position.angle_to(internal_position))
	# These are for the cases where the transform is relative to the current position
	else:
		if event.rotation:
			desired_rotation = event.rotation
		if event.position and (event.position > Vector2(0,0)):
			desired_distance = event.position.distance_to(Vector2(0,0))
		# The below lets us move backwards
		elif event.position and (event.position < Vector2(0,0)):
			desired_distance = -event.position.distance_to(Vector2(0,0))
	if desired_rotation:
		send_rotation_to_arduino_(desired_rotation)
	if desired_distance:
		send_distance_to_arduino_(desired_distance)
	
