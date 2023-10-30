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

const COLORS = [
	Color.CORAL,
	Color.AQUAMARINE,
	Color.GOLDENROD,
	Color.LIGHT_SEA_GREEN,
	Color.LIGHT_STEEL_BLUE,
	Color.MAGENTA,
]

const STATUS_COLORS = [
	Color.DARK_SALMON,
	Color.DARK_OLIVE_GREEN
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
		task_changed.emit()
		_update_mesh()


## Task priority
@export var priority := Priority.VERY_LOW:
	get:
		return priority
	set(value):
		priority = value
		task_changed.emit()

## Task priority
@export var priority_en := Priority.UNKNOWN:
	get:
		return priority_en
	set(value):
		priority_en = value
		task_changed.emit()

## Set to true if the task has been completed
@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		_update_mesh()
		task_changed

## Task status
@export var status := Status.UNKNOWN:
	get:
		return status
	set(value):
		status = value
		_update_mesh()
		task_changed

@onready var label_3d = %Label3D

var _task_type_meshes: Array[Node3D] = []
var _initialized := false


# Called when the node enters the scene tree for the first time.
func _ready():
	priority = priority_en
	if OS.is_debug_build():
		if not _initialized:
			_setup.call_deferred()
			_initialized = true
	else:
		visible = false
		push_warning("Task marker (name: " + name + ") present in scene " + owner.name + " in production build. Hiding.")
		queue_free.call_deferred()


func get_color() -> Color:
	if task_type > len(COLORS) - 1:
		return COLORS[DEFAULT_TYPE]
	return COLORS[task_type]


func get_icon() -> Texture2D:
	if task_type > len(ICONS) - 1:
		return ICONS[DEFAULT_TYPE]
	return ICONS[task_type]
	
	
func get_task_type_name() -> String:
	var keys = TaskTypes.keys()
	if task_type > len(keys):
		return keys[DEFAULT_TYPE]
	return keys[task_type]
	
	
func get_priority_string() -> String:
	return Priority.keys()[priority]
	
	
func get_status_string() -> String:
	return Status.keys()[status]


#func _migrate_enums():
#	print(name + " - priority: " + Priority.keys()[priority] + "; status: " + Status.keys()[status])
#	priority_en = priority - 1
#	status = Status.COMPLETED if fixed else Status.PENDING


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
	var mesh_instance := %TaskTypeMesh as MeshInstance3D
	if fixed:
		mesh_instance.mesh = FIXED_MESH
		mesh_instance.set_instance_shader_parameter("color", STATUS_COLORS[1])#FIXED_MESH_COLOR)
	elif task_type >= 0 and task_type <= len(MESHES):
		mesh_instance.mesh = MESHES[task_type]
		mesh_instance.set_instance_shader_parameter("color", get_color())
	else:
		push_error("Cannot find mesh - out of bounds. Index (from task type) = " + str(int(task_type)))
	
