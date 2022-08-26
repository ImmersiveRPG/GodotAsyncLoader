# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

const DEFAULT_SLEEP_MSEC := 10

var _scene_instancer = null
var _scene_adder = null
var _scene_switcher = null

var _sleep_msec := 0
var _is_logging_loads := false

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

func instance_async_with_cb(scene_path : String, cb : FuncRef, data := {}, has_priority := false) -> void:
	_scene_instancer.instance_async_with_cb(scene_path, cb, data, has_priority)

func instance_async(target : Node, scene_path : String, pos : Vector3, is_pos_global : bool) -> void:
	_scene_instancer.instance_async(target, scene_path, pos, is_pos_global)

func instance_sync(scene_path : String) -> Node:
	return _scene_instancer.instance_sync(scene_path)

func change_scene(scene_path : String, loading_path := "") -> void:
	_scene_switcher.change_scene(scene_path, loading_path)

func _add_scene(on_done_cb : FuncRef, scene_path : String, cb : FuncRef, instance : Node, data : Dictionary, has_priority : bool) -> void:
	_scene_adder._add_scene(on_done_cb, scene_path, cb, instance, data, has_priority)

func _ready() -> void:
	_scene_instancer = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneInstancer.gd").new()
	_scene_adder = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneAdder.gd").new()
	_scene_switcher = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneSwitcher.gd").new()

	self.add_child(_scene_instancer)
	self.add_child(_scene_adder)
	self.add_child(_scene_switcher)

func _exit_tree() -> void:
	# Tell the threads to stop
	if _scene_adder._is_running:
		_scene_adder._is_running = false

	if _scene_instancer._is_running:
		_scene_instancer._is_running = false

	# Wait for the threads to stop
	if _scene_adder._thread:
		_scene_adder._thread.wait_to_finish()
		_scene_adder._thread = null

	if _scene_instancer._thread:
		_scene_instancer._thread.wait_to_finish()
		_scene_instancer._thread = null
