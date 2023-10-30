@tool
extends Control

signal select_requested(node_instanceid: int)

const BUG_MARKER = preload("res://addons/scene_task_tracker/scripts/task_marker.gd")

const STATUS_ICONS = [
	preload("res://addons/scene_task_tracker/icons/pending.svg"),
	preload("res://addons/scene_task_tracker/icons/checkmark.svg")
]

var task_instance_id: int
var task_priority: int


func setup(target_task):
	var task = target_task as BUG_MARKER
	task_instance_id = task.get_instance_id()
	%DescriptionButton.text = task.description
	%DescriptionButton.tooltip_text = task.description
	var status_icon_index = 1 if task.fixed else 0
	%StatusIcon.texture = STATUS_ICONS[status_icon_index]
	%StatusIcon.modulate = BUG_MARKER.STATUS_COLORS[status_icon_index]
	%StatusIcon.tooltip_text = "Status: " + ("completed" if task.fixed else "pending")
	%TaskTypeIcon.texture = task.get_icon()
	%TaskTypeIcon.modulate = task.get_color()
	%TaskTypeIcon.tooltip_text = task.get_task_type_name().to_lower().capitalize()
	%FixedCheckBox.button_pressed = task.fixed
	%PriorityLabel.text = str(task.priority)
	%PriorityLabel.tooltip_text = "Priority: " + str(task.priority)
	task_priority = task.priority


func _on_description_button_pressed():
	select_requested.emit(task_instance_id)


func _on_copy_descr_button_pressed():
	var description: String = %DescriptionButton.text
	var trimmed_descr = description.strip_edges()
	DisplayServer.clipboard_set(trimmed_descr)
