# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

tool
extends EditorPlugin

# Get the name and paths of all the autoloads
const autoloads := {
	"SceneAdder" : "res://addons/GodotAsyncLoader/Singletons/SceneAdder.gd",
	"SceneLoader" : "res://addons/GodotAsyncLoader/Singletons/SceneLoader.gd",
	"SceneSwitcher" : "res://addons/GodotAsyncLoader/Singletons/SceneSwitcher.gd",
}

func _enter_tree() -> void:
	# Install all the autoloads
	for name in autoloads:
		var path = autoloads[name]
		if not ProjectSettings.has_setting("autoload/%s" % [name]):
			self.add_autoload_singleton(name, path)

	print("Installed plugin Godot Async Loader")

func _exit_tree() -> void:
	# Uninstall all the autoloads
	for name in autoloads:
		if ProjectSettings.has_setting("autoload/%s" % [name]):
			self.remove_autoload_singleton(name)

	print("Uninstalled plugin Godot Async Loader")
