@tool
extends Control

enum DIRTY_FLAGS {
	EDITED_SCENE_CHANGED = 	0b00000001,
	TASK_NODE_ADDED = 		0b00000010,
	TASK_NODE_REMOVED = 	0b00000100,
	FILTER_APPLIED = 		0b00001000,
	TREE_CHANGED = 			0b00010000,
	DOCK_READY = 			0b00100000,
	REFRESH_PRESSED = 		0b01000000,
	TASK_NODE_CHANGED = 	0b10000000,
}

enum TASK_TREE_COLUMN {
	DESCRIPTION,
	PRIORITY,
}

const REFRESH_PERIOD_MS: int = 2000
const SCENE_CHANGE_CHECK_PERIOD_MS: int = 2000

const BUG_MARKER = preload("../scripts/task_marker.gd")
const TASK = preload("../scripts/task.gd")
const TASK_TYPE = TASK.TaskTypes
const TASK_ST = TASK.Status
const TASK_DATABASE = preload("../scripts/task_database.gd")
const DEFAULT_TASK_DATABASE_PATH = "res://tasks/task_database.tres"
const CONFIG_PATH: String = "user://ls_task_tracker.cfg"

const NODE_SELECTOR_R = preload("node_selector.gd")

const SEL_SCENE_ONLY_ID: int = 30
const SEL_SUBSCENES_ID: int = 31

var _item_data : Array[int] = []
var _edited_root: Node
var _dirty_flags: int
var _is_dirty: bool
var _next_refresh_time: int = 0
var _next_scene_check_time: int = 0
var _node_selector: NODE_SELECTOR_R

var _nodes_popup: PopupMenu
var _filter_popup: PopupMenu

var _select_from_scene_only := true

var _selection_count: int
var _first_selected_index: int = -1
var _task_selection_status: Array[bool] = []

var _task_database_path: String
var _task_database: TASK_DATABASE
var _config : ConfigFile
var _edited_task: TASK


func _ready():
	
	_config = ConfigFile.new()
	var err = _config.load(CONFIG_PATH)
	if err == OK:
		_task_database_path = _config.get_value("database", "path", null)
	else: # create config file for this project
		_task_database_path = DEFAULT_TASK_DATABASE_PATH
		_config.set_value("database", "path", _task_database_path)
		var save_err = _config.save(CONFIG_PATH)
		if save_err != OK:
			push_error("Could not save task tracker config file")
	
	_load_database()
	
	# TODO: if no task_database has been assigned, only display UI stating so and allowing to set the path to the resource
	# once the task_database is set, save the path to a config file and display the normal UI
	
	_node_selector = NODE_SELECTOR_R.new()
	%NewTaskButton.pressed.connect(_on_new_task_button_pressed)
	%RefreshButton.pressed.connect(_on_refresh_button_pressed)
	%CopyDescrButton.pressed.connect(_on_copy_descr_button_pressed)
	%TaskEditorWindow.hide()
	%TaskEditorWindow.close_requested.connect(_on_edited_task_cancel)
	%TaskEditorCancelButton.pressed.connect(_on_edited_task_cancel)
	%TaskEditorOkButton.pressed.connect(_on_edited_task_ok)
	var tree_control = %Tree
	tree_control.multi_selected.connect(_on_multi_selected)
	tree_control.columns = 2
	tree_control.hide_root = true
	tree_control.hide_folding = true
	tree_control.scroll_horizontal_enabled = true
	tree_control.scroll_vertical_enabled = true
	tree_control.set_column_clip_content(0, true)
	tree_control.set_column_expand(0, true)
	tree_control.set_column_expand(1, false)
	_nodes_popup = (%NodesMenuButton as MenuButton).get_popup()
	_nodes_popup.id_pressed.connect(_on_nodes_popup_menu_id_pressed)
	_nodes_popup.hide_on_checkable_item_selection = false
	_nodes_popup.hide_on_item_selection = false
	_set_selection_scope_menu_items()
	_filter_popup = (%FilterMenuButton as MenuButton).get_popup()
	_filter_popup.hide_on_checkable_item_selection = false
	_filter_popup.hide_on_item_selection = false
	_filter_popup.id_pressed.connect(_on_filter_pressed)
	_next_scene_check_time = Time.get_ticks_msec() + SCENE_CHANGE_CHECK_PERIOD_MS
	_dirty_flags |= DIRTY_FLAGS.DOCK_READY
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process_old(_delta):
	var now: int = Time.get_ticks_msec()
	if now > _next_scene_check_time:
		_check_edited_scene_change()
	_is_dirty = _dirty_flags != 0
	if _is_dirty and Time.get_ticks_msec() > _next_refresh_time:
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
		_refresh()


