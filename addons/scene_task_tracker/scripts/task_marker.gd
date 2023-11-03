@tool
extends Node3D

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

const MESHES = [
	preload("res://addons/scene_task_tracker/model/markers/mesh/BugMarkerNew.obj"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/FeatureMarker.obj"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/TechImprMarker.obj"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/PolishMarker.obj"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/RegTestMarker.obj"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/UnknownMarker.obj"),
]

const ICONS = [
	preload("res://addons/scene_task_tracker/icons/bug.svg"),
	preload("res://addons/scene_task_tracker/icons/feature.svg"),
	preload("res://addons/scene_task_tracker/icons/tech_improvement.svg"),
	preload("res://addons/scene_task_tracker/icons/polish.svg"),
	preload("res://addons/scene_task_tracker/icons/regression_test.svg"),
	preload("res://addons/scene_task_tracker/icons/unkown.svg")
]

const PRIORITY_ICONS = [
#	preload("res://addons/scene_task_tracker/icons/priority/very_low.svg"),
#	preload("res://addons/scene_task_tracker/icons/priority/low.svg"),
#	preload("res://addons/scene_task_tracker/icons/priority/medium.svg"),
#	preload("res://addons/scene_task_tracker/icons/priority/high.svg"),
#	preload("res://addons/scene_task_tracker/icons/priority/very_high.svg"),
	preload("res://addons/scene_task_tracker/icons/priority/_Very_Low.svg"),
	preload("res://addons/scene_task_tracker/icons/priority/_Low.svg"),
	preload("res://addons/scene_task_tracker/icons/priority/_Medium.svg"),
	preload("res://addons/scene_task_tracker/icons/priority/_High.svg"),
	preload("res://addons/scene_task_tracker/icons/priority/_Very_High.svg"),
]


const PRIORITY_COLORS = [
	Color.DARK_OLIVE_GREEN,
	Color.DARK_SEA_GREEN,
	Color.GOLDENROD,
	Color.DARK_ORANGE,
	Color.ORANGE_RED,
]

const COLORS = [
	Color.CORAL,
	Color.AQUAMARINE,
	Color.GOLDENROD,
	Color.LIGHT_SEA_GREEN,
	Color.LIGHT_STEEL_BLUE,
	Color.MAGENTA,
]

const STATUS_ICONS = [
	preload("res://addons/scene_task_tracker/icons/pending.svg"),
#	preload("res://addons/scene_task_tracker/icons/checkmark.svg")
	preload("res://addons/scene_task_tracker/icons/priority/_Completed.svg"),
]

const STATUS_COLORS = [
	Color.DARK_SALMON,
	Color.LIME_GREEN
]

const DEFAULT_TYPE = TaskTypes.UNKNOWN
const DEFAULT_PRIORITY = Priority.LOW
const DEFAULT_STATUS = Status.PENDING

const FIXED_MESH_COLOR = Color.LIME_GREEN
const MARKER_ARROW_COLOR = Color.YELLOW

const FIXED_MESH = preload("res://addons/scene_task_tracker/model/markers/mesh/CheckMark.obj")

## Short description
@export_multiline var description: String = "Task description here":
	get:
		return description
	set(text):
		description = text
		_update_label()
		task_changed.emit()

## Extra information
@export_multiline var details: String:
	get:
		return details
	set(text):
		details = text
		_update_label()
		task_changed.emit()

## Task type
@export var task_type: TaskTypes = TaskTypes.UNKNOWN:
	get:
		return task_type
	set(value):
		task_type = value
		_update_mesh()
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
		_update_mesh()
		task_changed.emit()

@onready var label_3d = %Label3D

#var _task_type_meshes: Array[Node3D] = []
var _initialized := false


# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.is_debug_build():
		if not _initialized:
			_setup.call_deferred()
			_initialized = true
	else:
		visible = false
		push_warning("Task marker (name: " + name + ") present in scene " + owner.name + " in production build. Hiding.")
		queue_free.call_deferred()


func get_color() -> Color:
	return _get_elem(COLORS, task_type, DEFAULT_TYPE) as Color


func get_icon() -> Texture2D:
	return _get_elem(ICONS, task_type, DEFAULT_TYPE) as Texture2D


func get_priority_icon(include_status: bool = false) -> Texture2D:
	if include_status and status == Status.COMPLETED:
		return get_status_icon()
	return _get_elem(PRIORITY_ICONS, priority, DEFAULT_PRIORITY) as Texture2D


func get_priority_color(include_status: bool = false) -> Color:
	if include_status and status == Status.COMPLETED:
		return get_status_color()
	return _get_elem(PRIORITY_COLORS, priority, DEFAULT_PRIORITY) as Color


func get_task_type_name() -> String:
	var keys = TaskTypes.keys()
	return _get_elem(keys, task_type, DEFAULT_TYPE) as String
	
	
func get_priority_string() -> String:
	return Priority.keys()[priority]
	
	
func get_status_string() -> String:
	return Status.keys()[status]


func get_status_icon() -> Texture2D:
	return _get_elem(STATUS_ICONS, status, DEFAULT_STATUS) as Texture2D


func get_status_color() -> Color:
	return _get_elem(STATUS_COLORS, status, DEFAULT_STATUS) as Color


func get_sort_score() -> int:
	var score: int = priority
	if status == Status.COMPLETED:
		score -= 10
	return score


func _get_elem(array: Array, index, default_index):
	if index < 0 or index >= len(array):
		return array[default_index]
	return array[index]
	

func _setup() -> void:
	(%MarkerArrow as MeshInstance3D).set_instance_shader_parameter("color", MARKER_ARROW_COLOR)
	var task_type_mesh_inst := %TaskTypeMesh as MeshInstance3D
	task_type_mesh_inst.mesh = MESHES[TaskTypes.UNKNOWN]
	task_type_mesh_inst.set_instance_shader_parameter("color", COLORS[TaskTypes.UNKNOWN])
	_update_label()
	_update_mesh()


func _update_label():
	if label_3d:
		label_3d.text = description + "\n\n" + details


func _update_mesh():
	if not has_node("TaskTypeMesh"):
		return
	var mesh_instance := %TaskTypeMesh as MeshInstance3D
	if status == Status.COMPLETED:
		mesh_instance.mesh = FIXED_MESH
		mesh_instance.set_instance_shader_parameter("color", STATUS_COLORS[1])#FIXED_MESH_COLOR)
	elif task_type >= 0 and task_type <= len(MESHES):
		mesh_instance.mesh = MESHES[task_type]
		mesh_instance.set_instance_shader_parameter("color", get_color())
	else:
		push_error("Cannot find mesh - out of bounds. Index (from task type) = " + str(int(task_type)))
	
