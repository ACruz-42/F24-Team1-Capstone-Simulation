class_name EventQueue extends Node

# Note: Export is a prefix that makes debugging easier
@export var Queue: Array

func _init() -> void:
	Queue = []

# Add a new movement event to the queue
func add_event(event: StateMachine.Transform) -> void:
	Queue.append(event)
	process_queue()

# Process the next event in the queue
func process_queue() -> StateMachine.Transform:
	if is_processing or Queue.is_empty():
		return

	return Queue.pop_front()
