# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Control

# TODO:
# . Make throttler configurable
# . Add distance zones for waking/sleeping
# . Make it save sleeping nodes in tscn files in FS
# . Get rid of _world_offset to simplify code


func _ready() -> void:
	var err = AsyncLoader.connect("loading_started", Global, "_on_loading_started")
	assert(err == OK)

	err = AsyncLoader.connect("loading_progress", Global, "_on_loading_progress")
	assert(err == OK)

	err = AsyncLoader.connect("loading_done", Global, "_on_loading_done")
	assert(err == OK)

	err = AsyncLoader.connect("scene_changed", Global, "_on_scene_changed")
	assert(err == OK)

	AsyncLoader.start(Global.GROUPS, Global.GROUP_SLEEP_DISTANCES)

func _on_StartAsyncButton_pressed() -> void:
	AsyncLoader.change_scene("res://examples/World/World.tscn", "res://examples/Loading/Loading.tscn")

func _on_StartSyncButton_pressed() -> void:
	# Remove the old scene
	var start := OS.get_ticks_msec()
	var tree = self.get_tree()
	var old_scene = tree.current_scene
	tree.root.remove_child(old_scene)
	old_scene.queue_free()
	print("Removing old scene took %sms" % [OS.get_ticks_msec() - start])

	# Load the new scene
	start = OS.get_ticks_msec()
	var scene := ResourceLoader.load("res://examples/World/World.tscn")
	print("Loading scene took %sms" % [OS.get_ticks_msec() - start])

	# Instance the new scene
	start = OS.get_ticks_msec()
	var instance = scene.instance()
	print("Instancing scene took %sms" % [OS.get_ticks_msec() - start])

	# Add the new scene
	start = OS.get_ticks_msec()
	tree.root.add_child(instance)
	print("Adding scene took %sms" % [OS.get_ticks_msec() - start])

	tree.set_current_scene(instance)


func _on_start_async_open_world_button_pressed() -> void:
	AsyncLoader.change_scene("res://examples/WorldOpen/WorldOpen.tscn", "res://examples/Loading/Loading.tscn")
