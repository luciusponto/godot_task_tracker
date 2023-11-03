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
#	TYPE,
	DESCRIPTION,
	PRIORITY,
#	STATUS,
}

const REFRESH_PERIOD_MS: int = 2000
const SCENE_CHANGE_CHECK_PERIOD_MS: int = 2000

const BUG_MARKER = preload("res://addons/scene_task_tracker/scripts/task_marker.gd")
const TASK_TYPE = preload("res://addons/scene_task_tracker/scripts/task_marker.gd").TaskTypes
const TASK_ST = preload("res://addons/scene_task_tracker/scripts/task_marker.gd").Status

const ITEM = preload("res://addons/scene_task_tracker/UI/task_item_bt.gd")
const NODE_SELECTOR_R = preload("res://addons/scene_task_tracker/UI/node_selector.gd")

const SEL_SCENE_ONLY_ID: int = 30
const SEL_SUBSCENES_ID: int = 31

#var _item_resource = preload("res://addons/scene_task_tracker/UI/task_item_bt.tscn")
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
#var _selected_item_indices: Array[int] = []
var _task_selection_status: Array[bool] = []
#var _selection_dirty := false


func _enter_tree():
	_node_selector = NODE_SELECTOR_R.new()
#	get_tree().tree_changed.connect(_on_tree_changed)


func _exit_tree():
#	get_tree().tree_changed.disconnect(_on_tree_changed)
	pass


func _ready():
	%RefreshButton.pressed.connect(_on_refresh_button_pressed)
	%CopyDescrButton.pressed.connect(_on_copy_descr_button_pressed)
#	%ItemList.item_selected.connect(_on_item_selected)
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
func _process(_delta):
	var now: int = Time.get_ticks_msec()
	if now > _next_scene_check_time:
		_check_edited_scene_change()
	_is_dirty = _dirty_flags != 0
	if _is_dirty and Time.get_ticks_msec() > _next_refresh_time:
		_next_refresh_time = Time.get_ticks_msec() + REFRESH_PERIOD_MS
		_refresh()


func _on_copy_descr_button_pressed():
#	var selected_items = %ItemList.get_selected_items()
#	print(str(len(selected_items)))
#	if len(selected_items) > 0:
	var inst_id = _item_data[_first_selected_index]
	var instance = instance_from_id(inst_id)
#	print(str(instance))
	if instance and instance is BUG_MARKER:
		DisplayServer.clipboard_set((instance as BUG_MARKER).description)


func _on_item_selected(index: int):
	%CopyDescrButton.disabled = false
	var inst_id = _item_data[index]
	_node_selector.on_selection_requested(inst_id)


func _on_tree_changed():
	get_tree()
	_dirty_flags |= DIRTY_FLAGS.TREE_CHANGED


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
			_connect_safe(_edited_root.tree_exited, _on_edited_root_exited_tree)
			_connect_safe(_edited_root.child_entered_tree, _on_edited_scene_child_added)
			_connect_safe(_edited_root.child_exiting_tree, _on_edited_scene_child_removed)
		_edited_root = new_edited_root


func _disconnect_safe(target_signal: Signal, target_function: Callable):
	if target_signal.is_connected(target_function):
		target_signal.disconnect(target_function)


func _connect_safe(target_signal: Signal, target_function: Callable):
	if not target_signal.is_connected(target_function):
		target_signal.connect(target_function)


func _on_edited_root_exited_tree():
#	print(_edited_root.name + " exited tree")
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


func _on_refresh_button_pressed():
	_dirty_flags |= DIRTY_FLAGS.REFRESH_PRESSED
	_next_refresh_time = 0 # FORCE instant refresh


func _enabled_in_interface(marker: BUG_MARKER) -> bool:
	var show_bug = _filter_popup.is_item_checked(_filter_popup.get_item_index(0))
	var show_feature = _filter_popup.is_item_checked(_filter_popup.get_item_index(1))
	var show_tech_impr = _filter_popup.is_item_checked(_filter_popup.get_item_index(2))
	var show_polish = _filter_popup.is_item_checked(_filter_popup.get_item_index(3))
	var show_regr_test = _filter_popup.is_item_checked(_filter_popup.get_item_index(4))
	var show_unknown = _filter_popup.is_item_checked(_filter_popup.get_item_index(8))
	var show_pending = _filter_popup.is_item_checked(_filter_popup.get_item_index(6))
	var show_completed = _filter_popup.is_item_checked(_filter_popup.get_item_index(7))
	var status_filter = show_completed if marker.status == BUG_MARKER.Status.COMPLETED else show_pending
	match marker.task_type:
		BUG_MARKER.TaskTypes.BUG:
			return status_filter and show_bug
		BUG_MARKER.TaskTypes.FEATURE:
			return status_filter and show_feature
		BUG_MARKER.TaskTypes.TECHNICAL_IMPROVEMENT:
			return status_filter and show_tech_impr
		BUG_MARKER.TaskTypes.POLISH:
			return status_filter and show_polish
		BUG_MARKER.TaskTypes.REGRESSION_TEST:
			return status_filter and show_regr_test
		BUG_MARKER.TaskTypes.UNKNOWN:
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
#		print("Task panel not ready to refresh")
		return
	var start_time_us = Time.get_ticks_usec()
