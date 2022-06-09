# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

tool
extends EditorPlugin

func _enter_tree() -> void:
	self.add_autoload_singleton("SceneAdder", "res://addons/GodotAsyncLoader/Singletons/SceneAdder.gd")
	self.add_autoload_singleton("SceneLoader", "res://addons/GodotAsyncLoader/Singletons/SceneLoader.gd")
	self.add_autoload_singleton("SceneSwitcher", "res://addons/GodotAsyncLoader/Singletons/SceneSwitcher.gd")
	print("Godot Async Loader installed")

func _exit_tree() -> void:
	self.remove_autoload_singleton("SceneSwitcher")
	self.remove_autoload_singleton("SceneLoader")
	self.remove_autoload_singleton("SceneAdder")
	print("Godot Async Loader uninstalled")
