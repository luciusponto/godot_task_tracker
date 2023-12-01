@tool
extends Node3D

const TASK = preload("task.gd")

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
	preload("res://addons/scene_task_tracker/icons/priority/_Completed.svg"),
]

const STATUS_COLORS = [
	Color.DARK_SALMON,
	Color.LIME_GREEN
]

const FIXED_MESH_COLOR = Color.LIME_GREEN
const MARKER_ARROW_COLOR = Color.YELLOW

const FIXED_MESH = preload("res://addons/scene_task_tracker/model/markers/mesh/CheckMark.obj")

var task : TASK
@onready var label_3d = %Label3D

func get_color() -> Color:
	return _get_elem(COLORS, task.task_type, TASK.DEFAULT_TYPE) as Color


func get_icon() -> Texture2D:
	return _get_elem(ICONS, task.task_type, TASK.DEFAULT_TYPE) as Texture2D


func get_priority_icon(include_status: bool = false) -> Texture2D:
	if include_status and task.status == TASK.Status.COMPLETED:
		return get_status_icon()
	return _get_elem(PRIORITY_ICONS, task.priority, TASK.DEFAULT_PRIORITY) as Texture2D


func get_priority_color(include_status: bool = false) -> Color:
	if include_status and task.status == TASK.Status.COMPLETED:
		return get_status_color()
	return _get_elem(PRIORITY_COLORS, task.priority, TASK.DEFAULT_PRIORITY) as Color


func get_task_type_name() -> String:
	var keys = TASK.TaskTypes.keys()
	return _get_elem(keys, task.task_type, TASK.DEFAULT_TYPE) as String


func get_priority_string() -> String:
	return TASK.Priority.keys()[task.priority]


func get_status_string() -> String:
	return TASK.Status.keys()[task.status]


func get_status_icon() -> Texture2D:
	return _get_elem(STATUS_ICONS, task.status, TASK.DEFAULT_STATUS) as Texture2D


func get_status_color() -> Color:
	return _get_elem(STATUS_COLORS, task.status, TASK.DEFAULT_STATUS) as Color


func get_sort_score() -> int:
	var score: int = task.priority
	if task.status == TASK.Status.COMPLETED:
		score -= 10
	return score


func _get_elem(array: Array, index, default_index):
	if index < 0 or index >= len(array):
		return array[default_index]
	return array[index]


func _exit_tree():
	if task and task.changed.is_connected(_on_task_changed):
		task.changed.disconnect(_on_task_changed)


func setup(target_task : TASK) -> void:
	task = target_task
	task.changed.connect(_on_task_changed)
	(%MarkerArrow as MeshInstance3D).set_instance_shader_parameter("color", MARKER_ARROW_COLOR)
	var task_type_mesh_inst := %TaskTypeMesh as MeshInstance3D
	task_type_mesh_inst.mesh = MESHES[TASK.TaskTypes.UNKNOWN]
	task_type_mesh_inst.set_instance_shader_parameter("color", COLORS[TASK.TaskTypes.UNKNOWN])
	_update_label()
	_update_mesh()


func _update_label():
	if label_3d:
		label_3d.text = task.description + "\n\n" + task.details


func _update_mesh():
	if not has_node("TaskTypeMesh"):
		return
	var mesh_instance := %TaskTypeMesh as MeshInstance3D
	if task.status == TASK.Status.COMPLETED:
		mesh_instance.mesh = FIXED_MESH
		mesh_instance.set_instance_shader_parameter("color", STATUS_COLORS[1])#FIXED_MESH_COLOR)
	elif task.task_type >= 0 and task.task_type <= len(MESHES):
		mesh_instance.mesh = MESHES[task.task_type]
		mesh_instance.set_instance_shader_parameter("color", get_color())
	else:
		push_error("Cannot find mesh - out of bounds. Index (from task type) = " + str(int(task.task_type)))


func _on_task_changed() -> void:
	_update_label()
	_update_mesh()