func _load_database():
	if FileAccess.file_exists(_task_database_path):
		_task_database = load(_task_database_path)
	else:
		push_error("Could not load task database")


func _on_copy_descr_button_pressed():
	var inst_id = _item_data[_first_selected_index]
	var instance = instance_from_id(inst_id)
	if instance and instance is BUG_MARKER:
		DisplayServer.clipboard_set((instance as BUG_MARKER).description)


#func _on_item_selected(index: int):
#	%CopyDescrButton.disabled = false
#	var inst_id = _item_data[index]
#	_node_selector.on_selection_requested(inst_id)


#func _on_tree_changed():
#	get_tree()
#	_dirty_flags |= DIRTY_FLAGS.TREE_CHANGED


func _check_edited_scene_change():
	_next_scene_check_time += SCENE_CHANGE_CHECK_PERIOD_MS
	var scene_tree = get_tree()
	if not scene_tree:
		return
	var new_edited_root = scene_tree.edited_scene_root
	if new_edited_root != _edited_root:
		_next_refresh_time = 0 # Force immediate refresh
		_dirty_flags |= DIRTY_FLAGS.EDITED_SCENE_CHANGED
		if _edited_root:
			_disconnect_safe(_edited_root.tree_exited, _on_edited_root_exited_tree)
			_disconnect_safe(_edited_root.child_entered_tree, _on_edited_scene_child_added)
			_disconnect_safe(_edited_root.child_exiting_tree, _on_edited_scene_child_removed)
		if new_edited_root:
			_connect_safe(new_edited_root.tree_exited, _on_edited_root_exited_tree)
			_connect_safe(new_edited_root.child_entered_tree, _on_edited_scene_child_added)
			_connect_safe(new_edited_root.child_exiting_tree, _on_edited_scene_child_removed)
		_edited_root = new_edited_root


func _disconnect_safe(target_signal: Signal, target_function: Callable):
	if target_signal.is_connected(target_function):
		target_signal.disconnect(target_function)


func _connect_safe(target_signal: Signal, target_function: Callable):
	if not target_signal.is_connected(target_function):
		target_signal.connect(target_function)


func _on_edited_root_exited_tree():
	_check_edited_scene_change.call_deferred()


func _on_edited_scene_child_added(node: Node):
	if node is BUG_MARKER:
		_dirty_flags |= DIRTY_FLAGS.TASK_NODE_ADDED


func _on_edited_scene_child_removed(node: Node):
	if node is BUG_MARKER:
		_dirty_flags |= DIRTY_FLAGS.TASK_NODE_REMOVED


func _on_filter_pressed(id: int):
	if id == 10 or id == 11: # All or Nones
		# Uncheck All or None checkbox
		_filter_popup.set_item_checked(_filter_popup.get_item_index(id), false)
		
		var checked = id == 10
		for target_id in [0, 1, 2, 3, 4, 5, 8]: # Task types
			var index = _filter_popup.get_item_index(target_id)
			if (
					index > -1 and
					index < _filter_popup.item_count and
					_filter_popup.is_item_checkable(index)
				):
				_filter_popup.set_item_checked(index, checked)
	else:
		var index = _filter_popup.get_item_index(id)
		_filter_popup.toggle_item_checked(index)
	_dirty_flags |= DIRTY_FLAGS.FILTER_APPLIED


func _on_new_task_button_pressed():
	(%TaskEditorWindow as Window).show()
	_edited_task = TASK.new()
	

func _on_edited_task_cancel():
	(%TaskEditorWindow as Window).hide()
	# TODO: free task if new task and cancelled


func _on_edited_task_ok():
	(%TaskEditorWindow as Window).hide()
	# TODO: add / replace edited task to task database, save database


func _on_refresh_button_pressed():
	_dirty_flags |= DIRTY_FLAGS.REFRESH_PRESSED
	_next_refresh_time = 0 # FORCE instant refresh


