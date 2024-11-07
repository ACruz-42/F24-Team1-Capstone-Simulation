class_name StateMachine extends Node

## A helper class to simplify desired positions
class Transform:
	enum position_type {
		ABSOLUTE, RELATIVE
	}
	
	signal position_reached
	
	var position: Vector2 = Vector2(0,0)
	var rotation: float = 0
	var type: position_type = position_type.RELATIVE
	
	func _init(transform: Vector3 = Vector3.ZERO, is_absolute: bool = false) -> void:
		position = Vector2(transform.x,transform.y)
		rotation = transform.z
		if is_absolute:
			type = position_type.ABSOLUTE
		else:
			type = position_type.RELATIVE
	
	func is_absolute() -> bool:
		if type == position_type.ABSOLUTE:
			return true
		else:
			return false
			
## Internal State class
class State:
	signal entered_state(new_state:State)
	signal exited_state(old_state:State)
	signal done()
	
	signal transform_request(requested_transform:Transform)
	
	var desired_transform: Transform
	
	func enter() -> void:
		entered_state.emit(self)
		return

	func exit() -> void:
		exited_state.emit(self)
		return
	
	## The state machine calls this every physics tick (analogous to a main loop
	## in an embedded system)
	func update(delta_: float) -> void:
		return 

## This state emulates waiting for the LED, however, waiting for the LED
## is outside the purview of this simulation, but is kept as a reminder for later
class Wait_State_ extends State: 
	func enter() -> void:
		super()
		done.emit()
		return

## During this state, the robot moves slightly forward to score points
## as according to Specification 2 (I) and (II). 
## Then it rotates back and forth to sense the astral material on the field
class Sense_State extends State:
	
	func enter() -> void:
		super()
		var temp_timer =  Timer.new()
		temp_timer.start(3)
		await temp_timer.timeout
		
		var move_forward = Transform.new()
		move_forward.type = Transform.position_type.RELATIVE
		move_forward.position = Vector2(0,-30)
		transform_request.emit(move_forward)
		
		var rotate_left = Transform.new()
		rotate_left.type = Transform.position_type.RELATIVE
		rotate_left.rotation = -60
		transform_request.emit(rotate_left)
		
		var rotate_right = Transform.new()
		rotate_left.type = Transform.position_type.RELATIVE
		rotate_left.rotation = -60
		transform_request.emit(rotate_left)
		await rotate_right.position_reached
		
		done.emit()
		
	func update(delta_:float) -> void:
		
		return

class NCSC_State extends State:
	pass



# pick up ncsc, pick up gcsc, go to cave,
# pick everything up in cave, go out of cave, pick everything outside of cave
# place beacon, wait at landing pad
