# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Control

const CATEGORIES := [
	"terrain",
	"building",
	"furniture",
	"plant",
	"item",
	"npc",
	"etc",
]

func _init() -> void:
	SceneAdder._sleep_msec = 100
	SceneAdder.set_categories(CATEGORIES)

func _on_StartAsyncButton_pressed() -> void:
	SceneSwitcher.change_scene("res://addons/GodotAsyncLoader/Example/src/World/World.tscn", "res://addons/GodotAsyncLoader/Example/src/Loading/Loading.tscn")

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
	var scene := ResourceLoader.load("res://addons/GodotAsyncLoader/Example/src/World/World.tscn")
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

