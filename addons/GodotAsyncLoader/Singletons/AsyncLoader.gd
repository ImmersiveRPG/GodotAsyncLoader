# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

const DEFAULT_SLEEP_MSEC := 10

var _scene_loader = null
var _scene_adder = null
var _scene_switcher = null

var _sleep_msec := 0
var _is_logging_loads := false

func _ready() -> void:
	_scene_loader = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneLoader.gd").new()
	_scene_adder = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneAdder.gd").new()
	_scene_switcher = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneSwitcher.gd").new()

	self.add_child(_scene_loader)
	self.add_child(_scene_adder)
	self.add_child(_scene_switcher)

func start(groups : Array, sleep_msec := DEFAULT_SLEEP_MSEC) -> void:
	_sleep_msec = sleep_msec
	_scene_adder.set_groups(groups)

	# Start the adder thread
	_scene_adder._thread = Thread.new()
	var err = _scene_adder._thread.start(_scene_adder, "_run_adder_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

	# Start the loader thread
	_scene_loader._thread = Thread.new()
	err = _scene_loader._thread.start(_scene_loader, "_run_loader_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

func _exit_tree() -> void:
	# Tell the threads to stop
	if _scene_adder._is_running:
		_scene_adder._is_running = false

	if _scene_loader._is_running:
		_scene_loader._is_running = false

	# Wait for the threads to stop
	if _scene_adder._thread:
		_scene_adder._thread.wait_to_finish()
		_scene_adder._thread = null

	if _scene_loader._thread:
		_scene_loader._thread.wait_to_finish()
		_scene_loader._thread = null

func load_scene_async_with_cb(scene_file : String, cb : FuncRef, data := {}, has_priority := false) -> void:
	_scene_loader.load_scene_async_with_cb(scene_file, cb, data, has_priority)

func load_scene_async(target : Node, path : String, pos : Vector3, is_pos_global : bool) -> void:
	_scene_loader.load_scene_async(target, path, pos, is_pos_global)

func load_scene_sync(target : Node, path : String) -> Node:
	return _scene_loader.load_scene_sync(target, path)

func change_scene(path : String, loading_path := "") -> void:
	_scene_switcher.change_scene(path, loading_path)

func _add_scene(on_done_cb : FuncRef, path : String, cb : FuncRef, instance : Node, data : Dictionary, has_priority : bool) -> void:
	_scene_adder._add_scene(on_done_cb, path, cb, instance, data, has_priority)
