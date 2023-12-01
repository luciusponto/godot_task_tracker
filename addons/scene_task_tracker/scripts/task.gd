extends Resource

signal task_changed

enum TaskTypes {
	BUG,
	FEATURE,
	TECHNICAL_IMPROVEMENT,
	POLISH,
	REGRESSION_TEST,
	UNKNOWN,
}

enum Priority {
	VERY_LOW,
	LOW,
	MEDIUM,
	HIGH,
	VERY_HIGH,
	UNKNOWN,
}

enum Status {
	PENDING,
	COMPLETED,
	UNKNOWN,
}

const DEFAULT_TYPE = TaskTypes.UNKNOWN
const DEFAULT_PRIORITY = Priority.LOW
const DEFAULT_STATUS = Status.PENDING

var uid : int = 0

## Short description
@export_multiline var description: String = "Task description here":
	get:
		return description
	set(text):
		description = text
		task_changed.emit()

## Extra information
@export_multiline var details: String:
	get:
		return details
	set(text):
		details = text
		task_changed.emit()

## Task type
@export var task_type: TaskTypes = TaskTypes.UNKNOWN:
	get:
		return task_type
	set(value):
		task_type = value
		task_changed.emit()


## Task priority
@export var priority := Priority.VERY_LOW:
	get:
		return priority
	set(value):
		priority = value
		task_changed.emit()


## Task status
@export var status := Status.UNKNOWN:
	get:
		return status
	set(value):
		status = value
		task_changed.emit()

	
func _validate_property(property: Dictionary):
	match property.name:
		"uid" : property.usage = PROPERTY_USAGE_NO_EDITOR # consider PROPERTY_USAGE_READONLY