func _enabled_in_interface(task: TASK) -> bool:
	var show_bug = _filter_popup.is_item_checked(_filter_popup.get_item_index(0))
	var show_feature = _filter_popup.is_item_checked(_filter_popup.get_item_index(1))
	var show_tech_impr = _filter_popup.is_item_checked(_filter_popup.get_item_index(2))
	var show_polish = _filter_popup.is_item_checked(_filter_popup.get_item_index(3))
	var show_regr_test = _filter_popup.is_item_checked(_filter_popup.get_item_index(4))
	var show_unknown = _filter_popup.is_item_checked(_filter_popup.get_item_index(8))
	var show_pending = _filter_popup.is_item_checked(_filter_popup.get_item_index(6))
	var show_completed = _filter_popup.is_item_checked(_filter_popup.get_item_index(7))
	var status_filter = show_completed if task.status == TASK_ST.COMPLETED else show_pending
	match task.task_type:
		TASK_TYPE.BUG:
			return status_filter and show_bug
		TASK_TYPE.FEATURE:
			return status_filter and show_feature
		TASK_TYPE.TECHNICAL_IMPROVEMENT:
			return status_filter and show_tech_impr
		TASK_TYPE.POLISH:
			return status_filter and show_polish
		TASK_TYPE.REGRESSION_TEST:
			return status_filter and show_regr_test
		TASK_TYPE.UNKNOWN:
			return status_filter and show_unknown
		_:
			return false


func _refresh():
	_is_dirty = false
	%CopyDescrButton.disabled = true
	
	var trigger_desc := "Refresh triggered by: "
	for key in DIRTY_FLAGS.keys():
		var flag = DIRTY_FLAGS.get(key)
		if _dirty_flags & flag != 0:
			trigger_desc += str(key).to_lower().capitalize() + ", "
	trigger_desc.trim_suffix(", ")
	_dirty_flags = 0
	
	if not _filter_popup:
		print(Time.get_time_string_from_system() + " - Task panel not ready to refresh")
		return
	var start_time_us = Time.get_ticks_usec()
	
	for old_item_inst_id in _item_data:
		var old_item = instance_from_id(old_item_inst_id)
		if old_item and old_item is BUG_MARKER:
			var old_task = old_item as BUG_MARKER
			old_task.task_changed.disconnect(_on_task_marker_changed)

	var bug_markers = _get_markers_from_scene()
	var items : Array[BUG_MARKER] = []
	for marker in bug_markers:
		if _enabled_in_interface(marker):
			items.append(marker)
	items.sort_custom(func(a : BUG_MARKER, b : BUG_MARKER): return a.get_sort_score() > b.get_sort_score())
	_task_selection_status.resize(len(items))
	_task_selection_status.fill(false)
	_item_data.clear()
	_selection_count = 0

	var tree_control: Tree = %Tree
	const OVERRUN_BEHAVIOUR: TextServer.OverrunBehavior = TextServer.OverrunBehavior.OVERRUN_TRIM_ELLIPSIS
	tree_control.clear()
	tree_control.set_column_expand(TASK_TREE_COLUMN.DESCRIPTION, true)
	var root: TreeItem = tree_control.create_item()

	for item in items:
		_item_data.append(item.get_instance_id())
		item.task_changed.connect(_on_task_marker_changed)
		var tree_item: TreeItem = tree_control.create_item(root)
		tree_item.set_cell_mode(TASK_TREE_COLUMN.PRIORITY, TreeItem.CELL_MODE_ICON)
		tree_item.set_cell_mode(TASK_TREE_COLUMN.DESCRIPTION, TreeItem.CELL_MODE_STRING)

		tree_item.set_icon(TASK_TREE_COLUMN.DESCRIPTION, item.get_icon())
		tree_item.set_icon_modulate(TASK_TREE_COLUMN.DESCRIPTION, item.get_color())
		tree_item.set_tooltip_text(TASK_TREE_COLUMN.DESCRIPTION, item.get_task_type_name().to_lower().capitalize())
		tree_item.set_text(TASK_TREE_COLUMN.DESCRIPTION, item.description)
		tree_item.set_tooltip_text(TASK_TREE_COLUMN.DESCRIPTION, item.description)
		tree_item.set_text_overrun_behavior(TASK_TREE_COLUMN.DESCRIPTION, OVERRUN_BEHAVIOUR)
		
		var prior_icon: Texture2D = item.get_priority_icon(true)
		var pr_tooltip: String = "Priority: " + item.get_priority_string().to_lower().capitalize()
		pr_tooltip += "; Status: " + item.get_status_string().to_lower().capitalize()
		tree_item.set_tooltip_text(TASK_TREE_COLUMN.PRIORITY, pr_tooltip)
		tree_item.set_icon(TASK_TREE_COLUMN.PRIORITY, prior_icon)
		tree_item.set_icon_modulate(TASK_TREE_COLUMN.PRIORITY, item.get_priority_color(true))
		
	var time_taken_us = Time.get_ticks_usec() - start_time_us
	print(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(float(time_taken_us) / 1000) + " ms)")
	print(trigger_desc)


