extends Node

class_name StateMachine

signal send_event(event: Transform)
signal state_changed(old_state: State, new_state: State)
signal find_path


## Helper class
class Transform:
	enum PositionType { ABSOLUTE, RELATIVE }

	signal position_reached

	var position: Vector2 = Vector2.ZERO
	var rotation: float = 0
	var type: PositionType = PositionType.RELATIVE
	var AStar: bool = false

	func _init(transform: Vector3 = Vector3.ZERO, absolute: bool = false, is_AStar: bool = false) -> void:
		position = Vector2(transform.x, transform.y)
		rotation = transform.z
		type = PositionType.ABSOLUTE if absolute else PositionType.RELATIVE
		AStar = is_AStar
		position_reached.connect(func():)

	func is_absolute() -> bool:
		return type == PositionType.ABSOLUTE

## Base State class
class State:
	signal entered_state(new_state: State)
	signal exited_state(old_state: State)
	signal done()

	signal transform_request(requested_transform: Transform)

	var desired_transform: Transform

	func enter() -> void:
		entered_state.emit(self)

	func exit() -> void:
		exited_state.emit(self)

	func update(_delta: float) -> void:
		pass

## Wait state
class WaitState extends State:
	func enter() -> void:
		super.enter()
		done.emit()

## Sense state
class SenseState extends State:
	func enter() -> void:
		super.enter()

		# Move forward
		var move_forward = Transform.new(Vector3(0, 90, 0))
		transform_request.emit(move_forward)

		# Rotate left
		var rotate_left = Transform.new(Vector3(0, 0, 250), true)
		transform_request.emit(rotate_left)
		
		# Rotate right
		var rotate_right = Transform.new(Vector3(0, 0, 180))
		transform_request.emit(rotate_right)
		await rotate_right.position_reached
		

		done.emit()

## NCSC State
class NCSCState extends State:
	func enter() -> void:
		super.enter()
		
		var ready_position = Transform.new(Vector3(1550,850,0),true)
		transform_request.emit(ready_position)
		
		var ready_rotation = Transform.new(Vector3(0,0,360), true)
		transform_request.emit(ready_rotation)
		
		var pick_up_position = Transform.new(Vector3(0,-210,0))
		transform_request.emit(pick_up_position)
		
		var reset_position = Transform.new(Vector3(0, 300,0))
		transform_request.emit(reset_position)
		
		done.emit()

class GCSCState extends State:
	func enter() -> void:
		super.enter()
		
		var ready_position = Transform.new(Vector3(750,728,0),true)
		transform_request.emit(ready_position)
		
		var ready_rotation = Transform.new(Vector3(0,0,180), true)
		transform_request.emit(ready_rotation)
		
		var pick_up_position = Transform.new(Vector3(0,-300,0))
		transform_request.emit(pick_up_position)
		
		done.emit()

class CavePrepState extends State:
	func enter() -> void:
		super.enter()
		
		var ready_position = Transform.new(Vector3(1410, 761,0), true)
		transform_request.emit(ready_position)
		
		var ready_rotation = Transform.new(Vector3(0,0,90), true)
		transform_request.emit(ready_rotation)
		
		var enter_cave_position = Transform.new(Vector3(950,0,0))
		transform_request.emit(enter_cave_position)

		
		done.emit()

class CaveVacuumState extends State:
	func enter() -> void:
		super.enter()
		
		var ready_position = Transform.new(Vector3(-300,0,0))
		transform_request.emit(ready_position)
		
		var clockwise_turn = Transform.new(Vector3(0,0,-90))
		transform_request.emit(clockwise_turn)

		var sweep_up = Transform.new(Vector3(0,350,0))
		transform_request.emit(sweep_up)
		
		var back = Transform.new(Vector3(0,-350,0))
		transform_request.emit(back)
		
		var move = Transform.new(Vector3(300,0,90))
		transform_request.emit(move)
		
		transform_request.emit(clockwise_turn)
		transform_request.emit(sweep_up)
		transform_request.emit(Transform.new(Vector3(-100,0,0)))
		transform_request.emit(Transform.new(Vector3(100,0,90)))
		transform_request.emit(Transform.new(Vector3(-100,0,0)))
		transform_request.emit(Transform.new(Vector3(0,0,90)))

		
		var move_down = Transform.new(Vector3(0,600,0))
		transform_request.emit(move_down)
		transform_request.emit(Transform.new(Vector3(100,0,-90)))
		transform_request.emit(Transform.new(Vector3(-100,0,90)))
		transform_request.emit(Transform.new(Vector3(0,-250,0)))

		
		var move_left = Transform.new(Vector3(250,0,90))
		transform_request.emit(move_left)
		
		var sweep_down =  Transform.new(Vector3(350,0,-90))
		transform_request.emit(sweep_down)
		
		
		transform_request.emit(back)
		
		var counter_turn = Transform.new(Vector3(0,0, 270), true)
		transform_request.emit(counter_turn)
		
		var exit_cave = Transform.new(Vector3(600,0,0))
		transform_request.emit(exit_cave)
		
		await exit_cave.position_reached
		
		
		done.emit()
		
class MaterialPickupState extends State:
	signal find_path
	func enter() -> void:
		super.enter()
		
		find_path.emit()
		
var current_state: State
var current_index: int = 0
var state_list: Array = [WaitState, SenseState,NCSCState,GCSCState,CavePrepState, \
						CaveVacuumState, MaterialPickupState]

func _ready() -> void:
	# Initialize the state machine with a default state
	current_state = state_list[0].new()
	current_state.done.connect(transition_to.bind(current_index+1))
	current_state.transform_request.connect(send_event.emit)


# Starts the machine. There might be a stop at some point, but this is mostly
# for good coding practice
func start() -> void:
	current_state.enter()

func transition_to(index: int) -> void:
	# If we're past the last state, we just return
	if index >= len(state_list):
		return
	
	# if there's a current state, we exit that before entering the next state
	if current_state:
		current_state.exit()
		state_changed.emit(current_state, state_list[index])
	
	# Housekeeping for state data
	current_index = index
	current_state = state_list[index].new() # Makes a new state
	current_state.done.connect(transition_to.bind(current_index+1))
	current_state.transform_request.connect(send_event.emit)
	# This is exclusively for the MaterialPickupState
	if current_state.has_signal("find_path"):
		current_state.find_path.connect(find_path.emit)
	
	# Actually enter the new state
	current_state.enter()

func _physics_process(delta: float) -> void:
	# Basically passes physics processing downwards (not utilized atm)
	if current_state:
		current_state.update(delta)
