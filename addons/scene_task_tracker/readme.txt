Enable the plugin: Project -> Project Settings -> Plugins -> SceneTaskTracker

To add a task to a scene, drag task_marker.tscn into the scene and modify description, task type.

To view a list of all tasks in the currently edited scene, look at the Tasks tab in upper right
docking area of Godot.
Click a task to select it in the scene.
The Filter button controls the task list in the Tasks tab.
The Select In Scene button allows selecting the task marker nodes in the currently edited scene.

Tips for project organization and version control:
- To reduce the sizes of scenes, consider having a tasks only scene which contains instances of the
  other relevant scenes.
  This concept is used in the example scenes.
  The playable scene to be used in the game build is Level1.
  Then there is the Level1WithTasks which wraps Level1 and adds the task markers.
  This way, modifications to task markers will not affect the playable level or its components.