func _refresh_node_selection():
	var selected_items: Array[Node] = []
	var task_count: int = len(_task_selection_status)
	for i in range(0, task_count):
		if _task_selection_status[i]:
			var inst_id = _item_data[i]
			var node = instance_from_id(inst_id)
			selected_items.append(node)
	_node_selector.set_selection(selected_items)


func _on_multi_selected(item: TreeItem, column: int, selected: bool):
	if column != 0:
		return
	var index = item.get_index()
	_task_selection_status[index] = selected
	_selection_count += 1 if selected else -1
	if _selection_count == 1:
		_first_selected_index = index
	%CopyDescrButton.disabled = _selection_count == 0
	_refresh_node_selection()#.call_deferred()


func _on_task_marker_changed():
	_dirty_flags |= DIRTY_FLAGS.TASK_NODE_CHANGED


func _get_markers_from_scene() -> Array[BUG_MARKER]:
	var scene_tree = get_tree()
	_edited_root = scene_tree.edited_scene_root
	var typed_markers : Array[BUG_MARKER] = []
	if _edited_root:
		var edited_tree = _edited_root.get_tree()
		var bug_markers = edited_tree.get_nodes_in_group("bug_marker")
		for marker in bug_markers:
			if marker is BUG_MARKER:
				typed_markers.append(marker as BUG_MARKER)
		return typed_markers
	else:
		return []


func _set_selection_scope_menu_items():
	_nodes_popup.set_item_checked(_nodes_popup.get_item_index(SEL_SCENE_ONLY_ID), _select_from_scene_only)
	_nodes_popup.set_item_checked(_nodes_popup.get_item_index(SEL_SUBSCENES_ID), not _select_from_scene_only)


func _on_nodes_popup_menu_id_pressed(id):
	if id == SEL_SCENE_ONLY_ID or id == SEL_SUBSCENES_ID:
		_select_from_scene_only = true if id == SEL_SCENE_ONLY_ID else false
		_set_selection_scope_menu_items()
		return
		
	var ed_sc_root = get_tree().edited_scene_root
	if not ed_sc_root:
		return
	
	if id >= 0 and id <= 5:
		var prev_selected_nodes = []
		var filter = func(_a):
			return false
		match id:
			0: # ALL
				filter = func(_a):
					return true
			1: # NONE
				filter = func(_a):
					return false
			2: # PENDING
				filter = func(a):
					return not a.status != TASK_ST.COMPLETED and not a.task_type == TASK_TYPE.REGRESSION_TEST
			3: # COMPLETED
				filter = func(a):
					return a.status == TASK_ST.COMPLETED and not a.task_type == TASK_TYPE.REGRESSION_TEST
			4: # REGRESSION TEST
				filter = func(a):
					return a.task_type == TASK_TYPE.REGRESSION_TEST
			5: # INVERT SELECTION
				prev_selected_nodes = _node_selector.get_selection().get_selected_nodes()
			8: # UNKNOWN
				filter = func(a):
					return a.task_type == TASK_TYPE.UNKNOWN
	
		var markers: Array[BUG_MARKER] = _get_markers_from_scene()
		var selected_nodes: Array[Node] = []# as Array[Node]
		for marker in markers:
			var marker_script = marker as BUG_MARKER
			var marker_in_scope = marker.owner == _edited_root or not _select_from_scene_only
			if marker_in_scope:
				if id == 5: # INVERT SELECTION
					if not prev_selected_nodes.has(marker):
						selected_nodes.append(marker)
				elif filter.call(marker_script):
					selected_nodes.append(marker)
		_node_selector.set_selection(selected_nodes)
	
	elif id == 15:
		_node_selector.hide_selected()
	elif id == 16:
		_node_selector.show_selected()

