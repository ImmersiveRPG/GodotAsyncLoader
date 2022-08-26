# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node


var _scene_loader = null
var _scene_adder = null
var _scene_switcher = null

var _sleep_msec := 100
var _is_logging_loads := false

func _ready() -> void:
	_scene_loader = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneLoader.gd").new()
	_scene_adder = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneAdder.gd").new()
	_scene_switcher = ResourceLoader.load("res://addons/GodotAsyncLoader/SceneSwitcher.gd").new()

	self.add_child(_scene_loader)
	self.add_child(_scene_adder)
	self.add_child(_scene_switcher)
	
func set_groups(groups : Array) -> void:
	_scene_adder.set_groups(groups)

func load_scene_async_with_cb(target : Node, path : String, pos : Vector3, is_pos_global : bool, cb : FuncRef, data : Dictionary, has_priority := false) -> void:
	_scene_loader.load_scene_async_with_cb(target, path, pos, is_pos_global, cb, data, has_priority)

func load_scene_async(target : Node, path : String, pos : Vector3, is_pos_global : bool) -> void:
	_scene_loader.load_scene_async(target, path, pos, is_pos_global)

func load_scene_sync(target : Node, path : String) -> Node:
	return _scene_loader.load_scene_sync(target, path)

func change_scene(path : String, loading_path := "") -> void:
	_scene_switcher.change_scene(path, loading_path)

func _add_scene(on_done_cb : FuncRef, target : Node, path : String, pos : Vector3, is_pos_global : bool, cb : FuncRef, instance : Node, data : Dictionary, has_priority : bool) -> void:
	_scene_adder._add_scene(on_done_cb, target, path, pos, is_pos_global, cb, instance, data, has_priority)
