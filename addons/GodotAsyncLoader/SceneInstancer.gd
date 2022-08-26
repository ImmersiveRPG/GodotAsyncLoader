# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _to_instance := []
var _to_instance_mutex := Mutex.new()

#func instance_sync(scene_path : String) -> Node:
#	var data := {}
#
#	# Load the scene
#	var scene = _get_cached_scene(scene_path)
#	if scene == null: return null
#
#	# Instance the scene
#	var instance = scene.instance()
#
#	return instance

func instance_async_with_cb(packed_scene : PackedScene, scene_path : String, cb : FuncRef, data := {}, has_priority := false) -> void:
	var entry := {
		"packed_scene" : packed_scene,
		"scene_path" : scene_path,
		"cb" : cb,
		"data" : data,
		"has_priority" : has_priority,
	}

	_to_instance_mutex.lock()
	if has_priority:
		_to_instance.push_front(entry)
	else:
		_to_instance.push_back(entry)
	_to_instance_mutex.unlock()
	#print(_to_instance)

func _run_instancer_thread(_arg : int) -> void:
	_is_running = true

	while _is_running:
		_to_instance_mutex.lock()
		var to_instance := _to_instance.duplicate()
		_to_instance.clear()
		_to_instance_mutex.unlock()

		#print(to_instance)
		for entry in to_instance:
			var packed_scene = entry["packed_scene"]
			var scene_path = entry["scene_path"]
			var cb = entry["cb"]
			var data = entry["data"]
			var has_priority = entry["has_priority"]
			#print("!!!!!!! scene_path: %s" % scene_path)

			# Instance the scene
			var instance = packed_scene.instance()

			# Send the instance to the callback in the main thread
			AsyncLoader._add_scene(funcref(self, "_on_done"), scene_path, cb, instance, data, has_priority)
			#self.call_deferred("_on_done", target, scene_path, cb, instance, data)
			#print("??????? instance.global_transform.origin: %s" % instance.global_transform.origin)

		OS.delay_msec(2)

func _on_done(scene_path : String, cb : FuncRef, instance : Node, data : Dictionary) -> void:
#	# Just return if target is invalid
#	if not is_instance_valid(target):
#		return

	# Just return if instance is invalid
	if not is_instance_valid(instance):
		return

	# Just return if the cb is invalid
	if cb != null and not cb.is_valid():
		return

	if cb != null:
		#cb.call_deferred("call_func", instance, data)
		cb.call_func(instance, data)
	else:
		push_error("!!! Warning: cb was null!!!!")