#	print(Time.get_time_string_from_system() + " - Refreshing Tasks panel")
	for child in %RootVBoxContainer.get_children():
		if child is ITEM:
			var item = child as ITEM
			item.select_requested.disconnect(_node_selector.on_selection_requested)
		child.queue_free()
	var bug_markers = _get_markers_from_scene()
#	var items = []
	var items : Array[BUG_MARKER] = []
	for marker in bug_markers:
		if _enabled_in_interface(marker):
			items.append(marker)
#			var item: ITEM = _item_resource.instantiate()
#			item.setup(marker)
#			item.select_requested.connect(_node_selector.on_selection_requested)
#			items.append(item)
#	items.sort_custom(func(a, b): return a.task_priority > b.task_priority)
	items.sort_custom(func(a : BUG_MARKER, b : BUG_MARKER): return a.get_sort_score() > b.get_sort_score())
	_task_selection_status.resize(len(items))
	_task_selection_status.fill(false)
	for old_item_inst_id in _item_data:
		var old_item = instance_from_id(old_item_inst_id)
		if old_item and old_item is BUG_MARKER:
			var old_task = old_item as BUG_MARKER
			old_task.task_changed.disconnect(_on_task_marker_changed)
	_item_data.clear()
	_selection_count = 0
#	%ItemList.clear()
#	%ItemList.max_columns = 4
	var tree_control: Tree = %Tree
	tree_control.clear()
#	tree_control.set_column_expand(2, false)
#	tree_control.set_column_expand(0, true)
#	%Tree.set_column_expand(TASK_TREE_COLUMN.TYPE, false)
#	%Tree.set_column_expand(TASK_TREE_COLUMN.PRIORITY, false)
#	%Tree.set_column_expand(TASK_TREE_COLUMN.STATUS, false)
	const OVERRUN_BEHAVIOUR: TextServer.OverrunBehavior = TextServer.OverrunBehavior.OVERRUN_TRIM_ELLIPSIS
#	const AUTOWRAP_MODE: TextServer.AutowrapMode = 0
	tree_control.set_column_expand(TASK_TREE_COLUMN.DESCRIPTION, true)
	var root: TreeItem = tree_control.create_item()
#	root.set_cell_mode(TASK_TREE_COLUMN.DESCRIPTION, TreeItem.CELL_MODE_STRING)
#	root.set_text(TASK_TREE_COLUMN.DESCRIPTION, "Root")
#	root.set_text_overrun_behavior(TASK_TREE_COLUMN.DESCRIPTION, OVERRUN_BEHAVIOUR)
#	root.set_autowrap_mode(TASK_TREE_COLUMN.DESCRIPTION, AUTOWRAP_MODE)
#	root.set_autowrap_mode(1, AUTOWRAP_MODE)
#	root.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
#	root.set_text(1, "Test")
	for item in items:
#		%RootVBoxContainer.add_child(item)
#		var separator := HSeparator.new()
#		%RootVBoxContainer.add_child(separator)
		_item_data.append(item.get_instance_id())
		item.task_changed.connect(_on_task_marker_changed)
		
#		var index = %ItemList.add_icon_item(item.get_icon())
#		%ItemList.set_item_icon_modulate(index, item.get_color())
#		index = %ItemList.add_icon_item(item.get_priority_icon())
#		%ItemList.set_item_icon_modulate(index, item.get_priority_color())
#		index = %ItemList.add_icon_item(item.get_status_icon())
#		%ItemList.set_item_icon_modulate(index, item.get_status_color())
#		%ItemList.add_item(item.description)

		
		var tree_item: TreeItem = tree_control.create_item(root)
