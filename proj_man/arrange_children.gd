@tool
extends Node

const UPDATE_PERIOD_MS = 1000
const TASK_MARKER = preload("res://addons/scene_task_tracker/scripts/task_marker.gd")

@export var dist: float = 2.0
@export var columns: int = 5

@export var run: bool:
	get:
		return false
	set(_value):
		run = false
		_is_dirty = true
		
var _is_dirty: bool = false

func _process(_delta):
	if _is_dirty:
		_is_dirty = false
		_arrange()
		

func _enter_tree():
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_entered_tree)


func _exit_tree():
	child_entered_tree.disconnect(_on_child_entered_tree)
	child_exiting_tree.disconnect(_on_child_entered_tree)
	
	
func _on_child_entered_tree(node: Node):
	if node.is_in_group(&"bug_marker"):
		_is_dirty = true


func _arrange():
	print("Arranging task marker nodes in " + name)
	var col = 0
	var row = 0
	for child in get_children():
		if child.is_in_group(&"bug_marker"):
			var node = child as TASK_MARKER
			print(node.name)
			node.position = Vector3(col * dist, 0, -row * dist)
			col += 1
			if col >= columns:
				row += 1
				col = 0
