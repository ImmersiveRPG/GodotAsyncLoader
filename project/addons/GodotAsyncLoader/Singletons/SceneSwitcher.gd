# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node


func change_scene(path : String, loading_path := "") -> void:
	var data := {}

	# Make sure the scene exists before starting to load
	if not ResourceLoader.exists(path):
		push_error("Scene files does not exist: %s" % [path])
		return

	# Make sure the loading scene exists before starting to load
	if loading_path and not ResourceLoader.exists(loading_path):
		push_error("Loading scene files does not exist: %s" % [loading_path])
		return

	# Show the loading screen
	var start := OS.get_ticks_msec()
	if loading_path:
		var err : int = get_tree().change_scene(loading_path)
		assert(err == OK)
		#if SceneLoader._is_logging_loads: print("!!!!!! MAIN: changed to loading scene for %s ms" % [OS.get_ticks_msec() - start])
	if SceneLoader._is_logging_loads: data["change_scene"] = OS.get_ticks_msec() - start

	# Load the scene
	var pos := Vector3.INF
	SceneLoader.load_scene_async_with_cb(self, path, pos, true, funcref(self, "_on_scene_loaded"), data)

func _on_scene_loaded(path : String, node : Node, _pos : Vector3, _is_pos_global : bool, data : Dictionary) -> void:
	var tree : SceneTree = self.get_tree()
	var new_scene = node

	# Remove the old scene
	var start := OS.get_ticks_msec()
	var old_scene = tree.current_scene
	tree.root.remove_child(old_scene)
	old_scene.queue_free()
	if SceneLoader._is_logging_loads: data["remove_scene"] = OS.get_ticks_msec() - start

	# Add the new scene
	start = OS.get_ticks_msec()
	tree.root.add_child(new_scene)
	var time := OS.get_ticks_msec() - start
	if SceneLoader._is_logging_loads: data["add"] = time
	print("+++ Adding %s \"%s\" %s ms" % ["scene", new_scene.name, time])

	# Change to the new scene
	start = OS.get_ticks_msec()
	tree.set_current_scene(new_scene)
	if SceneLoader._is_logging_loads: data["set_current"] = OS.get_ticks_msec() - start

	if SceneLoader._is_logging_loads:
		var message := ""
		message += "!!!!!! scene switch %s\n" % path
		message += "    load %s ms in THREAD\n" % data["load"]
		message += "    instance %s ms in THREAD\n" % data["instance"]
		message += "    remove previous %s ms in MAIN!!!!!!!!!!!!\n" % data["remove_scene"]
		message += "    add %s ms in MAIN!!!!!!!!!!!!\n" % data["add"]
		message += "    set current %s ms in MAIN!!!!!!!!!!!!\n" % data["set_current"]
		print(message)
