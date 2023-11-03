#@tool
extends Control

signal select_requested(node_instanceid: int)

const BUG_MARKER = preload("res://addons/scene_task_tracker/scripts/task_marker.gd")

const STATUS_ICONS = [
	preload("res://addons/scene_task_tracker/icons/pending.svg"),
	preload("res://addons/scene_task_tracker/icons/checkmark.svg")
]

var task_instance_id: int
var task_priority: BUG_MARKER.Priority


func setup(target_task):
	var task = target_task as BUG_MARKER
	task_instance_id = task.get_instance_id()
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.description
	%StatusIcon.texture = _get_elem(STATUS_ICONS, task.status, STATUS_ICONS[0])
	%StatusIcon.modulate = _get_elem(BUG_MARKER.STATUS_COLORS, task.status, BUG_MARKER.STATUS_COLORS[0])
	%StatusIcon.tooltip_text = "Status: " + task.get_status_string().to_lower()
	%TaskTypeIcon.texture = task.get_icon()
	%TaskTypeIcon.modulate = task.get_color()
	%TaskTypeIcon.tooltip_text = task.get_task_type_name().to_lower().capitalize()
	%PriorityLabel.text = str(task.priority + 1)
	%PriorityLabel.tooltip_text = "Priority: " + str(task.get_priority_string().to_lower().capitalize())
	task_priority = task.priority
	

func _get_elem(array: Array, index: int, default):
	if index >= 0 and index <= len(array) - 1:
		return array[index]
	return default


func _on_description_button_pressed():
	select_requested.emit(task_instance_id)


func _on_copy_descr_button_pressed():
	var description: String = %DescriptionButton.text
	var trimmed_descr = description.strip_edges()
	DisplayServer.clipboard_set(trimmed_descr)
