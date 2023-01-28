# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node


func _on_add_orange_async_pressed() -> void:
	var r := 100.0
	var pos := Vector3(
		rand_range(-r, r),
		20.0,
		rand_range(-r, r)
	)

	# Instance scene asynchronously and send to callback
	var target = get_tree().get_current_scene()
	var scene_file := "res://examples/Items/Orange/Orange.tscn"
	SceneLoader.load_scene_async_with_cb(target, scene_file, pos, true, funcref(self, "on_orange_loaded"), {})

func on_orange_loaded(path : String, instance : Node, pos : Vector3, is_pos_global : bool, data : Dictionary) -> void:
	var target = get_tree().get_current_scene()
	instance.transform.origin = pos
	target.add_child(instance)


func _on_add_orange_sync_pressed() -> void:
	var r := 100.0
	var pos := Vector3(
		rand_range(-r, r),
		20.0,
		rand_range(-r, r)
	)

	# Instance scene asynchronously and send to callback
	var target = get_tree().get_current_scene()
	var scene_file := "res://examples/Items/Orange/Orange.tscn"
	var instance := SceneLoader.load_scene_sync(target, scene_file)
	instance.transform.origin = pos


func _on_change_scene_pressed() -> void:
	SceneSwitcher.change_scene("res://examples/World2/World2.tscn", "res://examples/Loading/Loading.tscn")
