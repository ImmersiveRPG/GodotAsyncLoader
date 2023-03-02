# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
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
	if not loading_path.is_empty() and not ResourceLoader.exists(loading_path):
		push_error("Loading scene files does not exist: %s" % [loading_path])
		return

	# Show the loading screen
	if loading_path:
		var err : int = get_tree().change_scene_to_file(loading_path)
		assert(err == OK)

	# Load the scene
	var cb := Callable(self, "_on_scene_loaded")
	AsyncLoader.instance_with_cb(scene_path, cb, data)

func _on_scene_loaded(instance : Node, data : Dictionary) -> void:
	# Get old current scene
	var tree : SceneTree = self.get_tree()
	var old_scene = tree.current_scene

	# Add new scene and make it current
	tree.root.add_child(instance)
	tree.set_current_scene(instance)

	# Free old scene
	old_scene.queue_free()

	AsyncLoader.call_deferred("emit_signal", "scene_changed", AsyncLoader._total_queue_count)
