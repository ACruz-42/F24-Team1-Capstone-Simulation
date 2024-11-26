extends Node

class_name StateMachine

signal send_event(event: Transform)
signal state_changed(old_state: State, new_state: State)

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
		var rotate_right = Transform.new(Vector3(0, 0, 60))
		transform_request.emit(rotate_right)
		

		done.emit()

## NCSC State (Placeholder for more logic)
class NCSCState extends State:
	func enter() -> void:
		super.enter()
		
		var ready_position = Transform.new(Vector3(1500,850,0),true)
		transform_request.emit(ready_position)
		
		var ready_rotation = Transform.new(Vector3(0,0,180), true)
		transform_request.emit(ready_rotation)
		
		var pick_up_position = Transform.new(Vector3(0,-150,0))
		transform_request.emit(pick_up_position)
		
		done.emit()


var current_state: State
var current_index: int = 0
var state_list: Array = [WaitState, SenseState,NCSCState]

func _ready() -> void:
	# Initialize the state machine with a default state
	current_state = state_list[0].new()
	current_state.done.connect(transition_to.bind(current_index+1))
	current_state.transform_request.connect(emit_send_event)

func emit_send_event(event:Transform) -> void:
	send_event.emit(event)

func start() -> void:
	current_state.enter()

func transition_to(index: int) -> void:
	if index >= len(state_list):
		return
	if current_state:
		current_state.exit()
		state_changed.emit(current_state, state_list[index])
	
	current_index = index
	current_state = state_list[index].new()
	current_state.done.connect(transition_to.bind(current_index+1))
	current_state.transform_request.connect(emit_send_event)
	current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.update(delta)
