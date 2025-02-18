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
@export var MAX_FORWARD_SPEED = 42*15
@export var MAX_BACKWARD_SPEED = 42*15
@export var MAX_ROTATIONAL_SPEED = 10*15

# Note: A Vector2 in Godot is a pair of numeric values, not a mathematical vector
var internal_position: Vector2
var internal_rotation: float
var outside_map: Array[Array]
var cave_map: Array[Array]

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

# Keep track of material on the board. This would be provided by the camera data
# but we're assuming perfect information in this simulation, so it's exact here.

var cave_nebulite: Array
var cave_geodinium: Array
var outside_nebulite: Array
var outside_geodinium: Array

# These are dummy variables on advisement of Dr. Rizvi. These do nothing atm.
var correct_pad: int = 0
const pad_locations = {0:Vector3(400,480,-180), 1:Vector3(400,600,90), 2:Vector3(400,800,90),
					   3:Vector3(400,1000,90), 4:Vector3(400,1200,90)}

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
	state_machine.find_path.connect(find_nearest_path)
	
	
	#for i:int in range(16):
		#var inner_array: Array
		#if i == 0 or i == 15:
			#inner_array.resize(18)
			#inner_array.fill(0)
		#else:
			#inner_array.resize(18)
			#inner_array.fill(3)
			#inner_array[0] = 0
			#inner_array[17] = 0
		#outside_map.append(inner_array)
		#
	#for i:int in range(16):
		#var inner_array: Array
		#if i == 0 or i == 15:
			#inner_array.resize(10)
			#inner_array.fill(0)
		#else:
			#inner_array.resize(10)
			#inner_array.fill(3)
			#inner_array[0] = 0
			#inner_array[9] = 0
		#cave_map.append(inner_array)
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

## Starts the state machine. This is a function for clean code practice
func start_state_machine() -> void:
	state_machine.start()


## This is a native godot function that runs every physics tick
func _physics_process(delta_: float) -> void :
	# Continue processing event queue
	if is_rotating:
		# Run the movement function
		rotate_(delta_, rotation_speed, 1)

		# Update elapsed time
		elapsed_rotation_time += delta_
		internal_rotation += delta_*rotation_speed
		while(internal_rotation < 0):
			internal_rotation += 360
		while(internal_rotation > 360):
			internal_rotation -= 360

		# Stop moving after the duration
		if elapsed_rotation_time > rotation_duration or \
		   is_equal_approx(elapsed_rotation_time, rotation_duration):
			is_rotating = false
	# Continue processing event queue
	elif is_moving:
		# Run the movement function
		if move_speed > 0:
			move_forward_(delta_, move_speed)
		else:
			move_backward_(delta_, -move_speed)

		# Update elapsed time
		elapsed_move_time += delta_
		
		update_position()
	
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
			
func update_position():
	internal_position = position
	#internal_position.x += sin(deg_to_rad(internal_rotation)) * delta_*move_speed
	#internal_position.y -= cos(deg_to_rad(internal_rotation)) * delta_*move_speed
	
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
		if astral_material.global_position in outside_nebulite:
			outside_nebulite.erase(astral_material.global_position)
		if astral_material.global_position in cave_nebulite:
			cave_nebulite.erase(astral_material.global_position)
		nebulite_count += 1
	elif (not astral_material.is_nebulite() and gcsc_attached):
		geodinium_count += 1
		if astral_material.global_position in outside_geodinium:
			outside_geodinium.erase(astral_material.global_position)
		if astral_material.global_position in cave_geodinium:
			cave_geodinium.erase(astral_material.global_position)
	else:
		return

	astral_material.queue_free()


## See pick_up_material_
func pick_up_CSC(csc: Area2D) -> void:
	assert(csc.has_method("is_nebulite")) # Note: This is a debugging tool
	if csc.is_nebulite():
		ncsc_attached =  true
		csc.queue_free()
	elif not csc.is_nebulite():
		gcsc_attached = true
		csc.queue_free()
		

## This updates the visual material count on the CSCs. Pure abstraction
func _update_count_label_(label: RichTextLabel, count: int) -> void:
	var new_text = "[center]" + str(count) + "[/center]"
	label.parse_bbcode(new_text)
#endregion


	#### ASTAR STARTS HERE #####
