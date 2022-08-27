# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

const DEFAULT_SLEEP_MSEC := 10

var _scene_cache = null
var _scene_loader = null
var _scene_instancer = null
var _scene_adder = null
var _scene_switcher = null

var _sleep_msec := 0
var _is_setup := false

func start(groups : Array, sleep_msec := DEFAULT_SLEEP_MSEC) -> void:
	_sleep_msec = sleep_msec
	_scene_adder._set_groups(groups)

	# Start the adder thread
	_scene_adder._thread = Thread.new()
	var err = _scene_adder._thread.start(_scene_adder, "_run_adder_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

	# Start the instancer thread
	_scene_instancer._thread = Thread.new()
	err = _scene_instancer._thread.start(_scene_instancer, "_run_instancer_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

	# Start the loader thread
	_scene_loader._thread = Thread.new()
	err = _scene_loader._thread.start(_scene_loader, "_run_loader_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

	_is_setup = true

func instance_async_with_cb(scene_path : String, cb : FuncRef, data := {}, has_priority := false) -> void:
	if not self._assert_is_setup(): return

	_scene_loader.load_and_instance_async_with_cb(scene_path, cb, data, has_priority)

func instance_async(target : Node, scene_path : String, pos : Vector3, is_pos_global : bool, has_priority := false) -> void:
	if not self._assert_is_setup(): return

	var data := {
		"target" : target,
		"pos" : pos,
		"is_pos_global" : is_pos_global,
	}
	var cb := funcref(self, "_default_instance_async_cb")
	_scene_loader.load_and_instance_async_with_cb(scene_path, cb, data, has_priority)

func _default_instance_async_cb(instance : Node, data : Dictionary) -> void:
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

	var scene = _scene_cache._get_cached(scene_path)
	var instance = scene.instance()
	return instance

func change_scene(scene_path : String, loading_path := "") -> void:
	if not self._assert_is_setup(): return

	_scene_switcher.change_scene(scene_path, loading_path)

func get_cached_scene(scene_path : String) -> PackedScene:
	if not self._assert_is_setup(): return null
	return _scene_cache._get_cached(scene_path)

func _add_scene(on_done_cb : FuncRef, scene_path : String, cb : FuncRef, instance : Node, data : Dictionary, has_priority : bool) -> void:
	_scene_adder._add_scene(on_done_cb, scene_path, cb, instance, data, has_priority)

func _instance_scene(packed_scene : PackedScene, scene_path : String, cb : FuncRef, data : Dictionary, has_priority : bool) -> void:
	_scene_instancer.instance_async_with_cb(packed_scene, scene_path, cb, data, has_priority)

func _assert_is_setup() -> bool:
	if not _is_setup:
		push_error("Call AsyncLoader.start to initialize the library first")
	return _is_setup

func _ready() -> void:
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
	if _scene_loader._is_running:
		_scene_loader._is_running = false

	if _scene_instancer._is_running:
		_scene_instancer._is_running = false

	if _scene_adder._is_running:
		_scene_adder._is_running = false

	# Wait for the threads to stop
	if _scene_loader._thread:
		_scene_loader._thread.wait_to_finish()
		_scene_loader._thread = null

	if _scene_instancer._thread:
		_scene_instancer._thread.wait_to_finish()
		_scene_instancer._thread = null

	if _scene_adder._thread:
		_scene_adder._thread.wait_to_finish()
		_scene_adder._thread = null
