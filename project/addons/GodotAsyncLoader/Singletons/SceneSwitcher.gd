# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Node


func change_scene(path : String) -> void:
	var data := {}

	# Make sure the scene exists before starting to load
	if not ResourceLoader.exists(path):
		push_error("Scene files does not exist: %s" % [path])
		return

	# Show the loading screen
	var start := OS.get_ticks_msec()
	var err : int = get_tree().change_scene("res://src/Loading/Loading.tscn")
	assert(err == OK)
	#if SceneLoader._is_logging_loads: print("!!!!!! MAIN: changed to loading scene for %s ms" % [OS.get_ticks_msec() - start])
	if SceneLoader._is_logging_loads: data["change_scene"] = OS.get_ticks_msec() - start

	# Load the scene
	var pos := Vector3.INF
	SceneLoader.load_scene_async_with_cb(self, path, pos, true, funcref(self, "_on_scene_loaded"), data)

func _on_scene_loaded(path : String, node : Node, _pos : Vector3, _is_pos_global : bool, data : Dictionary) -> void:
	var tree : SceneTree = self.get_tree()
	var new_scene = node

	# Remove the old loading scene
	var start := OS.get_ticks_msec()
	var old_scene = tree.current_scene
	tree.root.remove_child(old_scene)
	old_scene.queue_free()
	if SceneLoader._is_logging_loads: data["remove_scene"] = OS.get_ticks_msec() - start

	# Add the new scene
	start = OS.get_ticks_msec()
	tree.root.add_child(new_scene)
	if SceneLoader._is_logging_loads: data["add"] = OS.get_ticks_msec() - start
	print("+++ Adding %s %s ms" % [new_scene.name, OS.get_ticks_msec() - start])

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