#region AStar
var test_grid : Array[Array]= \
	[
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
	var distance = pos_a.distance_to(pos_b)
	return distance

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

## Use this to get angle to target
func get_rotation_to_target(start_pos: Vector2, end_pos: Vector2) -> float:
	var direction = end_pos - start_pos 
	var angle_radians = atan2(direction.y, direction.x) 
	return rad_to_deg(angle_radians) + 90

## Just adds a transform to the queue
func add_event(desired_transform: StateMachine.Transform) -> void:
	event_queue.append(desired_transform)


#region Event Parser
func parse_event() -> void:
	assert(not event_queue.is_empty())  # Debugging purposes

	var event = event_queue.pop_front()
	var desired_rotation: float = 0.0
	var desired_distance: float = 0.0

	if event.is_absolute():
		parse_absolute_movement(event, desired_rotation, desired_distance)
	else:
		parse_relative_movement(event, desired_rotation, desired_distance)
	current_event = event
	
#   ABSOLUTE MOVEMENT HANDLING

func parse_absolute_movement(event, desired_rotation: float, desired_distance: float) -> void:
	if event.rotation:
		desired_rotation = calculate_absolute_rotation(event.rotation)

	if event.position:
		if event.AStar:
			process_astar_path(event)
		else:
			desired_distance = internal_position.distance_to(event.position)
			var target_rotation = get_rotation_to_target(internal_position, event.position)
			desired_rotation = calculate_absolute_rotation(target_rotation)
	
	#var arrow = preload("res://pathfindingnode.tscn").instantiate()
	#arrow.start_position = internal_position
	#arrow.length = desired_distance
	#arrow.angle_degrees = get_rotation_to_target(internal_position, event.position)
	#get_tree().current_scene.add_child(arrow)
	execute_movement(desired_rotation, desired_distance)

func calculate_absolute_rotation(target_rotation: float) -> float:
	while(target_rotation < 0):
		target_rotation += 360
	while(target_rotation > 360):
		target_rotation -= 360
	var direct_rotation = target_rotation - internal_rotation
	var alt_rotation = (target_rotation - 360) - internal_rotation
	return direct_rotation if abs(direct_rotation) <= abs(alt_rotation) else alt_rotation

#todo: make this work
func process_astar_path(target_event: StateMachine.Transform) -> void:
	var new_queue: Array
	var path: Array = a_star(
		Godot_to_AStar_Position(internal_position),
		Godot_to_AStar_Position(target_event.position),
		outside_map
	)

	var first_step = path[0]
	var _desired_distance = internal_position.distance_to(first_step)
	var _desired_rotation = rad_to_deg(internal_position.angle_to(first_step))

	for i in range(1, len(path)):
		var godot_pos := AStar_to_Godot_Position(path[i])
		var new_rot: float = rad_to_deg(path[i - 1].angle_to(path[i]))
		var new_transform := StateMachine.Transform.new(Vector3(godot_pos.x, godot_pos.y, new_rot), true)
		new_queue.append(new_transform)
		if i == len(path)-1:
			# this doesnt work, and i strongly suspect it's because target_event is cleaned
			new_transform.position_reached.connect(target_event.astar_finished.emit)

	new_queue.append_array(event_queue)
	event_queue = new_queue

#   RELATIVE MOVEMENT HANDLING

func parse_relative_movement(event, desired_rotation: float, desired_distance: float) -> void:
	if event.rotation:
		desired_rotation = event.rotation

	if event.position:
		desired_distance = event.position.length()  # Cleaner than comparing to `Vector2.ZERO`
		if event.position.x < 0 or event.position.y < 0:
			desired_distance *= -1  # Allows moving backwards
	
	execute_movement(desired_rotation, desired_distance)


func execute_movement(desired_rotation: float, desired_distance: float) -> void:
	if desired_rotation != 0.0:
		send_rotation_to_arduino_(desired_rotation)

	if desired_distance != 0.0:
		send_distance_to_arduino_(desired_distance)
#endregion

# Placeholder function. I'm just a bit worried about the rover getting too close to
# the wall
func check_too_close_to_wall(pos: Vector2) -> void:
	if pos.y <= 430:
		var event := StateMachine.Transform.new(Vector3(pos.x,pos.y+400,0),true)
		event_queue.append(event)
	elif pos.y > 1160:
		var event := StateMachine.Transform.new(Vector3(pos.x,pos.y-400,0),true)
		event_queue.append(event)
	if pos.x <= 370:
		var event := StateMachine.Transform.new(Vector3(pos.x+450,pos.y,0),true)
		event_queue.append(event)
	elif pos.x >= 1390:
		var event := StateMachine.Transform.new(Vector3(pos.x-450,pos.y,0),true)
		event_queue.append(event)
	return

## This is in place of AStar. We'll get the closest position, then the closest 
## position to that. Adds a bunch of points to the event queue
func find_nearest_path(start_pos: Vector2 = internal_position, positions: Array = outside_geodinium+outside_nebulite) -> void:
	var current_pos = start_pos
	var remaining_positions = positions.duplicate()

	# this might not work,can't change array while iterating in godot
	while not remaining_positions.is_empty():
		var closest_pos = remaining_positions[0]
		var closest_distance = current_pos.distance_squared_to(closest_pos)

		for pos: Vector2 in remaining_positions:
			var dist = current_pos.distance_squared_to(pos)
			if (dist < closest_distance):
				closest_pos = pos
				closest_distance = dist
			
		# Checks if rover will end up too close to the wall, and brings the rover
		# closer to the center if it will.
		check_too_close_to_wall(closest_pos)
			
		var new_event := StateMachine.Transform.new(Vector3(closest_pos.x,closest_pos.y,0), true)
		event_queue.append(new_event)

		remaining_positions.erase(closest_pos)  # Remove visited position
		current_pos = closest_pos
	
	var final_event := StateMachine.Transform.new(pad_locations[correct_pad], true)
	event_queue.append(final_event)
	event_queue.append(StateMachine.Transform.new(Vector3(0,0,180), true))
	
