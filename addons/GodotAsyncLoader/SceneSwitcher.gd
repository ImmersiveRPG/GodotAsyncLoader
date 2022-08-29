# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node


func change_scene(scene_path : String, loading_path := "") -> void:
	var data := {
		"scene_path" : scene_path,
	}

	# Make sure the scene exists before starting to load
	if not ResourceLoader.exists(scene_path):
		push_error("Scene files does not exist: %s" % [scene_path])
		return

	# Make sure the loading scene exists before starting to load
	if loading_path and not ResourceLoader.exists(loading_path):
		push_error("Loading scene files does not exist: %s" % [loading_path])
		return

	# Show the loading screen
	if loading_path:
		var err : int = get_tree().change_scene(loading_path)
		assert(err == OK)

	# Load the scene
	var cb := funcref(self, "_on_scene_loaded")
	AsyncLoader.instance_with_cb(scene_path, cb, data)

func _on_scene_loaded(instance : Node, data : Dictionary) -> void:
	var tree : SceneTree = self.get_tree()
	var new_scene = instance
	var scene_path = data["scene_path"]

	# Remove the old scene
	var old_scene = tree.current_scene
	tree.root.remove_child(old_scene)
	old_scene.queue_free()

	# Add the new scene
	tree.root.add_child(new_scene)

	# Change to the new scene
	tree.set_current_scene(new_scene)
