# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _scene_cache = null
var _scene_loader = null
var _scene_instancer = null
var _scene_adder = null
var _scene_switcher = null

signal loading_started(total)
signal loading_progress(current, total)
signal loading_done(total)
signal scene_changed

var _was_queue_empty := true
var _total_queue_count := 0

func start(groups : Array, sleep_msec : int) -> void:
	await get_tree().process_frame
	var config = self.get_node_or_null("/root/AsyncLoaderConfig")
	config._post_add_sleep_msec = sleep_msec
	_scene_adder._set_groups(groups)

	# Start the adder thread
	_scene_adder._thread = Thread.new()
	var err = _scene_adder._thread.start(Callable(_scene_adder, "_run_adder_thread"), Thread.PRIORITY_LOW)
	assert(err == OK)

	# Start the instancer thread
	_scene_instancer._thread = Thread.new()
	err = _scene_instancer._thread.start(Callable(_scene_instancer, "_run_instancer_thread"), Thread.PRIORITY_LOW)
	assert(err == OK)

	# Start the loader thread
	_scene_loader._thread = Thread.new()
	err = _scene_loader._thread.start(Callable(_scene_loader, "_run_loader_thread"), Thread.PRIORITY_LOW)
	assert(err == OK)

	config._is_setup = true





func instance_with_cb(scene_path : String, cb : Callable, data := {}, has_priority := false) -> void:
	if not self._assert_is_setup(): return

	var cb_data := {
		"scene_path" : scene_path,
		"cb" : cb,
		"data" : data,
		"has_priority" : has_priority
	}

	var _loaded_cb := Callable(self, "_loaded_cb")
	_scene_loader.load_with_cb(scene_path, _loaded_cb, cb_data, has_priority)

func _loaded_cb(packed_scene : PackedScene, data : Dictionary) -> void:
	#print(["!!! _loaded_cb", data])
	var _instanced_cb := Callable(self, "_instanced_cb")
	var has_priority = data["has_priority"]
	_scene_instancer.instance_with_cb(packed_scene, _instanced_cb, data, has_priority)

func _instanced_cb(instance : Node, data : Dictionary) -> void:
	#print(["!!! _instanced_cb", data])
	var _added_cb := Callable(self, "_added_cb")
	var has_priority = data["has_priority"]
	_scene_adder._add_scene(instance, _added_cb, data, has_priority)

func _added_cb(instance : Node, data : Dictionary) -> void:
	#print(["!!! _added_cb", instance, data])
	var cb = data["cb"]
	var cb_data = data["data"]

	# Just return if instance is invalid
	if not is_instance_valid(instance):
		push_error("!!! Warning: instance is not valid!!!!")
		return

	# Just return if the cb is null
	if cb == null:
		push_error("!!! Warning: cb was null!!!!")
		return

	# Just return if the cb is not valid
	if not cb.is_valid():
		push_error("!!! Warning: cb is not valid!!!!")
		return

	# Just return if the cb target is null
	if cb.is_null():
		push_error("!!! Warning: cb target is null!!!!")
		return

	#print([cb, instance, data])
	cb.call(instance, cb_data)


func instance(target : Node, scene_path : String, pos : Vector3, is_pos_global : bool, has_priority := false) -> void:
	if not self._assert_is_setup(): return

	var data := {
		"target" : target,
		"pos" : pos,
		"is_pos_global" : is_pos_global,
	}
	var cb := Callable(self, "_default_instance_cb")
	AsyncLoader.instance_with_cb(scene_path, cb, data, has_priority)

func _default_instance_cb(instance : Node, data : Dictionary) -> void:
	var target = data["target"]
	var pos = data["pos"]
	var is_pos_global = data["is_pos_global"]

	target.add_child(instance)

	# Set the instance position
	if pos != Vector3.INF and "transform" in instance:
		# Convert the position from global to local if needed
		if is_pos_global:
			pos = pos - target.global_transform.origin

		instance.transform.origin = pos

func instance_sync(scene_path : String) -> Node:
	if not self._assert_is_setup(): return null

	var scene = _scene_cache._load_and_cache(scene_path)
	var instance = scene.instantiate()
	return instance

func change_scene(scene_path : String, loading_path := "") -> void:
	if not self._assert_is_setup(): return

	_scene_switcher.change_scene(scene_path, loading_path)


func _load_and_cache_scene(scene_path : String) -> PackedScene:
	return _scene_cache._load_and_cache(scene_path)

func _assert_is_setup() -> bool:
	var config = get_node("/root/AsyncLoaderConfig")
	if not config._is_setup:
		push_error("Call AsyncLoader.start to initialize the library first")
	return config._is_setup

func _ready() -> void:
	# Create config and make it accessible as /root/AsyncLoaderConfig
	var config = ResourceLoader.load("res://addons/GodotAsyncLoader/Singletons/AsyncLoaderConfig.gd").new()
	config.name = "AsyncLoaderConfig"
	await get_tree().process_frame
	self.get_tree().root.add_child(config)
	config.owner = self.get_tree().root

	_scene_cache = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneCache.gd").new()
	_scene_loader = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneLoader.gd").new()
	_scene_instancer = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneInstancer.gd").new()
	_scene_adder = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneAdder.gd").new()
	_scene_switcher = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneSwitcher.gd").new()

	self.add_child(_scene_cache)
	self.add_child(_scene_loader)
	self.add_child(_scene_instancer)
	self.add_child(_scene_adder)
	self.add_child(_scene_switcher)

func _exit_tree() -> void:
	# Tell the threads to stop
	if _scene_loader and _scene_loader._is_running:
		_scene_loader._is_running = false

	if _scene_instancer and _scene_instancer._is_running:
		_scene_instancer._is_running = false

	if _scene_adder and _scene_adder._is_running:
		_scene_adder._is_running = false

	# Wait for the threads to stop
	if _scene_loader and _scene_loader._thread:
		_scene_loader._thread.wait_to_finish()
		_scene_loader._thread = null

	if _scene_instancer and _scene_instancer._thread:
		_scene_instancer._thread.wait_to_finish()
		_scene_instancer._thread = null

	if _scene_adder and _scene_adder._thread:
		_scene_adder._thread.wait_to_finish()
		_scene_adder._thread = null