#		tree_item.set_cell_mode(TASK_TREE_COLUMN.TYPE, TreeItem.CELL_MODE_ICON)
		tree_item.set_cell_mode(TASK_TREE_COLUMN.PRIORITY, TreeItem.CELL_MODE_ICON)
		tree_item.set_cell_mode(TASK_TREE_COLUMN.DESCRIPTION, TreeItem.CELL_MODE_STRING)
		
#		root.set_autowrap_mode(0, AUTOWRAP_MODE)
#		root.set_autowrap_mode(1, AUTOWRAP_MODE)
		
		
		tree_item.set_icon(TASK_TREE_COLUMN.DESCRIPTION, item.get_icon())
		tree_item.set_icon_modulate(TASK_TREE_COLUMN.DESCRIPTION, item.get_color())
#		var desc_tooltip: String = "Type: " + item.get_task_type_name().to_lower().capitalize()
#		desc_tooltip += " - " + item.description
		tree_item.set_tooltip_text(TASK_TREE_COLUMN.DESCRIPTION, item.get_task_type_name().to_lower().capitalize())
		tree_item.set_text(TASK_TREE_COLUMN.DESCRIPTION, item.description)
		tree_item.set_tooltip_text(TASK_TREE_COLUMN.DESCRIPTION, item.description)
		tree_item.set_text_overrun_behavior(TASK_TREE_COLUMN.DESCRIPTION, OVERRUN_BEHAVIOUR)
		var prior_icon: Texture2D = item.get_priority_icon(true)
		var pr_tooltip: String = "Priority: " + item.get_priority_string().to_lower().capitalize()
		pr_tooltip += "; Status: " + item.get_status_string().to_lower().capitalize()
		tree_item.set_tooltip_text(TASK_TREE_COLUMN.PRIORITY, pr_tooltip)
		tree_item.set_icon(TASK_TREE_COLUMN.PRIORITY, prior_icon)
#		tree_item.set_icon_max_width(TASK_TREE_COLUMN.PRIORITY, 8)
		tree_item.set_icon_modulate(TASK_TREE_COLUMN.PRIORITY, item.get_priority_color(true))
#		var completed: bool = item.status == BUG_MARKER.Status.COMPLETED
#		if item.status == BUG_MARKER.Status.COMPLETED:
#			tree_item.set_cell_mode(TASK_TREE_COLUMN.STATUS, TreeItem.CELL_MODE_ICON)
#			tree_item.set_tooltip_text(TASK_TREE_COLUMN.STATUS, item.get_status_string())
#			tree_item.set_icon(TASK_TREE_COLUMN.STATUS, item.get_status_icon())
#			tree_item.set_icon_modulate(TASK_TREE_COLUMN.STATUS, item.get_status_color())
#			tree_item.set_icon_max_width(TASK_TREE_COLUMN.STATUS, 16)
#		else:
#			tree_item.set_cell_mode(TASK_TREE_COLUMN.STATUS, TreeItem.CELL_MODE_STRING)
		
	var time_taken_us = Time.get_ticks_usec() - start_time_us
	print(Time.get_time_string_from_system() + " - Refreshed Tasks panel (" + str(float(time_taken_us) / 1000) + " ms)")
	print(trigger_desc)


func _refresh_node_selection():
	var selected_items: Array[Node] = []
	for i in range(0, len(_task_selection_status)):
		if _task_selection_status[i]:
			var inst_id = _item_data[i]
			var node = instance_from_id(inst_id)
			selected_items.append(node)
	_node_selector.set_selection(selected_items)


func _on_multi_selected(item: TreeItem, column: int, selected: bool):
	if column != 0:
		return
	# TODO: select nodes corresponding to selected items, deselect nodes corresponding to deselected items
#	var selected_nodes
#	_node_selector.set_selection()
#	var tree_control := %Tree as Tree
#	var root = (%Tree as Tree).get_root()
	var index = item.get_index()
#	var node = instance_from_id(_item_data[index])
#	_selection_count += 1 if selected else -1
#	if _selection_count == 0 and selected:
#		_node_selector.clear_selection()
#	if tree_control.get_selected()
	_task_selection_status[index] = selected
	_selection_count += 1 if selected else -1
	print("Selected items: " + str(_selection_count))
	if _selection_count == 1:
		_first_selected_index = index
	%CopyDescrButton.disabled = _selection_count == 0
		
#	if selected:
#		_node_selector.add_to_selection(node)
#	else:
#		_selected_item_indices.erase(index)
#		_node_selector.remove_from_selection(node)
#	_selection_dirty = true
	_refresh_node_selection.call_deferred()
#	print(str(item) + ", col: " + str(column) + " selected: " + str(selected))
	

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
