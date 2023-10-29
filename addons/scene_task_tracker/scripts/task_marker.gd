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

const BILLBOARDS = [
	preload("res://addons/scene_task_tracker/model/markers/BugMarkerNew.glb"),
	preload("res://addons/scene_task_tracker/model/markers/FeatureMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/TechImprMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/PolishMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/RegTestMarker.glb"),
	preload("res://addons/scene_task_tracker/model/markers/UnknownMarker.glb"),
]

const MESHES = [
	preload("res://addons/scene_task_tracker/model/markers/mesh/bug_marker.tres"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/feature.tres"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/tech_improvement.tres"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/polish.tres"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/regression_test.tres"),
	preload("res://addons/scene_task_tracker/model/markers/mesh/unknown.tres"),
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
	Color.GOLD,
	Color.MEDIUM_AQUAMARINE,
	Color.SILVER,
	Color.MAGENTA,
]

const DEFAULT_TYPE = TaskTypes.UNKNOWN
const FIXED_MESH = preload("res://addons/scene_task_tracker/model/markers/mesh/checkmark.tres")

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


## Task priority. Highest is 5, lowest is 1.
@export_range(1, 5) var priority: int = 1:
	get:
		return priority
	set(value):
		priority = value
		task_changed.emit()


## Set to true if the task has been completed
@export var fixed: bool = false:
	get:
		return fixed
	set(value):
		fixed = value
		_update_mesh()
		task_changed


@onready var label_3d = %Label3D

var _task_type_meshes: Array[Node3D] = []
var _initialized := false


# Called when the node enters the scene tree for the first time.
func _ready():
	if not _initialized:
		call_deferred("_setup")
		_initialized = true


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


func _setup() -> void:
	_update_label()
	_update_mesh()


func _update_label():
	if label_3d:
		label_3d.text = description + "\n\n" + details
		

func _update_mesh():
	if fixed:
		(%TaskTypeMesh as MeshInstance3D).mesh = FIXED_MESH
	elif task_type >= 0 and task_type <= len(MESHES):
		(%TaskTypeMesh as MeshInstance3D).mesh = MESHES[task_type]
	else:
		push_error("Cannot find mesh - out of bounds. Index (from task type) = " + str(int(task_type)))
