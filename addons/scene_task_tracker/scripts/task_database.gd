extends Resource

signal task_list_changed

const TASK = preload("./task.gd")

@export_group("Internal data")
## Do not change manually
@export var _last_uid : int = -1
## Do not change manually
@export var _tasks : Array[TASK]

func _validate_property(property: Dictionary):
	if property.name ==	"last_uid":
			property.usage = PROPERTY_USAGE_NO_EDITOR
			#property.usage |= PROPERTY_USAGE_READ_ONLY


func add_new_task(task: TASK):
	var task_uid = _last_uid + 1
	task.uid = task_uid
	_tasks.append(task)
	_last_uid = task_uid
	task_list_changed.emit()


func remove_task(uid):
	var target_task : TASK
	var found := false
	for task in _tasks:
		if task.uid == uid:
			target_task = task
			found = true
			break
	if found:
		_tasks.erase(target_task)
		task_list_changed.emit()
