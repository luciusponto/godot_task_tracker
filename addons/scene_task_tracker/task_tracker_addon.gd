@tool
extends EditorPlugin

const MARKER_MANAGER : String = "TaskMarkerManager"
const TASK_DATABASE : String = "TaskDatabase"

var dock
var task_database

func _enter_tree():
	dock = preload("UI/task_tracker_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)
	add_autoload_singleton(MARKER_MANAGER, "scripts/task_marker_manager.gd")
	task_database = preload("scripts/task_database.gd")
	add_custom_type(TASK_DATABASE, "Resource", task_database, null)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	remove_autoload_singleton(MARKER_MANAGER)
	remove_custom_type(TASK_DATABASE)
